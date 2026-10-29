#!/usr/bin/env python3
"""Every voice at one level.

THE USER (2026-10-28): "Especially if we're going to continue adding voice model support, we're
going to want a sane way to keep the volume even across them all." Nothing levelled them: Piper
puts a take's level back after its effort filter and that is all, so each model's own level went
straight on into the reading. Measured on four paragraphs of one chapter, speaking RMS:
libritts-high 0.065, Kokoro's Heart 0.086 and Puck 0.141 - Puck's takes at full scale, clipped in
the write - and the ambience bed, staged under libritts-high, sank 17 dB under Puck.

SO EACH VOICE IS MEASURED ONCE, as the vowel probe measures a checkpoint: a fixed passage
(LEVEL_TEXT) rendered through the backend's own `_run` with no delivery at all, its SPEAKING level
taken (`speaking_level`: the RMS of the frames within LEVEL_GATE dB of its loud ones - the pauses
and breaths left out), and the voice's gain is TARGET over it. Every take of the voice is scaled by
it as it comes out of the model, before any of the host's own shaping - an emphasis lift is held
under full scale (piper.py EMPHASIS_CEILING), and a hot take had no room left for one. ONE GAIN A
VOICE AND SPEAKER, NEVER A TAKE: a hushed approach, a lifted word, a paragraph's arc are the host's
and the model's, and stay as they were.

TARGET is libritts-high speaker 0's own level measured so - the default voice, every reading made
in it so far and the level VoiceFX's bed was staged under (voice_fx.gd PAD_VOICE_REF) - so its
gain is 1. A new backend needs nothing here: it is levelled by its own `_run` and the files it names
(`_level_files`).

Cached beside the weights (`levels.json` in the backend's own folder), keyed by the voice, the
speaker, LEVEL_VERSION and the model files' sizes and times - a voice taught again keeps its id; a
read-only voices folder just measures again. A failure is gain 1 and is not kept: a voice is never
lost to its level.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

# Plain narration, two sentences, neither a question nor an exclamation: about six seconds of speech.
LEVEL_TEXT = (
    "The morning was quiet, and the road ran on past the river.",
    "She opened the letter and read it twice before she put it down.",
)
# A change to the passage or the measure: every voice is measured again. (A level is kept, not a gain: TARGET
# may move without it.)
LEVEL_VERSION = 2
# libritts-high, speaker 0, as `measure` measures it: 0.0480 with the noise off, times what its noise adds
# (piper.py `level_noise`). Others, measured so: its speaker 4 0.0333, Kokoro's Heart 0.0853, Emma 0.1105,
# Puck 0.1315, Maple (1.1) 0.0499 - 2 to 4 s each. Read in the same chapter after, every voice's speech
# came within 1.2 dB of the others' (Piper's delivery lifts it a little more than Kokoro's).
TARGET = 0.0547
# A frame counts as speech within this many dB of the loud frames (the 95th percentile frame).
LEVEL_GATE = 30.0
FRAME_S = 0.02
# How far a voice is ever moved: a measure past these is a broken render, not a voice.
GAIN_MIN = 0.1
GAIN_MAX = 10.0


def speaking_level(audio, sr: int) -> float:
    """The RMS of `audio`'s speech: its FRAME_S frames within LEVEL_GATE dB of its loud ones. 0 for silence."""
    import numpy as np

    a = np.asarray(audio, dtype=np.float64).ravel()
    n = max(1, int(FRAME_S * sr))
    k = a.size // n
    if k == 0:
        return 0.0
    ms = (a[: k * n].reshape(k, n) ** 2).mean(axis=1)
    loud = float(np.percentile(ms, 95))
    if loud <= 0.0:
        return 0.0
    keep = ms >= loud * 10.0 ** (-LEVEL_GATE / 10.0)
    return float(np.sqrt(ms[keep].mean()))


def tokens_of(sentence: str) -> list:
    """A sentence as the host's tokens: each word and the marks after it."""
    out = []
    for w in sentence.split():
        m = re.match(r"^(.*?)([.,;:!?]*)$", w)
        out.append({"text": m.group(1), "punct": m.group(2)})
    return out


class Levels:
    """The gain each voice and speaker is played at, measured once and kept in `folder`."""

    def __init__(self, folder: Path) -> None:
        self._path = Path(folder) / "levels.json"
        self._gains: dict = {}

    def gain(self, backend, voice: str, speaker: int, cfg: dict, sess) -> float:
        """The gain for `voice`'s `speaker`: kept, or measured now through `backend`'s `_run` on `sess` and `cfg`."""
        key = f"{voice}#{int(speaker)}"
        if key in self._gains:
            return self._gains[key]
        ident = self._ident(backend, voice, speaker)
        level = self._load(key, ident)
        if level is None:
            try:
                level = self.measure(backend, voice, speaker, cfg, sess)
            except Exception as exc:  # noqa: BLE001 - a voice is never lost to its level
                print(f"ghost/voice: could not measure {key}'s level ({exc}); played as it comes", file=sys.stderr)
                level = 0.0
            if level > 0.0:
                self._save(key, ident, level)
        g = min(max(TARGET / level, GAIN_MIN), GAIN_MAX) if level > 0.0 else 1.0
        print(f"ghost/voice: {key} speaks at {level:.4f}, played at {g:.3f}", file=sys.stderr)
        self._gains[key] = g
        return g

    @staticmethod
    def measure(backend, voice: str, speaker: int, cfg: dict, sess) -> float:
        """LEVEL_TEXT's speaking level in `voice`'s `speaker`, through the backend's own `_run`, nothing delivered."""
        import numpy as np

        # NO NOISE: a VITS model samples its sound and its timing on every render (Piper's noise_scale and noise_w),
        # and libritts-high's level measured so moved 0.7 dB from one render to the next - a level kept for good
        # must be the same wherever it is measured. Kokoro samples nothing.
        params = {"speaker": int(speaker), "phonemizer": "espeak", "lexicon": "off", "noise_scale": 0.0,
                  "noise_w": 0.0}
        takes = []
        for sentence in LEVEL_TEXT:
            audio, _spans = backend._run(tokens_of(sentence), voice, params, cfg, sess, "espeak")
            takes.append(np.asarray(audio, dtype=np.float32).ravel())
        sr = int(cfg.get("audio", {}).get("sample_rate", 22050))
        # ...and what the noise it was measured without adds back in use (the backend's own, measured)
        return speaking_level(np.concatenate(takes), sr) * float(getattr(backend, "level_noise", 1.0))

    @staticmethod
    def _ident(backend, voice: str, speaker: int) -> str:
        parts = [f"v{LEVEL_VERSION}"]
        for p in backend._level_files(voice, speaker):
            try:
                st = Path(p).stat()
                parts.append(f"{Path(p).name}:{st.st_size}:{st.st_mtime_ns}")
            except OSError:
                parts.append(f"{Path(p).name}:-")
        return ";".join(parts)

    def _read(self) -> dict:
        try:
            got = json.loads(self._path.read_text(encoding="utf-8"))
        except Exception:  # noqa: BLE001 - absent, unreadable or half-written
            return {}
        return got if isinstance(got, dict) else {}

    def _load(self, key: str, ident: str):
        row = self._read().get(key)
        if isinstance(row, dict) and row.get("ident") == ident and isinstance(row.get("level"), (int, float)) \
                and float(row["level"]) > 0.0:
            return float(row["level"])
        return None

    def _save(self, key: str, ident: str, level: float) -> None:
        try:
            rows = self._read()
            rows[key] = {"ident": ident, "level": round(level, 6)}
            self._path.parent.mkdir(parents=True, exist_ok=True)
            tmp = self._path.with_suffix(".json.part")
            tmp.write_text(json.dumps(rows, indent=1, sort_keys=True), encoding="utf-8")
            tmp.replace(self._path)  # atomic: a reader sees the whole file or none
        except Exception:  # noqa: BLE001 - a read-only voices folder just measures again
            pass
