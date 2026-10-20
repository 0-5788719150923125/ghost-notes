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
- A DRAWING (figure.py): its labels set in the same run and placed where the SVG put them, the whole
  measured down from a baseline at its foot; a label TeX refuses fails the drawing alone, with TeX's
  words; a plot is computed (y = x squared through the right corner of its axes, 1/x broken at 0 and
  cut at the range's edge); an outline the SVG left unfilled is NOT shaded (SVG's own default fill is
  black - the control), a small filled circle is a dot and a big one hatched; an arrow ends at its
  line's end; and an expression that is not arithmetic in x is refused, names and calls alike.
- A SERIES A RUN KEPT (hosts/compute/run.py's keep(), 2026-10-19): joined point to point and cut at
  the box's edge, thinned when long, dotted (inside the box only), barred from the axis to its height;
  a name no run kept is refused (the control), and so are too many dots; typeset hands it through.
- MORE TO DRAW WITH (the user, 2026-10-19: "do the agents have the ability to draw charts, line
  graphs, etc.? ... the ability to draw arbitrary pictures would be useful"): a curve of t is traced
  whole inside its box (a unit circle closes on itself) and cut at the box's edges where it leaves it
  (the control, a circle too big for the box); a polar curve is a radius at its angle; ticks written
  with pi are numbered in pi (the control, the same ticks as a decimal, are not); a bar is hatched
  from its foot to its height; an angle's arc runs between its two directions, a right angle is a
  corner; a grid adds a faint line at each tick (the control, the same axes without it); and a range is a
  constant, never a variable.
"""
import math
import pathlib
import shutil
import sys
import tempfile

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import typeset  # noqa: E402
import figure  # noqa: E402

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
    _figures()
    if FAILS:
        print("test_typeset: %d FAILURE(S)" % len(FAILS))
        return 1
    print("test_typeset: ALL OK")
    return 0


def _figures():
    graph = ('<svg viewBox="0 0 360 200"><axes x="-2 2" y="-1 4" box="30 10 300 170" xlabel="$x$">'
             '<plot fn="x^2" id="curve"/><dot x="1" y="1" id="P"/><label x="1" y="1" id="Plab">$(1,1)$</label>'
             '</axes><g id="mark"><line x1="10" y1="190" x2="40" y2="190"/></g></svg>')
    work = pathlib.Path(tempfile.mkdtemp(prefix="ghost-figure-"))
    try:
        answer = typeset.typeset({"work": str(work / "w"), "width": 270, "items": [
            {"id": "g", "tex": graph, "mode": "figure"},
            {"id": "badlabel", "mode": "figure",
             "tex": '<svg viewBox="0 0 360 80"><line x1="0" y1="40" x2="360" y2="40"/><text x="5" y="70">$\\frac{1}{$</text></svg>'},
            {"id": "after", "tex": "x + 1"},
            {"id": "pinned", "tex": "1 + \\pin{t}{\\tan^2 x} = \\pin{s}{\\sec^2 x}"},
            {"id": "bare", "tex": "1 + \\tan^2 x = \\sec^2 x"},
        ]})
    finally:
        shutil.rmtree(work, ignore_errors=True)
    items = {it["id"]: it for it in answer["items"]}
    g = items["g"]
    check(g["ok"] and g.get("figure") and len(g["paths"]) > 5 and len(g["glyphs"]) > 5,
          "a drawing is set: its paths and its labels' glyphs (%d paths, %d glyphs)" % (len(g.get("paths", [])), len(g["glyphs"])))
    ys = [pt[1] for p in g["paths"] for pt in p["pts"]] + [gl["y"] + gl["dp"] for gl in g["glyphs"]]
    check(max(ys) <= 0.01 and g["d"] == 0.0 and abs(min(ys) + g["h"]) < 2.0,
          "measured down from a baseline at its foot (%.1f to %.1f, h %.1f)" % (min(ys), max(ys), g["h"]))
    check(not items["badlabel"]["ok"] and "Missing }" in items["badlabel"]["error"] and items["after"]["ok"],
          "a label TeX refuses fails its drawing alone, with TeX's words (%s)" % items["badlabel"]["error"][:60])
    kinds = [p["kind"] for p in g["paths"]]
    check("dot" in kinds and "arrow" in kinds, "the axes have arrowheads and the point a dot (%s)" % ", ".join(sorted(set(kinds))))

    # A PART THE PEN CAN POINT AT: an id names a drawing's part, \pin a formula's, each with its box
    an = g.get("anchors", {})
    check(sorted(an) == ["P", "Plab", "curve", "mark"], "a drawing's named parts come back, axes' children and a group's too (%s)" % sorted(an))
    if "P" in an and "curve" in an and "Plab" in an:
        P, C, L = an["P"], an["curve"], an["Plab"]
        check(P[2] - P[0] < 8 and C[2] - C[0] > 200 and C[0] <= P[0] <= C[2] and C[1] <= P[1] <= C[3],
              "a dot's box is a dot's, on its curve, which spans the axes (%s in %s)" % (P, C))
        check(abs(L[0] - P[2]) < 12 and L[3] <= P[3] + 1, "and a label's box is where it was put, beside its dot (%s)" % L)
    pinned, bare = items["pinned"], items["bare"]
    pa = pinned.get("anchors", {})
    check(pinned["ok"] and sorted(pa) == ["s", "t"], "a formula's \\pin parts come back (%s)" % sorted(pa))
    if sorted(pa) == ["s", "t"]:
        t, sb = pa["t"], pa["s"]
        check(0 < t[0] < t[2] < sb[0] < sb[2] <= pinned["w"] + 0.01 and t[1] < 0 < t[3] + 1,
              "each where it was set, in order, inside the formula (%s, %s of %.1f)" % (t, sb, pinned["w"]))
    check(bare["ok"] and abs(bare["w"] - pinned["w"]) < 0.01 and bare.get("anchors") == {},
          "a pin changes nothing of how a formula is set, and with none there is no part (the control: %.2f vs %.2f)"
          % (bare["w"], pinned["w"]))

    runs = figure._curve(figure.expression("x^2"), -2, 2, 0, 4)
    check(len(runs) == 1 and abs(runs[0][0][1] - 4) < 1e-9 and abs(runs[0][-1][0] - 2) < 1e-9,
          "y = x squared runs corner to corner of its range")
    inv = figure._curve(figure.expression("1/x"), -2, 2, -4, 4)
    check(len(inv) == 2 and all(-4 - 1e-9 <= y <= 4 + 1e-9 for r in inv for _, y in r)
          and abs(abs(inv[0][-1][1]) - 4) < 1e-6,
          "1/x is broken at 0 and cut where it leaves the range (%d runs)" % len(inv))
    for bad in ("2x", "__import__('os')", "x + y", "open(x)"):
        try:
            figure.expression(bad)
            check(False, "an expression that is not arithmetic in x is refused: %r" % bad)
        except figure.FigureError:
            check(True, "an expression that is not arithmetic in x is refused: %r" % bad)

    shapes = figure.compile_figure(
        '<svg viewBox="0 0 360 120"><circle cx="40" cy="60" r="30"/>'
        '<circle cx="140" cy="60" r="30" fill="black"/><circle cx="240" cy="60" r="3" fill="black"/>'
        '<line x1="260" y1="60" x2="350" y2="60" arrow="end"/></svg>')
    kinds = [p["kind"] for p in shapes["paths"]]
    first_hatch = kinds.index("hatch") if "hatch" in kinds else -1
    check(kinds[0] == "line" and kinds[1] == "line" and first_hatch == 2,
          "an outline the SVG left unfilled is not shaded, and a filled one is hatched (%s)" % ", ".join(kinds[:4]))
    check(kinds.count("dot") == 1, "a small filled circle is a dot")
    line = [p for p in shapes["paths"] if p["kind"] == "line"][-1]
    head = shapes["paths"][-1]
    check(head["kind"] == "arrow" and head["pts"][1] == line["pts"][-1], "an arrow's tip is its line's end")
    try:
        figure.compile_figure('<svg viewBox="0 0 10 10"><plot fn="x"/></svg>')
        check(False, "a plot outside axes is refused")
    except figure.FigureError as e:
        check("axes" in str(e), "a plot outside axes is refused, saying where it belongs (%s)" % e)
    _more()
    _data(work)


def _more():
    import math
    # A CURVE OF t, whole inside its box and cut at the box's edges where it leaves it
    unit = figure._traced(math.cos, math.sin, 0.0, math.tau, -1.5, 1.5, -1.5, 1.5)
    on = all(abs(math.hypot(x, y) - 1.0) < 1e-9 for r in unit for x, y in r)
    check(len(unit) == 1 and on and math.dist(unit[0][0], unit[0][-1]) < 1e-9,
          "a curve of t is traced whole: the unit circle closes on itself (%d run)" % len(unit))
    big = figure._traced(lambda t: 2 * math.cos(t), lambda t: 2 * math.sin(t), 0.0, math.tau, -1.5, 1.5, -1.5, 1.5)
    edges = all(abs(abs(p[0]) - 1.5) < 1e-9 or abs(abs(p[1]) - 1.5) < 1e-9 for r in big for p in (r[0], r[-1]))
    check(len(big) >= 4 and edges, "the control: a circle too big for its box is cut where it leaves it, at the edges (%d runs)" % len(big))
    fig = figure.compile_figure('<svg viewBox="0 0 360 200"><axes x="-2.5 2.5" y="-2 2" box="30 10 300 180">'
                                '<plot r="1+cos(t)" t="0 2*pi" id="c"/></axes></svg>')
    xs = [pt[0] for p in fig["paths"] if p["kind"] == "line" and len(p["pts"]) > 50 for pt in p["pts"]]
    sc = figure.COLUMN_PT / figure.COLUMN
    check(xs and abs(max(xs) - (30 + 300 * (2 + 2.5) / 5) * sc) < 0.5 and abs(min(xs) - (30 + 300 * (2.5 - 0.25) / 5) * sc) < 0.5,
          "a polar curve is a radius at its angle: the cardioid reaches x = 2 and back to x = -1/4 (%.1f..%.1f)" % (min(xs), max(xs)))
    # TICKS IN PI
    trig = figure.compile_figure('<svg viewBox="0 0 360 160"><axes x="0 2*pi" y="-1.2 1.2" ticks="pi/2 1"><plot fn="sin(x)"/></axes></svg>')
    labels = [lab["tex"] for lab in trig["labels"]]
    plain = figure.compile_figure('<svg viewBox="0 0 360 160"><axes x="0 6.2832" y="-1.2 1.2" ticks="1.5708 1"><plot fn="sin(x)"/></axes></svg>')
    check(all(t in labels for t in ("$\\pi/2$", "$\\pi$", "$3\\pi/2$")) and "$1.57$" in [lab["tex"] for lab in plain["labels"]],
          "ticks written with pi are numbered in pi (%s; the control, written as decimals, %s)"
          % (" ".join(labels[:3]), " ".join(lab["tex"] for lab in plain["labels"][:2])))
    # A BAR, its foot on the axis and its top at its height, shaded
    bars = figure.compile_figure('<svg viewBox="0 0 360 200"><axes x="0 4" y="0 4" box="40 10 280 180">'
                                 '<rect x="1" y="0" width="1" height="3" fill="black" id="bar"/></axes></svg>')
    hatch = [p for p in bars["paths"] if p["kind"] == "hatch"]
    tops = [pt[1] for p in bars["paths"] if p["kind"] == "line" and len(p["pts"]) >= 4 for pt in p["pts"]]
    check(hatch and tops and abs(min(tops) - (10 + 180 * (1 - 3 / 4)) * sc) < 0.5 and abs(max(tops) - 190 * sc) < 0.5,
          "a bar stands from its foot on the axis to its height, hatched (%d hatch lines)" % len(hatch))
    # AN ANGLE: its arc from one direction to the other; a right angle a corner
    ang = figure.compile_figure('<svg viewBox="0 0 360 120"><line x1="50" y1="100" x2="300" y2="100"/>'
                                '<angle x="50" y="100" r="40" from="0" to="35" id="th"/>'
                                '<angle x="300" y="100" r="12" from="90" to="180" right="true"/></svg>')
    arc = ang["paths"][1]["pts"]
    end = (50 + 40 * math.cos(math.radians(35)), 100 - 40 * math.sin(math.radians(35)))
    corner = ang["paths"][2]["pts"]
    check(abs(arc[0][0] - 90 * sc) < 0.01 and abs(arc[0][1] - 100 * sc) < 0.01 and math.dist(arc[-1], (end[0] * sc, end[1] * sc)) < 0.01
          and len(corner) == 3 and math.dist(corner[1], (288 * sc, 88 * sc)) < 0.01,
          "an angle's arc runs from one direction to the other, counterclockwise as seen, and a right angle is a corner")
    # A GRID: dotted lines at the ticks, under the rest
    gridded = figure.compile_figure('<svg viewBox="0 0 360 200"><axes x="-3 3" y="-2 2" grid="true"><plot fn="x"/></axes></svg>')
    bare = figure.compile_figure('<svg viewBox="0 0 360 200"><axes x="-3 3" y="-2 2"><plot fn="x"/></axes></svg>')
    grid = [p for p in gridded["paths"] if p["kind"] == "grid"]
    check(len(grid) == 10 and gridded["paths"][0]["kind"] == "grid" and len(gridded["paths"]) == len(bare["paths"]) + 10
          and not any(p["kind"] == "grid" for p in bare["paths"]),
          "a grid adds a faint line at each tick but the axes', drawn first (%d; the control, without it, none)" % len(grid))
    for bad in ('<plot x="cos(t)" y="sin(t)" t="0 x"/>', '<plot x="cos(x)" y="sin(t)" t="0 1"/>'):
        try:
            figure.compile_figure('<svg viewBox="0 0 360 200"><axes x="-1 1" y="-1 1">%s</axes></svg>' % bad)
            check(False, "a range is a constant and a curve of t names only t: %s" % bad)
        except figure.FigureError as e:
            check(True, "a range is a constant and a curve of t names only t (%s)" % e)



def _data(work):
    """A SERIES A RUN KEPT, drawn by its name: joined, dotted, barred; refused when no run kept it."""
    sq = {"sq": {"points": [[i / 10.0, (i / 10.0) ** 2] for i in range(31)]}}
    svg = '<svg viewBox="0 0 360 200"><axes x="0 2" y="0 4" box="40 10 280 180">%s</axes></svg>'
    sc = figure.COLUMN_PT / figure.COLUMN
    fig = figure.compile_figure(svg % '<plot data="sq" id="s"/>', sq)
    line = [p for p in fig["paths"] if p["kind"] == "line" and len(p["pts"]) > 10]
    ends = line[0]["pts"][-1] if line else (0, 0)
    check(len(line) == 1 and len(line[0]["pts"]) == 21 and abs(ends[0] - (40 + 280) * sc) < 0.5 and abs(ends[1] - 10 * sc) < 0.5,
          "a kept series is joined point to point, and cut at the box's edge where it leaves it (%d points, ending at the corner)"
          % (len(line[0]["pts"]) if line else 0))
    try:
        figure.compile_figure(svg % '<plot data="sq"/>', {})
        check(False, "the control: a series no run kept is refused")
    except figure.FigureError as e:
        check("no run kept" in str(e), "the control: a series no run kept is refused (%s)" % e)
    many = {"n": {"points": [[i, math.sin(i / 300.0)] for i in range(5000)]}}
    thin = figure.compile_figure('<svg viewBox="0 0 360 200"><axes x="0 5000" y="-1.2 1.2"><plot data="n"/></axes></svg>', many)
    longest = max(len(p["pts"]) for p in thin["paths"] if p["kind"] == "line")
    check(longest <= figure.PLOT_MOST + 1 + 2, "a long series is thinned for the pen (%d of 5000 points)" % longest)
    five = {"d": {"points": [[0.2, 1], [0.6, 2], [1.0, 3], [1.4, 2], [3.0, 1]]}}
    dots = figure.compile_figure(svg % '<dots data="d"/>', five)
    check(sum(1 for p in dots["paths"] if p["kind"] == "dot") == 4, "a dot at each point inside the box (4 of 5: one is past x = 2)")
    bars = figure.compile_figure(svg % '<bars data="d" width="0.2" fill="black"/>', five)
    rects = [p for p in bars["paths"] if p["kind"] == "line" and len(p["pts"]) >= 4 and p["pts"][0] != p["pts"][1]]
    tall = [min(pt[1] for pt in r["pts"]) for r in rects[-4:]]
    want = [(10 + 180 * (1 - h / 4.0)) * sc for h in (1, 2, 3, 2)]
    check(len(rects) >= 4 and all(abs(a - b) < 0.5 for a, b in zip(tall, want)) and any(p["kind"] == "hatch" for p in bars["paths"]),
          "a bar stands on the axis at each x, as tall as its y, shaded")
    try:
        figure.compile_figure(svg % '<dots data="n"/>', many)
        check(False, "too many dots are refused")
    except figure.FigureError as e:
        check("at most" in str(e), "too many dots are refused (%s)" % e)
    got = typeset.typeset({"work": str(work / "d"), "width": 300, "data": sq,
                           "items": [{"id": "f", "mode": "figure", "tex": svg % '<plot data="sq"/>'}]})
    check(got["items"][0]["ok"] if isinstance(got, dict) and "items" in got else False,
          "typeset hands a drawing the episode's data")


if __name__ == "__main__":
    sys.exit(main())
