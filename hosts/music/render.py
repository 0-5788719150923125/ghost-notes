#!/usr/bin/env python3
"""A composed Sound's score made into sound: each part a stem, the sung takes laid in, and the mix (next/music.md,
"Rendering").

    render.py <spec.json>

The spec is the score as the composer resolved it (src/music/composer.gd hands it over, SongBake writes it) - never
argv:

    {"out", "mix", "length", "seed", "beat",
     "parts": [{"key", "instrument": {"method", ...}, "notes": [{t, len, midi | hit, vel}], "level", "pan", "fx", "mute"}],
     "vocals": [{"key", "level", "pan", "fx", "takes": [{"wav", "at"}], "vocoder", "notes": [{t, len, midi}]}],
     "duck": {"hits": [seconds], "depth", "release", "parts": [key]},
     "master": {"reverb": {"seconds", "damp", "predelay"}, "gain", "loudness", "ceiling"}}

Times are seconds; `level` and `gain` are dB; a part's `fx` may hold `reverb` (its send, 0-1), `delay` ({beats,
feedback, mix}), `chorus`, `drive`, `highpass`, `lowpass` (Hz) and `compress` ({threshold, ratio}).

A part's stem is made in a worker process of its own (several side by side) and kept in `<out>/stems/` under a hash of
what made it (its instrument, notes, effects and the seed), so a
part not changed is read back rather than made again (a stem no part names is removed); its level, pan, mute and reverb
send are the mix's, laid on once the stem is brought to one loudness while it plays (PLAYING), so a part's level is its
place in the mix whatever its instrument's own loudness. The mix is
`<out>/<mix>`, 16-bit PCM at 44.1 kHz, every part through one room (a reverb's impulse response, convolved), brought
to one loudness (LOUDNESS) and limited. A sung take is a file the voice host made; it is resampled to the mix's rate
and laid at its `at`; with a `vocoder` amount, the voice is heard through a vocoder playing the line's own `notes` (the
carrier sounds the score's pitch exactly, the voice gives it its words).

Writes `<out>/done.json`: {"ok", "mix", "stems": {key: path}, "seconds", "peak_db"} or {"ok": false, "error"}.
Progress is printed a line at a time (the log the app shows).
"""

from __future__ import annotations

import hashlib
import json
import os
import sys
import time
import traceback
import zlib
from concurrent.futures import ProcessPoolExecutor
from math import gcd
from pathlib import Path

import numpy as np
from scipy import signal
from scipy.io import wavfile

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import dsp  # noqa: E402
import instruments  # noqa: E402
from dsp import RATE  # noqa: E402

# Raised when a stem made from the same spec would come out different: every kept stem is made again.
STEMS = 1
# What a part's stem does not depend on: the mix sets them.
MIX_FIELDS = ("level", "pan", "mute")
# Seconds before its beat a vocoder's note begins, for the consonants sung before the beat.
CARRIER_LEAD = 0.07
# Every stem is brought to this loudness while it plays (dBFS, its playing frames' RMS) before its level is laid on:
# a part's level is its place in the mix, whatever its instrument's own loudness (a driven kit, a sung take).
PLAYING = -18.0
# A frame plays while it is within this many dB of the stem's loudest.
PLAYING_RANGE = 40.0
# The mix's loudness while it plays (dBFS RMS) before the limiter; a master's `loudness` says otherwise.
LOUDNESS = -15.0


def say(msg: str) -> None:
    print(msg, flush=True)


def rng_of(seed: int, key: str) -> np.random.Generator:
    return np.random.default_rng([int(seed) & 0xFFFFFFFF, zlib.crc32(key.encode("utf-8"))])


def stem_hash(part: dict, seed: int, beat: float) -> str:
    made = {k: v for k, v in part.items() if k not in MIX_FIELDS}
    fx = dict(made.get("fx", {}) or {})
    fx.pop("reverb", None)
    made["fx"] = fx
    blob = json.dumps({"part": made, "seed": seed, "beat": beat, "v": STEMS}, sort_keys=True)
    return hashlib.sha1(blob.encode("utf-8")).hexdigest()[:16]


def read_wav(path: str) -> np.ndarray:
    """A WAV as [channels, n] floats at RATE."""
    sr, data = wavfile.read(path)
    x = data.astype(np.float64)
    if data.dtype == np.int16:
        x /= 32768.0
    elif data.dtype == np.int32:
        x /= 2147483648.0
    x = x.reshape(len(x), -1).T
    if sr != RATE:
        g = gcd(int(sr), RATE)
        x = signal.resample_poly(x, RATE // g, int(sr) // g, axis=-1)
    return x


_LENGTHS: dict = {}


def wav_seconds(path: str) -> float:
    """A WAV's length from its header (kept, per path), 0 for one not there: the voice's takes are 16-bit, read without
    their samples."""
    if path not in _LENGTHS:
        import wave
        try:
            with wave.open(path) as w:
                _LENGTHS[path] = w.getnframes() / float(w.getframerate())
        except (OSError, EOFError, wave.Error):
            return 0.0
    return _LENGTHS[path]


def write_float(path: Path, x: np.ndarray) -> None:
    tmp = path.with_name(path.name + ".part")
    wavfile.write(str(tmp), RATE, x.T.astype(np.float32))
    tmp.replace(path)


def write_pcm16(path: Path, x: np.ndarray, rng) -> None:
    tpdf = (rng.uniform(-0.5, 0.5, x.shape) + rng.uniform(-0.5, 0.5, x.shape)) / 32768.0
    pcm = np.clip(np.round((x + tpdf) * 32767.0), -32768, 32767).astype(np.int16)
    tmp = path.with_name(path.name + ".part")
    wavfile.write(str(tmp), RATE, pcm.T)
    tmp.replace(path)


def effects(x: np.ndarray, fx: dict, beat: float, rng) -> np.ndarray:
    """A stem's own effects, [2, n] in and out (its reverb is the mix's send)."""
    if float(fx.get("highpass", 0.0)) > 0.0:
        x = dsp.butter(x, "highpass", float(fx["highpass"]))
    if float(fx.get("lowpass", 0.0)) > 0.0:
        x = dsp.butter(x, "lowpass", float(fx["lowpass"]))
    if float(fx.get("drive", 0.0)) > 0.0:
        x = dsp.drive(x, float(fx["drive"]))
    comp = fx.get("compress")
    if isinstance(comp, dict):
        x = dsp.compress(x, float(comp.get("threshold", -18.0)), float(comp.get("ratio", 3.0)))
    if float(fx.get("chorus", 0.0)) > 0.0:
        x = dsp.chorus(x, 3.0, 0.7, float(fx["chorus"]))
    dl = fx.get("delay")
    if isinstance(dl, dict) and float(dl.get("mix", 0.0)) > 0.0:
        x = x + float(dl["mix"]) * dsp.echo(x, float(dl.get("beats", 0.75)) * beat, float(dl.get("feedback", 0.35)))
    return x


def playing_gain(x: np.ndarray) -> float:
    """The gain that brings [2, n] to PLAYING while it plays (its frames within PLAYING_RANGE of its loudest)."""
    w = int(0.05 * RATE)
    m = x.shape[-1] // w
    if m == 0:
        return 1.0
    frames = np.sqrt(np.mean(x[:, :m * w].reshape(2, m, w) ** 2, axis=(0, 2)))
    top = float(frames.max())
    if top <= 1e-7:
        return 1.0
    on = frames[frames > top * 10.0 ** (-PLAYING_RANGE / 20.0)]
    level = float(np.sqrt(np.mean(on ** 2)))
    return 10.0 ** (PLAYING / 20.0) / max(level, 1e-7)


def stem_path(part: dict, seed: int, beat: float, stems: Path) -> Path:
    return stems / f"{part['key']}-{stem_hash(part, seed, beat)}.wav"


def make_stem(part: dict, n: int, seed: int, beat: float, stems: Path) -> str:
    """A part's stem made and kept (what a worker process does): its path."""
    path = stem_path(part, seed, beat, stems)
    say(f"making {part['key']}")
    rng = rng_of(seed, str(part["key"]))
    x = instruments.render(part, n, rng)
    x = effects(x, part.get("fx", {}) or {}, beat, rng)
    write_float(path, x)
    return str(path)


def make_stems(parts: list, n: int, seed: int, beat: float, stems: Path) -> None:
    """Every part's stem not kept yet, made side by side in worker processes (half the machine's cores, so the app beside
    it keeps the rest); one alone is made here."""
    todo = []
    for part in parts:
        path = stem_path(part, seed, beat, stems)
        if not path.exists() or read_wav_frames(path) < n:
            todo.append(part)
    workers = max(1, min(len(todo), (os.cpu_count() or 2) // 2))
    if workers <= 1:
        for part in todo:
            make_stem(part, n, seed, beat, stems)
        return
    with ProcessPoolExecutor(max_workers=workers) as pool:
        for got in [pool.submit(make_stem, part, n, seed, beat, stems) for part in todo]:
            got.result()


def read_wav_frames(path: Path) -> int:
    """How many frames a kept stem holds, from its header alone (float32 stereo at RATE, written by write_float)."""
    try:
        return max((path.stat().st_size - 44) // 8, 0)
    except OSError:
        return 0


def vocal_stem(voc: dict, n: int, beat: float, seed: int) -> np.ndarray:
    x = np.zeros((2, n))
    for take in voc.get("takes", []):
        w = read_wav(str(take["wav"]))
        mono = w.mean(axis=0)
        at = int(float(take.get("at", 0.0)) * RATE)
        s0, e = max(0, -at), min(len(mono), n - at)
        if e > s0:
            x[:, at + s0:at + e] += mono[s0:e]
    amount = float(voc.get("vocoder", 0.0))
    if amount > 0.0 and voc.get("notes"):
        say("the vocoder")
        x = vocoded(x, voc["notes"], amount, rng_of(seed, "vocoder"))
    fx = {"highpass": 90.0, "compress": {"threshold": -20.0, "ratio": 3.0}, **(voc.get("fx", {}) or {})}
    return effects(x, fx, beat, rng_of(seed, str(voc.get("key", "vocal"))))


def carrier(notes: list, n: int, rng) -> np.ndarray:
    """What a vocoder plays: the sung line's own notes, two saws a little apart and a square an octave down, each note
    begun a little before its beat (the consonant sung before it needs something to sound through) and gliding into the
    next where they touch."""
    out = np.zeros(n)
    ordered = sorted(notes, key=lambda nt: float(nt["t"]))
    for i, nt in enumerate(ordered):
        t0 = max(float(nt["t"]) - CARRIER_LEAD, 0.0)
        t1 = float(nt["t"]) + float(nt["len"])
        nxt = ordered[i + 1] if i + 1 < len(ordered) else None
        joined = nxt is not None and float(nxt["t"]) - t1 < 0.06
        end = float(nxt["t"]) - CARRIER_LEAD if joined else t1 + 0.06
        a, m = int(t0 * RATE), max(int((end - t0) * RATE), 1)
        if a >= n:
            continue
        m = min(m, n - a)
        midi = np.full(m, float(nt["midi"]))
        if i and float(ordered[i - 1]["t"]) + float(ordered[i - 1]["len"]) > t0 - 0.06:
            g = min(m, int(0.03 * RATE))
            midi[:g] = float(ordered[i - 1]["midi"]) + (midi[:g] - float(ordered[i - 1]["midi"])) * np.linspace(0.0, 1.0, g)
        hz = dsp.midi_hz(midi)
        tone = np.zeros(m)
        for cents in (-7.0, 7.0):
            ph, dt = dsp.phase(hz * 2.0 ** (cents / 1200.0), m, start=rng.uniform(0, 1))
            tone += dsp.saw(ph, dt)
        ph, dt = dsp.phase(hz / 2.0, m)
        tone += 0.5 * dsp.pulse(ph, dt)
        env = np.ones(m)
        k = min(m, int(0.006 * RATE))
        env[:k] = np.linspace(0.0, 1.0, k)
        if not joined:
            r = min(m, int(0.05 * RATE))
            env[m - r:] *= np.linspace(1.0, 0.0, r)
        out[a:a + m] += tone * env
    return out


def vocoded(x: np.ndarray, notes: list, amount: float, rng) -> np.ndarray:
    """The sung voice [2, n] through a vocoder playing its own notes, at `amount` (0 the voice, 1 the vocoder alone),
    the vocoder's level the voice's."""
    voice = x.mean(axis=0)
    robot = dsp.vocoder(voice, carrier(notes, x.shape[-1], rng))
    robot *= np.sqrt(np.mean(voice ** 2) / (np.mean(robot ** 2) + 1e-12))
    mixed = (1.0 - amount) * voice + amount * robot
    return np.stack([mixed, mixed])


def render(spec: dict) -> dict:
    out = Path(spec["out"])
    stems = out / "stems"
    stems.mkdir(parents=True, exist_ok=True)
    n = int(float(spec["length"]) * RATE)
    seed = int(spec.get("seed", 0))
    beat = float(spec.get("beat", 0.5))
    mix = np.zeros((2, n))
    send = np.zeros((2, n))
    made: dict = {}
    duck = spec.get("duck") or {}
    gain_of = dsp.duck(n, duck.get("hits", []), float(duck.get("depth", 0.0)), float(duck.get("release", 0.15)))
    make_stems(spec.get("parts", []), n, seed, beat, stems)
    for part in spec.get("parts", []):
        path = stem_path(part, seed, beat, stems)
        x = read_wav(str(path))[:, :n]
        made[str(part["key"])] = str(path)
        if part.get("mute"):
            continue
        x = dsp.pan(x.mean(axis=0), float(part["pan"])) * 0.5 + x * 0.5 if float(part.get("pan", 0.0)) else x
        x = x * playing_gain(x) * 10.0 ** (float(part.get("level", 0.0)) / 20.0)
        if str(part["key"]) in duck.get("parts", []):
            x = x * gain_of
        mix += x
        send += x * float((part.get("fx") or {}).get("reverb", 0.0))
    for voc in spec.get("vocals", []):
        if voc.get("mute"):
            continue
        # kept under a hash of its takes, notes, vocoder and effects, as a part's stem is
        took = {k: v for k, v in voc.items() if k not in MIX_FIELDS}
        took["takes"] = [{"wav": t["wav"], "at": t["at"], "size": Path(t["wav"]).stat().st_size if Path(t["wav"]).exists() else 0}
                         for t in voc.get("takes", [])]
        h = hashlib.sha1(json.dumps({"voice": took, "v": STEMS}, sort_keys=True).encode("utf-8")).hexdigest()[:16]
        path = stems / f"{voc.get('key', 'vocal')}-{h}.wav"
        x = read_wav(str(path))[:, :n] if path.exists() else None
        if x is None or x.shape[-1] < n:
            say(f"laying in {voc.get('key', 'vocal')}")
            x = vocal_stem(voc, n, beat, seed)
            write_float(path, x)
        x = x * playing_gain(x) * 10.0 ** (float(voc.get("level", 0.0)) / 20.0)
        made[str(voc.get("key", "vocal"))] = str(path)
        mix += x
        send += x * float((voc.get("fx") or {}).get("reverb", 0.15))
    master = spec.get("master", {}) or {}
    rv = master.get("reverb", {}) or {}
    if np.any(send):
        say("the room")
        ir = dsp.reverb_ir(float(rv.get("seconds", 2.0)), rng_of(seed, "room"), float(rv.get("damp", 0.5)),
                           float(rv.get("predelay", 0.015)))
        mix += dsp.convolve(send, ir) * 0.5
    mix *= 10.0 ** (float(master.get("gain", 0.0)) / 20.0)
    mix = dsp.butter(mix, "highpass", 25.0)
    # the whole brought to one loudness while it plays, then limited: every song as loud as the next
    mix *= playing_gain(mix) * 10.0 ** ((float(master.get("loudness", LOUDNESS)) - PLAYING) / 20.0)
    mix = dsp.limit(mix, float(master.get("ceiling", -1.0)))
    peak = float(np.max(np.abs(mix))) if n else 0.0
    # stems no part names any more go: a part rolled leaves its last stem behind otherwise, every roll
    kept = {Path(p).name for p in made.values()}
    for f in stems.glob("*.wav"):
        if f.name not in kept:
            f.unlink(missing_ok=True)
    path = out / str(spec.get("mix", "mix.wav"))
    write_pcm16(path, mix, rng_of(seed, "dither"))
    return {"ok": True, "mix": str(path), "stems": made, "seconds": n / RATE,
            "peak_db": 20.0 * np.log10(max(peak, 1e-9))}


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    spec_path = Path(argv[1])
    spec = json.loads(spec_path.read_text(encoding="utf-8"))
    out = Path(spec["out"])
    out.mkdir(parents=True, exist_ok=True)
    began = time.time()
    try:
        done = render(spec)
        done["took"] = round(time.time() - began, 2)
        say("done in %.1f s" % done["took"])
    except Exception as exc:  # noqa: BLE001 - the app reads the reason
        traceback.print_exc()
        done = {"ok": False, "error": f"{type(exc).__name__}: {exc}"}
    (out / "done.json").write_text(json.dumps(done), encoding="utf-8")
    return 0 if done.get("ok") else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
