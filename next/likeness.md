# Likeness: an actor, played from his own frames

Two builds: the first (a retrieval-based player) and the second build, "a still and a model", which holds
where the two differ (below). The passes after the second build (the fourth to the tenth) are the head's and
the body's refinements, newest first below the voice section. The first build's files are backed up in
`dist/likeness_v1/` (never committed).

## A voice alone: the Voice training card

A voice alone's Utterances and Voice are Kokoro's own steps (`kokoro_utterances`, `kokoro_voice`;
`ActorSteps.of_kind`; an actor's voice is still Piper's): its sentences heard again alone and cut to the
words their sound says, Kokoro's decoder taught their sound, its delivery kept (next/voice_engines.md,
"Training Kokoro"). The Piper account below is how the card began.

The card fine-tunes a new voice for a note's Voice component. Sources: a video file, a YouTube URL or a
playlist URL.

### What can be trained here (looked at 2026-10-26)

- **Piper: built, and measured** ("Their own voice", the fifth pass's "The voice is every way he sounds").
  John (public domain) fine-tuned on their sentences, an hour on the 5060 Ti. Their tone arrives by epoch 30
  (the spectrum as near their held-out speech as their own other sentences are). Clarity does not: one
  voice of his, 93 minutes, is misheard 15.9% of words, where his own audio is 5.6% and John 7.5%. Untried:
  taught in John's own labels ("en").
- **Kokoro: no training code of its own** (hexgrad: not feasible without the style encoders and
  discriminators it did not release). Three routes outside it:
  - [kikiri-tts](https://github.com/semidark/kikiri-tts) (Apache-2.0): a whole fine-tune through a patched
    StyleTTS 2 trainer (stage 1 the decoder again, adversarially, with a fresh style encoder and fresh
    discriminators; stage 2 durations, F0 and energy). Made for a new language (German, about 51 hours for
    its base), "10 GB+" of the graphics card's memory where about 8 is free beside Praxis. Not a recipe for
    one English speaker on the official weights.
  - [kokoro-inno-clone-tuner](https://huggingface.co/remsky/kokoro-inno-clone-tuner) (code Apache-2.0, its
    speaker encoder CC BY-SA 3.0): one 3 to 30 s clip to a native voicepack ([510, 1, 256]), Kokoro frozen.
    Its own numbers: speaker similarity 0.288 on LibriSpeech test-clean (shallow), UTMOS 4.45. One clip,
    where we have hours.
  - **Our own style fit** (next/voice_engines.md, "Fine-tuning"): Kokoro frozen, the 256 numbers fitted to
    all of their sentences by gradient. Little memory and minutes; keeps Kokoro's clarity; how much of them
    it reaches is the question. Not built.
- The card trained Piper first, the trainer that ran; Kokoro followed by a loop of our own.

### Built

- **The Voice training component** (`voice_training`, family Voice; it brings a Voice, as the Actor does;
  shown on a reading's, a table's and a proof's panel; `python:voice_train` among its capabilities, so where
  PyTorch has no CUDA build, "+" leaves it out). Its card (`VoiceTrainingCard`): whose voice (a picker, "New
  voice…"), their name, their recordings (a folder, files, links), the five steps, Generate, Stop, **Read
  in it**, and the Voice lessons. Made, the voice is "<name> (their own voice)" on every Voice card, and the
  note reads in it as it lands (`ReadingPanel.voice_made`, as the Actor card's does).
- **A voice alone is a person of the Actors library** (`actor.json`'s `kind` "voice"; `ActorFolder.sound_only`),
  listed apart from the actors (`Actors.list(kind)`): the same folder, fingerprints, staleness and runner as
  an actor, but made of the voice and what it reads alone: Fetch, Probe, Hear, Utterances, Voice
  (`ActorSteps.voice_chain`), whatever a run asks (`ActorBuilder.tick`). Kept apart so its links can be
  fetched as their sound (`ActorSources.SOUND_FORMAT`: the best AAC, no picture, no captions; a 19 s video
  is 302 KiB); an actor's folder listing one would have had its video fetched again later, and everything
  heard from it made stale.
- **Its folders list sound files beside videos** (`ActorFolder.SOUND_EXTS`: m4a, mp3, wav, flac, ogg, opus,
  aac), and a file can be picked by itself on both cards (a source of kind "file",
  `ActorSources.add_file`).
- **The two cards share their parts:** the sources and videos (`ActorSourceList`) and the steps' rows,
  worked out on a worker (`ActorStepRows`).

### Verified

- `tests/likeness/voice_training_check.gd`: listed apart (two-sided), a folder's sound files and a file
  picked by itself, the fetch's arguments (the control: an actor's take the picture and captions), the sound
  file a fetch leaves (never its `.part`), Generate making each recording's probe and Hear, the Utterances,
  the Voice and nothing else, and a run asking for every step no more (the control: an actor's makes the
  survey); with the restriction taken out of the runner the gate fails. Read in it waits for the voice, then
  hands the reading its id; so does a voice landing. actor_upload_check, actors_check and components_check
  pass on the shared parts.
- By hand, outside the app: the card's own yt-dlp arguments fetched a 19 s video's sound; ffprobe found no
  picture and 19.06 s; Hear heard it whole (35 words).
- Not yet run end to end in the app: a playlist fetched, heard, cut and taught from the card.

### To try

On a note with a Voice: "+" -> Voice training -> New voice… (their name) -> Add link… (a playlist of them
talking) or Add folder… / Add files… -> untick what is not them -> Generate. Hear takes about a seventh of
the recordings' length on the processor, the Voice an hour or so on the graphics card (Voice lessons,
6,000); Stop keeps what is learned. Half an hour or more of their ordinary speaking voice is plenty;
Utterances keeps one voice of them and says what it left out.

## The tenth pass: the beard moves as one, the hands at rest are seen (2026-10-25, later)

Symptoms: spikes where there is a lot of movement (the beard projecting beyond other features), a resting
pose of open palms, face-up, and everything stretching.

### Measured (`dist/tenth/`)

- The fracture (`fracture.py`: consecutive frames, the later warped back by the smooth flow between them) of
  the beard went from 0.25 to 0.48 once it rode the head. Cause (`levers.py`): a beard splat parted from its
  neighbours by 0.435 px a step, 45% of its own move; its expression shifts alone parted it by 0.286 (hair has
  no shape that shifts with the face), its triangle alone 0.220. Hung from the head below the chin and with
  no shifts under the lips: 0.124.
- The motion is not past theirs (the head moved against the body in 55 of 359 frame pairs, by 1.9 px; their
  own footage: 272, by 3.9). What stretches is the body bent in 2D under a head that moves.

### Fixed

- **THE BEARD MOVES AS ONE** (`fit.hang_beard`, Fit version 6): below the chin a splat on the face's
  triangles is hung from the head's own frame where it stood, as the hair is; under the lips' outline it
  keeps its triangle (the jaw carries it) and takes no expression shifts. Gate: test_fit
  (`the_beard_moves_as_one`).
- **THEIR HANDS, CLOSER** (`actor.hands_sheet`, Stills version 5; `rules/likeness/rest.yaml`): a second
  sheet, each still cropped round its pose's hand landmarks, numbered alike, goes to the At rest writer with
  the first. Gate: test_actor (`test_hands_sheet`).
- **A still with nothing before them** (the outline rule leaving none): the specs take each still's layers
  from `stills.json` (`ActorBuilder.still_layers`), the trainer none for no front. Gate: actors_check.

## The ninth pass: a head that turns, a beard that stays on it (2026-10-25, late night)

Symptom: the actor does not feel truly 3D; edges morph and warp, worst at the neck and the beard.

### Measured (`dist/third_d/`, `dist/ceiling/`)

- The head is 3D; it was not played as one: a head turned in the trainer by 6 to 18 degrees of yaw holds as a
  head, but the plan played their head at `CALM` 0.6 of their own, eased under `MOST` 5, 4 and 3 degrees
  (sizes for a still bent by the motion). The head moved against the body in 38 of 359 frame pairs, by 1.6
  px; in his own footage, in 272, by 3.9.
- The beard's lower half followed the torso (0.93 of its motion): the neck stretch gave every head splat a
  quarter face below the chin the torso's move (34,861 of the set's), and no step that learned them ever drew
  them so; played, a translucent veil hung from the beard over the collar as the head moved.
- What stood before them was his sweater: `front_K.png` held five pieces of the dark knit and missed the
  microphone. A piece's rim that is a strong edge in the still: the microphone 0.10 to 0.45, the shirt's and
  the sweater's pieces 0.00 to 0.06.
- The ceiling (`ceiling.py`: the head frozen, each moment's codes, then its pose and points too, fitted to the
  picture): on unseen moments 24.5 dB tracked, 23.3 played, 25.6 with everything, and on moments it learned
  from only 1.2 dB more. The head is the limit, and it underfits. Three videos or ten score alike; the three
  hold twice the fine detail.

### Fixed

- **A HEAD OF SPLATS TURNS AS THEY DO** (`LikenessPlan.size_for`, `SPLAT_CALM` 1, `SPLAT_MOST` 12, 9 and 6
  degrees; their own 95th percentile is 6, 5 and 3); the 2D renderer keeps its calm.
- **THE HEAD RIDES THE HEAD** (`train.second_of`): no head splat takes the torso's move; the shader's second
  influence is a body splat's alone. Gates: test_fit (`the_head_rides_the_head`), splat_head_check (a head
  splat written a share draws as with none).
- **A THING BEFORE THEM HAS AN OUTLINE OF ITS OWN** (`actor.outlined`, OUTLINE_EDGE, OUTLINE_SHARE): a piece
  is kept only where 8% of its rim is a strong edge. Gate: test_actor (`test_front_outlined`).

### What is made again

Stills (version 4) and everything after it for each set: At rest, Rig, Frames, Face rig, Avatar, Fit
(version 5).

### Open

- **The t-shirt set's neck**: its bare neck's skin rides the head now, and specks (black shirt splats unseen
  in the still, uncovered as it turns) may show again. Telling skin that stretches from hair that hangs needs
  the moments' say, but his tracked torso jumps 20 px every half second, too loose to learn against.
- **The jaw scarcely moves** (0.3 px a frame under the lips against 2.1 in his footage): MediaPipe sees no
  chin under his beard, so the rig learned a jaw that barely drops; driven by the lips' parting it could.
- **The head underfits** (the ceiling): first a head of one session trained far longer, to see whether its
  own frames climb past 26 dB (the budget) or not (the representation).
- **The body is the still bent in 2D** by its bones, by design.
- A picture frame's edge on the wall by his head is a front piece in three of one set's stills (outlined, so
  kept).

## Three alike videos, and is the approach convoluted? (2026-10-25, late)

The question: reduce to three very similar videos, or replace the body-part rigging with full-frame splats.

### The set played had no lookalike

The set played was the one video of the 68 against a black backdrop in a dark room; nearly all the others
are the office (the green wall, the window's light, most in the same knit sweater). The head of 10 videos had
learned the office's daylight and was stretched over the dark room (`dist/sweep/all_videos.jpg`).

### The three (`dist/sweep/`)

By each video's median face light, chest colour, wall colour and the face's place and size in the picture
(and by eye: `closest.jpg`): "Sobriety & Personal Evolution" (f-f0686b23ff, 77 usable minutes), "Manuscript
Day 131" (f-ea1b92e172, 56) and "Evolution is neat!" (f-791f8b0499, 52): the same sweater, long beard and
combed hair, the same room, light, camera distance and framing. The set played is Manuscript Day 131's
(set-8ed7fcfe: one continuous 56-minute shot).

**THE HEAD PINNED, not the videos unticked:** unticking 65 videos would make the audit, the sets, the
visemes, the motion, the utterances and the voice stale. A video pinned "head" on the card
(`ActorFolder.pinned`, `head_videos`) is what the head learns from, the pinned alone, every ticked video
still read for everything else; the Head's fingerprint names the pins. Generate makes again the Head (3
videos x Head steps, about 20 minutes) and the new set's steps; the voice and the rest stay. Gate:
actors_check (one pinned, it alone; unpinned, as it was).

### What the literature says (a third survey)

- **No published paradigm clearly beats this one under these constraints:** splats bound to a mesh with a
  small linear basis per splat is where real-time head avatars have ended up (GaussianAvatars, 3D Gaussian
  Blendshapes, RGBAvatar, Gaussian Eigen Models). What is convoluted here is the averaging (one head of many
  sessions, then the set's bake, then one still's fit) and the rules patching over it.
- **Full-frame splats over time** (4DGS, Deformable 3DGS) only replay the timestamps filmed; re-driving them
  means inventing a control space, and a fixed camera is their worst case (DyCheck).
- **"The most distinct poses, embedded"** belongs in the driving, not the renderer: a motion graph over
  their own tracked code trajectories (Video Textures, Video Rewrite, Fried 2019): retrieval of their own
  mouth snippets by phoneme context, transitions by interpolation of codes, nothing new at playback.
- **The data regime of the closest family** (talking portraits: ER-NeRF, TalkingGaussian, SyncTalk): one
  session, 3-6 minutes, a 512 px crop, 32 to 36 dB, but scored with the test video's own pose and blinks,
  often face-only or pasted into the real frame. Pooled sessions help when each is short (PAV) and only when
  their differences have somewhere to go; one of his sessions is some 15 times what those papers train on.
- **The ceiling, measured apart from the driving:** freeze the model and fit each held-out frame's
  expression codes photometrically. Near what it scores on frames it learned (27 dB on one video), the drive
  is what loses; near 23, the representation (fine detail sliding on MediaPipe's coarse mesh), then
  photometric tracking.
- **Ranked:** keep the paradigm and cut the averaging (the ceiling test first; each session's own model;
  20-50 learned components in place of 12 PCA ones, GEM gained 2.4 dB from 10 to 30; the mouth's inside
  learned at the shapes played); then a motion graph and phoneme-context retrieval for behaviour; not
  retrieval of real pixels (the first build) nor 4DGS.

## The eighth pass: the soft mouth and the neck, from the literature (2026-10-25, night)

Symptoms: the mouth soft, and a few dark specks at the neck's sides as the head turns.

**Read first** (two surveys): the mouth wants per-frame refinement of the drive, teeth of their own
(GaussianAvatars' teeth triangles on the skull and the jaw, GaussianBlendshapes' mouth splats on two teeth
billboards with no expression shifts, GeoAvatar's part-wise mouth +1.5 dB; a fan of triangles "naively
connecting lip vertices" blurs and sticks the teeth together) and mouth-weighted losses. The neck: no paper
lets two separately rigged layers both cover it; full-body avatars blend their skinning across it,
talking-head methods give it one owner, the torso.

### Measured before anything was changed (`dist/mouth/`)

- The head is soft everywhere, not at the mouth alone: the avatar keeps 12 to 20% of the frame's fine detail
  at the brow, cheek, nose and lips alike (about 23 dB even on frames it learned from); Fit sharpens all of
  it from the still but where the face opens, so the mouth and the beard under it stood out.
- Not the tracking (each frame's pose and points freed to fit the avatar moved 0.3 px at the median, gaining
  0.1 to 0.2 dB). The drive is where the mouth is.
- The teeth are yellow streaks, painted on the fan of triangles from the inner lips to a point behind them,
  which moves with the lips, where teeth move with the skull (upper) and the jaw (lower).
- The neck's specks, drawn as Godot draws, are the black shirt's splats the head's splats below the chin had
  hidden, uncovered as those slid away with the head.

### Tried and dropped

The neck's skin held to the still as the head turns (specks 322 to 23, but it ate the bottom of the beard);
recolouring what no picture shows or what hides under the neck's skin; fitting the whole mouth to the still
(the still's closed lips showed in the openings again).

### THE NECK STRETCHES (fixed)

Each head splat below the chin takes the torso's move from where it stood in the still, more and more to a
quarter of the face's height below it (`train.second_of`, `NECK`): the neck stretches between the head and
the body. The shader takes it as it takes the body's second influences, the head splat's place in the still
from the still's frames (`SplatHead.hold_still`). In the still's order, the speck pixels over the four turns
went from 179 to none. Gates: splat_head_check (the shader against the rules, and its control), test_fit
(`the_neck_stretches`). (The ninth pass narrows this to the neck: no head splat takes the torso's move.)

### THE BEARD UNDER THE LIPS IS FITTED (fixed)

Held to the moments, Fit no longer holds the beard below the lips: only the lips' outline, fading out over
0.02 of the face's height. Played: 47% of the still's detail in the mouth's box, from 40, the openings as
clean.

### THE MOUTH IS THE SET'S TOO (fixed, in part)

The bake pulls the mouth's splats (on the lips', the corners' and the inside's triangles, `bake.mouth_of`)
no harder than the hair's, and lets them grow: a head learned from 3 videos then draws the set's open mouths
with 22% of their fine detail where the real head drew 14%, and played with the lips-only Fit, 49% of the
still's detail in the mouth's box (from 40%). Still soft.

### Teeth of their own, and the mouth's inside its own (tried on scratch heads; not shipped)

Four heads of the same 3 videos and 12,000 steps (`dist/mouth/teeth/`), scored on the set's 12 most open
mouths: A as it is (24.99 dB, 28% of the fine detail); B with teeth (upper on the head's frame, lower on a
jaw's triangle, no expression shifts; 24.89, 28%); C, B with the mouth weighed 10x (22.98, 45%, speckled
jagged teeth); D, B with the face's own splats' cover inside the open inner lips pulled to none (25.50, 33%).
The opening is painted by the lips (their splats, centred on the lips and reaching in, paint the teeth, which
then move with the lips and smear); teeth alone change nothing. D draws the teeth as teeth on the mouths it
learned from, but played it tears: the played mouths are their tracked mouths pushed by Articulation, wider
than any it learned, and the fan that paints the inside stretches into a dark gash. Not shipped; the next
step is the inside learned at the played shapes, or a push the inside follows.

### Found, not fixed: what stands before them is his shirt

`front_1.png` (what stands before them, drawn over the splats and never moving) holds his whole upper body
and not the microphone: by colour alone, a black shirt on a dark wall is the still's in every frame. It holds
his chest still and cuts the beard with a hard edge as the head turns past it. `actor.py`'s `still_room` /
FRONT_SEEN, STILL_SHARE. (The ninth pass's outline rule addresses it.)

### What is made again

Each set's Avatar (version 6: the mouth the set's own) and Fit (4), about 10 minutes; the neck's stretch is
written by Fit and drawn by the player. Drawn by Godot over the take: `dist/mouth/seventh_vs_eighth.mp4`.
To judge: the neck as the head turns, the beard under the lips, the mouth.

## The seventh pass: the needles (2026-10-25, evening)

Symptom: needle-like fractures throughout the scene, especially near the face when it moves, and a blurry
mouth. Looked at (`dist/needles/`): a set drawn by Godot over the 12 s take, and the frames the medium wrote
for the splats at six moments of it, drawn again by the trainer.

### Godot and the trainer agree

Drawn by the trainer from the very frames Godot wrote, the needles are the same ones (a dark line from the
mouth's corner across the cheek, needles through the beard, green and purple specks on the neck, the beard's
edges in streaks); the avatar before Fit had none of them.

### Fitted to one picture, the head came apart as it moved (found and fixed)

Fit fitted the head's splats to the still alone: any layers that add up to that one picture would do (41.4 dB
on it, but 19.9 on the set's moments it never fitted, where the avatar it started from held 21.75). Now the
moments keep it whole (`fit.moment_loss`): each step one of the set's own moments is drawn too, as tracked
and in its own light, and asks the head for its picture in squares 4 pixels wide, so what moves with the face
holds together and the fine detail is the still's alone. 38.0 dB on the still, 21.4 on the moments it never
fitted.

### The mouth folded the face (found and fixed)

- **Turned past the head's own turn, a triangle by the mouth's corner went 91 to 96 degrees**, and cheek
  triangles beside the nose some 35. The face's own ways turned no triangle more than 4 degrees, the blink
  the lids' 34, each sound's mouth up to 121.
- **Why:** each sound's own mouth is the median of their tracked points, and Articulation pushes all of it
  three times. Their own mouths turn a triangle at most 27 degrees; pushed, the mouth's corners crossed over
  themselves (P B M 118 degrees, F V 85, "open" 62) and the splats bound there swung edge-on.
- **A sound's mouth never folds the face** (`LikenessMedium.unfolded`, `FOLD_MOST` 40 degrees): pushed no
  further than turns any triangle past it. On his set "open" is pushed 1.85 (the lips parted 0.105 of the
  face's height, their own 95th percentile 0.11), P B M 1.25 and F V 1.7, the rest 2.6 to 3.

Drawn by Godot (`dist/needles/now_vs_seventh_pass.mp4`): the line across the cheek, the needles through the
beard and the specks on the neck are gone; the beard's edges whole through a blink and as the mouth closes on
P B M. A few dark specks remain at the neck's sides (below the chin the head's splats and the body's meet and
slide as the head turns). The still is 38 dB where it was 41.4.

### What is made again

Each set's Fit (version 4), about 5 minutes. The cap on the mouths is the player's own. To judge: the beard's
edges and the cheeks as the mouth opens and closes, and the neck as the head turns.

Open: the mouth is the head's, as soft as every video's mouths averaged; Fit holds it as the moments taught
it, since fitted to the still it took the still's closed lips into every opening.

## The sixth pass: the mouth, the flicker and the edges

Symptoms on the head of splats: the mouth shape barely moves; the face's shape and color flicker into
something else after several stable seconds; heavy artifacting at the neck (black splotches, hard lines) and
blurred ears. Looked at (`dist/fifth_look/`): a set drawn by the medium over a 24 s take
(`likeness_look_probe --take`), and what the player hands the splats each frame.

### The flicker is the glances (found and fixed)

- **Nothing else moves the face in steps:** the face's own ways move 0.01 a frame, the motion pieces blend
  over 0.8 s. A glance (about one every 4.5 s, turned to in 60 ms, held 0.35 to 1.2 s) moved the expression's
  components by up to 3.4 of their spreads, and a blink 1.1. Drawn, a glance re-made the face (the cheek
  widened, its light went blotchy, the beard's edge moved).
- **Why:** both things that move the face mixed its parts. The splats' expression was the 52 scores'
  principal components over every score at once, and its shifts learned whatever went with a score in his
  footage (a glance aside came with his head turned to a lit screen); the rig's basis was fitted over every
  score, so the eyes' scores moved the points below the nose 0.97 as far as their most.
- **The face has parts** (`hosts/avatar/parts.py`): the eyes, the brows and the mouth, each its scores, its
  anchors (MediaPipe's points: the eyes' rims and irises; the brows; the lips and the jaw's edge round the
  chin) and a reach in the face's heights (0.12, 0.15, 0.3). The rig's basis moves a point by the scores of
  the parts that reach it alone (`rig.by_parts`; a point no part reaches moves with none), and the expression
  has components of each part's scores alone (4, 2 and 6: `train.components`), a splat taking a part's
  shifts only as far as the part reaches its triangle (`train.reach_of`; the export writes each shift so,
  and the shader is unchanged). The basis explains 40% of the face's movement (the lips 62%), what it gave
  up being what the other parts' scores explained by going with them.

### The mouth scarcely moved (found and fixed)

- **Played, his lips parted 0.044 to 0.062 of his face's height while he spoke; his own, tracked over all his
  frames, 0.013 to 0.11** (1st to 95th percentiles; 0.145 at the 99th). Each sound's mouth was its scores
  set one at a time and pushed from the still's own (lips parted 0.035), so most consonants closed the mouth
  and "open" at its most parted the lips 0.064. His wide mouths reach 0.11 to 0.145 with an ordinary jaw
  score: the beard throws MediaPipe's jaw off.
- **Each sound's mouth is their own** (the Face rig's `mouths`, `rig.mouths_of`): the frames of every video
  whose mouth's scores are nearest the sound's (a percent of them), their points' median less the rest's
  (only where the mouth reaches), their mouth's scores' median less the rest's, and how far their lips part
  (1st and 99th percentiles). The player moves the still's face, its mouth at rest, by them, pushed by
  Articulation and never past their own parting (`LikenessMedium.own_mouths`). Silence is their mouth at
  rest. Simulated over the take at Articulation 3: 0.037 to 0.114 while speaking. The mouth opens on the
  vowels, its inside dark and the teeth showing, and closes on P B M.

### The edges are the head's (found; fixed in part)

- **The neck:** in the still the neck shows between the beard and the collar; drawn, it was dark with a hard
  curved edge and a ring of skin. The bake drops the head's splats below the chin and lays the set's own
  there from its 146 moments, and Fit fitted only the body.
- **The hair and ears:** the head is every video's, adapted to the set's moments: soft, the ears a smear.
- **Fitted to the still whole** (a scratch Fit, the head's splats too): 23.3 dB on the whole still became
  43.7, the hair in strands, the beard sharp, the neck the still's skin down to the collar, but where the
  face opens it broke: the shut lids showed the still's open eye as colored specks, and the parted mouth the
  still's closed lips as specks and streaks. What shows in the opening is whatever stands there, bound to
  anything.
- **Fit fits the head too, but not where the face opens** (`fit.where_it_opens`): a head splat is held by
  where it stands in the still: within the lips' sweep (their outline and itself 0.15 of the face's height
  lower) or an eye's rim, wholly, fitted more and more past them (wholly at 0.06 and 0.04 of the face's
  height). 41.5 dB on the whole still (from 23.3), the hair in strands, the ears and beard sharp, the neck the
  still's skin down to the collar with no edge; the parted mouth and the shut lids clean.

### All of it at once, on a scratch head

A head learned with the parts (`dist/fifth_look/parts_run/`: three Head videos, 2,000 steps each, a tenth of
a real Head), the set baked from it (21.69 dB on the moments it never fitted), Fit (39.7 dB on the whole
still) and 12 s drawn with their own mouths: through a glance the lids lower and nothing else changes.
`dist/fifth_look/now_vs_sixth_pass.mp4`.

### What is made again

Generate makes again, in order: the Head rig (seconds), Head (about 1.7 hours), and each set's Face rig
(seconds), Avatar (4 minutes) and Fit (4). Until its Face rig is made again a set refuses to play on the
splats ("from before their own mouths"). To judge: the mouth at Articulation 3 (2 if it opens too far), a
glance, the neck and the hair. Not looked at: a set with glasses (the head never draws them), and a still
with the lips apart (silence is their mouth at rest, not the still's).

Symptoms on the head and the voice trained on all 65 videos: the face moves at exactly the moment every
phoneme changes and is still when the actor is silent; heavy black dots speckled in the beard; a muddy,
inconsistent voice.

### The face moves only at the phones (found and fixed)

Every frame is drawn (`LikenessMedium.draw_at` poses the splats each frame); what was stepped was what the
plan handed them.

- **The two strongest, made for two pictures, were played on the splats.** `Visemes.strongest` mixes at most
  two sounds, right for the 2D renderer, which draws two library pictures. On a head of splats it held each
  sound's whole shape and gave way to the next in some 15 ms: a jump inside one frame. On a real passage (218
  phones, 24 s, 30 frames a second) the mouth's scores travelled twice as far as Cohen and Massaro's weighted
  mean of every pull, and moved by as much as 0.69 of a score from one frame to the next (the mean of every
  pull: 0.26; smoothed by 20-25 ms: 0.21). **Now** a head of splats mixes every pull, averaged over a Gaussian
  of 20 ms (`Visemes.mix`, `LikenessPlan.mouth_mix`), and the lips still close at M (0.85 of the mouth in a
  fast "AA M AA"); coarticulation_check holds it frame by frame, the two strongest its control. The 2D
  renderer is unchanged.
- **No sound is pushed past their own 99th percentile of each score** (`visemes.json`'s `range`;
  `LikenessMedium.TOP`): at Articulation 3, "open" asked jawOpen 0.67 and the lips' close 0.42, where the
  head's 99th percentile of its 17,192 moments is 0.49 and 0.25, and the splats bound to the mesh stretched
  with it.
- **Silent, the face still moves.** From every video's survey (five looks a second) and the words heard:
  their brows, lids and cheeks move 0.74 to 0.82 as much in silence as while speaking, and their mouth 0.74.
  Some of it is MediaPipe's jitter: the slow part goes on from one look to the next (lag-0.2 s correlation
  0.43 to 0.58 for brows, squint and smile; 0.24 to 0.31 for the mouth's quick components). The Motion step
  learns their face's own motion at the head's looks (`actor.py`: `face_names`, every score but the blinks,
  the gaze and the lips' opening and protrusion, which the plan plays itself and a beard misreads;
  high-passed as the head's, smoothed over 0.4 s, `face_components`: on his footage six ways: two of the
  brows, a smile, a squint, a stretch of the mouth's corner, the brows one against the other); the plan
  reads them from the same piece as the head (`LikenessPlan.face`), at its calm, and the splats mix them
  (`LikenessMedium._take_face_ways`). The Motion step's version is 4 (36 s on 65 videos).

### The black dots are the bake's growth (found and fixed)

Not the player (`dist/dots_audit/`): the trainer's own render of `fit` at the still has them (309 speck
pixels the photo lacks), and drawn in the exported order or sorted by depth no pixel differs by more than
0.3. They move "in 3D" because they are bound to the head's and the face's frames.

What they are: splats under half a pixel (median 0.24 px), wholly opaque, dark (luminance 0.085), on the
drawn surface. 90 make half of the specks, 359 four fifths. The shared head held 1 such splat; the set's
bake 13,087, and Fit kept 10,006. The bake grew the head freely (55k splats to 346k on 146 moments, copying
splats already under a pixel) and over-fitted their darkest detail in a few moments (some show glasses, a
globe, bottles, a keyboard before his face). Baked without growth: no specks at all and 21.54 dB on unseen
moments against 21.57: the growth bought nothing, only softness lost on the still.

Now (`bake.py`): the head grows to at most three times its own (`HEAD_GROWTH`), never copies a splat already
under a pixel (`LEAST_COPY`; `train.Splats.densify`'s `least`), and before it is baked a head splat under a
pixel darker than 60% of the face drawn round it in most of eight moments is dropped (`specks`; relative, so
dark hair keeps its own). On his set (`dist/bake_test/`, 6.6 minutes): 4,774 specks dropped, a head of 139k;
11 speck pixels at the still against 216, 47 on each unseen moment against 279, and the face 21.85 dB at the
still (21.57) and 21.67 on unseen moments (21.57). The room's frames are counted one at a time
(`train.room_of`): summed whole, the masks of 146 frames were 2.3 GB of 64-bit integers.

Left: a few faint specks in the beard. The moments with glasses or something held before the face are still
learned from (the head draws them worst), but left out at a quarter of the steps the set came out no better
(21.50 dB against 21.67, 85 speck pixels against 47), so they stay.

### The voice is every way he sounds (found and fixed)

Measured (`dist/voice_audit/`): 40 held-out sentences from 27 videos, none of their text taught, none from a
video the old voices were taught on, said through the voice host's own path and heard by Whisper (base.en);
the pitch from sentence to sentence; the long-term spectrum against his clean held-out speech.

| voice | taught on | word errors | sentence pitch spread (Hz) | spectrum off (dB) |
|---|---|---|---|---|
| him (his own audio) | | 5.6% | 38 | 0 |
| John, the base | | 7.5% | 15 | 5.3 |
| the dev run at epoch 120 | 46 min, 2 spoken videos | 14.4% | 12 | 0.9 |
| the first run in the app | 637-915 sentences | 17.4% | 23 | 1.4 |
| **all 65 videos, 30 epochs** | 480 min, 58 videos | **33.6%** | 17 | 1.6 |
| **one voice of them (the proof)** | 93 min, 19 videos, ~4.9k batches of 8 | **15.9%** | **9** | 1.2 |

Why: of the 480 minutes, 220 were noisy (outdoors, wind, water, two over a music bed), 32 soft and low, 38
high, 44 breathy, and 146 his ordinary voice. A voice of one speaker averages them and draws among them
sentence by sentence. Four videos were there twice ("(1080p)" and "(1080p, h264)" in merged download
folders), so 48 of the 287 held-out sentences were also taught. Ruled out: the trainer's settings, clipping,
too few batches, the transcripts (a second hearing, small.en, on 454 sentences: a median 3.9% of words
differ).

Now: the Utterances step keeps one voice (`utterances.signature` measures each sentence as it is cut,
`choose` keeps them together: its speech 30 dB over its own pauses; 8 to 30 characters a second of loud
sound; its pitch within 1.3 times their usual one; a harmonics-to-noise ratio of 3.6 dB or more; its video's
mean spectrum within 2 dB of the most typical video's; each sentence once) and says the minutes left out for
each reason; a copy is not another video (`ActorFolder.copy_of`: a video of the same title and length as an
earlier one is left out of every step, the card marking it ⧉); and the Voice is taught in lessons, each a
batch of 16 (`voice_steps`, 6,000, under an hour). On his 68 videos (`dist/utt_test/`, 21 minutes): of the
499 minutes cut, 1,087 sentences and 45 held out, 88 minutes from 12 videos, his register 124 Hz; left out,
in minutes: noisy 226, another register 72, breathy 46, another recording 46, said twice 18, not paced as
speech 3. Untried: John's own labels ("en") in place of "en-us".

### The head is soft: too little of each video, and nothing settles (found; fixed in part)

Measured (`dist/blur_audit/`; sharpness is the render's mean |Laplacian| over the frame's in a region, 1.0 as
sharp as the frame). The shared head (63 videos, 60,000 steps): on its own training moments the eyes and nose
0.17 at 21.7 dB, the beard 0.08, the hair 0.14, and on unseen moments the same (0.21, 20.5 dB): it is
under-fitted, not over-fitted. 42% of its face splats are nearly clear; its median splat is 7 px.

| head (eyes and nose, on the same video's moments) | steps a video | trained on | unseen |
|---|---|---|---|
| shared, 63 videos | ~950 | 23.15 dB, 0.21 (beard 0.05) | 22.46 dB, 0.22 |
| one video | 6,000 | 27.05, 0.51 (beard 0.31) | 22.86, 0.46 |
| one video, each moment's pose refined | 6,000 | 27.06, 0.51 | 22.47, 0.46 |
| one video, its places settling | 6,000 | 27.24, 0.67 (beard 0.55) | 22.81, 0.68 |
| three videos, settling | 6,000 each | 26.21, 0.59 (beard 0.46) | 23.23, 0.55 |

Why: some 950 steps a video; no rate fell in any loop (3DGS's own rates without its schedule, so every place
wandered a step's worth to the end); the bake starts from the head and is pulled toward it. Not the cause:
each moment's pose (refined, it moved 0.3 px and gained nothing), the moments' resolution, the rasterizer's
low-pass.

Now: the places settle in every loop (`train.Splats.decay`: the place, the expression's and the look's shifts
of place at their rate times 0.01 ** the share done; head.py, bake.py, fit.py, train.py); and the head learns
enough of each video: the Head videos (10) with the most usable minutes of them facing the camera
(`ActorFolder.head_videos`), the Head steps (6,000) each (the same hour and three quarters as 60,000 over
all of them); a video it does not learn from takes the mean look (`head.Footage`'s `unchosen`).

Not done, measured mixed: the bake freed (its pull toward the head off, its face growing anywhere): eyes and
nose sharper (0.41 to 0.51 trained, 0.49 to 0.63 unseen) but 21.71 to 21.30 dB unseen, the two changes not
measured apart. Not tried: keeping the moments with something held before the face out of a set's frames
(`head_frames.py` drops only a hand at the mouth); pruning after the growth ends (3DGS does not).

### What is made again

Generate makes again, in order: Motion (36 s), Utterances (21 minutes on the processor) and Voice (6,000
lessons, under an hour); Head (about 1.7 hours); the set's Avatar (7 minutes) and Fit (3). A copy of a video
is left out on the card at once.

## The second build: a still and a model (2026-10-21, night)

The first build was a series of stitched-together frames: no model, a mouth that did not track the voice,
random gestures cropped by jump cuts, and sets that are pointless when only one is used. The second build
extracts the actor's behavior across all footage and plays it on one still.

**Measured on the first build's set before changing anything:**
- The mouth picked from the library followed the voice's target closely (jawOpen drawn against wanted:
  correlation 0.97 over 12 s), but the target scarcely moved: the range visemes put "open" at his 92nd
  percentile of jawOpen (0.26), the dominance blend held it near 0.09 +- 0.05, and his clean, visibly open
  mouths sit at 0.45 to 0.6.
- His own talking was under every frame: his cheeks, beard and head moved to words he said then, around a
  mouth moving to the voice.
- The library held faults: its "most open" mouth was a hand over his mouth, others a smeared mis-track,
  motion blur, an object across the lips; three mouths mixed every frame doubled the lips and teeth.
- His head turns widely (yaw 43 degrees from the 5th to the 95th percentile) and 97% of its motion is under
  2.5 Hz, so the survey's five looks a second hold it, over all eight videos (117 minutes facing the camera).
- A prototype (one still, the mouth drawn from one clean real mouth per sound class, exaggerated twice past
  his own, at most two mixed, a mask tight to the lips, the head turned 5 degrees through its 3D points)
  read as speech, and the turn was clean up close.

**The design:**
- **The base of every frame is one still:** a real frame of the set, the most typical calm moment (facing
  the camera, eyes open, mouth closed, hands at rest, nothing in front of them, sharp), chosen from a few
  candidates (`stills`); another can be picked on the card. No footage plays, so no hand, prop or jump cut is
  ever seen.
- **What moves is a model of them, from all their footage:**
  - the head (`motion`, per actor): their own head motion where they face the camera, from every video's
    survey, its slow drift taken out, played back in pieces from a seed, scaled to a calm size and livelier
    while they speak; it turns the still's face through its 3D points;
  - the eyes: blinks at their own rate, more often at pauses, drawn from their own closed and half-closed
    eyes;
  - the mouth: each sound class's prototypes (a few clean real mouths each, from any video, at the still's
    turn, chosen for a target pushed past their own range by the Articulation setting, `library`), at most
    two mixed at a moment by the voice's phones (the dominance functions), inside a mask tight to the lips;
    silence is the still's own mouth.
- **A set is only where the pixels come from:** its still, its rig and its library (minutes to build). What
  is the actor's (their range of mouth shapes and their motion) comes from every video. There is no track,
  no takes, no frames extracted, no gestures, habits or director.
- Gestures may come back as the head's own (a nod, a tilt, the brows), placed by a director on the words;
  not built.

**Built:**
- **Steps** (`ActorSteps`): fetch, captions, probe, survey, shots, words, sets, audit; then per actor
  `visemes` (their range, every video's survey) and `motion` (`motion.json`: runs of their head's quick
  motion where they face the camera, which looks are speech, blinks a minute); per set `stills` (six
  candidates, `stills/` and `stills.json`), `rig` (the mesh on the first still, the face's box,
  `mask_mouth.png` tight to the lips, `mask_eyes.png` round the lids, `eye_weights`) and `library`
  (`library.json`, `library/`: three prototype mouths a sound class, two eyes half closed and two shut; the
  Articulation setting, default 2).
- **actor.py:** `survey_records` (every usable look of the given shots, across videos), `stills` (scored
  against the set's median picture and person, the hands against their low resting place since the hands
  seen are mostly raised ones, the brows and smile at rest; then looked at again at full size, sharpness
  counted), `rig`, `visemes`, `motion` (`high_pass`, `runs_of`; a look past 4 of their spreads ends a run),
  `library` (candidates found in the surveys, seeked and re-measured at full size by MediaPipe in IMAGE
  mode, a face straying from the others' median left out, a blurred one only where nothing else is; pushed
  targets on the shapes that show, never mouthClose: pushed, it chose open jaws for P B M).
- **Playing** (`LikenessPlan`, `LikenessFace`, the shader): the head (motion pieces drawn from the seed,
  blended 0.8 s into each other, read between looks by Catmull-Rom, at 0.6 of their own size and livelier
  while the voice speaks, eased past `MOST`) turns the still's 3D points about the neck; blinks at their
  rate and at pauses (70 ms closing, 40 held, 130 opening); the mouth is the two strongest pulls less the
  third, over the strongest, the rest the still's own mouth (`Visemes.strongest`, continuous). One layer, one
  still texture, one library texture array: a frame costs about 0.5 ms.
- **The card:** a Still row (the set's six, the one in use marked, a click uses another: nothing made
  again); the library line says mouths, sounds, eyes, minutes of motion and blinks a minute; a set builds in
  a few minutes. There is no Likeness card: the Actor puts them on the stage, the seed the note's own (see
  "The Actor puts them on the stage").

**Looked at, on his footage (a scratch copy; his folders only read):**
- Stills: a raised hand mistaken for rest, then gestures for rest (the median of hands seen); the low end of
  the hands gives four of six calm with hands down; the first of them is the default.
- The library on all eight videos: 42 mouths for 14 sounds and 4 eyes in about two minutes; P B M pressed
  (cost 1.4-2.1 against 37-48 before mouthClose was left alone).
- His motion: 60 minutes kept in 164 runs; his quick motion's spread 3.3 degrees yaw, 3.5 pitch, 2.2 roll; 30
  blinks a minute from the survey, 33 from the 30 fps track.
- Live, in the app with the real voice (`likeness_live_probe --stamp 1 --bake 1`): the medium 0.4-0.6 ms a
  frame. A baked 30 s take drawn frame by frame (`likeness_look_probe --take`) and joined with its sound:
  the mouth opens on "fox" and "dog", presses on "jumps"; the head moves and settles; blinks at pauses. The
  drawn jaw (MediaPipe on the frames) against each phone's intended openness: 0.59, peaking one frame after
  the phone starts, so no lag; against the voice's loudness 0.08 (his own footage scores 0.16-0.32). It opens
  a little less than he does at the top (jaw 0.20 at the 90th percentile while speaking, his 0.30):
  Articulation raises it.

To judge: Generate on the Actor card once (the new steps: about five minutes), a still picked on the card
if the default is not the one, ▶ on a note; then an export.

## One head (2026-10-23, night)

A Gaussian-splat model is pointless if scenes generate from a single set of images, so the head is learned
across all sets, and the body shifts and morphs a little.

**What is the actor's and what is the set's:**
- **The actor's (every video):** each sound's mouth, motion, blinks, glances, posture, voice, and the head.
  - **Head frames** (per video, `hosts/avatar/head_frames.py`): about 300 moments picked from its survey,
    never read whole. Half are taken farthest-first in the scores and the turn (the mouth weighted most);
    half are spread evenly through the video; none is within 0.6 s of another or has a hand at the mouth.
    Each is read at full size and looked at as frames.py looks.
  - **Head rig** (`rig.py` over every folder): one neutral face, one basis, each frame's video.
  - **Head** (`hosts/avatar/head.py`): one set of head splats, learned from every video at once. Each video
    has a look: a code of 8 numbers that mixes per-splat shifts of place and colour, as the expression does.
    Each video also has its own room (`room_of`) and its own light body, so the head is never asked to paint
    a video's clothes.
- **The set's (one shot):** its moments (`head_frames.py` over its shots, 160, with its stills), posed
  against the actor's face (`rig.py --shared`). Then `hosts/avatar/bake.py`: the head held, the set's look,
  room and body fitted to its moments in 2,000 steps, the head baked in that look, written as an avatar. Then
  Fit. A new set costs minutes, not a 40-minute training.
- **Godot reads the same avatar files.** `train.Frames` takes the components the splats were learned with
  (`expr`): the head's.

**Measured:**
- The moments: 21 videos, about 2.5 minutes each; one video's moments hold 17 with jawOpen past 0.35 (5.7%,
  against 1.5% of its 2-fps shot); all together about 260, against that shot's 76.
- One face over 19 videos: 5,353 frames, the head's pose fitted to 3.78 px (one video alone: 2.25). The
  scores explain 52% of the face's movement (lips 64%), against 59% (lips 64%) for one set's.
- The looks start at none along with the shifts they mix, and neither was ever pulled; the codes start at 0.3
  spread (`CODE_START`); the looks then shift the colours 0.15 to 0.41 (logit).
- The head, 19 videos, 40,000 steps (`dist/head_test/head19`, 44 minutes, 53 ms a step): 21.0 dB round the
  face on 275 held-out moments of every video, each as its video looks (one set's own avatar scores 21.3 on
  its one shot); flat from step 25,000; 134k head splats; the looks shift its colours 0.18 to 0.56 (logit).
  Its previews draw each video's light, expression and turn from one head, but softer than one set's own;
  his hair, worn every way, is the blurriest.
- The set from it: posed 2.85 px, baked 1.6 minutes, fitted to its still 21.9 to 33.3 dB (its own avatar's
  fit: 33.4). Held whole, the head is soft, and below the beard it smears an average of every collar over
  the shirt's. Adapted (the bake fits the head's own numbers to the set, pulled toward the head's: the
  face's surface in full, what is far from it or on the head at FREE_PULL): the face is sharper; 4,000
  steps, 4.9 minutes; a new set is about ten minutes in all. On a held-out moment with his mouth wide and
  teeth showing, the render played from the scores opens it and shows teeth, which the set's own (ASMR)
  avatar never saw. `dist/head_test/per_set_vs_one_head.mp4`.
- **The smear:** drawn alone, the head's splats painted the neck, the collar and the shoulders (an average
  of every collar); the body had a hole there (laid clear of a box round the head, and not fitted where the
  head is solid). The neck's splats are bound to the jaw's edge, near it, so pulling "far from the face"
  missed them (21k of 50k went, the rest still painted it).
- **Fixed: below the chin the head is the set's own.** Every shared splat below the chin is dropped
  (MediaPipe's 152 is the face's lowest point): 50k. The set's own are laid there from its moments, as
  train.py lays a set's: 10.8k, the beard bound to the jaw's edge, free, and grown with the set's body. The
  body is laid below the chin up to the face (`up_to_face`). Collar, neck and undershirt clean, the beard
  whole, the face near the set's own. Bake 5.9 minutes, Fit 3.6 (33.3 dB).
- **A step a program makes is landed and stamped** (`_land_process`): every step with a main file (`MAIN`)
  is stamped, or a step ending "done" with no stamp counts as missing and starts again; `actors_check` holds
  every program's step to having one.
- **Open:** the head's softness (more splats or steps, a look of more than 8 numbers for his hair); judging
  by eye (a vision agent shown the bake's previews, as the Table's art director is shown each painting;
  PSNR called the held head as good as one set's own while the collar was a smear).

**The body bends** (`train.second_of`, `splat_head.gdshader`):
- A second influence per body splat, by where it rests in the still: the torso keeps more and more of the
  still from the chest down to the hips (0.9 at the seat), so the chest and shoulders lean, settle and
  breathe over a seat that stays; a shoulder goes with the torso inward of its joint, and an arm with the
  bone above it near its start.
- Godot blends, handed every bone's 2D move (`SplatHead.pose_bones` -> `moves`).
- Gate: `splat_head_check`: the bone moved and its splats half held by the still, drawn as the rules say;
  the control is the same move unheld.

**A moved video is the same video** (`ActorSources.rescan`, `_moved_here`): an id is its path's, so a moved
folder would add its videos as new (surveyed again) and the sets made of them would lose them. A missing
folder video takes a file of its name found in another of their folders. Its fetch token is named by where
it was first found (`found_at`), so with `mv` keeping the file's time, nothing made from it goes stale. Gate:
`actors_check` (moved, the same video with its survey still made; the control is a copy beside a file still
there, a video of its own).

**A video with too few moments of their face is left out**:
- A video that shows no face (a close read finding none in any moment, a timelapse finding one face in 47
  looks) is answered, not failed. Its moments are written empty (`head_frames.none_of_theirs`) and its row
  says the head learns nothing from it. A set's moments still fail: a set is made from them.
- Head leaves out a video with fewer than `head.LEAST` (20) moments: no room, no body, and the others' mean
  look as its code (`looks_of`). Each video's share of the steps is its share of the moments, so a handful
  taught nothing anyway.
- Gate: `test_fit.py`: videos of 30, 25, 3, 1 and 0 moments: the last three left out, the others learned
  from and held out; the control, with no floor, holds out the one moment and leaves it nothing.
- **A room is kept small** (`head.Rooms`): the plate and seen are uint8, and the move is learned at half
  size and upsampled bilinearly (`move`: the cells round a window, cut to it). 63 rooms took 6.8 GB (training
  peaked at 7.65 GB, heading for about 10 GB at 500k head splats, on a 16 GB card where Praxis trains too);
  now the rooms take 1.30 GB and training peaks at 2.60 GB, the one spike being room building (5.32 GB while
  a video's median is taken). Loss 0.1664 against 0.1672, held-out PSNR 16.26 against 16.22 dB; 44 s against
  58 s. Gate: `test_fit.py`: over windows at the frame's edges and of odd sizes, the move is the whole move's
  upsampling cut to the window; the control cuts with no margin of cells.

## The room behind them, and how far a set reaches (2026-10-23, evening)

**What a set is, to the head of splats:**
- One shot of one video. `ActorBuilder.avatar_shot` takes the set's longest usable shot. His 53 videos fell
  into about 130 sets, and none of the large ones spans two videos: each video has its own outfit, framing
  and often its own room.
- The face rig, the splats, their 12 expression shifts, the body and the room are that shot's alone. What is
  every video's: each sound's mouth (`visemes.json`, at percentiles of his own range), the head's motion,
  the blinks, glances and posture, and the voice.
- The rig moves the mouth alike on both sets. At Articulation 2, "open" parts the lips 13 px on one set and
  15 on another (of a mouth 92 and 117 px wide); most sounds part them 2 to 8 px.
- A set from an ASMR video barely opens his mouth: frames with jawOpen past 0.35: 76 of 5,216, against 330
  of 8,926 on another shot; past 0.45, 6 against 57. The splats there never learned his open mouth, and the
  same opening reads as nothing. Articulation 3 (playback only for this renderer; set on his actor) parts
  the lips a little more and breaks nothing.

**The blur round the head was his body in the plate.**
- The plate started from the set's room picture (`room_K.jpg`). Where the room is never seen, that picture
  keeps the still's own pixels, right for the 2D renderer, which draws them over it where they stand. No
  frame shows the wall there to unlearn it, so the learned plate held his face, beard, shirt and clasped
  hands, sharp (or a smeared face in rainbow streaks). The splats leaned on it: anywhere not fully opaque
  showed the frozen copy (a smudged, see-through collar, a second edge beside the ear and cheek as the head
  moved off the still's pose).
- Now `train.room_of`: each pixel is the median of the frames whose person mask (grown 12 px) leaves it, over
  160 frames of the shot (10 s). A pixel fewer than 3 show is filled from round it (`fill_round`: push-pull,
  smoothed to a harmonic fill). The plate learns only as far as it is seen (`Scene.seen`): 71% of the picture
  on one shot. The Avatar step's version is 2.
- The splats are made faint every 3,000 steps until step 20,000, so a 12,000-step run ended on a reset (21.2
  dB at step 10,000, 17.0 at 12,000). The growing ends at two thirds of a shorter run (`train.until_of`); the
  default 30,000 is unchanged.
- The test run (12,000 steps): held-out frames 21.2 dB round the face and 18.0 round the body, against the
  old 30,000-step avatar's 21.3 and 18.1 with his body in its plate; fitted to a still 21.8 to 31.0 dB. In
  Godot the collar and neck under the beard are whole, and the head has one edge against the wall as it
  moves (`dist/look_mouth/old_vs_new.mp4`).

**One head for every set** (built: "One head"): the head's splats (face, hair, beard) learned from frames of
many videos, each video with a learned appearance code for its light, while the body and room stay the set's.
It buys hundreds of open-mouth frames and his face from more angles; it costs Frames for every video, a longer
training, and his look changing between videos (hair up or down, the beard's length).

**Gates:** `hosts/avatar/test_fit.py`: the room as the frames show it, with the plain median holding the
person as the control; the hair past the mask left out, with the control of no margin; the fill of a ramp;
the plate moving only where seen; a run of any length ending well past its last reset.

## The body as the still holds it

A body learned from every frame (run 2, 40,000 steps, up to 600k splats) is a dark blob with ragged edges
(the sweater's knit gone, the hands two smudges): 23.2 dB round the face and 20.4 round the body on held-out
frames, the same as run 1 with a third of the splats. More splats sharpen nothing, so the frames do not agree.

**Measured: nothing holds a sweater still from frame to frame.**
- The pose's torso jumps where he sits still: every half second its width moves 3.5% and its place 20 px at
  the median (11% and 48 px at the 90th percentile), its turn 1.8 degrees; the face's own scale moves 1.6%.
- His chest, lined up by each candidate frame and medianed over 300 frames: each frame's share of its own
  fine detail that the median kept: the whole patch (desk and microphone in it) 0.43 held at the set's
  median torso, 0.10 on the pose's torso; the upper chest alone at most 0.09 by any frame tried (held still
  0.09, the pose 0.07, the pose smoothed over up to 17 frames or the head's own shift and scale 0.04 to
  0.07).
- Aligning each frame's chest to the median (congealing) ran away: frames slid 42 px at the median onto flat
  dark places where any frame matches. Even frames with his arms at rest keep no knit when medianed. He sways
  and leans, and the knit stretches and folds as he breathes; no rigid frame of reference undoes that, and
  no tracker is precise enough on a loose sweater.

**The body that is played is the still's,** moved by its bones. **The Fit** (`hosts/avatar/fit.py`, the Fit
step, about two minutes):
- Only the body's splats are fitted again, to the one still played; the head's splats and the room are held
  as learned. On his still 8: 26.6 dB before, 32.3 after. The knit, the folded hands and the forearms on the
  desk are the still's, and a torso turned 3 degrees carries all of it as one piece.
- Under the microphone they are fitted to `body_K.jpg` (the still filled from round it), and their outline
  is not asked for there (left free, they grow red and green garbage).
- Not where the head is solid (cover over 0.9): body splats fitted to one picture could paint its face
  there, and the torso would carry it. What lies behind keeps what the frames taught and shows through the
  beard's soft lower edge.
- Never needles: a splat's longest side is at most `FIT_LONG` (6) times its next.
- The splats may grow to `FIT_MOST` (360k) in all (about 396k came out, 177 MB of `.bin`). Every body splat
  still carries 24 texels of expression shifts that are always zero; the shader skips reading them, and a
  compact layout is open.
- Picking another still makes the Fit stale (the still is in its fingerprint), and nothing else. Until it is
  fitted again, the medium plays the still the fit was made for (`fit.json`'s `still`).

**The head's splats must not paint his chest:** on run 2's avatar the head's splats covered past 2% across a
fifth of the frame and past 50% in patches on the chest (505 large faint ones bound to the head with nothing
holding them near it), a chest that turned with the head. A splat of the head or the face whose centre stands
past the head's region (`train.head_region`, grown by `HEAD_REACH` 16 px) is dropped every 100 steps in
training (`train.astray`) and before the fit (500 to 1,700 every 1,000 steps).

**Run 3** (the strays dropped in training, 36 minutes): the same scores on held-out frames (23.1 dB round the
face, 20.4 round the body), none of the head's splats astray at the still's pose, the body behind the beard a
plausible dark turtleneck. Fitted to still 8: 26.8 to 32.0 dB, 401k splats. In Godot
(`likeness_look_probe --renderer gaussian --take`; `dist/avatar/demo_fit/fit_demo.mp4`): the knit, the folded
hands, the turtleneck under the beard. Change per frame (1/255, mean / largest): the head 1.14 / 4.06 and the
beard's edge 0.90 / 4.55; the chest 0.30 / 1.82 and the hands 0.21 / 1.21, moving as the bones do. Loaded in
0.66 s (0.2 after), posed in 5 ms; drawn as the trainer draws it, 32 to 40 dB over the frame.

**Its limit:** each splat is bound to one bone. A pose far from the still (a lean, an arm raised) shatters the
fitted sweater along its bones, in the trainer's drawing and Godot's alike. Played, the body stays near the
still (posture shifts, breath), so it holds. Gestures would need splats skinned across bones, as the 2D
body's mesh is.

**Gate:** `hosts/avatar/test_fit.py` (the training venv, no graphics card): the needle cut, the head's splats
past its reach (in the face and the hair kept; over the chest, far off and off the picture astray; a body
splat there kept), and the still as one more frame (its bones' axes read as columns, against a non-symmetric
control; tracked and played alike).

## The whole of them

Goals: movement beyond the head (the gaussians applied to more of the scene, so his body can move), and a
stable head region (the tip of the beard, along the sweater and around the head against the wall were smudged
and smeared).

**What the edges were**, measured (the demo's change from frame to frame round the head, its expression
shifts on and off): with them, the beard's whole lower outline flickered as a bright ring and the head's
outline glowed; without them only the eyes and mouth changed (0.71/255 a frame against 0.47). The shifts
were learned for the face, and a splat far from its triangle (the beard's tip, the hair's edge) swings on a
lever with each one; played, they were also pushed by Articulation past the range they were learned in.

**Built:**
- **Shifts only on the face, fading with distance:** a splat takes its shifts fully on its triangle and none
  two of its units out (`SHIFT_NEAR`, `SHIFT_FAR`; train.py's `Splats.shift_weight`, the shader alike). The
  expression a sound is played with is its own scores, not pushed: Articulation pushes the face's geometry
  only.
- **Whole frames** (frames.py takes [x, y, w, h]; the Frames step reads the shot whole) and **the body's
  bones** (rig.py's `BODY`, the 2D rig's bones less the head): the torso, the shoulders, each arm's upper
  arm, forearm and hand, from the pose, in one plane half a shoulder width behind the face's nose tip
  (MediaPipe's pose guesses at depth, the camera is fixed, and a splat's own depth on its bone is learned).
  Every frame with a face is posed, a hand at the mouth included (the hand is theirs); the expression basis
  is fitted only on frames with no hand there.
- **The trainer learns the whole of them over their room** (train.py): binding to the face's triangles, the
  head, the nine bones; a bone not seen in a frame has its splats drawn clear there, so a hand under the
  desk is not learned from MediaPipe's guess (each bone's first splats are laid in the frame where it is
  seen best); the room is a learned plate (the set's room plate to start, refined where the frames show it,
  with a gain per frame for the light; the halo against the wall came from edge splats painting the gap
  between a guessed room and the true one); each step learns a 704 px window of a whole frame, half of them
  round the face; the export has the bones and `avatar.plate.png`.
- **Godot** (`SplatHead`): `pose_face` carries the head on the torso (a 2D transform); `pose_bones` places
  the bones as the still holds them, each moved as the 2D body's bone is (`LikenessFace.bones`: posture,
  breath, lifts, resting hands), a bone the still does not show flagged and its splats drawn clear. The
  medium draws the avatar's room and hides the still's 2D layer. The gate holds a bone, a hidden bone and a
  leaning torso to the rules (10 checks).

**Data:** more of one shot adds little (9,000 frames at 2 a second already sample his range). More videos add
expressions, mouth shapes and slightly different camera places, and also changes of look (lighting, hair,
beard, glasses, clothes) that pooled naively would only be averaged. The plan: unwrap his face from each
video's frames onto the rig's canonical layout, compare videos by the cosine similarity of their mean
unwrapped faces, and let in those that show the same him, weighted by it; each keeps its own room plate and
light gain. `scripts/fetch_channel.py` fetches his newest N videos (Shorts left out) into a cache,
standalone, with its own yt-dlp kept current.

## A head of splats (2026-10-22, night)

Goal: a second renderer for the Actor card beside the 2D one (the 2D version is a janky first draft in the
uncanny valley), with as few external dependencies as possible.

**What was decided:**
- No FLAME, no SMPL-X, no gsplat: the face and body models need an account with the institute that publishes
  them (credentials), and gsplat compiles CUDA with nvcc.
- The surface is MediaPipe's own face mesh, which ghost already tracks. Its triangles are read off its
  tessellation (854 cliques; 6 edges on more than two are cleaned), with the mouth's and the eyes' holes
  filled.
- Splats are bound to its triangles (GaussianAvatars' binding), or to the head for the hair and ears.
- The rasterizer is ours, in Triton, which ships inside the PyTorch the voice already fetches.
- The renderer is ours, in Godot. The camera is fixed and the head turns little, so the splats are drawn in
  one order, back to front as the neutral face stands, and never sorted per frame.
- The head is splats; the body and room are the 2D still's, drawn under it.

**Built:**
- **`hosts/avatar/frames.py`** (face_venv): the set's longest shot read twice a second at full resolution,
  cropped round the head. Each frame gets MediaPipe's 478 points, its 52 scores, the head's matrix, the
  body's points and the person mask; the set's stills are tracked alike.
- **`hosts/avatar/rig.py`:** their neutral face; each frame's pose (a similarity fitted on the points that
  move least); a ridge basis from the 52 scores to every point's offset (what drives the playing head); the
  triangles; and `poses.json` (each still's pose and scores, their median scores, the shut eye's score).
- **`hosts/avatar/raster.py`** (+ `test_raster.py`, 4/4 with controls): a tile rasterizer, forward and
  backward in Triton, held to a dense PyTorch reference to 3e-7. Forward plus backward takes 4 ms for 100k
  splats at 512 px. Its header lists the exact rules for a port.
- **`hosts/avatar/train.py`** (voice_train_venv, the graphics card's lane): each step takes one frame,
  places every splat from the tracked face, renders it over what is behind the head, and scores it: L1 +
  D-SSIM inside a region round the head, plus cover against the person. A colour correction per frame, 3DGS's
  densification, GaussianAvatars' regularisers. What is behind the head is the room above the mouth, and
  below it their own body where the frame shows it (a pixel near their clothing's colour), else splats bound
  to the jaw paint a dark smudge of sweater round the beard. It writes `avatar.npz`, and `avatar.json` +
  `avatar.bin` for Godot.
- **`hosts/avatar/look.py`:** held-out frames as played, with their poses, for the probe.
- **`src/likeness/splat_head.gd` + `.gdshader`:** one instanced quad per splat. A data texture holds the
  splats; a small float texture holds the binding frames, posed each frame in GDScript (6-8 ms) from the
  scores. The vertex shader places each splat as the trainer does, and the canvas blends them over.
- **The medium** (`LikenessMedium`, renderer "gaussian"): the splat head on a layer between their body and
  what stands before them. Its scores: the still's own; each sound's mouth from `visemes.json`, weighed by
  the plan's pulls and pushed past their own by the Articulation setting; the lids as far shut as the blink;
  the glances (the Face rig's `looks`). Its pose: the still's, turned by their motion about the neck,
  carried by the torso.
- **The Actor card's Renderer** (2D / Gaussian, the block's `renderer`): Gaussian steps Frames, Face rig and
  Avatar; 2D only Library and Learn; everything else shared. The card shows and the builder makes the note's
  renderer's steps; the other's settings are kept. `ActorSteps.RENDERERS` says what each needs to play.
  `ActorBuilder.cannot_train` leaves every graphics-card step alone without an NVIDIA card.

**Measured, on his set (the long shot of one 75-minute video):**
- The frames: 9,031 at 2 a second; 8,632 had a face and no hand at the mouth (hands anywhere round the head
  are left out of learning).
- The rig: head pose fitted to 2.3 px on 143 points; the scores alone explain 58% of the face's movement on
  held-out frames (69% of the lips', 72% of the eyes'); drawn over the frames, the rig's lips and lids sit on
  the tracked ones.
- Training: about 40 ms a step at 512 px; 260k splats by step 15,000; 24 dB PSNR in the head's region on
  held-out frames; at 2,500 steps it is recognisably him.
- Godot against the trainer on the same poses (`tests/likeness/splat_head_probe.gd`): 30 dB on the head and
  37 dB over the square (the differences are fine edges, the price of one draw order). Loading 127k splats
  takes 130 ms. Live in the app (`likeness_live_probe --renderer gaussian`): it plays, reading in his own
  voice, his head a 3D head over his body and room.
- A set's shots are not one framing (his first two are framed wider), so a head is learned from the longest
  shot only (`ActorBuilder.avatar_shot`). A hand raised beside the head is in the person mask, so such
  frames are left out.

**Since the first run:**
- Learned at full resolution (704 px, the crop's own): 248k splats, 33 minutes, 24 dB on held-out frames.
- The still's own head is cut out above the mouth (`likeness_warp.gdshader`'s `head_cut`, from the trainer's
  region): the room shows through the splats' soft edges, as they were learned.
- The played face mixes faces made once (`SplatHead.face_of`): each sound's, the shut lids', each glance's. A
  frame mixes three or four of them, not 52 basis arrays.
- A demo of the probe's sentences in his own voice, frame by frame from a baked take
  (`likeness_look_probe --renderer gaussian --take`).

**Why it was soft, measured:** not registration (fitting each frame's pose with the splats held lowers the
error only 1.5%); little the light (learned on the 15 minutes round the still's time it is 0.6 dB better, as
soft by eye); underfit (its error on frames it learned from is near its error on those it did not: L1 0.034
against 0.0385): one place and one colour for every expression average away what changes with it (the
teeth, the creases, the lips' own shapes).

**So a splat changes with the expression** (GaussianBlendshapes, SIGGRAPH 2024):
- The expression is the 52 scores' first 12 principal components over the frames learned from, each scaled
  to its spread. Each splat has 12 shifts of its place and 12 of its colour's logit, mixed by the expression,
  and pulled toward none.
- In Godot the export writes the shader's data texture whole (28 texels a splat). The shader mixes the shifts
  by `expr`, which `SplatHead.expr_of` makes from the scores; the medium makes each face's expression once
  and mixes it with the face. The most splats is 400k.
- The gate holds it: drawn at 0.8 of an expression, 0.48/255 from the rules; its control, drawn at none,
  does not match. First run (40k steps): his teeth show in a smile where the run before had a blur;
  held-out error is level (24.22 dB against 24.18).

**And a fog:** that run's median splat stood 4 px wide, and only 15,544 of its 180k splats covered more than
0.05: the head was a fog of big faint splats, stacked, and a fog is soft. Densification copied whole every
splat up to 1% of the square (7 px); 3DGS's 1% is of a whole scene's extent, and a head that fills the
square needs a finer cut. Now: split above 0.2% (`SPLIT_SHARE`); once the splats stop growing, each cover is
pushed to decide, on or off (its binary entropy, `DECIDE`), and the nearly clear are dropped every 1,000
steps. Result: 7,566 splats at the end (from 222k at densification's height), held-out error level (24.21
dB), by eye the same as 180k. The splats were never what limited it.

**So what is soft is what the frames teach.** A splat settles on the average of what it sees in every frame,
and fine detail (pores, creases, strands) slides a pixel or two against MediaPipe's coarse mesh from frame to
frame, the beard's strands on their own. The papers get sharp heads by tracking the face against the pixels
themselves (photometric tracking, dense correspondence), the next piece of work if this is taken further.
Kept: run4 (`dist/avatar/run4/`), light to draw; demo `dist/avatar/demo4/splat_head_demo.mp4`.

**Not yet:**
- The mouth opens less than his own; Articulation pushes it.
- No export has been made with it (the demo is the look probe's, frame by frame).
- Gates: `tests/likeness/splat_head_check.gd` (GPU) holds the shader to the rules, worked out in GDScript on
  a made avatar: 0.5/255 mean. Its control transposes every splat's turn and is 12.7/255 off. Against a
  trained avatar, the probe prints the gap (30 dB on the head).

**To try it:** Renderer -> Gaussian on the Actor card, then Generate. Frames takes about 25 minutes on the
processor for a 75-minute shot, Face rig seconds, Avatar about 25 minutes on the graphics card. Then ▶.

## Their own voice

Goal: fine-tune the actor's voice as a Piper model.

**What there was to work with (measured):**
- **His sound:** eight videos, 7.1 hours; one has no sound track. Clean: his speech sits 25 to 42 dB over the
  room, nothing clipped, the full 11 kHz a 22 kHz voice holds.
- **Five of the eight are whispered.** A third of their loud frames carry a pitch, against three fifths in
  the two spoken ones (128 minutes). A whisper is another voice; it is left out.
- **Whisper's words,** as Transcribe left them, cover 20 minutes of each video, base.en on the processor: a
  median word sure at 0.91, a fifth of runs holding one under 0.34, and its errors are real. Its word edges
  come early: his voice runs on 30 to 48 dB over the room just past a word's end.
- **Piper's trainer** is in its PyPI wheel (`piper-tts[train]` 1.8, GPL; fetched into an environment of its
  own, never shipped; the voice it makes is data), on PyTorch 2.14 with CUDA 13, which runs on this RTX 5060
  Ti (sm_120). The wheel leaves its Cython alignment unbuilt: numba's, line for line the same search
  (`hosts/voice_train/align.py`), takes 6 ms a batch. It takes our own ids (`dataset_type phoneme_ids`), so
  the voice is taught exactly what the voice host will send it.
- **Clean bases to fine-tune from** (`rhasspy/piper-checkpoints`): John (medium, male, LibriVox public
  domain, itself fine-tuned from Kristin), LJSpeech (high, female, public domain), Kristin, Norman. Every
  lessac-derived one is out (Blizzard's terms). A John checkpoint exported by our own exporter (TorchScript,
  opset 15) loads, patches (one Ceil) and speaks through the voice host as Piper's own do.

**Built:**
- **Hear** (per video, the processor, speech_venv): the whole of each video heard by Whisper
  (`transcribe.py`, in pieces of 10 minutes), told the ums came before so it writes them.
- **Utterances** (`hosts/voice/utterances.py`, voice_venv): his words in runs between pauses, 1 to 12 s,
  every word heard surely; each edge walked out to where the sound falls and cut at the quietest frame of
  the pause beyond (within 12 dB of the room); none holding a sound no word was heard in (an um Whisper left
  out, a laugh); spoken, not whispered; all at one level; the ids are the voice host's own (`ids_of`: its
  homographs, its eSpeak reading of the sentence, its lead-in spaces, its layout). Every 25th is held out
  (`test.csv`) to measure the voice against. On his videos: 637 sentences, 46 minutes (42 from the two
  spoken videos), 26 held out; 475 whispered runs left out.
- **Voice** (`hosts/voice_train/train.py`, voice_train_venv, a lane of its own, the graphics card, beside the
  processor's): John warm-started (every weight, a fresh optimizer) and fine-tuned for the Voice lessons
  setting's epochs (150), bf16, batch 16, about 25 seconds an epoch, an hour all told. The whole run is saved
  every 5 epochs (and at an epoch's end 10 minutes past the last save) under another name and renamed into
  place, so Stop loses a few minutes and ▶ goes on. An epoch is as long as their speech (all 65 videos gave
  6,909 sentences, 8.3 hours, about 5 minutes an epoch), so each epoch's line says the time to go; the
  allocator grows its segments (`PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True`) so the card shared with
  another trainer is not run out of; other sentences or another base start again from the base. When every
  epoch is done the voice is exported and published (`ActorBuilder.publish_voice`): copied to
  `<data>/ghost/voices/piper/trained/actor-<id>.onnx` with its config and a description (`<id>.voice.json`:
  their name, what it was fine-tuned from), where the voice host lists voices trained here beside its
  allowlist (`TRAINED`), never fetched. It is on every note's Voice card as "<name> (their own voice)".
- **The note it was trained on reads in it as it lands:** `ActorBuilder.voice_published` ->
  `ActorCard._voice_made` -> `ReadingPanel.voice_made`: the voices are asked for again, and the reader's tab
  is set to it (`ReadingCast.voice_made`). A list asked again keeps what is picked. On any other note, or
  after a restart, it is picked on the Voice card like any voice. Gate: tests/reading/voice_made_check.gd.
  The first run: 915 utterances, 65 minutes of his voice from 7 videos, 150 epochs in 99 minutes; through the
  voice host it says a test sentence that Whisper (small.en) hears word for word.
- **A machine that cannot train** (no NVIDIA card, or a platform PyTorch has no CUDA build for) leaves the
  three steps alone; their rows say why (`ActorBuilder.cannot_train`).

**Measured** (the held-out sentences said by each voice through the voice host, against his own; his pitch,
his long-term spectrum and his MFCCs' distribution, `dist/voice_train/probes/likeness.py`, and what Whisper
hears each say, `wer.py`):

| voice | pitch median / IQR (Hz) | spectrum off (dB) | MFCC distance | Whisper's word errors |
|---|---|---|---|---|
| him, 26 other sentences of his | 154 / 53 | 0.96 | 0.22 | 2.5% (his own; mostly the transcript's) |
| John, the base | 119 / 34 | 4.70 | 4.08 | 4.3% |
| fine-tuned, epoch 10 | 135 / 31 | 1.32 | 2.07 | 31.6% |
| fine-tuned, epoch 30 | 137 / 40 | 0.98 | 1.17 | 22.6% |
| fine-tuned, epoch 120 | 140 / 43 | 0.81 | 0.82 | 18.9% |

Their tone is there by epoch 30 (the spectrum as near his held-out speech as his own other sentences are);
clarity is not: a fifth of its words misheard, against the base's 4%. Read 20% slower it is misheard just as
often, so it is not the pace. What is misheard is mostly vowels. The likeliest cause, the next experiment:
John was taught on eSpeak's British labels (`espeak.voice "en"`, as every published Piper voice of the base's
line) and is taught him in American ones, so the vowels' symbols are learned again from 46 minutes; taught in
John's own labels, the vowels it knows carry over (the voice's config then says "en" and the host reads it
so). Listening (`dist/voice_train/listen/`): `0_him_heldout.wav`, `1_john_base.wav` and
`2_his_voice_epoch120.wav`.

## The fourth pass: a body, modeled

Symptom: the actor's body is completely rigid, rocking constantly, and the hands stay in an open-palm
gesture; a relaxed, neutral posture that is not frozen is wanted.

**Why, each (measured on his footage):**
- **The rocking:** the body played the quick part of his shoulders' motion (the slow drift taken out, 4 s):
  about 60% of it swings with a period of 1 to 4 seconds, 0.75 degrees of tilt about a pivot at the frame's
  foot (12 px at his head). It is his gestures pulling at his shoulders (their quick motion is 40-70% larger
  while his hands move most than while they move least), and a still whose hands never move has nothing to
  pull them.
- **Rigid:** one transform moved every vertex of the body, hands, arms and torso as one block.
- **The open palms:** his open-palm gesture is held at the desk's height, the same as the low resting place
  the still was chosen against. No measure of the body's points told them apart: on 21 frames looked at by
  eye (8 at rest, 9 open-palmed, 4 holding a phone), the wrists' height, their stillness over 5 s, their
  range over 10 s, the hands' distance apart and the turn of the hand's points all overlapped.

**Built:**
- **A skeleton on each still** (`rig`'s `stills`: `skeleton`, `skin`): from its pose (the hips, seen or 1.35
  shoulder widths under the neck behind the desk; the neck; each shoulder, elbow, wrist and the hand's end)
  and every vertex of its mesh weighed to its bones (actor.py `BONES`: the torso, the head, each shoulder,
  upper arm, forearm and hand), the mesh given points along each arm and its sides so an arm bends apart from
  what is behind it. A hand seen in the picture rests: it stays where it is (but for its own small drift)
  while the torso moves, and its arm bends between it and the moved shoulder, the elbow found as an arm's is
  (two bones keeping their lengths, bending the way they bent: `LikenessFace.elbow`). A hand out of the
  picture goes with its shoulder.
- **A posture, held and shifted** (`LikenessPlan.posture`): the torso holds a posture for about 1.8 of his
  own holding time (`motion`'s `posture`: the lag at which his 6-second posture falls to 1/e of itself), then
  shifts to another over 1 to 2.2 s, each drawn from his own range of posture with his axes' own
  correlations, half of it (a third of his tilt), keeping half of the last, with a slow sway under it (knots
  3 s apart) so it is never frozen. What is quicker than 4 s is 0.14 of the posture's motion on the gate's
  made motion, against the head's 1.09 (body_check). The breath stretches the torso about the hips and lifts
  the shoulders, which also wander a little each on its own (`lifts`); the hands settle somewhere new, a few
  pixels, as the body shifts (`hands`). The head keeps turning on the neck by his own quick motion, and
  takes back 0.7 of the body's tilt, keeping its eyes level.
- **The still at rest** (`rest`, "At rest" on the card, an agent: `rules/likeness/rest.yaml`): the stills step
  keeps 12 candidates and puts them on one numbered sheet; a writer says which show him at ease (hands
  folded, resting or out of sight, nothing held, facing the camera), most at ease first (`rest.json`). The
  Likeness is drawn on the first unless one is picked; the card shows those first, marked; stills made
  again forget the pick.
- **What stands before them** (`front_K.png`, `body_K.jpg`): a pixel that is still the still's in 60% of the
  set's frames (at half size, each still judged against its own pixels in the first still's light: its color
  within 14 levels, and where the still has texture its patch alike too) and still the still's in the
  frames where he is there hides him, in a piece of 3000 pixels or more: it is drawn over him and never
  moves, his matte kept whole under it and his picture there filled from round it, so he moves behind it.
  One that never moves at his matte's edge is the wall his matte bled over: out of his matte. Texture alone
  never matches the microphone's plain dark body; color without each still's own light never matches either
  (the light moves 15 levels over the hour); with it, half his dark sweater matched too; color plus texture
  where the still has some finds the microphone's body and a few flecks. Its spider mount's thin rods and
  its cable are not found, and still move with him a little.
- **The room's frames** are 150 across all of the set (not its first quarter hour, whose light is 13 to 28
  levels off the later stills').
- **The room behind a head where they seldom sit:** the plate is trusted where a quarter of the frames saw
  the room, or six that agree (three quarters of them within 12 levels of their median: `trust`); otherwise
  it is filled from round it.
- **A light halo round the head:** the plate is darkened or lightened as the still's wall just outside him is
  against it, spread 30 px inward (`SHADE`), since his shadow on the wall is in the still and not in the
  plate.
- **A light sliver between his arm and the chair:** his matte is soft there (0.2 to 0.5), and away from the
  head the plate is used only where the still is mostly him (`SOFT`, 0.6): under a soft edge the room is the
  still's own, so at rest the picture is the still. Round the head (2.3 of its radii) the plate reaches 12 px
  past his edge, so no hair is left on the wall as the head turns.

**Looked at (scratch copies of his set; his folders only read):** 38 s of a Piper voice drawn on the new
stills' 10th (hands folded; `dist/likeness_v4_preview.mp4`). His resting hands move at most 2 px; his
shoulders up to 13 px, held for 5 to 10 s and shifted over about a second; the wall not at all. The still
drawn through its mesh at rest differs from the still by 0.0043 of full scale. The microphone's body stays
put; at the largest shift a thin seam shows at its lower right. The stills step takes about 13 minutes on
his set with the machine loaded (12 stills, 150 frames). Open: At rest has not been asked of a writer on his
sheet (the gate lands made answers).

## The third pass: the whole of them

Symptoms on the second build: the body does not shift, the head floats instead of pivoting, the eyes never
look around, the region around the head smears (the wall and its picture), every mouth a different color,
weak mouth shapes.

**Why, each:**
- The smear: the only thing between the head and the frame's fixed edge was a ring of mesh, so the wall
  stretched wherever the head went.
- The float: the head was moved by where their face's box went in the footage and turned about the neck: two
  motions for one.
- Nothing else moves: no mesh over the body, so nothing to move it with.
- The colors: each prototype matched to the still by their cheeks' mean only.
- The stare: the library held no eye looking aside.

**The plan, in order:**
1. **Layers:** them over the room (a clean plate of the set made from its footage: each pixel the frames
   where it is not them, each frame's light matched to the still's; the still's own room wherever it
   shows), cut out by a person matte, so the room never moves and what the head uncovers is the room.
2. **The body:** a mesh over them from their pose (the shoulders, the neck, the silhouette, inside), each
   vertex weighed between the head and the torso; the torso moved by their own body motion from the same
   footage (the shoulders' place and tilt, how near), the head turned on the neck by their head's own turn
   relative to it, and the chest breathing in at the voice's pauses.
3. **The colors:** every library image matched to the still round the lips and the lids (their mean and
   spread in Lab), at build time.
4. **The eyes:** their own eyes looking aside, down and up, in the library; glances drawn from the seed.
5. **Their words:** a local speech recognizer (faster-whisper) gives every usable stretch its words and
   times where there are no captions; the visemes are then learned from them.
6. **A model of their mouth, learned from every video:** an ensemble of small networks from the voice's
   phones round a moment to their mouth's shape there, trained on every survey look against its transcript.

**Built:**
- **The room and the matte** (`stills`): each still's matte from MediaPipe's segmentation (copied: its mask
  is a view of a buffer the next frame overwrites), less what stands before them (pixels whose texture
  matches the still's in 60% of the set's frames: the microphone; a color test failed, the wall itself
  varies 22 levels as the sun moves). The room: the still's own where it is not them; behind them the median
  of 90 frames where each pixel was not them, each frame's light fitted to the still's (a mean takes in the
  globe and ghosts of them), trusted where a quarter of the frames saw it; the rest of the 70 px band their
  motion can uncover filled from the room round it only (filled from them, the sweater smears into the
  wall). `room_K.jpg`, `matte_K.png`. The medium draws the room, then them through the matte: a frame's
  difference to the first is zero on the room.
- **The body** (`rig`'s `stills`): each still's mesh (its silhouette every 45 px, a band 55 px out, a grid
  inside, the shoulders, elbows, wrists and neck), each vertex weighed to the head (all of it above the
  neck's foot near the head, none at the shoulders) and to the body (on them and near; none out in the
  room). `motion` holds the shoulders' place, lean and tilt from the same looks, and the head's turn relative
  to them (its roll's sign read from the data: head and shoulders lean together); the head only turns, on
  the neck, and the body carries it (`LikenessFace.body_xf`), breathing in at the voice's pauses
  (`LikenessPlan.breath`).
- **The colors:** every library image matched to the still round the lips or the lids (mean and spread in
  Lab, `color_like`); and glances: their eyes looking left, right, up and down in the library, about one
  every 4.5 s, held 0.35-1.2 s (`LikenessPlan.glance`).
- **Their words** (`transcribe`, `hosts/speech/transcribe.py`, the `speech_venv` with faster-whisper and
  Whisper's base English model, MIT, pinned by its sha256): each video without captions, its usable steady
  shots up to the Listen setting's minutes (20), word by word; `words` reads captions or the transcript.
  9x faster than real time on the processor.
- **Their mouth, learned** (`learn`, `mouth_model.json`): eight networks (the inputs: how much of each of 15
  sound classes fills each of 9 windows of 60 ms from -240 to +240 ms, shares, so the mouth moves smoothly;
  32 tanh neurons; their 23 mouth blendshapes), each trained by Adam on its own resample of every survey
  look near their words, their mean the mouth. One video is held out first and the card says what it
  explains there beside each sound's average mouth. The medium reads it as trained (`LikenessPlan._inputs`,
  `_predict`: coarticulation_check holds a made one-neuron network to tanh(1), tanh(0.5) and 0), pushes it
  past their own by Articulation and draws the two library mouths nearest it, the nearest whole and the next
  by how far it is from the third (continuous as the order changes). On a made voice whose lips close 120 ms
  before each closing sound, the ensemble explained 0.88 of the mouth on unseen speech, each sound's mean
  mouth 0.57 (test_actor.py).

**Measured on his footage (scratch copies; his folders only read):**
- The room, the matte, the body: a frame's difference to the first is zero on the wall, the picture and the
  window, and spread over all of him; the picture frame's edge beside his head stays sharp as the head
  turns. The medium draws a frame in about 1.1 ms with the body.
- Transcribe: six videos (two have no sound, or are handheld throughout), 20 minutes each, 18,229 words in
  about 14 minutes of processor; 59,836 phones from them.
- **Learning his mouth failed on this footage, and says so.** His measured mouth scarcely follows the
  sounds: whether a vowel is being said against his jaw correlates 0.02-0.08 per video (at lag 0), 0.05-0.12
  on the full-size 30 fps track, and no better by the lips' gap, height or the darkness between the lips; at
  the coarse level only (speaking against pauses) his jaw is 0.1-0.4 of its spread higher while he speaks.
  His beard hides his mouth from MediaPipe, and a phone's time is guessed within its word (Whisper times
  words, about 100 ms late here). The visemes learned from the words span 19% of his jaw's range (the
  range's own 85%): every sound nearly the same mouth, so `visemes` keeps the range below 40%
  (`WORDS_SHOW`). The ensemble, each video against its own mean, explains 2.5% of his mouth on the held-out
  video (each sound's mean 0.9%, one network -1.1%): it beats both, but too little to draw from, so the
  medium uses it only past 15% and 5 points over each sound's mean (`LikenessPlan.LEARNED_LEAST`), and the
  card says which.
- **What would let it learn:** phone times in his speech, not word times (his transcript spoken by Piper,
  whose phones are exact, and aligned to his sound by DTW over their spectra, no new dependency); a measure
  of his mouth his beard does not hide; or a capture session (a short scripted reading, his mouth lit and
  seen).

## Status of the first build

The first build (a retrieval-based player: his real takes as the base, his real mouths warped into them) is
superseded by the second build: its `track`, `mouths`, `takes`, `gestures` and `director` steps, `ActorTrack`,
`LikenessFrames`, `LikenessCard` and the gesture rules are gone. What it still contributes: the library, the
steps up to `sets`/`audit`, the survey, the shots, the Actor card and the medium row.

**Built (first build):**
- `src/likeness/` (a row in docs.py's `FOLDERS`): `Actors` (the library), `ActorFolder` (one actor on disk;
  the plan's `Actor` renamed, since `stage/cast.gd` has an inner `Actor`), `ActorSteps` (the steps and the
  settings, as rows), `ActorBuilder` (the runner), `ActorSources` (folders, links, captions), `ActorPrompts`
  (the agents' words in, their answers out), `ActorCard`, `Visemes`, `LikenessFace` (the rig, the library,
  the mesh), `LikenessPlan`, `LikenessMedium` (`likeness.gd`) and `likeness_warp.gdshader`.
- `hosts/face/actor.py` (survey, shots, sets, rig, visemes, stills, library, motion) and
  `hosts/face/test_actor.py`; `rules/likeness/audit.yaml`.
- The component row `actor`, the medium row `likeness`, `NoteCards.KEYS`, the reading workspace's `hosts`.
- **Phones ride with words:** the Piper host's token path hands back every phone with its time
  (`_last_phones`, moved by every resample, trim and splice the word spans are), `ReadingJoin.phones`,
  `Subtitles.phones`, the export's sidecar `phones`.
- **Gates:** `actors_check`, `coarticulation_check`, `warp_check` (GPU), `likeness_determinism_check` (GPU),
  `hosts/face/test_actor.py`, a Likeness note in `teardown_check`, the likeness prompts in `rules_check`.
  Probes: `likeness_look_probe`, `likeness_live_probe` (▶ in the real main scene).

**Looked at:** the frame redrawn through its own mesh came back with a mean difference of 0 and a worst pixel
of 1/255 (`warp_check` holds it); another stretch's mouth drawn in (one mouth, and three mixed) was natural
at full size, with no seam in the beard, no color break, no popping. The survey ran at 0.28 of real time.

**His footage, found while building:** his videos have no automatic captions, so no viseme is learned from
captions (every class takes its place in his own range, `Visemes.REGISTRY`'s `range`; the row says "from
their own range (no captions)"); one video has no audio; one continuous take can hold a handheld stretch
(hence shots split by camera motion); his channel holds 2,040 videos, and a captions-only link lists them in
seconds and matches the folder's eight by title.

**Findings from a full Generate over all his footage in the app** (eight videos, 29 sets): "Use this set"
(not "Play this set") switches the set in use, each set says whether it is built and roughly how long
building it takes, and there is one Generate, on the Actor card. A frame's share of the medium is decoded to
RGBA8 on the worker and not uploaded again when a 60 fps show draws the same footage frame twice. The cards
keep the actor's json files while unchanged on disk (`ActorFolder.read_kept`) and make the library line and
the step rows again only when what they show changed. A segment with no frames is a failure
(`actor.py frames`), and the stage names the missing video (`LikenessFrames.trouble`). A fingerprint takes
what a step reads by id (`ActorFolder.inputs_of`) and `actor.json` keeps the video order, so a restart does
not make a built set stale (actors_check holds it). Not yet seen working: an export.

**How to try it:**
1. On a note, "+" Actor: it brings a Voice, and the note is read by them.
2. On the Actor card, pick "New actor…" and name them. Add folder… (the videos folder), and untick other
   creators' rows.
3. Generate on the Actor card. The first time, ghost rebuilds the face and download environments (about 520
   MB), then surveys every ticked video (about two hours for seven), groups the sets, has the labeler audit
   each, learns their mouth's range and their motion from every video (seconds), and builds the set in use
   (its stills, its rig, its library: a few minutes). The Still row then shows six pictures of them; a click
   uses another.
4. Write the words on the Script card; ▶ reads the note with them; ⤓ exports. A set is used with "Use this
   set" on the Actor card; each is built on its own, and one built is kept.
5. To look without the app: `tests/likeness/likeness_look_probe.gd` (its header) draws the identity, every
   sound's mouth, the eyes, and a take frame by frame; `likeness_live_probe` plays the real app and bakes a
   take with its phones.

## What changed from the plan

1. **No new file.** The mouths' layout is the set's own mean face with a moderately open mouth (the frames
   between his 60th and 92nd percentile of `jawOpen`), not MediaPipe's canonical UVs (the canonical mouth is
   closed): `canonical_face_model.obj` has no row.
2. **The target face is the chosen mouths' own shapes,** mixed by their weights; `visemes.json` holds the
   shapes per class only.
3. **The mouth's key is measured against his own spread** (`actor.py`'s `key_scale`, `KEY_WEIGHT`): his
   blendshapes span a few hundredths and his head turns over 40 degrees, so a key of raw values chose every
   mouth by the turn alone.
4. **One gain for all three channels** when a mouth is matched to a frame's light
   (`LikenessFace.match_light`): a gain per channel turns a red lip teal.
5. **Shots split where the camera starts or stops moving** (the background's own change, 0.1-0.3 on a
   tripod, 1.5-20 handheld); a set says it is `handheld`; the default set is the steady one with the most
   usable minutes. A jump cut is confirmed at the full frame rate.
6. **A `captions` step:** a folder video matched to a link's entry fetches its captions before its words; a
   video with none is made with none, never a step that blocks.
7. **The hands' exclusion reaches down over the beard** (0.7 of the face's width below the chin).
8. **The mouth image follows its box** (384 wide; 368 tall for his beard).
9. **Frames are extracted per track segment** (the first build's playback; the second build plays one still).
11. **A phone holds the mouth until the next starts** (Piper times P, B and M at 12-24 ms, under a frame);
    the five frames a mouth is averaged over weigh 1, 2, 3, 2, 1.
12. **A download that says nothing for five minutes is stopped and tried again**, and captions that could
    not be fetched never stop a video's words.
13. **The library on the Actor card is words:** the mouths by head turn and how many sounds were learned
    from captions.
14. **"+" grays a component whose card the note's panel would not show** (`Components.host_note`).

**Not built:** the disclosure line on a title card (the upload's description says it), the small deviations
(gaze, brows), and the capture session.
10. **The UI and the agents' rules say "the actor" and "they"**: the suite is for anyone, not one person.

**The goal.** An ASMR creator, Ephemeral Rift, asked for his likeness to read chapters of his upcoming book.
Ghost makes a video of him reading the note's words, in his own room, from his own footage. It is not
generative: every pixel of him is a real pixel from his videos, bent.

**What was ruled out, and why:**
- Generative video: this machine cannot do it, and a rented service is not wanted.
- A splat avatar through gsplat, FLAME, MHR, SAM 3D Body or Audio2Face: dependency hell (the head of splats
  that was built uses our own rasterizer and MediaPipe's mesh instead).

**Direction:** re-implementing a thing is easier and more reliable than wiring a dependency; keep MediaPipe;
a full-screen shader; the bulk of any change is small deviations from frame to frame, with the mouth tracking
the voice; Piper for the first build; a pipeline as a suite of tools, not a feature tailored to one person
(like the book: the Picture presents it, and the Illustrations card makes and manages the pictures).

## The method

1. **His real takes are the base of every frame** (first build; the second build uses one still). They hold
   his body, hands, hair, head turns and room.
2. **The mouth is replaced:** by real mouths from his footage, chosen by the shape the voice needs, warped
   into the take through MediaPipe's face mesh, blended by one fragment shader.
3. **The voice's phones drive the mouth shape.** Piper hands back every phone with its exact time.
4. **The takes are chosen and joined** where two frames nearly match (Video Textures, SIGGRAPH 2000); an
   agent picked his gestures to land on the right words (first build only).

**The precedent:** Mary101 (MIT, SIGGRAPH 2002) did the mouth this way from 8 minutes of video and 46 mouth
images, and viewers telling real from synthetic scored 52.1% and 46.6%: chance.

**No new dependency:** MediaPipe, OpenCV and numpy are in the face environment (`face_venv`); yt-dlp is in
the download environment (`ytdlp_venv`); FFmpeg is fetched; Piper is the voice; the agents are ghost's own;
the rest is GDScript and one canvas shader.

## What his footage is (looked at 2026-10-20)

A folder of 8 videos of his (25-92 minutes each, about 7 hours in all, 1920x1080 h264, all at 59.94 fps but
one at 30) from an earlier project, with 4 videos of other creators in the same folder.

**What the pipeline must handle,** because it is not the "same shot every time" assumed:
- Each video is edited: jump cuts, a few camera framings, and inserts such as a handheld close-up, or him in
  a hat outside.
- The camera is placed differently from video to video around the same desk.
- His look changes within a video (glasses on for the first minutes, then off).
- The light drifts: sunlight patches move across the wall over minutes.
- He talks with his hands constantly; a hand is often on his cheek or his head, and sometimes he holds a
  phone.
- He turns three-quarters toward his monitor often, reading.
- A large gray beard and mustache: the jaw line is hidden, and the lips are partly covered.
- A boom mic stands beside him.

So the unit of work is a set: the stretches of footage with one camera placement and one look, found
automatically and confirmed by an agent. Each set is a library of its own.

## The suite

Three parts, after the book's pattern: a library under both cards, a card that makes and manages, and a card
that presents (now one card, the Actor's).

### The library: `Actors` (`src/likeness/actors.gd`)

**An actor is a folder,** `user://actors/<id>/`, shared by every note that uses it, as `Illustrations` and
`Films` are. Its rules are the illustration library's:
- Nothing builds on its own: a button is the only caller, because the steps cost hours and the agents cost
  quota.
- Cached by fingerprint: each step's output records the fingerprints of its inputs, its settings and the
  script's version.
- Stale, not invalid: a changed input marks the output stale (⚠); it is still used until it is remade.
- The test seam: `use_for_test()` moves the root aside, so no gate writes the author's actors.

`actor.json`: the name, the sources (folders, links, and the videos found in each, each ticked or not), the
chosen set.

There is no consent rule in the app (trivial to circumvent, and the platform terms cover it): an upload
neither asks for a license on file nor refuses one; "Consent and disclosure" below is the advice.

### The Actor card (component `actor`): makes and manages

The card, top to bottom:
1. **The actor:** pick one from the library or make a new one, and its name.
2. **Sources:**
   - **Add folder…** A directory, read in place and never copied or written. Its videos are listed as rows,
     rescanned when the card opens.
   - **Add link…** A video, a playlist or a channel. `yt-dlp --flat-playlist -J` lists the entries first,
     so the rows appear at once with title, duration and thumbnail; each is then fetched as its own step,
     one at a time. Format `bv*[height<=1080][vcodec^=avc1]+ba[acodec^=mp4a]/b[height<=1080]`; captions
     `--write-auto-subs --sub-langs "en.*" --sub-format json3` (auto captions carry a time for every word);
     `--write-info-json`; `--download-archive` in the actor's folder, so re-adding a playlist fetches only
     what is new. Files land in `footage/`. The download environment, its Deno, and its one
     update-and-retry follow `MaskUrlImport`.
   - **"Captions only" on a link:** fetches no video, and matches each caption file to a folder video by
     title.
   - **A tick per video,** for whether it is used.
3. **Steps:** a row per step, in order (see The steps). Each row: ✓ when made, ⚠ when stale, a running share
   while it works, or what it waits for, and a short summary of what it made. ▶ makes that step and anything
   it needs. ⟳ redoes it: its output is deleted and remade, and what depends on it goes stale. A per-video
   step shows a count ("Survey 5/8").
4. **Generate** makes everything missing or stale, in order. **Stop** ends the running step, which resumes
   from its own last saved video or chunk.
5. **Sets:** a thumbnail and a sample frame for each, its minutes, its look in words (from the audit),
   whether it is built, and the one in use ("Use this set").
6. **The library:** the visemes' mouths, the count of mouths and motion.
7. **Who labels:** an `AgentPick` row. The job sends pictures, so the backend must see them
   (`Bedrock.sees_pictures` already gates this).
8. **Advanced** (folded): the step settings (see The defaults).

**The runner is `ActorBuilder` (`src/likeness/actor_builder.gd`),** shaped like `ProofProducer`: every `tick`
starts each step whose inputs exist and whose output is missing or stale (when Generate asked), and lands
what ended. One CPU step at a time (MediaPipe takes every core it is given) and one agent job at a time.
Python steps run through `Subprocess` (no shell), with `--progress <file>` polled as `face_track.py` is;
outputs are written to a temporary name and renamed into place. A step that waits (its environment is
installing) is not failed, and says for what.

### The Actor puts them on the stage (component `actor`, medium `likeness`)

One component: the Actor card builds and presents. It pins the medium while it is up
(`Director.medium_override = "likeness"`) and lets it go when it leaves.
- **It hands the reading how it goes out** (`ActorCard.Publish`): an export waits for the set in use to be
  built (saying what it still needs), the render's document carries `likeness` (the actor's folder, the set,
  its still, the seed: `ActorCard.document`) and an upload says whose likeness it is.
- **The performance is the note's:** the seed of which pieces of their motion play, when they blink and
  glance and when their posture shifts is drawn from the note's own file (`ActorCard.performance`), so a
  note always plays the same way and an export is what was watched.
- **The intro and outro fade them:** they rise across the whole intro (`ShowFeed.lead`: the take's own
  lead-in in a render, else the note's intro hold), arriving as the first word is said, as every picture does
  (`Director._bookend_fade`). They go down a beat after the last word and are black as the outro runs out
  (`ShowOpening.end_fade`, the desk's and the table's).
- **Gone:** `LikenessCard`, the `likeness` component and block (an older note's `likeness:` block is carried
  untouched and means nothing), `ActorFeed` and the reading's `feed()`. An Actor takes the presentation, so
  it cannot share a note with a Picture, a Table show or a lesson.

**The medium** is a row in `Medium.REGISTRY` (`res://src/likeness/likeness.gd`, frames `["landscape"]`, needs
`reading`). It renders as a pure function of show time (see Rendering).

**The component's row** (`src/notes/components.gd`): `actor` - family `picture`; needs `reading`; provides
`picture`; requires `voice`; slot `presentation`; capabilities `forward_plus`, `subprocess`, `ffmpeg`,
`python:face`, `python:speech`, `python:download`, `agent:writer`; block `actor` (its `id` and who labels);
script `res://src/likeness/actor_card.gd`. "+" Actor brings a Voice. The reading workspace's `hosts` holds
`actor`.

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
  sets/<set>/                the second build's per-set files: stills/, stills.json, rig, library/,
                             library.json, room, matte and avatar files
  visemes.json, motion.json  the actor's own: their range of mouth shapes, their motion
```

The track format (`survey.bin`): little-endian like `face_track.py`'s `GFT1`, with the magic `b"ACT1"`, a
version, the rate, the count, which fields are present, then the samples. The survey is about 1.5 KB a
sample, about 200 MB for 7 hours.

## The steps

All Python is one entry point, `hosts/face/actor.py <step> ...`, one subcommand per step, in `face_venv`.
Agent steps are `TextGen` jobs with pictures attached, like the art director's (`TableProducer`): the rules
are in `rules/likeness/*.yaml`, and the reply is JSON, parsed and checked, with a malformed reply retried
once.

| # | Step | Per | Runs | Reads | Writes | Cost (est.) |
|---|---|---|---|---|---|---|
| 1 | **fetch** | link video | yt-dlp | the link | `footage/` | download time |
| 2 | **probe** | video | ffprobe | the video | `probe.json` | seconds |
| 3 | **survey** | video | `actor.py survey` | the video | `survey.bin` | about 0.2-0.4x real time |
| 4 | **shots** | video | `actor.py shots` | `survey.bin`, the video | `shots.json` | seconds |
| 5 | **words** | video | GDScript | captions json3 | `words.json` | seconds |
| 6 | **sets** | actor | `actor.py sets` | every `shots.json` and `survey.bin` | `sets.json` | a minute |
| 7 | **audit** | actor | agent | `sets.json`, sheets | `audit.json` | 1 job per set |
| 8 | **track** | set | (first build; gone) | | | |
| 9 | **rig** | set | `actor.py rig` | the still, the canonical mesh | `rig.json` | seconds |
| 10 | **mouths** | set | (first build; replaced by `library`) | | | |
| 11 | **visemes** | actor | `actor.py visemes` | every survey | `visemes.json` | a minute |
| 12 | **takes** | set | (first build; gone) | | | |
| 13 | **gestures** | set | (first build; gone) | | | |

**Step by step:**

1. **fetch.** yt-dlp with the flags above, one video at a time. "Captions only" fetches nothing but the json3
   and matches it by title.
2. **probe.** ffprobe's duration, frame rate and size, and whether a captions file sits beside the video
   (`<name>.en*.json3`).
3. **survey.** Decodes with OpenCV, and runs MediaPipe's face landmarker (with blendshapes and the head's
   transform) and pose landmarker (with its segmentation mask) every 0.2 s. Keeps no 478 points: the survey
   is for finding things, not warping them. Passes a thread count, as `pose_track.py` does. It resumes by
   video: a stopped survey loses at most the video in hand.
4. **shots.** A cut is a jump in the thumbnails' difference that the samples on either side do not share. The
   exact frame is found by decoding the second around it. Shots under 3 s are dropped.
5. **words.** The json3 caption events are read into words with `t0` and `t1`. Auto captions give a time per
   word; a word's end is the next word's start, capped at 0.6 s.
6. **sets.** A shot's background is the median of its thumbnails where the person mask is clear. Shots are
   compared by their backgrounds' edge maps, not their colors, so the sun moving on the wall does not split
   a set while a moved camera does; the face box's size and place are compared too. Clustering is
   agglomerative, with a threshold. A set's usable minutes count the samples with one face found, and no
   wrist or index fingertip of the pose inside the lower half of the face box. Its sheet is 16 frames across
   its length.
7. **audit (agent).** One job per set with over 2 minutes usable. It is shown the set's sheet, plus a sheet
   for each of its shots (a 4x4 grid, near 1568x882). It writes the set's look in words (glasses, hat,
   clothes, the framing), whether every shot is the same person in the same look (a shot in another look is
   split off into its own set), and which stretches are usable and why any is not (an insert, a hand over the
   mouth, a phone in front of the face, leaving the frame, another person). Its words go on the card. The
   chosen set defaults to the one with the most usable minutes.
8. **track.** Gone with the first build.
9. **rig.** The mesh on the still: the canonical mesh's points with their UVs (the 10 iris points ride their
   eyes), two outer rings grown from the face oval's 36 points (1.35x over the hair and beard, 2x where any
   change has faded to nothing), anchors on the frame's edge, one triangulation over all of them, made once
   with OpenCV's `Subdiv2D` in the mean shape and fixed for the set.
10. **mouths.** Replaced by the second build's `library` (three prototype mouths a sound class, two half-shut
    and two shut eyes).
11. **visemes.** The actor's own: each sound class's mouth placed in their own range (see "Their own mouth,
    learned" in the third pass for why it is not learned from captions).
12. **takes.** Gone with the first build.
13. **gestures.** Gone with the first build. The agent rules carried no example names (examples get copied
    word for word).

## Rendering

**One mesh, drawn over the whole frame with a canvas shader** (the full-screen shader):
1. The mesh is the rig's triangulation. It reaches the frame's edges, so it covers every pixel.
2. Each vertex carries its position (the target point in output pixels), its base UV (where that point sits
   in the base frame) and its canonical UV (where it sits in the mouth library).
3. The GPU interpolates both UVs across each triangle, which is a piecewise affine warp, for nothing.
4. The fragment shader, for each pixel: the base frame at the base UV; inside the lower-face mask (sampled at
   the canonical UV, feathered there) up to 3 library mouths from a `Texture2DArray`, mixed by their weights,
   each color-matched first (its mean and spread matched to a ring of the base's own cheek and beard around
   it, so the drifting sun leaves no seam).

The layout coordinate rides in the vertex `COLOR` as a float (`warp_check` holds it). Everything stays in
sRGB: the frames are sRGB, and the shader blends them as they are; no 3D, no tonemapper, no compute.

**Determinism:** the output is a pure function of show time. The mouth weights at a frame are the mean of
the k-nearest weights over the 5 frames around it, all computed from the target shape, itself a function of
time. Never a filter with memory, or a seek and an export would differ.

## The lanes

All are functions of show time. Each plan is held as it is shown: a chunk's plan is fixed when the chunk's
phones land, as the desk holds its page (`DeskMedium.take_words`).

1. **The base.** The second build's one still (the first build's takes joined at their best joins, with
   gesture marks cutting to a gesture's take, are gone).
2. **The mouth.**
   - Piper's phones (`{p, t0, t1}` on every take, exact: they are the durations the synthesizer used) are
     mapped to viseme classes, and those to his viseme mouth shapes.
   - Coarticulation by dominance functions (Cohen and Massaro, 1993): each phone pulls toward its target with
     a falloff around its center, so an "m" closes the lips in fast speech while the vowels blend.
   - A target mouth becomes target lip and jaw points through the map in `visemes.json`, set into the base
     frame's own head pose; then the 3 nearest library mouths by key (the target blendshapes, the base
     frame's yaw and pitch, and its light); the base's own mouth and jaw are covered.
3. **Small deviations (later):** gaze and brows as landmark offsets.

**The viseme classes are a registry, rows not tables** (`src/likeness/visemes.gd`). About 14 classes:
silence; the consonants (P B M; F V; TH DH; T D N L; S Z; SH ZH CH JH; K G NG; R; W); the vowels (open AA AE
AH AY AW; mid EH EY ER; spread IH IY Y; rounded AO OW OY UW UH). Each row has a `label`, its phones, its
dominance (strength and falloff) and a `blurb`.

## The agents

Wired as everywhere else: `AgentPick` rows for who does each job, the words in `rules/likeness/*.yaml` (read
by `Rules`, checked by `rules_check`), and jobs on `AgentJobs`. No reasoning asked for (the
`reasoning_extraction` safeguard stops a run that asks) and no sample phrases in the rules.

| Job | Rules | Shown | Writes |
|---|---|---|---|
| Audit | `rules/likeness/audit.yaml` | the set's sheets | `audit.json` |
| At rest | `rules/likeness/rest.yaml` | the stills' sheets (and their hands' sheet) | `rest.json` |

## The voice

- Piper, through the Voice card, as any reading. The stand-in is the closest stock male voice in Piper's
  allowlist; the actor's own voice (see "Their own voice", and the Voice training card) replaces it.
- Phones ride with words: `ReadingJoin` carries each chunk's `phones` beside its `words`, shifted by the same
  spliced rests (`ReadingPlan.words_for`), into the take the medium reads.
- Later: a generative voice (VoxCPM2 with a LoRA on his reading) only has to hand back phones with times,
  from its own plan or an aligner. The picture does not change.

## Gates

Tests mirror `src/`, so each is under `tests/likeness/` unless named.

| Gate | Holds | Its control, which must fail |
|---|---|---|
| `actors_check.gd` | Through `Actors.use_for_test`: a step with a missing input waits; a changed input marks stale; ⟳ deletes and stales what depends on it; Generate's order; nothing written outside the test root | A step started without its input |
| `warp_check.gd` (GPU, `run_quiet.sh`) | A made base image with made landmarks, drawn with the target equal to the base, comes back within 1/255 | The target moved 2 px |
| `coarticulation_check.gd` | AA M AA closes the lips at M's center | M's dominance set to zero |
| `likeness_determinism_check.gd` (GPU) | Two renders of one moment hash the same | A seed changed |
| `hosts/face/test_actor.py` | Unwrap then rewarp on a made image within 1 px; one cut found in a fixture made by FFmpeg; seeded k-means repeats; two made backgrounds are two sets, and a bright patch moved across one keeps it one | A rewarp with the UVs swapped |
| existing: `components_check`, `rules_check`, `compile_check`, `docs.py --check` | the rows, rules and folder | - |

Fixtures are made, not found. MediaPipe on a real face is looked at in probes on his footage, never in a
gate: the footage is not in the repo.

## Build order

The first build's milestones (M1 to M8), each ending with something to look at: M1 the library and the
sources (`src/likeness/`, the Actor card, the component rows, gate `actors_check`); M2 survey, shots, words,
sets; M3 audit (correct the clustering's threshold against what is on screen); M4 the identity test (a frame
redrawn through its own mesh must be indistinguishable; another frame's mouth drawn into it: the first look
at the seam, the beard and the teeth); M5 the ceiling (his own tracked mouth drawn onto a different take with
his real audio under it, so any fault is the picture's); M6 the voice lane and the medium (visemes,
coarticulation, phones through `ReadingJoin`); M7 takes, joins, gestures and the director (removed in the
second build); M8 the proof (2-3 minutes of a chapter: Generate, then the export,
`likeness_determinism_check`). On long work, batch the changes and run `scripts/check.sh --for src/likeness`
once at the end of a milestone.

## The defaults

All are on the card's Advanced fold, so "Go!" needs no answers.

| Setting | Default | Why |
|---|---|---|
| Survey interval | 0.2 s | enough to find cuts and sets; full rate only where it is used |
| Output rate | 30 fps | ghost's export rate |
| Output size | the set's own, 1920x1080 | his frames as they are |
| Articulation | 2 | how far past their own range the mouth is pushed |
| Shortest shot | 3 s | jump cuts shorter than that are noise |
| Set to build | the most usable minutes | the audit can change it |
| Labeler | the `AgentPick` default | as elsewhere |
| Voice | the closest stock male Piper voice | a stand-in |

## Risks, and where each is seen first

1. **Teeth doubled in a blend.** Fewer mouths and sharper weights; at worst the single nearest mouth with a
   short cross-fade.
2. **A seam in the beard.** Color matching plus feathering; the beard's own texture hides more than skin
   would.
3. **His original speech in the base.** His cheeks and head move to words he said then; the second build's
   still has none of it.
4. **His hands near his face.** Stretches where the pose's hands are in the lower face are excluded, so the
   mouth is never drawn over a hand.
5. **Three-quarter turns toward the monitor.** The mouth key holds the head's yaw, and the set must hold
   mouths at those angles.
6. **Caption timing.** The visemes come from medians, so they are robust; the capture session's scripted
   viseme take fixes a wrong class.
7. **The light.** It drifts within a set: color matching for the mouths.

## Later, not in this build

- **His capture session,** shot for the purpose: a locked camera, one look, a scripted viseme take (each
  mouth shape held, spoken and whispered, with slow turns), 20-45 minutes of him reading chapters, his
  gestures each from rest to rest, and one passage filmed as the ground truth.
- **The generative voice:** VoxCPM2 with a LoRA on that reading, judged blind by him.
- **Small deviations:** gaze and brows.
- **A webcam performer** through the same MediaPipe.
- **The step up, if the warp's range is too small:** a splat avatar (built: "A head of splats").

## Consent and disclosure

- Every upload is already marked as synthetic media (`"containsSyntheticMedia": true`,
  `src/export/youtube.gd`).
- The disclosure: a line on the title card and in the description satisfies the EU AI Act's Article 50 for a
  creative work.
- If he enrolls in YouTube's likeness detection, agree in advance that he files no takedowns against these.
- The signed license should cover the uses (named specifically), his approval of each script and render, the
  term, revocation, who holds the actor's folder, deletion at the end, his estate, and pay and credit
  (California AB 2602 and 1836, New York GOL 5-302 and Tennessee's ELVIS Act are why).
- ACX/Audible reject AI narration.

## Sources

- **Mary101** (Ezzat, Geiger and Poggio, SIGGRAPH 2002): https://history.siggraph.org/?p=118425. The 8
  minutes, the 46 prototypes and the visual Turing test are from Ezzat's lecture:
  https://www.mit.edu/~9.520/spring08/Classes/tony_9520class08.pdf
- **Video Rewrite** (Bregler, Covell and Slaney, 1997): https://www.mit.edu/~9.520/spring09/Papers/VideoRewrite.pdf
- **Video Textures** (Schödl, Szeliski, Salesin and Essa, 2000):
  https://sites.cc.gatech.edu/gvu/perception/projects/videotexture/index.html
- **Coarticulation by dominance functions:** Cohen and Massaro, "Modeling coarticulation in synthetic visual
  speech", 1993.
- **MediaPipe:** the face landmarker: https://developers.google.com/edge/mediapipe/solutions/vision/face_landmarker;
  the canonical face mesh, with texture coordinates:
  https://github.com/google-ai-edge/mediapipe/tree/master/mediapipe/modules/face_geometry/data
- **yt-dlp's options:** https://github.com/yt-dlp/yt-dlp#usage-and-options
- **Consent:**
  - EU AI Act Article 50: https://artificialintelligenceact.eu/article/50/
  - California: https://perkinscoie.com/insights/update/single-day-california-enacts-five-bills-tackling-digital-replicas-and-deepfakes
  - New York: https://www.nysenate.gov/legislation/bills/2023/S7676
  - ACX: https://help.acx.com/s/article/acx-audio-submission-requirements
