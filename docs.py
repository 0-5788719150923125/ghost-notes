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
  docs/cli.md          - every ghost command-line flag.

The README is stubs and lists that link here: docs.py patches it between
`<!-- AUTODOC:NAME:BEGIN/END -->` marker pairs (FEATURES, SUBSYSTEMS, LAYOUT),
the same mechanism as praxis/docs.py, and keeps next/roadmap.md's open items
above its closed ones, as Praxis keeps its roadmap.

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
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

ROOT = Path(__file__).resolve().parent
SCRIPTS = ROOT / "src"
SCENES_DIR = SCRIPTS / "scenes"
MEDIA_DIR = SCRIPTS / "media"
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
    (
        "data",
        "Plain data",
        "Plain data in and out, at the bottom because it needs nothing: the YAML-subset "
        "parser, a document's frontmatter (re-read, one key edited, verified), pure edits of "
        "nested data, reading any registry's rows (`Registry`), what an agent is told "
        "(`rules/`), and a script read into cues, hesitations and pictures.",
    ),
    (
        "platform",
        "The machine",
        "The machine under Ghost Notes: the one owner of its settings file, the earliest hook "
        "of a launch, every child program in one place, what ghost installs for itself and "
        "keeps current, the app's own update, and what this platform can do.",
    ),
    (
        "audio",
        "Audio & analysis",
        "From a song file to the typed per-frame `AudioFeatures` every scene "
        "consumes - live analyzer, offline bake, and the content descriptors "
        "that make sessions deterministic per song.",
    ),
    (
        "render",
        "Drawing",
        "How things get drawn and how a heavy scene stays interactive: thousands of shapes "
        "in one draw call, geometry built off the main thread, the lens, planes and meshes "
        "of the software 3D path, and color.",
    ),
    (
        "motion",
        "Motion & simulation",
        "How things move: seeded oscillators, sparse response gating, the nonlinear kit and "
        "flow fields, the forces particles compose by key (`Primitives`), the fixed-rate "
        "tick, and running systems whose STATE is the picture - a granular automaton, a "
        "flock with a spatial hash, a plate's standing waves, a water surface.",
    ),
    (
        "geometry",
        "Generative form",
        "Self-contained generators a scene composes rather than hand-models - each one "
        "samples a space of shapes from a seed and hands back plain geometry - with the "
        "procedural fields, terrain heightfields and shadowing of the 3D world, and the "
        "composed bodies. The `cattle, not pets` discipline, made into parts.",
    ),
    (
        "scene_kit",
        "Scene substrate",
        "What every scene is built on: the `GhostScene` base and its 3D sibling, the "
        "camera, framing pools, lighting, the visual layers scenes compose by key "
        "(`Layer`), and `ShowFeed` - what the show hands the parts it mounts.",
    ),
    (
        "stage",
        "Storyboards & stage",
        "A show written down, as data: the storyboard's spec and its field tables, and the "
        "Cast/Actions/Track stack that renders a described scene. See "
        "[storyboards/README.md](../storyboards/README.md) for the data spec and "
        "[stage.md](stage.md) for the fields and the actor/verb registries.",
    ),
    (
        "scenes",
        "Scenes",
        "The catalog, one scene a file. Cataloged in [scenes.md](scenes.md), each from its "
        "own doc comment.",
    ),
    (
        "agents",
        "Agents",
        "Every piece of writing and painting ghost asks an AI for: who writes "
        "(TextGen) and who paints (ImageGen), one queue for both (AgentJobs), "
        "the tools ghost serves an agent while it works (AgentTools), "
        "which Amazon Bedrock models an AWS account can call (BedrockCatalog), "
        "and how the Assistant's command-line tools are run.",
    ),
    (
        "notes",
        "Notes",
        "The note as a file: where notes live, a document kept in step with its file, the "
        "registry of what a note can carry (`Components`), the registry of the marks a "
        "script may carry (`ScriptMarks`), and where a note's cards meet without naming each "
        "other: an episode one card makes (`EpisodeFeed`) and the steps the others add to it "
        "(`EpisodeStep`).",
    ),
    (
        "ui",
        "The panel kit",
        "What every note's panel is built from, and what it asks of the window it is in: a "
        "side panel that cannot outgrow the window and its \"+\", a component's folding card "
        "in its family's color and the chips over the cards, the cards a note's components "
        "bring (built from the registry's rows, attached and detached), the Script card every "
        "note has (its editor window and highlighter), rows drawn from a table of fields, two small "
        "controls, and `Shell` - the bottom-right row, room along the bottom edge, the way "
        "back to the notes. Above `notes/` because it is a kit for a note's components.",
    ),
    (
        "voice",
        "Synthesis (voice)",
        "Text to narrated audio in two paths: ghost's own source-filter "
        "synthesizer (no models, no weights, fully inspectable, and the only "
        "path that can sing), and a small local neural voice run by a "
        "subprocess host. Shared between them: the text front end and its "
        "normalization, the threaded real-time stream and the buffer effects. "
        "Design: next/voice.md.",
    ),
    (
        "media",
        "Media",
        "What the show is carried on: the `Medium` base and its registry, each medium "
        "([media.md](media.md)), the layouts they set (comic pages, a novel, a notebook, a "
        "tablet's pages), the films and pictures they show, and where a reading is in its "
        "document.",
    ),
    (
        "show",
        "The show",
        "The player: the Director's schedule and transitions, the one transport, karaoke "
        "subtitles, the Look over the whole picture, and the cards of the show's own "
        "settings.",
    ),
    (
        "timeline",
        "The storyboard's editor",
        "The card that keeps a note's storyboard and the dock it opens: a strip of "
        "entries, a stage entry's lanes, and the ruler.",
    ),
    (
        "export",
        "Export",
        "Rendering a session to video (bake + Movie Maker, background "
        "processes) and uploading it to YouTube. Under the workspaces: a reading and a show "
        "of cards export a take and fill in an upload, and the exporter names neither.",
    ),
    (
        "reading",
        "The voice's workspaces",
        "The panels a voice runs in: the reading (script, cast, voice, stream, export), "
        "the Generative editor built on it, and the voice lab with the fishing game that "
        "breeds its voices.",
    ),
    (
        "table",
        "The set",
        "A place, seen and heard, built from a written description: the table itself "
        "(Tables), the things on it (Props), its air (Effects, and what the wind carries: "
        "Drifts), its light (Lights) and the one wind both share (Winds), its sound "
        "(Soundscape), where cards go on it, what can be done with them and how a reading "
        "says so, the faces printed on them - and the medium that puts it all on the stage "
        "(`table.gd`, a row of `Medium.REGISTRY`).",
    ),
    (
        "cards",
        "Cards",
        "A show of cards nobody writes: a show's brief, its episodes - each "
        "planned, dealt, painted and written by agents one card at a time, kept "
        "on disk step by step - and the set dresser that builds the table they are read "
        "at. The rules are every show's; the brief says what the cards are - tarot, "
        "baseball or trading cards, a card game's deck, flashcards, recipe cards - and "
        "lists them, or leaves each episode's deck to its producer. Design: next/cards.md.",
    ),
    (
        "desk",
        "The desk",
        "A study where a ghost does math, seen and heard: the ink (formulas TeX lays out, "
        "written stroke by stroke in a seeded hand from the Hershey stroke fonts), the pad, "
        "the pen that moves by itself, the instruments it reaches for - a calculator, a "
        "tablet, a screen with Lean on it - and the medium that puts them on the stage. "
        "Its room is built from the table's parts. Design: next/proof.md.",
    ),
    (
        "proof",
        "Proof",
        "A ghost doing math, made by agents: a note's problem fixed, worked at the desk with "
        "Lean - a lab notebook, checks, a proof handed in only when verified - and taught, "
        "each episode kept on disk step by step; the solver's tools, the rules each agent is "
        "told, and the card that runs it all and hands the reading its lesson. Design: "
        "next/proof.md.",
    ),
    (
        "likeness",
        "Likeness",
        "An actor played from their own footage: the library of actors, each built from their videos "
        "(a folder, or links fetched) - surveyed, grouped into sets by camera and look, the agent that "
        "audits them, a still of each set and a model of them from every video (their head's motion, "
        "their blinks, their mouths for each sound, their voice) - the card that makes one and puts "
        "them on a note's stage, and the medium that plays them reading it: the still, its head turned "
        "and its mouth and eyes drawn from their own, through one mesh over the frame. Design: "
        "next/likeness.md.",
    ),
    (
        "masking",
        "Masking",
        "The video chroma-key masking editor - a second app surface inside "
        "ghost. See [masking.md](masking.md).",
    ),
    (
        "app",
        "The shell",
        "The lifecycle around everything, and the one folder that names every other: main, "
        "the furniture every mode gets (Chrome), the notes list and a note's own panel, the "
        "phone shell, the "
        "authoring loop - the log, the feedback console and the Assistant - and the "
        "recorder of the README's animation, which drives the real app.",
    ),
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
UPWARD: List[Tuple[str, str, List[Tuple[str, str]]]] = [
]

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

# (flag, argument placeholder, description, internal). Internal flags are
# passed between ghost's own processes (exporter -> render, editor ->
# render), not meant for hand use. Verified against the source scan below.
CLI_FLAGS: List[Tuple[str, str, str, bool]] = [
    (
        "--audio",
        "<path>",
        "Load this song (`.wav` / `.mp3` / `.ogg` / `.flac`; FLAC is "
        "transcoded via ffmpeg) and start straight on it, past the notes list.",
        False,
    ),
    (
        "--scene",
        "<name|N>",
        "Pin one scene for authoring (by script-name substring or registry " "index).",
        False,
    ),
    (
        "--medium",
        "<name>",
        "What the show is carried on for this run: `full` (one scene filling "
        "the frame) or `comic` (a comic page). Overrides the remembered "
        "setting; see [media.md](media.md).",
        False,
    ),
    (
        "--filter",
        "<k=v,...>",
        "The look over the whole picture for this run - `--filter "
        "monochrome=1,static=0.3`, or `--filter none`. Overrides the remembered "
        "set; see [filters.md](filters.md).",
        False,
    ),
    (
        "--live-tap",
        "",
        "Record what the mixer actually plays - the Master bus, the last two minutes - "
        "to user://synth/live_tap.wav when ghost quits. For when what you hear and what "
        "a measurement says disagree.",
        False,
    ),
    (
        "--clock-watch",
        "",
        "Report when the show's clock stops advancing while frames keep being "
        "written - the shape a frozen recording takes. On automatically in every "
        "render; useful on a plain session because that runs at the speed of the "
        "audio rather than the encoder.",
        False,
    ),
    (
        "--until",
        "<seconds>",
        "Stop at this point on the show clock. Renders a slice instead of the "
        "whole thing, which is how a defect deep in a long export is reproduced "
        "without paying for the whole export.",
        False,
    ),
    (
        "--storyboard",
        "<name>",
        "Manual mode: play `storyboards/<name>.yaml` (or `.json`).",
        False,
    ),
    (
        "--frame",
        "landscape|portrait",
        "The show's frame for this run - 16:9 or 9:16 - over the remembered one, as `--medium` "
        "overrides the medium. A medium without a portrait frame plays landscape. Passed to an "
        "export's render, so it renders the frame the session showed.",
        False,
    ),
    (
        "--handheld",
        "",
        "Run the phone shell on the desktop: the notes list and the editor, full screen in a "
        "phone's shape, no stage, no transport, nothing downloaded (`GHOST_HANDHELD=1` does the "
        "same). A phone runs it always.",
        False,
    ),
    (
        "--note",
        "<path>",
        "Open one note, in the workspace its components name (a voice's reading, a show of "
        "cards, the note's own panel for its words or a song) - past the notes list.",
        False,
    ),
    (
        "--deps",
        "",
        "Print the environment report - what ghost has installed for itself (FFmpeg, "
        "uv, Python, each feature's environment), what it uses from the machine, "
        "versions and resolved paths, and an install hint for anything of the "
        "machine's that is missing - then exit. Exits non-zero if something a feature "
        "needs is absent. Pairs with `--headless`; the same report is the "
        "Environment panel, behind the ⚙ in the bottom-right row.",
        False,
    ),
    (
        "--provision",
        "[all|update|KEY]",
        "Install ghost's own dependencies now, printing each step, then exit: uv, "
        "FFmpeg and Python by default, every feature's environment too with `all`, one "
        "row by its key with what it needs (`mathlib` brings Lean), or bring everything "
        "installed to its newest release with `update`. The same jobs "
        "an ordinary launch runs in the background. Exits non-zero if anything asked "
        "for could not be had. Pairs with `--headless`.",
        False,
    ),
    (
        "--seed",
        "<N>",
        "Override the session seed (default derives from the audio's own "
        "content fingerprint, so the same song replays the same show).",
        False,
    ),
    (
        "--synth",
        "[text-file]",
        "Open the voice-synthesis editor: write or paste a script, sample a "
        "voice by seed; each reading renders a WAV take and plays it as a normal "
        "session (scenes react to the narration; karaoke subtitles track it).",
        False,
    ),
    (
        "--say",
        "",
        "With `--synth`: speak the loaded text immediately on boot "
        "(automation, demos, headless checks).",
        False,
    ),
    (
        "--cards",
        "",
        "Open the Cards mode: a show's brief, its episodes (planned, dealt, painted and written "
        "by agents one card at a time) and the Generative voice that reads them at the table.",
        False,
    ),
    (
        "--mask-edit",
        "<session.json>",
        "Open the Masking editor on a session (also creates one from a " "video path).",
        False,
    ),
    (
        "--mask-render",
        "<session.json>",
        "Render a Masking session to video (used with `--write-movie`).",
        True,
    ),
    (
        "--export",
        "",
        "Marks a Movie Maker render process (set by the exporter; `Boot` "
        "shrinks the window early).",
        True,
    ),
    (
        "--export-smoke",
        "",
        "Check that an exported desktop app starts and can unpack its bundled Python hosts, "
        "then exit. Used by `scripts/smoke-export.sh`.",
        True,
    ),
    (
        "--export-smoke-note",
        "PATH",
        "With `--export-smoke`: also check that this note is recognized as a Cards note.",
        True,
    ),
    (
        "--app-version",
        "",
        "Print the embedded app build version as JSON, then exit (release diagnostics).",
        True,
    ),
    (
        "--apply-update",
        "<target> <parent PID> <staged path> <sha256> <restart>",
        "Internal helper: after the parent exits, replace the portable executable with a verified update.",
        True,
    ),
    (
        "--update-smoke-hold",
        "",
        "Keep the exported app running briefly while the updater's replacement path is tested.",
        True,
    ),
    (
        "--synth-autopilot",
        "",
        "With `--export`: open the Synthesis panel over the take and let the "
        "fishing game play itself (random Throw/Pull/reel/hold-or-fold), so the "
        "UI is recorded into the video. Generates no audio and persists nothing "
        "(set by the exporter's 'Automate the Synthesis game' toggle).",
        True,
    ),
    (
        "--use-bake",
        "",
        "Drive `Spectrum` from the song's cached bake instead of the live " "analyzer.",
        True,
    ),
    (
        "--bake-file",
        "<path>",
        "Explicit spectrum-bake cache for a render (implies `--use-bake`).",
        True,
    ),
    (
        "--showcase-now",
        "",
        "Record the README's animation (`docs/showcase.webp`) now, stale or "
        "not, and quit; pairs with `--headless`. A development launch records "
        "it by itself when what it shows has changed (`src/app/showcase.gd`).",
        False,
    ),
    (
        "--showcase",
        "<work dir>",
        "Marks the README animation's Movie Maker recording (set by "
        "`Showcase`): plays the showcase note read-only and quits.",
        True,
    ),
    ("--bake-song", "<path>", "Export subprocess: the song to analyze.", True),
    ("--bake-out", "<path>", "Export subprocess: where to write the bake cache.", True),
]

# Flags that belong to the Godot engine itself (or are argument separators),
# excluded from the drift check.
ENGINE_FLAGS = {
    "--headless",
    "--log-file",
    # the window arguments a launch can give, which Boot.fit_window then leaves alone
    "--resolution",
    "--position",
    "--fullscreen",
    "--maximized",
    "--path",
    "--editor",
    "--quit",
    "--script",
    "--write-movie",
    "--fixed-fps",
    "--",
    # claude / codex arguments (assistant_backends' feedback dispatch, image_gen's
    # illustration jobs), not ghost flags
    "--dangerously-bypass-approvals-and-sandbox",
    "--dangerously-skip-permissions",
    "--json",
    "--output-format",
    "--resume",
    "--skip-git-repo-check",
    "--verbose",
    # ...and TextGen's bare writers (the Cards mode's agents): no tools, no project, no session
    "--safe-mode",
    "--tools",
    "--system-prompt-file",
    "--no-session-persistence",
    "--input-format",
    "--include-partial-messages",
    "--effort",
    "--ephemeral",
    # ...and a writer working with ghost's own tools (AgentTools): their config, nothing else's
    "--mcp-config",
    "--strict-mcp-config",
    "--allowedTools",
    "--setting-sources",
    # the Grok Build CLI's (TextGen.Grok and ImageGen.Grok), not ghost flags
    "--agent",
    "--prompt-file",
    "--verbatim",
    "--disallowed-tools",
    "--no-memory",
    "--no-subagents",
    "--disable-web-search",
    "--cwd",
    "--allow",
    "--always-approve",
    # the AWS CLI's (bedrock_catalog.gd and the Bedrock writer and painter), not ghost flags
    "--region",
    "--output",
    "--no-cli-pager",
    "--cli-input-json",
    "--cli-binary-format",
    "--cli-read-timeout",
    "--model-id",
    "--body",
    "--content-type",
    "--accept",
    # yt-dlp/pip arguments (mask_editor's URL import subprocess), not ghost flags
    "--newline",
    "--no-playlist",
    "--restrict-filenames",
    "--upgrade",
    "--throttled-rate",
    "--concurrent-fragments",
    "--js-runtimes",
    # hosts/face/face_track.py's and pose_track.py's own interfaces (mask_editor
    # spawns them for the clown's landmark pre-pass and the umbra's body pre-pass)
    # - arguments to a subprocess, not ghost flags.
    "--video",
    "--out",
    "--model",
    "--rate",
    "--progress",
    "--mask-w",
    "--mask-h",
    "--start",
    "--duration",
    "--background",
    # hosts/face/actor.py's interface (the Likeness's ActorBuilder runs each step of an actor
    # with it) - arguments to a subprocess.
    "--ffmpeg",
    "--face-model",
    "--pose-model",
    "--interval",
    "--survey",
    "--min-shot",
    "--spec",
    "--sheets",
    "--threshold",
    "--stills",
    # hosts/avatar/rig.py's (the Actor card's Head rig and Face rig steps): arguments to a subprocess.
    "--frames",
    "--poses",
    "--shared",
    # yt-dlp's, as the Actor card lists and fetches a link's videos and captions.
    "--flat-playlist",
    "--no-warnings",
    "--no-overwrites",
    "--write-auto-subs",
    "--sub-langs",
    "--sub-format",
    "--write-info-json",
    "--skip-download",
    "--merge-output-format",
    "--download-archive",
    "--socket-timeout",
    # setpriv's interface (subprocess.gd binds every child's lifetime to ghost's with it),
    # an argument to a subprocess, not a ghost flag.
    "--pdeathsig",
    # fallocate's interface (exporter.gd releases the scratch AVI behind its encoder with it).
    "--punch-hole",
    "--offset",
    "--length",
    # What deps.gd ASKS other programs, to read their versions out - every one of
    # these is an argument handed to somebody else's binary, not a ghost flag.
    "--version",
    # uv's interface (provisioner.gd installs Python and builds every environment with it),
    # arguments to a subprocess, not ghost flags.
    "--cache-dir",
    "--no-config",
    "--install-dir",
    "--no-bin",
    "--no-registry",
    "--python",
    "--clear",
    "--no-build",
    "--no-python-downloads",
}

# Top-level entries for the README LAYOUT block and docs/index.md, in that order.
# (name, description). A runtime folder (git-ignored, so absent from a clone) says so in its
# description and is listed without a link.
TOP_LEVEL: List[Tuple[str, str]] = [
    (
        "project.godot",
        "Godot 4.7 project; autoloads `Settings`, `Boot`, `Spectrum`, `Director`, "
        "`Provisioner`; `scenes/main.tscn` is the entry scene.",
    ),
    ("scenes/", "The Godot entry scene (`main.tscn`). Everything else is code-built."),
    (
        "src/",
        "All GDScript, in one level of folders that are a stack: a script names its own "
        "folder and the ones below. [docs/structure.md](docs/structure.md) is the stack; "
        "[docs/index.md](docs/index.md) has every script.",
    ),
    (
        "src/scenes/",
        "The visualizer scene catalog - one class per scene. See "
        "[docs/scenes.md](docs/scenes.md).",
    ),
    (
        "src/media/",
        "The media - what the show is carried on. See [docs/media.md](docs/media.md).",
    ),
    (
        "shaders/",
        "The GPU shaders: the Look, every Masking effect, the card table and a few scenes.",
    ),
    (
        "storyboards/",
        "Manual-mode scene scores (YAML; JSON accepted). "
        "[storyboards/README.md](storyboards/README.md) is the data spec.",
    ),
    (
        "data/",
        "Data the code reads - pronunciation (CMUdict, `english.yml`), the LibriTTS speaker "
        "table - each license beside its file.",
    ),
    ("fonts/", "Faces the media draw with: the notebook's handwriting and the card table's lettering."),
    (
        "hosts/",
        "The Python hosts ghost spawns, each in an environment of its own the Provisioner builds "
        "(`src/platform/deps.gd`): `voice/` the neural voice, `face/` Masking's face and body pre-passes, "
        "`capture/` the tablet's page capture. Kept out of the exported .pck.",
    ),
    (
        "scripts/",
        "Build and check scripts: `scripts/check.sh` runs every gate (`--gpu` adds the ones "
        "that need a real renderer), `scripts/build.sh` exports a target into `dist/`.",
    ),
    (
        "tests/",
        "The gates (`*_check.gd`) and probes (`*_probe.gd`), in folders that mirror `src/` "
        "(a gate lives with what it holds), and their runners and fixtures at the top; "
        "`scripts/check.sh` runs them all, and `--for` the ones a change can reach.",
    ),
    (
        "docs/",
        "Generated documentation. Regenerate with `python docs.py`; do not edit by hand.",
    ),
    (
        "next/",
        "Design notes and plans, one per subsystem: [notes.md](next/notes.md) is the notes "
        "refactor, step by step, and [roadmap.md](next/roadmap.md) is what comes next.",
    ),
    ("reference/", "Reference imagery scenes were prototyped from."),
    (
        "masks/",
        "Saved Masking sessions, one directory per source video (runtime, git-ignored).",
    ),
    (
        "feedback/",
        "Feedback console output: `NNNN.json` + `NNNN.png` per report (runtime, git-ignored).",
    ),
    ("dist/", "Build artifacts and the gates' logs (runtime, git-ignored)."),
    (
        "audio/",
        "Drop a `song.wav` here to bundle one (runtime, git-ignored); or use `--audio`.",
    ),
]

# Standalone pages, documented outside the registry pages: (title, repo-relative path, one
# line). One source for docs/index.md and the README's SUBSYSTEMS block.
SUBSYSTEMS: List[Tuple[str, str, str]] = [
    (
        "How the show is made",
        "docs/architecture.md",
        "from the audio to the screen or a video file: the signal path, composition, "
        "drawing, scheduling, rendering - and adding a scene.",
    ),
    (
        "The environment",
        "docs/environment.md",
        "what Ghost Notes installs itself, and the few programs that stay the machine's.",
    ),
    (
        "The structure",
        "docs/structure.md",
        "`src/` as a stack of folders: what each is, what it names, and what still points up.",
    ),
    ("CLI flags", "docs/cli.md", "every command-line flag."),
    ("Storyboards", "storyboards/README.md", "the data spec a note's storyboard is written in."),
]

AUTOGEN_HEADER = "<!-- AUTOGENERATED by docs.py - do not edit by hand -->"


# ---------------------------------------------------------------------------
# GDScript parsing
# ---------------------------------------------------------------------------


def _script_path(stem: str) -> Path:
    """Where a script lives, by its file name alone: its folder is looked up, never written
    here, so a script that moves folders needs no edit in this file. The scene catalog is left
    out of the search - `glyphs` and `terrain` are a generator and a scene both - and a scene
    is read from `SCENES_DIR` by whoever wants one."""
    found = [p for p in sorted(SCRIPTS.glob(f"*/{stem}.gd")) if p.parent != SCENES_DIR]
    if len(found) != 1:
        raise SystemExit(
            f"[ghost-docs] docs.py reads src/*/{stem}.gd and found {len(found)}: "
            + (", ".join(p.relative_to(ROOT).as_posix() for p in found) or "none")
        )
    return found[0]


class Script:
    def __init__(self, path: Path) -> None:
        self.path = path
        self.name = path.stem
        self.text = path.read_text()
        self.class_name, self.extends, self.doc = _parse_header(self.text)

    @property
    def rel(self) -> str:
        return self.path.relative_to(ROOT).as_posix()


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


def _md(text: str) -> str:
    """GDScript doc markup -> markdown: `[param x]` -> `x`, `[Class]` -> `Class`.

    The tag list is not decoration: `[constant X]` was leaking into docs/scenes.md
    verbatim, eighteen times, because only `[param ]` was handled."""
    text = re.sub(r"\[code\](.*?)\[/code\]", r"`\1`", text, flags=re.S)
    text = re.sub(
        r"\[(?:param|constant|method|member|signal|enum|annotation) " r"([\w.]+)\]",
        r"`\1`",
        text,
    )
    return re.sub(r"\[([A-Z]\w*(?:\.\w+)*)\]", r"`\1`", text)


def _paragraphs(doc: List[str]) -> List[str]:
    out: List[str] = []
    cur: List[str] = []
    for line in doc:
        if line == "":
            if cur:
                out.append(" ".join(cur))
                cur = []
        else:
            cur.append(line)
    if cur:
        out.append(" ".join(cur))
    return out


def _one_liner(doc: List[str], strip_name: str = "") -> str:
    """First doc paragraph as a single line, optional `Name -` prefix stripped."""
    paras = _paragraphs(doc)
    if not paras:
        return ""
    line = paras[0]
    if strip_name:
        line = re.sub(
            rf"^{re.escape(strip_name)}\s+-\s+", "", line, flags=re.IGNORECASE
        )
    if len(line) > 300:
        line = line[:300].rsplit(" ", 1)[0] + " ..."
    return _md(line)


def _full_doc(doc: List[str]) -> str:
    return "\n\n".join(_md(p) for p in _paragraphs(doc))


def _line_of(text: str, pattern: str) -> Optional[int]:
    m = re.search(pattern, text, re.M)
    if not m:
        return None
    return text.count("\n", 0, m.start()) + 1


def _parse_registry_dict(
    text: str, const_name: str = "REGISTRY"
) -> List[Tuple[str, str]]:
    """Parse `const NAME := { "key": Value, ... }` into (key, value) pairs."""
    m = re.search(rf"const {const_name} :?= \{{(.*?)\n\}}", text, re.S)
    if not m:
        return []
    return re.findall(r'"(\w+)":\s*"?(\w+)"?', m.group(1))


def _inner_class_docs(text: str) -> Dict[str, Tuple[str, int]]:
    """Map inner class name -> (doc text, 1-based line). The doc is the
    contiguous comment block (`#` or `##`) directly above the declaration,
    with decorative ruler lines dropped."""
    out: Dict[str, Tuple[str, int]] = {}
    lines = text.splitlines()
    for i, line in enumerate(lines):
        m = re.match(r"class (\w+)", line)
        if not m:
            continue
        doc: List[str] = []
        j = i - 1
        while j >= 0 and lines[j].strip().startswith("#"):
            stripped = lines[j].strip().lstrip("#").strip()
            if not re.fullmatch(r"-{3,}", stripped):
                doc.insert(0, stripped)
            j -= 1
        paras = _paragraphs(doc)
        out[m.group(1)] = ("\n\n".join(_md(p) for p in paras), i + 1)
    return out


def _source_link(rel: str, line: Optional[int] = None) -> str:
    """Markdown source link from docs/ to a repo file (with #L anchor)."""
    anchor = f"#L{line}" if line else ""
    label = f"{rel}:{line}" if line else rel
    return f"[{label}](../{rel}{anchor})"


# ---------------------------------------------------------------------------
# Scene catalog
# ---------------------------------------------------------------------------


class SceneInfo:
    def __init__(self, script: Script) -> None:
        self.script = script
        t = script.text
        self.behaviors: List[str] = []
        self.group = ""
        kind = re.search(r'render_kind\s*=\s*"(\w+)"', t)
        self.render_kind = (
            kind.group(1)
            if kind
            else ("scene3d" if script.extends == "Scene3D" else "canvas")
        )
        self.oneshot = 'lifecycle = "oneshot"' in t
        self.morph_in = _first(t, r'morph_in\s*=\s*"(\w+)"')
        self.morph_out = _first(t, r'morph_out\s*=\s*"(\w+)"')
        self.layers = sorted(set(re.findall(r'add_layer\(\s*"(\w+)"', t)))


def _first(text: str, pattern: str) -> Optional[str]:
    m = re.search(pattern, text)
    return m.group(1) if m else None


def _parse_scene_roster(director_text: str) -> List[Tuple[str, str, str]]:
    """Parse SceneRoster.SCENES into (scene name, behavior, group comment)."""
    m = re.search(r"const SCENES :?= \[(.*?)\n\]", director_text, re.S)
    if not m:
        warn("could not parse SceneRoster.SCENES")
        return []
    entries: List[Tuple[str, str, str]] = []
    group = ""
    for line in m.group(1).splitlines():
        s = line.strip()
        if s.startswith("#"):
            group = s.lstrip("# ").strip()
            continue
        pm = re.search(r'scenes/(\w+)\.gd"\).*?"behavior":\s*"(\w+)"', s)
        if pm:
            entries.append((pm.group(1), pm.group(2), group))
    return entries


SCENE_BASES = {"GhostScene", "Scene3D"}


def _collect_scenes() -> Tuple[Dict[str, SceneInfo], List[str]]:
    """All scenes on disk, annotated with their Director registration.
    Returns (name -> SceneInfo, ordered group labels)."""
    # A scene is a script that extends a scene base; the roster beside them is a registry, not one.
    scenes = {
        p.stem: SceneInfo(s)
        for p in sorted(SCENES_DIR.glob("*.gd"))
        for s in [Script(p)]
        if s.extends in SCENE_BASES
    }
    roster = _parse_scene_roster((SCENES_DIR / "roster.gd").read_text())
    groups: List[str] = []
    for name, behavior, group in roster:
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
    intro = _md(group) if group.rstrip(".") != head else ""
    return head, intro


def _scene_flags(info: SceneInfo) -> str:
    bits = [info.render_kind]
    if info.behaviors:
        bits.extend(sorted(set(info.behaviors)))
    if info.oneshot:
        bits.append("oneshot seeds")
    return ", ".join(bits)


def _render_scenes_doc(scenes: Dict[str, SceneInfo], groups: List[str]) -> str:
    lines = [
        AUTOGEN_HEADER,
        "# Scene catalog",
        "",
        f"{len(scenes)} scenes under `src/scenes/`, one class per file, "
        "each documented by its own leading doc comment (reproduced here). "
        "A scene is a seeded **definition** (`build_params(rng)`) modulated "
        "by audio (`update`) and drawn through a view; registration in "
        "`SceneRoster.SCENES` pairs it with one or more **behaviors** "
        "(`static` / `drift` / `fluid`).",
        "",
        "Legend per entry: render kind, registered behaviors, lifecycle. "
        "`morph in/out` are the typed geometries a scene can continuously "
        "hand over across a cut; `layers` are the [Layer](layers.md) "
        "components it composes.",
        "",
    ]
    ordered = [g for g in groups]
    by_group: Dict[str, List[str]] = {g: [] for g in ordered}
    unregistered: List[str] = []
    for name in sorted(scenes):
        info = scenes[name]
        if not info.behaviors:
            unregistered.append(name)
        else:
            by_group.setdefault(info.group, []).append(name)

    for group in ordered:
        names = by_group.get(group, [])
        if not names:
            continue
        header, intro = _split_group(group)
        lines.extend([f"## {header}", ""])
        if intro:
            lines.extend([intro, ""])
        for name in names:
            lines.extend(_render_scene_entry(name, scenes[name]))
    if unregistered:
        lines.extend(
            [
                "## On disk but not in the auto rotation",
                "",
                "Present under `src/scenes/` but not registered in "
                "`SceneRoster.SCENES` - reachable only by storyboard (`stage`), "
                "`--scene` pin, or not reachable at all. If one of these "
                "should be in the rotation, register it; if it is retired, "
                "delete it.",
                "",
            ]
        )
        for name in unregistered:
            lines.extend(_render_scene_entry(name, scenes[name]))
    return "\n".join(lines).rstrip() + "\n"


def _render_scene_entry(name: str, info: SceneInfo) -> List[str]:
    s = info.script
    out = [f"### `{name}` ({_scene_flags(info)})", ""]
    body = _full_doc(s.doc)
    if body:
        out.extend([body, ""])
    else:
        warn(f"scenes/{name}.gd has no doc comment")
    facts = []
    if info.morph_in:
        facts.append(f"morph in: `{info.morph_in}`")
    if info.morph_out:
        facts.append(f"morph out: `{info.morph_out}`")
    if info.layers:
        facts.append("layers: " + ", ".join(f"`{k}`" for k in info.layers))
    if facts:
        out.extend([" · ".join(facts), ""])
    text = (ROOT / s.rel).read_text()
    fields = _rows(text, "FIELDS")
    if fields:
        # WHAT AN ENTRY CAN TELL IT (GhostScene.choice, number): its settings, each the seed's until told
        out.extend(["An entry can tell it, under `set` (unset, the seed draws one; a number may be told as a "
                    "narrower range, `[lo, hi]`):", "",
                    "| Setting | Options | What it sets |", "| --- | --- | --- |"])
        for k, row in fields.items():
            if row.get("type") == "num":
                lo, hi = (row.get("range") or [None, None])[:2]
                out.append(f"| `{k}` {row.get('label', '')} | `{lo}` to `{hi}` | {_md(str(row.get('blurb', '')))} |")
                continue
            opts = _table_options(text, str(row.get("options", "")))
            names = _table_options(text, str(row.get("names", ""))) if row.get("names") else []
            shown = []
            for o in opts:
                said = str(names[int(o)]) if names and isinstance(o, int) and int(o) < len(names) else str(o)
                if said not in shown:
                    shown.append(said)
            out.append(f"| `{k}` {row.get('label', '')} | {', '.join(f'`{o}`' for o in shown)} | {_md(str(row.get('blurb', '')))} |")
        out.append("")
    out.extend([f"Source: {_source_link(s.rel)} (extends `{s.extends}`)", ""])
    return out


# ---------------------------------------------------------------------------
# Registry pages (layers, forces, stage)
# ---------------------------------------------------------------------------


def _render_registry_page(
    title: str,
    slug_intro: str,
    script: Script,
    pairs: List[Tuple[str, str]],
) -> str:
    inner = _inner_class_docs(script.text)
    lines = [
        AUTOGEN_HEADER,
        f"# {title}",
        "",
        slug_intro,
        "",
        _full_doc(script.doc),
        "",
        f"Registry: `{script.class_name}.REGISTRY` in {_source_link(script.rel)} "
        f"({len(pairs)} entries)",
        "",
    ]
    bodies = _class_bodies(script.text)
    common = {}
    for body in bodies.values():
        common = common or _rows(body, "COMMON")
    if common:
        lines.extend(["Every entry also takes:", ""] + _field_table(common) + [""])
    for key, cls in pairs:
        doc, line = inner.get(cls, ("", None))
        lines.append(f"## `{key}` - {cls}")
        lines.append("")
        if doc:
            lines.extend([doc, ""])
        else:
            warn(f"{script.rel}: class {cls} (registry key '{key}') has no doc comment")
        fields = _rows(bodies.get(cls, ""), "FIELDS")
        if fields:
            lines.extend(_field_table(fields) + [""])
        lines.append(f"Source: {_source_link(script.rel, line)}")
        lines.append("")
    return "\n".join(lines).rstrip() + "\n"


def _field_table(fields: Dict[str, Dict[str, Any]]) -> List[str]:
    """A class's FIELDS as a table: the setting, its default (unset: drawn or worked out, as it
    says), and what it does."""
    out = ["| Setting | Default | What it does |", "| --- | --- | --- |"]
    for k, row in fields.items():
        d = row.get("default")
        shown = "unset" if d is None else ("on" if d is True else "off" if d is False else f"`{d}`")
        out.append(f"| `{k}` {row.get('label', '')} | {shown} | {_md(str(row.get('blurb', '')))} |")
    return out


def _render_media_doc(base: Script) -> str:
    """docs/media.md, from Medium.REGISTRY and each medium script's own header.

    Not _render_registry_page: that renderer expects a registry whose values are
    INNER CLASSES of the registry script (Layer, Primitives, Cast all work that
    way). A medium is a whole file, because it owns render targets and a draw -
    so the values here are script paths and each entry's doc is that file's own
    class header."""
    pairs = _media_pairs(base)
    if not pairs:
        warn("could not parse Medium.REGISTRY")
    rows = _rows(base.text, "REGISTRY")
    labels = {k: str(r.get("label", k)) for k, r in rows.items()}
    blurbs = {k: str(r.get("blurb", "")) for k, r in rows.items()}
    lines = [
        AUTOGEN_HEADER,
        "# Media: what carries the show",
        "",
        "The presentation axis - what the show is drawn ON, as opposed to what "
        "drives it. Independent of the modes, so every mode gets every medium.",
        "",
        _full_doc(base.doc),
        "",
        f"Registry: `Medium.REGISTRY` in {_source_link(base.rel)} "
        f"({len(pairs)} entries). Select with `--medium NAME`, or the Medium "
        "picker in the Generative panel (persisted to `user://ghost.cfg`, "
        "`[director] medium`).",
        "",
    ]
    for key, rel in pairs:
        path = ROOT / rel
        if not path.exists():
            warn(f"Medium.REGISTRY registers {rel} which does not exist")
            continue
        sc = Script(path)
        lines.append(f"## `{key}` - {labels.get(key, key)}")
        lines.append("")
        if blurbs.get(key):
            lines.extend([f"_{blurbs[key]}_", ""])
        if sc.doc:
            lines.extend([_full_doc(sc.doc), ""])
        else:
            warn(f"{sc.rel}: medium '{key}' has no doc comment")
        lines.append(f"Source: {_source_link(sc.rel)}")
        lines.append("")
    # The folder also holds what the media set and show (layouts, films, pictures): only a
    # script that IS a medium - one extending Medium or a registered medium - must be a row.
    registered = [rel for _k, rel in pairs]
    medium_classes = {"Medium"} | {
        Script(ROOT / rel).class_name for rel in registered if (ROOT / rel).exists()
    }
    for path in sorted(SCRIPTS.glob("*/*.gd")):
        rel = path.relative_to(ROOT).as_posix()
        if rel in registered or path.stem == "medium" or path.parent == SCENES_DIR:
            continue
        if Script(path).extends in medium_classes:
            warn(f"{rel} is a medium not registered in Medium.REGISTRY - it can never be selected")
    return "\n".join(lines).rstrip() + "\n"


def _render_filters_doc(base: Script) -> str:
    """docs/filters.md, from Filters.REGISTRY + LABELS/BLURBS and the shader's own header.

    Not _render_registry_page: a filter is neither an inner class nor a script, it is a
    uniform and a block of GLSL - so the per-entry text comes from each row's blurb and the how
    comes from the shader file's header, which is where the pipeline is written down.

    It also CHECKS the pair, which is this table's own failure mode: a registry key whose
    uniform the shader does not declare ships as a control that does nothing, because
    `set_shader_parameter` on an unknown name is silent. tests/show/stage_filter_check.gd
    asserts the same thing at runtime; this is so a docs run says it too."""
    rows = _rows(base.text, "REGISTRY")
    pairs = _filter_pairs(base)
    if not pairs:
        warn("could not parse Filters.REGISTRY")
    labels = {k: str(r.get("label", k)) for k, r in rows.items()}
    blurbs = {k: str(r.get("blurb", "")) for k, r in rows.items()}
    defaults = {k: r["default"] for k, r in rows.items() if "default" in r}
    shader_path = ROOT / "shaders" / "stage_filter.gdshader"
    shader_src = shader_path.read_text() if shader_path.exists() else ""
    if not shader_src:
        warn("shaders/stage_filter.gdshader is missing - the filters cannot render")
    lines = [
        AUTOGEN_HEADER,
        "# Filters: the look over the whole picture",
        "",
        "A post-process applied to the finished frame, after every scene has drawn "
        "and under everything on a CanvasLayer - so the show is filtered and the "
        "subtitles and panels are not. Filters COMBINE: each has its own 0..1 dial "
        "and they are all applied, in one pass, in the order below.",
        "",
        _full_doc(base.doc),
        "",
        f"Registry: `Filters.REGISTRY` in {_source_link(base.rel)} "
        f"({len(pairs)} entries), rendered by "
        f"{_source_link('shaders/stage_filter.gdshader')}. Select with "
        "`--filter key=amount,...` (or `--filter none`), or the Look rows in the "
        "Generative panel (persisted to `user://ghost.cfg`, `[director] filters`).",
        "",
        "| # | Key | Name | Uniform | Default |",
        "| - | --- | ---- | ------- | ------- |",
    ]
    for i, (key, uniform) in enumerate(pairs, start=1):
        lines.append(
            f"| {i} | `{key}` | {labels.get(key, key)} | `{uniform}` | "
            f"{defaults.get(key, '?')} |"
        )
    lines.append("")
    for key, uniform in pairs:
        if f"uniform float {uniform}" not in shader_src:
            warn(
                f"Filters.REGISTRY maps '{key}' to {uniform}, which "
                "shaders/stage_filter.gdshader does not declare - the control is a no-op"
            )
        for field in ("label", "blurb", "default"):
            if field not in rows.get(key, {}):
                warn(f"Filters.REGISTRY's row '{key}' has no `{field}`")
        lines.append(f"## `{key}` - {labels.get(key, key)}")
        lines.append("")
        if blurbs.get(key):
            lines.extend([_md(blurbs[key]), ""])
        lines.append(
            f"Uniform `{uniform}`, default {defaults.get(key, '?')} when first "
            "switched on."
        )
        lines.append("")
    for m in re.finditer(r"uniform float (u_\w+)", shader_src):
        if m.group(1) not in [u for _k, u in pairs]:
            warn(
                f"shaders/stage_filter.gdshader declares {m.group(1)}, which no "
                "Filters.REGISTRY entry drives - it can never be set"
            )
    return "\n".join(lines).rstrip() + "\n"


def _const_block(text: str, name: str) -> str:
    m = re.search(rf"const {name} :?= \{{(.*?)\n\}}", text, re.S)
    return m.group(1) if m else ""


def _rows(text: str, name: str) -> Dict[str, Dict[str, Any]]:
    """A registry of ROWS - `const NAME := {"key": {"label": ..., "about": ..., ...}}`, the one shape
    ghost's registries share (next/structure.md, step 6) - read as Python data. GDScript's literals
    are Python's but for `true` / `false` / `null`, `&"name"` and a bare name in a value's place (an
    inner class, a constant), which comes back as its name, a string. Comments are dropped."""
    m = re.search(rf"^const {name}\b[^=\n]*:?=\s*\{{", text, re.M)
    if not m:
        return {}
    i, depth, quote = m.end(), 1, None
    while depth and i < len(text):
        c = text[i]
        if quote:
            if c == "\\":
                i += 1
            elif c == quote:
                quote = None
        elif c in "\"'":
            quote = c
        elif c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
        i += 1
    body = text[m.end() - 1 : i]
    lines = []
    for line in body.split("\n"):
        kept, q = [], None
        for j, c in enumerate(line):
            if q:
                kept.append(c)
                if c == q and line[j - 1] != "\\":
                    q = None
            elif c in "\"'":
                q = c
                kept.append(c)
            elif c == "#":
                break
            else:
                kept.append(c)
        lines.append("".join(kept))
    src = re.sub(r'[&^]"', '"', "\n".join(lines))
    # outside the string literals only: GDScript's words for Python's, and a bare name as its name
    words = {"true": "True", "false": "False", "null": "None"}
    parts = re.split(r'("(?:[^"\\\n]|\\.)*")', src)
    for k in range(0, len(parts), 2):
        seg = re.sub(r"\b(true|false|null)\b", lambda mm: words[mm.group(1)], parts[k])
        parts[k] = re.sub(
            r"(?<=[:\[,])(\s*)([A-Za-z_][\w.]*)(?=\s*[,\]}])",
            lambda mm: mm.group(0) if mm.group(2) in ("True", "False", "None") else f'{mm.group(1)}"{mm.group(2)}"',
            seg,
        )
    return ast.literal_eval("".join(parts))


def _gd_string(lit: str) -> str:
    """A GDScript string literal's value (the escapes the registries use)."""
    return (
        lit.encode("utf-8").decode("unicode_escape").encode("latin-1").decode("utf-8")
    )


def _render_script_doc(marks: Script) -> str:
    """docs/script.md, from ScriptMarks.REGISTRY + GROUPS: every authoring mark a script
    may carry, as the editor's palette offers them."""
    groups = re.findall(
        r'"(\w+)":\s*\{"label":\s*"([^"]*)"', _const_block(marks.text, "GROUPS")
    )
    entries = _script_entries(marks)
    if not groups or not entries:
        warn("could not parse ScriptMarks.REGISTRY / GROUPS")
    str_field = r'"{}":\s*"((?:[^"\\]|\\.)*)"'
    rows = []
    for key, body in entries:
        f = {}
        for name in ("label", "group", "blurb", "before", "fill", "after"):
            m = re.search(str_field.format(name), body)
            f[name] = _gd_string(m.group(1)) if m else ""
            if not m and name in ("label", "group", "blurb"):
                warn(f"ScriptMarks.REGISTRY['{key}'] has no {name}")
        modes = re.search(r'"modes":\s*\[([^\]]*)\]', body)
        f["modes"] = re.findall(r'"(\w+)"', modes.group(1)) if modes else []
        # what the mark does in a panel where that differs: {"cards": "..."}
        own = re.search(r'"blurbs":\s*\{(.*)\},?\s*$', body, re.M)
        f["blurbs"] = (
            {
                m: _gd_string(t)
                for m, t in re.findall(r'"(\w+)":\s*"((?:[^"\\]|\\.)*)"', own.group(1))
            }
            if own
            else {}
        )
        rows.append((key, f))
    lines = [
        AUTOGEN_HEADER,
        "# Writing a script",
        "",
        "Every mark a Generative or Synthesis script, or a Cards brief, may carry - "
        "the list the script editor's palette (**Edit** on the panel) is built "
        "from, and the patterns it highlights with. A script is Markdown; "
        "YAML frontmatter at the top is the panel's and never shown in the "
        "editor or spoken. A Cards brief is handed to the show's agents rather "
        "than read aloud, so a mark offered there says what it does in a brief.",
        "",
        _full_doc(marks.doc),
        "",
        f"Registry: `ScriptMarks.REGISTRY` in {_source_link(marks.rel)} "
        f"({len(rows)} entries). Each one is proven against the parser that "
        "reads it by `tests/notes/script_marks_check.gd`.",
        "",
    ]
    for gkey, glabel in groups:
        mine = [(k, f) for k, f in rows if f["group"] == gkey]
        if not mine:
            continue
        lines.extend(
            [
                f"## {glabel}",
                "",
                "| Mark | Example | Panels | What it does |",
                "|---|---|---|---|",
            ]
        )
        for k, f in mine:
            ex = (f["before"] + f["fill"] + f["after"]).strip().replace("|", "\\|")
            panels = ", ".join(m.capitalize() for m in f["modes"])
            does = f["blurb"]
            for m, text in f["blurbs"].items():
                does += f" **In a {m.capitalize()} brief:** {text}"
            lines.append(f"| {f['label']} | `{ex}` | {panels} | {does} |")
        lines.append("")
    for k, f in rows:
        if f["group"] not in [g for g, _ in groups]:
            warn(f"ScriptMarks.REGISTRY['{k}'] names unknown group '{f['group']}'")
    return "\n".join(lines).rstrip() + "\n"


def _gd_groups(text: str, const: str) -> List[Tuple[str, List[Tuple[str, str]]]]:
    """`const NAME := {"owner": {"field": {...}, ...}, ...}` as (owner, [(field, body)]): a table
    of field tables, each owner closed by a brace on a line of its own."""
    block = _const_block(text, const) + "\n"
    out = []
    for owner, body in re.findall(r'\n\t"(\w+)":\s*\{\n(.*?)\n\t\},', block, re.S):
        fields = re.findall(r'\t\t"(\w+)":\s*\{(.*?)\},[ \t]*(?=\n|$)', body + "\n", re.S)
        out.append((owner, fields))
    return out


def _field_rows(fields: List[Tuple[str, str]]) -> List[str]:
    """A fields table's rows: key, what the editor calls it, its type, and its sentence."""
    lines = ["| Key | In the editor | Type | What it is |", "| --- | --- | --- | --- |"]
    for key, body in fields:
        blurb = _md(_gd_text(body, "blurb")).replace("|", "\\|")
        kind = _gd_text(body, "type")
        opts = [o for o in _gd_list(body, "options") if o]
        if opts:
            kind += ": " + ", ".join(f"`{o}`" for o in opts)
        lines.append(f"| `{key}` | {_gd_text(body, 'label')} | {kind} | {blurb} |")
    return lines


def _render_stage_doc(cast: Script, actions: Script, track: Script, board: Script) -> str:
    action_pairs = _parse_registry_dict(actions.text)
    cast_pairs = _parse_registry_dict(cast.text)
    cast_inner = _inner_class_docs(cast.text)
    action_inner = _inner_class_docs(actions.text)
    lines = [
        AUTOGEN_HEADER,
        "# Stage: actors and verbs",
        "",
        "The data-driven scene stack behind storyboard `stage` entries: a "
        "**Cast** of actors, **Actions** verbs applied to them on a "
        "**Track** timeline. The storyboard file format itself is specified "
        "in [storyboards/README.md](../storyboards/README.md).",
        "",
        "## Fields",
        "",
        "What a storyboard can say, read from the tables its editor builds its rows from "
        f"(`Storyboard.BOARD` and its siblings in {_source_link(board.rel)}): a field in a "
        "table is a control in the editor. A `num` is a number or a sampled `[lo, hi]` "
        "range; a key left out is its default.",
        "",
    ]
    for title, const in (
        ("The storyboard", "BOARD"),
        ("An entry", "ENTRY"),
        ("How long an entry stays", "TIMING_FIELDS"),
        ("A stage entry", "STAGE"),
        ("Its camera", "CAMERA"),
        ("An actor", "ACTOR"),
        ("A span", "SPAN"),
    ):
        fields = _gd_entries(board.text, const)
        if not fields:
            warn(f"could not parse Storyboard.{const}")
        lines.extend([f"### {title}", ""] + _field_rows(fields) + [""])
    cast_params = dict(_gd_groups(cast.text, "PARAMS"))
    action_args = dict(_gd_groups(actions.text, "ARGS"))
    if not cast_params or not action_args:
        warn("could not parse Cast.PARAMS or Actions.ARGS")
    lines += [
        "## Cast (actor registry)",
        "",
        _full_doc(cast.doc),
        "",
        f"Registry: `Cast.REGISTRY` in {_source_link(cast.rel)} "
        f"({len(cast_pairs)} kinds)",
        "",
    ]
    for kind, _ in cast_pairs:
        cls = f"{kind.capitalize()}Actor"
        doc, line = cast_inner.get(cls, ("", None))
        lines.append(f"### `{kind}` - {cls}")
        lines.append("")
        if doc:
            lines.extend([doc, ""])
        if cast_params.get(kind):
            lines.extend(_field_rows(cast_params[kind]) + [""])
        lines.extend([f"Source: {_source_link(cast.rel, line)}", ""])
    lines.extend(
        [
            "## Actions (verb registry)",
            "",
            _full_doc(actions.doc),
            "",
            f"Registry: `Actions.REGISTRY` in {_source_link(actions.rel)} "
            f"({len(action_pairs)} verbs)",
            "",
        ]
    )
    for key, cls in action_pairs:
        doc, line = action_inner.get(cls, ("", None))
        lines.append(f"### `{key}` - {cls}")
        lines.append("")
        if doc:
            lines.extend([doc, ""])
        if action_args.get(key):
            lines.extend(_field_rows(action_args[key]) + [""])
        lines.extend([f"Source: {_source_link(actions.rel, line)}", ""])
    lines.extend(
        [
            "## Track (the timeline runner)",
            "",
            _full_doc(track.doc),
            "",
            f"Source: {_source_link(track.rel)}",
            "",
        ]
    )
    return "\n".join(lines).rstrip() + "\n"


# ---------------------------------------------------------------------------
# Masking page
# ---------------------------------------------------------------------------


def _render_masklab_doc(session: Script, editor: Script) -> str:
    t = session.text
    effects = _mask_effects(session)
    controls: Dict[int, Tuple[List[str], str]] = {}
    cm = re.search(r"const EFFECT_CONTROLS :?= \{(.*?)\n\}", t, re.S)
    if cm:
        for line in cm.group(1).splitlines():
            lm = re.match(r"\s*(\d+):\s*\[([^\]]*)\],?\s*(?:#\s*(.*))?", line)
            if not lm:
                continue
            groups = re.findall(r'"(\w+)"', lm.group(2))
            note = (lm.group(3) or "").strip()
            controls[int(lm.group(1))] = (groups, note)
    lines = [
        AUTOGEN_HEADER,
        "# Masking",
        "",
        "The video chroma-key masking editor - a second app surface inside "
        "ghost, separate from the audio visualizer. Open it on a session (or "
        "straight on a video file) with:",
        "",
        "```",
        "godot --path . -- --mask-edit masks/<video>/session.json",
        "```",
        "",
        "## The data model",
        "",
        _full_doc(session.doc),
        "",
        f"Source: {_source_link(session.rel)}",
        "",
        "## The editor",
        "",
        _full_doc(editor.doc),
        "",
        f"Source: {_source_link(editor.rel)}",
        "",
        "## Effects",
        "",
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
        "",
        "| # | Effect | Control groups | Notes |",
        "| --- | --- | --- | --- |",
    ]
    for idx, name in enumerate(effects):
        groups, note = controls.get(idx, ([], ""))
        note = re.sub(rf"^{re.escape(name)}\s*", "", note)
        note = note.lstrip("(").rstrip(")")
        gtxt = ", ".join(f"`{g}`" for g in groups) if groups else "-"
        lines.append(f"| {idx} | `{name}` | {gtxt} | {note} |")
    lines.extend(
        [
            "",
            "## Headless marker insertion",
            "",
            "`src/masking/mask_marker_tool.gd` inserts one marker into a saved "
            "session from the command line (no editor boot): ",
            "",
            "```",
            "godot --headless --path . --script src/masking/mask_marker_tool.gd \\",
            "    -- masks/<video>/session.json <time> [field=value ...]",
            "```",
            "",
            "The marker seeds from whatever was governing at `<time>`; each "
            "`field=value` then overrides one session field (e.g. "
            "`effect_a=14 fx_contrast=0.6 duration=0.5`). Note: a live "
            "editor autosaving the same session will clobber markers "
            "inserted this way - reload the session first.",
            "",
        ]
    )
    return "\n".join(lines).rstrip() + "\n"


# ---------------------------------------------------------------------------
# CLI page + flag drift check
# ---------------------------------------------------------------------------


def check_panel_controls() -> None:
    """Every panel control the mask editor SYNCS must also be BUILT.

    The editor's control panel is three parallel lists that have to agree: a
    member variable, a line in _build_panel that constructs it, and a line in
    _refresh_panel_inner that writes the stored value back into it. Delete or
    move a build line and leave the other two - which happens when a block of
    sliders is replaced wholesale - and the variable stays null, so every panel
    refresh throws. That is once at open, once per selection, and once per frame
    from _process, and it takes the rest of the refresh down with it, so controls
    below the broken one silently stop updating too.

    It is invisible to a running check, because a GDScript runtime error prints
    and carries on rather than failing anything, and it is invisible to a
    structural check over the registered-control list, because a control that was
    never built was never registered either. It IS visible here: a name that is
    written to but never assigned. Same drift-detection idea as CLI_FLAGS above.
    """
    src = _script_path("mask_editor").read_text(encoding="utf-8")
    written = set(re.findall(r"\b(_\w+)\.set_(?:value|pressed)_no_signal\(", src))
    for name in sorted(written):
        # `var _x` alone is a declaration, not a construction - the assignment is
        # what proves something was actually made and handed to the panel.
        if not re.search(rf"^\s*{re.escape(name)} = ", src, re.M):
            warn(
                f"mask_editor.gd: {name} is written by _refresh_panel_inner but "
                "never built - the panel will throw on every refresh"
            )


def check_films_pumped() -> None:
    """`Films.pump()` must be called from main.gd's `_process`.

    A window cut is an ffmpeg subprocess, and something with a frame has to notice it
    exited and promote its output out of the `.part` name. That used to be polled by the
    live film panel and by the Generative panel - which are exactly the two things usually
    absent - so a finished cut stayed a `.part` forever and footage appeared on one page of
    a session and never again. main's `_process` is the only one always running, and a test
    probe replaces the main scene, so no gate can see this from inside a run.
    """
    main = _script_path("main").read_text(encoding="utf-8")
    if "Films.pump()" not in main:
        warn(
            "main.gd never calls Films.pump() - a finished window cut will never be "
            "promoted, and film will appear once per session at most"
        )


def check_settings_owner() -> None:
    """Nothing but settings.gd may touch the config file directly.

    Every remembered value in ghost used to be written by whichever script owned the
    control, each doing its own `ConfigFile.load()` -> set -> `save()` on the SAME
    file. Five writers with five debounces means a new control is persistent only if
    someone remembers to add save code, two processes clobber each other (an export
    renders in a second one), and a kill loses everything since the last pause. The
    fix was one owner - `Settings` - and this is what stops a sixth writer appearing
    the next time someone needs to remember something.

    Mask sessions are exempt: those are per-video session files under masks/, not the
    app's settings.
    """
    for path in sorted(SCRIPTS.rglob("*.gd")):
        rel = path.relative_to(ROOT).as_posix()
        if path.name in ("settings.gd",) or "mask" in path.name:
            continue
        text = path.read_text(encoding="utf-8")
        if "ConfigFile.new()" in text or '"user://ghost.cfg"' in text:
            warn(
                f"{rel}: writes user://ghost.cfg directly - settings belong to "
                "Settings (src/platform/settings.gd), which owns the file, the debounce "
                "and the flushing"
            )


def _scan_flags() -> Dict[str, List[str]]:
    """Every `--flag` string literal in the GDScript, mapped to the scripts
    that mention it."""
    found: Dict[str, List[str]] = {}
    for path in sorted(SCRIPTS.rglob("*.gd")):
        for flag in set(re.findall(r'"(--[a-z][a-z-]*)"', path.read_text())):
            found.setdefault(flag, []).append(path.relative_to(ROOT).as_posix())
    return found


def _render_cli_doc(found: Dict[str, List[str]]) -> str:
    documented = {f for f, _, _, _ in CLI_FLAGS}
    undocumented = sorted(set(found) - documented - ENGINE_FLAGS)
    for flag in undocumented:
        warn(
            f"CLI flag {flag} ({', '.join(found[flag])}) missing from CLI_FLAGS in docs.py"
        )
    for flag in sorted(documented - set(found)):
        warn(f"CLI_FLAGS documents {flag} but it no longer appears in the source")
    lines = [
        AUTOGEN_HEADER,
        "# CLI flags",
        "",
        "Ghost's own flags follow the Godot separator: "
        "`godot --path . -- <ghost flags>`. Any of "
        "`--audio` / `--scene` / `--storyboard` boots straight into a song, and "
        "`--note` into a note, past the notes list. Flags marked _internal_ are passed "
        "between ghost's own processes (exporter, bake runner, mask render); "
        "you rarely type them.",
        "",
        "| Flag | Argument | Description | |",
        "| --- | --- | --- | --- |",
    ]
    for flag, arg, desc, internal in CLI_FLAGS:
        if flag not in found:
            continue
        tag = "_internal_" if internal else ""
        cells = [f"`{flag}`", f"`{arg}`" if arg else "", desc, tag]
        lines.append("| " + " | ".join(c.replace("|", "\\|") for c in cells) + " |")
    if undocumented:
        lines.extend(
            [
                "",
                "**Undocumented flags found in the source** (add them to "
                "`CLI_FLAGS` in `docs.py`): "
                + ", ".join(f"`{f}`" for f in undocumented),
            ]
        )
    return "\n".join(lines).rstrip() + "\n"


# ---------------------------------------------------------------------------
# Registry readers, shared by the pages and the README's counts
# ---------------------------------------------------------------------------

_STR = r'"((?:[^"\\]|\\.)*)"'
_STR_NC = r'"(?:[^"\\]|\\.)*"'


def _gd_text(body: str, name: str) -> str:
    """A string field's value, its literals joined where it is written `"a" + "b"` across lines."""
    m = re.search(rf'"{name}":\s*((?:{_STR_NC}\s*\+?\s*)+)', body)
    if not m:
        return ""
    return "".join(_gd_string(s) for s in re.findall(_STR, m.group(1)))


def _gd_list(body: str, name: str) -> List[str]:
    """A list field's strings (`["a", &"b"]`)."""
    m = re.search(rf'"{name}":\s*\[([^\]]*)\]', body)
    return re.findall(r'&?"([^"]*)"', m.group(1)) if m else []


def _gd_map(body: str, name: str) -> List[Tuple[str, str]]:
    """A dictionary field of strings (`{"linux": "...", ...}`), in order."""
    m = re.search(rf'"{name}":\s*\{{(.*?)\}}', body, re.S)
    if not m:
        return []
    return [(k, _gd_string(v)) for k, v in re.findall(rf'"([\w-]+)":\s*{_STR}', m.group(1))]


def _gd_entries(text: str, const: str) -> List[Tuple[str, str]]:
    """`const NAME := {"key": {...}, ...}` as (key, body) pairs, one-line and multi-line entries
    alike. Comment lines between entries are skipped."""
    block = _const_block(text, const) + "\n"
    return re.findall(r'\n\t"([^"]+)":\s*\{(.*?)\},[ \t]*(?:#[^\n]*)?(?=\n)', block, re.S)


def _gd_rows(text: str, const: str) -> List[str]:
    """`const NAME := [{...}, ...]` as each row's body (a row's nested dictionaries are indented
    deeper, so only a row's own closing brace ends it)."""
    m = re.search(rf"const {const} :?= \[(.*?)\n\]", text, re.S)
    return re.findall(r"\n\t\{(.*?)\n\t\},", m.group(1) + "\n", re.S) if m else []


def _media_pairs(base: Script) -> List[Tuple[str, str]]:
    """Medium.REGISTRY as (key, script path from the repository's root). A row names its script
    by path, so a medium a feature brings lives with the feature (the card table, in `table/`)."""
    return [
        (k, str(r.get("script", "")).replace("res://", "", 1))
        for k, r in _rows(base.text, "REGISTRY").items()
    ]


def _filter_pairs(base: Script) -> List[Tuple[str, str]]:
    """Filters.REGISTRY as (key, uniform)."""
    return [(k, str(r.get("uniform", ""))) for k, r in _rows(base.text, "REGISTRY").items()]


def _mask_effects(session: Script) -> List[str]:
    """MaskSession.MASK_EFFECTS, in index order."""
    m = re.search(r"const MASK_EFFECTS :?= \[(.*?)\]", session.text, re.S)
    return re.findall(r'"(\w+)"', m.group(1)) if m else []


def _script_entries(marks: Script) -> List[Tuple[str, str]]:
    """ScriptMarks.REGISTRY as (key, body)."""
    return re.findall(
        r'\n\t"(\w+)": \{(.*?)\n\t\},', _const_block(marks.text, "REGISTRY"), re.S
    )


def _class_index() -> Dict[str, Script]:
    """Every script under src/ by the name the code calls it: its class_name, or its autoload
    name in project.godot (Spectrum and Director have no class_name)."""
    out: Dict[str, Script] = {}
    for p in sorted(SCRIPTS.rglob("*.gd")):
        s = Script(p)
        if s.class_name:
            out[s.class_name] = s
    project = (ROOT / "project.godot").read_text()
    for name, rel in re.findall(r'^(\w+)="\*?res://([^"]+\.gd)"', project, re.M):
        if (ROOT / rel).exists():
            out.setdefault(name, Script(ROOT / rel))
    return out


# ---------------------------------------------------------------------------
# Components and templates
# ---------------------------------------------------------------------------

CAPABILITY_WHERE = {"desktop": "the desktop", "checkout": "a checkout of the repository"}


def _render_components_doc(comp: Script, caps: Script) -> str:
    """docs/components.md, from Components.FAMILIES / SLOTS / WORKSPACES / REGISTRY and
    Capabilities.TABLE: what a note can carry, the room each part takes, which panel runs
    a note, and what each part asks of the platform."""
    families = re.findall(
        r'&"(\w+)":\s*\{"label":\s*"([^"]*)"', _const_block(comp.text, "FAMILIES")
    )
    entries = _gd_entries(comp.text, "REGISTRY")
    slots = _gd_entries(comp.text, "SLOTS")
    workspaces = _gd_entries(comp.text, "WORKSPACES")
    table = _gd_entries(caps.text, "TABLE")
    if not (families and entries and slots and workspaces and table):
        warn(
            "could not parse Components.FAMILIES / SLOTS / WORKSPACES / REGISTRY or "
            "Capabilities.TABLE"
        )
    labels = {k: _gd_text(b, "label") for k, b in entries}
    family_of = {k: _first(b, r'"family":\s*&"(\w+)"') for k, b in entries}
    lines = [
        AUTOGEN_HEADER,
        "# Components",
        "",
        "What a note can carry. A note is a markdown file, and each block under `ghost:` in "
        "its frontmatter is a component attached to it. **New** in the notes list makes a "
        "note with nothing attached, **+** attaches a component and the × on its card takes "
        "it off again, and what a note does is read off what it has attached.",
        "",
        _full_doc(comp.doc),
        "",
        f"Registry: `Components.REGISTRY` in {_source_link(comp.rel)} "
        f"({len(entries)} components, {len(slots)} slots, {len(workspaces)} workspaces).",
        "",
        "## Slots",
        "",
        "Where a note has room for exactly one. Components that take the same slot are "
        "alternatives: **+** grays the second, and says which to detach.",
        "",
        "| Slot | What it is | Taken by |",
        "| --- | --- | --- |",
    ]
    for key, body in slots:
        takers = ", ".join(labels[k] for k, b in entries if key in _gd_list(b, "slots"))
        blurb = _md(_gd_text(body, "blurb")).replace("|", "\\|")
        lines.append(f"| `{key}` | {blurb} | {takers} |")
    lines.extend(
        [
            "",
            "## Workspaces",
            "",
            "The panels that run a note. Most components are a card on whichever panel is "
            "up; a few are an editor of their own and name the workspace that is. Where two "
            "attached components name one, a component another brings gives way to the one "
            "that brings it.",
            "",
            "| Workspace | Named by | What it is |",
            "| --- | --- | --- |",
        ]
    )
    for key, body in workspaces:
        named = ", ".join(labels[k] for k, b in entries if _gd_text(b, "workspace") == key)
        blurb = _md(_gd_text(body, "blurb")).replace("|", "\\|")
        lines.append(
            f"| **{_gd_text(body, 'label')}** (`{key}`) | {named or 'no component: the default'} "
            f"| {blurb} |"
        )
    lines.extend(
        [
            "",
            "## Components",
            "",
            "By family - the color a component's card, chip and marks are drawn in.",
            "",
        ]
    )
    for fam, flabel in families:
        mine = [(k, b) for k, b in entries if family_of[k] == fam]
        if not mine:
            continue
        lines.extend([f"### {flabel}", ""])
        for key, body in mine:
            lines.append(f"- **{labels[key]}** (`{key}`) - {_md(_gd_text(body, 'blurb'))}")
            facts = []
            for field, word in (("needs", "needs"), ("provides", "gives"), ("requires", "brings")):
                vals = _gd_list(body, field)
                if field == "requires":
                    vals = [labels.get(v, v) for v in vals]
                if vals:
                    facts.append(f"{word} {', '.join(vals)}")
            takes = _gd_list(body, "slots")
            if takes:
                facts.append("takes the " + " and the ".join(takes))
            asks = _gd_list(body, "capabilities")
            if asks:
                facts.append("asks for " + ", ".join(f"`{c}`" for c in asks))
            block = _gd_text(body, "block")
            if block:
                facts.append(f"kept in `{block}:`")
            if facts:
                lines.append(f"  - {'; '.join(facts)}")
        lines.append("")
    for key in [k for k, f in family_of.items() if f not in dict(families)]:
        warn(f"Components.REGISTRY['{key}'] names a family FAMILIES does not have")
    lines.extend(
        [
            "## Capabilities",
            "",
            "What a component may ask of the platform. Each is possible somewhere or not at "
            "all, and **+** leaves out what is impossible here and grays what is not ready "
            "yet, with the reason; the same table is checked wherever a program is started. "
            "On a phone, a note is its text and nothing else.",
            "",
            "| Capability | What it is | Possible on |",
            "| --- | --- | --- |",
        ]
    )
    for key, body in table:
        where = _gd_text(body, "where")
        lines.append(f"| `{key}` | {_gd_text(body, 'label')} | {CAPABILITY_WHERE.get(where, where)} |")
    lines.extend(["", f"Source: `Capabilities.TABLE` in {_source_link(caps.rel)}"])
    return "\n".join(lines).rstrip() + "\n"


# ---------------------------------------------------------------------------
# The environment
# ---------------------------------------------------------------------------

MACHINES = {
    "linux-x86_64": "Linux (x86-64)",
    "linux-arm64": "Linux (ARM)",
    "macos-arm64": "Apple silicon Macs",
    "macos-x86_64": "Intel Macs",
    "windows-x86_64": "Windows (x86-64)",
    "windows-arm64": "Windows on ARM",
}
PLATFORMS = {"linux": "Linux", "macos": "macOS", "windows": "Windows"}


def _env_row(body: str) -> List[str]:
    name = _gd_text(body, "name")
    used = _gd_text(body, "used_for")
    if not name or not used:
        warn(f"a Deps row has no name or used_for: {body.strip()[:60]}")
    tags = [_gd_text(body, "size"), ", ".join(PLATFORMS.get(p, p) for p in _gd_list(body, "platforms"))]
    head = ", ".join([f"**{name}**"] + [t for t in tags if t])
    out = [f"- {head} - {_md(used)}"]
    for machine, why in _gd_map(body, "unsupported"):
        out.append(f"  - Not on {MACHINES.get(machine, machine)}: {why}.")
    for plat, hint in _gd_map(body, "install"):
        out.append(f"  - {PLATFORMS.get(plat, plat)}: `{hint}`")
    return out


def _render_environment_doc(deps: Script) -> str:
    """docs/environment.md, from Deps.FETCHED / MANAGED / TOOLS - the rows the Environment panel
    and `--deps` render: what each is for, its size, the machines it cannot be built on and why,
    and the install hints for what stays the machine's."""
    tables = {t: _gd_rows(deps.text, t) for t in ("FETCHED", "MANAGED", "TOOLS")}
    for t, rows in tables.items():
        if not rows:
            warn(f"could not parse Deps.{t}")
    lines = [
        AUTOGEN_HEADER,
        "# The environment",
        "",
        "Godot 4.7 is the only thing to install. Everything else Ghost Notes runs, it installs "
        "and keeps current itself, under its own data directory - never system-wide, and never "
        "into your own environments. uv, FFmpeg and Python download in the background the "
        "first time it opens; a feature's environment is built the first time that feature is "
        "used. While anything installs, a notice at the top of the screen says what and how far "
        "along, and the Environment panel (the ⚙ in the bottom-right row) lists every piece with "
        "its version, what it is for and, if it failed, why. With **keep up to date** ticked "
        "there, Ghost Notes looks for newer releases once a day.",
        "",
        "The same report, and an install, from a terminal:",
        "",
        "```",
        "godot --headless --path . -- --deps             # what is installed, and where",
        "godot --headless --path . -- --provision        # install uv, FFmpeg and Python now",
        "godot --headless --path . -- --provision all    # ...and every feature's environment",
        "godot --headless --path . -- --provision update # bring everything up to date",
        "godot --headless --path . -- --provision mathlib # Lean and Mathlib, for the Proof component (~8 GB)",
        "```",
        "",
        "## What Ghost Notes installs itself",
        "",
    ]
    for t in ("FETCHED", "MANAGED"):
        for body in tables[t]:
            lines.extend(_env_row(body))
    lines.extend(
        [
            "",
            "## What stays the machine's",
            "",
            "A few programs are part of the system or keep their own logins, so they stay yours "
            "to install; the Environment panel shows the command for each.",
            "",
        ]
    )
    for body in tables["TOOLS"]:
        lines.extend(_env_row(body))
    lines.extend(
        [
            "",
            "## Platforms",
            "",
            "Linux, macOS and Windows are all meant to work, and nothing needs a Unix shell: "
            "background programs are started directly, and where output has to be redirected "
            "Ghost Notes does it itself (through PowerShell on Windows). It is developed on Linux, "
            "so Windows and macOS are the least exercised - where something fails, the "
            "Environment panel is the first place to look. The machines an environment cannot "
            "be built on are named under it above. On a phone Ghost Notes downloads nothing.",
            "",
            f"Source: `Deps.FETCHED`, `Deps.MANAGED` and `Deps.TOOLS` in {_source_link(deps.rel)}, "
            "installed by [src/platform/provisioner.gd](../src/platform/provisioner.gd). The panel and every program "
            "Ghost Notes starts ask the same resolver, so the panel cannot report a program "
            "present while a launch fails to find it.",
        ]
    )
    return "\n".join(lines).rstrip() + "\n"


# ---------------------------------------------------------------------------
# The agents
# ---------------------------------------------------------------------------


def _sentence(text: str) -> str:
    """`text` with its first letter capitalized: a class one-liner begins lower case once its
    name is stripped ("TextGen - who writes the words")."""
    return text[:1].upper() + text[1:]


def _class_body(text: str, name: str) -> str:
    """An inner class's body: from `class Name:` to the next top-level class, or the end."""
    m = re.search(rf"^class {name}:\n(.*?)(?=^class \w+|\Z)", text, re.S | re.M)
    return m.group(1) if m else ""


def _agent_backends(script: Script) -> List[Dict[str, str]]:
    """A TextGen / ImageGen registry as one record per backend, in registry order: its key, label,
    blurb and class doc, the Deps row its CLI resolves through (the `Deps.has` in its class), and
    whether it takes Ghost Notes' own tools (`takes_tools` returning true)."""
    rows = _rows(script.text, "REGISTRY")
    labels = {k: str(r.get("label", k)) for k, r in rows.items()}
    blurbs = {k: str(r.get("blurb", "")) for k, r in rows.items()}
    docs = _inner_class_docs(script.text)
    out = []
    for key, cls in ((k, str(r.get("backend", ""))) for k, r in rows.items()):
        body = _class_body(script.text, cls)
        dep = _first(body, r'Deps\.has\("(\w+)"\)') or ""
        if not dep:
            warn(f"{script.rel}: {cls} names no Deps row (Deps.has) - docs/agents.md cannot say what to install")
        if key not in labels or key not in blurbs:
            warn(f"{script.rel}: the row '{key}' has no label or blurb")
        doc, line = docs.get(cls, ("", None))
        out.append({"key": key, "label": labels.get(key, key), "blurb": blurbs.get(key, ""), "doc": doc,
                    "line": str(line or ""), "dep": dep,
                    "tools": "yes" if re.search(r"func takes_tools\(\) -> bool:\s*\n\s*return true", body) else ""})
    return out


def _render_agents_doc(text_gen: Script, image_gen: Script, assistant: Script, deps: Script) -> str:
    """docs/agents.md, from TextGen.REGISTRY, ImageGen.REGISTRY and AssistantBackends.REGISTRY - each
    backend's label, blurb and class doc - and the Deps.TOOLS row of every CLI they run, for the
    install lines. Nothing here names an agent: the table is whatever the registries hold."""
    writers = _agent_backends(text_gen)
    painters = _agent_backends(image_gen)
    helpers = [
        {"key": k, "label": _gd_text(b, "label"), "dep": _gd_text(b, "dep")}
        for k, b in _gd_entries(assistant.text, "REGISTRY")
    ]
    tools = {_gd_text(b, "key"): b for b in _gd_rows(deps.text, "TOOLS")}
    clis: List[str] = []
    for a in writers + painters + helpers:
        if a["dep"] and a["dep"] not in clis:
            clis.append(a["dep"])
    for dep in clis:
        if dep not in tools:
            warn(f"an agent runs '{dep}', which no Deps.TOOLS row describes")

    def cli_name(dep: str) -> str:
        return _gd_text(tools.get(dep, ""), "name") or dep

    def role(group: List[Dict[str, str]], dep: str) -> str:
        return ", ".join(a["label"] for a in group if a["dep"] == dep) or "-"

    lines = [
        AUTOGEN_HEADER,
        "# Agents: who writes, paints and fixes",
        "",
        "Ghost Notes hands three kinds of work to AI agents. A **writer** writes the words: a card "
        "show's plan, its deck's booklet, the set dresser's table and every reading. A **painter** "
        "paints the pictures: a deck's cards, the table's cloth and room, and the book's and the "
        "notebook's illustrations. The **assistant** takes a note left in the feedback console "
        "(the backtick key) and makes the fix in the copy of Ghost Notes it runs from.",
        "",
        "Every agent is a command-line tool you install yourself, and each keeps its own sign-in, "
        "which Ghost Notes never handles: it finds the tool, runs it only when you ask, and keeps "
        "what each run was sent and what it said beside the result. Install one or several. Until "
        "one is installed, a component that needs a writer or a painter is grayed in a note's **+**, "
        "its tooltip naming every agent that would do; the Environment panel (the ⚙ in the bottom-right "
        "row) lists each tool with the command that installs it.",
        "",
        "## Which tool does what",
        "",
        "| Command-line tool | Writer | Painter | Assistant | Ghost Notes' own tools |",
        "|---|---|---|---|---|",
    ]
    for dep in clis:
        site = _gd_text(tools.get(dep, ""), "site")
        name = f"[{cli_name(dep)}]({site})" if site else cli_name(dep)
        lines.append(
            f"| {name} | {role(writers, dep)} | {role(painters, dep)} | {role(helpers, dep)} | "
            f"{'yes' if any(w['dep'] == dep and w['tools'] for w in writers) else '-'} |"
        )
    lines.extend(
        [
            "",
            "A writer that takes **Ghost Notes' own tools** works in a loop: it calls a tool Ghost "
            "Notes serves while the app runs (build a thing, stand it on the table, photograph it), "
            "looks at what comes back and goes on (`AgentTools`). The card table's set dresser works "
            "that way when its writer can; any other writer is asked once and answers once.",
            "",
            "Where each is chosen: a card show's **Writer** and **Painter** rows, each with its own "
            "model and reasoning effort; the illustration panel's painter, for the book and the "
            "notebook; and the assistant picker in the 💬 panel. What every agent is told is in "
            "[rules/](../rules), one YAML file per role.",
            "",
            f"## Writers ({len(writers)})",
            "",
            f"`TextGen.REGISTRY` in {_source_link(text_gen.rel)}. {_sentence(_one_liner(text_gen.doc, 'TextGen'))}",
            "",
        ]
    )
    for kind, group, script in (("writer", writers, text_gen), ("painter", painters, image_gen)):
        if kind == "painter":
            lines.extend(
                [
                    f"## Painters ({len(painters)})",
                    "",
                    f"`ImageGen.REGISTRY` in {_source_link(image_gen.rel)}. {_sentence(_one_liner(image_gen.doc, 'ImageGen'))}",
                    "",
                ]
            )
        for a in group:
            lines.extend([f"### `{a['key']}` - {a['label']}", ""])
            if a["blurb"]:
                lines.extend([f"_{_md(a['blurb'])}_", ""])
            if a["doc"]:
                lines.extend([a["doc"], ""])
            else:
                warn(f"{script.rel}: the {kind} '{a['key']}' has no doc comment")
            lines.extend(
                [f"Runs the {cli_name(a['dep'])}. Source: {_source_link(script.rel, int(a['line']) if a['line'] else None)}", ""]
            )
    lines.extend(
        [
            f"## The assistant ({len(helpers)})",
            "",
            f"`AssistantBackends.REGISTRY` in {_source_link(assistant.rel)}. "
            f"{_sentence(_one_liner(assistant.doc, 'AssistantBackends'))} It runs in the folder Ghost Notes "
            "runs from and edits it, so it is for working on Ghost Notes itself.",
            "",
        ]
    )
    for a in helpers:
        lines.append(f"- **{a['label']}** (`{a['key']}`)")
    lines.extend(["", "## Installing one", ""])
    for dep in clis:
        body = tools.get(dep, "")
        site = _gd_text(body, "site")
        lines.append(f"- **{cli_name(dep)}**" + (f" - {site}" if site else ""))
        for plat, hint in _gd_map(body, "install"):
            lines.append(f"  - {PLATFORMS.get(plat, plat)}: `{hint}`")
    lines.extend(
        [
            "",
            f"Source: the registries above, and `Deps.TOOLS` in {_source_link(deps.rel)}, which the "
            "Environment panel and every launch resolve through - see [environment.md](environment.md).",
        ]
    )
    return "\n".join(lines).rstrip() + "\n"


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


def _render_architecture_doc(
    classes: Dict[str, Script],
    scenes: Dict[str, SceneInfo],
    layer: Script,
    prims: Script,
    medium: Script,
) -> str:
    """docs/architecture.md: how the parts fit together, from the audio to the screen or a video
    file. The prose is curated here (as DESIGN_NOTES is); every list and count in it is read from
    the source, and every class it names is checked to exist."""

    def ref(name: str) -> str:
        s = classes.get(name)
        if s is None:
            warn(f"docs/architecture.md names {name}, which no script declares")
            return f"`{name}`"
        return f"[`{name}`](../{s.rel})"

    def keys(pairs: List[Tuple[str, str]]) -> str:
        return ", ".join(f"`{k}`" for k, _ in pairs)

    features_src = _script_path("audio_features").read_text()
    fields = ", ".join(f"`{v}`" for v in re.findall(r"^var (\w+)", features_src, re.M))
    live = {n: s for n, s in scenes.items() if s.behaviors}
    behaviors = sorted({b for s in live.values() for b in s.behaviors})
    kinds: Dict[str, int] = {}
    for s in live.values():
        kinds[s.render_kind] = kinds.get(s.render_kind, 0) + 1
    kind_text = ", ".join(
        f"`{k}` ({n})" for k, n in sorted(kinds.items(), key=lambda e: (-e[1], e[0]))
    )
    morphing = sum(1 for s in live.values() if s.morph_in or s.morph_out)
    forces = _parse_registry_dict(prims.text)
    layers = _parse_registry_dict(layer.text)
    medium_rows = _rows(medium.text, "REGISTRY")
    labels = {k: str(r.get("label", k)) for k, r in medium_rows.items()}
    media = [labels.get(k, k) for k, _ in _media_pairs(medium)]
    portrait = [labels.get(k, k) for k, r in medium_rows.items() if "portrait" in r.get("frames", [])]
    lines = [
        AUTOGEN_HEADER,
        "# How the show is made",
        "",
        "From the audio to the screen, or to a video file. Each part's reference is its own "
        "source and the [index](index.md); this page is how they fit together.",
        "",
        "```",
        "  audio ──▶ Spectrum ──▶ AudioFeatures ──▶ GhostScene ──▶ stage ──▶ screen / video",
        "            (analyzer)    (typed, per frame)  │ (definition × behavior)",
        "                                   movement ──┤",
        "                                              ▼",
        "                                Director: cut on the music, blend sometimes",
        "```",
        "",
        "## The signal path",
        "",
        f"- **{ref('Spectrum')}** (an autoload) owns the audio player and the analyzer, and emits "
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
        "fingerprint, so the same song always plays the same show; `--seed N` rolls another.",
        "",
        "## Composition, by registry",
        "",
        f"- **Physics:** {ref('Primitives')} holds {len(forces)} force modules ({keys(forces)}) "
        f"that a scene composes into a {ref('ParticleSystem')} by key - the same `scatter` "
        "bursts glass, rocks and embers. See [forces.md](forces.md).",
        f"- **Appearance:** {ref('Layer')} holds {len(layers)} visual components "
        f"({keys(layers)}) that seed themselves, advance on the audio and draw on a scene's "
        "canvas, in unit-fraction space so they fill any frame - the same `snow` that is a "
        "scene of its own falls over the cityscape. See [layers.md](layers.md).",
        "- A new scene is mostly a parts list.",
        "",
        "## Drawing",
        "",
        f"- **Every scene declares a render kind** - in the rotation: {kind_text}.",
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
        "interaction - thousands of items, none scripted.",
        "",
        "## Staying interactive",
        "",
        "The engine runs one main loop, so a scene that spends 300 ms in a frame blocks input "
        "for 300 ms.",
        "",
        f"- {ref('TriBatch')} submits a frame's triangles in one call: per-shape draw calls, not "
        "geometry, were the cost.",
        f"- {ref('FrameForge')} builds a scene's geometry on a worker from a plain-data "
        "snapshot, and `_draw` submits the finished packet in microseconds.",
        "",
        "## Scheduling and transitions",
        "",
        f"- **{ref('Director')}** (an autoload) holds the roster - {len(live)} scenes in the "
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
        "mode's default.",
        "",
        "## Media and frames",
        "",
        f"The scenes are drawn on a **medium** - {', '.join(media)} ([media.md](media.md)) - in "
        "a **frame**: landscape, 1920x1080, or portrait, 1080x1920, for "
        f"{', '.join(portrait) or 'none yet'}. The stage is the frame, as large as the window "
        "holds it, and the Look ([filters.md](filters.md)) filters the whole picture.",
        "",
        "## Rendering: live and baked",
        "",
        "1. **Live.** The audio plays through the analyzer and the scenes react in real time. "
        "The window stretches in `canvas_items` mode, so 2D rasterizes at the monitor's own "
        "resolution.",
        f"2. **Baked, for export** ({ref('Exporter')}). A headless process analyzes the song into a "
        f"spectrum timeline once ({ref('SpectrumBake')}, cached per song); a second renders the "
        "show with Movie Maker, driving the scenes from that timeline - frame-perfect, in sync. "
        "The size goes through a transient `override.cfg`, because Movie Maker fixes it at "
        "startup: `viewport` stretch, in a window shaped like the frame, so frames come from an "
        "offscreen buffer at any resolution. On Linux the render runs on a virtual display "
        "(`xvfb-run`), so the desktop cannot freeze it, and ffmpeg encodes the MP4 while the "
        "render is still writing.",
        "",
        "## The feedback loop",
        "",
        "The `` ` `` console captures what is on screen - the scene's typed descriptor (name, "
        "kind, behavior, seed, params, the audio frame), a note and a screenshot - into "
        "`feedback/NNNN.{json,png}`; the seed makes it reproducible. The Assistant (💬) browses "
        "the records and can send one to an AI command-line tool as a fix.",
        "",
        "## Adding a scene",
        "",
        ADD_A_SCENE,
    ]
    return "\n".join(lines).rstrip() + "\n"


# ---------------------------------------------------------------------------
# Index + README layout
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


def _render_index(
    scripts: Dict[str, Script],
    scenes: Dict[str, SceneInfo],
    features: List[Tuple[str, str, str, str]],
) -> str:
    lines = [
        AUTOGEN_HEADER,
        "# Ghost Notes docs index",
        "",
        "Generated from the source of record (doc comments, registries, the "
        "scene roster) by [docs.py](../docs.py). The [README](../README.md) says what "
        "Ghost Notes is and how to run it, and the [roadmap](../next/roadmap.md) what "
        "comes next. Regenerate with `python docs.py`.",
        "",
        DESIGN_NOTES,
        "## Feature registries",
        "",
    ]
    for slug, title, count, desc in features:
        lines.append(f"- [{title}]({slug}.md) ({count}) - {desc}")
    lines.extend(["", "## Subsystems", ""])
    for title, path, desc in SUBSYSTEMS:
        lines.append(f"- [{title}]({_docs_relative(path)}) - {desc}")
    lines.extend(["", "## Directory layout", "", _render_layout_block("../"), ""])
    lines.extend(
        [
            "## Script map",
            "",
            "One folder under `src/` a group, bottom first: a script names scripts in its own "
            "folder and in the folders above its own in this list. [structure.md](structure.md) "
            "is the same stack with what each folder names and what still points up.",
            "",
        ]
    )
    for folder, title, desc in FOLDERS:
        lines.extend([f"### `{folder}/` - {title}", "", desc, ""])
        if folder == "scenes":
            continue
        for script in sorted(_folder_scripts(folder), key=lambda s: s.name):
            one = _one_liner(script.doc, strip_name=script.class_name or "")
            label = script.class_name or script.name
            lines.append(f"- [`{script.name}.gd`](../{script.rel}) **{label}** - {one}")
        lines.append("")
    lines.append(
        f"Scene scripts ({len(scenes)}) are cataloged separately in "
        "[scenes.md](scenes.md)."
    )
    return "\n".join(lines).rstrip() + "\n"


def _folder_scripts(folder: str) -> List[Script]:
    return [Script(p) for p in sorted((SCRIPTS / folder).glob("*.gd"))]


# ---------------------------------------------------------------------------
# The structure: src/ is a stack, and the code is held to it
# ---------------------------------------------------------------------------


def _code_of(text: str) -> str:
    """A script with its comments and string literals taken out, so a class named in a doc
    comment or a tooltip is not a reference."""
    out = []
    for line in text.splitlines():
        kept, i, quote = [], 0, None
        while i < len(line):
            c = line[i]
            if quote:
                if c == "\\":
                    i += 2
                    continue
                if c == quote:
                    quote = None
            elif c in "\"'":
                quote = c
            elif c == "#":
                break
            else:
                kept.append(c)
            i += 1
        out.append("".join(kept))
    return "\n".join(out)


def _references() -> Dict[str, set]:
    """{script: the scripts it names}, each as `folder/name`: a class name or an autoload's
    name in its code, or a `preload` / `load` of a script's path."""
    paths = sorted(SCRIPTS.glob("*/*.gd"))
    key = lambda p: f"{p.parent.name}/{p.stem}"
    text = {key(p): p.read_text() for p in paths}
    by_res = {p.relative_to(ROOT).as_posix(): key(p) for p in paths}
    named: Dict[str, str] = {}
    project = (ROOT / "project.godot").read_text()
    for name, rel in re.findall(r'^(\w+)="\*?res://([^"]+\.gd)"', project, re.M):
        if rel in by_res:
            named[name] = by_res[rel]
    for k, t in text.items():
        m = re.search(r"^class_name\s+(\w+)", t, re.M)
        if m:
            named[m.group(1)] = k
    edges: Dict[str, set] = {k: set() for k in text}
    for k, t in text.items():
        for m in re.finditer(r"\b[A-Z][A-Za-z0-9_]*\b", _code_of(t)):
            other = named.get(m.group(0))
            if other and other != k:
                edges[k].add(other)
        for m in re.finditer(r'(?:pre)?load\(\s*"res://(src/[\w/]+\.gd)"', t):
            other = by_res.get(m.group(1))
            if other and other != k:
                edges[k].add(other)
    return edges


def _upward(edges: Dict[str, set], order: List[str]) -> List[Tuple[str, str]]:
    """The references that point up the stack: (script, the script above it that it names)."""
    rank = {folder: i for i, folder in enumerate(order)}
    out = []
    for a in sorted(edges):
        for b in sorted(edges[a]):
            fa, fb = a.split("/")[0], b.split("/")[0]
            if fa in rank and fb in rank and rank[fb] > rank[fa]:
                out.append((a, b))
    return out


def _structure_problems(
    edges: Dict[str, set], order: List[str], listed: List[Tuple[str, str]]
) -> List[str]:
    """What is wrong between the code and the stack. Pure, so its control can be run on a
    made-up graph: see `check_structure`."""
    up = _upward(edges, order)
    out = []
    for a, b in up:
        if (a, b) not in listed:
            out.append(
                f"src/{a}.gd names src/{b}.gd, which is ABOVE it: src/ is a stack, and a "
                "script names its own folder and the ones below. Hand it what it reads "
                "(next/structure.md, \"The rules\") - do not add a row to UPWARD"
            )
    for a, b in listed:
        if (a, b) not in up:
            out.append(
                f"docs.py UPWARD lists {a} -> {b}, which is no longer in the code: delete "
                "its row (the list only shrinks)"
            )
    if len(set(listed)) != len(listed):
        out.append("docs.py UPWARD lists a pair twice")
    return out


def _handed_problems(edges: Dict[str, set], handed: Dict[str, List[str]]) -> List[str]:
    """The scripts a show mounts that name what they are handed (HANDED). Pure, for the control."""
    out = []
    for a in sorted(edges):
        for b in sorted(edges[a]):
            if a.split("/")[0] in handed.get(b, []):
                out.append(
                    f"src/{a}.gd names src/{b}.gd: a part a show mounts reads the show through "
                    "its `feed` ([ShowFeed]) - hand it what it needs there (docs.py HANDED)"
                )
    return out


def check_structure() -> Dict[str, set]:
    """src/ is a stack (FOLDERS, bottom first), and the code is held to it.

    Every script sits in exactly one folder that FOLDERS names, and every reference between
    scripts points down or stays in its folder - except the pairs UPWARD lists, which is what
    is left to fix and may only get shorter. A flat `src/` hid that the code was already
    layered (703 of 751 references pointed down when this was first measured, 2026-10-13); a
    stack nothing holds is flat again within a month, one convenient `Director.x` at a time.

    THE CONTROL: before the real code is judged, a made-up graph with one reference planted
    upward must be reported, and one listed pair that is gone must be reported too. A check
    that passes those has not been run.
    """
    order = [folder for folder, _t, _d in FOLDERS]
    planted = {"platform/a": {"app/b"}, "app/b": {"platform/a"}}
    if len(_structure_problems(planted, order, [])) != 1 or len(
        _structure_problems({"platform/a": set()}, order, [("platform/a", "app/b")])
    ) != 1:
        warn("check_structure: its control did not fail - the check proves nothing")
    if len(_handed_problems({"media/a": {"audio/b"}, "audio/c": {"audio/b"}}, {"audio/b": ["media"]})) != 1:
        warn("check_structure: the HANDED control did not fail - the check proves nothing")

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
    listed = [pair for _p, _f, pairs in UPWARD for pair in pairs]
    for problem in _structure_problems(edges, order, listed) + _handed_problems(edges, HANDED):
        warn(problem)
    return edges


def _class_bodies(text: str) -> Dict[str, str]:
    """Each inner class of a script: its name -> its body, one tab of indent taken off."""
    out: Dict[str, str] = {}
    lines = text.split("\n")
    for i, line in enumerate(lines):
        m = re.match(r"class (\w+)\b", line)
        if not m:
            continue
        body = []
        for l in lines[i + 1:]:
            if l.strip() and not l.startswith(("\t", " ")):
                break
            body.append(l[1:] if l.startswith("\t") else l)
        out[m.group(1)] = "\n".join(body)
    return out


def _reads(body: str) -> Dict[str, Tuple[str, str]]:
    """The settings a class reads off its config: key -> (num / flag / txt, the default as written),
    the first read of each. Comments and strings aside from the key itself are not looked in."""
    out: Dict[str, Tuple[str, str]] = {}
    code = "\n".join(l.split("#")[0] if not l.lstrip().startswith("#") else "" for l in body.split("\n"))
    for m in re.finditer(r'(?<![\w.])(num|flag|txt|cfg\.get)\("(\w+)",\s*', code):
        i, depth = m.end(), 1
        while depth and i < len(code):
            depth += {"(": 1, ")": -1}.get(code[i], 0)
            i += 1
        out.setdefault(m.group(2), (m.group(1).replace("cfg.get", "get"), code[m.end():i - 1].strip()))
    return out


def _field_problems(bodies: Dict[str, str], registry: List[Tuple[str, str]], base: str) -> List[str]:
    """What is wrong between each registered class's FIELDS and the settings its code reads: a read
    with no row, a row nothing reads, a row's type or literal default that is not the code's. The
    base class's own reads are its `COMMON` rows, every class's. Pure, so its control can run on a
    made-up script (see `check_fields`)."""
    out = []
    for key, cls in [("", base)] + list(registry):
        body = bodies.get(cls, "")
        own = _reads(body)
        table = "COMMON" if cls == base else "FIELDS"
        fields = _rows(body, table)
        if cls == base and not own and not fields:
            continue
        for k, (kind, default) in own.items():
            if k not in fields:
                out.append(f"{cls} reads `{k}` and its {table} has no row for it")
                continue
            row = fields[k]
            if kind != "get" and row.get("type") != kind:
                out.append(f"{cls}.{table} `{k}` is a {row.get('type')}, and the code reads a {kind}")
            want = row.get("default")
            try:
                lit = ast.literal_eval(default.replace("true", "True").replace("false", "False"))
            except (ValueError, SyntaxError):
                lit = None   # drawn from the seed, or worked out: the row says so in words
            if lit is not None and want != lit:
                out.append(f"{cls}.{table} `{k}` defaults to {want!r}, and the code to {lit!r}")
            if lit is None and want is not None:
                out.append(f"{cls}.{table} `{k}` defaults to {want!r}, and the code draws it ({default})")
        for k in fields:
            if k not in own:
                out.append(f"{cls}.{table} has `{k}`, which its code never reads")
    return out


def _scene_field_problems(text: str, name: str) -> List[str]:
    """What is wrong between a scene's FIELDS and the settings it takes from an entry
    ([method GhostScene.choice] and [method GhostScene.number], steps 27 and 28): a setting chosen or numbered
    with no row of its type, a row nothing reads, a choice whose `options` (or `names`) names no table
    of the scene, a number whose `range` is not two numbers low to high, and a default (a setting is
    the seed's until it is told). Pure, so its control runs on a made-up scene."""
    out = []
    code = "\n".join(l for l in text.splitlines() if not l.lstrip().startswith("#"))
    reads = {"choice": set(re.findall(r'\bchoice\("(\w+)"', code)),
             "num": set(re.findall(r'(?<![\w.])number\("(\w+)"', code))}
    fields = _rows(text, "FIELDS")
    tables = set(re.findall(r"^const (\w+)\b", text, re.M))
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
            if not (isinstance(r, list) and len(r) == 2 and all(isinstance(x, (int, float)) for x in r) and r[0] < r[1]):
                out.append(f"{name}.FIELDS `{k}`: its range {r!r} is not two numbers, low to high")
        if row.get("default") is not None:
            out.append(f"{name}.FIELDS `{k}` defaults to {row.get('default')!r} - a setting is the seed's until told")
    return out


def _table_options(text: str, name: str) -> List[Any]:
    """A scene's table [name] as its options: a Dictionary's keys, an Array's elements, in order - read
    off the literal's top level alone, so what each option holds (a `Vector3(...)`, a nested row) is
    never parsed."""
    m = re.search(rf"^const {name}\b[^=\n]*:?=\s*([\[{{])", text, re.M)
    if not m:
        return []
    is_dict = m.group(1) == "{"
    i, depth, quote, start = m.end(), 1, None, m.end()
    out: List[Any] = []
    item = ""
    while depth and i < len(text):
        c = text[i]
        if quote:
            if c == "\\":
                i += 2
                continue
            if c == quote:
                quote = None
                if depth == 1:
                    out_str = text[start:i]
                    j = i + 1
                    while j < len(text) and text[j] in " \t":
                        j += 1
                    if not is_dict or (j < len(text) and text[j] == ":"):
                        out.append(out_str)
        elif c in "\"'":
            quote = c
            start = i + 1
        elif c == "#":
            i = text.find("\n", i)
            if i < 0:
                break
            continue
        elif c in "[{(":
            depth += 1
        elif c in "]})":
            depth -= 1
        elif depth == 1 and not is_dict and (c.isdigit() or c == "-"):
            j = i
            while j < len(text) and (text[j].isdigit() or text[j] in "-."):
                j += 1
            num = text[i:j]
            out.append(float(num) if "." in num else int(num))
            i = j
            continue
        i += 1
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
    if len(_field_problems(planted, [("a", "A"), ("b", "B")], "Base")) != 2:
        warn("check_fields: its control did not fail - the check proves nothing")
    scene_a = 'const KINDS := ["a", "b"]\nfunc build_params(rng):\n\tvar k = choice("kind", rng)\n'
    scene_b = ('const FIELDS := {"kind": {"label": "Kind", "type": "choice", "options": "SORTS", "default": null, '
               '"blurb": "x"}}\nconst KINDS := ["a"]\nfunc build_params(rng):\n\tvar k = choice("kind", rng)\n')
    scene_c = ('const FIELDS := {"size": {"label": "Size", "type": "num", "range": [2.0, 1.0], "default": null, '
               '"blurb": "x"}}\nfunc build_params(rng):\n\tvar s = number("size", rng)\n\tvar r = number("rim", rng)\n')
    if len(_scene_field_problems(scene_a, "a")) != 1 or len(_scene_field_problems(scene_b, "b")) != 1 \
            or len(_scene_field_problems(scene_c, "c")) != 2:
        warn("check_fields: its scenes' control did not fail - the check proves nothing")
    for rel, base in [("src/scene_kit/layer.gd", "Base"), ("src/motion/primitives.gd", "Force")]:
        text = (ROOT / rel).read_text()
        for problem in _field_problems(_class_bodies(text), _parse_registry_dict(text), base):
            warn(f"{rel}: {problem}")
    for path in sorted((ROOT / "src" / "scenes").glob("*.gd")):
        for problem in _scene_field_problems(path.read_text(), path.stem):
            warn(f"{path.relative_to(ROOT)}: {problem}")


def _missing_paths(text: str) -> List[str]:
    """The `src/<...>.gd` and `tests/<...>.gd` paths written in [text] that are not on disk."""
    found = re.findall(r"(?<![\w/])(?:res://)?((?:src|tests)/[a-z_0-9]+(?:/[a-z_0-9]+)*\.gd)\b", text)
    return [rel for rel in sorted(set(found)) if not (ROOT / rel).exists()]


def check_paths() -> None:
    """A script path written in code names a script that exists.

    A class name is global, so a script that moves folders breaks nothing the compiler can see -
    and a `load("res://src/...")` built from a string, a `--script` argument, a row of a registry
    that names its script by path, or a gate that reads a source file as text breaks at the
    moment it runs, in whichever session reaches it first. `compile_check` loads every script and
    never follows a string. This reads every `src/<...>.gd` written in the code, the gates, the
    rules, the storyboards, the shaders and the two orientation files, and names any that is not
    on disk. The notes in next/ are left out: they are allowed to remember a file that is gone.

    THE CONTROL, run first: a path that names nothing must be found, and one that names a real
    script must not be.
    """
    if _missing_paths('load("res://src/platform/no_such_script.gd")') != [
        "src/platform/no_such_script.gd"
    ] or _missing_paths("src/platform/settings.gd and res://src/show/director.gd"):
        warn("check_paths: its control did not fail - the check proves nothing")
    roots = ["src", "tests", "rules", "storyboards", "shaders", "scenes", "hosts", "scripts"]
    files = [ROOT / "project.godot", ROOT / "CLAUDE.md", ROOT / "README.md"]
    for r in roots:
        files += [p for p in (ROOT / r).rglob("*") if p.is_file()]
    kinds = {".gd", ".tscn", ".godot", ".cfg", ".py", ".sh", ".md", ".yaml", ".yml",
             ".gdshader", ".gdshaderinc"}
    for p in sorted(files):
        if not p.exists() or p.suffix not in kinds or "__pycache__" in p.parts:
            continue
        try:
            text = p.read_text()
        except UnicodeDecodeError:
            continue
        for rel in _missing_paths(text):
            warn(f"{p.relative_to(ROOT).as_posix()} names {rel}, which does not exist")


def _comment_off(line: str, mark: str) -> str:
    """[line] up to its comment (`#` in GDScript, `//` in a shader); a mark inside a string is kept."""
    quote, i = None, 0
    while i < len(line):
        c = line[i]
        if quote:
            if c == "\\":
                i += 2
                continue
            if c == quote:
                quote = None
        elif c in "\"'":
            quote = c
        elif line.startswith(mark, i):
            return line[:i]
        i += 1
    return line


def _uid_references(text: str, suffix: str) -> List[Tuple[int, str]]:
    """The `uid://` references in a file Godot reads, as (line, uid). A scene's or resource's own
    header (`[gd_scene ... uid=...]`) names the file itself, not another, and a comment refers to
    nothing. Pure, for the control."""
    out = []
    for n, line in enumerate(text.splitlines(), 1):
        if n == 1 and line.startswith(("[gd_scene", "[gd_resource")):
            continue
        if suffix == ".gd":
            line = _comment_off(line, "#")
        elif suffix in (".gdshader", ".gdshaderinc"):
            line = _comment_off(line, "//")
        elif line.lstrip().startswith(";"):
            continue
        out += [(n, m.group(0)) for m in re.finditer(r"uid://\w*", line)]
    return out


UID_OVERRIDE = "text_editor/behavior/files/drop_preload_resources_as_uid=false"


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
    if _user_dir(renamed) == USER_DIR or _user_dir(named) != USER_DIR:
        warn("check_user_dir: its control did not fail - the check proves nothing")
    got = _user_dir((ROOT / "project.godot").read_text())
    if got != USER_DIR:
        warn(f"project.godot: user:// would be <data>/{got}, but the user's data is in <data>/{USER_DIR}: "
             f'name the folder - config/use_custom_user_dir=true, config/custom_user_dir_name="{USER_DIR}"')


def check_no_uids() -> None:
    """A file is named by its `res://` path, never a `uid://`.

    Since Godot 4.4 every script and shader has a `.uid` beside it, so a reference by UID survives
    a move the editor never saw. ghost names its files in code (`preload`, `load`, a registry's
    `script`, a `--script` argument), and a move is a path edit that `check_paths` and
    `compile_check` hold, so the `.uid` files are read by nothing and gitignored: each checkout
    mints its own. A `uid://` naming another file would then resolve in the checkout that wrote it
    and nowhere else - a bare `preload("uid://...")` has no path to fall back on, and a scene's
    `ext_resource` by UID warns and churns between checkouts. The editor writes one when a file
    is dropped into the script editor, unless `project.godot`'s `[editor_overrides]` turns that
    off (UID_OVERRIDE, held here too), and when it saves a scene or resource that references
    another file: this catches either.

    THE CONTROL, run first: a planted `preload("uid://...")` and an `ext_resource` by UID must be
    found, and a scene's own header UID and a comment that mentions one must not.
    """
    found = [
        _uid_references('const A := preload("uid://b1x")', ".gd"),
        _uid_references('[ext_resource type="Script" uid="uid://b1x" path="res://a.gd" id="1"]', ".tscn"),
    ]
    quiet = [
        _uid_references('[gd_scene format=3 uid="uid://b1x"]', ".tscn"),
        _uid_references('# never preload("uid://b1x")', ".gd"),
    ]
    if any(len(f) != 1 for f in found) or any(quiet):
        warn("check_no_uids: its control did not fail - the check proves nothing")
    project = (ROOT / "project.godot").read_text()
    if not re.search(r"^\[editor_overrides\]\n(?:[^\[\n].*\n|\n)*?" + re.escape(UID_OVERRIDE) + "$",
                     project, re.M):
        warn(f"project.godot: [editor_overrides] must keep {UID_OVERRIDE}, or a file dropped "
             "into the script editor is preloaded by a UID only this checkout knows")
    files = [ROOT / "project.godot", ROOT / "export_presets.cfg"]
    for r in ["src", "tests", "scenes", "shaders", "fonts", "data"]:
        if (ROOT / r).is_dir():
            files += [p for p in (ROOT / r).rglob("*") if p.is_file()]
    kinds = {".gd", ".tscn", ".tres", ".godot", ".cfg", ".gdshader", ".gdshaderinc"}
    for p in sorted(files):
        if p.suffix not in kinds:
            continue
        try:
            text = p.read_text()
        except (FileNotFoundError, UnicodeDecodeError):
            continue
        for n, uid in _uid_references(text, p.suffix):
            warn(f"{p.relative_to(ROOT).as_posix()}:{n} names a file by {uid}: name it by its "
                 "res:// path (the .uid files are gitignored, so a UID holds in one checkout only)")


def _render_structure_doc(edges: Dict[str, set]) -> str:
    """docs/structure.md: the stack, what each folder names, and what still points up."""
    order = [folder for folder, _t, _d in FOLDERS]
    rank = {folder: i for i, folder in enumerate(order)}
    names: Dict[str, set] = {folder: set() for folder in order}
    inside = down = 0
    for a, bs in edges.items():
        for b in bs:
            fa, fb = a.split("/")[0], b.split("/")[0]
            if fa == fb:
                inside += 1
            elif rank[fb] < rank[fa]:
                down += 1
                names[fa].add(fb)
    up = sum(len(pairs) for _p, _f, pairs in UPWARD)
    lines = [
        AUTOGEN_HEADER,
        "# The structure",
        "",
        "`src/` is one level of folders, and the folders are a STACK. A script names "
        "scripts in its own folder and in the folders below it, and nothing above: what a "
        "part reads from higher up is handed to it. So the folders a change can reach are "
        "the ones above the folder it is in, and a folder near the bottom can be read "
        "without knowing anything over it.",
        "",
        "Written from `FOLDERS` and `UPWARD` in [docs.py](../docs.py), which holds the code "
        "to both at every `python docs.py --check`: a new reference that points up fails, "
        "and so does a listed one that is gone. [next/structure.md](../next/structure.md) "
        "is why the stack is in this order and what is being done about the rest.",
        "",
        f"Between scripts today: {inside} references inside a folder, {down} down the "
        f"stack, {up} up it.",
        "",
        "## The stack, top first",
        "",
        "| folder | what it is | scripts | names |",
        "| --- | --- | --- | --- |",
    ]
    for folder, title, _desc in reversed(FOLDERS):
        count = len(list((SCRIPTS / folder).glob("*.gd")))
        below = ", ".join(f"`{n}`" for n in sorted(names[folder], key=lambda n: -rank[n]))
        lines.append(f"| `{folder}/` | {title} | {count} | {below or 'nothing'} |")
    lines.extend(["", "## The folders, bottom first", ""])
    for folder, title, desc in FOLDERS:
        lines.extend([f"### `{folder}/` - {title}", "", desc, ""])
        if folder == "scenes":
            continue
        lines.append(
            ", ".join(f"[`{s.name}`](../{s.rel})" for s in _folder_scripts(folder))
        )
        lines.append("")
    lines.extend(["## What still points up", ""])
    if not UPWARD:
        lines.extend(
            [
                "Nothing. Every reference between scripts stays in its folder or points down, "
                "and `python docs.py --check` fails the first one that does not.",
                "",
            ]
        )
    else:
        lines.extend(
            [
                f"{up} references, in {len(UPWARD)} patterns. Each row is a script naming one "
                "above it; a pattern's rows go when its fix lands.",
                "",
            ]
        )
    for pattern, fix, pairs in UPWARD:
        lines.extend([f"### {pattern} ({len(pairs)})", "", f"The fix: {fix}.", ""])
        for a, b in pairs:
            lines.append(f"- `{a}` names `{b}`")
        lines.append("")
    return "\n".join(lines).rstrip() + "\n"


def _reprefix(desc: str) -> str:
    """Rebase repo-root-relative markdown links for use inside docs/."""
    return re.sub(
        r"\]\((?!https?:|/|#|\.\.?/)([^)]+)\)", lambda m: f"](../{m.group(1)})", desc
    )


def _docs_relative(path: str) -> str:
    """A repo-relative path as docs/index.md links it."""
    return path[len("docs/") :] if path.startswith("docs/") else f"../{path}"


def _render_layout_block(link_prefix: str = "") -> str:
    """The top-level layout as a list, each entry linked where it is in the repository (a
    git-ignored runtime folder is not, since it is not there to link to). `link_prefix` rebases
    the links for a page outside the root (`../` from docs/)."""
    lines = []
    for name, desc in TOP_LEVEL:
        label = f"`{name}`"
        if "git-ignored" not in desc:
            label = f"[{label}]({link_prefix}{name})"
        lines.append(f"- **{label}** - {_reprefix(desc) if link_prefix else desc}")
    return "\n".join(lines)


def _render_readme_features_block(features: List[Tuple[str, str, str, str]]) -> str:
    lines = [
        "Ghost Notes is built from registries. Each page below is generated from one, listing "
        "every entry and where it lives; [docs/index.md](docs/index.md) is the whole map.",
        "",
    ]
    for slug, title, count, desc in features:
        lines.append(f"- [{title}](docs/{slug}.md) ({count}) - {desc}")
    return "\n".join(lines)


def _render_readme_subsystems_block() -> str:
    lines = ["Documented outside the registry pages.", ""]
    for title, path, desc in SUBSYSTEMS:
        lines.append(f"- [{title}]({path}) - {desc}")
    return "\n".join(lines)


def _render_readme_layout_block() -> str:
    return (
        "Top-level layout; every script is in [docs/index.md](docs/index.md).\n\n"
        + _render_layout_block()
    )


def _sort_roadmap() -> None:
    """Keep next/roadmap.md's open items above its closed ones, as praxis/docs.py keeps its own:
    each group sorted by length, open shortest first, closed longest first. Stable, so items of
    equal length keep their order; idempotent."""
    path = ROOT / "next" / "roadmap.md"
    if not path.exists():
        return
    text = path.read_text()
    first = re.search(r"^- \[[ xX]\] ", text, re.M)
    if not first:
        return
    preamble, body = text[: first.start()], text[first.start() :]
    starts = [m.start() for m in re.finditer(r"^- \[[ xX]\] ", body, re.M)]
    blocks = [
        body[s : (starts[i + 1] if i + 1 < len(starts) else len(body))].rstrip("\n")
        for i, s in enumerate(starts)
    ]
    opens = sorted((b for b in blocks if re.match(r"- \[ \] ", b)), key=len)
    closed = sorted(
        (b for b in blocks if re.match(r"- \[[xX]\] ", b)), key=len, reverse=True
    )
    _write_if_changed(
        path, preamble.rstrip("\n") + "\n\n" + "\n\n".join(opens + closed) + "\n"
    )


# ---------------------------------------------------------------------------
# Output plumbing
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
    begin = f"<!-- AUTODOC:{name}:BEGIN -->"
    end = f"<!-- AUTODOC:{name}:END -->"
    if begin not in current or end not in current:
        warn(f"README.md missing AUTODOC:{name} markers - block not patched")
        return
    block = f"{begin}\n\n{body.rstrip()}\n\n{end}"
    before, _, rest = current.partition(begin)
    _, _, after = rest.partition(end)
    _write_if_changed(readme, before + block + after)


def main() -> int:
    if "--folders" in sys.argv[1:]:
        # the stack, bottom first, one a line: what scripts/check.sh --for reads
        print("\n".join(folder for folder, _t, _d in FOLDERS))
        return 0
    # Every script but the scenes, by file name (a scene is read from SCENES_DIR).
    scripts: Dict[str, Script] = {}
    for p in sorted(SCRIPTS.glob("*/*.gd")):
        if p.parent == SCENES_DIR:
            continue
        if p.stem in scripts:
            warn(f"two scripts are named {p.stem}.gd: {scripts[p.stem].rel} and "
                 f"{p.relative_to(ROOT).as_posix()}")
        scripts[p.stem] = Script(p)
    scenes, groups = _collect_scenes()
    edges = check_structure()
    check_paths()
    check_no_uids()
    check_user_dir()
    check_fields()
    check_panel_controls()
    check_settings_owner()
    check_films_pumped()

    layer = scripts["layer"]
    prims = scripts["primitives"]
    comp = scripts["components"]
    live = sum(1 for s in scenes.values() if s.behaviors)
    # The registry-backed pages: (slug, title, count, one line). One source for docs/index.md
    # and the README's FEATURES block, every count read from the registry it names.
    features = [
        (
            "components",
            "Components",
            f"{len(_gd_entries(comp.text, 'REGISTRY'))} components, "
            f"{len(_gd_entries(comp.text, 'WORKSPACES'))} workspaces",
            "what a note can carry, the room each part takes, which panel runs it, and "
            "what each part asks of the platform.",
        ),
        (
            "scenes",
            "Scenes",
            str(live),
            "the visualizer scenes in the rotation, each from its own doc comment.",
        ),
        ("media", "Media", str(len(_media_pairs(scripts["medium"]))), "what the show is carried on."),
        (
            "filters",
            "Look filters",
            str(len(_filter_pairs(scripts["filters"]))),
            "the post-process over the whole picture.",
        ),
        (
            "layers",
            "Layers",
            str(len(_parse_registry_dict(layer.text))),
            "the visual components scenes compose - weather, skies, atmosphere.",
        ),
        (
            "forces",
            "Forces",
            str(len(_parse_registry_dict(prims.text))),
            "the physics primitives particles compose.",
        ),
        (
            "stage",
            "Stage actors and verbs",
            f"{len(_parse_registry_dict(scripts['cast'].text))} actors, "
            f"{len(_parse_registry_dict(scripts['actions'].text))} verbs",
            "what a storyboard's `stage` entries are made of.",
        ),
        (
            "masking",
            "Masking effects",
            str(len(_mask_effects(scripts["mask_session"]))),
            "the video effects editor: its model, its effects and its headless tools.",
        ),
        (
            "script",
            "Script marks",
            str(len(_script_entries(scripts["script_marks"]))),
            "every mark a script may carry - the script editor's palette.",
        ),
        (
            "agents",
            "Agents",
            f"{len(_rows(scripts['text_gen'].text, 'REGISTRY'))} writers, "
            f"{len(_rows(scripts['image_gen'].text, 'REGISTRY'))} painters, "
            f"{len(_gd_entries(scripts['assistant_backends'].text, 'REGISTRY'))} assistants",
            "the AI command-line tools Ghost Notes hands its words, pictures and fixes to: which "
            "does what, how each is run, and how to install one.",
        ),
    ]

    _write_if_changed(
        DOCS / "components.md", _render_components_doc(comp, scripts["capabilities"])
    )
    _write_if_changed(DOCS / "scenes.md", _render_scenes_doc(scenes, groups))
    _write_if_changed(
        DOCS / "layers.md",
        _render_registry_page(
            "Layers: the visual-component registry",
            "Reusable appearance components any scene composes by key via "
            "`add_layer` / `update_layers` / `draw_layers(z)`.",
            layer,
            _parse_registry_dict(layer.text),
        ),
    )
    _write_if_changed(
        DOCS / "forces.md",
        _render_registry_page(
            "Forces: the physics-primitive registry",
            "Reusable force modules a scene composes into a `ParticleSystem` "
            "by key.",
            prims,
            _parse_registry_dict(prims.text),
        ),
    )
    _write_if_changed(
        DOCS / "stage.md",
        _render_stage_doc(
            scripts["cast"], scripts["actions"], scripts["track"], scripts["storyboard"]
        ),
    )
    _write_if_changed(
        DOCS / "masking.md",
        _render_masklab_doc(scripts["mask_session"], scripts["mask_editor"]),
    )
    _write_if_changed(DOCS / "media.md", _render_media_doc(scripts["medium"]))
    _write_if_changed(DOCS / "filters.md", _render_filters_doc(scripts["filters"]))
    _write_if_changed(DOCS / "script.md", _render_script_doc(scripts["script_marks"]))
    _write_if_changed(
        DOCS / "architecture.md",
        _render_architecture_doc(_class_index(), scenes, layer, prims, scripts["medium"]),
    )
    _write_if_changed(DOCS / "environment.md", _render_environment_doc(scripts["deps"]))
    _write_if_changed(
        DOCS / "agents.md",
        _render_agents_doc(
            scripts["text_gen"], scripts["image_gen"], scripts["assistant_backends"], scripts["deps"]
        ),
    )
    _write_if_changed(DOCS / "structure.md", _render_structure_doc(edges))
    _write_if_changed(DOCS / "cli.md", _render_cli_doc(_scan_flags()))
    _write_if_changed(DOCS / "index.md", _render_index(scripts, scenes, features))

    _patch_readme_block("FEATURES", _render_readme_features_block(features))
    _patch_readme_block("SUBSYSTEMS", _render_readme_subsystems_block())
    _patch_readme_block("LAYOUT", _render_readme_layout_block())
    _sort_roadmap()

    print(
        f"[ghost-docs] done: {len(scenes)} scenes, "
        f"{len(scripts)} scripts, {len(WARNINGS)} warning(s)."
    )
    if CHECK:
        for path in STALE:
            print(f"[ghost-docs] STALE {path} - run `python docs.py`")
        return 1 if STALE or WARNINGS else 0
    return 0


if __name__ == "__main__":
    sys.exit(main())
