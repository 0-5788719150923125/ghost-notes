#!/usr/bin/env python3
"""Auto-docs generator for ghost.

The Praxis move (see praxis/docs.py) applied to a Godot project: introspect
the source of record and generate the documentation from it, so the docs
cannot drift from the code. Here the source of record is the GDScript
itself - every script carries a leading `##` doc comment, the scene roster
is the literal `Director.SCENES` array, the component registries are
literal `const REGISTRY := {...}` dictionaries, and the Masking effect
table is `MASK_EFFECTS` / `EFFECT_CONTROLS`. This script parses all of
that statically (no Godot boot required) and writes:

  docs/index.md        - the map: design, the pages, directory layout, every script.
  docs/components.md   - what a note can carry: components, templates, capabilities.
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

import re
import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple

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

# (group title, group description, [script filenames under src/]).
SCRIPT_GROUPS: List[Tuple[str, str, List[str]]] = [
    (
        "Audio & analysis",
        "From a song file to the typed per-frame `AudioFeatures` every scene "
        "consumes - live analyzer, offline bake, and the content descriptors "
        "that make sessions deterministic per song.",
        [
            "spectrum.gd",
            "audio_features.gd",
            "bake.gd",
            "bake_runner.gd",
            "harmonic_signature.gd",
            "echo.gd",
        ],
    ),
    (
        "Direction & session",
        "The lifecycle around the scenes: boot, the notes list, the Director's "
        "scheduling/transitions, the manual Workspace, and the Dial "
        "performance controls.",
        [
            "main.gd",
            "boot.gd",
            "subprocess.gd",
            "deps.gd",
            "deps_panel.gd",
            "provision.gd",
            "provisioner.gd",
            "provision_badge.gd",
            "chrome.gd",
            "capabilities.gd",
            "components.gd",
            "side_panel.gd",
            "card.gd",
            "card_row.gd",
            "look_card.gd",
            "bookends_card.gd",
            "picture_card.gd",
            "console.gd",
            "notes_list.gd",
            "phone_shell.gd",
            "note_panel.gd",
            "note_store.gd",
            "director.gd",
            "settings.gd",
            "medium.gd",
            "filters.gd",
            "comic_page.gd",
            "comic_spread.gd",
            "book_layout.gd",
            "notebook_layout.gd",
            "tablet_page.gd",
            "page_capture.gd",
            "films.gd",
            "illustrations.gd",
            "image_gen.gd",
            "illustration_panel.gd",
            "workspace.gd",
            "dial.gd",
            "dial_widget.gd",
            "volume_knob.gd",
            "transport.gd",
            "tag_field.gd",
        ],
    ),
    (
        "Scene substrate",
        "What every scene is built on: the `GhostScene` base, the camera, "
        "framing pools, seeded motion, sparse response gating, lighting, and "
        "the organic primitives (curves, flow fields, growth).",
        [
            "ghost_scene.gd",
            "scene_view.gd",
            "shots.gd",
            "mod_bank.gd",
            "activation.gd",
            "lighting.gd",
            "nonlinear.gd",
            "flow.gd",
            "filament.gd",
            "swarm.gd",
            "sim_clock.gd",
        ],
    ),
    (
        "Generative form",
        "Self-contained generators a scene composes rather than hand-models - "
        "each one samples a space of shapes from a seed and hands back plain "
        "geometry. The `cattle, not pets` discipline, made into parts.",
        [
            "crystal.gd",
            "glyphs.gd",
            "wallpaper_group.gd",
            "branch3d.gd",
            "contour.gd",
        ],
    ),
    (
        "Simulation substrates",
        "Running physical systems whose STATE is the picture, rather than "
        "drawings of one: a granular automaton, a flock with a spatial hash, "
        "a plate's standing waves, and a water surface.",
        [
            "grains.gd",
            "boids.gd",
            "plate_field.gd",
            "wave_field.gd",
        ],
    ),
    (
        "Rendering & performance",
        "How a heavy scene stays interactive: thousands of shapes in one "
        "draw call, and the geometry for them built off the main thread.",
        ["tri_batch.gd", "frame_forge.gd"],
    ),
    (
        "Composition registries",
        "The two shared registries scenes compose by key - appearance "
        "(`Layer`) and physics (`Primitives`) - plus the particle substrate "
        "the forces act on.",
        [
            "layer.gd",
            "primitives.gd",
            "particle.gd",
            "particle_system.gd",
        ],
    ),
    (
        "3D path",
        "The unified software-3D renderer: a positionable perspective camera, "
        "mesh/plane primitives, procedural fields, palettes, terrain "
        "heightfields, and shadowing.",
        [
            "lens3d.gd",
            "plane3d.gd",
            "scene3d.gd",
            "mesh3d.gd",
            "geometry.gd",
            "field.gd",
            "scheme.gd",
            "palette.gd",
            "terrain.gd",
            "shadow_field.gd",
        ],
    ),
    (
        "Bodies",
        "Reusable composed characters - sampled stacks of primitives, not "
        "bespoke meshes.",
        ["eye_body.gd", "prism_body.gd"],
    ),
    (
        "Synthesis (voice)",
        "Text to narrated audio in two paths: ghost's own source-filter "
        "synthesizer (no models, no weights, fully inspectable, and the only "
        "path that can sing), and a small local neural voice run by a "
        "subprocess host. Shared between them: the source of the words (the "
        "text box, or a Markdown file on disk re-read at every Play, whose "
        "frontmatter carries the voice), the text front end and its "
        "normalization, the threaded real-time stream, karaoke subtitles, and "
        "the buffer effects. Design: next/voice.md.",
        [
            "phonemes.gd",
            "text_norm.gd",
            "phrasing.gd",
            "voice.gd",
            "voice_field.gd",
            "voice_stream.gd",
            "synth_editor.gd",
            "voice_sampler.gd",
            "doc_source.gd",
            "front_matter.gd",
            "manuscript.gd",
            "tablet_script.gd",
            "script_marks.gd",
            "script_highlighter.gd",
            "script_writer.gd",
            "subtitles.gd",
            "voice_host.gd",
            "reading_panel.gd",
            "generative_editor.gd",
            "voice_readers.gd",
            "voice_fx.gd",
            "room_fx.gd",
        ],
    ),
    (
        "Tarot",
        "An automatic tarot reading: a show's brief, its episodes - each "
        "planned, painted and written by agents one card at a time, kept on "
        "disk step by step - and the table they are read at, in the Generative "
        "voice, with the things on it modeled from a written description "
        "(Props). Design: next/tarot.md.",
        [
            "tarot_editor.gd",
            "table_actions.gd",
            "table_positions.gd",
            "dealer_tools.gd",
            "tarot_producer.gd",
            "tarot_episode.gd",
            "tarot_prompts.gd",
            "tarot_script.gd",
            "tarot_deck.gd",
            "tarot_table.gd",
            "tarot_cards.gd",
            "props.gd",
            "effects.gd",
            "set_dresser_tools.gd",
            "table_preview.gd",
        ],
    ),
    (
        "Agents",
        "Every piece of writing and painting ghost asks an AI for: who writes "
        "(TextGen) and who paints (ImageGen), one queue for both (AgentJobs), "
        "the tools ghost serves an agent while it works (AgentTools), "
        "which Amazon Bedrock models an AWS account can call (BedrockCatalog), "
        "and where a reading's voice is in its document (ReadingFollower).",
        [
            "text_gen.gd",
            "agent_jobs.gd",
            "agent_tools.gd",
            "bedrock_catalog.gd",
            "reading_follower.gd",
        ],
    ),
    (
        "Storyboards & stage",
        "Manual mode as data: the YAML-subset parser, the storyboard loader, "
        "and the Cast/Actions/Track stack that renders a described scene. "
        "See [storyboards/README.md](../storyboards/README.md) for the data "
        "spec and [stage.md](stage.md) for the actor/verb registries.",
        ["yaml.gd", "storyboard.gd", "cast.gd", "actions.gd", "track.gd"],
    ),
    (
        "Masking",
        "The video chroma-key masking editor - a second app surface inside "
        "ghost. See [masking.md](masking.md).",
        [
            "mask_session.gd",
            "mask_editor.gd",
            "mask_timeline.gd",
            "timeline_view.gd",
            "track_lane.gd",
            "mask_marker_tool.gd",
        ],
    ),
    (
        "Export",
        "Rendering a session to video (bake + Movie Maker, background "
        "processes), and uploading it to YouTube.",
        ["exporter.gd", "youtube.gd"],
    ),
    (
        "Feedback & assistant",
        "The in-app authoring loop: capture reproducible critiques, browse "
        "them, and dispatch automated fixes.",
        ["feedback.gd", "assistant.gd", "assistant_backends.gd"],
    ),
]

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
        "Open one note, run by the template its blocks say it is (a voice is Generative, a show "
        "Tarot, a song Auto, nothing attached a plain note) - past the notes list.",
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
        "[all|update]",
        "Install ghost's own dependencies now, printing each step, then exit: uv, "
        "FFmpeg and Python by default, every feature's environment too with `all`, or "
        "bring everything installed to its newest release with `update`. The same jobs "
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
    ("--dial-demo", "", "Auto-turn the first Dial hands-free (demos, renders).", False),
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
        "--tarot",
        "",
        "Open the tarot mode: a show's brief, its episodes (planned, painted and written by "
        "agents one card at a time) and the Generative voice that reads them at the table.",
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
    ("--bake-song", "<path>", "`bake_runner`: the song to analyze.", True),
    ("--bake-out", "<path>", "`bake_runner`: where to write the bake cache.", True),
]

# Flags that belong to the Godot engine itself (or are argument separators),
# excluded from the drift check.
ENGINE_FLAGS = {
    "--headless",
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
    # ...and TextGen's bare writers (the tarot mode's agents): no tools, no project, no session
    "--safe-mode",
    "--tools",
    "--system-prompt-file",
    "--no-session-persistence",
    "--input-format",
    "--effort",
    "--ephemeral",
    # ...and a writer working with ghost's own tools (AgentTools): their config, nothing else's
    "--mcp-config",
    "--strict-mcp-config",
    "--allowedTools",
    "--setting-sources",
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
        "All GDScript. Per-script map in [docs/index.md](docs/index.md); the "
        "subsystem groups are described there too.",
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
        "The GPU shaders: the Look, every Masking effect, the tarot table and a few scenes.",
    ),
    (
        "storyboards/",
        "Manual-mode scene scores (YAML; JSON accepted). "
        "[storyboards/README.md](storyboards/README.md) is the data spec.",
    ),
    (
        "data/",
        "Data the code reads - pronunciation (CMUdict, `english.yml`), the LibriTTS speaker "
        "table, the tarot's - each license beside its file.",
    ),
    ("fonts/", "Faces the media draw with: the notebook's handwriting and the tarot's lettering."),
    (
        "hosts/",
        "The Python hosts ghost spawns, each in an environment of its own the Provisioner builds "
        "(`src/deps.gd`): `voice/` the neural voice, `face/` Masking's face and body pre-passes, "
        "`capture/` the tablet's page capture. Kept out of the exported .pck.",
    ),
    (
        "scripts/",
        "Build and check scripts: `scripts/check.sh` runs every gate (`--gpu` adds the ones "
        "that need a real renderer), `scripts/build.sh` exports a target into `dist/`.",
    ),
    (
        "tests/",
        "The gates (`*_check.gd`), probes (`*_probe.gd`) and their runners; "
        "`scripts/check.sh` runs them all.",
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
    ("CLI flags", "docs/cli.md", "every command-line flag."),
    ("Storyboards", "storyboards/README.md", "the data spec Manual notes are written in."),
]

AUTOGEN_HEADER = "<!-- AUTOGENERATED by docs.py - do not edit by hand -->"


# ---------------------------------------------------------------------------
# GDScript parsing
# ---------------------------------------------------------------------------


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
    """Parse Director.SCENES into (scene name, behavior, group comment)."""
    m = re.search(r"const SCENES :?= \[(.*?)\n\]", director_text, re.S)
    if not m:
        warn("could not parse Director.SCENES")
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


def _collect_scenes() -> Tuple[Dict[str, SceneInfo], List[str]]:
    """All scenes on disk, annotated with their Director registration.
    Returns (name -> SceneInfo, ordered group labels)."""
    scenes = {p.stem: SceneInfo(Script(p)) for p in sorted(SCENES_DIR.glob("*.gd"))}
    roster = _parse_scene_roster((SCRIPTS / "director.gd").read_text())
    groups: List[str] = []
    for name, behavior, group in roster:
        if name not in scenes:
            warn(f"Director.SCENES registers scenes/{name}.gd which does not exist")
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
        "`Director.SCENES` pairs it with one or more **behaviors** "
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
                "`Director.SCENES` - reachable only by storyboard (`stage`), "
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
    for key, cls in pairs:
        doc, line = inner.get(cls, ("", None))
        lines.append(f"## `{key}` - {cls}")
        lines.append("")
        if doc:
            lines.extend([doc, ""])
        else:
            warn(f"{script.rel}: class {cls} (registry key '{key}') has no doc comment")
        lines.append(f"Source: {_source_link(script.rel, line)}")
        lines.append("")
    return "\n".join(lines).rstrip() + "\n"


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
    labels = dict(
        re.findall(r'"(\w+)":\s*"([^"]*)"', _const_block(base.text, "LABELS"))
    )
    blurbs = dict(
        re.findall(r'"(\w+)":\s*"([^"]*)"', _const_block(base.text, "BLURBS"))
    )
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
    for key, stem in pairs:
        path = MEDIA_DIR / f"{stem}.gd"
        if not path.exists():
            warn(f"Medium.REGISTRY registers media/{stem}.gd which does not exist")
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
    for path in sorted(MEDIA_DIR.glob("*.gd")):
        if path.stem not in [stem for _k, stem in pairs]:
            warn(
                f"src/media/{path.stem}.gd is not registered in "
                "Medium.REGISTRY - it can never be selected"
            )
    return "\n".join(lines).rstrip() + "\n"


def _render_filters_doc(base: Script) -> str:
    """docs/filters.md, from Filters.REGISTRY + LABELS/BLURBS and the shader's own header.

    Not _render_registry_page: a filter is neither an inner class nor a script, it is a
    uniform and a block of GLSL - so the per-entry text comes from BLURBS and the how
    comes from the shader file's header, which is where the pipeline is written down.

    It also CHECKS the pair, which is this table's own failure mode: a registry key whose
    uniform the shader does not declare ships as a control that does nothing, because
    `set_shader_parameter` on an unknown name is silent. tests/stage_filter_check.gd
    asserts the same thing at runtime; this is so a docs run says it too."""
    pairs = _filter_pairs(base)
    if not pairs:
        warn("could not parse Filters.REGISTRY")
    labels = dict(
        re.findall(r'"(\w+)":\s*"([^"]*)"', _const_block(base.text, "LABELS"))
    )
    blurbs = dict(
        re.findall(r'"(\w+)":\s*"([^"]*)"', _const_block(base.text, "BLURBS"))
    )
    defaults = dict(
        re.findall(r'"(\w+)":\s*([0-9.]+)', _const_block(base.text, "DEFAULTS"))
    )
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
        for table in ("LABELS", "BLURBS", "DEFAULTS"):
            if key not in (
                labels
                if table == "LABELS"
                else blurbs if table == "BLURBS" else defaults
            ):
                warn(f"Filters.{table} has no entry for '{key}'")
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
        rows.append((key, f))
    lines = [
        AUTOGEN_HEADER,
        "# Writing a script",
        "",
        "Every mark a Generative or Synthesis script may carry - the list the "
        "script editor's palette (**Edit script…** on either panel) is built "
        "from, and the patterns it highlights with. A script is Markdown; "
        "YAML frontmatter at the top is the panel's and never shown in the "
        "editor or spoken.",
        "",
        _full_doc(marks.doc),
        "",
        f"Registry: `ScriptMarks.REGISTRY` in {_source_link(marks.rel)} "
        f"({len(rows)} entries). Each one is proven against the parser that "
        "reads it by `tests/script_marks_check.gd`.",
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
            lines.append(f"| {f['label']} | `{ex}` | {panels} | {f['blurb']} |")
        lines.append("")
    for k, f in rows:
        if f["group"] not in [g for g, _ in groups]:
            warn(f"ScriptMarks.REGISTRY['{k}'] names unknown group '{f['group']}'")
    return "\n".join(lines).rstrip() + "\n"


def _render_stage_doc(cast: Script, actions: Script, track: Script) -> str:
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
            "`src/mask_marker_tool.gd` inserts one marker into a saved "
            "session from the command line (no editor boot): ",
            "",
            "```",
            "godot --headless --path . --script src/mask_marker_tool.gd \\",
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
    src = (SCRIPTS / "mask_editor.gd").read_text(encoding="utf-8")
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
    main = (SCRIPTS / "main.gd").read_text(encoding="utf-8")
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
                "Settings (src/settings.gd), which owns the file, the debounce "
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
    """Medium.REGISTRY as (key, script stem)."""
    return re.findall(
        r'"(\w+)":\s*"res://src/media/(\w+)\.gd"', _const_block(base.text, "REGISTRY")
    )


def _filter_pairs(base: Script) -> List[Tuple[str, str]]:
    """Filters.REGISTRY as (key, uniform)."""
    return re.findall(r'"(\w+)":\s*"(u_\w+)"', _const_block(base.text, "REGISTRY"))


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
    """docs/components.md, from Components.FAMILIES / REGISTRY / TEMPLATES and
    Capabilities.TABLE: what a note can carry, the templates New makes from it, and what
    each part asks of the platform."""
    families = re.findall(
        r'&"(\w+)":\s*\{"label":\s*"([^"]*)"', _const_block(comp.text, "FAMILIES")
    )
    entries = _gd_entries(comp.text, "REGISTRY")
    templates = _gd_entries(comp.text, "TEMPLATES")
    table = _gd_entries(caps.text, "TABLE")
    if not (families and entries and templates and table):
        warn("could not parse Components.FAMILIES / REGISTRY / TEMPLATES or Capabilities.TABLE")
    labels = {k: _gd_text(b, "label") for k, b in entries}
    family_of = {k: _first(b, r'"family":\s*&"(\w+)"') for k, b in entries}
    lines = [
        AUTOGEN_HEADER,
        "# Components and templates",
        "",
        "What a note can carry. A note is a markdown file, and each block under `ghost:` in "
        "its frontmatter is a component attached to it. **New** in the notes list makes a "
        "note from a template, **+** attaches more, and a note opens as the template its "
        "blocks say it is - or as a plain note, when nothing is attached.",
        "",
        _full_doc(comp.doc),
        "",
        f"Registries: `Components.REGISTRY` and `Components.TEMPLATES` in "
        f"{_source_link(comp.rel)} ({len(entries)} components, {len(templates)} templates).",
        "",
        "## Templates",
        "",
        "| Template | Components | What it is |",
        "| --- | --- | --- |",
    ]
    for _key, body in templates:
        parts = ", ".join(labels.get(c, c) for c in _gd_list(body, "components"))
        blurb = _md(_gd_text(body, "blurb")).replace("|", "\\|")
        lines.append(f"| **{_gd_text(body, 'label')}** | {parts} | {blurb} |")
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
            "installed by [src/provisioner.gd](../src/provisioner.gd). The panel and every program "
            "Ghost Notes starts ask the same resolver, so the panel cannot report a program "
            "present while a launch fails to find it.",
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

Register it in `Director.SCENES` - `{"script": preload("res://src/scenes/my_scene.gd"),
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

    features_src = (SCRIPTS / "audio_features.gd").read_text()
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
    labels = dict(re.findall(r'"(\w+)":\s*"([^"]*)"', _const_block(medium.text, "LABELS")))
    media = [labels.get(k, k) for k, _ in _media_pairs(medium)]
    portrait = [
        labels.get(k, k)
        for k, frames in re.findall(r'"(\w+)":\s*\[([^\]]*)\]', _const_block(medium.text, "FRAMES"))
        if '"portrait"' in frames
    ]
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
    lines.extend(["## Script map", ""])
    grouped = {f for _, _, files in SCRIPT_GROUPS for f in files}
    for title, desc, files in SCRIPT_GROUPS:
        lines.extend([f"### {title}", "", desc, ""])
        for fname in files:
            script = scripts.get(Path(fname).stem)
            if script is None:
                warn(f"docs.py SCRIPT_GROUPS lists {fname} which does not exist")
                continue
            one = _one_liner(script.doc, strip_name=script.class_name or "")
            label = script.class_name or script.name
            lines.append(f"- [`{fname}`](../src/{fname}) **{label}** - {one}")
        lines.append("")
    stray = sorted(p.name for p in SCRIPTS.glob("*.gd") if p.name not in grouped)
    if stray:
        warn("scripts not in docs.py SCRIPT_GROUPS: " + ", ".join(stray))
        lines.extend(
            [
                "### Unsorted (add to `SCRIPT_GROUPS` in docs.py)",
                "",
            ]
        )
        for fname in stray:
            script = scripts.get(Path(fname).stem)
            one = _one_liner(script.doc) if script else ""
            lines.append(f"- [`{fname}`](../src/{fname}) - {one}")
        lines.append("")
    lines.append(
        f"Scene scripts ({len(scenes)}) are cataloged separately in "
        "[scenes.md](scenes.md)."
    )
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
    scripts = {p.stem: Script(p) for p in sorted(SCRIPTS.glob("*.gd"))}
    scenes, groups = _collect_scenes()
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
            "Components and templates",
            f"{len(_gd_entries(comp.text, 'REGISTRY'))} components, "
            f"{len(_gd_entries(comp.text, 'TEMPLATES'))} templates",
            "what a note can carry, the templates **New** makes from it, and what each "
            "part asks of the platform.",
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
        _render_stage_doc(scripts["cast"], scripts["actions"], scripts["track"]),
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
