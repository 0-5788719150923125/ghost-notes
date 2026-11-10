#!/usr/bin/env python3
"""Gate for the painter's hand (feedback 0020, 2026-11-09 - the user: "You would want a hand that generally tries to keep its whole brush
inside of the edge; however hands can make mistakes, and spill over the edge, dragging/blending color with it. If it does, we could clean
that up with more white (or other colors), or we might be able to wipe it away with a cotton swab (if the mistake was small, or the color
was faint). So the point is: we want naturally-looking behaviors here.").

Run it directly with the paint venv's python - no pytest, no GPU (the optimizer is never imported):

    ~/.local/share/godot/app_userdata/ghost/paint_venv/bin/python hosts/paint/test_hand.py

On a made surface - a white ground, a plum disc on it - held to:

  1. A CAREFUL HAND: the fat brush's blend over the disc, its slips held off, leaves everything past the disc's edge as it was (plan.py
     `_feather_area`). CONTROL: its pulls six tenths of a touch in from the edge, as they were, reach past it.
  2. A MARK THAT CHANGES NOTHING IS NEVER MADE (solve.py `try_lay`): a pull over the bare white is not laid. CONTROL: one over the disc is.
  3. A BLEND DRAGS (marks.soften's `drag`): a pull drawn from the disc out over the white leaves a hint of plum there. CONTROL: with no
     drag, the white past the blur's reach is untouched.
  4. A HAND SLIPS, THE SAME WAY EVERY TIME (marks.slipped): of many pulls, a few stray past their path by more than a third of the brush's
     half width and a few run on past their end, most stay within a steady hand's wander; the same seed draws the same path.
  5. A SPILL IS CLEANED (layers_paint.tidy): a small plum spill on the white is blotted with the cotton swab, a big one painted back over in
     white - both nearer the picture than they were. CONTROL: a spill that is the layer's own (inside where it changes things) is left.
  7. A CLEANUP PAINTS BACK WHAT WAS THERE, AND STAYS OUT OF THE LAYER (feedback 0005: white patches on a cream face, the eye's makeup
     lightened at its edge): on a ground laid in a cream mix where the picture says white, a big spill against the disc's edge is painted
     back nearer the cream than the white, and a small one beside it blotted - the disc itself untouched. CONTROL: the paint nearest the
     picture there, which the cleanup had used, is the white.
  9. A BASE IS EVEN BEFORE THE SPONGE IS PUT DOWN (2026-11-09: "the sponge was put down too early. There are still patchy areas"): next
     to nothing of the face under nine tenths covered. CONTROL: gone back over twice where under 0.8, as it was, more of it is.
  10. A PART PAINTED BY NUMBERS HAS ITS OWN BORDERS WORKED WET, NEVER ITS EDGE (feedback 0011, 2026-11-10: "large white bands around the
     outer part of the eye-diamond ... the outer white smearing into the inner part" - layers_paint `OWN_BORDERS`): a soft layer laid by
     numbers over a plum disc's whole inside, a dark middle and plum round it, leaves the plum just inside the disc's edge plum. CONTROL:
     its edge against the white worked as a border too, as it was, the white is carried into it.
  11. NO LAYER CHANGES THE FACE'S OWN EDGE (feedback 0012, 2026-11-10: "weird black smudges being painted along the chin" - layers_paint
     `RIM_OFF`): of two pictures of a face, the second's silhouette drawn two pixels aside into the black past it and a dark spot added,
     the step is the spot. CONTROL: the edge not kept, a ring round the whole face is the step's too.
  12. A HAND KEEPING OUT OF A PLACE TAKES NOTHING UP FROM IT (feedback 0011 - plan.py `TAKE_INSIDE`): a fat brush's fade round a small core
     in a plum disc, its band crossing the disc's edge, the hand kept out past the disc and taking up only the disc, as a layer's fade
     does: the plum by the edge stays plum. CONTROL: its pulls taking up the white past the edge, the white is carried in.
  6. A SOFT LAYER IS NOT ITS PICTURE'S REDRAW (layers_paint.layer_alpha): a soft step whose picture is redrawn a shade lighter all over,
     with a real shading in one place, has the shading for its own and next to nothing of the rest. CONTROL: the floor it had, all of it.
  7. A BASE IS ONE POT'S PAINT (feedback 0001, 2026-11-09: "The color we're painting doesn't seem to actually match the foundation it was
     sourced from" - plan.py `_base`): over a picture a grey-green between white and olive, the base and its every press are in one of
     the table's paints. CONTROL: of every paint and mix, the nearest is a mix.
  8. A BASE'S PATS ARE A HAND'S, NEVER A LATTICE (feedback 0001: "the gaps are always in the exact same, uniform layout ... like a grid
     of color, instead of organic" - plan.py `PAT_WANDER`): the thin places a white base leaves over a 150 mm face have no layout to
     them (their autocorrelation's strongest peak off its middle under 0.3), in no more presses than the lattice took. CONTROL: pressed
     on the sweep's lattice, its holes repeat (over 0.45).
"""

import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))

FAILS = []
# How much lighter (OKLab x100) the plum just inside a part painted by numbers may come out (check 10).
NUMBERED_LIGHTER = 2.0


def check(ok, what):
    print(("  ok    " if ok else "  FAIL  ") + what)
    if not ok:
        FAILS.append(what)


def surface(more=None):
    """A 60 mm square, a disc of face; the picture a white ground with a plum disc 14 mm across at its middle; `more` paints on the table
    beside the white and the plum. -> (painter, disc mask, white, plum)."""
    from run import FromSpec
    from canvas import PX
    from plan import PlanPainter
    from tools import TOOLS
    px = 4.0
    n = int(60 * px)
    yy, xx = np.mgrid[0:n, 0:n] / px
    face = (xx - 30) ** 2 + (yy - 30) ** 2 < 28 ** 2
    white, plum = np.array([0.96, 0.95, 0.93]), np.array([0.29, 0.17, 0.24])
    pic = np.zeros((n, n, 4))
    pic[..., :3] = white
    pic[..., 3] = face
    pic[((xx - 30) ** 2 + (yy - 30) ** 2 < 7 ** 2) & face, :3] = plum
    spec = {"paints": {"white paint": "#f6f3ec", "plum cream": "#4a2a3e", **(more or {})}, "bare": "#c89e80", "px": px, "size": [n, n]}
    ref = FromSpec(spec, pic)
    p = PlanPainter(ref, list(TOOLS), 1)
    p.layer_name = "test"
    h, w = ref.h, ref.w
    Y, X = (np.mgrid[0:h, 0:w] + 0.5) / PX
    disc = ((X - 30) ** 2 + (Y - 30) ** 2 < 7 ** 2) & ref.face
    # (...the ground and the disc laid straight onto the canvas, its paint pre-multiplied sRGB as the canvas keeps it: what is under the
    # hand, not what it is tested on)
    a = ref.face * 1.0
    p.cv.pre[...] = white[None, None, :] * a[..., None]
    p.cv.alp[...] = a
    p.cv.pre[disc] = plum
    return p, disc, white, plum


def base_surface(paints, color, mm):
    """A bare square `mm` across, a disc of face nearly as wide, its picture all `color` (sRGB), the table's `paints` - nothing laid yet.
    -> the painter."""
    from run import FromSpec
    from plan import PlanPainter
    from tools import TOOLS
    px = 4.0
    n = int(mm * px)
    yy, xx = np.mgrid[0:n, 0:n] / px
    pic = np.zeros((n, n, 4))
    pic[..., :3] = color
    pic[..., 3] = (xx - mm / 2) ** 2 + (yy - mm / 2) ** 2 < (mm / 2 - 2) ** 2
    ref = FromSpec({"paints": paints, "bare": "#c89e80", "px": px, "size": [n, n]}, pic)
    p = PlanPainter(ref, list(TOOLS), 1)
    p.layer_name = "base"
    return p


def main():
    import marks as mk
    from canvas import PX
    from scipy import ndimage
    from color import delta, dec, oklab
    from layers_paint import tidy

    # 1. a careful hand
    p, disc, white, plum = surface()
    saved = (mk.SLIP_EVERY, mk.OVER_EVERY)
    mk.SLIP_EVERY, mk.OVER_EVERY = 0.0, 0.0
    before = p.cv.copy()
    n0 = len(p.laid)
    p._feather_area(disc, 1.5)
    mk.SLIP_EVERY, mk.OVER_EVERY = saved
    past = ~ndimage.binary_dilation(disc, iterations=int(1.0 * PX)) & p.ref.face
    off = np.abs(p.cv.pre - before.pre).max(-1)[past]
    tool = p.hand.tool
    check(len(p.laid) > n0 and float(off.max()) < 0.01,
          "the fat brush's blend stays inside the disc: %d pulls with the %s, most off past it %.4f" % (len(p.laid) - n0, tool, off.max()))
    from tools import TOOLS
    half = TOOLS[tool]["mm"] * 0.3
    dt = ndimage.distance_transform_edt(disc)
    S = dt >= half * 0.6 * PX
    ring = S & ~ndimage.binary_erosion(S)
    ys, xs = np.nonzero(ring)
    ang = np.arctan2(ys - ys.mean(), xs - xs.mean())
    o = np.argsort(ang)
    path = np.stack([(xs[o] + 0.5) / PX, (ys[o] + 0.5) / PX], 1)[::4]
    m = mk.soften(before, path, half, 1.5, 0.9, "wet_blend", tool)
    reach_past = np.abs(m.pre - before.pre[m.sl]).max(-1)[past[m.sl]]
    check(float(reach_past.max()) > 0.03, "CONTROL: six tenths of a touch in from the edge, it reaches past it (most off %.3f)" % reach_past.max())

    # 2. a mark that changes nothing is never made
    p, disc, white, plum = surface()
    blank = mk.soften(p.cv, np.array([[12.0, 24.0], [12.0, 36.0]]), 4.8, 1.5, 0.9, "wet_blend", "blender")
    over = mk.soften(p.cv, np.array([[24.0, 30.0], [36.0, 30.0]]), 4.8, 1.5, 0.9, "wet_blend", "blender")
    check(not p.try_lay(blank, p.ref.lab, -1e9), "a pull over the bare white is never laid")
    check(p.try_lay(over, p.ref.lab, -1e9), "CONTROL: a pull over the disc is")

    # 3. a blend drags
    p, disc, white, plum = surface()
    pull = np.stack([np.linspace(30.0, 46.0, 33), np.full(33, 30.0)], 1)
    far = np.zeros(disc.shape, bool)
    far[int(28 * PX):int(32 * PX), int(41 * PX):int(45 * PX)] = True
    for drag, want in ((0.3, True), (0.0, False)):
        m = mk.soften(p.cv, pull, 3.0, 0.8, 0.9, "wet_blend", "flat", drag=drag)
        d = delta(oklab(p.cv.shown_of(m.pre, m.alp, p.cv.bare_lin)), p.cv.lab(m.sl))[far[m.sl]]
        if want:
            check(float(d.max()) > 2.0, "a pull from the disc out over the white leaves a hint of plum 11-15 mm out (%.1f)" % d.max())
        else:
            check(float(d.max()) < 0.5, "CONTROL: with no drag, the white there is untouched (%.2f)" % d.max())

    # 4. a hand slips, the same way every time
    line = np.stack([np.linspace(0, 40, 81), np.full(81, 10.0)], 1)
    strays = overs = 0
    calm = []
    for seed in range(400):
        q = mk.slipped(line, 4.8, seed)
        side = np.abs(q[:81, 1] - 10.0).max()
        strays += side > 4.8 / 3
        overs += len(q) > 81
        calm.append(side)
    same = np.array_equal(mk.slipped(line, 4.8, 7), mk.slipped(line, 4.8, 7))
    check(10 <= strays <= 90 and 10 <= overs <= 80 and float(np.median(calm)) < 0.5 and same,
          "of 400 pulls %d stray past a third of the half width, %d run on past their end, the median wanders %.2f mm; the same seed "
          "draws the same path: %s" % (strays, overs, np.median(calm), same))

    # 5. a spill is cleaned
    p, disc, white, plum = surface()
    before = p.cv.copy()
    h, w = disc.shape
    Y, X = (np.mgrid[0:h, 0:w] + 0.5) / PX
    small = ((X - 46) ** 2 + (Y - 30) ** 2 < 1.6 ** 2) & p.ref.face
    big = ((X - 30) ** 2 + (Y - 48) ** 2 < 3.5 ** 2) & p.ref.face
    p.cv.pre[small | big] = plum
    alpha = disc * 1.0
    target = p.ref.lab
    err0_small = float(delta(p.cv.lab(), target)[small].mean())
    err0_big = float(delta(p.cv.lab(), target)[big].mean())
    n0 = len(p.laid)
    said = tidy(p, before, alpha, target, p.ref.face)
    kinds = [lm[0].kind for lm in p.laid[n0:]]
    tools = {lm[0].tool for lm in p.laid[n0:] if lm[0].kind == "blot"}
    err1_small = float(delta(p.cv.lab(), target)[small].mean())
    err1_big = float(delta(p.cv.lab(), target)[big].mean())
    check(kinds.count("blot") > 0 and tools == {"bud"} and err1_small < err0_small * 0.4,
          "the small spill is blotted with the cotton swab (%d blots): %.1f -> %.1f off the picture" % (kinds.count("blot"), err0_small, err1_small))
    check(any(k != "blot" for k in kinds) and err1_big < err0_big * 0.5,
          "the big spill is painted back over (%d marks): %.1f -> %.1f off the picture (%s)" % (sum(k != "blot" for k in kinds), err0_big, err1_big, said))
    p2, disc2, _, _ = surface()
    before2 = p2.cv.copy()
    p2.cv.pre[big] = plum
    n0 = len(p2.laid)
    tidy(p2, before2, np.maximum(disc2 * 1.0, big * 1.0), p2.ref.lab, p2.ref.face)
    check(len(p2.laid) == n0, "CONTROL: a patch inside where the layer changes things is its own, and left (%d marks)" % (len(p2.laid) - n0))

    # 7. a cleanup paints back what was there, and stays out of the layer
    p, disc, white, plum = surface({"amber cream": "#c89a2f"})
    cream_j = [k for k, nm in enumerate(p.opt_names) if "amber" in nm and "white" in nm]
    cream_j = min(cream_j, key=lambda k: float(np.abs(np.asarray(p.opt_cols[k]) - white).sum())) if cream_j else None
    if cream_j is None:
        check(False, "no cream mix of the amber and the white to lay a ground in: %s" % p.opt_names)
    else:
        cream = np.asarray(p.opt_cols[cream_j], float)
        face = p.ref.face
        p.cv.pre[face] = cream
        p.cv.pre[disc] = plum
        before = p.cv.copy()
        h, w = disc.shape
        Y, X = (np.mgrid[0:h, 0:w] + 0.5) / PX
        r = np.hypot(X - 30, Y - 30)
        big = (r >= 7) & (r < 11) & (np.abs(Y - 30) < 4) & (X > 30) & face          # against the disc's right edge
        small = (r >= 7) & (r < 8.6) & (np.abs(X - 30) < 1.2) & (Y < 30) & face     # against its top
        p.cv.pre[big | small] = plum
        held = p.cv.pre[disc].copy()
        tidy(p, before, disc * 1.0, p.ref.lab, face)
        out = big & (r > 9.0)          # past the band kept clear round the layer, where it is painted back
        shown = p.cv.lab()
        to_cream = float(delta(shown[out], oklab(np.broadcast_to(dec(cream), shown[out].shape).copy())).mean())
        to_white = float(delta(shown[out], oklab(np.broadcast_to(dec(white), shown[out].shape).copy())).mean())
        check(float(np.abs(p.cv.pre[disc] - held).max()) < 0.01, "the disc's own paint is untouched by its cleanup (most off %.4f)"
              % np.abs(p.cv.pre[disc] - held).max())
        check(to_cream < to_white, "the big spill is painted back nearer the cream ground (%.1f) than the white (%.1f)" % (to_cream, to_white))
        med = np.median(p.ref.lab[big], axis=0)
        old = p.opt_names[int(np.argmin(np.linalg.norm((oklab(dec(p.opt_cols)) - med) * p.HUE, axis=1)))]
        check(old == "white paint", "CONTROL: the paint nearest the picture there, as the cleanup had used, is %s" % old)

    # 6. a soft layer is not its picture's redraw
    import layers_paint as LP
    p, disc, white, plum = surface()
    face = p.ref.face
    h, w = face.shape
    rng = np.random.default_rng(3)
    # (...a redraw's drift as 732687's shine had it: its median 1.7, its 90th percentile 3.4, wandering over a few millimeters)
    field = ndimage.gaussian_filter(rng.normal(0, 1.0, (h, w)), PX * 2.0)
    d = np.clip(1.7 + 1.3 * field / field[face].std(), 0, None) * face
    Y, X = (np.mgrid[0:h, 0:w] + 0.5) / PX
    shade = ((X - 20) ** 2 + (Y - 24) ** 2 < 6 ** 2) & face
    d = d + np.where(shade, 6.0, 0.0)
    a = LP.layer_alpha(d, face, soft=True)
    check(float((a[shade] > 0.15).mean()) > 0.9 and float((a[face & ~shade] > 0.15).mean()) < 0.05,
          "a soft step's shading is its own (%.0f%%), its picture's lighter redraw round it is not (%.1f%%)"
          % (100 * (a[shade] > 0.15).mean(), 100 * (a[face & ~shade] > 0.15).mean()))
    saved = LP.SOFT_DRIFT
    LP.SOFT_DRIFT = 0.0
    a0 = LP.layer_alpha(d, face, soft=True)
    LP.SOFT_DRIFT = saved
    check(float((a0[face & ~shade] > 0.15).mean()) > 0.15, "CONTROL: with the floor it had, the redraw is %.0f%% its own" % (100 * (a0[face & ~shade] > 0.15).mean()))

    # 7. a base is one pot's paint
    import plan as plan_mod
    from color import hex_rgb, mix
    paints = {"white paint": "#f6f3ec", "olive cream": "#3f4a2c"}
    grey = mix(hex_rgb(paints["olive cream"]), hex_rgb(paints["white paint"]), 0.75)
    p = base_surface(paints, grey, 60)
    _, any_name = p.paint_of({"paint": "auto"}, p.ref.face)
    p._base({"name": "base", "how": "base", "paint": "auto"})
    laid = {lm[0].paint for lm in p.laid}
    check(p.ground in paints and laid == {p.ground},
          "a base over a grey-green between white and olive is laid in one pot's paint: %s, its presses in %s" % (p.ground, sorted(laid)))
    check("+" in any_name, "CONTROL: of every paint and mix, the nearest is a mix (%s)" % any_name)

    # 8. a base's pats are a hand's, never a lattice
    def lattice(p):
        """How regular the base's thin places are: the strongest peak of their autocorrelation 6-30 mm off its middle, over the middle
        90 mm of the face (1 at its center)."""
        n = int(30 * PX), int(120 * PX)
        a = p.cv.alp[n[0]:n[1], n[0]:n[1]]
        thin = (a < np.percentile(a, 10)).astype(float)
        thin -= thin.mean()
        F = np.fft.fft2(thin)
        ac = np.fft.fftshift(np.real(np.fft.ifft2(F * np.conj(F))))
        ac /= max(ac.max(), 1e-9)
        cy, cx = np.array(ac.shape) // 2
        yy, xx = np.mgrid[0:ac.shape[0], 0:ac.shape[1]]
        rr = np.hypot(yy - cy, xx - cx) / PX
        return float(ac[(rr > 6) & (rr < 30)].max())

    white = {"white paint": "#f6f3ec"}
    p = base_surface(white, hex_rgb(white["white paint"]), 150)
    p._base({"name": "base", "how": "base", "paint": "white paint"})
    scattered, presses = lattice(p), len(p.laid)
    saved = plan_mod.PAT_WANDER
    plan_mod.PAT_WANDER = 0.0
    p0 = base_surface(white, hex_rgb(white["white paint"]), 150)
    p0._base({"name": "base", "how": "base", "paint": "white paint"})
    plan_mod.PAT_WANDER = saved
    on_lattice, presses0 = lattice(p0), len(p0.laid)
    check(scattered < 0.3 and presses <= presses0 * 1.1,
          "a base's thin places lie where its presses fell, no layout to them: %.2f regular, in %d presses" % (scattered, presses))
    check(on_lattice > 0.45, "CONTROL: pressed on the sweep's lattice, its holes repeat (%.2f regular, %d presses)" % (on_lattice, presses0))

    # 9. a base is even before the sponge is put down
    from scipy import ndimage as ndi
    def thin_share(p):
        soft = ndi.gaussian_filter(p.cv.alp, PX * 0.75)
        return float((soft[p.ref.face] < 0.9).mean())
    even = thin_share(p)
    saved = (plan_mod.BASE_EVEN, plan_mod.BASE_PASSES)
    plan_mod.BASE_EVEN, plan_mod.BASE_PASSES = 0.8, 2
    p1 = base_surface(white, hex_rgb(white["white paint"]), 150)
    p1._base({"name": "base", "how": "base", "paint": "white paint"})
    plan_mod.BASE_EVEN, plan_mod.BASE_PASSES = saved
    patchy = thin_share(p1)
    check(even < 0.005, "a base is even before the sponge is put down: %.2f%% of the face under nine tenths, in %d presses" % (100 * even, presses))
    check(patchy > even * 2 and patchy > 0.005,
          "CONTROL: gone back over twice where under 0.8, as it was, %.2f%% is (%d presses)" % (100 * patchy, len(p1.laid)))

    # 10. a part painted by numbers has its own borders worked wet, never its edge
    import layers_paint as lp

    def numbered(own):
        q, disc, white, plum = surface({"black paint": "#121214"})
        h, w = disc.shape
        Y, X = (np.mgrid[0:h, 0:w] + 0.5) / PX
        r = np.sqrt((X - 30) ** 2 + (Y - 30) ** 2)
        pic = np.broadcast_to(white, (h, w, 3)).copy()
        pic[disc] = plum
        pic[disc & (r < 3.5)] = [0.07, 0.07, 0.08]
        saved = lp.OWN_BORDERS
        lp.OWN_BORDERS = own
        try:
            words = lp.by_numbers(q, disc, disc * 1.0, oklab(dec(pic)), {"colors": 2}, True)
        finally:
            lp.OWN_BORDERS = saved
        rim = disc & (r > 5.8) & (r < 6.8)
        col = q.cv.pre[rim] / np.maximum(q.cv.alp[rim][:, None], 1e-6)
        return float(np.mean(oklab(dec(col))[:, 0]) - oklab(dec(plum[None]))[0, 0]), words
    kept, words = numbered(True)
    worked, words_was = numbered(False)
    check(kept < NUMBERED_LIGHTER, "a part painted by numbers keeps its edge: the plum just inside a disc's edge %.1f lighter (OKLab x100) after %s"
          % (kept, ", ".join(words)))
    check(worked > NUMBERED_LIGHTER * 2, "CONTROL: its edge against the white worked as a border, as it was, it is %.1f lighter (%s)"
          % (worked, ", ".join(words_was)))

    # 11. no layer changes the face's own edge
    p, disc, white, plum = surface()
    face = p.ref.face
    h, w = face.shape
    Y, X = (np.mgrid[0:h, 0:w] + 0.5) / PX
    r = np.sqrt((X - 30) ** 2 + (Y - 30) ** 2)
    # (...two pictures of the same white face on black, the second's silhouette drawn two pixels inside the first's and blended into the
    # black past it, as the image model redraws it - and a real step in it, a dark spot on the cheek)
    before_pic = np.where((r < 28.0)[..., None], white, 0.0)
    edge = np.clip((27.5 - r) * PX * 0.5 + 0.5, 0.0, 1.0)[..., None]
    after_pic = white * edge
    spot = (X - 20) ** 2 + (Y - 30) ** 2 < 3 ** 2
    after_pic[spot] = plum
    d = LP.changed(oklab(dec(before_pic)), oklab(dec(after_pic)), face)
    rim = face & (r > 26.0)
    a = LP.layer_alpha(d, face, soft=True)
    check(float((a[spot] > 0.3).mean()) > 0.9 and float((a[rim] > 0.15).sum()) / PX ** 2 < 0.5,
          "no layer changes the face's own edge: its silhouette redrawn aside is %.1f mm2 of the step, its spot %.0f%% of it"
          % (float((a[rim] > 0.15).sum()) / PX ** 2, 100 * float((a[spot] > 0.3).mean())))
    saved = LP.RIM_OFF
    LP.RIM_OFF = 0.0
    a0 = LP.layer_alpha(d, face, soft=True)
    LP.RIM_OFF = saved
    check(float((a0[rim] > 0.15).sum()) / PX ** 2 > 5.0, "CONTROL: with the edge not kept, the silhouette is %.1f mm2 of it"
          % (float((a0[rim] > 0.15).sum()) / PX ** 2))

    # 12. a hand keeping out of a place takes nothing up from it
    import plan as plan_mod2

    def faded(take_inside):
        q, disc, white, plum = surface()
        h, w = disc.shape
        Y, X = (np.mgrid[0:h, 0:w] + 0.5) / PX
        r = np.sqrt((X - 30) ** 2 + (Y - 30) ** 2)
        saved = plan_mod2.TAKE_INSIDE
        plan_mod2.TAKE_INSIDE = take_inside
        q.keep_out = q.ref.face & ~ndimage.binary_dilation(disc, iterations=int(LP.FADE_PAST * PX))
        q.untaken = q.ref.face & ~disc
        try:
            q._smudge({"name": "test", "how": "smudge", "mask": disc & (r < 4.0), "band": 5.0, "size": 5.0, "strength": 0.55, "inside": 0.25})
        finally:
            q.keep_out = None
            q.untaken = None
            plan_mod2.TAKE_INSIDE = saved
        rim = disc & (r > 5.5) & (r < 6.6)
        col = q.cv.pre[rim] / np.maximum(q.cv.alp[rim][:, None], 1e-6)
        return float(np.mean(oklab(dec(col))[:, 0]) - oklab(dec(plum[None]))[0, 0])
    inside_only = faded(True)
    took_white = faded(False)
    check(inside_only < NUMBERED_LIGHTER, "a fade kept inside a disc takes nothing from past it: the plum by its edge %.1f lighter" % inside_only)
    check(took_white > NUMBERED_LIGHTER * 2, "CONTROL: taking up the white past the edge, as it did, it is %.1f lighter" % took_white)

    print("FAILED: %d" % len(FAILS) if FAILS else "all passed")
    sys.exit(1 if FAILS else 0)


if __name__ == "__main__":
    main()
