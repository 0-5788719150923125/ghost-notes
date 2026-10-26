#!/usr/bin/env python3
"""actor.py, held to what its steps promise (next/likeness.md, "Gates").

    <face_venv python> test_actor.py [--ffmpeg <ghost's ffmpeg>]

Fixtures are made, not found: a picture of noise, a mesh over it, a made face, made surveys and a
video FFmpeg makes from two colors - no footage of anyone. Each claim beside a control that must fail:
- a frame unwrapped into the layout and warped back comes back where it was, within a pixel; with the
  layout's points swapped it does not;
- a hard cut in a made video is found, and placed on its frame; a made video with none has none;
- two made rooms are two sets; the same room with a bright patch moved across it (the sun on a wall)
  stays one set - and with the edges compared by color instead, it would have split;
- the survey's format reads back what was written, and a survey's looks are read only inside the shots
  given, a little in from each cut, where a face was found;
- the head's quick motion keeps a nod and drops a slow drift; its runs end at a gap and at a turn away,
  and a short one is dropped;
- their face's own motion keeps a slow brow raise and calms the jitter round it, the raise its first way of
  moving (jitter alone makes no such way), and leaves the blinks, the gaze and the lips' opening out;
- a sound's target is pushed past their own on the shapes that show, never on mouthClose;
- a hand up is costed and a hand at rest is not - where rest is the low end of where their hands are seen;
- the rig made on a made still masks the lips and the eyes and nothing else, the lids move with the eyes
  and the brows never;
- the learned mouth: on a made voice whose mouth closes AHEAD of each closing sound (as lips do), the
  ensemble explains on unseen speech what each sound's mean mouth cannot; trained on shuffled mouths, it
  explains nothing; the same seed trains the same network.
"""
import argparse
import json
import math
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import actor  # noqa: E402

FAILS = []


def check(ok, what):
    print("   %s   %s" % ("ok  " if ok else "FAIL", what))
    if not ok:
        FAILS.append(what)


def test_warp_round_trip():
    import numpy as np
    # A SMOOTH PICTURE (a resampling keeps it; noise a pixel wide it cannot, both ways)
    yy, xx = np.mgrid[0:240, 0:320].astype(np.float32)
    img = np.stack([128 + 100 * np.sin(xx / 17.0), 128 + 100 * np.cos(yy / 13.0),
                    128 + 80 * np.sin((xx + yy) / 23.0)], axis=2).astype(np.uint8)
    # a mesh: a grid over the frame, and a layout that is the grid bent smoothly
    gx, gy = np.meshgrid(np.linspace(40, 280, 7), np.linspace(40, 200, 5))
    src = np.stack([gx.ravel(), gy.ravel()], axis=1)
    lay = src * 0.9 + np.array([12.0, 8.0]) + 6.0 * np.sin(src[:, ::-1] / 40.0)
    tris = []
    for r in range(4):
        for c in range(6):
            a = r * 7 + c
            tris += [[a, a + 1, a + 7], [a + 1, a + 8, a + 7]]
    tris = np.array(tris)
    flat = actor.warp_triangles(img, src, lay, tris, img.shape)
    back = actor.warp_triangles(flat, lay, src, tris, img.shape)
    # judged inside the mesh, away from its edge
    x0, y0, x1, y1 = 60, 60, 260, 180
    d = np.abs(back[y0:y1, x0:x1].astype(np.float32) - img[y0:y1, x0:x1].astype(np.float32)).mean()
    check(d < 3.0, "unwrap then rewarp comes back (mean difference %.2f of 255)" % d)
    # A POINT, not a mean: a bright dot goes and comes back to its own pixel
    dot = np.zeros_like(img)
    dot[118:123, 158:163] = 255
    there = actor.warp_triangles(dot, src, lay, tris, img.shape)
    home = actor.warp_triangles(there, lay, src, tris, img.shape)
    ys, xs = np.nonzero(home[:, :, 0] > 128)
    cx, cy = (xs.mean(), ys.mean()) if xs.size else (0.0, 0.0)
    check(math.hypot(cx - 160, cy - 120) <= 1.0, "a dot comes back within a pixel (%.2f px off)" % math.hypot(cx - 160, cy - 120))
    # the control: the layout's points swapped round
    swapped = lay.copy()
    swapped[[10, 11, 17, 18]] = swapped[[18, 17, 11, 10]]
    there = actor.warp_triangles(dot, src, swapped, tris, img.shape)
    lost = actor.warp_triangles(there, lay, src, tris, img.shape)
    ys, xs = np.nonzero(lost[:, :, 0] > 128)
    off = math.hypot(xs.mean() - 160, ys.mean() - 120) if xs.size else 99.0
    check(off > 2.0, "with the points swapped the dot does not come home (%.2f px off) - the check can fail" % off)


def make_video(ffmpeg, path, cut_at=None, length=8.0):
    """A made video: a smooth moving pattern, and - with [cut_at] - another one from then on."""
    if cut_at is None:
        src = "testsrc2=size=320x180:rate=30:duration=%g" % length
        cmd = [ffmpeg, "-v", "error", "-y", "-f", "lavfi", "-i", src]
    else:
        a = "testsrc2=size=320x180:rate=30:duration=%g" % cut_at
        b = "mandelbrot=size=320x180:rate=30,trim=duration=%g" % (length - cut_at)
        cmd = [ffmpeg, "-v", "error", "-y", "-f", "lavfi", "-i", a, "-f", "lavfi", "-i", b,
               "-filter_complex", "[0:v][1:v]concat=n=2:v=1:a=0"]
    subprocess.run(cmd + ["-pix_fmt", "yuv420p", "-c:v", "libx264", "-g", "15", path], check=True)


def survey_of_video(ffmpeg, path):
    """A survey's thumbnails of a made video, as the survey takes them (no face, no body)."""
    import numpy as np
    thumbs = []
    for _k, g in actor.frames(ffmpeg, path, actor.THUMB_W, actor.THUMB_H, rate=5.0, gray=True):
        thumbs.append(g.reshape(-1))
    return np.array(thumbs, dtype=np.uint8)


def test_cuts(ffmpeg, tmp):
    import numpy as np
    one = os.path.join(tmp, "cut.mp4")
    make_video(ffmpeg, one, cut_at=4.0)
    th = survey_of_video(ffmpeg, one)
    found = actor.find_cuts(th)
    placed = []
    for i in found:
        at, stands = actor.exact_cut(ffmpeg, one, (i - 1) * 0.2, i * 0.2, 30.0)
        if stands >= actor.CUT_STANDS:
            placed.append(at)
    check(len(placed) == 1 and abs(placed[0] - 4.0) <= 1.5 / 30.0,
          "one cut found, on its frame (found %s)" % [round(p, 3) for p in placed])
    none = os.path.join(tmp, "nocut.mp4")
    make_video(ffmpeg, none)
    th = survey_of_video(ffmpeg, none)
    placed = []
    for i in actor.find_cuts(th):
        at, stands = actor.exact_cut(ffmpeg, none, (i - 1) * 0.2, i * 0.2, 30.0)
        if stands >= actor.CUT_STANDS:
            placed.append(at)
    check(not placed, "a video with no cut has none (found %s)" % placed)


class Fake:
    """A survey in memory: the fields shot_profile reads."""

    def __init__(self, thumbs, masks, rate=5.0):
        import numpy as np
        n = thumbs.shape[0]
        self.rate = rate
        self.count = n
        box = np.tile(np.array([0.4, 0.3, 0.6, 0.6], dtype=np.float32), (n, 1))
        self.f = {"time": (np.arange(n) / rate).reshape(-1, 1).astype(np.float32), "thumb": thumbs,
                  "mask": masks, "found": np.ones((n, 1), dtype=np.float32), "box": box,
                  "pose": np.zeros((n, 132), dtype=np.float32)}

    def __getitem__(self, k):
        return self.f[k]


def room(seed, patch_x=None):
    """A made room as the survey sees it, 64 x 36: shapes with edges, a person in the middle - and a
    bright patch of sun where [patch_x] says."""
    import numpy as np
    rng = np.random.default_rng(seed)
    img = np.full((actor.THUMB_H, actor.THUMB_W), 90.0)
    for _ in range(6):
        x, y = rng.integers(0, actor.THUMB_W - 12), rng.integers(0, actor.THUMB_H - 8)
        img[y:y + rng.integers(4, 10), x:x + rng.integers(6, 14)] = rng.integers(20, 200)
    if patch_x is not None:
        sun = np.zeros_like(img)
        sun[4:20, patch_x:patch_x + 10] = 40.0
        import cv2
        img = img + cv2.GaussianBlur(sun, (0, 0), 3.0)
    return np.clip(img, 0, 255)


def test_sets():
    import numpy as np
    mask = np.zeros((actor.MASK_H, actor.MASK_W), dtype=np.uint8)
    mask[4:18, 13:19] = 255
    n = 20

    def shot(seed, patches):
        th = np.stack([room(seed, p).reshape(-1) for p in patches]).astype(np.uint8)
        return Fake(th, np.tile(mask.reshape(-1), (len(patches), 1)))

    a = actor.shot_profile(shot(1, [None] * n), 0.0, 99.0)
    b = actor.shot_profile(shot(2, [None] * n), 0.0, 99.0)
    sun1 = actor.shot_profile(shot(1, [2 + i // 4 for i in range(n)]), 0.0, 99.0)
    sun2 = actor.shot_profile(shot(1, [40 + i // 4 for i in range(n)]), 0.0, 99.0)
    t = 0.55
    check(actor.shot_distance(a, b) > t, "two rooms are two sets (%.2f over %.2f)" % (actor.shot_distance(a, b), t))
    check(actor.shot_distance(sun1, sun2) < t,
          "the sun moved across one room keeps it one set (%.2f under %.2f)" % (actor.shot_distance(sun1, sun2), t))
    # the control: the same two, compared by their brightness rather than their edges, split
    by_color = float(np.abs(sun1["bg"] - sun2["bg"]).mean())
    by_color_rooms = float(np.abs(a["bg"] - sun1["bg"]).mean())
    check(by_color > 0.5 * by_color_rooms, "compared by color the moved sun would split the room (%.1f against %.1f)" % (by_color, by_color_rooms))
    groups = actor.cluster(3, [[0, actor.shot_distance(a, b), actor.shot_distance(a, sun1)],
                               [actor.shot_distance(a, b), 0, actor.shot_distance(b, sun1)],
                               [actor.shot_distance(a, sun1), actor.shot_distance(b, sun1), 0]], t)
    check(sorted(map(sorted, groups)) == [[0, 2], [1]], "the clustering puts each room's shots together: %s" % groups)


def test_format(tmp):
    import numpy as np
    path = os.path.join(tmp, "t.bin")
    w = actor.TrackWriter(path, actor.SURVEY_FIELDS, 5.0)
    for i in range(5):
        w.add({"time": i / 5.0, "found": 1.0, "blend": np.full(52, 0.1 * i, dtype=np.float32),
               "thumb": np.full(2304, i, dtype=np.uint8)})
    w.close()
    tr = actor.Track(path)
    check(tr.count == 5 and abs(tr.rate - 5.0) < 1e-6, "a survey reads back its count and rate")
    check(abs(float(tr["blend"][3, 7]) - 0.3) < 1e-6 and int(tr["thumb"][4, 7]) == 4,
          "a survey reads back its fields")


def made_survey(path, n=200, lost=()):
    """A survey of [n] looks a fifth of a second apart, the face found but at [lost], turned a little."""
    import numpy as np
    w = actor.TrackWriter(path, actor.SURVEY_FIELDS, 5.0)
    for i in range(n):
        m = np.eye(4, dtype=np.float32).reshape(-1)
        w.add({"time": i / 5.0, "found": 0.0 if i in lost else 1.0, "matrix": m,
               "blend": np.full(52, 0.05, dtype=np.float32), "box": [0.4, 0.3, 0.6, 0.6],
               "pose": np.zeros(132, dtype=np.float32)})
    w.close()


def test_survey_records(tmp):
    """Looks are read inside the shots given, a little in from each cut, where a face was found."""
    import numpy as np
    path = os.path.join(tmp, "s.bin")
    made_survey(path, lost=(50, 51))
    R = actor.survey_records({"v": {"survey": path}}, [{"vid": "v", "start": 2.0, "end": 12.0, "set": "a"}])
    t = R["time"]
    check(R["count"] > 0 and t.min() >= 2.0 + actor.CUT_MARGIN - 1e-6 and t.max() <= 12.0 - actor.CUT_MARGIN + 1e-6,
          "a survey's looks come from inside the shot, away from its cuts (%.1f to %.1f)" % (t.min(), t.max()))
    check(not np.any(np.isclose(t, 10.0)) and not np.any(np.isclose(t, 10.2)), "a look with no face was read")
    check(set(R["set"].tolist()) == {"a"} and np.allclose(R["angles"], 0.0, atol=1e-4), "a look's set or turn is wrong")
    # angles_of is head_angles, all at once
    rng = np.random.default_rng(3)
    ms = []
    for _ in range(20):
        a, b, c = rng.uniform(-0.6, 0.6, 3)
        Rx = np.array([[1, 0, 0], [0, math.cos(a), -math.sin(a)], [0, math.sin(a), math.cos(a)]])
        Ry = np.array([[math.cos(b), 0, math.sin(b)], [0, 1, 0], [-math.sin(b), 0, math.cos(b)]])
        Rz = np.array([[math.cos(c), -math.sin(c), 0], [math.sin(c), math.cos(c), 0], [0, 0, 1]])
        m = np.eye(4)
        m[:3, :3] = Rz @ Ry @ Rx
        ms.append(m.reshape(-1))
    together = actor.angles_of(np.array(ms))
    alone = np.array([actor.head_angles(m) for m in ms])
    check(np.allclose(together, alone, atol=1e-6), "the turns read all at once are not the turns read one by one")


def test_motion():
    """The head's quick motion keeps a nod and drops a drift; runs end at a gap and at a turn away."""
    import numpy as np
    n = 300
    t = np.arange(n) / 5.0
    nod = np.sin(t * 2.0 * math.pi / 1.6)
    drift = t * 0.2
    X = np.stack([drift + nod] + [np.zeros(n)] * 5, axis=1)
    hp = actor.high_pass(X, 21)[30:-30, 0]
    check(np.abs(hp - nod[30:-30]).mean() < 0.15, "the quick part kept the drift or lost the nod (%.3f off)" % np.abs(hp - nod[30:-30]).mean())
    check(np.abs(X[30:-30, 0] - nod[30:-30]).mean() > 2.0, "the made drift is too small to show (the check can fail)")
    # runs: one shot, a gap at 20 s, a turn away at 40 s, a short stretch at the end
    keep = np.ones(n, dtype=bool)
    R = {"count": n, "piece": np.zeros(n, dtype=int), "time": t.copy()}
    R["time"][100:] += 3.0
    keep[200:205] = False
    keep[260:] = True
    R["piece"][270:] = 1
    runs = actor.runs_of(R, 5.0, keep)
    lengths = [len(r) for r in runs]
    check(lengths == [100, 100, 65], "the runs are %s, not cut at the gap, the turn and the shot's end" % lengths)


def test_face_motion():
    """Their face's own motion keeps a slow brow raise under jitter, as its first way of moving, and leaves the
    blinks, the gaze and the lips' opening to what plays them."""
    import numpy as np
    names = actor.face_names()
    check("browInnerUp" in names and "mouthSmileLeft" in names and "eyeSquintLeft" in names,
          "the face's own motion leaves out a brow, a smile or a squint")
    check(not any(n.startswith("eyeBlink") or n.startswith("eyeLook") or n in ("jawOpen", "mouthPucker", "mouthClose")
                  for n in names), "the face's own motion takes a blink, the gaze or the lips' opening")
    rng = np.random.default_rng(3)
    n = 600
    t = np.arange(n) / 5.0
    brow = 0.2 * np.sin(t * 2.0 * math.pi / 3.0)
    F = rng.normal(0.0, 0.08, (n, len(names)))
    F[:, names.index("browInnerUp")] += brow
    S = actor.smooth_looks(F, actor.FACE_SMOOTH * 5.0)
    j = names.index("browInnerUp")
    kept = float(np.corrcoef(S[20:-20, j], brow[20:-20])[0, 1])
    check(kept > 0.9, "smoothed, the brow goes with its slow raise only %.2f" % kept)
    calm = actor.smooth_looks(rng.normal(0.0, 0.08, (n, 3)), actor.FACE_SMOOTH * 5.0)[20:-20].std()
    check(calm < 0.4 * 0.08, "smoothed, the jitter is still %.3f of 0.08" % calm)
    basis, sd = actor.face_components(S)
    check(int(np.argmax(np.abs(basis[0]))) == j, "the first way their face moves is not the brow's")
    check(1 <= len(sd) <= actor.FACE_MOST and np.allclose(np.linalg.norm(basis, axis=1), 1.0), "the ways are not unit directions")
    # the control: the jitter alone holds no direction its own, so the raise is what made the first one
    b0, _ = actor.face_components(actor.smooth_looks(rng.normal(0.0, 0.08, (n, len(names))), actor.FACE_SMOOTH * 5.0))
    check(abs(b0[0][j]) < 0.9, "jitter alone made the brow the first way (the check cannot fail)")


def test_targets():
    """A sound's target is pushed past their own on the shapes that show, never on mouthClose."""
    import numpy as np
    n = len(actor.MOUTH_NAMES)
    rest = np.full(n, 0.02)
    sound = np.full(n, 0.10)
    t = actor.class_target(sound, rest, 2.0)
    jaw, close = actor.MOUTH_NAMES.index("jawOpen"), actor.MOUTH_NAMES.index("mouthClose")
    check(abs(t[jaw] - 0.18) < 1e-9, "the jaw is not pushed twice as far from rest (%.3f)" % t[jaw])
    check(abs(t[close] - 0.10) < 1e-9, "mouthClose was pushed (%.3f): it rises with an open jaw" % t[close])
    check(np.all(actor.class_target(np.full(n, 0.9), rest, 3.0) <= 1.0), "a target past 1")
    check(np.allclose(actor.class_target(sound, rest, 1.0), sound), "at 1 a target is not their own")


def test_hands():
    """A hand up costs; a hand at rest - the low end of where their hands are seen - does not."""
    import numpy as np
    pose = np.zeros((40, 33, 4))
    pose[:, 11, 1] = pose[:, 12, 1] = 0.5
    pose[:, 15, 3] = 1.0
    pose[:, 15, 1] = 0.95
    pose[30:, 15, 1] = 0.7             # raised, as a gesture at the chest
    cost = actor.hands_up(pose.reshape(40, -1))
    check(cost[:30].max() < 1e-9 and cost[30:].min() > 1.0, "a raised hand costs %.2f, one at rest %.2f" % (cost[30:].min(), cost[:30].max()))
    # the control: what the first build did - their median place as rest - costs a hand at rest when
    # most hands seen are raised (2026-10-21)
    pose[5:, 15, 1] = 0.7
    cost = actor.hands_up(pose.reshape(40, -1))
    median = float(np.median(pose[:, 15, 1]))
    check(cost[:5].min() < 1e-9 and abs(median - 0.7) < 1e-9, "the low hands are costed when raised ones are most")


def made_face():
    """468 points in a face's places: the named rings where a face has them, the rest scattered inside."""
    import numpy as np
    rng = np.random.default_rng(1)
    pts = np.zeros((actor.FACE_POINTS, 2))
    for i in range(actor.FACE_POINTS):
        while True:
            p = rng.uniform(-1, 1, 2)
            if p @ p < 0.8:
                break
        pts[i] = p * np.array([0.8, 1.0])

    def ring(idx, c, rx, ry):
        # from the top, round (MediaPipe's oval starts at the forehead and reaches the chin half way)
        for k, i in enumerate(idx):
            a = -math.pi / 2 + 2 * math.pi * k / len(idx)
            pts[i] = [c[0] + rx * math.cos(a), c[1] + ry * math.sin(a)]

    ring(actor.OVAL, (0.0, 0.0), 0.8, 1.0)
    ring(actor.LIPS_OUTER, (0.0, 0.55), 0.25, 0.09)
    ring(actor.LIPS_INNER, (0.0, 0.55), 0.18, 0.03)
    ring(actor.EYE_RIGHT, (-0.33, -0.15), 0.12, 0.04)
    ring(actor.EYE_LEFT, (0.33, -0.15), 0.12, 0.04)
    for k, i in enumerate(actor.BROWS):
        pts[i] = [(-0.5 + 0.08 * (k % 10)) * (1 if k < 10 else -1), -0.33]
    pts[actor.NOSE_TIP] = [0.0, 0.18]
    pts[actor.SUBNASALE] = [0.0, 0.33]
    return pts


def test_rig(tmp):
    """The rig made on a made still: its masks hold the lips and the eyes and nothing else; the lids
    move with the eyes and the brows never; the lips move with the mouth."""
    import numpy as np
    import cv2
    face = made_face()
    W, H = 1920, 1080
    px = face * 200.0 + np.array([960.0, 500.0])
    pts = [[x / W, y / H, 0.0] for x, y in px] + [[0.5, 0.5, 0.0]] * 10
    stills = os.path.join(tmp, "stills.json")
    actor.write_json(stills, {"stills": [{"size": [W, H], "points": pts}]})
    out = os.path.join(tmp, "rig.json")
    code = actor.cmd_rig(argparse.Namespace(stills=stills, out=out, ring1=1.35, ring2=2.0, ring_moves=0.6,
                                            box_width=512, progress=""))
    rig = actor.read_json(out) if code == 0 else None
    check(rig is not None, "the rig was not made from a still")
    if rig is None:
        return
    x0, y0, x1, y1 = rig["box"]
    iw, ih = rig["image"]
    mouth = cv2.imread(os.path.join(tmp, "mask_mouth.png"), 0)
    eyes = cv2.imread(os.path.join(tmp, "mask_eyes.png"), 0)

    def at(m, p):
        x = int((p[0] - x0) / (x1 - x0) * iw)
        y = int((p[1] - y0) / (y1 - y0) * ih)
        return int(m[min(ih - 1, max(0, y)), min(iw - 1, max(0, x))])

    lip = px[actor.LIPS_OUTER].mean(axis=0)
    eye = px[actor.EYE_RIGHT].mean(axis=0)
    nose = px[actor.NOSE_TIP]
    check(at(mouth, lip) > 200 and at(eyes, eye) > 200, "the masks do not hold the lips (%d) and the eyes (%d)" % (at(mouth, lip), at(eyes, eye)))
    check(at(mouth, eye) < 10 and at(mouth, nose) < 10 and at(eyes, lip) < 10 and at(eyes, nose) < 10,
          "a mask reaches where it should not: mouth at the eye %d, at the nose %d; eyes at the lips %d, at the nose %d" % (
              at(mouth, eye), at(mouth, nose), at(eyes, lip), at(eyes, nose)))
    ew = np.array(rig["eye_weights"])
    mw = np.array(rig["weights"])
    check(ew[actor.EYE_RIGHT].min() == 1.0 and ew[actor.BROWS].max() == 0.0 and ew[actor.LIPS_OUTER].max() == 0.0,
          "the lids do not move with the eyes, or the brows or lips do")
    check(mw[actor.LIPS_OUTER].min() == 1.0 and mw[actor.EYE_RIGHT].max() == 0.0, "the lips do not move with the mouth, or the eyes do")
    # its body: a weight for every bone and every vertex past the near ring, the frame's edge on none
    body = rig["stills"][0]
    rest = len(actor.OVAL) + len(body["body"]) + len(rig["anchors"])
    check(sorted(body["skin"]) == sorted(actor.BONES) and all(len(v) == rest for v in body["skin"].values()),
          "the still's skin does not weigh every vertex on every bone")
    check(all(max(v[-len(rig["anchors"]):]) == 0.0 for v in body["skin"].values()), "the frame's edge moves with a bone")
    check(set(body["skeleton"]) == {"neck", "hip", "width", "l", "r"}, "the still's skeleton is %s" % sorted(body["skeleton"]))


def test_skin():
    """THE BODY'S BONES (the fourth pass): a made seated pose's skeleton - the hips under the neck, a hand
    seen in the picture resting and one seen too faintly not - and each place weighed to the bone it is on:
    the torso's middle to the torso, a resting wrist to its hand, a forearm to the forearm, the head to the
    head, the room to nothing; no place weighs more than whole."""
    import numpy as np
    W, H = 1920, 1080
    pose = np.zeros((33, 4))

    def put(k, x, y, v=0.9):
        pose[k] = [x / W, y / H, 0.0, v]

    put(11, 1150, 560)
    put(12, 770, 560)
    put(13, 1250, 820)
    put(14, 670, 820)
    put(15, 1050, 980)
    put(16, 700, 990, 0.2)
    put(17, 1010, 1010)
    put(19, 1000, 990)
    put(18, 680, 1030, 0.2)
    put(20, 670, 1020, 0.2)
    face = made_face() * 160.0 + np.array([960.0, 300.0])
    matte = np.zeros((H, W), np.float32)
    matte[440:, 600:1320] = 1.0
    matte[120:440, 820:1100] = 1.0
    skel = actor.skeleton(pose.reshape(-1), W, H)
    check(skel["l"]["rests"] and not skel["r"]["rests"], "a hand seen in the picture does not rest, or one seen faintly does")
    # hands clasped: one faint beside one that rests rests too
    clasped = pose.copy()
    clasped[16, :2] = [1000 / W, 1000 / H]
    check(actor.skeleton(clasped.reshape(-1), W, H)["r"]["rests"], "a faint hand clasped in a resting one does not rest")
    check(abs(skel["hip"][1] - (560 + actor.TORSO * 380)) < 1e-6 and abs(skel["hip"][0] - 960) < 1e-6,
          "the unseen hips are not under the neck (%s)" % str(skel["hip"]))
    places = {"torso": (960, 760), "hand_l": (1040, 985), "fore_l": (1150, 900), "head": (960, 300)}
    pts = np.array(list(places.values()) + [(100.0, 100.0)], dtype=np.float64)
    wts = actor.skin_weights(pts, face, pose.reshape(-1), matte, W, H)
    for n, (bone, _) in enumerate(places.items()):
        got = actor.BONES[int(wts[n].argmax())]
        check(got == bone and wts[n].max() > 0.6, "a place on the %s weighs most on the %s (%.2f)" % (bone, got, wts[n].max()))
    check(wts[-1].sum() < 1e-9, "the room weighs %.3f on the body" % wts[-1].sum())
    check(wts.sum(axis=1).max() <= 1.0 + 1e-9, "a place weighs %.3f, more than whole" % wts.sum(axis=1).max())


def test_front():
    """WHAT NEVER MOVES ([still_room]): a thing that never moves and hides them where they are (a
    microphone) is drawn before them - their matte kept whole under it and their picture filled there; one
    that never moves where they are not (the wall their matte bled over) leaves their matte; what moves
    (them) stays theirs. The control: with nothing still, there is no front and the matte is as it was."""
    import numpy as np
    H, W = 120, 200
    rng = np.random.default_rng(5)
    still = rng.integers(60, 120, (H, W, 3)).astype(np.uint8)
    still[40:80, 90:110] = 10                       # the microphone: dark, before them
    matte = np.zeros((H, W), np.float32)
    matte[20:, 50:150] = 1.0                        # them
    matte[40:80, 90:110] = 0.0                      # ...the segmentation left the microphone out
    plate = np.full((H, W, 3), 128.0)
    seen = matte <= 0.5
    there = np.where(matte > 0.5, 0.8, 0.0)
    there[40:80, 90:110] = 0.7
    steady = np.zeros((H, W))
    front = np.zeros((H, W))
    steady[30:110, 85:125] = 0.9
    front[30:110, 85:125] = 0.9
    steady[20:120, 140:150] = 0.9                   # their matte's edge over the wall: still, not before them
    steady[95:105, 60:70] = 0.9                     # a fleck of them that happened to stay: too small to be a thing
    front[95:105, 60:70] = 0.9
    steady[60:72, 68:80] = 0.9                      # ...and one inside them, not before them: theirs
    m, room, fr, body = actor.still_room(still, matte, plate, seen, {"still": steady, "front": front}, there)
    check(fr is not None and fr[60, 100] > 0.9 and fr[60, 70] == 0.0, "the microphone is not drawn before them, or they are")
    check(m[60, 100] > 0.9, "their matte has a hole the microphone's shape (%.2f): it would move with them" % m[60, 100])
    check(m[60, 146] < 0.1 and m[60, 120] > 0.9, "the wall stayed in their matte (%.2f), or they left it (%.2f)" % (m[60, 146], m[60, 120]))
    check(np.abs(body[60, 100].astype(int) - 10).max() > 20, "their picture under the microphone is the microphone")
    check(fr[100, 65] == 0.0 and m[66, 74] > 0.9, "a fleck of them was drawn before them, or cut out of them")
    m2, _, fr2, body2 = actor.still_room(still, matte, plate, seen, {"still": np.zeros((H, W)), "front": np.zeros((H, W))}, there)
    check(fr2 is None and np.allclose(m2, matte) and body2 is still, "with nothing still, a front was found or the matte changed")
    # a microphone the segmentation left wholly out of them, as wide as a real one, is before them all the same
    wide = matte.copy()
    wide[30:110, 85:125] = 0.0
    m3, _, fr3, _ = actor.still_room(still, wide, plate, seen, {"still": steady, "front": front}, there)
    check(fr3 is not None and fr3[60, 105] > 0.9 and m3[60, 105] > 0.9,
          "a microphone left out of their matte is not drawn before them, they not whole under it")


def test_front_outlined():
    """A THING BEFORE THEM HAS AN OUTLINE OF ITS OWN ([outlined]): them in a plain black shirt, two pieces judged never
    to move where they are - a light microphone, its edge in the still, is drawn before them; a piece of the plain shirt,
    still only for being plain, is not (the control: it passed every other test, its size and where they are)."""
    import numpy as np
    H, W = 160, 260
    still = np.full((H, W, 3), 128, np.uint8)
    still[30:, 40:220] = 20                         # them, in a black shirt
    still[40:120, 140:190] = 150                    # the microphone before them
    matte = np.zeros((H, W), np.float32)
    matte[30:, 40:220] = 1.0
    plate = np.full((H, W, 3), 128.0)
    there = np.where(matte > 0.5, 0.8, 0.0)
    judged = np.zeros((H, W))
    judged[40:120, 140:190] = 0.9                   # the microphone
    judged[60:140, 60:110] = 0.9                    # a plain piece of the shirt
    _m, _room, fr, _body = actor.still_room(still, matte, plate, matte <= 0.5, {"still": judged, "front": judged}, there)
    check(fr is not None and fr[80, 165] > 0.9, "the microphone, outlined, is not drawn before them")
    check(fr is not None and fr[100, 85] == 0.0, "a plain piece of their shirt was drawn before them")


def test_shade():
    """THE LIGHT ROUND THEM: their shadow on the wall beside them in the still, not in the plate, darkens the
    plate behind their edge - and a plate lit as the still is is left as it is (the control)."""
    import numpy as np
    H, W = 120, 200
    still = np.full((H, W, 3), 150, np.uint8)
    still[:, 100:] = 60                              # them, on the right
    still[:, 80:100] = 110                           # their shadow on the wall beside them
    matte = np.zeros((H, W), np.float32)
    matte[:, 100:] = 1.0
    plate = np.full((H, W, 3), 150.0)
    trusted = np.ones((H, W), bool)
    judged = {"still": np.zeros((H, W)), "front": np.zeros((H, W))}
    _, room, _, _ = actor.still_room(still, matte, plate, trusted, judged, np.zeros((H, W)))
    check(room[60, 105, 0] < 140, "the plate behind their edge is %d, not darkened as their shadow is" % room[60, 105, 0])
    plain = still.copy()
    plain[:, 80:100] = 150
    _, room2, _, _ = actor.still_room(plain, matte, plate, trusted, judged, np.zeros((H, W)))
    check(abs(int(room2[60, 105, 0]) - 150) <= 2, "a plate lit as the still is was changed (%d)" % room2[60, 105, 0])


def test_soft_edge():
    """THEIR SOFT EDGE AWAY FROM THE HEAD shows the still's own room - at rest the picture is the still - and
    round the head the plate reaches past it (the control: no hair left on the wall)."""
    import numpy as np
    H, W = 120, 200
    still = np.full((H, W, 3), 160, np.uint8)       # the wall
    still[40:, 60:100] = 40                          # a dark chair behind their soft edge, below the head
    still[:40, 90:100] = 50                          # ...and hair in it, round the head
    still[:, 100:] = 90
    matte = np.zeros((H, W), np.float32)
    matte[:, 100:] = 1.0
    matte[:, 90:100] = 0.3                           # the soft edge
    plate = np.full((H, W, 3), 160.0)                # the wall the frames saw there
    trusted = np.ones((H, W), bool)
    judged = {"still": np.zeros((H, W)), "front": np.zeros((H, W))}
    head = np.zeros((H, W), bool)
    head[:40] = True
    _, room, _, _ = actor.still_room(still, matte, plate, trusted, judged, np.zeros((H, W)), head)
    check(abs(int(room[80, 95, 0]) - 40) <= 3, "under their soft edge the room is %d, not the still's own" % room[80, 95, 0])
    check(int(room[20, 95, 0]) > 100, "round the head the room under their edge is the still's, hair and all (%d)" % room[20, 95, 0])


def test_trust():
    """THE PLATE IS TRUSTED where a quarter of the frames saw the room, or a few that agree - not a few that
    do not (their own shape the segmentation missed, a globe held up), nor fewer than a few."""
    import numpy as np
    n = 150
    seen = np.array([0.3, 6 / n, 6 / n, 3 / n, 0.3])
    agree = np.array([0.2, 0.9, 0.4, 1.0, 1.0])
    check(actor.trust(seen, agree, n).tolist() == [True, True, False, False, True],
          "the plate is trusted at %s" % actor.trust(seen, agree, n).tolist())


def test_posture():
    """THEIR POSTURE ([posture_of]): from shoulders that wander slowly, with a quick sway on top, its spread
    and how long it holds come back - and a posture that wanders quicker holds for less (the control)."""
    import numpy as np

    def made(tau, seed):
        rng = np.random.default_rng(seed)
        n = 4000
        a = math.exp(-0.2 / tau)
        x = np.zeros(n)
        for i in range(1, n):
            x[i] = a * x[i - 1] + math.sqrt(1 - a * a) * rng.normal(0.0, 0.03)
        quick = 0.01 * np.sin(np.arange(n) * 0.2 * 2 * math.pi / 2.5)
        pose = np.zeros((n, 33, 4))
        pose[:, 11, :] = [0.6, 0.5, 0.0, 1.0]
        pose[:, 12, :] = [0.4, 0.5, 0.0, 1.0]
        pose[:, 11, 0] += x + quick
        pose[:, 12, 0] += x + quick
        R = {"count": n, "box": np.tile([0.45, 0.2, 0.55, 0.4], (n, 1)), "pose": pose.reshape(n, -1),
             "angles": np.zeros((n, 3)), "vid": np.array(["v"] * n, dtype=object), "piece": np.zeros(n, dtype=int),
             "time": np.arange(n) / 5.0}
        return actor.posture_of(R, [np.arange(n)], 5.0, 1.0, {"videos": {"v": {"size": [1920, 1080]}}}), x

    slow, x = made(10.0, 1)
    want = x.std() / 0.1
    check(abs(slow["sd"][0] - want) < 0.35 * want, "the posture's spread across is %.3f, not near %.3f" % (slow["sd"][0], want))
    check(7.0 <= slow["tau"] <= 20.0, "a posture that wanders over 10 s holds %.1f s" % slow["tau"])
    fast, _ = made(1.5, 2)
    check(fast["tau"] < slow["tau"] * 0.6, "a quicker posture holds %.1f s against %.1f: the measure cannot tell" % (fast["tau"], slow["tau"]))


def test_learn():
    """The ensemble learns what lies round a moment: a mouth that starts closing 120 ms before a closing
    sound, which each sound's mean mouth (one class at the moment) cannot know."""
    import numpy as np
    rng = np.random.default_rng(4)
    classes = ["rest", "open", "pbm"]
    phones, t = [], 0.0
    while t < 1800.0:
        c = rng.choice(["open", "pbm", "open"])
        d = rng.uniform(0.06, 0.16)
        phones.append({"vid": "v", "t0": t, "t1": t + d, "class": str(c)})
        t += d + (rng.uniform(0.3, 0.8) if rng.random() < 0.08 else 0.0)
    line = actor.class_line(phones)
    t0, t1, cl = line["v"]
    times = np.arange(0.5, t - 0.5, 0.2)

    def truth(tt):
        # open while a vowel is heard, but closing from 120 ms before a closing sound
        i = np.searchsorted(t0, tt, side="right") - 1
        later = np.searchsorted(t0, tt + 0.12, side="right") - 1
        now_open = (i >= 0) & (tt < t1[np.clip(i, 0, None)]) & (np.array(cl)[np.clip(i, 0, None)] == "open")
        soon = np.array(cl)[np.clip(later, 0, None)] == "pbm"
        return np.where(now_open & ~soon, 1.0, 0.0)

    X = actor.contexts(line, "v", times, classes)
    Y = np.stack([truth(times)] + [rng.normal(0, 0.05, times.size) for _ in range(2)], axis=1) + rng.normal(0, 0.05, (times.size, 3))
    split = int(times.size * 0.7)
    weights = np.array([1.0, 0.01, 0.01])
    members = [actor.train_member(X[:split], Y[:split], seed=k, epochs=15, hidden=16) for k in range(3)]
    ens = actor.ensemble_predict(members, X[split:])
    centre = actor.OFFSETS.index(0.0) * len(classes)
    means = {c: Y[:split][np.argmax(X[:split, centre:centre + 3], axis=1) == c].mean(axis=0) for c in range(3)}
    plain = np.array([means[int(np.argmax(x[centre:centre + 3]))] for x in X[split:]])
    got, base = actor.r2(ens, Y[split:], weights), actor.r2(plain, Y[split:], weights)
    check(got > base + 0.1, "the ensemble explains %.2f of the mouth on unseen speech, each sound's mean %.2f" % (got, base))
    shuffled = Y[:split][rng.permutation(split)]
    noise = [actor.train_member(X[:split], shuffled, seed=k, epochs=15, hidden=16) for k in range(2)]
    check(actor.r2(actor.ensemble_predict(noise, X[split:]), Y[split:], weights) < 0.05,
          "trained on shuffled mouths, it still explains the mouth (the check can fail)")
    a_ = actor.train_member(X[:500], Y[:500], seed=3, epochs=2, hidden=8)
    b_ = actor.train_member(X[:500], Y[:500], seed=3, epochs=2, hidden=8)
    check(all(np.array_equal(p, q) for p, q in zip(a_, b_)), "one seed trained two networks")
    # the shares sum to 1 in each window (the rest takes what nothing fills)
    k = len(classes)
    sums = X.reshape(X.shape[0], len(actor.OFFSETS), k).sum(axis=2)
    check(np.allclose(sums, 1.0, atol=1e-5), "a window's shares do not sum to one (%.3f to %.3f)" % (sums.min(), sums.max()))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ffmpeg", default="")
    a = ap.parse_args()
    ffmpeg = a.ffmpeg
    if not ffmpeg:
        import glob
        fetched = sorted(glob.glob(os.path.expanduser("~/.local/share/godot/app_userdata/ghost/tools/ffmpeg/*/ffmpeg")))
        ffmpeg = fetched[-1] if fetched else ""
    if not os.path.exists(ffmpeg):
        import shutil
        ffmpeg = shutil.which("ffmpeg") or ""
    with tempfile.TemporaryDirectory(dir=os.path.expanduser("~")) as tmp:
        test_warp_round_trip()
        test_sets()
        test_format(tmp)
        test_survey_records(tmp)
        test_motion()
        test_face_motion()
        test_targets()
        test_hands()
        test_rig(tmp)
        test_skin()
        test_front()
        test_front_outlined()
        test_trust()
        test_shade()
        test_soft_edge()
        test_posture()
        test_learn()
        if ffmpeg and os.path.exists(ffmpeg):
            test_cuts(ffmpeg, tmp)
        else:
            print("   skip  the cuts: no FFmpeg (pass --ffmpeg)")
    print("\n%d failure%s" % (len(FAILS), "" if len(FAILS) == 1 else "s"))
    return 1 if FAILS else 0


if __name__ == "__main__":
    sys.exit(main())
