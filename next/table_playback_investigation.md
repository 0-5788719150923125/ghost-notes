# Table playback investigation, 2026-10-31

Feedback `0001` reports jars still moving in pairs. Feedback `0002` reports a ladle entering the pot, coming out,
and entering again. Investigated the current working tree, including the existing unstaged fixes, and a copy of
The Quiet Crucible #841899 using `take_585248.json`'s saved word timings. The author's episode and settings were
not edited. A saved take is reproducible evidence; its timings need not be those of a new live voice session.

## Causes and changes

The paired jars were programmed behavior, not an unstable collision. `TableWork._trips` split a collection with no
carrier into two-object trips, squeezed into the original group's duration. `build` then inferred a shared hand
and rigid relative motion from identical track dictionaries. Two independent objects could therefore become
kinematically attached simply because they had matching animation commands.
The feedback also records the bake ahead of playback (`baked_to` 258.93, audio time 248.29, `outran` false), so a late
bake does not explain this report.

Collection moves now take one object per trip. Each trip keeps the original move's time, the act grows accordingly,
and the scheduler preserves that minimum even when the passage is short. `parts_report` identifies collections
before the puppeteer writes its acts; the rules tell it to fetch the individual part needed. Existing episodes
remain playable through the generic collection expansion. Four jars on a real carrier can still ride it together.
The legacy four-jar fetch takes 20 seconds instead of five. Moving only the needed jar is preferable when authoring
new work; the runtime does not guess which ingredient a script intended.
An existing recording can consequently narrate ahead of an expanded legacy move. Preserving physically separate
trips cannot also preserve an undersized group time budget. For strict synchronization, author individual fetches
or regenerate the work/reading with enough time; the replay below validates motion, not revised narration.

Matching commands no longer produce a kinematic attachment. A real joint or physical seat supplies the relationship.
For a seated cork carried with its jar, the physics compares their original commands before automatic clearance:
the jar's foot may need a higher path than its cork, so comparing the corrected paths can falsely decide that the
cork is being taken out. This matching is restricted to an actual geometric seat. Without that seat, equal paths
leave the objects independent. There is one physical constraint rather than a separate kinematic weld.

There was also a scheduler ordering bug. A word cue replaced the previous act's end instead of respecting it. In the
saved replay, `ash-pinch` began at 474.18 seconds while `ash-uncover` ran from 475.41 to 477.91. The acts affected
different channels, so the channel conflict check did not help. A cue is now the earliest requested start; the
preceding act in the beat must finish first, including when its cue has not yet arrived. This enforces the order promised to
the puppeteer without having to infer every semantic dependency between an opening and its contents.

The ladle report exposed a different generic rule. Every aim/circle entry added an obstacle-clearing arc over its
first 0.8 seconds. A ladle left leaning inside a pot was lifted roughly ten centimeters when stirring resumed, then
lowered back into the brew. A tool whose contact point starts and ends inside the same vessel now resumes without
that extra lift. Reaching from outside retains the entry arc; whole-body collisions still apply. Vessel poses come
from the caller's work/timeline, never the other thread's mutable solid transforms.

Feedback pose snapshots now use table coordinates through `_world_of`, matching the rest of the work. Calling
`global_transform` on tables built outside the scene tree had emitted engine errors during the physics tests.

## Launch diagnostics and performance

The quoted launch log contains no engine exception. The collection lines describe the fallback above. "Behind the
show" / "caught up" describe the asynchronous bake, including its initial startup. The governor reports expensive
rendered frames and reduces their frequency. Removing these messages would not repair the underlying work.

The episode probe now supports `--profile=T`: bake first, warm up rendering, then separately measure static rendering,
work updates, and complete medium updates. On the RTX 5060 Ti with Forward+, at 1280x720 around second one:

| Probe mode | Measured CPU work | Wall time per frame |
| --- | ---: | ---: |
| Static table, playback updates stopped | ~0 ms | 52.30 ms |
| Work updates | 13.03 ms | 58.02 ms |
| Complete medium updates | 16.60 ms | 62.01 ms |

These are probe measurements, not the user's full application frame times. They show a substantial rendering cost
even without simulation/playback updates. The animation fixes do not solve it. Further performance work should
separate shadow passes, procedural materials and geometry with controlled comparisons, then reduce the measured
cost while checking the picture. Changing physics tolerances or collection batching to hide render stalls couples
unrelated systems and makes the motion less reliable.

## Regression coverage and replay

`physics_check` covers independent sequential jars versus a real tray, preserved trip durations under a short
reading, physical seating versus identical unconnected paths, and inside/outside vessel entry transitions.
`table_work_check._cue_order` covers early and unheard cues on different channels. The saved episode's ladle
transition was also baked through second 38: the artificial rise disappears, while the ladle still straightens
from its resting lean into its stirring pose.

The same saved episode was baked through second 245. Its original four-jar fetch now runs 223.57-243.57 seconds:
at seconds 225, 230, 235 and 240 respectively, amber, dragon's blood, frankincense and myrrh are the jar in transit.
The others wait on the shelf or stand where they were set down. All four finish upright. This checks the legacy
fallback on the actual generated geometry and authored path, in addition to the small fixtures.

The episode probe's report loop now respects `--from`/`--to`; it previously baked every later act to produce reports
even after a bounded replay had finished sampling. Use separate `--copy` directories for concurrent replays.

Final validation:

- Full headless run: 156 of 157 gates passed in 16m28s, including the complete physics, live-work and placement gates.
  `sand_settle_check`, unrelated to these changes, hit the runner's 300-second timeout under concurrent load. The same
  check passed when rerun with a 600-second timeout, with no code changes. The full-run command therefore returned
  failure; the retry's result is recorded separately rather than calling that run green.
- Targeted GPU gates `table_thread_check` and `puppeteer_tools_check`: both passed.
- `python docs.py --check`: no warnings. `git diff --check`: clean.
- Saved-episode replays: ladle through second 38, jars through second 245, and the warmed Forward+ playback profile.

Logs are under `dist/`: `investigation_checks.log`, `sand_settle_retry.log`, `investigation_gpu_checks.log`,
`crucible_ladle_after.log`, `crucible_jars_after.log`, and `crucible_render_profile.log`.

Example commands (the take must already exist):

```sh
godot --headless --path . --script res://tests/table/physics_check.gd -- \
  --only=_jars_apart,_carried_with,_seat_rides,_tool_entry
scripts/check.sh --only table_work_check,table_work_live_check
GHOST_PROBE_GPU=1 tests/run_boot_probe.sh tests/table/episode_bake_probe.gd 240 \
  --take=user://generative/take_585248.json --profile=1
```

For future fixes, keep three boundaries explicit: the authored action and its duration, the physical body's identity
and constraints, and the frame being presented. Test the independent case alongside the supported/attached case,
and replay real word timings alongside small solver fixtures. A new heuristic should not silently change another
boundary to make its own test pass.
