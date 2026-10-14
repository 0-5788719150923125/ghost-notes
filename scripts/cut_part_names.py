"""After cut_part.py: the part's public names, the owner holding its part, what reaches in.

    python scripts/cut_part_names.py <spec.json>
        spec: cut_part's, plus "api": {old: new} (what the owner asks of the part, named without
        the underscore), "receivers": [...] (the variables gates and other parts hold the owner
        in), "anchor" (a line the owner's fields go before) and "field_doc".
A new public name already used in the part is refused (comments and strings aside).
"""
import json, re, sys
from pathlib import Path

spec = json.loads(Path(sys.argv[1]).read_text())
repo = Path(spec["repo"])
part, owner = repo / spec["part_file"], repo / spec["file"]
FIELD, BACK, PART, OWNER = spec["field"], spec.get("back", "t"), spec["part"], spec["owner"]
moved = set(json.loads(Path(sys.argv[1]).with_suffix(".moved.json").read_text()))
api = spec.get("api", {})
pt, ot = part.read_text(), owner.read_text()
statics = set(re.findall(r"^(?:static func|const|enum)\s+(\w+)", pt, re.M))

# 1. the part's public names - refused if a name is already taken there
for old, new in api.items():
    assert old in moved, f"{old} did not move"
    code_only = re.sub(r"#.*", "", re.sub(r'"(?:[^"\\\n]|\\.)*"|\'(?:[^\'\\\n]|\\.)*\'', '""', pt))
    assert not re.search(rf"(?<![\w.]){new}\b", code_only), f"{new} is already a name in {PART}"
    pt = re.sub(rf"(?<![\w]){old}\b", new, pt)
    ot = re.sub(rf"(?<![\w]){FIELD}\.{old}\b", f"{FIELD}.{new}", ot)
    ot = re.sub(rf"(?<![\w]){PART}\.{old}\b", f"{PART}.{new}", ot)
    ot = re.sub(rf"\[method {old}\]", f"[method {PART}.{new}]", ot)
    if old in statics:
        statics.add(new)
part.write_text(pt)

# 2. the owner holds its part, and hands it itself
field = f"{spec.get('field_doc', '').rstrip()}\nvar {FIELD} := {PART}.new()\n".lstrip("\n")
m = re.search(r"^func _init\(\) -> void:\n", ot, re.M)
if m:
    ot = ot[:m.end()] + f"\t{FIELD}.{BACK} = self\n" + ot[m.end():]
    i = ot.index(spec["anchor"])
    ot = ot[:i] + field + "\n\n" + ot[i:]
else:
    i = ot.index(spec["anchor"])
    ot = ot[:i] + field + "\n\nfunc _init() -> void:\n" + f"\t{FIELD}.{BACK} = self\n\n\n" + ot[i:]
owner.write_text(ot)

# 3. the gates that reach into what moved
names = {m: api.get(m, m) for m in moved}
recv = "|".join(re.escape(r) for r in spec.get("receivers", []))
others = sorted((repo / "tests").glob("*.gd")) + [x for x in sorted((repo / "src").rglob("*.gd")) if x not in (part, owner)]
for p in others:
    t = p.read_text()
    total = 0
    for old, new in sorted(names.items(), key=lambda kv: -len(kv[0])):
        if recv:
            t, k = re.subn(rf"(?<![\w.])({recv})\.{old}\b", lambda mm: f"{mm.group(1)}.{FIELD}.{new}", t)
            total += k
        t, k = re.subn(rf"(?<![\w.]){OWNER}\.{old}\b", f"{PART}.{new}", t)
        total += k
    if total:
        p.write_text(t)
        print(f"  {p.relative_to(repo)}: {total}")
