# Computing faster: threads, the GPU, and tiny networks

Asked 2026-11-06, a long-term question, not work to start. Nothing is built and nothing new was measured for this
note: the numbers below are other notes' measurements, each cited. The user: "Computations in our projects here can be
rather slow, and I suspect a large portion of that is CPU time: just computing various values sequentially for every
frame ... do we have the ability to compute in parallel, and if so - would that even help? Second, is there any world
where we would get fancy, and use tiny neural networks to approximate the continuous, sequential functions that slow us
down? And if so, I wonder how much of that could be run efficiently on GPU, perhaps via shaders?"

## The answer, in short

- **We already compute in parallel**, and more threads would buy less than it sounds. Sixteen scripts use
  `WorkerThreadPool`, the physics bake has a thread of its own, and `FrameForge` builds scene geometry off the main
  thread. But the machine has 4 cores (8 threads) already shared by the main thread, the bake, the voice and, in an
  export, x264. And much of the slow time is not our GDScript at all.
- **A show is a pure function of seed and show time.** That is the project's biggest asset for speed: whatever is a
  pure function of time can be computed in any order, on any core, on the GPU, or in another process. Only a
  SIMULATION carries state from one frame to the next, and only it is truly sequential.
- **The levers, most certain first:** measure where a frame goes (never done for an export); move pure functions of
  time onto the GPU exactly, as shaders; the export's plumbing; the particle solver in its paper's own parallel form;
  compiled code for the one hottest loop (a trade-off for the user); tiny networks last.
- **Tiny networks: yes, there is such a world**, and recent graphics lives in it (small MLPs evaluated per pixel). But a
  network wins only on a narrow kind of function, and before approximating a function it is almost always better to
  move the exact one to the GPU. For the simulation, a network that REPLACES the step is the wrong use. The right one is
  parareal's coarse guess, which makes the work parallel in time and cannot change the answer - a research project.

## Where the time goes (what is measured)

| What | Measured | Where |
|---|---|---|
| An export frame at 2880x1620 | about 154 ms (6.5 fps, 9x real time) | cloud_render.md |
| ...Movie Maker's MJPEG encode, on the main thread | about 50 of 87 ms (the vortex days; a raw pipe was 2.5x faster, reverted) | cloud_render.md |
| ...Xvfb's presentation | about 13 ms | cloud_render.md |
| A live table frame, playing | 24-32 ms of the app's thread, 14.2 ms of it posing all 282 parts (since fixed: a frame poses only what changes) | framework_audit.md |
| The same table, paused | 6-7 ms | framework_audit.md |
| The episode probe's static table at 1280x720 | 52 ms a frame with ~0 ms of CPU work | table_playback_investigation.md |
| A stepped physics frame | ~10 ms of GDScript (a stirred liquid's level 1.4 ms, its waves 1.25 ms, every vessel pair's dip test 0.9 ms) | framework_audit.md |
| A whole-show bake | 161 s for 345 s of show | framework_audit.md |
| Brick by Brick's Jolt record (a second Godot) | 2.5x real time | assembly.md |

So the user's guess holds for the physics bake, and it held for posing until that was fixed. For an export it is
probably a minority, behind readback, the encode, Xvfb and x264 (cloud_render.md's step 1, measure the split, was never
done). For the picture it is open: the probe's 52 ms with no CPU work and the app's 6-7 ms paused cannot both describe
the same thing, and that has to be settled before any GPU work. And the slowest wait of all, an episode's planning
("hours and hours", framework_audit.md), is agents' time, which nothing here touches.

## 1. Parallel: what we have, and when it helps

Godot gives real threads with no interpreter lock: `Thread`, `WorkerThreadPool.add_task`, and `add_group_task` (one
function over N indices across every core - used nowhere yet). Rendering runs on the main thread (`thread_model` 1,
Godot's default, checked on this install); 2 ("Separate") gives it a thread of its own, which changes when a frame is
drawn and not what, and is worth one measured try.

Per-frame work comes in three kinds, and parallelism helps each differently.

**Pure functions of show time.** The table's poses, a scene's geometry from its feed, a camera, an easing, a liquid's
waves (a stream function of time). Parallel across time and across things, three ways:

- on a worker ahead of need: `FrameForge`'s contract (a static builder over a snapshot), and every bake;
- in a vertex or fragment shader, time handed in as a uniform (already the rule for a shader's clock): exact, and the
  GPU evaluates millions a frame;
- across time, in separate processes: cloud_render.md's spans apply on this one machine too. Two render processes could
  overlap one's readback and encode with the other's GPU work. Unmeasured.

**Simulation.** `TablePhysics`, `Particles`, the Jolt record: the state at t + dt is made from the state at t, so it is
sequential in time. Within a step it can be parallel, with care:

- `Particles` projects its contacts IN ORDER (Gauss-Seidel): each pair moves `_p` in place and the next pair sees the
  move (`Particles._contacts`). Split across threads as it is, the answer would depend on which thread ran first, and
  live must equal export. The deterministic parallel forms: Jacobi with averaging (each particle sums its corrections
  from the substep's starting positions, then takes their average), or coloring (the pairs of one color touch disjoint
  particles). Macklin et al. 2014, the paper `Particles` is built from, ran its solver on the GPU in Jacobi form with
  each particle's corrections averaged. The paper's own form is the parallel one; our port runs it in order. Read it
  again before building.
- ISLANDS: things that touch nothing touching each other step independently, in any order, on any thread, to the same
  bits. Coarse enough for `WorkerThreadPool` (a task per island, several substeps each), and framework_audit.md already
  lists islands as a remaining win for the bake's cost.
- At 240 Hz with a few hundred awake particles, a substep is little work; a task dispatched per substep can cost more
  than it saves. An island per frame amortizes it.

**The render and the export's plumbing.** Readback, MJPEG, Xvfb, x264 and the GPU itself are not our GDScript, and no
thread in our code touches them. The raw-pipe writer (2.5x) and NVENC are already weighed in cloud_render.md, each a
trade-off against the engine's own mechanism.

**The ceiling.** A hot loop spread over every core of a 4-core machine already holding three jobs is about 3x at best.
The language is the bigger lever: the same numeric loop compiled is commonly 10-50x faster than GDScript (a rule of
thumb - measure it on our own loop). A GDExtension (C++ or Rust) is a toolchain per platform, Android included, and a
dependency the project does not have: a choice for the user, never a quiet addition. The engine's bulk calls
(`Transform3D * PackedVector3Array`, one `multimesh_set_buffer` a frame) are the engine-native middle, and already the
pattern.

## 2. The GPU, without networks

Move the exact function before approximating it: a GPU evaluating the true formula usually beats anything evaluating a
network of it.

- **Compute shaders.** Forward+ on Godot 4.7 has `RenderingDevice` (GLSL compute), checked on this install. So is
  `RenderingServer.multimesh_get_buffer_rd_rid`: a compute pass can write the transforms of grains drawn instanced and
  the renderer draws them, with nothing read back. `Texture2DRD` hands a compute result to a material as a texture.
- **`Particles` has the right shape** for it: spheres, a hash grid (`_cell`, `_hash`), passes per particle - the shape
  of every GPU particle solver, in Jacobi form.
- **Liquids' levels and waves are formulas**: a vertex shader, exact. Rigid bodies with contacts (`TablePhysics`'
  solids) are a much harder port than particles.

The traps:

- **Determinism.** The same shader on the same GPU and driver gives the same bits so long as no float sum depends on
  the order threads finish (no atomic float adds; fixed reductions). Across GPUs (a cloud render on another card) it is
  not promised. So a GPU bake would be made ONCE and saved, the record the one truth that live and export both read,
  rather than each process baking its own as now. cloud_render.md already weighs writing the bake's checkpoints to a
  file.
- **Readback.** What the CPU still needs each frame (contact sounds, events, the audit's invariants, the work asking
  where a thing is) comes back over PCIe 3.0 x8 and waits on the GPU. A few thousand spheres' positions are about
  50 KB, small, but a sync point: read a frame late.
- **The phone.** The Mobile renderer has compute; Compatibility does not.
- **The GPU is shared** with the render, and at times with a training job: check `nvidia-smi`, never assume.

## 3. Tiny networks

There is a real world for this. Recent graphics evaluates small MLPs per pixel: neural materials (Zeltner et al.,
"Real-Time Neural Appearance Models", 2023), neural texture compression (Vaidyanathan et al., 2023), neural radiance
caching (Muller et al., 2021), and multiresolution hash encodings (Instant NGP, Muller et al., 2022), which let a tiny
MLP hold fine detail.

**When a network wins - all five at once:**

1. The exact function is expensive: many noise octaves, many shadow taps, an iterative solve.
2. It is smooth, or its detail fits a hash grid.
3. It has a moderate number of inputs, about 4 to 10. With 1 to 3, bake a lookup texture: one filtered fetch beats any
   network and is exact to its resolution. With dozens, the network outgrows the function.
4. It is evaluated many times a frame: per pixel, per vertex, per particle.
5. A small error is invisible, or is checked.

**The cost on this GPU.** A 6 -> 16 -> 16 -> 3 MLP is about 400 multiply-adds. At 2880x1620 (4.7 M pixels) that is
about 1.9 G multiply-adds a frame, and the 5060 Ti's ~23 TFLOPS FP32 does it in a fraction of a millisecond in
principle (more in practice: weights fetched from a buffer, register pressure). Godot's shaders are plain float math:
Godot does not turn on the tensor-core extensions (Vulkan's cooperative matrix and vector), so the networks stay tiny.

**Training.** We hold the exact function, so data is unlimited and free: sample it fresh, never a fixed set. PyTorch is
already in the voice environments (`Deps` rows), but ghost itself needs only the weights, a data file a shader reads. A
gate: the network against the exact function at pinned inputs, a budget on the worst error, and a control (the same
net, its weights shuffled) that must fail.

**The candidates in ghost, ranked honestly:**

- **Shading** - the best fit, if the GPU proves to be the cost: the layered noise of the procedural materials
  (`table_top.gdshader`, `prop_common.gdshaderinc`), the soft shadow filter's taps (`ShadowFilter`). But first ask
  whether a baked texture does it: most procedural material is a function of position on a fixed surface, and a table is
  built once a show, so baking each surface once at build makes a network unnecessary.
- **Liquids' surfaces** - no: a few waves are already a closed form. A vertex shader, exact.
- **Easings, poses, the camera** - no: cheap closed forms.
- **A learned simulator replacing the step** (Sanchez-Gonzalez et al., "Learning to Simulate Complex Physics with Graph
  Networks", 2020) - no. For a few hundred particles the exact step, compiled or on the GPU, is cheaper than a graph
  network; errors compound over thousands of steps; and the invariants (nothing interpenetrates, a heap at rest stays at
  rest) become things it mostly does. Here the solver is the truth.
- **The step as parareal's coarse guess** - the one way a network breaks the sequence in time without changing the
  answer. Parareal (Lions, Maday and Turinici, 2001): a cheap coarse solver guesses the state at the start of each span;
  the exact solver runs every span at once from those guesses; a sweep corrects the guesses; repeat until the span
  boundaries stop moving. The result converges to the exact solver's, so the network buys speed and never truth. Agboh,
  Grainger, Ruprecht and Dogar, "Parareal with a Learned Coarse Model for Robotic Manipulation" (2020), did it for
  objects pushed on a table, which is close to ours. The catches: contacts are not smooth and slow its convergence (with
  P spans and K iterations it is at most P/K times faster, and every iteration is a full solve's worth of parallel
  work); and converged means to a tolerance, not bit for bit - fine for a record saved once, wrong while each process
  bakes its own.

## What to do, in order

### 1. Measure the split

Status: not started.

An export, per frame, on a pinned span: our GDScript, the render's CPU side, the GPU, readback, MJPEG, Xvfb, x264
(`WorkClock`, `viewport_get_measured_render_time_cpu/gpu`, the medium frame-cost method in the debugging notes). The
live table: the episode probe's `--profile=T`, and the probe's 52 ms settled against the app's 6-7 ms. Try `thread_model`
2 once. This decides which steps below are worth anything; it is cloud_render.md's step 1 too.

### 2. Pure functions of time onto the GPU, exact

Status: not started.

Whatever the CPU writes per vertex each frame and could be written as a formula of show time: liquids' surfaces first.

### 3. Islands for the bake, on worker threads

Status: not started.

`add_group_task`, deterministic by construction. A gate bakes threaded and on one thread and compares them bit for bit
(physics_check's `_threaded` has the shape).

### 4. Particles as a compute shader

Status: not started.

In Jacobi form, drawn straight from the buffer it writes, its record made once and saved.

### 5. Compiled code for the one hottest loop

Status: not started. A choice for the user (a toolchain and a dependency).

### 6. One tiny-network experiment

Status: not started.

On a measured expensive shader function that a texture cannot hold: fit it, compare milliseconds and the worst error,
and look at the picture.

### 7. Parareal with a learned coarse step

Status: not started. Only if the bake is still the wait after 3 to 5.

## Open questions for the user

- Is the slowness you feel the export, the live picture, the bake, or the agents? Step 1 will say, but your sense of it
  picks what to measure first.
- A GDExtension in a compiled language, for 10-50x on a hot loop: acceptable as a dependency?
- A bake made once and saved, the one truth both live and export read, instead of each process baking its own: it is
  what a GPU or parallel solver needs for live to equal export. Acceptable?

## Sources

- Macklin, Muller, Chentanez and Kim, "Unified Particle Physics for Real-Time Applications", SIGGRAPH 2014.
- Lions, Maday and Turinici, "A 'parareal' in time discretization of PDE's", 2001.
- Agboh, Grainger, Ruprecht and Dogar, "Parareal with a Learned Coarse Model for Robotic Manipulation", Computing and
  Visualization in Science, 2020.
- Sanchez-Gonzalez et al., "Learning to Simulate Complex Physics with Graph Networks", ICML 2020.
- Muller, Evans, Schied and Keller, "Instant Neural Graphics Primitives with a Multiresolution Hash Encoding", 2022.
- Muller, Rousselle, Novak and Keller, "Real-time Neural Radiance Caching for Path Tracing", 2021.
- Zeltner et al., "Real-Time Neural Appearance Models", 2023.
- Vaidyanathan et al., "Random-Access Neural Compression of Material Textures", 2023.
