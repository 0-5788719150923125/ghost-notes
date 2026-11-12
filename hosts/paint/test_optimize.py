#!/usr/bin/env python3
"""Gate for the optimizer's hand ("An intelligent model should know: it can draw a single line, pull it all the way through, as a base color. And
then it can correct itself, painting other colors on top of that").

Run it directly with the paint venv's python - no pytest (the optimizer on the GPU where there is one, else the CPU, a minute or two):

    ~/.local/share/godot/app_userdata/ghost/paint_venv/bin/python hosts/paint/test_optimize.py

On a made surface - a white face, a tear down it 44 mm long and 3 mm wide, black for most of its length and olive at its end - held to:

  1. A LONG THIN PART'S BASE FIRST (optimize.BASE_LONG): the tear's first pulls are its base, in black, along at least
     BASE_COVERS_LEAST of its length in at most two pulls. CONTROL: with no base, it takes more pulls.
  2. EVERY RUN WORTH ITS TRIP (optimize.GROUP_LEAST): every run of one brush in one paint is worth at least GROUP_LEAST seconds of the
     hand's time, or is its paint's only run with no shade near it (a color of the design, kept). CONTROL: with none merged, more runs,
     some worth less.
  3. ONE RUN A BRUSH AND PAINT (optimize.LayerOpt.key_of): no brush is taken up in a paint twice in the layer.

And on a white face with a brow drawn on it - an arc 46 mm long and 0.6 mm wide, black for half its length and red for the rest
 - painted as a layer:

  4. A LINE AS A HAND DRAWS ONE (plan.LINE_JOIN, layers_paint.LINES_WHOLE): its longest pull lies along BROW_COVERS_LEAST of it.
     CONTROL: its lines found inside each paint's own points, as they were, it is cut into pieces where its color changes.
  5. A LINE THAT SHOWS (plan.LINE_LEAST): every pull at least LINE_LEAST wide. CONTROL: with a least wider than it, it is laid wider.
"""

import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))

FAILS = []
BASE_COVERS_LEAST = 0.7


def check(ok, what):
    print(("  ok    " if ok else "  FAIL  ") + what)
    if not ok:
        FAILS.append(what)


def tear_surface():
    """A 60 x 70 mm square, a disc of face; the picture the face in white with a tear down it - black from 8 mm to 40 mm, olive to 52.
    -> (painter, the tear's mask, its picture)."""
    from run import FromSpec
    from plan import PlanPainter
    from tools import TOOLS
    px = 4.0
    w, h = int(60 * px), int(70 * px)
    yy, xx = np.mgrid[0:h, 0:w] / px
    face = (xx - 30) ** 2 / 28 ** 2 + (yy - 35) ** 2 / 33 ** 2 < 1.0
    white, black, olive = np.array([0.96, 0.95, 0.93]), np.array([0.07, 0.07, 0.08]), np.array([0.43, 0.42, 0.18])
    pic = np.zeros((h, w, 4))
    pic[..., :3] = white
    pic[..., 3] = face
    wobble = 30 + 1.5 * np.sin(yy / 6.0)
    tear = (np.abs(xx - wobble) < 1.5) & (yy > 8) & (yy < 52) & face
    pic[tear & (yy < 40), :3] = black
    pic[tear & (yy >= 40), :3] = olive
    spec = {"paints": {"white paint": "#f6f3ec", "black paint": "#121214", "olive cream": "#6e6a2d"}, "bare": "#c89e80", "px": px,
            "size": [w, h]}
    ref = FromSpec(spec, pic)
    p = PlanPainter(ref, list(TOOLS), 1)
    p.layer_name = "tears"
    a = ref.face * 1.0
    p.cv.pre[...] = white[None, None, :] * a[..., None]
    p.cv.alp[...] = a
    return p, tear[:ref.h, :ref.w], pic[..., :3]


def painted(base_long=None, group_least=None):
    """The tear laid by optimize_layer, its constants as asked. -> (painter, marks laid in order, the tear's mask)."""
    import optimize as opt
    saved = (opt.BASE_LONG, opt.GROUP_LEAST)
    if base_long is not None:
        opt.BASE_LONG = base_long
    if group_least is not None:
        opt.GROUP_LEAST = group_least
    try:
        p, tear, pic = tear_surface()
        n0 = len(p.laid)
        opt.optimize_layer(p, [(tear, ["black paint", "olive cream"], False)], pic, log=lambda s: None)
    finally:
        opt.BASE_LONG, opt.GROUP_LEAST = saved
    return p, [m[0] for m in p.laid[n0:]], tear


def runs_of(marks):
    """The marks' runs of one brush in one paint, in order: `[(tool, paint, seconds)]`."""
    from optimize import _pull_time
    out = []
    for m in marks:
        k = (m.tool, m.paint)
        t = _pull_time(np.asarray(m.rec.get("pts", [[0.0, 0.0], [0.0, 0.0]]), float))
        if out and out[-1][:2] == k:
            out[-1] = (k[0], k[1], out[-1][2] + t)
        else:
            out.append((k[0], k[1], t))
    return out


def main():
    import optimize as opt

    p, marks, tear = painted()
    ys = np.nonzero(tear)[0] / 4.0
    tear_len = float(ys.max() - ys.min())
    first = []
    for m in marks:
        if m.paint != "black paint" or len(first) >= 2:
            break
        first.append(m)
    span = 0.0
    if first:
        pts = np.vstack([np.asarray(m.rec["pts"], float) for m in first])
        span = float(pts[:, 1].max() - pts[:, 1].min())
    check(len(first) >= 1 and span >= BASE_COVERS_LEAST * (40 - 8),
          "the tear's first pulls are its base: %d in black along %.1f mm of its 32 mm of black (%.0f mm in all)" % (len(first), span, tear_len))
    _, marks0, _ = painted(base_long=1e9)
    check(len(marks0) > len(marks), "CONTROL: with no base it takes %d pulls, against %d" % (len(marks0), len(marks)))

    runs = runs_of(marks)
    from color import dec, oklab

    def lone(r):
        """A run worth less than its trip, its paint's only one and no shade near it among the runs worth theirs."""
        others = [q for q in runs if q is not r]
        mine = oklab(dec(np.asarray(p._color(r[1]), float)))
        return all(q[1] != r[1] for q in others) and all(float(np.linalg.norm(oklab(dec(np.asarray(p._color(q[1]), float))) - mine)) > opt.MERGE_COLOR_MOST
                                                         for q in others if q[2] >= opt.GROUP_LEAST)
    check(all(r[2] >= opt.GROUP_LEAST or lone(r) for r in runs),
          "every run is worth its trip, or a color of its own: %s" % ", ".join("%s in %s %.1f s" % (r[0], r[1].split(" ")[0], r[2]) for r in runs))
    keys = [r[:2] for r in runs]
    check(len(keys) == len(set(keys)), "no brush is taken up in a paint twice: %s" % [k[0] + "/" + k[1].split(" ")[0] for k in keys])
    _, marks1, _ = painted(base_long=1e9, group_least=0.0)
    runs1 = runs_of(marks1)
    check(any(r[2] < opt.GROUP_LEAST for r in runs1) and len(runs1) > len(runs),
          "CONTROL: none merged, %d runs, the least worth %.1f s" % (len(runs1), min(r[2] for r in runs1) if runs1 else 0.0))

    # 4-5. a brow
    import layers_paint as lp
    import plan as plan_mod

    def brow(whole=True, least=None):
        from run import FromSpec
        px = 4.0
        n = int(60 * px)
        yy, xx = np.mgrid[0:n, 0:n] / px
        face = (xx - 30) ** 2 + (yy - 30) ** 2 < 28 ** 2
        white = np.array([0.96, 0.95, 0.93])
        ground = np.zeros((n, n, 4))
        ground[..., :3] = white
        ground[..., 3] = face
        line = ground.copy()
        mid = 22.0 + 0.012 * (xx - 30) ** 2
        on = (np.abs(yy - mid) < 0.3) & (xx > 7) & (xx < 53) & face
        line[on & (xx < 30), :3] = [0.07, 0.07, 0.08]
        line[on & (xx >= 30), :3] = [0.45, 0.05, 0.08]
        spec = {"paints": {"white paint": "#f6f3ec", "black paint": "#121214", "red paint": "#a01828"}, "bare": "#c89e80", "px": px,
                "size": [n, n]}
        ref = FromSpec(spec, line)
        saved = (lp.LINES_WHOLE, plan_mod.LINE_LEAST)
        lp.LINES_WHOLE = whole
        if least is not None:
            plan_mod.LINE_LEAST = least
        try:
            p, starts, _ = lp.paint_layers(ref, [{"name": "ground"}, {"name": "brow"}], [ground[..., :3], line[..., :3]], log=lambda s: None)
        finally:
            lp.LINES_WHOLE, plan_mod.LINE_LEAST = saved
        marks = [m[0] for m in p.laid[starts[1]:] if "pts" in m[0].rec]
        xs = np.linspace(8, 52, 89)
        ys = 22.0 + 0.012 * (xs - 30) ** 2
        spine = np.stack([xs, ys], 1)

        def covers(ms):
            hit = np.zeros(len(spine), bool)
            for m in ms:
                pts = np.asarray(m.rec["pts"], float)
                if len(pts) < 2:
                    continue
                dense = np.vstack([np.linspace(pts[k], pts[k + 1], 20) for k in range(len(pts) - 1)])
                hit |= np.min(np.linalg.norm(spine[:, None] - dense[None], axis=-1), axis=1) < 1.0
            return float(hit.mean())
        lens = [float(np.linalg.norm(np.diff(np.asarray(m.rec["pts"], float), axis=0), axis=1).sum()) for m in marks]
        top = [marks[int(np.argmax(lens))]] if marks else []
        halves = [float(np.min(np.asarray(m.rec.get("half_w", [9.0]), float))) for m in marks]
        return covers(top), len(marks), min(halves) if halves else 0.0
    got, n_marks, thinnest = brow()
    BROW_COVERS_LEAST = 0.85
    check(got >= BROW_COVERS_LEAST, "a brow's longest pull lies along %.0f%% of it (%d pulls in all)" % (100 * got, n_marks))
    cut, n_cut, _ = brow(whole=False)
    check(cut < BROW_COVERS_LEAST, "CONTROL: its lines found inside each paint's own points, its longest pull lies along %.0f%% (%d pulls)" % (100 * cut, n_cut))
    check(thinnest >= plan_mod.LINE_LEAST * 0.5 - 1e-6, "every pull of it at least %.1f mm wide (the thinnest %.2f)" % (plan_mod.LINE_LEAST, 2 * thinnest))
    _, _, thin3 = brow(least=3.0)
    check(thin3 > thinnest + 0.1, "CONTROL: with a least of 3 mm (a liner's 2 at most), the thinnest is %.2f mm wide, against %.2f" % (2 * thin3, 2 * thinnest))

    print("FAILED: %d" % len(FAILS) if FAILS else "all passed")
    sys.exit(1 if FAILS else 0)


if __name__ == "__main__":
    main()
