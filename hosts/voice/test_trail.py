#!/usr/bin/env python3
"""Tests for the word before a rest in the Piper backend: the trail, and the next word's hiss.

Run it directly with the voice venv's python - no pytest needed:

    ~/.local/share/godot/app_userdata/ghost/voice_venv/bin/python \
        hosts/voice/test_trail.py

What is held, each with the case that must not change:

  1. the final rime is the last vowel run and what follows it (`_final_rimes`);
  2. the trail's weight grows with the rest and is nothing at a full stop, at Pause 0 or with
     `trail` 0 (`_trail_weight`);
  3. the hold scales that rime through `dur_scale`, and nothing else; trail 0 feeds nothing;
  4. the fade takes the word's end down by TRAIL_DB and leaves everything before its tip and
     the next word alone; trail 0 and a full stop return the audio untouched;
  5. the sag lowers the tip's pitch by TRAIL_SAG semitones and keeps the length; a glide that
     would reach the next word is not made;
  6. the next word's hiss in a floored rest is held to LEAD_KEEP, and voice, a short lead and an
     unfloored mark are left alone (`_quiet_lead`).

Synthesis runs against the fake ONNX session of test_expression.py: deterministic audio and
durations, no model download, no eSpeak. Signals for 4-6 are made here: a tone with a hard end,
silence, and noise above 4 kHz.
"""

from __future__ import annotations

import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

from test_expression import _ids_of, _render, _tok, eq, ok  # noqa: E402

SR = 22050
PAUSED = {"pause_scale": 6.5}  # the reporter's setting: a comma rest past TRAIL_REST_FULL

CHECKS: list = []


def check(fn):
    CHECKS.append(fn)
    return fn


def _tone(seconds: float, hz: float = 150.0, amp: float = 0.5):
    """A voice-like tone: a fundamental and its first harmonics."""
    import numpy as np

    t = np.arange(int(round(seconds * SR))) / SR
    x = sum(np.sin(2 * np.pi * hz * k * t) / k for k in (1, 2, 3))
    return (amp * x / np.max(np.abs(x))).astype(np.float32)


def _hiss(seconds: float, amp: float = 0.15, seed: int = 3):
    """Noise with its energy above 4 kHz - an /s/."""
    import numpy as np

    n = int(round(seconds * SR))
    w = np.random.default_rng(seed).standard_normal(n + 2)
    x = w[2:] - 2 * w[1:-1] + w[:-2]
    return (amp * x / np.max(np.abs(x))).astype(np.float32)


def _scene(rest=None):
    """Word 0 a tone over [0.1, 0.5) that stops dead, a rest, word 1 a tone over [0.9, 1.2).
    `rest` is laid over [0.5, 0.9) when given. Returns (audio, edges)."""
    import numpy as np

    a = np.zeros(int(1.3 * SR), dtype=np.float32)
    a[int(0.1 * SR) : int(0.5 * SR)] = _tone(0.4)
    a[int(0.9 * SR) : int(1.2 * SR)] = _tone(0.3)
    if rest is not None:
        a[int(0.5 * SR) : int(0.5 * SR) + rest.size] += rest
    return a, {0: (0.1, 0.5), 1: (0.9, 1.2)}


GROUP = [{"text": "end", "punct": ","}, {"text": "sweet", "punct": "."}]


def _rms_db(a, b, t0: float, t1: float) -> float:
    """Level of `b` against `a` over [t0, t1) seconds, in dB."""
    import numpy as np

    i0, i1 = int(t0 * SR), int(t1 * SR)
    ra = np.sqrt(np.mean(np.square(a[i0:i1], dtype=np.float64)))
    rb = np.sqrt(np.mean(np.square(b[i0:i1], dtype=np.float64)))
    return float(20 * np.log10(rb / ra))


def _f0(x) -> float:
    """Autocorrelation pitch of a voiced stretch, refined between lags."""
    import numpy as np

    x = x.astype(np.float64) - float(np.mean(x))
    ac = np.correlate(x, x, "full")[x.size - 1 :]
    lo, hi = int(SR / 400), int(SR / 70)
    k = lo + int(np.argmax(ac[lo:hi]))
    y0, y1, y2 = ac[k - 1], ac[k], ac[k + 1]
    return SR / (k + 0.5 * (y0 - y2) / (y0 - 2 * y1 + y2))


# -- 1. the final rime ---------------------------------------------------------


@check
def test_final_rimes():
    """The last vowel run with its stress and length marks, and the consonants after it."""
    from backends.piper import _final_rimes

    syms = [
        ("ˈ", 0), ("ɛ", 0), ("n", 0), ("d", 0), (",", 0), (" ", 0),  # end, : all of it
        ("n", 1), ("ˈ", 1), ("ɛ", 1), ("v", 1), ("ɚ", 1), (" ", 1),  # never: only the ɚ
        ("j", 2), ("ˈ", 2), ("u", 2), ("ː", 2), (";", 2), (" ", 2),  # you; : stress, vowel, length
        ("h", 3), ("m", 3), ("m", 3), (" ", 3),  # hmm: no vowel, its last sound
    ]
    eq(sorted(_final_rimes(syms, {0})), [0, 1, 2, 3], "'end': the stressed vowel and its coda")
    eq(sorted(_final_rimes(syms, {1})), [10], "'never': its last syllable, not its stress")
    eq(sorted(_final_rimes(syms, {2})), [13, 14, 15], "'you': stress mark, vowel, length mark")
    eq(sorted(_final_rimes(syms, {3})), [20], "'hmm': the last sound")
    eq(_final_rimes(syms, set()), set(), "a source not asked for is never touched")


# -- 2. the weight -----------------------------------------------------------------


@check
def test_trail_weight():
    """Grows with the rest to 1; nothing at a full stop, at Pause 0, or with trail 0."""
    from backends.piper import TRAIL_REST_FULL, _pause_multiplier, _trail_weight

    eq(_trail_weight(".", PAUSED), 0.0, "a full stop is the model's own")
    eq(_trail_weight("?", PAUSED), 0.0, "and so is a question")
    eq(_trail_weight(",", {"pause_scale": 0.0}), 0.0, "Pause 0: no boundary, no trail")
    eq(_trail_weight(",", {**PAUSED, "trail": 0.0}), 0.0, "trail 0 turns it off")
    eq(_trail_weight(",", PAUSED), 1.0, "a long rest gets all of it")
    eq(_trail_weight(",", {**PAUSED, "trail": 2.0}), 2.0, "trail 2 doubles it")
    one = _trail_weight(",", {"pause_scale": 1.0})
    want = (0.15 + 0.10) * _pause_multiplier({"pause_scale": 1.0}) / TRAIL_REST_FULL
    ok(abs(one - want) < 1e-9, "Pause 1: the comma's rest's share of a full one", "%.3f" % one)
    ok(
        _trail_weight(",", {"pause_scale": 0.5}) < one < _trail_weight(",", {"pause_scale": 1.5}),
        "and it grows with the dial",
    )


# -- 3. the hold, in the duration plan ------------------------------------------------


@check
def test_hold_scales_the_final_rime_only():
    """The comma's word's final rime is scaled by 1 + TRAIL_STRETCH; no other id is."""
    from backends.piper import PAD, TRAIL_STRETCH

    toks = [
        _tok("wait", "", ["W", "EY1", "T"]),
        _tok("end", ",", ["EH1", "N", "D"]),
        _tok("sweet", ".", ["S", "W", "IY1", "T"]),
    ]
    _res, sess, pmap, _pcm = _render(toks, PAUSED)
    fed = sess.fed[0]
    ok(fed["scale"] is not None, "a word before a comma feeds the duration scale")
    scaled = {i for i, m in enumerate(fed["scale"]) if m != 1.0}
    got = {fed["ids"][i] for i in scaled} - {PAD}
    eq(got, _ids_of(pmap, "ˈ", "ɛ", "n", "d"), "the ids scaled are 'end''s final rime")
    ok(
        all(abs(float(fed["scale"][i]) - (1.0 + TRAIL_STRETCH)) < 1e-6 for i in scaled),
        "by 1 + TRAIL_STRETCH",
    )
    comma = fed["ids"].index(pmap.get(",")[0])
    ok(comma not in scaled and comma - 1 in scaled, "the blank after the rime is, the mark is not")
    # the controls: trail off, and a sentence with no mid-sentence mark
    _res, sess, _pmap, _pcm = _render(toks, {**PAUSED, "trail": 0.0})
    eq(sess.fed[0]["scale"], None, "trail 0 feeds no scale")
    plain = [dict(t, punct="") for t in toks[:-1]] + [toks[-1]]
    _res, sess, _pmap, _pcm = _render(plain, PAUSED)
    eq(sess.fed[0]["scale"], None, "a sentence with no comma feeds no scale")


@check
def test_hold_meets_stress_by_multiplying():
    """A leaned-on word before a comma: its stressed vowel gets both."""
    from backends.piper import EMPHASIS, TRAIL_STRETCH

    toks = [_tok("end", ",", ["EH1", "N", "D"], emph=1), _tok("now", ".", ["N", "AW1"])]
    _res, sess, pmap, _pcm = _render(toks, PAUSED)
    fed = sess.fed[0]
    v = fed["ids"].index(pmap.get("ɛ")[0])
    want = EMPHASIS[1][0] * (1.0 + TRAIL_STRETCH)
    ok(abs(float(fed["scale"][v]) - want) < 1e-6, "the vowel: stress x hold", "%.3f" % want)


# -- 4. the fade --------------------------------------------------------------------


@check
def test_fade_takes_the_end_down():
    """Down by about TRAIL_DB at the voice's end, easing in from TRAIL_TIP before it; the
    word's earlier part and the next word are the same samples."""
    import numpy as np
    from backends.piper import TRAIL_DB, TRAIL_TIP, _trail

    a, edges = _scene()
    out = _trail(a, edges, GROUP, PAUSED, SR)
    eq(out.size, a.size, "the length is kept")
    early = int((0.5 - TRAIL_TIP - 0.01) * SR)
    ok(np.array_equal(out[:early], a[:early]), "untouched before the tip")
    ok(np.array_equal(out[int(0.89 * SR) :], a[int(0.89 * SR) :]), "the next word untouched")
    tip = _rms_db(a, out, 0.485, 0.495)
    ok(-TRAIL_DB - 1.0 < tip < -TRAIL_DB + 3.0, "the tip is down by about TRAIL_DB", "%.1f dB" % tip)
    mid = _rms_db(a, out, 0.5 - TRAIL_TIP * 0.55, 0.5 - TRAIL_TIP * 0.45)
    ok(-TRAIL_DB * 0.5 < mid < -0.5, "halfway, part of the way", "%.1f dB" % mid)
    # the controls
    ok(_trail(a, edges, GROUP, {**PAUSED, "trail": 0.0}, SR) is a, "trail 0: the same array")
    stop = [dict(GROUP[0], punct="."), GROUP[1]]
    ok(_trail(a, edges, stop, PAUSED, SR) is a, "a full stop: the same array")


# -- 5. the sag ---------------------------------------------------------------------


@check
def test_sag_lowers_the_tip():
    """The last moments fall by TRAIL_SAG semitones; earlier, the pitch is the word's own."""
    import math

    from backends import piper as P

    a, edges = _scene()
    real_db = P.TRAIL_DB
    P.TRAIL_DB = 0.0  # the pitch alone
    try:
        out = P._trail(a, edges, GROUP, PAUSED, SR)
        P.TRAIL_SAG, sag = 0.0, P.TRAIL_SAG
        try:
            flat = P._trail(a, edges, GROUP, PAUSED, SR)
        finally:
            P.TRAIL_SAG = sag
    finally:
        P.TRAIL_DB = real_db
    w = int(0.03 * SR)
    end = int(0.5 * SR)
    before = 12 * math.log2(_f0(out[end - 4 * w : end - 3 * w]) / 150.0)
    tip = 12 * math.log2(_f0(out[end - w : end]) / 150.0)
    ok(abs(before) < 0.15, "90-120 ms before the end, its own pitch", "%+.2f st" % before)
    ok(
        -sag - 0.2 < tip < -sag * 0.6,
        "the last 30 ms down most of TRAIL_SAG",
        "%+.2f st of %.1f" % (tip, -sag),
    )
    eq(out.size, a.size, "the length is kept")
    flat_tip = 12 * math.log2(_f0(flat[end - w : end]) / 150.0)
    ok(abs(flat_tip) < 0.1, "control: TRAIL_SAG 0 leaves the pitch", "%+.2f st" % flat_tip)


@check
def test_glide_that_does_not_fit_is_not_made():
    """A glide whose run-on would reach `stop` touches nothing."""
    import numpy as np
    from backends.piper import _glide

    a = _tone(0.5)
    b = a.copy()
    end = int(0.4 * SR)
    ok(not _glide(b, end - 2000, end, end, 1.5, end + 10, SR), "refused")
    ok(np.array_equal(a, b), "and nothing was written")
    ok(_glide(b, end - 2000, end, end, 1.5, end + 2000, SR), "with room, made")
    eq(b.size, a.size, "the length is kept")


# -- 6. the next word's hiss --------------------------------------------------------


@check
def test_quiet_lead_holds_the_hiss_to_its_keep():
    """A rest full of the next word's hiss keeps LEAD_KEEP of it, coming in over LEAD_RAMP."""
    import numpy as np
    from backends.piper import LEAD_KEEP, LEAD_RAMP, _quiet_lead

    hiss = _hiss(0.35)
    a, edges = _scene()
    a[int(0.55 * SR) : int(0.55 * SR) + hiss.size] += hiss  # 0.55 to 0.90: a 350 ms lead
    out = _quiet_lead(a, edges, GROUP, PAUSED, SR)
    keep = int(round(0.9 * SR)) - int(round(LEAD_KEEP * SR))
    ok(
        float(np.max(np.abs(out[int(0.56 * SR) : keep]))) == 0.0,
        "silent from where the hiss started to the kept lead",
    )
    ramp = keep + int(round(LEAD_RAMP * SR))
    ok(np.array_equal(out[ramp:], a[ramp:]), "the kept lead, past its ramp, and the next word untouched")
    ok(np.array_equal(out[: int(0.55 * SR)], a[: int(0.55 * SR)]), "the word before untouched")
    rise = np.abs(out[keep:ramp]).reshape(-1)
    ok(rise[: rise.size // 4].max() < rise[-rise.size // 4 :].max(), "the lead comes in, not on")


@check
def test_quiet_lead_leaves_the_rest_alone():
    """Controls: a lead shorter than LEAD_KEEP, voice in the rest, and a mark with no floor."""
    import numpy as np
    from backends.piper import LEAD_KEEP, _quiet_lead

    a, edges = _scene()
    short = _hiss(LEAD_KEEP * 0.75)
    a[int(0.9 * SR) - short.size : int(0.9 * SR)] += short
    ok(_quiet_lead(a, edges, GROUP, PAUSED, SR) is a, "a short lead is the model's own")
    voiced, edges = _scene(_tone(0.35, amp=0.2))
    ok(_quiet_lead(voiced, edges, GROUP, PAUSED, SR) is voiced, "voice in the rest is not hiss")
    full, edges = _scene(_hiss(0.4))
    stop = [dict(GROUP[0], punct="."), GROUP[1]]
    ok(_quiet_lead(full, edges, stop, PAUSED, SR) is full, "a mark with no floor is not looked at")
    ok(
        _quiet_lead(full, edges, GROUP, {"pause_scale": 0.0}, SR) is full,
        "nor is a comma at Pause 0",
    )
    ok(not np.array_equal(_quiet_lead(full, edges, GROUP, PAUSED, SR), full), "(and the case itself does)")


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
