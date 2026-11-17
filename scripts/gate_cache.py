"""Skip a gate while nothing it read has changed since it passed.

    python3 scripts/gate_cache.py check --dir D --meta M gate...       # one line a gate: `<gate>\\tcached` or `<gate>\\t<why it runs>`
    python3 scripts/gate_cache.py record --dir D --meta M --gate G --trace T --start NS \
        [--settings-reads R] [--cfg-start C]                           # T/t.<pid> from strace -ff
    python3 scripts/gate_cache.py show --trace T                       # what a trace counts as inputs, for looking
    python3 scripts/gate_cache.py user-dir                             # Ghost's user:// folder
    python3 scripts/gate_cache.py strace                               # how check.sh runs strace (before its -o)
    python3 scripts/gate_cache.py --selftest                           # the control: planted changes it must see

check.sh runs every gate under strace (STRACE, the calls in CALLS) and hands the trace here. A gate's
INPUTS are what its processes opened to read, stat'ed, executed or listed inside the repo or Ghost's
user:// folder (the fetched environments live there), and the paths they looked for and did not find.
What a gate wrote is its own, and so is the listing of a folder it wrote into. A record keeps a content
hash per file, a hash per listing, what was absent, and the meta check.sh hands in (Godot's version,
the gate's run line, the runner's own hash). GHOST.CFG IS KEPT BY THE KEYS READ: the app rewrites it
with any use, so each Godot process lists the keys its Settings reads (`GHOST_SETTINGS_READS`) and the
record holds those values alone - or the whole file when a process read it without saying which. A
gate whose record still holds is cached: a gate given the same bytes does the same thing, which the
gates are held to (pinned seeds, no timing the machine).

A listing is kept as the names the gate saw (strace prints them), so a folder others write into
while it runs (parallel probes' scenes in tests/) keeps what it read. A pass is kept only if nothing
else it read changed after the gate started (a file's ctime past the start, an absent path that
appeared; for ghost.cfg, a key read whose value differs from check.sh's copy at the start): otherwise
a file edited mid-run would be kept with bytes the gate never saw. A gate that connects off this machine is never kept. Hashes are remembered by device,
inode, size, mtime and ctime together, which no tool can set back.
"""

import hashlib
import os
import re
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

## How check.sh runs strace, before its `-o`: every process, a file per thread, descriptors shown as
## their paths, only the calls in CALLS stopping, and a listing's names printed whole.
STRACE = "-ff -qq -y -s 4096 --seccomp-bpf -e signal=none -e abbrev=!getdents64"
## The calls traced, as strace's -e trace= list.
CALLS = ("open,openat,openat2,creat,stat,lstat,newfstatat,statx,access,faccessat,faccessat2,execve,execveat,"
         "getdents64,connect,mkdir,mkdirat,rename,renameat,renameat2,unlink,unlinkat,rmdir,truncate,link,linkat,"
         "symlink,symlinkat")

## Under the repo, what no gate's result can depend on: outputs (logs, builds, this cache) and the
## engine's and Python's own caches, rebuilt from the sources the trace already holds.
SKIP_IN_ROOT = ("dist/", ".git/", ".godot/editor/", ".godot/shader_cache/", ".godot/mono/")
## Under user://, the same: logs and the renderer's caches.
SKIP_IN_USER = ("logs/", "shader_cache/", "vulkan/", ".recovery_mode_lock")
## Never part of a listing: the boot probe runner's private scene (`tests/_probe_<pid>.tscn`), which
## comes and goes with every run, any number at once, and Python's caches.
TRANSIENT = re.compile(r"^(_probe_\d+\.(tscn|gd)(\.uid)?|__pycache__)$")

WRITE_FLAGS = ("O_WRONLY", "O_RDWR", "O_CREAT", "O_TRUNC")
ABSENT_ERRORS = ("ENOENT", "ENOTDIR")
## The settings file, kept by the keys read (see the header).
CFG_NAME = "ghost.cfg"


def user_dir() -> Path:
    """Ghost's user:// folder, by the name project.godot gives it."""
    m = re.search(r'^config/custom_user_dir_name="([^"]+)"', (ROOT / "project.godot").read_text(), re.M)
    data = os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share")
    return Path(data) / (m.group(1) if m else "godot/app_userdata/ghost")


class Scope:
    """Which paths can be a gate's inputs."""

    def __init__(self, root: Path, user: Path):
        self.root = str(root).rstrip("/") + "/"
        self.user = str(user).rstrip("/") + "/"

    def holds(self, path: str) -> bool:
        if "/__pycache__/" in path or path.endswith("/__pycache__"):
            return False
        for base, skip in ((self.root, SKIP_IN_ROOT), (self.user, SKIP_IN_USER)):
            if path + "/" == base:
                return True
            if path.startswith(base):
                rel = path[len(base):]
                return not any(rel == s.rstrip("/") or rel.startswith(s) for s in skip)
        return False


# -- reading a trace ------------------------------------------------------------

_FD = re.compile(r'(?:AT_FDCWD|-?\d+)<((?:[^>\\]|\\.)*)>')
_STR = re.compile(r'"((?:[^"\\]|\\.)*)"')
_TOKEN = re.compile(r'(?:AT_FDCWD|-?\d+)<(?:[^>\\]|\\.)*>|"(?:[^"\\]|\\.)*"')
_RET = re.compile(r'\)\s+= (-?\d+|\?)(?:<[^>]*>)?(?: (E[A-Z0-9]+))?')
_INET = re.compile(r'sa_family=AF_INET6?.*?(?:sin6?_port=htons\((\d+)\)).*?(?:inet_addr\("([^"]+)"\)|inet_pton\(AF_INET6, "([^"]+)")')
_UNIX = re.compile(r'sa_family=AF_UNIX, sun_path=@?"([^"]*)"')
_NAME = re.compile(r'd_name="((?:[^"\\]|\\.)*)"')

## For each traced call, its arguments as the tokens pulled out of the line in order: `d` a folder
## descriptor shown as `<path>`, `p` a path string; what the call does with them is decided below.
SHAPES = {
    "open": "p", "creat": "p", "stat": "p", "lstat": "p", "access": "p", "execve": "p", "mkdir": "p",
    "unlink": "p", "rmdir": "p", "truncate": "p", "rename": "pp", "link": "pp", "symlink": "pp",
    "openat": "dp", "openat2": "dp", "newfstatat": "dp", "statx": "dp", "faccessat": "dp", "faccessat2": "dp",
    "execveat": "dp", "mkdirat": "dp", "unlinkat": "dp", "renameat": "dpdp", "renameat2": "dpdp",
    "linkat": "dpdp", "symlinkat": "pdp", "getdents64": "d",
}
READS = {"open", "openat", "openat2", "stat", "lstat", "newfstatat", "statx", "access", "faccessat",
         "faccessat2", "execve", "execveat"}


def _enc(s: str) -> str:
    """A path or key as one field of a record line (a path may hold a tab or a newline)."""
    return s.replace("\\", "\\\\").replace("\t", "\\t").replace("\n", "\\n").replace("\r", "\\r")


def _dec(s: str) -> str:
    out, i = [], 0
    while i < len(s):
        if s[i] == "\\" and i + 1 < len(s):
            out.append({"t": "\t", "n": "\n", "r": "\r"}.get(s[i + 1], s[i + 1]))
            i += 2
        else:
            out.append(s[i])
            i += 1
    return "".join(out)


def _lines(path: Path):
    """A record's or the memo's lines, split on newlines alone."""
    return [ln for ln in path.read_text(encoding="utf-8", errors="surrogateescape").split("\n") if ln]


def _unescape(s: str) -> str:
    """strace's C escapes in a printed path, back to the path."""
    if "\\" not in s:
        return s
    out = bytearray()
    i = 0
    raw = s.encode("utf-8", "surrogateescape")
    while i < len(raw):
        c = raw[i]
        if c == 0x5C and i + 1 < len(raw):
            n = chr(raw[i + 1])
            if n in "01234567":
                j = i + 1
                while j < len(raw) and j < i + 4 and chr(raw[j]) in "01234567":
                    j += 1
                out.append(int(raw[i + 1:j], 8) & 0xFF)
                i = j
                continue
            if n == "x" and i + 3 < len(raw) + 1:
                out.append(int(raw[i + 2:i + 4], 16))
                i += 4
                continue
            out.append({"n": 10, "t": 9, "r": 13, "v": 11, "f": 12}.get(n, raw[i + 1]))
            i += 2
            continue
        out.append(c)
        i += 1
    return out.decode("utf-8", "surrogateescape")


class Trace:
    """What one gate's run touched, sorted into reads, writes, listings and absences (absolute paths)."""

    def __init__(self):
        self.read = set()
        self.written = set()
        self.listed = {}       # {a folder listed: the names it saw}
        self.absent = set()
        self.offsite = []      # where it connected off this machine
        self.cfg_readers = {}  # {a ghost.cfg read: the pids that opened it}

    def add_line(self, line: str, cwd: list, pid: str = "") -> None:
        paren = line.find("(")
        if paren <= 0 or not line[:paren].isidentifier():
            return
        name = line[:paren]
        if name == "connect":
            self._connect(line)
            return
        shape = SHAPES.get(name)
        if shape is None or line.endswith("<unfinished ...>"):
            return
        r = _RET.search(line)
        if not r:
            return
        ok = r.group(1) not in ("-1", "?")
        err = r.group(2) or ""
        tokens = _TOKEN.findall(line[paren + 1:r.start() + 1])
        args = []
        base = None
        for kind, tok in zip(shape, tokens):
            if kind == "d":
                m = _FD.fullmatch(tok)
                if not m:
                    return
                base = _unescape(m.group(1))
                if tok.startswith("AT_FDCWD"):
                    cwd[0] = base
                if shape == "d":
                    args.append(base)
            else:
                m = _STR.fullmatch(tok)
                if not m:
                    return
                p = _unescape(m.group(1))
                if p == "":
                    base = None
                    continue  # AT_EMPTY_PATH: a call on the descriptor itself, already counted where it was opened
                if not p.startswith("/"):
                    p = os.path.join(base if base is not None else (cwd[0] or str(ROOT)), p)
                args.append(os.path.normpath(p))
                base = None
        if not args:
            return
        if name == "getdents64":
            names = self.listed.setdefault(args[0], set())
            if "}, ...]" in line:
                names.add("\0partial")  # an array strace cut short: what the gate saw is not known
            names.update(_unescape(n) for n in _NAME.findall(line))
        elif name in ("open", "openat", "openat2"):
            if any(f in line for f in WRITE_FLAGS):
                if ok:
                    self.written.add(args[0])
            elif ok:
                self.read.add(args[0])
                if args[0].endswith("/" + CFG_NAME):
                    self.cfg_readers.setdefault(args[0], set()).add(pid)
            elif err in ABSENT_ERRORS:
                self.absent.add(args[0])
        elif name in READS:
            if ok:
                self.read.add(args[0])
            elif err in ABSENT_ERRORS:
                self.absent.add(args[0])
        elif not ok:
            # A write that failed wrote nothing: a recursive mkdir calls mkdir on every folder above its
            # own, `/home` included, and each fails as already there.
            return
        elif name in ("symlink", "symlinkat", "link", "linkat"):
            self.written.add(args[-1])
        else:  # creat, mkdir, unlink, rmdir, truncate, rename: every path named is written
            self.written.update(args)

    def _connect(self, line: str) -> None:
        m = _INET.search(line)
        if m:
            port, v4, v6 = m.group(1), m.group(2), m.group(3)
            addr = v4 or v6 or ""
            if port == "53" or not (addr.startswith("127.") or addr == "::1"):
                self.offsite.append(f"{addr}:{port}")
            return
        m = _UNIX.search(line)
        if m and "resolve" in m.group(1):
            self.offsite.append(m.group(1))

    @classmethod
    def load(cls, folder: Path) -> "Trace":
        t = cls()
        for f in sorted(folder.glob("t.*")):
            cwd = [None]
            pid = f.name.split(".", 1)[1]
            with open(f, encoding="utf-8", errors="surrogateescape") as fh:
                for line in fh:
                    t.add_line(line.rstrip("\n"), cwd, pid)
        return t

    def inputs(self, scope: Scope) -> dict:
        """{path: kind}: `f` a file's bytes, `e` a folder that exists, `d` a folder's listing (the names
        are in [member listed]), `a` absent."""
        written = self.written
        scratch = written | {os.path.dirname(w) for w in written}

        def own(p: str) -> bool:
            """Written by the gate, or under a folder it made, moved or removed: its scratch."""
            while p not in ("", "/"):
                if p in written:
                    return True
                p = os.path.dirname(p)
            return False

        out = {}
        for p in self.absent:
            if scope.holds(p) and not own(p):
                out[p] = "a"
        for p in self.read:
            if scope.holds(p) and not own(p):
                out[p] = "f"  # a folder among them becomes `e` when it is hashed
        for p in self.listed:
            if scope.holds(p) and p not in scratch and not own(p):
                out[p] = "d"
        return out


# -- hashing --------------------------------------------------------------------

def cfg_values(text: str) -> dict:
    """{(section, key): the value's text} of a Godot ConfigFile. A value runs on over lines while a
    string or a bracket is open in it (a script's words, a dictionary)."""
    out = {}
    section = ""
    key = None
    depth = 0
    in_str = False
    buf = []
    for line in text.split("\n"):
        if key is None:
            s = line.strip()
            if not s or s.startswith(";"):
                continue
            if s.startswith("[") and s.endswith("]"):
                section = s[1:-1]
                continue
            k, eq, rest = line.partition("=")
            if not eq:
                continue
            key, buf, chunk = k.strip(), [], rest
        else:
            chunk = line
        buf.append(chunk)
        i = 0
        while i < len(chunk):
            c = chunk[i]
            if in_str:
                if c == "\\":
                    i += 1
                elif c == '"':
                    in_str = False
            elif c == '"':
                in_str = True
            elif c in "[{(":
                depth += 1
            elif c in "]})":
                depth -= 1
            i += 1
        if not in_str and depth <= 0:
            out[(section, key)] = "\n".join(buf)
            key, depth = None, 0
    if key is not None:
        out[(section, key)] = "\n".join(buf)
    return out


def settings_read(folder: Path) -> dict:
    """{pid: [(section, key), ...]} from the files Settings writes under GHOST_SETTINGS_READS."""
    out = {}
    if folder and folder.is_dir():
        for f in folder.iterdir():
            keys = []
            for line in f.read_text(encoding="utf-8", errors="surrogateescape").splitlines():
                section, tab, key = line.partition("\t")
                if tab:
                    keys.append((section, key))
            out[f.name] = keys
    return out


class Hashes:
    """Content hashes, remembered across runs by what a file's stat says."""

    def __init__(self, path: Path = None):
        self.path = path
        self.known = {}
        self.fresh = False
        self.cfgs = {}  # {path: (stamp, cfg_values)}
        if path and path.exists():
            for line in _lines(path):
                parts = line.split("\t", 2)
                if len(parts) == 3:
                    self.known[_dec(parts[2])] = (parts[0], parts[1])

    @staticmethod
    def listing(names) -> str:
        """A listing's state: its names, less `.`, `..` and the transient ones, hashed."""
        kept = sorted(n for n in names if n not in (".", "..") and not TRANSIENT.match(n))
        return "list:" + hashlib.sha1("\n".join(kept).encode("utf-8", "surrogateescape")).hexdigest()

    @staticmethod
    def _stamp(st) -> str:
        return f"{st.st_dev}:{st.st_ino}:{st.st_size}:{st.st_mtime_ns}:{st.st_ctime_ns}"

    def state(self, path: str, kind: str) -> str:
        """What a path is now, in the record's terms: a file's hash, `dir`, a listing's hash, `absent`."""
        try:
            st = os.stat(path)
        except OSError:
            return "absent"
        if kind == "d":
            try:
                return self.listing(os.listdir(path))
            except OSError:
                return "absent"
        if os.path.isdir(path):
            return "dir"
        if kind == "a":
            return "present"
        stamp = self._stamp(st)
        hit = self.known.get(path)
        if hit and hit[0] == stamp:
            return hit[1]
        h = hashlib.sha1()
        try:
            with open(path, "rb") as fh:
                for chunk in iter(lambda: fh.read(1 << 20), b""):
                    h.update(chunk)
        except OSError:
            return "unreadable"
        self.known[path] = (stamp, h.hexdigest())
        self.fresh = True
        return h.hexdigest()

    def key_state(self, path: str, section: str, key: str) -> str:
        """A settings key's value now, hashed: `absent` when the file or the key is."""
        try:
            stamp = self._stamp(os.stat(path))
        except OSError:
            return "absent"
        hit = self.cfgs.get(path)
        if not hit or hit[0] != stamp:
            try:
                text = Path(path).read_text(encoding="utf-8", errors="surrogateescape")
            except OSError:
                return "absent"
            hit = (stamp, cfg_values(text))
            self.cfgs[path] = hit
        value = hit[1].get((section, key))
        if value is None:
            return "absent"
        return hashlib.sha1(value.encode("utf-8", "surrogateescape")).hexdigest()

    def save(self) -> None:
        if not self.path or not self.fresh:
            return
        self.path.parent.mkdir(parents=True, exist_ok=True)
        fd, tmp = tempfile.mkstemp(dir=self.path.parent, prefix=".hashes.")
        with os.fdopen(fd, "w", encoding="utf-8", errors="surrogateescape") as fh:
            for p, (stamp, h) in sorted(self.known.items()):
                if os.path.exists(p):
                    fh.write(f"{stamp}\t{h}\t{_enc(p)}\n")
        os.replace(tmp, self.path)


# -- records --------------------------------------------------------------------

def read_meta(path: Path, gate: str) -> dict:
    """The meta a gate's record must match: every `key value` line of check.sh's meta file, with
    `how:<gate>` read as this gate's `how`."""
    out = {}
    for line in path.read_text().splitlines():
        key, _, value = line.partition(" ")
        if key.startswith("how:"):
            if key == f"how:{gate}":
                out["how"] = value
        elif key:
            out[key] = value
    return out


def write_record(out: Path, meta: dict, entries: dict) -> None:
    """[entries] {path: (kind, state)}; a ghost.cfg key's path is `file\\0section\\0key`."""
    lines = [f"m\t{k}\t{_enc(v)}" for k, v in sorted(meta.items())]
    lines += [f"{kind}\t{state}\t" + "\t".join(_enc(x) for x in p.split("\0"))
              for p, (kind, state) in sorted(entries.items())]
    out.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=out.parent, prefix=f".{out.name}.")
    with os.fdopen(fd, "w", encoding="utf-8", errors="surrogateescape") as fh:
        fh.write("\n".join(lines) + "\n")
    os.replace(tmp, out)


def read_record(path: Path):
    meta, entries = {}, []
    for line in _lines(path):
        parts = line.split("\t", 2)
        if len(parts) != 3:
            continue
        if parts[0] == "m":
            meta[parts[1]] = _dec(parts[2])
        else:
            entries.append((parts[0], parts[1], "\0".join(_dec(x) for x in parts[2].split("\t"))))
    return meta, entries


def why_runs(record: Path, meta: dict, hashes: Hashes, root: Path) -> str:
    """'' when the record still holds, else the first thing that changed, in a few words."""
    if not record.exists():
        return "no pass recorded"
    old_meta, entries = read_record(record)
    for k in sorted(set(old_meta) | set(meta)):
        if old_meta.get(k) != meta.get(k):
            return f"{k} changed"
    for kind, state, p in entries:
        if kind == "k":
            path, section, key = p.split("\0", 2)
            if hashes.key_state(path, section, key) != state:
                return f"{os.path.basename(path)} [{section}] {key} changed"
            continue
        if hashes.state(p, kind) != state:
            shown = os.path.relpath(p, root) if p.startswith(str(root)) else p
            what = {"a": "appeared", "d": "listing changed"}.get(kind, "changed")
            return f"{shown} {what}"
    return ""


def make_record(trace: Trace, scope: Scope, hashes: Hashes, start_ns: int, reads: dict = None,
                cfg_start: Path = None):
    """(entries, '') for a pass worth keeping, or (None, why not). [reads] is what Settings said each
    process read, [cfg_start] check.sh's copy of ghost.cfg from before the gate started."""
    if trace.offsite:
        return None, f"it connected off this machine ({trace.offsite[0]})"
    entries = {}
    inputs = trace.inputs(scope)
    for cfg, pids in trace.cfg_readers.items():
        if inputs.get(cfg) != "f" or reads is None or not all(pid in reads for pid in pids):
            continue  # a process read it without saying which keys: the whole file is the input
        del inputs[cfg]
        start = cfg_values(cfg_start.read_text(encoding="utf-8", errors="surrogateescape")) \
            if cfg_start and cfg_start.exists() else {}
        for pid in pids:
            for section, key in reads[pid]:
                state = hashes.key_state(cfg, section, key)
                was = start.get((section, key))
                was = "absent" if was is None else hashlib.sha1(was.encode("utf-8", "surrogateescape")).hexdigest()
                if state != was:
                    return None, f"{CFG_NAME} [{section}] {key} changed during the run"
                entries[f"{cfg}\0{section}\0{key}"] = ("k", state)
    if not any(p.startswith(scope.root) for p in inputs) and not any(c.startswith(scope.root) for c in entries):
        # every gate reads at least its own script: a trace with nothing in the repo was misread
        return None, "it read nothing in the repo, so its trace cannot be trusted"
    for p, kind in inputs.items():
        if kind == "d":
            seen = trace.listed[p]
            if "\0partial" in seen:
                return None, f"strace cut short the listing of {p}"
            entries[p] = ("d", hashes.listing(seen))
            continue
        state = hashes.state(p, kind)
        if kind == "a":
            if state != "absent":
                return None, f"{p} appeared during the run"
            entries[p] = ("a", "absent")
            continue
        if state == "absent":
            if kind == "f":  # read, then removed by something else: what it read is gone
                return None, f"{p} went away during the run"
            continue
        if state == "dir":  # a folder it only found: what is in it is not what it read
            entries[p] = ("e", state)
            continue
        try:
            st = os.stat(p)
        except OSError:
            continue
        if st.st_ctime_ns > start_ns:
            return None, f"{p} changed during the run"
        entries[p] = (kind, state)
    return entries, ""


# -- commands -------------------------------------------------------------------

def _arg(argv, name, default=None):
    if name in argv:
        i = argv.index(name)
        return argv[i + 1]
    return default


def cmd_check(argv) -> int:
    folder = Path(_arg(argv, "--dir"))
    meta_path = Path(_arg(argv, "--meta"))
    gates = [a for i, a in enumerate(argv) if not a.startswith("--") and (i == 0 or argv[i - 1] not in ("--dir", "--meta"))]
    hashes = Hashes(folder / ".hashes")
    for g in gates:
        why = why_runs(folder / g, read_meta(meta_path, g), hashes, ROOT)
        print(f"{g}\t{why or 'cached'}")
    hashes.save()
    return 0


def cmd_record(argv) -> int:
    folder = Path(_arg(argv, "--dir"))
    gate = _arg(argv, "--gate")
    trace = Trace.load(Path(_arg(argv, "--trace")))
    hashes = Hashes(folder / ".hashes")
    reads = _arg(argv, "--settings-reads")
    cfg_start = _arg(argv, "--cfg-start")
    entries, why = make_record(trace, Scope(ROOT, user_dir()), hashes, int(_arg(argv, "--start")),
                               settings_read(Path(reads)) if reads else None, Path(cfg_start) if cfg_start else None)
    out = Path(_arg(argv, "--out", str(folder / gate)))
    if entries is None:
        print(f"gate_cache: {gate} is not kept: {why}")
        out.unlink(missing_ok=True)
        return 1
    write_record(out, read_meta(Path(_arg(argv, "--meta")), gate), entries)
    return 0


def cmd_show(argv) -> int:
    trace = Trace.load(Path(_arg(argv, "--trace")))
    scope = Scope(ROOT, user_dir())
    inputs = trace.inputs(scope)
    for kind in "fdea":
        ps = sorted(p for p, k in inputs.items() if k == kind)
        print(f"{kind}: {len(ps)}")
        for p in ps:
            print(f"    {p}")
    written = sorted(p for p in trace.written if scope.holds(p))
    print(f"written: {len(written)}")
    for p in written:
        print(f"    {p}")
    for o in trace.offsite:
        print(f"offsite: {o}")
    return 0


# -- the control ----------------------------------------------------------------

def selftest() -> int:
    """Plant a repo, a trace and changes in a scratch folder; every change a gate could see must make
    it run, and nothing else may."""
    failures = []

    def expect(what, got, want):
        if got != want:
            failures.append(f"{what}: got {got!r}, want {want!r}")

    with tempfile.TemporaryDirectory() as tmp:
        root, user = Path(tmp) / "repo", Path(tmp) / "user"
        for d in ("src", "tests", "dist", "data/scenes", "scratch"):
            (root / d).mkdir(parents=True)
        user.mkdir()
        (root / "src/a.gd").write_text("a")
        (root / "src/b.gd").write_text("b")
        (root / "src/unread.gd").write_text("u")
        (root / "data/scenes/one.json").write_text("{}")
        (root / "dist/log.txt").write_text("log")
        (user / "ghost.cfg").write_text("cfg")
        r = str(root)
        lines = [
            f'openat(AT_FDCWD<{r}>, "src/a.gd", O_RDONLY|O_CLOEXEC) = 3<{r}/src/a.gd>',
            f'newfstatat(AT_FDCWD<{r}>, "{r}/src/b.gd", {{st_mode=S_IFREG|0644}}, 0) = 0',
            f'openat(AT_FDCWD<{r}>, "{r}/src/gone.gd", O_RDONLY) = -1 ENOENT (No such file or directory)',
            f'getdents64(4<{r}/data/scenes>, [{{d_ino=1, d_type=DT_DIR, d_name="."}}, {{d_ino=2, d_type=DT_DIR, '
            f'd_name=".."}}, {{d_ino=3, d_type=DT_REG, d_name="one.json"}}], 32768) = 80',
            f'getdents64(4<{r}/data/scenes>, [], 32768) = 0',
            f'openat(AT_FDCWD<{r}>, "{r}/dist/log.txt", O_RDONLY) = 3<{r}/dist/log.txt>',
            f'openat(AT_FDCWD<{r}>, "{r}/scratch/out.txt", O_WRONLY|O_CREAT|O_TRUNC, 0644) = 5<{r}/scratch/out.txt>',
            f'openat(AT_FDCWD<{r}>, "{r}/scratch/out.txt", O_RDONLY) = 5<{r}/scratch/out.txt>',
            f'getdents64(6<{r}/scratch>, [{{d_ino=4, d_type=DT_REG, d_name="out.txt"}}], 32768) = 32',
            f'openat(AT_FDCWD<{r}>, "{r}/data", O_RDONLY|O_CLOEXEC|O_DIRECTORY) = 7<{r}/data>',
            f'openat(AT_FDCWD<{r}>, "{user}/made/deep/x.json", O_RDONLY) = 8<{user}/made/deep/x.json>',
            f'rename("{user}/made", "{user}/.trash/made") = 0',
            f'openat(AT_FDCWD<{r}>, "{r}/src/odd\\nname\\tx.gd", O_RDONLY) = -1 ENOENT (No such file or directory)',
            f'mkdir("{tmp}", 0777) = -1 EEXIST (File exists)',
            f'mkdir("{r}", 0777) = -1 EEXIST (File exists)',
            f'openat(AT_FDCWD<{r}>, "{r}/src/b.gd", O_WRONLY|O_CREAT|O_TRUNC, 0644) = -1 EACCES (Permission denied)',
            f'openat(AT_FDCWD</>, "{user}/ghost.cfg", O_RDONLY) = 3<{user}/ghost.cfg>',
            'openat(AT_FDCWD</>, "/usr/lib/libc.so.6", O_RDONLY|O_CLOEXEC) = 3</usr/lib/libc.so.6>',
            f'statx(9<{r}>, "", AT_STATX_SYNC_AS_STAT|AT_EMPTY_PATH, STATX_TYPE, {{}}) = 0',
            f'openat(AT_FDCWD<{r}/te\\"sts>, "x", O_RDONLY) = -1 EACCES (Permission denied)',
        ]
        tdir = Path(tmp) / "trace"
        tdir.mkdir()
        (tdir / "t.100").write_text("\n".join(lines) + "\n")
        scope = Scope(root, user)
        trace = Trace.load(tdir)
        inputs = trace.inputs(scope)
        expect("inputs", sorted((os.path.relpath(p, tmp), k) for p, k in inputs.items()), [
            ("repo/data", "f"), ("repo/data/scenes", "d"), ("repo/src/a.gd", "f"), ("repo/src/b.gd", "f"),
            ("repo/src/gone.gd", "a"), ("repo/src/odd\nname\tx.gd", "a"), ("user/ghost.cfg", "f")])
        expect("names seen", trace.listed[str(root / "data/scenes")], {".", "..", "one.json"})

        cache = Path(tmp) / "cache"
        meta_file = Path(tmp) / "meta"
        meta_file.write_text("godot 4.7\nhow:g boot probe, 120s\nhow:other script\n")
        meta = read_meta(meta_file, "g")
        expect("meta", meta, {"godot": "4.7", "how": "boot probe, 120s"})
        import time
        start = time.time_ns()
        time.sleep(0.01)
        entries, why = make_record(trace, scope, Hashes(), start)
        expect("files written before the start are kept", why, "")
        entries, why = make_record(trace, scope, Hashes(), start - 10 ** 12)
        expect("a file changed after the start is not kept", entries is None, True)
        (root / "data/later.json").write_text("{}")
        (root / "data/scenes/later.json").write_text("{}")
        entries, why = make_record(trace, scope, Hashes(), start)
        expect("a folder it only found, written into after the start, does not stop the pass", why, "")
        write_record(cache / "g", meta, entries)
        expect("a file written into a folder it listed after it listed it: it runs, never cached on what it missed",
               why_runs(cache / "g", meta, Hashes(), root), f"data/scenes listing changed")
        (root / "data/later.json").unlink()
        (root / "data/scenes/later.json").unlink()
        cut = Trace()
        cut.add_line(f'getdents64(4<{r}/data/scenes>, [{{d_ino=1, d_name="a"}}, ...], 32768) = 80', [None])
        expect("a listing strace cut short is not kept", make_record(cut, scope, Hashes(), time.time_ns())[0], None)
        entries, _ = make_record(trace, scope, Hashes(), time.time_ns())
        write_record(cache / "g", meta, entries)

        def runs() -> str:
            return why_runs(cache / "g", read_meta(meta_file, "g"), Hashes(cache / ".hashes"), root)

        expect("nothing changed", runs(), "")
        change_odd = root / "src/odd\nname\tx.gd"
        (root / "src/unread.gd").write_text("u2")
        (root / "dist/log.txt").write_text("log2")
        (root / "scratch/new.txt").write_text("n")
        (root / "data/scenes/_probe_123.tscn").write_text("p")
        expect("a file it never read, an output and a transient probe scene changed", runs(), "")
        (root / "data/scenes/_probe_123.tscn").unlink()

        def change(what, do, undo):
            do()
            expect(what, runs() != "", True)
            undo()
            expect(f"{what}, undone", runs(), "")

        change("a file it read", lambda: (root / "src/a.gd").write_text("A"), lambda: (root / "src/a.gd").write_text("a"))
        change("a file it stat'ed", lambda: (root / "src/b.gd").write_text("B"), lambda: (root / "src/b.gd").write_text("b"))
        change("a file in user://", lambda: (user / "ghost.cfg").write_text("x"), lambda: (user / "ghost.cfg").write_text("cfg"))
        change("a file it looked for appearing", lambda: (root / "src/gone.gd").write_text("g"),
               lambda: (root / "src/gone.gd").unlink())
        change("a file added to a folder it listed", lambda: (root / "data/scenes/two.json").write_text("{}"),
               lambda: (root / "data/scenes/two.json").unlink())
        change("a path holding a newline and a tab appearing", lambda: change_odd.write_text("o"),
               lambda: change_odd.unlink())
        change("its run line", lambda: meta_file.write_text("godot 4.7\nhow:g boot probe, 300s\n"),
               lambda: meta_file.write_text("godot 4.7\nhow:g boot probe, 120s\n"))
        change("Godot", lambda: meta_file.write_text("godot 4.8\nhow:g boot probe, 120s\n"),
               lambda: meta_file.write_text("godot 4.7\nhow:g boot probe, 120s\n"))

        # the same bytes written again (a checkout, an editor's save) keep the pass; a remembered hash
        # is never trusted across a write, whatever its mtime says
        st = os.stat(root / "src/a.gd")
        (root / "src/a.gd").write_text("Z")
        os.utime(root / "src/a.gd", ns=(st.st_atime_ns, st.st_mtime_ns))
        expect("new bytes behind an old mtime", runs() != "", True)
        (root / "src/a.gd").write_text("a")
        expect("the same bytes written again", runs(), "")

        # ghost.cfg by the keys read: another key, even one in a value of many lines, is not an input
        cfg = user / "ghost.cfg"
        text = ('[director]\n\npacing=0.5\nmode="calm"\n\n[synth]\n\ntext="One line.\nx=1 inside the words\n'
                '"\ncast={\n"a": [1, 2]\n}\n')
        cfg.write_text(text)
        expect("cfg values", cfg_values(text), {("director", "pacing"): "0.5", ("director", "mode"): '"calm"',
               ("synth", "text"): '"One line.\nx=1 inside the words\n"', ("synth", "cast"): '{\n"a": [1, 2]\n}'})
        reads_dir = Path(tmp) / "reads"
        reads_dir.mkdir()
        (reads_dir / "100").write_text("director\tpacing\nsynth\ttext\nsynth\tgone\n")
        start_copy = Path(tmp) / "cfg.start"
        start_copy.write_text(text)
        entries, why = make_record(trace, scope, Hashes(), time.time_ns(), settings_read(reads_dir), start_copy)
        expect("keyed", sorted(e[0] for e in entries.values()), ["a", "a", "d", "e", "f", "f", "k", "k", "k"])
        write_record(cache / "g", meta, entries)
        expect("keyed, nothing changed", runs(), "")
        cfg.write_text(text.replace('"calm"', '"busy"').replace('[1, 2]', '[3]'))
        expect("a key it never read changed", runs(), "")
        cfg.write_text(text.replace("0.5", "0.7"))
        expect("a key it read changed", runs(), "ghost.cfg [director] pacing changed")
        cfg.write_text(text.replace("inside the words", "inside other words"))
        expect("a line of a long value changed", runs(), "ghost.cfg [synth] text changed")
        cfg.write_text(text + "[synth]\ngone=1\n")
        expect("a key it looked for appeared", runs() != "", True)
        cfg.write_text(text)
        start_copy.write_text(text.replace("0.5", "0.6"))
        expect("a key changed during the run is not kept",
               make_record(trace, scope, Hashes(), time.time_ns(), settings_read(reads_dir), start_copy)[0], None)
        (reads_dir / "100").rename(reads_dir / "999")
        entries, _ = make_record(trace, scope, Hashes(), time.time_ns(), settings_read(reads_dir), start_copy)
        expect("a process that never said which keys keeps the whole file",
               entries.get(str(cfg)), ("f", hashlib.sha1(text.encode()).hexdigest()))

        outside = Trace()
        outside.add_line('openat(AT_FDCWD</>, "/usr/lib/libc.so.6", O_RDONLY) = 3</usr/lib/libc.so.6>', [None])
        outside.add_line(f'openat(AT_FDCWD</>, "{user}/ghost.cfg", O_RDONLY) = 3<{user}/ghost.cfg>', [None])
        expect("a trace with nothing in the repo is not kept", make_record(outside, scope, Hashes(), time.time_ns())[0], None)

        off = Trace()
        off.add_line('connect(7, {sa_family=AF_INET, sin_port=htons(443), sin_addr=inet_addr("140.82.112.3")}, 16) = 0', [None])
        off.add_line('connect(8, {sa_family=AF_INET, sin_port=htons(8765), sin_addr=inet_addr("127.0.0.1")}, 16) = 0', [None])
        expect("off this machine", off.offsite, ["140.82.112.3:443"])
        expect("an offsite gate is not kept", make_record(off, scope, Hashes(), time.time_ns())[0], None)
        expect("unescape", _unescape('a\\"b\\\\c\\303\\251'), 'a"b\\cé')

    for f in failures:
        print(f"gate_cache: FAIL {f}")
    print("gate_cache: " + ("ALL OK" if not failures else f"{len(failures)} FAILED"))
    return 1 if failures else 0


def main(argv) -> int:
    if argv[:1] == ["--selftest"]:
        return selftest()
    if argv[:1] == ["user-dir"]:
        print(user_dir())
        return 0
    if argv[:1] == ["strace"]:
        print(f"{STRACE} -e trace={CALLS}")
        return 0
    commands = {"check": cmd_check, "record": cmd_record, "show": cmd_show}
    if not argv or argv[0] not in commands:
        print(__doc__)
        return 2
    return commands[argv[0]](argv[1:])


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
