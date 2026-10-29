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
- Ibrahim, "Liquid Sloshing Dynamics: Theory and Applications" (Cambridge, 2005)
- Mayer and Krechetnikov, "Walking with coffee: Why does it spill?" (Physical Review E, 2012)
- Potyondy and Cundall, "A bonded-particle model for rock" (Int. J. Rock Mech. Min. Sci., 2004)
- Flash and Hogan, "The coordination of arm movements: an experimentally confirmed mathematical model" (J. Neurosci., 1985)
- Morasso, "Spatial control of arm movements" (Exp. Brain Res., 1981)
- MacKenzie, Marteniuk, Dugas, Liske and Eickmeier, "Three-dimensional movement trajectories in Fitts' task" (Q. J. Exp.
  Psychol., 1987)
