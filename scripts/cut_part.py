"""Cut one part out of a big GDScript class into a script of its own, with every reference
between the two rewritten - so that what the part reads of its owner is written down (`t.x`).
next/structure.md, "One file, one job"; it cut TableShuffle and Masking's three parts.

    python scripts/cut_part.py <spec.json> report     # what would move, and what it touches
    python scripts/cut_part.py <spec.json> apply      # then scripts/cut_part_names.py <spec.json>

THE TRAPS, each met once:
- NEVER MOVE A METHOD A SUBCLASS OVERRIDES (list it in `keep`): the part would call its own copy
  and the override would go quiet, with nothing to say so. reading_panel.gd is all overrides.
- The owner's name in the part (`back`) must be no local anywhere in the moved functions - `t` was
  every function's time. The tool refuses one that is.
- A Node method the part calls on its owner (`add_child`) is named by compiling: list it in
  `inherited`, or prefix it by hand.
- A gate that holds the owner in an untyped variable reaches moved members at RUNTIME only: list
  the variables in `receivers` (cut_part_names.py patches them), run the gates, and read their
  logs - check.sh fails a SCRIPT ERROR behind a pass.
- A banner's prose (plain `#` lines under it) belongs to the part: name the banner in `carry`.
- The owner's `field` must be named like none of its members (the tool refuses it): MaskUndo's was
  `_undo`, the name of the method it took, and the gates' calls were rewritten twice.
- A plain `#` comment block touching a declaration goes with it (the AVI repair's note stayed in
  the owner over an empty banner once); one standing apart, or under a banner, stays.

spec.json:
  file      the owner script
  owner     its class_name
  part      the new class_name          part_file  where it goes
  field     the owner's member that holds the part
  back      the part's member that holds the owner (default "t")
  sections  [banner titles] whose functions move
  also      [names] that move as well   keep [names] that stay whatever their section
  inherited [names] the part reads off the owner's base classes (found by compiling)
  header    path of a text file: the part's doc comment
  repo      the repository root (for the report on outside references)
"""

import json
import re
import sys
from collections import defaultdict
from pathlib import Path

spec = json.loads(Path(sys.argv[1]).read_text())
mode = sys.argv[2] if len(sys.argv) > 2 else "report"
repo = Path(spec["repo"])
path = repo / spec["file"]
OWNER, PART, FIELD = spec["owner"], spec["part"], spec["field"]
BACK = spec.get("back", "t")
lines = path.read_text().split("\n")
n = len(lines)

BANNER = re.compile(r"^# --- (.*?)(?: -{3,})?\s*$")
DECL = re.compile(
    r"^(?:@\w+(?:\([^)]*\))?\s+)*(static func|func|static var|var|const|signal|enum|class)\s+(\w+)"
)


def blank(line: str, quote=None):
    """(the line with comments and string literals blanked, the quote still open at its end)."""
    out, i = [], 0
    while i < len(line):
        c = line[i]
        if quote:
            if c == "\\" and i + 1 < len(line):
                out.append("  ")
                i += 2
                continue
            if line.startswith(quote, i):
                out.append(" " * len(quote))
                i += len(quote)
                quote = None
                continue
            out.append(" ")
        elif line.startswith('"""', i):
            quote = '"""'
            out.append("   ")
            i += 3
            continue
        elif c in "\"'":
            quote = c
            out.append(" ")
        elif c == "#":
            out.append(" " * (len(line) - i))
            break
        else:
            out.append(c)
        i += 1
    if quote in ('"', "'"):
        quote = None  # a one-line string never runs on
    return "".join(out), quote


code = []
q = None
for l in lines:
    b, q = blank(l, q)
    code.append(b)

# --- top-level declarations --------------------------------------------------------------------
decls = []
section = "(head)"
i = 0
lead = None  # first line of the doc comment / annotations that belong to the next declaration
while i < n:
    line = lines[i]
    if line.startswith("# ---"):
        m = BANNER.match(line)
        section = m.group(1).strip(" -") if m else section
        lead = None
        i += 1
        continue
    d = DECL.match(line)
    if not d and (line.startswith("##") or (line.startswith("@") and line.strip() != "")):
        if lead is None:
            lead = i
        i += 1
        continue
    # a plain comment block TOUCHING a declaration (no blank line between) is about it, and goes
    # where it goes: left in the owner over nothing, the AVI repair's lay above an empty banner
    if not d and line.startswith("#") and not line.startswith("# ---"):
        k = i
        while k < n and lines[k].startswith("#") and not lines[k].startswith("# ---"):
            k += 1
        if k < n and (DECL.match(lines[k]) or lines[k].startswith("##")) and lead is None:
            lead = i
        i = k
        continue
    if d:
        kind, name = d.group(1), d.group(2)
        depth = sum(code[i].count(c) for c in "([{") - sum(code[i].count(c) for c in ")]}")
        j = i + 1
        while j < n:
            l = lines[j]
            if depth > 0:
                depth += sum(code[j].count(c) for c in "([{") - sum(code[j].count(c) for c in ")]}")
                j += 1
                continue
            if l.startswith(("\t", " ")):
                j += 1
                continue
            plain = lambda s: s.startswith("#") and not s.startswith("##") and not s.startswith("# ---")
            if l.strip() == "" or plain(l):
                k = j
                while k < n and (lines[k].strip() == "" or plain(lines[k])):
                    k += 1
                if k < n and lines[k].startswith(("\t", " ")) and kind in ("func", "static func", "class"):
                    j = k
                    continue
            break
        decls.append({"kind": kind, "name": name, "start": i, "end": j, "section": section,
                      "lead": lead if lead is not None else i})
        lead = None
        i = j
        continue
    if line.strip() != "":
        lead = None
    i += 1

by_name = {}
for d in decls:
    assert d["name"] not in by_name or d["kind"] == "class", f"declared twice: {d['name']}"
    by_name[d["name"]] = d
funcs = [d for d in decls if d["kind"] in ("func", "static func")]
members = set(by_name)

IDENT = re.compile(r"[A-Za-z_]\w*")


def tokens(d):
    """Every bare identifier in a declaration: (line index, column, name) - bare meaning not
    reached through a dot, a `$` or an `@`."""
    out = []
    prev = ""
    for li in range(d["start"], d["end"]):
        c = code[li]
        for m in IDENT.finditer(c):
            before = c[:m.start()].rstrip()
            last = before[-1] if before else prev
            if last in (".", "$", "@", "%") and not (last == "%" and before and before[-1] == "%" and c[m.start() - 1] == " "):
                continue
            out.append((li, m.start(), m.group(0)))
        s = c.strip()
        if s:
            prev = s[-1]
    return out


def locals_of(d):
    text = "\n".join(code[d["start"]:d["end"]])
    names = set()
    sig = re.match(r"[^(]*\((.*?)\)\s*(?:->[^:]*)?:", text, re.S)
    if sig:
        for part in re.split(r",(?![^(\[{]*[)\]}])", sig.group(1)):
            pm = re.match(r"\s*(\w+)", part)
            if pm:
                names.add(pm.group(1))
    for lm in re.finditer(r"\bvar\s+(\w+)|\bfor\s+(\w+)\s+in\b|\bfunc\s*\w*\s*\(([^)]*)\)", text[text.find(":") if sig else 0:]):
        if lm.group(1):
            names.add(lm.group(1))
        if lm.group(2):
            names.add(lm.group(2))
        if lm.group(3):
            for part in lm.group(3).split(","):
                pm = re.match(r"\s*(\w+)", part)
                if pm:
                    names.add(pm.group(1))
    return names


for d in decls:
    d["tokens"] = tokens(d)
    d["locals"] = locals_of(d) if d["kind"] in ("func", "static func") else set()
    d["uses"] = {name for _, _, name in d["tokens"] if name in members and name != d["name"]} - d["locals"]
    d["shadow"] = {name for _, _, name in d["tokens"] if name in members and name != d["name"]} & d["locals"]

# --- what moves ------------------------------------------------------------------------------
keep = set(spec.get("keep", []))
moved = {d["name"] for d in funcs if d["section"] in spec.get("sections", [])} | set(spec.get("also", []))
moved -= keep
for name in moved:
    assert name in by_name, f"no such member: {name}"

# a variable or constant goes with the part when only the part's own members use it
users = defaultdict(set)
for d in decls:
    for u in d["uses"]:
        users[u].add(d["name"])
outside_names = set()
asked_of_owner = set()
for p in list((repo / "src").rglob("*.gd")):
    if p == path:
        continue
    t = p.read_text()
    for m in re.finditer(r"\.(\w+)\b", t):
        outside_names.add(m.group(1))
    for m in re.finditer(rf"\b{OWNER}\.(\w+)\b", t):
        asked_of_owner.add(m.group(1))
for p in list((repo / "tests").rglob("*.gd")):
    for m in re.finditer(r"\.(\w+)\b", p.read_text()):
        outside_names.add(m.group(1))
keep |= {x for x in asked_of_owner if x in by_name and by_name[x]["kind"] in ("const", "enum", "class")}
changed = True
while changed:
    changed = False
    for d in decls:
        if d["name"] in moved or d["name"] in keep or d["kind"] in ("func", "static func", "signal", "class"):
            continue
        if d["kind"].startswith(("var", "static var")) and d["name"].startswith("_") is False and d["name"] in outside_names:
            continue  # a public variable something else sets: it stays where they look for it
        if users[d["name"]] and users[d["name"]] <= moved and d["uses"] <= moved | {x["name"] for x in decls if x["kind"] in ("const", "enum", "class")}:
            moved.add(d["name"])
            changed = True

kept = members - moved
# the field the owner holds its part in must be no member of the owner: named like a moved method
# (`_undo` for MaskUndo), every `ed._undo` a gate held was rewritten twice, to `ed._undo.undo`
assert FIELD not in members, f"the owner already has a member named {FIELD}: pick another `field`"
inherited = set(spec.get("inherited", []))
for d in decls:
    if d["name"] in moved:
        assert BACK not in d["locals"], f"{d['name']} has a local named {BACK}: pick another `back`"
    else:
        assert FIELD not in d["locals"], f"{d['name']} has a local named {FIELD}: pick another `field`"


def is_static(name):
    return by_name[name]["kind"] in ("static func", "const", "enum", "class", "static var")


def rewrite(d, in_part: bool):
    """The declaration's lines (lead included) with the other side's members qualified."""
    edits = defaultdict(list)  # line -> [(col, old, new)]
    for li, col, name in d["tokens"]:
        if name in d["locals"]:
            continue
        if li == d["start"] and name == d["name"]:
            continue
        new = None
        if in_part:
            if name == "self":
                new = BACK
            elif name in kept:
                new = f"{OWNER}.{name}" if is_static(name) else f"{BACK}.{name}"
            elif name in inherited:
                new = f"{BACK}.{name}"
        else:
            if name in moved:
                new = f"{PART}.{name}" if is_static(name) else f"{FIELD}.{name}"
        if new:
            edits[li].append((col, name, new))
    out = []
    for li in range(d["lead"], d["end"]):
        l = lines[li]
        for col, old, new in sorted(edits.get(li, []), reverse=True):
            assert l[col:col + len(old)] == old, (li, l, old)
            l = l[:col] + new + l[col + len(old):]
        out.append(l)
    return out


# --- the report -------------------------------------------------------------------------------
mf = [d for d in funcs if d["name"] in moved]
mv = [d for d in decls if d["name"] in moved and d["kind"] not in ("func", "static func")]
reads_owner = defaultdict(int)
for d in decls:
    if d["name"] in moved:
        for u in d["uses"] & kept:
            reads_owner[u] += 1
calls_part = defaultdict(set)
for d in decls:
    if d["name"] in kept:
        for u in d["uses"] & moved:
            calls_part[u].add(d["name"])
print(f"{PART}: {len(mf)} functions ({sum(d['end'] - d['start'] for d in mf)} lines), "
      f"{sum(1 for d in mv if 'var' in d['kind'])} variables, {sum(1 for d in mv if d['kind'] in ('const', 'enum'))} constants move")
print(f"  what the part reads of its owner ({len(reads_owner)}): " + " ".join(f"{k}({v})" for k, v in sorted(reads_owner.items(), key=lambda kv: -kv[1])))
print(f"  what the owner asks of the part ({len(calls_part)}): " + " ".join(f"{k}<-{len(v)}" for k, v in sorted(calls_part.items(), key=lambda kv: -len(kv[1]))))
sh = [(d["name"], sorted(d["shadow"])) for d in decls if d["shadow"] and (d["name"] in moved or d["shadow"] & moved)]
print(f"  a local shadows a member here (look by hand): {sh}")
strs = set()
for li, l in enumerate(lines):
    for m in re.finditer(r"[\"']([A-Za-z_]\w*)[\"']", l):
        if m.group(1) in moved:
            strs.add((li + 1, m.group(1)))
print(f"  moved members named in a string in this file: {sorted(strs)}")
ext = defaultdict(set)
for p in list((repo / "src").rglob("*.gd")) + list((repo / "tests").rglob("*.gd")):
    if p == path:
        continue
    t = p.read_text()
    for m in re.finditer(r"\.(\w+)\b", t):
        if m.group(1) in moved and (m.group(1).startswith("_") or by_name[m.group(1)]["kind"] in ("var", "func")):
            ext[p.relative_to(repo).as_posix()].add(m.group(1))
print("  moved members reached from other files (.name):")
for f, names in sorted(ext.items()):
    print(f"    {f}: {' '.join(sorted(names))}")

if mode != "apply":
    sys.exit(0)

# --- write both files ---------------------------------------------------------------------------
header = Path(spec["header"]).read_text().rstrip("\n") if spec.get("header") else f"## {PART} - a part of [{OWNER}]."
carried = set()
for title in spec.get("carry", []):
    at = next(i for i, l in enumerate(lines) if l.startswith("# ---") and title in l)
    carried.add(at)
    prose = []
    k = at + 1
    while k < n and lines[k].startswith("#") and not lines[k].startswith("##") and not lines[k].startswith("# ---"):
        carried.add(k)
        prose.append("##" + lines[k][1:])
        k += 1
    if prose:
        header += "\n##\n" + "\n".join(prose)
part = ["extends RefCounted", f"class_name {PART}", "", header, "",
        f"## The [{OWNER}] this is a part of: everything read through it is something this part",
        "## is handed, and the list of them is what it depends on.",
        f"var {BACK}: {OWNER}", ""]
owner = []
cursor = 0
last_section = None
ordered = sorted(decls, key=lambda d: d["lead"])
for d in ordered:
    if d["lead"] < cursor:
        continue  # an inner declaration already carried by its outer one
    gap = [l for gi, l in enumerate(lines[cursor:d["lead"]], cursor) if gi not in carried]
    owner.extend(gap)
    if d["name"] in moved:
        if d["section"] != last_section and d["kind"] in ("func", "static func"):
            part.extend(["", f"# --- {d['section']} " + "-" * max(3, 96 - len(d["section"]) - 7), ""])
            last_section = d["section"]
        part.extend(rewrite(d, True))
        part.extend(["", ""] if d["kind"] in ("func", "static func") else [])
        # drop the blank lines the declaration left behind in the owner
        while owner and owner[-1].strip() == "" and len(owner) > 1 and owner[-2].strip() == "":
            owner.pop()
    else:
        owner.extend(rewrite(d, False))
    cursor = d["end"]
owner.extend(l for gi, l in enumerate(lines[cursor:], cursor) if gi not in carried)
text = "\n".join(owner)
# a banner the cut left with nothing under it goes too
text = re.sub(r"\n# --- [^\n]*\n\s*(?=\n# --- |\Z)", "\n", text)
text = re.sub(r"\n{4,}", "\n\n\n", text)
ptext = re.sub(r"\n{4,}", "\n\n\n", "\n".join(part)).rstrip("\n") + "\n"
path.write_text(text)
(repo / spec["part_file"]).write_text(ptext)
Path(sys.argv[1]).with_suffix(".moved.json").write_text(json.dumps(sorted(moved)))
print(f"wrote {spec['part_file']} ({ptext.count(chr(10))} lines); {spec['file']} is {text.count(chr(10))} lines")
