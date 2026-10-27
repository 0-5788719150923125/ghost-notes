#!/usr/bin/env python3
"""kokoro_export.py - a Kokoro voice taught here, written into the voice host's own graph (next/voice_engines.md,
"Training Kokoro").

    <voice_train_venv python> kokoro_export.py --graph <the host's patched model.onnx> --model <kokoro-v1_0.pth>
        --config <config.json> --run <the run's last.pt> --out <voice folder> --name <shown name>

THE GRAPH IS THE HOST'S, ITS WEIGHTS THE RUN'S: the export onnx-community made (and the host patched - `dur_scale`,
`rest_floor`, `durations`) is copied whole, and each of its weights that comes from what was taught (the decoder and
the prosody predictor) is written again from the run. Its weights are not under PyTorch's names - weight norm folded
in, the LSTMs' gates repacked (i f g o to i o f g, both directions stacked, their biases joined), some matrices
transposed - so WHICH IS WHICH IS FOUND BY VALUE: every derived form of every parameter of the stock checkpoint is
compared with every weight of the stock graph (`mapping`), and each match says how to make that weight from the
taught parameters. 477 of the graph's 556 weights are found so; the rest are constants (shapes, the STFT's bases).
Every taught tensor reaches the graph but the AdaIN norms' own scale and shift, which are held (kokoro_train.py).

The voice folder: `model.onnx`, `tokenizer.json` (copied beside the graph it came with), `voices/<pack>.bin` - their
taught timbre (the style's first 128) in every row of a [510, 1, 256] pack and, where Kokoro's delivery was kept (the
run's `delivery`), the base pack's own prosody row by row, as the base voice reads a sentence of each length; else the
taught style whole in every row - and `voice.json` ({name, chain, license, british}). THE EXPORT IS
CHECKED before it is kept: a sentence through the graph plans the frames PyTorch plans, and sounds as it sounds.
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import numpy as np  # noqa: E402

TAUGHT = ("decoder.", "predictor.")
PACK = "voice"
ROWS = 510


def say(*parts) -> None:
    print("actor: kokoro export:", *parts, flush=True)


def _held(name: str) -> bool:
    """An AdaIN norm's own scale or shift: never taught, and not in the graph."""
    return name.endswith(".norm.weight") or name.endswith(".norm.bias")


def derived(model) -> dict:
    """Every form a taught parameter takes in the graph: weight norm folded, a matrix transposed, a Snake's alpha
    inverted, an LSTM's gates repacked - {key: array}."""
    import torch

    for mod in model.modules():
        if hasattr(mod, "weight_g"):
            torch.nn.utils.remove_weight_norm(mod)
    out = {}
    lstms = {name for name, mod in model.named_modules() if isinstance(mod, torch.nn.LSTM)}
    for name, p in model.state_dict().items():
        if not name.startswith(TAUGHT) or _held(name) or name.rsplit(".", 1)[0] in lstms:
            continue
        a = p.detach().cpu().numpy().astype(np.float32)
        out[name] = a
        if a.ndim == 2:
            out[name + ".T"] = np.ascontiguousarray(a.T)
        if ".alpha" in name:
            out[name + ".recip"] = 1.0 / a

    def gates(w, h):
        return np.concatenate([w[:h], w[3 * h:], w[h:2 * h], w[2 * h:3 * h]], 0)  # i f g o -> i o f g

    for name, mod in model.named_modules():
        if isinstance(mod, torch.nn.LSTM) and name.startswith(TAUGHT):
            h = mod.hidden_size
            sd = {k: v.detach().cpu().numpy().astype(np.float32) for k, v in mod.state_dict().items()}
            out[name + ".lstm.W"] = np.stack([gates(sd["weight_ih_l0"], h), gates(sd["weight_ih_l0_reverse"], h)])
            out[name + ".lstm.R"] = np.stack([gates(sd["weight_hh_l0"], h), gates(sd["weight_hh_l0_reverse"], h)])
            out[name + ".lstm.B"] = np.stack([
                np.concatenate([gates(sd["bias_ih_l0"], h), gates(sd["bias_hh_l0"], h)]),
                np.concatenate([gates(sd["bias_ih_l0_reverse"], h), gates(sd["bias_hh_l0_reverse"], h)])])
    return out


def mapping(graph, stock: dict) -> dict:
    """{graph weight's name: the derived key it is} - by value, against the stock checkpoint's derived forms. A weight
    matching two different parameters is left alone (none of the taught ones does)."""
    from onnx import numpy_helper

    by_shape: dict = {}
    for k, v in stock.items():
        by_shape.setdefault(v.shape, []).append(k)
    out = {}
    for t in graph.graph.initializer:
        if t.data_type != 1:  # float32 only: the shapes and indices are ints
            continue
        v = numpy_helper.to_array(t)
        hits = [k for k in by_shape.get(v.shape, []) if np.allclose(stock[k], v, rtol=1e-4, atol=1e-6)]
        bases = {k.removesuffix(".T").removesuffix(".recip") for k in hits}
        if len(bases) == 1:
            out[t.name] = hits[0]
    return out


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="kokoro_export.py")
    ap.add_argument("--graph", required=True)
    ap.add_argument("--model", required=True)
    ap.add_argument("--config", required=True)
    ap.add_argument("--run", required=True)
    ap.add_argument("--base", default="", help="the pack the run started from: its prosody where the delivery was kept")
    ap.add_argument("--out", required=True)
    ap.add_argument("--name", default="Their own voice")
    ap.add_argument("--british", action="store_true")
    a = ap.parse_args(argv)
    import onnx
    import torch
    from onnx import numpy_helper

    from kokoro_model import KModel

    graph = onnx.load(a.graph)
    stock = derived(KModel.load(a.model, a.config))
    found = mapping(graph, stock)
    run = torch.load(a.run, map_location="cpu", weights_only=False)
    taught_model = KModel.load(a.model, a.config)
    taught_model.decoder.load_state_dict(run["decoder"])
    taught_model.predictor.load_state_dict(run["predictor"])
    taught = derived(taught_model)
    moved = 0
    for t in graph.graph.initializer:
        key = found.get(t.name)
        if key is None:
            continue
        new = taught[key].astype(np.float32)
        t.CopyFrom(numpy_helper.from_array(new.reshape(tuple(t.dims)), t.name))
        moved += 1
    out = Path(a.out)
    (out / "voices").mkdir(parents=True, exist_ok=True)
    tmp = out / "model.onnx.part"
    onnx.save(graph, str(tmp))
    style = run["style"].detach().cpu().numpy().astype(np.float32).reshape(1, 1, 256)
    pack = np.repeat(style, ROWS, axis=0)
    if str(run.get("delivery", "taught")) == "kept":
        if not a.base:
            say("error: Kokoro's delivery was kept, and the pack it was kept from was not given (--base)")
            return 1
        pack = np.fromfile(a.base, dtype=np.float32).reshape(-1, 1, 256)[:ROWS].copy()
        pack[:, :, :128] = style[:, :, :128]
    pack.tofile(out / "voices" / (PACK + ".bin.part"))

    # THE CHECK: one sentence through the graph and through PyTorch - the same frames, and the same sound but for the
    # graph's own gain (its inverse STFT leaves out the window's normalization: 1.5 here)
    import onnxruntime as ort

    ids = [0, 50, 83, 54, 156, 31, 16, 65, 156, 87, 123, 54, 46, 3, 16, 81, 102, 61, 16, 102, 68, 16, 83, 16, 62, 156,
           86, 61, 62, 4, 0]
    so = ort.SessionOptions()
    so.log_severity_level = 3
    sess = ort.InferenceSession(str(tmp), so, providers=["CPUExecutionProvider"])
    wav, dur = sess.run(None, {"input_ids": np.array([ids], np.int64), "style": style.reshape(1, 256),
                               "speed": np.array([1.0], np.float32)})
    taught_model.eval()
    torch.manual_seed(0)
    y, frames = taught_model.synthesize(torch.tensor([ids]), torch.from_numpy(style.reshape(1, 256)))
    same_plan = np.array_equal(np.asarray(dur).reshape(-1).astype(np.int64), frames.numpy())
    w, t = np.asarray(wav).reshape(-1), y.numpy()
    n = min(len(w), len(t))
    corr = float(np.corrcoef(w[:n], t[:n])[0, 1])
    say("%d of the graph's weights written from the run; a sentence through it: the same plan %s, its sound "
        "%.3f alike (gain %.2f)" % (moved, "yes" if same_plan else "NO", corr, float(np.std(w[:n]) / max(1e-9, np.std(t[:n])))))
    if not same_plan or corr < 0.95:
        tmp.unlink(missing_ok=True)
        (out / "voices" / (PACK + ".bin.part")).unlink(missing_ok=True)
        say("error: the graph does not say what the run says")
        return 1
    os.replace(tmp, out / "model.onnx")
    os.replace(out / "voices" / (PACK + ".bin.part"), out / "voices" / (PACK + ".bin"))
    shutil.copyfile(Path(a.graph).with_name("tokenizer.json"), out / "tokenizer.json")
    meta = {"name": a.name, "license": "Their own voice; Kokoro-82M's weights are Apache-2.0",
            "chain": "Kokoro-82M v1.0, its decoder taught their own speech" + (
                ", its delivery the base voice's" if str(run.get("delivery", "taught")) == "kept" else " and its delivery too"),
            "british": a.british,
            "steps": int(run.get("step", 0))}
    (out / "voice.json.part").write_text(json.dumps(meta, indent=1), encoding="utf-8")
    os.replace(out / "voice.json.part", out / "voice.json")
    return 0


if __name__ == "__main__":
    sys.exit(main())
