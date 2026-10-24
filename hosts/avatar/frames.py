#!/usr/bin/env python3
"""frames.py - the frames an actor's head is learned from (next/likeness.md, "A head of splats").

    <face_venv python> frames.py --ffmpeg <ffmpeg> --spec <spec.json> [--progress <file>]

The spec: {"video", "shots": [[t0, t1], ...], "crop": [x, y, w, h], "rate", "face_model", "pose_model",
"stills", "out"} - one set's video (a fixed camera), the stretches of it to read, the part of the frame read
(full-resolution pixels; [x, y, size] for a square; the whole frame for a whole person), how many frames a
second, MediaPipe's two models, the set's stills (full frames: they are played on one of them) and the
folder.

Writes <out>/img/<k>.jpg (the crop at full resolution), <out>/mask/<k>.png (the person, MediaPipe's own
segmentation of the crop) and <out>/frames.npz:
- t [N] (seconds into the video), found [N] (a face seen), hands [N] (a hand at the mouth: a frame that
  teaches nothing about the face);
- points [N, 478, 3]: the face's points in crop pixels, z on x's scale (MediaPipe's own: depth relative
  to the head's centre);
- blend [N, 52]: MediaPipe's expression scores; matrix [N, 16]: the head's transform (the canonical face
  into a camera it assumes); pose [N, 132]: the body's 33 points (x, y, z, visibility), in the crop;
- still_points [S, 478, 3], still_blend [S, 52], still_pose [S, 132], still_found [S]: the same of each
  still, cropped alike.

EACH FRAME IS A PICTURE OF ITS OWN (MediaPipe in IMAGE mode): frames half a second apart are not a video
to track through, and one face's places must not be carried into the next.

THE FACE IS READ CLOSE (spec "face_crop": [x, y, size], in the part read): MediaPipe's face model on a square
round the head, its pose and person on the whole - in a whole 1920x1080 frame the face is small to it, and
the rig's scores explained 48% of his face's movement read so, 56% read close.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "face"))

import actor  # noqa: E402 - the face host's MediaPipe, its readers and its rules of a usable frame


def crops(ffmpeg: str, video: str, t0: float, t1: float, rate: float, x: int, y: int, w: int, h: int):
    """Yield (t, rgb [h, w, 3]) every 1/[rate] s of [t0, t1], the part at (x, y), full resolution."""
    import numpy as np
    cmd = [ffmpeg, "-v", "error", "-nostdin", "-ss", "%.4f" % t0, "-i", video, "-t", "%.4f" % (t1 - t0),
           "-vf", "fps=%g,crop=%d:%d:%d:%d" % (rate, w, h, x, y), "-an", "-f", "rawvideo",
           "-pix_fmt", "rgb24", "-"]
    n = w * h * 3
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stdin=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                         bufsize=n * 4)
    k = 0
    try:
        while True:
            b = p.stdout.read(n)
            if len(b) < n:
                break
            yield t0 + k / rate, np.frombuffer(b, dtype=np.uint8).reshape(h, w, 3)
            k += 1
    finally:
        p.stdout.close()
        p.kill()
        p.wait()


def look(watch, rgb, face_crop):
    """The face and body in one frame (the Watcher's record): the face read in [face_crop] of it - [x, y, size],
    its points brought back to the whole frame's terms - the pose and the person in the whole."""
    import numpy as np
    if not face_crop:
        return watch.look(rgb, 0)
    fx, fy, fs = face_crop
    h, w = rgb.shape[:2]
    mp = watch.mp
    rec = {"found": 0.0}
    pr = watch.pose.detect(mp.Image(image_format=mp.ImageFormat.SRGB, data=np.ascontiguousarray(rgb)))
    if pr.pose_landmarks:
        rec["pose"] = [c for p in pr.pose_landmarks[0] for c in (p.x, p.y, p.z, p.visibility)]
    if pr.segmentation_masks:
        rec["segmentation"] = np.array(pr.segmentation_masks[0].numpy_view(), copy=True)
    fr = watch.face.detect(mp.Image(image_format=mp.ImageFormat.SRGB,
                                    data=np.ascontiguousarray(rgb[fy:fy + fs, fx:fx + fs])))
    if fr.face_landmarks and len(fr.face_landmarks[0]) >= 478:
        pts = np.array([(p.x * fs + fx, p.y * fs + fy, p.z * fs) for p in fr.face_landmarks[0][:478]], np.float32)
        pts /= np.array([w, h, w], np.float32)
        rec["found"] = 1.0
        rec["points"] = pts
        rec["box"] = [float(pts[:468, 0].min()), float(pts[:468, 1].min()), float(pts[:468, 0].max()),
                      float(pts[:468, 1].max())]
        if fr.face_blendshapes:
            rec["blend"] = [c.score for c in fr.face_blendshapes[0]][:52]
        if fr.facial_transformation_matrixes:
            rec["matrix"] = np.asarray(fr.facial_transformation_matrixes[0], dtype=np.float32).reshape(-1)
    return rec


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
    c = [int(v) for v in spec["crop"]]
    x, y, w, h = c if len(c) == 4 else (c[0], c[1], c[2], c[2])
    scale = np.array([w, h, w], np.float32)
    rate = float(spec.get("rate", 2.0))
    fc = spec.get("face_crop")
    face_crop = (int(fc[0]) - x, int(fc[1]) - y, int(fc[2])) if fc else None
    os.makedirs(os.path.join(out, "img"), exist_ok=True)
    os.makedirs(os.path.join(out, "mask"), exist_ok=True)
    watch = actor.Watcher(spec["face_model"], spec["pose_model"], masks=True, image=True)
    total = sum(max(0.0, t1 - t0) for t0, t1 in spec["shots"]) * rate
    rows = {"t": [], "found": [], "hands": [], "points": [], "blend": [], "matrix": [], "pose": []}
    k = 0
    for t0, t1 in spec["shots"]:
        for t, rgb in crops(a.ffmpeg, spec["video"], float(t0), float(t1), rate, x, y, w, h):
            rec = look(watch, rgb, face_crop)
            found = rec.get("found", 0.0) > 0.5
            pts = rec["points"] if found else np.zeros((478, 3), np.float32)
            pose = np.asarray(rec.get("pose", [0.0] * 132), np.float32)
            hands = found and actor.hands_at_mouth(pose.tolist(), rec.get("box"))
            rows["t"].append(t)
            rows["found"].append(found)
            rows["hands"].append(bool(hands))
            rows["points"].append(pts * scale)
            rows["blend"].append(np.asarray(rec.get("blend", [0.0] * 52), np.float32))
            rows["matrix"].append(np.asarray(rec.get("matrix", np.zeros(16)), np.float32))
            rows["pose"].append(pose)
            Image.fromarray(rgb).save(os.path.join(out, "img", "%05d.jpg" % k), quality=94)
            seg = rec.get("segmentation")
            if seg is not None:
                seg = np.asarray(seg, np.float32).reshape(h, w)
                Image.fromarray((np.clip(seg, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8)).save(
                    os.path.join(out, "mask", "%05d.png" % k))
            k += 1
            if a.progress and k % 20 == 0:
                actor.progress(a.progress, min(0.999, k / max(1.0, total)))
    stills = {"still_points": [], "still_blend": [], "still_pose": [], "still_found": []}
    for path in spec.get("stills", []):
        full = np.asarray(Image.open(path).convert("RGB"))
        rec = look(watch, np.ascontiguousarray(full[y:y + h, x:x + w]), face_crop)
        found = rec.get("found", 0.0) > 0.5
        stills["still_found"].append(found)
        stills["still_points"].append((rec["points"] if found else np.zeros((478, 3), np.float32)) * scale)
        stills["still_blend"].append(np.asarray(rec.get("blend", [0.0] * 52), np.float32))
        stills["still_pose"].append(np.asarray(rec.get("pose", [0.0] * 132), np.float32))
    rows.update(stills)
    np.savez(os.path.join(out, "frames.npz.part"), **{key: np.asarray(v) for key, v in rows.items()})
    os.replace(os.path.join(out, "frames.npz.part.npz"), os.path.join(out, "frames.npz"))
    found = int(np.sum(rows["found"]))
    usable = int(np.sum(np.asarray(rows["found"]) & ~np.asarray(rows["hands"])))
    actor.say("frames: %d frames, %d with a face, %d without a hand at it" % (k, found, usable))
    if a.progress:
        actor.progress(a.progress, 1.0)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
