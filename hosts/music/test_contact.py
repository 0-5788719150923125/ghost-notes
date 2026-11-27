#!/usr/bin/env python3
"""contact.py held to what the motion says (next/studio.md, "The sound").

    <music_venv>/bin/python test_contact.py [--demo DIR]

Held, each against a control that must differ:
- a pure function: the same lanes and seed are the same samples (another seed, other samples);
- faster is brighter and louder: fur rubbed at 0.3 m/s against 0.05 m/s, a block scraped quick against slow;
- harder is louder: the same scrape at 3 N against 0.5 N;
- the side heard: a rub on the left of the windscreen is louder in the left ear and reaches it first (the right side the
  other way round); one at the back (toward the viewer) is darker than one at the front at the same distance;
- near is louder: a tap on the camera across the room is quieter than one on the microphone's body;
- a hit's softness: a fingertip's tap is darker than a nail's on the same body;
- stick-slip: a slow, hard scrape has the creak's regular slips (its envelope periodic at speed / SLIP_STEP), a quick one
  does not;
- nothing clips (the limiter's ceiling), the edges never click (the first and last samples near silence);
- a spec past its bounds is refused, saying why; contact.py writes the WAV and the done file.

`--demo DIR` also writes each sound held here to DIR, for the ear.
"""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import numpy as np  # noqa: E402

import contact  # noqa: E402

FAILS = 0
LR = 300.0
R = 0.088   # the windscreen's radius


def ok(cond: bool, msg: str) -> None:
    global FAILS
    print(("ok    " if cond else "FAIL  ") + msg)
    if not cond:
        FAILS += 1


def lanes(secs: float, at, speed, force) -> dict:
    """Lanes for `secs` seconds: `at` a point or a function of time (s) to a point, speed and force numbers or functions."""
    t = np.arange(int(secs * LR)) / LR
    sp = speed(t) if callable(speed) else np.full_like(t, float(speed))
    fo = force(t) if callable(force) else np.full_like(t, float(force))
    if callable(at):
        p = np.array([at(tt) for tt in t])
    else:
        p = np.tile(np.asarray(at, dtype=float), (t.size, 1))
    return {"x": p[:, 0].tolist(), "y": p[:, 1].tolist(), "z": p[:, 2].tolist(), "speed": sp.tolist(), "force": fo.tolist()}


def envelope(t: np.ndarray, secs: float) -> np.ndarray:
    """Pressed in over a quarter second and let go over the last quarter (a hand lands and lifts)."""
    return np.clip(t / 0.25, 0.0, 1.0) * np.clip((secs - t) / 0.25, 0.0, 1.0)


def rub(secs: float, at, speed: float, force: float, kind="rub", on="fur", by="skin", body=None, seed=1, wobble=0.1) -> dict:
    c = {"kind": kind, "on": on, "by": by,
         "lanes": lanes(secs, at, lambda t: speed * envelope(t, secs) * (1.0 + wobble * np.sin(2 * np.pi * 2.3 * t)),
                        lambda t: force * envelope(t, secs))}
    if body:
        c["body"] = body
    return {"secs": secs, "tail": 0.4, "seed": seed, "lane_rate": LR, "contacts": [c], "hits": []}


def mid(x: np.ndarray, secs: float) -> np.ndarray:
    a, b = int(0.4 * contact.RATE), int((secs - 0.4) * contact.RATE)
    return x[:, a:b]


def db(x: np.ndarray) -> float:
    return float(20.0 * np.log10(np.sqrt(np.mean(x * x)) + 1e-12))


def centroid(x: np.ndarray) -> float:
    mono = x.mean(axis=0) if x.ndim == 2 else x
    spec = np.abs(np.fft.rfft(mono * np.hanning(mono.size)))
    hz = np.fft.rfftfreq(mono.size, 1.0 / contact.RATE)
    return float(np.sum(spec * hz) / (np.sum(spec) + 1e-12))


def onset_lag(x: np.ndarray) -> int:
    """Samples by which the left ear's onset leads the right's (positive: left first)."""
    def first(ch):
        a = np.abs(ch)
        return int(np.argmax(a > a.max() * 0.2))
    return first(x[1]) - first(x[0])


def main(argv: list[str]) -> int:
    demo = Path(argv[argv.index("--demo") + 1]) if "--demo" in argv else None
    made = {}

    def make(name: str, spec: dict) -> np.ndarray:
        why = contact.check(spec)
        if why:
            raise ValueError(name + ": " + why)
        x = contact.render(spec)
        made[name] = x
        return x

    secs = 3.0
    left = [-R, 0.0, 0.0]
    right = [R, 0.0, 0.0]
    back = [0.0, 0.0, R]
    front = [0.0, 0.0, -R]

    # a pure function
    a = make("fur_rub", rub(secs, back, 0.12, 1.0))
    b = contact.render(rub(secs, back, 0.12, 1.0))
    c = contact.render(rub(secs, back, 0.12, 1.0, seed=2))
    ok(np.array_equal(a, b), "the same lanes and seed are the same samples")
    ok(not np.allclose(a, c), "another seed is other samples (the control)")

    # faster: brighter and louder
    slow = make("fur_slow", rub(secs, back, 0.05, 1.0))
    quick = make("fur_quick", rub(secs, back, 0.3, 1.0))
    ok(db(mid(quick, secs)) > db(mid(slow, secs)) + 4.0,
       "fur rubbed at 0.3 m/s is louder than at 0.05 (%.1f against %.1f dB)" % (db(mid(quick, secs)), db(mid(slow, secs))))
    ok(centroid(mid(quick, secs)) > centroid(mid(slow, secs)) * 1.3,
       "...and brighter (%.0f against %.0f Hz)" % (centroid(mid(quick, secs)), centroid(mid(slow, secs))))
    block = {"shape": "bar", "size": [0.1, 0.06, 0.025], "material": "wood"}
    sc_slow = make("scrape_slow", rub(secs, [0.0, -0.05, 0.12], 0.04, 1.0, "scrape", "wood", "wood", block))
    sc_quick = make("scrape_quick", rub(secs, [0.0, -0.05, 0.12], 0.25, 1.0, "scrape", "wood", "wood", block))
    ok(centroid(mid(sc_quick, secs)) > centroid(mid(sc_slow, secs)) * 1.2,
       "a block scraped quick is brighter than slow (%.0f against %.0f Hz)" % (centroid(mid(sc_quick, secs)), centroid(mid(sc_slow, secs))))
    ok(db(mid(sc_quick, secs)) > db(mid(sc_slow, secs)) + 3.0, "...and louder")
    # harder: louder
    soft = make("scrape_soft", rub(secs, [0.0, -0.05, 0.12], 0.12, 0.5, "scrape", "wood", "wood", block))
    firm = make("scrape_firm", rub(secs, [0.0, -0.05, 0.12], 0.12, 3.0, "scrape", "wood", "wood", block))
    ok(db(mid(firm, secs)) > db(mid(soft, secs)) + 3.0,
       "the same scrape at 3 N is louder than at 0.5 N (%.1f against %.1f dB)" % (db(mid(firm, secs)), db(mid(soft, secs))))

    # the side heard
    lft = make("fur_left", rub(secs, left, 0.12, 1.0))
    rgt = make("fur_right", rub(secs, right, 0.12, 1.0))
    ml, mr = mid(lft, secs), mid(rgt, secs)
    ok(db(ml[0:1]) > db(ml[1:2]) + 6.0, "a rub on the left is louder in the left ear (%.1f against %.1f dB)" % (db(ml[0:1]), db(ml[1:2])))
    ok(db(mr[1:2]) > db(mr[0:1]) + 6.0, "...and one on the right in the right ear (the control)")
    tap_l = make("tap_left", {"secs": 0.6, "tail": 0.2, "seed": 1, "lane_rate": LR, "contacts": [],
                              "hits": [{"t": 0.1, "speed": 0.4, "on": "fur", "by": "skin", "at": left}]})
    ok(onset_lag(tap_l) > 5, "a tap on the left reaches the left ear first (by %d samples)" % onset_lag(tap_l))
    bk = make("fur_back", rub(secs, back, 0.12, 1.0))
    fr = make("fur_front", rub(secs, front, 0.12, 1.0))
    ok(centroid(mid(bk, secs)) < centroid(mid(fr, secs)) * 0.95,
       "behind (toward the viewer) is darker than in front (%.0f against %.0f Hz)" % (centroid(mid(bk, secs)), centroid(mid(fr, secs))))

    # near is louder, a fingertip darker than a nail
    shell = {"shape": "shell", "size": [0.13, 0.09, 0.08], "material": "plastic"}
    tube = {"shape": "tube", "size": [0.12, 0.06, 0.06], "material": "metal"}
    hit = lambda at, by, body: {"secs": 0.8, "tail": 0.6, "seed": 1, "lane_rate": LR, "contacts": [],
                               "hits": [{"t": 0.05, "speed": 0.35, "on": body["material"], "by": by, "at": at, "body": body}]}
    far_tap = make("tap_camera_far", hit([0.0, 0.16, -0.85], "nail", shell))
    near_tap = make("tap_mic_body", hit([0.0, -0.14, 0.03], "nail", tube))
    ok(db(near_tap) > db(far_tap) + 6.0, "a tap on the microphone's body is louder than one on the camera across the room "
       "(%.1f against %.1f dB)" % (db(near_tap), db(far_tap)))
    finger = make("tap_shell_finger", hit([0.0, 0.0, -0.2], "skin", shell))
    nail = make("tap_shell_nail", hit([0.0, 0.0, -0.2], "nail", shell))
    ok(centroid(finger) < centroid(nail) * 0.8, "a fingertip's tap is darker than a nail's (%.0f against %.0f Hz)" % (centroid(finger), centroid(nail)))

    # stick-slip: the creak's slips, periodic at speed / SLIP_STEP
    def periodic_at(x: np.ndarray, hz: float) -> float:
        """How far the envelope's power round `hz` (within a tenth: a creak's slips jitter) stands over the bands either
        side of it (between its harmonics)."""
        env = np.abs(x.mean(axis=0)).reshape(-1, 44).mean(axis=1)   # a 1 kHz envelope
        env = env - env.mean()
        spec = np.abs(np.fft.rfft(env * np.hanning(env.size))) ** 2
        f = np.fft.rfftfreq(env.size, 44 / contact.RATE)
        at = spec[np.abs(f - hz) < 0.1 * hz].mean()
        beside = spec[((f > 0.55 * hz) & (f < 0.75 * hz)) | ((f > 1.3 * hz) & (f < 1.5 * hz))].mean()
        return float(at / (beside + 1e-18))
    v_slow = 0.012
    creak = make("scrape_creak", rub(4.0, [0.0, -0.05, 0.12], v_slow, 3.5, "scrape", "wood", "wood", block, wobble=0.0))
    hz = v_slow / contact.SLIP_STEP
    cm = mid(creak, 4.0)
    cm = cm[:, : cm.shape[1] // 44 * 44]
    qm = mid(sc_quick, secs)
    qm = qm[:, : qm.shape[1] // 44 * 44]
    ok(periodic_at(cm, hz) > 3.0, "a slow, hard scrape creaks: slips every %.2f mm, %.0f a second (peak %.1f over the floor)"
       % (contact.SLIP_STEP * 1000, hz, periodic_at(cm, hz)))
    ok(periodic_at(qm, hz) < periodic_at(cm, hz) * 0.5, "...a quick one does not (the control)")

    # nothing clips, the edges never click
    loud = make("fur_hard", rub(secs, left, 0.6, 6.0))
    ok(float(np.abs(loud).max()) <= contact.CEILING + 1e-6, "a hard, quick rub stays under the ceiling (%.3f)" % float(np.abs(loud).max()))
    ok(all(float(np.abs(x[:, :3]).max()) < 1e-3 and float(np.abs(x[:, -3:]).max()) < 1e-3 for x in made.values()),
       "every sound begins and ends at silence")

    # the studio's acts name only what the host knows (StudioActs.SOUND_MATERIALS, held to MATERIALS)
    import re
    acts_gd = (HERE.parent.parent / "src" / "studio" / "studio_acts.gd").read_text()
    m = re.search(r"const SOUND_MATERIALS := \[([^\]]*)\]", acts_gd)
    named = re.findall(r'"([a-z]+)"', m.group(1)) if m else []
    ok(sorted(named) == sorted(contact.MATERIALS), "StudioActs.SOUND_MATERIALS is contact.py's MATERIALS (%s)" % ", ".join(named))

    # refused, and written
    ok("secs" in contact.check({"secs": 0.0}), "no seconds is refused, saying so")
    bad = rub(1.0, back, 0.1, 1.0)
    bad["contacts"][0]["on"] = "cheese"
    ok("cheese" in contact.check(bad), "an unknown material is refused, naming it")
    with tempfile.TemporaryDirectory() as d:
        spec = rub(1.0, back, 0.1, 1.0)
        spec["out"] = str(Path(d) / "a.wav")
        spec["done"] = str(Path(d) / "a.done.json")
        sp = Path(d) / "a.spec.json"
        sp.write_text(json.dumps(spec))
        subprocess.run([sys.executable, "-I", str(HERE / "contact.py"), str(sp)], check=False, capture_output=True)
        res = json.loads(Path(spec["done"]).read_text()) if Path(spec["done"]).exists() else {}
        ok(bool(res.get("ok")) and Path(spec["out"]).exists() and res.get("heard", {}).get("frames"),
           "contact.py writes the WAV and the done file, its heard numbers in it")

    # the levels, for the ear and the voice beside them (it speaks at about -24 dB)
    for name, x in made.items():
        print("      %-18s rms %6.1f dB  peak %6.1f dB  bright %5.0f Hz" % (name, db(x), 20 * np.log10(np.abs(x).max() + 1e-12), centroid(x)))
    if demo:
        demo.mkdir(parents=True, exist_ok=True)
        for name, x in made.items():
            contact.write_wav(str(demo / (name + ".wav")), x)
        print("wrote %d sounds to %s" % (len(made), demo))
    print("FAILED %d" % FAILS if FAILS else "all held")
    return 1 if FAILS else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
