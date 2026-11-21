#!/usr/bin/env python3
"""A DRAWING MADE A PUPPET (next/cartoon.md): a character drawn on paper cut off it, meshed, and weighted to the skeleton an agent
placed on it - what the stage's puppet reads ([PuppetRig]).

    rig.py cut <spec.json>     the drawing off its paper:  cut.png, cut.json, cut_look.png
    rig.py build <spec.json>   its skeleton, jaw and eyes: rig.json, skin.png, jaw.png, look.png
    rig.py align <spec.json>   a drawing set onto another's canvas: its cut.png, as tall as the other's, its feet on theirs

A spec is JSON, never argv. Every coordinate is a pixel of `cut.png` (x right, y down). Each step writes `done.json` beside what it
made: `{ok, ...}` or `{ok: false, error}` - errors are sentences for the agent that wrote the spec.

CUT  {"src": the drawing, "dir": the folder, "holes": [ids] | null, "keep": [ids],
      "erase": [[[x, y], ...] | {outline: [[x, y], ...], color: "#rrggbb", tolerance?}, ...]}
  The paper is the color round the drawing's edge; what touches the edge in that color is paper. The figure is the largest thing left.
  Paper the figure closes round is numbered (`cut.json` `regions`, largest first): a gap between a limb and the body, or something
  drawn white (an eye, a page). One larger than HOLE_SHARE of the figure is a gap unless `keep` names it; `holes` names gaps outright.
  What is no longer joined to the figure once the gaps are out goes with them (a mark drawn in a gap). `erase` takes out polygons,
  or only one color inside one (a flash drawn round a hammer, its hammer kept).
  The crop is the figure's before anything is taken out, so coordinates hold from one cut to the next.

ALIGN  {"dir": the drawing's folder (its cut.png), "base": the folder of the drawing it is painted from}
  A drawing of a model sheet (next/cartoon.md) is resampled onto its base's canvas: scaled to the base figure's height, its feet's
  middle on theirs - so it shares the base's coordinates, and a skeleton placed on the base fits it. The cut as painted is kept as
  `cut_raw.png`.

BUILD  {"dir", "bones": [{name, parent, head: [x, y], tail: [x, y], role?, side?}], "jaw"?: {outline: [[x, y], ...], hinge: [x, y],
        parent?, cavity?: "#rrggbb", open?: degrees, drop?: px}, "eyes"?: [{name?, center, radius: r | [rx, ry], lid?: "#rrggbb"}],
        "behind"?: [{name, color: "#rrggbb", tolerance?, bone?}], "parts"?: [{name, outline: [[x, y], ...], bone}],
        "ground"?: y, "faces"?: front | left | right, "poses"?: {name: {bone: degrees}}, "about"?: text, "grid"?: px,
        "rigid"?: true}
  One bone has parent "" - the root. The jaw is cut out of the body into a layer of its own on a `jaw` bone at its hinge, a dark
  cavity behind the hole it leaves; each eye gets a bone (`eye_N` unless named) that scales it and a lid of the skin round it.
  A part `behind` (an aura, a cloak) is the figure's pixels of its color, its large pieces only, made a layer of its own behind the
  rest - filled flat in its color where the figure hid it - on its bone (the root's unless named), so the limbs in front of it are
  no longer joined through it. A PART (a hammer, a phone, a page held) is the figure's pixels inside its outline made a rigid layer
  of its own in front, wholly on its bone; the hole it leaves in the body is filled with the colors round it, so it can swing away
  without dragging what it touched. `rigid` builds a drawing held whole on one bone (a back, a mood). The mesh follows each layer's
  outline; a vertex's weights are the bones nearest it THROUGH the figure (shortest paths inside
  its silhouette), so an arm beside the body never pulls the body.
"""
import json
import math
import sys
import traceback
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage as ndi
from scipy.sparse import csr_matrix
from scipy.sparse.csgraph import dijkstra
from scipy.spatial import Delaunay

## The largest side a drawing is worked at (px): a bigger one is scaled down first.
MAX_SIDE = 1400
## How far a pixel's color may be from the paper's (0-255, per channel at most) and still be paper.
PAPER_TOL = 48
## Enclosed paper larger than this share of the figure is a gap, unless kept; one larger than SMALL_GAP is a gap too where nothing is
## drawn inside it (a page has its writing, an eye its pupil - a gap between limbs has nothing).
HOLE_SHARE = 0.02
SMALL_GAP = 0.003
## The margin round the figure in cut.png (px).
PAD = 10
## How far apart a mesh's points are inside a figure (px), and along its outline.
GRID = 16
EDGE_STEP = 6
## The longest side the weights' shortest paths are worked at (px).
FIELD_SIDE = 320
## How far past the nearest bone (a share of the figure's height) another bone still takes a share of a vertex.
BLEND = 0.05
## The most bones that move one vertex.
MOST_BONES = 4
## How far past the body's own edge the hole a part leaves is filled (px): where it lay over the body, the body goes on under it.
LIFT_FILL = 14
## A jaw's cavity, where the spec names none, and how far the jaw opens by default (degrees).
CAVITY = "#2a0b10"
JAW_OPEN = 16.0
## How far the look's bent panel turns every bone but the root (degrees).
TEST_TURN = 15

PALETTE = [(230, 25, 75), (60, 180, 75), (255, 205, 25), (0, 130, 200), (245, 130, 48), (145, 30, 180), (70, 240, 240),
           (240, 50, 230), (170, 255, 60), (250, 160, 190), (0, 128, 128), (200, 160, 255), (170, 110, 40), (255, 250, 200),
           (128, 0, 0), (120, 255, 200), (128, 128, 0), (255, 215, 180), (0, 0, 128), (128, 128, 128)]


def main(argv):
    if len(argv) < 3 or argv[1] not in ("cut", "build", "align"):
        print(__doc__)
        return 2
    spec = json.loads(Path(argv[2]).read_text())
    out = Path(spec["dir"])
    out.mkdir(parents=True, exist_ok=True)
    try:
        res = {"cut": cut, "build": build, "align": align}[argv[1]](spec)
        res["ok"] = True
    except SpecError as e:
        res = {"ok": False, "error": str(e)}
    except Exception as e:  # noqa: BLE001 - a host says what broke, it never dies silent
        res = {"ok": False, "error": "%s: %s" % (type(e).__name__, e), "trace": traceback.format_exc()}
    (out / "done.json").write_text(json.dumps(res, indent=1))
    print(json.dumps({k: v for k, v in res.items() if k != "trace"}))
    return 0 if res["ok"] else 1


class SpecError(Exception):
    """What the agent wrote that cannot be built, said so it can be written again."""


# --- cut ---------------------------------------------------------------------------------------------------------------

def cut(spec):
    src = Path(spec["src"]).expanduser()
    if not src.exists():
        raise SpecError("there is no picture at %s" % src)
    img = Image.open(src).convert("RGB")
    if max(img.size) > MAX_SIDE:
        k = MAX_SIDE / max(img.size)
        img = img.resize((round(img.width * k), round(img.height * k)), Image.LANCZOS)
    rgb = np.asarray(img).astype(np.int16)
    h, w = rgb.shape[:2]
    edge = np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]])
    paper_rgb = np.median(edge, axis=0)
    paper = np.abs(rgb - paper_rgb).max(axis=2) < PAPER_TOL
    lab, _ = ndi.label(paper)
    border = np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))
    bg = np.isin(lab, border[border > 0])
    figure = _largest(~bg)
    if figure.sum() < 0.002 * w * h:
        raise SpecError("nothing was found on the paper - is the drawing on a plain background?")
    ys, xs = np.nonzero(figure)
    x0, y0 = max(0, xs.min() - PAD), max(0, ys.min() - PAD)
    x1, y1 = min(w, xs.max() + PAD + 1), min(h, ys.max() + PAD + 1)
    filled = ndi.binary_fill_holes(figure)
    # the paper the figure closes round, numbered largest first
    inside = paper & figure
    rl, rn = ndi.label(inside)
    regions = []
    if rn:
        areas = ndi.sum(inside, rl, range(1, rn + 1))
        cents = ndi.center_of_mass(inside, rl, range(1, rn + 1))
        order = np.argsort(-areas)
        fig_area = float(filled.sum())
        boxes = ndi.find_objects(rl)
        for rank, i in enumerate(order):
            if areas[i] < 30:
                continue
            own = rl[boxes[i]] == (i + 1)
            marked = int(ndi.binary_fill_holes(own).sum() - own.sum()) > 12
            regions.append({"id": len(regions) + 1, "label": int(i + 1), "area": int(areas[i]),
                            "share": round(float(areas[i]) / fig_area, 4), "marked": marked,
                            "at": [int(round(cents[i][1] - x0)), int(round(cents[i][0] - y0))]})
    holes = spec.get("holes")
    keep = set(spec.get("keep") or [])
    for r in regions:
        if holes is not None:
            r["hole"] = r["id"] in holes
        else:
            r["hole"] = r["id"] not in keep and (r["share"] > HOLE_SHARE or (r["share"] > SMALL_GAP and not r["marked"]))
    alpha = figure.copy()
    for r in regions:
        if r["hole"]:
            alpha[rl == r["label"]] = False
    for i, item in enumerate(spec.get("erase") or []):
        # an outline, or {outline, color, tolerance}: only that color inside it
        poly = item.get("outline", []) if isinstance(item, dict) else item
        gone = _poly_mask((w, h), [(x + x0, y + y0) for x, y in poly])
        if isinstance(item, dict) and item.get("color"):
            want = _hex(item["color"], "erase[%d].color" % i)
            gone &= np.abs(rgb.astype(float) - want).max(axis=2) < float(item.get("tolerance", 60))
        alpha &= ~gone
    alpha = _largest(alpha)
    # the ink's soft edge kept: a pixel just outside, as dark as ink is over the paper, is that much ink
    lum = rgb.mean(axis=2)
    paper_lum = float(paper_rgb.mean())
    near = (ndi.distance_transform_edt(~alpha) <= 1.5) & ~alpha
    edge_a = np.clip((paper_lum - lum) / max(1.0, paper_lum - 40.0), 0.0, 1.0) * near
    a = np.where(alpha, 1.0, edge_a)
    col = rgb.astype(float)
    mix = (a > 0.05) & ~alpha
    col[mix] = np.clip((col[mix] - paper_rgb * (1.0 - a[mix, None])) / a[mix, None], 0, 255)
    rgba = np.dstack([col, a * 255.0]).astype(np.uint8)[y0:y1, x0:x1]
    out = Path(spec["dir"])
    Image.fromarray(rgba).save(out / "cut.png")
    for r in regions:
        del r["label"]
    info = {"size": [int(x1 - x0), int(y1 - y0)], "crop": [int(x0), int(y0)], "source": str(src), "paper": [int(c) for c in paper_rgb],
            "regions": regions}
    (out / "cut.json").write_text(json.dumps(info, indent=1))
    _cut_look(rgba, regions, out / "cut_look.png")
    return {"cut": str(out / "cut.png"), "look": str(out / "cut_look.png"), "size": info["size"],
            "regions": [{k: r[k] for k in ("id", "share", "at", "marked", "hole")} for r in regions]}


def _largest(mask):
    lab, n = ndi.label(mask, structure=np.ones((3, 3)))
    if n == 0:
        return mask
    sizes = ndi.sum(mask, lab, range(1, n + 1))
    return lab == (int(np.argmax(sizes)) + 1)


def _poly_mask(size, pts):
    m = Image.new("L", size, 0)
    if len(pts) >= 3:
        ImageDraw.Draw(m).polygon([tuple(map(float, p)) for p in pts], fill=255)
    return np.asarray(m) > 127


def _cut_look(rgba, regions, path):
    """The cut over a gray checker, a pixel grid over it, and each enclosed region ringed and numbered: red a gap, green kept."""
    im = _over_checker(rgba)
    d = ImageDraw.Draw(im)
    _grid(d, im.size)
    font = _font(22)
    for r in regions:
        x, y = r["at"]
        c = (220, 30, 30) if r["hole"] else (20, 160, 40)
        d.ellipse([x - 16, y - 16, x + 16, y + 16], outline=c, width=4)
        d.text((x + 18, y - 12), str(r["id"]), fill=c, font=font, stroke_width=2, stroke_fill=(255, 255, 255))
    im.save(path)


# --- align -------------------------------------------------------------------------------------------------------------

def align(spec):
    out = Path(spec["dir"])
    base = Path(spec["base"])
    raw = out / "cut_raw.png"
    if not raw.exists():
        if not (out / "cut.png").exists():
            raise SpecError("the drawing is not cut yet (cut.png)")
        (out / "cut.png").rename(raw)
    if not (base / "cut.png").exists():
        raise SpecError("the drawing it is painted from is not cut yet")
    b = Image.open(base / "cut.png").convert("RGBA")
    v = Image.open(raw).convert("RGBA")
    bb = _bbox(np.asarray(b)[..., 3] > 128)
    vb = _bbox(np.asarray(v)[..., 3] > 128)
    k = (bb[3] - bb[1]) / max(1.0, float(vb[3] - vb[1]))
    vs = v.resize((max(1, round(v.width * k)), max(1, round(v.height * k))), Image.LANCZOS)
    # its feet's middle onto the base's: the bottom row of each figure, the middle of its width
    ox = round((bb[0] + bb[2]) / 2.0 - (vb[0] + vb[2]) / 2.0 * k)
    oy = round(bb[3] - vb[3] * k)
    canvas = Image.new("RGBA", b.size, (0, 0, 0, 0))
    canvas.paste(vs, (ox, oy), vs)
    canvas.save(out / "cut.png")
    return {"cut": str(out / "cut.png"), "scale": round(k, 4), "offset": [ox, oy], "size": list(b.size)}


def _bbox(mask):
    ys, xs = np.nonzero(mask)
    if len(xs) == 0:
        raise SpecError("there is no figure in the drawing")
    return int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())


# --- build -------------------------------------------------------------------------------------------------------------

def build(spec):
    out = Path(spec["dir"])
    if not (out / "cut.png").exists():
        raise SpecError("the drawing is not cut yet (cut.png)")
    rgba = np.asarray(Image.open(out / "cut.png").convert("RGBA"))
    h, w = rgba.shape[:2]
    alpha = rgba[..., 3].astype(float) / 255.0
    solid = alpha > 0.5
    ys = np.nonzero(solid.any(axis=1))[0]
    top, bottom = int(ys.min()), int(ys.max())
    height = float(bottom - top)
    if spec.get("rigid"):
        # a drawing held whole (a back, a mood): one bone up its middle, from its feet to its top
        xs = np.nonzero(solid.any(axis=0))[0]
        cx = float(xs.min() + xs.max()) / 2.0
        spec = dict(spec, bones=[{"name": "root", "parent": "", "head": [cx, float(bottom)], "tail": [cx, float(top)], "role": "body"}])
    bones = _bones(spec, w, h)
    names = [b["name"] for b in bones]
    # the jaw: a layer of its own, cut out of the body, on a bone at its hinge
    jaw = spec.get("jaw") or None
    jaw_mask = np.zeros_like(solid)
    if jaw:
        outline = jaw.get("outline") or []
        if len(outline) < 3:
            raise SpecError("jaw.outline needs at least three points round the part of the face that drops")
        hinge = _pt(jaw.get("hinge"), "jaw.hinge", w, h)
        parent = str(jaw.get("parent") or ("head" if "head" in names else names[0]))
        if parent not in names:
            raise SpecError("jaw.parent '%s' is not a bone (bones: %s)" % (parent, ", ".join(names)))
        jaw_mask = _poly_mask((w, h), outline) & (alpha > 0.02)
        if jaw_mask.sum() < 20:
            raise SpecError("jaw.outline holds none of the drawing - it must ring the chin and lower lip on the figure")
        jy, jx = np.nonzero(jaw_mask)
        low = [float(jx.mean()), float(jy.max())]
        bones.append({"name": "jaw", "parent": parent, "head": hinge, "tail": low, "role": "jaw", "side": ""})
    eyes = []
    for i, e in enumerate(spec.get("eyes") or []):
        c = _pt(e.get("center"), "eyes[%d].center" % i, w, h)
        r = e.get("radius", 20)
        rx, ry = (float(r[0]), float(r[1])) if isinstance(r, (list, tuple)) else (float(r), float(r))
        if rx < 2 or ry < 2:
            raise SpecError("eyes[%d].radius is too small to see" % i)
        name = str(e.get("name") or "eye_%d" % (i + 1))
        parent = str(e.get("parent") or ("head" if "head" in names else names[0]))
        if parent not in names:
            raise SpecError("eyes[%d].parent '%s' is not a bone" % (i, parent))
        lid = e.get("lid") or _ring_color(rgba, c, rx, ry)
        bones.append({"name": name, "parent": parent, "head": c, "tail": [c[0], c[1] - ry], "role": "eye", "side": ""})
        eyes.append({"name": name, "bone": name, "center": c, "radius": [rx, ry], "lid": lid})
    index = {b["name"]: i for i, b in enumerate(bones)}
    # parts: rigid layers of their own, lifted out of the body
    parts = []
    lifted = np.zeros_like(solid)
    for i, part in enumerate(spec.get("parts") or []):
        outline = part.get("outline") or []
        if len(outline) < 3:
            raise SpecError("parts[%d].outline needs at least three points round the part" % i)
        bone = str(part.get("bone") or "")
        if bone not in names:
            raise SpecError("parts[%d].bone '%s' is not a bone (bones: %s)" % (i, bone, ", ".join(names)))
        pm = _poly_mask((w, h), outline) & (alpha > 0.02) & ~jaw_mask & ~lifted
        if pm.sum() < 30:
            raise SpecError("parts[%d].outline holds almost none of the drawing" % i)
        name = str(part.get("name") or "part_%d" % (i + 1))
        if name in names or name in ("body", "jaw"):
            raise SpecError("parts[%d]: name it something no bone or layer is called" % i)
        parts.append({"name": name, "bone": bone, "mask": pm})
        lifted |= pm
    # what stands behind: its color's large pieces, a layer of its own, filled where the rest hid it
    behind = []
    taken = np.zeros_like(solid)
    for i, part in enumerate(spec.get("behind") or []):
        want = _hex(part.get("color"), "behind[%d].color" % i)
        tol = float(part.get("tolerance", 60))
        own = (np.abs(rgba[..., :3].astype(float) - want).max(axis=2) < tol) & solid & ~jaw_mask
        lab, n = ndi.label(own)
        if n:
            sizes = ndi.sum(own, lab, range(1, n + 1))
            own = np.isin(lab, 1 + np.nonzero(sizes > 0.01 * solid.sum())[0])
        if own.sum() < 50:
            raise SpecError("behind[%d]: almost nothing of the figure is %s - pick the color from the drawing" % (i, part.get("color")))
        bone = str(part.get("bone") or names[0])
        if bone not in names:
            raise SpecError("behind[%d].bone '%s' is not a bone" % (i, bone))
        # the body in front is its solid core: what is left once thin strands (this part's own outline, a marker's streaks) and
        # small islands are cut off goes behind with it, or it would stay where it was drawn as the limbs move
        rest = solid & ~own & ~taken
        core = ndi.binary_opening(rest, iterations=2)
        cl, cn = ndi.label(core)
        if cn:
            csz = ndi.sum(core, cl, range(1, cn + 1))
            core = np.isin(cl, 1 + np.nonzero(csz > 0.004 * solid.sum())[0])
        front = rest & ndi.binary_dilation(core, iterations=3)
        own = own | (rest & ~front)
        grown = ndi.binary_dilation(own, iterations=3) & (alpha > 0.02)
        # what it stands behind, filled: its extent closed (a part open at one side still reaches behind what it rings), never past
        # the figure's own outline, nor out where a limb reaches beyond it
        hull = ndi.binary_fill_holes(ndi.binary_closing(grown, iterations=25, border_value=0))
        region = hull & ndi.binary_fill_holes(grown | solid)
        pix = rgba.copy()
        flat = np.median(rgba[own][:, :3], axis=0)
        pix[region & ~own, :3] = flat.astype(np.uint8)
        pix[..., 3] = np.where(region, np.where(own, rgba[..., 3], 255), 0).astype(np.uint8)
        name = str(part.get("name") or "behind_%d" % (i + 1))
        behind.append({"name": name, "bone": bone, "pix": pix, "mask": region})
        taken |= own
    # the layers: what stands behind, the body with the jaw's hole in it, and the jaw
    body_a = alpha * ~taken
    body_rgb = rgba[..., :3].copy()
    if lifted.any():
        # where a part is lifted out, the body is filled with the colors round it - only where the rest of the body closes round
        # the hole (a part reaching past the body's outline leaves nothing behind there)
        rest = solid & ~lifted & ~taken
        dist, near_i = ndi.distance_transform_edt(~rest, return_indices=True)
        inside = lifted & (ndi.binary_fill_holes(rest) | (dist <= LIFT_FILL))
        body_rgb[inside] = rgba[near_i[0][inside], near_i[1][inside], :3]
        body_a = np.where(lifted, np.where(inside, 1.0, 0.0), body_a)
        solid_body = (body_a > 0.5)
    else:
        solid_body = solid & ~taken
    jaw_a = alpha * jaw_mask
    # a bone that lies mostly inside a lifted part moves that part alone, never the body round where it was lifted from
    carried = set()
    for b in bones:
        a0, t0 = np.array(b["head"]), np.array(b["tail"])
        pts = [a0 + (t0 - a0) * k for k in np.linspace(0.0, 1.0, 9)]
        inside = [lifted[int(min(max(p[1], 0), h - 1)), int(min(max(p[0], 0), w - 1))] for p in pts]
        if lifted.any() and sum(inside) >= 6:
            carried.add(b["name"])
    fields, scale = _fields(((body_a > 0.05) | solid_body) & ~lifted, bones, eyes, jaw_mask, carried)
    grid = int(spec.get("grid") or GRID)
    layers = []
    for part in behind:
        m = _grid_mesh(part["pix"][..., 3].astype(float) / 255.0, grid * 2)
        Image.fromarray(part["pix"]).save(out / (part["name"] + ".png"))
        layers.append({"name": part["name"], "image": part["name"] + ".png", "points": _flat(m[0]),
                       "tris": m[1].ravel().tolist(), "weights": [[[index[part["bone"]], 1.0]] for _ in range(len(m[0]))]})
    body_mesh = _grid_mesh(body_a, grid)
    body_w = _weights(body_mesh[0], fields, scale, bones, eyes, height,
                      (jaw_mask, index[bones[index["jaw"]]["parent"]]) if jaw else None)
    layers.append({"name": "body", "image": "skin.png", "points": _flat(body_mesh[0]), "tris": body_mesh[1].ravel().tolist(),
                   "weights": body_w})
    skin = np.dstack([body_rgb, (body_a * 255).astype(np.uint8)])
    cavity = None
    if jaw:
        jm = _grid_mesh(jaw_a, max(6, grid // 2))
        layers.append({"name": "jaw", "image": "jaw.png", "points": _flat(jm[0]), "tris": jm[1].ravel().tolist(),
                       "weights": [[[index["jaw"], 1.0]] for _ in range(len(jm[0]))]})
        Image.fromarray(np.dstack([rgba[..., :3], (jaw_a * 255).astype(np.uint8)])).save(out / "jaw.png")
        # the hole the jaw leaves is the mouth: painted dark into the body itself, inside a ring of the drawing that the closed jaw
        # covers, so it is never seen at rest and moves as the face round it does
        cav = _hex(jaw.get("cavity") or CAVITY, "jaw.cavity")
        inner = ndi.binary_erosion(jaw_mask, iterations=2)
        skin[jaw_mask, :3] = rgba[jaw_mask, :3]
        skin[jaw_mask, 3] = rgba[jaw_mask, 3]
        skin[inner, :3] = cav.astype(np.uint8)
        cavity = {"color": str(jaw.get("cavity") or CAVITY), "bone": bones[index["jaw"]]["parent"]}
    Image.fromarray(skin).save(out / "skin.png")
    for part in parts:
        pa = alpha * part["mask"]
        pmesh = _grid_mesh(pa, max(8, grid // 2))
        Image.fromarray(np.dstack([rgba[..., :3], (pa * 255).astype(np.uint8)])).save(out / (part["name"] + ".png"))
        layers.append({"name": part["name"], "image": part["name"] + ".png", "points": _flat(pmesh[0]),
                       "tris": pmesh[1].ravel().tolist(), "weights": [[[index[part["bone"]], 1.0]] for _ in range(len(pmesh[0]))],
                       "part": True})
    ground = float(spec.get("ground", bottom))
    rig = {"version": 1, "size": [w, h], "top": top, "ground": ground, "faces": str(spec.get("faces", "front")),
           "bones": bones, "layers": layers, "cavity": cavity, "eyes": eyes,
           "mouth": {"hinge": bones[index["jaw"]]["head"], "open": float(jaw.get("open", JAW_OPEN)),
                     "drop": float(jaw.get("drop", 0.0))} if jaw else None,
           "poses": spec.get("poses") or {}, "about": str(spec.get("about", ""))}
    (out / "rig.json").write_text(json.dumps(rig))
    rig["_jaw_outline"] = [[tuple(map(float, p)) for p in jaw["outline"]]] if jaw else []
    _build_look(rgba, rig, fields, scale, out / "look.png")
    counts = {b["name"]: 0 for b in bones}
    for vw in body_w:
        counts[bones[max(vw, key=lambda p: p[1])[0]]["name"]] += 1
    idle = [n for n, c in counts.items() if c == 0 and bones[index[n]]["role"] not in ("jaw",)]
    return {"rig": str(out / "rig.json"), "look": str(out / "look.png"), "bones": len(bones),
            "vertices": sum(len(l["points"]) // 2 for l in layers), "moves_nothing": idle,
            "height": height}


def _bones(spec, w, h):
    raw = spec.get("bones") or []
    if not raw:
        raise SpecError("bones: at least a root bone (parent \"\") is needed")
    out = []
    seen = set()
    for i, b in enumerate(raw):
        name = str(b.get("name", "")).strip()
        if not name or name in seen or name == "jaw":
            raise SpecError("bones[%d]: each bone needs its own name (and 'jaw' is made from the jaw)" % i)
        seen.add(name)
        out.append({"name": name, "parent": str(b.get("parent", "") or ""), "head": _pt(b.get("head"), name + ".head", w, h),
                    "tail": _pt(b.get("tail", b.get("head")), name + ".tail", w, h), "role": str(b.get("role", "") or ""),
                    "side": str(b.get("side", "") or "")})
    roots = [b["name"] for b in out if not b["parent"]]
    if len(roots) != 1:
        raise SpecError("exactly one bone has parent \"\" (the root); these do: %s" % (", ".join(roots) or "none"))
    for b in out:
        if b["parent"] and b["parent"] not in seen:
            raise SpecError("bone %s: its parent %s is not a bone" % (b["name"], b["parent"]))
    # parents before children, as the stage builds them
    order, placed = [], set()
    while len(order) < len(out):
        moved = False
        for b in out:
            if b["name"] not in placed and (not b["parent"] or b["parent"] in placed):
                order.append(b)
                placed.add(b["name"])
                moved = True
        if not moved:
            raise SpecError("the bones' parents make a loop")
    return order


def _hex(v, what):
    t = str(v or "").strip().lstrip("#")
    if len(t) != 6:
        raise SpecError("%s must be a color, \"#rrggbb\"" % what)
    try:
        return np.array([int(t[0:2], 16), int(t[2:4], 16), int(t[4:6], 16)], dtype=float)
    except ValueError:
        raise SpecError("%s must be a color, \"#rrggbb\"" % what)


def _pt(v, what, w, h):
    if not isinstance(v, (list, tuple)) or len(v) != 2:
        raise SpecError("%s must be [x, y] in pixels of the cut" % what)
    x, y = float(v[0]), float(v[1])
    if not (-w * 0.1 <= x <= w * 1.1 and -h * 0.1 <= y <= h * 1.1):
        raise SpecError("%s [%d, %d] is off the picture (%d x %d)" % (what, x, y, w, h))
    return [round(x, 1), round(y, 1)]


def _ring_color(rgba, c, rx, ry):
    """The skin round an eye: the commonest light color in a ring just outside it, ink left out."""
    h, w = rgba.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w]
    q = ((xx - c[0]) / (rx * 1.25)) ** 2 + ((yy - c[1]) / (ry * 1.25)) ** 2
    q2 = ((xx - c[0]) / (rx * 1.7)) ** 2 + ((yy - c[1]) / (ry * 1.7)) ** 2
    ring = (q > 1.0) & (q2 <= 1.0) & (rgba[..., 3] > 200)
    px = rgba[ring][:, :3].astype(int)
    if len(px) == 0:
        return "#808080"
    px = px[px.mean(axis=1) > 70]
    if len(px) == 0:
        return "#606060"
    keys, counts = np.unique((px // 16), axis=0, return_counts=True)
    k = keys[np.argmax(counts)]
    sel = px[np.all(px // 16 == k, axis=1)].mean(axis=0)
    return "#%02x%02x%02x" % tuple(int(v) for v in sel)


def _fields(mask, bones, eyes, jaw_mask, carried=()):
    """Each bone's distance from every pixel of the figure, through the figure: shortest paths on a grid of it worked at FIELD_SIDE.
    -> (fields [bone, y, x] in full pixels, the grid's scale). The jaw's own bone has none (its layer is all its own); an eye's is
    ringed round its center."""
    h, w = mask.shape
    s = min(1.0, FIELD_SIDE / max(h, w))
    sh, sw = max(2, round(h * s)), max(2, round(w * s))
    small = np.asarray(Image.fromarray((mask * 255).astype(np.uint8)).resize((sw, sh), Image.BILINEAR)) > 40
    small = ndi.binary_closing(small, iterations=1) | small
    idx = -np.ones((sh, sw), dtype=np.int64)
    ys, xs = np.nonzero(small)
    idx[ys, xs] = np.arange(len(ys))
    rows, cols, vals = [], [], []
    for dy, dx, c in ((0, 1, 1.0), (1, 0, 1.0), (1, 1, math.sqrt(2)), (1, -1, math.sqrt(2))):
        a = idx[0:sh - dy, max(0, -dx):sw - max(0, dx)]
        b = idx[dy:sh, max(0, dx):sw - max(0, -dx)]
        ok = (a >= 0) & (b >= 0)
        rows.append(a[ok]); cols.append(b[ok]); vals.append(np.full(ok.sum(), c))
    n = len(ys)
    r = np.concatenate(rows); c = np.concatenate(cols); v = np.concatenate(vals)
    graph = csr_matrix((np.concatenate([v, v]), (np.concatenate([r, c]), np.concatenate([c, r]))), shape=(n, n))
    # every pixel of the small grid read as its nearest pixel of the figure
    _, near = ndi.distance_transform_edt(~small, return_indices=True)
    fields = np.full((len(bones), sh, sw), np.inf, dtype=np.float32)
    for bi, b in enumerate(bones):
        if b["role"] in ("jaw", "eye") or b["name"] in carried:
            continue
        seeds = set()
        a = np.array(b["head"]) * s
        t = np.array(b["tail"]) * s
        steps = max(2, int(np.linalg.norm(t - a) * 2))
        for k in np.linspace(0.0, 1.0, steps):
            p = a + (t - a) * k
            x, y = int(round(min(max(p[0], 0), sw - 1))), int(round(min(max(p[1], 0), sh - 1)))
            ny, nx = near[0][y, x], near[1][y, x]
            if idx[ny, nx] >= 0:
                seeds.add(int(idx[ny, nx]))
        if not seeds:
            continue
        d = dijkstra(graph, directed=False, indices=sorted(seeds), min_only=True)
        f = np.full((sh, sw), np.inf, dtype=np.float32)
        f[ys, xs] = d
        f = f[near[0], near[1]]
        # a piece of the figure no path reaches (a claw cut off by a layer behind it) goes by the straight distance, far behind
        lost = ~np.isfinite(f)
        if lost.any():
            gy, gx = np.mgrid[0:sh, 0:sw]
            f[lost] = 1e4 + _segment_distance(gx[lost], gy[lost], a, t)
        fields[bi] = f
    return fields / s, s


def _segment_distance(x, y, a, b):
    ab = b - a
    k = np.clip(((x - a[0]) * ab[0] + (y - a[1]) * ab[1]) / max(1e-9, float(ab @ ab)), 0.0, 1.0)
    return np.hypot(x - (a[0] + k * ab[0]), y - (a[1] + k * ab[1]))


def _grid_mesh(a, g):
    """A mesh over the pixels of [a] that show, following their outline: points every EDGE_STEP px along it (a little outside, so
    the soft edge is covered) and every [g] px well inside, triangulated, and every triangle that crosses empty paper dropped - so
    no triangle joins two parts a gap divides (an ear and the finger beside it). -> (points [n, 2], tris [m, 3])."""
    m = a > 0.02
    if m.sum() < 3:
        return np.zeros((0, 2)), np.zeros((0, 3), dtype=np.int64)
    md = ndi.binary_dilation(m, iterations=2)
    h, w = m.shape
    edge = md & ~ndi.binary_erosion(md)
    ys, xs = np.nonzero(edge)
    step = EDGE_STEP
    _, first = np.unique((ys // step) * (w // step + 1) + xs // step, return_index=True)
    rim = np.stack([xs[first], ys[first]], axis=1).astype(float)
    inner = ndi.binary_erosion(md, iterations=max(2, int(g * 0.6)))
    gy, gx = np.mgrid[g // 2:h:g, g // 2:w:g]
    keep = inner[gy, gx]
    core = np.stack([gx[keep], gy[keep]], axis=1).astype(float)
    pts = np.concatenate([rim, core]) if len(core) else rim
    if len(pts) < 3:
        return np.zeros((0, 2)), np.zeros((0, 3), dtype=np.int64)
    tris = Delaunay(pts).simplices
    # a triangle stays only if the paper inside it is the figure's: its middle, its edges' middles, and between
    t = pts[tris]                                          # [m, 3, 2]
    c = t.mean(axis=1, keepdims=True)
    probes = np.concatenate([c, (t + np.roll(t, 1, axis=1)) * 0.5, (t + c) * 0.5, (c * 2 + np.roll(t, 1, axis=1)) / 3.0], axis=1)
    px = np.clip(np.round(probes[..., 0]).astype(int), 0, w - 1)
    py = np.clip(np.round(probes[..., 1]).astype(int), 0, h - 1)
    ok = ndi.binary_dilation(md, iterations=3)[py, px].all(axis=1)
    tris = tris[ok]
    used = np.unique(tris)
    remap = -np.ones(len(pts), dtype=np.int64)
    remap[used] = np.arange(len(used))
    return pts[used], remap[tris]


def _weights(pts, fields, scale, bones, eyes, height, mouth=None):
    """Each vertex's bones: those within BLEND of the nearest through the figure, falling off over it, the MOST_BONES strongest kept;
    an eye's bone takes what lies inside it, all of it at its middle. -> [[[bone index, weight], ...] per vertex]."""
    nb, fh, fw = fields.shape
    gx = np.clip(np.round(pts[:, 0] * scale).astype(int), 0, fw - 1)
    gy = np.clip(np.round(pts[:, 1] * scale).astype(int), 0, fh - 1)
    d = fields[:, gy, gx].T                                  # [n, bones]
    band = max(4.0, BLEND * height)
    dmin = np.where(np.isfinite(d), d, 1e9).min(axis=1, keepdims=True)
    wts = np.clip(1.0 - (d - dmin) / band, 0.0, 1.0) ** 2
    wts[~np.isfinite(d)] = 0.0
    lost = wts.sum(axis=1) <= 0
    if lost.any():
        wts[lost, 0] = 1.0
    wts /= wts.sum(axis=1, keepdims=True)
    index = {b["name"]: i for i, b in enumerate(bones)}
    if mouth is not None:
        # the mouth's region, and a band round it, goes with the bone the jaw hangs from
        jm, bi = mouth
        outside = ndi.distance_transform_edt(~jm)
        h, w = jm.shape
        px = np.clip(np.round(pts[:, 0]).astype(int), 0, w - 1)
        py = np.clip(np.round(pts[:, 1]).astype(int), 0, h - 1)
        k = np.clip(1.0 - outside[py, px] / max(6.0, 0.6 * band), 0.0, 1.0)
        wts *= (1.0 - k)[:, None]
        wts[:, bi] += k
    for e in eyes:
        c = np.array(e["center"])
        rx, ry = e["radius"]
        q = np.sqrt(((pts[:, 0] - c[0]) / rx) ** 2 + ((pts[:, 1] - c[1]) / ry) ** 2)
        k = np.clip((1.3 - q) / 0.5, 0.0, 1.0)
        k = k * k * (3 - 2 * k)
        wts *= (1.0 - k)[:, None]
        wts[:, index[e["bone"]]] += k
    out = []
    for row in wts:
        top = np.argsort(-row)[:MOST_BONES]
        top = [i for i in top if row[i] > 0.01]
        tot = sum(row[i] for i in top)
        out.append([[int(i), round(float(row[i] / tot), 4)] for i in top])
    return out


def _outline_of(mask):
    """A polygon round [mask]'s largest piece: its boundary pixels walked in angle about its middle (a jaw's hole is a simple blob)."""
    m = _largest(mask)
    ys, xs = np.nonzero(m & ~ndi.binary_erosion(m))
    cy, cx = ys.mean(), xs.mean()
    ang = np.arctan2(ys - cy, xs - cx)
    order = np.argsort(ang)
    pts = np.stack([xs[order], ys[order]], 1).astype(float)
    keep = np.linspace(0, len(pts) - 1, min(len(pts), 96)).astype(int)
    return pts[keep]


def _flat(pts):
    return [round(float(v), 1) for v in np.asarray(pts).ravel()]


# --- the looks ---------------------------------------------------------------------------------------------------------

def _build_look(rgba, rig, fields, scale, path):
    """Three panels side by side: the skeleton on the drawing over a pixel grid; what each bone moves (each pixel in its bone's color);
    and the puppet bent - every bone turned TEST_TURN degrees, the jaw open, each eye swollen - so a bad weight shows as a tear."""
    h, w = rgba.shape[:2]
    bones = rig["bones"]
    a = _over_checker(rgba)
    d = ImageDraw.Draw(a)
    _grid(d, a.size)
    _draw_rig(d, rig)
    # what each bone moves
    fh, fw = fields.shape[1:]
    nb = len(bones)
    dd = fields.copy()
    dmin = np.min(np.where(np.isfinite(dd), dd, 1e9), axis=0)
    band = max(4.0, BLEND * float(rig["ground"] - rig["top"]))
    wts = np.clip(1.0 - (dd - dmin[None]) / band, 0, 1) ** 2
    wts[~np.isfinite(dd)] = 0
    tot = wts.sum(0)
    tot[tot <= 0] = 1
    cols = np.array([PALETTE[i % len(PALETTE)] for i in range(nb)], dtype=float)
    pix = np.tensordot(wts / tot, cols, axes=(0, 0))       # [h, w, 3]
    pix = np.asarray(Image.fromarray(np.clip(pix, 0, 255).astype(np.uint8)).resize((w, h), Image.BILINEAR)).astype(float)
    for e in rig["eyes"]:
        c = np.array(e["center"])
        rx, ry = e["radius"]
        yy, xx = np.mgrid[0:h, 0:w]
        q = np.sqrt(((xx - c[0]) / rx) ** 2 + ((yy - c[1]) / ry) ** 2)
        k = np.clip((1.3 - q) / 0.5, 0, 1)[..., None]
        bi = [b["name"] for b in bones].index(e["bone"])
        pix = pix * (1 - k) + cols[bi] * k
    lum = rgba[..., :3].mean(axis=2, keepdims=True) / 255.0
    shade = np.clip(pix * (0.35 + 0.65 * lum), 0, 255)
    al = rgba[..., 3:4] / 255.0
    jaw_mask = None
    if rig["cavity"]:
        jl = next(l for l in rig["layers"] if l["name"] == "jaw")
        jaw_mask = np.asarray(Image.open(Path(path).parent / "jaw.png"))[..., 3] > 20
        bi = [b["name"] for b in bones].index("jaw")
        shade[jaw_mask] = cols[bi] * (0.35 + 0.65 * lum[jaw_mask])
    b_img = Image.fromarray((shade * al + 235 * (1 - al)).astype(np.uint8))
    db = ImageDraw.Draw(b_img)
    _draw_rig(db, rig, labels=True)
    # bent
    c_img = _bent(rgba, rig, Path(path).parent)
    sheet = Image.new("RGB", (w * 3 + 40, h + 40), (255, 255, 255))
    sheet.paste(a, (10, 30))
    sheet.paste(b_img, (w + 20, 30))
    sheet.paste(c_img, (2 * w + 30, 30))
    ds = ImageDraw.Draw(sheet)
    f = _font(20)
    ds.text((12, 4), "the skeleton (grid: a line every 50 px)", fill=(0, 0, 0), font=f)
    ds.text((w + 22, 4), "what each bone moves", fill=(0, 0, 0), font=f)
    ds.text((2 * w + 32, 4), "bent: each bone turned %d degrees, the jaw open" % TEST_TURN, fill=(0, 0, 0), font=f)
    sheet.save(path)


def _draw_rig(d, rig, labels=True):
    f = _font(16)
    for i, b in enumerate(rig["bones"]):
        c = PALETTE[i % len(PALETTE)]
        (x0, y0), (x1, y1) = b["head"], b["tail"]
        if b["role"] == "eye":
            continue
        d.line([x0, y0, x1, y1], fill=(0, 0, 0), width=7)
        d.line([x0, y0, x1, y1], fill=c, width=4)
        d.ellipse([x0 - 6, y0 - 6, x0 + 6, y0 + 6], fill=c, outline=(0, 0, 0), width=2)
        if labels:
            d.text(((x0 + x1) / 2 + 6, (y0 + y1) / 2 - 8), b["name"], fill=c, font=f, stroke_width=3, stroke_fill=(0, 0, 0))
    for e in rig["eyes"]:
        (cx, cy), (rx, ry) = e["center"], e["radius"]
        d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], outline=(0, 220, 255), width=3)
    if rig["mouth"]:
        for pts in rig.get("_jaw_outline", []):
            d.line(pts + pts[:1], fill=(255, 0, 200), width=3)
        hx, hy = rig["mouth"]["hinge"]
        d.ellipse([hx - 7, hy - 7, hx + 7, hy + 7], fill=(255, 0, 200), outline=(0, 0, 0), width=2)


def pose_matrices(rig, angles, jaw_open=0.0, eye_scale=1.0, jaw_drop=0.0):
    """Each bone's transform (3x3, rest pixels to bent pixels) for [angles] (bone -> degrees, about its head; others 20)."""
    mats = {}
    for b in rig["bones"]:
        ang = angles.get(b["name"], 0.0)
        drop = 0.0
        if b["role"] == "jaw":
            ang = jaw_open
            drop = jaw_drop
        hx, hy = b["head"]
        r = math.radians(ang)
        rot = np.array([[math.cos(r), -math.sin(r), 0], [math.sin(r), math.cos(r), drop], [0, 0, 1]])
        sc = np.diag([eye_scale, eye_scale, 1.0]) if b["role"] == "eye" else np.eye(3)
        t = np.array([[1, 0, hx], [0, 1, hy], [0, 0, 1]]) @ rot @ sc @ np.array([[1, 0, -hx], [0, 1, -hy], [0, 0, 1]])
        mats[b["name"]] = (mats[b["parent"]] @ t) if b["parent"] else t
    return mats


def _bent(rgba, rig, folder):
    h, w = rgba.shape[:2]
    angles = {b["name"]: TEST_TURN for b in rig["bones"] if b["parent"]}
    mo = rig["mouth"] or {}
    mats = pose_matrices(rig, angles, jaw_open=float(mo.get("open", 0.0)), eye_scale=1.3, jaw_drop=float(mo.get("drop", 0.0)))
    names = [b["name"] for b in rig["bones"]]
    canvas = Image.new("RGBA", (w, h), (236, 236, 236, 255))
    for layer in rig["layers"]:
        img = Image.open(folder / layer["image"]).convert("RGBA")
        p = np.array(layer["points"]).reshape(-1, 2)
        hp = np.c_[p, np.ones(len(p))]
        wm = np.zeros((len(p), len(names)))
        for vi, vw in enumerate(layer["weights"]):
            for bi, wt in vw:
                wm[vi, bi] = wt
        each = np.stack([(mats[n] @ hp.T).T[:, :2] for n in names], axis=1)    # [n, bones, 2]
        bent = (each * wm[..., None]).sum(axis=1)
        tris = np.array(layer["tris"]).reshape(-1, 3)
        for t in tris:
            _warp_tri(img, canvas, p[t], bent[t])
    return canvas.convert("RGB")


def _warp_tri(src, dst, s, t):
    """The triangle [s] of [src] drawn where [t] is in [dst]: an affine map, clipped to the triangle."""
    x0, y0 = np.floor(t.min(0)).astype(int) - 1
    x1, y1 = np.ceil(t.max(0)).astype(int) + 1
    x0, y0 = max(0, x0), max(0, y0)
    x1, y1 = min(dst.width, x1), min(dst.height, y1)
    if x1 <= x0 or y1 <= y0:
        return
    a = np.c_[t, np.ones(3)]
    try:
        m = np.linalg.solve(a, s)         # t -> s
    except np.linalg.LinAlgError:
        return
    # PIL wants dst->src as (a, b, c, d, e, f) over the patch's own coordinates
    coeffs = (m[0, 0], m[1, 0], m[2, 0] + m[0, 0] * x0 + m[1, 0] * y0, m[0, 1], m[1, 1], m[2, 1] + m[0, 1] * x0 + m[1, 1] * y0)
    patch = src.transform((x1 - x0, y1 - y0), Image.AFFINE, coeffs, resample=Image.BILINEAR)
    mask = Image.new("L", patch.size, 0)
    ImageDraw.Draw(mask).polygon([(float(px - x0), float(py - y0)) for px, py in t], fill=255, outline=255)
    alpha = Image.fromarray((np.asarray(patch)[..., 3].astype(np.uint16) * np.asarray(mask) // 255).astype(np.uint8))
    patch.putalpha(alpha)
    dst.alpha_composite(patch, (x0, y0))


def _over_checker(rgba):
    h, w = rgba.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w]
    chk = np.where(((yy // 16 + xx // 16) % 2) == 0, 222, 238)[..., None].astype(float)
    al = rgba[..., 3:4] / 255.0
    return Image.fromarray((rgba[..., :3] * al + chk * (1 - al)).astype(np.uint8))


def _grid(d, size):
    w, h = size
    f = _font(14)
    for x in range(0, w, 50):
        d.line([x, 0, x, h], fill=(90, 90, 255) if x % 100 == 0 else (170, 170, 255), width=1)
        if x % 100 == 0:
            d.text((x + 2, 2), str(x), fill=(40, 40, 200), font=f)
    for y in range(0, h, 50):
        d.line([0, y, w, y], fill=(90, 90, 255) if y % 100 == 0 else (170, 170, 255), width=1)
        if y % 100 == 0:
            d.text((2, y + 2), str(y), fill=(40, 40, 200), font=f)


def _font(size):
    for name in ("DejaVuSans-Bold.ttf", "/usr/share/fonts/TTF/DejaVuSans-Bold.ttf", "/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


if __name__ == "__main__":
    sys.exit(main(sys.argv))
