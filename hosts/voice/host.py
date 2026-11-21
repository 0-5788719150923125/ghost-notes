#!/usr/bin/env python3
"""ghost voice host - a neural synthesis subprocess, spoken to over stdio.

WHY A SUBPROCESS AND NOT A GDEXTENSION. Godot has no first-class ONNX support,
and wrapping ONNX Runtime's C API natively means per-platform binaries and a
build story ghost does not have. It would also mean a native rebuild every time
we try a different model, which is exactly what the design is supposed to make
cheap. ghost already bootstraps a private virtualenv at user://ytdlp_venv for
its YouTube import, so the pattern and the failure handling exist. Adding a
model becomes a file in backends/ and an entry in the registry, with no Godot
code touched - the swappability test in VOICE_PLAN.md section 3. If latency ever
justifies it, the transport can become a GDExtension without changing the
protocol.

PROTOCOL. Newline-delimited JSON on stdin and stdout. One request per line, one
response per line, `id` echoed back. Audio never travels as JSON - it is written
to a file whose path is returned, because base64 over a pipe is a needless copy
of megabytes and Godot can load a WAV directly.

  -> {"id": 1, "op": "capabilities"}
  <- {"id": 1, "ok": true, "backends": {...}}

  -> {"id": 2, "op": "voices"}
  <- {"id": 2, "ok": true, "voices": [{"id", "name", "backend", "license", ...}]}

  -> {"id": 3, "op": "synthesize", "text": "...", "voice": "en_US-...",
      "out": "/path/to/take.wav", "params": {"length_scale": 1.0}}
  <- {"id": 3, "ok": true, "wav": "...", "sample_rate": 22050, "duration": 4.2,
      "words": [{"text": "the", "t0": 0.0, "t1": 0.12}], "phones": [...]}

  -> {"id": 6, "op": "sing", "voice": "kokoro", "out": "/path/to/phrase.wav", "params": {"speaker": 0},
      "words": [{"text": "error", "notes": [{"t": 0.0, "len": 0.3, "midi": 64}, ...]}], "style": {"tune": 0.0}}
  <- {"id": 6, "ok": true, "wav": "...", "sample_rate": 24000, "start": -0.31, "duration": 2.1, "sung": [...]}
     A `semis` in its params (a voice's Tone) is a change of SIZE, the notes and their times kept (`_sung_at_size`);
     every phrase is sung on past its end and cut, so its last word is whole (`_sung_whole`).

  -> {"id": 4, "op": "cancel", "ids": [2, 3]}
  <- {"id": 3, "ok": false, "cancelled": true}
  <- {"id": 4, "ok": true, "dropped": 1}

  -> {"id": 5, "op": "shutdown"}

Every response carries "ok". On failure it is false and "error" holds a
user-safe string. The host never exits on a bad request - the model load is the
slow part and we want it to stay warm.

REQUESTS WAIT IN LINE, AND A CANCEL REACHES THEM. Requests are read on a thread
of their own into a line the main loop takes from, one at a time, in order; a
`cancel` is answered by that thread at once, each named request still in line
answered `cancelled` and never made (the one being made finishes, and its reply
is the caller's to drop). Read in turn, a cancel would have waited behind the
very requests it names: Test asks for its whole passage at once, and a Stop only
forgot the replies, so a new Test would wait for each old passage to be made in
full. Read on a thread, stdin is also always drained, so ghost's write of
a request never blocks its frame on a full pipe.

STDOUT IS THE PROTOCOL. Anything a backend prints would corrupt it, so stdout is
redirected for the whole process and only the protocol writer holds the real
one. Diagnostics go to stderr, which ghost's console surfaces.
"""

from __future__ import annotations

import json
import os
import sys
import threading
import traceback
from collections import deque
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import backends  # noqa: E402
from backends import REGISTRY, BackendError  # noqa: E402

PROTOCOL_VERSION = 1


def _trust_store() -> None:
    """Point TLS at the system's CA bundle when this interpreter's own default is absent.

    ghost runs the host on a standalone CPython whose OpenSSL looks for
    /etc/ssl/cert.pem and /etc/ssl/certs. Most systems have one of them; the few
    that keep their bundle elsewhere would fail every download with a certificate
    error, so the usual locations are tried before anything is fetched.
    """
    if os.name == "nt" or os.environ.get("SSL_CERT_FILE"):
        return
    import ssl

    paths = ssl.get_default_verify_paths()
    if paths.cafile and os.path.exists(paths.cafile):
        return
    if paths.capath and os.path.isdir(paths.capath):
        if any(name.endswith(".0") for name in os.listdir(paths.capath)):
            return
    for candidate in (
        "/etc/ssl/certs/ca-certificates.crt",
        "/etc/pki/tls/certs/ca-bundle.crt",
        "/etc/ssl/ca-bundle.pem",
        "/etc/pki/tls/cacert.pem",
        "/etc/ssl/certs/ca-bundle.crt",
    ):
        if os.path.exists(candidate):
            os.environ["SSL_CERT_FILE"] = candidate
            return


_trust_store()


class Host:
    def __init__(self) -> None:
        # Claim the real stdout before anything else can write to it, then point
        # the process's stdout at stderr so a chatty backend cannot corrupt the
        # protocol stream. Model loaders are notoriously chatty.
        self._out = os.fdopen(
            os.dup(sys.stdout.fileno()), "w", buffering=1, encoding="utf-8"
        )
        os.dup2(sys.stderr.fileno(), sys.stdout.fileno())
        # Godot speaks UTF-8; Windows would otherwise decode stdin as cp1252.
        sys.stdin.reconfigure(encoding="utf-8")
        self._backends: dict = {}
        backends.progress = self._download_progress
        self._sending = threading.Lock()  # replies come from both threads
        self._line: deque = deque()  # requests waiting to be made; None is the end of stdin
        self._waiting = threading.Condition()

    # -- transport ---------------------------------------------------------

    def send(self, payload: dict) -> None:
        with self._sending:
            self._out.write(json.dumps(payload) + "\n")
            self._out.flush()

    def _download_progress(
        self, name: str, done: int, total: int, finished: bool, error: str
    ) -> None:
        event = {"event": "download", "name": name, "done": done, "total": total}
        if finished:
            event.update({"finished": True, "ok": not error, "error": error})
        self.send(event)

    def run(self) -> int:
        self.send(
            {
                "event": "ready",
                "protocol": PROTOCOL_VERSION,
                "backends": sorted(REGISTRY.keys()),
            }
        )
        threading.Thread(target=self._read, name="requests", daemon=True).start()
        while True:
            with self._waiting:
                while not self._line:
                    self._waiting.wait()
                req = self._line.popleft()
            if req is None:
                return 0
            rid = req.get("id")
            op = req.get("op", "")
            if op == "shutdown":
                self.send({"id": rid, "ok": True})
                return 0
            try:
                self.send({"id": rid, "ok": True, **self.dispatch(op, req)})
            except BackendError as exc:
                self.send({"id": rid, "ok": False, "error": str(exc)})
            except Exception as exc:  # noqa: BLE001
                traceback.print_exc()
                self.send(
                    {"id": rid, "ok": False, "error": f"{type(exc).__name__}: {exc}"}
                )

    def _read(self) -> None:
        """stdin, a line at a time, into the line - a cancel acted on here, as it arrives."""
        try:
            for line in sys.stdin:
                line = line.strip()
                if not line:
                    continue
                try:
                    req = json.loads(line)
                except json.JSONDecodeError as exc:
                    self.send({"ok": False, "error": f"malformed request: {exc}"})
                    continue
                if req.get("op") == "cancel":
                    self._cancel(req)
                    continue
                with self._waiting:
                    self._line.append(req)
                    self._waiting.notify()
        except Exception:  # noqa: BLE001 - a reader that dies ends the host, as the loop it was did
            traceback.print_exc()
        with self._waiting:
            self._line.append(None)
            self._waiting.notify()

    def _cancel(self, req: dict) -> None:
        """Every request `ids` names that is still in line, taken out of it and answered `cancelled`."""
        ids = set(req.get("ids") or [])
        with self._waiting:
            dropped = [r for r in self._line if r is not None and r.get("id") in ids]
            for r in dropped:
                self._line.remove(r)
        for r in dropped:
            self.send({"id": r.get("id"), "ok": False, "cancelled": True})
        self.send({"id": req.get("id"), "ok": True, "dropped": len(dropped)})

    # -- operations --------------------------------------------------------

    def dispatch(self, op: str, req: dict) -> dict:
        if op == "capabilities":
            return {
                "protocol": PROTOCOL_VERSION,
                "backends": {name: cls.describe() for name, cls in REGISTRY.items()},
            }
        if op == "voices":
            voices = []
            for name in REGISTRY:
                try:
                    voices.extend(self.backend(name).voices())
                except BackendError as exc:
                    # one unavailable backend must not hide the others: a missing
                    # dependency is a reportable state, not a fatal one
                    self.send(
                        {
                            "event": "backend_unavailable",
                            "backend": name,
                            "error": str(exc),
                        }
                    )
            return {"voices": voices}
        if op == "synthesize":
            voice = req.get("voice") or ""
            backend = self.backend(req.get("backend") or self.backend_for(voice))
            result = backend.synthesize(
                text=req.get("text", ""),
                voice=voice,
                out_path=req["out"],
                params=req.get("params") or {},
                phonemes=req.get("phonemes"),
            )
            return result
        if op == "sing":
            # a phrase sung on its notes (a composed Sound's vocal part): the backend that owns the voice must sing
            voice = req.get("voice") or ""
            backend = self.backend(req.get("backend") or self.backend_for(voice))
            if not hasattr(backend, "sing"):
                raise BackendError(f"the {backend.name} voices cannot sing")
            params = dict(req.get("params") or {})
            semis = float(params.pop("semis", 0.0) or 0.0)
            if abs(semis) > 1e-3:
                return _sung_at_size(backend, voice, req.get("words") or [], req["out"], params, req.get("style") or {}, semis)
            return _sung_whole(backend, voice, req.get("words") or [], req["out"], params, req.get("style") or {})
        if op == "ensure":
            # download/prepare a voice without synthesizing, so a UI can show
            # progress before the user is waiting on audio
            return self.backend(
                req.get("backend") or self.backend_for(req.get("voice", ""))
            ).ensure(req.get("voice", ""))
        raise BackendError(f"unknown op '{op}'")

    # -- backend management ------------------------------------------------

    def backend(self, name: str):
        if name not in REGISTRY:
            raise BackendError(f"unknown backend '{name}'")
        if name not in self._backends:
            self._backends[name] = REGISTRY[name]()  # loads lazily; stays warm
        return self._backends[name]

    def backend_for(self, voice: str) -> str:
        for name, cls in REGISTRY.items():
            if cls.owns(voice):
                return name
        raise BackendError(f"no backend owns voice '{voice}'")


# A phrase is sung on past its end by TAIL_WORDS of its own opening words, each a TAIL_NOTE long after TAIL_GAP of rest, and
# cut TAIL_RELEASE past its last note, faded over the last TAIL_FADE of that (`_sung_whole`).
TAIL_WORDS = 3
TAIL_GAP = 0.35
TAIL_NOTE = 0.25
TAIL_RELEASE = 0.08
TAIL_FADE = 0.04


def _sung_whole(backend, voice: str, words: list, out: str, params: dict, style: dict) -> dict:
    """A phrase sung with its last word whole. Kokoro ending an utterance on a word lets that word die away - a short
    one to nothing, a held one's last consonants early (the same as a spoken sentence's end, which the reading gives
    the next sentence's opening words for) - so the phrase is sung on past its end, TAIL_WORDS of its own opening words
    after a short rest at its last note's pitch, and the take cut just after its last note: only the phrase is kept,
    its last word sung as one in the middle of a line is."""
    import wave

    import numpy as np

    notes = [n for w in words for n in w.get("notes", [])]
    texts = [str(w.get("text", "")) for w in words if str(w.get("text", "")).strip()]
    if not notes or not texts:
        return backend.sing(voice=voice, words=words, out_path=out, params=params, style=style)
    last = max(notes, key=lambda n: float(n["t"]) + float(n["len"]))
    end = float(last["t"]) + float(last["len"])
    tail = []
    at = end + TAIL_GAP
    for text in (texts * TAIL_WORDS)[:TAIL_WORDS]:
        tail.append({"text": text, "notes": [{"t": at, "len": TAIL_NOTE, "midi": float(last["midi"])}]})
        at += TAIL_NOTE + 0.03
    got = dict(backend.sing(voice=voice, words=list(words) + tail, out_path=out, params=params, style=style))
    with wave.open(out, "rb") as w:
        rate = w.getframerate()
        audio = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").astype(np.float32) / 32767.0
    cut = max(1, min(audio.size, int(round((end + TAIL_RELEASE - float(got.get("start", 0.0))) * rate))))
    kept = audio[:cut].copy()
    fade = min(kept.size, int(TAIL_FADE * rate))
    if fade > 0:
        kept[-fade:] *= np.linspace(1.0, 0.0, fade, dtype=np.float32)
    pcm = (np.clip(kept, -1.0, 1.0) * 32767.0).astype("<i2")
    tmp = out + ".part"
    with wave.open(tmp, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(pcm.tobytes())
    Path(tmp).replace(out)
    got["duration"] = kept.size / float(rate)
    got["sung"] = [x for x in got.get("sung", []) if not isinstance(x, dict) or int(x.get("word", 0)) < len(words)]
    return got


def _sung_at_size(backend, voice: str, words: list, out: str, params: dict, style: dict, semis: float) -> dict:
    """A phrase sung by a voice `semis` semitones larger or smaller (the Tone's pitch shift, which moves the formants),
    on the notes and times it is given: sung `semis` lower and quicker by the ratio, then played back slower by it - the
    pitch and timing come back where they were written and the formants move with the playback, as the reading's Tone
    moves them (piper._resample, the band-limited resampler)."""
    import wave

    import numpy as np
    from backends.piper import _resample

    r = 2.0 ** (semis / 12.0)
    told = [{**w, "notes": [{**n, "t": float(n["t"]) * r, "len": float(n["len"]) * r, "midi": float(n["midi"]) - semis}
                            for n in w.get("notes", [])]} for w in words]
    got = _sung_whole(backend, voice, told, out, params, style)
    with wave.open(out, "rb") as w:
        rate = w.getframerate()
        audio = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").astype(np.float32) / 32767.0
    sized = _resample(audio, r)
    pcm = (np.clip(sized, -1.0, 1.0) * 32767.0).astype("<i2")
    tmp = out + ".part"
    with wave.open(tmp, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(pcm.tobytes())
    Path(tmp).replace(out)
    got = dict(got)
    got["start"] = float(got.get("start", 0.0)) / r
    got["duration"] = sized.size / float(rate)
    got["sung"] = [{**x, "t": float(x["t"]) / r} if isinstance(x, dict) and "t" in x else x for x in got.get("sung", [])]
    return got


if __name__ == "__main__":
    raise SystemExit(Host().run())
