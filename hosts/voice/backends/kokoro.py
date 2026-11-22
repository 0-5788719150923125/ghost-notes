"""Kokoro voices (hexgrad/Kokoro-82M v1.0), run as raw ONNX beside Piper (next/voice_engines.md, "Kokoro").

What it is: StyleTTS 2 without the diffusion, 82M parameters. PL-BERT reads the phonemes, a duration
predictor plans each token's frames (rounded, at least one), F0 and energy are predicted from the aligned
features, and an iSTFTNet decoder makes 24 kHz audio. A voice is a style vector (128 numbers of timbre for
the decoder, 128 of prosody for the predictor) taken by the sentence's token count from a [510, 1, 256]
pack; at most 510 tokens are read at once.

What it shares with Piper is everything around the model: ghost's tokens, eSpeak's reading of them
(homographs, lexicon), rests floored in the plan and spliced after it, the trail, the lead, stress held
through `dur_scale`, the arc's pitch, the Tone played back. This is PiperBackend with the model swapped: the
ids, the graph, the frame (600 samples, 25 ms; Piper's is 256 at 22,050) and the voices.

The graph is onnx-community's timestamped export (Apache-2.0, pinned below), patched once where first used
(`_patch`) as a Piper voice is: `dur_scale` multiplies the planned durations before they are rounded,
`rest_floor` floors them after, and `durations` hands back the whole frames the decoder used. Unfed, the
patched graph's audio is the stock graph's sample for sample, and frames x 600 is the take's length exactly.
Nothing in it samples: one text and one voice make one take.

The symbols: Kokoro's English was taught misaki's notation, not eSpeak's (one letter a diphthong: A eɪ, I
aɪ, W aʊ, Y ɔɪ, O oʊ, Q əʊ; ʤ and ʧ for the affricates; T for the American flap; no length marks in
American). `kokoro_symbols` writes eSpeak's reading in it by misaki's own table for its eSpeak fallback
(misaki/espeak.py, `EspeakFallback`), each symbol keeping its word; the phones go back in eSpeak's symbols,
so a mouth reads them as it reads Piper's.

Voices trained here (next/voice_engines.md "Training Kokoro"): a checkpoint of its own under
`trained/<id>/`: the stock graph with the decoder's and prosody predictor's weights from a run
(hosts/voice_train/kokoro_export.py), its tokenizer, one pack (`voices/voice.bin`, the taught style in every
row) and `voice.json` ({name, license, chain, british}). Listed beside the stock checkpoints (`_family`),
never fetched.

A blend of readers (hosts/voice/blend.py): a request's `blend` ("mix: af_heart 2, bf_emma 1") reads in a
pack made of the checkpoint's own packs (`_blended`, the latest BLENDS_KEPT kept made), in its accent, at
its readers' level; the backend says `blend` (`describe`). A blend that moves is read token by token where each
stands in its paragraph (the request's `plan_span`; its noise at `plan_p` paragraphs on) through the graph made to
take a style a token (`_moving_graph`: hosts/voice/kokoro_moving.py, made once beside the stock graph and checked
against it) - or, without a span or that graph, a sentence at a time at its `plan_u`. A line that shapes one reader
(breath, push, noise) is that reader moved. A voice taught here never blends.

The opening: the first pad keeps its own length at every pace. Kokoro stays silent for a fixed stretch from
the start of the sequence (8 to 14 frames by voice) and voices whatever comes after it, word or not. The
first pad's own plan at speed 1.0 lands the first word just there (Puck plans 10 frames and wakes at 9), but
`speed` divides the pad with the words, so a fast pace shortens it and swallows the word, and a slow one
lengthens it and voices a phantom before it. Measured on the raw graph, Puck's "A mind...":

    pad frames   sound starts at frame   sound before the first phone   "A" against the rest
        1                8.0             none: the word is in the silence      -104 dB
        8                8.4                                                     -8
       10 (its plan)     8.8              30 ms (PLAN_LEAD: the word itself)     -1
       14                9.0             125 ms                                  +5

So there is no lead-in: the ids are the model's own and the pad is planned at speed 1.0 whatever the pace
(`dur_scale` = speed on it). More pad than its plan brings the phantom back (x1.15: 35 ms at -21 dB at Pace
1). An unpatched graph takes no `dur_scale`, and its pad follows the speed. The words after keep the stock
plan (median 1.00 at Pace 1 and 1.6) and a voice's speaking level moves at most 0.23 dB, so levels.json
stands.

The pace never squashes a vowel. `speed` divides every frame of the plan before its Round, so past about 1.3x
a vowel of two frames rounds to one and its syllable is not heard (at 1.32x "needed it." is heard as "needed").
Where the pace is above 1, each piece is planned at speed 1.0 first and every vowel floored at what it had there,
up to VOWEL_LEAST frames (`_render_symbols`): what the pace takes comes from the consonants and the longer vowels,
and a vowel Kokoro itself plans one frame long stays so.

The end: a sentence's end is not the call's. At the end of a call Kokoro lets the last word go, so a sentence
that ends on a full stop is read with its own first word after it and the take cut in the rest the model makes
at the stop (AFTER_WORDS, `_after`, `_cut_after`). What is followed is planned faster, so the sentence is planned
alone first, by the graph cut to its plan (`_planner`), and the call is told that plan (`_told`) - but not the
holds mid-sentence a sentence has only alone (HOLD_OVER).

The start: where the request says what was said before the sentence (`before`: the reading sends the last words of
the sentence before it in its paragraph, in the same voice), they are read first and the take cut in the rest the
model makes after them (`_before_ids`, `_cut_before`). The sentence is told its plan alone up to its last sound, so
what they change is how it comes in - its first words' pitch and level, softer than the start of a call - never its
pace. Where the model reads on into the sentence (after a word or two it does not rest), it is read without them.

Not here: `noise_scale` and `noise_w` (the Tone's `noise` columns do nothing on these voices), F0 as an
input save the request's `inflect` (inflection.py, through the sung graph; the arc and the Tone resample), Kokoro's own dwell at a mark (the pause figures are Piper's
measurements), the vowel probe.

The rate: rendered at 24 kHz and handed back at 22,050 (`OUT_RATE`) through the band-limited resampler,
since a reading joins its takes at one rate and a cast may mix Kokoro and Piper voices.
"""

from __future__ import annotations

import json
import os
import re
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
    SENTENCE_END,
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
# A floor that says a plan entry is a take's trimmed end (`_nominal`): fixed seconds, at any scale.
HELD = float("inf")
# Its audio runs ahead of its plan: the voicing the plan puts in each frame is heard PLAN_LEAD earlier
# (median 55 ms Emma, 48 Heart over 20 sentences, the middle half within 15 ms, the same across a sentence).
# Every time the plan says (a word, its edges, a rest, a phone) is told that much earlier, so what is placed
# by them (the cut of a rest, the trail, subtitles, a mouth) lands on the sound.
PLAN_LEAD = 0.05
GAP_REACH = 0.05  # how far past the (corrected) word boundary a rest's cut is looked for
# ...and how far before it: reaching GAP_REACH back into a word finds the silence of its stop's closure, and
# the release goes over the rest. A word's last sound ends by its corrected end, give or take this much.
GAP_BACK = 0.015
# The word before a rest is held at least this long on its last vowel (seconds at length scale 1; the
# trail's share of it, as its hold is). Piper's hold is a ratio (TRAIL_STRETCH) and on 25 ms frames a ratio
# is wrong both ways (a 50 ms "oo" rounds back to two frames, "stays," held 1.6 times is drawn out). A floor
# lengthens the short vowel alone and leaves a long one as planned.
HOLD_LEAST = 0.09
# The frames a vowel the pace shortens keeps at least, or what it has at speed 1.0 where that is fewer (the
# module's header, "The pace never squashes a vowel"). A diphthong is one id.
VOWEL_LEAST = 2
STYLE = 256
PAD_ID = 0
# How this backend reads a request, said on every voice's row (`voices`): a row keys the takes kept in its voice
# (TakeCache), so raising it has every sentence kept before said again. Raised when the same request comes out
# another take.
READS = 6

LICENSE = (
    "Apache-2.0 (hexgrad/Kokoro-82M). Its training data includes synthetic audio from closed "
    "commercial voices - a provenance question before any commercial use"
)

# The English packs of v1.0, a speaker number each: (pack, accent, sex, what else is said of it), the grade
# hexgrad's own in VOICES.md. The order is the numbers: a note keeps its speaker as an index, so a pack
# added later goes at the end and none is moved. Most read best between 100 and 200 tokens and weakly under
# 10 to 20.
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
# How many blends are kept made (`_blended`): half a megabyte each, one a place in a paragraph for a blend that moves.
BLENDS_KEPT = 32
# The stock graph made to take a style a token (`_moving_graph`), beside it: as big again.
MOVING = "model_moving.onnx"
# A graph cut to its plan (`_plan_graph`), beside it: "model_plan.onnx".
PLAN = "_plan.onnx"
# The stock graph made to sing (`_sung_graphs`, kokoro_sung.py), and it cut to its planned curves, beside it.
SUNG = "model_sung.onnx"
SUNG_CURVES = "model_sung_curves.onnx"
# ...and the graph a voice moves in made so (an inflected reading of a moving voice), and it cut to its curves.
MOVING_SUNG = "model_moving_sung.onnx"
MOVING_SUNG_CURVES = "model_moving_sung_curves.onnx"
# A sung vowel's energy is held at its peak over its first HOLD_LOOK curve steps (12.5 ms each), and never more than
# HOLD_UNDER (the curve's own log units) under the phrase's vowels' typical peak.
HOLD_LOOK = 8
HOLD_UNDER = 0.5
# A vowel held SUSTAIN_FROM frames or more is sung a second time with its energy raised where its middle fell under its
# onset (or SUSTAIN_UNDER dB under the phrase's vowels): SUSTAIN_SLOPE dB a unit of energy (measured on af_heart's
# "user": 6.1 to 10 raised a held u 19 dB), at most SUSTAIN_MOST dB and never past ENERGY_MOST.
SUSTAIN_FROM = 8
SUSTAIN_UNDER = 4.0
SUSTAIN_SLOPE = 5.0
SUSTAIN_MOST = 18.0
ENERGY_MOST = 10.5
# Where the voices taught here are, under the voices' root (`_family`).
TRAINED = "trained"

# The English packs of v1.1-zh: an hour each of crowdsourced synthetic English (its model card), ungraded.
# Vale is "an older British female".
PACKS_11: list[tuple[str, str, str, str]] = [
    ("af_maple", "US", "F", "ungraded"),
    ("af_sol", "US", "F", "ungraded"),
    ("bf_vale", "GB", "F", "older, ungraded"),
]

# The checkpoints, one voice each in the Voice list, their packs its speakers (as libritts-high's readers
# are under it): the Voice list names a model and the Speaker row picks who reads in it. Each is
# onnx-community's export at the commit last verified: the graph, the tokenizer (its vocab is the ids) and a
# file per pack, under `dir` of the voices' root. v1.1-zh is a second checkpoint, not a strict upgrade (its
# card): it drops most of v1.0's voices for Chinese ones and adds three English, Vale a British woman.
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

# eSpeak's reading in misaki's symbols: misaki's table for its eSpeak fallback (`E2M`, then its American and
# British replacements), read without eSpeak's tie marks (ghost's reading has none, so two symbols of one
# word that spell a diphthong or an affricate are taken as one). The longest match wins, so "eə" is British
# ɛː before "e" alone is A.
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

# The happy vowel is said "ee". eSpeak reads a word's unstressed "ee" (the dictionary's IY0) as lax ɪ
# ("babysitter" bˈeɪbɪsˌɪɾɚ, "everything" ˈɛvɹɪθˌɪŋ, "video" vˈɪdɪoʊ), and Kokoro, taught on misaki's
# dictionary, which writes that vowel i, says ɪ there as a short vowel. So where the word's dictionary
# reading (the token's `fallback`, ghost's CMUdict) has IY0 and eSpeak ɪ in the same place, it is written i
# after a stressed syllable (ba|by|sitter, ev|ery|thing) or before a vowel (vid|e|o, the|ology); an
# unstressed prefix before a consonant keeps eSpeak's ɪ ("pretend", "prepare": the dictionary's IY0 there is
# careful speech). A word whose vowels do not line up one for one is left as eSpeak read it.
_ARPA_VOWELS = frozenset(("AA", "AE", "AH", "AO", "AW", "AY", "EH", "ER", "EY", "IH", "IY", "OW", "OY", "UH", "UW"))
# eSpeak's vowel nuclei, longest first: a diphthong, a long vowel or a vowel with its r is one
_NUCLEUS = re.compile(r"aɪ|aʊ|eɪ|oʊ|ɔɪ|əʊ|eə|ɪə|ʊə|ɑːɹ|ɔːɹ|ɛɹ|ɪɹ|ʊɹ|ɜːɹ|iː|uː|ɑː|ɔː|ɜː|i|ɪ|ɛ|æ|ɑ|ɒ|ɔ|ʊ|u|ʌ|ə|ɚ|ɐ|ᵻ|ɜ|o|e|a")


def happy_vowels(ipa: str, arpa: list) -> str:
    """eSpeak's reading `ipa` of a word with its happy vowel written i where the dictionary's `arpa` says so
    (above): `ipa` as it is where the two do not line up, or nothing is to change."""
    vowels = []  # (stress, whether a vowel comes straight after it)
    for k, ph in enumerate(arpa):
        base = str(ph).rstrip("012")
        if base in _ARPA_VOWELS:
            after = str(arpa[k + 1]).rstrip("012") if k + 1 < len(arpa) else ""
            vowels.append((str(ph)[len(base):], after in _ARPA_VOWELS, base))
    if not any(b == "IY" and st == "0" for st, _v, b in vowels):
        return ipa
    nuclei = list(_NUCLEUS.finditer(ipa))
    if len(nuclei) != len(vowels):
        return ipa
    out = ipa
    for k in reversed(range(len(vowels))):
        stress, before_vowel, base = vowels[k]
        if base != "IY" or stress != "0" or nuclei[k].group(0) != "ɪ":
            continue
        after_stress = any(st in ("1", "2") for st, _v, _b in vowels[:k])
        if after_stress or before_vowel:
            out = out[: nuclei[k].start()] + "i" + out[nuclei[k].end():]
    return out


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
    # No lead is quieted: no rest is floored here, and a floored rest is what makes the next word's lead
    # long. The trail (the word before a rest let go of) is made, on the plan told PLAN_LEAD earlier.
    quiets_lead = False
    # ...and runs right up to where the next word starts: Kokoro holds a word through a comma it reads
    # straight through, so the next word's start walked back over sound is the same word's vowel (the fade
    # would dip half way and the cut in the dip misplace the word). Where the voice runs into the next word,
    # the trail's way back up runs on into it, never a step.
    trail_early = 0.0
    trail_through = True
    # The text inflects the words (inflection.py): its pitch through the sung graph.
    inflects = True
    # Kokoro samples nothing: its level is the same render to render (level.py, PiperBackend.level_noise).
    level_noise = 1.0

    @classmethod
    def describe(cls) -> dict:
        d = PiperBackend.describe()
        d.update(
            {
                "name": cls.name,
                "phoneme_input": True,  # eSpeak's reading, in misaki's symbols
                "duration_control": True,  # speed, and the patched plan
                "pitch_control": False,  # a reading's pitch is the plan's; a sung phrase's is told (`sing`)
                "sings": True,  # `sing`: a phrase on its notes, through the graph made to sing (kokoro_sung.py)
                "timings": True,  # the rounded plan, exact
                # Its readers blend (blend.py): said of the backend, never on a voice's row, because every
                # field of a row keys the takes kept in that voice (TakeCache) and one added would re-make
                # every one of them.
                "blend": True,
                # A request's `before` (the words said before its sentence) is read first and cut away: said of the
                # backend, so a reading sends them to no other voice and keys no other voice's takes by them.
                "before": True,
                # A request's `inflect` (inflection.py: a question rises, a leaned-on word is accented): said of the
                # backend, so a reading sends it to these voices alone and keys no other voice's takes by it.
                "inflect": True,
            }
        )
        return d

    @classmethod
    def owns(cls, voice: str) -> bool:
        return voice in FAMILIES or cls._trained(voice) is not None

    @classmethod
    def _trained(cls, voice: str):
        """A voice taught here (`TRAINED`): its description ({name, license, chain, british}), or None."""
        if not voice or "/" in voice or voice.startswith(".") or voice in FAMILIES:
            return None
        d = cls._root() / TRAINED / voice
        if not all((d / f).exists() for f in (MODEL, TOKENIZER, "voices/voice.bin", "voice.json")):
            return None
        try:
            meta = json.loads((d / "voice.json").read_text(encoding="utf-8"))
        except Exception:  # noqa: BLE001 - half-written: not a voice yet
            return None
        return meta if isinstance(meta, dict) else None

    @classmethod
    def _family(cls, voice: str) -> dict:
        """A checkpoint as FAMILIES describes one - a stock one, or one taught here (one pack, its own voice)."""
        if voice in FAMILIES:
            return FAMILIES[voice]
        meta = cls._trained(voice)
        if meta is None:
            raise BackendError(f"unknown Kokoro voice '{voice}'")
        accent = "GB" if bool(meta.get("british", False)) else "US"
        return {"name": str(meta.get("name", voice)), "base": "", "dir": TRAINED + "/" + voice,
                "derivation": str(meta.get("chain", "taught here")), "license": str(meta.get("license", "")),
                "packs": [("voice", accent, "", "taught here")], "about": "A voice taught here, on their own speech."}

    def __init__(self) -> None:
        super().__init__()
        self._models: dict = {}  # checkpoint -> its graph, every pack of it shares
        self._vocabs: dict = {}  # checkpoint -> {symbol: id}
        self._speakers: dict = {}  # (checkpoint, pack index) -> its cfg (`_speaker`)
        self._blends: dict = {}  # (checkpoint, the blend read) -> its cfg (`_blended`), the latest BLENDS_KEPT
        self._moving: dict = {}  # checkpoint -> its graph that takes a style a token, or None (`_moving_graph`)
        self._paths: dict = {}  # id(a graph) -> its file
        self._plans: dict = {}  # id(a graph) -> the graph that makes its plan alone (`_planner`)
        self._sung: dict = {}  # (checkpoint, moving) -> (its graph that sings, its curve planner), or None (`_sung_graphs`)

    # -- storage -----------------------------------------------------------

    @staticmethod
    def _root() -> Path:
        root = PiperBackend._root().parent / "kokoro"
        root.mkdir(parents=True, exist_ok=True)
        return root

    @classmethod
    def _home(cls, family: str) -> Path:
        d = cls._family(family)["dir"]
        return cls._root() / d if d else cls._root()

    def voices(self) -> list[dict]:
        out = []
        trained = self._root() / TRAINED
        taught = sorted(d.name for d in trained.iterdir() if self._trained(d.name) is not None) if trained.is_dir() else []
        for vid in [*FAMILIES, *taught]:
            fam = self._family(vid)
            home = self._home(vid)
            out.append(
                {
                    "id": vid,
                    "name": fam["name"],
                    "backend": self.name,
                    "license": fam.get("license", LICENSE),
                    "derivation": fam["derivation"],
                    "speakers": len(fam["packs"]),
                    "reads": READS,
                    # Who each speaker number is, said by the host (VoiceReaders.offer): the libritts
                    # readers are described from files, these from the tables above.
                    "readers": [
                        {"reader": pack, "g": sex, "d": "%s, %s, %s" % (pack.split("_", 1)[-1], ACCENTS[accent], said)}
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
        if voice not in FAMILIES:
            return 0  # taught here: its files are here, or it is not listed
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
            self._paths[id(self._models[family])] = home / MODEL
            tok = json.loads((home / TOKENIZER).read_text(encoding="utf-8"))
            self._vocabs[family] = {str(k): int(v) for k, v in tok["model"]["vocab"].items()}
        return self._models[family]

    def ids_of(self, tokens: list, family: str = "kokoro", british: bool = False, phonemizer: str = "espeak") -> list:
        """THE IDS THE GRAPH IS SENT FOR `tokens` (`_run`, `_render_symbols`): its homographs, eSpeak's reading in
        misaki's symbols, a pad at each end - what a voice is taught on here (hosts/voice/utterances.py), so it
        learns exactly what it will be asked. What the plan is told (floors, stretches, the first pad's length) is the
        plan's, not the ids'."""
        espeak = "en-gb" if british else "en-us"
        if phonemizer == "espeak":
            self._homographs.annotate(tokens, espeak)
        units = kokoro_symbols(self._symbols(tokens, phonemizer, espeak, ""), british)
        if family not in self._vocabs:
            self._download(family)
            tok = json.loads((self._home(family) / TOKENIZER).read_text(encoding="utf-8"))
            self._vocabs[family] = {str(k): int(v) for k, v in tok["model"]["vocab"].items()}
        vocab = self._vocabs[family]
        return [PAD_ID, *[int(vocab[k]) for k, _src, _at in units if k in vocab], PAD_ID]

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
        packs = self._family(family)["packs"]
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

    def _blended(self, family: str, spec, u: float = 0.5, pos: float = 0.0):
        """The cfg of the blend `spec` names (blend.py) in `_speaker`'s shape, its pack made of its readers' as it
        stands at `u` across a paragraph (`pos` paragraphs into the reading, for its noise) and read in its accent -
        or None where it names fewer than two of this checkpoint's packs and shapes none (a reader it does not hold
        is left out), or the checkpoint is one taught here. `kokoro.blend` keeps what its level is made of
        (`_leveled`)."""
        import blend

        b = blend.parse(spec) if family in FAMILIES else None
        if b is None:
            return None
        packs = self._family(family)["packs"]
        at = {row[0]: i for i, row in enumerate(packs)}
        voices = [v for v in b["voices"] if v[0] in at]
        if not voices or (len(voices) < 2 and not blend.shaped(b)):
            return None
        b = {**b, "voices": voices}
        wander = b["noise"] is not None and b["noise"][0] == "wander"
        key = (family, b["method"], b["accent"], tuple(voices), b["breath"], b["push"], b["noise"],
               round(u, 4) if blend.moving(b) or wander else None, round(pos, 4) if wander else None)
        if key not in self._blends:
            idx = [at[r] for r, _w, _p in voices]
            readers = [self._speaker(family, i) for i in idx]
            now = blend.at(b, u)
            pack = blend.make(b["method"], [c["kokoro"]["pack"] for c in readers],
                              [w for _r, w, _p in now["voices"]], [p for _r, _w, p in now["voices"]])
            if blend.shaped(b):
                pack = (pack + blend.offset(b, u, pos).astype(pack.dtype)).astype(pack.dtype)
            gb = blend.british(b, [packs[i][1] for i in idx])
            base = readers[0]
            while len(self._blends) >= BLENDS_KEPT:
                self._blends.pop(next(iter(self._blends)))
            self._blends[key] = {
                **base,
                "espeak": {"voice": "en-gb" if gb else "en-us"},
                "kokoro": {**base["kokoro"], "pack": pack, "british": gb,
                           "blend": {"blend": b, "speakers": idx, "u": u}},
            }
        return self._blends[key]

    def _cfg_of(self, voice: str, params: dict) -> dict:
        """What a request reads in: the blend it names (`_blended`) where this checkpoint can make it, read at the
        request's place (`plan_u`, the middle of a paragraph where it has none; `plan_p` paragraphs in), else its
        speaker's pack."""
        import blend

        u = params.get("plan_u")
        u = 0.5 if u is None else min(max(float(u), 0.0), 1.0)
        span = _span(params.get("plan_span"))
        if span is not None:
            u = (span[0] + span[1]) / 2.0
        p = float(params.get("plan_p", 0) or 0)
        made = self._blended(voice, params.get("blend"), u, p + u)
        if made is None:
            return self._speaker(voice, int(params.get("speaker", 0) or 0))
        b = made["kokoro"]["blend"]["blend"]
        wander = b["noise"] is not None and b["noise"][0] == "wander"
        if span is None or not (blend.moving(b) or wander):
            return made
        packs = [self._speaker(voice, i)["kokoro"]["pack"] for i in made["kokoro"]["blend"]["speakers"]]
        return {**made, "kokoro": {**made["kokoro"], "moving": {"blend": b, "packs": packs, "span": span, "pos": p}}}

    def _moving_graph(self, family: str):
        """The checkpoint's graph made to take a style a token (kokoro_moving.py), made from the stock graph the first
        time it is asked for (and again whenever the stock graph is newer) - None where it cannot be made."""
        if family not in self._moving:
            import onnxruntime as ort

            import kokoro_moving

            self._graph(family)  # the stock graph first: fetched and patched
            home = self._home(family)
            path, stock = home / MOVING, home / MODEL
            if not path.exists() or path.stat().st_mtime < stock.stat().st_mtime:
                print("ghost/voice: making the Kokoro graph a voice moves in, once", file=sys.stderr)
                kokoro_moving.make(stock, path)
            self._moving[family] = (ort.InferenceSession(str(path), sess_options=self._options(),
                                                         providers=["CPUExecutionProvider"])
                                    if path.exists() else None)
            if self._moving[family] is not None:
                self._paths[id(self._moving[family])] = path
        return self._moving[family]

    def _planner(self, sess):
        """The graph that makes `sess`'s plan alone (`_plan_graph`), opened the first time it is asked for - `sess`
        itself where there is none, a whole call for a plan."""
        key = id(sess)
        if key not in self._plans:
            path = self._paths.get(key)
            self._plans[key] = (self._plan_graph(path, self._options()) if path is not None else None) or sess
        return self._plans[key]

    @staticmethod
    def _plan_graph(path: Path, opts):
        """The graph at `path` cut to its plan (its second output alone: the tokens' encoders and the duration
        predictor, a sixth of the file and 2% of a call's time, the same frames), made beside it the first time and
        again whenever `path` is newer - None where it cannot be cut."""
        dst = path.with_name(path.stem + PLAN)
        try:
            import onnx
            import onnxruntime as ort

            if not dst.exists() or dst.stat().st_mtime < path.stat().st_mtime:
                model = onnx.load(str(path))
                cut = onnx.utils.Extractor(model).extract_model(
                    [i.name for i in model.graph.input], [model.graph.output[1].name])
                tmp = dst.with_name(dst.name + ".making")
                onnx.save(cut, str(tmp))
                tmp.replace(dst)
            return ort.InferenceSession(str(dst), sess_options=opts, providers=["CPUExecutionProvider"])
        except Exception as exc:  # noqa: BLE001 - the graph itself plans
            print(f"ghost/voice: no plan graph for {path.name} ({exc})", file=sys.stderr)
            return None

    def _leveled(self, voice: str, params: dict, cfg: dict, sess) -> dict:
        """A blend at its readers' level (blend.py `gain`: each reader measured once, as any voice is); a reader at
        its own (level.py)."""
        made = cfg.get("kokoro", {}).get("blend")
        if made is None:
            return super()._leveled(voice, params, cfg, sess)
        import blend

        gains = [self._levels.gain(self, voice, i, self._speaker(voice, i), sess) for i in made["speakers"]]
        return {**params, "level_gain": blend.gain(made["blend"], gains, made["u"])}

    def _load(self, voice: str):
        """Piper's contract, for a caller that asks it: the graph and speaker 0. No vowel probe - what it
        measures is a Piper checkpoint's (vowel_probe.py)."""
        if not self.owns(voice):
            raise BackendError(f"unknown Kokoro voice '{voice}'")
        return self._graph(voice), self._speaker(voice, 0)

    @staticmethod
    def _options():
        """A session that leaves a live show its share of the machine: a thread for each core but one, and
        no spinning between operators (on four cores a 5.9 s sentence ran at 2.70x real time with the
        default using 3.9 cores, 2.60x with this using 2.6). The reading's own Godot, its show and its audio
        need the rest."""
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

        The export plans `durations` (the predictor's sum over its sigmoids, over `speed`), rounds it, clips
        it at one frame and expands the tokens by it. Patched: the plan times `dur_scale` (a multiplier per
        token, default 1) before the Round (a frame is 25 ms and most tokens are planned at one to three, so
        a stretch after the Round would mostly land back on the same frame), then floored by `rest_floor`
        (frames per token, default none) and clipped; `durations` is that clip: whole frames, what the audio
        was made of. Unfed, the graph renders what it did. The patched graph is opened before it replaces
        the file, so one that will not load is never written. False when it cannot be patched (no `onnx`, an
        unknown shape).
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
        # Where the plan comes back: v1.0's export hands back the plan before its Round (`durations` is the
        # Div's output), so that name is moved onto the clipped plan. v1.1's hands back the clip already
        # (`duration`, cast and squeezed) and is left as it is. A graph that does neither is not patched.
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
        cfg = self._cfg_of(voice, params)
        cfg = {**cfg, "kokoro": {**cfg["kokoro"], "family": voice}}  # what an inflected call finds its sung graph by
        run = sess
        if cfg.get("kokoro", {}).get("moving") is not None:
            run = self._moving_graph(voice)
            if run is None:  # no graph to move in: a sentence at a time
                cfg = {**cfg, "kokoro": {k: v for k, v in cfg["kokoro"].items() if k != "moving"}}
                run = sess
        return self._synth_tokens(list(tokens), voice, out_path, self._leveled(voice, params, cfg, sess), cfg, run)

    # -- singing -----------------------------------------------------------

    def _sung_graphs(self, family: str, moving: bool = False):
        """(the graph that sings, the graph that plans its curves) for a checkpoint, made from its patched graph the
        first time (kokoro_sung.py) and again whenever that is newer - None where it cannot sing. `moving`: made from
        the graph a voice moves in (`_moving_graph`) instead, for an inflected reading of a moving voice."""
        key = (family, moving)
        if key not in self._sung:
            import onnxruntime as ort

            import kokoro_sung

            self._graph(family)  # fetched and patched first
            home = self._home(family)
            if moving:
                if self._moving_graph(family) is None:
                    self._sung[key] = None
                    return None
                stock, sung, plan = home / MOVING, home / MOVING_SUNG, home / MOVING_SUNG_CURVES
            else:
                stock, sung, plan = home / MODEL, home / SUNG, home / SUNG_CURVES
            if not sung.exists() or sung.stat().st_mtime < stock.stat().st_mtime:
                print("ghost/voice: making the Kokoro graph that sings%s, once" % (" a moving voice" if moving else ""),
                      file=sys.stderr)
                if not kokoro_sung.make(stock, sung):
                    self._sung[key] = None
                    return None
            if not plan.exists() or plan.stat().st_mtime < sung.stat().st_mtime:
                kokoro_sung.curves(sung, plan)
            opts = self._options()
            open_ = lambda p: ort.InferenceSession(str(p), sess_options=opts, providers=["CPUExecutionProvider"])  # noqa: E731
            self._sung[key] = (open_(sung), open_(plan) if plan.exists() else None)
        return self._sung[key]

    def sing(self, voice: str, words: list, out_path: str, params: dict, style: dict) -> dict:
        """A phrase sung (next/music.md, "Kokoro sings"; singing.py lays it): `words` [{text, notes: [{t, len, midi}]}],
        times in seconds from the phrase's start. Three calls: the phrase planned as spoken (each consonant's length),
        the curves Kokoro plans for the sung durations (where it voices), then the phrase sung on the notes' pitch with
        its vowels' energy held. Returns {"wav", "sample_rate", "start" (where the take's first sample falls, in the
        phrase's seconds), "duration", "sung": [{word, t}]}."""
        import numpy as np

        import singing

        if not self.owns(voice):
            raise BackendError(f"unknown Kokoro voice '{voice}'")
        graphs = self._sung_graphs(voice)
        if graphs is None:
            raise BackendError("this Kokoro graph cannot be made to sing")
        sung_sess, curve_sess = graphs
        cfg = self._cfg_of(voice, params)
        kk = cfg["kokoro"]
        british = bool(kk["british"])
        # a word the note spells (a `say:` mark) keeps its ARPAbet and IPA: `_symbols` sings it so
        tokens = [{"text": str(w.get("text", "")), **{k: w[k] for k in ("arpa", "say") if w.get(k)}} for w in words]
        if not tokens or not all(t["text"].strip() for t in tokens):
            raise BackendError("a sung phrase needs words, each with its notes")
        espeak = "en-gb" if british else "en-us"
        self._homographs.annotate(tokens, espeak)
        units = kokoro_symbols(self._symbols(tokens, "espeak", espeak, voice), british)
        vocab = kk["vocab"]
        per_word: list = [[] for _ in words]
        for sym, src, _at in units:
            if sym != " " and sym in vocab and 0 <= int(src) < len(words):
                per_word[int(src)].append(sym)
        if not all(per_word):
            raise BackendError("a word of the phrase has no sound Kokoro knows")
        space = int(vocab[" "])
        body: list = []
        for w, syms in enumerate(per_word):
            if w:
                body.append(space)
            body.extend(int(vocab[s]) for s in syms)
        ids = np.array([[PAD_ID, *body, PAD_ID]], dtype=np.int64)
        pack = kk["pack"]
        style_row = np.asarray(pack[min(len(body), pack.shape[0]) - 1], dtype=np.float32).reshape(1, STYLE)
        base = {"input_ids": ids, "style": style_row, "speed": np.ones(1, np.float32)}
        stock = self._graph(voice)
        planner = self._planner(stock)
        spoken = planner.run(None, base)
        planned = np.asarray(spoken[-1] if len(spoken) == 1 else spoken[1], dtype=float).ravel()
        frame_s = HOP / float(SR)
        laid = singing.lay(per_word, [list(w.get("notes", [])) for w in words], planned.tolist(), frame_s)
        frames = np.asarray(laid["frames"], dtype=np.float32).reshape(1, -1)
        total = int(frames.sum())
        feed = {**base, "dur_scale": np.zeros((1, ids.shape[1]), np.float32), "rest_floor": frames}
        got = (curve_sess or sung_sess).run(None, feed)
        names = [o.name for o in (curve_sess or sung_sess).get_outputs()]
        f0p = np.asarray(got[names.index("f0_planned")], dtype=float).ravel()
        n_p = np.asarray(got[names.index("n_planned")], dtype=float).ravel()
        steps = len(f0p)
        half = frame_s / 2.0
        times = laid["origin"] + (np.arange(steps) + 0.5) * half
        voices = laid["voices"]
        midi = np.zeros(steps)
        held = np.zeros(steps)
        k = 0
        for j, t in enumerate(times):
            while k + 1 < len(voices) and voices[k + 1][0] <= t:
                k += 1
            midi[j] = voices[k][1] if voices else 60.0
            held[j] = max(t - voices[k][0], 0.0) if voices else 0.0
        curve = np.asarray(singing.ornament(midi.tolist(), half, held.tolist(), style or {},
                                            seed=int((style or {}).get("seed", 0))))
        f0 = 440.0 * 2.0 ** ((curve - 69.0) / 12.0)
        # a consonant Kokoro plans unvoiced keeps its plan; a sung vowel is voiced however long it is held (the plan
        # sags under VOICED on a vowel stretched past anything it was taught, and the decoder breathes it)
        vowel = np.zeros(steps, dtype=bool)
        for a, b in laid["vowels"]:
            vowel[2 * a:2 * b] = True
        keep = (f0p < singing.VOICED) & ~vowel
        for a, b in laid["rests"]:
            keep |= (times >= a) & (times < b)
        first, last = int(frames[0, 0]) * 2, (total - int(frames[0, -1])) * 2
        keep[:first] = True
        keep[last:] = True
        f0_set = singing.seam_pitch(np.where(keep, f0p, f0), keep, f0p).astype(np.float32)
        # each vowel's energy held at its own peak, and never under the phrase's vowels' (the plan lets a long vowel
        # die away as a pause would): the decoder keeps a held vowel voiced only while it is told it is loud
        peaks = [float(np.max(n_p[2 * a:min(2 * a + HOLD_LOOK, steps)])) for a, b in laid["vowels"] if 2 * a < steps]
        floor = float(np.median(peaks)) - HOLD_UNDER if peaks else 0.0
        n_set = n_p.copy()
        for a, b in laid["vowels"]:
            a2, b2 = 2 * a, min(2 * b, steps)
            if b2 - a2 > 2:
                target = max(float(np.max(n_p[a2:min(a2 + HOLD_LOOK, b2)])), floor)
                n_set[a2:b2] = np.maximum(n_p[a2:b2], target)
        n_set = singing.seam_energy(n_set, n_p)
        wave_at = [o.name for o in sung_sess.get_outputs()].index("waveform")

        def decode(energy):
            feed.update({"f0_keep": np.zeros(1, np.float32), "f0_set": f0_set.reshape(1, -1),
                         "n_keep": np.zeros(1, np.float32), "n_set": energy.astype(np.float32).reshape(1, -1)})
            return np.asarray(sung_sess.run(None, feed)[wave_at], dtype=np.float64).ravel()

        audio = decode(n_set)
        # THE HELD VOWEL KEEPS ITS LEVEL: a vowel held past its spoken length settles quieter than it began, more so the
        # longer it is held, so each vowel's middle is heard against its own onset (never under the phrase's vowels
        # by more than SUSTAIN_UNDER dB) and its energy raised where it sags, then the phrase is sung again
        rms = np.array([np.sqrt(np.mean(audio[i * HOP:(i + 1) * HOP] ** 2)) for i in range(audio.size // HOP)])
        db = 20.0 * np.log10(np.maximum(rms, 1e-5))
        onsets = [float(np.max(db[a:min(a + 4, b)])) for a, b in laid["vowels"] if b - a >= 4 and a < db.size]
        if onsets:
            floor_db = float(np.median(onsets)) - SUSTAIN_UNDER
            raised = n_set.copy()
            for a, b in laid["vowels"]:
                if b - a < SUSTAIN_FROM or b > db.size:
                    continue
                want = max(float(np.max(db[a:a + 4])), floor_db)
                short = np.clip(want - db[a:b], 0.0, SUSTAIN_MOST)
                short[:3] = 0.0  # the onset as it was
                lift = np.repeat(np.convolve(short, np.ones(3) / 3.0, mode="same"), 2) / SUSTAIN_SLOPE
                raised[2 * a:2 * b] = np.minimum(raised[2 * a:2 * b] + lift[:2 * (b - a)], ENERGY_MOST)
            if np.any(raised != n_set):
                audio = decode(singing.seam_energy(raised, n_p))
        self._write_wav(out_path, audio, SR)
        return {"wav": out_path, "sample_rate": SR, "start": laid["origin"] + PLAN_LEAD,
                "duration": audio.size / float(SR), "sung": laid["sung"], "frames": total}

    def _level_files(self, voice: str, speaker: int) -> list:
        """The checkpoint's graph and the speaker's pack (level.py)."""
        packs = self._family(voice)["packs"]
        pack = packs[min(max(int(speaker), 0), len(packs) - 1)][0]
        home = self._home(voice)
        return [home / MODEL, home / "voices" / f"{pack}.bin"]

    def _dictionary_reading(self, ipa: str, token: dict) -> str:
        """eSpeak's reading with the happy vowel misaki's dictionary writes (`happy_vowels`), from the word's own
        dictionary reading - none for a word no dictionary holds (`rare`), whose ARPAbet is a guess."""
        arpa = token.get("fallback")
        if not arpa or token.get("rare"):
            return ipa
        return happy_vowels(ipa, list(arpa))

    def _symbols(self, tokens: list, phonemizer: str, espeak_voice: str = "en-us", voice: str = "") -> list:
        """Piper's, without its lead-in spaces (LEAD_IN_SPACES) or its last word-space: the sentence's own
        symbols. Kokoro has no lead-in (the module's header, THE OPENING), so what a voice is taught on
        (`ids_of`), what it is sent and the style row it is read in are the sentence alone."""
        out = super()._symbols(tokens, phonemizer, espeak_voice, voice)
        k = 0
        while k < len(out) and out[k] == (" ", 0):
            k += 1
        # ...nor the word-space Piper's path puts after the last word: Kokoro was never taught an utterance
        # that ends on one and renders it as a sound (a short take ended on a hiss 32 to 40 dB under its
        # peak).
        end = len(out)
        while end > k and out[end - 1][0] == " ":
            end -= 1
        return out[k:end]

    def _before_ids(self, params: dict, kk: dict) -> list:
        """The ids of what was said before the sentence (the request's `before`, as tokens), read as a sentence is
        - [] where there is nothing, no sound, or no full stop at its end (a comma's phrase runs on into the next)."""
        toks = [dict(t) for t in (params.get("before") or []) if isinstance(t, dict)]
        if not toks or str(toks[-1].get("punct", "")) not in SENTENCE_END:
            return []
        british = bool(kk["british"])
        espeak = "en-gb" if british else "en-us"
        phonemizer = str(params.get("phonemizer", "espeak"))
        vocab = kk["vocab"]
        try:
            if phonemizer == "espeak":
                self._homographs.annotate(toks, espeak)
            units = kokoro_symbols(self._symbols(toks, phonemizer, espeak, ""), british)
        except Exception as exc:  # noqa: BLE001 - the words before are a nicety: the sentence is read without them
            print(f"ghost/voice: the words before a sentence not read ({exc})", file=sys.stderr)
            return []
        out = [int(vocab[k]) for k, _src, _at in units if k in vocab]
        quiet = {vocab.get(" ")} | {vocab[m] for m in _MARK_SYMBOLS if m in vocab}
        return out if any(i not in quiet for i in out) else []

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
        inflect: dict | None = None,
    ):
        """(symbol, source) pairs -> audio, plus a time span per source - Piper's contract
        (`PiperBackend._render_symbols`), on Kokoro's ids: one id a symbol, a pad at each end, no
        blanks between. What the plan is told: a stretch on a source's nucleus, a hold on its final
        rime and its last vowel floored at HOLD_LEAST (shared with its length mark), the opening vowel
        floored, the first pad held at its own length (the module's header, THE OPENING), above speed 1.0
        every vowel floored at its frames at speed 1.0 up to VOWEL_LEAST - and no rest (below).

        A sentence over MAX_TOKENS is read in pieces cut at a word-space - after a mark where one
        is in reach - each with its own pads and its own style, the pieces' plans laid end to end.

        A sentence that ends on a full stop is followed in its call by its own first word (AFTER_WORDS, or as
        many as the request's `after` says), told the plan it has alone, and cut before the word; what is handed
        back is the sentence's alone. So is a sentence read after what the request's `before` says was said: it is
        said first and the take cut in the rest after it (`led`).

        `inflect` (inflection.py's marks) inflects the words: a word's `slow` floors every sound of it at its planned
        frames times that (its remainders carried, so the word is that much longer in whole frames), and where
        any has a pitch shape the call is planned first (its frames, and its pitch where a word is flattened: the sung
        graph cut to its curves) and read by the sung graph (kokoro_sung.py), its `f0_keep` the shapes laid on that
        plan (`inflection.curve`) - Kokoro's own pitch moved, the decoder making it, and a vowel it would whisper told
        its pitch outright where a mark voices it (`inflection.voiced`). A voice that moves reads by the
        graph it moves in made so (`_sung_graphs(moving=True)`).
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
        vowel: list[bool] = []  # whether each id is a vowel (a diphthong is one): what the pace may not squash
        is_core: list[bool] = []  # whether each id is of its word's stressed vowel (where an accent peaks)
        missing: list[str] = []
        opened = False
        for u, (ksym, src, at) in enumerate(units):
            kid = vocab.get(ksym)
            if kid is None:
                missing.append(ksym)
                continue
            # No rest is floored: Kokoro given frames on a word-space (or a mark) holds the word through
            # them instead of resting (20 frames after "dawn," rendered 500 ms of voice 16 to 20 dB under
            # the peak), and the rest spliced in was cut through it. Unfloored, the word falls away to 45 dB
            # under by itself, and the splicer measures that and rests the remainder (`_splice_pauses`, in
            # the window `_gap` searches). The opening vowel's floor is a vowel's, and so is the held one's.
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
            vowel.append(any(symbols[j][0] in _VOWELS for j in at))
            is_core.append(core)  # its stress mark with it: Kokoro plans the syllable's onset on the mark
        for sym in sorted(set(missing)):
            if sym in self._warned_symbols:
                continue
            self._warned_symbols.add(sym)
            print("ghost/voice: dropping U+%04X (%r), absent from Kokoro's symbols" % (ord(sym), sym),
                  file=sys.stderr)

        audio_parts: list = []
        frames_parts: list = []
        fed_floor = any(floor)
        takes = {i.name for i in getattr(sess, "get_overridable_initializers", list)()}
        speed = 1.0 / max(ls, 1e-3)
        fed_scale = speed != 1.0 or any(m != 1.0 for m in scale)
        lay_owner: list[int] = []
        lay_rest: list[int] = []
        lay_sound: list[bool] = []
        lay_unit: list[int] = []
        lay_floor: list[float] = []
        moving = kk.get("moving")
        space = vocab.get(" ")
        marks = {vocab[m] for m in _MARK_SYMBOLS if m in vocab}

        told_plan = REST_FLOOR_INPUT in takes and DUR_SCALE_INPUT in takes
        # what was said before the sentence, read first and cut away (`before`)
        before = self._before_ids(params, kk) if told_plan and space is not None else []

        def feeds_of(a: int, b: int, more: list, told=None, lead=(), pace=None) -> dict:
            """What a call of ids[a:b] is fed, `lead` said before them and `more` after, read at speed `pace` (None:
            the request's). `told` is the frames of its first ids, a pad first (None: the call's own plan): a told
            id's plan is scaled away and floored at them - save the pad where words come before (theirs is the call's)."""
            at_speed = speed if pace is None else float(pace)
            body = ids[a:b]
            n = max(1, len(body))
            pack = kk["pack"]
            front = [*lead, space] if lead else []
            rest = [space, *more] if more else []
            feeds = {
                "input_ids": np.array([[PAD_ID, *front, *body, *rest, PAD_ID]], dtype=np.int64),
                "style": np.asarray(pack[min(n, pack.shape[0]) - 1], dtype=np.float32).reshape(1, STYLE),
                "speed": np.array([at_speed], dtype=np.float32),
            }
            if moving is not None:
                # a row a token, each where it stands across the paragraph: its sentence's span laid over its ids
                import blend

                u0, u1 = moving["span"]
                total = float(max(1, len(ids)))
                places = [u0 + (u1 - u0) * min(max(x / total, 0.0), 1.0)
                          for x in (a, *([a] * len(front)), *[j + 0.5 for j in range(a, b)], *([b] * len(rest)), b)]
                rows = [p[min(n, p.shape[0]) - 1].reshape(STYLE) for p in moving["packs"]]
                feeds["style"] = blend.rows_along(moving["blend"], rows, places, float(moving["pos"]))
            floors = [0.0, *([0.0] * len(front)), *floor[a:b], *([0.0] * len(rest)), 0.0]
            # the first pad undoes `speed`: it is planned as at speed 1.0, where the first word meets the voice waking
            scales = [at_speed, *([1.0] * len(front)), *scale[a:b], *([1.0] * len(rest)), 1.0]
            for k, f in enumerate(told or []):
                if k == 0 and front:
                    continue
                at = k + len(front) if k else 0
                scales[at], floors[at] = 0.0, float(f)
            if (fed_floor or told is not None) and REST_FLOOR_INPUT in takes:
                feeds[REST_FLOOR_INPUT] = np.array(floors, dtype=np.float32)
            if (fed_scale or told is not None) and DUR_SCALE_INPUT in takes:
                feeds[DUR_SCALE_INPUT] = np.array(scales, dtype=np.float32)
            return feeds

        # the sung graph, where a mark moves the pitch and this call reads the checkpoint's stock graph
        pitched = contours = None
        if inflect and any(m.shapes() or m.flatten > 0.0 for m in inflect.values()) and kk.get("family"):
            family = kk["family"]
            if moving is None and sess is self._models.get(family):
                pitched, contours = self._sung_graphs(family) or (None, None)
            elif moving is not None and sess is self._moving.get(family):
                pitched, contours = self._sung_graphs(family, moving=True) or (None, None)

        def inflected(a: int, b: int, more: list, told, lead, feeds: dict):
            """`feeds` with the pitch the marks ask for laid on the call's own plan (`f0_keep`), None where it moves
            no pitch."""
            import inflection

            plan = np.asarray(self._planner(sess).run(None, feeds)[-1]).reshape(-1)
            front = (len(lead) + 1) if lead else 0
            back = (len(more) + 1) if more else 0
            owners = [-1] * (1 + front) + owner[a:b] + [-1] * (back + 1)
            sounds = [False] * (1 + front) + sound[a:b] + [False] * (back + 1)
            if len(owners) != plan.size:
                return None
            cores: dict = {}
            for k in range(a, b):
                if is_core[k] and sound[k]:
                    cores.setdefault(owner[k], []).append(1 + front + k - a)
            stress = {w: (ks[0], ks[-1]) for w, ks in cores.items()}
            f0 = energy = None
            if contours is not None and any(m.flatten > 0.0 or m.voice for m in inflect.values()):
                got = contours.run(None, feeds)
                names = [o.name for o in contours.get_outputs()]
                f0, energy = got[names.index("f0_planned")], got[names.index("n_planned")]
            # the shapes laid where the sounds are heard (PLAN_LEAD early), two curve steps a frame
            lead_steps = int(round(PLAN_LEAD / (frame_s / 2.0)))
            keep = inflection.curve(inflect, owners, plan.tolist(), sounds, stress, f0, lead=lead_steps)
            if keep is None:
                return None
            # a vowel the plan whispers, voiced where a mark asks (`voice`): the pitch told outright
            vowels = {1 + front + k - a for k in range(a, b) if vowel[k]}
            got = inflection.voiced(inflect, owners, plan.tolist(), vowels, stress, f0, keep, lead=lead_steps)
            if got is not None:
                pitch, _told, loud = got
                return {**feeds, "f0_keep": np.zeros(1, np.float32), "f0_set": pitch.reshape(1, -1),
                        "n_keep": np.zeros(1, np.float32),
                        "n_set": inflection.lifted(energy, loud, f0).reshape(1, -1)}
            return {**feeds, "f0_keep": keep.reshape(1, -1)}

        def read(a: int, b: int, more: list, told=None, lead=()):
            """ids[a:b] in one call, `lead` said before them and `more` after: (audio, the plan's frames an id, a pad
            at each end)."""
            feeds = feeds_of(a, b, more, told, lead)
            sung = inflected(a, b, more, told, lead, feeds) if pitched is not None else None
            out = pitched.run(None, sung) if sung is not None else sess.run(None, feeds)
            planned = np.asarray(out[1]).reshape(-1).astype(np.float64)
            # an unpatched graph hands back the plan before its Round and Clip: done here as there
            return (np.asarray(out[0]).reshape(-1).astype(np.float32),
                    planned if REST_FLOOR_INPUT in takes else np.maximum(np.round(planned), 1.0))

        def led(a: int, b: int, more: list, told: list):
            """ids[a:b] read with `before` said first and the take cut in the rest after it (`_cut_before`): (audio,
            plan) as `read` hands them back without it, the first pad what is left before the sentence - None where
            the model reads on into the sentence."""
            audio, planned = read(a, b, more, told, before)
            n = len(before) + 2  # the pad, the words before and the word-space after them
            said = 1 + max(k for k, i in enumerate(before) if i != space and i not in marks)
            first = n + next(k for k in range(b - a) if sound[a + k])
            cut = _cut_before(audio, planned, said, first, frame_s)
            if cut is None:
                return None
            audio = audio[cut:].copy()
            fade = min(audio.size, int(round(BEFORE_FADE * SR)))
            audio[:fade] *= (0.5 - 0.5 * np.cos(np.linspace(0.0, np.pi, fade))).astype(np.float32)
            return audio, np.concatenate(([max(0.0, float(planned[:n].sum()) - cut / float(HOP))], planned[n:]))

        pieces = _pieces(ids, units, unit_of)
        for a, b in pieces:
            # the pace never squashes a vowel: each floored at its frames at speed 1.0, up to VOWEL_LEAST
            if speed > 1.0 and told_plan and any(vowel[a:b]):
                at_one = np.asarray(self._planner(sess).run(None, feeds_of(a, b, [], pace=1.0))[-1]).reshape(-1)
                for k in range(a, b):
                    if vowel[k]:
                        floor[k] = max(floor[k], min(float(VOWEL_LEAST), float(at_one[1 + k - a])))
                fed_floor = fed_floor or any(floor[a:b])
            # a word inflected slower, by whole frames: planned, its sounds' frames times its `slow` laid out with
            # each one's remainder carried to the next, and floored there (a 2-frame sound times 1.12 rounds back to 2)
            slowed = {w: float(m.slow) for w, m in (inflect or {}).items() if m.slow != 1.0}
            if slowed and told_plan and any(owner[k] in slowed for k in range(a, b)):
                plan = np.asarray(self._planner(sess).run(None, feeds_of(a, b, []))[-1]).reshape(-1)
                carry: dict = {}
                for k in range(a, b):
                    if sound[k] and owner[k] in slowed:
                        exact = float(plan[1 + k - a]) * slowed[owner[k]] + carry.get(owner[k], 0.0)
                        n = float(round(exact))
                        carry[owner[k]] = exact - n
                        floor[k] = max(floor[k], n)
                fed_floor = True
            # the sentence's end is not the call's (AFTER_WORDS): words after it, and the take cut before them
            more = []
            heard = [k for k in range(a, b) if sound[k]]
            if (a, b) == pieces[-1] and space is not None and told_plan and heard:
                more = _after(ids, units, unit_of, sound, int(params.get("after", AFTER_WORDS)))
                if b - a + 1 + len(more) > MAX_TOKENS:
                    more = []
            # ...nor its start, where the request says what was said before it
            lead = (a, b) == pieces[0] and heard and before and b - a + len(before) + 2 + len(more) <= MAX_TOKENS
            if more or lead:
                planner = self._planner(sess)
                alone = np.asarray(planner.run(None, feeds_of(a, b, []))[-1]).reshape(-1)
                last = 1 + heard[-1] - a  # the place in a call's plan (a pad first) of the sentence's last sound
                own = [float(alone[k]) for k in range(last)]  # its plan alone up to it
            if more:
                # the sentence's plan made alone and followed, and the call told what it keeps of them (`_told`)
                followed = np.asarray(planner.run(None, feeds_of(a, b, more))[-1]).reshape(-1)
                # ...and where a mark follows (a pad first): its rest is the sentence's own
                marked = [False, *[k + 1 < b and ids[k + 1] in marks for k in range(a, b)]]
                told = _told(alone, followed, last, marked)
                got = led(a, b, more, told) if lead else None
                take, planned = got if got is not None else read(a, b, more, told)
                cut = _cut_after(take, planned, last, 2 + b - a + sound[: len(more)].index(True), frame_s)
                if cut is None:  # it read on: the sentence alone
                    got = led(a, b, [], own) if lead else None
                    take, planned = got if got is not None else read(a, b, [])
                else:
                    take, planned = take[:cut], _plan_to(planned[: 1 + b - a], cut / float(HOP))
            elif lead:
                got = led(a, b, [], own)
                take, planned = got if got is not None else read(a, b, [])
            else:
                take, planned = read(a, b, [])
            audio_parts.append(take)
            frames_parts.append(planned)
            lay_owner += [-1, *owner[a:b], -1]
            lay_rest += [-2, *rest_of[a:b], -2]
            lay_sound += [False, *sound[a:b], False]
            lay_unit += [-1, *unit_of[a:b], -1]
            lay_floor += [0.0, *floor[a:b], 0.0]
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
        floors = np.array(lay_floor if fed_floor and REST_FLOOR_INPUT in takes else [0.0] * frames.size, np.float64)
        # what `_trim_ends` left at the ends is seconds, not plan: counted by `_nominal` as whole frames, a
        # pad cut to a sliver would make a pitch move resample the words long
        heard = [k for k, s in enumerate(lay_sound) if s]
        if heard:
            floors[: heard[0]] = HELD
            floors[heard[-1] + 1 :] = HELD
        self._last_floor = floors
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
        """Where a rest after token `ti` may be cut: from GAP_BACK before the end the plan (told PLAN_LEAD
        earlier) gives the word to GAP_REACH past the next word's start, never past either word. Not wider:
        where Kokoro reads through a comma there is no silence between the words, and a wider window finds
        the longest silence inside a word (a stop's closure) and puts its release after the rest."""
        here, nxt = edges.get(ti), edges.get(ti + 1)
        if here is None or nxt is None:
            return None
        lo = max(float(here[0]), float(here[1]) - GAP_BACK)
        hi = min(float(nxt[1]), float(nxt[0]) + GAP_REACH)
        return (lo, hi) if hi > lo else None

    @staticmethod
    def _nominal(frames, ratio: float, sr: int, floor=None) -> float:
        """`_nominal_seconds` for a rounded plan: a token planned at `m` frames was asked for between m -
        1/2 and m + 1/2, so at another scale it falls in that interval over the ratio, and the mean of the
        Round over it is closed form (the integral of a staircase). One frame is the clip's, a floored token
        keeps its floor, and a take's trimmed ends (a floor of HELD) are the seconds they were cut to, the
        same at any scale."""
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
        exp = np.maximum(np.where(m <= 1.0, 1.0, exp), 1.0)
        if floor is not None:
            f = np.asarray(floor, dtype=np.float64)
            exp = np.where((f > 0.0) & (m <= f), np.maximum(m, 1.0), exp)
            exp = np.where(f == HELD, m, exp)
        return float(exp.sum()) * HOP / float(sr)

    @staticmethod
    def _delivered(audio, sr: int):
        """At OUT_RATE, the rate every take of a reading is joined at. The seconds are the same."""
        if sr == OUT_RATE or audio.size < 2:
            return audio, sr
        return _resample(audio, sr / float(OUT_RATE)), OUT_RATE


# The silence at a take's ends, as the seam between two sentences was measured on Piper (piper.py `DWELL`,
# the full stop's 0.18: 0.138-0.145 s after a sentence and 0.044 before the next). The seam splices its gap
# on that assumption and Kokoro's own ends hold more (its first pad rests 14 frames, 350 ms; a sentence's
# mark, word-space and pad another 225 ms: seams of 2.57-2.79 s against Piper's 1.89-2.06 at the same
# Pause), so a take is trimmed to them (`_trim_ends`).
SEAM_LEAD = 0.044
SEAM_TAIL = 0.14
# What counts as sound at a take's ends: a share of its peak, as the splicer's SPLICE_QUIET.
SEAM_QUIET = 0.02

# A sentence's end is not the call's. Kokoro was taught on calls of many sentences (its own pipeline packs a
# paragraph into one), and at the end of a call it lets the last word go: a short one is planned as it is
# anywhere and said far under the same word with more after it, whatever its stress or its length. So a
# sentence that ends on a full stop is followed in its call by a word-space and its own first AFTER_WORDS
# words (`_after`), and the take is cut in the rest the model makes at the stop (`_cut_after`); where it
# makes none, the sentence is read alone.
# What is followed is planned faster too (in Nicole's voice the words before the last a median 11% shorter, some
# a third; a short word's vowel a frame less, and "his" heard as "a"), so the sentence's plan is made alone
# first and the call told it (`_told`): its pace is the one it has alone.
AFTER_WORDS = 1
# Read alone, a sentence is held mid-way where read in a paragraph it is not ("The subject means that's..." holds
# subject's t 8 frames, means' z 9 and that's s 7, followed 4, 5 and 3: heard as hesitations; 38 such holds in
# 86 of Nicole's sentences alone, 14 followed). So no sound before the last is told more than this many frames
# past its plan followed: a frame's difference (the pace, a short vowel) is the sentence's own, a hold is not.
HOLD_OVER = 1
# A sentence of this many words or fewer is read alone: told its plan, Nicole reads on at the stop after every
# one of them, so the call would be thrown away.
ALONE_WORDS = 1
# The rest at the stop: under this share of the peak, where nothing sounds at all (a faint last sound, a hum
# or a soft hiss under SEAM_QUIET, is over it).
AFTER_QUIET = 0.005
# What is said before a sentence is cut away in the last rest after it at least this long (one word before is
# followed by none in most calls, three by one in most: next/voice_engines.md, "The sentence before it")...
BEFORE_REST = 0.09
BEFORE_REACH = 0.03  # ...looked for this far past the sentence's first sound by the plan
BEFORE_FADE = 0.01  # the take fades in over this from the cut, in the silence SEAM_LEAD before its first sound


# Nothing hisses after a voice that ended voiced. On a sentence ending in a vowel Kokoro often renders a
# burst of hiss as the voice lets go and through the mark after it ("Oh." 18 to 23 dB under the peak, 86 to
# 99% of it above 4 kHz; heard as "Load", "Ose"). Where the plan says the last sound was voiced (a vowel, or
# l r m n ŋ w j), what follows the waveform's last voiced moment is let go of over TAIL_FADE; a last sound
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
    # voice is a run of TAIL_RUN frames: a lone low frame at the very end (a thump in the last pad) is not
    # the voice going on, and taken for it would keep the hiss before it
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
    SEAM_TAIL after its last: each cut only where the plan holds no sound (the first pad's frames at the
    head, told PLAN_LEAD early; the marks, word-space and pad after the last sounding token at the tail) and
    only where the waveform is quiet. The frames are cut with the audio, so they still add up to it and
    every time read off them stays exact."""
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
    first = next((k for k, s in enumerate(sound) if s), len(sound))
    opening = float(frames[:first].sum()) * frame_s - PLAN_LEAD
    head = max(0.0, min(heard_from, opening) - SEAM_LEAD)
    last = max((k for k, s in enumerate(sound) if s), default=-1)
    total = float(frames.sum()) * frame_s
    said_to = float(frames[: last + 1].sum()) * frame_s
    tail = max(0.0, total - max(heard_to + SEAM_TAIL, said_to))
    cut0 = int(round(head * sr))
    cut1 = int(round(tail * sr))
    if cut0 + cut1 >= audio.size:
        return audio, frames
    left = cut0 / sr / frame_s
    for k in range(first):
        take = min(frames[k], left)
        frames[k] -= take
        left -= take
        if left <= 0.0:
            break
    left = cut1 / sr / frame_s
    for k in range(frames.size - 1, last, -1):
        take = min(frames[k], left)
        frames[k] -= take
        left -= take
        if left <= 0.0:
            break
    return audio[cut0 : audio.size - cut1], frames


def _after(ids: list, units: list, unit_of: list, sound: list, words: int) -> list:
    """The ids said after a sentence so that its end is not the call's (AFTER_WORDS): its own first `words`
    words, up to the mark or word-space that ends the last of them - [] where it does not end on a full stop
    (SENTENCE_END: what trails off or breaks off is read to the call's end) or is of ALONE_WORDS words or fewer."""
    own = sum(1 for k in range(len(sound)) if sound[k] and (k == 0 or not sound[k - 1]))
    if words <= 0 or own <= ALONE_WORDS or units[unit_of[-1]][0] not in SENTENCE_END:
        return []
    out: list = []
    said = 0
    inside = False
    for k, i in enumerate(ids):
        if sound[k]:
            said += 0 if inside else 1
            inside = True
        elif inside and said == words:
            break
        else:
            inside = False
        out.append(i)
    while out and not sound[len(out) - 1]:
        out.pop()
    return out


def _told(alone, followed, last: int, marked: list) -> list:
    """What a call with words after its sentence is told of the sentence's plan: the frames of every id before its
    last sound. `alone` and `followed` are the sentence's plan read alone and followed by the words (a pad first),
    `last` the place of its last sound, `marked` whether a mark follows each place. Each id is told its frames
    alone, but never more than HOLD_OVER past its frames followed - save before a mark, whose rest is the
    sentence's. The last sound and the stop are the call's: it plans the stop's rest on them, and frames forced
    on them are voiced (held to the frames the sentence has alone, "Patient." is followed by 0.3 s of a whispered
    vowel 14 to 25 dB under its peak, heard as "Patient-ah")."""
    return [float(alone[k]) if k == 0 or marked[k] else float(min(alone[k], followed[k] + HOLD_OVER))
            for k in range(last)]


def _cut_after(audio, frames, last: int, nxt: int, frame_s: float):
    """Where a call read with words after its sentence ends as the sentence's own take, in samples - or None
    where the model did not rest at the stop. `frames` is the call's plan (a pad first), `last` the place in it
    of the sentence's last sound and `nxt` of the first sound after it. The plan gives a stop's rest to the
    sound before it, so the rest is looked for in the waveform: the longest stretch under AFTER_QUIET from the
    start of the last sound to the start of the words after. The cut is SEAM_TAIL past the last moment over
    SEAM_QUIET (what `_trim_ends` leaves after a take) and never before the rest starts, and the rest must
    run SEAM_LEAD past it."""
    import numpy as np

    sr = HOP / frame_s
    step = max(1, int(0.005 * sr))
    lo = int(max(0.0, float(frames[:last].sum()) * frame_s - PLAN_LEAD) * sr) // step
    hi = min(audio.size // step, int(max(0.0, float(frames[:nxt].sum()) * frame_s - PLAN_LEAD) * sr) // step)
    if hi - lo < 2:
        return None
    level = np.sqrt((audio[: hi * step].reshape(hi, step).astype(np.float64) ** 2).mean(axis=1))
    peak = float(np.max(np.abs(audio[: hi * step])))
    if peak <= 0.0:
        return None
    # the longest run of rest in [lo, hi), as (start, end)
    rest = np.concatenate(([False], level[lo:] <= AFTER_QUIET * peak, [False]))
    turns = np.flatnonzero(rest[1:] != rest[:-1])
    if turns.size == 0:
        return None
    runs = turns.reshape(-1, 2)
    k = int(np.argmax(runs[:, 1] - runs[:, 0]))
    start, end = lo + int(runs[k, 0]), lo + int(runs[k, 1])
    loud = np.flatnonzero(level[:start] > SEAM_QUIET * peak)
    heard_to = int(loud[-1]) + 1 if loud.size else 0
    cut = max(start, heard_to + int(round(SEAM_TAIL * sr / step)))
    if end - cut < int(round(SEAM_LEAD * sr / step)):
        return None
    return cut * step


def _cut_before(audio, frames, said: int, first: int, frame_s: float):
    """Where a call read with words before its sentence starts as the sentence's own take, in samples - or None
    where the model did not rest after them. `frames` is the call's plan (a pad first), `said` the place in it of
    the last sound before the sentence and `first` of the sentence's first sound. The rest is looked for from the
    start of that sound to BEFORE_REACH past the start of the first (by the plan, PLAN_LEAD early): the last
    stretch under AFTER_QUIET at least BEFORE_REST long. The cut is SEAM_LEAD before its end, where `_trim_ends`
    leaves a take's head, and never before it starts."""
    import numpy as np

    sr = HOP / frame_s
    step = max(1, int(0.005 * sr))
    lo = int(max(0.0, float(frames[:said].sum()) * frame_s - PLAN_LEAD) * sr) // step
    hi = min(audio.size // step,
             int(max(0.0, float(frames[:first].sum()) * frame_s - PLAN_LEAD + BEFORE_REACH) * sr) // step)
    if hi - lo < 2:
        return None
    peak = float(np.max(np.abs(audio)))
    if peak <= 0.0:
        return None
    level = np.sqrt((audio[: hi * step].reshape(hi, step).astype(np.float64) ** 2).mean(axis=1))
    rest = np.concatenate(([False], level[lo:] <= AFTER_QUIET * peak, [False]))
    runs = np.flatnonzero(rest[1:] != rest[:-1]).reshape(-1, 2)
    least = int(np.ceil(BEFORE_REST * sr / step - 1e-9))
    long_enough = [(int(s), int(e)) for s, e in runs if e - s >= least]
    if not long_enough:
        return None
    start, end = long_enough[-1]
    return (lo + max(start, end - int(round(SEAM_LEAD * sr / step)))) * step


def _plan_to(frames, total: float):
    """`frames` (a call's plan through its sentence's last id) as the plan of a take cut at `total` frames, a last
    pad after it: what the plan holds past the cut taken off its end (a stop's rest is planned on the sound before
    it), what the take holds past the plan the pad's. It adds up to the take, as `_trim_ends` leaves it."""
    import numpy as np

    out = np.append(np.asarray(frames, dtype=np.float64), 0.0)
    left = float(out.sum()) - total
    if left < 0.0:
        out[-1] = -left
    for k in range(out.size - 2, 0, -1):
        if left <= 0.0:
            break
        take = min(out[k], left)
        out[k] -= take
        left -= take
    return out


def _span(value):
    """A request's `plan_span` as (start, end) within 0..1, or None where it is not two numbers."""
    try:
        u0, u1 = (min(max(float(v), 0.0), 1.0) for v in value)
    except (TypeError, ValueError):
        return None
    return (u0, max(u0, u1))


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


def _pieces(ids: list, units: list, unit_of: list, most: int = MAX_TOKENS) -> list:
    """[(a, b)] spans of `ids` of at most `most` each, cut after a word-space - the one after a
    mark nearest the limit where there is one in the piece's second half, else the last."""
    out: list = []
    a = 0
    n = len(ids)
    while n - a > most:
        hi = a + most
        cut = None
        for k in range(hi - 1, a + most // 2, -1):
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
