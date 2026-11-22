"""inflection.py - how a sentence's words are inflected from what its text says: a question rises at its end, a word
leaned on is drawn out and accented. Pure: rules read a sentence's tokens and say what each word does; `curve` lays
what they say on a frame plan as a pitch multiplier any graph with an F0 input reads (Kokoro's sung graph,
kokoro_sung.py: `f0_keep` fed a curve multiplies the pitch it plans, so the decoder makes the inflection itself).

    marks = plan(group, settings)     # {token: Mark}, `group` a sentence's tokens, `settings` the request's `inflect`
    keep = curve(marks, owners, frames, sounds, stress, planned)   # [2 x frames] multipliers, 1 where no rule speaks
    f0, told, loud = voiced(marks, owners, frames, vowels, stress, planned, keep)   # the pitch, where a mark voices
    energy = lifted(energy_planned, loud, planned)   # ...its stressed vowel as loud as the call's voiced steps

A RULE IS A ROW of RULES (`label`, `blurb`, `fields` with each default, `fn`): `fn(group, fields) -> {token: Mark}`.
A new heuristic is a row and a function; nothing else changes. Marks from every rule on one word are combined: the
pitch shapes each read and added, the stretches multiplied, the most flattening kept.

A Mark is what one word does:
- `pitch`: keyframes [(at, semitones)] across the word's sounds: `at` 0 its first sound's start, 1 its last sound's
  end, or an ANCHOR on its stressed vowel - "stress<" its start, "stress" its middle, "stress>" its end (the vowel is
  where a pitch move is heard: on a stop or in the rest after, it is not). Between keyframes the value eases
  (smoothstep); before the first it holds to the word's start; after the last it holds to the next word's first sound
  (the rest after it, or the end of the take).
- `flatten`: how much of the model's own pitch movement on the word is taken out (0 none, 1 all), pulled to what it
  plans before the stressed vowel, so the shape is the word's contour rather than a bend of the model's (a sentence's
  last word falls as a statement's: a question's rise on top of it is heard flat). Needs the planned pitch.
- `voice`: where the model plans the word's vowels unvoiced from its stressed one on (a breathy voice whispers a
  sentence's last word), they are voiced at the pitch the shapes ask for, from the word's own pitch before its
  stressed vowel or the sentence's just before the word (`voiced`): a whispered vowel has no pitch to move.
- `slow`: every sound of the word held this much longer (its pace).
- `stretch`: its stressed vowel held this much longer, on top. With inflection on, the rules' stretches are all a word
  has: the backend's own emphasis stretch is not added.

Outside a marked word the curve is 1 (the model's own pitch), and the whole is eased over SMOOTH steps so no rule
makes a step the decoder would click on. `settings` is True (every rule at its defaults), False/None (none), or
{rule: True, False or {field: value}}: a rule left out is on.
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field

# Curve steps (12.5 ms each, two a duration frame) the pitch curve is eased over: a Hann window of about 90 ms.
SMOOTH = 7
# Hz under which a planned pitch is unvoiced (singing.py's VOICED), and the share of a word's median pitch a step must
# reach to be read as voiced by flattening (a step on the edge of voicing reads a few tens of Hz).
VOICED = 40.0
VOICED_SHARE = 0.5
# The most flattening moves a step, in semitones either way.
FLATTEN_MOST = 6.0
# A voiced step's energy is raised to the call's median voiced energy less this (the curve's own log units).
ENERGY_UNDER = 0.5
ANCHORS = ("stress<", "stress", "stress>")
# Penn tags of a wh-word, and of what may stand before one at the front of a wh-question (conjunction, preposition,
# interjection, adverb, a comma).
WH_TAGS = frozenset({"WDT", "WP", "WP$", "WRB"})
FRONT_TAGS = frozenset({"CC", "IN", "UH", "RB", ","})


@dataclass
class Mark:
    pitch: list = field(default_factory=list)  # [(at, semitones)], at in 0..1 or an anchor
    slow: float = 1.0
    stretch: float = 1.0
    flatten: float = 0.0
    more: list = field(default_factory=list)  # other rules' shapes on the same word, each read alone and added
    voice: bool = False

    def add(self, other: "Mark") -> "Mark":
        return Mark(self.pitch, self.slow * other.slow, self.stretch * other.stretch,
                    max(self.flatten, other.flatten), self.more + ([other.pitch] if other.pitch else []) + other.more,
                    self.voice or other.voice)

    def shapes(self) -> list:
        return [sh for sh in [self.pitch, *self.more] if sh]


def _last_word(group: list) -> int:
    """The last token of `group` with words in it, -1 if none."""
    for ti in range(len(group) - 1, -1, -1):
        if str(group[ti].get("text", "")).strip():
            return ti
    return -1


def _end_mark(group: list) -> str:
    for t in reversed(group):
        p = str(t.get("punct", ""))
        if p:
            return p
    return ""


def wh_question(group: list) -> bool:
    """Whether a sentence asks with a wh-word in front ("Where did you put them?", "And how?", "In which room?"): its
    first wh-tagged word (Penn WDT, WP, WP$, WRB: the tokens' `pos`, homographs.py) with nothing before it but
    conjunctions, prepositions, interjections and adverbs. A wh-word later on is not one: an echo ("You did what?"),
    a question about a clause ("Do you know where he went?"), a relative ("The man that came is here?"). False where
    the sentence was not tagged."""
    for t in group:
        if not str(t.get("text", "")).strip():
            continue
        pos = str(t.get("pos", ""))
        if pos in WH_TAGS:
            return True
        if not pos or pos not in FRONT_TAGS:
            return False
    return False


def question(group: list, f: dict) -> dict:
    """A sentence that ends on "?" rises on its last word (a low rise): its own fall flattened, a small dip at the start
    of its stressed vowel, `on_vowel` of `rise` semitones by that vowel's end and the rest by the word's, held into
    the rest. The word keeps its length: the trail already holds a sentence's last word (`slow`, `stretch` 1), and
    its vowels are voiced where the model would whisper them (`voice`). A wh-question (`wh_question`) rises `wh` of
    that: none by default, falling as a statement does."""
    if "?" not in _end_mark(group):
        return {}
    ti = _last_word(group)
    if ti < 0:
        return {}
    share = float(f["wh"]) if wh_question(group) else 1.0
    if share <= 0.0:
        return {}
    rise = float(f["rise"]) * share
    return {ti: Mark(pitch=[(0.0, 0.0), ("stress<", -float(f["dip"])), ("stress>", rise * float(f["on_vowel"])),
                            (1.0, rise)],
                     slow=float(f["slow"]), stretch=float(f["stretch"]), flatten=float(f["flatten"]),
                     voice=float(f["voice"]) > 0.0)}


def emphasis(group: list, f: dict) -> dict:
    """A word leaned on (`emph`: `*italic*` 1, `**bold**` 2, both 3) is accented: its pitch up to `accent` semitones
    at its stressed vowel and back under where it was by its end, every sound `slow` times longer and the stressed
    vowel `stretch` on top (all the lengthening it has: with inflection on, the backend's own `EMPHASIS` stretch is
    not added). Bold is `bold` times all of it. A sentence's last word keeps `final` of the lengthening: the trail
    already holds it."""
    out = {}
    last = _last_word(group)
    for ti, t in enumerate(group):
        level = int(t.get("emph", 0) or 0)
        if level <= 0:
            continue
        k = 1.0 if level == 1 else float(f["bold"])
        held = k * (float(f["final"]) if ti == last else 1.0)
        out[ti] = Mark(pitch=[("stress<", 0.0), ("stress", float(f["accent"]) * k), (1.0, -float(f["fall"]) * k)],
                       slow=1.0 + (float(f["slow"]) - 1.0) * held, stretch=1.0 + (float(f["stretch"]) - 1.0) * held)
    return out


RULES: dict = {
    "question": {
        "label": "Question",
        "blurb": "A sentence ending in a question mark rises on its last word, unless it asks with a wh-word in front.",
        "fields": {"rise": 6.0, "dip": 0.7, "on_vowel": 1.0, "flatten": 0.8, "slow": 1.0, "stretch": 1.0, "wh": 0.0,
                   "voice": 1.0},
        "fn": question,
    },
    "emphasis": {
        "label": "Emphasis",
        "blurb": "An italic or bold word is accented at its stressed vowel and drawn out.",
        "fields": {"accent": 3.0, "fall": 1.0, "slow": 1.12, "stretch": 1.5, "bold": 1.5, "final": 0.3},
        "fn": emphasis,
    },
}


def plan(group: list, settings) -> dict:
    """{token index: Mark} for one sentence, every rule `settings` leaves on combined."""
    if not settings:
        return {}
    told = settings if isinstance(settings, dict) else {}
    out: dict = {}
    for key, row in RULES.items():
        own = told.get(key, True)
        if own is False:
            continue
        fields = {**row["fields"], **(own if isinstance(own, dict) else {})}
        for ti, m in row["fn"](group, fields).items():
            out[ti] = out[ti].add(m) if ti in out else m
    return out


def _ease(x: float) -> float:
    x = min(max(x, 0.0), 1.0)
    return x * x * (3.0 - 2.0 * x)


def shape_at(keys: list, u: float) -> float:
    """A word's keyframes (`at` resolved to 0..1) read at `u`: eased between, held past the ends."""
    if not keys:
        return 0.0
    if u <= keys[0][0]:
        return keys[0][1]
    for (a, sa), (b, sb) in zip(keys, keys[1:]):
        if u <= b:
            return sa + (sb - sa) * (_ease((u - a) / (b - a)) if b > a else 1.0)
    return keys[-1][1]


def curve(marks: dict, owners: list, frames: list, sounds: list, stress: dict | None = None, planned=None,
          lead: int = 0):
    """The pitch multiplier for one call, two steps a frame: `owners` the token each id is of (-1 a pad or what is not
    the sentence's), `frames` each id's planned frames, `sounds` whether each id is heard, `stress` {token: (first id,
    last id) of its stressed vowel}, `planned` the model's pitch a step (Hz; None: nothing is flattened), `lead` the
    steps a sound is heard before its plan says (Kokoro voices a sound about 50 ms early, while the pitch it is fed is
    heard where it is fed): the shapes are laid that much earlier, the flattening where the plan has it. 1 everywhere
    no mark moves the pitch; None where nothing is marked to."""
    import numpy as np

    if not any(m.shapes() or (m.flatten > 0.0 and planned is not None) for m in marks.values()):
        return None
    starts = np.concatenate(([0.0], np.cumsum(np.asarray(frames, dtype=np.float64))))
    steps = int(round(starts[-1])) * 2
    semis = np.zeros(steps)
    shaped = np.zeros(steps)  # the shapes, laid `lead` steps early after
    f0 = None
    if planned is not None:
        f0 = np.asarray(planned, dtype=np.float64).ravel()
        f0 = f0[:steps] if f0.size >= steps else np.pad(f0, (0, steps - f0.size))
    heard = [k for k, s in enumerate(sounds) if s]
    for ti, m in marks.items():
        mine = [k for k in heard if owners[k] == ti]
        if not mine:
            continue
        a, b = starts[mine[0]], starts[mine[-1] + 1]
        nxt = next((k for k in heard if k > mine[-1] and owners[k] != ti), None)
        reach = starts[nxt] if nxt is not None else starts[-1]
        if b <= a:
            continue
        at_of = {"stress<": 0.5, "stress": 0.5, "stress>": 0.5}
        if stress and ti in stress:
            v0, v1 = stress[ti]
            at_of = {"stress<": (starts[v0] - a) / (b - a), "stress": ((starts[v0] + starts[v1 + 1]) / 2.0 - a) / (b - a),
                     "stress>": (starts[v1 + 1] - a) / (b - a)}
        lo, hi = int(math.floor(a * 2)), min(steps, int(math.ceil(reach * 2)))
        u = ((np.arange(lo, hi) + 0.5) / 2.0 - a) / (b - a)
        for sh in m.shapes():
            keys = sorted((min(max(at_of[at] if at in at_of else float(at), 0.0), 1.0), float(v)) for at, v in sh)
            shaped[lo:hi] += [shape_at(keys, x) for x in u]
        if m.flatten > 0.0 and f0 is not None:
            # read on the word's own sounds alone (what follows in the call may be another sentence's), held after
            end = max(lo + 1, min(hi, int(math.ceil(b * 2))))
            flat = _flattened(f0[lo:end], u[:end - lo], at_of["stress<"], float(m.flatten))
            semis[lo:end] += flat
            semis[end:hi] += flat[-1]
    if lead > 0:
        shaped = np.concatenate((shaped[lead:], np.full(min(lead, steps), shaped[-1] if steps else 0.0)))[:steps]
    semis += shaped
    if SMOOTH > 1:
        w = np.hanning(SMOOTH + 2)[1:-1]
        w /= w.sum()
        pad = SMOOTH // 2
        semis = np.convolve(np.pad(semis, pad, mode="edge"), w, mode="valid")[:steps]
    return (2.0 ** (semis / 12.0)).astype(np.float32)


def _flattened(f0, u, onset: float, amount: float):
    """Semitones a step that pull a word's voiced pitch `amount` of the way to what it is planned before its stressed
    vowel (`onset`, in the word's 0..1; its first voiced steps where none are before it), unvoiced steps carried over
    from the voiced ones beside them. Zeros where it has under two voiced steps."""
    import numpy as np

    over = f0[f0 > VOICED]
    if over.size < 2:
        return np.zeros(f0.size)
    voiced = np.nonzero(f0 > max(VOICED, VOICED_SHARE * float(np.median(over))))[0]
    if voiced.size < 2:
        return np.zeros(f0.size)
    before = voiced[u[voiced] < onset]
    ref = float(np.median(f0[before])) if before.size >= 2 else float(np.median(f0[voiced[:3]]))
    st = np.clip(amount * 12.0 * np.log2(ref / f0[voiced]), -FLATTEN_MOST, FLATTEN_MOST)
    return np.interp(np.arange(f0.size), voiced, st)


def voiced(marks: dict, owners: list, frames: list, vowels, stress: dict | None, planned, keep, lead: int = 0):
    """The pitch a step (Hz) to feed in place of `planned` times `keep`, where a mark that `voice`s finds its word's
    vowels from its stressed one on planned unvoiced: those steps (laid `lead` early, as the shapes are) at the base
    pitch times `keep`, the base the word's voiced pitch before its stressed vowel or the last voiced before the word;
    the joins eased (singing.seam_pitch). `vowels` the ids that are vowels. (the pitch, the steps voiced, the steps of
    the stressed vowel among them - what `lifted` makes loud: a vowel after it keeps its planned energy, so a word's
    tail that dies away still does), or None where nothing is voiced."""
    import numpy as np

    import singing

    if planned is None or keep is None or not any(m.voice for m in marks.values()):
        return None
    f0 = np.asarray(planned, dtype=np.float64).ravel()
    steps = len(keep)
    f0 = f0[:steps] if f0.size >= steps else np.pad(f0, (0, steps - f0.size))
    keep = np.asarray(keep, dtype=np.float64)
    starts = np.concatenate(([0.0], np.cumsum(np.asarray(frames, dtype=np.float64))))
    out = f0 * keep
    told = np.zeros(steps, dtype=bool)
    loud = np.zeros(steps, dtype=bool)
    for ti, m in marks.items():
        if not m.voice:
            continue
        mine = [k for k in range(len(owners)) if owners[k] == ti]
        if not mine:
            continue
        first = stress[ti][0] if stress and ti in stress else mine[0]
        last = stress[ti][1] if stress and ti in stress else first
        at = [k for k in mine if k >= first and k in vowels]
        lo_word = int(math.floor(starts[mine[0]] * 2))
        cut = int(math.floor(starts[first] * 2))
        before = f0[lo_word:cut]
        before = before[before > VOICED]
        if before.size < 2:
            earlier = f0[:lo_word]
            before = earlier[earlier > VOICED][-6:]
        if before.size < 2:
            continue
        base = float(np.median(before))
        for k in at:
            for j in range(int(math.floor(starts[k] * 2)), min(steps, int(math.ceil(starts[k + 1] * 2)))):
                j_heard = max(0, j - lead)
                if f0[j] < VOICED:
                    told[j_heard] = True
                    loud[j_heard] = k <= last
                    out[j_heard] = base * keep[j_heard]
    if not told.any():
        return None
    return singing.seam_pitch(out, told, f0).astype(np.float32), told, loud


def lifted(energy, told, planned):
    """The model's energy curve with the steps `told` (`voiced`'s stressed vowel) raised to the call's typical voiced energy (less
    ENERGY_UNDER), eased in and out (singing.seam_energy): the decoder voices a vowel only while it is told it is loud,
    and a whispered one is planned quiet."""
    import numpy as np

    import singing

    n = np.asarray(energy, dtype=np.float64).ravel()
    f0 = np.asarray(planned, dtype=np.float64).ravel()[:n.size]
    told = np.asarray(told, dtype=bool)[:n.size]
    loud = n[:f0.size][f0 > VOICED]
    if loud.size < 4:
        return n.astype(np.float32)
    target = float(np.median(loud)) - ENERGY_UNDER
    out = n.copy()
    out[:told.size][told] = np.maximum(n[:told.size][told], target)
    return singing.seam_energy(out, n).astype(np.float32)
