#!/usr/bin/env python3
"""ghost music host - a composed Sound made a stretch at a time as it plays, spoken to over stdio (stream.py makes the
stretches; the app's SongStream asks for them).

PROTOCOL. Newline-delimited JSON, one request a line and one reply a line, `id` echoed; audio never travels as JSON -
a window is written to a file and its path returned.

  -> {"id": 1, "op": "load", "spec": {...render.py's spec...}}
  <- {"id": 1, "ok": true, "length": 220.3}
  -> {"id": 2, "op": "takes", "takes": [{"wav", "at", "voice"}]}  the takes sung so far, all of them, each its voice's
  <- {"id": 2, "ok": true}
  -> {"id": 3, "op": "window", "t0": 30.0, "t1": 36.0, "out": "/path/w3.f32"}
  <- {"id": 3, "ok": true, "wav": "/path/w3.f32", "t0": 30.0, "t1": 36.0}
     ("voice": false makes it without the voice; "follows": true fades it in from the last window whatever its time -
     a bar played again while the singer is late)
  -> {"id": 4, "op": "shutdown"}

A window is raw float32 stereo at 44.1 kHz, interleaved (left, right), little-endian, no header: what the app pushes
into its stream, read with one call. Requests are made in order; a window asked of a song loaded since is made
of the song now. Every reply carries "ok"; on failure "error" says why, and the host carries on. Stdout is the
protocol: anything else goes to stderr.
"""

from __future__ import annotations

import json
import sys
import traceback
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import numpy as np  # noqa: E402

import stream  # noqa: E402


def main() -> int:
    out = sys.stdout
    sys.stdout = sys.stderr  # nothing but the protocol on the real stdout
    song = None

    def send(msg: dict) -> None:
        out.write(json.dumps(msg) + "\n")
        out.flush()

    send({"event": "ready"})
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            req = json.loads(line)
        except json.JSONDecodeError as exc:
            send({"ok": False, "error": f"malformed request: {exc}"})
            continue
        rid = req.get("id")
        op = req.get("op", "")
        if op == "shutdown":
            send({"id": rid, "ok": True})
            return 0
        try:
            if op == "load":
                song = stream.Song(req["spec"])
                send({"id": rid, "ok": True, "length": song.length})
            elif op == "takes":
                if song is not None:
                    song.set_takes(req.get("takes") or [])
                send({"id": rid, "ok": True})
            elif op == "window":
                if song is None:
                    raise RuntimeError("no song is loaded")
                t0, t1 = float(req["t0"]), float(req["t1"])
                x = song.window(t0, t1, bool(req.get("voice", True)), req.get("follows"))
                path = Path(str(req["out"]))
                tmp = path.with_name(path.name + ".part")
                np.clip(x.T, -1.0, 1.0).astype("<f4").tofile(str(tmp))
                tmp.replace(path)
                send({"id": rid, "ok": True, "wav": str(path), "t0": t0, "t1": t1})
            else:
                raise RuntimeError(f"unknown op '{op}'")
        except Exception as exc:  # noqa: BLE001 - the app reads the reason; the host stays up
            traceback.print_exc()
            send({"id": rid, "ok": False, "error": f"{type(exc).__name__}: {exc}"})
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
