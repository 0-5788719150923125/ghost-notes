#!/usr/bin/env python3
"""utterances.py - an actor's own speech, cut into the sentences a voice of them is taught on (next/likeness.md,
"Their own voice").

    <voice_venv python> utterances.py --ffmpeg <ghost's ffmpeg> --spec <spec.json> [--progress <file>]

The spec: {"videos": [{"vid", "path", "words"}], "config", "espeak", "out", "index"} - each ticked video's file
and every word heard in it (`words`: Hear's speech.json, {"words": [{"text", "t0", "t1", "p"}]}), the base
voice's config (its phoneme map), the eSpeak voice they are read in, the folder the utterances go to and the
summary written last (`index`, the step's own file). FOR KOKORO (`"engine": "kokoro"`, its `family` and whether
it reads `british`; next/voice_engines.md, "Training Kokoro"): no config - the sound is cut at Kokoro's 24 kHz and
the ids are its graph's (`KokoroBackend.ids_of`), `phonemes.json` its vocabulary. AND AGAIN, AGREED (`"agreed"`: the
cuts hosts/speech/agree.py found, each sentence heard again alone and cut to the words its sound says): those cuts of
the `from` folder's sentences written as utterances, their ids made again from the words kept (`apply`).

Writes <out>/wav/<utt>.wav (22050 Hz, mono), <out>/metadata.csv (`utt|text|ids`: what training reads),
<out>/test.csv (held out, never trained on: what the voice is measured against), <out>/phonemes.json (the
map), then <index>: {utterances, minutes, held_out, by_video, left_out: {why: count}, left_out_minutes: {why:
minutes}, voiced, register, recording}.

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

ONE VOICE, NOT EVERY WAY THEY SOUND (2026-10-24, the user on the voice taught on all 65 of his videos: "really
muddy and hard to understand ... quite inconsistent"; Whisper misheard 33.6% of its words, against 14-17% for the
voices taught on two to seven): of the 480 minutes those videos gave, 220 were noisy - outdoors, wind, water, over a
music bed - 32 soft and low (85 Hz, close to the microphone), 38 pitched high, 44 breathy, and 146 his ordinary
voice; a voice of one speaker averages them all and draws among them sentence by sentence. Taught on the ordinary
part alone (93 minutes from 19 videos) it was misheard half as often (15.9%) and held its register (its pitch from
sentence to sentence varied 9 Hz, against 17). So every candidate is measured as it is cut (`signature`) and the
ones kept are chosen together (`choose`), by measurement - never by a list of videos:
- CLEAN: its speech CLEAN dB over its own pauses - or, where none of theirs is (2026-10-26: an ASMR channel's soft
  speech over a high-gain microphone's hiss, a median 19 dB, 30 for none of 253), within CLEAN_FROM_BEST of their
  cleanest (the 90th percentile): what is noisy is noisy against how they record;
- PACED AS SPEECH: RATE characters a second of loud sound (a music bed under it is loud with no words; soft speech
  has few loud frames, so its rate reads high - 25 a second their median, a quarter over 34);
- IN THEIR REGISTER: its pitch within REGISTER of their usual one (where the most minutes of the clean ones are);
- NOT BREATHY: a harmonics-to-noise ratio of BREATHY dB or more;
- ONE RECORDING: a video's mean spectrum (BANDS mel bands, its level taken out) within RECORDING dB of the most
  typical video's (the one nearest all the others, by their minutes);
- SAID ONCE: a sentence heard again (their downloads held four videos twice) is kept once, so nothing held out is
  also taught.
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
CLEAN = 30.0  # dB: an utterance's speech (its loud frames' median) over its own pauses (its 10th percentile)...
CLEAN_FROM_BEST = 6.0  # ...or this much under their cleanest (the 90th percentile), where that is under CLEAN
RATE = (8.0, 60.0)  # characters a second of loud sound
REGISTER = 1.3  # their usual pitch times or over this
BREATHY = 3.6  # dB: the median harmonics-to-noise ratio of its pitched frames
RECORDING = 2.0  # dB (RMS over the bands) from the most typical video's mean spectrum
BANDS = 40
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


def _mel_bank(n_fft=1024, n_mels=BANDS):
    def hz2mel(f):
        return 2595.0 * np.log10(1.0 + f / 700.0)

    def mel2hz(m):
        return 700.0 * (10.0 ** (m / 2595.0) - 1.0)
    pts = mel2hz(np.linspace(hz2mel(60.0), hz2mel(10000.0), n_mels + 2))
    bins = np.floor((n_fft + 1) * pts / SR).astype(int)
    fb = np.zeros((n_mels, n_fft // 2 + 1))
    for m in range(1, n_mels + 1):
        a, b, c = bins[m - 1], bins[m], bins[m + 1]
        fb[m - 1, a:b] = (np.arange(a, b) - a) / max(1, b - a)
        fb[m - 1, b:c] = (c - np.arange(b, c)) / max(1, c - b)
    return fb


MEL = _mel_bank()


def signature(y, text: str) -> dict:
    """AN UTTERANCE'S SIGNATURE (ONE VOICE): {clean - its speech over its own pauses (dB), rate - characters a second
    of loud sound, f0 - its pitched frames' median pitch (Hz; 0 for none), hnr - their median harmonics-to-noise
    ratio (dB), spectrum - its loud frames' mean over BANDS mel bands (dB), its level taken out}."""
    y = np.asarray(y, dtype=np.float64)
    n = int(FRAME * SR)
    k = len(y) // n
    lv = 10.0 * np.log10((y[: k * n].reshape(k, n) ** 2).mean(1) + 1e-12) if k else np.zeros(1)
    floor = float(np.percentile(lv, 10))
    sp = lv[lv > floor + SOUND]
    out = {"clean": float(np.median(sp) - floor) if len(sp) else 0.0, "rate": 0.0, "f0": 0.0, "hnr": -99.0,
           "spectrum": np.zeros(BANDS)}
    hop, size = 256, 1024
    m = (len(y) - size) // hop
    if m <= 0:
        return out
    fr = np.stack([y[i * hop: i * hop + size] for i in range(m)])
    fr = fr - fr.mean(1, keepdims=True)
    loud = 10.0 * np.log10((fr ** 2).mean(1) + 1e-12) > floor + SOUND
    out["rate"] = len(text) / max(float(loud.sum()) * hop / SR, 0.3)
    fl = fr[loud]
    if not len(fl):
        return out
    ac = np.fft.irfft(np.abs(np.fft.rfft(fl, 2 * size, axis=1)) ** 2, axis=1)[:, :size]
    ac /= ac[:, :1] + 1e-12
    lo, hi = SR // 300, SR // 70
    peak = ac[:, lo:hi].max(1)
    lag = ac[:, lo:hi].argmax(1) + lo
    pitched = peak > 0.5
    if pitched.any():
        r = np.clip(peak[pitched], 1e-3, 0.999)
        out["hnr"] = float(np.median(10.0 * np.log10(r / (1.0 - r))))
        out["f0"] = float(np.median(SR / lag[pitched]))
    power = np.abs(np.fft.rfft(fl * np.hanning(size), axis=1)) ** 2 + 1e-12
    bands = (10.0 * np.log10(power @ MEL.T + 1e-10)).mean(0)
    out["spectrum"] = bands - bands.mean()
    return out


def said_as(text: str) -> str:
    """A sentence as compared for SAID ONCE: lowercase letters, digits and single spaces."""
    return " ".join("".join(ch for ch in text.lower() if ch.isalnum() or ch == " ").split())


def choose(cands: list) -> tuple[list, dict]:
    """WHICH CANDIDATES ARE KEPT (ONE VOICE): [cands] (`[{vid, text, seconds, clean, rate, f0, hnr, spectrum}]`) to
    (the indices kept, in order; {why: {reason: [indices left out]}, register: their usual pitch (Hz), recording: the
    most typical video's id})."""
    why: dict = {}

    def out(i, reason):
        why.setdefault(reason, []).append(i)
    alive = []
    clean = min(CLEAN, float(np.percentile([c["clean"] for c in cands], 90)) - CLEAN_FROM_BEST) if cands else CLEAN
    for i, c in enumerate(cands):
        if c["clean"] < clean:
            out(i, "noisy")
        elif not RATE[0] <= c["rate"] <= RATE[1]:
            out(i, "not paced as speech")
        elif c["f0"] <= 0.0:
            out(i, "unpitched")
        else:
            alive.append(i)
    register = 0.0
    if alive:
        h, e = np.histogram(np.log([cands[i]["f0"] for i in alive]), bins=40,
                            weights=[cands[i]["seconds"] for i in alive])
        register = float(np.exp((e[h.argmax()] + e[h.argmax() + 1]) / 2.0))
    rest = []
    for i in alive:
        if abs(np.log(cands[i]["f0"] / register)) > np.log(REGISTER):
            out(i, "another register")
        elif cands[i]["hnr"] < BREATHY:
            out(i, "breathy")
        else:
            rest.append(i)
    alive = rest
    recording = ""
    vids = sorted({cands[i]["vid"] for i in alive})
    if vids:
        weight = np.array([sum(cands[i]["seconds"] for i in alive if cands[i]["vid"] == v) for v in vids])
        mean = np.array([np.mean([cands[i]["spectrum"] for i in alive if cands[i]["vid"] == v], axis=0) for v in vids])
        apart = np.sqrt(((mean[:, None] - mean[None]) ** 2).mean(2))
        typical = int(np.argmin((apart * weight[None]).sum(1)))
        recording = vids[typical]
        near = {vids[j] for j in range(len(vids)) if apart[typical, j] <= RECORDING}
        rest = []
        for i in alive:
            if cands[i]["vid"] in near:
                rest.append(i)
            else:
                out(i, "another recording")
        alive = rest
    said = set()
    kept = []
    for i in alive:
        key = said_as(cands[i]["text"])
        if key in said:
            out(i, "said twice")
            continue
        said.add(key)
        kept.append(i)
    return kept, {"why": why, "register": register, "recording": recording, "clean": clean}


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


def apply(spec: dict) -> int:
    """THE AGREED CUTS written: each kept sentence's stretch of its clip, its words' ids made again (Kokoro's), the held-out
    ones held out still."""
    from backends.kokoro import SR as KOKORO_SR, KokoroBackend

    global SR
    SR = KOKORO_SR
    src, out = Path(spec["from"]), Path(spec["out"])
    cuts = json.loads(Path(spec["agreed"]).read_text(encoding="utf-8"))
    (out / "wav").mkdir(parents=True, exist_ok=True)
    for old in (out / "wav").glob("*.wav"):
        old.unlink()
    backend = KokoroBackend()
    family, british = str(spec.get("family", "kokoro")), bool(spec.get("british", False))
    train, test, seconds = [], [], 0.0
    for utt, c in cuts.items():
        with wave.open(str(src / "wav" / (utt + ".wav"))) as w:
            y = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").astype(np.float32) / 32768.0
        seg = y[int(float(c["t0"]) * SR): int(float(c["t1"]) * SR)]
        said = [{"text": t, "punct": p} for t, p in (split_word(str(tk)) for tk in c["tokens"]) if t]
        write_wav(out / "wav" / (utt + ".wav"), seg)
        row = "%s|%s|%s" % (utt, " ".join(w["text"] + w["punct"] for w in said),
                            " ".join(map(str, backend.ids_of(said, family, british))))
        (test if c.get("set") == "test.csv" else train).append(row)
        seconds += len(seg) / SR
    write_text(out / "metadata.csv", "\n".join(train) + "\n")
    write_text(out / "test.csv", "\n".join(test) + "\n")
    write_text(out / "phonemes.json", json.dumps(backend._vocabs[family], ensure_ascii=False))
    write_text(Path(spec["index"]), json.dumps({"utterances": len(train), "held_out": len(test),
                                               "minutes": round(seconds / 60.0, 1)}, indent=1))
    say("utterances: %d sentences agreed, %.1f minutes of their voice" % (len(train) + len(test), seconds / 60.0))
    return 0


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="utterances.py")
    ap.add_argument("--ffmpeg", required=True)
    ap.add_argument("--spec", required=True)
    ap.add_argument("--progress", default="")
    a = ap.parse_args(argv)
    spec = json.loads(Path(a.spec).read_text(encoding="utf-8"))
    if spec.get("agreed"):
        return apply(spec)
    out = Path(spec["out"])
    (out / "wav").mkdir(parents=True, exist_ok=True)
    for old in (out / "wav").glob("*.wav"):
        old.unlink()
    pmap = json.loads(Path(spec["config"]).read_text(encoding="utf-8"))["phoneme_id_map"] if spec.get("config") else {}
    espeak = str(spec.get("espeak", "en-us"))
    kokoro = str(spec.get("engine", "piper")) == "kokoro"
    if kokoro:
        # KOKORO'S RATE AND ITS OWN IDS: every measure below reads SR, so the cut and the choice are the same
        global SR
        from backends.kokoro import SR as KOKORO_SR, KokoroBackend
        SR = KOKORO_SR
        backend = KokoroBackend()
        family, british = str(spec.get("family", "kokoro")), bool(spec.get("british", False))
        backend.ids_of([{"text": "a", "punct": ""}], family, british)
        pmap = backend._vocabs[family]
    else:
        from backends.piper import PiperBackend
        backend = PiperBackend()
    cands, why, pitched = [], {}, []
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
            said = [{"text": w["text"], "punct": w["punct"]} for w in r]
            ids = backend.ids_of(said, family, british) if kokoro else ids_of(backend, said, pmap, espeak)
            utt = "%s_%05d" % (v["vid"], k)
            write_wav(out / "wav" / (utt + ".wav"), seg * gain)
            cands.append({"utt": utt, "vid": v["vid"], "text": text, "seconds": len(seg) / SR,
                          "row": "%s|%s|%s" % (utt, text.replace("|", " "), " ".join(map(str, ids))),
                          **signature(seg * gain, text)})
    # ONE VOICE: the candidates chosen together, and the sound of the rest gone
    chosen, found = choose(cands)
    train, test, kept = [], [], {}
    for n, i in enumerate(chosen, start=1):
        c = cands[i]
        (test if n % HELD_OUT == 0 else train).append(c["row"])
        kept[c["vid"]] = kept.get(c["vid"], 0.0) + c["seconds"]
    minutes_out = {}
    for reason, idx in found["why"].items():
        why[reason] = why.get(reason, 0) + len(idx)
        minutes_out[reason] = round(sum(cands[i]["seconds"] for i in idx) / 60.0, 1)
        for i in idx:
            (out / "wav" / (cands[i]["utt"] + ".wav")).unlink(missing_ok=True)
    write_text(out / "metadata.csv", "\n".join(train) + "\n")
    write_text(out / "test.csv", "\n".join(test) + "\n")
    write_text(out / "phonemes.json", json.dumps(pmap, ensure_ascii=False))
    minutes = sum(kept.values()) / 60.0
    summary = {"utterances": len(train), "held_out": len(test), "minutes": round(minutes, 1),
               "by_video": {k: round(s / 60.0, 1) for k, s in kept.items()}, "left_out": why,
               "left_out_minutes": minutes_out, "register": round(found["register"], 1),
               "clean": round(float(found.get("clean", CLEAN)), 1),
               "recording": found["recording"],
               "voiced": [round(float(x), 2) for x in np.percentile(pitched, [10, 50, 90])] if pitched else []}
    write_text(Path(spec["index"]), json.dumps(summary, indent=1))
    progress(a.progress, 1.0)
    heard = sum(c["seconds"] for c in cands) / 60.0
    gone = ", ".join("%s %.0f" % (k, m) for k, m in sorted(minutes_out.items(), key=lambda x: -x[1])) or "none"
    say("utterances: %d utterances, %.0f minutes of their voice from %d videos - one voice of the %.0f minutes cut "
        "(minutes left out: %s; %d whispered runs)" % (len(train), minutes, len(kept), heard, gone, why.get("whispered", 0)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
