#!/usr/bin/env python3
"""bake.py - a set's avatar, made from the actor's head (next/likeness.md, "One head").

    <voice_train_venv python> bake.py --spec <spec.json> [--progress <file>]

The spec: train.py's ({"frames", "rig", "front", "span"} - the set's moments, read by head_frames.py, and the
set's rig, posed against the actor's) and {"head", "video", "out", "steps", "preview"} - the actor's head
(head.py), which of its videos the set is of (its code; -1 for none: the mean of them all), where the avatar goes,
how many steps the set is fitted in and a folder for a picture of it.

THE HEAD IS THE ONE LEARNED FROM EVERY VIDEO, ADAPTED TO THE SET: its expression shifts and their components
held (the set's frames are read with the head's, `expr`) - how their face moves is every video's - and its splats'
own place, size, turn, colour and cover fitted to the set's moments, each pulled toward the head's (ADAPT_PULL):
held whole, the head drew every video at once - softer than one set's own, and below the beard an average of every
collar he wore (2026-10-23: a smear over the plaid shirt's). THE FACE IS EVERY VIDEO'S, WHAT IS ROUND IT THE SET'S:
a splat on the face's surface is pulled in full; one far from its triangle (the beard's length, what lies under the
jaw) or on the head (the hair, which he wears every way) takes FREE_PULL of it, fading as train.py's expression
shifts fade (SHIFT_NEAR to SHIFT_FAR); a colour, everywhere (the set's light and its detail are its own). AND BELOW
THE CHIN THE HEAD IS THE SET'S OWN: drawn alone, the head had painted the neck, the collar and the shoulders - an
average of every collar he wore - and the body had a hole there; pulled toward clear, 21k of its 50k splats there went
and the rest still painted it. So its splats below the chin (but the face's surface) are dropped, and laid again from
the set's moments as train.py lays a set's (`train.initial`'s splats round the face: the beard bound to the jaw's edge,
which carries it), free, and grown here with the set's body - laid below the chin up to the face itself
(`up_to_face`), so the collar is the body's, fitted to the still after. What is every video's is the face itself:
its surface, how it moves, the inside of the mouth. WHAT IS THE SET'S IS FITTED TO ITS OWN MOMENTS, in STEPS:
- ITS LOOK: the code its video learned (or the mean, for a video the head never saw), moved to the set's light;
- ITS ROOM: train.room_of over its moments, learned where seen, with a gain and colour correction per moment;
- ITS BODY: train.initial's, laid on its bones, learned and grown here - and fitted to the still after (fit.py).
Then the head is baked as the set's video looks (`HeadSplats.baked`), and the whole of them is written as
train.py writes an avatar: what fit.py fits, and what Godot reads.
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

import head as heads  # noqa: E402
import train  # noqa: E402

# The share of windows round the face (the rest over the body, which is fitted here).
FACE_WINDOWS = 0.6
# The head's own numbers that adapt to the set, and how hard each is pulled toward the head's (per unit squared, on
# the mean): its expression and look shifts are held.
ADAPTS = ("place", "log_scale", "turn", "colour", "cover")
ADAPT_PULL = 0.05
# The share of the pull a splat far from the face's surface, or on the head, takes - and every colour.
FREE_PULL = 0.1
# The head's splats at most, here.
HEAD_MOST = 500000
# The body's splats at most, here (fit.py may grow them further).
BODY_MOST = 240000


def say(*parts) -> None:
    print("actor: bake:", *parts, flush=True)


class Adapting(heads.HeadSplats):
    """THE HEAD AS A SET ADAPTS IT: beside its numbers, each splat's pull toward the head's (`weight`) and the numbers
    it is pulled toward (`held_at`), kept with each splat through every drop and copy - one made here is free; its
    expression and look shifts held through all of it."""

    weight = None
    held_at = None

    def hold(self, weight) -> None:
        self.weight = weight
        self.held_at = {n: self.p[n].detach().clone() for n in ADAPTS}

    def _replace(self, keep, extra):
        import torch
        kept = int(keep.sum())
        super()._replace(keep, extra)
        for name, p in self.p.items():
            p.requires_grad_(name in ADAPTS)
        if self.weight is None:
            return
        new = len(self) - kept
        self.weight = torch.cat([self.weight[keep], torch.zeros(new, device=self.bind.device)])
        for n in ADAPTS:
            self.held_at[n] = torch.cat([self.held_at[n][keep], self.p[n].detach()[kept:]])


def held(npz: str, device):
    """The actor's head as head.py saved it: (Adapting, codes [V, LOOKS])."""
    import numpy as np
    import torch
    a = np.load(npz)
    t = lambda x: torch.tensor(x, device=device)
    cov = np.clip(a["cover"], 1e-6, 1 - 1e-6)
    head = Adapting(t(a["bind"]).long(), t(a["place"]), t(a["log_scale"]), t(a["turn"]), t(a["colour_logit"]),
                            t(np.log(cov / (1 - cov))), int(a["tris"].shape[0]), t(a["place_d"]), t(a["colour_d"]),
                            k=int(a["place_d"].shape[1]), look_place=t(a["look_place"]), look_colour=t(a["look_colour"]),
                            looks=int(a["look_place"].shape[1]))
    for name, p in head.p.items():
        p.requires_grad_(name in ADAPTS)
    return head, a["codes"]


def render(head, code, body, rig, data, scene, i: int, wx: int, wy: int, w: int, h: int, learned=True):
    """Frame i's window: the head as [param code] looks and the set's body, over the set's room."""
    import torch
    import raster
    origin, axes, unit, _v = rig.frames(data, i)
    expr = data.expr[i]
    hm, hs, ht = head.world(origin, axes, unit, expr, code)
    bm, bs, bt = body.world(origin, axes, unit)
    means2d, conics, depth, radii = raster.project(torch.cat([hm, bm]), torch.cat([hs, bs]), torch.cat([ht, bt]))
    if means2d.requires_grad:
        means2d.retain_grad()
    colours = torch.cat([head.colours(expr, code), body.colours()])
    if learned:
        c = scene.correct[i]
        colours = (colours @ c[:3] + c[3]).clamp(0.0, 1.0)
    covers = torch.cat([head.covers(), body.covers(data.bone_seen[i])])
    shifted = means2d - torch.tensor([float(wx), float(wy)], device=means2d.device)
    image, cover = raster.rasterize(shifted, conics, colours, covers, depth, radii, h, w,
                                    scene.behind(i, wx, wy, w, h, learned))
    return image, cover, means2d, radii, unit


def whole(head_baked, body, k: int):
    """The head as baked and the body, one train.Splats (the body's expression shifts none)."""
    import torch
    n = len(body)
    z = torch.zeros((n, k, 3), device=body.bind.device)
    cat = lambda name, extra=None: torch.cat([head_baked.p[name].data, body.p[name].data if extra is None else extra])
    return train.Splats(torch.cat([head_baked.bind, body.bind]), cat("place"), cat("log_scale"), cat("turn"),
                        cat("colour"), cat("cover"), head_baked.T, cat("place_d", z), cat("colour_d", z), k=k)


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
    data = train.Frames({**spec, "expr": spec["head"]}, dev)
    rig = train.Rig(spec["rig"], dev)
    head, codes = held(spec["head"], dev)
    v = int(spec.get("video", -1))
    start = codes[v] if 0 <= v < codes.shape[0] else codes.mean(0)
    code = torch.nn.Parameter(torch.tensor(start, device=dev, dtype=torch.float32))
    s = train.initial(rig, data, dev, up_to_face=True)
    # BELOW THE CHIN, THE SET'S OWN: the head's splats there (but the face's surface) dropped, and laid again from the
    # set's moments - initial's splats round the face, those below the chin - free
    with torch.no_grad():
        at = int(data.measured[0])
        origin, axes, unit, verts = rig.frames(data, at)
        chin = float(verts[152, 1])
        means, _s, _t = head.world(origin, axes, unit, data.expr[at], code)
        # all of them: the chin (MediaPipe's 152) is the face's lowest point, and the neck's splats, bound to the jaw's
        # edge, stand near it (kept "on the face", 45k of 50k still painted the collar)
        under = means[:, 1] > chin
        head._replace(~under, {})
        head.hold(FREE_PULL + (1.0 - FREE_PULL) * head.shift_weight())
        laid, _s, _t = s.world(origin, axes, unit)
        lo = rig.T * train.PER_TRIANGLE
        mine = torch.zeros(len(s), dtype=torch.bool, device=dev)
        mine[lo:lo + train.AROUND] = True
        mine &= laid[:, 1] > chin
        n_new = int(mine.sum())
        z = lambda m: torch.zeros((n_new, m, 3), device=dev)
        head._replace(torch.ones(len(head), dtype=torch.bool, device=dev),
                      {"bind": s.bind[mine], "place": s.p["place"].data[mine], "log_scale": s.p["log_scale"].data[mine],
                       "turn": s.p["turn"].data[mine], "colour": s.p["colour"].data[mine],
                       "cover": s.p["cover"].data[mine], "place_d": z(head.p["place_d"].shape[1]),
                       "colour_d": z(head.p["colour_d"].shape[1]), "look_place": z(head.p["look_place"].shape[1]),
                       "look_colour": z(head.p["look_colour"].shape[1])})
    say("below the chin, %d of the head's splats dropped and %d laid from the set's moments" % (int(under.sum()), n_new))
    on = s.bind > rig.T
    body = train.Splats(s.bind[on], s.p["place"].data[on], s.p["log_scale"].data[on], s.p["turn"].data[on],
                        s.p["colour"].data[on], s.p["cover"].data[on], rig.T,
                        torch.zeros((int(on.sum()), 0, 3), device=dev), torch.zeros((int(on.sum()), 0, 3), device=dev),
                        k=0)
    with torch.no_grad():
        plate, seen = data.room()
    scene = train.Scene(data, dev, plate, seen)
    code_opt = torch.optim.Adam([code], lr=5e-3)

    def pulled(name):
        w = head.weight if name != "colour" else head.weight.clamp(max=FREE_PULL)
        return (w.reshape((-1,) + (1,) * (head.p[name].dim() - 1)) * (head.p[name] - head.held_at[name]) ** 2).mean()
    steps = int(spec.get("steps", 2000))
    until = train.until_of(steps)
    say("%d moments, %d held out; the head's %d splats as video %d looks, a body of %d to start; %d steps"
        % (len(data.train), len(data.held), len(head), v, len(body), steps))
    rng = np.random.default_rng(0)
    order = np.concatenate([rng.permutation(data.train) for _ in range(steps // max(1, data.train.size) + 1)])[:steps]
    data.read_ahead(order)
    front = 1.0 - data.front
    W = train.WINDOW
    t0 = time.time()
    for step in range(1, steps + 1):
        i = int(order[step - 1])
        img, person = data.get(i)
        wx, wy = data.window(i, rng, rng.random() < FACE_WINDOWS)
        image, cover, means2d, radii, unit = render(head, code, body, rig, data, scene, i, wx, wy, W, W)
        truth = img[wy:wy + W, wx:wx + W]
        m = front[wy:wy + W, wx:wx + W]
        l1 = ((image - truth).abs() * m[..., None]).sum() / (m.sum() * 3 + 1e-6)
        dssim = ((1.0 - train.ssim_map(image, truth)) * m[..., None]).sum() / (m.sum() * 3 + 1e-6)
        cov = ((cover - person[wy:wy + W, wx:wx + W]).abs() * m).sum() / (m.sum() + 1e-6)
        loss = ((1.0 - train.SSIM_SHARE) * l1 + train.SSIM_SHARE * dssim + train.COVER_SHARE * cov
                + heads.CODE_PULL * ((code - torch.tensor(start, device=dev)) ** 2).mean()
                + ADAPT_PULL * sum(pulled(name) for name in ADAPTS)
                + train.PLATE_PULL * scene.pulled())
        for opt in (head.opt, body.opt, scene.opt, code_opt):
            opt.zero_grad(set_to_none=True)
        loss.backward()
        with torch.no_grad():
            if step < until and means2d.grad is not None:
                nh = len(head)
                g = means2d.grad.norm(dim=-1) * (W * 0.5)
                p = means2d - torch.tensor([float(wx), float(wy)], device=dev)
                r = radii.float()
                there = (p[:, 0] + r > 0) & (p[:, 0] - r < W) & (p[:, 1] + r > 0) & (p[:, 1] - r < W)
                body.pull[there[nh:]] += g[nh:][there[nh:]]
                body.seen[there[nh:]] += 1.0
                # the head grows only where it is free (what is held stays the head's)
                free = there[:nh] & (head.weight <= FREE_PULL)
                head.pull[free] += g[:nh][free]
                head.seen[free] += 1.0
        for opt in (head.opt, body.opt, scene.opt, code_opt):
            opt.step()
        if train.DENSIFY_FROM <= step < until and step % train.DENSIFY_EVERY == 0:
            body.densify(unit, BODY_MOST)
            head.densify(unit, HEAD_MOST)
        if step % train.OPACITY_RESET == 0 and step < until:
            body.reset_cover()
        if step > until and step % train.PRUNE_EVERY == 0:
            body.prune()
        if step % 250 == 0:
            train.progress(a.progress, 0.95 * step / steps)
            say("step %d: L1 %.4f, cover %.4f, %d on the body, the look %.2f from its video's, %.0f s"
                % (step, l1.item(), cov.item(), len(body), float((code.detach() - torch.tensor(start, device=dev)).norm()),
                   time.time() - t0))
    head.prune()
    k = int(head.p["place_d"].shape[1])
    baked = head.baked(code.detach())
    splats = whole(baked, body, k)
    # what it holds on the set's moments it never fitted, as played (no light of each moment's own)
    psnr = []
    with torch.no_grad():
        for i in data.measured:
            i = int(i)
            img, _p = data.get(i, ahead=False)
            x0, y0, x1, y1 = data.face_box(i)
            wx = int(np.clip((x0 + x1) / 2 - W / 2, 0, data.W - W))
            wy = int(np.clip((y0 + y1) / 2 - W / 2, 0, data.H - W))
            got = train.render(splats, rig, data, scene, i, wx, wy, W, W, learned=False)[0]
            psnr.append(-10.0 * math.log10(max(float(((got - img[wy:wy + W, wx:wx + W]) ** 2).mean()), 1e-10)))
            if spec.get("preview") and len(psnr) <= 4:
                os.makedirs(spec["preview"], exist_ok=True)
                pic = torch.cat([img[wy:wy + W, wx:wx + W], got], 1).clamp(0, 1).cpu().numpy()
                Image.fromarray((pic * 255.0 + 0.5).astype(np.uint8)).save(
                    os.path.join(spec["preview"], "%d.jpg" % len(psnr)), quality=88)
    train.save(splats, rig, data, scene, spec["rig"], spec["out"], extra={"video": v})
    train.progress(a.progress, 1.0)
    say("%d splats (%d on the body); on %d moments it never fitted: PSNR %.2f dB round the face; %.1f minutes"
        % (len(splats), len(body), len(psnr), float(np.mean(psnr)) if psnr else 0.0, (time.time() - t0) / 60.0))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
