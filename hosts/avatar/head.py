#!/usr/bin/env python3
"""head.py - ONE HEAD FOR EVERY SET: an actor's head of splats learned from moments of every video of theirs
at once (next/likeness.md, "One head").

    <voice_train_venv python> head.py --spec <spec.json> [--progress <file>]

The spec: {"rig", "out", "steps", "preview"} - the actor's rig (rig.py over every video's head_frames.py folder:
one neutral face, one basis, and which folder each frame is from), where the head goes, how many steps, and a
folder for pictures of it against held-out frames.

WHY (the user, 2026-10-23: "It's pointless to build a gaussian splatting model if the scenes can only generate
from a single set of images ... let us search for a kind of learned blend, which can inherit features from the
actor across all sets"): a set's avatar had learned from one shot of one video, and knew only what it showed -
the plaid set's ASMR video has 6 frames with the jaw past 0.45, the sweater set's 57. Every video shows the
same face, its mouth, its turns; what differs is the light, the camera, and a little of them (the hair tied or
loose, the beard's length).

SO THE HEAD IS SHARED AND EACH VIDEO HAS A LOOK:
- THE HEAD'S SPLATS (bound to the face's triangles and to the head, as train.py binds them) are learned from
  every video's moments, with their expression shifts (GaussianBlendshapes, as train.py's);
- A VIDEO'S LOOK is a code of LOOKS numbers, its own, learned: every head splat shifts its place and colour by
  the code (`look_place`, `look_colour` [N, LOOKS, 3] - the expression's mechanism, mixed by the video rather
  than the face), both pulled toward none (LOOK_PULL, CODE_PULL), so what all videos share stays in the splats;
  with the per-frame colour correction train.py has (the day's light);
- EACH VIDEO HAS ITS OWN ROOM (train.room_of over its moments, learned only where seen) AND ITS OWN BODY: a few
  splats on its bones (BODY_START, at most BODY_MOST), a group of their own with an optimizer of their own, there
  so the head is never asked to paint a video's clothes - a set's body is fitted to its own still (bake.py, fit.py);
- A VIDEO WITH TOO FEW MOMENTS OF THEIR FACE (LEAST: a timelapse, a video of ants) IS LEFT OUT - no room, no body,
  and the others' mean look as its code.

Each step: a frame of any video, a window of it (FACE_WINDOWS round the face), the head as that video looks and
that video's body, over its room; L1 and SSIM, the cover against the person, train.py's regularisers. A video's
room, body and code are each their own parameters: a step on one video never moves another's.

Writes <out> (head.npz): the head's splats with their expression and look shifts, every video's code, room and
body, the expression's components and the rig's face - what bake.py makes a set's avatar from - and, every so
often, <preview>/<step>.jpg.
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

# A video's look: how many numbers its code has, how far from none each code starts (the code and the shifts it
# mixes both started at none, and neither was ever pulled: each one's pull is the other times the error), and the
# pulls toward no shift and no code.
LOOKS = 8
CODE_START = 0.3
LOOK_PULL = 1e-3
CODE_PULL = 1e-3
# A video's body: the splats laid on its bones to start, and the most it may grow to - its share of BODIES_MOST
# for them all (19 bodies of 40,000 held 888k splats and 12 GB of a 16 GB card with the head), at most BODY_MOST.
BODY_START = 8000
BODY_MOST = 40000
BODIES_MOST = 600000
# The head's splats at most.
HEAD_MOST = 500000
# A room's move is learned at 1/this of the frame's size (Rooms: a room kept small).
ROOM_COARSE = 2
# The share of windows round the face (the rest over the person: its body is learned there).
FACE_WINDOWS = 0.8
# Every n-th moment of each video is held out; this many are measured on, across the videos.
HELD_OUT = 20
MEASURED = 48
# A video with fewer moments of theirs than this is left out (a timelapse showed their face in 1 of 47 looks, a
# video of ants in none; the one held out, nothing was left to lay its body from): a handful teaches neither its
# room nor its look - a video's share of the steps is its share of the moments - and its code is the others' mean.
LEAST = 20


def say(*parts) -> None:
    print("actor: head:", *parts, flush=True)


# --- every video's moments -------------------------------------------------------------------------

class Footage(train.Frames):
    """EVERY VIDEO'S MOMENTS, as train.Frames is one set's: the rig's per-frame arrays (its frames in folder order,
    `video` saying whose), each moment read from its own folder. The frame's size is the first folder's; a folder
    of another size is left out, and so is one with fewer than LEAST moments (`used`, `left_out`: its count)."""

    def __init__(self, rig_path: str, device):
        import numpy as np
        import torch
        r = np.load(rig_path)
        self.folders = [str(f) for f in r["folders"]]
        self.video = r["video"].astype(np.int64)
        self.V = len(self.folders)
        self.local = np.zeros(self.video.size, np.int64)
        sizes, pts = [], []
        for v, d in enumerate(self.folders):
            self.local[self.video == v] = np.arange(int((self.video == v).sum()))
            c = [int(x) for x in json.load(open(os.path.join(d, "spec.json")))["crop"]]
            sizes.append((c[2], c[3]))
            pts.append(np.load(os.path.join(d, "frames.npz"))["points"])
        self.points = np.concatenate(pts)
        self.W, self.H = sizes[0]
        self.crop = [0, 0, self.W, self.H]
        keep = r["keep"].astype(bool)
        for i in range(keep.size):
            v = int(self.video[i])
            if keep[i] and (sizes[v] != sizes[0] or not os.path.exists(self._path(i, "mask", ".png"))):
                keep[i] = False
        counts = np.bincount(self.video[keep], minlength=self.V)
        self.used = [v for v in range(self.V) if counts[v] >= LEAST]
        self.left_out = {v: int(counts[v]) for v in range(self.V) if counts[v] < LEAST}
        if not self.used:
            raise ValueError("no video shows %d moments of their face" % LEAST)
        keep &= np.isin(self.video, self.used)
        self.idx = np.nonzero(keep)[0]
        self.held = np.concatenate([self.idx[self.video[self.idx] == v][::HELD_OUT] for v in self.used])
        self.train = np.setdiff1d(self.idx, self.held)
        self.measured = self.held[:: max(1, self.held.size // MEASURED)][:MEASURED]
        t = lambda x: torch.tensor(x, device=device, dtype=torch.float32)
        self.blend, self.scale, self.rot, self.shift = t(r["blend"]), t(r["scale"]), t(r["rot"]), t(r["shift"])
        self.aligned = t(r["aligned"])
        self.bone_origin, self.bone_axes = t(r["bone_origin"]), t(r["bone_axes"])
        self.bone_unit, self.bone_seen = t(r["bone_unit"]), t(r["bone_seen"])
        self.B = int(r["bone_unit"].shape[1])
        self.device = device
        b = r["blend"].astype(np.float64)
        self.expr_mean = b[self.train].mean(0)
        _u, sv, vt = np.linalg.svd(b[self.train] - self.expr_mean, full_matrices=False)
        self.expr_basis = vt[:train.EXPRESSIONS].T
        self.expr_scale = sv[:train.EXPRESSIONS] / math.sqrt(max(1, self.train.size - 1))
        self.expr = t((b - self.expr_mean) @ self.expr_basis / np.maximum(self.expr_scale, 1e-6))
        self.K = train.EXPRESSIONS
        # nothing stands before them that the loss must leave out (a set's microphone is the set's own)
        self.front = torch.zeros((self.H, self.W), device=device)
        self._queue = None

    def _path(self, i: int, kind: str, ext: str) -> str:
        return os.path.join(self.folders[int(self.video[i])], kind, "%05d%s" % (int(self.local[i]), ext))

    def _load(self, i: int):
        import numpy as np
        from PIL import Image
        return (np.asarray(Image.open(self._path(i, "img", ".jpg")), np.uint8),
                np.asarray(Image.open(self._path(i, "mask", ".png")), np.uint8))

    def of(self, v: int, frames):
        """Those of [param frames] that are video [param v]'s."""
        return frames[self.video[frames] == v]

    def room_of_video(self, v: int):
        """Video [param v]'s room as its moments show it ([method train.room_of])."""
        import numpy as np
        mine = self.of(v, self.train)
        pick = mine[np.linspace(0, mine.size - 1, min(train.PLATE_FRAMES, mine.size)).astype(int)]
        got = [self._load(int(i)) for i in pick]
        return train.room_of([g[0] for g in got], [g[1] for g in got], self.device)


# --- the head, as each video looks -----------------------------------------------------------------

class HeadSplats(train.Splats):
    """The head's splats, train.Splats' with A LOOK: shifts of place and colour for each of LOOKS components,
    mixed by a video's code (`look_place`, `look_colour` [N, LOOKS, 3])."""

    NAMES = train.Splats.NAMES + ("look_place", "look_colour")
    RATES = {**train.Splats.RATES, "look_place": 1e-3, "look_colour": 1.5e-3}

    def __init__(self, bind, place, log_scale, turn, colour, cover, triangles: int, place_d=None, colour_d=None,
                 k=train.EXPRESSIONS, look_place=None, look_colour=None, looks=LOOKS):
        import torch
        self.bind = bind
        self.T = triangles
        n = bind.shape[0]
        z = lambda m: torch.zeros((n, m, 3), device=bind.device)
        values = (place, log_scale, turn, colour, cover, place_d if place_d is not None else z(k),
                  colour_d if colour_d is not None else z(k), look_place if look_place is not None else z(looks),
                  look_colour if look_colour is not None else z(looks))
        self.p = {name: torch.nn.Parameter(v.contiguous()) for name, v in zip(self.NAMES, values)}
        self.opt = torch.optim.Adam([{"params": [self.p[n]], "lr": self.RATES[n], "name": n} for n in self.NAMES],
                                    eps=1e-15)
        self.pull = torch.zeros(n, device=bind.device)
        self.seen = torch.zeros(n, device=bind.device)

    def world(self, origin, axes, unit, expr=None, code=None):
        import torch
        means, scales, turns = super().world(origin, axes, unit, expr)
        if code is not None:
            u, ax = unit[self.bind], axes[self.bind]
            means = means + u[:, None] * torch.einsum("nij,nj->ni", ax, torch.einsum("l,nlc->nc", code,
                                                                                     self.p["look_place"]))
        return means, scales, turns

    def colours(self, expr=None, code=None):
        import torch
        if code is None:
            return super().colours(expr)
        c = self.p["colour"] + torch.einsum("l,nlc->nc", code, self.p["look_colour"])
        if expr is not None and self.p["colour_d"].shape[1] == expr.shape[0]:
            c = c + self.shift_weight()[:, None] * torch.einsum("k,nkc->nc", expr, self.p["colour_d"])
        return torch.sigmoid(c)

    def baked(self, code):
        """THE HEAD AS VIDEO [param code] LOOKS: train.Splats, its look folded into its place and colour."""
        import torch
        with torch.no_grad():
            place = self.p["place"] + torch.einsum("l,nlc->nc", code, self.p["look_place"])
            colour = self.p["colour"] + torch.einsum("l,nlc->nc", code, self.p["look_colour"])
            return train.Splats(self.bind.clone(), place.clone(), self.p["log_scale"].clone(), self.p["turn"].clone(),
                                colour.clone(), self.p["cover"].clone(), self.T, self.p["place_d"].clone(),
                                self.p["colour_d"].clone(), k=self.p["place_d"].shape[1])


def stored(x):
    """[param x] in 0..1 as a room keeps it: uint8."""
    import torch
    return (x.clamp(0.0, 1.0) * 255.0 + 0.5).to(torch.uint8)


class Rooms:
    """Every video's room - its plate, learned only as far as its moments show it - and each frame's gain and
    colour correction, as train.Scene has them for one set.

    A ROOM IS KEPT SMALL (2026-10-24: 63 rooms as train.Scene keeps one, the plate, its seen and its move with the
    move's optimizer in float, held 6.8 GB of a 16 GB card shared with another trainer): the plate and seen are
    uint8 (the plate is the frames' median of uint8 pictures), and the move is learned at 1/ROOM_COARSE of the
    frame's size, upsampled bilinearly - a correction to a plate that holds the room's own detail."""

    def __init__(self, data: Footage, device, plates, seens):
        import torch
        import torch.nn.functional as F
        n = int(data.blend.shape[0])
        self.data = data
        self.plate0 = plates
        self.seen = seens
        self.moved, self.seen_coarse = [], []
        for s in seens:
            coarse = F.avg_pool2d(s.float()[None, None] / 255.0, ROOM_COARSE, ceil_mode=True)[0, 0]
            self.seen_coarse.append(coarse[..., None])
            self.moved.append(torch.nn.Parameter(torch.zeros(coarse.shape + (3,), device=device)))
        self.gain = torch.nn.Parameter(torch.ones((n, 3), device=device))
        correct = torch.zeros((n, 4, 3), device=device)
        correct[:, :3] = torch.eye(3, device=device)
        self.correct = torch.nn.Parameter(correct)
        self.opt = torch.optim.Adam([{"params": self.moved, "lr": 2e-3}, {"params": [self.gain], "lr": 2e-3},
                                     {"params": [self.correct], "lr": 2e-4}])

    def move(self, v: int, wx: int, wy: int, w: int, h: int):
        """Video [param v]'s move over the window at (wx, wy), w x h, at the frame's size: the coarse cells round
        it upsampled (a cell's margin on each side, so it is the whole move's upsampling cut to the window)."""
        import torch.nn.functional as F
        k, m = ROOM_COARSE, self.moved[v]
        y0, x0 = max(0, wy // k - 1), max(0, wx // k - 1)
        y1, x1 = min(m.shape[0], (wy + h) // k + 2), min(m.shape[1], (wx + w) // k + 2)
        up = F.interpolate(m[y0:y1, x0:x1].permute(2, 0, 1)[None], scale_factor=k, mode="bilinear",
                           align_corners=False)[0].permute(1, 2, 0)
        return up[wy - k * y0: wy - k * y0 + h, wx - k * x0: wx - k * x0 + w]

    def plate(self, v: int, wx=0, wy=0, w=None, h=None):
        H, W = self.plate0[v].shape[:2]
        w, h = (W - wx) if w is None else w, (H - wy) if h is None else h
        base = self.plate0[v][wy:wy + h, wx:wx + w].float() / 255.0
        seen = self.seen[v][wy:wy + h, wx:wx + w, None].float() / 255.0
        return base + seen * self.move(v, wx, wy, w, h)

    def pulled(self, v: int):
        return (self.seen_coarse[v] * self.moved[v]).abs().mean()

    def behind(self, i: int, wx: int, wy: int, w: int, h: int, light=True):
        v = int(self.data.video[i])
        return (self.plate(v, wx, wy, w, h) * (self.gain[i] if light else 1.0)).clamp(0.0, 1.0)


def render(head: HeadSplats, body, rig, data: Footage, rooms: Rooms, codes, i: int, wx: int, wy: int, w: int, h: int,
           tracked=True, learned=True):
    """Frame i's window at (wx, wy), w x h: the head as its video looks and that video's body, over its room:
    (image, cover, means2d, radii, unit) - means2d the head's splats first, then the body's."""
    import torch
    import raster
    origin, axes, unit, _v = rig.frames(data, i, tracked)
    expr = data.expr[i]
    code = codes[int(data.video[i])]
    hm, hs, ht = head.world(origin, axes, unit, expr, code)
    bm, bs, bt = body.world(origin, axes, unit)
    means2d, conics, depth, radii = raster.project(torch.cat([hm, bm]), torch.cat([hs, bs]), torch.cat([ht, bt]))
    if means2d.requires_grad:
        means2d.retain_grad()
    colours = torch.cat([head.colours(expr, code), body.colours()])
    if learned:
        c = rooms.correct[i]
        colours = (colours @ c[:3] + c[3]).clamp(0.0, 1.0)
    covers = torch.cat([head.covers(), body.covers(data.bone_seen[i])])
    shifted = means2d - torch.tensor([float(wx), float(wy)], device=means2d.device)
    image, cover = raster.rasterize(shifted, conics, colours, covers, depth, radii, h, w,
                                    rooms.behind(i, wx, wy, w, h, learned))
    return image, cover, means2d, radii, unit


def bodies_of(rig, data: Footage, device):
    """Each video's body to start: train.initial's, laid in that video's own moments, BODY_START of them; None for
    a video left out."""
    import torch
    keep_train, keep_on = data.train, train.ON_BODY
    out = []
    try:
        train.ON_BODY = BODY_START
        for v in range(data.V):
            if v in data.left_out:
                out.append(None)
                continue
            data.train = data.of(v, keep_train)
            s = train.initial(rig, data, device)
            on = s.bind > rig.T
            out.append(train.Splats(s.bind[on], s.p["place"].data[on], s.p["log_scale"].data[on],
                                    s.p["turn"].data[on], s.p["colour"].data[on], s.p["cover"].data[on], rig.T,
                                    torch.zeros((int(on.sum()), 0, 3), device=device),
                                    torch.zeros((int(on.sum()), 0, 3), device=device), k=0))
    finally:
        data.train, train.ON_BODY = keep_train, keep_on
    return out


def head_of(rig, data: Footage, device) -> HeadSplats:
    """The head to start: train.initial's face and round it, laid in the moment it chooses."""
    s = train.initial(rig, data, device)
    on = s.bind <= rig.T
    return HeadSplats(s.bind[on], s.p["place"].data[on], s.p["log_scale"].data[on], s.p["turn"].data[on],
                      s.p["colour"].data[on], s.p["cover"].data[on], rig.T, k=data.K)


def held_error(head, bodies, rig, data, rooms, codes):
    """PSNR on held-out moments in a window round the face, each as its video looks, with no light of its own."""
    import numpy as np
    import torch
    out = []
    with torch.no_grad():
        for i in data.measured:
            i = int(i)
            img, _p = data.get(i, ahead=False)
            x0, y0, x1, y1 = data.face_box(i)
            wx = int(np.clip((x0 + x1) / 2 - train.WINDOW / 2, 0, data.W - train.WINDOW))
            wy = int(np.clip((y0 + y1) / 2 - train.WINDOW / 2, 0, data.H - train.WINDOW))
            got = render(head, bodies[int(data.video[i])], rig, data, rooms, codes, i, wx, wy, train.WINDOW,
                         train.WINDOW, learned=False)[0]
            mse = float(((got - img[wy:wy + train.WINDOW, wx:wx + train.WINDOW]) ** 2).mean())
            out.append(-10.0 * math.log10(max(mse, 1e-10)))
    return float(np.mean(out))


def preview(head, bodies, rig, data, rooms, codes, step: int, out_dir: str):
    """Six held-out moments of six videos, round the face: theirs on top, as tracked, then as played (the face
    from its scores alone)."""
    import numpy as np
    import torch
    from PIL import Image
    cols = []
    vids = []
    with torch.no_grad():
        for i in data.measured:
            i = int(i)
            if int(data.video[i]) in vids:
                continue
            vids.append(int(data.video[i]))
            img, _p = data.get(i, ahead=False)
            x0, y0, x1, y1 = data.face_box(i)
            pw = 512
            wx = int(np.clip((x0 + x1) / 2 - pw / 2, 0, data.W - pw))
            wy = int(np.clip((y0 + y1) / 2 - pw / 2, 0, data.H - pw))
            body = bodies[int(data.video[i])]
            got = render(head, body, rig, data, rooms, codes, i, wx, wy, pw, pw, learned=False)[0]
            played = render(head, body, rig, data, rooms, codes, i, wx, wy, pw, pw, tracked=False, learned=False)[0]
            cols.append(torch.cat([img[wy:wy + pw, wx:wx + pw], got, played], 0))
            if len(cols) == 6:
                break
    pic = (torch.cat(cols, 1).clamp(0, 1).cpu().numpy() * 255.0 + 0.5).astype(np.uint8)
    os.makedirs(out_dir, exist_ok=True)
    Image.fromarray(pic).save(os.path.join(out_dir, "%06d.jpg" % step), quality=88)


def looks_of(codes, data: Footage):
    """Every video's code [V, LOOKS]: a video left out takes the mean of the others' (a set made from it starts there)."""
    import torch
    c = torch.stack([x.data for x in codes])
    if data.left_out:
        c[list(data.left_out)] = c[data.used].mean(0)
    return c


def save(head: HeadSplats, bodies, rooms: Rooms, codes, data: Footage, rig_path: str, out: str) -> None:
    """head.npz: the head's splats with their expression and look shifts, every video's code, room (uint8) and
    body (its splats end to end, `body_video` saying whose; a video left out has none, and a black room), the
    expression's components, the rig's face."""
    import numpy as np
    import torch
    r = np.load(rig_path)
    with torch.no_grad():
        held = [(v, b) for v, b in enumerate(bodies) if b is not None]
        cat = lambda name: torch.cat([b.p[name].data for _v, b in held]).cpu().numpy()
        np.savez(out + ".part.npz", bind=head.bind.cpu().numpy().astype(np.int32),
                 place=head.p["place"].cpu().numpy(), log_scale=head.p["log_scale"].cpu().numpy(),
                 turn=torch.nn.functional.normalize(head.p["turn"], dim=-1).cpu().numpy(),
                 colour_logit=head.p["colour"].cpu().numpy(), cover=head.covers().cpu().numpy(),
                 place_d=head.p["place_d"].cpu().numpy(), colour_d=head.p["colour_d"].cpu().numpy(),
                 look_place=head.p["look_place"].cpu().numpy(), look_colour=head.p["look_colour"].cpu().numpy(),
                 codes=looks_of(codes, data).cpu().numpy(),
                 rooms=np.stack([stored(rooms.plate(v)).cpu().numpy() for v in range(data.V)]),
                 body_video=np.concatenate([np.full(len(b), v, np.int32) for v, b in held]),
                 body_bind=torch.cat([b.bind for _v, b in held]).cpu().numpy().astype(np.int32),
                 body_place=cat("place"), body_log_scale=cat("log_scale"),
                 body_turn=torch.nn.functional.normalize(torch.cat([b.p["turn"].data for _v, b in held]), dim=-1).cpu().numpy(),
                 body_colour_logit=cat("colour"), body_cover=torch.cat([b.covers() for _v, b in held]).cpu().numpy(),
                 expr_mean=data.expr_mean.astype(np.float32), expr_basis=data.expr_basis.astype(np.float32),
                 expr_scale=data.expr_scale.astype(np.float32), canon=r["canon"], basis=r["basis"], tris=r["tris"],
                 bones=np.int32(data.B), crop=np.asarray(data.crop, np.int32), folders=np.asarray(data.folders))
    os.replace(out + ".part.npz", out)


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
    try:
        data = Footage(spec["rig"], dev)
    except ValueError as exc:
        say(str(exc))
        return 2
    rig = train.Rig(spec["rig"], dev)
    head = head_of(rig, data, dev)
    bodies = bodies_of(rig, data, dev)
    plates, seens = [], []
    with torch.no_grad():
        for v in range(data.V):
            if v in data.left_out:
                plates.append(torch.zeros((data.H, data.W, 3), dtype=torch.uint8, device=dev))
                seens.append(torch.zeros((data.H, data.W), dtype=torch.uint8, device=dev))
                continue
            p, s = data.room_of_video(v)
            plates.append(stored(p))
            seens.append(stored(s))
            del p, s
    rooms = Rooms(data, dev, plates, seens)
    g = torch.Generator(device="cpu").manual_seed(1)
    codes = [torch.nn.Parameter((torch.randn(LOOKS, generator=g) * CODE_START).to(dev)) for _ in range(data.V)]
    code_opt = torch.optim.Adam([{"params": codes, "lr": 5e-3}])
    steps = int(spec.get("steps", 60000))
    until = train.until_of(steps)
    if data.left_out:
        say("%d of %d videos left out, too few moments of their face (fewer than %d): %s"
            % (len(data.left_out), data.V, LEAST, ", ".join("%s %d" % (os.path.basename(os.path.dirname(
                data.folders[v])), n) for v, n in data.left_out.items())))
    say("%d videos, %d moments to learn from, %d held out; %d head splats and %d on their bodies to start; %d steps"
        % (len(data.used), len(data.train), len(data.held), len(head), sum(len(b) for b in bodies if b is not None),
           steps))
    rng = np.random.default_rng(0)
    order = np.concatenate([rng.permutation(data.train) for _ in range(steps // data.train.size + 1)])[:steps]
    data.read_ahead(order)
    strays = 0
    t0 = time.time()
    for step in range(1, steps + 1):
        i = int(order[step - 1])
        v = int(data.video[i])
        body = bodies[v]
        img, person = data.get(i)
        wx, wy = data.window(i, rng, rng.random() < FACE_WINDOWS)
        W = train.WINDOW
        image, cover, means2d, radii, unit = render(head, body, rig, data, rooms, codes, i, wx, wy, W, W)
        truth = img[wy:wy + W, wx:wx + W]
        l1 = (image - truth).abs().mean()
        dssim = (1.0 - train.ssim_map(image, truth)).mean()
        cov = (cover - person[wy:wy + W, wx:wx + W]).abs().mean()
        face = head.bind < rig.T
        place = head.p["place"][face]
        reg = (torch.relu(place.norm(dim=-1) - train.STRAY).mean()
               + torch.relu(torch.exp(head.p["log_scale"][face]) - train.LARGE).mean())
        shifts = (head.p["place_d"] ** 2).mean() + (head.p["colour_d"] ** 2).mean()
        looks = (head.p["look_place"] ** 2).mean() + (head.p["look_colour"] ** 2).mean()
        loss = ((1.0 - train.SSIM_SHARE) * l1 + train.SSIM_SHARE * dssim + train.COVER_SHARE * cov
                + train.REG_SHARE * reg + train.DELTA_PULL * shifts + LOOK_PULL * looks
                + CODE_PULL * (codes[v] ** 2).mean() + train.PLATE_PULL * rooms.pulled(v))
        for opt in (head.opt, body.opt, rooms.opt, code_opt):
            opt.zero_grad(set_to_none=True)
        loss.backward()
        with torch.no_grad():
            if step < until and means2d.grad is not None:
                g = means2d.grad.norm(dim=-1) * (W * 0.5)
                p = means2d - torch.tensor([float(wx), float(wy)], device=dev)
                r = radii.float()
                there = (p[:, 0] + r > 0) & (p[:, 0] - r < W) & (p[:, 1] + r > 0) & (p[:, 1] - r < W)
                nh = len(head)
                head.pull[there[:nh]] += g[:nh][there[:nh]]
                head.seen[there[:nh]] += 1.0
                body.pull[there[nh:]] += g[nh:][there[nh:]]
                body.seen[there[nh:]] += 1.0
        for opt in (head.opt, body.opt, rooms.opt, code_opt):
            opt.step()
        if train.DENSIFY_FROM <= step < until and step % train.DENSIFY_EVERY == 0:
            made = head.densify(unit, HEAD_MOST)
            for b in bodies:
                if b is not None and float(b.seen.sum()) > 0:
                    b.densify(unit, min(BODY_MOST, BODIES_MOST // len(data.used)))
            if step % 1000 == 0:
                say("step %d: %d head splats (copied %d, split %d, dropped %d; %d past its reach), %d on their bodies"
                    % ((step, len(head)) + made + (strays, sum(len(b) for b in bodies if b is not None))))
                strays = 0
        if step >= train.DENSIFY_FROM and step % train.DENSIFY_EVERY == 0:
            with torch.no_grad():
                far = train.astray(head, rig, data, i)
            if bool(far.any()):
                strays += int(far.sum())
                head._replace(~far, {})
        if step % train.OPACITY_RESET == 0 and step < until:
            head.reset_cover()
            for b in bodies:
                if b is not None:
                    b.reset_cover()
        if step > until and step % train.PRUNE_EVERY == 0:
            head.prune()
            for b in bodies:
                if b is not None:
                    b.prune()
        if step % 500 == 0:
            train.progress(a.progress, step / steps)
            say("step %d: loss %.4f (L1 %.4f, cover %.4f), %d head splats, %.0f s"
                % (step, loss.item(), l1.item(), cov.item(), len(head), time.time() - t0))
        if step % 5000 == 0 or step == steps:
            if spec.get("preview"):
                preview(head, bodies, rig, data, rooms, codes, step, spec["preview"])
            say("step %d: held out - PSNR %.2f dB round the face" % (step, held_error(head, bodies, rig, data, rooms,
                                                                                     codes)))
    save(head, bodies, rooms, codes, data, spec["rig"], spec["out"])
    shifts = torch.stack([torch.einsum("l,nlc->nc", codes[v].data, head.p["look_colour"].data).abs().mean()
                          for v in data.used])
    out = (" (%d more left out: too few moments of their face)" % len(data.left_out)) if data.left_out else ""
    say("%d head splats; %d videos%s, their looks shift its colours %.3f to %.3f (logit, on the mean); on %d moments it never saw: PSNR %.2f dB round "
        "the face; %d minutes" % (len(head), len(data.used), out, float(shifts.min()), float(shifts.max()),
                                  len(data.held), held_error(head, bodies, rig, data, rooms, codes),
                                  int((time.time() - t0) / 60)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
