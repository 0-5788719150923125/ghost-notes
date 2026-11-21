"""stream.py - a composed Sound made a stretch at a time, for hearing it as it plays (host.py serves it; the app's
SongStream asks). The same score render.py makes whole, in windows of a few seconds:

- a part whose stem is kept (render.py's, under the same hash) is read from it - a slice of the file, nothing made;
- a part not kept is made over the window and PRE seconds before it, its notes still sounding from before the window
  included, so a held chord, a note's release, an echo and the room carry into the window as they would in the whole;
- each voice (the lead, a chorus's voices) is its takes laid where they fall (the app sings them ahead and says which
  are there, each take naming its voice), through the vocoder where the score asks for one, placed left to right;
- every part's level is brought to one loudness (render.PLAYING) by a gain found once - from its kept stem, or from
  the stretch where it plays most - and the whole by one gain found once from the song's busiest stretch, so the
  windows join at one level.

A window is what the whole would be over it, near enough to judge a roll by: a part's noise, its oscillators' phases and
its kit's variants are drawn afresh each window, and the limiter's memory is the window's own. So a window is made
XFADE seconds past its end, and the window asked next from there fades in from that tail: a chord held across the join
is two takes of it, never a step between them.
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from scipy.io import wavfile

import dsp
import instruments
import render
from dsp import RATE

# Seconds made before a window for what carries into it: a release, an echo, the room's tail.
PRE = 3.0
# Seconds of a part made to find its loudness where no stem is kept, at its busiest.
PROBE = 6.0
# Seconds a window runs past its end, faded into the next.
XFADE = 0.02


class Song:
    def __init__(self, spec: dict) -> None:
        self.spec = spec
        self.seed = int(spec.get("seed", 0))
        self.beat = float(spec.get("beat", 0.5))
        self.length = float(spec["length"])
        self.stems = Path(spec["out"]) / "stems"
        master = spec.get("master", {}) or {}
        rv = master.get("reverb", {}) or {}
        self.ir = dsp.reverb_ir(float(rv.get("seconds", 2.0)), render.rng_of(self.seed, "room"), float(rv.get("damp", 0.5)),
                                float(rv.get("predelay", 0.015)))
        self.ceiling = float(master.get("ceiling", -1.0))
        self.loudness = float(master.get("loudness", render.LOUDNESS))
        self.parts = []
        for part in spec.get("parts", []):
            path = render.stem_path(part, self.seed, self.beat, self.stems)
            kept = None
            if path.exists() and render.read_wav_frames(path) >= int(self.length * RATE):
                _sr, kept = wavfile.read(str(path), mmap=True)  # float32 [n, 2], read a slice at a time
            self.parts.append({"part": part, "kept": kept, "gain": 1.0})
        for p in self.parts:
            p["gain"] = self._part_gain(p)
        self.voices = [dict(v, _gain=None) for v in spec.get("vocals") or []]
        self._takes: dict = {}  # a take's samples at RATE, read once
        self._tail = None  # the last window's XFADE past its end, and where it begins
        self._tail_at = -1.0
        self.master = 1.0
        self.master = self._master_gain()

    # -- the windows ---------------------------------------------------------------------------------

    def window(self, t0: float, t1: float, voice: bool = True, follows: bool = None) -> np.ndarray:
        """The mix over [t0, t1), [2, samples] - without the voice where `voice` is False (a vamp while the singer is
        late) - faded in from the last window's tail where it follows it: where it begins where that one ended, or
        always where `follows` (a bar played again after another)."""
        x = self._made(t0, t1 + XFADE, voice)
        keep = x.shape[1] - int(round(XFADE * RATE))
        out, tail = x[:, :keep], x[:, keep:]
        joins = follows if follows is not None else abs(self._tail_at - t0) < 0.5 / RATE
        if self._tail is not None and joins:
            k = min(self._tail.shape[1], out.shape[1])
            ramp = np.sin(np.linspace(0.0, np.pi / 2.0, k)) ** 2
            out[:, :k] = self._tail[:, :k] * (1.0 - ramp) + out[:, :k] * ramp
        self._tail, self._tail_at = tail, t1
        return out

    def _made(self, t0: float, t1: float, voice: bool = True) -> np.ndarray:
        """The mix over [t0, t1), made from PRE seconds before it."""
        w0 = max(0.0, t0 - PRE)
        n = int(round((t1 - w0) * RATE))
        skip = int(round((t0 - w0) * RATE))
        mix = np.zeros((2, n))
        send = np.zeros((2, n))
        for p in self.parts:
            part = p["part"]
            if part.get("mute"):
                continue
            x = self._part(p, w0, n)
            if float(part.get("pan", 0.0)):
                x = dsp.pan(x.mean(axis=0), float(part["pan"])) * 0.5 + x * 0.5
            x = x * p["gain"] * 10.0 ** (float(part.get("level", 0.0)) / 20.0)
            mix += x
            send += x * float((part.get("fx") or {}).get("reverb", 0.0))
        for v in self.voices if voice else []:
            if v.get("mute"):
                continue
            x = self._voice(v, w0, n)
            if x is not None:
                mix += x
                send += x * float((v.get("fx") or {}).get("reverb", 0.15))
        if np.any(send):
            mix += dsp.convolve(send, self.ir) * 0.5
        mix *= self.master
        mix = dsp.butter(mix, "highpass", 25.0)
        mix = dsp.limit(mix, self.ceiling)
        return mix[:, skip:]

    def set_takes(self, takes: list) -> None:
        """Every take sung so far, each to the voice it names (the lead's where it names none)."""
        for v in self.voices:
            key = str(v.get("key", "vocal"))
            v["takes"] = [t for t in takes if str(t.get("voice", "vocal")) == key]

    # -- a part over a stretch -----------------------------------------------------------------------

    def _part(self, p: dict, w0: float, n: int) -> np.ndarray:
        """Part `p` over [w0, w0 + n samples): its kept stem's slice, or made there."""
        a = int(round(w0 * RATE))
        kept = p["kept"]
        if kept is not None:
            got = np.zeros((2, n))
            b = min(a + n, kept.shape[0])
            if b > a:
                got[:, :b - a] = np.asarray(kept[a:b], dtype=np.float64).T
            return got
        return self._make(p["part"], w0, n)

    def _make(self, part: dict, w0: float, n: int) -> np.ndarray:
        t1 = w0 + n / RATE
        notes = []
        for nt in part.get("notes", []):
            start = float(nt["t"])
            end = start + float(nt.get("len", 0.0)) + 6.0  # a note's release, a struck note's ring
            if start < t1 and end > w0:
                notes.append({**nt, "t": start - w0})
        rng = render.rng_of(self.seed, str(part["key"]))
        x = instruments.render({**part, "notes": notes}, n, rng)
        return render.effects(x, part.get("fx", {}) or {}, self.beat, rng)

    def _part_gain(self, p: dict) -> float:
        """A part's gain to the one loudness: from its kept stem, else from PROBE seconds where it plays most."""
        if p["kept"] is not None:
            return render.playing_gain(np.asarray(p["kept"][::4], dtype=np.float64).T)
        notes = p["part"].get("notes", [])
        if not notes:
            return 1.0
        t = _busiest([float(nt["t"]) for nt in notes], PROBE, self.length)
        return render.playing_gain(self._make(p["part"], max(0.0, t - PRE), int((PROBE + PRE) * RATE)))

    def _master_gain(self) -> float:
        """The whole's gain to its loudness, from the song's busiest stretch (every part's notes counted)."""
        times = [float(nt["t"]) for p in self.parts for nt in p["part"].get("notes", [])]
        if not times:
            return 1.0
        t = _busiest(times, PROBE, self.length)
        w = self._made(t, min(t + PROBE, self.length))
        return render.playing_gain(w) * 10.0 ** ((self.loudness - render.PLAYING) / 20.0)

    # -- the voice -----------------------------------------------------------------------------------

    def _voice(self, v: dict, w0: float, n: int):
        """Voice `v` over [w0, w0 + n samples): the takes there laid where they fall, through the vocoder where the
        score asks for one, through its own effects, at the one loudness, placed; None where nothing is sung there."""
        x = np.zeros((2, n))
        t1 = w0 + n / RATE
        any_take = False
        for take in v.get("takes", []):
            at = float(take.get("at", 0.0))
            frames = render.wav_seconds(str(take["wav"]))  # 0 for a take gone from the disk: that stretch goes without
            if frames <= 0.0 or at >= t1 or at + frames <= w0:
                continue
            if take["wav"] not in self._takes:
                try:
                    self._takes[take["wav"]] = render.read_wav(str(take["wav"])).mean(axis=0)
                except OSError:
                    continue
            mono = self._takes[take["wav"]]
            s = int(round((at - w0) * RATE))
            a, b = max(0, -s), min(len(mono), n - s)
            if b > a:
                x[:, s + a:s + b] += mono[a:b]
                any_take = True
                if v["_gain"] is None:
                    v["_gain"] = render.playing_gain(np.stack([mono, mono]))
        if not any_take:
            return None
        amount = float(v.get("vocoder", 0.0))
        if amount > 0.0 and v.get("notes"):
            notes = [{**nt, "t": float(nt["t"]) - w0} for nt in v["notes"]
                     if float(nt["t"]) < t1 + 0.1 and float(nt["t"]) + float(nt["len"]) > w0 - 0.2]
            x = render.vocoded(x, notes, amount, render.rng_of(self.seed, render.vocoder_salt(v)))
        fx = {"highpass": 90.0, "compress": {"threshold": -20.0, "ratio": 3.0}, **(v.get("fx", {}) or {})}
        x = render.effects(x, fx, self.beat, render.rng_of(self.seed, str(v.get("key", "vocal"))))
        x = render.placed(x, float(v.get("pan", 0.0)))
        return x * (v["_gain"] or 1.0) * 10.0 ** (float(v.get("level", 0.0)) / 20.0)


def _busiest(times: list, span: float, length: float) -> float:
    """Where the most of `times` fall within `span` seconds: its start."""
    ts = np.sort(np.asarray(times))
    best, at = -1, 0.0
    j = 0
    for i, t in enumerate(ts):
        while ts[j] < t - span:
            j += 1
        if i - j > best:
            best, at = i - j, float(ts[j])
    return min(max(at, 0.0), max(length - span, 0.0))
