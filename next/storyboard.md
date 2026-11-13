# The storyboard: a show written down

The modes were never in the engine; they were in the shell. This note is the design that follows, what is built of it, and what comes next. [notes.md](notes.md) is the plan it continues ("Composition, not templates"); [docs/stage.md](../docs/stage.md) is the data spec.

## Status

- **Built:** a storyboard is no component. A note shown in a Medium holds its own (`NoteStoryboard`), kept as `storyboard.json` in the note's folder (`NoteUpload.folder_of`), never in its frontmatter; its timeline opens from ☰ beside Play while the format plays scenes (Auto, Full frame, Comic). The forecast is editable in place: the first change writes it down; "To the seed" empties it. Each state is kept in the note's history (`history/storyboard/`) and listed by Restore…. There is no `storyboards/` folder: the one shipped storyboard is `data/showcase.json`, the README's animation and the demo note's ("A prism divides"), played by path; `--storyboard <path>` plays any file.
- **Looked at:** the gates (`storyboard_check`, `storyboard_editor_check`, `demo_note_check`, `showcase_check`, `teardown_check`, `form_leave_check`, `prism_motion_check`); the README animation recorded through the real app (22.9 s: two empty seconds, a blue prism flying in apex first from the upper right, landing like a spring and righting slowly through its first clone, a red clone pulled off it in a tug-of-war that snaps, a cascade of clones to ten, the ten tetrahedra of a tetrahedron cut three to an edge turning as one, the dissolve, the last red darting out to the upper right), looked at frame by frame; the editor not yet used by a person.
- **The user's to judge:** the new prism show recorded; whether a reading shown in scenes should open its storyboard or its words' marks from ☰ (the storyboard ranks over the marks, as an episode does - a choice on ☰ is unbuilt).

## The finding

**The engine already agreed.** `Director._next_entry()` returns one shape - a scene, its motion, its seed, how it leaves - from two sources: the next entry of a storyboard, or one it writes on the spot from the seed. So the seeded show ("Auto") is a storyboard nobody wrote down, and a written one ("Manual") is the same show made explicit. The split into modes was in the shell: a table of seven templates, a function that read a note's blocks and picked one, and five panels that each built their own cards.

**So the general case is the written one**, and everything else is a shorter way of producing it:

| what the user does | what produces the entries |
| --- | --- |
| attaches a Picture and nothing else | the seed, cut by cut (`Director._pick`) |
| writes a storyboard | `storyboard.json` in the note's folder |
| changes the seeded show | `Director.forecast` - the seed's entries, written down at the first change |
| plays a file | `--storyboard <path>`, read and never written |

One function answers the first and the third (`_pick`, handed its state instead of reading it), so what a forecast says and what plays cannot drift apart. `storyboard_editor_check` cuts the real Director through six scenes and holds them to the forecast.

## What was built

### One kind of note

- **New has no options.** It makes a note with nothing attached (no `ghost:` key), and every note opens the same way: `main.open_note` reads what is attached and starts the workspace those components name.
- **No templates.** Each component declares two facts in the registry: the **slots** it takes (`clock`, `presentation` - a note has one of each) and the **workspace** it needs, if any. `Components.workspace_of(attached)` is derived: the workspace an attached component names, and where two name one, a component another *brings* gives way (Table brings a Voice, so Table runs the show).
- **"+" is derived, on every panel.** `Components.attach_menu(menu, attached)` offers every component that is attached by itself, what can be had now first, then the rest grayed with a reason: a need nothing provides, an agent not installed, or a slot that is taken ("This note's clock is its Song - detach that first.").
- **Everything attached comes off.** Each component's card has an × that asks, removes its blocks (`Components.blocks_of`) and opens the note again. Two refusals, each with its reason: the text is the note, and a Voice stays while the components that bring it do. A component left without what it needs says so at the head of its card.
- **Every panel builds a note's cards one way.** `NoteCards.build` adds a card per attached component; the note's own panel, the reading, the Table workspace and the voice lab each build only what is theirs alone and hand over the rest. Attach and detach are `NoteCards.attach` / `detach`: write the file, reopen.
- **One path puts a show up.** `main._attach_show(plan)` serves a song's note and a reading's: a panel answers `show_plan()` - whether there is a presentation, and the storyboard to walk.

So a voice with a Picture and a storyboard (a narrated story with authored scenes) and a voice alone (heard with its words over an empty frame until a Picture is attached) need no code of their own.

### The storyboard as the note's own data

- **In the note's folder.** `NoteStoryboard` keeps a note's storyboard as JSON (`Storyboard.to_json`; a whole number read back an int, `Storyboard.whole`), written a moment after an edit settles and kept in the note's history at each write. Nothing written is no file: the seed chooses.
- **Two shapes.** The raw tree is what is written - `defs` and `use` in it - and what the editor edits. The loaded form (`Storyboard.from_data`) is what the Director walks. Loading never changes the raw tree.
- **Edits are pure.** `DataPath` (`put`, `cut`, `insert`, `move`) returns a new root and leaves its argument alone, so an editor's undo is the list of trees it has shown.
- **Fields are tables.** `Storyboard.BOARD / ENTRY / TIMINGS / STAGE / CAMERA / ACTOR / SPAN`, `Cast.PARAMS` (per kind) and `Actions.ARGS` (per verb) say what can be set: label, type, default, bounds or choices, a sentence. `SchemaForm` draws rows from a table, so a field added to a table is a control in the editor and a row in `docs/stage.md`.
- **One schedule.** `Storyboard.schedule` is the arithmetic the Director walks; the editor's ruler is drawn from the same function.
- **A render gets it too.** An export of a note's storyboard hands the render a file written from what the Director is walking (`Exporter._storyboard_arg`).

### The editor

`NoteStoryboard` opens `StoryboardEditor` from ☰ beside Play (`Transport.offer_timeline`, rank 2), a dock along the bottom of the frame; the show is fitted above it (`Chrome.claim_stage`), so what is edited is seen whole.

- **The strip** (`StoryboardStrip`): entries on a ruler, as wide as they are scheduled to stay. Click to pick (the show cuts there, and where the storyboard follows the song the song seeks too); drag to reorder; drag the right edge of a fixed hold to lengthen it. A cue-timed entry has a broken edge: it has no fixed end.
- **The lanes** (`TimelineLanes`, on Masking's `TrackLane` and `FlagStrip`; next/editing.md, "The Timeline"): for a stage entry, a lane per actor and its spans - a block for a window, a diamond for a moment. Drag to retime; double-click a lane to add.
- **The inspector**: whatever is picked - the storyboard, an entry, an actor, a span - as rows from the tables. A value a def gives is shown dimmed, as a default is; changing it writes the map's own key over the def.
- **Source**: the whole tree as YAML, taken back if it still loads.
- With nothing written, the editor shows the seed's forecast, grayed: what "automatic" is about to play, as a storyboard. A change to it writes it down; + Scene starts one from nothing.
- **To the seed**: empties it, and the seed chooses again (Restore… brings it back).

### Gates

`storyboard_check` (pure: edits leave their input alone, it round-trips through the JSON a note keeps and the YAML source view, the shipped one copied into a note loads as the file does, the schedule's numbers, five controls), `storyboard_editor_check` (through the real app: the tables against their registries, which formats offer it, forecast against real cuts, written-down is the same scene from the same seed, every edit pure and one step back, the note's folder keeps it and its history, To the seed, a voice walks one too), `demo_note_check` (the shipped show lands in the demo note's folder), `components_check` (workspaces, slots, detach), `notes_list_check` (New is a button, a note becomes a show by "+", a component detaches), `teardown_check` (a story left with the editor open, a narrated note).

## What it does not do yet

- **Five workspaces, not one panel.** The reading, Table, the voice lab and Masking are still panels of their own - composed the same way, but a Voice is not yet a card on the note's own panel. `ReadingPanel` builds its shell beside `NotePanel`'s; the next cut is making the voice a driver the note's panel hosts.
- **One clock.** A song and a voice cannot be on one note. The slot refuses it; the mix ("a song ducks under a voice") is unbuilt.
- **A storyboard needs a sound.** With no song and no voice there is no clock, so no show. A storyboard of fixed holds could conduct itself (a silent film); `Spectrum` has no clock without audio yet.
- **Scenes are still code.** An entry names a scene and pins its seed; what the scene rolls from that seed is not data except on a `stage`. Properties for the geometry, lighting and textures are the scene-spec pipeline (roadmap): the Layer registry is the nearest step - a `layers` entry, as `stage` is for actors, would make `aurora` (`bed` + `stars` + `aurora`) a storyboard entry instead of a file.
- **No keyframed properties.** The Look, the camera dials and the holds are one value per note. A lane of keyframes for any numeric field is the modulation notes.md describes; the tables are what such a lane would be built from.
- **Transitions are three names.** `cut`, `dip`, `fade`, and a morph where two entries line up. A transition as its own timeline item is not built.
- **The editor is not judged by a person yet.** It was looked at through rendered pictures (`tests/timeline/storyboard_look_probe.gd`), not used.

## Next, in order

1. The author's own pass over the editor: what is missing to write a real story with it.
2. A `layers` scene: an entry that composes Layer registry entries, with a table per layer.
3. The storyboard conducting itself with no sound.
4. The voice as a card on the note's own panel (the workspaces fold into one).
5. Property lanes: a keyframed value for any field a table marks as one.
