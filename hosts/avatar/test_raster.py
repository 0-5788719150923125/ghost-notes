#!/usr/bin/env python3
"""Tests for the splat rasterizer (raster.py).

Run it directly with the voice-training venv's python (its torch and Triton) - no pytest needed:

    ~/.local/share/godot/app_userdata/ghost/voice_train_venv/bin/python hosts/avatar/test_raster.py

It needs a CUDA graphics card. The scenes are small and seeded; the last section times a head's worth of
splats and is not a gate.

  A SPLAT'S TILES ARE ITS BOX'S - each splat is binned to exactly the tiles holding a pixel of the image
  whose center lies within its radius on both axes, found pixel by pixel.
  THE FORWARD IS THE REFERENCE'S - on random scenes, an image size no multiple of 16, image and alpha are
  within 1e-5 of the dense reference's; the scenes hold ties in depth, splats off the image, splats of
  radius 0, pairs too faint to count, clamped ones, pixels the stop ends and tails past the tile cut. The
  two make the same decisions bit for bit (the same float32 steps, the same exp), so no scene sits on an
  edge between them (CONTROLS: nearest-last, or without the tile cut, the reference is far off).
  THE GRADIENTS ARE THE REFERENCE'S - means2d, conics, colors, opacities and the background, under a
  loss on image and alpha, against the reference's autograd (CONTROL: b's gradient halved - 3DGS's own
  convention for the conic - is caught).
  PROJECT IS THE FORMULA - conics, radii and depth against Sigma2 built from a rotation made another way
  (Rodrigues' formula from the quaternion's axis and angle) and inverted by torch.linalg; its gradients
  pass gradcheck in double precision (CONTROL: with the rotation transposed, the formula disagrees).
"""

from __future__ import annotations

import math
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import torch  # noqa: E402

import raster  # noqa: E402

CHECKS = []
DEV = "cuda"
# An image no multiple of 16 on either side, so the edge tiles are partly outside it.
H, W = 45, 67
FORWARD_TOL = 1e-5


def check(fn):
    CHECKS.append(fn)
    return fn


def ok(cond, what):
    if not cond:
        raise AssertionError(what)
    print(f"    ok   {what}")


def scene(seed, n=300, image_background=False):
    """A random scene of n splats, every rule given work: depth in whole steps (ties), a few splats well
    off the image and a few of radius 0, some fainter than 1/255 everywhere, some opaque past the clamp,
    and a tenth piled at three spots, wide and opaque, so pixels there are done before their last."""
    g = torch.Generator().manual_seed(seed)

    def u(lo, hi, *shape):
        return lo + (hi - lo) * torch.rand(*shape, generator=g)

    xy = torch.stack([u(-8.0, W + 8.0, n), u(-8.0, H + 8.0, n)], 1)
    off = torch.rand(n, generator=g) < 0.06
    xy[off, 0] = torch.where(torch.rand(int(off.sum()), generator=g) < 0.5, -60.0, W + 60.0)
    z = torch.randint(0, 40, (n,), generator=g).float()
    scales = torch.exp(u(math.log(0.3), math.log(7.0), n, 3))
    rotations = torch.randn(n, 4, generator=g)
    kind = torch.rand(n, generator=g)
    opacities = torch.where(kind < 0.12, u(0.0005, 0.0035, n),
                            torch.where(kind < 0.3, u(0.995, 1.0, n), u(0.05, 0.9, n)))
    pile = (torch.rand(n, generator=g) < 0.1) & ~off
    spots = torch.stack([u(8.0, W - 8.0, 3), u(8.0, H - 8.0, 3)], 1)
    k = int(pile.sum())
    xy[pile] = spots[torch.randint(0, 3, (k,), generator=g)] + 2.0 * torch.randn(k, 2, generator=g)
    scales[pile] = u(3.0, 8.0, k, 3)
    opacities[pile] = u(0.995, 1.0, k)
    means3d = torch.cat([xy, z[:, None]], 1)
    colors = torch.rand(n, 3, generator=g)
    means2d, conics, depth, radii = raster.project(means3d, scales, rotations)
    radii[torch.randperm(n, generator=g)[:4]] = 0
    background = torch.rand(H, W, 3, generator=g) if image_background else torch.rand(3, generator=g)
    return {"means2d": means2d.to(DEV), "conics": conics.to(DEV), "colors": colors.to(DEV),
            "opacities": opacities.to(DEV), "depth": depth.to(DEV), "radii": radii.to(DEV),
            "H": H, "W": W, "background": background.to(DEV)}


ARGS = ("means2d", "conics", "colors", "opacities", "depth", "radii", "H", "W", "background")


def call(fn, s, **change):
    return fn(*[change.get(k, s[k]) for k in ARGS])


def facts(s):
    """What a scene puts the rules to, from its pixel-by-splat table as the kernel takes it."""
    order = torch.sort(s["depth"], stable=True).indices
    x0, x1, y0, y1 = (v[order] for v in raster.tile_rects(s["means2d"], s["radii"], H, W))
    m, con, o = s["means2d"][order], s["conics"][order], s["opacities"][order]
    py, px = torch.meshgrid(torch.arange(H, device=DEV), torch.arange(W, device=DEV), indexing="ij")
    px, py = px.reshape(-1), py.reshape(-1)
    tx, ty = (px // 16)[:, None], (py // 16)[:, None]
    inrect = (tx >= x0) & (tx <= x1) & (ty >= y0) & (ty <= y1)
    dx = (px.float() + 0.5)[:, None] - m[:, 0]
    dy = (py.float() + 0.5)[:, None] - m[:, 1]
    power = -0.5 * (con[:, 0] * dx * dx + 2.0 * con[:, 1] * dx * dy + con[:, 2] * dy * dy)
    raw = o * torch.exp(power)
    alpha = torch.clamp(raw, max=raster.ALPHA_MAX)
    use = inrect & (power <= 0) & (alpha >= raster.ALPHA_MIN)
    t = torch.ones(px.shape[0], device=DEV)
    live = torch.ones_like(t, dtype=torch.bool)
    for i in range(use.shape[1]):
        test = t * (1.0 - alpha[:, i])
        go = live & use[:, i]
        live = live & ~(go & (test < raster.T_MIN))
        t = torch.where(go & live, test, t)
    rect_empty = (x0 > x1) | (y0 > y1)
    return {"ties in depth": s["depth"].numel() - torch.unique(s["depth"]).numel(),
            "splats off the image": int((rect_empty & (s["radii"][order] > 0)).sum()),
            "of radius 0": int((s["radii"] == 0).sum()),
            "fainter than 1/255": int((~rect_empty & (o < raster.ALPHA_MIN)).sum()),
            "clamped pairs": int((use & (raw > raster.ALPHA_MAX)).sum()),
            "pixels stopped": int((~live).sum()),
            "pairs past the cut": int((~inrect & (power <= 0) & (alpha >= raster.ALPHA_MIN)).sum())}


def worst(a, b):
    return float((a - b).abs().max())


@check
def a_splats_tiles_are_its_box():
    s = scene(11, n=400)
    m, r = s["means2d"], s["radii"]
    x0, x1, y0, y1 = raster.tile_rects(m, r, H, W)
    # Pixel by pixel: the image's centers within the radius on both axes, then the tiles they lie in.
    cx = torch.arange(W, device=DEV).float() + 0.5
    cy = torch.arange(H, device=DEV).float() + 0.5
    inx = (cx[None, :] - m[:, :1]).abs() <= r[:, None].float()
    iny = (cy[None, :] - m[:, 1:]).abs() <= r[:, None].float()
    tiles_x, tiles_y = -(-W // 16), -(-H // 16)
    hitx = torch.stack([inx[:, 16 * t:16 * t + 16].any(1) for t in range(tiles_x)], 1)
    hity = torch.stack([iny[:, 16 * t:16 * t + 16].any(1) for t in range(tiles_y)], 1)
    want = (hitx[:, None, :] & hity[:, :, None]) & (r > 0)[:, None, None]
    txs = torch.arange(tiles_x, device=DEV)
    tys = torch.arange(tiles_y, device=DEV)
    got = (((txs >= x0[:, None]) & (txs <= x1[:, None]))[:, None, :]
           & ((tys >= y0[:, None]) & (tys <= y1[:, None]))[:, :, None])
    ok(bool((got == want).all()), "every splat's tiles are those holding a pixel center within its radius")
    ok(bool(want.any()) and bool((~want.flatten(1).any(1) & (r > 0)).any()),
       "the splats tried include some on the image and some off it")
    ids, ranges = raster.bin_tiles(m, s["depth"], r, H, W)
    counts = ranges[:, 1] - ranges[:, 0]
    ok(int(counts.sum()) == int(got.sum()), "the binning lists each splat once in each of its tiles")
    order = torch.sort(s["depth"], stable=True).indices
    rank = torch.empty(m.shape[0], dtype=torch.int64, device=DEV)
    rank[order] = torch.arange(m.shape[0], device=DEV)
    fine = True
    for t in range(ranges.shape[0]):
        a, b = int(ranges[t, 0]), int(ranges[t, 1])
        g = ids[a:b].long()
        fine &= bool((torch.diff(rank[g]) > 0).all()) and bool(got[g, t // tiles_x, t % tiles_x].all())
    ok(fine, "each tile's list is its own splats, nearest first, ties by index")


@check
def the_forward_is_the_references():
    scenes = [scene(1), scene(2), scene(3), scene(4, image_background=True), scene(5, n=60)]
    err_i = err_a = far = uncut = 0.0
    total = {}
    for s in scenes:
        image, alpha = call(raster.rasterize, s)
        want_i, want_a = call(raster.reference, s)
        err_i = max(err_i, worst(image, want_i))
        err_a = max(err_a, worst(alpha, want_a))
        for k, v in facts(s).items():
            total[k] = total.get(k, 0) + v
        far = max(far, worst(image, call(raster.reference, s, depth=-s["depth"])[0]))
        big = torch.where(s["radii"] > 0, torch.full_like(s["radii"], 100000), s["radii"])
        uncut = max(uncut, worst(image, call(raster.reference, s, radii=big)[0]))
    ok(err_i <= FORWARD_TOL, "the image is the reference's on %d scenes of %dx%d, one over a picture "
       "(largest difference %.1e)" % (len(scenes), W, H, err_i))
    ok(err_a <= FORWARD_TOL, "and so is alpha (largest difference %.1e)" % err_a)
    ok(all(v > 0 for v in total.values()),
       "the scenes hold " + ", ".join("%s %d" % kv for kv in total.items()))
    ok(far > 1000 * FORWARD_TOL, "CONTROL: nearest-last, the reference is %.2f off (the comparison can fail)" % far)
    ok(uncut > 100 * FORWARD_TOL,
       "CONTROL: without the tile cut, the reference is %.4f off (the cut is exercised, and matched)" % uncut)
    s = dict(scenes[0])
    s["means2d"] = s["means2d"] + torch.tensor([1000.0, 0.0], device=DEV)
    image, alpha = call(raster.rasterize, s)
    ok(bool((image == s["background"]).all()) and bool((alpha == 0).all()),
       "a scene with nothing on the image is its background, alpha 0")


def grads(fn, s, w_image, w_alpha):
    leaves = {k: s[k].detach().clone().requires_grad_(True)
              for k in ("means2d", "conics", "colors", "opacities", "background")}
    image, alpha = call(fn, s, **leaves)
    loss = (image * w_image).sum() + (alpha * w_alpha).sum()
    got = torch.autograd.grad(loss, list(leaves.values()))
    return dict(zip(leaves, got))


# A gradient agrees when each entry is within RTOL of its own size, or within ATOL of its tensor's largest:
# float32 sums of up to 256 pixels a tile, in no fixed order, against autograd's float64 compositing.
RTOL, ATOL = 1e-3, 1e-5


def agree(got, want):
    scale = float(want.abs().max())
    excess = ((got - want).abs() - RTOL * want.abs()) / max(scale, 1e-30)
    return float(excess.max()) <= ATOL, float((got - want).abs().max()) / max(scale, 1e-30)


@check
def the_gradients_are_the_references():
    g = torch.Generator(device=DEV).manual_seed(9)
    total = {}
    errs = {}
    kept = None
    for s in (scene(21), scene(22, image_background=True), scene(23, n=120)):
        w_image = torch.randn(H, W, 3, generator=g, device=DEV)
        w_alpha = torch.randn(H, W, generator=g, device=DEV)
        got = grads(raster.rasterize, s, w_image, w_alpha)
        want = grads(raster.reference, s, w_image, w_alpha)
        kept = kept or (got, want)
        for k in got:
            fine, rel = agree(got[k], want[k])
            errs.setdefault(k, []).append((fine, rel))
        for k, v in facts(s).items():
            total[k] = total.get(k, 0) + v
    for k, rows in errs.items():
        ok(all(f for f, _ in rows), "d/d%s is the reference's (largest difference %.1e of its largest)"
           % (k, max(r for _, r in rows)))
    ok(total["clamped pairs"] > 0 and total["pixels stopped"] > 0 and total["fainter than 1/255"] > 0,
       "under clamped pairs (%d), stopped pixels (%d) and splats fainter than 1/255 (%d)"
       % (total["clamped pairs"], total["pixels stopped"], total["fainter than 1/255"]))
    got, want = kept
    half = got["conics"].clone()
    half[:, 1] *= 0.5
    ok(not agree(half, want["conics"])[0],
       "CONTROL: b's gradient halved (3DGS's symmetric convention) is caught, %.2f off"
       % agree(half, want["conics"])[1])


def rodrigues(q):
    """The rotation of quaternion q (w, x, y, z), by its axis and angle: another road to R."""
    q = q / q.norm(dim=-1, keepdim=True)
    v = q[:, 1:]
    s = v.norm(dim=-1)
    angle = 2.0 * torch.atan2(s, q[:, 0])
    axis = v / s[:, None]
    k = torch.zeros(q.shape[0], 3, 3, dtype=q.dtype)
    k[:, 0, 1], k[:, 0, 2], k[:, 1, 2] = -axis[:, 2], axis[:, 1], -axis[:, 0]
    k = k - k.transpose(1, 2)
    eye = torch.eye(3, dtype=q.dtype).expand_as(k)
    return eye + torch.sin(angle)[:, None, None] * k + (1.0 - torch.cos(angle))[:, None, None] * (k @ k)


def formula(means3d, scales, rotations, transpose=False):
    r = rodrigues(rotations.double())
    if transpose:
        r = r.transpose(1, 2)
    s3 = r @ torch.diag_embed(scales.double() ** 2) @ r.transpose(1, 2)
    s2 = s3[:, :2, :2] + raster.LOW_PASS * torch.eye(2, dtype=torch.float64)
    inv = torch.linalg.inv(s2)
    reach = 3.0 * torch.sqrt(torch.linalg.eigvalsh(s2)[:, -1])
    return torch.stack([inv[:, 0, 0], inv[:, 0, 1], inv[:, 1, 1]], -1), reach, means3d[:, 2].double()


@check
def project_is_the_formula():
    g = torch.Generator().manual_seed(31)
    n = 2000
    means3d = torch.randn(n, 3, generator=g) * 50
    scales = torch.exp(torch.empty(n, 3).uniform_(math.log(0.05), math.log(40.0), generator=g))
    rotations = torch.randn(n, 4, generator=g) * 3
    means2d, conics, depth, radii = raster.project(means3d, scales, rotations)
    want, reach, want_depth = formula(means3d, scales, rotations)
    rel = float(((conics.double() - want).abs() / want.abs().amax(-1, keepdim=True)).max())
    ok(rel < 1e-5, "the conics are Sigma2's inverse (largest difference %.1e of each splat's largest)" % rel)
    clear = (reach - reach.round()).abs() > 1e-4
    ok(bool((radii[clear].double() == torch.ceil(reach[clear])).all()) and int(clear.sum()) > n - 10,
       "the radii are ceil(3 sqrt(largest eigenvalue)) (%d of %d off a knife edge)" % (int(clear.sum()), n))
    ok(bool((means2d == means3d[:, :2]).all()) and bool((depth.double() == want_depth).all()),
       "the means are x, y and the depth is z")
    wrong, _, _ = formula(means3d, scales, rotations, transpose=True)
    off = float(((conics.double() - wrong).abs() / wrong.abs().amax(-1, keepdim=True)).max())
    ok(off > 1e-2, "CONTROL: with the rotation transposed, the formula is %.2f off" % off)
    tiny = (torch.randn(4, 3, dtype=torch.float64, generator=g) * 5,
            torch.rand(4, 3, dtype=torch.float64, generator=g) * 3 + 0.2,
            torch.randn(4, 4, dtype=torch.float64, generator=g))
    tiny = tuple(t.requires_grad_(True) for t in tiny)
    passed = torch.autograd.gradcheck(lambda m, s, q: raster.project(m, s, q)[:3], tiny, eps=1e-6, atol=1e-5)
    ok(passed, "project's gradients pass gradcheck in double precision")


def timing():
    """A head's worth: 100k splats in an ellipse a head fills of a 512 x 512 frame, 0.5 to 4 pixels wide."""
    n, size = 100_000, 512
    g = torch.Generator(device=DEV).manual_seed(7)
    turn = torch.rand(n, generator=g, device=DEV) * 2 * math.pi
    out = torch.sqrt(torch.rand(n, generator=g, device=DEV))
    means3d = torch.stack([256 + 180 * out * torch.cos(turn), 256 + 220 * out * torch.sin(turn),
                           torch.randn(n, generator=g, device=DEV) * 60], 1)
    scales = torch.exp(torch.rand(n, 3, generator=g, device=DEV) * math.log(8.0)) * 0.5
    rotations = torch.randn(n, 4, generator=g, device=DEV)
    means2d, conics, depth, radii = raster.project(means3d, scales, rotations)
    leaves = [means2d.detach().clone().requires_grad_(True), conics.detach().clone().requires_grad_(True),
              torch.rand(n, 3, generator=g, device=DEV).requires_grad_(True),
              (0.05 + 0.95 * torch.rand(n, generator=g, device=DEV)).requires_grad_(True)]
    background = torch.rand(3, device=DEV, requires_grad=True)
    w = torch.randn(size, size, 3, generator=g, device=DEV)
    ids, _ = raster.bin_tiles(means2d, depth, radii, size, size)

    def forward():
        return raster.rasterize(*leaves, depth, radii, size, size, background)

    def both():
        image, alpha = forward()
        ((image * w).sum() + alpha.sum()).backward()

    for _ in range(3):
        both()
    torch.cuda.synchronize()
    base = torch.cuda.memory_allocated()
    torch.cuda.reset_peak_memory_stats()

    def least(fn, runs=7):
        best = math.inf
        for _ in range(runs):
            torch.cuda.synchronize()
            t0 = time.perf_counter()
            fn()
            torch.cuda.synchronize()
            best = min(best, time.perf_counter() - t0)
        return best

    with torch.no_grad():
        t_forward = least(forward)
    t_both = least(both)
    peak = torch.cuda.max_memory_allocated() - base
    print(f"    time forward + backward: {t_both * 1000:.2f} ms (forward alone {t_forward * 1000:.2f} ms), "
          f"{n} splats at {size}x{size}, {ids.numel()} splat-tile pairs, radii {int(radii.min())} to "
          f"{int(radii.max())} (median {int(radii.median())})")
    print(f"    memory {peak / 2 ** 20:.1f} MB at the peak above the scene's own {base / 2 ** 20:.1f} MB")


def main() -> int:
    if not torch.cuda.is_available():
        print("test_raster: needs a CUDA graphics card")
        return 2
    failed = 0
    for fn in CHECKS:
        print(f"\n{fn.__name__}")
        try:
            fn()
        except AssertionError as exc:
            failed += 1
            print(f"    FAIL {exc}")
    print(f"\n{len(CHECKS) - failed}/{len(CHECKS)} checks passed")
    print("\ntiming (not a gate)")
    timing()
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
