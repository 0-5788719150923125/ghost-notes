#!/usr/bin/env python3
"""Move some of a big class's variables into a small data class it holds, every use rewritten.

    python scripts/hold_vars.py <spec.json> [report|apply]

spec.json:
  repo        the repository root
  file        the owner script                 field   the owner's member that holds the data
  cls         the data class's class_name      cls_file  where it goes
  vars        {"_old": "new"}: each variable, and its name in the data class
  receivers   the variables other scripts hold the owner in (`medium`, `m`) - `m._old` becomes
              `m.<field>.new` in every script under src/ and tests/ but the owner
  skip        scripts whose receivers hold something else (another medium with the same names)
  header      a text file: the data class's doc comment

WHAT IT IS FOR. A variable written in one place and read everywhere (the table's plan: written
when an episode loads) is one thing with one lifetime, and holding it in an object says so: the
owner can start a fresh one in one statement, and a part can be handed it instead of its owner
(next/structure.md, step 7). It moves STORAGE only - every statement that wrote a variable writes
the same field, in the same order - so a seeded show is the same show.

THE TRAPS: a local or a parameter named like a moved variable would be rewritten too, so the tool
refuses to run while one exists; and a gate that holds the owner in an untyped variable reaches the
fields at runtime only - name its variable in `receivers`, then run the gates and read their logs.
"""

import json
import re
import sys
from pathlib import Path

spec = json.loads(Path(sys.argv[1]).read_text())
mode = sys.argv[2] if len(sys.argv) > 2 else "report"
repo = Path(spec["repo"])
owner = repo / spec["file"]
FIELD, CLS = spec["field"], spec["cls"]
names = spec["vars"]
lines = owner.read_text().split("\n")


def blank(line: str) -> str:
    """The line with its comment and string literals blanked, the same length."""
    out, i, q = [], 0, None
    while i < len(line):
        c = line[i]
        if q:
            if c == "\\" and i + 1 < len(line):
                out.append("  ")
                i += 2
                continue
            if c == q:
                q = None
            out.append(" ")
        elif c in "\"'":
            q = c
            out.append(" ")
        elif c == "#":
            out.append(" " * (len(line) - i))
            break
        else:
            out.append(c)
        i += 1
    return "".join(out)


alt = "|".join(re.escape(k) for k in sorted(names, key=len, reverse=True))
# refuse a local or a parameter that shares a name with a moved variable
clash = []
for li, l in enumerate(lines):
    c = blank(l)
    if l.startswith(("\t", " ")):
        if re.search(rf"\b(?:var|for)\s+({alt})\b", c):
            clash.append(li + 1)
    if re.match(r"\s*(?:static\s+)?func\b", c):
        sig = re.search(r"\((.*)\)", c)
        if sig and re.search(rf"(?<![\w.])({alt})\b", sig.group(1)):
            clash.append(li + 1)
assert not clash, f"a local or parameter is named like a moved variable, lines {clash}"

# the declarations, with the doc comment above each
decl_at = {}
for li, l in enumerate(lines):
    m = re.match(rf"var ({alt})\b(.*)$", l)
    if m:
        lead = li
        while lead > 0 and lines[lead - 1].startswith("##"):
            lead -= 1
        decl_at[m.group(1)] = (lead, li)
missing = sorted(set(names) - set(decl_at))
assert not missing, f"no declaration of {missing}"

uses = 0
out = []
removed = set()
for name, (lead, at) in decl_at.items():
    removed.update(range(lead, at + 1))
first = min(lead for lead, _ in decl_at.values())
fields = []
for name, (lead, at) in sorted(decl_at.items(), key=lambda kv: kv[1][0]):
    doc = lines[lead:at]
    decl = re.sub(rf"^var {re.escape(name)}\b", f"var {names[name]}", lines[at])
    fields.extend(doc + [decl])

pat = re.compile(rf"(?<![\w.$])({alt})\b")
for li, l in enumerate(lines):
    if li in removed:
        if li == first:
            out.extend(spec.get("field_doc", "").rstrip("\n").split("\n") if spec.get("field_doc") else [])
            out.append(f"var {FIELD} := {CLS}.new()")
        continue
    c = blank(l)
    edits = [(m.start(), m.group(1)) for m in pat.finditer(c)]
    for col, name in reversed(edits):
        l = l[:col] + f"{FIELD}.{names[name]}" + l[col + len(name):]
        uses += 1
    out.append(l)

# other scripts that reach the variables on the owner
recv = "|".join(re.escape(r) for r in spec.get("receivers", []))
others = {}
for p in sorted(list((repo / "src").rglob("*.gd")) + list((repo / "tests").rglob("*.gd"))):
    if p == owner or p.relative_to(repo).as_posix() in spec.get("skip", []):
        continue
    t = p.read_text()
    t2, k = re.subn(rf"(?<![\w.])({recv})\.({alt})\b", lambda m: f"{m.group(1)}.{FIELD}.{names[m.group(2)]}", t)
    if k:
        others[p] = (t2, k)

print(f"{CLS}: {len(names)} variables, {uses} uses in {owner.relative_to(repo)}")
for p, (_, k) in others.items():
    print(f"  {p.relative_to(repo)}: {k}")
if mode != "apply":
    sys.exit(0)

header = Path(spec["header"]).read_text().rstrip("\n") if spec.get("header") else f"## {CLS} - data [{spec['file']}] holds."
(repo / spec["cls_file"]).write_text(
    "extends RefCounted\n" + f"class_name {CLS}\n\n" + header + "\n\n" + "\n".join(fields).rstrip("\n") + "\n"
)
owner.write_text("\n".join(out))
for p, (t2, _) in others.items():
    p.write_text(t2)
print("written")
