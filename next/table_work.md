# Work at the table: things that move, written by the agents

Goal: grow the Cards pipeline into other kinds of desk activity (alchemy first: a mortar and pestle,
ingredients, grinding, baby dragons heard in the background; then baking: pull a recipe card, follow the steps
on the table; then jigsaw puzzles and building with unbranded bricks). It has to be built generally: places
where motion would be expected were never animated because agents could not (a clock the speaker says shows
3:00am showed 3:00 precisely, and its hands never moved).

**Decided:** no baking mode and no alchemy mode. A system flexible enough that agents do this for
themselves, just in time: generic primitives, driven by the show's markdown brief and the agents' own
instructions. The first show's brief is `rift/cards/the-quiet-crucible.md` (an alchemist's bench at night;
ingredient cards; a raven on the shelf; the hatchlings by the hearth), cloned from
`rift/cards/true-tarot.md`.

This note is what was found, the design, and the plan in order. What is in things is real, and moves are a
hand's: next/table_physics.md (liquids keep their volume in a vessel's inside and pour over its rim when
tipped, `grains` and `loose` parts are particles and bodies baked over show time, a pestle breaks what it is
pressed into, and every move is minimum jerk, bowed, leaning and never quite still: `Hands`; `pour` is gone,
the tip is the pour).

**Status: the first build is in** - the clock runs, the parts work, the puppeteer blocks acts, the readers
talk the work through, the dragons are heard; nothing yet has run with real agents or been rendered on a real
table. What each step holds, and what is open, is in its Status below. Gates: `table_work_check`,
`table_work_live_check` (the work on a mounted table: steam, a pour's stream, cue bursts, the hatchlings'
puffs, a moving thing's shade) and `creatures_check` (`tests/table/`); `work_steps_check` and, on the GPU,
`puppeteer_tools_check` (`tests/table_show/`); `rules_check` (the rules name no kind of work). Probe:
`table_work_look_probe` (frames of a bench through its acts). Seen on that probe's bench (no painted cloth or
room): steam off the brew, the ink's stream mid-pour, the brew purple after it, the pestle grinding tilted in
the bowl, and a moving thing's shade carried with it (`TableWork._tick_shades`: gone while lifted or tipped,
under it where it is set down).

## Trying it

1. In the notes list, "Existing note..." and pick `rift/cards/the-quiet-crucible.md`: its `ghost: cards:`
   block makes it a Cards show.
2. On its Episode card, **New episode**, then **Generate**. The plan says each position's work; the **Table**
   row makes the set (the set dresser builds the bench's working parts) and then the work (the puppeteer;
   its tools' calls show on the row as the set dresser's do); each card with work gets a second reading, the
   words said while it is done.
3. **Play**: the clock's hands move; steam rises off the brew; after each card is read, it goes down and its
   work is done while the host talks; the hatchlings are heard, and a puff of smoke rises past the far edge
   when one huffs.
4. **Folder** opens the episode: `acts.json` is the work as blocked, `table.json` the set, and `jobs/acts/`
   the puppeteer's prompt, its tool calls (`tools.jsonl`) and what it saw.

## The verdict

**Possible, and most of the machine exists:**

- The table already moves things as a pure function of show time. Every card has its own timeline
  (`TableCardPose`), the shoebox slides in, turns and has its lid lifted off (`TableMedium._pose_box`), and
  any part the set dresser gives a `move` gets a pivot node of its own (`Props._holder`, nested as groups
  nest) that `TableMedium._tick_ride` turns every frame. What was missing is motion that is driven by the
  clock or by the reading, rather than a response to the ride and the wind, and a way for an agent to write
  it.
- Words that cue actions exist twice: the reading's own-line marks and the rests the voice takes for them
  (`CardReading`, `TableActions`); and the desk, where a mark inside speech fires at its word
  (`<!-- point: name -->`), what is written is said as it is written, and the pen's clock is elastic to the
  voice (`DeskScript`, `DeskMedium.elastic`). The table keeps a `ReadingFollower` with every word's time.
- The agent loop exists: the set dresser builds through ghost's own tools, looks at what it built, and fixes
  it before it submits. Published work on agents and 3D says the loop is what makes this work:
  Articulate-Anything (an actor that writes an object's joints as code and a critic that judges the result)
  took articulation from 8.7-11.6% to 75% success; SceneCraft writes Blender scripts and refines them from
  renders; Holodeck has the model write spatial relations and lets a constraint solver find the numbers. The
  lesson for motion: the agent says what the work is, and the table solves the geometry.

**What is hard:** an agent's sense of motion is weaker than its sense of layout; dough that is kneaded or
folded cannot be done by moving rigid parts; a pour needs a stream; nothing may pass through anything; and it
adds one more best-tier agent run with pictures to every episode.

## What was found

**The clock.** An episode's table had "a wind-up alarm clock", its hands two `box` parts placed at three
o'clock, and no way to say otherwise: `Rides.MOVES` (sway, tremble, swing, needle, rock, slosh) are all
answers to a jolt or a gust, and the only thing on any table that turns at a rate was the Lights' `spin`
caster (a ceiling fan's shadow, out of shot).

**The other tables.** Of 34 set dresser tables on disk, the things that would be moving in the world and
stood still: the clock; a smoldering mosquito coil; a frankincense burner whose smoke was a fog bank beyond
the table and a burst at the close, never a thread rising from the burner; cups "poured and cooling" with no
steam; two brass balances. The air can make smoke (`Effects`) but cannot rise from a thing.

**Godot's `Expression` is not safe for an agent's text:** a `--script` probe with no base object cannot call
`OS.get_name()` or `Engine.get_frames_drawn()`, but `print(...)` runs and
`instance_from_id(<the root's id>).get_class()` returns `Window`: any live object, and its methods.

## What a viewer sees

Nobody is in the chair: the tools work by themselves. A ghost at an alchemist's bench. A card comes off the
deck and is held up, and while the reader talks about it a jar lifts off the shelf at the frame's edge, tips
three seeds into the mortar and goes back. The pestle grinds in slow circles, its tip pressed to the bowl,
the seeds shrinking as a pale powder rises round them, a little dust lifting at each turn; the grinding is
heard, stone on stone. The mortar tips its powder into the cauldron, which blooms violet and steams harder.
The clock on the shelf has moved on twelve minutes since the opening. Behind the table, a hatchling dragon by
the hearth purrs, and a small puff of smoke rises past the table's far edge when it huffs.

The tools move as a held tool moves (the pestle pivots about its tip in the bowl, a knife rocks on its point)
but no hand is ever drawn: a visible hand is a feature of its own and easy to get uncanny (next/proof.md).
For alchemy it reads as magic; for baking, as a ghost who bakes.

## The design: three layers, all data

1. **Working parts:** the set dresser's: joints, named points and states on the things it builds.
2. **Motion laws:** a registry of rows: what a joint, a point or a state does over time.
3. **Acts:** the new role's: named pieces of work made of laws, cued by the reading.

and two that come with them: the work heard (contacts make their own sounds) and creatures heard (a
Soundscape layer). Everything stays a pure function of show time, so a scrub, a render and a tool's picture
see the same pose. Nothing an agent writes is ever run as code inside ghost.

### Why not code

Generating GDScript at runtime would be the most just-in-time, but it runs with ghost's full rights in the
app and in the render's second process, a loop with no end freezes the show, and nothing could hold it to
being a function of time. `Expression` reaches any object (above). So the expressiveness comes from two
places instead:

- **Formulas where numbers go.** Any number a law takes may be a formula of `t` (seconds into the act), `u`
  (its progress, 0 to 1), `T` (show time) and `n` (the cycle), with arithmetic and a short list of functions
  (sin, cos, ease, smoothstep, clamp, lerp, pingpong, fract, noise). Read by an evaluator of ghost's own,
  whitelisted as `hosts/math/figure.py`'s already is (`_OPS`, the names it knows, calls by name only),
  bounded in size, parsed once.
- **Programs that hand back data.** When an act needs a program (a hundred jigsaw pieces placed in the order
  a person would, a pour's arc worked out) the agent runs Python in the sandbox the lesson's solver already
  uses (`hosts/compute/run.py`: bubblewrap, no network, capped time and memory), and what comes back is
  tracks: keyframes, kept in the episode and played by the table like any other track. The program and its
  output are both kept. Without bwrap there is no `run`, so everything must also be possible without it.

The agent invents the motion for this episode; ghost only plays data.

## 1. Working parts

Fields on any part or group of a thing (`Props`), written by the set dresser beside its shapes:

- **`joint`** - `{kind, at, axis, range}`: a `hinge` (turns about `axis` through `at`: a clock's hand, a lid,
  a balance's beam, a vial's tilt), a `slide` (moves along `axis`: a cork, a drawer, a plunger) or `free`
  (any pose: a pestle, a knife, a spoon, anything picked up). Built where `move` is built: each jointed copy
  gets a node of its own from `Props._holder`, so a hand turns inside the clock that a jolt rocks. A joint
  and a `move` can share a part (the joint's node outside, the response inside).
- **`points`** - `{name: [x, y, z]}`: the places a law holds, aims or presses with (a pestle's `tip` and
  `grip`, a knife's `point` and `heel`, a vial's `lip`, a mortar's `floor`).
- **`state`** - what can change about it: `fill` (a liquid's top at a share of its vessel), `tint` (its color
  toward another), `grow` (scaled about its base or a point; `squash` keeps its volume, for a ball of dough
  rolled flat), `shown` (it fades in or out, or dissolves), `glow` (it gives light, and lights what is near
  it with a small light of its own).
- **`runs`** - a law it follows all the time, from the opening (layer 2): the clock's hands, a pendulum, a
  mobile, a candle burning down, an hourglass's sand, incense smoke.
- **`emits`** - an effect of the air from one of its points (`Effects` takes an `at`): smoke rising off the
  burner, steam off a cup or the cauldron, dust off the pestle at each turn.
- A material, **`liquid`**: clear or opaque, a meniscus, foam, and a boil driven by show time (a pinned
  uniform, never `TIME`).

The set dresser's `look` draws each joint's axis and range on the grid, and its points, so it can see that
the minute hand turns about the dial's middle and not its own.

**The clock, written** (illustrative; the rules carry no example, which would be copied onto every table):

```json
{"name": "minute hand", "shape": "box", "size": [0.35, 3.8, 0.1], "at": [0, 8.7, 2.2],
 "joint": {"kind": "hinge", "at": [0, 6.8, 2.2], "axis": [0, 0, 1]},
 "runs": {"law": "turn", "from": 0, "rate": 0.1}}
```

A tenth of a degree a second is one turn an hour; the hour hand at 1/120, from 90 for three o'clock; a second
hand at 6, `tick: 60`.

## 2. Motion laws

One registry (`Motions`, in `table/`), each law a row with a `label`, a `blurb` and its `FIELDS`, so
`docs.py --check` holds the rows to what the code reads, and the agents read the blurbs (`describe()`). Each
law is a closed form of time; laws on one channel add.

| law | what it does | what it is for |
|---|---|---|
| `turn` | a hinge at a rate, from an angle; `tick` steps it with a small settle | clock hands, a turning mobile, a music box's drum |
| `swing` | a hinge driven back and forth: amplitude, period, phase, shape | a pendulum clock, a metronome, a rocking cradle, a balance settling |
| `circle` | a point travels a circle or an ellipse on a plane | stirring, grinding, whisking |
| `path` | keyframes (a pose or a point at a time) eased between | a knife's chop, a vial's tilt and pour, a lid lifted |
| `aim` | a part posed by two of its points, each following its own law | the pestle: tip on a small circle in the bowl, grip on a wider one above; a spoon; a whisk; a knife rocking on its point |
| `press` | a point kept on another thing's surface | the pestle's tip on the mortar's floor, the rolling pin on the dough, the knife on the board |
| `roll` | turning by the distance traveled over its radius | a rolling pin, a coin, a marble |
| `carry` | lifted, carried in an arc, lowered, turned on the way | a jar from the shelf and back, a jigsaw piece, a pinch of salt, the cards' own deal |
| `jitter` | a little seeded unsteadiness on top of any other | a hand is never still |
| `to` | a state goes to a value over the act, eased | herbs ground down, powder rising, the brew changing color |
| `pour` | one vessel's fill goes down as another's goes up, a stream between them | a vial into the cauldron, the mortar's powder, an hourglass |

`press` and `aim` are the constraints the Holodeck lesson points at: the agent says the tip stays in the
bowl, and the table finds where the bowl is. `press` casts down the part's axis onto the target's triangles
at each sampled moment (`Geometry3D.ray_intersects_triangle`) and keeps the solution as a table of numbers,
so playing it is a lookup.

A stream is an effect: a rope of liquid, sand or powder falling from a point to a surface along the arc a
pour would take, flowing as it goes.

## 3. Acts

An episode's `acts.json`: each act `{name, about, length, tracks, cues, leaves}`: `about` is what it shows,
in a sentence, for the reader; `length` a number of seconds or `under` (below); `tracks` the laws, each on a
thing's joint, point or state; `cues` what happens at a moment of it (an effect at a point, a moment the air
can burst on); `leaves` what stays changed when it ends.

```json
{"name": "grind", "about": "the pestle grinds the moonseed in the mortar to a pale powder",
 "length": "under",
 "tracks": [
   {"thing": "pestle", "law": "aim", "press": "mortar",
    "tip": {"law": "circle", "around": "mortar.floor", "radius": 1.5, "period": 1.4},
    "grip": {"law": "circle", "around": "mortar.floor", "lift": 14, "radius": 3.5, "period": 1.4}},
   {"thing": "mortar", "part": "moonseed", "state": "grow", "law": "to", "value": 0.3},
   {"thing": "mortar", "part": "powder", "state": "fill", "law": "to", "value": 0.6}],
 "cues": [{"every": 1.4, "effect": "dust", "at": "pestle.tip"}]}
```

**The reading cues an act three ways:**

- **Between passages, the voice waiting:** `<!-- table: do pour -->`, a written verb of `TableActions` whose
  rest is the act's length, read from the episode rather than a constant. For the moments that are the point:
  the brew blooming, the last piece pressed home.
- **Under the words:** `<!-- table: begin grind -->` before a passage: the act runs under it, a cyclic law
  in whole turns, a path stretched to fit, ending with the passage or at `<!-- table: end grind -->`. Most
  work is this: readers talk while they shuffle, and a baker talks while stirring.
- **At a word:** `<!-- act: pour -->` inside speech, as the desk's `point` is, timed by the table's
  `ReadingFollower`: "and in goes the <!-- act: pour --> moonwater".

What is done is said as it is done: it is very hard to watch text being written while the voice speaks about
something else, and the same holds for work. The reader narrates an act as it happens, never ahead of it and
never long after.

**State persists.** The pose and the states an act leaves are where the next one starts; an act's start is
the schedule's, so a pose at any moment folds over every act begun before it. A live reading plans again as
word times arrive, and nothing begun moves back (the desk's `_hold_past`, carried over).

**An oracle.** The shoebox's opening, written as an act, must pose the box and its lid exactly as `_pose_box`
does, frame for frame; then `_pose_box` goes. That proves the player against a behavior already accepted, as
`table_positions_check` kept the old spread as its oracle.

## 4. The puppeteer

A new role, named for object theater, where a puppeteer moves everyday things with hands the audience is not
meant to see. It runs after the table is set (it needs the things) and before the readers (they need the
acts). It is told the plan's work, the table's working parts and the cards drawn, and it writes the acts
through tools, as the set dresser writes the table:

- `parts` - every working part on the table: things, joints and their ranges, points, states, sizes.
- `act` - write or replace an act; answered in numbers: each track's reach and speed (too fast for a hand?),
  the closest it comes to everything else and where, anything passing through anything with its depth and
  the moment, a `press` that lost its surface, and what the act leaves changed.
- `watch` - a sheet of frames of the act from the camera, as the set dresser's `watch` is, and close up.
- `trace` - the paths of named points over the act, drawn from the camera and from above like a long
  exposure: a grinding circle that is a circle, a pour that reaches the cauldron.
- `run` - the sandbox, when there is one.
- `submit` - refused while anything passes through anything.

Every picture counts against a budget, as the set dresser's do. The checker uses no physics server: the table
is built on a worker thread off the tree, and nothing in a table's build may need it (`table_thread_check`).
Each moving part's points are sampled over the act against a distance grid of everything else (the sculpt's
distance machinery), at the act's likely length and at half and double it, so an act stretched under a long
passage is checked too.

**The readers are told the acts**, as they are told what moves after their words (`TablePrompts.after`): the
acts of their own beat and those before it, by name, `about` and length. A reader's mark naming no act is
dropped (`voice_marks_only` keeps a reply to the voice's marks). A reader of a work beat is sent a picture of
the table as the act leaves it, as a card's reader is sent its painting. No cheating holds: no act of a later
beat reaches a reader.

**The rules name no kind of work.** As no rules file names a kind of card (`rules_check`), none names
grinding, baking or alchemy: the brief says what the work is, the registries' blurbs say what the laws do, and
the code decides when and fills in. The blurbs give several uses each, never one sample.

## 5. The work heard, and the creatures

**Contacts make their own sounds.** The checker knows when two things meet, how hard, and how fast one slides
on the other. Each becomes a sound: an impact a few damped modes by material (glass rings, stone knocks, wood
thunks), a scrape a friction noise whose loudness and brightness follow the speed and the press, rolling, a
pour (the Soundscape's Minnaert bubbles), a boil. This is FoleyAutomatic's method (van den Doel, Kry and Pai,
SIGGRAPH 2001: modal synthesis for impacts, and the continuous sliding and rolling a triggered impact
misses). Synthesized like the rest of the Soundscape (no recordings) and mixed with the place.

**Creatures, heard and never seen.** A Soundscape layer written by the set dresser beside the wind and the
rain: what makes the sound, by numbers (body size, how breathy, its calls: chirp, trill, purr, huff, snore,
squeak; how many, where, how often, and how its mood runs over the episode). A hatchling dragon by the hearth
is a small body that purrs and huffs; the same layer is a cat on a windowsill, frogs at a pond, pigeons under
the eaves. No species is named in code. A huff may be seen as well as heard: a puff of smoke past the table's
far edge at the huff's moment, from the same plan. Bodies stay off the table (bones and skulls remain the one
exception).

**Risk: nothing pulses.** A purr is a pulse, and a pestle going round is a repeat; both are real sounds and
exactly the mistake the Soundscape has made before. Judged by ear, each part rendered alone and compared.

## 6. Beats: an episode that is not only cards

An episode is an intro, a passage per card, and a close. With work, the spread's positions become beats: a
position may draw a card (as before), may draw a card and then do work with it (an ingredient fetched, ground
and added), or may draw nothing and only work (the brew comes to the boil). Positions are data
(`TablePositions`, `comes`); a position that draws nothing is one more value. A passage per position.

- **Cards are optional.** A show may draw none: no designer, painter or art director runs; the cloth and the
  room are still painted. A jigsaw draws none; its picture is painted (`image:picture`).
- **The producer plans the work** beside the spread, from the brief: per position, what is done and with
  what, what it changes, and roughly how long; nothing that depends on a card it cannot know.
- **The step graph** has `acts` (needs the plan, the table and the draw); a beat's passage needs the acts of
  its beat. The puppeteer's step is a row under the card's own steps, with ✓ and ⟳.
- **What the show has already made** includes the work, so a producer can see that every brew so far ended
  in a color change and plan outside it.

## 7. The first show: alchemy

Cloned from `true-tarot.md` into a new brief in `rift/cards/`. Everything about alchemy lives in the brief
(the bench, the jars, the cauldron and vials, the hatchlings by the fire, how the host talks while working,
what a brew is) and nothing about it in code or rules. The cards stay: a deck of ingredients listed in the
brief's `## Cards`, each with what it does, drawn by the seed as tarot is: the shuffle picks tonight's
ingredients, the reader brews with whatever comes, and the whole cards machine (draw, painting, no cheating,
the reader looking at the card) is used as it is. The work is what each ingredient's card is followed by.

**Open: where a drawn ingredient comes from.** The set dresser sets the table before it knows the draw, and a
shelf holding every ingredient of a large deck is more than a table holds (`MAX_THINGS` is 32). Recommended:
the set dresser builds the bench, the vessels and the tools; the puppeteer builds each drawn ingredient's
small thing (a sprig, a crystal, a beetle's shell) with the set dresser's own `put`, and carries it in from
past the frame's edge; nothing appears or vanishes in view unless the work makes it so.

## 8. Assemblies: bricks, then the jigsaw

Built differently: see next/assembly.md (a free-form build that meanders: no builder role and no booklet; the
puppeteer writes the meander in one law, and a piece has a life before and after it is used). What follows is
the first design, kept for the jigsaw's sake and for what it got right.

Building with unbranded bricks fits a table of rigid things best: every part is rigid, every place is on a
grid, a part goes on by being pressed down, and nothing bends, pours or melts. Every check is exact rather
than measured, and the order of the build is the order of the story.

**The assembly, shared by the bricks and the jigsaw.** One thing made of many small parts: each a kind, a
size and a color, with a place on a lattice and a turn, a build order grouped into steps, and where each part
waits until it is used (a loose pile, a tray sorted by color, a bag per step). It is drawn instanced, as the
deck is (a MultiMesh per kind and size, a color per instance), so a build of hundreds of parts costs little
and stands outside `Props.MAX_PARTS`, `MAX_INSTANCES` and `Rides.MAX_MOVERS`; only the part in hand is a node
of its own.

**One law makes its acts: `assemble`.** From the order, each step is one act: each part is picked out of where
it waits, carried, turned, lowered over its place and pressed home (a millimeter's push, and a click: plastic
on plastic, from the contact sounds of section 5), at a person's pace, now and then hunting through the pile.
The puppeteer sets each step's pace and which passage it runs under; it never writes a carry per brick.

**The bricks.** A brick lattice: studs 8 mm apart, a plate 3.2 mm high, a brick three plates. A few kinds
(brick, plate, tile, slope, round, arch), each sized in studs; the studs carry no logo. A `plastic` material:
glossy molded color, a little light through its edges, and clear colors too.

**The checks are exact** (the builder's tools answer with them): no two parts in one cell; every part held to
the base through studs (a graph of what sits on what); a part held by a single stud is flagged; each step
builds only on what the steps before it built, so the order can really be built; nothing taller than its place
on the table shows. BrickGPT (CMU, ICCV 2025) builds this way, placing bricks bottom to top and rolling back a
placement that collides or would not stand; its full stability test is a force solver, and the connectivity
check is the simpler option to start with.

**Who designs the model.** The producer says what is built, from the brief. A builder, with tools as the set
dresser has, writes the model: `place` (parts, layer by layer, refused when they collide or rest on nothing),
`look` (the model from four sides and from the chair, with a step's new parts picked out), `check` (the list
above), `run` (a program in the sandbox: a shape filled in cell by cell, then merged into the largest bricks
with their seams staggered) and `submit`. An agent drawing in cells is the risk, so the first builds are
things bricks favor: a house, a boat, a tower, a robot.

**The booklet is the build's.** Each step's page is rendered by ghost from the model (the parts the step uses,
and the model so far with them picked out), never painted, and held up beside the build as a card's booklet
page is. The box art is painted, with a render of the finished model handed to the painter as its reference.

**Unbranded.** The brand's name appears nowhere the show says, prints or uploads: no title, tag, description
or booklet carries it; no stud carries a logo and no box a maker's name. The brief says so in its Never, as
`the-shoebox.md` does. No figures: the table has no bodies anyway, and the classic little figure's shape is a
registered EU trademark (General Court, T-395/14, 2015). The brick's own shape is free: the EU's top court
refused it a trademark in 2010 because the shape is what is "necessary to obtain a technical result".

**What is drawn.** Three ways: a set, built as its booklet says (nothing drawn); a dip into the bin (the seed
draws a handful of parts, and the build uses only those, an honest constraint as the deck is); or challenge
cards (a deck of prompts drawn by the seed).

**The jigsaw is a flat assembly,** and comes cheaply after the bricks: a `puzzle` cut (a picture cut into a
seeded grid of pieces with tabs, each piece an outline: `extrude` takes any outline); a `picture` material
across the whole puzzle, painted (`image:picture`); its order a person's (edges first, then by color), given
to `assemble` as a rule rather than a list. Its no-cheating is the puzzle's: the reader sees what is placed
so far.

## 9. Baking

Baking needs three more things: a thing built as its pieces (a loaf as its slices, a sheet of dough as its
cookies) and an `apart` law that slides one away from the rest; a `becomes` (dough into bread: carried out
past the frame's edge to an oven nobody sees, and back as the other thing); and time passing (the clock's
`turn` rate raised for an act while it bakes, the light moving on). What reads at table distance is cutting,
stamping, pouring, layering and decorating; kneading, folding and piping do not, and the brief steers away
from them. Of the four it asks the most of rigid parts, so it comes last.

## 10. Five shows, and what each still needs

Briefs in `rift/cards/`, each telling its agents everything about its work in plain words, since the rules
name none:

| show | file | the cards | runs today? | what it still needs |
|---|---|---|---|---|
| The Quiet Crucible (alchemy) | `the-quiet-crucible.md` | one recipe card from a box of them | yes | a recipe-box episode, by eye |
| Brick by Brick (building bricks, unbranded) | `brick-by-brick.md` | none: a slow free-form build, dug for, tried and torn down, with long silences | built, not yet by real agents | next/assembly.md |
| Corner by Corner (jigsaw) | `corner-by-corner.md` | find-it cards: details of the night's picture, the draw the order it is built in | no | the puzzle cut, a picture across the pieces (`image:picture`), the assembly, the box lid showing the same picture |
| The Recipe Tin (baking) | `the-recipe-tin.md` | one recipe card from a tin of one baker's cards | in part | pieces and `apart`, `becomes`, time passing, a thick stream, `squash` and `roll`, spreading (the painted surface, section 11) |
| Joker Motivation (clown makeup on a mask) | `joker-motivation.md` | none | in part | its fixed things; a mask form; the painted surface; `press` in any direction (section 11); the show with no cards is built |

The makeup show. The genre, read from four channels' transcripts and thirty-odd titles: a deep, slow voice in
the second person to a "chosen one"; a cold open on the title's promise; flattering contradictions; a
faceless "they" who gossip and plot; silence recast as strategy; one plea to like and subscribe "for every
chosen one"; numbered truths, a "let's talk science" aside, an "I know someone who" story; vague prophecy; and
a close of quiet vindication. The brief plays it straight and fences off its worst corners: no revenge, no
secret elites, no hostility to any group of people, never walking away from help, never the comic-book
character himself.

## 11. The painted surface, and the makeup show

The same thing frosts a cake, letters a sign, paints a miniature.

- **A show with no cards** (a plan of `beats`, section 6's open half): no deck, no shuffle, no card designer,
  painter or art director; the producer's positions are beats of work alone; the script opens with no source,
  then `work K` per beat, then the close; no deck stands on the table. Built (the plan's step 11).
- **A show's fixed things:** the mask, its stand and its station are the same every episode. A brief may
  carry things the table stands unchanged every episode, written out exactly (a fenced JSON block under a
  heading the brief names), built by `Props` as any thing is, which the set dresser builds round and never
  moves; and, when the brief says so, a fixed light and sound.
- **A mask form:** a face with no features to speak of (eyes and lips closed, no hair, no ears) as a shape of
  its own (`mask`: width, length, depth), the second exception to "no body" after skulls; the set dresser's
  check calls a carved head a body.
- **The painted surface:** a part's `skin`, a painting laid on it from one side, along the view it was painted
  from (the mask's face from the front). The painting lines up with the form because it is painted on the
  form: the painter is handed the table's own render of the bare part from that side (orthographic) and paints
  the finished design onto it (`image:skin:<thing>`), and the art director checks that nothing moved. Strokes
  reveal it: a law `paint` drives a brush (a free part, aimed and pressed onto the surface along the skin's
  side) along paths in the painting's own coordinates (0-1 across and down), each with a width and a manner
  (`stipple`, dabs filling a region; `line`; `fill`, sweeps); the design shows where the brush has passed. A
  pure function of time, and cheap: when the acts are scheduled, every texel of the skin is given the moment
  the brush first covers it (a reveal-time map, drawn once per schedule), and the shader shows the design
  wherever that moment has passed, its edge soft; nothing is painted frame by frame. Glitter and metal are the
  material's plays; a rhinestone is a small thing carried and pressed. Gates: a stroke's revealed texels
  against its path (control: a texel off the path), a scrub against a play.
- **`press` in any direction:** a brush on an upright mask presses along the skin's side (`along`) where it
  used to cast straight down.

## The plan, in order

Each step leaves ghost working, has a gate with a control that must fail, and the episodes already made play
as they did.

### 0. Spikes

- **0a. The clock runs.** Joints and `turn` on a table that had the bug, watched over a minute of show time.
  Held by `table_work_check` on a clock built for it (a minute hand 60 degrees on at ten minutes, the hour
  hand from three o'clock, a ticking second hand on its steps; the control: the same hands unjointed stand
  still). A table set from now on is told to joint its hands (`Motions.describe_parts`).
- **0b. The shoebox as an act.** The oracle above, before any agent writes an act. Not built: `_pose_box` is
  as it was.
- **0c. The evaluator.** Formulas parsed and evaluated in GDScript, refusing every name it does not know
  (`instance_from_id`, `print`, `OS`). Built (`table/formula.gd`, `Formula`): numbers, the act's names, + - * /
  % ^, calls of 29 functions by name, compiled once to postfix steps; refusals held by the gate, with Godot's
  `Expression` as the control. Not fuzzed against figure.py.

### 1. Working parts and laws that run

`joint`, `points`, `runs`; `turn` and `swing`; the set dresser told of them; `look` draws joints. Done when a
set dresser's clock reads the right time at every moment of a render and a scrub. Gate: `table_work_check`
(the hand's angle at show time, a render against a scrub; control: a hand with no joint stays at its built
angle).

Status: built but `look`. A part's (or a top-level group's) `name`, `joint` (hinge, slide, free), `points`,
`start`, `runs` and `emits` (`Motions.sanitize_work`, kept by `Props._sanitize_part`); each working copy a
node of its own outside its ride mover (`Props._worker`, `_holder`'s `works`); the set dresser reads it all
in Props' vocabulary (`Motions.describe_parts`). A lit candle's wax never works. `look` does not draw joints
yet.

### 2. States, the liquid, effects from a point

`state`, `emits`, the `liquid` material, the stream. Done when incense smokes from its stick and an hourglass
runs out over the episode. Gate: states over time; control: a state with no law holds.

Status: built, not yet seen on a table. States `fill`, `grow`, `tint`, `glow`, `shown`, `emit` and `boil`
(`TableWork._pose_work`); material `liquid` (`prop.gdshader` kind 13: ripples and bubbles on a handed-in
`show_time`, never `TIME`; `glow` lights any opaque material), compiled and drawn on the GPU under xvfb;
`emits` plumes of steam, smoke or fumes from a point, a pool of puffs in closed form on the smoke shader
(`TableWork._plume`); a pour's stream (`_stream`). No incense or hourglass has been watched yet.

### 3. Acts

`acts.json`, the player, the remaining laws (`circle`, `path`, `aim`, `press`, `roll`, `carry`, `jitter`,
`to`, `pour`), the marks and their rests, state that persists, the checker. Done when a hand-written act
grinds in a mortar with nothing passing through anything, and the shoebox's oracle holds. Gates: the oracle;
act determinism (a scrub, a live reading planned again, a render); a clip check in the manner of
`box_clip_check` (control: an act driven through the bowl's wall must be caught).

Status: built but `roll` and the oracle. `table/motions.gd` (`Motions`: the laws as rows, acts made safe) and
`table/table_work.gd` (`TableWork`, the medium's part: channels, timelines, poses). Laws `turn`, `swing`,
`to`, `path`, `circle`, `aim`, `carry`, `pour`, with `press` (a ray down onto a thing's surface,
`TriangleMesh`, 1.8 us a ray) and `jitter`; tracks on one part take turns by their own stretch of the act; an
aim or a circle brings its tool in from where it was, lifted over a rim (`BLEND_LIFT`). The marks are not
section 3's `do`/`begin`/`end`: a card's work is a beat of its own, `<!-- table: work K -->` lays the card and
opens its passage (`TableActions`), the beat's acts run in order under it, an act may start at a word
(`<!-- act: name -->`, `CardReading.parse`'s `cues`), an "under" act fills what its beat leaves, and acts that
would run past the beat's last word are quickened (never under half speed). A begun act never moves on a
re-plan (`_begun`). The checker (`TableWork.check`): a moving thing's points against everything still, by
parity of `TriangleMesh` hits, and the table's top; what a tool goes into (a heap being ground, a liquid) is
soft. Held by `table_work_check` (the pestle pressed into the bowl at every moment, never through it; the
control driven through its wall is caught; a carried jar stays, then goes back; the schedule from a parsed
reading). Not built: `roll`, the shoebox oracle, a render against a scrub.

### 4. The puppeteer

Its rules (`rules/table/puppeteer.yaml`), tools, step and row; the readers told the acts. Done when a real
run blocks a real episode's work through its tools and submits. Gates: no reader prompt holds a later beat's
act (two-sided, as `cards_check` `_archive`); an unknown act's mark is dropped; `rules_check` finds no kind
of work in any rules file (control: a part that names one).

Status: built, never run with a real agent. `cards/puppeteer_tools.gd` (`parts`, `act` (each act answered by
`TableWork.check`), `remove`, `watch` (six frames through an act, `TablePreview.work_watch`) and `submit`,
which asks once that every act be watched); the step `acts` (made from the plan, the draw and the table,
`TableEpisode.needs`), `TableProducer._make_acts` / `_land_acts`, the Table row's ⟳; the producer's plan has
each position's `work`, `work_intro` and `work_close` (`rules/table/producer.yaml` `work`); the set dresser
is told the plan's work (`set_dresser.yaml`, `TablePrompts.work_lines`). Held by `work_steps_check` (the steps
and what each is made from; the `work K` move; a work passage handed its own beat's acts and no later beat's,
the control the later beat's own; a cue kept only for its own acts) and `rules_check` (the work's prompts
whole; no rules file names a kind of work, the control a part that says "potion").

What the work is, as real episodes shaped it:

- **A part's copies work as one.** A part's name works all its copies, a move moving them as one
  (`TableWork.groups`, channel `g<i>:pose`), and "slips 3" one copy alone (`TableWork._part_of`); `parts`
  lists a part's copies once with each one's place, and the blind table text says how they are named
  (`Motions._parts_text`). A glow lights every copy. Gate: `table_work_check` `_copies` (the stack lifted as
  one passes clean, its top copy alone too; the control the bottom copy alone, caught passing into the rest).
- **The work shows on the card.** The work is a row of its own (Work, its ⟳ the block again); a running row
  says what is being done first and wraps to say all of it; the puppeteer's last call and its looks are shown
  as the set dresser's are (`EpisodeCard._tools_progress`, `TableProducer.looks_of`); every status line says
  what the agent has thought while it calls a tool (`TextGen.activity_line`: "calling act · ~74K tokens
  thought · 18:00"). The draw's row (Draw) shows only where cards are drawn, and each beat's row is called
  what the producer calls one (`beat_word` in the plan: an Ingredient, a Coat; Card or Beat when it names
  none) with the beat's own name beside it (panel_fit_check `_check_rows_named`).
- **The producer owns the draw's count.** The brief says in prose how many cards its episodes draw, and the
  plan's spread is the draw (`TableProducer._land_plan`: cut to `SPREAD_MOST` and to a listed deck; a plan of
  `beats` draws none; one producer prompt offers both, `rules/table/producer.yaml`); earlier episodes show
  their counts, and how many cards they drew is one of the habits the producer names.
- **The work is done where it is seen.** A place is found where its thing is at that moment
  (`TableWork._thing_world`, `_work_world`, `place_of(v, fallback, T)`; a press is cast in the thing's own
  frame, `_press`; an end two passes deep, `_timelines`), a loose part left in its thing rides it (`_ridden`:
  a pestle left in the mortar goes home with it, one laid on the table stays), and there is a work spot,
  `"work"` in any place a law takes: the middle of the picture, 6 cm toward the reader, clear of the cards'
  places, the box and what stands (`TablePlan.work_spot`, `Motions.SPOTS`); `parts` says where. The puppeteer
  is told to bring each thing there to work it and put it back after (`rules/table/puppeteer.yaml`), the set
  dresser to leave the middle free or stand there the one thing all the work is done on (a mask). Not kept
  clear by code: the mask show's mask stands in the middle and is worked there.
- **The clock** is shown to the set dresser as a law a part may run (`Motions.RUNNING`): a `clock` law keeps
  the video's own time clockwise about the hinge's axis (`shows`/`time` move the hand from its built hour),
  the set dresser's own `{"clock": "hour"}` is read as one, an act's turn on a running hand is left out and
  said, and a hand an act sets runs on from there (`TableWork.value`). What runs all the time keeps the
  reading's time (`TablePlan.since`, the document's `start_time`, `ReadingStream.start_time`), so a scrub
  does not start the clock again.
- **`act` replies tell the truth about passing through.** The room a part was built in is its own slot
  (going back into it is going home), a point inside something as the act begins may come out, and a part
  back where it was built is as built (`TableWork.check`); a carry's `down` sets a thing on whatever is under
  it, however it is turned (`_settle`).
- **Written cards.** A frame style `written` (`CardTable.FRAMES`): the card's writing is its face, a title and
  its lines in a hand (`CardTable.HANDS`: neat, quick, print, typed), on ruled, plain or grid stock
  (`RULINGS`), a small picture in its corner or a band across its top (`SKETCHES`), laid out as large as fits,
  a long line wrapped and indented, too many cut with an ellipsis (`CardFaces.written_layout`). Card sizes are
  rows (`CardTable.CARD_SIZES`), with `index` (3 x 5 in) and `recipe` (4 x 6 in) read sideways: wider than
  tall, the mesh, the held card, the box's files and the footprints follow (`CardFaces.face_px`, the short
  side 720 px). The designer writes a written card's `writing` in place of a booklet entry (kept as its text
  for every reader, `TableProducer._land_design`), the painter paints only the small picture, the puppeteer
  is handed each written card's lines (a recipe's steps are the work) and waits for its design. Gate:
  `tests/table/written_card_check.gd`.
- **The brief** `rift/cards/the-quiet-crucible.md` is a recipe box: each episode's box the producer's (a dozen
  to thirty brews of one alchemist, every one brewed from the shelf), one card drawn, the card a written
  index card read sideways, its work the whole brew in the card's order; the 44 ingredients are `## The
  shelf` (no longer a deck).
- **A box's inside is measured from its own walls** (`TableBox.inside_of`): clear across a card's width, a
  box is never shrunk under its cards, and an open box's room is as wide as its cards and more
  (`CardTable.box_most`, told the set dresser too; box_clip_check's chest).
- **A lamp moved out of the shot mirrors nothing** (`Lights.build`; lights_check): a glossy brew would
  otherwise mirror a near, dim lamp at full glint.
- **A tool left in a vessel rests as let go** (rules/table/set_dresser.yaml). A plume's puffs are born half a
  puff's size apart as they rise, at least, and fade as it steams less (`TableWork._plume`,
  `Motions.TRAIL_THIN`; table_work_live_check). A heap's vessel wall is the vessel sliced just above the
  floor and its top found walking up (`Props._walls`; cards_check's smooth dish). Each coal glows its own way
  (prop.gdshader `apart`: a part with copies, its own share of the glow on a slow clock of its own).
- **Nothing begins on a guess** (`TableWork.schedule`): an act cued at an unheard word waits for it, and so
  does what follows it; a beat's end is guessed from the last word heard at the voice's own pace
  (`_guessed`); what the plan in force has begun stays begun; an act placed only once its moment has passed
  begins then, not part way through; no two acts move one part at once. Played all at once (as an export's
  sidecar has the words) or a sentence at a time ahead of a hushed voice (as the live window gives them), an
  episode plans every act at the same moment and nothing moves more than 1.6 cm in a frame
  (`tests/table/work_arrival_probe.gd`).
- **A loose part the work moves rides its thing until its act is placed** (`_moved`, from the acts, not the
  schedule); a part standing in its thing as built rides it until first picked up, and "in" means standing in
  the thing's body, its loose parts aside (`_body_of`); a hand's lift into a grind blends in
  (`blend_lift`).
- **A move goes on through its places** and stops only where it holds or turns back (`Motions.slopes`,
  Steffen's monotone cubic, so nothing overshoots a key into the table; `TableWork._chains` makes
  back-to-back carries and paths one move).
- **A pour falls** (`_tick_stream`): each drop leaves the lip as the vessel held it when it left, along the
  vessel's mouth at a shallow head's Torricelli speed, under gravity, to the surface (a closed form of show
  time, thinning as it falls; `_lip_of` finds a part's point, and says when the lip names nothing). The
  puppeteer is told a pour is tipped across the view, and `act` says where each stream lands and when its
  vessel hides it.
- Gates: table_work_check (the words as they arrive, through its places, a pour falls, a scrubbed clock, the
  lift).
- Open: a glowing part (coals, a lit brew) casts no light of its own, so a set dresser lights one with a
  lamp; coals still reach up into the pot's underside where it hangs low over them (an overhang is no wall);
  a written card propped up while the work goes on (it lies where its spread puts it); the shuffle's own
  moves assume a tall card (`TableShuffle` reads `TableMedium.CARD`), so a written deck belongs in a box;
  nothing renders a written card's picture against its painting yet; what is poured is liquid only (a powder
  tipped from a ladle is a cue's burst).

### 5. Beats

Positions that draw nothing, shows that draw no card, the reader sent the table after its act, work in the
archive. Gate: `cards_choose_check`'s pattern: the same context round any brief.

Status: in part. A card's work has a passage of its own (`say:work:K`, after the card's, before the next
card's: `TableEpisode.steps`), and the intro and the close carry their beat's acts. A show that draws no card
is built (section 11's first item). Not built: a position that draws nothing in a show that draws cards, the
table's picture sent to a work passage's reader.

### 6. The alchemy brief, and its first episode

The brief and the author's eyes. A first episode made, watched and reported on, as the lesson's first was.

Status: the brief is written, the episode is the author's. `rift/cards/the-quiet-crucible.md`, cloned in
shape from `true-tarot.md`: 44 ingredient cards in eight shelves, four of them poisons whose jars stay
sealed; the work as fetch, prepare, add, and the brew answers; a raven familiar (a voice) and the hatchlings
(heard only); upload off. Facts in its "The truth" to check before an episode airs: Boyle and the 1689
repeal, Berkeley's 1980 bismuth-to-gold, Pare's 1575 bezoar test, phosphorus "one of the first" elements with
a known discoverer.

### 7. The work heard, and the creatures

Contact sounds from acts; the creatures layer. The creatures need nothing above and could come first. Gates:
levels rendered offline, each part alone; by ear.

Status: the creatures built, the contact sounds not. `Soundscape`'s `creatures` layer (up to 4: `size`,
`breath`, `calls` of chirp, trill, purr, huff, snore, squeak, coo and croak, `count`, `rate`, `side`, `near`,
`awake` over `over` seconds): a source through two formants, events in closed form, a purr the only pulse and
breathing; `Soundscape.seen_calls` gives its huffs, and the table puts a small puff of smoke past its far
edge at each (`TableWork._huffs`). Held by `creatures_check`. Not heard by anyone yet: levels only.

### 8. The assembly, and the bricks

The instanced assembly, `assemble`, the brick kinds and `plastic`, the builder's tools and checks, the
booklet rendered from the model. Done when a builder's model is built on the table step by step, every brick
pressed onto studs that hold it. Gates: the checks (controls: a brick in a taken cell, a brick resting on
nothing, an order that builds a roof before its walls); an assembly posed at show time, a scrub against a
render.

### 9. The jigsaw, 10. Baking

As above, each its own note when it is reached.

### 11. No cards, fixed things, the mask, the painted surface

Section 11. Status: built: fixed things, the mask form, the painted surface, a tool pressed onto it in any
direction, brushes whose hairs bend, a sponge that gives, powder that puffs (next/painted_surface.md). A show
that draws no card: a plan of beats (the producer's, for a brief that draws no cards) is an episode staged
from nowhere (`TableActions.SOURCES` `none`, opened by `begin`; `CardTable.cardless`, `CardTable.beats`): the
producer plans `beats` (`rules/table/producer.yaml` `reply_beats`; `TableProducer._land_beats` keeps them as
the spread's positions, at most `BEATS_MOST`, and takes `none` from any plan that draws cards); its steps are
the plan, a draw of none, the cloth, the room, the table, the acts, the intro, a passage a beat (`say:K`,
said while its work is done: `TableEpisode.steps`, `needs`) and the close; the script is `begin`, `work K`
before each beat, the spread; the table stands no deck, card or box and keeps no room for them
(`TablePlan.deck_count`, `TableThings.off_limits`); each beat is a chapter; the reader, the set dresser and
the puppeteer are told of beats (`cardless` in their rules); the Episode card lists a row a beat. Gates:
`tests/table_show/cardless_check.gd`, `tests/table/table_cardless_check.gd`. Not yet run with real agents.

## Heat and a drink

What steams cools, and a drink takes some of it.

**What steams cools** (`Motions.temperature`, `steam_share`, `TableWork._plume_heat`). Newton's law, a pure
function of show time, so a scrub lands where it should: 85 C at the start, toward a 21 C room, losing all
but a third of what it has over the room in 34 minutes for something a cup across (coffee in a stoneware mug
is at 41 C at 40 minutes, about what real ones do). What is larger holds its heat longer, by how far across
it is: a pot 30 cm across takes two hours to fall as far. Steam is whole down to 80 C and gone at 58 C, so a
mug thins from about 4 minutes and stops at about 18, by itself, on every table already made. As it cools the
trail is fainter, slower, shorter-lived and smaller, and never broken into tufts.

An `emits` may say `hot` (its degrees as the video starts) and `kept_hot` (something is keeping it so, as a
flame under it does). What boils stays hot while it boils, whatever the clock says. Smoke and fumes are not
heat and go on. `parts` tells the puppeteer when each thing will have gone cold, so a reader can notice it.
Nothing warms a thing again: a cup refilled at minute 60 would not steam.

**`drink` is a law on any vessel** (`TableWork._drink_at`, `_to_the_mouth`, `_drunk_from`). The agent says
`drink` and how much, and the hand knows where the mouth is: close under the lens, 18 cm along its axis,
every corner of the thing past the frame's foot however big it is, worked out from the lens's own field. A
third of its stretch up, a third held out of sight, a third back to exactly where it stood. What is drunk
goes while it is out of sight, by a `to` on each named liquid's `fill`: a drink of 0.2 leaves 0.800 of what
was there, and nothing spills (it tips 9 degrees, under a full cup's brink). A stretch under six seconds is
made six. Its steam fades within 55 cm of the lens, or it would cross the whole picture. It goes over what is
built (`lift_over`), since the bricks are in another world from what an act moves.

**Open:** it has been looked at as stills a second apart on a real table with a hand-written act. No
puppeteer has written one and none has been played in the app or heard. The reader is told only through the
act's `about`, which the rule asks to say so, that nobody talks while they drink: there is no mark that stops
the voice for it.

## Decisions for the user

- **No hands:** the tools move on their own (recommended, and the lesson's choice).
- **The role's name:** "puppeteer", or another.
- **The component's name.** Cards would host shows that are not about cards. Recommended: keep the name for
  now; the last rename was 736 references in 30 files (next/notes.md, step 9).
- **Cards in the alchemy show:** ingredient cards drawn by the seed (recommended), or a brew the producer
  plans with no draw.
- **The sandbox for the puppeteer** (and the builder): allowed, as the lesson's solver is?
- **What a brick show draws:** decided: nothing. A free-form build (next/assembly.md).
- **The order after alchemy:** recommended: bricks, then the jigsaw (they share the assembly), then baking,
  which asks the most of rigid parts.
- **The camera stays locked.** Work too small to see from the chair is brought to the lens the way a card is
  held up (a `present` law, which is next/notes.md's open "more than one card up at once" made general)
  rather than the camera moving.

## Risks

- **The agent's sense of motion.** Answered by constraints that make coherent motion out of few numbers
  (`press`, `aim`, `carry`), answers in numbers, `trace` pictures, and a checker that refuses a clip.
- **Kinematics only.** Rigid parts, scales and fades; no cloth, no dough that folds, no fluid but a stream
  and a level.
- **Cost.** One more best-tier run with pictures per episode; a table with more moving parts per frame.
- **Moves are for the story.** A clock runs because clocks run, and work moves because it is being done;
  nothing moves for variety.
- **Copied examples.** The rules carry no sample act, and the blurbs no single sample use.

## Sources

- Articulate-Anything (ICLR 2025): <https://arxiv.org/abs/2410.13882>
- SceneCraft: An LLM Agent for Synthesizing 3D Scene as Blender Code (ICML 2024): <https://arxiv.org/abs/2403.01248>
- Holodeck: Language Guided Generation of 3D Embodied AI Environments (CVPR 2024): <https://arxiv.org/abs/2312.09067>
- van den Doel, Kry and Pai, FoleyAutomatic (SIGGRAPH 2001): <https://www.cs.mcgill.ca/~kry/pubs/foleyautomatic/foleyautomatic.pdf>
- Generating Physically Stable and Buildable Brick Structures from Text (BrickGPT, ICCV 2025): <https://arxiv.org/abs/2505.05469>
- The brick's shape refused as a trademark, CJEU 2010: <https://www.jurist.org/news/2010/09/eu-court-rejects-registration-of-lego-red-brick-trademark/>
- The figure's shape upheld, General Court T-395/14, 2015: <https://gowlingwlg.com/en/insights-resources/articles/2015/lego-s-manikin-shape-ctm-is-ruled-valid>
