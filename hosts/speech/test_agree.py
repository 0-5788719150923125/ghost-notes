#!/usr/bin/env python3
"""Tests for agree.py: each sentence cut to the words its own sound says.

Run it directly with the speech venv's python - no pytest needed, no model loaded (a hearing is faked):

    ~/.local/share/godot/app_userdata/ghost/speech_venv/bin/python hosts/speech/test_agree.py

  THE RUN THEY AGREE ON - a sentence whose sound has a word before its text and lacks its text's last word keeps the
  words both say, in order (CONTROL: under LEAST words, or a word heard less than SURE, none is kept).
  CUT IN THE QUIET - between the run and the word beside it, the quietest 10 ms (a word's time on soft speech runs late,
  so never at the word's own edge).
  KEPT ONLY WHERE IT IS SAID - a cut whose last hearing is its text is kept, with its seconds and its words' marks; one
  whose last hearing is not, is not (CONTROL).
"""

from __future__ import annotations

import sys
import types
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import numpy as np  # noqa: E402

import agree as A  # noqa: E402

CHECKS = []


def check(fn):
    CHECKS.append(fn)
    return fn


def ok(cond, what):
    assert cond, what
    print("    ok   " + what)


def word(text, start, end, p=0.9):
    return types.SimpleNamespace(word=" " + text, start=start, end=end, probability=p)


@check
def the_run_they_agree_on():
    tokens = "be acting as your assistant, I'll be writing".split()
    heard = [word("I'll", 0.1, 0.3), word("be", 0.35, 0.5), word("acting", 0.5, 0.9), word("as", 0.9, 1.0),
             word("your", 1.0, 1.2), word("assistant", 1.2, 1.8), word("and", 1.9, 2.0)]
    got = A.run_of(tokens, heard)
    ok(got == (0, 1, 5), "the words both say, in order: text from 0, heard from 1, five of them (%s)" % (got,))
    ok(A.run_of(tokens, heard[:3]) is None, "CONTROL: two words agreeing are too few")
    shaky = [*heard[:3], word("as", 0.9, 1.0, p=0.2), *heard[4:]]
    ok(A.run_of(tokens, shaky) is None or A.run_of(tokens, shaky)[2] < 5, "CONTROL: a word heard unsurely is not agreed on")


@check
def cut_in_the_quiet():
    sr = 24000
    y = np.full(sr, 0.1, np.float32)
    y[int(0.42 * sr): int(0.43 * sr)] = 0.0  # the one quiet moment between two words
    at = A.quietest(y, sr, 0.30, 0.60)
    ok(abs(at - 0.42) < 0.011, "the cut is the quietest 10 ms between them (%.2f s)" % at)


@check
def kept_only_where_it_is_said():
    sr = 16000
    y = np.zeros(sr * 3, np.float32)
    y[int(0.2 * sr): int(2.6 * sr)] = 0.1
    tokens = "already had him sign waivers.".split()
    hearings = {"first": [word("I've", 0.2, 0.4), word("already", 0.5, 0.9), word("had", 0.9, 1.1), word("him", 1.1, 1.3),
                          word("sign", 1.3, 1.6), word("waivers", 1.6, 2.2)]}

    class Model:
        """A hearing faked: the whole clip as above; a cut of it, its words as the text."""

        def __init__(self, last):
            self.last = last

        def transcribe(self, audio, **_):
            secs = len(audio) / A.SR16
            if secs > 2.9:
                words = hearings["first"]
            else:
                words = [word(w, 0.05 + 0.3 * k, 0.3 + 0.3 * k) for k, w in enumerate(self.last)]
            return [types.SimpleNamespace(words=words)], None

    got = A.agree(Model(["already", "had", "him", "sign", "waivers"]), y, sr, tokens, passes=1)
    ok(got is not None and got[2] == tokens and 0.4 <= got[0] <= 0.5, "cut past the word the text lacks, its words and mark kept (%s)" % (got,))
    bad = A.agree(Model(["already", "had", "him", "sign"]), y, sr, tokens, passes=1)
    ok(bad is None, "CONTROL: a cut whose last hearing is not its text is not kept")


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
    sys.exit(main())
