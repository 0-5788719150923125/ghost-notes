#!/usr/bin/env python3
"""singing.py and the graph made to sing (kokoro_sung.py), held.

    <voice_venv>/bin/python test_singing.py

Held:
- syllables: a word's symbols split at its vowels, the consonants between two going to the second as far as English
  lets a syllable begin ("wˈɛl|kəm", "kən|sˈɛp|ʧu|əl"), a stress mark riding with its vowel, ŋ never beginning one;
- match: one note a syllable; a note shared where there are more syllables (its time split); a syllable held over
  several notes where there are fewer;
- lay: every id at least one frame and the frames whole; each sung vowel begins within half a frame of its note, its
  consonants before it (the onset sung before the beat); a rest between two words is a rest; the control - the same
  words a beat later move every vowel a beat later;
- ornament: at `tune` 1 the pitch is the notes' exactly; at 0 a change of note overshoots and settles, and a held note
  sways (vibrato) within its depth;
- where Kokoro's graph is installed, the graph made to sing renders, unfed, what the stock graph renders, sample for
  sample (kokoro_sung.check), and its curve graph hands back as many F0 steps as twice the frames it was told.
"""

import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import singing  # noqa: E402

FAILS = 0


def ok(cond: bool, what: str) -> None:
    global FAILS
    print(("  ok   " if cond else "  FAIL ") + what)
    if not cond:
        FAILS += 1


def split(word: str) -> str:
    syms = list(word)
    return "|".join("".join(syms[i] for i in s["on"] + s["nu"] + s["co"]) for s in singing.syllabify(syms))


def main() -> int:
    print("-- syllables")
    ok(split("wˈɛlkəm") == "wˈɛl|kəm", "welcome: %s" % split("wˈɛlkəm"))
    ok(split("kənsˈɛpʧuəl") == "kən|sˈɛp|ʧu|əl", "conceptual: %s" % split("kənsˈɛpʧuəl"))
    ok(split("sˈɪŋəɹ") == "sˈɪŋ|əɹ", "singer: ŋ never begins a syllable (%s)" % split("sˈɪŋəɹ"))
    ok(split("ɛkstɹə") == "ɛk|stɹə", "extra: the longest onset English allows (%s)" % split("ɛkstɹə"))
    ok(len(singing.syllabify(list("ʃ"))) == 1, "a word with no vowel is one syllable")

    print("-- match")
    n = [{"t": 0.0, "len": 0.5, "midi": 60}, {"t": 0.5, "len": 0.5, "midi": 62}]
    ok([len(x) for x in singing.match(2, n)] == [1, 1], "one note a syllable")
    m3 = singing.match(3, n)
    ok(len(m3) == 3 and abs(m3[0][0]["len"] + m3[1][0]["len"] - 0.5) < 1e-9 and m3[0][0]["midi"] == m3[1][0]["midi"],
       "more syllables: a note's time split between two")
    ok([len(x) for x in singing.match(1, n)] == [2], "fewer syllables: one held over both notes")

    print("-- lay")
    fr = 0.025
    words = [list("wˈɛlkəm"), list("jˈuzəɹ")]
    notes = [[{"t": 0.0, "len": 0.3, "midi": 64}, {"t": 0.3, "len": 0.3, "midi": 62}],
             [{"t": 1.0, "len": 0.5, "midi": 60}, {"t": 1.5, "len": 0.8, "midi": 60}]]
    ids = 1 + len(words[0]) + 1 + len(words[1]) + 1
    plan = [10.0] + [2.0] * (ids - 2) + [6.0]
    laid = singing.lay(words, notes, plan, fr)
    frames = laid["frames"]
    ok(len(frames) == ids and all(isinstance(f, int) and f >= 1 for f in frames), "every id whole frames, at least one")
    starts = [laid["origin"] + sum(frames[:i]) * fr for i in range(len(frames))]
    vowels = [s["t"] for s in laid["sung"]]
    firsts = [laid["origin"] + a * fr for a, _b in laid["vowels"]]
    ok(all(abs(a - b) <= fr * 0.75 for a, b in zip(firsts, vowels)), "each vowel begins on its note: %s against %s" % (
        [round(x, 3) for x in firsts], vowels))
    ok(starts[1] < 0.0, "the first onset is sung before the beat (it starts at %.3f s)" % starts[1])
    ok(any(a < 0.95 and b > 0.7 for a, b in laid["rests"]), "the gap between the words is a rest: %s" % laid["rests"])
    later = [[{**x, "t": x["t"] + 0.5} for x in w] for w in notes]
    laid2 = singing.lay(words, later, plan, fr)
    moved = [laid2["origin"] + a * fr - (laid["origin"] + b * fr) for (a, _), (b, _) in zip(laid2["vowels"], laid["vowels"])]
    ok(all(abs(d - 0.5) <= fr for d in moved), "the control: the notes half a second later move every vowel with them")

    print("-- ornament")
    step = 0.0125
    midi = [60.0] * 40 + [64.0] * 120
    held = [i * step for i in range(40)] + [i * step for i in range(120)]
    hard = singing.ornament(midi, step, held, {"tune": 1.0})
    ok(all(abs(a - b) < 1e-9 for a, b in zip(hard, midi)), "tune 1: the notes exactly")
    soft = singing.ornament(midi, step, held, {"tune": 0.0, "vibrato": 0.3, "drift": 0.0})
    ok(max(soft[40:70]) > 64.05, "tune 0: the change overshoots (peak %.2f)" % max(soft[40:70]))
    late = soft[110:]
    ok(max(late) - min(late) > 0.3 and max(abs(x - 64.0) for x in late) < 0.45, "a held note sways within its depth")

    print("-- the graph that sings")
    home = Path.home() / ".local/share/ghost/voices/kokoro"
    stock = home / "model.onnx"
    if not stock.exists():
        print("  skip: Kokoro is not installed here")
    else:
        import kokoro_sung
        import numpy as np
        import onnxruntime as ort

        with tempfile.TemporaryDirectory() as d:
            sung, curves = Path(d) / "sung.onnx", Path(d) / "curves.onnx"
            ok(kokoro_sung.make(stock, sung), "made from the installed graph, and unfed it renders the stock graph's samples")
            ok(kokoro_sung.curves(sung, curves), "cut to its curves")
            opts = ort.SessionOptions()
            opts.log_severity_level = 3
            sess = ort.InferenceSession(str(curves), sess_options=opts, providers=["CPUExecutionProvider"])
            ids = np.array([[0, 50, 156, 102, 54, 16, 65, 156, 51, 54, 4, 0]], dtype=np.int64)
            told = np.full((1, ids.shape[1]), 3.0, np.float32)
            got = sess.run(None, {"input_ids": ids, "style": np.zeros((1, 256), np.float32), "speed": np.ones(1, np.float32),
                                  "dur_scale": np.zeros((1, ids.shape[1]), np.float32), "rest_floor": told})
            ok(got[0].size == 2 * int(told.sum()), "its F0 is two steps a told frame (%d for %d frames)" % (got[0].size, int(told.sum())))
    print("test_singing: %s" % ("ALL OK" if FAILS == 0 else "%d FAILED" % FAILS))
    return 1 if FAILS else 0


if __name__ == "__main__":
    raise SystemExit(main())
