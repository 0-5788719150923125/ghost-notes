"""Kokoro voices (hexgrad/Kokoro-82M v1.0), run as raw ONNX beside Piper - an inference trial
(next/voice_engines.md, "Kokoro").

WHAT IT IS. StyleTTS 2 without the diffusion, 82M parameters: PL-BERT reads the phonemes, a duration
predictor plans each token's frames (rounded, at least one), the F0 and energy curves are predicted
from the aligned features, and an iSTFTNet decoder makes 24 kHz audio of them. A voice is a style
vector - 128 numbers of timbre for the decoder, 128 of prosody for the predictor - taken by the
sentence's token count from a [510, 1, 256] pack, and at most 510 tokens are read at once.

WHAT IT SHARES WITH PIPER: everything around the model. ghost's tokens, eSpeak's reading of them (the
homographs, the lexicon), the rests floored in the plan and spliced after it, the trail, the lead,
stress held through `dur_scale`, the arc's pitch, the Tone played back - so this is PiperBackend with
the model swapped: the ids, the graph, the frame (600 samples, 25 ms; Piper's is 256 at 22,050,
11.6 ms) and the voices.

THE GRAPH is onnx-community's timestamped export (Apache-2.0, pinned below), patched once where it
is first used (`_patch`) the way a Piper voice is: `dur_scale` multiplies the planned durations before
they are rounded, `rest_floor` floors them after, and `durations` hands back the whole frames the
decoder used - the export's own output was the plan before rounding. Unfed, the patched graph's audio
is the stock graph's sample for sample, and frames x 600 is the take's length exactly (measured
2026-10-25). Nothing in it samples: one text and one voice make one take.

THE SYMBOLS. Kokoro's English was taught misaki's notation, not eSpeak's: one letter a diphthong (A
eɪ, I aɪ, W aʊ, Y ɔɪ, O oʊ, Q əʊ), ʤ and ʧ for the affricates, T for the American flap, no length
marks in American. `kokoro_symbols` writes eSpeak's reading in it by misaki's own table for its
eSpeak fallback (misaki/espeak.py, `EspeakFallback`), each symbol keeping the word it came from; the
phones go back in eSpeak's symbols, so a mouth reads them as it reads Piper's.

NOT HERE, an inference trial: `noise_scale` and `noise_w` (the Tone's `noise` columns do nothing on
these voices), F0 as an input (the arc and the Tone still resample), Kokoro's own dwell at a mark (the
pause figures are Piper's measurements), the vowel probe, and voices trained here.

THE RATE. Rendered at 24 kHz and handed back at 22,050 (`OUT_RATE`) through the band-limited
resampler: a reading joins its takes at one rate, and a cast may mix Kokoro and Piper voices.
"""

from __future__ import annotations

import json
import os
import sys
import urllib.request
from pathlib import Path
from typing import Any

from . import BackendError, register, report
from .piper import (
    _LENGTHENS,
    _MARK_SYMBOLS,
    _STRESS,
    _UNSAID,
    _VOWELS,
    DUR_SCALE_INPUT,
    REST_FLOOR_INPUT,
    TRAIL_STRETCH,
    PiperBackend,
    _final_rimes,
    _hiss_codas,
    _nuclei,
    _reporter,
    _resample,
)

MODEL = "model.onnx"  # full precision: this is a listening trial, and the quantized graphs are not it
TOKENIZER = "tokenizer.json"

SR = 24000
HOP = 600
OUT_RATE = 22050
MAX_TOKENS = 510
# ITS AUDIO RUNS AHEAD OF ITS PLAN (2026-10-25, the user: "the 'h' from 'happy' STARTS on the left side
# of the comma"): the voicing the plan puts in each frame is heard PLAN_LEAD earlier - measured over 20
# sentences of two voices, a median 55 ms (Emma) and 48 (Heart), the middle half of them within 15 ms of
# it, the same in a sentence's first half as in its second. So every time the plan says - a word, its
# edges, a rest, a phone - is told that much earlier, and what is placed by them (the cut of a rest, the
# trail, the subtitles, a mouth) is placed on the sound. Uncorrected, the cut of the rest after "arms,"
# had been looked for past the "h" and found the closure inside "happy": "ha ... ppy".
PLAN_LEAD = 0.05
GAP_REACH = 0.05  # how far past the (corrected) word boundary a rest's cut is looked for
# ...and how far before it (2026-10-26, "You've always felt it, haven't you, my love?"): reaching
# GAP_REACH back into "it" found the silence of its t's closure, and the release went over the rest,
# a tick before "haven't". A word's last sound ends by its corrected end, give or take this much.
GAP_BACK = 0.015
# THE WORD BEFORE A REST IS HELD AT LEAST THIS LONG ON ITS LAST VOWEL (seconds at length scale 1; the
# trail's share of it, as its hold is). Piper's hold is a ratio (TRAIL_STRETCH) and on 25 ms frames a
# ratio is wrong both ways: the 50 ms "oo" of "you," rounded 1.25 times back to two frames, and held
# 1.6 times, "stays," and "flame," (five and six frames) were drawn out ("someone stayyys", the user,
# 2026-10-26). A floor lengthens the short vowel alone and leaves a long one as planned.
HOLD_LEAST = 0.09
STYLE = 256
PAD_ID = 0

LICENSE = (
    "Apache-2.0 (hexgrad/Kokoro-82M). Its training data includes synthetic audio from closed "
    "commercial voices - a provenance question before any commercial use"
)

# THE ENGLISH PACKS of v1.0, a speaker number each: (pack, accent, sex, what else is said of it) - the
# grade hexgrad's own in VOICES.md (the quality and amount of the voice's training data). THE ORDER IS THE
# NUMBERS: a note keeps its speaker as an index, so a pack added later goes at the end and none is ever
# moved. Most read best between 100 and 200 tokens and weakly under 10 to 20.
PACKS: list[tuple[str, str, str, str]] = [
    ("af_heart", "US", "F", "grade A"),
    ("af_bella", "US", "F", "grade A-"),
    ("af_nicole", "US", "F", "grade B-"),
    ("af_aoede", "US", "F", "grade C+"),
    ("af_kore", "US", "F", "grade C+"),
    ("af_sarah", "US", "F", "grade C+"),
    ("af_alloy", "US", "F", "grade C"),
    ("af_nova", "US", "F", "grade C"),
    ("af_sky", "US", "F", "grade C-"),
    ("af_jessica", "US", "F", "grade D"),
    ("af_river", "US", "F", "grade D"),
    ("am_fenrir", "US", "M", "grade C+"),
    ("am_michael", "US", "M", "grade C+"),
    ("am_puck", "US", "M", "grade C+"),
    ("am_echo", "US", "M", "grade D"),
    ("am_eric", "US", "M", "grade D"),
    ("am_liam", "US", "M", "grade D"),
    ("am_onyx", "US", "M", "grade D"),
    ("am_santa", "US", "M", "grade D-"),
    ("am_adam", "US", "M", "grade F+"),
    ("bf_emma", "GB", "F", "grade B-"),
    ("bf_isabella", "GB", "F", "grade C"),
    ("bf_alice", "GB", "F", "grade D"),
    ("bf_lily", "GB", "F", "grade D"),
    ("bm_fable", "GB", "M", "grade C"),
    ("bm_george", "GB", "M", "grade C"),
    ("bm_lewis", "GB", "M", "grade D+"),
    ("bm_daniel", "GB", "M", "grade D"),
]
ACCENTS = {"US": "American", "GB": "British"}

# THE ENGLISH PACKS of v1.1-zh: an hour each of crowdsourced synthetic English (its model card), ungraded.
# Vale is "an older British female".
PACKS_11: list[tuple[str, str, str, str]] = [
    ("af_maple", "US", "F", "ungraded"),
    ("af_sol", "US", "F", "ungraded"),
    ("bf_vale", "GB", "F", "older, ungraded"),
]

# THE CHECKPOINTS, one voice each in the Voice list, their packs its speakers - as libritts-high's readers are
# under it - so the Voice list names a model and the Speaker row picks who reads in it (2026-10-25, the user:
# "voice should be used more like a family of voices, then a secondary option should be for selecting the
# various checkpoints within"). Each is onnx-community's export at the commit last verified (2026-10-25):
# the graph, the tokenizer (its vocab is the ids) and a file per pack, under `dir` of the voices' root.
# v1.1-zh is a second checkpoint, not a strict upgrade (its card): it drops most of v1.0's voices for
# Chinese ones and adds three English, Vale a British woman (2026-10-25, the user: "I'm looking for a
# better female GB voice. 'Emma' is decent, but it's a B-, and it does click/pop sometimes").
FAMILIES: dict[str, dict] = {
    "kokoro": {
        "name": "kokoro",
        "base": "https://huggingface.co/onnx-community/Kokoro-82M-v1.0-ONNX-timestamped/resolve/"
        "dd4401a9add81ac692d20e240d22ec9dda82cc29",
        "dir": "",
        "derivation": "hexgrad/Kokoro-82M v1.0",
        "packs": PACKS,
        "about": "Grades: Kokoro's own, of each voice's training data (hexgrad, VOICES.md).",
    },
    "kokoro-1.1": {
        "name": "kokoro 1.1",
        "base": "https://huggingface.co/onnx-community/Kokoro-82M-v1.1-zh-ONNX/resolve/"
        "6cc0f0d2ebe369a68b0df87c2b65c1af8c0ac3e3",
        "dir": "v1.1",
        "derivation": "hexgrad/Kokoro-82M-v1.1-zh (its English: an hour a voice of crowdsourced synthetic speech)",
        "packs": PACKS_11,
        "about": "Kokoro v1.1-zh's English voices: an hour each of synthetic speech, not graded (hexgrad).",
    },
}

# ESPEAK'S READING IN MISAKI'S SYMBOLS - misaki's table for its eSpeak fallback (`E2M`, then its
# American and British replacements), read WITHOUT eSpeak's tie marks: ghost's eSpeak reading has none,
# so two symbols of one word that spell a diphthong or an affricate are taken as one. The longest match
# wins, so "eə" is British ɛː before "e" alone is A.
_SHARED = {
    "eɪ": "A",
    "aɪ": "I",
    "aʊ": "W",
    "ɔɪ": "Y",
    "dʒ": "ʤ",
    "tʃ": "ʧ",
    "e": "A",
    "ɚ": "əɹ",
    "r": "ɹ",
    "x": "k",
    "ç": "k",
    "ɐ": "ə",
    "ɬ": "l",
    "̃": "",
    "ʲ": "",
    "o": "ɔ",
    # kokoro v1.0's misaki writes the flap and the glottal stop so (`version != "2.0"`)
    "ɾ": "T",
    "ʔ": "t",
}
_AMERICAN = {**_SHARED, "oʊ": "O", "ɜːɹ": "ɜɹ", "ɜː": "ɜɹ", "ɪə": "iə", "ː": ""}
_BRITISH = {**_SHARED, "eə": "ɛː", "iə": "ɪə", "əʊ": "Q"}
SYLLABIC = "̩"
SMALL_SCHWA = "ᵊ"


def kokoro_symbols(symbols: list, british: bool) -> list:
    """eSpeak's (symbol, source) pairs as Kokoro's: [(symbol, source, positions)], `positions` the
    places in `symbols` it was written from - one unit, which may be two of Kokoro's symbols (ɚ is
    əɹ) or two of eSpeak's (eɪ is A), and none for what is dropped. A syllabic consonant is a small
    schwa before it, misaki's ᵊ. A pair is merged only inside one source: a diphthong is one word's."""
    table = _BRITISH if british else _AMERICAN
    longest = max(len(k) for k in table)
    out: list = []
    j = 0
    n = len(symbols)
    while j < n:
        sym, src = symbols[j]
        if j + 1 < n and symbols[j + 1][0] == SYLLABIC and symbols[j + 1][1] == src:
            out.append((SMALL_SCHWA, src, (j, j + 1)))
            out.append((_one(sym, table), src, (j, j + 1)))
            j += 2
            continue
        if sym == SYLLABIC:  # a mark with no base before it in its word: nothing to say
            j += 1
            continue
        took = 1
        written = sym
        for size in range(min(longest, n - j), 1, -1):
            run = symbols[j : j + size]
            if any(s != src for _, s in run):
                continue
            key = "".join(s for s, _ in run)
            if key in table:
                took, written = size, table[key]
                break
        else:
            written = table.get(sym, sym)
        at = tuple(range(j, j + took))
        for ch in written:
            out.append((ch, src, at))
        j += took
    return out


def _one(sym: str, table: dict) -> str:
    got = table.get(sym, sym)
    return got[:1] if got else sym


# Every eSpeak symbol `kokoro_symbols` writes into Kokoro's, so a reading checked against the voice's
# map (lexicon.py) finds them there.
_FROM_ESPEAK = frozenset(
    ch for table in (_AMERICAN, _BRITISH) for key in table for ch in key
) | {SYLLABIC}


@register
class KokoroBackend(PiperBackend):
    name = "kokoro"
    hop = HOP
    # NO LEAD IS QUIETED: no rest is floored here, and a floored rest is what made the next word's lead
    # long. The trail - the word before a rest let go of - is made, on the plan told PLAN_LEAD earlier.
    quiets_lead = False
    # ...and runs right up to where the next word starts: Kokoro holds a word through a comma it reads
    # straight through, so the next word's start walked back over sound was the same word's vowel ("you,"
    # faded half way, then back at full, and the cut in that dip put its second half before "my"). Where
    # the voice runs into the next word, the trail's way back up runs on into it, never a step.
    trail_early = 0.0
    trail_through = True

    @classmethod
    def describe(cls) -> dict:
        d = PiperBackend.describe()
        d.update(
            {
                "name": cls.name,
                "phoneme_input": True,  # eSpeak's reading, in misaki's symbols
                "duration_control": True,  # speed, and the patched plan
                "pitch_control": False,  # the F0 curve is in the graph, not yet an input
                "timings": True,  # the rounded plan, exact
            }
        )
        return d

    @classmethod
    def owns(cls, voice: str) -> bool:
        return voice in FAMILIES

    @classmethod
    def _trained(cls, voice: str):
        return None  # none are trained here (next/voice_engines.md, "Kokoro")

    def __init__(self) -> None:
        super().__init__()
        self._models: dict = {}  # checkpoint -> its graph, every pack of it shares
        self._vocabs: dict = {}  # checkpoint -> {symbol: id}
        self._speakers: dict = {}  # (checkpoint, pack index) -> its cfg (`_speaker`)

    # -- storage -----------------------------------------------------------

    @staticmethod
    def _root() -> Path:
        root = PiperBackend._root().parent / "kokoro"
        root.mkdir(parents=True, exist_ok=True)
        return root

    @classmethod
    def _home(cls, family: str) -> Path:
        d = FAMILIES[family]["dir"]
        return cls._root() / d if d else cls._root()

    def voices(self) -> list[dict]:
        out = []
        for vid, fam in FAMILIES.items():
            home = self._home(vid)
            out.append(
                {
                    "id": vid,
                    "name": fam["name"],
                    "backend": self.name,
                    "license": LICENSE,
                    "derivation": fam["derivation"],
                    "speakers": len(fam["packs"]),
                    # WHO EACH SPEAKER NUMBER IS, said by the host (VoiceReaders.offer): the libritts
                    # readers are described from files, these from the tables above
                    "readers": [
                        {"reader": pack, "g": sex, "d": "%s, %s, %s" % (pack.split("_", 1)[1], ACCENTS[accent], said)}
                        for pack, accent, sex, said in fam["packs"]
                    ],
                    "readers_about": fam["about"],
                    "installed": (home / MODEL).exists() and (home / TOKENIZER).exists(),
                    "notes": "%d voices; a speaker number picks one" % len(fam["packs"]),
                }
            )
        return out

    def ensure(self, voice: str) -> dict:
        """Fetched, and the graph OPENED - patched the first time - so the first take of a reading does
        not wait seconds on it: the reading asks this as its voice is listed and as one is picked
        (`VoiceHost.ensure`)."""
        got = self._download(voice)
        self._graph(voice)
        return {"voice": voice, "installed": True, "downloaded": bool(got), "bytes": got}

    def _download(self, voice: str) -> int:
        """The checkpoint's graph and tokenizer, fetched unless they are here: the bytes fetched."""
        if not self.owns(voice):
            raise BackendError(f"unknown Kokoro voice '{voice}'")
        home = self._home(voice)
        got = self._fetch(voice, home / MODEL, "onnx/" + MODEL, "voice " + FAMILIES[voice]["name"])
        got += self._fetch(voice, home / TOKENIZER, TOKENIZER)
        if got:
            report("voice " + FAMILIES[voice]["name"], finished=True)
        return got

    @staticmethod
    def _fetch(family: str, dest: Path, rel: str, progress: str = "") -> int:
        """`rel` of the checkpoint's pinned export to `dest`, unless it is there: the bytes fetched."""
        if dest.exists():
            return 0
        dest.parent.mkdir(parents=True, exist_ok=True)
        tmp = dest.with_name(dest.name + ".part")
        url = "%s/%s" % (FAMILIES[family]["base"], rel)
        try:
            urllib.request.urlretrieve(url, tmp, _reporter(progress) if progress else None)
        except Exception as exc:  # noqa: BLE001
            tmp.unlink(missing_ok=True)
            report(progress or "voice kokoro", finished=True, error=f"could not fetch {url}: {exc}")
            raise BackendError(f"could not fetch {url}: {exc}") from exc
        tmp.replace(dest)  # atomic: a reader sees the whole file or none
        return dest.stat().st_size

    # -- model -------------------------------------------------------------

    def _graph(self, family: str):
        """The checkpoint's graph, fetched, patched and opened the first time it is asked for."""
        if family not in self._models:
            self._download(family)
            home = self._home(family)
            self._models[family] = self._open(home / MODEL)
            tok = json.loads((home / TOKENIZER).read_text(encoding="utf-8"))
            self._vocabs[family] = {str(k): int(v) for k, v in tok["model"]["vocab"].items()}
        return self._models[family]

    def _pack_array(self, family: str, pack: str):
        """A pack's styles, [rows, 1, STYLE], fetched the first time (half a megabyte)."""
        import numpy as np

        path = self._home(family) / "voices" / f"{pack}.bin"
        self._fetch(family, path, f"voices/{pack}.bin")
        styles = np.fromfile(path, dtype=np.float32)
        if styles.size % STYLE:
            raise BackendError(f"Kokoro voice '{pack}' is not a whole pack of {STYLE}-number styles")
        return styles.reshape(-1, 1, STYLE)

    def _speaker(self, family: str, index: int) -> dict:
        """Speaker `index` of a checkpoint, its cfg in the shape Piper's path reads (clamped to the packs
        there are): its pack, its checkpoint's symbols, and eSpeak in its own accent - a British pack is
        read British."""
        packs = FAMILIES[family]["packs"]
        i = min(max(int(index), 0), len(packs) - 1)
        if family not in self._vocabs:
            self._graph(family)  # the symbols are the graph's: a speaker built before it would have none
        if (family, i) not in self._speakers:
            pack, accent, _sex, _said = packs[i]
            british = accent == "GB"
            vocab = self._vocabs.get(family, {})
            pmap = {ch: [n] for ch, n in vocab.items()}
            for ch in _FROM_ESPEAK:
                pmap.setdefault(ch, [])
            self._speakers[(family, i)] = {
                "audio": {"sample_rate": SR},
                "phoneme_id_map": pmap,
                "espeak": {"voice": "en-gb" if british else "en-us"},
                "inference": {"length_scale": 1.0},
                "num_speakers": 1,
                "kokoro": {"pack": self._pack_array(family, pack), "british": british, "vocab": vocab},
            }
        return self._speakers[(family, i)]

    def _load(self, voice: str):
        """Piper's contract, for a caller that asks it: the graph and speaker 0. No vowel probe - what it
        measures is a Piper checkpoint's (vowel_probe.py)."""
        if not self.owns(voice):
            raise BackendError(f"unknown Kokoro voice '{voice}'")
        return self._graph(voice), self._speaker(voice, 0)

    @staticmethod
    def _options():
        """A session that leaves a live show its share of the machine: a thread for each core but one, and
        no spinning between operators. Measured 2026-10-25 on four cores, a sentence of 5.9 s: the default
        (a thread a core, spinning) made it at 2.70x real time with 3.9 cores busy; this at 2.60x with 2.6
        - the reading's own Godot, its show and its audio need the rest ("playback kept freezing")."""
        import onnxruntime as ort

        opts = ort.SessionOptions()
        opts.log_severity_level = 3  # the protocol owns stdout
        opts.intra_op_num_threads = max(1, _cores() - 1)
        opts.add_session_config_entry("session.intra_op.allow_spinning", "0")
        return opts

    def _open(self, path: Path):
        """The graph, patched the first time it is opened (`_patch`)."""
        import onnxruntime as ort

        opts = self._options()
        sess = ort.InferenceSession(str(path), sess_options=opts, providers=["CPUExecutionProvider"])
        takes = {i.name for i in sess.get_overridable_initializers()}
        if REST_FLOOR_INPUT in takes and DUR_SCALE_INPUT in takes:
            return sess
        del sess
        if not self._patch(path):
            print(
                "ghost/voice: the Kokoro graph is unpatched - no rest floor at marks or emphasis",
                file=sys.stderr,
            )
        return ort.InferenceSession(str(path), sess_options=opts, providers=["CPUExecutionProvider"])

    @staticmethod
    def _patch(path: Path) -> bool:
        """Give the duration plan Piper's two inputs and hand back the plan the decoder used.

        The export plans `durations` (the predictor's sum over its sigmoids, over `speed`), rounds it,
        clips it at one frame and expands the tokens by it. Patched: the plan times `dur_scale` (a
        multiplier per token, default 1) BEFORE the Round - a whole frame is 25 ms, and most tokens are
        planned at one to three of them, so a stretch after the Round would mostly land back on the
        same frame - then floored by `rest_floor` (frames per token, default none) and clipped, and
        `durations` is that clip: whole frames, what the audio was made of. Unfed, the graph renders
        exactly what it did. The patched graph is opened before it replaces the file, so one that will
        not load is never written. False when it cannot be patched (no `onnx`, an unknown shape).
        """
        try:
            import numpy as np
            import onnx
            import onnxruntime as ort
            from onnx import TensorProto, helper, numpy_helper
        except ImportError:
            return False
        model = onnx.load(str(path))
        graph = model.graph
        rounds = [n for n in graph.node if n.op_type == "Round"]
        if len(rounds) != 1:
            print(f"ghost/voice: Kokoro graph has {len(rounds)} Round nodes, expected 1 - not patching",
                  file=sys.stderr)
            return False
        rnd = rounds[0]
        clips = [n for n in graph.node if rnd.output[0] in n.input]
        planners = [n for n in graph.node if rnd.input[0] in n.output]
        if len(clips) != 1 or clips[0].op_type != "Clip" or len(planners) != 1:
            print("ghost/voice: Kokoro graph's plan is not Round -> Clip - not patching", file=sys.stderr)
            return False
        clip, plan = clips[0], planners[0]
        # WHERE THE PLAN COMES BACK. v1.0's export hands back the plan BEFORE its Round (`durations` is
        # the Div's output): that name is moved onto the clipped plan. v1.1's hands back the clip already
        # (`duration`, cast and squeezed): left as it is. A graph that does neither is not patched.
        outs = [o.name for o in graph.output]
        planned = plan.output[0]
        if planned in outs:
            plan.output[0] = "ghost_durations_planned"
            planned = "ghost_durations_planned"
        elif not _reaches(graph, clip.output[0], outs):
            print("ghost/voice: Kokoro graph does not hand back its plan - not patching", file=sys.stderr)
            return False
        nodes = list(graph.node)
        nodes.insert(
            nodes.index(plan) + 1,
            helper.make_node(
                "Mul", [planned, DUR_SCALE_INPUT], ["ghost_durations_scaled"], name="ghost_dur_scale",
            ),
        )
        rnd.input[0] = "ghost_durations_scaled"
        nodes.insert(
            nodes.index(rnd) + 1,
            helper.make_node(
                "Max", [rnd.output[0], REST_FLOOR_INPUT], ["ghost_durations_floored"],
                name="ghost_rest_floor",
            ),
        )
        clip.input[0] = "ghost_durations_floored"
        if planned == "ghost_durations_planned":
            nodes.insert(
                nodes.index(clip) + 1,
                helper.make_node("Identity", [clip.output[0]], ["durations"], name="ghost_durations"),
            )
        del graph.node[:]
        graph.node.extend(nodes)
        for name, value in ((DUR_SCALE_INPUT, 1.0), (REST_FLOOR_INPUT, 0.0)):
            graph.initializer.append(numpy_helper.from_array(np.full(1, value, np.float32), name))
            graph.input.append(helper.make_tensor_value_info(name, TensorProto.FLOAT, None))
        tmp = path.with_name(path.name + ".patching")
        onnx.save(model, str(tmp))
        try:
            opts = ort.SessionOptions()
            opts.log_severity_level = 3
            ort.InferenceSession(str(tmp), sess_options=opts, providers=["CPUExecutionProvider"])
        except Exception as exc:  # noqa: BLE001 - a graph that will not load is never written
            tmp.unlink(missing_ok=True)
            print(f"ghost/voice: patched Kokoro graph will not load ({exc})", file=sys.stderr)
            return False
        tmp.replace(path)
        return True

    # -- work --------------------------------------------------------------

    def synthesize(
        self,
        text: str,
        voice: str,
        out_path: str,
        params: dict[str, Any],
        phonemes: Any = None,
    ) -> dict:
        tokens = params.get("tokens")
        if not tokens:
            raise BackendError("Kokoro reads ghost's tokens; a bare phoneme string is Piper's path")
        if not self.owns(voice):
            raise BackendError(f"unknown Kokoro voice '{voice}'")
        sess = self._graph(voice)
        cfg = self._speaker(voice, int(params.get("speaker", 0) or 0))
        return self._synth_tokens(list(tokens), voice, out_path, params, cfg, sess)

    def _symbols(self, tokens: list, phonemizer: str, espeak_voice: str = "en-us", voice: str = "") -> list:
        """Piper's, without its lead-in spaces (LEAD_IN_SPACES) or its last word-space: the lead-in gives a VITS graph somewhere to
        start that is not a word, and Kokoro's first pad already carries its own (14 frames, 350 ms,
        in the first sentence measured - more than the seam allows, so it is trimmed, `_trim_ends`)."""
        out = super()._symbols(tokens, phonemizer, espeak_voice, voice)
        k = 0
        while k < len(out) and out[k] == (" ", 0):
            k += 1
        # ...nor the word-space Piper's path puts after the last word: Kokoro was never taught an
        # utterance that ends on one, and rendered it as a sound - a short take ended on a hiss 32 to
        # 40 dB under its peak where without it the tail falls 55 to 90 (2026-10-25, the Cards Test's
        # "Oh. Oh, wow."; Isabella's one-word sentences heard as "Ose. Wouse. Nouse.")
        end = len(out)
        while end > k and out[end - 1][0] == " ":
            end -= 1
        return out[k:end]

    def _render_symbols(
        self,
        symbols: list,
        cfg: dict,
        sess,
        params: dict,
        floors: dict | None = None,
        stretch: dict | None = None,
        opening: float = 0.0,
        hold: dict | None = None,
    ):
        """(symbol, source) pairs -> audio, plus a time span per source - Piper's contract
        (`PiperBackend._render_symbols`), on Kokoro's ids: one id a symbol, a pad at each end, no
        blanks between. What the plan is told: a stretch on a source's nucleus, a hold on its final
        rime and its last vowel floored at HOLD_LEAST (shared with its length mark), the opening vowel
        floored - and no rest (below).

        A sentence over MAX_TOKENS is read in pieces cut at a word-space - after a mark where one
        is in reach - each with its own pads and its own style, the pieces' plans laid end to end.
        """
        import numpy as np

        kk = cfg["kokoro"]
        vocab = kk["vocab"]
        frame_s = HOP / float(SR)
        nucleus = _nuclei(symbols)
        rime = _final_rimes(symbols, set(hold)) if hold else set()
        first = next(
            (src for sym, src in symbols if src >= 0 and sym != " " and sym not in _MARK_SYMBOLS),
            None,
        )
        ls = float(params.get("length_scale", 1.0))
        open_frames = float(np.ceil(opening * ls / frame_s - 1e-9)) if opening > 0.0 else 0.0

        units = kokoro_symbols(symbols, bool(kk["british"]))

        def vowel_of_rime(ksym, src, at) -> bool:
            """A unit of the final vowel of a held source: a vowel of its rime, or the length mark."""
            return src in hold and any(j in rime for j in at) and (
                ksym == "ː" or any(symbols[j][0] in _VOWELS for j in at))

        # each held source's last vowel at least HOLD_LEAST in all, its units sharing it ("uː" is two)
        least: dict = {}
        if hold:
            shares: dict = {}
            for ksym, src, at in units:
                if vowel_of_rime(ksym, src, at):
                    shares[src] = shares.get(src, 0) + 1
            for src, k in shares.items():
                weight = max(0.0, (float(hold[src]) - 1.0) / TRAIL_STRETCH)
                frames = float(np.ceil(HOLD_LEAST * weight * ls / frame_s - 1e-9))
                least[src] = float(np.ceil(frames / k))
        ids: list[int] = []
        owner: list[int] = []
        rest_of: list[int] = []
        sound: list[bool] = []
        floor: list[float] = []
        scale: list[float] = []
        unit_of: list[int] = []  # which place in `units` each id is, -1 for a pad
        missing: list[str] = []
        opened = False
        for u, (ksym, src, at) in enumerate(units):
            kid = vocab.get(ksym)
            if kid is None:
                missing.append(ksym)
                continue
            # NO REST IS FLOORED: Kokoro given frames on a word-space (or a mark) does not rest in them, it
            # holds the word through them - 20 frames on the space after "dawn," rendered 500 ms of voice at
            # 16 to 20 dB under the peak - and the rest spliced in was cut through it. Unfloored, the word
            # falls away to 45 dB under by itself, and the splicer measures that and rests the remainder
            # (`_splice_pauses`, in the window `_gap` searches). The opening vowel's floor is a vowel's,
            # and so is the held one's.
            rest = 0.0
            core = any(j in nucleus for j in at)
            mul = float(stretch.get(src, 1.0)) if stretch and core else 1.0
            if hold and any(j in rime for j in at):
                mul *= float(hold.get(src, 1.0))
            if src in least and vowel_of_rime(ksym, src, at):
                rest = least[src]
            if core and src == first and open_frames > 0.0 and not opened and ksym != _STRESS:
                rest = max(rest, open_frames)
                opened = True
            ids.append(int(kid))
            owner.append(src)
            rest_of.append(src if ksym == " " else -2)
            sound.append(ksym != " " and ksym not in _MARK_SYMBOLS)
            floor.append(rest)
            scale.append(mul)
            unit_of.append(u)
        for sym in sorted(set(missing)):
            if sym in self._warned_symbols:
                continue
            self._warned_symbols.add(sym)
            print("ghost/voice: dropping U+%04X (%r), absent from Kokoro's symbols" % (ord(sym), sym),
                  file=sys.stderr)

        audio_parts: list = []
        frames_parts: list = []
        fed_floor = any(floor)
        fed_scale = any(m != 1.0 for m in scale)
        takes = {i.name for i in getattr(sess, "get_overridable_initializers", list)()}
        speed = 1.0 / max(ls, 1e-3)
        lay_owner: list[int] = []
        lay_rest: list[int] = []
        lay_sound: list[bool] = []
        lay_unit: list[int] = []
        lay_floor: list[float] = []
        for a, b in _pieces(ids, units, unit_of):
            body = ids[a:b]
            n = max(1, len(body))
            pack = kk["pack"]
            feeds = {
                "input_ids": np.array([[PAD_ID, *body, PAD_ID]], dtype=np.int64),
                "style": np.asarray(pack[min(n, pack.shape[0]) - 1], dtype=np.float32).reshape(1, STYLE),
                "speed": np.array([speed], dtype=np.float32),
            }
            fl = [0.0, *floor[a:b], 0.0]
            sc = [1.0, *scale[a:b], 1.0]
            if fed_floor and REST_FLOOR_INPUT in takes:
                feeds[REST_FLOOR_INPUT] = np.array(fl, dtype=np.float32)
            if fed_scale and DUR_SCALE_INPUT in takes:
                feeds[DUR_SCALE_INPUT] = np.array(sc, dtype=np.float32)
            out = sess.run(None, feeds)
            audio_parts.append(np.asarray(out[0]).reshape(-1).astype(np.float32))
            planned = np.asarray(out[1]).reshape(-1).astype(np.float64)
            # an unpatched graph hands back the plan before its Round and Clip: done here as there
            frames_parts.append(planned if REST_FLOOR_INPUT in takes else np.maximum(np.round(planned), 1.0))
            lay_owner += [-1, *owner[a:b], -1]
            lay_rest += [-2, *rest_of[a:b], -2]
            lay_sound += [False, *sound[a:b], False]
            lay_unit += [-1, *unit_of[a:b], -1]
            lay_floor += fl
        audio = np.concatenate(audio_parts) if audio_parts else np.zeros(1, dtype=np.float32)
        frames = np.concatenate(frames_parts) if frames_parts else np.zeros(0)
        if frames.size == len(lay_owner):
            audio = _quiet_tail(audio, _last_said(symbols, units, unit_of, sound))
            audio, frames = _trim_ends(audio, frames, lay_sound, frame_s)

        # What Piper's render leaves for the token path, read the same way (`_render_symbols` there).
        self._last_frames = None
        self._last_floor = None
        self._last_rests = []
        self._last_edges = {}
        self._last_phones = []
        self._last_hisses = _hiss_codas(symbols)
        spans: dict = {}
        if frames.size != len(lay_owner):
            return audio, spans
        self._last_frames = frames
        if fed_floor and REST_FLOOR_INPUT in takes:
            self._last_floor = np.array(lay_floor, dtype=np.float32)
        # every time from here on is the plan's less PLAN_LEAD (never before the take's start)
        t = -PLAN_LEAD
        run_at = 0.0
        run_of = -1
        spoke = False
        said: dict = {}  # unit -> (t0, t1)
        for dur, who, rest, heard, u in zip(frames * frame_s, lay_owner, lay_rest, lay_sound, lay_unit):
            a, b = max(0.0, t), max(0.0, t + dur)
            if heard and who >= 0:
                e = self._last_edges.get(who)
                self._last_edges[who] = (a if e is None else e[0], b)
            if heard and u >= 0:
                e = said.get(u)
                said[u] = (a if e is None else e[0], b)
            if rest == -2:
                if run_of >= 0 and spoke and who >= 0:
                    self._last_rests.append((run_at, a, run_of))
                spoke = spoke or who >= 0
                run_of = -1
                run_at = b
            elif rest >= 0:
                run_of = rest
            if who >= 0:
                if who not in spans:
                    spans[who] = [a, b]
                else:
                    spans[who][1] = b
            t += dur
        self._last_phones = _phones(units, said, symbols)
        return audio, spans

    @staticmethod
    def _gap(edges: dict, ti, frame: float):
        """Where a rest after token `ti` may be cut: from GAP_BACK before the end the plan, told PLAN_LEAD
        earlier, gives the word to GAP_REACH past the next word's start - what is left of its error - and
        never past either word. Not wider: where Kokoro reads through a comma there is no silence between
        the words, and a window reaching into either found the longest silence inside it - "happy"'s
        closure, and "it"'s, which put its t's release after the rest."""
        here, nxt = edges.get(ti), edges.get(ti + 1)
        if here is None or nxt is None:
            return None
        lo = max(float(here[0]), float(here[1]) - GAP_BACK)
        hi = min(float(nxt[1]), float(nxt[0]) + GAP_REACH)
        return (lo, hi) if hi > lo else None

    @staticmethod
    def _nominal(frames, ratio: float, sr: int, floor=None) -> float:
        """`_nominal_seconds` for a ROUNDED plan: a token planned at `m` frames was asked for between
        m - 1/2 and m + 1/2, so at another scale it falls in that interval over the ratio, and the
        mean of the Round over it is closed form (the integral of a staircase). One frame is the
        clip's, and a floored token keeps its floor."""
        import numpy as np

        if frames is None or ratio <= 0.0:
            return 0.0

        def area(y):
            """The integral of floor() from 0 to y, y >= 0."""
            k = np.floor(y)
            return k * (k - 1.0) * 0.5 + k * (y - k)

        m = np.asarray(frames, dtype=np.float64)
        lo = np.maximum(m - 0.5, 0.0) / ratio
        hi = (m + 0.5) / ratio
        width = np.maximum(hi - lo, 1e-12)
        exp = (area(hi + 0.5) - area(lo + 0.5)) / width
        exp = np.where(m <= 1.0, 1.0, exp)
        if floor is not None:
            f = np.asarray(floor, dtype=np.float64)
            exp = np.where((f > 0.0) & (m <= f), m, exp)
        return float(np.maximum(exp, 1.0).sum()) * HOP / float(sr)

    @staticmethod
    def _delivered(audio, sr: int):
        """At OUT_RATE, the rate every take of a reading is joined at. The seconds are the same."""
        if sr == OUT_RATE or audio.size < 2:
            return audio, sr
        return _resample(audio, sr / float(OUT_RATE)), OUT_RATE


# THE SILENCE AT A TAKE'S ENDS, as the seam between two sentences was measured on Piper (piper.py `DWELL`,
# the full stop's 0.18: 0.138-0.145 s after a sentence and 0.044 before the next). The seam splices its
# gap on that assumption, and Kokoro's own ends hold more: its first pad rests 14 frames (350 ms) and a
# sentence's mark, word-space and pad another 225 ms or so - measured over a passage of nine sentences,
# its seams ran 2.57-2.79 s where Piper's ran 1.89-2.06, at the same Pause (its commas, which the splicer
# measures, matched: 0.80-0.94 s against 0.90-0.95). So a take is trimmed to them (`_trim_ends`).
SEAM_LEAD = 0.044
SEAM_TAIL = 0.14
# What counts as sound at a take's ends: a share of its peak, as the splicer's SPLICE_QUIET.
SEAM_QUIET = 0.02


# NOTHING HISSES AFTER A VOICE THAT ENDED VOICED (2026-10-25, the Cards Test's "Let's shuffle. Oh. Oh,
# wow." - "the two words spoken after that are completely imperceptible"). On a sentence ending in a vowel,
# Kokoro often renders a burst of hiss as the voice lets go and through the mark after it: on "Oh." 18 to
# 23 dB under the peak, 86 to 99% of it above 4 kHz, in Emma and Isabella alike - "Oh" heard as "Load",
# "Loved", "Ose" (Whisper, and the user's ear). Where the plan says the last sound was voiced - a vowel, or
# l r m n ŋ w j - what follows the waveform's last voiced moment is let go of over TAIL_FADE; a last sound
# that hisses itself (a final s, z, sh, f, th, or a stop's release) is the word and is never touched.
TAIL_FADE = 0.03
TAIL_FRAME = 0.01
TAIL_VOICED_HF = 0.3   # a frame with less than this share above TAIL_ABOVE is voice
TAIL_ABOVE = 4000.0
TAIL_LOUD = 0.01       # ...and louder than this share of the peak (-40 dB)
TAIL_RUN = 3           # ...for this many frames in a row
_VOICED_END = _VOWELS | frozenset("lɹmnŋwjɾ")


def _last_said(symbols: list, units: list, unit_of: list, sound: list) -> str:
    """The last sound the plan says, as eSpeak spelled it ("" for none): the last symbol of the last
    sounding unit, a length mark aside."""
    for k in range(len(sound) - 1, -1, -1):
        if sound[k] and unit_of[k] >= 0:
            at = units[unit_of[k]][2]
            for j in reversed(at):
                ch = symbols[j][0]
                if ch not in _LENGTHENS and ch not in _UNSAID and ch != SYLLABIC:
                    return ch
    return ""


def _quiet_tail(audio, last: str):
    """`audio` let go of after its last voiced moment, where the plan's `last` sound was voiced."""
    import numpy as np

    if last not in _VOICED_END or audio.size < 2:
        return audio
    hop = int(TAIL_FRAME * SR)
    n = audio.size // hop
    if n < 2:
        return audio
    framed = audio[: n * hop].reshape(n, hop).astype(np.float64)
    level = np.sqrt((framed**2).mean(axis=1))
    peak = float(level.max())
    if peak <= 0.0:
        return audio
    spec = np.abs(np.fft.rfft(framed * np.hanning(hop), axis=1)) ** 2
    high = spec[:, np.fft.rfftfreq(hop, 1.0 / SR) > TAIL_ABOVE].sum(axis=1) / (spec.sum(axis=1) + 1e-20)
    # VOICE IS A RUN of TAIL_RUN frames: a lone low frame at the very end (a thump in the last pad, seen on
    # Isabella's "No.") is not the voice going on, and taken for it, it kept the hiss before it
    mask = (level > TAIL_LOUD * peak) & (high < TAIL_VOICED_HF)
    runs = np.convolve(mask.astype(np.int32), np.ones(TAIL_RUN, np.int32), mode="valid")
    ends = np.nonzero(runs == TAIL_RUN)[0]
    if ends.size == 0:
        return audio
    start = (int(ends[-1]) + TAIL_RUN) * hop
    fade = int(TAIL_FADE * SR)
    if start >= audio.size:
        return audio
    out = audio.copy()
    m = min(fade, out.size - start)
    out[start : start + m] *= (0.5 + 0.5 * np.cos(np.linspace(0.0, np.pi, m))).astype(out.dtype)
    out[start + m :] = 0.0
    return out


def _trim_ends(audio, frames, sound: list, frame_s: float):
    """(audio, frames) with the take's head cut to SEAM_LEAD before its first sound and its tail to
    SEAM_TAIL after its last - each cut only where the plan holds no sound (the first pad's frames at
    the head, the marks, word-space and pad after the last sounding token at the tail) and only where
    the waveform is quiet. The frames are cut with the audio, so they still add up to it and every time
    read off them stays exact."""
    import numpy as np

    sr = HOP / frame_s
    if audio.size < 2 or frames.size < 2:
        return audio, frames
    peak = float(np.max(np.abs(audio)))
    if peak <= 0.0:
        return audio, frames
    step = max(1, int(0.005 * sr))
    n = audio.size // step
    level = np.sqrt((audio[: n * step].reshape(n, step) ** 2).mean(axis=1))
    loud = np.nonzero(level > SEAM_QUIET * peak)[0]
    if loud.size == 0:
        return audio, frames
    heard_from = loud[0] * step / sr
    heard_to = (loud[-1] + 1) * step / sr
    frames = frames.astype(np.float64).copy()
    head = max(0.0, min(heard_from, frames[0] * frame_s) - SEAM_LEAD)
    last = max((k for k, s in enumerate(sound) if s), default=-1)
    total = float(frames.sum()) * frame_s
    said_to = float(frames[: last + 1].sum()) * frame_s
    tail = max(0.0, total - max(heard_to + SEAM_TAIL, said_to))
    cut0 = int(round(head * sr))
    cut1 = int(round(tail * sr))
    if cut0 + cut1 >= audio.size:
        return audio, frames
    frames[0] -= cut0 / sr / frame_s
    left = cut1 / sr / frame_s
    for k in range(frames.size - 1, last, -1):
        take = min(frames[k], left)
        frames[k] -= take
        left -= take
        if left <= 0.0:
            break
    return audio[cut0 : audio.size - cut1], frames


def _cores() -> int:
    """Physical cores (two threads of one core share it): /proc/cpuinfo's distinct (package, core) pairs
    on Linux, else half the logical count."""
    try:
        pairs = set()
        phys = core = None
        for line in Path("/proc/cpuinfo").read_text().splitlines():
            if line.startswith("physical id"):
                phys = line.split(":", 1)[1].strip()
            elif line.startswith("core id"):
                core = line.split(":", 1)[1].strip()
                pairs.add((phys, core))
        if pairs:
            return len(pairs)
    except OSError:
        pass
    return max(1, (os.cpu_count() or 2) // 2)


def _reaches(graph, name: str, outputs: list) -> bool:
    """Whether tensor `name` flows into one of the graph's `outputs`."""
    seen = {name}
    grew = True
    while grew:
        grew = False
        for n in graph.node:
            if any(i in seen for i in n.input):
                for o in n.output:
                    if o not in seen:
                        seen.add(o)
                        grew = True
    return any(o in seen for o in outputs)


def _pieces(ids: list, units: list, unit_of: list) -> list:
    """[(a, b)] spans of `ids` of at most MAX_TOKENS each, cut after a word-space - the one after a
    mark nearest the limit where there is one in the piece's second half, else the last."""
    out: list = []
    a = 0
    n = len(ids)
    while n - a > MAX_TOKENS:
        hi = a + MAX_TOKENS
        cut = None
        for k in range(hi - 1, a + MAX_TOKENS // 2, -1):
            if units[unit_of[k]][0] == " " and k > a and units[unit_of[k - 1]][0] in _MARK_SYMBOLS:
                cut = k + 1
                break
        if cut is None:
            cut = next(
                (k + 1 for k in range(hi - 1, a, -1) if units[unit_of[k]][0] == " "),
                hi,
            )
        out.append((a, cut))
        a = cut
    out.append((a, n))
    return out


def _phones(units: list, said: dict, symbols: list) -> list:
    """[{p, t0, t1, w}] in eSpeak's symbols, as Piper hands them back: each unit's time shared evenly
    among the eSpeak symbols it was written from (A's between e and ɪ), a length mark its vowel's,
    stress marks, word-spaces and marks none."""
    out: list = []
    done: set = set()
    by_at: dict = {}
    for u, (_ksym, src, at) in enumerate(units):
        if u in said:
            t0, t1 = said[u]
            e = by_at.get(at)
            by_at[at] = (src, t0 if e is None else min(e[1], t0), t1 if e is None else max(e[2], t1))
    for at, (src, t0, t1) in sorted(by_at.items(), key=lambda kv: kv[1][1]):
        if at in done:
            continue
        done.add(at)
        heard = [j for j in at if symbols[j][0] not in _UNSAID and symbols[j][0] != "̩"]
        if not heard:
            continue
        step = (t1 - t0) / len(heard)
        for k, j in enumerate(heard):
            sym = symbols[j][0]
            a, b = t0 + k * step, t0 + (k + 1) * step
            if sym in _LENGTHENS and out and out[-1]["w"] == src:
                out[-1]["t1"] = b
                continue
            out.append({"p": sym, "t0": a, "t1": b, "w": src})
    return out
