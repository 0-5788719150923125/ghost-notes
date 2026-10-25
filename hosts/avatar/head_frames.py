#!/usr/bin/env python3
"""head_frames.py - the moments of one video their head is learned from, with every other video's
(next/likeness.md, "One head").

    <face_venv python> head_frames.py --ffmpeg <ffmpeg> --spec <spec.json> [--progress <file>]

The spec: {"video", "survey", "shots": [[t0, t1], ...], "count", "face_model", "pose_model", "out"} and, for a
set's own moments, "stills" - the video, its survey, the stretches of it in one camera placement (its largest
set's usable shots, or the set's), how many moments to take, MediaPipe's two models and the set's stills (their
points, scores and pose are written as frames.py writes them: `still_points` ...).

ONE HEAD FOR EVERY SET (the user, 2026-10-23: "It's pointless to build a gaussian splatting model if the scenes
can only generate from a single set of images"): a set's avatar had learned from one shot of one video, so it
knew only what that shot showed - an ASMR video's mouth barely opens. The head is now learned from moments of
every video at once (head.py), and THESE ARE ONE VIDEO'S: picked from its survey (every 0.2 s: the face's 52
scores, its turn), never read whole -
- HALF FOR WHAT THEY SHOW (`DIVERSE`): taken farthest-first in the scores and the turn (`WEIGHTS`, the mouth
  most), so a rare open mouth, a pucker or a turned head is taken as surely as the common rest;
- HALF EVENLY THROUGH THE VIDEO, so the light of each part of it and their usual face are there too;
- none within SPACED seconds of another, none with a hand at the mouth (it teaches nothing of the face).

Each moment is read at full size (`actor.frame_at`) and looked at as frames.py looks at a frame: the face close
(a square round its survey box, AVATAR_FACE of the face's height), the body and the person in the whole.

Writes, as frames.py does (head.py and train.Frames read either): <out>/img/<k>.jpg, <out>/mask/<k>.png,
<out>/frames.npz (t, found, hands, points, blend, matrix, pose) and <out>/spec.json ({"crop": [0, 0, w, h]}).

A VIDEO THAT SHOWS NO FACE OF THEIRS IS ANSWERED, NOT FAILED (2026-10-24: a video of ants found none in 131 s, and
its error stood on the card): with no moment in its shots or no face found in any, a video's are written empty -
the head learns nothing from it (head.py leaves out a video with too few) - but a set's (the spec's "stills") fail:
a set is made from them.
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
import frames  # noqa: E402
import head  # noqa: E402

# The share of the moments picked for what they show; the rest are spread evenly through the video.
DIVERSE = 0.5
# How the face's scores weigh in what a moment shows (the rest 0); its turn weighs 1 a TURN_UNIT degrees.
WEIGHTS = {"jawOpen": 3.0, "mouthFunnel": 2.0, "mouthPucker": 2.0, "mouthSmileLeft": 1.5, "mouthSmileRight": 1.5,
           "mouthStretchLeft": 1.0, "mouthStretchRight": 1.0, "mouthClose": 1.0, "mouthLowerDownLeft": 1.0,
           "mouthLowerDownRight": 1.0, "mouthUpperUpLeft": 1.0, "mouthUpperUpRight": 1.0, "mouthRollLower": 1.0,
           "mouthRollUpper": 1.0, "mouthPressLeft": 0.5, "mouthPressRight": 0.5, "mouthShrugLower": 0.5,
           "mouthShrugUpper": 0.5, "browInnerUp": 0.7, "browDownLeft": 0.5, "browDownRight": 0.5,
           "browOuterUpLeft": 0.5, "browOuterUpRight": 0.5, "eyeSquintLeft": 0.4, "eyeSquintRight": 0.4,
           "eyeWideLeft": 0.4, "eyeWideRight": 0.4, "cheekSquintLeft": 0.4, "cheekSquintRight": 0.4}
TURN_UNIT = 15.0
# No two moments nearer than this, in seconds.
SPACED = 0.6
# The square the face is read close in: this many of the face's height, as the set's frames are read.
AVATAR_FACE = 2.33
# What one moment's row holds beyond the moment itself (an empty frames.npz is shaped as a full one).
ROW = {"t": ((), "float64"), "found": ((), "bool"), "hands": ((), "bool"), "points": ((478, 3), "float32"),
       "blend": ((52,), "float32"), "matrix": ((16,), "float32"), "pose": ((132,), "float32")}


def features(R):
    """What each survey look shows, weighed: [n, 52 + 3] - its scores by WEIGHTS and its turn by TURN_UNIT."""
    import numpy as np
    w = np.array([WEIGHTS.get(n, 0.0) for n in actor.BLEND_NAMES[:52]], np.float32)
    return np.concatenate([R["blend"][:, :52] * w, R["angles"].astype(np.float32) / TURN_UNIT], 1)


def pick(R, count: int, rng):
    """[param count] of the looks [param R] (indices): DIVERSE of them farthest-first in what they show, the rest
    evenly through time; none nearer than SPACED to another, none with a hand at the mouth."""
    import numpy as np
    n = int(R["count"])
    ok = ~actor.hands_at_mouth_all(R["pose"], R["box"]) if n else np.zeros(0, bool)
    cand = np.nonzero(ok)[0]
    if cand.size == 0:
        return []
    f = features(R)[cand]
    taken = []
    # farthest first, from the look nearest their median face
    d = np.linalg.norm(f - np.median(f, 0), axis=1)
    want = max(1, int(round(count * DIVERSE)))
    at = int(d.argmin())
    near = np.full(cand.size, np.inf)
    times = R["time"]
    while len(taken) < want:
        i = int(cand[at])
        if all(abs(times[i] - times[j]) >= SPACED for j in taken):
            taken.append(i)
        near = np.minimum(near, np.linalg.norm(f - f[at], axis=1))
        near[at] = -1.0
        if near.max() <= 0.0:
            break
        at = int(near.argmax())
    # evenly through time: at each of the times spread over the video, the free look nearest it
    chosen = set(taken)
    left = np.array([i for i in cand if i not in chosen])
    need = count - len(taken)
    if left.size and need > 0:
        order = left[np.argsort(times[left])]
        at_t = times[order]
        for target in np.linspace(at_t[0], at_t[-1], need):
            j = int(np.searchsorted(at_t, target))
            for k in sorted(range(max(0, j - 8), min(order.size, j + 8)), key=lambda k: abs(at_t[k] - target)):
                i = int(order[k])
                if i not in chosen and all(abs(times[i] - times[q]) >= SPACED for q in taken):
                    taken.append(i)
                    chosen.add(i)
                    break
    return sorted(taken, key=lambda i: times[i])


def face_crop(box, w: int, h: int):
    """[x, y, size]: the square the face in normalized [param box] is read close in."""
    fh = (box[3] - box[1]) * h
    side = int(min(min(w, h), max(256, round(AVATAR_FACE * fh / 16.0) * 16)))
    cx = (box[0] + box[2]) * 0.5 * w
    cy = (box[1] + box[3]) * 0.5 * h + 0.05 * fh
    return [int(min(max(0, round(cx - side / 2)), w - side)), int(min(max(0, round(cy - side / 2)), h - side)), side]


def write(out: str, w: int, h: int, video: str, rows: dict) -> None:
    """<out>/spec.json and <out>/frames.npz, each written whole (a row-less key shaped as ROW has it)."""
    import numpy as np
    os.makedirs(out, exist_ok=True)
    with open(os.path.join(out, "spec.json.part"), "w") as fh:
        json.dump({"crop": [0, 0, w, h], "video": video}, fh)
    os.replace(os.path.join(out, "spec.json.part"), os.path.join(out, "spec.json"))
    shaped = lambda key, v: np.zeros((0,) + ROW[key][0], ROW[key][1]) if key in ROW and not len(v) else np.asarray(v)
    np.savez(os.path.join(out, "frames.npz.part"), **{key: shaped(key, v) for key, v in rows.items()})
    os.replace(os.path.join(out, "frames.npz.part.npz"), os.path.join(out, "frames.npz"))


def none_of_theirs(a, spec: dict, w: int, h: int, why: str) -> int:
    """A video with no moment of theirs to read: the head's are written empty (done), a set's fail."""
    if "stills" in spec:
        actor.say("head frames: %s" % why)
        return 2
    write(spec["out"], w, h, spec["video"], {key: [] for key in ROW})
    actor.say("head frames: %s - the head learns nothing from this video" % why)
    if a.progress:
        actor.progress(a.progress, 1.0)
    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--ffmpeg", required=True)
    ap.add_argument("--spec", required=True)
    ap.add_argument("--progress", default="")
    a = ap.parse_args()
    import numpy as np
    from PIL import Image
    spec = actor.read_json(a.spec)
    out = spec["out"]
    p = actor.probe(a.ffmpeg, spec["video"])
    w, h = int(p["width"]), int(p["height"])
    if w <= 0 or h <= 0:
        actor.say("head frames: the video cannot be read (%s)" % spec["video"])
        return 2
    R = actor.survey_records({"v": {"survey": spec["survey"]}},
                             [{"vid": "v", "start": float(t0), "end": float(t1)} for t0, t1 in spec["shots"]])
    picks = pick(R, int(spec.get("count", 300)), np.random.default_rng(0))
    if not picks:
        return none_of_theirs(a, spec, w, h, "no moment of theirs in this video's shots")
    os.makedirs(os.path.join(out, "img"), exist_ok=True)
    os.makedirs(os.path.join(out, "mask"), exist_ok=True)
    watch = actor.Watcher(spec["face_model"], spec["pose_model"], masks=True, image=True)
    scale = np.array([w, h, w], np.float32)
    rows = {"t": [], "found": [], "hands": [], "points": [], "blend": [], "matrix": [], "pose": []}
    k = 0
    for n, i in enumerate(picks):
        t = float(R["time"][i])
        rgb = actor.frame_at(a.ffmpeg, spec["video"], t, w, h)
        if rgb is None:
            continue
        try:
            rec = frames.look(watch, rgb, face_crop(R["box"][i], w, h))
        except RuntimeError as exc:
            # MediaPipe's own failure on one picture: that moment is left out, and the landmarkers made again (a graph
            # that failed fails every picture after it)
            actor.say("head frames: a moment at %.1f s left out (%s)" % (t, str(exc).splitlines()[0][:80]))
            watch = actor.Watcher(spec["face_model"], spec["pose_model"], masks=True, image=True)
            continue
        found = rec.get("found", 0.0) > 0.5
        seg = rec.get("segmentation")
        if not found or seg is None:
            continue
        pose = np.asarray(rec.get("pose", [0.0] * 132), np.float32)
        rows["t"].append(t)
        rows["found"].append(True)
        rows["hands"].append(bool(actor.hands_at_mouth(pose.tolist(), rec.get("box"))))
        rows["points"].append(rec["points"] * scale)
        rows["blend"].append(np.asarray(rec.get("blend", [0.0] * 52), np.float32))
        rows["matrix"].append(np.asarray(rec.get("matrix", np.zeros(16)), np.float32))
        rows["pose"].append(pose)
        Image.fromarray(rgb).save(os.path.join(out, "img", "%05d.jpg" % k), quality=94)
        seg = np.asarray(seg, np.float32).reshape(h, w)
        Image.fromarray((np.clip(seg, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8)).save(
            os.path.join(out, "mask", "%05d.png" % k))
        k += 1
        if a.progress and n % 10 == 0:
            actor.progress(a.progress, min(0.999, (n + 1) / len(picks)))
    if k == 0:
        return none_of_theirs(a, spec, w, h, "no face of theirs found in the %d moments picked" % len(picks))
    # A SET'S STILLS (spec "stills": the set's own moments are read too, for its room and its still's pose): each
    # looked at whole to find the face, then close, as the moments are
    stills = {"still_points": [], "still_blend": [], "still_pose": [], "still_found": []}
    for path in spec.get("stills", []):
        full = np.ascontiguousarray(np.asarray(Image.open(path).convert("RGB")))
        first = watch.look(full, 0)
        rec = frames.look(watch, full, face_crop(first["box"], w, h)) if first.get("found", 0.0) > 0.5 else first
        found = rec.get("found", 0.0) > 0.5
        stills["still_found"].append(found)
        stills["still_points"].append((rec["points"] if found else np.zeros((478, 3), np.float32)) * scale)
        stills["still_blend"].append(np.asarray(rec.get("blend", [0.0] * 52), np.float32))
        stills["still_pose"].append(np.asarray(rec.get("pose", [0.0] * 132), np.float32))
    if spec.get("stills"):
        rows.update(stills)
    write(out, w, h, spec["video"], rows)
    jaw = np.asarray(rows["blend"])[:, actor.BLEND_NAMES.index("jawOpen")]
    few = " - too few, the head leaves this video out" if k < head.LEAST and "stills" not in spec else ""
    actor.say("head frames: %d moment%s of %d looks (jawOpen past 0.35 in %d, its 90th percentile %.2f)%s"
              % (k, "" if k == 1 else "s", int(R["count"]), int((jaw > 0.35).sum()), float(np.percentile(jaw, 90)),
                 few))
    if a.progress:
        actor.progress(a.progress, 1.0)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
