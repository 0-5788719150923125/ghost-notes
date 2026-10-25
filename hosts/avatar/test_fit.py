#!/usr/bin/env python3
"""Tests for the fit of an avatar's body to its still (fit.py), the head's reach (train.py's `astray`), the
room behind them (train.py's `room_of`, `fill_round`, `Scene`) and the videos the head learns from (head.py's
`Footage`).

Run it directly with the voice-training venv's python (its torch) - no pytest needed, no graphics card:

    ~/.local/share/godot/app_userdata/ghost/voice_train_venv/bin/python hosts/avatar/test_fit.py

  NEVER NEEDLES - a body splat's longest side is cut to FIT_LONG times its next, its other sides kept; one
  within that, and any of the head's however long, is left as it was (CONTROL: before, the body's needle
  stood past FIT_LONG).
  THE HEAD'S SPLATS PAST ITS REACH ARE THE ASTRAY - of the head's (bound to the head or a face's triangle), the
  ones whose centre stands outside the head's region (over the chest, off the picture) are astray, the ones in
  it are not; a body splat standing where an astray one stands is not (CONTROL: the region is not empty and not
  the whole picture).
  THE STILL IS ONE MORE FRAME - its pose, scores, expression and bones appended as the poses' row has them, a
  bone's axes read as COLUMNS (as rig.py writes them: CONTROL, the axes are no symmetric matrix, so rows would
  differ); its points as tracked are its scores' face, so tracked and played draw it alike.
  THE ROOM IS THE WALL THE FRAMES SHOW - a person moving over a wall, their middle never leaving it: where any
  frames show the wall the plate is the wall, and where none does it is filled from round it with nothing of them
  in it (CONTROL: the median of the frames as they are holds their face there); their hair painted a few pixels
  past the mask is left out (CONTROL: with no margin it is in the plate); seen is 0 where no frame shows the wall
  and 1 where every one does.
  FILLED FROM ROUND IT - the known pixels kept exactly; a hole in a smooth ramp filled close to the ramp (CONTROL:
  the hole as it was is far from it).
  THE PLATE MOVES ONLY WHERE IT IS SEEN - moved everywhere, the plate where nothing showed it is still where it
  started, and no pull reaches it (CONTROL: where it is seen, it moved).
  A RUN ENDS WELL PAST ITS LAST RESET - of any length the Avatar steps setting allows, a third of the run at least
  comes after the splats were last made faint, and the default run's schedule is as it was (CONTROL: growing until
  DENSIFY_UNTIL whatever the length, 12,000 steps end on a reset).
  A VIDEO WITH TOO FEW MOMENTS IS LEFT OUT OF THE HEAD - of four videos with 30, 25, 3 and 1 moments (and one
  with none, a video of ants), those with fewer than LEAST are left out: none of their moments is learned from
  or held out, each other video has some of each, and a left-out video's code is the others' mean (CONTROL: with
  no floor, the video of one moment has it held out and none to learn from - the head's crash, 2026-10-24). And
  THE HEAD VIDEOS: named some, only those it can learn from are, the rest unchosen with the mean look (CONTROL:
  with none named, none is unchosen).
  A ROOM IS KEPT SMALL - its move learned at 1/ROOM_COARSE of the frame's size: over any window (at the frame's
  edges, of odd sizes) the move is the whole move's upsampling cut to it, and with no move the plate is the plate
  kept (CONTROL: cut with no margin of cells round the window, it is not).
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import torch  # noqa: E402

import fit  # noqa: E402
import head  # noqa: E402
import train  # noqa: E402

CHECKS = []
W, H = 200, 160


def check(fn):
    CHECKS.append(fn)
    return fn


def ok(cond, what):
    if not cond:
        raise AssertionError(what)
    print(f"    ok   {what}")


def splats_at(binds, places, sides, triangles):
    """Splats bound by [param binds], at [param places] in their frames, with sides [param sides]."""
    n = len(binds)
    turn = torch.zeros(n, 4)
    turn[:, 0] = 1.0
    return train.Splats(torch.tensor(binds), torch.tensor(places, dtype=torch.float32),
                        torch.log(torch.tensor(sides, dtype=torch.float32)), turn, torch.zeros(n, 3),
                        torch.zeros(n), triangles)


@check
def never_needles():
    T = 4
    s = splats_at([T + 1, T + 1, 0, T], [[0, 0, 0]] * 4,
                  [[30.0, 2.0, 0.5], [9.0, 2.0, 0.5], [30.0, 2.0, 0.5], [0.1, 40.0, 1.0]], T)
    before = torch.exp(s.p["log_scale"].data.clone())
    ok(float(before[0, 0] / before[0, 1]) > fit.FIT_LONG, "CONTROL: the body's needle stands %.0f to 1"
       % float(before[0, 0] / before[0, 1]))
    body = s.bind > T
    fit.not_needles(s, body)
    after = torch.exp(s.p["log_scale"].data)
    ok(abs(float(after[0, 0] / after[0, 1]) - fit.FIT_LONG) < 1e-4,
       "the body's needle is cut to %.1f times its next side" % float(after[0, 0] / after[0, 1]))
    ok(torch.allclose(after[0, 1:], before[0, 1:]), "and its other sides are kept")
    s2 = splats_at([T + 1], [[0, 0, 0]], [[5.0, 1.0, 0.5]], T)
    fit.not_needles(s2, s2.bind > T)
    ok(torch.allclose(torch.exp(s2.p["log_scale"].data), torch.tensor([[5.0, 1.0, 0.5]])),
       "a body splat within %.0f to 1 is as it was" % fit.FIT_LONG)
    ok(torch.allclose(after[2:], before[2:]), "the head's and the face's are as they were, however long")


class _Data:
    """A frame of W x H with nothing but what `astray` reads."""
    W, H = W, H

    def __init__(self, k):
        self.expr = torch.zeros((1, k))


class _Rig:
    """A face of 478 points in a box at (80..120, 40..90), its mouth at (100, 80); every frame at the origin."""

    def __init__(self, triangles, bones):
        self.T = triangles
        self.n = triangles + 1 + bones
        v = torch.zeros(478, 3)
        a = torch.linspace(0, 2 * math.pi, 478)
        v[:, 0] = 100 + 20 * torch.cos(a)
        v[:, 1] = 65 + 25 * torch.sin(a)
        v[61] = torch.tensor([92.0, 80.0, 0.0])
        v[291] = torch.tensor([108.0, 80.0, 0.0])
        self.verts = v

    def frames(self, data, i, tracked=True):
        return torch.zeros(self.n, 3), torch.eye(3).repeat(self.n, 1, 1), torch.ones(self.n), self.verts


@check
def the_heads_splats_past_its_reach():
    T, B = 3, 2
    rig = _Rig(T, B)
    data = _Data(train.EXPRESSIONS)
    # the head's: in the face, on the hair, over the chest, far right, off the picture; a face's in the face;
    # a body splat where the chest one is
    places = [[100, 60, 0], [100, 25, 0], [100, 150, 0], [190, 40, 0], [-30, 60, 0], [104, 70, 0], [100, 150, 0]]
    binds = [T, T, T, T, T, 0, T + 1]
    s = splats_at(binds, places, [[1.0, 1.0, 1.0]] * len(binds), T)
    region = train.head_region(data, rig.verts)
    ok(0.01 < float(region.float().mean()) < 0.5, "CONTROL: the head's region is %.0f%% of the picture"
       % (100 * float(region.float().mean())))
    far = train.astray(s, rig, data, 0).tolist()
    ok(far[:5] == [False, False, True, True, True], "the head's over the chest, far off and off the picture are "
       "astray, the ones in the face and the hair are not: %s" % far[:5])
    ok(not far[5], "a face's splat in the face is not astray")
    ok(not far[6], "a body splat where an astray one stands is not")


@check
def the_still_is_one_more_frame():
    torch.manual_seed(0)
    V, K, B, N = 480, 3, 2, 5
    rig = object.__new__(train.Rig)
    canon = torch.randn(V, 3)
    basis = torch.randn(52, V, 3) * 0.1
    derived = torch.softmax(torch.randn(V - 478, 478), -1)
    shift = torch.randn(V - 478, 3)
    canon[478:] = derived @ canon[:478] + shift
    basis[:, 478:] = torch.einsum("dv,kvc->kdc", derived, basis[:, :478])
    rig.canon, rig.basis, rig.derived, rig.derived_shift = canon, basis, derived, shift
    rig.tris = torch.tensor([[0, 1, 2], [2, 3, 4]])
    rig.T = 2
    data = object.__new__(train.Frames)
    data.device = torch.device("cpu")
    data.aligned = torch.randn(N, 478, 3)
    data.blend, data.scale, data.rot, data.shift = torch.rand(N, 52), torch.ones(N), torch.eye(3).repeat(N, 1, 1), torch.zeros(N, 3)
    data.expr = torch.zeros(N, K)
    data.expr_mean = torch.rand(52).double().numpy()
    data.expr_basis = torch.randn(52, K).double().numpy()
    data.expr_scale = (torch.rand(K) + 0.5).double().numpy()
    data.bone_origin, data.bone_axes = torch.zeros(N, B, 3), torch.eye(3).repeat(N, B, 1, 1)
    data.bone_unit, data.bone_seen = torch.ones(N, B), torch.ones(N, B)
    c, s_ = math.cos(0.5), math.sin(0.5)
    axes = torch.tensor([[c, -s_, 0.0], [s_, c, 0.0], [0.0, 0.0, 1.0]])   # columns: x, y, z of the bone
    ok(not torch.allclose(axes, axes.T), "CONTROL: the bone's axes are no symmetric matrix")
    blend = torch.rand(52)
    rot = torch.tensor([[0.0, -1.0, 0.0], [1.0, 0.0, 0.0], [0.0, 0.0, 1.0]])
    row = {"scale": 2.0, "rot": rot.tolist(), "shift": [10.0, 20.0, 3.0], "blend": blend.tolist(),
           "bones": [{"origin": [1.0, 2.0, 3.0], "axes": axes.T.tolist(), "unit": 7.0, "seen": 0.9},
                     {"origin": [4.0, 5.0, 6.0], "axes": torch.eye(3).tolist(), "unit": 2.0, "seen": 0.1}]}
    i = fit.as_frame(data, rig, row)
    ok(i == N and data.blend.shape[0] == N + 1 and data.aligned.shape[0] == N + 1 and data.bone_axes.shape[0] == N + 1,
       "the still is frame %d, after the %d" % (i, N))
    ok(float(data.scale[i]) == 2.0 and torch.allclose(data.rot[i], rot) and torch.allclose(data.shift[i], torch.tensor([10.0, 20.0, 3.0])),
       "its head's pose is the row's")
    ok(torch.allclose(data.bone_axes[i, 0], axes), "a bone's axes are read as columns")
    ok(torch.allclose(data.bone_origin[i, 1], torch.tensor([4.0, 5.0, 6.0])) and float(data.bone_unit[i, 0]) == 7.0
       and abs(float(data.bone_seen[i, 1]) - 0.1) < 1e-6, "and its places, units and how surely each is seen")
    want = (blend.double().numpy() - data.expr_mean) @ data.expr_basis / data.expr_scale
    ok(torch.allclose(data.expr[i].double(), torch.tensor(want), atol=1e-5), "its expression is its scores' components")
    tracked = train.Rig.face(rig, data, i, tracked=True)
    played = train.Rig.face(rig, data, i, tracked=False)
    ok(torch.allclose(tracked, played, atol=1e-4), "tracked and played, its face is the same (largest gap %.1e)"
       % float((tracked - played).abs().max()))


def a_wall_and_a_person(n=20, hair=0):
    """[param n] frames of a person (a box, its middle never leaving one place) moving over a wall (a ramp with a
    dark frame on it): (pictures, people, wall, middle) - the person red, their mask, the wall alone, and the
    box that never leaves; [param hair] paints them that many pixels past their mask."""
    import numpy as np
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    wall = np.stack([40 + xx * 0.6, 60 + yy * 0.5, 90 + (xx + yy) * 0.2], -1)
    wall[30:34, 20:180] = 20.0
    wall = wall.clip(0, 255).astype(np.uint8)
    pictures, people = [], []
    for k in range(n):
        x0 = 60 + (k % 5) * 12
        y0 = 40 + (k % 3) * 8
        pic, mask = wall.copy(), np.zeros((H, W), np.uint8)
        mask[y0:y0 + 70, x0:x0 + 60] = 255
        pic[max(0, y0 - hair):y0 + 70 + hair, max(0, x0 - hair):x0 + 60 + hair] = (230, 30, 30)
        pictures.append(pic)
        people.append(mask)
    return pictures, people, wall, (slice(56, 110), slice(108, 120))


@check
def the_room_is_the_wall_the_frames_show():
    import numpy as np
    pictures, people, wall, (ys, xs) = a_wall_and_a_person()
    plate, seen = train.room_of(pictures, people, "cpu")
    plate = plate.numpy() * 255.0
    seen = seen.numpy()
    shown = seen > 0
    ok(shown.mean() > 0.5 and not shown.all(), "some of the wall is shown and some never is (%.0f%% shown)"
       % (100 * shown.mean()))
    ok(np.abs(plate[shown] - wall[shown]).max() < 1.0, "where frames show the wall, the plate is the wall")
    ok(not shown[ys, xs].any() and seen[ys, xs].max() == 0.0, "where they always stand, nothing is seen")
    red = plate[..., 0] - plate[..., 1]
    ok(red[ys, xs].max() < red[shown].max() + 5.0, "nothing of them is in the plate where they always stand "
       "(redness at most %.0f there)" % red[ys, xs].max())
    as_is = np.median(np.stack(pictures).astype(np.float32), 0)
    ok((as_is[..., 0] - as_is[..., 1])[ys, xs].min() > 150.0, "CONTROL: the frames' median as they are holds them")
    ok(seen[0, 0] == 1.0, "a corner every frame shows is seen in full")


@check
def their_hair_past_the_mask_is_left_out():
    pictures, people, wall, _m = a_wall_and_a_person(hair=4)

    def off():
        plate, seen = train.room_of(pictures, people, "cpu")
        shown = seen > 0
        return float((plate * 255.0 - torch.as_tensor(wall).float())[shown].abs().max())
    gap = off()
    ok(gap < 1.0, "hair painted 4 px past the mask is not in the plate (at most %.1f off the wall)" % gap)
    keep = train.PLATE_GROW
    try:
        train.PLATE_GROW = 0
        gap = off()
    finally:
        train.PLATE_GROW = keep
    ok(gap > 100.0, "CONTROL: with no margin it is (%.0f off the wall)" % gap)


@check
def filled_from_round_it():
    yy, xx = torch.meshgrid(torch.arange(H, dtype=torch.float32), torch.arange(W, dtype=torch.float32), indexing="ij")
    ramp = torch.stack([xx / W, yy / H, (xx + yy) / (W + H)], -1)
    known = torch.ones(H, W)
    known[50:90, 70:130] = 0.0
    holed = ramp * known[..., None]
    out = train.fill_round(holed, known)
    ok(torch.equal(out[known > 0], ramp[known > 0]), "the known pixels are kept exactly")
    gap = (out - ramp)[known == 0].abs()
    ok(float(gap.mean()) < 0.04 and float(gap.max()) < 0.15, "the hole is filled close to the ramp (%.3f off on the "
       "mean, %.3f at most)" % (float(gap.mean()), float(gap.max())))
    ok(float((holed - ramp)[known == 0].abs().max()) > 0.3, "CONTROL: the hole as it was is far from it")


@check
def the_plate_moves_only_where_it_is_seen():
    class Data:
        blend = torch.zeros(3, 52)
    plate0 = torch.full((H, W, 3), 0.5)
    seen = torch.zeros(H, W)
    seen[:, : W // 2] = 1.0
    scene = train.Scene(Data(), "cpu", plate0, seen)
    with torch.no_grad():
        scene.moved.fill_(0.25)
    moved = scene.plate()
    ok(torch.equal(moved[:, W // 2:], plate0[:, W // 2:]), "moved everywhere, the plate where nothing showed it "
       "is where it started")
    ok(torch.allclose(moved[:, : W // 2], plate0[:, : W // 2] + 0.25), "CONTROL: where it is seen, it moved")
    scene.moved.grad = None
    scene.behind(0, 0, 0, W, H).sum().backward()
    ok(float(scene.moved.grad[:, W // 2:].abs().max()) == 0.0, "no pull reaches it where it is unseen")


def last_reset(steps, until):
    """The last step a run of [param steps] made every splat faint at, growing until [param until]; 0 for none."""
    return max([s for s in range(train.OPACITY_RESET, steps + 1, train.OPACITY_RESET) if s < until], default=0)


@check
def a_run_ends_well_past_its_last_reset():
    for steps in (3000, 4500, 9000, 12000, 15000, 30000, 60000, 100000):
        tail = steps - last_reset(steps, train.until_of(steps))
        ok(tail * 3 >= steps, "%d steps: %d after the last reset" % (steps, tail))
    ok(train.until_of(30000) == train.DENSIFY_UNTIL, "the default run grows until %d, as before" % train.DENSIFY_UNTIL)
    ok(12000 - last_reset(12000, train.DENSIFY_UNTIL) == 0, "CONTROL: growing until %d, 12,000 steps end on a reset"
       % train.DENSIFY_UNTIL)


def videos_of(counts, root):
    """A rig over one folder a video, video k with [param counts][k] moments, as head_frames.py and rig.py write
    them (a mask file each, the points and poses zero); its path."""
    import json
    import numpy as np
    folders, video = [], []
    for v, n in enumerate(counts):
        d = root / ("v%d" % v) / "head"
        (d / "mask").mkdir(parents=True)
        (d / "spec.json").write_text(json.dumps({"crop": [0, 0, W, H]}))
        np.savez(d / "frames.npz", points=np.zeros((n, 478, 3), np.float32))
        for k in range(n):
            (d / "mask" / ("%05d.png" % k)).write_bytes(b"")
        folders.append(str(d))
        video += [v] * n
    n, B = len(video), 9
    g = np.random.default_rng(0)
    path = root / "rig.npz"
    np.savez(path, folders=np.asarray(folders), video=np.asarray(video, np.int32), keep=np.ones(n, bool),
             blend=g.random((n, 52)).astype(np.float32), scale=np.ones(n, np.float32),
             rot=np.tile(np.eye(3, dtype=np.float32), (n, 1, 1)), shift=np.zeros((n, 3), np.float32),
             aligned=np.zeros((n, 478, 3), np.float32), bone_origin=np.zeros((n, B, 3), np.float32),
             bone_axes=np.tile(np.eye(3, dtype=np.float32), (n, B, 1, 1)), bone_unit=np.ones((n, B), np.float32),
             bone_seen=np.ones((n, B), np.float32))
    return str(path)


@check
def a_video_with_too_few_moments_is_left_out_of_the_head():
    import tempfile
    from pathlib import Path
    counts = [30, 25, 3, 1, 0]
    with tempfile.TemporaryDirectory() as tmp:
        rig = videos_of(counts, Path(tmp))
        data = head.Footage(rig, "cpu")
        ok(data.used == [0, 1] and data.left_out == {2: 3, 3: 1, 4: 0}, "of %s moments, those under %d are left out "
           "(%s)" % (counts, head.LEAST, data.left_out))
        of = lambda frames: set(int(v) for v in data.video[frames])
        ok(of(data.train) == {0, 1} and of(data.held) == {0, 1}, "none of theirs is learned from or held out, "
           "and each other video has some of each")
        codes = [torch.nn.Parameter(torch.full((head.LOOKS,), float(v))) for v in range(len(counts))]
        looks = head.looks_of(codes, data)
        ok(torch.allclose(looks[2], torch.full((head.LOOKS,), 0.5)) and torch.equal(looks[1], codes[1].data),
           "a left-out video's code is the others' mean, theirs their own")
        keep = head.LEAST
        try:
            head.LEAST = 0
            bare = head.Footage(rig, "cpu")
        finally:
            head.LEAST = keep
        ok(3 in of(bare.held) and 3 not in of(bare.train), "CONTROL: with no floor, the video of one moment has it "
           "held out and none to learn from")
        # THE HEAD VIDEOS: only those named are learned from, the rest taking the mean look
        some = head.Footage(rig, "cpu", {"v1", "v2"})
        ok(some.used == [1] and some.unchosen == [0] and of(some.train) == {1} and 2 in some.left_out,
           "named v1 and v2, it learns from %s, leaves %s unchosen (v2 too few)" % (some.used, some.unchosen))
        ok(torch.equal(head.looks_of(codes, some)[0], codes[1].data), "an unchosen video's code is the others' mean")
        ok(head.Footage(rig, "cpu").unchosen == [], "CONTROL: with none named, none is left unchosen")


@check
def a_room_is_kept_small():
    import torch.nn.functional as F

    class Data:
        blend = torch.zeros(2, 52)
    Hh, Ww = 161, 203
    g = torch.Generator().manual_seed(3)
    plate = torch.rand((Hh, Ww, 3), generator=g)
    rooms = head.Rooms(Data(), "cpu", [head.stored(plate)], [head.stored(torch.ones(Hh, Ww))])
    ok(torch.allclose(rooms.plate(0), plate, atol=0.5 / 255 + 1e-6), "with no move the plate is the plate kept")
    with torch.no_grad():
        rooms.moved[0].copy_(torch.rand(rooms.moved[0].shape, generator=g))
    k = head.ROOM_COARSE
    whole = F.interpolate(rooms.moved[0].detach().permute(2, 0, 1)[None], scale_factor=k, mode="bilinear",
                          align_corners=False)[0].permute(1, 2, 0)
    windows = [(0, 0, 64, 64), (1, 3, 37, 29), (Ww - 50, Hh - 41, 50, 41), (77, 90, 101, 71), (0, 0, Ww, Hh)]
    worst = max(float((rooms.move(0, *w) - whole[w[1]:w[1] + w[3], w[0]:w[0] + w[2]]).abs().max()) for w in windows)
    ok(worst < 1e-5, "over any window the move is the whole move's upsampling cut to it (%.2g)" % worst)
    wx, wy, w, h = 77, 90, 101, 71
    bare = F.interpolate(rooms.moved[0].detach()[wy // k:(wy + h) // k + 1, wx // k:(wx + w) // k + 1]
                         .permute(2, 0, 1)[None], scale_factor=k, mode="bilinear", align_corners=False)[0].permute(1, 2, 0)
    bare = bare[wy - k * (wy // k):wy - k * (wy // k) + h, wx - k * (wx // k):wx - k * (wx // k) + w]
    ok(float((bare - whole[wy:wy + h, wx:wx + w]).abs().max()) > 1e-3, "CONTROL: cut with no margin, it is not")


def main() -> int:
    failed = 0
    for fn in CHECKS:
        print(f"\n{fn.__name__}")
        try:
            fn()
        except AssertionError as exc:
            failed += 1
            print(f"    FAIL {exc}")
    print(f"\n{len(CHECKS) - failed}/{len(CHECKS)} checks passed")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
