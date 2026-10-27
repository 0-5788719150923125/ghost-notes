# Likeness: an actor, played from his own frames

Planned 2026-10-20; **built 2026-10-21** (M1 to M8 in code, M4 and M5 looked at on his footage).
**The second build (2026-10-21, night): a still and a model** - the section right below. The rest of
this note is the first build, kept for what it found; where the two differ, the second build holds.
The first build's files are backed up in `dist/likeness_v1/` (they were never committed).
**The fifth pass (2026-10-24): an audit of the head of splats and the voice** - below the sixth.
**The sixth pass (2026-10-25): the mouth, the flicker and the edges** - below the seventh.
**The seventh pass (2026-10-25, evening): the needles** - below the eighth.
**The eighth pass (2026-10-25, night): the soft mouth and the neck, from the literature** - below the next.
**Three alike videos, and is the approach convoluted? (2026-10-25, late)** - below the next.
**The ninth pass (2026-10-25, late night): a head that turns, a beard that stays on it** - below the next.
**The tenth pass (2026-10-25, later): the beard moves as one, the hands at rest are seen** - below the next.
**A voice alone: the Voice training card (2026-10-26)** - right below.

## A voice alone: the Voice training card (2026-10-26)

**NOW KOKORO'S (2026-10-26, later; next/voice_engines.md "Training Kokoro").** The user: "I likely won't use Piper
models for anything other than testing now, given that Kokoro is so much better-sounding ... our own custom training
loop would probably be perfectly fine." A voice alone's Utterances and Voice are Kokoro's own steps
(`kokoro_utterances`, `kokoro_voice`; `ActorSteps.of_kind`: an actor's voice is still Piper's): its sentences heard
again alone and cut to the words their sound says, Kokoro's decoder taught their sound, its delivery kept. The Piper
account below is how the card began.

**The user:** "I think I'd like to try for fine-tuning support, for voices. I am imagining a new component/card, which
we could attach to a note that already has the "Voice" component, to fine-tune a new voice for that component. As with
the other fine-tuning we've tried (the actor/likeness feature), I'd like to support importing a video from file, or by
pointing to a YouTube URL or playlist URL. Could you please do some foundational research here, and if you think this
will be possible, could you wire something up?"

### What can be trained here (looked at 2026-10-26)

- **Piper: built, and measured** ("Their own voice", and the fifth pass's "The voice is every way he sounds"). John
  (public domain) fine-tuned on their sentences, an hour on the 5060 Ti. Their tone arrives by epoch 30 (the spectrum
  as near their held-out speech as their own other sentences are). Clarity does not: one voice of his, 93 minutes, is
  misheard 15.9% of words, where his own audio is 5.6% and John 7.5%. Untried: taught in John's own labels ("en").
- **Kokoro: no training code of its own** (hexgrad: not feasible without the style encoders and discriminators it did
  not release). Three routes outside it:
  - [kikiri-tts](https://github.com/semidark/kikiri-tts) (Apache-2.0): a whole fine-tune through a patched StyleTTS 2
    trainer - stage 1 the decoder again, adversarially, with a fresh style encoder and fresh discriminators; stage 2
    durations, F0 and energy; StyleTTS 2's ASR aligner, JDC and PL-BERT to train with. Made for a NEW LANGUAGE (German,
    about 51 hours for its base; its single-speaker voices 455 and 627 clips on top of that base), "10 GB+" of the
    graphics card's memory where about 8 is free beside Praxis. Not a recipe for one English speaker on the official
    weights.
  - [kokoro-inno-clone-tuner](https://huggingface.co/remsky/kokoro-inno-clone-tuner) (code Apache-2.0, its speaker
    encoder CC BY-SA 3.0): one 3 to 30 s clip to a native voicepack ([510, 1, 256]) in a second, Kokoro frozen - the
    timbre half from a learned speaker encoder, the prosody half a blend of stock packs moved by the clip's pitch. Its
    own numbers: speaker similarity 0.288 on LibriSpeech test-clean (shallow, as it says), UTMOS 4.45, no word errors
    given. One clip, where we have hours.
  - **Our own style fit** (next/voice_engines.md, "Fine-tuning"): Kokoro frozen, the 256 numbers fitted to all of
    their sentences by gradient. Little memory and minutes; keeps Kokoro's clarity; how much of them it reaches is the
    question. Not built.
- **So the card trained Piper at first**, the trainer that ran here that day - and Kokoro the same evening, by a loop
  of our own (above).

### Built

- **The Voice training component** (`voice_training`, family Voice; it brings a Voice, as the Actor does; shown on a
  reading's, a table's and a proof's panel; `python:voice_train` among its capabilities, so where PyTorch has no CUDA
  build - a Mac, Windows - "+" leaves it out). Its card (`VoiceTrainingCard`): whose voice (a picker, "New voice…"),
  their name, their RECORDINGS (a folder, files, links), the five steps, Generate, Stop, **Read in it**, and the Voice
  lessons. Made, the voice is "<name> (their own voice)" on every Voice card, and the note reads in it as it lands
  (`ReadingPanel.voice_made`, as the Actor card's does).
- **A voice alone is a person of the Actors library** (`actor.json`'s `kind` "voice"; `ActorFolder.sound_only`),
  listed apart from the actors (`Actors.list(kind)`): the same folder, fingerprints, staleness and runner as an actor,
  but MADE OF THE VOICE AND WHAT IT READS ALONE - Fetch, Probe, Hear, Utterances, Voice (`ActorSteps.voice_chain`),
  whatever a run asks (`ActorBuilder.tick`). Kept apart, so its links can be FETCHED AS THEIR SOUND
  (`ActorSources.SOUND_FORMAT`: the best AAC, no picture, no captions - Hear listens to all of it): a 19 s video was
  302 KiB. An actor's folder listing one would have had its video fetched again later, and everything heard from it
  made stale.
- **Its folders list sound files beside videos** (`ActorFolder.SOUND_EXTS`: m4a, mp3, wav, flac, ogg, opus, aac), and
  **a file can be picked by itself** on both cards (a source of kind "file", `ActorSources.add_file`).
- **The two cards share their parts:** the sources and videos (`ActorSourceList`) and the steps' rows, worked out on a
  worker (`ActorStepRows`), moved out of the Actor card as they were.

### Verified

- `tests/likeness/voice_training_check.gd`: listed apart (two-sided), a folder's sound files and a file picked by
  itself, the fetch's arguments (the control: an actor's take the picture and captions), the sound file a fetch leaves
  (never its `.part`), Generate making each recording's probe and Hear, the Utterances, the Voice and nothing else -
  and a run asking for every step no more (the control: an actor's makes the survey); with the restriction taken out
  of the runner the gate fails. Read in it waits for the voice, then hands the reading its id; so does a voice
  landing. actor_upload_check, actors_check and components_check pass on the shared parts.
- By hand, outside the app: the card's own yt-dlp arguments fetched a 19 s video's sound (`<id>.m4a`, 302 KiB, and its
  details); ffprobe found no picture and 19.06 s (the probe's row says "0:19, sound"); Hear heard it whole (35 words);
  Utterances read it (and kept none of that outdoor 2005 phone recording: measured as whispered).
- **Not yet run end to end in the app** - a playlist fetched, heard, cut and taught from the card. That is the user's
  test.

### To try

On a note with a Voice: "+" → Voice training → New voice… (their name) → Add link… (a playlist of them talking) or Add
folder… / Add files… → untick what is not them → Generate. Hear takes about a seventh of the recordings' length on the
processor, the Voice an hour or so on the graphics card (Voice lessons, 6,000); Stop keeps what is learned. Half an
hour or more of their ordinary speaking voice is plenty; Utterances keeps one voice of them and says what it left out.

## The tenth pass: the beard moves as one, the hands at rest are seen (2026-10-25, later)

**The user, on the set made again after the ninth pass:** "The places where there is a lot of movement is spiky, as if
his beard is projecting beyond other features. His resting pose is open palm, face-up - which is bizarre, because it
makes him look like a priest or something. Everything stretches and morphs." And: "the spikes are perceptual spikes.
They happen when motion happens ... transitions between frames, they morph in a fractured/spiky kind of way."

### Measured (`dist/tenth/`)

- **The fracture** (`fracture.py`: consecutive frames, the later warped back by the smooth flow between them; what is
  left, over the texture there): the beard 0.25 before the ninth pass, 0.27 with the head's own motion, 0.48 to 0.51 once
  it rode the head; the collar 0.08 to 0.29-0.30. The bigger turns did little; the beard on the head did it.
- **Why** (`levers.py`: the fitted avatar, the face eased from its still to its most open moment and back in small steps,
  the head held; each beard splat's move against its 12 nearest): a splat parted from its neighbours by 0.435 px a step,
  45% of its own move. Its expression shifts alone parted it by 0.286 (more than they moved it: they had learned noise -
  hair has no shape that shifts with the face); its triangle alone, each turning its own way, by 0.220. Hung from the
  head below the chin and with no shifts under the lips: 0.124.
- **The still at rest**: the writer (Opus 5.5, shown the 12 stills on one sheet, a hand some 40 pixels) put stills 3
  and 1 - both palms open - among its five, 3 first; cropped to the hands (`hands.jpg`), five are plainly open or
  gesturing and three folded.
- **The motion is not past theirs**: the head moved against the body in 55 of 359 frame pairs, by 1.9 px (their own
  footage: 272, by 3.9). What stretches is the body bent in 2D under a head that now moves, and a still with both arms
  out bends with every shift of posture.

### Fixed

- **THE BEARD MOVES AS ONE** (`fit.hang_beard`, Fit version 6): below the chin a splat on the face's triangles is hung
  from the head's own frame where it stood, as the hair is; under the lips' outline it keeps its triangle (the jaw carries
  it) and takes no expression shifts. Fit learns its moments so, and plays so. Gate: test_fit (`the_beard_moves_as_one`).
- **THEIR HANDS, CLOSER** (`actor.hands_sheet`, Stills version 5; `rules/likeness/rest.yaml`): a second sheet, each still
  cropped round its pose's hand landmarks, numbered alike, goes to the At rest writer with the first. Gate: test_actor
  (`test_hands_sheet`).
- **A still with nothing before them** (the Fit step failed, `front_7.png` not found: the outline rule had left none):
  the specs take each still's layers from `stills.json` (`ActorBuilder.still_layers`), the trainer none for no front.
  Gate: actors_check.

## The ninth pass: a head that turns, a beard that stays on it (2026-10-25, late night)

**The user, on the set of the three alike videos:** "the new video is somewhat better I guess, but I still hate the fact
that the actor doesn't feel truly 3D. It just feels like we're morphing/warping at edges, and it's especially messy at the
neck and around the beard. If we were going to take some next steps here, what would you suggest?"

### Measured (`dist/third_d/`, `dist/ceiling/`)

- **The head is 3D; it is not played as one.** The head turned in the trainer by 6 to 18 degrees of yaw and 8 of pitch
  holds as a head - face, hair, ponytail and beard (`turn.py`, `order.py`); drawn in Godot's one order (the still's,
  never sorted) it is within 39 to 48 dB of the same turn sorted, under half a percent a pixel. But the plan plays their
  head at `CALM` 0.6 of their own, 0.55 of that while silent, eased under `MOST` 5, 4 and 3 degrees - sizes for a still
  bent by the motion. Over a take (`warp.py`, `follows.py`: the flow less the head's rigid motion), the head moved against
  the body in 38 of 359 frame pairs, by 1.6 px; in 12 seconds of his own footage, in 272, by 3.9. Under his lips the take
  moved 0.3 px a frame against the head, his own beard 2.1 (`bob.py`).
- **The beard's lower half followed the torso** (0.93 of its motion, none of the head's): the eighth pass's neck stretch
  gave every head splat a quarter face below the chin the torso's move - 34,861 of the set's - and no step that learned
  them (the head, the bake, Fit's moments) ever drew them so. Played, a translucent blue-grey veil hung from the beard over
  the collar as the head moved (`AB_beard.jpg`: as built above, riding the head below).
- **What stands before them was his sweater.** This set's `front_K.png` held five pieces of the dark knit (one at the
  collar's fold by the beard) and missed the microphone, which stands beside him. Over his four sets, the share of a
  piece's rim that is a strong edge in the still: the microphone and its shock mount 0.10 to 0.45, the black t-shirt's and
  the sweater's pieces 0.00 to 0.06 (`fronts.jpg`).
- **The ceiling** (`ceiling.py`: the head frozen, each moment's expression codes, then its pose and points too, fitted to
  the picture in its own light): on unseen moments 24.5 dB tracked, 23.3 played, 25.1 with the codes fitted, 25.6 with
  everything - and on moments it learned from only 1.2 dB more (26.4). The head is the limit, and it underfits: it
  scarcely draws even what it was taught. Three videos or ten score alike; the three hold twice the fine detail (0.16 to
  0.21 of the frame's against 0.09 to 0.11).

### Fixed

- **A HEAD OF SPLATS TURNS AS THEY DO** (`LikenessPlan.size_for`, `SPLAT_CALM` 1, `SPLAT_MOST` 12, 9 and 6 degrees -
  their own 95th percentile is 6, 5 and 3); the 2D renderer keeps its calm.
- **THE HEAD RIDES THE HEAD** (`train.second_of`): no head splat takes the torso's move; the shader's second influence is
  a body splat's alone, and `SplatHead.hold_still` and the still's frames are gone. Gates: test_fit
  (`the_head_rides_the_head`), splat_head_check (a head splat written a share draws as with none).
- **A THING BEFORE THEM HAS AN OUTLINE OF ITS OWN** (`actor.outlined`, OUTLINE_EDGE, OUTLINE_SHARE): a piece is kept only
  where 8% of its rim is a strong edge. The t-shirt set's left microphone is one piece with the shirt and goes with it.
  Gate: test_actor (`test_front_outlined`).

Drawn by Godot over the take, left to right - as the user saw it, with their own motion, and the beard riding the head:
`dist/third_d/now_motion_beard.mp4`.

### What is made again

Stills (version 4) and everything after it for each set: At rest, Rig, Frames, Face rig, Avatar, Fit (version 5).

### Open

- **The t-shirt set's neck** (set-2cacf4ef): its bare neck's skin rides the head now, and the specks the eighth pass
  stretched away (black shirt splats unseen in the still, uncovered as it turns) may show again there. Telling skin that
  stretches from hair that hangs needs the moments' say (a share learned in Fit) - but his tracked torso jumps 20 px every
  half second, too loose to learn against.
- **The jaw scarcely moves** (0.3 px a frame under the lips against 2.1 in his footage): MediaPipe sees no chin under his
  beard, so the rig learned a jaw that barely drops; driven by the lips' parting it could.
- **The head underfits** (the ceiling): first a head of one session trained far longer, to see whether its own frames
  climb past 26 dB - the budget - or not - the representation.
- **The body is the still bent in 2D** by its bones, by design.
- A picture frame's edge on the wall by his head is a front piece in three of set-6f0cbf09's stills (outlined, so kept).

## Three alike videos, and is the approach convoluted? (2026-10-25, late)

**The user:** "it still feels wrong ... maybe it truly would be worth reducing the number of videos to 3 very similar
ones, then to regenerate with those videos alone"; and "maybe there would be a better approach, which wouldn't require
all of that body part-specific rigging? ... full-screen training, where the actor and scene and ALL of the behavior is
synthesized through splats over time? ... the X most distinct poses, and embed them ... I don't know what's possible,
given our constraints."

### The set played had no lookalike

The set played (set-2cacf4ef, "Unc ASMR") is the one video of the 68 against a black backdrop in a dark room; nearly all
the others are the office - the green wall, the window's light, most in the same knit sweater. The head of 10 videos had
learned the office's daylight and was stretched over the dark room. One frame of each video: `dist/sweep/all_videos.jpg`.

### The three (`dist/sweep/`)

By each video's median face light, chest colour, wall colour and the face's place and size in the picture (and by eye:
`closest.jpg`): **"Sobriety & Personal Evolution"** (f-f0686b23ff, 77 usable minutes), **"Manuscript Day 131"**
(f-ea1b92e172, 56) and **"Evolution is neat!"** (f-791f8b0499, 52) - the same chunky knit sweater, long beard and combed
hair, the same room, light, camera distance and framing. The set played is now Manuscript Day 131's (set-8ed7fcfe: one
continuous 56-minute shot). The actor's file before: `dist/sweep/actor.json.before-pins`.

**THE HEAD PINNED, not the videos unticked:** unticking 65 videos would have made the audit, the sets, the visemes, the
motion, the utterances and the voice stale - Generate would have taught the voice again for hours on three videos'
speech. A video pinned "head" on the card (`ActorFolder.pinned`, `head_videos`) is what the head learns from, the pinned
alone, every ticked video still read for everything else; the Head's fingerprint names the pins. Generate makes again the
Head (3 videos x Head steps, about 20 minutes) and the new set's steps; the voice and the rest stay as they are. Gate:
actors_check (one pinned, it alone; unpinned, as it was).

### What the literature says (a third survey)

- **No published paradigm clearly beats this one under these constraints:** splats bound to a mesh with a small linear
  basis per splat is where real-time head avatars have ended up (GaussianAvatars, 3D Gaussian Blendshapes, RGBAvatar,
  Gaussian Eigen Models). What is convoluted here is the averaging - one head of many sessions, then the set's bake, then
  one still's fit - and the rules patching over it.
- **Full-frame splats over time** (4DGS, Deformable 3DGS) only replay the timestamps filmed; re-driving them means
  inventing a control space - a rig learned from weaker data - and a fixed camera is their worst case (DyCheck).
- **"The most distinct poses, embedded"** belongs in the driving, not the renderer: a motion graph over their own tracked
  code trajectories (Video Textures, Video Rewrite, Fried 2019) - retrieval of their own mouth snippets by phoneme
  context, transitions by interpolation of codes, nothing new at playback.
- **The data regime of the closest family** (talking portraits: ER-NeRF, TalkingGaussian, SyncTalk): one session, 3-6
  minutes, a 512 px crop - 32 to 36 dB, but scored with the test video's own pose and blinks, often face-only or pasted
  into the real frame. Pooled sessions help when each is short (PAV) and only when their differences have somewhere to go;
  one of his sessions is some 15 times what those papers train on.
- **The ceiling, measured apart from the driving:** freeze the model and fit each held-out frame's expression codes
  photometrically. Near what it scores on frames it learned (27 dB on one video), the drive is what loses; near 23, the
  representation (fine detail sliding on MediaPipe's coarse mesh) - then photometric tracking.
- **Ranked:** keep the paradigm and cut the averaging (the ceiling test first; each session's own model; 20-50 learned
  components in place of 12 PCA ones of the tracker's scores - GEM gained 2.4 dB from 10 to 30; the mouth's inside learned
  at the shapes played); then a motion graph and phoneme-context retrieval for behaviour; not retrieval of real pixels (the
  first build) nor 4DGS.

## The eighth pass: the soft mouth and the neck, from the literature (2026-10-25, night)

**The user:** "Can you please continue on the things still not fixed? If needed, perhaps do some foundational
research, search the internet for techniques, etc. Don't rely too heavily on your intuition here, there might be
better ways to do this stuff than what you're pushing for, right now." Still not fixed after the seventh pass: the
mouth soft, and a few dark specks at the neck's sides as the head turns.

**Read first** (two surveys; the papers' own words and ablations):
- The mouth: per-frame refinement of the drive (GaussianAvatars, MonoGaussianAvatar, HRAvatar, NeRFace's latent
  codes); TEETH OF THEIR OWN - GaussianAvatars' teeth triangles on the skull and the jaw, GaussianBlendshapes' ~14k
  mouth splats on two teeth billboards with no expression shifts ("blurry or ghosting" teeth without), GeoAvatar's
  part-wise mouth (+1.5 dB), TalkingGaussian's inside-mouth branch; a fan of triangles "naively connecting lip
  vertices" is named as the design that blurs and sticks the teeth together (GeoAvatar, FlashAvatar); mouth-weighted
  losses (FlashAvatar 40x on a mouth mask; RAD-NeRF's lip fine-tuning), densifying where the mouth is only sometimes
  seen (STAvatar), moving lips rather than recolouring them (TalkingGaussian).
- The neck: no paper lets two separately rigged layers both cover it. Full-body avatars (ExAvatar, HUGS, GART,
  X-Avatar) BLEND THEIR SKINNING across the neck; talking-head methods (AD-NeRF, RAD-NeRF, ER-NeRF, TalkingGaussian)
  give it one owner, the torso, trained on a picture with the neck painted up under the jaw; occluded splats take their
  visible neighbours' colour (OccGaussian).

### Measured before anything was changed (`dist/mouth/`)

- **The head is soft everywhere, not at the mouth alone:** on the set's own frames the avatar keeps 12 to 20% of the
  frame's fine detail (the Laplacian's energy) at the brow, the cheek, the nose and the lips alike, about 23 dB even
  on frames it learned from. Fit then sharpens all of it from the still but where the face opens - so the mouth, and
  the beard under it, stood out.
- **Not the tracking:** each frame's pose and points, freed to fit the avatar, moved 0.3 px at the median (the lips
  0.2), and on the frames with the mouth most open 0.1 - gaining 0.1 to 0.2 dB. The drive is where the mouth is.
- **The teeth are a smear:** on the open mouths it learned from, the mouth opens to the right shape and the teeth are
  yellow streaks - painted on the fan of triangles from the inner lips to a point behind them, which moves with the
  lips, where teeth move with the skull (upper) and the jaw (lower).
- **The neck:** the speck pixels on the neck's smooth skin (as the still shows it), with the head turned 3 degrees each
  way against the body. Drawn as the trainer draws (sorted by depth) they were mostly the head's and the body's
  layers swapping places; drawn as Godot draws - in the still's order - they are the black shirt's splats the head's
  splats below the chin had hidden, uncovered as those slid away with the head (the 42 splats under nine tenths of the
  specks: small, opaque, black, on a shoulder's bone, unseen in the still).

### Tried and dropped

- **The neck's skin held to the still as the head turns** (a turned head each Fit step): 322 speck pixels to 23, but
  it ate the bottom of the beard, even in the still (36.0 dB from 38.0) - the beard does swing over the neck.
- **Recolouring what no picture shows** (by the still and 24 moments): 30 splats, nothing changed; **recolouring what
  hides under the neck's skin**, or under the head, from the body round it (`train.fill_round`): 322 to 222, and in
  the still's order nothing.
- **Fitting the whole mouth to the still**, held to the moments: the beard under it sharp (48% of the still's detail,
  from 40) - but the still's closed lips showed in the openings again.

### THE NECK STRETCHES (fixed)

Each head splat below the chin takes the torso's move from where it stood in the still, more and more to a quarter of
the face's height below it (`train.second_of`, `NECK`): the neck stretches between the head and the body as a neck
does. The shader takes it as it takes the body's second influences, the head splat's place in the still from the
still's frames (`SplatHead.hold_still`, written once a load after the moment's own). In the still's order, the speck
pixels over the four turns: 179 to none; drawn by Godot over the take, the dotted line and the cross on the neck gone,
the beard turning with the head. Gates: splat_head_check (the shader against the rules, and its control),
test_fit (`the_neck_stretches`).

### THE BEARD UNDER THE LIPS IS FITTED (fixed)

Held to the moments, Fit no longer holds the beard below the lips (it had held as far as the lower lip goes, 0.15 of
the face's height): only the lips' outline, fading out over 0.02 of the face's height. Played: 47% of the still's
detail in the mouth's box, from 40, the openings as clean; a light hair across the lower lip is the still's own.

### THE MOUTH IS THE SET'S TOO (fixed, in part)

The bake pulled the face's surface in full toward the shared head, the mouth with it: every video's lips averaged.
A head learned from 3 videos instead of 10 drew the set's open mouths with 28% of their fine detail where the real head
drew 14% - so the bake now pulls the mouth's splats (on the lips', the corners' and the inside's triangles,
`bake.mouth_of`) no harder than the hair's, and lets them grow: 22% (24.17 dB against 24.21), and played, with the
lips-only Fit, 49% of the still's detail in the mouth's box (from 40% before this pass). Still soft.

### Teeth of their own, and the mouth's inside its own (tried on scratch heads; not shipped)

Four heads of the same 3 videos and 12,000 steps (`dist/mouth/teeth/`), each baked onto the set, on its 12 most open
mouths (each frame's own light, as tracked):

| head | the mouth | detail | what paints the opening |
|---|---|---|---|
| A: as it is | 24.99 dB | 28% | the lips' own splats 84-96%, the fan the rest |
| B: teeth (upper on the head's frame, lower on a jaw's triangle, no expression shifts) | 24.89 | 28% | the teeth 16%, the lips 74% |
| C: B, the mouth weighed 10x and open mouths drawn up to 4x | 22.98 | 45% | (speckled, jagged teeth) |
| D: B, and the face's own splats' cover inside the open inner lips pulled to none (TalkingGaussian's decomposition) | 25.50 | 33% | the fan 82%, the teeth 17%, the lips 1% |

- **The opening was painted by the lips:** their splats - centred on the lips, reaching in - painted the teeth, which then
  moved with the lips and smeared. Teeth alone changed nothing: the lips went on painting over them.
- **D drew the teeth as teeth** on the mouths it learned from (each tooth, the gaps). **Played, it tore:** the played
  mouths are their tracked mouths pushed by Articulation, wider than any it learned, and the fan that paints the inside
  stretched into a dark gash with fragments of teeth. Not shipped; the next step there is the inside learned at the
  played shapes, or a push the inside follows.

### Found, not fixed: what stands before them is his shirt

`front_1.png` (what stands before them, drawn over the splats and never moving) holds his whole upper body - the black
t-shirt, the shoulders - and not the microphone. By colour alone, where the picture is plain, a black shirt on a dark wall
is the still's in every frame. Drawn over the splats, it holds his chest still and cuts the beard with a hard edge as the
head turns past it (a notch at the beard's right side). `actor.py`'s `still_room` / FRONT_SEEN, STILL_SHARE.

### What is made again

Generate makes again each set's Avatar (its version is 6: the mouth the set's own) and Fit (4: the seventh pass's and
this one's), about 10 minutes; the neck's stretch is written by Fit and drawn by the player. Drawn by Godot over the
take: `dist/mouth/seventh_vs_eighth.mp4` (the seventh pass on the left, this one on the right).

**For the user to test:** the neck as the head turns, the beard under the lips, the mouth.

## The seventh pass: the needles (2026-10-25, evening)

**The user, on the set made again after the sixth pass:** "This feels somewhat better, however the whole scene has
needle-like fractures throughout it, especially near the face, and especially noticeable when the face moves.
Otherwise, the motion itself is looking somewhat better (though the mouth is quite blurry still). But the fractures
look really bad."

**Looked at** (`dist/needles/`): the set (set-2cacf4ef, its Head of 60,000 steps on 10 videos, 64 minutes) drawn by
Godot over the 12 s take; the frames the medium wrote for the splats at six moments of it (a scratch dump), drawn
again by the trainer.

### Godot and the trainer agree

Drawn by the trainer from the very frames Godot wrote, the needles are the same ones, where they are: a dark line
from the mouth's corner across the cheek, needles through the beard, green and purple specks on the neck, the
beard's edges in streaks. The avatar before Fit, drawn from the same frames, had none of them but streaks at the
beard's edge, where the mouth folded the face (below) - only its blur.

### Fitted to one picture, the head came apart as it moved (found and fixed)

- **Fit fitted the head's splats to the still alone.** Any layers that add up to that one picture would do: 41.4 dB on
  it, but on the set's moments it never fitted 19.9 dB, where the avatar it started from held 21.75. Turned 3
  degrees, the neck broke into coloured specks; played, the beard and cheek tore as the mouth opened.
- **NOW THE MOMENTS KEEP IT WHOLE** (`fit.moment_loss`): each step one of the set's own moments is drawn too, as
  tracked and in its own light, and asks the head for its picture in squares 4 pixels wide - what moves with the face
  holds together as it did in them, the fine detail is the still's alone. On his set: 38.0 dB on the still (from
  41.4), 21.4 on the moments it never fitted (the avatar's 21.75, the still's alone 19.9); squares of 8 held it as
  well (21.25).

### The mouth folded the face (found and fixed)

- **Turned past the head's own turn, a triangle by the mouth's corner went 91 to 96 degrees** at two of the six
  moments, and cheek triangles beside the nose some 35. Of what moves the played face, the face's own ways turned no
  triangle more than 4 degrees, the blink the lids' 34 - and each sound's mouth up to 121.
- **Why:** each sound's own mouth is the median of their tracked points (the sixth pass), and Articulation pushes all
  of it three times. Their own mouths turn a triangle at most 27 degrees; pushed, the mouth's corners crossed over
  themselves - P B M 118 degrees, F V 85, "open" 62 - and the splats bound there swung edge-on.
- **NOW A SOUND'S MOUTH NEVER FOLDS THE FACE** (`LikenessMedium.unfolded`, `FOLD_MOST` 40 degrees): pushed no further
  than turns any triangle past it. On his set "open" is pushed 1.85 (the lips parted 0.105 of the face's height,
  their own 95th percentile 0.11), P B M 1.25 and F V 1.7 (pushed 3 they had moved the lips only 2 to 3 pixels nearer
  closed), the rest 2.6 to 3.

**Drawn by Godot** (the 12 s take; `dist/needles/now_vs_seventh_pass.mp4`, the set as Generate made it on the left,
with both on the right): the line across the cheek, the needles through the beard, the specks and crosses on the
neck gone; the beard's edges whole through a blink and as the mouth closes on P B M. A few dark specks remain at
the neck's sides (the avatar has them too: below the chin the head's splats and the body's meet, and slide as the
head turns). The still is 38 dB where it was 41.4 - a little of its finest detail given for it.

### What is made again

Generate makes again each set's Fit (its version is 4): about 5 minutes. The cap on the mouths is the player's
own: nothing else is made again.

**For the user to test:** Generate on the Actor card, then ▶ on the note: the beard's edges and the cheeks as the
mouth opens and closes, and the neck as the head turns.

**Still open:** the mouth is the head's, as soft as every video's mouths averaged - Fit holds it as the moments
taught it, since fitted to the still it took the still's closed lips into every opening.

## The sixth pass: the mouth, the flicker and the edges (2026-10-25)

**The user, on the head of splats made again after the fifth pass:** "This new attempt is decent, but it still has
some problems. The mouth shape barely moves. The shape/color of the face and head can be stable for several seconds,
but then it 'flickers' into something else ... around the edges of the face is heavy artifacting: at the neck, black
splotches and hard lines, and around the head - heavy blurring, such that ears just look like smears."

**Looked at** (`dist/fifth_look/`): his set (set-2cacf4ef: a black t-shirt, a dark room) drawn by the medium over a
24 s take (`likeness_look_probe --take`), and what the player hands the splats each frame (a scratch probe: the glance,
the blink, the face's own ways, the expression).

### The flicker is the glances (found and fixed)

- **Nothing else moves the face in steps:** the face's own ways moved 0.01 a frame, the motion pieces blend over 0.8 s.
  A glance (about one every 4.5 s, turned to in 60 ms, held 0.35 to 1.2 s) moved the expression's components by up to
  3.4 of their spreads (look aside: components 3 and 8, the gaze's; look down: 2.6 of component 1, the lids' with the
  gaze's), and a blink 1.1.
- **Drawn, a glance re-made the face:** the cheek widened, its light went blotchy, the beard's edge moved - for the
  whole of the glance, then back.
- **Why:** both things that move the face mixed its parts.
  - The splats' expression was the 52 scores' principal components over every score at once, and its shifts learned
    whatever went with a score in his footage: a glance aside came with his head turned to a lit screen.
  - The rig's basis was fitted over every score: a glance's scores moved the cheeks and the jaw. Measured from the
    basis, the eyes' scores moved the points below the nose 0.97 as far as their most - what a score moves cannot be
    read off a fit of correlated scores.
- **NOW THE FACE HAS PARTS** (`hosts/avatar/parts.py`): the eyes, the brows and the mouth, each its scores, its anchors
  (MediaPipe's points: the eyes' rims and irises; the brows; the lips and the jaw's edge round the chin) and a reach in
  the face's heights (0.12, 0.15, 0.3: all of it within half, none past it). The rig's basis moves a point by the scores
  of the parts that reach it alone (`rig.by_parts`; a point no part reaches - the nose, the upper cheeks, the forehead's
  top - moves with none), and the expression has components of each part's scores alone (4, 2 and 6: `train.components`),
  a splat taking a part's shifts only as far as the part reaches its triangle (`train.reach_of`; the export writes each
  shift so, and the shader is as it was). On his frames the basis explains 40% of the face's movement where it had 54%
  (the lips 62% from 67%): what it gave up is what the other parts' scores had explained by going with them.

### The mouth scarcely moved (found and fixed)

- **Played, his lips parted 0.044 to 0.062 of his face's height while he spoke; his own, tracked over all his frames,
  0.013 to 0.11** (the 1st to 95th percentiles; 0.145 at the 99th). Each sound's mouth was its scores, set one at a time
  (the jaw at its place in his range, every other mouth score at its median) and pushed from the still's own - whose
  lips are parted 0.035 - so most consonants closed the mouth, and "open" at its most (the jaw at their 99th
  percentile) parted the lips 0.064 through the basis. His wide mouths reach 0.11 to 0.145 with an ordinary jaw score:
  the beard throws MediaPipe's jaw off.
- **The head is learned on the tracked points, so the mouth is played from them.** NOW EACH SOUND'S MOUTH IS THEIR OWN
  (the Face rig's `mouths`, `rig.mouths_of`): the frames of every video whose mouth's scores are nearest the sound's (a
  percent of them), their points' median less the rest's - only where the mouth reaches - and their mouth's scores'
  median less the rest's; and how far their lips part, the 1st and 99th percentiles. The player moves the still's face,
  its mouth at rest, by them, pushed by Articulation and never past their own parting (`LikenessMedium.own_mouths`).
  Silence is their mouth at rest. Simulated over the take at Articulation 3: 0.037 to 0.114 while speaking.
- **Drawn:** the mouth opens on the vowels, its inside dark and the teeth showing, and closes on P B M.

### The edges are the head's (found; fixed in part)

- **The neck:** in the still, his neck shows between the beard and the t-shirt's collar; drawn, it was dark with a hard
  curved edge and a ring of skin. The bake drops the head's splats below the chin and lays the set's own there from its
  146 moments, and Fit fitted only the body - not where the head is solid.
- **The hair and ears:** the head is every video's, adapted to the set's moments: soft, the ears a smear.
- **Fitted to the still whole** (a scratch Fit, the head's splats too, their expression shifts held): 23.3 dB on the
  whole still became 43.7, the hair in strands, the beard sharp, the neck the still's skin down to the collar - but
  where the face opens it broke: the shut lids showed the still's open eye as coloured specks, and the parted mouth the
  still's closed lips as specks and streaks. Held there - the places, the triangles on the lips and the eyes' rims, or
  every splat the expression moves - it still did, or left blurred patches beside sharp ones: what shows in the
  opening is whatever stands there, bound to anything.
- **NOW FIT FITS THE HEAD TOO, BUT NOT WHERE THE FACE OPENS** (`fit.where_it_opens`): a head splat is held by where it
  stands in the still - within the lips' sweep (their outline and itself 0.15 of the face's height lower) or an eye's
  rim, wholly, fitted more and more past them (wholly at 0.06 and 0.04 of the face's height). On his set: 41.5 dB on
  the whole still (from 23.3), the hair in strands, the ears and beard sharp, the neck the still's skin down to the
  collar with no edge; the parted mouth and the shut lids clean, the soft mouth fading into the sharp beard round it.
  A few coloured strands showed on a cheek during a glance down - the old basis moved the cheek with a glance.

### All of it at once, on a scratch head

A head learned with the parts (`dist/fifth_look/parts_run/`: three of the Head videos, 2,000 steps each - a tenth of a
real Head, 8 minutes), the set baked from it (21.69 dB on the moments it never fitted, as the real head's set), Fit
(39.7 dB on the whole still) and 12 s drawn with their own mouths: through a glance the lids lower and nothing else
changes - the old head had changed the cheek's light, the nose's shading and the warmth of the whole face.
`dist/fifth_look/now_vs_sixth_pass.mp4`: the set as it is on the left, as it will be on the right, over a passage in
John's voice.

### What is made again

Generate makes again, in order: the Head rig (seconds), Head (about 1.7 hours), and each set's Face rig (seconds),
Avatar (4 minutes) and Fit (4). Until its Face rig is made again a set refuses to play on the splats ("from before
their own mouths").

**For the user to test:** Generate on the Actor card, then ▶ on the note: the mouth at Articulation 3 (2 if it opens
too far), a glance, the neck and the hair. Not yet looked at: a set with glasses (the head never draws them), and a
still with the lips apart (silence is their mouth at rest now, not the still's).

**The user, on the head of splats and the voice trained on all 65 videos:** "it's almost starting to feel
like our results are getting worse ... the face moves/morphs at EXACTLY the same time every phoneme changes.
So, when the actor is not talking - the face is not moving at all ... every 'sound' that comes from the actor
also comes with a jarring shift in the face; and because of the heavy blurring, the face is extremely
unstable"; "heavy black dots speckled throughout the actor's beard. They move and shift in a very much 3D
manner"; "The generative voice sounds quite bad now ... really muddy and hard to understand. It's quite
inconsistent."

### The face moves only at the phones (found and fixed)

**Every frame is drawn** (`LikenessMedium.draw_at` poses the splats each frame): what was stepped was what
the plan handed them.

- **The two strongest, made for two pictures, were played on the splats.** `Visemes.strongest` mixes at most
  two sounds, each less the third, measured against the strongest - right for the 2D renderer, which draws
  two library pictures. On a head of splats it held each sound's whole shape and gave way to the next in some
  15 ms: a jump inside one frame. On a real passage (John's, 218 phones, 24 s; at 30 frames a second) the
  mouth's scores travelled twice as far as Cohen and Massaro's own weighted mean of every pull, and moved by
  as much as 0.69 of a score from one frame to the next (the mean of every pull: 0.26; smoothed by 20-25 ms:
  0.21); a sound's share of the mouth moved up to 0.92 in a frame (every pull, smoothed: 0.30). The gate had
  checked continuity a tenth of a millisecond at a time, where a 15 ms crossing is smooth. NOW a head of
  splats mixes every pull, averaged over a Gaussian of 20 ms (`Visemes.mix`, `LikenessPlan.mouth_mix`), and
  the lips still close at M (0.85 of the mouth in a fast "AA M AA"); coarticulation_check holds it frame by
  frame, the two strongest its control.
- **Articulation 3 took the mouth past anything the head saw.** Each sound's mouth is a place in their own
  range (`visemes.json`, "their words scarcely show in their mouth: 0.19"), pushed from the still's own:
  at 3, "open" asked jawOpen 0.67 and the lips' close 0.42, where the head's 99th percentile of its 17,192
  moments is 0.49 and 0.25 (this set's 153 moments reach jawOpen 0.35 twice). The splats bound to the mesh
  stretch with it. NOW no sound is pushed past their own 99th percentile of each score (`visemes.json`'s
  `range`; `LikenessMedium.TOP`).
- **Silent, nothing moved but the blinks and glances.** From every video's survey (five looks a second) and
  the words heard: their brows, lids and cheeks move 0.74 to 0.82 as much in silence (a second from any word)
  as while speaking, and their mouth 0.74. Some of it is MediaPipe's jitter: the slow part goes on from one
  look to the next (lag-0.2 s correlation 0.43 to 0.58 for brows, squint and smile; 0.24 to 0.31 for the
  mouth's quick components). NOW the Motion step learns THEIR FACE'S OWN MOTION at the head's looks
  (`actor.py`: `face_names` - every score but the blinks, the gaze and the lips' opening and protrusion, which
  the plan plays itself and a beard misreads, his pucker's 90th percentile 0.71 - high-passed as the head's,
  smoothed over 0.4 s, `face_components`: on his footage six ways, two of the brows, a smile, a squint, a
  stretch of the mouth's corner, the brows one against the other); the plan reads them from the same piece as
  the head (`LikenessPlan.face`), at its calm, and the splats mix them (`LikenessMedium._take_face_ways`). The
  Motion step's version is 4: it is made again (36 s on his 65 videos).

The 2D renderer is unchanged: it still draws two library pictures.

### The black dots are the bake's growth (found and fixed)

**Not the player** (`dist/dots_audit/`): the trainer's own render of `fit` at the still has them (309 speck
pixels the photo lacks: the forehead, along the beard, the neck), and drawn in the exported order or truly sorted
by depth - at the still, turned 5 degrees, with "w" and "open" pushed three times - no pixel differs by more than
0.3. They move "in 3D" because they are bound to the head's and the face's frames.

**What they are:** splats under half a pixel (median 0.24 px; with the rasterizer's 0.3 low-pass each draws a
1-2 px dot), wholly opaque (cover 1.0), dark (luminance 0.085), on the drawn surface. 90 of them make half of the
specks, 359 four fifths. The shared head held 1 such splat; the set's bake 13,087, and Fit kept 10,006.

**Why:** the bake grew the head freely - from 55k splats to 346k, on 146 moments (`HEAD_MOST` 500k, about 13k a
densify round), copying splats already under a pixel - and over-fitted their darkest detail in a few moments. This
set's moments (`dist/dots_audit/set_moments.jpg`) show glasses in 11 and a globe, bottles, game boxes, a keyboard
and a broom before his face in some 25, none masked, and the black collar between the beard's strands. Baked again
without any growth: no specks at all and 21.54 dB on the moments it never saw against 21.57 - the growth bought
nothing there, only softness lost on the still.

**NOW** (`bake.py`, NO SPECKS): the head grows to at most three times its own (`HEAD_GROWTH`), never copies a splat
already under a pixel (`LEAST_COPY`; `train.Splats.densify`'s `least`), and before it is baked a head splat under a
pixel darker than 60% of the face drawn round it in most of eight moments is dropped (`specks`) - relative, so his
dark hair keeps its own. Baked so on his set (`dist/bake_test/`, 6.6 minutes): 4,774 specks dropped, a head of 139k;
at the still 11 speck pixels the photo lacks against 216, on each unseen moment 47 against 279, and the face 21.85
dB at the still (21.57) and 21.67 on unseen moments (21.57). And the room's frames are counted one at a time
(`train.room_of`): summed whole, the masks of 146 frames became 2.3 GB of 64-bit integers, and the bake died of it on
a card shared with another trainer.

**Left:** a few faint specks in the beard. The moments with glasses or something held before the face are still
learned from: the head draws them worst (of the 24 it draws worst, all but a few - `dist/bake_test/worst24.jpg`),
but left out at a quarter of the steps (the 13 of 146 more than two spreads past the median) the set came out no
better - 21.50 dB on the unseen moments against 21.67, 85 speck pixels on each against 47 - so they stay.

### The voice is every way he sounds (found and fixed)

**Measured** (`dist/voice_audit/`): 40 held-out sentences from 27 videos - none of their text taught, none from a
video the old voices were taught on - said through the voice host's own path and heard by Whisper (base.en); the
pitch from sentence to sentence; the long-term spectrum against his clean held-out speech.

| voice | taught on | word errors | sentence pitch spread (Hz) | spectrum off (dB) |
|---|---|---|---|---|
| him (his own audio) | | 5.6% | 38 | 0 |
| John, the base | | 7.5% | 15 | 5.3 |
| the dev run at epoch 120 | 46 min, 2 spoken videos | 14.4% | 12 | 0.9 |
| the first run in the app | 637-915 sentences | 17.4% | 23 | 1.4 |
| **all 65 videos, 30 epochs** | 480 min, 58 videos | **33.6%** | 17 | 1.6 |
| **one voice of them (the proof)** | 93 min, 19 videos, ~4.9k batches of 8 | **15.9%** | **9** | 1.2 |

**Why:** of the 480 minutes, 220 were noisy (outdoors, wind, water, two over a music bed - "Human Laws" at 208 Hz and
168 characters a second), 32 soft and low (85 Hz, close to the microphone), 38 high, 44 breathy, and 146 his ordinary
voice. A voice of one speaker averages them and draws among them sentence by sentence: lowering its sampling noise
helped it 11 points and the old voice 3. And FOUR VIDEOS WERE THERE TWICE ("(1080p)" and "(1080p, h264)", their merged
download folders): 48 of the 287 held-out sentences were also taught. Ruled out: the trainer's settings (the same as
the old runs'), clipping, too few batches (13k, more than the old runs), the transcripts (a second hearing, small.en,
on 454 sentences: a median 3.9% of words differ, alike in clean and noisy videos).

**NOW:** the Utterances step keeps ONE VOICE (`utterances.signature` measures each sentence as it is cut, `choose`
keeps them together: its speech 30 dB over its own pauses; 8 to 30 characters a second of loud sound; its pitch
within 1.3 times their usual one; a harmonics-to-noise ratio of 3.6 dB or more; its video's mean spectrum within 2 dB
of the most typical video's; each sentence once) and says the minutes left out for each reason; A COPY IS NOT ANOTHER
VIDEO (`ActorFolder.copy_of`: a video of the same title and length as an earlier one is left out of every step, the
card marking it ⧉); and the Voice is taught in LESSONS, each a batch of 16 (`voice_steps`, 6,000 - about the proof's,
under an hour), as many epochs as make them. Run on his 68 videos (`dist/utt_test/`, 21 minutes): of the 499
minutes cut, 1,087 sentences and 45 held out, 88 minutes from 12 videos, his register 124 Hz; left out, in minutes:
noisy 226, another register 72, breathy 46, another recording 46, said twice 18, not paced as speech 3. Untried:
John's own labels ("en") in place of "en-us".

### The head is soft: too little of each video, and nothing settles (found; fixed in part)

**Measured** (`dist/blur_audit/`; sharpness is the render's mean |Laplacian| over the frame's in a region, 1.0 as
sharp as the frame; regions from MediaPipe's points: the eyes and nose from the brows to the upper lip, the mouth and
beard below). The shared head as built (63 videos, 60,000 steps): on its own training moments the eyes and nose 0.17
at 21.7 dB, the beard 0.08, the hair 0.14 - and on unseen moments the same (0.21, 20.5 dB): it is not over-fitted, it
is under-fitted. 42% of its face splats are nearly clear; its median splat is 7 px.

| head (eyes and nose, on the same video's moments) | steps a video | trained on | unseen |
|---|---|---|---|
| shared, 63 videos | ~950 | 23.15 dB, 0.21 (beard 0.05) | 22.46 dB, 0.22 |
| one video | 6,000 | 27.05, 0.51 (beard 0.31) | 22.86, 0.46 |
| one video, each moment's pose refined | 6,000 | 27.06, 0.51 | 22.47, 0.46 |
| one video, its places settling | 6,000 | 27.24, 0.67 (beard 0.55) | 22.81, 0.68 |
| three videos, settling | 6,000 each | 26.21, 0.59 (beard 0.46) | 23.23, 0.55 |

**Why, by evidence:** (1) some 950 steps a video, three or four looks at each moment; (2) no rate fell in any loop -
3DGS's own rates, taken without its schedule, so every place wandered a step's worth to the end; (3) the bake starts
from the head and is pulled toward it. Not the cause: each moment's pose (refined, it moved 0.3 px and gained
nothing - though a 1 px error would cost a third of the sharpness), the moments' resolution (full 1080p, sharp), the
rasterizer's low-pass.

**NOW:** THE PLACES SETTLE in every loop (`train.Splats.decay`: the place, the expression's and the look's shifts of
place at their rate times 0.01 ** the share done - head.py, bake.py, fit.py, train.py); and THE HEAD LEARNS ENOUGH OF
EACH VIDEO: the Head videos (10) with the most usable minutes of them facing the camera
(`ActorFolder.head_videos`), the Head steps (6,000) each - the same hour and three quarters as the 60,000 over all of
them; a video it does not learn from takes the mean look, as one left out (`head.Footage`'s `unchosen`). On his
footage they are his long talking videos, this set's among them. The Head, Avatar and Fit steps' versions are
raised: they are made again.

**Not done, measured mixed:** the bake freed (its pull toward the head off, its face growing anywhere): from a sharp
head its eyes and nose went 0.41 to 0.51 trained and 0.49 to 0.63 unseen - but 21.71 to 21.30 dB unseen, and the two
changes were not measured apart. **Not tried:** keeping the moments with something held before the face out of a
set's frames (head_frames.py drops only a hand at the mouth); not pruning after the growth ends (3DGS does not).

### What is made again

Generate makes again, in order: Motion (36 s), Utterances (21 minutes on the processor) and Voice (6,000 lessons,
under an hour); Head (about 1.7 hours); the set's Avatar (7 minutes) and Fit (3). A copy of a video is left out
on the card at once.

## The second build: a still and a model (2026-10-21, night)

**The user's verdict on the first build:** "it's pretty clear that there is no 'model' here. The actor
is just a series of stitched-together frames ... The mouth is detected well enough, and it does move,
but it doesn't track the voice at all really. Then there's all of the random gestures and the globe
and such, which are cropped by the jump-cuts. Overall, it simply doesn't work in a way that would be
usable in any capacity." And: the sets are pointless when only one is used - "I would be more
inclined to extract features not into separate sets for each video, but into separate sets for each
action, each pose, each mouth-shape"; "the average of all samples is likely to be a pretty normal,
forward-facing actor, with a mouth that moves when speaking."

**What was measured on his built set before changing anything:**
- **The mouth picked from the library followed the voice's target closely** (jawOpen, drawn against
  wanted: correlation 0.97 over 12 s) - but **the target scarcely moved**: the range visemes put "open"
  at his 92nd percentile of jawOpen (0.26), the dominance blend held it near 0.09 +- 0.05, and on a
  still frame the lips barely parted in three seconds of speech. His clean, visibly open mouths sit at
  0.45 to 0.6.
- **His own talking was under every frame:** the takes are him speaking, so his cheeks, beard and head
  moved to words he said then, around a mouth moving to the voice.
- **The library held faults:** its "most open" mouth was a hand over his mouth, others a smeared
  mis-track, motion blur, an object across the lips. And three mouths mixed every frame doubled the
  lips and teeth.
- **His head turns widely** (yaw 43 degrees from the 5th to the 95th percentile, much of it toward his
  monitor) **and 97% of its motion is under 2.5 Hz** - so the survey's five looks a second hold it, over
  all eight videos (117 minutes facing the camera).
- **A prototype, looked at:** one still of him, the mouth drawn from one clean real mouth per sound
  class (exaggerated twice past his own, at most two mixed, a mask tight to the lips) and the head
  turned 5 degrees through its 3D points - it read as speech (open with teeth on the vowels, closed on
  the M's), and the turn was clean up close: hair, beard and room held.

**The design:**
- **The base of every frame is ONE STILL:** a real frame of the set, the most typical calm moment -
  facing the camera, eyes open, mouth closed, hands at rest, nothing in front of them, sharp - chosen
  from a few candidates (`stills`), and another can be picked on the card. No footage plays, so no
  hand, prop or jump cut is ever seen.
- **What moves is a model of them, from all their footage:**
  - **the head** (`motion`, per actor): their own head motion where they face the camera, from every
    video's survey, its slow drift taken out, played back in pieces from a seed, scaled to a calm size
    and livelier while they speak; it turns the still's face through its 3D points;
  - **the eyes:** blinks at their own rate, more often at pauses, drawn from their own closed and
    half-closed eyes;
  - **the mouth:** each sound class's PROTOTYPES - a few clean real mouths each, from any video, at the
    still's turn, chosen for a target pushed past their own range by the Articulation setting
    (`library`) - at most two mixed at a moment, by the voice's phones (the dominance functions as
    before), inside a mask tight to the lips; silence is the still's own mouth.
- **A set is only where the pixels come from:** its still, its rig and its library (minutes to build).
  What is the actor's, not a set's - their range of mouth shapes and their motion - comes from every
  video. **No track:** the 30 fps track, the takes, the frames extracted, the gestures, the habits and
  the director are gone (the 80 minutes and 3.5 GB a set took).
- **Gestures may come back as the head's own** - a nod, a tilt, the brows - placed by a director on the
  words; not in this build.

**Built (2026-10-21, night):**
- **Steps** (`ActorSteps`): fetch, captions, probe, survey, shots, words, sets, audit as before; then
  per actor `visemes` (their range, every video's survey) and `motion` (`motion.json`: runs of their
  head's quick motion where they face the camera, which looks are speech, blinks a minute); per set
  `stills` (six candidates, `stills/` and `stills.json`), `rig` (the mesh on the first still, the face's
  box, `mask_mouth.png` tight to the lips, `mask_eyes.png` round the lids, `eye_weights`) and `library`
  (`library.json`, `library/`: three prototype mouths a sound class, two eyes half closed and two shut;
  the Articulation setting, default 2). Gone: track, takes, gestures, frames, the director, the gesture
  mark, `ActorTrack`, `LikenessFrames`, `rules/likeness/gestures.yaml` and `director.yaml`.
- **actor.py:** `survey_records` (every usable look of the given shots, across videos), `stills`
  (scored against the set's median picture and person, the hands against their LOW resting place - the
  hands seen are mostly raised ones, so their median is a gesture - the brows and smile at rest; then
  looked at again at full size, sharpness counted), `rig`, `visemes`, `motion` (`high_pass`, `runs_of`,
  a look past 4 of their spreads ends a run), `library` (candidates found in the surveys, seeked and
  re-measured at full size by MediaPipe in IMAGE mode, a face straying from the others' median - a hand,
  a mug - left out, a blurred one only where nothing else is; pushed targets on the shapes that show,
  never mouthClose: pushed, it chose open jaws for P B M).
- **Playing** (`LikenessPlan`, `LikenessFace`, the shader): the head - motion pieces drawn from the
  seed, blended 0.8 s into each other, read between looks by Catmull-Rom, at 0.6 of their own size and
  livelier while the voice speaks, eased past `MOST` - turns the still's 3D points about the neck;
  blinks at their rate and at pauses (70 ms closing, 40 held, 130 opening); the mouth is the two
  strongest pulls less the third, over the strongest, the rest the still's own mouth
  (`Visemes.strongest`: continuous - stepped a tenth of a millisecond, no share moves 0.02). One layer,
  one still texture, one library texture array: a frame costs about 0.5 ms (the first build's 2-8).
- **The card:** a Still row (the set's six, the one in use marked, a click uses another - nothing made
  again); the library line says mouths, sounds, eyes, minutes of motion and blinks a minute; a set
  builds in a few minutes; the Likeness card had the Performance (the seed) and nothing else - since
  2026-10-22 there is no Likeness card: the Actor puts them on the stage, the seed the note's own (see
  "The Actor puts them on the stage").

**Looked at, on his footage (through a scratch copy; his folders only read):**
- **Stills:** the first pick took a raised hand for rest (a wrist under the shoulders but mid-gesture),
  the second took gestures for rest (the median of hands seen), the third - the low end - gave four of
  six calm with hands down; the first of them is the default.
- **The library on all eight videos:** 42 mouths for 14 sounds and 4 eyes in about two minutes, all from
  the still's own set once another set cost 1.5; P B M pressed (cost 1.4-2.1 against 37-48 before
  mouthClose was left alone).
- **His motion:** 60 minutes kept in 164 runs; his quick motion's spread 3.3 degrees yaw, 3.5 pitch,
  2.2 roll; 30 blinks a minute from the survey, 33 from the 30 fps track.
- **Live, in the real app with the real voice** (`likeness_live_probe --stamp 1 --bake 1`): ready, the
  library in, the phones arriving; the medium 0.4-0.6 ms a frame. A baked take of 30 s drawn frame by
  frame (`likeness_look_probe --take`) and joined with its sound: the mouth opens on "fox" and "dog",
  presses on "jumps"; the head moves and settles; blinks at pauses. **The drawn jaw (MediaPipe on the
  frames) against each phone's intended openness: 0.59, peaking one frame after the phone starts** -
  its middle, so no lag; against the voice's loudness only 0.08, but his own footage scores just
  0.16-0.32 on that (loudness is a poor stand-in, and the room's ambience fills the pauses). It opens a
  little less than he does at the top (jaw 0.20 at the 90th percentile while speaking, his 0.30):
  Articulation raises it.

**For the user to test:** Generate on the Actor card once (the new steps: about five minutes, no
track), a still picked on the card if the default is not the one, ▶ on a note; then an export.

## One head (2026-10-23, night)

The user: "It's pointless to build a gaussian splatting model if the scenes can only generate from a single set
of images. So yes, let us search for a kind of learned blend, which can inherit features from the actor across
all sets." And of the body: "it never moves at all. It just floats around, weirdly, stiffly ... there must be a
way to at least allow the body to shift and morph a little bit."

**What is the actor's and what is the set's:**
- **The actor's (every video):** each sound's mouth, motion, blinks, glances, posture, voice - and now THE HEAD.
  - **Head frames** (per video, `hosts/avatar/head_frames.py`): about 300 moments picked from its survey, never
    read whole. Half are taken farthest-first in the scores and the turn (the mouth weighted most); half are
    spread evenly through the video; none is within 0.6 s of another or has a hand at the mouth. Each is read at
    full size and looked at as frames.py looks.
  - **Head rig** (`rig.py` over every folder): one neutral face, one basis, each frame's video.
  - **Head** (`hosts/avatar/head.py`): one set of head splats, learned from every video at once. Each video has
    a LOOK: a code of 8 numbers that mixes per-splat shifts of place and colour, as the expression does. Each
    video also has its own room (`room_of`) and its own light body, so the head is never asked to paint a
    video's clothes.
- **The set's (one shot):** its moments (`head_frames.py` over its shots, 160, with its stills), posed against the
  actor's face (`rig.py --shared`). Then `hosts/avatar/bake.py`: the head held, the set's look, room and body
  fitted to its moments in 2,000 steps, the head baked in that look, written as an avatar. Then Fit, as before. A
  new set costs minutes, not a 40-minute training.
- **Godot reads the same avatar files.** `train.Frames` takes the components the splats were learned with
  (`expr`): the head's.

**Measured:**
- **The moments read:** 21 videos, about 2.5 minutes each. 20 read; one's file had been moved.
- **His open mouth:**
  - The plaid video's 299 moments hold 17 with jawOpen past 0.35: 5.7%, against 1.5% of its 2-fps shot.
  - All of them together hold about 260, against the plaid shot's 76.
- **One face over 19 videos:** 5,353 frames, the head's pose fitted to 3.78 px (one video alone: 2.25). The
  scores explain 52% of the face's movement (lips 64%), against 59% (lips 64%) for one set's.
- **Trial** (5 videos, 600 steps): the looks start at none along with the shifts they mix, and neither was ever
  pulled. The codes now start at 0.3 spread (`CODE_START`); the looks then shift the colours 0.15 to 0.41 (logit).
- **The whole chain on the plaid set,** from the trial head: its moments (2.4 min), posed (3.06 px), baked (19.4 dB
  on held-out moments round the face) and fitted (21.9 to 28.9 dB in 300 steps).
- **The head, 19 videos, 40,000 steps** (`dist/head_test/head19`, 44 minutes, 53 ms a step):
  - 21.0 dB round the face on 275 held-out moments of every video, each as its video looks; the plaid set's own
    avatar scores 21.3 on its one shot. The score is flat from step 25,000.
  - 134k head splats. The looks shift its colours 0.18 to 0.56 (logit).
  - Its previews draw each video's light, expression and turn from one head (a pair of glasses it does not
    draw), but softer than one set's own: his hair, worn every way, is the blurriest.
- **The plaid set from it:** posed 2.85 px, baked 1.6 minutes, fitted to its still 21.9 to 33.3 dB (its own
  avatar's fit: 33.4).
  - Held whole, the head is soft, and below the beard it smears an average of every collar over the shirt's.
  - **Adapted** (the bake fits the head's own numbers to the set, pulled toward the head's: the face's surface in
    full, what is far from it or on the head at FREE_PULL): the face is sharper; the smear under the beard stays.
    4,000 steps, 4.9 minutes; a new set is about ten minutes in all.
  - **On a held-out moment of the set,** his mouth wide with his teeth showing: the render played from the scores
    opens it and shows teeth, which the set's own (ASMR) avatar never saw. A dark streak sits on one cheek.
  - `dist/head_test/per_set_vs_one_head.mp4`: the set's own avatar on the left, from the one head on the right,
    over his voice's take.
- **The smear, found:** drawn alone, the head's splats painted the neck, the collar and the shoulders: an
  average of every collar. The body had a hole there - laid clear of a box round the head, and not fitted where
  the head is solid.
  - Pulled toward clear below the mouth, far from the face: 2k of them went.
  - Below the chin: 21k of 50k went, and the rest still painted it. The neck's splats are bound to the jaw's
    edge, near it, so "far from the face" missed them.
- **Fixed: below the chin the head is the set's own.**
  - Every shared splat below the chin is dropped (MediaPipe's 152 is the face's lowest point): 50k.
  - The set's own are laid there from its moments, as train.py lays a set's: 10.8k, the beard bound to the jaw's
    edge. They are free, and grown with the set's body.
  - The body is laid below the chin up to the face (`up_to_face`).
  - On the plaid set: the collar, the neck and the undershirt clean, the beard whole, the face near the set's own.
    A green speck beside the nose in a frame (one stray splat).
  - Bake 5.9 minutes, Fit 3.6 (33.3 dB). `dist/head_test/per_set_vs_one_head.mp4`.
- **A step a program makes and the builder did not land** (`_land_process` listed its steps by name): Head frames
  ended "done" with no stamp, so missing, and was started again - a video's moments read over and over, found by
  running the steps for real on a copy of the actor. Now every step with a main file (`MAIN`) is landed and
  stamped; `actors_check` holds every program's step to having one.
- **Open:**
  - The head's softness: more splats or steps, and a look of more than 8 numbers for his hair.
  - Judging these by eye: a vision agent shown the bake's previews, as Cards' art director is shown each painting
    (the user, 2026-10-23: "putting agents into that part of the loop"). PSNR called the held head as good as one
    set's own, while the collar was a smear.

**The body bends** (`train.second_of`, `splat_head.gdshader`):
- **A second influence per body splat,** by where it rests in the still:
  - The torso keeps more and more of the still from the chest down to the hips (0.9 at the seat), so the chest
    and shoulders lean, settle and breathe over a seat that stays.
  - A shoulder goes with the torso inward of its joint, and an arm with the bone above it near its start.
- **Godot blends,** handed every bone's 2D move (`SplatHead.pose_bones` -> `moves`).
- **Gate:** `splat_head_check` - the bone moved and its splats half held by the still, drawn as the rules say;
  the control is the same move unheld.

**A moved video is the same video** (`ActorSources.rescan`, `_moved_here`):
- **The user merged** "Ephemeral Rift" into "Ephemeral Rift (more)", which left eight videos missing at their
  paths. An id is its path's, so a rescan would have added them as new - to be surveyed again - and the sets
  made of them would have lost them.
- **Now a missing folder video takes a file of its name** found in another of their folders. Its fetch token is
  named by where it was first found (`found_at`), so with `mv` keeping the file's time, nothing made from it goes
  stale.
- **Gate:** `actors_check` - moved, the same video with its survey still made; the control is a copy beside a
  file still there, which is a video of its own.

**A video with too few moments of their face is left out** (2026-10-24, the user's first run over all 65 videos):
- **Two failures:**
  - "Feeding Backyard Ants Boiled Egg Yolk": the audit gave it 131 s of shots, and the close read found no face in
    any moment. Its Head frames failed, and the error stood on the card.
  - A timelapse found one face in 47 looks. Head held that one moment out, which left the video nothing to lay
    its body from, and `train.initial` crashed (`argmax` of nothing). The ASMR in the woods found 15.
- **Now a video of the head's that shows no face is answered, not failed.** Its moments are written empty
  (`head_frames.none_of_theirs`) and its row says the head learns nothing from it. A set's moments still fail:
  a set is made from them.
- **Head leaves out a video with fewer than `head.LEAST` (20) moments:** no room, no body, and the others' mean
  look as its code (`looks_of`). Its Head frames row says so. Each video's share of the steps is its share of the
  moments, so a handful taught nothing anyway.
- **Gate:** `test_fit.py` - videos of 30, 25, 3, 1 and 0 moments: the last three left out, the others learned from
  and held out; the control, with no floor, holds out the one moment and leaves it nothing.
- **A room is kept small** (`head.Rooms`). Measured on the real rig, 1000 steps:
  - Before: 63 rooms held as train.Scene holds one (plate, seen and move in float, the move's Adam state too),
    about 108 MB a video and 6.8 GB together. The peak was 7.65 GB at step 1000, heading for about 10 GB at
    500k head splats, on a 16 GB card where Praxis trains too (3.5 to 7.7 GB).
  - Now: the plate and seen are uint8, and the move is learned at half size and upsampled bilinearly (`move`: the
    cells round a window, cut to it). The rooms take 1.30 GB, and training peaks at 2.60 GB. The one spike is room
    building, 5.32 GB while a video's median is taken.
  - Loss 0.1664 against 0.1672, and the held-out PSNR 16.26 against 16.22 dB. 44 s against 58 s.
  - Gate: `test_fit.py` - over windows at the frame's edges and of odd sizes, the move is the whole move's
    upsampling cut to the window; the control cuts with no margin of cells.

## The room behind them, and how far a set reaches (2026-10-23, evening)

The user, on the plaid set (set-6f0cbf09) after the sweater one (set-0e8c1195): "The mouth barely seems to move
at all, and it almost never makes a shape. Is the rigging and such bound to ONLY frames from within a set?" And:
"the heavy blurring around the head ... when the wall is blurry, when the turtleneck of the sweater is blurry...
it looks pretty bad."

**What a set is, to the head of splats:**
- **One shot of one video.** `ActorBuilder.avatar_shot` takes the set's longest usable shot. His 53 videos fell
  into about 130 sets, and none of the large ones spans two videos: each video has its own outfit, framing and
  often its own room. "Set likeness" splits nothing that is one place.
- **The face rig, the splats, their 12 expression shifts, the body and the room are that shot's alone.** What is
  every video's: each sound's mouth (`visemes.json`, at percentiles of his own range), the head's motion, the
  blinks, glances and posture, and the voice.
- **The rig moves the mouth alike on both sets.** At Articulation 2, "open" parts the lips 13 px on the sweater
  set and 15 on the plaid (of a mouth 92 and 117 px wide); most sounds part them 2 to 8 px. The 12 components
  carry jawOpen at 0.70 and 0.99.
- **But the plaid shot barely opens his mouth.** It is an ASMR video. Frames with jawOpen past 0.35: 76 of
  5,216, against 330 of 8,926 on the sweater shot; past 0.45, 6 against 57; puckered past 0.5, 213 against
  1,464. So the splats there never learned his open mouth, and the same opening reads as nothing.
- **Articulation 3** (playback only for this renderer; set on his actor) parts the lips a little more and breaks
  nothing (`dist/look_mouth/plaid_a3`).

**The blur round the head was HIS BODY IN THE PLATE.**
- **The plate started from the set's room picture** (`room_K.jpg`). Where the room is never seen, that picture
  keeps the still's own pixels. That is right for the 2D renderer, which draws them over it where they stand.
- **No frame shows the wall there to unlearn it.** So the plaid set's learned plate held his face, beard,
  shirt and clasped hands, sharp. The sweater set's held a smeared face in rainbow streaks.
- **The splats leaned on it.** Anywhere not fully opaque showed the frozen copy: a smudged, see-through
  collar, and a second edge beside the ear and cheek as the head moved off the still's pose.
- **Now `train.room_of`:** each pixel is the median of the frames whose person mask (grown 12 px) leaves it,
  over 160 frames of the shot (10 s). A pixel fewer than 3 show is filled from round it (`fill_round`: push-pull,
  smoothed to a harmonic fill). The plate learns only as far as it is seen (`Scene.seen`).
- **On the plaid shot,** 71% of the picture is seen.
- **The Avatar step's version is 2:** every avatar made before is stale.

**A short run ended faint.**
- **The splats are made faint every 3,000 steps** until step 20,000, so a 12,000-step run ended on a reset:
  21.2 dB at step 10,000, 17.0 at 12,000.
- **The growing now ends at two thirds of a shorter run** (`train.until_of`). The default 30,000 is unchanged.

**The test run** (`dist/look_mouth/plaid_v2`, 12,000 steps):
- **Held-out frames:** 21.2 dB round the face and 18.0 round the body, against the old 30,000-step avatar's
  21.3 and 18.1 with his body in its plate.
- **Fitted to still 11:** 21.8 to 31.0 dB.
- **In Godot** (`dist/look_mouth/old_vs_new.mp4`, the old fit on the left): the collar and neck under the beard
  are whole, and the head has one edge against the wall as it moves.

**Open: one head for every set.**
- **The shared head:** the head's splats (face, hair, beard) learned from frames of many videos, each video with
  a learned appearance code for its light (a per-video colour shift basis, as the expression shifts are mixed),
  while the body and room stay the set's.
- **What it buys:** hundreds of open-mouth frames, and his face from more angles.
- **What it costs:** Frames for every video, a longer training, and his look changing between videos (hair up
  or down, the beard's length).

**Gates:** `hosts/avatar/test_fit.py`:
- The room as the frames show it, with the plain median holding the person as the control.
- The hair past the mask left out, with the control of no margin.
- The fill of a ramp.
- The plate moving only where seen.
- A run of any length ending well past its last reset.

## The body as the still holds it (2026-10-23)

**What the whole of them learned** (run 2, 40,000 steps, up to 600k splats): the face as good as before, the
body a dark blob with ragged edges, the sweater's knit gone, the hands two flesh-colored smudges. On held-out
frames, 23.2 dB round the face and 20.4 round the body: the same as run 1 with a third of the splats. More
splats sharpened nothing, so the frames did not agree.

**Measured: nothing holds a sweater still from frame to frame.**
- **The pose's torso jumps where he sits still.** Every half second, its width moves 3.5% and its place 20 px
  at the median (11% and 48 px at the 90th percentile), and its turn 1.8°. The face's own scale, from its
  468 points, moves 1.6%.
- **His chest, lined up by each candidate frame and medianed over 300 frames.** Each frame's share of its own
  fine detail that the median kept:
  - The whole patch, the desk and the microphone in it: 0.43 held at the set's median torso, 0.10 on the
    pose's torso.
  - The upper chest alone, between the shoulders and above the desk: at most 0.09 by any frame tried. Held
    still 0.09; the pose 0.07; the pose smoothed over up to 17 frames, a share of it, or the head's own
    shift and scale 0.04 to 0.07.
- **Aligning each frame's chest to the median** (shift, scale, turn: congealing) ran away. Frames slid
  42 px at the median and 198 at the 90th percentile, onto flat dark places where any frame matches.
- **Even the frames with his arms at rest,** medianed, keep no knit, and the hands smear. He sways and
  leans, and the knit stretches and folds as he breathes and moves his arms. No rigid frame of reference
  undoes that, and there is no tracker precise enough on a loose sweater.

**But the body that is played is the still's,** moved by its bones. So **THE FIT** (`hosts/avatar/fit.py`,
the Fit step, about two minutes):
- **Only the body's splats are fitted again,** to the one still played. The head's splats and the room are
  held as learned.
- **On his still 8:** 26.6 dB where it is fitted, before, and 32.3 after (run 2's avatar). The knit, the
  folded hands and the forearms on the desk are the still's, and a torso turned 3° carries all of it as one
  piece.
- **Under the microphone** they are fitted to `body_K.jpg` (the still filled from round it), and their
  outline is not asked for there. Left free, the splats under it had grown red and green garbage.
- **Not where the head is solid** (cover over 0.9). Body splats fitted to one picture could paint its face
  there, and the torso would carry it. What lies behind keeps what the frames taught, and it shows through
  the beard's soft lower edge.
- **Never needles:** a splat's longest side is at most `FIT_LONG` (6) times its next. Fitted beside the
  beard, body splats grew into its strands.
- **The splats may grow** to `FIT_MOST` (360k) in all: about 396k came out, 177 MB of `.bin`. Every body
  splat still carries 24 texels of expression shifts that are always zero; the shader now skips reading
  them, and a compact layout is open.
- **Picking another still makes the Fit stale** (the still is in its fingerprint), and nothing else. Until
  it is fitted again, the medium plays the still the fit was made for (`fit.json`'s `still`).

**THE HEAD'S SPLATS HAD PAINTED HIS CHEST:**
- **On run 2's avatar:** the head's splats covered past 2% across a fifth of the frame, and past 50% in
  patches on the chest. 505 large faint ones, bound to the head with nothing holding them near it, did
  that. It was part of the smear "along the sweater": a chest that turned with the head.
- **Now dropped:** a splat of the head or the face whose centre stands past the head's region
  (`train.head_region`, grown by `HEAD_REACH` 16 px) is dropped every 100 steps in training (`train.astray`)
  and before the fit. Run 3 drops 500 to 1,700 every 1,000 steps.

**Run 3** (the strays dropped in training, 36 minutes): the same scores on held-out frames (23.1 dB round the
face, 20.4 round the body), none of the head's splats astray at the still's pose, and the body behind the
beard a plausible dark turtleneck. Fitted to still 8: 26.8 to 32.0 dB, 401k splats. **In Godot**
(`likeness_look_probe --renderer gaussian --take`, his own voice's take: `dist/avatar/demo_fit/fit_demo.mp4`):
the knit, the folded hands, the turtleneck under the beard. Change per frame (1/255, mean / largest): the head
1.14 / 4.06 and the beard's edge 0.90 / 4.55, against last night's head-only demo's 1.52 / 9.50 and 1.48 / 7.07
(rendered 1280 wide, this one 960); the chest 0.30 / 1.82 and the hands 0.21 / 1.21, moving as the bones do.
Loaded in 0.66 s (0.2 after), posed in 5 ms; drawn as the trainer draws it, 32 to 40 dB over the frame.

**Its limit:** each splat is bound to one bone. A pose far from the still (a lean, an arm raised: a held-out
frame) shatters the fitted sweater along its bones, in the trainer's drawing and Godot's alike. Played, the
body stays near the still (posture shifts, breath), so it holds. Gestures would need splats skinned across
bones, as the 2D body's mesh is.

**Gate:** `hosts/avatar/test_fit.py` (the training venv, no graphics card): the needle cut, the head's splats
past its reach (in the face and the hair kept; over the chest, far off and off the picture astray; a body
splat there kept), and the still as one more frame (its bones' axes read as columns, against a non-symmetric
control; tracked and played alike).

## The whole of them (2026-10-23)

**The user, on the head of splats:** "an EXTREMELY solid result ... the blurriness doesn't bother me that much
- because it actually gives the head depth ... It looks like real 3D." And: "the movement is restricted to the
head. I would like to see the gaussians applied to more of the scene ... such that his body might be able to
move"; "the head region is somewhat unstable and jittery ... at the edges (the tip of the beard, along the
sweater, around the head against the wall) - those parts are very smudged and smeared."

**What the edges were, measured** (the demo's change from frame to frame round the head, its expression
shifts on and off): with them, the beard's whole lower outline flickered as a bright ring, and the head's
outline glowed. Without them, only the eyes and mouth changed (0.71/255 a frame against 0.47). The shifts were learned
for the face, and a splat far from its triangle (the beard's tip, the hair's edge) swings on a lever with each
one. Played, they were also pushed by Articulation past the range they were learned in.

**Built:**
- **Shifts only on the face, fading with distance:** a splat takes its shifts fully on its triangle and none
  two of its units out (`SHIFT_NEAR`, `SHIFT_FAR`; train.py's `Splats.shift_weight`, the shader alike). The
  expression a sound is played with is its own scores, not pushed: Articulation pushes the face's geometry
  only.
- **Whole frames** (frames.py takes [x, y, w, h]; the Frames step reads the shot whole) and **the body's bones**
  (rig.py's `BODY`, the 2D rig's bones less the head):
  - **The bones:** the torso, the shoulders, each arm's upper arm, forearm and hand, from the pose.
  - **In one plane** half a shoulder width behind the face's nose tip. MediaPipe's pose guesses at depth (its
    shoulders stood 240 px apart in it), the camera is fixed, and a splat's own depth on its bone is learned.
  - **Every frame with a face is posed,** a hand at the mouth included (the hand is theirs). The expression
    basis is fitted only on frames with no hand there.
- **The trainer learns the whole of them over their room** (train.py, rewritten):
  - **Binding:** the face's triangles, the head, the nine bones.
  - **A bone not seen in a frame** has its splats drawn clear there, so a hand under the desk is not learned
    from MediaPipe's guess. Each bone's first splats are laid in the frame where it is seen best.
  - **The room is a learned plate:** the set's room plate to start, refined where the frames show it, with
    a gain per frame for the light. The halo against the wall came from edge splats painting the gap
    between a guessed room and the true one.
  - **Each step** learns a 704 px window of a whole frame, half of them round the face.
  - **The export** has the bones and `avatar.plate.png`.
- **Godot** (`SplatHead`):
  - **`pose_face`** carries the head on the torso (a 2D transform).
  - **`pose_bones`** places the bones as the still holds them, each moved as the 2D body's bone is
    (`LikenessFace.bones`: posture, breath, lifts, resting hands). A bone the still does not show is
    flagged, and its splats are drawn clear.
  - **The medium** draws the avatar's room and hides the still's 2D layer, so the head cut-out is gone.
  - **The gate** holds a bone, a hidden bone and a leaning torso to the rules (10 checks).

**Data, asked (the user: "Do we have enough training examples? This actor has hundreds of videos"):**
- **More of this shot would add little:** 9,000 frames at 2 a second already sample his range.
- **More videos add** expressions, mouth shapes and slightly different camera places.
- **They also add his look's changes** (lighting, hair, beard, glasses, clothes), which pooled naively
  would only be averaged.
- **The plan:** unwrap his face from each video's frames onto the rig's canonical layout, compare videos
  by the cosine similarity of their mean unwrapped faces, and let in those that show the same him,
  weighted by it. Each keeps its own room plate and light gain.
- `scripts/fetch_channel.py` fetches his newest N videos (Shorts left out) into a cache, standalone, with
  its own yt-dlp kept current.

## A head of splats (2026-10-22, night)

**The user, on the 2D version:** "acceptable as a first attempt, a draft, a proof-of-concept. It sells
the idea... though every single part of it is janky ... because of the uncanny valley." Then: "I want to
come back to the gaussian splatting idea ... What would it take to try and support two modes for the
'Actor' card ... 2D (the current) and gaussian". And: "try to minimize the number of external
dependencies. If something can be reimplemented here, that might be the better approach."

**What was decided:**
- **No FLAME, no SMPL-X, no gsplat.** The face and body models need an account with the institute
  that publishes them (credentials), and gsplat compiles CUDA with nvcc.
- **The surface is MediaPipe's own face mesh,** which ghost already tracks. Its triangles are read off
  its tessellation (854 cliques; 6 edges on more than two are cleaned), with the mouth's and the eyes'
  holes filled.
- **Splats are bound to its triangles** (GaussianAvatars' binding), or to the head for the hair and ears.
- **The rasterizer is ours, in Triton,** which ships inside the PyTorch the voice already fetches.
- **The renderer is ours, in Godot.** The camera is fixed and the head turns little, so the splats are
  drawn in one order, back to front as the neutral face stands, and never sorted per frame.
- **The head is splats; the body and room are the 2D still's,** drawn under it.

**Built:**
- **`hosts/avatar/frames.py`** (face_venv): the set's longest shot read twice a second at full resolution,
  cropped round the head. Each frame gets MediaPipe's 478 points, its 52 scores, the head's matrix, the
  body's points and the person mask; the set's stills are tracked alike.
- **`hosts/avatar/rig.py`:** their neutral face; each frame's pose (a similarity fitted on the points
  that move least); a ridge basis from the 52 scores to every point's offset (what drives the playing
  head); the triangles; and `poses.json` (each still's pose and scores, their median scores, the shut
  eye's score).
- **`hosts/avatar/raster.py`** (+ `test_raster.py`, 4/4 with controls): a tile rasterizer, forward and
  backward in Triton, held to a dense PyTorch reference to 3e-7. Forward plus backward takes 4 ms for
  100k splats at 512 px. Its header lists the exact rules for a port.
- **`hosts/avatar/train.py`** (voice_train_venv, the graphics card's lane):
  - Each step takes one frame, places every splat from the tracked face, renders it over what is
    behind the head, and scores it: L1 + D-SSIM inside a region round the head, plus cover against the
    person.
  - It has a colour correction per frame, 3DGS's densification, and GaussianAvatars' regularisers.
  - **What is behind the head** is the room above the mouth, and below it their own body where the frame
    shows it (a pixel near their clothing's colour). The first run painted the sweater round the beard
    with splats bound to the jaw, a dark smudge.
  - It writes `avatar.npz`, and `avatar.json` + `avatar.bin` for Godot.
- **`hosts/avatar/look.py`:** held-out frames as played, with their poses, for the probe.
- **`src/likeness/splat_head.gd` + `.gdshader`:** one instanced quad per splat. A data texture holds the
  splats; a small float texture holds the binding frames, posed each frame in GDScript (6-8 ms) from the
  scores. The vertex shader places each splat as the trainer does, and the canvas blends them over.
- **The medium** (`LikenessMedium`, renderer "gaussian"): the splat head on a layer between their body
  and what stands before them.
  - **Its scores:** the still's own; each sound's mouth from `visemes.json`, weighed by the plan's pulls
    and pushed past their own by the Articulation setting (as the 2D library is); the lids as far shut as
    the blink; the glances (the Face rig's `looks`: the eyes and brows as they look that way most).
  - **Its pose:** the still's, turned by their motion about the neck, carried by the torso.
- **The Actor card's Renderer** (2D / Gaussian, the block's `renderer`):
  - **Gaussian steps:** Frames, Face rig and Avatar.
  - **2D only:** Library and Learn.
  - **Shared:** everything else.
  - The card shows and the builder makes the note's renderer's steps; the other's settings are kept.
  - `ActorSteps.RENDERERS` says what each needs to play. `ActorBuilder.cannot_train` (was
    `voice_unavailable`) leaves every graphics-card step alone without an NVIDIA card.

**Measured, on his set (the long shot of "Wasting Precious Time", 75 minutes):**
- **The frames:** 9,031 at 2 a second. Over the whole set, 8,632 frames had a face and no hand at the
  mouth; hands anywhere round the head are left out of learning.
- **The rig:**
  - **Head pose:** fitted to 2.3 px on 143 points.
  - **The scores alone** explain 58% of the face's movement on held-out frames: 69% of the lips', 72% of
    the eyes'. Drawn over the frames, the rig's lips and lids sit on the tracked ones: wide open, half
    open, blinks.
- **Training:**
  - **Speed:** about 40 ms a step at 512 px. It reaches 260k splats by step 15,000.
  - **Held out:** 24 dB PSNR in the head's region, with no colour correction there.
  - **By eye:** at 2,500 steps it is recognisably him; the played face (from scores alone) and the
    tracked one look alike.
- **Godot against the trainer** on the same poses (`tests/likeness/splat_head_probe.gd`): 30 dB on the
  head and 37 dB over the square. The differences are fine edges, the price of one draw order. Loading
  127k splats takes 130 ms.
- **Live in the real app** (`likeness_live_probe --renderer gaussian`): it plays, reading in his own voice,
  his head a 3D head over his body and room.

**What it found on the way:**
- **A set's shots are not one framing:** his first two are framed wider, so a head is learned from the
  longest shot only (`ActorBuilder.avatar_shot`).
- **A hand raised beside the head** is in the person mask, so such frames are left out.
- **The sweater smudge** round the beard (above).

**Since the first run:**
- **Learned at full resolution** (704 px, the crop's own): 248k splats, 33 minutes, 24 dB on held-out
  frames.
- **The still's own head is cut out above the mouth** (`likeness_warp.gdshader`'s `head_cut`, from the
  trainer's region): the room shows through the splats' soft edges, as they were learned.
- **The played face mixes faces made once** (`SplatHead.face_of`): each sound's, the shut lids', each
  glance's. A frame mixes three or four of them, not 52 basis arrays.
- **A demo** of the probe's sentences in his own voice, frame by frame from a baked take
  (`likeness_look_probe --renderer gaussian --take`): `dist/avatar/demo/splat_head_demo.mp4`.

**Why it was soft, measured:**
- **Not registration:** fitting each frame's pose with the splats held lowers the error only 1.5% (0.2
  degrees, 0.9 px).
- **Little the light:** learned on the 15 minutes round the still's time, it is 0.6 dB better on the
  same held-out frames (25.06 against 24.48), and as soft by eye.
- **Underfit:** its error on the frames it learned from is near its error on those it did not (L1 0.034
  against 0.0385). One place and one colour for every expression average away what changes with it -
  the teeth, the creases, the lips' own shapes.

**So a splat changes with the expression** (GaussianBlendshapes, SIGGRAPH 2024):
- **The expression** is the 52 scores' first 12 principal components over the frames learned from, each
  scaled to its spread.
- **Each splat** has 12 shifts of its place and 12 of its colour's logit, mixed by the expression, and
  pulled toward none.
- **In Godot:** the export writes the shader's data texture whole (28 texels a splat). The shader mixes
  the shifts by `expr`, which `SplatHead.expr_of` makes from the scores. The medium makes each face's
  expression once and mixes it with the face.
- **More splats:** the most is now 400k.
- **The gate** holds it: drawn at 0.8 of an expression, 0.48/255 from the rules; its control, drawn at
  none, does not match.
- **Its first run** (40k steps): his teeth show in a smile where the run before had a blur, and held-out
  error is level (24.22 dB against 24.18).

**And a fog:** that run's median splat stood 4 px wide. Only 15,544 of its 180k splats covered more than
0.05, and 2,004 more than 0.7: the head was a fog of big faint splats, stacked, and a fog is soft.
- **The cause:** densification copied whole every splat up to 1% of the square (7 px). 3DGS's 1% is of a
  whole scene's extent; a head that fills the square needs a finer cut.
- **The changes:** split above 0.2% (`SPLIT_SHARE`). Once the splats stop growing, each cover is pushed to
  decide, on or off (its binary entropy, `DECIDE`), and the nearly clear are dropped every 1,000 steps.
- **The result:** 7,566 splats at the end (from 222k at densification's height), held-out error level
  (24.21 dB), and by eye the same as 180k. The splats were never what limited it.

**So what is soft is what the frames teach.** A splat settles on the average of what it sees in every
frame, and fine detail - pores, creases, strands - slides a pixel or two against MediaPipe's coarse mesh
from frame to frame, the beard's strands on their own. The papers get sharp heads by tracking the face
against the pixels themselves (photometric tracking, dense correspondence), which is the next piece of
work if this is taken further. Kept: run4 (`dist/avatar/run4/`), light to draw. The demo is
`dist/avatar/demo4/splat_head_demo.mp4`: the probe's sentences in his own voice, with sounds, blinks and
glances.

**Not yet:**
- **The mouth opens less than his own;** Articulation pushes it.
- **No export has been made with it** (the demo is the look probe's, frame by frame).
- **Gates:** `tests/likeness/splat_head_check.gd` (GPU) holds the shader to the rules, worked out in
  GDScript on a made avatar: 0.5/255 mean. Its control transposes every splat's turn and is 12.7/255 off.
  Against a trained avatar, the probe prints the gap (30 dB on the head).

**To try it:** Renderer → Gaussian on the Actor card, then Generate. Frames takes about 25 minutes on the
processor for a 75-minute shot, Face rig seconds, Avatar about 25 minutes on the graphics card. Then ▶.

## Their own voice (2026-10-22)

**The user, on the fourth pass:** "the model gives off the uncanny valley effect, and I'm doubtful we're
ever going to get past that with this 2D method ... I would like to know how tough it would be to
fine-tune this actor's voice as a Piper model. If you think we could wire up such a function, I would like
to give that a try next."

**What there was to work with (measured):**
- **His sound:** eight videos, 7.1 hours; one ("Why I love writing") has no sound track at all. Clean:
  his speech sits 25 to 42 dB over the room, nothing clipped, the full 11 kHz a 22 kHz voice holds.
- **Five of the eight are whispered.** A third of their loud frames carry a pitch, against three fifths
  in the two spoken ones ("Manuscript Day 45", "Wasting Precious Time": 128 minutes). A whisper is
  another voice; it is left out (a whispered voice of him would be a second one, taught on those).
- **Whisper's words, as Transcribe left them,** cover 20 minutes of each video (the Likeness needed no
  more), base.en on the processor: a median word sure at 0.91, a fifth of runs holding one under 0.34,
  and its errors are real ("Billings of year" for billions of years). Its word edges come early: his
  voice runs on 30 to 48 dB over the room just past a word's end.
- **Piper's trainer** is in its PyPI wheel (`piper-tts[train]` 1.8, GPL - fetched into an environment
  of its own, never shipped; the voice it makes is data), on PyTorch 2.14 with CUDA 13, which runs on
  this RTX 5060 Ti (sm_120). The wheel leaves its Cython alignment unbuilt: numba's, line for line the
  same search (`hosts/voice_train/align.py`), takes 6 ms a batch. It takes our own ids
  (`dataset_type phoneme_ids`), so the voice is taught exactly what the voice host will send it.
- **Clean bases to fine-tune from** (`rhasspy/piper-checkpoints`): John (medium, male, LibriVox public
  domain, itself fine-tuned from Kristin), LJSpeech (high, female, public domain), Kristin, Norman. Every
  lessac-derived one is out (Blizzard's terms). A John checkpoint exported by our own exporter
  (TorchScript, opset 15) loads, patches (one Ceil) and speaks through the voice host as Piper's own do.

**Built:**
- **Hear** (per video, the processor, speech_venv): the whole of each video heard by Whisper
  (`transcribe.py`, now in pieces of 10 minutes), told the ums came before so it writes them.
- **Utterances** (`hosts/voice/utterances.py`, voice_venv): his words in runs between pauses, 1 to 12 s,
  every word heard surely; each edge walked out to where the sound falls and cut at the quietest frame of
  the pause beyond (it must be within 12 dB of the room); none holding a sound no word was heard in (an
  um Whisper left out, a laugh); spoken, not whispered; all at one level - and the ids are the voice
  host's own (`ids_of`: its homographs, its eSpeak reading of the sentence, its lead-in spaces, its
  layout). Every 25th is held out (`test.csv`) to measure the voice against. On his videos: 637
  sentences, 46 minutes (42 of them from the two spoken videos), 26 held out; 475 whispered runs left out.
- **Voice** (`hosts/voice_train/train.py`, voice_train_venv, a lane of its own - the graphics card -
  beside the processor's): John warm-started (every weight, a fresh optimizer) and fine-tuned for the
  Voice lessons setting's epochs (150), bf16, batch 16 - about 25 seconds an epoch, an hour all told.
  The whole run is saved every 5 epochs (and at an epoch's end 10 minutes past the last save) under another
  name and renamed into place, so Stop loses a few minutes and ▶ goes on. AN EPOCH IS AS LONG AS THEIR
  SPEECH (2026-10-24): all 65 of his videos gave 6,909 sentences, 8.3 hours, about 5 minutes an epoch -
  150 epochs about 12 hours - so each epoch's line says the time to go; that run died of the graphics
  card's memory at epoch 2 (8.3 GB of its own, the card shared with another trainer), and the allocator now
  grows its segments (`PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True`); other sentences or another base start again from the base. When every epoch is
  done the voice is exported and PUBLISHED (`ActorBuilder.publish_voice`): copied to
  `<data>/ghost/voices/piper/trained/actor-<id>.onnx` with its config and a description
  (`<id>.voice.json`: their name, what it was fine-tuned from), where the
  voice host lists voices trained here beside its allowlist (`TRAINED`), never fetched. It is on every
  note's Voice card as "<name> (their own voice)".
- **The note it was trained on reads in it as it lands** (2026-10-22, the user after the first run in
  the app: "When I click on the play button, it's still using the regular Piper voice"). The Voice card
  had asked for its voices once, as the note opened, so a voice made in the hours after was never on it.
  Now `ActorBuilder.voice_published` -> `ActorCard._voice_made` -> `ReadingPanel.voice_made`: the voices
  are asked for again, and the reader's tab is set to it (`ReadingCast.voice_made`). A list asked again
  keeps what is picked. On any other note, or after a restart, it is picked on the Voice card like any
  voice. Gate: tests/reading/voice_made_check.gd. That first run: 915 utterances, 65 minutes of his voice
  from 7 videos (Hear across whole videos), 150 epochs in 99 minutes. Through the voice host it says a
  test sentence that Whisper (small.en) hears word for word.
- **A machine that cannot train** (no NVIDIA card, or a platform PyTorch has no CUDA build for) leaves the
  three steps alone; their rows say why (`ActorBuilder.cannot_train`).

**Measured** (no ear: the held-out sentences said by each voice through the voice host, against his own;
his pitch, his long-term spectrum and his MFCCs' distribution - `dist/voice_train/probes/likeness.py` -
and what Whisper hears each say, `wer.py`):

| voice | pitch median / IQR (Hz) | spectrum off (dB) | MFCC distance | Whisper's word errors |
|---|---|---|---|---|
| him, 26 other sentences of his | 154 / 53 | 0.96 | 0.22 | 2.5% (his own; mostly the transcript's) |
| John, the base | 119 / 34 | 4.70 | 4.08 | 4.3% |
| fine-tuned, epoch 10 | 135 / 31 | 1.32 | 2.07 | 31.6% |
| fine-tuned, epoch 30 | 137 / 40 | 0.98 | 1.17 | 22.6% |
| fine-tuned, epoch 120 | 140 / 43 | 0.81 | 0.82 | 18.9% |

The run was stopped at epoch 120 of 150 by the machine running short of memory (its save at 120 kept: ▶
goes on from it). **Their tone is there by epoch 30** (the spectrum as near his held-out speech as his own
other sentences are); **clarity is not**: a fifth of its words misheard, against the base's 4%. Read 20%
slower it is misheard just as often, so it is not the pace (it does speak quicker than John: the passage
in 21 s against 28). What is misheard is mostly vowels - "pots and pans" heard as "pause and pence", "as
many" as "his mink". **The likeliest cause, the next experiment:** John was taught on eSpeak's British
labels (`espeak.voice "en"`, as every published Piper voice of the base's line) and is taught him in
American ones, so the vowels' symbols are learned again from 46 minutes; taught in John's own labels, the
vowels it knows carry over (the voice's config then says "en" and the host reads it so). Then: Whisper's
errors in the sentences (base.en; small.en's second opinion was stopped with the run, 650 of 663 heard).
Listening (`dist/voice_train/listen/`): `0_him_heldout.wav` (his own, held out), `1_john_base.wav` and
`2_his_voice_epoch120.wav` (the same passage, the base and his voice).

## The fourth pass: a body, modeled (2026-10-22)

**The user on the third pass:** "This is kind of working, but the actor's body is completely rigid, and
it is just rocking around constantly. The hands remain in this strange open-palm gesture. The problem is
that we're not modeling the body - we're just shifting it around a bunch. I would have expected a more
relaxed, neutral posture - and one that isn't frozen in-place, rocking weirdly back and forth."

**Why, each (measured on his footage):**
- **The rocking:** the body played the quick part of his shoulders' motion (the slow drift taken out,
  4 s): about 60% of it swings with a period of 1 to 4 seconds, 0.75 degrees of tilt about a pivot at the
  frame's foot - 12 px at his head. It is his gestures pulling at his shoulders (the shoulders' quick
  motion is 40-70% larger while his hands move most than while they move least), and a still whose hands
  never move has nothing to pull them.
- **Rigid:** one transform moved every vertex of the body - hands, arms and torso as one block.
- **The open palms:** the still was chosen with its hands "against their low resting place", and his
  open-palm gesture is held at the desk's height. No measure of the body's points told them apart: on 21
  frames looked at by eye (8 at rest, 9 open-palmed, 4 holding a phone), the wrists' height, their
  stillness over 5 s, their range over 10 s, the hands' distance apart and the turn of the hand's points
  all overlapped. The stillest hands of the set were all holding a phone.

**Built:**
- **A skeleton on each still** (`rig`'s `stills`: `skeleton`, `skin`): from its pose - the hips (seen, or
  1.35 shoulder widths under the neck, behind the desk), the neck, each shoulder, elbow, wrist and the
  hand's end - and every vertex of its mesh weighed to its bones (actor.py `BONES`: the torso, the head,
  each shoulder, upper arm, forearm and hand), the mesh given points along each arm and its sides so an
  arm bends apart from what is behind it. A hand seen in the picture RESTS: it stays where it is (but for
  its own small drift) while the torso moves, and its arm bends between it and the moved shoulder - the
  elbow found as an arm's is (two bones keeping their lengths, bending the way they bent:
  `LikenessFace.elbow`). A hand out of the picture goes with its shoulder.
- **A posture, held and shifted** (`LikenessPlan.posture`): the torso holds a posture for about 1.8 of his
  own holding time (`motion`'s `posture`: the lag at which his 6-second posture falls to 1/e of itself),
  then shifts to another over 1 to 2.2 s - each drawn from his own range of posture with his axes' own
  correlations, half of it (a third of his tilt), keeping half of the last - with a slow sway under it
  (knots 3 s apart) so it is never frozen. Nothing quick is left in it: what is quicker than 4 s is 0.14
  of the posture's motion on the gate's made motion, against the head's 1.09 (body_check). The breath
  stretches the torso about the hips and lifts the shoulders, which also wander a little each on its own
  (`lifts`); the hands settle somewhere new, a few pixels, as the body shifts (`hands`). The head keeps
  turning on the neck by his own quick motion, and takes back 0.7 of the body's tilt, keeping its eyes
  level.
- **The still at rest** (`rest`, "At rest" on the card, an agent: `rules/likeness/rest.yaml`): the stills
  step keeps 12 candidates (two of six were at rest before) and puts them on one numbered sheet; a
  writer says which show him at ease - hands folded, resting or out of sight, nothing held, facing the
  camera - most at ease first (`rest.json`). The Likeness is drawn on the first unless one is picked;
  the card shows those first, marked; stills made again forget the pick.
- **What stands before them** (`front_K.png`, `body_K.jpg`): the microphone stayed in still 4's matte -
  its plain dark body has no texture for the third pass's test - and with the body bending it bent too.
  Now a pixel that is still the still's in 60% of the set's frames (at half size, each still judged
  against its own pixels in the first still's light: its color within 14 levels, and where the still has
  texture its patch alike too) and still the still's in the frames where he is there hides him - in a
  piece of 3000 pixels or more: it is drawn over him and never moves, his matte kept whole under it and his
  picture there filled from round it, so he moves behind it. One that never moves at his matte's edge is
  the wall his matte bled over: out of his matte, as before. Measured, still 10 of the new stills: by
  texture alone the microphone's body never matched; by color without each still's own light it never
  matched either (the light moves 15 levels over the hour); with it, half his dark sweater did too (its
  knit is gone at half size); by color, and texture where the still has some, the microphone's body and a
  few flecks. Its spider mount's thin rods and its cable are not found, and still move with him a little.
- **The room's frames were the set's first sixth** (a third-pass bug, found here): the plate took the
  first 90 of 540 looks spread over the set, in order - the session's first quarter hour, its light 13 to
  28 levels off the later stills' on the microphone, which then matched none of them. Now 150 across
  all of it.
- **The room behind a head where they seldom sit:** the plate was trusted where a quarter of the frames
  saw the room; behind still 10's head (he sits nearer the picture than usual) the wall shows in 4 to 14%
  of them, so all of it was filled from round it - a smear where the picture's frame was. Trusted by six
  frames alone, a patch of his own face came in at his hairline (frames whose segmentation missed his
  head) and the globe behind an arm. Now: a quarter of the frames, or six that agree (three quarters of
  them within 12 levels of their median: `trust`).
- **A light halo round the head:** his shadow on the wall is in the still and not in the plate (made
  where he is not), so the plate is now darkened or lightened as the still's wall just outside him is
  against it, spread 30 px inward (`SHADE`).
- **A light sliver in the gap between his arm and the chair:** his matte is soft there (0.2 to 0.5), and
  under it the plate's wall showed where the still showed the chair. Away from the head the plate is now
  used only where the still is mostly him (`SOFT`, 0.6): under a soft edge the room is the still's own, so
  at rest the picture is the still. Round the head (2.3 of its radii) the plate still reaches 12 px past
  his edge, so no hair is left on the wall as the head turns.

**Looked at (2026-10-22, through scratch copies of his set; his folders only read):** 38 s of a Piper
voice drawn on the new stills' 10th (hands folded; the one a writer would call most at ease of the
sheet's 3, 4 and 10), `dist/likeness_v4_preview.mp4`. His resting hands move at most 2 px; his shoulders
up to 13 px, held for 5 to 10 s and shifted over about a second; the wall not at all. The still drawn
through its mesh at rest differs from the still by 0.0043 of full scale (0.0061 before the room's fixes).
The microphone's body stays put; at the largest shift a thin seam shows at its lower right, and its
mount's thin rods move a little with him. The stills step takes about 13 minutes on his set with the
machine loaded (12 stills, 150 frames). **Not yet seen by the user;** At rest has not been asked of a
writer on his sheet (the gate lands made answers).

## The third pass: the whole of them (2026-10-22)

**The user on the second build:** "not a terrible attempt ... it FEELS like we might be onto something
that could become quite decent." What is wrong: NOTHING else moves - "the body doesn't shift at all, the
head doesn't really pivot at all (it just sort of floats around) ... our edits are restricted to general
regions"; the eyes never look around; "the region around the head smears quite a lot ... on the wall,
and on the picture on the wall especially"; every mouth a different color, "blurry flickering
patterns"; the mouth shapes weak - "Is there a simple and effective way we might be able to extract
subtitles from video ...?"; "I also wonder if we might benefit from true learning of some sort. Some
internal neurons, updated via a simple rule, and informed by ALL sets of videos. Maybe even some kind
of ensemble method."; and whether any Gaussian splatting is in it (none).

**Why, each:**
- **The smear:** the only thing between the head and the frame's fixed edge was a ring of mesh, so
  the wall stretched wherever the head went.
- **The float:** the head was moved by where their face's box went in the footage AND turned about the
  neck - two motions for one, and the turn's pivot never seen to bend anything.
- **Nothing else moves:** no mesh over the body, so nothing to move it with.
- **The colors:** each prototype matched to the still by their cheeks' mean only.
- **The stare:** the library held no eye looking aside.

**The plan, in order:**
1. **Layers:** them over THE ROOM - a clean plate of the set made from its footage (each pixel the
   frames where it is not them, each frame's light matched to the still's), the still's own room
   wherever it shows - cut out by a person matte, so the room never moves and what the head uncovers is
   the room.
2. **The body:** a mesh over them from their pose (the shoulders, the neck, the silhouette, inside),
   each vertex weighed between the head and the torso; the TORSO moved by their own body motion from
   the same footage (the shoulders' place and tilt, how near), the HEAD turned on the neck by their
   head's own turn relative to it, and the chest breathing in at the voice's pauses.
3. **The colors:** every library image matched to the still round the lips and the lids (their mean
   and spread in Lab), at build time.
4. **The eyes:** their own eyes looking aside, down and up, in the library; glances drawn from the
   seed.
5. **Their words:** a local speech recognizer (faster-whisper) gives every usable stretch its words
   and times where there are no captions; the visemes are then learned from them.
6. **A model of their mouth, learned from every video:** an ensemble of small networks from the
   voice's phones round a moment to their mouth's shape there, trained on every survey look against
   its transcript.

**Built (2026-10-22):**
- **The room and the matte** (`stills`): each still's matte from MediaPipe's segmentation (COPIED: its
  mask is a view of a buffer the next frame overwrites - every still had kept the last frame's), less
  what stands before them - pixels whose texture matches the still's in 60% of the set's frames (the
  microphone; a color test failed, the wall itself varies 22 levels as the sun moves). The ROOM: the
  still's own where it is not them; behind them the MEDIAN of 90 frames where each pixel was not them,
  each frame's light fitted to the still's (a mean had taken in the globe and ghosts of them), trusted
  where a quarter of the frames saw it; the rest of the 70 px band their motion can uncover filled from
  the room round it only (filled from them, the sweater smeared into the wall). `room_K.jpg`,
  `matte_K.png`. The medium draws the room, then them through the matte: the wall and the picture never
  move (a frame's difference to the first is zero on the room).
- **The body** (`rig`'s `stills`): each still's mesh - its silhouette every 45 px, a band 55 px out, a
  grid inside, the shoulders, elbows, wrists and neck - each vertex weighed to the head (all of it above
  the neck's foot near the head, none at the shoulders) and to the body (on them and near; none out in
  the room). `motion` now holds the shoulders' place, lean and tilt from the same looks, and the head's
  turn relative to them (its roll's sign read from the data: head and shoulders lean together); the
  head only TURNS, on the neck, and the body carries it (`LikenessFace.body_xf`), breathing in at the
  voice's pauses (`LikenessPlan.breath`).
- **The colors:** every library image matched to the still round the lips or the lids (mean and spread
  in Lab, `color_like`); and GLANCES - their eyes looking left, right, up and down in the library, about
  one every 4.5 s, held 0.35-1.2 s (`LikenessPlan.glance`).
- **Their words** (`transcribe`, `hosts/speech/transcribe.py`, the `speech_venv` with faster-whisper and
  Whisper's base English model, MIT, pinned by its sha256): each video without captions, its usable
  steady shots up to the Listen setting's minutes (20), word by word; `words` reads captions or the
  transcript. Measured on his footage: 9x faster than real time on the processor, the words right.
- **Their mouth, learned** (`learn`, `mouth_model.json`): eight networks (the inputs: how much of each
  of 15 sound classes fills each of 9 windows of 60 ms from -240 to +240 ms - shares, so the mouth moves
  smoothly; 32 tanh neurons; their 23 mouth blendshapes), each trained by Adam on its own resample of
  every survey look near their words, their mean the mouth. One video is held out first and the card
  says what it explains there beside each sound's average mouth. The medium reads it as trained
  (`LikenessPlan._inputs`, `_predict`: coarticulation_check holds a made one-neuron network to tanh(1),
  tanh(0.5) and 0), pushes it past their own by Articulation and draws the two library mouths nearest
  it, the nearest whole and the next by how far it is from the third (continuous as the order changes).
  On a made voice whose lips close 120 ms before each closing sound, the ensemble explained 0.88 of the
  mouth on unseen speech, each sound's mean mouth 0.57 (test_actor.py).

**Measured on his footage (through scratch copies; his folders only read):**
- **The room, the matte, the body:** a frame's difference to the first is zero on the wall, the picture
  and the window, and spread over all of him - head, torso, arms, hands; the picture frame's edge beside
  his head stays sharp as the head turns. The medium draws a frame in about 1.1 ms with the body.
- **Transcribe:** six videos (two have no sound, or are handheld throughout), 20 minutes each, 18,229
  words in about 14 minutes of processor; 59,836 phones from them.
- **LEARNING HIS MOUTH FAILED ON THIS FOOTAGE, AND SAYS SO.** His measured mouth scarcely follows the
  sounds: whether a vowel is being said against his jaw correlates 0.02-0.08 per video (at lag 0 - the
  times agree), 0.05-0.12 on the full-size 30 fps track, and no better by the lips' gap, the lips'
  height or the darkness between the lips; at the coarse level only (speaking against pauses) his jaw
  is 0.1-0.4 of its spread higher while he speaks. His beard hides his mouth from MediaPipe, and a
  phone's time is guessed within its word (Whisper times words, about 100 ms late here). The visemes
  learned from the words span 19% of his jaw's range (the range's own 85%): every sound nearly the same
  mouth, drawn it would scarcely move - so `visemes` keeps the range below 40% (`WORDS_SHOW`). The
  ensemble, each video against its own mean, explains 2.5% of his mouth on the held-out video (each
  sound's mean 0.9%, one network -1.1%): the ensemble beats both, but too little to draw from - the
  medium uses it only past 15% and 5 points over each sound's mean (`LikenessPlan.LEARNED_LEAST`), and
  the card says which.
- **What would let it learn:** phone times in his speech, not word times (his transcript spoken by
  Piper, whose phones are exact, and aligned to his sound by DTW over their spectra - no new dependency);
  a measure of his mouth his beard does not hide; or the capture session - a short scripted reading,
  his mouth lit and seen.

## Status of the first build (2026-10-21)

**Built:**
- `src/likeness/` (a row in docs.py's `FOLDERS`, after `proof/`): `Actors` (the library),
  `ActorFolder` (one actor on disk: the plan's `Actor`, renamed - `stage/cast.gd` has an inner
  `Actor`), `ActorSteps` (the steps and the settings, as rows), `ActorBuilder` (the runner),
  `ActorSources` (folders, links, captions), `ActorPrompts` (the agents' words in, their answers out),
  `ActorFeed`, `ActorCard`, `ActorTrack` (reads `ACT1`), `Visemes`, `LikenessFace` (the rig, the
  library, the mesh), `LikenessPlan` (the bed, gestures, the mouth), `LikenessFrames`,
  `LikenessCard`, `LikenessMedium` (`likeness.gd`) and `likeness_warp.gdshader`.
- `hosts/face/actor.py` (survey, shots, sets, track, rig, mouths, visemes, takes, candidates, frames)
  and `hosts/face/test_actor.py`.
- `rules/likeness/audit.yaml`, `gestures.yaml` (with the habits), `director.yaml`.
- The component rows `actor` and `likeness`, the medium row `likeness`, `NoteCards.KEYS`, the reading
  workspace's `hosts`, the `gesture` mark (`Manuscript.GESTURE`, group `gestures`).
- **Phones ride with words:** the Piper host's token path hands back every phone with its time
  (`_last_phones`, moved by every resample, trim and splice the word spans are), `ReadingJoin.phones`,
  `Subtitles.phones`, the export's sidecar `phones`.
- **Gates:** `actors_check`, `coarticulation_check`, `warp_check` (GPU), `likeness_determinism_check`
  (GPU), `hosts/face/test_actor.py`, a Likeness note in `teardown_check`, the likeness prompts in
  `rules_check`, the gesture mark in `script_marks_check`. Probes: `likeness_look_probe` (M4, M5), `likeness_live_probe` (▶ in the real main scene).

**Looked at, on "Why I love writing" (3 minutes tracked):**
- **M4a, the identity:** the frame redrawn through its own mesh came back with a mean difference of
  0 and a worst pixel of 1/255. The layout coordinate rides in the vertex COLOR as a float
  (`warp_check` holds it), so the fallback texture was not needed.
- **M4b and M5:** another stretch's mouth drawn in (one mouth, and three mixed), and a sweep of 240
  frames with his mouth from 40 s later: natural at full size, no seam in the beard, no color break,
  no popping frame to frame. The video has no audio track, so M5 was judged without sound.
- **Measured:** the survey ran at 0.28 of real time (14 min for 51 min); the track at about 2.6x the
  footage (7m50 for 3 min, sharing the CPU with a survey); the mouths in a minute.

**His footage, found while building:**
- **His YouTube videos have no automatic captions** ("no automatic captions", "no subtitles", two
  checked with a current yt-dlp). So no viseme is learned from captions: every class takes its place
  in his own range (`Visemes.REGISTRY`'s `range`), which is what M4b used. A capture session's scripted
  viseme take (Later) is the fix.
- **"Why I love writing" has no audio** (the other seven do).
- **One continuous take can hold a handheld stretch:** "Manuscript Day 45" opens with three minutes
  handheld (him in a hat, walking in) before the camera is set down; "The Irony of Nature Content" is a
  handheld selfie throughout. Hence shots split by camera motion (below).
- **His channel holds 2,040 videos:** a captions-only link lists them in seconds and matches the
  folder's eight by title.

**End to end, through the real `ActorBuilder`** (a command-line driver, every step but the fetch of
a video, on "Manuscript Day 45" with 2 minutes of its set followed): his channel listed (2,040 videos,
the folder's 8 matched by title), the survey (10,789 samples), shots (14, 7 handheld), sets (7), the
**audit agent** (his look in words, as it is: "no glasses, no hat, dark olive knit sweater, swept-back
grey hair and grey beard; seated at a desk beside a large monitor, medium shot from slightly to his
right"), the track (3,600 frames), the rig, 96 mouths, the visemes, 7 takes, and the **gestures agent**
(4 named of 7 candidates - "raise pinched fingers", "raise index finger", "glance aside, open palm",
"open palm to side" - and his habits). The **director agent** placed two marks in a paragraph, and the
text with them removed was byte-identical. That actor is in the library as **"Ephemeral Rift
(2-minute test)"**: a Likeness can play it at once, and Advanced → "Most minutes" and Generate grow it.
**M6** was drawn by `likeness_look_probe --take` over a paragraph Piper read (156 phones in 14.5 s):
the mouth moves with the sounds, closes on the M's and P's, and pops nowhere.

**The user's first test (2026-10-21, evening):**
- **A full Generate over all his footage, in the app:** every step made, eight videos (16:04 to 19:56):
  29 sets, 10 audited, and the default set (set-0e8c1195, 76 usable minutes, 40 followed) built -
  72,000 frames tracked in 80 minutes, 512 mouths, 158 takes, 26 gestures named.
- **"Play this set" read as a preview.** It switched the set in use, and since a set's steps are its
  own, the Likeness card's Generate then began building the other set from its track - which looked
  like the first build being thrown away (it was kept). The button is **Use this set** ("In use" on the
  one used), and each set says whether it is built and roughly how long building it takes.
- **"Why are there two Generate stages?"** The Likeness card had a Generate that ran the Actor card's
  steps for the set in use and then the director. **It has none now:** the Actor card builds; the
  Likeness card says what the set in use still needs, directs, and plays.
- **▶ "did nothing"** on a note with no words: the reading said "Nothing to speak yet." on its status
  line only. The Likeness card now says to write the words first when the note has none, and the
  reading says where to write them.
- **Live playback, seen working** (`likeness_live_probe`, the real main scene and voice on his built
  set through a copy of symlinks): him at his desk, the mouth following Piper's phones. A frame's
  share of the medium measured 2 ms on a quiet stretch and up to 23 ms with the machine loaded, most of
  it the frame's upload - now decoded to RGBA8 on the worker (7.5 ms to 1.5 at least), and not
  uploaded again when a 60 fps show draws the same footage frame twice.
- **The two cards held the main thread 57 ms every quarter second** (the Actor card 38, the Likeness
  card 17), playing or not: `audit.json` parsed for every set question, the 3.9 MB `mouths.json` for
  the library line, every step's every scope worked out again. Now the actor's json files are kept
  while unchanged on disk (`ActorFolder.read_kept`), the library line and the step rows are made again
  only when what they show changed, and the Likeness card asks the actor's state once a tick: 2.5 and
  1.7 ms.
- **Footage moved since a set was built played black, with nothing said:** "Ephemeral Rift (2-minute
  test)" read his videos from Eidolon's folder, which moved to `~/Downloads/Ephemeral Rift` at 16:03.
  A segment with no frames is a failure now (`actor.py frames`), and the stage names the missing video
  (`LikenessFrames.trouble`).
- **A restart made the built set stale** ("Stuff was stale, I had to regenerate"): the videos were
  held in the order they were added (by file name) and `actor.json` was written sorted by id, so read
  back after the restart they came in another order, and the Sets' fingerprint, which listed them as
  held, changed - the sets, the audit and every step of the set were made again, the track too. Now a
  fingerprint takes what a step reads by id (`ActorFolder.inputs_of`) and `actor.json` keeps the order
  (actors_check holds it: an actor read again from its file finds every step as it was).
- **"0 from captions" on Visemes is not a fault:** his videos have no captions (above), so each sound's
  mouth is placed in his own range. The row now says so ("15 sounds, from their own range (no
  captions)"). It also means the gestures were named from their pictures alone.

**Not yet seen working, for the user to test:** an export, and the director on a real chapter.

**How to try it:**
1. On a note, "+" Actor: it brings a Voice, and the note is read by them.
2. On the Actor card, pick "New actor…" and name him. Add folder… the Eidolon `videos/` folder, and
   untick the four other creators' rows.
3. Generate on the Actor card. The first time, ghost rebuilds the face and download environments
   (about 520 MB), then surveys every ticked video (about two hours for his seven), groups the sets,
   has the labeler audit each, learns their mouth's range and their motion from every video (seconds),
   and builds the set in use - its stills, its rig, its library (a few minutes). The Still row then
   shows six pictures of them; a click uses another.
4. Write the words on the Script card; ▶ reads the note with them; ⤓ exports. A set is used with "Use
   this set" on the Actor card; each is built on its own, and one built is kept.
5. To look without the app: `tests/likeness/likeness_look_probe.gd` (its header) draws the identity,
   every sound's mouth, the eyes, and a take frame by frame; `likeness_live_probe` plays the real app
   and bakes a take with its phones.

## What changed from the plan

1. **No new file.** The layout the mouths are kept in is the set's own mean face, aligned, with a
   moderately open mouth (the frames between his 60th and 92nd percentile of `jawOpen`), not
   MediaPipe's canonical UVs: the canonical mouth is closed, and an open mouth's teeth would have been
   squeezed into a sliver. So `canonical_face_model.obj` has no row.
2. **The target face is the chosen mouths' own shapes,** mixed by their weights and set into the
   frame's pose by its steady points; no linear map from blendshapes to points is needed.
   `visemes.json` holds the shapes per class only.
3. **The mouth's key is measured against his own spread** (`actor.py`'s `key_scale`, `KEY_WEIGHT`):
   his blendshapes span a few hundredths (`jawOpen` 0.01 to 0.22) and his head turns over 40°, so a key
   of raw values chose every mouth by the turn alone and every viseme came out the same mouth.
4. **One gain for all three channels** when a mouth is matched to a frame's light
   (`LikenessFace.match_light`): a gain per channel turned a red lip teal.
5. **Shots split where the camera starts or stops moving** (the background's own change, 0.1-0.3 on a
   tripod, 1.5-20 handheld), and a set says it is `handheld`; steady sets come first, and the default
   set is the steady one with the most usable minutes. A jump cut is confirmed at the full frame rate
   (one frame-to-frame jump standing 2.2 times over the next).
6. **A `captions` step:** a folder video matched to a link's entry fetches its captions before its
   words. A video the site has no captions for is made, with none - never a step that blocks.
7. **The hands' exclusion reaches down over the beard** (0.7 of the face's width below the chin): a
   hand at his chin stood in a kept mouth.
8. **The mouth image follows its box** (384 wide; 368 tall for his beard), not 384x192.
9. **Frames are extracted per track segment** (20 s), 30 s ahead of a live show, two at a time, at
   most 40 segments kept; an export extracts in step and waits. The Likeness card extracts the first
   45 s of the plan as soon as the actor can play.
11. **A phone holds the mouth until the next starts:** Piper times P, B and M at 12-24 ms (its own
    frames, without the blanks), under a frame - the closure scarcely showed. And the five frames a
    mouth is averaged over weigh 1, 2, 3, 2, 1.
12. **A download that says nothing for five minutes is stopped and tried again** (an old yt-dlp hung
    at "Downloading webpage" for good), and captions that could not be fetched never stop a video's
    words.
13. **The library on the Actor card is words for now:** the mouths by head turn, how many sounds were
    learned from captions, the gestures by name and count - no thumbnails that play. The Likeness card
    lists the set's gestures as buttons that put a mark at the cursor; the script's palette offers the
    gesture mark itself, not each gesture by name.
14. **"+" grays a component whose card the note's panel would not show** (`Components.host_note`): an
    Actor goes on a note of its own or with a Likeness, never on a show of cards. And the reading builds
    the cards of what its components bring, so "+" Likeness shows the Actor card at once.

**Not built yet:** the disclosure line on a title card (the upload's description says it), the
small deviations (gaze, brows), and the capture session.
10. **The UI and the agents' rules say "the actor" and "they"**: the suite is for anyone, not one
    person.

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

No new file either (see What changed from the plan, 1).

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
- the chosen set.

**No consent rule in the app** (removed 2026-10-22, the user: "trivial to circumvent, so not worth
keeping ... That is what the legal system and platform terms of service are for"): an upload neither asks
for a license on file nor refuses one; "Consent and disclosure" below is the advice it was built from.

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
   audit), whether it is built, and the one in use ("Use this set").
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

### The Actor puts them on the stage (component `actor`, medium `likeness`)

**One component since 2026-10-22.** It had been two: an Actor that built and a Likeness that played. The
Likeness card lost its Generate (the user's first test: "why there are two Generate stages"), then its
Performance (2026-10-22: "Do we really need this card with just one option?"), and was left a bare title
bar. The user took it off with its × "because it was doing no work, except for existing" - and the
video went with it. Then: "If we're doing all that pipeline work with Actor... then the implication is
we want to use that actor in the scene." So the Actor card does what the Likeness card did:
- **It pins the medium** while it is up (`Director.medium_override = "likeness"`, as Proof pins the
  desk), and lets it go when it leaves.
- **It hands the reading how it goes out** (`ActorCard.Publish`): an export waits for the set in use to
  be built (saying what it still needs), the render's document carries `likeness` - the actor's folder,
  the set, its still, the seed (`ActorCard.document`) - and an upload says whose likeness it is.
- **The performance is the note's:** the seed of which pieces of their motion play, when they blink and
  glance and when their posture shifts is drawn from the note's own file (`ActorCard.performance`), so
  a note always plays the same way and an export is what was watched.
- **The intro and outro fade them** (2026-10-22, the user: "The fade-in/fade-out from the 'intro &
  outro' component does not appear to work here"). Measured live with 9 s holds: they rose from black
  in the intro's first second and sat lit through the other eight. Now they rise across the whole intro
  (`ShowFeed.lead` - the take's own lead-in in a render, else the note's intro hold), arriving as the
  first word is said, as every picture does (`Director._bookend_fade`). They go down a beat after the
  last word and are black as the outro runs out (`ShowOpening.end_fade`, the desk's and the table's).
- **Gone:** `LikenessCard`, the `likeness` component and block (an older note's `likeness:` block is
  carried untouched and means nothing), `ActorFeed` and the reading's `feed()` (only the two cards used
  them). An Actor no longer stands alone on a note to build without playing: it takes the
  presentation, so it cannot share a note with a Picture, Cards or Proof.

**The medium** is a row in `Medium.REGISTRY` (`res://src/likeness/likeness.gd`, frames
`["landscape"]`, needs `reading`). It renders, as a pure function of show time (see Rendering).

**The component's row** (`src/notes/components.gd`): **`actor`** - family `picture`; needs `reading`;
provides `picture`; requires `voice`; slot `presentation`; capabilities `forward_plus`, `subprocess`,
`ffmpeg`, `python:face`, `python:speech`, `python:download`, `agent:writer`; block `actor` (its `id`
and who labels); script `res://src/likeness/actor_card.gd`. "+" Actor brings a Voice, as Cards brings
one. The reading workspace's `hosts` holds `actor`.

## The actor's folder

```
user://actors/<id>/
  actor.json                 name, sources, ticks, chosen set
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
(`TableProducer`): the rules are in `rules/likeness/*.yaml`, and the reply is JSON, parsed and
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
- **M8 - The proof.** 2-3 minutes of a chapter: Generate on the Actor card, Direct, then the export.
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
