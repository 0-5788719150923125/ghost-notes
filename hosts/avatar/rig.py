#!/usr/bin/env python3
"""rig.py - the surface an actor's head of splats is bound to, learned from their own frames (next/likeness.md,
"A head of splats").

    <face_venv python> rig.py --frames <frames folder> --out <rig.npz> [--poses <poses.json>]

MediaPipe's face mesh is the surface: its 478 points are tracked in every frame (frames.py), and its
triangles come from its own tessellation. From the frames this learns:
- THEIR NEUTRAL FACE (`canon`): every frame's points brought onto one another by a similarity (scale,
  rotation, shift) fitted on the points that move least with expression, then averaged;
- EACH FRAME'S HEAD (`scale`, `rot`, `shift`): that similarity, from the neutral face into the frame's pixels;
- HOW THEIR FACE MOVES (`basis`): the neutral face's offset at each point as a linear function of MediaPipe's
  52 expression scores, by ridge regression over every frame - what drives the head at playback, where a
  sound's mouth and a blink are those scores (visemes.json, the plan's blinks);
- THE SURFACE (`tris`): MediaPipe's triangles, with the mouth's and the eyes' holes filled - the mouth by a
  fan to a point behind the lips (where the teeth and the dark of the mouth are learned), each eye by a fan
  to its iris centre (so the eye's own splats follow the gaze).

Writes <out>: canon [V, 3], basis [52, V, 3], tris [T, 3], derived [V - 478, 478] with derived_shift
[V - 478, 3] (the points that are not MediaPipe's: a mix of its points plus a fixed offset), rigid [K]
(the points the head's pose is fitted on), and per frame: keep [N] (a frame learned from), scale [N],
rot [N, 3, 3], shift [N, 3], aligned [N, 478, 3] (its points on the neutral face's frame), blend [N, 52].

And <poses>, what the head is played from ([SplatHead], the medium): each still's pose and scores
({scale, rot (rows), shift, blend} - the head as it stands in the still, which the playing head starts from),
`rest` (their median scores: the face at ease, what a sound's mouth and a blink move from), `shut` (each
eye's score when it is closed: the top of their own blinks) and `looks` (each glance of the plan's - the 2D
library's `GLANCES`, the picture's left and right - as the 52 scores' move from their median when they look
that way most: the median of the frames whose two scores for it are in their top LOOK_SHARE, less the
median of all; the eyes' and brows' scores alone, so the lids and brows that go with it come too, and the
talking that went on while they looked does not).
"""

from __future__ import annotations

import argparse
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "face"))

import actor  # noqa: E402

# The inner edge of the lips, round (MediaPipe's numbering) - the mouth's hole.
LIPS_INNER = [78, 191, 80, 81, 82, 13, 312, 311, 310, 415, 308, 324, 318, 402, 317, 14, 87, 178, 88, 95]
# Each eye's opening, round, and its iris centre.
EYE_LEFT = [33, 246, 161, 160, 159, 158, 157, 173, 133, 155, 154, 153, 145, 144, 163, 7]
EYE_RIGHT = [263, 466, 388, 387, 386, 385, 384, 398, 362, 382, 381, 380, 374, 373, 390, 249]
IRIS_LEFT = 468
IRIS_RIGHT = 473
# How far behind the lips the mouth's back point stands, in the neutral face's units: a share of the
# distance between the mouth's corners.
MOUTH_DEPTH = 0.45
# The share of points the head's pose is fitted on: those that move least once the head is taken out.
RIGID_SHARE = 0.3
# The ridge on the expression basis: small, so a score that moves the face is followed.
RIDGE = 1e-2
# Every n-th kept frame is held out to measure the basis on.
HELD_OUT = 10
# A glance is learned from the frames looking that way most: this top share of them.
LOOK_SHARE = 0.03


def triangles():
    """MediaPipe's face triangles, read off its tessellation: every three points joined pairwise - less the few
    such triples that are not faces (an edge on more than two of them keeps the two whose third points lie
    on opposite sides of it, judged on the canonical face)."""
    from mediapipe.tasks.python import vision
    edges = set()
    for c in vision.FaceLandmarksConnections.FACE_LANDMARKS_TESSELATION:
        a, b = int(c.start), int(c.end)
        edges.add((min(a, b), max(a, b)))
    near = {}
    for a, b in edges:
        near.setdefault(a, set()).add(b)
        near.setdefault(b, set()).add(a)
    tris = set()
    for a, b in edges:
        for c in near[a] & near[b]:
            tris.add(tuple(sorted((a, b, c))))
    return sorted(tris)


def clean(tris, canon2d):
    """Drop the triples that are not faces: where an edge sits on more than two, keep the smallest triangle on
    each side of it (the faces either side of an edge are its nearest neighbours)."""
    import numpy as np
    on = {}
    for t in tris:
        for e in ((t[0], t[1]), (t[0], t[2]), (t[1], t[2])):
            on.setdefault(e, []).append(t)
    drop = set()

    def area(t):
        p = canon2d[list(t)]
        u, v = p[1] - p[0], p[2] - p[0]
        return abs(u[0] * v[1] - u[1] * v[0]) * 0.5

    for (a, b), ts in on.items():
        if len(ts) <= 2:
            continue
        d = canon2d[b] - canon2d[a]
        sides = {1: [], -1: []}
        for t in ts:
            c = [v for v in t if v not in (a, b)][0]
            w = canon2d[c] - canon2d[a]
            sides[1 if d[0] * w[1] - d[1] * w[0] > 0 else -1].append(t)
        for side in sides.values():
            side.sort(key=area)
            drop.update(side[1:])
    return [t for t in tris if t not in drop]


def similarity(src, dst):
    """Scale s, rotation R (a proper one) and shift t taking points src [n, 3] onto dst [n, 3]: dst ~ s R src + t."""
    import numpy as np
    ms, md = src.mean(0), dst.mean(0)
    a, b = src - ms, dst - md
    u, sig, vt = np.linalg.svd(b.T @ a)
    d = np.sign(np.linalg.det(u @ vt))
    fix = np.diag([1.0, 1.0, d])
    rot = u @ fix @ vt
    s = float((sig * np.diag(fix)).sum() / max((a * a).sum(), 1e-12))
    return s, rot, md - s * rot @ ms


def fit(points, rigid, rounds=4):
    """Every frame's pose against the neutral face, the neutral face from the posed frames, in turn; the rigid
    points picked again each round as those that move least."""
    import numpy as np
    canon = points[0].astype(np.float64)
    n = points.shape[0]
    for _ in range(rounds):
        poses = [similarity(canon[rigid], points[i][rigid].astype(np.float64)) for i in range(n)]
        aligned = np.stack([(points[i] - t) @ r / s for i, (s, r, t) in enumerate(poses)])
        canon = np.median(aligned, axis=0)
        spread = np.sqrt(((aligned - canon) ** 2).sum(-1).mean(0))
        rigid = np.argsort(spread)[: max(12, int(RIGID_SHARE * spread.size))]
    return canon, poses, aligned, rigid


def derived(canon, lips_inner):
    """The points the mesh adds to MediaPipe's: the mouth's back (the inner lips' mean, pushed back by
    MOUTH_DEPTH of the mouth's width) - as a mix of MediaPipe's points and a fixed offset."""
    import numpy as np
    w = np.zeros((1, canon.shape[0]))
    w[0, lips_inner] = 1.0 / len(lips_inner)
    width = np.linalg.norm(canon[61] - canon[291])
    # behind is the face's +z (MediaPipe: a smaller z is nearer the camera)
    shift = np.array([[0.0, 0.0, MOUTH_DEPTH * width]])
    return w, shift


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--frames", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--poses", default="")
    ap.add_argument("--progress", default="")
    a = ap.parse_args()
    import numpy as np
    f = np.load(os.path.join(a.frames, "frames.npz"))
    pts = f["points"][:, :478].astype(np.float64)
    keep = f["found"].astype(bool) & ~f["hands"].astype(bool)
    idx = np.nonzero(keep)[0]
    canon, poses, aligned, rigid = fit(pts[idx], np.arange(468))
    residual = aligned - canon
    # THE BASIS: offsets from the neutral face as a linear function of the 52 scores, ridge, on all but the
    # held-out frames; then measured on those
    blend = f["blend"][idx].astype(np.float64)
    test = np.zeros(idx.size, bool)
    test[::HELD_OUT] = True
    X = np.concatenate([blend, np.ones((idx.size, 1))], 1)
    Y = residual.reshape(idx.size, -1)
    A = X[~test]
    lam = RIDGE * np.eye(X.shape[1])
    lam[-1, -1] = 0.0
    W = np.linalg.solve(A.T @ A + lam * A.shape[0], A.T @ Y[~test])
    pred = X[test] @ W
    def r2(rows):
        cols = np.concatenate([[3 * r, 3 * r + 1, 3 * r + 2] for r in rows])
        e = ((Y[test][:, cols] - pred[:, cols]) ** 2).sum()
        v = ((Y[test][:, cols] - Y[test][:, cols].mean(0)) ** 2).sum()
        return 1.0 - e / max(v, 1e-12)
    canon = canon + W[-1].reshape(-1, 3)        # the neutral face is where every score is 0
    basis = W[:52].reshape(52, -1, 3)
    # THE SURFACE: MediaPipe's triangles, its holes filled
    tris = clean(triangles(), canon[:, :2])
    dw, dshift = derived(canon, LIPS_INNER)
    back = 478
    fill = [(LIPS_INNER[i], LIPS_INNER[(i + 1) % len(LIPS_INNER)], back) for i in range(len(LIPS_INNER))]
    for loop, iris in ((EYE_LEFT, IRIS_LEFT), (EYE_RIGHT, IRIS_RIGHT)):
        fill += [(loop[i], loop[(i + 1) % len(loop)], iris) for i in range(len(loop))]
    canon_all = np.concatenate([canon, dw @ canon + dshift])
    basis_all = np.concatenate([basis, np.einsum("dv,kvc->kdc", dw, basis)], 1)
    n = pts.shape[0]
    scale = np.zeros(n)
    rot = np.tile(np.eye(3), (n, 1, 1))
    shift = np.zeros((n, 3))
    al = np.zeros((n, 478, 3))
    for j, i in enumerate(idx):
        scale[i], rot[i], shift[i] = poses[j]
        al[i] = aligned[j]
    out = a.out + ".part.npz"
    np.savez(out, canon=canon_all.astype(np.float32), basis=basis_all.astype(np.float32),
             tris=np.asarray(list(tris) + fill, np.int32), derived=dw.astype(np.float32),
             derived_shift=dshift.astype(np.float32), rigid=rigid.astype(np.int32), keep=keep,
             scale=scale.astype(np.float32), rot=rot.astype(np.float32), shift=shift.astype(np.float32),
             aligned=al.astype(np.float32), blend=f["blend"].astype(np.float32))
    os.replace(out, a.out)
    if a.poses:
        stills = []
        for j in range(f["still_points"].shape[0] if "still_points" in f.files else 0):
            if not bool(f["still_found"][j]):
                stills.append(None)
                continue
            s, r, t = similarity(canon[rigid], f["still_points"][j][rigid].astype(np.float64))
            stills.append({"scale": s, "rot": r.tolist(), "shift": t.tolist(), "blend": f["still_blend"][j].tolist()})
        blends = f["blend"][idx]
        rest = np.median(blends, 0)
        looks = {}
        for name, pair in actor.GLANCES.items():
            cols = [actor.BLEND_NAMES.index(n) for n in pair]
            how = blends[:, cols].mean(1)
            most = how >= np.quantile(how, 1.0 - LOOK_SHARE)
            # the eyes and brows alone: what else moves with a glance in their footage is their talking
            only = np.array([n.startswith(("eye", "brow")) for n in actor.BLEND_NAMES], np.float64)
            looks[name] = ((np.median(blends[most], 0) - rest) * only).tolist()
        actor.write_json(a.poses, {"stills": stills, "rest": rest.tolist(), "looks": looks,
                                   "shut": [float(np.percentile(blends[:, 9], 99)), float(np.percentile(blends[:, 10], 99))]})
    # what it holds, measured
    fit_px = np.sqrt((((aligned[:, rigid] - canon[rigid]) * np.asarray([s for s, _, _ in poses])[:, None, None]) ** 2)
                     .sum(-1).mean())
    actor.say("face: %d frames, %d triangles (%d filled), the head's pose fitted to %.2f px on %d points; "
              "the scores explain %.0f%% of the face's movement on held-out frames (lips %.0f%%, eyes %.0f%%)"
              % (idx.size, len(tris) + len(fill), len(fill), fit_px, rigid.size, 100 * r2(range(478)),
                 100 * r2(sorted(set(LIPS_INNER) | {61, 291, 0, 17})), 100 * r2(EYE_LEFT + EYE_RIGHT)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
