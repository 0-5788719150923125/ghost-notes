#!/usr/bin/env python3
"""Kokoro's graph made to sing: its pitch and energy curves taken as inputs (next/music.md, "Kokoro sings").

    make(<the host's patched model.onnx>, <model_sung.onnx>) -> bool
    curves(<model_sung.onnx>, <model_sung_curves.onnx>) -> bool

Kokoro's decoder makes the waveform from a pitch curve: the prosody predictor plans F0 and energy along the alignment
(two values a duration frame, 12.5 ms each), and the decoder's harmonic source and its convolutions read them. Made
here, each curve passes through `curve * keep + set` on its way to the decoder - `f0_keep`/`f0_set` and
`n_keep`/`n_set`, overridable initializers of 1 and 0 - so unfed the graph renders what the stock graph renders, and
fed `keep` 0 and `set` a curve as long as the alignment (2 x its frames) it sings that curve. The curves as planned
come back as `f0_planned` and `n_planned`.

With the host's own patch (`dur_scale`, `rest_floor`), the durations are set too: `dur_scale` 0 and `rest_floor` the
frames each token holds. `curves` cuts the sung graph to its planned curves alone (no decoder: a fraction of a call)
for the pass that reads what Kokoro would do with those durations before the pass that sings.

THE SOURCE IS GIVEN BACK ITS BREATH (`breath`, an overridable initializer of 0): Kokoro's harmonic source is StyleTTS2's
SineGen, trained as `sin * uv + noise` with noise of NOISE_VOICED where voiced and a third of the sine's amplitude where not,
and the export dropped the noise. Told no pitch with none (a whisper, the host's `whisper`), the source is silent - a state
the decoder never met - and it buzzes at twice its 80 Hz frame rate; fed `breath` 1 it has the noise it was trained with.
Unfed, nothing is added.

THE SITES ARE FOUND BY NAME AND SHAPE: the predictor's `F0_proj` and `N_proj` convolutions, each read by one Squeeze
whose output is the curve. A graph without them is not made, and the voice cannot sing. The source is the input of
`m_source/l_linear`'s MatMul, made by a Mul of the sine and the voicing (a Cast); where it is not found the graph sings
without breath. The graph a voice moves in
(kokoro_moving.py, a style row a token) is made so too: its pitch is what an inflected reading of a moving voice moves.
"""

from __future__ import annotations

import sys
from pathlib import Path

INPUTS = (("f0_keep", 1.0), ("f0_set", 0.0), ("n_keep", 1.0), ("n_set", 0.0))
PLANNED = ("f0_planned", "n_planned")
BREATH = "breath"
# SineGen's noise where voiced (`noise_std`); where not it is the sine's amplitude over three, read off the graph
NOISE_VOICED = 0.003
# what a graph made here says it is (its metadata `ghost_sung`): one made before the breath is made again
VERSION = "2"


def make(src: Path, dst: Path) -> bool:
    """`dst` made from `src`, opened and checked (`check`) before it replaces anything - False, and nothing written,
    where the graph is not the shape this knows."""
    try:
        import numpy as np
        import onnx
        from onnx import TensorProto, helper, numpy_helper
    except ImportError:
        return False

    def fail(why: str) -> bool:
        print(f"ghost/voice: Kokoro's graph cannot be made to sing - {why}", file=sys.stderr)
        return False

    model = onnx.load(str(src))
    g = model.graph
    nodes = list(g.node)
    cons: dict = {}
    for n in nodes:
        for i in n.input:
            cons.setdefault(i, []).append(n)
    sites = []
    for proj in ("F0_proj", "N_proj"):
        convs = [n for n in nodes if n.op_type == "Conv" and proj in n.name]
        if len(convs) != 1:
            return fail(f"{len(convs)} {proj} convolutions")
        readers = cons.get(convs[0].output[0], [])
        if len(readers) != 1 or readers[0].op_type != "Squeeze":
            return fail(f"{proj} is not read by one Squeeze")
        sites.append(readers[0].output[0])
    names = {i.name for i in g.input} | {i.name for i in g.initializer}
    if any(k in names for k, _v in INPUTS):
        return fail("it is already made")
    for curve, (keep, put), planned in zip(sites, (INPUTS[0:2], INPUTS[2:4]), PLANNED):
        kept, out = curve + "_ghost_kept", curve + "_ghost_sung"
        for n in nodes:
            for j, inp in enumerate(n.input):
                if inp == curve:
                    n.input[j] = out
        at = next(i for i, n in enumerate(nodes) if curve in n.output)
        nodes[at + 1:at + 1] = [
            helper.make_node("Mul", [curve, keep[0]], [kept], name="ghost_sung_" + keep[0]),
            helper.make_node("Add", [kept, put[0]], [out], name="ghost_sung_" + put[0]),
            helper.make_node("Identity", [curve], [planned], name="ghost_" + planned),
        ]
        g.output.append(helper.make_tensor_value_info(planned, TensorProto.FLOAT, None))
    del g.node[:]
    g.node.extend(nodes)
    for name, value in INPUTS:
        g.initializer.append(numpy_helper.from_array(np.full(1, value, np.float32), name))
        g.input.append(helper.make_tensor_value_info(name, TensorProto.FLOAT, None))
    if not _breathe(g):
        print("ghost/voice: Kokoro's harmonic source was not found - it sings without breath", file=sys.stderr)
    model.metadata_props.add(key="ghost_sung", value=VERSION)
    tmp = dst.with_name(dst.name + ".making")
    onnx.save(model, str(tmp))
    if not check(src, tmp):
        tmp.unlink(missing_ok=True)
        return fail("unfed, it does not render what the stock graph renders")
    tmp.replace(dst)
    return True


def curves(sung: Path, dst: Path) -> bool:
    """`dst`: the sung graph cut to its planned curves (the inputs they depend on in, `f0_planned` and `n_planned` out).
    False where it cannot be cut."""
    try:
        import onnx
    except ImportError:
        return False
    try:
        model = onnx.load(str(sung))
        told = {k for k, _v in INPUTS} | {BREATH}  # downstream of the curves: a cut that listed them would need them fed
        cut = onnx.utils.Extractor(model).extract_model([i.name for i in model.graph.input if i.name not in told],
                                                         list(PLANNED))
        tmp = dst.with_name(dst.name + ".making")
        onnx.save(cut, str(tmp))
        tmp.replace(dst)
        return True
    except Exception as exc:  # noqa: BLE001 - the whole graph plans instead
        print(f"ghost/voice: no curve graph for {sung.name} ({exc})", file=sys.stderr)
        return False


def _breathe(g) -> bool:
    """Graph `g`'s harmonic source given SineGen's noise back, times the input `breath` (0 unfed) - False, `g` untouched,
    where the source is not the shape this knows."""
    import numpy as np
    from onnx import TensorProto, helper, numpy_helper

    made = {o: n for n in g.node for o in n.output}
    inits = {i.name: i for i in g.initializer}
    linear = [n for n in g.node if n.op_type == "MatMul" and "m_source/l_linear" in n.name]
    if len(linear) != 1:
        return False
    src = linear[0].input[0]
    mul = made.get(src)
    if mul is None or mul.op_type != "Mul" or len(mul.input) != 2:
        return False
    casts = [i for i in mul.input if i in made and made[i].op_type == "Cast"]
    if len(casts) != 1:
        return False
    uv = casts[0]
    sine = made.get(next(i for i in mul.input if i != uv))
    amp = 0.1
    if sine is not None and sine.op_type == "Mul":
        for i in sine.input:
            if i in inits and int(np.prod(inits[i].dims or [1])) == 1:
                amp = float(numpy_helper.to_array(inits[i]).reshape(-1)[0])
    for name, value in (("ghost_breath_voiced", NOISE_VOICED), ("ghost_breath_unvoiced", amp / 3.0), ("ghost_breath_one", 1.0)):
        g.initializer.append(numpy_helper.from_array(np.array(value, np.float32), name))
    g.initializer.append(numpy_helper.from_array(np.zeros(1, np.float32), BREATH))
    g.input.append(helper.make_tensor_value_info(BREATH, TensorProto.FLOAT, None))
    out = "ghost_breath_source"
    added = [
        helper.make_node("RandomNormalLike", [src], ["ghost_breath_n"], name="ghost_breath_noise", dtype=TensorProto.FLOAT,
                         mean=0.0, scale=1.0, seed=5.0),
        helper.make_node("Sub", ["ghost_breath_one", uv], ["ghost_breath_off"], name="ghost_breath_off"),
        helper.make_node("Mul", [uv, "ghost_breath_voiced"], ["ghost_breath_on_amp"], name="ghost_breath_on_amp"),
        helper.make_node("Mul", ["ghost_breath_off", "ghost_breath_unvoiced"], ["ghost_breath_off_amp"], name="ghost_breath_off_amp"),
        helper.make_node("Add", ["ghost_breath_on_amp", "ghost_breath_off_amp"], ["ghost_breath_amp"], name="ghost_breath_amp"),
        helper.make_node("Mul", ["ghost_breath_amp", BREATH], ["ghost_breath_fed"], name="ghost_breath_fed"),
        helper.make_node("Mul", ["ghost_breath_n", "ghost_breath_fed"], ["ghost_breath_term"], name="ghost_breath_term"),
        helper.make_node("Add", [src, "ghost_breath_term"], [out], name="ghost_breath_add"),
    ]
    nodes = list(g.node)
    for n in nodes:
        if n is not mul:
            for j, i in enumerate(n.input):
                if i == src:
                    n.input[j] = out
    at = nodes.index(mul)
    nodes[at + 1:at + 1] = added
    del g.node[:]
    g.node.extend(nodes)
    return True


def check(stock: Path, sung: Path) -> bool:
    """Whether `sung` opens and, unfed, makes what `stock` makes from the same ids and row: the same frames and the
    same samples (a Mul by 1 and an Add of 0 change no float)."""
    try:
        import numpy as np
        import onnxruntime as ort
    except ImportError:
        return False
    opts = ort.SessionOptions()
    opts.log_severity_level = 3
    try:
        a = ort.InferenceSession(str(stock), sess_options=opts, providers=["CPUExecutionProvider"])
        b = ort.InferenceSession(str(sung), sess_options=opts, providers=["CPUExecutionProvider"])
    except Exception as exc:  # noqa: BLE001 - a graph that will not open is never kept
        print(f"ghost/voice: the sung Kokoro graph will not open ({exc})", file=sys.stderr)
        return False
    ids = np.array([[0, 50, 156, 102, 54, 16, 65, 156, 51, 54, 4, 0]], dtype=np.int64)
    packs = sorted((Path(stock).parent / "voices").glob("*.bin"))
    row = (np.fromfile(packs[0], dtype=np.float32).reshape(-1, 256)[9:10] if packs
           else np.zeros((1, 256), dtype=np.float32))
    # a graph that takes a style a token (kokoro_moving.py) is fed the one row for every id
    first = a.get_inputs()[[i.name for i in a.get_inputs()].index("style")].shape[0]
    if first != 1:
        row = np.repeat(row, ids.shape[1], axis=0)
    feed = {"input_ids": ids, "style": row, "speed": np.array([1.0], dtype=np.float32)}
    try:
        wa, da = a.run(None, feed)[:2]
        got = b.run(None, feed)
    except Exception as exc:  # noqa: BLE001
        print(f"ghost/voice: the sung Kokoro graph will not run ({exc})", file=sys.stderr)
        return False
    names = [o.name for o in b.get_outputs()]
    wb, db = got[names.index("waveform")], got[names.index("durations")]
    return bool(np.array_equal(np.asarray(da).ravel(), np.asarray(db).ravel()) and np.array_equal(wa, wb))


if __name__ == "__main__":
    ok = make(Path(sys.argv[1]), Path(sys.argv[2]))
    raise SystemExit(0 if ok else 1)
