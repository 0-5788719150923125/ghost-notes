# What is built on the table: many small parts, slowly

The user, 2026-11-02, of the brick show (`rift/cards/brick-by-brick.md`, renamed from The Spare Bin, its challenge cards gone):

> I just want to free-form build something from the LEGOs, in a meandering style, while talking about whatever people talk about when
> they are mindlessly building toy models ... a big box of bricks that we would sometimes dig through (bearing in mind we might want
> sound there), or piles of bricks on the table ... we might pull a brick, try to fit it, put it back, try a different one. We might
> build some structure, then destroy it and start over ... building a model from LEGO is probably not fast ... The video might be long.
> There might be stretches where we do not talk at all.

This replaces the plan in `next/table_work.md` section 8, which was written for a build that follows its steps. What stayed: an instanced
assembly on a lattice, one law that makes its acts, exact checks. What changed: **the puppeteer writes the meander itself** in the one
law, with no separate builder or booklet, and **a piece has a life before and after it is used** - it lies in a heap, it is dug for,
it comes off again.

**Status, 2026-11-03, later: the model step is built ("The model", below) and so is what a hand does with what it holds ("In hand"). Gated, and run on 63178's own table from a design written by hand. No real agent has designed one yet, and neither has been watched in the app.**

**Status, 2026-11-03: built twice. The first version, moving each piece along a planned path, was watched and rejected; what stands now is real bodies.** Run on the first real
episode's own table and acts (563019); nobody has yet watched this version in the app or heard it. Open at the end.

## Trying it

1. In the notes list, "Existing note..." and pick `rift/cards/brick-by-brick.md`.
2. On the Pipeline card, Generate. The producer should plan `assembly: true`, a `quiet` near 0.5 and six to ten beats, the set dresser
   should build a hollow tub and write an `assembly` block, and the puppeteer's `act`s should come back with level maps.
3. Play. The record starts when the table first stands on the stage, and the transport says "catching up" if the show reaches what it has not written yet.

To look without any agent: `GHOST_PROBE_GPU=1 tests/run_boot_probe.sh tests/table/assembly_look_probe.gd 500 [--episode <dir> --acts N] [--clip A,B]`.

## The model

The user, 2026-11-03, of a real hour of it, *An Island Before Breakfast* (63178):

> You will notice that we built absolutely nothing discernable ... The things we're building are not actual shapes. Consider this: if I asked you to produce a complex scene with voxels, you could probably
> build an extremely elaborate and impressive one outright. Here, we barely build the bridge we said we'd build... and we go nowhere near to an island. So, our process is flawed. We probably need a proper modeling
> step, such that we aren't just randomly placing bricks, but building to some kind of grand, planned vision. Maybe we need blueprints, like the cards mode uses. And of course, the ability to make mistakes and
> correct errors is still important. I just want to have a proper model built by the end of every video.

Its frames say so: an hour for a flat blue floor, three black terraces and a small house. `acts.json` says why. Nothing was ever designed. The puppeteer made up the next stretch act by act from level maps, was told to
change its mind, and was told "what you write is how someone builds, not what they end up with". **So there is now a step before the table, `model`, by a new agent, the modeler (`rules/table/modeler.yaml`).** The plan's new `build` says what it is.

**What it writes is shapes, not pieces** (`AssemblyModel.SHAPES`): box, round, ball, land from a formula, `where` for anything at all, line, roof, and an exact `part`; each can `carve`, `paint`, `repeat`, `mirror`, in named sections in the order they go on, in a grid a stud across and a plate up. Formulas are `Formula`'s, never code, and it gained `noise2`.

**Code lays the real parts** (`AssemblyModel._lay`), which is the part no agent could be asked to do:

- **Largest first, wherever it fits.** Cell by cell, a curved edge came apart: 813 of the first 1,817 parts were single studs.
- **Courses.** A curved shape is worked out a brick's height at a time unless told otherwise (`step`), and a brick lies on a course, so colors and shapes change where bricks do. A color change a level at a time costs a plate per stud.
- **Bricks in thin walls, wide plates over anything wider,** because bricks side by side are not joined to anything, and a plate across a hollow is held by all its walls. Over nothing it is always plates.
- **Hollow where nobody can see** (`SHELL`). A solid hill is thousands of parts.
- **It holds, or it says so.** `_ordered` finds an order a hand could build it in: on the plate or joined by a stud to what is there, from below or hung from above. What hangs because of how it was laid is mended: long plates across it (`_bridged`) and a thicker hidden wall (`_pillars`). What hangs because it was written in the air is said in words, with where: it found a house of mine ten levels over the ground, and two trunks that started above it.

`ModelTools` is a loop like the set dresser's: `shape`, `look` (`ModelStudio`: its real parts from four sides, before any table exists), `remove`, `submit`, which refuses too many parts always (`PARTS_MOST`, 1100) and what floats until told twice. Everyone after it is told what it is (`TableEpisode.model_words`): the set dresser, the puppeteer, the reader. It goes into `table.json`'s `assembly` as it lands, so every table anywhere stands from that one file, and it brings its plate and colors. A stock's filling gives way to what is wanted of it (`FILLERS_LEAST`).

**The puppeteer stages it and no longer designs it.** Its steps with a model are `build` (the next N parts, in order), `wrong` (the next parts on wrong in plain view: a stud off, turned, or the wrong color), `undo` (what went on last comes off), and `dig`, `try`, `look`, `pause`, `turn`, `take`, `wreck` as before, where `try` and `look` need no part or place: they mean what comes next. `put`, `wall` and `fill` are not offered.

**Everything comes off owed.** A part of the model is standing or it is owed, whatever took it off, and the next `build` lays what is owed first. A wrong piece in the way of its proper place comes off when that place is wanted. So mistakes and starting over cost only time.

**And it stands by the end, always.** `Assembly.with_finish` starts the last act that builds with `finish`, which takes off what is wrong and builds what is owed, so an act's worth of bad planning costs a long stretch and never the model. It costs nothing where all of it stands, and it says how much is owed (a walk of the plan over a stand-in table), so the reader's words are timed for it: a video must not end on its last word with the model half up. `act` says how far along it is.

**A finished episode goes on as it was made** (`TableEpisode.wants_model`): acts blocked with no model want none. Blocking them again begins from one. The brief was rewritten: it had said "with no plan" and "whether or not it is finished".

A carry now goes over what stands under its way stud by stud (`AssemblyBake._model_top_at`), up to `LIFT_MOST`: with a 28 cm tower on the plate, "the highest thing anywhere" would have had every piece rise over it.

**All of it in the picture.** A model's top cut off by the frame is no model. The modeler is told how tall this episode's lens sees (`TablePrompts.modeler`, `CardTable.headroom_at`), `set` says by how much it would be cut where its plate stands, part by part (`TableAssembly.model_cut_by`), and `submit` asks once. A real table measured it: 8.3 cm of a 28 cm tower on 63178's table, which was set for a smaller plate.

A design I wrote by hand, as an agent would, as a test: a lighthouse on an island with a keeper's house, a stone bridge, trees and a boat, 1,070 parts on 40 x 40 studs, 28 cm tall, in 7 s of laying. It reads instantly from any side. It is at the top of its range: most of its cost is the rough shoreline. The aim is 350 to 800. Run for real on 63178's table with acts converted from its own, wrong parts and undoing in them, 860 parts built by them and the rest by `finish`:

| measured | |
|---|---|
| its record | 1,239 bodies, 1,258 steps: 3,230 s of record in 1,312 s (2.5x real time), with other jobs loading the machine to 10-18 |
| the first minutes | about 0.6x, while digs thaw much of the tub; then about 3.5x once it is building |
| it stands at the end | 1,067 of 1,070: the 3 left are parts it was told hold on to nothing |

Gates: `assembly_model_check` (the laying, the language, the steps, the finish), `model_step_check` (the step, the tools, what lands), `rules_check`. Probe: `assembly_model_probe`; `assembly_look_probe --model <design> --work <acts>` stands one on a real episode's table.

## In hand

The user, 2026-11-03:

> I'm unhappy with the way bricks are pulled, then how they just float there, frozen. A real hand is not perfectly still: the brick would maybe float a little, the rotation would change, maybe the person would flip the
> brick in their fingers, fidgeting with it. But to have the brick just sit there, center-screen, at an angle, unmoving - it looks very strange.

63178 held a brick in the air 223 times for 230 s in all, 93 of those over a second, most at the 2.4 cm hover and not at the lens. It was drifting by 0.8 mm and half a degree, which `Hands` itself says is seen as perfectly still, and only in the stops; and the same fixed spot in the middle of the frame took every look, turned once on one slow axis, which read as a tumble in zero gravity.

**`Fingers` is laid over the record, not in it,** from the grip to where it leaves the hand (`Assembly.held_at`). A stop lasts as long as the reading wants, so the record cannot hold motion for it. It is a pure function of time in hand: a scrub lands the same, it touches nothing, and it has no sound. Three things, as much of each as the **room** allows, which the record says along the way (`AssemblyBake._room`: free in the air, less carried over things, a little over a place, on the studs less, pressed home none):

- the arm sways (`Hands.drift`, at last at `HOLD_SWAY`);
- the hand shifts in short moves with rests between, never waves, which read as under water;
- the fingers turn it over in beats (`Fingers.BEATS`: tilt, roll, a flip in two goes with a regrip, end over end, spin), only where it is clear of everything; their clock stops as room runs out, so it is righted along one path with no jump.

Over things it goes up and never down, and a tilt is lifted by what its low end would dip, so it touches nothing. **A hand kept waiting over a place draws back** (`Fingers.drawn_back`): over 2.2 s it rises, has room for its fingers, and comes down before it goes on.

**The pull** (`AssemblyBake._pull`) was a straight lift at one orientation, a stop, and a carry. Now the grip tips one end up, it comes on up turning, and the end of the draw goes on under the carry, the two added (Flash and Henis, 1991), so it never comes to rest between them. Real neighbors really ride up on it. **The look** is held somewhere of its own, off the middle of the frame, low, toward where it came from (`_view_xf`).

Gates: `fingers_check` (never still, and the drift alone called still by the same measure; turned over; no jump past half a turn; both ends the record's; never lower over things), `assembly_check` `_time`, `assembly_bake_check` `_in_hand`.

## Real bodies

The user, 2026-11-03, of the first version:

> The digging behavior is bizarre. It's basically just bricks gently floating around in the air, shifting positions ... so slow it looks like there's low gravity. It's not
> actually digging, there's no proper physics, and the blocks clip through each other ... The sounds being made are clearly fake as well ... the sound doesn't align with the
> actual events. You would expect bricks to make sounds when they touch each other - and you would expect gentle motions to make no sound (or quiet sound), while collisions with
> more force to make more sound.

All of that was one mistake. This note used to argue that bricks should never be physics, from what our own solver costs (`TablePhysics`, `MAX_WORKS` 192). That was true of it
and false of physics. **Godot ships Jolt.** It cannot be stepped by hand in the app, but a second Godot under `--headless --fixed-fps 240` steps it as fast as the machine goes:

| measured | |
|---|---|
| a spike, 600 bricks poured and settled | 2 s |
| two runs of the same record | identical, every key of every piece (`_same_twice`) |
| 563019 whole: 230 steps, 471 pieces, a 40 minute video | 840 s of record in 229 s, with another job using most of the machine |
| its size on disk | 35 MB |
| a frame's work on the app's thread | 2.7 ms on frames spread through the show; 8.9 ms in a dig on a busy machine, before its lookup was narrowed to what moves then, and not measured in a dig since; 6.6 ms at most as a stretch lands |

So the bricks are bodies (`AssemblyWorld`), with their shapes as tall as their studs, and everything clips against everything: `assembly_bake_check` measures gravity from nothing but
where things were (9.6 m/s2, and a control that low gravity reads as low), and holds that nothing lies in anything, nothing crosses a wall or the table, and nothing is flung.

**It is still a log with time over it,** which is what made the first version's hour possible and is the one thing it got right: what comes to rest where does not depend on when in the reading it
happens, provided nothing happens while time stops. So:

- `AssemblyBake`, in a process of its own, runs every step at a hand's pace on the record's own clock and writes down what happens, in stretches, each named by everything it depends on
  and holding where everything then is. A new act costs what comes after it; a note opened again costs nothing; the show plays what has landed and waits only for what has not.
- It leaves **stops** in the record, and lets the world come to rest before each (`_settle`), so nothing can hang in the air through one.
- `Assembly.lay` places all of it in the show, and can again every sentence of a live reading. `AssemblyTrack` looks a pose up, so a scrub lands exactly where that moment was, and an hour costs the frame a minute does.
- `Assembly` itself no longer moves anything. It is the plan: what fits, what could not be done, what each act comes to in words. A puppeteer's `act` and `model`, and the set dresser's table, see where things rest
  by that walk alone and never ask for a record, so they answer in a moment.

**The hand is a body too,** and unseen, as every hand at this table is: a cupped palm or a set of fingers moved through the heap. A dig is what a hand does in a tub (`AssemblyBake.GESTURES`): fingers dragged through it,
a handful flipped over and falling back, the top pushed across. A piece is drawn out through what lies on it, which rides up and rolls off; what is let go of falls, and lands how it lands. A part asked for
later is wherever that turned out to be.

**A heap at rest costs nothing.** A piece that has stopped goes static, and is made a body again only when something that moves comes near it, so a dig costs what it disturbs however full the tub is, and because what moves thaws what lies
on it, nothing is left hanging. Jolt alone wakes everything touching what is awake, and in a tub that is the whole tub.

**Finding what would not come to rest was the real work.** Every stop would have been a lie, and the silences would have crackled. The gate caught it: 350 "hits" a second all the way through a carry across the empty table, on pieces rocking at 3 rad/s. See `AssemblyWorld`'s header. Also
measured: Godot's contact reports were more than half of a record's time, so what a piece hit is asked once, when it has hit something (`_against`); thin plates went through thin walls until continuous collision was on; a piece in hand
filed twice in the thaw grid was set loose while held, and went at 7 m/s.

## Walls, and what falls

Feedback 0015 on 462684, the first episode a real modeler designed: "There is an orange brick currently clipping through the side of the bucket." And the user on the spill: "people do make messes - just so long as those fallen bricks still remain usable, if we need them."

**The clip was the first dig's, not the pour's.** An 8x8 plate, piece 361, stood on edge in the tub's short wall from the first dig to the end of the show, 2.5 mm into its inner face and 1.8 mm out of its outer one. Three things meet there. A hand is kinematic, so what it shoves against a wall is pushed by something that cannot give, and no solver satisfies both. A wall of a thing is two faces of a surface, each pushing what is nearest it out through itself, so a plate as thin as the wall sits between them. And the wall was thin: 5 mm on the tub's long axis and 3.3 mm on its short one, warped by 0.63. 41 true boxes stood in a solid in the record's first 90 steps. `assembly_bake_check` never saw it, because it asks where a piece's origin goes, and that plate's origin was well inside.

**So a vessel's inside is a rule of the world** (`AssemblyWorld.add_vessel`, `_wall_push`), laid over the solver at every read. Its inside is measured from the thing's own surface by rays, 96 ways round at 16 heights (a warped lathe to within 0.1 mm of its profile), and a corner of a piece past that, below the rim, moves the piece back along that way, up to three corners a read since moved off one another may be deepest on a wall that curves. A piece is in a vessel from when its middle is until its middle leaves over the rim; gone through the wall it is still in, and comes back. Over the rim is not through it: what lies across a rim has corners far below it, and the test is the height where the piece crosses the wall's place. A hand drawing one out goes by the same rule. A test shove of an 8x8 plate on edge: 91 mm through the tub without it, 0.8 mm with it.

The top 5 mm of a rolled rim is above the highest height measured: a plate lying on the lip can still stand a couple of millimeters into it. It is a piece lying on a rim, not one through a wall.

**A fallen brick is still a brick.** It keeps its stock wherever it lands and `_find` goes on finding it, last of its kind since it takes the highest. Nothing about using them needed changing. 462684 baked whole on a copy with all of this, 930 pieces and 1,139 steps: 808 of 808 parts stand at the end, no part went unfound, and of its 945 presses 674 came from a stock, 246 from what lay fallen on the table, 20 from another stock's place and 5 off the plate. 2,770 s of record in 998 s, the machine busy. Piece 398, an 8x8 plate, went off the table a quarter of an hour in and is in the model at the end.

| through the tub's outer face, at rest | the record as it was, first 93 steps | whole show, 1,139 steps |
|---|---|---|
| over 0.5 mm | 50 bricks | 11 |
| over 1 mm | 36 | 2 |
| over 2 mm | 25 | 0 |
| over 3 mm | 8 | 0 |

**Two things did.** The physics' table was a slab 16 m wide, so a brick past the drawn edge rested on air, one 14 cm past it in 462684. The top is now its real outline (`add_prism`, from `Tables.edge_points`), and past it a brick drops 72 cm to a floor, from where a hand fetches it when nothing nearer of its kind is left: out from under the table first if it rolled there, then up beside it, never through the top (`_off_the_floor`). And a stray on the plate was shoved about by every part laid over it, 9 of them by step 87 and the model's first section covers the whole plate, so the hand now moves what lies where a part is about to go (`_clear_spot`), to `aside`, where it can still be had. Only what is in the way: the rest of the mess stays.

Jolt says once a bake that its job system ran out of jobs and is waiting: it did before any of this, and it is the size of the heap.

A first dig still spills about 30% of an overfull tub. The tub in 462684 holds 863 pieces in about 18 x 28 cm. The user has said that is fine.

## Slow, by stopping

A step has a **natural** time (`Assembly.OPS`) and its moves take what they take on the record. `lay` fits a stretch of steps to the time its words leave:

| time given | what happens |
|---|---|
| less than its moves take | no stops at all, and it overruns; the next act waits behind it |
| between that and natural | its stops shortened in proportion |
| more than natural | **moves keep a hand's pace, and the rest goes into stops**, four times as much into a `pause` as elsewhere |

The record runs at one speed or stands still: `assembly_check` `_time` holds that. A fall always takes the time a fall takes. So a reader who talks long gets a builder who stops more, never one in slow motion. What is in hand through a stop goes on being handled ("In hand").

## What a table says, what an act says

**The set dresser** writes `assembly` beside `things`: colors by name, a `base` (its plate), and `stock` - each a pile `at` a place, or
`thing` naming a hollow thing it built. A container's inside is found by rays straight down (`TableAssembly._heap_of`), so any open tub,
crate, tray or dish holds pieces without being told how it is shaped, and a solid thing is refused in words. A deep one is filled
over a false floor: only its top layers are real, and nobody can tell.

**The puppeteer** writes `{"law": "assemble", "ops": [...]}`, its `length` left out:

| step | what the hands do |
|---|---|
| `dig` | a hand really in a heap, a few gestures with stops between, nearer what it is looking `for` as it goes on |
| `put` | find a piece, bring it over, line it up, press it on; `hover`, `first` and `look` are its indecision |
| `try` | bring one over and take it away again (`press`: on and off) |
| `look` | hold one up near the lens and turn it over |
| `pause` | nothing moves |
| `take` | one piece off, and whatever only it held comes away with it |
| `wreck` | a stretch or all of it pulled apart top down, chunk by chunk, let fall into a stock, where it comes apart |
| `turn` | the plate turned, to see another side |
| `wall`, `fill` | a run of the same part, seams staggered, the hands in a rhythm (about 5 s a piece) |

**The agent says what, the hand finds where**, as `pour` and `dip` do:

- *Which piece:* the one of that part most to hand, the highest in that stock, found when it happens. A piece asked for is always there: a dry pass of the same walk learns what the
  steps need, and it is added to the stock before anything lands, soonest-used on top.
- *What has to move:* whatever is in the way, by being in the way. Under much, the hand clears it first.
- *How high:* `at` is `[x, z]`, and it comes down on what is there; `[x, z, level]` only to hang under something.
- *The way:* over what stands under it, by `Hands`, up first and down last.

`act` answers with what each act came to, what it COULD NOT do, and the whole model level by level as letters. `model` is the model from
four sides, close to. The rules name none of this: `rules_check` now bans "brick" and "lego" from `rules/`, and the words come from
`Assembly.describe()`, inserted only `when: assembly`.

## Silence

`<!-- quiet: 40 -->`, written by the reader where it stops talking (`CardReading.QUIET_MARK`). It is a rest as a table's move is
(`action-hold`), so it stays with the Hesitate box off, and it runs to `QUIET_MOST`, four minutes. Four things had to change, each found
by a failure:

- **A word budget.** `TablePrompts.reader` asked for words to cover all the work. The plan's `quiet` (the producer's, from the brief)
  now scales it down, and the reader is told how many seconds pass with no words.
- **A cue in a silence.** `<!-- act: x --> <!-- quiet: 30 -->` cued at the next word would wait out the whole silence. A cue with a quiet
  beside it is timed from the word before, plus how far into the silence it stands (`CardReading.quiet_around`, `TableWork.schedule`).
- **A beat that opens in silence.** A mark's move is placed just before the next word (`ReadingFollower.place`), so the beat began as
  its opening silence ended. The action now carries `lead`, and is placed before it.
- **A beat that ends in silence.** A beat's span ended at its last word, so the work stopped for the silence. The action carries `tail`.

If a reader writes too little anyway, `TableProducer.fit_silence` adds the difference as a silence before the last sentence, so the work
never runs on past the talk.

**AN EPISODE OPENS TALKING** (the user, 2026-11-03: "a solid 45 seconds of silence at the beginning ... feels wrong. We definitely need an intro, even if we're going to go silent at parts throughout"). The brief and the reader's rule had both invited
it, in so many words. Now the brief asks for an easy hello, the rule says so (`quiet_opening`, about a minute of talk), and whatever is written `CardReading.opens_talking` holds it as the script is read, so an episode already made is mended too: a silence before the first 60 words comes
out, and up to 30 s of it falls at the next paragraph's end. A breath stays.

## Heard

**No hit, no sound** (`AssemblyWorld._hits`, `WorkSounds._hit`). A sound is written when a piece's speed changes suddenly past what gravity gives it, how much it changed is how hard it hit, and that alone decides how it sounds: gentle is quiet and dull, hard is loud and bright, its higher modes coming in only past their own speed. A bigger piece is lower. What it hit rings too, as what it is made of - a tin wall under a brick, a table under one - and a hand gives only a soft touch. Nothing is drawn at a rate any more, so they cannot not line up: `assembly_bake_check` `_heard` holds that every hit is at a piece really moving there, then. A press home, a piece pulled off and a plate dragged are the few that are not hits, and are written at the moment they happen. **Nobody has listened to this yet**: what is measured is when and how hard, and the character is still a guess.

## Found building the first version

Kept here because the code says what it does now, and not what it did:

- `(problems[_act] as PackedStringArray).append(...)` appends to a copy, so no step ever reported a problem (CLAUDE.md warns of exactly
  this). `problems` holds plain Arrays.
- A `wreck` grown by joined pieces took a whole running-bond wall in one chunk, since each joint holds up the next. A chunk grows only
  as far as it brings away no more than a hand takes.
- A plate turned sweeps its diagonal, and its corner went through a tub written beside it. Its room on the table is now the whole circle
  it sweeps (40 cm square for a 32-stud plate, so a big tub sits partly out of the frame; a smaller plate lets it closer, and the set dresser is now told to do that so what is dug in is seen), and a turn
  that would still hit something is refused in words (`Assembly._swept_into`).

## Open

- **By ear, and by eye in the app.** Whether a flip reads as a hand with no hand to see, whether the clatter sounds like plastic. The render of 563019 to judge it by was stopped for lack of memory: `dist/brick3/motion_final_silent.mp4` is its first 18 s with no sound, `with_sound_earlier.mp4` 12 s with sound, from just before continuous collision went on.
- **The full suite has not run on this version.** `scripts/check.sh --for src/table`, 81 gates, has passed gate by gate with another session's work in the tree, not all in one run; the GPU gates and the folders below `table` have not reported since these changes.
- **A frame in a dig** has not been measured since its lookup was narrowed.
- **Seeing the hand?** The show has never drawn one, and the brief says no figures. It is the first thing to try if digging still reads as telekinesis.
- **The first real modeler.** 462684, "A stilt house on a teal bay": 808 parts, 40 x 40, nothing floating, a two-hour episode. Its model, staged, has not been judged whole by the user yet.
- **A first play catches up.** The opening digs of a record bake slower than real time on a busy machine (see The model), so a show played the moment it is generated says "catching up" early on. It is cached after that.
- **Pieces out of the tub.** See Walls, and what falls. A large model's stock still overflows its tub as it is poured, and the set dresser is not told how much a tub holds.
- **A chunk comes apart as it is let go,** not as it lands. A joined pair stays joined in real life.
- **The tub on the table.** Its top is often half out of the picture, which is where the digging is. The set dresser is told, not held to it.
- **A thing that moves meets no brick.** A thing an act moves is `TablePhysics`'s, the bricks are in another process. A `drink` goes over all that will ever be built (`TableWork.lift_over`, `TableAssembly.built_reach`); a `carry` over the plate would still go through a tower, and the puppeteer has had no reason to write one.
- **Limits a real episode may hit.** 40 acts (`Motions.MAX_ACTS`) at a few minutes each is about two hours; 120 steps an act; 1,800 pieces.
- **Clear parts.** The old brief's see-through pieces: a second instanced material, not built. No figures, by the brief.
- **A phone.** It cannot start a second process. A note made on the desktop plays from a record moved with it, if that is ever wanted; a phone does not make one.
- **The jigsaw** (`corner-by-corner.md`) was to share this. A flat lattice of different pieces, `Assembly.KINDS` is bricks' own.
