"""WHAT THE PAINTER LAID, AS THE SHOW PLAYS IT (next/face_layers.md): the marks cut into elements - a run of one layer's marks with one
tool in one paint, as a hand works - and each element's program and maps, on one clock, so the tool the show moves and the paint that
appears under it can never drift apart.

THE PROGRAM is the show's own (src/table/skins.gd, `Skins._Prog.done()`): keys `[t, x, y, lift, press, where]` (millimeters over the
surface's frame; `where` 1 back at the pot) and strokes `{pts, t, r, load, press}` (a press's also `side`, "face" or "corner"), at
the show's own pace - the constants below are `Skins`', line for line. THE MAPS are what skin_paint.gdshader draws an element from (PaintLayers.render's): what each point holds after
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
# A LOAD ONLY RUNS OUT (feedback 0006, 2026-11-09: "This brush just went from painting very faint, almost imperceptable yellow strokes
# ... to an extremely dark yellow stroke ... applied without ever returning to the container, to pickup a heavier load. Logically, it
# makes no sense"): the optimizer finds each pull's strength on its own (its `th`), 0.06 to whole, and one load laid them in any order. A
# pull laying more than the last since the brush was loaded by this much (of a whole stroke's strength) goes back to the pot first -
# pressed harder accounts for less. Only the trips change: the marks, their order and what they lay are the painter's.
LOAD_HEAVIER = 0.2
PRESS_NARROW = 0.12
NEVER = 1000.0
DAB_MEETS = 0.18
SLOTS = 8

STROKES = {"sweep": SWEEP_SPEED, "glaze": SWEEP_SPEED, "shade": SWEEP_SPEED, "lipstick": SWEEP_SPEED, "dry_brush": SWEEP_SPEED,
           "scumble": SWEEP_SPEED, "line": LINE_SPEED, "pencil": LINE_SPEED, "crack": CRACK_SPEED, "flick": CRACK_SPEED,
           "feather": BLEND_SPEED, "wet_blend": BLEND_SPEED, "smudge": BLEND_SPEED, "lift": BLEND_SPEED, "soften": BLEND_SPEED}
PRESSES = ("pat", "stipple", "dab", "dot", "spatter", "sponge_blend", "blot")
# how the show names what an element does (Skins.PAINTER_HOWS' keys)
HOW = {"line": "line", "pencil": "line", "crack": "line", "flick": "line", "dab": "dab", "dot": "dab", "pat": "sponge",
       "stipple": "sponge", "spatter": "sponge", "sponge_blend": "sponge", "feather": "blend", "wet_blend": "blend", "smudge": "blend",
       "lift": "blend", "soften": "blend", "blot": "dab"}


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
        self.last_strength = None    # what the last pull since the brush was loaded laid (LOAD_HEAVIER)

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
        self.last_strength = None

    def stroke(self, pts, speed, r, press, reload_mm, clean, strength=None):
        """A pull along `pts` at `speed`, pressed `press` a point, laying `strength` (its paint's, 0-1; None unknown): its points' times.
        Back to the pot first when its load would have run out by then - by the way it has gone, or by laying more than the last pull
        could have left on it (LOAD_HEAVIER)."""
        pts = np.asarray(pts, float)
        length = float(np.linalg.norm(np.diff(pts, axis=0), axis=1).sum())
        heavier = strength is not None and self.last_strength is not None and strength > self.last_strength + LOAD_HEAVIER
        if not clean and self.marks > 0 and (self.used_mm + length > reload_mm or heavier):
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
        if strength is not None:
            self.last_strength = float(strength)
        look = self.marks % LOOK_EVERY == 0
        self.t += UP if look else PULL_UP
        self.key(self.at, HOVER if look else PULL_LIFT, 0.0)
        if look:
            self.t += 0.5 * (LOOK[0] + LOOK[1])
            self.key(self.at, LOOK_LIFT, 0.0)
        return ts

    def press(self, c, r, press, per_load, clean, side="face"):
        """A press at `c` by the tool's `side` ("face" or "corner"): when it comes down."""
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
        self.strokes.append({"pts": [c.tolist()], "t": [round(t_down, 4)], "r": float(r), "load": [1.0], "press": [float(press)], "side": side})
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


# --- the hand's order ----------------------------------------------------------------------------------------------------------------

# A PULL TURNED THE OTHER WAY, AND PULLS GATHERED BY THE WAY THEY GO (feedback 0016, 2026-11-09: "This brush is flipping and twirling and
# twisting and repositioning and it just looks chaotic. A real artist would prefer keep a neutral position, and only reposition when the
# stroke requires it. They might choose to batch certain strokes from certain directions, before repositioning to work on strokes from
# other directions"): the optimizer's pulls run whichever way it found them - in 732687 a flat's, a round's and a liner's next pull ran
# the other way to the last a quarter to a third of the time (31%, 32%, 23%), 89 degrees between pulls on average - and the show leans a
# brush the way it is pulled, so its handle was thrown from side to side. A pull whose paint is laid alike at both ends is drawn the way
# nearest the one before it (where they are about parallel: within HEADING_SAME), else up the face and out to its side, the way the show
# holds a brush (src/table/table_paint.gd, HELD_OUT) - 36 degrees between them on average; and a run of such pulls laid in bins of
# HEADING_BIN degrees of the way they go, the one first come to first, each swept across - the same paint over itself, in any order, is
# what it was. A pull whose ends differ (a tail, a load running out: ENDS_ALIKE) keeps its own way and place.
HEADING_SAME = 0.5
HEADING_BIN = 45.0
# ...each place swept so before the next (pulls whose middles lie within PLACE_MM of one another, one to the next, are a place), the
# places in the order the hand comes to them from the first.
PLACE_MM = 12.0
ENDS_ALIKE = 0.85
RECOVER_MOST = 0.01


def _places(mids, near):
    """Points `mids` (mm) gathered into places - each point within `near` of another of its place, one to the next - the places toured
    from the first point's, the next always the one nearest the last's middle: `[[indices]]`."""
    n = len(mids)
    if n == 0:
        return []
    P = np.asarray(mids, float)
    left = set(range(n))
    groups = []
    while left:
        seed = min(left)
        grp, edge = [seed], [seed]
        left.discard(seed)
        while edge:
            k = edge.pop()
            close = [t for t in left if float(np.linalg.norm(P[t] - P[k])) <= near]
            for t in close:
                left.discard(t)
                grp.append(t)
                edge.append(t)
        groups.append(sorted(grp))
    out = [groups.pop(0)]
    while groups:
        at = P[out[-1]].mean(axis=0)
        k = int(np.argmin([float(np.linalg.norm(P[g].mean(axis=0) - at)) for g in groups]))
        out.append(groups.pop(k))
    return out


def _hand_order(marks, pre, alp, col, width_mm):
    """AN ELEMENT'S MARKS AS A HAND LAYS THEM (above): each pull drawn the way that turns least from the last, and runs of pulls gathered
    by the way they go - laid again in that order over the canvas before the element (`pre`, `alp`), each its own coverage of `col`
    recovered from the painter's canvas before and after it (`Canvas.over`), so the maps are staged from the order the program plays.
    The marks as they were where any of them is not paint `col` laid over (a clean brush, a blend), or their own coverage cannot be
    recovered to RECOVER_MOST. -> the marks (new ones where changed; the painter's own are never touched)."""
    import dataclasses
    from marks import path_field, resample
    if col is None or len(marks) < 2:
        return marks
    col = np.asarray(col, float)
    y0 = min(m.sl[0].start for m in marks)
    y1 = max(m.sl[0].stop for m in marks)
    x0 = min(m.sl[1].start for m in marks)
    x1 = max(m.sl[1].stop for m in marks)
    wp, wa = pre[y0:y1, x0:x1].copy(), alp[y0:y1, x0:x1].copy()
    own, free = [], []
    for m in marks:
        loc = (slice(m.sl[0].start - y0, m.sl[0].stop - y0), slice(m.sl[1].start - x0, m.sl[1].stop - x0))
        b_pre, b_alp = wp[loc], wa[loc]
        # (...its own coverage: by how much nearer whole it made the canvas, else - over paint already whole - how far toward `col`)
        to = col - b_pre
        tt = (to * to).sum(-1)
        by_col = np.where(tt > 1e-4, ((m.pre - b_pre) * to).sum(-1) / np.maximum(tt, 1e-4), 0.0)
        a = np.clip(np.where(b_alp < 0.999, (m.alp - b_alp) / np.maximum(1.0 - b_alp, 1e-6), by_col), 0.0, 1.0)
        r_pre = col * a[..., None] + b_pre * (1.0 - a[..., None])
        r_alp = a + b_alp * (1.0 - a)
        if max(float(np.abs(r_pre - m.pre).max()), float(np.abs(r_alp - m.alp).max())) > RECOVER_MOST:
            return marks
        own.append(a)
        # (...a pull, laid alike at both ends: as much of it in its first quarter as in its last, along its middle - and pressed alike)
        ok = False
        rec = m.rec
        if m.kind not in PRESSES and "pts" in rec and len(rec["pts"]) >= 2:
            pts = np.asarray(rec["pts"], float)
            hw = np.asarray(rec.get("half_w", 1.0), float)
            hw = np.broadcast_to(hw, (len(pts),)) if hw.ndim == 0 or len(np.ravel(hw)) != len(pts) else hw
            if float(np.linalg.norm(pts[-1] - pts[0])) >= 1.0 and float(np.abs(hw - hw[::-1]).max()) <= 0.15 * max(float(hw.max()), 1e-3):
                dense, s, k = resample(pts, 0.2)
                d, i, _ = path_field(dense, m.sl)
                u = s[i] / max(float(s[-1]), 1e-6)
                core = d <= 0.8 * np.interp(k[i], np.arange(len(hw)), hw)
                a0, a1 = a[core & (u < 0.25)], a[core & (u > 0.75)]
                if len(a0) >= 6 and len(a1) >= 6:
                    m0, m1 = float(a0.mean()), float(a1.mean())
                    ok = max(m0, m1) > 0.05 and min(m0, m1) >= ENDS_ALIKE * max(m0, m1)
        free.append(ok)
        wp[loc], wa[loc] = m.pre, m.alp
    # THE ORDER: each run of pulls that may turn, gathered by the way they go - the way first come to first, swept across it
    heads = []
    for m in marks:
        pts = np.asarray(m.rec.get("pts", [[0.0, 0.0]]), float)
        heads.append(float(np.degrees(np.arctan2(pts[-1, 1] - pts[0, 1], pts[-1, 0] - pts[0, 0]))) % 180.0 if len(pts) >= 2 else 0.0)
    order = []
    i = 0
    while i < len(marks):
        if not free[i]:
            order.append(i)
            i += 1
            continue
        j = i
        while j < len(marks) and free[j]:
            j += 1
        run = list(range(i, j))
        # (...A PLACE AT A TIME, the places toured ([PLACE_MM]; 2026-11-10, the user: "They tend to jump around the entire face, to random
        # places"): gathered by the way they go over a whole run, a run of gold seams from the brow to the jaw had been swept across the
        # face once for each way)
        for place in _places([np.asarray(marks[q].rec["pts"], float).mean(axis=0) for q in run], PLACE_MM):
            bins = {}
            for t in place:
                q = run[t]
                bins.setdefault(int(((heads[q] + HEADING_BIN * 0.5) % 180.0) // HEADING_BIN), []).append(q)
            for b, qs in bins.items():
                ang = np.radians(b * HEADING_BIN)
                across = np.array([-np.sin(ang), np.cos(ang)])
                mids = [np.asarray(marks[q].rec["pts"], float).mean(axis=0) for q in qs]
                order.extend(q for _, q in sorted(zip([float(np.dot(c, across)) for c in mids], qs)))
        i = j
    # THE WAY EACH IS DRAWN: about parallel to the last, as it went; else up the face and out to its side
    out = []
    last = None
    for q in order:
        m = marks[q]
        if free[q]:
            pts = np.asarray(m.rec["pts"], float)
            v = pts[-1] - pts[0]
            v = v / max(float(np.linalg.norm(v)), 1e-9)
            mid = pts.mean(axis=0)
            pref = np.array([0.5 * np.sign(mid[0] - width_mm * 0.5), -1.0])
            pref = pref / np.linalg.norm(pref)
            ref = last if last is not None and abs(float(np.dot(v, last))) >= HEADING_SAME else pref
            if float(np.dot(v, ref)) < 0.0:
                rec = dict(m.rec)
                rec["pts"] = pts[::-1].tolist()
                hw = m.rec.get("half_w")
                if hw is not None and np.ndim(hw) > 0:
                    rec["half_w"] = list(np.asarray(hw)[::-1])
                for key in ("press", "th"):
                    if key in m.rec and np.ndim(m.rec[key]) > 0 and len(np.ravel(m.rec[key])) == len(pts):
                        rec[key] = list(np.asarray(m.rec[key])[::-1])
                m = dataclasses.replace(m, rec=rec, pts=np.asarray(m.pts)[::-1].copy() if np.ndim(m.pts) == 2 else m.pts)
                v = -v
            last = v
        out.append((q, m))
    if [q for q, _ in out] == list(range(len(marks))):
        return [m for _, m in out]
    # ...LAID AGAIN IN THAT ORDER over the canvas before the element: each mark's canvas after it, as the maps are staged from
    wp, wa = pre[y0:y1, x0:x1].copy(), alp[y0:y1, x0:x1].copy()
    laid = []
    for q, m in out:
        loc = (slice(m.sl[0].start - y0, m.sl[0].stop - y0), slice(m.sl[1].start - x0, m.sl[1].stop - x0))
        a = own[q]
        n_pre = col * a[..., None] + wp[loc] * (1.0 - a[..., None])
        n_alp = a + wa[loc] * (1.0 - a)
        wp[loc], wa[loc] = n_pre, n_alp
        laid.append(dataclasses.replace(m, pre=n_pre, alp=n_alp))
    return laid


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


def recompose(els, root, shape, order=None):
    """The elements' maps laid in `order` (all of them, as listed, by default) as the shader lays them: color over what is under it by
    coverage (pre-multiplied). -> (pre, alp): the canvas they leave - what a layer painted again alone is painted over (run.py)."""
    pre = np.zeros(tuple(shape) + (3,))
    alp = np.zeros(tuple(shape))
    for i in (range(len(els)) if order is None else order):
        e = els[i]
        m = e["maps"]
        w, h = m["w"], m["h"]
        x0, y0 = int(round(e["rect"][0] * PX)), int(round(e["rect"][1] * PX))
        a = np.fromfile(Path(root) / m["cover"], np.uint8).reshape(h, w) / 255.0
        c = np.fromfile(Path(root) / m["tint"], np.uint8).reshape(h, w, 3) / 255.0
        box = (slice(y0, y0 + h), slice(x0, x0 + w))
        pre[box] = c * a[..., None] + pre[box] * (1 - a[..., None])
        alp[box] = a + alp[box] * (1 - a)
    return pre, alp


def merge_layer(kept, kept_root, fresh, fresh_root, layer, out):
    """ONE LAYER PAINTED AGAIN, PUT AMONG THE REST (next/editing.md step 4: "The painter host solves one layer and replaces only that
    layer's elements"): `kept` the elements as they stood (their maps under `kept_root`), `fresh` the layer's new ones (under
    `fresh_root`); the kept layer's own go, the new take their place between the layers before and after it, each new one an id past
    every kept one (and its maps renamed with it), every kept one's maps copied as they were. Writes `out/elements.json`. -> the list."""
    import shutil
    out = Path(out)
    (out / "maps").mkdir(parents=True, exist_ok=True)
    before = [e for e in kept if int(e["layer"]) < layer]
    after = [e for e in kept if int(e["layer"]) > layer]
    for e in before + after:
        for tag, f in e["maps"].items():
            if isinstance(f, str) and (Path(kept_root) / f).resolve() != (out / f).resolve():
                shutil.copyfile(Path(kept_root) / f, out / f)
    top = max([int(str(e["id"]).split("_")[-1]) for e in kept if str(e["id"]).split("_")[-1].isdigit()] + [-1])
    renamed = []
    for k, e in enumerate(fresh):
        e = json.loads(json.dumps(e))
        name = "el_%03d" % (top + 1 + k)
        for tag, f in list(e["maps"].items()):
            if isinstance(f, str):
                nf = "maps/%s_%s.bin" % (name, tag)
                shutil.copyfile(Path(fresh_root) / f, out / nf)
                e["maps"][tag] = nf
        e["id"] = name
        renamed.append(e)
    els = before + renamed + after
    (out / "elements.json").write_text(json.dumps({"px": PX, "elements": els}))
    return els


def export(p, starts, steps, out, log=print, canvas=None, base_layer=0):
    """THE ELEMENTS, written to `out`: `elements.json` and each one's maps (`maps/`), replaying the painter's marks on a fresh canvas -
    or on `canvas` ((pre, alp)), where only some of the layers were painted again over the ones before them (layers_paint.paint_layers)."""
    out = Path(out)
    (out / "maps").mkdir(parents=True, exist_ok=True)
    H, W = p.cv.h, p.cv.w
    pre = np.zeros((H, W, 3)) if canvas is None else np.array(canvas[0], float)
    alp = np.zeros((H, W)) if canvas is None else np.array(canvas[1], float)
    els = []
    for gi, g in enumerate(groups(p, starts)):
        marks = [p.laid[i][0] for i in g["marks"]]
        tool = g["tool"]
        r = TOOLS.get(tool, {"mm": 6.0})["mm"] * 0.5
        clean = not g["paint"]
        # (...in the order a hand lays them, each pull the way nearest the last: _hand_order)
        marks = _hand_order(marks, pre, alp, None if clean else p._color(g["paint"]), W / PX)
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
                # (...by the side it was pressed with, which the show holds it by - a face print patted flat, never tipped onto a corner)
                side = "corner" if rec.get("corner") else "face"
                times.append(("press", prog.press(c, rr, float(rec.get("press", 1.0)), per, clean, side)))
            else:
                pts = np.asarray(rec["pts"], float)
                hw = rec.get("half_w", r)
                hw = np.broadcast_to(np.asarray(hw, float), (len(pts),)) if np.ndim(hw) == 0 or len(np.ravel(hw)) != len(pts) else np.asarray(hw)
                speed = STROKES.get(m.kind, SWEEP_SPEED)
                reload_mm = RELOAD_LINE if speed in (LINE_SPEED, CRACK_SPEED) else RELOAD_SWEEP
                # (...as strong as the painter laid it: its paint's thickness, times what was on the brush - LOAD_HEAVIER)
                th = rec.get("th")
                strength = float(np.mean(th)) * float(rec.get("load", 1.0)) if th is not None and np.size(th) > 0 else None
                ts = prog.stroke(pts, speed, r, _press_of(hw, r), reload_mm, clean, strength)
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
        d, dal = pre1 - pre0, alp1 - alp0
        dd = (d * d).sum(-1)
        st_t = np.full((y1 - y0, x1 - x0, SLOTS), NEVER, np.float32)
        st_c = np.zeros((y1 - y0, x1 - x0, SLOTS), np.float32)
        k = np.zeros((y1 - y0, x1 - x0), np.int32)
        for m, tm in zip(marks, times):
            sy, sx = slice(m.sl[0].start - y0, m.sl[0].stop - y0), slice(m.sl[1].start - x0, m.sl[1].stop - x0)
            ch = (np.abs(m.pre - pre[m.sl]).sum(-1) + np.abs(m.alp - alp[m.sl])) > 1e-3
            pre[m.sl], alp[m.sl] = m.pre, m.alp
            if ch.any():
                if tm[0] == "press":
                    tpx = np.full(ch.shape, tm[1] + DAB_MEETS)
                else:
                    tpx = _pixel_times(m, m.sl, tm[1], tm[2])
                u = (tpx / natural).astype(np.float32)
                kk = k[sy, sx]
                # (...EACH MARK'S SHARE OF THE ELEMENT'S CHANGE IS WHAT THE PAINTER'S CANVAS HOLDS AFTER IT, projected onto that change -
                # feedback 0015, 2026-11-09: "one of the regions it paints over turns much LIGHTER, even though that region had purple
                # paint on it already": shared out by how many marks touch a point, a pull's first pass over a point a second would
                # cross showed half the element's color, a pale patch inside 732687's dark streak, where the painter had laid it all
                # but whole. Where the color hardly changes, the coverage's share; where neither does, the count's.)
                dj, ddj, dalj = d[sy, sx], dd[sy, sx], dal[sy, sx]
                by_color = np.clip(((pre[m.sl] - pre0[sy, sx]) * dj).sum(-1) / np.maximum(ddj, 1e-6), 0, 1)
                by_cover = np.clip((alp[m.sl] - alp0[sy, sx]) / np.maximum(dalj, 1e-6), 0, 1)
                by_count = (kk + 1) / np.maximum(n[sy, sx], 1)
                share = np.where(ddj > 1e-4, by_color, np.where(dalj > 1e-3, by_cover, by_count))
                for j in range(SLOTS - 1):
                    sel = ch & (kk == j)
                    st_t[sy, sx, j][sel] = u[sel]
                    st_c[sy, sx, j][sel] = share[sel]
                st_t[sy, sx, SLOTS - 1][ch] = u[ch]
                k[sy, sx] += ch
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
        # (...the base pressed on with a sponge - `base_layer`, which of `steps` it is: none where only later layers are painted again, whose
        # first had been called the base, a liner's outline played as a sponge's stipple)
        if g["layer"] == base_layer:
            how = "sponge"
        color = p._color(g["paint"]) if g["paint"] else np.array([1.0, 1.0, 1.0])
        els.append({"id": name, "layer": int(g["layer"]), "layer_name": steps[g["layer"]].get("name", ""), "tool": tool,
                    "paint": g["paint"], "color": "#%02x%02x%02x" % tuple(int(round(v * 255)) for v in np.clip(color, 0, 1)),
                    "how": how, "rect": [x0 / PX, y0 / PX, w / PX, h / PX], "marks": len(marks), "seconds": round(natural, 2),
                    "maps": maps, "program": program})
    (out / "elements.json").write_text(json.dumps({"px": PX, "elements": els}))
    log("  exported %d elements, %.1f min of painting" % (len(els), sum(e["seconds"] for e in els) / 60))
    return els
