#!/usr/bin/env python3
"""Listening pairs for inflection.py: each line read by a Kokoro speaker as a reading reads it, once plain and once
inflected, side by side in one folder, with each take's pitch at its last word printed.

    ~/.local/share/godot/app_userdata/ghost/voice_venv/bin/python hosts/voice/inflection_probe.py \
        [--out dist/inflection] [--speakers 20,0] [--only question,emphasis] [--set question.rise=6]

A line is words, `*word*` italic and `**word**` bold as a script marks them. Written: `<out>/<speaker>_<n>_plain.wav`,
`..._inflected.wav`, and `<out>/<speaker>_all.wav`, every pair one after another (plain, then inflected).
"""

from __future__ import annotations

import argparse
import re
import sys
import wave
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

LINES = (
    "Is it raining outside?",
    "Did you leave the door open?",
    "You told him about the letter?",
    "Where did you put the keys?",
    "What time does the train leave?",
    "You did *what*?",
    "I never said she *stole* the money.",
    "I never said *she* stole the money.",
    "It was not a dream. It was *real*.",
    "This is **exactly** what I was afraid of.",
    "Are you *sure* it was him?",
)
GAP = 0.6  # seconds of silence between takes in the joined file


def tokens_of(line: str) -> list:
    """A line as the host's tokens: each word, the marks after it, and its emphasis level."""
    out = []
    for w in line.split():
        level = 0
        m = re.match(r"^(\*\*\*|\*\*|\*)?(.*?)(\*\*\*|\*\*|\*)?([.,;:!?]*)$", w)
        lead, word, _close, punct = m.groups()
        if lead:
            level = {"*": 1, "**": 2, "***": 3}[lead]
        out.append({"text": word, "punct": punct, **({"emph": level} if level else {})})
    return out


def pitch_track(audio, sr: int):
    """A rough F0 track (autocorrelation, 20 ms frames, 75-400 Hz), 0 where unvoiced."""
    import numpy as np

    n = int(sr * 0.04)
    hop = int(sr * 0.01)
    lo, hi = int(sr / 400), int(sr / 75)
    peak = float(np.max(np.abs(audio))) or 1.0
    f0 = []
    for i in range(0, audio.size - n, hop):
        x = audio[i:i + n].astype(np.float64)
        if np.sqrt(np.mean(x * x)) < peak * 0.03:
            f0.append(0.0)
            continue
        x = x - x.mean()
        r = np.correlate(x, x, mode="full")[n - 1:]
        if r[0] <= 0:
            f0.append(0.0)
            continue
        k = lo + int(np.argmax(r[lo:hi]))
        f0.append(sr / k if r[k] / r[0] > 0.45 else 0.0)
    return np.array(f0)


def tail_semis(audio, sr: int) -> float:
    """Semitones from the median voiced pitch of the take to its last voiced 150 ms."""
    import numpy as np

    f0 = pitch_track(audio, sr)
    v = np.nonzero(f0 > 0)[0]
    if v.size < 10:
        return 0.0
    tail = f0[v[v >= v[-1] - 15]]
    return float(12.0 * np.log2(np.median(tail) / np.median(f0[v])))


def write(path: Path, audio, sr: int) -> None:
    import numpy as np

    pcm = (np.clip(audio, -1.0, 1.0) * 32767.0).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(pcm.tobytes())


def read(path: Path):
    import numpy as np

    with wave.open(str(path), "rb") as w:
        sr = w.getframerate()
        a = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").astype(np.float32) / 32767.0
    return a, sr


def main() -> int:
    import numpy as np

    from backends.kokoro import PACKS, KokoroBackend

    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="dist/inflection")
    ap.add_argument("--speakers", default="20,0")
    ap.add_argument("--only", default="")
    ap.add_argument("--set", action="append", default=[], help="rule.field=value")
    args = ap.parse_args()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    settings: dict = {}
    if args.only:
        import inflection

        settings = {k: (k in args.only.split(",")) for k in inflection.RULES}
    for s in args.set:
        key, value = s.split("=", 1)
        rule, fld = key.split(".", 1)
        own = settings.get(rule)
        settings[rule] = {**(own if isinstance(own, dict) else {}), fld: float(value)}
    inflect = settings or True

    k = KokoroBackend()
    for sp in [int(x) for x in args.speakers.split(",")]:
        name = PACKS[sp][0]
        joined = []
        sr = 22050
        for n, line in enumerate(LINES):
            row = []
            for tag, inf in (("plain", None), ("inflected", inflect)):
                path = out / f"{name}_{n:02d}_{tag}.wav"
                params = {"tokens": tokens_of(line), "speaker": sp}
                if inf:
                    params["inflect"] = inf
                got = k.synthesize(line, "kokoro", str(path), params)
                audio, sr = read(path)
                toks = params["tokens"]
                marked = {i for i, t in enumerate(toks) if t.get("emph")} | {len(toks) - 1}
                lengths = " ".join(f"{toks[int(t['index'])]['text']} {1000 * (float(t['t1']) - float(t['t0'])):3.0f}ms"
                                   for t in got.get("tokens", []) if int(t.get("index", -1)) in marked)
                row.append(f"{tag} {audio.size / sr:4.2f}s tail {tail_semis(audio, sr):+5.1f} st ({lengths})")
                joined += [audio, np.zeros(int(GAP * sr), np.float32)]
            print(f"{name} {n:02d} {line!r:48} " + " | ".join(row))
            joined.append(np.zeros(int(GAP * sr), np.float32))
        write(out / f"{name}_all.wav", np.concatenate(joined), sr)
    print(f"written to {out.resolve()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
