# The work at the table, audited

The question: are the table show's bugs coming from the framework code, or from agents with too much freedom
making the wrong choices? The symptoms were a ladle floating above a cauldron, a pestle that hovers and then
rises before going down into the mortar, a mortar that tipped and missed the cauldron, plans that took hours to
generate, and a live viewer that lagged.

## The answer: the framework

Measured on one episode's puppeteer job folder (`jobs/acts/`):

| What was asked | What the record shows |
|---|---|
| Was the agent stuck in loops of correction? | No. The puppeteer made 48 `act` calls for 38 acts (ten rewrites) and 10 `remove`s. Its own API time was 9.7 minutes of a 105-minute job. |
| Then where did the time go? | Into our tools: at least 78 minutes inside `act` and `watch`. An `act` took 30 s at the start of the show and 150-250 s at its end; a `watch` 120 s. |
| Why did it not watch its acts? | Each look cost two minutes. It watched 9 of 38. |
| The pour that missed | The agent wrote exactly the primitive the rules ask for (`{"law": "pour", "into": "brew"}`) and it poured nothing: `pour` turned a vessel only as far as a liquid's brink, and an empty mortar's brink ends at 62 degrees, where ground resin does not slide. It then fell back on the hand-written tip the prompt's own example showed, and `act` answered "63 in the copper cauldron on its brazier": the brazier's pan is a part of that thing, so a miss read as a hit. |
| The ladle over the cauldron | `ladle-to-pot` carries the ladle over the pot; `ladle-stir` is cued at a word. Between them the rule held a thing that would fall "until its next move", however long that is, with a hand nobody sees. Live, the stir's word came later than the rehearsal thought. |
| The pestle | `pestle-lift` held it 14 cm over the mortar; `frank-grind` waited 15 s for its word; then the aim's entry raised it a fixed 10 cm (`BLEND_LIFT`) before lowering it in. |

The agent can know none of these timings: a live reading places an act only when its word is heard. Only the
framework can keep what is between acts at rest. The model was not what failed.

## Why the classes keep coming back

1. **Two models of where a thing is.** The work (`TableWork`) poses things by closed-form laws from what the agent
   wrote; the physics (`TablePhysics`) simulates them; and every disagreement is settled by a local rule (held back,
   catch up, re-based, held aloft, let go, trial, weld, seat, rest, stands in, yields to). Each rule held for the
   shapes it was written for; a new shape or timing needed a new rule.
2. **The past depended on the future.** What the physics world was was decided from every act at once: a free part
   was a body only if some act, at any time, moved it (`_make_rigid`, `_goes`, `TableWork._moved`); a thing was held
   in the air if a later act would take it up (`_moved_after`). So a jar no act moved was an immovable solid, and
   the same jar a body the moment a later act fetched it. And a bake could not be carried from one draft to the
   next, since `_layout_of()` and `_plan_of()` hashed the bodies and every moved part.
3. **The agent writes geometry, and was told about it in noise.** Places are centimeters and turns are degrees;
   `act` answered in words that were sometimes wrong ("63 in the copper cauldron on its brazier"), sometimes the
   framework's own lag blamed on the agent ("HELD BACK by the table's top" for a jar 18 cm in the air), and
   sometimes impossible.

## Measured

- **A whole-show bake: 161 s** (`episode_bake_probe`, 345 s of show). A stepped frame costs 10-16 ms; frames where
  nothing moves cost nothing, but from 10 s to 130 s every one of 7,200 frames was stepped.
- **Where a stepped frame went** (`--profile-bake`, ms): liquids 4.6 (twelve liquids, most in bottles nobody touches),
  particles 1.9, rigid bodies 1.7, solids 1.5, the frame's record 0.5.
- **A puppeteer's call** (`tests/table/act_calls_probe.gd`, a job's calls replayed through the real
  `PuppeteerTools`): a table stood afresh every call (6.5 s for the room, then the work and its physics built
  again), then baked from wherever the plans part - from the show's start whenever an act moved something new.
- **The live viewer:** a playing frame cost 24-32 ms of the app's thread, so the stage governor dropped the picture
  to one frame in six. Paused, the same table drew in 6-7 ms. `TableWork.tick` posed all 282 parts every frame,
  changed or not: 14.2 ms of a 16.7 ms medium frame.

## What was built

| | Before | After |
|---|---|---|
| The puppeteer's whole job (70 calls, 9 watches), replayed through the real tools | ~95 min | 16.2 min |
| ...its `act`s' checks | ~700 s | 58 s |
| ...a `watch` | 120 s | 10 s |
| The first 29 calls, replayed | 810 s | 348 s |
| A call that moved something new | 95 s, 126 s (baked from 0) | 36 s, 46 s |
| A call rewriting one act | 15-30 s | 3-7 s |
| `physics_check` | 280 s | 100 s |
| A live table frame's CPU (medium, during the stir) | 16.7 ms | 6.6 ms |
| ...of it, the parts posed | 10.0 ms | 2.2 ms |
| ...of it, the grains drawn | 2.7 ms | 1.2 ms |

### 1. The world is the table's (`TablePhysics._goes`, `_make_rigid`; `RigidParts` "dormant")

Every free part and every thing that may be moved whole (all but what holds a flame) is a body as built, whatever
the acts are. Untouched it is dormant: exactly the solid it was before it was a body - reckoned no further, met as a
solid, counted as no displacer in a liquid (`_dormant`) - and woken by nothing but a hand taking it up or what holds
it moving (`RigidParts._stirred`). Not woken by whatever comes near: the table woke itself and never settled. Which
hollows are reckoned as insides (40 at most) is the table's too - what holds something, then a thing's parts, then
whole things, ties by index (`_make_liquids`).

### 2. One table for the puppeteer's whole session (`TablePreview._stand`, `TableMedium.rework`, `TableWork.rebind`, `TablePhysics.rebind`)

The table is stood once; each later `act` binds the new draft to it, and the bake goes back only as far as the draft
changes - by an act's name (indexes shift as acts are inserted), its time and what it does (`_changed_from` compares
the track). Sprinkles are kept by their act's name and track (`_find_sprinkles`), their grains made once and never
moved. A rehearsal that has not changed is not made again (`rehearse`). The work's own state is split: what the table
is (`build`) and what the acts decide (`_take_acts`, `_fit_acts`, `_build_cues`).

### 3. A frame costs what moves in it

- A liquid at rest stays at rest (`TablePhysics._calm`): its vessel still, its surface calm, nothing pouring,
  filling, boiling hard, moving or awake in it - its last frame's answer.
- A live frame poses only what can have changed (`TableWork._settled`, `_spans_for`): a part whose channels have no
  move at the moment, that runs and swings by nothing, and whose physics pose, fill and wholeness are as last drawn,
  is left; a jump in time, a new plan or a check poses all. Grains are drawn again only where they moved
  (`_draw_particles`).

### 4. Nothing hangs in the air between acts (`TablePhysics._held_aloft`, `HOLD_MOST`)

A hand holds a thing that would fall in the air only across a pause: its next move begins within 3 s, or its own act
goes on, or an act is still to come (see 10). Otherwise it lets go gently there - set down into the vessel under it,
or onto what is under it - and the next move takes it up from there, its way planned from where it lies
(`_held_pose`; a point against a vessel's wall is in the vessel, `_against_inside`). Nothing looks further ahead than
the pause, so live and exported agree. `act` says so whenever a move leaves a thing in the air
(`TableWork._aloft_said`): a rehearsal plays acts back to back and never shows the gap a live reading opens.

### 5. A tool comes to its work as a carry goes (`TableWork._entry_lift`, `BLEND_TURN`)

An aim's or a circle's entry is lifted as far as clearing its way asks (`_clearance`, the carry's own measure), and a
hand's whole lift when it turns much on the way, turning about the part's middle after it has risen - never about a
node's far origin, and never a set 10 cm: a pestle over its mortar goes straight down into it.

### 6. `pour` pours what does not flow (`TableWork._pour_at`, `POUR_WET`), and the example shows `pour`

Past its liquid's brink a pour turns on to its `tip` (120 unless written), the time shared by the turn each part
makes, so a mortar's powder or a dish's stone slides out over the lip. The prompt's example (copied, as examples are)
pours with `pour`, and the rules say `pour` takes whatever a vessel holds.

### 7. What `act` says is true

- A pour is judged against what it was meant for (`TablePhysics._pour_said`, `_targets_of`): what left the vessel -
  its liquid's parcels, the grains and pieces in it or on it - counted in, or missed, by the part each went into.
- Where a thing is, is said by the part (`_where`, `_liquid_label`, `_body_where`): "the inside of the copper
  cauldron on its brazier's brazier pan", never the thing alone; on what is under it, looked for straight down; never
  in or on itself.
- "Held back" only where something held it (`report`): a body behind its fast hand in clear air is no collision. A
  body is judged against what it rides, so a cork carried home in its jar is not far from where the act left it. A
  mover's loose and free parts are the physics', never counted as the mover passing through something (`check`).

### 8. The live viewer buffers (`TablePhysics.reach`, `ReadingStream.BUFFER_PAUSED`, `Spectrum.ready_ahead`, the transport)

Paused, the table's physics bakes on to the show's end and the reading's voice is made ahead (900 s at most);
playing on, the host is asked again only as the made voice runs down, and the bake is already there. The rail shows
the buffered stretch lighter than what is played (`ShowFeed.ready_ahead`, `paused`; the conductor's `ahead`).

### 9. Played live: the crash and the freezes (the same evening; `episode_bake_probe --live`)

`--live` plays an episode as the app does - the words a sentence at a time, the bake on its own thread
(`TablePhysics.threaded`), the clock the wall's - and says each frame that held the app's thread, by what took it; on
a GPU (`GHOST_PROBE_GPU=1`) each whole frame too. A probe that baked the whole plan first (`--stalls`) found nothing
over 34 ms: every cause below is the live path's.

- **The crash: two threads in one container.** `_draw_liquids` read the twin's channels as the bake took a new plan
  and freed them, and the same class in seven more places: the work and the twin posing one plan's entries; the bake
  adding keys to the solids, the loose things and the sprinkles while the app's thread read them; a liquid's inside
  made from the bake's own solid; the app's thread writing a texture into a liquid the bake reads; both threads making
  a field's surface points the first time; and a frame naming its woken bodies by `_woke` (a packed array held in a
  Dictionary is the same array). The rule, in TablePhysics' header: the app's thread reads only frames (each with its
  own copy of its woken bodies, `wk`), what was made before the bake began, and its own copies
  (`TableWork._solids_ref`, `_drawn_mm`, `_wave_tex`, `_sprinkles_drawn`); the twin is handed copies of the entries
  (`_entries_of`); every key the bake finds later is seeded at build; a field's points are made at build, under its
  lock.
- **The freeze, every sentence.** Each plan a live reading makes (one a sentence) worked out again, on the app's
  thread and twice over, where every carry comes to rest and how far it is set down: 2.6-3.2 s a sentence. Now a
  carry's end needs no way over or rise (`Hands.carried`); what an entry found is kept for the next plan where nothing
  before it changed (`_same_until`, `FOUND`); a set-down or a way over poses the table once (`_meshes_at`), casts only
  where a mesh's box is (`_over`), and takes what no act moves where it was built (`_still`). The ladle's set-down
  went from 109 ms to 8; a sentence is 63-77 ms on the app's thread, every frame between them 4.9 ms on average.
- **The freeze, the first drip.** The stream and drops, made the first time anything dripped, built their shaders
  then (3.4 s for one frame). Now they are made with the table and a copy of each, in the same material, drawn at
  nothing's size for its first frames (`_drawn_nodes`).

Gates: physics_check `_kept_across_plans` (a plan made again finds nothing again; the control, a move changed before
it, both again), `_warmed_first`, `_frame_names_bodies`.

### 10. Scrubbing is seeking, and nothing is dropped for a word not yet heard (later the same night)

- **A scrub is a seek.** A scrub used to start the reading again from a sentence, timed from 0, and the table, its
  acts and its bake were made again (153 s before a frame). Now a scrub in the same episode is a seek
  (`TableMedium._seek_to`, `ReadingFollower.seek`): the table keeps the clock of the reading it was made for, the new
  reading's words come on it where they were heard before (`offset`), every word heard keeps its time, so the plan
  stands and what was baked is looked up. A new table only for another episode or acts blocked again (`_as_built`).
  Scrubbing back 60 s waits 0.0 s.
- **A thing is held for an act still to come,** a pause at most (`TablePhysics._to_come`, `_holds_across`): a hand
  holds what it poured from while it finishes the sentence, since a live reading places an act only once its word is
  heard and an export holds it across the second between. A plan that has the hand hold what the last plan let go of
  bakes again from that move's end (`_hold_changed`), so live is what the export makes. Not the other way: going back
  for a moment's hover made the show wait.

Gates: physics_check `_held_till_placed` (held while an act is to come, let go after a pause; an act placed within the
pause bakes nothing again, one moved into it after a let-go bakes from the move's end); table_work_live_check's seek
(the control, acts written again, a new table). Probe: `episode_bake_probe --live --seek=T`.

### 11. "Stuck together"

Three faults, all live-only, shown by `episode_bake_probe --live --script --pace=`.

- **Stuck together in the picture only.** A free part's node hangs from its thing's, and a frame posed it again only
  where it can have changed (`TableWork._settled`), asked of the moves written on the thing. A body also moves outside
  them: swaying in a hold, let go and falling, catching up. So a pestle at rest was dragged along by the mortar's every
  motion. Now a frame that moves a node poses again every free part hanging from it (`tick`'s `stirred`, parents
  first, `_order_of_posing`). physics_check `_part_stays_when_thing_goes`.
- **The mortar fell because a hand let go where nothing could take it.** At the voice's own pace there are 4-5 s
  between a pour's end and the next act, past the pause, so the hand set it down on the cauldron's rim, from which it
  tumbled. Raising the pause was treating the number, not the rule, and the rest test could not see it: tipping over a
  rim begins slowly. Now a hand never lets go where what it holds would tumble (`TablePhysics._lands_ill`,
  `LAND_TRIAL` 3 s: turned past `LAND_TILT` and down past `LAND_DROP`, and not standing in a vessel): it holds on for a
  next move within `HOLD_ILL` (8 s) or one still to come, and otherwise puts it back where it last rested
  (`_put_back`). physics_check `_not_dropped_on_a_rim`.
- **A skip ahead performed what it skipped,** as it landed (`ReadingFollower.seek`): the skipped words had no times, so
  their acts were placed as their moment had passed, squeezed. Now they are given times before the landing, spaced as
  the estimate spaces them, and their acts are baked at their full length before it, so the world landed in is the one
  the reading would have reached. A scrub forgets what it left ahead of it (`TableWork._begun`). table_work_live_check
  `_skip`. A skip still bakes what it skips; returning anywhere baked waits for nothing.

Probes must be the live show. A take carries the script it was exported from, so `--script` plays the script as it
stands; and the plan's estimate runs faster than the voice, so `--pace=` (about 0.63 for the rail's time; the
sentence rests are longer still) is needed. At pace 1 all of this was clean.

### 12. The brew that drained, the feather that bounced

The brew's volume fell from 996 ml to 273 ml over the show, so the level-counting test had only covered a ladle
stood upright.

- **A vessel with part of its rim under a liquid was a siphon** (`TablePhysics._dips`): the side of its rim under the
  brew filled it, the slosh stood it over the other side, which poured at 400 to 1,163 ml a second into the pot's
  wall, counted spilled. While any of its rim is under, the two are one surface (`dipped`): it does not slosh or pour,
  and the flow goes both ways until it stands as high inside as out.
- **The level moved in stairs** (`Vessel._table`): a level is a quantile of cell middles, which lie in layers. Each
  point now stands for its whole cell, spread across its width along `up`.
- **A hand dropped what it was about to stir with** (`_held_aloft`, `_stands_in`): "what stands in a vessel is let go"
  had no limit. Taken up again within a pause, it is held.
- **A body could go 58 cm a second, whatever its hand did** (`RigidParts._go`): a limit for going carefully past what is
  near, applied in clear air too. Clear of everything by more than the way, nothing limits it.
- **A sheet's outline met nothing** (`Particles.fill_shape`, `_sheet_outline`): what meets the world is a point at the
  sheet's thickness. Now each of `SHEET_REACHES` ways round, a point at the outline's edge.
- **What a hand lays down rests** (`TableWork.LAID_REST`, `_laid_by`): a move ending at the table's top, or set `down`,
  holds its channel 1.2 s longer, on the live schedule and the rehearsal alike, so a feather does not bounce.

`episode_bake_probe --audit` bakes the show whole and says each thing that must always hold and did not: liquid kept,
a body in a solid or through the table, a jump, off its hand, gone on by itself, hanging in the air, a loose thing past
its vessel's wall. Run it before asking the author to watch. Gates: physics_check `_brew_kept`, `_sheet_tip_in_pot`,
`_stands_held_for_a_moment`; table_work_live_check `_laid_rests`. Feedback reports each liquid's volume and surface.

### 13. A sheet that bends, a liquid never still

New physics, for any sheet and any floater:

- **A sheet bends** (`Particles.make_soft`, `_soft_pass`; a sheet of `TablePhysics.BENDS`: plant, paper, fabric):
  position based dynamics' stretch and bending (Muller et al., 2007): links to each point's nearest, links across each
  point, a weak pull back to its own shape. A hand holds it rigid, its bend easing out (`_ease_held`). What it does is
  kept in every frame (`bo`, `TablePhysics.bend_of`) and drawn by `SheetBend`.
- **A thin tool cannot go between its points** (`Particles.THIN_TOOL`, a solid's `thin`; `SOFT_MOST` points): they meet
  it at their whole radius.
- **It is pushed no faster than the tool goes, and it slides** (`SOFT_PUSH`; friction off against a moving solid;
  `SOFT_CALM` shares speed along the links).
- **A vessel takes no part of a sheet with it.**
- **A liquid is never still** (`Particles.current`, `swell`; `TablePhysics._flow_of`, `_agitation`): a stream
  function's two slow waves and two of swell, as hard as it boils and swirls, a pure function of the moment; a body
  afloat never sleeps. In a simmering pot, over 30 s: 12 cm of drift, 70 degrees of turn, 1.4 mm of bob.
- **The whiplash was the stir's:** a tool's speed over its nearness to the axis turned the whole surface as one. Now a
  vortex (`_liquids_step`, `SWIRL_CORE`, `core`): rigid to where the tool goes, falling away past it.

**The bake.** What sleeps on what moves is found once (`_on_moving`), a sphere asks only the solids near it
(`_near_of`), a dip is asked again only if something could have changed it (`was`), what displaces is asked of stirred
bodies alone. A stir bakes in 25-29 s for 30 s of show, results identical to the digit. A floater keeps every later
frame stepped.

Gates: physics_check `_sheet_bends_round`, `_floater_lives`, `_sheet_stays_whole`, `_sheet_tip_in_pot`. `--audit` also
says a thin tool through a sheet as drawn, a sheet pulled out of shape, a loose thing out through a wall;
`--soft-trace` gives each sheet's points against each vessel. Run the audit on the show's own acts: bench gates passed
while the show failed.

### 14. The vial that stayed empty

Baked whole, the vial took 26.9 ml; played live it stayed empty, every parcel stopping at the height of the vial's neck.

**What stopped it was a cork nobody could see.** `vial 1 cork` has `start: {shown: 0}`, and only the act after the pour
brings it. `TablePhysics._shown` read `not twin._chan.has(ch) or value > 0.5`: no act on the channel meant "there".
Live, that act's words are not heard until after the pour, the channel does not exist, and the cork stood in the neck
as a solid while the picture drew nothing. Now no act on it is what it started as.

**The class: a plan that has not heard of an act must read as if the act will not touch the thing, never as if it
already did.** Sections 10 and 11 fixed this for a hand letting go and for a landing. The probe for the class:
`episode_bake_probe --heard` bakes on this thread as a live plan comes to know the show, and `--series`/`--against`
say where any body or liquid parts from the whole plan's bake (8 minutes for the show; with the old `_shown` it
reports the vial 26.9 ml short from 562.8 s to the end). On the whole show 11 stretches differ, read as one of two
things:

- **The hand holds what it would have let go, until it hears the next act.** `_hold_changed` re-bakes only a plan that
  holds what the last let go of, never the other way, so a live show and an export differ here on purpose: live the
  ladle stays upright, exported it leans in the pot for a moment.
- **What floats or is stirred goes its own way after that.** Small differences grow in a stirred pot.

Reports carry the table's own clock (`now`): after a scrub it is neither the report's `time` nor the rail's.

Gate: physics_check `_unbrought_not_there` (placed, unheard, heard after the bake; control: the cork brought first
stops the stream). Before saying a show is right, run both: `--audit` on the whole plan, and `--heard --audit
--against`.

### Seen on 841899 itself (`episode_bake_probe`, the take's own word times, a copy)

- **The pestle:** it is set down into the mortar at once and leans there through the 15 s, then goes straight into the
  grind - no hover, no rise.
- **The pour:** the agent's own first act, `{"law": "pour", "into": "brew"}`, turns the mortar to 119 degrees over the
  pot and `act` says "64 of the 64 pieces that left it went in"; the mortar is held over the pot for the 2.5 s the
  pestle takes to go back, then carried home.
- **The hand-written tip,** played again, is told "62 in the inside of the copper cauldron on its brazier's brazier pan,
  1 in the copper cauldron on its brazier's brew".
- **The ladle:** the same rule.

Gates: physics_check `_pours_loose`, `_world_from_table`, and the hold tests (`_held_between`, `_held_till_placed`,
`_leans_in`, `_held_unless_resting`, `_rests_let_go`, `_sheet_lies`, `_level_counts`, `_dips_full`); table_work_check
`_held_up`, `_aloft`. Probes: `act_calls_probe`, `episode_bake_probe --profile-bake` (a bake's cost by section, and
why each frame was stepped) and `--profile` (a live frame's).

## What a framework for any desk needs

LEGO, baking, a jigsaw and alchemy differ in their things, never in what holds them together. Five rules:

1. **The world is the table's.** What exists, what is a body, what can pour or break is decided by what was built,
   never by what an agent writes later (done for bodies; the next new kind of thing - a dough, a brick - must follow
   it).
2. **Nothing a frame does looks ahead.** Every decision at a moment reads only what came before it and at most a
   hand's pause after (done for holds); so any draft, live word or scrub is baked again from its first change, and
   live agrees with exported.
3. **The agent says what, the hand finds where.** A verb per kind of handling, its geometry found from the things
   themselves: `pour`, `dip` (done), `stir`, `grind`, `put` in or on, `snap` (a brick onto studs: a seat that welds,
   which exists), `knead`, `cut` (a blade exists). A verb is a small planner over the same primitives - reach, rise
   clear, carry, place by letting go (the trial), release - never a new physics.
4. **What was meant is checked against what happened.** Each verb carries its intent (into what, onto what) and the
   bake is judged by it (done for `pour`); a miss is an error the agent sees, by the part's name.
5. **A frame costs what changes.** Asleep and dormant things cost nothing to bake or to draw (done for bodies,
   liquids, posing and grains); a new primitive is written so from the start.

The primitives under them are few and mostly here: rigid bodies with contacts, seats and welds (bricks, lids, corks);
swings by weight (a balance, a hinge); particles with shape matching (grains, crumbs, dough); liquids in vessels
(batter, brew); states over time (heat, color, fill, rise); sound from contact. What is missing is the verbs.

## Open

- **Verbs over geometry.** The same for stirring and grinding (`stir`/`grind` in a vessel, the tool's point placed by
  the vessel's own inside), for placing (`put` a thing in or on another, its resting pose found by letting it go), and
  for showing (`hold up`). The laws stay as the escape hatch. Most of what the puppeteer still gets wrong is geometry
  it should not write.
- **Invariants, checked after every bake, as errors.** Nothing interpenetrates; nothing hangs unsupported while still;
  nothing moves faster than a hand; what was poured for a target lands in it (done: `_pour_said`); a thing set down is
  where it was set. `episode_bake_probe --audit` says them by hand for one episode; telling the puppeteer, in `act`, is
  what is left.
- **One model of where a thing is.** The work plans the hand; the physics should be the only answer to where a thing
  is, and `check`'s PASSES THROUGH (the plan's poses) folded into the physics' HELD BACK, so one event is said once.
- **A plan's guesses.** A live plan places the moves after an act that runs "under" the words on a guessed end, and
  moves them every sentence; where the guess proves early the bake goes back to it (once 30 s). Guessing ends later,
  or measuring the moves on the bake's own thread, is the next step.
- **The bake's own cost.** A stepped frame is still ~10 ms of GDScript (a stirred liquid's level 1.4 ms, its waves
  1.25 ms, every vessel pair's dip test 0.9 ms). Godot 4.7 does not let a physics space be stepped by hand, so Jolt is
  out; the remaining wins are islands (step only what is near something moving) and a coarser step for what is merely
  settling.
- **The picture.** Paused, the same table draws in 6-7 ms at the window's own size; a stage rendered at a lower scale
  while the governor is throttling would buy the rest.
