#!/usr/bin/env python3
"""contact.py - the sound a thing makes, made by the motion that makes it (next/studio.md, "The sound").

    contact.py <spec.json>

The spec, never argv: {"secs", "tail", "seed", "lane_rate", "contacts", "hits", "out", "done"} - writes a 44.1 kHz stereo
WAV at `out` and, when finished, `done`: {"ok", "wav", "seconds", "heard"} or {"ok": false, "error"}. A pure function of
the spec: the same lanes and seed are the same samples.

A CONTACT is one thing sliding on another for the whole act: {"kind", "on", "by", "lanes", "body"} - `kind` rub
(fingertips), brush (bristles), scratch (nails), scrape (a rigid thing on another) or cup (a hand closed round it);
`on` and `by` materials (MATERIALS); `lanes` {x, y, z, speed, force}, one value each `1 / lane_rate` seconds: where the
contact is round the microphone (meters: x to the viewer's right, y up, z toward the viewer; the capsule at 0), how fast
it slides (m/s) and how hard it presses (N); `body` what rings, {shape, size [x, y, z] m, material} (BODIES), or none.
A HIT is one strike: {"t", "speed" m/s, "on", "by", "at" [x, y, z], "body", "handling"} - `handling` true for a strike on
the microphone itself, heard through its body as well as the air. A contact's or a hit's `body2` is the other
body where both ring (a block on a block).

What each sounds like, from the motion (van den Doel, Kry and Pai, "FoleyAutomatic", 2001; Conan et al., Computer Music
Journal 2014; Farnell, "Designing Sound", 2010):

- FUR (a windscreen over the capsule): a pressure rumble where it is pushed toward the capsule, from the change in force
  (20-150 Hz, near the capsule and so loud); a swish whose band rises with the speed; a deep drag under it; fiber crackle,
  micro-clicks at a rate the speed sets, heavy-tailed in loudness and brighter as it goes faster. A brush adds its tips'
  airy swish; nails make the crackle dense and bright.
- A HARD SURFACE rubbed, brushed or scratched: its grain read at the sliding speed - a band of noise between speed / coarse
  and speed / grain, so it sounds higher as it goes faster and louder as it presses harder - softened by a soft tool (a
  fingertip's pulp, its ridges passing), crackling where a nail or a bristle catches, ringing the body under it.
- A SCRAPE: the same grain, with coarse bumps read from a profile along the way it has slid (going back over a place
  sounds it again), and stick-slip where it is slow and pressed hard - slips at speed / SLIP_STEP, a creak - every bit of
  it ringing both bodies' modes, damped by the hands.
- A HIT: a contact pulse as long as the softer material makes it (a fingertip several milliseconds, a nail or wood on wood
  a fraction of one), its spectrum falling past one over that; the near-field pressure of the body stopping (a deep thud
  close to the capsule) and both bodies' modes.

WHERE IT IS HEARD: a spherical head of radius HEAD at the capsule, turned as the viewer is. Each ear's own distance (so a
sound a few centimeters from one ear is far louder there); the far ear's head shadow (Brown and Duda, "A structural model
for binaural sound synthesis", 1998: one pole and one zero, alpha by the angle); the path round the head as a moving
fractional delay (cubic), so its Doppler comes free; darker from behind (toward the viewer); a pinna notch that rises with
height; and the capsule's proximity bass, more the nearer it is. Then the microphone's color (presence and air), a small
dry room and a soft limiter. LEVELS ARE ABSOLUTE (GAIN): a sound far from the capsule is quiet, never normalized.

THE HEARD NUMBERS (`heard`): `frames` every FRAME seconds - loudness each ear (dBFS), the balance (left minus right, dB) and
brightness (spectral centroid, Hz); `peak_db`; `seconds`.
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
from scipy import signal  # noqa: E402

import dsp  # noqa: E402

RATE = 44100
# The loudest sample (full scale) the limiter lets through.
CEILING = 0.89
# What a spec may ask: the longest act (s), its tail, the most contacts and hits, the slowest and quickest lanes.
LONGEST = 180.0
TAIL_MOST = 6.0
CONTACTS_MOST = 8
HITS_MOST = 4000
LANE_RATES = (50.0, 2000.0)
KINDS = ("rub", "brush", "scratch", "scrape", "cup")
# The speed of sound (m/s), the head's radius (m), the nearest an ear is ever taken to be (m) and the distance heard at
# its own level (m).
SOUND_SPEED = 343.0
HEAD = 0.0875
EAR_NEAREST = 0.035
EAR_REF = 0.1
# Brown and Duda's head shadow: the least alpha (the far ear's highs), at this angle from the ear (degrees).
ALPHA_LEAST = 0.1
THETA_LEAST = 150.0
# How much darker a sound wholly behind the head is above BACK_HZ (share of the highs taken), and the pinna notch's depth
# and its band (Hz, low to high as the sound rises).
BACK_DARK = 0.55
BACK_HZ = 3800.0
NOTCH_DEPTH = 0.45
NOTCH_HZ = (6200.0, 10500.0)
# The capsule's proximity bass: a cardioid's sqrt(1 + 1/(2kr)^2) at PROX_AT Hz, lifted under PROX_HZ, at most PROX_MOST
# times (about +9 dB at 10 cm, +15 dB at 5 cm).
PROX_AT = 120.0
PROX_HZ = 220.0
PROX_MOST = 4.5
# The whole sound's level: a fingertip rubbing the fur at a brisk 0.12 m/s and 1 N is heard about 18 dB under full scale.
GAIN = 0.25
# Each act is pressed a little, as an ASMR mix is (dsp.compress): above this level (dBFS), by this ratio.
SQUEEZE_DB = -20.0
SQUEEZE = 2.0
# A scrape's rasp: its wood fibers caught every RASP_STEP meters slid, heard between these (Hz).
RASP_STEP = 0.0001
RASP_HZ = (900.0, 6500.0)
# The heard numbers' frame (s).
FRAME = 0.1
# A hit's parts, for a pulse of unit area: the near-field thud of the body stopping, a hard edge's click, and its modes.
THUD = 60.0
CLICK = 26.0
RING = 7.0
# A strike on the microphone itself (`handling`): carried through its body into the capsule, a deep thump in both ears.
HANDLING = 14.0
# A contact's reference speed (m/s) and force (N): what its levels are written against.
V0 = 0.1
F0 = 1.0
# Stick-slip: below this speed (m/s) and above this force (N) a scrape catches, slipping every SLIP_STEP meters.
SLIP_SPEED = 0.035
SLIP_FORCE = 1.2
SLIP_STEP = 0.00035

# What things are made of. `pulse` the contact time a hit on itself takes (s: the softer, the longer); `grain` its finest
# texture (m) and `coarse` its bumps (m); `rough` how loud its grain is (a share); `E` and `rho` (Pa, kg/m3) its stiffness
# and density, `loss` its loss factor (what rings long rings low loss); `soft` a thing that does not ring.
MATERIALS = {
    "wood": {"label": "Wood", "blurb": "Hardwood: a dry, quick knock, its grain a soft rasp that rises as it slides faster.",
             "pulse": 0.00045, "grain": 0.000025, "coarse": 0.003, "rough": 1.0, "E": 12e9, "rho": 700.0, "loss": 0.008},
    "plastic": {"label": "Plastic", "blurb": "Hard plastic, a hollow body's shell: a tok, a smooth hiss when rubbed.",
                "pulse": 0.0007, "grain": 0.000012, "coarse": 0.004, "rough": 0.45, "E": 2.3e9, "rho": 1050.0, "loss": 0.03},
    "metal": {"label": "Metal", "blurb": "Cast metal: rings long and high, its surface nearly smooth.",
              "pulse": 0.0003, "grain": 0.000008, "coarse": 0.005, "rough": 0.3, "E": 70e9, "rho": 2700.0, "loss": 0.0025},
    "glass": {"label": "Glass", "blurb": "Glass: the smoothest, a squeak under a fingertip, a clink when struck.",
              "pulse": 0.00022, "grain": 0.000004, "coarse": 0.006, "rough": 0.15, "E": 65e9, "rho": 2500.0, "loss": 0.002},
    "fur": {"label": "Fur", "blurb": "A fur windscreen over the capsule: rumble, swish and crackle, never a ring.",
            "pulse": 0.012, "grain": 0.0, "coarse": 0.0, "rough": 0.0, "E": 0.0, "rho": 0.0, "loss": 1.0, "soft": True},
    "skin": {"label": "Fingertip", "blurb": "A fingertip's pulp: soft, its ridges passing every half millimeter.",
             "pulse": 0.007, "grain": 0.00045, "coarse": 0.0, "rough": 0.0, "E": 0.0, "rho": 0.0, "loss": 1.0, "soft": True},
    "nail": {"label": "Fingernail", "blurb": "A fingernail's edge: hard and thin, a click and a bright scratch.",
             "pulse": 0.0006, "grain": 0.0, "coarse": 0.0, "rough": 0.0, "E": 0.0, "rho": 0.0, "loss": 1.0, "soft": True},
    "bristle": {"label": "Bristles", "blurb": "A soft brush's bristles: tips catching and slipping, an airy swish.",
                "pulse": 0.004, "grain": 0.0, "coarse": 0.0, "rough": 0.0, "E": 0.0, "rho": 0.0, "loss": 1.0, "soft": True},
}
# What a body rings as: its modes from its shape, size and material.
BODIES = {
    "bar": {"label": "Bar", "blurb": "A solid block or stick, free: its bending modes along its length and across it."},
    "shell": {"label": "Shell", "blurb": "A hollow box's walls (a camera's body): plate modes, low and many."},
    "tube": {"label": "Tube", "blurb": "A hollow cylinder (a microphone's body, a lens barrel): ring modes, few and long."},
}
# Each tool's way with fur: its contact's width (m), its crackle's rate at V0 (clicks a second), its crackle's band (Hz,
# low and high), and how much rumble, swish and air it makes (shares).
FUR_TOOLS = {
    "skin": {"width": 0.016, "crackle": 900.0, "band": (2400.0, 7500.0), "rumble": 1.0, "swish": 1.0, "air": 0.15},
    "bristle": {"width": 0.022, "crackle": 3000.0, "band": (3000.0, 8500.0), "rumble": 0.5, "swish": 1.0, "air": 0.3},
    "nail": {"width": 0.008, "crackle": 2200.0, "band": (3600.0, 9500.0), "rumble": 0.6, "swish": 0.5, "air": 0.15},
}


# --- the spec ---------------------------------------------------------------------------------------------------------

def check(spec: dict) -> str:
    """Why `spec` cannot be made, "" where it can."""
    secs = float(spec.get("secs", 0.0))
    if not (0.05 <= secs <= LONGEST):
        return "secs %.2f is outside 0.05-%g" % (secs, LONGEST)
    if not (0.0 <= float(spec.get("tail", 0.0)) <= TAIL_MOST):
        return "tail is outside 0-%g" % TAIL_MOST
    lr = float(spec.get("lane_rate", 300.0))
    if not (LANE_RATES[0] <= lr <= LANE_RATES[1]):
        return "lane_rate %g is outside %g-%g" % (lr, *LANE_RATES)
    contacts = spec.get("contacts", [])
    hits = spec.get("hits", [])
    if len(contacts) > CONTACTS_MOST:
        return "more than %d contacts" % CONTACTS_MOST
    if len(hits) > HITS_MOST:
        return "more than %d hits" % HITS_MOST
    for i, c in enumerate(contacts):
        if c.get("kind") not in KINDS:
            return "contact %d: no kind %r (%s)" % (i, c.get("kind"), ", ".join(KINDS))
        for side in ("on", "by"):
            if c.get(side) not in MATERIALS:
                return "contact %d: no material %r" % (i, c.get(side))
        lanes = c.get("lanes", {})
        for k in ("x", "y", "z", "speed", "force"):
            if not isinstance(lanes.get(k), list) or not lanes[k]:
                return "contact %d: lane %s is missing" % (i, k)
        why = _check_body(c.get("body")) or _check_body(c.get("body2"))
        if why:
            return "contact %d: %s" % (i, why)
    for i, h in enumerate(hits):
        for side in ("on", "by"):
            if h.get(side) not in MATERIALS:
                return "hit %d: no material %r" % (i, h.get(side))
        why = _check_body(h.get("body")) or _check_body(h.get("body2"))
        if why:
            return "hit %d: %s" % (i, why)
    return ""


def _check_body(b) -> str:
    if b is None:
        return ""
    if b.get("shape") not in BODIES:
        return "no body shape %r" % b.get("shape")
    if b.get("material") not in MATERIALS or MATERIALS[b["material"]].get("soft"):
        return "a body of %r does not ring" % b.get("material")
    size = b.get("size", [])
    if len(size) != 3 or min(float(s) for s in size) <= 0.0 or max(float(s) for s in size) > 2.0:
        return "a body's size is three lengths in meters"
    return ""


def lanes_of(c: dict, n: int, lane_rate: float) -> dict:
    """A contact's lanes a sample each over n samples, eased (never a step a lane's jump would make), speed and force
    never below 0."""
    out = {}
    t = np.arange(n) / RATE
    for k in ("x", "y", "z", "speed", "force"):
        v = np.asarray(c["lanes"][k], dtype=float)
        v = np.nan_to_num(v, nan=0.0, posinf=0.0, neginf=0.0)
        tl = np.arange(v.size) / lane_rate
        u = np.interp(t, tl, v)
        # zero-phase easing at a third of the lanes' rate: a lane's corner is never a click
        b, a = signal.butter(2, min(lane_rate / 3.0, RATE * 0.4) / (RATE * 0.5))
        u = signal.filtfilt(b, a, u) if n > 30 else u
        out[k] = u
    out["speed"] = np.clip(out["speed"], 0.0, 4.0)
    out["force"] = np.clip(out["force"], 0.0, 40.0)
    return out


# --- what rings -------------------------------------------------------------------------------------------------------

def modes_of(body: dict | None, rng: np.random.Generator, held: bool = True) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """A body's modes: (Hz, seconds to -60 dB, level), at most 10, those past hearing dropped. Held in a hand, it dies
    away quicker. A seeded detune keeps two of the same thing from being one sound."""
    if not body:
        return np.zeros(0), np.zeros(0), np.zeros(0)
    m = MATERIALS[body["material"]]
    sx, sy, sz = sorted(float(s) for s in body["size"])[::-1]   # longest first
    E, rho, loss = m["E"], m["rho"], m["loss"] * (2.2 if held else 1.0)
    shape = body["shape"]
    f = []
    if shape == "bar":
        beta = [4.730, 7.853, 10.996, 14.137, 17.279]
        for L, h, k in ((sx, sz, 1.0), (sx, sy, 0.55), (sy, sz, 0.4)):
            c = np.sqrt(E * h * h / (12.0 * rho * L ** 4))
            for i, bl in enumerate(beta):
                f.append((bl * bl / (2.0 * np.pi) * c, k / (1.0 + 0.6 * i)))
    elif shape == "shell":
        wall = max(0.0015, min(sz * 0.04, 0.004))
        D = E * wall ** 3 / (12.0 * (1.0 - 0.35 ** 2))
        c = np.pi / 2.0 * np.sqrt(D / (rho * wall))
        for (a, b, k) in ((sx, sy, 1.0), (sx, sz, 0.7), (sy, sz, 0.5)):
            for mm in (1, 2, 3):
                for nn in (1, 2):
                    f.append((c * ((mm / a) ** 2 + (nn / b) ** 2), k / (mm * nn) ** 0.7))
    else:  # tube: ring modes of a thin cylinder of radius half its girth
        r = max(sy, sz) * 0.5
        wall = max(0.001, r * 0.06)
        cl = np.sqrt(E / (12.0 * rho * (1.0 - 0.33 ** 2)))
        for nn in range(2, 7):
            f.append((wall / (r * r) * cl * nn * (nn * nn - 1) / np.sqrt(nn * nn + 1) / (2.0 * np.pi), 1.0 / (nn - 1)))
        L = sx
        for i, bl in enumerate([4.730, 7.853]):
            f.append((bl * bl / (2.0 * np.pi) * np.sqrt(E * (r * r / 2.0) / (rho * L ** 4)), 0.5 / (1 + i)))
    f = [(hz * (1.0 + 0.03 * rng.standard_normal()), g) for hz, g in f if 40.0 < hz < RATE * 0.42]
    f.sort(key=lambda p: -p[1])
    f = f[:10]
    if not f:
        return np.zeros(0), np.zeros(0), np.zeros(0)
    hz = np.array([p[0] for p in f])
    lv = np.array([p[1] for p in f])
    t60 = np.clip(2.2 / (np.pi * hz * loss), 0.004, 2.5)
    return hz, t60, lv / np.sqrt(np.sum(lv * lv))


def ring(x: np.ndarray, modes: tuple, struck: bool = False) -> np.ndarray:
    """`x` driving a body's modes, each a two-pole resonator. STRUCK, a pulse of unit area rings each mode at its level,
    however long it rings (a strike gives a mode its speed, whatever its damping); else (a rub, a scrape) each is
    driven as noise drives it, its build-up at resonance taken out, so a long-ringing body hums rather than howls."""
    hz, t60, lv = modes
    out = np.zeros_like(x)
    for f, d, g in zip(hz, t60, lv):
        r = np.exp(-6.91 / (d * RATE))
        w = 2.0 * np.pi * f / RATE
        b0 = np.sin(w) if struck else np.sin(w) * np.sqrt(2.0 * (1.0 - r))
        out += g * signal.lfilter([b0], [1.0, -2.0 * r * np.cos(w), r * r], x)
    return out


# --- the excitations --------------------------------------------------------------------------------------------------

def band(x: np.ndarray, lo, hi) -> np.ndarray:
    """`x` between two cutoffs, either of which may move (a sample each)."""
    return dsp.lowpass(x, hi, rate=RATE) - dsp.lowpass(x, lo, rate=RATE)


def clicks(rate_: np.ndarray, rng: np.random.Generator, tail: float = 2.4) -> np.ndarray:
    """Clicks at a rate a sample each (a second), placed at random: a Poisson stream, each click's level heavy-tailed
    (a few loud among many quiet, as fibers and grit are) and either sign."""
    p = np.clip(rate_ / RATE, 0.0, 0.6)
    hit = rng.random(p.size) < p
    out = np.zeros(p.size)
    k = int(np.count_nonzero(hit))
    if k:
        out[hit] = np.minimum(rng.pareto(tail, k) + 1.0, 9.0) * np.where(rng.random(k) < 0.5, -1.0, 1.0)
    return out


def grain_noise(v: np.ndarray, F: np.ndarray, m: dict, soft_by: float, rng: np.random.Generator) -> np.ndarray:
    """A surface's grain read at sliding speed `v` under force `F`: noise between speed / coarse and speed / grain (a
    fractal surface heard as a band that slides up with the speed), louder as it goes faster and presses harder, its top
    cut where a soft tool smooths it (`soft_by`, m: 0 a hard edge)."""
    n = v.size
    lo = np.clip(v / max(m["coarse"], 1e-4), 30.0, 4000.0)
    top = v / max(m["grain"], 1e-6)
    if soft_by > 0.0:
        top = np.minimum(top, 900.0 + v / soft_by * 0.6)
    hi = np.clip(top, lo * 1.5, RATE * 0.42)
    x = band(dsp.noise(n, rng, "pink"), lo, hi)
    lvl = m["rough"] * np.sqrt((v / V0) * (F / F0))   # FoleyAutomatic: as the square root of speed times force
    return x * lvl


def coarse_bumps(travel: np.ndarray, m: dict, rng: np.random.Generator) -> np.ndarray:
    """The coarse bumps along the way slid (a profile a quarter millimeter a step, read where the contact is): the same
    place slid over again sounds again. A share round 1."""
    span = float(travel.max() - travel.min()) + 0.01
    step = 0.00025
    k = int(span / step) + 8
    prof = dsp.onepole(rng.standard_normal(k), 0.12, rate=1)  # smoothed over a few steps
    prof = prof / (np.std(prof) + 1e-9)
    pos = (travel - travel.min()) / step
    return 1.0 + 0.45 * np.interp(pos, np.arange(k), prof)


def fur(lanes: dict, by: str, rng: np.random.Generator) -> np.ndarray:
    """A tool on the fur windscreen: rumble, drag, swish, crackle and air, as the header says."""
    tool = FUR_TOOLS.get(by, FUR_TOOLS["skin"])
    v, F = lanes["speed"], lanes["force"]
    n = v.size
    touching = np.clip(F / 0.05, 0.0, 1.0)
    vr = v / V0
    # the press toward the capsule: its change in force (N/s), and a turbulence the drag makes
    dF = np.gradient(F) * RATE
    turb = dsp.onepole(rng.standard_normal(n), 60.0, RATE) * F * np.sqrt(vr + 0.02)
    rumble = dsp.butter(dsp.butter(0.012 * dF + 0.9 * turb, "lowpass", 150.0, 2, RATE), "highpass", 22.0, 2, RATE)
    # the deep drag: brown-ish noise low under the swish, its band up with the speed
    drag_hi = np.clip(260.0 * (vr + 0.05) ** 0.45, 120.0, 900.0)
    drag = dsp.lowpass(dsp.onepole(rng.standard_normal(n), 200.0, RATE), drag_hi, rate=RATE) * 2.2
    drag *= F ** 0.6 * vr ** 0.8
    # the swish: a band round fc, rising with the speed
    fc = np.clip(700.0 * (vr + 0.02) ** 0.55, 180.0, 7000.0)
    swish = band(dsp.noise(n, rng, "pink"), fc / 1.9, fc * 1.9) * (vr ** 0.95) * (F / F0 + 0.15) ** 0.4
    # the fibers' crackle: rate from the speed, its band brighter faster
    lam = tool["crackle"] * vr * (tool["width"] / 0.016) * np.sqrt(F / F0 + 0.05) * touching
    imp = clicks(lam, rng)
    bright = np.clip(vr / 2.5, 0.0, 1.0)
    lo_band = dsp.butter(imp, "bandpass", (tool["band"][0] * 0.6, tool["band"][0] * 1.6), 2, RATE)
    hi_band = dsp.butter(imp, "bandpass", (tool["band"][1] * 0.55, min(tool["band"][1] * 1.3, RATE * 0.45)), 2, RATE)
    crackle = ((1.0 - bright) * lo_band + bright * hi_band) * (0.6 + 0.4 * vr ** 0.3) * 0.11
    # a brush's tips in the air: high, airy, with the square of the speed
    air = dsp.butter(dsp.noise(n, rng), "bandpass", (2500.0, 11000.0), 2, RATE) * np.minimum(vr * vr, 6.0) * 0.08
    out = (tool["rumble"] * rumble * 1.4 + 0.5 * drag * tool["rumble"] + tool["swish"] * swish * 0.55
           + crackle + tool["air"] * air * touching)
    # the fur itself takes the very top off: what reaches the capsule through it is soft
    return dsp.butter(out * touching, "lowpass", 10500.0, 2, RATE)


def hard(lanes: dict, kind: str, on: str, by: str, rng: np.random.Generator) -> np.ndarray:
    """A tool on a hard surface (rub, brush, scratch), before the body under it rings."""
    m = MATERIALS[on]
    v, F = lanes["speed"], lanes["force"]
    n = v.size
    touching = np.clip(F / 0.05, 0.0, 1.0)
    vr = v / V0
    if kind == "rub":
        # a fingertip's pulp smooths the grain; its ridges pass every half millimeter, a low buzz under it
        x = grain_noise(v, F, m, MATERIALS["skin"]["grain"], rng) * 0.6
        ridge_hz = v / MATERIALS["skin"]["grain"]
        ph = np.cumsum(ridge_hz) / RATE
        buzz = dsp.lowpass(dsp.noise(n, rng, "pink"), np.clip(ridge_hz * 4.0 + 300.0, 300.0, 6000.0), rate=RATE)
        x += buzz * (0.55 + 0.45 * np.sin(2.0 * np.pi * ph)) * 0.35 * vr ** 0.8 * (F / F0) ** 0.5 * (1.2 - m["rough"])
        # a smooth surface squeaks under a slow, firm fingertip
        if m["rough"] < 0.35:
            sq = np.clip((F - 0.8) / 1.5, 0.0, 1.0) * np.clip(1.0 - v / 0.08, 0.0, 1.0)
            x += np.sin(2.0 * np.pi * np.cumsum(500.0 + 9000.0 * v) / RATE) * sq * 0.05
    elif kind == "brush":
        lam = 3200.0 * vr * np.sqrt(F / F0 + 0.05)
        imp = clicks(lam, rng, 2.8)
        x = dsp.butter(imp, "bandpass", (5000.0, 15000.0), 2, RATE) * 0.07 * (0.5 + 0.5 * vr ** 0.4)
        x += dsp.butter(dsp.noise(n, rng), "bandpass", (3000.0, 12000.0), 2, RATE) * np.minimum(vr * vr, 6.0) * 0.05
        x += grain_noise(v, F, m, 0.0, rng) * 0.08
    else:  # scratch: a nail's hard edge reads every bit of the grain, and catches on it
        x = grain_noise(v, F, m, 0.0, rng) * 0.8
        lam = v / max(m["grain"] * 6.0, 1e-5) * 0.25
        imp = clicks(np.minimum(lam, 6000.0), rng)
        x += dsp.butter(imp, "highpass", 2500.0, 2, RATE) * 0.05 * (F / F0) ** 0.5
    return x * touching


def scrape(lanes: dict, on: str, by: str, rng: np.random.Generator) -> np.ndarray:
    """One rigid thing slid on another: grain, coarse bumps along the way slid, stick-slip where it is slow and pressed."""
    m_on, m_by = MATERIALS[on], MATERIALS[by]
    v, F = lanes["speed"], lanes["force"]
    touching = np.clip(F / 0.05, 0.0, 1.0)
    travel = np.cumsum(v) / RATE
    rough = dict(m_on)
    rough["rough"] = 0.5 * (m_on["rough"] + m_by.get("rough", 0.0))
    x = grain_noise(v, F, rough, 0.0, rng) * coarse_bumps(travel, m_on, rng)
    # the rasp: fibers caught one by one, as many a second as are slid over (Conan et al.'s impact series)
    lam = v / RASP_STEP * 0.5 * touching
    x += dsp.butter(clicks(np.minimum(lam, 8000.0), rng), "bandpass", RASP_HZ, 2, RATE) * 0.05 * (F / F0) ** 0.5 * rough["rough"]
    # stick-slip: while slow and pressed it sticks (no sliding, so no grain heard) and slips each SLIP_STEP slid (a step
    # jittered as it goes) - a creak, each slip a quick release through the hand, low and woody, ringing the block
    catch = np.clip((F - SLIP_FORCE) / 2.0, 0.0, 1.0) * np.clip(1.0 - v / SLIP_SPEED, 0.0, 1.0) * touching
    if np.any(catch > 0.0):
        x *= 1.0 - 0.95 * catch
        jitter = 1.0 + 0.06 * dsp.onepole(rng.standard_normal(v.size), 4.0, RATE) / 0.017
        phase = np.cumsum(v / (SLIP_STEP * np.clip(jitter, 0.7, 1.3))) / RATE
        slip = np.zeros_like(v)
        slip[1:] = (np.diff(np.floor(phase)) != 0).astype(float)
        kick = slip * catch * F * (0.8 + 0.4 * rng.random(v.size))
        groan = dsp.lowpass(kick, 650.0, q=3.0, rate=RATE) * 4.5
        snap = dsp.butter(kick, "bandpass", (1500.0, 5000.0), 2, RATE) * 0.6
        x += groan + snap
    return x * touching


def cup(lanes: dict, rng: np.random.Generator) -> np.ndarray:
    """A hand closed round the fur: mostly the press toward the capsule, a big soft drag, little crackle."""
    l2 = dict(lanes)
    out = fur(l2, "skin", rng)
    dF = np.gradient(lanes["force"]) * RATE
    whump = dsp.butter(dsp.butter(0.03 * dF, "lowpass", 110.0, 2, RATE), "highpass", 20.0, 2, RATE)
    return out * 0.8 + whump


def hit_sound(h: dict, rng: np.random.Generator) -> tuple[np.ndarray, int]:
    """One strike, mono, and the sample it begins at: the contact pulse, the near-field thud of the body stopping, and
    what it rings."""
    on, by = MATERIALS[h["on"]], MATERIALS[h["by"]]
    tau = float(np.sqrt(on["pulse"] ** 2 + by["pulse"] ** 2))
    speed = float(np.clip(h.get("speed", 0.2), 0.0, 4.0))
    amp = (speed / 0.3) ** 1.2   # Hertzian: a quicker strike gives a little more than its speed
    t0 = float(h["t"])
    start = int(np.floor(t0 * RATE))
    frac = t0 * RATE - start
    n_pulse = int(np.ceil(tau * RATE)) + 2
    tt = (np.arange(n_pulse) - frac) / RATE
    # a pulse of unit area (in samples): the same momentum given over a shorter time is a taller, brighter pulse
    pulse = np.where((tt >= 0.0) & (tt <= tau), np.sin(np.pi * np.clip(tt / tau, 0.0, 1.0)), 0.0)
    pulse *= np.pi / (2.0 * tau * RATE)
    modes = modes_of(h.get("body"), rng)
    ring_s = float(max(modes[1].max() if modes[1].size else 0.0, 0.0))
    n = n_pulse + int((min(ring_s, 2.5) + 0.06) * RATE)
    x = np.zeros(n)
    x[:n_pulse] = pulse
    out = np.zeros(n)
    # the body stopping, heard close: the pulse itself, its lowest lows taken off
    out += dsp.butter(x, "highpass", 45.0, 2, RATE) * THUD
    # a hard edge clicks
    if tau < 0.0012:
        out += dsp.butter(x, "highpass", 3000.0, 2, RATE) * CLICK
    if modes[0].size:
        out += ring(x, modes, struck=True) * RING
    # the striker rings too where it is a body of its own (one block knocked on another)
    if h.get("body2"):
        out += ring(x, modes_of(h["body2"], rng), struck=True) * RING * 0.8
    if h["on"] == "fur":
        # a tap on the fur: a soft thump of air pushed at the capsule, and a few fibers
        thump = dsp.butter(x, "lowpass", 160.0, 2, RATE) * THUD * 2.5
        out = thump + dsp.butter(clicks(np.full(n, 3000.0) * np.exp(-np.arange(n) / (0.02 * RATE)), rng),
                                 "bandpass", (3000.0, 9000.0), 2, RATE) * 0.04
    return out * amp, start


def handling(h: dict) -> np.ndarray:
    """A strike on the microphone's own body heard through it, not the air: the contact pulse's lows, a thump. Mono, from
    the hit's own sample."""
    on, by = MATERIALS[h["on"]], MATERIALS[h["by"]]
    tau = float(np.sqrt(on["pulse"] ** 2 + by["pulse"] ** 2))
    amp = (float(np.clip(h.get("speed", 0.2), 0.0, 4.0)) / 0.3) ** 1.2
    n_pulse = int(np.ceil(tau * RATE)) + 2
    n = n_pulse + int(0.12 * RATE)
    x = np.zeros(n)
    tt = np.arange(n_pulse) / RATE
    x[:n_pulse] = np.where(tt <= tau, np.sin(np.pi * np.clip(tt / tau, 0.0, 1.0)), 0.0) * np.pi / (2.0 * tau * RATE)
    return dsp.butter(dsp.butter(x, "lowpass", 260.0, 2, RATE), "highpass", 30.0, 2, RATE) * HANDLING * amp


# --- where it is heard ------------------------------------------------------------------------------------------------

def _cubic_read(x: np.ndarray, pos: np.ndarray) -> np.ndarray:
    """`x` read at fractional sample positions (Catmull-Rom): a moving delay that keeps its highs."""
    i = np.floor(pos).astype(int)
    f = pos - i
    xp = np.concatenate([np.zeros(2), x, np.zeros(3)])
    i = np.clip(i + 2, 1, xp.size - 3)
    y0, y1, y2, y3 = xp[i - 1], xp[i], xp[i + 1], xp[i + 2]
    return y1 + 0.5 * f * (y2 - y0 + f * (2.0 * y0 - 5.0 * y1 + 4.0 * y2 - y3 + f * (3.0 * (y1 - y2) + y3 - y0)))


def _shadow_lp(x: np.ndarray) -> np.ndarray:
    """The head's one pole, at c / (pi a) (Brown and Duda)."""
    fc = SOUND_SPEED / (np.pi * HEAD)
    return dsp.onepole(x, fc, RATE)


def ears(mono: np.ndarray, x: np.ndarray, y: np.ndarray, z: np.ndarray) -> np.ndarray:
    """A mono sound at a place (a sample each, or one each: a still source) heard by the head at the capsule: [2, n]."""
    n = mono.size
    p = np.stack([np.broadcast_to(x, (n,)), np.broadcast_to(y, (n,)), np.broadcast_to(z, (n,))]).astype(float)
    r = np.sqrt(np.sum(p * p, axis=0))
    # a place inside the head is taken out to its surface
    out_r = np.maximum(r, HEAD * 1.02)
    p = p * (out_r / np.maximum(r, 1e-9))
    r = out_r
    u = p / r
    lp = _shadow_lp(mono)
    hp = mono - lp
    out = np.zeros((2, n))
    for e, side in enumerate((-1.0, 1.0)):
        ear = np.array([side * HEAD, 0.0, 0.0])
        d = np.sqrt(np.sum((p - ear[:, None]) ** 2, axis=0))
        cos_th = u[0] * side
        th = np.degrees(np.arccos(np.clip(cos_th, -1.0, 1.0)))
        alpha = (1.0 + ALPHA_LEAST / 2.0) + (1.0 - ALPHA_LEAST / 2.0) * np.cos(np.radians(np.minimum(th, 180.0) * 180.0 / THETA_LEAST))
        alpha = np.where(th > THETA_LEAST, ALPHA_LEAST, alpha)
        # the path: straight where the ear is seen from the source, else to the tangent and round the head
        seen = cos_th * r >= HEAD
        gamma = np.arccos(np.clip(cos_th, -1.0, 1.0))
        tangent = np.sqrt(np.maximum(r * r - HEAD * HEAD, 0.0))
        round_ = tangent + HEAD * np.maximum(gamma - np.arccos(np.clip(HEAD / r, -1.0, 1.0)), 0.0)
        path = np.where(seen, d, np.maximum(round_, d))
        shaded = lp + alpha * hp
        delayed = _cubic_read(shaded, np.arange(n) - path / SOUND_SPEED * RATE)
        out[e] = delayed * (EAR_REF / np.maximum(d, EAR_NEAREST))
    # darker from behind (toward the viewer)
    back = np.clip(u[2], 0.0, 1.0) * BACK_DARK
    if np.any(back > 0.0):
        for e in range(2):
            out[e] -= back * dsp.butter(out[e], "highpass", BACK_HZ, 2, RATE)
    # the pinna's notch, higher as the sound is higher (its mean height: a notch never sweeps audibly)
    el = float(np.clip(np.mean(u[1]), -1.0, 1.0))
    nf = NOTCH_HZ[0] + (NOTCH_HZ[1] - NOTCH_HZ[0]) * (el + 1.0) / 2.0
    for e in range(2):
        out[e] -= NOTCH_DEPTH * dsp.butter(out[e], "bandpass", (nf / 1.15, nf * 1.15), 2, RATE)
    # the capsule's proximity bass: more the nearer
    two_kr = 2.0 * (2.0 * np.pi * PROX_AT / SOUND_SPEED) * r
    g = np.clip(np.sqrt(1.0 + 1.0 / (two_kr * two_kr)), 1.0, PROX_MOST)
    for e in range(2):
        out[e] += (g - 1.0) * dsp.butter(out[e], "lowpass", PROX_HZ, 2, RATE)
    return out


# --- the whole act ----------------------------------------------------------------------------------------------------

def render(spec: dict) -> np.ndarray:
    """The act's sound, [2, n] at RATE: every contact and hit made and placed, the microphone's color, the room, the
    limiter."""
    secs = float(spec["secs"])
    tail = float(spec.get("tail", 0.6))
    n = int(round((secs + tail) * RATE))
    lr = float(spec.get("lane_rate", 300.0))
    seed = int(spec.get("seed", 0))
    mix = np.zeros((2, n))
    for i, c in enumerate(spec.get("contacts", [])):
        rng = np.random.default_rng([seed, 1, i])
        lanes = lanes_of(c, n, lr)
        kind, on, by = c["kind"], c["on"], c["by"]
        if kind == "cup":
            mono = cup(lanes, rng)
        elif on == "fur":
            mono = fur(lanes, by, rng)
        elif kind == "scrape":
            mono = scrape(lanes, on, by, rng)
            modes = modes_of(c.get("body"), rng)
            if modes[0].size:
                mono = mono * 0.55 + ring(mono, modes) * 1.6
            other = c.get("body2")
            if other:
                mono = mono + ring(mono, modes_of(other, rng)) * 1.2
        else:
            mono = hard(lanes, kind, on, by, rng)
            modes = modes_of(c.get("body"), rng)
            if modes[0].size:
                mono = mono + ring(mono, modes) * (0.9 if kind == "scratch" else 0.5)
        mix += ears(mono, lanes["x"], lanes["y"], lanes["z"])
    for i, h in enumerate(spec.get("hits", [])):
        rng = np.random.default_rng([seed, 2, i])
        mono, start = hit_sound(h, rng)
        at = h.get("at", [0.0, 0.0, -0.1])
        st = ears(mono, np.float64(at[0]), np.float64(at[1]), np.float64(at[2]))
        a, b = max(start, 0), min(start + st.shape[1], n)
        if b > a:
            mix[:, a:b] += st[:, a - start:b - start]
        if h.get("handling"):
            th = handling(h)
            a, b = max(start, 0), min(start + th.size, n)
            if b > a:
                mix[:, a:b] += th[a - start:b - start]
    mix *= GAIN
    mix = dsp.compress(mix, threshold_db=SQUEEZE_DB, ratio=SQUEEZE, window_s=0.015, rate=RATE) if n > 64 else mix
    mix = color(mix)
    mix = room(mix, np.random.default_rng([seed, 3]))
    mix = soft_limit(mix)
    # eased in and out: an act's edges never click
    k_in, k_out = min(int(0.004 * RATE), n // 4), min(int(0.03 * RATE), n // 4)
    if k_in:
        mix[:, :k_in] *= np.sin(np.linspace(0.0, np.pi / 2.0, k_in)) ** 2
    if k_out:
        mix[:, -k_out:] *= np.cos(np.linspace(0.0, np.pi / 2.0, k_out)) ** 2
    return mix


def color(x: np.ndarray) -> np.ndarray:
    """The microphone's own: below 28 Hz gone, a little presence about 5 kHz, a little air above 11 kHz."""
    y = dsp.butter(x, "highpass", 28.0, 2, RATE)
    y = y + 0.15 * dsp.butter(y, "bandpass", (3800.0, 6800.0), 2, RATE)
    y = y + 0.12 * dsp.butter(y, "highpass", 11000.0, 2, RATE)
    return y


def room(x: np.ndarray, rng: np.random.Generator) -> np.ndarray:
    """A small, treated room: the desk's reflection a few milliseconds on, and a short, quiet tail."""
    n = x.shape[1]
    d = int(0.0034 * RATE)
    y = x.copy()
    y[:, d:] += 0.16 * dsp.butter(x[:, :n - d], "lowpass", 5000.0, 2, RATE)
    ir = dsp.reverb_ir(0.32, rng, damp=0.65, predelay=0.006, rate=RATE)
    wet = np.stack([signal.fftconvolve(y[0], ir[0])[:n], signal.fftconvolve(y[1], ir[1])[:n]])
    return y + 0.045 * wet


def soft_limit(x: np.ndarray) -> np.ndarray:
    """Never past CEILING: what nears it is bent under it smoothly, what is quiet untouched."""
    knee = CEILING * 0.6
    a = np.abs(x)
    over = a > knee
    y = x.copy()
    y[over] = np.sign(x[over]) * (knee + (CEILING - knee) * np.tanh((a[over] - knee) / (CEILING - knee)))
    return y


def heard(x: np.ndarray) -> dict:
    """What it sounds like as numbers (see the header)."""
    hop = int(FRAME * RATE)
    frames = []
    for s in range(0, x.shape[1], hop):
        seg = x[:, s:s + hop]
        if seg.shape[1] < 64:
            break
        rms = np.sqrt(np.mean(seg * seg, axis=1)) + 1e-9
        mono = seg.mean(axis=0)
        spec = np.abs(np.fft.rfft(mono * np.hanning(mono.size)))
        hz = np.fft.rfftfreq(mono.size, 1.0 / RATE)
        cen = float(np.sum(spec * hz) / (np.sum(spec) + 1e-12))
        db = 20.0 * np.log10(rms)
        frames.append([round(s / RATE, 2), round(float(db[0]), 1), round(float(db[1]), 1),
                       round(float(db[0] - db[1]), 1), round(cen)])
    peak = float(np.abs(x).max()) + 1e-12
    return {"seconds": round(x.shape[1] / RATE, 3), "peak_db": round(20.0 * np.log10(peak), 1),
            "frames": frames, "columns": ["s", "left_db", "right_db", "balance_db", "brightness_hz"]}


def write_wav(path: str, x: np.ndarray, seed: int = 0) -> None:
    """16-bit stereo at RATE, dithered (a quiet tail never turns to steps)."""
    rng = np.random.default_rng([seed, 9])
    tpdf = (rng.random(x.shape) - rng.random(x.shape)) / 32768.0
    pcm = (np.clip(x + tpdf, -1.0, 1.0).T * 32767.0).astype("<i2")
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    tmp = path + ".part"
    with wave.open(tmp, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())
    Path(tmp).replace(path)


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: contact.py <spec.json>", file=sys.stderr)
        return 2
    spec = json.loads(Path(argv[1]).read_text())
    done = str(spec.get("done", ""))
    try:
        why = check(spec)
        if why:
            raise ValueError(why)
        x = render(spec)
        write_wav(str(spec["out"]), x, int(spec.get("seed", 0)))
        result = {"ok": True, "wav": str(spec["out"]), "seconds": round(x.shape[1] / RATE, 3), "heard": heard(x)}
    except Exception as exc:  # the app shows why
        traceback.print_exc()
        result = {"ok": False, "error": str(exc)}
    if done:
        Path(done + ".part").write_text(json.dumps(result))
        Path(done + ".part").replace(done)
    else:
        print(json.dumps(result))
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
