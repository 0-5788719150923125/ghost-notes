#!/usr/bin/env python3
"""THE STEPS' LAYERS, PAINTED (layers_gen.py made the steps): each layer what its step changed - where, how much, in what colors - cut
into parts by color, each part painted with the technique its shape asks for, or the one its step names.

WHAT CHANGED, judged as an eye judges it: each point against the step before at that point and a pixel round it (the image painter
redraws the whole picture, and a pixel's drift is no paint); a layer's alpha soft where the change is soft - a haze, a shading - and the
image painter's drift over the whole face, a step's typical change, never counted as paint.

A PART'S TECHNIQUE BY ITS SHAPE (unless its step says): thin - lines, traced on the step's own picture; scattered - stippled; broad -
filled, or run together wet from the step's own colors where they vary (gradient); soft - shaded, as much at each point as the step's
alpha says.

    layers_paint.py <episode folder> --layers <layers_gen out dir> --out <dir> [--video]
"""
import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

import lines as lines_mod
import measure
from canvas import PX
from color import dec, delta, oklab
from plan import PlanPainter
from refs import Reference, _filled
from tools import TOOLS
import marks as mk


def load_step(path, ref):
    """A step's picture as the reference is held: filled past its edge, at the canvas's resolution (sRGB floats)."""
    img = Image.fromarray(_filled(np.asarray(Image.open(path).convert("RGBA"))))
    big = np.asarray(img.resize((ref.w, ref.h), Image.BICUBIC)).astype(float) / 255.0
    return np.clip(big[..., :3], 0, 1)


def changed(prev_lab, cur_lab, face, shift=1):
    """How much each point changed, OKLab x100: the least difference between it and the step before at it or within `shift` pixels."""
    best = np.full(face.shape, np.inf)
    for dy in range(-shift, shift + 1):
        for dx in range(-shift, shift + 1):
            moved = np.roll(np.roll(prev_lab, dy, 0), dx, 1)
            best = np.minimum(best, delta(cur_lab, moved))
    return ndimage.gaussian_filter(best, PX * 0.2) * face


def layer_alpha(d, face, floor=3.0, span=10.0, soft=False):
    """A layer's alpha from its change `d`: the face's typical change (the redraw's drift) and `floor` under it none, full by `span` more.
    A SOFT step (`soft` - shading, a haze, a step whose change is broad and gentle) is told from the redraw by its jitter alone - the
    change's fine-scale wobble, never its size: measured against the typical change, the socket shading round a closed eye (four units
    darker, the typical change on a step that shades much of the face) had been thrown away as drift."""
    if soft:
        jitter = float(np.median(np.abs(d - ndimage.gaussian_filter(d, PX * 2.0))[face]))
        lo = max(1.5, 3.0 * jitter)
        return np.clip((d - lo) / (span * 0.6), 0.0, 1.0)
    drift = float(np.median(d[face])) + 2.0 * float(np.median(np.abs(d[face] - np.median(d[face]))))
    lo = max(floor, drift)
    return np.clip((d - lo) / span, 0.0, 1.0)


def parts(alpha, cur_lab, most=3, hue=np.array([1.0, 3.0, 3.0]), thresh=0.5):
    """The layer's painted points cut by color into at most `most` parts (a part each color far enough from the others): masks."""
    on = alpha > thresh
    if on.sum() < 20:
        return []
    X = cur_lab[on] * hue
    rng = np.random.default_rng(0)
    C = X[rng.choice(len(X), 1)]
    for _ in range(most - 1):
        dmin = np.min(((X[:, None] - C[None]) ** 2).sum(-1), axis=1)
        if dmin.max() < (12.0 ** 2):
            break
        C = np.vstack([C, X[np.argmax(dmin)]])
    for _ in range(10):
        lb = np.argmin(((X[:, None] - C[None]) ** 2).sum(-1), axis=1)
        C = np.array([X[lb == k].mean(0) if (lb == k).any() else C[k] for k in range(len(C))])
    out = []
    for k in range(len(C)):
        m = np.zeros(alpha.shape, bool)
        m[on] = lb == k
        if m.sum() >= 12:
            out.append(m)
    return out


def clean(m, least=0.6):
    """Part `m` without the specks the redraw left (pieces under `least` mm^2)."""
    comps, n = ndimage.label(m)
    if n == 0:
        return m
    sizes = ndimage.sum(np.ones(m.shape), comps, range(1, n + 1))
    keep = np.zeros(n + 1, bool)
    keep[1:] = sizes >= least * PX * PX
    return keep[comps]


def shape_of(m):
    """A part's shape: (its thickness - area-weighted, mm; how many pieces; how long its longest piece is for its width; how round its
    pieces are, the area against the circle round their widest inside)."""
    comps, n = ndimage.label(m)
    if n == 0:
        return 0.0, 0, 0.0, 0.0
    th, ar, rounds, elong = [], [], [], 0.0
    for i, bx in enumerate(ndimage.find_objects(comps)):
        part = comps[bx] == i + 1
        dt = ndimage.distance_transform_edt(np.pad(part, 1))
        r = dt.max()
        a = part.sum()
        th.append(r / PX)
        ar.append(a)
        rounds.append(a / max(np.pi * r * r, 1.0))
        elong = max(elong, a / max(4.0 * r * r, 1.0))
    ar = np.array(ar, float)
    return float((np.array(th) * ar).sum() / ar.sum()), n, elong, float((np.array(rounds) * ar).sum() / ar.sum())


def technique(m, alpha, face, lab=None):
    """What a part's shape asks for: lines, strokes, dots, texture, gradient or fill."""
    thick, n, elong, roundness = shape_of(m)
    area = m.sum() / (PX * PX)
    if thick < 0.6:
        return "lines"
    if n >= 4 and area / n < 12.0 and roundness > 0.6:
        return "dots"
    if n > 25 and area / n < 4.0:
        return "texture"
    if elong > 3.0 and thick < 2.5:
        return "strokes"
    if lab is not None and float(np.percentile(lab[m][:, 0], 85) - np.percentile(lab[m][:, 0], 15)) > 14.0:
        return "gradient"
    return "fill"


def laid_paints(p, m, prev, cur, alpha, most=3, apart=12.0, least=0.1):
    """THE PAINTS A THIN PART WAS LAID IN, read from what each point became over what it was (`prev` -> `cur`, sRGB floats): the paint
    whose coverage over the old color comes nearest the new one, point by point in linear light, weighed by how far the point moved -
    up to `most`, each `apart` (OKLab x100, hue weighed up) from the others and `least` of the weight. -> ([names], label map: the index
    of each point's paint, -1 none). A hairline's own color is the face's half over: read as a color, 327484's gold threads had been
    traced in grey, and a crackle redrawn a pixel aside had outweighed them. Where a darker paint laid thin and a paler one laid whole
    come to the same, the darker wins - as a liner lays a line, whole down its middle (preferring the whole, even at a twenty-fifth of
    the change, had turned the crackle a pale blue-grey and the gold a grey)."""
    sel = m & (alpha > 0.3)
    label = np.full(m.shape, -1, int)
    if sel.sum() < 4:
        return [], label
    P = dec(prev[sel])
    dl = dec(cur[sel]) - P
    O = dec(np.asarray(p.opt_cols, float))
    res = np.empty((len(P), len(O)))
    for k0 in range(0, len(O), 32):
        D = O[None, k0:k0 + 32] - P[:, None]
        a = np.clip((dl[:, None] * D).sum(-1) / np.maximum((D * D).sum(-1), 1e-6), 0.0, 1.0)
        res[:, k0:k0 + 32] = np.linalg.norm(dl[:, None] - a[..., None] * D, axis=-1)
    best = np.argmin(res, axis=1)
    tot = np.bincount(best, weights=np.linalg.norm(dl, axis=1), minlength=len(O))
    # (...each paint weighed with the mixes near it: a crackle's blue-black is near a dozen mixes, none of them a tenth of it alone)
    opt_lab = oklab(O) * p.HUE
    heads = []
    for k in np.argsort(-tot):
        if tot[k] <= 0:
            break
        if all(np.linalg.norm(opt_lab[k] - opt_lab[j]) >= apart for j in heads):
            heads.append(int(k))
    if not heads:
        return [], label
    gw = np.bincount(np.argmin(np.linalg.norm(opt_lab[:, None] - opt_lab[heads][None], axis=-1), axis=1), weights=tot,
                     minlength=len(heads))
    picked = [heads[j] for j in np.argsort(-gw)[:most] if gw[j] >= least * gw.sum()]
    if not picked:
        return [], label
    label[sel] = np.argmin(res[:, picked], axis=1)
    return [p.opt_names[k] for k in picked], label


THIN = 1.0          # mm, a part's thickness (area-weighted, half its width): thinner, a line traced - lashes, a lash line, cracks


def edge_soft(e, alpha):
    """Whether element `e`'s edge is soft in its step: the step's alpha stays up in a ring a millimeter and a half outside it."""
    ring = ndimage.binary_dilation(e, iterations=int(1.5 * PX)) & ~e
    # (...up all round it - a bruise's haze - never a run's glints or a tear's gold rim on one side: blended out, the runs had come out a
    # broad teal smear)
    return bool(ring.any() and float(alpha[ring].mean()) > 0.28 and float((alpha[ring] > 0.15).mean()) > 0.75)


def layer_plan(alpha, lab, face, soft_step=False):
    """A LAYER AS ELEMENTS: soft all over - shaded whole, toward its step's picture; else its thin parts of a color of their own (lines,
    outlines, lashes, cracks) traced on the step's own picture, never cleaned of their pieces - a crack's alpha breaks wherever its
    antialiasing thins - and its broad parts taken whole: each separate piece one element - filled crisp and shaded inside toward the
    step's colors where its edge is crisp, shaded out to a faded edge where its edge is soft, drawn as one stroke where long and narrow,
    dotted where small and round. -> [(mask, how, soft_edge, color or None)] - broad first, lines on top."""
    # (...A SOFT STEP IS ONE SOFT AREA, whatever its pieces: cut into parts, a shading's darker places had been drawn as sixty-six lines)
    if soft_step:
        reg = (alpha > 0.05) & face
        return [(reg, "shade_to", True, None)] if reg.sum() >= 12 else []
    on = clean(alpha > 0.5)
    if on.sum() < 12:
        return []
    soft = float(((alpha > 0.1) & (alpha < 0.6)).sum()) / max(float((alpha > 0.1).sum()), 1.0)
    thick, n, elong, _ = shape_of(on)
    if soft > 0.6 and thick > 1.5:
        return [(ndimage.binary_dilation(on, iterations=int(2 * PX)) & (alpha > 0.05), "shade_to", True, None)]
    thin, broad = [], np.zeros(on.shape, bool)
    for m in parts(alpha, lab, thresh=0.3):
        if shape_of(clean(m, 0.3))[0] < THIN:
            thin.append(m)
        else:
            broad |= clean(m, 0.3) & (alpha > 0.5)
    if thin and broad.any() and sum(x.sum() for x in thin) > 1.5 * broad.sum():
        thin.append(broad)
        broad = np.zeros(on.shape, bool)
    out = []
    if broad.any():
        broad = ndimage.binary_closing(broad, iterations=2) & on
        comps, k = ndimage.label(broad)
        for i in range(k):
            e = comps == i + 1
            if e.sum() < 12:
                continue
            th, pieces, el, rd = shape_of(e)
            spread = float(np.percentile(lab[e][:, 0], 85) - np.percentile(lab[e][:, 0], 15))
            sft = edge_soft(e, alpha)
            if e.sum() / (PX * PX) < 12.0 and rd > 0.6:
                how = "dots"
            elif el > 3.0 and th < 2.5 and not sft and spread <= 10.0:
                how = "strokes"
            else:
                how = "numbers"
            out.append((e, how, sft, None))
    # (...its thin parts traced together, each paint its own element - laid_paints splits them by what was laid, never by color)
    if thin:
        out.append((np.logical_or.reduce(thin), "trace", False, None))
    return out


def paints_for(p, cl, n):
    """THE PAINTS A PART IS MADE OF: its own colors `cl` (OKLab x100) gathered into up to `n` (hue weighed up, the starts spread), each
    matched to the nearest paint or mix, each once, the lightest first - a bruise's violet, teal and indigo-black, never three steps of
    lightness that lose the teal between them."""
    X = np.asarray(cl, float) * p.HUE
    if len(X) > 20000:
        X = X[np.random.default_rng(0).choice(len(X), 20000, replace=False)]
    C = X[[int(np.argmin(X[:, 0]))]]
    for _ in range(n - 1):
        dmin = np.min(((X[:, None] - C[None]) ** 2).sum(-1), axis=1)
        if dmin.max() < 10.0 ** 2:
            break
        C = np.vstack([C, X[int(np.argmax(dmin))]])
    for _ in range(12):
        lb = np.argmin(((X[:, None] - C[None]) ** 2).sum(-1), axis=1)
        C = np.array([X[lb == k].mean(0) if (lb == k).any() else C[k] for k in range(len(C))])
    share = np.bincount(lb, minlength=len(C)) / len(lb)
    opt = oklab(dec(p.opt_cols)) * p.HUE
    names = []
    for k in np.argsort(-C[:, 0]):
        if share[k] < 0.04:
            continue
        names.append(p.opt_names[int(np.argmin(np.linalg.norm(opt - C[k], axis=1)))])
    return list(dict.fromkeys(names))


def by_numbers(p, ext, alpha, lab, st, soft_edge):
    """Element `ext` painted by numbers from its step's colors `lab` at thickness `alpha`; what was laid, as words."""
    out = []
    names = paints_for(p, lab[ext & (alpha > 0.3)] if (ext & (alpha > 0.3)).any() else lab[ext], int(st.get("colors", 4)))
    if not names:
        return out
    opt = np.array([oklab(dec(p._color(nm))) for nm in names]) * p.HUE
    near = np.argmin(np.linalg.norm((lab[..., None, :] * p.HUE) - opt[None, None], axis=-1), axis=-1)
    near = np.where(ext, near, -1)
    from plan import smooth_shape
    from solve import _majority
    near = _majority(near, 7, ext)
    order = sorted(range(len(names)), key=lambda j: -oklab(dec(p._color(names[j])))[0])
    tool_most = st.get("tool")
    for j in order:
        sub = ext & (near == j)
        sub = smooth_shape(sub, int(PX * 0.6)) & ext
        if sub.sum() < (0.8 * PX) ** 2:
            continue
        sub = ndimage.binary_dilation(sub, iterations=int(0.6 * PX)) & ext
        col, nm = p._color(names[j]), names[j]
        comps, k = ndimage.label(sub)
        n0 = len(p.laid)
        for q, bx in enumerate(ndimage.find_objects(comps)):
            part = comps[bx] == q + 1
            if part.sum() < 6:
                continue
            thick = ndimage.distance_transform_edt(np.pad(part, 1)).max() / PX
            tool = tool_most or ("liner" if thick <= 1.0 else ("round" if thick <= 4.5 else "flat"))
            # (...filled whole, again where it is still thin - laid in rings at the step's thickness, it had left gaps between them)
            full = np.zeros(ext.shape, bool)
            full[bx] = part
            p._solid(full, col, nm, 1.0, tool, passes=2)
        out.append("%s %d" % (nm.split("+")[0].split(" ")[0] + ("+" if "+" in nm else ""), len(p.laid) - n0))
    # (...the borders between its colors worked wet, as far as its own colors run soft)
    border = np.zeros(ext.shape, bool)
    border[:, 1:] |= near[:, 1:] != near[:, :-1]
    border[1:, :] |= near[1:, :] != near[:-1, :]
    reach = float(st.get("reach", 2.5 if soft_edge else 1.2))
    band = ndimage.binary_dilation(border & ext, iterations=int(reach * PX)) & ext
    if band.any():
        n0 = len(p.laid)
        p._feather_area(band, reach, None, 1)
        out.append("blend %d" % (len(p.laid) - n0))
    return out


def paint_layers(ref, steps, pics, log=print):
    """EVERY LAYER PAINTED, IN ORDER: `ref` the surface (its frame, paints, bare color, face), `steps` the layers (`{name, soft, ...}`),
    `pics` each layer's picture at the canvas's resolution (sRGB floats). -> (the painter, where each layer's marks begin in its
    `laid`, the measures' reference)."""
    labs = [oklab(dec(p)) for p in pics]
    face = ref.face
    tools = [k for k, v in TOOLS.items()]
    final = ref
    final.srgb, final.lab = pics[-1], labs[-1]
    sheet_alpha = []
    p = PlanPainter(final, tools, 1)
    bare_lab = oklab(np.broadcast_to(dec(ref.bare), pics[0].shape).copy())
    starts = []
    for i, st in enumerate(steps):
        name = st["name"]
        starts.append(len(p.laid))
        prev = labs[i - 1] if i else bare_lab
        if i == 0 or st.get("how") == "base":
            L = {"name": name, "how": "base", "paint": st.get("paint", "auto"), "colors": labs[0]}
            p.layer_name = name
            col, pn = p.paint_of({**L, "paint": L["paint"]}, face)
            p._base({"name": name, "how": "base", "paint": pn if L["paint"] == "auto" else L["paint"]})
            p.stage_done(name)
            sheet_alpha.append((name, np.stack([face * 1.0] * 3, -1)))
            log("  %-20s base in %s" % (name, pn))
            continue
        d = changed(prev, labs[i], face)
        alpha = layer_alpha(d, face, float(st.get("floor", 3.0)), soft=bool(st.get("soft")))
        sheet_alpha.append((name, np.stack([alpha] * 3, -1)))
        hows = []
        if st.get("how"):
            groups = [(alpha > 0.15, st["how"], False, None)]
        else:
            groups = layer_plan(alpha, labs[i], face, bool(st.get("soft")))
        fade = False
        # (...BROAD COLOR, OPTIMIZED: each broad part's strokes found by gradient descent toward the step's own picture over the canvas as
        # it stands - a soft part out to where its step's alpha fades - and the layer's strokes laid together, each brush taken up once
        # for the layer, through its paints: part by part, each brush taken up again for each, 327484 had come to 52 acts - optimize.py)
        if not st.get("no_opt"):
            specs = []
            for m, how, soft_edge, core in groups:
                if how not in ("numbers", "shade_to", "strokes", "fill"):
                    continue
                fade = fade or soft_edge
                reg = m if st.get("soft") else ((ndimage.binary_dilation(m, iterations=int(3 * PX)) & (alpha > 0.05)) if soft_edge else m)
                names = paints_for(p, labs[i][reg & (alpha > 0.3)] if (reg & (alpha > 0.3)).any() else labs[i][reg],
                                   int(st.get("colors", 5)))
                specs.append((reg, names, soft_edge))
            groups = [g for g in groups if g[1] not in ("numbers", "shade_to", "strokes", "fill")]
            if specs:
                from optimize import optimize_layer
                p.layer_name = name
                hows.append(optimize_layer(p, specs, pics[i], log=log, iters=int(st.get("iters", 260))))
        for m, how, soft_edge, core in groups:
            fade = fade or soft_edge
            L = {"name": name, "how": how, "mask": m, "colors": labs[i], "smooth": float(st.get("smooth", 0.3)), "min_area": 0.3,
                 "paint": st.get("paint", "auto")}
            L.update({k: v for k, v in st.items() if k not in ("name", "add", "how")})
            if core is not None:
                # (...in its own color where it is most itself)
                j = int(np.argmin(np.linalg.norm((oklab(dec(p.opt_cols)) - core) * p.HUE, axis=1)))
                L["paint"] = p.opt_names[j]
            if how == "trace":
                # (...THE STEP'S OWN LINES inside where its part is, traced on its own picture - each paint they were laid in on its own,
                # a line kept for the paint most of its new points were laid in: a line already drawn, redrawn aside, is no one's)
                names, label = laid_paints(p, m, pics[i - 1], pics[i], alpha)
                near = ndimage.grey_dilation(label, size=3)
                for g, nm in enumerate(names):
                    mine = ndimage.binary_dilation(label == g, iterations=3) & face

                    def keep(l, g=g, k=len(names)):
                        ij = np.clip(np.round(np.asarray(l["pts"]) * PX).astype(int), 0, [near.shape[1] - 1, near.shape[0] - 1])
                        at = near[ij[:, 1], ij[:, 0]]
                        counts = np.bincount(at[at >= 0], minlength=k)
                        return int(np.argmax(counts)) == g and counts.sum() >= 0.3 * len(at)

                    Lg = dict(L, how="lines", paint=nm, lines_from=pics[i], mask=mine, all=True, keep=keep,
                              tool=st.get("tool", "liner"), line_smooth=float(st.get("line_smooth", 0.4)), quick=True)
                    p.layer_name = name
                    n0 = len(p.laid)
                    try:
                        p._lines(Lg)
                    except Exception as e:
                        log("  %-20s lines failed: %s" % (name, e))
                    hows.append("lines %d %s" % (len(p.laid) - n0, nm.split("+")[0].split(" ")[0]))
                continue
            elif how == "numbers" and soft_edge:
                # (...a soft element shaded out to where its step's alpha fades, toward the step's own colors)
                how = "shade_to"
                m = ndimage.binary_dilation(m, iterations=int(3 * PX)) & (alpha > 0.05)
            if how == "numbers":
                # (...PAINTED BY NUMBERS FROM ITS OWN STEP: the element cut by the step's own colors into the paints they are nearest, each
                # part laid lightest first a little past its border, as thick at each point as the step laid it there - a soft edge thins
                # out as the step's does - then the borders between them worked wet, as far as the element is soft; never shaded by guess)
                ext = (ndimage.binary_dilation(m, iterations=int(3 * PX)) & (alpha > 0.06)) if soft_edge else m
                hows.extend(by_numbers(p, ext, alpha if soft_edge else np.maximum(alpha, m * 1.0), labs[i], st, soft_edge))
                continue
            elif how == "fill_shade":
                # (...CRISP, THEN SHADED INSIDE: the paint its middle is made of filled to its edge, then the step's darker and lighter
                # colors worked in where it has them, kept inside - lips, a lid: an edge a hand cuts in, the tone a hand works in after)
                cl = labs[i][m]
                med = np.median(cl, axis=0)
                jb = int(np.argmin(np.linalg.norm((oklab(dec(p.opt_cols)) - med) * p.HUE, axis=1)))
                p.layer_name = name
                n0 = len(p.laid)
                p._fill(dict(L, how="fill", paint=p.opt_names[jb], mask=m))
                hows.append("fill %s %d" % (p.opt_names[jb].split(" ")[0], len(p.laid) - n0))
                for nm in paints_for(p, cl, 3):
                    if nm == p.opt_names[jb]:
                        continue
                    Ls = dict(L, how="shade", paint=nm, mask=m, target=pics[i], most=0.9, soft=0.5, least=0.08, reach=0.0,
                              tool=st.get("tool", "round"))
                    n0 = len(p.laid)
                    p._shade(Ls)
                    hows.append("shade %s %d" % (nm.split(" ")[0], len(p.laid) - n0))
                continue
            elif how == "shade_to":
                # (...each paint the step's colors there are made of, lightest first, as much at each point as the step wants - a gradient,
                # never patches)
                cl = labs[i][m]
                names = paints_for(p, cl, 4)
                order = sorted(names, key=lambda nm: -oklab(dec(p._color(nm)))[0])
                for nm in order:
                    Ls = dict(L, how="shade", paint=nm, mask=m, target=pics[i], most=0.95, soft=0.8, least=0.06, reach=1.2,
                              tool=st.get("tool", "round"))
                    Ls.pop("colors", None)
                    p.layer_name = name
                    n0 = len(p.laid)
                    try:
                        p._shade(Ls)
                    except Exception as e:
                        log("  %-20s shade failed: %s" % (name, e))
                    hows.append("shade %s %d" % (nm.split(" ")[0], len(p.laid) - n0))
                continue
            if how == "lines":
                L.update({"lines_from": pics[i], "mask": ndimage.binary_dilation(m, iterations=2), "all": True,
                          "tool": st.get("tool", "liner"), "paint": st.get("paint", "auto")})
            elif how == "shade":
                # (...out to its soft edge: a shading's alpha fades past where it is half laid)
                L.update({"mask": ndimage.binary_dilation(m, iterations=int(2 * PX)) & (alpha > 0.05), "amount": alpha,
                          "most": float(st.get("most", 0.9)), "least": 0.05})
            elif how == "texture":
                if not L.get("paints"):
                    L["paints"] = paints_for(p, labs[i][m], 2)
                L.setdefault("size", 3.0)
            elif how == "gradient":
                if not L.get("paints"):
                    L["paints"] = paints_for(p, labs[i][m], 4)
                L.setdefault("reach", 2.0)
            elif how == "strokes":
                L.update({"one": False, "line_smooth": 1.0, "spill": 0.2, "tool": st.get("tool", "round"), "spur": 2.0})
            elif how == "dots":
                L.update({"tool": st.get("tool", "handle"), "max_area": 30.0})
            p.layer_name = name
            n0 = len(p.laid)
            try:
                getattr(p, "_" + how)(L)
            except Exception as e:
                log("  %-20s %s failed: %s" % (name, how, e))
            hows.append("%s %d" % (how, len(p.laid) - n0))
        # (...and its soft edge, where the step's own was soft - faded out into what is round it)
        if st.get("fade") or fade:
            p._smudge({"name": name, "how": "smudge", "mask": alpha > 0.5, "band": float(st.get("fade", 5.0)), "size": 5.0,
                       "strength": 0.55, "inside": 0.25, "smooth": 1.0})
            hows.append("fade")
        p.stage_done(name)
        log("  %-20s %s; the painting at %.1f min" % (name, ", ".join(hows), p.hand.t / 60))
    return p, starts, sheet_alpha


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("episode")
    ap.add_argument("--layers", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--video", action="store_true")
    a = ap.parse_args()
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    ref = Reference(a.episode)
    ld = Path(a.layers)
    doc = json.loads((ld / "steps.json").read_text())
    steps = doc["steps"]
    pics = [load_step(ld / ("step_%02d.png" % (i + 1)), ref) for i in range(len(steps))]
    face_ref = ref.srgb.copy()
    p, starts, sheet_alpha = paint_layers(ref, steps, pics)
    final = ref
    face = ref.face
    canvas = p.stages[-1][1]
    _, ref_lines = lines_mod.find(final.srgb, PX, face)
    m_final = measure.measure(canvas, final, ref_lines)
    measure.sheet(out / "compare.png", [("reference (face_ref)", face_ref), ("the steps' last", final.srgb), ("lab, from layers", canvas),
                                       ("error vs steps", measure.error_map(canvas, final))])
    measure.sheet(out / "steps.png", [("step %d %s" % (i + 1, s["name"]), pics[i]) for i, s in enumerate(steps)])
    measure.sheet(out / "alphas.png", sheet_alpha)
    measure.sheet(out / "stages.png", [(n, img) for n, img, t in p.stages])
    print(measure.table([("lab vs steps", m_final)]))
    print("  painting %.1f min, %d marks, wasted %.1f min" % (p.hand.t / 60, len(p.laid), getattr(p, "wasted", 0.0) / 60))
    if a.video:
        import paint as paint_mod
        paint_mod.timelapse(p, out)
    print("  -> " + str(out))


if __name__ == "__main__":
    main()
