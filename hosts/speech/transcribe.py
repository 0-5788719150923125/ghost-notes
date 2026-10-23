#!/usr/bin/env python3
"""transcribe.py - the words a video's person says, and when (next/likeness.md, the third pass).

    <speech_venv python> transcribe.py --ffmpeg <ghost's ffmpeg> --model <a faster-whisper model folder>
        --spec <spec.json> [--progress <file>]

The spec names the video, the stretches of it to listen to (`spans`: [[t0, t1]] in its seconds - its
usable shots, as the Actor's audit left them, or the whole of it for Hear) and where the words go (`out`);
`prompt` is the text Whisper is told came before (Hear's asks for the ums and uhs it would leave out), and
`step` the step it says it ran. Each stretch's sound is read by FFmpeg (mono, 16 kHz) in pieces of at most
PIECE seconds and transcribed with each word's time (Whisper's cross-attention, as faster-whisper aligns
it), the voice-activity filter skipping silence; the words land in the video's own seconds:
`{"words": [{"text", "t0", "t1", "p"}], "seconds": heard}`.

It is the captions a video without them never had (2026-10-22, the user: "Is there a simple and
effective way we might be able to extract subtitles from video, and sync them with timestamps?"), and
written as the captions' words are, so the steps after it read either.

WRITTEN UNDER A TEMPORARY NAME AND RENAMED INTO PLACE, as every step of actor.py's.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys


def say(*parts) -> None:
    print("actor:", *parts, flush=True)


def progress(path: str, frac: float) -> None:
    if not path:
        return
    tmp = path + ".part"
    with open(tmp, "w") as f:
        f.write("%.4f" % max(0.0, min(1.0, frac)))
    os.replace(tmp, path)


def sound_of(ffmpeg: str, video: str, t0: float, t1: float):
    """The stretch's sound, mono at 16 kHz, as float32 - what Whisper hears."""
    import numpy as np
    raw = subprocess.run([ffmpeg, "-v", "error", "-nostdin", "-ss", "%.3f" % t0, "-t", "%.3f" % (t1 - t0), "-i", video,
                          "-vn", "-ac", "1", "-ar", "16000", "-f", "f32le", "-"], capture_output=True).stdout
    return np.frombuffer(raw, dtype=np.float32)


# The longest stretch read at once (seconds): a whole video is heard in pieces, so its sound is never all
# in memory and its progress moves.
PIECE = 600.0


def merged(spans, gap: float = 1.0):
    """[spans] in order, those closer than [gap] seconds joined: fewer, longer stretches to hear - none
    longer than PIECE."""
    out = []
    for a, b in sorted((float(a), float(b)) for a, b in spans if float(b) > float(a)):
        if out and a - out[-1][1] < gap:
            out[-1][1] = max(out[-1][1], b)
        else:
            out.append([a, b])
    pieces = []
    for a, b in out:
        while b - a > PIECE:
            pieces.append([a, a + PIECE])
            a += PIECE
        pieces.append([a, b])
    return pieces


def words_in(segments, at: float):
    """Whisper's words in a stretch that starts at [at] seconds of the video, in the video's seconds."""
    out = []
    for s in segments:
        for w in s.words or []:
            text = w.word.strip()
            if text:
                out.append({"text": text, "t0": round(at + float(w.start), 3), "t1": round(at + float(w.end), 3),
                            "p": round(float(w.probability), 3)})
    return out


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="transcribe.py")
    ap.add_argument("--ffmpeg", required=True)
    ap.add_argument("--model", required=True)
    ap.add_argument("--spec", required=True)
    ap.add_argument("--progress", default="")
    ap.add_argument("--threads", type=int, default=4)
    a = ap.parse_args(argv)
    with open(a.spec) as f:
        spec = json.load(f)
    spans = merged(spec.get("spans", []))
    total = sum(b - a_ for a_, b in spans) or 1.0
    from faster_whisper import WhisperModel
    model = WhisperModel(a.model, device="cpu", compute_type="int8", cpu_threads=a.threads)
    words, done = [], 0.0
    for t0, t1 in spans:
        audio = sound_of(a.ffmpeg, spec["video"], t0, t1)
        if audio.size:
            segs, _info = model.transcribe(audio, language="en", word_timestamps=True, vad_filter=True,
                                           beam_size=5, condition_on_previous_text=False,
                                           initial_prompt=spec.get("prompt") or None)
            words += words_in(segs, t0)
        done += t1 - t0
        progress(a.progress, done / total)
    tmp = spec["out"] + ".part"
    with open(tmp, "w") as f:
        json.dump({"words": words, "seconds": round(total, 1)}, f)
    os.replace(tmp, spec["out"])
    progress(a.progress, 1.0)
    say("%s: %d words in %.0f minutes heard" % (spec.get("step", "transcribe"), len(words), total / 60.0))
    return 0


if __name__ == "__main__":
    sys.exit(main())
