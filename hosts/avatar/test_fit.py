#!/usr/bin/env python3
"""Tests for the fit of an avatar's body to its still (fit.py) and the head's reach (train.py's `astray`).

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
