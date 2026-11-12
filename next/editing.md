# Editing a show: one document, made by agents or by hand

A show can be fixed without regenerating steps: humans or agents edit details directly, and a human can build nonlinear
scenes from scratch and debug them in manual mode. The C# question is answered in [csharp.md](csharp.md).

## What was decided

- **A step is kept, never deleted.** Made again, the old one is a version back; what came from a changed step is stale (it still
  plays); 🔒 means kept, and a step a hand changed is kept. Generate makes what is missing or stale and not kept.
- **Words do not name the work's place in line.** A cue names an act or a painted layer; a cue naming nothing is a problem said.
- **The voice is the clock.** Every sentence said is kept; a take kept is what plays, so a seek is a seek.
- **The Timeline: one document for every show** - groups, lanes, items (a span or a flag) on the show's clock
  (song, voice or seconds), each item on the `time` engine (a pure function of show time, seekable) or the `verb` engine (a
  simulation that may answer the music, reached by replaying its group). Its control is Masking's (`TrackLane`, `FlagStrip`,
  `TimelineView`).
- **One thing picked, one inspector, one row shape.** No card per kind of asset; every registry's rows read in one shape.
- **It is not a mode.** Every row has ✎; an agent is one maker and a hand another.

## Built (every piece with a two-sided gate)

1. **Kept steps** - `KeptSteps` (`notes/`) under `TableEpisode` and `ProofEpisode`: `steps.json`, versions, stale, kept, restore;
   Keep a copy; the painter host's maps one back; the Actor's steps one back (its ✎ puts them back).
2. **Words and the script** - cues bind to acts or layers (`TableWork.resolve_cues`); the script edited whole
   (`TableProducer.write_script`); `--episode-check <dir>` lists what is wrong.
3. **The voice** - `TakeCache`; a seek while paused stays paused; the Voice row keeps a take for the words and voices it was said
   in (`ReadingPanel.take_sig`), and Play plays it as a file, as a render does; an export takes a copy.
4. **✎ on a row** - `SourceWindow` (words, data as JSON, versions put back, its agent asked again with a note); a design's
   elements as rows (`DesignWindow`); a picture imported; one painted layer laid again alone (`lay_layer`, the host's `only`).
   On a copy of a finished episode, laying layer 13 of 16 (35 s) left every other layer's elements and design as they were, and
   the canvas outside the layer the same to the pixel (`tests/table_show/lay_layer_probe.gd`).
5. **One row shape** - `SchemaForm` (slider, color, reference, pair; `normalize` reads every registry's dialect); `TableRows` for
   an act, a thing, a part and each law's fields (the puppeteer's own sentences); `docs/table.md`, its bounds held by `--check`.
6. **One dock's shell** - `TimelineDock` with an inspector and Undo, filled by its owner; the storyboard's editor shares its parts.
   One timeline is open at a time, opened by the ☰ beside Play on every note (`Transport.offer_timeline`: the note's storyboard,
   episode, lesson or words' marks, the highest rank standing); while one is open the rail steps aside and the editor's strip
   tracks the show and seeks it. Flags carry no words (overlapping labels are unreadable); a flag's name is its tooltip, and the
   panel's Timeline card lists every item in order, a row picking it and moving the show there (`TimelineList`).
7. **The set** - a click on the stage names what is there (`Director.pick`): a stage's actor into its inspector, a table's thing
   and part into the dock - the table from above to drag it on (`TablePlanView`), its rows, its parts, + Part, + New thing,
   a free look.
8. **From nothing** - "By hand" episodes Generate passes by; a library of things (`ThingLibrary`).
9. **Agents on what is picked** - "Ask the set dresser / the puppeteer" about one thing or act, with a note.
10. **Flags** - `StageKeys`: the camera, an actor's size, hue and fade, and the Look's filters (`ShowFeed.turn_look`).
11. **Numbers as rows** - `TableTune`, told per show (`table: tune:`), on the panel's Pacing card: a component hands the rows it
    reads (`TuneSection`), a table show only those pacing the laws its acts use - no brush's for a show that paints nothing, and no
    card at all when nothing is offered (`PacingCard`).
12. **The other shows** - Proof's steps kept and its lesson a Timeline; every reading's marks a Timeline (`ReadingTimeline`, the
    Letter's and the Dispatch desk's too).
13. **A stretch rendered again** - `Stitch`, `--from`, the exporter's "A stretch again".

Also: the demo note "A prism divides" on a desktop's first launch.

## Decided by me, the user's to overrule

🔒 protects the step it is on; Generate remakes stale steps unless kept; episode sources stay in `user://`; no take is needed
before Play; the inspector lives in the dock; tuning is per show; the two docks stay two classes over shared parts; registries
keep their dialects and the form reads them; one reader of marks for every reading format.

## Status: what is left

- **The author's eye, first** (step 0): the demo note's Timeline, a key added, an actor clicked; on a copy of a finished episode a
  ⟳, a ✎, the Voice row, the inspector and the plan.
- A change on the set seen without the table standing again (measure what a stand costs first).
- Smaller: a material made new; a light or a level as a stage flag; a picture's painter asked from its row; an agent handed only
  what is picked as its toolset; more than one back for the Actor; every bound held by docs.py, not only an act's length.
- Seen, not traced: `Motions.sanitize_law` drops a paint track's `manner: line` with no note; an episode's table does not say
  when the brief has gained a fixed thing since.
- Failing on the committed tree too (checked on a clean `git archive` of HEAD): `table_place_check` (the title's
  settle before the first word) and the GPU gate `table_thread_check` (a table with no light built on a worker photographs
  differently, 7 pixels). The rest of the suite, 206 headless and 33 GPU gates, passes.
