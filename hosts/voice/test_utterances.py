#!/usr/bin/env python3
"""Tests for an actor's speech cut into the sentences their voice is taught on (utterances.py), and for the
voices trained here that the voice host lists (backends/piper.py, `TRAINED`).

Run it directly with the voice venv's python - no pytest needed:

    ~/.local/share/godot/app_userdata/ghost/voice_venv/bin/python hosts/voice/test_utterances.py

eSpeak is real here (the ids are its reading); the sound is made, and no voice model is loaded.

  THE IDS ARE THE HOST'S - a sentence's ids, as utterances.py writes them, are the ids the voice host
  feeds its graph for the same words (CONTROL: laid out with the pad after each id, they are not).
  THE WORDS - a word's marks and quotes come apart; runs break at a pause, sooner after a sentence's end,
  and a run too long is split at its longest gap.
  THE CUT - lands in the quiet past where a word's sound falls; refused where the pause holds sound, or
  where a sound no word was heard in lies inside (CONTROL: the same sound under a word is kept).
  THE VOICE - a pitched sound counts as spoken, noise as whispered.
  ITS SIGNATURE - a made voice at 125 Hz between quiet pauses reads its pitch, a clear harmonics-to-noise ratio and
  speech well over its pauses; the same voice under a noise floor reads as noisy (CONTROL: noise alone has no pitch).
  A voice at 280 Hz reads 280, and a rumble - its correlation only falling - reads no pitch, never the search's edge
  (CONTROL: by its correlation's peak alone it would read pitched, at the edge; the code before read it 302 Hz).
  ONE VOICE - of made candidates, the noisy, the music-paced, the high, the breathy, the sentence said twice and the
  video of another recording are each left out for their own reason, and the rest kept (CONTROL: with no limit on
  the recording, the other video is kept).
  TRAINED VOICES - one published with its config is listed, owned and its files found where it lies, never
  fetched (CONTROL: without its config, or by a name with a path in it, it is not).
"""

from __future__ import annotations

import json
import os
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import numpy as np  # noqa: E402

import utterances as U  # noqa: E402

CHECKS = []


def check(fn):
    CHECKS.append(fn)
    return fn


def ok(cond, what):
    if not cond:
        raise AssertionError(what)
    print(f"    ok   {what}")


def _tokens(line: str) -> list:
    out = []
    for w in line.split():
        t, p = U.split_word(w)
        out.append({"text": t, "punct": p})
    return out


class _Recorder:
    """Stands in for a voice's graph: records the ids it is fed, one frame each."""

    def __init__(self) -> None:
        self.fed: list = []

    def run(self, _outputs, feeds):
        from backends.piper import HOP_LENGTH
        ids = [int(i) for i in feeds["input"][0]]
        self.fed.append(ids)
        frames = np.full(len(ids), 2.0, np.float32)
        audio = (0.5 * np.sin(np.arange(int(frames.sum()) * HOP_LENGTH) / 9.0)).astype(np.float32)
        return [audio.reshape(1, 1, -1), frames.reshape(1, -1)]


@check
def the_ids_are_the_hosts():
    from backends.piper import BOS, EOS, PAD, PiperBackend
    be = PiperBackend()
    line = "Honestly, I read it twice, and then I closed the book."
    syms = be._symbols(_tokens(line), "espeak", "en-us", "")
    pmap = {ch: [i + 3] for i, ch in enumerate(sorted({s for s, _ in syms} | set("ˈˌːəɪɛæʊ")))}
    ids = U.ids_of(be, _tokens(line), pmap, "en-us")
    cfg = {"audio": {"sample_rate": 22050}, "phoneme_id_map": pmap, "num_speakers": 1, "inference": {},
           "espeak": {"voice": "en-us"}}
    sess = _Recorder()
    with tempfile.TemporaryDirectory() as td:
        be._synth_tokens(_tokens(line), "fake", str(Path(td) / "take.wav"),
                         {"phonemizer": "espeak", "trail": 0.0, "lexicon": "off"}, cfg, sess)
    ok(len(sess.fed) == 1, "the sentence is one request (%d)" % len(sess.fed))
    ok(sess.fed[0] == ids, "the ids taught are the ids the host sends (%d and %d ids)" % (len(ids), len(sess.fed[0])))
    ok(ids[0] == BOS and ids[1] == PAD and ids[-1] == EOS and ids[-2] == PAD, "they open and close as the host's do")
    after = [BOS] + [x for i in ids[2:-2:2] for x in (i, PAD)] + [EOS]
    ok(after != sess.fed[0], "CONTROL: the pad after each id is not the host's layout")


@check
def the_words():
    ok(U.split_word("better.") == ("better", "."), "a full stop comes off its word")
    ok(U.split_word('"Hello,"') == ("Hello", ","), "quotes go, the comma is kept")
    ok(U.split_word("well-known") == ("well-known", ""), "a hyphen inside a word stays")
    ok(U.split_word("—") == ("", ""), "a dash alone is no word")

    def w(text, t0, t1, p=0.95):
        t, punct = U.split_word(text)
        return {"text": t, "punct": punct, "t0": t0, "t1": t1, "p": p}

    words = [w("one", 0.0, 0.3), w("two", 0.35, 0.6), w("three.", 0.65, 0.9),  # 0.25 after a full stop
             w("four", 1.15, 1.4), w("five", 1.6, 1.9),                             # 0.2 with none: no break
             w("six", 2.35, 2.6)]                                                   # 0.45: a break
    rs = U.runs(words)
    ok([[x["text"] for x in r] for r in rs] == [["one", "two", "three"], ["four", "five"], ["six"]],
       "runs break at a pause, sooner after a sentence's end: %s" % [[x["text"] for x in r] for r in rs])
    long, t = [], 0.0
    for i in range(30):
        long.append(w("w%d" % i, t, t + 0.4))
        t += 0.7 if i == 14 else 0.5  # every gap 0.1 s, and 0.3 after the fifteenth
    rs = U.runs(long)
    ok([len(r) for r in rs] == [15, 15] and all(r[-1]["t1"] - r[0]["t0"] <= U.LONGEST for r in rs),
       "a run too long is split, and no word lost: %s" % [len(r) for r in rs])


def _lv(spec: list) -> np.ndarray:
    """Frame levels from [(frames, dB)]."""
    return np.concatenate([np.full(n, db, np.float64) for n, db in spec])


@check
def the_cut():
    floor = -60.0
    f = U.FRAME
    # pause (room) 40 frames, words 100 frames at -20 dB, then the sound falling over 5 frames, pause 40
    lv = _lv([(40, -60.0), (100, -20.0), (5, -40.0), (40, -60.0), (100, -20.0), (40, -60.0)])
    lv[30] = -63.0  # the quietest frame of the pause before
    lv[155] = -64.0  # ...and of the one after
    words = [[{"text": "a", "punct": "", "t0": 40 * f, "t1": 90 * f, "p": 0.95},
              {"text": "b", "punct": "", "t0": 92 * f, "t1": 135 * f, "p": 0.95}],  # Whisper's end, early
             [{"text": "c", "punct": "", "t0": 185 * f, "t1": 285 * f, "p": 0.95},
              {"text": "d", "punct": "", "t0": 285 * f, "t1": 285 * f, "p": 0.95}]]
    reach = [(U.sound_from(lv, floor, int(r[0]["t0"] / f), -1), U.sound_from(lv, floor, int(r[-1]["t1"] / f), 1))
             for r in words]
    got = U.cut(words, 0, lv, floor, reach, [])
    ok(got == (30, 156),
       "the cut lands in the quiet before, and past the sound's fall after: %s" % (got,))
    ok(reach[0][1] >= 145, "a word's end is walked out to where its sound falls (frame %d)" % reach[0][1])
    # the pause holds sound: nowhere quiet to cut
    loud = lv.copy()
    loud[140:185] = -30.0
    reach2 = [(U.sound_from(loud, floor, int(r[0]["t0"] / f), -1), U.sound_from(loud, floor, int(r[-1]["t1"] / f), 1))
              for r in words]
    ok(isinstance(U.cut(words, 0, loud, floor, reach2, []), str), "a pause that holds sound is no place to cut")
    # a sound inside that no word was heard in
    words3 = [[{"text": "a", "punct": "", "t0": 40 * f, "t1": 60 * f, "p": 0.95},
               {"text": "b", "punct": "", "t0": 120 * f, "t1": 140 * f, "p": 0.95}]]
    lv3 = _lv([(40, -60.0), (100, -20.0), (40, -60.0)])
    reach3 = [(U.sound_from(lv3, floor, 40, -1), U.sound_from(lv3, floor, 140, 1))]
    blobs = [(80, 100)]  # 0.4 s of sound, 20 frames from either word
    ok(U.cut(words3, 0, lv3, floor, reach3, blobs) == "a sound the words lack", "a sound the words lack is refused")
    words3[0].insert(1, {"text": "um", "punct": ",", "t0": 82 * f, "t1": 98 * f, "p": 0.9})
    ok(isinstance(U.cut(words3, 0, lv3, floor, reach3, blobs), tuple), "CONTROL: the same sound under a word is kept")


@check
def the_voice():
    t = np.arange(U.SR) / U.SR
    tone = sum(0.3 / k * np.sin(2 * np.pi * 140 * k * t) for k in range(1, 8)).astype(np.float32)
    noise = (0.2 * np.random.default_rng(1).standard_normal(U.SR)).astype(np.float32)
    ok(U.voiced(tone, -80.0) > 0.9, "a pitched sound is spoken (%.2f)" % U.voiced(tone, -80.0))
    ok(U.voiced(noise, -80.0) < 0.1, "CONTROL: noise is whispered (%.2f)" % U.voiced(noise, -80.0))


def _voice_at(f0: float, noise: float, seed: int = 1):
    """A second of a made voice at [f0] Hz between quiet pauses, under a noise floor of [noise]."""
    rng = np.random.default_rng(seed)
    t = np.arange(U.SR) / U.SR
    tone = sum(0.3 / k * np.sin(2 * np.pi * f0 * k * t) for k in range(1, 8))
    pause = np.zeros(int(0.3 * U.SR))
    y = np.concatenate([pause, tone, pause])
    return y + noise * rng.standard_normal(len(y))


@check
def its_signature():
    sig = U.signature(_voice_at(125.0, 1e-4), "a sentence of thirty letters")
    ok(abs(sig["f0"] - 125.0) < 6.0, "the made voice's pitch reads %.1f Hz (125)" % sig["f0"])
    ok(sig["hnr"] > U.BREATHY and sig["clean"] > U.CLEAN, "its harmonics %.1f dB, its speech %.1f dB over its pauses" % (sig["hnr"], sig["clean"]))
    ok(sig["spectrum"].shape == (U.BANDS,) and abs(float(sig["spectrum"].mean())) < 1e-6, "its spectrum is its bands less their level")
    noisy = U.signature(_voice_at(125.0, 0.05), "a sentence of thirty letters")
    ok(noisy["clean"] < U.CLEAN and noisy["hnr"] < sig["hnr"], "under a noise floor it reads %.1f dB over its pauses, its harmonics %.1f dB" % (noisy["clean"], noisy["hnr"]))
    hiss = U.signature(0.2 * np.random.default_rng(2).standard_normal(U.SR), "hiss")
    ok(hiss["f0"] == 0.0, "CONTROL: noise alone has no pitch (%.1f Hz)" % hiss["f0"])
    high = U.signature(_voice_at(280.0, 1e-4), "a sentence of thirty letters")
    ok(abs(high["f0"] - 280.0) < 10.0, "a voice at 280 Hz reads %.1f" % high["f0"])
    rumble = np.random.default_rng(3).standard_normal(U.SR)
    for i in range(1, len(rumble)):  # a one-pole low pass: its correlation falls as 0.995 a sample
        rumble[i] += 0.995 * rumble[i - 1]
    pause = np.zeros(int(0.3 * U.SR))
    rumble = np.concatenate([pause, 0.3 * rumble / np.abs(rumble).max(), pause]) + 1e-4 * np.random.default_rng(4).standard_normal(U.SR + 2 * len(pause))
    ok(U.signature(rumble, "a sentence of thirty letters")["f0"] == 0.0, "a rumble reads no pitch (%.1f Hz)"
       % U.signature(rumble, "a sentence of thirty letters")["f0"])
    fr = rumble[len(pause) + 2048: len(pause) + 2048 + 1024]
    fr = fr - fr.mean()
    ac = np.fft.irfft(np.abs(np.fft.rfft(fr, 2048)) ** 2)[:1024]
    ac /= ac[0]
    window = ac[U.SR // 300: U.SR // 70]
    ok(window.max() > 0.5 and window.argmax() == 0, "CONTROL: by its correlation's peak alone it reads pitched, at %.0f Hz"
       % (U.SR / (U.SR // 300)))


def _cands():
    base = np.linspace(-6.0, 6.0, U.BANDS)
    tilt = base + np.linspace(-4.0, 4.0, U.BANDS)
    c = []
    for n in range(30):
        c.append({"vid": "a", "text": "sentence number %d" % n, "seconds": 4.0, "clean": 40.0, "rate": 15.0,
                  "f0": 125.0 + (n % 5), "hnr": 6.0, "spectrum": base})
    for n in range(10):
        c.append({"vid": "b", "text": "another sentence %d" % n, "seconds": 4.0, "clean": 40.0, "rate": 15.0,
                  "f0": 125.0, "hnr": 6.0, "spectrum": tilt})
    odd = {"noisy": {"clean": 20.0}, "not paced as speech": {"rate": 70.0}, "another register": {"f0": 200.0},
           "breathy": {"hnr": 2.0}, "said twice": {"text": "Sentence number 3!"}}
    for reason, change in odd.items():
        c.append({**c[0], "text": "odd one " + reason, **change})
    return c, list(odd)


@check
def one_voice():
    c, reasons = _cands()
    kept, found = U.choose(c)
    why = found["why"]
    ok(all(len(why.get(r, [])) == 1 for r in reasons), "each odd one is left out for its own reason: %s" % why)
    ok(len(why.get("another recording", [])) == 10, "the video of another recording is left out (%d of 10)" % len(why.get("another recording", [])))
    ok(len(kept) == 30 and abs(found["register"] - 127.0) < 6.0 and found["recording"] == "a",
       "the rest kept (%d of 30), their register %.1f Hz, the typical recording %s" % (len(kept), found["register"], found["recording"]))
    was = U.RECORDING
    try:
        U.RECORDING = 99.0
        kept2, found2 = U.choose(c)
    finally:
        U.RECORDING = was
    ok(len(kept2) == 40 and "another recording" not in found2["why"], "CONTROL: with no limit, the other recording is kept")


@check
def soft_spoken():
    """THEIR OWN CLEAN (2026-10-26, an ASMR channel: soft speech over a high-gain microphone's hiss, a median 19 dB over
    its pauses and 30 for none of 253): every sentence 19 to 25 dB keeps them all and leaves the noisy one out, where 30
    dB whoever they are would keep none (THE CONTROL)."""
    c, _ = _cands()
    soft = [{**x, "clean": 19.0 + (i % 7)} for i, x in enumerate(c[:30])] + [{**c[0], "text": "a noisy one", "clean": 9.0}]
    kept, found = U.choose(soft)
    ok(len(kept) == 30 and found["why"].get("noisy") == [30] and abs(found["clean"] - 19.0) < 0.6,
       "a soft voice keeps its clean ones (%d of 30), its noisy one left out, the floor %.1f dB" % (len(kept), found["clean"]))
    was = U.CLEAN_FROM_BEST
    try:
        U.CLEAN_FROM_BEST = -99.0
        kept2, _f2 = U.choose(soft)
    finally:
        U.CLEAN_FROM_BEST = was
    ok(not kept2, "CONTROL: held to 30 dB whoever they are, it keeps none (%d)" % len(kept2))


@check
def trained_voices():
    from backends import piper as P
    old = os.environ.get("XDG_DATA_HOME")
    with tempfile.TemporaryDirectory() as td:
        os.environ["XDG_DATA_HOME"] = td
        try:
            d = Path(td) / "ghost" / "voices" / "piper" / P.TRAINED
            d.mkdir(parents=True)
            (d / "actor-x.onnx").write_bytes(b"not a graph")
            (d / "actor-x.onnx.json").write_text("{}")
            (d / "actor-x.voice.json").write_text(json.dumps({"name": "A Person (their own voice)", "actor": "x",
                                                              "license": "theirs", "chain": "fine-tuned"}))
            (d / "actor-y.onnx").write_bytes(b"not a graph")  # no config
            be = P.PiperBackend()
            listed = {v["id"]: v for v in be.voices()}
            ok("actor-x" in listed and listed["actor-x"]["installed"] and listed["actor-x"]["name"] == "A Person (their own voice)",
               "a voice trained here is listed under its name, installed")
            ok(P.PiperBackend.owns("actor-x") and be._files("actor-x")[0] == d / "actor-x.onnx",
               "it is owned, and its files are where it lies")
            ok(be.ensure("actor-x") == {"voice": "actor-x", "installed": True, "downloaded": False}, "it is never fetched")
            ok("actor-y" not in listed and not P.PiperBackend.owns("actor-y"), "CONTROL: one without its config is not")
            ok(not P.PiperBackend.owns("../trained/actor-x"), "CONTROL: a name with a path in it is not")
            ok(be._files("en_US-john-medium")[0].parent == d.parent, "an allowlisted voice is still found where it was")
        finally:
            if old is None:
                os.environ.pop("XDG_DATA_HOME", None)
            else:
                os.environ["XDG_DATA_HOME"] = old


def main() -> int:
    failed = 0
    for fn in CHECKS:
        print(f"\n{fn.__name__}")
        try:
            fn()
        except AssertionError as exc:
            failed += 1
            print(f"    FAIL {exc}")
    print(f"\n{len(CHECKS) - failed}/{len(CHECKS)} checks passed")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
