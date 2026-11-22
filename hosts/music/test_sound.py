#!/usr/bin/env python3
"""sound.py held to what a patch says (next/sound_effects.md).

    <music_venv>/bin/python test_sound.py

Held:
- a pure function: the same patch and seed are the same samples (the control: another seed, other noise);
- a level curve is heard as written: loud where it says 1, silent where it says 0;
- a moving source: a tone flying past is heard higher as it comes and lower as it goes, loudest as it passes nearest;
- the heard numbers tell an abrupt end from a slow one: a sound loud to its last sample has no fade and ends loud (the
  control: one eased down by 66 dB over four seconds takes about two from 6 dB down to 40 dB down, and ends quiet);
- a patch with an unknown source or filter is refused, saying which;
- sound.py writes the WAV and the done file, its heard numbers in it.
"""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import numpy as np  # noqa: E402

import sound  # noqa: E402

FAILS = 0


def ok(cond: bool, msg: str) -> None:
    global FAILS
    print(("ok    " if cond else "FAIL  ") + msg)
    if not cond:
        FAILS += 1


def db_at(h: dict, t: float) -> float:
    return min(h["frames"], key=lambda f: abs(f["t"] - t))["db"]


def main() -> int:
    hiss = {"secs": 3.0, "layers": [{"source": "noise", "color": "pink",
                                     "level": [[0.0, 0.0], [1.0, 1.0], [2.0, 1.0], [3.0, 0.0]]}]}
    a = sound.render(hiss, 5)
    b = sound.render(hiss, 5)
    c = sound.render(hiss, 6)
    ok(np.array_equal(a, b) and not np.array_equal(a, c), "the same patch and seed are the same samples; another seed is other noise")
    h = sound.heard(a)
    ok(db_at(h, 1.5) > db_at(h, 0.05) + 25.0 and db_at(h, 1.5) > db_at(h, 2.95) + 25.0,
       "a level curve is heard as written: %.1f dB in the middle, %.1f and %.1f at its ends" % (db_at(h, 1.5), db_at(h, 0.05), db_at(h, 2.95)))

    tone = {"secs": 8.0, "layers": [{"source": "sine", "pitch": 500.0, "moving": {"closest": 4.0, "near": 60.0, "speed": 90.0}}]}
    ht = sound.heard(sound.render(tone, 1))
    early = [f["pitch"] for f in ht["frames"] if 1.0 <= f["t"] <= 2.0 and f["pitch"]]
    late = [f["pitch"] for f in ht["frames"] if 6.0 <= f["t"] <= 7.0 and f["pitch"]]
    ok(bool(early) and bool(late) and np.median(early) > 560.0 and np.median(late) < 445.0,
       "a tone flying past is higher coming and lower going: %s Hz then %s Hz" % (np.median(early) if early else None, np.median(late) if late else None))
    ok(abs(ht["loudest_at"] - 4.0) < 0.8, "it is loudest as it passes nearest: %.1f s" % ht["loudest_at"])

    cut = {"secs": 4.0, "layers": [{"source": "noise", "level": 1.0}]}
    eased = {"secs": 2.0, "tail": 6.0, "layers": [{"source": "noise", "level": {"points": [[0.0, 1.0], [2.0, 1.0], [6.0, 0.0005]], "ease": "exp"}}]}
    hc = sound.heard(sound.render(cut, 2))
    he = sound.heard(sound.render(eased, 2))
    ok(hc["fade"] is None and hc["end_db"] > hc["frames"][5]["db"] - 3.0,
       "a sound loud to its end has no fade and ends loud (%s, %.1f dB)" % (hc["fade"], hc["end_db"]))
    ok(he["fade"] is not None and 1.5 < he["fade"] < 4.0 and he["end_db"] < he["frames"][5]["db"] - 40.0,
       "the control: one eased down over four seconds fades in %s s and ends quiet (%.1f dB)" % (he["fade"], he["end_db"]))

    ok("source" in sound.check({"secs": 1.0, "layers": [{"source": "violin"}]}) and
       "filter" in sound.check({"secs": 1.0, "layers": [{"source": "noise", "filters": [{"kind": "comb"}]}]}) and
       sound.check(hiss) == "", "an unknown source or filter is refused, saying which; a good patch is not")

    with tempfile.TemporaryDirectory() as tmp:
        spec = {"patch": hiss, "seed": 5, "out": str(Path(tmp) / "s.wav"), "done": str(Path(tmp) / "done.json")}
        (Path(tmp) / "spec.json").write_text(json.dumps(spec))
        subprocess.run([sys.executable, "-I", str(HERE / "sound.py"), str(Path(tmp) / "spec.json")], check=False)
        done = json.loads((Path(tmp) / "done.json").read_text())
        with wave.open(spec["out"]) as w:
            frames, rate, chans = w.getnframes(), w.getframerate(), w.getnchannels()
        ok(done.get("ok") and rate == sound.RATE and chans == 2 and abs(frames - 3.0 * sound.RATE) < 2 and "frames" in done["heard"],
           "sound.py writes the WAV (%d frames at %d Hz, %d channels) and the done file with its heard numbers" % (frames, rate, chans))
    print("test_sound: %s" % ("ALL OK" if FAILS == 0 else "%d FAILED" % FAILS))
    return 1 if FAILS else 0


if __name__ == "__main__":
    raise SystemExit(main())
