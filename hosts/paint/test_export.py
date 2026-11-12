#!/usr/bin/env python3
"""Gate for the painter host's output (export.py): what the show plays is what the painter laid.

Run it directly with the paint venv's python - no pytest, no GPU (a picture of thin lines only, so the optimizer is never imported):

    ~/.local/share/godot/app_userdata/ghost/paint_venv/bin/python hosts/paint/test_export.py

A small made surface - a white ground; a curved black line; then a gold one beside it, the black redrawn a pixel aside as an image
model redraws what it was given - painted as an episode's layers are (layers_paint.paint_layers), exported as the show reads it, and held
to three things:

  1. THE MAPS COME TO THE CANVAS: each element's color laid over what is under it by its coverage, in order, is the painter's own canvas
     (skin_paint.gdshader lays them so). CONTROL: the same elements in the reverse order must not.
  2. THE PROGRAM IS ONE CLOCK: keys in time order, ending at the element's length; each stroke's times inside it; every point's first
     reach and its staged times inside it (0-1), where it is laid at all.
  3. A THIN LINE IS LAID IN THE PAINT IT WAS LAID IN (layers_paint.laid_paints): the gold step laid in gold alone - the black redrawn
     aside traced again by no one. CONTROL: the rule it replaced (the step's change cut by color, each part's color its most laid
     points' darker half) finds a part that is not gold.
  4. A POINT LAID TWICE SHOWS THE PAINTER'S CANVAS AFTER ITS FIRST MARK (: a dark pull's first pass showed half its color
     where a second would cross, a pale patch in the streak): the element's first staged coverage of its color over what was under it.
     CONTROL: the coverage shared out by how many marks touch the point, as it was, does not.
  5. A HAND'S ORDER (export._hand_order): on a second made surface, a flat's pulls laid across and up the face by turns, every other one the other way, and one
     with a tail - exported, each pull within 90 degrees of the last, gathered by the way they go, the tailed one its own way, the maps
     still the canvas and staged from the order the program plays. CONTROL: the order and ways they were laid in.
  6. A LOAD ONLY RUNS OUT (export.LOAD_HEAVIER): a flat's pulls in one paint,
     faint and strong by turns, as the optimizer finds them - exported, none lays more than the one before by LOAD_HEAVIER without a
     trip to the pot between them, and the maps still come to the canvas. CONTROL: the program as it was, with no such trip, does.
  8. ONE LAYER AGAIN (run.py `only`, export.merge_layer): a layer painted again alone over the canvas the ones before it leave, put among
     the rest - their elements as they were, its own with ids past them, the canvas near the whole painting's. CONTROL: the layer left out.
  7. A PLACE AT A TIME (export._places, PLACE_MM; 2026-11-10: "They tend to jump around the entire face, to random places"): a run's
     pulls in two places 110 mm apart, listed turn about, are gathered into the two places. CONTROL: one place as wide as the face.
"""

import json
import sys
import tempfile
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))

FAILS = []


def check(ok, what):
    print(("  ok    " if ok else "  FAIL  ") + what)
    if not ok:
        FAILS.append(what)


def made_surface():
    """The surface and its three steps' pictures: 40 mm square, a disc of face; a white ground, a black arc, then a gold one beside it
    with the black redrawn a little aside."""
    from run import FromSpec
    from canvas import PX
    px = 4.0
    n = int(40 * px)
    yy, xx = np.mgrid[0:n, 0:n] / px
    face = (xx - 20) ** 2 + (yy - 20) ** 2 < 18 ** 2
    ground = np.zeros((n, n, 4))
    ground[..., :3] = np.array([0.96, 0.95, 0.93])
    ground[..., 3] = face
    black = ground.copy()
    r = np.hypot(xx - 20, yy - 30)
    black[(np.abs(r - 14) < 0.35) & (yy < 27) & face, :3] = np.array([0.07, 0.07, 0.08])
    lined = ground.copy()
    r2 = np.hypot(xx - 20.3, yy - 30.2)
    lined[(np.abs(r2 - 14) < 0.35) & (yy < 27) & face, :3] = np.array([0.07, 0.07, 0.08])
    lined[(np.abs(r - 12.6) < 0.2) & (yy < 27) & face, :3] = np.array([0.69, 0.55, 0.27])
    spec = {"paints": {"white paint": "#f6f3ec", "black paint": "#121214", "old gold cream": "#b08d45", "slate cream": "#4d6372"},
            "bare": "#c89e80", "px": px, "size": [n, n]}
    ref = FromSpec(spec, lined)
    from PIL import Image
    pics = []
    for rgba in (ground, black, lined):
        img = Image.fromarray((np.clip(rgba, 0, 1) * 255).astype(np.uint8))
        pics.append(np.asarray(img.resize((ref.w, ref.h), Image.BICUBIC)).astype(float)[..., :3] / 255.0)
    assert ref.w == int(round(40 * PX))
    return ref, pics


def recompose(els, root, shape, order):
    """The elements' maps laid in `order` as the shader lays them (export.recompose, which a layer painted again alone is painted over)."""
    from export import recompose as laid
    return laid(els, root, shape, order)


def first_marks(p, starts, els, root):
    """For every point two or more of an element's marks lay: how far what the show draws after its first mark (the element's first
    staged coverage of its color over what was under it, pre-multiplied as the shader lays it) is from the painter's canvas after that
    mark - and the same, the coverage shared out by how many marks touch the point ('s pale patches)."""
    from export import groups
    pre = np.zeros((p.cv.h, p.cv.w, 3))
    alp = np.zeros((p.cv.h, p.cv.w))
    off, off_count = [], []
    for g, e in zip(groups(p, starts), els):
        marks = [p.laid[i][0] for i in g["marks"]]
        y0, y1 = min(m.sl[0].start for m in marks), max(m.sl[0].stop for m in marks)
        x0, x1 = min(m.sl[1].start for m in marks), max(m.sl[1].stop for m in marks)
        pre0 = pre[y0:y1, x0:x1].copy()
        first = np.zeros(pre0.shape)
        n = np.zeros(pre0.shape[:2], np.int32)
        for m in marks:
            sy, sx = slice(m.sl[0].start - y0, m.sl[0].stop - y0), slice(m.sl[1].start - x0, m.sl[1].stop - x0)
            ch = (np.abs(m.pre - pre[m.sl]).sum(-1) + np.abs(m.alp - alp[m.sl])) > 1e-3
            pre[m.sl], alp[m.sl] = m.pre, m.alp
            at = first[sy, sx]
            new = ch & (n[sy, sx] == 0)
            at[new] = m.pre[new]
            n[sy, sx] += ch
        mp = e["maps"]
        w, h = mp["w"], mp["h"]
        assert (w, h) == (x1 - x0, y1 - y0)
        c0 = np.fromfile(root / mp["built0"], np.uint8).reshape(h, w, 4)[..., 0] / 255.0
        cover = np.fromfile(root / mp["cover"], np.uint8).reshape(h, w) / 255.0
        tint = np.fromfile(root / mp["tint"], np.uint8).reshape(h, w, 3) / 255.0
        sel = n >= 2
        for c, into in ((c0, off), (cover / np.maximum(n, 1), off_count)):
            shown = tint * c[..., None] + pre0 * (1 - c[..., None])
            into.extend(np.abs(shown - first).max(-1)[sel].tolist())
    return np.asarray(off), np.asarray(off_count)


class _Made:
    """A painter's laid marks, as the export reads them (`cv`, `laid`, `_color`)."""

    def __init__(self, cv, laid, colors):
        self.cv, self.laid, self._colors = cv, laid, colors

    def _color(self, name):
        return self._colors[name]


def _pulls(prog):
    """A program's pulls (more than a point): each one's way across the surface, unit."""
    out = []
    for s in prog["strokes"]:
        pts = np.asarray(s["pts"], float)
        if len(pts) >= 2 and np.linalg.norm(pts[-1] - pts[0]) > 1.0:
            out.append((pts[-1] - pts[0]) / np.linalg.norm(pts[-1] - pts[0]))
    return out


def hand_order():
    """5. A HAND'S ORDER (export._hand_order): a flat's pulls laid as the optimizer leaves them - across and up and down the face by turns, every other
    one the other way - and one with a tail. Exported, each pull runs within 90 degrees of the one before, the pulls are gathered by the
    way they go, the tailed one keeps its way, the maps still come to the canvas, and a point laid twice shows after its first mark what
    the canvas held after the first pull the program plays there. CONTROL: the order and ways they were laid in do none of it."""
    import marks as mk
    from canvas import Canvas, PX
    from export import export, _hand_order
    from marks import Mark
    n = int(40 * PX)
    yy, xx = np.mgrid[0:n, 0:n] / PX
    face = (xx - 20) ** 2 + (yy - 20) ** 2 < 18 ** 2
    cv = Canvas(n, n, (0.78, 0.62, 0.5), face)
    white, slate = np.array([0.96, 0.95, 0.93]), np.array([0.30, 0.39, 0.45])
    ground_pre = np.where(face[..., None], white, 0.0)
    ground = Mark("pat", "sponge", (slice(0, n), slice(0, n)), ground_pre, face.astype(float), np.array([[20.0, 20.0]]), 0.0, 1,
                  "white paint", {"c": [20.0, 20.0], "r": 18.0})
    cv.lay(ground.sl, ground.pre, ground.alp, 0.0)
    laid = [(ground, 0.0, 0.0)]
    # (...two across, then two up and down the face, by turns, every other one the other way - the optimizer's own; then a pull with a
    # tail, drawn down the face)
    ways = [((10, 12), (30, 12)), ((30, 16), (10, 16)), ((12, 30), (12, 10)), ((16, 10), (16, 30)), ((10, 20), (30, 20)),
            ((30, 24), (10, 24)), ((20, 30), (20, 10)), ((24, 10), (24, 30))]
    for a, b in ways:
        m = mk.brush_stroke(cv, np.linspace(a, b, 21), 1.6, slate, "slate cream", 0.6, 1.0, "sweep", "flat", tail=0.0, load_mm=1e9, seed=3)
        cv.lay(m.sl, m.pre, m.alp, 0.0)
        laid.append((m, 0.0, 0.0))
    tailed = mk.brush_stroke(cv, np.linspace((28, 8), (28, 30), 21), 1.6, slate, "slate cream", 0.6, 1.0, "sweep", "flat", seed=5)
    cv.lay(tailed.sl, tailed.pre, tailed.alp, 0.0)
    laid.append((tailed, 0.0, 0.0))
    p = _Made(cv, laid, {"white paint": white, "slate cream": slate})
    starts, steps = [0, 1], [{"name": "ground"}, {"name": "pulls"}]
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        els = export(p, starts, steps, root, log=lambda s: None)
        el = [e for e in els if e["layer"] == 1][0]
        made = _pulls(el["program"])
        as_laid = [(np.asarray(m.rec["pts"])[-1] - np.asarray(m.rec["pts"])[0]) / np.linalg.norm(np.asarray(m.rec["pts"])[-1] - np.asarray(m.rec["pts"])[0])
                   for m, _, _ in laid[1:]]
        turned = lambda vs: sum(1 for u, v in zip(vs, vs[1:]) if float(np.dot(u, v)) < 0.0)
        gathered = lambda vs: sum(1 for u, v in zip(vs[:-1], vs[1:-1]) if abs(float(np.dot(u, v))) < 0.5)
        free_made, free_laid = made[:-1], as_laid[:-1]
        check(len(made) == len(ways) + 1 and turned(free_made) == 0,
              "each pull runs within 90 degrees of the one before (%d of %d turned past it)" % (turned(free_made), len(free_made) - 1))
        check(turned(free_laid) >= 3, "CONTROL: as they were laid, %d of %d turned past it" % (turned(free_laid), len(free_laid) - 1))
        check(gathered(made) <= 1, "the pulls are gathered by the way they go (%d changes of way)" % gathered(made))
        check(gathered(as_laid) >= 3, "CONTROL: as they were laid, %d changes of way" % gathered(as_laid))
        check(float(np.dot(made[-1], np.array([0.0, 1.0]))) > 0.99, "the pull with a tail keeps its way, down the face")
        pre, alp = recompose(els, root, (n, n), range(len(els)))
        off = np.abs(pre - cv.pre).max(-1)[face]
        check(float(np.percentile(off, 99.5)) < 0.03, "the maps still come to the canvas (99.5th percentile off %.4f)" % np.percentile(off, 99.5))
        # (...staged from the order the program plays: the canvas after each point's first pull, in that order)
        hm = _hand_order([m for m, _, _ in laid[1:]], ground.pre, ground.alp, slate, 40.0)
        played = _Made(cv, [laid[0]] + [(m, 0.0, 0.0) for m in hm], p._colors)
        off_played, _ = first_marks(played, starts, els, root)
        off_laid, _ = first_marks(p, starts, els, root)
        check(len(off_played) > 0 and float(np.percentile(off_played, 99)) < 0.05,
              "a point laid twice shows the canvas after the first pull the program plays there (99th percentile off %.4f)"
              % np.percentile(off_played, 99))
        check(float(np.percentile(off_laid, 99)) > 0.05,
              "CONTROL: against the order they were laid in it does not (99th percentile off %.4f)" % np.percentile(off_laid, 99))


def loads():
    """6. A LOAD ONLY RUNS OUT (export.LOAD_HEAVIER): six pulls of a flat in one paint across the face, at the
    strengths the optimizer finds them - strong and faint by turns. Exported, no pull lays more than the one before it by LOAD_HEAVIER
    without a trip to the pot between them, and the maps still come to the canvas. CONTROL: with no such trip, as the program was, one
    does."""
    import export as ex
    import marks as mk
    from canvas import Canvas, PX
    from marks import Mark
    n = int(40 * PX)
    yy, xx = np.mgrid[0:n, 0:n] / PX
    face = (xx - 20) ** 2 + (yy - 20) ** 2 < 18 ** 2
    cv = Canvas(n, n, (0.78, 0.62, 0.5), face)
    white, amber = np.array([0.96, 0.95, 0.93]), np.array([0.78, 0.60, 0.18])
    ground = Mark("pat", "sponge", (slice(0, n), slice(0, n)), np.where(face[..., None], white, 0.0), face.astype(float),
                  np.array([[20.0, 20.0]]), 0.0, 1, "white paint", {"c": [20.0, 20.0], "r": 18.0})
    cv.lay(ground.sl, ground.pre, ground.alp, 0.0)
    laid = [(ground, 0.0, 0.0)]
    strengths = [0.85, 0.3, 0.8, 0.25, 0.75, 0.7]
    for k, th in enumerate(strengths):
        x = 10.0 + 4.0 * k
        m = mk.brush_stroke(cv, np.linspace((x, 30.0), (x, 12.0), 21), 1.4, amber, "amber cream", th, 1.0, "sweep", "flat", tail=0.0,
                            load_mm=1e9, seed=7 + k)
        cv.lay(m.sl, m.pre, m.alp, 0.0)
        laid.append((m, 0.0, 0.0))
    p = _Made(cv, laid, {"white paint": white, "amber cream": amber})
    starts, steps = [0, 1], [{"name": "ground"}, {"name": "pulls"}]

    def unloaded(prog):
        """How many of the program's pulls lay more than the one before by LOAD_HEAVIER with no trip to the pot between them."""
        trips = [k[0] for k in prog["keys"] if int(k[5]) == 1]
        out, prev = 0, None
        for st in prog["strokes"]:
            th = strengths[int(round((float(np.mean(np.asarray(st["pts"])[:, 0])) - 10.0) / 4.0))]
            if prev is not None and th > prev[0] + 0.2 and not any(prev[1] < t < st["t"][0] for t in trips):
                out += 1
            prev = (th, st["t"][-1])
        return out

    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        els = ex.export(p, starts, steps, root, log=lambda s: None)
        el = [e for e in els if e["layer"] == 1][0]
        pre, alp = recompose(els, root, (n, n), range(len(els)))
        off = np.abs(pre - cv.pre).max(-1)[face]
        check(len(el["program"]["strokes"]) == len(strengths) and unloaded(el["program"]) == 0 and float(np.percentile(off, 99.5)) < 0.03,
              "no pull lays markedly more than the one before without a trip to the pot (%d did; %d trips), the maps still the canvas "
              "(99.5th percentile off %.4f)" % (unloaded(el["program"]), sum(1 for k in el["program"]["keys"] if int(k[5]) == 1) // 2,
                                                np.percentile(off, 99.5)))
    saved = ex.LOAD_HEAVIER
    ex.LOAD_HEAVIER = 1e9
    try:
        with tempfile.TemporaryDirectory() as tmp:
            els = ex.export(p, starts, steps, Path(tmp), log=lambda s: None)
            was = unloaded([e for e in els if e["layer"] == 1][0]["program"])
    finally:
        ex.LOAD_HEAVIER = saved
    check(was >= 1, "CONTROL: as the program was, %d pulls lay markedly more than the one before with no trip between" % was)


def check_one_layer(ref, pics, steps, els, root, shape):
    """8. ONE LAYER PAINTED AGAIN (next/editing.md step 4): the second layer alone, over the canvas the first left (its elements' maps),
    merged among the rest - the others' elements as they were, ids and maps; the new ones past every kept id; and the canvas they
    all leave near the whole painting's. CONTROL: the layer left out, the canvas far from it."""
    from layers_paint import paint_layers
    from export import export, recompose, merge_layer
    whole, _ = recompose(els, root, shape)
    face = ref.face
    with tempfile.TemporaryDirectory() as t2:
        t2 = Path(t2)
        under = [i for i, e in enumerate(els) if int(e["layer"]) < 1]
        canvas = recompose(els, root, shape, under)
        p, starts, _ = paint_layers(ref, steps, pics, log=lambda s: None, first=1, last=1, canvas=canvas)
        fresh = export(p, starts, steps, t2 / "fresh", log=lambda s: None, canvas=canvas, base_layer=-1)
        for e in fresh:
            e["layer"] = 1
        merged = merge_layer(els, root, fresh, t2 / "fresh", 1, t2 / "out")
        kept_ids = [e["id"] for e in els if int(e["layer"]) != 1]
        same = [e["id"] for e in merged if int(e["layer"]) != 1] == kept_ids and all(
            (root / f).read_bytes() == (t2 / "out" / f).read_bytes()
            for e in merged if int(e["layer"]) != 1 for f in e["maps"].values() if isinstance(f, str))
        check(same, "the other layers' elements are as they were, ids and maps")
        top = max(int(i.split("_")[-1]) for i in [e["id"] for e in els])
        new = [e for e in merged if int(e["layer"]) == 1]
        check(bool(new) and all(int(e["id"].split("_")[-1]) > top for e in new), "the layer's new elements take ids past every kept one")
        again, _ = recompose(merged, t2 / "out", shape)
        near = float(np.abs(again - whole).max(-1)[face].mean())
        gone, _ = recompose([e for e in merged if int(e["layer"]) != 1], t2 / "out", shape)
        far = float(np.abs(gone - whole).max(-1)[face].mean())
        check(near < 0.02 and far > near * 2, "the canvas they leave is near the whole painting's (%.4f); CONTROL: the layer left out, far (%.4f)" % (near, far))


def main():
    from layers_paint import paint_layers
    from export import export, NEVER
    ref, pics = made_surface()
    steps = [{"name": "ground"}, {"name": "line"}, {"name": "gold"}]
    p, starts, _ = paint_layers(ref, steps, pics, log=lambda s: None)
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        els = export(p, starts, steps, root, log=lambda s: None)
        print("%d elements: %s" % (len(els), ", ".join("%s %s %s" % (e["id"], e["tool"], e["paint"]) for e in els)))
        check(len(els) >= 2 and els[0]["layer"] == 0, "the ground is the first element, the lines after it")

        # 8. One layer again (run.py `only`; export.merge_layer): the line painted again alone over the canvas the ground left
        check_one_layer(ref, pics, steps, els, root, (p.cv.h, p.cv.w))

        # 1. the maps come to the canvas
        shape = (p.cv.h, p.cv.w)
        pre, alp = recompose(els, root, shape, range(len(els)))
        face = ref.face
        off = np.abs(pre - p.cv.pre).max(-1)[face]
        aoff = np.abs(alp - p.cv.alp)[face]
        check(float(np.percentile(off, 99.5)) < 0.03 and float(np.percentile(aoff, 99.5)) < 0.03,
              "the elements laid in order come to the painter's canvas (99.5th percentile off: color %.4f, coverage %.4f)"
              % (np.percentile(off, 99.5), np.percentile(aoff, 99.5)))
        rpre, _ = recompose(els, root, shape, range(len(els) - 1, -1, -1))
        roff = np.abs(rpre - p.cv.pre).max(-1)[face]
        check(float(roff.max()) > 0.2, "CONTROL: laid in the reverse order they do not (most off %.3f)" % roff.max())

        # 2. one clock
        for e in els:
            pg = e["program"]
            nat = float(pg["natural"])
            ts = [k[0] for k in pg["keys"]]
            ok = all(b >= a - 1e-6 for a, b in zip(ts, ts[1:])) and abs(ts[-1] - nat) < 1e-3 * max(nat, 1.0)
            ok = ok and all(0.0 <= min(s["t"]) and max(s["t"]) <= nat + 1e-3 for s in pg["strokes"])
            m = e["maps"]
            w, h = m["w"], m["h"]
            cover = np.fromfile(root / m["cover"], np.uint8).reshape(h, w) > 0
            when = np.fromfile(root / m["when"], np.float16).reshape(h, w, 3).astype(float)
            bw = np.concatenate([np.fromfile(root / m["built_when0"], np.float16).reshape(h, w, 4),
                                 np.fromfile(root / m["built_when1"], np.float16).reshape(h, w, 4)], -1).astype(float)
            laid = bw[cover]
            ok = ok and bool(((when[cover][:, 0] >= 0) & (when[cover][:, 0] <= 1.001)).all())
            ok = ok and bool(((laid >= 0) & ((laid <= 1.001) | (laid >= NEVER * 0.99))).all())
            check(ok, "%s: keys in order to its %.1f s, strokes and maps inside them" % (e["id"], nat))

        # 3. the gold step laid in gold, the black redrawn aside no one's
        gold_paints = [e["paint"] for e in els if e["layer"] == 2]
        check(bool(gold_paints) and all("gold" in nm for nm in gold_paints), "the gold step is laid in gold alone (%s)" % ", ".join(gold_paints))
        import layers_paint as LP
        from color import dec, oklab
        labs = [oklab(dec(x)) for x in pics]
        alpha = LP.layer_alpha(LP.changed(labs[1], labs[2], ref.face), ref.face)
        opt = oklab(dec(p.opt_cols))
        old = []
        for m in LP.parts(alpha, labs[2], thresh=0.3):
            sel = m & (alpha > 0.8) if (m & (alpha > 0.8)).sum() >= 4 else m
            cl = labs[2][sel]
            core = np.median(cl[cl[:, 0] <= np.median(cl[:, 0])], axis=0)
            old.append(p.opt_names[int(np.argmin(np.linalg.norm((opt - core) * p.HUE, axis=1)))])
        check(any("gold" not in nm for nm in old), "CONTROL: the rule it replaced finds %s" % ", ".join(old))

        # 4. a point laid twice shows, after its first mark, what the painter's canvas held then
        off, off_count = first_marks(p, starts, els, root)
        check(len(off) > 0 and float(np.percentile(off, 99)) < 0.05,
              "a point two marks lay shows the painter's canvas after the first (%d points, 99th percentile off %.4f)"
              % (len(off), np.percentile(off, 99) if len(off) else -1))
        check(len(off_count) > 0 and float(np.percentile(off_count, 99)) > 0.1,
              "CONTROL: shared out by how many marks touch it, it does not (99th percentile off %.3f)"
              % (np.percentile(off_count, 99) if len(off_count) else -1))
    hand_order()
    loads()
    # 7. a place at a time
    import export as ex7
    left = [np.array([10.0 + k, 20.0]) for k in range(4)]
    right = [np.array([120.0 + k, 30.0]) for k in range(4)]
    mids = [left[0], right[0], left[1], right[1], left[2], right[2], left[3], right[3]]
    places = ex7._places(mids, ex7.PLACE_MM)
    check(len(places) == 2 and sorted(places[0]) == [0, 2, 4, 6] and sorted(places[1]) == [1, 3, 5, 7],
          "a run's pulls in two places, listed turn about, are swept a place at a time: %s" % places)
    check(len(ex7._places(mids, 1e9)) == 1, "CONTROL: one place as wide as the face, they are one")

    print("FAILED: %d" % len(FAILS) if FAILS else "all passed")
    sys.exit(1 if FAILS else 0)


if __name__ == "__main__":
    main()
