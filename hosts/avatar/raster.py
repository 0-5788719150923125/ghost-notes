#!/usr/bin/env python3
"""raster.py - splats drawn and taught: a differentiable rasterizer of 2D Gaussians in Triton, the renderer
an actor's head of splats is trained through (next/likeness.md, "A head of splats").

    import raster
    means2d, conics, depth, radii = raster.project(means3d, scales, rotations)
    image, alpha = raster.rasterize(means2d, conics, colors, opacities, depth, radii, H, W, background)

ONE FIXED CAMERA, FAR AWAY: the frames are a locked camera's and a head is small against its distance, so
the projection is orthographic and everything is in image pixels - x right, y down, z the depth (smaller
is nearer), a pixel (px, py) sampled at its center (px + 0.5, py + 0.5).

THE RULES, so another renderer (the app's compute shader) draws the same picture. All float32, and every
product and sum rounded on its own: the kernels are compiled without fused multiply-adds, and a shader
must say `precise` to match.
- project: q = rotation / |rotation|, R its matrix, M = R diag(s); Sigma2 = (M M^T)[:2, :2] + 0.3 I, as
  (a, b, c) = (a0 + 0.3, b, c0 + 0.3); det = d0 + 0.3 (a0 + c0) + 0.09, where d0 = s1^2 s2^2 R20^2 +
  s0^2 s2^2 R21^2 + s0^2 s1^2 R22^2 is det((M M^T)[:2, :2]) by Cauchy-Binet; conic = (c / det, -b / det,
  a / det); radius = ceil(3 sqrt(l)), the larger eigenvalue l = (a + c) / 2 + sqrt(((a - c) / 2)^2 + b^2).
- Tiles are 16 x 16 pixels, ceil(W / 16) to a row, numbered row by row. A splat's box is the pixels whose
  centers lie within its radius of its mean on both axes, in the image: x0 = ceil(mx - (r + 0.5)),
  x1 = floor(mx + (r - 0.5)), clipped to [0, W - 1], and y likewise. It is binned to every tile of that
  box (x0 // 16 to x1 // 16, by y0 // 16 to y1 // 16), and to none when the box is empty, its radius is 0
  or its mean is not finite. A tile's splats are taken nearest first: by depth, ties by index.
- Each pixel of a tile, its center (cx, cy), T = 1 and C = 0 to begin, takes the tile's splats in order:
  dx = cx - mx, dy = cy - my; power = -0.5 * (((a dx) dx + ((2 b) dx) dy) + (c dy) dy);
  alpha = min(0.99, o exp(power)). The splat is passed over unless power <= 0 and alpha >= 1/255. Else
  test = T (1 - alpha): below 1e-4 the pixel is done and this splat is not added; otherwise
  C += (alpha T) color and T = test. The three constants are float32's nearest to 1/255, 0.99 and 1e-4.
- image = C + T background, alpha = 1 - T.
Only exp is not exact: here it is CUDA's expf (libdevice's, the same bits as torch.exp), and a shader's
exp may differ in its last bits - enough, on a knife edge, to pass over a splat this keeps.

THE BACKWARD IS 3DGS'S: each pixel walks back from its last contributor (`n`, saved with the final T),
dividing T back out and carrying the color of what lies behind, and each splat's gradient is summed over
the tile's 256 pixels and added atomically. Two departures: no gradient goes through alpha where the 0.99
clamp holds (3DGS lets one through), and b is the conic's off-diagonal counted twice in the form, so
dpower/db = -dx dy (3DGS keeps half that for its own symmetric convention).

THE SUMS ARE IN NO FIXED ORDER: a splat's gradient is added by every tile it touches, in whatever order the
tiles finish, so its last bits differ from run to run. A forward is the same every time.

`reference` composites the same splats densely in plain torch, for the tests: a table of every pixel
against every splat, so small sizes only.
"""

from __future__ import annotations

import torch
import triton
import triton.language as tl
from triton.language.extra import libdevice

TILE = 16
# 3DGS's low-pass: every splat at least about a pixel wide, so none falls between pixel centers.
LOW_PASS = 0.3
# The compositing's thresholds as float32 values, since the kernels compare in float32.
ALPHA_MIN = torch.tensor(1.0 / 255.0, dtype=torch.float32).item()
ALPHA_MAX = torch.tensor(0.99, dtype=torch.float32).item()
T_MIN = torch.tensor(1e-4, dtype=torch.float32).item()
# A splat's packed row: mean x, y; conic a, b, c; opacity; color r, g, b.
ROW = 9
# Two warps to a tile, four pixels a thread: measured against one, four and eight, the backward's nine
# sums a splat cost least across two.
WARPS = 2


def project(means3d: torch.Tensor, scales: torch.Tensor, rotations: torch.Tensor):
    """3D Gaussians to the image's 2D ones, orthographically: (means2d [N, 2], conics [N, 3], depth [N],
    radii [N] int32). Differentiable in all three inputs (radii aside); any float dtype."""
    q = rotations / rotations.norm(dim=-1, keepdim=True)
    w, x, y, z = q.unbind(-1)
    # Only R's first two rows reach the image: Sigma2 = (R diag(s))[:2] (R diag(s))[:2]^T.
    r0 = torch.stack([1 - 2 * (y * y + z * z), 2 * (x * y - w * z), 2 * (x * z + w * y)], -1) * scales
    r1 = torch.stack([2 * (x * y + w * z), 1 - 2 * (x * x + z * z), 2 * (y * z - w * x)], -1) * scales
    r2 = torch.stack([2 * (x * z - w * y), 2 * (y * z + w * x), 1 - 2 * (x * x + y * y)], -1)
    a0 = (r0 * r0).sum(-1)
    c0 = (r1 * r1).sum(-1)
    a = a0 + LOW_PASS
    b = (r0 * r1).sum(-1)
    c = c0 + LOW_PASS
    # a c - b b cancels to nothing for a thin splat (float32 kept 1e-4 of it); by Cauchy-Binet, with row 0
    # x row 1 = row 2, the same determinant is a sum of positive terms.
    s2 = scales * scales
    det0 = (s2[:, 1] * s2[:, 2] * r2[:, 0] * r2[:, 0] + s2[:, 0] * s2[:, 2] * r2[:, 1] * r2[:, 1]
            + s2[:, 0] * s2[:, 1] * r2[:, 2] * r2[:, 2])
    det = det0 + LOW_PASS * (a0 + c0) + LOW_PASS * LOW_PASS
    conics = torch.stack([c / det, -b / det, a / det], -1)
    with torch.no_grad():
        big = 0.5 * (a + c) + torch.sqrt(0.25 * (a - c) * (a - c) + b * b)
        radii = torch.ceil(3.0 * torch.sqrt(big)).to(torch.int32)
    return means3d[:, :2], conics, means3d[:, 2], radii


def tile_rects(means2d: torch.Tensor, radii: torch.Tensor, H: int, W: int):
    """Each splat's tiles as inclusive ranges (tx0, tx1, ty0, ty1), int64; all four make an empty range
    (tx1 = tx0 - 1, ty1 = ty0 - 1) when its box is. The binning and the reference both take this, so the
    two cut alike."""
    m = means2d.detach().float()
    r = radii.to(torch.float32)[:, None]
    good = (radii > 0) & (m.abs() < float("inf")).all(-1)
    m = torch.where(good[:, None], m, torch.zeros_like(m))
    size = torch.tensor([W, H], dtype=torch.float32, device=m.device)
    # Clamped while still float: a mean far off the image would overflow the integer.
    lo = torch.clamp(torch.ceil(m - (r + 0.5)), min=torch.zeros_like(size), max=size).long()
    hi = torch.clamp(torch.floor(m + (r - 0.5)), min=-torch.ones_like(size), max=size - 1).long()
    inside = good & (lo <= hi).all(-1)
    lo = lo // TILE
    hi = torch.where(inside[:, None], hi // TILE, lo - 1)
    return lo[:, 0], hi[:, 0], lo[:, 1], hi[:, 1]


def bin_tiles(means2d: torch.Tensor, depth: torch.Tensor, radii: torch.Tensor, H: int, W: int):
    """(ids [M] int32, ranges [tiles, 2] int32): the splats of every tile it touches, tile by tile and
    nearest first within one, and each tile's [start, end) in that list."""
    dev = means2d.device
    tiles_x, tiles_y = -(-W // TILE), -(-H // TILE)
    n = means2d.shape[0]
    x0, x1, y0, y1 = tile_rects(means2d, radii, H, W)
    nx = x1 - x0 + 1
    count = nx * (y1 - y0 + 1)
    total = int(count.sum())
    if total == 0:
        return (torch.zeros(1, dtype=torch.int32, device=dev),
                torch.zeros(tiles_x * tiles_y, 2, dtype=torch.int32, device=dev))
    # The depth order is a rank, so a key is the tile above 32 bits and the rank below: one sort.
    rank = torch.empty(n, dtype=torch.int64, device=dev)
    rank[torch.sort(depth.detach(), stable=True).indices] = torch.arange(n, device=dev)
    gid = torch.repeat_interleave(torch.arange(n, device=dev), count, output_size=total)
    # What each pair needs of its splat, gathered at once: its first pair, its box's width and corner, its rank.
    per = torch.stack([torch.cumsum(count, 0) - count, nx, x0, y0, rank], 1)
    first, wide, left, top, order = per[gid].unbind(1)
    local = torch.arange(total, device=dev) - first
    key, perm = torch.sort((((top + local // wide) * tiles_x + left + local % wide) << 32) | order)
    ids = gid[perm].to(torch.int32)
    edges = torch.searchsorted(key, torch.arange(tiles_x * tiles_y + 1, device=dev) << 32).to(torch.int32)
    return ids, torch.stack([edges[:-1], edges[1:]], 1).contiguous()


@triton.jit
def _forward(rows, ids, ranges, out_c, out_t, out_n, H, W, tiles_x, alpha_min, alpha_max, t_min,
             ROW: tl.constexpr, TILE: tl.constexpr):
    tile = tl.program_id(0)
    k = tl.arange(0, TILE * TILE)
    px = (tile % tiles_x) * TILE + k % TILE
    py = (tile // tiles_x) * TILE + k // TILE
    inside = (px < W) & (py < H)
    cx = px.to(tl.float32) + 0.5
    cy = py.to(tl.float32) + 0.5
    start = tl.load(ranges + 2 * tile)
    end = tl.load(ranges + 2 * tile + 1)
    t = tl.full([TILE * TILE], 1.0, tl.float32)
    c0 = tl.zeros([TILE * TILE], tl.float32)
    c1 = tl.zeros([TILE * TILE], tl.float32)
    c2 = tl.zeros([TILE * TILE], tl.float32)
    n = tl.zeros([TILE * TILE], tl.int32)
    live = inside
    j = start
    go = j < end
    while go:
        p = rows + tl.load(ids + j).to(tl.int64) * ROW
        mx = tl.load(p)
        my = tl.load(p + 1)
        a = tl.load(p + 2)
        b = tl.load(p + 3)
        c = tl.load(p + 4)
        o = tl.load(p + 5)
        dx = cx - mx
        dy = cy - my
        power = -0.5 * (a * dx * dx + 2.0 * b * dx * dy + c * dy * dy)
        alpha = tl.minimum(o * libdevice.exp(power), alpha_max)
        use = live & (power <= 0.0) & (alpha >= alpha_min)
        test = t * (1.0 - alpha)
        done = use & (test < t_min)
        live = live & ~done
        use = use & ~done
        w = alpha * t
        c0 = tl.where(use, c0 + w * tl.load(p + 6), c0)
        c1 = tl.where(use, c1 + w * tl.load(p + 7), c1)
        c2 = tl.where(use, c2 + w * tl.load(p + 8), c2)
        t = tl.where(use, test, t)
        n = tl.where(use, j - start + 1, n)
        j += 1
        # The tile stops early once every pixel in it is done.
        go = (j < end) & (tl.max(live.to(tl.int32), axis=0) > 0)
    pix = py * W + px
    tl.store(out_c + 3 * pix, c0, mask=inside)
    tl.store(out_c + 3 * pix + 1, c1, mask=inside)
    tl.store(out_c + 3 * pix + 2, c2, mask=inside)
    tl.store(out_t + pix, t, mask=inside)
    tl.store(out_n + pix, n, mask=inside)


@triton.jit
def _backward(rows, ids, ranges, final_t, counts, grad_c, grad_t, grads, H, W, tiles_x, alpha_min,
              alpha_max, ROW: tl.constexpr, TILE: tl.constexpr):
    tile = tl.program_id(0)
    k = tl.arange(0, TILE * TILE)
    px = (tile % tiles_x) * TILE + k % TILE
    py = (tile // tiles_x) * TILE + k // TILE
    inside = (px < W) & (py < H)
    cx = px.to(tl.float32) + 0.5
    cy = py.to(tl.float32) + 0.5
    start = tl.load(ranges + 2 * tile)
    pix = py * W + px
    n = tl.load(counts + pix, mask=inside, other=0)
    tf = tl.load(final_t + pix, mask=inside, other=1.0)
    g0 = tl.load(grad_c + 3 * pix, mask=inside, other=0.0)
    g1 = tl.load(grad_c + 3 * pix + 1, mask=inside, other=0.0)
    g2 = tl.load(grad_c + 3 * pix + 2, mask=inside, other=0.0)
    gt = tl.load(grad_t + pix, mask=inside, other=0.0)
    t = tf
    # The color of everything behind the splat at hand, as seen through it (3DGS's accum_rec).
    s0 = tl.zeros([TILE * TILE], tl.float32)
    s1 = tl.zeros([TILE * TILE], tl.float32)
    s2 = tl.zeros([TILE * TILE], tl.float32)
    la = tl.zeros([TILE * TILE], tl.float32)
    l0 = tl.zeros([TILE * TILE], tl.float32)
    l1 = tl.zeros([TILE * TILE], tl.float32)
    l2 = tl.zeros([TILE * TILE], tl.float32)
    top = tl.max(n, axis=0)
    for i in range(0, top):
        jl = top - 1 - i
        gid = tl.load(ids + start + jl).to(tl.int64)
        p = rows + gid * ROW
        mx = tl.load(p)
        my = tl.load(p + 1)
        a = tl.load(p + 2)
        b = tl.load(p + 3)
        c = tl.load(p + 4)
        o = tl.load(p + 5)
        r = tl.load(p + 6)
        g = tl.load(p + 7)
        bl = tl.load(p + 8)
        dx = cx - mx
        dy = cy - my
        power = -0.5 * (a * dx * dx + 2.0 * b * dx * dy + c * dy * dy)
        gauss = libdevice.exp(power)
        raw = o * gauss
        alpha = tl.minimum(raw, alpha_max)
        # The forward's own test, so the same splats count; past n, the pixel was done.
        use = (jl < n) & (power <= 0.0) & (alpha >= alpha_min)
        keep = 1.0 - alpha
        t = tl.where(use, t / keep, t)
        s0 = tl.where(use, la * l0 + (1.0 - la) * s0, s0)
        s1 = tl.where(use, la * l1 + (1.0 - la) * s1, s1)
        s2 = tl.where(use, la * l2 + (1.0 - la) * s2, s2)
        dalpha = t * ((r - s0) * g0 + (g - s1) * g1 + (bl - s2) * g2) - tf / keep * gt
        w = alpha * t
        # Where the clamp holds, alpha is 0.99 whatever the splat: nothing flows back through it.
        free = use & (raw <= alpha_max)
        dpow = tl.where(free, dalpha * alpha, 0.0)
        if tl.max(use.to(tl.int32), axis=0) > 0:
            q = grads + gid * ROW
            tl.atomic_add(q, tl.sum(dpow * (a * dx + b * dy), axis=0), sem="relaxed")
            tl.atomic_add(q + 1, tl.sum(dpow * (b * dx + c * dy), axis=0), sem="relaxed")
            tl.atomic_add(q + 2, tl.sum(dpow * (-0.5 * dx * dx), axis=0), sem="relaxed")
            tl.atomic_add(q + 3, tl.sum(dpow * (-dx * dy), axis=0), sem="relaxed")
            tl.atomic_add(q + 4, tl.sum(dpow * (-0.5 * dy * dy), axis=0), sem="relaxed")
            tl.atomic_add(q + 5, tl.sum(tl.where(free, dalpha * gauss, 0.0), axis=0), sem="relaxed")
            tl.atomic_add(q + 6, tl.sum(tl.where(use, w * g0, 0.0), axis=0), sem="relaxed")
            tl.atomic_add(q + 7, tl.sum(tl.where(use, w * g1, 0.0), axis=0), sem="relaxed")
            tl.atomic_add(q + 8, tl.sum(tl.where(use, w * g2, 0.0), axis=0), sem="relaxed")
        la = tl.where(use, alpha, la)
        l0 = tl.where(use, r, l0)
        l1 = tl.where(use, g, l1)
        l2 = tl.where(use, bl, l2)


class Rasterize(torch.autograd.Function):
    """The splats composited, without the background: (C [H, W, 3], T [H, W]). Differentiable in means2d,
    conics, colors and opacities; depth and radii only order and cut."""

    @staticmethod
    def forward(ctx, means2d, conics, colors, opacities, depth, radii, H, W):
        dev = means2d.device
        if dev.type != "cuda":
            raise ValueError("raster: the splats must be on a CUDA device")
        rows = torch.cat([means2d.detach(), conics.detach(), opacities.detach()[:, None], colors.detach()],
                         1).float().contiguous()
        ids, ranges = bin_tiles(means2d, depth, radii, H, W)
        tiles_x = -(-W // TILE)
        color = torch.empty(H, W, 3, dtype=torch.float32, device=dev)
        trans = torch.empty(H, W, dtype=torch.float32, device=dev)
        counts = torch.empty(H, W, dtype=torch.int32, device=dev)
        _forward[(ranges.shape[0],)](rows, ids, ranges, color, trans, counts, H, W, tiles_x, ALPHA_MIN,
                                     ALPHA_MAX, T_MIN, ROW=ROW, TILE=TILE, num_warps=WARPS,
                                     enable_fp_fusion=False)
        ctx.save_for_backward(rows, ids, ranges, trans, counts)
        ctx.size = (H, W)
        return color, trans

    @staticmethod
    def backward(ctx, grad_color, grad_trans):
        rows, ids, ranges, trans, counts = ctx.saved_tensors
        H, W = ctx.size
        if grad_color is None:
            grad_color = torch.zeros_like(trans)[..., None].expand(H, W, 3)
        if grad_trans is None:
            grad_trans = torch.zeros_like(trans)
        grads = torch.zeros_like(rows)
        _backward[(ranges.shape[0],)](rows, ids, ranges, trans, counts, grad_color.float().contiguous(),
                                      grad_trans.float().contiguous(), grads, H, W, -(-W // TILE), ALPHA_MIN,
                                      ALPHA_MAX, ROW=ROW, TILE=TILE, num_warps=WARPS, enable_fp_fusion=False)
        return grads[:, 0:2], grads[:, 2:5], grads[:, 6:9], grads[:, 5], None, None, None, None


def rasterize(means2d, conics, colors, opacities, depth, radii, H: int, W: int, background):
    """(image [H, W, 3], alpha [H, W]): the splats over the background ([3], or [H, W, 3]). All float32,
    on the graphics card; differentiable in means2d, conics, colors, opacities and the background."""
    for name, v in (("means2d", means2d), ("conics", conics), ("colors", colors), ("opacities", opacities),
                    ("background", background)):
        if v.dtype != torch.float32:
            raise ValueError("raster: %s must be float32, not %s" % (name, v.dtype))
    color, trans = Rasterize.apply(means2d, conics, colors, opacities, depth, radii, int(H), int(W))
    return color + trans[..., None] * background, 1.0 - trans


def reference(means2d, conics, colors, opacities, depth, radii, H: int, W: int, background):
    """`rasterize`, densely in plain torch (autograd): every pixel against every splat, under the same
    tile cut, skips, clamp and stop. Its alphas are float32 by the kernel's own steps (torch.exp is
    libdevice's expf), so the two pass over the same splats. The stop is found with float32's running
    product, as the kernel finds it: a float64 one disagrees on real knife edges - two clamped splats in
    a row leave (1 - 0.99)^2, 2e-6 under 1e-4. The compositing itself is in float64."""
    dev = means2d.device
    order = torch.sort(depth.detach(), stable=True).indices
    x0, x1, y0, y1 = (v[order] for v in tile_rects(means2d, radii, H, W))
    m, con, o, col = means2d[order], conics[order], opacities[order], colors[order]
    py, px = torch.meshgrid(torch.arange(H, device=dev), torch.arange(W, device=dev), indexing="ij")
    px, py = px.reshape(-1), py.reshape(-1)
    tx, ty = (px // TILE)[:, None], (py // TILE)[:, None]
    inrect = (tx >= x0) & (tx <= x1) & (ty >= y0) & (ty <= y1)
    dx = (px.float() + 0.5)[:, None] - m[:, 0]
    dy = (py.float() + 0.5)[:, None] - m[:, 1]
    a, b, c = con[:, 0], con[:, 1], con[:, 2]
    power = -0.5 * (a * dx * dx + 2.0 * b * dx * dy + c * dy * dy)
    alpha = torch.clamp(o * torch.exp(power), max=ALPHA_MAX)
    use = inrect & (power <= 0.0) & (alpha >= ALPHA_MIN)
    alpha = torch.where(use, alpha, torch.zeros_like(alpha))
    with torch.no_grad():
        kept = torch.zeros_like(use)
        t = torch.ones(alpha.shape[0], dtype=torch.float32, device=dev)
        live = torch.ones_like(t, dtype=torch.bool)
        for i in range(alpha.shape[1]):
            test = t * (1.0 - alpha[:, i])
            go = live & use[:, i]
            live = live & ~(go & (test < T_MIN))
            kept[:, i] = go & live
            t = torch.where(kept[:, i], test, t)
    alpha = torch.where(kept, alpha, torch.zeros_like(alpha)).double()
    if alpha.shape[1] == 0:
        trans = torch.ones(alpha.shape[0], dtype=torch.float64, device=dev)
        color = torch.zeros(alpha.shape[0], 3, dtype=torch.float64, device=dev)
    else:
        after = torch.cumprod(1.0 - alpha, 1)
        before = torch.cat([torch.ones_like(after[:, :1]), after[:, :-1]], 1)
        color = (alpha * before) @ col.double()
        trans = after[:, -1]
    bg = background.double().reshape(-1, 3) if background.dim() == 3 else background.double()
    image = color + trans[:, None] * bg
    return image.reshape(H, W, 3).float(), (1.0 - trans).reshape(H, W).float()
