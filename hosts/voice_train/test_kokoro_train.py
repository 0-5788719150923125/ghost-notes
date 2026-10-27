#!/usr/bin/env python3
"""Tests for teaching Kokoro a voice (kokoro_model.py, kokoro_data.py, kokoro_train.py, kokoro_export.py).

Run it directly with the voice-training venv's python - no pytest needed:

    ~/.local/share/godot/app_userdata/ghost/voice_train_venv/bin/python hosts/voice_train/test_kokoro_train.py

No graphics card is needed, nothing is downloaded and nothing is trained: the model is Kokoro's shape with weights
drawn at random.

  THE CHECKPOINT LOADS WHOLE - a state dict as hexgrad saved it (every key under "module.") loads into the model, and
  a sentence plans whole frames of 600 samples (CONTROL: one missing a weight is refused, never half loaded).
  WHOLE FRAMES - boundaries placed by the warp become frames per id, each at least one, summing to the sentence's
  (CONTROL: rounding alone leaves an id none).
  A LESSON'S BATCH - each frame of a sentence aligned to one id, its pitch and energy laid at twice the rate, its
  stretch cut from where the batch says, nothing past its end.
  THE GRAPH'S WEIGHTS ARE FOUND BY VALUE - a graph whose weights are the model's in the export's forms (weight norm
  folded, matrices transposed, LSTMs' gates repacked) has each found, and a taught model's values written into it
  where they belong (CONTROL: a weight two parameters share is left alone).
  THEIR PITCH AND ENERGY - pYIN reads a 220 Hz tone at 220, at twice the frame rate, and none in silence.
"""

from __future__ import annotations

import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import numpy as np  # noqa: E402

CHECKS = []


def check(fn):
    CHECKS.append(fn)
    return fn


def ok(cond, what):
    assert cond, what
    print("    ok   " + what)


VOCAB = {c: i + 1 for i, c in enumerate("abcdefghijklmnop ")}
CONFIG = {
    "istftnet": {"upsample_kernel_sizes": [20, 12], "upsample_rates": [10, 6], "gen_istft_hop_size": 5,
                 "gen_istft_n_fft": 20, "resblock_dilation_sizes": [[1, 3, 5], [1, 3, 5], [1, 3, 5]],
                 "resblock_kernel_sizes": [3, 7, 11], "upsample_initial_channel": 512},
    "dim_in": 64, "dropout": 0.2, "hidden_dim": 512, "max_conv_dim": 512, "max_dur": 50, "multispeaker": True,
    "n_layer": 3, "n_mels": 80, "n_token": 178, "style_dim": 128, "text_encoder_kernel_size": 5,
    "plbert": {"hidden_size": 768, "num_attention_heads": 12, "intermediate_size": 2048,
               "max_position_embeddings": 512, "num_hidden_layers": 12, "dropout": 0.1},
    "vocab": VOCAB,
}

_MODEL = {}


def _model():
    """Kokoro's shape, its weights drawn at random (one, shared), and its checkpoint as hexgrad saved one."""
    import json

    import torch
    from kokoro_model import KModel

    if not _MODEL:
        torch.manual_seed(0)
        td = tempfile.mkdtemp()
        cfg = Path(td) / "config.json"
        cfg.write_text(json.dumps(CONFIG))
        m = KModel(CONFIG)
        state = {part: {"module." + k: v for k, v in getattr(m, part).state_dict().items()
                        if not (".norm.weight" in k or ".norm.bias" in k)} for part in KModel.PARTS}
        torch.save(state, Path(td) / "model.pth")
        _MODEL.update({"dir": Path(td), "config": cfg, "weights": Path(td) / "model.pth", "state": state})
    return _MODEL


@check
def the_checkpoint_loads_whole():
    import torch
    from kokoro_model import HOP, KModel

    d = _model()
    m = KModel.load(d["weights"], d["config"]).eval()
    ids = torch.tensor([[0, 3, 5, 17, 9, 2, 0]])
    torch.manual_seed(0)
    audio, frames = m.synthesize(ids, torch.zeros(1, 256))
    ok(len(frames) == 7 and int(frames.min()) >= 1 and audio.shape[0] == int(frames.sum()) * HOP,
       "a sentence plans whole frames, at least one an id, 600 samples each (%d frames)" % int(frames.sum()))
    broken = {p: dict(v) for p, v in d["state"].items()}
    broken["decoder"].pop(next(iter(broken["decoder"])))
    torch.save(broken, d["dir"] / "broken.pth")
    try:
        KModel.load(d["dir"] / "broken.pth", d["config"])
        refused = False
    except ValueError:
        refused = True
    ok(refused, "CONTROL: a checkpoint missing a weight is refused")


@check
def whole_frames():
    from kokoro_data import whole

    placed = [2.4, 2.45, 7.2, 9.9]
    got = whole(placed, 5, 12)
    ok(int(got.sum()) == 12 and int(got.min()) >= 1 and len(got) == 5, "each id at least one frame, all of them 12 (%s)" % list(got))
    plain = np.diff(np.round(np.concatenate([[0.0], placed, [12.0]])))
    ok(int(plain.min()) == 0, "CONTROL: rounded alone, an id has none (%s)" % list(plain.astype(int)))


@check
def a_lessons_batch():
    import torch
    from kokoro_train import HOP, batch, window

    items = []
    for k, frames in enumerate(([3, 2, 4], [1, 5])):
        total = sum(frames)
        items.append({"ids": np.arange(len(frames)) + 1, "frames": np.array(frames), "audio": np.arange(total * HOP, dtype=np.float32) + 1000 * k,
                      "f0": np.full(2 * total, 100.0 + k, np.float32), "n": np.full(2 * total, 1.0 + k, np.float32)})
    b = batch(items, "cpu", 4 * HOP / 24000.0)
    aln = b["aln"]
    ok(torch.equal(aln[0].sum(0), torch.ones(9)) and torch.equal(aln[1].sum(0)[:6], torch.ones(6))
       and float(aln[1].sum(0)[6:].sum()) == 0.0, "each frame of a sentence aligned to one id, none past its end")
    ok(float(b["f0"][1, :12].min()) == 101.0 and float(b["f0"][1, 12:].abs().max()) == 0.0, "pitch at twice the frame rate, padded with none")
    c = int(b["crop"][0])
    ok(torch.equal(b["audio"][0], torch.from_numpy(items[0]["audio"][c * HOP:(c + 4) * HOP])), "the stretch is cut where the batch says")
    z = torch.arange(20.0).view(1, 1, 20).repeat(2, 1, 1)
    w = window(z, torch.tensor([3, 18]), 4)
    ok(torch.equal(w[0, 0], torch.tensor([3.0, 4.0, 5.0, 6.0])) and torch.equal(w[1, 0], torch.tensor([18.0, 19.0, 0.0, 0.0])),
       "a window is the stretch, zero past the end")


@check
def the_graphs_weights_are_found_by_value():
    import onnx
    import torch
    from kokoro_export import derived, mapping
    from kokoro_model import KModel
    from onnx import helper, numpy_helper

    d = _model()
    stock = derived(KModel.load(d["weights"], d["config"]))
    keys = [k for k in stock if k.endswith(".lstm.W")][:1] + [k for k in stock if "conv_post" in k and k.endswith("weight")][:1] \
        + [k for k in stock if k.endswith(".T")][:1]
    inits = [numpy_helper.from_array(stock[k], "w%d" % i) for i, k in enumerate(keys)]
    # every Snake's alpha starts at one: a weight of ones that shape is any of them
    inits.append(numpy_helper.from_array(np.ones((1, 256, 1), np.float32), "shared_ones"))
    graph = helper.make_model(helper.make_graph([], "g", [], [], initializer=inits))
    found = mapping(graph, stock)
    ok([found.get("w%d" % i) for i in range(len(keys))] == keys, "each weight is found as what it is (%s)" % ", ".join(keys))
    taught = KModel.load(d["weights"], d["config"])
    with torch.no_grad():
        for p in list(taught.decoder.parameters()) + list(taught.predictor.parameters()):
            p.add_(0.01)
    new = derived(taught)
    ok(all(not np.allclose(new[k], stock[k]) for k in keys), "a taught model's forms are its own")
    ok("shared_ones" not in found, "CONTROL: a weight two parameters share is left alone")


@check
def their_pitch_and_energy():
    from kokoro_data import F0_HOP, SR, energy, pitch

    t = np.arange(SR, dtype=np.float32) / SR
    y = np.concatenate([0.3 * np.sin(2 * np.pi * 220.0 * t), np.zeros(SR // 2, np.float32)]).astype(np.float32)
    frames = len(y) // 600
    f0, n = pitch(y, frames), energy(y, frames)
    tone = f0[5: SR // F0_HOP - 5]
    ok(len(f0) == 2 * frames and len(n) == 2 * frames, "pitch and energy at twice the frame rate")
    ok(abs(float(np.median(tone)) - 220.0) < 3.0 and float(f0[-20:].max()) == 0.0,
       "a 220 Hz tone read at %.1f, and silence unvoiced" % float(np.median(tone)))
    ok(float(n[10]) > float(n[-10]) + 5.0, "the tone's energy over silence's")


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
