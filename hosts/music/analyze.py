#!/usr/bin/env python3
"""A song file read for its patterns: the reference a composed Sound can take its tempo, key, chords, form, groove and
sung melody from (next/music.md, "Importing a song"). listen.py holds the pieces; this runs them in order.

    analyze.py <spec.json>

The spec, never argv: {"song" (any file FFmpeg reads), "ffmpeg" (its path), "out" (a folder), "lines" (optional: the
lyrics, [{"text", "syllables", "section"}] a sung line each, in order)}.

Writes `<out>/reference.json`:

    {"tempo" (BPM), "beat" (seconds), "offset" (the first downbeat, seconds), "bars" (count), "meter": 4,
     "key": {"tonic", "mode", "name", "confidence"},
     "chords": [{"bar", "beat", "root", "quality"}]   (each change, on the beat it lands)
     "sections": [{"bar", "bars", "letter", "sung"}]   (sung: the share of its bars with a voice in them)
     "drums": {letter: {"kick": [16 floats], "snare": [...], "hat": [...]}}   (a bar's sixteenths, how strong)
     "voice": {bar: {"pitch": [16], "onset": [16], "group"}}   (a sung bar's tune a sixteenth at a time: the pitch
              sung there, MIDI or 0, and how likely a syllable begins there; bars singing one line share a group)
     "lines": [{"bar", "text"}]   (each lyric line's first bar, where `lines` was given)
     "stray": seconds the beats stray from one straight grid}

and `<out>/done.json` ({"ok"} or {"ok": false, "error"}). Nothing of the song's sound is kept: its numbers only.
Progress is printed a line at a time.
"""

from __future__ import annotations

import json
import subprocess
import sys
import time
import traceback
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import listen as L  # noqa: E402

STEPS = 16  # sixteenths a bar
METER = 4
# A bar is sung when this share of it is voiced in the foreground...
SUNG = 0.2
# ...and what does not repeat in it is at least this share of its energy, and this many times the share in the song's
# quietest sixth of bars.
FOREGROUND_SHARE = 0.05
FLOOR_OVER = 1.4
# A sung bar's foreground hisses at least this much over 4 kHz against its middle band (energy ratio); less, and it is
# counted as sung that much less.
HISS_VOICE = 0.015
HISS_LEAST = 0.35
# Where chords are read from (Hz).
CHORD_BAND = (100.0, 1000.0)


def say(msg: str) -> None:
    print(msg, flush=True)


def decode(path: str, ffmpeg: str) -> np.ndarray:
    """The song as [2, n] floats at listen.RATE (a mono file is doubled)."""
    run = subprocess.run([ffmpeg, "-v", "error", "-i", path, "-ac", "2", "-ar", str(L.RATE), "-f", "f32le", "-"],
                         capture_output=True, check=False)
    if run.returncode != 0 or not run.stdout:
        raise RuntimeError("FFmpeg could not read the song: " + run.stderr.decode("utf-8", "replace")[-300:])
    x = np.frombuffer(run.stdout, dtype=np.float32).astype(np.float64)
    return x.reshape(-1, 2).T


def downbeat(grid: np.ndarray, kick: np.ndarray, change: np.ndarray) -> int:
    """Which beat of the first four is a bar's first: where the low drum and the chord changes fall most."""
    best, at = -1.0, 0
    for p in range(METER):
        score = float(kick[p::METER].mean() + 2.0 * change[p::METER].mean())
        if score > best:
            best, at = score, p
    return at


def analyze(spec: dict) -> dict:
    began = time.time()
    x = decode(str(spec["song"]), str(spec["ffmpeg"]))
    length = x.shape[1] / L.RATE
    mid, side = x.mean(axis=0), 0.5 * (x[0] - x[1])
    say("the spectrum")
    Zm = L.stft(mid)
    S = np.abs(Zm)
    S_side = L.spectrogram(side)
    H, P = L.hpss(S)
    env = L.onset_envelope(S)
    say("the beat")
    bpm = L.tempo(env)
    bf = L.beats(env, bpm)
    grid, beat, stray = L.straight_grid(bf, length)
    fps = L.RATE / L.HOP
    gf = np.round(grid * fps).astype(int)
    # chroma from a finer spectrum (at 2048 points a bin is 10.8 Hz, two semitones at a bass note's pitch), the chords'
    # from under 1 kHz (a saw's upper harmonics above it read as false sevenths), the bass note by harmonic summation
    # on a finer one still
    S4 = L.spectrogram(mid, 4096)
    H4, _P4 = L.hpss(S4)
    edges = np.append(gf, gf[-1] + int(beat * fps))
    Cb = L.sync(L.chroma(H4, CHORD_BAND[0], CHORD_BAND[1]), edges)
    low = L.sync(L.bass_chroma(L.spectrogram(mid, 8192)), edges, np.median)
    beat_chords = L.chords(Cb, low)
    change = np.array([0.0] + [1.0 if beat_chords[i] != beat_chords[i - 1] else 0.0 for i in range(1, len(beat_chords))])
    kick_env = L.drums(P, gf)["kick"]
    first = downbeat(grid, kick_env, change)
    grid, beat_chords = grid[first:], beat_chords[first:]
    bars = len(grid) // METER
    offset = float(grid[0]) if len(grid) else 0.0
    say("the key and chords")
    k = L.key_by_chords(L.chroma(H4, CHORD_BAND[0], CHORD_BAND[1]), beat_chords[:bars * METER])
    chords = []
    for i, ch in enumerate(beat_chords[:bars * METER]):
        if not chords or (chords[-1]["root"], chords[-1]["quality"]) != ch:
            chords.append({"bar": i // METER, "beat": i % METER, "root": int(ch[0]), "quality": ch[1]})
    # sixteenth grid
    step_t = np.concatenate([np.linspace(grid[b], grid[b] + beat, STEPS // METER, endpoint=False)
                             for b in range(bars * METER)]) if bars else np.zeros(0)
    step_t = np.append(step_t, offset + bars * METER * beat)
    sf = np.round(step_t * fps).astype(int)
    say("the drums")
    hits = L.drums(P, sf[:-1])
    say("the voice")
    bar_edges = np.round((offset + np.arange(bars + 1) * METER * beat) * fps).astype(int)
    mask = L.foreground(S, S_side, bar_edges)
    voice = L.istft(Zm * mask, len(mid))
    f0, ap, level = L.yin_candidates(voice, 70.0, 900.0)
    track = L.pitch_track(f0, ap, level)
    sung = np.zeros(bars)
    t_of = np.arange(len(track)) * 256 / L.RATE
    for b in range(bars):
        m = (t_of >= offset + b * METER * beat) & (t_of < offset + (b + 1) * METER * beat)
        sung[b] = float(np.mean(track[m] > 0)) if m.any() else 0.0
    # a bar is sung only where what does not repeat is a real share of it: the band alone leaves a few percent there
    # (what never repeats exactly), a voice singing words a sixth to a third (ERROR ME FOUND: 0.5-3% through its
    # intro, 13-40% through its verses)
    share = np.array([float(np.sum((S[:, bar_edges[b]:bar_edges[b + 1]] * mask[:, bar_edges[b]:bar_edges[b + 1]]) ** 2)
                            / (np.sum(S[:, bar_edges[b]:bar_edges[b + 1]] ** 2) + 1e-12)) for b in range(bars)])
    # ...and over what the band alone leaves in the song's quietest bars (a pad's chorus sways at no rate of the bar's,
    # so it never repeats exactly and stands in the foreground all through)
    floor = max(FOREGROUND_SHARE, FLOOR_OVER * float(np.percentile(share, 15)))
    sung = np.where(share >= floor, sung, 0.0)
    # ...and a voice says words: its consonants hiss over 4 kHz, which an instrument's lead does not (ERROR ME FOUND's
    # breaks: 0.1-0.6% of the foreground's middle band; its sung bars mostly 1.5-37%)
    f2 = L.bin_hz()
    hi_b, mid_b = (f2 >= 4000.0) & (f2 <= 10000.0), (f2 >= 200.0) & (f2 <= 3000.0)
    hiss = np.array([float(np.sum((S[hi_b, bar_edges[b]:bar_edges[b + 1]] * mask[hi_b, bar_edges[b]:bar_edges[b + 1]]) ** 2)
                           / (np.sum((S[mid_b, bar_edges[b]:bar_edges[b + 1]] * mask[mid_b, bar_edges[b]:bar_edges[b + 1]]) ** 2) + 1e-12))
                     for b in range(bars)])
    sung = sung * np.clip(hiss / HISS_VOICE, HISS_LEAST, 1.0)
    say("the tune")
    sal, cands = L.salience(voice)
    Vo = np.abs(L.stft(voice, 1024, 256))
    fo = np.arange(Vo.shape[0]) * L.RATE / 1024
    band = np.log1p(100.0 * Vo[(fo >= 200.0) & (fo <= 4000.0)].sum(axis=0))
    onset = np.maximum(np.diff(band, prepend=band[:1]), 0.0)
    bar_chord = [tuple(beat_chords[b * METER]) if b * METER < len(beat_chords) else (0, "") for b in range(bars)]
    profile = L.voice_profile(sal, cands, onset, step_t, bars, sung, bar_chord)
    say("the form")
    timbre = L.sync(np.log1p(L.log_bands(S, count=24)), bar_edges)
    timbre = (timbre - timbre.mean(axis=1, keepdims=True)) / (timbre.std(axis=1, keepdims=True) + 1e-9)
    feats = np.vstack([L.sync(L.chroma(H4, CHORD_BAND[0], CHORD_BAND[1]), bar_edges) * 2.0, timbre * 0.3, (sung[None, :] > SUNG) * 1.5])
    bounds, letters = L.sections(feats)
    secs = [{"bar": int(a), "bars": int(b - a), "letter": lt, "sung": round(float(np.mean(sung[a:b] > SUNG)), 2)}
            for a, b, lt in zip(bounds[:-1], bounds[1:], letters)]
    patterns: dict = {}
    for s in secs:
        rows = {}
        for name, v in hits.items():
            m = v[: bars * STEPS].reshape(bars, STEPS)[s["bar"]:s["bar"] + s["bars"]]
            rows[name] = [round(float(q), 2) for q in m.mean(axis=0)]
        patterns.setdefault(s["letter"], rows)
    voice_bars = {str(b): v for b, v in profile.items()}
    out = {"tempo": round(60.0 / beat, 3), "beat": beat, "offset": round(offset, 4), "bars": int(bars), "meter": METER,
           "length": round(length, 3), "key": k, "chords": chords, "sections": secs, "drums": patterns,
           "voice": voice_bars, "sung": [round(float(v), 2) for v in sung], "stray": round(stray, 4),
           "took": round(time.time() - began, 1)}
    lines = spec.get("lines") or []
    if lines:
        out["lines"] = place_lines(lines, sung, secs)
    return out


def place_lines(lines: list, sung: np.ndarray, secs: list) -> list:
    """Each lyric line's first bar: the sung bars in order, shared among the lines of each sung stretch."""
    runs = []  # (first bar, bars) of each stretch of sung bars
    b = 0
    while b < len(sung):
        if sung[b] > SUNG:
            e = b
            while e < len(sung) and sung[e] > SUNG * 0.5:
                e += 1
            runs.append((b, e - b))
            b = e
        else:
            b += 1
    total = sum(n for _a, n in runs)
    if total == 0:
        return []
    per = max(total / max(len(lines), 1), 1.0)
    out = []
    li = 0
    for a, n in runs:
        take = max(int(round(n / per)), 1)
        for q in range(take):
            if li >= len(lines):
                break
            out.append({"bar": int(a + round(q * n / take)), "text": str(lines[li].get("text", ""))})
            li += 1
    return out


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    spec = json.loads(Path(argv[1]).read_text(encoding="utf-8"))
    out = Path(spec["out"])
    out.mkdir(parents=True, exist_ok=True)
    try:
        ref = analyze(spec)
        tmp = out / "reference.json.part"
        tmp.write_text(json.dumps(ref, indent=1), encoding="utf-8")
        tmp.replace(out / "reference.json")
        done = {"ok": True, "reference": str(out / "reference.json"), "took": ref["took"]}
        say("done in %.1f s" % ref["took"])
    except Exception as exc:  # noqa: BLE001 - the app reads the reason
        traceback.print_exc()
        done = {"ok": False, "error": f"{type(exc).__name__}: {exc}"}
    (out / "done.json").write_text(json.dumps(done), encoding="utf-8")
    return 0 if done.get("ok") else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
