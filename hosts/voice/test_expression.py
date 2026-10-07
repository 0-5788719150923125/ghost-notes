#!/usr/bin/env python3
"""Tests for the voice's expression controls in the Piper backend: the duration plan steered.

Run it directly with the voice venv's python - no pytest needed:

    ~/.local/share/godot/app_userdata/ghost/voice_venv/bin/python \
        hosts/voice/test_expression.py

What is held, each with the case that must not change:

  1. a word leaned on (`emph`) lengthens ITS stressed vowel through `dur_scale`, and an
     unmarked sentence feeds nothing (the request it always was);
  2. the opening word's vowel is floored (`OPENING_VOWEL`) - once, in the first word, at
     the request's length scale - and the vowel probe's own renders are left alone;
  3. the leaned-on word is lifted by its gain and nothing else is;
  4. `play_ratio` plays the take back in the host and every time returned follows it;
  5. the resampler is band-limited, against the linear one it replaced;
  6. a voice patched before `dur_scale` existed gains it and keeps its floor.

Synthesis runs against a fake ONNX session, as in test_pauses.py: deterministic audio and
durations, no model download, no eSpeak.
"""

from __future__ import annotations

import math
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

SR = 22050

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


class _FakeMap:
    """A phoneme_id_map that knows every symbol, so nothing is ever dropped."""

    def __init__(self) -> None:
        self._ids: dict = {}

    def get(self, sym, default=None):
        if sym not in self._ids:
            self._ids[sym] = [len(self._ids) + 3]
        return self._ids[sym]

    def items(self):
        return self._ids.items()


def _cfg() -> dict:
    return {
        "audio": {"sample_rate": SR},
        "phoneme_id_map": _FakeMap(),
        "num_speakers": 1,
        "inference": {},
        "espeak": {"voice": "en-us"},
    }


class _Session:
    """The fake voice behind a fully patched graph: a duration of 2-4 frames per id, scaled
    by `dur_scale` and then floored by `rest_floor`, in the order `_ensure_patched` puts them
    after the ceiling. Records what it was fed. `takes` is which of the two inputs
    the graph has."""

    def __init__(self, takes=("rest_floor", "dur_scale")) -> None:
        self.takes = tuple(takes)
        self.fed: list = []

    def get_overridable_initializers(self):
        import types

        return [types.SimpleNamespace(name=n) for n in self.takes]

    def run(self, _outputs, feeds):
        import numpy as np
        from backends.piper import DUR_SCALE_INPUT, HOP_LENGTH, REST_FLOOR_INPUT

        ids = list(feeds["input"][0])
        scale = feeds.get(DUR_SCALE_INPUT)
        floor = feeds.get(REST_FLOOR_INPUT)
        self.fed.append(
            {
                "ids": ids,
                "scale": None if scale is None else np.array(scale),
                "floor": None if floor is None else np.array(floor),
            }
        )
        frames = np.array([2.0 + (int(i) % 3) for i in ids])
        if scale is not None:
            frames = frames * scale
        if floor is not None:
            frames = np.maximum(frames, floor)
        n = int(frames.sum()) * HOP_LENGTH
        t = np.arange(n, dtype=np.float64)
        audio = (0.5 * np.sin(2.0 * np.pi * t / 64.0)).astype(np.float32)
        return [audio.reshape(1, 1, -1), frames.astype(np.float32).reshape(1, -1)]


def _tok(text, punct, arpa, emph=0):
    t = {"text": text, "punct": punct, "fallback": arpa}
    if emph:
        t["emph"] = emph
    return t


SENTENCE = [
    _tok("it", "", ["IH1", "T"]),
    _tok("was", "", ["W", "AA1", "Z"]),
    _tok("never", "", ["N", "EH1", "V", "ER0"]),
    _tok("so", ".", ["S", "OW1"]),
]


def _render(tokens, params=None, sess=None):
    """`_synth_tokens` on the fake voice. Returns (result, session, map, wav samples)."""
    import numpy as np
    from backends.piper import PiperBackend

    sess = sess or _Session()
    cfg = _cfg()
    with tempfile.TemporaryDirectory() as td:
        out = Path(td) / "a.wav"
        res = PiperBackend()._synth_tokens(
            list(tokens),
            "fake",
            str(out),
            {"phonemizer": "ghost", "pause_scale": 0.0, **(params or {})},
            cfg,
            sess,
        )
        raw = out.read_bytes()
    pcm = np.frombuffer(raw[44:], "<i2").astype(np.float32) / 32768.0
    return res, sess, cfg["phoneme_id_map"], pcm


def _ids_of(pmap, *syms):
    return {pmap.get(s)[0] for s in syms}


# -- 1. stress ---------------------------------------------------------------


@check
def test_nuclei():
    """The vowel run after the primary stress; the first run where there is none."""
    from backends.piper import _nuclei

    syms = [
        ("n", 0), ("ˈ", 0), ("ɛ", 0), ("v", 0), ("ɚ", 0),  # never: the stressed ɛ
        (" ", 0),
        ("s", 1), ("ˈ", 1), ("o", 1), ("ʊ", 1),  # so: the diphthong, whole
        (" ", 1),
        ("ð", 2), ("ə", 2),  # the: no stress mark, its first vowel
        (" ", 2),
        ("ˈ", 3), ("i", 3), ("ː", 3),  # a length mark rides with its vowel
    ]
    eq(sorted(_nuclei(syms)), [1, 2, 7, 8, 9, 12, 14, 15, 16], "nuclei, each with its stress mark")


@check
def test_stress_lengthens_its_vowel_only():
    """`emph` scales the marked word's stressed vowel and nothing else; unmarked feeds nothing."""
    from backends.piper import EMPHASIS

    toks = [dict(t) for t in SENTENCE]
    toks[2]["emph"] = 1
    _res, sess, pmap, _pcm = _render(toks)
    fed = sess.fed[0]
    ok(fed["scale"] is not None, "a leaned-on word feeds the duration scale")
    from backends.piper import PAD

    scaled = {i for i, m in enumerate(fed["scale"]) if m != 1.0}
    eq(
        {fed["ids"][i] for i in scaled} - {PAD},
        _ids_of(pmap, "ˈ", "ɛ"),
        "only the stressed syllable of 'never' is scaled: its mark and its vowel",
    )
    ids = fed["ids"]
    v = ids.index(pmap.get("ɛ")[0])
    eq(
        sorted(scaled),
        [v - 2, v - 1, v, v + 1],
        "with the blanks inside it and the one after it, and nothing either side",
    )
    ok(
        abs(float(fed["scale"][min(scaled)]) - EMPHASIS[1][0]) < 1e-6,
        "by the italic level's multiplier",
    )
    toks[2]["emph"] = 2
    _res, sess, _pmap, _pcm = _render(toks)
    ok(abs(float(max(sess.fed[0]["scale"])) - EMPHASIS[2][0]) < 1e-6, "bold leans harder")
    # the controls: no mark, and a graph that cannot take the input
    _res, sess, _pmap, _pcm = _render(SENTENCE)
    eq(sess.fed[0]["scale"], None, "an unmarked sentence feeds no scale")
    _res, sess, _pmap, _pcm = _render(toks, sess=_Session(takes=("rest_floor",)))
    eq(sess.fed[0]["scale"], None, "a graph without the input is never fed it")


@check
def test_stress_lengthens_the_take():
    """...and the plan the graph used is longer by the stretched frames, the word's span too."""
    plain, _s, _m, pcm0 = _render(SENTENCE)
    toks = [dict(t) for t in SENTENCE]
    toks[2]["emph"] = 2
    leaned, _s, _m, pcm1 = _render(toks)
    ok(pcm1.size > pcm0.size, "the take is longer", "%d > %d" % (pcm1.size, pcm0.size))
    span = {int(t["index"]): t["t1"] - t["t0"] for t in plain["tokens"]}
    span2 = {int(t["index"]): t["t1"] - t["t0"] for t in leaned["tokens"]}
    ok(span2[2] > span[2], "the word leaned on is longer", "%.3f > %.3f" % (span2[2], span[2]))
    ok(abs(span2[0] - span[0]) < 1e-9, "the word before it is not")


# -- 2. the opening vowel ------------------------------------------------------


@check
def test_opening_vowel_is_floored_once():
    """One floor, on the first word's vowel, of OPENING_VOWEL at the request's length scale."""
    from backends.piper import HOP_LENGTH, OPENING_VOWEL

    frame = HOP_LENGTH / float(SR)
    for ls in (1.0, 1.4):
        _res, sess, pmap, _pcm = _render(SENTENCE, {"length_scale": ls})
        fed = sess.fed[0]
        floored = [i for i, f in enumerate(fed["floor"]) if f > 0]
        eq(len(floored), 1, "one id floored at length scale %.1f" % ls)
        eq(fed["ids"][floored[0]], pmap.get("ɪ")[0], "and it is the vowel of 'it'")
        eq(
            float(fed["floor"][floored[0]]),
            float(math.ceil(OPENING_VOWEL * ls / frame - 1e-9)),
            "to OPENING_VOWEL at length scale %.1f" % ls,
        )


@check
def test_the_vowel_probe_is_left_alone():
    """`_render_symbols` without `opening` - how vowel_probe.py renders - floors nothing."""
    from backends.piper import PiperBackend

    sess = _Session()
    PiperBackend()._render_symbols(
        [(" ", 0), ("ˈ", 0), ("ɪ", 0), ("t", 0), (" ", 0)], _cfg(), sess, {}
    )
    eq(sess.fed[0]["floor"], None, "no floor fed")
    eq(sess.fed[0]["scale"], None, "no scale fed")


# -- 3. the gain -----------------------------------------------------------


@check
def test_emphasis_gain():
    """The word is lifted by its level's dB, eased; outside it the audio is untouched."""
    import numpy as np
    from backends.piper import EMPHASIS, EMPHASIS_RAMP, _emphasize

    a = np.full(SR, 0.25, np.float32)
    edges = {0: (0.1, 0.2), 1: (0.4, 0.6)}
    group = [{"text": "a"}, {"text": "b", "emph": 1}]
    out = _emphasize(a, edges, group, SR)
    want = 0.25 * 10 ** (EMPHASIS[1][1] / 20.0)
    ok(abs(float(out[int(0.5 * SR)]) - want) < 1e-5, "the word is lifted to its level")
    ramp = int(EMPHASIS_RAMP * SR)
    ok(
        np.all(out[: int(0.4 * SR) - ramp - 1] == a[: int(0.4 * SR) - ramp - 1]),
        "nothing before it moves",
    )
    ok(np.all(out[int(0.6 * SR) + ramp + 1 :] == 0.25), "nothing after it moves")
    step = float(np.max(np.abs(np.diff(out.astype(np.float64)))))
    ok(step < 0.25 * 0.01, "no step anywhere: the lift is eased", "largest %.5f" % step)
    eq(
        _emphasize(a, edges, [{"text": "a"}, {"text": "b"}], SR) is a,
        True,
        "no mark: the same array back",
    )


# -- 4. the Tone, played back in the host --------------------------------------


@check
def test_play_ratio():
    """The take comes back played at the ratio, and every time returned is in its seconds."""
    import numpy as np

    plain, _s, _m, pcm0 = _render(SENTENCE)
    r = 2.0 ** (1.5 / 12.0)
    played, _s, _m, pcm1 = _render(SENTENCE, {"play_ratio": r})
    eq(pcm1.size, int(round(pcm0.size / r)), "the length is divided by the ratio")
    eq(float(played["played"]), r, "the result says it was played")
    for a, b in zip(plain["tokens"], played["tokens"]):
        for key in ("t0", "t1"):
            ok(
                abs(b[key] - a[key] / r) < 1e-3,
                "token %d %s follows the playback" % (a["index"], key),
            )
    same, _s, _m, pcm2 = _render(SENTENCE, {"play_ratio": 1.0})
    ok(np.array_equal(pcm2, pcm0), "a ratio of 1 is the take it always was")


# -- 5. the resampler ---------------------------------------------------------


def _worst_spur(fn, ratio: float, tones=(4000.0, 6000.0, 8000.0)) -> float:
    """dB of the largest spur against the moved tone, over a few tones."""
    import numpy as np

    t = np.arange(SR) / SR
    worst = -300.0
    for f in tones:
        y = fn(np.sin(2 * np.pi * f * t).astype(np.float32), ratio)[1000:-1000]
        spec = np.abs(np.fft.rfft(y * np.hanning(y.size)))
        freqs = np.fft.rfftfreq(y.size, 1 / SR)
        near = np.abs(freqs - f * ratio) < 60
        main = spec[near].max()
        spec[near] = 0
        worst = max(worst, 20 * np.log10(spec.max() / main))
    return worst


def _linear(a, ratio: float):
    """The interpolation `_resample` replaced, as the control."""
    import numpy as np

    n = max(1, int(round(a.size / ratio)))
    idx = np.linspace(0.0, a.size - 1.0, n)
    lo = np.floor(idx).astype(np.int64)
    hi = np.minimum(lo + 1, a.size - 1)
    fr = idx - lo
    return (a[lo] * (1 - fr) + a[hi] * fr).astype(np.float32)


@check
def test_resampler_is_band_limited():
    """Every spur under -70 dB at the Tone presets' ratios; the linear control is far above it."""
    from backends.piper import _resample

    for semis in (1.5, -3.0, -4.0):
        r = 2.0 ** (semis / 12.0)
        got = _worst_spur(_resample, r)
        ok(got < -70.0, "%+.1f semitones: worst spur %.1f dB" % (semis, got))
        ctl = _worst_spur(_linear, r)
        ok(ctl > -40.0, "...where linear left %.1f dB (the control)" % ctl)
    import numpy as np

    a = np.random.default_rng(1).standard_normal(5000).astype(np.float32)
    eq(_resample(a, 1.09).size, int(round(a.size / 1.09)), "the length the linear one had")
    eq(_resample(a, 1.0) is a, True, "a ratio of 1 is the same array")


# -- 6. the patch --------------------------------------------------------------


@check
def test_an_old_patch_gains_the_scale():
    """A graph patched before `dur_scale` (the floor only) gets it, and keeps its floor."""
    try:
        import numpy as np
        import onnx
        import onnxruntime as ort
        from onnx import TensorProto, helper, numpy_helper
    except ImportError as exc:
        print("    -- onnx/onnxruntime missing (%s); skipping" % exc)
        return
    from backends.piper import DUR_SCALE_INPUT, REST_FLOOR_INPUT, PiperBackend

    # what `_ensure_patched` used to leave: the plan exposed, a Max taking the floor
    graph = helper.make_graph(
        [
            helper.make_node("Ceil", ["x"], ["w_planned"]),
            helper.make_node("Max", ["w_planned", REST_FLOOR_INPUT], ["w"]),
            helper.make_node("ReduceSum", ["w"], ["total"], keepdims=0),
        ],
        "plan",
        [
            helper.make_tensor_value_info("x", TensorProto.FLOAT, [1, 1, "n"]),
            helper.make_tensor_value_info(REST_FLOOR_INPUT, TensorProto.FLOAT, None),
        ],
        [
            helper.make_tensor_value_info("total", TensorProto.FLOAT, None),
            helper.make_tensor_value_info("w", TensorProto.FLOAT, None),
        ],
        [numpy_helper.from_array(np.zeros(1, np.float32), REST_FLOOR_INPUT)],
    )
    model = helper.make_model(graph, opset_imports=[helper.make_opsetid("", 13)])
    model.ir_version = 8
    x = np.array([[[0.2, 1.5, 2.0]]], np.float32)
    with tempfile.TemporaryDirectory() as td:
        path = Path(td) / "v.onnx"
        onnx.save(model, str(path))
        PiperBackend._ensure_patched(path)
        once = path.read_bytes()
        PiperBackend._ensure_patched(path)
        eq(path.read_bytes() == once, True, "patched again: left alone")
        s = ort.InferenceSession(str(path), providers=["CPUExecutionProvider"])
    eq(
        sorted(i.name for i in s.get_overridable_initializers()),
        sorted([REST_FLOOR_INPUT, DUR_SCALE_INPUT]),
        "both inputs",
    )
    _t, w = s.run(None, {"x": x})
    eq(np.asarray(w).ravel().tolist(), [1.0, 2.0, 2.0], "unfed, the plan it always was")
    _t, w = s.run(
        None,
        {
            "x": x,
            DUR_SCALE_INPUT: np.array([1.0, 2.0, 1.0], np.float32),
            REST_FLOOR_INPUT: np.array([4.0, 0.0, 0.0], np.float32),
        },
    )
    eq(np.asarray(w).ravel().tolist(), [4.0, 4.0, 2.0], "ceiled, then scaled, then floored")


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
