#!/usr/bin/env python3
"""train.py - an actor's head as 3D Gaussian splats bound to their own face, learned from one set's frames
(next/likeness.md, "A head of splats").

    <voice_train_venv python> train.py --spec <spec.json> [--progress <file>]

The spec: {"frames", "rig", "room", "front", "out", "steps", "size", "preview", "span"} - the folder frames.py wrote,
the rig rig.py wrote, the set's room plate and what stands before them (full frames: the crop is the
frames' own), where the avatar goes, how many steps, the side of the square it is learned at, a folder for
pictures of it against held-out frames, and the stretch of the video [t0, t1] it learns from (one camera
placement: a set's shots can stand a little apart - his first two are framed wider than the third).

EVERY SPLAT IS BOUND TO A FRAME OF ITS OWN that the face carries (GaussianAvatars' binding): a triangle of
the face - its centre, its edge and normal for axes, its mean edge for a unit - or the head itself (its pose
from the rig: hair, ears, the top of the head, which no triangle of the face reaches without a lever that
would swing it with the brows). A splat keeps its place, turn and size in its frame's terms, so the face
moved by a score moves every splat on it. The beard below the mouth is bound to the lower face's edge,
which the jaw carries.

WHAT IS BEHIND THE HEAD is what is behind it as it is played: the room above the mouth, and below it their own
body where the frame shows it (`Frames.body`: a pixel near the colour of their clothing a little further down)
- the head is drawn over their body, so the splats are not asked to paint the sweater round a beard, and the
beard, which is not the sweater's colour, is all they learn there (2026-10-22: the sweater painted by splats
bound to the jaw read as a dark smudge round the beard).

EACH STEP: one frame - the face as it was tracked in it (spec "face": "tracked", the default: MediaPipe's own
points, so the splats learn where the face truly was - the rig's scores explain 58% of his face's movement,
69% of the lips') or as the rig makes it from the frame's scores ("rig": learned as it will be played),
every splat placed, rendered over the room (brought to the frame's
light by a gain fitted round them) and compared with the frame inside a region round the head: L1 and SSIM,
and the drawn cover against the person MediaPipe sees there; what stands before them (the microphone) is no
part of the loss. A small colour correction per frame takes the day's changing light out of the head.

A SPLAT CHANGES WITH THE FACE'S EXPRESSION (GaussianBlendshapes, SIGGRAPH 2024): beside its place and colour,
EXPRESSIONS shifts of each, mixed by the frame's expression - its 52 scores' first EXPRESSIONS principal
components over the frames learned from, each scaled to its spread (`Frames.expr`). What one place and one
colour averaged away is learned where it changes: the teeth as the mouth opens, the creases as they squint,
the lips' own shapes. The shifts are pulled toward none (DELTA_PULL), so a splat changes only where that
pays.

THE SPLATS GROW WHERE THEY ARE WANTED (3DGS's densification): every DENSIFY_EVERY steps until DENSIFY_UNTIL,
a splat whose place on the picture is pulled hard is copied when it is small and split when it is large;
one nearly clear is dropped; every OPACITY_RESET steps all are made faint again, so what is not needed fades.

Writes <out> (avatar.npz: per splat its binding, place, scale, turn, colour and cover; the rig's
neutral face, basis and triangles), beside it what Godot reads (`export`: <out>.json and <out>.bin) and,
every so often, <preview>/<step>.jpg.
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

# Splats laid on each triangle at the start, and laid round the face (hair, ears, beard).
PER_TRIANGLE = 6
AROUND = 24000
# Densification (3DGS's figures; its pull is on the picture's -1..1 coordinates, so a pixel's is scaled).
DENSIFY_FROM = 500
DENSIFY_UNTIL = 15000
DENSIFY_EVERY = 100
GRAD_PULL = 0.0002
OPACITY_RESET = 3000
PRUNE_BELOW = 0.005
MOST = 400000
# The expression's principal components a splat's place and colour shift by, and the pull toward no shift.
EXPRESSIONS = 12
DELTA_PULL = 1e-3
# A splat's size where it is copied rather than split, as a share of the square: 3DGS's 1% is of a whole
# scene's extent, and a head that fills the square needs a finer cut - at 1% (7 px at 704) every splat up to
# that was copied whole, and the median one stood 4 px wide (a fog of big faint splats, soft).
SPLIT_SHARE = 0.002
# ONCE THE SPLATS STOP GROWING each is pushed to be there or not (its cover's binary entropy, this much) and
# those nearly clear are dropped every PRUNE_EVERY steps: stacked faint splats are a fog, and a fog is soft.
DECIDE = 0.01
PRUNE_EVERY = 1000
# The loss: L1 and D-SSIM, and the cover against the person.
SSIM_SHARE = 0.2
COVER_SHARE = 0.1
# How far a triangle's splat may stray from it, and how large it may grow, in the triangle's own units,
# before it is pulled back (GaussianAvatars' regularisers).
STRAY = 1.0
LARGE = 0.6
REG_SHARE = 0.01
# The body's points that are a hand (MediaPipe's pose: wrists, pinkies, index fingers, thumbs).
HAND_POINTS = (15, 16, 17, 18, 19, 20, 21, 22)
# Every n-th frame is held out: never learned from, the pictures are of it; this many are measured on.
HELD_OUT = 25
MEASURED = 48
# The head's own unit, in the neutral face's pixels: a splat bound to the head moves in steps of the same
# size as one on a triangle (whose unit is its mean edge, about this).
HEAD_UNIT = 16.0
# Frames read ahead of the step that wants them, on a thread of their own.
AHEAD = 24
# THEIR BODY BEHIND THE HEAD: a pixel below the mouth this near their clothing's colour (0..1, the largest
# channel's difference, on a picture blurred by BODY_BLUR pixels) is their body; the clothing's colour is the
# median of the person in a band BODY_BAND of the face's height deep, below the beard.
BODY_NEAR = 0.09
BODY_BLUR = 3
BODY_BAND = 0.35


def say(*parts) -> None:
    print("actor: avatar:", *parts, flush=True)


def progress(path: str, frac: float) -> None:
    if path:
        with open(path + ".part", "w") as fh:
            fh.write("%.4f" % frac)
        os.replace(path + ".part", path)


# --- the data --------------------------------------------------------------------------------------

class Frames:
    """One set's frames at the learning size, on the GPU as they are asked for (a few hundred stay)."""

    def __init__(self, spec: dict, size: int, device):
        import numpy as np
        import torch
        from PIL import Image
        self.dir = spec["frames"]
        f = np.load(os.path.join(self.dir, "frames.npz"))
        r = np.load(spec["rig"])
        self.crop = json.load(open(os.path.join(self.dir, "spec.json")))["crop"]
        x0, y0, side = (int(v) for v in self.crop)
        self.side = side
        keep = r["keep"].astype(bool)
        t0, t1 = spec.get("span", [0.0, 1e9])
        keep &= (f["t"] >= t0) & (f["t"] <= t1)
        self.points = f["points"]
        self.k = size / side
        self.size = size
        # A HAND ANYWHERE ROUND THE HEAD teaches the head nothing (the person MediaPipe sees takes it in)
        pose = f["pose"].reshape(-1, 33, 4)
        for i in np.nonzero(keep)[0]:
            hand = pose[i, list(HAND_POINTS)]
            seen = hand[:, 3] > 0.5
            if seen.any() and (self._reach(int(i), hand[seen, 0] * size, hand[seen, 1] * size) < 1.08).any():
                keep[i] = False
        for i in range(keep.size):
            if keep[i] and not os.path.exists(os.path.join(self.dir, "mask", "%05d.png" % i)):
                keep[i] = False
        self.idx = np.nonzero(keep)[0]
        self.held = self.idx[::HELD_OUT]
        self.train = np.setdiff1d(self.idx, self.held)
        self.blend = torch.tensor(r["blend"], device=device)
        self.scale = torch.tensor(r["scale"], device=device)
        self.rot = torch.tensor(r["rot"], device=device)
        self.shift = torch.tensor(r["shift"], device=device)
        self.aligned = torch.tensor(r["aligned"], device=device)
        self.device = device
        self.measured = self.held[:: max(1, self.held.size // MEASURED)][:MEASURED]
        # THE EXPRESSION: the scores' first EXPRESSIONS principal components over the frames learned from,
        # each to its spread - what a splat's shifts are mixed by
        b = r["blend"].astype(np.float64)
        self.expr_mean = b[self.train].mean(0)
        _u, sv, vt = np.linalg.svd(b[self.train] - self.expr_mean, full_matrices=False)
        self.expr_basis = vt[:EXPRESSIONS].T
        self.expr_scale = sv[:EXPRESSIONS] / math.sqrt(max(1, self.train.size - 1))
        e = (b - self.expr_mean) @ self.expr_basis / np.maximum(self.expr_scale, 1e-6)
        self.expr = torch.tensor(e, device=device, dtype=torch.float32)
        self.K = EXPRESSIONS

        def crop_of(path, mode):
            im = Image.open(path).convert(mode).crop((x0, y0, x0 + side, y0 + side)).resize((size, size), Image.BILINEAR)
            return torch.tensor(np.asarray(im, np.float32) / 255.0, device=device)
        self.room = crop_of(spec["room"], "RGB")
        front = Image.open(spec["front"])
        self.front = crop_of(spec["front"], "RGBA")[..., 3] if front.mode == "RGBA" else crop_of(spec["front"], "L")
        self._front_np = self.front.cpu().numpy()
        self._ready = {}
        self._queue = None

    def read_ahead(self, order) -> None:
        """Read the frames of [order] (indices, in the order they will be asked for) on a thread, AHEAD at most."""
        import queue
        import threading
        q = queue.Queue(maxsize=AHEAD)
        self._queue = q

        def work():
            for i in order:
                q.put((int(i), self._load(int(i))))
        threading.Thread(target=work, daemon=True).start()

    def _load(self, i: int):
        """Frame i off the disk, on the processor: its picture, the person and the loss's region (numpy)."""
        import numpy as np
        from PIL import Image
        s = self.size
        img = Image.open(os.path.join(self.dir, "img", "%05d.jpg" % i)).resize((s, s), Image.BILINEAR)
        m = Image.open(os.path.join(self.dir, "mask", "%05d.png" % i)).resize((s, s), Image.BILINEAR)
        return (np.asarray(img, np.uint8), np.asarray(m, np.uint8), self.region(i), self.body(i, img, np.asarray(m)))

    def body(self, i: int, img, person):
        """Where frame i shows their body below the mouth (0..1): near their clothing's colour, measured below
        the beard - what the head is drawn over as it is played."""
        import numpy as np
        from PIL import ImageFilter
        s = self.size
        p = self.points[i][:468, :2] * self.k
        y0, y1 = p[:, 1].min(), p[:, 1].max()
        h = y1 - y0
        mouth_y = p[[61, 291], 1].mean()
        band0 = int(min(s - 4, y1 + 0.55 * h))
        band1 = int(min(s, band0 + max(4.0, BODY_BAND * h)))
        soft = np.asarray(img.filter(ImageFilter.BoxBlur(BODY_BLUR)), np.float32) / 255.0
        there = person[band0:band1] > 128
        if int(there.sum()) < 200:
            return np.zeros((s, s), np.float32)
        colour = np.median(soft[band0:band1][there], axis=0)
        near = np.abs(soft - colour).max(-1) < BODY_NEAR
        rows = (np.arange(s, dtype=np.float32) + 0.5)[:, None] > mouth_y
        return (near & (person > 128) & rows).astype(np.float32)

    def get(self, i: int, ahead=True):
        """Frame i: its picture [S,S,3], the person [S,S], the region the loss is taken in [S,S] and what is
        behind the head [S,S,3] - from the thread's reading when [param ahead] (the learning order), else off
        the disk."""
        import torch
        got = None
        if ahead and self._queue is not None:
            j, got = self._queue.get()
            if j != i:
                got = None
        if got is None:
            got = self._load(i)
        img_np, mask_np, region_np, body_np = got
        img = torch.tensor(img_np, device=self.device).float() / 255.0
        person = torch.tensor(mask_np, device=self.device).float() / 255.0
        region = torch.tensor(region_np, device=self.device)
        body = torch.tensor(body_np, device=self.device)
        # the room in the frame's light: per channel, the frame's wall against the plate's, round the head
        wall = (person < 0.05) & (region > 0.5) & (self.front < 0.5)
        if int(wall.sum()) > 200:
            gain = (img[wall].median(0).values / self.room[wall].median(0).values.clamp_min(1e-3)).clamp(0.5, 2.0)
        else:
            gain = torch.ones(3, device=self.device)
        room = (self.room * gain).clamp(0.0, 1.0)
        # behind the head: the room, or their body where the frame shows it; the person the splats cover,
        # less their body
        behind = room * (1.0 - body[..., None]) + img * body[..., None]
        return img, person * (1.0 - body), region, behind

    def held_frame(self, i: int):
        """A held-out frame, read off the disk (the thread reads the learning order only)."""
        return self.get(i, ahead=False)

    def _reach(self, i: int, xx, yy):
        """How far out of the region (x, y) is in frame i: under 1 inside it (the two ellipses' nearer measure)."""
        import numpy as np
        p = self.points[i][:468, :2] * self.k
        x0, y0 = p.min(0)
        x1, y1 = p.max(0)
        cx, w, h = (x0 + x1) * 0.5, x1 - x0, y1 - y0
        mouth = p[[61, 291]].mean(0)
        top, bottom = y0 - 0.45 * h, y1 + 0.55 * h
        cy, ry, rx = (top + y1) * 0.5, (y1 - top) * 0.5, 0.95 * w
        head = np.sqrt(((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2)
        head = np.where(yy < mouth[1], head, 9.0)
        beard = np.sqrt(((xx - mouth[0]) / (0.55 * w)) ** 2 + ((yy - mouth[1]) / max(bottom - mouth[1], 1.0)) ** 2)
        return np.minimum(head, beard)

    def region(self, i: int, front=True):
        """Where the loss is taken in frame i, feathered: above the mouth an ellipse round the face grown up for
        the hair and out for the ears; below it, one the beard's width from the mouth to where the beard
        ends (wider would take in the sweater at the shoulders, which their body, not the head, is drawn
        with); less what stands before them."""
        import numpy as np
        s = self.size
        yy, xx = np.mgrid[0:s, 0:s].astype(np.float32) + 0.5
        r = np.clip((1.08 - self._reach(i, xx, yy)) / 0.08, 0.0, 1.0)
        if front:
            r = r * (1.0 - self._front_np)
        return r.astype(np.float32)


# --- the face, posed -------------------------------------------------------------------------------

class Rig:
    """The rig's neutral face and basis on the GPU: the face of a frame's scores, posed into the square."""

    def __init__(self, path: str, device):
        import numpy as np
        import torch
        r = np.load(path)
        self.canon = torch.tensor(r["canon"], device=device)
        self.basis = torch.tensor(r["basis"], device=device)
        self.tris = torch.tensor(r["tris"], device=device, dtype=torch.long)
        self.derived = torch.tensor(r["derived"], device=device)
        self.derived_shift = torch.tensor(r["derived_shift"], device=device)
        self.tracked = True

    def face(self, blend, scale, rot, shift, k: float, tracked=None):
        """The face's points in the square's pixels: the neutral face moved by the scores - or the frame's own
        tracked points, on the neutral face's frame - then the head's pose. The points the mesh adds to
        MediaPipe's are made from its points either way."""
        import torch
        if tracked is None:
            v = self.canon + torch.einsum("k,kvc->vc", blend, self.basis)
        else:
            v = torch.cat([tracked, self.derived @ tracked + self.derived_shift])
        return (scale * v @ rot.T + shift) * k

    def frames(self, verts, head_scale, head_rot, head_origin):
        """Every binding frame: (origin [F,3], axes [F,3,3] as columns, unit [F]) - the triangles', then the head's."""
        import torch
        a, b, c = verts[self.tris[:, 0]], verts[self.tris[:, 1]], verts[self.tris[:, 2]]
        origin = (a + b + c) / 3.0
        e1 = torch.nn.functional.normalize(b - a, dim=-1)
        n = torch.nn.functional.normalize(torch.cross(b - a, c - a, dim=-1), dim=-1)
        e2 = torch.cross(n, e1, dim=-1)
        axes = torch.stack([e1, e2, n], dim=-1)
        unit = ((b - a).norm(dim=-1) + (c - b).norm(dim=-1) + (a - c).norm(dim=-1)) / 3.0
        origin = torch.cat([origin, head_origin[None]])
        axes = torch.cat([axes, head_rot[None]])
        unit = torch.cat([unit, head_scale.reshape(1)])
        return origin, axes, unit


def quat_mul(a, b):
    import torch
    aw, ax, ay, az = a.unbind(-1)
    bw, bx, by, bz = b.unbind(-1)
    return torch.stack([aw * bw - ax * bx - ay * by - az * bz, aw * bx + ax * bw + ay * bz - az * by,
                        aw * by - ax * bz + ay * bw + az * bx, aw * bz + ax * by - ay * bx + az * bw], -1)


def quat_of(m):
    """Quaternions (w, x, y, z) of rotation matrices [..., 3, 3]."""
    import torch
    w = torch.sqrt((1.0 + m[..., 0, 0] + m[..., 1, 1] + m[..., 2, 2]).clamp_min(1e-8)) * 0.5
    x = (m[..., 2, 1] - m[..., 1, 2]) / (4.0 * w)
    y = (m[..., 0, 2] - m[..., 2, 0]) / (4.0 * w)
    z = (m[..., 1, 0] - m[..., 0, 1]) / (4.0 * w)
    return torch.stack([w, x, y, z], -1)


# --- the splats ------------------------------------------------------------------------------------

class Splats:
    """The learned parameters: per splat its binding (a frame's index), its place in the frame's units, its
    log-scale, its turn in the frame, its colour (logit) and its cover (logit) - and the shifts of its place
    and colour for each of the expression's components (`place_d`, `colour_d` [N, K, 3])."""

    NAMES = ("place", "log_scale", "turn", "colour", "cover", "place_d", "colour_d")
    RATES = {"place": 1.6e-3, "log_scale": 5e-3, "turn": 1e-3, "colour": 2.5e-3, "cover": 5e-2,
             "place_d": 1e-3, "colour_d": 1.5e-3}

    def __init__(self, bind, place, log_scale, turn, colour, cover, place_d=None, colour_d=None, k=EXPRESSIONS):
        import torch
        self.bind = bind
        n = bind.shape[0]
        if place_d is None:
            place_d = torch.zeros((n, k, 3), device=bind.device)
        if colour_d is None:
            colour_d = torch.zeros((n, k, 3), device=bind.device)
        self.p = {}
        for name, v in zip(self.NAMES, (place, log_scale, turn, colour, cover, place_d, colour_d)):
            self.p[name] = torch.nn.Parameter(v.contiguous())
        self.opt = torch.optim.Adam([{"params": [self.p[n]], "lr": self.RATES[n], "name": n} for n in self.NAMES],
                                    eps=1e-15)
        self.pull = torch.zeros(bind.shape[0], device=bind.device)
        self.seen = torch.zeros(bind.shape[0], device=bind.device)

    def __len__(self):
        return int(self.bind.shape[0])

    def world(self, origin, axes, unit, expr=None):
        """Every splat in the square at expression [param expr]: (means3d, scales, rotations)."""
        import torch
        o, ax, u = origin[self.bind], axes[self.bind], unit[self.bind]
        place = self.p["place"]
        if expr is not None and self.p["place_d"].shape[1] == expr.shape[0]:
            place = place + torch.einsum("k,nkc->nc", expr, self.p["place_d"])
        means = o + u[:, None] * torch.einsum("nij,nj->ni", ax, place)
        scales = u[:, None] * torch.exp(self.p["log_scale"])
        turns = quat_mul(quat_of(ax), torch.nn.functional.normalize(self.p["turn"], dim=-1))
        return means, scales, turns

    def colours(self, expr=None):
        import torch
        c = self.p["colour"]
        if expr is not None and self.p["colour_d"].shape[1] == expr.shape[0]:
            c = c + torch.einsum("k,nkc->nc", expr, self.p["colour_d"])
        return torch.sigmoid(c)

    def covers(self):
        import torch
        return torch.sigmoid(self.p["cover"])

    # densification: the optimizer's state is kept for those kept, and starts at zero for those made
    def _replace(self, keep, extra: dict):
        import torch
        for group in self.opt.param_groups:
            name = group["name"]
            old = group["params"][0]
            st = self.opt.state.pop(old, None)
            new = torch.cat([old.data[keep], extra[name]]) if extra else old.data[keep]
            par = torch.nn.Parameter(new.contiguous())
            if st is not None:
                n_new = new.shape[0] - int(keep.sum())
                for key in ("exp_avg", "exp_avg_sq"):
                    z = torch.zeros((n_new,) + st[key].shape[1:], device=new.device)
                    st[key] = torch.cat([st[key][keep], z])
                self.opt.state[par] = st
            group["params"][0] = par
            self.p[name] = par
        self.bind = torch.cat([self.bind[keep], extra["bind"]]) if extra else self.bind[keep]
        self.pull = torch.zeros(len(self), device=self.bind.device)
        self.seen = torch.zeros(len(self), device=self.bind.device)

    def densify(self, unit_of, side: int):
        """Copy the small splats pulled hard, split the large ones, drop the clear ones."""
        import torch
        pull = self.pull / self.seen.clamp_min(1.0)
        size = (unit_of[self.bind][:, None] * torch.exp(self.p["log_scale"])).max(-1).values
        hard = pull > GRAD_PULL
        small = size <= SPLIT_SHARE * side
        copy = hard & small
        split = hard & ~small
        room = MOST - len(self)
        if room <= 0:
            copy[:] = False
            split[:] = False
        extra = {"bind": torch.cat([self.bind[copy], self.bind[split], self.bind[split]])}
        for name in self.NAMES:
            v = self.p[name].data
            if name == "place":
                # a split's two halves stand a scale's width either side along the splat's own axes
                sd = torch.exp(self.p["log_scale"].data[split])
                jitter = torch.randn_like(sd) * sd
                rot = _rot_of(torch.nn.functional.normalize(self.p["turn"].data[split], dim=-1))
                off = torch.einsum("nij,nj->ni", rot, jitter)
                extra[name] = torch.cat([v[copy], v[split] + off, v[split] - off])
            elif name == "log_scale":
                extra[name] = torch.cat([v[copy], v[split] - math.log(1.6), v[split] - math.log(1.6)])
            else:
                extra[name] = torch.cat([v[copy], v[split], v[split]])
        keep = ~split & (self.covers().detach() > PRUNE_BELOW)
        self._replace(keep, extra)
        return int(copy.sum()), int(split.sum()), int((~keep).sum() - split.sum())

    def prune(self) -> int:
        """Drop the splats nearly clear; how many went."""
        keep = self.covers().detach() > PRUNE_BELOW
        gone = int((~keep).sum())
        if gone:
            self._replace(keep, {})
        return gone

    def reset_cover(self):
        import torch
        with torch.no_grad():
            self.p["cover"].data.clamp_(max=_logit(0.01))
        for group in self.opt.param_groups:
            if group["name"] == "cover":
                st = self.opt.state.get(group["params"][0])
                if st:
                    st["exp_avg"].zero_()
                    st["exp_avg_sq"].zero_()


def load(npz: str, device) -> Splats:
    """A saved avatar's splats, to render with (their optimizer is fresh)."""
    import numpy as np
    import torch
    a = np.load(npz)

    def t(x):
        return torch.tensor(x, device=device)
    if "colour_logit" in a.files:
        logit = a["colour_logit"]
    else:
        col = np.clip(a["colour"], 1e-4, 1 - 1e-4)
        logit = np.log(col / (1 - col))
    cov = np.clip(a["cover"], 1e-6, 1 - 1e-6)
    n = a["bind"].shape[0]
    shifts = {k: t(a[k]) for k in ("place_d", "colour_d") if k in a.files}
    k = int(shifts["place_d"].shape[1]) if shifts else 0
    return Splats(t(a["bind"]).long(), t(a["place"]), t(a["log_scale"]), t(a["turn"]), t(logit),
                  t(np.log(cov / (1 - cov))), shifts.get("place_d"), shifts.get("colour_d"), k=k)


def _logit(x: float) -> float:
    return math.log(x / (1.0 - x))


def _rot_of(q):
    import torch
    w, x, y, z = q.unbind(-1)
    return torch.stack([1 - 2 * (y * y + z * z), 2 * (x * y - w * z), 2 * (x * z + w * y),
                        2 * (x * y + w * z), 1 - 2 * (x * x + z * z), 2 * (y * z - w * x),
                        2 * (x * z - w * y), 2 * (y * z + w * x), 1 - 2 * (x * x + y * y)], -1).reshape(q.shape[:-1] + (3, 3))


def initial(rig: Rig, data: Frames, device):
    """The first splats: PER_TRIANGLE on each triangle of the face at random places on it, and AROUND round it
    where the first frame sees the person - the beard's (below the mouth) bound to the lower face's edge, the
    rest to the head - at the depth of the face's rim; coloured from that frame."""
    import numpy as np
    import torch
    g = torch.Generator(device="cpu").manual_seed(0)
    i0 = int(data.train[0])
    img, person, region, _room = data.get(i0)
    verts = rig.face(data.blend[i0], data.scale[i0], data.rot[i0], data.shift[i0], data.k,
                     data.aligned[i0] if rig.tracked else None)
    origin, axes, unit = rig.frames(verts, data.scale[i0] * data.k * HEAD_UNIT, data.rot[i0], data.shift[i0] * data.k)
    T = rig.tris.shape[0]
    # on the face: barycentric places, in each triangle's frame
    bary = torch.rand((T, PER_TRIANGLE, 3), generator=g).to(device)
    bary = bary / bary.sum(-1, keepdim=True)
    tri_pts = verts[rig.tris]                                          # [T,3,3]
    pts = torch.einsum("tkj,tjc->tkc", bary, tri_pts).reshape(-1, 3)
    bind_face = torch.arange(T, device=device).repeat_interleave(PER_TRIANGLE)
    place_face = torch.einsum("nji,nj->ni", axes[bind_face], (pts - origin[bind_face])) / unit[bind_face, None]
    # round it: where the person is, inside the region, outside the face's own outline
    s = data.size
    from PIL import Image, ImageDraw
    hull = Image.new("L", (s, s), 0)
    face2d = verts[:468, :2].detach().cpu().numpy()
    order = _convex(face2d)
    ImageDraw.Draw(hull).polygon([tuple(map(float, face2d[j])) for j in order], fill=255)
    inside = torch.tensor(np.asarray(hull, np.float32) / 255.0, device=device)
    want = (person > 0.5) & (region > 0.5) & (inside < 0.5)
    ys, xs = torch.nonzero(want, as_tuple=True)
    pick = torch.randint(0, ys.numel(), (AROUND,), generator=g).to(device)
    xy = torch.stack([xs[pick].float() + 0.5, ys[pick].float() + 0.5], -1)
    rim = verts[[10, 152, 234, 454, 127, 356, 172, 397]]
    z = torch.full((AROUND, 1), float(rim[:, 2].mean()), device=device)
    pts2 = torch.cat([xy, z], -1)
    # the beard: below the mouth's corners, bound to the nearest triangle on the lower half of the face's edge
    mouth_y = float(verts[[61, 291], 1].mean())
    beard = pts2[:, 1] > mouth_y
    lower = torch.tensor(sorted({t for t in range(T) if float(origin[t, 1]) > mouth_y}), device=device)
    bind_around = torch.full((AROUND,), T, device=device, dtype=torch.long)
    if lower.numel() and bool(beard.any()):
        d = torch.cdist(pts2[beard, :2], origin[lower, :2])
        bind_around[beard] = lower[d.argmin(1)]
    place_around = torch.einsum("nji,nj->ni", axes[bind_around], (pts2 - origin[bind_around])) / unit[bind_around, None]
    bind = torch.cat([bind_face, bind_around])
    place = torch.cat([place_face, place_around])
    world = torch.cat([pts, pts2])
    # colour from the frame, size from the spacing
    px = world[:, :2].long().clamp(0, s - 1)
    col = img[px[:, 1], px[:, 0]].clamp(0.02, 0.98)
    spacing = torch.full((bind.shape[0],), 2.0, device=device)
    log_scale = torch.log((spacing / unit[bind])[:, None].repeat(1, 3))
    log_scale[:, 2] -= 1.0                                               # flat against their surface
    turn = torch.zeros((bind.shape[0], 4), device=device)
    turn[:, 0] = 1.0
    colour = torch.log(col / (1.0 - col))
    cover = torch.full((bind.shape[0],), _logit(0.3), device=device)
    return Splats(bind, place, log_scale, turn, colour, cover, k=data.K)


def _convex(p):
    """The convex hull of points [n, 2], as indices in order."""
    pts = sorted(range(len(p)), key=lambda i: (p[i][0], p[i][1]))

    def cross(o, a, b):
        return (p[a][0] - p[o][0]) * (p[b][1] - p[o][1]) - (p[a][1] - p[o][1]) * (p[b][0] - p[o][0])
    lower, upper = [], []
    for i in pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], i) <= 0:
            lower.pop()
        lower.append(i)
    for i in reversed(pts):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], i) <= 0:
            upper.pop()
        upper.append(i)
    return lower[:-1] + upper[:-1]


# --- the loss --------------------------------------------------------------------------------------

def ssim_map(a, b):
    """SSIM per pixel of images [S,S,3] (an 11-tap Gaussian window, as 3DGS's)."""
    import torch
    x = a.permute(2, 0, 1)[None]
    y = b.permute(2, 0, 1)[None]
    k = torch.exp(-((torch.arange(11, device=a.device) - 5.0) ** 2) / (2 * 1.5 ** 2))
    k = (k / k.sum())
    w = (k[:, None] * k[None, :])[None, None].repeat(3, 1, 1, 1)

    def blur(z):
        return torch.nn.functional.conv2d(z, w, padding=5, groups=3)
    mx, my = blur(x), blur(y)
    sxx, syy, sxy = blur(x * x) - mx * mx, blur(y * y) - my * my, blur(x * y) - mx * my
    c1, c2 = 0.01 ** 2, 0.03 ** 2
    s = ((2 * mx * my + c1) * (2 * sxy + c2)) / ((mx * mx + my * my + c1) * (sxx + syy + c2))
    return s[0].permute(1, 2, 0)


def render(splats: Splats, rig: Rig, data: Frames, i: int, correct=None, frame=None, tracked=None):
    """Frame i's head over its room: (image [S,S,3], cover [S,S], means2d - kept for the pull)."""
    import torch
    import raster
    verts = rig.face(data.blend[i], data.scale[i], data.rot[i], data.shift[i], data.k,
                     data.aligned[i] if (rig.tracked if tracked is None else tracked) else None)
    origin, axes, unit = rig.frames(verts, data.scale[i] * data.k * HEAD_UNIT, data.rot[i], data.shift[i] * data.k)
    expr = data.expr[i]
    means, scales, turns = splats.world(origin, axes, unit, expr)
    means2d, conics, depth, radii = raster.project(means, scales, turns)
    if means2d.requires_grad:
        means2d.retain_grad()
    colours = splats.colours(expr)
    if correct is not None:
        colours = (colours @ correct[:3] + correct[3]).clamp(0.0, 1.0)
    room = data.get(i)[3] if frame is None else frame[3]
    image, cover = raster.rasterize(means2d, conics, colours, splats.covers(), depth, radii,
                                    data.size, data.size, room)
    return image, cover, means2d, radii, unit


def preview(splats, rig, data, step: int, out_dir: str):
    """Held-out frames: theirs on top, then the splats on the face as tracked, then on the face the rig makes
    from the frame's scores alone (as it is played)."""
    import numpy as np
    import torch
    from PIL import Image
    rows = []
    with torch.no_grad():
        for i in data.measured[:: max(1, len(data.measured) // 6)][:6]:
            fr = data.held_frame(int(i))
            got = render(splats, rig, data, int(i), frame=fr, tracked=True)[0]
            played = render(splats, rig, data, int(i), frame=fr, tracked=False)[0]
            rows.append(torch.cat([fr[0], got, played], 0))
    pic = (torch.cat(rows, 1).clamp(0, 1).cpu().numpy() * 255.0 + 0.5).astype(np.uint8)
    os.makedirs(out_dir, exist_ok=True)
    Image.fromarray(pic).save(os.path.join(out_dir, "%06d.jpg" % step), quality=90)


def held_error(splats, rig, data):
    """The mean L1 inside the region on the held-out frames (0..1 per channel), and the PSNR there."""
    import torch
    errs, mses = [], []
    with torch.no_grad():
        for i in data.measured:
            fr = data.held_frame(int(i))
            img, _person, region, _room = fr
            got = render(splats, rig, data, int(i), frame=fr)[0]
            w = region[..., None]
            errs.append(float(((got - img).abs() * w).sum() / (w.sum() * 3)))
            mses.append(float((((got - img) ** 2) * w).sum() / (w.sum() * 3)))
    m = sum(mses) / len(mses)
    return sum(errs) / len(errs), -10.0 * math.log10(max(m, 1e-10))


# The width of the splats' data texture Godot reads, in texels.
TEXEL_WIDTH = 4096


def export(npz: str) -> None:
    """THE AVATAR AS GODOT READS IT (src/likeness/splat_head.gd): <npz minus .npz>.json, its header - the counts,
    the crop and the learning size, the head's unit, the expression's components, and each array's [byte
    offset, count, type] - and .bin, the arrays end to end, little-endian. The splats are written BACK TO FRONT
    as the neutral face stands straight on (their depth then), so a renderer that draws them in order
    composites them as learned.

    `texels` IS THE SHADER'S DATA TEXTURE, byte for byte (RGBA floats, TEXEL_WIDTH wide): per splat, in order,
    its place and binding, its log-scale and cover, its turn (w, x, y, z), its colour's logit, then for each of
    the expression's components its place's shift and its colour's shift - 4 + 2K texels."""
    import numpy as np
    a = np.load(npz)
    canon, tris = a["canon"].astype(np.float64), a["tris"]
    v = canon
    p0, p1, p2 = v[tris[:, 0]], v[tris[:, 1]], v[tris[:, 2]]
    origin = (p0 + p1 + p2) / 3.0
    e1 = p1 - p0
    e1 /= np.linalg.norm(e1, axis=1, keepdims=True)
    n = np.cross(p1 - p0, p2 - p0)
    n /= np.linalg.norm(n, axis=1, keepdims=True)
    e2 = np.cross(n, e1)
    unit = (np.linalg.norm(p1 - p0, axis=1) + np.linalg.norm(p2 - p1, axis=1) + np.linalg.norm(p0 - p2, axis=1)) / 3.0
    bind = a["bind"]
    T = tris.shape[0]
    on_face = bind < T
    depth = np.zeros(bind.shape[0])
    b = bind[on_face]
    loc = a["place"][on_face]
    depth[on_face] = origin[b, 2] + unit[b] * (e1[b, 2] * loc[:, 0] + e2[b, 2] * loc[:, 1] + n[b, 2] * loc[:, 2])
    depth[~on_face] = HEAD_UNIT * a["place"][~on_face][:, 2]
    order = np.argsort(-depth, kind="stable")
    N = bind.shape[0]
    k = int(a["place_d"].shape[1]) if "place_d" in a.files else 0
    per = 4 + 2 * k
    tex = np.zeros((N, per, 4), np.float32)
    tex[:, 0, :3] = a["place"][order]
    tex[:, 0, 3] = bind[order]
    tex[:, 1, :3] = a["log_scale"][order]
    tex[:, 1, 3] = a["cover"][order]
    tex[:, 2, :] = a["turn"][order]
    if "colour_logit" in a.files:
        logit = a["colour_logit"]
    else:
        col = np.clip(a["colour"], 1e-4, 1 - 1e-4)
        logit = np.log(col / (1 - col))
    tex[:, 3, :3] = logit[order]
    for j in range(k):
        tex[:, 4 + 2 * j, :3] = a["place_d"][order][:, j]
        tex[:, 5 + 2 * j, :3] = a["colour_d"][order][:, j]
    flat = tex.reshape(-1, 4)
    rows = -(-flat.shape[0] // TEXEL_WIDTH)
    texels = np.zeros((rows * TEXEL_WIDTH, 4), np.float32)
    texels[: flat.shape[0]] = flat
    arrays = {"texels": texels.astype("<f4"), "canon": a["canon"].astype("<f4"), "basis": a["basis"].astype("<f4"),
              "tris": a["tris"].astype("<i4")}
    if k:
        arrays.update({"expr_mean": a["expr_mean"].astype("<f4"), "expr_basis": a["expr_basis"].astype("<f4"),
                       "expr_scale": a["expr_scale"].astype("<f4")})
    base = npz[:-4] if npz.endswith(".npz") else npz
    head = {"version": 2, "splats": int(N), "tris": int(T), "verts": int(canon.shape[0]),
            "scores": int(a["basis"].shape[0]), "crop": [int(c) for c in a["crop"]], "size": int(a["size"]),
            "head_unit": HEAD_UNIT, "texel_width": TEXEL_WIDTH, "per_splat": per, "expressions": k, "arrays": {}}
    at = 0
    with open(base + ".bin.part", "wb") as fh:
        for name, arr in arrays.items():
            raw = np.ascontiguousarray(arr).tobytes()
            head["arrays"][name] = [at, int(arr.size), "i32" if arr.dtype.kind == "i" else "f32"]
            fh.write(raw)
            at += len(raw)
    with open(base + ".json.part", "w") as fh:
        json.dump(head, fh, indent=1)
    os.replace(base + ".bin.part", base + ".bin")
    os.replace(base + ".json.part", base + ".json")


def save(splats, rig_path: str, out: str, data: Frames):
    import numpy as np
    import torch
    r = np.load(rig_path)
    with torch.no_grad():
        np.savez(out + ".part.npz", bind=splats.bind.cpu().numpy().astype(np.int32),
                 place=splats.p["place"].cpu().numpy(), log_scale=splats.p["log_scale"].cpu().numpy(),
                 turn=torch.nn.functional.normalize(splats.p["turn"], dim=-1).cpu().numpy(),
                 colour=splats.colours().cpu().numpy(), colour_logit=splats.p["colour"].cpu().numpy(),
                 cover=splats.covers().cpu().numpy(),
                 place_d=splats.p["place_d"].cpu().numpy(), colour_d=splats.p["colour_d"].cpu().numpy(),
                 expr_mean=data.expr_mean.astype(np.float32), expr_basis=data.expr_basis.astype(np.float32),
                 expr_scale=data.expr_scale.astype(np.float32),
                 canon=r["canon"], basis=r["basis"], tris=r["tris"], crop=np.asarray(data.crop, np.int32),
                 size=np.int32(data.size))
    os.replace(out + ".part.npz", out)
    export(out)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--spec", required=True)
    ap.add_argument("--progress", default="")
    a = ap.parse_args()
    import numpy as np
    import torch
    spec = json.load(open(a.spec))
    if not torch.cuda.is_available():
        say("no graphics card PyTorch can use")
        return 2
    dev = torch.device("cuda")
    torch.manual_seed(0)
    data = Frames(spec, int(spec.get("size", 512)), dev)
    rig = Rig(spec["rig"], dev)
    rig.tracked = spec.get("face", "tracked") == "tracked"
    splats = initial(rig, data, dev)
    steps = int(spec.get("steps", 30000))
    # a colour correction per frame: [3x3 | 3], learned slowly, the identity to start
    n_frames = int(data.blend.shape[0])
    correct = torch.zeros((n_frames, 4, 3), device=dev)
    correct[:, :3] = torch.eye(3, device=dev)
    correct = torch.nn.Parameter(correct)
    copt = torch.optim.Adam([correct], lr=2e-4)
    say("%d frames to learn from, %d held out; %d splats to start; %d steps at %d px"
        % (len(data.train), len(data.held), len(splats), steps, data.size))
    rng = np.random.default_rng(0)
    order = np.concatenate([rng.permutation(data.train) for _ in range(steps // data.train.size + 1)])[:steps]
    data.read_ahead(order)
    t0 = time.time()
    for step in range(1, steps + 1):
        i = int(order[step - 1])
        fr = data.get(i)
        img, person, region, _room = fr
        image, cover, means2d, radii, unit = render(splats, rig, data, i, correct[i], fr)
        w = region[..., None]
        l1 = ((image - img).abs() * w).sum() / (w.sum() * 3 + 1e-6)
        dssim = ((1.0 - ssim_map(image, img)) * w).sum() / (w.sum() * 3 + 1e-6)
        cov = ((cover - person).abs() * region).sum() / (region.sum() + 1e-6)
        face = splats.bind < rig.tris.shape[0]
        place = splats.p["place"][face]
        reg = torch.relu(place.norm(dim=-1) - STRAY).mean() + torch.relu(torch.exp(splats.p["log_scale"][face]) - LARGE).mean()
        shifts = (splats.p["place_d"] ** 2).mean() + (splats.p["colour_d"] ** 2).mean()
        loss = (1.0 - SSIM_SHARE) * l1 + SSIM_SHARE * dssim + COVER_SHARE * cov + REG_SHARE * reg + DELTA_PULL * shifts
        if step >= DENSIFY_UNTIL:
            c = splats.covers().clamp(1e-6, 1.0 - 1e-6)
            loss = loss + DECIDE * (-(c * torch.log(c) + (1.0 - c) * torch.log(1.0 - c))).mean()
        splats.opt.zero_grad(set_to_none=True)
        copt.zero_grad(set_to_none=True)
        loss.backward()
        with torch.no_grad():
            if step < DENSIFY_UNTIL and means2d.grad is not None:
                seen = radii > 0
                splats.pull[seen] += means2d.grad[seen].norm(dim=-1) * (data.size * 0.5)
                splats.seen[seen] += 1.0
        splats.opt.step()
        copt.step()
        if DENSIFY_FROM <= step < DENSIFY_UNTIL and step % DENSIFY_EVERY == 0:
            made = splats.densify(unit, data.size)
            if step % 1000 == 0:
                say("step %d: %d splats (copied %d, split %d, dropped %d)" % ((step, len(splats)) + made))
        if step % OPACITY_RESET == 0 and step < DENSIFY_UNTIL:
            splats.reset_cover()
        if step > DENSIFY_UNTIL and step % PRUNE_EVERY == 0:
            gone = splats.prune()
            if step % 5000 == 0:
                say("step %d: %d splats (dropped %d nearly clear)" % (step, len(splats), gone))
        if step % 500 == 0:
            progress(a.progress, step / steps)
            say("step %d: loss %.4f (L1 %.4f, cover %.4f), %d splats, %.0f s" % (step, loss.item(), l1.item(),
                                                                               cov.item(), len(splats), time.time() - t0))
        if spec.get("preview") and (step % 2500 == 0 or step == steps):
            preview(splats, rig, data, step, spec["preview"])
            err, psnr = held_error(splats, rig, data)
            say("step %d: held out - L1 %.4f, PSNR %.2f dB in the region" % (step, err, psnr))
            save(splats, spec["rig"], spec["out"], data)
    save(splats, spec["rig"], spec["out"], data)
    err, psnr = held_error(splats, rig, data)
    say("%d splats; on %d frames it never saw: L1 %.4f, PSNR %.2f dB round the head; %.0f minutes"
        % (len(splats), len(data.held), err, psnr, (time.time() - t0) / 60.0))
    progress(a.progress, 1.0)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
