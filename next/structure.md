# The structure: folders that say what names what

Opened 2026-10-13, for the user's question: `src/` is one flat directory, bugs feel like
whack-a-mole, and Praxis is easy to read - would organizing ghost the way Praxis is organized
help? Yes, with one correction to the premise. This note is the measurement behind that answer,
the rules it led to, what was done that day, and what is left. It serves [notes.md](notes.md) and
[storyboard.md](storyboard.md) and changes nothing they decided: a note is still what is attached
to it, and components still meet only through what the note owns.

**The layout itself is not written here.** [docs/structure.md](../docs/structure.md) is: every
folder, bottom to top, what it is, what it names and every script in it, written by `docs.py` from
the same table that holds the code to it. This note is the why.

## The finding

**The code was already layered. The directory hid it, and nothing held it.**

Measured on the flat tree, 2026-10-13, by reading every script's references to another script
(class names, the five autoloads, `preload` and `load` paths; comments and strings left out):

- 228 scripts, 130,000 lines. 162 of them sat flat in `src/`; `scenes/` (59) and `media/` (7) were
  the only folders.
- Sorted into 22 folders stacked bottom to top, **703 of the 751 references that crossed a folder
  pointed down. 48 pointed up.**
- The 48 were why it did not feel layered. With them, 95 scripts sat in six dependency cycles, the
  largest 61 scripts wide: 55 scenes, the Director, `GhostScene`, `Scene3D`, `Layer`, `Medium` and
  `Subtitles`. Two lines held that one together - `Director.aura` in `ghost_scene.gd` (the fishing
  game's pull, read by every scene) and `Director.silence_floor` in `scenes/glyphs.gd`.
- `docs.py` already sorted every script into 16 groups for `docs/index.md`, from a hand list of
  162 file names. The grouping existed. It was not on disk, and one group ("Direction & session",
  44 scripts) was the shell, the platform, the panel kit, the notes, the Director and the media
  layouts together.

**The correction: moving files does not fix a bug.** What makes a fix in one place break another
is in the code, and a move does not touch it.

- **Ten files are 30% of the code.** `mask_editor.gd`: 8,376 lines, 316 member variables.
  `table.gd` (the card table's medium): 6,797 and 121. `reading_panel.gd`: 4,548 and 115. Every
  function in a file may read and write every variable in it, so in these three a change to one job
  is a change next to all the others. The week showed where that costs: of the 29 commits since the
  move to this repository that touch `src/`, 20 touch `table.gd`, and the next eight files by count
  are all Cards and the reading panel.
- **Inheritance where the plan says composition.** `CardsEditor` overrides 31 of `ReadingPanel`'s
  functions (notes.md: "Tarot inherits Generative and spends its effort removing things").
- **Globals read from anywhere.** Outside their own files, `Director` was named 189 times in 21
  scripts and `Spectrum` 154 times in 21. Most are one small read - a seed, a dial, the clock.
- **A registry kept inside the script that uses it.** The scene roster is `Director.SCENES`, so
  listing the scenes means loading the Director; 22 layers are one 2,326-line file.

So the folders were the cheap half: they put the structure where it can be seen and let a gate
hold it. The references that pointed up were the half that needed design, and they came in eight
patterns, not 48 problems. Both halves are done. The half that moves the bug count is the three
files above, and it is what is left.

## What Praxis does, and what of it was already here

Praxis is one package per AXIS OF VARIATION (attention, losses, encoders - about 55 of them, one
level deep). A package declares a registry namespace; everything else asks the registry by name and
never imports an implementation; one implementation is one file; `tests/` mirrors the packages;
the docs are written from the registries.

Ghost had most of that: `src/scenes/` and `src/media/` were exactly it, about sixty literal tables
are registries, `docs.py` is the same mechanism, and "adding to a registry is the extension
mechanism" is a commitment in `docs/index.md`. Three differences shaped the plan.

1. **Python's imports are its structure; GDScript has none.** A `class_name` is global. So a
   script that moves needs no edit in the scripts that use it, and nothing stops any script from
   naming any other. The first made the move cheap. The second is why the order needs a gate.
2. **Praxis's packages are all one kind of thing** - parts of a model. Ghost has parts, a show
   that plays them, features built on the show, and a shell. One level of folders still, but in a
   stated order.
3. **A Praxis registry is found by its name.** Ghost's are found by naming the script that holds
   them, which is fine going down and a cycle going up.

## The rules

1. **One level of folders, each one thing.** `src/<folder>/<script>.gd`, and no folder inside a
   folder.
2. **Down only.** The folders are a stack (`FOLDERS` in `docs.py`, bottom first). A script names
   scripts in its own folder and in the folders below it. An autoload is a script like any other:
   the Director is in `show/`, so nothing below `show/` reads it.
3. **What a part reads is handed to it.** This is dependency injection in ghost's own terms, and
   it takes four forms, all in the code: an ARGUMENT (`update(features, delta)` - the scenes never
   touch the audio engine, which is why they are the cleanest code here), a SEAM (`NoteStore.root`,
   `CardEpisode.root`, `Films.use_for_test`), HANDED STATE (`Director._pick` is given its state, so
   forecast and walk are one body), and a CONTRACT - a small typed base class in a low folder, which
   the thing above extends and the thing below is handed (`Shell`, `ShowFeed`, `SoundBed`). A part
   that needs the seed, the clock or a dial takes it one of these ways and never asks who owns it.
4. **A registry is in the folder of the thing it lists**, never in the script that uses it. A row
   whose implementation lives higher up names it by path, and a gate loads every row
   (`Components` `script`, `Capabilities.ROLES`, `Medium.REGISTRY`; `components_check` loads the
   first two).
5. **Only `app/` names everything.** It is where a note's parts are put together, and a feature
   never reaches up for it.
6. **One file, one job** - along the banners a big file already has, a section at a time, never
   moving a method a subclass overrides (step 8).

**The gate.** `python docs.py --check` reads every script's references and fails on one that points
up, on a script that is in no folder, on a folder the table does not place, and on a folder inside
a folder. Its control is run first, every time: a made-up graph with one reference planted upward
must be reported. `UPWARD` in `docs.py` is the list of exceptions - it began at 48 and is empty,
and a row added to it is a debt with a date, never the way to make a new reference pass.

## The map

```
 app        opens notes, builds a note's panel from its components, owns the window's furniture
 ───────────────────────────────────────────────────────────────────────────────────────────────
 features   masking      cards      table (the set, and the medium that shows it)      reading
 ───────────────────────────────────────────────────────────────────────────────────────────────
 services   export: a show to a file, and to YouTube          timeline: the storyboard's editor
 ───────────────────────────────────────────────────────────────────────────────────────────────
 the show   show: the Director walks a storyboard and mounts scenes on a medium, through the Look
            media: full frame, comic, book, notebook, tablet - and their layouts, films, pictures
 ───────────────────────────────────────────────────────────────────────────────────────────────
 a note     ui: the panel kit and what a panel asks of the window (Shell)
            notes: the note as a file, the registry of components, the registry of marks
            voice: words to sound                  agents: who writes and who paints
 ───────────────────────────────────────────────────────────────────────────────────────────────
 pictures   scenes   stage   scene_kit   geometry   motion   render
 ───────────────────────────────────────────────────────────────────────────────────────────────
 ground     platform     data     audio
```

Three things the stack showed that the flat list could not.

- **The voice engine names nothing but `platform`, `data` and `audio`**: 11 scripts and 7,600
  lines of a clean library. All of the tangle people call "the voice" is in the three workspace
  panels above it (`reading/`).
- **The set names almost nothing**: the table, its things, light, wind, air and sound are built
  from a description and know no episode, no deck and no agent. It is a place, and a place is
  reusable.
- **`export/` is under the workspaces, not over them.** A reading and a show of cards use the
  exporter and the YouTube card; the exporter names neither. Guessed the other way round at first,
  and the references said otherwise.

## How the 48 went

Each by one of four moves. The first column is what to reach for the next time a reference wants
to point up.

| the move | what it was | how many |
| --- | --- | --- |
| **A helper goes down** to the folder that can own it | `field_of` to `FrontMatter`; a section and a title's key to `Manuscript`; a list read as strings to `DataPath`; a voice's hue to `Scheme`; the ruler takes a length where it took a Masking session | 5 |
| **A contract goes under both sides** | `Shell` (`ui/`): the row, the claims, the way home, the note's "⋯", the feedback console - `Chrome` extends it and is the furniture. `ShowFeed` (`scene_kit/`): the seed, the camera, the hand, the holds, the fade, the aura - the Director extends it and hands itself to what it mounts. `SoundBed` (`audio/`): what a reading mixes under a voice - `Soundscape` extends it, and Cards hands the reading the maker. And the YouTube card finds the exporter beside it (`Exporter.of`) where it asked the shell for it | 18 |
| **A row names its script by path** | a component's card (`Components` `script`, built by `NoteCards.make` through `for_note(ctx)`); an agent role's registry (`Capabilities.ROLES`); a region a mark is `within` (`ScriptMarks.REGIONS`) | 6 |
| **A script goes where it belongs** | the table medium, the card faces and the reading's table marks to `table/`; the film scene to `media/`; the showcase to `app/`; the Script card and `NoteCards` to `ui/`; `ui/` above `notes/` (it is a kit for a note's components) and `export/` under the workspaces | 19 |

With the 48 gone, 32 scripts are left in nine cycles, each inside one folder (the largest, nine
scripts, is the set's own: `Props`, `Lights`, `Tables`, `Winds` and the rest name one another).
Before, it was 95 scripts in six, one of them 61 wide.

## The steps

**1. The move.** *Status, 2026-10-13: done.* 162 scripts went into their folders with their
`.uid`s, no file renamed (`Director._scene_key` hashes a scene's file name: a renamed scene is a
different show from the same seed), and 603 path strings were rewritten in 141 files. Tried first
on a copy of the tree. `src/wind.gd.uid`, a sidecar whose script was long gone, went with it. The
editor's first scan after a move reports each autoload's old path once, from its own cache; the
second is clean.

**2. The gate and the map.** *Status, 2026-10-13: done.* `FOLDERS` and `UPWARD` in `docs.py`
replaced `SCRIPT_GROUPS` and its 162 file names: a script's group is its folder, so a new script
is in the docs by being in one. `check_structure` holds the stack; `docs/structure.md` is written
from it; `docs.py` finds a script by its file name alone (`_script_path`), so a script that moves
folders needs no edit there.

**3. The small ones, 4. the shell's contract, 5. the show handed down.** *Status, 2026-10-13:
done* - with the table medium going home (the first half of 7) and Masking taking the shell's
feedback console (the first of 9), which is all 48. See "How the 48 went".

**Correctness, not only green.** *Status, 2026-10-13: done.* Three things no gate could see:

- **A gate passed for a week with its check dead.** `clown_face_check` set two members of the
  editor that no longer existed; the runtime error ended its Steadiness check and the gate printed
  its pass over it. Steadiness moved to the face track long ago, so the check now lives in
  `face_track_check`, through the dial's own mapping (`MaskFaceTrack.sigma_for`, which the editor
  now calls), with a control that fails when the wobble never reaches the reader. AND THE RUNNER
  FAILS THAT NOW: `check.sh` counts the runtime `SCRIPT ERROR`s in a passing gate's log, and a
  gate that makes one on purpose declares it (`## script errors: N`). The first full run under it
  found no other - and it caught a check of mine from earlier the same day, which loaded scripts
  before the autoloads existed and passed over its own errors.
- **A path written in code is held to the disk.** `docs.py --check` reads every `src/<...>.gd`
  and `tests/<...>.gd` written in the code, the gates, the rules and the orientation files, and
  names any that is missing - a moved script breaks nothing the compiler sees. It found two dead
  references on its first run.
- **Masking gets the console courtesy.** `main._end_session` asked its own handle whether the
  feedback console was open; Masking's console is the shell's, so a reading of it was missed.

**6. One shape of registry.** *Status, 2026-10-13: done for the registries that were parallel
maps; the roster is out of the Director.* Every registry is a Dictionary of ROWS, one per key, in
the order it is offered: a `label` a person reads, a `blurb`, and the fields of its own kind. The
Look's filters (`uniform`, `default`), the media (`script`, `uses`, `frames`, `needs`, `mode`,
`bare`) and the agent backends (`backend`) were four or seven parallel tables keyed alike and are
one table of rows each now, with each field's reason written beside the field instead of above a
table of its own. `Registry` (`data/`) reads a label, a blurb or a field of any of them; docs.py's
`_rows` reads any of them as data, so the docs need no regex per table. `data/` moved to the bottom
of the stack for it: plain-data helpers name nothing, and the platform reads them.
`SceneRoster` (`scenes/roster.gd`) holds the rotation and the atmospheric list, read by the
Director, the storyboard's editor, docs.py and the gates; the order and names are unchanged, so
every seeded show is. Left: a table of FIELDS per composable thing - scenes have none yet (what a
scene rolls from its seed is code), layers and forces neither - which is what a timeline's
inspector and an agent choosing parts will read; `Cast.PARAMS` and `Actions.ARGS` are the shape.

**7. `table.gd` along its banners.** *Status, 2026-10-13: three parts out; 6,800 lines to 3,800.*
`TableShuffle` (every move the deck makes), `TablePlan` (what an episode decides when it loads -
the seed, the cards, the slots, the camera's place, the staging... - written by one fixed order of
statements, a fresh one per episode, read by everything after) and `TableCardPose` (where each card
is at a moment of the show: no state of its own, read off the plan, the schedule and the box). What
is left in `table.gd` is the per-frame driver (`_pose`, which applies poses to the meshes and keeps
the little per-frame state there is), the building of the set and the episode, and the things on
the table. Next: the things on the table (they read the plan now, so their boundary is narrower
than the 64 references it was), and the episode's build split from its decisions - the plan made
by a function of (episode, seed) with the same draws in the same order, the nodes built from it.

**8. The workspaces become cards.** *Status, 2026-10-13: the first piece - what a reading reads -
is handed, not overridden.* `reading_panel.gd`'s banners do not hold together (its "audition"
section holds `_set_status`, which the rest calls 19 times), and `CardsEditor` overrode 31 of its
methods: a method moved into a part would call the part's own copy, and the override would go quiet
with no compiler to say so. So the reading comes apart by turning overrides into what a mode HANDS
it. The first: `TextWalk` (`reading/`) is what a reading reads - the words, the title announced,
the text the cast and the fingerprint come from, the passage a voice is auditioned with - the note's
own by default (a tablet chapter read off its screen); Cards hands an `EpisodeWalk` (`cards/`) that
reads the episode it produced, never the brief. Six overrides went (31 to 25), and
`tests/reading/text_walk_check.gd` holds the walks - it fails, as it should, when Cards' walk is
made to read the brief, which no gate checked before. Next, in the same way: where the reading is
(`_environment`, already a maker of a `SoundBed`), how its export is named and uploaded
(`export_name`, `_upload_*`), then the panel's own cards - until a voice is a card that reads
whatever walk the note's components hand it (storyboard.md's fourth "Next"; notes.md, "text walks").

**9. Masking joins.** *Status, 2026-10-13: three parts are out.* `MaskPoseTrack` (the pose track:
bootstrapped, read by time), `MaskUrlImport` (a link where a file is expected) and `MaskFaceTrack`
(the face track and the stencil rasterized from it) hold their own state and read the editor through
`editor.`; `mask_editor.gd` fell from 8,400 lines to 6,800. Left: the shared transport (roadmap, "One
transport for Masking too"), the prep (its section is asked twelve things - the session's lifecycle
lives in it), and one timeline kit for Masking's two and the storyboard's.

**10. Tests mirror the folders.** *Status, 2026-10-13: done.* 165 gates and probes live in
`tests/<folder>/`, the folder of what each holds; the runners, the fixtures and `compile_check` stay
at the top. `scripts/check.sh --for` runs what a change can reach - the gates of the folders it
touched and of every folder above (by default, what changed since the last commit; a path outside
src/ and tests/ runs everything) - reading the stack from `python3 docs.py --folders`. A change in
`src/table/` runs 37 gates of the 132.

## The second round: a foundation for a live mode (2026-10-15)

The user, before starting a new kind of mode - a real-time one that shows theorem-proving: "I don't
think it's a good idea to start working on a new mode until we've cleaned-up the foundation."
Measured first. A new mode that reads aloud would today have to EXTEND `ReadingPanel` (4,591 lines)
and override what it needs, as Cards does 25 times; every medium and the table read the show's
clock off `Spectrum`, so a show whose time is not a song's could not drive them; and the agents,
the rules, the media registry and the components are ready as they are. So, in order:

11. **The show's time is handed.** *Status, 2026-10-15: done.* `ShowFeed` carries the clock -
    `show_time()`, `show_length()`, `tail()` (the bookend's, as baked) and `signature()` (the
    harmonic signature) - and the media, the table and the scenes read it there; the Director
    answers from `Spectrum`, and `BAND_COUNT` moved to `AudioFeatures`. A part a show mounts
    (`scene_kit`, `scenes`, `media`, `table`) never names `Spectrum`: `HANDED` in docs.py holds it,
    with a control. `tests/scene_kit/feed_clock_check.gd` hands a tablet 0.6 s with the session
    clock wound to 100 s and gets half its fade, and a scene an E signature and gets E's hue - and
    it found its own first draft passing over a part that failed to load, so it counts its checks.
12. **The reading takes its parts.** *Status, 2026-10-15: done.* Nothing extends `ReadingPanel`.
    A component hands it what it changes: what is read (`walk`, `TextWalk`), where it is heard
    (`bed`, `ReadingBed`: `{make, key}` and the dial) and how it goes out (`publish`,
    `ReadingPublish`: the export's name, what is held through the render and written after it, the
    upload's text and macros, the book document, the YouTube card's own rows). Cards is a card:
    `EpisodeCard` (`cards/`) is the episode, its agents, its rows and its YouTube fields, built by
    `NoteCards` from the `cards` row (`script`, `heading`, the bookends' tips at a table) above the
    voice, handing all three and asking the panel a few things by name. `CardsEditor` and
    `GenerativeEditor` are gone: `Components.WORKSPACES` `reading` and `cards` say a panel's
    section, title, hint, `hosts` and `classic` set, and main makes one `ReadingPanel` for either.
    Two runtime errors behind passes were caught by check.sh on the way (gates reading the old
    `_picture`), and one gap of mine by reading: the episode's walk did not yet say an edit to the
    brief leaves its reading alone (`reads_source`, now held by text_walk_check).
13. **`reading_panel.gd` along its banners.** *Status, 2026-10-15: the pure half is out.* What is
    a function of its arguments went to static libraries under `voice/`: `Splice` (the hesitations
    spliced into a take, the hums held, word timings moved by the cuts, WAV in and out) and
    `Delivery` (the tone presets, the pause curve, the rest at a seam and a handover, stress, the
    delivery marks eased sentence by sentence, the host's request for one chunk in one voice, the
    room dialed). The live window, the audition and the export call the same functions, so they
    cannot part. 4,664 lines to 3,734. Left: the stateful sections (the cast, the audition, the
    sliding window), which a voice card would be built from.
14. **`table.gd`.** *Status, 2026-10-15: two more parts out; 3,811 lines to 2,841.* `TableLight`
    (the flames - flicker, draft, lick - their glow and heat, the rig and its key, the contact
    shadows) and `TableBox` (the box, its files, the cards a search looks at; `stood`, `files`,
    `searched`, which the poses read). Left: placing the things (it calls the light and the box,
    and is called by the episode's build), and the plan made by a function of (episode, seed) -
    the episode's section interleaves its draws with the nodes it builds, and splitting them
    without moving a single draw is a change to make with the user's eyes on a seeded show.
15. **`mask_editor.gd` along its banners.** *Status, 2026-10-15: two more parts out; 6,778 lines to
    6,533.* `MaskAudioFx` (the bus and the timeline applied to the sound) and `MaskUndo` (the two
    stacks of snapshots, a gesture coalesced into one step) each read the editor a few times. The
    paint sim was measured too and left: it is where the shader is handed every clown and umbra dial
    (54 of the editor's members), so it is not a boundary yet. Its banners do not hold together -
    "Hi-res waveform window" holds the source panel, "auto-save" the face and pose processes - and
    the lanes (1,264 lines), the markers (821) and the autosave (732) want their functions sorted
    under true banners before any cut, with the shared transport and one timeline kit after.
    Found on the way: `cut_part.py` let the owner's field be named like the method it took
    (`_undo`), and a gate's calls were rewritten twice; it refuses that now.
16. **Field tables.** *Status, 2026-10-15: done for the layers and the forces.* Every setting a
    layer or a force reads off its config is a row in its class's own `FIELDS` (`label`, `type`,
    `default` - null when the seed draws it or it is worked out, as the `blurb` says), the layers'
    shared depth band in `Layer.Base.COMMON`; [method Layer.fields_of] reads one layer's rows, and
    docs/layers.md and docs/forces.md show them. 107 layer settings and 26 force settings. HELD BOTH
    WAYS: `docs.py --check` (`check_fields`) reports a setting read with no row, a row nothing reads
    and a default the row and the code disagree on, with a control; and
    `tests/scene_kit/layer_fields_check.gd` builds every layer told the defaults its table states
    and requires the same layer as one told nothing, which fails, as it should, when one row's
    default is changed. The two settings read as strings with `cfg.get` read through `txt()` now,
    and the base's `hue()`, which nothing called, is gone. Left: the scenes, whose rolls from the
    seed are code - a `layers` storyboard entry (storyboard.md, "Next" 2) is what would use these
    rows first.

WHERE THE THREE BIG FILES STAND (they were 30% of the code, and the week's bugs were in them):
`mask_editor.gd` 8,376 lines to 6,533, `table.gd` 6,797 to 2,841, `reading_panel.gd` 4,548 to 3,734 -
with seven parts and two libraries beside them, each holding its own state or none, and nothing
left that extends the reading.

A LIVE MODE IS THEN A COMPONENT AND A CARD. A row in `Components.REGISTRY` (its family, what it
needs and provides, its slots, `script`), a card built by `NoteCards` above the voice that hands
the reading a `TextWalk` whose text grows as its agents write (and, if it has a place, a
`ReadingBed`; if its export is its own, a `ReadingPublish`), a medium registered by row that draws
what they make from the time its `feed` hands it, and agents through `AgentJobs` and `rules/`. What
it does NOT have yet is a reading that takes text while it streams (the sliding window plans its
chunks at Play) and a show timed by nothing but a clock (storyboard.md, "A storyboard needs a
sound") - the first features to build in it, on this foundation.

## The third round: the stateful halves (2026-10-19)

The user, a few days and a lot of new work later (Proof's desk, the table's rides): "continue down
the path of fixing the structure, especially with respect to the pure functional design, the
stateful handling, and the rest of the stuff you left for later" - and, for a live mode not yet
committed to, interfaces only where they are cheap and certain. Two other sessions were working in
the tree that day (the desk, the table's rides), so this round kept to `reading/` and `masking/`,
and the table's two steps (14) waited for them. Gates ran into a log folder of their own
(`GHOST_CHECK_OUT`, new in check.sh): two runs in one tree had overwritten each other's logs.

17. **A reading's plan is a function.** *Status, 2026-10-19: done.* `ReadingPlan` (`reading/`) is
    what a reading will say, worked out from its words: the passages by speaker, the hesitations
    and delivery marks resolved, the chunks cut and placed in their paragraphs, the outro mark's
    fade, the scrub's estimate, the start words, the subtitle words timed from the host's spans.
    In: the words, the title announced and what is asked (`reader`, `hesitate`, `bare`, `outro`).
    The panel had kept the plan's findings in members - the hesitations' lengths in one list a
    second method consumed with a cursor, the delivery marks of the passage last resolved, the
    fade's length - and AN EXPORT PLANNED WHILE A READING PLAYED REWROTE THE FADE THE READING WAS
    FADING BY (multi_voice_check holds it now; the old code fails it). A passage's rests are its
    own: a sentinel the phonemizer loses costs that passage its lengths, never every passage after
    it. FOR A READING THAT GROWS, `ReadingPlan.make(..., from_sentence)` plans a piece of text as a
    continuation and says where the next starts. `tests/reading/reading_plan_check.gd` plans with
    no panel at all (two mutations, two failures).
18. **One join for the live reading and the export.** *Status, 2026-10-19: done.* `ReadingJoin`
    joins a take a chunk at a time - the seam, the hesitations spliced in, the room's marks (voice
    and distance), the words in the take's seconds, where each chunk starts and the fade - and the
    live window, the export and the audition each hold one. They were three copies kept alike by
    comments, and had parted: a reading started part way through rested a seam before its first
    sentence (the export never did), the two placed an unaligned word on either side of a
    hesitation's cut, and both kept a running total of seconds that drifted from the audio up to a
    frame per seam (the join counts frames). `tests/reading/reading_join_check.gd`, three
    mutations, three failures - one of them the trap the panel's comments record: a handover written
    after the player consumed every mark still lands on its own frame, never at 0.
19. **The audition is a part.** *Status, 2026-10-19: done.* `ReadingAudition` holds Test's
    eighteen members of state; the panel asks it to start, stop and take a reply. It had no gate:
    `tests/reading/audition_check.gd` answers it from a stand-in host with takes made in the gate
    (every sentence asked at once, nothing joined out of order, a seam between each two and a
    second of tail, every frame through the room, the takes off the disk, Stop dropping what is in
    flight) - three mutations, three failures. A hum or a hesitation in the passage is now spliced
    as a reading splices it.
20. **The window is a part.** *Status, 2026-10-19: done.* `ReadingStream` is the reading on the
    stream - the plan, the requests and takes, the ring, the join, the live chain, the place under
    the voice, the scrub - cut with `cut_part.py`, then put in true sections. On the way check.sh
    caught a runtime error behind a pass (speak_stop_check read the moved members by string name),
    and the same loop's next check was passing on `int(null)`: both read off the stream now and fail
    on a name it does not hold.
21. **Banners that hold together.** *Status, 2026-10-19: done for the reading panel, the stream, the
    cast and Masking.* `scripts/sort_banners.py` puts every declaration under the banner a layout
    names and refuses to write unless each comes out byte for byte (a banner over a group of
    variables becomes a comment over them; prose whose code had gone to a part went into that
    part's header). Masking's 476 declarations went under 22 true banners, checked from outside the
    tool: the same lines, reordered. `cut_part.py` learned two things from what it left behind - a
    plain comment touching a declaration goes with it, and a banner left empty goes.
22. **Masking along its true banners.** *Status, 2026-10-19: four parts out; 6,533 lines to 5,631.*
    With the banners true, four sections came out with small boundaries: `MaskPrep` (the clip
    transcoded once, guarded against a second writer, its length and frame size), `MaskWaveform`
    (the strip, crisp under zoom, and the envelope), `MaskRegion` (the box drawn over the video)
    and `MaskExport` (the Movie Maker relaunch at the clip's size, the mux). Each reads five to
    eleven of the editor's members and is asked a few things by public name.
23. **The cast is a part: the Voice card's insides.** *Status, 2026-10-19: done.* `ReadingCast` is
    the voices the script names and the rows that edit them - the cast, the tabs, the voice picker,
    the reader browser, every dial, Turn and Hesitate - and its block is the document's `voice:`
    (`capture()`, `apply()`), which is the interface every card on a panel keeps. Everything that
    reads a voice asks it by name (`cfg_of`). `reading_panel.gd` 3,765 lines to 1,101.

WHERE THE BIG FILES STAND NOW: `reading_panel.gd` 4,548 lines (round one) to 1,101, with three
pure libraries (`Splice`, `Delivery`, `ReadingPlan`), the join and three parts (the cast, the
stream, the audition) beside it; `mask_editor.gd` 8,376 to 5,631, with nine parts; `table.gd`
2,989 (the rides grew it), untouched this round.

LEFT, in order: the Voice as a card built by `NoteCards` from the `voice` row (`ReadingCast`
already keeps the block; what is left is the card being made where the others are, and a gate
that reads it there); Masking's tracks (538 lines, reading 25 things of the editor), then its
shared transport and one timeline kit; the table's things and its plan as a function of
(episode, seed), when the table is free; the scenes' field tables.

FOR A LIVE MODE, what is ready and what is not. A piece of text that arrives later is planned as a
continuation (`ReadingPlan.make` with `from_sentence`) and joined onto the same take (`ReadingJoin`
joins whatever chunk it is handed). What is not there is the stream's end: `ReadingStream` treats
its last planned chunk as the end of the reading, so an open one would have to pad silence while it
waits (a stream that runs dry stops the session clock) and queue its outro only when it is closed.

## What the two futures need

**A nonlinear timeline editor** (compose scenes from existing scenes, geometry and animation).
The folders it grows in exist: `timeline/` is the editor, `stage/` the spec. What it needs from
the steps: a catalog it can list without loading a player and every composable thing described
the same way (6: one row shape with a table of fields, over scenes, layers, actors, verbs, forces,
filters and shots), and one ruler - the storyboard's strip already borrows Masking's
`TimelineView`, and Masking still has a second timeline of its own (9). `ShowFeed` is the other
half: a preview scrubbed by a timeline is a second thing that fills it in, and the scenes and media
it mounts cannot tell. Then the open items storyboard.md names: a `layers` entry, keyframed
property lanes, a transition as an item.

**A real-time problem solver** (agents browsing on the tablet, writing on paper, reasoning aloud).
It is one more folder, `solver/`, beside `cards/`, and it would name `agents`, `voice`, `media`
and `show` - what Cards names. What it needs is that those take their content as it arrives: a
storyboard with a third source beside the written and the seeded one (a live queue), a medium
filled from a feed where it now takes a finished manuscript, a clock with no audio (storyboard.md,
"A storyboard needs a sound"), and tools a component declares (`AgentTools` serves the set
dresser's today). Step 8 is the one that makes room: a voice that is a card can be attached to
it. Cards is the rehearsal - its agents already produce a show step by step - and its table is
already a place a desk could be.

**Many kinds of show, and rounds** (the user, 2026-10-13: "we are essentially building a kind of
harness for AI agents ... we have made the visual aspect a first-class citizen ... we might be
working on a kind of world model" - cartoons and animation, a music-making tool, automatons doing
real work live on video). Each of those is a feature that does not exist yet, so the foundation's
job is not to know them but to not forbid them: parts that meet only through what a show hands them
(`ShowFeed`, a plan, a feed), registries that describe what can be composed, and a clock that never
waits on anything.

That last one is where ROUNDS come in. An agent loop works in rounds: a turn asks for tools, they
run (several at once), the results come back, the next turn starts - nothing blocks on everything.
The same shape fits both halves of a live show:

- **Agents.** A round's output lands as data on the show's schedule - an entry, a moment, a page for
  the tablet, a line for the voice - at a round boundary, and the show keeps playing in between.
  That is "agents write data, not code" with a clock attached, and it is the storyboard's third
  source (a live queue) from step 8's future above.
- **Drawing.** Work is given a priority and a budget per frame, and what misses its frame lands on
  a later one. Ghost already does this in five places, each its own way: `FrameForge` (geometry
  built on a worker, taken when ready), the landscapes that repaint every 3-4 frames, `SimClock`'s
  fixed tick, "work that misses a frame is absorbed, not queued" (docs/index.md, the design
  commitments), and `AgentJobs`' one queue. One scheduler would make that a declaration on the part
  rather than a trick inside it.

THE PRECONDITION IS PURITY, which is why the plan and the feed come first: a pose that is a
function of (plan, show time) can be computed early, late, on another thread or at low priority and
still land where it belongs; a scene that integrates state frame by frame cannot be deferred without
changing what it shows. So each part moved onto "a function of what it is handed and the time" -
`TableShuffle`, `TablePlan`, the media on `ShowFeed` - is a part a scheduler could later run in
rounds. Not built; a direction, recorded so the next cut is made with it in mind.

## What this does not do

- **Nothing here fixed a bug.** The stack is for seeing the project and for keeping it seen; the
  bug count moves with 7 and 8.
- **A row that names a script by path loses the compiler's check.** `compile_check` loads every
  script and `components_check` loads the rows; that is the price of a table that does not pull in
  what it lists.
- **`ShowFeed` has a default.** A scene or a medium nobody handed a feed reads the show that is up
  (`ShowFeed.playing()`), which is what naming the autoload used to give it - so a gate that builds
  a medium by hand still runs. It goes when the note owns the clock, the feeds and the seed, and
  hands them.
- **Shaders stay flat** in `shaders/`. They are named by feature already (`table_`, `prop_`,
  `light_`, `effect_`), and moving them beside their scripts is a second, smaller move.
- **Cycles inside a folder are allowed.** The gate holds the order of the folders, not the order
  inside one.
