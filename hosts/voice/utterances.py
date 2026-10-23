#!/usr/bin/env python3
"""utterances.py - an actor's own speech, cut into the sentences a voice of them is taught on (next/likeness.md,
"Their own voice").

    <voice_venv python> utterances.py --ffmpeg <ghost's ffmpeg> --spec <spec.json> [--progress <file>]

The spec: {"videos": [{"vid", "path", "words"}], "config", "espeak", "out", "index"} - each ticked video's file
and every word heard in it (`words`: Hear's speech.json, {"words": [{"text", "t0", "t1", "p"}]}), the base
voice's config (its phoneme map), the eSpeak voice they are read in, the folder the utterances go to and the
summary written last (`index`, the step's own file).

Writes <out>/wav/<utt>.wav (22050 Hz, mono), <out>/metadata.csv (`utt|text|ids`: what training reads),
<out>/test.csv (held out, never trained on: what the voice is measured against), <out>/phonemes.json (the
map), then <index>: {utterances, minutes, held_out, by_video, left_out: {why: count}, voiced}.

THE IDS ARE THE VOICE HOST'S OWN (backends/piper.py): its homographs, its eSpeak reading of the sentence, its
lead-in spaces and its layout of the ids - so the voice is taught exactly what it will be sent.

WHAT IS KEPT, measured on Ephemeral Rift's videos (2026-10-22):
- a run of their words between pauses (BREAK; SENTENCE_BREAK after a sentence's end), SHORTEST to LONGEST
  seconds of at least two words, every word heard surely enough (WORD_SURE, RUN_SURE: Whisper's own
  probabilities; its median word is 0.91, a fifth of runs hold one under 0.34);
- CUT IN THE QUIET either side: Whisper's word edges come early - the voice runs on 30-48 dB over the room
  just past a word's end - so each edge is walked out to where the sound falls (`sound_from`) and the cut
  is the quietest frame of the pause beyond it, which must be within QUIET of the room;
- NO SOUND THE TEXT LACKS: a loud stretch meeting no word (an "um" Whisper left out, a laugh, a cough);
- SPOKEN, NOT WHISPERED: five of their eight videos are mostly whispered (a third of their loud frames carry
  a pitch, against three fifths in the spoken two); a whisper is another voice, so a run with less than
  VOICED of its loud frames pitched is left out;
- each brought to one level (LEVEL, its peaks under PEAK): their videos sit 13 dB apart.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import wave
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import numpy as np  # noqa: E402

SR = 22050
FRAME = 0.02  # seconds: the frames a level is read in
BREAK = 0.4  # a gap this long between words ends an utterance...
SENTENCE_BREAK = 0.2  # ...and this long after a sentence's end
LONGEST = 12.0  # seconds of words an utterance may hold; a longer run is split at its longest gap
SHORTEST = 1.0
EDGE = 0.35  # seconds of the pause kept either side, at most
WORD_SURE = 0.25
RUN_SURE = 0.8
QUIET = 12.0  # dB over the room a cut may land at
LOUD = 20.0  # dB over the room: a frame of sound
SOUND = 15.0  # dB over the room: where a word's sound has fallen
STRAY = 0.2  # seconds of sound meeting no word an utterance may hold
VOICED = 0.45
LEVEL = -20.0  # dB: the median of an utterance's loud frames
PEAK = 0.966
HELD_OUT = 25  # every this many utterances, one is held out
MARKS = ",.;:!?"
ENDS = ".!?"


def say(*parts) -> None:
    print("actor:", *parts, flush=True)


def progress(path: str, frac: float) -> None:
    if not path:
        return
    tmp = path + ".part"
    with open(tmp, "w") as f:
        f.write("%.4f" % max(0.0, min(1.0, frac)))
    os.replace(tmp, path)


def sound_of(ffmpeg: str, video: str):
    """The video's sound, mono at SR, as float32 - empty when it has none."""
    raw = subprocess.run([ffmpeg, "-v", "error", "-nostdin", "-i", video, "-vn", "-ac", "1", "-ar", str(SR),
                          "-f", "f32le", "-"], capture_output=True).stdout
    return np.frombuffer(raw, dtype=np.float32)


def levels(y):
    """Each FRAME's level, in dB."""
    n = int(FRAME * SR)
    k = len(y) // n
    fr = y[: k * n].reshape(k, n).astype(np.float64)
    return 10.0 * np.log10((fr ** 2).mean(1) + 1e-12)


def voiced(y, floor: float) -> float:
    """The share of the loud 46 ms frames that carry a pitch between 70 and 300 Hz."""
    hop, n = 512, 1024
    k = (len(y) - n) // hop
    if k <= 0:
        return 0.0
    fr = np.stack([y[i * hop: i * hop + n] for i in range(k)]).astype(np.float64)
    fr -= fr.mean(1, keepdims=True)
    fr = fr[10.0 * np.log10((fr ** 2).mean(1) + 1e-12) > floor + SOUND]
    if not len(fr):
        return 0.0
    ac = np.fft.irfft(np.abs(np.fft.rfft(fr, 2 * n, axis=1)) ** 2, axis=1)[:, :n]
    ac /= ac[:, :1] + 1e-12
    return float(np.mean(ac[:, SR // 300: SR // 70].max(1) > 0.5))


def split_word(text: str) -> tuple[str, str]:
    """(the word, the mark after it): quotes, brackets and dashes go; of several marks, the last."""
    t = text.strip().strip("\"'“”‘’()[]{}")
    punct = ""
    while t and t[-1] in MARKS + "\"'“”’)":
        if t[-1] in MARKS:
            punct = punct or t[-1]
        t = t[:-1]
    return t.strip("\"'“”‘’()[]-—–"), punct


def runs(words: list) -> list:
    """The words in runs between pauses, none longer than LONGEST (split at their longest gap)."""
    out, cur = [], []
    for w in words:
        if cur:
            gap = w["t0"] - cur[-1]["t1"]
            ended = bool(cur[-1]["punct"]) and cur[-1]["punct"] in ENDS  # ("" is in every string)
            if gap >= BREAK or (ended and gap >= SENTENCE_BREAK):
                out.append(cur)
                cur = []
        cur.append(w)
    if cur:
        out.append(cur)
    done = []
    while out:
        r = out.pop()
        if r[-1]["t1"] - r[0]["t0"] <= LONGEST:
            done.append(r)
            continue
        gaps = [(r[i + 1]["t0"] - r[i]["t1"], i) for i in range(len(r) - 1)]
        g, i = max(gaps) if gaps else (0.0, -1)
        if g >= 0.12:
            out += [r[: i + 1], r[i + 1:]]
    return sorted(done, key=lambda r: r[0]["t0"])


def sound_from(lv, floor: float, at: int, way: int, most: int = 30) -> int:
    """From frame [at], walking [way], the frame where the sound has fallen under the room + SOUND."""
    i = at
    for _ in range(most):
        j = i + way
        if j < 0 or j >= len(lv) or lv[j] < floor + SOUND:
            break
        i = j
    return i + (1 if way > 0 else 0)


def cut(rs: list, k: int, lv, floor: float, reach: list, blobs: list):
    """Run [k]'s frames [f0, f1) cut in the quiet either side, or why it cannot be."""
    r = rs[k]
    if r[-1]["t1"] - r[0]["t0"] < SHORTEST or len(r) < 2:
        return "short"
    ps = [w["p"] for w in r]
    if min(ps) < WORD_SURE or sum(ps) / len(ps) < RUN_SURE:
        return "unsure words"
    a0, b0 = reach[k]
    lo = max(reach[k - 1][1] if k else 0, a0 - int(EDGE / FRAME))
    hi = min(reach[k + 1][0] if k + 1 < len(rs) else len(lv), b0 + int(EDGE / FRAME))
    if a0 - lo < 2 or hi - b0 < 2:
        return "no pause round it"
    f0 = lo + int(np.argmin(lv[lo:a0]))
    f1 = b0 + int(np.argmin(lv[b0:hi])) + 1
    if max(lv[f0], lv[f1 - 1]) > floor + QUIET:
        return "cut in sound"
    heard = [(int(w["t0"] / FRAME) - 5, int(w["t1"] / FRAME) + 5) for w in r]
    stray = sum(e - b for b, e in blobs if b < f1 and e > f0 and not any(b < hb and e > ha for ha, hb in heard))
    if stray * FRAME > STRAY:
        return "a sound the words lack"
    return f0, f1


def ids_of(backend, tokens: list, pmap: dict, espeak: str) -> list:
    """The ids the voice host sends for these words (`_run`, `_render_symbols`): [BOS, PAD, id, PAD, ..., EOS]."""
    from backends.piper import BOS, EOS, PAD
    backend._homographs.annotate(tokens, espeak)
    symbols, _ = backend._fold_syllabic(backend._symbols(tokens, "espeak", espeak, ""), pmap)
    ids = [BOS]
    for sym, _src in symbols:
        mapped = pmap.get(sym)
        if mapped is None:
            continue
        ids.append(PAD)
        ids += [int(m) for m in mapped]
    return ids + [PAD, EOS]


def write_wav(path: Path, y) -> None:
    pcm = np.clip(np.round(y * 32767.0), -32768, 32767).astype("<i2")
    tmp = path.with_name(path.name + ".part")
    with wave.open(str(tmp), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    os.replace(tmp, path)


def write_text(path: Path, text: str) -> None:
    tmp = path.with_name(path.name + ".part")
    tmp.write_text(text, encoding="utf-8")
    os.replace(tmp, path)


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="utterances.py")
    ap.add_argument("--ffmpeg", required=True)
    ap.add_argument("--spec", required=True)
    ap.add_argument("--progress", default="")
    a = ap.parse_args(argv)
    spec = json.loads(Path(a.spec).read_text(encoding="utf-8"))
    out = Path(spec["out"])
    (out / "wav").mkdir(parents=True, exist_ok=True)
    for old in (out / "wav").glob("*.wav"):
        old.unlink()
    pmap = json.loads(Path(spec["config"]).read_text(encoding="utf-8"))["phoneme_id_map"]
    espeak = str(spec.get("espeak", "en-us"))
    from backends.piper import PiperBackend
    backend = PiperBackend()
    train, test, kept, why, pitched = [], [], {}, {}, []
    n = 0
    videos = spec["videos"]
    for vi, v in enumerate(videos):
        progress(a.progress, vi / max(1, len(videos)))
        try:
            heard = json.loads(Path(v["words"]).read_text(encoding="utf-8")).get("words", [])
        except (OSError, ValueError):
            heard = []
        y = sound_of(a.ffmpeg, v["path"]) if heard else np.zeros(0, np.float32)
        if not y.size:
            continue
        lv = levels(y)
        floor = float(np.percentile(lv, 10))
        words = []
        for w in heard:
            t, p = split_word(str(w["text"]))
            if t:
                words.append({"text": t, "punct": p, "t0": float(w["t0"]), "t1": float(w["t1"]), "p": float(w["p"])})
        rs = runs(words)
        loud = (lv > floor + LOUD).astype(np.int8)
        edges = np.flatnonzero(np.diff(np.concatenate([[0], loud, [0]])))
        blobs = list(zip(edges[::2], edges[1::2]))
        reach = [(sound_from(lv, floor, int(r[0]["t0"] / FRAME), -1), sound_from(lv, floor, int(r[-1]["t1"] / FRAME), 1))
                 for r in rs]
        for k, r in enumerate(rs):
            got = cut(rs, k, lv, floor, reach, blobs)
            if isinstance(got, str):
                why[got] = why.get(got, 0) + 1
                continue
            f0, f1 = got
            seg = y[int(f0 * FRAME * SR): int(f1 * FRAME * SR)]
            vs = voiced(seg, floor)
            pitched.append(vs)
            if vs < VOICED:
                why["whispered"] = why.get("whispered", 0) + 1
                continue
            text = " ".join(w["text"] + w["punct"] for w in r)
            if not 6.0 <= len(text) / (r[-1]["t1"] - r[0]["t0"]) <= 25.0:
                why["too quick or slow for its words"] = why.get("too quick or slow for its words", 0) + 1
                continue
            sl = levels(seg)
            speech = sl[sl > floor + SOUND]
            if not len(speech):
                why["quiet"] = why.get("quiet", 0) + 1
                continue
            gain = min(10.0 ** ((LEVEL - float(np.median(speech))) / 20.0), PEAK / max(1e-6, float(np.abs(seg).max())))
            ids = ids_of(backend, [{"text": w["text"], "punct": w["punct"]} for w in r], pmap, espeak)
            utt = "%s_%05d" % (v["vid"], k)
            write_wav(out / "wav" / (utt + ".wav"), seg * gain)
            row = "%s|%s|%s" % (utt, text.replace("|", " "), " ".join(map(str, ids)))
            n += 1
            (test if n % HELD_OUT == 0 else train).append(row)
            kept[v["vid"]] = kept.get(v["vid"], 0.0) + len(seg) / SR
    write_text(out / "metadata.csv", "\n".join(train) + "\n")
    write_text(out / "test.csv", "\n".join(test) + "\n")
    write_text(out / "phonemes.json", json.dumps(pmap, ensure_ascii=False))
    minutes = sum(kept.values()) / 60.0
    summary = {"utterances": len(train), "held_out": len(test), "minutes": round(minutes, 1),
               "by_video": {k: round(s / 60.0, 1) for k, s in kept.items()}, "left_out": why,
               "voiced": [round(float(x), 2) for x in np.percentile(pitched, [10, 50, 90])] if pitched else []}
    write_text(Path(spec["index"]), json.dumps(summary, indent=1))
    progress(a.progress, 1.0)
    say("utterances: %d utterances, %.0f minutes of their voice from %d videos (%d whispered left out)"
        % (len(train), minutes, len(kept), why.get("whispered", 0)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
