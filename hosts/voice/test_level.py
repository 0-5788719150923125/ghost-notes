"""Tests for every voice at one level (level.py), and the host playing each take at its voice's gain
(backends/piper.py `_leveled`, `_synth_tokens`).

Run it directly with the voice venv's python - no pytest needed:

    ~/.local/share/godot/app_userdata/ghost/voice_venv/bin/python hosts/voice/test_level.py

eSpeak is real here (the host's own reading of the words); no voice model is loaded.

  THE SPEAKING LEVEL - a voice's level is its speech's, its pauses left out: a tone between silences reads the
  tone's RMS, and twice as loud reads twice as much (CONTROL: the plain RMS over the pauses too reads under it).
  ONE GAIN A VOICE - a voice twice as loud as another is played at half its gain, so the two come out alike; the
  target voice is played as it is (CONTROL: as they come, the two are 6 dB apart).
  KEPT - a second host on the same folder measures nothing; a model file changed measures again; a measure that
  fails is played at 1 and not kept (CONTROL: the next asks again).
  THE TAKE - the host writes a take at its gain, scaled whole (CONTROL: with no gain asked, as the model made it).
"""

from __future__ import annotations

import os
import sys
import tempfile
import time
import wave
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import numpy as np  # noqa: E402

import level as L  # noqa: E402

CHECKS = []
SR = 22050


def check(fn):
    CHECKS.append(fn)
    return fn


def ok(cond, what):
    if not cond:
        raise AssertionError(what)
    print(f"    ok   {what}")


def _spoken(amp: float) -> np.ndarray:
    """Half a second of silence, a second of a 140 Hz buzz at `amp`, half a second of silence."""
    t = np.arange(SR) / SR
    tone = amp * (np.sin(2 * np.pi * 140 * t) + 0.5 * np.sin(2 * np.pi * 280 * t)) / 1.118
    z = np.zeros(SR // 2)
    return np.concatenate([z, tone, z]).astype(np.float32)


class _Voice:
    """Stands in for a backend: `_run` makes `_spoken(amp)` for a sentence, and counts how often it is asked."""

    def __init__(self, amp: float, model: Path, fail: bool = False) -> None:
        self.amp = amp
        self.model = model
        self.fail = fail
        self.runs = 0

    def _run(self, group, voice, params, cfg, sess, phonemizer):
        self.runs += 1
        if self.fail:
            raise RuntimeError("the graph would not open")
        return _spoken(self.amp), []

    def _level_files(self, voice, speaker):
        return [self.model]


CFG = {"audio": {"sample_rate": SR}}


@check
def the_speaking_level():
    a = _spoken(0.1)
    lv = L.speaking_level(a, SR)
    plain = float(np.sqrt(np.mean(a.astype(np.float64) ** 2)))
    ok(abs(lv - 0.1 / np.sqrt(2)) < 0.002, "a tone between silences reads its own RMS (%.4f)" % lv)
    ok(abs(L.speaking_level(_spoken(0.2), SR) / lv - 2.0) < 0.01, "twice as loud reads twice as much")
    ok(plain < lv * 0.75, "CONTROL: the plain RMS over the pauses too reads under it (%.4f)" % plain)


@check
def one_gain_a_voice():
    with tempfile.TemporaryDirectory() as td:
        model = Path(td) / "m.onnx"
        model.write_bytes(b"x")
        levels = L.Levels(Path(td))
        quiet = _Voice(0.05, model)
        loud = _Voice(0.10, model)
        gq = levels.gain(quiet, "quiet", 0, CFG, None)
        gl = levels.gain(loud, "loud", 0, CFG, None)
        out_q = L.speaking_level(_spoken(0.05) * gq, SR)
        out_l = L.speaking_level(_spoken(0.10) * gl, SR)
        ok(abs(gq / gl - 2.0) < 0.01, "a voice twice as loud is played at half the gain (%.3f, %.3f)" % (gq, gl))
        ok(abs(out_q - L.TARGET) < 1e-4 and abs(out_l - L.TARGET) < 1e-4,
           "both come out at the target (%.4f, %.4f)" % (out_q, out_l))
        at = _Voice(L.TARGET * np.sqrt(2), model)
        ok(abs(levels.gain(at, "target", 0, CFG, None) - 1.0) < 0.01, "the target voice is played as it is")
        apart = 20 * np.log10(L.speaking_level(_spoken(0.10), SR) / L.speaking_level(_spoken(0.05), SR))
        ok(abs(apart - 6.02) < 0.1, "CONTROL: as they come, the two are %.1f dB apart" % apart)


@check
def kept():
    with tempfile.TemporaryDirectory() as td:
        model = Path(td) / "m.onnx"
        model.write_bytes(b"x")
        first = _Voice(0.08, model)
        g1 = L.Levels(Path(td)).gain(first, "v", 3, CFG, None)
        again = _Voice(0.08, model)
        g2 = L.Levels(Path(td)).gain(again, "v", 3, CFG, None)
        ok(first.runs == 2 and again.runs == 0 and abs(g1 - g2) < 1e-5,
           "a second host on the same folder measures nothing (%d renders, then %d)" % (first.runs, again.runs))
        later = time.time() + 5.0
        os.utime(model, (later, later))
        changed = _Voice(0.16, model)
        g3 = L.Levels(Path(td)).gain(changed, "v", 3, CFG, None)
        ok(changed.runs == 2 and abs(g1 / g3 - 2.0) < 0.01, "a model file changed measures again (gain %.3f)" % g3)
        broken = _Voice(0.08, model, fail=True)
        gb = L.Levels(Path(td)).gain(broken, "b", 0, CFG, None)
        retry = _Voice(0.08, model, fail=True)
        L.Levels(Path(td)).gain(retry, "b", 0, CFG, None)
        ok(gb == 1.0, "a measure that fails is played at 1")
        ok(retry.runs == 1, "CONTROL: it is not kept - the next host asks again")


class _Recorder:
    """Stands in for a voice's graph: a steady tone, one frame an id."""

    def run(self, _outputs, feeds):
        from backends.piper import HOP_LENGTH
        n = len(feeds["input"][0])
        frames = np.full(n, 2.0, np.float32)
        audio = (0.3 * np.sin(np.arange(int(frames.sum()) * HOP_LENGTH) / 9.0)).astype(np.float32)
        return [audio.reshape(1, 1, -1), frames.reshape(1, -1)]


def _take(params: dict) -> np.ndarray:
    from backends.piper import PiperBackend
    be = PiperBackend()
    toks = L.tokens_of("The road ran on past the river.")
    syms = be._symbols(toks, "espeak", "en-us", "")
    pmap = {ch: [i + 3] for i, ch in enumerate(sorted({s for s, _ in syms} | set("ˈˌːəɪɛæʊ")))}
    cfg = {"audio": {"sample_rate": SR}, "phoneme_id_map": pmap, "num_speakers": 1, "inference": {},
           "espeak": {"voice": "en-us"}}
    with tempfile.TemporaryDirectory() as td:
        out = Path(td) / "take.wav"
        be._synth_tokens(toks, "fake", str(out), {"phonemizer": "espeak", "trail": 0.0, "lexicon": "off", **params},
                         cfg, _Recorder())
        with wave.open(str(out)) as w:
            return np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").astype(np.float64) / 32767.0


@check
def the_take():
    plain = _take({})
    half = _take({"level_gain": 0.5})
    ok(plain.size == half.size and np.max(np.abs(half - plain * 0.5)) < 2.0 / 32767.0,
       "the host writes a take at its gain, scaled whole")
    ok(np.max(np.abs(plain)) > 0.25, "CONTROL: with no gain asked, as the model made it (peak %.2f)" % np.max(np.abs(plain)))


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
