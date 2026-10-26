#!/usr/bin/env python3
"""rig.py - the surface an actor's head of splats is bound to, learned from their own frames (next/likeness.md,
"A head of splats").

    <face_venv python> rig.py --frames <frames folder> [--frames <another> ...] --out <rig.npz>
                              [--poses <poses.json>] [--shared <the actor's rig.npz>] [--visemes <visemes.json>]

MediaPipe's face mesh is the surface: its 478 points are tracked in every frame (frames.py), and its
triangles come from its own tessellation. From the frames this learns:
- THEIR NEUTRAL FACE (`canon`): every frame's points brought onto one another by a similarity (scale,
  rotation, shift) fitted on the points that move least with expression, then averaged;
- EACH FRAME'S HEAD (`scale`, `rot`, `shift`): that similarity, from the neutral face into the frame's pixels;
- HOW THEIR FACE MOVES (`basis`): the neutral face's offset at each point as a linear function of MediaPipe's
  52 expression scores, by ridge regression over every frame - what drives the head at playback, where a
  blink, a glance and their face's own motion are those scores - A PART AT A TIME (`by_parts`, parts.py: each
  point moved by the scores of the parts that reach it alone; fitted over every score, a glance had moved the
  cheeks and the jaw);
- THE SURFACE (`tris`): MediaPipe's triangles, with the mouth's and the eyes' holes filled - the mouth by a
  fan to a point behind the lips (where the teeth and the dark of the mouth are learned), each eye by a fan
  to its iris centre (so the eye's own splats follow the gaze).

THE BODY'S BONES (`BODY`, the 2D rig's bones less the head - actor.py's `BONES`): from each frame's pose
(MediaPipe's 33 points), a frame of reference per bone - the torso at the neck, its axes the shoulders' line
and the picture's down; each shoulder at its joint, the torso's axes; each upper arm, forearm and hand along
its bone from its joint - with a unit (a quarter of the shoulders' width, half a limb's length) and how
surely it is seen (its ends' least visibility). THE BONES LIE IN ONE PLANE, BODY_BEHIND shoulder widths
behind the face's nose tip: MediaPipe's pose guesses at depth (on his frames its shoulders stood 240 px
apart in it), the camera is fixed and the body turns little, so its places across the picture are taken and
its depth is not - a splat's own depth on its bone is learned.

Writes <out>: canon [V, 3], basis [52, V, 3], tris [T, 3], derived [V - 478, 478] with derived_shift
[V - 478, 3] (the points that are not MediaPipe's: a mix of its points plus a fixed offset), rigid [K]
(the points the head's pose is fitted on), and per frame: keep [N] (a frame learned from), scale [N],
rot [N, 3, 3], shift [N, 3], aligned [N, 478, 3] (its points on the neutral face's frame), blend [N, 52],
bone_origin [N, B, 3], bone_axes [N, B, 3, 3] (columns), bone_unit [N, B], bone_seen [N, B].

ONE FACE FOR EVERY VIDEO (next/likeness.md, "One head"): given several folders (head_frames.py's, one a video),
their frames are posed and learned from together - one neutral face, one basis - and the rig says which folder
each frame is from (`video` [N], `folders`). Given --shared (the actor's rig), nothing is learned: the folder's
frames and stills are posed against the actor's neutral face (a set's own, played on the head learned from all),
and the glances and the eyes' shut scores are the actor's (its poses.json beside it).

And <poses>, what the head is played from ([SplatHead], the medium): each still's pose, scores and bones
({scale, rot (rows), shift, blend, bones: [{origin, axes (columns), unit, seen}]} - the head and body as they
stand in the still, which the playing ones start from),
`rest` (their median scores: the face at ease, what a sound's mouth and a blink move from), `shut` (each
eye's score when it is closed: the top of their own blinks) and `looks` (each glance of the plan's - the 2D
library's `GLANCES`, the picture's left and right - as the 52 scores' move from their median when they look
that way most: the median of the frames whose two scores for it are in their top LOOK_SHARE, less the
median of all; the eyes' and brows' scores alone, so the lids and brows that go with it come too, and the
talking that went on while they looked does not) - and, given --visemes (the actor's visemes.json), `mouths`: each
sound's mouth as their face made it (`mouths_of`: the points' and scores' move from their rest, from every frame of
the actor's) and how far their lips part (`gap`, its 1st and 99th percentiles).
"""

from __future__ import annotations

import argparse
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "face"))

import actor  # noqa: E402
import parts  # noqa: E402

# The inner edge of the lips, round (MediaPipe's numbering) - the mouth's hole.
LIPS_INNER = [78, 191, 80, 81, 82, 13, 312, 311, 310, 415, 308, 324, 318, 402, 317, 14, 87, 178, 88, 95]
# Each eye's opening, round, and its iris centre.
EYE_LEFT = [33, 246, 161, 160, 159, 158, 157, 173, 133, 155, 154, 153, 145, 144, 163, 7]
EYE_RIGHT = [263, 466, 388, 387, 386, 385, 384, 398, 362, 382, 381, 380, 374, 373, 390, 249]
IRIS_LEFT = 468
IRIS_RIGHT = 473
# EACH SOUND'S MOUTH is the median of the frames whose mouth's scores are nearest the sound's: this share of them,
# at least MOUTH_LEAST.
MOUTH_SHARE = 0.01
MOUTH_LEAST = 30
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
# The body's bones (actor.py's BONES less the head, in its order), and the pose's points each runs between:
# the shoulders and the arm's joints; a hand runs from its wrist to its knuckles (the index's and pinky's).
BODY = ["torso", "shoulder_l", "shoulder_r", "upper_l", "fore_l", "hand_l", "upper_r", "fore_r", "hand_r"]
ARMS = {"l": (11, 13, 15, 17, 19), "r": (12, 14, 16, 18, 20)}
# The face's nose tip (MediaPipe's face mesh), and how far behind it the body's bones lie, in shoulder widths.
FACE_NOSE = 1
BODY_BEHIND = 0.5


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


def bones_of(pose, w: float, h: float, face=None):
    """THE BODY'S BONES in one picture's pose [33 * 4] (normalized): (origin [B, 3], axes [B, 3, 3] - columns,
    unit [B], seen [B]) in its pixels, z on x's scale, put on [face]'s depth when it is given."""
    import numpy as np
    p = np.asarray(pose, np.float64).reshape(33, 4)
    xyz = p[:, :3] * np.array([w, h, w])
    vis = p[:, 3]
    origin = np.zeros((len(BODY), 3))
    axes = np.tile(np.eye(3), (len(BODY), 1, 1))
    unit = np.ones(len(BODY))
    seen = np.zeros(len(BODY))
    sw = float(np.hypot(*(xyz[11] - xyz[12])[:2]))
    if sw < 1.0:
        return origin, axes, unit, seen
    xyz[:, 2] = (float(face[FACE_NOSE][2]) if face is not None else 0.0) + BODY_BEHIND * sw
    sl, sr = xyz[11], xyz[12]

    def norm(v):
        n = float(np.linalg.norm(v))
        return v / n if n > 1e-9 else v
    e1 = norm(sl - sr)
    down = np.array([0.0, 1.0, 0.0])
    e2 = norm(down - np.dot(down, e1) * e1)
    e3 = np.cross(e1, e2)
    torso = np.stack([e1, e2, e3], 1)
    rows = [((sl + sr) * 0.5, torso, sw / 4.0, min(vis[11], vis[12])), (sl, torso, sw / 4.0, vis[11]),
            (sr, torso, sw / 4.0, vis[12])]

    def limb(a, b, sure):
        d = xyz[b] - xyz[a] if isinstance(b, int) else b - xyz[a]
        length = float(np.linalg.norm(d))
        x = norm(d) if length > 1e-6 else e2
        y = np.cross(e3, x)
        y = norm(y) if np.linalg.norm(y) > 1e-6 else e1
        return (xyz[a], np.stack([x, y, np.cross(x, y)], 1), max(length * 0.5, 1.0), sure)
    for side in ("l", "r"):
        s_, e_, w_, pk, ix = ARMS[side]
        rows.append(limb(s_, e_, min(vis[s_], vis[e_])))
        rows.append(limb(e_, w_, min(vis[e_], vis[w_])))
        rows.append(limb(w_, (xyz[pk] + xyz[ix]) * 0.5, min(vis[w_], vis[pk], vis[ix])))
    for b, (o, ax, u, sure) in enumerate(rows):
        origin[b], axes[b], unit[b], seen[b] = o, ax, u, sure
    return origin, axes, unit, seen


def by_parts(X, Y, canon):
    """THE BASIS, A PART AT A TIME ([param X]: the frames' scores and a 1, [N, 53]; [param Y]: their points' offsets
    from the neutral face [param canon], [N, V * 3]): each point's offsets a ridge regression on the scores of the
    parts that reach it alone (parts.py), each score's row then taken as far as its part reaches the point - so a
    glance moves the eyes and nothing else, and a point no part reaches moves with nothing. [53, V * 3]: the scores'
    rows, then the neutral face's correction."""
    import numpy as np
    reach = parts.reach_at(canon, canon)
    own = [parts.scores_of(actor.BLEND_NAMES, row[1]) for row in parts.PARTS]
    W = np.zeros((X.shape[1], Y.shape[1]))
    groups = {}
    for v in range(canon.shape[0]):
        groups.setdefault(tuple(bool(x) for x in reach[v] > 0.0), []).append(v)
    for key, vs in groups.items():
        cols = sorted(set(j for p, on in enumerate(key) if on for j in own[p])) + [X.shape[1] - 1]
        ys = np.array([[3 * v, 3 * v + 1, 3 * v + 2] for v in vs]).reshape(-1)
        A = X[:, cols]
        lam = RIDGE * np.eye(len(cols))
        lam[-1, -1] = 0.0
        W[np.ix_(cols, ys)] = np.linalg.solve(A.T @ A + lam * A.shape[0], A.T @ Y[:, ys])
    for p, cols in enumerate(own):
        W[cols] *= np.repeat(reach[:, p], 3)[None]
    return W


def mouths_of(aligned, blend, visemes: dict, canon, dw) -> dict:
    """EACH SOUND'S MOUTH AS THEIR FACE MADE IT (2026-10-25, the user: "The mouth shape barely moves"): played from
    each sound's scores through the basis, his mouth opened 0.044 to 0.062 of his face's height while it spoke - his
    own lips, tracked, 0.013 to 0.11 - for a sound's scores were set one by one (the jaw at its place in his range,
    the lips at their medians, where an open jaw drops the lower lip with it) and the beard leaves MediaPipe's scores
    short of what the lips do. The head is learned on the tracked points, so the mouth is played from them: for each
    sound of [param visemes] (visemes.json), the frames ([param aligned] [N, 478, 3] on the neutral face, [param blend]
    [N, 52]) whose mouth's scores are nearest the sound's (each score over its spread; MOUTH_SHARE of them, at least
    MOUTH_LEAST), their points' median less the rest's - where the mouth reaches (parts.py), the points the face adds
    after them made from them ([param dw]) - and their mouth's scores' median less the rest's. With the inner lips' parting
    over the face's height across every frame, its 1st and 99th percentiles: how far a mouth may go."""
    import numpy as np
    names = visemes.get("names", [])
    cols = [actor.BLEND_NAMES.index(n) for n in names]
    m = blend[:, cols].astype(np.float64)
    sd = m.std(0) + 1e-6
    n_near = min(len(m), max(MOUTH_LEAST, int(MOUTH_SHARE * len(m))))
    mouth = [row[0] for row in parts.PARTS].index("mouth")
    reach = parts.reach_at(canon, canon[:478])[:, mouth]
    said = np.zeros(blend.shape[1])
    said[parts.scores_of(actor.BLEND_NAMES[: blend.shape[1]], parts.PARTS[mouth][1])] = 1.0
    made = {}
    for c, row in visemes.get("classes", {}).items():
        d = (((m - np.asarray(row["blend"], np.float64)) / sd) ** 2).sum(1)
        near = np.argpartition(d, n_near - 1)[:n_near]
        made[c] = (np.median(aligned[near], 0), np.median(blend[near], 0))
    if "rest" not in made:
        return {}
    rest_points, rest_blend = made["rest"]
    sounds = {}
    for c, (points, scores) in made.items():
        off = (points - rest_points) * reach[:, None]
        off = np.concatenate([off, dw @ off])
        sounds[c] = {"points": np.round(off, 4).tolist(), "blend": np.round((scores - rest_blend) * said, 4).tolist()}
    gap = np.linalg.norm(aligned[:, 13] - aligned[:, 14], axis=1) / np.maximum(
        np.linalg.norm(aligned[:, parts.TOP] - aligned[:, parts.CHIN], axis=1), 1e-6)
    return {"sounds": sounds, "gap": [round(float(np.percentile(gap, 1)), 4), round(float(np.percentile(gap, 99)), 4)]}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--frames", required=True, action="append")
    ap.add_argument("--out", required=True)
    ap.add_argument("--poses", default="")
    ap.add_argument("--shared", default="")
    ap.add_argument("--visemes", default="")
    ap.add_argument("--progress", default="")
    a = ap.parse_args()
    import numpy as np
    fs = [np.load(os.path.join(d, "frames.npz")) for d in a.frames]
    f = {k: np.concatenate([g[k] for g in fs]) for k in ("points", "found", "hands", "blend", "pose")}
    video = np.concatenate([np.full(g["found"].shape[0], k, np.int32) for k, g in enumerate(fs)])
    sizes = []
    for d in a.frames:
        c = [int(v) for v in json.load(open(os.path.join(d, "spec.json")))["crop"]]
        sizes.append((c[2], c[3]) if len(c) == 4 else (c[2], c[2]))
    pts = f["points"][:, :478].astype(np.float64)
    # EVERY FRAME WITH A FACE is posed (a hand at the mouth is theirs too, and the whole of them is learned);
    # the basis is fitted on those with no hand at the mouth, whose scores a hand does not spoil
    keep = f["found"].astype(bool)
    idx = np.nonzero(keep)[0]
    shared = np.load(a.shared) if a.shared else None
    if shared is not None:
        # POSED AGAINST THE ACTOR'S FACE: its neutral face, basis, surface and rigid points, as they are
        canon_all, basis_all = shared["canon"].astype(np.float64), shared["basis"].astype(np.float64)
        canon, rigid = canon_all[:478], shared["rigid"].astype(np.int64)
        tris, dw, dshift = [tuple(t) for t in shared["tris"]], shared["derived"], shared["derived_shift"]
        fill = []
        poses = [similarity(canon[rigid], pts[i][rigid]) for i in idx]
        aligned = np.stack([(pts[i] - t) @ r / s for i, (s, r, t) in zip(idx, poses)]) if idx.size else np.zeros((0, 478, 3))
    else:
        canon, poses, aligned, rigid = fit(pts[idx], np.arange(468))
        residual = aligned - canon
        # THE BASIS: offsets from the neutral face as a linear function of the 52 scores, ridge, on all but the
        # held-out frames; then measured on those
        unspoiled = ~f["hands"].astype(bool)[idx]
        blend = f["blend"][idx].astype(np.float64)[unspoiled]
        residual = residual[unspoiled]
        test = np.zeros(blend.shape[0], bool)
        test[::HELD_OUT] = True
        X = np.concatenate([blend, np.ones((blend.shape[0], 1))], 1)
        Y = residual.reshape(blend.shape[0], -1)
        W = by_parts(X[~test], Y[~test], canon)
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
    cw, ch = sizes[0]
    nb = len(BODY)
    b_origin = np.zeros((n, nb, 3))
    b_axes = np.tile(np.eye(3), (n, nb, 1, 1))
    b_unit = np.ones((n, nb))
    b_seen = np.zeros((n, nb))
    for i in range(n):
        if bool(f["found"][i]):
            b_origin[i], b_axes[i], b_unit[i], b_seen[i] = bones_of(f["pose"][i], *sizes[int(video[i])], pts[i])
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
             aligned=al.astype(np.float32), blend=f["blend"].astype(np.float32),
             bone_origin=b_origin.astype(np.float32), bone_axes=b_axes.astype(np.float32),
             bone_unit=b_unit.astype(np.float32), bone_seen=b_seen.astype(np.float32), video=video,
             folders=np.asarray([os.path.abspath(d) for d in a.frames]))
    os.replace(out, a.out)
    if a.poses:
        stills = []
        g = fs[0]
        for j in range(g["still_points"].shape[0] if "still_points" in g.files else 0):
            if not bool(g["still_found"][j]):
                stills.append(None)
                continue
            s, r, t = similarity(canon[rigid], g["still_points"][j][rigid].astype(np.float64))
            row = {"scale": s, "rot": r.tolist(), "shift": t.tolist(), "blend": g["still_blend"][j].tolist()}
            if "still_pose" in g.files:
                bo, ba, bu, bs = bones_of(g["still_pose"][j], cw, ch, g["still_points"][j])
                row["bones"] = [{"origin": bo[b].tolist(), "axes": ba[b].T.tolist(), "unit": float(bu[b]),
                                 "seen": float(bs[b])} for b in range(nb)]
            stills.append(row)
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
        own = {"stills": stills, "rest": rest.tolist(), "looks": looks,
               "shut": [float(np.percentile(blends[:, 9], 99)), float(np.percentile(blends[:, 10], 99))]}
        theirs = os.path.join(os.path.dirname(a.shared), "poses.json") if a.shared else ""
        if theirs and os.path.exists(theirs):
            # the actor's range, from every video: their rest, their glances, how far their eyes close
            for key in ("rest", "looks", "shut"):
                own[key] = actor.read_json(theirs)[key]
        if a.visemes and os.path.exists(a.visemes):
            # each sound's mouth from every frame of theirs: the actor's (--shared), else these
            src = shared if shared is not None else {"aligned": al, "blend": f["blend"], "keep": keep}
            k = np.asarray(src["keep"]).astype(bool)
            own["mouths"] = mouths_of(np.asarray(src["aligned"])[k].astype(np.float64), np.asarray(src["blend"])[k],
                                      actor.read_json(a.visemes), canon_all, dw)
        actor.write_json(a.poses, own)
    # what it holds, measured
    fit_px = np.sqrt((((aligned[:, rigid] - canon[rigid]) * np.asarray([s for s, _, _ in poses])[:, None, None]) ** 2)
                     .sum(-1).mean())
    if shared is not None:
        actor.say("face: %d frames posed against the actor's face, to %.2f px on %d points" % (idx.size, fit_px, rigid.size))
        return 0
    actor.say("face: %d folders, %d frames, %d triangles (%d filled), the head's pose fitted to %.2f px on %d points; "
              "the scores explain %.0f%% of the face's movement on held-out frames (lips %.0f%%, eyes %.0f%%)"
              % (len(a.frames), idx.size, len(tris) + len(fill), len(fill), fit_px, rigid.size, 100 * r2(range(478)),
                 100 * r2(sorted(set(LIPS_INNER) | {61, 291, 0, 17})), 100 * r2(EYE_LEFT + EYE_RIGHT)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
