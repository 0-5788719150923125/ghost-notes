"""Backend registry for the ghost voice host.

Adding a model means adding a module here and one REGISTRY entry. Nothing in
Godot changes - that is the whole point of the subprocess design (VOICE_PLAN.md
section 2), and it is the test of whether the interface is drawn correctly.

A backend must not import its heavy dependencies at module import time. The host
enumerates every registered backend to answer `voices`, and one missing wheel
must degrade to "that backend is unavailable" rather than taking the process
down. Import inside __init__ or later, and raise BackendError.
"""

from __future__ import annotations

import sys
from pathlib import Path
from typing import Any


class BackendError(RuntimeError):
    """Anything a user could plausibly be shown: a missing model, an absent
    dependency, a voice that will not load. Distinct from a genuine bug, which
    is allowed to raise normally and get a traceback on stderr."""


class Backend:
    """The contract. Deliberately narrow, and deliberately the same shape the
    procedural engine already satisfies, so both paths can sit behind one
    VoiceSession on the Godot side."""

    name = "base"

    # -- identity ----------------------------------------------------------

    @classmethod
    def describe(cls) -> dict:
        """Static capability report, answerable without loading anything.

        The UI is built from this rather than from assumptions: a backend that
        cannot control duration simply does not show that slider. Backends
        differ enormously in what they expose and pretending otherwise is how
        you end up with dead controls.
        """
        return {
            "name": cls.name,
            "streaming": False,  # incremental synthesis, or utterance-at-a-time
            "phoneme_input": False,  # accepts pre-computed phonemes (ghost's own G2P)
            "duration_control": False,  # global rate, at minimum
            "pitch_control": False,
            "reference_audio": False,  # voice cloning / style transfer
            "timings": False,  # returns word or phone boundaries
            "singing": False,
        }

    @classmethod
    def owns(cls, voice: str) -> bool:
        """Whether this backend recognizes a voice id, so callers need not
        track which backend a voice came from."""
        return False

    # -- work --------------------------------------------------------------

    def voices(self) -> list[dict]:
        """Installed and installable voices. Each entry MUST carry a `license`
        field: for most of these projects the code license and the checkpoint
        license differ, and the checkpoint is where the commercial risk sits
        (VOICE_PLAN.md section 8)."""
        raise NotImplementedError

    def ensure(self, voice: str) -> dict:
        """Download or prepare a voice. Separate from synthesize so a UI can
        show progress before the user is sitting waiting on audio."""
        raise NotImplementedError

    def synthesize(
        self,
        text: str,
        voice: str,
        out_path: str,
        params: dict[str, Any],
        phonemes: Any = None,
    ) -> dict:
        """Write a WAV to out_path and return metadata.

        Must return: {"wav", "sample_rate", "duration"} and, where the model can
        supply them, {"words": [{text, t0, t1}], "phones": [{p, t0, t1}]}.
        ghost's karaoke subtitles and its audio-reactive scene pipeline both key
        off those timings, so a backend that can produce them should.
        """
        raise NotImplementedError


REGISTRY: dict[str, type[Backend]] = {}


def register(cls: type[Backend]) -> type[Backend]:
    REGISTRY[cls.name] = cls
    return cls


# Where a backend reports a download as it streams: the host installs a callable
# taking (name, done_bytes, total_bytes, finished, error), and ghost shows it beside
# its own installs. None when nothing is listening (tests, the command-line tools).
progress = None


def report(
    name: str, done: int = 0, total: int = 0, finished: bool = False, error: str = ""
) -> None:
    if progress is not None:
        progress(name, done, total, finished, error)


# -- the device ----------------------------------------------------------------
#
# Every session a backend renders with is opened by `open_session`, on the providers `providers` picks:
# the CPU alone unless the host was started for the graphics card (host.py `--gpu`, `use_gpu`), and
# then CUDA first with the CPU for any operator CUDA has no kernel for. Whether CUDA runs is found
# once (`device`), by a one-node graph opened and run on it, and a fallback's reason is said once on
# stderr. A graph opened only to check it (a patch, a made graph against the stock one) stays on the
# CPU, where its samples are compared exactly.
#
# On CUDA every session draws on one arena (`_SHARED`), so Kokoro's stock, moving and sung graphs hold
# the largest call's memory once. Kokoro's STFT has no CUDA kernel and runs on the CPU (a third of a
# call). It stays there: as a convolution its DC and Nyquist bins' imaginary parts are exactly zero,
# which the graph's atan2 (`imag > 0`) makes a phase of -pi where the CPU's STFT leaves rounding of
# either sign, and the take comes out 1.9 dB quieter.

_GPU_ASKED = False
_DEVICE: dict | None = None  # {"device": "gpu" | "cpu", "why": str}, once found
_SHARED = False  # the one CUDA arena is registered

# CUDA's options. cuDNN's default convolution algorithm: on Kokoro a twelfth quicker than either
# search over sentences of new lengths, and the same take. No TF32, whose 10-bit products move a
# Kokoro plan by a frame and its spectrum away from the CPU's take.
CUDA_OPTIONS = {
    "device_id": 0,
    "cudnn_conv_algo_search": "DEFAULT",
    "arena_extend_strategy": "kSameAsRequested",
    "use_tf32": "0",
}


def use_gpu(on: bool = True) -> None:
    """Ask for the graphics card: every session `open_session` opens from now runs on CUDA where it can."""
    global _GPU_ASKED, _DEVICE
    _GPU_ASKED = bool(on)
    _DEVICE = None


def device() -> dict:
    """Where sessions run: {"device": "gpu" | "cpu", "why": why the CPU was used when the card was asked
    for, "" otherwise}. Found the first time it is asked; the reason said once on stderr."""
    global _DEVICE, _SHARED
    if _DEVICE is None:
        _DEVICE = {"device": "cpu", "why": ""}
        if _GPU_ASKED:
            why = _cuda_runs()
            _DEVICE = {"device": "cpu" if why else "gpu", "why": why}
            if why:
                print(f"ghost/voice: the voice runs on the CPU - {why}", file=sys.stderr)
            else:
                print("ghost/voice: the voice runs on the graphics card (CUDA)", file=sys.stderr)
                import onnxruntime as ort

                if not _SHARED:
                    try:
                        mem = ort.OrtMemoryInfo("Cuda", ort.OrtAllocatorType.ORT_ARENA_ALLOCATOR,
                                                int(CUDA_OPTIONS["device_id"]), ort.OrtMemType.DEFAULT)
                        # no cap, grown by what is asked (1 = kSameAsRequested), the default first chunk and dead bytes
                        ort.create_and_register_allocator_v2("CUDAExecutionProvider", mem,
                                                             {"device_id": str(CUDA_OPTIONS["device_id"])},
                                                             ort.OrtArenaCfg(0, 1, -1, -1))
                        _SHARED = True
                    except Exception as exc:  # noqa: BLE001 - each session keeps an arena of its own
                        print(f"ghost/voice: no shared CUDA arena ({_first_line(exc)})", file=sys.stderr)
    return _DEVICE


def providers() -> list:
    """The execution providers a rendering session is opened with, best first."""
    if device()["device"] == "gpu":
        return [("CUDAExecutionProvider", dict(CUDA_OPTIONS)), "CPUExecutionProvider"]
    return ["CPUExecutionProvider"]


def open_session(model, opts=None):
    """An onnxruntime session for `model` (a path or a graph's bytes) on `providers`: a graph CUDA will
    not open is opened on the CPU, said on stderr."""
    import onnxruntime as ort

    src = model if isinstance(model, (bytes, bytearray)) else str(model)
    chosen = providers()
    if len(chosen) == 1:
        return ort.InferenceSession(src, sess_options=opts, providers=chosen)
    if opts is None:
        opts = ort.SessionOptions()
    if _SHARED:
        opts.add_session_config_entry("session.use_env_allocators", "1")
    try:
        return ort.InferenceSession(src, sess_options=opts, providers=chosen)
    except Exception as exc:  # noqa: BLE001 - out of graphics memory, an operator CUDA rejects
        name = Path(src).name if isinstance(src, str) else "a graph"
        print(f"ghost/voice: {name} will not open on the graphics card ({_first_line(exc)}) - on the CPU",
              file=sys.stderr)
        return ort.InferenceSession(src, sess_options=opts, providers=["CPUExecutionProvider"])


def _cuda_runs() -> str:
    """Why CUDA cannot run this host's sessions, "" when it can: its build present, NVIDIA's libraries
    loaded from this environment, and a one-node graph opened and run on it."""
    try:
        import numpy as np
        import onnxruntime as ort
        from onnx import TensorProto, helper
    except ImportError as exc:
        return f"the voice environment is missing {exc.name}"
    if "CUDAExecutionProvider" not in ort.get_available_providers():
        return "this onnxruntime is its CPU build (the graphics card's environment is not in use)"
    ort.set_default_logger_severity(3)  # errors only: every CUDA session warns that no plugin device is registered
    if hasattr(ort, "preload_dlls"):
        try:
            ort.preload_dlls()  # CUDA, cuBLAS, cuFFT and cuDNN from NVIDIA's wheels in this environment
        except Exception as exc:  # noqa: BLE001 - the session below says whether it mattered
            print(f"ghost/voice: CUDA's libraries did not preload ({_first_line(exc)})", file=sys.stderr)
    x = helper.make_tensor_value_info("x", TensorProto.FLOAT, [4])
    y = helper.make_tensor_value_info("y", TensorProto.FLOAT, [4])
    graph = helper.make_graph([helper.make_node("Add", ["x", "x"], ["y"])], "probe", [x], [y])
    model = helper.make_model(graph, opset_imports=[helper.make_opsetid("", 13)])
    model.ir_version = 8
    try:
        sess = ort.InferenceSession(model.SerializeToString(),
                                    providers=[("CUDAExecutionProvider", dict(CUDA_OPTIONS)), "CPUExecutionProvider"])
        if sess.get_providers()[0] != "CUDAExecutionProvider":
            return "onnxruntime could not start CUDA (no NVIDIA driver, or its libraries did not load)"
        got = sess.run(None, {"x": np.arange(4, dtype=np.float32)})[0]
        if not np.array_equal(got, np.arange(4, dtype=np.float32) * 2):
            return "CUDA ran but answered wrongly"
    except Exception as exc:  # noqa: BLE001 - no device, a card this build has no kernels for
        return f"CUDA did not run ({_first_line(exc)})"
    return ""


def _first_line(exc: BaseException) -> str:
    text = str(exc).strip()
    return (text.splitlines()[0] if text else type(exc).__name__)[:200]


# Import for side effects. Each module registers itself and must not import its
# heavy dependencies at module scope.
from . import piper  # noqa: E402,F401
from . import kokoro  # noqa: E402,F401
