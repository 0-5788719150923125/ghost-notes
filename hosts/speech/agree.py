#!/usr/bin/env python3
"""agree.py - each of their sentences cut to the words its own sound says (next/voice_engines.md, "Training Kokoro").

    <speech_venv python> agree.py --spec <spec.json> [--progress <file>]

The spec: {"utterances": Utterances' folder (wav/, metadata.csv, test.csv), "model": a faster-whisper model folder
(medium.en: the smaller ones hear soft speech too poorly), "out": the cuts (JSON), "passes"}.

WHY (2026-10-26, an ASMR channel): a sentence's words came from hearing the whole video at once, and its cut was laid by
those words' times - and only 83 of 192 cut sentences said exactly their text, heard again alone: a word at an edge
counted on the wrong side of a cut ("I've" in one sentence's text, its sound in the next), a word the long hearing
left out. Taught on them, Kokoro learned to say what no text asked for and mumbled; on clean speech, alignments a
median two frames off alone took its words misheard from 1% to 33%.

SO EACH IS HEARD AGAIN, ALONE (word times, beam 5), and cut to the longest run of words its text and its sound agree
on - at least LEAST words, each heard SURE - in the quietest 10 ms between that run and the word beside it; heard again
and cut again, PASSES times (a word's time on soft speech runs late, so a first cut can keep the word before); and
KEPT ONLY WHERE THE LAST HEARING IS ITS TEXT, word for word. `{utt: {t0, t1, tokens, set}}`: seconds into its clip, the
text's own words (their marks kept) and whether it was held out.
"""

from __future__ import annotations

import argparse
import difflib
import json
import os
import sys
import wave
from pathlib import Path

LEAST = 3
SURE = 0.4
SHORTEST = 0.8
PASSES = 2
SR16 = 16000


def say(*parts) -> None:
    print("actor:", *parts, flush=True)


def progress(path: str, frac: float) -> None:
    if not path:
        return
    tmp = path + ".part"
    with open(tmp, "w") as f:
        f.write("%.4f" % max(0.0, min(1.0, frac)))
    os.replace(tmp, path)


def norm(word: str) -> str:
    return "".join(c for c in word.lower() if c.isalnum())


def read(path: Path):
    """A clip (mono 16-bit) as float32, and its rate."""
    import numpy as np

    with wave.open(str(path)) as w:
        return np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").astype(np.float32) / 32768.0, w.getframerate()


def at16k(y, sr: int):
    import numpy as np

    n = int(len(y) * SR16 / sr)
    return np.interp(np.arange(n) * sr / SR16, np.arange(len(y)), y).astype(np.float32)


def run_of(tokens: list, words: list):
    """The longest run of `tokens` (the text's, marks kept) that `words` (heard, with times) say in order:
    (first token, first word, how many), or None under LEAST or with a word heard less than SURE."""
    toks = [norm(t) for t in tokens]
    heard = [norm(w.word) for w in words]
    blk = max(difflib.SequenceMatcher(None, toks, heard, autojunk=False).get_matching_blocks(), key=lambda b: b.size)
    if blk.size < LEAST or min(words[j].probability for j in range(blk.b, blk.b + blk.size)) < SURE:
        return None
    return blk.a, blk.b, blk.size


def quietest(y, sr: int, lo: float, hi: float) -> float:
    """The quietest 10 ms in [lo, hi] seconds."""
    import numpy as np

    hop = int(0.01 * sr)
    a, b = max(0, int(lo / 0.01)), max(0, int(hi / 0.01)) + 1
    lv = [float(np.mean(y[k * hop:(k + 1) * hop] ** 2)) for k in range(a, b) if (k + 1) * hop <= len(y)]
    return (a + int(np.argmin(lv))) * 0.01 if lv else lo


def hear(model, y, sr: int) -> list:
    segs, _ = model.transcribe(at16k(y, sr), language="en", beam_size=5, word_timestamps=True,
                               condition_on_previous_text=False)
    return [w for s in segs for w in s.words]


def agree(model, y, sr: int, tokens: list, passes: int = PASSES):
    """The cut of clip `y` whose sound says a run of `tokens` - (t0, t1, the run's tokens) - or None."""
    t0, t1, toks = 0.0, len(y) / sr, list(tokens)
    for _ in range(passes):
        seg = y[int(t0 * sr): int(t1 * sr)]
        words = hear(model, seg, sr)
        found = run_of(toks, words) if words else None
        if found is None:
            return None
        i, j, n = found
        s0, e0 = words[j].start, words[j + n - 1].end
        a = quietest(seg, sr, words[j - 1].end, s0) if j > 0 else quietest(seg, sr, max(0.0, s0 - 0.3), s0)
        b = quietest(seg, sr, e0, words[j + n].start) if j + n < len(words) else quietest(seg, sr, e0, min(len(seg) / sr, e0 + 0.35))
        t0, t1, toks = t0 + a, t0 + b, toks[i:i + n]
        if t1 - t0 < SHORTEST:
            return None
    last = [norm(w.word) for w in hear(model, y[int(t0 * sr): int(t1 * sr)], sr)]
    return (round(t0, 3), round(t1, 3), toks) if last == [norm(t) for t in toks if norm(t)] else None


def load(path: str):
    """medium.en on the graphics card where CTranslate2 can reach it, else on the processor."""
    from faster_whisper import WhisperModel

    try:
        m = WhisperModel(path, device="cuda", compute_type="float16")
        import numpy as np

        # HEARD ONCE, WHOLE: a transcription is lazy, and CUDA's libraries are only reached when it runs - unrun, a
        # card with no CUDA 12 cuBLAS beside CTranslate2 passed here and failed on the first sentence (2026-10-27)
        segs, _info = m.transcribe(np.zeros(SR16, np.float32), language="en", vad_filter=False)
        list(segs)
        return m, "the graphics card"
    except Exception:  # noqa: BLE001 - no card, or CUDA's libraries not here
        return WhisperModel(path, device="cpu", compute_type="int8", cpu_threads=max(1, (os.cpu_count() or 2) - 1)), "the processor"


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="agree.py")
    ap.add_argument("--spec", required=True)
    ap.add_argument("--progress", default="")
    a = ap.parse_args(argv)
    spec = json.loads(Path(a.spec).read_text(encoding="utf-8"))
    src = Path(spec["utterances"])
    rows = []
    for name in ("metadata.csv", "test.csv"):
        p = src / name
        if p.exists():
            for line in p.read_text(encoding="utf-8").splitlines():
                if line.strip():
                    utt, text, _ids = line.split("|", 2)
                    rows.append((utt, text, name))
    model, where = load(spec["model"])
    say("agree: hearing %d sentences again, alone, on %s" % (len(rows), where))
    cuts, kept, heard = {}, 0.0, 0.0
    for k, (utt, text, name) in enumerate(rows):
        progress(a.progress, k / max(1, len(rows)))
        y, sr = read(src / "wav" / (utt + ".wav"))
        heard += len(y) / sr
        got = agree(model, y, sr, text.split(), int(spec.get("passes", PASSES)))
        if got is not None:
            cuts[utt] = {"t0": got[0], "t1": got[1], "tokens": got[2], "set": name}
            kept += got[1] - got[0]
    out = Path(spec["out"])
    tmp = out.with_name(out.name + ".part")
    tmp.write_text(json.dumps(cuts, indent=1), encoding="utf-8")
    os.replace(tmp, out)
    progress(a.progress, 1.0)
    say("agree: %d of %d sentences say their words, %.1f of %.1f minutes" % (len(cuts), len(rows), kept / 60.0, heard / 60.0))
    return 0


if __name__ == "__main__":
    sys.exit(main())
