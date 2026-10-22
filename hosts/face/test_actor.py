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
- a sound's target is pushed past their own on the shapes that show, never on mouthClose;
- a hand up is costed and a hand at rest is not - where rest is the low end of where their hands are seen;
- the rig made on a made still masks the lips and the eyes and nothing else, the lids move with the eyes
  and the brows never.
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
        test_targets()
        test_hands()
        test_rig(tmp)
        if ffmpeg and os.path.exists(ffmpeg):
            test_cuts(ffmpeg, tmp)
        else:
            print("   skip  the cuts: no FFmpeg (pass --ffmpeg)")
    print("\n%d failure%s" % (len(FAILS), "" if len(FAILS) == 1 else "s"))
    return 1 if FAILS else 0


if __name__ == "__main__":
    sys.exit(main())
