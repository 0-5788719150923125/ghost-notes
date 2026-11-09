"""A reference to paint, read from an episode's folder - never written (TEST_PLAN.md, "Read-only").

From the episode: the face painted first (`face_ref.png`, three pixels a millimeter over the surface's frame), the surface's frame
(`skin.json`), the table's paints (`table.json`: its creams, a finish - polish 0.9 or more, a gloss - left out as TablePaint leaves
it out of a ground) and the bare surface's color (the material of the part marked `skin`).
"""
import json
from pathlib import Path

import numpy as np
from PIL import Image

from canvas import PX
from color import dec, hex_rgb, oklab
from scipy import ndimage

FINISH_POLISH = 0.9


class Reference:
    def __init__(self, folder):
        folder = Path(folder)
        self.folder = folder
        self.name = folder.name
        skin = json.loads((folder / "skin.json").read_text())
        frame = skin["designs"][0].get("frame", [150.0, 210.0])
        self.frame = (float(frame[0]), float(frame[1]))
        table = json.loads((folder / "table.json").read_text())
        mats = table.get("materials", {})
        self.paints = {k: hex_rgb(m["color"]) for k, m in mats.items()
                       if m.get("kind") == "cream" and float(m.get("polish") or 0.0) < FINISH_POLISH}
        self.bare = hex_rgb(self._skin_color(table, mats))
        img = Image.open(folder / "face_ref.png").convert("RGBA")
        # (...the color past its edge the nearest of its own: what lies beyond is clear, often black, and blurred or resized it had drawn
        # a dark rim round the face)
        img = Image.fromarray(_filled(np.asarray(img)))
        self.hi = np.asarray(img).astype(float) / 255.0          # the picture at its own resolution
        self.hi_px = self.hi.shape[1] / self.frame[0]
        self.w = int(round(self.frame[0] * PX))
        self.h = int(round(self.frame[1] * PX))
        big = np.asarray(img.resize((self.w, self.h), Image.BICUBIC)).astype(float) / 255.0
        self.face = big[..., 3] > 0.5
        self.srgb = np.clip(big[..., :3], 0, 1)
        self.lab = oklab(dec(self.srgb))

    @staticmethod
    def _skin_color(table, mats):
        def walk(parts):
            for p in parts:
                if p.get("skin"):
                    return p.get("material")
                got = walk(p.get("parts", []))
                if got:
                    return got
            return None
        for th in table.get("things", []):
            m = walk(th.get("parts", []))
            if m and m in mats:
                return mats[m]["color"]
        return "#c89e80"


def _filled(rgba):
    """Picture `rgba` (uint8) with every point not wholly covered given the color of the nearest point that is, its cover kept."""
    out = rgba.copy()
    clear = rgba[..., 3] < 250
    if clear.any() and (~clear).any():
        _, (iy, ix) = ndimage.distance_transform_edt(clear, return_indices=True)
        out[..., :3] = rgba[iy, ix, :3]
    return out
