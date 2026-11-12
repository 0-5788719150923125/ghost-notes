# C#: would it help, and should it come with the editing work

The question: would moving much of the code to C# fix the slow scenes, and should that migration start with
[editing.md](editing.md)'s?

Measured on an i7-4790K (2014, 4 cores), an RTX 5060 Ti, Godot 4.7.2 in its standard build. The load average was 11
throughout, so every figure is processor time, never the wall's. This is [compute.md](compute.md)'s step 1 done for the
scenes, and its step 5 priced. Nothing is built.

## The answer

- **Would C# help? Yes, where the slowness is our own code, and by a great deal.** The scenes are slow in GDScript
  arithmetic and nowhere else: 13 of the 55 in the catalog cost more than a 60 fps frame in script alone, and four cost
  110 to 126 ms. The worst one's arithmetic, compiled, runs about a hundred times faster on this processor.
- **Most of the code? No.** What is slow is a few kernels: about 2,000 lines of scene geometry and about 9,000 of the
  bake's solver, of 220,000. The panels, notes, agents, pipeline and registries are not slow. Moving them buys nothing
  and costs the gates, docs.py and edit-and-run-at-once.
- **Not everything slow is ours.** A playing table spends 2 to 3 ms a frame in script and 6 ms of the graphics card; its
  hitching was the stage governor hunting over frames that waited for something else
  ([table_playback_investigation.md](table_playback_investigation.md)). An export is mostly readback and encoding. C#
  changes neither.
- **With the editing work? No.** They touch different code, and two migrations at once leave every regression with two
  suspects. They meet in one place, what an edit costs to see (below), and that sets the order.
- **For the scenes, the GPU first.** A vertex shader's work is being done by hand on the processor while the graphics card
  is idle. C# would make the wrong device fast enough; a shader gives the work to the right one.
- **C# is the right tool for what must stay on the processor:** simulations (the bake, cloth, sand, flocks) and builders.
  It is first-party, one toolchain for every desktop, and the GDScript it replaces is its own test.

## What was measured

### Every scene in the catalog (`tests/scenes/scene_cost_probe.gd`)

One frame at 1920x1080 on the dummy renderer, so the GPU is not in it: script, and the canvas taking its arrays. The
forge is made to build in `_draw`, as an export does, so a worker's share is counted. An empty frame (0.13 ms) is taken off.

| A frame costs | Scenes |
|---|---|
| over 100 ms | `terrain_city` 126, `spires` 124, `canopy` 118, `terrain` 111 |
| 16.7 to 45 ms | `snowfall` 43, `rocks` 35, `cloth` 27, `tidepool` 26, `filaments` 25, `tunnel_run` 24, `chladni` 21, `falling_sand` 19, `contour_map` 19 |
| 8 to 16.7 ms | `murmuration` 15, `two_eyes` 15, `eye_prism` 15, `planes` 11, `furry` 10, `starfield` 9, `spectrum_ring` 8, `metropolis` 8 |
| under 8 ms | the other 34 |

Nearly all of it is `_draw`, on one thread. Live, 11 scenes build on a worker (`FrameForge`), so the UI stays up and the
picture updates only as fast as its build: `terrain` at about nine a second. CI's processors are about 2.5 times this
one; such a machine clears the middle rows and leaves the top one at 45 to 50 ms.

### The worst one, by stage

All four scenes over 100 ms draw one thing, `Terrain`: a heightfield of 12,544 vertices, built once, then every frame:

| Stage | ms | What it is |
|---|---|---|
| `collect_surface` | 61.2 | each vertex projected, lit, fogged (4.9 microseconds a vertex); a Dictionary and three arrays made per quad |
| `step_light` | 15.8 | the cast shadows eased |
| the batch | 24.8 | 12,314 quads written into `TriBatch` |
| `painter_sort` | 7.9 | far to near, for want of a depth buffer |

The same arithmetic in C (`gcc -O2`, one thread, the water branch left out) takes **0.88 ms** where GDScript takes 93.9
for the three stages it covers: about 107 times. C# usually lands within two or three times of C on such a loop; that
part is not measured, since this machine has no .NET SDK. Godot's developers gave about 4 times for naive code at 4.0,
and "orders of magnitude" is what people report for loops that never call the engine, as this one does not.

### A playing table (`episode_bake_probe --profile=150`, 732687 on a copy)

The work costs 1.76 ms a frame, the whole medium 2.19 ms; played live for 300 s, 2.68 ms a frame and none over 22. The
table stood in 21 s (28 to 31 s in the app's own log). The app's log has its playing frames at 25 to 26 ms, right on the
governor's line (24 ms). That is not the table: its stage takes the card 6.2 ms at 1920 x 1080. Something was waited
for (the card or the processor shared) and the governor hunted over it.
[table_playback_investigation.md](table_playback_investigation.md) has the split and the fix.

## What C# would change

| What is slow | Our GDScript? | C# | The better lever |
|---|---|---|---|
| The scenes' geometry (21 of 55 over 8 ms) | all of it | to a few ms each | the GPU: a mesh built once, a shader, a depth buffer |
| Scenes that are simulations (cloth, sand, flocks, snow) | yes | large | C# |
| The physics bake (161 s for 345 s of show) | yes, about 10 ms a stepped frame | large | C#, and compute.md's islands |
| A table built (21 to 31 s) | not measured | unknown | measure it |
| A table playing | no: 2 to 3 ms | nothing | the governor reading its own thread (done) |
| An export (9x its length) | a minority, but a `terrain` frame adds its 111 ms | little | cloud_render.md |
| An episode's agents | no | nothing | |
| Panels, notes, pipeline, agents' plumbing | not slow | nothing | |

## What it would cost here

- **Another engine and a build step.** C# needs Godot's .NET build and a .NET SDK (8 or later). This machine has
  neither: `/usr/bin/godot` is the standard build, and only a runtime is installed. `scripts/setup_godot.py`, CI and
  "Godot is the only install" all change. Every run and every gate begins with a build.
- **Runs that share one tree.** Dispatched runs overlap here, and they would share one build output.
- **The phone.** Android and iOS are still marked experimental for C# in Godot's documentation, and the web cannot be
  exported at all. A project with C# in it takes the .NET path on every platform it ships to. Whether the phone can be
  exported from the standard build, with the kernels simply absent, is the first thing a spike must find out.
- **Two languages.** GDScript and C# call each other by name at run time, with values converted on the way, and neither
  can extend the other. A kernel behind one call a frame (arrays in, arrays out) pays almost nothing for that. A scene,
  a card or a registry moved across pays it everywhere.
- **docs.py and the gates read GDScript.** The folder stack, the rows, the generated pages and 183 gates would all stand
  outside kernels unless they learn C#.
- **Bits.** Live must equal export, and some gates hold exact figures. A solver in another language rounds differently:
  tolerances change, and the bakes of shows already made are made again.

All of it is small for a handful of kernels behind a narrow door, and large for most of the code.

## The other levers, on the same loop

- **The GPU.** `Terrain` is a static mesh. Projection, light, fog and water are a vertex shader's job with show time as a
  uniform, and the sort goes away. Processor cost drops to near nothing, and the interpenetration the painter's sort
  cannot resolve (its own header says so) is solved by depth. The cost is the author's eye: a new picture must be judged.
- **The same GDScript, written tighter.** No Dictionary per quad, the batch written once, the light eased every other
  frame. Unmeasured; perhaps twice. Worth doing, and not enough.
- **A GDExtension (C++ or Rust).** Fastest of all, and it can be absent on a platform. A toolchain for each one.
- **A newer processor.** About 2.5 times, across everything, with no code.

## What I would do, in order

1. **Nothing in the language until editing.md's steps 1 to 4 are in.**
2. **`Terrain` on the GPU (M).** Four scenes at once, the worst four. The author judges one picture.
3. **A C# spike on one simulation kernel (S).** `Particles`' step, behind one static call, the GDScript kept as its oracle
   and its fallback. It answers what nothing here could measure: the real speed, the build step's cost in the gates, two
   runs building in one tree, and the phone exported without it. *Done when* those four are numbers.
4. **Then by measurement.** If the spike is clean: the solver (`TablePhysics`, `Particles`, `RigidParts`, `Vessel`), then
   what builds a table if that proves to be script, then the simulation scenes. Each is a kernel with its GDScript beside
   it until a gate holds them equal. If it is not clean, the GPU for what is a function of time and compute.md's islands
   for what is not, and the language question is closed.
5. **Where the two plans meet.** editing.md's `stand` and `bake` are the waits a person editing feels. They want step 4's
   solver and builders, so that work goes before editing.md's step 7, not after it.

## Decisions for the user

- A second engine build, a .NET SDK and a build step in every gate: acceptable, for kernels only?
- The phone: if a C# project cannot be exported for Android from the standard build, does C# stop there?
- `Terrain` on the GPU means a picture to judge again. Is that welcome, or is "the same picture, faster" (C#) worth more?

## Sources

- Godot's documentation: [C#/.NET](https://docs.godotengine.org/en/stable/tutorials/scripting/c_sharp/index.html),
  [C# basics](https://docs.godotengine.org/en/stable/tutorials/scripting/c_sharp/c_sharp_basics.html),
  [cross-language scripting](https://docs.godotengine.org/en/stable/tutorials/scripting/cross_language_scripting.html),
  [exporting for the web](https://docs.godotengine.org/en/latest/tutorials/export/exporting_for_web.html).
- [Current state of C# platform support in Godot 4.2](https://godotengine.org/article/platform-state-in-csharp-for-godot-4-2/).
- [State of GDScript vs C# performance in Godot 4.0](https://forum.godotengine.org/t/state-of-gdscript-vs-c-performance-in-godot-4-0/5875)
  (the developers' own early figure, quoted there).

## Status

Measured and evaluated; nothing built, nothing decided.
