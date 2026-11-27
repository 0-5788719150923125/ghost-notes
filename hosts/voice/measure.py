"""What a take sounds like as numbers (the host's `measure`; next/delivery.md, "Tuning a delivery"): its length, how much of it is
voiced, its pitch (semitones over 100 Hz: the median, the 10th and 90th percentiles, the spread between them) and its level (dBFS
of the part that sounds), and both across it in tenths - so a delivery's Lab and its designer hear a delivery against its plain
twin. Pure numpy.

The pitch is the first autocorrelation peak within 0.85 of the best lag in 70-400 Hz, a frame voiced where that peak is over 0.5
and the frame within 32 dB of the take's peak; a breathy voice loses its low phrase ends below that, so compare its upper
quantiles more than its median.
"""

from __future__ import annotations

import wave

HOP = 0.01
WIN = 0.04
LOW_HZ = 70.0
HIGH_HZ = 400.0
VOICED = 0.5
QUIET_DB = 32.0
TENTHS = 10


def _load(path: str):
    import numpy as np

    with wave.open(path) as w:
        sr = w.getframerate()
        ch = w.getnchannels()
        width = w.getsampwidth()
        raw = w.readframes(w.getnframes())
    if width == 2:
        a = np.frombuffer(raw, "<i2").astype(np.float64) / 32768.0
    elif width == 4:
        a = np.frombuffer(raw, "<i4").astype(np.float64) / 2147483648.0
    else:
        a = (np.frombuffer(raw, np.uint8).astype(np.float64) - 128.0) / 128.0
    return a.reshape(-1, ch).mean(axis=1), sr


def track(a, sr: int):
    """(f0 Hz per HOP step, NaN where unvoiced; level dBFS per step)."""
    import numpy as np

    hop, win = int(HOP * sr), int(WIN * sr)
    lo, hi = int(sr / HIGH_HZ), int(sr / LOW_HZ)
    if a.size < win + hop:
        return np.zeros(0), np.zeros(0)
    w = np.hanning(win)
    peak = float(np.max(np.abs(a))) + 1e-9
    f0, lv = [], []
    for i in range(0, a.size - win, hop):
        x = a[i:i + win]
        rms = float(np.sqrt(np.mean(x * x)))
        lv.append(20.0 * np.log10(rms + 1e-9))
        if 20.0 * np.log10(rms / peak + 1e-12) < -QUIET_DB:
            f0.append(np.nan)
            continue
        x = (x - x.mean()) * w
        r = np.fft.irfft(np.abs(np.fft.rfft(x, 2 * win)) ** 2)[:win]
        if r[0] <= 0:
            f0.append(np.nan)
            continue
        r = r / r[0]
        seg = r[lo:hi]
        best = float(seg.max()) if seg.size else 0.0
        if best < VOICED:
            f0.append(np.nan)
            continue
        cand = [k for k in range(1, seg.size - 1) if seg[k] >= 0.85 * best and seg[k] >= seg[k - 1] and seg[k] >= seg[k + 1]]
        f0.append(sr / ((cand[0] if cand else int(np.argmax(seg))) + lo))
    return np.array(f0), np.array(lv)


def of_samples(a, sr: int) -> dict:
    """The numbers of one take's samples (mono float)."""
    import numpy as np

    f0, lv = track(a, sr)
    out = {"seconds": round(a.size / float(sr), 3), "voiced": 0.0, "pitch": None, "pitch_low": None, "pitch_high": None,
           "spread": None, "level": None, "pitch_tenths": [], "level_tenths": []}
    if f0.size == 0:
        return out
    ok = ~np.isnan(f0)
    out["voiced"] = round(float(ok.sum()) * HOP, 3)
    loud = lv > (lv.max() - QUIET_DB)
    if loud.any():
        out["level"] = round(float(10.0 * np.log10(np.mean(10.0 ** (lv[loud] / 10.0)))), 2)
    if ok.sum() >= 3:
        st = 12.0 * np.log2(f0[ok] / 100.0)
        lo_, med, hi_ = (float(np.percentile(st, q)) for q in (10, 50, 90))
        out.update({"pitch": round(med, 2), "pitch_low": round(lo_, 2), "pitch_high": round(hi_, 2), "spread": round(hi_ - lo_, 2)})
    n = f0.size
    for k in range(TENTHS):
        a0, a1 = n * k // TENTHS, max(n * (k + 1) // TENTHS, n * k // TENTHS + 1)
        seg, sl = f0[a0:a1], lv[a0:a1]
        v = seg[~np.isnan(seg)]
        out["pitch_tenths"].append(round(float(np.median(12.0 * np.log2(v / 100.0))), 1) if v.size else None)
        out["level_tenths"].append(round(float(sl.max()), 1) if sl.size else None)
    return out


def of_files(paths: list) -> dict:
    """Each take's numbers (`takes`), and all of them heard end to end as one (`all`)."""
    import numpy as np

    takes, parts, rate = [], [], None
    for p in paths:
        try:
            a, sr = _load(str(p))
        except (OSError, EOFError, wave.Error) as exc:
            takes.append({"error": str(exc)})
            continue
        takes.append(of_samples(a, sr))
        if rate is None or rate == sr:
            rate = sr
            parts.append(a)
    whole = of_samples(np.concatenate(parts), rate) if parts else {}
    return {"takes": takes, "all": whole}
