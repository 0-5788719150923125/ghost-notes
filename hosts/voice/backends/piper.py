"""Piper voices, run as raw ONNX through onnxruntime. No GPL code is imported, linked or shipped.

`pip install piper-tts` would pull in GPL-3.0 eSpeak-NG, so none of it is used: a Piper voice is an
`.onnx` graph plus an `.onnx.json` config (with a `phoneme_id_map`) distributed as data, ghost's own
G2P maps phonemes to ids, and onnxruntime (MIT) runs the graph.

Voice checkpoints are licensed individually and the license is transitive through fine-tuning.
`lessac` (Blizzard 2013) restricts use to research, and voices fine-tuned from it inherit that: amy,
joe, hfc_female, hfc_male, libritts_r. ryan and the hfc pair are CC BY-NC-SA; kathleen is CC0 data
fine-tuned from ryan. VOICES is therefore an allowlist, not a catalog: each entry records its dataset
and derivation chain, and adding one means reading its MODEL_CARD.
"""

from __future__ import annotations

import functools
import json
import math
import os
import sys
import urllib.request
from pathlib import Path
from typing import Any

from . import Backend, BackendError, register, report


def _reporter(name: str):
    """A urlretrieve hook that reports progress a few times a second, not per block."""
    last = [0.0]

    def hook(blocks: int, block_size: int, total: int) -> None:
        import time

        now = time.monotonic()
        if now - last[0] < 0.25:
            return
        last[0] = now
        report(name, min(blocks * block_size, max(total, 0)), max(total, 0))

    return hook


HF_BASE = "https://huggingface.co/rhasspy/piper-voices/resolve/main"

# VITS hop length: one duration-predictor frame is this many samples.
HOP_LENGTH = 256

# Sentence-final marks. ghost's front end already emits these as phones, so the
# split costs nothing and needs no text.
SENTENCE_END = {".", "!", "?"}

# Extra seconds of silence after a mark at `pause_scale` = 1.0, on top of the model's own rest (the
# model sees the mark, so its intonation is untouched).
# The model already rests about 0.15 s at a comma, 0.19 at ";" and 0.30 at ":" (en_US-ljspeech-medium),
# so the entries stay small: 0.26 s on a colon would out-rest a full stop and invert: > ; > ,.
# The sentence-final marks are 0.32, the `sentence_gap` default: the table subsumes that parameter (a
# caller's `sentence_gap` still wins for. ! ?). More pause comes from the Pause slider (see
# generative_editor.MAX_PAUSE_SCALE).
PAUSE_AFTER: dict[str, float] = {
    ",": 0.10,
    ";": 0.13,
    ":": 0.16,
    # Sentence-final marks are the sentence gap, never added to it (see _gap_for).
    ".": 0.32,
    "!": 0.32,
    "?": 0.32,
}

# What the model already rests at each mark, in seconds, measured with its noise off: the token-span
# increments for, ; :, and for a sentence end its trailing silence (0.14) plus the next sentence's
# leading silence (0.044).
# The dial scales the model's rest plus ours, so both are needed. These figures are an estimate (en_US-john-medium
# rests 0.41 s at a comma where this says 0.15), so `_splice_pauses` measures the real rest in the
# waveform and this table is used only where there is none: the seam between separately rendered
# sentences, and the accounting.
DWELL: dict[str, float] = {
    ",": 0.15,
    ";": 0.19,
    ":": 0.30,
    ".": 0.18,
    "!": 0.18,
    "?": 0.18,
}

# The pause curve: the dial multiplies the whole rest (the model's plus ours), so every mark keeps its
# share at every setting.
# A power law `d ** PAUSE_GAIN`: exactly 1.0 at 1.0 with no normalizing constant, and it keeps
# climbing (5.0x at the top of the dial, exponent log(5)/log(10)) where a saturating exponential
# plateaus. Concave: each unit of dial adds less than the last.
PAUSE_GAIN = 0.69897


def _pause_multiplier(params: dict) -> float:
    """How much longer than natural every rest in this reading is. 1.0 at Pause 1.0."""
    return _pause_scale(params) ** PAUSE_GAIN


def _rest_from(
    dwell: float, top_up: float, mult: float, have: float | None = None
) -> float:
    """Seconds of silence to add at a mark, given `have` seconds already there.

    The target is `(dwell + top_up) * mult`: the rest a reader should hear, taken from the table so it is
    the same at every comma and keeps its ratio to a full stop at every dial setting. `have` is measured
    off the waveform by `_splice_pauses` and subtracted, since silence can only be added. The target must
    not be built from `have`: a dwell is a draw from the stochastic duration predictor (0.0 to 0.4 s for
    the same mark and voice), and multiplying it scales that scatter.

    `have` defaults to `dwell` for callers with no waveform (the sentence seam and the accounting).

    Floored at zero: below about 0.6 on the dial the model already rests longer than asked, and
    shortening would mean re-synthesizing.
    """
    # At 1.0 with nothing to measure the answer is the top-up, returned exactly (`(0.18 + 0.5) * 1.0 - 0.18`
    # is 0.49999999999999994) so the seam is reproducible to the sample. Not taken where `have` was
    # measured: there `(dwell + top_up) * 1.0 - have` differs from `top_up`, and returning `top_up`
    # would put a step in the dial at its default.
    if mult == 1.0 and (have is None or have == dwell):
        return max(0.0, top_up)
    return max(0.0, (dwell + top_up) * mult - (dwell if have is None else have))


def _top_up(mark: str, params: dict, base: float | None = None) -> float:
    """Our own share of the rest at Pause 1.0: the table, or the caller's sentence_gap."""
    return PAUSE_AFTER.get(str(mark), 0.0) if base is None else base


def _rest_for(mark: str, params: dict, base: float | None = None) -> float:
    """`_rest_from` with the dwell taken from DWELL, for callers with no waveform: the sentence seam and the accounting."""
    m = str(mark)
    return _rest_from(
        _dwell_for(m, base), _top_up(m, params, base), _pause_multiplier(params)
    )


def _dwell_for(mark: str, base: float | None = None) -> float:
    """The mark's natural rest at Pause 1.0. `base` is the caller's `sentence_gap` overriding the top-up;
    a top-up for a mark the table lacks takes a full stop's dwell (only the sentence seam does this)."""
    m = str(mark)
    if m in DWELL:
        return DWELL[m]
    return DWELL["."] if base is not None else 0.0


def _rest_floor(mark: str, params: dict, share: float = 1.0) -> float:
    """Seconds of rest the model renders at a mid-sentence mark, before any splice; `share` is the part
    of its rest the mark gets (`_tail_share`).

    en_US-libritts-high runs on through a comma instead of ending the word, so spliced silence would cut
    it off. Given frames on the word-space after the mark (`_render_symbols`, via the input
    `_ensure_patched` adds), the model renders a real rest with its own release and onset, and
    `_splice_pauses` takes that silence to the target. The mark's natural dwell suffices for the
    release; a target shorter than the dwell is rendered whole.
    """
    m = str(mark)
    if m in SENTENCE_END or PAUSE_AFTER.get(m, 0.0) <= 0.0:
        return 0.0
    dwell = _dwell_for(m)
    return max(
        0.0,
        min(dwell, (dwell + _top_up(m, params)) * _pause_multiplier(params) * share),
    )


# A comma that leaves its sentence SHORT_TAIL words or fewer ("..., too.") rests SHORT_TAIL_REST of a
# comma's whole rest (dial still applied): a short tail is an afterthought, and pauses shrink with the
# phrase beside them (Zvonik & Cummins 2003, Krivokapic 2007). The word before trails off by what that
# rest earns (`_trail_weight`). A colon or semicolon keeps its rest, as does a comma whose tail ends at
# another mark (an aside) or whose own run is as short and follows one (a list's last item).
SHORT_TAIL = 2
SHORT_TAIL_REST = 0.35


def _tail_share(group: list, ti: int) -> float:
    """The share of its mark's rest `group[ti]` gets: SHORT_TAIL_REST after a comma whose sentence ends
    SHORT_TAIL words or fewer later, 1 otherwise. `group` is one sentence's tokens."""
    if str(group[ti].get("punct", "")) != ",":
        return 1.0
    head = 1
    for t in reversed(group[:ti]):
        if str(t.get("punct", "")):
            if head <= SHORT_TAIL:
                return 1.0
            break
        head += 1 if str(t.get("text", "")).strip() else 0
    words = 0
    for t in group[ti + 1:]:
        if str(t.get("text", "")).strip():
            words += 1
        m = str(t.get("punct", ""))
        if m:
            return SHORT_TAIL_REST if m in SENTENCE_END and 0 < words <= SHORT_TAIL else 1.0
        if words > SHORT_TAIL or _rest_after(t) > 0.0:
            return 1.0
    # a group that ends without a sentence's end is a passage cut short, its sentence going on
    return 1.0


# A rest the caller splices in (a token's `rest_after`, seconds: a hesitation, an action; ghost's
# `Splice.chunk`). The word before it is treated as the word before a mark, so the model does not read
# on into the next word: read at a phrase end (`_in_sentence`), held and trailed off by the weight its
# rest earns (`_trail_weight`), and floored by REST_AFTER_FLOOR, the comma's dwell (`_rest_floor`).
# Where no mark rests there, that rest is the caller's begun, never added to it: the token's row says
# how much the model rendered (`rested`).
REST_AFTER_FLOOR = DWELL[","]


def _rest_after(tok: dict) -> float:
    """Seconds of rest the caller splices in after `tok` (`rest_after`), 0 for none."""
    try:
        return max(0.0, float(tok.get("rest_after", 0.0) or 0.0))
    except (TypeError, ValueError):
        return 0.0


def _floor_of(tok: dict, params: dict, share: float = 1.0) -> float:
    """The rest floor on the word-space after `tok`: its mark's (`_rest_floor`, `share` of its rest -
    `_tail_share`), raised to REST_AFTER_FLOOR - never past the rest itself - where the caller splices
    a rest in after it. None after a sentence end, whose rest is the gap between groups."""
    m = str(tok.get("punct", ""))
    floor = _rest_floor(m, params, share)
    after = _rest_after(tok)
    if after > 0.0 and m not in SENTENCE_END:
        floor = max(floor, min(REST_AFTER_FLOOR, after))
    return floor


# The graph input `_ensure_patched` adds: per-id frames the duration plan may not fall below.
REST_FLOOR_INPUT = "rest_floor"
# ...and the other one: a per-id multiplier on the planned frames, after the Ceil and before
# the floor. How a word is leaned on (`EMPHASIS`).
DUR_SCALE_INPUT = "dur_scale"

# A word leaned on, by the level the script marks it with (`*italic*` 1, `**bold**` 2, both 3): its
# stressed vowel held longer through the duration plan and the word a little louder. Pitch, the third
# cue of stress, has no input in a VITS graph.
# Measured (en_US-libritts-high, 14 renders a level) against the unmarked word: italic 16-20% longer and
# 5-6 dB up, bold 29-38% longer and 7-9 dB up. The word grows less than its multiplier because only the
# stressed vowel is held. Most of bold's step over italic is length: the gain never clips the word
# (`EMPHASIS_CEILING`), and bold reaches that ceiling.
EMPHASIS: dict[int, tuple[float, float]] = {
    # level: (vowel duration multiplier, gain on the word in dB)
    1: (1.50, 2.5),
    2: (1.90, 5.0),
    3: (1.90, 5.0),
}
# The loudest a lifted word may peak, of full scale: its lift is cut back to stay under it.
EMPHASIS_CEILING = 0.97
# How quickly the emphasis gain comes and goes at the word's edges.
EMPHASIS_RAMP = 0.030

# The opening word's vowel: the least it may be rendered, in seconds at the request's own length scale.
# en_US-libritts-high clips a sentence's first word even with LEAD_IN_SPACES ("A" 12 ms, "If"/"It"/"The"
# 46 ms, about twice that mid-sentence; rhasspy/piper#296). A floor, not a stretch, so a word the model
# already lengthened is untouched.
OPENING_VOWEL = 0.05

# The word before a rest trails off. The model ends every word at full level and drops it (the steepest
# 20 ms is about 15 dB before a comma), which with a long rest and level pitch reads as the word cut off.
# Three small moves, scaled together by `_trail_weight`:
#   the hold, through the duration plan: the word's final rime renders `1 + TRAIL_STRETCH` times longer;
#   the fade, on the waveform: for TRAIL_TIP seconds up to the voice's end the level eases down
#   (quadratic in dB) to TRAIL_DB below and stays there through the rest until the next word is about
#   to start, which takes word-final releases down with it;
#   the sag, on the waveform: the last TRAIL_SAG_SPAN seconds are read slower, easing to TRAIL_SAG
#   semitones lower, length kept (`_glide`).
# Full sentence ends are left to the model's finality and `_discourse_plan`.
TRAIL_STRETCH = 0.25
TRAIL_TIP = 0.12
TRAIL_DB = 16.0
TRAIL_SAG = 1.5
TRAIL_SAG_SPAN = 0.09
# A rest this long is a strong enough boundary for the whole trail; a shorter one gets a share of
# it. Boundary strength is what pre-boundary lengthening follows, and the rest is the strength.
TRAIL_REST_FULL = 0.5
# A colon is not faded: it announces what follows and the voice holds up into it, and the fade took the
# end of the short word before it (heard by Whisper with Kokoro's Puck: the word before a colon came
# through in 8 of 10 with the trail, 10 of 10 without its fade; commas 6 of 6 either way). How much of
# the fade the word before a mark takes, where not all of it:
TRAIL_FADE = {":": 0.0}
# How far under the final rime's own peak the voice still counts as sounding (`_trail` looks for
# its end in the waveform: the model keeps voicing through the mark, so the plan's last sound is
# 50 ms early to 80 ms late), how long the level takes to come back before the next word, and how
# far past the voice's end the sag keeps reading slow (inside the rest, where the join is silent).
TRAIL_VOICED_DB = 12.0
TRAIL_BACK = 0.03
TRAIL_SAG_TAIL = 0.03
# The sag's join back to the unmoved audio.
TRAIL_JOIN = 0.002

# A word's own hiss is not faded: the fade is the voice falling away, but a word ending on frication
# ("cards,", "house,") ends on a small sound (a final /z/ is 25-35 dB under the take's peak and 30-60 ms
# long), and a fade floor held through it made plurals sound like singulars.
# The plan says which words, the waveform says where: a word whose last sounds hold one of `_HISSES` is
# searched for a hiss after its rime's loudest point (`_hiss_tail`), for as many runs as those sounds
# spell (`_hiss_codas`: one in "cards", two in "asks", parted by a stop's closure of up to
# TRAIL_HISS_GAP; a run survives a dropout of TRAIL_HISS_DROP). The voice then ends TRAIL_HISS_IN before
# the hiss, where the fade comes back up to nothing, and goes down again over TRAIL_HISS_OUT after it.
# The plan's own word end cannot place it: such a hiss runs 40-170 ms past it.
# A word's hiss is searched for lower than a lead's, above TRAIL_HISS_ABOVE: /ʃ/ has 94-100% of its
# energy above 2 kHz but only 5-40% above 4, so 4 kHz finds an /s/ and a sliver of a /ʃ/.
# The voice falls no further than its hiss: the fade's depth is the vowel's level over the hiss's, no
# more than TRAIL_DB, so it never dips the vowel under the sound it runs into.
_HISSES = frozenset("szʃʒfθ")
TRAIL_HISS_ABOVE = 2000.0
TRAIL_HISS_GAP = 0.12
TRAIL_HISS_DROP = 0.015
TRAIL_HISS_IN = 0.012
TRAIL_HISS_OUT = 0.03
# The next word can start 10-30 ms before the plan says, so the far side of a rest is walked back from
# the plan's figure while the audio is louder than TRAIL_SOUNDING of the take's peak, no further than
# TRAIL_EARLY.
TRAIL_SOUNDING = 0.01
TRAIL_EARLY = 0.06

# The next word's hiss leaks into a rest: the model starts a fricative early (an /s/ 40-75 ms before
# its word) and the lengthened word-space takes it along, so before an /s/ the lead fills 165-195 ms of
# a 210-290 ms rest and the splice cuts through it. `_quiet_lead` keeps LEAD_KEEP seconds of it before
# the next word, coming in over LEAD_RAMP, and silences what is earlier. A frame is hiss when more than
# LEAD_HF of its energy is above LEAD_ABOVE and it is louder than LEAD_FLOOR (of the take's peak).
LEAD_KEEP = 0.08
LEAD_RAMP = 0.03
LEAD_HF = 0.5
LEAD_ABOVE = 4000.0
LEAD_FLOOR = 0.005
LEAD_FRAME = 0.005

# The vowels of eSpeak's IPA (and of `arpabet.to_symbols`), and the marks that belong to one.
_VOWELS = frozenset("aeiouyæɑɐɒɔəɚɛɜɝɪʊʌʏɘɵɨʉøœɤɯᵻ")
_VOWEL_MARKS = frozenset("ː")
_STRESS = "ˈ"
# Not a sound of its own, in the phones handed back: the stress marks; and the length mark, which is
# the vowel's before it.
_UNSAID = frozenset({"ˈ", "ˌ", " "})
_LENGTHENS = frozenset({"ː", "ˑ"})


def _trail_weight(mark: str, params: dict, after: float = 0.0, share: float = 1.0) -> float:
    """How much of the trail the word before `mark` gets: None at a sentence end, 0 where nothing rests
    (a mark with no rest, or any mark at Pause 0) unless the caller splices `after` seconds in
    (`REST_AFTER_FLOOR`). Otherwise the share of TRAIL_REST_FULL the word's rest reaches (the mark's
    `share`, `_tail_share`) times the request's `trail` (1 default, 0 off, 2 double)."""
    m = str(mark)
    if m in SENTENCE_END:
        return 0.0
    rest = max(0.0, float(after))
    if PAUSE_AFTER.get(m, 0.0) > 0.0:
        rest += (_dwell_for(m) + _top_up(m, params)) * _pause_multiplier(params) * share
    if rest <= 0.0:
        return 0.0
    try:
        k = min(max(float(params.get("trail", 1.0)), 0.0), 2.0)
    except (TypeError, ValueError):
        k = 1.0
    return k * min(1.0, rest / TRAIL_REST_FULL)


def _nuclei(symbols: list) -> set:
    """Positions in `symbols` that are each source's nucleus: the run of vowels (and length marks) after
    its primary stress, or its first vowel run if none. A diphthong is one run.

    The stress mark directly before the run belongs to it: Piper spreads a syllable's time over the mark,
    vowel and blanks between, and the vowel's id is often a single frame, so a stretch that misses them
    moves almost nothing."""
    by_src: dict = {}
    for j, (sym, src) in enumerate(symbols):
        if src >= 0:
            by_src.setdefault(src, []).append((j, sym))
    out: set = set()
    for items in by_src.values():
        start = 0
        for k, (j, sym) in enumerate(items):
            if sym == _STRESS:
                start = k + 1
                break
        run: list = []
        for j, sym in items[start:]:
            if sym in _VOWELS or (run and sym in _VOWEL_MARKS):
                run.append(j)
            elif run:
                break
        if run and start > 0 and run[0] == items[start - 1][0] + 1:
            run.insert(0, items[start - 1][0])
        if not run and start > 0:
            # a stress mark with no vowel after it in this word: fall back to the first run
            for j, sym in items:
                if sym in _VOWELS or (run and sym in _VOWEL_MARKS):
                    run.append(j)
                elif run:
                    break
        out.update(run)
    return out


def _final_rimes(symbols: list, want) -> set:
    """Positions in `symbols` of the FINAL RIME of each source in `want`: its last vowel run (with
    the stress mark right before it and the length mark after) and the consonants that follow it,
    up to the mark and the space that end the word. What a pre-boundary lengthening stretches.

    A word with no vowel at all ("hmm") is held on its last sound.
    """
    by_src: dict = {}
    for j, (sym, src) in enumerate(symbols):
        if src in want and sym != " " and sym not in _MARK_SYMBOLS:
            by_src.setdefault(src, []).append((j, sym))
    out: set = set()
    for items in by_src.values():
        last = next(
            (k for k in range(len(items) - 1, -1, -1) if items[k][1] in _VOWELS), None
        )
        if last is None:
            out.add(items[-1][0])
            continue
        first = last
        while first > 0 and items[first - 1][1] in _VOWELS:
            first -= 1
        if first > 0 and items[first - 1][1] == _STRESS:
            first -= 1
        out.update(j for j, _ in items[first:])
    return out


def _hiss_codas(symbols: list) -> dict:
    """{source: runs} for the sources in `symbols` whose last sounds hold a hiss: how many runs
    of `_HISSES` follow the word's last vowel - one in "cards" and "last", two in "asks", where
    a stop parts them - or stand anywhere in a word with no vowel at all. What `_trail` may look
    for at the end of a word, and how much of it."""
    by_src: dict = {}
    for sym, src in symbols:
        if src >= 0 and sym != " " and sym not in _MARK_SYMBOLS:
            by_src.setdefault(src, []).append(sym)
    out: dict = {}
    for src, syms in by_src.items():
        last = next((k for k in range(len(syms) - 1, -1, -1) if syms[k] in _VOWELS), -1)
        coda = [s in _HISSES for s in syms[last + 1 :]]
        runs = sum(1 for k, h in enumerate(coda) if h and (k == 0 or not coda[k - 1]))
        if runs:
            out[src] = runs
    return out


# Click avoidance for spliced silence - see _splice_pauses.
SPLICE_SEARCH_MS = 3.0  # zero-crossing refinement around the chosen trough
SPLICE_ENV_MS = 8.0  # envelope smoothing: finds the quiet PLACE, not a quiet sample
SPLICE_FADE_MS = 2.0  # ramp at an edge that is already silent
SPLICE_RELEASE_MS = 30.0  # ramp out of a voice still sounding at the cut
SPLICE_ATTACK_MS = 12.0  # ramp back into one
SPLICE_QUIET = 0.02  # share of the utterance's peak under which an edge is silence
SPLICE_LOUD = 0.16  # share at which the ramps reach their full length
SPLICE_REACH_MS = 70.0  # how far past a mark the cut may look when no plan bounds it
SPLICE_REST_REACH = (
    2.0  # s each way a mark's rest is measured in: words bound it, not this
)

# Symbols that are punctuation rather than a word's sound, as `_symbols` emits them.
_MARK_SYMBOLS = frozenset(PAUSE_AFTER)


def _split_sentences(phones: list) -> list[list]:
    """Break a phone stream at sentence-final punctuation, keeping the mark."""
    out, cur = [], []
    for p in phones:
        cur.append(p)
        if str(p) in SENTENCE_END:
            out.append(cur)
            cur = []
    if cur and any(str(x).strip() for x in cur):
        out.append(cur)
    return out or [list(phones)]


def _pause_scale(params: dict) -> float:
    """The user's pause multiplier. 1.0 = the table, 0.0 = none, 2.0 = double."""
    try:
        return max(0.0, float(params.get("pause_scale", 1.0)))
    except (TypeError, ValueError):
        return 1.0


def _pause_for(mark: str, params: dict) -> float:
    """Extra silence after a mid-sentence mark, in seconds.

    One multiplier on the whole rest, for every mark (see DWELL and `_rest_for`): the model's own rest
    does not scale with our silence, so scaling only ours would stretch the gaps between marks rather
    than the marks. Applied to the total, the ratios at 10x are the ratios at 1x, and the curve
    saturates so the far end is long rather than broken.
    """
    if PAUSE_AFTER.get(str(mark), 0.0) <= 0.0:
        return 0.0
    return _rest_for(mark, params)


# The largest `dynamics` this file is handed (generative_editor._open_up's value at the top of the
# slider). Timing coefficients below are written as the figure they deliver there, divided by this.
# Kept here because the editor is Godot and this is Python; the two change together.
DEPTH_TOP = 2.5


def _discourse_plan(groups: list, params: dict) -> list[dict]:
    """Per-sentence rate and pitch from discourse structure, not from a clock.

    Piper never sees the paragraph, so every sentence starts from the same register. The rules:

      Paratone: F0 resets upward at the start of a discourse unit and declines across it, the reset
      scaling with boundary depth (Lehiste 1975; 't Hart/Collier/Cohen 1990; Sluijter & Terken 1993;
      Nakajima & Allen 1993). The wave is phase-locked to the text, not a fixed-period oscillator.
      Final lengthening: material before a boundary is lengthened in proportion to its strength (Klatt
      1975; Wightman et al. 1992).
      Length-conditioned rate: the longer the utterance the shorter its segments (Lindblom).
      Vocal effort, which is not volume: a louder voice has a flatter source spectrum, a quieter one a
      steeper tilt, and effort declines across a paragraph like pitch, so it rides the same contour.

    `dynamics` (0..1) scales the whole timing half, `prosody_arc` is the paragraph pitch arc in
    semitones peak-to-peak, `effort` scales the tilt/level contour. All default to 0.

    `lean_semis` and `lean_effort` move this sentence's register and effort a little on top: the
    delivery a script marks for a stretch, eased across sentences by the caller. The pitch rides the
    formant-locked path as the arc does. Clamped small.
    """
    depth = max(0.0, float(params.get("dynamics", 0.0)))
    arc = max(0.0, float(params.get("prosody_arc", 0.0)))
    effort = max(0.0, float(params.get("effort", 0.0)))
    lean_semis = min(max(float(params.get("lean_semis", 0.0) or 0.0), -1.5), 1.5)
    lean_effort = min(max(float(params.get("lean_effort", 0.0) or 0.0), -0.5), 0.5)
    n = len(groups)
    lens = [max(1, len(g)) for g in groups]
    typical = sum(lens) / float(n) if n else 1.0
    # The caller's place in the reading, when it knows it. A request is one sentence
    # (generative_editor.CHUNK_SENTENCES = 1), so deriving position from `groups` makes
    # every sentence the first and last of its own unit at once - u = 0 forever, no final
    # lengthening ever, and the arc flattened to a constant offset. Only the caller has
    # the paragraph structure, so it sends the position and this shapes it.
    u_in = params.get("plan_u")
    v_in = float(params.get("plan_v", 0.0) or 0.0)
    plan = []
    for i, g in enumerate(groups):
        # 0 at the top of the unit, 1 at its last sentence.
        if u_in is not None:
            u = min(max(float(u_in), 0.0), 1.0)
        else:
            u = 0.0 if n <= 1 else i / (n - 1.0)
        # Reset high, decline across the unit. Squared so most of the fall happens
        # late, which is the shape declination actually has.
        # NESTED ARCS. The paragraph's own decline, plus the slower one its SECTION is
        # making - so a run of one-sentence paragraphs, where the fast arc has no room to
        # move at all, still travels. Weighted toward the local shape where there is one:
        # the section is a swell under the writing, not the writing.
        semis = (
            arc * (0.5 - u * u * 0.5 - u * 0.5) * 0.62
            + arc * (0.5 - v_in * v_in * 0.5 - v_in * 0.5) * 0.38
            + lean_semis
        )
        # Progressive final lengthening into the unit's boundary, strongest at the
        # end. 18% at the top of the dial: a real pre-boundary rime lengthens far more
        # than that, but this is applied to the WHOLE sentence, not just its last rime.
        #
        # The ceiling had to be divided by `_open_up`'s and that is the bug this fixes.
        # These coefficients were written against a `depth` of 0..1 and read as their own
        # ceilings - the comment above has said "18%" since the day it was written.
        # generative_editor._open_up later opened the delivery dials to 2.5x at the top of
        # their travel, which multiplied every number here by two and a half without
        # touching this file: the paragraph term reached 45%, the section term 17%, and a
        # sentence at the end of both ran at rate 0.375, i.e. two and a half times its own
        # length. Reported as "the cadence/pace/speed of the voice becomes slower and
        # slower and slower... even at very small Arc values", and the Arc was innocent -
        # at the reported settings (arc 0.06, dynamics 0.62) the arc contributes 0.0% of
        # it and Dynamics contributes 15%, measured on the reporter's own voice and text.
        #
        # Scaled by DEPTH_TOP so the documented figures are what the top of the dial
        # actually delivers, which is what everything in this function was calibrated as.
        rate = (
            1.0
            - depth * (0.18 / DEPTH_TOP) * (u * u)
            - depth * (0.07 / DEPTH_TOP) * (v_in * v_in)
        )
        # Long sentences run a little faster, short ones a little slower.
        rel = lens[i] / typical if typical > 0 else 1.0
        rate *= 1.0 + depth * (0.10 / DEPTH_TOP) * (1.0 - min(max(rel, 0.5), 2.0)) * 0.5
        mark = ""
        for t in reversed(g):
            mark = str(t.get("punct", ""))
            if mark:
                break
        if mark == "?":
            rate *= 1.0 + depth * (
                0.04 / DEPTH_TOP
            )  # questions run slightly quicker...
            semis += arc * 0.20  # ...and end higher
        elif mark == "!":
            rate *= 1.0 + depth * (0.06 / DEPTH_TOP)
            semis += arc * 0.12
        # Rhythmic variety: the duration predictor's own noise, varied per sentence
        # instead of pinned for the take. Alternating rather than random so a
        # re-render is identical - an export must not be a different performance.
        nw = 1.0 + depth * (0.25 / DEPTH_TOP) * (1.0 if i % 2 == 0 else -1.0)
        # +1 at the top of the unit, -1 at its end: the effort contour, shared by
        # the tilt and the level so they can never disagree about which way is
        # louder. Squared-ish like the pitch decline, for the same reason.
        e = (
            1.0
            - 2.0
            * ((u * u * 0.5 + u * 0.5) * 0.62 + (v_in * v_in * 0.5 + v_in * 0.5) * 0.38)
        ) * effort + lean_effort
        plan.append(
            {
                "rate": max(0.55, rate),
                "semis": semis,
                "noise_w_mul": min(1.6, max(0.5, nw)),
                "tilt": 0.45 * e,
                "gain_db": 2.6 * e,
            }
        )
    return plan


def _effort(a, sr: int, tilt: float, gain_db: float):
    """Vocal effort: spectral TILT first, level second.

    The high band is what changes with effort, so it is what gets moved - a boxcar
    moving average is the low band and the residual is the high one, which is a
    crude filter and exactly the right amount of crude for a gentle shelf. It is
    also O(n) via a cumulative sum, which matters: this runs over every sentence
    and a per-sample IIR loop in Python would cost more than the model does.
    """
    import numpy as np

    if abs(tilt) < 1e-3 and abs(gain_db) < 1e-3:
        return a
    if abs(tilt) >= 1e-3 and a.size > 8:
        # ~1.2 kHz corner: below the speech formants that carry effort, above the
        # fundamental, so the tilt moves brightness and not the voice's weight.
        n = max(2, int(round(sr / 1200.0)))
        pad = np.concatenate(
            [np.full(n, a[0], dtype=np.float32), a, np.full(n, a[-1], dtype=np.float32)]
        )
        c = np.cumsum(pad, dtype=np.float64)
        lo = ((c[n:] - c[:-n]) / n).astype(np.float32)[: a.size]
        # A TILT, so the low band is cut by as much as the high band is lifted -
        # `a + tilt*(a - lo)` only ADDS treble, which is a level change wearing a
        # filter's clothes (measured +5.7 dB where +2.6 was asked for, and the two
        # controls stop being independent). Then renormalize to the level the
        # sentence came in at, so `gain_db` below is the ONLY thing that sets level
        # and the number in the tooltip is the number you get.
        rms0 = float(np.sqrt(np.mean(a.astype(np.float64) ** 2)))
        a = a + tilt * (a - 2.0 * lo)
        rms1 = float(np.sqrt(np.mean(a.astype(np.float64) ** 2)))
        if rms1 > 1e-9 and rms0 > 1e-9:
            a = (a * (rms0 / rms1)).astype(np.float32)
    if abs(gain_db) >= 1e-3:
        a = a * float(10.0 ** (gain_db / 20.0))
    return np.clip(a, -1.0, 1.0).astype(np.float32)


# The band-limited resampler's kernel: taps either side of the read position, and the Kaiser window's
# shape. 16 a side with beta 8.6 puts the stopband near -80 dB at 32 multiply-adds a sample.
RESAMPLE_TAPS = 16
RESAMPLE_BETA = 8.6
# The passband edge as a share of the lower Nyquist: what is above it is filtered out rather
# than folded back. Speech at 22.05 kHz has little left up there to lose.
RESAMPLE_CUTOFF = 0.94
# Fractional read positions are rounded to this many steps between two samples: 1024 left spurs at
# -68 dB by 8 kHz (the rounding is a timing jitter), 4096 holds every spur under -80 dB.
RESAMPLE_PHASES = 4096


def _emphasize(audio, edges: dict, group: list, sr: int):
    """The level half of `EMPHASIS`: each leaned-on word a little louder, eased in and out.

    `edges` is {token: (first sound, last sound)} in seconds - the word's own sounds, so the
    lift starts with the word rather than in the rest before it.
    """
    import numpy as np

    lifts = [
        (edges[ti], EMPHASIS[int(t.get("emph", 0) or 0)][1])
        for ti, t in enumerate(group)
        if int(t.get("emph", 0) or 0) in EMPHASIS and ti in edges
    ]
    if not lifts or audio.size == 0:
        return audio
    gain = np.ones(audio.size, dtype=np.float64)
    ramp = max(1, int(round(EMPHASIS_RAMP * sr)))
    for (a, b), db in lifts:
        lo = max(0, int(round(a * sr)) - ramp)
        hi = min(audio.size, int(round(b * sr)) + ramp)
        if hi <= lo:
            continue
        # never into the clip below: a word already near full scale is lifted by what room it has
        peak = float(np.max(np.abs(audio[lo:hi])))
        lift = 10.0 ** (db / 20.0)
        if peak > 0.0:
            lift = max(1.0, min(lift, EMPHASIS_CEILING / peak))
        g = np.full(hi - lo, lift)
        n = min(ramp, (hi - lo) // 2)
        if n > 0:
            ease = 0.5 - 0.5 * np.cos(np.linspace(0.0, np.pi, n))
            g[:n] = 1.0 + (g[:n] - 1.0) * ease
            g[-n:] = 1.0 + (g[-n:] - 1.0) * ease[::-1]
        gain[lo:hi] = np.maximum(gain[lo:hi], g)
    return np.clip(audio * gain, -1.0, 1.0).astype(np.float32)


def _rms_envelope(a, n: int):
    """Moving RMS of `a` over `n` samples, centered, one value per sample (an edge uses what
    is there)."""
    import numpy as np

    c = np.concatenate(([0.0], np.cumsum(np.square(a, dtype=np.float64))))
    i = np.arange(a.size)
    lo = np.clip(i - n // 2, 0, a.size)
    hi = np.clip(i - n // 2 + n, 0, a.size)
    return np.sqrt((c[hi] - c[lo]) / np.maximum(hi - lo, 1))


def _glide(audio, a: int, b: int, c: int, fall: float, stop: int, sr: int) -> bool:
    """Lower the pitch of audio[a:b] in place by up to `fall` semitones, keeping the length.

    Bought as the arc's pitch is, by reading slower: rate 1 at `a`, easing (smoothstep) to 2^(-fall/12)
    at `b`, and at that rate on to `c`. The slower read runs a few milliseconds long and the audio after
    it must not move (the plan's times, the splices and the karaoke stand on it), so the glided read
    runs on over the samples it displaced and TRAIL_JOIN seconds of it are crossfaded back into the
    original, in a word's last moments and the rest after it (`c` is inside the rest), where a join is
    silent. `stop` is the first sample it may not write: the next word is never touched. Returns False,
    having touched nothing, where it does not fit.

    The formants go down with the pitch (8% at 1.5 semitones) and `_restore_formants` is not used:
    under the end-of-word fade the vowel only darkens as it falls.
    """
    import numpy as np

    join = max(1, int(round(TRAIL_JOIN * sr)))
    if fall <= 0.0 or b - a < 8 or c < b or a < 0 or c + join >= audio.size:
        return False
    r_end = 2.0 ** (-fall / 12.0)
    pos = np.arange(a, c + 1, dtype=np.float64)
    f = np.clip((pos - a) / float(b - a), 0.0, 1.0)
    rate = 1.0 - (1.0 - r_end) * f * f * (3.0 - 2.0 * f)
    # the output sample at which each source position is reached
    t = np.concatenate(([0.0], np.cumsum(1.0 / rate[:-1])))
    n_out = int(t[-1])
    if a + n_out + join > stop:
        return False
    u = np.interp(np.arange(n_out), t, pos)
    u_on = u[-1] + r_end * np.arange(1, join + 1)
    src = np.pad(audio.astype(np.float32), (RESAMPLE_TAPS, RESAMPLE_TAPS + 1))
    y = _read_at(src, np.concatenate((u, u_on)), _sinc_table(RESAMPLE_CUTOFF))
    ease = 0.5 - 0.5 * np.cos(np.pi * (np.arange(join) + 0.5) / join)
    at = a + n_out
    y[n_out:] = y[n_out:] * (1.0 - ease) + audio[at : at + join] * ease
    audio[a : at + join] = y
    return True


def _is_hiss(x, sr: int, peak: float, above: float = LEAD_ABOVE) -> bool:
    """Whether the frame `x` is hiss: louder than LEAD_FLOOR of the take's `peak`, with more than
    LEAD_HF of its energy above `above` Hz."""
    import numpy as np

    x = x.astype(np.float64)
    if x.size < 8 or np.sqrt(np.mean(x * x)) < peak * LEAD_FLOOR:
        return False
    spec = np.abs(np.fft.rfft(x * np.hanning(x.size))) ** 2
    tot = float(spec.sum())
    high = float(spec[np.fft.rfftfreq(x.size, 1.0 / sr) >= above].sum())
    return tot > 0.0 and high / tot > LEAD_HF


def _hiss_from(
    audio, lo: int, hi: int, sr: int, peak: float, above: float = LEAD_ABOVE
) -> int:
    """Where the run of hiss that ends at sample `hi` begins, walked back from it frame by frame
    and never before `lo`; `hi` itself where the frame before it is not hiss (`_is_hiss`)."""
    w = max(8, int(round(LEAD_FRAME * sr)))
    k = int(hi)
    while k - w >= lo and _is_hiss(audio[k - w : k], sr, peak, above):
        k -= w
    return k


def _hiss_tail(audio, lo: int, by: int, hi: int, sr: int, peak: float, runs: int = 1):
    """(start, end) in samples of the hiss a word ends on, looked for in [lo, hi), or None.

    From the first frame of hiss (above TRAIL_HISS_ABOVE) after `lo` - which must come before
    `by`, or it is not this word's - through `runs` runs of it: a run goes on over a dropout of
    TRAIL_HISS_DROP, and the next one may start up to TRAIL_HISS_GAP after it (a stop's
    closure). A stray frame out in the rest is none of it. A start at `lo` itself may be the
    middle of a run: the caller walks it back (`_hiss_from`).
    """
    w = max(8, int(round(LEAD_FRAME * sr)))
    drop = int(round(TRAIL_HISS_DROP * sr))
    gap = int(round(TRAIL_HISS_GAP * sr))
    start = end = None
    left = max(1, int(runs))
    for k in range(int(lo), int(hi) - w + 1, w):
        hiss = _is_hiss(audio[k : k + w], sr, peak, TRAIL_HISS_ABOVE)
        if start is None:
            if hiss:
                start, end = k, k + w
            elif k > by:
                break
        elif hiss:
            if k - end > drop:
                # past a closure: the next run, where the word has one
                if left <= 1:
                    break
                left -= 1
            end = k + w
        elif k - end >= (gap if left > 1 else drop):
            break
    return None if start is None else (start, end)


def _sound_from(audio, lo: int, hi: int, sr: int, peak: float) -> int:
    """Where the sound that is running at sample `hi` begins: walked back from it frame by frame
    while a frame is louder than TRAIL_SOUNDING of the take's `peak`, and never before `lo`."""
    import numpy as np

    w = max(8, int(round(LEAD_FRAME * sr)))
    k = int(hi)
    while k - w >= lo:
        x = audio[k - w : k].astype(np.float64)
        if np.sqrt(np.mean(x * x)) < peak * TRAIL_SOUNDING:
            break
        k -= w
    return k


def _quiet_lead(audio, edges: dict, group: list, params: dict, sr: int):
    """The next word's hiss in a floored rest held to LEAD_KEEP seconds (see LEAD_KEEP).

    Only where the rest was floored (`_floor_of`), which is what lengthens the lead; an unfloored
    boundary is the model's own. The lead is walked back from the next word's first sound and never past
    the plan's end of this one. A word's own final hiss runs past that end (see `_HISSES`) and is kept
    from it by the silence between the two. Returns a copy, or `audio` itself where nothing is changed.
    """
    import numpy as np

    peak = float(np.max(np.abs(audio))) if audio.size else 0.0
    out = None
    for ti, tok in enumerate(group):
        nxt = edges.get(ti + 1)
        if ti not in edges or nxt is None or peak <= 0.0:
            continue
        if _floor_of(tok, params) <= 0.0:
            continue
        lo = int(round(float(edges[ti][1]) * sr))
        hi = min(audio.size, int(round(float(nxt[0]) * sr)))
        start = _hiss_from(audio, lo, hi, sr, peak)
        keep = hi - int(round(LEAD_KEEP * sr))
        if start >= keep:
            continue
        if out is None:
            out = np.array(audio, dtype=np.float32, copy=True)
        ramp = min(int(round(LEAD_RAMP * sr)), hi - keep)
        fade = max(1, int(round(SPLICE_FADE_MS * sr / 1000.0)))
        # out over a few ms where the hiss starts, nothing until the kept lead, then back in
        n = min(fade, keep - start)
        out[start : start + n] *= np.linspace(1.0, 0.0, n, dtype=np.float32)
        out[start + n : keep] = 0.0
        if ramp > 0:
            out[keep : keep + ramp] *= (
                0.5 - 0.5 * np.cos(np.pi * (np.arange(ramp) + 0.5) / ramp)
            ).astype(np.float32)
    return audio if out is None else out


def _trail(audio, edges: dict, group: list, params: dict, sr: int, hisses=None,
           walk_back=None, through: bool = False):
    """The fade and the sag of `TRAIL_*`, on each word that comes before a mid-sentence mark or a rest
    the caller splices in (`REST_AFTER_FLOOR`).

    `edges` is {token: (first sound, last sound)} in seconds. The voice's own end is searched in the
    waveform (the last point within TRAIL_VOICED_DB of the final rime's peak) because the plan puts it
    50 ms early to 80 ms late; the fade ends there, so the model's own drop lands in the part already
    down. `hisses` is {token: runs} for words that end on a hiss (`_hiss_codas`): theirs is found and
    left at the model's level, the voice ending before it (see `_HISSES`). Returns a copy with the words
    changed, or `audio` itself where none is.

    `walk_back` is how far the next word's start is walked back over sound (None: TRAIL_EARLY).
    `through`: where the voice runs right up to the next word, the way back up (TRAIL_BACK) runs on into
    it rather than shrinking to a one-sample step, which would cut the next word in.
    """
    import numpy as np

    todo = [
        (ti, _trail_weight(str(t.get("punct", "")), params, _rest_after(t), _tail_share(group, ti)))
        for ti, t in enumerate(group)
        if ti in edges
    ]
    todo = [(ti, w) for ti, w in todo if w > 0.0]
    peak = float(np.max(np.abs(audio))) if audio.size else 0.0
    if not todo or peak <= 0.0:
        return audio
    out = np.array(audio, dtype=np.float32, copy=True)
    n_env = max(1, int(round(0.010 * sr)))
    guard = int(round(0.010 * sr))
    reach = int(round((TRAIL_EARLY if walk_back is None else float(walk_back)) * sr))
    for ti, w in todo:
        first, last = (int(round(float(x) * sr)) for x in edges[ti])
        nxt = edges.get(ti + 1)
        limit = out.size if nxt is None else min(out.size, int(round(float(nxt[0]) * sr)))
        # the next word starts where its lead hiss does (`_quiet_lead`), or where its own sound does if
        # earlier: never faded, never taken for this word's voice
        limit = _hiss_from(audio, last, limit, sr, peak)
        early = max(last, limit - reach)
        limit = _sound_from(audio, early, limit, sr, peak)
        lo = max(first, last - int(round(0.12 * sr)))
        hi = min(limit - guard, last + int(round(0.25 * sr)))
        if hi - lo < 4 * n_env:
            continue
        env = _rms_envelope(audio[lo:hi], n_env)
        head = env[: max(1, last + int(round(0.08 * sr)) - lo)]
        top = float(head.max())
        if top < peak * 0.01:
            continue
        end = lo + int(np.flatnonzero(env >= top * 10.0 ** (-TRAIL_VOICED_DB / 20.0))[-1])
        # the hiss this word ends on, and the voice ending before it
        tail = None
        runs = int(hisses.get(ti, 0)) if hisses else 0
        if runs > 0:
            by = max(end, last) + int(round(TRAIL_HISS_GAP * sr))
            tail = _hiss_tail(audio, lo + int(head.argmax()), by, hi, sr, peak, runs)
        if tail is not None:
            tail = (_hiss_from(audio, first, tail[0], sr, peak, TRAIL_HISS_ABOVE), tail[1])
            end = min(end, tail[0] - int(round(TRAIL_HISS_IN * sr)))
        tip = min(int(round(TRAIL_TIP * sr)), end - first)
        if tip < int(round(0.03 * sr)):
            continue
        stop = max(end, limit - guard)
        span = min(int(round(TRAIL_SAG_SPAN * sr)), end - first)
        if tail is not None:
            # the slow read's run-on ends before the hiss: none of it is displaced
            _glide(out, end - span, end, end, TRAIL_SAG * w, tail[0], sr)
        else:
            c = min(end + int(round(TRAIL_SAG_TAIL * sr)), stop)
            if not _glide(out, end - span, end, c, TRAIL_SAG * w, stop, sr):
                _glide(out, end - span, end, end, TRAIL_SAG * w, stop, sr)
        depth = TRAIL_DB * w * TRAIL_FADE.get(str(group[ti].get("punct", "")), 1.0)
        base = end - tip
        back = int(round(TRAIL_BACK * sr))
        if through and tail is None:
            stop = max(stop, min(out.size, end + back))
        n = stop - base
        back = min(back, stop - end)
        if tail is None:
            g = np.full(n, -depth)
            g[:tip] = -depth * (np.arange(tip) / float(tip)) ** 2
            if back > 0:
                g[n - back :] = -depth * (1.0 - np.arange(back) / float(back))
        else:
            # the voice down to its hiss's level and no further, up to nothing as the hiss
            # arrives, and the floor once it has ended
            voice = float(_rms_envelope(audio[base:end], n_env).max())
            hiss = float(_rms_envelope(audio[tail[0] : tail[1]], n_env).max())
            fall = min(depth, max(0.0, 20.0 * math.log10(max(voice, 1e-9) / max(hiss, 1e-9))))
            at = np.arange(n, dtype=np.float64)
            up = np.clip((at + base - tail[0]) / (TRAIL_HISS_IN * sr) + 1.0, 0.0, 1.0)
            down = np.clip((tail[1] - at - base) / (TRAIL_HISS_OUT * sr) + 1.0, 0.0, 1.0)
            up = 0.5 - 0.5 * np.cos(np.pi * up)
            down = 0.5 - 0.5 * np.cos(np.pi * down)
            g = -fall * np.minimum(at / float(tip), 1.0) ** 2 * (1.0 - up) - depth * (1.0 - down)
            if back > 0:
                g[n - back :] *= 1.0 - np.arange(back) / float(back)
        out[base:stop] *= (10.0 ** (g / 20.0)).astype(np.float32)
    return out


def _resample(a, ratio: float):
    """Play `a` back `ratio` times faster: how both pitch moves are bought (the Tone and the arc).

    Band-limited: linear interpolation lets spectral images through and droops the top end (1.8 dB at a
    quarter of the sample rate, 4 dB at 8 kHz), and a faster playback folds what lies above the new
    Nyquist back as alias; every sentence goes through twice (the arc here, the Tone in the editor), so
    the dulling compounds. At +1.5 semitones linear left images at -27 dB by 4 kHz and -14 dB by 8 kHz;
    this keeps every spur under -80 dB and the passband within about a dB to 8 kHz.

    A Kaiser-windowed sinc cut off at the lower of the two Nyquists, read at the positions linear
    interpolation read (the first sample to the last, `n` evenly spaced), so timings computed against
    it still land.
    """
    import numpy as np

    if abs(ratio - 1.0) < 1e-4 or a.size < 2:
        return a
    n = max(1, int(round(a.size / ratio)))
    if n < 2:
        return a[:1].astype(np.float32)
    step = (a.size - 1.0) / (n - 1.0)
    table = _sinc_table(RESAMPLE_CUTOFF * min(1.0, 1.0 / step))
    src = np.pad(a.astype(np.float32), (RESAMPLE_TAPS, RESAMPLE_TAPS + 1))
    out = np.empty(n, dtype=np.float32)
    block = 16384
    for s in range(0, n, block):
        pos = np.arange(s, min(n, s + block)) * step
        out[s : s + pos.size] = _read_at(src, pos, table)
    return out


@functools.lru_cache(maxsize=8)
def _sinc_table(fc: float):
    """The resampler's kernel, tabulated at RESAMPLE_PHASES fractional offsets (polyphase: each output
    sample reads the nearest row, as computing the window per sample is too slow)."""
    import numpy as np

    w = RESAMPLE_TAPS
    k = np.arange(-w + 1, w + 1)
    frac = np.arange(RESAMPLE_PHASES + 1) / RESAMPLE_PHASES
    d = frac[:, None] - k[None, :]
    win = np.i0(RESAMPLE_BETA * np.sqrt(np.clip(1.0 - (d / (w + 1.0)) ** 2, 0.0, 1.0)))
    table = (fc * np.sinc(fc * d) * win / np.i0(RESAMPLE_BETA)).astype(np.float32)
    table.flags.writeable = False
    return table


def _read_at(src, pos, table):
    """`src` read at the fractional sample positions `pos`. `src` is padded by RESAMPLE_TAPS
    before it and RESAMPLE_TAPS + 1 after, so a position `p` of the unpadded audio is `p` here."""
    import numpy as np

    w = RESAMPLE_TAPS
    k = np.arange(-w + 1, w + 1)
    base = np.floor(pos).astype(np.int64)
    phase = np.rint((pos - base) * RESAMPLE_PHASES).astype(np.int64)
    taps = src[base[:, None] + k[None, :] + w]
    return np.einsum("ij,ij->i", taps, table[phase])


# --- the source and the filter, separated -----------------------------------
#
# Speech is a source (the glottal buzz, which carries pitch) driven through a filter (the vocal tract,
# whose resonances carry the words and the speaker). A whisper is that filter with noise in place of
# the buzz; a pitch move that keeps the speaker is the buzz moved with the filter held still. Both
# first need an estimate of the filter, frame by frame.
#
# Linear prediction gives it: an LPC fit of order p is a smooth envelope through the harmonics, and
# test_source_filter.py tracks formants with the same autocorrelation-plus-Levinson method, so gate and
# effect agree on where a formant is.
#
# Numpy only (hosts/voice/requirements.txt has no scipy, so no lfilter or IIR): both effects are
# magnitude edits on a windowed FFT, overlap-added back. Levinson is vectorized across frames (the
# loop runs `order` times over all frames at once).

_LPC_FRAME = 0.032  # s: long enough for two pitch periods of a low male voice
_LPC_HOP = 0.008  # s: 75% overlap, where a Hann window's square sums flat
# The whisper's noise is fixed so a re-render is the same performance (as the duration-predictor
# jitter alternates by sentence index instead of sampling; see `_discourse_plan`).
_WHISPER_SEED = 0x5EED
# How much smoother than the data the whisper's envelope is asked to be (see `_lpc_envelopes`): 0.98 is
# where the fundamental leaves without the vowel. The formant lock does not use it: it wants the
# sharpest envelope.
_WHISPER_GAMMA = 0.98


def _lpc_windows(sr: int) -> tuple:
    """(window length, hop, FFT size, Hann window) for this sample rate."""
    import numpy as np

    win = max(64, int(round(_LPC_FRAME * sr)) // 2 * 2)
    hop = max(16, int(round(_LPC_HOP * sr)))
    nfft = 1
    while nfft < win:
        nfft *= 2
    return win, hop, nfft, np.hanning(win).astype(np.float32)


def _framed(x, win: int, hop: int):
    """`x` cut into overlapping frames, one row each."""
    import numpy as np

    if x.size < win:
        x = np.pad(x, (0, win - x.size))
    n = 1 + (x.size - win) // hop
    idx = np.arange(win)[None, :] + hop * np.arange(n)[:, None]
    return x[idx].astype(np.float64)


def _lpc_envelopes(frames, order: int, nfft: int, gamma: float = 1.0):
    """The spectral envelope of every frame at once.

    Levinson-Durbin vectorized across frames: the recursion is over the order and each quantity is a
    scalar per frame, so each of the `order` steps is one vector operation. The autocorrelation comes
    from one batched FFT.

    `gamma` under 1 is bandwidth expansion: scaling the coefficients by gamma^k pulls every pole in off
    the unit circle, so the envelope passes over harmonics instead of tracking them at a low pitch
    (harmonic ripple would print onto the whisper's noise). Measured on a synthetic 118 Hz vowel:
    harmonicity 0.24 at gamma 1, 0.06 at 0.98. Costs a little formant accuracy (F1 about 12% high at
    0.98, F2 and F3 within 3%).
    """
    import numpy as np

    n = frames.shape[1]
    size = 1
    while size < 2 * n:
        size *= 2
    spec = np.fft.rfft(frames, size, axis=1)
    r = np.fft.irfft(spec * np.conj(spec), size, axis=1)[:, : order + 1]
    # A ridge on the zero lag. Silence and pure tones are both singular for a
    # plain fit, and a sentence has silence at both ends of it by construction.
    r[:, 0] = r[:, 0] * 1.0001 + 1e-9
    f = frames.shape[0]
    a = np.zeros((f, order + 1))
    a[:, 0] = 1.0
    err = r[:, 0].copy()
    for i in range(1, order + 1):
        acc = r[:, i].copy()
        if i > 1:
            acc += np.sum(a[:, 1:i] * r[:, i - 1 : 0 : -1], axis=1)
        k = -acc / np.maximum(err, 1e-12)
        if i > 1:
            prev = a[:, 1:i].copy()
            a[:, 1:i] = prev + k[:, None] * prev[:, ::-1]
        a[:, i] = k
        err = np.maximum(err * (1.0 - k * k), 1e-12)
    if gamma < 1.0:
        a = a * (gamma ** np.arange(order + 1))[None, :]
    # |H(w)| = sqrt(gain) / |A(w)|
    aw = np.fft.rfft(a, nfft, axis=1)
    return np.sqrt(err)[:, None] / np.maximum(np.abs(aw), 1e-9)


def _overlap_add(frames, hop: int, length: int, window, incoherent: bool = False):
    """Frames back to a signal, windowed again and normalized by what overlapped.

    The second window is needed because a frame whose magnitude spectrum was edited is no longer
    confined to its frame, and adding the raw result back seams audibly. Dividing by the accumulated
    squared window makes the reconstruction exact where nothing was edited.

    `incoherent` is for noise frames: overlapping independent noise adds in power, so the same division
    leaves it 2.7 dB quiet; the square root is the right normalizer. (Continuous noise adding
    coherently puts a 125 Hz buzz in the pitch range a whisper vacates: harmonicity 0.37 against 0.24.)
    """
    import numpy as np

    win = frames.shape[1]
    out = np.zeros(length + win, dtype=np.float64)
    norm = np.zeros_like(out)
    w2 = (window * window).astype(np.float64)
    for i in range(frames.shape[0]):
        s = i * hop
        out[s : s + win] += frames[i] * window
        norm[s : s + win] += w2
    den = np.maximum(norm[:length], 1e-6)
    return (out[:length] / (np.sqrt(den) if incoherent else den)).astype(np.float32)


def _rms_match(frames, target_frames):
    """Per-frame level, restored. Both effects rebuild a frame from scratch."""
    import numpy as np

    have = np.sqrt(np.mean(frames * frames, axis=1))
    want = np.sqrt(np.mean(target_frames * target_frames, axis=1))
    return frames * (want / np.maximum(have, 1e-9))[:, None]


def _whisper(a, sr: int, amount: float):
    """Keep the vocal tract, replace the voice in it with breath.

    A whisper has no fundamental and no harmonics, and the words survive in the resonances. No inference
    parameter produces one (a VITS checkpoint trained on modal speech has none to sample), but a filter
    can: rebuild each frame as noise shaped by that frame's own spectral envelope.

    `amount` blends against the original: half way is a stage whisper, a voice that has not quite left.
    """
    import numpy as np

    amount = min(1.0, max(0.0, float(amount)))
    if amount <= 1e-3 or a.size < 4:
        return a
    win, hop, nfft, window = _lpc_windows(sr)
    frames = _framed(a, win, hop) * window
    env = _lpc_envelopes(frames, _lpc_order(sr), nfft, _WHISPER_GAMMA)
    # A fresh draw per frame, not one continuous noise - see `_overlap_add`.
    rng = np.random.default_rng(_WHISPER_SEED)
    noise = rng.standard_normal(frames.shape)
    spec = np.fft.rfft(noise * window, nfft, axis=1) * env
    built = np.fft.irfft(spec, nfft, axis=1)[:, :win]
    built = _rms_match(built, frames)
    wet = _overlap_add(built, hop, a.size, window, incoherent=True)
    # ...and the level trimmed once at the end: the per-frame match and the incoherent normalizer still
    # land about a decibel low.
    dry = a.astype(np.float64)
    have = float(np.sqrt(np.mean(wet.astype(np.float64) ** 2)))
    want = float(np.sqrt(np.mean(dry * dry)))
    if have > 1e-9:
        wet = wet * (want / have)
    # Power-preserving: the whisper (noise) and the voice under it are uncorrelated, so they add in
    # power and a straight `a*wet + (1-a)*dry` lands at sqrt(a^2 + (1-a)^2) of the level (-2.95 dB at
    # 0.45, nothing at either end). Matches the prediction to 0.02 dB.
    norm = math.sqrt(amount * amount + (1.0 - amount) ** 2)
    out = (amount * wet + (1.0 - amount) * dry) / max(norm, 1e-9)
    return np.clip(out, -1.0, 1.0).astype(np.float32)


def _muffle(a, sr: int, amount: float):
    """A voice coming through something: the high end taken off, and a little level with it.

    Not the Presence dial's distance: distance is a property of the room and belongs to whoever directs
    the reading, a muffle a property of the voice (Gruff speaks through a mask) and belongs to the tone
    that asked for it, so the two must not share a knob.

    A one-pole low-pass: a gentle wide-band roll-off rather than a filter with an audible corner, and
    the cheapest thing that cannot ring. The level trim goes with it because a covered voice is quieter.
    """
    import numpy as np

    amount = min(1.0, max(0.0, float(amount)))
    if amount <= 1e-3 or a.size < 2:
        return a
    # 9 kHz wide open down to about 1.4 kHz at full - a mask, not a telephone.
    cut = 9000.0 * math.pow(0.155, amount)
    x = math.exp(-2.0 * math.pi * cut / float(sr))
    # The pole as its impulse response rather than a per-sample Python recursion: the kernel is spent
    # inside 40 taps (x^40 is 1e-7 at the widest setting).
    taps = np.arange(40)
    kernel = (1.0 - x) * np.power(x, taps)
    out = np.convolve(a.astype(np.float64), kernel)[: a.size]
    # ...and put back what the filter took off the level, less the trim the muffle is worth.
    have = float(np.sqrt(np.mean(out.astype(np.float64) ** 2)))
    want = float(np.sqrt(np.mean(a.astype(np.float64) ** 2))) * (1.0 - 0.18 * amount)
    if have > 1e-9:
        out = out * (want / have)
    return np.clip(out, -1.0, 1.0).astype(np.float32)


def _restore_formants(shifted, source, ratio: float, sr: int):
    """Put `source`'s formants back onto `shifted` after a resample.

    A resample moves the whole spectrum, so buying a pitch move with one also moves the formants, which
    carry the speaker's size: the paragraph arc made a different, larger person finish the paragraph.
    The resampled frame already has the wanted pitch: divide its spectrum by its own envelope and
    multiply by the envelope of the frame it came from, and the harmonics stay where the resample put
    them while the resonances return to the speaker's. Frame i of the output stands at `i * hop * ratio`
    in the source, as the resample did to the time axis.
    """
    import numpy as np

    if abs(ratio - 1.0) < 1e-4 or shifted.size < 4 or source.size < 4:
        return shifted
    win, hop, nfft, window = _lpc_windows(sr)
    out_frames = _framed(shifted, win, hop) * window
    n = out_frames.shape[0]
    # the same frames, located in the pre-resample audio
    src = source
    if src.size < win:
        src = np.pad(src, (0, win - src.size))
    starts = np.minimum(
        np.round(np.arange(n) * hop * ratio).astype(np.int64), src.size - win
    )
    starts = np.maximum(starts, 0)
    src_frames = src[starts[:, None] + np.arange(win)[None, :]].astype(np.float64)
    src_frames = src_frames * window
    order = _lpc_order(sr)
    nfft_env = nfft
    want = _lpc_envelopes(src_frames, order, nfft_env)
    have = _lpc_envelopes(out_frames, order, nfft_env)
    # Bounded, because a frame of near-silence has an envelope that means nothing
    # and dividing by it is how a click gets made.
    corr = np.clip(want / np.maximum(have, 1e-9), 0.05, 20.0)
    spec = np.fft.rfft(out_frames, nfft, axis=1) * corr
    built = np.fft.irfft(spec, nfft, axis=1)[:, :win]
    built = _rms_match(built, out_frames)
    out = _overlap_add(built, hop, shifted.size, window)
    return np.clip(out, -1.0, 1.0).astype(np.float32)


def _lpc_order(sr: int) -> int:
    """One pole pair per kHz, plus two for the glottal tilt - the usual rule."""
    return int(min(36, 2 + sr // 1000))


def _nominal_seconds(frames, ratio: float, sr: int, floor=None) -> float:
    """How long this sentence would have run at `1/ratio` of the length scale it was given.

    A per-sentence pitch move renders `pr` times slower and plays back `pr` times faster, and the two do
    not cancel in duration: the duration predictor's output is ceiled to whole frames per phoneme id
    (pads and BOS/EOS included), so an id at its one-frame floor cannot get shorter, and 13% to 46% of a
    sentence (by voice and sentence) does not respond to length_scale. Uncorrected, the arc opens a unit
    high (renders long, plays short) and closes it low, so the reading accelerates into every paragraph
    and drags out of it (5.1% and 2.0% at the top of the Arc dial on a 3 s sentence).

    The frames are the plan the synthesizer used: `frames_i = ceil(d_i * L)` says `d_i * L` fell in
    `(m-1, m]`, so at the other scale it falls in `((m-1)/r, m/r]`, and averaging the ceiling over that
    interval is the integral of a staircase, closed form. It is general in the width: a pull-down (ratio
    under 1) widens the interval past a whole frame, and a two-term version reads 6% long there.

    Exact at ratio 1, so with no arc there is no correction.

    `floor` is the per-id rest floor the render was given (`_rest_floor`), or None. An id held at its
    floor is a fixed number of frames at any length scale.
    """
    import numpy as np

    if frames is None or ratio <= 0.0:
        return 0.0

    def area(x):
        """The integral of ceil() from 0 to x - a staircase, so it is closed form."""
        k = np.floor(x)
        return k * (k + 1.0) * 0.5 + (k + 1.0) * (x - k)

    m = np.asarray(frames, dtype=np.float64)
    lo = np.maximum(m - 1.0, 0.0) / ratio
    hi = m / ratio
    width = np.maximum(hi - lo, 1e-12)
    exp = (area(hi) - area(lo)) / width
    # An id at the floor stays at the floor, and this is the whole fixed fraction: a one-frame id's
    # predicted duration was under a frame (most are the pads between phonemes, near zero), so averaging
    # the ceiling over that frame would credit it half a frame it never had, and a pull-down turns that
    # into a whole extra frame each (+6% of a sentence).
    exp = np.where(m <= 1.0, 1.0, exp)
    if floor is not None:
        f = np.asarray(floor, dtype=np.float64)
        exp = np.where((f > 0.0) & (m <= f), m, exp)
    return float(np.maximum(exp, 1.0).sum()) * HOP_LENGTH / float(sr)


# A first guess at that fixed fraction, used to ask for a length scale that lands near the requested
# pitch move. Only the neighborhood matters: `_nominal_seconds` measures afterwards and the resample
# corrects, so timing is exact and only the delivered semitones drift.
PACE_FIXED_GUESS = 0.30


def _pitch_length(pr: float) -> float:
    """The length-scale factor to REQUEST for a pitch move of `pr`.

    Solving `A*L + b = pr * (A*ls + b)` for L, with `b/(A*ls) = f/(1-f)`: asking for exactly
    `pr` lands short of it, because the fixed part comes back unscaled and then gets divided
    by `pr` along with everything else.
    """
    f = PACE_FIXED_GUESS / (1.0 - PACE_FIXED_GUESS)
    return pr + f * (pr - 1.0)


def _gap_for(mark: str, params: dict) -> float:
    """Seconds between two sentences, for a sentence ending in `mark`.

    Unified with PAUSE_AFTER rather than added to it: a full stop's pause is
    this gap and nothing else, so `pause_scale` cannot double-count it.
    """
    raw = params.get("sentence_gap")
    if raw is None:
        base = PAUSE_AFTER.get(str(mark), PAUSE_AFTER["."])
    else:
        try:
            base = float(raw)
        except (TypeError, ValueError):
            base = PAUSE_AFTER["."]
    # The same rule as every other mark: the dial scales the whole rest and the model's share is
    # subtracted. A caller's `sentence_gap` still wins over the table, as a top-up at 1.0.
    return _rest_for(str(mark), params, base)


def _trough(audio, lo: int, hi: int, sr: int, quiet: float) -> int:
    """The sample in [lo, hi) to cut at: the quietest PLACE, refined to a zero crossing.

    The envelope is a moving average of |x| (SPLICE_ENV_MS), so the search lands in the
    dip between two sounds rather than on whichever zero crossing of a vowel happens to be
    nearest. Where part of the window is silence (envelope under `quiet`) the cut goes in
    the middle of its longest silent run, as far from both words as it can get. An empty
    window returns `lo`.
    """
    import numpy as np

    n = int(audio.size)
    lo = min(max(int(lo), 0), n)
    hi = min(max(int(hi), lo), n)
    if hi - lo <= 1:
        return lo
    w = max(1, int(round(SPLICE_ENV_MS * sr / 1000.0)))
    a0, a1 = max(0, lo - w), min(n, hi + w)
    c = np.concatenate(([0.0], np.cumsum(np.abs(audio[a0:a1]).astype(np.float64))))
    pos = np.arange(lo, hi)
    s0 = np.clip(pos - w // 2, a0, a1) - a0
    s1 = np.clip(pos - w // 2 + w, a0, a1) - a0
    smooth = (c[s1] - c[s0]) / np.maximum(s1 - s0, 1)
    silent = smooth <= quiet
    if silent.any():
        edge = np.diff(np.concatenate(([0], silent.astype(np.int8), [0])))
        starts, ends = np.flatnonzero(edge == 1), np.flatnonzero(edge == -1)
        k = int(np.argmax(ends - starts))
        return lo + int((starts[k] + ends[k]) // 2)
    center = lo + int(np.argmin(smooth))
    r = max(1, int(round(SPLICE_SEARCH_MS * sr / 1000.0)))
    zl, zh = max(lo, center - r), min(hi, center + r + 1)
    mag = np.abs(audio[zl:zh])
    cand = np.flatnonzero(mag <= float(mag.min()) + 1e-6) + zl
    return int(cand[np.argmin(np.abs(cand - center))])


def _edge_level(audio, at: int, before: bool, sr: int) -> float:
    """RMS of the 5 ms on one side of sample `at`."""
    import numpy as np

    n = max(1, int(round(0.005 * sr)))
    seg = audio[max(0, at - n) : at] if before else audio[at : at + n]
    return (
        float(np.sqrt(np.mean(np.square(seg, dtype=np.float64)))) if seg.size else 0.0
    )


def _edge_ramp(level: float, peak: float, longest_ms: float, sr: int) -> int:
    """Samples of ramp at a splice edge, by how loud the audio still is there.

    Silence takes SPLICE_FADE_MS. A voice still sounding at the cut gets up to
    `longest_ms`: a ramp of a couple of milliseconds on a vowel is itself a click, and a
    release of a few tens of milliseconds reads as the reader stopping. Interpolated on a
    log scale between SPLICE_QUIET and SPLICE_LOUD, because loudness is.
    """
    quiet, loud = SPLICE_QUIET * peak, SPLICE_LOUD * peak
    if peak <= 0.0 or level <= quiet:
        ms = SPLICE_FADE_MS
    else:
        k = min(1.0, math.log(level / quiet) / math.log(loud / quiet))
        ms = SPLICE_FADE_MS + k * (longest_ms - SPLICE_FADE_MS)
    return max(1, int(round(ms * sr / 1000.0)))


def _ramp(seg, n_in: int, n_out: int) -> None:
    """Raised-cosine fade over the first `n_in` and last `n_out` samples of `seg`, in place."""
    import numpy as np

    def curve(k: int):
        return (0.5 - 0.5 * np.cos(np.pi * (np.arange(k) + 0.5) / k)).astype(seg.dtype)

    k = min(int(n_in), int(seg.size))
    if k > 0:
        seg[:k] *= curve(k)
    k = min(int(n_out), int(seg.size))
    if k > 0:
        seg[seg.size - k :] *= curve(k)[::-1]


def _gap_window(edges: dict, ti, frame: float):
    """(lo, hi) seconds a pause after token `ti` may be cut in, or None.

    From the end of the token's last phoneme - so the punctuation's own frames are in
    reach, which is where the model rests when it does - to one frame into the next
    token's first phoneme, where a stop's closure is silence. `edges` is
    {token: (first phoneme start, last phoneme end)}; `frame` one duration frame in the
    same seconds.
    """
    here, nxt = edges.get(ti), edges.get(ti + 1)
    if here is None or nxt is None:
        return None
    lo = float(here[1])
    hi = min(float(nxt[0]) + frame, float(nxt[1]))
    return (lo, hi) if hi > lo else None


def _splice_pauses(audio, points, sr: int, mult: float = 1.0):
    """Insert real silence into an utterance without re-synthesizing it.

    `points` is [(t, top_up, limit, dwell, lo, hi)], ascending: `t` the nominal end of the token or phone
    carrying the mark, `top_up` the mark's own share of the rest, `limit` the next token's start, `dwell`
    the mark's table rest (see `_rest_from`) and [lo, hi) the seconds the cut may go in (`_gap_window`).
    Shorter tuples have no window: the cut may only move forward of `t`, by SPLICE_REACH_MS, and never past
    `limit`. Returns `(audio, inserted)` with `inserted` [(time, seconds)] in the form `_shift` takes; with
    nothing to insert the input array itself comes back.

    A sentence is synthesized whole and the silence spliced in afterwards, so a comma keeps its continuation
    contour. The voice often runs through a comma without pausing, so the window may hold no silence: the
    cut goes where the voice is quietest (`_trough`), and each edge is ramped for the level found there
    (`_edge_ramp`). The silence measured around the cut says how much of the rest is already paid for; the
    target comes from the table (see `_rest_from`). Where the model rested longer than the target (a floored
    mark, `_rest_floor`, on a voice that also pauses there) the excess comes out of the middle of that
    silence, a negative entry in `inserted`.
    """
    import numpy as np

    pts = []
    for p in points:
        if float(p[1]) <= 0.0:
            continue
        pts.append(
            (
                float(p[0]),
                float(p[1]),
                float(p[2]) if len(p) > 2 else 0.0,
                float(p[3]) if len(p) > 3 and p[3] is not None else None,
                (float(p[4]), float(p[5])) if len(p) > 5 else None,
            )
        )
    if not pts:
        return audio, []
    pts.sort(key=lambda p: p[0])
    peak = float(np.max(np.abs(audio))) if audio.size else 0.0
    quiet = peak * SPLICE_QUIET
    reach = max(1, int(round(SPLICE_REACH_MS * sr / 1000.0)))
    fade = max(1, int(round(SPLICE_FADE_MS * sr / 1000.0)))

    pieces: list = []
    inserted: list = []
    prev = 0
    n_in = 0
    for t, secs, limit, dwell, win in pts:
        want = int(round(t * sr))
        if win is not None:
            lo, hi = int(round(win[0] * sr)), int(round(win[1] * sr))
        else:
            lo = want
            hi = min(int(round(limit * sr)), want + reach) if limit > 0.0 else want
        lo = max(lo, prev)
        cut = _trough(audio, lo, max(hi, lo), sr, quiet)
        have = _silence_around(audio, cut, quiet, sr, SPLICE_REST_REACH)
        pad = int(
            round(
                _rest_from(dwell if dwell is not None else have, secs, mult, have) * sr
            )
        )
        if pad <= 0:
            if dwell is None:
                continue
            # The model rested past the target: the excess comes out of the middle of its
            # silence, where the join is silence on both sides and a short ramp is enough.
            over = int(round((have - (dwell + secs) * mult) * sr))
            s0, s1 = _silent_span(audio, cut, quiet, sr, SPLICE_REST_REACH)
            s0 = max(s0, prev)
            if over <= 0 or s1 - s0 <= over + 2 * fade:
                continue
            at = s0 + (s1 - s0 - over) // 2
            seg = np.array(audio[prev:at], dtype=audio.dtype, copy=True)
            _ramp(seg, n_in, fade)
            pieces.append(seg)
            inserted.append((at / float(sr), -over / float(sr)))
            prev, n_in = at + over, fade
            continue
        seg = np.array(audio[prev:cut], dtype=audio.dtype, copy=True)
        out = _edge_ramp(_edge_level(audio, cut, True, sr), peak, SPLICE_RELEASE_MS, sr)
        _ramp(seg, n_in, out)
        pieces.append(seg)
        pieces.append(np.zeros(pad, dtype=audio.dtype))
        # Reported at the mark, clamped into [t, limit]: the shifted timings are token spans, and the pause
        # belongs after the mark's token and before the next. Clamped at both ends because a sample index
        # turned back into seconds can land a hair either side, which flips a comparison in `_shift`.
        at = max(t, cut / float(sr))
        if limit > 0.0:
            at = min(at, limit)
        inserted.append((at, pad / float(sr)))
        prev = cut
        n_in = _edge_ramp(
            _edge_level(audio, cut, False, sr), peak, SPLICE_ATTACK_MS, sr
        )
    if not inserted:
        return audio, []
    tail = np.array(audio[prev:], dtype=audio.dtype, copy=True)
    _ramp(tail, n_in, 0)
    pieces.append(tail)
    return np.concatenate(pieces), inserted


_warned_unaligned = False


# The ceiling on an unplanned rest, as a multiple of the median rest between two words in the same sentence,
# floored so a brisk sentence keeps room for a real one.
# Relative because pace, length_scale, the tone preset, the Arc resample and the checkpoint all move the
# whole distribution together; the sentence's own median tracks all of them.
# 3.0 is where the histogram of unmarked boundary rests over their sentence's median is empty (3036
# boundaries, 4 speakers, 3 paces): a mass thinning to nothing at 3.0, then 0.16% scattered out to 5.4x.
# Those are a second distribution, not a tail; the cut brings them back to 3.0, not to the median, so the
# rest stays indistinguishable from one the model meant.
# The floor is a safety net where the median over four or five boundaries is unreliable; it binds only at a
# brisk pace.
REST_RATIO = 3.0
REST_FLOOR = 0.12


def _trim_rests(audio, rests, sr: int):
    """Cut the unplanned pause out of the middle of a clause.

    Piper's duration predictor is stochastic and predicts durations for the blanks between phonemes too. A
    blank is also where the model pauses, so its duration is bimodal: a few tens of milliseconds, or a
    quarter second in the other mode, and enough draws land one mid-clause with no punctuation near it. It
    is not fixable at the source: the plan and the waveform come from one ONNX call, and the only dial that
    reaches it is `noise_w`, the rhythmic variety of the whole reading. Reading in the sentence rather than
    word by word (see WORD_BREAK) shortens the tail but cannot remove the mode.

    The plan says where, the waveform says how long. `rests` is [(t0, t1)] from the frame plan, for word
    boundaries carrying no punctuation (a marked one is `_splice_pauses`'s). The audible gap runs past the
    plan at both ends (a word tapers into a rest, and a phone beside the blank can render as silence), so
    the real silence around each boundary is measured and the ceiling applies to that.

    The excess comes out of the middle of the silence, so the ramp that prevents a click has silence to land
    on at both ends. Returns `(audio, removed)` with `removed` in the form `_shift` takes, the seconds
    negative. With nothing to cut the input array is returned untouched (byte-identical).
    """
    import numpy as np

    spans = [(float(a), float(b)) for a, b in rests if float(b) > float(a)]
    if not spans or audio.size == 0:
        return audio, []
    lens = sorted(b - a for a, b in spans)
    cap = max(REST_FLOOR, REST_RATIO * lens[len(lens) // 2])
    fade = max(1, int(round(SPLICE_FADE_MS * sr / 1000.0)))
    quiet = float(np.max(np.abs(audio))) * 0.02
    pieces: list = []
    removed: list = []
    prev = 0
    need_in = False
    for a, b in spans:
        mid = int(round(0.5 * (a + b) * sr))
        lo, hi = _silent_span(audio, mid, quiet, sr)
        lo = max(lo, prev)
        n = int(round(((hi - lo) / float(sr) - cap) * sr))
        if n <= 0 or hi - lo <= n + 2 * fade:
            continue
        at = lo + (hi - lo - n) // 2
        seg = np.array(audio[prev:at], dtype=audio.dtype, copy=True)
        _ramp(seg, fade if need_in else 0, fade)
        pieces.append(seg)
        removed.append((at / float(sr), -n / float(sr)))
        prev, need_in = at + n, True
    if not removed:
        return audio, []
    tail = np.array(audio[prev:], dtype=audio.dtype, copy=True)
    _ramp(tail, fade if need_in else 0, 0)
    pieces.append(tail)
    return np.concatenate(pieces), removed


def _silent_span(audio, at: int, thresh: float, sr: int, reach: float = 0.5) -> tuple:
    """(first, last+1) of the contiguous near-silence containing sample `at`.

    Walked outward from the point rather than measured between token spans (a span is the aligner's opinion,
    this is about the waveform). Bounded at `reach` seconds each way, half a second by default: past that a
    silence is the end of the utterance, not a dwell. `(at, at)`, an empty span, if `at` is not in silence.
    """
    import numpy as np

    if audio.size == 0 or thresh <= 0.0:
        return at, at
    span = int(reach * sr)
    lo = max(0, at - span)
    hi = min(audio.size, at + span)
    a = np.abs(audio[lo:hi])
    if a.size == 0:
        return at, at
    i = min(max(at - lo, 0), a.size - 1)
    if a[i] > thresh:
        return at, at
    loud = np.where(a > thresh)[0]
    left = loud[loud < i]
    right = loud[loud > i]
    start = int(left[-1]) + 1 if left.size else 0
    end = int(right[0]) if right.size else a.size
    return lo + start, lo + end


def _silence_around(
    audio, at: int, thresh: float, sr: int, reach: float = 0.5
) -> float:
    """Seconds of contiguous near-silence containing `at` - what the model rests here."""
    lo, hi = _silent_span(audio, at, thresh, sr, reach)
    return float(hi - lo) / sr


def _warn_unaligned(marks) -> None:
    """Say so, once, when a mid-sentence pause was asked for and cannot be placed.

    Splicing needs the duration predictor's spans to know where the mark ends. An unpatched voice has none
    (the same condition that costs the subtitles), and the pause would otherwise silently not happen.
    """
    global _warned_unaligned
    if _warned_unaligned or not marks:
        return
    _warned_unaligned = True
    print(
        "ghost/voice: no alignment output from this voice, so pauses after "
        + " ".join(sorted(set(marks)))
        + " cannot be placed (sentence pauses are unaffected)",
        file=sys.stderr,
    )


def _shift(t: float, inserted, inclusive: bool) -> float:
    """`t` moved later by every pause inserted before it.

    A span's start is inclusive (a pause landing exactly on it happened first) and its end is not (a pause
    landing exactly on the end belongs after the span, which puts the mark's own token in front of its own
    silence).

    A negative entry is silence taken out from `at` on: a time inside what was removed lands where the
    removal starts, a time after it moves back by all of it, and one exactly at `at` stays put either way.
    """
    add = 0.0
    for at, dur in inserted:
        if dur < 0.0:
            if at < t:
                add += max(dur, at - t)
        elif at < t or (inclusive and at <= t):
            add += dur
    return t + add


def _espeak_word(text: str) -> str:
    """A token as eSpeak should see it: an internal hyphen is a word boundary.

    A hyphen inside a word is the boundary between two words spelled as one ("ten-forty" is said "ten
    forty"). ghost keeps the hyphen to here (the karaoke line shows the source spelling; see
    TextNorm._expand_core), so this is the one place that turns the spelling back into a boundary.

    eSpeak returns the same phones either way and only the word space differs ("ten-forty" -> tˈɛnfˈɔːɹɾi,
    "ten forty" -> tˈɛn fˈɔːɹɾi), so no pronunciation changes. The model does not ignore the boundary: two
    primary stresses welded together is a shape its training data lacks, and en_US-libritts-high opens a
    hole in the middle of the word (longest near-silence inside "forty-second" 0.40 s glued, 0.07 s spaced;
    "twenty-five" 0.25 -> 0.07). The other installed voices do not. A compound eSpeak already reads with one
    primary ("re-enter") is unaffected.

    Only the ASCII hyphen, the only one that survives TextNorm (it folds typographic hyphens to it and an em
    dash to a comma). A token of nothing but dashes is returned untouched, since handing the phonemizer an
    empty string drops the item and misaligns every later word.
    """
    spoken = " ".join(text.replace("-", " ").split())
    return spoken or text.strip()


# Phoneme id stream shape, from piper1-gpl docs/ALIGNMENTS.md:
#   [BOS, PAD, id, PAD, id, PAD, ..., EOS]
BOS, EOS, PAD = 1, 2, 0

# Word-spaces prepended to every utterance so the model's onset ramp does not land on
# the first real word. Two, by measurement - see the table in _symbols.
LEAD_IN_SPACES = 2

# U+200B zero width space, written between the words of a sentence before it goes to eSpeak, so eSpeak reads
# the sentence (which is how it decides stress) yet yields a reading that can be cut into words.
# Word by word, eSpeak gives only citation forms, and a function word's carries a primary stress no reader
# would put there ("a" ˈeɪ, the letter, for ɐ; "in" ˈɪn for ɪn; "to" tuː for tə): a reading with every
# preposition stressed sounds jerky. Phonemizing the whole sentence welds words across boundaries ("not a"
# -> nˌɑːɾə) and ghost needs the phones of each word (karaoke, per-token timings, pause placement); a plain
# join loses that on 103 of 230 sentences.
# A zero-width space is a word boundary to eSpeak, has no phones of its own, and does not stop it analyzing
# the sentence. Still 6 of 230 sentences come back with a different piece count than words (2.6%) and fall
# back to the word-by-word path. A pipe behaves the same; a double bar disturbs the stresses.
WORD_BREAK = "\u200b"

# U+0329 combining vertical line below, the IPA "syllabic" mark eSpeak puts on a consonant carrying a
# syllable alone (American -ten/-tain: "written" /ɹˈɪʔn̩/, "certain", "gotten").
# Not every voice can spell it: four of the five installed carry 157-symbol maps that include it,
# en_US-libritts-high a 130-symbol map that does not, and dropping the mark leaves a glottal stop and a bare
# consonant with no second syllable (146 tokens across north-star).
# So substitute: a syllabic consonant is a schwa plus that consonant (eSpeak spells the un-glottalized
# members that way: "prison" /pɹˈɪzən/). Inserting the schwa before the base gives /ɹˈɪʔən/, which every
# voice can say.
SYLLABIC = "\u0329"
SCHWA = "\u0259"

# Commercially clean English voices only, verified MODEL_CARD by MODEL_CARD. Anything not on this list needs
# its card read before it is added.
VOICES: dict[str, dict] = {
    "en_US-ljspeech-medium": {
        "path": "en/en_US/ljspeech/medium/en_US-ljspeech-medium",
        "license": "Public domain (LJ Speech)",
        "chain": "trained from scratch",
        "speakers": 1,
        "notes": "Single speaker, small, the quickest thing to prove the pipeline.",
    },
    "en_US-libritts-high": {
        "path": "en/en_US/libritts/high/en_US-libritts-high",
        "license": "CC BY 4.0 (LibriTTS, openslr.org/60) - attribution required",
        "chain": "trained from scratch",
        "speakers": 904,
        "notes": "904 speakers under one checkpoint. The natural analog of the "
        "fishing game's genome: identity becomes a speaker id you can "
        "throw, catch and interpolate.",
    },
    "en_US-kristin-medium": {
        "path": "en/en_US/kristin/medium/en_US-kristin-medium",
        "license": "Public domain (LibriVox, ~11.5h)",
        "chain": "trained from scratch",
        "speakers": 1,
    },
    "en_US-norman-medium": {
        "path": "en/en_US/norman/medium/en_US-norman-medium",
        "license": "Public domain (LibriVox, ~15.5h)",
        "chain": "trained from scratch",
        "speakers": 1,
    },
    "en_US-john-medium": {
        "path": "en/en_US/john/medium/en_US-john-medium",
        "license": "Public domain (LibriVox, ~12.5h)",
        "chain": "fine-tuned from kristin (clean chain)",
        "speakers": 1,
    },
}

# Voices trained here (next/likeness.md, "Their own voice"): an actor's voice fine-tuned on this computer
# from a clean base, published by the Actor card as `<id>.onnx`, `<id>.onnx.json` and `<id>.voice.json`
# ({name, license, chain, actor}) in this folder under the voices' root. Listed beside the allowlist, never
# fetched.
TRAINED = "trained"


@register
class PiperBackend(Backend):
    name = "piper"
    # Samples a duration frame stands for. A model with another frame (kokoro.py) says its own, and the
    # token path reads the plan through it.
    hop = HOP_LENGTH
    # The two shapings of a word's edge before a rest: the trail (the word before it let go of: fade and
    # sag) and the lead (the next word's hiss quieted in a floored rest). A model that floors no rest
    # (kokoro.py) makes no lead.
    trails = True
    quiets_lead = True
    # How far the trail walks the next word's start back over sound (None: TRAIL_EARLY, read when made), and
    # whether its way back up may run on into the next word. A model whose corrected plan says where the
    # next word starts, and which holds a word into it at a comma (kokoro.py), walks back none and lets the
    # return run on.
    trail_early = None
    trail_through = False
    # What the noise adds to its level (level.py measures a voice with the noise off, so a level kept is the
    # same wherever measured): VITS samples on every render, and libritts-high speaks 1.14 times (speaker 0)
    # to 1.16 (speaker 4) louder than with none. A model that samples nothing (kokoro.py) says 1.
    level_noise = 1.14

    @classmethod
    def describe(cls) -> dict:
        d = super().describe()
        d.update(
            {
                "streaming": False,  # per-sentence today; sub-utterance is possible
                "phoneme_input": True,  # the point of this backend
                "duration_control": True,  # length_scale
                "pitch_control": False,  # VITS has no direct f0 handle
                "timings": True,  # exact, from the duration predictor
                "reference_audio": False,
                "singing": False,
            }
        )
        return d

    @classmethod
    def owns(cls, voice: str) -> bool:
        return voice in VOICES or cls._trained(voice) is not None

    @classmethod
    def _trained(cls, voice: str):
        """A voice trained here: its description ({name, license, chain, actor}), or None."""
        if not voice or "/" in voice or voice.startswith("."):
            return None
        d = cls._root() / TRAINED
        if not ((d / f"{voice}.onnx").exists() and (d / f"{voice}.onnx.json").exists()):
            return None
        try:
            meta = json.loads((d / f"{voice}.voice.json").read_text(encoding="utf-8"))
        except Exception:  # noqa: BLE001 - absent or half-written: named after its file
            meta = {}
        return meta if isinstance(meta, dict) else {}

    def __init__(self) -> None:
        try:
            import numpy  # noqa: F401
            import onnxruntime  # noqa: F401
        except ImportError as exc:
            raise BackendError(
                "onnxruntime/numpy are not installed in the voice environment"
            ) from exc
        import homographs  # ghost's own; HERE is on sys.path - see host.py
        import level
        import lexicon
        import vowel_probe

        self._sessions: dict[str, Any] = {}
        self._configs: dict[str, dict] = {}
        # Homograph resolution phonemizes through this backend's own word-level call, so a carrier reading
        # and a bare reading are comparable. Constructed once because its probe cache makes it free after
        # the first few sentences.
        self._homographs = homographs.Homographs(self._espeak)
        # A word eSpeak has to guess at (the reading marks it `rare`) is read as Wiktionary
        # has it, its full vowels stressed - see lexicon.py. Its cache sits beside the voices.
        self._lexicon = lexicon.Lexicon(self._espeak, self._root().parent / "lexicon")
        # Whether a checkpoint says the vowel its phoneme string names. The verdict is per voice and the
        # probe renders, so it is asked once and remembered, in memory and on disk beside the weights.
        self._vowels = vowel_probe.VowelProbe(
            self._espeak, self._render_symbols, self._root()
        )
        # Every voice at one level: each voice and speaker measured once and played at one gain,
        # kept beside its weights - see level.py.
        self._levels = level.Levels(self._root())
        # The frame plan of the most recent render - see `_render_symbols`.
        self._last_frames = None
        self._last_floor = None
        self._last_rests: list = []
        self._last_edges: dict = {}
        self._last_hisses: dict = {}

    # -- storage -----------------------------------------------------------

    @staticmethod
    def _root() -> Path:
        # Weights never live in the repo. This mirrors user:// on the Godot side and is created on demand.
        # Per platform, and it must agree with Deps.data_dir() on the Godot side: the Environment panel
        # counts .onnx files there.
        if sys.platform == "win32":
            base = Path(
                os.environ.get("LOCALAPPDATA") or (Path.home() / "AppData" / "Local")
            )
        elif sys.platform == "darwin":
            base = Path.home() / "Library" / "Application Support"
        else:
            base = Path(
                os.environ.get("XDG_DATA_HOME") or (Path.home() / ".local" / "share")
            )
        root = base / "ghost" / "voices" / "piper"
        root.mkdir(parents=True, exist_ok=True)
        return root

    def _files(self, voice: str) -> tuple[Path, Path]:
        root = self._root()
        if voice not in VOICES and self._trained(voice) is not None:
            root = root / TRAINED
        return root / f"{voice}.onnx", root / f"{voice}.onnx.json"

    def voices(self) -> list[dict]:
        out = []
        trained = self._root() / TRAINED
        for onnx in sorted(trained.glob("*.onnx")) if trained.is_dir() else []:
            vid = onnx.name[: -len(".onnx")]
            meta = self._trained(vid)
            if meta is None:
                continue
            out.append(
                {
                    "id": vid,
                    "name": str(meta.get("name", vid)),
                    "backend": self.name,
                    "license": str(meta.get("license", "")),
                    "derivation": str(meta.get("chain", "")),
                    "speakers": 1,
                    "installed": True,
                    "notes": str(meta.get("notes", "")),
                    "actor": str(meta.get("actor", "")),
                }
            )
        for vid, meta in VOICES.items():
            onnx, cfg = self._files(vid)
            out.append(
                {
                    "id": vid,
                    "name": vid.replace("en_US-", "").replace("-", " "),
                    "backend": self.name,
                    "license": meta["license"],
                    "derivation": meta["chain"],
                    "speakers": meta["speakers"],
                    "installed": onnx.exists() and cfg.exists(),
                    "notes": meta.get("notes", ""),
                }
            )
        return out

    def ensure(self, voice: str) -> dict:
        if voice not in VOICES and self._trained(voice) is not None:
            return {"voice": voice, "installed": True, "downloaded": False}
        if voice not in VOICES:
            raise BackendError(f"unknown or non-allowlisted voice '{voice}'")
        onnx, cfg = self._files(voice)
        if onnx.exists() and cfg.exists():
            return {"voice": voice, "installed": True, "downloaded": False}
        base = f"{HF_BASE}/{VOICES[voice]['path']}"
        for url, dest in ((f"{base}.onnx", onnx), (f"{base}.onnx.json", cfg)):
            tmp = dest.with_suffix(dest.suffix + ".part")
            # Progress for the model only: its few-KB config would read as the bar starting over.
            hook = _reporter(f"voice {voice}") if dest is onnx else None
            try:
                urllib.request.urlretrieve(url, tmp, hook)
            except Exception as exc:  # noqa: BLE001
                tmp.unlink(missing_ok=True)
                report(
                    f"voice {voice}",
                    finished=True,
                    error=f"could not fetch {url}: {exc}",
                )
                raise BackendError(f"could not fetch {url}: {exc}") from exc
            tmp.replace(dest)  # atomic: a reader sees whole file or none
        report(f"voice {voice}", finished=True)
        return {
            "voice": voice,
            "installed": True,
            "downloaded": True,
            "bytes": onnx.stat().st_size + cfg.stat().st_size,
        }

    # -- model -------------------------------------------------------------

    def _load(self, voice: str):
        if voice in self._sessions:
            return self._sessions[voice], self._configs[voice]
        self.ensure(voice)
        import onnxruntime as ort

        onnx, cfgp = self._files(voice)
        self._ensure_patched(onnx)
        cfg = json.loads(cfgp.read_text(encoding="utf-8"))
        opts = ort.SessionOptions()
        opts.log_severity_level = 3  # the protocol owns stdout
        sess = ort.InferenceSession(
            str(onnx), sess_options=opts, providers=["CPUExecutionProvider"]
        )
        self._sessions[voice] = sess
        self._configs[voice] = cfg
        # Ask this checkpoint whether it says the vowel its phoneme string names (en_US-libritts-high
        # renders a word-initial `ɹˈiːd` with the vowel of `rid`; see vowel_probe.py). Here rather than in
        # `_run` because it is a property of the weights, so once per load, and it renders, so it must not
        # happen inside a render. On the cold path only, it never touches a session a caller supplied: the
        # alignment tests seed `_sessions` with a stand-in whose phoneme map allocates ids on lookup, and
        # probing it would move every id under test.
        self._vowels.measure(
            voice, cfg, sess, str(cfg.get("espeak", {}).get("voice", "en-us"))
        )
        return sess, cfg

    @staticmethod
    def _ensure_patched(onnx: Path) -> None:
        """Expose the duration plan and let it be floored and scaled, once, on first load of a voice.

        Stock Piper graphs return audio only; without the duration tensor there are no phoneme or word times
        and no subtitles. Two optional inputs are added: REST_FLOOR_INPUT (frames per id, default none), a
        floor the plan may not fall below, between the duration predictor's ceiling and everything that
        reads it (how a mark gets a rest the model renders itself, `_rest_floor`); and DUR_SCALE_INPUT (a
        multiplier per id, default 1) on the planned frames after the Ceil and before the floor (how a word
        is leaned on, `EMPHASIS`). Unfed, the graph computes what it always did. Each is added on its own,
        so a voice patched before one existed gets the missing one.

        Patching happens where a voice is first used. Idempotent and cheap (one session open; a graph
        carrying both is left alone), and the patched graph is opened before it replaces the file, so one
        that will not load is never written.
        """
        import onnxruntime as ort

        opts = ort.SessionOptions()
        opts.log_severity_level = 3
        probe = ort.InferenceSession(
            str(onnx), sess_options=opts, providers=["CPUExecutionProvider"]
        )
        aligned = len(probe.get_outputs()) > 1
        inputs = {i.name for i in probe.get_overridable_initializers()}
        floored = REST_FLOOR_INPUT in inputs
        scaled = DUR_SCALE_INPUT in inputs
        del probe
        if aligned and floored and scaled:
            return
        try:
            import numpy as np
            import onnx as onnx_mod
            from onnx import helper, numpy_helper
        except ImportError:
            # no `onnx` package: synthesis still works, subtitles (or the floor) do not
            print(
                f"ghost/voice: {onnx.name} is unpatched and the `onnx` package is "
                "missing - "
                + (
                    "subtitles unavailable"
                    if not aligned
                    else "no rest floor at marks or emphasis"
                ),
                file=sys.stderr,
            )
            return
        model = onnx_mod.load(str(onnx))
        graph = model.graph
        at = [i for i, n in enumerate(graph.node) if n.op_type == "Ceil"]
        if len(at) != 1:
            print(
                f"ghost/voice: {onnx.name} has {len(at)} Ceil nodes, "
                "expected 1 - not patching",
                file=sys.stderr,
            )
            return
        ceil = graph.node[at[0]]
        tensor = ceil.output[0]
        if not scaled:
            # A Mul after the Ceil, taking the name the Ceil gave its output, so everything downstream (the
            # floor's Max, the path, the alignment output) reads the scaled plan. After rather than before
            # because most of a syllable's ids are predicted under one frame and `ceil(d * 1.3)` lands on
            # the same whole frame (a stretch before the Ceil moved a stressed word by 0 to 30 ms). The path
            # is a mask against the plan's running sum, so fractional frames are taken as they are.
            out = ceil.output[0]
            ceil.output[0] = out + "_unscaled"
            graph.node.insert(
                at[0] + 1,
                helper.make_node(
                    "Mul",
                    [out + "_unscaled", DUR_SCALE_INPUT],
                    [out],
                    name="ghost_dur_scale",
                ),
            )
            graph.initializer.append(
                numpy_helper.from_array(np.ones(1, np.float32), DUR_SCALE_INPUT)
            )
            graph.input.append(
                helper.make_tensor_value_info(
                    DUR_SCALE_INPUT, onnx_mod.TensorProto.FLOAT, None
                )
            )
        if not aligned:
            graph.output.append(
                helper.make_tensor_value_info(tensor, onnx_mod.TensorProto.FLOAT, None)
            )
        if not floored:
            # Whatever now produces the plan (the Ceil, or the scale after it) is renamed and a Max takes
            # its old name, so the graph's consumers and the alignment output read the floored plan.
            # One-dimensional, so it broadcasts along the ids whatever the plan's rank.
            planned = tensor + "_planned"
            k = next(i for i, n in enumerate(graph.node) if tensor in n.output)
            graph.node[k].output[0] = planned
            graph.node.insert(
                k + 1,
                helper.make_node(
                    "Max",
                    [planned, REST_FLOOR_INPUT],
                    [tensor],
                    name="ghost_rest_floor",
                ),
            )
            graph.initializer.append(
                numpy_helper.from_array(np.zeros(1, np.float32), REST_FLOOR_INPUT)
            )
            graph.input.append(
                helper.make_tensor_value_info(
                    REST_FLOOR_INPUT, onnx_mod.TensorProto.FLOAT, None
                )
            )
        data = model.SerializeToString()
        ort.InferenceSession(
            data, sess_options=opts, providers=["CPUExecutionProvider"]
        )
        tmp = onnx.with_suffix(onnx.suffix + ".part")
        tmp.write_bytes(data)
        tmp.replace(onnx)  # atomic: a reader sees whole graph or old graph
        print(f"ghost/voice: patched {onnx.name}", file=sys.stderr)

    # -- synthesis ---------------------------------------------------------

    # -- phonemization --------------------------------------------------

    _espeak_ready = False
    _warned_symbols: set = set()

    @classmethod
    def _espeak(cls, words: list[str], voice: str = "en-us") -> list[str]:
        """eSpeak's IPA for a list of words, in the voice's own eSpeak language.

        Each item is its own utterance, so what an item contains is what eSpeak reads. `_in_sentence` hands
        it a whole sentence with zero-width breaks (the normal path); the word-by-word batch is the fallback
        for a sentence eSpeak runs together anyway, and `homographs.py` hands it carrier phrases.

        The language comes from the voice config, not the voice's name: en_US-ljspeech-medium declares
        `espeak.voice = "en"`, which eSpeak resolves to British English, so the model was trained on RP
        symbols despite its name. Hardcoding "en-us" feeds it æ, ʌ, ɑː and oʊ where it expects a, ɒ, ɒ and
        əʊ ("lamp" comes out "lump").
        """
        if not cls._espeak_ready:
            try:
                import espeakng_loader
                from phonemizer.backend.espeak.wrapper import EspeakWrapper

                EspeakWrapper.set_library(espeakng_loader.get_library_path())
                EspeakWrapper.set_data_path(espeakng_loader.get_data_path())
            except ImportError as exc:
                raise BackendError(
                    'eSpeak phonemizer unavailable; set phonemizer="ghost" to '
                    "use ghost's own ARPAbet front end instead"
                ) from exc
            cls._espeak_ready = True
        from phonemizer import phonemize
        from phonemizer.separator import Separator

        # phonemizer validates against its own language list, which lacks eSpeak's bare "en" (British in
        # eSpeak, as read from the config).
        lang = {"en": "en-gb", "en-uk": "en-gb"}.get(voice, voice)
        # Each item of `words` is its own utterance: a list is a batch, not a sentence. One word per item is
        # the isolated reading, which loses the homograph and the stress (eSpeak reads "live" as laɪv alone
        # and lɪv in "where they live", and stresses every function word shown alone). The separator makes a
        # multi-word item splittable again, which is how both `_in_sentence` and homographs.py get a reading
        # back per word with the syntax attached.
        out = phonemize(
            words,
            language=lang,
            backend="espeak",
            strip=True,
            with_stress=True,
            njobs=1,
            separator=Separator(word=" ", phone=""),
        )
        return [o.strip() for o in out]

    def _in_sentence(
        self, tokens: list, need: list, espeak_voice: str
    ) -> dict[int, str]:
        """eSpeak's reading of each word as it sits in this sentence.

        Returns {token index: IPA} for every index in `need`, or {} if the reading could not be cut back
        into words, in which case the caller falls back to the word-by-word batch. See WORD_BREAK.

        Every token contributes its spelling to the sentence, including those not in `need`: a word with an
        authored override or a homograph reading still conditions its neighbors' stress. Only the pieces for
        `need` are read back.

        A token may be more than one eSpeak word (`_espeak_word` turns an internal hyphen into a boundary),
        so the pieces are taken by count and rejoined with the space the hyphen asked for.

        A rest the caller splices in ends a phrase (`REST_AFTER_FLOOR`): the sentence is read in pieces
        broken after each word that has one, so that word is read as the end of what is said ("to" before a
        hesitation is tuː, not tə).
        """
        spoken: list[str] = []
        counts: dict[int, tuple[int, int]] = {}
        ends: list[int] = []  # where in `spoken` each phrase but the last ends
        for i, t in enumerate(tokens):
            text = str(t.get("text", ""))
            if not text.strip():
                continue
            w = _espeak_word(text)
            parts = w.split()
            if not parts:
                continue
            counts[i] = (len(spoken), len(parts))
            spoken.extend(parts)
            if _rest_after(t) > 0.0:
                ends.append(len(spoken))
        if not spoken:
            return {}
        cuts = [0] + [e for e in ends if e < len(spoken)] + [len(spoken)]
        phrases = [(" %s " % WORD_BREAK).join(spoken[a:b]) for a, b in zip(cuts, cuts[1:])]
        try:
            read = self._espeak(phrases, espeak_voice) or []
            pieces = [str(r).split() for r in read]
            # a phrase that came back with another count of words cannot be laid on its own
            if len(pieces) != len(phrases) or any(
                len(p) != b - a for p, a, b in zip(pieces, cuts, cuts[1:])
            ):
                pieces = [[]]
            got = [w for p in pieces for w in p]
        except BackendError:
            raise
        except (
            Exception
        ) as exc:  # noqa: BLE001 - a phonemizer fault must not lose audio
            print(
                "ghost/voice: sentence-level phonemization failed (%s); "
                "falling back to word by word" % exc,
                file=sys.stderr,
            )
            return {}
        if len(got) != len(spoken):
            # eSpeak still ran the words together somewhere, so there is no honest way to say which phones
            # belong to which word. The isolated batch is wrong about stress but right about alignment,
            # which this file cannot trade away.
            self._warn_welded()
            return {}
        out: dict[int, str] = {}
        for i in need:
            at = counts.get(i)
            if at is None:
                return {}
            start, n = at
            out[i] = " ".join(got[start : start + n])
        return out

    def _warn_welded(self) -> None:
        """Once per process: the sentence reading could not be cut into words."""
        if "\u200b" in self._warned_symbols:
            return
        self._warned_symbols.add("\u200b")
        print(
            "ghost/voice: eSpeak ran words together in a sentence despite the word "
            "break; those sentences are read word by word instead (about 3% of them)",
            file=sys.stderr,
        )

    def _symbols(
        self,
        tokens: list,
        phonemizer: str,
        espeak_voice: str = "en-us",
        voice: str = "",
    ) -> list:
        """(codepoint, token index) pairs for a chunk.

        A token carries its source text AND, optionally, ghost's own ARPAbet.
        Inline [K AE T] overrides arrive with `arpa` set and ALWAYS win - that
        is the whole point of the override, and it is how invented proper nouns
        stay pronounceable whichever phonemizer is in use.

        A token may also carry `ipa`, which is eSpeak's OWN reading of that word
        under the part of speech it was tagged with (homographs.py). It sits
        below `arpa` - the author still outranks it - and above the word-by-word
        transcription it exists to correct.

        Whichever of the three a reading comes from, it is written out in the spelling
        THIS checkpoint was measured to render correctly before it leaves here (see
        vowel_probe.py). That applies to the authored override too, and deliberately:
        the repair does not change which vowel is named, only how it is spelled for a
        model that mis-renders the short spelling, so an author who writes [R IY1 D]
        wants the same repair an eSpeak reading gets. `voice` empty - every caller
        that is not a real render - leaves every reading untouched.
        """
        import arpabet

        def written(ipa: str) -> str:
            return self._vowels.repair_for(voice, ipa) if voice else ipa

        # A whitespace-only token must never reach the batch, and the result is checked: phonemizer drops an
        # empty or whitespace-only input instead of returning "" ([" ", "the"] comes back as ["ðə"]), and
        # the zip below would then pair every remaining word with its neighbor's phonemes and let the last
        # fall through to ghost's ARPAbet, a homograph included.
        need = [
            i
            for i, t in enumerate(tokens)
            if not t.get("arpa") and not t.get("ipa") and str(t.get("text", "")).strip()
        ]
        espoke: dict[int, str] = {}
        if need and phonemizer == "espeak":
            espoke = self._in_sentence(tokens, need, espeak_voice)
        if need and phonemizer == "espeak" and not espoke:
            words = [_espeak_word(str(tokens[i]["text"])) for i in need]
            got = self._espeak(words, espeak_voice)
            if len(got) != len(words):
                # Alignment is not recoverable from a short batch (which one was dropped is unknown), so
                # redo it one word at a time: slower, but a wrong-by-one sentence is not worth one call.
                print(
                    "ghost/voice: phonemizer returned %d results for %d words; "
                    "re-running individually to keep alignment"
                    % (len(got), len(words)),
                    file=sys.stderr,
                )
                got = [(self._espeak([w], espeak_voice) or [""])[0] for w in words]
            espoke = dict(zip(need, got))

        # Lead-in: the model's onset ramp lands on the first phoneme, so the opening word comes out short
        # and weak. Word-spaces ahead of the first token give the onset somewhere to happen. Two reach
        # parity with the same word mid-sentence on both axes (initial "the" over mid, at 0, 1, 2, 3 spaces:
        # duration 0.70, 0.91, 1.06, 1.28; amplitude 1.30, 0.67, 0.95, 1.18); three overshoot and drawl.
        # Cost: a few tens of ms of silence at the head, which the chunk seam provides anyway.
        out: list = [(" ", 0)] * LEAD_IN_SPACES
        for i, t in enumerate(tokens):
            if t.get("arpa"):
                got = "".join(
                    ch for ch, _ in arpabet.to_symbols([str(x) for x in t["arpa"]])
                )
                for ch in written(got):
                    out.append((ch, i))
            elif t.get("ipa"):
                for ch in written(self._dictionary_reading(str(t["ipa"]), t)):
                    out.append((ch, i))
            elif i in espoke:
                for ch in written(self._dictionary_reading(espoke[i], t)):
                    out.append((ch, i))
            elif t.get("text"):
                # no eSpeak: fall back to ghost's ARPAbet if it sent any
                got = "".join(
                    ch
                    for ch, _ in arpabet.to_symbols(
                        [str(x) for x in t.get("fallback", [])]
                    )
                )
                for ch in written(got):
                    out.append((ch, i))
            for ch in str(t.get("punct", "")):
                out.append((ch, i))
            out.append((" ", i))
        return out

    def synthesize(
        self,
        text: str,
        voice: str,
        out_path: str,
        params: dict[str, Any],
        phonemes: Any = None,
    ) -> dict:
        """Synthesize sentence by sentence, joined with real silence.

        A whole paragraph as one utterance comes back rushed: the model has no reason to breathe at a full
        stop it is in the middle of. Splitting also keeps each inference short, which makes streaming
        possible.
        """
        import numpy as np

        sess, cfg = self._load(voice)
        pmap: dict = cfg["phoneme_id_map"]
        sample_rate = int(cfg["audio"]["sample_rate"])

        tokens = params.get("tokens")
        if tokens:
            return self._synth_tokens(list(tokens), voice, out_path, self._leveled(voice, params, cfg, sess),
                                      cfg, sess)
        sentences = _split_sentences(list(phonemes))
        if len(sentences) > 1:
            chunks, phones_all, cursor = [], [], 0.0
            for si, sent in enumerate(sentences):
                sub = self.synthesize(
                    text,
                    voice,
                    out_path + f".s{si}",
                    {**params, "_no_split": True},
                    sent,
                )
                import wave as _w

                with _w.open(sub["wav"]) as fh:
                    import numpy as _np

                    a = (
                        _np.frombuffer(fh.readframes(fh.getnframes()), "<i2").astype(
                            _np.float32
                        )
                        / 32768.0
                    )
                Path(sub["wav"]).unlink(missing_ok=True)
                for ph in sub.get("phones", []):
                    phones_all.append(
                        {
                            "p": ph["p"],
                            "t0": round(ph["t0"] + cursor, 4),
                            "t1": round(ph["t1"] + cursor, 4),
                        }
                    )
                chunks.append(a)
                cursor += len(a) / sub["sample_rate"]
                if si < len(sentences) - 1:
                    import numpy as _np

                    # the mark this sentence ended on decides its own pause
                    gap = _gap_for(str(sent[-1]).strip() if sent else "", params)
                    pad = int(round(gap * sub["sample_rate"]))
                    if pad > 0:
                        chunks.append(_np.zeros(pad, dtype=_np.float32))
                        cursor += pad / sub["sample_rate"]
            import numpy as _np

            joined = (
                _np.concatenate(chunks) if chunks else _np.zeros(1, dtype=_np.float32)
            )
            sr = int(cfg["audio"]["sample_rate"])
            self._write_wav(out_path, joined, sr)
            return {
                "wav": out_path,
                "sample_rate": sr,
                "duration": float(joined.size) / sr,
                "phones": phones_all,
                "aligned": bool(phones_all),
                "sentences": len(sentences),
            }

        if not phonemes:
            raise BackendError(
                "this backend takes phonemes, not text: ghost's own G2P supplies "
                "them, which is what keeps eSpeak-NG (GPL) out of the build"
            )

        # [BOS, PAD, id, PAD, ..., EOS]. Track which ids came from which input phoneme so the durations can
        # be folded back into words. ghost sends its own ARPAbet: translating here keeps the [K AE T]
        # override working on this path and eSpeak-NG out of the build (see arpabet.py).
        import arpabet

        symbols = arpabet.to_symbols(list(phonemes))

        # [BOS, PAD, id, PAD, id, PAD, ..., EOS]: the pad comes before each id and after the last, per
        # piper1-gpl docs/ALIGNMENTS.md (emitting it after drops the pad following BOS and shifts the stream
        # by one). ghost's ARPAbet carries no syllabic mark, so this is a no-op here, kept for symmetry with
        # the eSpeak path.
        symbols, _folded = self._fold_syllabic(symbols, pmap)
        ids: list[int] = [BOS]
        owner: list[int] = [-1]
        missing: list[str] = []
        for sym, src in symbols:
            mapped = pmap.get(sym)
            if mapped is None:
                missing.append(sym)
                continue
            ids.append(PAD)
            owner.append(src)
            for m in mapped:
                ids.append(int(m))
                owner.append(src)
        ids.append(PAD)
        owner.append(-1)
        ids.append(EOS)
        owner.append(-1)

        if missing:
            # Loud, not silent: a symbol absent from phoneme_id_map is dropped by the encoder without
            # complaint.
            raise BackendError(
                "phonemes not in this voice's phoneme_id_map: "
                + " ".join(sorted(set(missing))[:12])
                + "  (regenerate the ARPAbet mapping against this voice)"
            )

        inf = cfg.get("inference", {})
        feeds = {
            "input": np.array([ids], dtype=np.int64),
            "input_lengths": np.array([len(ids)], dtype=np.int64),
            "scales": np.array(
                [
                    float(params.get("noise_scale", inf.get("noise_scale", 0.667))),
                    float(params.get("length_scale", inf.get("length_scale", 1.0))),
                    float(params.get("noise_w", inf.get("noise_w", 0.333))),
                ],
                dtype=np.float32,
            ),
        }
        if int(cfg.get("num_speakers", 1)) > 1:
            feeds["sid"] = np.array([int(params.get("speaker", 0))], dtype=np.int64)

        outputs = sess.run(None, feeds)
        audio = np.asarray(outputs[0]).squeeze().astype(np.float32)

        phone_times = []
        if len(outputs) > 1:
            phone_times = self._durations(outputs[1], owner, phonemes, sample_rate)

        # Mid-sentence marks arrive on this path as phones of their own (see arpabet.PUNCT_PASSTHROUGH), so
        # each has a span to splice after. Needs the durations; without them there is no place to cut, as
        # there are no subtitles either.
        points, unplaceable = [], []
        for i, sym in enumerate(phonemes):
            mark = str(sym).strip()
            if mark in SENTENCE_END or _pause_for(mark, params) <= 0.0:
                continue  # . ! ? are the gap between sentences, above
            if i < len(phone_times):
                nxt = phone_times[i + 1] if i + 1 < len(phone_times) else None
                # the top-up and the table dwell, like the token path - the splicer
                # measures what is already there and tops it up to the target - and the
                # window: the mark's own frames to one frame into the phone after it
                point = (
                    float(phone_times[i]["t1"]),
                    _top_up(mark, params),
                    float(nxt["t0"]) if nxt is not None else 0.0,
                    _dwell_for(mark),
                )
                if nxt is not None:
                    hi = min(
                        float(nxt["t0"]) + HOP_LENGTH / float(sample_rate),
                        float(nxt["t1"]),
                    )
                    point += (float(phone_times[i]["t0"]), hi)
                points.append(point)
            else:
                unplaceable.append(mark)
        _warn_unaligned(unplaceable)
        if points:
            audio, inserted = _splice_pauses(
                audio, points, sample_rate, _pause_multiplier(params)
            )
            for ph in phone_times:
                ph["t0"] = round(_shift(ph["t0"], inserted, True), 4)
                ph["t1"] = round(_shift(ph["t1"], inserted, False), 4)

        self._write_wav(out_path, audio, sample_rate)
        return {
            "wav": out_path,
            "sample_rate": sample_rate,
            "duration": float(audio.size) / sample_rate,
            "phones": phone_times,
            "aligned": bool(phone_times),
        }

    def _synth_tokens(
        self, tokens: list, voice: str, out_path: str, params: dict, cfg: dict, sess
    ) -> dict:
        """Token path: sentence-split, phonemize, synthesize, join.

        Tokens carry their own text, so the sentence split happens here on the punctuation ghost already
        parsed, and the phonemizer sees whole words with their boundaries intact.

        Two kinds of pause, one table. A sentence-final mark ends a group and its pause is the silence
        between groups. Every other mark (, ; :) stays inside its group: the sentence is synthesized whole
        and the silence spliced in afterwards, so a comma never gets a sentence end's falling intonation.
        Both are `PAUSE_AFTER` seconds times `pause_scale`.
        """
        import numpy as np

        phonemizer = str(params.get("phonemizer", "espeak"))
        groups: list[list] = []
        cur: list = []
        for t in tokens:
            cur.append(t)
            if str(t.get("punct", "")) in SENTENCE_END:
                groups.append(cur)
                cur = []
        if cur:
            groups.append(cur)

        sr = int(cfg["audio"]["sample_rate"])
        chunks: list = []
        times: list = []
        # Every sound with its time ({p, t0, t1, w}, `w` the token it is of): moved by everything the spans
        # are moved by (the resample, the trimmed rests, the spliced pauses), so a mouth that follows them
        # says what the take says.
        phones: list = []
        cursor = 0.0
        base = 0
        plan = _discourse_plan(groups, params)
        for gi, group in enumerate(groups):
            # The sentence's own prosody. A pitch move is bought as the Tone shift buys one: render `pr`
            # times slower, play back `pr` times faster, so the sentence lands at its nominal duration and a
            # higher register.
            step = plan[gi]
            pr = 2.0 ** (float(step["semis"]) / 12.0)
            gp = dict(params)
            base_ls = float(
                params.get(
                    "length_scale", cfg.get("inference", {}).get("length_scale", 1.0)
                )
            )
            # ...and ASK for more than `pr`, because part of a sentence does not scale and
            # the playback divides all of it. See `_pitch_length` / `_nominal_seconds`.
            gp["length_scale"] = base_ls * _pitch_length(pr) / float(step["rate"])
            gp["noise_w"] = float(
                params.get("noise_w", cfg.get("inference", {}).get("noise_w", 0.333))
            ) * float(step["noise_w_mul"])
            audio, per_token = self._run(group, voice, gp, cfg, sess, phonemizer)
            # every voice at one level, as it comes out of the model (level.py)
            audio = audio * float(params.get("level_gain", 1.0))
            said = [dict(ph) for ph in getattr(self, "_last_phones", [])]
            # The frame plan's word-boundary rests and each word's sounds, before anything
            # resamples them.
            group_rests = list(self._last_rests)
            edges = dict(self._last_edges)
            frame = self.hop / float(sr)
            audio = _emphasize(audio, edges, group, sr)
            if self.quiets_lead:
                audio = _quiet_lead(audio, edges, group, params, sr)
            if self.trails:
                audio = _trail(audio, edges, group, params, sr, dict(self._last_hisses),
                               walk_back=self.trail_early, through=self.trail_through)
            # Say which words came back without a span. ghost keeps them in the karaoke line either way (it
            # interpolates their timing; see GenerativeEditor._bridge_words), but a token the aligner cannot
            # place means the phoneme stream carries nothing for that word, so it is likely not spoken
            # either.
            unplaced = [
                str(t.get("text", ""))
                for ti, t in enumerate(group)
                if ti not in per_token and str(t.get("text", "")).strip()
            ]
            if unplaced:
                print(
                    "ghost/voice: no alignment for %d of %d tokens in this sentence: %s"
                    % (len(unplaced), len(group), " ".join(unplaced[:8])),
                    file=sys.stderr,
                )
            audio = _effort(audio, sr, float(step["tilt"]), float(step["gain_db"]))
            # The source, if this reading wants a different one. Before the pitch move because a whisper has
            # no pitch to move and the other order spends the work twice.
            audio = _whisper(audio, sr, float(params.get("whisper", 0.0)))
            audio = _muffle(audio, sr, float(params.get("muffle", 0.0)))
            if abs(pr - 1.0) > 1e-4:
                # The ratio is measured, not assumed: playing back by exactly `pr` tilts the pace across a
                # paragraph; playing back by the ratio between what this sentence rendered to and what it
                # would have unshifted lands the timing exactly, whatever the voice did with the length
                # scale. The pitch then moves by that measured ratio, a few percent off what was asked,
                # which nobody can hear.
                nominal = self._nominal(
                    self._last_frames, _pitch_length(pr), sr, self._last_floor
                )
                played = float(audio.size) / float(sr)
                ratio = pr
                if nominal > 0.05 and played > 0.05:
                    ratio = played / nominal
                    # A guard, not a tuning: a mis-shaped frame plan must not halve or double a sentence.
                    if ratio < pr * 0.6 or ratio > pr * 1.6:
                        ratio = pr
                pr = ratio
                shifted = _resample(audio, pr)
                # ...and the filter held still while the source moves (default on): the arc changes
                # register, and a register change must not change how big the speaker is. `formant_lock` = 0
                # disables it, for the gate's A/B.
                if float(params.get("formant_lock", 1.0)) > 0.5:
                    shifted = _restore_formants(shifted, audio, pr, sr)
                audio = shifted
                # the alignment was measured before the resample, so it moves with it
                per_token = {k: (v[0] / pr, v[1] / pr) for k, v in per_token.items()}
                for ph in said:
                    ph["t0"], ph["t1"] = ph["t0"] / pr, ph["t1"] / pr
                group_rests = [(a / pr, b / pr, w) for a, b, w in group_rests]
                edges = {k: (a / pr, b / pr) for k, (a, b) in edges.items()}
                frame /= pr
            # A rest nobody asked for, shortened before the ones that were asked for are put in. Unmarked
            # boundaries only: a mark's rest belongs to `_splice_pauses` and the Pause dial, and so does a
            # rest the caller splices in after a word.
            audio, cut = _trim_rests(
                audio,
                [
                    (a, b)
                    for a, b, w in group_rests
                    if w < len(group)
                    and not str(group[w].get("punct", ""))
                    and _rest_after(group[w]) <= 0.0
                ],
                sr,
            )
            if cut:
                per_token = {
                    k: (
                        max(0.0, _shift(v[0], cut, True)),
                        max(0.0, _shift(v[1], cut, False)),
                    )
                    for k, v in per_token.items()
                }
                per_token = {k: (a, max(a, b)) for k, (a, b) in per_token.items()}
                for ph in said:
                    a0 = max(0.0, _shift(ph["t0"], cut, True))
                    ph["t0"], ph["t1"] = a0, max(a0, _shift(ph["t1"], cut, False))
                edges = {
                    k: (_shift(a, cut, True), _shift(b, cut, False))
                    for k, (a, b) in edges.items()
                }
            # mid-sentence marks: splice their silence into this group's audio
            points, unplaceable = [], []
            for ti, tok in enumerate(group):
                mark = str(tok.get("punct", ""))
                if mark in SENTENCE_END or _pause_for(mark, params) <= 0.0:
                    continue  # . ! ? are the gap between groups, below
                if ti in per_token:
                    nxt = per_token.get(ti + 1)
                    # (mark's token end, top-up, next token start, the table's dwell): the splicer measures
                    # what the model already rests there and tops it up to the target (see `_rest_from`; the
                    # mark's share is `_tail_share`'s). The window is where the cut may go.
                    share = _tail_share(group, ti)
                    point = (
                        float(per_token[ti][1]),
                        _top_up(mark, params) * share,
                        float(nxt[0]) if nxt is not None else 0.0,
                        _dwell_for(mark) * share,
                    )
                    win = self._gap(edges, ti, frame)
                    points.append(point + win if win is not None else point)
                else:
                    unplaceable.append(mark)
            _warn_unaligned(unplaceable)
            audio, inserted = _splice_pauses(
                audio, points, sr, _pause_multiplier(params)
            )
            # Where a rest after each word goes: ghost splices its hesitations and action holds there
            # (Splice.chunk). The same window as a mark's, searched in the finished audio: after a mark or a
            # floored rest (`REST_AFTER_FLOOR`) it is the middle of the silence already there, and where no
            # mark rests it is the caller's rest begun, said on the row as `rested`.
            rests, rested = {}, {}
            quiet = SPLICE_QUIET * float(np.max(np.abs(audio))) if audio.size else 0.0
            for ti in per_token:
                win = self._gap(edges, ti, frame)
                if win is None:
                    continue
                lo = int(round(_shift(win[0], inserted, False) * sr))
                hi = int(round(_shift(win[1], inserted, True) * sr))
                at = _trough(audio, lo, hi, sr, quiet)
                rests[ti] = at / float(sr)
                after = _rest_after(group[ti])
                if after > 0.0 and PAUSE_AFTER.get(str(group[ti].get("punct", "")), 0.0) <= 0.0:
                    rested[ti] = min(after, _silence_around(audio, at, quiet, sr))
            gap = None
            if gi < len(groups) - 1:
                gap = _gap_for(str(group[-1].get("punct", "")) if group else "", params)
            for ph in said:
                phones.append({"p": ph["p"], "w": base + int(ph["w"]),
                               "t0": round(_shift(float(ph["t0"]), inserted, True) + cursor, 4),
                               "t1": round(_shift(float(ph["t1"]), inserted, False) + cursor, 4)})
            for ti, span in per_token.items():
                # float(): numpy scalars are not JSON-serializable and the
                # protocol is JSON
                row = {
                    "index": base + ti,
                    "t0": round(_shift(float(span[0]), inserted, True) + cursor, 4),
                    "t1": round(_shift(float(span[1]), inserted, False) + cursor, 4),
                }
                if ti in rests:
                    row["rest"] = round(rests[ti] + cursor, 4)
                if ti in rested:
                    row["rested"] = round(rested[ti], 4)
                elif ti == len(group) - 1 and gap is not None:
                    # the sentence's last word: the middle of the gap before the next
                    row["rest"] = round(cursor + len(audio) / sr + gap * 0.5, 4)
                times.append(row)
            chunks.append(audio)
            cursor += len(audio) / sr
            base += len(group)
            if gap is not None:
                pad = int(round(gap * sr))
                if pad > 0:
                    chunks.append(np.zeros(pad, dtype=np.float32))
                    cursor += pad / sr
        joined = np.concatenate(chunks) if chunks else np.zeros(1, dtype=np.float32)
        # The Tone, played back here rather than in the editor: the same render-slower, play-faster trade as
        # the arc, through the same band-limited resampler (see `_resample`). Every time handed back is in
        # the played audio's own seconds, so the editor has no ratio left to apply.
        played = float(params.get("play_ratio", 1.0) or 1.0)
        if abs(played - 1.0) > 1e-4 and joined.size > 1:
            joined = _resample(joined, played)
            for row in times + phones:
                for key in ("t0", "t1", "rest", "rested"):
                    if key in row:
                        row[key] = round(row[key] / played, 4)
        joined, sr = self._delivered(joined, sr)
        self._write_wav(out_path, joined, sr)
        return {
            "wav": out_path,
            "sample_rate": sr,
            "duration": float(joined.size) / sr,
            "tokens": times,
            "phones": phones,
            "aligned": bool(times),
            "sentences": len(groups),
            "played": played,
        }

    @staticmethod
    def _gap(edges: dict, ti, frame: float):
        """Where a rest after token `ti` may be cut - `_gap_window`, for a plan whose word edges are the
        waveform's to within a frame or two. A model whose are not says its own."""
        return _gap_window(edges, ti, frame)

    @staticmethod
    def _nominal(frames, ratio: float, sr: int, floor=None) -> float:
        """How long a sentence would have run at `1/ratio` of its length scale - `_nominal_seconds`,
        for a plan CEILED to whole frames of `hop` samples. A model that rounds its plan says so here."""
        return _nominal_seconds(frames, ratio, sr, floor)

    @staticmethod
    def _delivered(audio, sr: int):
        """The take as it is handed back: (audio, sample rate). Piper's, as rendered."""
        return audio, sr

    @staticmethod
    def _fold_syllabic(symbols: list, pmap: dict) -> tuple[list, bool]:
        """Rewrite syllabic consonants this voice cannot spell as schwa + consonant.

        The mark follows its base in the stream, so the schwa is inserted one place back: `[.., ("n", i),
        ("̩", i)]` becomes `[.., ("ə", i), ("n", i)]`. The inserted symbol keeps the base's source index, so
        per-token alignment is unaffected.

        A no-op on voices whose maps carry U+0329, and on a voice that lacks a schwa (it falls through to
        the existing drop).
        """
        # Look at the stream before the map: most utterances contain no syllabic mark, so probing is wasted
        # work, and a phoneme_id_map is not always an inert dict (the test harness's stand-in allocates an
        # id on first lookup, which shifted every later id). Cheap early-out, no side effects.
        if not any(sym == SYLLABIC for sym, _ in symbols):
            return symbols, False
        # .get() rather than `in`: that same stand-in supports lookup but not membership.
        if pmap.get(SYLLABIC) is not None or pmap.get(SCHWA) is None:
            return symbols, False
        out: list = []
        folded = False
        for sym, src in symbols:
            if sym == SYLLABIC:
                if out:
                    out.insert(len(out) - 1, (SCHWA, out[-1][1]))
                    folded = True
                # A mark with nothing in front of it has no base to be syllabic on: discarded rather than
                # turned into an invented leading schwa.
                continue
            out.append((sym, src))
        return out, folded

    def _run(
        self, group: list, voice: str, params: dict, cfg: dict, sess, phonemizer: str
    ):
        """One sentence: symbols -> ids -> audio, plus per-token time spans."""
        espeak_voice = str(cfg.get("espeak", {}).get("voice", "en-us"))
        # Word by word a homograph has no syntax to be read by, so eSpeak gives its default reading every
        # time. Ask again in a frame that forces the part of speech, only where the answer changes
        # (homographs.py; a no-op if nltk is not installed). English only, as the carrier frames and the
        # tagger are.
        if phonemizer == "espeak" and espeak_voice.split("-")[0] in ("en", ""):
            self._homographs.annotate(group, espeak_voice)
            # ...and a word eSpeak is only guessing at, read as a dictionary has it, its full
            # vowels stressed (lexicon.py; `lexicon` is the request's: fetch, cache or off)
            self._lexicon.annotate(group, espeak_voice, str(params.get("lexicon", "off")),
                                   cfg.get("phoneme_id_map", {}))
        # The reading is then written in the spelling this checkpoint was measured to render correctly (see
        # `_load` and vowel_probe.py).
        symbols = self._symbols(group, phonemizer, espeak_voice, voice)
        floors = {ti: _floor_of(t, params, _tail_share(group, ti)) for ti, t in enumerate(group)}
        stretch = {
            ti: EMPHASIS[int(t.get("emph", 0) or 0)][0]
            for ti, t in enumerate(group)
            if int(t.get("emph", 0) or 0) in EMPHASIS
        }
        # the word before a rest is held (`TRAIL_STRETCH`): its final rime, by this much
        held = {}
        for ti, t in enumerate(group):
            w = _trail_weight(str(t.get("punct", "")), params, _rest_after(t), _tail_share(group, ti))
            if w > 0.0:
                held[ti] = 1.0 + TRAIL_STRETCH * w
        return self._render_symbols(
            symbols, cfg, sess, params, floors, stretch, opening=OPENING_VOWEL, hold=held
        )

    def _render_symbols(
        self,
        symbols: list,
        cfg: dict,
        sess,
        params: dict,
        floors: dict | None = None,
        stretch: dict | None = None,
        opening: float = 0.0,
        hold: dict | None = None,
    ):
        """(symbol, source) pairs -> audio, plus a time span per source.

        Split out of `_run` so the vowel probe can render a phoneme string it built itself and get spans
        keyed to single symbols rather than words. Nothing here interprets the source index; it is carried
        through and handed back.

        `floors` is {source: seconds} of rest the model renders on the word-space that ends that source
        (`_floor_of`), fed to the graph when it takes one. `stretch` is {source: multiplier} on that
        source's stressed vowel (`EMPHASIS`), `opening` the seconds the first word's vowel may not fall
        below (`OPENING_VOWEL`) at the request's length scale, and `hold` {source: multiplier} on that
        source's final rime (`TRAIL_STRETCH`), multiplied with the stress where the two meet. All act on the
        duration plan through the graph's inputs; a graph without them renders as before. The vowel probe
        passes none: it must get the model's own vowels.
        """
        import numpy as np

        pmap: dict = cfg["phoneme_id_map"]
        frame_s = HOP_LENGTH / float(cfg["audio"]["sample_rate"])
        # eSpeak is where U+0329 comes from, so this is the call that matters.
        symbols, folded = self._fold_syllabic(symbols, pmap)
        # The nucleus of each source: the vowel run after its primary stress, or its first vowel run. What a
        # stretch lengthens and the opening floor holds up.
        nucleus = _nuclei(symbols)
        rime = _final_rimes(symbols, set(hold)) if hold else set()
        first = next(
            (
                src
                for sym, src in symbols
                if src >= 0 and sym != " " and sym not in _MARK_SYMBOLS
            ),
            None,
        )
        ls = float(
            params.get("length_scale", cfg.get("inference", {}).get("length_scale", 1.0))
        )
        open_frames = (
            float(math.ceil(opening * ls / frame_s - 1e-9)) if opening > 0.0 else 0.0
        )
        ids: list[int] = [BOS]
        owner: list[int] = [-1]
        # Which symbol each id says, by its place in `symbols` (-1 for BOS, the pads and EOS): the phones
        # handed back with their times (`_last_phones`), which a likeness's mouth follows (next/likeness.md,
        # "The voice").
        said_by: list[int] = [-1]
        missing: list[str] = []
        # Which ids are the rest between two words (the blanks and the word-space). `_trim_rests` needs
        # where a boundary rest starts and stops, and only the id stream says: a token's span runs to the
        # end of its own trailing space, so the rest is split between two spans. -1 = not a rest, else the
        # index of the token whose word-space this run carries.
        rest_of: list[int] = [-2]
        # Which ids are a word's own sounds, not blanks, word-spaces or punctuation: a pause is cut between
        # the last of one word's and the first of the next's (`_gap_window`), since a token's span runs on
        # through its mark and space.
        sound: list[bool] = [False]
        # Frames each id's duration may not fall below - nonzero only on the word-space
        # that ends a source with a floor (`_floor_of`: its mark's, or a rest the caller
        # splices in after it), so never the lead-in spaces.
        floor: list[float] = [0.0]
        # The multiplier on each id's predicted duration - 1 everywhere but a leaned-on vowel.
        scale: list[float] = [1.0]
        # The word-space that ends each source (its last symbol, after its mark if it has one, never a space
        # inside it) is where its rest is floored.
        ends = {src: j for j, (_sym, src) in enumerate(symbols)}
        opened = False  # the opening floor goes on the first id of the first nucleus only
        for j, (sym, src) in enumerate(symbols):
            mapped = pmap.get(sym)
            if mapped is None:
                missing.append(sym)
                continue
            rest = 0.0
            if sym == " " and floors and j == ends.get(src):
                rest = float(round(float(floors.get(src, 0.0)) / frame_s))
            core = j in nucleus
            mul = float(stretch.get(src, 1.0)) if stretch and core else 1.0
            # the blank before a nucleus symbol is inside the syllable unless it opens it, and
            # the blank right after the nucleus is the vowel's release - both are stretched
            prev_core = (j - 1) in nucleus and symbols[j - 1][1] == src
            pad_mul = (
                float(stretch.get(src, 1.0))
                if stretch and prev_core
                else 1.0
            )
            # a held word's final rime the same way: its sounds, the blanks inside it, and the
            # one after it
            if hold:
                if j in rime:
                    mul *= float(hold.get(src, 1.0))
                if (j - 1) in rime and symbols[j - 1][1] == src:
                    pad_mul *= float(hold.get(src, 1.0))
            if core and src == first and open_frames > 0.0 and not opened and sym != _STRESS:
                rest = max(rest, open_frames)
                opened = True
            ids.append(PAD)
            owner.append(src)
            said_by.append(-1)
            rest_of.append(-1)
            sound.append(False)
            floor.append(0.0)
            scale.append(pad_mul)
            for k, m in enumerate(mapped):
                ids.append(int(m))
                owner.append(src)
                said_by.append(j)
                rest_of.append(src if sym == " " else -2)
                sound.append(sym != " " and sym not in _MARK_SYMBOLS)
                floor.append(rest if k == 0 else 0.0)
                scale.append(mul)
        ids.append(PAD)
        owner.append(-1)
        said_by.append(-1)
        rest_of.append(-1)
        sound.append(False)
        floor.append(0.0)
        scale.append(1.0)
        ids.append(EOS)
        owner.append(-1)
        said_by.append(-1)
        rest_of.append(-2)
        sound.append(False)
        floor.append(0.0)
        scale.append(1.0)
        if folded and SYLLABIC not in self._warned_symbols:
            self._warned_symbols.add(SYLLABIC)
            print(
                "ghost/voice: this voice has no U+0329 (syllabic); writing it as a "
                "schwa before the consonant instead",
                file=sys.stderr,
            )
        if missing:
            # Drop, do not fail: eSpeak emits marks a voice's map may not carry, and raising costs the whole
            # request. Anything landing here is genuinely unhandled (U+0329 is rewritten above; see
            # SYLLABIC). Reported once per symbol per process, to stderr, which ghost echoes to the
            # terminal.
            for sym in sorted(set(missing)):
                if sym in self._warned_symbols:
                    continue
                self._warned_symbols.add(sym)
                print(
                    "ghost/voice: dropping U+%04X (%r), absent from this "
                    "voice's phoneme_id_map" % (ord(sym), sym),
                    file=sys.stderr,
                )

        inf = cfg.get("inference", {})
        feeds = {
            "input": np.array([ids], dtype=np.int64),
            "input_lengths": np.array([len(ids)], dtype=np.int64),
            "scales": np.array(
                [
                    float(params.get("noise_scale", inf.get("noise_scale", 0.667))),
                    float(params.get("length_scale", inf.get("length_scale", 1.0))),
                    float(params.get("noise_w", inf.get("noise_w", 0.333))),
                ],
                dtype=np.float32,
            ),
        }
        if int(cfg.get("num_speakers", 1)) > 1:
            feeds["sid"] = np.array([int(params.get("speaker", 0))], dtype=np.int64)
        fed = None
        takes = {i.name for i in getattr(sess, "get_overridable_initializers", list)()}
        if any(floor) and REST_FLOOR_INPUT in takes:
            fed = np.array(floor, dtype=np.float32)
            feeds[REST_FLOOR_INPUT] = fed
        if any(m != 1.0 for m in scale) and DUR_SCALE_INPUT in takes:
            feeds[DUR_SCALE_INPUT] = np.array(scale, dtype=np.float32)
        out = sess.run(None, feeds)
        audio = np.asarray(out[0]).squeeze().astype(np.float32)

        spans: dict = {}
        # The duration plan, kept: `_nominal_seconds` needs it, and the floor it was given, to undo what a
        # per-sentence length_scale does to the timing. Stashed rather than returned because the vowel probe
        # renders through this function and unpacks a pair.
        self._last_frames = None
        self._last_floor = None
        # [(t0, t1, token index)] for every run of blanks carrying a word-space, in the
        # same seconds `spans` is in. Stashed rather than returned for the reason
        # `_last_frames` is: the vowel probe renders through here and unpacks a pair.
        self._last_rests: list = []
        # {token: (first sound start, last sound end)} in the same seconds - see `sound`.
        self._last_edges: dict = {}
        # [{p, t0, t1, w}]: every sound with its time in the same seconds, `w` its token - see
        # `said_by`. A length mark is its vowel's; stress marks, word-spaces and marks are no sound.
        self._last_phones: list = []
        # The tokens that end on a hiss, for `_trail`. From the symbols, so with or without a plan.
        self._last_hisses: dict = _hiss_codas(symbols)
        if len(out) > 1:
            frames = np.asarray(out[1]).squeeze().astype(np.float64)
            if frames.ndim == 1 and frames.size == len(owner):
                self._last_frames = frames
                self._last_floor = fed
                t = 0.0
                run_at = 0.0
                run_of = -1
                spoke = False
                said: dict = {}
                for dur, who, rest, heard, by in zip(
                    frames * HOP_LENGTH / float(cfg["audio"]["sample_rate"]),
                    owner,
                    rest_of,
                    sound,
                    said_by,
                ):
                    if heard and who >= 0:
                        e = self._last_edges.get(who)
                        self._last_edges[who] = (t if e is None else e[0], t + dur)
                    if heard and by >= 0:
                        e = said.get(by)
                        said[by] = (t if e is None else e[0], t + dur)
                    if rest == -2:
                        # A rest is only a rest when speech stands on both sides of it: the lead-in (see
                        # LEAD_IN_SPACES) and the utterance's tail are neither.
                        if run_of >= 0 and spoke and who >= 0:
                            self._last_rests.append((run_at, t, run_of))
                        spoke = spoke or who >= 0
                        run_of = -1
                        run_at = t + dur
                    elif rest >= 0:
                        run_of = rest
                    if who >= 0:
                        if who not in spans:
                            spans[who] = [t, t + dur]
                        else:
                            spans[who][1] = t + dur
                    t += dur
                for j in sorted(said):
                    sym, src = symbols[j]
                    a, b = said[j]
                    if sym in _UNSAID:
                        continue
                    if sym in _LENGTHENS and self._last_phones and self._last_phones[-1]["w"] == src:
                        self._last_phones[-1]["t1"] = b
                        continue
                    self._last_phones.append({"p": sym, "t0": a, "t1": b, "w": src})
        return audio, spans

    @staticmethod
    def _durations(
        w_ceil, owner: list[int], phonemes: list, sample_rate: int
    ) -> list[dict]:
        """Per-phoneme boundaries from the VITS duration predictor.

        `w_ceil` is the ceiling of the stochastic duration predictor, one entry per phoneme id including
        pads and BOS/EOS, in frames; multiply by the hop length for samples. This is the plan the
        synthesizer used, so it is exact. Only present when the voice's ONNX has been patched to expose it
        (see patch_alignment.py); otherwise timings are unavailable.
        """
        import numpy as np

        frames = np.asarray(w_ceil).squeeze().astype(np.float64)
        if frames.ndim != 1 or frames.size != len(owner):
            return []
        samples = frames * HOP_LENGTH
        # fold every id's duration back onto the input phoneme that produced it,
        # pads included - a pad's time belongs to the phoneme it followed
        spans: dict[int, float] = {}
        for dur, who in zip(samples, owner):
            if who >= 0:
                spans[who] = spans.get(who, 0.0) + float(dur)
        out, cursor = [], 0.0
        for i, sym in enumerate(phonemes):
            dur = spans.get(i, 0.0) / sample_rate
            out.append(
                {"p": str(sym), "t0": round(cursor, 4), "t1": round(cursor + dur, 4)}
            )
            cursor += dur
        return out

    def _dictionary_reading(self, ipa: str, token: dict) -> str:
        """eSpeak's reading `ipa` of `token`, as this model should be sent it given the word's dictionary reading
        (its `fallback`, ghost's CMUdict ARPAbet). Piper was taught on eSpeak's own readings: as it is. A model
        taught on another dictionary's says where they part (kokoro.py)."""
        return ipa

    def _leveled(self, voice: str, params: dict, cfg: dict, sess) -> dict:
        """`params` with the gain `voice`'s speaker is played at (`level_gain`, level.py)."""
        speaker = int(params.get("speaker", 0) or 0)
        return {**params, "level_gain": self._levels.gain(self, voice, speaker, cfg, sess)}

    def _level_files(self, voice: str, speaker: int) -> list:
        """The files `voice`'s `speaker` sounds as it does because of: a level kept is kept while they are."""
        return [self._files(voice)[0]]

    @staticmethod
    def _write_wav(path: str, audio, sample_rate: int) -> None:
        import wave
        import numpy as np

        pcm = (np.clip(audio, -1.0, 1.0) * 32767.0).astype("<i2")
        tmp = path + ".part"
        with wave.open(tmp, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(sample_rate)
            w.writeframes(pcm.tobytes())
        Path(tmp).replace(path)  # atomic, same discipline as Voice.write_wav
