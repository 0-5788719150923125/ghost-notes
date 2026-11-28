# Plan: a stricter framework

**Status.** Drafted 2026-11-28 from `next/shared_primitives.md`, checked against the tree at `a6e9429`. Nothing is built yet.
It waits for the decisions in section 9 and a go.

**The goal.** Make the right way the easy way and the wrong way loud. A feature should be built once and reach every room
that uses it. Its card and its scene should come from one declaration. When something is left out, a check should fail before
an export does. The user should not be the framework's test suite.

---

## 1. Is the audit right?

Mostly yes. Every concrete claim checks out against the code, and several understate the problem. Two helpers did the
duplication checks on their own; I traced the card and scene contracts myself.

| Audit claim | Verdict | What the code shows (and what the audit missed) |
| --- | --- | --- |
| Camera: an unknown, unset field reads as zero, and the card gate supplies the registration itself | TRUE | `Cameras.value` falls back to `0.0` for any key a sort does not declare (`src/motion/cameras.gd`). `camera_card_check` calls `Director.see_cameras(TableMedium.cameras_seen(true))` itself, so it passes even if production stops registering. Registration also happens in two places: `table.gd` through its feed, and `episode_card.gd` through the Director. |
| Show sounds: the provider is installed apart from playback, and the base returns `[]` | TRUE | `StudioFormat` installs `Heard` on the panel. Playback gets levels only because `_redress_live` writes them into the live document and `StudioMedium._ensure_doc` reads them back each frame. |
| Environment: Studio dresses fog, rays and air in its own method | TRUE, understated | Dressing is written **four times**: `DeskMedium._dress`, `PopupMedium._dress_desk` (a copy of the desk's), `DispatchMedium._dress_environment` and `StudioMedium._dress_environment`. Each has its own constants and lifecycle. Table has a fifth path of its own. |
| Studio placement is a working model of agent/author parity | TRUE | `StudioSet.PLACE_FIELDS` and `StudioFormat.set_place` serve both the card and the refine agent. This is the pattern to copy. |
| The flip screen was missing in the export, and no gate can see it | TRUE | Studio's gates check script parsing, act lanes and lens geometry. Nothing compares a live frame to an exported one. Last night's remount (`_mount_screen` from `advance`) is unverified against an export. |
| Medium variants: Auto adds nothing, and `Medium.make` loads a script that can do anything | TRUE | That freedom is what lets each format re-solve shared problems. |
| Table: `_make_twin` copies 20+ fields, and `rebind` refreshes a subset | TRUE | 21 fields, 9 of them private. `_solids_ref` and `_liquids_ref` are set in two other places. **Missed: a live stale-cache risk.** The twin's `_still_of` is never cleared on rebind, so a table with no rigid parts keeps stillness worked out under the old acts. |
| Props: five copies of the thumbnail loop | TRUE, understated | **Six** identical `_asked` bodies (`desk_recipes.gd` too), plus duplicated `want_pictures`, `prepare_pictures`, `picture` and spec caches. Role choice is copied **three** times (Desk skips the fit check), and `choices()` is near-identical. |
| Three word matchers can disagree | TRUE, with gaps | Only `ReadingFollower` takes a one-letter word at the cursor. **Missed:** Book's 12-word window counts layout words, so it reaches less far than Tablet's. Notebook and Pop-up inherit Book's matcher. `ReadingFollower`'s restart drops its estimate. Dispatch's `_page_follow` is a fourth matcher of a different kind. |
| Table and Dispatch share synthesis bodies | TRUE, understated | `_sine`, `_burst`, `_drop_voice` and `_drop_burst` match, and so do `_rand`, `_noise`, the voice and burst arrays, and the mixing loops. |
| Godot and Piper share the pause curve | PARTLY | The formula and constants match up to a dial of 10. Godot clamps there and Piper does not. Nothing compares the two numerically. |
| Studio sanitizes and serializes settings on every frame | TRUE, and it is everywhere | **Seven** media have an `_ensure_doc` that re-reads the untyped document each frame and compares JSON or hash keys: studio, dispatch, desk, letter, episode desk, tablet and table. |
| A single layout controller would buy little | Agree | Choosing a prop for a role is the repeated operation, not layout. |

## 2. What the audit missed

These are the findings closest to last night.

1. **Every one of last night's fifteen reports is a generic motion invariant, and only Table checks for those.** Things
   passed through each other or the eye (0008, 0011, 0013). Things moved too fast, arrived at once, or whipped back and forth
   (0010, 0012, 0015). A held thing was frozen (0009). Two instances moved identically (0001 the steam, 0014 the blocks). Things
   popped in and out in view (0010, 0013). Table has `episode_bake_probe --audit` for this class. Studio has nothing, so each
   report was fixed by hand in `studio.gd`, and each fix made the next report.
2. **Studio's corrections break "the same motion is seen and heard."** The eye push (up to 25 cm), the fur clearance and the
   hand sway are all applied in `_pose` at frame time. The act's sound was already made from the motion before them
   (`StudioSounds.make_all` knows nothing of them). A knock you see moved is heard where it was. The correction also runs on the
   app's thread: `_clear_of_eye` samples 13 moments, and each one walks every act for both blocks, every frame.
3. **The unison bug has a structural cause.** `_hands_sway` drives both blocks from one seed (`HELD_SEED`, "the pair as one").
   `Gesture` already has seeded held motion (`idle`, `tremor`, `wave`), but nothing makes two things' seeds differ.
4. **Polling against a standing rule.** `StudioFormat` reads the script's and take's modified times every 0.5 s. `StudioMedium`
   polls `table.json` every second. The Environment card polls its own state every second.
5. **Controls built by hand.** The Environment card's new Level row is a hand-built slider, not a schema row. Studio's
   `LEVEL_LEAST`/`LEVEL_MOST` repeat `Surroundings`'s.
6. **One feature, four copies of its state.** These are the note's block, the card's knobs, the live document and the take's
   book. They are joined by hand: `capture`/`apply`, `_redress_live` (copied in the studio, pop-up and desk formats),
   `document_parts`, `freshen_document` (added last night for exactly this class) and seven `_ensure_doc`s.
7. **The unattended fix prompt asks for the narrow fix and no proof.** `Assistant._build_prompt` says "scope the fix to what's
   actually reported" and asks for no verification. That is the opposite of "a reported instance is a class."
8. **Silent fallbacks go beyond Cameras.** `Medium.uses` answers true for an unknown medium. `ShowSounds` answers `[]` by
   default. A `Filters` key with no uniform is a silent no-op that CLAUDE.md documents as a trap instead of failing.
9. **CLAUDE.md is 483 lines and 7,900 words, mostly status,** while saying it stays short. A dispatched run with a narrow task
   cannot hold that many rules, so the ones that matter get lost.
10. **A duplicate scan found nine groups of identical function bodies of 8+ lines** across files. Among them: versions
    `_write` (environment and delivery), designer `_on_chat` (environment and delivery), library `entries`, `_redress_live`, and
    `_size_of` (YouTube and TikTok).

## 3. Why these problems exist

1. **Shared helpers share computation, not responsibility.** `Surroundings.rays`, `fog_for`, `effects_of`, `Gesture.idle` and
   `Cameras.sway_at` are good static helpers. But each medium still decides which ones to call, in what order, when to call
   them again, and what to release. That orchestration is where omissions live. Adding a fog kind to the registry reaches only
   the rooms whose code happens to call the right helpers.
2. **The Medium contract never grew.** It was designed as four vetoes so the Director could cut scenes. Formats are now whole
   worlds (sets, props, cameras, environment, sounds, acts), but the only channel into them is `bind_captions(subs)` and an
   untyped `subs.document`. So every medium re-derives everything, every frame, with its own change detection.
3. **Rules that are checked hold, and rules in prose drift.** `docs.py --check` enforces the folder stack, and `UPWARD` is still
   empty. That rule has never slipped because a machine holds it. "No polling", "a field is a row, never a control" and "fix the
   class" are prose, and all three slipped last night.
4. **Gates share the blind spots of the change they test.** A feature's gate is written in the same session that wrote the
   feature, so it encodes that session's model (the camera gate registers the cameras itself). Nothing checks the composed
   output generically, independent of how a feature was built. So each export is the first full test.
5. **The unattended loop optimizes locally.** The prompt asks for the narrow fix and gives the run no audit to check against.
   Each run makes its report go away and moves the problem: repulsion led to blocks too close, then through the fur, then
   arriving together, then through the head, then moving in unison, then whiplash.

## 4. Principles

- **P1. A feature is one part that owns its whole life:** fields, defaults, sanitizing, applying, ticking and releasing.
  A scene hands it inputs (its world, bounds, light, camera) and never calls its pieces.
- **P2. Card, scene and agent tools come from one declaration,** and the saved block is the only data between them. Exports run
  in a second process, so "the same instance" means the same part definition over the same data.
- **P3. An unknown name is an error.** A misspelled field, an unregistered sort or an unknown medium fails loudly: at runtime
  with `push_error`, and before that in `docs.py` wherever the name is a literal.
- **P4. Generic checks look at the output:** a motion audit over show time, live against export, and card round-trips. Each
  iterates the registries, so a new kind or format is covered without being listed. A second list of features to remember
  would repeat the oversight.
- **P5. A rule that matters is a check.** Each line of the framework contract (workstream M) names the check that holds it.
- **P6. Nothing is worked out again per frame unless it changed.** A version number marks a change. The disk is read when it
  changes, by whoever owns the file.
- **P7. A fix lands in the part that owns the class,** never only in the instance reported.

Together these ask less of agents and authors. An agent has fewer things to remember, because a part does the remembering and a
check catches the miss. An author has fewer controls to hunt for, because a card is derived from the same declaration the scene
uses.

---

## 5. Workstreams

Each workstream has a goal, the change, the files it owns, and what proves it.

### A. The show audit (the net for last night's class)

- **Goal.** One audit, run before anyone is asked to watch, that checks the composed show over time in any format with a set.
- **Change.**
  - `ShowAudit` holds pure checks over frames of samples, in `motion/`. Each kind of wrong is a registry row with a threshold
    and a blurb:
    - `through`: two things inside each other past an allowance. A pair touching as the set was built is said apart, as Table's
      audit does.
    - `eye`: a thing's nearest surface closer to the eye than its clearance, or crossing the near plane.
    - `speed` and `accel`: a thing in shot over its caps.
    - `reverse`: whiplash, a high speed reversing within a short window.
    - `pop`: a thing appearing or vanishing while inside the frustum.
    - `still`: a held thing perfectly still for over a second and a half.
    - `unison`: two things of one kind whose motion correlates above 0.97 over a few seconds while both move. This catches
      matching onsets too.
  - A sampler beside `PropRig` (in `table/`) reads every `PropRig` and the current camera of a mounted medium. It works for any
    medium, because every thing a scene works is a prop. `PropRig` gains one flag, `held`, which a medium's pose sets.
  - A probe drives a real format over show time headless with a driven feed, no GPU, and prints each wrong once per stretch
    with its worst value and when. The episode is copied read-only to `dist/`, like `episode_bake_probe`.
- **Gates.**
  - `tests/motion/show_audit_check.gd`: each rule on synthetic streams, with a planted violation that must fail and a clean
    stream that passes.
  - `tests/studio/studio_audit_check.gd`: a fixture studio show passes. Controls that must fail: a block driven through the
    eye, and both blocks given one seed.
  - Every format whose row has a set (`own_set` or `mode`) must answer the audit, or carry an `audit_skip` row field saying why.
    The gate fails a format that does neither, so a new format is covered without being listed.
- **Order.** Studio first, then Dispatch (phones to the ear, the mug). Table keeps its deeper audit; its samples feed the
  generic rules later.

### B. Studio motion: one corrected track, made off the app's thread, seen and heard

- **Goal.** Close last night's class at its source. Studio's things move by one deterministic track per thing, and both the
  picture and the sound read that track.
- **Change.**
  - Move hand-offs, rests, bring-ins, keep-outs and sway out of `StudioMedium._pose` and into the worker that makes the acts.
  - Add a shared `KeepOut` primitive in `motion/`. It corrects a sampled track against moving volumes (the eye's path from
    `HeadPlan`, the windscreen's ball, another thing). The push is smooth, low-passed over a window either side, and
    speed-limited. Studio's current logic is the first case, generalized.
  - Add a speed and acceleration limiter beside it.
  - Make it impossible to share seeds by accident: held motion takes the thing's key (`Gesture.held_of(key, seed, t)`), so each
    hand sways on its own.
  - Contact lanes are made from the corrected track. Each sound window is corrected with the head plan known when it is made.
    A window whose correction changes gets a new key and is made again; in an export everything is known up front.
- **Fallback.** If remaking live windows proves too costly, keep the corrections at pose time but compute them on the worker
  into a ready-ahead track. That still fixes the frame cost. The gap between seen and heard is then listed as open.
- **Files.** `studio.gd`, `studio_acts.gd`, `studio_sounds.gd`, `studio_format.gd`, `gesture.gd`, new `motion/keep_out.gd`.
  This agent also moves Studio onto D's environment part and removes Studio's disk polling (F).
- **Proof.**
  - The studio audit (A) is clean on the reference episode, the one exported four times.
  - A gate checks that the position each contact lane was made from equals the drawn position within 1 cm at sampled times.
  - `advance` costs no more than a lookup per thing, measured with `tests/work_clock.gd`.

### C. Live equals export (the flip screen and every secondary view)

- **Goal.** A picture sampled from a second viewport is a required input to the frame, in the live show and in the export.
- **Change.**
  - First reproduce the blank screen with the production exporter on a short, low-resolution studio fixture, and find the
    cause. Do not assume last night's remount fixed it.
  - Then add a small contract in `scene_kit/`. A medium that puts a viewport's picture on a visible surface registers it. The
    show holds (`ShowFeed.wait_for`) until each newly bound view has drawn. The export reports a render error if a required
    binding fails.
- **Gate.** `tests/export/screen_export_check.gd`, on the GPU list. A moving target visible only to the lens is exported and
  decoded at two times, and the screen face is checked for the target in both places, with a local tolerance. Controls that
  must fail: the lens feed blanked with REC and the meters still drawn, and the first frame frozen. It is run again after a
  stop and a play. The Dispatch `behind` camera's screen follows the same contract second.

### D. One environment part (`EnvironmentRig`)

- **Goal.** A new fog look, shaft or air kind reaches every room by default.
- **Change.**
  - `EnvironmentRig`, in `table/` beside `Surroundings`, owns the whole lifecycle: brightness, shafts and beams with their
    ticking, fog, air, each lit thing's share, the heard levels, applying a change, and releasing.
  - A host hands it inputs once: `env`, `root`, air regions, shaft geometry (toward, onto, reach, default color), the air's
    camera, fog length, and a hook for a light of its own (Dispatch's crack).
  - The episode's elements are handed in through the panel or episode feed when `table.json` changes, never polled.
  - Desk, Pop-up, Dispatch and Studio each keep only their constants as inputs. Table stays behind its own interface.
- **Gate.** `tests/table/environment_rig_check.gd` covers every format that mounts a rig, times every registered element kind.
  Each kind is added through the card's real operation, saved and reopened, and the mounted rig must show a non-default field.
  Control that must fail: a rig whose apply skips fog. A new kind or room is covered without being listed.
- **Files.** New `table/environment_rig.gd`; `desk.gd`, `popup.gd`, `dispatch.gd`. Studio moves over in B.

### E. Strict names, and one camera registration

- **Goal.** Unknown names fail loudly (P3).
- **Change.**
  - `Cameras.value` reports a key its sort does not declare.
  - Field groups are declared once: a sort with `sway` has `sway_speed` too, held by `docs.py`.
  - `Medium.uses` reports an unknown medium or an unknown feature group.
  - The `ShowSounds` base reports `sounds()` not overridden.
  - A `Filters` key with no `u_<key>` uniform fails `docs.py`, replacing the trap note in CLAUDE.md.
  - Camera registration has one source. The card reads the format's own static answer (`TableMedium.cameras_seen`), and
    `camera_card_check` opens a real note whose episode wants a game, never calling `see_cameras` itself.
  - Extend `docs.py check_fields` to nested `fields` (Cameras sorts, Surroundings kinds), so a literal key passed to `value`
    must exist.
- **Files.** `cameras.gd`, `medium.gd`, `show_sounds.gd`, `episode_card.gd`, `camera_card_check.gd`, `docs.py`
  (`check_fields` only).

### F. One live document: versions, one publish path, no polling

- **Goal.** No medium re-derives an unchanged document. No card hand-copies its block into the live document.
- **Change.**
  - The live document carries a version per block, bumped by its one writer.
  - `ReadingPanel.publish_live(key, data)` replaces every `_redress_live` (studio, pop-up, desk and dispatch formats).
  - Each `_ensure_doc` returns early on unchanged versions and re-applies only the blocks that changed.
  - Remove the polls: `StudioFormat` hears the script and take from `EpisodeFeed` when they change, the Environment card works
    out `_hears` when its spec or the bed changes, and Studio's `table.json` poll goes away with D.
- **Order.** I land the small API myself first (about 15 minutes), then each medium's owner adopts it.

### G. Block schemas for formats (Studio first)

- **Goal.** One declaration of a format's block feeds `capture`, `apply` and sanitizing on the card, and the medium's reading
  of it.
- **Change.** Studio's `takes`, `makes`, `places`, `marks` and `levels` become one rows table (`StudioBlock`), with the
  existing `levels_of`, `makes_of` and `marks_of` as its readers. Card controls for ordinary fields come from `SchemaForm`.
  The Environment Level becomes a schema row, not a hand-built slider.
- **Order.** Studio and Environment tonight. The other formats follow once the shape has proved itself.

### H. Props: one picture loop, one role choice

- **Change.**
  - The picture plumbing (`_asked`, `want_pictures`, `prepare_pictures`, `picture`, the spec cache) moves into `PropSection`,
    or `ShelfSection` where a shelf extends that instead.
  - Role choice becomes one operation, `PropMakes.choose_kept(role, name, current)`, returning the choice, whether it changed,
    and why not. It is used by Dispatch, Studio and Desk. Its misfit message comes from `PropMakes.missing`, which names both
    faces and needs.
  - `choices()` becomes one helper.
- **Gate.** A refined make missing a required feature keeps the old choice and names what is missing, for a studio role and a
  dispatch role.
- **Files.** `prop_section.gd`, `shelf_section.gd`, `desk_props.gd`, `dispatch_props.gd`, `studio_props.gd`,
  `library_props.gd`, `make_shelf.gd`, `desk_recipes.gd`, `prop_makes.gd`.

### I. One word matcher

- **Change.**
  - Characterize first. A gate records today's behavior of all three matchers on one-letter fragments, a repeated word after a
    seek, a take that restarts, split words, and Book's layout-word window.
  - Then extract the cursor, window and split-word rules beneath Book, Tablet and `ReadingFollower`. Each keeps its own index
    mapping and seek. Apply one rule (see decision 1).
  - Fix `ReadingFollower`'s restart dropping its estimate.
- **Files.** `reading_follower.gd`, `book.gd`, `tablet.gd`. Notebook and Pop-up inherit the change.

### J. One synth kit, one pause table

- **Change.**
  - `SynthVoices`, in `audio/`, holds the voices, the bursts, their arrays and mixing loops, `_rand` and `_noise`. It is
    parameterized by its caps (40/12 against 48/32), the pan function and the seed. Table and Dispatch use it.
  - The pause curve's cases (dial, dwell, expected rest) go in one shared data file that both the Godot and the Python suites
    read. Piper clamps the dial at 10 (see decision 2).
- **Gate.** Fixed-seed sample hashes for both renderers, captured before the change, must match after it.

### K. Table plan handoff

- **Change.**
  - `TableWork` declares its node-free plan data once (`PLAN_FIELDS`, `plan_state()`, `adopt_plan()`), including
    `_solids_ref` and `_liquids_ref`.
  - `_make_twin` and `rebind` both use that declaration.
  - Caches derived from the plan (`_still_of`, `_laid_of`) are cleared in `adopt_plan`, which fixes the stale `_still_of`.
- **Gate.** `tests/table/rebind_parity_check.gd`: a changed act gives the same poses in a fresh bake and in an incremental
  rebake, including a prop at rest between spoken cues. Control that must fail: skipping the cache clear, on a table with no
  rigid parts.
- **Files.** `table_work.gd`, `table_physics.gd`.

### L. Static checks, and the duplicates removed

- **New `docs.py --check` rules.**
  - One environment: `Surroundings`' dressing functions are called only from `EnvironmentRig`.
  - One picture loop: no `_asked` outside the shelf base.
  - One live publish: no `_redress_live`.
  - No polling: no `FileAccess.get_modified_time` in `_process`, `advance` or `_ensure_doc` bodies.
  - No serializing in the frame: no `JSON.stringify` in those bodies.
  - Camera field literals and field groups (from E).
  - **No copies:** an identical function body of 8+ normalized lines in two files fails. The nine groups found today are
    removed: one versions store under environment and delivery, one designer chat base, one library `entries`, one
    `_size_of`, and so on. This is the generic guard against an agent copying one medium into another.
- **Files.** `docs.py`, plus the small files holding the nine duplicate groups.

### M. Agent instructions

- **The dispatch prompt (`Assistant._build_prompt`).** The run should:
  - find the class of the problem and every place it shows (every bowl's steam, every pair of things);
  - fix it in the part that owns it, or make that part;
  - verify on the real thing: the format's show audit at the reported moment, and `check.sh --for`;
  - say what was verified, how, and what was not.

  Keep "no unrelated refactoring."
- **CLAUDE.md.** Add a framework contract of about eight lines (P1 to P7, each naming its check), and remove the trap notes
  that checks now hold. Trimming the status list into `next/roadmap.md` is decision 5.
- **Notes.** Update `next/shared_primitives.md`'s Status block with what was built, and `next/studio.md` for the motion change.

### N. Measure

After B and F, measure Studio's frame cost cold and warm on the same passage: p95 and p99 frame intervals, and buffer remaining
at each hitch, as the audit asks. Extend the ready-ahead mechanism only where those numbers say so.

---

## 6. Order and parallel agents

All agents work in this one tree with **file ownership**: no two agents edit a file at the same time, and nothing touches git.
I coordinate, brief each agent from this plan, review every diff, and run gates between waves.

| Wave | Agent | Workstreams | Owns |
| --- | --- | --- | --- |
| 0 | me | Baseline | `check.sh --list`, the gates for studio, table, desk, dispatch, media and show; a read-only copy of the reference episode |
| 1 | 1 | A | `motion/show_audit.gd`, the sampler, `PropRig`'s `held` flag, audit probe and gates, Studio's `held` tags only |
| 1 | 2 | D | `table/environment_rig.gd`, `desk.gd`, `popup.gd`, `dispatch.gd`, the rig gate |
| 1 | 3 | E, H | `cameras.gd`, `medium.gd`, `show_sounds.gd`, `episode_card.gd`, the camera card gate, the props files |
| 1 | 4 | K, J | `table_work.gd`, `table_physics.gd`, `work_sounds.gd`, `dispatch_sounds.gd`, `audio/synth_voices.gd`, the pause files |
| 2 | me | F core | The document version and `publish_live` |
| 2 | 5 | B, Studio's D and F, G (Studio) | Every `src/studio/` file, `gesture.gd`, `motion/keep_out.gd` |
| 2 | 6 | I | `reading_follower.gd`, `book.gd`, `tablet.gd` |
| 2 | 7 | F (adoption) | `_ensure_doc` early returns and `publish_live` in dispatch, desk, letter, episode desk, tablet, table and the formats |
| 3 | me or 8 | C | The export contract and GPU gate (needs decision 4) |
| 3 | me | L, M, N | `docs.py` rules, the duplicate removals, the prompt, CLAUDE.md, the notes, measurement |
| end | me | | `python docs.py`, the full suite once, `--gpu` once, and a summary of what changed and what is still open |

**Resource rules.**
- At most four agents at once.
- Every hand-run Godot uses `nice -n 19` and `--log-file <scratch>`. Each agent runs only its own gates, with `--jobs 1`, and
  never the full suite.
- No GPU or xvfb work before wave 3.
- A new `class_name` is reported to me. I run the editor scan centrally, because two scans at once can drop a class from the
  cache.

## 7. Rules every agent brief carries

- Read CLAUDE.md and the header of every file before changing it. Leave the files you do not own alone.
- No git writes: no staging, committing, `git mv`, `git rm` or checkout. Never overwrite a file you have not read.
- Parse-check right after each GDScript edit (the `parse` gate), and never leave a file broken.
- Comments say what the thing is, in present tense, in the repo's voice: no history, dates or quotes. American English,
  " - " for a dash, never an em dash.
- Every new behavior gets a two-sided gate with a control that must fail. Gates are read-only (`Settings.is_probe_launch`, the
  seams).
- Nothing heavy on the app's thread. No polling the disk. No JSON in a frame.
- Large scratch goes on a real disk, never `/tmp`. Kill by exact pid. No shell polling loops.
- Report what was verified and how, what failed and why, and any file outside your list you needed to touch.

## 8. Not tonight

- **Medium definitions as data** (`Medium.make` assembling parts). D and G prove the parts first. Assembling a third room from a
  definition is a feature, not a fix, so it waits for a decision once those parts exist.
- **A general parity check between agent tools and card controls,** where every agent tool that writes the note declares an
  operation with both bindings. Studio placement already works this way. Once D and G exist, I would pilot it on Environment
  element fields.
- **Table's simulation behind a composed interface.** It stays behind its current one, as the audit says.

## 9. Decisions for you

1. **Word matching.** Should every matcher take a one-letter word at the cursor, as `ReadingFollower` (five media) already does?
   *I recommend yes.*
2. **Pause dial.** Should Piper clamp the pause dial at 10, as Godot does, so the two curves are the same everywhere?
   *I recommend yes.*
3. **Parallel agents.** Can they work in this one tree under file ownership, with no worktrees and no git writes?
   *I recommend yes.*
4. **GPU work tonight.** C needs short, low-resolution exports under xvfb, and the end of the night needs one full suite with
   `--gpu`. Is that all right while you are away from the machine?
5. **CLAUDE.md.** Add the eight-line framework contract? *I recommend yes.* Should the status list (about 300 lines) also move
   into `next/roadmap.md` and the `next/` notes it already cites? That one is your call.
6. **The reference episode.** Is it the studio episode you exported four times? I will find it from the latest take unless you
   name it. I will work only on a read-only copy.
7. **Quiet tree.** Please keep the app closed, with no feedback runs dispatched, while the agents work.

## 10. Done means

- The studio audit is clean on the reference episode. Any wrong that remains is listed with the reason it stays.
- The flip screen shows in an export, and the GPU gate holds it, including after a stop and a play.
- One environment part serves Desk, Pop-up, Dispatch and Studio, and the rig gate covers every format times every kind.
- Seen equals heard in Studio, and `advance` does lookups.
- No `_ensure_doc` serializes per frame, and nothing polls the disk in a frame or process path. `docs.py` holds both.
- Unknown camera fields, media and feature groups fail. Camera registration has one source, and its gate uses production
  registration.
- Props have one picture loop and one role choice. Synthesis has one kit. The pause curve has one table. Word matching has one
  matcher, with its behavior characterized.
- Table's plan handoff is declared once, `_still_of` no longer goes stale, and the rebind parity gate holds.
- `docs.py --check` passes with the new rules, including the duplicate-body rule, and the full suite is green.
- The dispatch prompt asks for the class, the owning part and verification. CLAUDE.md carries the contract, and the
  `next/` notes say what was built.
