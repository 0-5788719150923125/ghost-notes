"""What each behavior lays, in the painting lab (TEST_PLAN.md, "The behaviors").

A TOOL IS WHAT IS HELD, A BEHAVIOR HOW IT IS USED: each function here is one behavior's mark - its motion (a path, a point), its
pressure over the course of the mark, how it uses what is on the tool, and what it leaves. Every one returns a `Mark`: the canvas's
new paint over the box it touched (`pre`, `alp`), never yet laid - the painter weighs it first (solve.py) and lays it only if it
helps - and what the show needs to play it again (`rec`).

THE SAME FEW DYNAMICS UNDER ALL OF THEM: a load that falls as it is used (`load`), pressure (width, and how much is laid), speed
(fast is broken), the tool's angle (a flat brush's width), wetness (marks.wet_blend), how thick the paint is (`th`). Millimeters
throughout; the canvas is canvas.PX pixels a millimeter.

THE SHAPES ARE THE ENGINE'S (PaintLayers.raster): a brush's belly thinner toward its edges (BELLY), a tail narrowing over its last
quarter, bristle streaks that open as it runs dry; a sponge's ragged edge, pores, and a film that fades toward its rim.
"""
from dataclasses import dataclass, field

import numpy as np
from scipy.spatial import cKDTree

from canvas import PX, Canvas


@dataclass
class Mark:
    kind: str                      # the behavior
    tool: str
    sl: tuple                      # the box it touched (rows, columns)
    pre: np.ndarray                # the canvas's paint there after it
    alp: np.ndarray
    pts: np.ndarray                # its path (millimeters), a point for a press
    length: float = 0.0            # how far the tool moved on the surface
    presses: int = 0               # how many times it came down
    paint: str = ""                # what it carried ("" a clean tool)
    rec: dict = field(default_factory=dict)


# --- noise: value noise, each octave turned from the last, no grid in it ---------------------------------------------------------

def _hash(ix, iy, seed):
    h = (ix.astype(np.uint64) * np.uint64(374761393) + iy.astype(np.uint64) * np.uint64(668265263)
         + np.uint64(seed & 0xffffffff) * np.uint64(2246822519)) & np.uint64(0xffffffff)
    h = ((h ^ (h >> np.uint64(13))) * np.uint64(1274126177)) & np.uint64(0xffffffff)
    return ((h ^ (h >> np.uint64(16))) & np.uint64(0xffffff)).astype(np.float64) / 16777216.0


def vnoise(x, y, seed=0):
    ix = np.floor(x).astype(np.int64)
    iy = np.floor(y).astype(np.int64)
    fx = x - ix
    fy = y - iy
    ux = fx * fx * (3 - 2 * fx)
    uy = fy * fy * (3 - 2 * fy)
    ix = ix + (1 << 20)
    iy = iy + (1 << 20)
    a = _hash(ix, iy, seed)
    b = _hash(ix + 1, iy, seed)
    c = _hash(ix, iy + 1, seed)
    d = _hash(ix + 1, iy + 1, seed)
    return (a + (b - a) * ux) + ((c + (d - c) * ux) - (a + (b - a) * ux)) * uy


def fbm(x, y, seed=0, octaves=4):
    s = 0.0
    w = 0.5
    for o in range(octaves):
        s = s + w * vnoise(x, y, seed + o * 101)
        x, y = 0.8 * x - 0.6 * y + 3.1, 0.6 * x + 0.8 * y + 1.7
        x, y = x * 2.03, y * 2.03
        w *= 0.5
    return s / (1 - 0.5 ** octaves)


def smoothstep(a, b, x):
    t = np.clip((x - a) / np.where(np.abs(b - a) < 1e-9, 1e-9, b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


# --- where a mark reaches -----------------------------------------------------------------------------------------------------------

def box(pts, reach, h, w):
    """The canvas box (row and column slices) round points `pts` (mm) out to `reach` (mm); None off the canvas."""
    lo = (pts.min(axis=0) - reach) * PX
    hi = (pts.max(axis=0) + reach) * PX
    x0, y0 = max(int(np.floor(lo[0])), 0), max(int(np.floor(lo[1])), 0)
    x1, y1 = min(int(np.ceil(hi[0])) + 1, w), min(int(np.ceil(hi[1])) + 1, h)
    if x1 <= x0 or y1 <= y0:
        return None
    return (slice(y0, y1), slice(x0, x1))


def grid(sl):
    """The millimeter positions of the pixel centers in box `sl`: X, Y (h, w)."""
    ys = (np.arange(sl[0].start, sl[0].stop) + 0.5) / PX
    xs = (np.arange(sl[1].start, sl[1].stop) + 0.5) / PX
    return np.meshgrid(xs, ys)


def resample(pts, ds):
    """Path `pts` (N, 2) as points `ds` apart: (M, 2), how far along each is (M,), and the share of the way each came from (M,)."""
    pts = np.asarray(pts, dtype=float)
    if len(pts) < 2:
        return pts.copy(), np.zeros(1), np.zeros(1)
    seg = np.linalg.norm(np.diff(pts, axis=0), axis=1)
    s = np.concatenate([[0.0], np.cumsum(seg)])
    total = s[-1]
    if total < 1e-6:
        return pts[:1].copy(), np.zeros(1), np.zeros(1)
    n = max(int(np.ceil(total / ds)), 1)
    sn = np.linspace(0.0, total, n + 1)
    x = np.interp(sn, s, pts[:, 0])
    y = np.interp(sn, s, pts[:, 1])
    k = np.interp(sn, s, np.arange(len(pts), dtype=float))
    return np.stack([x, y], axis=1), sn, k


def along(values, k):
    """Per-point `values` (N,) at fractional point indices `k`."""
    values = np.asarray(values, dtype=float)
    if values.ndim == 0 or len(values) == 1:
        return np.full(len(k), float(np.ravel(values)[0]))
    return np.interp(k, np.arange(len(values)), values)


def path_field(dense, sl):
    """For each pixel of box `sl`: its distance to path `dense` (mm), the nearest point's index, and which side it lies on (+1 left)."""
    X, Y = grid(sl)
    q = np.stack([X.ravel(), Y.ravel()], axis=1)
    if len(dense) == 1:
        d = np.linalg.norm(q - dense[0], axis=1)
        return d.reshape(X.shape), np.zeros(X.shape, dtype=int), np.ones(X.shape)
    d, i = cKDTree(dense).query(q)
    tang = np.gradient(dense, axis=0)
    tang /= np.maximum(np.linalg.norm(tang, axis=1, keepdims=True), 1e-9)
    rel = q - dense[i]
    side = np.sign(tang[i, 0] * rel[:, 1] - tang[i, 1] * rel[:, 0])
    return d.reshape(X.shape), i.reshape(X.shape), side.reshape(X.shape)


# --- laying broad color -------------------------------------------------------------------------------------------------------------

FILM = 0.95          # what a full, freshly loaded press leaves
LOAD_POWER = 0.8
PRESS_DEPOSIT = 0.45
RAGGED = 0.6         # a sponge print's edge wanders this far (mm)
PORE = 0.35          # a sponge's pores this fine (mm)
EDGE_FADE = 2.0      # its film thins over this much of its rim (mm)
SPONGE_DRY = 0.6     # what a sponge all but run dry still leaves, a share of a full load's - a dry press had left the bare skin showing


def sponge_print(cv, c, r, color, paint, load=1.0, press=1.0, corner=False, seed=0, kind="pat", tool="sponge", ragged=None):
    """A SPONGE PRESSED at `c`: its face (patting) or its corner (stippling, `corner`), `r` its face's radius - pressed lighter, less of
    it touches and less is left; a ragged edge, pores, a film fading to its rim; what is left falls with the load."""
    rr = r * (0.38 if corner else 1.0) * (0.75 + 0.25 * press)
    rg = RAGGED if ragged is None else ragged
    sl = box(np.array([c]), rr + rg * 2, cv.h, cv.w)
    if sl is None:
        return None
    X, Y = grid(sl)
    d = np.hypot(X - c[0], Y - c[1])
    edge = rr + (fbm(X / max(rg * 2.5, 0.8) + seed * 0.37, Y / max(rg * 2.5, 0.8), seed) - 0.5) * 2 * rg
    a = np.clip((edge - d) / 0.35 + 0.5, 0, 1)
    dep = FILM * (SPONGE_DRY + (1 - SPONGE_DRY) * load) ** LOAD_POWER * (PRESS_DEPOSIT + (1 - PRESS_DEPOSIT) * press)
    pores = np.clip(0.55 + (fbm(X / PORE + seed * 1.7, Y / PORE, seed + 7) - 0.5) * 2 * (0.75 if corner else 0.55), 0, 1)
    a = a * dep * (pores + (1 - pores) * dep * dep) * (0.4 + 0.6 * np.clip((edge - d) / min(EDGE_FADE, rr * 0.5), 0, 1))
    pre, alp = Canvas.over(cv.pre[sl], cv.alp[sl], a, color)
    return Mark(kind, tool, sl, pre, alp, np.array([c]), 0.0, 1, paint, {"c": list(c), "r": rr, "press": press, "load": load, "corner": bool(corner)})


BELLY = 0.5          # the outer share of a brush's half width its paint thins out over
TAIL = 0.25          # the last share of a pull that narrows and pales
TAIL_NARROW = 0.75
TAIL_LEFT = 0.55
DRY_LEAST = 0.55     # what a pull all but run dry still lays
LOAD_MM = 260.0      # a brush's load lasts about this far along its pulls (mm)


def brush_stroke(cv, pts, half_w, color, paint, th=1.0, load=1.0, kind="sweep", tool="round", edge=0.25, belly=BELLY,
                 streak=(0.12, 0.9, 0.8), streak_across=0.3, streak_along=6.0, tail=TAIL, load_mm=LOAD_MM, color2=None, seed=0,
                 coverage=None):
    """A BRUSH PULLED along `pts`, `half_w` wide at each point (pressure made width): thickest along its middle, thinning to its edges
    (`belly`); narrowing and paling over its `tail`; its load falling along it (`load_mm`), the bristles' streaks opening as it runs
    dry; `th` how thick the paint is (a glaze thin). `color2`: loaded with two paints, one on each side (double loading) - the color
    runs from one to the other across it. `coverage`: a dry brush's - only that share of the surface catches it."""
    pts = np.asarray(pts, dtype=float)
    hw = np.broadcast_to(np.asarray(half_w, dtype=float), (len(pts),))
    ds = max(min(float(hw.min()) * 0.25, 0.25), 0.05)
    dense, s, k = resample(pts, ds)
    w_d = along(hw, k)
    # (...as thick as `th` says at each point, where it is given one a point: a touch of a dark paint laid heavier where the picture is
    # darker, fading out where it is not)
    th_d = along(th, k) if np.ndim(th) > 0 else None
    total = max(s[-1], 1e-6)
    u = s / total
    tl = smoothstep(1 - tail, 1.0, u) if tail > 0 else np.zeros_like(u)
    w_d = w_d * (1 - (1 - TAIL_NARROW) * tl)
    ld = load * np.exp(-s / load_mm)
    reach = float(w_d.max()) + edge
    sl = box(dense, reach, cv.h, cv.w)
    if sl is None:
        return None
    d, i, side = path_field(dense, sl)
    w = w_d[i]
    core = w * (1 - belly)
    a = 1 - smoothstep(core - edge * 0.5, w + edge * 0.5, d) if belly > 0 else np.clip((w - d) / edge + 0.5, 0, 1)
    lp = ld[i]
    dry = np.clip(1 - lp, 0, 1)
    X, Y = grid(sl)
    # (...its bristles: streaks along the way it is pulled - across it by the side it lies on and how far out, along it by how far)
    across = side * d / streak_across
    n = vnoise(across + seed * 0.13, s[i] / streak_along + seed * 0.71, seed)
    amount = np.clip(streak[0] + dry * streak[1], 0, streak[2])
    a = a * (1 - amount + amount * smoothstep(0.25, 0.65, n)) * (1 - (1 - TAIL_LEFT) * tl[i]) * (DRY_LEAST + (1 - DRY_LEAST) * lp)
    if coverage is not None:
        # (...A DRY BRUSH: only the surface's high points and the bristles' paths catch it - fewer as it runs out)
        tooth = 0.5 * fbm(X / 0.25 + seed, Y / 0.25, seed + 3) + 0.5 * vnoise(across * 1.5 + seed, s[i] / (streak_along * 2), seed + 5)
        cv_ = np.clip(coverage * lp, 0.05, 1.0)
        a = a * smoothstep(1 - cv_ - 0.08, 1 - cv_ + 0.08, tooth)
    a = np.clip(a * (th_d[i] if th_d is not None else th), 0, 1)
    if color2 is not None:
        t = smoothstep(-1.0, 1.0, side * d / np.maximum(w, 1e-6))[..., None]
        col = np.asarray(color) * (1 - t) + np.asarray(color2) * t
    else:
        col = np.asarray(color)
    pre, alp = Canvas.over(cv.pre[sl], cv.alp[sl], a, col)
    return Mark(kind, tool, sl, pre, alp, pts, float(total), 1, paint, {"pts": pts.tolist(), "half_w": hw.tolist(),
                "th": np.asarray(th).tolist(), "load": load})


# --- lines and small marks ----------------------------------------------------------------------------------------------------------

def line(cv, pts, half_w, color, paint, th=1.0, load=1.0, kind="line", tool="liner", seed=0):
    """A LINE drawn with a brush's tip: crisp, even, pressed to its width point by point; a liner's load lasts about 110 mm."""
    return brush_stroke(cv, pts, half_w, color, paint, th, load, kind, tool, edge=0.08, belly=0.0, streak=(0.12, 0.0, 0.12),
                        streak_across=0.2, streak_along=4.0, tail=0.12, load_mm=110.0, seed=seed)


def flick(cv, pts, half_w, color, paint, th=1.0, load=1.0, tool="round", seed=0):
    """A TAPERED STROKE: pressed down, then lifted as it moves - thick to thin all along."""
    pts = np.asarray(pts, dtype=float)
    n = len(pts)
    taper = np.linspace(1.0, 0.12, n) ** 0.8
    return brush_stroke(cv, pts, np.asarray(half_w) * taper, color, paint, th, load, "flick", tool, edge=0.1, belly=0.2,
                        streak=(0.1, 0.4, 0.4), tail=0.0, load_mm=150.0, seed=seed)


TIP_LEAST = 0.15


def dab(cv, c, r, color, paint, press=1.0, th=1.0, tool="round", seed=0):
    """A BRUSH'S TIP PRESSED DOWN: a soft dot as big as it is pressed."""
    rr = r * (TIP_LEAST + (1 - TIP_LEAST) * press)
    sl = box(np.array([c]), rr + 0.4, cv.h, cv.w)
    if sl is None:
        return None
    X, Y = grid(sl)
    d = np.hypot(X - c[0], Y - c[1])
    edge = rr + (vnoise(X / 0.5 + seed, Y / 0.5, seed) - 0.5) * 0.24
    a = np.clip((edge - d) / 0.2 + 0.5, 0, 1) * th
    pre, alp = Canvas.over(cv.pre[sl], cv.alp[sl], a, color)
    return Mark("dab", tool, sl, pre, alp, np.array([c]), 0.0, 1, paint, {"c": list(c), "r": rr})


def dot(cv, c, r, color, paint, load=1.0, tool="handle"):
    """A DOT from a brush handle's end: perfectly round and crisp, smaller as what was taken up runs out."""
    rr = r * (0.55 + 0.45 * np.sqrt(load))
    sl = box(np.array([c]), rr + 0.2, cv.h, cv.w)
    if sl is None:
        return None
    X, Y = grid(sl)
    d = np.hypot(X - c[0], Y - c[1])
    a = np.clip((rr - d) / 0.06 + 0.5, 0, 1) * 0.97
    pre, alp = Canvas.over(cv.pre[sl], cv.alp[sl], a, color)
    return Mark("dot", tool, sl, pre, alp, np.array([c]), 0.0, 1, paint, {"c": list(c), "r": rr})


TOOTH = 0.12          # the skin's grain a pencil catches (mm)


def pencil(cv, pts, half_w, press, color, paint, seed=0, tool="pencil"):
    """A PENCIL LINE: a hard core, narrow and crisp; light pressure catches only the skin's high points (grainy, broken), harder fills
    it in. The grain is the surface's, the same under every pass: a second pass at the same pressure darkens what caught, no more."""
    pts = np.asarray(pts, dtype=float)
    pr = np.broadcast_to(np.asarray(press, dtype=float), (len(pts),))
    dense, s, k = resample(pts, 0.05)
    p_d = along(pr, k)
    sl = box(dense, half_w + 0.1, cv.h, cv.w)
    if sl is None:
        return None
    d, i, side = path_field(dense, sl)
    X, Y = grid(sl)
    a = np.clip((half_w - d) / 0.06 + 0.5, 0, 1)
    tooth = fbm(X / TOOTH, Y / TOOTH, 4242)          # the surface's own grain, never the stroke's
    cov = 0.3 + 0.7 * p_d[i]
    a = a * smoothstep(1 - cov - 0.08, 1 - cov + 0.08, tooth) * (0.55 + 0.4 * p_d[i])
    pre, alp = Canvas.over(cv.pre[sl], cv.alp[sl], a, color)
    return Mark("pencil", tool, sl, pre, alp, pts, float(s[-1]), 1, paint, {"pts": pts.tolist(), "half_w": half_w, "press": pr.tolist()})


def lipstick(cv, pts, half_w, color, paint, seed=0, tool="lipstick"):
    """LIPSTICK: a wax bullet that is its own paint - opaque, even, crisp at its edge, fine drag streaks; never reloaded."""
    return brush_stroke(cv, pts, half_w, color, paint, 0.92, 1.0, "lipstick", tool, edge=0.08, belly=0.08, streak=(0.18, 0.0, 0.18),
                        streak_across=0.12, streak_along=10.0, tail=0.05, load_mm=1e9, seed=seed)


# --- texture ------------------------------------------------------------------------------------------------------------------------

def dry_brush(cv, pts, half_w, color, paint, load=0.6, th=0.9, tool="flat", seed=0):
    """DRY BRUSHING: a stiff brush with almost no paint dragged quickly - broken, streaky coverage on the surface's high points."""
    return brush_stroke(cv, pts, half_w, color, paint, th, 1.0, "dry_brush", tool, edge=0.2, belly=0.3, streak=(0.5, 0.0, 0.5),
                        streak_across=0.18, streak_along=9.0, tail=0.15, load_mm=180.0, seed=seed, coverage=load)


def scumble(cv, c, r, color, paint, load=0.5, th=0.6, tool="round", seed=0, turns=3):
    """SCUMBLING: a brush with little paint scrubbed in small circles - a soft, broken veil."""
    ang = np.linspace(0, turns * 2 * np.pi, turns * 16)
    rad = r * (0.5 + 0.5 * np.sin(ang * 0.37 + seed))
    drift = np.linspace(-r * 0.6, r * 0.6, len(ang))
    pts = np.stack([c[0] + rad * np.cos(ang) + drift, c[1] + rad * np.sin(ang)], axis=1)
    m = dry_brush(cv, pts, r * 0.45, color, paint, load, th, tool, seed)
    if m is not None:
        m.kind = "scumble"
    return m


def spatter(cv, c, way, spread, color, paint, rng, n=50, tool="round", most=None):
    """SPATTERING: a loaded brush flicked - a spray of droplets, many small and a few large, scattered ahead of it."""
    way = np.asarray(way, dtype=float)
    way = way / max(np.linalg.norm(way), 1e-9)
    nrm = np.array([-way[1], way[0]])
    t = rng.normal(0, 1, n) * spread
    q = rng.normal(0, 1, n) * spread * 0.5
    pos = np.asarray(c) + np.outer(t, way) + np.outer(q, nrm)
    # (...a fan's or a toothbrush's drops fine, a stiff round brush's bold)
    most = most if most is not None else (0.35 if tool in ("fan", "toothbrush") else 0.7)
    rad = np.minimum(0.04 * (1 - rng.random(n)) ** (-1 / 1.6), most)
    sl = box(pos, 0.8, cv.h, cv.w)
    if sl is None:
        return None
    X, Y = grid(sl)
    a = np.zeros(X.shape)
    for p, r in zip(pos, rad):
        a = np.maximum(a, np.clip((r - np.hypot(X - p[0], Y - p[1])) / 0.05 + 0.5, 0, 1))
    pre, alp = Canvas.over(cv.pre[sl], cv.alp[sl], a * 0.95, color)
    return Mark("spatter", tool, sl, pre, alp, np.array([c]), 0.0, 1, paint, {"c": list(c), "way": way.tolist(), "spread": spread, "n": n})


# --- moving and taking off paint already on -----------------------------------------------------------------------------------------

def _profile(X, Y, p, r, soft):
    d = np.hypot(X - p[0], Y - p[1])
    return 1 - smoothstep(r * (1 - soft), r, d)


def move(cv, pts, half_w, pick, lay, kind, tool, soft=0.8, wet_only=None, now=0.0, take=0.0):
    """PAINT ALREADY ON MOVED by a tool carrying none of its own (feathering, wet blending, sponge blending, smudging) - or taken off
    (`take`, lifting): along `pts` the tool takes up `pick` of what lies under it at each step and lays `lay` of what it carries.
    `wet_only` (seconds): only paint laid that recently moves."""
    pts = np.asarray(pts, dtype=float)
    dense, s, k = resample(pts, max(half_w * 0.35, 0.2))
    sl = box(dense, half_w + 0.5, cv.h, cv.w)
    if sl is None:
        return None
    pre = cv.pre[sl].copy()
    alp = cv.alp[sl].copy()
    X, Y = grid(sl)
    wet = np.ones(alp.shape) if wet_only is None else np.clip(1 - (now - cv.laid_t[sl]) / wet_only, 0, 1)
    if take > 0:
        # (...taken off as much as `take` over its whole width, however many steps pass over a point)
        step = max(half_w * 0.35, 0.2)
        take_step = 1 - (1 - take) ** (step / (2 * half_w))
        for p in dense:
            prof = _profile(X, Y, p, half_w, soft) * wet
            if prof.sum() < 1e-6:
                continue
            f = 1 - take_step * prof
            pre *= f[..., None]
            alp *= f
    else:
        pre, alp = _carry(pre, alp, X, Y, dense, half_w, soft, pick, lay, wet)
    return Mark(kind, tool, sl, pre, alp, pts, float(s[-1]), 1, "", {"pts": pts.tolist(), "half_w": half_w})


def _carry(pre, alp, X, Y, dense, half_w, soft, pick, lay, wet=None):
    """What a tool drawn along `dense` (mm) carries: at each step it takes up `pick` of what lies under it and lays `lay` of what it holds
    - the paint already on moved along the way it goes. -> (pre, alp)."""
    held_pre = None
    held_alp = 0.0
    for p in dense:
        prof = _profile(X, Y, p, half_w, soft)
        if wet is not None:
            prof = prof * wet
        wsum = prof.sum()
        if wsum < 1e-6:
            continue
        under_pre = (pre * prof[..., None]).sum(axis=(0, 1)) / wsum
        under_alp = float((alp * prof).sum() / wsum)
        if held_pre is None:
            held_pre, held_alp = under_pre, under_alp
        else:
            held_pre = held_pre + (under_pre - held_pre) * pick
            held_alp = held_alp + (under_alp - held_alp) * pick
        g = lay * prof
        pre = pre + (held_pre - pre) * g[..., None]
        alp = alp + (held_alp - alp) * g
    return pre, alp


def soften(cv, pts, half_w, reach=0.8, strength=0.8, kind="feather", tool="round", drag=0.0):
    """FEATHERING: a clean, damp brush drawn along `pts` moves the paint under it a little way each way - each point it passes taken
    toward what lies within `reach` mm round it, as much as `strength` where the brush bears hardest. An edge becomes a gradient; the
    tones either side stay their own (a brush that carried one average over all it touched had flattened both). AND IT DRAGS (`drag`,
    0-1: what it takes up and lays as it goes - feedback 0020: a fat brush "spill[ing] over the edge, dragging/blending color with it"):
    drawn from a color out over the white, it carries a little of it, fading, where a blur alone had left the white untouched."""
    pts = np.asarray(pts, dtype=float)
    dense, s, k = resample(pts, max(half_w * 0.3, 0.2))
    sl = box(dense, half_w + reach * 3, cv.h, cv.w)
    if sl is None:
        return None
    d, i, side = path_field(dense, sl)
    prof = (1 - smoothstep(half_w * 0.3, half_w, d)) * strength
    sig = reach * PX
    pre = cv.pre[sl]
    alp = cv.alp[sl]
    from scipy import ndimage
    pre_m = np.stack([ndimage.gaussian_filter(pre[..., c], sig) for c in range(3)], -1)
    alp_m = ndimage.gaussian_filter(alp, sig)
    g = prof[..., None]
    pre2, alp2 = pre + (pre_m - pre) * g, alp + (alp_m - alp) * prof
    if drag > 0:
        X, Y = grid(sl)
        pre2, alp2 = _carry(pre2, alp2, X, Y, dense, half_w, 0.8, drag, drag * 0.8)
    return Mark(kind, tool, sl, pre2, alp2, pts, float(s[-1]), 1, "",
                {"pts": pts.tolist(), "half_w": half_w, "reach": reach})


def feather(cv, pts, half_w, tool="round"):
    return soften(cv, pts, half_w, 0.8, 0.8, "feather", tool)


def wet_blend(cv, pts, half_w, now, tool="round", wet=60.0):
    return move(cv, pts, half_w, 0.5, 0.6, "wet_blend", tool, soft=0.8, wet_only=wet, now=now)


def sponge_blend(cv, c, r, rng, tool="sponge", n=6):
    """A DAMP SPONGE BOUNCED over an edge: what is under it evened out press by press, a stippled transition."""
    pts = np.asarray(c) + rng.normal(0, r * 0.35, (n, 2))
    m = move(cv, pts, r * 0.45, 0.35, 0.35, "sponge_blend", tool, soft=0.5)
    if m is not None:
        m.presses, m.length = n, 0.0
    return m


def smudge(cv, pts, half_w, tool="finger"):
    return move(cv, pts, half_w, 0.6, 0.55, "smudge", tool, soft=0.95)


# A HAND'S PULL AS IT IS DRAWN ([slipped]): a steady hand's wander across it, a share of the brush's half width, over this wavelength (mm);
# a slip aside this often, as far as this many half widths at the most (most much less: the square of a uniform); run on past its end this
# often, by up to this many half widths.
SLIP_STEADY = 0.06
SLIP_WAVE = 12.0
SLIP_EVERY = 0.12
SLIP_MOST = 1.2
OVER_EVERY = 0.10
OVER_MOST = 1.0


def slipped(pts, half_w, seed):
    """THE PULL AS A HAND DRAWS IT (the user, 2026-11-09, of feedback 0020: "You would want a hand that generally tries to keep its whole
    brush inside of the edge; however hands can make mistakes, and spill over the edge, dragging/blending color with it ... we want
    naturally-looking behaviors here"): the planned path `pts` (mm) with a steady hand's slow wander, now and then a slip aside - a smooth
    bump, mostly small, rarely as far as SLIP_MOST half widths - and now and then run on past its end. The mark is laid where the hand
    went, so the show's brush and its paint agree. Seeded: the same pull slips the same way every time."""
    pts = np.asarray(pts, float)
    if len(pts) < 2:
        return pts
    rng = np.random.default_rng(int(seed) & 0xFFFFFFFF)
    seg = np.diff(pts, axis=0)
    s = np.concatenate([[0.0], np.cumsum(np.hypot(seg[:, 0], seg[:, 1]))])
    if s[-1] < 1e-6:
        return pts
    tang = np.gradient(pts, axis=0)
    tang /= np.maximum(np.linalg.norm(tang, axis=1, keepdims=True), 1e-9)
    nrm = np.stack([-tang[:, 1], tang[:, 0]], 1)
    ph = rng.uniform(0, 2 * np.pi, 2)
    off = SLIP_STEADY * half_w * (0.6 * np.sin(2 * np.pi * s / SLIP_WAVE + ph[0]) + 0.4 * np.sin(2 * np.pi * s / (SLIP_WAVE * 0.43) + ph[1]))
    if rng.random() < SLIP_EVERY:
        u = rng.random()
        h = half_w * SLIP_MOST * (0.25 + 0.75 * u * u) * (1.0 if rng.random() < 0.5 else -1.0)
        at = rng.uniform(0.15, 0.85) * s[-1]
        span = rng.uniform(3.0, 7.5)
        off = off + h * np.exp(-((s - at) / span) ** 2)
    out = pts + nrm * off[:, None]
    if rng.random() < OVER_EVERY:
        out = np.vstack([out, out[-1] + tang[-1] * half_w * OVER_MOST * (0.3 + 0.7 * rng.random())])
    return out


def blot(cv, c, r, under_pre, under_alp, take=0.85, seed=0, tool="bud"):
    """A SPILL BLOTTED OFF WITH A COTTON SWAB (feedback 0020: "we might be able to wipe it away with a cotton swab (if the mistake was
    small, or the color was faint)"): pressed at `c`, its tip takes up `take` of the fresh paint under it, as much as it bears there - what
    was under the spill (`under_pre`, `under_alp`: the whole canvas before it) showing again - in a soft, slightly ragged round print."""
    sl = box(np.array([c]), r + 1.0, cv.h, cv.w)
    if sl is None:
        return None
    X, Y = grid(sl)
    d = np.hypot(X - c[0], Y - c[1])
    edge = r + (fbm(X / 1.2 + seed * 0.37, Y / 1.2, seed) - 0.5) * 0.6
    prof = np.clip((edge - d) / 0.6 + 0.5, 0, 1) * take
    pre = cv.pre[sl] + (under_pre[sl] - cv.pre[sl]) * prof[..., None]
    alp = cv.alp[sl] + (under_alp[sl] - cv.alp[sl]) * prof
    return Mark("blot", tool, sl, pre, alp, np.array([c]), 0.0, 1, "", {"c": list(c), "r": r, "press": 1.0, "load": 1.0, "corner": False})


def lift(cv, pts, half_w, take=0.35, tool="bud"):
    return move(cv, pts, half_w, 0, 0, "lift", tool, soft=0.6, take=take)
