#!/usr/bin/env python3
"""fit.py - an avatar's body fitted to the still it is played from (next/likeness.md, "The body as the still
holds it").

    <voice_train_venv python> fit.py --spec <spec.json> [--progress <file>]

The spec: train.py's ({"frames", "rig", "front", "span"}) and {"poses", "avatar", "still", "picture",
"matte", "out", "steps"} - the rig's poses.json, the avatar train.py made, which still is played (an index into
the poses' stills), its picture with what stands before them filled from round it (`body_K.jpg`) and its matte,
where the fitted avatar goes and how many steps.

LEARNED FROM EVERY FRAME, THE BODY IS A BLUR (2026-10-23: the sweater's knit gone, the hands two smudges - and
with three times the splats no sharper): nothing holds a sweater still from one frame to the next. On his frames
the pose's torso jumped where he sat still (its width 3.5% and its place 20 px every half second at the median,
11% and 48 px at the 90th percentile; the face's scale moves 1.6%), and held still instead - or carried by the
head, or by the pose smoothed over seconds - the median of his chest kept under a tenth of one frame's detail:
the knit stretches and folds as he breathes and moves his arms. But the body that is played is the still's,
moved by its bones. So THE SPLATS BOUND TO A BONE ARE FITTED AGAIN TO THE STILL ALONE, the head's splats and the
room held as learned: the sweater's knit, the hands as they rest. NOT WHERE THE HEAD IS SOLID (HEAD_COVER):
splats bound to a bone fitted to one picture could paint its face there, and the torso would carry it; what lies
behind it keeps what the frames taught (round the soft edge of the beard, it shows through). Under what stands before them (the microphone)
their picture is the one filled from round it, and their outline there is not asked for. First THE HEAD'S
SPLATS PAST ITS REACH are dropped (`train.astray`: on his avatar 505 large faint ones had painted a fifth of the
frame, his chest, which would have turned with his head). The splats may grow where the still pulls at them (to
FIT_MOST in all: the medium draws every one each frame), never into needles (FIT_LONG, a splat's longest side to
its next: fitted beside the beard, they grew into its strands).

Writes <out> (fit.npz) as train.py writes an avatar, with what Godot reads beside it (.json - naming the still
it was fitted to, `still` - .bin, .plate.png).
"""

from __future__ import annotations

import argparse
import json
import math
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import train  # noqa: E402

# The most splats in all once fitted, the share of the steps they may grow in, and how long a splat may be.
FIT_MOST = 360000
FIT_GROWS = 0.6
FIT_LONG = 6.0
# Where the head's splats cover this much is the head's.
HEAD_COVER = 0.9


def say(*parts) -> None:
    print("actor: fit:", *parts, flush=True)


def as_frame(data: train.Frames, rig: train.Rig, sp: dict) -> int:
    """THE STILL AS ONE MORE FRAME of [param data]: its face's pose and scores (its points as tracked are its
    scores' face: it is played so), its expression, its bones (the poses' row [param sp]); its index."""
    import numpy as np
    import torch
    dev = data.device

    def t(x):
        return torch.tensor(np.asarray(x, np.float32), device=dev)
    i = int(data.blend.shape[0])
    face = rig.canon + torch.einsum("k,kvc->vc", t(sp["blend"]), rig.basis)
    data.aligned = torch.cat([data.aligned, face[None, : data.aligned.shape[1]]])
    data.blend = torch.cat([data.blend, t(sp["blend"])[None]])
    data.scale = torch.cat([data.scale, t([sp["scale"]])])
    data.rot = torch.cat([data.rot, t(sp["rot"])[None]])
    data.shift = torch.cat([data.shift, t(sp["shift"])[None]])
    e = (np.asarray(sp["blend"], np.float64) - data.expr_mean) @ data.expr_basis / np.maximum(data.expr_scale, 1e-6)
    data.expr = torch.cat([data.expr, t(e)[None]])
    bones = sp["bones"]
    data.bone_origin = torch.cat([data.bone_origin, t([b["origin"] for b in bones])[None]])
    data.bone_axes = torch.cat([data.bone_axes, t([b["axes"] for b in bones]).transpose(1, 2)[None]])
    data.bone_unit = torch.cat([data.bone_unit, t([b["unit"] for b in bones])[None]])
    data.bone_seen = torch.cat([data.bone_seen, t([b["seen"] for b in bones])[None]])
    return i


def head_cover(splats, rig, data, i: int):
    """How much the head's own splats (the face's and the head's) cover each pixel of frame [param i], as played."""
    import torch
    import raster
    origin, axes, unit, _v = rig.frames(data, i, tracked=False)
    means, scales, turns = splats.world(origin, axes, unit, data.expr[i])
    m2, conics, depth, radii = raster.project(means, scales, turns)
    covers = splats.covers(data.bone_seen[i]) * (splats.bind <= rig.T).float()
    black = torch.zeros((data.H, data.W, 3), device=means.device)
    return raster.rasterize(m2, conics, splats.colours(data.expr[i]), covers, depth, radii, data.H, data.W, black)[1]


def not_needles(splats, body) -> None:
    """No body splat longer than FIT_LONG times its next side."""
    import torch
    with torch.no_grad():
        ls = splats.p["log_scale"].data
        top = ls.topk(2, dim=-1)
        most = top.values[:, 1] + math.log(FIT_LONG)
        long = body & (top.values[:, 0] > most)
        if bool(long.any()):
            rows = torch.nonzero(long)[:, 0]
            ls[rows, top.indices[rows, 0]] = most[rows]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--spec", required=True)
    ap.add_argument("--progress", default="")
    a = ap.parse_args()
    import numpy as np
    import torch
    from PIL import Image
    spec = json.load(open(a.spec))
    if not torch.cuda.is_available():
        say("no graphics card PyTorch can use")
        return 2
    dev = torch.device("cuda")
    torch.manual_seed(0)
    # read with the components its splats were learned with (the actor's head's, for a head made from every video)
    data = train.Frames({**spec, "expr": spec["avatar"]}, dev)
    rig = train.Rig(spec["rig"], dev)
    splats = train.load(spec["avatar"], dev)
    # the room as the avatar learned it, held
    scene = train.Scene(data, dev, torch.tensor(np.load(spec["avatar"])["plate"], device=dev))
    stills = json.load(open(spec["poses"])).get("stills", [])
    k = int(spec["still"])
    if k >= len(stills) or not isinstance(stills[k], dict):
        say("their head was not found in still %d" % k)
        return 2
    i = as_frame(data, rig, stills[k])
    with torch.no_grad():
        far = train.astray(splats, rig, data, i)
    if bool(far.any()):
        splats._replace(~far, {})

    def picture(path, mode):
        x0, y0, w, h = data.crop
        im = Image.open(path).convert(mode).crop((x0, y0, x0 + w, y0 + h))
        return torch.tensor(np.asarray(im, np.float32) / 255.0, device=dev)
    still = picture(spec["picture"], "RGB")
    matte = picture(spec["matte"], "L")

    # WHERE THE STILL IS FITTED: not where the head is solid; their outline not under what stands before them
    with torch.no_grad():
        head = head_cover(splats, rig, data, i) > HEAD_COVER
    keep = (~head).float()
    outline = keep * (1.0 - data.front)
    ys, xs = torch.nonzero((matte > 0.5) & (keep > 0.5), as_tuple=True)
    if ys.numel() == 0:
        say("nothing of their body to fit in still %d" % k)
        return 2
    box = [float(xs.min()), float(ys.min()), float(xs.max()), float(ys.max())]

    def error(img):
        se = (((img - still) ** 2) * keep[..., None]).sum() / (keep.sum() * 3 + 1e-6)
        return -10.0 * math.log10(max(float(se), 1e-10))

    with torch.no_grad():
        before = error(train.render(splats, rig, data, scene, i, 0, 0, data.W, data.H, tracked=False, learned=False)[0])
    steps = int(spec.get("steps", 3000))
    S = min(train.WINDOW, data.W, data.H)
    body = splats.bind > rig.T
    say("still %d: %d of %d splats on the body (%d of the head's past its reach dropped), %.2f dB where it is fitted; "
        "%d steps" % (k, int(body.sum()), len(splats), int(far.sum()), before, steps))
    rng = np.random.default_rng(0)
    t0 = time.time()
    for step in range(1, steps + 1):
        wx = int(np.clip(rng.uniform(box[0], box[2]) - S / 2, 0, data.W - S))
        wy = int(np.clip(rng.uniform(box[1], box[3]) - S / 2, 0, data.H - S))
        image, cover, means2d, radii, unit = train.render(splats, rig, data, scene, i, wx, wy, S, S, tracked=False,
                                                          learned=False)
        truth = still[wy:wy + S, wx:wx + S]
        m = keep[wy:wy + S, wx:wx + S]
        l1 = ((image - truth).abs() * m[..., None]).sum() / (m.sum() * 3 + 1e-6)
        dssim = ((1.0 - train.ssim_map(image, truth)) * m[..., None]).sum() / (m.sum() * 3 + 1e-6)
        mo = outline[wy:wy + S, wx:wx + S]
        cov = ((cover - matte[wy:wy + S, wx:wx + S]).abs() * mo).sum() / (mo.sum() + 1e-6)
        loss = (1.0 - train.SSIM_SHARE) * l1 + train.SSIM_SHARE * dssim + train.COVER_SHARE * cov
        splats.opt.zero_grad(set_to_none=True)
        loss.backward()
        with torch.no_grad():
            for name in train.Splats.NAMES:
                g = splats.p[name].grad
                if g is not None:
                    g[~body] = 0.0
            if means2d.grad is not None:
                p = means2d - torch.tensor([float(wx), float(wy)], device=dev)
                r = radii.float()
                there = body & (p[:, 0] + r > 0) & (p[:, 0] - r < S) & (p[:, 1] + r > 0) & (p[:, 1] - r < S)
                splats.pull[there] += means2d.grad[there].norm(dim=-1) * (S * 0.5)
                splats.seen[there] += 1.0
        splats.decay(step / steps)
        splats.opt.step()
        not_needles(splats, body)
        if step % train.DENSIFY_EVERY == 0 and step <= FIT_GROWS * steps:
            splats.densify(unit, FIT_MOST)
            body = splats.bind > rig.T
        if step % 500 == 0:
            train.progress(a.progress, step / steps)
            say("step %d: L1 %.4f, %d splats (%d on the body), %.0f s" % (step, l1.item(), len(splats), int(body.sum()),
                                                                          time.time() - t0))
    with torch.no_grad():
        after = error(train.render(splats, rig, data, scene, i, 0, 0, data.W, data.H, tracked=False, learned=False)[0])
    # THE BODY BENDS as it is played: each body splat's second influence, by where it rests in the still
    train.save(splats, rig, data, scene, spec["rig"], spec["out"], at=i, extra={"still": k},
               second=train.second_of(splats, rig, data, i))
    say("still %d fitted: %.2f dB where it is fitted, from %.2f; %d splats; %.1f minutes" % (k, after, before, len(splats),
                                                                                          (time.time() - t0) / 60.0))
    train.progress(a.progress, 1.0)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
