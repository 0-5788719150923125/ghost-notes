#!/usr/bin/env python3
"""Gate for a sticker cut off its ground (rig.py `sticker`, next/sticker_book.md).

Run it with any python that has numpy, scipy and Pillow (the puppet or the paint venv):

    ~/.local/share/godot/app_userdata/ghost/paint_venv/bin/python hosts/puppet/test_sticker.py

On a made painting - a flat magenta ground, a kraft-brown figure outlined in black with a ring for an arm (magenta inside the ring), a
pink patch inside the figure, a speck of ink off on its own:

  1. THE GROUND GOES: every corner and the magenta inside the ring is clear. CONTROL: the figure's middle and its outline are opaque.
  2. WHAT IS INSIDE THE DRAWING STAYS, HOWEVER NEAR THE GROUND'S COLOR: the pink patch deep inside is opaque.
  3. A SOFT EDGE IS THE DRAWING'S COLOR: a pixel of the edge where ink fades into magenta keeps no magenta in it.
  4. SPECKS GO: the stray dot of ink far from the figure is clear, and the sticker is cropped to the figure.
  5. A PAINTING WITH NO FLAT GROUND IS REFUSED, and so is one on paper (keyed, the paper's own brown in the figure would be holes),
     each said in words. CONTROL: the flat magenta one is cut.
  6. A CLOSE DRAWING IS CUT: head and shoulders running off the bottom and both sides, the ground only above and beside the head, is cut
     off it, its bottom kept where the page ends.
"""
import json
import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import rig  # noqa: E402

MAGENTA = (255, 0, 255)
KRAFT = (176, 138, 90)
INK = (20, 18, 16)
PINK = (235, 120, 215)
fails = 0


def check(ok, what):
    global fails
    if not ok:
        fails += 1
        print("FAIL:", what)


def painting(flat=True):
    im = Image.new("RGB", (400, 600), MAGENTA)
    d = ImageDraw.Draw(im)
    d.rectangle([140, 100, 260, 520], fill=KRAFT, outline=INK, width=6)
    d.ellipse([255, 220, 345, 310], outline=INK, width=14)            # an arm in a ring, magenta inside it
    d.rectangle([180, 300, 220, 340], fill=PINK)                      # pink well inside the figure
    d.ellipse([30, 560, 36, 566], fill=INK)                           # a speck
    if not flat:
        im = Image.fromarray(np.random.default_rng(3).integers(0, 256, (600, 400, 3)).astype(np.uint8))
    # a soft edge: the right side of the body blended half into the ground
    if flat:
        px = im.load()
        for y in range(120, 500):
            px[261, y] = tuple((np.array(INK) * 0.5 + np.array(MAGENTA) * 0.5).astype(int))
    return im


def run():
    tmp = Path(tempfile.mkdtemp())
    src = tmp / "painted.png"
    painting().save(src)
    out = tmp / "sticker.png"
    got = rig.sticker({"src": str(src), "out": str(out), "dir": str(tmp)})
    s = np.asarray(Image.open(out).convert("RGBA")).astype(int)
    x0, y0 = got["crop"]
    a = s[..., 3]
    at = lambda x, y: s[y - y0, x - x0]
    # 1
    check(a[0, 0] == 0 and a[-1, -1] == 0, "the ground at the corners is clear")
    check(at(300, 265)[3] == 0, "the magenta inside the ring is clear")
    check(at(200, 200)[3] == 255 and at(141, 300)[3] == 255, "CONTROL: the figure and its outline are opaque")
    # 2
    check(at(200, 320)[3] == 255, "the pink deep inside the figure stays")
    # 3
    e = at(261, 300)
    check(0 < e[3] < 255 and abs(int(e[0]) - INK[0]) < 40 and abs(int(e[2]) - INK[2]) < 40,
          "a soft edge is the ink's color, not magenta: %s" % list(e))
    # 4
    check(x0 > 40 and s.shape[0] < 470 and s.shape[1] < 240, "the speck went and the sticker is cropped to the figure: %s at %s" % (s.shape, got["crop"]))
    # 5
    noisy = tmp / "noisy.png"
    painting(flat=False).save(noisy)
    try:
        rig.sticker({"src": str(noisy), "out": str(tmp / "n.png"), "dir": str(tmp)})
        check(False, "a painting with no flat ground is refused")
    except rig.SpecError as e:
        check("ground" in str(e), "...in words: %s" % e)
    paper = Image.new("RGB", (400, 600), KRAFT)
    ImageDraw.Draw(paper).rectangle([140, 100, 260, 520], fill=KRAFT, outline=INK, width=6)
    paper.save(tmp / "paper.png")
    try:
        rig.sticker({"src": str(tmp / "paper.png"), "out": str(tmp / "p.png"), "dir": str(tmp)})
        check(False, "a painting on paper is refused")
    except rig.SpecError as e:
        check("vivid" in str(e), "...in words: %s" % e)
    # 6
    close = Image.new("RGB", (400, 600), MAGENTA)
    d = ImageDraw.Draw(close)
    d.ellipse([110, 40, 290, 260], fill=KRAFT, outline=INK, width=6)               # a head
    d.polygon([(0, 330), (400, 330), (400, 600), (0, 600)], fill=KRAFT, outline=INK)  # shoulders off three edges
    d.rectangle([170, 250, 230, 340], fill=KRAFT)                                     # a neck
    close.save(tmp / "close.png")
    got = rig.sticker({"src": str(tmp / "close.png"), "out": str(tmp / "c.png"), "dir": str(tmp)})
    c = np.asarray(Image.open(tmp / "c.png").convert("RGBA")).astype(int)
    x0, y0 = got["crop"]
    check(c[5 - y0 if 5 >= y0 else 0, 5 - x0 if 5 >= x0 else 0, 3] == 0 or (x0 > 5 and y0 > 5), "a close drawing's ground above it is clear")
    check(c[-1, c.shape[1] // 2, 3] == 255 and y0 + c.shape[0] == 600, "and its shoulders run to the page's bottom: %s at %s" % (c.shape, got["crop"]))
    print("test_sticker:", "ok" if fails == 0 else "%d failed" % fails)
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(run())
