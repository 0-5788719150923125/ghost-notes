#!/usr/bin/env python3
"""Tests for a script's delivery in the voice host's pipeline (next/delivery.md): what each word's `x` and acts do to the
take once the model has made it - its volume and tremor (`_emphasize`), its effort (`_effort`), its whisper (`_whisper`), a
word cut off (`_cut_off`), the rest after it (`_pauses_of`), and the curve each is laid on (`_word_curve`).

Run it directly with the voice venv's python (no pytest):

    ~/.local/share/godot/app_userdata/ghost/voice_venv/bin/python hosts/voice/test_delivery.py

Every check has its control: a take whose words say nothing comes back as it went in.
"""

from __future__ import annotations

import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

SR = 22050
FAILS: list = []


def check(cond, what: str) -> None:
    print(("    ok  " if cond else "    FAIL ") + what)
    if not cond:
        FAILS.append(what)


def _take():
    """Three words of a steady tone with silence between: (audio, edges, group) - edges {token: (first, last) seconds}."""
    import numpy as np

    t = np.arange(int(1.6 * SR)) / SR
    tone = 0.3 * np.sin(2.0 * np.pi * 220.0 * t)
    gate = ((t > 0.1) & (t < 0.5)) | ((t > 0.6) & (t < 1.0)) | ((t > 1.1) & (t < 1.5))
    audio = (tone * gate).astype(np.float32)
    edges = {0: (0.1, 0.5), 1: (0.6, 1.0), 2: (1.1, 1.5)}
    group = [{"text": "one"}, {"text": "two"}, {"text": "three"}]
    return audio, edges, group


def _rms(a, t0: float, t1: float) -> float:
    import numpy as np

    seg = a[int(t0 * SR):int(t1 * SR)].astype(np.float64)
    return float(np.sqrt(np.mean(seg * seg)))


def curve() -> None:
    import numpy as np
    from backends.piper import _word_curve

    audio, edges, group = _take()
    check(_word_curve(edges, group, "volume", audio.size, SR) is None, "a take whose words say nothing has no curve (control)")
    group[1]["x"] = {"volume": 6.0}
    c = _word_curve(edges, group, "volume", audio.size, SR)
    check(c is not None and abs(c[int(0.8 * SR)] - 6.0) < 1e-6 and abs(c[int(0.3 * SR)]) < 1e-6
          and abs(c[int(1.3 * SR)]) < 1e-6, "a word's value is held over its own sounds and nowhere else's")
    check(0.0 < c[int(0.55 * SR)] < 6.0, "...and eased straight across the gap before it")
    check(np.allclose(_word_curve(edges, group, "volume", audio.size, SR, 2.0), 2.0 * c), "a scale scales it")


def volume() -> None:
    from backends.piper import EMPHASIS_CEILING, _emphasize

    audio, edges, group = _take()
    same = _emphasize(audio, edges, group, SR)
    check(same is audio, "a take whose words say nothing is left alone (control)")
    group[1]["x"] = {"volume": 6.0}
    group[2]["x"] = {"volume": -6.0}
    out = _emphasize(audio, edges, group, SR)
    check(abs(_rms(out, 0.2, 0.4) - _rms(audio, 0.2, 0.4)) < 1e-4, "a word with no volume keeps its level")
    up = _rms(out, 0.7, 0.9) / _rms(audio, 0.7, 0.9)
    down = _rms(out, 1.2, 1.4) / _rms(audio, 1.2, 1.4)
    check(1.9 < up < 2.1 and 0.48 < down < 0.52, "a word's volume is its dB (%.2f, %.2f)" % (up, down))
    loud, edges2, group2 = _take()
    loud = loud * 3.0
    group2[1]["x"] = {"volume": 8.0}
    check(float(abs(_emphasize(loud, edges2, group2, SR)).max()) <= EMPHASIS_CEILING + 1e-3, "a louder word never clips")


def tremor() -> None:
    import numpy as np
    from backends.piper import _emphasize

    audio, edges, group = _take()
    group[1]["x"] = {"tremor": 1.0}
    out = _emphasize(audio, edges, group, SR)
    hop = int(0.02 * SR)
    env = [_rms(out, 0.62 + k * 0.02, 0.62 + (k + 1) * 0.02) for k in range(17)]
    env0 = [_rms(audio, 0.62 + k * 0.02, 0.62 + (k + 1) * 0.02) for k in range(17)]
    check(np.ptp(20 * np.log10(env)) > 2.0 and np.ptp(20 * np.log10(env0)) < 0.5 and hop > 0,
          "a tremor shakes the word's level (%.2f dB)" % float(np.ptp(20 * np.log10(env))))


def effort() -> None:
    import numpy as np
    from backends.piper import _effort, _word_curve

    audio, edges, group = _take()
    noise = np.random.default_rng(3).standard_normal(audio.size).astype(np.float32) * 0.05
    mixed = (audio + noise * (np.abs(audio) > 0)).astype(np.float32)
    check(_effort(mixed, SR, 0.0, 0.0, None) is mixed, "no effort and no curve leaves the take alone (control)")
    group[1]["x"] = {"effort": 1.0}
    out = _effort(mixed, SR, 0.0, 0.0, _word_curve(edges, group, "effort", mixed.size, SR, 0.45))

    def hi_share(a, t0, t1):
        seg = a[int(t0 * SR):int(t1 * SR)].astype(np.float64)
        spec = np.abs(np.fft.rfft(seg)) ** 2
        f = np.fft.rfftfreq(seg.size, 1.0 / SR)
        return float(spec[f > 2000.0].sum() / spec.sum())

    check(hi_share(out, 0.65, 0.95) > 1.5 * hi_share(mixed, 0.65, 0.95)
          and abs(hi_share(out, 0.15, 0.45) - hi_share(mixed, 0.15, 0.45)) < 0.25 * hi_share(mixed, 0.15, 0.45) + 1e-3,
          "a word's effort tilts it brighter, the others barely")


def whisper() -> None:
    import numpy as np
    from backends.piper import _whisper, _word_curve

    audio, edges, group = _take()
    check(_whisper(audio, SR, 0.0, None) is audio, "no whisper leaves the take alone (control)")
    group[2]["x"] = {"whisper": 1.0}
    out = _whisper(audio, SR, 0.0, _word_curve(edges, group, "whisper", audio.size, SR))

    def tonal(a, t0, t1):
        seg = a[int(t0 * SR):int(t1 * SR)].astype(np.float64)
        spec = np.abs(np.fft.rfft(seg)) ** 2
        f = np.fft.rfftfreq(seg.size, 1.0 / SR)
        return float(spec[(f > 200) & (f < 240)].sum() / spec.sum())

    check(tonal(out, 1.2, 1.4) < 0.5 * tonal(audio, 1.2, 1.4) and tonal(out, 0.2, 0.4) > 0.8 * tonal(audio, 0.2, 0.4),
          "a whispered word loses its voicing, the others keep theirs")


def cut() -> None:
    from backends.piper import _cut_off

    audio, edges, group = _take()
    said = [{"p": "t", "t0": 0.6, "t1": 0.7, "w": 1}, {"p": "u", "t0": 0.7, "t1": 0.8, "w": 1}, {"p": "z", "t0": 0.8, "t1": 1.0, "w": 1}]
    check(_cut_off(audio, said, group, SR) is audio, "a take with no word cut off is left alone (control)")
    group[1]["acts"] = [["cut off", 1.0]]
    out = _cut_off(audio, said, group, SR)
    check(_rms(out, 0.81, 0.99) == 0.0 and _rms(out, 0.71, 0.78) > 0.1 and _rms(out, 0.2, 0.4) > 0.1,
          "a word cut off goes silent from its first vowel's end, and nothing else does")


def pauses() -> None:
    from backends.piper import _pauses_of

    from backends.piper import _rest_seconds

    check(_pauses_of({"text": "a"}) == 1.0 and _pauses_of({"x": {"pauses": 0.5}}) == 0.5,
          "a word's rest is as long as its delivery says, its own where it says none")
    check(abs(_pauses_of({"x": {"pauses": 0.5, "commas": 2.0}}) - 1.0) < 1e-9 and _pauses_of({"x": {"ends": 3.0}}) == 1.0,
          "a comma's rest follows `pauses` times `commas`, never a sentence's own axis (control)")
    check(_rest_seconds({"x": {"commas_s": 0.4}}, "commas") == 0.4 and _rest_seconds({"x": {"commas": 2.0}}, "commas") is None,
          "a comma's rest in seconds is read, and none where the delivery gives none (control)")


def contours() -> None:
    import inflection

    q = inflection.RULES["question"]["fields"]
    marks, _ = inflection.delivered([{"text": "so", "acts": [["rise-fall", 1.0]]}], q)
    check(marks[0].shapes() == [inflection._contour("rise-fall", 1.0, q).pitch], "an act with no contour of its own draws its own row's (control)")
    own = [["stress<", 0.0], [1.0, 5.0]]
    marks, _ = inflection.delivered([{"text": "so", "acts": [["rise-fall", 2.0, own]]}], q)
    check(marks[0].shapes() == [[("stress<", 0.0), (1.0, 10.0)]], "an act's own contour is drawn in place of the row's, times its degree")
    marks, _ = inflection.delivered([{"text": "so", "acts": [["drawn", 4.0, [[0.0, 0.0], [0.5, 2.0]]]]}], q)
    check(marks[0].shapes() == [[(0.0, 0.0), (0.5, 4.0)]] and marks[0].drawn > 1.0,
          "a drawn word's own hill is drawn, times the square root of its degree, and the word still held")


def bank_contours() -> None:
    """The contours delivery_bank.gd shows in a Lab are the ones the host draws."""
    import json
    import re
    import inflection

    src = (HERE.parent.parent / "src" / "voice" / "delivery_bank.gd").read_text()
    q = inflection.RULES["question"]["fields"]
    found = 0
    for m in re.finditer(r'^\t"([a-z -]+)": \{"label".*"contour": (\[.*?\]\])\}', src, re.M):
        name, shown = m.group(1), [tuple(p) for p in json.loads(m.group(2))]
        found += 1
        if name == "drawn":
            h = inflection.DRAWN_HILL
            drawn = [("stress<", 0.0), (inflection.DRAWN_PEAK, h), (1.0, -h)]
            check(shown == drawn, "drawn's hill as the Lab shows it is the host's (%s, %s)" % (shown, drawn))
            continue
        if name == "spaced":
            check(shown == [("stress<", 0.0), ("stress", 2.0), (1.0, -1.0)], "spaced's contour as the Lab shows it is the host's")
            continue
        c = inflection._contour(name, 1.0, q)
        check(c is not None and [tuple(p) for p in c.pitch] == shown, "%s's contour as the Lab shows it is the host's (%s, %s)"
              % (name, shown, c.pitch if c else None))
    check(found >= 12, "every act's contour is read from the bank (%d)" % found)


def measured() -> None:
    import numpy as np
    import measure

    t = np.arange(int(1.0 * SR)) / SR
    tone = 0.3 * np.sin(2.0 * np.pi * 200.0 * t)
    m = measure.of_samples(tone, SR)
    check(m["pitch"] is not None and abs(m["pitch"] - 12.0) < 0.2 and m["voiced"] > 0.9,
          "a 200 Hz tone measures 12 semitones over 100 Hz, voiced throughout (%s)" % m["pitch"])
    noise = np.random.default_rng(1).standard_normal(SR) * 0.1
    check(measure.of_samples(noise, SR)["voiced"] < 0.1, "noise is not voiced (control)")
    up = measure.of_samples(0.3 * np.sin(2.0 * np.pi * np.cumsum(np.linspace(150.0, 300.0, SR)) / SR), SR)
    tenths = [p for p in up["pitch_tenths"] if p is not None]
    check(len(tenths) >= 8 and tenths[-1] - tenths[0] > 9.0, "a glide up measures rising across its tenths (%s)" % tenths)


if __name__ == "__main__":
    for fn in (curve, volume, tremor, effort, whisper, cut, pauses, contours, bank_contours, measured):
        print(fn.__name__)
        fn()
    print(f"\n{len(FAILS)} failed" if FAILS else "\nall passed")
    raise SystemExit(1 if FAILS else 0)
