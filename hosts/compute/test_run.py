#!/usr/bin/env python3
"""run.py, held to what a solver's code may and may not do.

    python test_run.py

Skips (exit 0, saying so) where there is no bwrap. Any Python runs it - the code it runs uses only
the standard library, inside the sandbox around the same Python.

What is held, each beside a control - the same code run plainly, outside the sandbox - that does
what the sandbox stops:
- a run prints, and keeps a series (y against 0, 1, 2 and y against x) with what it is about;
- the code's own error comes back as Python prints it, its own line shown, the runner's frames out;
- it reaches no network (a listener on this machine's loopback is not there);
- it sees none of the author's files (the repository's README is not there) and writes nowhere but
  its folder, while a file it saves there is there for the next run;
- it is stopped at its time limit and when its folder grows past its cap, and an allocation past
  its memory fails;
- keep refuses a value that is not a finite number, and a kept file the code forged is checked again:
  its bad series are dropped, its good one kept;
- with no bwrap nothing runs at all.
"""
import json
import os
import pathlib
import shutil
import socket
import subprocess
import sys
import tempfile
import threading

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import run  # noqa: E402

FAILS = []


def check(ok, what):
    print("   %s   %s" % ("ok  " if ok else "FAIL", what))
    if not ok:
        FAILS.append(what)


def sandboxed(base, code, seconds=20, memory_mb=None, bwrap=None, work_mb=None, n=[0]):
    n[0] += 1
    spec = {"code": code, "out": str(base / ("out%d.json" % n[0])), "work": str(base / "work"),
            "io": str(base / ("io%d" % n[0])), "seconds": seconds,
            "bwrap": shutil.which("bwrap") if bwrap is None else bwrap}
    if memory_mb:
        spec["memory_mb"] = memory_mb
    if work_mb:
        spec["work_mb"] = work_mb
    return run.run(spec)


def plainly(base, code):
    """The control: the same code, run as any program is."""
    p = subprocess.run([sys.executable, "-I", "-c", code], capture_output=True, text=True, cwd=str(base), timeout=60)
    return p.stdout + p.stderr


def main():
    if not shutil.which("bwrap"):
        print("test_run: SKIPPED - no bwrap on this machine")
        return 0
    # on a real disk where there is one (dist/, ignored by git): the sandbox has a /tmp of its own, so a
    # folder under /tmp would let the write below land in the sandbox's /tmp and say nothing
    dist = HERE.parent.parent / "dist"
    base = pathlib.Path(tempfile.mkdtemp(prefix="ghost_run_test_", dir=str(dist) if dist.is_dir() else None))
    try:
        print("-- a run")
        a = sandboxed(base, "print('six', 2 * 3)\nkeep('ys', [3, 1, 2], about='three')\nkeep('xy', [0.5, 1.5], [4, 5])\n")
        check(a["ok"] and a["exit"] == 0 and a["stdout"] == "six 6\n", "it prints (%r, exit %s)" % (a["stdout"], a["exit"]))
        check(a["kept"].get("ys", {}).get("points") == [[0.0, 3.0], [1.0, 1.0], [2.0, 2.0]]
              and a["kept"]["ys"]["about"] == "three" and a["kept"].get("xy", {}).get("points") == [[0.5, 4.0], [1.5, 5.0]],
              "it keeps y against 0, 1, 2 and y against x")
        e = sandboxed(base, "def f(x):\n    return 1 / x\n\nf(0)\n")
        check(e["exit"] == 1 and "line 2, in f" in e["stderr"] and "return 1 / x" in e["stderr"]
              and "ZeroDivisionError" in e["stderr"] and "run.py\", line" in e["stderr"]
              and str(HERE) not in e["stderr"], "an error is Python's own, the code's lines shown, the runner's frames out")

        print("-- what it cannot reach")
        srv = socket.socket()
        srv.bind(("127.0.0.1", 0))
        srv.listen(4)
        port = srv.getsockname()[1]
        threading.Thread(target=lambda: [srv.accept() for _ in range(2)], daemon=True).start()
        net = "import socket\ns = socket.socket(); s.settimeout(3)\ntry:\n    s.connect(('127.0.0.1', %d)); print('REACHED')\nexcept OSError as e:\n    print('NOT', e)\n" % port
        inside = sandboxed(base, net)["stdout"]
        outside = plainly(base, net)
        check(inside.startswith("NOT") and outside.startswith("REACHED"),
              "no network: a listener on the loopback is not reached (%s; the control: %s)" % (inside.strip(), outside.strip()))
        readme = HERE.parent.parent / "README.md"
        look = "import os\nprint(os.path.exists(%r))\n" % str(readme)
        inside = sandboxed(base, look)["stdout"].strip()
        outside = plainly(base, look).strip()
        check(inside == "False" and outside == "True", "the author's files are not there (README: %s; the control: %s)" % (inside, outside))
        target = base / "outside.txt"
        write = "try:\n    open(%r, 'w').write('x'); print('WROTE')\nexcept OSError as e:\n    print('NOT', e.strerror)\n" % str(target)
        inside = sandboxed(base, write)["stdout"].strip()
        wrote_in = target.exists()
        outside = plainly(base, write).strip()
        check(inside.startswith("NOT") and not wrote_in and outside == "WROTE" and target.exists(),
              "it writes nowhere but its folder (%s; the control: %s)" % (inside, outside))
        sandboxed(base, "open('saved.txt', 'w').write('kept')\n")
        again = sandboxed(base, "print(open('saved.txt').read())\n")
        check(again["stdout"].strip() == "kept" and (base / "work" / "saved.txt").exists(), "a file it saves in its folder is there for the next run")

        print("-- limits")
        slow = sandboxed(base, "while True:\n    pass\n", seconds=2)
        check(slow["timed_out"] and 1.9 < slow["seconds"] < 6.0 and "time limit" in slow["error"],
              "an endless loop is stopped at its limit (%.1f s)" % slow["seconds"])
        big = sandboxed(base, "b = bytearray(700 << 20)\nprint('GOT')\n", memory_mb=512)
        small = sandboxed(base, "b = bytearray(100 << 20)\nprint('GOT')\n", memory_mb=512)
        check("MemoryError" in big["stderr"] and small["stdout"].strip() == "GOT",
              "past its memory an allocation fails (the control, a small one, does not)")

        fill = "import time\nfor i in range(%d):\n    open('fill%%d.bin' %% i, 'wb').write(b'x' * (4 << 20)); time.sleep(0.4)\nprint('DONE')\n"
        full = sandboxed(base, fill % 8, work_mb=16)
        some = sandboxed(base, "import os\nfor f in os.listdir('.'):\n    os.remove(f) if f.startswith('fill') else None\n" + fill % 2, work_mb=16)
        check("folder grew past" in full["error"] and "DONE" not in full["stdout"] and some["stdout"].strip() == "DONE",
              "a run that fills its folder past its cap is stopped (the control, a little, is not)")

        print("-- what is kept")
        nan = sandboxed(base, "keep('bad', [1.0, float('nan')])\n")
        check(nan["exit"] == 1 and "finite" in nan["stderr"] and nan["kept"] == {}, "keep refuses nan")
        forged = sandboxed(base, "import json, os\njson.dump({'ok': {'points': [[0, 1], [1, 2]]}, '1bad': {'points': [[0, 1]]}, "
                                 "'nans': {'points': [[0, 'x']]}, 'many': {'points': [[0, 1]] * 9000}}, open('.kept.json', 'w'))\nos._exit(0)\n")
        check(set(forged["kept"]) == {"ok"}, "a forged kept file is checked again: only its good series stays (%s)" % sorted(forged["kept"]))

        print("-- no sandbox, no run")
        none = sandboxed(base, "open('ran.txt', 'w').write('x')\n", bwrap="")
        check(not none["ok"] and "bwrap" in none["error"] and not (base / "work" / "ran.txt").exists(),
              "with no bwrap nothing runs")
    finally:
        shutil.rmtree(base, ignore_errors=True)
    print("test_run: %s" % ("ALL OK" if not FAILS else "%d FAILED" % len(FAILS)))
    return 0 if not FAILS else 1


if __name__ == "__main__":
    sys.exit(main())
