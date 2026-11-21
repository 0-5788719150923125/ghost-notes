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
- a voice sung at another size (a Tone's `semis`, host._sung_at_size): a stand-in singer told a phrase sings a pure tone
  at the pitch and for the time it is told; three semitones larger, it is told the phrase three higher and quicker and
  what comes back is at the written pitch, ending where it was written, its start and syllables where they were - the
  control, the singer's own take, is three semitones higher and shorter;
- the last word whole (host._sung_whole): the singer is told the phrase and three of its own words after a rest, and the
  take comes back ending just past the last note, faded, the words after it gone from its syllables - the control, the
  singer's own take, runs on through them; where Kokoro is installed, a phrase's last word sung so is within a few dB of
  the line's others - the control, Kokoro left to end on it, lets it die away; a word sung with a spelling (a say mark's
  `arpa`) is sung so - the control, the same word unspelled, comes out otherwise;
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

    print("-- a voice at another size")
    sized()
    print("-- the last word whole")
    whole()

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


class _Tone:
    """A stand-in singer: each note a sine at its pitch for its length, written as the backends write a take."""

    told: list = []
    words: list = []

    def sing(self, voice, words, out_path, params, style):
        import numpy as np
        from backends.piper import PiperBackend

        rate = 24000
        notes = [n for w in words for n in w["notes"]]
        _Tone.told = notes
        _Tone.words = words
        lead = 0.3  # its take begins this long before the phrase, as a sung consonant does
        end = max(float(n["t"]) + float(n["len"]) for n in notes)
        audio = np.zeros(int((end + lead) * rate) + 1)
        for n in notes:
            a, b = int((float(n["t"]) + lead) * rate), int((float(n["t"]) + float(n["len"]) + lead) * rate)
            t = np.arange(b - a) / rate
            audio[a:b] = 0.5 * np.sin(2 * np.pi * singing.hz(float(n["midi"])) * t)
        PiperBackend._write_wav(out_path, audio, rate)
        return {"wav": out_path, "sample_rate": rate, "start": -lead, "duration": audio.size / rate,
                "sung": [{"word": i, "t": float(w["notes"][0]["t"])} for i, w in enumerate(words)]}


def _pitch(path: str) -> tuple:
    """A take's length (seconds) and its pitch (MIDI), by the strongest bin of its spectrum."""
    import wave

    import numpy as np

    with wave.open(path, "rb") as w:
        rate = w.getframerate()
        x = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").astype(float)
    spec = np.abs(np.fft.rfft(x * np.hanning(x.size), n=1 << 20))
    hz = float(np.argmax(spec)) * rate / float(1 << 20)
    return x.size / float(rate), 69.0 + 12.0 * np.log2(hz / 440.0)


def sized() -> None:
    try:
        import numpy  # noqa: F401
        import host
    except ImportError as exc:  # a machine without the voice environment
        print("  skip: %s" % exc)
        return
    words = [{"text": "la", "notes": [{"t": 0.0, "len": 1.5, "midi": 60.0}]}]
    with tempfile.TemporaryDirectory() as d:
        out = str(Path(d) / "sized.wav")
        got = host._sung_at_size(_Tone(), "kokoro", words, out, {}, {}, -3.0)
        told = _Tone.told[0]
        length, pitch = _pitch(out)
        own = str(Path(d) / "own.wav")
        _Tone().sing("kokoro", [{"text": "la", "notes": [told]}], own, {}, {})
        own_len, own_pitch = _pitch(own)
        r = 2.0 ** (-3.0 / 12.0)
        ok(abs(float(told["midi"]) - 63.0) < 1e-6 and abs(float(told["len"]) - 1.5 * r) < 1e-6,
           "three semitones larger, the singer is told the phrase three higher and quicker (%.1f, %.3f s)" % (told["midi"], told["len"]))
        ends = float(got["start"]) + length
        ok(abs(pitch - 60.0) < 0.1 and abs(ends - (1.5 + host.TAIL_RELEASE / r)) < 0.01,
           "...and what comes back is at the written pitch, ending where it was written: %.2f for 60, at %.3f s" % (pitch, ends))
        ok(abs(float(got["start"]) + 0.3 / r) < 1e-6 and len(got["sung"]) == 1 and abs(float(got["sung"][0]["t"])) < 1e-6,
           "...its start and syllables moved with it")
        ok(abs(own_pitch - 63.0) < 0.1 and own_len < 1.6,
           "the control: the singer's own take is three higher and shorter, %.2f for %.3f s" % (own_pitch, own_len))


def _level(path: str, start: float, a: float, b: float) -> float:
    """A take's level (dB) over phrase seconds [a, b): the loud end of its 10 ms frames there."""
    import wave

    import numpy as np

    with wave.open(path, "rb") as w:
        rate = w.getframerate()
        x = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").astype(float) / 32767.0
    i, j = max(0, int((a - start) * rate)), min(x.size, int((b - start) * rate))
    hop = int(0.01 * rate)
    frames = [np.sqrt(np.mean(x[q:q + hop] ** 2) + 1e-12) for q in range(i, max(j - hop, i + 1), hop)]
    return 20.0 * np.log10(np.percentile(frames, 80)) if frames else -120.0


def whole() -> None:
    try:
        import wave

        import numpy as np
        import host
    except ImportError as exc:
        print("  skip: %s" % exc)
        return
    words = [{"text": "on", "notes": [{"t": 0.0, "len": 0.6, "midi": 64.0}]},
             {"text": "page", "notes": [{"t": 0.7, "len": 0.3, "midi": 60.0}]}]
    with tempfile.TemporaryDirectory() as d:
        out = str(Path(d) / "whole.wav")
        got = host._sung_whole(_Tone(), "kokoro", words, out, {}, {})
        told = _Tone.words
        tail = told[len(words):]
        with wave.open(out, "rb") as w:
            rate = w.getframerate()
            x = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").astype(float)
        ends = float(got["start"]) + x.size / rate
        ok(len(tail) == host.TAIL_WORDS and [t["text"] for t in tail] == ["on", "page", "on"]
           and abs(float(tail[0]["notes"][0]["t"]) - (1.0 + host.TAIL_GAP)) < 1e-6 and float(tail[0]["notes"][0]["midi"]) == 60.0,
           "the singer is told the phrase and three of its own words after a rest, at its last note's pitch")
        ok(abs(ends - (1.0 + host.TAIL_RELEASE)) < 0.002 and abs(x[-1]) < 2 and len(got["sung"]) == len(words),
           "...and the take comes back ending just past the last note (%.3f s), faded, the words after it gone" % ends)
        own = str(Path(d) / "own.wav")
        _Tone().sing("kokoro", told, own, {}, {})
        with wave.open(own, "rb") as w:
            own_ends = -0.3 + w.getnframes() / w.getframerate()
        ok(own_ends > ends + 0.5, "the control: the singer's own take runs on through them, to %.2f s" % own_ends)
        home = Path.home() / ".local/share/ghost/voices/kokoro"
        if not (home / "model.onnx").exists():
            print("  skip: Kokoro is not installed here")
            return
        from backends import REGISTRY
        kokoro = REGISTRY["kokoro"]()
        line = [{"text": t, "notes": [{"t": a, "len": n, "midi": m}]}
                for t, a, n, m in (("On", 0.0, 0.6, 64.0), ("an", 0.63, 0.29, 64.0), ("artist's", 0.95, 0.6, 62.0), ("page", 1.58, 0.28, 60.0))]
        sung = str(Path(d) / "sung.wav")
        bare = str(Path(d) / "bare.wav")
        a = host._sung_whole(kokoro, "kokoro", line, sung, {"speaker": 0}, {"tune": 0.2})
        b = kokoro.sing(voice="kokoro", words=line, out_path=bare, params={"speaker": 0}, style={"tune": 0.2})
        def last_under(path, got):
            others = float(np.median([_level(path, float(got["start"]), w["notes"][0]["t"], w["notes"][0]["t"] + w["notes"][0]["len"]) for w in line[:-1]]))
            return others - _level(path, float(got["start"]), 1.58, 1.86)
        whole_under, bare_under = last_under(sung, a), last_under(bare, b)
        ok(whole_under < 6.0, "where Kokoro sings, the last word sung on past is %.1f dB under the line's others" % whole_under)
        ok(bare_under > 12.0, "...the control, Kokoro left to end on it: %.1f dB under" % bare_under)
        word = {"text": "wisened", "notes": [{"t": 0.0, "len": 0.8, "midi": 60.0}]}
        spelled_wav, plain_wav = str(Path(d) / "spelled.wav"), str(Path(d) / "plain.wav")
        kokoro.sing(voice="kokoro", words=[{**word, "arpa": ["W", "IH1", "Z", "AH0", "N", "D"]}], out_path=spelled_wav,
                    params={"speaker": 0}, style={"tune": 1.0})
        kokoro.sing(voice="kokoro", words=[word], out_path=plain_wav, params={"speaker": 0}, style={"tune": 1.0})
        with wave.open(spelled_wav, "rb") as w1, wave.open(plain_wav, "rb") as w2:
            a1, a2 = w1.readframes(w1.getnframes()), w2.readframes(w2.getnframes())
        ok(a1 != a2, "a word sung with its spelling is sung so - the control, unspelled, comes out otherwise")


if __name__ == "__main__":
    raise SystemExit(main())
