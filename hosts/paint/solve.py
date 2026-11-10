"""THE PAINTER of the painting lab (TEST_PLAN.md, "The painter"): every mark chosen by code, in stages, broad to fine.

1. FOUNDATION - the ground paint patted on with the sponge's face, row by row, then a press wherever it is still thin.
2. BROAD COLOR, BROAD TO FINE (Hertzmann, SIGGRAPH 1998): for each brush from the widest, the picture blurred to its scale; on a grid
   as wide as the brush, wherever the canvas is still far from it, a stroke begun at the worst point - in the paint or mix nearest the
   picture there, of the few the layer mixes (each a trip to rinse and load), curving along the picture's contours, pressed to the
   width of what wants it, ending where the canvas is already nearer than the stroke would be.
3. LINES AND SMALL MARKS - the picture's own lines (lines.find), each drawn with the tool whose mark is nearest it for its time.
4. TEXTURE - where the picture is speckled or streaked and the canvas is not: stippling, dry brushing, spattering - whichever helps
   most for its time.
5. MOVING AND LIFTING - feathering across edges sharper on the canvas than in the picture, lifting where the canvas is darker.

EVERY MARK IS WEIGHED BEFORE IT IS LAID (`_gain`): how much nearer the picture it brings what it touches, a point made worse counting
WORSE times; laid only if that clears the stage's least. What it made worse is kept, the miss rate.
"""
import numpy as np
from scipy import ndimage

import lines as lines_mod
import marks as mk
from canvas import PX, Canvas
from color import dec, delta, enc, mix, oklab
from tools import TOOLS, Hand

WORSE = 2.5
NOTHING = 0.006      # a mark changing no point of the canvas more than this (its paint, its coverage) changes nothing
MIX_SHARES = (0.1, 0.25, 0.5, 0.75)   # (a tenth: a white made cream, never a quarter's orange)
THICKS = (1.0, 0.6, 0.3)


class Painter:
    def __init__(self, ref, tools=None, seed=1):
        self.ref = ref
        self.cv = Canvas(ref.h, ref.w, ref.bare, ref.face)
        self.hand = Hand()
        self.rng = np.random.default_rng(seed)
        self.tools = tools or [k for k, v in TOOLS.items() if v["table"]]
        self.laid = []          # (Mark, t0, t1) in order
        self.stages = []        # (name, picture after it)
        self.stats = {}         # behavior -> {marks, gain, worse, laid}
        self.paints = dict(ref.paints)
        self._options()
        _, sk = lines_mod.find(ref.srgb, PX, ref.face)
        near = ndimage.binary_dilation(sk, iterations=2)
        _, (iy, ix) = ndimage.distance_transform_edt(near, return_indices=True)
        self.miss_target = ref.lab[iy, ix]

    # --- the palette: paints, mixes, thicknesses -------------------------------------------------------------------------------

    def _options(self):
        names = list(self.paints)
        cols = [self.paints[n] for n in names]
        opts = [(n, c) for n, c in zip(names, cols)]
        labs = [oklab(dec(c)) for c in cols]
        for i in range(len(names)):
            for j in range(i + 1, len(names)):
                # (...NEVER TWO COLORS FROM ACROSS THE WHEEL: a painter does not mix red into teal - it makes mud, and a teal picked as
                # the nearest to a dull teal had come out a grey-brown bruise)
                ci, cj = np.hypot(*labs[i][1:]), np.hypot(*labs[j][1:])
                if ci > 4.0 and cj > 4.0:
                    ang = abs(np.arctan2(labs[i][2], labs[i][1]) - np.arctan2(labs[j][2], labs[j][1]))
                    if min(ang, 2 * np.pi - ang) > np.radians(100):
                        continue
                for t in MIX_SHARES:
                    opts.append(("%s+%s %.2f" % (names[i], names[j], t), mix(cols[i], cols[j], t)))
        self.opt_names = [o[0] for o in opts]
        self.opt_cols = np.array([o[1] for o in opts])

    def _after_point(self, k_rows, k_cols, th):
        """For each option, what canvas points (rows, cols) would show laid at thickness `th`: (n_points, n_opts, 3) OKLab."""
        pre = self.cv.pre[k_rows, k_cols]
        alp = self.cv.alp[k_rows, k_cols]
        a = th * mk.FILM
        p2 = self.opt_cols[None, :, :] * a + pre[:, None, :] * (1 - a)
        a2 = a + alp[:, None] * (1 - a)
        return oklab(Canvas.shown_of(p2, np.broadcast_to(a2, p2.shape[:2]), self.cv.bare_lin))

    def choose_colors(self, rows, cols, target, most=6, thicks=THICKS):
        """THE FEW MIXES A LAYER MAKES: for points (rows, cols) wanting colors `target` (n, 3 OKLab), up to `most` options (paint or
        mix, thickness) chosen greedily to serve them all best; each point's own of those. -> (chosen [(opt, th)], each point's index)."""
        costs = []
        keys = []
        for th in thicks:
            after = self._after_point(rows, cols, th)
            costs.append(delta(after, target[:, None, :]))
            keys += [(o, th) for o in range(len(self.opt_names))]
        C = np.concatenate(costs, axis=1)
        chosen = []
        best = np.full(len(rows), np.inf)
        for _ in range(most):
            tot = np.minimum(C, best[:, None]).sum(axis=0)
            j = int(np.argmin(tot))
            if chosen and best.sum() - tot[j] < 0.5 * len(rows):
                break
            chosen.append(j)
            best = np.minimum(best, C[:, j])
        which = np.argmin(C[:, chosen], axis=1)
        return [keys[j] for j in chosen], which

    # --- weighing and laying ----------------------------------------------------------------------------------------------------

    def _gain(self, m, target):
        before = delta(self.cv.lab(m.sl), target[m.sl])
        after = delta(oklab(Canvas.shown_of(m.pre, m.alp, self.cv.bare_lin)), target[m.sl])
        d = (before - after) * self.ref.face[m.sl]
        changed = np.abs(m.alp - self.cv.alp[m.sl]) + np.abs(m.pre - self.cv.pre[m.sl]).sum(axis=-1)
        worse = float((changed * (d < -0.5)).sum())
        return float(np.where(d > 0, d, d * WORSE).sum()) / (PX * PX), worse / (PX * PX), float(changed.sum()) / (PX * PX)

    def _gain_soft(self, m, target, sigma):
        """`_gain`, the canvas and `target` both softened by `sigma` pixels: a line a fraction of a pixel off its place in the picture is
        still on it to an eye, never a miss twice over."""
        sl = m.sl
        pad = int(3 * sigma) + 1
        big = (slice(max(sl[0].start - pad, 0), min(sl[0].stop + pad, self.cv.h)), slice(max(sl[1].start - pad, 0), min(sl[1].stop + pad, self.cv.w)))
        oy, ox = sl[0].start - big[0].start, sl[1].start - big[1].start
        pre_b, alp_b = self.cv.pre[big].copy(), self.cv.alp[big].copy()
        before = self.cv.shown(big)
        pre_b[oy:oy + m.pre.shape[0], ox:ox + m.pre.shape[1]] = m.pre
        alp_b[oy:oy + m.alp.shape[0], ox:ox + m.alp.shape[1]] = m.alp
        after = Canvas.shown_of(pre_b, alp_b, self.cv.bare_lin)
        soft = lambda im: np.stack([ndimage.gaussian_filter(im[..., c], sigma) for c in range(3)], -1)
        t = target[big]
        d = (delta(oklab(soft(before)), t) - delta(oklab(soft(after)), t)) * self.ref.face[big]
        return float(np.where(d > 0, d, d * WORSE).sum()) / (PX * PX)

    def try_lay(self, m, target, least, start=None, paint=None, soft=0.0):
        """Mark `m` weighed against `target` and laid if it brings it at least `least` (mm^2 x OKLab) nearer; the hand's time spent."""
        if m is None:
            return False
        # WHAT THE HAND KEEPS ITS MARKS OUT OF (`keep_out`, a mask of the canvas, while set): a careful edge, cut in - the mark's paint
        # stops at it (feedback 0005: a spill's cleanup reached into the eye it spilled from and lightened its makeup)
        keep = getattr(self, "keep_out", None)
        if keep is not None and keep[m.sl].any():
            k = keep[m.sl]
            m.pre = np.where(k[..., None], self.cv.pre[m.sl], m.pre)
            m.alp = np.where(k, self.cv.alp[m.sl], m.alp)
        # A MARK THAT CHANGES NOTHING IS NEVER MADE (feedback 0020: a fat brush's pulls run over the white, moving nothing - time spent and a
        # tool seen working for nothing)
        if np.abs(m.pre - self.cv.pre[m.sl]).max() < NOTHING and np.abs(m.alp - self.cv.alp[m.sl]).max() < NOTHING:
            return False
        g, worse, changed = self._gain(m, target)
        if soft > 0:
            g = self._gain_soft(m, target, soft)
        if g < least:
            return False
        # (...its misses judged against the picture itself, whatever the stage aimed at - its fine lines left out, which are drawn last
        # over whatever is under them)
        _, worse_ref, _ = self._gain(m, self.miss_target)
        t0, t1 = self.hand.mark(m.kind, start if start is not None else m.pts[0], m.length, m.presses)
        # (...and time spent on a mark that brought the picture no nearer kept as wasted - judged softly, as an eye judges a line)
        g_ref = self._gain_soft(m, self.ref.lab, PX * 0.3)
        if g_ref <= 0.0:
            self.wasted = getattr(self, "wasted", 0.0) + (t1 - t0)
            self.wasted_n = getattr(self, "wasted_n", 0) + 1
            wb = getattr(self, "wasted_by", {})
            k = getattr(self, "layer_name", m.kind)
            wb[k] = (wb.get(k, (0, 0.0))[0] + 1, wb.get(k, (0, 0.0))[1] + (t1 - t0))
            self.wasted_by = wb
        self.cv.lay(m.sl, m.pre, m.alp, t1)
        self.laid.append((m, t0, t1))
        st = self.stats.setdefault(m.kind, {"marks": 0, "gain": 0.0, "worse": 0.0, "laid": 0.0, "tool": m.tool})
        st["marks"] += 1
        st["gain"] += g
        st["worse"] += worse_ref
        st["laid"] += changed
        return True

    def stage_done(self, name):
        self.stages.append((name, enc(self.cv.shown()), self.hand.t))

    # --- 1. foundation ----------------------------------------------------------------------------------------------------------

    def foundation(self):
        """THE GROUND: the paint nearest the whole picture, patted on row by row, then pressed again wherever it is still thin."""
        face = self.ref.face
        # (...THE GROUND IS THE FACE'S LARGEST AREA'S PAINT, never the paint nearest it all on average: on a white face half rusted that
        # had been the rust, the whole face brown)
        if not hasattr(self, "labels"):
            self.plan_regions()
        vals, counts = np.unique(self.labels[self.labels >= 0], return_counts=True)
        o = int(vals[np.argmax(counts)])
        ground = self.opt_names[o]
        self.paints.setdefault(ground, self.opt_cols[o])
        self.ground = ground
        col = self.opt_cols[o]
        self.hand.take("sponge")
        self.hand.need(ground)
        r = TOOLS["sponge"]["mm"] * 0.5 * 0.8
        step = r * 1.25
        ys = np.arange(r * 0.6, self.ref.frame[1], step * 0.866)
        target = self.ref.lab
        for row, y in enumerate(ys):
            xs = np.arange(r * 0.6 + (step * 0.5 if row % 2 else 0), self.ref.frame[0], step)
            if row % 2:
                xs = xs[::-1]
            for x in xs:
                c = np.array([x, y]) + self.rng.normal(0, r * 0.08, 2)
                if not self._near_face(c, r * 0.7):
                    continue
                m = mk.sponge_print(self.cv, c, r, col, ground, self.hand.load, 1.0, False, int(self.rng.integers(1 << 30)))
                self._force(m, c)
        # (...pressed again wherever it is still thin - the corner for a small gap)
        for _ in range(4):
            # (...judged over a millimeter and a half, as an eye does: a sponge's pores are its texture, not gaps to press again; and
            # cell by cell - the gaps between presses join into one net, whose middle is one place)
            thin = face & (ndimage.gaussian_filter(self.cv.alp, PX * 0.75) < self.THIN)
            g = int(r * PX)
            cents, sizes = [], []
            for y0 in range(0, self.ref.h, g):
                for x0 in range(0, self.ref.w, g):
                    cell = thin[y0:y0 + g, x0:x0 + g]
                    n = int(cell.sum())
                    if n >= (self.GAP_LEAST * PX) ** 2:
                        yy, xx = np.nonzero(cell)
                        cents.append((y0 + yy.mean(), x0 + xx.mean()))
                        sizes.append(n)
            if not cents:
                break
            order = self._tour([np.array([c[1], c[0]]) / PX for c in cents])
            for i in order:
                c = np.array([cents[i][1], cents[i][0]]) / PX
                corner = sizes[i] < (r * PX * 0.6) ** 2
                m = mk.sponge_print(self.cv, c, r, col, ground, self.hand.load, 1.0, corner, int(self.rng.integers(1 << 30)),
                                    kind="pat")
                self._force(m, c)
        self.stage_done("foundation")

    THIN = 0.85              # a foundation this thin (over 1.5 mm) is pressed again...
    GAP_LEAST = 1.5          # ...where the thin place is at least this wide (mm)

    def _force(self, m, c):
        if m is None:
            return
        t0, t1 = self.hand.mark(m.kind, c, 0, 1)
        _, worse, changed = self._gain(m, self.miss_target)
        self.cv.lay(m.sl, m.pre, m.alp, t1)
        self.laid.append((m, t0, t1))
        # (...a foundation goes everywhere - under the eyes and lips too: none of it is a miss)
        st = self.stats.setdefault(m.kind, {"marks": 0, "gain": 0.0, "worse": 0.0, "laid": 0.0, "tool": m.tool, "ground": True})
        st["marks"] += 1

    def _near_face(self, c, r):
        x, y = int(c[0] * PX), int(c[1] * PX)
        rp = int(r * PX)
        sl = np.s_[max(y - rp, 0):y + rp + 1, max(x - rp, 0):x + rp + 1]
        return bool(self.ref.face[sl].any())

    def _tour(self, pts):
        """A hand's order through points `pts`: each next the nearest to the last, from the hand's own place."""
        if not pts:
            return []
        left = list(range(len(pts)))
        at = self.hand.at if self.hand.at is not None else pts[0]
        out = []
        while left:
            j = min(left, key=lambda i: (pts[i][0] - at[0]) ** 2 + (pts[i][1] - at[1]) ** 2)
            out.append(j)
            left.remove(j)
            at = pts[j]
        return out

    # --- 2. broad color ---------------------------------------------------------------------------------------------------------

    # Each pass: its scale (mm: the picture blurred to it, the grid of places it works), how far off a place must be to be worked,
    # the most of the painting's time it may take (seconds), and the marks it may try there - (behavior, tool, half width or radius mm)
    PASSES = (
        (6.0, 7.0, 260.0, (("sweep", "flat", 5.0), ("glaze", "flat", 5.0), ("stipple", "sponge", 15.0))),
        (3.0, 8.0, 260.0, (("sweep", "round", 3.0), ("glaze", "round", 3.0), ("stipple", "sponge", 10.0), ("dab", "round", 3.0))),
        (1.5, 9.0, 200.0, (("sweep", "round", 1.5), ("dab", "round", 1.6))),
    )
    NEAR = 25.0              # mm: a place this far from the hand counts half as much (the next near the last)
    COLORS_TRIED = 3         # the paints or mixes nearest the picture at a place, tried there (and whatever is on the tool)
    STROKE_LEAST = 3.0       # a mark laid only if it brings its blurred picture this much nearer (mm^2 x OKLab)
    MAX_STEPS = 8
    MIN_STEPS = 1
    CURVE = 0.35             # how much of a turn a stroke takes each step (Hertzmann's curvature filter): a little, never a swirl

    def broad(self, passes=None):
        for R, off, secs, tries in (passes or self.PASSES):
            tries = tuple(t for t in tries if t[1] in self.tools)
            if tries:
                self._pass(R, off, secs, tries)
        self.stage_done("broad color")

    def _blurred(self, R):
        sig = R * PX * 0.5
        lin = dec(self.ref.srgb)
        b = np.stack([ndimage.gaussian_filter(lin[..., c], sig) for c in range(3)], axis=-1)
        return oklab(b)

    def _nearest_options(self, y, x, target_lab, n, thicks=THICKS):
        """The `n` (paint or mix, thickness) nearest `target_lab` laid over the canvas at (y, x)."""
        keys, costs = [], []
        for th in thicks:
            after = self._after_point(np.array([y]), np.array([x]), th)[0]
            costs.append(delta(after, target_lab))
            keys += [(o, th) for o in range(len(self.opt_names))]
        c = np.concatenate(costs)
        return [keys[j] for j in np.argsort(c)[:n]]

    def _pass(self, R, off, secs, tries):
        """ONE PASS, BROAD TO FINE (Hertzmann's layer, each mark measured): the place furthest off the picture blurred to `R` - the next
        near the last - and there each mark of `tries` in each of the few paints nearest it; the one that brings it nearest for its time
        (a swap, a rinse and a load counted) laid. Until nothing is `off` enough, or its `secs` are spent."""
        target = self._blurred(R)
        gy = ndimage.sobel(target[..., 0], 0)
        gx = ndimage.sobel(target[..., 0], 1)
        face = self.ref.face
        D = delta(self.cv.lab(), target) * face
        g = max(int(R * PX), 2)
        ch, cw = (self.ref.h + g - 1) // g, (self.ref.w + g - 1) // g
        cell_mean = np.zeros((ch, cw))
        cell_face = np.zeros((ch, cw), bool)

        def recell(r0, r1, c0, c1):
            for cy in range(max(r0 // g, 0), min((r1 - 1) // g + 1, ch)):
                for cx in range(max(c0 // g, 0), min((c1 - 1) // g + 1, cw)):
                    blk = D[cy * g:(cy + 1) * g, cx * g:(cx + 1) * g]
                    cell_face[cy, cx] = face[cy * g:(cy + 1) * g, cx * g:(cx + 1) * g].any()
                    cell_mean[cy, cx] = blk.mean()

        recell(0, self.ref.h, 0, self.ref.w)
        tried = np.zeros((ch, cw), bool)
        t_end = self.hand.t + secs
        cyy, cxx = np.mgrid[0:ch, 0:cw]
        centers = np.stack([(cxx + 0.5) * g / PX, (cyy + 0.5) * g / PX], axis=-1)
        while self.hand.t < t_end:
            ok = cell_face & ~tried & (cell_mean >= off)
            if not ok.any():
                break
            score = np.where(ok, cell_mean, -1.0)
            if self.hand.at is not None:
                dist = np.linalg.norm(centers - self.hand.at, axis=-1)
                score = np.where(ok, cell_mean / (1 + dist / self.NEAR), -1.0)
            cy, cx = np.unravel_index(np.argmax(score), score.shape)
            blk = D[cy * g:(cy + 1) * g, cx * g:(cx + 1) * g]
            k = np.unravel_index(np.argmax(blk), blk.shape)
            y, x = cy * g + k[0], cx * g + k[1]
            p0 = np.array([x + 0.5, y + 0.5]) / PX
            opts = self._nearest_options(y, x, target[y, x], self.COLORS_TRIED)
            best = None
            path_cache = {}
            for kind, tool, size in tries:
                held = [(self.opt_names.index(self.hand.paint), 1.0)] if self.hand.paint in self.opt_names else []
                for opt, th in opts + held:
                    if kind == "glaze":
                        th = min(th, 0.35)
                    elif kind == "sweep" and th < 0.5:
                        continue
                    col = self.opt_cols[opt]
                    name = self.opt_names[opt]
                    seed = int(self.rng.integers(1 << 30))
                    load = self.hand.load if (tool == self.hand.tool and name == self.hand.paint) else 1.0
                    if kind in ("sweep", "glaze"):
                        key = (tool, size)
                        if key not in path_cache:
                            path = self._path(p0, oklab(dec(col)), size, target, gx, gy)
                            path_cache[key] = (path, self._widths(path, col, th, size, size, target))
                        path, hw = path_cache[key]
                        m = mk.brush_stroke(self.cv, path, hw, col, name, th, load, kind, tool,
                                            belly=0.75 if kind == "glaze" else mk.BELLY, seed=seed)
                        secs_m = 0.45 + m.length / (14.0 if kind == "sweep" else 16.0) if m else 1.0
                    elif kind == "stipple":
                        m = mk.sponge_print(self.cv, p0, size / 0.38, col, name, min(load, 0.6) * (th / 1.0), 0.5, True, seed, "stipple")
                        secs_m = 0.3
                    else:
                        m = mk.dab(self.cv, p0, size, col, name, 0.7, th, tool, seed)
                        secs_m = 0.45
                    if m is None:
                        continue
                    gain, _, _ = self._gain(m, target)
                    per = gain / (secs_m + 0.35 + self.hand.cost(tool, name))
                    if best is None or per > best[0]:
                        best = (per, gain, m, tool, name)
            if best is None or best[1] < self.STROKE_LEAST:
                tried[cy, cx] = True
                continue
            _, gain, m, tool, name = best
            self.hand.take(tool)
            self.hand.need(name)
            self.try_lay(m, target, -1e9, p0)
            sl = m.sl
            D[sl] = delta(self.cv.lab(sl), target[sl]) * face[sl]
            recell(sl[0].start, sl[0].stop, sl[1].start, sl[1].stop)
            tried[max(sl[0].start // g, 0):min((sl[0].stop - 1) // g + 1, ch), max(sl[1].start // g, 0):min((sl[1].stop - 1) // g + 1, cw)] = False

    def _path(self, p0, col_lab, R, target, gx, gy):
        pts = [p0]
        prev = None
        for k in range(self.MAX_STEPS):
            p = pts[-1]
            x, y = int(p[0] * PX), int(p[1] * PX)
            if not (0 <= x < self.ref.w and 0 <= y < self.ref.h) or not self.ref.face[y, x]:
                pts.pop()
                break
            if k >= self.MIN_STEPS:
                t = target[y, x]
                if delta(t, self.cv.lab(np.s_[y:y + 1, x:x + 1])[0, 0]) < delta(t, col_lab):
                    break
            gv = np.array([gx[y, x], gy[y, x]])
            if np.linalg.norm(gv) < 1e-3:
                d = prev if prev is not None else np.array([1.0, 0.3]) / np.hypot(1.0, 0.3)
            else:
                d = np.array([-gv[1], gv[0]]) / np.linalg.norm(gv)
                if prev is not None and d @ prev < 0:
                    d = -d
                if prev is not None:
                    d = self.CURVE * d + (1 - self.CURVE) * prev
                    d /= max(np.linalg.norm(d), 1e-9)
            pts.append(p + d * R)
            prev = d
        if len(pts) < 2:
            pts = [p0, p0 + np.array([R * 0.5, 0.0])]
        return np.array(pts)

    def _widths(self, path, col, th, R, half_most, target):
        """PRESSED TO THE WIDTH OF WHAT WANTS IT: at each point of `path`, as far across it as the stroke's color would bring the picture
        nearer than the canvas is - the nearer side twice over where it lies off center - no wider than the brush, no narrower than its tip."""
        col_lab = oklab(dec(col))
        out = []
        for i, p in enumerate(path):
            a = path[min(i + 1, len(path) - 1)] - path[max(i - 1, 0)]
            if np.linalg.norm(a) < 1e-9:
                out.append(min(R, half_most))
                continue
            n = np.array([-a[1], a[0]]) / np.linalg.norm(a)
            reach = []
            for sgn in (1, -1):
                run = 0.0
                while run < half_most:
                    q = p + n * sgn * (run + 0.25)
                    x, y = int(q[0] * PX), int(q[1] * PX)
                    if not (0 <= x < self.ref.w and 0 <= y < self.ref.h) or not self.ref.face[y, x]:
                        break
                    t = target[y, x]
                    if delta(t, col_lab) >= delta(t, self.cv.lab(np.s_[y:y + 1, x:x + 1])[0, 0]):
                        break
                    run += 0.25
                reach.append(run)
            out.append(float(np.clip(min(sum(reach) * 0.5, min(reach) * 2.0) + 0.25, half_most * mk.TIP_LEAST, half_most)))
        w = np.array(out)
        return np.convolve(np.pad(w, 1, mode="edge"), np.ones(3) / 3, mode="valid")

    # --- 2b. regions: the picture as a painter reads it - areas of one paint, each filled inside its own edge -------------------

    COLORS = 24              # the areas' colors before each is matched to a paint or mix (fewer, fewer trips to rinse and load)
    HUE = np.array([1.0, 3.0, 3.0])   # hue weighed against lightness when the picture is cut into colors (lightness had swamped a lip)
    AREA_LEAST = 1.0         # mm^2: an area smaller is left to the lines and the touch-ups
    SPECK = 6.0              # mm^2: an area smaller is given to what is round it
    RIM = 2.5                # mm: the picture's own rim, given what lies inside it
    SAME_AS_GROUND = 5.0     # an area this near the ground's own color is the foundation's
    FILL_APART = 0.5         # side-by-side strokes this share of their width apart (further, the stripes between them showed)
    SOFT_EDGE = 0.45         # an area whose edge the picture shows this much softer than a cut edge is laid with the sponge...
    SPONGE_AREAS = False     # ...when areas may be (its corner's presses spilled past small ones - the blend softens instead)

    def plan_regions(self, k=None):
        """THE PICTURE CUT INTO AREAS OF ONE COLOR: its fine lines left out (they are drawn last), its colors clustered - hue weighed
        up, the starts spread (k-means++) - each matched to the paint or mix nearest it, and areas of one paint taken as one."""
        k = k or self.COLORS
        ref = self.ref
        _, sk = lines_mod.find(ref.srgb, PX, ref.face)
        near = ndimage.binary_dilation(sk, iterations=2)
        _, (iy, ix) = ndimage.distance_transform_edt(near, return_indices=True)
        lab = oklab(dec(ref.srgb[iy, ix]))
        X = lab[ref.face] * self.HUE
        rng = np.random.default_rng(0)
        sub = X[rng.choice(len(X), min(20000, len(X)), replace=False)]
        C = [sub[rng.integers(len(sub))]]
        for _ in range(k - 1):
            d = np.min(((sub[:, None, :] - np.array(C)[None]) ** 2).sum(-1), axis=1)
            C.append(sub[rng.choice(len(sub), p=d / d.sum())])
        C = np.array(C)
        for _ in range(20):
            lb = np.argmin(((X[:, None, :] - C[None]) ** 2).sum(-1), axis=1)
            for j in range(k):
                if (lb == j).any():
                    C[j] = X[lb == j].mean(0)
        opt_lab = oklab(dec(self.opt_cols))
        snap = np.argmin(((((C / self.HUE)[:, None, :] - opt_lab[None]) * self.HUE) ** 2).sum(-1), axis=1)
        labels = np.full(ref.face.shape, -1)
        labels[ref.face] = snap[lb]
        # (...smoothed by the most common label round each point - a median of labels invents ones that are not there - and its rim
        # given what lies inside it: the picture's own rim is drawn dark, an edge no painter paints)
        inner = ndimage.binary_erosion(ref.face, iterations=int(PX * self.RIM))
        labels[~inner] = -1
        lab2 = _majority(labels, 5, inner)
        _, (iy, ix) = ndimage.distance_transform_edt(lab2 < 0, return_indices=True)
        lab2 = lab2[iy, ix]
        lab2[~ref.face] = -1
        # (...and every speck smaller than a brush's touch given to what is round it: a fleck of the picture is a line's or a texture's,
        # never an area of its own)
        for _ in range(3):
            small = np.zeros(lab2.shape, bool)
            for v in np.unique(lab2):
                if v < 0:
                    continue
                comps, n = ndimage.label(lab2 == v)
                if n == 0:
                    continue
                sizes = ndimage.sum(np.ones(lab2.shape), comps, range(1, n + 1))
                tiny = np.zeros(n + 1, bool)
                tiny[1:] = sizes < self.SPECK * PX * PX
                small |= tiny[comps]
            if not small.any():
                break
            keep = ~small & ref.face
            _, (iy, ix) = ndimage.distance_transform_edt(~keep, return_indices=True)
            lab2 = np.where(small, lab2[iy, ix], lab2)
        self.labels = lab2

    def regions(self):
        """EACH AREA FILLED INSIDE ITS OWN EDGE, the lightest paint first - a thin area with one stroke along its middle pressed to its
        width, a broad one with strokes side by side along its long way, pressed narrower where its edge comes near; the brush chosen
        by how thick the area is; then a press of the tip wherever it is still thin."""
        if not hasattr(self, "labels"):
            self.plan_regions()
        ground_lab = oklab(dec(self.paints[self.ground])) if hasattr(self, "ground") else None
        opts = [o for o in np.unique(self.labels) if o >= 0]
        opts.sort(key=lambda o: -oklab(dec(self.opt_cols[o]))[0])
        target = self.ref.lab
        for o in opts:
            col = self.opt_cols[o]
            if ground_lab is not None and delta(oklab(dec(col)), ground_lab) < self.SAME_AS_GROUND:
                continue
            name = self.opt_names[o]
            comps, n = ndimage.label(self.labels == o)
            if n == 0:
                continue
            boxes = ndimage.find_objects(comps)
            jobs = []
            my_l = oklab(dec(col))[0]
            darker = np.array([oklab(dec(self.opt_cols[q]))[0] < my_l if q >= 0 else False for q in range(len(self.opt_cols))])
            for i, bx in enumerate(boxes):
                M = comps[bx] == i + 1
                if M.sum() < self.AREA_LEAST * PX * PX:
                    continue
                # (...LAID UNDER WHAT IS DARKER INSIDE IT: an area takes in the darker areas it encloses, painted over it after - a
                # gradient laid as a painter lays it, each darker tone over a smaller area, never as rings filled one by one)
                inner = ndimage.binary_fill_holes(M) & ~M
                lab_in = self.labels[bx]
                M = M | (inner & (lab_in >= 0) & darker[np.maximum(lab_in, 0)])
                cy = (bx[0].start + bx[0].stop) / 2 / PX
                cx = (bx[1].start + bx[1].stop) / 2 / PX
                jobs.append((np.array([cx, cy]), bx, M))
            # (...each area with the brush as thick as it is, a paint's areas taken brush by brush, the broadest first: one brush for
            # all of them had filled a broad one with the liner, and a brush changed area by area had cost more than the painting)
            def brush(M):
                th = ndimage.distance_transform_edt(np.pad(M, 1)).max() / PX
                b = "liner" if th <= 1.2 else ("round" if th <= 4.5 else "flat")
                return b if b in self.tools else "round"
            by_tool = {}
            for jb in jobs:
                by_tool.setdefault(brush(jb[2]), []).append(jb)
            for tool in ("flat", "round", "liner"):
                todo = by_tool.get(tool, [])
                for j in self._tour([jb[0] for jb in todo]):
                    _, bx, M = todo[j]
                    self._fill(M, bx, col, name, target, tool)
        self.stage_done("regions")

    SPILL = 0.4              # mm a fill's stroke may reach past its area's edge: what is painted next defines the edge

    def _soft(self, bx, M):
        """How soft the picture is at this area's edge: its change across the edge against a cut edge's."""
        if not hasattr(self, "_sharp_ref"):
            self._sharp_ref = measure_detail(self.ref.lab)
        ring = M & ~ndimage.binary_erosion(M, iterations=2)
        if ring.sum() < 4:
            return False
        sharp = self._sharp_ref[bx][ring].mean()
        return bool(sharp < self.SOFT_EDGE * np.percentile(self._sharp_ref[self.ref.face], 95))

    def _sponge_fill(self, M, bx, col, name, target):
        """A SOFT AREA PRESSED ON WITH THE SPONGE'S CORNER: presses set in a lattice inside it, each its corner's width apart."""
        self.hand.take("sponge")
        self.hand.need(name)
        r = TOOLS["sponge"]["mm"] * 0.5
        rr = r * 0.38
        dt = ndimage.distance_transform_edt(np.pad(M, 1))[1:-1, 1:-1] / PX
        oy, ox = bx[0].start, bx[1].start
        step = rr * 1.1 * PX
        pts = []
        for row, y in enumerate(np.arange(step * 0.4, M.shape[0], step * 0.866)):
            for x in np.arange(step * 0.4 + (step * 0.5 if row % 2 else 0), M.shape[1], step):
                yi, xi = int(y), int(x)
                if yi < M.shape[0] and xi < M.shape[1] and M[yi, xi] and dt[yi, xi] >= rr * 0.3:
                    pts.append(np.array([xi + ox + 0.5, yi + oy + 0.5]) / PX)
        if not pts:
            yy, xx = np.nonzero(M)
            pts = [np.array([xx.mean() + ox, yy.mean() + oy]) / PX]
        for i in self._tour(pts):
            m = mk.sponge_print(self.cv, pts[i], r, col, name, self.hand.load, 0.8, True, int(self.rng.integers(1 << 30)), kind="stipple")
            self.try_lay(m, target, -1e9, pts[i])

    def _fill(self, M, bx, col, name, target, tool, again=2):
        dt = ndimage.distance_transform_edt(np.pad(M, 1))[1:-1, 1:-1] / PX
        thick = float(dt.max())
        hw = TOOLS[tool]["mm"] * 0.5
        self.hand.take(tool)
        self.hand.need(name)
        oy, ox = bx[0].start, bx[1].start
        # (...ALONG ITS CONTOURS, from just inside its edge inward, as a painter cuts in an edge and works in - one long axis had cut a
        # ring or a band across into dashes; a blob's middle line branched out to its ragged edge)
        dtp = dt * PX
        first = min(hw * 0.85, thick * 0.5)
        levels = [first]
        step = 2 * hw * self.FILL_APART
        while levels[-1] + step < thick:
            levels.append(levels[-1] + step)
        for li, d in enumerate(levels):
            S = dtp >= d * PX
            if not S.any():
                continue
            ring = S & ~ndimage.binary_erosion(S)
            sk = lines_mod._thin(ring)
            ls = lines_mod._follow(sk, np.ones(sk.shape), np.zeros(sk.shape + (3,)), np.ones(sk.shape), PX)
            half = min(hw, d + self.SPILL) if li == 0 else hw
            for l in ls:
                for chunk in _chunks(l["pts"], 45.0):
                    if len(chunk) < 2:
                        continue
                    pts = chunk + np.array([ox, oy]) / PX
                    m = mk.brush_stroke(self.cv, pts, max(half, hw * mk.TIP_LEAST), col, name, 1.0, self.hand.load, "sweep", tool,
                                        seed=int(self.rng.integers(1 << 30)))
                    self.try_lay(m, target, -1e9)
        # (...and whatever of it is still bare filled again the same way, until it is covered: a contour too short to follow had left
        # an area's middle bare)
        if again > 0:
            sl = np.s_[bx[0], bx[1]]
            bare = M & (delta(self.cv.lab(sl), oklab(dec(col))[None, None, :]) > 8)
            bare = ndimage.binary_opening(bare)
            if bare.sum() >= (0.8 * PX) ** 2:
                self._fill(bare, bx, col, name, target, tool, again - 1)
        return
        # (...and a press of the tip wherever it is still thin)
        sl = np.s_[bx[0], bx[1]]
        far = (delta(self.cv.lab(sl), oklab(dec(col))[None, None, :]) > 10) & M
        far = ndimage.binary_opening(far, iterations=2)
        lab_f, n = ndimage.label(far)
        if n:
            sizes = ndimage.sum(far, lab_f, range(1, n + 1))
            big = [i + 1 for i in range(n) if sizes[i] >= (1.5 * PX) ** 2]
            cents = ndimage.center_of_mass(far, lab_f, big) if big else []
            rt = TOOLS["round"]["mm"] * 0.5
            for c in cents[:12]:
                p0 = np.array([c[1] + ox + 0.5, c[0] + oy + 0.5]) / PX
                m = mk.dab(self.cv, p0, rt, col, name, 0.3, 1.0, self.hand.tool, int(self.rng.integers(1 << 30)))
                self.try_lay(m, target, 0.0, p0)

    # --- 2c. blending: the edges between areas the picture shows soft ----------------------------------------------------------

    BLEND_REACH = 1.2        # mm: how far a feathering pull moves the paint each way

    def blend(self, half=4.0, soft=0.8):
        """A BLENDING BRUSH PULLED ALONG EVERY EDGE BETWEEN AREAS THAT THE PICTURE SHOWS SOFT (the picture changing there less sharply
        than the paint does): what lies either side taken up and laid across, kept wherever it helps."""
        if not hasattr(self, "labels"):
            self.stage_done("blending")
            return
        lab_img = self.labels
        edge = np.zeros(lab_img.shape, bool)
        edge[:, 1:] |= lab_img[:, 1:] != lab_img[:, :-1]
        edge[1:, :] |= lab_img[1:, :] != lab_img[:-1, :]
        edge &= self.ref.face
        sharp_ref = measure_detail(self.ref.lab)
        sharp_cv = measure_detail(self.cv.lab())
        soft_edge = edge & (sharp_ref < sharp_cv * soft)
        soft_edge = ndimage.binary_dilation(soft_edge, iterations=1)
        sk = lines_mod._thin(soft_edge)
        ls = lines_mod._follow(sk, np.ones(sk.shape) * 2, np.zeros(sk.shape + (3,)), np.ones(sk.shape), PX)
        tool = "blender" if "blender" in self.tools else "round"
        self.hand.take(tool)
        self.hand.need("")
        target = self.ref.lab
        for o in self._tour([l["pts"][0] for l in ls]):
            pts = ls[o]["pts"]
            if np.linalg.norm(np.diff(pts, axis=0), axis=1).sum() < 2.0:
                continue
            # (...a long edge in pulls a hand makes, no longer than 30 mm each)
            for chunk in _chunks(pts, 30.0):
                m = mk.soften(self.cv, chunk, half, self.BLEND_REACH, 0.85, "feather", tool)
                self.try_lay(m, target, 0.0)
        self.stage_done("blending")

    # --- 3. lines and small marks -----------------------------------------------------------------------------------------------

    LINE_COLORS = 4
    LINE_SOFT = 0.3          # mm: a line judged on the picture and the canvas softened this much

    def lines(self, tools=("liner", "pencil", "round")):
        # (...never the picture's own rim: a dark edge drawn round the face, no line a painter draws)
        inside = ndimage.binary_erosion(self.ref.hi[..., 3] > 0.5, iterations=int(self.ref.hi_px * 1.5))
        found, _ = lines_mod.find(self.ref.hi[..., :3], self.ref.hi_px, inside)
        if not found:
            self.stage_done("lines")
            return
        # (...judged on the picture softened by a third of a millimeter, as an eye sees a line - LINE_SOFT)
        lin = dec(self.ref.srgb)
        target = oklab(np.stack([ndimage.gaussian_filter(lin[..., c], self.LINE_SOFT * PX) for c in range(3)], -1))
        # (...each line's color: the mix nearest its own color over the canvas where it runs, of the few the lines are drawn in)
        mids = [l["pts"][len(l["pts"]) // 2] for l in found]
        rows = np.array([min(int(p[1] * PX), self.ref.h - 1) for p in mids])
        cols = np.array([min(int(p[0] * PX), self.ref.w - 1) for p in mids])
        chosen, which = self.choose_colors(rows, cols, np.array([l["lab"] for l in found]), self.LINE_COLORS, thicks=(1.0, 0.6))
        usable = [t for t in tools if t in self.tools]
        for j, (opt, th) in enumerate(chosen):
            col = self.opt_cols[opt]
            idx = np.nonzero(which == j)[0]
            if len(idx) == 0:
                continue
            for tool in usable:
                self.hand.take(tool)
                self.hand.need(self.opt_names[opt])
                half_most = TOOLS[tool]["mm"] * 0.5
                left = []
                for o in self._tour([found[i]["pts"][0] for i in idx]):
                    l = found[idx[o]]
                    hw = np.clip(l["half"], half_most * mk.TIP_LEAST, half_most)
                    seed = int(self.rng.integers(1 << 30))
                    if tool == "pencil":
                        m = mk.pencil(self.cv, l["pts"], float(np.median(hw)), 0.9, col, self.opt_names[opt], seed)
                    elif len(l["pts"]) >= 3 and l["half"][0] > l["half"][-1] * 1.8:
                        m = mk.flick(self.cv, l["pts"], hw, col, self.opt_names[opt], th, self.hand.load, tool, seed)
                    else:
                        m = mk.line(self.cv, l["pts"], hw, col, self.opt_names[opt], th, self.hand.load, "line", tool, seed)
                    if not self.try_lay(m, target, 0.0, soft=self.LINE_SOFT * PX):
                        left.append(idx[o])
                idx = np.array(left, dtype=int)
                if len(idx) == 0:
                    break
        self.stage_done("lines")

    # --- 4. texture -------------------------------------------------------------------------------------------------------------

    def texture(self, cell=4.0, least_detail=4.0):
        """WHERE THE PICTURE IS SPECKLED OR STREAKED AND THE CANVAS IS NOT: each behavior that makes texture tried there, the one that
        helps most for its time laid."""
        target = self.ref.lab
        detail = ndimage.gaussian_filter(np.abs(target[..., 0] - ndimage.gaussian_filter(target[..., 0], PX * 0.6)), PX * 1.0)
        mine = ndimage.gaussian_filter(np.abs(self.cv.lab()[..., 0] - ndimage.gaussian_filter(self.cv.lab()[..., 0], PX * 0.6)), PX * 1.0)
        want = (detail - mine) * self.ref.face
        g = int(cell * PX)
        cells = []
        for y0 in range(0, self.ref.h, g):
            for x0 in range(0, self.ref.w, g):
                if want[y0:y0 + g, x0:x0 + g].mean() > least_detail:
                    cells.append((y0 + g // 2, x0 + g // 2))
        if not cells:
            self.stage_done("texture")
            return
        rows = np.array([c[0] for c in cells])
        cols = np.array([c[1] for c in cells])
        # (...in the color the picture's texture there is made of: its points furthest from the canvas)
        tcol = []
        for y, x in cells:
            sl = np.s_[max(y - g // 2, 0):y + g // 2, max(x - g // 2, 0):x + g // 2]
            d = delta(self.cv.lab(sl), target[sl]).ravel()
            tl = target[sl].reshape(-1, 3)
            tcol.append(tl[np.argsort(d)[-max(len(d) // 5, 1):]].mean(axis=0))
        chosen, which = self.choose_colors(rows, cols, np.array(tcol), 4, thicks=(1.0, 0.6))
        for j, (opt, th) in enumerate(chosen):
            col = self.opt_cols[opt]
            name = self.opt_names[opt]
            idx = np.nonzero(which == j)[0]
            for o in self._tour([np.array([cols[i] + 0.5, rows[i] + 0.5]) / PX for i in idx]):
                i = idx[o]
                c = np.array([cols[i] + 0.5, rows[i] + 0.5]) / PX
                best = None
                for kind in ("stipple", "dry_brush", "spatter"):
                    tool = {"stipple": "sponge", "dry_brush": "flat", "spatter": "round"}[kind]
                    if tool not in self.tools:
                        continue
                    seed = int(self.rng.integers(1 << 30))
                    if kind == "stipple":
                        m = mk.sponge_print(self.cv, c, TOOLS["sponge"]["mm"] * 0.5, col, name, 0.5, 0.6, True, seed, kind="stipple")
                        secs = 0.5
                    elif kind == "dry_brush":
                        gy = ndimage.sobel(target[..., 0], 0)[rows[i], cols[i]]
                        gx = ndimage.sobel(target[..., 0], 1)[rows[i], cols[i]]
                        d = np.array([-gy, gx]) if abs(gx) + abs(gy) > 1e-3 else np.array([1.0, 0.0])
                        d = d / np.linalg.norm(d)
                        m = mk.dry_brush(self.cv, np.array([c - d * cell, c + d * cell]), TOOLS["flat"]["mm"] * 0.4, col, name, 0.5, th,
                                         "flat", seed)
                        secs = 1.0
                    else:
                        m = mk.spatter(self.cv, c, np.array([1.0, 0.4]), cell * 0.5, col, name, self.rng, 40, "round")
                        secs = 1.2
                    if m is None:
                        continue
                    gain, _, _ = self._gain(m, target)
                    if best is None or gain / secs > best[0]:
                        best = (gain / secs, m, tool, gain)
                if best and best[3] > 1.0:
                    self.hand.take(best[2])
                    self.hand.need(name)
                    self.try_lay(best[1], target, 1.0, c)
        self.stage_done("texture")

    # --- 5. moving and lifting --------------------------------------------------------------------------------------------------

    def moves(self, edge=6.0, tries=400):
        """EDGES SHARPER ON THE CANVAS THAN IN THE PICTURE feathered (or smudged, whichever helps more); WHERE THE CANVAS IS DARKER THAN
        THE PICTURE, paint lifted off."""
        target = self.ref.lab
        face = self.ref.face

        def sharp(lab):
            return sum(ndimage.sobel(lab[..., c], 0) ** 2 + ndimage.sobel(lab[..., c], 1) ** 2 for c in range(3)) ** 0.5

        excess = (sharp(self.cv.lab()) - sharp(target)) * face
        done = 0
        tool = "round" if "round" in self.tools else self.tools[0]
        self.hand.take(tool)
        self.hand.need("")
        g = int(3.0 * PX)
        cells = []
        for y0 in range(0, self.ref.h, g):
            for x0 in range(0, self.ref.w, g):
                cell = excess[y0:y0 + g, x0:x0 + g]
                if cell.max() > edge * 8:
                    k = np.unravel_index(np.argmax(cell), cell.shape)
                    cells.append((y0 + k[0], x0 + k[1]))
        pts = [np.array([x + 0.5, y + 0.5]) / PX for y, x in cells]
        lab = self.cv.lab()
        gy = ndimage.sobel(lab[..., 0], 0)
        gx = ndimage.sobel(lab[..., 0], 1)
        for o in self._tour(pts)[:tries]:
            y, x = cells[o]
            c = pts[o]
            d = np.array([gx[y, x], gy[y, x]])
            if np.linalg.norm(d) < 1e-3:
                continue
            d = d / np.linalg.norm(d)
            best = None
            for kind, fn in (("feather", lambda p: mk.feather(self.cv, p, 1.2, tool)), ("smudge", lambda p: mk.smudge(self.cv, p, 2.0, "finger"))):
                if kind == "smudge" and "finger" not in self.tools:
                    continue
                for sgn in (1, -1):
                    m = fn(np.array([c - d * sgn * 2.0, c + d * sgn * 2.0]))
                    if m is None:
                        continue
                    gain, _, _ = self._gain(m, target)
                    if best is None or gain > best[0]:
                        best = (gain, m)
            if best and best[0] > 0.8:
                if best[1].tool != self.hand.tool:
                    self.hand.take(best[1].tool)
                    self.hand.need("")
                if self.try_lay(best[1], target, 0.8, c):
                    done += 1
        self.stage_done("moves")
        return done


def measure_detail(lab):
    g = sum(ndimage.sobel(lab[..., c], 0) ** 2 + ndimage.sobel(lab[..., c], 1) ** 2 for c in range(3)) ** 0.5
    return ndimage.gaussian_filter(g, PX * 0.5)


def _chunks(pts, most):
    """Path `pts` cut into runs no longer than `most` mm."""
    out, cur, run = [], [pts[0]], 0.0
    for a, b in zip(pts[:-1], pts[1:]):
        run += float(np.linalg.norm(b - a))
        cur.append(b)
        if run >= most:
            out.append(np.array(cur))
            cur, run = [b], 0.0
    if len(cur) >= 2:
        out.append(np.array(cur))
    return out


def _majority(labels, size, where):
    """Each point of `labels` given the label most common within `size` pixels round it (inside `where`); -1 outside."""
    ids = [v for v in np.unique(labels) if v >= 0]
    best = np.full(labels.shape, -1)
    best_n = np.zeros(labels.shape)
    for v in ids:
        n = ndimage.uniform_filter((labels == v).astype(float), size)
        better = n > best_n
        best[better] = v
        best_n[better] = n[better]
    best[~where] = -1
    return best
