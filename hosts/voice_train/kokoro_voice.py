#!/usr/bin/env python3
"""kokoro_voice.py - the Voice training card's Voice step on Kokoro: their sentences made ready, Kokoro taught them, and
the voice written into the host's graph (next/voice_engines.md, "Training Kokoro").

    <voice_train_venv python> kokoro_voice.py --spec <spec.json> [--progress <file>]

The spec: {"utterances": Utterances' folder (`"engine": "kokoro"`), "model", "config", "base" (the pack it starts
from), "graph" (the voice host's Kokoro graph to write into) and "graph_url" (where the host fetches it, for a
machine that has never read in Kokoro), "work" (kept between runs), "out" (the voice folder), "name", "british",
"steps", "batch", "seconds"}.

THREE PARTS, EACH KEPT: the sentences prepared (kokoro_data.py: their alignment, pitch and energy) once for the
sentences they are - `work/prepared` is made again only when Utterances made other ones; the lessons (kokoro_train.py:
`work/run/last.pt` goes on where it stopped); the export (kokoro_export.py), checked against PyTorch before it is kept.
The progress is the three as one: a tenth the preparing, the lessons the most, the export the last of it.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import kokoro_data  # noqa: E402
import kokoro_export  # noqa: E402
import kokoro_train  # noqa: E402


def say(*parts) -> None:
    print("actor: voice:", *parts, flush=True)


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="kokoro_voice.py")
    ap.add_argument("--spec", required=True)
    ap.add_argument("--progress", default="")
    a = ap.parse_args(argv)
    spec = json.loads(Path(a.spec).read_text(encoding="utf-8"))
    utt, work = Path(spec["utterances"]), Path(spec["work"])
    work.mkdir(parents=True, exist_ok=True)
    # THE SENTENCES, PREPARED ONCE for what Utterances made (its index and its rows) and the pack it starts from
    stamp = hashlib.sha256(b"".join((utt / f).read_bytes() for f in ("metadata.csv", "test.csv") if (utt / f).exists())
                           + str(spec["base"]).encode()).hexdigest()[:16]
    prepared = work / "prepared"
    mark = prepared / "made_from.txt"
    if not (mark.exists() and mark.read_text().strip() == stamp and (prepared / "index.json").exists()):
        say("preparing their sentences: each said by Kokoro and laid on theirs, their pitch and energy read")
        rc = kokoro_data.main(["--data", str(utt), "--base", str(spec["base"]), "--model", str(spec["model"]),
                               "--config", str(spec["config"]), "--out", str(prepared)])
        if rc:
            return rc
        mark.write_text(stamp)
    kokoro_train.progress(a.progress, 0.1)
    # THE LESSONS, going on from where they stopped
    train_spec = work / "train.spec.json"
    train_spec.write_text(json.dumps({"data": str(prepared), "model": spec["model"], "config": spec["config"],
                                      "base": spec["base"], "work": str(work / "run"), "steps": int(spec.get("steps", 4000)),
                                      "batch": int(spec.get("batch", 6)), "seconds": float(spec.get("seconds", 1.5))}))
    whole = a.progress

    class Scaled:
        """kokoro_train's progress, laid in 0.1 to 0.97 of the whole."""

        def __init__(self):
            self.path = whole + ".lessons" if whole else ""

    lessons = Scaled()
    real = kokoro_train.progress

    def progress(path: str, frac: float) -> None:
        if path and path == lessons.path:
            real(whole, 0.1 + 0.87 * frac)
        else:
            real(path, frac)

    kokoro_train.progress = progress
    try:
        rc = kokoro_train.main(["--spec", str(train_spec), "--progress", lessons.path])
    finally:
        kokoro_train.progress = real
    if rc:
        return rc
    # THE EXPORT, into a copy of the host's own graph - fetched as the host fetches it, where it never has
    graph = Path(spec["graph"])
    if not graph.exists():
        import urllib.request

        graph = work / "stock" / "model.onnx"
        graph.parent.mkdir(parents=True, exist_ok=True)
        for name, url in (("model.onnx", spec["graph_url"] + "/onnx/model.onnx"), ("tokenizer.json", spec["graph_url"] + "/tokenizer.json")):
            if not (graph.parent / name).exists():
                say("fetching Kokoro's graph (%s)" % name)
                urllib.request.urlretrieve(url, graph.parent / (name + ".part"))
                (graph.parent / (name + ".part")).replace(graph.parent / name)
    say("writing the voice into Kokoro's graph")
    args = ["--graph", str(graph), "--model", str(spec["model"]), "--config", str(spec["config"]),
            "--run", str(work / "run" / "last.pt"), "--out", str(spec["out"]), "--name", str(spec.get("name", "Their own voice")),
            "--base", str(spec["base"])]
    if bool(spec.get("british", False)):
        args.append("--british")
    rc = kokoro_export.main(args)
    if rc:
        return rc
    kokoro_train.progress(a.progress, 1.0)
    say("their voice is ready")
    return 0


if __name__ == "__main__":
    sys.exit(main())
