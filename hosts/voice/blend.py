#!/usr/bin/env python3
"""A Kokoro voice made of others: the packs of a checkpoint's readers mixed into one (the line, its
words and why: src/voice/voice_blend.gd).

A pack is [510, 1, 256]: row n the style for a sentence of n tokens, its first TIMBRE numbers what
Kokoro's decoder is given (`ref_s[:, :128]` in its model.py) and the rest what its duration, pitch and
energy predictors are (`ref_s[:, 128:]`). Every method works row by row, so a blend reads a short
sentence and a long one as its readers would.

THE LINE, as voice_blend.gd writes it: `<method>[ <accent>]: <reader>[ <weight>][ <part>], ...`.
`parse` reads it as that file does - an unknown method a mix, an unknown accent or part unsaid, a weight
clamped - and a line that names fewer than two readers is no blend.

THE METHODS:

  mix        the weighted average, number by number - Kokoro's own `af_bella,af_sky`, and Kokoro-FastAPI's
             `af_bella(2)+af_sky(1)`;
  spherical  the same mix, each half's length put back to the readers' own (weighted): two voices apart
             average to a shorter vector than either (Heart and Emma, 1.59 and 1.67 in a row's timbre, mix
             to 1.46) - the community's slerp, for any number of readers;
  split      the timbre of the readers marked sound, the prosody of those marked delivery (each side a mix
             by weight; both is on both sides; a side nobody is on takes everyone) - StyleTTS 2's acoustic
             and prosodic styles, which Kokoro keeps apart;
  max, min   each number the largest (smallest) any reader has, weights unused - the user's own two ideas,
             kept because every word was still heard in them (below); no reader was taught a style like it.

WHAT WAS MEASURED (2026-11-11, four sentences in each of four pairs - Heart+Emma, Heart+Puck, Emma+George,
Bella+Michael - through the real graph; Whisper medium.en on each, the speaking level as level.py takes it):
see BLEND_MEASURED below.

ITS LEVEL IS ITS READERS' (`gain`): every voice is played at one level (level.py), and a blend's is
measured off its readers' gains - their weighted geometric mean, the sound side's alone in a split (the
decoder makes the level: Heart's sound with Emma's delivery spoke at 0.084, Heart 0.082, Emma 0.107). A
blend is never measured itself: a weight moved is a new blend, and each would wait seconds on its level
and leave a row in levels.json.
"""

from __future__ import annotations

import math

TIMBRE = 128
METHODS = ("mix", "spherical", "split", "max", "min")
# The methods a weight means nothing to: every reader counts once.
UNWEIGHTED = ("max", "min")
PARTS = ("both", "sound", "delivery")
ACCENTS = ("american", "british")
WEIGHT_MIN = 0.1
WEIGHT_MAX = 10.0


def parse(spec: str):
    """`spec` read: {method, accent ("" unsaid), voices: [(reader, weight, part)]}, or None for a line
    that names fewer than two readers."""
    if not isinstance(spec, str) or ":" not in spec:
        return None
    head, _, body = spec.partition(":")
    words = head.strip().lower().split()
    method = words[0] if words and words[0] in METHODS else "mix"
    accent = words[1] if len(words) > 1 and words[1] in ACCENTS else ""
    voices = []
    for entry in body.split(","):
        bits = entry.strip().split()
        if not bits:
            continue
        weight, part = 1.0, "both"
        for b in bits[1:]:
            low = b.lower()
            try:
                weight = min(max(float(low), WEIGHT_MIN), WEIGHT_MAX)
                if not math.isfinite(weight):
                    weight = 1.0
            except ValueError:
                if low in PARTS:
                    part = low
        voices.append((bits[0], weight, part))
    if len(voices) < 2:
        return None
    return {"method": method, "accent": accent, "voices": voices}


def sides(method: str, weights: list, parts: list) -> tuple:
    """Each reader's weight on the timbre side and on the prosody side (unnormalized): the same weight on
    both but in a split, where a reader is on the side its part names - and a side nobody is on takes
    everyone's."""
    if method in UNWEIGHTED:
        return [1.0] * len(weights), [1.0] * len(weights)
    if method != "split":
        return list(weights), list(weights)
    sound = [w if p in ("both", "sound") else 0.0 for w, p in zip(weights, parts)]
    said = [w if p in ("both", "delivery") else 0.0 for w, p in zip(weights, parts)]
    return (sound if sum(sound) > 0 else list(weights)), (said if sum(said) > 0 else list(weights))


def make(method: str, packs: list, weights: list, parts: list):
    """The blended pack of `packs` (each [rows, 1, 256], one checkpoint's), by `method`."""
    import numpy as np

    rows = min(p.shape[0] for p in packs)
    stack = np.stack([np.asarray(p[:rows], dtype=np.float64) for p in packs])  # [n, rows, 1, 256]
    if method in UNWEIGHTED:
        return (stack.max(axis=0) if method == "max" else stack.min(axis=0)).astype(np.float32)
    tw, pw = sides(method, weights, parts)
    out = np.empty(stack.shape[1:], dtype=np.float64)
    for half, w in ((slice(0, TIMBRE), tw), (slice(TIMBRE, None), pw)):
        x = stack[..., half]
        w = np.asarray(w, dtype=np.float64)
        w = w / w.sum()
        if method == "spherical":
            norms = np.linalg.norm(x, axis=-1, keepdims=True)
            unit = x / np.maximum(norms, 1e-12)
            d = np.tensordot(w, unit, axes=1)
            d = d / np.maximum(np.linalg.norm(d, axis=-1, keepdims=True), 1e-12)
            out[..., half] = d * np.tensordot(w, norms, axes=1)
        else:
            out[..., half] = np.tensordot(w, x, axes=1)
    return out.astype(np.float32)


def british(blend: dict, accents: list) -> bool:
    """Whether `blend` is read British: its accent if said, else that of its heaviest reader on the prosody
    side (`accents`, each reader's "GB" or "US", in its order) - the first of the heaviest."""
    if blend["accent"]:
        return blend["accent"] == "british"
    weights = [w for _r, w, _p in blend["voices"]]
    parts = [p for _r, _w, p in blend["voices"]]
    _tw, pw = sides(blend["method"], weights, parts)
    heaviest = max(range(len(pw)), key=lambda i: (pw[i], -i))
    return accents[heaviest] == "GB"


def gain(blend: dict, gains: list) -> float:
    """The gain `blend` is played at, from its readers' (`gains`, in its order): their weighted geometric
    mean, on the timbre side (above)."""
    weights = [w for _r, w, _p in blend["voices"]]
    parts = [p for _r, _w, p in blend["voices"]]
    tw, _pw = sides(blend["method"], weights, parts)
    total = sum(tw)
    return math.exp(sum(w * math.log(max(g, 1e-6)) for w, g in zip(tw, gains)) / total)
