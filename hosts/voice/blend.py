#!/usr/bin/env python3
"""A Kokoro voice made of others, and shaped: the packs of a checkpoint's readers mixed into one, the mix moving
across a paragraph, and the whole moved along measured directions (the line, its words and why:
src/voice/voice_blend.gd).

A pack is [510, 1, 256]: row n the style for a sentence of n tokens, its first TIMBRE numbers what
Kokoro's decoder is given (`ref_s[:, :128]` in its model.py) and the rest what its duration, pitch and
energy predictors are (`ref_s[:, 128:]`). Every method works row by row, so a blend reads a short
sentence and a long one as its readers would.

THE LINE, as voice_blend.gd writes it:

    <method>[ <accent>]: <reader>[ <weights>][ <part>], ...[; breath <points>][; push <points>][; noise <kind> <amount>[ <seed>]]

`<weights>` is one number or points across a paragraph joined by "/" (`60/50/40`): the reader's share at the
paragraph's first sentence, its last, and evenly between. `breath` and `push` are points from -1 to 1, the same
way. `parse` reads it as that file does - an unknown method a mix, an unknown accent, part or clause unsaid, a
number clamped. Fewer than two readers is no voice unless the line shapes it (a lane or noise): one reader
shaped is that reader moved.

ACROSS A PARAGRAPH: each curve (`curve_at`, a monotone cubic through the points: it never overshoots them, so a
share never goes below nothing nor a lane past its ends) is read where each token stands in its paragraph - a
request's `plan_span`, where its sentence starts and ends in its paragraph (0 its first word, 1 its last), laid over
its tokens (`rows_along`) and read by the graph that takes a style a token (kokoro_moving.py). Without it, or where
that graph cannot be made, a sentence reads in one style, at its `plan_u` (0 at a paragraph's first sentence, 1 at
its last), and a curve steps from sentence to sentence.

THE METHODS:

  mix        the weighted average, number by number - Kokoro's own `af_bella,af_sky`, and Kokoro-FastAPI's
             `af_bella(2)+af_sky(1)`;
  spherical  the same mix, each half's length put back to the readers' own (weighted): two voices apart
             average to a shorter vector than either (Heart and Emma, 1.59 and 1.67 in a row's timbre, mix
             to 1.46) - the community's slerp, for any number of readers;
  split      the timbre of the readers marked sound, the prosody of those marked delivery (each side a mix
             by weight; both is on both sides; a side nobody is on takes everyone) - StyleTTS 2's acoustic
             and prosodic styles, which Kokoro keeps apart;
  max, min   the weighted mix plus how far each number's largest (smallest) reader stands past the readers'
             plain mean: equal weights are each number the largest (smallest) any reader has, and a weight
             leans it toward its reader. No reader was taught a style like it; every word was still heard.

THE LANES (`shape`): `breath` moves the voice along the direction that makes Kokoro's readers breathier (1 is
BREATH_SIGMAS of the readers' own spread along it; -1 clearer), `push` along the one that makes them brighter and
pushed (1 is PUSH_SIGMAS; -1 softer, darker). Both measured off the 28 English readers by
hosts/voice_train/kokoro_axes.py into kokoro_axes.json beside this file; moved +-2 sigmas, breath moved CPP 2-3 dB
and push the alpha ratio about 15 dB, each monotonic, in every reader tried.

NOISE stays among voices: a draw over the readers' own principal directions, each by its spread (kokoro_axes.json
`spread`), NOISE_MOST of a reader's distance from the readers' mean at amount 1. `fixed` is one draw for the whole
reading (a new voice near this one); `wander` draws a value every paragraph and eases between them, read at the
request's place in the reading (`plan_p` + `plan_u`). The seed picks the draw.

ITS LEVEL IS ITS READERS' (`gain`): every voice is played at one level (level.py), and a blend's is
measured off its readers' gains - their weighted geometric mean, the sound side's alone in a split (the
decoder makes the level: Heart's sound with Emma's delivery spoke at 0.084, Heart 0.082, Emma 0.107). A
blend is never measured itself: a weight moved is a new blend, and each would wait seconds on its level
and leave a row in levels.json. A lane moved is left at its own level: a breathier voice is a little quieter.
"""

from __future__ import annotations

import json
import math
import sys
from pathlib import Path

TIMBRE = 128
METHODS = ("mix", "spherical", "split", "max", "min")
PARTS = ("both", "sound", "delivery")
ACCENTS = ("american", "british")
LANES = ("breath", "push")
NOISES = ("fixed", "wander")
WEIGHT_MAX = 100.0
POINTS_MOST = 9          # points a curve may have
BREATH_SIGMAS = 3.0      # breath 1, in sigmas of the readers' spread along its axis
PUSH_SIGMAS = 2.0        # push 1
NOISE_MOST = 0.6         # noise 1, as a share of a reader's distance from the readers' mean
AXES = Path(__file__).with_name("kokoro_axes.json")

_axes: dict | None = None


def _points(word: str, lo: float, hi: float):
    """A number or "/"-joined numbers, each clamped to lo..hi - or None where any is not a number."""
    out = []
    for bit in word.split("/"):
        try:
            v = float(bit)
        except ValueError:
            return None
        if not math.isfinite(v):
            return None
        out.append(min(max(v, lo), hi))
    return tuple(out[:POINTS_MOST]) if out else None


def parse(spec: str):
    """`spec` read: {method, accent ("" unsaid), voices: [(reader, weights, part)], breath, push (points), noise
    ((kind, amount, seed) or None)} - or None for a line that is no voice (fewer than two readers and nothing that
    shapes one)."""
    if not isinstance(spec, str) or ":" not in spec:
        return None
    first, *clauses = spec.split(";")
    head, _, body = first.partition(":")
    words = head.strip().lower().split()
    method = words[0] if words and words[0] in METHODS else "mix"
    accent = words[1] if len(words) > 1 and words[1] in ACCENTS else ""
    voices = []
    for entry in body.split(","):
        bits = entry.strip().split()
        if not bits:
            continue
        weights, part = (1.0,), "both"
        for b in bits[1:]:
            low = b.lower()
            got = _points(low, 0.0, WEIGHT_MAX)
            if got is not None:
                weights = got
            elif low in PARTS:
                part = low
        voices.append((bits[0], weights, part))
    lanes = {lane: (0.0,) for lane in LANES}
    noise = None
    for clause in clauses:
        bits = clause.strip().lower().split()
        if len(bits) >= 2 and bits[0] in LANES:
            got = _points(bits[1], -1.0, 1.0)
            if got is not None:
                lanes[bits[0]] = got
        elif len(bits) >= 3 and bits[0] == "noise" and bits[1] in NOISES:
            got = _points(bits[2], 0.0, 1.0)
            seed = int(bits[3]) if len(bits) > 3 and bits[3].isdigit() else 0
            if got is not None and got[0] > 0.0:
                noise = (bits[1], got[0], seed)
    out = {"method": method, "accent": accent, "voices": voices, **lanes, "noise": noise}
    if len(voices) >= 2 or (len(voices) == 1 and shaped(out)):
        return out
    return None


def shaped(blend: dict) -> bool:
    """Whether `blend` moves its voice: a lane off zero, or noise."""
    return blend["noise"] is not None or any(v != 0.0 for lane in LANES for v in blend[lane])


def moving(blend: dict) -> bool:
    """Whether `blend` is read differently across a paragraph: a curve of more than one value."""
    curves = [w for _r, w, _p in blend["voices"]] + [blend[lane] for lane in LANES]
    return any(len(set(c)) > 1 for c in curves)


def curve_at(points, u: float) -> float:
    """`points` (evenly across 0..1) read at `u`: a monotone cubic (Fritsch-Carlson), so between two points it never
    leaves them. voice_blend.gd's `curve_at` is this, line for line."""
    p = [float(v) for v in points]
    n = len(p)
    if n == 1:
        return p[0]
    u = min(max(float(u), 0.0), 1.0)
    h = 1.0 / (n - 1)
    d = [(p[k + 1] - p[k]) / h for k in range(n - 1)]
    m = [0.0] * n
    m[0], m[-1] = d[0], d[-1]
    for k in range(1, n - 1):
        m[k] = 0.0 if d[k - 1] * d[k] <= 0.0 else (d[k - 1] + d[k]) / 2.0
    for k in range(n - 1):
        if d[k] == 0.0:
            m[k] = m[k + 1] = 0.0
            continue
        a, b = m[k] / d[k], m[k + 1] / d[k]
        s = a * a + b * b
        if s > 9.0:
            t = 3.0 / math.sqrt(s)
            m[k], m[k + 1] = t * a * d[k], t * b * d[k]
    k = min(int(u / h), n - 2)
    t = (u - k * h) / h
    t2, t3 = t * t, t * t * t
    return ((2 * t3 - 3 * t2 + 1) * p[k] + (t3 - 2 * t2 + t) * h * m[k]
            + (-2 * t3 + 3 * t2) * p[k + 1] + (t3 - t2) * h * m[k + 1])


def at(blend: dict, u: float | None) -> dict:
    """`blend` with each reader's weight read at `u` (None: each curve's mean) - the one weight `make`, `british` and
    `gain` take. Where every weight is nothing, each counts once."""
    voices = []
    for r, w, part in blend["voices"]:
        v = sum(w) / len(w) if u is None else curve_at(w, u)
        voices.append((r, max(v, 0.0), part))
    if sum(v for _r, v, _p in voices) <= 0.0:
        voices = [(r, 1.0, part) for r, _v, part in voices]
    return {**blend, "voices": voices}


def sides(method: str, weights: list, parts: list) -> tuple:
    """Each reader's weight on the timbre side and on the prosody side (unnormalized): the same weight on
    both but in a split, where a reader is on the side its part names - and a side nobody is on takes
    everyone's."""
    if method != "split":
        return list(weights), list(weights)
    sound = [w if p in ("both", "sound") else 0.0 for w, p in zip(weights, parts)]
    said = [w if p in ("both", "delivery") else 0.0 for w, p in zip(weights, parts)]
    return (sound if sum(sound) > 0 else list(weights)), (said if sum(said) > 0 else list(weights))


def make(method: str, packs: list, weights: list, parts: list):
    """The blended pack of `packs` (each [rows, 1, 256], one checkpoint's), by `method`, at one weight a reader."""
    import numpy as np

    rows = min(p.shape[0] for p in packs)
    stack = np.stack([np.asarray(p[:rows], dtype=np.float64) for p in packs])  # [n, rows, 1, 256]
    if method in ("max", "min"):
        w = np.asarray(weights, dtype=np.float64)
        w = w / w.sum()
        edge = stack.max(axis=0) if method == "max" else stack.min(axis=0)
        return (np.tensordot(w, stack, axes=1) + edge - stack.mean(axis=0)).astype(np.float32)
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


def axes() -> dict:
    """kokoro_axes.json, read once ({} where it is missing: no lane or noise moves anything)."""
    global _axes
    if _axes is None:
        try:
            _axes = json.loads(AXES.read_text(encoding="utf-8"))
        except (OSError, ValueError) as exc:
            print(f"ghost/voice: no Kokoro axes ({exc}) - breath, push and noise do nothing", file=sys.stderr)
            _axes = {}
    return _axes


def _knot(seed: int, k: int, j: int) -> float:
    import numpy as np

    return float(np.random.default_rng([seed, k, j + (1 << 20)]).standard_normal())


def offset(blend: dict, u: float, pos: float, table: dict | None = None):
    """The style offset [256] `blend`'s lanes and noise make at `u` across a paragraph and `pos` in the reading
    (paragraphs from the start) - zeros where nothing moves it or the axes are missing."""
    import numpy as np

    table = axes() if table is None else table
    out = np.zeros(256, dtype=np.float64)
    if not table:
        return out
    for lane, sigmas in (("breath", BREATH_SIGMAS), ("push", PUSH_SIGMAS)):
        v = curve_at(blend[lane], u)
        if v != 0.0 and lane in table:
            out += v * sigmas * float(table[lane]["sigma"]) * np.asarray(table[lane]["axis"], dtype=np.float64)
    noise = blend["noise"]
    if noise is not None and "spread" in table:
        kind, amount, seed = noise
        basis = np.asarray(table["spread"]["axes"], dtype=np.float64)
        sd = np.asarray(table["spread"]["sd"], dtype=np.float64)
        if kind == "fixed":
            z = np.array([_knot(seed, k, 0) for k in range(len(sd))])
        else:
            j = math.floor(pos)
            t = pos - j
            ease = (1.0 - math.cos(math.pi * t)) / 2.0
            z = np.array([_knot(seed, k, j) * (1.0 - ease) + _knot(seed, k, j + 1) * ease for k in range(len(sd))])
        out += amount * NOISE_MOST * (z * sd) @ basis
    return out


def rows_along(blend: dict, rows: list, places, pos0: float = 0.0, table: dict | None = None):
    """Each token's style [len(places), 256]: `blend` made of its readers' rows (`rows`, one [256] a reader - each
    pack's row for the sentence's length) where each token stands across its paragraph (`places`), moved by its lanes
    and noise there (`pos0` + its place, paragraphs into the reading)."""
    import numpy as np

    stack = [np.asarray(r, dtype=np.float32).reshape(1, 1, 256) for r in rows]
    parts = [p for _r, _w, p in blend["voices"]]
    moves = shaped(blend)
    out = np.empty((len(places), 256), dtype=np.float32)
    for k, u in enumerate(places):
        now = at(blend, float(u))
        style = make(blend["method"], stack, [w for _r, w, _p in now["voices"]], parts)[0, 0].astype(np.float64)
        if moves:
            style = style + offset(blend, float(u), pos0 + float(u), table)
        out[k] = style
    return out


def british(blend: dict, accents: list) -> bool:
    """Whether `blend` is read British: its accent if said, else that of its heaviest reader on the prosody
    side across the paragraph (`accents`, each reader's "GB" or "US", in its order) - the first of the heaviest.
    Read off each curve's mean, so a reading never changes accent between its sentences."""
    if blend["accent"]:
        return blend["accent"] == "british"
    mean = at(blend, None)
    weights = [w for _r, w, _p in mean["voices"]]
    parts = [p for _r, _w, p in mean["voices"]]
    _tw, pw = sides(blend["method"], weights, parts)
    heaviest = max(range(len(pw)), key=lambda i: (pw[i], -i))
    return accents[heaviest] == "GB"


def gain(blend: dict, gains: list, u: float = 0.5) -> float:
    """The gain `blend` is played at `u` across a paragraph, from its readers' (`gains`, in its order): their weighted
    geometric mean, on the timbre side (above)."""
    now = at(blend, u)
    weights = [w for _r, w, _p in now["voices"]]
    parts = [p for _r, _w, p in now["voices"]]
    tw, _pw = sides(blend["method"], weights, parts)
    total = sum(tw)
    return math.exp(sum(w * math.log(max(g, 1e-6)) for w, g in zip(tw, gains)) / total)
