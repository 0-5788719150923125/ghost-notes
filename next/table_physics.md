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
- Ibrahim, "Liquid Sloshing Dynamics: Theory and Applications" (Cambridge, 2005)
- Mayer and Krechetnikov, "Walking with coffee: Why does it spill?" (Physical Review E, 2012)
- Potyondy and Cundall, "A bonded-particle model for rock" (Int. J. Rock Mech. Min. Sci., 2004)
- Flash and Hogan, "The coordination of arm movements: an experimentally confirmed mathematical model" (J. Neurosci., 1985)
- Morasso, "Spatial control of arm movements" (Exp. Brain Res., 1981)
- MacKenzie, Marteniuk, Dugas, Liske and Eickmeier, "Three-dimensional movement trajectories in Fitts' task" (Q. J. Exp.
  Psychol., 1987)
