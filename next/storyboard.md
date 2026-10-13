# The storyboard: a show written down

Opened 2026-10-12, for the user's question: are the modes the problem, and is "manual" the general
case the others simplify? Yes to both. This note is the design that answer led to, what was built
of it that day, and what comes next. [notes.md](notes.md) is the plan it continues ("Composition,
not templates"); [storyboards/README.md](../storyboards/README.md) is the data spec.

## The finding

**The engine already agreed.** `Director._next_entry()` returns one shape - a scene, its motion,
its seed, how it leaves - from two sources: the next entry of a storyboard, or one it writes on the
spot from the seed. So the seeded show ("Auto") is a storyboard nobody wrote down, and a written
one ("Manual") is the same show made explicit. The split into modes was never in the Director. It
was in the shell: a table of seven templates, a function that read a note's blocks and picked one,
and five panels that each built their own cards.

**So the general case is the written one**, and everything else is a shorter way of producing it:

| what the user does | what produces the entries |
| --- | --- |
| attaches a Picture and nothing else | the seed, cut by cut (`Director._pick`) |
| writes a storyboard | the note's own `scenes:` block |
| starts from the seeded show | `Director.forecast` - the seed's entries, written into the note |
| names a file | `storyboards/<name>.yaml`, read and never written |

One function answers the first and the third (`_pick`, handed its state instead of reading it), so
what a forecast says and what plays cannot drift apart. `storyboard_editor_check` cuts the real
Director through six scenes and holds them to the forecast.

## What was built (2026-10-12)

### One kind of note

- **New has no options.** It is a button. It makes a note with nothing attached (no `ghost:` key),
  and every note opens the same way: `main.open_note` reads what is attached and starts the
  workspace those components name.
- **`Components.TEMPLATES` is gone**, with `template_for` and `marker_blocks`. In their place each
  component declares two facts in the registry: the **slots** it takes (`clock`, `presentation` - a
  note has one of each) and the **workspace** it needs, if any. `Components.workspace_of(attached)`
  is derived: the workspace an attached component names, and where two name one, a component
  another *brings* gives way (Cards brings a Voice, so Cards runs the show).
- **"+" is derived, on every panel.** `Components.attach_menu(menu, attached)` offers every
  component that is attached by itself, what can be had now first, then the rest grayed with a
  reason: a need nothing provides, an agent not installed, or a slot that is taken ("This note's
  clock is its Song - detach that first."). The per-panel lists (`DECIDES`, `WITH_SONG`, the
  readings' `["youtube"]`) are gone.
- **Everything attached comes off.** Each component's card has an × that asks, removes its blocks
  (`Components.blocks_of`) and opens the note again. Two refusals, each with its reason: the text
  is the note, and a Voice stays while the Cards that bring it do. A component left without what it
  needs says so at the head of its card.
- **Every panel builds a note's cards one way.** `NoteCards.build` adds a card per attached
  component (Picture, Storyboard, Look, Intro & outro, YouTube); the note's own panel, the reading,
  the Cards workspace and the voice lab each build only what is theirs alone and hand over the
  rest. Attach and detach are `NoteCards.attach` / `detach`: write the file, reopen.
- **One path puts a show up.** `main._attach_show(plan)` serves a song's note and a reading's: a
  panel answers `show_plan()` - whether there is a presentation, and the storyboard to walk.

What falls out, with no code written for the pairing: **a voice with a Picture and a storyboard**
(a narrated story with authored scenes), and **a voice alone**, which is heard with its words over
an empty frame until a Picture is attached.

### The storyboard as the note's own data

- **In the note.** A note's `scenes:` block holds its storyboard (`Storyboard.of_block`: the
  note's own, a file's name, or nothing written). It is written by the same autosave every card's
  block goes through, merged three ways with an edit made outside.
- **Two shapes.** The RAW tree is what is written - `defs` and `use` in it - and what the editor
  edits. The LOADED form (`Storyboard.from_data`) is what the Director walks. Loading never
  changes the raw tree.
- **Edits are pure.** `DataPath` (`put`, `cut`, `insert`, `move`) returns a new root and leaves its
  argument alone. An editor's undo is therefore the list of trees it has shown.
- **Fields are tables.** `Storyboard.BOARD / ENTRY / TIMINGS / STAGE / CAMERA / ACTOR / SPAN`,
  `Cast.PARAMS` (per kind) and `Actions.ARGS` (per verb) say what can be set: label, type, default,
  bounds or choices, a sentence. `SchemaForm` draws rows from a table, so a field added to a table
  is a control in the editor and a row in `docs/stage.md`.
- **One schedule.** `Storyboard.schedule` is the arithmetic the Director walked; the editor's ruler
  is drawn from the same function.
- **A render gets it too.** An export of a note-owned storyboard hands the render a file written
  from what the Director is walking (`Exporter._storyboard_arg`).

### The editor

`StoryboardCard` ("Timeline…") opens `StoryboardEditor`, a dock along the bottom of the frame; the
show is fitted above it (`Chrome.claim_stage`), so what is edited is seen whole.

- **The strip** (`StoryboardStrip`): entries on a ruler, as wide as they are scheduled to stay.
  Click to pick (the show cuts there, and where the storyboard follows the song the song seeks
  too); drag to reorder; drag the right edge of a fixed hold to lengthen it. A cue-timed entry has
  a broken edge: it has no fixed end.
- **The lanes** (`StoryboardLanes`): for a stage entry, a lane per actor and its spans - a block
  for a window, a diamond for a moment. Drag to retime; double-click a lane to add.
- **The inspector**: whatever is picked - the storyboard, an entry, an actor, a span - as rows from
  the tables. A value a def gives is shown dimmed, as a default is; changing it writes the map's
  own key over the def.
- **Source**: the whole tree as YAML, taken back if it still loads. Everything the spec has is
  reachable from the first day.
- **Start from**: the seeded show written down, or a copy of a board in `storyboards/`.
- With nothing written, the editor shows the seed's forecast, grayed: what "automatic" is about to
  play, as a storyboard.

### Gates

`storyboard_check` (pure: edits leave their input alone, the block round-trips through YAML, a
board taken into a note loads as the file did, the schedule's numbers, four controls),
`storyboard_editor_check` (through the real app: the tables against their registries, forecast
against real cuts, written-down is the same scene from the same seed, every edit pure and one step
back, the note keeps it, a file is read-only until taken in, a voice walks one too),
`components_check` (rewritten: workspaces, slots, detach), `notes_list_check` (rewritten: New is a
button, a note becomes a show by "+", a component detaches), `teardown_check` (two new make-ups: a
story left with the editor open, a narrated note).

## What it does not do yet

Said plainly, because each is a place the old shape still shows.

- **Five workspaces, not one panel.** The reading, Cards, the voice lab and Masking are still
  panels of their own - composed the same way now, but a Voice is not yet a card on the note's own
  panel. `ReadingPanel` (4,400 lines) builds its shell beside `NotePanel`'s; the next cut is making
  the voice a driver the note's panel hosts.
- **One clock.** A song and a voice cannot be on one note. The slot refuses it honestly; the mix
  ("a song ducks under a voice") is unbuilt.
- **A storyboard needs a sound.** With no song and no voice there is no clock, so no show. A
  storyboard of fixed holds could conduct itself (a silent film); `Spectrum` has no clock without
  audio yet.
- **Scenes are still code.** An entry names a scene and pins its seed; what the scene rolls from
  that seed is not data except on a `stage`. "Properties for the geometry, the lighting, the
  textures" is the scene-spec pipeline (roadmap): the Layer registry is the nearest step - a
  `layers` entry, as `stage` is for actors, would make `aurora` (`bed` + `stars` + `aurora`) a
  storyboard entry instead of a file.
- **No keyframed properties.** The Look, the camera dials and the holds are one value per note. A
  lane of keyframes for any numeric field is the modulation notes.md describes; the tables are
  what such a lane would be built from.
- **Frontmatter length.** A long storyboard is long YAML above the note's words: `MiniYaml.emit`
  writes block style. The escape is already there (a note may name a file); a flow style for list
  items, and editing a file in place, are the next rungs. Changing the emitter was left alone on
  purpose: it would reformat every note already written.
- **Transitions are three names.** `cut`, `dip`, `fade`, and a morph where two entries line up. A
  transition as its own timeline item is not built.
- **The editor is not judged by a person yet.** It was looked at through rendered pictures
  (`tests/storyboard_look_probe.gd`), not used.

## Next, in order

1. The user's own pass over the editor: what is missing to write a real story with it.
2. A `layers` scene: an entry that composes Layer registry entries, with a table per layer.
3. The storyboard conducting itself with no sound.
4. The voice as a card on the note's own panel (the workspaces fold into one).
5. Property lanes: a keyframed value for any field a table marks as one.
