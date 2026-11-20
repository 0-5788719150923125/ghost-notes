"""singing.py - a sung phrase laid on its notes: the syllables of each word, which note each sings, how many frames
each symbol holds, and the pitch curve the voice is told (next/music.md, "Kokoro sings"). Pure: the model is the
backend's (KokoroBackend.sing); this is arithmetic on its symbols and its plan.

A phrase is words, each with its notes `{t, len, midi}` in seconds from the phrase's start. A word's symbols are split
into syllables at their vowels (`syllabify`: the consonants between two vowels go to the second as far as English
lets a syllable begin, the rest stay with the first), and its syllables matched to its notes (`match`): one each; two
sung quickly on one note where a word has more syllables than notes; one held across several where it has fewer (a
melisma: the vowel holds and the pitch moves).

THE VOWEL IS ON THE BEAT. A syllable's consonants before its vowel (and a stress mark, which Kokoro plans frames for)
are sung before its note (taken from the end of the note before, or from the rest), its consonants after the vowel at
the end of its note, and each consonant keeps the
length Kokoro plans for it spoken; the vowel takes the rest of the note (`lay`). The first pad keeps its planned
length (the backend's header, THE OPENING), so the frame the take starts on is placed by it.

The pitch: each note's own, with what a singer adds (`ornament`, after Saitou and colleagues' speech-to-singing
recipe): a glide into a change of note that overshoots a little and settles (a damped second-order response), vibrato
coming in on a held note, a slow drift. `tune` 1 takes them all out - a hard-tuned voice, every note a step. Where
what is told meets what Kokoro plans, the two are eased together (`seam_pitch`, `seam_energy`): a step in a curve the
decoder reads is a click in what it makes.
"""

from __future__ import annotations

import math

# Kokoro's vowels in misaki's American and British notation: one letter each, its diphthongs single letters, the
# small schwa a syllabic consonant's.
VOWELS = frozenset("aeiouæɑɒɔəɚɛɜɪʊʌɐᵻAIOQWYᵊ")
# What rides with a vowel and keeps its planned frames: stress, length.
MARKS = frozenset("ˈˌː")
# Consonant runs a syllable may begin with (maximal onset): every single consonant but ŋ, and these.
ONSETS = frozenset({
    "pl", "pɹ", "bl", "bɹ", "tɹ", "dɹ", "kl", "kɹ", "ɡl", "ɡɹ", "fl", "fɹ", "θɹ", "ʃɹ", "sp", "st", "sk", "sm", "sn",
    "sl", "sw", "tw", "dw", "kw", "ɡw", "pj", "bj", "fj", "vj", "mj", "nj", "hj", "kj", "θw", "sf",
    "spɹ", "stɹ", "skɹ", "spl", "skw", "skl", "stj", "spj", "skj",
})
SPACE = " "
# The least a sung vowel holds, in frames: under it the consonants around it are shortened to make room.
VOWEL_LEAST = 2
# Hz under which Kokoro's planned pitch is unvoiced: those frames keep the plan, so a hiss is never made to buzz.
VOICED = 40.0
# How damped a glide into a new note is (1 none past it): at 0.65 a change overshoots by about a fourteenth and settles.
DAMPING = 0.65
# Curve steps (12.5 ms each) a seam between what is told and what Kokoro plans is eased over.
SEAM = 3


def is_vowel(sym: str) -> bool:
    return sym in VOWELS


def syllabify(syms: list[str]) -> list[dict]:
    """A word's symbols as syllables: [{"on", "nu", "co"}], each a list of indices into `syms`. A word with no vowel
    is one syllable of consonants (its nucleus empty)."""
    nuclei: list[list[int]] = []
    for i, s in enumerate(syms):
        if is_vowel(s):
            if nuclei and nuclei[-1][-1] == i - 1 and s != "ᵊ" and syms[i - 1] == "ᵊ":
                nuclei[-1].append(i)  # the small schwa and the consonant it voices are one nucleus
            else:
                nuclei.append([i])
        elif s in MARKS and nuclei and nuclei[-1][-1] == i - 1 and s == "ː":
            nuclei[-1].append(i)
    if not nuclei:
        return [{"on": list(range(len(syms))), "nu": [], "co": []}]
    out = []
    for k, nu in enumerate(nuclei):
        out.append({"on": [], "nu": list(nu), "co": []})
    # before the first vowel: its onset (a stress mark straight before a vowel rides with it)
    first = nuclei[0][0]
    lead = list(range(first))
    out[0]["on"], marks = _split_marks(syms, lead)
    out[0]["nu"] = marks + out[0]["nu"]
    for k in range(len(nuclei) - 1):
        between = list(range(nuclei[k][-1] + 1, nuclei[k + 1][0]))
        cons, marks = _split_marks(syms, between)
        take = 0
        for size in (3, 2, 1):
            if size <= len(cons):
                run = "".join(syms[i] for i in cons[-size:])
                if (size == 1 and run != "ŋ") or run in ONSETS:
                    take = size
                    break
        out[k]["co"] = cons[:len(cons) - take]
        out[k + 1]["on"] = cons[len(cons) - take:]
        out[k + 1]["nu"] = marks + out[k + 1]["nu"]
    out[-1]["co"] = list(range(nuclei[-1][-1] + 1, len(syms)))
    return out


def _split_marks(syms: list[str], idx: list[int]) -> tuple[list[int], list[int]]:
    """A run's consonants, and the stress marks in it (which ride with the vowel after)."""
    return [i for i in idx if syms[i] not in MARKS], [i for i in idx if syms[i] in MARKS]


def match(n_syl: int, notes: list[dict]) -> list[list[dict]]:
    """Each syllable's notes: one each, a note shared where there are more syllables (its time split between them),
    several for one where there are fewer."""
    if not notes:
        return [[] for _ in range(n_syl)]
    if n_syl == len(notes):
        return [[nt] for nt in notes]
    if n_syl < len(notes):
        out: list[list[dict]] = [[] for _ in range(n_syl)]
        for i, nt in enumerate(notes):
            out[min(i * n_syl // len(notes), n_syl - 1)].append(nt)
        return out
    out = [[] for _ in range(n_syl)]
    owners: list[list[int]] = [[] for _ in notes]
    for j in range(n_syl):
        owners[min(j * len(notes) // n_syl, len(notes) - 1)].append(j)
    for nt, js in zip(notes, owners):
        share = float(nt["len"]) / max(len(js), 1)
        for q, j in enumerate(js):
            out[j].append({**nt, "t": float(nt["t"]) + q * share, "len": share})
    return out


def lay(words: list[list[str]], notes: list[list[dict]], planned: list[float], frame_s: float) -> dict:
    """The frames each id holds for a phrase whose words have the symbols `words` (a space id between words, a pad at
    each end) and the notes `notes`, from Kokoro's own plan `planned` (frames per id).

    Returns {"frames": [int] an id each, "origin": seconds from the phrase's start to the first frame, "voices":
    [(t, midi)] the pitch from t on, "rests": [(t0, t1)] where nothing is sung, "vowels": [(f0, f1)] each sung vowel's
    frames, "sung": [{"word", "t"}] each syllable's vowel onset}."""
    id_of: dict = {}
    space_of: dict = {}
    sym_of: dict = {}
    k = 1
    for w, syms in enumerate(words):
        if w > 0:
            space_of[w] = k
            k += 1
        for i, sym in enumerate(syms):
            id_of[(w, i)] = k
            sym_of[k] = sym
            k += 1
    plan = [float(p) for p in planned]
    if len(plan) != k + 1:
        raise ValueError(f"the plan has {len(plan)} frames for {k + 1} ids")
    sung = []
    for w, syms in enumerate(words):
        sy = syllabify(syms)
        for q, (s, nts) in enumerate(zip(sy, match(len(sy), notes[w]))):
            sung.append({"word": w, "first": q == 0, "on": [id_of[(w, i)] for i in s["on"]],
                         "nu": [id_of[(w, i)] for i in s["nu"]], "co": [id_of[(w, i)] for i in s["co"]], "notes": nts})
    for j, s in enumerate(sung):  # a syllable its word had no note for is sung just after the one before
        if not s["notes"]:
            prev = sung[j - 1]["notes"][-1] if j else {"t": 0.0, "len": 0.2, "midi": 60.0}
            s["notes"] = [{**prev, "t": float(prev["t"]) + float(prev["len"]), "len": 0.12}]
    spoken = lambda ix: sum(plan[i] for i in ix) * frame_s  # noqa: E731
    least = VOWEL_LEAST * frame_s
    for s in sung:
        s["t0"] = float(s["notes"][0]["t"])
        s["t1"] = float(s["notes"][-1]["t"]) + float(s["notes"][-1]["len"])
        # a stress mark is sung before the beat with the onset, so the vowel itself lands on it
        s["marks"] = [i for i in s["nu"] if sym_of[i] in MARKS and sym_of[i] != "ː"]
        s["nu"] = [i for i in s["nu"] if i not in s["marks"]]
        s["on"] = s["on"] + s["marks"]
        s["on_len"] = spoken(s["on"])
    for j, s in enumerate(sung):
        nxt = sung[j + 1] if j + 1 < len(sung) else None
        if nxt is None:
            s["end"] = s["t1"]
        else:
            s["end"] = min(s["t1"], nxt["t0"] - nxt["on_len"] - (frame_s if nxt["first"] else 0.0))
        s["co_len"] = min(spoken(s["co"]), max(s["end"] - s["t0"] - least, frame_s * len(s["co"])))
    starts = [0.0] * len(plan)
    spans = [0.0] * len(plan)
    t = sung[0]["t0"] - sung[0]["on_len"] if sung else 0.0
    origin = t - plan[0] * frame_s
    starts[0], spans[0] = origin, plan[0] * frame_s
    voices: list = []
    rests: list = []
    vowel_spans: list = []
    last_id = None

    def put(i: int, length: float) -> None:
        nonlocal t, last_id
        starts[i], spans[i] = t, max(length, frame_s)
        t += spans[i]
        last_id = i

    for j, s in enumerate(sung):
        on_start = s["t0"] - s["on_len"]
        if j and s["first"] and s["word"] in space_of:
            if on_start - t > 2.0 * frame_s:
                rests.append((t, on_start))
            put(space_of[s["word"]], on_start - t)
        elif on_start > t + 1e-9 and last_id is not None:
            spans[last_id] += on_start - t  # a rest inside a word: what was sung holds on
            t = on_start
        voices.append((t, float(s["notes"][0]["midi"])))
        if s["on"]:
            scale = max(s["t0"] - t, frame_s * len(s["on"])) / max(s["on_len"], 1e-9)
            for i in s["on"]:
                put(i, plan[i] * frame_s * scale)
        letters = list(s["nu"])
        v0 = t
        v_end = max(s["end"] - s["co_len"], t + least)
        for i in letters:
            put(i, (v_end - v0) / max(len(letters), 1))
        if letters:
            vowel_spans.append((v0, t))
        for nt in s["notes"][1:]:
            voices.append((float(nt["t"]), float(nt["midi"])))
        if s["co"]:
            scale = s["co_len"] / max(spoken(s["co"]), 1e-9)
            for i in s["co"]:
                put(i, plan[i] * frame_s * scale)
    end = len(plan) - 1
    starts[end], spans[end] = t, plan[end] * frame_s
    # whole frames, each boundary rounded where it falls (so the error never gathers), each id at least one
    bounds = [round((starts[i] - origin) / frame_s) for i in range(len(plan))]
    bounds.append(round((t + spans[end] - origin) / frame_s))
    frames = [max(bounds[i + 1] - bounds[i], 1) for i in range(len(plan))]
    vowels = [(round((a - origin) / frame_s), round((b - origin) / frame_s)) for a, b in vowel_spans]
    return {"frames": frames, "origin": origin, "voices": voices, "rests": rests, "vowels": vowels,
            "sung": [{"word": s["word"], "t": s["t0"]} for s in sung]}


def ornament(midi: list[float], step: float, held: list[float], style: dict, seed: int = 0) -> list[float]:
    """The pitch a singer gives `midi` (a value each `step` seconds; `held` how long the note at each step has been
    held, in seconds): a damped glide into each change of note, vibrato on a note held long, a slow drift - all scaled
    out by `style.tune` toward 1, a hard-tuned step."""
    tune = min(max(float(style.get("tune", 0.0)), 0.0), 1.0)
    n = len(midi)
    if n == 0:
        return []
    out = list(midi)
    if tune < 1.0:
        w = 2.0 * math.pi * float(style.get("glide_hz", 6.0)) * (1.0 + 6.0 * tune)
        z = float(style.get("damping", DAMPING)) + (1.0 - float(style.get("damping", DAMPING))) * tune
        z = min(z, 0.999)
        r = math.exp(-z * w * step)
        th = w * math.sqrt(1.0 - z * z) * step
        a1, a2 = 2.0 * r * math.cos(th), -r * r
        g = 1.0 - a1 - a2
        lead = int(round((2.0 * z / w) / step))  # the response's lag, taken back so a change lands on its note
        src = midi[lead:] + [midi[-1]] * lead
        y1 = y2 = src[0]
        for i in range(n):
            y = a1 * y1 + a2 * y2 + g * src[i]
            out[i] = y
            y2, y1 = y1, y
    depth = float(style.get("vibrato", 0.3)) * (1.0 - tune)
    rate = float(style.get("vibrato_rate", 5.5))
    wait = float(style.get("vibrato_delay", 0.28))
    drift = float(style.get("drift", 0.08)) * (1.0 - tune)
    rnd = _Lcg(seed)
    walk = 0.0
    phase = rnd.next() * 6.283
    for i in range(n):
        if held[i] < step * 0.5:
            phase = rnd.next() * 6.283  # each note's vibrato starts where it will
        ramp = min(max((held[i] - wait) / 0.2, 0.0), 1.0)
        walk = walk * 0.97 + (rnd.next() - 0.5) * 0.06
        out[i] += depth * ramp * math.sin(2.0 * math.pi * rate * held[i] + phase) + drift * walk
    return out


class _Lcg:
    """A small seeded stream in [0, 1): the same take every time."""

    def __init__(self, seed: int) -> None:
        self.s = (int(seed) * 2654435761 + 1) & 0xFFFFFFFF

    def next(self) -> float:
        self.s = (1664525 * self.s + 1013904223) & 0xFFFFFFFF
        return self.s / 4294967296.0


def seam_pitch(f0, keep, planned, steps: int = SEAM):
    """No step where a sung pitch meets Kokoro's own: where the sung curve gives way to a voiced planned value (or takes
    over from one), the two are crossed over `steps` steps in the log domain. A switch to an unvoiced plan is left
    as it is - voicing starting and stopping is speech's own."""
    import numpy as np

    out = np.array(f0, dtype=float)
    n = len(out)
    for i in range(1, n):
        if bool(keep[i]) == bool(keep[i - 1]):
            continue
        a, b = (i - 1, i)
        if min(planned[a], planned[b]) < VOICED and (keep[a] and planned[a] < VOICED or keep[b] and planned[b] < VOICED):
            continue
        lo, hi = max(0, i - steps), min(n, i + steps)
        x0, x1 = np.log(max(out[lo], 1.0)), np.log(max(out[hi - 1], 1.0))
        for j in range(lo, hi):
            u = (j - lo) / max(hi - lo - 1, 1)
            w = 0.5 - 0.5 * np.cos(np.pi * u)
            out[j] = float(np.exp(x0 + (x1 - x0) * w))
    return out


def seam_energy(told, planned, steps: int = SEAM):
    """The energy told, its departures from Kokoro's plan (a held vowel's hold, its lift) eased in and out over `steps`
    steps (a Hann window) rather than stepped: a step in what the decoder is told is a click in what it makes."""
    import numpy as np

    told = np.asarray(told, dtype=float)
    planned = np.asarray(planned, dtype=float)
    win = np.hanning(2 * steps + 1)
    win /= win.sum()
    lift = np.convolve(told - planned, win, mode="same")
    return planned + np.maximum(lift, 0.0) + np.minimum(told - planned, 0.0)


def hz(midi: float) -> float:
    return 440.0 * 2.0 ** ((midi - 69.0) / 12.0)
