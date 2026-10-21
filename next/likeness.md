# Likeness: an actor, played from his own frames

Planned 2026-10-20, not built. This note is the build spec: "Go!" means build it in the order of
**Build order**, top to bottom.

**The goal.** An ASMR creator, Ephemeral Rift, asked for his likeness to read chapters of his
upcoming book. Ghost makes a video of him reading the note's words, in his own room, from his own
footage. It is not generative: every pixel of him is a real pixel from his videos, bent.

**What was ruled out, and why** (the history is in git):
- **Generative video:** this machine cannot do it, and the user will not pay for a service.
- **A splat avatar** (gsplat, FLAME, MHR, SAM 3D Body, Audio2Face): "an exercise in dependency
  hell".

**The user's direction (2026-10-20):**
- "just re-implementing the thing is easier and faster and more reliable".
- Keep MediaPipe.
- "A full-screen shader".
- "the bulk of any change would be small deviations from frame to frame, with the mouth tracking
  the voice".
- Piper for the first build.
- **A pipeline, as a suite of tools,** not a feature tailored to one person. Like the book: the
  Picture presents it, and the Illustrations card makes and manages the pictures.

## The method

1. **His real takes are the base of every frame.** They hold his body, hands, hair, head turns and
   room. A take is played at its own speed and never retimed.
2. **The mouth is replaced:**
   - by real mouths from his footage, chosen by the shape the voice needs;
   - warped into the take through MediaPipe's face mesh;
   - blended by one fragment shader.
3. **The voice's phones drive the mouth shape.** Piper hands back every phone with its exact time.
4. **The takes are chosen and joined** where two frames nearly match (Video Textures, SIGGRAPH
   2000). An agent picks his gestures to land on the right words.

**The precedent:** Mary101 (MIT, SIGGRAPH 2002) did the mouth this way from 8 minutes of video and
46 mouth images, and viewers telling real from synthetic scored 52.1% and 46.6%: chance.

**No new dependency:**
- MediaPipe, OpenCV and numpy are in the face environment (`face_venv`);
- yt-dlp is in the download environment (`ytdlp_venv`);
- FFmpeg is fetched;
- Piper is the voice;
- the agents are ghost's own;
- the rest is GDScript and one canvas shader.

The one new file is MediaPipe's `canonical_face_model.obj` (Apache), a file row in `face_venv`.

## What his footage is (looked at 2026-10-20)

`/home/crow/repos/praxis/staging/eidolon/videos/` (from an earlier project, Eidolon, a nose-touch
classifier: only its videos are reused).

**What is there:**
- 8 videos of his: 25-92 minutes each, about 7 hours in all.
- 1920x1080 h264, all at 59.94 fps but one at 30.
- 4 videos of other creators sit in the same folder.

**What the pipeline must handle,** because it is not the "same shot every time" assumed:
- **Each video is edited:** jump cuts, a few camera framings, and inserts such as a handheld
  close-up, or him in a hat outside.
- **The camera is placed differently from video to video** around the same desk.
- **His look changes within a video:** glasses on for the first minutes, then off.
- **The light drifts:** sunlight patches move across the wall over minutes.
- **He talks with his hands constantly.** A hand is often on his cheek or his head, and sometimes
  he holds a phone.
- **He turns three-quarters toward his monitor often,** reading.
- **A large gray beard and mustache:** the jaw line is hidden, and the lips are partly covered.
- **A boom mic** stands beside him.

**So the unit of work is a SET:** the stretches of footage with one camera placement and one look,
found automatically and confirmed by an agent. Each set is a library of its own.

## The suite

Three parts, after the book's pattern: a library under both cards, a card that makes and manages,
and a card that presents.

### The library: `Actors` (`src/likeness/actors.gd`)

**An actor is a folder,** `user://actors/<id>/`, shared by every note that uses it, as
`Illustrations` and `Films` are. Its rules are the illustration library's:
- **Nothing builds on its own.** A button is the only caller, because the steps cost hours and the
  agents cost quota.
- **Cached by fingerprint.** Each step's output records the fingerprints of its inputs, its
  settings and the script's version.
- **Stale, not invalid.** A changed input marks the output stale (⚠); it is still used until it is
  remade.
- **The test seam:** `use_for_test()` moves the root aside, so no gate writes the author's actors.

**`actor.json`:**
- the name;
- the sources: folders, links, and the videos found in each, each ticked or not;
- the chosen set;
- consent: a path to the signed license, or empty.

**Consent:**
- Building is private, so it runs without consent on file.
- **An export that would upload refuses** an actor with none, and says why. The card shows "no
  consent on file" until there is.

### The Actor card (component `actor`): makes and manages

The card, top to bottom:
1. **The actor:** pick one from the library or make a new one, and its name.
2. **Sources:**
   - **Add folder…** A directory, read in place and never copied or written. Its videos are listed
     as rows, rescanned when the card opens.
   - **Add link…** A video, a playlist or a channel.
     - `yt-dlp --flat-playlist -J` lists the entries first, so the rows appear at once with title,
       duration and thumbnail.
     - Each is then fetched as its own step, one at a time.
     - The settings:
       - **Format:** `bv*[height<=1080][vcodec^=avc1]+ba[acodec^=mp4a]/b[height<=1080]`, the
         format Eidolon used.
       - **Captions:** `--write-auto-subs --sub-langs "en.*" --sub-format json3`, because auto
         captions carry a time for every word.
       - **Metadata:** `--write-info-json`.
       - **No repeats:** `--download-archive` in the actor's folder, so re-adding a playlist fetches
         only what is new.
     - Files land in `footage/`.
     - The download environment, its Deno, and its one update-and-retry follow `MaskUrlImport`.
   - **"Captions only" on a link:** fetches no video, and matches each caption file to a folder
     video by title. This gives the Eidolon folder's videos their captions without fetching 11 GB
     again.
   - **A tick per video,** for whether it is used. The four other creators are unticked.
3. **Steps:** a row per step, in order (see The steps).
   - Each row: ✓ when made, ⚠ when stale, a running share while it works, or what it waits for, and
     a short summary of what it made (for example "3 sets, 41 min usable").
   - ▶ makes that step and anything it needs.
   - ⟳ redoes it: its output is deleted and remade, and what depends on it goes stale.
   - A per-video step shows a count ("Survey 5/8").
4. **Generate** makes everything missing or stale, in order. **Stop** ends the running step,
   which resumes from its own last saved video or chunk.
5. **Sets:** a thumbnail and a sample frame for each, its minutes, its look in words (from the
   audit), and the chosen one.
6. **The library:**
   - his gestures as a strip of named thumbnails, which play on click;
   - his visemes, one mouth per class;
   - the count of mouths.
7. **Who labels:** an `AgentPick` row. The job sends pictures, so the backend must see them
   (`Bedrock.sees_pictures` already gates this).
8. **Advanced** (folded): the step settings (see The defaults).

**The runner is `ActorBuilder` (`src/likeness/actor_builder.gd`),** shaped like `ProofProducer`:
- Every `tick` starts each step whose inputs exist and whose output is missing or stale (when
  Generate asked), and lands what ended.
- **What runs at once:** one CPU step at a time, since MediaPipe takes every core it is given, and
  one agent job at a time.
- **Python steps** run through `Subprocess` (no shell), with `--progress <file>` polled as
  `face_track.py` is. Outputs are written to a temporary name and renamed into place.
- **A step that waits is not failed.** A step whose environment is installing waits, and says for
  what.

### The Likeness card (component `likeness`) and medium (`likeness`): presents

**The card:**
- the set, from the actor's sets;
- **Generate:** makes everything this note needs - the actor's missing steps through its feed,
  then the gestures (see Direct);
- **Direct:** the director places gesture marks in the note's text;
- **Clear gestures.**
- **Who directs:** an `AgentPick` row.

**The medium** is a row in `Medium.REGISTRY` (`res://src/likeness/likeness.gd`, frames
`["landscape"]`, needs `reading`). It renders, as a pure function of show time (see Rendering).

**The components' rows** (`src/notes/components.gd`):
- **`actor`:** family `picture`; needs nothing; provides `actor`; requires nothing; no slot.
  - Capabilities: `subprocess`, `ffmpeg`, `python:face`, `python:download`, `agent:writer`.
  - Block `actor` (its `id`); script `res://src/likeness/actor_card.gd`.
  - It may stand alone on a note, which then just builds an actor.
- **`likeness`:** family `picture`; needs `reading` and `actor`; provides `picture`; requires
  `actor` and `voice`; slot `presentation`.
  - Capabilities: `forward_plus`, `agent:writer`; marks `["gestures"]`.
  - Block `likeness`; script `res://src/likeness/likeness_card.gd`.
  - "+" Likeness brings an Actor card and a Voice, as Cards brings a Voice.
- **The reading workspace's `hosts`** gains `actor` and `likeness`.

**The cards never name each other.**
- The Actor card answers `feeds()` with `{"actor": ActorFeed}`, collected by the panel as
  `episode_steps()` is.
- The Likeness card asks the panel `feed("actor")`.
- **`ActorFeed`** is a small typed contract: the folder, the chosen set, `generate()`, and
  `status()`.

## The actor's folder

```
user://actors/<id>/
  actor.json                 name, sources, ticks, chosen set, consent
  footage/                   fetched videos, .info.json, .en*.json3 captions, archive.txt
  videos/<vid>/              one folder per source video (<vid> = a hash of its path and size)
    probe.json               duration, fps, size, has captions
    survey.bin               every 0.2 s: face found, head transform, 52 blendshapes, face box,
                             33 pose landmarks, a 32x18 person mask, a 64x36 gray thumbnail
    shots.json               the cuts: [start, end) in seconds
    words.json               caption words with times (from json3), if any
  sets.json                  sets: shots per set, minutes, sample frames, edge-map plate
  sheets/                    contact sheets made for the agents (JPEG, timestamps burned in)
  audit.json                 per set: its look in words; per shot: usable stretches, and why the rest is not
  sets/<set>/
    track.bin                the full track at 30 fps over its usable stretches: 478 landmarks (x, y, z),
                             52 blendshapes, head transform, 33 pose landmarks
    rig.json                 the mean shape, the outer rings, the triangles (canonical UVs included)
    mouths/NNNN.png          the mouth library: lower face in canonical space, 384x192
    mouths.json              per mouth: its key (mouth blendshapes, head yaw and pitch, light), its source frame
    phones.json              his phones with times, from caption words through Phonemes
    visemes.json             per viseme class: his mouth blendshapes; the linear map to lip and jaw landmarks
    takes.json               the takes: [start, end) between rest frames, the excluded stretches
    joins.json               per rest frame, its best joins (frame, cost)
    gestures.json            per gesture: name, words, take, start, stroke, end, how often he does it
    habits.md                the director's brief: when he does what
    frames/<take>/NNNNN.jpg  a take's frames at 30 fps, extracted the first time the take is played
```

**The track format** (both `survey.bin` and `track.bin`): little-endian like `face_track.py`'s
`GFT1`, with the magic `b"ACT1"`, a version, the rate, the count, which fields are present, then
the samples.

**The sizes** (est.):
- The survey is about 1.5 KB a sample, about 200 MB for all 7 hours.
- A set's track is about 7 KB a frame, about 250 MB for 20 minutes.
- Frames are about 250 KB each, only for the takes played.

## The steps

All Python is one entry point, `hosts/face/actor.py <step> ...`, one subcommand per step, in
`face_venv`. Agent steps are `TextGen` jobs with pictures attached, like the art director's
(`CardProducer`): the rules are in `rules/likeness/*.yaml`, and the reply is JSON, parsed and
checked, with a malformed reply retried once.

| # | Step | Per | Runs | Reads | Writes | Cost (est.) |
|---|---|---|---|---|---|---|
| 1 | **fetch** | link video | yt-dlp | the link | `footage/` | download time |
| 2 | **probe** | video | ffprobe | the video | `probe.json` | seconds |
| 3 | **survey** | video | `actor.py survey` | the video | `survey.bin` | about 0.2-0.4x real time: 1.5-3 h for all 7 h |
| 4 | **shots** | video | `actor.py shots` | `survey.bin`, the video | `shots.json` | seconds |
| 5 | **words** | video | GDScript | captions json3 | `words.json` | seconds |
| 6 | **sets** | actor | `actor.py sets` | every `shots.json` and `survey.bin` | `sets.json` | a minute |
| 7 | **audit** | actor | agent | `sets.json`, sheets | `audit.json` | 1 job per set |
| 8 | **track** | set | `actor.py track` | the usable stretches | `track.bin` | about 45 min for 20 min of footage |
| 9 | **rig** | set | `actor.py rig` | `track.bin`, the canonical mesh | `rig.json` | seconds |
| 10 | **mouths** | set | `actor.py mouths` | `track.bin`, `rig.json`, the video | `mouths/`, `mouths.json` | 10-20 min |
| 11 | **visemes** | set | GDScript, then `actor.py visemes` | `words.json`, `track.bin` | `phones.json`, `visemes.json` | a minute |
| 12 | **takes** | set | `actor.py takes` | `track.bin`, `audit.json` | `takes.json`, `joins.json` | minutes |
| 13 | **gestures** | set | `actor.py candidates`, then agent | `track.bin`, `words.json`, sheets | `gestures.json`, `habits.md` | 1-3 jobs |

**Step by step:**

1. **fetch.** yt-dlp with the flags above, one video at a time. "Captions only" fetches nothing but
   the json3, and matches it by title.

2. **probe.** ffprobe's duration, frame rate and size, and whether a captions file sits beside the
   video (`<name>.en*.json3`).

3. **survey.**
   - Decodes with OpenCV, and runs MediaPipe's face landmarker (with blendshapes and the head's
     transform) and pose landmarker (with its segmentation mask) every 0.2 s.
   - Keeps no 478 points: the survey is for finding things, not warping them.
   - Passes a thread count, as `pose_track.py` does.
   - **It resumes by video:** a stopped survey loses at most the video in hand.

4. **shots.**
   - A cut is a jump in the thumbnails' difference that the samples on either side do not share.
   - The exact frame is found by decoding the second around it.
   - **Shots under 3 s are dropped.**

5. **words.** The json3 caption events are read into words with `t0` and `t1`. Auto captions give a
   time per word; a word's end is the next word's start, capped at 0.6 s.

6. **sets.**
   - **A shot's background is the median of its thumbnails** where the person mask is clear.
   - **Shots are compared by their backgrounds' EDGE maps,** not their colors, so the sun moving on
     the wall does not split a set while a moved camera does. The face box's size and place are
     compared too.
   - **Clustering is agglomerative, with a threshold.**
   - **A set's usable minutes** count the samples with one face found, and no wrist or index
     fingertip of the pose inside the lower half of the face box.
   - **Its sheet** is 16 frames across its length.

7. **audit (agent).** One job per set with over 2 minutes usable.
   - **It is shown:** the set's sheet, plus a sheet for each of its shots (a 4x4 grid, near
     1568x882).
   - **It writes:**
     - the set's look in words (glasses, hat, clothes, the framing);
     - whether every shot is the same person in the same look, so a shot in another look is split
       off into its own set;
     - which stretches are usable, and why any is not: an insert, a hand over the mouth, a phone in
       front of the face, leaving the frame, another person.
   - **Its words go on the card.**
   - **The chosen set** defaults to the one with the most usable minutes.

8. **track.**
   - The full face and pose at 30 fps over the chosen set's usable stretches: every second frame
     of a 59.94 fps source, by time and not by index.
   - **It keeps everything:** 478 points with depth, the blendshapes, the transform and the pose.

9. **rig.**
   - **The canonical mesh's points, with their UVs.** The 10 iris points ride their eyes.
   - **Two outer rings** grown from the face oval's 36 points: one at 1.35x over the hair and beard,
     one at 2x where any change has faded to nothing.
   - **Anchors on the frame's edge.**
   - **One triangulation** over all of them, made once with OpenCV's `Subdiv2D` in the mean shape,
     and fixed for the set.

10. **mouths.**
    - **Every usable frame's lower face is unwrapped into canonical space:** the triangles below
      the nose, plus the beard ring, warped triangle by triangle with OpenCV.
    - **The key:** the mouth's blendshapes (`jawOpen`, `mouthClose`, `mouthFunnel`, `mouthPucker`,
      the smiles, stretches, rolls, shrugs, presses and the lip uppers and lowers, about 20), the
      head's yaw and pitch, and the light, as the mean color of the cheeks.
    - **k-means into 512 entries** (seeded), keeping the frame nearest each center: a real mouth,
      never an average.
    - **Each mouth is saved** as a 384x192 PNG.

11. **visemes.**
    - **Phones from his captions:** GDScript turns `words.json` into phones with `Phonemes` (ARPAbet,
      the same symbols Piper is sent). Each word's span is split in proportion to the phones'
      usual durations, which gives `phones.json`.
    - **His mouth per viseme:** `actor.py visemes` takes, for each viseme class, the median of his
      mouth blendshapes at its phones' centers. The captions' timing is rough, but thousands of
      occurrences make the medians good.
    - **The map from mouth shape to points:** a least-squares map from the mouth blendshapes to the
      lip and jaw landmarks in canonical space, so a target mouth becomes target points for the warp.

12. **takes.**
    - **Rest frames** are where his head, hands and mouth are slow and his mouth is near closed.
    - **A take** runs from one rest frame to a later one, inside a usable stretch.
    - **The joins:** for each rest frame, the 8 best rest frames to join to elsewhere in the set, by
      a cost over the landmarks, the pose's hands, and a 64x36 thumbnail of the person.
    - **A pair whose hands differ much is never joined.**

13. **gestures.**
    - **Candidates:** `actor.py candidates` finds stretches where the head's yaw or pitch, the
      brows, the hands' height or the lean leave his rest range, and returns, rest to rest.
    - **The agent** is shown each candidate's sheet and the caption words he said during it, about
      20 per job. It names each, says what it conveys, and marks its stroke (the frame where it
      lands), or drops it.
    - **His habits:** the agent then writes `habits.md`, the director's brief: when he does what,
      from the words beside his gestures.
    - **No example names in the rules.** Examples get copied word for word; the names are his
      footage's.

## Rendering

**One mesh, drawn over the whole frame with a canvas shader.** This is the full-screen shader.
1. **The mesh is the rig's triangulation.** It reaches the frame's edges, so it covers every pixel.
2. **Each vertex carries:**
   - **its position:** the target point in output pixels;
   - **its base UV:** where that point sits in the base frame;
   - **its canonical UV:** where it sits in the mouth library.
3. **The GPU interpolates both UVs across each triangle,** which is a piecewise affine warp, for
   nothing.
4. **The fragment shader, for each pixel:**
   - **the base frame,** at the base UV;
   - **inside the lower-face mask** (sampled at the canonical UV, feathered there): up to 3 library
     mouths from a `Texture2DArray`, mixed by their weights;
   - **each mouth color-matched first:** its mean and spread are matched to a ring of the base's
     own cheek and beard around it, so the drifting sun leaves no seam.
5. **A join** draws two meshes with their own base frames and warps toward one in-between shape,
   cross-faded over 8 frames.

**The first thing M4 checks:** how Godot's 2D mesh carries a second float UV per vertex (`COLOR`
if it stays float, else `CUSTOM0`/`CUSTOM1`). The fallback is a small float texture of canonical
UVs, looked up by vertex index.

**Everything stays in sRGB:**
- The frames are sRGB, and the shader blends them as they are.
- No 3D, no tonemapper, no compute.
- It should run on the Compatibility renderer too (est.).

**Frames:**
- A take's frames are extracted at 30 fps the first time it plays (FFmpeg, JPEG quality 92), as
  Films prepares nothing until it is used.
- They are read ahead on a thread. The export reads them in step.

**Determinism:**
- The output is a pure function of show time.
- The mouth weights at a frame are the mean of the k-nearest weights over the 5 frames around it,
  all computed from the target shape, itself a function of time. **Never a filter with memory,** or
  a seek and an export would differ.

## The lanes

All are functions of show time. Each plan is held as it is shown: a chunk's plan is fixed when the
chunk's phones land, as the desk holds its page (`DeskMedium.take_words`).

1. **The base take.**
   - **The bed:** takes of the chosen set, in seeded order, each joined to the next at its best
     join.
   - **A gesture mark** (`<!-- gesture: name -->`) cuts to that gesture's take, so that its stroke
     lands on the word after the mark, then back to the bed.
   - **Unmarked text plays the bed alone.**
2. **The mouth.**
   - **Piper's phones** (`{p, t0, t1}` on every take, exact: they are the durations the synthesizer
     used) are mapped to viseme classes, and those to his viseme mouth shapes.
   - **Coarticulation by dominance functions** (Cohen and Massaro, 1993): each phone pulls toward
     its target with a falloff around its center, so an "m" closes the lips in fast speech while
     the vowels blend.
   - **A target mouth** becomes target lip and jaw points through `visemes.json`'s map, set into the
     base frame's own head pose.
   - **Then the 3 nearest library mouths by key:** the target blendshapes, the base frame's yaw and
     pitch, and its light.
   - **The base take's own mouth and jaw are covered:** the lower face is warped to the new jaw,
     and the lips come from the library.
3. **Small deviations (later):** gaze and brows as landmark offsets. The first build has none: his
   takes carry their own motion.

**The viseme classes are a registry, rows not tables** (`src/likeness/visemes.gd`). There are about
14 classes:
- **silence;**
- **the consonants:** P B M; F V; TH DH; T D N L; S Z; SH ZH CH JH; K G NG; R; W;
- **the vowels:** open AA AE AH AY AW; mid EH EY ER; spread IH IY Y; rounded AO OW OY UW UH.

Each row has a `label`, its phones, its dominance (strength and falloff) and a `blurb`.

## The agents

Wired as everywhere else: `AgentPick` rows for who does each job, the words in `rules/likeness/*.yaml`
(read by `Rules`, checked by `rules_check`), and jobs on `AgentJobs`.
- **No reasoning asked for.** The `reasoning_extraction` safeguard stops a run that asks.
- **No sample phrases in the rules.**

| Job | Rules | Shown | Writes |
|---|---|---|---|
| Audit | `rules/likeness/audit.yaml` | the set's sheets | `audit.json` |
| Gestures | `rules/likeness/gestures.yaml` | the candidates' sheets, with their words | `gestures.json`, `habits.md` |
| Director | `rules/likeness/director.yaml` | the note's text, the gestures (names, what each conveys), `habits.md` | marks in the text |

**The director writes its marks into the note's text,** as Proof's Refine writes the note.
- **The check:** the text with every gesture mark removed must equal the text it was given, byte for
  byte, or the result is refused.
- **The author's own gesture marks stay,** and are not moved.
- **The ScriptWriter's palette** offers a `gestures` group, listing only the gestures the chosen set
  holds.

## The voice

- **Piper, through the Voice card, as any reading.** The stand-in is the closest stock male voice
  in Piper's allowlist.
- **The one change: phones ride with words.** `ReadingJoin` carries each chunk's `phones` beside
  its `words`, shifted by the same spliced rests (`ReadingPlan.words_for`), into the take the
  medium reads.
- **Later:** a generative voice (VoxCPM2 with a LoRA on his reading) only has to hand back phones
  with times, from its own plan or an aligner. The picture does not change.

## Gates

Tests mirror `src/`, so each is under `tests/likeness/` unless named.

| Gate | Holds | Its control, which must fail |
|---|---|---|
| `actors_check.gd` | Through `Actors.use_for_test`: a step with a missing input waits; a changed input marks stale; ⟳ deletes and stales what depends on it; Generate's order; nothing written outside the test root | A step started without its input |
| `warp_check.gd` (GPU, `run_quiet.sh`) | A made base image with made landmarks, drawn with the target equal to the base, comes back within 1/255 | The target moved 2 px |
| `coarticulation_check.gd` | AA M AA closes the lips at M's center | M's dominance set to zero |
| `likeness_determinism_check.gd` (GPU) | Two renders of one moment hash the same | A seed changed |
| `hosts/face/test_actor.py` | Unwrap then rewarp on a made image within 1 px; one cut found in a fixture made by FFmpeg; seeded k-means repeats; two made backgrounds are two sets, and a bright patch moved across one keeps it one | A rewarp with the UVs swapped |
| existing: `components_check`, `rules_check`, `compile_check`, `docs.py --check` | the new rows, rules and folder | - |

**Fixtures are made, not found.** MediaPipe on a real face is looked at in probes on his footage,
never in a gate: the footage is not in the repo.

## Build order

Each milestone ends with something to look at. Nothing past M4 is worth building if M4 looks bad.

- **M1 - The library and the sources.**
  - `src/likeness/` (a row in docs.py's `FOLDERS`, after `desk/`): `Actors`, `ActorBuilder` and
    `ActorFeed`.
  - The Actor card with its sources (folder, link, playlist, captions only, ticks) and the step rows,
    with Generate, ▶, ⟳ and Stop.
  - The component rows.
  - The `canonical_face_model.obj` file row in `face_venv`, with its sha256 and size.
  - Gate: `actors_check`.
  - **Look:** add the Eidolon folder and untick the four others; add his channel as captions only.
- **M2 - Survey, shots, words, sets.** `actor.py survey|shots|sets` and `test_actor.py`.
  - **Look:** the sets on the card.
  - **Expect:** a few sets per video framing, and the inserts split off.
- **M3 - Audit.** The rules, the job, `audit.json`, and the look in words on the card.
  - **Look:** do the sets and looks match what is on screen? Correct the clustering's threshold
    here.
- **M4 - Track, rig, mouths, and the identity test.** The canonical-UV question answered first;
  `warp_check`. Then a probe that renders:
  - **(a)** a frame redrawn through its own mesh, which must be indistinguishable;
  - **(b)** another frame's mouth drawn into it.
  - **This is the first look at the seam, the beard and the teeth.**
- **M5 - The ceiling.** A probe draws his own tracked mouth from one stretch onto a different take,
  with his real audio under it. No voice and no visemes are involved, so any fault is the picture's.
  - **Look at it with the user, side by side with the real stretch.**
- **M6 - The voice lane and the medium.**
  - Visemes from his captions; `visemes.gd`; coarticulation (and its gate); phones through
    `ReadingJoin`.
  - The Likeness card and medium on the bed alone.
  - **Look:** a paragraph read by Piper.
- **M7 - Takes, joins, gestures, the director.** `actor.py takes|candidates`, the gestures job,
  `habits.md`, the director's job and its check, and the `gestures` palette group.
  - **Look:** 60 s with gestures on their words.
- **M8 - The proof.** 2-3 minutes of a chapter: Generate on the Likeness card, then the export.
  `likeness_determinism_check`.
  - **Look:** with him, if he wants.

On long work, batch the changes and run `scripts/check.sh --for src/likeness` once at the end of a
milestone.

## The defaults

All are on the card's Advanced fold, so "Go!" needs no answers.

| Setting | Default | Why |
|---|---|---|
| Survey interval | 0.2 s | enough to find cuts and sets; full rate only where it is used |
| Track rate, output rate | 30 fps | half his 59.94 fps; ghost's export rate |
| Output size | the set's own, 1920x1080 | his frames as they are |
| Mouth library | 512 entries, 384x192 | about 150 MB as a texture array; Mary101 needed 46 |
| Mouths mixed | 3, weights sharpened toward the nearest | fewer blends, fewer doubled teeth |
| Shortest shot | 3 s | jump cuts shorter than that are noise |
| Set to build | the most usable minutes | the audit can change it |
| Join cross-fade | 8 frames | a quarter second |
| Labeler, director | the `AgentPick` default | as elsewhere |
| Voice | the closest stock male Piper voice | a stand-in |

## Risks, and where each is seen first

1. **Teeth doubled in a blend.** Seen at M4b and M5. The fixes: fewer mouths and sharper weights;
   at worst, the single nearest mouth with a short cross-fade.
2. **A seam in the beard.** Seen at M4b. Color matching plus feathering. The beard's own texture
   hides more than skin would.
3. **His original speech in the base take.** His cheeks and head move to words he said then. The
   lower face is replaced; the rest is real motion, slightly off the new rhythm. Judged at M5.
4. **His hands near his face.** The takes exclude stretches where the pose's hands are in the lower
   face, so the mouth is never drawn over a hand.
5. **Three-quarter turns toward the monitor.** The mouth key holds the head's yaw, and the set must
   hold mouths at those angles. The card says how many mouths each yaw band holds.
6. **Caption timing.** The visemes come from medians, so they are robust. If a class comes out
   wrong, the capture session's scripted viseme take fixes it.
7. **The light.** It drifts within a set: color matching for the mouths, and the join's cost
   includes the person's thumbnail, so joins stay in similar light.

## Later, not in this build

- **His capture session,** shot for the purpose: a locked camera, one look, a scripted viseme take
  (each mouth shape held, spoken and whispered, with slow turns), 20-45 minutes of him reading
  chapters, his gestures each from rest to rest, and one passage filmed as the ground truth.
- **The generative voice:** VoxCPM2 with a LoRA on that reading, judged blind by him.
- **Small deviations:** gaze and brows.
- **A webcam performer** through the same MediaPipe.
- **The step up, if the warp's range is too small:** a splat avatar. Its research is in git
  (2026-10-20).

## Consent and disclosure

- **Every upload is already marked as synthetic media** (`"containsSyntheticMedia": true`,
  `src/export/youtube.gd:991`).
- **The disclosure:** a line on the title card and in the description satisfies the EU AI Act's
  Article 50 for a creative work.
- **If he enrolls in YouTube's likeness detection,** agree in advance that he files no takedowns
  against these.
- **The signed license should cover:**
  - the uses, named specifically;
  - his approval of each script and render;
  - the term;
  - revocation;
  - who holds the actor's folder;
  - deletion at the end;
  - his estate;
  - pay and credit.

  California AB 2602 and 1836, New York GOL 5-302 and Tennessee's ELVIS Act are why.
- **ACX/Audible reject AI narration.**

## Sources

- **Mary101** (Ezzat, Geiger and Poggio, SIGGRAPH 2002): https://history.siggraph.org/?p=118425.
  The 8 minutes, the 46 prototypes and the visual Turing test are from Ezzat's lecture:
  https://www.mit.edu/~9.520/spring08/Classes/tony_9520class08.pdf
- **Video Rewrite** (Bregler, Covell and Slaney, 1997):
  https://www.mit.edu/~9.520/spring09/Papers/VideoRewrite.pdf
- **Video Textures** (Schödl, Szeliski, Salesin and Essa, 2000):
  https://sites.cc.gatech.edu/gvu/perception/projects/videotexture/index.html
- **Coarticulation by dominance functions:** Cohen and Massaro, "Modeling coarticulation in
  synthetic visual speech", 1993.
- **MediaPipe:**
  - the face landmarker: https://developers.google.com/edge/mediapipe/solutions/vision/face_landmarker
  - the canonical face mesh, with texture coordinates:
    https://github.com/google-ai-edge/mediapipe/tree/master/mediapipe/modules/face_geometry/data
- **yt-dlp's options:** https://github.com/yt-dlp/yt-dlp#usage-and-options
- **Consent:**
  - EU AI Act Article 50: https://artificialintelligenceact.eu/article/50/
  - California: https://perkinscoie.com/insights/update/single-day-california-enacts-five-bills-tackling-digital-replicas-and-deepfakes
  - New York: https://www.nysenate.gov/legislation/bills/2023/S7676
  - ACX: https://help.acx.com/s/article/acx-audio-submission-requirements
