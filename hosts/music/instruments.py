"""instruments.py - how each kind of instrument is made, by its `method` (next/music.md, "The instruments").

An instrument is a row of numbers the composer resolves from the Instruments registry (src/music/instruments.gd): its
`method` and that method's settings. A part is that instrument and its notes, each `{t, len, midi, vel}` in seconds
(a drum's note names its `hit` instead of a pitch). `render(part, n, rng)` is the part's sound, [2, n].

The methods:

- `kit` - drums from first principles, the 808's and 909's recipes: a kick is a sine falling fast in pitch with a click,
  a snare two tones and a band of noise, a clap noise bursts a few milliseconds apart, a hat six square waves at
  unrelated pitches through a high band-pass, a tom a pitched fall, a cymbal noise and metal held longer.
- `subtractive` - detuned oscillators through a resonant low-pass with its own envelope: pads, leads, basses, strings.
- `fm` - a sine moving another sine's phase (Chowning's FM): electric pianos, bells, basses.
- `pluck` - Karplus-Strong strings: guitar, harp, a picked bass; with drive and a speaker's tone, an electric guitar.
- `modal` - struck things, as decaying modes: bells, marimba, glass.
- `organ` - drawbars, a sine a harmonic.
- `vox` - a buzz through a vowel's formants: a wordless choir.

A note's sound runs past its length by its release, and each part's notes are summed where they fall.
"""

from __future__ import annotations

import numpy as np

import dsp
from dsp import RATE

# 808 hat oscillators (Hz), the metallic cluster.
HAT_TONES = (205.3, 304.4, 369.6, 522.7, 540.0, 800.0)
# A vowel's first three formants (Hz) and their bandwidths, a male voice's.
VOWELS = {
    "a": ((730.0, 1090.0, 2440.0), (90.0, 110.0, 160.0)),
    "o": ((570.0, 840.0, 2410.0), (80.0, 100.0, 150.0)),
    "u": ((300.0, 870.0, 2240.0), (60.0, 90.0, 150.0)),
    "e": ((530.0, 1840.0, 2480.0), (70.0, 110.0, 160.0)),
    "i": ((270.0, 2290.0, 3010.0), (60.0, 120.0, 180.0)),
}


def _p(params: dict, key: str, default):
    v = params.get(key, default)
    return type(default)(v) if isinstance(default, (int, float)) and not isinstance(default, bool) else v


def _place(buf: np.ndarray, at: int, sound: np.ndarray) -> None:
    """`sound` summed into `buf` from sample `at`, cut at either end."""
    n = buf.shape[-1]
    if at >= n or at + sound.shape[-1] <= 0:
        return
    s0 = max(0, -at)
    e = min(sound.shape[-1], n - at)
    buf[..., at + s0:at + e] += sound[..., s0:e]


# --- drums ------------------------------------------------------------------------------------------

def _kick(p: dict, vel: float, rng) -> np.ndarray:
    n = int(_p(p, "decay", 0.45) * 4 * RATE)
    t = dsp.seconds(n)
    lo, hi = _p(p, "pitch", 50.0), _p(p, "pitch", 50.0) * 2.0 ** _p(p, "sweep", 2.0)
    freq = lo + (hi - lo) * np.exp(-t / _p(p, "sweep_time", 0.035))
    ph, _ = dsp.phase(freq, n)
    body = np.sin(2 * np.pi * ph) * dsp.decay(n, _p(p, "decay", 0.45))
    click = dsp.butter(dsp.noise(n, rng), "bandpass", (1500.0, 7000.0)) * dsp.decay(n, 0.003)
    out = body + _p(p, "click", 0.3) * click
    return dsp.drive(out * (0.6 + 0.4 * vel), _p(p, "drive", 0.25))


def _snare(p: dict, vel: float, rng) -> np.ndarray:
    n = int(_p(p, "decay", 0.18) * 5 * RATE)
    t = dsp.seconds(n)
    tone = _p(p, "tone", 185.0)
    body = (np.sin(2 * np.pi * tone * t) + 0.6 * np.sin(2 * np.pi * tone * 1.78 * t)) * dsp.decay(n, _p(p, "body", 0.05))
    hiss = dsp.butter(dsp.noise(n, rng), "bandpass", (_p(p, "low", 1200.0), _p(p, "high", 8000.0)))
    hiss = hiss * dsp.decay(n, _p(p, "decay", 0.18))
    out = _p(p, "tone_mix", 0.5) * body + _p(p, "snap", 1.0) * hiss * 0.7
    return dsp.drive(out * vel, _p(p, "drive", 0.1))


def _hat(p: dict, vel: float, rng, open_: bool) -> np.ndarray:
    tau = _p(p, "open", 0.28) if open_ else _p(p, "decay", 0.04)
    n = int(tau * 6 * RATE)
    t = dsp.seconds(n)
    metal = np.zeros(n)
    tune = _p(p, "tune", 1.0)
    for f in HAT_TONES:
        metal += np.sign(np.sin(2 * np.pi * f * tune * 1.7 * t + rng.uniform(0, 6.28)))
    metal = metal / len(HAT_TONES) * _p(p, "metal", 0.6) + dsp.noise(n, rng) * (1.0 - _p(p, "metal", 0.6)) * 0.5
    out = dsp.butter(metal, "bandpass", (6500.0, 15000.0), 2) * dsp.decay(n, tau)
    return dsp.butter(out, "highpass", 5000.0) * vel * 1.6


def _clap(p: dict, vel: float, rng) -> np.ndarray:
    n = int(0.6 * RATE)
    burst = np.zeros(n)
    w = dsp.noise(n, rng)
    for k in range(4):
        at = int(k * _p(p, "spread", 0.011) * RATE)
        env = np.zeros(n)
        env[at:] = dsp.decay(n - at, 0.006 if k < 3 else _p(p, "decay", 0.16))
        burst += w * env
    return dsp.butter(burst, "bandpass", (_p(p, "tone", 1100.0), _p(p, "tone", 1100.0) * 3.5)) * vel * 1.3


def _tom(p: dict, vel: float, rng, pitch: float) -> np.ndarray:
    n = int(_p(p, "decay", 0.3) * 4 * RATE)
    t = dsp.seconds(n)
    freq = pitch * (1.0 + 0.5 * np.exp(-t / 0.04))
    ph, _ = dsp.phase(freq, n)
    out = np.sin(2 * np.pi * ph) * dsp.decay(n, _p(p, "decay", 0.3))
    out += 0.15 * dsp.butter(dsp.noise(n, rng), "bandpass", (pitch * 2, pitch * 8)) * dsp.decay(n, 0.02)
    return dsp.drive(out * vel, 0.2)


def _cymbal(p: dict, vel: float, rng, tau: float, bright: float) -> np.ndarray:
    n = int(tau * 4 * RATE)
    t = dsp.seconds(n)
    metal = np.zeros(n)
    for f in HAT_TONES:
        metal += np.sign(np.sin(2 * np.pi * f * 2.3 * t + rng.uniform(0, 6.28)))
    out = 0.4 * metal / len(HAT_TONES) + 0.6 * dsp.noise(n, rng)
    out = dsp.butter(out, "highpass", 3000.0 + 3000.0 * bright) * dsp.decay(n, tau, attack=0.002)
    return out * vel * 0.9


def _rim(p: dict, vel: float, rng) -> np.ndarray:
    n = int(0.12 * RATE)
    out = dsp.modal(n, (1700.0, 2400.0, 3500.0), (0.04, 0.03, 0.02), (1.0, 0.6, 0.3))
    return out * vel * 0.6


def _shaker(p: dict, vel: float, rng) -> np.ndarray:
    n = int(0.12 * RATE)
    env = np.clip(dsp.seconds(n) / 0.02, 0, 1) * dsp.decay(n, 0.03, attack=0.02)
    return dsp.butter(dsp.noise(n, rng), "highpass", 6000.0) * env * vel * 0.5


# Each hit: (its sound, where it stands left to right, its level).
def _hit(name: str, params: dict, vel: float, rng) -> tuple[np.ndarray, float]:
    p = params.get(name, {}) if isinstance(params.get(name), dict) else {}
    if name == "kick":
        return _kick(p, vel, rng), 0.0
    if name == "snare":
        return _snare(p, vel, rng), 0.05
    if name == "ghost":  # the soft stroke between the backbeats the app is named for
        return _snare(params.get("snare", {}), vel * 0.3, rng), 0.05
    if name == "hat":
        return _hat(params.get("hat", {}), vel, rng, False), 0.3
    if name == "open_hat":
        return _hat(params.get("hat", {}), vel, rng, True), 0.3
    if name == "clap":
        return _clap(p, vel, rng), -0.05
    if name in ("tom_hi", "tom_mid", "tom_lo"):
        base = {"tom_hi": 220.0, "tom_mid": 160.0, "tom_lo": 110.0}[name]
        return _tom(params.get("tom", {}), vel, rng, base * float(params.get("tom", {}).get("tune", 1.0))), \
            {"tom_hi": -0.3, "tom_mid": 0.1, "tom_lo": 0.4}[name]
    if name == "crash":
        return _cymbal(p, vel, rng, float(p.get("decay", 1.4)), 0.5), -0.4
    if name == "ride":
        return _cymbal(p, vel, rng, float(p.get("decay", 0.9)), 1.0), 0.45
    if name == "rim":
        return _rim(p, vel, rng), 0.1
    if name == "shaker":
        return _shaker(p, vel, rng), 0.5
    return np.zeros(1), 0.0


def kit(part: dict, n: int, rng) -> np.ndarray:
    params = part.get("instrument", {})
    out = np.zeros((2, n))
    for note in part.get("notes", []):
        sound, where = _hit(str(note.get("hit", "kick")), params, float(note.get("vel", 0.9)), rng)
        lvl = float((params.get(str(note.get("hit")), {}) or {}).get("level", 1.0)) if isinstance(params.get(str(note.get("hit"))), dict) else 1.0
        _place(out, int(float(note["t"]) * RATE), dsp.pan(sound * lvl, where * float(params.get("width", 1.0))))
    return out


# --- pitched ----------------------------------------------------------------------------------------

def _pitch_curve(note: dict, n: int, params: dict, prev_midi) -> np.ndarray:
    """A note's pitch in Hz a sample: its own, glided to from the note before where the part glides, with vibrato
    once it has held a while."""
    midi = float(note["midi"])
    curve = np.full(n, midi)
    glide = float(params.get("glide", 0.0))
    if glide > 0.0 and prev_midi is not None:
        k = min(n, int(glide * RATE))
        curve[:k] = midi + (prev_midi - midi) * np.exp(-np.arange(k) / max(glide * RATE / 4.0, 1.0))
    vib = float(params.get("vibrato", 0.0))  # semitones deep
    if vib > 0.0:
        t = dsp.seconds(n)
        wait = float(params.get("vibrato_delay", 0.25))
        ramp = np.clip((t - wait) / 0.25, 0.0, 1.0)
        curve = curve + vib * ramp * np.sin(2 * np.pi * float(params.get("vibrato_rate", 5.5)) * t)
    return dsp.midi_hz(curve)


def _sounding(note: dict, release: float) -> tuple[int, int, float]:
    at = int(float(note["t"]) * RATE)
    gate = max(float(note.get("len", 0.25)), 0.01)
    return at, int((gate + release) * RATE), gate


def subtractive(part: dict, n: int, rng) -> np.ndarray:
    p = part.get("instrument", {})
    amp = p.get("amp", {"a": 0.005, "d": 0.3, "s": 0.7, "r": 0.2})
    fenv = p.get("fenv", {"a": 0.005, "d": 0.4, "s": 0.3, "r": 0.3})
    waves = p.get("waves", [{"wave": "saw", "level": 1.0, "detune": 0.0, "octave": 0}])
    voices = max(int(p.get("unison", 1)), 1)
    spread = float(p.get("spread", 12.0))  # cents across the unison
    width = float(p.get("width", 0.6))
    cutoff = float(p.get("cutoff", 1200.0))
    env_oct = float(p.get("env", 2.0))
    key = float(p.get("key", 0.5))
    res = float(p.get("res", 0.8))
    poles = int(p.get("poles", 2))
    out = np.zeros((2, n))
    prev = None
    for note in part.get("notes", []):
        at, m, gate = _sounding(note, float(amp.get("r", 0.2)) * 1.5)
        vel = float(note.get("vel", 0.8))
        hz = _pitch_curve(note, m, p, prev if p.get("glide") else None)
        prev = float(note["midi"])
        sig = np.zeros((2, m))
        for v in range(voices):
            off = 0.0 if voices == 1 else (v / (voices - 1) - 0.5) * spread
            pos = 0.0 if voices == 1 else (v / (voices - 1) - 0.5) * 2.0 * width
            mono = np.zeros(m)
            for w in waves:
                f = hz * 2.0 ** (float(w.get("octave", 0)) + (float(w.get("detune", 0.0)) + off) / 1200.0)
                ph, dt = dsp.phase(f, m, start=rng.uniform(0, 1))
                fn = dsp.WAVES.get(str(w.get("wave", "saw")), dsp.saw)
                mono += float(w.get("level", 1.0)) * (fn(ph, dt, float(w.get("width", 0.5))) if fn is dsp.pulse else fn(ph, dt))
            sig += dsp.pan(mono / np.sqrt(voices), pos)
        if float(p.get("sub", 0.0)) > 0.0:
            ph, dt = dsp.phase(hz / 2.0, m)
            sig += dsp.pan(float(p["sub"]) * dsp.sine(ph), 0.0)
        if float(p.get("noise", 0.0)) > 0.0:
            sig += dsp.pan(float(p["noise"]) * dsp.noise(m, rng, "pink") * 0.3, 0.0)
        fe = dsp.adsr(m, gate, float(fenv["a"]), float(fenv["d"]), float(fenv["s"]), float(fenv["r"]))
        track = (float(hz[0]) / 261.6) ** key
        cut = np.clip(cutoff * track * 2.0 ** (env_oct * fe * (0.5 + 0.5 * vel)), 30.0, RATE * 0.45)
        sig = np.stack([dsp.lowpass(sig[c], cut, res, poles=poles) for c in range(2)])
        env = dsp.adsr(m, gate, float(amp["a"]), float(amp["d"]), float(amp["s"]), float(amp["r"]))
        _place(out, at, sig * env * vel)
    return dsp.drive(out * 0.35, float(p.get("drive", 0.0)))


def fm(part: dict, n: int, rng) -> np.ndarray:
    p = part.get("instrument", {})
    amp = p.get("amp", {"a": 0.002, "d": 1.2, "s": 0.0, "r": 0.4})
    ratio = float(p.get("ratio", 1.0))
    index = float(p.get("index", 2.0))
    index_decay = float(p.get("index_decay", 0.6))
    tine = float(p.get("tine", 0.0))  # the struck bar's bright partial
    out = np.zeros(n)
    for note in part.get("notes", []):
        at, m, gate = _sounding(note, float(amp.get("r", 0.4)) * 1.5)
        vel = float(note.get("vel", 0.8))
        hz = _pitch_curve(note, m, p, None)
        t = dsp.seconds(m)
        cph, _ = dsp.phase(hz, m)
        mph, _ = dsp.phase(hz * ratio, m)
        idx = index * (0.4 + 0.6 * vel) * (0.25 + 0.75 * np.exp(-t / max(index_decay, 1e-3)))
        tone = np.sin(2 * np.pi * cph + idx * np.sin(2 * np.pi * mph))
        if tine > 0.0:
            tph, _ = dsp.phase(hz * float(p.get("tine_ratio", 14.0)), m)
            tone += tine * np.sin(2 * np.pi * tph) * np.exp(-t / 0.08)
        env = dsp.adsr(m, gate, float(amp["a"]), float(amp["d"]), float(amp["s"]), float(amp["r"]))
        _place(out, at, tone * env * vel)
    stereo = dsp.pan(out * 0.4, 0.0)
    if float(p.get("tremolo", 0.0)) > 0.0:  # a suitcase piano's pan
        t = dsp.seconds(n)
        lfo = float(p["tremolo"]) * np.sin(2 * np.pi * float(p.get("tremolo_rate", 4.0)) * t)
        stereo = np.stack([stereo[0] * (1 - lfo), stereo[1] * (1 + lfo)])
    return dsp.drive(stereo, float(p.get("drive", 0.0)))


def pluck(part: dict, n: int, rng) -> np.ndarray:
    p = part.get("instrument", {})
    decay_s = float(p.get("decay", 2.0))
    bright = float(p.get("bright", 0.5))
    pick = float(p.get("pick", 0.12))
    damp = float(p.get("damp", 0.0))  # a palm on the strings: each note stopped at its length
    out = np.zeros(n)
    for note in part.get("notes", []):
        at = int(float(note["t"]) * RATE)
        gate = float(note.get("len", 0.5))
        hold = gate if damp > 0.0 else decay_s * 1.2
        m = int((hold + 0.08) * RATE)
        vel = float(note.get("vel", 0.8))
        s = dsp.karplus(m, float(dsp.midi_hz(float(note["midi"]))), decay_s * (1.0 - 0.8 * damp), bright * (0.6 + 0.4 * vel), rng,
                        pick=pick)
        if damp > 0.0 or gate < decay_s:
            stop = int(gate * RATE)
            if stop < m:
                s[stop:] *= np.exp(-np.arange(m - stop) / (0.02 * RATE))
        _place(out, at, s * vel)
    body = dsp.butter(out, "lowpass", float(p.get("tone", 5000.0)), 2)
    if float(p.get("drive", 0.0)) > 0.0:  # an amp and its speaker: drive, the low end tightened, the fizz rolled off
        body = dsp.drive(dsp.butter(body, "highpass", 90.0) * 2.5, float(p["drive"]))
        body = dsp.butter(body, "lowpass", float(p.get("cab", 4200.0)), 4)
    stereo = dsp.pan(body * 0.5, float(p.get("pan", 0.0)))
    return stereo


def modal_part(part: dict, n: int, rng) -> np.ndarray:
    p = part.get("instrument", {})
    ratios = p.get("ratios", [1.0, 2.0, 2.76, 5.4, 8.93])
    decays = p.get("decays", [2.5, 1.6, 1.0, 0.5, 0.3])
    amps = p.get("amps", [1.0, 0.5, 0.35, 0.2, 0.1])
    length = float(p.get("length", 1.0))
    out = np.zeros(n)
    for note in part.get("notes", []):
        at = int(float(note["t"]) * RATE)
        f0 = float(dsp.midi_hz(float(note["midi"])))
        m = int(max(decays) * length * 1.3 * RATE)
        vel = float(note.get("vel", 0.8))
        s = dsp.modal(m, [f0 * r for r in ratios], [d * length for d in decays], [a * (vel ** (k * 0.3)) for k, a in enumerate(amps)])
        strike = dsp.butter(dsp.noise(int(0.004 * RATE), rng), "highpass", 2000.0) * float(p.get("hardness", 0.2))
        s[:len(strike)] += strike
        _place(out, at, s * vel)
    return dsp.pan(out * 0.3, 0.0)


def organ(part: dict, n: int, rng) -> np.ndarray:
    p = part.get("instrument", {})
    bars = p.get("drawbars", [0.8, 0.6, 1.0, 0.0, 0.4, 0.0, 0.0, 0.0, 0.2])
    harmonics = [0.5, 1.5, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 8.0]
    amp = p.get("amp", {"a": 0.01, "d": 0.1, "s": 1.0, "r": 0.08})
    out = np.zeros(n)
    for note in part.get("notes", []):
        at, m, gate = _sounding(note, float(amp["r"]) * 1.5)
        hz = _pitch_curve(note, m, p, None)
        tone = np.zeros(m)
        for h, lvl in zip(harmonics, bars):
            if lvl > 0.0:
                ph, _ = dsp.phase(hz * h, m)
                tone += float(lvl) * dsp.sine(ph)
        click = dsp.butter(dsp.noise(int(0.003 * RATE), rng), "highpass", 1500.0) * float(p.get("click", 0.15))
        tone[:len(click)] += click
        env = dsp.adsr(m, gate, float(amp["a"]), float(amp["d"]), float(amp["s"]), float(amp["r"]))
        _place(out, at, tone * env * float(note.get("vel", 0.8)))
    stereo = dsp.pan(out * 0.18, 0.0)
    return dsp.chorus(stereo, 2.0, float(p.get("leslie", 5.8)), float(p.get("leslie_mix", 0.4)))


def vox(part: dict, n: int, rng) -> np.ndarray:
    p = part.get("instrument", {})
    amp = p.get("amp", {"a": 0.4, "d": 0.5, "s": 0.85, "r": 0.8})
    vowel = VOWELS.get(str(p.get("vowel", "a")), VOWELS["a"])
    out = np.zeros(n)
    for note in part.get("notes", []):
        at, m, gate = _sounding(note, float(amp["r"]) * 1.5)
        hz = _pitch_curve(note, m, {**p, "vibrato": float(p.get("vibrato", 0.15))}, None)
        ph, dt = dsp.phase(hz, m, start=rng.uniform(0, 1))
        buzz = dsp.saw(ph, dt) + 0.1 * dsp.noise(m, rng)
        sung = np.zeros(m)
        for (f, bw), gain in zip(zip(*vowel), (1.0, 0.7, 0.35)):
            sung += gain * dsp.butter(buzz, "bandpass", (max(f - bw, 50.0), f + bw), 2)
        env = dsp.adsr(m, gate, float(amp["a"]), float(amp["d"]), float(amp["s"]), float(amp["r"]))
        _place(out, at, sung * env * float(note.get("vel", 0.8)))
    return dsp.chorus(dsp.pan(out * 0.8, 0.0), 6.0, 0.4, 0.7)


METHODS = {"kit": kit, "subtractive": subtractive, "fm": fm, "pluck": pluck, "modal": modal_part, "organ": organ,
           "vox": vox}


def render(part: dict, n: int, rng) -> np.ndarray:
    """A part's sound, [2, n]: its instrument's method over its notes."""
    method = str(part.get("instrument", {}).get("method", "subtractive"))
    if method not in METHODS:
        raise ValueError(f"no instrument is made by '{method}'")
    return METHODS[method](part, n, rng)
