"""Sort a big GDScript file's declarations under true banners - a pure reorder, checked.

    python scripts/sort_banners.py <file.gd> <layout.json>          # report: what is where, what is missing
    python scripts/sort_banners.py <file.gd> <layout.json> apply    # rewrite the file
    python scripts/sort_banners.py <file.gd> - list                 # what is under each banner now

A big file comes apart along its banners (CLAUDE.md, "A BIG FILE COMES APART ALONG ITS BANNERS"), and
a cut is only as good as the banners it follows: reading_panel.gd's "the audition" held the status
line and the Ink row, Masking's "auto-save" the face and pose processes. This puts every declaration
under the banner the layout names, and nothing else changes - every declaration comes out byte for
byte as it went in (its `##` doc and annotations with it), which the tool checks before it writes.

layout.json:
  head      [names] the declarations before the first banner, in this order (`*` = every variable,
            constant, signal and enum not named elsewhere, in the order the file has them)
  sections  [{"title": "...", "prose": ["# a line", ...], "members": [names]}] - each banner, the
            plain `#` lines under it, and its declarations in order
  demote    [banner titles, or their first words] banners that head a group of variables rather than
            code: each becomes a plain `# Title` comment, its prose under it, over the first
            declaration below it
A name placed twice, a name the file does not declare and a declaration placed nowhere are refused.

WHAT GOES WITH A DECLARATION: its `##` doc and annotations, and a run of plain `#` comment lines
above it (an old banner's prose is dropped with the banner unless a section's `prose` keeps it - the
report prints every banner's prose so none is lost by accident). Variables keep their order among
themselves when `*` places them (an initializer may read one declared above it); a layout that
names variables places them where it says.
"""

import json
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
layout = json.loads(Path(sys.argv[2]).read_text()) if sys.argv[2] != "-" else {"sections": []}
mode = sys.argv[3] if len(sys.argv) > 3 else "report"
lines = path.read_text().split("\n")
n = len(lines)

BANNER = re.compile(r"^# --- (.*?)(?: -{3,})?\s*$")
DECL = re.compile(
    r"^(?:@\w+(?:\([^)]*\))?\s+)*(static func|func|static var|var|const|signal|enum|class)\s+(\w+)"
)

# --- the file as blocks: header, banners (+ prose), declarations (+ what goes with each) ----------
header_end = 0
while header_end < n and (lines[header_end].startswith(("extends", "class_name", "@tool", "##"))
                          or lines[header_end].strip() == ""):
    header_end += 1
# the header ends at the last blank line before the first non-header line
while header_end > 0 and lines[header_end - 1].strip() != "":
    header_end -= 1
header = lines[:header_end]

decls = {}       # name -> {"text": [lines], "kind", "at"}
order = []       # names in file order
banners = []     # [(title, [prose lines])]
under = {"(head)": []}   # banner title -> the names declared under it, as the file stands
current = "(head)"
pending = []     # comment lines waiting for the declaration below them
i = header_end
while i < n:
    line = lines[i]
    if line.startswith("# ---"):
        m = BANNER.match(line)
        title = (m.group(1) if m else line[5:]).strip(" -")
        prose = []
        k = i + 1
        while k < n and lines[k].startswith("#") and not lines[k].startswith("##") and not lines[k].startswith("# ---"):
            prose.append(lines[k])
            k += 1
        if any(title.startswith(t) for t in layout.get("demote", [])):
            # a banner over a group of variables, not over code: its title and prose go with the
            # declaration below it, as a plain comment
            pending = ["# " + title] + prose
            i = k
            continue
        banners.append((title, prose))
        current = title
        under.setdefault(title, [])
        pending = []
        i = k
        continue
    if line.strip() == "":
        if pending and pending[-1] != "":
            pending.append("")
        i += 1
        continue
    if (line.startswith("#") and not DECL.match(line)) or line.startswith("@") and not DECL.match(line):
        pending.append(line)
        i += 1
        continue
    d = DECL.match(line)
    assert d, f"line {i + 1} is neither a declaration nor a comment: {line!r}"
    kind, name = d.group(1), d.group(2)
    j = i + 1
    depth = line.count("(") + line.count("[") + line.count("{") - line.count(")") - line.count("]") - line.count("}")
    while j < n:
        l = lines[j]
        if depth > 0:
            depth += l.count("(") + l.count("[") + l.count("{") - l.count(")") - l.count("]") - l.count("}")
            j += 1
            continue
        if l.startswith(("\t", " ")):
            j += 1
            continue
        if l.strip() == "" or (l.startswith("#") and not l.startswith("##") and not l.startswith("# ---")):
            k = j
            while k < n and (lines[k].strip() == "" or (lines[k].startswith("#") and not lines[k].startswith("##")
                                                       and not lines[k].startswith("# ---"))):
                k += 1
            if k < n and lines[k].startswith(("\t", " ")):
                j = k
                continue
        break
    body = lines[i:j]
    while body and body[-1].strip() == "":
        body.pop()
    lead = [x for x in pending]
    while lead and lead[-1] == "":
        lead.pop()
    while lead and lead[0] == "":
        lead.pop(0)
    # a `##` doc never stands apart from what it documents
    assert name not in decls or kind == "class", f"declared twice: {name}"
    decls[name] = {"text": lead + body, "kind": kind, "at": len(order)}
    order.append(name)
    under[current].append(name)
    pending = []
    i = j
assert not [x for x in pending if x.strip()], f"comment lines after the last declaration: {pending}"

# --- the layout ------------------------------------------------------------------------------------
placed = []
head = []
star_at = None
for name in layout.get("head", []):
    if name == "*":
        star_at = len(head)
        continue
    head.append(name)
for sec in layout["sections"]:
    placed.extend(sec["members"])
placed.extend(head)
dupes = sorted({x for x in placed if placed.count(x) > 1})
unknown = sorted(set(placed) - set(decls))
if star_at is not None:
    rest = [x for x in order if x not in placed and decls[x]["kind"] not in ("func", "static func", "class")]
    head[star_at:star_at] = rest
    placed.extend(rest)
missing = [x for x in order if x not in placed]

print(f"{path.name}: {len(order)} declarations, {len(banners)} banners")
if mode == "list":
    for title, names in under.items():
        print(f"  [{title}]")
        print("    " + " ".join(names))
    sys.exit(0)
for title, prose in banners:
    if prose:
        print(f"  banner prose under '{title}':")
        for p in prose:
            print("     " + p)
if dupes:
    print("PLACED TWICE:", dupes)
if unknown:
    print("NOT IN THE FILE:", unknown)
if missing:
    print("PLACED NOWHERE:", missing)
if dupes or unknown or missing or mode != "apply":
    sys.exit(1 if (dupes or unknown or missing) else 0)

# --- write, then check every declaration came through unchanged ------------------------------------
def banner(title):
    return "# --- " + title + " " + "-" * max(3, 100 - len(title) - 7)


out = list(header)
while out and out[-1].strip() == "":
    out.pop()
out.append("")
for k, name in enumerate(head):
    d = decls[name]
    func = d["kind"] in ("func", "static func", "class")
    if func or (k > 0 and decls[head[k - 1]]["kind"] in ("func", "static func", "class")):
        out.extend(["", ""])
    elif d["text"][0].startswith("#") and out[-1].strip() != "":
        out.append("")
    out.extend(d["text"])
for sec in layout["sections"]:
    out.extend(["", "", banner(sec["title"])])
    out.extend(sec.get("prose", []))
    for name in sec["members"]:
        d = decls[name]
        out.extend(["", ""] if d["kind"] in ("func", "static func", "class") else [""])
        out.extend(d["text"])
text = re.sub(r"\n{4,}", "\n\n\n", "\n".join(out)).rstrip("\n") + "\n"

# the check: the same declarations, each byte for byte, and every comment line kept or named
before = sorted("\n".join(d["text"]) for d in decls.values())
after_lines = text.split("\n")
for name, d in decls.items():
    block = "\n".join(d["text"])
    assert block in text, f"{name} did not come through whole"
kept_prose = {p for sec in layout["sections"] for p in sec.get("prose", [])}
dropped = [p for _, prose in banners for p in prose if p not in kept_prose and p not in text]
path.write_text(text)
print(f"wrote {path} ({text.count(chr(10))} lines, was {n}); banner prose dropped: {len(dropped)}")
for p in dropped:
    print("   dropped:", p)
