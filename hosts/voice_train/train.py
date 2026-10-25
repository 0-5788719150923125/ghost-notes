#!/usr/bin/env python3
"""train.py - an actor's own voice: a clean Piper checkpoint fine-tuned on their speech (next/likeness.md,
"Their own voice").

    <voice_train_venv python> train.py --spec <spec.json> [--progress <file>]
    <voice_train_venv python> train.py --export <checkpoint> --out <voice.onnx>

The spec: {"data": the utterances folder (metadata.csv, wav/, phonemes.json), "base": the base checkpoint,
"work": where training keeps its cache and checkpoint, "out": the voice (.onnx; its config beside it as
.onnx.json), "name", "espeak", "epochs", "batch"}.

THE IDS ARE THE VOICE HOST'S: utterances.py wrote each utterance's phoneme ids as hosts/voice sends them
at playback (its eSpeak reading, its homographs, its lead-in spaces), so the trainer reads them as given
(`dataset_type phoneme_ids`) and the voice is taught exactly what it will be asked.

FROM THE BASE'S WEIGHTS, NOT ITS RUN: the base is warm-started (every weight copied, a fresh optimizer and
schedule), since resuming its own run would carry on its epoch count and its decayed learning rate. Its
shape (quality) is read from its own hyperparameters.

STOPPED IS NOT LOST: every SAVE_EVERY epochs, and at the first epoch's end past SAVE_MINUTES since the last
save, the run is saved whole (`last.ckpt`, written under another name and renamed into place, so a kill never
leaves half of one), and the next run goes on from it. The voice is exported only when every epoch is done:
the step's output is newer than its start only then.

AN EPOCH IS AS LONG AS THEIR SPEECH (2026-10-24: 6,909 sentences, 8.3 hours of his, about 5 minutes an
epoch, where the first run's 65 minutes took 40 s): each epoch's line says how long the rest will take, from
the epochs this run has done past its first (which builds the cache), and the card's row shows it. It died
at epoch 2 with the card shared with another trainer, 8.3 GB of its own at the end, so the allocator grows
its segments rather than leaving reserved memory in pieces (`PYTORCH_CUDA_ALLOC_CONF`).
"""

from __future__ import annotations

import argparse
import json
import logging
import os
import sys
import time
import types
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
# Before torch is first imported: it reads this as CUDA starts.
os.environ.setdefault("PYTORCH_CUDA_ALLOC_CONF", "expandable_segments:True")

# Epochs between saves of the whole run, and the most minutes between them (an epoch of hours of their
# speech is minutes long): a stop loses at most a few minutes.
SAVE_EVERY = 5
SAVE_MINUTES = 10.0
# The share of the utterances held out to measure the mel loss on, every VALIDATE_EVERY epochs.
VALIDATION = 0.05
VALIDATE_EVERY = 10


def say(*parts) -> None:
    print("actor: voice:", *parts, flush=True)


def progress(path: str, frac: float) -> None:
    if not path:
        return
    tmp = path + ".part"
    with open(tmp, "w") as f:
        f.write("%.4f" % max(0.0, min(1.0, frac)))
    os.replace(tmp, path)


def span(minutes: float) -> str:
    """A time to go, as the row says it."""
    if minutes < 90.0:
        n = max(1, round(minutes))
        return "about %d minute%s" % (n, "" if n == 1 else "s")
    return "about %.0f hours" % (minutes / 60.0) if minutes >= 600.0 else "about %.1f hours" % (minutes / 60.0)


def install_align() -> None:
    """Piper's Cython alignment, which its wheel leaves unbuilt, is align.py's numba search."""
    import align
    pkg = "piper.train.vits.monotonic_align.monotonic_align"
    sys.modules[pkg] = types.ModuleType(pkg)
    sys.modules[pkg].core = align
    sys.modules[pkg + ".core"] = align


def export(checkpoint: Path, out: Path) -> None:
    """The checkpoint's generator as the graph the voice host reads. TorchScript's exporter, as Piper's
    own voices were made: one Ceil on the duration plan, which the host patches (`_ensure_patched`)."""
    import torch
    from piper.train.vits.lightning import VitsModel

    torch.manual_seed(1234)
    model = VitsModel.load_from_checkpoint(checkpoint, map_location="cpu", weights_only=False)
    g = model.model_g
    g.eval()
    with torch.no_grad():
        g.dec.remove_weight_norm()

    def forward(text, text_lengths, scales, sid=None):
        return g.infer(text, text_lengths, noise_scale=scales[0], length_scale=scales[1],
                       noise_scale_w=scales[2], sid=sid)[0].unsqueeze(1)

    g.forward = forward
    seq = torch.randint(low=0, high=g.n_vocab, size=(1, 50), dtype=torch.long)
    out.parent.mkdir(parents=True, exist_ok=True)
    tmp = out.with_name(out.name + ".part")
    torch.onnx.export(model=g, args=(seq, torch.LongTensor([50]), torch.FloatTensor([0.667, 1.0, 0.8]), None),
                      f=str(tmp), opset_version=15, dynamo=False,
                      input_names=["input", "input_lengths", "scales", "sid"], output_names=["output"],
                      dynamic_axes={"input": {0: "batch_size", 1: "phonemes"}, "input_lengths": {0: "batch_size"},
                                    "output": {0: "batch_size", 2: "time"}})
    os.replace(tmp, out)


def sound(path: Path) -> bool:
    """Is the saved run whole (a kill mid-save of an older version of this left one that was not)?"""
    import torch
    try:
        return "state_dict" in torch.load(path, map_location="cpu", weights_only=False, mmap=True)
    except Exception:  # noqa: BLE001
        return False


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="train.py")
    ap.add_argument("--spec", default="")
    ap.add_argument("--progress", default="")
    ap.add_argument("--export", default="")
    ap.add_argument("--out", default="")
    a = ap.parse_args(argv)
    logging.basicConfig(level=logging.WARNING)
    install_align()
    if a.export:
        export(Path(a.export), Path(a.out))
        return 0
    spec = json.loads(Path(a.spec).read_text())
    data, work, out = Path(spec["data"]), Path(spec["work"]), Path(spec["out"])
    work.mkdir(parents=True, exist_ok=True)
    import torch

    if not torch.cuda.is_available():
        say("error: no CUDA graphics card - a voice is trained on one")
        return 2
    torch.set_float32_matmul_precision("high")
    from lightning.pytorch.callbacks import Callback
    from piper.train.__main__ import VitsLightningCLI
    from piper.train.vits.dataset import VitsDataModule
    from piper.train.vits.lightning import VitsModel

    hp = torch.load(spec["base"], map_location="cpu", weights_only=False, mmap=True)["hyper_parameters"]
    quality = str(hp.get("quality", "medium"))
    epochs = int(spec.get("epochs", 200))
    last = work / "last.ckpt"
    # A SAVED RUN GOES ON only while it is the same lesson: the same base and the same sentences (only the
    # epochs asked for may change). Other sentences, or another base, start again from the base.
    import hashlib
    lesson = hashlib.sha256((str(spec["base"]) + "\n" + (data / "metadata.csv").read_text(encoding="utf-8"))
                            .encode("utf-8")).hexdigest()[:16]
    run_file = work / "run.json"
    try:
        same = json.loads(run_file.read_text(encoding="utf-8")).get("lesson") == lesson
    except (OSError, ValueError):
        same = False
    if last.exists() and not same:
        say("new sentences or another base: starting again from the base")
        last.unlink()
        import shutil
        shutil.rmtree(work / "cache", ignore_errors=True)
    if last.exists() and not sound(last):
        say("the saved run is not whole; starting again from the base")
        last.unlink()
    run_file.write_text(json.dumps({"lesson": lesson}), encoding="utf-8")
    begun = time.monotonic()

    class Keep(Callback):
        """Progress each epoch, and how long the rest will take; the whole run saved every SAVE_EVERY or
        SAVE_MINUTES, atomically."""

        first = None  # (epoch, time) at this run's first epoch's end
        saved = begun

        def on_train_epoch_end(self, trainer, module):
            e = trainer.current_epoch + 1
            now = time.monotonic()
            mel = trainer.callback_metrics.get("train_mel")
            progress(a.progress, 0.99 * e / epochs)
            if self.first is None:
                self.first = (e, now)
                each = now - begun
            else:
                each = (now - self.first[1]) / (e - self.first[0])
            left = " - %s to go" % span((epochs - e) * each / 60.0) if e < epochs else ""
            say("epoch %d of %d: mel %.3f, %.0f minutes%s" % (e, epochs, float(mel) if mel is not None else -1.0,
                                                              (now - begun) / 60.0, left))
            if e % SAVE_EVERY == 0 or e == epochs or now - self.saved >= SAVE_MINUTES * 60.0:
                tmp = work / "last.part.ckpt"
                trainer.save_checkpoint(str(tmp))
                os.replace(tmp, last)
                self.saved = time.monotonic()

    batch = int(spec.get("batch", 16))
    args = ["fit",
            "--data.voice_name", str(spec.get("name", "voice")),
            "--data.csv_path", str(data / "metadata.csv"),
            "--data.audio_dir", str(data / "wav"),
            "--data.dataset_type", "phoneme_ids",
            "--data.phonemes_path", str(data / "phonemes.json"),
            "--data.espeak_voice", str(spec.get("espeak", "en-us")),
            "--data.cache_dir", str(work / "cache"),
            "--data.config_path", str(work / "config.json"),
            "--data.batch_size", str(batch),
            "--data.validation_split", str(VALIDATION),
            "--data.num_test_examples", "0",
            "--data.num_workers", "2",
            "--model.sample_rate", str(hp["sample_rate"]),
            "--model.resblock", str(hp["resblock"]),
            "--model.resblock_kernel_sizes", str(list(hp["resblock_kernel_sizes"])),
            "--model.resblock_dilation_sizes", str([list(x) for x in hp["resblock_dilation_sizes"]]),
            "--model.upsample_rates", str(list(hp["upsample_rates"])),
            "--model.upsample_initial_channel", str(hp["upsample_initial_channel"]),
            "--model.upsample_kernel_sizes", str(list(hp["upsample_kernel_sizes"])),
            "--model.mos_metric", "none",
            "--trainer.max_epochs", str(epochs),
            "--trainer.accelerator", "gpu",
            "--trainer.devices", "1",
            "--trainer.precision", "bf16-mixed" if torch.cuda.is_bf16_supported() else "32",
            "--trainer.default_root_dir", str(work),
            "--trainer.logger", "false",
            "--trainer.enable_checkpointing", "false",
            "--trainer.enable_progress_bar", "false",
            "--trainer.enable_model_summary", "false",
            "--trainer.check_val_every_n_epoch", str(VALIDATE_EVERY),
            "--trainer.num_sanity_val_steps", "0"]
    if last.exists():
        say("going on from the saved run")
        args += ["--ckpt_path", str(last)]
    else:
        args += ["--model.warmstart_ckpt", str(spec["base"])]
    del hp
    sys.argv = [sys.argv[0]]
    VitsLightningCLI(VitsModel, VitsDataModule, args=args, save_config_kwargs={"overwrite": True},
                     trainer_defaults={"max_epochs": epochs, "callbacks": [Keep()]})
    say("exporting the voice")
    export(last, out)
    conf = json.loads((work / "config.json").read_text(encoding="utf-8"))
    conf["dataset"] = str(spec.get("name", "voice"))
    conf["audio"] = {"sample_rate": int(conf.get("audio", {}).get("sample_rate", 22050)), "quality": quality}
    conf["inference"] = {"noise_scale": 0.667, "length_scale": 1.0, "noise_w": 0.8}
    tmp = out.with_name(out.name + ".json.part")
    tmp.write_text(json.dumps(conf, ensure_ascii=False, indent=1), encoding="utf-8")
    os.replace(tmp, out.with_name(out.name + ".json"))
    progress(a.progress, 1.0)
    say("%d epochs, %.0f minutes on the graphics card" % (epochs, (time.monotonic() - begun) / 60.0))
    return 0


if __name__ == "__main__":
    sys.exit(main())
