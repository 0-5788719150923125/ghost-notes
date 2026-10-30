#!/usr/bin/env python3
"""Tests for the Kokoro backend (backends/kokoro.py): Piper's path on another model.

Run it directly with the voice venv's python - no pytest needed:

    ~/.local/share/godot/app_userdata/ghost/voice_venv/bin/python \
        hosts/voice/test_kokoro.py

What is held, each with the case that must not change:

  1. eSpeak's reading is written in misaki's symbols (A for eɪ, T for the flap, ᵊ for a syllabic
     consonant, ː dropped in American and kept in British) - and a pair is merged only inside one
     word;
  2. the ids are one a symbol with a pad at each end, no blanks, LEAD_IN word-spaces after the first pad
     (the opening word is said), and the style is the pack's row for the sentence's own tokens;
  3. no rest is floored; the word before a rest has its last vowel held at HOLD_LEAST ("uː" sharing it),
     less at a weaker boundary, none without the trail; a rest is cut in its window, after a stop's
     release, never in its closure; the trail fades a vowel held into the next word whole and comes back
     up without a step;
  4. a leaned-on word scales its stressed syllable alone, and an unmarked one feeds no scale;
  5. the spans and phones are the plan's frames of 600 samples at 24 kHz, the phones in eSpeak's
     symbols (A's time shared by e and ɪ), and the take is handed back at 22,050 with its seconds kept;
     its head is trimmed through the pad and the lead-in to SEAM_LEAD before the first sound;
  6. a sentence over 510 tokens is read in pieces cut after a mark, each with its own pads;
  7. the length a pitch move is measured against is the ROUNDED plan's, exact at ratio 1, a take's
     trimmed ends counted as they stand;
  8. the graph patch: unfed, the stock graph's output; the scale before the Round, the floor after,
     the plan handed back whole - and a graph of another shape is left alone;
  9. a voice taught here (trained/<id>/) is listed beside the checkpoints, one speaker, never fetched, read
     in its own accent - and the ids a voice is taught on (`ids_of`) are the ones the graph is sent;
 10. the happy vowel: where the word's dictionary reading has an unstressed "ee" and eSpeak a lax ɪ, after a
     stress or before a vowel, Kokoro is sent i ("babysitter", "everything", "video", "reaction") - an
     unstressed prefix before a consonant ("pretend"), vowels that do not line up, a word no dictionary holds
     and every word Piper reads are left as eSpeak read them.

Synthesis runs against a fake session, as in test_expression.py: no model download, no eSpeak.
"""

from __future__ import annotations

import sys
import tempfile
import wave
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

CHECKS: list = []


def check(fn):
    CHECKS.append(fn)
    return fn


def eq(got, want, what: str):
    assert got == want, f"{what}: got {got!r}, want {want!r}"
    print(f"    ok  {what} == {want!r}")


def ok(cond, what: str, detail: str = ""):
    assert cond, f"FAILED: {what}" + (f" ({detail})" if detail else "")
    print(f"    ok  {what}" + (f"  {detail}" if detail else ""))


# -- fake voice ------------------------------------------------------------

# A vocab in the shape of Kokoro's: the pad first, the marks, the word-space, misaki's symbols.
VOCAB = "$;:,.!?—… " + "AIOQTWYᵊᵻabdefhijklmnopstuvwzæðŋɑɒɔəɛɜɡɪɹʃʊʌʒʤʧθˈˌː"
SPACE = VOCAB.index(" ")


class _Session:
    """The patched graph, faked: a plan of 2-4 frames a symbol (one for a pad or a word-space), over
    `speed`, times `dur_scale`, rounded, floored by `rest_floor`, at least one - in the order `_patch`
    puts them. 600 samples a frame. Records what it was fed. Without the two inputs it hands back
    the plan before the Round, as the stock export does."""

    def __init__(self, takes=("rest_floor", "dur_scale"), lead=1.0, tail=1.0, quiet_marks=False) -> None:
        self.takes = tuple(takes)
        self.fed: list = []
        # Kokoro's own ends: its first pad's frames, and whether a mark, a word-space and a pad are
        # silent - the plain fake sounds through everything, so nothing is trimmed from it
        self.lead = lead
        self.tail = tail
        self.quiet = {0} | ({VOCAB.index(c) for c in ".,; "} if quiet_marks else set())

    def get_overridable_initializers(self):
        import types

        return [types.SimpleNamespace(name=n) for n in self.takes]

    def run(self, _outputs, feeds):
        import numpy as np

        ids = [int(i) for i in feeds["input_ids"][0]]
        speed = float(feeds["speed"][0])
        scale = feeds.get("dur_scale")
        floor = feeds.get("rest_floor")
        self.fed.append(
            {
                "ids": ids,
                "style": np.array(feeds["style"]),
                "scale": None if scale is None else np.array(scale),
                "floor": None if floor is None else np.array(floor),
            }
        )
        plan = np.array([1.0 if i in (0, SPACE) else 2.0 + (i % 3) for i in ids]) / speed
        plan[0] = self.lead / speed
        plan[-1] = self.tail / speed
        if "dur_scale" not in self.takes:
            frames = plan
        else:
            if scale is not None:
                plan = plan * scale
            frames = np.round(plan)
            if floor is not None:
                frames = np.maximum(frames, floor)
            frames = np.maximum(frames, 1.0)
        whole = np.maximum(np.round(frames), 1.0).astype(int)
        t = np.arange(int(whole.sum()) * 600, dtype=np.float64)
        audio = 0.5 * np.sin(2.0 * np.pi * t / 96.0)
        at = 0
        for i, f in zip(ids, whole):
            if i in self.quiet:
                audio[at : at + f * 600] = 0.0
            at += f * 600
        return [audio.astype(np.float32).reshape(1, -1), frames.astype(np.float32).reshape(1, -1)]


def _backend(british: bool = False):
    import numpy as np
    from backends.kokoro import STYLE, KokoroBackend

    k = KokoroBackend()
    # row r of the pack is all r, so the style fed says which row it was
    pack = np.repeat(np.arange(510, dtype=np.float32)[:, None, None], STYLE, axis=2)
    cfg = {
        "audio": {"sample_rate": 24000},
        "phoneme_id_map": {ch: [i] for i, ch in enumerate(VOCAB)},
        "espeak": {"voice": "en-gb" if british else "en-us"},
        "inference": {"length_scale": 1.0},
        "num_speakers": 1,
        "kokoro": {"pack": pack, "british": british, "vocab": {ch: i for i, ch in enumerate(VOCAB)}},
    }
    return k, cfg


def _tok(text, ipa, punct="", emph=0):
    t = {"text": text, "ipa": ipa, "punct": punct}
    if emph:
        t["emph"] = emph
    return t


SENTENCE = [
    _tok("it", "ˈɪt", ","),
    _tok("was", "wʌz"),
    _tok("never", "nˈɛvɚ"),
    _tok("so", "sˈoʊ", "."),
]


def _render(tokens, params=None, sess=None, british=False):
    """`_synth_tokens` on the fake voice: (result, session, wav rate, wav samples)."""
    k, cfg = _backend(british)
    sess = sess or _Session()
    with tempfile.TemporaryDirectory() as td:
        out = Path(td) / "a.wav"
        res = k._synth_tokens(
            list(tokens),
            "kokoro",
            str(out),
            {"phonemizer": "ghost", "pause_scale": 0.0, "trail": 0.0, **(params or {})},
            cfg,
            sess,
        )
        with wave.open(str(out)) as w:
            rate, n = w.getframerate(), w.getnframes()
    return res, sess, rate, n


def _syms(text: str, src: int = 0):
    return [(ch, src) for ch in text]


# -- 1. the symbols -----------------------------------------------------------


@check
def test_american_symbols():
    """misaki's American spelling of eSpeak's reading."""
    from backends.kokoro import kokoro_symbols

    def said(ipa):
        return "".join(s for s, _, _ in kokoro_symbols(_syms(ipa), False))

    eq(said("hˈeɪ"), "hˈA", "eɪ is A")
    eq(said("bˈʌɾɚ"), "bˈʌTəɹ", "the flap is T, ɚ is əɹ")
    eq(said("bˈɑːɾl̩"), "bˈɑTᵊl", "no length mark in American; a syllabic l is ᵊl")
    eq(said("ɡˈoʊ"), "ɡˈO", "oʊ is O")
    eq(said("dʒˈʌmp tʃˈɪp"), "ʤˈʌmp ʧˈɪp", "the affricates are one symbol each")
    eq(said("hɜː"), "hɜɹ", "the NURSE vowel takes its r")
    eq(said("bˈɔɪ"), "bˈY", "ɔɪ is Y")
    pair = kokoro_symbols([("ɔ", 0), ("ɪ", 1)], False)
    eq([s for s, _, _ in pair], ["ɔ", "ɪ"], "two words' symbols are never merged into one")


@check
def test_british_symbols():
    from backends.kokoro import kokoro_symbols

    def said(ipa):
        return "".join(s for s, _, _ in kokoro_symbols(_syms(ipa), True))

    eq(said("hˈeə"), "hˈɛː", "the SQUARE vowel is ɛː, not A then ə")
    eq(said("ɡˈəʊ"), "ɡˈQ", "əʊ is Q")
    eq(said("kˈɑːt"), "kˈɑːt", "British keeps its length marks")


@check
def test_units_keep_their_places():
    """Each symbol written says which of eSpeak's it came from."""
    from backends.kokoro import kokoro_symbols

    got = kokoro_symbols(_syms("sˈeɪ", 3), False)
    eq([(s, src, at) for s, src, at in got], [("s", 3, (0,)), ("ˈ", 3, (1,)), ("A", 3, (2, 3))],
       "A was written from places 2 and 3")


@check
def test_the_happy_vowel():
    """eSpeak's readings, as measured, against the words' dictionary readings (ghost's CMUdict ARPAbet)."""
    from backends.kokoro import KokoroBackend, happy_vowels
    from backends.piper import PiperBackend

    def arpa(s):
        return [p if p[-1].isdigit() else p + "0" for p in s.split()]

    sitter = arpa("B EY1 B IY0 S IH2 T ER0")
    eq(happy_vowels("bˈeɪbɪsˌɪɾɚ", sitter), "bˈeɪbisˌɪɾɚ", "babysitter: the y after the stress is 'ee'")
    eq(happy_vowels("ˈɛvɹɪθˌɪŋ", arpa("EH1 V R IY0 TH IH2 NG")), "ˈɛvɹiθˌɪŋ", "everything")
    eq(happy_vowels("vˈɪdɪoʊ", arpa("V IH1 D IY0 OW0")), "vˈɪdioʊ", "video: before a vowel")
    eq(happy_vowels("ɹɪˈækʃən", arpa("R IY0 AE1 K SH AH0 N")), "ɹiˈækʃən", "reaction: before a vowel, ahead of the stress")
    eq(happy_vowels("pɹɪtˈɛnd", arpa("P R IY0 T EH1 N D")), "pɹɪtˈɛnd",
       "CONTROL: pretend - an unstressed prefix before a consonant is said as eSpeak reads it")
    eq(happy_vowels("bˈeɪbsˌɪɾɚ", sitter), "bˈeɪbsˌɪɾɚ", "CONTROL: vowels that do not line up are left alone")
    eq(happy_vowels("bˈeɪbi", arpa("B EY1 B IY0")), "bˈeɪbi", "CONTROL: a happy vowel eSpeak already reads is as it was")
    tok = {"text": "babysitter", "fallback": sitter}
    k = KokoroBackend()
    eq(k._dictionary_reading("bˈeɪbɪsˌɪɾɚ", tok), "bˈeɪbisˌɪɾɚ", "Kokoro is sent the dictionary's vowel")
    eq(k._dictionary_reading("bˈeɪbɪsˌɪɾɚ", {**tok, "rare": True}), "bˈeɪbɪsˌɪɾɚ",
       "CONTROL: a word no dictionary holds (its ARPAbet a guess), as eSpeak read it")
    eq(PiperBackend()._dictionary_reading("bˈeɪbɪsˌɪɾɚ", tok), "bˈeɪbɪsˌɪɾɚ",
       "CONTROL: Piper, taught on eSpeak's own readings, is sent them")


# -- 2. the ids ----------------------------------------------------------------


@check
def test_ids_one_a_symbol():
    import numpy as np

    _res, sess, _rate, _n = _render(SENTENCE)
    fed = sess.fed[0]
    ids = fed["ids"]
    eq((ids[0], ids[-1]), (0, 0), "a pad at each end")
    ok(0 not in ids[1:-1], "no pads between the symbols")
    from backends.kokoro import LEAD_IN

    eq(ids[1 : 1 + LEAD_IN], [SPACE] * LEAD_IN, "LEAD_IN word-spaces open the utterance, after the pad")
    body = "".join(VOCAB[i] for i in ids[1 + LEAD_IN : -1])
    eq(body, "ˈɪt, wʌz nˈɛvəɹ sˈO.", "the sentence as Kokoro reads it, ending on its mark - no word-space after")
    eq(float(np.asarray(fed["style"]).ravel()[0]), float(len(ids) - 3 - LEAD_IN),
       "the style is the pack's row for the sentence's own token count, the lead-in not counted")


# -- 3. the comma's floor ------------------------------------------------------


@check
def test_no_rest_is_floored():
    """Kokoro holds a word through frames floored on its word-space (it does not rest in them), so no
    rest is floored: with a comma and a pause asked, only the opening vowel's floor is fed."""
    params = {"pause_scale": 1.0}
    _res, sess, _rate, _n = _render(SENTENCE, params)
    fed = sess.fed[0]
    floored = [VOCAB[fed["ids"][i]] for i, f in enumerate(fed["floor"]) if f > 0.0]
    eq(floored, ["ɪ"], "a comma floors nothing; the opening vowel alone is held up")
    toks = [dict(t) for t in SENTENCE]
    toks[1]["rest_after"] = 1.0
    _res, sess, _rate, _n = _render(toks, params)
    floored = [VOCAB[sess.fed[0]["ids"][i]] for i, f in enumerate(sess.fed[0]["floor"]) if f > 0.0]
    eq(floored, ["ɪ"], "nor does a hesitation after a word")


@check
def test_a_rest_is_cut_where_its_gap_is():
    """The window a rest is cut in runs from GAP_BACK before the (corrected) end of the word to GAP_REACH
    past the next word's start, never past either word; Piper's runs from the word's end to a frame into
    the next."""
    from backends.kokoro import GAP_BACK, GAP_REACH, KokoroBackend
    from backends.piper import PiperBackend

    edges = {0: (0.0, 0.4), 1: (0.45, 0.9)}
    lo, hi = KokoroBackend._gap(edges, 0, 0.025)
    ok(abs(lo - (0.4 - GAP_BACK)) < 1e-9 and abs(hi - (0.45 + GAP_REACH)) < 1e-9,
       "Kokoro's window: %.3f to %.3f s" % (lo, hi))
    ok(hi < 0.675, "never as far as the middle of the next word (its closures are silences too)")
    short = {0: (0.0, 0.4), 1: (0.45, 0.47)}
    eq(KokoroBackend._gap(short, 0, 0.025)[1], 0.47, "never past the end of the next word")
    plo, phi = PiperBackend._gap(edges, 0, 0.025)
    ok(abs(plo - 0.4) < 1e-9 and abs(phi - 0.475) < 1e-9, "Piper's is unchanged: %.3f to %.3f s" % (plo, phi))
    eq(KokoroBackend._gap(edges, 1, 0.025), None, "after the last word, none")


@check
def test_a_stops_release_stays_its_word():
    """'it,' before 'haven't': the vowel, the silence of the t's closure, its release, the next word's
    breath. Cut in Kokoro's window, the rest goes in after the release; reaching GAP_REACH back into the
    word (the window as it was) found the closure and put the release after the rest (the control)."""
    import numpy as np
    from backends.kokoro import GAP_REACH, KokoroBackend
    from backends.piper import SPLICE_QUIET, _trough

    sr = 24000
    rng = np.random.default_rng(3)
    t = np.arange(int(0.8 * sr)) / sr
    vowel = (0.5 * np.sin(2 * np.pi * 180.0 * t)).astype(np.float32)
    a = np.zeros(t.size, np.float32)

    def lay(t0, t1, x):
        a[int(t0 * sr) : int(t1 * sr)] = x[int(t0 * sr) : int(t1 * sr)]

    lay(0.10, 0.34, vowel)  # "i"; then the closure, silent, to 0.375
    lay(0.375, 0.39, (0.3 * rng.uniform(-1.0, 1.0, t.size)).astype(np.float32))  # the t's release
    lay(0.39, 0.47, (0.05 * rng.uniform(-1.0, 1.0, t.size)).astype(np.float32))  # "h"
    lay(0.47, 0.80, vowel)  # "aven't"
    edges = {0: (0.10, 0.40), 1: (0.45, 0.80)}
    quiet = float(np.abs(a).max()) * SPLICE_QUIET
    lo, hi = KokoroBackend._gap(edges, 0, 0.025)
    cut = _trough(a, int(lo * sr), int(hi * sr), sr, quiet) / sr
    ok(cut >= 0.39, "the rest goes in after the release", "%.3f s" % cut)
    old = _trough(a, int((0.40 - GAP_REACH) * sr), int(hi * sr), sr, quiet) / sr
    ok(0.34 <= old < 0.375, "control: reaching GAP_REACH back, the cut is in the closure", "%.3f s" % old)


@check
def test_a_held_vowel_fades_whole_without_a_step():
    """At a comma it reads straight through, Kokoro holds the word's vowel up to the next word. The trail,
    as Kokoro makes it, fades it right up to the next word's start, and the way back up runs on into that
    word. Controls: walked back over sound (Piper's), the voice is at full level again before the next
    word - the dip half way through the vowel, where the cut went; not run on, the way back is a step."""
    import numpy as np
    import backends.piper as P
    from backends.kokoro import KokoroBackend

    sr = 24000
    t = np.arange(int(1.0 * sr)) / sr
    a = (0.5 * np.sin(2 * np.pi * 180.0 * t)).astype(np.float32)  # one voice, sounding throughout
    edges = {0: (0.10, 0.40), 1: (0.45, 0.90)}
    group = [{"text": "you", "punct": ","}, {"text": "my", "punct": ""}, {"text": "love", "punct": ""},
             {"text": "again", "punct": "."}]  # a comma's whole rest: more than SHORT_TAIL words after it
    params = {"pause_scale": 6.5}

    def gain(out, t0, t1):
        """The trail's gain in dB over [t0, t1), where the input is not near a zero crossing."""
        x = a[int(t0 * sr) : int(t1 * sr)].astype(np.float64)
        y = out[int(t0 * sr) : int(t1 * sr)].astype(np.float64)
        keep = np.abs(x) > 0.1
        return 20.0 * np.log10(np.abs(y[keep]) / np.abs(x[keep]))

    def steepest(out):
        return float(np.max(np.abs(np.diff(gain(out, 0.3, 0.6)))))

    real = P.TRAIL_SAG
    P.TRAIL_SAG = 0.0  # no pitch sag: what comes out is the input times the trail's gain
    try:
        made = P._trail(a, edges, group, params, sr, walk_back=KokoroBackend.trail_early,
                        through=KokoroBackend.trail_through)
        walked = P._trail(a, edges, group, params, sr)
        stepped = P._trail(a, edges, group, params, sr, walk_back=KokoroBackend.trail_early, through=False)
    finally:
        P.TRAIL_SAG = real
    late = float(np.median(gain(made, 0.425, 0.435)))
    ok(late < -10.0, "the vowel is still fading 15 ms before the next word starts", "%+.1f dB" % late)
    ok(steepest(made) < 1.0, "and comes back up without a step", "%.2f dB a sample at most" % steepest(made))
    back = float(np.median(gain(walked, 0.425, 0.435)))
    ok(back > -1.0, "control: walked back over the vowel, it is at full level there again", "%+.1f dB" % back)
    ok(steepest(stepped) > 10.0, "control: not run on, it comes back in one step",
       "%.1f dB" % steepest(stepped))


@check
def test_a_short_last_vowel_is_held():
    """Before a rest, the word's last vowel is floored at HOLD_LEAST in all - "uː" sharing it between its
    two symbols, "eɪ" (A) taking it alone - and a weaker boundary (Pause 1, half the trail) holds less; a
    sentence's last word has no trail and is not held. Without the trail, the opening vowel alone (the
    control)."""
    import numpy as np
    from backends.kokoro import HOLD_LEAST

    toks = [_tok("so", "sˈəʊ"), _tok("you", "jˈuː", ","), _tok("say", "sˈeɪ", ","), _tok("it", "ˈɪt", ".")]

    def floored(params):
        _res, sess, _rate, _n = _render(toks, params, british=True)
        fed = sess.fed[0]
        return [(VOCAB[fed["ids"][i]], float(f)) for i, f in enumerate(fed["floor"]) if f > 0.0]

    whole = float(np.ceil(HOLD_LEAST / 0.025 - 1e-9))  # at length scale 1, a full boundary: 4 frames
    eq(floored({"pause_scale": 6.5, "trail": 1.0}),
       [("Q", 2.0), ("u", whole / 2), ("ː", whole / 2), ("A", whole)],
       "the opening vowel, then each held vowel at HOLD_LEAST: 'you''s shared, 'say''s alone, 'it.' none")
    weak = dict(floored({"pause_scale": 1.0, "trail": 1.0}))
    ok(weak["A"] < whole, "a weaker boundary holds less", "%d frames" % weak["A"])
    eq(floored({"pause_scale": 6.5, "trail": 0.0}), [("Q", 2.0)], "control: no trail, no hold")


@check
def test_the_trail_but_no_lead():
    """No rest is floored on Kokoro, and a floored rest is what made the next word's lead long: the lead is
    not quieted; the trail (the word before a rest let go of) is made, on the corrected plan. On Piper both
    are made (the control)."""
    import backends.piper as P
    from backends.piper import PiperBackend

    called: list = []
    real = (P._trail, P._quiet_lead)

    def trail(audio, *a, **k):
        called.append("trail")
        return audio

    def lead(audio, *a, **k):
        called.append("lead")
        return audio

    P._trail, P._quiet_lead = trail, lead
    try:
        _render(SENTENCE, {"pause_scale": 1.0, "trail": 1.0})
        eq(called, ["trail"], "Kokoro: the trail is made, the lead is not")
        called.clear()
        from test_expression import _Session as PiperSession, _cfg as piper_cfg

        with tempfile.TemporaryDirectory() as td:
            PiperBackend()._synth_tokens([dict(t, fallback=["AH0"]) for t in SENTENCE], "fake", str(Path(td) / "p.wav"),
                                         {"phonemizer": "ghost", "pause_scale": 1.0, "trail": 1.0}, piper_cfg(), PiperSession())
        eq(called, ["lead", "trail"], "Piper, the same sentence: both are made (the control)")
    finally:
        P._trail, P._quiet_lead = real


# -- 4. stress -----------------------------------------------------------------


@check
def test_stress_scales_its_syllable():
    toks = [dict(t) for t in SENTENCE]
    toks[2]["emph"] = 1
    _res, sess, _rate, _n = _render(toks)
    fed = sess.fed[0]
    ok(fed["scale"] is not None, "a leaned-on word feeds the duration scale")
    scaled = [VOCAB[fed["ids"][i]] for i, m in enumerate(fed["scale"]) if m != 1.0]
    eq(scaled, ["ˈ", "ɛ"], "only 'never''s stressed syllable: its mark and its vowel")
    _res, sess, _rate, _n = _render(SENTENCE)
    eq(sess.fed[0]["scale"], None, "an unmarked sentence feeds no scale")


# -- 5. the times, the phones, the rate ----------------------------------------


@check
def test_times_phones_and_rate():
    import numpy as np
    from backends.kokoro import HOP, LEAD_IN, OUT_RATE, PLAN_LEAD, SR

    toks = [_tok("say", "sˈeɪ"), _tok("it", "ˈɪt", ".")]
    res, sess, rate, n = _render(toks)
    fed = sess.fed[0]
    plan = np.array([1.0 if i in (0, SPACE) else 2.0 + (i % 3) for i in fed["ids"]])
    want = float(plan.sum()) * HOP / SR
    ok(abs(res["duration"] - want) < 1e-3, "the take is the plan's frames of 600 samples at 24 kHz",
       "%.4f s" % res["duration"])
    eq(rate, OUT_RATE, "handed back at 22,050")
    ok(abs(n - want * OUT_RATE) <= 1, "with its seconds kept", "%d samples" % n)
    eq(res["sample_rate"], OUT_RATE, "and says so")
    ids = fed["ids"]
    # every time is the plan's told PLAN_LEAD earlier (Kokoro's audio runs that far ahead of its plan)
    t = np.maximum(np.concatenate([[0.0], np.cumsum(plan)]) * HOP / SR - PLAN_LEAD, 0.0)
    s_at = ids.index(VOCAB.index("s"))
    a_at = ids.index(VOCAB.index("A"))
    phones = res["phones"]
    eq([p["p"] for p in phones], ["s", "e", "ɪ", "ɪ", "t"], "the phones in eSpeak's symbols")
    ok(abs(phones[0]["t0"] - t[s_at]) < 1e-3, "s starts where its frames do, PLAN_LEAD earlier")
    mid = (t[a_at] + t[a_at + 1]) / 2.0
    ok(abs(phones[1]["t1"] - mid) < 1e-3 and abs(phones[2]["t0"] - mid) < 1e-3,
       "A's time is shared by e and ɪ")
    spans = {row["index"]: (row["t0"], row["t1"]) for row in res["tokens"]}
    ok(abs(spans[0][0] - t[1 + LEAD_IN]) < 1e-3,
       "the first word starts after the pad's and the lead-in's frames, PLAN_LEAD earlier")


@check
def test_ends_trimmed_to_the_seam():
    """Kokoro's 14-frame first pad, the lead-in and its silent marks at the end are cut to the silence the
    seam was measured on; the plain fake, which sounds through its pad, is the control (nothing cut above).
    The fake's audio does not run ahead of its plan, so the head keeps SEAM_LEAD before where the plan, told
    PLAN_LEAD early, puts the first sound - never nearer it - and the first word is told SEAM_LEAD in."""
    import numpy as np
    from backends.kokoro import LEAD_IN, OUT_RATE, PLAN_LEAD, SEAM_LEAD, SEAM_TAIL

    sess = _Session(lead=14.0, tail=10.0, quiet_marks=True)
    res, sess, rate, n = _render([_tok("say", "sˈeɪ"), _tok("so", "sˈoʊ", ".")], sess=sess)
    spans = {row["index"]: (row["t0"], row["t1"]) for row in res["tokens"]}
    first = SEAM_LEAD
    ok(abs(spans[0][0] - first) < 2e-3, "the first word starts SEAM_LEAD in, not 450 ms (pad and lead-in)",
       "%.3f s" % spans[0][0])
    ok(abs(res["phones"][0]["t0"] - first) < 2e-3, "and its first phone with it")
    fed = sess.fed[0]
    ids = fed["ids"]
    plan = np.array([14.0] + [1.0 if i in (0, SPACE) else 2.0 + (i % 3) for i in ids[1:-1]] + [10.0])
    ok(float(plan[max(k for k, i in enumerate(ids) if i not in sess.quiet) + 1 :].sum()) * 0.025 > SEAM_TAIL,
       "the fake's ends hold more silence than the seam allows")
    last = max(k for k, i in enumerate(ids) if i not in sess.quiet)
    said_to = float(plan[: last + 1].sum()) * 0.025 - ((14.0 + LEAD_IN) * 0.025 - PLAN_LEAD - SEAM_LEAD)
    ok(abs(res["duration"] - (said_to + SEAM_TAIL)) < 2e-3, "SEAM_TAIL kept after the last sound",
       "%.3f s" % (res["duration"] - said_to))
    ok(abs(n - res["duration"] * OUT_RATE) <= 1, "the take is as long as its times say")


@check
def test_no_hiss_after_a_voiced_end():
    """A take whose plan ends voiced loses what hisses after its last voiced moment; one whose last sound
    is a hiss keeps every sample (the control)."""
    import numpy as np
    from backends.kokoro import SR, _quiet_tail

    rng = np.random.default_rng(7)
    t = np.arange(int(0.3 * SR)) / SR
    voice = (0.5 * np.sin(2 * np.pi * 180.0 * t)).astype(np.float32)
    noise = rng.standard_normal(int(0.12 * SR)).astype(np.float32)
    hiss = np.diff(np.concatenate([[0.0], noise])).astype(np.float32) * 0.08  # mostly above 4 kHz
    thump = (0.02 * np.sin(2 * np.pi * 60.0 * np.arange(int(0.01 * SR)) / SR)).astype(np.float32)
    # ...a lone low frame at the very end (a thump in the last pad) is not the voice going on
    take = np.concatenate([voice, hiss, np.zeros(int(0.05 * SR), np.float32), thump])
    quiet = _quiet_tail(take, "ʊ")
    tail = quiet[voice.size + int(0.04 * SR):]
    ok(float(np.sqrt(np.mean(_quiet_tail(take[: -thump.size], "ʊ")[voice.size + int(0.04 * SR):] ** 2))) < 1e-6,
       "and without the thump, the same")
    ok(float(np.sqrt(np.mean(tail ** 2))) < 1e-6, "after 'oh', the hiss is let go of",
       "%.1g" % float(np.sqrt(np.mean(tail ** 2))))
    ok(np.array_equal(quiet[: voice.size - int(0.01 * SR)], take[: voice.size - int(0.01 * SR)]), "the voice itself untouched")
    eq(np.array_equal(_quiet_tail(take, "s"), take), True, "after a final s, the hiss is the word: untouched")


# -- 6. a long sentence -----------------------------------------------------------


@check
def test_long_sentence_in_pieces():
    from backends.kokoro import MAX_TOKENS

    toks = []
    for i in range(120):
        toks.append(_tok("word%d" % i, "wˈɜːd", "," if i % 9 == 8 else ""))
    toks[-1]["punct"] = "."
    res, sess, _rate, _n = _render(toks)
    ok(len(sess.fed) > 1, "read in pieces", "%d" % len(sess.fed))
    for fed in sess.fed:
        ok(len(fed["ids"]) - 2 <= MAX_TOKENS and fed["ids"][0] == 0 and fed["ids"][-1] == 0,
           "a piece of at most 510 tokens, a pad at each end")
    first = sess.fed[0]["ids"]
    eq("".join(VOCAB[i] for i in first[-3:-1]), ", ", "the first piece ends after a mark")
    starts = [row["t0"] for row in sorted(res["tokens"], key=lambda r: r["index"])]
    eq(len(starts), len(toks), "every word placed")
    ok(all(b >= a for a, b in zip(starts, starts[1:])), "in order")
    _res, sess, _rate, _n = _render(SENTENCE)
    eq(len(sess.fed), 1, "a short sentence is one piece")


# -- 7. the rounded plan ---------------------------------------------------------


@check
def test_nominal_is_the_rounded_plans():
    import numpy as np
    from backends.kokoro import HOP, SR, KokoroBackend
    from backends.piper import PiperBackend

    from backends.kokoro import HELD

    m = np.array([1.0, 2.0, 3.0, 5.0, 8.0, 13.0])
    eq(KokoroBackend._nominal(m, 1.0, SR), float(m.sum()) * HOP / SR, "exact at ratio 1")
    # a take's ends, trimmed to slivers of a frame: seconds, not plan (the control: unmarked, each is a frame)
    cut = np.array([0.2, 0.0, 0.4, 3.0, 5.0, 0.6])
    ends = np.array([HELD, HELD, HELD, 0.0, 0.0, HELD])
    eq(KokoroBackend._nominal(cut, 1.0, SR, ends), float(cut.sum()) * HOP / SR, "trimmed ends counted as they stand")
    eq(KokoroBackend._nominal(cut, 1.25, SR, ends) - KokoroBackend._nominal(cut[3:5], 1.25, SR),
       1.2 * HOP / SR, "...the same at any scale")
    eq(round(KokoroBackend._nominal(cut, 1.0, SR) * SR / HOP, 6), 12.0,
       "control: unmarked, each sliver counts a whole frame (12 frames where the take holds 9.2)")

    def brute(ratio):
        total = 0.0
        for mm in m:
            if mm <= 1.0:
                total += 1.0
                continue
            x = np.linspace((mm - 0.5) / ratio, (mm + 0.5) / ratio, 200001)[:-1]
            total += float(np.maximum(np.floor(x + 0.5), 1.0).mean())
        return total * HOP / SR

    for r in (0.8, 1.25):
        got = KokoroBackend._nominal(m, r, SR)
        ok(abs(got - brute(r)) < 1e-4, "the mean Round over the interval at ratio %.2f" % r, "%.5f" % got)
    ceiled = PiperBackend._nominal(m, 1.25, SR) * HOP / 256.0
    ok(abs(ceiled - brute(1.25)) > 1e-3, "Piper's ceiled estimate is not it",
       "%.4f against %.4f" % (ceiled, brute(1.25)))


# -- 8. the patch ----------------------------------------------------------------


def _toy_graph(path: Path, rounds: int = 1, after_clip: bool = False) -> None:
    """The export's plan in miniature: durations = x / speed (an output), Round, Clip at 1, Cast,
    and a 'waveform' of the whole frames times 600."""
    import numpy as np
    import onnx
    from onnx import TensorProto, helper, numpy_helper

    plan = "planned" if after_clip else "durations"
    nodes = [helper.make_node("Div", ["x", "speed"], [plan], name="plan")]
    last = plan
    for k in range(rounds):
        nodes.append(helper.make_node("Round", [last], ["r%d" % k], name="round%d" % k))
        last = "r%d" % k
    nodes += [
        helper.make_node("Clip", [last, "one"], ["clipped"], name="clip"),
        helper.make_node("Cast", ["clipped"], ["whole"], to=TensorProto.INT64, name="cast"),
        helper.make_node("Cast", ["whole"], ["wholef"], to=TensorProto.FLOAT, name="back"),
        helper.make_node("Mul", ["wholef", "hop"], ["waveform"], name="wave"),
    ]
    if after_clip:  # v1.1's export: `duration` is the clip, cast to whole numbers
        nodes.append(helper.make_node("Cast", ["whole"], ["durations"], to=TensorProto.FLOAT, name="out"))
    graph = helper.make_graph(
        nodes,
        "toy",
        [
            helper.make_tensor_value_info("x", TensorProto.FLOAT, [None]),
            helper.make_tensor_value_info("speed", TensorProto.FLOAT, [1]),
        ],
        [
            helper.make_tensor_value_info("waveform", TensorProto.FLOAT, [None]),
            helper.make_tensor_value_info("durations", TensorProto.FLOAT, [None]),
        ],
        [
            numpy_helper.from_array(np.array(1.0, np.float32), "one"),
            numpy_helper.from_array(np.array([600.0], np.float32), "hop"),
        ],
    )
    model = helper.make_model(graph, opset_imports=[helper.make_opsetid("", 20)])
    model.ir_version = 10
    onnx.save(model, str(path))


@check
def test_patch():
    import numpy as np
    import onnxruntime as ort
    from backends.kokoro import KokoroBackend

    x = np.array([1.4, 0.3, 2.6], np.float32)
    speed = np.ones(1, np.float32)
    with tempfile.TemporaryDirectory() as td:
        path = Path(td) / "toy.onnx"
        _toy_graph(path)
        stock = ort.InferenceSession(str(path), providers=["CPUExecutionProvider"])
        w0, d0 = stock.run(None, {"x": x, "speed": speed})
        ok(not np.allclose(d0, np.round(d0)), "the stock graph hands back the plan before its Round")
        del stock
        ok(KokoroBackend._patch(path), "patched")
        s = ort.InferenceSession(str(path), providers=["CPUExecutionProvider"])
        eq(sorted(i.name for i in s.get_overridable_initializers()), ["dur_scale", "rest_floor"], "both inputs")
        w1, d1 = s.run(None, {"x": x, "speed": speed})
        eq(w1.tolist(), w0.tolist(), "unfed, the stock graph's output")
        eq(d1.tolist(), [1.0, 1.0, 3.0], "the plan handed back as the whole frames used")
        w2, d2 = s.run(
            None,
            {
                "x": x,
                "speed": speed,
                "dur_scale": np.array([1.5, 1.0, 1.0], np.float32),
                "rest_floor": np.array([0.0, 4.0, 0.0], np.float32),
            },
        )
        eq(d2.tolist(), [2.0, 4.0, 3.0], "scaled before the Round (1.4 x 1.5 = 2.1 -> 2), floored after")
        eq(w2.tolist(), [1200.0, 2400.0, 1800.0], "and the audio is made of that plan")
        before = path.read_bytes()
        eq(KokoroBackend._patch(path), False, "a patched graph is not patched twice")
        eq(path.read_bytes() == before, True, "and is left as it was")
        v11 = Path(td) / "v11.onnx"
        _toy_graph(v11, after_clip=True)
        ok(KokoroBackend._patch(v11), "a graph handing back its clipped plan is patched (v1.1's export)")
        s = ort.InferenceSession(str(v11), providers=["CPUExecutionProvider"])
        _w, d3 = s.run(None, {"x": x, "speed": speed, "dur_scale": np.array([1.5, 1.0, 1.0], np.float32),
                               "rest_floor": np.array([0.0, 4.0, 0.0], np.float32)})
        eq(d3.tolist(), [2.0, 4.0, 3.0], "its own output now says the scaled, floored plan")
        odd = Path(td) / "odd.onnx"
        _toy_graph(odd, rounds=2)
        before = odd.read_bytes()
        eq(KokoroBackend._patch(odd), False, "a graph of another shape is refused")
        eq(odd.read_bytes() == before, True, "and left as it was")


@check
def test_owns_its_voices_only():
    from backends.kokoro import KokoroBackend
    from backends.piper import PiperBackend

    eq(KokoroBackend.owns("kokoro"), True, "the Kokoro voice is Kokoro's")
    eq(KokoroBackend.owns("kokoro-1.1"), True, "and so is its second checkpoint")
    eq(PiperBackend.owns("kokoro"), False, "...and never Piper's")
    eq(KokoroBackend.owns("en_US-libritts-high"), False, "a Piper voice is not Kokoro's")
    eq(KokoroBackend.owns("kokoro-af_heart"), False, "a pack is a speaker, never a voice of its own")


@check
def test_one_voice_its_packs_the_speakers():
    """The Voice list names the model once; the Speaker row picks the pack, each described. (In a voices'
    root of its own: the author's may hold voices taught here.)"""
    from backends.kokoro import PACKS, KokoroBackend

    with _voices_root():
        rows = KokoroBackend().voices()
    eq([r["id"] for r in rows], ["kokoro", "kokoro-1.1"], "one voice a checkpoint")
    v = rows[0]
    eq((v["id"], v["speakers"]), ("kokoro", len(PACKS)), "its packs are its speakers")
    eq(len(v["readers"]), len(PACKS), "each speaker described")
    eq(v["readers"][0], {"reader": "af_heart", "g": "F", "d": "heart, American, grade A"},
       "speaker 0 is af_heart, the one graded A")
    eq(v["readers"][20]["reader"], "bf_emma", "the numbers are the table's order")
    eq(rows[1]["readers"][2], {"reader": "bf_vale", "g": "F", "d": "vale, British, older, ungraded"},
       "v1.1's Vale, described as its card has her")


class _voices_root:
    """XDG_DATA_HOME moved to a folder of its own for the block: the voices' root, emptied."""

    def __enter__(self):
        import os

        self.td = tempfile.TemporaryDirectory()
        self.old = os.environ.get("XDG_DATA_HOME")
        os.environ["XDG_DATA_HOME"] = self.td.name
        return Path(self.td.name) / "ghost" / "voices"

    def __exit__(self, *exc):
        import os

        if self.old is None:
            os.environ.pop("XDG_DATA_HOME", None)
        else:
            os.environ["XDG_DATA_HOME"] = self.old
        self.td.cleanup()


@check
def test_a_voice_taught_here():
    """A VOICE TAUGHT HERE (trained/<id>/: its graph, tokenizer, one pack and voice.json) is listed beside the
    checkpoints - one speaker, its own, under its name - owned, never fetched, and read in its own accent. THE
    CONTROLS: a folder without its description is no voice, nor is a name with a path in it, nor a checkpoint's."""
    import json

    import numpy as np
    from backends.kokoro import KokoroBackend

    with _voices_root() as root:
        d = root / "kokoro" / "trained" / "kokoro-someone"
        (d / "voices").mkdir(parents=True)
        (d / "model.onnx").write_bytes(b"not a graph")
        (d / "tokenizer.json").write_text("{}")
        np.zeros((510, 1, 256), np.float32).tofile(d / "voices" / "voice.bin")
        (d / "voice.json").write_text(json.dumps({"name": "Someone (their own voice)", "british": True,
                                                  "license": "theirs", "chain": "Kokoro, taught"}))
        half = root / "kokoro" / "trained" / "kokoro-half"
        half.mkdir(parents=True)
        (half / "model.onnx").write_bytes(b"not a graph")
        k = KokoroBackend()
        rows = {r["id"]: r for r in k.voices()}
        ok("kokoro-someone" in rows and rows["kokoro-someone"]["speakers"] == 1
           and rows["kokoro-someone"]["name"] == "Someone (their own voice)" and rows["kokoro-someone"]["installed"],
           "a voice taught here is listed under its name, one speaker, installed")
        eq([r for r in rows][:2], ["kokoro", "kokoro-1.1"], "the checkpoints first, as they were")
        eq((KokoroBackend.owns("kokoro-someone"), k._download("kokoro-someone")), (True, 0), "owned, and never fetched")
        k._vocabs["kokoro-someone"] = {"a": 1}
        sp = k._speaker("kokoro-someone", 0)
        eq((sp["espeak"]["voice"], sp["kokoro"]["pack"].shape), ("en-gb", (510, 1, 256)),
           "read in its own accent, from its own pack")
        ok("kokoro-half" not in rows and not KokoroBackend.owns("kokoro-half"), "CONTROL: without its description, no voice")
        ok(not KokoroBackend.owns("../trained/kokoro-someone"), "CONTROL: a name with a path in it is not")
        eq(KokoroBackend._trained("kokoro"), None, "CONTROL: a checkpoint's name is never a voice taught here")


@check
def test_ids_of_are_what_the_graph_is_sent():
    """What a voice is taught on is what it is sent (`ids_of`, utterances.py): the same ids `_render_symbols` fed the
    graph for the same words - pads at both ends, no word-space after the last word - less the render's
    lead-in (LEAD_IN), which opens the utterance and is not the sentence."""
    from backends.kokoro import LEAD_IN

    k, cfg = _backend()
    k._vocabs["kokoro"] = cfg["kokoro"]["vocab"]
    _res, sess, _rate, _n = _render(SENTENCE)
    fed = sess.fed[0]["ids"]
    eq(k.ids_of([dict(t) for t in SENTENCE], phonemizer="ghost"), [fed[0], *fed[1 + LEAD_IN :]],
       "taught on what it is sent, the lead-in aside")


@check
def test_a_speaker_is_its_pack_and_accent():
    """The request's speaker number picks the pack and the accent eSpeak reads in; out of range is
    clamped, never an error mid-reading."""
    import numpy as np
    from backends.kokoro import PACKS, KokoroBackend

    k = KokoroBackend()
    k._vocabs = {"kokoro": {ch: i for i, ch in enumerate(VOCAB)}, "kokoro-1.1": {"a": 1}}
    asked: list = []

    def pack_array(family, name):
        asked.append((family, name))
        return np.zeros((510, 1, 256), np.float32)

    k._pack_array = pack_array
    eq(k._speaker("kokoro", 0)["espeak"]["voice"], "en-us", "an American pack is read American")
    emma = [i for i, row in enumerate(PACKS) if row[0] == "bf_emma"][0]
    eq((k._speaker("kokoro", emma)["espeak"]["voice"], k._speaker("kokoro", emma)["kokoro"]["british"]),
       ("en-gb", True), "a British pack is read British")
    k._speaker("kokoro", 999)
    vale = k._speaker("kokoro-1.1", 2)
    eq((vale["espeak"]["voice"], vale["kokoro"]["vocab"]), ("en-gb", {"a": 1}),
       "a speaker of the second checkpoint reads in that checkpoint's symbols")
    eq(asked, [("kokoro", "af_heart"), ("kokoro", "bf_emma"), ("kokoro", PACKS[-1][0]), ("kokoro-1.1", "bf_vale")],
       "each pack loaded once; past the end is the last")


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
    raise SystemExit(main())
