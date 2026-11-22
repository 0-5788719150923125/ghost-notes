#!/usr/bin/env python3
"""A sound effect's PATCH made into sound, and what it sounds like as numbers (next/sound_effects.md).

    sound.py <spec.json>

The spec, never argv: {"patch", "seed", "out", "done"} - the patch, the seed its noise is drawn from, the WAV to write
and the JSON to write when finished: {"ok", "wav", "seconds", "heard"} or {"ok": false, "error"}.

A patch is {"secs", "tail", "gain", "room", "layers"}: `secs` what the voice waits for it, `tail` how long it is heard
after (so the sound is secs + tail long), `gain` dB (0 or less: the loudest sample at CEILING), `room` {seconds, damp,
mix} a reverb round all of it. Each layer is one source, shaped and placed, sounding over `at` ([start, end] seconds):

- `source`: noise (`color` white, pink or brown), sine, saw, pulse, triangle (on `pitch`, Hz), modal (`modes`
  [[Hz, seconds to -60 dB, level]], struck at each of `hits`), pluck (a string at `pitch` struck at each of `hits`,
  ringing `decay` seconds, `bright` 0-1), crackle (`rate` random clicks a second, each `decay` seconds);
- `level` 0-1, `filters` [{kind lowpass | highpass | bandpass, hz, q}] (a low-pass's `hz` may move; a high- or band-
  pass takes its curve's middle value), `drive` 0-1, `pan` -1 to 1, `gain` dB;
- `moving` {closest, near, speed}: the source flies past - nearest `closest` seconds into the sound, `near` meters off,
  at `speed` m/s - heard from where it is: its pitch Doppler-shifted at the speed of sound, louder as it nears, the
  far air darkening it, panned from where it is.

A CURVE is a number, a list of [seconds, value] points, or {"points": [...], "ease": linear | smooth | exp}: smooth
(the default) eases between points; exp moves by ratios (a pitch or a fade heard evenly). Before its first point a
curve holds that point's value, after its last the last's.

THE HEARD NUMBERS (`heard`), what the sound designer reads instead of listening: `frames` every FRAME seconds - its
loudness (dBFS), brightness (the spectral centroid, Hz) and pitch (Hz where it is a clear tone, else null); `peak_db`;
`loudest_at`; `onsets` (where the loudness jumps); `fade` (seconds from the last moment within 6 dB of the peak to 40 dB
under it, null if it never gets there - an abrupt end is a short fade or a sound still loud at its end); `end_db` (the
loudness of its last FRAME). A pure function of the patch and the seed.
"""

from __future__ import annotations

import json
import sys
import traceback
import wave
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import numpy as np  # noqa: E402

import dsp  # noqa: E402

# The rate a sound is made at: the desk's ([DispatchSounds.RATE]).
RATE = 22050
# The loudest a sound's loudest sample is written at (full scale) at gain 0.
CEILING = 0.89
# The longest a sound may be (seconds), and the most layers: a patch past these is refused.
LONGEST = 60.0
LAYERS_MOST = 12
# The speed of sound (m/s), as the desk's jet takes it.
SOUND_SPEED = 343.0
# The heard numbers' frame (s), the loudness a jump must make to be an onset (dB in a frame), and a tone's clarity.
FRAME = 0.1
ONSET_DB = 9.0
CLEAR = 0.6
SOURCES = ("noise", "sine", "saw", "pulse", "triangle", "modal", "pluck", "crackle")
FILTERS = ("lowpass", "highpass", "bandpass")


# --- curves -----------------------------------------------------------------------------------------

def curve(c, n: int, default: float, rate: int = RATE) -> np.ndarray:
    """Curve `c` (see the header) a sample each over n samples; `default` where it is missing."""
    if c is None:
        return np.full(n, float(default))
    if isinstance(c, (int, float)):
        return np.full(n, float(c))
    ease = "smooth"
    pts = c
    if isinstance(c, dict):
        ease = str(c.get("ease", "smooth"))
        pts = c.get("points", [])
    pts = sorted(([float(p[0]), float(p[1])] for p in pts if isinstance(p, (list, tuple)) and len(p) >= 2),
                 key=lambda p: p[0])
    if not pts:
        return np.full(n, float(default))
    t = np.arange(n) / rate
    xs = np.array([p[0] for p in pts])
    ys = np.array([p[1] for p in pts])
    if len(pts) == 1:
        return np.full(n, ys[0])
    i = np.clip(np.searchsorted(xs, t, side="right") - 1, 0, len(xs) - 2)
    span = np.maximum(xs[i + 1] - xs[i], 1e-9)
    u = np.clip((t - xs[i]) / span, 0.0, 1.0)
    a, b = ys[i], ys[i + 1]
    if ease == "linear":
        return a + (b - a) * u
    if ease == "exp":
        lo = 1e-5
        return np.exp(np.log(np.maximum(a, lo)) + (np.log(np.maximum(b, lo)) - np.log(np.maximum(a, lo))) * u)
    w = u * u * (3.0 - 2.0 * u)
    return a + (b - a) * w


def middle(c, default: float) -> float:
    """A curve's middle value: what a filter that cannot move is set to."""
    if c is None:
        return float(default)
    if isinstance(c, (int, float)):
        return float(c)
    pts = c.get("points", []) if isinstance(c, dict) else c
    vals = sorted(float(p[1]) for p in pts if isinstance(p, (list, tuple)) and len(p) >= 2)
    return vals[len(vals) // 2] if vals else float(default)


# --- sources ----------------------------------------------------------------------------------------

def source(layer: dict, n: int, rng: np.random.Generator) -> np.ndarray:
    """A layer's source alone, n samples from the sound's start (silent outside its `at`)."""
    kind = str(layer.get("source", "noise"))
    out = np.zeros(n)
    at = layer.get("at", [0.0, n / RATE])
    a = int(np.clip(float(at[0]) * RATE, 0, n))
    b = int(np.clip(float(at[1]) * RATE, a, n)) if len(at) > 1 else n
    m = b - a
    if m <= 0:
        return out
    if kind == "noise":
        color = str(layer.get("color", "white"))
        if color == "brown":
            w = np.cumsum(rng.standard_normal(m))
            w = dsp.butter(w - np.mean(w), "highpass", 20.0, 2, RATE)
            w /= np.std(w) + 1e-9
        else:
            w = dsp.noise(m, rng, "pink" if color == "pink" else "white")
            w /= np.std(w) + 1e-9
        out[a:b] = w * 0.3
    elif kind in ("sine", "saw", "pulse", "triangle"):
        f = curve(layer.get("pitch"), n, 220.0)[a:b]
        ph, dt = dsp.phase(f, m, RATE)
        out[a:b] = {"sine": dsp.sine, "saw": dsp.saw, "pulse": dsp.pulse, "triangle": dsp.triangle}[kind](ph, dt) * 0.5
    elif kind == "modal":
        modes = [md for md in layer.get("modes", []) if isinstance(md, (list, tuple)) and len(md) >= 3]
        for h in _hits(layer, a, b):
            seg = n - h
            out[h:] += dsp.modal(seg, [float(md[0]) for md in modes], [float(md[1]) for md in modes],
                                 [float(md[2]) for md in modes], RATE)
    elif kind == "pluck":
        f = middle(layer.get("pitch"), 220.0)
        for h in _hits(layer, a, b):
            out[h:] += dsp.karplus(n - h, f, float(layer.get("decay", 1.5)), float(layer.get("bright", 0.5)), rng, RATE) * 0.5
    elif kind == "crackle":
        rate_ = max(float(layer.get("rate", 20.0)), 0.0)
        count = rng.poisson(rate_ * m / RATE)
        ln = max(int(float(layer.get("decay", 0.004)) * RATE), 1)
        env = np.exp(-np.arange(ln) * 6.91 / ln)
        for at_ in rng.integers(a, b, size=count):
            e = min(at_ + ln, n)
            out[at_:e] += env[:e - at_] * rng.uniform(-1.0, 1.0) * rng.uniform(0.3, 1.0)
    return out


def _hits(layer: dict, a: int, b: int) -> list[int]:
    hits = layer.get("hits")
    if not isinstance(hits, list) or not hits:
        return [a]
    return [int(np.clip(float(h) * RATE, a, max(a, b - 1))) for h in hits if isinstance(h, (int, float))]


# --- a layer, shaped and placed ---------------------------------------------------------------------

def layer_sound(layer: dict, n: int, rng: np.random.Generator) -> np.ndarray:
    """One layer, [2, n]."""
    x = source(layer, n, rng)
    for f in layer.get("filters", []):
        if not isinstance(f, dict):
            continue
        kind = str(f.get("kind", "lowpass"))
        q = float(f.get("q", 0.707))
        if kind == "lowpass":
            hz = f.get("hz", 2000.0)
            x = dsp.lowpass(x, curve(hz, n, 2000.0) if not isinstance(hz, (int, float)) else float(hz), q, RATE)
        elif kind == "highpass":
            x = dsp.butter(x, "highpass", middle(f.get("hz"), 200.0), 2, RATE)
        elif kind == "bandpass":
            c = max(middle(f.get("hz"), 1000.0), 40.0)
            half = c / max(q, 0.1) / 2.0
            x = dsp.butter(x, "bandpass", [max(c - half, 20.0), min(c + half, RATE * 0.45)], 2, RATE)
    drive_ = float(layer.get("drive", 0.0))
    if drive_ > 0.0:
        x = dsp.drive(x / (np.abs(x).max() + 1e-9), drive_) * (np.abs(x).max() + 1e-9)
    pan_ = curve(layer.get("pan"), n, 0.0)
    moving = layer.get("moving")
    if isinstance(moving, dict):
        x, pan_ = fly(x, moving, pan_)
    x = x * np.clip(curve(layer.get("level"), n, 1.0), 0.0, 4.0) * 10.0 ** (float(layer.get("gain", 0.0)) / 20.0)
    ang = (np.clip(pan_, -1.0, 1.0) + 1.0) * np.pi / 4.0
    return np.stack([x * np.cos(ang), x * np.sin(ang)]) * np.sqrt(2.0)


def fly(x: np.ndarray, moving: dict, pan_: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Source x heard as it flies past (the header's `moving`): read at the moment each sample left it (so its pitch
    is Doppler-shifted), louder as it nears, darker as it is far, panned from where it is."""
    n = x.shape[0]
    closest = float(moving.get("closest", n / RATE / 2.0))
    near = max(float(moving.get("near", 200.0)), 1.0)
    speed = float(np.clip(float(moving.get("speed", 90.0)), 0.0, SOUND_SPEED * 0.9))
    u = np.arange(n) / RATE
    te = u.copy()
    for _ in range(5):
        xe = speed * (te - closest)
        te = u - np.sqrt(near * near + xe * xe) / SOUND_SPEED
    xe = speed * (te - closest)
    r = np.sqrt(near * near + xe * xe)
    heard = np.interp(te * RATE, np.arange(n), x, left=0.0, right=0.0)
    nearness = near / r
    dark = np.clip(nearness, 0.12, 1.0)
    heard = dsp.lowpass(heard, 400.0 + 7600.0 * dark, 0.707, RATE)
    side = np.clip(xe / (near * 2.0), -1.0, 1.0) * 0.6
    return heard * nearness, np.clip(pan_ + side, -1.0, 1.0)


# --- the whole sound --------------------------------------------------------------------------------

def check(patch: dict) -> str:
    """Why patch cannot be made, "" when it can."""
    if not isinstance(patch, dict):
        return "a patch is a JSON object"
    secs = float(patch.get("secs", 0.0)) + float(patch.get("tail", 0.0))
    if not 0.05 <= secs <= LONGEST:
        return f"secs + tail is {secs:.2f} s; a sound is 0.05 to {LONGEST:.0f} s"
    layers = patch.get("layers", [])
    if not isinstance(layers, list) or not layers:
        return "a patch needs at least one layer"
    if len(layers) > LAYERS_MOST:
        return f"{len(layers)} layers; at most {LAYERS_MOST}"
    for i, ly in enumerate(layers):
        if not isinstance(ly, dict):
            return f"layer {i} is not an object"
        if str(ly.get("source", "noise")) not in SOURCES:
            return f"layer {i}: source {ly.get('source')!r} is none of {', '.join(SOURCES)}"
        for f in ly.get("filters", []):
            if isinstance(f, dict) and str(f.get("kind", "lowpass")) not in FILTERS:
                return f"layer {i}: filter {f.get('kind')!r} is none of {', '.join(FILTERS)}"
    return ""


def render(patch: dict, seed: int) -> np.ndarray:
    """Patch as sound, [2, n] at RATE, its loudest sample at CEILING times its gain."""
    n = int(round((float(patch.get("secs", 0.0)) + float(patch.get("tail", 0.0))) * RATE))
    rng = np.random.default_rng(int(seed) & 0x7FFFFFFF)
    mix = np.zeros((2, n))
    for ly in patch["layers"]:
        mix += layer_sound(ly, n, np.random.default_rng(rng.integers(0, 2 ** 31)))
    room = patch.get("room")
    if isinstance(room, dict) and float(room.get("mix", 0.0)) > 0.0:
        ir = dsp.reverb_ir(float(room.get("seconds", 1.0)), np.random.default_rng(int(seed) + 7),
                           float(room.get("damp", 0.5)), 0.012, RATE)
        wet = dsp.convolve(mix, ir) * 0.25
        k = float(np.clip(room.get("mix", 0.0), 0.0, 1.0))
        mix = mix * (1.0 - k) + wet * k
    peak = float(np.abs(mix).max())
    if peak > 1e-9:
        mix *= CEILING * 10.0 ** (min(float(patch.get("gain", 0.0)), 0.0) / 20.0) / peak
    return mix


def heard(x: np.ndarray) -> dict:
    """What [2, n] sounds like as numbers (the header's THE HEARD NUMBERS)."""
    mono = x.mean(axis=0)
    hop = int(FRAME * RATE)
    frames = []
    loud = []
    for i in range(0, max(len(mono) - hop + 1, 1), hop):
        seg = mono[i:i + hop]
        rms = float(np.sqrt(np.mean(seg ** 2))) if seg.size else 0.0
        db = 20.0 * np.log10(max(rms, 1e-6))
        loud.append(db)
        spec = np.abs(np.fft.rfft(seg * np.hanning(seg.size))) if seg.size > 8 else np.zeros(1)
        freqs = np.fft.rfftfreq(seg.size, 1.0 / RATE) if seg.size > 8 else np.zeros(1)
        bright = float((spec * freqs).sum() / (spec.sum() + 1e-12)) if db > -70 else None
        frames.append({"t": round(i / RATE, 2), "db": round(db, 1),
                       "bright": round(bright) if bright is not None else None, "pitch": _pitch(seg) if db > -50 else None})
    loud_ = np.array(loud)
    top = float(loud_.max()) if loud_.size else -120.0
    onsets = [round(k * FRAME, 2) for k in range(1, len(loud_)) if loud_[k] - loud_[k - 1] >= ONSET_DB and loud_[k] > top - 40]
    if loud_.size and loud_[0] > top - 40:
        onsets.insert(0, 0.0)
    near_top = np.flatnonzero(loud_ >= top - 6.0)
    fade = None
    if near_top.size:
        last = int(near_top[-1])
        under = np.flatnonzero(loud_[last:] <= top - 40.0)
        fade = round(float(under[0]) * FRAME, 2) if under.size else None
    return {"seconds": round(len(mono) / RATE, 2), "peak_db": round(20.0 * np.log10(max(float(np.abs(x).max()), 1e-9)), 1),
            "loudest_at": round(float(np.argmax(loud_)) * FRAME, 2) if loud_.size else 0.0, "onsets": onsets[:24],
            "fade": fade, "end_db": round(float(loud_[-1]), 1) if loud_.size else -120.0, "frames": frames}


def _pitch(seg: np.ndarray):
    """A frame's pitch where it is a clear tone (normalized autocorrelation over CLEAR), else None."""
    if seg.size < 64:
        return None
    s = seg - seg.mean()
    ac = np.correlate(s, s, mode="full")[s.size - 1:]
    if ac[0] <= 1e-12:
        return None
    ac = ac / ac[0]
    lo, hi = int(RATE / 2000.0), min(int(RATE / 50.0), ac.size - 1)
    if hi <= lo:
        return None
    k = lo + int(np.argmax(ac[lo:hi]))
    return round(RATE / k, 1) if ac[k] >= CLEAR else None


def write_wav(path: str, x: np.ndarray) -> None:
    pcm = (np.clip(x.T, -1.0, 1.0) * 32767.0).astype("<i2")
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: sound.py <spec.json>", file=sys.stderr)
        return 2
    spec = json.loads(Path(argv[1]).read_text())
    done = str(spec.get("done", ""))
    try:
        patch = spec.get("patch", {})
        why = check(patch)
        if why:
            raise ValueError(why)
        x = render(patch, int(spec.get("seed", 0)))
        write_wav(str(spec["out"]), x)
        result = {"ok": True, "wav": str(spec["out"]), "seconds": round(x.shape[1] / RATE, 3), "heard": heard(x)}
    except Exception as exc:  # the app shows why
        traceback.print_exc()
        result = {"ok": False, "error": str(exc)}
    if done:
        Path(done).write_text(json.dumps(result))
    else:
        print(json.dumps(result))
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
