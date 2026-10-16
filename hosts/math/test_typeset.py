#!/usr/bin/env python3
"""typeset.py, held to what the desk's hand relies on.

    python test_typeset.py [tex_bin_dir]

With no argument TeX is looked up on PATH; ghost's own is tools/tex/<version>/.../bin/<platform>.
Skips (exit 0, saying so) where there is no TeX at all. Run with the math environment's Python
(it needs fontTools).

What is held, each with an input that must fail where a pass could be an accident:
- one bad formula fails ALONE, with TeX's own message, and the items around it are still set;
- TeX's order is kept: a fraction's bar comes between its numerator and its denominator;
- the origin is TeX's baseline (the `ghost:base` special), not the first glyph's: a radical hangs
  below the baseline, so an item that starts with one still has its "2" on y = 0;
- glyphs carry their PostScript names (`summationdisplay`, `radical`), which the hand reads.
"""
import pathlib
import shutil
import sys
import tempfile

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import typeset  # noqa: E402

FAILS = []


def check(ok, msg):
    print(("   ok   " if ok else "   FAIL ") + msg)
    if not ok:
        FAILS.append(msg)


def main():
    tex_bin = sys.argv[1] if len(sys.argv) > 1 else ""
    typeset._BIN["dir"] = tex_bin
    if shutil.which(typeset._prog("latex")) is None:
        print("test_typeset: SKIPPED - no TeX here (latex not found)")
        return 0
    work = pathlib.Path(tempfile.mkdtemp(prefix="ghost-typeset-"))
    try:
        answer = typeset.typeset({"work": str(work / "w"), "width": 300, "items": [
            {"id": "frac", "tex": r"\sqrt{2} = \frac{p}{q}"},
            {"id": "bad", "tex": r"\frac{1}{"},
            {"id": "sum", "tex": r"\sum_{k=1}^{n} k"},
        ]})
    finally:
        shutil.rmtree(work, ignore_errors=True)
    items = {it["id"]: it for it in answer["items"]}
    check(not items["bad"]["ok"] and "Missing }" in items["bad"]["error"],
          "a bad formula fails with TeX's own words (%s)" % items["bad"]["error"][:40])
    check(items["frac"]["ok"] and items["sum"]["ok"], "and the items around it are still set")

    frac = items["frac"]
    seq = sorted([(g["k"], g["n"]) for g in frac["glyphs"]] + [(r["k"], "RULE") for r in frac["rules"]])
    names = [n for _, n in seq]
    check(names == ["radical", "RULE", "two", "equal", "p", "RULE", "q"],
          "TeX's order: a radical, its bar, its radicand; a numerator, its bar, its denominator (%s)"
          % " ".join(names))
    two = next(g for g in frac["glyphs"] if g["n"] == "two")
    radical = next(g for g in frac["glyphs"] if g["n"] == "radical")
    check(abs(two["y"]) < 0.01, "the origin is TeX's baseline: the 2 sits on y = 0 (%.2f)" % two["y"])
    check(abs(radical["y"]) > 1.0,
          "the control: the radical, set first, is NOT on the baseline (%.2f) - so the first glyph "
          "could not have been the origin" % radical["y"])
    check(any(g["n"] == "summationdisplay" for g in items["sum"]["glyphs"]),
          "a display sum is named summationdisplay")
    if FAILS:
        print("test_typeset: %d FAILURE(S)" % len(FAILS))
        return 1
    print("test_typeset: ALL OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
