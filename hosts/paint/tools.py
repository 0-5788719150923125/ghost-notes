"""The tools and the hand's time, in the painting lab (TEST_PLAN.md).

THE TABLE'S TOOLS (joker-motivation's brush tray and sponge dish, their sizes as the table builds them) and THE LAB'S OWN - a
lipstick, a pencil, a brush handle, a cotton bud, a fingertip - which no table has yet: the lab tries them all, so we learn which are
worth adding (`table: False`).

THE HAND'S TIME is the show's (Skins: a careful 7 mm/s line, 14 mm/s sweeps, a dab's 0.42 s, 3.4 s back to the pot, 60 mm/s between
marks), so the painting's minutes here are the video's minutes there. Each behavior: how fast it moves, how long it takes to come down
and lift, and how far a load lasts.
"""
import numpy as np

TOOLS = {
    "sponge":   {"kind": "sponge", "mm": 30.0, "table": True},
    "round":    {"kind": "brush", "mm": 6.0, "table": True},
    "flat":     {"kind": "brush", "mm": 10.0, "table": True},
    "liner":    {"kind": "brush", "mm": 2.0, "table": True},
    "blender":  {"kind": "brush", "mm": 16.0, "table": True},
    "fan":      {"kind": "brush", "mm": 12.0, "table": True},
    "lipstick": {"kind": "lipstick", "mm": 4.0, "table": False},
    "pencil":   {"kind": "pencil", "mm": 0.8, "table": False},
    "handle":   {"kind": "handle", "mm": 1.6, "table": False},
    "bud":      {"kind": "bud", "mm": 5.0, "table": False},
    "finger":   {"kind": "finger", "mm": 12.0, "table": False},
}

# Each behavior: speed along the surface (mm/s), coming down and lifting (s), a press's hold (s), how far a load lasts - in mm of
# path, or presses - and what it is for (the painter chooses by what a region of the picture shows - solve.py).
BEHAVIORS = {
    "pat":          {"speed": 0, "down": 0.16, "up": 0.16, "hold": 0.1, "load_presses": 26, "for": "even coverage, the foundation"},
    "stipple":      {"speed": 0, "down": 0.12, "up": 0.12, "hold": 0.06, "load_presses": 40, "for": "speckle, soft texture, haze"},
    "sweep":        {"speed": 14, "down": 0.22, "up": 0.2, "load_mm": 260, "for": "shapes and areas"},
    "glaze":        {"speed": 16, "down": 0.22, "up": 0.2, "load_mm": 320, "for": "thin tints and shading"},
    "double_load":  {"speed": 12, "down": 0.25, "up": 0.2, "load_mm": 200, "for": "a gradient in one pass"},
    "lipstick":     {"speed": 12, "down": 0.25, "up": 0.2, "load_mm": 1e9, "for": "lips: opaque, even"},
    "line":         {"speed": 7, "down": 0.22, "up": 0.2, "load_mm": 110, "for": "outlines, lash lines, crackle"},
    "crack":        {"speed": 16, "down": 0.12, "up": 0.1, "load_mm": 160, "for": "a crackle's short lines, flicked on"},
    "flick":        {"speed": 18, "down": 0.15, "up": 0.1, "load_mm": 150, "for": "tapered lines: lashes, branches, drips"},
    "pencil":       {"speed": 10, "down": 0.2, "up": 0.15, "load_mm": 1e9, "for": "grainy lines: brows, lash lines, outlines"},
    "dab":          {"speed": 0, "down": 0.16, "up": 0.16, "hold": 0.1, "load_presses": 14, "for": "soft dots, highlights"},
    "dot":          {"speed": 0, "down": 0.2, "up": 0.2, "hold": 0.1, "load_presses": 6, "for": "round crisp dots: jewels, studs"},
    "dry_brush":    {"speed": 25, "down": 0.15, "up": 0.15, "load_mm": 180, "for": "streaks: scratches, rust, grain"},
    "scumble":      {"speed": 20, "down": 0.2, "up": 0.2, "load_mm": 200, "for": "a broken veil, weathering"},
    "spatter":      {"speed": 0, "down": 0.35, "up": 0.35, "hold": 0.1, "load_presses": 4, "for": "speckles, flecks, noise round an edge"},
    "feather":      {"speed": 16, "down": 0.22, "up": 0.2, "for": "an edge made a gradient"},
    "wet_blend":    {"speed": 14, "down": 0.22, "up": 0.2, "for": "two wet paints run together"},
    "shade":        {"speed": 15, "down": 0.22, "up": 0.2, "load_mm": 300, "for": "a touch of a paint worked in, heavier where wanted"},
    "sponge_blend": {"speed": 0, "down": 0.12, "up": 0.12, "hold": 0.06, "for": "an edge softened in stipple"},
    "smudge":       {"speed": 10, "down": 0.3, "up": 0.25, "for": "a soft smear"},
    "lift":         {"speed": 10, "down": 0.25, "up": 0.2, "for": "paint taken off: a highlight, a correction"},
    "blot":         {"speed": 0, "down": 0.2, "up": 0.2, "hold": 0.3, "for": "a small or faint spill blotted off with a cotton swab"},
}

TRAVEL = 60.0         # mm/s between marks, never quicker than TRAVEL_LEAST
TRAVEL_LEAST = 0.35
RELOAD = 3.4          # back to the pot and loaded again...
RELOAD_AT = 0.45      # ...before the load falls below this: a painter filling a shape reloads before the brush streaks dry
SWAP = 4.0            # one tool put down and the next taken up
RINSE = 3.5           # a brush rinsed of one paint before another...
DRY = 2.5             # ...and dried on the towel
LOOK = 1.2            # a look back at the work...
LOOK_EVERY = 6        # ...every so many marks
LOOK_EVERY_PRESSES = 20
MIX = 2.5             # two paints mixed on the palette before a load of the mix
CLEAN_TOOLS = ("lipstick", "pencil", "handle")   # never rinsed: their paint is their own, or wiped


class Hand:
    """The painting's clock: where the hand is, what it holds, what is on it, and the seconds every move takes."""

    def __init__(self):
        self.t = 0.0
        self.at = None
        self.tool = None
        self.paint = None
        self.load = 0.0
        self.marks = 0
        self.swaps = 0
        self.by = {}          # seconds by behavior
        self.reloads = 0

    def _spend(self, what, s):
        self.t += s
        self.by[what] = self.by.get(what, 0.0) + s

    def cost(self, tool, paint):
        """What taking up `tool` with `paint` on it would cost now (seconds): a swap, a rinse, a load, a mix."""
        s = 0.0
        if tool != self.tool:
            if self.tool is not None:
                s += SWAP + (RINSE + DRY if self.paint and TOOLS[self.tool]["kind"] == "brush" else 0.0)
            if paint and tool not in CLEAN_TOOLS:
                s += RELOAD + (MIX if "+" in paint else 0.0)
        elif paint != self.paint:
            if self.paint and TOOLS[tool]["kind"] == "brush":
                s += RINSE + DRY
            if paint and tool not in CLEAN_TOOLS:
                s += RELOAD + (MIX if "+" in paint else 0.0)
        return s

    def take(self, tool):
        if tool == self.tool:
            return
        if self.tool is not None:
            if self.paint and TOOLS[self.tool]["kind"] == "brush":
                self._spend("cleaning", RINSE + DRY)
            self._spend("tool changes", SWAP)
            self.swaps += 1
        self.tool, self.paint, self.load = tool, None, 0.0

    def need(self, paint):
        """`paint` on the tool ("" a clean one): rinsed of the last, dipped in this."""
        if paint == self.paint:
            return
        kind = TOOLS[self.tool]["kind"]
        if self.paint and kind == "brush":
            self._spend("cleaning", RINSE + DRY)
        if paint and self.tool not in CLEAN_TOOLS:
            self._spend("loading", RELOAD + (MIX if "+" in paint else 0.0))
            self.reloads += 1
        self.paint, self.load = paint, 1.0 if paint else 0.0

    def mark(self, kind, start, length=0.0, presses=0, use=None):
        """A mark of behavior `kind` begun at `start` (mm): the way there, coming down, the stroke or presses, lifting, a look now and
        then; and what it used of the load, back to the pot when it runs out. Its start and end on the clock."""
        b = BEHAVIORS[kind]
        if self.at is not None:
            self._spend("between marks", max(float(np.linalg.norm(np.asarray(start) - self.at)) / TRAVEL, TRAVEL_LEAST))
        t0 = self.t
        work = b["down"] + b["up"]
        if b.get("speed", 0) > 0:
            work += length / b["speed"]
        work += presses * b.get("hold", 0.0)
        self._spend(kind, work)
        t1 = self.t
        self.at = np.asarray(start, dtype=float)
        self.marks += 1
        # (...a look back every so many marks - pressing and dabbing looks less often: a run of presses is one gesture)
        if self.marks % (LOOK_EVERY_PRESSES if b.get("speed", 0) == 0 or kind == "crack" else LOOK_EVERY) == 0:
            self._spend("looking", LOOK)
        if use is None:
            use = (length / b["load_mm"]) if "load_mm" in b else (presses / b["load_presses"] if "load_presses" in b else 0.0)
        if self.paint:
            self.load -= use
            # (...a sponge stippling goes on until nearly dry - a texture wants its fading presses; a brush filling, not)
            if self.load <= (0.2 if TOOLS[self.tool]["kind"] == "sponge" else RELOAD_AT) and self.tool not in ("lipstick", "pencil"):
                self._spend("loading", RELOAD)
                self.reloads += 1
                self.load = 1.0
        return t0, t1
