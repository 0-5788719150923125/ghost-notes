"""parts.py - THE FACE'S PARTS: the eyes, the brows and the mouth, each its own scores, its own points of
MediaPipe's face mesh and how far round them it reaches (next/likeness.md, "The sixth pass").

WHY (2026-10-25, the user: "The shape/color of the face and head can be stable for several seconds, but then it
'flickers' into something else"): the face was moved by MediaPipe's 52 scores all at once, and their footage ties
the scores together - a glance aside came with the head turned to a lit screen, a wide mouth with the brows raised.
Fitted over every score, the rig's basis had a glance's scores move the cheeks and the jaw (the eyes' scores moved
the points below the nose 0.97 as far as their most), and the splats' expression components mixed every part, so a
played glance - 3.4 of its component's spreads in 60 ms - widened the cheek and moved the face's light. Measured from
the basis itself, every part reached nearly every triangle: what a score moves cannot be read off a fit of
correlated scores. So THE PARTS ARE PLACES ON THE FACE: each part's points (its anchors), and a reach in the face's
heights (the forehead's top, MediaPipe's 10, to the chin, 152) - all of it within half the reach of an anchor, none
past it. The rig's basis moves a point by the scores of the parts that reach it alone (rig.py), the splats' expression
has components of each part's scores alone and a splat takes them as far as the part reaches its triangle (train.py),
and each sound's mouth moves only what the mouth reaches (rig.py's `mouths`).

Each row: its name, the scores it moves (those whose names start so), how many principal components of them a splat's
shifts are mixed by, its anchors, and its reach.
"""

from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "face"))

import actor  # noqa: E402

# THE POINTS (MediaPipe's numbering, actor.py's rings): the lips, the lower face's edge round the chin (what the jaw
# carries: the face oval from one corner of the jaw to the other), each eye's rim and its iris, the brows.
JAW = actor.OVAL[actor.OVAL.index(397): actor.OVAL.index(172) + 1]
IRISES = list(range(468, 478))
# The face's height: the forehead's top to the chin.
TOP = 10
CHIN = actor.CHIN

PARTS = (
    ("eyes", ("eyeBlink", "eyeLook", "eyeSquint", "eyeWide"), 4, actor.EYE_RIGHT + actor.EYE_LEFT + IRISES, 0.12),
    ("brows", ("brow",), 2, actor.BROWS, 0.15),
    ("mouth", ("jaw", "mouth", "cheek", "nose"), 6, actor.LIPS_OUTER + actor.LIPS_INNER + JAW, 0.3),
)


def scores_of(names, starts) -> list:
    """The indices of [param names] (MediaPipe's score names, in order) a part moves."""
    return [j for j, s in enumerate(names) if s.startswith(tuple(starts))]


def reach_at(canon, at):
    """HOW FAR EACH PART REACHES [param at] ([M, 3] places on the neutral face [param canon], [V, 3]): [M, len(PARTS)]
    in 0..1 - all within half a part's reach of its nearest anchor, none past its reach, smoothly between (2D: the
    picture's across and down, as the face is seen)."""
    import numpy as np
    canon = np.asarray(canon, np.float64)
    at = np.asarray(at, np.float64)
    height = max(float(np.linalg.norm(canon[TOP, :2] - canon[CHIN, :2])), 1e-6)
    out = np.zeros((at.shape[0], len(PARTS)))
    for p, (_name, _scores, _n, anchors, reach) in enumerate(PARTS):
        a = canon[[i for i in anchors if i < canon.shape[0]], :2]
        d = np.sqrt(((at[:, None, :2] - a[None]) ** 2).sum(-1)).min(1) / height
        t = np.clip((d - 0.5 * reach) / (0.5 * reach), 0.0, 1.0)
        out[:, p] = 1.0 - t * t * (3.0 - 2.0 * t)
    return out
