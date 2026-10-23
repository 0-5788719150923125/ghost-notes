#!/usr/bin/env python3
"""frames.py - the frames an actor's head is learned from (next/likeness.md, "A head of splats").

    <face_venv python> frames.py --ffmpeg <ffmpeg> --spec <spec.json> [--progress <file>]

The spec: {"video", "shots": [[t0, t1], ...], "crop": [x, y, size], "rate", "face_model", "pose_model",
"stills", "out"} - one set's video (a fixed camera), the stretches of it to read, the square of the frame the
head stays in (full-resolution pixels), how many frames a second, MediaPipe's two models, the set's stills
(full frames: the head is played on one of them) and the folder.

Writes <out>/img/<k>.jpg (the crop at full resolution), <out>/mask/<k>.png (the person, MediaPipe's own
segmentation of the crop) and <out>/frames.npz:
- t [N] (seconds into the video), found [N] (a face seen), hands [N] (a hand at the mouth: a frame that
  teaches nothing about the face);
- points [N, 478, 3]: the face's points in crop pixels, z on x's scale (MediaPipe's own: depth relative
  to the head's centre);
- blend [N, 52]: MediaPipe's expression scores; matrix [N, 16]: the head's transform (the canonical face
  into a camera it assumes); pose [N, 132]: the body's 33 points (x, y, z, visibility), in the crop;
- still_points [S, 478, 3], still_blend [S, 52], still_found [S]: the same of each still, cropped alike.

EACH FRAME IS A PICTURE OF ITS OWN (MediaPipe in IMAGE mode): frames half a second apart are not a video
to track through, and one face's places must not be carried into the next.
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


def crops(ffmpeg: str, video: str, t0: float, t1: float, rate: float, x: int, y: int, size: int):
    """Yield (t, rgb [size, size, 3]) every 1/[rate] s of [t0, t1], the square at (x, y), full resolution."""
    import numpy as np
    cmd = [ffmpeg, "-v", "error", "-nostdin", "-ss", "%.4f" % t0, "-i", video, "-t", "%.4f" % (t1 - t0),
           "-vf", "fps=%g,crop=%d:%d:%d:%d" % (rate, size, size, x, y), "-an", "-f", "rawvideo",
           "-pix_fmt", "rgb24", "-"]
    n = size * size * 3
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stdin=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                         bufsize=n * 4)
    k = 0
    try:
        while True:
            b = p.stdout.read(n)
            if len(b) < n:
                break
            yield t0 + k / rate, np.frombuffer(b, dtype=np.uint8).reshape(size, size, 3)
            k += 1
    finally:
        p.stdout.close()
        p.kill()
        p.wait()


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
    x, y, size = (int(v) for v in spec["crop"])
    rate = float(spec.get("rate", 2.0))
    os.makedirs(os.path.join(out, "img"), exist_ok=True)
    os.makedirs(os.path.join(out, "mask"), exist_ok=True)
    watch = actor.Watcher(spec["face_model"], spec["pose_model"], masks=True, image=True)
    total = sum(max(0.0, t1 - t0) for t0, t1 in spec["shots"]) * rate
    rows = {"t": [], "found": [], "hands": [], "points": [], "blend": [], "matrix": [], "pose": []}
    k = 0
    for t0, t1 in spec["shots"]:
        for t, rgb in crops(a.ffmpeg, spec["video"], float(t0), float(t1), rate, x, y, size):
            rec = watch.look(rgb, 0)
            found = rec.get("found", 0.0) > 0.5
            pts = rec["points"] if found else np.zeros((478, 3), np.float32)
            pose = np.asarray(rec.get("pose", [0.0] * 132), np.float32)
            hands = found and actor.hands_at_mouth(pose.tolist(), rec.get("box"))
            rows["t"].append(t)
            rows["found"].append(found)
            rows["hands"].append(bool(hands))
            rows["points"].append(pts * np.float32(size))
            rows["blend"].append(np.asarray(rec.get("blend", [0.0] * 52), np.float32))
            rows["matrix"].append(np.asarray(rec.get("matrix", np.zeros(16)), np.float32))
            rows["pose"].append(pose)
            Image.fromarray(rgb).save(os.path.join(out, "img", "%05d.jpg" % k), quality=94)
            seg = rec.get("segmentation")
            if seg is not None:
                seg = np.asarray(seg, np.float32).reshape(size, size)
                Image.fromarray((np.clip(seg, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8)).save(
                    os.path.join(out, "mask", "%05d.png" % k))
            k += 1
            if a.progress and k % 20 == 0:
                actor.progress(a.progress, min(0.999, k / max(1.0, total)))
    stills = {"still_points": [], "still_blend": [], "still_found": []}
    for path in spec.get("stills", []):
        full = np.asarray(Image.open(path).convert("RGB"))
        rec = watch.look(np.ascontiguousarray(full[y:y + size, x:x + size]), 0)
        found = rec.get("found", 0.0) > 0.5
        stills["still_found"].append(found)
        stills["still_points"].append((rec["points"] if found else np.zeros((478, 3), np.float32)) * np.float32(size))
        stills["still_blend"].append(np.asarray(rec.get("blend", [0.0] * 52), np.float32))
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
