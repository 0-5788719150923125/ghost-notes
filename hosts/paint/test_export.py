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
    """The elements' maps laid in `order` as the shader lays them: color over what is under it by coverage (pre-multiplied)."""
    from canvas import PX
    pre = np.zeros(shape + (3,))
    alp = np.zeros(shape)
    for i in order:
        e = els[i]
        m = e["maps"]
        w, h = m["w"], m["h"]
        x0, y0 = int(round(e["rect"][0] * PX)), int(round(e["rect"][1] * PX))
        a = np.fromfile(root / m["cover"], np.uint8).reshape(h, w) / 255.0
        c = np.fromfile(root / m["tint"], np.uint8).reshape(h, w, 3) / 255.0
        box = (slice(y0, y0 + h), slice(x0, x0 + w))
        pre[box] = c * a[..., None] + pre[box] * (1 - a[..., None])
        alp[box] = a + alp[box] * (1 - a)
    return pre, alp


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
    print("FAILED: %d" % len(FAILS) if FAILS else "all passed")
    sys.exit(1 if FAILS else 0)


if __name__ == "__main__":
    main()
