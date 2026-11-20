"""dsp.py - the music host's kit: every sound a composed Sound makes, from oscillators, noise and filters (next/music.md,
"The instruments"). No samples and no model: what an instrument is is a few numbers read by these.

Everything is a numpy array of float64 at RATE. An envelope, a filter's cutoff or a pitch may be a number or an array a
sample each. The pieces:

- band-limited oscillators (PolyBLEP: a naive saw aliases badly on a high note), a phase from a pitch curve;
- envelopes: ADSR (linear attack, exponential decay and release) and a plain exponential decay;
- filters: a resonant low-pass whose cutoff may move (RBJ biquads at fixed cutoffs, mixed by where the cutoff is),
  fixed high-, low- and band-passes, one-pole smoothing;
- noise, white and pink;
- Karplus-Strong (a noise burst in a damped delay line, worked a period at a time: each period reads only the one
  before it, so a period is one vector step);
- a reverb's impulse response (decaying noise, its highs dying first, two decorrelated channels) and the space it makes
  by FFT convolution; a tempo-synced delay as its echoes laid down one by one; chorus; drive; a compressor; a limiter;
  the sidechain duck; equal-power pan.

TRAP: a moving cutoff is a mix of fixed filters, so a resonant sweep has two peaks a step apart as it passes between
them; MORPH_STEP is narrow enough that it reads as one.
"""

from __future__ import annotations

import numpy as np
from scipy import ndimage, signal

RATE = 44100
# Octaves between the fixed filters a moving cutoff is mixed from (half that where the filter rings).
MORPH_STEP = 1.0 / 6.0


def midi_hz(m):
    """Equal temperament, A4 = 440 Hz."""
    return 440.0 * 2.0 ** ((np.asarray(m, dtype=float) - 69.0) / 12.0)


def seconds(n: int, rate: int = RATE) -> np.ndarray:
    return np.arange(n) / float(rate)


# --- oscillators ------------------------------------------------------------------------------------

def phase(freq, n: int, rate: int = RATE, start: float = 0.0) -> tuple[np.ndarray, np.ndarray]:
    """(phase in cycles, the step each sample) for a pitch `freq` - a number or an array of n."""
    inc = np.broadcast_to(np.asarray(freq, dtype=float) / rate, (n,)).astype(float)
    ph = np.cumsum(inc) - inc + start
    return ph, inc


def _blep(t: np.ndarray, dt: np.ndarray) -> np.ndarray:
    """PolyBLEP's correction near a step at t = 0 (t in cycles, dt the step a sample)."""
    out = np.zeros_like(t)
    dt = np.maximum(dt, 1e-9)
    lo = t < dt
    x = t[lo] / dt[lo]
    out[lo] = x + x - x * x - 1.0
    hi = t > 1.0 - dt
    x = (t[hi] - 1.0) / dt[hi]
    out[hi] = x * x + x + x + 1.0
    return out


def saw(ph: np.ndarray, dt: np.ndarray) -> np.ndarray:
    t = np.mod(ph, 1.0)
    return 2.0 * t - 1.0 - _blep(t, dt)


def pulse(ph: np.ndarray, dt: np.ndarray, width: float = 0.5) -> np.ndarray:
    t = np.mod(ph, 1.0)
    naive = np.where(t < width, 1.0, -1.0)
    return naive + _blep(t, dt) - _blep(np.mod(t - width, 1.0), dt)


def triangle(ph: np.ndarray, _dt=None) -> np.ndarray:
    t = np.mod(ph, 1.0)
    return 1.0 - 4.0 * np.abs(t - 0.5)


def sine(ph: np.ndarray, _dt=None) -> np.ndarray:
    return np.sin(2.0 * np.pi * ph)


WAVES = {"saw": saw, "square": pulse, "pulse": pulse, "triangle": triangle, "sine": sine}


# --- envelopes --------------------------------------------------------------------------------------

def adsr(n: int, gate: float, a: float, d: float, s: float, r: float, rate: int = RATE) -> np.ndarray:
    """An envelope n samples long for a key held `gate` seconds: a linear rise over `a`, an exponential fall to `s`
    over about `d`, held, then let go over about `r` (each fall's time constant a quarter of its time)."""
    t = seconds(n, rate)
    if n == 0:
        return t
    a = max(a, 1e-4)
    rise = np.clip(t / a, 0.0, 1.0)
    fall = s + (1.0 - s) * np.exp(-np.maximum(t - a, 0.0) / max(d / 4.0, 1e-4))
    held = np.where(t < a, rise, fall)
    at = int(max(gate, 0.0) * rate)
    if at >= n:
        return held
    level = held[at]
    tail = level * np.exp(-(t[at:] - t[at]) / max(r / 4.0, 1e-4))
    out = held.copy()
    out[at:] = tail
    return out


def decay(n: int, tau: float, attack: float = 0.0005, rate: int = RATE) -> np.ndarray:
    """A hit's envelope: a tiny rise (no click), then e^(-t/tau)."""
    t = seconds(n, rate)
    return np.clip(t / max(attack, 1e-5), 0.0, 1.0) * np.exp(-t / max(tau, 1e-5))


def release_of(a: float, d: float, r: float) -> float:
    """Seconds an ADSR note sounds past its gate, to about -50 dB."""
    return r * 1.5


# --- filters ----------------------------------------------------------------------------------------

def _rbj_lowpass(fc: float, q: float, rate: int) -> tuple[np.ndarray, np.ndarray]:
    w0 = 2.0 * np.pi * min(max(fc, 10.0), rate * 0.45) / rate
    alpha = np.sin(w0) / (2.0 * max(q, 0.1))
    c = np.cos(w0)
    b = np.array([(1.0 - c) / 2.0, 1.0 - c, (1.0 - c) / 2.0])
    a = np.array([1.0 + alpha, -2.0 * c, 1.0 - alpha])
    return b / a[0], a / a[0]


def _fixed_lowpass(x: np.ndarray, fc: float, q: float, poles: int, rate: int) -> np.ndarray:
    y = x
    for qq in ([0.54, q] if poles >= 4 else [q]):
        b, a = _rbj_lowpass(fc, qq, rate)
        y = signal.lfilter(b, a, y)
    return y


def lowpass(x: np.ndarray, cutoff, q: float = 0.707, rate: int = RATE, poles: int = 2) -> np.ndarray:
    """A resonant low-pass (`q` 0.707 flat; higher rings at the cutoff); `poles` 4 runs two in a row, the second
    carrying the resonance. `cutoff` a number, or an array a sample each: then the signal runs through fixed filters
    spaced MORPH_STEP octaves apart over the cutoff's range, and each sample is the mix of the two either side of its
    cutoff - a sweep as a handful of whole-signal passes rather than a filter re-tuned every few samples."""
    y = np.asarray(x, dtype=float)
    if np.ndim(cutoff) == 0:
        return _fixed_lowpass(y, float(cutoff), q, poles, rate)
    cut = np.clip(np.broadcast_to(np.asarray(cutoff, dtype=float), y.shape), 20.0, rate * 0.45)
    oct_ = np.log2(cut)
    lo, hi = float(oct_.min()), float(oct_.max())
    step = MORPH_STEP / 2.0 if q > 1.5 else MORPH_STEP
    if hi - lo < 1e-3:
        return _fixed_lowpass(y, float(cut[0]), q, poles, rate)
    k = int(np.ceil((hi - lo) / step)) + 1
    grid = lo + np.arange(k) * step
    pos = np.clip((oct_ - lo) / step, 0.0, k - 1 - 1e-9)
    i = pos.astype(int)
    w = pos - i
    out = np.zeros_like(y)
    for j in range(k):
        below, above = np.flatnonzero(i == j), np.flatnonzero(i == j - 1)
        if below.size == 0 and above.size == 0:
            continue
        f = _fixed_lowpass(y, float(2.0 ** grid[j]), q, poles, rate)
        out[below] += f[below] * (1.0 - w[below])
        out[above] += f[above] * w[above]
    return out


def butter(x: np.ndarray, kind: str, hz, order: int = 2, rate: int = RATE) -> np.ndarray:
    """A fixed Butterworth filter: kind `lowpass`, `highpass` or `bandpass` (hz a pair)."""
    nyq = rate * 0.5
    w = np.clip(np.asarray(hz, dtype=float) / nyq, 1e-4, 0.999)
    sos = signal.butter(order, w, btype=kind, output="sos")
    return signal.sosfilt(sos, x, axis=-1)


def onepole(x: np.ndarray, hz: float, rate: int = RATE) -> np.ndarray:
    a = np.exp(-2.0 * np.pi * hz / rate)
    return signal.lfilter([1.0 - a], [1.0, -a], x, axis=-1)


# --- noise ------------------------------------------------------------------------------------------

def noise(n: int, rng: np.random.Generator, color: str = "white") -> np.ndarray:
    w = rng.standard_normal(n)
    if color == "pink":  # Paul Kellet's economy filter, about -3 dB an octave
        b = [0.049922035, -0.095993537, 0.050612699, -0.004408786]
        a = [1.0, -2.494956002, 2.017265875, -0.522189400]
        w = signal.lfilter(b, a, w) * 4.0
    return w


# --- physical models --------------------------------------------------------------------------------

def karplus(n: int, freq: float, decay_s: float, bright: float, rng: np.random.Generator, rate: int = RATE,
            pick: float = 0.0) -> np.ndarray:
    """A plucked string: a noise burst (filtered by `bright`, 0 dull to 1 bright) in a delay line a period long,
    each pass averaged and scaled so the string falls 60 dB over `decay_s`. `pick` (0 to 0.5) is where it is plucked:
    a comb on the burst."""
    freq = float(min(max(freq, 20.0), rate / 4.0))
    s = 0.5 * (1.0 - 0.9 * bright)  # the loop's two-tap average: 0.5 is the darkest
    d = rate / freq - s
    per = max(int(d), 2)
    frac = d - per
    g = 10.0 ** (-3.0 / max(decay_s * freq, 1e-3))
    c0, c1 = 1.0 - s, s
    # the loop reads y[n-per], y[n-per-1], y[n-per-2]: the averaging taps, fractionally delayed
    k0, k1, k2 = g * c0 * (1.0 - frac), g * (c1 * (1.0 - frac) + c0 * frac), g * c1 * frac
    burst = noise(per, rng)
    burst = onepole(burst, 800.0 + 12000.0 * bright, rate)
    if pick > 0.0:
        sh = int(per * pick)
        burst = burst - np.concatenate([np.zeros(sh), burst[:per - sh]])
    burst = burst / max(1e-9, np.abs(burst).max())
    y = np.zeros(n + 3)
    y[3:3 + min(per, n)] = burst[:min(per, n)]
    # y index offset by 3 so the taps two before the start read zeros
    for s0 in range(3 + per, n + 3, per):
        e = min(s0 + per, n + 3)
        m = e - s0
        y[s0:e] += k0 * y[s0 - per:s0 - per + m] + k1 * y[s0 - per - 1:s0 - per - 1 + m] + k2 * y[s0 - per - 2:s0 - per - 2 + m]
    return y[3:]


def modal(n: int, freqs, decays, amps, rate: int = RATE) -> np.ndarray:
    """A struck thing: decaying sines, one a mode (frequency, seconds to -60 dB, level)."""
    t = seconds(n, rate)
    out = np.zeros(n)
    for f, dcy, amp in zip(freqs, decays, amps):
        if f >= rate * 0.45:
            continue
        out += amp * np.sin(2.0 * np.pi * f * t) * np.exp(-6.91 * t / max(dcy, 1e-3))
    return out


# --- effects ----------------------------------------------------------------------------------------

def drive(x: np.ndarray, amount: float) -> np.ndarray:
    """Saturation: 0 is clean; 1 is a warm overdrive; above that, distortion."""
    if amount <= 0.0:
        return x
    k = 1.0 + 8.0 * amount
    return np.tanh(k * x) / np.tanh(k)


def pan(mono: np.ndarray, p: float) -> np.ndarray:
    """Equal-power pan: p -1 left, 0 middle, 1 right. [2, n]."""
    ang = (min(max(p, -1.0), 1.0) + 1.0) * np.pi / 4.0
    return np.stack([mono * np.cos(ang), mono * np.sin(ang)]) * np.sqrt(2.0)


def reverb_ir(seconds_: float, rng: np.random.Generator, damp: float = 0.5, predelay: float = 0.012,
              rate: int = RATE) -> np.ndarray:
    """A room's answer to a click, [2, n]: decorrelated noise falling 60 dB over `seconds_` at the lows and sooner
    the higher it is (`damp` 0 bright to 1 dark), after `predelay`, a few early reflections first."""
    n = int((seconds_ * 1.3 + predelay) * rate)
    t = seconds(n, rate)
    pre = int(predelay * rate)
    out = np.zeros((2, n))
    bands = [(None, 400.0, 1.0), ((400.0, 3000.0), None, 0.85 - 0.35 * damp), (3000.0, None, 0.6 - 0.45 * damp)]
    for ch in range(2):
        w = rng.standard_normal(n)
        acc = np.zeros(n)
        for lo, hi, share in bands:
            if lo is None:
                b = butter(w, "lowpass", hi, 2, rate)
            elif hi is None and isinstance(lo, tuple):
                b = butter(w, "bandpass", lo, 2, rate)
            else:
                b = butter(w, "highpass", lo, 2, rate)
            rt = max(seconds_ * share, 0.05)
            acc += b * np.exp(-6.91 * t / rt)
        acc[:pre] = 0.0
        # early reflections: a few taps in the first 60 ms
        for _ in range(6):
            at = pre + int(rng.uniform(0.002, 0.06) * rate)
            if at < n:
                acc[at] += rng.uniform(-1.0, 1.0) * 3.0
        out[ch] = acc
    out /= np.sqrt(np.sum(out ** 2) / 2.0) + 1e-9
    return out


def convolve(x: np.ndarray, ir: np.ndarray) -> np.ndarray:
    """A stereo signal [2, n] through a stereo impulse response, cut to n."""
    n = x.shape[-1]
    return np.stack([signal.oaconvolve(x[c], ir[c])[:n] for c in range(2)])


def echo(x: np.ndarray, delay_s: float, feedback: float, rate: int = RATE, tone: float = 4000.0,
         spread: bool = True) -> np.ndarray:
    """A delay's echoes alone ([2, n] in and out): each `delay_s` later, `feedback` softer and duller, the left and
    right taking turns where `spread`."""
    d = max(int(delay_s * rate), 1)
    n = x.shape[-1]
    out = np.zeros_like(x)
    cur = x
    gain = 1.0
    k = 1
    while gain * feedback > 0.02 and k * d < n and k < 24:
        gain *= feedback
        cur = onepole(cur, tone, rate)
        shifted = np.zeros_like(x)
        shifted[:, k * d:] = cur[:, :n - k * d] * gain
        if spread and k % 2 == 1:
            shifted = shifted[::-1]
        out += shifted
        k += 1
    return out


def chorus(x: np.ndarray, depth_ms: float = 3.0, rate_hz: float = 0.8, mix: float = 0.5, rate: int = RATE) -> np.ndarray:
    """A slowly swaying copy beside each channel ([2, n]), the two sways opposite."""
    n = x.shape[-1]
    t = seconds(n, rate)
    idx = np.arange(n, dtype=float)
    out = np.empty_like(x)
    for c in range(2):
        lag = (depth_ms * 1e-3 * rate) * (1.5 + np.sin(2.0 * np.pi * rate_hz * t + np.pi * c))
        out[c] = x[c] * (1.0 - mix * 0.5) + mix * 0.5 * np.interp(idx - lag, idx, x[c], left=0.0)
    return out


def compress(x: np.ndarray, threshold_db: float = -18.0, ratio: float = 3.0, window_s: float = 0.02,
             rate: int = RATE) -> np.ndarray:
    """A gentle compressor on [2, n] or [n]: the level over `window_s`, everything above the threshold brought down by
    the ratio, the gain smoothed over the same window."""
    mono = x if x.ndim == 1 else np.max(np.abs(x), axis=0)
    w = max(int(window_s * rate), 1)
    rms = np.sqrt(ndimage.uniform_filter1d(mono ** 2, w) + 1e-12)
    over = 20.0 * np.log10(rms) - threshold_db
    gain_db = -np.maximum(over, 0.0) * (1.0 - 1.0 / max(ratio, 1.0))
    gain = 10.0 ** (ndimage.uniform_filter1d(gain_db, w) / 20.0)
    return x * gain


def limit(x: np.ndarray, ceiling_db: float = -1.0, look_s: float = 0.004, rate: int = RATE) -> np.ndarray:
    """A look-ahead limiter on [2, n]: the gain falls before a peak that would pass the ceiling and comes back over a
    few times as long; a soft clip catches what is left."""
    ceil = 10.0 ** (ceiling_db / 20.0)
    peak = np.max(np.abs(x), axis=0)
    w = max(int(look_s * rate), 1)
    held = ndimage.maximum_filter1d(peak, size=2 * w + 1)
    g = np.minimum(1.0, ceil / np.maximum(held, 1e-9))
    g = ndimage.minimum_filter1d(g, size=2 * w + 1)
    g = ndimage.uniform_filter1d(g, size=2 * w + 1)
    g = np.minimum(g, signal.lfilter([0.002], [1.0, -0.998], g - 1.0) + 1.0)  # a slow recovery
    y = x * g
    return np.tanh(y / ceil) * ceil


def duck(n: int, times, depth: float, release_s: float, rate: int = RATE) -> np.ndarray:
    """The sidechain's pump: a gain that dips by `depth` at each of `times` and comes back over `release_s`."""
    if depth <= 0.0 or len(times) == 0:
        return np.ones(n)
    imp = np.zeros(n)
    for t in times:
        i = int(t * rate)
        if 0 <= i < n:
            imp[i] = 1.0
    k = int(release_s * 4 * rate)
    shape = np.exp(-np.arange(k) / max(release_s * rate, 1.0))
    shape[: int(0.004 * rate)] *= np.linspace(0.0, 1.0, int(0.004 * rate))  # no click on the way down
    env = np.minimum(signal.oaconvolve(imp, shape)[:n], 1.0)
    return 1.0 - depth * env
