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
     unfloored mark are left alone (`_quiet_lead`);
  7. a word that ends on a hiss keeps it ("cards," is not "card,"): the plan says which words and
     how many runs (`_hiss_codas`), the waveform says where, the voice ends before it, and the
     floor comes back after it; a word the plan does not name, a second run it does not spell
     (the /t/ of "last,") and a stray hiss out in the rest all keep the floor; a hiss that sits
     between 2 and 4 kHz ("hush,") is one too, and the voice falls no further than a loud one;
  8. a next word that starts before the plan says is not dipped; with TRAIL_EARLY 0 it is.

Synthesis runs against the fake ONNX session of test_expression.py: deterministic audio and
durations, no model download, no eSpeak. Signals for 4-8 are made here: a tone with a hard end,
silence, a faint room tone, and noise above 4 kHz.
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


# -- 7. a word's own hiss ------------------------------------------------------------


def _room(seconds: float, amp: float = 0.0015, seed: int = 5):
    """A faint low room tone (about -50 dB under the tone), so a rest has a level to measure."""
    import numpy as np

    n = int(round(seconds * SR))
    w = np.random.default_rng(seed).standard_normal(n + 15)
    x = np.convolve(w, np.ones(16) / 16.0, "valid")
    return (amp * x / np.max(np.abs(x))).astype(np.float32)


def _shh(seconds: float, amp: float = 0.03, seed: int = 11):
    """Noise between 2 and 4 kHz - a /ʃ/, which has next to nothing above 4."""
    import numpy as np

    n = int(round(seconds * SR))
    spec = np.fft.rfft(np.random.default_rng(seed).standard_normal(n))
    f = np.fft.rfftfreq(n, 1.0 / SR)
    spec[(f < 2200.0) | (f > 3800.0)] = 0.0
    x = np.fft.irfft(spec, n)
    return (amp * x / np.max(np.abs(x))).astype(np.float32)


def _plural(hisses=((0.44, 0.50),), voice_to: float = 0.42, amp: float = 0.03, make=_hiss):
    """`_scene` with word 0 ending on a hiss: its tone over [0.1, voice_to), each (t0, t1) of
    `hisses` a hiss at `amp` (-24 dB under the tone, a final /z/'s level), and a room tone
    under the whole rest. The plan's last sound is 0.45: before the hiss ends, as it is."""
    import numpy as np

    a = np.zeros(int(1.3 * SR), dtype=np.float32)
    a[int(0.1 * SR) : int(voice_to * SR)] = _tone(voice_to - 0.1)
    a[int(0.9 * SR) : int(1.2 * SR)] = _tone(0.3)
    a[int(voice_to * SR) : int(0.9 * SR)] += _room(0.9 - voice_to)
    for k, (t0, t1) in enumerate(hisses):
        h = make(t1 - t0, amp=amp, seed=7 + k)
        a[int(t0 * SR) : int(t0 * SR) + h.size] += h
    return a, {0: (0.1, 0.45), 1: (0.9, 1.2)}


@check
def test_hiss_codas():
    """Which words end on a hiss, and on how many runs of it."""
    from backends.piper import _hiss_codas

    syms = [
        ("k", 0), ("ˈ", 0), ("ɑ", 0), ("ː", 0), ("ɹ", 0), ("d", 0), ("z", 0), (",", 0), (" ", 0),
        ("k", 1), ("ˈ", 1), ("ɑ", 1), ("ː", 1), ("ɹ", 1), ("d", 1), (" ", 1),
        ("ˈ", 2), ("æ", 2), ("s", 2), ("k", 2), ("s", 2), (" ", 2),
        ("l", 3), ("ˈ", 3), ("æ", 3), ("s", 3), ("t", 3), (" ", 3),
        ("s", 4), ("ˈ", 4), ("ɪ", 4), ("s", 4), ("t", 4), ("ɚ", 4), (" ", 4),
        ("m", 5), ("ˈ", 5), ("ʌ", 5), ("n", 5), ("θ", 5), ("s", 5), (" ", 5),
        ("ʃ", 6), ("ʃ", 6), (".", 6),
    ]
    got = _hiss_codas(syms)
    eq(got.get(0), 1, "'cards': one run, after its last vowel")
    ok(1 not in got, "'card': no hiss, not named")
    eq(got.get(2), 2, "'asks': two, a stop between them")
    eq(got.get(3), 1, "'last': one, and the stop after it is not another")
    ok(4 not in got, "'sister': its hisses are before its last vowel")
    eq(got.get(5), 1, "'months': two hisses side by side are one run")
    eq(got.get(6), 1, "'shh': no vowel, the whole word")


@check
def test_a_final_hiss_is_kept():
    """Voice, a stop's closure, a hiss: the hiss at its own level, the voice still down before
    it, the floor back after it. Unnamed, the same word loses the hiss - the reported fault."""
    import numpy as np
    from backends.piper import TRAIL_DB, _trail

    a, edges = _plural()
    out = _trail(a, edges, GROUP, PAUSED, SR, {0: 1})
    eq(out.size, a.size, "the length is kept")
    kept = _rms_db(a, out, 0.445, 0.495)
    ok(abs(kept) < 0.5, "the hiss is the model's own level", "%+.1f dB" % kept)
    tip = _rms_db(a, out, 0.395, 0.405)
    ok(tip < -TRAIL_DB * 0.5, "the voice still falls away before it", "%+.1f dB" % tip)
    rest = _rms_db(a, out, 0.60, 0.80)
    ok(abs(rest + TRAIL_DB) < 1.0, "and the floor is back in the rest after it", "%+.1f dB" % rest)
    ok(np.array_equal(out[int(0.895 * SR) :], a[int(0.895 * SR) :]), "the next word untouched")
    # the control, and what a stop's release still gets: a word the plan does not name
    for name, arg in (("no plan", None), ("another word's", {1: 1})):
        lost = _rms_db(a, _trail(a, edges, GROUP, PAUSED, SR, arg), 0.445, 0.495)
        ok(lost < -TRAIL_DB + 2.0, "control (%s): the hiss is under the floor" % name, "%+.1f dB" % lost)


@check
def test_voice_that_runs_into_its_hiss():
    """No closure, and a hiss loud enough to pass for voice ("eyes,", "answers,"): the voice
    ends where the hiss begins instead of somewhere inside it."""
    from backends.piper import TRAIL_DB, _trail

    a, edges = _plural(hisses=((0.42, 0.52),), amp=0.2)
    out = _trail(a, edges, GROUP, PAUSED, SR, {0: 1})
    kept = _rms_db(a, out, 0.43, 0.515)
    ok(abs(kept) < 0.5, "the hiss is the model's own level", "%+.1f dB" % kept)
    tip = _rms_db(a, out, 0.39, 0.40)
    ok(tip < -TRAIL_DB * 0.5, "the voice has fallen away by the time it starts", "%+.1f dB" % tip)
    # the control: unnamed, the fade runs through the hiss
    lost = _rms_db(a, _trail(a, edges, GROUP, PAUSED, SR), 0.49, 0.515)
    ok(lost < -TRAIL_DB * 0.5, "control: unnamed, the end of the hiss is faded", "%+.1f dB" % lost)


@check
def test_a_low_hiss_is_a_hiss():
    """A /ʃ/ sits between 2 and 4 kHz: found whole. Looked for above 4 kHz, as a lead is, it
    is not found and goes under the floor."""
    from backends import piper as P

    a, edges = _plural(hisses=((0.44, 0.56),), make=_shh)
    kept = _rms_db(a, P._trail(a, edges, GROUP, PAUSED, SR, {0: 1}), 0.45, 0.55)
    ok(abs(kept) < 0.5, "the whole of it is the model's own level", "%+.1f dB" % kept)
    real = P.TRAIL_HISS_ABOVE
    P.TRAIL_HISS_ABOVE = P.LEAD_ABOVE
    try:
        lost = _rms_db(a, P._trail(a, edges, GROUP, PAUSED, SR, {0: 1}), 0.45, 0.55)
    finally:
        P.TRAIL_HISS_ABOVE = real
    ok(lost < -P.TRAIL_DB + 2.0, "control: above 4 kHz it is not seen", "%+.1f dB" % lost)


@check
def test_the_voice_falls_no_further_than_its_hiss():
    """Before a hiss as loud as the voice the fade is next to nothing; before a quiet one it
    is the whole TRAIL_DB."""
    from backends.piper import TRAIL_DB, _trail

    loud, edges = _plural(hisses=((0.42, 0.54),), amp=0.9, make=_shh)
    out = _trail(loud, edges, GROUP, PAUSED, SR, {0: 1})
    tip = _rms_db(loud, out, 0.385, 0.405)
    ok(tip > -2.0, "a loud hiss: the voice is not dipped under it", "%+.1f dB" % tip)
    ok(abs(_rms_db(loud, out, 0.43, 0.53)) < 0.5, "and the hiss is the model's own level")
    quiet, edges = _plural(hisses=((0.42, 0.54),), amp=0.03, make=_shh)
    deep = _rms_db(quiet, _trail(quiet, edges, GROUP, PAUSED, SR, {0: 1}), 0.385, 0.405)
    ok(deep < -TRAIL_DB * 0.6, "control: a quiet one, and the voice comes down to it", "%+.1f dB" % deep)


@check
def test_hiss_runs_are_the_plans():
    """Two hisses a closure apart: both kept where the word spells two ("asks,"), only the
    first where it spells one ("last," - what follows is a stop's release, and stays down)."""
    from backends.piper import TRAIL_DB, _trail

    a, edges = _plural(hisses=((0.42, 0.47), (0.54, 0.59)))
    two = _trail(a, edges, GROUP, PAUSED, SR, {0: 2})
    ok(abs(_rms_db(a, two, 0.425, 0.465)) < 0.5, "two runs: the first is kept")
    second = _rms_db(a, two, 0.545, 0.585)
    ok(abs(second) < 0.5, "two runs: and the second, past the closure", "%+.1f dB" % second)
    one = _trail(a, edges, GROUP, PAUSED, SR, {0: 1})
    ok(abs(_rms_db(a, one, 0.425, 0.465)) < 0.5, "one run: the hiss is kept")
    release = _rms_db(a, one, 0.545, 0.585)
    ok(release < -TRAIL_DB + 2.0, "one run: what follows the closure keeps the floor", "%+.1f dB" % release)


@check
def test_a_stray_hiss_is_not_the_words():
    """A hiss that starts long after the voice has ended is out in the rest, not the word's."""
    from backends.piper import TRAIL_DB, _trail

    a, edges = _plural(hisses=((0.70, 0.74),))
    out = _trail(a, edges, GROUP, PAUSED, SR, {0: 1})
    stray = _rms_db(a, out, 0.705, 0.735)
    ok(stray < -TRAIL_DB + 2.0, "it keeps the floor", "%+.1f dB" % stray)
    plain = _trail(a, edges, GROUP, PAUSED, SR)
    ok(abs(_rms_db(plain, out, 0.30, 0.42)) < 0.1, "and the voice ends where it would with no hiss named")


# -- 8. the next word, early ---------------------------------------------------------


@check
def test_an_early_next_word_is_not_dipped():
    """The next word starts 30 ms before the plan says: the floor lets go before its sound."""
    import numpy as np
    from backends import piper as P

    a, edges = _scene()
    early = int(0.87 * SR)
    a[early : int(0.9 * SR)] = _tone(0.3)[: int(0.9 * SR) - early]
    out = P._trail(a, edges, GROUP, PAUSED, SR)
    ok(np.array_equal(out[early:], a[early:]), "its first sound is the same samples")
    ok(_rms_db(a, out, 0.485, 0.495) < -P.TRAIL_DB * 0.5, "and the word before still trails off")
    real = P.TRAIL_EARLY
    P.TRAIL_EARLY = 0.0
    try:
        old = P._trail(a, edges, GROUP, PAUSED, SR)
    finally:
        P.TRAIL_EARLY = real
    dip = _rms_db(a, old, 0.87, 0.88)
    ok(dip < -3.0, "control: trusting the plan dips it", "%+.1f dB" % dip)


@check
def test_the_plan_reaches_the_trail():
    """`_synth_tokens` hands `_trail` the words that end on a hiss, by token."""
    from backends import piper as P

    toks = [
        _tok("cards", ",", ["K", "AA1", "R", "D", "Z"]),
        _tok("card", ",", ["K", "AA1", "R", "D"]),
        _tok("asks", ".", ["AE1", "S", "K", "S"]),
    ]
    seen: list = []
    real = P._trail

    def spy(audio, edges, group, params, sr, hisses=None):
        seen.append(hisses)
        return real(audio, edges, group, params, sr, hisses)

    P._trail = spy
    try:
        _render(toks, PAUSED)
    finally:
        P._trail = real
    eq(seen, [{0: 1, 2: 2}], "'cards' one run, 'card' none, 'asks' two")


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
