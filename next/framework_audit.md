# The work at the table, audited (2026-11-01)

The user, of a week spent trying to get one clean episode of The Quiet Crucible: "are our bugs coming from our own,
underlying framework code? Or are they coming from agents that have too much freedom, and are making the wrong choices?"
and "generating these episode plans is REALLY slow ... hours and hours". Feedback 0001-0003 of 2026-11-01 (841899 played
live): the ladle "just floating above the cauldron"; the pestle "floats weirdly above the mortar, then moves upward, then
moves downward into the mortar"; the mortar tipped "into the cauldron, we miss it completely. The ingredients land in the dish
beside the mortar". And the live viewer lags.

## The answer: the framework

Measured on the episode itself (its puppeteer's own job folder, `jobs/acts/`), never guessed:

| What was asked | What the record shows |
|---|---|
| Was the agent stuck in loops of correction? | No. The puppeteer (Sonnet 5.5) made 48 `act` calls for 38 acts - ten rewrites - and 10 `remove`s. Its own API time was **9.7 minutes** of a **105-minute** job. |
| Then where did the time go? | Into our tools: at least 78 minutes inside `act` and `watch` (their heartbeats). An `act` took 30 s at the start of the show and 150-250 s at its end; a `watch` 120 s. |
| Why did it not watch its acts? | Each look cost two minutes. It watched 9 of 38 and said so: "Most of them I never watched". |
| Feedback 0003, the pour that missed | The agent first wrote exactly the primitive the rules ask for - `{"law": "pour", "into": "brew"}`. **It poured nothing**: `pour` turned a vessel only as far as a liquid's brink, and an empty mortar's brink ends at 62 degrees, where ground resin does not slide. It then fell back on the hand-written tip the prompt's own EXAMPLE showed (a carry to a point and a path turned -115 degrees), and `act` answered **"63 in the copper cauldron on its brazier"** - the brazier's pan is a part of that thing, so a miss read as a hit. |
| Feedback 0001, the ladle over the cauldron | `ladle-to-pot` carries the ladle over the pot; `ladle-stir` is cued at a word. Between them our rule HELD a thing that would fall "until its next move" - however long that is, with a hand nobody sees. Live, the stir's word came later than the rehearsal thought. |
| Feedback 0002, the pestle | `pestle-lift` held it 14 cm over the mortar; `frank-grind` waited 15 s for its word (the probe's schedule: 231.6 s to 247.0 s); then the aim's entry raised it a fixed 10 cm (`BLEND_LIFT`) before lowering it in. |

The agent can know none of these timings: a live reading places an act only when its word is heard. Only the framework can
keep what is between acts at rest. Sonnet was not what failed; Opus would have met the same tools.

## Why the classes keep coming back

Three structural causes, each behind many of the nights' patches:

1. **TWO MODELS OF WHERE A THING IS.** The work (`TableWork`) poses things by closed-form laws from what the agent wrote; the
   physics (`TablePhysics`) simulates them; and every disagreement is settled by a local rule (held back, catch up, re-based,
   held aloft, let go, trial, weld, seat, rest, stands in, yields to). Each rule held for the shapes it was written for. A
   new shape, a new timing, a new rule.
2. **THE PAST DEPENDED ON THE FUTURE.** What the physics world *was* was decided from every act at once: a free part was a body
   only if some act, at any time, moved it (`_make_rigid`, `_goes`, `TableWork._moved`); a thing was held in the air if a later
   act would take it up (`_moved_after`). So a jar no act moved was an immovable solid, and the same jar a body the moment a
   later act fetched it. And because the world changed with the acts, a bake could not be carried from one draft to the next:
   `_layout_of()` hashed the bodies and the sprinkles, and `_plan_of()` hashed every moved part - any act that moved something
   new threw the whole bake away.
3. **THE AGENT WRITES GEOMETRY, AND WAS TOLD ABOUT IT IN NOISE.** Places are centimeters and turns are degrees; `act` answered
   with what the solver did in words that were sometimes wrong ("63 in the copper cauldron on its brazier"), sometimes the
   framework's own lag blamed on the agent ("HELD BACK by the table's top" for a jar 18 cm in the air, behind its fast hand),
   and sometimes impossible ("came to rest 32 cm from where the act left it - now in the air"; "90 cm" for a cork that rode its
   jar home).

## Measured

Every number is from the episode's own table (a copy), on this machine.

- **A whole-show bake: 161 s** (`episode_bake_probe`, 345 s of show). A stepped frame costs 10-16 ms; frames where nothing
  moves cost nothing, but from 10 s to 130 s every one of 7,200 frames was stepped.
- **Where a stepped frame went** (`--profile-bake`, ms): liquids 4.6 (twelve liquids, most in bottles nobody touches),
  particles 1.9, rigid bodies 1.7, solids 1.5, the frame's record 0.5.
- **A puppeteer's call** (`tests/table/act_calls_probe.gd`, the job's own first 29 calls replayed through the real
  `PuppeteerTools`): a table stood afresh every call (6.5 s for the room, then the work and its physics built again), then
  baked from wherever the plans part - from the show's start whenever an act moved something new (calls 6, 8, 9, 13, 26, 28).
- **The live viewer**: a playing frame cost 24-32 ms of the app's thread, so the stage governor dropped the picture to one
  frame in six (level 3, about ten a second) - the lag. Paused, the same table drew in 6-7 ms: the picture is cheap, the
  work done every frame while it plays is not. `TableWork.tick` posed all 282 parts every frame, changed or not: 14.2 ms of a
  16.7 ms medium frame.

## What was built

| | Before | After |
|---|---|---|
| The puppeteer's whole job, all 70 calls and its 9 watches, replayed through the real tools | ~95 min (105 less 9.7 of model) | **16.2 min** (974 s) |
| ...its `act`s' checks | ~700 s | 58 s |
| ...a `watch` | 120 s | 10 s |
| The puppeteer's first 29 calls, replayed | 810 s | **348 s** |
| A call that moved something new (calls 26, 28) | 95 s, 126 s (baked from 0) | 36 s, 46 s (from 73.5 s, 106 s) |
| A call rewriting one act | 15-30 s | 3-7 s |
| `physics_check` | 280 s | 100 s |
| A live table frame's CPU (medium, during the stir) | 16.7 ms | **6.6 ms** |
| ...of it, the parts posed | 10.0 ms | 2.2 ms |
| ...of it, the grains drawn | 2.7 ms | 1.2 ms |

### 1. The world is the table's (`TablePhysics._goes`, `_make_rigid`; `RigidParts` "dormant")

Every free part and every thing that may be moved whole (all but what holds a flame) is a body as built, whatever the acts are.
Untouched it is DORMANT: exactly the solid it was before it was a body - reckoned no further, met as a solid, counted as no
displacer in a liquid (`_dormant`) - and woken by nothing but a hand taking it up or what holds it moving (`RigidParts._stirred`).
Tried first with bodies woken by whatever came near: the table woke itself and never settled (rigid bodies 92 s and grains 20 s
of every 10 s of show, six liquids sloshing) - the "won't settle" class, made at will. So nothing passing near wakes it. Which
hollows are reckoned as insides (40 at most) is the table's too - what holds something, then a thing's parts, then whole things,
ties by index (`_make_liquids`): ranking every whole thing with the parts had cost 841899's mortar its inside to a recipe tin's.

### 2. One table for the puppeteer's whole session (`TablePreview._stand`, `TableMedium.rework`, `TableWork.rebind`, `TablePhysics.rebind`)

The table is stood once; each later `act` binds the new draft to it, and the bake goes back only as far as the draft changes -
by an act's NAME (indexes shift as acts are inserted), its time and WHAT IT DOES (`_changed_from` compares the track: a rewritten
act keeps its name and time, and live readings had only ever changed times). Sprinkles are kept by their act's name and track
(`_find_sprinkles`), their grains made once and never moved. And a rehearsal that has not changed is not made again
(`rehearse`): each act a call checked had rebuilt every channel's timeline, half of what the calls waited on. The work's own state is split: what the table is (`build`) and what
the acts decide (`_take_acts`, `_fit_acts`, `_build_cues`).

### 3. A frame costs what moves in it

- A liquid at rest stays at rest (`TablePhysics._calm`): its vessel still, its surface calm and unwaved, nothing pouring, filling,
  boiling hard, moving or awake in it - its last frame's answer.
- A live frame poses only what can have changed (`TableWork._settled`, `_spans_for`): a part whose channels have no move at the
  moment, that runs and swings by nothing, and whose physics pose, fill and wholeness are as last drawn, is left; a jump in time,
  a new plan or a check poses all. Grains are drawn again only where they moved (`_draw_particles`), their turns found once.

### 4. Nothing hangs in the air between acts (`TablePhysics._held_aloft`, `HOLD_MOST`)

A hand holds a thing that would fall in the air only across a pause: its next move begins within 3 s (a mortar held over the pot
while the other hand puts the pestle back), or its own act goes on. Otherwise it lets go gently there - set down into the vessel
under it, or onto what is under it - and the next move takes it up from there, its way to its work planned from where it lies
(`_held_pose` drops the entry's lift planned from the air; a point against a vessel's wall is in the vessel, `_against_inside`). Nothing looks further ahead than the pause, so live and exported agree. And `act` says so whenever a move leaves a
thing in the air (`TableWork._aloft_said`): a rehearsal plays acts back to back and never shows the gap a live reading opens.

### 5. A tool comes to its work as a carry goes (`TableWork._entry_lift`, `BLEND_TURN`)

An aim's or a circle's entry is lifted as far as clearing its way asks (`_clearance`, the carry's own measure), and a hand's
whole lift when it turns much on the way, turning about the part's middle after it has risen - never about a node's far origin,
and never a set 10 cm: a pestle over its mortar goes straight down into it; a ladle lying on its rest rises before it turns.

### 6. `pour` pours what does not flow (`TableWork._pour_at`, `POUR_WET`), and the example shows `pour`

Past its liquid's brink a pour turns on to its `tip` (120 unless written), the time shared by the turn each part makes - so a
mortar's powder or a dish's stone slides out over the lip where it was put. The prompt's example (copied, as examples are)
pours with `pour`, and the rules say `pour` takes whatever a vessel holds.

### 7. What `act` says is true

- A pour is judged against what it was meant for (`TablePhysics._pour_said`, `_targets_of`): what left the vessel - its liquid's
  parcels, the grains and pieces in it or on it - counted in, or MISSED, by the part each went into.
- Where a thing is, is said by the PART (`_where`, `_liquid_label`, `_body_where`): "the inside of the copper cauldron on its
  brazier's brazier pan", never the thing alone; on what is under it, looked for straight down; never in or on itself.
- HELD BACK only where something held it (`report`): a body behind its fast hand in clear air is no collision. A body judged
  against what it rides, so a cork carried home in its jar is not "90 cm from where the act left it". A mover's loose and
  free parts are the physics', never counted as the mover passing through something (`check`).

### 8. The live viewer buffers (`TablePhysics.reach`, `ReadingStream.BUFFER_PAUSED`, `Spectrum.ready_ahead`, the transport)

Paused, the table's physics bakes on to the show's end and the reading's voice is made ahead (900 s at most); playing on, the
host is asked again only as the made voice runs down, and the bake is already there - so the buffered stretch plays without
either beside it. The rail shows it, lighter than what is played, as a video player shows what it has loaded
(`ShowFeed.ready_ahead`, `paused`; the conductor's `ahead`).

### 9. Played live: the crash and the freezes (the same evening; `episode_bake_probe --live`)

The user, re-blocking 841899's work and playing it live: a crash (signal 11 in `_draw_liquids`), and "every time the ladle is
pulled out of the liquid, to return to its holder, there is a solid 3-4 seconds of completely-frozen screen, while the audio still
plays ... Shouldn't the buffering have helped?" It could not: neither was the bake. `--live` plays an episode as the app does - the
words a sentence at a time, the bake on its own thread (`TablePhysics.threaded`), the clock the wall's - and says each frame that
held the app's thread, by what took it; on a GPU (`GHOST_PROBE_GPU=1`) each whole frame too. A probe that baked the whole plan
first (`--stalls`) found nothing over 34 ms in the whole show: every cause below is the live path's.

- **The crash: two threads in one container.** `_draw_liquids` read the twin's channels as the bake took a new plan and freed
  them. Played live, the probe died a minute in, then at 451-475 s (`double free or corruption`, `corrupted size`,
  `smallbin double linked list corrupted`) - the same class seven more ways: the work and the twin posing one plan's entries, each
  writing what it found into them; the bake adding keys to the solids (the points it meets a body by, its matter, its mass, whether
  it stirs or presses), the loose things and the sprinkles while the app's thread read them; a liquid's inside made from the bake's
  own solid; the app's thread writing a texture into a liquid the bake reads; both threads making a field's surface points the
  first time, each letting the empty array go; and a frame naming its woken bodies by `_woke` itself - a packed array held in a
  Dictionary is the same array, grown and cut by the bake under the picture's reads. (The probe's own profile, written by both
  threads, was a ninth; kept apart now, `drawn_profile`.) The rule, in TablePhysics' header: the app's thread reads only frames
  (each with its own copy of its woken bodies, `wk`), what was made before the bake began, and its own copies
  (`TableWork._solids_ref`, `_drawn_mm`, `_wave_tex`, `_sprinkles_drawn`); the twin is handed copies of the entries
  (`_entries_of`); every key the bake finds later is seeded at build; a field's points are made at build, under its lock. Played
  again through every stretch that had crashed, and the whole show: none.
- **The freeze, every sentence.** Each plan a live reading makes (one a sentence) worked out again, on the app's thread and twice
  over, where every carry so far comes to rest and how far it is set down. By the second stir: 2.6-3.2 s of room and set-down a
  sentence (370-480 s: a 2.8-3.5 s stall every 3-6 s) - the picture frozen whenever the ladle moved. Now a carry's end needs no
  way over or rise (at its ends a carry is where it is set, `Hands.carried`); what an entry found is kept for the next plan where
  nothing before it changed (`_same_until`, `FOUND`), its start and end with it; a set-down or a way over poses the table once
  (`_meshes_at`), casts only where a mesh's box is (`_over`), and takes what no act moves where it was built (`_still`). The ladle's
  set-down 109 ms to 8. The whole show played live, alone: a sentence 63-77 ms on the app's thread (the worst 157 ms), every frame
  between them 4.9 ms on average - nearly all of it the moves placed after an act still stretching, whose times every sentence
  moves (`plan: each move's ends`).
- **The freeze, the first drip.** On the GPU, at 88.8 s as the ladle came out: 3.4 s for one frame, 116 ms of it the table's - the
  stream and drops, made the first time anything dripped, their shaders built then. Now they are made with the table and a copy
  of each, in the same material, drawn at nothing's size for its first frames (`_drawn_nodes`): the table's first frame takes
  2.3 s more, and 88.8 s is a frame like any other (the worst of the table's work in the first 110 s: 48 ms).

Gates: physics_check `_kept_across_plans` (a plan made again finds nothing again; the control, a move changed before it, both
again), `_warmed_first` (the drip's nodes and their warm copies, in the same materials, made with the table and let go),
`_frame_names_bodies` (a frame kept across a restore still poses its woken rod - it failed on the frames that held `_woke`).

### 10. Scrubbing is seeking, and nothing is dropped for a word not yet heard (later the same night)

The user, feedback 0004 at 263.9 s ("By a nigh-" in the caption): "the pestle disappeared, and then reappeared ... the mortar is
also freaking out, stuck tipping the wrong way, after it already poured its contents into the cauldron" - and, scrubbing back to
look again, "it's just stuck on 'catching up'. Are we re-buffering from the very beginning, or starting from wherever we scrubbed
to? It might be best if we just saved the buffer... so that returning to a position is fast."

- **From the very beginning.** A scrub starts the reading again from a sentence, timed from 0 - and the table, its acts and its
  bake were made again for it: built again (10 s), and its physics baked from the show's first act, the past placed on guessed
  word times so nothing of the last bake matched - 153 s of 841899 before a frame. Now A SCRUB IN THE SAME EPISODE IS A SEEK
  (`TableMedium._seek_to`, `ReadingFollower.seek`): the table keeps the clock of the reading it was made for, the new reading's
  words come on it where they were heard before (`offset`), every word heard keeps its time, so the plan stands and what was
  baked is looked up. A new table only for another episode or acts blocked again (`_as_built`). Played to 120 s, scrubbed back
  to 58 s: the same table and bake, 0.0 s waited, the worst frame 20 ms, the ladle drawn within 0.3 cm of where it was.
- **The mortar.** `mortar-home` is cued at "By"; a live reading places an act only once its word is heard, and the pour ended
  first - so the hold rule (section 4: nothing held for an act not placed) let go of the mortar over the cauldron, where its pour
  had left it level: it came down on the rim and lay there tipped, and when "By" came, the plan was baked again only from
  `mortar-home`. An export, every word known, held it across the second between. Now A THING IS HELD FOR AN ACT STILL TO COME,
  a pause at most (`TablePhysics._to_come`, `_holds_across`) - a hand holds what it poured from while it finishes the sentence -
  and a plan that has the hand hold what the last plan let go of bakes again from that move's end (`_hold_changed`): live is
  what the export makes. Not the other way: going back for a moment's hover had the show wait (841899's stir placed 14 s after the
  ladle's move took the bake back 10 s).
- **The pestle**, gone and back, was not reproduced here, and the cause given for the mortar was at most part of it: section 11 has
  what they were.

Gates: physics_check `_held_till_placed` (held while an act is to come, let go after a pause; an act placed within the pause bakes
nothing again, one moved into it after a let-go bakes from the move's end); table_work_live_check's seek (the same table, its clock
put where the first word was heard, its bake standing, the pestle where it was drawn; the control, acts written again, a new
table). Probe: `episode_bake_probe --live --seek=T`.

### 11. "Stuck together" (feedback 0005-0007, the same night)

The user: "The pestle and the mortar are now moving in-sync, as if they are stuck together. The pestle is being blocked by the box of
cards, and thus the mortar is ALSO being blocked" - then "the pestle clipped through the table and the mortar falls to the table" -
and "I did skip ahead in the timeline ... We may need to ensure that timeline scrubbing can recover properly." Three faults, all
live-only, all shown by `episode_bake_probe --live --script --pace=` (see below). The reports held the clue: the bake had the pestle
in one place throughout (`bake_off_work_cm` 0.8), while it was DRAWN 1.8 degrees round as the mortar swayed 1.6.

- **They were stuck together in the picture only.** A free part's node hangs from its thing's, and a frame posed it again only where it
  can have changed (`TableWork._settled`, section 3 - this audit's own optimization), asked of the moves WRITTEN on the thing. A body also
  moves outside them: swaying in a hold, let go and falling, catching up. So the pestle at rest was dragged along by the mortar's
  every motion, through the box, down through the table as the mortar fell, until the next pose took it back ("disappeared, and then
  reappeared", 0004). Now a frame that moves a node poses again every free part hanging from it (`tick`'s `stirred`, parents first,
  `_order_of_posing`). physics_check `_part_stays_when_thing_goes`: 13.6 cm off before, none now.
- **The mortar fell because a hand let go where nothing could take it.** At the voice's own pace there are 4-5 s between the pour's end and
  "By" - past the pause, so the hand "set it down where it is": on the cauldron's rim, from which it tumbled to the table, 112 degrees over,
  and trembled there. Baked on those times it ends 33.2 cm from home at 111 degrees; 0007 reports 33.5 and 112.8. The pause had been
  raised from 1 s to 3 s for this same fall (section 4): the number was treated, not the rule. And the test it rested on could not
  see it: tried for 1.2 s, the mortar had turned 13 degrees and dropped 8 mm - tipping over a rim begins slowly - and was judged at rest.
  Now A HAND NEVER LETS GO WHERE WHAT IT HOLDS WOULD TUMBLE (`TablePhysics._lands_ill`, `LAND_TRIAL` 3 s: turned past `LAND_TILT` and down past
  `LAND_DROP`, and not standing in a vessel - a ladle turns as far coming to lean on a pot's rim, and comes down a centimeter): it holds
  on for a next move within `HOLD_ILL` (8 s) or one still to come, and otherwise puts it back where it last rested (`_put_back`).
  Baked again: level over the cauldron for the 4.6 s, then home. physics_check `_not_dropped_on_a_rim`.
- **A skip ahead performed what it skipped, as it landed** (`ReadingFollower.seek`, the user's own guess): the words skipped had no times, so their
  acts were placed as their moment had passed, squeezed, on the landing: the ladle in, stirred and home in 4 s. Now they are given
  times before the landing, spaced as the estimate spaces them, and their acts are baked at their full length before it: the world
  landed in is the one the reading would have reached. And a scrub forgets what it left ahead of it (`TableWork._begun`): those acts
  are placed again by their words. table_work_live_check `_skip`, whose control fails as the probe did (`fetch-jar` at half its length,
  ending after the landing). A skip still bakes what it skips - 44 s for 100 s of show - and returning anywhere baked waits for nothing.

Why it took three rounds: the probes were not the live show. A take carries the script it was exported from, and 841899's had been
written again, so its acts were cued at other words (`--script` plays the script as it stands); and the plan's estimate runs faster
than the voice (`--pace=`: the rail's 2:46 was 263.9 s of show, about 0.63 - and the sentence rests are longer still). At pace 1 all
of this was clean.

### 12. The brew that drained, the feather that bounced (feedback 0008-0011, the same night)

The user: "Every time I've seen the ladle go into the pot, the liquid level decreases - even though the law of displacement should make it increase", "The amount of
liquid never recovers", and of the bugs left, "ones which you have already tried to fix before, and apparently never did". That was so: `_level_counts` (section 4's round)
held a ladle stood UPRIGHT in a pot, and passed, while the show's ladle tipped against the wall. Baked on the script as it stands (`--script --pace=0.6`): 996 ml at the start,
668 by 200 s, 438 by 352 s, 273 by the end.

- **A vessel with part of its rim under a liquid was a siphon** (`TablePhysics._dips`). Let go, the ladle tipped against the wall. The side of its rim under the brew filled it;
  the slosh of a surface 6 cm across stood it over the other side, which poured at 400 to 1,163 ml a second; most of that struck the pot's wall where no inside was found and
  was counted spilled. 260 ml in 0.65 s, with the ladle holding about 45 ml throughout. Now while any of its rim is under, the two are one surface (`dipped`): it does not slosh
  or pour, and the flow goes both ways until it stands as high inside as out.
- **The level moved in stairs** (`Vessel._table`). A level is a quantile of the middles of a grid's cells, and those lie in layers: the cauldron's cells are 1 cm tall, so the
  surface stood at 9.54 cm from 668 ml down to 546, then at 8.59. Each point now stands for its whole cell, spread across its width along `up`. No percent of the brew moves its
  surface over 2.5 mm (the bare grid's: over 5).
- **A hand dropped what it was about to stir with** (`_held_aloft`, `_stands_in`): "what stands in a vessel is let go" had no limit below. Let go 15 cm up for the 1.6 s before its
  stir, the ladle fell, lay down, and was hauled upright 6.6 cm in 0.6 s. Taken up again within a pause, it is held (past one it still leans, as asked).
- **A body could go 58 cm a second, whatever its hand did** (`RigidParts._go`): 9.6 mm a frame, a limit for going carefully past what is near, applied in clear air too. The
  ladle's last act fell 44 cm behind its hand, reached its rest late, was let go 5 cm up and lay on it 18 degrees off. Clear of everything by more than the way, nothing limits it.
- **A sheet's outline met nothing** (`Particles.fill_shape`, `_sheet_outline`): what meets the world is a point at the sheet's thickness, and past its last point nothing. The
  feather's rows lay 1.9 cm apart, its tip between two: "a little red triangle poking out", the same report that had once widened its one line of spheres. Now each of
  `SHEET_REACHES` ways round, a point at the outline's edge.
- **What a hand lays down rests** (`TableWork.LAID_REST`, `_laid_by`): `fetch-feather` and `feather-in` are back to back, so "It came to the table, touched the table, then
  immediately bounced". A move ending at the table's top, or set `down`, holds its channel 1.2 s longer, on the live schedule and the rehearsal alike. A jar lowered in the air to
  pour goes straight on.

Baked again: 996.5 ml, 11.35 cm; ladle in, 11.46 cm (it RISES); ladle out after each of three stirs, 995.8 ml, 11.35 cm; 27 ml poured into the vial, as written; 1.3 ml spilled over
the show. The feather lies on the bench 1.2 s and on the pot's floor inside its wall; the ladle ends on its rest as built.

`episode_bake_probe --audit` (the next section's invariants, as a report): bakes the show whole and says each thing that must always hold and did not - liquid kept, a body in a
solid or through the table, a jump, off its hand, gone on by itself, hanging in the air, a loose thing past its vessel's wall. Run it before asking the user to watch. Gates:
physics_check `_brew_kept`, `_sheet_tip_in_pot`, `_stands_held_for_a_moment`; table_work_live_check `_laid_rests`. Feedback now reports each liquid's volume and surface.

### 13. A sheet that bends, a liquid never still (feedback 0012, 2026-11-02)

The user: "The phoenix feather is clipping through the ladle ... The feather should probably be more deformable, so that it's able to wrap and contort around the ladle ... but also gently
enough that it doesn't create a whiplash effect and spring the feather out of the liquid"; and "when nothing is touching the feather at all, it floats perfectly stable ... it should be gently
moving, according to the movement of the liquid and the weight of the object ... sometimes bob ... maybe spin a bit". New physics, for any sheet and any floater:

- **A sheet bends** (`Particles.make_soft`, `_soft_pass`; a sheet of `TablePhysics.BENDS`: plant, paper, fabric): position based dynamics' stretch and bending (Muller et al., 2007): links to each
  point's nearest, links across each point, a weak pull back to its own shape. A hand holds it rigid, its bend easing out (`_ease_held`). What it does is kept in every frame (`bo`,
  `TablePhysics.bend_of`) and drawn by `SheetBend`: each vertex follows its nearest points; normals from its own faces.
- **A thin tool cannot go between its points** (`Particles.THIN_TOOL`, a solid's `thin`; `SOFT_MOST` points): a 7 mm handle fitted between rows 1.9 cm apart. They meet it at their whole radius.
- **It is pushed no faster than the tool goes, and it slides** (`SOFT_PUSH`; friction off against a moving solid; `SOFT_CALM` shares speed along the links). A wet sheet gripped by a rising ladle went
  up with it and hung over the rim, half in and half out.
- **A vessel takes no part of a sheet with it**: what is in a moving inside rides it, and part of the feather rode off in the ladle's bowl, the rest in the pot, stretched 23 cm across the table.
- **A liquid is never still** (`Particles.current`, `swell`; `TablePhysics._flow_of`, `_agitation`): a stream function's two slow waves and two of swell, as hard as it boils and swirls, a pure
  function of the moment; a body afloat never sleeps. In a simmering pot, over 30 s: 12 cm of drift, 70 degrees of turn, 1.4 mm of bob, under 1 cm a second.
- **The whiplash was the stir's, not the feather's** (`_liquids_step`, `SWIRL_CORE`, `core`): a tool's speed over its nearness to the axis turned the whole surface as one, 4 radians a second as a
  tool passed the middle, and what floated at the edge went half a meter a second. Now a vortex: rigid to where the tool goes, falling away past it.

**The bake.** A stir had baked slower than it plays (35 s for 30 s) before any of this: 52 of 1,437 spheres awake, and a frame walking all of them a dozen times to find it. Now what sleeps on what
moves is found once (`_on_moving`), a sphere asks only the solids near it (`_near_of`), a dip is asked again only if something could have changed it (`was`), what displaces is asked of stirred
bodies alone. Results identical to the digit (physics_check's printed figures), 25-29 s for 30 s. A floater keeps every later frame stepped: a quiet stretch that cost 2 s of bake for 30 costs ~20 now.

Gates: physics_check `_sheet_bends_round`, `_floater_lives`, `_sheet_stays_whole`, `_sheet_tip_in_pot` (now what shows: out of the far side of the wall). `--audit` says: a thin tool through a sheet as
drawn, a sheet pulled out of shape, a loose thing out through a wall; `--soft-trace`, each sheet's points against each vessel. Bench gates held while the show failed three times here, each found by
the audit on the show's own acts: run it.

### 14. The vial that stayed empty (feedback 0013, 2026-11-02)

"When the ladle poured into the vial here, nothing happened. There is no liquid in the vial." The report held it: of every liquid only the brew had changed, 28.3 ml down, so neither the ladle
nor the vial held anything. Baked whole the vial took 26.9 ml, and rendered it stood filled. Played live it stayed empty: `ladle -> -1: 27.6 ml`, every parcel stopping at the height of the vial's
neck, with the stream, the lip and the vial all where they should be.

**What stopped it was a cork nobody could see.** `vial 1 cork` has `start: {shown: 0}`, and only `stopper-and-hold`, the act after the pour, brings it. `TablePhysics._shown` read `not twin._chan.has(ch) or value > 0.5`:
no act on the channel meant "there". With the whole plan known the channel exists, holds its start value, and the cork is not there until its act. Live, that act's words are not heard until
after the pour, the channel does not exist, and the cork stands in the neck as a solid while the picture, reading the same start value, draws nothing. Now no act on it is what it started as.

**The class: a plan that has not heard of an act must read as if the act will not touch the thing, never as if it already did.** Section 10 fixed this for a hand letting go, section 11 for a landing;
each was found by a viewer. So there is now a probe for the class. `episode_bake_probe --heard` bakes on this thread as a live plan comes to know the show (77 plans here, the bake 12 s past the clock), and
`--series`/`--against` say where any of 289 bodies and liquids parts from the whole plan's bake. No wall clock: 8 minutes for the show. Control: with the old `_shown` it reports the vial 26.9 ml short from 562.8 s to the end; with the fix, nothing on the bench.

On the whole show, 11 stretches differ, none of them the vial, and all so far read as one of two things:
- **The hand holds what it would have let go, until it hears the next act** (ladle at 26.2-30 s and 412.6-424.6 s: 8 cm, up to 72 degrees, and 16 ml between brew and ladle while it stands in the pot). `_hold_changed` re-bakes only a plan that holds
  what the last let go of, never the other way. So a live show and an export differ here on purpose: live the ladle stays upright, exported it leans in the pot for a moment.
- **What floats or is stirred goes its own way after that** (the feather from 412.6 s, 8.5 cm; frankincense tears from 318.6 s; a sulfur lump from 428 s, 41 cm at its most at 429.4 s, read as dissolved or crushed in one bake and not yet in the other; not traced). Small differences grow in a stirred pot.

Same fix on the route the user took: skipped to the bottling (`--live --seek=538:40`), the vial reached 27.3 ml. Reports now carry the table's own clock (`now`): after a scrub it is neither the report's `time` nor the rail's.

Gate: physics_check `_unbrought_not_there` (placed, unheard, heard after the bake; control: the cork brought first stops the stream). Before saying a show is right, run both: `--audit` on the whole plan, and `--heard --audit --against`.

### Seen on 841899 itself (`episode_bake_probe`, the take's own word times, a copy)

- **Feedback 0002, the pestle**: `pestle-lift` ends at 231.6 s 14 cm over the mortar; `frank-grind` begins at 247.0 s. Now the pestle
  is set down into the mortar at once and leans there (its middle 6.6 cm up, "by the mortar") through the 15 s, then goes straight
  into the grind (7.0, 7.7, 8.2 cm) - no hover, no rise.
- **Feedback 0003, the pour**: the agent's own first act, `{"law": "pour", "into": "brew"}`, now turns the mortar to 119 degrees over
  the pot and `act` says "POUR of the bronze mortar and pestle into "brew": 64 of the 64 pieces that left it went in"; the mortar is
  held over the pot for the 2.5 s the pestle takes to go back, then carried home. (At a 1 s pause it was set down on the cauldron's
  rim and tumbled into the brazier's pan - so the pause is 3 s.)
- **Feedback 0003 as it happened**: the agent's hand-written tip, played again, is now told "62 in the inside of the copper cauldron
  on its brazier's brazier pan, 1 in the copper cauldron on its brazier's brew" - where it had been told "63 in the copper cauldron on
  its brazier", and read a miss as a hit.
- **Feedback 0001, the ladle**: the same rule; the take's own stir follows its fetch at once, so it is not reproduced here.

Gates: physics_check `_pours_loose`, `_world_from_table`, and the hold tests rewritten to the rule (`_held_between`,
`_held_till_placed`, `_leans_in`, `_held_unless_resting`, `_rests_let_go`, `_sheet_lies`, `_level_counts`, `_dips_full`);
table_work_check `_held_up`, `_aloft` (the report says what a move leaves in the air). Probes: `act_calls_probe` (a job's calls
replayed, timed), `episode_bake_probe --profile-bake` (a bake's cost by section, and why each frame was stepped) and `--profile`
(a live frame's, by section).

## What a framework for any desk needs

LEGO, baking, a jigsaw and alchemy differ in their things, never in what holds them together. Five rules, each now true or named
below as open:

1. **The world is the table's.** What exists, what is a body, what can pour or break is decided by what was built, never by what
   an agent writes later (done for bodies; the next new kind of thing - a dough, a brick - must follow it).
2. **Nothing a frame does looks ahead.** Every decision at a moment reads only what came before it and at most a hand's pause after
   (done for holds); so any draft, live word or scrub is baked again from its first change, and live agrees with exported.
3. **The agent says what, the hand finds where.** A verb per kind of handling, its geometry found from the things themselves:
   `pour`, `dip` (done), `stir`, `grind`, `put` in or on, `snap` (a brick onto studs: a seat that welds, which exists), `knead`,
   `cut` (a blade exists). A verb is a small planner over the same primitives - reach, rise clear, carry, place by letting go
   (the trial), release - never a new physics.
4. **What was meant is checked against what happened.** Each verb carries its intent (into what, onto what) and the bake is judged
   by it (done for `pour`); a miss is an error the agent sees, by the part's name.
5. **A frame costs what changes.** Asleep and dormant things cost nothing to bake or to draw (done for bodies, liquids, posing and
   grains); a new primitive is written so from the start.

The primitives under them are few and mostly here: rigid bodies with contacts, seats and welds (bricks, lids, corks); swings by
weight (a balance, a hinge); particles with shape matching (grains, crumbs, dough, if its shape is let go slowly); liquids in
vessels (batter, brew); states over time (heat, color, fill, rise); sound from contact. What is missing is the verbs.

## Open

- **Verbs over geometry.** `pour` and `dip` showed the way: the agent names WHAT (the ladle, into the pot) and the hand finds
  WHERE. The same for stirring and grinding (`stir`/`grind` in a vessel, the tool's point placed by the vessel's own inside), for
  placing (`put` a thing in or on another, its resting pose found by letting it go - the trial that exists), and for showing
  (`hold up`). The laws stay as the escape hatch. Most of what the puppeteer still gets wrong is geometry it should not write.
- **Invariants, checked after every bake, as errors.** Nothing interpenetrates; nothing hangs unsupported while still; nothing
  moves faster than a hand; what was poured for a target lands in it (done: `_pour_said`); a thing set down is where it was set. `episode_bake_probe --audit` says them by hand,
  for one episode (section 12); telling the puppeteer, in `act`, is what is left.
- **One model of where a thing is.** The work plans the hand; the physics should be the only answer to where a thing is, and
  `check`'s PASSES THROUGH (the plan's poses) folded into the physics' HELD BACK, so one event is said once.
- **A plan's guesses.** A live plan places the moves after an act that runs "under" the words on a guessed end, and moves them
  every sentence: each is measured again (the 50 ms a sentence left above - kept from the last plan it would be a guess, and live
  would no longer be what an export makes), and where the guess proves early the bake goes back to it - 841899 at 418.5 s went
  back 30 s, to where the frankincense stir had been guessed to end, and the show waited for it. Guessing ends later, or measuring
  the moves on the bake's own thread, is the next step.
- **The bake's own cost.** A stepped frame is still ~10 ms of GDScript (a stirred liquid's level 1.4 ms, its waves 1.25 ms, every
  vessel pair's dip test 0.9 ms). Godot 4.7 does not let a physics space be stepped by hand, so Jolt is out; the remaining wins are
  islands (step only what is near something moving) and a coarser step for what is merely settling.
- **The picture.** Paused, the same table draws in 6-7 ms at the window's own size; a stage rendered at a lower scale while the
  governor is throttling would buy the rest.
