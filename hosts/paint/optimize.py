"""One layer's strokes, optimized (DiffVG, Li et al. 2020; Stylized Neural Painting, Zou et al. 2021): a layer is a small,
exact target - its region and its step's colors over the canvas as it stands - so its strokes are found by gradient
descent through a soft model of the very strokes the lab lays (marks.brush_stroke: a path, a width at each point, how
thick, how soft its belly), never by rules that fit one element and break the next.

1. Start from the layer painted by numbers: its step's colors gathered into a few paints (layers_paint.paints_for),
   each part's contours a stroke apiece, as wide as the brush that suits the part.
2. Optimize paths, widths, thickness and softness together (Adam, on the GPU), every stroke laid in order over the canvas
   as the show lays paint (pre-multiplied, decoded `pow 2.2`), against the step's picture in OKLab - fine and coarse -
   with paths kept smooth, widths within their brush's, and a little cost on paint so a stroke that earns nothing fades out.
3. Keep what earns its place: a stroke gone thin is dropped; the rest are laid with the real renderer, a layer's parts
   together (`optimize_layer`): the broadest brush first, through its paints lightest first, then the next brush - the
   hand's time counted.
"""
import numpy as np
import torch
from scipy import ndimage

import lines as lines_mod
import marks as mk
from canvas import PX
from color import dec, oklab
from tools import TOOLS

DEV = "cuda" if torch.cuda.is_available() else "cpu"
OPT_SIDE = 240        # the optimized crop's longest side (pixels): finer than that is wasted on broad color
POINTS = 6            # control points a stroke
EDGE = 0.25           # mm, a stroke's outer edge (marks.brush_stroke's)
TOOL_HALF = (("liner", 1.0), ("round", 3.0), ("flat", 5.0), ("blender", 8.0))
# A long thin part's base first: a part no wider than BASE_HALF_MOST (mm, half) and BASE_LONG times longer than it is wide - a
# tear, a streak - is drawn along its middle in the paint most of it is, in pulls up to BASE_PULL mm, and its other colors
# only correct it (painted by numbers it would be many short runs of one brush in one paint, each a rinse, a blot and a dip).
BASE_HALF_MOST = 4.0
BASE_LONG = 4.0
BASE_PULL = 45.0
# A brush in a paint is taken up only for work worth the trip: a run of one brush in one paint worth under GROUP_LEAST seconds
# of painting (each pull a second and its length at PULL_SPEED mm/s - a change of paint costs the show about 14 s, rinsed,
# blotted and dipped) is laid by another run: its paint's run with the most work, in whichever brush, else a run worth its
# trip in a shade no further than MERGE_COLOR_MOST (OKLab x100) - else it stays, a color of its own (merged as far as 25,
# a part loses its minor colors). Then the layer's strokes found again.
GROUP_LEAST = 12.0
PULL_SPEED = 14.0
MERGE_COLOR_MOST = 12.0
# ...and a correction found where error remains is a pull along the place's own length, up to this long (mm).
REFINE_PULL = 30.0
# A mark that shows: a crisp part's stroke laid at least this strong (a soft part's glazes at 0.06) - fainter dabs are the
# brush touching the face and leaving nothing anyone could see.
TH_SHOWS = 0.25

_M1 = torch.tensor([[0.4122214708, 0.5363325363, 0.0514459929], [0.2119034982, 0.6806995451, 0.1073969566],
                    [0.0883024619, 0.2817188376, 0.6299787005]], device=DEV)
_M2 = torch.tensor([[0.2104542553, 0.7936177850, -0.0040720468], [1.9779984951, -2.4285922050, 0.4505937099],
                    [0.0259040371, 0.7827717662, -0.8086757660]], device=DEV)


def t_oklab(lin):
    lms = torch.clamp(lin @ _M1.T, min=1e-6) ** (1.0 / 3.0)
    return (lms @ _M2.T) * 100.0


def tool_for(hw):
    for name, h in TOOL_HALF:
        if hw <= h * 1.05:
            return name, h
    return TOOL_HALF[-1]


class LayerOpt:
    def __init__(self, p, region, target_srgb, names, soft=False, iters=260, log=None):
        self.p = p
        self.names = names
        self.cols = np.array([p._color(n) for n in names])
        self.soft = soft
        self.iters = iters
        self.log = log or (lambda *a: None)
        H, W = region.shape
        ys, xs = np.nonzero(region)
        pad = int(3 * PX)
        y0, y1 = max(ys.min() - pad, 0), min(ys.max() + pad + 1, H)
        x0, x1 = max(xs.min() - pad, 0), min(xs.max() + pad + 1, W)
        self.box = (slice(y0, y1), slice(x0, x1))
        self.origin = np.array([x0, y0]) / PX          # mm
        self.region = region
        self.target = target_srgb
        side = max(y1 - y0, x1 - x0)
        self.k = max(int(np.ceil(side / OPT_SIDE)), 1)  # full pixels an optimized pixel
        self.opx = PX / self.k

    # --- the crop, at the optimizer's resolution -----------------------------------------------------------------------------------

    def _down(self, a):
        a = np.asarray(a, dtype=np.float32)
        h, w = a.shape[:2]
        k = self.k
        hh, ww = h // k * k, w // k * k
        a = a[:hh, :ww]
        if a.ndim == 2:
            return a.reshape(hh // k, k, ww // k, k).mean(axis=(1, 3))
        return a.reshape(hh // k, k, ww // k, k, a.shape[2]).mean(axis=(1, 3))

    def setup(self):
        p, sl = self.p, self.box
        # (...a layer paints only its own region: outside it the target is the canvas as it stands, so a stroke that strays is a
        # cost - judged against the step there, strokes would be laid to match the step's own redrawn shading)
        inside = ndimage.gaussian_filter(ndimage.binary_dilation(self.region[sl], iterations=2).astype(np.float32), 1.0)[..., None]
        tgt = dec(self.target[sl]) * inside + p.cv.shown(sl) * (1 - inside)
        self.T = torch.tensor(self._down(tgt), device=DEV)
        self.T_lab = t_oklab(self.T)
        self.pre0 = torch.tensor(self._down(p.cv.pre[sl]), device=DEV)
        self.alp0 = torch.tensor(self._down(p.cv.alp[sl]), device=DEV)
        self.bare = torch.tensor(p.cv.bare_lin, dtype=torch.float32, device=DEV)
        # (...never judged on the face's own rim: the picture's dark edge there is no paint)
        inner = ndimage.binary_erosion(p.ref.face, iterations=int(2.5 * PX))
        face = self._down(inner[sl].astype(np.float32)) > 0.5
        near = ndimage.binary_dilation(self.region[sl], iterations=int(1.5 * PX))
        wgt = np.where(self._down(near.astype(np.float32)) > 0.5, 1.0, 0.7) * face
        self.Wt = torch.tensor(wgt, dtype=torch.float32, device=DEV)
        h, w = self.T.shape[:2]
        ys = (torch.arange(h, device=DEV, dtype=torch.float32) + 0.5) / self.opx
        xs = (torch.arange(w, device=DEV, dtype=torch.float32) + 0.5) / self.opx
        self.Y, self.X = torch.meshgrid(ys, xs, indexing="ij")

    # --- where the strokes start: the layer painted by numbers ----------------------------------------------------------------------

    def init_strokes(self, most=140):
        from solve import _majority
        from plan import smooth_shape, smooth_path, _is_closed
        from solve import _chunks
        p, sl = self.p, self.box
        reg = self.region[sl]
        lab = oklab(dec(self.target[sl]))
        opt = oklab(dec(self.cols)) * p.HUE
        near = np.argmin(np.linalg.norm(lab[..., None, :] * p.HUE - opt[None, None], axis=-1), axis=-1)
        near = _majority(np.where(reg, near, -1), 7, reg)
        strokes = []
        order = sorted(range(len(self.names)), key=lambda j: -oklab(dec(self.cols[j]))[0])
        # ...a long thin part's base first ([BASE_LONG]): along its middle in the paint most of it is, as wide as it is
        base = []
        based = np.zeros(reg.shape, bool)
        long_parts = np.zeros(reg.shape, bool)
        comps, _ = ndimage.label(reg)
        for q, bx in enumerate(ndimage.find_objects(comps)):
            part = comps[bx] == q + 1
            if part.sum() < (0.7 * PX) ** 2:
                continue
            dt = ndimage.distance_transform_edt(np.pad(part, 1))[1:-1, 1:-1]
            thick = dt.max() / PX
            sk = lines_mod._thin(part)
            if thick > BASE_HALF_MOST or sk.sum() / PX < BASE_LONG * 2.0 * thick:
                continue
            votes = np.bincount(near[bx][part & (near[bx] >= 0)], minlength=len(self.names))
            j0 = int(np.argmax(votes))
            # (...in two paints at most, its base and the next most of it: every other color of it the nearer of those two's -
            # a tear's dry streaks would cut its length into pieces each too short to pull, and dabbed at between)
            two = [j0] + [j for j in np.argsort(-votes) if j != j0 and votes[j] > 0][:1]
            if len(two) == 2:
                sub = near[bx]
                d0 = np.linalg.norm(lab[bx] * p.HUE - opt[two[0]], axis=-1)
                d1 = np.linalg.norm(lab[bx] * p.HUE - opt[two[1]], axis=-1)
                other = part & (sub >= 0) & (sub != two[0]) & (sub != two[1])
                sub[other] = np.where(d0[other] <= d1[other], two[0], two[1])
                near[bx] = sub
            tool, hw = tool_for(max(min(thick, 5.0), 0.6))
            base.extend(self._pulls(sk, dt, bx, thick, j0, tool, hw, base=True))
            based[bx] |= part & (near[bx] == j0)
            long_parts[bx] |= part
        spacing = 0.9
        for attempt in range(4):
            strokes = list(base)
            for j in order:
                sub = smooth_shape(reg & (near == j) & ~based, int(PX * 0.5)) & reg
                comps, n = ndimage.label(sub)
                for q, bx in enumerate(ndimage.find_objects(comps)):
                    part = comps[bx] == q + 1
                    if part.sum() < (0.7 * PX) ** 2:
                        continue
                    dt = ndimage.distance_transform_edt(np.pad(part, 1))[1:-1, 1:-1]
                    thick = dt.max() / PX
                    tool, hw = tool_for(max(min(thick, 5.0), 0.6))
                    # (...a long thin piece of any paint pulled down its middle, as its part's base is)
                    sk = lines_mod._thin(part)
                    if thick <= BASE_HALF_MOST and sk.sum() / PX >= BASE_LONG * 2.0 * thick:
                        strokes.extend(self._pulls(sk, dt, bx, thick, j, tool, hw, base=False))
                        continue
                    d = min(hw * 0.8, thick * 0.5)
                    while d * PX <= dt.max() + 0.5:
                        S = dt >= d * PX
                        ring = S & ~ndimage.binary_erosion(S)
                        ls = lines_mod._follow(lines_mod._thin(ring), np.ones(ring.shape), np.zeros(ring.shape + (3,)), np.ones(ring.shape), PX)
                        for l in ls:
                            path = smooth_path(l["pts"], 1.0, closed=_is_closed(l["pts"]))
                            for ch in _chunks(path, 30.0):
                                if len(ch) < 2:
                                    continue
                                pts = mk.resample(ch, max(np.linalg.norm(np.diff(ch, axis=0), axis=1).sum() / (POINTS - 1), 0.05))[0]
                                if len(pts) < POINTS:
                                    pts = np.array([ch[0] + (ch[-1] - ch[0]) * t for t in np.linspace(0, 1, POINTS)])
                                idx = np.linspace(0, len(pts) - 1, POINTS).round().astype(int)
                                pts = pts[idx] + np.array([bx[1].start, bx[0].start]) / PX + self.origin
                                strokes.append({"pts": pts, "w": np.full(POINTS, hw * 0.8), "th": 0.85 if not self.soft else 0.5,
                                                "soft": 0.4 if not self.soft else 1.2, "paint": j, "hw": hw, "tool": tool})
                        d += hw * spacing * 1.6
            if len(strokes) <= most:
                break
            spacing *= 1.4
        self.strokes = self._ordered(strokes)
        # (...and a long thin part left to its pulls - never dabbed at where error remains, [refine])
        self.long_parts = long_parts
        return len(strokes)

    def _pulls(self, sk, dt, bx, thick, j, tool, hw, base):
        """A long thin piece's pulls (its skeleton `sk`, its distance inside `dt`, in the crop at `bx`): down its middle in paint `j`, as wide
        as it is, BASE_PULL mm at most each ([BASE_LONG])."""
        from plan import smooth_path, _is_closed
        from solve import _chunks
        out = []
        for l in lines_mod._follow(sk, dt, np.zeros(sk.shape + (3,)), np.ones(sk.shape), PX):
            if len(l["pts"]) < 2:
                continue
            path = smooth_path(l["pts"], 1.0, closed=_is_closed(l["pts"]))
            half = float(np.clip(np.median(l["half"]) if len(l["half"]) else thick, 0.3, hw))
            for ch in _chunks(path, BASE_PULL):
                if len(ch) < 2 or np.linalg.norm(np.diff(ch, axis=0), axis=1).sum() < 1.0:
                    continue
                idx = np.linspace(0, len(ch) - 1, POINTS).round().astype(int)
                pts = ch[idx] + np.array([bx[1].start, bx[0].start]) / PX + self.origin
                out.append({"pts": pts, "w": np.full(POINTS, half), "th": 0.9, "soft": 0.4 if not self.soft else 1.2,
                            "paint": j, "hw": hw, "tool": tool, "base": base})
        return out

    # --- the order they are laid in, and judged in --------------------------------------------------------------------------------

    def key_of(self, s):
        """Where stroke `s` is laid in its layer ([optimize_layer] lays every part's in this order, and each part is judged in it): the
        broadest brush first, then the next - as a painter works a layer broad to fine; in each brush the paint its layer's base is
        laid in first ([BASE_LONG]), then the rest lightest first; a base before what corrects it. Its place in its run is its tour's
        ([_ordered])."""
        nm = self.names[s["paint"]]
        return (-s["hw"], 0 if self.base_of_tool.get(s["tool"]) == nm else 1, -float(oklab(dec(self.cols[s["paint"]]))[0]),
                0 if s.get("base") else 1)

    def _ordered(self, strokes):
        """Strokes `strokes` in their layer's order ([key_of]), each run of one brush in one paint toured - the next pull always the one
        nearest where the hand is, by either end - so the hand works a place, then the next, never back and forth across the face."""
        if not hasattr(self, "base_of_tool"):
            self.base_of_tool = base_paints([(strokes, self.names)])
        keyed = sorted(range(len(strokes)), key=lambda n: self.key_of(strokes[n]))
        out, at = [], None
        i = 0
        while i < len(keyed):
            k0 = self.key_of(strokes[keyed[i]])[:3]
            j = i
            while j < len(keyed) and self.key_of(strokes[keyed[j]])[:3] == k0:
                j += 1
            run = [strokes[n] for n in keyed[i:j]]
            # (...its bases first, toured among themselves, then what corrects them)
            for want_base in (True, False):
                left = [s for s in run if bool(s.get("base")) == want_base]
                while left:
                    if at is None:
                        nxt = 0
                    else:
                        nxt = int(np.argmin([min(np.linalg.norm(np.asarray(s["pts"])[0] - at), np.linalg.norm(np.asarray(s["pts"])[-1] - at))
                                             for s in left]))
                    s = left.pop(nxt)
                    pts = np.asarray(s["pts"])
                    if at is not None and np.linalg.norm(pts[-1] - at) < np.linalg.norm(pts[0] - at):
                        s["pts"] = pts[::-1].copy()
                        s["w"] = np.asarray(s["w"])[::-1].copy()
                    at = np.asarray(s["pts"])[-1]
                    out.append(s)
            i = j
        return out

    def sync(self):
        """Each stroke's own fields from what the optimizer found."""
        P = self.P.detach().cpu().numpy()
        Wd = self.widths().detach().cpu().numpy()
        TH = torch.sigmoid(self.th_logit).detach().cpu().numpy()
        SOFT = torch.exp(self.soft_log).detach().cpu().numpy()
        for n, s in enumerate(self.strokes):
            s.update({"pts": P[n], "w": Wd[n], "th": float(TH[n]), "soft": float(SOFT[n])})
        if hasattr(self, "_found"):
            del self._found

    # --- the soft model -------------------------------------------------------------------------------------------------------------

    def _params(self):
        S = self.strokes
        self.P = torch.tensor(np.array([s["pts"] for s in S]), dtype=torch.float32, device=DEV, requires_grad=True)
        hw = np.array([s["hw"] for s in S])
        w = np.clip(np.array([s["w"] for s in S]) / hw[:, None], 0.16, 0.99)
        self.hw = torch.tensor(hw, dtype=torch.float32, device=DEV)
        self.w_logit = torch.tensor(np.log(w / (1 - w)), dtype=torch.float32, device=DEV, requires_grad=True)
        th = np.clip(np.array([s["th"] for s in S]), 0.02, 0.98)
        self.th_logit = torch.tensor(np.log(th / (1 - th)), dtype=torch.float32, device=DEV, requires_grad=True)
        self.soft_log = torch.tensor(np.log(np.array([s["soft"] for s in S])), dtype=torch.float32, device=DEV, requires_grad=True)
        self.C = torch.tensor(self.cols[[s["paint"] for s in S]], dtype=torch.float32, device=DEV)

    def widths(self):
        return self.hw[:, None] * (mk.TIP_LEAST + (1 - mk.TIP_LEAST) * torch.sigmoid(self.w_logit))

    def render(self):
        X = self.X[None] + 0.0
        Y = self.Y[None] + 0.0
        pre = self.pre0.clone()
        alp = self.alp0.clone()
        org = torch.tensor(self.origin, dtype=torch.float32, device=DEV)
        P = self.P - org
        Wd = self.widths()
        TH = torch.sigmoid(self.th_logit)
        SOFT = torch.exp(self.soft_log).clamp(0.6 if self.soft else 0.05, 4.0)
        for n in range(P.shape[0]):
            a = P[n, :-1]
            b = P[n, 1:]
            ab = b - a
            L2 = (ab * ab).sum(-1).clamp(min=1e-6)
            vx = X - a[:, 0, None, None]
            vy = Y - a[:, 1, None, None]
            t = ((vx * ab[:, 0, None, None] + vy * ab[:, 1, None, None]) / L2[:, None, None]).clamp(0, 1)
            dx = vx - t * ab[:, 0, None, None]
            dy = vy - t * ab[:, 1, None, None]
            d2 = dx * dx + dy * dy
            dmin, j = d2.min(0)
            d = torch.sqrt(dmin + 1e-6)
            tj = torch.gather(t, 0, j[None])[0]
            w0 = Wd[n, :-1][j]
            w1 = Wd[n, 1:][j]
            w = w0 + (w1 - w0) * tj
            belly = (SOFT[n] / w).clamp(0.5 if self.soft else 0.05, 0.95)
            core = w * (1 - belly)
            x = ((d - (core - EDGE / 2)) / ((w + EDGE / 2) - (core - EDGE / 2))).clamp(0, 1)
            cov = TH[n] * (1 - x * x * (3 - 2 * x))
            pre = self.C[n] * cov[..., None] + pre * (1 - cov[..., None])
            alp = cov + alp * (1 - cov)
        col = torch.where(alp[..., None] > 1e-4, pre / alp[..., None].clamp(min=1e-4), torch.zeros_like(pre))
        return self.bare * (1 - alp[..., None]) + torch.clamp(col, 0, 1) ** 2.2 * alp[..., None]

    def loss(self, shown):
        lab = t_oklab(shown)
        e = ((lab - self.T_lab) ** 2).sum(-1)
        fine = (e * self.Wt).sum() / self.Wt.sum().clamp(min=1)
        lc = torch.nn.functional.avg_pool2d(lab.permute(2, 0, 1)[None], 4)
        tc = torch.nn.functional.avg_pool2d(self.T_lab.permute(2, 0, 1)[None], 4)
        wc = torch.nn.functional.avg_pool2d(self.Wt[None, None], 4)
        coarse = (((lc - tc) ** 2).sum(1) * wc[0]).sum() / wc.sum().clamp(min=1)
        smooth = ((self.P[:, 2:] - 2 * self.P[:, 1:-1] + self.P[:, :-2]) ** 2).sum(-1).mean()
        paint = torch.sigmoid(self.th_logit).mean()
        return fine + 0.5 * coarse + 2.0 * smooth + 3.0 * paint, fine

    def refine(self, add=12, iters=160):
        """Where error remains, more strokes (e-David's loop, inside one layer): the places still furthest from the step's picture, each a
        short stroke in the paint nearest the picture there, as wide as the place - then all of them optimized again."""
        with torch.no_grad():
            shown = self.render()
            e = (((t_oklab(shown) - self.T_lab) ** 2).sum(-1) * self.Wt).cpu().numpy()
        e = ndimage.gaussian_filter(e, max(1.0, 1.0 * self.opx))
        # (...inside its part alone: past it, where the target is the canvas, a paint can only spill more)
        e = e * (self._down(ndimage.binary_dilation(self.region[self.box], iterations=int(0.5 * PX)).astype(np.float32))[:e.shape[0], :e.shape[1]] > 0.5)
        if getattr(self, "long_parts", None) is not None and self.long_parts.any():
            e = e * (self._down(ndimage.binary_dilation(self.long_parts, iterations=int(PX)).astype(np.float32))[:e.shape[0], :e.shape[1]] < 0.5)
        self.sync()
        tlab = self.T_lab.cpu().numpy()
        opt = oklab(dec(self.cols)) * self.p.HUE
        new = []
        # (...a soft layer's faint differences worth a stroke too - a shading three units off is a shading missed)
        thr = max(float(np.percentile(e[self.Wt.cpu().numpy() > 0.9], 90)) if (self.Wt.cpu().numpy() > 0.9).any() else 0.0,
                  6.0 if self.soft else 25.0)
        for _ in range(add):
            k = np.unravel_index(np.argmax(e), e.shape)
            if e[k] < thr:
                break
            y, x = k
            j = int(np.argmin(np.linalg.norm(opt - tlab[y, x] * self.p.HUE, axis=1)))
            blob = e > e[k] * 0.5
            lbl, _ = ndimage.label(blob)
            part = lbl == lbl[k]
            # (...along the place's own length, as wide as it is across: a long miss beside a tear is one pull down it, not a
            # string of dabs)
            py, px_ = np.nonzero(part)
            c = (np.array([px_.mean(), py.mean()]) + 0.5) / self.opx + self.origin
            if len(py) >= 3:
                ev, evec = np.linalg.eigh(np.cov(np.stack([px_, py]).astype(float)) + np.eye(2) * 0.25)
                d = evec[:, 1]
                long_r = 2.0 * float(np.sqrt(max(ev[1], 0.0))) / self.opx
                r = max(2.0 * float(np.sqrt(max(ev[0], 0.0))) / self.opx, 0.5)
            else:
                d, long_r, r = np.array([1.0, 0.0]), 0.5, 0.5
            tool, hw = tool_for(min(max(r, 0.6), 5.0))
            half = float(np.clip(long_r, hw, REFINE_PULL * 0.5))
            pts = np.array([c + d * half * t for t in np.linspace(-1, 1, POINTS)])
            new.append({"pts": pts, "w": np.full(POINTS, min(r, hw) * 0.9), "th": 0.6, "soft": 0.6 if self.soft else 0.3,
                        "paint": j, "hw": hw, "tool": tool})
            yy0, yy1 = max(y - int(r * self.opx * 1.5) - 1, 0), y + int(r * self.opx * 1.5) + 2
            xx0, xx1 = max(x - int(r * self.opx * 1.5) - 1, 0), x + int(r * self.opx * 1.5) + 2
            e[yy0:yy1, xx0:xx1] = 0
        if not new:
            return 0
        self.strokes = self._ordered(self.strokes + new)
        self.optimize(iters)
        return len(new)

    def optimize(self, iters=None):
        iters = iters or self.iters
        self._params()
        opt = torch.optim.Adam([{"params": [self.P], "lr": 0.25}, {"params": [self.w_logit], "lr": 0.08},
                                {"params": [self.th_logit], "lr": 0.08}, {"params": [self.soft_log], "lr": 0.05}])
        first = last = None
        for it in range(iters):
            opt.zero_grad()
            l, fine = self.loss(self.render())
            l.backward()
            opt.step()
            if first is None:
                first = float(fine.detach())
            last = float(fine.detach())
        self.log("    optimized %d strokes: error %.1f -> %.1f" % (len(self.strokes), first ** 0.5, last ** 0.5))
        return first, last

    # --- laid for real --------------------------------------------------------------------------------------------------------------

    def lay_order(self):
        """Its strokes as they are laid, the faint ones dropped: `[(n, its brush's half width, its paint's name)]`."""
        TH = torch.sigmoid(self.th_logit).detach().cpu().numpy()
        return [(n, s["hw"], self.names[s["paint"]]) for n, s in enumerate(self.strokes) if TH[n] >= self.shows()]

    def shows(self):
        """How strong a stroke of this part is laid at the least ([TH_SHOWS])."""
        return 0.06 if self.soft else TH_SHOWS

    def lay_one(self, n):
        """Stroke `n` laid on the painter's canvas, as the soft model found it. -> whether it was kept."""
        p = self.p
        if not hasattr(self, "_found"):
            self._found = (self.P.detach().cpu().numpy(), self.widths().detach().cpu().numpy(),
                           torch.sigmoid(self.th_logit).detach().cpu().numpy(),
                           torch.exp(self.soft_log).clamp(0.05, 4.0).detach().cpu().numpy())
        P, Wd, TH, SOFT = self._found
        s = self.strokes[n]
        pts = P[n]
        if np.linalg.norm(np.diff(pts, axis=0), axis=1).sum() < 0.3:
            pts = np.vstack([pts[0], pts[0] + np.array([0.3, 0.0])])
            ws = np.full(2, Wd[n].mean())
        else:
            ws = Wd[n]
        belly = float(np.clip(max(SOFT[n], 0.6 if self.soft else 0.05) / max(ws.mean(), 1e-3), 0.5 if self.soft else 0.05, 0.95))
        nm = self.names[s["paint"]]
        p.hand.take(s["tool"])
        p.hand.need(nm)
        m = mk.brush_stroke(p.cv, pts, ws, self.cols[s["paint"]], nm, float(TH[n]), 1.0, "sweep", s["tool"], edge=EDGE, belly=belly,
                            streak=(0.03, 0.15, 0.15), tail=0.0, load_mm=1e9, seed=int(p.rng.integers(1 << 30)))
        return bool(p.try_lay(m, p.ref.lab, -1e9, pts[0]))


def base_paints(parts):
    """Each brush's base paint over a layer's parts (`[(strokes, paint names)]`): the paint its long thin parts' bases are laid in most
    with it ([BASE_LONG]), by their length - none for a brush that lays no base."""
    by = {}
    for strokes, names in parts:
        for s in strokes:
            if s.get("base"):
                k = (s["tool"], names[s["paint"]])
                by[k] = by.get(k, 0.0) + float(np.linalg.norm(np.diff(np.asarray(s["pts"]), axis=0), axis=1).sum())
    out = {}
    for (tool, nm), _ in sorted(by.items(), key=lambda kv: -kv[1]):
        out.setdefault(tool, nm)
    return out


def _pull_time(pts):
    """A pull's time at the hand's pace ([GROUP_LEAST]): a second, and its length at PULL_SPEED."""
    return 1.0 + float(np.linalg.norm(np.diff(np.asarray(pts), axis=0), axis=1).sum()) / PULL_SPEED


def consolidate(p, los, iters):
    """Every run of one brush in one paint worth its trip ([GROUP_LEAST]) over a layer's parts `los`: a run worth less laid by a run already
    taken up - the same paint in the brush nearest its width, else the nearest paint in the same brush (or in any, where the brush lays no
    other) within MERGE_COLOR_MOST - else left a color of its own; the parts changed found again. -> (strokes moved, strokes dropped: none)."""
    halves = dict(TOOL_HALF)
    moved = dropped = 0
    for _ in range(4):
        work = {}
        based = {}
        for lo in los:
            if lo.strokes:
                lo.sync()
            for s in lo.strokes:
                if s["th"] >= lo.shows():
                    k = (s["tool"], lo.names[s["paint"]])
                    work[k] = work.get(k, 0.0) + _pull_time(s["pts"])
                    based[k] = based.get(k, 0.0) + (_pull_time(s["pts"]) if s.get("base") else 0.0)
        # (...a base never: it is what its part is)
        small = {k for k, v in work.items() if v < GROUP_LEAST and based.get(k, 0.0) <= 0.0}
        if not small:
            break
        big = {k: v for k, v in work.items() if k not in small}
        if not big:
            # (...a layer of small runs alone: the one its bases are most of kept - a base is what the part is - else its largest, the
            # rest laid by it)
            top = max(work, key=lambda k: (based.get(k, 0.0), work[k]))
            big = {top: work[top]}
            small.discard(top)
            if not small:
                break
        # (...each paint's own run: the one of its runs a base is most of, else with the most work - every other run of it laid by that one)
        home = {}
        for b in work:
            if b[0] in halves and (b[1] not in home or (based.get(b, 0.0), b in big, work[b]) > (based.get(home[b[1]], 0.0), home[b[1]] in big, work[home[b[1]]])):
                home[b[1]] = b
        changed = []
        for lo in los:
            keep = []
            for s in lo.strokes:
                k = (s["tool"], lo.names[s["paint"]])
                if k not in small or s["th"] < lo.shows():
                    keep.append(s)
                    continue
                to = home.get(k[1]) if home.get(k[1]) not in (None, k) else None
                if to is None:
                    # (...its paint's own run, small: into a shade near it, worth its trip - else it stays, a color of its own)
                    mine = oklab(dec(lo.cols[s["paint"]]))
                    pool = [b for b in big if b[0] == k[0]] or [b for b in big if b[0] in halves]
                    if pool:
                        dist = {b: float(np.linalg.norm(oklab(dec(p._color(b[1]))) - mine)) for b in pool}
                        best = min(dist, key=dist.get)
                        to = best if dist[best] <= MERGE_COLOR_MOST else None
                if to is None:
                    keep.append(s)
                    continue
                if lo not in changed:
                    changed.append(lo)
                if to[1] not in lo.names:
                    lo.names.append(to[1])
                    lo.cols = np.vstack([lo.cols, np.asarray(p._color(to[1]), float)[None]])
                s["paint"] = lo.names.index(to[1])
                if to[0] != s["tool"]:
                    s["tool"], s["hw"] = to[0], halves[to[0]]
                    s["w"] = np.clip(np.asarray(s["w"], float), s["hw"] * mk.TIP_LEAST, s["hw"])
                moved += 1
                keep.append(s)
            lo.strokes = keep
        if not changed:
            break
        base_of = base_paints([(lo.strokes, lo.names) for lo in los])
        for lo in changed:
            lo.base_of_tool = base_of
            lo.strokes = lo._ordered(lo.strokes)
            if lo.strokes:
                lo.optimize(max(iters // 2, 40))
    return moved, dropped


def optimize_layer(p, specs, target_srgb, log=print, iters=260, rounds=1):
    """A layer's broad parts (`specs`: `[(region, paint names, soft)]`) painted toward `target_srgb`: each part's strokes optimized on
    its own, against the canvas as the layer finds it, in the order the layer lays them ([LayerOpt.key_of]: broad to fine, each brush's
    base paint first, then lightest first, each run toured) - every run worth its trip ([consolidate]) - then all of them laid together in
    that order, and each soft part worked over wet after. Words."""
    los = []
    added = 0
    for region, names, soft in specs:
        if not region.any() or not names:
            continue
        lo = LayerOpt(p, region, target_srgb, names, soft, iters, log)
        lo.setup()
        if lo.init_strokes() == 0:
            continue
        los.append(lo)
    if not los:
        return "opt 0"
    # (...each brush's base paint the layer's, over all its parts - so each run is one, whichever part it is in)
    base_of = base_paints([(lo.strokes, lo.names) for lo in los])
    for lo in los:
        lo.base_of_tool = base_of
        lo.strokes = lo._ordered(lo.strokes)
        lo.optimize()
        for _ in range(rounds):
            added += lo.refine()
    moved, dropped_small = consolidate(p, los, iters)
    los = [lo for lo in los if lo.strokes]
    if not los:
        return "opt 0"
    base_of = base_paints([(lo.strokes, lo.names) for lo in los])
    order = []
    for k, lo in enumerate(los):
        lo.base_of_tool = base_of
        for pos, (n, hw, nm) in enumerate(lo.lay_order()):
            order.append((lo.key_of(lo.strokes[n]), k, pos, n))
    order.sort(key=lambda t: (t[0], t[1], t[2]))
    laid = sum(1 for _, k, _, n in order if los[k].lay_one(n))
    dropped = sum(len(lo.strokes) for lo in los) - len(order)
    # (...and a soft part worked over wet with a clean brush, as a painter blends a haze - the strokes' own edges gone into it)
    for lo in los:
        if lo.soft:
            p._feather_area(lo.region & (ndimage.distance_transform_edt(lo.region) > PX * 1.0), 1.5, None, 1)
    return "opt %d parts, %d laid (%d added), %d dropped, %d moved to a run already taken up" % (len(los), laid, added, dropped, moved)
