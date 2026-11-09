"""The picture's own lines, found and followed as a hand would draw them (TEST_PLAN.md, stage 3; the engine's
PaintLayers._trace_lines, the same steps).

WHERE A LINE IS: where the picture stands apart from what is round it (`ROUND`, a blur) by at least `STRONG`, followed on where it
fades to `WEAK` as long as it runs on from where it was clear (hysteresis - a crackle's faint stretches had broken it into dashes);
its dotted gaps bridged by a pixel's growth; and only where it is narrow - deeper in than `WIDEST` is an area, not a line.

FOLLOWED AS A HAND DRAWS: thinned to a pixel (Zhang and Suen), followed from each end first, on through where lines meet the straightest
way, joined to what is drawn already at either end - split at every meeting, a crackle had come out a scatter of dashes. Each line
carries its width point by point (how far each point lies inside it) and its color (the picture where it is most a line).
"""
import numpy as np
from scipy import ndimage

from color import dec, delta, oklab

ROUND = 1.2       # mm: what is round a point, a blur this wide
STRONG = 14.0     # OKLab x100 apart from what is round it: clearly a line
WEAK = 6.0        # ...and followed on while it stays this far apart
WIDEST = 1.6      # mm each side of its middle: deeper in, an area
SHORTEST = 1.0    # mm: none shorter
KEEP = 0.12       # mm: kept to its turns within this


def _thin(img):
    """Zhang and Suen's thinning: a mask (bool) worn down to lines a pixel wide."""
    img = img.copy().astype(np.uint8)
    while True:
        changed = False
        for sub in (0, 1):
            p = np.pad(img, 1)
            P2, P3, P4, P5 = p[:-2, 1:-1], p[:-2, 2:], p[1:-1, 2:], p[2:, 2:]
            P6, P7, P8, P9 = p[2:, 1:-1], p[2:, :-2], p[1:-1, :-2], p[:-2, :-2]
            ns = [P2, P3, P4, P5, P6, P7, P8, P9, P2]
            B = sum(n.astype(int) for n in ns[:8])
            A = sum(((ns[i] == 0) & (ns[i + 1] == 1)).astype(int) for i in range(8))
            if sub == 0:
                c = (P2 * P4 * P6 == 0) & (P4 * P6 * P8 == 0)
            else:
                c = (P2 * P4 * P8 == 0) & (P2 * P6 * P8 == 0)
            rm = (img == 1) & (B >= 2) & (B <= 6) & (A == 1) & c
            if rm.any():
                img[rm] = 0
                changed = True
        if not changed:
            return img.astype(bool)


def find(srgb, px, where=None):
    """THE LINES OF PICTURE `srgb` (h, w, 3), `px` pixels a millimeter, inside `where` (bool) if given: `(lines, mask)` - each line
    `{pts (N, 2) mm, half (N,) mm, lab (3,), strength}`; `mask` the thinned lines (bool), for measuring."""
    lab = oklab(dec(srgb))
    sig = ROUND * px * 0.5
    bg = np.stack([ndimage.gaussian_filter(lab[..., c], sig) for c in range(3)], axis=-1)
    apart = delta(lab, bg)
    ok = np.ones(apart.shape, bool) if where is None else where
    strong = (apart >= STRONG) & ok
    weak = (apart >= WEAK) & ok
    lab_w, n = ndimage.label(weak, structure=np.ones((3, 3)))
    keep = np.zeros(n + 1, bool)
    keep[np.unique(lab_w[strong])] = True
    keep[0] = False
    on = keep[lab_w]
    inside = ndimage.distance_transform_edt(on)
    on = ndimage.binary_dilation(on, structure=np.ones((3, 3))) & ok
    sk = _thin(on)
    sk &= inside <= WIDEST * px
    return _follow(sk, inside, lab, apart, px), sk


def _follow(sk, inside, lab, apart, px):
    h, w = sk.shape
    on = set(zip(*np.nonzero(sk)))
    nbrs = [(-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1)]

    def around(p):
        return [(p[0] + dy, p[1] + dx) for dy, dx in nbrs if (p[0] + dy, p[1] + dx) in on]

    ends = [p for p in on if len(around(p)) == 1]
    seen = set()
    out = []
    for st in ends + sorted(on):
        if st in seen:
            continue
        line = []
        before = [q for q in around(st) if q in seen]
        if before:
            line.append(before[0])
        line.append(st)
        seen.add(st)
        cur = st
        while True:
            back = line[max(len(line) - 4, 0)]
            dv = np.array([cur[0] - back[0], cur[1] - back[1]], float)
            best, nxt = -9.0, None
            for q in around(cur):
                if q in seen:
                    continue
                v = np.array([q[0] - cur[0], q[1] - cur[1]], float)
                sc = v @ dv / (np.linalg.norm(v) * np.linalg.norm(dv)) if np.linalg.norm(dv) > 0 else -abs(v[0] * v[1])
                if sc > best:
                    best, nxt = sc, q
            if nxt is None:
                break
            line.append(nxt)
            seen.add(nxt)
            cur = nxt
        after = [q for q in around(cur) if q in seen and q not in line[-4:]]
        if after:
            line.append(after[0])
        pts = np.array([[c + 0.5, r + 0.5] for r, c in line]) / px
        if len(pts) < 2 or np.linalg.norm(np.diff(pts, axis=0), axis=1).sum() < SHORTEST:
            continue
        rr = np.array([p[0] for p in line])
        cc = np.array([p[1] for p in line])
        half = np.maximum(inside[rr, cc] - 0.5, 0.5) / px
        keep = _kept(pts, 0, len(pts) - 1)
        # (...its color where it is most a line, its strength how far it stands apart)
        a = apart[rr, cc]
        core = np.argsort(a)[-max(len(a) // 3, 1):]
        out.append({"pts": pts[keep], "half": _median_runs(half, keep), "lab": lab[rr[core], cc[core]].mean(axis=0),
                    "strength": float(np.mean(a))})
    return out


def _kept(pts, i0, i1):
    if i1 - i0 < 2:
        return [i0, i1] if i1 > i0 else [i0]
    a, b = pts[i0], pts[i1]
    ab = b - a
    L = np.linalg.norm(ab)
    seg = pts[i0 + 1:i1]
    if L < 1e-9:
        d = np.linalg.norm(seg - a, axis=1)
    else:
        d = np.abs(ab[0] * (seg[:, 1] - a[1]) - ab[1] * (seg[:, 0] - a[0])) / L
    j = int(np.argmax(d))
    if d[j] <= KEEP:
        return [i0, i1]
    at = i0 + 1 + j
    return _kept(pts, i0, at)[:-1] + _kept(pts, at, i1)


def _median_runs(half, keep):
    out = []
    for j, k in enumerate(keep):
        a = keep[max(j - 1, 0)]
        b = keep[min(j + 1, len(keep) - 1)]
        out.append(float(np.median(half[min(a, k):max(b, k) + 1])))
    return np.array(out)
