"""The measures of the painting lab (TEST_PLAN.md, "Measures"), and the sheets to look at.

A mean over the face lies: large plain areas swamp the eyes, lips and crackle. So beside the plain error: the error weighted
by the picture's detail (how sharply it changes round each point), the likeness of its light and dark at three scales
(SSIM), how many of its lines are drawn and how many drawn lines are its (recall and precision), and the error inside
crops of what matters.
"""
import json

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

import lines as lines_mod
from canvas import PX
from color import dec, delta, enc, oklab

# Crops of what matters on each reference (mm: x0, y0, x1, y1) - drawn round its features by eye.
REGIONS = {
    "327484": {"bruised eye": (80, 55, 135, 110), "closed eye": (25, 60, 70, 105), "mouth": (40, 135, 112, 170),
               "crackle": (20, 15, 70, 50), "drip": (100, 100, 125, 200), "tear": (35, 98, 58, 125)},
    "257002": {"left eye": (15, 80, 70, 120), "right eye": (80, 80, 135, 120), "mouth": (20, 125, 130, 160),
               "rust": (105, 20, 145, 80), "diamond": (15, 95, 40, 130), "rivets": (55, 5, 95, 85)},
}


def _ssim(a, b, sig, mask):
    mu_a = ndimage.gaussian_filter(a, sig)
    mu_b = ndimage.gaussian_filter(b, sig)
    va = ndimage.gaussian_filter(a * a, sig) - mu_a ** 2
    vb = ndimage.gaussian_filter(b * b, sig) - mu_b ** 2
    cab = ndimage.gaussian_filter(a * b, sig) - mu_a * mu_b
    c1, c2 = (0.01 * 100) ** 2, (0.03 * 100) ** 2
    s = ((2 * mu_a * mu_b + c1) * (2 * cab + c2)) / ((mu_a ** 2 + mu_b ** 2 + c1) * (va + vb + c2))
    return float(s[mask].mean())


def detail_weight(ref_lab):
    g = sum(ndimage.sobel(ref_lab[..., c], 0) ** 2 + ndimage.sobel(ref_lab[..., c], 1) ** 2 for c in range(3)) ** 0.5
    return ndimage.gaussian_filter(g, PX * 0.5)


def measure(srgb, ref, ref_lines=None):
    """The measures of canvas picture `srgb` (h, w, 3, sRGB 0-1) against Reference `ref`."""
    lab = oklab(dec(srgb))
    face = ref.face
    de = delta(lab, ref.lab)
    w = detail_weight(ref.lab)
    out = {
        "error": float(de[face].mean()),
        "error_p90": float(np.percentile(de[face], 90)),
        "over_10": float((de[face] > 10).mean()),
        "detail_error": float((de * w)[face].sum() / w[face].sum()),
        "ssim_1mm": _ssim(lab[..., 0], ref.lab[..., 0], PX * 1.0, face),
        "ssim_2mm": _ssim(lab[..., 0], ref.lab[..., 0], PX * 2.0, face),
        "ssim_4mm": _ssim(lab[..., 0], ref.lab[..., 0], PX * 4.0, face),
    }
    if ref_lines is None:
        _, ref_lines = lines_mod.find(ref.srgb, PX, face)
    _, got = lines_mod.find(srgb, PX, face)
    near_got = ndimage.binary_dilation(got, iterations=1)
    near_ref = ndimage.binary_dilation(ref_lines, iterations=1)
    out["line_recall"] = float((ref_lines & near_got).sum() / max(ref_lines.sum(), 1))
    out["line_precision"] = float((got & near_ref).sum() / max(got.sum(), 1))
    regs = {}
    for name, (x0, y0, x1, y1) in REGIONS.get(ref.name, {}).items():
        sl = np.s_[int(y0 * PX):int(y1 * PX), int(x0 * PX):int(x1 * PX)]
        m = face[sl]
        regs[name] = float(de[sl][m].mean()) if m.any() else None
    out["regions"] = regs
    return out


def error_map(srgb, ref):
    de = delta(oklab(dec(srgb)), ref.lab)
    v = np.clip(de / 30.0, 0, 1)
    img = np.stack([v, v * 0.6, 1 - v], axis=-1) * ref.face[..., None]
    return img


def _u8(img):
    return Image.fromarray((np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8))


def _label(im, text):
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, im.width, 18], fill=(0, 0, 0))
    d.text((4, 3), text, fill=(255, 255, 255))
    return im


def sheet(path, panels):
    """Pictures side by side, each `(title, srgb)`, saved to `path`."""
    ims = [_label(_u8(p), t) for t, p in panels]
    W = sum(i.width for i in ims)
    H = max(i.height for i in ims)
    out = Image.new("RGB", (W, H), (20, 20, 20))
    x = 0
    for i in ims:
        out.paste(i, (x, 0))
        x += i.width
    out.save(path)


def crops(path, ref, rows, scale=2):
    """Each region of `ref` cropped from each picture in `rows` (`(title, srgb)`), a row a region, at `scale` times."""
    regs = REGIONS.get(ref.name, {})
    lines_out = []
    for name, (x0, y0, x1, y1) in regs.items():
        sl = np.s_[int(y0 * PX):int(y1 * PX), int(x0 * PX):int(x1 * PX)]
        ims = []
        for title, img in rows:
            im = _u8(img[sl])
            im = im.resize((im.width * scale, im.height * scale), Image.LANCZOS)
            ims.append(_label(im, "%s - %s" % (name, title)))
        lines_out.append(ims)
    if not lines_out:
        return
    W = max(sum(i.width for i in r) for r in lines_out)
    H = sum(max(i.height for i in r) for r in lines_out)
    out = Image.new("RGB", (W, H), (20, 20, 20))
    y = 0
    for r in lines_out:
        x = 0
        for i in r:
            out.paste(i, (x, y))
            x += i.width
        y += max(i.height for i in r)
    out.save(path)


def table(rows):
    """Measures side by side, `(title, measures)` each, as text."""
    keys = ["error", "detail_error", "over_10", "ssim_1mm", "ssim_2mm", "ssim_4mm", "line_recall", "line_precision"]
    head = "%-22s" % "" + "".join("%12s" % t[:12] for t, _ in rows)
    out = [head]
    for k in keys:
        out.append("%-22s" % k + "".join("%12.3f" % m[k] for _, m in rows))
    regs = list(rows[0][1].get("regions", {}).keys())
    for r in regs:
        out.append("%-22s" % ("  " + r) + "".join("%12.2f" % (m["regions"].get(r) or 0) for _, m in rows))
    return "\n".join(out)


def texture_energy(lab, px=PX, fine=0.5, over=2.0):
    """How much fine texture a picture has round each point: its lightness's departure from itself softened by `fine` mm, that departure's
    size averaged over `over` mm - a rust patch's grain, a haze's speckle; a flat coat none."""
    L = lab[..., 0]
    hp = np.abs(L - ndimage.gaussian_filter(L, px * fine))
    return ndimage.gaussian_filter(hp, px * over)


def edge_map(lab, px=PX):
    """How sharply a picture changes round each point (its edges and lines)."""
    g = sum(ndimage.sobel(lab[..., c], 0) ** 2 + ndimage.sobel(lab[..., c], 1) ** 2 for c in range(3)) ** 0.5
    return ndimage.gaussian_filter(g, px * 0.3)


def focus_boxes(score, face, px=PX, size=24.0, n=6):
    """The `n` places (mm boxes `size` across, apart) where `score` sums highest inside the face."""
    g = int(size * px)
    s = ndimage.uniform_filter(np.where(face, score, 0.0), g)
    out = []
    s = s.copy()
    for _ in range(n):
        k = np.unravel_index(np.argmax(s), s.shape)
        if s[k] <= 0:
            break
        y, x = k
        out.append((max(x - g // 2, 0) / px, max(y - g // 2, 0) / px, min(x + g // 2, face.shape[1]) / px, min(y + g // 2, face.shape[0]) / px))
        s[max(y - g, 0):y + g, max(x - g, 0):x + g] = 0
    return out
