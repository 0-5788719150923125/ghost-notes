"""A PAINTING'S PLAN, LAYER BY LAYER, carried out with real marks (TEST_PLAN.md; the user, 2026-11-08: "I should paint the entire mask
white is a logical first step, because all other colors can be painted on top of that foundation. And for the eyes, I should paint
them orange, and later paint the inner parts purple").

THE PLAN DECIDES, THE CODE LAYS: a plan is what a painter - an agent - decides from the picture: the base, then each layer in order,
what it is (`how`), in what paint, where. Where is said loosely (`within`: a box or a polygon in millimeters, or all of it) and made
exact from the picture: the points there nearer the layer's colors (`near`) than the others (`versus`), the shape then cleaned - its
edge smoothed (`smooth`), its holes filled, specks dropped - so a round rivet comes out round and a diamond straight-edged. SHAPES AND
LINES EXACT, COLORS AND TEXTURES APPROXIMATE: a texture is a stippled approximation, never copied a fleck at a time.

    {"layers": [{"name", "how": "base"|"fill"|"glaze"|"stipple"|"outline"|"lines"|"dots"|"blend", "paint": a paint, a mix
      ("a+b 0.25") or "auto", "within": "all" | [x0, y0, x1, y1] | [[x, y], ...], "near": [colors], "versus": [colors], "tol",
      "smooth" (mm), "fill_holes", "min_area" (mm^2), "grow" (mm), "density" (stipple), "size" (mm), "width" (mm), "th"}, ...]}

Colors in `near`/`versus` are paint names, #hex, or {"at": [x0, y0, x1, y1]} - the picture's own color in that box: a painter
judges a rust patch against the face's own cream between the patches, never against white. Each layer's marks are timed by the hand (tools.Hand), as every other mark.
"""
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

import lines as lines_mod
import marks as mk
from canvas import PX
from color import dec, delta, hex_rgb, oklab
from solve import Painter, _chunks
from tools import TOOLS


class PlanPainter(Painter):
    def __init__(self, *a, **k):
        super().__init__(*a, **k)
        self._soft_lab = {}
        self.base_col = None
        self._layers_before = []

    def run(self, plan):
        for L in plan["layers"]:
            self._layers_before = getattr(self, "_layers_before", []) + [L]
            how = L["how"]
            getattr(self, "_" + how)(L)
            self.stage_done(L.get("name", how))

    # --- where: loose, then exact --------------------------------------------------------------------------------------------------

    def _color(self, c):
        # (...or the picture's own color where it says - {"at": a box}, the middle of what is there)
        if isinstance(c, dict) and "at" in c:
            x0, y0, x1, y1 = c["at"]
            blk = self.ref.srgb[int(y0 * PX):int(y1 * PX), int(x0 * PX):int(x1 * PX)].reshape(-1, 3)
            return np.median(blk, axis=0)
        if isinstance(c, str) and c.startswith("#"):
            return hex_rgb(c)
        if c in self.paints:
            return self.paints[c]
        if c in self.opt_names:
            return self.opt_cols[self.opt_names.index(c)]
        # (...any mix, written "first paint+second paint share" in either order and any share: an agent's "white paint+rust cream 0.1"
        # had been no color at all, and its base never laid)
        import re
        mt = re.match(r"^\s*(.+?)\s*\+\s*(.+?)\s+([0-9]*\.?[0-9]+)\s*$", str(c))
        if mt and mt.group(1) in self.paints and mt.group(2) in self.paints:
            from color import mix
            return mix(self.paints[mt.group(1)], self.paints[mt.group(2)], float(np.clip(float(mt.group(3)), 0.0, 1.0)))
        raise ValueError("no such color: %s" % c)

    def _ref_soft(self, mm):
        key = round(mm, 2)
        if key not in self._soft_lab:
            lin = dec(self.ref.srgb)
            if mm > 0:
                lin = np.stack([ndimage.gaussian_filter(lin[..., c], mm * PX * 0.5) for c in range(3)], -1)
            self._soft_lab[key] = oklab(lin)
        return self._soft_lab[key]

    def _within(self, w):
        """Where `w` says, loosely: "all"; a box [x0, y0, x1, y1]; a polygon [[x, y], ...]; or a list of boxes and polygons (mm)."""
        if w in (None, "all"):
            return self.ref.face.copy()
        def is_box(s):
            return len(s) == 4 and all(isinstance(v, (int, float)) for v in s)
        def is_poly(s):
            return len(s) >= 3 and all(isinstance(v, (list, tuple)) and len(v) == 2 for v in s)
        shapes = [w] if (is_box(w) or is_poly(w)) else list(w)
        im = Image.new("L", (self.ref.w, self.ref.h), 0)
        d = ImageDraw.Draw(im)
        for s in shapes:
            if is_box(s):
                x0, y0, x1, y1 = s
                d.rectangle([x0 * PX, y0 * PX, x1 * PX, y1 * PX], fill=255)
            elif is_poly(s):
                d.polygon([(x * PX, y * PX) for x, y in s], fill=255)
            else:
                raise ValueError("`within` is all, a box, a polygon or a list of them: %s" % (s,))
        return (np.asarray(im) > 0) & self.ref.face

    def mask(self, L):
        """WHERE LAYER `L` GOES, exact: inside `within`, the points nearer `near` than `versus` (the picture softened to `smooth`), the
        shape cleaned."""
        M = self._within(L.get("within", "all"))
        smooth = float(L.get("smooth", 0.6))
        # (...or GIVEN WHOLE - a layer's own alpha, made from the step that painted it, never guessed from colors - layers_paint.py)
        if L.get("mask") is not None:
            M = M & np.asarray(L["mask"], bool)
        if "near" in L:
            lab = self._ref_soft(min(smooth, 1.0))
            near = np.array([oklab(dec(self._color(c))) for c in L["near"]])
            dn = np.min(np.linalg.norm(lab[..., None, :] - near[None, None], axis=-1), axis=-1)
            sel = dn < float(L.get("tol", 40.0))
            if L.get("versus"):
                vs = np.array([oklab(dec(self._color(c))) for c in L["versus"]])
                dv = np.min(np.linalg.norm(lab[..., None, :] - vs[None, None], axis=-1), axis=-1)
                sel &= dn < dv
            M &= sel
        # (...or by lightness against the base - `darker` / `lighter` by that much: a brow's sheen is a grey nearer the plum shadow under it
        # than black, but far darker than the face)
        if ("darker" in L or "lighter" in L) and self.base_col is not None:
            lab = self._ref_soft(min(smooth, 1.0))
            bl = oklab(dec(self.base_col))[0]
            if "darker" in L:
                M &= lab[..., 0] < bl - float(L["darker"])
            if "lighter" in L:
                M &= lab[..., 0] > bl + float(L["lighter"])
        r = int(round(smooth * PX))
        if r > 0:
            st = ndimage.generate_binary_structure(2, 1)
            M = ndimage.binary_opening(M, st, iterations=r)
            M = ndimage.binary_closing(M, st, iterations=r)
            # (...ITS EDGE A PAINTER'S CURVE: the signed distance to its edge softened and cut at zero - a curve's wobble smaller than
            # `smooth` gone, its corners kept rounder than a picture's pixels; the lips and brows had come out jagged)
            M = smooth_shape(M, r)
        if L.get("fill_holes"):
            M = ndimage.binary_fill_holes(M)
        # (...made the same both sides of the face where it is - `mirror`: the axis in mm, or true for the face's middle: a pair of lips
        # read off a picture's shading come out lopsided)
        if L.get("mirror"):
            ax = float(L["mirror"]) if not isinstance(L["mirror"], bool) else float(np.nonzero(self.ref.face)[1].mean() + 0.5) / PX
            cols = np.arange(self.ref.w)
            src = np.clip(np.round(2 * ax * PX - cols - 1).astype(int), 0, self.ref.w - 1)
            both = (M.astype(float) + M[:, src].astype(float)) * 0.5
            M = ndimage.gaussian_filter(both, PX * 0.3) > 0.45
        g = float(L.get("grow", 0.0))
        if g > 0:
            M = ndimage.binary_dilation(M, iterations=int(g * PX))
        elif g < 0:
            M = ndimage.binary_erosion(M, iterations=int(-g * PX))
        least = float(L.get("min_area", 2.0)) * PX * PX
        comps, n = ndimage.label(M)
        if n:
            sizes = ndimage.sum(np.ones(M.shape), comps, range(1, n + 1))
            keep = np.zeros(n + 1, bool)
            keep[1:] = sizes >= least
            M = keep[comps]
        return M & self.ref.face

    def paint_of(self, L, M):
        p = L.get("paint", "auto")
        if p == "auto" and L.get("colors") is not None and M.any():
            # (...nearest the colors its own step painted there, where a layer brings them)
            med = np.median(np.asarray(L["colors"])[M], axis=0)
            opt_lab = oklab(dec(self.opt_cols))
            j = int(np.argmin(np.linalg.norm((opt_lab - med) * self.HUE, axis=1)))
            return self.opt_cols[j], self.opt_names[j]
        if p != "auto":
            col = self._color(p)
            self.paints.setdefault(p, col) if "+" in p and p not in self.opt_names else None
            return col, p
        # (...the paint or mix nearest the picture where the layer goes)
        med = np.median(self.ref.lab[M], axis=0) if M.any() else self.ref.lab[self.ref.face].mean(0)
        opt_lab = oklab(dec(self.opt_cols))
        # (...hue weighed up, as the areas are cut: by lightness alone a warm cream had matched a grey)
        j = int(np.argmin(np.linalg.norm((opt_lab - med) * self.HUE, axis=1)))
        return self.opt_cols[j], self.opt_names[j]

    # --- what each layer is ------------------------------------------------------------------------------------------------------

    def _base(self, L):
        """THE BASE: one paint patted over the whole face with the sponge until it is whole."""
        M = self.ref.face
        # (...its paint the picture's where it is plainest - `sample`, a box or polygon - or as named)
        col, name = self.paint_of(L, self._within(L.get("sample", "all")))
        self.base_col = col
        self.paints.setdefault(name, col)
        self.ground = name
        self._options()
        self.labels = np.where(self.ref.face, 0, -1)
        self.foundation_with(name, col)

    def foundation_with(self, name, col):
        face = self.ref.face
        self.hand.take("sponge")
        self.hand.need(name)
        r = TOOLS["sponge"]["mm"] * 0.5 * 0.8
        step = r * 1.25
        for row, y in enumerate(np.arange(r * 0.6, self.ref.frame[1], step * 0.866)):
            xs = np.arange(r * 0.6 + (step * 0.5 if row % 2 else 0), self.ref.frame[0], step)
            if row % 2:
                xs = xs[::-1]
            for x in xs:
                c = np.array([x, y]) + self.rng.normal(0, r * 0.08, 2)
                if self._near_face(c, r * 0.7):
                    self._force(mk.sponge_print(self.cv, c, r, col, name, self.hand.load, 1.0, False, int(self.rng.integers(1 << 30))), c)
        # (...pressed again with its face wherever it is still thin, a cell at a time - its corner, a press for every gap, had made the
        # base ten minutes long)
        for _ in range(2):
            thin = face & (ndimage.gaussian_filter(self.cv.alp, PX * 0.75) < 0.8)
            # (...EACH THIN PATCH WHOLE, wherever it lies - a press at its middle, or, larger than a press, presses spread over it a press
            # apart: cut by a grid of cells, a gap across a cell's border had been pressed twice, or not at all)
            comps, n = ndimage.label(thin)
            cents = []
            step = r * 1.25 * PX
            for i, bx in enumerate(ndimage.find_objects(comps)):
                part = comps[bx] == i + 1
                if part.sum() < (1.0 * PX) ** 2:
                    continue
                yy, xx = np.nonzero(part)
                if max(part.shape) <= r * 1.6 * PX:
                    cents.append(np.array([bx[1].start + xx.mean() + 0.5, bx[0].start + yy.mean() + 0.5]) / PX)
                    continue
                for row, y in enumerate(np.arange(step * 0.5, part.shape[0], step * 0.866)):
                    for x in np.arange(step * 0.5 + (step * 0.5 if row % 2 else 0), part.shape[1], step):
                        win = part[max(int(y - step / 2), 0):int(y + step / 2), max(int(x - step / 2), 0):int(x + step / 2)]
                        if win.sum() >= (1.0 * PX) ** 2:
                            wy, wx = np.nonzero(win)
                            cents.append(np.array([bx[1].start + max(int(x - step / 2), 0) + wx.mean() + 0.5,
                                                   bx[0].start + max(int(y - step / 2), 0) + wy.mean() + 0.5]) / PX)
            if not cents:
                break
            for i in self._tour(cents):
                self._force(mk.sponge_print(self.cv, cents[i], r, col, name, self.hand.load, 1.0, False, int(self.rng.integers(1 << 30))), cents[i])

    def _fill(self, L):
        """A SHAPE FILLED SOLID: along its contours, a brush as thick as each part of it is, and filled again wherever paint is still
        thin - no bare skin left showing (the user, 2026-11-08: "large gaps ... tan is showing through in a ton of places")."""
        M = self.mask(L)
        if not M.any():
            return
        col, name = self.paint_of(L, M)
        self._solid(M, col, name, float(L.get("th", 1.0)), L.get("tool"))

    def _solid(self, M, col, name, th=1.0, tool=None, passes=3):
        target = self.ref.lab
        col_lab = oklab(dec(col))
        todo = M
        for p in range(passes):
            comps, n = ndimage.label(todo)
            boxes = ndimage.find_objects(comps)
            jobs = []
            for i, bx in enumerate(boxes):
                m = comps[bx] == i + 1
                if m.sum() < 2:
                    continue
                cy = (bx[0].start + bx[0].stop) / 2 / PX
                cx = (bx[1].start + bx[1].stop) / 2 / PX
                jobs.append((np.array([cx, cy]), bx, m))
            by_tool = {}
            for jb in jobs:
                thick = ndimage.distance_transform_edt(np.pad(jb[2], 1)).max() / PX
                t = tool or ("liner" if thick <= 1.2 else ("round" if thick <= 4.5 else "flat"))
                by_tool.setdefault(t, []).append(jb)
            for t in ("flat", "round", "liner"):
                for j in self._tour([jb[0] for jb in by_tool.get(t, [])]):
                    _, bx, m = by_tool[t][j]
                    self._contours(m, bx, col, name, t, th)
            # (...and wherever it is still thin, again)
            left = M & (delta(self.cv.lab(), col_lab[None, None, :]) > (6.0 if th >= 0.9 else 1e9))
            left = ndimage.binary_opening(left)
            if left.sum() < (0.6 * PX) ** 2:
                break
            todo = left

    def _contours(self, M, bx, col, name, tool, th, th_map=None):
        """`M` (box `bx`) filled along its contours with `tool` in `col` at thickness `th` - or, given `th_map` (the whole canvas), as
        thick at each point of each stroke as the map says there."""
        hw = TOOLS[tool]["mm"] * 0.5
        self.hand.take(tool)
        self.hand.need(name)
        dt = ndimage.distance_transform_edt(np.pad(M, 1))[1:-1, 1:-1]
        thick = dt.max() / PX
        oy, ox = bx[0].start, bx[1].start
        first = min(hw * 0.8, thick * 0.5)
        levels = [first]
        step = hw * 0.75
        while levels[-1] + step < thick:
            levels.append(levels[-1] + step)
        for li, d in enumerate(levels):
            S = dt >= d * PX
            if not S.any():
                continue
            ring = S & ~ndimage.binary_erosion(S)
            sk = lines_mod._thin(ring)
            ls = lines_mod._follow(sk, np.ones(sk.shape), np.zeros(sk.shape + (3,)), np.ones(sk.shape), PX)
            half = min(hw, d + 0.5) if li == 0 else hw
            for l in ls:
                # (...each ring a smooth curve, the outer one CUT IN: crisp at its outer edge, as a painter draws a shape's edge before
                # filling it - the pixel ring had laid every wobble of the picture's edge)
                path = smooth_path(l["pts"], max(self.EDGE_SMOOTH, d * 0.3), closed=_is_closed(l["pts"]))
                cut = li == 0 and th >= 0.9
                for chunk in _chunks(path, 45.0):
                    if len(chunk) < 2:
                        continue
                    pts = chunk + np.array([ox, oy]) / PX
                    if th_map is not None:
                        qi = np.clip((pts * PX).astype(int), 0, [th_map.shape[1] - 1, th_map.shape[0] - 1])
                        th_pts = th_map[qi[:, 1], qi[:, 0]]
                        if th_pts.max() < 0.04:
                            continue
                        m = mk.brush_stroke(self.cv, pts, max(half, hw * mk.TIP_LEAST), col, name, th_pts, self.hand.load, "shade", tool,
                                            belly=0.8, edge=0.4, streak=(0.03, 0.2, 0.2), seed=int(self.rng.integers(1 << 30)))
                        self.try_lay(m, self.ref.lab, -1e9)
                        continue
                    # (...a fill's strokes laid wet into each other: little bristle streaking - ring after streaked ring had shown as bands)
                    m = mk.brush_stroke(self.cv, pts, max(half, hw * mk.TIP_LEAST), col, name, th, self.hand.load,
                                        "glaze" if th < 0.9 else "sweep", tool, belly=0.75 if th < 0.9 else (0.1 if cut else 0.45),
                                        edge=0.12 if cut else 0.3, tail=0.0 if cut else mk.TAIL, streak=(0.04, 0.3, 0.3),
                                        seed=int(self.rng.integers(1 << 30)))
                    if th >= 0.9 and self._done_under(m, col) > self.DONE:
                        continue
                    self.try_lay(m, self.ref.lab, -1e9)
        # (...a shape too small for any contour: a press of the tip at its middle)
        if not levels or thick < 0.4:
            yy, xx = np.nonzero(M)
            c = np.array([xx.mean() + ox + 0.5, yy.mean() + oy + 0.5]) / PX
            self.try_lay(mk.dab(self.cv, c, max(thick, 0.3), col, name, 1.0, th, tool), self.ref.lab, -1e9, c)

    def _strokes(self, L):
        """A LONG SHAPE DRAWN AS A HAND DRAWS IT - a drip, a brow, a lid's line: one stroke along its middle, pressed to its width at
        every point (thick where it is thick, tapering where it tapers), pulled the way it runs - a drip downward. Filled round its
        contours, each drip had been outlined both sides and gone over again."""
        M = self.mask(L)
        if not M.any():
            return
        col, name = self.paint_of(L, M)
        tool = L.get("tool", "round")
        hw = TOOLS[tool]["mm"] * 0.5
        self.hand.take(tool)
        self.hand.need(name)
        dt = ndimage.distance_transform_edt(M)
        sk = lines_mod._thin(M)
        ls = lines_mod._follow(sk, dt, np.zeros(M.shape + (3,)), np.ones(M.shape), PX)
        down = L.get("down", False)
        spur = float(L.get("spur", 1.5))
        jobs = []
        # (...a shape drawn as ONE stroke - `one`: a brow, a lid's line - its spine alone, each part's longest path, never its spurs)
        if L.get("one"):
            comps, n = ndimage.label(M)
            best = {}
            for l in ls:
                q = l["pts"][len(l["pts"]) // 2]
                c = comps[min(int(q[1] * PX), M.shape[0] - 1), min(int(q[0] * PX), M.shape[1] - 1)]
                ln = np.linalg.norm(np.diff(l["pts"], axis=0), axis=1).sum()
                if c and (c not in best or ln > best[c][0]):
                    best[c] = (ln, l)
            ls = [v[1] for v in best.values()]
        for l in ls:
            pts = l["pts"]
            if np.linalg.norm(np.diff(pts, axis=0), axis=1).sum() < spur:
                continue
            half = l["half"]
            # (...smoothed along its length, its width eased, and pulled out to its points along its ends' way - a thinned line of pixels
            # wobbles, and stops short of a tapering tip by half its width)
            pts, half = smooth_stroke(pts, half, float(L.get("line_smooth", 1.2)), PX)
            if down and pts[0][1] > pts[-1][1]:
                pts, half = pts[::-1], half[::-1]
            jobs.append((pts, half))
        for o in self._tour([j[0][0] for j in jobs]):
            pts, half = jobs[o]
            w = np.clip(half + float(L.get("spill", 0.4)), hw * mk.TIP_LEAST, hw)
            for chunk_i, chunk in enumerate(_chunks(pts, 70.0)):
                k0 = int(np.argmin(np.linalg.norm(pts - chunk[0], axis=1)))
                ww = np.interp(np.arange(len(chunk)), [0, len(chunk) - 1], [w[min(k0, len(w) - 1)], w[min(k0 + len(chunk) - 1, len(w) - 1)]]) \
                    if len(w) != len(chunk) else w
                m = mk.brush_stroke(self.cv, chunk, ww, col, name, float(L.get("th", 1.0)), self.hand.load, "sweep", tool, belly=0.15,
                                    streak=(0.05, 0.4, 0.4), seed=int(self.rng.integers(1 << 30)))
                self.try_lay(m, self.ref.lab, -1e9)
        # (...and whatever of it is still bare, filled - only a real gap, and never round a shape drawn as one stroke: touched up along
        # every edge, a brow had come out beaded)
        if L.get("one"):
            return
        left = M & (delta(self.cv.lab(), oklab(dec(col))[None, None, :]) > 12)
        left = ndimage.binary_opening(left, iterations=2)
        if left.sum() >= (1.5 * PX) ** 2:
            self._solid(left, col, name, 1.0, None, passes=1)

    def _correct(self, L):
        """GOING BACK OVER WHAT CAME OUT WRONG, as e-David does with its camera (Deussen et al. 2012): each shape layer before this one
        looked at again - where its shape still does not show its paint, though the picture wants it there, marks added, and only marks
        that bring the canvas nearer the picture; a layer no mark helps any more is left. Never over work already right."""
        done = []
        for P in self._layers_before:
            if P.get("how") not in ("fill", "strokes", "dots", "outline"):
                continue
            M = self.mask(P)
            if not M.any():
                continue
            col, name = self.paint_of(P, M)
            col_lab = oklab(dec(col))
            far = M & (delta(self.cv.lab(), col_lab[None, None, :]) > float(L.get("far", 12.0)))
            # (...only where the picture is nearer this paint than the canvas is)
            far &= delta(self.ref.lab, col_lab[None, None, :]) < delta(self.ref.lab, self.cv.lab())
            far = ndimage.binary_opening(far)
            if far.sum() < (float(L.get("least", 1.0)) * PX) ** 2:
                continue
            n0 = len(self.laid)
            comps, n = ndimage.label(far)
            for i, bx in enumerate(ndimage.find_objects(comps)):
                m = comps[bx] == i + 1
                if m.sum() < (0.8 * PX) ** 2:
                    continue
                thick = ndimage.distance_transform_edt(np.pad(m, 1)).max() / PX
                tool = P.get("tool") or ("liner" if thick <= 1.2 else ("round" if thick <= 4.5 else "flat"))
                self._contours_checked(m, bx, col, name, tool)
            done.append("%s %d" % (P.get("name", ""), len(self.laid) - n0))
        self.corrected = done

    def _contours_checked(self, M, bx, col, name, tool):
        """`_contours`, every stroke weighed: laid only if it brings the canvas nearer the picture."""
        keep = self.try_lay
        self.try_lay = lambda m, target, least, start=None, paint=None, soft=0.0: keep(m, target, max(least, 0.5), start, paint, soft)
        try:
            self._contours(M, bx, col, name, tool, 1.0)
        finally:
            self.try_lay = keep

    DONE = 0.8               # a stroke whose touch is this much already its paint is never laid (it would go over done work)
    EDGE_SMOOTH = 0.8        # mm: a filled shape's rings smoothed along their length at least this much
    TEXTURE_SECONDS = 180.0  # a stipple or spatter layer stops here unless it says otherwise

    def _done_under(self, m, col):
        """How much of what mark `m` touches already shows its paint `col` - going over work already done is time wasted."""
        if m is None:
            return 1.0
        # (...where it changes the color - over the base everything is already covered, so a rise in coverage says nothing)
        touched = np.abs(m.pre - self.cv.pre[m.sl]).sum(axis=-1) + np.abs(m.alp - self.cv.alp[m.sl]) > 0.05
        if not touched.any():
            return 1.0
        d = delta(self.cv.lab(m.sl), oklab(dec(col))[None, None, :])
        return float((d[touched] < 6.0).mean())

    def _spatter(self, L):
        """SPATTER: a loaded brush flicked - a stiff one's drops bold and few, a fan's or a toothbrush's fine and many - flick by flick over
        the shape, each throwing its drops ahead of it, those past the shape's edge kept only a little way out: noise round an eye, the
        speckle in rust (the trade: a faster flick throws more drops, a thinner paint a finer mist)."""
        M = self.mask(L)
        if not M.any():
            return
        col, name = self.paint_of(L, M)
        tool = L.get("tool", "fan" if "fan" in self.tools else "round")
        self.hand.take(tool)
        self.hand.need(name)
        area = M.sum() / (PX * PX)
        flicks = max(int(float(L.get("density", 0.5)) * area / 150.0), 1)
        yy, xx = np.nonzero(M)
        pick = self.rng.choice(len(yy), min(flicks, len(yy)), replace=False)
        pts = [np.array([xx[i] + 0.5, yy[i] + 0.5]) / PX for i in pick]
        spread = float(L.get("spread", 4.0))
        drops = int(L.get("drops", 40))
        near = ndimage.gaussian_filter(M.astype(float), PX * float(L.get("margin", 1.0)))
        t_end = self.hand.t + float(L.get("seconds", self.TEXTURE_SECONDS))
        for i in self._tour(pts):
            if self.hand.t > t_end:
                break
            way = self.rng.normal(0, 1, 2)
            m = mk.spatter(self.cv, pts[i], way, spread, col, name, self.rng, drops, tool)
            if m is not None:
                keep = np.clip(near[m.sl] * 2.0, 0, 1)
                m.alp = self.cv.alp[m.sl] + (m.alp - self.cv.alp[m.sl]) * keep
                m.pre = self.cv.pre[m.sl] + (m.pre - self.cv.pre[m.sl]) * keep[..., None]
            self.try_lay(m, self.ref.lab, -1e9, pts[i])

    # --- color worked on the face: shading, gradients, textured fills ------------------------------------------------------------
    # (the user, 2026-11-09: "there is very little actual color blending or gradients here ... add a touch of black to make an entire
    # region darker ... if the paint is still wet, then hypothetically you could feather the region between them - and blend those two
    # colors into a new one. It's all about the gradients")

    def _amount(self, M, col, most=0.9, soft=1.5, target=None):
        """HOW MUCH OF PAINT `col` EACH POINT OF `M` WANTS laid over what is there now to come nearest the picture: the share along the
        line from the canvas's color to the paint's (linear light) that lands nearest the picture's, softened over `soft` mm - a tone,
        never a texture - and no more than `most`."""
        c = self.cv.shown()
        r = dec(self.ref.srgb if target is None else np.asarray(target))
        r = np.stack([ndimage.gaussian_filter(r[..., k], soft * PX * 0.5) for k in range(3)], -1)
        p = dec(np.asarray(col))
        d = p[None, None, :] - c
        a = ((r - c) * d).sum(-1) / np.maximum((d * d).sum(-1), 1e-6)
        a = np.clip(a, 0.0, most) * M
        return ndimage.gaussian_filter(a, soft * PX) * (ndimage.gaussian_filter(M.astype(float), PX * 0.5) > 0.3)

    def _shade(self, L):
        """A TOUCH OF A PAINT WORKED INTO A REGION: laid heavier where the picture wants more of it and fading to nothing where it wants
        none - a region darkened with black, warmed with rust - then feathered while it is wet, so it is a gradient, never a coat."""
        M = self.mask(L)
        if not M.any():
            return
        col, name = self.paint_of(L, M)
        amt = (np.asarray(L["amount"]) * float(L.get("most", 1.0)) if L.get("amount") is not None
               else self._amount(M, col, float(L.get("most", 0.85)), float(L.get("soft", 1.5)), L.get("target"))) / mk.FILM
        if amt.max() < 0.05:
            return
        # (...only where it is wanted - `least` of it at the least: shading asked over the whole face had stroked every inch of it, most
        # of those strokes laying nothing the picture needed - with a broad soft brush, the fewer strokes)
        M = smooth_shape(M & (amt > float(L.get("least", 0.08))), int(PX * 1.5))
        if not M.any():
            return
        amt = amt * ndimage.gaussian_filter(M.astype(float), PX)
        tool = L.get("tool", "blender" if "blender" in self.tools else "flat")
        comps, n = ndimage.label(M)
        for i, bx in enumerate(ndimage.find_objects(comps)):
            self._contours(comps[bx] == i + 1, bx, col, name, tool, 1.0, th_map=amt)
        if float(L.get("reach", 2.0)) > 0:
            self._feather_area(M, float(L.get("reach", 2.0)), L.get("blend_tool"), passes=int(L.get("passes", 1)))

    def _feather_area(self, M, reach, tool=None, passes=1, wet=True):
        """THE WHOLE OF `M` WORKED OVER WITH A CLEAN BRUSH WHILE IT IS WET: pulls along its contours, each moving the paint under it about
        `reach` mm each way - the colors laid side by side run into each other and make new ones between."""
        tool = tool or ("blender" if "blender" in self.tools else "round")
        self.hand.take(tool)
        self.hand.need("")
        half = TOOLS[tool]["mm"] * 0.3
        dt = ndimage.distance_transform_edt(M)
        for _ in range(passes):
            d = half * 0.6
            while d * PX < dt.max():
                S = dt >= d * PX
                ring = S & ~ndimage.binary_erosion(S)
                ls = lines_mod._follow(lines_mod._thin(ring), np.ones(M.shape), np.zeros(M.shape + (3,)), np.ones(M.shape), PX)
                for l in ls:
                    path = smooth_path(l["pts"], 1.5, closed=_is_closed(l["pts"]))
                    for chunk in _chunks(path, 40.0):
                        if len(chunk) >= 2:
                            m = mk.soften(self.cv, chunk, half, reach, 0.9, "wet_blend", tool)
                            self.try_lay(m, self.ref.lab, -1e9)
                d += half * 1.4

    def _smudge(self, L):
        """A LARGE SMUDGE, AS STRONG AS ASKED: a fat brush, clean and damp, worked over a band either side of a shape's edge (`band` mm)
        - or over the whole shape (`whole`) - each pull `size` mm across, moving the paint under it about `reach` mm, with `strength`
        (0-1): a region's paints run out into what is round them, as the picture's fade into the white (the user, 2026-11-09: "a lot
        more feathering/fuzziness/blending around the extreme edges ... they blend right into the white")."""
        M = self.mask(L)
        if not M.any():
            return
        band = float(L.get("band", 5.0))
        if L.get("whole"):
            area = M
        else:
            # (...out past the edge by `band`, in from it by `inside` of that - reaching far in, it had washed a lid's color out)
            area = (ndimage.binary_dilation(M, iterations=int(band * PX))
                    & ~ndimage.binary_erosion(M, iterations=max(int(band * PX * float(L.get("inside", 0.3))), 1)))
            area &= self.ref.face
        tool = L.get("tool", "blender" if "blender" in self.tools else "flat")
        self.hand.take(tool)
        self.hand.need("")
        half = float(L.get("size", 5.0))
        reach = float(L.get("reach", half * 0.6))
        strength = float(np.clip(float(L.get("strength", 0.6)), 0.05, 1.0))
        least = 0.0 if L.get("keep") else -1e9
        dt = ndimage.distance_transform_edt(area)
        d = half * 0.5
        while d * PX < dt.max() or d == half * 0.5:
            S = dt >= d * PX
            if not S.any():
                break
            ring = S & ~ndimage.binary_erosion(S)
            ls = lines_mod._follow(lines_mod._thin(ring), np.ones(area.shape), np.zeros(area.shape + (3,)), np.ones(area.shape), PX)
            for l in self._tour_lines(ls):
                path = smooth_path(l["pts"], 2.0, closed=_is_closed(l["pts"]))
                for chunk in _chunks(path, 45.0):
                    if len(chunk) >= 2:
                        self.try_lay(mk.soften(self.cv, chunk, half, reach, strength, "smudge", tool), self.ref.lab, least)
            d += half * 1.2

    def _tour_lines(self, ls):
        return [ls[i] for i in self._tour([l["pts"][0] for l in ls])]

    def _paints_of(self, L, M):
        names = L.get("paints") or [L.get("paint", "auto")]
        out = []
        for n in names:
            if n == "auto":
                out.append(self.paint_of({"paint": "auto"}, M))
            else:
                out.append((self._color(n), n))
        return out

    def _gradient(self, L):
        """A SHAPE IN SEVERAL PAINTS RUN TOGETHER WET: each of `paints` laid where the picture is nearest it, a little past its border
        into its neighbours, the lightest first; then the borders between them worked with a clean brush while wet, as wide as the
        picture's own transition is soft (`reach`) - two paints side by side mixed on the face into the colors between."""
        M = self.mask(L)
        if not M.any():
            return
        pairs = self._paints_of(L, M)
        lab = self._ref_soft(1.0)
        opt = np.array([oklab(dec(c)) for c, _ in pairs])
        dist = np.linalg.norm((lab[..., None, :] - opt[None, None]) * self.HUE, axis=-1)
        near = np.argmin(dist, axis=-1)
        order = np.argsort([-oklab(dec(c))[0] for c, _ in pairs])
        for j in order:
            col, name = pairs[j]
            sub = M & (near == j)
            sub = smooth_shape(sub, int(PX * 0.8)) & M
            sub = ndimage.binary_dilation(sub, iterations=int(float(L.get("overlap", 0.8)) * PX)) & M
            if sub.sum() < (1.0 * PX) ** 2:
                continue
            self._solid(sub, col, name, float(L.get("th", 1.0)), L.get("tool"), passes=1)
        # (...the borders inside it worked wet, the picture's own softness deciding how far)
        inner = np.zeros(M.shape, bool)
        inner[:, 1:] |= near[:, 1:] != near[:, :-1]
        inner[1:, :] |= near[1:, :] != near[:-1, :]
        inner = ndimage.binary_dilation(inner & M, iterations=int(float(L.get("reach", 2.5)) * PX)) & M
        self._feather_area(inner | (M & ~ndimage.binary_erosion(M, iterations=int(PX))), float(L.get("reach", 2.5)),
                           L.get("blend_tool"), passes=int(L.get("passes", 1)))

    def _texture(self, L):
        """A TEXTURED FILL: the whole shape stippled with the sponge, press by press until no skin shows, each press in whichever of
        `paints` the picture is nearest where it lands - one paint at a time, the lightest first - pressure, size and turn varied: the
        grain and the color's play come from the presses, never a smooth fill speckled after."""
        M = self.mask(L)
        if not M.any():
            return
        pairs = self._paints_of(L, M)
        size = float(L.get("size", 5.0))
        rr = size * 0.5
        lab = self._ref_soft(0.4)
        opt = np.array([oklab(dec(c)) for c, _ in pairs])
        step = rr * float(L.get("apart", 1.0)) * PX
        pts = []
        for row, y in enumerate(np.arange(step * 0.5, M.shape[0], step * 0.866)):
            for x in np.arange(step * 0.5 + (step * 0.5 if row % 2 else 0), M.shape[1], step):
                jx, jy = x + self.rng.normal(0, step * 0.25), y + self.rng.normal(0, step * 0.25)
                xi, yi = int(np.clip(jx, 0, M.shape[1] - 1)), int(np.clip(jy, 0, M.shape[0] - 1))
                if M[yi, xi]:
                    pts.append((yi, xi))
        if not pts:
            return
        which = [int(np.argmin(np.linalg.norm((opt - lab[y, x]) * self.HUE, axis=1))) for y, x in pts]
        inside = ndimage.gaussian_filter(M.astype(float), PX * 0.4)
        t_end = self.hand.t + float(L.get("seconds", 300.0))
        self.hand.take("sponge")
        for j in np.argsort([-oklab(dec(c))[0] for c, _ in pairs]):
            col, name = pairs[j]
            mine = [np.array([x + 0.5, y + 0.5]) / PX for (y, x), w in zip(pts, which) if w == j]
            if not mine:
                continue
            self.hand.need(name)
            for i in self._tour(mine):
                if self.hand.t > t_end:
                    return
                k = float(self.rng.uniform(0.75, 1.25))
                m = mk.sponge_print(self.cv, mine[i], rr * k / 0.38, col, name, min(self.hand.load, float(L.get("load", 0.9))),
                                    float(L.get("press", 0.8)) * float(self.rng.uniform(0.7, 1.15)), True, int(self.rng.integers(1 << 30)),
                                    kind="stipple", ragged=rr * k * 0.35)
                if m is not None:
                    keep = inside[m.sl]
                    m.alp = self.cv.alp[m.sl] + (m.alp - self.cv.alp[m.sl]) * keep
                    m.pre = self.cv.pre[m.sl] + (m.pre - self.cv.pre[m.sl]) * keep[..., None]
                self.try_lay(m, self.ref.lab, -1e9, mine[i])

    def _glaze(self, L):
        """A THIN COAT over a shape: the color under it still shows."""
        M = self.mask(L)
        if M.any():
            col, name = self.paint_of(L, M)
            self._solid(M, col, name, float(L.get("th", 0.4)), L.get("tool", "flat"), passes=1)

    def _stipple(self, L):
        """A TEXTURE APPROXIMATED: the sponge's corner pressed lightly at scattered places inside the shape - `density` of it covered, the
        presses `size` mm across - never the picture's texture copied a fleck at a time."""
        M = self.mask(L)
        if not M.any():
            return
        col, name = self.paint_of(L, M)
        size = float(L.get("size", 4.0))
        density = float(L.get("density", 0.7))
        self.hand.take("sponge")
        self.hand.need(name)
        rr = size * 0.5
        area = M.sum() / (PX * PX)
        n = int(density * area / (np.pi * rr * rr))
        yy, xx = np.nonzero(M)
        if n <= 0 or len(yy) == 0:
            return
        # (...NO LONGER THAN ITS TIME - `seconds`, three minutes unless it says: a texture asked over the whole face had been sixteen
        # thousand presses and four hours)
        n = min(n, int(L.get("most", 600)))
        pick = self.rng.choice(len(yy), min(n, len(yy)), replace=False)
        pts = [np.array([xx[i] + 0.5, yy[i] + 0.5]) / PX for i in pick]
        t_end = self.hand.t + float(L.get("seconds", self.TEXTURE_SECONDS))
        for i in self._tour(pts):
            if self.hand.t > t_end:
                break
            # (...each pounce its own: pressed harder or lighter, a little larger or smaller, the sponge turned between - as the trade
            # stipples: the same press over and over had laid polka dots)
            k = float(self.rng.uniform(0.7, 1.3))
            pr = float(L.get("press", 0.6)) * float(self.rng.uniform(0.6, 1.2))
            m = mk.sponge_print(self.cv, pts[i], rr * k / 0.38, col, name, min(self.hand.load, float(L.get("load", 0.75))), min(pr, 1.0), True,
                                int(self.rng.integers(1 << 30)), kind="stipple", ragged=rr * k * 0.35)
            if m is not None:
                # (...kept to its shape: what a press lays past the shape's edge fades out within a millimeter)
                inside = ndimage.gaussian_filter(M[m.sl].astype(float), PX * 0.4)
                m.alp = self.cv.alp[m.sl] + (m.alp - self.cv.alp[m.sl]) * inside
                m.pre = self.cv.pre[m.sl] + (m.pre - self.cv.pre[m.sl]) * inside[..., None]
            self.try_lay(m, self.ref.lab, -1e9, pts[i])

    def _outline(self, L):
        """A SHAPE'S EDGE DRAWN: a line just inside its cleaned edge, `width` wide."""
        M = self.mask(L)
        if not M.any():
            return
        col, name = self.paint_of(L, M)
        w = float(L.get("width", 0.4))
        tool = L.get("tool", "liner")
        self.hand.take(tool)
        self.hand.need(name)
        dt = ndimage.distance_transform_edt(np.pad(M, 1))[1:-1, 1:-1]
        S = dt >= max(w * PX, 1)
        ring = S & ~ndimage.binary_erosion(S)
        sk = lines_mod._thin(ring)
        ls = lines_mod._follow(sk, np.ones(sk.shape), np.zeros(sk.shape + (3,)), np.ones(sk.shape), PX)
        for o in self._tour([l["pts"][0] for l in ls]):
            path = smooth_path(ls[o]["pts"], float(L.get("line_smooth", 0.8)), closed=_is_closed(ls[o]["pts"]))
            for chunk in _chunks(path, 45.0):
                m = mk.line(self.cv, chunk, w, col, name, 1.0, self.hand.load, "line", tool, int(self.rng.integers(1 << 30)))
                self.try_lay(m, self.ref.lab, -1e9)

    def _lines(self, L):
        """THE PICTURE'S OWN LINES inside `within`, those nearer `near` than `versus`, each drawn pressed to its width."""
        inside = ndimage.binary_erosion(self.ref.hi[..., 3] > 0.5, iterations=int(self.ref.hi_px * float(L.get("inset", 1.5))))
        w = L.get("within", "all")
        if w != "all":
            big = self._within(w)
            hi_m = np.asarray(Image.fromarray(big.astype(np.uint8) * 255).resize((self.ref.hi.shape[1], self.ref.hi.shape[0]))) > 0
            inside &= hi_m
        if L.get("lines_from") is not None:
            # (...the lines its own step painted, found on that step's picture - layers_paint.py)
            found, _ = lines_mod.find(np.asarray(L["lines_from"]), PX, np.asarray(L.get("mask", self.ref.face), bool) & self.ref.face)
        else:
            found, _ = lines_mod.find(self.ref.hi[..., :3], self.ref.hi_px, inside)
        if "near" in L and "darker" not in L and "warmer" not in L:
            near = np.array([oklab(dec(self._color(c))) for c in L["near"]])
            vs = np.array([oklab(dec(self._color(c))) for c in L.get("versus", [])]) if L.get("versus") else None
            keep = []
            for l in found:
                dn = np.min(np.linalg.norm(near - l["lab"], axis=1))
                if vs is not None and dn >= np.min(np.linalg.norm(vs - l["lab"], axis=1)):
                    continue
                keep.append(l)
            found = keep
        # (...or by how they stand against the base - `darker`: lightness under it by that much; `warmer`: yellower by that much - a
        # hairline's color, averaged with what is round it, is a grey that is near no paint)
        if self.base_col is not None and ("darker" in L or "warmer" in L):
            b = oklab(dec(self.base_col))
            found = [l for l in found if ("darker" not in L or l["lab"][0] < b[0] - float(L["darker"]))
                     and ("warmer" not in L or l["lab"][2] > b[2] + float(L["warmer"]))]
        if not found:
            return
        # (...in "auto", the paint or mix nearest the lines' own color - never the area's, which is the face round them)
        if L.get("paint", "auto") == "auto":
            med = np.median(np.array([l["lab"] for l in found]), axis=0)
            opt_lab = oklab(dec(self.opt_cols))
            j = int(np.argmin(np.linalg.norm((opt_lab - med) * self.HUE, axis=1)))
            col, name = self.opt_cols[j], self.opt_names[j]
        else:
            col, name = self.paint_of(L, self._within(w))
        tool = L.get("tool", "liner")
        hw_most = TOOLS[tool]["mm"] * 0.5
        self.hand.take(tool)
        self.hand.need(name)
        lin = dec(self.ref.srgb)
        target = oklab(np.stack([ndimage.gaussian_filter(lin[..., c], self.LINE_SOFT * PX) for c in range(3)], -1))
        scale = float(L.get("width_scale", 1.0))
        if L.get("quick"):
            found = _chained(found, self._tour([l["pts"][0] for l in found]), float(L.get("join", 0.8)))
            order = range(len(found))
        else:
            order = self._tour([l["pts"][0] for l in found])
        for o in order:
            l = found[o]
            # (...smoothed along its length; drawn straight where it all but is - `straight`: always - as a seam is drawn with one sure pull)
            l = dict(l)
            pts = smooth_path(l["pts"], float(L.get("line_smooth", 0.5)), closed=False)
            straight = L.get("straight") or _nearly_straight(pts, float(L.get("straight_tol", 0.35)))
            if straight:
                # (...a straight line one width all along: a seam given a flick's taper had come out a wedge)
                pts = np.array([pts[0], pts[-1]])
                l["half"] = np.full(2, float(np.median(l["half"])))
            else:
                l["half"] = np.interp(np.linspace(0, 1, len(pts)), np.linspace(0, 1, len(l["half"])), l["half"])
            l["pts"] = pts
            hw = np.clip(l["half"] * scale, hw_most * mk.TIP_LEAST, hw_most)
            if not straight and len(l["pts"]) >= 3 and l["half"][0] > l["half"][-1] * 1.8:
                m = mk.flick(self.cv, l["pts"], hw, col, name, 1.0, self.hand.load, tool, int(self.rng.integers(1 << 30)))
            else:
                m = mk.line(self.cv, l["pts"], hw, col, name, 1.0, self.hand.load, "line", tool, int(self.rng.integers(1 << 30)))
            # (...a crackle's many short lines flicked on - `quick` - never cut in at an outline's careful pace: 22 minutes of a face's
            # time had gone to its cracks)
            if m is not None and L.get("quick"):
                m.kind = "crack"
            self.try_lay(m, target, -1e9 if L.get("all") else 0.0, soft=self.LINE_SOFT * PX)

    def _dots(self, L):
        """ROUND THINGS MADE ROUND: each part of the shape a dot at its middle, as wide as the part - a handle's end for a small one, a
        brush's tip pressed to the size for a larger."""
        M = self.mask(L)
        if not M.any():
            return
        # (...a box with no colors said: the round thing inside it found by itself - what differs from the box's own border - an agent's
        # box drawn round each rivet had been painted as a square)
        if "near" not in L and "darker" not in L and "lighter" not in L:
            M = self._blobs_in(L, M)
        # (...ONLY WHAT IS A DOT: a part no larger than `max_area` and round enough - its area against the circle round its widest
        # inside - whatever the plan's colors caught: a light patch of the face taken for a jewel had been painted as one disc 30 mm across)
        comps, n = ndimage.label(M)
        most = float(L.get("max_area", 20.0)) * PX * PX
        keep = np.zeros(n + 1, bool)
        for i, bx in enumerate(ndimage.find_objects(comps)):
            part = comps[bx] == i + 1
            a = part.sum()
            r_in = ndimage.distance_transform_edt(np.pad(part, 1)).max()
            keep[i + 1] = a <= most and a <= np.pi * (r_in * 1.6) ** 2
        M = keep[comps]
        if not M.any():
            return
        col, name = self.paint_of(L, M)
        comps, n = ndimage.label(M)
        cents = ndimage.center_of_mass(M, comps, range(1, n + 1))
        sizes = ndimage.sum(np.ones(M.shape), comps, range(1, n + 1))
        tool = L.get("tool", "handle" if "handle" in self.tools else "round")
        self.hand.take(tool)
        self.hand.need(name)
        pts = [np.array([c[1] + 0.5, c[0] + 0.5]) / PX for c in cents]
        for i in self._tour(pts):
            r = float(np.sqrt(sizes[i] / np.pi)) / PX * float(L.get("size_scale", 1.0))
            if tool == "handle":
                m = mk.dot(self.cv, pts[i], r / 0.9, col, name, 1.0, tool)
            else:
                hw = TOOLS[tool]["mm"] * 0.5
                m = mk.dab(self.cv, pts[i], hw, col, name, float(np.clip((r / hw - mk.TIP_LEAST) / (1 - mk.TIP_LEAST), 0, 1)), 1.0, tool)
            self.try_lay(m, self.ref.lab, -1e9, pts[i])

    def _blobs_in(self, L, M):
        """In each separate part of `M` (a box drawn round a thing), the thing itself: the largest patch differing from the part's
        border by more than `apart` (OKLab x100)."""
        out = np.zeros(M.shape, bool)
        comps, n = ndimage.label(M)
        lab = self._ref_soft(0.3)
        for i, bx in enumerate(ndimage.find_objects(comps)):
            part = comps[bx] == i + 1
            ring = part & ~ndimage.binary_erosion(part, iterations=2)
            if ring.sum() < 4:
                continue
            border = np.median(lab[bx][ring], axis=0)
            diff = np.linalg.norm(lab[bx] - border, axis=-1) > float(L.get("apart", 15.0))
            diff &= part & ~ring
            lb, k = ndimage.label(diff)
            if k == 0:
                continue
            sizes = ndimage.sum(np.ones(diff.shape), lb, range(1, k + 1))
            out[bx] |= lb == (int(np.argmax(sizes)) + 1)
        return out

    def _blend(self, L):
        """A SHAPE'S EDGE FEATHERED where the picture shows it soft: a clean brush along it."""
        M = self.mask(L)
        if not M.any():
            return
        tool = L.get("tool", "blender" if "blender" in self.tools else "round")
        self.hand.take(tool)
        self.hand.need("")
        ring = M & ~ndimage.binary_erosion(M)
        sk = lines_mod._thin(ndimage.binary_dilation(ring))
        ls = lines_mod._follow(sk, np.ones(sk.shape), np.zeros(sk.shape + (3,)), np.ones(sk.shape), PX)
        half = float(L.get("width", 3.0))
        reach = float(L.get("reach", 1.2))
        for o in self._tour([l["pts"][0] for l in ls]):
            for chunk in _chunks(ls[o]["pts"], 30.0):
                m = mk.soften(self.cv, chunk, half, reach, float(L.get("strength", 0.85)), "feather", tool)
                self.try_lay(m, self.ref.lab, -1e9 if L.get("all") else 0.0)


# --- curves a hand draws ------------------------------------------------------------------------------------------------------------

def smooth_shape(M, r):
    """Shape `M` with its edge made a smooth curve: its signed distance (inside positive) softened by `r` pixels and cut at zero."""
    if not M.any():
        return M
    sdf = ndimage.distance_transform_edt(M) - ndimage.distance_transform_edt(~M)
    return ndimage.gaussian_filter(sdf, max(r * 0.8, 0.5)) > 0


def _is_closed(pts, near=1.0):
    return len(pts) > 6 and float(np.linalg.norm(pts[0] - pts[-1])) < near


def smooth_path(pts, sigma, closed=False):
    """Path `pts` (mm) smoothed along its length by `sigma` mm - a closed one all round, an open one with its ends kept - points 0.25 mm
    apart."""
    pts = np.asarray(pts, dtype=float)
    if len(pts) < 3 or sigma <= 0:
        return pts
    dense, s, _ = mk.resample(pts, 0.25)
    if len(dense) < 4:
        return dense
    sg = sigma / 0.25
    mode = "wrap" if closed else "nearest"
    x = ndimage.gaussian_filter1d(dense[:, 0], sg, mode=mode)
    y = ndimage.gaussian_filter1d(dense[:, 1], sg, mode=mode)
    out = np.stack([x, y], axis=1)
    if not closed:
        # (...its ends where they were, the smoothing eased in from them)
        k = min(int(sg * 2) + 1, len(out) // 2)
        for i in range(k):
            t = i / max(k, 1)
            out[i] = dense[i] * (1 - t) + out[i] * t
            out[-1 - i] = dense[-1 - i] * (1 - t) + out[-1 - i] * t
    return out


def smooth_stroke(pts, half, sigma, px):
    """A stroke's spine `pts` and widths `half` smoothed by `sigma` mm, and pulled out at each end along its way by that end's width -
    to the point its taper comes to."""
    path = smooth_path(pts, sigma, closed=False)
    h = np.interp(np.linspace(0, 1, len(path)), np.linspace(0, 1, len(half)), half)
    h = ndimage.gaussian_filter1d(h, max(sigma / 0.25, 1.0), mode="nearest")
    if len(path) >= 3:
        t0 = path[0] - path[min(4, len(path) - 1)]
        t1 = path[-1] - path[max(len(path) - 5, 0)]
        t0 /= max(np.linalg.norm(t0), 1e-9)
        t1 /= max(np.linalg.norm(t1), 1e-9)
        path = np.vstack([path[0] + t0 * h[0], path, path[-1] + t1 * h[-1]])
        h = np.concatenate([[h[0] * 0.25], h, [h[-1] * 0.25]])
    return path, h


def _nearly_straight(pts, tol):
    """Whether path `pts` (mm) strays no further than `tol` from the straight line between its ends, and is long enough to be a line."""
    a, b = pts[0], pts[-1]
    L = float(np.linalg.norm(b - a))
    if L < 6.0:
        return False
    d = np.abs((b[0] - a[0]) * (pts[:, 1] - a[1]) - (b[1] - a[1]) * (pts[:, 0] - a[0])) / L
    return float(d.max()) <= tol


def _chained(found, order, join, most=60.0):
    """LINES DRAWN ON WITHOUT LIFTING where one begins near where the last ended (`join` mm), as a crackle is drawn - each lifted and set
    down again, its cracks had taken longer than drawing them; none longer than `most` mm. The next always the nearest to where the hand
    is, by either of its ends - from the first of `order`."""
    if not found:
        return []
    starts = np.array([np.asarray(l["pts"])[0] for l in found])
    ends = np.array([np.asarray(l["pts"])[-1] for l in found])
    left = np.ones(len(found), bool)
    out = []
    cur = None
    at = starts[order[0]] if len(order) else starts[0]
    for _ in range(len(found)):
        d0 = np.where(left, np.linalg.norm(starts - at, axis=1), np.inf)
        d1 = np.where(left, np.linalg.norm(ends - at, axis=1), np.inf)
        j = int(np.argmin(np.minimum(d0, d1)))
        flip = d1[j] < d0[j]
        dist = min(d0[j], d1[j])
        left[j] = False
        pts, half = np.asarray(found[j]["pts"]), np.asarray(found[j]["half"])
        if flip:
            pts, half = pts[::-1], half[::-1]
        run = float(np.linalg.norm(np.diff(cur["pts"], axis=0), axis=1).sum()) if cur is not None else 0.0
        if cur is not None and dist <= join and run < most:
            cur = {"pts": np.vstack([cur["pts"], pts]), "half": np.concatenate([cur["half"], half]), "lab": cur["lab"]}
        else:
            if cur is not None:
                out.append(cur)
            cur = {"pts": pts, "half": half, "lab": found[j]["lab"]}
        at = pts[-1]
    out.append(cur)
    return out
