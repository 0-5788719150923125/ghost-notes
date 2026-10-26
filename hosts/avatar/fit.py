#!/usr/bin/env python3
"""fit.py - an avatar fitted to the still it is played from (next/likeness.md, "The body as the still holds it",
"The sixth pass").

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
moved by its bones. So THE SPLATS BOUND TO A BONE ARE FITTED AGAIN TO THE STILL ALONE, the room held as learned:
the sweater's knit, the hands as they rest. NOT WHERE THE HEAD IS SOLID (HEAD_COVER):
splats bound to a bone fitted to one picture could paint its face there, and the torso would carry it; what lies
behind it keeps what the frames taught (round the soft edge of the beard, it shows through). Under what stands before them (the microphone)
their picture is the one filled from round it, and their outline there is not asked for. First THE HEAD'S
SPLATS PAST ITS REACH are dropped (`train.astray`: on his avatar 505 large faint ones had painted a fifth of the
frame, his chest, which would have turned with his head). The splats may grow where the still pulls at them (to
FIT_MOST in all: the medium draws every one each frame), never into needles (FIT_LONG, a splat's longest side to
its next: fitted beside the beard, they grew into its strands).

AND THE HEAD IS FITTED TO IT TOO (2026-10-25, the user: "around the edges of the face is heavy artifacting: at the
neck, black splotches and hard lines, and around the head - heavy blurring, such that ears just look like smears"):
the head is every video's, adapted to a set's moments, and held whole it painted the neck under the beard dark with
a hard edge where the shared splats below the chin had been dropped, the hair and ears as a blur - 23.3 dB on the
whole still. Fitted too, the still is 42 dB and the hair, beard and neck are the still's. BUT NOT WHERE THE FACE
OPENS (`where_it_opens`): fitted there, splats round the lips took the still's closed mouth and the parted mouth
showed them as coloured specks and streaks, and the shut lids the still's open eye. Held by their binding - the
triangles on the lips and the eyes' rims, or every splat an expression moves - they still did, or left blurred patches
beside sharp ones: what shows in the opening is whatever stands there, bound to anything. So a head splat is held by
WHERE IT STANDS in the still: within the lips' outline or an eye's rim, wholly, and fitted more and more past them,
wholly at MOUTH_EDGE and EYE_EDGE of the face's height; every splat keeps its expression shifts. (Before the moments
held it - below - the beard under the lips was held too, as far as the lower lip goes, 0.15 of the face's height: a soft
patch in a sharp beard, the played mouth with 40% of the still's fine detail there; held to the moments, it is fitted -
47%, its openings as clean.) Body splats are fitted where the head is not solid, as
before; none of them grows into a needle; a head splat under LEAST_COPY pixels is never copied (bake.py's specks).

BUT THE MOMENTS KEEP IT WHOLE (2026-10-25, the user: "the whole scene has needle-like fractures throughout it,
especially near the face, and especially noticeable when the face moves"): fitted to the still alone, the head's
splats could stand in any layers that add up to that one picture - 41.4 dB on it, but 19.9 on the set's moments it
never fitted, where the avatar it started from held 21.75 - and played (the mouth open, the head turned a few
degrees, the face's own ways) the layers slid apart: a dark line from the mouth's corner across the cheek, needles
through the beard, green and purple specks on the neck. The trainer drew the same from the very frames Godot wrote;
the avatar before it, only where the mouth folded the face. So each step one of the set's own moments is drawn too
(`moment_loss`: as tracked, in its own light, learned here) and asks the head for its picture in squares MOMENT_POOL
pixels wide - what moves with the face holds together as it did in them, and the fine detail is the still's alone
(squares of 8 held it as well, 21.25 dB). On his set: 38.0 dB on the still, 21.4 on those moments, and played, the
beard and the cheek whole as the mouth opens. (Where the beard's edges still broke, the mouth had folded the face:
the player's, `LikenessMedium.unfolded`.)

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

import parts  # noqa: E402  (first: it puts hosts/face, actor.py's, on the path)
import actor  # noqa: E402
import train  # noqa: E402

# The most splats in all once fitted, the share of the steps they may grow in, and how long a splat may be.
FIT_MOST = 360000
FIT_GROWS = 0.6
FIT_LONG = 6.0
# Where the head's splats cover this much is the head's: no body splat is fitted there.
HEAD_COVER = 0.9
# WHERE THE FACE OPENS, in the face's heights: how far past the lips' outline and past an eye's rim a head splat is
# held less and less.
MOUTH_EDGE = 0.02
EYE_EDGE = 0.04
# No head splat under this many pixels is copied (bake.py's LEAST_COPY).
LEAST_COPY = 1.0
# THE MOMENTS KEEP IT WHOLE: each step one of the set's moments too, round the face, asked only for its means over
# squares MOMENT_POOL pixels wide, at MOMENT_SHARE of the still's loss; each moment's light learned at LIGHT_RATES (its
# colour correction, its gain).
MOMENT_POOL = 4
MOMENT_SHARE = 1.0
LIGHT_RATES = (2e-3, 5e-3)
# THE BEARD MOVES AS ONE ([method hang_beard]): how far below the lips' outline, in the face's heights, the beard under
# them begins.
BEARD_UNDER = 0.02


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


def not_needles(splats, fitted) -> None:
    """No splat of [param fitted] longer than FIT_LONG times its next side."""
    import torch
    with torch.no_grad():
        ls = splats.p["log_scale"].data
        top = ls.topk(2, dim=-1)
        most = top.values[:, 1] + math.log(FIT_LONG)
        long = fitted & (top.values[:, 0] > most)
        if bool(long.any()):
            rows = torch.nonzero(long)[:, 0]
            ls[rows, top.indices[rows, 0]] = most[rows]


def where_it_opens(splats, rig, data, i: int):
    """HOW FREE EACH SPLAT IS TO BE FITTED, by where it stands in the still (frame [param i]): a head splat in the lips'
    convex outline or in an eye's rim not at all, wholly MOUTH_EDGE or EYE_EDGE of the face's height past it, smoothly
    between; a body splat wholly. [N]"""
    import torch
    with torch.no_grad():
        origin, axes, unit, verts = rig.frames(data, i, tracked=False)
        means, _s, _t = splats.world(origin, axes, unit, data.expr[i])
        p, v = means[:, :2], verts[:, :2]
        height = float((v[parts.TOP] - v[parts.CHIN]).norm())
        held = torch.zeros(len(splats), device=p.device)
        for pts, edge in ((v[actor.LIPS_OUTER], MOUTH_EDGE), (v[actor.EYE_RIGHT], EYE_EDGE),
                          (v[actor.EYE_LEFT], EYE_EDGE)):
            held = torch.maximum(held, 1.0 - train.smoothstep(0.0, edge * height, outside(p, pts)))
        body = (splats.bind > rig.T).float()
        return (1.0 - held) * (1.0 - body) + body


def hang_beard(splats, rig, data, i: int):
    """THE BEARD MOVES AS ONE (2026-10-25, the user: "transitions between frames, they morph in a fractured/spiky kind
    of way"): with the jaw eased open, a beard splat parted from its 12 nearest by 0.44 px a step against the 0.96 it
    moved - each on a triangle of its own that turned its own way (the jaw's edge, levers of up to 7 of its units), and
    each with expression shifts of its own that had learned noise (alone they moved it 0.27 px a step, and parted it
    from its neighbours by more). Hair has no shape to shift with the face. So, as it stands in the still (frame [param
    i]): a splat on the face's triangles BELOW THE CHIN is hung from the head's own frame, as the hair is (its place,
    size and turn in the head's terms, where it stood; the head's take no shifts), and one BELOW THE LIPS' OUTLINE
    (BEARD_UNDER of the face's height past it) keeps its triangle, which the jaw carries, but takes no shifts: 0.12 px a
    step. `(hung, under)`: how many of each."""
    import torch
    with torch.no_grad():
        T = rig.T
        origin, axes, unit, verts = rig.frames(data, i, tracked=False)
        means, _s, _t = splats.world(origin, axes, unit, data.expr[i])
        height = float((verts[parts.TOP] - verts[parts.CHIN]).norm())
        on_tri = splats.bind < T
        hung = on_tri & (means[:, 1] > float(verts[parts.CHIN, 1]))
        under = on_tri & ~hung & (means[:, 1] > float(verts[actor.LIPS_OUTER, 1].max()) + BEARD_UNDER * height)
        b = splats.bind[hung]
        oh, ah, uh = origin[T], axes[T], unit[T]
        p = splats.p
        p["place"].data[hung] = (means[hung] - oh) @ ah / uh
        p["log_scale"].data[hung] += torch.log(unit[b] / uh)[:, None]
        to_head = torch.einsum("ji,njk->nik", ah, axes[b])
        p["turn"].data[hung] = train.quat_mul(train.quat_of(to_head), torch.nn.functional.normalize(p["turn"].data[hung], dim=-1))
        splats.bind[hung] = T
        for name in ("place_d", "colour_d"):
            p[name].data[hung | under] = 0.0
        return int(hung.sum()), int(under.sum())


def coarse(x):
    """[param x] ([H, W, C]) as the means of its squares MOMENT_POOL pixels wide ([C, H / MOMENT_POOL,
    W / MOMENT_POOL]): what a moment is asked for."""
    import torch
    return torch.nn.functional.avg_pool2d(x.permute(2, 0, 1)[None], MOMENT_POOL)[0]


def moment_loss(splats, rig, data, scene, j: int, wx: int, wy: int, S: int, img, person, front):
    """HOW FAR MOMENT [param j] IS FROM ITS PICTURE, coarsely: its window at ([param wx], [param wy]), [param S]
    square, drawn as tracked in its own light, against [param img] and the person [param person] - their means over
    squares ([method coarse]), colour and cover, not where something stands before them ([param front], 1 where
    nothing does)."""
    image, cover = train.render(splats, rig, data, scene, j, wx, wy, S, S)[:2]
    m = front[wy:wy + S, wx:wx + S, None]
    return ((coarse(image * m) - coarse(img[wy:wy + S, wx:wx + S] * m)).abs().mean()
            + train.COVER_SHARE * coarse((cover - person[wy:wy + S, wx:wx + S])[..., None] * m).abs().mean())


def outside(p, pts):
    """How far each of [param p] ([N, 2]) stands outside the convex outline of [param pts] ([M, 2]): the most it stands
    past any edge's line, outward (0 or less inside)."""
    import torch
    hull = pts[torch.tensor(train._convex(pts.cpu().numpy().tolist()), device=pts.device)]
    a = hull
    e = torch.roll(hull, -1, 0) - a
    n = torch.nn.functional.normalize(torch.stack([e[:, 1], -e[:, 0]], -1), dim=-1)
    n = torch.where(((hull.mean(0) - a) * n).sum(-1, keepdim=True) > 0, -n, n)
    return ((p[:, None] - a[None]) * n[None]).sum(-1).max(1).values


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
    hung, under = hang_beard(splats, rig, data, i)

    def picture(path, mode):
        x0, y0, w, h = data.crop
        im = Image.open(path).convert(mode).crop((x0, y0, x0 + w, y0 + h))
        return torch.tensor(np.asarray(im, np.float32) / 255.0, device=dev)
    still = picture(spec["picture"], "RGB")
    matte = picture(spec["matte"], "L")

    # WHERE THE STILL IS FITTED: the body's splats not where the head is solid, the head's anywhere; their outline
    # not under what stands before them
    with torch.no_grad():
        head = head_cover(splats, rig, data, i) > HEAD_COVER
    keep = (~head).float()
    outline = keep * (1.0 - data.front)
    ys, xs = torch.nonzero(matte > 0.5, as_tuple=True)
    if ys.numel() == 0:
        say("nothing of them to fit in still %d" % k)
        return 2
    box = [float(xs.min()), float(ys.min()), float(xs.max()), float(ys.max())]

    def error(img, where=None):
        w = torch.ones_like(keep) if where is None else where
        se = (((img - still) ** 2) * w[..., None]).sum() / (w.sum() * 3 + 1e-6)
        return -10.0 * math.log10(max(float(se), 1e-10))

    with torch.no_grad():
        drawn = train.render(splats, rig, data, scene, i, 0, 0, data.W, data.H, tracked=False, learned=False)[0]
        before, before_body = error(drawn), error(drawn, keep)
        # and round the face on the moments it never fits (as tracked, in no light of their own)
        unseen = train.held_error(splats, rig, data, scene)["face"]
    steps = int(spec.get("steps", 3000))
    S = min(train.WINDOW, data.W, data.H)
    body = splats.bind > rig.T
    free = where_it_opens(splats, rig, data, i)
    say("still %d: %d of %d splats on the body, %d of the head's held where the face opens (%d past its reach dropped); "
        "the beard: %d hung from the head below the chin, %d under the lips without shifts; "
        "%.2f dB on the still, %.2f where the body is; %d steps" % (k, int(body.sum()), len(splats), int((free < 0.5).sum()),
                                                                  int(far.sum()), hung, under, before, before_body, steps))
    rng = np.random.default_rng(0)
    # THE MOMENTS, one a step, in their own light
    order = np.concatenate([rng.permutation(data.train) for _ in range(steps // max(1, data.train.size) + 1)])[:steps]
    data.read_ahead(order)
    light = torch.optim.Adam([{"params": [scene.correct], "lr": LIGHT_RATES[0]},
                              {"params": [scene.gain], "lr": LIGHT_RATES[1]}])
    front = 1.0 - data.front
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
        # the head's loss is the whole window's
        whole = ((1.0 - train.SSIM_SHARE) * (image - truth).abs().mean()
                 + train.SSIM_SHARE * (1.0 - train.ssim_map(image, truth)).mean())
        splats.opt.zero_grad(set_to_none=True)
        loss.backward(retain_graph=True)
        bodies = {n: splats.p[n].grad[body].clone() for n in train.Splats.NAMES if splats.p[n].grad is not None}
        splats.opt.zero_grad(set_to_none=True)
        whole.backward()
        # and a moment's, on the head (the body's is the still's alone)
        j = int(order[step - 1])
        img, person = data.get(j)
        mx, my = data.window(j, rng, True)
        light.zero_grad(set_to_none=True)
        held = moment_loss(splats, rig, data, scene, j, mx, my, S, img, person, front)
        (MOMENT_SHARE * held).backward()
        light.step()
        with torch.no_grad():
            for name in train.Splats.NAMES:
                g = splats.p[name].grad
                if g is None:
                    continue
                if name in ("place_d", "colour_d"):
                    g.zero_()
                    continue
                g.mul_(free.reshape((-1,) + (1,) * (g.dim() - 1)))
                g[body] = bodies[name] if name in bodies else 0.0
            if means2d.grad is not None:
                p = means2d - torch.tensor([float(wx), float(wy)], device=dev)
                r = radii.float()
                there = (free > 0.5) & (p[:, 0] + r > 0) & (p[:, 0] - r < S) & (p[:, 1] + r > 0) & (p[:, 1] - r < S)
                splats.pull[there] += means2d.grad[there].norm(dim=-1) * (S * 0.5)
                splats.seen[there] += 1.0
        splats.decay(step / steps)
        splats.opt.step()
        not_needles(splats, free > 0.0)
        if step % train.DENSIFY_EVERY == 0 and step <= FIT_GROWS * steps:
            splats.densify(unit, FIT_MOST, least=LEAST_COPY)
            body = splats.bind > rig.T
            free = where_it_opens(splats, rig, data, i)
        if step % 500 == 0:
            train.progress(a.progress, step / steps)
            say("step %d: L1 %.4f, the moments %.4f, %d splats (%d on the body), %.0f s"
                % (step, l1.item(), held.item(), len(splats), int(body.sum()), time.time() - t0))
    with torch.no_grad():
        drawn = train.render(splats, rig, data, scene, i, 0, 0, data.W, data.H, tracked=False, learned=False)[0]
        after, after_body = error(drawn), error(drawn, keep)
        unseen_after = train.held_error(splats, rig, data, scene)["face"]
    # THE BODY BENDS as it is played: each body splat's second influence, by where it rests in the still
    train.save(splats, rig, data, scene, spec["rig"], spec["out"], at=i, extra={"still": k},
               second=train.second_of(splats, rig, data, i))
    say("still %d fitted: %.2f dB on the still, from %.2f (%.2f where the body is, from %.2f); round the face on the "
        "moments it never fitted %.2f dB, from %.2f; %d splats; %.1f minutes"
        % (k, after, before, after_body, before_body, unseen_after, unseen, len(splats), (time.time() - t0) / 60.0))
    train.progress(a.progress, 1.0)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
