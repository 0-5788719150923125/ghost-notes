"""listen.py - a song read for what it is made of, by classic signal processing (next/music.md, "Importing a song"):
its beat grid, key, chords, sections, drum pattern, bass line and sung melody. No model and nothing kept of its sound
but numbers.

The pieces, each a function of arrays:

- `spectrogram`: the short-time spectrum, magnitudes;
- `hpss`: harmonic and percussive apart by median filtering (Fitzgerald 2010): a held tone is a horizontal line in a
  spectrogram and a hit a vertical one, so a median along each axis keeps one and loses the other;
- `onset_envelope`: how much new sound arrives each frame (half-wave rectified flux over log bands);
- `tempo` and `beats`: the onset envelope's autocorrelation weighed toward a tactus near 110 BPM, then Ellis's (2007)
  dynamic program for the beats, then one straight grid through them when the song keeps time (most do, a drum
  machine's exactly);
- `chroma`: the harmonic part folded into twelve pitch classes; `bass_chroma` the bass note's, by harmonic summation;
- `key`: Krumhansl and Kessler's profiles against the whole song's chroma;
- `chords`: each beat's chroma against triad and seventh templates, smoothed by a Viterbi pass that prefers to stay;
- `sections`: bars compared with each other (chroma and timbre), cut where the music changes (a checkerboard kernel
  along the self-similarity's diagonal, Foote 2000), and like stretches given one letter;
- `drums`: the percussive part's low, middle and high bands, each a step a sixteenth, averaged over a section's bars;
- `foreground`: what does not repeat - each bar against its most alike bars' median (REPET-SIM's idea, Rafii and Pardo
  2012, on the beat grid), the singer kept from the band that loops under them, the middle of the stereo field first;
- `pitch_track`: YIN's cumulative mean normalized difference (de Cheveigné and Kawahara 2002) on the foreground, its
  candidates joined by a Viterbi pass that dislikes leaps (pYIN's idea, Mauch and Dixon 2014);
- `notes_of`: a pitch track as notes on the beat grid, each sixteenth's median pitch, joined where it holds;
- `salience` and `voice_profile`: the sung line's pitch by harmonic summation, read a sixteenth at a time from the bars
  that sing the same line over the same chord averaged together, its octave folded into the song's register, and where
  each step's syllables can begin - what the composer lays a line's own syllables on.

Arrays are float64; times are seconds; a frame is HOP samples at RATE.
"""

from __future__ import annotations

import numpy as np
from scipy import ndimage, signal

RATE = 22050
N_FFT = 2048
HOP = 512
NAMES = ("C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B")
# Krumhansl and Kessler's key profiles (C major, C minor).
MAJOR = np.array([6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88])
MINOR = np.array([6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17])
# The chord shapes listened for, as intervals over the root.
QUALITIES = {"": (0, 4, 7), "m": (0, 3, 7), "7": (0, 4, 7, 10), "maj7": (0, 4, 7, 11), "m7": (0, 3, 7, 10),
             "sus4": (0, 5, 7), "sus2": (0, 2, 7), "5": (0, 7)}
# A beat's chord stays rather than changes this much more likely (the Viterbi's self-transition).
CHORD_STAY = 0.92
# How much the bass note holding a chord's root counts toward that chord (against a template's cosine, 0-1).
BASS_ROOT = 0.35
# Two sung bars over one chord are one line sung again when their pitch profiles are this alike (cosine).
GROUP_ALIKE = 0.8
# A step is sung where its strongest pitch class stands this far over the step's median salience (in deviations).
VOICED_SALIENCE = 1.6
# Semitones either side of the song's sung middle a pitch is folded into.
REGISTER = 7.0
# The tactus a tempo is weighed toward, and how widely (octaves).
TACTUS = 110.0
TACTUS_WIDTH = 0.9


def frames_to_s(i) -> np.ndarray:
    return np.asarray(i, dtype=float) * HOP / RATE


def stft(x: np.ndarray, n_fft: int = N_FFT, hop: int = HOP) -> np.ndarray:
    """The STFT [bins, frames] of a mono signal, Hann-windowed, centered."""
    pad = np.pad(x, n_fft // 2, mode="reflect")
    win = np.hanning(n_fft)
    count = 1 + (len(pad) - n_fft) // hop
    out = np.empty((n_fft // 2 + 1, count), dtype=np.complex128)
    for s in range(0, count, 4096):  # in pieces: a whole song's frames at once is gigabytes
        e = min(s + 4096, count)
        idx = np.arange(n_fft)[None, :] + hop * np.arange(s, e)[:, None]
        out[:, s:e] = np.fft.rfft(pad[idx] * win, axis=1).T
    return out


def istft(Z: np.ndarray, length: int, hop: int = HOP) -> np.ndarray:
    """The signal back from an STFT `stft` made, by weighted overlap-add."""
    n_fft = (Z.shape[0] - 1) * 2
    win = np.hanning(n_fft)
    frames = np.fft.irfft(Z.T, n=n_fft, axis=1) * win
    out = np.zeros(length + n_fft)
    norm = np.zeros(length + n_fft)
    for i, fr in enumerate(frames):
        a = i * hop
        if a >= len(out):
            break
        e = min(a + n_fft, len(out))
        out[a:e] += fr[:e - a]
        norm[a:e] += win[:e - a] ** 2
    out = out / np.maximum(norm, 1e-6)
    return out[n_fft // 2:n_fft // 2 + length]


def spectrogram(x: np.ndarray, n_fft: int = N_FFT, hop: int = HOP) -> np.ndarray:
    """|STFT| [bins, frames]."""
    return np.abs(stft(x, n_fft, hop))


def bin_hz(n_fft: int = N_FFT) -> np.ndarray:
    return np.arange(n_fft // 2 + 1) * RATE / n_fft


def hpss(S: np.ndarray, width: int = 17) -> tuple[np.ndarray, np.ndarray]:
    """(harmonic, percussive) magnitudes by soft masks from the two medians."""
    h = ndimage.median_filter(S, size=(1, width))
    p = ndimage.median_filter(S, size=(width, 1))
    mh = h ** 2 / (h ** 2 + p ** 2 + 1e-12)
    return S * mh, S * (1.0 - mh)


def log_bands(S: np.ndarray, lo: float = 30.0, hi: float = 11000.0, count: int = 64) -> np.ndarray:
    """S folded into `count` log-spaced bands [count, frames]."""
    f = bin_hz((S.shape[0] - 1) * 2)
    edges = np.geomspace(lo, hi, count + 1)
    which = np.digitize(f, edges) - 1
    out = np.zeros((count, S.shape[1]))
    for b in range(count):
        m = which == b
        if m.any():
            out[b] = S[m].sum(axis=0)
    return out


def onset_envelope(S: np.ndarray) -> np.ndarray:
    """New sound a frame: the rise of log band energy, summed, its slow trend taken off."""
    L = np.log1p(100.0 * log_bands(S))
    flux = np.maximum(np.diff(L, axis=1, prepend=L[:, :1]), 0.0).sum(axis=0)
    flux -= ndimage.uniform_filter1d(flux, 32)
    return np.maximum(flux, 0.0)


def tempo(env: np.ndarray, lo_bpm: float = 60.0, hi_bpm: float = 200.0) -> float:
    """The beat's tempo in BPM: the autocorrelation peak, weighed toward TACTUS, refined between lags."""
    fps = RATE / HOP
    e = env - env.mean()
    ac = signal.fftconvolve(e, e[::-1], mode="full")[len(e) - 1:]
    lags = np.arange(len(ac))
    lo, hi = int(fps * 60.0 / hi_bpm), int(fps * 60.0 / lo_bpm)
    bpm = 60.0 * fps / np.maximum(lags, 1)
    weight = np.exp(-0.5 * (np.log2(bpm / TACTUS) / TACTUS_WIDTH) ** 2)
    score = ac * weight
    k = lo + int(np.argmax(score[lo:hi]))
    lag = float(k)
    if 1 <= k < len(ac) - 1:  # a parabola through the peak, for a lag between frames
        a, b, c = score[k - 1], score[k], score[k + 1]
        den = a - 2.0 * b + c
        if den < 0.0:
            lag = k + float(np.clip(0.5 * (a - c) / den, -0.5, 0.5))
    return 60.0 * fps / lag


def beats(env: np.ndarray, bpm: float, tightness: float = 100.0) -> np.ndarray:
    """Beat frames by Ellis's dynamic program: each frame's best predecessor about a period back."""
    fps = RATE / HOP
    period = 60.0 * fps / bpm
    e = env / (env.std() + 1e-9)
    score = e.copy()
    back = np.full(len(e), -1)
    reach = np.arange(-int(2 * period), -int(period / 2))
    cost = -tightness * np.log(-reach / period) ** 2
    for i in range(len(e)):
        j = i + reach
        ok = j >= 0
        if not ok.any():
            continue
        cand = score[j[ok]] + cost[ok]
        k = int(np.argmax(cand))
        score[i] = e[i] + cand[k]
        back[i] = j[ok][k]
    # the last beat is the best-scoring frame in the final period
    tail = len(e) - int(period)
    i = tail + int(np.argmax(score[tail:])) if tail > 0 else int(np.argmax(score))
    out = []
    while i >= 0:
        out.append(i)
        i = back[i]
    return np.array(out[::-1])


def straight_grid(beat_frames: np.ndarray, length_s: float) -> tuple[np.ndarray, float, float]:
    """(beat times, the beat's length, how far the beats stray from it) for one straight line through the beats - a
    song that keeps time has its grid exactly. The line is fitted on the beats' middle, trimmed of strays."""
    t = frames_to_s(beat_frames)
    n = np.arange(len(t))
    for _ in range(3):
        a, b = np.polyfit(n, t, 1)
        res = t - (a * n + b)
        keep = np.abs(res) < max(3.0 * np.median(np.abs(res)), 0.01)
        n, t = n[keep], t[keep]
    a, b = np.polyfit(n, t, 1)
    stray = float(np.median(np.abs(t - (a * n + b))))
    # the first beat may fall a hair before the song's start (the fit's own scatter): it is the start
    first = b - a * np.round(b / a)
    if first < -0.25 * a:
        first += a
    grid = np.arange(max(first, 0.0), length_s, a)
    return grid, float(a), stray


def chroma(S: np.ndarray, lo: float = 55.0, hi: float = 2000.0) -> np.ndarray:
    """[12, frames]: each bin's energy given to its nearest pitch class, log-compressed and normalized."""
    f = bin_hz((S.shape[0] - 1) * 2)
    m = (f >= lo) & (f <= hi)
    pc = np.mod(np.round(12.0 * np.log2(f[m] / 440.0)) + 9, 12).astype(int)
    C = np.zeros((12, S.shape[1]))
    E = np.log1p(10.0 * S[m])
    for k in range(12):
        C[k] = E[pc == k].sum(axis=0)
    return C / (np.linalg.norm(C, axis=0, keepdims=True) + 1e-9)


def sync(X: np.ndarray, edges: np.ndarray, how=np.mean) -> np.ndarray:
    """X's frames gathered between consecutive `edges` (frame indices): [rows, len(edges) - 1]."""
    out = np.zeros((X.shape[0], max(len(edges) - 1, 0)))
    for k in range(len(edges) - 1):
        a, b = int(edges[k]), max(int(edges[k + 1]), int(edges[k]) + 1)
        out[:, k] = how(X[:, a:min(b, X.shape[1])], axis=1) if a < X.shape[1] else 0.0
    return out


def key(C: np.ndarray) -> dict:
    """{"tonic": 0-11, "mode": "major"|"minor", "name", "confidence"} from a song's chroma."""
    c = C.mean(axis=1)
    best = []
    for r in range(12):
        best.append((float(np.corrcoef(c, np.roll(MAJOR, r))[0, 1]), r, "major"))
        best.append((float(np.corrcoef(c, np.roll(MINOR, r))[0, 1]), r, "minor"))
    best.sort(reverse=True)
    s, r, mode = best[0]
    return {"tonic": r, "mode": mode, "name": NAMES[r] + (" minor" if mode == "minor" else " major"),
            "confidence": round(s - best[1][0], 3)}


def chord_templates() -> tuple[np.ndarray, list]:
    T, L = [], []
    for r in range(12):
        for q, iv in QUALITIES.items():
            v = np.zeros(12)
            for k, i in enumerate(iv):
                v[(r + i) % 12] = 1.0 if k < 3 else 0.7
            T.append(v / np.linalg.norm(v))
            L.append((r, q))
    return np.array(T), L


def chords(Cb: np.ndarray, bass: np.ndarray | None = None) -> list:
    """Each beat's chord [(root, quality)] from beat chroma `Cb` [12, beats], smoothed by Viterbi. The low band's
    chroma `bass` [12, beats] leans hard toward a chord whose root it holds (a bass note is a chord's root far more
    often than not), so a chord sharing most of its notes with its neighbor (C and Am7, Dm7 and F6) is told apart by
    what is under it."""
    T, L = chord_templates()
    sim = T @ (Cb / (np.linalg.norm(Cb, axis=0, keepdims=True) + 1e-9))
    if bass is not None:
        bn = bass / (bass.max(axis=0, keepdims=True) + 1e-9)
        sim += BASS_ROOT * np.array([bn[r] for r, _q in L]) ** 2
    # sevenths and suspensions must earn their place over a plain triad
    prior = np.array([0.0 if q in ("", "m") else -0.035 for _r, q in L])[:, None]
    lik = np.exp(14.0 * (sim + prior))
    lik /= lik.sum(axis=0, keepdims=True)
    n = len(L)
    stay, move = np.log(CHORD_STAY), np.log((1.0 - CHORD_STAY) / (n - 1))
    D = np.log(lik[:, 0] + 1e-12)
    back = np.zeros((Cb.shape[1], n), dtype=int)
    for t in range(1, Cb.shape[1]):
        best_other = np.max(D) + move
        arg_other = int(np.argmax(D))
        stay_v = D + stay
        take = stay_v >= best_other
        back[t] = np.where(take, np.arange(n), arg_other)
        D = np.where(take, stay_v, best_other) + np.log(lik[:, t] + 1e-12)
    path = [int(np.argmax(D))]
    for t in range(Cb.shape[1] - 1, 0, -1):
        path.append(int(back[t][path[-1]]))
    return [L[i] for i in path[::-1]]


def bass_chroma(S: np.ndarray, lo: float = 28.0, hi: float = 52.0, harmonics: int = 6) -> np.ndarray:
    """[12, frames]: how much each pitch class is the bass note, by harmonic summation over a fine spectrum `S` (8192
    points or more) - each candidate from MIDI `lo` to `hi` scored by its first harmonics' log magnitudes, so a bass's
    root wins over its own strong fifth (its third harmonic) and a kick's tail, one bare sine, scores little."""
    n_fft = (S.shape[0] - 1) * 2
    L_ = np.log1p(1000.0 * S / (S.max() + 1e-9))
    out = np.zeros((12, S.shape[1]))
    for m in range(int(lo), int(hi) + 1):
        f0 = 440.0 * 2.0 ** ((m - 69) / 12.0)
        sal = np.zeros(S.shape[1])
        for h in range(1, harmonics + 1):
            b = f0 * h * n_fft / RATE
            i = int(b)
            if i + 1 >= S.shape[0]:
                break
            fr = b - i
            sal += 0.85 ** (h - 1) * ((1.0 - fr) * L_[i] + fr * L_[i + 1])
        out[m % 12] = np.maximum(out[m % 12], sal)
    out -= out.min(axis=0, keepdims=True)
    return out / (np.linalg.norm(out, axis=0, keepdims=True) + 1e-9)


def key_by_chords(C: np.ndarray, beat_chords: list) -> dict:
    """The key, its relative major or minor chosen by which of their tonic chords the song plays more (C major and A
    minor share every note; a song that sits on C is in C)."""
    k = key(C)
    rel = (k["tonic"] + (3 if k["mode"] == "minor" else 9)) % 12
    other = "major" if k["mode"] == "minor" else "minor"
    def tonic_beats(root: int, mode: str) -> int:
        return sum(1 for r, q in beat_chords if r == root and (q.startswith("m") and not q.startswith("maj")) == (mode == "minor"))
    if tonic_beats(rel, other) > tonic_beats(k["tonic"], k["mode"]):
        k = {"tonic": rel, "mode": other, "name": NAMES[rel] + (" minor" if other == "minor" else " major"),
             "confidence": k["confidence"]}
    return k


def checkerboard(n: int) -> np.ndarray:
    a = np.sign(np.arange(-n, n) + 0.5)
    g = signal.windows.gaussian(2 * n, n / 2.0)
    return np.outer(a, a) * np.outer(g, g)


def sections(F: np.ndarray, size: int = 4, least: int = 4) -> tuple[list, list]:
    """Where the music changes, and a letter for each stretch: `F` [features, bars]. (bounds in bars, letters)."""
    X = F / (np.linalg.norm(F, axis=0, keepdims=True) + 1e-9)
    SSM = X.T @ X
    K = checkerboard(size)
    n = SSM.shape[0]
    pad = np.pad(SSM, size, mode="edge")
    nov = np.array([np.sum(pad[i:i + 2 * size, i:i + 2 * size] * K) for i in range(n)])
    nov = np.maximum(nov, 0.0)
    peaks, _ = signal.find_peaks(nov, distance=least, height=np.percentile(nov, 60))
    bounds = [0] + [int(p) for p in peaks if 0 < p < n] + [n]
    bounds = sorted(set(bounds))
    # like stretches share a letter: each stretch's mean feature, joined greedily by similarity
    means = [X[:, a:b].mean(axis=1) for a, b in zip(bounds[:-1], bounds[1:])]
    letters: list = []
    seen: list = []
    for m in means:
        m = m / (np.linalg.norm(m) + 1e-9)
        best, at = -1.0, -1
        for k, s in enumerate(seen):
            c = float(m @ s)
            if c > best:
                best, at = c, k
        if best > 0.93:
            letters.append(chr(ord("A") + at))
        else:
            seen.append(m)
            letters.append(chr(ord("A") + len(seen) - 1))
    return bounds, letters


def drums(P: np.ndarray, grid_frames: np.ndarray) -> dict:
    """Each band's strength at each grid step: {"kick", "snare", "hat"} -> [steps], from the percussive spectrogram."""
    f = bin_hz((P.shape[0] - 1) * 2)
    bands = {"kick": (35.0, 120.0), "snare": (180.0, 3500.0), "hat": (6000.0, 11000.0)}
    out = {}
    for name, (lo, hi) in bands.items():
        e = np.log1p(50.0 * P[(f >= lo) & (f < hi)].sum(axis=0))
        rise = np.maximum(np.diff(e, prepend=e[:1]), 0.0)
        rise = rise / (np.percentile(rise, 99) + 1e-9)
        vals = []
        for g in grid_frames:
            g = int(g)
            vals.append(float(rise[max(g - 1, 0):g + 2].max()) if g < len(rise) else 0.0)
        out[name] = np.clip(np.array(vals), 0.0, 1.5)
    return out


def foreground(S_mid: np.ndarray, S_side: np.ndarray, bar_edges: np.ndarray, near: int = 6) -> np.ndarray:
    """The singer's share of the middle channel's spectrogram (a soft mask [bins, frames]): each bar against the
    median of its `near` most alike bars - what repeats under the voice - and what the sides hold too taken off."""
    bins = S_mid.shape[0]
    count = len(bar_edges) - 1
    width = int(np.median(np.diff(bar_edges)))
    stack = np.zeros((count, bins, width))
    for b in range(count):
        a = int(bar_edges[b])
        seg = S_mid[:, a:a + width]
        stack[b, :, :seg.shape[1]] = seg
    flat = np.log1p(stack.reshape(count, -1))
    flat = flat / (np.linalg.norm(flat, axis=1, keepdims=True) + 1e-9)
    sim = flat @ flat.T
    mask = np.zeros_like(S_mid)
    for b in range(count):
        order = np.argsort(-sim[b])
        alike = [k for k in order if k != b][:near]
        bg = np.median(stack[alike], axis=0)
        a = int(bar_edges[b])
        seg = S_mid[:, a:a + width]
        w = seg.shape[1]
        bgw = np.minimum(bg[:, :w], seg)
        side = S_side[:, a:a + w]
        fg = np.maximum(seg - bgw - 0.5 * side, 0.0)
        mask[:, a:a + w] = fg ** 2 / (fg ** 2 + bgw ** 2 + 1e-12)
    return mask


def yin_candidates(x: np.ndarray, fmin: float, fmax: float, frame: int = 2048, hop: int = 256,
                   threshold: float = 0.2) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Per frame: (best period's f0 in Hz or 0, its aperiodicity 0-1 (low is clean), the frame's level)."""
    lo, hi = int(RATE / fmax), min(int(RATE / fmin), frame // 2)
    count = 1 + (len(x) - frame) // hop
    idx = np.arange(frame)[None, :] + hop * np.arange(count)[:, None]
    X = x[idx]
    level = np.sqrt(np.mean(X ** 2, axis=1))
    w = frame // 2
    # the difference function d(tau) = r(0) + r_tau(0) - 2 r(tau), from FFT autocorrelations
    Fx = np.fft.rfft(X, n=2 * frame, axis=1)
    ac = np.fft.irfft(Fx * np.conj(np.fft.rfft(X[:, :w], n=2 * frame, axis=1)), axis=1)[:, :w]
    cs = np.cumsum(X ** 2, axis=1)
    e0 = cs[:, w - 1][:, None]
    taus = np.arange(w)
    et = np.stack([cs[:, t + w - 1] - (cs[:, t - 1] if t else 0.0) for t in taus], axis=1)
    d = e0 + et - 2.0 * ac
    d[:, 0] = 0.0
    cmnd = d * taus / np.maximum(np.cumsum(d, axis=1), 1e-12)
    cmnd[:, 0] = 1.0
    f0 = np.zeros(count)
    ap = np.ones(count)
    for i in range(count):
        c = cmnd[i, lo:hi]
        below = np.flatnonzero(c < threshold)
        if below.size:
            k = below[0]
            while k + 1 < len(c) and c[k + 1] < c[k]:
                k += 1
        else:
            k = int(np.argmin(c))
        t = lo + k
        if 1 <= t < w - 1:  # parabolic refinement
            a, b, cc = cmnd[i, t - 1], cmnd[i, t], cmnd[i, t + 1]
            den = a - 2 * b + cc
            t = t + 0.5 * (a - cc) / den if den > 0 else t
        f0[i] = RATE / t
        ap[i] = float(c[min(k, len(c) - 1)])
    return f0, ap, level


def pitch_track(f0: np.ndarray, ap: np.ndarray, level: np.ndarray, leap: float = 0.35) -> np.ndarray:
    """A sung line from YIN's frames: MIDI a frame (0 unsung). Voiced where clean and loud enough; the octave a
    frame sits in chosen by a Viterbi pass that charges `leap` a semitone for a jump (YIN's octave slips undone)."""
    loud = level > max(np.percentile(level, 30), 1e-4)
    voiced = (ap < 0.35) & loud & (f0 > 0)
    midi = np.where(f0 > 0, 69.0 + 12.0 * np.log2(np.maximum(f0, 1e-9) / 440.0), 0.0)
    out = np.zeros_like(midi)
    # each voiced run's octave: candidates the frame's pitch an octave down, as is, an octave up
    i = 0
    n = len(midi)
    while i < n:
        if not voiced[i]:
            i += 1
            continue
        j = i
        while j < n and voiced[j]:
            j += 1
        run = midi[i:j]
        cands = np.stack([run - 12.0, run, run + 12.0])
        cost = np.array([0.6, 0.0, 0.6])[:, None] + ap[i:j][None, :]
        D = cost[:, 0].copy()
        back = np.zeros((3, j - i), dtype=int)
        for t in range(1, j - i):
            jump = leap * np.abs(cands[:, t][:, None] - cands[:, t - 1][None, :])
            tot = D[None, :] + jump
            back[:, t] = np.argmin(tot, axis=1)
            D = tot[np.arange(3), back[:, t]] + cost[:, t]
        k = int(np.argmin(D))
        for t in range(j - i - 1, -1, -1):
            out[i + t] = cands[k, t]
            k = back[k, t]
        i = j
    # a voiced run shorter than 60 ms is a blip
    runs = np.flatnonzero(np.diff(np.concatenate([[0], (out > 0).astype(int), [0]])))
    for a, b in zip(runs[::2], runs[1::2]):
        if (b - a) * 256 / RATE < 0.06:
            out[a:b] = 0.0
    return out


def notes_of(track: np.ndarray, track_hop: int, grid: np.ndarray, scale: list | None = None,
             least_voiced: float = 0.5) -> list:
    """A pitch track as notes on the grid (step times in seconds): each step's median pitch where at least
    `least_voiced` of it is sung, snapped to `scale` (pitch classes) where it is within a third of a semitone of one,
    steps of one pitch joined. [{t, len, midi}]."""
    t_of = np.arange(len(track)) * track_hop / RATE
    steps = []
    for a, b in zip(grid[:-1], grid[1:]):
        m = (t_of >= a) & (t_of < b)
        seg = track[m]
        if seg.size == 0 or np.mean(seg > 0) < least_voiced:
            steps.append(None)
            continue
        p = float(np.median(seg[seg > 0]))
        r = round(p)
        if scale is not None and (r % 12) not in scale:
            near = min((abs(p - (r + d)), r + d) for d in (-1, 1) if (r + d) % 12 in scale)
            if near[0] < 0.85:
                r = near[1]
        steps.append(int(r))
    notes = []
    for k, s in enumerate(steps):
        if s is None:
            continue
        if notes and notes[-1]["midi"] == s and notes[-1]["end_step"] == k:
            notes[-1]["end_step"] = k + 1
        else:
            notes.append({"midi": s, "step": k, "end_step": k + 1})
    return [{"t": float(grid[n["step"]]), "len": float(grid[n["end_step"]] - grid[n["step"]]), "midi": n["midi"],
             "step": n["step"]} for n in notes]


def salience(x: np.ndarray, lo: float = 45.0, hi: float = 84.0, res: float = 0.1, n_fft: int = 4096,
             hop: int = 256) -> tuple[np.ndarray, np.ndarray]:
    """Harmonic-sum pitch salience [candidates, frames] of a (mostly sung) signal, and the candidates' MIDI pitches
    (`res` semitones apart): each candidate's first ten harmonics' log magnitudes summed, each 0.8 of the one before."""
    V = np.abs(stft(x, n_fft, hop))
    Vl = np.log1p(3000.0 * V / (V.max() + 1e-9))
    cands = np.arange(lo, hi, res)
    hz = 440.0 * 2.0 ** ((cands - 69.0) / 12.0)
    sal = np.zeros((len(cands), V.shape[1]))
    for h in range(1, 11):
        fb = hz * h / (RATE / n_fft)
        ok = fb < V.shape[0] - 2
        lo_b = np.floor(fb[ok]).astype(int)
        fr = fb[ok] - lo_b
        sal[ok] += 0.8 ** (h - 1) * ((1.0 - fr)[:, None] * Vl[lo_b] + fr[:, None] * Vl[lo_b + 1])
    return sal, cands


def voice_profile(sal: np.ndarray, cands: np.ndarray, onset: np.ndarray, step_t: np.ndarray, bars: int,
                  sung: np.ndarray, bar_chord: list, hop: int = 256, steps: int = 16) -> dict:
    """A sung bar's tune as its sixteenths: {bar: {"pitch": [MIDI or 0 a step], "onset": [0-1 a step], "group"}}.

    REPETITION IS THE DENOISER: bars sung over the same chord with alike pitch profiles are one group (the same line of
    a verse in its stanzas, a chorus's line sung again), and each step's pitch is read from the group's salience
    averaged - what the band does differently under each repeat cancels and the tune stays. The octave is the one
    nearest the song's sung register (YIN's and salience's octave slips undone). The onsets are each bar's own and its
    group's, averaged: where a syllable can begin."""
    fps = RATE / hop
    S = np.zeros((bars, steps, len(cands)))
    O = np.zeros((bars, steps))
    for b in range(bars):
        for k in range(steps):
            i = b * steps + k
            a, e = int(step_t[i] * fps), max(int(step_t[i + 1] * fps), int(step_t[i] * fps) + 1)
            if a >= sal.shape[1]:
                continue
            col = sal[:, a:min(e, sal.shape[1])].mean(axis=1)
            S[b, k] = (col - np.median(col)) / (col.std() + 1e-9)
            O[b, k] = float(onset[a:min(e, len(onset))].max()) if a < len(onset) else 0.0
    sung_bars = [b for b in range(bars) if sung[b] > 0.2]
    if not sung_bars:
        return {}
    semis = np.round(cands).astype(int)

    def pc_profile(M: np.ndarray) -> np.ndarray:
        P = np.zeros((steps, 12))
        for c in range(12):
            P[:, c] = np.maximum(M[:, (semis % 12) == c], 0.0).max(axis=1)
        v = P.ravel()
        return v / (np.linalg.norm(v) + 1e-9)

    groups: list = []  # [{chord, members, mean profile}]
    member_of = {}
    for b in sung_bars:
        prof = pc_profile(S[b])
        best, at = -1.0, -1
        for gi, g in enumerate(groups):
            if g["chord"] != bar_chord[b]:
                continue
            c = float(prof @ g["profile"])
            if c > best:
                best, at = c, gi
        if best >= GROUP_ALIKE:
            g = groups[at]
            g["members"].append(b)
            g["sum"] += prof
            g["profile"] = g["sum"] / (np.linalg.norm(g["sum"]) + 1e-9)
            member_of[b] = at
        else:
            groups.append({"chord": bar_chord[b], "members": [b], "sum": prof.copy(), "profile": prof})
            member_of[b] = len(groups) - 1
    # the song's sung register: the median of every sung step's strongest pitch
    peaks = cands[np.argmax(S[sung_bars].reshape(-1, len(cands)), axis=1)]
    strong = S[sung_bars].reshape(-1, len(cands)).max(axis=1) > VOICED_SALIENCE
    middle = float(np.median(peaks[strong])) if strong.any() else 60.0
    window = (cands >= middle - REGISTER) & (cands <= middle + REGISTER)
    out = {}
    for gi, g in enumerate(groups):
        mean = S[g["members"]].mean(axis=0)
        onset_g = O[g["members"]].mean(axis=0)
        for b in g["members"]:
            # each bar its own salience and its group's, half each: what repeats steadies it, what is its own stays
            mix = 0.5 * S[b] + 0.5 * mean if len(g["members"]) > 1 else S[b]
            pitch = []
            for k in range(steps):
                folded = np.zeros(12)
                for c in range(12):
                    folded[c] = mix[k][(semis % 12) == c].max()
                pc = int(np.argmax(folded))
                if float(folded[pc]) < VOICED_SALIENCE:
                    pitch.append(0)
                    continue
                # the pitch class's place nearest the register's middle
                m = int(round(middle)) + ((pc - int(round(middle))) % 12)
                if m - middle > 6:
                    m -= 12
                pitch.append(int(m))
            on = 0.5 * O[b] + 0.5 * onset_g
            on = on / (on.max() + 1e-9)
            out[b] = {"pitch": pitch, "onset": [round(float(v), 3) for v in on], "group": gi}
    return out
