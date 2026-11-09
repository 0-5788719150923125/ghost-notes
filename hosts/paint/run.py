#!/usr/bin/env python3
"""THE PAINTER AT THE TABLE, AS A HOST (next/face_layers.md): an episode's picture, painted again in layers (`layer_K.png`), laid with
real marks - each layer's thin parts traced on its own picture, its broad parts by strokes found by gradient descent (optimize.py) - and
written as the show plays it (export.py): each element's program and maps.

    run.py <spec.json>

The spec is JSON, never argv: {"out": folder, "bare_image": face_bare.png, "at": [x, y], "size": [w, h] (the surface's place in the
bare picture, pixels), "px": its pixels a millimeter, "bare": "#rrggbb" (the surface's own color), "paints": {name: "#rrggbb"} (the
table's creams), "layers": [{name, soft}], "images": [layer_1.png, ...]}. Writes into `out`: `elements.json`, `maps/`, and `done.json`
({ok, elements, minutes} or {ok: false, error}). Progress goes to stdout, a line a step.
"""
import json
import sys
import time
import traceback
from pathlib import Path

import numpy as np
from PIL import Image

# (...run isolated - `python -I`, as every host is - its own folder's modules found by name all the same)
sys.path.insert(0, str(Path(__file__).resolve().parent))


class FromSpec:
    """The surface a spec describes, as the lab's Reference holds one."""

    def __init__(self, spec, last_rgba):
        from canvas import PX
        from color import dec, hex_rgb, oklab
        from refs import _filled
        self.name = "episode"
        self.paints = {n: hex_rgb(c) for n, c in spec["paints"].items()}
        self.bare = hex_rgb(spec.get("bare", "#c89e80"))
        px = float(spec.get("px", 3.0))
        w, h = spec["size"]
        self.frame = (w / px, h / px)
        img = Image.fromarray(_filled((np.clip(last_rgba, 0, 1) * 255).astype(np.uint8)))
        self.hi = np.asarray(img).astype(float) / 255.0
        self.hi_px = px
        self.w = int(round(self.frame[0] * PX))
        self.h = int(round(self.frame[1] * PX))
        big = np.asarray(img.resize((self.w, self.h), Image.BICUBIC)).astype(float) / 255.0
        self.face = big[..., 3] > 0.5
        self.srgb = np.clip(big[..., :3], 0, 1)
        self.lab = oklab(dec(self.srgb))


def as_reference(painted_path, bare_path, at, size, skin):
    """A painted layer as the reference is made from the painted face (Skins.face_reference): cut to the surface's frame, the mask's own
    lighting divided out, clear where the bare surface is dark. -> RGBA floats."""
    p = Image.open(painted_path).convert("RGB")
    b = Image.open(bare_path).convert("RGB")
    if p.size != b.size:
        p = p.resize(b.size, Image.BILINEAR)
    p = np.asarray(p).astype(float) / 255.0
    b = np.asarray(b).astype(float) / 255.0
    lum = lambda c: 0.2126 * c[..., 0] + 0.7152 * c[..., 1] + 0.0722 * c[..., 2]
    bc = np.array([int(skin[i:i + 2], 16) / 255.0 for i in (1, 3, 5)])
    x0, y0 = at
    w, h = size
    pc, bb = p[y0:y0 + h, x0:x0 + w], b[y0:y0 + h, x0:x0 + w]
    lit = np.clip(lum(bb) / max(lum(bc), 0.05), 0.62, 1.0)[..., None]
    rgb = np.minimum(pc / lit, 1.0)
    a = (lum(bb) > 0.08).astype(float)[..., None]
    return np.concatenate([rgb, a], axis=-1)


def main():
    spec = json.loads(Path(sys.argv[1]).read_text())
    out = Path(spec["out"])
    out.mkdir(parents=True, exist_ok=True)
    done = out / "done.json"
    if done.exists():
        done.unlink()
    t0 = time.time()
    try:
        from refs import _filled
        layers = spec["layers"]
        images = spec["images"]
        if len(images) != len(layers) or not layers:
            raise ValueError("%d layers but %d pictures" % (len(layers), len(images)))
        refs = [as_reference(p, spec["bare_image"], spec["at"], spec["size"], spec.get("bare", "#c89e80")) for p in images]
        ref = FromSpec(spec, refs[-1])
        pics = []
        for r in refs:
            img = Image.fromarray(_filled((np.clip(r, 0, 1) * 255).astype(np.uint8)))
            big = np.asarray(img.resize((ref.w, ref.h), Image.BICUBIC)).astype(float) / 255.0
            pics.append(np.clip(big[..., :3], 0, 1))
        print("  %d layers, %d paints; painting" % (len(layers), len(ref.paints)), flush=True)
        from layers_paint import paint_layers
        p, starts, _ = paint_layers(ref, layers, pics, log=lambda s: print(s, flush=True))
        from export import export
        els = export(p, starts, layers, out, log=lambda s: print(s, flush=True))
        done.write_text(json.dumps({"ok": True, "elements": len(els), "minutes": sum(e["seconds"] for e in els) / 60,
                                    "seconds_to_solve": round(time.time() - t0, 1)}))
    except Exception as e:
        traceback.print_exc()
        done.write_text(json.dumps({"ok": False, "error": "%s: %s" % (type(e).__name__, e)}))
        sys.exit(1)


if __name__ == "__main__":
    main()
