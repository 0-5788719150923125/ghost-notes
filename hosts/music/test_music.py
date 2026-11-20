#!/usr/bin/env python3
"""The music host held to what it makes and what it reads: a song rendered from a known score, then read back.

    <music_venv>/bin/python test_music.py

The fixture is made, not found: a score of sixteen bars - a known tempo, the chords C, G, Am, F a bar each, a backbeat,
the bass on the roots, a pad, and a lead singing a known tune in the middle of the stereo field, a vowel a note, no bar
of it alike, a hiss before each note as a word's consonant - rendered by
render.py, then read by analyze.py (FFmpeg decodes it; the test skips, saying so, where there is none).

Held:
- render.py makes the mix and a stem a part; made again from the same spec, each stem is read back, not made;
- the mix is loud enough, under the ceiling, and its stereo field holds the pad wider than the lead;
- the importer finds the tempo within a quarter of a beat a minute, the key's scale (C major or its relative minor),
  the chord roots of most bars, the kick on one and three and the snare on two and four, and the lead's pitch
  classes on most of its sung steps;
- the control: the same score at another tempo is read at that tempo, and with its lead muted the importer finds far
  fewer sung bars.
"""

import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import numpy as np  # noqa: E402

FAILS = 0
CHORDS = [(0, (48, 52, 55)), (7, (43, 47, 50)), (9, (45, 48, 52)), (5, (41, 45, 48))]
# the lead's tune, a bar's eighths (MIDI): drawn once from a seeded stream, chord tones on the beats and steps between,
# so no two bars of it are alike (a voice's line over sixteen bars rarely repeats a bar exactly)
_rng = np.random.default_rng(11)
TUNE = []
for _bar in range(16):
    _tones = [m + 12 for m in CHORDS[_bar % 4][1]]
    TUNE.append([int(_rng.choice(_tones)) if e % 2 == 0 else int(_rng.choice([60, 62, 64, 65, 67, 69, 71])) for e in range(8)])


def ok(cond: bool, what: str) -> None:
    global FAILS
    print(("  ok   " if cond else "  FAIL ") + what)
    if not cond:
        FAILS += 1


def score(bpm: float, out: Path, lead: bool = True) -> dict:
    beat = 60.0 / bpm
    drums, bass, pad, keys = [], [], [], []
    for bar in range(16):
        root, tri = CHORDS[bar % 4]
        for b in range(4):
            t = (bar * 4 + b) * beat
            drums.append({"t": t, "hit": "kick" if b in (0, 2) else "snare", "vel": 0.95})
            for e in range(2):
                drums.append({"t": t + e * beat / 2, "hit": "hat", "vel": 0.6})
        for e in range(8):
            bass.append({"t": (bar * 4 + e / 2) * beat, "len": beat * 0.45, "midi": 36 + root % 12 - (12 if root % 12 > 7 else 0), "vel": 0.85})
        for m in tri:
            pad.append({"t": bar * 4 * beat, "len": 4 * beat - 0.05, "midi": m + 12, "vel": 0.6})
        if lead and bar >= 4:
            # the tune on its beats, its rhythm between them and its vowel as a line of words would set them: never
            # twice alike (a part a vowel)
            for e, m in enumerate(TUNE[bar]):
                if e % 2 == 1 and (bar * 7 + e) % 3 == 0:
                    continue
                held = 0.9 if e % 2 == 1 or (bar * 5 + e) % 4 else 0.45
                keys.append({"t": (bar * 4 + e / 2) * beat, "len": beat * held, "midi": m, "vel": 0.65 + 0.3 * ((bar + e) % 3) / 2,
                             "vowel": "aioeu"[(bar * 3 + e) % 5]})
    parts = [
        {"key": "drums", "instrument": {"method": "kit"}, "notes": drums, "level": -3.0, "pan": 0.0, "fx": {}},
        {"key": "bass", "instrument": {"method": "subtractive", "cutoff": 400.0}, "notes": bass, "level": -4.0, "pan": 0.0, "fx": {}},
        {"key": "pad", "instrument": {"method": "subtractive", "unison": 3, "spread": 18.0, "width": 0.9, "cutoff": 1200.0,
                                      "amp": {"a": 0.3, "d": 0.5, "s": 0.8, "r": 0.5}}, "notes": pad, "level": -12.0, "pan": 0.0,
         "fx": {"chorus": 0.5}},
    ]
    # ...and its consonants: a hiss just before each note, as a word's "s" or "t" before its vowel
    parts.append({"key": "consonants", "instrument": {"method": "kit", "shaker": {"level": 1.0}},
                  "notes": [{"t": max(n["t"] - 0.04, 0.0), "hit": "shaker", "vel": 0.9} for n in keys], "level": -6.0,
                  "pan": 0.0, "fx": {}})
    for vw in "aioeu":
        parts.append({"key": "lead_" + vw, "instrument": {"method": "vox", "vowel": vw, "vibrato": 0.1,
                                                          "amp": {"a": 0.02, "d": 0.2, "s": 0.9, "r": 0.1}},
                      "notes": [n for n in keys if n["vowel"] == vw], "level": -2.0, "pan": 0.0, "fx": {}})
    return {"out": str(out), "mix": "mix.wav", "length": 16 * 4 * beat + 1.5, "seed": 3, "beat": beat, "parts": parts,
            "vocals": [], "master": {"reverb": {"seconds": 0.8}, "gain": -4.0, "ceiling": -1.0}}


def run(script: str, spec: dict, folder: Path) -> dict:
    folder.mkdir(parents=True, exist_ok=True)
    path = folder / (script + ".json")
    path.write_text(json.dumps(spec))
    subprocess.run([sys.executable, "-I", str(HERE / (script + ".py")), str(path)], check=False, capture_output=True)
    done = folder / "done.json"
    return json.loads(done.read_text()) if done.exists() else {"ok": False, "error": "no done.json"}


def main() -> int:
    from scipy.io import wavfile
    import listen

    ffmpeg = shutil.which("ffmpeg")
    work = Path(tempfile.mkdtemp(prefix="ghost_music_"))
    try:
        print("-- render")
        a = work / "a"
        done = run("render", score(100.0, a), a)
        ok(done.get("ok") and Path(done["mix"]).exists() and len(done["stems"]) == 9, "the mix and a stem a part: %s" % done.get("error", ""))
        made = {k: Path(p).stat().st_mtime_ns for k, p in done.get("stems", {}).items()}
        again = run("render", score(100.0, a), a)
        ok(again.get("ok") and all(Path(p).stat().st_mtime_ns == made[k] for k, p in again["stems"].items()),
           "made again from the same spec, every stem is read back")
        sr, mix = wavfile.read(done["mix"])
        x = mix.astype(float) / 32768.0
        peak = float(np.abs(x).max())
        ok(sr == 44100 and 0.2 < peak < 0.95, "44.1 kHz, its peak %.2f under the ceiling and loud enough" % peak)
        stems = {k: wavfile.read(p)[1].astype(float) for k, p in done["stems"].items()}

        def width(s):
            return float(np.sum((s[:, 0] - s[:, 1]) ** 2) / (np.sum((s[:, 0] + s[:, 1]) ** 2) + 1e-9))
        ok(width(stems["pad"]) > 5.0 * width(stems["bass"]) + 1e-6, "the pad's unison spreads it wider than the bass")
        if ffmpeg is None:
            print("  skip the importer: no ffmpeg")
            return 1 if FAILS else 0
        print("-- the importer reads it back")
        ref_done = run("analyze", {"song": done["mix"], "ffmpeg": ffmpeg, "out": str(a)}, a)
        ok(ref_done.get("ok"), "analyze.py read the mix: %s" % ref_done.get("error", ""))
        ref = json.loads((a / "reference.json").read_text())
        ok(abs(ref["tempo"] - 100.0) < 0.25, "the tempo: %.3f" % ref["tempo"])
        k = ref["key"]
        ok((k["tonic"], k["mode"]) in ((0, "major"), (9, "minor")), "the key's scale: %s" % k["name"])
        ordered = sorted(ref["chords"], key=lambda c: (c["bar"], c["beat"]))
        hits = 0
        for bar in range(ref["bars"]):
            cur = None
            for c in ordered:
                if (c["bar"], c["beat"]) <= (bar, 1):
                    cur = c["root"]
            hits += 1 if cur == CHORDS[bar % 4][0] else 0
        ok(hits >= 0.6 * ref["bars"], "the chord roots of most bars: %d of %d" % (hits, ref["bars"]))
        longest = max(ref["sections"], key=lambda sec: sec["bars"])
        pat = ref["drums"][longest["letter"]]
        kick, snare = np.array(pat["kick"]), np.array(pat["snare"])
        ok(kick[[0, 8]].min() > kick[[4, 12]].max() and snare[[4, 12]].min() > snare[[0, 8]].max(),
           "the kick on one and three, the snare on two and four: %s / %s" % (np.round(kick[::4], 2), np.round(snare[::4], 2)))
        voice = ref.get("voice", {})
        right = total = 0
        for b, v in voice.items():
            bar = int(b)
            if bar < 4:
                continue
            tune = TUNE[bar]
            for step, p in enumerate(v["pitch"]):
                if p:
                    total += 1
                    right += 1 if p % 12 == tune[step // 2] % 12 else 0
        ok(total > 40 and right >= 0.5 * total, "the lead's pitch classes on most of its sung steps: %d of %d" % (right, total))
        print("-- the controls")
        b = work / "b"
        run("render", score(128.0, b), b)
        run("analyze", {"song": str(b / "mix.wav"), "ffmpeg": ffmpeg, "out": str(b)}, b)
        ref_b = json.loads((b / "reference.json").read_text())
        ok(abs(ref_b["tempo"] - 128.0) < 0.3, "another tempo is read as that tempo: %.3f" % ref_b["tempo"])
        c = work / "c"
        run("render", score(100.0, c, lead=False), c)
        run("analyze", {"song": str(c / "mix.wav"), "ffmpeg": ffmpeg, "out": str(c)}, c)
        ref_c = json.loads((c / "reference.json").read_text())
        ok(len(ref_c.get("voice", {})) < 0.5 * max(len(voice), 1),
           "with the lead muted, far fewer bars are sung: %d against %d" % (len(ref_c.get("voice", {})), len(voice)))
    finally:
        shutil.rmtree(work, ignore_errors=True)
    print("test_music: %s" % ("ALL OK" if FAILS == 0 else "%d FAILED" % FAILS))
    return 1 if FAILS else 0


if __name__ == "__main__":
    raise SystemExit(main())
