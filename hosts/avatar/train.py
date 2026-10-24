#!/usr/bin/env python3
"""train.py - an actor as 3D Gaussian splats bound to their own face and body, over their own room, learned
from one set's frames (next/likeness.md, "A head of splats", "The whole of them").

    <voice_train_venv python> train.py --spec <spec.json> [--progress <file>]

The spec: {"frames", "rig", "room", "front", "out", "steps", "preview", "span"} - the folder frames.py wrote
(whole frames), the rig rig.py wrote, the set's room plate and what stands before them (whole frames), where
the avatar goes, how many steps, a folder for pictures of it against held-out frames, and the stretch of the
video [t0, t1] it learns from (one camera placement: a set's shots can stand a little apart).

EVERY SPLAT IS BOUND TO A FRAME OF ITS OWN that they carry (GaussianAvatars' binding): a triangle of the face -
its centre, its edge and normal for axes, its mean edge for a unit; the head itself (hair, ears, the top of
the head, which no triangle reaches without a lever that would swing it with the brows); or one of the body's
bones (rig.py's `BODY`: the torso, the shoulders, each arm's upper arm, forearm and hand, from the pose). A
splat keeps its place, turn and size in its frame's terms, so whatever moves its frame moves it. The beard
below the mouth is bound to the lower face's edge, which the jaw carries. A bone not seen in a frame (a hand
under the desk: MediaPipe guesses where) has its splats drawn clear there - learned only where they are seen.

THE ROOM IS A PLATE, LEARNED: the camera never moves, so the room is one picture seen from one place - the
set's room plate to start, refined where the frames show it, with a gain per frame for the day's light. With
the room behind them learned, the splats at their edges are not asked to paint the difference between a
guessed room and the true one (the head alone, over a fixed plate, grew a halo against the wall).

EACH STEP: one frame and a WINDOW of it (WINDOW square; half of them round the face, where the most is), the
face as it was tracked in it (MediaPipe's own points) and the body as its pose stands, every splat placed,
rendered over the plate and compared with the frame: L1 and SSIM, and the drawn cover against the person
MediaPipe sees there; what stands before them (the microphone) is no part of the loss. A small colour
correction per frame takes the day's changing light out of them.

A SPLAT CHANGES WITH THE FACE'S EXPRESSION (GaussianBlendshapes, SIGGRAPH 2024): beside its place and colour,
EXPRESSIONS shifts of each, mixed by the frame's expression - its 52 scores' first EXPRESSIONS principal
components over the frames learned from, each scaled to its spread (`Frames.expr`) - pulled toward none
(DELTA_PULL). ONLY ON THE FACE, AND FADING WITH DISTANCE from its triangle (SHIFT_NEAR to SHIFT_FAR units): a
splat far from its triangle - the beard's tip, the hair's edge - swings on a lever with every shift, and they
flickered (2026-10-23: "the tip of the beard, along the sweater, around the head against the wall").

THE SPLATS GROW WHERE THEY ARE WANTED (3DGS's densification): every DENSIFY_EVERY steps until DENSIFY_UNTIL,
a splat whose place on the picture is pulled hard is copied when it is small and split when it is large; one
nearly clear is dropped; every OPACITY_RESET steps all are made faint again; after, those nearly clear are
dropped every PRUNE_EVERY steps. NO PUSH FOR A SPLAT TO BE THERE OR NOT (it cut the whole of him from 116k to
18k, the torso to 1,030 splats of 20 px, and the sweater went to a blur - the head alone was no sharper for it).
The pull's spread is said every 1000 steps (its median and 95th percentile), to set GRAD_PULL by.

Writes <out> (avatar.npz), beside it what Godot reads (`export`: <out>.json, <out>.bin and <out>.plate.png)
and, every so often, <preview>/<step>.jpg.
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

# Splats laid on each triangle at the start, round the face (hair, ears, beard), and on the body.
PER_TRIANGLE = 6
AROUND = 24000
ON_BODY = 48000
# The window a step is learned in, and the share of windows round the face.
WINDOW = 704
FACE_WINDOWS = 0.5
# Densification (3DGS's figures; its pull is on the picture's -1..1 coordinates, so a pixel's is scaled).
DENSIFY_FROM = 500
DENSIFY_UNTIL = 20000
DENSIFY_EVERY = 100
# A quarter of 3DGS's: learned in windows, the whole of them grew only 77k to 116k at its 0.0002.
GRAD_PULL = 0.00005
OPACITY_RESET = 3000
PRUNE_BELOW = 0.005
MOST = 600000
# The expression's principal components a splat's place and colour shift by, and the pull toward no shift;
# a splat's shifts fade from SHIFT_NEAR to SHIFT_FAR of its triangle's units away from it.
EXPRESSIONS = 12
DELTA_PULL = 1e-3
SHIFT_NEAR = 1.0
SHIFT_FAR = 2.0
# A splat's size where it is copied rather than split, as a share of the window: 3DGS's 1% is of a whole
# scene's extent, and a head that fills the square needs a finer cut (at 1% the median splat stood 4 px wide).
SPLIT_SHARE = 0.002
# Once the splats stop growing, those nearly clear are dropped this often.
PRUNE_EVERY = 1000
# The loss: L1 and D-SSIM, the cover against the person, and the plate held near the room it started as.
SSIM_SHARE = 0.2
COVER_SHARE = 0.1
PLATE_PULL = 0.01
# How far a triangle's splat may stray from it, and how large it may grow, in the triangle's own units,
# before it is pulled back (GaussianAvatars' regularisers).
STRAY = 1.0
LARGE = 0.6
REG_SHARE = 0.01
# A bone seen less surely than this in a frame has its splats drawn clear there.
SEEN = 0.3
# Every n-th frame is held out: never learned from, the pictures are of it; this many are measured on.
HELD_OUT = 25
MEASURED = 48
# The head's own unit, in the neutral face's pixels: a splat bound to the head moves in steps of the same
# size as one on a triangle (whose unit is its mean edge, about this).
HEAD_UNIT = 16.0
# A seated torso from the shoulders to the hips, in shoulder widths (actor.py's TORSO): its splats' reach.
TORSO = 1.35
# Frames read ahead of the step that wants them, on a thread of their own.
AHEAD = 16
# How far past their head's region (`head_region`) a splat bound to the head or the face may stand, in pixels.
HEAD_REACH = 16


def say(*parts) -> None:
    print("actor: avatar:", *parts, flush=True)


def progress(path: str, frac: float) -> None:
    if path:
        with open(path + ".part", "w") as fh:
            fh.write("%.4f" % frac)
        os.replace(path + ".part", path)


def smoothstep(e0: float, e1: float, x):
    import torch
    t = ((x - e0) / (e1 - e0)).clamp(0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


# --- the data --------------------------------------------------------------------------------------

class Frames:
    """One set's whole frames, read ahead on a thread; the face's and body's frames of reference per frame."""

    def __init__(self, spec: dict, device):
        import numpy as np
        import torch
        from PIL import Image
        self.dir = spec["frames"]
        f = np.load(os.path.join(self.dir, "frames.npz"))
        r = np.load(spec["rig"])
        c = [int(v) for v in json.load(open(os.path.join(self.dir, "spec.json")))["crop"]]
        self.crop = c if len(c) == 4 else [c[0], c[1], c[2], c[2]]
        x0, y0, self.W, self.H = self.crop
        keep = r["keep"].astype(bool) | (f["found"].astype(bool) & f["hands"].astype(bool))
        t0, t1 = spec.get("span", [0.0, 1e9])
        keep &= (f["t"] >= t0) & (f["t"] <= t1) & f["found"].astype(bool)
        for i in range(keep.size):
            if keep[i] and not os.path.exists(os.path.join(self.dir, "mask", "%05d.png" % i)):
                keep[i] = False
        self.points = f["points"]
        self.idx = np.nonzero(keep)[0]
        self.held = self.idx[::HELD_OUT]
        self.train = np.setdiff1d(self.idx, self.held)
        self.measured = self.held[:: max(1, self.held.size // MEASURED)][:MEASURED]
        t = lambda x: torch.tensor(x, device=device, dtype=torch.float32)
        self.blend, self.scale, self.rot, self.shift = t(r["blend"]), t(r["scale"]), t(r["rot"]), t(r["shift"])
        self.aligned = t(r["aligned"])
        self.bone_origin, self.bone_axes = t(r["bone_origin"]), t(r["bone_axes"])
        self.bone_unit, self.bone_seen = t(r["bone_unit"]), t(r["bone_seen"])
        self.B = int(r["bone_unit"].shape[1])
        self.device = device
        # THE EXPRESSION: the scores' first EXPRESSIONS principal components over the frames learned from,
        # each to its spread - what a splat's shifts are mixed by
        b = r["blend"].astype(np.float64)
        self.expr_mean = b[self.train].mean(0)
        _u, sv, vt = np.linalg.svd(b[self.train] - self.expr_mean, full_matrices=False)
        self.expr_basis = vt[:EXPRESSIONS].T
        self.expr_scale = sv[:EXPRESSIONS] / math.sqrt(max(1, self.train.size - 1))
        self.expr = t((b - self.expr_mean) @ self.expr_basis / np.maximum(self.expr_scale, 1e-6))
        self.K = EXPRESSIONS

        def crop_of(path, mode):
            im = Image.open(path).convert(mode).crop((x0, y0, x0 + self.W, y0 + self.H))
            return torch.tensor(np.asarray(im, np.float32) / 255.0, device=device)
        self.room = crop_of(spec["room"], "RGB")
        front = Image.open(spec["front"])
        self.front = crop_of(spec["front"], "RGBA")[..., 3] if front.mode == "RGBA" else crop_of(spec["front"], "L")
        self._queue = None

    def read_ahead(self, order) -> None:
        """Read the frames of [order] (in the order they will be asked for) on a thread, AHEAD at most."""
        import queue
        import threading
        q = queue.Queue(maxsize=AHEAD)
        self._queue = q

        def work():
            for i in order:
                q.put((int(i), self._load(int(i))))
        threading.Thread(target=work, daemon=True).start()

    def _load(self, i: int):
        import numpy as np
        from PIL import Image
        img = Image.open(os.path.join(self.dir, "img", "%05d.jpg" % i))
        m = Image.open(os.path.join(self.dir, "mask", "%05d.png" % i))
        return np.asarray(img, np.uint8), np.asarray(m, np.uint8)

    def get(self, i: int, ahead=True):
        """Frame i: its picture [H,W,3] and the person [H,W] - from the thread when [param ahead] (the learning
        order), else off the disk."""
        import torch
        got = None
        if ahead and self._queue is not None:
            j, got = self._queue.get()
            if j != i:
                got = None
        if got is None:
            got = self._load(i)
        img = torch.tensor(got[0], device=self.device).float() / 255.0
        person = torch.tensor(got[1], device=self.device).float() / 255.0
        return img, person

    def face_box(self, i: int):
        """The face's box in frame i: (x0, y0, x1, y1)."""
        p = self.points[i][:468, :2]
        return float(p[:, 0].min()), float(p[:, 1].min()), float(p[:, 0].max()), float(p[:, 1].max())

    def window(self, i: int, rng, face: bool):
        """A WINDOW's corner in frame i: round the face, or anywhere over the person (the face's box grown to
        take in the shoulders and arms the pose sees), inside the frame."""
        import numpy as np
        x0, y0, x1, y1 = self.face_box(i)
        if face:
            cx, cy = (x0 + x1) * 0.5 + rng.normal(0.0, 30.0), (y0 + y1) * 0.5 + rng.normal(0.0, 30.0)
        else:
            o = self.bone_origin[i].cpu().numpy()
            seen = self.bone_seen[i].cpu().numpy() > SEEN
            xs = np.concatenate([[x0, x1], o[seen, 0]])
            ys = np.concatenate([[y0, y1], o[seen, 1], [y1 + 2.5 * (y1 - y0)]])
            cx, cy = rng.uniform(xs.min(), xs.max()), rng.uniform(ys.min(), min(ys.max(), self.H))
        wx = int(np.clip(cx - WINDOW / 2, 0, self.W - WINDOW))
        wy = int(np.clip(cy - WINDOW / 2, 0, self.H - WINDOW))
        return wx, wy


# --- the face and body, posed ---------------------------------------------------------------------

class Rig:
    """The rig's neutral face and basis on the GPU, and the frames every splat is bound to."""

    def __init__(self, path: str, device):
        import numpy as np
        import torch
        r = np.load(path)
        t = lambda x: torch.tensor(x, device=device)
        self.canon, self.basis = t(r["canon"]), t(r["basis"])
        self.tris = t(r["tris"]).long()
        self.derived, self.derived_shift = t(r["derived"]), t(r["derived_shift"])
        self.T = int(self.tris.shape[0])

    def face(self, data: Frames, i: int, tracked=True):
        """The face's points in frame i's pixels: the frame's own tracked points (or the neutral face moved by its
        scores, as it is played), posed. The points the mesh adds to MediaPipe's are made from its points."""
        import torch
        if tracked:
            v = data.aligned[i]
            v = torch.cat([v, self.derived @ v + self.derived_shift])
        else:
            v = self.canon + torch.einsum("k,kvc->vc", data.blend[i], self.basis)
        return data.scale[i] * v @ data.rot[i].T + data.shift[i]

    def frames(self, data: Frames, i: int, tracked=True):
        """Every binding frame in frame i: (origin [F,3], axes [F,3,3] as columns, unit [F]) - the triangles',
        the head's, the bones'."""
        import torch
        verts = self.face(data, i, tracked)
        a, b, c = verts[self.tris[:, 0]], verts[self.tris[:, 1]], verts[self.tris[:, 2]]
        origin = (a + b + c) / 3.0
        e1 = torch.nn.functional.normalize(b - a, dim=-1)
        n = torch.nn.functional.normalize(torch.cross(b - a, c - a, dim=-1), dim=-1)
        e2 = torch.cross(n, e1, dim=-1)
        axes = torch.stack([e1, e2, n], dim=-1)
        unit = ((b - a).norm(dim=-1) + (c - b).norm(dim=-1) + (a - c).norm(dim=-1)) / 3.0
        origin = torch.cat([origin, data.shift[i][None], data.bone_origin[i]])
        axes = torch.cat([axes, data.rot[i][None], data.bone_axes[i]])
        unit = torch.cat([unit, (data.scale[i] * HEAD_UNIT).reshape(1), data.bone_unit[i]])
        return origin, axes, unit, verts


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

    def __init__(self, bind, place, log_scale, turn, colour, cover, triangles: int, place_d=None, colour_d=None,
                 k=EXPRESSIONS):
        import torch
        self.bind = bind
        self.T = triangles
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
        self.pull = torch.zeros(n, device=bind.device)
        self.seen = torch.zeros(n, device=bind.device)

    def __len__(self):
        return int(self.bind.shape[0])

    def shift_weight(self):
        """How much of its expression shifts a splat takes: on the face, fading with distance from its triangle;
        none on the head or a bone."""
        w = 1.0 - smoothstep(SHIFT_NEAR, SHIFT_FAR, self.p["place"].detach().norm(dim=-1))
        return w * (self.bind < self.T).float()

    def world(self, origin, axes, unit, expr=None):
        """Every splat at expression [param expr]: (means3d, scales, rotations)."""
        import torch
        o, ax, u = origin[self.bind], axes[self.bind], unit[self.bind]
        place = self.p["place"]
        if expr is not None and self.p["place_d"].shape[1] == expr.shape[0]:
            place = place + self.shift_weight()[:, None] * torch.einsum("k,nkc->nc", expr, self.p["place_d"])
        means = o + u[:, None] * torch.einsum("nij,nj->ni", ax, place)
        scales = u[:, None] * torch.exp(self.p["log_scale"])
        turns = quat_mul(quat_of(ax), torch.nn.functional.normalize(self.p["turn"], dim=-1))
        return means, scales, turns

    def colours(self, expr=None):
        import torch
        c = self.p["colour"]
        if expr is not None and self.p["colour_d"].shape[1] == expr.shape[0]:
            c = c + self.shift_weight()[:, None] * torch.einsum("k,nkc->nc", expr, self.p["colour_d"])
        return torch.sigmoid(c)

    def covers(self, seen=None):
        """Each splat's cover; with [param seen] (the bones' in a frame), a bone's splats clear where it is not seen."""
        import torch
        c = torch.sigmoid(self.p["cover"])
        if seen is not None:
            on_bone = self.bind > self.T
            b = (self.bind - self.T - 1).clamp(min=0)
            c = torch.where(on_bone & (seen[b] < SEEN), torch.zeros_like(c), c)
        return c

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

    def densify(self, unit_of, most=MOST):
        """Copy the small splats pulled hard, split the large ones, drop the clear ones; none made past [param most]."""
        import torch
        pull = self.pull / self.seen.clamp_min(1.0)
        size = (unit_of[self.bind][:, None] * torch.exp(self.p["log_scale"])).max(-1).values
        hard = pull > GRAD_PULL
        small = size <= SPLIT_SHARE * WINDOW
        copy = hard & small
        split = hard & ~small
        if most - len(self) <= 0:
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
    cov = np.clip(a["cover"], 1e-6, 1 - 1e-6)
    return Splats(t(a["bind"]).long(), t(a["place"]), t(a["log_scale"]), t(a["turn"]), t(a["colour_logit"]),
                  t(np.log(cov / (1 - cov))), int(a["tris"].shape[0]), t(a["place_d"]), t(a["colour_d"]),
                  k=int(a["place_d"].shape[1]))


def _logit(x: float) -> float:
    return math.log(x / (1.0 - x))


def _rot_of(q):
    import torch
    w, x, y, z = q.unbind(-1)
    return torch.stack([1 - 2 * (y * y + z * z), 2 * (x * y - w * z), 2 * (x * z + w * y),
                        2 * (x * y + w * z), 1 - 2 * (x * x + z * z), 2 * (y * z - w * x),
                        2 * (x * z - w * y), 2 * (y * z + w * x), 1 - 2 * (x * x + y * y)], -1).reshape(q.shape[:-1] + (3, 3))


def _segment(q, a, b):
    """Distances of points q [n, 2] from the segment a-b."""
    import torch
    ab = b - a
    t = (((q - a) @ ab) / (ab @ ab).clamp_min(1e-9)).clamp(0.0, 1.0)
    return (q - (a + t[:, None] * ab)).norm(dim=-1)


def initial(rig: Rig, data: Frames, device):
    """The first splats:
    - PER_TRIANGLE on each triangle of the face at random places on it, and AROUND round it where the frame sees
      the person - the beard's (below the mouth) bound to the lower face's edge, the rest to the head - at the
      depth of the face's rim;
    - ON_BODY over the body, each bone's laid in the frame (of a sample) where that bone is seen most surely, on
      the person nearest it there, at its plane's depth;
    each coloured from the frame it was laid in."""
    import numpy as np
    import torch
    g = torch.Generator(device="cpu").manual_seed(0)
    T, B = rig.T, data.B
    sample = data.train[:: max(1, data.train.size // 300)]
    seen = data.bone_seen[torch.tensor(sample, device=device)]
    best = int(sample[int((seen[:, :3].min(1).values).argmax())])

    def laid(i, pts, bind):
        origin, axes, unit, _v = rig.frames(data, i)
        return torch.einsum("nji,nj->ni", axes[bind], (pts - origin[bind])) / unit[bind, None]

    def colour_at(img, pts):
        px = pts[:, :2].long()
        px[:, 0] = px[:, 0].clamp(0, data.W - 1)
        px[:, 1] = px[:, 1].clamp(0, data.H - 1)
        return img[px[:, 1], px[:, 0]].clamp(0.02, 0.98)

    binds, places, cols = [], [], []
    # THE FACE, AND ROUND IT (in the frame the shoulders are seen best)
    img, person = data.get(best, ahead=False)
    origin, axes, unit, verts = rig.frames(data, best)
    bary = torch.rand((T, PER_TRIANGLE, 3), generator=g).to(device)
    bary = bary / bary.sum(-1, keepdim=True)
    pts = torch.einsum("tkj,tjc->tkc", bary, verts[rig.tris]).reshape(-1, 3)
    bind = torch.arange(T, device=device).repeat_interleave(PER_TRIANGLE)
    binds.append(bind)
    places.append(laid(best, pts, bind))
    cols.append(colour_at(img, pts))
    mouth = verts[[61, 291]].mean(0)
    from PIL import Image, ImageDraw
    hull = Image.new("L", (data.W, data.H), 0)
    face2d = verts[:468, :2].detach().cpu().numpy()
    ImageDraw.Draw(hull).polygon([tuple(map(float, face2d[j])) for j in _convex(face2d)], fill=255)
    inside = torch.tensor(np.asarray(hull) > 127, device=device)
    around = (person > 0.5) & head_region(data, verts) & ~inside
    ys, xs = torch.nonzero(around, as_tuple=True)
    pick = torch.randint(0, ys.numel(), (AROUND,), generator=g).to(device)
    rim = verts[[10, 152, 234, 454, 127, 356, 172, 397], 2].mean()
    pts = torch.stack([xs[pick].float() + 0.5, ys[pick].float() + 0.5, torch.full((AROUND,), float(rim), device=device)], -1)
    bind = torch.full((AROUND,), T, device=device, dtype=torch.long)
    below = pts[:, 1] > mouth[1]
    lower = torch.tensor(sorted({t for t in range(T) if float(origin[t, 1]) > float(mouth[1])}), device=device)
    if lower.numel() and bool(below.any()):
        bind[below] = lower[torch.cdist(pts[below, :2], origin[lower, :2]).argmin(1)]
    binds.append(bind)
    places.append(laid(best, pts, bind))
    cols.append(colour_at(img, pts))
    # THE BODY: each bone's splats in the frame it is seen best, on the person nearest it there
    per_bone = max(1, ON_BODY // B)
    for b in range(B):
        i = int(sample[int(seen[:, b].argmax())])
        if float(data.bone_seen[i, b]) < SEEN:
            continue
        img_b, person_b = data.get(i, ahead=False)
        o = data.bone_origin[i]
        sw = float(data.bone_unit[i, 0]) * 4.0
        segs = []
        for bb in range(B):
            if bb == 0:
                segs.append((o[0, :2], o[0, :2] + torch.tensor([0.0, TORSO * sw], device=device)))
            elif bb in (1, 2):
                segs.append((o[bb, :2], o[bb, :2]))
            else:
                tip = o[bb, :2] + 2.0 * data.bone_unit[i, bb] * data.bone_axes[i, bb, :2, 0]
                segs.append((o[bb, :2], tip))
        x0b, y0b, x1b, y1b = data.face_box(i)
        not_head = torch.ones_like(person_b, dtype=torch.bool)
        not_head[int(max(0, y0b - 0.5 * (y1b - y0b))):int(y1b + 0.6 * (y1b - y0b)),
                 int(max(0, x0b - 0.4 * (x1b - x0b))):int(x1b + 0.4 * (x1b - x0b))] = False
        ys, xs = torch.nonzero((person_b > 0.5) & not_head, as_tuple=True)
        if ys.numel() == 0:
            continue
        q = torch.stack([xs.float() + 0.5, ys.float() + 0.5], -1)
        d = torch.stack([_segment(q, a, e) - (0.25 * sw if bb in (1, 2) else 0.0)
                         for bb, (a, e) in enumerate(segs)], -1)
        d[:, data.bone_seen[i] < SEEN] = float("inf")
        mine = d.argmin(1) == b
        ys, xs = ys[mine], xs[mine]
        if ys.numel() == 0:
            continue
        pick = torch.randint(0, ys.numel(), (per_bone,), generator=g).to(device)
        pts = torch.stack([xs[pick].float() + 0.5, ys[pick].float() + 0.5,
                           o[b, 2].expand(per_bone) + torch.randn(per_bone, generator=g).to(device) * 0.05 * sw], -1)
        bind = torch.full((per_bone,), T + 1 + b, device=device, dtype=torch.long)
        binds.append(bind)
        places.append(laid(i, pts, bind))
        cols.append(colour_at(img_b, pts))
    bind = torch.cat(binds)
    place = torch.cat(places)
    col = torch.cat(cols)
    _o, _a, unit, _v = rig.frames(data, best)
    log_scale = torch.log((2.0 / unit[bind])[:, None].repeat(1, 3))
    log_scale[:, 2] -= 1.0                                               # flat against their surface
    turn = torch.zeros((bind.shape[0], 4), device=device)
    turn[:, 0] = 1.0
    cover = torch.full((bind.shape[0],), _logit(0.3), device=device)
    return Splats(bind, place, log_scale, turn, torch.log(col / (1.0 - col)), cover, T, k=data.K)


def head_region(data: Frames, verts):
    """WHERE THEIR HEAD IS in a picture of them posed so ([param verts]: the face's points in its pixels) - an
    ellipse round the face from above the hair down to the mouth, and the beard's below the mouth: the reach of
    the splats bound to the head and the face. [H, W] bool."""
    import torch
    x0, y0 = [float(v) for v in verts[:468, :2].min(0).values]
    x1, y1 = [float(v) for v in verts[:468, :2].max(0).values]
    w, h = x1 - x0, y1 - y0
    mouth = verts[[61, 291]].mean(0)
    yy, xx = torch.meshgrid(torch.arange(data.H, device=verts.device) + 0.5,
                            torch.arange(data.W, device=verts.device) + 0.5, indexing="ij")
    top = y0 - 0.45 * h
    head = (((xx - (x0 + x1) / 2) / (0.95 * w)) ** 2 + ((yy - (top + y1) / 2) / ((y1 - top) / 2)) ** 2 < 1.0) & (yy < mouth[1])
    beard = (((xx - mouth[0]) / (0.55 * w)) ** 2 + ((yy - mouth[1]) / (y1 + 0.55 * h - mouth[1])) ** 2 < 1.0)
    return head | beard


def astray(splats, rig, data, i: int):
    """THE HEAD'S SPLATS PAST ITS REACH in frame [param i]: those bound to the head or a triangle of the face whose
    centre lies outside the head's region there (`head_region`, grown by HEAD_REACH pixels). [N] bool."""
    import torch
    origin, axes, unit, verts = rig.frames(data, i)
    means, _s, _t = splats.world(origin, axes, unit, data.expr[i])
    region = head_region(data, verts).float()[None, None]
    region = torch.nn.functional.max_pool2d(region, 2 * HEAD_REACH + 1, 1, HEAD_REACH)[0, 0] > 0.5
    x, y = means[:, 0], means[:, 1]
    there = (x >= 0) & (x < data.W) & (y >= 0) & (y < data.H)
    inside = there & region[y.long().clamp(0, data.H - 1), x.long().clamp(0, data.W - 1)]
    return (splats.bind <= rig.T) & ~inside


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


class Scene:
    """What is learned besides the splats: the room's plate, its gain per frame, and the splats' colour
    correction per frame ([3x3 | 3])."""

    def __init__(self, data: Frames, device):
        import torch
        n = int(data.blend.shape[0])
        self.plate0 = data.room.clone()
        self.plate = torch.nn.Parameter(data.room.clone())
        self.gain = torch.nn.Parameter(torch.ones((n, 3), device=device))
        correct = torch.zeros((n, 4, 3), device=device)
        correct[:, :3] = torch.eye(3, device=device)
        self.correct = torch.nn.Parameter(correct)
        self.opt = torch.optim.Adam([{"params": [self.plate], "lr": 2e-3}, {"params": [self.gain], "lr": 2e-3},
                                     {"params": [self.correct], "lr": 2e-4}])

    def behind(self, i: int, wx: int, wy: int, w: int, h: int, light=True):
        return (self.plate[wy:wy + h, wx:wx + w] * (self.gain[i] if light else 1.0)).clamp(0.0, 1.0)


def render(splats: Splats, rig: Rig, data: Frames, scene: Scene, i: int, wx: int, wy: int, w: int, h: int,
           tracked=True, learned=True):
    """Frame i's window at (wx, wy), w x h, them over the room: (image, cover, means2d, radii, unit). [param learned]
    takes the frame's own light (a frame learned from has it)."""
    import torch
    import raster
    origin, axes, unit, _v = rig.frames(data, i, tracked)
    expr = data.expr[i]
    means, scales, turns = splats.world(origin, axes, unit, expr)
    means2d, conics, depth, radii = raster.project(means, scales, turns)
    if means2d.requires_grad:
        means2d.retain_grad()
    colours = splats.colours(expr)
    if learned:
        c = scene.correct[i]
        colours = (colours @ c[:3] + c[3]).clamp(0.0, 1.0)
    shifted = means2d - torch.tensor([float(wx), float(wy)], device=means2d.device)
    image, cover = raster.rasterize(shifted, conics, colours, splats.covers(data.bone_seen[i]), depth, radii, h, w,
                                    scene.behind(i, wx, wy, w, h, learned))
    return image, cover, means2d, radii, unit


def preview(splats, rig, data, scene, step: int, out_dir: str):
    """Held-out frames, the person's part of each: theirs on top, the splats as tracked under it, then as played
    (the face from the frame's scores alone)."""
    import numpy as np
    import torch
    from PIL import Image
    cols = []
    with torch.no_grad():
        for i in data.measured[:: max(1, len(data.measured) // 4)][:4]:
            i = int(i)
            img, _p = data.get(i, ahead=False)
            x0, y0, x1, y1 = data.face_box(i)
            pw = min(1024, data.W)
            wx = int(np.clip((x0 + x1) / 2 - pw / 2, 0, data.W - pw))
            got = render(splats, rig, data, scene, i, wx, 0, pw, data.H, learned=False)[0]
            played = render(splats, rig, data, scene, i, wx, 0, pw, data.H, tracked=False, learned=False)[0]
            col = torch.cat([img[:, wx:wx + pw], got, played], 0)
            cols.append(torch.nn.functional.avg_pool2d(col.permute(2, 0, 1)[None], 2)[0].permute(1, 2, 0))
    pic = (torch.cat(cols, 1).clamp(0, 1).cpu().numpy() * 255.0 + 0.5).astype(np.uint8)
    os.makedirs(out_dir, exist_ok=True)
    Image.fromarray(pic).save(os.path.join(out_dir, "%06d.jpg" % step), quality=88)


def held_error(splats, rig, data, scene):
    """PSNR on the held-out frames, in a window round the face and one round the body under it."""
    import numpy as np
    import torch
    out = {"face": [], "body": []}
    with torch.no_grad():
        for i in data.measured:
            i = int(i)
            img, _p = data.get(i, ahead=False)
            x0, y0, x1, y1 = data.face_box(i)
            for name, cy in (("face", (y0 + y1) / 2), ("body", y1 + (y1 - y0) * 1.2)):
                wx = int(np.clip((x0 + x1) / 2 - WINDOW / 2, 0, data.W - WINDOW))
                wy = int(np.clip(cy - WINDOW / 2, 0, data.H - WINDOW))
                got = render(splats, rig, data, scene, i, wx, wy, WINDOW, WINDOW, learned=False)[0]
                mse = float(((got - img[wy:wy + WINDOW, wx:wx + WINDOW]) ** 2).mean())
                out[name].append(-10.0 * math.log10(max(mse, 1e-10)))
    return {k: float(np.mean(v)) for k, v in out.items()}


# The width of the splats' data texture Godot reads, in texels.
TEXEL_WIDTH = 4096


def export(npz: str, order, extra=None) -> None:
    """THE AVATAR AS GODOT READS IT (src/likeness/splat_head.gd): <npz minus .npz>.json, its header - the counts
    (splats, triangles, the face's points, the scores, the bones), the crop, the head's unit, the expression's
    components, each array's [byte offset, count, type] and whatever [param extra] adds - .bin, the arrays end to end, little-endian, and
    .plate.png, the room. The splats are written in [param order] - back to front as a frame of theirs stands -
    so a renderer that draws them in order composites them as learned.

    `texels` IS THE SHADER'S DATA TEXTURE, byte for byte (RGBA floats, TEXEL_WIDTH wide): per splat, in order,
    its place and binding, its log-scale and cover, its turn (w, x, y, z), its colour's logit, then for each of
    the expression's components its place's shift and its colour's shift - 4 + 2K texels."""
    import numpy as np
    from PIL import Image
    a = np.load(npz)
    bind = a["bind"]
    T = int(a["tris"].shape[0])
    N = bind.shape[0]
    k = int(a["place_d"].shape[1])
    per = 4 + 2 * k
    tex = np.zeros((N, per, 4), np.float32)
    tex[:, 0, :3] = a["place"][order]
    tex[:, 0, 3] = bind[order]
    tex[:, 1, :3] = a["log_scale"][order]
    tex[:, 1, 3] = a["cover"][order]
    tex[:, 2, :] = a["turn"][order]
    tex[:, 3, :3] = a["colour_logit"][order]
    for j in range(k):
        tex[:, 4 + 2 * j, :3] = a["place_d"][order][:, j]
        tex[:, 5 + 2 * j, :3] = a["colour_d"][order][:, j]
    flat = tex.reshape(-1, 4)
    rows = -(-flat.shape[0] // TEXEL_WIDTH)
    texels = np.zeros((rows * TEXEL_WIDTH, 4), np.float32)
    texels[: flat.shape[0]] = flat
    arrays = {"texels": texels.astype("<f4"), "canon": a["canon"].astype("<f4"), "basis": a["basis"].astype("<f4"),
              "tris": a["tris"].astype("<i4"), "expr_mean": a["expr_mean"].astype("<f4"),
              "expr_basis": a["expr_basis"].astype("<f4"), "expr_scale": a["expr_scale"].astype("<f4")}
    base = npz[:-4] if npz.endswith(".npz") else npz
    Image.fromarray((np.clip(a["plate"], 0, 1) * 255.0 + 0.5).astype(np.uint8)).save(base + ".plate.png.part.png")
    os.replace(base + ".plate.png.part.png", base + ".plate.png")
    head = {"version": 3, "splats": int(N), "tris": T, "verts": int(a["canon"].shape[0]),
            "scores": int(a["basis"].shape[0]), "bones": int(a["bones"]), "crop": [int(c) for c in a["crop"]],
            "size": int(a["crop"][2]), "head_unit": HEAD_UNIT, "texel_width": TEXEL_WIDTH, "per_splat": per,
            "expressions": k, "shift_near": SHIFT_NEAR, "shift_far": SHIFT_FAR, "plate": os.path.basename(base) + ".plate.png",
            "arrays": {}}
    head.update(extra or {})
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


def save(splats, rig, data, scene, rig_path: str, out: str, at=None, extra=None):
    """avatar.npz, then the export (with [param extra] in its header) in the order the splats stand back to front
    in a frame of theirs ([param at], else the first measured)."""
    import numpy as np
    import torch
    r = np.load(rig_path)
    with torch.no_grad():
        i = int(data.measured[0]) if at is None else int(at)
        origin, axes, unit, _v = rig.frames(data, i)
        means, _s, _t = splats.world(origin, axes, unit)
        order = torch.argsort(-means[:, 2], stable=True).cpu().numpy()
        np.savez(out + ".part.npz", bind=splats.bind.cpu().numpy().astype(np.int32),
                 place=splats.p["place"].cpu().numpy(), log_scale=splats.p["log_scale"].cpu().numpy(),
                 turn=torch.nn.functional.normalize(splats.p["turn"], dim=-1).cpu().numpy(),
                 colour_logit=splats.p["colour"].cpu().numpy(), cover=splats.covers().cpu().numpy(),
                 place_d=splats.p["place_d"].cpu().numpy(), colour_d=splats.p["colour_d"].cpu().numpy(),
                 expr_mean=data.expr_mean.astype(np.float32), expr_basis=data.expr_basis.astype(np.float32),
                 expr_scale=data.expr_scale.astype(np.float32), plate=scene.plate.cpu().numpy(),
                 canon=r["canon"], basis=r["basis"], tris=r["tris"], bones=np.int32(data.B),
                 crop=np.asarray(data.crop, np.int32))
    os.replace(out + ".part.npz", out)
    export(out, order, extra)


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
    data = Frames(spec, dev)
    rig = Rig(spec["rig"], dev)
    splats = initial(rig, data, dev)
    scene = Scene(data, dev)
    steps = int(spec.get("steps", 40000))
    say("%d frames to learn from, %d held out; %d splats to start (%d bones); %d steps in %d px windows of %dx%d"
        % (len(data.train), len(data.held), len(splats), data.B, steps, WINDOW, data.W, data.H))
    rng = np.random.default_rng(0)
    order = np.concatenate([rng.permutation(data.train) for _ in range(steps // data.train.size + 1)])[:steps]
    data.read_ahead(order)
    front = 1.0 - data.front
    strays = 0
    t0 = time.time()
    for step in range(1, steps + 1):
        i = int(order[step - 1])
        img, person = data.get(i)
        wx, wy = data.window(i, rng, rng.random() < FACE_WINDOWS)
        image, cover, means2d, radii, unit = render(splats, rig, data, scene, i, wx, wy, WINDOW, WINDOW)
        truth = img[wy:wy + WINDOW, wx:wx + WINDOW]
        m = front[wy:wy + WINDOW, wx:wx + WINDOW]
        l1 = ((image - truth).abs() * m[..., None]).sum() / (m.sum() * 3 + 1e-6)
        dssim = ((1.0 - ssim_map(image, truth)) * m[..., None]).sum() / (m.sum() * 3 + 1e-6)
        cov = ((cover - person[wy:wy + WINDOW, wx:wx + WINDOW]).abs() * m).sum() / (m.sum() + 1e-6)
        face = splats.bind < rig.T
        place = splats.p["place"][face]
        reg = torch.relu(place.norm(dim=-1) - STRAY).mean() + torch.relu(torch.exp(splats.p["log_scale"][face]) - LARGE).mean()
        shifts = (splats.p["place_d"] ** 2).mean() + (splats.p["colour_d"] ** 2).mean()
        plate = (scene.plate - scene.plate0).abs().mean()
        loss = ((1.0 - SSIM_SHARE) * l1 + SSIM_SHARE * dssim + COVER_SHARE * cov + REG_SHARE * reg
                + DELTA_PULL * shifts + PLATE_PULL * plate)
        splats.opt.zero_grad(set_to_none=True)
        scene.opt.zero_grad(set_to_none=True)
        loss.backward()
        with torch.no_grad():
            if step < DENSIFY_UNTIL and means2d.grad is not None:
                p = means2d - torch.tensor([float(wx), float(wy)], device=dev)
                r = radii.float()
                there = (p[:, 0] + r > 0) & (p[:, 0] - r < WINDOW) & (p[:, 1] + r > 0) & (p[:, 1] - r < WINDOW)
                splats.pull[there] += means2d.grad[there].norm(dim=-1) * (WINDOW * 0.5)
                splats.seen[there] += 1.0
        splats.opt.step()
        scene.opt.step()
        if DENSIFY_FROM <= step < DENSIFY_UNTIL and step % DENSIFY_EVERY == 0:
            if step % 1000 == 0:
                seen = splats.seen > 0
                pull = (splats.pull[seen] / splats.seen[seen]) if bool(seen.any()) else torch.zeros(1, device=dev)
                spread = (float(pull.median()), float(torch.quantile(pull[:100000], 0.95)))
            made = splats.densify(unit)
            if step % 1000 == 0:
                say("step %d: %d splats (copied %d, split %d, dropped %d; %d of the head's past its reach); pull "
                    "median %.2g, 95th %.2g" % ((step, len(splats)) + made + (strays,) + spread))
                strays = 0
        if step >= DENSIFY_FROM and step % DENSIFY_EVERY == 0:
            with torch.no_grad():
                far = astray(splats, rig, data, i)
            if bool(far.any()):
                strays += int(far.sum())
                splats._replace(~far, {})
        if step % OPACITY_RESET == 0 and step < DENSIFY_UNTIL:
            splats.reset_cover()
        if step > DENSIFY_UNTIL and step % PRUNE_EVERY == 0:
            gone = splats.prune()
            if step % 5000 == 0:
                say("step %d: %d splats (dropped %d nearly clear; %d of the head's past its reach)"
                    % (step, len(splats), gone, strays))
                strays = 0
        if step % 500 == 0:
            progress(a.progress, step / steps)
            say("step %d: loss %.4f (L1 %.4f, cover %.4f), %d splats, %.0f s" % (step, loss.item(), l1.item(),
                                                                               cov.item(), len(splats), time.time() - t0))
        if spec.get("preview") and (step % 5000 == 0 or step == steps):
            preview(splats, rig, data, scene, step, spec["preview"])
            e = held_error(splats, rig, data, scene)
            say("step %d: held out - PSNR %.2f dB round the face, %.2f round the body" % (step, e["face"], e["body"]))
            save(splats, rig, data, scene, spec["rig"], spec["out"])
    save(splats, rig, data, scene, spec["rig"], spec["out"])
    e = held_error(splats, rig, data, scene)
    say("%d splats; on %d frames it never saw: PSNR %.2f dB round the face, %.2f round the body; %.0f minutes"
        % (len(splats), len(data.held), e["face"], e["body"], (time.time() - t0) / 60.0))
    progress(a.progress, 1.0)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
