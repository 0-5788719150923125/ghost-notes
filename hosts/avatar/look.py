#!/usr/bin/env python3
"""look.py - an avatar drawn on held-out frames as it is played, for the eye and for Godot to be held to
(tests/likeness/splat_head_probe.gd).

    <voice_train_venv python> look.py --spec <train spec.json> --avatar <avatar.npz> --out <folder> [--count N]

For each of N held-out frames: <out>/<k>_truth.png (the frame), <k>_played.png (the splats on the face the rig
makes from its scores, over its room - no colour correction, as played), <k>_room.png (that room) and
<k>_pose.json ({blend, scale, rot (rows), shift, k, size, crop}: what SplatHead.pose is handed).
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
    data = train.Frames(spec, int(spec.get("size", 512)), dev)
    rig = train.Rig(spec["rig"], dev)
    splats = train.load(a.avatar, dev)
    os.makedirs(a.out, exist_ok=True)

    def png(t, path):
        Image.fromarray((t.clamp(0, 1).cpu().numpy() * 255.0 + 0.5).astype(np.uint8)).save(path)
    picks = data.measured[:: max(1, data.measured.size // a.count)][: a.count]
    with torch.no_grad():
        for n, i in enumerate(picks):
            i = int(i)
            fr = data.held_frame(i)
            played = train.render(splats, rig, data, i, frame=fr, tracked=False)[0]
            png(fr[0], os.path.join(a.out, "%d_truth.png" % n))
            png(played, os.path.join(a.out, "%d_played.png" % n))
            png(fr[3], os.path.join(a.out, "%d_room.png" % n))
            pose = {"frame": i, "blend": data.blend[i].tolist(), "scale": float(data.scale[i]),
                    "rot": data.rot[i].tolist(), "shift": data.shift[i].tolist(), "k": data.k,
                    "size": data.size, "crop": [int(c) for c in data.crop]}
            json.dump(pose, open(os.path.join(a.out, "%d_pose.json" % n), "w"))
    print("actor: avatar: look: %d frames in %s" % (len(picks), a.out))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
