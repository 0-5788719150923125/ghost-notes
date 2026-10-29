#!/usr/bin/env python3
"""kokoro_train.py - Kokoro taught someone's voice, by a training loop of our own (next/voice_engines.md, "Training
Kokoro"; the user, 2026-10-26: "our own custom training loop would probably be perfectly fine").

    <voice_train_venv python> kokoro_train.py --spec <spec.json> [--progress <file>]

The spec: {"data": the prepared folder (kokoro_data.py), "model": kokoro-v1_0.pth, "config": its config.json,
"base": the pack it starts from (.bin), "work": where the run is kept, "steps", "batch", "seconds"}, and optionally
"predictor" ("kept", "pitch" or "taught") and "ear" (WavLM Base+'s pytorch_model.bin).

WHAT IS TAUGHT, AND WHAT IS NOT. Kokoro's reading of text - PL-BERT and the text encoder - is held: it was taught on
far more English than anyone's videos hold, and it is what makes the ids say the words. Taught: THE DECODER (their
timbre, from the aligned text, their pitch and their energy) and the 128 numbers of the style it reads. KOKORO'S
DELIVERY - the prosody predictor (how long each sound is held, its pitch and energy) and the 128 it reads - is the
base voice's unless the spec says `"predictor": "taught"`: on soft speech warped from another voice it was what cost
the words (`keep_delivery`).

`"predictor": "pitch"` IS STYLETTS 2'S SECOND STAGE, THE TIMING KEPT (2026-10-27, after kikiri-tts): the predictor's
pitch and energy (`shared`, `F0`, `N` and their projections) are taught on their curves, its timing held, and after
CURVES_AFTER steps the decoder is taught from THE PREDICTOR'S curves along their alignment (`F0Ntrain`), the mel's
gradient reaching the predictor through them - curves like the ones it will be played with, at their level. Kept, the
decoder was taught on their measured pitch and energy and played on the base voice's planned ones, smooth where theirs
move twice as sharply (energy, frame to frame) and lower (theirs a median 220 Hz, af_heart's 192). Each sentence's
prosody style is the base pack's row for its length, as it is read. THE VOICE IS PLAYED WITH KOKORO'S OWN DELIVERY
(kokoro_export.py leaves the taught pitch and energy behind; 2026-10-28, an ASMR channel's 12 minutes, twenty unseen
sentences): with no style read from the recording - Kokoro has none - the taught pitch follows theirs r = 0.01, and
played with it the words smeared (22.9% misheard); with Kokoro's own, 5.3%, the best taught voice yet (kept: 9.6%), its
floor between words 61 dB down (kept: 55) and its 4-8 kHz 1.3 dB under their own recordings (kept: 7.0). Taught on
Kokoro's own curves instead - its level, not theirs - the decoder learned to raise the pitch it was given and smeared
the words (20.2%); on the predictor's energy with their own pitch, 25.5%; on its curves for half a batch, 21.3%.

`"ear"` LISTENS AS STYLETTS 2 DOES: the L1 between WavLM's 13 hidden states for their audio and ours (wavlm.py,
EAR_WEIGHT), from the first step - a speech model hears a stop said or smeared, which a frame-by-frame mel does not.

THE LOSSES, StyleTTS 2's second stage less its diffusion and its speech-model discriminator:
- the decoder TEACHER-FORCED on a stretch of each sentence (their alignment, pitch and energy, `seconds` long):
  multi-resolution log-mel L1 (MEL_WEIGHT), and adversarial - a multi-period and a multi-resolution discriminator,
  least squares, with feature matching (FM_WEIGHT) - after ADV_AFTER steps of the discriminators learning alone:
  they start fresh (Kokoro's were never released), and a fresh one's verdicts would only push the decoder about;
- the predictor on the whole sentence: each id's frames (DUR_WEIGHT, the sum of its sigmoids against theirs, and
  each sigmoid against whether the id holds that many), their pitch (F0_WEIGHT) and energy (N_WEIGHT), smooth L1.

THE RUN IS KEPT (`last.pt`, written under another name and renamed into place) every SAVE_EVERY steps and at the end,
and a run goes on from it while its spec's data and base are the same. Every LISTEN_EVERY steps the held-out
sentences are said through the full model - their own plan, pitch and energy, predicted - into `listen/<step>/`.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import random
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
os.environ.setdefault("PYTORCH_CUDA_ALLOC_CONF", "expandable_segments:True")

import numpy as np  # noqa: E402

SR = 24000
HOP = 600
SAVE_EVERY = 500
LISTEN_EVERY = 1000
LISTEN_MOST = 6
ADV_AFTER = 1000
MEL_WEIGHT = 45.0
FM_WEIGHT = 2.0
ADV_WEIGHT = 1.0
DUR_WEIGHT = 1.0
F0_WEIGHT = 0.1
N_WEIGHT = 1.0
# StyleTTS 2 weighs its ear 1 against 5 x its own mel loss, about one to one on a taught voice; ours is 45 x a log-mel L1
# that runs 18 times theirs on the same audio (2026-10-27, eight batches of hers through two taught decoders)
EAR_WEIGHT = 18.0
CURVES_AFTER = 1000
LR = 1e-4
STYLE_LR = 1e-3
D_LR = 2e-4


def say(*parts) -> None:
    print("actor: kokoro:", *parts, flush=True)


def progress(path: str, frac: float) -> None:
    if not path:
        return
    tmp = path + ".part"
    with open(tmp, "w") as f:
        f.write("%.4f" % max(0.0, min(1.0, frac)))
    os.replace(tmp, path)


def span(minutes: float) -> str:
    if minutes < 90.0:
        n = max(1, round(minutes))
        return "about %d minute%s" % (n, "" if n == 1 else "s")
    return "about %.1f hours" % (minutes / 60.0)


# --- the discriminators (HiFi-GAN's multi-period, UnivNet's multi-resolution) -----------------------------

def _discriminators():
    import torch
    import torch.nn as nn
    import torch.nn.functional as F
    from torch.nn.utils import weight_norm

    class Period(nn.Module):
        def __init__(self, period):
            super().__init__()
            self.period = period
            ch = [1, 32, 128, 512, 1024]
            self.convs = nn.ModuleList([weight_norm(nn.Conv2d(ch[i], ch[i + 1], (5, 1), (3, 1), padding=(2, 0)))
                                        for i in range(4)])
            self.convs.append(weight_norm(nn.Conv2d(1024, 1024, (5, 1), 1, padding=(2, 0))))
            self.post = weight_norm(nn.Conv2d(1024, 1, (3, 1), 1, padding=(1, 0)))

        def forward(self, x):
            b, c, t = x.shape
            if t % self.period:
                x = F.pad(x, (0, self.period - t % self.period), "reflect")
            x = x.view(b, c, -1, self.period)
            maps = []
            for conv in self.convs:
                x = F.leaky_relu(conv(x), 0.1)
                maps.append(x)
            x = self.post(x)
            maps.append(x)
            return x.flatten(1), maps

    class Resolution(nn.Module):
        def __init__(self, n_fft, hop, win):
            super().__init__()
            self.n_fft, self.hop, self.win = n_fft, hop, win
            self.register_buffer("window", torch.hann_window(win), persistent=False)
            self.convs = nn.ModuleList([
                weight_norm(nn.Conv2d(1, 32, (3, 9), padding=(1, 4))),
                weight_norm(nn.Conv2d(32, 32, (3, 9), stride=(1, 2), padding=(1, 4))),
                weight_norm(nn.Conv2d(32, 32, (3, 9), stride=(1, 2), padding=(1, 4))),
                weight_norm(nn.Conv2d(32, 32, (3, 9), stride=(1, 2), padding=(1, 4))),
                weight_norm(nn.Conv2d(32, 32, (3, 3), padding=(1, 1)))])
            self.post = weight_norm(nn.Conv2d(32, 1, (3, 3), padding=(1, 1)))

        def forward(self, x):
            s = torch.stft(x.squeeze(1), self.n_fft, self.hop, self.win, window=self.window, return_complex=True)
            x = s.abs().clamp(min=1e-7).transpose(1, 2).unsqueeze(1)
            maps = []
            for conv in self.convs:
                x = F.leaky_relu(conv(x), 0.1)
                maps.append(x)
            x = self.post(x)
            maps.append(x)
            return x.flatten(1), maps

    class All(nn.Module):
        def __init__(self):
            super().__init__()
            self.ds = nn.ModuleList([Period(p) for p in (2, 3, 5, 7, 11)] +
                                    [Resolution(*r) for r in ((1024, 120, 600), (2048, 240, 1200), (512, 50, 240))])

        def forward(self, y):
            return [d(y) for d in self.ds]

    return All()


# --- the losses ------------------------------------------------------------------------------------

class MelLoss:
    """Multi-resolution log mel L1 (80 bands)."""

    RES = ((1024, 120, 600), (2048, 240, 1200), (512, 50, 240))

    def __init__(self, device):
        import librosa
        import torch

        self.banks = []
        for n_fft, hop, win in self.RES:
            fb = torch.from_numpy(librosa.filters.mel(sr=SR, n_fft=n_fft, n_mels=80)).to(device)
            self.banks.append((n_fft, hop, win, fb, torch.hann_window(win, device=device)))

    def logmel(self, y, k):
        import torch

        n_fft, hop, win, fb, w = self.banks[k]
        s = torch.stft(y, n_fft, hop, win, window=w, return_complex=True).abs()
        return torch.log((fb @ s).clamp(min=1e-5))

    def __call__(self, y_hat, y):
        return sum((self.logmel(y_hat, k) - self.logmel(y, k)).abs().mean() for k in range(len(self.banks))) / len(self.banks)


def d_loss(real, fake):
    return sum(((1 - r) ** 2).mean() + (f ** 2).mean() for (r, _), (f, _) in zip(real, fake))


def g_loss(fake):
    return sum(((1 - f) ** 2).mean() for f, _ in fake)


def fm_loss(real, fake):
    return sum((a.detach() - b).abs().mean() for (_, ra), (_, fa) in zip(real, fake) for a, b in zip(ra, fa))


# --- their sentences ---------------------------------------------------------------------------------

def load(folder: Path, rows: list) -> list:
    out = []
    for r in rows:
        d = np.load(folder / (r["utt"] + ".npz"))
        out.append({k: d[k] for k in ("audio", "ids", "frames", "f0", "n")} | {"utt": r["utt"], "text": r["text"]})
    return out


def batch(items: list, device, seconds: float):
    """Padded ids, their lengths, alignments [B, T, F], pitch and energy [B, 2F], frame lengths, and for the decoder a
    stretch of each: its start frame (`crop`) and its audio."""
    import torch

    b = len(items)
    t = max(len(x["ids"]) for x in items)
    f = max(int(x["frames"].sum()) for x in items)
    w = max(1, int(round(seconds * SR / HOP)))
    ids = torch.zeros(b, t, dtype=torch.long)
    frames = torch.zeros(b, t, dtype=torch.long)
    aln = torch.zeros(b, t, f)
    f0 = torch.zeros(b, 2 * f)
    n = torch.zeros(b, 2 * f)
    lengths = torch.zeros(b, dtype=torch.long)
    flen = torch.zeros(b, dtype=torch.long)
    crop = torch.zeros(b, dtype=torch.long)
    audio = torch.zeros(b, w * HOP)
    for i, x in enumerate(items):
        k = len(x["ids"])
        fr = torch.from_numpy(x["frames"]).long()
        total = int(fr.sum())
        ids[i, :k] = torch.from_numpy(x["ids"])
        frames[i, :k] = fr
        idx = torch.repeat_interleave(torch.arange(k), fr)
        aln[i, idx, torch.arange(total)] = 1.0
        f0[i, : 2 * total] = torch.from_numpy(x["f0"][: 2 * total])
        n[i, : 2 * total] = torch.from_numpy(x["n"][: 2 * total])
        lengths[i] = k
        flen[i] = total
        c = random.randint(0, max(0, total - w))
        crop[i] = c
        a = torch.from_numpy(x["audio"][c * HOP: (c + w) * HOP])
        audio[i, : a.shape[0]] = a
    to = lambda z: z.to(device, non_blocking=True)  # noqa: E731
    return {"ids": to(ids), "frames": to(frames), "aln": to(aln), "f0": to(f0), "n": to(n), "lengths": to(lengths),
            "flen": to(flen), "crop": crop, "audio": to(audio), "w": w}


def window(z, crop, w: int, per: int = 1):
    """[B, C, F*per] cut to each row's stretch [crop*per, (crop+w)*per), zero past its end."""
    import torch

    out = torch.zeros(*z.shape[:-1], w * per, device=z.device, dtype=z.dtype) if z.dim() == 3 else \
        torch.zeros(z.shape[0], w * per, device=z.device, dtype=z.dtype)
    for i in range(z.shape[0]):
        c = int(crop[i]) * per
        piece = z[i, ..., c: c + w * per]
        out[i, ..., : piece.shape[-1]] = piece
    return out


# --- the run ------------------------------------------------------------------------------------------

DELIVERIES = ("kept", "pitch", "taught")


def hold(model, delivery: str) -> None:
    """What is not taught, held: Kokoro's reading of text always, and the predictor as [delivery] says."""
    import torch

    for part in (model.bert, model.bert_encoder, model.text_encoder):
        part.requires_grad_(False)
        part.eval()
    # THE ADAIN NORMS' OWN SCALE AND SHIFT ARE HELD at 1 and 0: Kokoro never taught them (they are not in its checkpoint -
    # an affine norm only for an old exporter's sake) and its graph folds them away, so a value taught there could
    # never reach the voice host
    for mod in model.modules():
        if isinstance(mod, torch.nn.InstanceNorm1d):
            mod.weight.requires_grad_(False)
            mod.bias.requires_grad_(False)
    # KOKORO'S DELIVERY, KEPT unless `"predictor": "taught"` (2026-10-26, measured on an ASMR channel's soft speech; next/
    # voice_engines.md "Training Kokoro"): the prosody predictor and the half of the style it reads are held. Taught, its
    # timing was the noisiest thing in their data - warped from another voice onto soft speech - and its pitch and energy
    # threw the taught decoder: twenty unseen sentences were misheard 22-56% of their words; with Kokoro's delivery, 4.8%,
    # and their timbre most of the way (the long-term spectrum 1.6 dB off theirs, stock af_heart's 4.0). `pitch`: its
    # timing held, its pitch and energy taught
    if delivery == "kept":
        model.predictor.requires_grad_(False)
        model.predictor.eval()
    elif delivery == "pitch":
        for part in (model.predictor.text_encoder, model.predictor.lstm, model.predictor.duration_proj):
            part.requires_grad_(False)


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="kokoro_train.py")
    ap.add_argument("--spec", required=True)
    ap.add_argument("--progress", default="")
    a = ap.parse_args(argv)
    spec = json.loads(Path(a.spec).read_text(encoding="utf-8"))
    import torch
    import torch.nn.functional as F
    from kokoro_model import KModel

    if not torch.cuda.is_available():
        say("error: no CUDA graphics card - Kokoro is taught on one")
        return 2
    dev = "cuda"
    torch.backends.cuda.matmul.allow_tf32 = True
    torch.backends.cudnn.allow_tf32 = True
    data, work = Path(spec["data"]), Path(spec["work"])
    work.mkdir(parents=True, exist_ok=True)
    index = json.loads((data / "index.json").read_text(encoding="utf-8"))
    train, held = load(data, index["utterances"]), load(data, index["held_out"])
    if not train:
        say("error: no sentences to teach")
        return 2
    steps, size, seconds = int(spec.get("steps", 6000)), int(spec.get("batch", 6)), float(spec.get("seconds", 1.5))

    model = KModel.load(spec["model"], spec["config"]).to(dev)
    pack = np.fromfile(spec["base"], dtype=np.float32).reshape(-1, 256)
    typical = int(np.median([len(x["ids"]) - 2 for x in train]))
    style = torch.nn.Parameter(torch.from_numpy(pack[min(typical, len(pack)) - 1].copy())[None].to(dev))
    disc = _discriminators().to(dev)
    delivery = str(spec.get("predictor", "kept"))
    if delivery not in DELIVERIES:
        say("error: the predictor is kept, pitch or taught, not %s" % delivery)
        return 2
    keep_delivery = delivery == "kept"
    pitch = delivery == "pitch"
    hold(model, delivery)
    # each sentence's prosody style as it is read: the base pack's row for its length (Kokoro's own `pack[len - 1]`)
    rows = torch.from_numpy(pack[:, 128:].copy()).to(dev)
    ear = None
    if spec.get("ear"):
        from wavlm import Ear, WavLM

        ear = Ear(WavLM.load(spec["ear"]), dev)
    taught = [p for p in list(model.decoder.parameters()) + list(model.predictor.parameters()) if p.requires_grad]
    opt_g = torch.optim.AdamW([{"params": taught, "lr": LR}, {"params": [style], "lr": STYLE_LR}], betas=(0.8, 0.99),
                              weight_decay=0.0)
    opt_d = torch.optim.AdamW(disc.parameters(), lr=D_LR, betas=(0.8, 0.99), weight_decay=0.0)
    mel = MelLoss(dev)

    # a run taught another way is another lesson (nothing said for the default, so a run made before goes on)
    way = "" if keep_delivery and ear is None else "|%s|%s" % (delivery, "ear" if ear is not None else "")
    lesson = hashlib.sha256((json.dumps(index["utterances"]) + str(spec["base"]) + way).encode()).hexdigest()[:16]
    last = work / "last.pt"
    step = 0
    if last.exists():
        try:
            ck = torch.load(last, map_location=dev, weights_only=False)
            if ck.get("lesson") == lesson:
                model.decoder.load_state_dict(ck["decoder"])
                model.predictor.load_state_dict(ck["predictor"])
                style.data.copy_(ck["style"].to(dev))
                disc.load_state_dict(ck["disc"])
                opt_g.load_state_dict(ck["opt_g"])
                opt_d.load_state_dict(ck["opt_d"])
                step = int(ck["step"])
                say("going on from step %d" % step)
            else:
                say("new sentences or another base: starting again")
        except Exception as exc:  # noqa: BLE001
            say("the saved run could not be read (%s); starting again" % exc)

    def save():
        tmp = work / "last.part.pt"
        torch.save({"lesson": lesson, "step": step, "delivery": delivery, "decoder": model.decoder.state_dict(),
                    "predictor": model.predictor.state_dict(), "style": style.detach().cpu(), "disc": disc.state_dict(),
                    "opt_g": opt_g.state_dict(), "opt_d": opt_d.state_dict(), "base": str(spec["base"])}, tmp)
        os.replace(tmp, last)

    def listen():
        """The held-out sentences said through the whole model - its own plan, pitch and energy - and theirs beside;
        and how near the decoder comes to them given their own plan, pitch and energy (`held mel`: as it rises while
        the training loss falls, it is learning those sentences rather than them)."""
        import soundfile as sf

        model.eval()
        with torch.no_grad():
            tf = []
            for x in held:
                b = batch([x], dev, int(x["frames"].sum()) * HOP / SR)
                torch.manual_seed(0)
                _d, t_en, _l = model.encode(b["ids"], b["lengths"], style[:, 128:])
                y_hat = model.decoder(t_en @ b["aln"], b["f0"], b["n"], style[:, :128]).squeeze(1)
                y = torch.from_numpy(x["audio"][: y_hat.shape[-1]]).to(dev)[None]
                tf.append(float(mel(y_hat[:, : y.shape[-1]], y)))
            if tf:
                say("step %d: held mel %.3f" % (step, float(np.mean(tf))))
        d = work / "listen" / ("%06d" % step)
        d.mkdir(parents=True, exist_ok=True)
        for x in held[:LISTEN_MOST]:
            torch.manual_seed(0)
            y, _fr = model.synthesize(torch.from_numpy(x["ids"])[None].to(dev), style.detach())
            sf.write(str(d / (x["utt"] + ".wav")), y.cpu().numpy(), SR)
            if step == 0 or not (work / "listen" / "theirs").exists():
                (work / "listen" / "theirs").mkdir(parents=True, exist_ok=True)
            sf.write(str(work / "listen" / "theirs" / (x["utt"] + ".wav")), x["audio"], SR)
        model.decoder.train()
        if not keep_delivery:
            model.predictor.train()

    say("%s%s: %d sentences (%.1f minutes), %d held out: %d steps of %d, %.1f s stretches" % (
        {"kept": "Kokoro's delivery kept", "pitch": "its pitch and energy taught", "taught": "its delivery taught"}[delivery],
        ", WavLM listening" if ear is not None else "", len(train), sum(int(x["frames"].sum()) for x in train) * HOP / SR / 60.0, len(held), steps, size, seconds))
    if step == 0 and held:
        listen()
    model.decoder.train()
    if not keep_delivery:
        model.predictor.train()
    begun = time.monotonic()
    first = step
    keep = {}
    while step < steps:
        items = random.sample(train, min(size, len(train)))
        b = batch(items, dev, seconds)
        bs = len(items)
        s_d = style[:, :128].expand(bs, -1)
        if delivery == "taught":
            s_p = style[:, 128:].expand(bs, -1)
        else:
            s_p = rows[(b["lengths"] - 3).clamp(0, rows.shape[0] - 1)]
        # THE PREDICTOR, on the whole sentence: their frames, pitch and energy (none of it, its delivery kept; their
        # pitch and energy alone, `pitch`)
        with torch.set_grad_enabled(delivery == "taught"):
            d, t_en, logits = model.encode(b["ids"], b["lengths"], s_p)
        inner = KModel.masks(b["lengths"], b["ids"].shape[1]).logical_not()
        inner[:, 0] = False
        inner[torch.arange(bs, device=dev), b["lengths"] - 1] = False  # the pads hold the edges' silence
        want = b["frames"].float()
        sig = torch.sigmoid(logits)
        bins = (torch.arange(logits.shape[-1], device=dev)[None, None] < want[..., None]).float()
        with torch.set_grad_enabled(not keep_delivery):
            dur = (sig.sum(-1) - want).abs()[inner].mean() + F.binary_cross_entropy(sig[inner], bins[inner])
            f0_hat, n_hat = model.prosody(d, b["aln"], s_p, b["flen"])
            fmask = (torch.arange(b["f0"].shape[1], device=dev)[None] < 2 * b["flen"][:, None])
            f0_l = F.smooth_l1_loss(f0_hat[fmask], b["f0"][fmask])
            n_l = F.smooth_l1_loss(n_hat[fmask], b["n"][fmask])
        # THE DECODER, teacher-forced on a stretch of each - on the predictor's curves once it has learned theirs
        w = b["w"]
        asr = window(t_en.detach() @ b["aln"], b["crop"], w)
        f0_in, n_in = (f0_hat, n_hat) if pitch and step >= CURVES_AFTER else (b["f0"], b["n"])
        y_hat = model.decoder(asr, window(f0_in, b["crop"], w, 2), window(n_in, b["crop"], w, 2), s_d).squeeze(1)
        y = b["audio"][:, : y_hat.shape[-1]]
        y_hat = y_hat[:, : y.shape[-1]]
        # the discriminators
        adv = step >= ADV_AFTER
        opt_d.zero_grad(set_to_none=True)
        ld = d_loss(disc(y[:, None]), disc(y_hat.detach()[:, None]))
        ld.backward()
        opt_d.step()
        # the voice
        lm = mel(y_hat, y)
        loss = MEL_WEIGHT * lm + (0.0 if keep_delivery else F0_WEIGHT * f0_l + N_WEIGHT * n_l)
        if delivery == "taught":
            loss = loss + DUR_WEIGHT * dur
        le = torch.zeros((), device=dev)
        if ear is not None:
            le = ear(y_hat, y)
            loss = loss + EAR_WEIGHT * le
        if adv:
            # their audio's pass needs no gradient (its features are targets): kept, it ran the card out of memory
            with torch.no_grad():
                real = disc(y[:, None])
            fake = disc(y_hat[:, None])
            lg, lf = g_loss(fake), fm_loss(real, fake)
            loss = loss + ADV_WEIGHT * lg + FM_WEIGHT * lf
        opt_g.zero_grad(set_to_none=True)
        loss.backward()
        torch.nn.utils.clip_grad_norm_(taught + [style], 5.0)
        opt_g.step()
        step += 1
        for k, v in (("mel", lm), ("dur", dur), ("f0", f0_l), ("n", n_l), ("d", ld), ("ear", le)):
            v = float(v.detach())
            keep[k] = keep[k] * 0.98 + v * 0.02 if k in keep else v
        if step % 50 == 0 or step == steps:
            progress(a.progress, 0.99 * step / steps)
            each = (time.monotonic() - begun) / max(1, step - first)
            say("step %d of %d: mel %.3f, frames %.3f, pitch %.2f, energy %.3f, judge %.3f%s%s - %s to go" % (
                step, steps, keep["mel"], keep["dur"], keep["f0"], keep["n"], keep["d"],
                ", ear %.3f" % keep["ear"] if ear is not None else "", "" if adv else " (judges learning)",
                span((steps - step) * each / 60.0)))
        if step % SAVE_EVERY == 0 or step == steps:
            save()
        if held and (step % LISTEN_EVERY == 0 or step == steps):
            listen()
    progress(a.progress, 1.0)
    say("%d steps, %.0f minutes on the graphics card" % (step - first, (time.monotonic() - begun) / 60.0))
    return 0


if __name__ == "__main__":
    sys.exit(main())
