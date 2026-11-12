# Table playback investigation, 2026-10-31

Two reports of table playback: jars moving in pairs, and a ladle entering the pot, coming out and entering again. The
investigation ran on the working tree and on a copy of a saved episode with its saved word timings (`take_585248.json`).
A saved take is reproducible evidence; its timings need not be those of a new live voice session.

## Causes and changes

- **Paired jars were programmed behavior, not an unstable collision.** `TableWork._trips` split a collection with no
  carrier into two-object trips squeezed into the original group's duration, and `build` then inferred a shared hand and
  rigid relative motion from identical track dictionaries. Matching commands could attach two independent objects. The
  bake was ahead of playback, so a late bake does not explain it.
- **Collection moves take one object per trip.** Each trip keeps the original move's time, the act grows accordingly, and
  the scheduler preserves that minimum even when the passage is short. `parts_report` identifies collections before the
  puppeteer writes its acts; the rules tell it to fetch the individual part needed. Existing episodes stay playable
  through the generic collection expansion; four jars on a real carrier can still ride it together. The legacy four-jar
  fetch takes 20 seconds instead of five, so an existing recording can narrate ahead of an expanded legacy move. For
  strict synchronization, author individual fetches or regenerate the work or reading with enough time.
- **Matching commands no longer produce a kinematic attachment.** A real joint or physical seat supplies the relationship:
  one physical constraint, not a separate kinematic weld. For a seated cork carried with its jar, the physics compares
  their original commands before automatic clearance (the jar's foot may need a higher path than its cork, so comparing
  the corrected paths can falsely decide the cork is being taken out). This matching is restricted to an actual
  geometric seat; without one, equal paths leave the objects independent.
- **Scheduler order.** A word cue used to replace the previous act's end instead of respecting it (an act began while the
  previous one on another channel was still running). A cue is now the earliest requested start; the preceding act in the
  beat must finish first, including when its cue has not yet arrived.
- **Tool entry.** Every aim/circle entry added an obstacle-clearing arc over its first 0.8 seconds, so a ladle left
  leaning inside a pot was lifted about ten centimeters when stirring resumed. A tool whose contact point starts and ends
  inside the same vessel now resumes without that lift. Reaching from outside keeps the entry arc; whole-body collisions
  still apply. Vessel poses come from the caller's work/timeline, never the other thread's mutable solid transforms.
- **Feedback pose snapshots** use table coordinates through `_world_of`; `global_transform` on tables built outside the
  scene tree emitted engine errors in the physics tests.

## Launch diagnostics and performance

The launch log's collection lines describe the fallback above; "Behind the show" / "caught up" describe the asynchronous
bake, including its startup; the governor reports expensive rendered frames and reduces their frequency. Removing the
messages would not repair the underlying work.

The episode probe supports `--profile=T`: bake first, warm up rendering, then separately measure static rendering, work
updates and complete medium updates. On the RTX 5060 Ti with Forward+, at 1280x720 around second one:

| Probe mode | Measured CPU work | Wall time per frame |
| --- | ---: | ---: |
| Static table, playback updates stopped | ~0 ms | 52.30 ms |
| Work updates | 13.03 ms | 58.02 ms |
| Complete medium updates | 16.60 ms | 62.01 ms |

These are probe figures under a virtual display (see the last section), not application frame times. Changing physics
tolerances or collection batching to hide render stalls couples unrelated systems and makes the motion less reliable.

## Regression coverage and replay

- `physics_check` covers independent sequential jars versus a real tray, preserved trip durations under a short reading,
  physical seating versus identical unconnected paths, and inside/outside vessel entry transitions.
- `table_work_check._cue_order` covers early and unheard cues on different channels.
- The saved episode's ladle transition baked through second 38: the artificial rise is gone, and the ladle still
  straightens from its resting lean into its stirring pose. Its legacy four-jar fetch (223.57-243.57 s) shows one jar in
  transit at a time, and all four finish upright.
- The episode probe's report loop respects `--from`/`--to`. Use separate `--copy` directories for concurrent replays.

Example commands (the take must already exist):

```sh
godot --headless --path . --script res://tests/table/physics_check.gd -- \
  --only=_jars_apart,_carried_with,_seat_rides,_tool_entry
scripts/check.sh --only table_work_check,table_work_live_check
GHOST_PROBE_GPU=1 tests/run_boot_probe.sh tests/table/episode_bake_probe.gd 240 \
  --take=user://generative/take_585248.json --profile=1
```

For future fixes, keep three boundaries explicit: the authored action and its duration, the physical body's identity and
constraints, and the frame being presented. Test the independent case alongside the supported/attached case, and replay
real word timings alongside small solver fixtures. A new heuristic should not silently change another boundary to make its
own test pass.

## Why a table plays in hitches (2026-11-10, corrected 2026-11-11; Joker Motivation 732687)

Complex scenes such as Joker Motivation episodes hitch near-constantly in playback. It is not pixels.

- **The live stage is 1920 x 1080 at any window.** The window stretches its canvas (`canvas_items`, 1080 units high), and
  the stage is the frame in those units (`main._frame_rect`). A 4K window scales that picture up; it never draws four
  times the pixels.
- **Figures must be taken with nothing else on the card.** A training run, a probe that outlived its timeout, or a virtual
  window so large it copies five frames a second all inflate them. `tests/table/table_render_probe.gd` says what uses the
  card as it starts, and shrinks its window. A probe under `xvfb` presents through it (40 ms a frame of wall for a stage
  that takes the card 3.5), so the 52 ms above is the virtual display.

**What a table frame costs, measured clean** (that probe; take `take_352946`, a still frame at 150 s):

| The stage at | Graphics card, a frame |
|---|---|
| 1280 x 720 | 3.5 ms |
| 1920 x 1080 (what the viewer draws) | 6.2 ms |
| 2560 x 1440 | 9.8 ms |
| 3840 x 2160 | 20.1 ms |

At 1920 x 1080 with one thing out: no multisampling (it is 4x) 5.0; no shadows 4.7; no glow 5.6; no bounce light 5.8; no
ambient occlusion 5.9; no volumetric fog 6.0; all of those out together 2.0. The paint's two canvases (750 x 1050, redrawn
every frame) add 1.1 ms; a 4K window's own pass with the note's Look, 0.5 ms. Playing: 6.0 ms of card, 0.8 ms of the
renderer's processor, 5.2 ms of our script (2.7 by the thread's own clock, `episode_bake_probe --live`, worst frame 22
ms): about 8 ms of card and 6 of the app's thread, well inside a 160 Hz display's two refreshes. It is not the table's
code, its geometry (70 draw calls, 141,408 triangles seen, 501,635 in shadows) or its pixels.

**What the app's own log has:** frames 24 to 29 ms apart whenever the stage was drawn every frame, and 6 to 14 ms once it
was drawn every other. A frame slow drawn every time and quick drawn every other time is not slow on the app's thread:
something was waited for. What was waited for is not established. Candidates: the card shared with a training run or an
export, and the processor shared with the live voice (Kokoro on all but one core; the probes play a take and run no
voice). The app now logs it when it happens, with the stage's time on the card.

**The governor made hitching of it.** It read the whole frame's time (`delta`) and took 25 ms for a heavy scene; drawn
every other frame the stage's frames read 6 to 14 ms, so it let go, met the same 25 ms and throttled again (185 changes of
level in one session).

What is built:

- **The governor reads the app's thread alone** (`StageGovernor`, `src/render/stage_governor.gd`: from a frame's first
  `_process` to the moment the renderer takes it). A scene heavy in script is spaced out (in the real loop `terrain_city`
  climbs to one frame in six, `snowfall` to one in three); a frame slow for the card's sake is left alone.
  `tests/render/stage_governor_check.gd`; its control is the old reading, which hunts 46 times a minute.
- **It says what it will not throttle for**, once a scene: `ghost: frames are N ms apart and this thread spends M ms of
  that ...`, with the stage's size and its time on the card.
- **Resolution, on the Graphics menu** (`Graphics.stage_size`): 720p, 1080p (the default), 1440p, 4K - the viewer's alone;
  an export is drawn at its own size.
- **A probe that times out no longer stays on the card.** The timeout in `tests/run_boot_probe.sh` is inside the virtual
  display, Godot its own child.

Open:

- What the frames waited for. The next session with a table up says it in the log; if the card is free and the line still
  appears, measure a live reading's frame (the voice is next).
- Lesser: the paint's canvases drawn only as paint is laid (1.1 ms), multisampling 2x (0.5 ms).
- A scene costing the thread 14 to 24 ms stays at whatever level a build's long frame put it at until the next cut
  (`starfield`: 16 ms, held at one frame in two).
