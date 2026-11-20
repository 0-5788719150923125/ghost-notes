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
- the vocoder: a vowel sung at 200 Hz through a carrier at 300 Hz comes out at 300 Hz, its spectrum the vowel's (its
  energy where the vowel's formants are, not where the bare carrier's is) - the control, the carrier alone, has no
  such shape;
- the importer finds the tempo within a quarter of a beat a minute, the key's scale (C major or its relative minor),
  the chord roots of most bars, the kick on one and three and the snare on two and four, and the lead's pitch
  classes on most of its sung steps;
- the control: the same score at another tempo is read at that tempo, and with its lead muted the importer finds far
  fewer sung bars;
- the stream (stream.py): the song made in windows whose joins fall off the beat is the whole - from kept stems its
  samples, from nothing kept its loudness envelope - and its joins are no louder a step than the song elsewhere; the
  controls, a window made with no time before it (the room's tail lost after each join) and windows not faded into
  each other (two takes of a held chord meeting), each fail; a bar played again while the singer is late (a vamp,
  `follows`) begins where what came before it would have gone on - the control, not faded in, jumps; a take gone from
  the disk is left out and the song made without it, a take there heard.
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
# the stream's window here: its joins off the beat (at 100 BPM a beat is 0.6 s)
STREAM_WINDOW = 5.3
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


def windows(spec: dict, length: float, pre: float = None, xfade: float = None) -> np.ndarray:
    """The song of `spec` made in stream.py's windows of STREAM_WINDOW seconds, laid end to end."""
    import stream
    old = stream.PRE, stream.XFADE
    stream.PRE = old[0] if pre is None else pre
    stream.XFADE = old[1] if xfade is None else xfade
    try:
        song = stream.Song(spec)
        out, t = [], 0.0
        while t < length:
            t1 = min(t + STREAM_WINDOW, length)
            out.append(song.window(t, t1))
            t = t1
        return np.concatenate(out, axis=1)
    finally:
        stream.PRE, stream.XFADE = old


def joins(x: np.ndarray, whole: np.ndarray) -> dict:
    """How windows `x` meet, against `whole`: the leftover in the half second after each join over the leftover
    elsewhere, and the step at each join over the steps near it, beside the same step off the joins (median each)."""
    n = min(x.shape[1], whole.shape[1])
    x, w = x[:, :n], whole[:, :n]
    rate = 44100
    r = x * (np.sum(x * w) / np.sum(x * x)) - w
    at = [int(round(k * STREAM_WINDOW * rate)) for k in range(1, int(n / rate / STREAM_WINDOW) + 1)]
    at = [a for a in at if a + rate < n]
    d = np.abs(np.diff(x.mean(axis=0)))

    def step(a: int) -> float:
        return d[a - 1] / (np.median(d[a - 2205:a + 2205]) + 1e-9)

    level = 20.0 * np.log10(np.sqrt(np.mean(x ** 2)) / np.sqrt(np.mean(w ** 2)))
    hop = int(0.05 * rate)

    def env(y: np.ndarray) -> np.ndarray:
        m = y.mean(axis=0)
        return np.log(1e-6 + np.add.reduceat(m[: len(m) // hop * hop] ** 2, np.arange(0, len(m) // hop * hop, hop)))

    return {"after": float(np.median([np.mean(r[:, a:a + rate // 2] ** 2) for a in at]) / np.mean(r ** 2)),
            "step": float(np.median([step(a) for a in at])), "off": float(np.median([step(a + int(1.7 * rate)) for a in at])),
            "level": float(level), "corr": float(np.corrcoef(x.mean(axis=0), w.mean(axis=0))[0, 1]),
            "envelope": float(np.corrcoef(env(x), env(w))[0, 1])}


def fake_take(path: Path) -> Path:
    """A take as the voice host writes one: a second of a sung vowel's stand-in (a 220 Hz tone), 16-bit at 24 kHz."""
    from scipy.io import wavfile
    t = np.arange(24000) / 24000.0
    wavfile.write(str(path), 24000, (0.5 * np.sin(2 * np.pi * 220.0 * t) * 32767).astype(np.int16))
    return path


def vamped(spec: dict, follows: bool) -> float:
    """The song made up to a bar line, then the bar before it three times again without the voice: how far each repeat's
    first sample lies from where the stretch before it would have gone on (its next sample), over a step of the song
    there (the median step between samples) - the worst of the three."""
    import stream
    song = stream.Song(spec)
    bar = 4 * float(spec["beat"])
    b = 8 * bar
    prev = song.window(0.0, b)
    worst = 0.0
    for _ in range(3):
        natural = song._tail[:, 0].copy()
        v = song.window(b - bar, b, False, follows)
        step = float(np.median(np.abs(np.diff(prev[:, -2205:], axis=1)))) + 1e-9
        worst = max(worst, float(np.abs(v[:, 0] - natural).max()) / step)
        prev = v
    return worst


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
        print("-- the stream")
        st = work / "s"
        spec = score(100.0, st)
        for p in spec["parts"]:
            if p["key"] in ("pad", "drums"):
                p["fx"] = {**p["fx"], "reverb": 0.4}  # a room to carry over a join
        spec["master"]["reverb"]["seconds"] = 2.0
        made = run("render", spec, st)
        whole = (wavfile.read(made["mix"])[1].astype(np.float64) / 32768.0).T
        kept = joins(windows(spec, spec["length"]), whole)
        ok(kept["corr"] > 0.99 and abs(kept["level"]) < 1.0,
           "from kept stems the windows are the whole: correlation %.3f, %+.2f dB" % (kept["corr"], kept["level"]))
        ok(kept["after"] < 1.4, "the room carries over a join: %.2fx the leftover elsewhere" % kept["after"])
        bare = joins(windows(spec, spec["length"], pre=0.0), whole)
        ok(bare["after"] > 1.4, "the control, nothing made before a window, loses the room after a join: %.2fx" % bare["after"])
        cold = dict(spec, out=str(work / "s_cold"))
        fresh = joins(windows(cold, spec["length"]), whole)
        ok(fresh["envelope"] > 0.98 and abs(fresh["level"]) < 1.5,
           "from nothing kept the windows sound as the whole: envelope %.3f, %+.2f dB" % (fresh["envelope"], fresh["level"]))
        ok(fresh["step"] < 1.5 * fresh["off"], "a join is no step: %.1fx the steps near it, %.1fx off the joins" % (fresh["step"], fresh["off"]))
        raw = joins(windows(cold, spec["length"], xfade=0.0), whole)
        ok(raw["step"] > 2.0 * raw["off"], "the control, windows not faded together, steps at a join: %.1fx against %.1fx" % (raw["step"], raw["off"]))
        import stream
        taken = dict(spec, vocals=[{"key": "vocal", "level": 0.0, "pan": 0.0, "fx": {}, "takes": [
            {"wav": str(fake_take(work / "take.wav")), "at": 2.0}, {"wav": str(work / "gone.wav"), "at": 6.0}]}])
        song = stream.Song(taken)
        heard = float(np.sqrt(np.mean(song.window(2.0, 3.0) ** 2)))
        bare_take = float(np.sqrt(np.mean(stream.Song(spec).window(2.0, 3.0) ** 2)))
        gone = song.window(6.0, 7.0)
        ok(heard > bare_take * 1.05 and gone.shape[1] == 44100,
           "a take there is heard (%.3f against %.3f without), and one gone from the disk is left out, the song made without it" % (heard, bare_take))
        vamp = vamped(cold, True)
        bare_vamp = vamped(cold, False)
        ok(vamp < 0.5 and bare_vamp > 3.0,
           "a bar played again begins where what came before goes on: %.2f of a step off; the control, not faded in, %.1f steps" % (
               vamp, bare_vamp))
        print("-- the vocoder")
        import dsp
        import instruments
        rng = np.random.default_rng(1)
        n = 44100
        voice = instruments.vox({"instrument": {"vowel": "a", "vibrato": 0.0, "amp": {"a": 0.01, "d": 0.1, "s": 1.0, "r": 0.05}},
                                 "notes": [{"t": 0.0, "len": 0.95, "midi": 55.0}]}, n, rng).mean(axis=0)
        ph, dt = dsp.phase(300.0, n)
        carrier = dsp.saw(ph, dt)
        robot = dsp.vocoder(voice, carrier)
        seg = robot[11025:33075]
        ac = np.correlate(seg[:8000], seg[:8000], mode="full")[7999:]
        lag = 60 + int(np.argmax(ac[60:400]))
        f0 = 44100.0 / lag
        def formant_share(x):
            spec = np.abs(np.fft.rfft(x[11025:33075]))
            f = np.fft.rfftfreq(22050, 1 / 44100)
            return float(spec[(f > 600) & (f < 1200)].sum() / spec[(f > 100) & (f < 4000)].sum())
        ok(abs(f0 - 300.0) < 8.0, "a vowel at 200 Hz through a carrier at 300 Hz comes out at %.0f Hz" % f0)
        ok(formant_share(robot) > 1.3 * formant_share(carrier),
           "...shaped as the vowel: %.2f of its energy where the vowel's first formants are, the bare carrier %.2f"
           % (formant_share(robot), formant_share(carrier)))
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
