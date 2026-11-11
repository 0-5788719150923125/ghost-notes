# Editing a show: one document, made by agents or by hand

Opened 2026-11-10, the day Joker Motivation went out against its deadline. The user: "the pipeline system has
tightly-coupled text and animation behavior, and there is no easy way to fix mistakes without regenerating steps ...
backing up the scripts, making the behavioral changes, patching the scripts back in, retraining neural models, running
gates/tests that take an hour to complete, rinse and repeat." And the aim: "a more unified development model - where
humans or agents in the loop could just edit details directly ... a human should be able to create nonlinear scenes from
scratch ... But the human should also be able to generate an automated scene via agents, and 'debug' that scene via
manual mode."

An audit and a plan. Nothing here is built. It continues [storyboard.md](storyboard.md) ("the general case is the written
one") and [pipeline.md](pipeline.md); the measurements it quotes are in [framework_audit.md](framework_audit.md) and
[face_layers.md](face_layers.md).

## The verdict

Yes, there is merit, and more of the ground is laid than it looks. Three findings change what to build, and in what order.

1. **"Manual" exists, is reachable, and has never been used.** New, "+" Song, "+" Medium (Full frame), "+" Storyboard, then
   the card's "Timeline…": a dock under the show with a strip of entries, a lane per actor, an inspector drawn from field
   tables, undo, and the whole tree as YAML (`StoryboardEditor`, 2026-10-12). The README's animation is that note playing
   `storyboards/showcase.yaml`. storyboard.md's own words: "The editor is not judged by a person yet." It edits scenes and
   the `stage`, never a table.
2. **The premise is true of a table show.** Agents do pass data into functions: a toolset is an ordinary object
   (`list_tools`, `call_tool`) that gates already call with no agent and no socket, and what it writes (`table.json`,
   `acts.json`, `skin.json`) goes through pure static sanitizers every time it is built, "so an edit by hand is read the
   same way" (`TableProducer`). A file changed on disk is picked up within a second while the show plays
   (`TableMedium._poll_pictures`). The data was always editable. What is missing is everything around it.
3. **An editor alone would not have saved the weeks.** They went to four things an editor does not touch (below): words
   and work stored tangled, a step graph whose only verb is delete, time that is a guess until a voice says it, and tool
   behavior that is code. The first three must be fixed under any editor, and they are small. The last wants its numbers
   made into rows, which is other work.

So: build it, do not call it a mode, and do not start with the UI.

## What was found

### Where the weeks went (732687, from the episode's own files and face_layers.md)

```
plan -> cloth, room -> table -> picture to copy -> check -> layers -> 16 layer pictures -> painter host (GPU solve)
     -> skin.json -> acts.json (computed from the design) -> 7 passages (each reader told its beat's acts)
     -> script.md (composed) -> the voice, live -> the schedule
```

| Cause | The evidence | The patch it got | Removed by |
|---|---|---|---|
| Words name the work by its place in line | Passages carry `<!-- act: stage-1-2-flat-brush -->`; a painted show's acts are computed and named by order; painted again, stage 2 went from seven acts to four | `_recue_words`, `recue_map` (11-09, rewritten 11-10) | step 2 |
| To make again is to delete | `TableEpisode.has` is "the file exists"; `invalidate` removes what was made from it: "a 40-minute painting made again had thrown away a script worth keeping" | the lock (`unlocked.json`); five copies of the episode under `~/scratch_ghost` | step 1 |
| Time is a guess until the voice says it | The plan guessed the intro at 442 s, the voice took 510; twice a stretch of 90-120 s with no hand moving. A seek is by sentence, renders the voice again and un-pauses (`ReadingStream.seek`) | `schedule`, `_element_beats`, `SLOW_MOST` 1.6 to 2.5 | step 3 |
| One thing cannot be changed alone | A layer painted again was spliced into `skin.json` by hand (`el_200..el_224`); one liner run on the jaw (`el_224`) and one blend (`el_208`) each became a rule, a repaint and a splice where a delete would have served; the card's Folder button is the only way to an episode's files | by hand, each time | step 4 |
| How a tool behaves is code | Most of painted_surface.md's reports (how a sponge is rinsed, how hairs lie on a pot): 1,347 numeric constants in `src/table`, 97 in `hosts/paint`, each change behind 183 gates (6,414 s end to end) | code, gates, watch again | step 11, in part |

Also seen: the episode's table froze the brief's fixed things as it landed, the brief has since gained a swab dish the
episode lacks, and nothing says so. And `Motions.sanitize_law` drops a paint track's `manner` when it is `line` (what
`acts_from_painting` writes for a liner) with no note: seen in passing, not traced.

### Two families of show

| | Timed by | A function of show time | Its score today | Written by hand today |
|---|---|---|---|---|
| Letter, Dispatch desk, tablet, novel | the voice's words | yes | marks in the note's words (`ScriptMarks`, 71) | all of it, in the Body editor |
| Table, Proof | the voice's words | yes (physics baked) | marks in the episode's script, plus `acts.json` | nothing: the files are in `user://` |
| Scenes, the `stage` | the song | no: a simulation, verbs latch, no scrub | the storyboard (`scenes:`) | all of it, in the Timeline dock |
| Masking | the clip | yes (`MaskSession.at_time`) | markers | all of it |

The Letter and the Dispatch desk are already what the user is asking for: a person writes the whole show from a palette
of marks, and it plays. THE HOUSE STYLE FOR A SCORE IS MARKS IN THE WORDS, and it works. The table is the odd one out
only because its words and data live in a folder the app never opens.

### What is data, and what is not

- **Data an agent writes, a person could:** a table's things (20 shapes, 17 materials, joints, points, states, what
  runs and emits), its top and cloths, light, sound, air and ride; acts (15 laws, cues); a painted design's elements
  (id, tool, pot, beat, seconds); the plan; the passages; a storyboard's entries, a stage's cast and spans; a scene's
  230 told settings.
- **Data nobody should write by hand:** the painter host's strokes and maps (503 MB for 732687), a physics bake, a voice
  take. A person edits their causes: the element list, the acts, the words.
- **Code:** what a scene rolls (about 1,500 dice against 230 settings), which layers it composes, every desk prop and
  its placement, camera moves, and how tools behave.

### What exists to build on

- `StoryboardEditor`: the dock (`Shell.claim_bottom`, `claim_stage`), undo as the list of trees shown (`DataPath`, pure),
  the Source view, and `SchemaForm`, which "knows nothing of a storyboard" and has one caller.
- `TimelineView` (ruler, zoom, playhead: Masking and the storyboard share it) and `TrackLane` (a block read and written
  through Callables).
- `ScriptWriter`: a window with a highlighter and a palette of marks, on the note's body.
- `PipelineRow.STATES` already has `stale`. `Illustrations` already keeps a picture's versions (`{file, sig, at}`, the
  one chosen, `imported` for one a person brought), stale by signature.
- `TablePreview` stands a table on a worker and poses it at any time; `TableMedium.rework` binds new acts to a standing
  table; the bake goes back only to the first change; `TableBlueprint` draws the plan from above.
- Checks that are pure or nearly: the sanitizers' notes, `TableWork.check`, `TablePhysics.report`,
  `episode_bake_probe --audit` and `--plan-only`.
- `_render_take` already writes a whole take with every word's time beside it (for an export).
- Seams where a person stands in for an agent: `GameTools.asker`, `ActorBuilder.make_with`.

### What is missing

- Who made a step, from what, and what it replaced. A step is a file; nothing more is known.
- Any way to open an episode's words or data in the app.
- Typed field rows for the table. Its bounds are literal arguments (`Props._num(v, fallback, lo, hi)`); its `fields` are
  `[name, sentence]` for an agent to read. And the rows that exist come in five dialects (the storyboard's
  `float/int/enum`, a scene's `choice/num` with `range`, a layer's `num/flag/txt/dict`, Filters' none, Tonemaps'
  `min/max/step`); `SchemaForm` reads one, and has no color, slider or reference.
- A seek to any moment that stays paused, for a show timed by words.
- Picking: nothing on the stage answers a click, and the show's camera sees a table only 13-22 cm up.
- The checks as something a person reads. `Props.sanitize` throws its notes away; the idle-tool report lives in a probe.
- A painter host that solves one layer.

## The design

1. **A step is kept, never deleted.** Each step gains what a picture already has: versions, who made each (a role, or a
   hand), and a signature of what it was made from. Made again, the old one is a version back. A change upstream makes
   what came from it STALE (it still plays), never gone. 🔒 on a row means KEPT: Generate passes it by, stale or not, and
   a step a person changed is kept. This moves the lock from the step being made again to the step being protected,
   which is what "I REALLY don't want to lose this script" asked for.
2. **Words do not name the work's place in line.** A computed act is never cued: a beat's acts follow in order and share
   it by what each takes. Where a painted part must begin at a word, the cue names its LAYER (`layers.json`'s name
   survives a repaint). An authored act keeps its name when blocked again. A cue naming nothing is a problem shown,
   never a mark dropped.
3. **The script is one text.** `CardReading.parse` splits what `compose` joins, so the script is edited whole and written
   back to its passages; neither is ever remade over the other.
4. **The voice is the clock, so the take is kept.** Made once, a sentence at a time, cached by what it says and how;
   its word times are the ruler. With a take standing there is no guess: the plan, the live show and the export read
   the same times, a seek is a seek, and a changed sentence costs one sentence.
5. **The score is drawn from the script; it is not a second source.** A timeline for a word-timed show shows its words,
   beats, acts, cues and silences where the take puts them; dragging a cue moves its mark in the words. One truth.
6. **One row shape, and the table gets rows.** Type, default, bounds, choices and unit beside the sentence the agent
   already reads; the sanitizer takes its bounds from the row. The agents' prompts do not change by a byte.
7. **One thing picked, one inspector.** Not a card per kind of asset. A thing's shape, material, working parts, sounds
   and what it emits are one object in `table.json`, so they are sections of one form. A reference (a part's material,
   a track's thing, a cue's point) is a chip that picks what it names, and "used by" is said before a delete. The
   picked thing is a typed contract in `ui/`, since cards never name each other.
8. **An edit says what it costs.** On its row: `live` (set on what stands), `stand` (the table built again: 21-31 s
   for 732687), `bake` (physics from the first change), `paint` (the host), `voice` (a sentence).
9. **The checks are a list.** For a person, and the same list for an agent's tool.
10. **Agents work on what is picked, through the tools they have.** And a person can be the one who makes a step.

## What a person editing needs

| Need | Today | Step |
|---|---|---|
| See any moment at once, and stay there | by sentence, voice rendered again, un-pauses | 3 |
| See what happens when, against the words | nothing for a table | 6 |
| See the set from where the camera is not | the agents' pictures only | 7 |
| See who made what, what is stale, what was changed by hand | made or missing | 1 |
| See what is wrong, and go there | probes, in a terminal | 4, 6 |
| Know what a change will cost before making it | no | 7 |
| Pick a thing by clicking it | no | 7 |
| Change a value in a typed control, a range kept as a range | storyboard only | 5, 7 |
| Change the words, with the marks offered | the note's body only | 4 |
| Move work in time; add a silence | no | 6 |
| Remove or re-time one painted run | by hand in JSON | 4 |
| Replace a made picture with one's own | a note's pictures only | 4 |
| Undo anything; go back a version; never lose work to a ⟳ | storyboard undo; copies by hand | 1 |
| Hear or see just the part in question | the whole episode | 6 (a region looped), 7 (a made scene) |
| Use a thing again in another show | the brief's fixed block | 8 |
| Start with nothing and no agent | scenes only | 8 |
| Hand a detail to an agent with a note | regenerate the whole step | 9 |
| Change a look, a light or a level over time | Masking only | 10 |
| Tune how a tool behaves by eye | a code change and its gates | 11 |
| Fix one stretch of a video already rendered | render all of it (about 9x its length) | 13 |

## The plan

Sizes: **S** is a session with its gates (the Pipeline card was one), **M** a few (the storyboard editor), **L** a week
or more. None counts the author's time to look, which has been the limit: storyboard.md, pipeline.md, face_layers.md and
the Medium card each end on "not yet seen by the user".

**0. An hour with what exists (the author; no code).** Make the note in the verdict's first point, "Start from: the seeded
show, written down", change an entry, add a stage entry. Write down what is missing. It decides step 6's shape.

**1. A step that is kept (M).** `TableEpisode`: per step, who made it, when and from what (digests); versions kept as
`Illustrations` keeps a picture's (five for words and data, one for a host's maps); `stale` computed, `invalidate`
moves and never removes; 🔒 is kept; ⟳ makes one step and its dependents go stale; Generate makes what is missing, or
stale and not kept, in order. `unlocked.json` read once. "Keep a copy" on the section: the sources as they stand,
restored as versions. Proof's episode after. *Done when* `skin_step_check` and `episode_rows_check` hold that making any
step again removes no file (the control: today's `invalidate`).

**2. Words that do not name the work (S).** The design's points 2 and 3. `recue_map` and `_recue_words` go. *Done when*
732687 painted again, on a copy, changes no byte of its words (the control: an act mark in a painted beat).

**3. The take, kept (M).** A sentence's audio cached by its text and voice settings; the take a row ("Voice") with its
length; where a take matches the script, the reading plays it and the table plans on its times; an export uses it. The
live stream stays for a first listen. *Done when* `episode_bake_probe --plan-only` on a kept take gives the schedule the
export plays, and a seek while paused lands and stays paused (the control: one changed sentence remakes one).

**4. ✎ on a row (M).** Beside ⟳ and 🔒, and docs.py's "one pipeline" rule holds it there.
- Words: the Body editor's window on the episode's script. `ScriptMarks` gains the table's marks (`table:`, `act:`,
  `chapter:`, `quiet:`), the palette listing this episode's acts by name and what each shows. Proof's lesson likewise.
- Data (`plan`, `table`, `acts`, `skin`, `model`, `layers`): a Source window as the storyboard's, taken back only if
  it still sanitizes, every note shown and none thrown away.
- A painted design: its elements as rows (layer, tool, pot, beat, seconds): reorder, move to a beat, re-time, remove.
- Pictures: Import…, as the Pictures card has for a note's own.
- `--episode-check <dir>`: the same checks headless, in seconds, for an edit made in a terminal.
- The painter host solves one layer and replaces only that layer's elements.

*Done when* every hand edit made to 732687 on 11-09 and 11-10 is a press in the app, on a copy.

**Steps 1 to 4 are the small version**: no new surface but one glyph and two windows that exist, and the loop that cost
the deadline is gone. I would build them whatever is decided about the rest.

**5. One row shape, and rows for the table (L, mechanical, in stages).** One shape for every registry, the five dialects
turned to it. `SchemaForm` gains a color, a slider, a pair, a reference (chosen from a list or picked on the stage), a
formula and a list of maps. Then the table's rows: laws and acts first (15 laws, about 60 fields), then a thing and its
parts, materials, light, sound, air, the top and cloths, a design's elements. docs.py holds rows to code both ways and
writes `docs/table.md`. *Done when* `--check` fails a bound a row and the code disagree on, and a gate holds the agents'
vocabulary text byte for byte.

**6. The score (L).** The storyboard's dock becomes any show's: its shell (the dock, undo, Source, inspector) parted from
what is the storyboard's own, and a show HANDS it a score through a small typed contract in `scene_kit/`, beside
`ShowFeed`: a ruler (seconds, or the take's words), groups (entries; beats), lanes (actors; things that work), items (a
span: an act, a verb, a silence; a flag: a cue, a mark), and what moving one does. The storyboard hands the first, the
table the second, the desks theirs from the marks they have. On a table's: an act as long as the schedule gives it, its
idle stretch drawn; "words 244 s, work 310 s" where a beat's two lengths part; a click on the ruler seeks; a region
loops. PROBLEMS in the dock: the sanitizers' notes, cues naming nothing, idle tools, `TableWork.check`, the audit after
a bake - a click seeks and picks. The puppeteer's `act` is handed the same list (framework_audit.md's open item).

**7. The set (L).** A click on the stage names a thing and its part (a ray against what is built). A second view: the
plan from above (`TableBlueprint`) and a free look. The inspector of the design's point 7; drag on the plan to place;
add from the registries. Every field starts at `stand`, since the table already rebuilds itself on a changed file;
`live` is added where the wait hurts (place, light, color), and what the 21-31 s of a stand is made of is measured
first. A made scene of what is picked, for seconds instead of a bake. No gizmos.

**8. From nothing (M).** A Table whose steps are a person's: `agent:*` asked per step, not per note; an empty episode
(the default table, no acts, an empty script); a step marked BY HAND, where Generate stops and says it waits. A library
of things (a thing as `table.json` holds one, with its materials - the brief's fixed block is that shape). For the
stage, storyboard.md's open list in its own order, and a scrub inside an entry by playing it again from its start.

**9. Agents on what is picked (M).** "Ask…" opens the step's role with its toolset on the document as it stands, only
what is picked open to change, the person's note as its brief; what it hands in is a version by that role. And the
Assistant's second route: a report from a playing episode can go to a fix of the episode's data, not only of the code.

**10. Flags (M-L).** Masking's marker is a value that changes at a moment, eased before or after it, and holds; so is the
table's `to` law with what an act leaves. One flag on the score for any field its row marks as changing over time: the
Look, the camera, a light, a level, a state. This is storyboard.md's property lanes and notes.md's modulation. Masking
keeps its session and editor.

**11. Numbers a person has judged, as rows (S to begin, then one at a time).** A constant a report made someone change
gets a row with a default and bounds (`SLOW_MOST`, `REST_MOST`, `MOVE_PACE`, the laid hold; the host's `GROUP_LEAST`,
`SLIP_EVERY`), told per show (`table: tune:`) and moved while it plays. Named and bounded, never a free knob; a value
that proves right becomes the default.

**12. The other shows (S-M each).** Proof and the Actor take step 1 and ✎; the Letter and the Dispatch desk hand a score.

**13. A stretch rendered again (M).** cloud_render.md's `--from` and stitch, on this machine: a late fix renders its
stretch, not the six hours a 40-minute video takes.

## A compiled language (asked the same day)

The user: "evaluate if it would be worth moving much if not most of our code to the C# backend ... and if we should
consider starting that migration as a part of this migration, as well?" Measured and answered in [csharp.md](csharp.md).
In short: C# would help a great deal where the slowness is our own arithmetic (13 of 55 scenes cost more than a 60 fps
frame in script alone; one loop compiled runs about a hundred times faster), but that is a few kernels, not most of the
code, and for the scenes the idle GPU is the first lever. Not with this work: different code, and two migrations at once
leave every regression with two suspects. The plans meet in point 8 above: `stand` and `bake` are the waits a person
editing feels, so if a spike clears C#, the solver and the builders go before step 7.

## Decisions for the user

1. **The lock's meaning.** Today 🔒 ties a step to what is made from it; I propose it protect the step it is on.
2. **What Generate does with a stale step.** I propose: makes it again unless it is kept.
3. **Where an episode's sources live.** Today `user://table/<show>/<seed>/`, outside the note's repository, which is why
   backups were by hand. Words, acts, table and design are tens of kilobytes: beside the note, its own git would hold
   them. Pictures and bakes stay in `user://`. (notes.md planned `user://notes/<id>/`; never built.)
4. **Is a take required before Play?** I propose no: live for a first listen, kept once the words are liked.
5. **The inspector: in the dock, as now, or a card on the panel.** A thing has many rows and the panel is tall. I
   would start in the dock because it exists, and move it if a thing does not fit.
6. **Per-show tuning (step 11).** It lets two shows part in how a brush behaves. I think that is right; it is yours.
7. **How far.** The small version, then step 0, then decide - or the whole of it now.

## Opinions

- **It is not a mode.** Nothing should be called Manual. Every row has ✎; every show has a score; an agent is one
  maker and a hand another. "A panel names no mode" already says it.
- **No cards for props, sounds and shaders, and no links drawn between cards.** The links are already in the data as
  names. One thing picked, shown whole, costs a tenth of that and cannot fall out of step.
- **Patch the data for the deadline, fix the class after.** "Fix entire classes of problems" is right for the framework
  and wrong as the only tool the night before a release. `el_224` should have been a delete and a roadmap line.
- **Agents gain as much as people.** Kept steps, real times and a problems list are what a puppeteer or a session in a
  terminal lacked too: framework_audit.md found 78 of 105 minutes inside our own tools.
- **Do not merge the stage's Cast and Actions with the table's Props and Motions now.** They are the same idea at two
  depths, and one renderer is its own roadmap item. Share the row, the step and the score; the rest can wait.
- **Cattle, not pets, still.** A told value is shown as a pin with its reset, and a range stays a range in every form.
- **NO CHEATING holds:** a reader asked to write one beat again is still shown only what came before it.

## Risks

- **Two truths, a hand's and an agent's.** Kept, stale and versions answer it. I would not build a layer of patches
  re-applied over regenerated data: every such scheme breaks where names change.
- **The bake's thread.** framework_audit.md's crashes were two threads in one container. Every edit goes in by the
  ways a puppeteer's `act` already does (`rework`, `rebind`, a rebuild on the worker), never a new one.
- **Gates.** Each piece needs a two-sided gate, and panel gates are slow. Favor pure ones (a tree in, a tree out).
- **Step 7 is where this could become a 3D editor.** The plan view, numbers and a pick; stop there.
- **Scenes cannot scrub.** The stage's verbs latch; step 8's replay is the cheap answer, not a rewrite.
- **Disk.** A version of a host's maps is half a gigabyte: one back, no more.
- **Not on a phone.** Every piece asks for the desktop, as the stage does.

## Status

Audited and planned 2026-11-10; nothing built, nothing decided. Next is the user's: the decisions above, and step 0.
