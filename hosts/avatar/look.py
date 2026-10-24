#!/usr/bin/env python3
"""look.py - an avatar drawn on held-out frames as it is played, for the eye and for Godot to be held to
(tests/likeness/splat_head_probe.gd).

    <voice_train_venv python> look.py --spec <train spec.json> --avatar <avatar.npz> --out <folder> [--count N]

For each of N held-out frames: <out>/<k>_truth.png (the frame), <k>_played.png (the splats on the face the rig
makes from its scores and the body as the pose stands, over the avatar's learned room - no light of the
frame's own, as played), <k>_room.png (that room) and <k>_pose.json ({blend, scale, rot (rows), shift, bones:
[{origin, axes (columns), unit, seen}], crop}: what SplatHead.pose_face and pose_bones are handed).
"""

from __future__ import annotations

import argparse
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import train  # noqa: E402


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--spec", required=True)
    ap.add_argument("--avatar", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--count", type=int, default=4)
    a = ap.parse_args()
    import numpy as np
    import torch
    from PIL import Image
    spec = json.load(open(a.spec))
    dev = torch.device("cuda")
    data = train.Frames(spec, dev)
    rig = train.Rig(spec["rig"], dev)
    splats = train.load(a.avatar, dev)
    scene = train.Scene(data, dev, torch.tensor(np.load(a.avatar)["plate"], device=dev))
    os.makedirs(a.out, exist_ok=True)

    def png(t, path):
        Image.fromarray((t.clamp(0, 1).cpu().numpy() * 255.0 + 0.5).astype(np.uint8)).save(path)
    picks = data.measured[:: max(1, data.measured.size // a.count)][: a.count]
    with torch.no_grad():
        for n, i in enumerate(picks):
            i = int(i)
            img, _p = data.get(i, ahead=False)
            played = train.render(splats, rig, data, scene, i, 0, 0, data.W, data.H, tracked=False, learned=False)[0]
            png(img, os.path.join(a.out, "%d_truth.png" % n))
            png(played, os.path.join(a.out, "%d_played.png" % n))
            png(scene.plate(), os.path.join(a.out, "%d_room.png" % n))
            bones = [{"origin": data.bone_origin[i, b].tolist(), "axes": data.bone_axes[i, b].T.tolist(),
                      "unit": float(data.bone_unit[i, b]), "seen": float(data.bone_seen[i, b])} for b in range(data.B)]
            pose = {"frame": i, "blend": data.blend[i].tolist(), "scale": float(data.scale[i]),
                    "rot": data.rot[i].tolist(), "shift": data.shift[i].tolist(), "bones": bones,
                    "crop": [int(c) for c in data.crop]}
            json.dump(pose, open(os.path.join(a.out, "%d_pose.json" % n), "w"))
    print("actor: avatar: look: %d frames in %s" % (len(picks), a.out))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
