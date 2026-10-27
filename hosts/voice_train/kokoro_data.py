"""kokoro_data.py - their sentences made ready to teach Kokoro (next/voice_engines.md, "Training Kokoro").

    <voice_train_venv python> kokoro_data.py --data <utterances folder> --base <pack.bin> --model <kokoro-v1_0.pth>
        --config <config.json> --out <prepared folder> [--progress <file>]

The utterances are Utterances' (hosts/voice/utterances.py with `"engine": "kokoro"`): 24 kHz wavs and the voice
host's own Kokoro ids. For each, what a training step reads (`<out>/<utt>.npz`):

- `audio` - the sentence without its room's steady noise (`quieted`), at Kokoro's own level (LEVEL), cut to whole
  frames of 600 samples;
- `ids` - as the host sends them, a pad at each end;
- `frames` - how many 25 ms frames each id holds, summing to the audio's: KOKORO SAYS THE SENTENCE (the base voice,
  its pace matched to theirs) and its plan, exact, is carried onto their recording by dynamic time warping over
  both's log mels, by cosine (`align`) - between two of Kokoro's own voices, where both plans are known (four pairs
  of voices, men and women, American and British, five sentences): a boundary's median error 0, 94% within a frame,
  where MFCCs were 75-78%;
- `f0` - their pitch every 300 samples, 0 where unvoiced (pYIN): Kokoro's own F0 curves are in Hz and pYIN reads
  them back within a percent on its own speech;
- `n` - their energy every 300 samples, StyleTTS 2's (the log of the norm of an 80-band power mel), IN KOKORO'S RANGE
  (`kokoro_range`): their values moved, quantile by quantile, onto the energies Kokoro planned for the same sentences.

`index.json` lists what was made and why any sentence was left out.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import wave
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

SR = 24000
HOP = 600
F0_HOP = 300
# THEIR LEVEL, KOKORO'S: the median of the loud 20 ms frames, in dB - where Kokoro's own speech sits (the PyTorch
# decoder, four sentences each: af_heart and af_bella -27, af_sarah -24, am_michael -28.5, bf_emma -24), so the
# energies its predictor knows are the ones it is taught
LEVEL = -27.0
PEAK = 0.95
FMIN, FMAX = 60.0, 600.0
# THE ROOM TAKEN OUT (`quieted`): each bin's steady noise - its power over the sentence's quietest QUIET_SHARE of frames -
# taken off GATE_OVER times over, the gain smoothed over GATE_SMOOTH bins and frames and never under GATE_FLOOR
QUIET_SHARE = 10.0
GATE_OVER = 2.0
GATE_FLOOR = 0.03
GATE_SMOOTH = (3, 3)


def say(*parts) -> None:
    print("actor: kokoro data:", *parts, flush=True)


def progress(path: str, frac: float) -> None:
    if not path:
        return
    tmp = path + ".part"
    with open(tmp, "w") as f:
        f.write("%.4f" % max(0.0, min(1.0, frac)))
    os.replace(tmp, path)


def read_wav(path: Path):
    with wave.open(str(path), "rb") as w:
        if w.getframerate() != SR or w.getnchannels() != 1:
            raise ValueError("%s is not mono at %d Hz" % (path.name, SR))
        return np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").astype(np.float32) / 32768.0


def loud_level(y) -> float:
    """The median of the loud 20 ms frames (within 30 dB of the loudest), in dB."""
    n = SR // 50
    k = len(y) // n
    lv = 10.0 * np.log10((y[: k * n].reshape(k, n) ** 2).mean(1) + 1e-12)
    return float(np.median(lv[lv > lv.max() - 30.0]))


def quieted(y):
    """THEIR RECORDING WITHOUT ITS ROOM (2026-10-26, an ASMR channel's soft speech over a high-gain microphone): a
    stationary noise - hiss, hum - every bin's power over the sentence's quietest tenth of frames, taken off as a
    Wiener-like gain, smoothed so no bin rings alone, never more than GATE_FLOOR. Taught on the noise, Kokoro learned
    it: their pauses sat 10 log units of energy over Kokoro's silence, its decoder made breathy noise wherever energy
    said so, and Whisper misheard half its words."""
    import librosa
    from scipy.ndimage import uniform_filter

    s = librosa.stft(y, n_fft=1024, hop_length=256)
    p = np.abs(s) ** 2
    e = p.sum(0)
    noise = p[:, e <= np.percentile(e, QUIET_SHARE)].mean(1, keepdims=True)
    gain = np.sqrt(np.clip(1.0 - GATE_OVER * noise / (p + 1e-12), 0.0, 1.0))
    gain = np.maximum(uniform_filter(gain, size=GATE_SMOOTH, mode="nearest"), GATE_FLOOR)
    return librosa.istft(s * gain, hop_length=256, length=len(y)).astype(np.float32)


def at_level(y):
    gain = 10.0 ** ((LEVEL - loud_level(y)) / 20.0)
    gain = min(gain, PEAK / max(1e-6, float(np.abs(y).max())))
    return (y * gain).astype(np.float32)


_MEL = None


def energy(y, frames: int):
    """StyleTTS 2's energy every F0_HOP samples (2 x frames of them): log of the norm of the 80-band power mel
    (n_fft 2048, window 1200, centered) - as measured; `kokoro_range` moves it into Kokoro's."""
    import librosa

    global _MEL
    if _MEL is None:
        _MEL = librosa.filters.mel(sr=SR, n_fft=2048, n_mels=80, htk=True, norm=None)
    s = np.abs(librosa.stft(y, n_fft=2048, hop_length=F0_HOP, win_length=1200, center=True)) ** 2
    n = np.log(np.linalg.norm(_MEL @ s + 1e-5, axis=0))
    return _fit(n, 2 * frames)


def pitch(y, frames: int):
    """Their F0 every F0_HOP samples (2 x frames), 0 where pYIN hears no voice - read at 16 kHz (the same hop in time),
    which is three times quicker and the same pitch."""
    import librosa

    y16 = librosa.resample(y, orig_sr=SR, target_sr=16000)
    f0, _v, _p = librosa.pyin(y16, fmin=FMIN, fmax=FMAX, sr=16000, frame_length=800, hop_length=200, center=True)
    return _fit(np.nan_to_num(f0, nan=0.0), 2 * frames)


def _fit(x, n: int):
    """[n] of x: cut, or its last value held."""
    x = np.asarray(x, dtype=np.float32)
    if len(x) >= n:
        return x[:n]
    return np.concatenate([x, np.full(n - len(x), x[-1] if len(x) else 0.0, np.float32)])


def logmel(y):
    """What the warp compares: 60 log mel bands every F0_HOP samples, each band standardized over the sentence."""
    import librosa

    f = np.log(librosa.feature.melspectrogram(y=y, sr=SR, n_fft=1200, hop_length=F0_HOP, n_mels=60) + 1e-6)
    return (f - f.mean(1, keepdims=True)) / (f.std(1, keepdims=True) + 1e-6)


def align(said, plan, theirs, frames: int):
    """THEIR FRAMES PER ID: Kokoro's audio `said` and its plan (whole frames per id) carried onto `theirs` by dynamic
    time warping over both's log mels - each of Kokoro's id boundaries placed where the warp takes it, then rounded to
    whole frames, every id at least one, summing to `frames`."""
    import librosa

    a, b = logmel(said), logmel(theirs)
    _d, wp = librosa.sequence.dtw(X=a, Y=b, metric="cosine")
    wp = wp[::-1]
    tgt = np.zeros(a.shape[1])
    cnt = np.zeros(a.shape[1])
    np.add.at(tgt, wp[:, 0], wp[:, 1])
    np.add.at(cnt, wp[:, 0], 1)
    tgt /= np.maximum(cnt, 1)
    bounds = np.cumsum(plan)[:-1] * 2.0  # Kokoro's id boundaries, in warp frames (two to a duration frame)
    placed = np.interp(bounds, np.arange(len(tgt)), tgt) / 2.0  # ...on theirs, in duration frames
    return whole(placed, len(plan), frames)


def whole(placed, ids: int, frames: int):
    """Boundaries (in frames, rising) to whole frames per id: each at least one, summing to `frames`."""
    edges = np.concatenate([[0.0], np.asarray(placed, dtype=np.float64), [float(frames)]])
    edges = np.maximum.accumulate(np.round(edges)).astype(np.int64)
    out = np.diff(edges)
    # an id given none borrows a frame from the longest near it, so every id is said
    for i in np.flatnonzero(out < 1):
        j = max(range(max(0, i - 3), min(ids, i + 4)), key=lambda k: out[k])
        if out[j] > 1:
            out[j] -= 1
            out[i] += 1
    out = np.maximum(out, 1)
    over = int(out.sum()) - frames
    while over > 0:
        j = int(np.argmax(out))
        out[j] -= 1
        over -= 1
    return out.astype(np.int64)


def kokoro_range(theirs, kokoros):
    """THEIR ENERGY IN KOKORO'S RANGE (2026-10-26): a function moving each of their energies to Kokoro's at the same
    quantile. Soft speech over a room never falls as quiet as Kokoro's silence - their quietest twentieth sat 8 log
    units over Kokoro's even with the room taken out - and the decoder, taught that energy, made sound wherever it
    was asked any: Whisper misheard half again as many words. Moved, the shape of their loudness is theirs and its
    values the ones Kokoro's decoder was made for."""
    qs = np.linspace(0.0, 100.0, 101)
    a = np.percentile(np.asarray(theirs, np.float64), qs)
    b = np.percentile(np.asarray(kokoros, np.float64), qs)
    a = np.maximum.accumulate(a + np.arange(len(a)) * 1e-9)
    return lambda n: np.interp(n, a, b).astype(np.float32)


def _features(job):
    """The pitch and energy of one sentence, in a process of its own (pYIN is the slow part)."""
    path, frames = job
    y = np.load(path)["audio"]
    return path, pitch(y, frames), energy(y, frames)


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="kokoro_data.py")
    ap.add_argument("--data", required=True)
    ap.add_argument("--base", required=True, help="the base voice's pack (.bin, [510, 1, 256] float32)")
    ap.add_argument("--model", required=True)
    ap.add_argument("--config", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--progress", default="")
    ap.add_argument("--workers", type=int, default=max(1, (os.cpu_count() or 2) - 1))

    a = ap.parse_args(argv)
    import torch
    from kokoro_model import KModel

    data, out = Path(a.data), Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    dev = "cuda" if torch.cuda.is_available() else "cpu"
    model = KModel.load(a.model, a.config).to(dev).eval()
    pack = torch.from_numpy(np.fromfile(a.base, dtype=np.float32).reshape(-1, 256))
    rows = []
    for name in ("metadata.csv", "test.csv"):
        p = data / name
        if p.exists():
            for line in p.read_text(encoding="utf-8").splitlines():
                if line.strip():
                    utt, text, ids = line.split("|", 2)
                    rows.append({"utt": utt, "text": text, "ids": [int(x) for x in ids.split()], "held": name == "test.csv"})
    made, left = [], {}
    jobs = []
    found = []
    planned_n: list = []
    for k, r in enumerate(rows):
        progress(a.progress, 0.5 * k / max(1, len(rows)))
        y = read_wav(data / "wav" / (r["utt"] + ".wav"))
        frames = len(y) // HOP
        ids = r["ids"]
        if frames < len(ids) or len(ids) > 510:
            left["too quick for its ids"] = left.get("too quick for its ids", 0) + 1
            continue
        y = at_level(quieted(y[: frames * HOP]))
        # KOKORO SAYS IT, at their pace: once to learn its length, again at the speed that makes it theirs
        x = torch.tensor([ids], device=dev)
        ref = pack[min(len(ids) - 2, pack.shape[0]) - 1][None].to(dev)
        speed = 1.0
        for _ in range(2):
            torch.manual_seed(0)
            said, plan = model.synthesize(x, ref, speed)
            speed = float(np.clip(speed * int(plan.sum()) / frames, 0.5, 2.0))
        planned_n.append(model.plan_of(x, ref, speed)[2])
        plan = plan.cpu().numpy()
        said = said.cpu().numpy()
        found.append({"ids": ids, "audio": y, "frames": align(said, plan, y, frames)})
        made.append({"utt": r["utt"], "text": r["text"], "held": r["held"], "frames": frames, "speed": round(speed, 3)})
    for m, it in zip(made, found):
        path = out / (m["utt"] + ".npz")
        np.savez(path, audio=it["audio"], ids=np.array(it["ids"], np.int64), frames=it["frames"])
        jobs.append((str(path), m["frames"]))
    # pitch and energy, every core but one; their energies then moved into Kokoro's range, all of them at once
    measured = []
    with ProcessPoolExecutor(max_workers=a.workers) as pool:
        for k, (path, f0, n) in enumerate(pool.map(_features, jobs, chunksize=4)):
            progress(a.progress, 0.5 + 0.45 * k / max(1, len(jobs)))
            measured.append((path, f0, n))
    move = kokoro_range(np.concatenate([n for _p, _f, n in measured]), np.concatenate(planned_n)) if planned_n else None
    for path, f0, n in measured:
        d = dict(np.load(path))
        np.savez(path, **d, f0=f0, n=move(n) if move is not None else n)
    index = {"utterances": [m for m in made if not m["held"]], "held_out": [m for m in made if m["held"]],
             "minutes": round(sum(m["frames"] for m in made) * HOP / SR / 60.0, 1), "left_out": left}
    tmp = out / "index.json.part"
    tmp.write_text(json.dumps(index, indent=1), encoding="utf-8")
    os.replace(tmp, out / "index.json")
    progress(a.progress, 1.0)
    say("%d sentences ready, %d held out, %.1f minutes" % (len(index["utterances"]), len(index["held_out"]),
                                                             index["minutes"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
