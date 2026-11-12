#!/usr/bin/env python3
"""kokoro_axes.py - where breath and push live in Kokoro's style, measured off its English readers and written for the
voice host (hosts/voice/kokoro_axes.json, read by hosts/voice/blend.py; next/voice_engines.md, "A Kokoro blend that
moves").

    <voice_train_venv python> kokoro_axes.py --model <kokoro-v1_0.pth> --config <config.json>
        --packs <the host's kokoro/voices folder> [--out hosts/voice/kokoro_axes.json]

Every English reader (`PACKS`) reads four sentences (their ids are the host's, `KokoroBackend.ids_of`, written in
here so this venv needs no eSpeak), each take seeded. Each take's breathiness is its cepstral peak prominence (CPP:
lower is breathier) and its effort its alpha ratio (1-5 kHz over 50-1000 Hz: higher is brighter, pushed), over its
loud frames.

- BREATH: the ridge direction over the whole style (both halves) that predicts CPP, its strength picked
  leave-one-reader-out, turned to point breathier.
- PUSH: the mean sound half of the brightest quarter of readers less that of the darkest quarter (the delivery half
  left still).
- SPREAD: the readers' principal directions (each pack's rows 20-200 averaged) and their spread, for noise that stays
  among voices.

Each axis carries its sigma: the spread of the takes' styles along it, so a move is said in readers' own terms.
Moved +-2 sigma on Heart, Emma, Santa and Michael, breath moved CPP 2-3 dB and push the alpha ratio about 15 dB, each
monotonic.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np
import torch

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import kokoro_model as km  # noqa: E402

SR = 24000
PACKS = ("af_heart", "af_bella", "af_nicole", "af_aoede", "af_kore", "af_sarah", "af_alloy", "af_nova", "af_sky",
         "af_jessica", "af_river", "am_fenrir", "am_michael", "am_puck", "am_echo", "am_eric", "am_liam", "am_onyx",
         "am_santa", "am_adam", "bf_emma", "bf_isabella", "bf_alice", "bf_lily", "bm_fable", "bm_george", "bm_lewis",
         "bm_daniel")
# (text, American ids, British ids), pads included
SENTENCES = (
    ("The harbor was still when we came down to it, an hour before the light.",
     [0, 81, 83, 16, 50, 156, 69, 123, 44, 83, 123, 16, 65, 138, 68, 16, 61, 62, 156, 102, 54, 16, 65, 86, 56, 16, 65,
      51, 16, 53, 156, 24, 55, 16, 46, 157, 39, 56, 16, 62, 135, 16, 102, 36, 3, 16, 83, 56, 16, 156, 39, 83, 123, 16,
      44, 177, 48, 157, 76, 123, 16, 81, 83, 16, 54, 156, 25, 62, 4, 0],
     [0, 81, 83, 16, 50, 156, 69, 158, 44, 83, 16, 65, 71, 68, 16, 61, 62, 156, 102, 54, 16, 65, 86, 56, 16, 65, 51,
      158, 16, 53, 156, 24, 55, 16, 46, 157, 39, 56, 16, 62, 135, 16, 102, 62, 3, 16, 83, 56, 16, 156, 39, 83, 16, 44,
      102, 48, 157, 76, 158, 16, 81, 83, 16, 54, 156, 25, 62, 4, 0]),
    ("He knew which rocks hid at high tide, which currents turned against you, and which of the other men would lie "
     "to you about both.",
     [0, 50, 51, 16, 56, 156, 63, 16, 65, 157, 102, 133, 16, 123, 156, 69, 53, 61, 16, 50, 156, 102, 46, 16, 72, 62,
      16, 50, 156, 25, 16, 62, 156, 25, 46, 3, 16, 65, 157, 102, 133, 16, 53, 156, 87, 123, 83, 56, 62, 61, 16, 62,
      156, 87, 123, 56, 46, 16, 83, 92, 156, 86, 56, 61, 62, 16, 52, 63, 3, 16, 72, 56, 46, 16, 65, 157, 102, 133, 16,
      138, 64, 16, 81, 102, 16, 156, 138, 81, 83, 123, 16, 55, 156, 86, 56, 16, 65, 135, 46, 16, 54, 156, 25, 16, 62,
      83, 16, 52, 63, 16, 83, 44, 157, 39, 62, 16, 44, 156, 31, 119, 4, 0],
     [0, 50, 51, 158, 16, 56, 52, 156, 63, 158, 16, 65, 157, 102, 133, 16, 123, 156, 71, 53, 61, 16, 50, 156, 102, 46,
      16, 43, 62, 16, 50, 156, 25, 16, 62, 156, 25, 46, 3, 16, 65, 157, 102, 133, 16, 53, 156, 138, 123, 83, 56, 62,
      61, 16, 62, 156, 87, 158, 56, 46, 16, 83, 92, 156, 86, 56, 61, 62, 16, 52, 63, 158, 3, 16, 43, 56, 46, 16, 65,
      157, 102, 133, 16, 71, 64, 16, 81, 102, 16, 156, 138, 81, 83, 16, 55, 156, 86, 56, 16, 65, 135, 46, 16, 54, 156,
      25, 16, 62, 83, 16, 52, 63, 158, 16, 83, 44, 157, 39, 62, 16, 44, 156, 33, 119, 4, 0]),
    ("A signal came in that did not belong to anything we knew.",
     [0, 83, 16, 61, 156, 102, 92, 56, 83, 54, 16, 53, 156, 24, 55, 16, 102, 56, 16, 81, 72, 62, 16, 46, 156, 102, 46,
      16, 56, 157, 69, 62, 16, 44, 177, 54, 156, 76, 112, 16, 62, 135, 16, 156, 86, 56, 102, 119, 157, 102, 112, 16,
      65, 51, 16, 56, 156, 63, 4, 0],
     [0, 83, 16, 61, 156, 102, 92, 56, 83, 54, 16, 53, 156, 24, 55, 16, 102, 56, 16, 81, 43, 62, 16, 46, 156, 102, 46,
      16, 56, 157, 71, 62, 16, 44, 102, 54, 156, 71, 112, 16, 62, 135, 16, 156, 86, 56, 102, 119, 157, 102, 112, 16,
      65, 51, 158, 16, 56, 52, 156, 63, 158, 4, 0]),
    ("He asked for a room, paid a week in advance, and went straight upstairs.",
     [0, 50, 51, 16, 156, 72, 61, 53, 62, 16, 48, 76, 123, 16, 83, 16, 123, 156, 63, 55, 3, 16, 58, 156, 24, 46, 16,
      83, 16, 65, 156, 51, 53, 16, 102, 56, 16, 83, 46, 64, 156, 72, 56, 61, 3, 16, 72, 56, 46, 16, 65, 86, 56, 62,
      16, 61, 62, 123, 156, 24, 62, 16, 138, 58, 61, 62, 156, 86, 123, 68, 4, 0],
     [0, 50, 51, 158, 16, 156, 43, 61, 53, 62, 16, 48, 76, 158, 123, 16, 83, 16, 123, 156, 63, 158, 55, 3, 16, 58, 156,
      24, 46, 16, 83, 16, 65, 156, 51, 158, 53, 16, 102, 56, 16, 83, 46, 64, 156, 43, 56, 61, 3, 16, 43, 56, 46, 16,
      65, 86, 56, 62, 16, 61, 62, 123, 156, 24, 62, 16, 138, 58, 61, 62, 156, 86, 158, 68, 4, 0]),
)
LAMBDAS = (0.1, 0.3, 1.0, 3.0, 10.0, 30.0, 100.0)
SPREAD = 12  # principal directions kept


def trim(a, gate_db=45.0):
    n = int(0.01 * SR)
    e = np.sqrt((a[: a.size // n * n].reshape(-1, n) ** 2).mean(axis=1) + 1e-12)
    on = np.where(20 * np.log10(e / e.max()) > -gate_db)[0]
    return a[max(0, on[0] * n - 720): (on[-1] + 1) * n + 720] if on.size else a


def cpp_and_alpha(a):
    """Mean cepstral peak prominence (dB) and alpha ratio (dB) over the take's loud 40 ms frames."""
    n, hop, nfft = int(0.04 * SR), int(0.01 * SR), 2048
    win = np.hanning(n)
    X = np.stack([a[i:i + n] * win for i in range(0, a.size - n, hop)])
    e = np.sqrt((X ** 2).mean(axis=1) + 1e-12)
    loud = 20 * np.log10(e / e.max()) > -25
    spec = np.abs(np.fft.rfft(X, nfft)) ** 2 + 1e-12
    ceps = np.abs(np.fft.irfft(10 * np.log10(spec), nfft))
    q = np.arange(nfft) / SR
    band = (q >= 1 / 400) & (q <= 1 / 60)
    fit = (q >= 0.001) & (q <= 1 / 60)
    A = np.vstack([q[fit], np.ones(fit.sum())]).T
    cpps = []
    for c in ceps[loud]:
        cdb = 20 * np.log10(c + 1e-9)
        coef, *_ = np.linalg.lstsq(A, cdb[fit], rcond=None)
        j = np.where(band)[0][np.argmax(cdb[band])]
        cpps.append(cdb[j] - (coef[0] * q[j] + coef[1]))
    f = np.fft.rfftfreq(nfft, 1 / SR)
    hi = spec[loud][:, (f > 1000) & (f < 5000)].sum()
    lo = spec[loud][:, (f > 50) & (f < 1000)].sum()
    return float(np.mean(cpps)), float(10 * np.log10(hi / lo))


def ridge(X, y, lam):
    mu, ym = X.mean(0), y.mean()
    Xc = X - mu
    return np.linalg.solve(Xc.T @ Xc + lam * np.eye(X.shape[1]), Xc.T @ (y - ym)), mu, ym


def loo_r(X, y, who, lam):
    pred = np.zeros_like(y)
    for v in set(who):
        tr, te = who != v, who == v
        w, mu, ym = ridge(X[tr], y[tr], lam)
        pred[te] = (X[te] - mu) @ w + ym
    return float(np.corrcoef(pred, y)[0, 1])


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="kokoro_axes.py")
    ap.add_argument("--model", required=True)
    ap.add_argument("--config", required=True)
    ap.add_argument("--packs", required=True)
    ap.add_argument("--out", default=str(HERE.parent / "voice" / "kokoro_axes.json"))
    args = ap.parse_args(argv)
    dev = "cuda" if torch.cuda.is_available() else "cpu"
    model = km.KModel.load(args.model, args.config).to(dev).eval()
    packs = {p: np.fromfile(Path(args.packs) / f"{p}.bin", dtype=np.float32).reshape(-1, 256) for p in PACKS}

    X, cpp, alpha, who = [], [], [], []
    for p in PACKS:
        for _text, us, gb in SENTENCES:
            ids = gb if p[0] == "b" else us
            row = packs[p][min(len(ids) - 2, packs[p].shape[0]) - 1]
            torch.manual_seed(3)
            audio, _frames = model.synthesize(torch.tensor([ids], device=dev), torch.tensor(row[None], device=dev))
            c, a = cpp_and_alpha(trim(audio.float().cpu().numpy()))
            X.append(row.astype(np.float64))
            cpp.append(c)
            alpha.append(a)
            who.append(p)
        print(f"{p:12s} cpp {np.mean(cpp[-4:]):6.2f}  alpha {np.mean(alpha[-4:]):6.2f}", flush=True)
    X, cpp, alpha, who = np.array(X), np.array(cpp), np.array(alpha), np.array(who)

    # breath: ridge over the whole style, pointed breathier (lower CPP)
    r, lam = max((loo_r(X, cpp, who, lam), lam) for lam in LAMBDAS)
    w, _mu, _ym = ridge(X, cpp, lam)
    breath = -w / np.linalg.norm(w)
    breath_sigma = float(((X - X.mean(0)) @ breath).std())

    # push: brightest quarter less darkest quarter, sound half
    per = {p: (X[who == p, :128].mean(0), alpha[who == p].mean()) for p in PACKS}
    order = sorted(per, key=lambda p: per[p][1])
    q = len(order) // 4
    d = np.mean([per[p][0] for p in order[-q:]], 0) - np.mean([per[p][0] for p in order[:q]], 0)
    push = np.concatenate([d / np.linalg.norm(d), np.zeros(128)])
    push_sigma = float(((X - X.mean(0)) @ push).std())
    push_r = float(np.corrcoef([per[p][0] @ push[:128] for p in PACKS], [per[p][1] for p in PACKS])[0, 1])

    # spread: the readers' principal directions
    V = np.stack([packs[p][19:200].astype(np.float64).mean(0) for p in PACKS])
    _u, s, vt = np.linalg.svd(V - V.mean(0), full_matrices=False)

    def nums(x):
        return [float(f"{v:.6g}") for v in np.asarray(x).ravel()]

    out = {
        "about": "Kokoro v1.0's style: breath and push directions and the English readers' spread, measured by "
                 "hosts/voice_train/kokoro_axes.py. A move is in sigmas: the takes' spread along the axis.",
        "breath": {"axis": nums(breath), "sigma": breath_sigma, "measure": "cepstral peak prominence, lower",
                   "loo_r": r, "lambda": lam},
        "push": {"axis": nums(push), "sigma": push_sigma, "measure": "alpha ratio, higher", "r": push_r,
                 "brightest": order[-q:], "darkest": order[:q]},
        "spread": {"axes": [nums(v) for v in vt[:SPREAD]], "sd": nums(s[:SPREAD] / np.sqrt(len(PACKS)))},
    }
    Path(args.out).write_text(json.dumps(out, indent=0) + "\n", encoding="utf-8")
    print(f"breath: leave-one-out r {r:.2f} (lambda {lam}), sigma {breath_sigma:.4f}; push: r {push_r:.2f}, sigma "
          f"{push_sigma:.4f}; spread: {SPREAD} directions -> {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
