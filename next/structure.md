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

**6. One shape of registry.** *Status, 2026-10-13: the roster is out of the Director; the shape
is not unified.* `SceneRoster` (`scenes/roster.gd`) holds the rotation and the atmospheric list, read
by the Director, the storyboard's editor, docs.py and the gates; the order and names are unchanged,
so every seeded show is. Left: one row shape - label, a sentence, a table of fields, the script -
over the four shapes there are (parallel `REGISTRY` / `LABELS` / `BLURBS` maps in `Medium`,
`Filters`, `TextGen` and `ImageGen`; one map of rows in `Components`; `Cast` and `Actions` with
separate field tables; the roster's list), and one reader, so `SchemaForm`, `docs.py`, "+" and a
timeline's "add" menu read any of them the same way. docs.py parses each shape by its own regex,
so the reader and docs.py change together.

**7. `table.gd` along its banners.** *Status, 2026-10-13: the shuffle is out.* `TableShuffle`
(`table/table_shuffle.gd`, 2,300 lines: every move the deck makes and where each card is during
one) holds its own state, reads 34 things of the medium (`medium.`) and is asked seven
(`shuffle_xf`, `shuffle_wander`, `move_at`, `deck_turns`, `riffle`, `wash`, `wash_jump`); `table.gd`
fell from 6,800 lines to 4,500. Measured, the other sections do not cut the same way: "the things on
the table", "posing" and "the episode" each read 60 or more of the medium's members. But almost all
of those are WRITTEN IN ONE PLACE, when the episode loads (the seed, the cards, the slots, the deck's
base, the camera's, the staging...) and only read after. That is the next cut: a `TablePlan`, made
once by the episode and read by everything that poses - the table as a pure function of (plan,
show time), which is what its header has always said it is. Then the posing and the things on the
table come out holding the plan instead of the medium.

**8. The workspaces become cards.** *Not begun, and measured not to be a cutting job.*
`reading_panel.gd`'s banners do not hold together (its "audition" section holds `_set_status`,
which the rest calls 19 times), and `CardsEditor` overrides 31 of its methods: a method moved into a
part would call the part's own copy, and the override would go quiet with no compiler to say so. So
the reading comes apart the way storyboard.md's fourth "Next" says - the voice a card on the note's
own panel, Cards a component that brings a voice - with the overrides turned into what each mode
hands the reading.

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
