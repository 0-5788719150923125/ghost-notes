#!/usr/bin/env python3
"""Run a solver's Python code in a sandbox, and keep the numbers it measured.

    run.py <spec.json>                      the host: runs the code, writes the answer to spec["out"]
    run.py --inner <code.py> <kept.json>    inside the sandbox: runs the code, with keep()

THE WORK SHOWN IS THE WORK DONE (next/proof.md): a claim about a model, a simulation or data is
settled by code that really ran, and a drawing on the pad plots the numbers that code kept - never
numbers an agent typed. A Proof solver hands its code to the `run` tool (ProofTools); this runs it.

The spec is JSON - never argv: {"code", "out", "work", "io", "seconds", "memory_mb", "work_mb",
"bwrap"} (`work_mb` may only lower the folder's cap).
`work` is the code's folder, kept across one solver's runs (a run may save a file the next one
loads); `io` is this run's own folder, outside `work`: the code, and what it printed.

THE CODE RUNS IN A SANDBOX. bubblewrap (`bwrap`, Linux) gives it a filesystem of its own: the
system's programs and libraries and this Python, read-only; `work`, the one place it may write; a
fresh /tmp; no home folder and nothing else of the author's. It has no network, sees no other
process, and holds no privileges. The host caps its memory (`memory_mb`, its address space), its
processor time, the size of any file it writes and of its folder, and kills it at `seconds` of wall
time. Without bwrap nothing runs (ProofTools.can_run does not offer the tool).

keep(name, y) or keep(name, x, y), inside the code: a named series - y against x, or against 0, 1,
2, ... - kept for the lesson's drawings (figure.py's <plot data>, <dots data>, <bars data>), with an
optional about="what it is". numpy arrays are taken as they are; every value must be a finite
number. The host checks what comes back again: the code could have written the file itself.

The answer, written to `out`:

    {"ok", "exit", "timed_out", "seconds", "stdout", "stderr", "kept": {name: {"points", "about"}},
     "work_mb", "error"}

`stdout` and `stderr` are cut to their first and last few thousand characters. Exit 0 with the
answer written whatever the code did; anything else is a failure, with the reason on stderr.
"""

import json
import math
import os
import pathlib
import re
import resource
import signal
import subprocess
import sys
import time

## The most characters of printed output handed back, from each end.
HEAD = 4000
TAIL = 4000
## Kept series: how many, how many points each, a name's form.
MOST_SERIES = 40
MOST_POINTS = 5000
NAME = re.compile(r"^[A-Za-z][A-Za-z0-9_]{0,39}$")
## Where the code's keep() writes, inside `work`.
KEPT = ".kept.json"
## The largest file the code may write (bytes), the most files it may hold open, and how big its
## /tmp may grow (MB; it is memory).
FILE_MAX = 64 * 1024 * 1024
FILES_OPEN = 256
TMP_MB = 256
## How big its folder - a real disk, kept between runs - may grow (MB).
WORK_MB = 512
## Threads the numeric libraries may use; the processor time a run may take is this many times its
## wall time, and a little more.
THREADS = 4
## The time and memory a run may ask for, and what it gets unasked.
SECONDS = (1.0, 600.0, 60.0)
MEMORY_MB = (256, 16384, 4096)
## What of the system the sandbox sees, read-only: the programs and libraries, the links a merged
## /usr leaves at the root, and the dynamic loader's cache.
SYSTEM = ("/usr",)
LINKS = ("/bin", "/sbin", "/lib", "/lib64", "/lib32")
ETC = ("/etc/ld.so.cache", "/etc/ld.so.conf", "/etc/ld.so.conf.d", "/etc/localtime")
## The exit statuses a run can end with that are not its own (128 + a signal).
SIGNALLED = {
    128 + signal.SIGKILL: "it was killed",
    128 + signal.SIGXCPU: "it used up its processor time",
    128 + signal.SIGXFSZ: "it wrote a file past the size limit",
    128 + signal.SIGSEGV: "it crashed (a segmentation fault)",
}


# --- inside the sandbox ---------------------------------------------------------------------------

def _numbers(v):
    if hasattr(v, "tolist"):
        v = v.tolist()
    if not isinstance(v, (list, tuple)):
        raise TypeError("keep takes a flat list of numbers")
    out = []
    for a in v:
        if hasattr(a, "item") and not isinstance(a, (list, tuple)):
            a = a.item()
        if isinstance(a, bool) or not isinstance(a, (int, float)):
            raise TypeError("keep takes a flat list of numbers")
        a = float(a)
        if not math.isfinite(a):
            raise ValueError("keep: every value must be a finite number (no nan or inf)")
        out.append(a)
    return out


def inner(code_path, kept_path):
    """Run the code as __main__ with keep() among the builtins; the series kept are written whatever
    happens. The code's own traceback is printed without this runner's frame."""
    import builtins
    import traceback

    kept = {}

    def keep(name, *values, about=""):
        if not isinstance(name, str) or not NAME.match(name):
            raise ValueError("keep: a name is a letter, then letters, digits or _ (at most 40)")
        if len(values) == 1:
            ys = _numbers(values[0])
            xs = [float(i) for i in range(len(ys))]
        elif len(values) == 2:
            xs, ys = _numbers(values[0]), _numbers(values[1])
        else:
            raise TypeError("keep(name, y) or keep(name, x, y)")
        if len(xs) != len(ys):
            raise ValueError("keep: x has %d values and y has %d" % (len(xs), len(ys)))
        if not ys or len(ys) > MOST_POINTS:
            raise ValueError("keep: a series has 1 to %d values, not %d" % (MOST_POINTS, len(ys)))
        if name not in kept and len(kept) >= MOST_SERIES:
            raise ValueError("keep: at most %d series in one run" % MOST_SERIES)
        kept[name] = {"points": [[x, y] for x, y in zip(xs, ys)], "about": str(about)[:200]}

    import linecache

    builtins.keep = keep
    status = 0
    try:
        src = pathlib.Path(code_path).read_text(encoding="utf-8")
        # a traceback shows the code's own lines, under the name it was given
        linecache.cache["run.py"] = (len(src), None, src.splitlines(True), "run.py")
        code = compile(src, "run.py", "exec")
        exec(code, {"__name__": "__main__", "__file__": "run.py", "__builtins__": builtins})
    except SystemExit as e:
        status = e.code if isinstance(e.code, int) else (0 if e.code is None else 1)
    except BaseException as e:  # the code's own error, printed as Python prints it, this runner's frames left out
        tb = traceback.TracebackException.from_exception(e)
        me = os.path.realpath(__file__)
        tb.stack = traceback.StackSummary.from_list([f for f in tb.stack if os.path.realpath(f.filename) != me])
        sys.stderr.write("".join(tb.format()))
        status = 1
    finally:
        try:
            pathlib.Path(kept_path).write_text(json.dumps(kept), encoding="utf-8")
        except OSError:
            pass
    sys.stdout.flush()
    sys.stderr.flush()
    return status


# --- the host -------------------------------------------------------------------------------------

def _dir_links(path, depth=0):
    """The links to folders met on the way to [path]'s real file, by the paths that name them (uv's
    environment names its Python through `cpython-3.14-...`, a link to `cpython-3.14.8-...`)."""
    out = []
    parts = pathlib.PurePosixPath(os.path.abspath(path)).parts
    cur = "/"
    for i, part in enumerate(parts[1:], 1):
        nxt = os.path.join(cur, part)
        if os.path.islink(nxt):
            if os.path.isdir(nxt):
                out.append(nxt)
            target = os.readlink(nxt)
            target = target if os.path.isabs(target) else os.path.join(cur, target)
            if depth < 16:
                out += _dir_links(os.path.join(target, *parts[i + 1:]), depth + 1)
            return out
        cur = nxt
    return out


def _python_dirs():
    """The folders this Python is made of: the environment, the install it was made from, and every
    linked folder its interpreter is reached through."""
    out = []
    for d in [sys.prefix, sys.base_prefix] + _dir_links(sys.executable):
        for p in (d, os.path.realpath(d)):
            if p not in out:
                out.append(p)
    return out


def sandbox_argv(bwrap, work, io, inner_argv):
    """bwrap's command line around [inner_argv]: see the module's note."""
    argv = [bwrap, "--unshare-all", "--die-with-parent", "--new-session", "--cap-drop", "ALL",
            "--clearenv", "--setenv", "PATH", "/usr/bin:/bin", "--setenv", "HOME", work,
            "--setenv", "LANG", "C.UTF-8", "--setenv", "TMPDIR", "/tmp"]
    for k in ("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS"):
        argv += ["--setenv", k, str(THREADS)]
    for d in SYSTEM:
        argv += ["--ro-bind", d, d]
    for d in LINKS:
        if os.path.islink(d):
            argv += ["--symlink", os.readlink(d), d]
        elif os.path.isdir(d):
            argv += ["--ro-bind", d, d]
    for f in ETC:
        argv += ["--ro-bind-try", f, f]
    argv += ["--proc", "/proc", "--dev", "/dev"]
    # /tmp is memory: a bwrap that can size it holds it to TMP_MB
    argv += (["--size", str(TMP_MB << 20)] if _bwrap_version(bwrap) >= (0, 10) else []) + ["--tmpfs", "/tmp"]
    for d in _python_dirs():
        argv += ["--ro-bind", d, d]
    here = os.path.dirname(os.path.realpath(__file__))
    argv += ["--ro-bind", here, here, "--ro-bind", io, io, "--bind", work, work]
    # the root the folders above were made in is memory too, and nothing is written there
    argv += ["--remount-ro", "/", "--chdir", work]
    return argv + inner_argv


def _bwrap_version(bwrap):
    try:
        said = subprocess.run([bwrap, "--version"], capture_output=True, text=True, timeout=10).stdout
        m = re.search(r"(\d+)\.(\d+)", said)
        return (int(m.group(1)), int(m.group(2))) if m else (0, 0)
    except (OSError, subprocess.SubprocessError):
        return (0, 0)


def _limits(memory_mb, cpu_seconds):
    def apply():
        # the run dies with this host, whatever kills it
        try:
            import ctypes
            ctypes.CDLL(None).prctl(1, signal.SIGKILL)  # PR_SET_PDEATHSIG
        except (OSError, AttributeError):
            pass
        resource.setrlimit(resource.RLIMIT_AS, (memory_mb << 20, memory_mb << 20))
        resource.setrlimit(resource.RLIMIT_CPU, (cpu_seconds, cpu_seconds + 5))
        resource.setrlimit(resource.RLIMIT_FSIZE, (FILE_MAX, FILE_MAX))
        resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
        resource.setrlimit(resource.RLIMIT_NOFILE, (FILES_OPEN, FILES_OPEN))
    return apply


def _ends(path):
    try:
        t = pathlib.Path(path).read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""
    if len(t) <= HEAD + TAIL:
        return t
    return "%s\n... (%d characters left out) ...\n%s" % (t[:HEAD], len(t) - HEAD - TAIL, t[-TAIL:])


def _kept(path):
    """The series in the code's kept file, checked again: the code may have written it itself."""
    try:
        d = json.loads(pathlib.Path(path).read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}
    out = {}
    if not isinstance(d, dict):
        return out
    for name, s in d.items():
        if len(out) >= MOST_SERIES or not isinstance(name, str) or not NAME.match(name) or not isinstance(s, dict):
            continue
        pts = s.get("points")
        if not isinstance(pts, list) or not 0 < len(pts) <= MOST_POINTS:
            continue
        good = []
        for p in pts:
            if (isinstance(p, list) and len(p) == 2 and all(isinstance(v, (int, float)) and not isinstance(v, bool)
                                                           and math.isfinite(v) for v in p)):
                good.append([float(p[0]), float(p[1])])
        if len(good) == len(pts):
            out[name] = {"points": good, "about": str(s.get("about", ""))[:200]}
    return out


def _size_mb(folder):
    total = 0
    for root, _dirs, files in os.walk(folder):
        for f in files:
            try:
                total += os.lstat(os.path.join(root, f)).st_size
            except OSError:
                pass
    return total / (1024 * 1024)


def _within(v, lo_hi_default, kind):
    lo, hi, default = lo_hi_default
    try:
        return min(max(kind(v), lo), hi)
    except (TypeError, ValueError):
        return default


def run(spec):
    bwrap = str(spec.get("bwrap", ""))
    if not bwrap or not os.access(bwrap, os.X_OK):
        return {"ok": False, "error": "no sandbox: bubblewrap (bwrap) is not installed, so nothing runs"}
    work = os.path.realpath(spec["work"])
    io = os.path.realpath(spec["io"])
    os.makedirs(work, exist_ok=True)
    os.makedirs(io, exist_ok=True)
    seconds = _within(spec.get("seconds"), SECONDS, float)
    memory = _within(spec.get("memory_mb"), MEMORY_MB, int)
    work_mb = _within(spec.get("work_mb"), (1, WORK_MB, WORK_MB), int)
    code_path = os.path.join(io, "code.py")
    pathlib.Path(code_path).write_text(str(spec.get("code", "")), encoding="utf-8")
    kept_path = os.path.join(work, KEPT)
    if os.path.lexists(kept_path):
        os.remove(kept_path)
    inner_argv = [sys.executable, "-I", "-B", os.path.realpath(__file__), "--inner", code_path, kept_path]
    argv = sandbox_argv(bwrap, work, io, inner_argv)
    out_path, err_path = os.path.join(io, "stdout.txt"), os.path.join(io, "stderr.txt")
    t0 = time.monotonic()
    timed_out = False
    too_big = False
    with open(out_path, "wb") as so, open(err_path, "wb") as se:
        p = subprocess.Popen(argv, stdin=subprocess.DEVNULL, stdout=so, stderr=se, close_fds=True,
                             env={"PATH": "/usr/bin:/bin"}, start_new_session=True,
                             preexec_fn=_limits(memory, int(seconds * THREADS) + 10))
        # the folder is a real disk: a run that fills it past WORK_MB (and past where it began) is stopped
        start_mb = _size_mb(work)
        while True:
            try:
                p.wait(timeout=0.5)
                break
            except subprocess.TimeoutExpired:
                pass
            if time.monotonic() - t0 >= seconds:
                timed_out = True
            elif _size_mb(work) > max(work_mb, start_mb):
                too_big = True
            if timed_out or too_big:
                try:
                    os.killpg(p.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                p.wait()
                break
    took = time.monotonic() - t0
    stderr = _ends(err_path)
    answer = {"ok": True, "exit": p.returncode, "timed_out": timed_out, "seconds": round(took, 2),
              "stdout": _ends(out_path), "stderr": stderr, "kept": _kept(kept_path),
              "work_mb": round(_size_mb(work), 1), "error": ""}
    if os.path.lexists(kept_path):
        os.remove(kept_path)
    if timed_out:
        answer["error"] = "stopped at %.0f s, the run's time limit" % seconds
    elif too_big:
        answer["error"] = "stopped: its folder grew past %d MB - delete what it no longer needs" % work_mb
    elif p.returncode in SIGNALLED:
        answer["error"] = SIGNALLED[p.returncode]
    elif p.returncode != 0 and stderr.startswith("bwrap:"):
        answer["ok"] = False
        answer["error"] = "the sandbox could not start: " + stderr.strip()[:400]
    return answer


def main():
    if len(sys.argv) == 4 and sys.argv[1] == "--inner":
        return inner(sys.argv[2], sys.argv[3])
    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    spec = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
    answer = run(spec)
    out = pathlib.Path(spec["out"])
    tmp = out.with_suffix(out.suffix + ".part")
    tmp.write_text(json.dumps(answer), encoding="utf-8")
    os.replace(tmp, out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
