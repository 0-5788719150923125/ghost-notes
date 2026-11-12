#!/usr/bin/env python3
"""Kokoro's graph made to take a style per token, so a voice moves within a sentence (blend.py's curves read at each
token's place in its paragraph; next/voice_engines.md, "A Kokoro blend that moves").

    make(<the host's patched model.onnx>, <model_moving.onnx>) -> bool

The stock graph takes `style` [1, 256] and holds it flat: every place the style enters is a Gemm (an AdaIN's or an
AdaLayerNorm's `fc`) whose [1, 2C] is unsqueezed to [1, 2C, 1] and broadcast over time, and one Expand that lays the
prosody half along the tokens for the duration encoder. Made here, `style` is [tokens, 256] (a row per id, pads
included):

- the duration encoder's Expand is the prosody rows themselves, [1, T, 128], and its three AdaLayerNorms' Gemms read
  the rows as they are, their [T, 2C] laid out [1, 2C, T];
- every AdaIN reads the style per frame - the rows carried onto the frames by the graph's own alignment (the [T, F]
  matrix its text and duration features are multiplied by) and smoothed over SMOOTH frames, as the PyTorch prototype
  smooths them - its [F, 2C] stretched to the length of what it normalizes, each place its nearest frame (one
  Gather: a Resize to a size known only when it runs fails the runtime's shape inference, and two Gathers for a
  linear stretch cost a tenth more of a sentence's time for steps already smoothed away).

The duration encoder's style also rides into the predictor's LSTMs through the alignment already. A row held the same
for every token renders what the stock graph renders (the same plan, frame for frame); `check` holds that before the
graph is kept. THE SITES ARE FOUND BY SHAPE, not by name: a graph whose sites are not all Gemm -> Unsqueeze -> two
Slices (an AdaIN's gamma read as 1 + gamma into a Mul with what it normalizes, or an AdaLayerNorm's Transposed) is not
made, and the reading steps from sentence to sentence instead.
"""

from __future__ import annotations

import sys
from collections import Counter, defaultdict
from pathlib import Path

STYLE = "style"
# Frames the per-frame style is smoothed over (a Hann window, 25 ms a frame): the prototype's 125 ms.
SMOOTH = 5


def make(src: Path, dst: Path) -> bool:
    """`dst` made from `src`, opened and checked (`check`) before it replaces anything - False, and nothing written,
    where the graph is not the shape this knows."""
    try:
        import numpy as np
        import onnx
        from onnx import TensorProto, helper, numpy_helper
    except ImportError:
        return False

    model = onnx.load(str(src))
    g = model.graph
    nodes = list(g.node)
    prod = {o: n for n in nodes for o in n.output}
    cons: dict = defaultdict(list)
    for n in nodes:
        for i in n.input:
            cons[i].append(n)
    init = {i.name: i for i in g.initializer}

    def const(name):
        if name in init:
            return numpy_helper.to_array(init[name])
        p = prod.get(name)
        if p is not None and p.op_type == "Constant":
            return numpy_helper.to_array(p.attribute[0].t)
        return None

    def fail(why: str) -> bool:
        print(f"ghost/voice: Kokoro graph not made to move ({why}) - a blend steps from sentence to sentence",
              file=sys.stderr)
        return False

    slices = [n for n in nodes if n.op_type == "Slice" and n.input[0] == STYLE]
    if len(slices) != 2:
        return fail(f"{len(slices)} slices of the style")
    seconds = Counter(n.input[1] for n in nodes if n.op_type == "MatMul")
    aligns = [t for t, k in seconds.items() if k >= 2 and t in prod and prod[t].op_type == "Cast"]
    if len(aligns) != 1:
        return fail(f"{len(aligns)} alignments")
    aln = aligns[0]

    added: list = []
    count = [0]

    def name(stem: str) -> str:
        count[0] += 1
        return f"ghost_moving_{stem}_{count[0]}"

    def node(op: str, inputs: list, **attrs) -> str:
        out = name(op.lower())
        added.append(helper.make_node(op, inputs, [out], name=out, **attrs))
        return out

    def ints(values) -> str:
        n = name("ints")
        g.initializer.append(numpy_helper.from_array(np.array(values, dtype=np.int64), n))
        return n

    axes0 = ints([0])
    lo2, hi3 = ints([2]), ints([3])

    def scalar(value, dtype) -> str:
        n = name("scalar")
        g.initializer.append(numpy_helper.from_array(np.array(value, dtype=dtype), n))
        return n

    zero_i, one_i = scalar(0, np.int64), scalar(1, np.int64)
    one_v, half_f = ints([1]), scalar(0.5, np.float32)

    def stretched(h3: str, normed: str) -> str:
        """[1, 2C, F] to the length of `normed` [1, C, L]: each place takes its nearest frame (the frame at
        (d + 0.5) F / L), the frames already smoothed, so a step between two is a sliver of a change."""
        f = node("Slice", [node("Shape", [h3]), lo2, hi3])                                   # [1] int64
        length = node("Slice", [node("Shape", [normed]), lo2, hi3])
        ratio = node("Div", [node("Cast", [f], to=TensorProto.FLOAT), node("Cast", [length], to=TensorProto.FLOAT)])
        steps = node("Cast", [node("Range", [zero_i, node("Squeeze", [length, axes0]), one_i])], to=TensorProto.FLOAT)
        at = node("Cast", [node("Floor", [node("Mul", [node("Add", [steps, half_f]), ratio])])], to=TensorProto.INT64)
        return node("Gather", [h3, node("Min", [at, node("Sub", [f, one_v])])], axis=2)

    hann = np.hanning(SMOOTH + 2)[1:-1]
    kernel = name("kernel")
    g.initializer.append(numpy_helper.from_array(
        np.tile((hann / hann.sum()).astype(np.float32), (128, 1, 1)), kernel))                  # [128, 1, SMOOTH]
    edges = ints([0, 0, SMOOTH // 2, 0, 0, SMOOTH - 1 - SMOOTH // 2])

    # each half: its rows [T, 128], laid along the tokens as the Expand lays the style ([1, T, 128]), and carried
    # onto the frames by the alignment [T, F] ([F, 128])
    along, frames = {}, {}
    for s in slices:
        rows = s.output[0]
        along[rows] = node("Unsqueeze", [rows, axes0])
        per_frame = node("MatMul", [node("Unsqueeze", [node("Transpose", [rows], perm=[1, 0]), axes0]), aln])
        per_frame = node("Conv", [node("Pad", [per_frame, edges], mode="edge"), kernel], group=128)  # smoothed
        frames[rows] = node("Transpose", [node("Squeeze", [per_frame, axes0]), ], perm=[1, 0])

    gone: set = set()
    rewire: dict = {}
    sites = 0
    for s in slices:
        for c in cons[s.output[0]]:
            if c.op_type == "Expand":
                rewire[c.output[0]] = along[s.output[0]]
                gone.add(c.name)
                continue
            if c.op_type != "Gemm":
                return fail(f"a {c.op_type} reads the style")
            after = cons[c.output[0]]
            if len(after) != 1 or after[0].op_type != "Unsqueeze":
                return fail(f"{c.name} is not unsqueezed")
            uq = after[0]
            halves = cons[uq.output[0]]
            if len(halves) != 2 or any(h.op_type != "Slice" for h in halves):
                return fail(f"{c.name} is not split in two")
            if any(x.op_type == "Transpose" for h in halves for x in cons[h.output[0]]):
                # an AdaLayerNorm, at token rate: [T, 2C] -> [1, 2C, T]
                h = node("Unsqueeze", [node("Transpose", [c.output[0]], perm=[1, 0]), axes0])
            else:
                # an AdaIN, at frame rate, resized to what it normalizes
                normed = None
                for half in halves:
                    for add in cons[half.output[0]]:
                        other = [i for i in add.input if i != half.output[0]]
                        if add.op_type == "Add" and other and const(other[0]) is not None \
                                and float(np.asarray(const(other[0])).ravel()[0]) == 1.0:
                            for mul in cons[add.output[0]]:
                                if mul.op_type == "Mul":
                                    normed = [i for i in mul.input if i != add.output[0]][0]
                if normed is None:
                    return fail(f"{c.name}: what it normalizes was not found")
                c.input[0] = frames[s.output[0]]
                h = stretched(node("Unsqueeze", [node("Transpose", [c.output[0]], perm=[1, 0]), axes0]), normed)
            rewire[uq.output[0]] = h
            gone.add(uq.name)
            sites += 1
    if sites < 10:
        return fail(f"only {sites} places the style enters")

    kept = [n for n in nodes if n.name not in gone] + added
    for n in kept:
        for k, i in enumerate(n.input):
            if i in rewire:
                n.input[k] = rewire[i]
    ordered = _ordered(kept, {i.name for i in g.input} | set(init) | {i.name for i in g.initializer})
    if ordered is None:
        return fail("its nodes have no order")
    del g.node[:]
    g.node.extend(ordered)
    # the export's shapes say [1, ...] where a style now has a row a token: left, the runtime plans by them
    del g.value_info[:]
    for i in g.input:
        if i.name == STYLE:
            dims = i.type.tensor_type.shape.dim
            dims[0].ClearField("dim_value")
            dims[0].dim_param = "style_tokens"
    tmp = dst.with_name(dst.name + ".making")
    onnx.save(model, str(tmp))
    if not check(src, tmp):
        tmp.unlink(missing_ok=True)
        return fail("it does not render what the stock graph renders")
    tmp.replace(dst)
    print(f"ghost/voice: Kokoro graph made to move a voice within a sentence ({sites} places)", file=sys.stderr)
    return True


def _ordered(nodes: list, ready: set):
    """`nodes` in an order where each comes after what it reads (Kahn's), or None."""
    have = set(ready) | {""}
    waiting = list(nodes)
    out: list = []
    while waiting:
        rest = []
        for n in waiting:
            if all(i in have for i in n.input):
                out.append(n)
                have.update(n.output)
            else:
                rest.append(n)
        if len(rest) == len(waiting):
            return None
        waiting = rest
    return out


def check(stock: Path, moving: Path) -> bool:
    """Whether `moving` opens and, fed a reader's row for every token (the first pack beside `stock`), plans what `stock`
    plans, frame for frame, and makes the same sound: the level within 3%, the spectrogram's loud cells correlated
    0.98 or more. Not sample for sample: the harmonic source takes the angle of a spectrum, which a rounding flips
    near pi, and a style that is no reader's (noise) is fragile enough to part further."""
    try:
        import numpy as np
        import onnxruntime as ort
    except ImportError:
        return False
    opts = ort.SessionOptions()
    opts.log_severity_level = 3
    try:
        a = ort.InferenceSession(str(stock), sess_options=opts, providers=["CPUExecutionProvider"])
        b = ort.InferenceSession(str(moving), sess_options=opts, providers=["CPUExecutionProvider"])
    except Exception as exc:  # noqa: BLE001 - a graph that will not open is never kept
        print(f"ghost/voice: the moving Kokoro graph will not open ({exc})", file=sys.stderr)
        return False
    ids = np.array([[0, 50, 156, 102, 54, 16, 65, 156, 51, 54, 4, 0]], dtype=np.int64)
    packs = sorted((Path(stock).parent / "voices").glob("*.bin"))
    row = (np.fromfile(packs[0], dtype=np.float32).reshape(-1, 256)[9:10] if packs
           else np.zeros((1, 256), dtype=np.float32))
    speed = np.array([1.0], dtype=np.float32)
    try:
        wa, da = a.run(None, {"input_ids": ids, STYLE: row, "speed": speed})[:2]
        wb, db = b.run(None, {"input_ids": ids, STYLE: np.repeat(row, ids.shape[1], axis=0), "speed": speed})[:2]
    except Exception as exc:  # noqa: BLE001
        print(f"ghost/voice: the moving Kokoro graph will not run ({exc})", file=sys.stderr)
        return False
    if not np.array_equal(np.asarray(da).ravel(), np.asarray(db).ravel()) or wa.size != wb.size:
        return False
    if not packs:
        return True

    def cells(x):
        x = np.asarray(x, dtype=np.float64).ravel()
        win = np.hanning(1024)
        return 20 * np.log10(np.abs(np.fft.rfft(np.stack([x[i:i + 1024] * win for i in range(0, x.size - 1024, 256)]),
                                                axis=1)) + 1e-6)

    la, lb = float(np.sqrt(np.mean(np.square(wa)))), float(np.sqrt(np.mean(np.square(wb))))
    sa, sb = cells(wa), cells(wb)
    loud = sa > sa.max() - 50
    return la > 0.0 and abs(lb / la - 1.0) < 0.03 and float(np.corrcoef(sa[loud], sb[loud])[0, 1]) >= 0.98
