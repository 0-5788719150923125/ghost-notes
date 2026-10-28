"""The host's LINE: a cancel reaches the requests still waiting while one is being made.

    <venv>/bin/python hosts/voice/test_host.py [<a host.py to hold, this folder's by default>]

The real host is run as ghost runs it, over its pipes, with a stand-in backend that writes an empty
take for each request it makes - the first one waiting on a gate this test opens. While it waits,
two of the three requests behind it are cancelled: they are answered `cancelled` at once, before the
one being made, and never made; the one being made and the ones not named are; a request asked after
the cancel is made after them. THE CONTROL: the same requests with no cancel are all made - and the
host as it was (each request read in turn, `git show HEAD:hosts/voice/host.py`) answers the cancel
only after the passage it names, and fails here.
"""

import json
import os
import queue
import shutil
import subprocess
import sys
import tempfile
import threading
import time

HERE = os.path.dirname(os.path.abspath(__file__))
HOST = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.join(HERE, "host.py")

# the host, with a backend that makes an empty take - the text "wait" only once the gate is open
DRIVER = r"""
import importlib.util, os, sys, time
sys.path.insert(0, sys.argv[1])
spec = importlib.util.spec_from_file_location("host_under_test", sys.argv[2])
host = importlib.util.module_from_spec(spec)
spec.loader.exec_module(host)
from backends import REGISTRY
GATE = sys.argv[3]

class Stand:
    @classmethod
    def owns(cls, voice):
        return voice == "stand"

    @classmethod
    def describe(cls):
        return {}

    def synthesize(self, text, voice, out_path, params, phonemes):
        if text == "wait":
            open(out_path + ".started", "w").close()
            while not os.path.exists(GATE):
                time.sleep(0.01)
        open(out_path, "w").close()
        return {"wav": out_path}

REGISTRY["stand"] = Stand
sys.exit(host.Host().run())
"""

fails = []


def check(cond, what):
    if not cond:
        fails.append(what)


def run(cancel: bool) -> tuple:
    """Requests 1 (waits on the gate), 2, 3, 4, a cancel of 1, 2 and 3 if [cancel], then 5: the replies
    in the order they came, and which requests were made."""
    work = tempfile.mkdtemp(prefix="ghost_host_")
    gate = os.path.join(work, "gate")
    proc = subprocess.Popen(
        [sys.executable, "-u", "-c", DRIVER, HERE, HOST, gate],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        text=True,
    )
    lines: queue.Queue = queue.Queue()
    threading.Thread(target=lambda: [lines.put(ln) for ln in proc.stdout], daemon=True).start()

    def send(req):
        proc.stdin.write(json.dumps(req) + "\n")
        proc.stdin.flush()

    def ask(i, text="go"):
        send({"id": i, "op": "synthesize", "backend": "stand", "voice": "stand", "text": text,
              "out": os.path.join(work, "take_%d" % i)})

    got = []
    try:
        check(json.loads(lines.get(timeout=60)).get("event") == "ready", "the host did not say it was ready")
        ask(1, "wait")
        for i in (2, 3, 4):
            ask(i)
        started = os.path.join(work, "take_1.started")
        for _ in range(3000):  # the first request is being made before anything is cancelled
            if os.path.exists(started):
                break
            time.sleep(0.01)
        if cancel:
            send({"id": 9, "op": "cancel", "ids": [1, 2, 3]})
            # what the cancel says comes before the gate opens: it was acted on while 1 was being made
            for _ in range(3):
                got.append(json.loads(lines.get(timeout=10)))
        ask(5)
        open(gate, "w").close()
        while not any(r.get("id") == 5 for r in got):
            got.append(json.loads(lines.get(timeout=30)))
        send({"id": 10, "op": "shutdown"})
        proc.wait(timeout=30)
    except queue.Empty:
        fails.append("the host stopped answering (cancel %s); it had answered %s" % (cancel, got))
    finally:
        if proc.poll() is None:
            proc.kill()
        made = {i for i in range(1, 6) if os.path.exists(os.path.join(work, "take_%d" % i))}
        shutil.rmtree(work, ignore_errors=True)
    return got, made


got, made = run(cancel=True)
check(
    [(r.get("id"), r.get("cancelled", False)) for r in got[:2]] == [(2, True), (3, True)]
    and got[2:3] == [{"id": 9, "ok": True, "dropped": 2}],
    "the cancel was not answered at once, the waiting requests first: %s" % got[:3],
)
check(made == {1, 4, 5}, "cancelled, the host made %s - not 1 (being made), 4 and 5" % sorted(made))
check(
    [r.get("id") for r in got[3:]] == [1, 4, 5] and all(r.get("ok") for r in got[3:]),
    "after the cancel the host answered %s, not 1, 4 and 5" % got[3:],
)
got, made = run(cancel=False)
check(made == {1, 2, 3, 4, 5}, "control: with no cancel the host made %s, not all five" % sorted(made))
print("test_host: %s" % ("ALL OK" if not fails else "FAILED - " + "; ".join(fails)))
sys.exit(1 if fails else 0)
