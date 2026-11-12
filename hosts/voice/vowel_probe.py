#!/usr/bin/env python3
"""Whether a checkpoint actually says the vowel its phoneme string names.

Some Piper checkpoints (en_US-libritts-high) read a word-initial `ɹˈiːd` with the vowel of `rid` although
eSpeak hands the model `ɹˈiːd`. Measured at speaker 32, one frame, one word swapped, five renders each (F1
discriminates: this reader's /iː/ is at F1 343, its /ɪ/ at 444):

    that can feed them    fˈiːd     F1 283      that can read them   ɹˈiːd  F1 463
    that can seed them    sˈiːd     F1 298      that can reed them   ɹˈiːd  F1 447
    that can breed them   bɹˈiːd    F1 333      that can freed them  fɹˈiːd F1 330

`reed` fails as `read` does and the model never sees spelling, so it is the symbol string, not the word: any
consonant in front of the ɹ, or a changed coda, recovers it. That signals a contaminated training set (every
past-tense "read" labeled `ɹˈiːd` over audio of `ɹˈɛd`), and the checkpoint hedges to a mid vowel.

The repair is phonetically null: English /iː/ in a stressed syllable before a consonant already has an
offglide, so writing it (ɹˈiːd -> ɹˈiːjd: speaker 32 F1 478 -> 298) is a spelling choice that leaves the
poisoned region. On words never broken it is a no-op within measurement noise.

It is asked, not listed, because it is not true of every checkpoint (on the other installed voices `read` is
already right; on en_US-kristin-medium the offglide hurts). As in homographs.py the question goes to the
model and the answer is cached. Three probe words in one frame: an /iː/ the model gets right, an /ɪ/ for the
other end of the scale, and the string under suspicion. If the suspect lands nearer the /ɪ/ the checkpoint
needs the repair; if writing the offglide does not move it back, the repair is declined. Nothing is keyed to
a word: the repair applies to every stressed /iː/ before a consonant.

Costs three short inferences for a healthy voice and four for one that needs the repair, once per voice per
install, cached beside the weights, on the cold path of `_load`. If numpy is missing, the ONNX has no
duration output, or anything else goes wrong, the answer is "no repair".
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

# A stressed /iː/ with an obstruent after it. The stress mark must be in the same word (no space and no
# second mark between), and the lookahead must find something that is not a vowel, a length mark or the
# offglide already; being a lookahead it also fails at the end of a word, which keeps `fɹˈiː` alone.
# Nasals are excluded: the repair was measured only on words ending in an obstruent (feed, seed, beat,
# reach, breed, freed). Firing before a nasal takes in the -ine / -een / -eam family (machine, seen, mean,
# dream), outside the evidence that justified it.
OFFGLIDE = re.compile(r"(ˈ[^ˈˌ ]*?iː)(?=[^aeiouɐəɚɛɪʊʌɔɑːjnmŋˈˌ ])")

# One frame and three words.
# The frame is long because the defect only appears in connected speech (a word said alone is right on every
# voice), so a two-word carrier is a weak instrument. Speaker 0 of the broken checkpoint, 24 renders per
# cell, F1 medians:
#
#     "that can {} them"                     tense 409  lax 523  suspect 609  fixed 522
#     "the house of healing that can {} them" tense 397  lax 535  suspect 625  fixed 432
#
# In the short frame the repaired string lands on the lax reference and the second gate decides an 87 Hz
# difference between measurements that scatter by 40; in the long one the repair carries the vowel back to
# the tense reference (193 Hz).
# The words are onset-matched (ɹ + vowel + stop), so the span the formants are taken from lines up without
# alignment. `reap` is an /iː/ every checkpoint gets right, `rip` the other end of the scale, `reed` the
# string under suspicion (`read`'s string, in a spelling that is no homograph question).
FRAME = "the house of healing that can {} them"
SUSPECT = "reed"
TENSE_REF = "reap"
LAX_REF = "rip"

# How the probe renders. A VITS voice is stochastic (the duration predictor and the flow draw from noise),
# which is wrong for a measurement: at speaking settings the F1 of a 50 ms vowel scattered by 40-50 Hz per
# render with a heavy tail (LPC occasionally picks the wrong pole), and the verdict flipped about one cold
# start in ten; averaging did not fix it.
# So the probe renders with both noise terms at zero and the clock slowed: the vowel gets three times as
# long for LPC to fit and the measurement is exactly repeatable (identical ratios to four decimals), so one
# render per word is the answer. These settings exist inside the probe only.
PROBE_PARAMS = {"noise_scale": 0.0, "noise_w": 0.0, "length_scale": 3.0}

# How far from the /iː/ reference the suspect has to land before the checkpoint is called broken, as a
# multiple of that reader's own /iː/-to-/ɪ/ distance. Measured deterministically on the five installed
# voices:
#
#     en_US-libritts-high   1.46      <- past its own /ɪ/, and the only one that is broken
#     en_US-john-medium     0.51
#     en_US-ljspeech-medium 0.23
#     en_US-kristin-medium  0.10
#     en_US-norman-medium   0.02
#
# 1.0 sits between the two nearest neighbors with about a threefold margin each side: the model renders the
# string further from the vowel it names than its own lax vowel is.
BROKEN_AT = 1.0

# How much worse the repair may make the vowel before it is refused, on the same scale. The test is
# non-regression, not improvement: a repair that does nothing is nothing, so the only outcome worth refusing
# is one that drags the vowel further from where it belongs.
MAX_LOSS = 0.10

# Where in the vowel's own span to measure. Skipping the first third steps past the transition out of the ɹ,
# which would drag F1 the same way for every word.
NUCLEUS = (0.30, 0.90)


def repair(ipa: str) -> str:
    """Write the offglide English already has. A no-op unless the string has a target."""
    return OFFGLIDE.sub(r"\1j", ipa)


def _formants(seg, sr: int) -> list:
    """F1..Fn of one vowel span, by LPC. Empty when the span is too short to fit."""
    import numpy as np

    if len(seg) < 256:
        return []
    order = int(2 + sr / 1000)
    x = np.asarray(seg, dtype=np.float64) * np.hamming(len(seg))
    x = np.append(x[0], x[1:] - 0.97 * x[:-1])  # pre-emphasis
    r = np.correlate(x, x, "full")[len(x) - 1 : len(x) + order]
    if len(r) <= order or r[0] <= 0:
        return []
    a = np.zeros(order + 1)
    a[0] = 1.0
    e = r[0]
    for i in range(1, order + 1):
        k = -(a[:i] @ r[i:0:-1]) / e
        a[1 : i + 1] = a[1 : i + 1] + k * a[i - 1 :: -1][:i]
        e *= 1 - k * k
        if e <= 0:
            return []
    out = []
    for z in np.roots(a):
        if np.imag(z) <= 0:
            continue
        f = np.arctan2(np.imag(z), np.real(z)) * sr / (2 * np.pi)
        bw = -0.5 * (sr / (2 * np.pi)) * np.log(abs(z))
        # A formant is a narrow peak. Wide poles are the glottal source and the
        # spectral tilt, and they sit wherever they like.
        if 90 < f < sr / 2 - 200 and bw < 400:
            out.append(f)
    return sorted(out)


class VowelProbe:
    """One per backend instance; the verdict is per voice and survives the process.

    `speak(words, lang)` is the backend's own word-level phonemizer and `render(symbols,
    params)` its symbols-to-audio step - the same two calls the real path makes, so a
    probe render and a reading render cannot drift apart.
    """

    def __init__(self, speak, render, cache_dir) -> None:
        self._speak = speak
        self._render = render
        self._dir = Path(cache_dir)
        self._verdict: dict[str, bool] = {}

    # -- public ------------------------------------------------------------

    def repair_for(self, voice: str, ipa: str) -> str:
        """`ipa`, with the offglide written if THIS voice was measured to need it."""
        return repair(ipa) if self._verdict.get(voice) else ipa

    def measure(self, voice: str, cfg: dict, sess, lang: str = "en-us") -> bool:
        """Decide once whether `voice` renders a bare stressed /iː/ as the wrong vowel."""
        if voice in self._verdict:
            return self._verdict[voice]
        cached = self._load(voice)
        if cached is None:
            try:
                cached = self._run(voice, cfg, sess, lang)
            except Exception as exc:  # noqa: BLE001 - a probe fault must not lose audio
                print(f"ghost/voice: vowel probe failed ({exc})", file=sys.stderr)
                cached = False
            self._save(voice, cached)
        self._verdict[voice] = cached
        return cached

    # -- internals ---------------------------------------------------------

    def _path(self, voice: str) -> Path:
        return self._dir / f"{voice}.probe.json"

    def _load(self, voice: str):
        try:
            got = json.loads(self._path(voice).read_text(encoding="utf-8"))
        except Exception:  # noqa: BLE001 - absent, unreadable or half-written
            return None
        return (
            bool(got["offglide"])
            if isinstance(got, dict) and "offglide" in got
            else None
        )

    def _save(self, voice: str, offglide: bool) -> None:
        try:
            self._dir.mkdir(parents=True, exist_ok=True)
            tmp = self._path(voice).with_suffix(".json.part")
            tmp.write_text(json.dumps({"offglide": offglide, "probe": SUSPECT}))
            tmp.replace(self._path(voice))  # atomic: a reader sees whole file or none
        except Exception:  # noqa: BLE001 - a read-only voices dir just re-probes
            pass

    def _f1(self, voice: str, cfg: dict, sess, lang: str, word_ipa: str) -> float:
        """F1 of the vowel in `word_ipa`, said inside the frame. One render, exactly."""
        import numpy as np

        sr = int(cfg["audio"]["sample_rate"])
        before, after = FRAME.split("{}")
        heads = [w for w in before.split() if w]
        tails = [w for w in after.split() if w]
        spoken = self._speak(heads + tails, lang)
        if len(spoken) != len(heads) + len(tails):
            raise RuntimeError("frame phonemization came back the wrong length")
        words = spoken[: len(heads)] + [word_ipa] + spoken[len(heads) :]

        # Every character its own source index: the render step keys its spans by whatever it is handed, so
        # numbering the characters turns a per-token span into a per-symbol one (a vowel is a symbol, not a
        # word).
        symbols: list = []
        for wi, w in enumerate(words):
            if wi:
                symbols.append((" ", len(symbols)))
            for ch in w:
                symbols.append((ch, len(symbols)))
        # The vowel of the probe word: its `i`/`ɪ` and any length mark after it.
        at = sum(len(w) for w in words[: len(heads)]) + len(heads)
        want = [
            k
            for k in range(at, at + len(word_ipa))
            if symbols[k][0] in "iɪ"
            or (symbols[k][0] == "ː" and symbols[k - 1][0] in "iɪ")
        ]
        if not want:
            raise RuntimeError(f"no vowel to measure in {word_ipa!r}")

        audio, spans = self._render(symbols, cfg, sess, dict(PROBE_PARAMS))
        got = [spans[k] for k in want if k in spans]
        if not got:
            raise RuntimeError("this voice reports no phoneme timings")
        t0 = min(s[0] for s in got)
        t1 = max(s[1] for s in got)
        lo = int((t0 + (t1 - t0) * NUCLEUS[0]) * sr)
        hi = int((t0 + (t1 - t0) * NUCLEUS[1]) * sr)
        f = _formants(np.asarray(audio)[lo:hi], sr)
        if not f:
            raise RuntimeError("no measurable vowel in the probe render")
        return float(f[0])

    def _run(self, voice: str, cfg: dict, sess, lang: str) -> bool:
        spoken = self._speak([SUSPECT, TENSE_REF, LAX_REF], lang)
        if len(spoken) != 3:
            raise RuntimeError("probe phonemization came back the wrong length")
        suspect, tense, lax = spoken
        fixed = repair(suspect)
        if fixed == suspect:
            # Nothing to write - this language or voice does not spell the vowel the
            # way the repair looks for, so there is no repair to offer.
            return False

        f_tense = self._f1(voice, cfg, sess, lang, tense)
        f_lax = self._f1(voice, cfg, sess, lang, lax)
        f_suspect = self._f1(voice, cfg, sess, lang, suspect)
        # A reader whose two reference vowels come back on top of each other tells us the measurement is not
        # working on this voice, not that it is healthy. It is also the denominator of everything below.
        scale = abs(f_lax - f_tense)
        if scale < 60.0:
            print(
                "ghost/voice: %s does not separate /iː/ from /ɪ/ in the probe "
                "(F1 %.0f vs %.0f); leaving its readings alone"
                % (voice, f_tense, f_lax),
                file=sys.stderr,
            )
            return False
        if abs(f_suspect - f_tense) <= BROKEN_AT * scale:
            return False  # says the vowel it names

        f_fixed = self._f1(voice, cfg, sess, lang, fixed)
        loss = abs(f_fixed - f_tense) - abs(f_suspect - f_tense)
        better = loss < MAX_LOSS * scale
        print(
            "ghost/voice: %s renders %s at F1 %.0f, %.2f of its own /iː/-to-/ɪ/ "
            "distance away from the /iː/ it names (%.0f, with /ɪ/ at %.0f); %s"
            % (
                voice,
                suspect,
                f_suspect,
                abs(f_suspect - f_tense) / scale,
                f_tense,
                f_lax,
                (
                    "writing the offglide (F1 %.0f)" % f_fixed
                    if better
                    else "the offglide makes it worse (F1 %.0f), leaving it" % f_fixed
                ),
            ),
            file=sys.stderr,
        )
        return better
