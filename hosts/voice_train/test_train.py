#!/usr/bin/env python3
"""Tests for the voice trainer's own parts (train.py, align.py).

Run it directly with the voice-training venv's python - no pytest needed:

    ~/.local/share/godot/app_userdata/ghost/voice_train_venv/bin/python hosts/voice_train/test_train.py

No graphics card is needed, and nothing is trained.

  THE ALIGNMENT IS VITS'S - align.py's search finds, path for path and sum for sum, what VITS's Cython
  `maximum_path_each` finds (transcribed below line for line), over utterances of many lengths, and its
  paths are monotonic, one phoneme a frame, first to last.
  PIPER FINDS IT - once installed, Piper's own `maximum_path` imports and runs on it (CONTROL: before,
  it does not import - the wheel ships the Cython unbuilt).
  A SAVED RUN IS JUDGED WHOLE - a checkpoint cut short is not taken for one (CONTROL: the whole one is).
  THE TIME TO GO IS SAID in minutes, then hours (CONTROL: an hour and a half is not said in minutes), and
  the trainer asks the allocator to grow its segments before torch starts CUDA.
"""

from __future__ import annotations

import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import numpy as np  # noqa: E402

CHECKS = []


def check(fn):
    CHECKS.append(fn)
    return fn


def ok(cond, what):
    if not cond:
        raise AssertionError(what)
    print(f"    ok   {what}")


def _reference(path, value, t_y, t_x):
    """VITS's monotonic_align/core.pyx `maximum_path_each`, line for line."""
    neg = np.float32(-1e9)
    for y in range(t_y):
        for x in range(max(0, t_x + y - t_y), min(t_x, y + 1)):
            v_cur = neg if x == y else value[y - 1, x]
            v_prev = (np.float32(0.0) if y == 0 else neg) if x == 0 else value[y - 1, x - 1]
            value[y, x] = np.float32(value[y, x] + max(v_prev, v_cur))
    index = t_x - 1
    for y in range(t_y - 1, -1, -1):
        path[y, index] = 1
        if index != 0 and (index == y or value[y - 1, index] < value[y - 1, index - 1]):
            index -= 1


@check
def the_alignment_is_vits():
    from align import maximum_path_c
    rng = np.random.default_rng(3)
    ty = np.array([120, 90, 60, 41, 40, 100, 7], np.int32)
    tx = np.array([40, 30, 20, 40, 40, 7, 7], np.int32)
    v = rng.normal(size=(len(ty), 120, 40)).astype(np.float32)
    p1, v1 = np.zeros(v.shape, np.int32), v.copy()
    maximum_path_c(p1, v1, ty, tx)
    p2, v2 = np.zeros(v.shape, np.int32), v.copy()
    for i in range(len(ty)):
        _reference(p2[i], v2[i], int(ty[i]), int(tx[i]))
    ok((p1 == p2).all(), "every path is VITS's")
    ok(np.array_equal(v1, v2), "every sum is VITS's")
    fine = True
    for i in range(len(ty)):
        p = p1[i, : ty[i], : tx[i]]
        x = p.argmax(1)
        fine &= bool((p.sum(1) == 1).all() and (np.diff(x) >= 0).all() and (np.diff(x) <= 1).all()
                     and x[0] == 0 and x[-1] == tx[i] - 1)
    ok(fine, "each path is monotonic, one phoneme a frame, from the first to the last")


@check
def piper_finds_it():
    try:
        import piper.train.vits.monotonic_align  # noqa: F401
        before = True
    except ImportError:
        before = False
    sys.modules.pop("piper.train.vits.monotonic_align", None)
    ok(not before, "CONTROL: before, Piper's alignment does not import (its Cython is unbuilt)")
    import torch
    import train
    train.install_align()
    from piper.train.vits.monotonic_align import maximum_path
    neg = torch.randn(2, 50, 12)
    mask = torch.zeros(2, 50, 12)
    mask[0] = 1.0
    mask[1, :30, :9] = 1.0
    path = maximum_path(neg, mask)
    ok(tuple(path.shape) == (2, 50, 12) and float(path[0].sum()) == 50.0 and float(path[1].sum()) == 30.0,
       "Piper's maximum_path runs on it: a phoneme for every frame of each utterance")


@check
def a_saved_run_is_judged_whole():
    import torch
    import train
    with tempfile.TemporaryDirectory() as td:
        whole = Path(td) / "last.ckpt"
        torch.save({"state_dict": {"w": torch.zeros(4096)}, "epoch": 3}, whole)
        cut = Path(td) / "cut.ckpt"
        cut.write_bytes(whole.read_bytes()[: whole.stat().st_size // 2])
        ok(train.sound(whole), "CONTROL: a whole run is taken")
        ok(not train.sound(cut), "a run cut short is not")


@check
def the_time_to_go_is_said():
    import os
    import train
    ok(train.span(0.2) == "about 1 minute" and train.span(40) == "about 40 minutes", "minutes under an hour and a half")
    ok(train.span(90) == "about 1.5 hours", "CONTROL: an hour and a half is said in hours")
    ok(train.span(745) == "about 12 hours", "half a day in whole hours")
    ok("expandable_segments:True" in os.environ.get("PYTORCH_CUDA_ALLOC_CONF", ""),
       "the allocator grows its segments")


def main() -> int:
    failed = 0
    for fn in CHECKS:
        print(f"\n{fn.__name__}")
        try:
            fn()
        except AssertionError as exc:
            failed += 1
            print(f"    FAIL {exc}")
    print(f"\n{len(CHECKS) - failed}/{len(CHECKS)} checks passed")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
