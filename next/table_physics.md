# What is in things: liquids, grains, loose things, and the hand that moves them

Independent objects, action order, vessel entry transitions and measured rendering cost: [table_playback_investigation.md](table_playback_investigation.md). It supersedes the two-at-a-time collection fallback described below. The framework audit is [framework_audit.md](framework_audit.md).

Origin: the first alchemy episode showed that liquids were textures with no fluid dynamics, vials held no snow, a tipped dish's crystals stayed attached to it, moves were straight eased lines, and a mortar's contents "poofed". Containers, grains, loose things and hands needed real behavior, and agents had to be told how to write for it.

## What was found

- **A liquid was a solid lathe with a wet shader** (`prop.gdshader` kind 13). `fill` scales the mesh from its base in the vessel's own frame (`TableWork._pose_work`), so a tipped vial's liquid tips with it.
- **Nothing was loose.** A shell's lodestone, quartz and amber were parts of the shell (`Props` leaves); a heap's copies were laid once at build and never moved.
- **There were no grains.** Snow, salt, powder and seeds had no form that could be poured.
- **A move was a straight line, eased** (`TableWork._pose`: `carry` a cubic ease between two places with a sine lift; `path` keys joined straight with Steffen's slopes). Nothing leaned, bowed or wavered. Cards were handled better: each held card sways on seeded sines (`TableCardPose._present_xf`).
- **The mortar's powder** was a ball whose `grow` the puppeteer drove; nothing was in the bowl to be ground.
- **Godot's physics cannot be used here**: `PhysicsServer3D` has no way to step a space by hand (checked in 4.7.2), so it runs only in real time on the main loop - never faster, never on the worker thread a table is built on, never as a function of show time. The table's own rule holds (next/table_work.md: "The checker uses no physics server").
- **GDScript's speed** (measured): a particle's integration and a collision with a lathe 0.37 us; a contact pass through a Dictionary hash 11 us a particle. A few hundred particles stepped at 240 Hz cost a few milliseconds a frame of simulated time - enough for a vial of snow and a handful of crystals, if what is at rest costs nothing.

## The design

### Everything that settles is BAKED, and played as a function of time

The table is a pure function of show time (a render, a scrub and a tool's picture of one moment agree). A simulation is stepped, so it is baked: stepped once over the show's timeline from the schedule (`TableWork.runs`), kept as frames, and played by looking up the moment. A live reading changes the schedule only where nothing has begun (`_begun`), so a replan re-bakes from the first act it moved, from the last kept checkpoint before it. A render waits for the bake to reach each frame it draws; a live picture never waits (at worst a frame of grains stands a moment). A set dresser's or puppeteer's preview bakes on a worker, the app's thread waiting a frame at a time, as far as the moment it pictures; a table stood again over the same table takes up the last one's bake at the checkpoint before the first moment their plans differ, channel by channel (`TablePhysics.carry`, `adopt`).

What is at rest costs nothing: a grain, a body or a liquid that has settled sleeps on its host - the part it lies in - and rides it, its place kept in the host's own frame (Macklin et al. 2014, section 7: sleeping). It wakes when its host tips past a few degrees or jolts, when anything else moving comes near it, or when something awake strikes it.

The bake runs on a thread of its own in the app and the render, with a twin of the work's kinematics (`TableWork`'s evaluation over the same data, its own recursion depth, nothing that touches a node): the schedule is handed to it, never shared while it changes.

### 1. Liquids: a free surface in a vessel's cavity

Particle liquids (Position Based Fluids, Macklin and Muller 2013) need thousands of particles and a surface rebuilt every frame - more than GDScript can afford, and the surface is what is seen. A liquid on a table is a bulk that keeps its volume, whose surface is level, and which moves in a few ways that read: the heightfield-plus-particles split games use (Muller, "Fast Water Simulation for Games Using Height Fields", GDC 2008) - the bulk as a surface, what leaves it as particles.

- **The cavity** (`Vessel`): the inside of a hollow lathe (its profile's inner wall, curved exactly as `Props._lathe` curves it) or a walled extrude (its outline less the wall), as a table of the radius at each height (and at each bearing, for an outline), its rim, and a few thousand equal-volume points filling it. A liquid part is in the hollow part of its thing whose cavity holds its middle; its own mesh is rebuilt as the whole cavity, and drawn clipped by its surface.
- **Its surface is level** in the table's space, wherever the vessel is turned: the plane that leaves the liquid's volume under it, from a table of levels by tilt and fill made once from the points. A tipped vial's liquid runs to its lip.
- **It pours when it reaches the lip** - and only then - over the part of the rim it stands above, as a weir does: Q = (2/3) Cd sqrt(2g) * the integral of the head^(3/2) along that rim (Cd 0.62), leaving at the speed of critical flow over a crest. The tip decides how much flows and when. A stoppered vessel pours nothing.
- **The stream** is what left, in parcels: each frame's outflow leaves the lip as the vessel holds it then, and falls under gravity until it meets a liquid's surface (it adds to it), a solid (spilled) or nothing. Drawn as a tube through the parcels, as thick as the flow (r = sqrt(Q / (pi v))).
- **It sloshes**: its surface's tilt is a damped oscillator driven by the vessel's acceleration, at the first sloshing mode of an upright cylinder of the surface's radius and the liquid's depth, w0^2 = (g xi / R) tanh(xi h / R), xi = 1.8412 (Ibrahim, Liquid Sloshing Dynamics, 2005); a carried cup's coffee rocks at a few hertz (Mayer and Krechetnikov, "Walking with coffee", 2012).
- **It turns when stirred**: a tool moving through it drives its swirl, which dies away over seconds; floating and sunk things are carried round by it, and its foam turns with it.
- **It ripples and splashes**: whatever enters it rings its surface (rings running out at a ripple's speed, dying as they go) and, hard enough, throws droplets that fall back.
- Drawn by `prop_liquid.gdshader`: the cavity's mesh, everything above the surface cut away, and where the cut is seen through, the surface itself at its true depth (written to `DEPTH`, lit at `LIGHT_VERTEX`), with the wet look (ripples, bubbles as it boils, foam, glow) on the surface. The surface is drawn only where the eye's crossing lies inside the cavity (`Vessel.shader_tables`, the shader's `in_cavity`), or the cauldron reads as a glass tank. A liquid as clear as 0.5 (water) is drawn seen through by the same body (`prop_liquid_clear.gdshader`, `CLEAR` in `prop_liquid.gdshaderinc`), under its glass, and less as what is rinsed into it clouds it (`murk`; next/painted_surface.md); a brew, ink or wine keeps the opaque body.

### 2. Grains and loose things: one particle solver

Position based dynamics (Muller et al. 2007), as the unified particle solver does it (Macklin, Muller, Chentanez and Kim, SIGGRAPH 2014): everything is spheres; granular matter is spheres with friction; a rigid thing is a cluster of spheres held to its shape by shape matching (Muller et al., "Meshless Deformations Based on Shape Matching", SIGGRAPH 2005); one iteration a substep, more substeps rather than iterations (Macklin et al., "Small Steps in Physics Simulation", SCA 2019).

- **Grains** (shape `grains`): sand, salt, snow, sugar, seeds, ash, powder, beads - laid into the cavity of the vessel they are drawn in, up to their `fill`, as a jittered packing already at rest. Each particle is drawn as a small lump of its material (a clump, for powder finer than a particle can be).
- **Loose things** (`loose` on any part): not fixed to its thing. Each copy is a body of a few spheres filling its shape, drawn with its own mesh, posed by the body. A heap's or a scatter's copies are loose unless written otherwise. Held by an act (carried, tipped), it goes where the act has it, from where it really is; let go, it falls as it was moving.
- **Collisions**: every other part of every thing is a solid with a signed distance in its own space (`ShapeField`): exact for a lathe (a 2D field of its curved profile, by radius and height) and an extrude (its outline's 2D field, floor and wall), closed forms for a box, a ball, a ring, a tube's segments and a crystal; a box round anything else. A solid moves as its thing or part moves; a particle meeting it is pushed out with friction against its motion.
- **In a liquid** a particle is slowed, lifted by what it displaces (it floats if lighter), carried by the swirl, and - if its material dissolves (snow, salt, sugar, powder: `dissolves`, seconds) - shrinks away; it rings the surface as it enters.
- **Grinding breaks**: a particle squeezed between a moving solid (a pestle pressed into the bowl) and what holds it is damaged; past its material's strength a body splits along its middle, its halves still rigid, and a lone particle into two of half its volume, down to powder - a bonded-particle model's bonds breaking under load (Potyondy and Cundall, 2004), in its simplest form. Metal, glass, wood and cloth never break. A body's first break hides its mesh and shows its pieces as chunks of its material.
- **What a material is, as matter** (`TablePhysics.MATTER`, a row a material class): its density, its strength, how fast it dissolves; a set dresser's material may say `dissolves` itself.

### 3. The hand: how a held thing moves

From the motor-control literature, each with a seeded share for every move (`Hands`), so no two moves are alike and every move is a function of its act:

- **Minimum jerk** in time (Flash and Hogan, 1985), skewed so it slows longer into a careful placing than out of the pick-up (MacKenzie et al., 1987).
- **A path that bows**: point-to-point hand paths are gently curved (Morasso, 1981) - a seeded bow to one side, a few hundredths of the distance at most, nothing at the ends; a lift that rises early and comes down late.
- **A held thing lags its hand**: tilted as a pendulum from its grip by the hand's acceleration - back as it sets off, forward as it stops - which also sets a carried liquid sloshing.
- **A held thing is never still**: a slow drift and a smaller quicker waver while it is off the table, none where it rests.
- **Stirring and grinding vary**: each round a little longer or shorter, its radius breathing, its middle wandering a millimeter or two.

### What the agents are told

- **The set dresser** (`Props.describe`, `Motions.describe_parts`, `rules/table/set_dresser.yaml`): a vessel's contents are what they are - a liquid part, `grains` for anything poured as stuff, `loose` for things that lie in or on something - and they pour, tumble and break for real. Each ingredient goes in the vessel it will come out of, with a stopper on what stays shut. What cannot be brought to the work's spot is worked where it stands and stands beside the spot, whole in view; what is needed only for a while may wait out of the shot, past the frame's sides.
- **The puppeteer** (`Motions.describe_laws`, `rules/table/puppeteer.yaml`, `act`'s replies): a vessel tipped far enough pours by itself; tip it over what catches it, hold it while it should flow, tip it back. `sprinkle` lets a little of something fall from a point; a sprinkle naming a thing the act moves must fall within 3 cm of it (`PINCH_NEAR`), and a pinch is never a pour. A pestle pressed into loose things and moved crushes them. A dip fills, and nothing is filled by magic what a pour fills. `act` answers with what the physics did: what left what, when, how much, where it landed, what sank, floated, dissolved or broke; for a tip that poured nothing, the angle its liquid needs; what held a hand back and how far short; where a broken thing's pieces are.

## The plan, in order

### 1. The hand

`table/hands.gd` (`Hands`); `carry`, `path`, a tool's way in (`BLEND_IN`), `circle` and `aim` through it. Gate: `tests/table/hands_check.gd` - a carry ends exactly where it was sent and starts where it was, its speed is continuous, its middle bows off the straight line (control: the straight line), its lift never goes below either end, a held thing leans with the hand's acceleration, nothing held is ever still, and the same act gives the same move every time.

*Status: built.* `Hands` (`timing`, `carried`, `bow`, `lean`, `drift`, `held`, `round_of`); `carry` and `path` (`TableWork._pose`, `_path_at`), a tool's way in (`BLEND_IN`, `blend_lift`) and every `circle` and `aim` (`Motions.point_at`, a track's `_hand` seed: `hash(episode seed, act, track)`). `Motions.eased`, the cubic every move was eased by, stepped its acceleration from +12 to -12 at the middle of every move; it is minimum jerk now. `table_work_check`'s controls take the hand's drift (`Hands.drift_most`) and its early lift (`LIFT_SHAPE`).

### 2. Solids, cavities and the solver

`table/shape_field.gd` (`ShapeField`), `table/vessel.gd` (`Vessel`), `table/particles.gd` (`Particles`). Gate: `tests/table/physics_check.gd` - a lathe's field against points known inside, outside and on it; a cavity's volume against its profile's; a level that stays level and keeps its volume as a vial tips; a weir that pours only past the lip (control: upright, nothing); grains that rest in an upright vial and run out of a tipped one; a body that slides out of a tipped dish and none from a level one; a ground body that breaks (control: not pressed, whole); the same bake twice, frame for frame.

*Status: built.* `ShapeField` (a lathe's and an extrude's 2D field in a narrow band, closed forms for the rest), `Vessel` (radius by height, equal-volume points, the level table by tilt or by tilt and bearing, the weir, the inside as a part to draw), `Particles` (PBD with friction, shape matching, sleeping on a host, riding a moving inside, breaking under a moving solid, dissolving, floating). Traps measured, each now in the code where it bites:

- A packed array in a list is a copy: `Particles.add` must grow its arrays.
- An 8-cell neighbor search needs cells twice the widest pair.
- Contacts rebuilt every substep through 27 cells and a Dictionary per pair cost 50 us a grain a substep: a Verlet pair list once a frame, with a margin as wide as the fastest can close in it, and every per-grain property in a packed array, made it about 8 (`Particles._find_pairs`).
- What is in a moving inside rides it (`_ride`; only how it moves in it is reckoned): sleepers start each frame where their host began it and are carried with it through the substeps, solids have the last word in a substep, two overlapping grains part at most `PART_MOST` a second, and a move is looked along in steps of half a thin wall (`THIN`).
- One pass of the constraints leaves a heap trembling: a held-up, slow grain loses some of its speed (`SETTLE`).

### 3. On the table

`Props`: `grains`, `loose`, the `powder` class (prop.gdshader kind 14), each class's `density`, `strength` and `dissolves`, `lathe_profile` shared with the fields, every solid reported with its place; a liquid's mesh rebuilt as its cavity. `table/table_physics.gd` (`TablePhysics`, a part of `TableWork`): what is physical on a table, the bake, its thread and twin, the playback (grains and chunks drawn instanced, bodies posed, liquids' surfaces, streams, splashes), the report. `TableWork`: `sprinkle`, loose parts posed by the physics (`pose_of`, drawn as pieces once broken, `whole`), a liquid the physics keeps never scaled (`liquid_volume`), `_world_rest_thing` and `_work_world` reading no node once built, the materials handed in by `TableMedium` (`_work.materials`). Gates: `physics_check` on a stood table (a vial of snow tipped over a bowl fills it; a dish's stones tumble into a cauldron of brew; a mortar's crystal ground to powder; a scrub against a play), `table_work_check`, `table_work_live_check`.

*Status: built.* The bake runs on a thread of its own in the app, on the caller's in a render, a preview and a gate (`render_waits`, `aside`, outside the tree); checkpoints every second, a new plan baked again from the last before the first act it moved (`replan`, `_take_plan`); quiet stretches skipped without reckoning a solid (`_may_move`); every frame carries all the picture draws (streams, rings, drops), so the picture never reads what the bake is writing.

### 4. The agents

The rules and the describers above; `PuppeteerTools`' `act` reply (`TablePhysics.report`). Gates: `rules_check` (prompts whole, no kind of work named), `work_steps_check`.

*Status: built.* `Props.describe` (`loose`, `density`, `dissolves`), `Motions.describe_parts`, `Motions.describe_laws`, `rules/table/puppeteer.yaml`, `rules/table/set_dresser.yaml`.

### Seen

`tests/table/physics_look_probe.gd` (a cauldron of brew, a jar of snow, a shell of three stones, a mortar with a crystal; compatibility on the CPU and Forward+ on the GPU): snow runs out of a tipped jar as grains, falls in a stream and floats on the brew; stones go in and rings spread where they did; the pestle goes round in the mortar. The probe's camera crops its bench's corner.

What measuring and playing the app fixed, as the code now behaves:

- A packed array held in a Dictionary is the array itself: each baked frame keeps copies of its own, shared with the frame before when the solver moved nothing (`Particles.moved`); `physics_check` `_threaded` holds the bake on a thread against the bake on the caller's. A sprinkle's grains are a grains part of their own; a thing with no surface is known to have none (`TableWork._mesh_of`).
- The work and the physics hold each other weakly (`TablePhysics.work`), because two RefCounted that hold each other are never freed and every table the set dresser and puppeteer stood was kept; `physics_check` `_let_go` frees a table and finds both gone.
- Every `act` used to stand a fresh table and bake from frame 0. Now: one table a call (`TablePreview.work_checks`), the bake carried from the last table as far as the plans agree (restored solids and held things exactly as a bake from the start has them - `physics_check` `_carried`, to the bit), checkpoints spread over the whole bake (`CHECKS_NEAR` dense, the older thinned), every picture rehearsed from one start (`TableWork.REHEARSAL`), and the bake on a worker that the tools' closing halts (puppeteer_tools_check).
- **A heap at rest sleeps whole** (`Particles._settle`: grains of one part slower than `SLEEP_SPEED` on the whole, none past `TREMBLE`, sleep together once most have been still `SLEEP_AFTER`). Where a live show outruns its bake, a loose thing the work has held since the last frame baked is where the work has it (`TableWork._outran`), and the log says when what is in things is behind and when it caught up.
- **A splash is one thing's, as it first goes in**: a drop for every 2 g of it, entering faster than 0.5 m/s, thrown up at 0.35 of its speed, a grain as heavy as it is drawn (`TablePhysics._events`).
- **A dip fills**: a vessel under a liquid's surface fills over its rim as a weir does until it stands as high inside as out (`TablePhysics._dips`), and a liquid's color follows the work's tint.
- A sheet of paper is written on by the work (`write`, below).

Gates: physics_check `_heap_sleeps`, `_splash`, `_dip`, `_let_fall`, each failing with its fix broken.

### Built the same day: words written, the work heard, a blade that cuts

**Words are written** (`Motions.LAWS` `write`, state `written`; `SheetWriting`): a sheet part (`Props.sheet_top` keeps its top surface on its work) is written on by the work - `{"law": "write", "text", "hand", "ink", "between"}` - in one of the recipe card's hands (`CardTable.HANDS`: neat, quick, print), drawn on the processor from the font's own glyphs into a picture (red the ink, green when each point is put down, line by line) on a thin skin over the sheet's bend and fold, shown as far as the pen has got (`shaders/sheet_writing.gdshader`). Nothing on a table is set written; the puppeteer writes only what the script or a card says, at the work's spot. A recipe card is its writing: a written card has no picture - none painted, none checked, nothing waits on one (`TableEpisode.written_card`), its title across its width; the designer writes its writing alone, and the reader meets it as its writing (`on_card`). Gates: table_work_check `_write`, written_card_check.

**The work is heard** (`WorkSounds`, owned by the table on the stage, played as its picture is drawn - live, and in a render, whose Movie Maker records the engine's sound): a thing set down (`TableWork.set_down`: its mass from its box and material) thumps the table and rings as its material does; a point pressed onto something (`TableWork.pressed`) grits only while it touches, as fast as it moves; a liquid at a `boil` bubbles, steam alone is silent; a pour's landing trickles. The sounds sit well under the voice (about 0.06 RMS): an iron pot set down peaks 0.045, a glass jar 0.0077, a paper slip nothing; grinding about 0.0034 RMS; a boil's bubbles 0.0085. Each piece the physics breaks off crunches (`TablePhysics.breaks_in`). A pause holds it: the show's time unmoved two ticks, the player is held (`WorkSounds.tick`). Gate: work_sounds_check (silent before a landing, while lifted, before the boil, a held thing never).

**Grinding is a scrape** (`WorkSounds`; van den Doel, Kry and Pai's FoleyAutomatic): the surface under the point read at the speed it slides (its finest grain at speed / 0.2 mm), its bumps roughening it at random, the point catching on grit, and all of it ringing what is ground in - its body low, the bigger the lower, its material's modes damped by the hand. The middle of its spectrum is 560 Hz where static-like grit was 4.7 kHz, its loudness in 20 ms pieces varying by 0.45 of itself. Gate: work_sounds_check (low and rough, and steady noise at 2.2 kHz neither, the control).

**A blade cuts** (a part's `edge`; `Particles._cut_through`, `TablePhysics._cut`, `MeshCut`): a moving blade come down into a loose thing of soft matter (`TablePhysics.CUTS`: plant, wax, paper, leather, fabric) parts its spheres along its own plane into two rigid bodies, set off the blade by its width (`PARTED`), and each piece is drawn as the thing's own mesh kept behind every cut it has had, each cut faced in a lighter color. Soft matter passes through a blade rather than being shoved by it; a board carried does not count as squeezing what lies on it (`CARRIED`: a solid under a thing carries it); a body is filled to its box's faces, a sphere down its middle where it narrows (`fill_shape`, `BODY_MOST` 36), and held up as a whole (`_settle`'s `borne`), or a body in layers never sleeps. Gate: physics_check `_cut` (three pieces, apart, the act saying so; the knife short, and a stone, cut nothing).

Open: the tip of a tapered thing rests 2-3 mm high on its 7 mm spheres; slices thinner than the sphere spacing (~1.4 cm) are not cut; a thing to be cut must lie on the board as a part of it or be carried there.

### Watched again (2026-10-29, the-quiet-crucible 119515): the ingredients made real

- **A loose thing is a body only once something comes to it** (`TablePhysics._wake_loose`): the work takes it up, its holder moves, a moving solid or something awake comes within a few millimeters (`Particles.awake_in`, by cells). Untouched, it costs nothing; touched, it is never rigid (a full solver had left 114 of 125 loose things rigid, colliding with nothing, never crushed). `MOST` is 1600. A frame shares what did not change (sizes, what is alive, owners, bodies) with the last. Gate: physics_check `_held_meets` (an untouched heap of forty costs no particle).
- **A held thing meets what it is carried into** (`Particles._held_way`): moved whole toward the hand only as far as nothing is deeper in a solid than it already is (a conservative advance, halved four times), then on along what stopped it. A free body does the same after its shape match where nothing near it moves (`_way`): one sphere at a time, since a scale's spheres 6 mm apart had let a vial's 1.5 mm glass slip between them. A held loose thing makes its frame be stepped. Gate: physics_check `_held_meets` (a 3.2 cm scale stays out of a 1.3 cm mouth; a bead goes in, onto the floor).
- **Grinding is the physics', not `grow`.** A pressed tool's head touching the bowl's sloping wall counts as meeting it (`TableWork._pressed_into`: within `PRESS_INTO` of what it presses). Godot's ray and triangle test has an epsilon (0.00001 on the edges' product) that passes a ray through any triangle smaller than a few millimeters in meters - a lathe bowl's floor within 2 cm of its axis - so the work's ray meshes are kept in centimeters (`TableWork._ray_mesh`, `_ray`; `TableBox`'s are not yet). A `grow` on a loose part is refused, saying how to grind it; `parts` says which loose things break. Gates: physics_check `_grind`, table_work_check `_loose_size`.
- **A hand holding a thing up sways** (`TableWork._held_up`): left between moves touching nothing, it drifts as a hand holds it, `Hands.HOLD_SWAY` times the drift of a careful move, coming on as the move ends and dying away before the next. Set down, or resting on or against anything, it is still. Gate: table_work_check `_held_up`.
- **The work's spot is kept clear, not the shuffle's rectangle**: only a card spread's area is kept bare (`TableThings.shuffle_rect`), and the blueprint draws the work's spot (a cross; the text gives it in centimeters) for what is worked where it stands to be set beside. Rule: the set dresser's THE WORK.
- **A vessel that has held one thing is never used for another** (the brief's rule). `parts` gives the `turn` that stands a thing laid on its side upright (the stopper).
- **The bake keeps ahead of the show** (a 167 s episode baked in 129 s, from 243): an empty inside is not levelled, sloshed and poured every frame; with nothing moving, the loops over every sleeper are skipped; what rides a moving vessel is looked for only near it; the stretches the work holds a loose thing are found once a plan; a stream's parcels are looked at only while one could still be falling; what floats on a calm liquid sleeps there (`Particles._afloat`) and wakes as it is stirred, tipped or struck; and a body no blade will cut (not soft, or under 3 cm) spaces its spheres up to twice their touching (`BODY_SPREAD`). The live bake runs up to 20 s ahead (`HORIZON`).

Open: a new episode, for the new set dresser and puppeteer rules; the grinding and a pause to be heard and watched; a pot that laps over its own rim back into itself through every act (unseen, but a stream the whole show); `TableBox`'s rays in meters; things a hand carries along a path through another thing now catch on it and drop (`act` says where they land).

### Watched again (2026-10-29, the-quiet-crucible 841899): what rests, what is put back, what a liquid feels

- **A body is not flung**: the whole-body advance (`Particles._way`) slides what stopped a body on by the rest of the way between two poses' middles, not their origins (which lie where the body was made, a meter off), and a body's poses are passed through about its middle (`Particles._between`).
- **What falls on a slope goes down it**: a solid's surface holds what rests on it by its own friction as well as the thing's (`TablePhysics.SURFACES`, met as their geometric mean) - polished metal and glass slick, stone and cloth not. Gate: physics_check `_rolls_off`, a board tilted 12 degrees the control.
- **What is in a thing goes with it**: a sleeper sleeps on the inside it is in, else on what holds it up (`Particles._host_of`, `_inside_at`; `touch` the contact facing up most, the table's top `TABLE`), and one asleep in an inside that is carried is carried with it (`_rehost`).
- **A thin thing's field is long enough**: the band is at least `ShapeField.FAR_LEAST` (12 mm), since past six cells every point reads the band's distance and a 1.5 mm pan's cells are 0.44 mm.
- **Put back as it was**: a carry with no `to` goes back where the thing was built, as it was built unless `turn` says; a part goes back where it was built in its thing, the thing as it stands now (`TableWork._home_of`); a thing set down stands on what is under its own foot (`_foot`: its surfaces' lowest points), never its box's corners. Gate: table_work_check `_put_back`.
- **A thing at rest is not held up**: whether a hand holds a thing between moves is asked of its own surface (`ShapeField.surface_points`), not its box's corners (a round lid has them out in the air past the rim).
- **A liquid's surface is moved by what crosses it** (`SurfaceWaves`): its heights over a grid across its vessel, a damped wave equation at 0.23 m/s (water's slowest ripple, at 1.7 cm, where its surface tension and its weight pull alike) coming back off its walls; a solid coming into a cell of the surface pushes it up, going lets it down (a bow wave and a wake), and what falls in dents it; stirred, it curves as a turning liquid does (omega^2 / 2g); what floats rides both. Kept a frame at a time as a byte a cell, drawn by its shader as the surface's shape. Gate: physics_check `_waves` (a spoon stirring a pot: 2 mm ripples over 79% of it; still 9 s after; the spoon going round over the water, the control, leaves it at rest).

Open: a polished crystal facet glowing under a candle (not traced); a balance's beam is the puppeteer's path, not the weight in its pans (see the next section); a solid sunk in a liquid does not raise its level (see "A step back").

### Watched once more (2026-10-29, 841899 replayed): what a hand picks up, and what weighs

- **A part's joint reaches the physics**: a part is where the part it hangs from has it, turned on its own joint (`_base_world`, `_joint` - one function for the picture and the bake), and its solids move with any of those; the bake looks at joint channels, not only `pose` (`TablePhysics._moves_at`, `_may_move`).
- **A hinge that hangs swings by weight** (`TablePhysics._find_swings`, `_swings_step`): a hinge on a level axis whose own weight hangs below its pivot swings by the torque of that weight and of whatever lies on it (`_loads_on`), its inertia about its axis, its pivot's drag, its stops; no act turns it. A part of it with no joint whose middle hangs below the pivot hangs from its top, level, as a balance's pans hang from the beam's ends (never higher than the pivot). It is trued as built: whatever turn its making leaves it with, empty, is taken off. Masses come from the solids' fields sampled over their boxes and their materials' densities (`_mass_of`). A 1.9 g lump on a balance tips it to its 10 degree stop in a third of a second; lifted off, the beam comes back level over a few seconds.
- **What a hand picks up is a rigid body** (`RigidParts`, Muller et al. 2020's positional contacts): every free part an act moves that is not loose - its own solids and those of every part of it with no joint - with a mass, a middle and an inertia, met as points on its surface against every other solid's field and every other solid's points against its own. Held, it goes where the hand takes it in pieces short enough never to step over a wall, pushed out along what it meets; let go, it falls, its friction against what it lies on, asleep on that and carried with it. The picture draws it where the bake has it; `act`'s check still reads the acts' own poses (`TableWork._planned`). A body clear of everything by more than it has gone since it was last looked at is not looked at (`RigidParts.STIRS` for a settling body that stirs nothing loose). The solve: a let-go body takes the mean of its contacts and a velocity pass after (its speed along each contact set to a small bounce of how it came in); a held one takes them one at a time, deepest first, each measured again - a hand drives what it holds into what is in the way. Surface points are taken farthest first; a body settling on what is being moved is carried by it; a hand never lets go between two moves less than `HOLD_GAP` apart; two held at once never push each other apart.
- **A sleeping body's pose is not frozen by other awake things**: only a body that fell asleep is hosted again (`Particles._settle`); a held body jolts nothing; a hollow part with loose things in it is one of the vessels reckoned (`LIQUID_MOST` 40).
- **A loose thing at rest lies again** (`TablePhysics._rest_loose`): asleep `RELEASE_AFTER` seconds, whole, held by nothing and in no liquid, it gives its spheres back and lies where it came to rest, as what holds it holds it - drawn there, carried with it, still weighing on it - until it tips or jolts under it or anything comes to it. Its body lets go of its spheres (the solver gives a dead sphere's place to the next made), and one lies again only where it is at what it lies on. A body settling does not wake another settling body.
- An act's report says where a loose thing's middle is, never its node's origin.

Gates: physics_check `_weighs` (a balance tips to its stop with a lump on one pan and comes back level, its pans level throughout; an act turning the empty beam, the control, turns nothing), `_tool_meets` (a rod driven 5 cm into a block stops at its face; the work's own rod, the control, is in it), `_tool_falls` (a rod let go 6 cm up lies on the table, asleep).

Open: a sunk solid does not raise a liquid's level; a rigid body in a liquid has no buoyancy; whole things carried (a mortar, a balance) are still the work's own poses, set down by their foot (see "Clipping, everywhere"); a held tool the acts turn through what it is in is pushed out with a jolt - the acts' own blend should go round it. The work's own law checks read the acts' poses (`TableWork._planned`); the physics is physics_check's to hold.

### Watched a third time (2026-10-30, 841899 replayed): the ladle's stream, what never slept, and what the acts got wrong

Found by baking the whole show once on a copy and logging it (where every parcel went, each body's sleep, each stage's cost), never by re-rendering:

- **A sunk vessel pours nothing**: a vessel whose lip is under another liquid's surface is that liquid now, full (`TablePhysics._under_liquid`). Gate: physics_check `_sunk` (a ladle stirred round a pot of water pours nothing; the control, lifted out and tipped, pours).
- **Trembling in place is at rest** (`RigidParts.SLEEP_DRIFT`, `Particles.SLEEP_DRIFT`): a body touching something that goes no further than half a millimeter from where it was sleeps, however fast it trembles.
- **A landing is no jolt** (`Particles.jolt_of`): a host's jolt is its acceleration along the table and downward past falling.
- **A held body goes at the hand's pace** (`RigidParts.CATCH_UP`): one held back by what it met comes back into the hand no faster than the hand goes plus 6 cm a second, and presses into what holds it back no harder.
- **Only a hand crushes** (`Particles._np`, a solid's `presses`): a body let go, settling by its own weight, rests on loose things and never breaks them.
- **The table holds a let-go body** whatever else pushes it, and a let-go body rests on the loose things under it (`RigidParts.LOOSE`).
- **The acts' own faults are said by `act`**: a sprinkle naming a thing the act moves must fall within 3 cm of it (`TableWork._sprinkles_said`, `PINCH_NEAR`); a part let go more than a centimeter from where its act left it is said so (`TablePhysics.report`, `LET_GO_OFF`); a stopper carried back with no `turn` lies on its side and drops into its jar.
- **The bake's pace** is what lags a live show: the particle solver on spheres that never slept was the cost, and with all the above the bake ran 0.8 to 1.4 times the show's pace from 100 s on, with 4 to 92 spheres awake and the solver never full.

Open: a stopper dropped sideways into a full jar still works down through its contents (the let-go solve's mean is weak against many contacts at once); a held pestle laid down past its mortar's rim jumps 2 cm in a frame as it is pushed across the rim; a busy frame with nothing awake costs about half the show's pace.

### Played live with new acts (2026-10-30, 841899's work blocked again): the ladle over the pot

Three causes, all the bake's, none visible in the puppeteer's rehearsal (one plan, its acts back to back):

- **A new plan does not begin a held move again**: `TablePhysics._take_plan` keeps `_held` (where each held move began) unless what the plan changed lies past the bake, or a checkpoint is restored with its own. A live reading hands over a plan with each sentence's words. Gate: physics_check `_moved_on`.
- **What a body was not looked at against still counts**: a solid not looked at bounds `RigidParts`' clearance by the gap between their boxes less a frame's most movement (`RigidParts._near`'s `far`). Gate: physics_check `_let_go_in`.
- **Held up between its moves, in the bake too**: the hand holds a rigid part where the move left it, swaying as the work sways it, until the next move takes it (`TablePhysics._held_aloft`, `RigidParts.touching` asked once as the move ends); what rests on or against something, or what no move takes up again, is let go (`_tool_falls`). Gate: physics_check `_held_between`.

Open: a let-go body landing on a thin wall stands 1-2 mm in it and, heavy and leaning, can work down through it (addressed in the next section); the act's check still reads the acts' own poses on the rehearsal, so what only a live reading's timing does is the gates' to hold.

### Clipping, everywhere (2026-10-30, 841899 replayed with the above)

One cause per class of clip:

- **Every thing an act moves is a body** (`_make_rigid`: its own solids and those of every part that moves only as it does, keyed -1 less its number, `_ch_of`). The twin has it where the bake has it (`TableWork.posed_things`, `_thing_world`), so its hinged parts, contents and liquids go where it really is, and the picture draws it there (`tick`, `thing_pose_of`). Before, only free parts were bodies, and the only guard for a whole thing was `act`'s check (`TableWork.check`: a few hundred of the mover's mesh corners, 25 moments, a ray's parity against the still meshes) - a 4 mm rim going into a mortar between its corners was never seen. `act` now says what held a hand back and how far short (`report`'s HELD BACK, from each frame's `rd`/`rt`).
- **A held thing is not held back by what it carries**: a body meets only what weighs more than it (and, held, not what is held too - `RigidParts._near`); lighter ones it pushes aside or carries; what hangs from it (each solid's `bodies`) it never meets; a rider is not woken by its carrier's own solids (`_asleep_frame`).
- **The bake goes before the draw**: `TableWork.tick` bakes to the moment before it sets the things' nodes.
- **Thin walls**: a contact is a push along the field's way out, and past a thin wall's middle that way is through its far side. So a point coming into a still wall keeps the face it came in by (`RigidParts` body `faces`: a plane, kept while it is in the wall and, out of it, only within `FACE_REACH` of where it came in), a held body's contacts are measured again against it (`_depth_now`), and a let-go body is put out along the deepest after its mean. A particle's centre is never left inside a still solid it was outside (`Particles._solid_pass`).
- **The act's report tells the truth**: a broken thing is placed by where its pieces are; a vessel's tip is read from the body where it really is (`_solid_at`).
- **A bake begun again from a checkpoint is the bake from the start**: a body's `stir`, `was_moved` and its solids' last frames (`_body_solids`) are kept.

Gates (physics_check): `_thing_meets` (a crate driven into a block stops at it, and is said HELD BACK; the control, the work's own crate, is in it), `_thin_walls` (a brass ladle stirred over powder on a 3 mm floor and let go in the pot never goes through the floor; the control, the powder moves). The bake's cost, a quiet machine, 10 s at a time over the first 100 s: 0.52 to 0.96 of the show's pace.

Open: the particle guard is not yet shown by a gate; a body meets things by 120 points of its surface, and between them its surface may dip into a wall (never through one, in the gates); `act`'s own ray check of the plan runs beside the bake's HELD BACK, and on a table reused for several checks (a probe, never the app) it can disagree - not looked into.

### The live viewer is not the export (2026-10-30 night, 841899 played live, feedback 0009-0016)

A whole show baked once with every act placed, as an export bakes it, was right; the live viewer differed in four ways, each fixed:

- **It drew a plan it had dropped**: a new plan sends the bake back to the checkpoint before what it changed, and what was baked past the change is dropped (`_take_plan`; physics_check `_plan_drops_stale`), so `baked_to` and the "behind the show" log are honest.
- **A hand let go what an export holds**: a part left in the air is held if a later act takes it up, found among the acts themselves (`_moved_after`, `_play_rank`; physics_check `_held_till_placed`), since live a move is placed when its word is heard.
- **It fell behind, and now the viewer waits**: from when the bake is less than `WAIT_UNDER` ahead of the show until it is `WAIT_AHEAD` (3 s) ahead again, the show's time is held (`TablePhysics.behind` -> `ShowFeed.wait_for` -> `Spectrum.set_waiting`: the player and the bookends stopped as for a pause, but not a pause - the transport still plays, its time saying "catching up", and a pause taken meanwhile outlasts the wait). Never in a render, a preview or a gate. A new plan is baked again from its first change the bake can see (`replan`, `_changed_from`: the channels it reads, entry by entry; a move that goes by its time alone, ending elsewhere, from the sooner end - physics_check `_replan_from_change`), so a stir whose end moves with each sentence does not restart the bake. Gates: physics_check `_waits_for_bake`, transport_check. Open: a faster bake.
- **The mortar slid**: what rests in or on a body, and a lighter thing in a hand, never moves it or wakes it (`RigidParts._yields_to`); a falling body meets everything else. Gate: table_work_check `_at_the_spot`.

Not gated: a falling body meeting a lighter one.

## Risks

- **Cost.** A few hundred awake particles at 240 Hz in GDScript are milliseconds a frame of simulated time; on a thread of its own that is several times real time, but a busy moment can still outrun it live (the viewer waits; a render waits). The particle count is capped (`Particles.MOST`), and what rests costs nothing.
- **Agents.** A set dresser that does not mark a dish's stones loose gets a dish whose stones stay put (a heap's copies are loose by default for this reason). A puppeteer that does not tip far enough pours nothing - `act` says so, with the angle needed.
- **Tunnelling.** A fast particle could pass a thin wall in one substep; a move longer than its radius is taken in pieces.
- **Old episodes** play with the physics: their `pour` tracks are dropped (said in the notes), and what they tipped pours for real or not at all.

## Sources

- Muller, Heidelberger, Hennix and Ratcliff, "Position Based Dynamics" (VRIPHYS 2006 / JVCIR 2007)
- Macklin, Muller, Chentanez and Kim, "Unified Particle Physics for Real-Time Applications" (SIGGRAPH 2014)
- Muller, Heidelberger, Teschner and Gross, "Meshless Deformations Based on Shape Matching" (SIGGRAPH 2005)
- Macklin, Storey, Lu, Terdiman, Chentanez, Jeschke and Muller, "Small Steps in Physics Simulation" (SCA 2019)
- Macklin and Muller, "Position Based Fluids" (SIGGRAPH 2013) - weighed, not taken
- Muller, "Fast Water Simulation for Games Using Height Fields" (GDC 2008)
- Lamb, "Hydrodynamics" (6th ed., 1932), on capillary-gravity waves: the slowest ripple on water, 0.23 m/s at 1.7 cm
- van den Doel, Kry and Pai, "FoleyAutomatic: Physically-based Sound Effects for Interactive Simulation and Animation" (SIGGRAPH 2001)
- Muller, Macklin, Chentanez, Jeschke and Kim, "Detailed Rigid Body Simulation with Extended Position Based Dynamics" (SCA 2020)
- Ibrahim, "Liquid Sloshing Dynamics: Theory and Applications" (Cambridge, 2005)
- Mayer and Krechetnikov, "Walking with coffee: Why does it spill?" (Physical Review E, 2012)
- Potyondy and Cundall, "A bonded-particle model for rock" (Int. J. Rock Mech. Min. Sci., 2004)
- Flash and Hogan, "The coordination of arm movements: an experimentally confirmed mathematical model" (J. Neurosci., 1985)
- Morasso, "Spatial control of arm movements" (Exp. Brain Res., 1981)
- MacKenzie, Marteniuk, Dugas, Liske and Eickmeier, "Three-dimensional movement trajectories in Fitts' task" (Q. J. Exp. Psychol., 1987)

## The ghost of the ladle's bowl (2026-10-30 night, feedback 0017-0020)

An empty vessel's inside mesh is made when it is first filled (`_make_inside_node`), and is measured through the node the vessel hangs from (`TablePhysics._mesh_in_vessel`), not against the vessel as built - else a ladle first filled in its pot has its inside drawn off its rest, riding the ladle round every stir. Gate: physics_check `_dip` (the cup's inside drawn in the cup; the control, measured as built, centimeters off). A contact from the side no longer holds a body up (`RigidParts.HELD_UP` on `touch`; what held a hand back is `by`), gate `_held_up_from_below`. The captures carry a `table` report (`TableWork.drawn_report`) of which parts are off where they first stood.

## Corks and lids (2026-10-30 night, feedback 0021 and the brimstone's cork)

One class: a part and its seat. Tracks of one act that make the same move share one hand and the second rides the first (`TableWork.build` `_with`, `_pose`'s `_lead`; the bake rides the leader's re-based move, `_held_pose`). Two held bodies meet (a lighter one in a hand yields, `RigidParts._yields_to`); a lighter thing in a hand never holds a heavier one up (`_may_hold`). Each part has a seat, what of its thing it was built touching (`_add_body`): eased in or out by a hand within `SEAT_REACH` it never meets it, and let go within `SEAT_NEAR`/`SEAT_TILT` it sits as built (`TablePhysics._seat`), since the solver's points are coarser than a cork's fit. Gates: physics_check `_carried_with`, `_put_back_in`.

Open: a hearth ash lid ends 56 mm off its crock, still moving a second later (ash on the rim holding it up would be right; not traced).

## A step back (2026-10-31, 841899 exported): the hand plans, the physics settles

Whack-a-mole on single instances was the wrong unit: the goal is to fix entire classes of problems.

### How it was looked at

`tests/table/episode_bake_probe.gd` (kept): the episode the take's sidecar names, stood from a copy, its acts scheduled on the take's own word times - exactly what the export baked - and the whole show baked on the probe's thread, then the parts asked for followed every quarter second (place, tilt, turn, how far off the hand, what held it back), each liquid's volume and surface height, the streams in the air, each act's report, each pour's plan; `--acts-file` tries other acts on the copy, `--shots` (on a GPU) draws chosen moments as the export drew them, `--gaps` measures a watched part's drawn surface against what is drawn under it. Every cause was read off its log, not guessed from the video.

### Why it kept happening

Three layers:

1. The agent writes geometry: a pour's lip, a carry's height, where a tool is left - in centimeters, by a model that cannot see what it would hit.
2. The work plays it literally, and the physics then fights it: held back, dropped, flung.
3. The physics decided what a hand does by local tests: a hand held anything "touching nothing" within 4 mm and dropped anything touching something; a part was seated only at the moment it was let go; a liquid's level counted its own volume alone; a floating body skipped the guard that keeps a body out of a wall.

So the fixes are rules a hand and a liquid keep - one each - and a law that takes the geometry away from the agent:

| Symptom | The class | The rule now |
|---|---|---|
| a ladle upright in the brew, swaying | a hand holding what would not fall | A hand holds only what would fall (`TablePhysics._held_aloft`): what rests where it is - held up from below, its middle over what holds it (`RigidParts.supported`) - is let go, and so is what stands in a vessel (`_stands_in`: its lowest point 2.5 cm under a rim), to lean there; what would fall is held until its next move; after its last it is lowered |
| a full ladle dropped after its dip | touching taken for resting | the same rule: grazing a rim or a vial is not resting |
| things let go fell and struck | a let-go is a drop | A hand lets go gently (`RigidParts.guide`): for 2.5 s after a hand lets go, or until it rests, no point of a body goes faster than 12 cm/s |
| corks shifting on their jars | a part in its seat simulated as a free body in a neck its points cannot resolve | A part in its seat goes with it (`_weld`, `RigidParts.weld`): carried with its seat (a move that begins and ends seated, never further off than two hands' bows - `_with_seat`, `SEAT_RIDE`), let go there by a hand, or come to rest snug in it, it is welded - eased onto the seat over a quarter second, then exactly where the seat is, woken by nothing but a hand taking it out. A seat is what holds it up and never a part of its own |
| the brew falls as the ladle goes in | a level that counts only its own volume | What stands in a liquid is under its surface (`_level_of`, `_displacers`): the level leaves under it the liquid and every body's matter, every moving vessel's whole inside and every sphere in it, less what stood in it as built (`d0`) |
| a ladle's bowl glitching in the brew | a sunk vessel's own surface drawn under the brew's | A surface under another liquid's is none (the frame's `sunk`) |
| a feather through the cauldron's wall | a sheet as a line of spheres; a floating body unguarded | A thin thing is met across its face (`Particles.fill_shape`), and a still wall is never crossed whole by what floats or is pushed (`Particles._way`'s `still_only`) |
| a ladle held back on the recipe tin | a carry's lift as written | A carry clears what stands in its way (`TableWork._clearance`): its lowest point 2 cm over the highest thing under its way, the written lift the least it rises |
| a pour from too high, missing the vial | a pour written as raw keys | A pour is a hand's (`Motions.LAWS` `pour`, `TableWork._pour_at`): `{"law": "pour", "into": "vial 1"}` - brought level over the mouth with its handle turned away, lowered onto it tipping about its lip so its body swings clear, turned about its lip (so the stream leaves where it was put), set back by the stream's throw (`sqrt(4/3 head fall)`), its lip as low as the mouth's width allows; back level, its lip rising |

### Measured on 841899 (a copy; the export's timing)

Read off `episode_bake_probe`: the ladle stood in the pot leans on the rim at 48 degrees and lies still; corks ride their jars to the millimeter; the brew's surface stands 0.9 mm higher with the ladle in (its metal displaces) where it had gone from 955 to 916 ml; the phoenix feather stays in the brew; the full ladle is held over the pot until the pour, and the `pour` law puts 7.8 ml of 11.9 in the vial where the hand-written pour put none (88% of a fuller ladle on a bench); the ladle carried home is lifted to 26 cm over the tin and set on its rest.

Gates (physics_check): `_seat_rides`, `_leans_in`, `_held_unless_resting`, `_level_counts`, `_floats_in`, `_clears_way`, `_pours_into` (the jug: all of it into the cup, its lip 3 cm over the rim; by hand about its middle 10 cm up, most of it spilled), `_runs_down` (a parcel thrown at a pot's inner wall ends in its water). Each fails with its fix taken out.

Also: a stream's parcels are looked along their whole way for what they meet (`_solid_on_way`); what strikes a vessel's inside is not counted gone (`_inside_of`); a seat is only what holds a part up from below.

### Open

- An episode made before `pour` and `dip` still pours and dips by hand: the Episode card's Work row, "Block the work again", writes `acts.json` afresh (told of `pour` and `dip`), or `acts.json` is edited by hand (`{"law": "dip", "into": ...}`, `{"law": "pour", "into": ...}`; the table reads the file at every stand). A straight-handled ladle cannot come level out of a deep pot at all; the set dresser might crook its handles.
- A sheet is met across its face but drawn rigid: a feather that bends needs its mesh skinned to its spheres.
- The pour's way back level lags its hand a few centimeters for half a second (`act` says HELD BACK).
- Not yet watched by the author, live or exported.

### Built the same evening, asked for: `dip`

`{"law": "dip", "into": "the pot"}` (`Motions.LAWS`, `TableWork._dip_at`, `_dip_plan`): the hand brings the vessel over the mouth with its handle out over the rim the way it came; finds, at each of seven depths from over the rim down to 1.2 cm over the floor, the least tip its body (every solid of what moves) clears the other's walls by - with its bowl as far across from that rim as goes deepest and least tipped (`_vessel_into`: the inside that holds a liquid before an empty one); lowers it straight in, tipping as each depth asks; holds it while it fills; and draws it up slowly, levelling as fast as the walls allow, so what it cannot hold falls back inside, and level at last. What strikes a vessel's inside wall runs down into it (`_inside_of`). On a bench of a straight-handled ladle and a 13 cm pot it must tip 45 degrees to reach near the floor, and a shallow bowl holds nothing at 45; levelling as it rises, it comes up 59% full, level, nothing outside the pot. Gate: physics_check `_dips_full` (the control: lowered level by hand, its handle meets the rim, it comes up empty).

The pour is careful too (`_pour_plan`): tipped along its brink (for each twentieth of its inside, the least tip at which that much reaches the lip's crest, from its level table - the outflow is steady, never a gush); tipped coming in only as far as its body needs, held up to 1.5 cm higher rather (`POUR_HIGHER`); its stream aimed for the height it falls from; back level from where its tipping ended; and what a stream strikes inside a vessel is asked a little back along its way (right at a wall a point lies in the inside's inset, outside it). On the bench 78% of a dip's 43 ml lands in a 1.6 cm vial. And `act` no longer calls a thing the hand still holds up "let go".

## The primitives (2026-10-31 night, 841899's work blocked again, played live; feedback 0001-0003)

Each symptom was one more instance of a rule that held for the shapes it was written for and not for the next one. So each fix is a primitive - one test or one representation for every shape the agents make - measured on the exact thing that failed. For a take-less live episode, a take is written from the episode's `script.md`, each word timed as Kokoro roughly reads it, so `episode_bake_probe` can bake it on a copy.

| Symptom | The class | The primitive now |
|---|---|---|
| a ladle on its block, swaying | "would it fall" told by a rule (`RigidParts.supported`) | Let go, where does it go? (`RigidParts.trial`, `TablePhysics._would_fall`): the body let go where it is, stepped alone for 1.2 s among everything as it stands; the hand lets go of whatever comes to rest within 2 cm of where it is, or stands in a vessel (which catches it), and holds the rest |
| a feather dropped between "held up" and "laid in" | a loose thing had no hold between moves (a rigid one did) | The same hand for both (`_held_aloft`'s `li`, `_loose_would_fall`) |
| four jars moved as one | a whole move welded every free part into one rigid body | A thing is one only as far as something holds it together: a free part is a body of its own whenever what it stands in moves (`TablePhysics._goes`, `_rides_thing`); a thing with nothing fixed to it is the hand's trips (`TableWork._trips`): its free parts carried two at a time, one in each hand, each to its place, over the same stretch, and `act` says so |
| a feather floating, its shadow apart | a sheet had no shape of its own and rested on its spheres' radius | A sheet's own shape (`ShapeField` "sheet": its outline's 2D field and the slab its thickness makes, bent and folded as `Props._sheet` bends it); its spheres one layer on its bent middle (`Particles.fill_shape`); a sphere rests at its thing's thickness against the table and the solids (`Particles.rc`, `add_body`'s `contact`), a matched body lifted out whole by its deepest (`_out_whole`) |
| a ladle on the cauldron's lip, floating | contacts at 120 points of a body and 200 of the other: a handle crossing a rim between them sank 2.2 mm into it | The deepest point, found (`RigidParts._refined`, after Macklin et al., "Local Optimization for Robust Signed Distance Field Collision", 2020): from each place a body's points come near a solid (up to four, 2 cm apart), down the solid's distance along the body's own surface, each step put back onto it by its nearest solid's field. Measured: 2.20 mm into the rim before, 0.49 after; of several contacts, the deepest left past twice the slack by their mean is put out alone, straight along it |
| two things held back by each other for minutes | two acts sent things to one spot | Room for it (`TableWork._room`): a move ending where another thing stands (any of its surface 2 mm in a solid as the plan has it then) is set the nearest place beside it that is clear; never against what it is a part of or was built in, judged as it will stand, set down first |
| a jar lifted from its row knocked the next | a carry goes across from its first instant | Up clear first, down among them last (`TableWork._rise_among`, `Hands.carried`'s `rise`): a thing with others within 1.5 cm round it rises clear of them before it goes across, and is across before it comes down among those where it goes |
| a way home held back short by an open tin | a path's keys played as written | A path clears what is in its way (`TableWork._path_clearance`), as a carry does; what is under a way is looked for in a grid over all it covers (`_probes_of`), free parts included (`_part_mesh_of`) |
| scrubbing: a tear on the recipe card | the bake began at 0, and what a mid-way start's acts did before it was never baked | The past is baked: a mid-way start's earlier words placed just before 0, spaced as estimated (`ReadingFollower.near_past`, the table's follower), and the bake begins at its first act (`TablePhysics._t0`, `_t_of`, `_k_of`); a live show waits for it as for any bake |
| a "bloop" a second while the pot only steamed | the boil's sound was its own seven big bubbles a second per unit of `boil`, nothing seen | One stream of bubbles, seen and heard (`Boil`): a seeded stream a pure function of the liquid, the time and its `boil` - many more as it boils harder, bigger, each ringing at Minnaert's pitch for its size (a millimeter's 3.3 kHz) as loud as it is big - drawn breaking on the surface (`prop_liquid.gdshader`'s `bubble`), the big ones ringing it in the bake (`_waves_step`), and heard as each breaks (`WorkSounds`). A simmer (`boil` 0.2) is about sixteen faint ticks a second at 2.6-6.5 kHz |

Gates (physics_check, each two-sided): `_jars_apart` (the control: on a tray they go together), `_rests_let_go`, `_sheet_lies`, `_past_baked`, `_tool_meets` (an aim drives the rod into the block and the physics holds it; a path there now goes over it), `_rests_on_rim`; work_sounds_check's simmer (at `boil` 0.2 over ten bubbles a second, all above 2 kHz; a rolling boil's reach under 800 Hz; every bubble heard is drawn just before it breaks).

## The framework, audited

Measured, the framework and not the agents' freedom is behind the bugs: [framework_audit.md](framework_audit.md). One puppeteer run spent 9.7 of its 105 minutes thinking and 78+ inside our tools; the physics world had been built from the acts, so every act that moved something new baked the show again from its start; a hand held a thing in the air for a later act however far off; `pour` stopped at an empty liquid's brink; the prompt's example taught the hand-written tip; and `act` named the thing, not the part, where things landed. Built, each held by a gate: the world from the table (every free part and movable thing a dormant body), one table a puppeteer session (`rebind`), holds only across a 3 s pause, `pour` past the brink, reports by part and pours judged IN or MISSED, a live frame posing only what changes, and the viewer buffering while paused.
