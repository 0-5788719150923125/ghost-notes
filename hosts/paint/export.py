"""WHAT THE PAINTER LAID, AS THE SHOW PLAYS IT (next/face_layers.md): the marks cut into elements - a run of one layer's marks with one
tool in one paint, as a hand works - and each element's program and maps, on one clock, so the tool the show moves and the paint that
appears under it can never drift apart.

THE PROGRAM is the show's own (src/table/skins.gd, `Skins._Prog.done()`): keys `[t, x, y, lift, press, where]` (millimeters over the
surface's frame; `where` 1 back at the pot) and strokes `{pts, t, r, load, press}`, at the show's own pace - the constants below are
`Skins`', line for line. THE MAPS are what skin_paint.gdshader draws an element from (PaintLayers.render's): what each point holds after
each of its first seven marks and after its last (`built`, `built_when`, 0-1 of the element's time), when it is first reached (`when`),
what it comes to (`cover`), and its color (`tint`) - the times half floats (a third of an episode's maps had been them) - the canvas before and after the element, so the element laid over what is under it
comes to exactly what the painter's canvas did.
"""
import json
from pathlib import Path

import numpy as np

from canvas import PX
from color import enc
from tools import TOOLS

# --- Skins' pace, line for line (src/table/skins.gd) -------------------------------------------------------------------------------
LINE_SPEED = 7.0
SWEEP_SPEED = 14.0
BLEND_SPEED = 16.0
CRACK_SPEED = 16.0
DOWN, UP, HOVER = 0.5, 0.45, 4.0
TRAVEL, TRAVEL_LEAST = 60.0, 0.35
LOOK, LOOK_LIFT, LOOK_EVERY = (0.6, 1.8), 9.0, 6
PULL_DOWN, PULL_UP, PULL_LIFT = 0.22, 0.2, 1.2
DAB, DAB_LIFT, DAB_MOVE = (0.16, 0.1, 0.16), 2.5, 70.0
RELOAD, RELOAD_LINE, RELOAD_SWEEP, RELOAD_DABS = 3.4, 110.0, 260.0, 16
PRESS_NARROW = 0.12
NEVER = 1000.0
DAB_MEETS = 0.18
SLOTS = 8

STROKES = {"sweep": SWEEP_SPEED, "glaze": SWEEP_SPEED, "shade": SWEEP_SPEED, "lipstick": SWEEP_SPEED, "dry_brush": SWEEP_SPEED,
           "scumble": SWEEP_SPEED, "line": LINE_SPEED, "pencil": LINE_SPEED, "crack": CRACK_SPEED, "flick": CRACK_SPEED,
           "feather": BLEND_SPEED, "wet_blend": BLEND_SPEED, "smudge": BLEND_SPEED, "lift": BLEND_SPEED, "soften": BLEND_SPEED}
PRESSES = ("pat", "stipple", "dab", "dot", "spatter", "sponge_blend")
# how the show names what an element does (Skins.PAINTER_HOWS' keys)
HOW = {"line": "line", "pencil": "line", "crack": "line", "flick": "line", "dab": "dab", "dot": "dab", "pat": "sponge",
       "stipple": "sponge", "spatter": "sponge", "sponge_blend": "sponge", "feather": "blend", "wet_blend": "blend", "smudge": "blend",
       "lift": "blend", "soften": "blend"}


class Program:
    """A hand's program as `Skins._Prog` writes one: where the tool is, lifted or down, pressed how hard; back to the pot."""

    def __init__(self):
        self.t = 0.0
        self.keys = []
        self.strokes = []
        self.at = None
        self.marks = 0
        self.used_mm = 0.0
        self.used_presses = 0

    def key(self, x, lift, press, where=0):
        self.keys.append([round(self.t, 4), float(x[0]), float(x[1]), float(lift), float(press), int(where)])

    def go(self, x, lift):
        if self.at is None:
            self.at = np.asarray(x, float)
            self.key(x, lift, 0.0)
            return
        d = float(np.linalg.norm(np.asarray(x) - self.at))
        if self.keys and self.keys[-1][3] < lift:
            self.t += UP
            self.key(self.at, lift, 0.0)
        self.t += max(d / TRAVEL, TRAVEL_LEAST)
        self.at = np.asarray(x, float)
        self.key(x, lift, 0.0)

    def trip_back(self):
        x = self.at if self.at is not None else np.zeros(2)
        self.t += UP
        self.key(x, HOVER * 3.0, 0.0)
        self.key(x, HOVER * 3.0, 0.0, 1)
        self.t += RELOAD
        self.key(x, HOVER * 3.0, 0.0, 1)
        self.t += 0.01
        self.key(x, HOVER * 3.0, 0.0)
        self.used_mm = 0.0
        self.used_presses = 0

    def stroke(self, pts, speed, r, press, reload_mm, clean):
        """A pull along `pts` at `speed`, pressed `press` a point: its points' times."""
        pts = np.asarray(pts, float)
        length = float(np.linalg.norm(np.diff(pts, axis=0), axis=1).sum())
        if not clean and self.used_mm + length > reload_mm and self.marks > 0:
            self.trip_back()
        self.go(pts[0], HOVER)
        self.t += PULL_DOWN
        self.key(pts[0], 0.0, press[0])
        ts = [self.t]
        along = 0.0
        for k in range(1, len(pts)):
            d = float(np.linalg.norm(pts[k] - pts[k - 1]))
            u = (along + d * 0.5) / max(length, 1e-3)
            along += d
            self.t += d / (speed * ((0.55 + 0.45 * np.sin(np.pi * u)) / 0.84))
            self.key(pts[k], 0.0, press[k])
            ts.append(self.t)
        self.strokes.append({"pts": pts.tolist(), "t": [round(v, 4) for v in ts], "r": float(r), "load": [1.0] * len(pts),
                             "press": [float(v) for v in press]})
        self.at = pts[-1]
        self.used_mm += length
        self.marks += 1
        look = self.marks % LOOK_EVERY == 0
        self.t += UP if look else PULL_UP
        self.key(self.at, HOVER if look else PULL_LIFT, 0.0)
        if look:
            self.t += 0.5 * (LOOK[0] + LOOK[1])
            self.key(self.at, LOOK_LIFT, 0.0)
        return ts

    def press(self, c, r, press, per_load, clean):
        """A press at `c`: when it comes down."""
        if not clean and self.used_presses >= per_load and self.marks > 0:
            self.trip_back()
        c = np.asarray(c, float)
        if self.at is None:
            self.key(c, DAB_LIFT, 0.0)
        else:
            self.t += max(float(np.linalg.norm(c - self.at)) / DAB_MOVE, 0.08)
            self.key(c, DAB_LIFT, 0.0)
        self.at = c
        self.t += DAB[0]
        self.key(c, 0.0, press)
        t_down = self.t
        self.strokes.append({"pts": [c.tolist()], "t": [round(t_down, 4)], "r": float(r), "load": [1.0], "press": [float(press)]})
        self.t += DAB[1]
        self.key(c, 0.0, press)
        self.t += DAB[2]
        self.key(c, DAB_LIFT, 0.0)
        self.used_presses += 1
        self.marks += 1
        return t_down

    def done(self):
        if not self.keys:
            self.key((0.0, 0.0), HOVER, 0.0)
        return {"keys": self.keys, "strokes": self.strokes, "stones": [], "pats": [], "mists": [], "natural": max(self.t, 0.1)}


def groups(p, starts):
    """The painter's marks cut into elements: each run of one layer's marks with one tool in one paint, in order."""
    out = []
    bounds = list(starts) + [len(p.laid)]
    for li in range(len(starts)):
        cur = None
        for idx in range(bounds[li], bounds[li + 1]):
            m = p.laid[idx][0]
            key = (li, m.tool, m.paint or "")
            if cur is None or cur["key"] != key:
                cur = {"key": key, "layer": li, "tool": m.tool, "paint": m.paint or "", "marks": []}
                out.append(cur)
            cur["marks"].append(idx)
    return out


def _press_of(hw, r):
    return np.clip((np.asarray(hw, float) / max(r, 1e-3) - PRESS_NARROW) / (1.0 - PRESS_NARROW), 0.0, 1.0)


def _pixel_times(m, sl, ts_pts, pts):
    """Each pixel of `sl`'s time along stroke `pts` (its points' times `ts_pts`): its nearest point's, along the way."""
    from marks import grid, path_field, resample
    pts = np.asarray(pts, float)
    if len(pts) < 2:
        X, _ = grid(sl)
        return np.full(X.shape, ts_pts[0])
    dense, s, k = resample(pts, 0.2)
    td = np.interp(k, np.arange(len(pts)), ts_pts)
    _, i, _ = path_field(dense, sl)
    return td[i]


def export(p, starts, steps, out, log=print):
    """THE ELEMENTS, written to `out`: `elements.json` and each one's maps (`maps/`), replaying the painter's marks on a fresh canvas."""
    out = Path(out)
    (out / "maps").mkdir(parents=True, exist_ok=True)
    H, W = p.cv.h, p.cv.w
    pre = np.zeros((H, W, 3))
    alp = np.zeros((H, W))
    els = []
    for gi, g in enumerate(groups(p, starts)):
        marks = [p.laid[i][0] for i in g["marks"]]
        tool = g["tool"]
        r = TOOLS.get(tool, {"mm": 6.0})["mm"] * 0.5
        clean = not g["paint"]
        # (...its program, on the show's pace)
        prog = Program()
        times = []
        kinds = set()
        for m in marks:
            kinds.add(m.kind)
            rec = m.rec
            if m.kind in PRESSES or "pts" not in rec:
                c = rec.get("c", m.pts[0] if len(m.pts) else (0.0, 0.0))
                rr = float(rec.get("r", r))
                per = 26 if tool == "sponge" else RELOAD_DABS
                times.append(("press", prog.press(c, rr, float(rec.get("press", 1.0)), per, clean)))
            else:
                pts = np.asarray(rec["pts"], float)
                hw = rec.get("half_w", r)
                hw = np.broadcast_to(np.asarray(hw, float), (len(pts),)) if np.ndim(hw) == 0 or len(np.ravel(hw)) != len(pts) else np.asarray(hw)
                speed = STROKES.get(m.kind, SWEEP_SPEED)
                reload_mm = RELOAD_LINE if speed in (LINE_SPEED, CRACK_SPEED) else RELOAD_SWEEP
                ts = prog.stroke(pts, speed, r, _press_of(hw, r), reload_mm, clean)
                times.append(("stroke", ts, pts))
        program = prog.done()
        natural = program["natural"]
        # (...its maps: the canvas before it and after, each point's marks counted, then laid again a mark at a time)
        y0 = min(m.sl[0].start for m in marks)
        y1 = max(m.sl[0].stop for m in marks)
        x0 = min(m.sl[1].start for m in marks)
        x1 = max(m.sl[1].stop for m in marks)
        box = (slice(y0, y1), slice(x0, x1))
        pre0, alp0 = pre[box].copy(), alp[box].copy()
        n = np.zeros((y1 - y0, x1 - x0), np.int32)
        for m in marks:
            sy, sx = slice(m.sl[0].start - y0, m.sl[0].stop - y0), slice(m.sl[1].start - x0, m.sl[1].stop - x0)
            ch = (np.abs(m.pre - pre[m.sl]).sum(-1) + np.abs(m.alp - alp[m.sl])) > 1e-3
            n[sy, sx] += ch
            pre[m.sl], alp[m.sl] = m.pre, m.alp
        pre1, alp1 = pre[box].copy(), alp[box].copy()
        pre[box], alp[box] = pre0, alp0
        st_t = np.full((y1 - y0, x1 - x0, SLOTS), NEVER, np.float32)
        st_c = np.zeros((y1 - y0, x1 - x0, SLOTS), np.float32)
        k = np.zeros((y1 - y0, x1 - x0), np.int32)
        for m, tm in zip(marks, times):
            sy, sx = slice(m.sl[0].start - y0, m.sl[0].stop - y0), slice(m.sl[1].start - x0, m.sl[1].stop - x0)
            ch = (np.abs(m.pre - pre[m.sl]).sum(-1) + np.abs(m.alp - alp[m.sl])) > 1e-3
            if ch.any():
                if tm[0] == "press":
                    tpx = np.full(ch.shape, tm[1] + DAB_MEETS)
                else:
                    tpx = _pixel_times(m, m.sl, tm[1], tm[2])
                u = (tpx / natural).astype(np.float32)
                kk = k[sy, sx]
                nn = np.maximum(n[sy, sx], 1)
                prog_ = (kk + 1) / nn
                for j in range(SLOTS - 1):
                    sel = ch & (kk == j)
                    st_t[sy, sx, j][sel] = u[sel]
                    st_c[sy, sx, j][sel] = prog_[sel]
                st_t[sy, sx, SLOTS - 1][ch] = u[ch]
                k[sy, sx] += ch
            pre[m.sl], alp[m.sl] = m.pre, m.alp
        # (...what it comes to, and its color: laid over what was under it, exactly the painter's canvas)
        dpre = np.abs(pre1 - pre0).max(-1)
        a_alpha = np.where(alp0 < 0.999, np.clip((alp1 - alp0) / np.maximum(1 - alp0, 1e-6), 0, 1), 0.0)
        a_color = np.clip((dpre - 0.004) / 0.03, 0, 1)
        # (...the color's own change counted only over paint all but whole: over a thin coat it had stood in for the coverage, and a half
        # laid white came out a whole grey - 327484's ground a field of grey dabs)
        a = np.where(alp0 < 0.95, a_alpha, np.maximum(a_alpha, a_color))
        a = np.where(n > 0, a, 0.0)
        col = np.where(a[..., None] > 1e-4, (pre1 - pre0 * (1 - a[..., None])) / np.maximum(a[..., None], 1e-4), 0.0)
        col = np.clip(col, 0, 1)
        # (...slots no mark filled are the one before; the last what it holds at the end, at its last mark)
        for j in range(1, SLOTS - 1):
            empty = k <= j
            st_t[..., j] = np.where(empty, st_t[..., j - 1], st_t[..., j])
            st_c[..., j] = np.where(empty, st_c[..., j - 1], st_c[..., j])
        st_c *= a[..., None]
        st_c[..., SLOTS - 1] = a
        first = st_t[..., 0]
        when = np.stack([first, np.ones_like(first), np.full_like(first, NEVER)], -1).astype(np.float32)
        name = "el_%03d" % gi
        h, w = y1 - y0, x1 - x0
        maps = {"w": int(w), "h": int(h)}

        def put(tag, arr):
            f = "maps/%s_%s.bin" % (name, tag)
            arr.astype(arr.dtype).tofile(out / f)
            maps[tag] = f

        put("cover", (np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8))
        put("when", when.astype(np.float16))
        put("built0", (np.clip(st_c[..., :4], 0, 1) * 255 + 0.5).astype(np.uint8))
        put("built1", (np.clip(st_c[..., 4:], 0, 1) * 255 + 0.5).astype(np.uint8))
        put("built_when0", st_t[..., :4].astype(np.float16))
        put("built_when1", st_t[..., 4:].astype(np.float16))
        put("tint", (col * 255 + 0.5).astype(np.uint8))
        how = "sweep"
        for kd in kinds:
            if kd in HOW:
                how = HOW[kd]
                break
        if g["layer"] == 0:
            how = "sponge"
        color = p._color(g["paint"]) if g["paint"] else np.array([1.0, 1.0, 1.0])
        els.append({"id": name, "layer": int(g["layer"]), "layer_name": steps[g["layer"]].get("name", ""), "tool": tool,
                    "paint": g["paint"], "color": "#%02x%02x%02x" % tuple(int(round(v * 255)) for v in np.clip(color, 0, 1)),
                    "how": how, "rect": [x0 / PX, y0 / PX, w / PX, h / PX], "marks": len(marks), "seconds": round(natural, 2),
                    "maps": maps, "program": program})
    (out / "elements.json").write_text(json.dumps({"px": PX, "elements": els}))
    log("  exported %d elements, %.1f min of painting" % (len(els), sum(e["seconds"] for e in els) / 60))
    return els
