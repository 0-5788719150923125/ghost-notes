#!/usr/bin/env python3
"""Tests for inflection.py: the rules and the curve they are laid on (no model).

    ~/.local/share/godot/app_userdata/ghost/voice_venv/bin/python hosts/voice/test_inflection.py

Held, each with the case that must not change:

  1. a question marks its last word alone (a full stop marks nothing; a trailing token with no words is passed over);
     a wh-question in front falls (no mark), with a conjunction, preposition or adverb before its wh-word, and
     rises at `wh` of the rise where set; an echo, a wh-word in a clause or a relative, and an untagged sentence rise;
  2. emphasis marks each leaned-on word, bold more than italic, an unmarked word nothing; a question keeps its last
     word's length and a sentence's last leaned-on word keeps less of its lengthening (the trail holds it already);
  3. settings: off is nothing, a rule turned off is gone, a field set is used, a rule left out is on;
  4. the curve is 1 outside a marked word, and None where nothing moves the pitch;
  5. a question's curve rises through its stressed vowel ("stress<" to "stress>") and holds into the rest after; a
     lead lays it earlier by that many steps (where the model voices a sound before its plan);
  6. an accent peaks on the stressed vowel, not at the word's middle;
  7. flattening takes a planned fall out of the word (and leaves an unflattened word's alone), never reads what follows
     the word in the call or a step on the edge of voicing, moves no step past FLATTEN_MOST, and the curve has no step a
     decoder would click on;
  8. a word whose vowels the plan whispers is voiced where a mark asks (at its base pitch times the curve, from its
     stressed vowel on, louder to the call's voiced energy), and a voiced word or a mark that does not voice is left
     to the plan;
  9. the script overrides word by word: "none" unmarks (a question, a leaned-on word), "rise" gives the last word of
     each run a question's rise (a wh-question, a run mid-sentence), by the question rule's fields.
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import numpy as np  # noqa: E402

import inflection  # noqa: E402
from inflection import Mark  # noqa: E402

FAILS: list = []


def check(ok: bool, what: str) -> None:
    print(("ok   " if ok else "FAIL ") + what)
    if not ok:
        FAILS.append(what)


def words(line: str) -> list:
    out = []
    for w in line.split():
        level = len(w) - len(w.lstrip("*"))
        body = w.strip("*")
        punct = body[len(body.rstrip(".,?!")):]
        out.append({"text": body.rstrip(".,?!"), "punct": punct, **({"emph": level} if level else {})})
    return out


def tagged(pairs: str) -> list:
    """'where/WRB did/VBD it/PRP go/VB?' as tokens with their `pos`."""
    out = []
    for w in pairs.split():
        punct = "?" if w.endswith("?") else ""
        text, pos = w.rstrip("?").split("/")
        out.append({"text": text, "punct": punct, "pos": pos})
    return out


def wh() -> None:
    falls = ("where/WRB did/VBD you/PRP put/VB them/PRP?", "and/CC how/WRB did/VBD you/PRP know/VB?",
             "in/IN which/WDT room/NN is/VBZ it/PRP?", "so/RB where/WRB are/VBP we/PRP?", "why/WRB not/RB?")
    for line in falls:
        check(inflection.plan(tagged(line), True) == {}, f"a wh-question falls: {line}")
    rises = ("you/PRP did/VBD what/WP?", "do/VB you/PRP know/VB where/WRB he/PRP went/VBD?",
             "the/DT man/NN that/WDT came/VBD is/VBZ here/RB?", "is/VBZ it/PRP raining/VBG?")
    for line in rises:
        check(bool(inflection.plan(tagged(line), True)), f"...and this one rises: {line}")
    check(bool(inflection.plan(words("where did you put them?"), True)), "an untagged sentence rises")
    some = inflection.plan(tagged(falls[0]), {"question": {"wh": 0.5}})
    check(bool(some) and some[4].pitch[-1][1] == 3.0, "a wh-question rises `wh` of the rise where set")


def rules() -> None:
    q = inflection.plan(words("did you see it?"), True)
    check(list(q) == [3], "a question marks its last word alone")
    check(q[3].pitch[-1][1] > 0 and q[3].flatten > 0, "...rising, its own fall flattened")
    check(inflection.plan(words("you saw it."), True) == {}, "a statement marks nothing")
    trailing = words("did you see it") + [{"text": "", "punct": "?"}]
    check(list(inflection.plan(trailing, True)) == [3], "a trailing token with no words is passed over")
    e = inflection.plan(words("I said *she* did **that** today."), True)
    check(sorted(e) == [2, 4], "emphasis marks each leaned-on word")
    peak = lambda m: max(v for _a, v in m.pitch)  # noqa: E731
    check(peak(e[4]) > peak(e[2]) and e[4].slow > e[2].slow > 1.0, "bold is more than italic")
    check(inflection.plan(words("I said she did that."), True) == {}, "an unmarked word nothing")
    check(q[3].slow == 1.0 and q[3].stretch == 1.0, "a question keeps its last word's length")
    end = inflection.plan(words("it was *real*."), True)[2]
    mid = inflection.plan(words("it was *real* enough."), True)[2]
    check(1.0 <= end.slow < mid.slow and 1.0 <= end.stretch < mid.stretch,
          "a sentence's last leaned-on word keeps less of its lengthening")


def settings() -> None:
    line = words("are you *sure*?")
    check(inflection.plan(line, False) == {} and inflection.plan(line, None) == {}, "off is nothing")
    both = inflection.plan(line, True)[2]
    check(len(both.shapes()) == 2, "two rules on one word: both shapes kept")
    only = inflection.plan(line, {"emphasis": False})[2]
    check(len(only.shapes()) == 1 and only.flatten > 0, "a rule turned off is gone")
    set_ = inflection.plan(line, {"question": {"rise": 9.0}, "emphasis": False})[2]
    check(set_.pitch[-1][1] == 9.0, "a field set is used")
    check(len(inflection.plan(line, {"question": {"rise": 9.0}})[2].shapes()) == 2, "a rule left out is on")


# a call: pad, word 0 (3 ids), word 1 (4 ids, its stressed vowel ids 5-6), a mark, pad
OWNERS = [-1, 0, 0, 0, 1, 1, 1, 1, 1, -1]
SOUNDS = [False, True, True, True, True, True, True, True, False, False]
FRAMES = [4, 3, 3, 3, 3, 3, 6, 3, 3, 6]
STRESS = {1: (5, 6)}


def step_of(k: int) -> int:
    return int(sum(FRAMES[:k])) * 2


def curves() -> None:
    check(inflection.curve({}, OWNERS, FRAMES, SOUNDS, STRESS) is None, "nothing marked: no curve")
    check(inflection.curve({1: Mark(slow=1.2)}, OWNERS, FRAMES, SOUNDS, STRESS) is None,
          "a mark with no pitch: no curve")
    q = inflection.plan(words("see it?"), {"question": {"flatten": 0.0}})
    c = inflection.curve(q, OWNERS, FRAMES, SOUNDS, STRESS)
    st = 12.0 * np.log2(c)
    check(np.allclose(st[:step_of(1)], 0.0, atol=1e-6), "1 outside the marked word")
    v0, v1 = step_of(5), step_of(7)
    check(st[v1] - st[v0] > 3.0, f"the rise is on the stressed vowel ({st[v0]:+.1f} to {st[v1]:+.1f} st)")
    check(st[-1] > 5.5, "...and holds into the rest after")
    check(st[step_of(4) + 1] < 1.0, "...not before the vowel")
    e = {1: Mark(pitch=[("stress<", 0.0), ("stress", 3.0), (1.0, -1.0)])}
    st = 12.0 * np.log2(inflection.curve(e, OWNERS, FRAMES, SOUNDS, STRESS))
    top = int(np.argmax(st))
    check(v0 <= top < v1, f"an accent peaks on the stressed vowel (step {top}, vowel {v0}-{v1})")
    middle = {1: Mark(pitch=[("stress<", 0.0), ("stress", 3.0), (1.0, -1.0)])}
    no_vowel = int(np.argmax(12.0 * np.log2(inflection.curve(middle, OWNERS, FRAMES, SOUNDS, None))))
    check(no_vowel != top, "...where a word with no stressed vowel known peaks at its middle")
    # a planned fall of 6 semitones across word 1, flat on word 0
    steps = int(sum(FRAMES)) * 2
    f0 = np.full(steps, 200.0)
    a, b = step_of(4), step_of(8)
    f0[a:b] = 200.0 * 2.0 ** (-np.linspace(0.0, 6.0, b - a) / 12.0)
    f0[b:] = 0.0
    flat = {1: Mark(flatten=1.0)}
    got = f0 * inflection.curve(flat, OWNERS, FRAMES, SOUNDS, STRESS, f0)
    span = 12.0 * np.log2(got[a + 6:b - 4].max() / got[a + 6:b - 4].min())
    check(span < 1.5, f"flattening takes the planned fall out ({span:.1f} st left of 6)")
    kept = f0 * inflection.curve({0: Mark(flatten=1.0)}, OWNERS, FRAMES, SOUNDS, STRESS, f0)
    check(np.allclose(kept[a + 8:b], f0[a + 8:b], rtol=1e-3), "...and leaves an unflattened word's alone")
    # what follows in the call (the next sentence's words, read on and cut away) and a step on the edge of voicing
    edge = f0.copy()
    edge[b - 2] = 45.0
    edge[b:] = 120.0
    st = 12.0 * np.log2(inflection.curve(flat, OWNERS, FRAMES, SOUNDS, STRESS, edge))
    check(float(np.abs(st).max()) <= inflection.FLATTEN_MOST + 1e-3,
          f"flattening reads neither what follows nor the edge of voicing (largest {np.abs(st).max():.1f} st)")
    plain = 12.0 * np.log2(inflection.curve(flat, OWNERS, FRAMES, SOUNDS, STRESS, f0))
    check(np.allclose(st[:b - 6], plain[:b - 6], atol=0.05), "...the word's own curve unchanged by them")
    on = 12.0 * np.log2(inflection.curve(q, OWNERS, FRAMES, SOUNDS, STRESS))
    early = 12.0 * np.log2(inflection.curve(q, OWNERS, FRAMES, SOUNDS, STRESS, lead=4))
    check(np.allclose(early[:-4], on[4:], atol=1e-5), "a lead lays the shapes that many steps earlier")
    jumps = np.abs(np.diff(12.0 * np.log2(inflection.curve(q, OWNERS, FRAMES, SOUNDS, STRESS))))
    check(float(jumps.max()) < 1.5, f"no step a decoder would click on (largest {jumps.max():.2f} st a step)")


def voicing() -> None:
    steps = int(sum(FRAMES)) * 2
    f0 = np.full(steps, 200.0)
    f0[:step_of(1)] = 0.0
    a, b = step_of(5), step_of(8)
    whisper = f0.copy()
    whisper[a:] = 0.0  # word 1 from its stressed vowel on, and the rest
    vowels = {5, 6}  # STRESS has word 1's stressed vowel as ids 5-6
    q = inflection.plan(words("see it?"), {"question": {"flatten": 0.0}})
    keep = inflection.curve(q, OWNERS, FRAMES, SOUNDS, STRESS, whisper)
    got = inflection.voiced(q, OWNERS, FRAMES, vowels, STRESS, whisper, keep)
    check(got is not None, "a whispered marked vowel is voiced")
    pitch, told, loud = got
    v = step_of(7)  # ids 5-6 the vowels; 7 a consonant, left whispered
    check(bool(told[a:v].all()) and not told[:a].any() and not told[v:].any(), "...on its vowels from the stressed one on")
    check(pitch[v - 1] > 200.0 * 2.0 ** (4.0 / 12.0), f"...at the base times the rise ({pitch[v - 1]:.0f} Hz)")
    check(inflection.voiced(q, OWNERS, FRAMES, vowels, STRESS, f0, keep) is None, "a voiced word is left to the plan")
    quiet = {k: Mark(pitch=m.pitch, voice=False) for k, m in q.items()}
    check(inflection.voiced(quiet, OWNERS, FRAMES, vowels, STRESS, whisper, keep) is None,
          "a mark that does not voice leaves it whispered")
    energy = np.where(whisper > 0, 1.0, -2.0)
    _p, told2, loud2 = inflection.voiced(q, OWNERS, FRAMES, vowels, {1: (5, 5)}, whisper, keep)
    six = step_of(6)
    check(bool(told2[six:step_of(7)].all()) and bool(loud2[a:six].all()) and not loud2[six:].any(),
          "...the stressed vowel made loud, a vowel after it voiced at its own energy")
    up = inflection.lifted(energy, loud, whisper)
    check(float(up[a + 2]) >= 1.0 - inflection.ENERGY_UNDER - 1e-3 and float(up[2]) == -2.0,
          "the voiced steps are raised to the call's voiced energy, the rest kept")


def script() -> None:
    told = words("am I fired?")
    for t in told:
        t["inflect"] = "none"
    check(inflection.plan(told, True) == {}, "a question the script says to inflect none does not rise")
    check(bool(inflection.plan(words("am I fired?"), True)), "...and unmarked, it does (the control)")
    lean = words("I said *she* did.")
    lean[2]["inflect"] = "none"
    check(inflection.plan(lean, True) == {}, "a leaned-on word the script says to inflect none is not accented")
    wh = tagged("then/RB who/WP did/VBD I/PRP flash/VB?")
    check(inflection.plan(wh, True) == {}, "a wh-question falls (the control)")
    for t in wh:
        t["inflect"] = "rise"
    up = inflection.plan(wh, True)
    check(list(up) == [4] and up[4].pitch[-1][1] == 6.0, "...and rises on its last word where the script says rise")
    run = words("he went home and slept.")
    for t in run[:3]:
        t["inflect"] = "rise"
    check(list(inflection.plan(run, True)) == [2], "a rise run rises on its own last word, mid-sentence")
    some = inflection.plan(wh, {"question": {"rise": 3.0}})
    check(some[4].pitch[-1][1] == 3.0, "...by the question rule's fields as set")


if __name__ == "__main__":
    rules()
    wh()
    settings()
    curves()
    voicing()
    script()
    print(f"\n{len(FAILS)} failed" if FAILS else "\nall passed")
    raise SystemExit(1 if FAILS else 0)
