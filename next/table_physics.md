# What is in things: liquids, grains, loose things, and the hand that moves them

Opened 2026-10-28, for the user's report on the first alchemy episode (`the-quiet-crucible` #181083):

1. "The liquids are not liquids; they are textures or shaders or something, with no fluid dynamics or collision. By that
   same logic, the containers that would hold liquid probably also do not have collision (the spoon, the cauldron, the
   vials, etc.)"
2. "The vials are not holding snow. Again, it's fake textures there - and it looks worst at the time we need it to look
   the best: when we are pouring from the vial. I would not expect snow to be a liquid: I would expect it to be
   particles, or voxels, or sand-like ... With physics and collision."
3. "When the green dish is 'tipped' into the cauldron, nothing happens. The apparent brass crystals do not move and
   tumble, and they do not fall into the cauldron. They remain attached to the dish."
4. "When we move objects around ... the motions are somewhat jerky, and they follow straight lines. A real human might
   move in curves, or in nonlinear patterns, or it might gently jitter ... akin to what we do with cards management."
5. And the mortar: "very little actually happening INSIDE of the mortar ... I would have expected to drop objects into
   the mortar, and I would have expected the grinding to destroy those things ... the current animation just 'poofs'".

The user expects a new episode to be generated to test it: the agents must be told, and must be able to write it.

## What was found

- **A liquid is a solid lathe with a wet shader** (`prop.gdshader` kind 13). `fill` scales the mesh from its base in the
  vessel's own frame (`TableWork._pose_work`), so a tipped vial's liquid tips with it, and a pour is the puppeteer's
  `pour` track - an `amount` over a `between` - with a stream drawn from the lip while the track says it flows,
  wherever the liquid is.
- **Nothing is loose.** The paua shell's lodestone, quartz and amber are parts of the shell (`Props` leaves): they are
  in its mesh's frame and go where it goes. A heap's copies are laid as a settled handful once, at build, and never move
  again.
- **There are no grains.** "Snowmelt" was a `water` lathe tinted pale; the brief's snow, salt, powder and seeds have no
  form that can be poured.
- **A move is a straight line, eased** (`TableWork._pose`: `carry` is a cubic ease between two places with a sine lift;
  `path` keys joined straight, Steffen's slopes through them since 2026-10-27). Nothing leans as it starts or stops, no
  path bows, nothing held in the air is ever unsteady. The cards are handled better: each held card sways on seeded
  sines (`TableCardPose._present_xf`).
- **The mortar's powder** is a ball whose `grow` the puppeteer drives; nothing is in the bowl to be ground.
- **Godot's physics cannot be used here**: `PhysicsServer3D` has no way to step a space by hand (checked in 4.7.2:
  `space_create`, `space_set_active`... no step), so it runs only in real time on the main loop - never faster, never
  on the worker thread a set dresser's table is built on, never as a function of show time. The table's own rule holds
  (next/table_work.md: "The checker uses no physics server").
- **GDScript's speed** (measured on this machine): a particle's integration and a collision with a lathe 0.37 us; a
  contact pass through a Dictionary hash 11 us a particle - so a few hundred particles stepped at 240 Hz cost a few
  milliseconds a frame of simulated time. Enough for a vial of snow and a handful of crystals, if what is at rest costs
  nothing.

## The design

### Everything that settles is BAKED, and played as a function of time

The table is a pure function of show time (a render, a scrub and a tool's picture of one moment agree). A simulation is
stepped, so it is BAKED: stepped once over the show's timeline from the schedule (`TableWork.runs`), kept as frames, and
played by looking up the moment. The schedule a live reading makes changes only where nothing has begun (`_begun`), so
a replan re-bakes from the first act it moved, from the last kept checkpoint before it. A render waits for the bake to
reach each frame it draws (it is never ahead of it); a live picture never waits (at worst a frame of grains stands a
moment). A set dresser's or puppeteer's preview bakes on a worker, the app's thread waiting a frame at a time, as far as
the moment it pictures - and a table stood again over the same table takes up the last one's bake at the checkpoint
before the first moment their plans differ, channel by channel (`TablePhysics.carry`, `adopt`).

What is AT REST COSTS NOTHING: a grain, a body or a liquid that has settled sleeps on its HOST - the part it lies in -
and rides it, its place kept in the host's own frame (Macklin et al. 2014, section 7: sleeping). It wakes when its host
tips past a few degrees or jolts, when anything else moving comes near it, or when something awake strikes it.

The bake runs on a thread of its own in the app and the render, with a TWIN of the work's kinematics (`TableWork`'s
evaluation over the same data, its own recursion depth, nothing that touches a node): the schedule is handed to it, never
shared while it changes.

### 1. Liquids: a free surface in a vessel's cavity

Simulating a liquid as particles (Position Based Fluids, Macklin and Muller 2013) needs thousands of particles and a
surface rebuilt every frame - more than GDScript can afford, and the surface is what is seen. A liquid on a table is a
BULK that keeps its volume, whose surface is level, and which moves in a few ways that read: the HEIGHTFIELD-PLUS-
PARTICLES split games use (Muller, "Fast Water Simulation for Games Using Height Fields", GDC 2008) - the bulk as a
surface, what leaves it as particles.

- **The cavity** (`Vessel`): the inside of a hollow lathe (its profile's inner wall, the profile curved exactly as
  `Props._lathe` curves it) or a walled extrude (its outline less the wall), as a table of the radius at each height
  (and at each bearing, for an outline), its rim, and a few thousand equal-volume points filling it. A liquid part is in
  the hollow part of its thing whose cavity holds its middle; its own mesh is rebuilt as the whole cavity, and drawn
  clipped by its surface.
- **Its surface is level** in the table's space, wherever the vessel is turned: the plane that leaves the liquid's
  volume under it, from a table of levels by tilt and fill made once from the points (a quantile of their heights along
  the up the vessel sees). A tipped vial's liquid runs to its lip.
- **It pours when it reaches the lip** - and only then - over the part of the rim it stands above, as a weir does:
  Q = (2/3) Cd sqrt(2g) * the integral of the head^(3/2) along that rim (Cd 0.62), from the rim's lowest point, leaving
  at the speed of critical flow over a crest. The tip decides how much flows and when; the puppeteer's guess of an
  amount does not. A stoppered vessel (a shown part across its mouth) pours nothing.
- **The stream** is what left, in parcels: each frame's outflow leaves the lip as the vessel holds it then, and falls
  under gravity until it meets a liquid's surface (it adds to it, a moment later), a solid (spilled) or nothing.
  Drawn as a tube through the parcels in the air, as thick as the flow (r = sqrt(Q / (pi v))).
- **It sloshes**: its surface's tilt is a damped oscillator driven by the vessel's acceleration, at the first sloshing
  mode of an upright cylinder of the surface's radius and the liquid's depth, w0^2 = (g xi / R) tanh(xi h / R),
  xi = 1.8412 (Ibrahim, Liquid Sloshing Dynamics, 2005) - a carried cup's coffee rocks at a few hertz (Mayer and
  Krechetnikov, "Walking with coffee", 2012).
- **It turns when stirred**: a tool moving through it drives its swirl, which dies away over seconds; floating and sunk
  things are carried round by it, and its foam turns with it.
- **It ripples and splashes**: whatever enters it - a stream, a crystal, a pinch of grains - rings its surface (rings
  running out at a ripple's speed, dying as they go) and, hard enough, throws droplets that fall back.
- Drawn by `prop_liquid.gdshader`: the cavity's mesh, everything above the surface cut away, and where the cut is seen
  through, the surface itself at its true depth (written to `DEPTH`, lit at `LIGHT_VERTEX`) - the classic liquid in a
  bottle, with the old wet look (ripples, bubbles as it boils, foam, glow) on the surface.

### 2. Grains and loose things: one particle solver

POSITION BASED DYNAMICS (Muller et al. 2007), as the UNIFIED PARTICLE solver does it (Macklin, Muller, Chentanez and Kim,
"Unified Particle Physics for Real-Time Applications", SIGGRAPH 2014): everything is spheres; granular matter is spheres
with friction; a rigid thing is a cluster of spheres held to its shape by SHAPE MATCHING (Muller et al., "Meshless
Deformations Based on Shape Matching", SIGGRAPH 2005); one iteration a substep, more substeps rather than iterations
(Macklin et al., "Small Steps in Physics Simulation", SCA 2019).

- **Grains** (a new shape, `grains`): sand, salt, snow, sugar, seeds, ash, powder, beads - laid into the cavity of the
  vessel they are drawn in, up to their `fill`, as a jittered packing that is already at rest. Each particle is drawn
  as a small lump of its material (a clump, for powder finer than a particle can be).
- **Loose things** (`loose` on any part): it is not fixed to its thing. Each copy is a body of a few spheres filling its
  shape; drawn with its own mesh, posed by the body. A heap's or a scatter's copies are loose unless written otherwise.
  Held by an act (carried, tipped), it goes where the act has it, from where it really is; let go, it falls as it was
  moving.
- **Collisions**: every other part of every thing is a SOLID with a signed distance in its own space (`ShapeField`):
  exact for a lathe (a 2D field of its curved profile, by radius and height) and an extrude (its outline's 2D field, its
  floor and wall), closed forms for a box, a ball, a ring, a tube's segments and a crystal; a box round anything else. A
  solid moves as its thing or part moves; a particle meeting it is pushed out with friction against its motion, so a
  tipped dish's stones slide and a carried one's ride.
- **In a liquid** a particle is slowed, lifted by what it displaces (it floats if it is lighter, as a petal or a sprig
  does), carried by the swirl, and - if its material dissolves (snow, salt, sugar, powder: `dissolves`, seconds) -
  shrinks away; it rings the surface as it enters.
- **Grinding breaks**: a particle squeezed between a moving solid (a pestle pressed into the bowl) and what holds it is
  DAMAGED; past its material's strength a body splits along its middle, its halves still rigid, and a lone particle into
  two of half its volume, down to powder - a BONDED-PARTICLE model's bonds breaking under load (Potyondy and Cundall,
  "A bonded-particle model for rock", 2004), in its simplest form. Metal, glass, wood and cloth never break. A body's
  first break hides its mesh and shows its pieces as chunks of its material.
- **What a material is, as matter** (`TablePhysics.MATTER`, a row a material class): its density, its strength, how fast
  it dissolves; a set dresser's material may say `dissolves` itself.

### 3. The hand: how a held thing moves

A hand moving a thing does not move it in a straight line at an eased speed. From the motor-control literature, each with
a seeded share for every move (`Hands`), so no two moves are alike and every move is a function of its act:

- **Minimum jerk** in time (Flash and Hogan, 1985), skewed so it slows longer into a careful placing than out of the
  pick-up (MacKenzie et al., 1987: the deceleration phase lengthens with the precision asked).
- **A path that bows**: point-to-point hand paths are gently curved (Morasso, 1981) - a seeded bow to one side, a few
  hundredths of the distance at most, nothing at the ends; a lift that rises early and comes down late, so a thing is
  lifted before it travels and lowered after it arrives.
- **A held thing lags its hand**: tilted as a pendulum from its grip by the hand's acceleration - back as it sets off,
  forward as it stops - which also sets a carried liquid sloshing.
- **A held thing is never still**: a slow drift and a smaller quicker waver while it is off the table (physiological
  postural drift below 2 Hz; tremor is too small to see at the table's distance), none where it rests.
- **Stirring and grinding vary**: each round a little longer or shorter, its radius breathing, its middle wandering a
  millimeter or two.

### What the agents are told

- **The set dresser** (`Props.describe`, `Motions.describe_parts`, `rules/table/set_dresser.yaml`): a vessel's contents
  are what they are - a liquid part, `grains` for anything poured as stuff, `loose` for things that lie in or on
  something - and they will pour, tumble and break for real.
- **The puppeteer** (`Motions.describe_laws`, `rules/table/puppeteer.yaml`, `act`'s replies): a vessel tipped far enough
  pours by itself; tip it over what catches it, hold it while it should flow, tip it back. `pour` is gone (the tip is
  the pour). `sprinkle` lets a little of something fall from a point (a pinch from fingers nobody sees, herbs crumbled
  off a bundle). A pestle pressed into loose things and moved crushes them. `act` answers with what the physics did:
  what left what, when, how much, where it landed, what sank, floated, dissolved or broke - and, for a tip that poured
  nothing, the angle its liquid needs.

## The plan, in order

### 1. The hand

`table/hands.gd` (`Hands`); `carry`, `path`, a tool's way in (`BLEND_IN`), `circle` and `aim` through it. Gate:
`tests/table/hands_check.gd` - a carry ends exactly where it was sent and starts exactly where it was, its speed is
continuous (no step from frame to frame), its middle bows off the straight line (control: the straight line), its lift
never goes below either end, a held thing leans with the hand's acceleration, nothing held is ever still, and the same
act gives the same move every time.

*Status, 2026-10-28: built.* `Hands` (`timing`, `carried`, `bow`, `lean`, `drift`, `held`, `round_of`); `carry` and `path`
(`TableWork._pose`, `_path_at`), a tool's way in (`BLEND_IN`, `blend_lift`) and every `circle` and `aim` (`Motions.point_at`,
a track's `_hand` seed: `hash(episode seed, act, track)`). FOUND ON THE WAY: `Motions.eased`, the cubic in and out every
move was eased by, stepped its acceleration from +12 to -12 at the middle of every move - a jolt half way, which is what
"somewhat jerky" was; it is minimum jerk now. Gate: `tests/table/hands_check.gd`; `table_work_check`'s controls take the
hand's drift (`Hands.drift_most`) and its early lift (`LIFT_SHAPE`).

### 2. Solids, cavities and the solver

`table/shape_field.gd` (`ShapeField`), `table/vessel.gd` (`Vessel`), `table/particles.gd` (`Particles`). Gate:
`tests/table/physics_check.gd` - a lathe's field against points known inside, outside and on it; a cavity's volume
against its profile's; a level that stays level and keeps its volume as a vial tips; a weir that pours only past the lip
(control: upright, nothing); grains that rest in an upright vial and run out of a tipped one (control: upright, none
leave); a body that slides out of a tipped dish and none that leave a level one; a ground body that breaks (control:
not pressed, whole); the same bake twice, frame for frame.

*Status, 2026-10-28: built.* `ShapeField` (a lathe's and an extrude's 2D field in a narrow band, closed forms for the
rest), `Vessel` (radius by height, equal-volume points, the level table by tilt or by tilt and bearing, the weir, the
inside as a part to draw), `Particles` (PBD with friction, shape matching, sleeping on a host, riding a moving inside,
breaking under a moving solid, dissolving, floating). WHAT MEASURING FOUND, each now in the code where it bites:
- a packed array in a list is a copy: `Particles.add` grew none of its arrays, so the first grain written overran them;
- an 8-cell neighbor search needs cells TWICE the widest pair (as wide, it missed neighbors and a heap never settled);
- the contacts of a heap, rebuilt every substep through 27 cells and a Dictionary per pair, were 50 us a grain a substep:
  a pair list once a frame (Verlet's), with a margin as wide as the fastest can close in it, and every per-grain property
  in a packed array made it about 8 - the snow bench's 14 s now bake in under 5 (`Particles._find_pairs`);
- a jar carried briskly leans past the wake angle, and its own thin glass, moving 4 mm a substep, swept its snow out
  through itself: what is in a moving inside now RIDES it (`_ride`) - only how it moves in it is reckoned - sleepers start
  each frame where their host began it and are carried with it through the substeps, a grain woken part way is at rest in
  its inside, solids have the last word in a substep, two overlapping grains part at most `PART_MOST` a second, and a move
  is looked along in steps of half a thin wall (`THIN`);
- one pass of the constraints leaves a heap trembling: a held-up, slow grain loses some of its speed (`SETTLE`).
Gate: `tests/table/physics_check.gd` (the lathe's field; the cup's inside and level counted cell by cell; the flask's pour,
its control and the angle it needs; the jar of snow tipped and carried upright; the dish's stones tumbling into the
cauldron; the crystal ground; the same tip twice).

### 3. On the table

`Props`: `grains`, `loose`, the `powder` class, every solid reported with its place; a liquid's mesh rebuilt as its
cavity. `table/table_physics.gd` (`TablePhysics`, a part of `TableWork`): what is physical on a table, the bake, its
thread and twin, the playback (grains and chunks drawn instanced, bodies posed, liquids' surfaces, streams, splashes),
the report. `TableWork`: `pour` and its stream gone, `sprinkle`, loose parts posed by the physics, the evaluation made
safe to run beside the frame. Gates: `physics_check` on a stood table (a vial of snow tipped over a bowl fills it; a
dish's stones tumble into a cauldron of brew; a mortar's crystal ground to powder; a scrub against a play),
`table_work_check`, `table_work_live_check`.

*Status, 2026-10-28: built.* `Props`: the `grains` shape (laid by the physics, no geometry), `loose` (a part's work; a
heap's or a scatter's copies loose unless written otherwise), the `powder` class (prop.gdshader kind 14), each class's
`density`, `strength` and `dissolves` (a material may say `density` and `dissolves`), `lathe_profile` shared with the
fields, and `solids`/`grains` reported from `build`. `TablePhysics` (a part of `TableWork`): the twin; the bake on a thread
of its own in the app, on the caller's in a render, a preview and a gate (`render_waits`, `aside`, outside the tree);
checkpoints every second, a new plan baked again from the last before the first act it moved (`replan`, `_take_plan`);
quiet stretches skipped without reckoning a solid (`_may_move`); every frame carrying all the picture draws (streams,
rings, drops), so the picture never reads what the bake is writing. `TableWork`: `pour`, its stream and its check gone;
`sprinkle`; a loose part posed by the physics (`pose_of`, drawn as its pieces once broken, `whole`); a liquid the physics
keeps never scaled (`liquid_volume`); `_world_rest_thing` and `_work_world` read no node once built; the materials handed
in by `TableMedium` (`_work.materials`).

### 4. The agents

The rules and the describers above; `PuppeteerTools`' `act` reply. Gates: `rules_check` (prompts whole, no kind of work
named), `work_steps_check`.

*Status, 2026-10-28: built.* `Props.describe` (`loose`, `density`, `dissolves`), `Motions.describe_parts` (what is in a
thing is what it is), `Motions.describe_laws` (WHAT IS IN THINGS IS REAL: how to pour, spill, tip out and grind; the hand
already in every move), `rules/table/puppeteer.yaml` (the same, and `act`'s reply), `rules/table/set_dresser.yaml` (each
ingredient in the vessel it will come out of, a stopper on what stays shut). `act` answers with `TablePhysics.report`.

### Seen

2026-10-28, `tests/table/physics_look_probe.gd` (a cauldron of brew, a jar of snow, a shell of three stones, a mortar with a
crystal; compatibility on the CPU and Forward+ on the GPU): the snow runs out of the tipped jar's mouth as grains, falls in
a stream and floats on the brew; the shell's stones go in and rings spread where they did; the pestle goes round in the
mortar. FOUND BY LOOKING: the liquid's cut surface had been drawn where the eye crossed its plane OUTSIDE the inside too -
seen through the iron wall below the surface, the cauldron read as a green glass tank. The surface is now drawn only where
the crossing lies in the inside (`Vessel.shader_tables`, the shader's `in_cavity`). Not yet seen by the user: a real
episode, and the probe's camera crops its bench's corner (the work's own spot is the middle).

FOUND BY THE THREADED CHECK (physics_check `_threaded`: the bake on a thread of its own, the picture asking as the app's
does, against the bake on the caller's thread): a packed array held in a Dictionary is the array itself, not a copy - every
frame had held the solver's own arrays, so every frame was the latest (scrubbed back, the grains would stand where they end
up; on the thread, the picture read arrays the bake was writing). Each frame keeps copies of its own now, shared with the
frame before when the solver moved nothing (`Particles.moved`). Also: a sprinkle's grains are a grains part of their own,
drawn; a thing with no surface is known to have none (`TableWork._mesh_of`), so the thread never measures it again.

FOUND IN THE APP (2026-10-28, while the user generated 707668, the app at 11.7 GB and the machine out of memory): the work
held its physics and the physics its work, and two RefCounted that hold each other are never freed - so every table the set
dresser and the puppeteer stood was kept when its stage was let go (each `act` and `watch` stands one), its meshes, frames
and checkpoints with it. The physics now holds its work weakly (`TablePhysics.work`), the bake reads the materials off the
twin, and physics_check `_let_go` frees a table and finds both gone. How much of the 11.7 GB the cycle was is not measured.
(The first run of 707668's Work was killed by the kernel at 14.6 GB at 14:25 - likely an app started before the fix, which
reads its scripts at launch.)

FOUND IN THE APP, AGAIN (2026-10-28, 707668's Work rerun: 90 minutes, 3 of its 30 looks, Ghost Notes would not close for
two minutes): every `act` stood a fresh table for each act it was handed and once more for its notes, and each baked the
work from frame 0 to the act's end on the app's own thread - ~16 ms a frame, the draft 105 s long, so 60 to 90 s for one
act and 330 to 390 s for four; the main thread spent 71 of the session's 86 minutes in it. Now: one table a call
(`TablePreview.work_checks`), the bake carried from the last table as far as the plans agree (the restored solids and
held things exactly as a bake from the start has them - physics_check `_carried`, to the bit), checkpoints spread back
over the whole bake (`CHECKS_NEAR` dense, the older thinned), every picture rehearsed from one start (`TableWork.REHEARSAL`;
a watch had rehearsed from 40 s and a check from 10, so neither's bake served the other), and the bake on a worker that
the tools' closing halts (puppeteer_tools_check).

WATCHED IN THE APP (2026-10-29, 707668 played live; the user: the cauldron "so far to the top-left that we can barely see
any of the interactions with it"; the iron's splash "far too intense: it splattered everywhere"; the mandrake slip "pulled
... to the center, then moved it over to the cauldron - but never put it in. Then suddenly ... 'poofed' back to the
center. Then, we placed the mortar and pestle directly on top of the root"; the ladle "supposedly puts liquid into a vial -
but we cannot see it", the vial's color change unseen, and "when the vial is put into the rack, it slowly fills with liquid
finally ... far too late"). Measured on a copy of the episode:

- THE LIVE BAKE FELL BEHIND THE SHOW. From the iron on, 10 s of show took 14 to 23 s to bake: the filings left in their jar
  never slept (a dozen of ~165 trembling at 1 to 18 cm a second, a single constraint pass's residue, and each time a few fell
  asleep the rest lost what they rested on, were jolted, and woke them - a quarter-second cycle). A live show past the last
  frame baked draws that frame, and a plan changed as a sentence's words arrive is baked again from the change - so the slip
  stood where the bake had last set it down while the mortar (no physics) came down on it, and the vial filled once the bake
  got there. Now A HEAP AT REST SLEEPS WHOLE (`Particles._settle`: grains of one part slower than SLEEP_SPEED on the whole,
  none past TREMBLE, sleep together once most have been still SLEEP_AFTER): 10 s of 707668 bakes in 3 to 6.4 s, the whole
  way through. Where a live show does outrun its bake, a loose thing the work has held since the last frame baked is where
  the work has it (`TableWork._outran`), and the log says when what is in things is behind and when it caught up.
- A SPLASH SUMMED A FRAME'S GRAINS: every frame's entries into a liquid made one splash of their momenta together, so the
  filings, a few spheres a frame, splashed 37 times in five seconds, 64 drops at once, 6 cm over the brew - and each sphere
  stands for a clump of filings. Now a splash is one thing's, as it first goes in: a drop for every 2 g of it, entering
  faster than 0.5 m/s, thrown up at 0.35 of its speed, a grain as heavy as it is drawn (`TablePhysics._events`): the iron
  rings the brew 32 times and throws nothing; a 30 g stone from 15 cm throws a few drops a centimeter or two.
- A DIP FILLED NOTHING: no vessel took liquid from one it was under, so the ladle "drew up a measure" of nothing, poured
  nothing, and the vial was filled by the puppeteer's `to` on its fill (magic, no stream). Now a vessel under a liquid's
  surface fills over its rim as a weir does until it stands as high inside as out (`TablePhysics._dips`), and a liquid's
  color follows the work's tint, so what is dipped or poured out carries the color it has now. The ladle, resting in the
  brew, is full from the start, carries ~10 ml out and pours a stream; the puppeteer is told a dip fills and never to fill
  by magic what a pour fills.
- THE CAULDRON IN THE CORNER is the set dresser's: told to push everything out toward the edges and to leave the work's
  spot clear, it stood the one thing that cannot be brought to the spot at the frame's edge. It is told now that what
  cannot be brought is worked where it stands and stands beside the spot, whole in view; and that a thing needed only for
  a while may wait out of the shot, on the table past the frame's sides (the user: "objects can exist outside of the
  viewport"), to be fetched in.
- THE SLIP IS THE BRIEF'S: the-quiet-crucible's brief puts a poison in "as its name on a slip of paper", and nothing on the
  table carries words - so the slip is a blank white square. The user: "The slip should show writing, if the script says
  it should" - a sheet is written on by the work now (`write`, below).

Gates: physics_check `_heap_sleeps`, `_splash`, `_dip`, `_let_fall`, each failing with its fix broken (169 filings awake;
151 splashes; the cup empty; the stone the bake's).

### Built the same day (2026-10-29): words written, the work heard, a blade that cuts

The user: "The slip should show writing, if the script says it should. And we definitely want to try the sounds, and
support the cutting board. But please make sure the sounds are not distracting; they need to be subdued and quieter than
the voice."

WORDS ARE WRITTEN (`Motions.LAWS` `write`, state `written`; `SheetWriting`): a sheet part (`Props.sheet_top` keeps its top
surface on its work) is written on by the work - `{"law": "write", "text", "hand", "ink", "between"}` - in one of the
recipe card's hands (`CardTable.HANDS`: neat, quick, print), drawn on the processor from the font's own glyphs into a picture
(red the ink, green when each point is put down, line by line) on a thin skin over the sheet's bend and fold, shown as far
as the pen has got (`shaders/sheet_writing.gdshader`). Nothing on a table is set written; the puppeteer writes only what
the script or a card says, at the work's spot. Gate: table_work_check `_write`. Seen: "Mandrake" on a slip, legible from
the reader's chair.

THE WORK, HEARD (`WorkSounds`, owned by the table on the stage, played as its picture is drawn - live, and in a render, whose
Movie Maker records the engine's sound): a thing set down (`TableWork.set_down`: a carry `down`, its mass from its box and
material) thumps the table and rings as its material does; a point pressed onto something (`TableWork.pressed`) grits only
while it touches, as fast as it moves; a liquid at a `boil` (`TableWork.boiling`) bubbles, steam alone is silent; a pour's
stream landing trickles (the physics' frame). Levels, the voice at ~0.06 RMS: an iron pot set down peaks 0.045, a glass
jar 0.0077, a paper slip nothing; grinding 0.004 RMS; a boil's bubbles 0.0085; the loudest 0.4 s of a busy bench 0.0068 RMS.
Gate: work_sounds_check (silent before a landing, while lifted, before the boil, a held thing never). NOT YET HEARD BY THE
USER, and not yet in a real export.

A BLADE CUTS (a part's `edge`; `Particles._cut_through`, `TablePhysics._cut`, `MeshCut`): a moving blade come down into a
loose thing of soft matter (`TablePhysics.CUTS`: plant, wax, paper, leather, fabric) parts its spheres along its own plane
into two rigid bodies, set off the blade by its width (`PARTED`), and each piece is drawn as the thing's own mesh kept behind
every cut it has had, each cut faced in a lighter color. Measured on the way: a blade shoving what it cuts (a sphere 1 mm
from its plane) crushed it against the board and flung it 20 cm, so soft matter passes through a blade; a body's upper
spheres, touching nothing but itself, took the knife beside them as their host and the piece rode off on the knife; a board
carried counted as squeezing what lay on it (`CARRIED`: a solid under a thing carries it); and the carrot lay 6 mm into the
board on one row of spheres along its middle, its tip unfilled - a body is now filled to its box's faces, a sphere down its
middle where it narrows (`fill_shape`, `BODY_MOST` 36), and held up as a whole (`_settle`'s `borne`), or a body in layers
never slept. Gate: physics_check `_cut` (three pieces, apart, the act saying so; the knife short, and a stone, cut nothing).
Seen: a carrot chopped three times on a board into four pieces, the board carried over a pot and tipped, the pieces falling
in, cut faces showing.

Open: the tip of a tapered thing rests 2-3 mm high on its 7 mm spheres; slices thinner than the sphere spacing (~1.4 cm)
are not cut (a stroke with no sphere on one side passes); a thing to be cut must lie on the board as a part of it or be
carried there (a thing of its own is stood with its lowest point on the cloth).

### Watched again (2026-10-29, the-quiet-crucible 119515): the ingredients made real

The user: the grinding not heard; the dragon's blood and the pumpkin seeds "didn't crush: they just scaled down a bit ...
no collision, they don't rest on the bottom of the mortar, and they appear to be floating"; the pestle held up "perfectly
still"; the ambience going on through a pause; the cauldron still in the top left; a dragon's scale lowered into a vial
"clips, because it is larger than the vial ... We really want that behavior everywhere there is interaction between
components, because faking it looks bad"; the vial drawn from twice, empty the second time, and reused at all ("The old
vial is contaminated"); the last cork put in sideways. What was found, and done:

- THE SOLVER WAS FULL. 119515's table had 125 loose things; its grains took 712 of `Particles.MOST`'s 900 particles and
  its lavender and sage the rest, so 114 were left rigid - drawn where the work put them, colliding with nothing, never
  crushed: the dragon's blood, the seeds, the nails, the scale. A LOOSE THING IS NOW A BODY ONLY ONCE SOMETHING COMES TO IT
  (`TablePhysics._wake_loose`): the work takes it up, its holder moves, a moving solid or something awake comes within a
  few millimeters (`Particles.awake_in`, by cells - one box round everything awake had woken the whole bench between two
  busy places). Untouched, it costs nothing; touched, it is never rigid. `MOST` 1600. A frame shares what did not change
  (sizes, what is alive, owners, bodies) with the last. Gate: physics_check `_held_meets` (an untouched heap of forty costs
  no particle).
- A HELD THING MEETS WHAT IT IS CARRIED INTO (`Particles._held_way`): moved whole toward the hand only as far as nothing is
  deeper in a solid than it already is (a conservative advance, halved four times), then on along what stopped it, level
  or upright. A free body does the same after its shape match where nothing near it moves (`_way`): one sphere at a time,
  a scale's spheres 6 mm apart had let a vial's 1.5 mm glass slip between them, and a ratchet of a slack per substep had
  walked a held one through the wall. A held loose thing now makes its frame be stepped (alone on a still table, nothing
  had been). Gate: physics_check `_held_meets` (a 3.2 cm scale stays out of a 1.3 cm mouth; a bead goes in, onto the floor).
- GRINDING IS THE PHYSICS'. The puppeteer's transcript: told every time that its pestle "PASSES THROUGH" the mortar, it
  lifted the pestle 2.8 cm clear and shrank the lumps with `grow`. Two causes: a `press`ed tool's head touching the bowl's
  sloping wall as it goes round was counted as passing through (`TableWork._pressed_into`: within `PRESS_INTO` of what it
  presses, it meets it); and GODOT'S RAY AND TRIANGLE TEST, whose epsilon (0.00001 on the edges' product) passes a ray
  through any triangle smaller than a few millimeters in meters - a lathe bowl's floor within 2 cm of its axis - so a pestle
  pressed in a mortar's middle went to the table under it. The work's ray meshes are kept in centimeters
  (`TableWork._ray_mesh`, `_ray`; `TableBox`'s are not yet). A `grow` on a loose part is refused, saying how to grind it;
  `parts` says which loose things break. Gates: physics_check `_grind` (a seated pestle pressed round the floor passes
  through nothing; too wide a round, its head in the wall, does), table_work_check `_loose_size`.
- HEARD: each piece the physics breaks off crunches (`TablePhysics.breaks_in`); the grit a little louder (`GRIND` 0.035,
  0.0055 RMS). A PAUSE HOLDS IT: the show's time unmoved two ticks, the player is held (`WorkSounds.tick`) - a starved
  generator had been restarted at the same moment over and over. And a pour's landing kept a quiet frame busy until it
  died away: frozen in the last frame, its bubbles had gone on to the end of the show. Gates: work_sounds_check.
- A HAND HOLDING A THING UP SWAYS (`TableWork._held_up`): left between moves touching nothing (a pestle lifted out of its
  mortar, a vial over a pot), it drifts as a hand holds it, `Hands.HOLD_SWAY` times the drift of a careful move, coming on
  as the move ends and dying away before the next. Set down, or resting on or against anything, it is still. Gate:
  table_work_check `_held_up`.
- THE CAULDRON: a show drawing its cards from a box kept a shuffle's 44 by 28 cm bare in the middle, where nothing is
  shuffled - the set dresser's pot, first written right beside the work's spot, had nowhere to stand but the back corner.
  Only its spread is kept bare now (`TableThings.shuffle_rect`), and the blueprint draws the work's spot (a cross; the
  text gives it in centimeters) for what is worked where it stands to be set beside. Rule: the set dresser's THE WORK.
- THE BRIEF (rift/cards/the-quiet-crucible.md): a vessel that has held one thing is never used for another - a clean vial
  each time, two or three on the rack. The second dip came up full in the bake (5.3 ml); live, the bake was behind the show
  there (the log's "behind the show" at 248 s) and the vial was drawn as it had been. `parts` gives the `turn` that stands
  a thing laid on its side upright (the stopper); the puppeteer is told a held thing meets what it is carried into.

- THE BAKE KEEPS AHEAD OF THE SHOW (measured on a copy of 119515, its 167 s of acts, under xvfb): 243 s to bake before,
  129 s after. Made bodies take more of a frame, so what a frame did for nothing went: an empty inside is no longer levelled,
  sloshed and poured every frame (18 of the table's 24); with nothing moving, the loops over every sleeper are skipped; what
  rides a moving vessel is looked for only near it; the stretches the work holds a loose thing are found once a plan; a
  stream's parcels are looked at only while one could still be falling (a pot lapping over its own rim back into itself
  had made thousands, every one scanned every frame); what floats on a calm liquid sleeps there (`Particles._afloat`) and
  wakes as it is stirred, tipped or struck - three seeds afloat had kept 24 particles awake to the end; and a body no
  blade will cut (not soft, or under 3 cm) spaces its spheres up to twice their touching (`BODY_SPREAD`: a pumpkin seed 8,
  not 20). Still over the show's pace: ten seeds tumbling into the mortar (1.1x) and a scale and a cobweb taken up (1.35x),
  each some 20 s - the live bake runs up to 20 s ahead (`HORIZON`).

Open: a new episode, for the set dresser's and the puppeteer's new rules; the user to hear the grinding and watch a pause;
119515's pot laps over its own rim into itself through every act (its brew at 68% of a bellied pot's inside, sloshed by the
stir) - unseen, but a stream the whole show;
`TableBox`'s rays in meters; things a hand carries along a path through another thing now catch on it and drop (119515's
lumps on the gimbal candle) - `act` says where they land.

### Watched again (2026-10-29, the-quiet-crucible 841899): what rests, what is put back, what a liquid feels

The user, watching it live: a frankincense tear dropped into the mortar "lands ON TOP of the pestle, and just sits there";
the grinding "sounds a lot closer to T.V. static ... a touch too loud" where "Stone on stone should be a scraping sound,
low and rough, abrasive"; the ladle going round in the cauldron with no "water physics, surface tension, or any of that
... better liquid physics, which would react to ANYTHING we put into them"; the crushed frankincense "left behind,
spinning weirdly on the table" as the mortar was lifted; the pestle put back "clipping through the side of the mortar,
completely"; the sulfur that "never settles into the bowl" of the balance, "just floats above the scale"; the sulfur's
cork put back "sideways", and the jar moved with its sulfur clipping through it and left on the table; one face of a
piece of sulfur "glowing brightly, for no apparent reason"; the ash crock's lid "moving about wildly on top of the pot,
never stopping". Probed on a copy of the episode (its acts as kept, `rehearsed()` times), and done:

- A BODY WAS FLUNG, and so it spun. The whole-body advance (`Particles._way`) slid what stopped a body on by the rest of
  the way between two poses' ORIGINS - which lie where the body was made, a meter off - so the least turn between them slid
  it centimeters: a tear wedged between the pestle and its mortar went 8 cm up and out in a frame, at the solver's 2.5 m/s.
  The slide is now its middle's, and a body's poses are passed through about its middle (`Particles._between`). Of six
  places along a pestle a tear was dropped on, three had flung it 30 cm to 1.8 m; none does.
- WHAT FALLS ON A SLOPE GOES DOWN IT: a solid's surface holds what rests on it by its own friction as well as the thing's
  (`TablePhysics.SURFACES`, met as their geometric mean) - polished metal and glass slick, stone and cloth not. The tear sat
  on the pestle's head, sloping 28 degrees, which the one friction for everything (0.65, 33 degrees) held. Gate:
  physics_check `_rolls_off`, a board tilted 12 degrees the control.
- WHAT IS IN A THING GOES WITH IT: a sleeper slept on the solid it had last met in the substep's loop - the pestle pressing
  it from above, or nothing, resting on other lumps - and stayed where it was as its mortar or jar was carried off. It sleeps
  on the inside it is in, else on what holds it up (`Particles._host_of`, `_inside_at`; `touch` the contact facing up
  most, the table's top `TABLE`), and one asleep in an inside that is carried is carried with it (`_rehost`). On the copy,
  all 64 of the crushed frankincense ride the mortar up to the pot and back.
- A THIN THING'S FIELD WAS TOO SHORT: past a band of six cells every point reads the band's distance, and a balance's pan
  1.5 mm thick has 0.44 mm cells - 2.7 mm, under a lump's spheres' 3.5 mm, so the sulfur lay 8 mm over the pan touching
  it. The band is at least `ShapeField.FAR_LEAST` (12 mm). The pan's beam is still the puppeteer's path, now with the
  lump lying in it.
- PUT BACK AS IT WAS: a carry with no `to` goes back where the thing was built, and now AS it was built, unless `turn`
  says (the cork laid on its side went back in sideways); a part goes back where it was built IN ITS THING, the thing as it
  stands now (`TableWork._home_of`: the pestle went back to where it had been built on the table, under the mortar now 9 mm
  higher); and a thing set down stands on what is under its own foot (`_foot`: its surfaces' lowest points), never its
  box's corners - the round mortar had been set down on the edge of what was beside its box. Gate: table_work_check
  `_put_back`.
- A THING AT REST IS NOT HELD UP: whether a hand holds a thing between moves (`_held_up`, it sways) was asked of its
  box's corners; a round lid on its crock has them out in the air past the rim, and swayed to the end of the show. It is
  asked of its own surface now (`ShapeField.surface_points`). Gate: table_work_check `_put_back`.
- GRINDING IS A SCRAPE (`WorkSounds`; van den Doel, Kry and Pai's FoleyAutomatic): the surface under the point read at the
  speed it slides (its finest grain at speed / 0.2 mm), its bumps roughening it at random, the point catching on grit, and
  all of it ringing what is ground in - its body low, the bigger the lower, its material's modes damped by the hand. The
  middle of its spectrum 560 Hz where the grit's was 4.7 kHz, its loudness in 20 ms pieces varying by 0.45 of itself where
  the grit's held to 0.03; 0.0034 RMS on the bench where it had been 0.0055. Gate: work_sounds_check (low and rough, and
  steady noise at 2.2 kHz neither, the control).
- A LIQUID'S SURFACE IS MOVED BY WHAT CROSSES IT (`SurfaceWaves`): its heights over a grid across its vessel, a damped wave
  equation at 0.23 m/s - water's slowest ripple, at 1.7 cm, where its surface tension and its weight pull alike - coming back
  off its walls; a solid coming into a cell of the surface pushes it up, going lets it down (a bow wave and a wake), and
  what falls in dents it; stirred, it curves as a turning liquid does (ω² / 2g); what floats rides both. Kept a frame at a
  time as a byte a cell, drawn by its shader as the surface's shape - the cut along the glass follows it, and the eye's ray
  meets it. Gate: physics_check `_waves` (a spoon stirring a pot: 2 mm ripples over 79% of it; still 9 s after; the
  spoon going round over the water, the control, leaves it at rest).

Open: the glowing face of the sulfur (not yet seen - likely a polished crystal's facet catching a candle, or a facet's
normal); tools are still the work's own poses - a pestle the puppeteer drives into a wall goes into it (said by `act`),
where a held tool meeting what it is moved into, and one let go falling to rest, would make it the physics'; a balance's
beam is the puppeteer's path, not the weight in its pans; a solid sunk in a liquid does not raise its level.

### Watched once more (2026-10-29, 841899 replayed): what a hand picks up, and what weighs

The user, replaying 841899 with the fixes above: the brimstone on the balance "does NOT move with the scale. It still floats
above it, the weight never transfers to the scale. So we definitely need physics there, as well as on the stones
themselves"; the brimstone "remains on the table, even after the jar containing it is moved to its original position";
and, of the two open items - tools and the balance - "The physics everywhere is just going to provide us with a better
long-term foundation". Found and done:

- A PART'S JOINT NEVER REACHED THE PHYSICS: a part stood where its thing had it, its own hinge or slide and the part it hangs
  from never asked (`TableWork._work_world`), and the bake looked only at `pose` channels (`TablePhysics._moves_at`,
  `_may_move`) - the beam tipped on the table and its pan dipped, and in the physics neither moved: the lump laid in the
  pan lay where the pan had been. A part is now where the part it hangs from has it, turned on its own joint
  (`_base_world`, `_joint` - one function for the picture and the bake), and its solids move with any of those.
- A HINGE THAT HANGS SWINGS BY WEIGHT (`TablePhysics._find_swings`, `_swings_step`): a hinge on a level axis whose own weight
  hangs below its pivot swings by the torque of that weight and of whatever lies on it - a sleeper on its solids, one awake
  held up by them, a loose thing whole, a liquid in it, a part let go on it (`_loads_on`) - its inertia about its axis,
  its pivot's drag, its stops; no act turns it (the puppeteer is told, and its acts on it are noted). A part of it with no
  joint whose middle hangs below the pivot HANGS from its top, level, its weight and its load pulling at where it hangs, as a
  balance's pans hang from the beam's ends (never higher than the pivot: a strand's thickness on top of the beam had hung both
  pans over it and tipped the empty balance to its stop). TRUED AS BUILT: whatever turn its making leaves it with, empty, is
  taken off, as a balance's nut sets it level (two pans' arms 0.13 mm apart had tipped it to its stop). Masses come from the
  solids' fields sampled over their boxes and their materials' densities (`_mass_of`). On 841899's balance (21 g of beam,
  its weight 0.6 mm under its pivot, 34 g pans) the lump of 1.9 g tips it to its 10 degree stop in a third of a second,
  riding its pan down 1.1 cm; lifted off, the beam comes back level over a few seconds.
- WHAT A HAND PICKS UP IS A RIGID BODY (`RigidParts`, Muller et al. 2020's positional contacts): every free part an act
  moves that is not loose - its own solids and those of every part of it with no joint - with a mass, a middle and an
  inertia, met as points on its surface against every other solid's field and every other solid's points against its own
  (a thin rim never slips between its points). HELD, it goes where the hand takes it in pieces short enough never to step
  over a wall, pushed out along what it meets and turned about it as a firm grip gives; LET GO, it falls, its friction
  against what it lies on, trembling damped, asleep on that and carried with it. The picture draws it where the bake has
  it; `act`'s check still reads the acts' own poses (`TableWork._planned`), so the puppeteer is told what its acts would put
  through something. A body clear of everything by more than it has gone since it was last looked at is not looked at
  (a ladle in the air or stirring clear of the pot's wall costs next to nothing), and one settling stirs nothing loose round
  it (`RigidParts.STIRS`).
  The solve, found the hard way on a rod: contacts one after another turned the body against each other (a rod landing flat
  spun to 47 radians a second); their mean, reckoned against one pose, puts right only the mean depth (a rod tilted against a
  block stood 2.5 mm in it). So a LET-GO body takes the mean of its contacts and a velocity pass after (Muller et al.: its
  speed along each contact set to a small bounce of how it came in, none under a substep of gravity), and a HELD one takes
  them one at a time, deepest first, each measured again - a hand drives what it holds into what is in the way, and nothing
  held is left to settle. Its surface points are taken farthest first (every k-th had left a box's edges out); a move goes
  on from where its last piece was kept, no further a frame than its pieces at their longest. A body settling on what is
  being moved is carried by it (a pestle let go as its mortar was picked up had been left in the air), a hand never lets
  go between two moves less than `HOLD_GAP` apart, two held at once never push each other apart, and a part going home into
  a rigid body the physics set down off its plan goes where that body really is (on the bake's twin, `TableWork._home_of`).
  Cost: the held ladle stirring in its cauldron bakes as fast as with no bodies at all (0.63x real time against 0.64x), once a
  body clear of everything is not looked at, a reach is the box its points fill, and solids keep their points between frames.
- WHY THE LUMPS STAYED ON THE TABLE (found last, the root of it): a SLEEPING BODY'S POSE FROZE whenever anything else on
  the table was awake. Putting a heap to sleep (`Particles._settle`) hosted again every sleeping body each frame, not only the
  ones that fell asleep then, from where it lay - its pose recomputed against its host's new place, so it never moved, while
  its spheres rode the host unseen. Offline, with nothing else awake as the jar went home, the lumps rode; live, something
  always was. Now only a body that fell asleep is hosted. And A HELD BODY JOLTS NOTHING (the pushes of what it met as it was
  taken up had woken its contents, and left them in the air); a hollow part with loose things in it is one of the vessels
  reckoned, now 40 (`LIQUID_MOST` - a jar left out had no inside for its lumps to ride).
- WHY THE LUMPS STAYED ON THE TABLE LIVE (too): the solver was full. A table's grains take most of `Particles.MOST` from the
  start (841899's: 1,225 of 1,600), and every loose thing a moving solid comes near becomes a body - and stayed one to the end
  of the show. So the solver filled ("lies as it was built: the physics holds no more", in the app's log), and the jar's
  lumps, never made bodies, were drawn where they lay. Now A LOOSE THING AT REST LIES AGAIN (`TablePhysics._rest_loose`):
  asleep `RELEASE_AFTER` seconds, whole, held by nothing and in no liquid, it gives its spheres back and lies where it came
  to rest, as what holds it holds it - drawn there, carried with it, still weighing on it - until it tips or jolts under it
  or anything comes to it; one turned away for want of room is asked again. ITS BODY LETS GO OF ITS SPHERES (the solver gives
  a dead sphere's place to the next made, and a body still naming them shape-matched the next thing made there toward its own
  old shape: a resin tear let go over its mortar flew off the table at the solver's fastest, a lump laid on the balance leapt
  33 cm), and one lies again only where it is AT what it lies on (a sleeper's host found through its neighbors had been a jar
  carried off without it). And a body settling stirs nothing loose round it,
  nor wakes another settling body (a jar and its stopper had kept each other awake for eighty seconds).
- An act's report says where a loose thing's MIDDLE is, never its node's origin (a heap's copy has that where the heap was
  built, centimeters off and swung wherever it turns: stones in a cauldron had been "on the table").
- A RECIPE CARD IS ITS WRITING (the user: "where would that picture have come from? ... just treat these like a baker's
  recipe card... just text"): a written card has no picture - none painted, none checked, nothing waits on one
  (`TableEpisode.written_card`), its title across its width; the designer writes its writing alone, and the reader meets it
  as its writing (`on_card`). Gate: written_card_check.

Gates: physics_check `_weighs` (a balance tips to its stop with a lump on one pan and comes back level, its pans level
throughout; an act turning the empty beam, the control, turns nothing), `_tool_meets` (a rod driven 5 cm into a block stops at
its face; the work's own rod, the control, is in it), `_tool_falls` (a rod let go 6 cm up lies on the table, asleep).

Open: the glowing sulfur facet (set aside by the user); a sunk solid does not raise a liquid's level; a rigid body in a
liquid has no buoyancy; whole things carried (a mortar, a balance) are still the work's own poses, set down by their foot;
a held tool the acts turn through what it is in (a pestle taken from lying to upright in its mortar) is pushed out of it with
a jolt - the acts' own blend should go round it. The work's own law checks read the acts' poses (`TableWork._planned`); the
physics is physics_check's to hold.

### Watched a third time (2026-10-30, 841899 replayed): the ladle's stream, what never slept, and what the acts got wrong

The user, replaying 841899 (on the code before this section): "when the ladle goes into the cauldron, the liquid inside falls
through the cauldron and into the pan below it"; the mortar "never actually made it to a position above the cauldron. It was
to the side, tipping onto the table"; "the frankincense still falls through the jar onto the table, and stays there. Same with
the crushed stuff inside the mortar"; and of all of it, "it's hard to tell because of the lag". Each found by baking the whole
show once on a copy and logging it (where every parcel went, each body's sleep, each stage's cost), never by re-rendering:

- A SUNK VESSEL POURED: the ladle filled from the brew (a dip), and its own surface, sloshed by the stir, stood over its rim -
  so it "poured" 2,755 parcels over the show, 18 liters, every one back into the brew, each living up to 0.08 s and falling
  up to 6 cm from the lip at the cauldron's floor: drawn, a stream through the cauldron's floor toward the brazier. A vessel
  whose lip is under another liquid's surface is that liquid now, full, and pours nothing (`TablePhysics._under_liquid`):
  32 parcels in the show, all as the ladle comes up out of the brew. Gate: physics_check `_sunk` (a ladle stirred round a pot
  of water pours nothing under it - 430 parcels without the fix; the control, lifted out and tipped, it pours).
- TREMBLING IN PLACE IS AT REST (`RigidParts.SLEEP_DRIFT`, `Particles.SLEEP_DRIFT`): a body touching something that goes no
  further than half a millimeter from where it was sleeps, however fast it trembles - a ladle laid on its rest rocked a
  hair's width each way, its far end over the sleep speed, and kept the bake reckoning every frame in full; a jar's lumps
  trembled a tenth of a millimeter in it for seconds.
- A LANDING IS NO JOLT (`Particles.jolt_of`): a host's jolt is its acceleration along the table and downward past falling -
  set down or lifted, what lies in it is only pressed into it (a millimeter's landing read twice `WAKE_JOLT`).
- A HELD BODY GOES AT THE HAND'S PACE (`RigidParts.CATCH_UP`): one held back by what it met comes back into the hand no
  faster than the hand goes plus 6 cm a second, and presses into what holds it back no harder - the pestle stood up through
  its mortar's wall had been driven into it 9.6 mm a frame and squeezed out sideways, 34 mm off the hand in a tenth of a
  second; now 0.6 mm at the most.
- ONLY A HAND CRUSHES (`Particles._np`, a solid's `presses`): a body let go, settling by its own weight, rests on loose things
  and never breaks them - a stopper let go in its jar crushed the tears under it, and their pieces flew out onto the table
  and the saucer beside it ("falls through the jar onto the table, and stays there").
- THE TABLE HOLDS A LET-GO BODY whatever else pushes it (the mean of its contacts puts right only their mean depth), and A
  LET-GO BODY RESTS ON THE LOOSE THINGS UNDER IT (`RigidParts.LOOSE`: a sphere it has sunk into, pushing it up, holds it as a
  solid would): the frankincense jar, wedged with its stopper, had sat 2.2 mm into the table; now 0.1.
- THE ACTS' OWN FAULTS, now said by `act`: the mortar was tipped 30 degrees with its lip 2 cm short of the cauldron and 1.7 cm
  under its rim, while a `sprinkle` from a point over the brew put the powder in - a sprinkle naming a thing the act moves
  must fall within 3 cm of it (`TableWork._sprinkles_said`, `PINCH_NEAR`; the puppeteer is told a pinch is never a pour); and
  each jar's stopper was carried back with no `turn`, lying on its side as it had been laid at the fetch, so it dropped into
  its jar - a part let go more than a centimeter from where its act left it is said so (`TablePhysics.report`, `LET_GO_OFF`).
  841899's acts are as the puppeteer wrote them: its Acts step made again would put them right.
- Measured: the crushed frankincense goes home in the mortar and lies on its floor, none under the table; "lump 8" of the last
  section did not come back - all seven lumps ride their jar home. What lagged was the bake: from 100 s on it ran 2 to 4 times
  the show's pace, and the stage costs said why - the particle solver alone was 1 to 2.4 times the show's pace on some 130
  spheres that never slept (the jars' contents, woken as each jar was set down, and the pieces of the tears its stopper
  crushed); everything else a busy frame does is about half the show's pace (liquids 3 ms, solids, the swinging balance,
  the wake checks and the record 1 to 1.5 ms each). With all of the above, baked again: from 100 s on 0.8 to 1.4 times the
  show's pace (one stretch, the vial dipped, 2.1), 4 to 92 spheres awake where there had been 86 to 179 - 4 for the last 40 s,
  where there had been 135 - and the solver never
  full (118 places left at the fullest; it had filled at 170 s); `act` on `frankincense-in` says the sprinkle falls 6 cm from
  the mortar, and on each jar's put-away that its stopper came to rest 5 cm off, in its jar.

Open: a stopper dropped sideways into a full jar still works down through its contents to the floor, squeezing a few into
the glass (16 spheres awake): the let-go solve's mean is weak against many contacts at once; a held pestle laid down past its
mortar's rim (`pestle-down`) jumps 2 cm in a frame as it is pushed across the rim; the cost of a busy frame with nothing
awake, about half the show's pace.

### Played live with new acts (2026-10-30, 841899's Acts step made again): the ladle over the pot

The user: "the first time the ladle is picked-up, it misses the cauldron completely, and lands upside-down and past it,
backwards, clipping through the cauldron from the outside" - "that bug didn't exist until we recently regenerated the 'work'
step, with new code". The acts were sound (`ladle-to-pot`, a path with a quarter turn into the pot, checked "nothing passes
through anything"); all three causes were the bake's, and none shows in the puppeteer's rehearsal (one plan, its acts back to
back). Found on a copy, the ladle's planned pose against the bake's frame by frame (a scratch probe; the rehearsal, a gap
between the acts, a new plan mid-move):

- A NEW PLAN BEGAN A HELD MOVE AGAIN: `TablePhysics._take_plan` emptied `_held` (where each held move began) on every plan
  handed over, also when nothing it changed lay behind the bake and no checkpoint was restored. A live reading hands one over
  with each sentence's words; one that came half way through `ladle-to-pot` began it again from where the ladle was by then -
  its way and its quarter turn taken twice: up to 33 cm, out past the pot's far wall, turned past upright. Before `RigidParts`
  only a loose thing's carry went through `_held`, so a tool never showed it. Now `_held` is kept: what the plan changed lies
  past the bake, or a checkpoint is restored with its own. Gate: physics_check `_moved_on`.
- WHAT A BODY WAS NOT LOOKED AT AGAINST DID NOT COUNT: `RigidParts`' clearance (it skips its contacts until it has gone as
  far as it was clear) was taken over the solids near its box and the table's top only - the ladle high over the bench was
  "clear" by its 18.5 cm over the table, and let go in the pot fell through its floor and the brazier to the table. A solid
  not looked at now bounds it too, by the gap between their boxes less a frame's most movement (`RigidParts._near`'s `far`).
  Gate: physics_check `_let_go_in`.
- HELD UP BETWEEN ITS MOVES, IN THE BAKE TOO: the work holds a thing a move left touching nothing until its next move
  (`TableWork._held_up`), and so did the rehearsal - but the bake let a rigid part go a quarter second after its move. Live,
  the words before `stir-the-base` ran longer than its rehearsal, and the ladle fell into the pot. Now the hand holds it where
  the move left it, swaying as the work sways it, until the next move takes it (`TablePhysics._held_aloft`, `RigidParts.touching`
  asked once as the move ends); what rests on or against something, or what no move takes up again, is still let go
  (`_tool_falls`). Gate: physics_check `_held_between`.

Measured on the copy with all three: the ladle into the pot within a millimeter of its plan, held there through a 1.5 s gap,
stirred round inside it - with or without a new plan at 12 s. Still open: a let-go body landing on a thin wall stands 1-2 mm
in it and, heavy and leaning, works down through it (the ladle let go in the pot sank 2 cm through a 3 mm copper floor in
half a second) - the let-go solve's mean, above (done in the next section); and the act's check still reads the acts' own
poses on the rehearsal, so what only a live reading's timing does is the gates' to hold.

### Clipping, everywhere (2026-10-30, 841899 replayed with the above)

The user: "So much clipping, everywhere, constantly. We must be doing something wrong"; the mortar tipped into the cauldron
"clips right through the cauldron. Again: why do we not have collision physics ... why can we not just add collision to most
if not all objects, so that they naturally respect physical boundaries?"; and at about 3:00, as the pestle went back into the
mortar, "a ring of crushed tears appears on the table, and float over to the cauldron".

Why it kept happening - one cause per class of clip, each found on a copy:

- A WHOLE THING HAD NO COLLISION AT ALL. `RigidParts` made bodies of the free parts an act moves (a pestle, a ladle, a cork);
  a whole thing an act moves (the mortar with its pestle, a jar, the balance, a crate) was still the acts' own pose - through
  anything. The only guard was `act`'s check (`TableWork.check`): a few hundred of the mover's mesh corners, 25 moments of the
  act, a ray's parity against the still meshes, one way only. A 4 mm rim going into a mortar between its corners is never
  seen: `tip-resin-in` was told "Nothing passes through anything". NOW EVERY THING AN ACT MOVES IS A BODY (`_make_rigid`: its
  own solids and those of every part that moves only as it does, keyed -1 less its number, `_ch_of`); the twin has it where the
  bake has it (`TableWork.posed_things`, `_thing_world`), so its hinged parts, contents and liquids go where it really is, and
  the picture draws it there (`tick`, `thing_pose_of`). `act` now says what held a hand back and how far short
  (`report`'s HELD BACK, from each frame's `rd`/`rt` - the same collision the picture is drawn with): `tip-resin-in` "HELD BACK
  by the copper cauldron on its brazier's cauldron - it stopped 3.8 cm short of where the act takes it, 4.2 s in".
- A HELD THING WAS HELD BACK BY WHAT IT CARRIES: the mortar carried with its pestle lying in it was shoved by the pestle, left
  on the table and tipped over; a balance's base by its own beam. A body now meets only what weighs more than it (and, held,
  not what is held too - `RigidParts._near`), held or let go: lighter ones it pushes aside or carries (let go, the pestle leaning
  in the mortar had crept it across the table and kept it awake); what hangs from it (each solid's `bodies`) it never meets; a
  rider is not woken by its carrier's own solids (`_asleep_frame`).
- A MOVED THING WAS DRAWN BEFORE THE BAKE WAS: `TableWork.tick` set the things' nodes before it baked to the moment, so a thing
  that is a body was drawn a frame late in a render, and from the plan on a jump in time. The bake goes first.
- THIN WALLS: a contact is a push along the field's way out, and past a thin wall's middle that way is through its far side.
  So a point coming into a still wall keeps the FACE it came in by (`RigidParts` body `faces`: a plane, kept while it is in the
  wall and, out of it, only within `FACE_REACH` of where it came in - out the far side; a cup's foot that grazed a rim had
  been held up by the rim's plane), a held body's contacts are measured again against it (`_depth_now`), and a let-go body is
  put out along the deepest after its mean, as the table's top already was. A particle's centre is never left inside a still
  solid it was outside (`Particles._solid_pass`). The ladle let go in a pot with a 3 mm floor now lies on the floor, where it had
  sunk through it.
- THE ACT'S REPORT MISINFORMED THE PUPPETEER: a broken thing was placed by the body it was before it broke - "frankincense
  tears 1: now on the table - BROKEN" while all 63 pieces lay in the cauldron; now where its pieces are. And a vessel's tip was
  read off the twin, which has a body only where the bake is now (a flask tipped and set back "never tipped": `_solid_at`).
- A BAKE BEGUN AGAIN FROM A CHECKPOINT was not the bake from the start: a body's `stir`, `was_moved` and its solids' last frames
  (`_body_solids`) were not kept, and a jar of snow taken up mid-carry spilled its grains 30 cm from where a bake from the start
  put them. Live, every new plan restores a checkpoint, so this was a source of live-only differences.

The ring of crushed tears was not reproduced: baked on the rehearsal, on the live words' timing (a sentence at a time, bake on
the caller's thread) and with the bake kept 20 s ahead as the app's thread keeps it, all 63 pieces pour into the cauldron at the
tip and lie on its floor. What is different in the app is its real voice timing; a feedback capture (`) at the moment would
give its time and frame.

Gates (physics_check): `_thing_meets` (a crate driven into a block stops at it, and is said HELD BACK; the control, the work's
own crate, is in it), `_thin_walls` (a brass ladle stirred over powder on a 3 mm floor and let go in the pot never goes through
the floor - on the code before, 3.9 cm, through it; the control, the powder moves). Benches put right where they had moved
through things: the knife is laid down after its chop (let go in the air it fell through its carrot and cut it again), the cup
is dipped over the bowl's rim and straight down (carried in an arc its side went through the rim), its pour read while held;
table_work_live_check's jar is lifted over the cauldron's rim and set down after its pour (it had gone through the rim, and
been let go over the brew); table_work_check's jar held up has a next move (after its last, a thing in the air is let go and
falls - the work's `_held_up` had held it forever, `_tool_falls` let it fall: one rule now, the puppeteer told it).

On 841899 (a copy, the rehearsal): `tip-resin-in` HELD BACK 3.8 cm by the cauldron, every crushed piece in the brew to the end
of the stir; `balance-to-middle` HELD BACK 2.1 cm by the recipe tin; `pestle-home` 1.3 cm by the table. The bake's cost, a quiet
machine, 10 s at a time over the first 100 s: 0.52 to 0.96 of the show's pace (it had been 0.56 to 0.77 over 10-40 s).

Open: the particle guard is not yet shown by a gate (the stirred powder never went through the floor on the old code either);
a body meets things by 120 points of its surface, and between them its surface may dip into a wall (never through one, in the
gates); `act`'s own ray check of the plan still runs beside the bake's HELD BACK, and on a table reused for several checks (a
probe, never the app, which stands one a call) it said `stir-resin` went through the table's top - not looked into.

### The live viewer is not the export (2026-10-30 night, 841899 played live, feedback 0009-0016)

The user left eight captures from one live play: the mortar sliding on the table "even when the video is paused" (0009, 3:04),
the mortar through the cauldron and missing the pour (0010), the ladle through the cauldron (0011), the brew in the brazier's
pan under the cauldron (0012), the ladle "floating in circles ... not just wiggle it around in the air" (0013), the phoenix
feather under the cauldron (0014), the brew gone as the ladle went in (0015), the ladle dropped through a vial (0016) - and "at
least some of this might be related to differences in the real-time viewer versus what you're getting in exports". So it was:
the whole show baked once with every act placed, as an export bakes it, has the brew in the cauldron at ~955 ml to the end,
nothing in the pan, the feather in the brew, the mortar held back at the rim and the resin poured in. What the live viewer adds:

- IT DREW A PLAN IT HAD DROPPED: a new plan (each sentence's words) sends the bake back to the checkpoint before what it changed,
  and every frame past it stayed - drawn as the new plan's, and counted as baked (`baked_to`), so neither the viewer's fallback
  nor the log's "behind the show" ever came. What was baked past the change is dropped now (`_take_plan`; physics_check
  `_plan_drops_stale`).
- A HAND LET GO WHAT AN EXPORT HOLDS: a part left in the air was held only if its next move was already placed, and live a move
  is placed when its word is heard - the ladle stood down into its pot was let go before the stir's words came, and fell. A later
  act is now looked for among the acts themselves (`_moved_after`, `_play_rank`; physics_check `_held_till_placed`).
- IT FELL BEHIND: the log has the bake behind from 260.8 s to the capture at 303 - the grind. Live, the picture then shows the
  last frame baked (and as it catches up, paused or not, things slide to where they are) or, for what an act moves, the act's
  own pose - through anything. The grind bakes at 1.14 of the show's pace on a quiet machine (particles 6.0 s of 10, rigid
  bodies 1.7, liquids 1.3); live it shares the machine with the voice and the picture. NOW THE VIEWER WAITS (the user's choice,
  "do #1"): from when the bake is less than `WAIT_UNDER` ahead of the show until it is `WAIT_AHEAD` (3 s) ahead again, the show's
  time is held (`TablePhysics.behind` -> `ShowFeed.wait_for` -> `Spectrum.set_waiting`: the player and the bookends stopped as for
  a pause, but not a pause - the transport still plays, its time saying "catching up", and a pause taken meanwhile outlasts the
  wait). Never in a render, a preview or a gate, which bake on the caller's thread. Gates: physics_check `_waits_for_bake`,
  transport_check. First measured, it waited 302 s of a 460 s show: a stir runs as long as its words leave it, each sentence
  moved its end, and the bake went back to where it began. A NEW PLAN IS NOW BAKED AGAIN FROM ITS FIRST CHANGE the bake can see
  (`replan`, `_changed_from`: the channels it reads, entry by entry; a move that goes by its time alone, ending elsewhere, from
  the sooner end - physics_check `_replan_from_change`): 3 waits, 5.9 s in all, the longest 3.2 s (a probe in real time, the
  bake on its own thread, without the voice or a full-size picture sharing the machine). Open still: a faster bake.
- THE MORTAR SLID (0009, in any bake): woken by its pestle grinding in it, and held up by the frankincense it was grinding (a
  loose thing under a body holds it up), it was shoved about - 3.2 mm in the gate's grind. What rests in or on a body, and a
  lighter thing in a hand, never moves it or wakes it (`RigidParts._yields_to`); a falling body meets everything else (a ladle
  had passed through a vial lighter than it). Gate: table_work_check `_at_the_spot` (the mortar still while ground in; 3.2 mm
  before).

Benches put right again: table_work_check's pestle laid down after its grind is lifted out of the bowl first (carried straight
off it went through the rim). Not gated: a falling body meeting a lighter one (a bench of a rod over a vial passed either way).

## Risks

- **Cost.** A few hundred awake particles at 240 Hz in GDScript are milliseconds a frame of simulated time; on a thread
  of its own that is several times real time, but a busy moment can still outrun it live (a frame stands; a render
  waits). The particle count is capped (`Particles.MOST`), and what rests costs nothing.
- **Agents.** A set dresser that does not mark a dish's stones loose gets a dish whose stones stay put (a heap's copies
  are loose by default for this reason). A puppeteer that does not tip far enough pours nothing - `act` says so, with the
  angle needed.
- **Tunnelling.** A fast particle could pass a thin wall in one substep; a move longer than its radius is taken in pieces.
- **Old episodes** play with the physics: their `pour` tracks are dropped (said in the notes), and what they tipped pours
  for real or not at all.

## Sources

- Muller, Heidelberger, Hennix and Ratcliff, "Position Based Dynamics" (VRIPHYS 2006 / JVCIR 2007)
- Macklin, Muller, Chentanez and Kim, "Unified Particle Physics for Real-Time Applications" (SIGGRAPH 2014)
- Muller, Heidelberger, Teschner and Gross, "Meshless Deformations Based on Shape Matching" (SIGGRAPH 2005)
- Macklin, Storey, Lu, Terdiman, Chentanez, Jeschke and Muller, "Small Steps in Physics Simulation" (SCA 2019)
- Macklin and Muller, "Position Based Fluids" (SIGGRAPH 2013) - weighed, not taken
- Muller, "Fast Water Simulation for Games Using Height Fields" (GDC 2008)
- Lamb, "Hydrodynamics" (6th ed., 1932), on capillary-gravity waves: the slowest ripple on water, 0.23 m/s at 1.7 cm
- van den Doel, Kry and Pai, "FoleyAutomatic: Physically-based Sound Effects for Interactive Simulation and Animation"
  (SIGGRAPH 2001)
- Muller, Macklin, Chentanez, Jeschke and Kim, "Detailed Rigid Body Simulation with Extended Position Based Dynamics"
  (SCA 2020)
- Ibrahim, "Liquid Sloshing Dynamics: Theory and Applications" (Cambridge, 2005)
- Mayer and Krechetnikov, "Walking with coffee: Why does it spill?" (Physical Review E, 2012)
- Potyondy and Cundall, "A bonded-particle model for rock" (Int. J. Rock Mech. Min. Sci., 2004)
- Flash and Hogan, "The coordination of arm movements: an experimentally confirmed mathematical model" (J. Neurosci., 1985)
- Morasso, "Spatial control of arm movements" (Exp. Brain Res., 1981)
- MacKenzie, Marteniuk, Dugas, Liske and Eickmeier, "Three-dimensional movement trajectories in Fitts' task" (Q. J. Exp.
  Psychol., 1987)

## The ghost of the ladle's bowl (2026-10-30 night, feedback 0017-0020)

"The cork in front of the scales is spinning in circles, matching the ladle" - then "the lid on the jar behind the box".
No part moved (the captures' new `table` report, `TableWork.drawn_report`: only the ladle and a watch hand were off where
they first stood). It was the ladle's own INSIDE, drawn in the wrong place: an empty vessel's inside mesh is made as it is
first filled (`_make_inside_node`), and `_inside_mesh` and `_cavity_uniforms` measured the mesh as it stood against the
vessel as built - right for an inside made at the build, but the ladle first fills in its pot, so its inside was built and
drawn the whole way from its rest off, riding the ladle round every stir. Now measured through the node the vessel hangs
from (`TablePhysics._mesh_in_vessel`). Gate: physics_check `_dip` (the cup's inside drawn in the cup; the control, measured
as built, centimeters off). Also: a contact from the side no longer holds a body up (`RigidParts.HELD_UP` on `touch`; what
held a hand back is `by`), gate `_held_up_from_below`.

## Corks and lids (2026-10-30 night, feedback 0021 and the brimstone's cork)

"When the frankincense jar was moved here, the lid fell into the jar, and now it cannot escape"; later the brimstone's cork
"turned sideways and got stuck in the jar as well" - one class: A PART AND ITS SEAT. Fixed: tracks of one act that make the
same move share one hand and the second RIDES the first (`TableWork.build` `_with`, `_pose`'s `_lead`; the bake rides the
leader's re-based move, `_held_pose`) - each had swayed its own way about its own pivot and the cork wandered through the
neck; two held bodies meet (a lighter one in a hand yields, `RigidParts._yields_to`); a lighter thing in a hand never holds a
heavier one up (`_may_hold`: the jar, set down as its cork was taken up, slept on the cork and went up with it); and EACH PART
HAS A SEAT, what of its thing it was built touching (`_add_body`): eased in or out by a hand within `SEAT_REACH` it never meets
it, and let go within `SEAT_NEAR`/`SEAT_TILT` it sits as built (`TablePhysics._seat`) - the solver's points are coarser than a
cork's fit. On 841899 the frankincense and sulfur corks go back to 0.0 mm. Gates: physics_check `_carried_with`, `_put_back_in`.
OPEN: the hearth ash lid ends ash-away 56 mm off its crock, still moving a second after (the user saw ash on the lid - ash on
the rim holding it up would be right; not yet traced, the probe was stopped).
