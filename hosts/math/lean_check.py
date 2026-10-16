#!/usr/bin/env python3
"""Check a Lean file against ghost's Mathlib workbench, through the Lean REPL.

    lean_check.py <spec.json>

The spec is JSON - never argv: {"code", "out", "bench", "lake", "forbidden": [...], "theorem"}.
`bench` is the workbench folder (user://lean/mathlib-<tag>), `lake` ghost's own Lake. The REPL is
started in the workbench (`lake env <repl>`), told `import Mathlib`, then handed the code with every
tactic asked for, then `#print axioms` for each theorem in it. The answer, written to `out`:

    {"ok", "verified", "report", "messages": [{severity, line, text}], "tactics": [{line, tactic,
     goals, facts}], "axioms": {name: [..]}, "forbidden_used": [..], "seconds"}

`report` is what an agent is shown: every error and warning with its line, the goals before each
tactic, the library facts each tactic used, every `sorry`, the axioms - and the verdict. VERIFIED
means: no error, no sorry, nothing beyond Lean's three standard axioms, no forbidden fact used (a
forbidden fact is Mathlib's own copy of the theorem being proved, caught through the constants
each tactic used), and - when `theorem` is named - that theorem exists. Exit 0 with the file
written whatever the verdict; anything else is a failure, with the reason on stderr.

Measured (2026-10-15, Mathlib v4.35.0): a check costs 12-40 s, nearly all of it `import Mathlib`.
"""

import json
import os
import pathlib
import re
import subprocess
import sys
import time

STANDARD = {"propext", "Classical.choice", "Quot.sound"}
# A fact worth naming to a reader is a lemma: a dotted name whose last part has an underscore -
# never a typeclass instance (`inst...`, `to...`) or a tactic's own machinery.
LEMMA = re.compile(r"^[A-Z][\w']*(\.[A-Z][\w']*)*\.[a-z][\w']*$")


def _lemmas(consts):
    out = []
    for u in consts:
        if not LEMMA.match(u) or re.search(r"\.(inst|to[A-Z])", u) or "_" not in u.rsplit(".", 1)[-1]:
            continue
        if u.startswith(("Mathlib.Tactic.", "Mathlib.Meta.", "Lean.")):
            continue
        out.append(u)
    return sorted(out)


def check(spec):
    code = spec["code"]
    forbidden = set(spec.get("forbidden", []))
    bench = spec["bench"]
    lake = spec["lake"]
    lines = code.splitlines()
    body_lines = [ln for ln in lines if not ln.strip().startswith("import ")]
    offset = len(lines) - len(body_lines)
    body = "\n".join(body_lines)
    names = re.findall(r"^\s*(?:theorem|lemma)\s+([^\s(:{\[]+)", body, re.M)
    cmds = [{"cmd": "import Mathlib"}, {"cmd": body, "env": 0, "allTactics": True}]
    for n in names:
        cmds.append({"cmd": "#print axioms %s" % n, "env": 1})
    stdin = "\n\n".join(json.dumps(c) for c in cmds) + "\n\n"
    repl = os.path.join(bench, ".lake", "packages", "REPL", ".lake", "build", "bin", "repl")
    if os.name == "nt":
        repl += ".exe"
    t0 = time.time()
    proc = subprocess.run([lake, "env", repl], input=stdin, capture_output=True, text=True,
                          cwd=bench, timeout=900)
    took = time.time() - t0
    answers = []
    for chunk in re.split(r"\n\n(?=\{)", proc.stdout.strip()):
        if not chunk.strip():
            continue
        try:
            answers.append(json.loads(chunk))
        except json.JSONDecodeError:
            answers.append({"raw": chunk})
    out = {"ok": True, "verified": False, "messages": [], "tactics": [], "axioms": {},
           "forbidden_used": [], "seconds": round(took, 1)}
    if len(answers) < 2:
        out["ok"] = False
        out["report"] = "Lean did not answer. " + (proc.stderr or proc.stdout)[-1500:]
        return out
    verified = True
    rep = []
    main = answers[1]
    for m in main.get("messages", []):
        sev = str(m.get("severity", "info"))
        line = int(m.get("pos", {}).get("line", 0)) + offset
        text = str(m.get("data", "")).strip()
        out["messages"].append({"severity": sev, "line": line, "text": text})
        if sev == "error":
            verified = False
        rep.append("%s at line %d: %s" % (sev.upper(), line, text))
    for s in main.get("sorries", []):
        verified = False
        line = int(s.get("pos", {}).get("line", 0)) + offset
        out["messages"].append({"severity": "sorry", "line": line, "text": str(s.get("goal", ""))})
        rep.append("SORRY at line %d, still to prove: %s" % (line, s.get("goal", "")))
    used = set()
    for t in main.get("tactics", []):
        consts = t.get("usedConstants", [])
        used.update(consts)
        line = int(t.get("pos", {}).get("line", 0)) + offset
        facts = _lemmas(consts)
        out["tactics"].append({"line": line, "tactic": t.get("tactic", ""), "goals": t.get("goals", ""),
                               "facts": facts})
        rep.append("\n-- tactic at line %d: %s" % (line, str(t.get("tactic", "")).splitlines()[0][:100]))
        rep.append("   goals before it:\n     " + str(t.get("goals", "")).replace("\n", "\n     "))
        if facts:
            rep.append("   facts it used: " + ", ".join(facts[:12]))
    bad = sorted(forbidden & used)
    if bad:
        verified = False
        out["forbidden_used"] = bad
        rep.append("\nFORBIDDEN: the proof uses %s, which is the theorem itself or Mathlib's own proof of it."
                   % ", ".join(bad))
    for a in answers[2:]:
        for m in a.get("messages", []):
            text = str(m.get("data", ""))
            hit = re.match(r"'([^']+)' depends on axioms: \[(.*)\]", text.strip(), re.S)
            if hit:
                axs = [x.strip() for x in hit.group(2).split(",") if x.strip()]
                out["axioms"][hit.group(1)] = axs
                extra = [x for x in axs if x not in STANDARD]
                if extra:
                    verified = False
                    rep.append("\nNON-STANDARD AXIOMS in %s: %s" % (hit.group(1), ", ".join(extra)))
                else:
                    rep.append("\n%s depends only on the standard axioms (%s)." % (hit.group(1), ", ".join(axs)))
            elif "does not depend on any axioms" in text:
                out["axioms"][text.split("'")[1] if "'" in text else "?"] = []
            elif text.strip():
                rep.append("\n" + text.strip())
    want = str(spec.get("theorem", "")).strip()
    if want and want not in names:
        verified = False
        rep.append("\nThere is no theorem called %s in the file." % want)
    if not names:
        verified = False
        rep.append("\nThe file states no theorem.")
    out["verified"] = verified
    rep.append("\n%s (checked in %.0f s)" % ("VERIFIED" if verified else "NOT VERIFIED", took))
    out["report"] = "\n".join(rep).strip()
    return out


def main():
    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    spec = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
    answer = check(spec)
    out = pathlib.Path(spec["out"])
    tmp = out.with_suffix(out.suffix + ".part")
    tmp.write_text(json.dumps(answer), encoding="utf-8")
    os.replace(tmp, out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
