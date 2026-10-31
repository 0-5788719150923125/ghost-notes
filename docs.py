#!/usr/bin/env python3
"""Auto-docs generator for ghost.

The Praxis move (see praxis/docs.py) applied to a Godot project: introspect
the source of record and generate the documentation from it, so the docs
cannot drift from the code. Here the source of record is the GDScript
itself - every script carries a leading `##` doc comment, the scene roster
is the literal `SceneRoster.SCENES` array (`src/scenes/roster.gd`), the component registries are
literal `const REGISTRY := {...}` dictionaries, and the Masking effect
table is `MASK_EFFECTS` / `EFFECT_CONTROLS`. This script parses all of
that statically (no Godot boot required) and writes:

  docs/index.md        - the map: design, the pages, directory layout, every script.
  docs/components.md   - what a note can carry: components, slots, workspaces, capabilities.
  docs/scenes.md       - the scene catalog, from each scene's own doc.
  docs/media.md        - the Medium registry: what the show is carried on.
  docs/filters.md      - the Look: the post-process over the whole picture.
  docs/layers.md       - the Layer registry (visual components).
  docs/forces.md       - the Primitives registry (physics forces).
  docs/stage.md        - the storyboard stage: Cast actors + Actions verbs.
  docs/masking.md      - the Masking: effects, controls, CLI.
  docs/script.md       - every mark a script may carry.
  docs/architecture.md - how the show is made, from the audio to a video file.
  docs/environment.md  - what Ghost Notes installs itself, and what stays the machine's.
  docs/agents.md       - the AI agents: who writes, who paints, the assistant, how to install one.
  docs/structure.md    - src/ as a stack of folders, and what each names.
  docs/cli.md          - every ghost command-line flag.

The README is stubs and lists that link here: docs.py patches it between
`<!-- AUTODOC:NAME:BEGIN/END -->` marker pairs (FEATURES, SUBSYSTEMS, LAYOUT),
the same mechanism as praxis/docs.py, and keeps next/roadmap.md's open items
above its closed ones, as Praxis keeps its roadmap.

How it is built, top to bottom: the curated maps (what a parser cannot know); ONE READER of
GDScript (`Script`, and `const`, which reads any constant as Python data - a registry is never
picked apart by a pattern); the page kit (`page`, `entry`, `table`: a page is a list of blocks);
one builder per page, each mapping its registries to blocks; the checks - the pattern rules as
rows (`RULES`, each with the planted wrong it must catch), and the few that need a model of the
code (the stack, the fields, the user folder); and `main`.

Writes are idempotent: a file is only touched when its content changes.
Drift that a human must resolve (a script missing from the group map, a
CLI flag missing from the table, a scene on disk but not registered) is
printed as a warning and surfaced in the generated docs rather than
silently dropped.

Run from anywhere: ``python docs.py`` (stdlib only). ``python docs.py --check`` writes
nothing and exits 1 if a generated file is stale or anything drifted - what
scripts/check.sh runs.
"""

from __future__ import annotations

import ast
import re
import sys
from fnmatch import fnmatch
from functools import cached_property
from pathlib import Path
from typing import Any, Callable, Dict, Iterable, List, NamedTuple, Optional, Sequence, Tuple, Union

ROOT = Path(__file__).resolve().parent
SCRIPTS = ROOT / "src"
SCENES_DIR = SCRIPTS / "scenes"
DOCS = ROOT / "docs"

WARNINGS: List[str] = []
## --check: report what would be rewritten instead of rewriting it.
CHECK = "--check" in sys.argv[1:]
STALE: List[str] = []


def warn(msg: str) -> None:
    WARNINGS.append(msg)
    print(f"[ghost-docs] WARNING: {msg}", file=sys.stderr)


# ---------------------------------------------------------------------------
# Curated maps. These carry the judgments a parser can't make: how scripts
# group into subsystems, and what each CLI flag means. Both are verified
# against the source at every run - a script or flag that exists in the
# code but not here is reported, so the map can rot loudly, never quietly.
# ---------------------------------------------------------------------------

# THE STACK. Every folder under src/, BOTTOM FIRST: (folder, title, description). A script may
# name scripts in its own folder and in the folders listed above its own here - never one below
# it in this list. A script's group is its folder, so nothing lists file names: a new script is
# in the docs by being in a folder, and a new folder is a row here. The order is held against
# the code at every run (`check_structure`); next/structure.md is why it is this order.
FOLDERS: List[Tuple[str, str, str]] = [
    ("data", "Plain data",
     "Plain data in and out, at the bottom because it needs nothing: the YAML-subset parser, a document's frontmatter "
     "(re-read, one key edited, verified), pure edits of nested data, reading any registry's rows (`Registry`), what "
     "an agent is told (`rules/`), and a script read into cues, hesitations and pictures."),
    ("platform", "The machine",
     "The machine under Ghost Notes: the one owner of its settings file, the earliest hook of a launch, the icon drawn "
     "for the machine (and for a build's package), every child program in one place, what ghost installs for itself "
     "and keeps current, the app's own update, and what this platform can do."),
    ("audio", "Audio & analysis",
     "From a song file to the typed per-frame `AudioFeatures` every scene consumes - live analyzer, offline bake, and "
     "the content descriptors that make sessions deterministic per song."),
    ("render", "Drawing",
     "How things get drawn and how a heavy scene stays interactive: thousands of shapes in one draw call, geometry "
     "built off the main thread, the lens, planes and meshes of the software 3D path, color, and how soft a light's "
     "shadow is."),
    ("motion", "Motion & simulation",
     "How things move: seeded oscillators, sparse response gating, the nonlinear kit and flow fields, the forces "
     "particles compose by key (`Primitives`), the fixed-rate tick, and running systems whose STATE is the picture - a "
     "granular automaton, a flock with a spatial hash, a plate's standing waves, a water surface."),
    ("geometry", "Generative form",
     "Self-contained generators a scene composes rather than hand-models - each one samples a space of shapes from a "
     "seed and hands back plain geometry - with the procedural fields, terrain heightfields and shadowing of the 3D "
     "world, and the composed bodies. The `cattle, not pets` discipline, made into parts."),
    ("scene_kit", "Scene substrate",
     "What every scene is built on: the `GhostScene` base and its 3D sibling, the camera, framing pools, lighting, the "
     "visual layers scenes compose by key (`Layer`), and `ShowFeed` - what the show hands the parts it mounts."),
    ("stage", "Storyboards & stage",
     "A show written down, as data: the storyboard's spec and its field tables, and the Cast/Actions/Track stack that "
     "renders a described scene. See [storyboards/README.md](../storyboards/README.md) for the data spec and "
     "[stage.md](stage.md) for the fields and the actor/verb registries."),
    ("scenes", "Scenes",
     "The catalog, one scene a file. Cataloged in [scenes.md](scenes.md), each from its own doc comment."),
    ("agents", "Agents",
     "Every piece of writing and painting ghost asks an AI for: who writes (TextGen) and who paints (ImageGen), one "
     "queue for both (AgentJobs), the tools ghost serves an agent while it works (AgentTools), which Amazon Bedrock "
     "models an AWS account can call (BedrockCatalog), and how the Assistant's command-line tools are run."),
    ("notes", "Notes",
     "The note as a file: where notes live, a document kept in step with its file, the registry of what a note can "
     "carry (`Components`), the registry of the marks a script may carry (`ScriptMarks`), and where a note's cards "
     "meet without naming each other: an episode one card makes (`EpisodeFeed`) and the steps the others add to it "
     "(`EpisodeStep`)."),
    ("ui", "The panel kit",
     "What every note's panel is built from, and what it asks of the window it is in: a side panel that cannot outgrow "
     "the window and its \"+\", a component's folding card in its family's color and the chips over the cards, the "
     "cards a note's components bring (built from the registry's rows, attached and detached), the Script card every "
     "note has (its editor window and highlighter), rows drawn from a table of fields, two small controls, and `Shell` "
     "- the bottom-right row, room along the bottom edge, the way back to the notes. Above `notes/` because it is a "
     "kit for a note's components."),
    ("voice", "Synthesis (voice)",
     "Text to narrated audio in two paths: ghost's own source-filter synthesizer (no models, no weights, fully "
     "inspectable, and the only path that can sing), and a small local neural voice run by a subprocess host. Shared "
     "between them: the text front end and its normalization, the threaded real-time stream and the buffer effects. "
     "Design: next/voice.md."),
    ("media", "Media",
     "What the show is carried on: the `Medium` base and its registry, each medium ([media.md](media.md)), the layouts "
     "they set (comic pages, a novel, a notebook, a tablet's pages), the films and pictures they show, and where a "
     "reading is in its document."),
    ("show", "The show",
     "The player: the Director's schedule and transitions, the one transport, karaoke subtitles, the Look over the "
     "whole picture, and the cards of the show's own settings."),
    ("timeline", "The storyboard's editor",
     "The card that keeps a note's storyboard and the dock it opens: a strip of entries, a stage entry's lanes, and "
     "the ruler."),
    ("export", "Export",
     "Rendering a session to video (bake + Movie Maker, background processes) and uploading it to YouTube. Under the "
     "workspaces: a reading and a show of cards export a take and fill in an upload, and the exporter names neither."),
    ("reading", "The voice's workspaces",
     "The panels a voice runs in: the reading (script, cast, voice, stream, export), the Generative editor built on "
     "it, and the voice lab with the fishing game that breeds its voices."),
    ("table", "The set",
     "A place, seen and heard, built from a written description: the table itself (Tables), the things on it (Props), "
     "its air (Effects, and what the wind carries: Drifts), its light (Lights) and the one wind both share (Winds), "
     "its sound (Soundscape), where cards go on it, what can be done with them and how a reading says so, the faces "
     "printed on them - and the medium that puts it all on the stage (`table.gd`, a row of `Medium.REGISTRY`)."),
    ("table_show", "The table's show",
     "A show at a table nobody writes: a show's brief, its episodes - each planned, dealt, painted and written by "
     "agents a card or a beat of work at a time, kept on disk step by step - the set dresser that builds the table and "
     "the puppeteer that works what stands on it. The rules are every show's; the brief says what is done there - "
     "cards read (tarot, baseball or trading cards, a card game's deck, flashcards, recipe cards, listed or left to "
     "each episode's producer), things made, or both. Design: next/cards.md, next/table_work.md."),
    ("desk", "The desk",
     "A study where a ghost does math, seen and heard: the ink (formulas TeX lays out, written stroke by stroke in a "
     "seeded hand from the Hershey stroke fonts), the pad, the pen that moves by itself, the instruments it reaches "
     "for - a calculator, a tablet, a screen with Lean on it - and the medium that puts them on the stage. Its room is "
     "built from the table's parts - and the letter written at the same desk: its own cursive hand (the Hershey script "
     "font, no TeX), what it says and writes, and its medium. Design: next/proof.md, next/letter.md."),
    ("proof", "Proof",
     "A ghost doing math, made by agents: a note's problem fixed, worked at the desk with Lean - a lab notebook, "
     "checks, a proof handed in only when verified - and taught, each episode kept on disk step by step; the solver's "
     "tools, the rules each agent is told, and the card that runs it all and hands the reading its lesson. Design: "
     "next/proof.md."),
    ("letter", "Letter",
     "A note read as a letter written by hand at a desk: the card that pins its medium, draws its sketches (an agent's "
     "SVG, laid out by the Proof pad's ink step) and paints its pictures (the Illustrations library's), and hands the "
     "reading the letter with the pen's rests in it. Design: next/letter.md."),
    ("likeness", "Likeness",
     "An actor played from their own footage: the library of actors, each built from their videos (a folder, or links "
     "fetched) - surveyed, grouped into sets by camera and look, the agent that audits them, a still of each set and a "
     "model of them from every video (their head's motion, their blinks, their mouths for each sound, their voice) - "
     "the card that makes one and puts them on a note's stage, and the medium that plays them reading it: the still, "
     "its head turned and its mouth and eyes drawn from their own, through one mesh over the frame; and a voice alone, "
     "taught their speech from their recordings by the Voice training card. Design: next/likeness.md."),
    ("masking", "Masking",
     "The video chroma-key masking editor - a second app surface inside ghost. See [masking.md](masking.md)."),
    ("app", "The shell",
     "The lifecycle around everything, and the one folder that names every other: main, the furniture every mode gets "
     "(Chrome), the notes list and a note's own panel, the phone shell, the authoring loop - the log, the feedback "
     "console and the Assistant - and the recorder of the README's animation, which drives the real app."),
]

# WHAT STILL POINTS UP: (pattern, the fix, [(script, the script above it that it names)]),
# scripts as `folder/name`. `check_structure` holds this list to the code BOTH WAYS: a script
# that names one above it and is not listed here fails the check, and so does a pair listed
# here that is no longer in the code - so the list can only shrink, and when a pattern is
# fixed its rows are deleted with it. Never add a row to make a new reference pass: hand the
# script what it reads instead (next/structure.md, "The rules").
#
# EMPTY SINCE 2026-10-13: it began at 48 pairs in eight patterns, and each went by one of four
# moves - a helper moved down to the folder that could own it, a contract put under both sides
# (`Shell`, `ShowFeed`, `SoundBed`), a registry row naming its script by path
# (`Components` `script`, `Capabilities.ROLES`, `Medium.REGISTRY`), or a script moved to the
# folder it turned out to belong in. Keep it empty: a row here is a debt, with a date.
UPWARD: List[Tuple[str, str, List[Tuple[str, str]]]] = []

# WHAT A MOUNTED PART IS HANDED, AND NEVER NAMES (next/structure.md, step 11): {script: the
# folders whose scripts read it only through what they are handed}. A scene, a medium and the
# table are mounted by a show and read it through their `feed` ([ShowFeed]) - its seed, its dials,
# its clock. The Director is above most of them anyway; the audio engine is BELOW all of them, so
# the stack alone allows it, and a medium that read the clock off `Spectrum` could only ever be
# played by a song - never by a preview a timeline scrubs, or a live show its agents conduct.
HANDED: Dict[str, List[str]] = {
    "audio/spectrum": ["scene_kit", "scenes", "media", "table", "desk"],
    "show/director": ["table", "desk"],
}

# (flag, argument placeholder, description, internal). Internal flags are passed between ghost's
# own processes (exporter -> render, editor -> render), not meant for hand use. Held against the
# flags the code reads (`flags_read`) both ways.
CLI_FLAGS: List[Tuple[str, str, str, bool]] = [
    ("--audio", "<path>",
     "Load this song (`.wav` / `.mp3` / `.ogg` / `.flac`; FLAC is transcoded via ffmpeg) and start straight on it, "
     "past the notes list.", False),
    ("--scene", "<name|N>", "Pin one scene for authoring (by script-name substring or registry index).", False),
    ("--medium", "<name>",
     "What the show is carried on for this run: `full` (one scene filling the frame) or `comic` (a comic page). "
     "Overrides the remembered setting; see [media.md](media.md).", False),
    ("--filter", "<k=v,...>",
     "The look over the whole picture for this run - `--filter monochrome=1,static=0.3`, or `--filter none`. Overrides "
     "the remembered set; see [filters.md](filters.md).", False),
    ("--live-tap", "",
     "Record what the mixer actually plays - the Master bus, the last two minutes - to user://synth/live_tap.wav when "
     "ghost quits. For when what you hear and what a measurement says disagree.", False),
    ("--clock-watch", "",
     "Report when the show's clock stops advancing while frames keep being written - the shape a frozen recording "
     "takes. On automatically in every render; useful on a plain session because that runs at the speed of the audio "
     "rather than the encoder.", False),
    ("--until", "<seconds>",
     "Stop at this point on the show clock. Renders a slice instead of the whole thing, which is how a defect deep in "
     "a long export is reproduced without paying for the whole export.", False),
    ("--storyboard", "<name>", "Manual mode: play `storyboards/<name>.yaml` (or `.json`).", False),
    ("--frame", "landscape|portrait",
     "The show's frame for this run - 16:9 or 9:16 - over the remembered one, as `--medium` overrides the medium. A "
     "medium without a portrait frame plays landscape. Passed to an export's render, so it renders the frame the "
     "session showed.", False),
    ("--handheld", "",
     "Run the phone shell on the desktop: the notes list and the editor, full screen in a phone's shape, no stage, no "
     "transport, nothing downloaded (`GHOST_HANDHELD=1` does the same). A phone runs it always.", False),
    ("--note", "<path>",
     "Open one note, in the workspace its components name (a voice's reading, a show of cards, the note's own panel "
     "for its words or a song) - past the notes list.", False),
    ("--deps", "",
     "Print the environment report - what ghost has installed for itself (FFmpeg, uv, Python, each feature's "
     "environment), what it uses from the machine, versions and resolved paths, and an install hint for anything of "
     "the machine's that is missing - then exit. Exits non-zero if something a feature needs is absent. Pairs with "
     "`--headless`; the same report is the Environment panel, behind the ⚙ in the bottom-right row.", False),
    ("--provision", "[all|update|KEY]",
     "Install ghost's own dependencies now, printing each step, then exit: uv, FFmpeg and Python by default, every "
     "feature's environment too with `all`, one row by its key with what it needs (`mathlib` brings Lean), or bring "
     "everything installed to its newest release with `update`. The same jobs an ordinary launch runs in the "
     "background. Exits non-zero if anything asked for could not be had. Pairs with `--headless`.", False),
    ("--seed", "<N>",
     "Override the session seed (default derives from the audio's own content fingerprint, so the same song replays "
     "the same show).", False),
    ("--synth", "[text-file]",
     "Open the voice-synthesis editor: write or paste a script, sample a voice by seed; each reading renders a WAV "
     "take and plays it as a normal session (scenes react to the narration; karaoke subtitles track it).", False),
    ("--say", "",
     "With `--synth`: speak the loaded text immediately on boot (automation, demos, headless checks).", False),
    ("--table", "",
     "Open the Table mode: a show's brief, its episodes (planned, dealt, painted and written by agents a card or a "
     "beat at a time) and the Generative voice that reads them at the table.", False),
    ("--mask-edit", "<session.json>",
     "Open the Masking editor on a session (also creates one from a video path).", False),
    ("--mask-render", "<session.json>", "Render a Masking session to video (used with `--write-movie`).", True),
    ("--export", "",
     "Marks a Movie Maker render process (set by the exporter; `Boot` shrinks the window early).", True),
    ("--export-smoke", "",
     "Check that an exported desktop app starts and can unpack its bundled Python hosts, then exit. Used by "
     "`scripts/smoke-export.sh`.", True),
    ("--export-smoke-note", "PATH",
     "With `--export-smoke`: also check that this note is recognized as a Table note.", True),
    ("--app-version", "", "Print the embedded app build version as JSON, then exit (release diagnostics).", True),
    ("--apply-update", "<target> <parent PID> <staged path> <sha256> <restart>",
     "Internal helper: after the parent exits, replace the portable executable with a verified update.", True),
    ("--update-smoke-hold", "",
     "Keep the exported app running briefly while the updater's replacement path is tested.", True),
    ("--synth-autopilot", "",
     "With `--export`: open the Synthesis panel over the take and let the fishing game play itself (random "
     "Throw/Pull/reel/hold-or-fold), so the UI is recorded into the video. Generates no audio and persists nothing "
     "(set by the exporter's 'Automate the Synthesis game' toggle).", True),
    ("--use-bake", "", "Drive `Spectrum` from the song's cached bake instead of the live analyzer.", True),
    ("--bake-file", "<path>", "Explicit spectrum-bake cache for a render (implies `--use-bake`).", True),
    ("--showcase-now", "",
     "Record the README's animation (`docs/showcase.webp`) now, stale or not, and quit; pairs with `--headless`. A "
     "development launch records it by itself when what it shows has changed (`src/app/showcase.gd`).", False),
    ("--showcase", "<work dir>",
     "Marks the README animation's Movie Maker recording (set by `Showcase`): plays the showcase note read-only and "
     "quits.", True),
    ("--bake-song", "<path>", "Export subprocess: the song to analyze.", True),
    ("--bake-out", "<path>", "Export subprocess: where to write the bake cache.", True),
]

# Godot's own flags that ghost's code reads too (a gate is run with `--script`): not ghost's.
GODOT_FLAGS = {"--script"}

# Top-level entries for the README LAYOUT block and docs/index.md, in that order.
# (name, description). A runtime folder (git-ignored, so absent from a clone) says so in its
# description and is listed without a link.
TOP_LEVEL: List[Tuple[str, str]] = [
    ("project.godot",
     "Godot 4.7 project; autoloads `Settings`, `Boot`, `Spectrum`, `Director`, `Provisioner`; `scenes/main.tscn` is "
     "the entry scene."),
    ("scenes/", "The Godot entry scene (`main.tscn`). Everything else is code-built."),
    ("src/",
     "All GDScript, in one level of folders that are a stack: a script names its own folder and the ones below. "
     "[docs/structure.md](docs/structure.md) is the stack; [docs/index.md](docs/index.md) has every script."),
    ("src/scenes/", "The visualizer scene catalog - one class per scene. See [docs/scenes.md](docs/scenes.md)."),
    ("src/media/", "The media - what the show is carried on. See [docs/media.md](docs/media.md)."),
    ("shaders/", "The GPU shaders: the Look, every Masking effect, the card table and a few scenes."),
    ("storyboards/",
     "Manual-mode scene scores (YAML; JSON accepted). [storyboards/README.md](storyboards/README.md) is the data "
     "spec."),
    ("data/",
     "Data the code reads - pronunciation (CMUdict, `english.yml`), the LibriTTS speaker table - each license beside "
     "its file."),
    ("fonts/", "Faces the media draw with: the notebook's handwriting and the card table's lettering."),
    ("hosts/",
     "The Python hosts ghost spawns, each in an environment of its own the Provisioner builds "
     "(`src/platform/deps.gd`): `voice/` the neural voice, `face/` Masking's face and body pre-passes, `capture/` the "
     "tablet's page capture. Kept out of the exported .pck."),
    ("scripts/",
     "Build and check scripts: `scripts/check.sh` runs every gate (`--gpu` adds the ones that need a real renderer), "
     "`scripts/build.sh` exports a target into `dist/`."),
    ("tests/",
     "The gates (`*_check.gd`) and probes (`*_probe.gd`), in folders that mirror `src/` (a gate lives with what it "
     "holds), and their runners and fixtures at the top; `scripts/check.sh` runs them all, and `--for` the ones a "
     "change can reach."),
    ("docs/", "Generated documentation. Regenerate with `python docs.py`; do not edit by hand."),
    ("next/",
     "Design notes and plans, one per subsystem: [notes.md](next/notes.md) is the notes refactor, step by step, and "
     "[roadmap.md](next/roadmap.md) is what comes next."),
    ("masks/", "Saved Masking sessions, one directory per source video (runtime, git-ignored)."),
    ("feedback/", "Feedback console output: `NNNN.json` + `NNNN.png` per report (runtime, git-ignored)."),
    ("dist/", "Build artifacts and the gates' logs (runtime, git-ignored)."),
    ("audio/", "Drop a `song.wav` here to bundle one (runtime, git-ignored); or use `--audio`."),
]

# Standalone pages, documented outside the registry pages: (title, repo-relative path, one
# line). One source for docs/index.md and the README's SUBSYSTEMS block.
SUBSYSTEMS: List[Tuple[str, str, str]] = [
    ("How the show is made", "docs/architecture.md",
     "from the audio to the screen or a video file: the signal path, composition, drawing, scheduling, rendering - and "
     "adding a scene."),
    ("The environment", "docs/environment.md",
     "what Ghost Notes installs itself, and the few programs that stay the machine's."),
    ("The structure", "docs/structure.md",
     "`src/` as a stack of folders: what each is, what it names, and what still points up."),
    ("CLI flags", "docs/cli.md", "every command-line flag."),
    ("Storyboards", "storyboards/README.md", "the data spec a note's storyboard is written in."),
]

CAPABILITY_WHERE = {"desktop": "the desktop", "checkout": "a checkout of the repository"}
MACHINES = {
    "linux-x86_64": "Linux (x86-64)",
    "linux-arm64": "Linux (ARM)",
    "macos-arm64": "Apple silicon Macs",
    "macos-x86_64": "Intel Macs",
    "windows-x86_64": "Windows (x86-64)",
    "windows-arm64": "Windows on ARM",
}
PLATFORMS = {"linux": "Linux", "macos": "macOS", "windows": "Windows"}

AUTOGEN_HEADER = "<!-- AUTOGENERATED by docs.py - do not edit by hand -->"


# ---------------------------------------------------------------------------
# Reading GDScript: a script's header and inner classes, and any constant as data
# ---------------------------------------------------------------------------


class Expr(str):
    """What a constant holds that is not a literal - a bare name (an inner class, another constant),
    a call (`Vector3(1, 0, 0)`, `preload(...)`), arithmetic - as its source text: a string that knows
    it is not one."""


_TOKEN = re.compile(
    r"(?P<space>[ \t\r]+|\\\n)|(?P<newline>\n)|(?P<comment>#[^\n]*)"
    r'|(?P<str>[&^]?r?(?:"""(?:[^\\]|\\.)*?"""|"(?:[^"\\\n]|\\.)*"|\'(?:[^\'\\\n]|\\.)*\'))'
    r"|(?P<num>0x[\da-fA-F_]+|0b[01_]+|(?:\d[\d_]*(?:\.[\d_]*)?|\.\d[\d_]*)(?:[eE][+-]?\d+)?)"
    r"|(?P<name>[A-Za-z_]\w*)"
    r"|(?P<op>\*\*|<<|>>|[<>=!]=|&&|\|\||->|:=|[-+*/%<>=!&|^~.,:;()\[\]{}@$])"
)
_BINARY = {"+", "-", "*", "/", "%", "**", "<<", ">>", "<", ">", "<=", ">=", "==", "!=", "&", "|", "^",
           "&&", "||", "and", "or", "in", "is", "as", "if", "else"}
_CLOSE = {"(": ")", "[": "]"}


class _Literal:
    """Reads one GDScript expression, from [pos] to where it ends, as Python data (see `const`). A
    line's end outside brackets ends it, as it ends a statement."""

    def __init__(self, text: str, pos: int) -> None:
        self.text, self.pos, self.depth = text, pos, 0
        self.advance()

    def advance(self) -> None:
        """Steps past the current token. `end` is where the last one taken ended; `broke`, that a
        line ended before the next, outside brackets."""
        self.end, self.broke = self.pos, False
        while True:
            m = _TOKEN.match(self.text, self.pos)
            if m is None:
                if self.pos < len(self.text):
                    raise ValueError(f"unexpected {self.text[self.pos:self.pos + 20]!r}")
                self.kind, self.tok, self.at = "end", "", self.pos
                return
            self.pos = m.end()
            if m.lastgroup == "newline":
                self.broke = self.broke or self.depth == 0
            elif m.lastgroup not in ("space", "comment"):
                self.kind, self.tok, self.at = m.lastgroup, m.group(), m.start()
                return

    def is_(self, op: str) -> bool:
        return self.kind == "op" and self.tok == op

    def expr(self) -> Any:
        start, parts, ops = self.at, [self.unary()], []
        while self.kind in ("op", "name") and self.tok in _BINARY and not self.broke:
            ops.append(self.tok)
            self.advance()
            parts.append(self.unary())
        if not ops:
            return parts[0]
        if set(ops) == {"+"} and all(type(p) is str for p in parts):
            return "".join(parts)
        return Expr(self.text[start:self.end])

    def unary(self) -> Any:
        start = self.at
        if self.kind in ("op", "name") and self.tok in ("-", "+", "!", "~", "not"):
            sign = self.tok
            self.advance()
            v = self.unary()
            if type(v) in (int, float) and sign in ("-", "+"):
                return -v if sign == "-" else v
            return Expr(self.text[start:self.end])
        start, v = self.at, self.primary()
        while self.kind == "op" and self.tok in ("(", "[", ".") and not self.broke:
            if self.tok == ".":
                self.advance()
                self.advance()
            else:
                self.items(_CLOSE[self.tok])
            v = Expr(self.text[start:self.end])
        return v

    def primary(self) -> Any:
        kind, tok, start = self.kind, self.tok, self.at
        if self.is_("["):
            return self.items("]")
        if self.is_("{"):
            return self.mapping()
        if self.is_("("):
            inner = self.items(")")
            return inner[0] if len(inner) == 1 else Expr(self.text[start:self.end])
        if kind not in ("str", "num", "name"):
            raise ValueError(f"unexpected {tok!r}")
        self.advance()
        if kind == "str":
            return ast.literal_eval(tok.lstrip("&^"))
        if kind == "num":
            t = tok.replace("_", "")
            return int(t, 0) if t[:2] in ("0x", "0b") else float(t) if re.search(r"[.eE]", t) else int(t)
        return {"true": True, "false": False, "null": None}.get(tok, Expr(tok))

    def items(self, close: str) -> List[Any]:
        out = []
        self.depth += 1
        self.advance()
        while not self.is_(close):
            out.append(self.expr())
            if self.is_(","):
                self.advance()
            elif not self.is_(close):
                raise ValueError(f"expected {close!r}, found {self.tok!r}")
        self.depth -= 1
        self.advance()
        return out

    def mapping(self) -> Dict[Any, Any]:
        out: Dict[Any, Any] = {}
        self.depth += 1
        self.advance()
        while not self.is_("}"):
            key = self.expr()
            if self.is_("="):  # Lua style, {name = value}
                key = str(key)
            elif not self.is_(":"):
                raise ValueError(f"expected ':', found {self.tok!r}")
            self.advance()
            out[key] = self.expr()
            if self.is_(","):
                self.advance()
            elif not self.is_("}"):
                raise ValueError(f"expected '}}', found {self.tok!r}")
        self.depth -= 1
        self.advance()
        return out


def _const_at(text: str, name: str) -> Optional[Tuple[Any, str]]:
    m = re.search(rf"^const {name}\b[^=\n]*=\s*", text, re.M)
    if not m:
        return None
    try:
        r = _Literal(text, m.end())
        return r.expr(), text[m.end():r.end]
    except ValueError as e:
        raise SystemExit(f"[ghost-docs] cannot read const {name}: {e}")


def const(text: str, name: str, default: Any = None) -> Any:
    """`const NAME := <value>` at the top level of [text], read as Python data: dictionaries in their
    order, arrays, strings (`&"name"` and `"a" + "b"` among them), numbers, true / false / null, and
    anything else as an `Expr`. [default] when [text] declares no such constant. The one shape ghost's
    registries share is ROWS (next/structure.md, step 6): `{"key": {"label": ..., "blurb": ...}}`."""
    found = _const_at(text, name)
    return default if found is None else found[0]


def const_source(text: str, name: str) -> str:
    """The constant's value as written, comments and all - for the two tables whose comments are
    data (the roster's group headings, the Masking effects' notes)."""
    found = _const_at(text, name)
    return "" if found is None else found[1]


def text(row: Dict[str, Any], key: str, default: str = "") -> str:
    """A row's field as text: a string, or a name as written; else [default]."""
    v = row.get(key)
    return v if isinstance(v, str) else default


def items(row: Dict[str, Any], key: str) -> List[Any]:
    v = row.get(key)
    return v if isinstance(v, list) else []


def pairs(row: Dict[str, Any], key: str) -> Dict[str, Any]:
    v = row.get(key)
    return v if isinstance(v, dict) else {}


_STRING = r'"(?:[^"\\\n]|\\.)*"|\'(?:[^\'\\\n]|\\.)*\''


def code_of(text: str, mark: str = "#", strings: bool = True) -> str:
    """[text] with its comments taken out - a [mark] outside a string literal, to the line's end - and
    without [strings], its string literals too, so a name in a tooltip is not a reference."""
    return re.sub(f"({_STRING})|{re.escape(mark)}[^\n]*",
                  lambda m: m.group(1) if m.group(1) and strings else "", text)


class Class(NamedTuple):
    doc: str  # the comment block directly over `class Name`, as markdown
    line: int  # 1-based
    body: str  # the lines after it that are indented or blank, one tab of indent taken off


class Script:
    """A GDScript file, read once: its header (`class_name`, `extends`, the leading `##` doc), its
    inner classes, and any of its constants as data."""

    def __init__(self, path: Path) -> None:
        self.path = path
        self.name = path.stem
        self.text = path.read_text()
        self.class_name, self.extends, self.doc = _parse_header(self.text)

    @property
    def rel(self) -> str:
        return self.path.relative_to(ROOT).as_posix()

    def const(self, name: str, default: Any = None) -> Any:
        return const(self.text, name, default)

    @cached_property
    def classes(self) -> Dict[str, Class]:
        out: Dict[str, Class] = {}
        lines = self.text.split("\n")
        for i, line in enumerate(lines):
            m = re.match(r"class (\w+)", line)
            if not m:
                continue
            doc: List[str] = []
            j = i - 1
            while j >= 0 and lines[j].strip().startswith("#"):
                said = lines[j].strip().lstrip("#").strip()
                if not re.fullmatch(r"-{3,}", said):  # a ruler is decoration
                    doc.insert(0, said)
                j -= 1
            body, quoted = [], False  # a line of a multi-line string may start at the margin
            for line_ in lines[i + 1:]:
                if not quoted and line_.strip() and not line_.startswith(("\t", " ")):
                    break
                body.append(line_[1:] if line_.startswith("\t") else line_)
                quoted ^= line_.count('"""') % 2 == 1
            out[m.group(1)] = Class("\n\n".join(md(p) for p in paragraphs(doc)), i + 1, "\n".join(body))
        return out


_SCRIPTS: Dict[Path, Script] = {}


def script_at(path: Path) -> Script:
    if path not in _SCRIPTS:
        _SCRIPTS[path] = Script(path)
    return _SCRIPTS[path]


def folder_scripts(folder: str) -> List[Script]:
    return [script_at(p) for p in sorted((SCRIPTS / folder).glob("*.gd"))]


def autoloads() -> Dict[str, str]:
    """project.godot's autoloads: name -> its script's path from the root."""
    project = (ROOT / "project.godot").read_text()
    return dict(re.findall(r'^(\w+)="\*?res://([^"]+\.gd)"', project, re.M))


def class_index() -> Dict[str, Script]:
    """Every script under src/ by the name the code calls it: its class_name, or its autoload
    name in project.godot (Spectrum and Director have no class_name)."""
    scripts = [script_at(p) for p in sorted(SCRIPTS.rglob("*.gd"))]
    out = {s.class_name: s for s in scripts if s.class_name}
    for name, rel in autoloads().items():
        if (ROOT / rel).exists():
            out.setdefault(name, script_at(ROOT / rel))
    return out


def _parse_header(text: str) -> Tuple[Optional[str], Optional[str], List[str]]:
    """Extract `class_name`, `extends`, and the leading `##` doc block.

    The doc block is the first contiguous run of `##` lines before the first
    declaration (func/var/const/class/signal/enum). Returned with the `##`
    prefix stripped; blank doc lines preserved as paragraph breaks."""
    class_name = None
    extends = None
    doc: List[str] = []
    in_doc = False
    for line in text.splitlines():
        s = line.strip()
        if s.startswith("##"):
            doc.append(s[2:].lstrip())
            in_doc = True
            continue
        if in_doc:
            break
        if s.startswith("extends ") and extends is None:
            extends = s.split()[1]
        elif s.startswith("class_name "):
            class_name = s.split()[1]
        elif s.startswith(("func ", "var ", "const ", "class ", "signal ", "enum ")):
            break
    return class_name, extends, doc


def md(text: str) -> str:
    """GDScript doc markup -> markdown: `[param x]` -> `x`, `[Class]` -> `Class`.

    The tag list is not decoration: `[constant X]` was leaking into docs/scenes.md
    verbatim, eighteen times, because only `[param ]` was handled."""
    text = re.sub(r"\[code\](.*?)\[/code\]", r"`\1`", text, flags=re.S)
    text = re.sub(r"\[(?:param|constant|method|member|signal|enum|annotation) ([\w.]+)\]", r"`\1`", text)
    return re.sub(r"\[([A-Z]\w*(?:\.\w+)*)\]", r"`\1`", text)


def paragraphs(doc: List[str]) -> List[str]:
    out: List[str] = []
    cur: List[str] = []
    for line in doc + [""]:
        if line:
            cur.append(line)
        elif cur:
            out.append(" ".join(cur))
            cur = []
    return out


def one_liner(doc: List[str], strip_name: str = "") -> str:
    """First doc paragraph as a single line, optional `Name -` prefix stripped."""
    paras = paragraphs(doc)
    if not paras:
        return ""
    line = paras[0]
    if strip_name:
        line = re.sub(rf"^{re.escape(strip_name)}\s+-\s+", "", line, flags=re.IGNORECASE)
    if len(line) > 300:
        line = line[:300].rsplit(" ", 1)[0] + " ..."
    return md(line)


def full_doc(doc: List[str]) -> str:
    return "\n\n".join(md(p) for p in paragraphs(doc))


def _first(text: str, pattern: str) -> Optional[str]:
    m = re.search(pattern, text)
    return m.group(1) if m else None


# ---------------------------------------------------------------------------
# The page kit: a page is a list of blocks
# ---------------------------------------------------------------------------

Block = Union[str, List[str]]


def page(title: str, blocks: Iterable[Block]) -> str:
    """A generated page: its header and title, then each block - a paragraph, or a list of lines (a
    table, a list) - with a blank line between."""
    parts = [f"{AUTOGEN_HEADER}\n# {title}"] + [b if isinstance(b, str) else "\n".join(b) for b in blocks]
    return "\n\n".join(parts).rstrip() + "\n"


def entry(head: str, lead: Optional[str], doc: Optional[str], *body: Optional[Block], level: int = 2,
          missing: str = "") -> List[Block]:
    """One entry of a registry: its heading, a lead line, its doc - or, when [missing] says what to
    warn, a warning that it has none - then the rest, each block left out when empty."""
    if not doc and missing:
        warn(missing)
    return ["#" * level + " " + head] + [b for b in (lead, doc, *body) if b]


def table(head: Union[Sequence[str], str], rows: Iterable[Sequence[Any]], rule: str = "") -> List[str]:
    """A markdown table, a `|` in a cell escaped. [head] is the heading's cells, or its line as written;
    [rule] the line under it, when not `| --- |` under each heading."""

    def line(cells: Iterable[str]) -> str:
        return "| " + " | ".join(cells) + " |"

    heading = head if isinstance(head, str) else line(head)
    return [heading, rule or line("---" for _ in range(heading.count("|") - 1))] + [
        line(str(c).replace("|", "\\|") for c in row) for row in rows
    ]


def link(rel: str, line: Optional[int] = None) -> str:
    """Markdown source link from docs/ to a repo file (with #L anchor)."""
    return f"[{rel}:{line}](../{rel}#L{line})" if line else f"[{rel}](../{rel})"


def field_table(fields: Dict[str, Dict[str, Any]]) -> Optional[List[str]]:
    """A class's FIELDS as a table: the setting, its default (unset: drawn or worked out, as it
    says), and what it does."""

    def shown(d: Any) -> str:
        return "unset" if d is None else "on" if d is True else "off" if d is False else f"`{d}`"

    if not fields:
        return None
    return table(["Setting", "Default", "What it does"],
                 ([f"`{k}` {r.get('label', '')}", shown(r.get("default")), md(str(r.get("blurb", "")))]
                  for k, r in fields.items()))


def schema_table(fields: Dict[str, Dict[str, Any]]) -> List[str]:
    """A table of fields an editor builds its rows from: the key, what the editor calls it, its type
    (and options), and its sentence."""

    def kind(r: Dict[str, Any]) -> str:
        opts = [o for o in items(r, "options") if o]
        return text(r, "type") + (": " + ", ".join(f"`{o}`" for o in opts) if opts else "")

    return table(["Key", "In the editor", "Type", "What it is"],
                 ([f"`{k}`", text(r, "label"), kind(r), md(text(r, "blurb"))] for k, r in fields.items()))


# ---------------------------------------------------------------------------
# Scene catalog
# ---------------------------------------------------------------------------

SCENE_BASES = {"GhostScene", "Scene3D"}


class Scene:
    def __init__(self, script: Script) -> None:
        t = script.text
        self.script = script
        self.behaviors: List[str] = []
        self.group = ""
        kind = re.search(r'render_kind\s*=\s*"(\w+)"', t)
        self.render_kind = kind.group(1) if kind else ("scene3d" if script.extends == "Scene3D" else "canvas")
        self.oneshot = 'lifecycle = "oneshot"' in t
        self.morph_in = _first(t, r'morph_in\s*=\s*"(\w+)"')
        self.morph_out = _first(t, r'morph_out\s*=\s*"(\w+)"')
        self.layers = sorted(set(re.findall(r'add_layer\(\s*"(\w+)"', t)))


def collect_scenes() -> Tuple[Dict[str, Scene], List[str]]:
    """All scenes on disk, annotated with their Director registration: (name -> Scene, the roster's
    group headings in order). A scene is a script that extends a scene base; the roster beside them
    is a registry, not one. Its groups are the comments over its entries."""
    scenes = {p.stem: Scene(s) for p in sorted(SCENES_DIR.glob("*.gd"))
              for s in [script_at(p)] if s.extends in SCENE_BASES}
    roster = const_source((SCENES_DIR / "roster.gd").read_text(), "SCENES")
    if not roster:
        warn("could not parse SceneRoster.SCENES")
    groups: List[str] = []
    group = ""
    for line in roster.splitlines():
        s = line.strip()
        if s.startswith("#"):
            group = s.lstrip("# ").strip()
            continue
        m = re.search(r'scenes/(\w+)\.gd"\).*?"behavior":\s*"(\w+)"', s)
        if not m:
            continue
        name, behavior = m.groups()
        if name not in scenes:
            warn(f"SceneRoster.SCENES registers scenes/{name}.gd which does not exist")
            continue
        scenes[name].behaviors.append(behavior)
        scenes[name].group = group
        if group not in groups:
            groups.append(group)
    return scenes, groups


def _split_group(group: str) -> Tuple[str, str]:
    """A roster group comment -> (short section header, optional intro line).
    The comment's lead (before ' - ' or a parenthetical) is the header; the
    full comment becomes the intro when it says more than the header."""
    if not group:
        return "Core catalog", ""
    head = re.split(r" - |\(", group, maxsplit=1)[0]
    head = head.replace('"', "").strip().rstrip(".")
    head = head[0].upper() + head[1:]
    return head, md(group) if group.rstrip(".") != head else ""


def options(text_: str, name: str) -> List[Any]:
    """A scene's table [name] as the options an entry may tell it: a dictionary's string keys, or an
    array's plain items (a string or a number), in order."""
    v = const(text_, name, [])
    if isinstance(v, dict):
        return [k for k in v if type(k) is str]
    return [o for o in v if type(o) in (str, int, float)] if isinstance(v, list) else []


def scene_entry(name: str, info: Scene) -> List[Block]:
    s = info.script
    flags = ", ".join([info.render_kind] + sorted(set(info.behaviors)) + (["oneshot seeds"] if info.oneshot else []))
    facts = ([f"morph in: `{info.morph_in}`"] if info.morph_in else []) + (
        [f"morph out: `{info.morph_out}`"] if info.morph_out else []) + (
        ["layers: " + ", ".join(f"`{k}`" for k in info.layers)] if info.layers else [])
    told: List[Block] = []
    fields = const(s.text, "FIELDS", {})
    if fields:
        # WHAT AN ENTRY CAN TELL IT (GhostScene.choice, number): its settings, each the seed's until told
        rows = []
        for k, row in fields.items():
            if row.get("type") == "num":
                lo, hi = (row.get("range") or [None, None])[:2]
                said = f"`{lo}` to `{hi}`"
            else:
                names = options(s.text, str(row.get("names", ""))) if row.get("names") else []
                shown: List[str] = []
                for o in options(s.text, str(row.get("options", ""))):
                    o = str(names[o]) if names and type(o) is int and o < len(names) else str(o)
                    if o not in shown:
                        shown.append(o)
                said = ", ".join(f"`{o}`" for o in shown)
            rows.append([f"`{k}` {row.get('label', '')}", said, md(str(row.get("blurb", "")))])
        told = ["An entry can tell it, under `set` (unset, the seed draws one; a number may be told as a "
                "narrower range, `[lo, hi]`):", table(["Setting", "Options", "What it sets"], rows)]
    return entry(f"`{name}` ({flags})", None, full_doc(s.doc), " · ".join(facts), *told,
                 f"Source: {link(s.rel)} (extends `{s.extends}`)", level=3,
                 missing=f"scenes/{name}.gd has no doc comment")


def scenes_page(scenes: Dict[str, Scene], groups: List[str]) -> str:
    blocks: List[Block] = [
        f"{len(scenes)} scenes under `src/scenes/`, one class per file, "
        "each documented by its own leading doc comment (reproduced here). "
        "A scene is a seeded **definition** (`build_params(rng)`) modulated "
        "by audio (`update`) and drawn through a view; registration in "
        "`SceneRoster.SCENES` pairs it with one or more **behaviors** "
        "(`static` / `drift` / `fluid`).",
        "Legend per entry: render kind, registered behaviors, lifecycle. "
        "`morph in/out` are the typed geometries a scene can continuously "
        "hand over across a cut; `layers` are the [Layer](layers.md) "
        "components it composes.",
    ]
    for group in groups:
        names = [n for n in sorted(scenes) if scenes[n].behaviors and scenes[n].group == group]
        if names:
            header, intro = _split_group(group)
            blocks += [f"## {header}"] + ([intro] if intro else [])
            blocks += [b for n in names for b in scene_entry(n, scenes[n])]
    unregistered = [n for n in sorted(scenes) if not scenes[n].behaviors]
    if unregistered:
        blocks += ["## On disk but not in the auto rotation",
                   "Present under `src/scenes/` but not registered in "
                   "`SceneRoster.SCENES` - reachable only by storyboard (`stage`), "
                   "`--scene` pin, or not reachable at all. If one of these "
                   "should be in the rotation, register it; if it is retired, "
                   "delete it."]
        blocks += [b for n in unregistered for b in scene_entry(n, scenes[n])]
    return page("Scene catalog", blocks)


# ---------------------------------------------------------------------------
# Registry pages
# ---------------------------------------------------------------------------


def registry_page(title: str, intro: str, script: Script) -> str:
    """A registry whose values are INNER CLASSES of its script (Layer, Primitives): each class's doc
    and its `FIELDS`, and the base's `COMMON` - what every entry takes."""
    reg = script.const("REGISTRY", {})
    classes = script.classes
    common = next((c for c in (const(k.body, "COMMON", {}) for k in classes.values()) if c), {})
    blocks: List[Block] = [intro, full_doc(script.doc),
                           f"Registry: `{script.class_name}.REGISTRY` in {link(script.rel)} ({len(reg)} entries)"]
    if common:
        blocks += ["Every entry also takes:", field_table(common)]
    for key, cls in reg.items():
        c = classes.get(cls, Class("", 0, ""))
        blocks += entry(f"`{key}` - {cls}", None, c.doc, field_table(const(c.body, "FIELDS", {})),
                        f"Source: {link(script.rel, c.line)}",
                        missing=f"{script.rel}: class {cls} (registry key '{key}') has no doc comment")
    return page(title, blocks)


def media_page(base: Script) -> str:
    """docs/media.md, from Medium.REGISTRY and each medium script's own header. A medium is a whole
    file, because it owns render targets and a draw: a row names its script by path, so a medium a
    feature brings lives with the feature (the card table, in `table/`)."""
    rows = base.const("REGISTRY", {})
    if not rows:
        warn("could not parse Medium.REGISTRY")
    blocks: List[Block] = [
        "The presentation axis - what the show is drawn ON, as opposed to what "
        "drives it. Independent of the modes, so every mode gets every medium.",
        full_doc(base.doc),
        f"Registry: `Medium.REGISTRY` in {link(base.rel)} "
        f"({len(rows)} entries). Select with `--medium NAME`, or the Medium "
        "picker in the Generative panel (persisted to `user://ghost.cfg`, "
        "`[director] medium`).",
    ]
    registered = []
    for key, row in rows.items():
        rel = text(row, "script").replace("res://", "", 1)
        registered.append(rel)
        if not (ROOT / rel).exists():
            warn(f"Medium.REGISTRY registers {rel} which does not exist")
            continue
        sc = script_at(ROOT / rel)
        blurb = text(row, "blurb")
        blocks += entry(f"`{key}` - {text(row, 'label', key)}", blurb and f"_{blurb}_", full_doc(sc.doc),
                        f"Source: {link(sc.rel)}", missing=f"{sc.rel}: medium '{key}' has no doc comment")
    # The folder also holds what the media set and show (layouts, films, pictures): only a
    # script that IS a medium - one extending Medium or a registered medium - must be a row.
    kinds = {"Medium"} | {script_at(ROOT / rel).class_name for rel in registered if (ROOT / rel).exists()}
    for path in sorted(SCRIPTS.glob("*/*.gd")):
        rel = path.relative_to(ROOT).as_posix()
        if rel not in registered and path.stem != "medium" and path.parent != SCENES_DIR \
                and script_at(path).extends in kinds:
            warn(f"{rel} is a medium not registered in Medium.REGISTRY - it can never be selected")
    return page("Media: what carries the show", blocks)


def filters_page(base: Script) -> str:
    """docs/filters.md, from Filters.REGISTRY and the shader's own header. A filter is a uniform and
    a block of GLSL, so it also CHECKS the pair, which is this table's own failure mode: a registry
    key whose uniform the shader does not declare ships as a control that does nothing, because
    `set_shader_parameter` on an unknown name is silent (tests/show/stage_filter_check.gd asserts
    the same at runtime; this is so a docs run says it too)."""
    rows = base.const("REGISTRY", {})
    if not rows:
        warn("could not parse Filters.REGISTRY")
    shader = ROOT / "shaders" / "stage_filter.gdshader"
    src = shader.read_text() if shader.exists() else ""
    if not src:
        warn("shaders/stage_filter.gdshader is missing - the filters cannot render")
    uniform = {k: text(r, "uniform") for k, r in rows.items()}
    default = {k: r.get("default", "?") for k, r in rows.items()}
    blocks: List[Block] = [
        "A post-process applied to the finished frame, after every scene has drawn "
        "and under everything on a CanvasLayer - so the show is filtered and the "
        "subtitles and panels are not. Filters COMBINE: each has its own 0..1 dial "
        "and they are all applied, in one pass, in the order below.",
        full_doc(base.doc),
        f"Registry: `Filters.REGISTRY` in {link(base.rel)} "
        f"({len(rows)} entries), rendered by "
        f"{link('shaders/stage_filter.gdshader')}. Select with "
        "`--filter key=amount,...` (or `--filter none`), or the Look rows in the "
        "Generative panel (persisted to `user://ghost.cfg`, `[director] filters`).",
        table(["#", "Key", "Name", "Uniform", "Default"],
              ([i, f"`{k}`", text(r, "label", k), f"`{uniform[k]}`", default[k]]
               for i, (k, r) in enumerate(rows.items(), start=1)),
              rule="| - | --- | ---- | ------- | ------- |"),
    ]
    for key, row in rows.items():
        if f"uniform float {uniform[key]}" not in src:
            warn(f"Filters.REGISTRY maps '{key}' to {uniform[key]}, which "
                 "shaders/stage_filter.gdshader does not declare - the control is a no-op")
        for field in ("label", "blurb", "default"):
            if field not in row:
                warn(f"Filters.REGISTRY's row '{key}' has no `{field}`")
        blocks += entry(f"`{key}` - {text(row, 'label', key)}", md(text(row, "blurb")), None,
                        f"Uniform `{uniform[key]}`, default {default[key]} when first switched on.")
    for m in re.finditer(r"uniform float (u_\w+)", src):
        if m.group(1) not in uniform.values():
            warn(f"shaders/stage_filter.gdshader declares {m.group(1)}, which no "
                 "Filters.REGISTRY entry drives - it can never be set")
    return page("Filters: the look over the whole picture", blocks)


def script_page(marks: Script) -> str:
    """docs/script.md, from ScriptMarks.REGISTRY + GROUPS: every authoring mark a script
    may carry, as the editor's palette offers them."""
    groups, rows = marks.const("GROUPS", {}), marks.const("REGISTRY", {})
    if not groups or not rows:
        warn("could not parse ScriptMarks.REGISTRY / GROUPS")
    for key, f in rows.items():
        for name in ("label", "group", "blurb"):
            if not isinstance(f.get(name), str):
                warn(f"ScriptMarks.REGISTRY['{key}'] has no {name}")
    blocks: List[Block] = [
        "Every mark a Generative or Synthesis script, or a Table brief, may carry - "
        "the list the script editor's palette (**Edit** on the panel) is built "
        "from, and the patterns it highlights with. A script is Markdown; "
        "YAML frontmatter at the top is the panel's and never shown in the "
        "editor or spoken. A Table brief is handed to the show's agents rather "
        "than read aloud, so a mark offered there says what it does in a brief.",
        full_doc(marks.doc),
        f"Registry: `ScriptMarks.REGISTRY` in {link(marks.rel)} "
        f"({len(rows)} entries). Each one is proven against the parser that "
        "reads it by `tests/notes/script_marks_check.gd`.",
    ]

    def does(f: Dict[str, Any]) -> str:  # what the mark does, and in a panel where that differs: {"table": "..."}
        return text(f, "blurb") + "".join(f" **In a {m.capitalize()} brief:** {t}" for m, t in pairs(f, "blurbs").items())

    for gkey, g in groups.items():
        mine = [f for f in rows.values() if text(f, "group") == gkey]
        if mine:
            blocks += [f"## {text(g, 'label')}", table(
                ["Mark", "Example", "Panels", "What it does"],
                ([text(f, "label"), f"`{(text(f, 'before') + text(f, 'fill') + text(f, 'after')).strip()}`",
                  ", ".join(m.capitalize() for m in items(f, "modes")), does(f)] for f in mine),
                rule="|---|---|---|---|")]
    for k, f in rows.items():
        if text(f, "group") not in groups:
            warn(f"ScriptMarks.REGISTRY['{k}'] names unknown group '{text(f, 'group')}'")
    return page("Writing a script", blocks)


def stage_page(cast: Script, actions: Script, track: Script, board: Script) -> str:
    blocks: List[Block] = [
        "The data-driven scene stack behind storyboard `stage` entries: a "
        "**Cast** of actors, **Actions** verbs applied to them on a "
        "**Track** timeline. The storyboard file format itself is specified "
        "in [storyboards/README.md](../storyboards/README.md).",
        "## Fields",
        "What a storyboard can say, read from the tables its editor builds its rows from "
        f"(`Storyboard.BOARD` and its siblings in {link(board.rel)}): a field in a "
        "table is a control in the editor. A `num` is a number or a sampled `[lo, hi]` "
        "range; a key left out is its default.",
    ]
    for title, name in (("The storyboard", "BOARD"), ("An entry", "ENTRY"), ("How long an entry stays", "TIMING_FIELDS"),
                        ("A stage entry", "STAGE"), ("Its camera", "CAMERA"), ("An actor", "ACTOR"), ("A span", "SPAN")):
        fields = board.const(name, {})
        if not fields:
            warn(f"could not parse Storyboard.{name}")
        blocks += [f"### {title}", schema_table(fields)]
    params, args = cast.const("PARAMS", {}), actions.const("ARGS", {})
    if not params or not args:
        warn("could not parse Cast.PARAMS or Actions.ARGS")
    for s, title, what, verbs, classes in (
        (cast, "Cast (actor registry)", "kinds", params, {k: f"{k.capitalize()}Actor" for k in cast.const("REGISTRY", {})}),
        (actions, "Actions (verb registry)", "verbs", args, actions.const("REGISTRY", {})),
    ):
        blocks += [f"## {title}", full_doc(s.doc),
                   f"Registry: `{s.class_name}.REGISTRY` in {link(s.rel)} ({len(classes)} {what})"]
        for key, cls in classes.items():
            c = s.classes.get(cls, Class("", 0, ""))
            blocks += entry(f"`{key}` - {cls}", None, c.doc, verbs.get(key) and schema_table(verbs[key]),
                            f"Source: {link(s.rel, c.line)}", level=3)
    blocks += ["## Track (the timeline runner)", full_doc(track.doc), f"Source: {link(track.rel)}"]
    return page("Stage: actors and verbs", blocks)


def masking_page(session: Script, editor: Script) -> str:
    """docs/masking.md: the session's model, the editor, and the effects - each effect's control
    groups from `EFFECT_CONTROLS`, and its note from that table's comments."""
    effects = session.const("MASK_EFFECTS", [])
    controls = session.const("EFFECT_CONTROLS", {})
    notes = {int(i): n.strip() for i, n in
             re.findall(r"^\s*(\d+):.*?#\s*(.*)$", const_source(session.text, "EFFECT_CONTROLS"), re.M)}
    rows = []
    for i, name in enumerate(effects):
        note = re.sub(rf"^{re.escape(name)}\s*", "", notes.get(i, "")).lstrip("(").rstrip(")")
        rows.append([i, f"`{name}`", ", ".join(f"`{g}`" for g in controls.get(i, [])) or "-", note])
    return page("Masking", [
        "The video chroma-key masking editor - a second app surface inside "
        "ghost, separate from the audio visualizer. Open it on a session (or "
        "straight on a video file) with:",
        ["```", "godot --path . -- --mask-edit masks/<video>/session.json", "```"],
        "## The data model", full_doc(session.doc), f"Source: {link(session.rel)}",
        "## The editor", full_doc(editor.doc), f"Source: {link(editor.rel)}",
        "## Effects",
        f"{len(effects)} effects (`MaskSession.MASK_EFFECTS`). The actual "
        "implementations live in "
        "[shaders/mask_split.gdshader](../shaders/mask_split.gdshader) - "
        "each marker becomes a shader layer, and `apply_layer()` dispatches "
        "per effect. Control groups: `keying` (threshold / feather / "
        "colorfulness steer the volumetric mask), `reach` (how wide around "
        "the key color a restore acts), `pattern` (field placement / "
        "coverage / contrast / resonance), plus per-effect groups (`echo`, "
        "`snow`, `fur`). An effect with no groups exposes only the universal "
        "color + intensity controls.",
        table(["#", "Effect", "Control groups", "Notes"], rows),
        "## Headless marker insertion",
        "`src/masking/mask_marker_tool.gd` inserts one marker into a saved "
        "session from the command line (no editor boot): ",
        ["```", "godot --headless --path . --script src/masking/mask_marker_tool.gd \\",
         "    -- masks/<video>/session.json <time> [field=value ...]", "```"],
        "The marker seeds from whatever was governing at `<time>`; each "
        "`field=value` then overrides one session field (e.g. "
        "`effect_a=14 fx_contrast=0.6 duration=0.5`). Note: a live "
        "editor autosaving the same session will clobber markers "
        "inserted this way - reload the session first.",
    ])


def components_page(comp: Script, caps: Script) -> str:
    """docs/components.md, from Components.FAMILIES / SLOTS / WORKSPACES / REGISTRY and
    Capabilities.TABLE: what a note can carry, the room each part takes, which panel runs
    a note, and what each part asks of the platform."""
    families, entries = comp.const("FAMILIES", {}), comp.const("REGISTRY", {})
    slots, workspaces, asks = comp.const("SLOTS", {}), comp.const("WORKSPACES", {}), caps.const("TABLE", {})
    if not (families and entries and slots and workspaces and asks):
        warn("could not parse Components.FAMILIES / SLOTS / WORKSPACES / REGISTRY or Capabilities.TABLE")
    label = {k: text(e, "label") for k, e in entries.items()}

    def component(key: str, e: Dict[str, Any]) -> List[str]:
        facts = []
        for field, word in (("needs", "needs"), ("provides", "gives"), ("requires", "brings"),
                            ("comes_with", "comes with")):
            vals = [label.get(v, v) if field in ("requires", "comes_with") else v for v in items(e, field)]
            if vals:
                facts.append(f"{word} {', '.join(vals)}")
        if items(e, "slots"):
            facts.append("takes the " + " and the ".join(items(e, "slots")))
        if items(e, "capabilities"):
            facts.append("asks for " + ", ".join(f"`{c}`" for c in items(e, "capabilities")))
        if text(e, "block"):
            facts.append(f"kept in `{text(e, 'block')}:`")
        return [f"- **{label[key]}** (`{key}`) - {md(text(e, 'blurb'))}"] + ([f"  - {'; '.join(facts)}"] if facts else [])

    blocks: List[Block] = [
        "What a note can carry. A note is a markdown file, and each block under `ghost:` in "
        "its frontmatter is a component attached to it. **New** in the notes list makes a "
        "note with nothing attached, **+** attaches a component and the × on its card takes "
        "it off again, and what a note does is read off what it has attached.",
        full_doc(comp.doc),
        f"Registry: `Components.REGISTRY` in {link(comp.rel)} "
        f"({len(entries)} components, {len(slots)} slots, {len(workspaces)} workspaces).",
        "## Slots",
        "Where a note has room for exactly one. Components that take the same slot are "
        "alternatives: **+** grays the second, and says which to detach.",
        table(["Slot", "What it is", "Taken by"],
              ([f"`{k}`", md(text(s, "blurb")), ", ".join(label[c] for c, e in entries.items() if k in items(e, "slots"))]
               for k, s in slots.items())),
        "## Workspaces",
        "The panels that run a note. Most components are a card on whichever panel is "
        "up; a few are an editor of their own and name the workspace that is. Where two "
        "attached components name one, a component another brings gives way to the one "
        "that brings it.",
        table(["Workspace", "Named by", "What it is"],
              ([f"**{text(w, 'label')}** (`{k}`)",
                ", ".join(label[c] for c, e in entries.items() if text(e, "workspace") == k) or "no component: the default",
                md(text(w, "blurb"))] for k, w in workspaces.items())),
        "## Components",
        "By family - the color a component's card, chip and marks are drawn in.",
    ]
    for fam, f in families.items():
        mine = [line for k, e in entries.items() if text(e, "family") == fam for line in component(k, e)]
        if mine:
            blocks += [f"### {text(f, 'label')}", mine]
    for k, e in entries.items():
        if text(e, "family") not in families:
            warn(f"Components.REGISTRY['{k}'] names a family FAMILIES does not have")
    blocks += [
        "## Capabilities",
        "What a component may ask of the platform. Each is possible somewhere or not at "
        "all, and **+** leaves out what is impossible here and grays what is not ready "
        "yet, with the reason; the same table is checked wherever a program is started. "
        "On a phone, a note is its text and nothing else.",
        table(["Capability", "What it is", "Possible on"],
              ([f"`{k}`", text(c, "label"), CAPABILITY_WHERE.get(text(c, "where"), text(c, "where"))]
               for k, c in asks.items())),
        f"Source: `Capabilities.TABLE` in {link(caps.rel)}",
    ]
    return page("Components", blocks)


def install_lines(row: Dict[str, Any]) -> List[str]:
    return [f"  - {PLATFORMS.get(p, p)}: `{hint}`" for p, hint in pairs(row, "install").items()]


def environment_page(deps: Script) -> str:
    """docs/environment.md, from Deps.FETCHED / MANAGED / TOOLS - the rows the Environment panel
    and `--deps` render: what each is for, its size, the machines it cannot be built on and why,
    and the install hints for what stays the machine's."""
    tables = {t: deps.const(t, []) for t in ("FETCHED", "MANAGED", "TOOLS")}
    for t, rows in tables.items():
        if not rows:
            warn(f"could not parse Deps.{t}")

    def rows_of(*names: str) -> List[str]:
        out = []
        for row in (r for t in names for r in tables[t]):
            name, used = text(row, "name"), text(row, "used_for")
            if not name or not used:
                warn(f"a Deps row has no name or used_for: {str(row)[:60]}")
            tags = [text(row, "size"), ", ".join(PLATFORMS.get(p, p) for p in items(row, "platforms"))]
            out.append(f"- {', '.join([f'**{name}**'] + [t for t in tags if t])} - {md(used)}")
            out += [f"  - Not on {MACHINES.get(m, m)}: {why}." for m, why in pairs(row, "unsupported").items()]
            out += install_lines(row)
        return out

    return page("The environment", [
        "Godot 4.7 is the only thing to install. Everything else Ghost Notes runs, it installs "
        "and keeps current itself, under its own data directory - never system-wide, and never "
        "into your own environments. uv, FFmpeg and Python download in the background the "
        "first time it opens; a feature's environment is built the first time that feature is "
        "used. While anything installs, a notice at the top of the screen says what and how far "
        "along, and the Environment panel (the ⚙ in the bottom-right row) lists every piece with "
        "its version, what it is for and, if it failed, why. With **keep up to date** ticked "
        "there, Ghost Notes looks for newer releases once a day.",
        "The same report, and an install, from a terminal:",
        ["```",
         "godot --headless --path . -- --deps             # what is installed, and where",
         "godot --headless --path . -- --provision        # install uv, FFmpeg and Python now",
         "godot --headless --path . -- --provision all    # ...and every feature's environment",
         "godot --headless --path . -- --provision update # bring everything up to date",
         "godot --headless --path . -- --provision mathlib # Lean and Mathlib, for the Proof component (~8 GB)",
         "```"],
        "## What Ghost Notes installs itself",
        rows_of("FETCHED", "MANAGED"),
        "## What stays the machine's",
        "A few programs are part of the system or keep their own logins, so they stay yours "
        "to install; the Environment panel shows the command for each.",
        rows_of("TOOLS"),
        "## Platforms",
        "Linux, macOS and Windows are all meant to work, and nothing needs a Unix shell: "
        "background programs are started directly, and where output has to be redirected "
        "Ghost Notes does it itself (through PowerShell on Windows). It is developed on Linux, "
        "so Windows and macOS are the least exercised - where something fails, the "
        "Environment panel is the first place to look. The machines an environment cannot "
        "be built on are named under it above. On a phone Ghost Notes downloads nothing.",
        f"Source: `Deps.FETCHED`, `Deps.MANAGED` and `Deps.TOOLS` in {link(deps.rel)}, "
        "installed by [src/platform/provisioner.gd](../src/platform/provisioner.gd). The panel and every program "
        "Ghost Notes starts ask the same resolver, so the panel cannot report a program "
        "present while a launch fails to find it.",
    ])


def agent_backends(script: Script, kind: str) -> List[Dict[str, Any]]:
    """A TextGen / ImageGen registry as one record per backend, in registry order: its key, label,
    blurb and class doc, the Deps row its CLI resolves through (the `Deps.has` in its class), and
    whether it takes Ghost Notes' own tools (`takes_tools` returning true)."""
    out = []
    for key, row in script.const("REGISTRY", {}).items():
        cls = text(row, "backend")
        c = script.classes.get(cls, Class("", 0, ""))
        dep = _first(c.body, r'Deps\.has\("(\w+)"\)') or ""
        if not dep:
            warn(f"{script.rel}: {cls} names no Deps row (Deps.has) - docs/agents.md cannot say what to install")
        if "label" not in row or "blurb" not in row:
            warn(f"{script.rel}: the row '{key}' has no label or blurb")
        out.append({"key": key, "label": text(row, "label", key), "blurb": text(row, "blurb"), "doc": c.doc,
                    "line": c.line, "dep": dep, "script": script, "kind": kind,
                    "tools": bool(re.search(r"func takes_tools\(\) -> bool:\s*\n\s*return true", c.body))})
    return out


def agents_page(text_gen: Script, image_gen: Script, assistant: Script, deps: Script) -> str:
    """docs/agents.md, from TextGen.REGISTRY, ImageGen.REGISTRY and AssistantBackends.REGISTRY - each
    backend's label, blurb and class doc - and the Deps.TOOLS row of every CLI they run, for the
    install lines. Nothing here names an agent: the table is whatever the registries hold."""
    writers, painters = agent_backends(text_gen, "writer"), agent_backends(image_gen, "painter")
    helpers = [{"key": k, "label": text(r, "label"), "dep": text(r, "dep")}
               for k, r in assistant.const("REGISTRY", {}).items()]
    tools = {text(r, "key"): r for r in deps.const("TOOLS", [])}
    clis = list(dict.fromkeys(a["dep"] for a in writers + painters + helpers if a["dep"]))
    for dep in clis:
        if dep not in tools:
            warn(f"an agent runs '{dep}', which no Deps.TOOLS row describes")

    def cli_name(dep: str) -> str:
        return text(tools.get(dep, {}), "name") or dep

    def role(group: List[Dict[str, Any]], dep: str) -> str:
        return ", ".join(a["label"] for a in group if a["dep"] == dep) or "-"

    def site(dep: str) -> str:
        return text(tools.get(dep, {}), "site")

    def backends(title: str, group: List[Dict[str, Any]], s: Script) -> List[Block]:
        out: List[Block] = [f"## {title} ({len(group)})",
                            f"`{s.class_name}.REGISTRY` in {link(s.rel)}. {_sentence(one_liner(s.doc, s.class_name))}"]
        for a in group:
            out += entry(f"`{a['key']}` - {a['label']}", a["blurb"] and f"_{md(a['blurb'])}_", a["doc"],
                         f"Runs the {cli_name(a['dep'])}. Source: {link(s.rel, a['line'])}", level=3,
                         missing=f"{s.rel}: the {a['kind']} '{a['key']}' has no doc comment")
        return out

    return page("Agents: who writes, paints and fixes", [
        "Ghost Notes hands three kinds of work to AI agents. A **writer** writes the words: a card "
        "show's plan, its deck's booklet, the set dresser's table and every reading. A **painter** "
        "paints the pictures: a deck's cards, the table's cloth and room, and the book's and the "
        "notebook's illustrations. The **assistant** takes a note left in the feedback console "
        "(the backtick key) and makes the fix in the copy of Ghost Notes it runs from.",
        "Every agent is a command-line tool you install yourself, and each keeps its own sign-in, "
        "which Ghost Notes never handles: it finds the tool, runs it only when you ask, and keeps "
        "what each run was sent and what it said beside the result. Install one or several. Until "
        "one is installed, a component that needs a writer or a painter is grayed in a note's **+**, "
        "its tooltip naming every agent that would do; the Environment panel (the ⚙ in the bottom-right "
        "row) lists each tool with the command that installs it.",
        "## Which tool does what",
        table(["Command-line tool", "Writer", "Painter", "Assistant", "Ghost Notes' own tools"],
              ([f"[{cli_name(d)}]({site(d)})" if site(d) else cli_name(d), role(writers, d), role(painters, d),
                role(helpers, d), "yes" if any(w["dep"] == d and w["tools"] for w in writers) else "-"]
               for d in clis), rule="|---|---|---|---|---|"),
        "A writer that takes **Ghost Notes' own tools** works in a loop: it calls a tool Ghost "
        "Notes serves while the app runs (build a thing, stand it on the table, photograph it), "
        "looks at what comes back and goes on (`AgentTools`). The card table's set dresser works "
        "that way when its writer can; any other writer is asked once and answers once.",
        "Where each is chosen: a card show's **Writer** and **Painter** rows, each with its own "
        "model and reasoning effort; the illustration panel's painter, for the book and the "
        "notebook; and the assistant picker in the 💬 panel. What every agent is told is in "
        "[rules/](../rules), one YAML file per role.",
        *backends("Writers", writers, text_gen),
        *backends("Painters", painters, image_gen),
        f"## The assistant ({len(helpers)})",
        f"`AssistantBackends.REGISTRY` in {link(assistant.rel)}. "
        f"{_sentence(one_liner(assistant.doc, 'AssistantBackends'))} It runs in the folder Ghost Notes "
        "runs from and edits it, so it is for working on Ghost Notes itself.",
        [f"- **{a['label']}** (`{a['key']}`)" for a in helpers],
        "## Installing one",
        [line for d in clis for line in [f"- **{cli_name(d)}**" + (f" - {site(d)}" if site(d) else "")]
         + install_lines(tools.get(d, {}))],
        f"Source: the registries above, and `Deps.TOOLS` in {link(deps.rel)}, which the "
        "Environment panel and every launch resolve through - see [environment.md](environment.md).",
    ])


def _sentence(text_: str) -> str:
    """[text_] with its first letter capitalized: a class one-liner begins lower case once its
    name is stripped ("TextGen - who writes the words")."""
    return text_[:1].upper() + text_[1:]


# ---------------------------------------------------------------------------
# The CLI page, and the flags the code reads
# ---------------------------------------------------------------------------

_FLAG_READ = r'(?:\.has\(|\.find\(|begins_with\(|_arg_value\([^,()]*,|==|!=)\s*"(--[a-z][a-z-]*)"'


def flags_read(code: str) -> set:
    """The flags [code] reads off a command line: a `"--flag"` handed to `.has(`, `.find(`,
    `begins_with(` or `_arg_value(args, ...)`, or compared with `==` / `!=`. A flag a script hands to
    another program sits in an array or an `append` and is not one - which is why no list of other
    programs' flags is kept here."""
    return set(re.findall(_FLAG_READ, code))


def scan_flags() -> Dict[str, List[str]]:
    """Every flag the GDScript reads, mapped to the scripts that read it. THE CONTROL, run first:
    each way of reading one must be found, and a flag passed on must not."""
    control("flags_read", flags_read('args.has("--a"); _arg_value(args, "--b"); a == "--c"; x.find("--d")\n'
                                     'args.append("--e"); var argv := ["--f", path]') == {"--a", "--b", "--c", "--d"})
    found: Dict[str, List[str]] = {}
    for path in sorted(SCRIPTS.rglob("*.gd")):
        for flag in flags_read(code_of(script_at(path).text)):
            found.setdefault(flag, []).append(path.relative_to(ROOT).as_posix())
    return found


def cli_page(found: Dict[str, List[str]]) -> str:
    documented = {f for f, _, _, _ in CLI_FLAGS}
    undocumented = sorted(set(found) - documented - GODOT_FLAGS)
    for flag in undocumented:
        warn(f"CLI flag {flag} ({', '.join(found[flag])}) missing from CLI_FLAGS in docs.py")
    for flag in sorted(documented - set(found)):
        warn(f"CLI_FLAGS documents {flag} but nothing in the source reads it")
    blocks: List[Block] = [
        "Ghost's own flags follow the Godot separator: "
        "`godot --path . -- <ghost flags>`. Any of "
        "`--audio` / `--scene` / `--storyboard` boots straight into a song, and "
        "`--note` into a note, past the notes list. Flags marked _internal_ are passed "
        "between ghost's own processes (exporter, bake runner, mask render); "
        "you rarely type them.",
        table("| Flag | Argument | Description | |",
              ([f"`{flag}`", f"`{arg}`" if arg else "", desc, "_internal_" if internal else ""]
               for flag, arg, desc, internal in CLI_FLAGS if flag in found)),
    ]
    if undocumented:
        blocks.append("**Undocumented flags found in the source** (add them to `CLI_FLAGS` in `docs.py`): "
                      + ", ".join(f"`{f}`" for f in undocumented))
    return page("CLI flags", blocks)


# ---------------------------------------------------------------------------
# How the show is made
# ---------------------------------------------------------------------------

ADD_A_SCENE = """\
```gdscript
extends GhostScene

func build_params(rng: RandomNumberGenerator) -> Dictionary:
    return {"count": rng.randi_range(6, 24), "hue": rng.randf()}

func update(f: AudioFeatures, delta: float) -> void:
    tick(f, delta)            # advance organic motion (speed-scaled by behavior)
    drift_view(f)             # optional whole-scene camera drift (gated by behavior)
    queue_redraw()

func _draw() -> void:
    begin_draw()              # push the view transform; draw around (0, 0) = center
    for i in int(params.count):
        var p := Vector2(0, -200 + i * 20)
        p += Vector2(wobble("dot", i), 0) * 40   # per-element drift (fluid only)
        draw_circle(p, 6, Color.from_hsv(params.hue, 0.7, 1.0))
```

Register it in `SceneRoster.SCENES` - `{"script": preload("res://src/scenes/my_scene.gd"),
"behavior": "fluid"}` - more than once with different behaviors to keep several looks. A oneshot
sets `lifecycle = "oneshot"` in `build_params` and returns `true` from `finished()`. Weather and
atmosphere are layers, composed the way forces are:

```gdscript
func build_params(rng):
    framing = "field"
    add_layer("bed", rng, {"hue": 0.6})      # a color wash behind everything
    add_layer("snow", rng, {"count": 100})   # falling flakes over it
    return {}

func update(f, delta):
    tick(f, delta); update_layers(f, delta); queue_redraw()

func _draw():
    begin_draw(); draw_layers()               # or draw_layers("back") ... geometry ... draw_layers("front")
```

Set `render_kind` in `build_params` so the scene is typed (`canvas` is the default). For real 3D,
extend `Scene3D` instead: a `lens`, `add_body(...)` / `add_plane(...)` and a depth-sorted
`render_world()`. The scene's own leading `##` doc comment is its entry in
[scenes.md](scenes.md) - run `python docs.py`.
"""


def architecture_page(classes: Dict[str, Script], scenes: Dict[str, Scene], layer: Script, prims: Script,
                      medium: Script) -> str:
    """docs/architecture.md: how the parts fit together, from the audio to the screen or a video
    file. The prose is curated here (as DESIGN_NOTES is); every list and count in it is read from
    the source, and every class it names is checked to exist."""

    def ref(name: str) -> str:
        s = classes.get(name)
        if s is None:
            warn(f"docs/architecture.md names {name}, which no script declares")
            return f"`{name}`"
        return f"[`{name}`](../{s.rel})"

    def keys(reg: Dict[str, Any]) -> str:
        return ", ".join(f"`{k}`" for k in reg)

    fields = ", ".join(f"`{v}`" for v in re.findall(r"^var (\w+)", find("audio_features").text, re.M))
    live = {n: s for n, s in scenes.items() if s.behaviors}
    behaviors = sorted({b for s in live.values() for b in s.behaviors})
    kinds: Dict[str, int] = {}
    for s in live.values():
        kinds[s.render_kind] = kinds.get(s.render_kind, 0) + 1
    kind_text = ", ".join(f"`{k}` ({n})" for k, n in sorted(kinds.items(), key=lambda e: (-e[1], e[0])))
    morphing = sum(1 for s in live.values() if s.morph_in or s.morph_out)
    forces, layers = prims.const("REGISTRY", {}), layer.const("REGISTRY", {})
    media_rows = medium.const("REGISTRY", {})
    media = [text(r, "label", k) for k, r in media_rows.items()]
    portrait = [text(r, "label", k) for k, r in media_rows.items() if "portrait" in items(r, "frames")]
    return page("How the show is made", [
        "From the audio to the screen, or to a video file. Each part's reference is its own "
        "source and the [index](index.md); this page is how they fit together.",
        ["```",
         "  audio ──▶ Spectrum ──▶ AudioFeatures ──▶ GhostScene ──▶ stage ──▶ screen / video",
         "            (analyzer)    (typed, per frame)  │ (definition × behavior)",
         "                                   movement ──┤",
         "                                              ▼",
         "                                Director: cut on the music, blend sometimes",
         "```"],
        "## The signal path",
        [f"- **{ref('Spectrum')}** (an autoload) owns the audio player and the analyzer, and emits "
         f"one {ref('AudioFeatures')} a frame: {fields}. It is the one typed interface every "
         "scene reads; no scene touches the audio engine.",
         f"- **{ref('GhostScene')}** is one visualizer: `build_params(rng)` rolls a **definition** "
         "from a seeded RNG, `update(features, delta)` modulates it by the audio, and `_draw()` "
         "renders it through the scene's **view** (zoom, tilt, rotation, offset).",
         "- **Motion is its own axis.** What a scene draws is separate from how it moves - its "
         f"**behavior**, one of {', '.join(f'`{b}`' for b in behaviors)}: `static` reacts to the "
         "audio alone, `drift` adds whole-scene camera breathing, `fluid` adds independent "
         f"per-element motion. A {ref('ModBank')} of slow seeded oscillators feeds named organic "
         "channels and per-element `wobble(key, i)`.",
         "- **The seed is the song's.** The session seed derives from the audio's own "
         "fingerprint, so the same song always plays the same show; `--seed N` rolls another."],
        "## Composition, by registry",
        [f"- **Physics:** {ref('Primitives')} holds {len(forces)} force modules ({keys(forces)}) "
         f"that a scene composes into a {ref('ParticleSystem')} by key - the same `scatter` "
         "bursts glass, rocks and embers. See [forces.md](forces.md).",
         f"- **Appearance:** {ref('Layer')} holds {len(layers)} visual components "
         f"({keys(layers)}) that seed themselves, advance on the audio and draw on a scene's "
         "canvas, in unit-fraction space so they fill any frame - the same `snow` that is a "
         "scene of its own falls over the cityscape. See [layers.md](layers.md).",
         "- A new scene is mostly a parts list."],
        "## Drawing",
        [f"- **Every scene declares a render kind** - in the rotation: {kind_text}.",
         f"- **The 3D path** ({ref('Scene3D')}, {ref('Lens3D')}, {ref('Plane3D')}, {ref('Mesh3D')}, "
         f"{ref('Geo')}) is where the 2D scenes converge: a positionable perspective camera, flat "
         "quads placed in 3D, software meshes with texture and a gaussian wireframe reveal, all "
         "depth-sorted under one lens.",
         "- **Structure is the bias; motion is bounded variance.** Flat subjects sway about a "
         "seeded rest pose rather than spin; solid bodies rotate, because that is how a solid "
         f"shows its volume. {ref('Activation')} gives each element a seeded threshold and gain "
         "through a soft nonlinearity, so some stay rooted while others bloom.",
         f"- **Sound drives color, not scale.** {ref('Lighting')} moves hotspots across the "
         "frame, flares a glow on beats and drifts the hue, where pulsing geometry would throb.",
         f"- **Many items, local rules.** {ref('Swarm')} evolves a field over a grid by local "
         "interaction - thousands of items, none scripted."],
        "## Staying interactive",
        "The engine runs one main loop, so a scene that spends 300 ms in a frame blocks input "
        "for 300 ms.",
        [f"- {ref('TriBatch')} submits a frame's triangles in one call: per-shape draw calls, not "
         "geometry, were the cost.",
         f"- {ref('FrameForge')} builds a scene's geometry on a worker from a plain-data "
         "snapshot, and `_draw` submits the finished packet in microseconds."],
        "## Scheduling and transitions",
        [f"- **{ref('Director')}** (an autoload) holds the roster - {len(live)} scenes in the "
         "rotation - and performs the cuts. A scene loops until cut, or is a oneshot that "
         "reports `finished()`; once it may leave, the Director waits for a spectral trigger - "
         "a beat, a movement (a section change) or a lull - with a maximum hold as the backstop, "
         "so exits land on the music.",
         "- **Novelty, not chance:** each candidate is weighted by how long its kind has gone "
         "unshown, so the show spreads across the catalog.",
         "- **Typed morphs:** a scene declares the geometry it leaves (`morph_out`) and what it "
         "can grow from (`morph_in`); where they match, the Director hands over a typed payload "
         f"and the cut is continuous ({morphing} scenes in the rotation take part). Anything "
         "else is a cut.",
         "- **Transition style is a hierarchy**, highest first: a compatible morph, the "
         "storyboard entry's `transition`, the scene's own style, the storyboard's default, the "
         "mode's default."],
        "## Media and frames",
        f"The scenes are drawn on a **medium** - {', '.join(media)} ([media.md](media.md)) - in "
        "a **frame**: landscape, 1920x1080, or portrait, 1080x1920, for "
        f"{', '.join(portrait) or 'none yet'}. The stage is the frame, as large as the window "
        "holds it, and the Look ([filters.md](filters.md)) filters the whole picture.",
        "## Rendering: live and baked",
        ["1. **Live.** The audio plays through the analyzer and the scenes react in real time. "
         "The window stretches in `canvas_items` mode, so 2D rasterizes at the monitor's own "
         "resolution.",
         f"2. **Baked, for export** ({ref('Exporter')}). A headless process analyzes the song into a "
         f"spectrum timeline once ({ref('SpectrumBake')}, cached per song); a second renders the "
         "show with Movie Maker, driving the scenes from that timeline - frame-perfect, in sync. "
         "The size goes through a transient `override.cfg`, because Movie Maker fixes it at "
         "startup: `viewport` stretch, in a window shaped like the frame, so frames come from an "
         "offscreen buffer at any resolution. On Linux the render runs on a virtual display "
         "(`xvfb-run`), so the desktop cannot freeze it, and ffmpeg encodes the MP4 while the "
         "render is still writing."],
        "## The feedback loop",
        "The `` ` `` console captures what is on screen - the scene's typed descriptor (name, "
        "kind, behavior, seed, params, the audio frame), a note and a screenshot - into "
        "`feedback/NNNN.{json,png}`; the seed makes it reproducible. The Assistant (💬) browses "
        "the records and can send one to an AI command-line tool as a fix.",
        "## Adding a scene",
        ADD_A_SCENE,
    ])


# ---------------------------------------------------------------------------
# The index, the structure page and the README's blocks
# ---------------------------------------------------------------------------

DESIGN_NOTES = """\
## Design, in five commitments

Ghost is not an entity-component system and does not pretend to be one; it
borrows the part of that idea it actually needs - **composition over
inheritance, by key, from registries** - and pairs it with a functional
core. The commitments:

1. **Deterministic functions of (seed, audio, time).** A scene's definition
   is a pure roll of a seeded RNG (`build_params`); its per-frame state is a
   function of the typed `AudioFeatures` stream. The session seed derives
   from the audio's own content fingerprint, so the same song always plays
   the same show. Determinism is what makes the feedback console's records
   reproducible and the offline export byte-stable.
2. **Declarative where a human authors.** Storyboards describe scenes as
   data (cast + verbs on a timeline, every number a sampleable range);
   Masking effects are table-driven (`MASK_EFFECTS` / `EFFECT_CONTROLS`);
   the scene roster, forces, and visual layers are literal registries.
   Adding to a registry is the extension mechanism - not new control flow.
3. **Sampled, not baked ("cattle, not pets").** Every tunable constant is a
   candidate for sampling from a per-instance range, so two things of a
   kind always differ and the catalog gains expression for free.
4. **Convergence over lockstep.** Presentation state never snaps to its
   target: cameras, activations, glows, and the Echo cursor all move by
   exponential smoothing toward targets that may jump discontinuously.
   Work that misses a frame is absorbed, not queued - the picture is
   allowed to be briefly stale and converges when the signal (or the frame
   budget) allows.
5. **Registries make integration free.** The same `snow` layer that is a
   scene on its own falls over the cityscape; the same `scatter` force
   bursts glass, rocks, and embers. A new scene is mostly a parts list.
"""


def index_page(scenes: Dict[str, Scene], features: List[Tuple[str, str, str, str]]) -> str:
    blocks: List[Block] = [
        "Generated from the source of record (doc comments, registries, the "
        "scene roster) by [docs.py](../docs.py). The [README](../README.md) says what "
        "Ghost Notes is and how to run it, and the [roadmap](../next/roadmap.md) what "
        "comes next. Regenerate with `python docs.py`.",
        DESIGN_NOTES.rstrip(),
        "## Feature registries",
        [f"- [{title}]({slug}.md) ({count}) - {desc}" for slug, title, count, desc in features],
        "## Subsystems",
        [f"- [{title}]({_docs_relative(path)}) - {desc}" for title, path, desc in SUBSYSTEMS],
        "## Directory layout",
        layout_block("../"),
        "## Script map",
        "One folder under `src/` a group, bottom first: a script names scripts in its own "
        "folder and in the folders above its own in this list. [structure.md](structure.md) "
        "is the same stack with what each folder names and what still points up.",
    ]
    for folder, title, desc in FOLDERS:
        blocks += [f"### `{folder}/` - {title}", desc]
        if folder != "scenes":
            blocks.append([f"- [`{s.name}.gd`](../{s.rel}) **{s.class_name or s.name}** - "
                           f"{one_liner(s.doc, strip_name=s.class_name or '')}"
                           for s in sorted(folder_scripts(folder), key=lambda s: s.name)])
    blocks.append(f"Scene scripts ({len(scenes)}) are cataloged separately in [scenes.md](scenes.md).")
    return page("Ghost Notes docs index", blocks)


def structure_page(edges: Dict[str, set]) -> str:
    """docs/structure.md: the stack, what each folder names, and what still points up."""
    rank = {folder: i for i, (folder, _t, _d) in enumerate(FOLDERS)}
    names: Dict[str, set] = {folder: set() for folder in rank}
    inside = down = 0
    for a, bs in edges.items():
        for b in bs:
            fa, fb = a.split("/")[0], b.split("/")[0]
            if fa == fb:
                inside += 1
            elif rank[fb] < rank[fa]:
                down += 1
                names[fa].add(fb)
    up = sum(len(pairs_) for _p, _f, pairs_ in UPWARD)
    blocks: List[Block] = [
        "`src/` is one level of folders, and the folders are a STACK. A script names "
        "scripts in its own folder and in the folders below it, and nothing above: what a "
        "part reads from higher up is handed to it. So the folders a change can reach are "
        "the ones above the folder it is in, and a folder near the bottom can be read "
        "without knowing anything over it.",
        "Written from `FOLDERS` and `UPWARD` in [docs.py](../docs.py), which holds the code "
        "to both at every `python docs.py --check`: a new reference that points up fails, "
        "and so does a listed one that is gone. [next/structure.md](../next/structure.md) "
        "is why the stack is in this order and what is being done about the rest.",
        f"Between scripts today: {inside} references inside a folder, {down} down the "
        f"stack, {up} up it.",
        "## The stack, top first",
        table(["folder", "what it is", "scripts", "names"],
              ([f"`{folder}/`", title, len(folder_scripts(folder)),
                ", ".join(f"`{n}`" for n in sorted(names[folder], key=lambda n: -rank[n])) or "nothing"]
               for folder, title, _desc in reversed(FOLDERS))),
        "## The folders, bottom first",
    ]
    for folder, title, desc in FOLDERS:
        blocks += [f"### `{folder}/` - {title}", desc]
        if folder != "scenes":
            blocks.append(", ".join(f"[`{s.name}`](../{s.rel})" for s in folder_scripts(folder)))
    blocks.append("## What still points up")
    if not UPWARD:
        blocks.append("Nothing. Every reference between scripts stays in its folder or points down, "
                      "and `python docs.py --check` fails the first one that does not.")
    else:
        blocks.append(f"{up} references, in {len(UPWARD)} patterns. Each row is a script naming one "
                      "above it; a pattern's rows go when its fix lands.")
    for pattern, fix, pairs_ in UPWARD:
        blocks += [f"### {pattern} ({len(pairs_)})", f"The fix: {fix}.", [f"- `{a}` names `{b}`" for a, b in pairs_]]
    return page("The structure", blocks)


def _reprefix(desc: str) -> str:
    """Rebase repo-root-relative markdown links for use inside docs/."""
    return re.sub(r"\]\((?!https?:|/|#|\.\.?/)([^)]+)\)", lambda m: f"](../{m.group(1)})", desc)


def _docs_relative(path: str) -> str:
    """A repo-relative path as docs/index.md links it."""
    return path[len("docs/"):] if path.startswith("docs/") else f"../{path}"


def layout_block(link_prefix: str = "") -> List[str]:
    """The top-level layout as a list, each entry linked where it is in the repository (a
    git-ignored runtime folder is not, since it is not there to link to). `link_prefix` rebases
    the links for a page outside the root (`../` from docs/)."""
    out = []
    for name, desc in TOP_LEVEL:
        label = f"`{name}`" if "git-ignored" in desc else f"[`{name}`]({link_prefix}{name})"
        out.append(f"- **{label}** - {_reprefix(desc) if link_prefix else desc}")
    return out


def readme_blocks(features: List[Tuple[str, str, str, str]]) -> Dict[str, str]:
    """The README's AUTODOC blocks: the registry pages, the standalone ones, the top-level layout."""
    return {
        "FEATURES": "\n".join(
            ["Ghost Notes is built from registries. Each page below is generated from one, listing "
             "every entry and where it lives; [docs/index.md](docs/index.md) is the whole map.", ""]
            + [f"- [{title}](docs/{slug}.md) ({count}) - {desc}" for slug, title, count, desc in features]),
        "SUBSYSTEMS": "\n".join(["Documented outside the registry pages.", ""]
                                + [f"- [{title}]({path}) - {desc}" for title, path, desc in SUBSYSTEMS]),
        "LAYOUT": "Top-level layout; every script is in [docs/index.md](docs/index.md).\n\n"
                  + "\n".join(layout_block()),
    }


def _sort_roadmap() -> None:
    """Keep next/roadmap.md's open items above its closed ones, as praxis/docs.py keeps its own:
    each group sorted by length, open shortest first, closed longest first. Stable, so items of
    equal length keep their order; idempotent."""
    path = ROOT / "next" / "roadmap.md"
    if not path.exists():
        return
    text_ = path.read_text()
    first = re.search(r"^- \[[ xX]\] ", text_, re.M)
    if not first:
        return
    preamble, body = text_[:first.start()], text_[first.start():]
    starts = [m.start() for m in re.finditer(r"^- \[[ xX]\] ", body, re.M)] + [len(body)]
    blocks = [body[s:e].rstrip("\n") for s, e in zip(starts, starts[1:])]
    opens = sorted((b for b in blocks if b.startswith("- [ ] ")), key=len)
    closed = sorted((b for b in blocks if re.match(r"- \[[xX]\] ", b)), key=len, reverse=True)
    _write_if_changed(path, preamble.rstrip("\n") + "\n\n" + "\n\n".join(opens + closed) + "\n")


# ---------------------------------------------------------------------------
# The checks. Each runs its CONTROL first - planted wrongs it must report, and planted rights it
# must not: a check whose control does not fail as it should has not been run.
# ---------------------------------------------------------------------------


def control(check: str, held: bool) -> None:
    if not held:
        warn(f"{check}: its control did not fail - the check proves nothing")


class Rule(NamedTuple):
    """A pattern the code must never hold, or with [require], one it must. [say] is the warning,
    formatted with `{file}`, `{line}`, `{hit}` (the pattern's group, else its match) and `{text}`
    (the line); a warning said twice is said once."""

    name: str
    files: Tuple[str, ...]  # globs from the root
    pattern: str
    say: str
    planted: Tuple[Tuple[str, str, int], ...]  # (a file's name, its text, how many warnings it must give)
    kinds: Tuple[str, ...] = (".gd",)  # the file suffixes looked in
    skip: Tuple[str, ...] = ()  # file names or paths (globs) left out
    require: bool = False  # the pattern must be found in each file, over its whole text
    comments: bool = False  # look in comments too (a path a doc comment names must be real)
    allow: str = ""  # a line matching this is never a hit
    when: Optional[Callable[[re.Match, str], bool]] = None  # (match, the file's code): a hit only if true


# A comment, by file kind: a resource's or a config file's is a whole line from `;`.
COMMENT_MARKS = {".gd": "#", ".gdshader": "//", ".gdshaderinc": "//"}

# A file is named by its `res://` path, never a `uid://` (CLAUDE.md, "Rules").
UID_OVERRIDE = "text_editor/behavior/files/drop_preload_resources_as_uid=false"

RULES: List[Rule] = [
    # NOTHING BUT settings.gd TOUCHES THE CONFIG FILE. Each control used to write its own
    # `ConfigFile.load()` -> set -> `save()` on the same file: five writers, five debounces, a new
    # control persistent only if someone remembered, two processes clobbering each other (an export
    # renders in a second one). The fix was one owner, `Settings`; this stops a sixth writer. Mask
    # sessions are per-video files under masks/, not the app's settings.
    Rule("settings owner", ("src/**/*",), r'ConfigFile\.new\(\)|"user://ghost\.cfg"',
         "{file}: writes user://ghost.cfg directly - settings belong to Settings (src/platform/settings.gd), "
         "which owns the file, the debounce and the flushing",
         (("a.gd", "var c := ConfigFile.new()", 1), ("a.gd", "# ConfigFile.new() was here\nSettings.bind(x)", 0)),
         skip=("settings.gd", "*mask*")),
    # A CARD HANDS THE READING HOW IT GOES OUT THROUGH `ReadingPanel.hand_publish`, never by setting
    # `publish`: `hand_publish` takes the card's name with it, so handing one is listing the steps the
    # note's other cards add (the YouTube card's tags). The Letter's set `reading.publish` itself and
    # its steps waited out of reach of its Generate (2026-10-28: "a game of whack-a-mole").
    Rule("publish handed", ("src/**/*",), r"\.publish\s*=(?!=)",
         "{file}: sets a reading's publish ({text}) - a card hands it with ReadingPanel.hand_publish(publish, "
         "its name), which lists the steps the note's other cards add under it",
         (("a.gd", "\tcard._panel.publish = Publish.new(card)", 1),
          ("a.gd", "\tif reading.publish == p:\n\t## reading.publish = Publish.new(self)\n"
                   "\treading.hand_publish(Publish.new(self), host_name())", 0)),
         skip=("reading_panel.gd",)),
    # `Films.pump()` IS CALLED FROM main's `_process`. A window cut is an ffmpeg child, and something
    # with a frame must notice it exit and promote its output out of the `.part` name. The live film
    # panel and the Generative panel polled it - the two things usually absent - so footage showed on
    # one page of a session and never again. A probe replaces the main scene, so no gate sees this.
    Rule("films pumped", ("src/*/main.gd",), r"Films\.pump\(\)",
         "{file} never calls Films.pump() - a finished window cut will never be promoted, and film will "
         "appear once per session at most",
         (("main.gd", "func _process(d):\n\tpass", 1), ("main.gd", "func _process(d):\n\tFilms.pump()", 0)),
         require=True),
    # EVERY PANEL CONTROL THE MASK EDITOR SYNCS IS BUILT. Its panel is three lists that must agree: a
    # member, the line in _build_panel that makes it, the line in _refresh_panel_inner that writes it
    # back. Drop a build line and the member stays null, so every refresh throws - at open, per
    # selection, per frame - and the controls below it stop updating. A runtime error prints and
    # carries on, so only this sees it: a name written to and never assigned.
    Rule("panel controls", ("src/*/mask_editor.gd",), r"\b(_\w+)\.set_(?:value|pressed)_no_signal\(",
         "{file}: {hit} is written by _refresh_panel_inner but never built - the panel will throw on every refresh",
         (("e.gd", "var _a\nfunc r():\n\t_a.set_value_no_signal(1)", 1),
          ("e.gd", "func b():\n\t_a = HSlider.new()\nfunc r():\n\t_a.set_value_no_signal(1)", 0)),
         when=lambda m, code: not re.search(rf"^\s*{re.escape(m.group(1))} = ", code, re.M)),
    # A SCRIPT PATH WRITTEN ANYWHERE NAMES A SCRIPT THAT EXISTS. A class name is global, so a moved
    # script breaks nothing the compiler sees - but a `load("res://src/...")` from a string, a
    # `--script` argument, a registry row naming its script by path, or a gate reading a source as
    # text breaks when it runs, in whichever session gets there first. Doc comments count; next/'s
    # notes are allowed to remember a file that is gone.
    Rule("paths", ("project.godot", "CLAUDE.md", "README.md", "src/**/*", "tests/**/*", "rules/**/*",
                   "storyboards/**/*", "shaders/**/*", "scenes/**/*", "hosts/**/*", "scripts/**/*"),
         r"(?<![\w/])(?:res://)?((?:src|tests)/[a-z_0-9]+(?:/[a-z_0-9]+)*\.gd)\b",
         "{file} names {hit}, which does not exist",
         (("a.gd", 'load("res://src/platform/no_such_script.gd")', 1),
          ("a.gd", "src/platform/settings.gd and res://src/show/director.gd", 0)),
         kinds=(".gd", ".tscn", ".godot", ".cfg", ".py", ".sh", ".md", ".yaml", ".yml", ".gdshader", ".gdshaderinc"),
         skip=("*__pycache__*",), comments=True, when=lambda m, _code: not (ROOT / m.group(1)).exists()),
    # A FILE IS NAMED BY ITS `res://` PATH, NEVER A `uid://`. The `.uid` files are gitignored (each
    # checkout mints its own), so a `uid://` naming another file resolves in the checkout that wrote
    # it and nowhere else - a bare `preload("uid://...")` has no path to fall back on. The editor
    # writes one when a file is dropped into the script editor (unless UID_OVERRIDE is kept) and when
    # it saves a scene that references another file. A scene's own header names itself.
    Rule("no uids", ("project.godot", "export_presets.cfg", "src/**/*", "tests/**/*", "scenes/**/*", "shaders/**/*",
                     "fonts/**/*", "data/**/*"), r"uid://\w*",
         "{file}:{line} names a file by {hit}: name it by its res:// path (the .uid files are gitignored, so a "
         "UID holds in one checkout only)",
         (("a.gd", 'const A := preload("uid://b1x")', 1),
          ("a.tscn", '[ext_resource type="Script" uid="uid://b1x" path="res://a.gd" id="1"]', 1),
          ("a.tscn", '[gd_scene format=3 uid="uid://b1x"]', 0), ("a.gd", '# never preload("uid://b1x")', 0)),
         kinds=(".gd", ".tscn", ".tres", ".godot", ".cfg", ".gdshader", ".gdshaderinc"),
         allow=r"^\[gd_(?:scene|resource)\b"),
    Rule("uid override", ("project.godot",),
         r"^\[editor_overrides\]\n(?:[^\[\n].*\n|\n)*?" + re.escape(UID_OVERRIDE) + "$",
         f"{{file}}: [editor_overrides] must keep {UID_OVERRIDE}, or a file dropped into the script editor is "
         "preloaded by a UID only this checkout knows",
         (("project.godot", "[editor_overrides]\n\n" + UID_OVERRIDE + "\n", 0),
          ("project.godot", "[editor_overrides]\n\n[x]\n" + UID_OVERRIDE + "\n", 1)),
         kinds=(".godot",), require=True, comments=True),
]


def rule_hits(rule: Rule, name: str, text_: str) -> List[str]:
    """What [rule] says of one file, [name] standing for its kind and its place in a warning."""
    suffix = Path(name).suffix
    if rule.comments:
        code = text_
    elif suffix in COMMENT_MARKS:
        code = code_of(text_, COMMENT_MARKS[suffix])
    else:
        code = re.sub(r"(?m)^[ \t]*;.*$", "", text_)
    if rule.require:
        return [] if re.search(rule.pattern, code, re.M) else [rule.say.format(file=name, line=0, hit="", text="")]
    out: List[str] = []
    for m in re.finditer(rule.pattern, code, re.M):
        start, end = code.rfind("\n", 0, m.start()) + 1, code.find("\n", m.start())
        line = code[start:end if end >= 0 else len(code)]
        if (rule.allow and re.search(rule.allow, line)) or (rule.when and not rule.when(m, code)):
            continue
        said = rule.say.format(file=name, line=code.count("\n", 0, start) + 1, hit=m.group(m.lastindex or 0),
                               text=line.strip())
        if said not in out:
            out.append(said)
    return out


def check_rules() -> None:
    """Every rule of `RULES` over the files it reads, after its control."""
    for rule in RULES:
        control(f"rule '{rule.name}'", all(len(rule_hits(rule, n, t)) == k for n, t, k in rule.planted))
        files = sorted({p for g in rule.files for p in ROOT.glob(g) if p.is_file() and p.suffix in rule.kinds
                        and not any(fnmatch(p.name, s) or fnmatch(p.relative_to(ROOT).as_posix(), s)
                                    for s in rule.skip)})
        if not files:
            warn(f"rule '{rule.name}' reads {', '.join(rule.files)}, which name no file")
        for p in files:
            try:
                text_ = p.read_text()
            except UnicodeDecodeError:
                continue
            for said in rule_hits(rule, p.relative_to(ROOT).as_posix(), text_):
                warn(said)


def _references() -> Dict[str, set]:
    """{script: the scripts it names}, each as `folder/name`: a class name or an autoload's
    name in its code, or a `preload` / `load` of a script's path."""
    paths = sorted(SCRIPTS.glob("*/*.gd"))
    key = lambda p: f"{p.parent.name}/{p.stem}"  # noqa: E731
    text_ = {key(p): script_at(p).text for p in paths}
    by_res = {p.relative_to(ROOT).as_posix(): key(p) for p in paths}
    named = {name: by_res[rel] for name, rel in autoloads().items() if rel in by_res}
    for k, t in text_.items():
        m = re.search(r"^class_name\s+(\w+)", t, re.M)
        if m:
            named[m.group(1)] = k
    edges: Dict[str, set] = {k: set() for k in text_}
    for k, t in text_.items():
        for m in re.finditer(r"\b[A-Z][A-Za-z0-9_]*\b", code_of(t, strings=False)):
            edges[k].add(named.get(m.group(0), k))
        for m in re.finditer(r'(?:pre)?load\(\s*"res://(src/[\w/]+\.gd)"', t):
            edges[k].add(by_res.get(m.group(1), k))
        edges[k].discard(k)
    return edges


def _upward(edges: Dict[str, set], order: List[str]) -> List[Tuple[str, str]]:
    """The references that point up the stack: (script, the script above it that it names)."""
    rank = {folder: i for i, folder in enumerate(order)}
    return [(a, b) for a in sorted(edges) for b in sorted(edges[a])
            if a.split("/")[0] in rank and b.split("/")[0] in rank and rank[b.split("/")[0]] > rank[a.split("/")[0]]]


def _structure_problems(edges: Dict[str, set], order: List[str], listed: List[Tuple[str, str]]) -> List[str]:
    """What is wrong between the code and the stack. Pure, so its control can be run on a
    made-up graph: see `check_structure`."""
    up = _upward(edges, order)
    out = [f"src/{a}.gd names src/{b}.gd, which is ABOVE it: src/ is a stack, and a script names its own folder "
           "and the ones below. Hand it what it reads (next/structure.md, \"The rules\") - do not add a row to UPWARD"
           for a, b in up if (a, b) not in listed]
    out += [f"docs.py UPWARD lists {a} -> {b}, which is no longer in the code: delete its row (the list only shrinks)"
            for a, b in listed if (a, b) not in up]
    if len(set(listed)) != len(listed):
        out.append("docs.py UPWARD lists a pair twice")
    return out


def _handed_problems(edges: Dict[str, set], handed: Dict[str, List[str]]) -> List[str]:
    """The scripts a show mounts that name what they are handed (HANDED). Pure, for the control."""
    return [f"src/{a}.gd names src/{b}.gd: a part a show mounts reads the show through its `feed` ([ShowFeed]) "
            "- hand it what it needs there (docs.py HANDED)"
            for a in sorted(edges) for b in sorted(edges[a]) if a.split("/")[0] in handed.get(b, [])]


def check_structure() -> Dict[str, set]:
    """src/ is a stack (FOLDERS, bottom first), and the code is held to it.

    Every script sits in exactly one folder that FOLDERS names, and every reference between
    scripts points down or stays in its folder - except the pairs UPWARD lists, which is what
    is left to fix and may only get shorter. A flat `src/` hid that the code was already
    layered (703 of 751 references pointed down when this was first measured, 2026-10-13); a
    stack nothing holds is flat again within a month, one convenient `Director.x` at a time.

    THE CONTROL: before the real code is judged, a made-up graph with one reference planted
    upward must be reported, and one listed pair that is gone must be reported too.
    """
    order = [folder for folder, _t, _d in FOLDERS]
    control("check_structure", len(_structure_problems({"platform/a": {"app/b"}, "app/b": {"platform/a"}}, order, []))
            == 1 == len(_structure_problems({"platform/a": set()}, order, [("platform/a", "app/b")])))
    control("check_structure's HANDED",
            len(_handed_problems({"media/a": {"audio/b"}, "audio/c": {"audio/b"}}, {"audio/b": ["media"]})) == 1)
    on_disk = sorted(p.name for p in SCRIPTS.iterdir() if p.is_dir())
    for folder in on_disk:
        if folder not in order:
            warn(f"src/{folder}/ is not in docs.py FOLDERS: say where it sits in the stack")
    for folder in order:
        if folder not in on_disk:
            warn(f"docs.py FOLDERS lists src/{folder}/, which does not exist")
    for p in sorted(SCRIPTS.glob("*.gd")):
        warn(f"src/{p.name} is in no folder: every script lives in src/<folder>/")
    for p in sorted(SCRIPTS.glob("*/*/*.gd")):
        warn(f"{p.relative_to(ROOT).as_posix()}: one level of folders under src/, no deeper")
    edges = _references()
    listed = [pair for _p, _f, pairs_ in UPWARD for pair in pairs_]
    for problem in _structure_problems(edges, order, listed) + _handed_problems(edges, HANDED):
        warn(problem)
    return edges


def _reads(body: str) -> Dict[str, Tuple[str, str]]:
    """The settings a class reads off its config: key -> (num / flag / txt, the default as written),
    the first read of each. Comments and strings aside from the key itself are not looked in."""
    out: Dict[str, Tuple[str, str]] = {}
    code = code_of(body)
    for m in re.finditer(r'(?<![\w.])(num|flag|txt|cfg\.get)\("(\w+)",\s*', code):
        i, depth = m.end(), 1
        while depth and i < len(code):
            depth += {"(": 1, ")": -1}.get(code[i], 0)
            i += 1
        out.setdefault(m.group(2), (m.group(1).replace("cfg.get", "get"), code[m.end():i - 1].strip()))
    return out


def _field_problems(bodies: Dict[str, str], registry: Dict[str, str], base: str) -> List[str]:
    """What is wrong between each registered class's FIELDS and the settings its code reads: a read
    with no row, a row nothing reads, a row's type or literal default that is not the code's. The
    base class's own reads are its `COMMON` rows, every class's. Pure, so its control can run on a
    made-up script (see `check_fields`)."""
    out = []
    for cls in [base] + list(registry.values()):
        body = bodies.get(cls, "")
        own = _reads(body)
        name = "COMMON" if cls == base else "FIELDS"
        fields = const(body, name, {})
        if cls == base and not own and not fields:
            continue
        for k, (kind, default) in own.items():
            if k not in fields:
                out.append(f"{cls} reads `{k}` and its {name} has no row for it")
                continue
            row = fields[k]
            if kind != "get" and row.get("type") != kind:
                out.append(f"{cls}.{name} `{k}` is a {row.get('type')}, and the code reads a {kind}")
            want = row.get("default")
            try:
                lit = ast.literal_eval(default.replace("true", "True").replace("false", "False"))
            except (ValueError, SyntaxError):
                lit = None  # drawn from the seed, or worked out: the row says so in words
            if lit is not None and want != lit:
                out.append(f"{cls}.{name} `{k}` defaults to {want!r}, and the code to {lit!r}")
            if lit is None and want is not None:
                out.append(f"{cls}.{name} `{k}` defaults to {want!r}, and the code draws it ({default})")
        out += [f"{cls}.{name} has `{k}`, which its code never reads" for k in fields if k not in own]
    return out


def _scene_field_problems(text_: str, name: str) -> List[str]:
    """What is wrong between a scene's FIELDS and the settings it takes from an entry
    ([method GhostScene.choice] and [method GhostScene.number], steps 27 and 28): a setting chosen or numbered
    with no row of its type, a row nothing reads, a choice whose `options` (or `names`) names no table
    of the scene, a number whose `range` is not two numbers low to high, and a default (a setting is
    the seed's until it is told). Pure, so its control runs on a made-up scene."""
    out = []
    code = code_of(text_)
    reads = {"choice": set(re.findall(r'\bchoice\("(\w+)"', code)),
             "num": set(re.findall(r'(?<![\w.])number\("(\w+)"', code))}
    fields = const(text_, "FIELDS", {})
    tables = set(re.findall(r"^const (\w+)\b", text_, re.M))
    for kind, verb in (("choice", "chooses"), ("num", "numbers")):
        for k in sorted(reads[kind]):
            if k not in fields:
                out.append(f"{name} {verb} `{k}` and its FIELDS has no row for it")
            elif fields[k].get("type") != kind:
                out.append(f"{name}.FIELDS `{k}` is a {fields[k].get('type')}, and the code reads a {kind}")
    for k, row in fields.items():
        kind = row.get("type")
        if kind not in reads:
            out.append(f"{name}.FIELDS `{k}` is a {kind!r}: a scene's setting is a choice or a num")
            continue
        if k not in reads[kind]:
            out.append(f"{name}.FIELDS has `{k}`, which its code never reads")
        if kind == "choice":
            for part in ("options", "names"):
                v = row.get(part)
                if (part == "options" or v is not None) and (not isinstance(v, str) or v not in tables):
                    out.append(f"{name}.FIELDS `{k}`: its {part} name `{v}`, which is no table of the scene")
        else:
            r = row.get("range")
            if not (isinstance(r, list) and len(r) == 2 and all(type(x) in (int, float) for x in r) and r[0] < r[1]):
                out.append(f"{name}.FIELDS `{k}`: its range {r!r} is not two numbers, low to high")
        if row.get("default") is not None:
            out.append(f"{name}.FIELDS `{k}` defaults to {row.get('default')!r} - a setting is the seed's until told")
    return out


def check_fields() -> None:
    """EVERY SETTING A COMPOSABLE THING READS IS A ROW (next/structure.md, steps 16 and 27). A layer and
    a force read their config through `num` / `flag` / `txt`, a scene takes an entry's `set` through
    `choice`; each class declares those settings in its own `FIELDS` - what a timeline's inspector
    builds its rows from ([SchemaForm]) and what an agent choosing a part is shown - and this holds the
    two together: a setting read with no row, a row nothing reads, and a default the row and the code
    disagree on (a scene's row: the table its options are must be the scene's).

    THE CONTROL, run first: a made-up class that reads a setting its FIELDS lacks, and one whose row
    has the wrong default, must each be reported; and a made-up scene that chooses a setting with no
    row, one whose row names no table of it, and one that numbers a setting with no row and has a
    range high to low.
    """
    planted = {"A": 'func _init():\n\tvar n := num("count", 3)\n',
               "B": 'const FIELDS := {"count": {"type": "num", "default": 4}}\nfunc _init():\n\tvar n := num("count", 3)\n'}
    control("check_fields", len(_field_problems(planted, {"a": "A", "b": "B"}, "Base")) == 2)
    scene_a = 'const KINDS := ["a", "b"]\nfunc build_params(rng):\n\tvar k = choice("kind", rng)\n'
    scene_b = ('const FIELDS := {"kind": {"label": "Kind", "type": "choice", "options": "SORTS", "default": null, '
               '"blurb": "x"}}\nconst KINDS := ["a"]\nfunc build_params(rng):\n\tvar k = choice("kind", rng)\n')
    scene_c = ('const FIELDS := {"size": {"label": "Size", "type": "num", "range": [2.0, 1.0], "default": null, '
               '"blurb": "x"}}\nfunc build_params(rng):\n\tvar s = number("size", rng)\n\tvar r = number("rim", rng)\n')
    control("check_fields' scenes", [len(_scene_field_problems(t, n)) for t, n in
                                     ((scene_a, "a"), (scene_b, "b"), (scene_c, "c"))] == [1, 1, 2])
    for stem, base in (("layer", "Base"), ("primitives", "Force")):
        s = find(stem)
        for problem in _field_problems({k: c.body for k, c in s.classes.items()}, s.const("REGISTRY", {}), base):
            warn(f"{s.rel}: {problem}")
    for path in sorted(SCENES_DIR.glob("*.gd")):
        for problem in _scene_field_problems(script_at(path).text, path.stem):
            warn(f"{path.relative_to(ROOT)}: {problem}")


# Where the user's data is, under the OS's data path: what user:// was while the project was called "ghost".
USER_DIR = "godot/app_userdata/ghost"


def _user_dir(project: str) -> str:
    """The folder under the OS's data path that Godot makes user:// from [application], as
    `OS::get_user_data_dir` (core/os/os.cpp) does: `custom_user_dir_name` when `use_custom_user_dir`
    is on, else `godot/app_userdata/<config/name>`."""
    app = re.search(r"^\[application\]\n((?:[^\[\n].*\n|\n)*)", project, re.M)
    body = app.group(1) if app else ""

    def get(key: str) -> str:
        m = re.search(r"^" + re.escape(key) + r"=(.*)$", body, re.M)
        return m.group(1).strip().strip('"') if m else ""

    if get("config/use_custom_user_dir") == "true" and get("config/custom_user_dir_name"):
        return get("config/custom_user_dir_name")
    return f"godot/app_userdata/{get('config/name')}"


def check_user_dir() -> None:
    """The user's data stays where it is, whatever the project is called.

    Godot makes user:// from the project's name unless the project names the folder itself, so
    renaming the project moved it: every note, setting, voice, episode and fetched tool (gigabytes)
    left behind in the old folder, and a child started after the rename - the export's bake - wrote
    into the new one while the app still read the old ("Bake failed", 2026-10-16). The project is
    called "Ghost Notes" and names its folder outright: `use_custom_user_dir` and
    `custom_user_dir_name` = USER_DIR (Android ignores both and keeps the app's own files folder).

    THE CONTROL, run first: a project renamed without naming its folder must be caught, and one that
    names it must not.
    """
    renamed = '[application]\n\nconfig/name="Ghost Notes"\n'
    named = renamed + f'config/use_custom_user_dir=true\nconfig/custom_user_dir_name="{USER_DIR}"\n'
    control("check_user_dir", _user_dir(renamed) != USER_DIR and _user_dir(named) == USER_DIR)
    got = _user_dir((ROOT / "project.godot").read_text())
    if got != USER_DIR:
        warn(f"project.godot: user:// would be <data>/{got}, but the user's data is in <data>/{USER_DIR}: "
             f'name the folder - config/use_custom_user_dir=true, config/custom_user_dir_name="{USER_DIR}"')


# ---------------------------------------------------------------------------
# Output plumbing, and main
# ---------------------------------------------------------------------------


def _write_if_changed(path: Path, content: str) -> None:
    if path.exists() and path.read_text() == content:
        return
    if CHECK:
        STALE.append(str(path.relative_to(ROOT)))
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content)
    print(f"[ghost-docs] wrote {path.relative_to(ROOT)}")


def _patch_readme_block(name: str, body: str) -> None:
    readme = ROOT / "README.md"
    if not readme.exists():
        return
    current = readme.read_text()
    begin, end = f"<!-- AUTODOC:{name}:BEGIN -->", f"<!-- AUTODOC:{name}:END -->"
    if begin not in current or end not in current:
        warn(f"README.md missing AUTODOC:{name} markers - block not patched")
        return
    before, _, rest = current.partition(begin)
    _, _, after = rest.partition(end)
    _write_if_changed(readme, f"{before}{begin}\n\n{body.rstrip()}\n\n{end}{after}")


def find(stem: str) -> Script:
    """A script by its file name alone: its folder is looked up, never written here, so a script that
    moves folders needs no edit in this file. The scene catalog is left out - `glyphs` and `terrain`
    are a generator and a scene both - and a scene is read from `SCENES_DIR`."""
    found = [p for p in sorted(SCRIPTS.glob(f"*/{stem}.gd")) if p.parent != SCENES_DIR]
    if len(found) != 1:
        raise SystemExit(f"[ghost-docs] docs.py reads src/*/{stem}.gd and found {len(found)}: "
                         + (", ".join(p.relative_to(ROOT).as_posix() for p in found) or "none"))
    return script_at(found[0])


def main() -> int:
    if "--folders" in sys.argv[1:]:
        # the stack, bottom first, one a line: what scripts/check.sh --for reads
        print("\n".join(folder for folder, _t, _d in FOLDERS))
        return 0
    seen: Dict[str, str] = {}
    for p in sorted(SCRIPTS.glob("*/*.gd")):
        rel = p.relative_to(ROOT).as_posix()
        if p.parent != SCENES_DIR and seen.setdefault(p.stem, rel) != rel:
            warn(f"two scripts are named {p.stem}.gd: {seen[p.stem]} and {rel}")
    s = find
    scenes, groups = collect_scenes()
    edges = check_structure()
    check_rules()
    check_user_dir()
    check_fields()

    def count(stem: str, name: str = "REGISTRY") -> int:
        return len(s(stem).const(name, {}))

    # The registry-backed pages: (slug, title, count, one line). One source for docs/index.md
    # and the README's FEATURES block, every count read from the registry it names.
    features = [
        ("components", "Components", f"{count('components')} components, {count('components', 'WORKSPACES')} workspaces",
         "what a note can carry, the room each part takes, which panel runs it, and what each part asks of the "
         "platform."),
        ("scenes", "Scenes", str(sum(1 for sc in scenes.values() if sc.behaviors)),
         "the visualizer scenes in the rotation, each from its own doc comment."),
        ("media", "Media", str(count("medium")), "what the show is carried on."),
        ("filters", "Look filters", str(count("filters")), "the post-process over the whole picture."),
        ("layers", "Layers", str(count("layer")), "the visual components scenes compose - weather, skies, atmosphere."),
        ("forces", "Forces", str(count("primitives")), "the physics primitives particles compose."),
        ("stage", "Stage actors and verbs", f"{count('cast')} actors, {count('actions')} verbs",
         "what a storyboard's `stage` entries are made of."),
        ("masking", "Masking effects", str(count("mask_session", "MASK_EFFECTS")),
         "the video effects editor: its model, its effects and its headless tools."),
        ("script", "Script marks", str(count("script_marks")),
         "every mark a script may carry - the script editor's palette."),
        ("agents", "Agents",
         f"{count('text_gen')} writers, {count('image_gen')} painters, {count('assistant_backends')} assistants",
         "the AI command-line tools Ghost Notes hands its words, pictures and fixes to: which does what, how each "
         "is run, and how to install one."),
    ]
    pages = {
        "components": lambda: components_page(s("components"), s("capabilities")),
        "scenes": lambda: scenes_page(scenes, groups),
        "layers": lambda: registry_page(
            "Layers: the visual-component registry",
            "Reusable appearance components any scene composes by key via "
            "`add_layer` / `update_layers` / `draw_layers(z)`.", s("layer")),
        "forces": lambda: registry_page(
            "Forces: the physics-primitive registry",
            "Reusable force modules a scene composes into a `ParticleSystem` by key.", s("primitives")),
        "stage": lambda: stage_page(s("cast"), s("actions"), s("track"), s("storyboard")),
        "masking": lambda: masking_page(s("mask_session"), s("mask_editor")),
        "media": lambda: media_page(s("medium")),
        "filters": lambda: filters_page(s("filters")),
        "script": lambda: script_page(s("script_marks")),
        "architecture": lambda: architecture_page(class_index(), scenes, s("layer"), s("primitives"), s("medium")),
        "environment": lambda: environment_page(s("deps")),
        "agents": lambda: agents_page(s("text_gen"), s("image_gen"), s("assistant_backends"), s("deps")),
        "structure": lambda: structure_page(edges),
        "cli": lambda: cli_page(scan_flags()),
        "index": lambda: index_page(scenes, features),
    }
    for slug, build in pages.items():
        _write_if_changed(DOCS / f"{slug}.md", build())
    for name, body in readme_blocks(features).items():
        _patch_readme_block(name, body)
    _sort_roadmap()

    print(f"[ghost-docs] done: {len(scenes)} scenes, {len(seen)} scripts, {len(WARNINGS)} warning(s).")
    if CHECK:
        for path in STALE:
            print(f"[ghost-docs] STALE {path} - run `python docs.py`")
        return 1 if STALE or WARNINGS else 0
    return 0


if __name__ == "__main__":
    sys.exit(main())
