# Likeness: the actor, generated, reading the note

Opened 2026-10-18 for the user's question. An actor wants a generative video of himself, driven by
the standard text pipeline. He is an ASMR creator, and he asked for this himself, for his upcoming
book launch: his AI likeness should read chapters of his book. His shot is always forward-facing,
centered, and in the same room.

The same day, the user set the direction after a first draft that re-rendered only the mouth over
his real footage:

- **The video is a novel performance.** "Between the hand movements and the head turns and such,
  I really think just changing the mouth is not going to have the effect we need." A completely
  novel video, or at the least the actor puppeted in his scene over his standard background.
- **The voice is truly generative.** "Piper voices sound robotic; they do not sound natural." It
  must speak with his inflection and cadence, not only his timbre.
- **The goal is a proof:** 2 to 3 minutes, not chapters. Praxis is off while it renders, so the
  whole GPU is the job's.

Every timing for this machine is an estimate scaled from measurements on other cards, marked
**(est.)**, until step 0 replaces it with a measurement.

## The verdict

**Yes, both, at 480p in an evening, with nothing trained.**
- **InfiniteTalk** makes him move from his voice alone: head turns, his gaze, his shoulders.
  150 s takes about 1.5-4 h (est.; budget 3 h).
- **Wan2.2-Animate** puppets him with a performer's real head and hand movement, over a real frame
  of his room. 150 s takes about 1-2 h (est.).
- **720p** takes about 4-11 h (est.), so it is an overnight run.
- **Completely novel shots** (a new place, a new angle) are possible too, but training his likeness
  into a model that can do them needs more memory than this machine has. That is a rented GPU for a
  few hours, a few dollars.

**The voice:**
- **VoxCPM2, fine-tuned on his recordings with a LoRA,** is the strongest commercially usable open
  model. Its Apache license allows the launch; training takes about 2-5 h on this card (est.).
- **Qwen3-TTS and CosyVoice3** are the runners-up.
- **ElevenLabs' Professional Voice Clone is the bar to measure against.** The open models a launch
  may use sit about 200 Elo under ElevenLabs on the public blind tests, so the actor's own ear
  decides whether open is good enough.

## The machine, with Praxis off

**The card:** an RTX 5060 Ti 16 GB, Blackwell (sm_120). With block swap, 16 GB of VRAM is enough
for every model below.

**The host:** an i7-4790K with 32 GB of DDR3 and PCIe 3.0 x8.
- **System RAM is the limit, not VRAM.** 32 GB is the most this board takes, so more RAM means a new
  platform.
- **Block swap over the gen-3 link is not the bottleneck:** about 6 minutes in the worst case for a
  whole take (est.).
- **Every successful 16 GB report found had 64 GB or more of RAM.** On 32 GB, two runs failed, and
  their failures set the rules:
  - A 2-minute InfiniteTalk run finished on 32 GB plus a pagefile, but one over 3 minutes crashed
    two hours in.
  - The final decode of a 3-minute take wanted over 120 GB.

**What follows from it:**
- **Render in segments of 30-45 s, cut at pauses,** and save each right after the sampler, with no
  previews.
- **Add a 32-64 GB swapfile on a real disk.** `/tmp` is a RAM disk, so not there.
- **Free the text encoder after it encodes.**

**The software that works on sm_120:**
- **Torch:** 2.9.1 with cu130 for ComfyUI-WanVideoWrapper; 2.10 with cu130 for Wan2GP. Avoid 2.8.0,
  which leaks RAM in Wan2GP.
- **SageAttention 2.2.0, built from source.** A plain `pip install` gives 1.0.6, which renders
  black.
- **Not SageAttention 3:** it gives mosaic artifacts on Wan and errors on a 5060 Ti.
- **No flash-attn and no xformers:** neither has a working sm_120 build, and neither is needed.

**The runtimes are ComfyUI with kijai's ComfyUI-WanVideoWrapper, or Wan2GP.** The official repos
load InfiniteTalk into 110-120 GB of RAM, and Wan2.2-S2V needs 80 GB of VRAM.

## The picture

### 1. From the voice alone: InfiniteTalk (the first proof)

InfiniteTalk (MeiGen; Apache code and weights) is an audio adapter on an unchanged Wan2.1-I2V-14B.
Given one frame of him and the voice, it makes him talk, with head motion, gaze and posture from
the audio. It uses its hands little.

**The recipe** (kijai's example workflow):
- **Models:**
  - Wan2.1-I2V-14B-480P in fp8_scaled, or GGUF Q6_K (14.2 GB) if RAM swaps;
  - the InfiniteTalk adapter at Q8 (2.65 GB);
  - umt5 in fp8 (6.74 GB), freed after it encodes;
  - clip_vision_h, chinese-wav2vec2-base, and the lightx2v LoRA.
  - Not FusionX, which costs identity and color.
- **Settings:** 6 steps (try 4), cfg 1, shift 11, window 81, motion_frame 9, 832x480, the long node's
  "infinitetalk" mode, and block swap 20-30, raised until it stops running out of memory.
- **The cost:** 150 s at 25 fps is 3,750 frames, or 53 windows of 72 new frames. The 3090 figure,
  "around half a minute per second of video", gives about 1.3 h. A measured 164 s per window gives
  2.4 h. A 4090 baseline scaled by SM count gives 3.5-5 h. So the estimate is 1.5-4 h at 480p
  (est.), and about 2.7x that at 720p.

**Long takes.** Identity holds "up to 1 minute. Beyond 1 minute, color shifts become more
pronounced." Segments of 30-45 s stay inside that. The color-match nodes help a little, but are
reported not to hold for "even a minute or two".

**Two ways to start a take:**
- **I2V from one sharp real frame of him in his room.** The maintainer's trick is to turn the still
  into a short fake video with a slight zoom, then run video-to-video.
- **Video-to-video over a real take of him sitting still.** The camera and layout stay "nearly the
  same", but the whole frame is regenerated. Away from him the room drifts 6-15 times the VAE's
  floor, and at `start_step` 3 objects appeared that were not there. So: composite the generated
  man over a clean plate of his room (see "Keeping his room" below).

**Silence is a hazard, and ASMR is full of it.** The face drifts during a trailing silence, and frame
jumps cluster where silence turns back into speech. Cut segments so each begins and ends on speech.
Where segments join on a long pause, which segment carries the pause is a test for step 0.

**Identity.** A Wan2.1-14B LoRA loads into InfiniteTalk (its README runs one). But no report found
says that a character LoRA improved identity there. So: no LoRA first, and judge 30 s with him.
Only then train one on a rented GPU (below).

### 2. A performer drives him: Wan2.2-Animate (the puppet)

Wan2.2-Animate-14B (Apache) moves a reference person with someone else's performance. A 512-pixel
crop of the driver's face becomes a latent injected every 5 layers, so the driver's expressions and
mouth carry over. Every 77-frame segment re-reads the reference image, which re-anchors identity.

**The puppet:**
- **The reference** is a real frame of him in his room.
- **The driver** is a performer filmed reading along to the generated voice: framed like him,
  centered, forward-facing, hands visible. The developer, or anyone of a similar build.
- **What the performer gives:** real head turns and real hand movement, timed to the words because
  they are reading them.
- **A lip pass tightens the mouth to the audio:** MuseTalk 1.5, whose weights are usable "for any
  purpose, even commercially", over the 480p result. It takes minutes. InfiniteTalk's
  video-to-video would regenerate the performance the puppet just gave.
- **Whispers matter less here.** The performer reads aloud, so the mouth is driven by a face, not by
  an audio encoder hearing a whisper.

**Two modes:**
- **Move:** the background comes from the reference frame, so it is his room, regenerated.
- **Mix (replacement):** only the masked person is generated, and the driver video's own pixels are
  kept outside the mask. Matte the performer onto a clean plate of his room first, then run Mix
  with its Relighting LoRA (trained on IC-Light composites). Mix does not retarget, so a performer
  of a different build deforms him. Move is the safer start.

**The cost:** 32 windows of about 4.8 s, at 4 steps with the lightx2v LoRA. The estimate is about
1.1 h at 480p (1.6 h at 6 steps) and 3.7 h at 720p (est.). It runs at 16 fps, so frame
interpolation (RIFE, MIT) brings it to 25 or 30.

**Weak spots:** fast hand movement leaves ghosting, so slow, deliberate hands (ASMR's own habit) are
the right brief for the performer.

**Licenses in the preprocessing:**
- The ComfyUI-native route uses DWPose (Apache).
- The official preprocessor uses YOLOv10, whose code is AGPL-3.0.
- Leave off the optional FLUX.1-Kontext-dev retargeting, which is non-commercial.

**Two to watch:**
- **SCAIL-2** (June 2026; Apache code, MIT weights). Animate and replace modes, a Relighting LoRA,
  and a DPO LoRA for hands, lips and eyes. About 1.9 h at 480p and 6.6 h at 720p (est.). Use its
  end-to-end SAM3 mode: its pose path uses NLF, whose weights are non-commercial.
- **Wan2.2-Animate-2** (2026-08-07; Apache). It reads the driving video directly with no extractors
  and has a 10-step distill. Wan2GP runs it with an NVFP4 option; replacement mode is not yet
  documented.

**Later: his own motion.** Pose tracks from his archive (ghost's `hosts/face/pose_track.py` already
makes them), with the face from a performer reading the new words. That would carry his own
mannerisms. ComfyUI feeds the pose and face videos in separately, so this is possible in
principle, and untested.

### 3. Completely novel shots: LTX-2.x with his LoRA

LTX-2.3 and 2.5 (Lightricks, 22B) generate video and sound together. They also take a GIVEN voice:
`A2VidPipelineTwoStage --audio-path` keeps the waveform unchanged, applies a `--lora`, takes image
conditioning, and runs long clips in 97-frame chunks with 25 carry frames. (The "Dub-It" IC-LoRA
cannot: it generates its own speech.)

**His likeness:**
- An **A2V LoRA** (the trainer's `a2v_lora.yaml`: 960x544x89, 2000 steps, the audio branch frozen),
  trained on his clips with his own speech. It should learn his gestures from his speech (est.).
- **The trainer recommends 80 GB; its low-VRAM config needs 32 GB.** So training is rented: an A100
  80 GB is $1.19-1.79 an hour, for a few hours (est.).

**The cost:** 2.5 ships an NVFP4 distilled checkpoint for Blackwell. Reports: a 10 s clip in under
5 minutes on an RTX 5070, and 20 s at 1080p fitting 16 GB. About 0.2-1.5 h for 150 s (est.). The
Gemma 12B text encoder and the 22B weights do not fit 32 GB together, so Gemma is unloaded after it
encodes.

**The license** (LTX-2 community license):
- free under $10M of annual revenue;
- anything published must say it is machine-generated;
- a deepfake is banned only "without consent";
- watermarks must not be removed.

**The route that trains here instead:** an image LoRA of him on an Apache image model, trained
locally on 16 GB (est.). The candidates are Z-Image, Qwen-Image, and FLUX.2 klein 4B (the 9B is
non-commercial). It makes new stills of him anywhere, and InfiniteTalk or Animate brings them to
life.

### Keeping his room

His camera never moves, so a clean plate of the empty room is the background, and the generated man
is composited over it. That holds the room perfectly still over minutes, which a regenerated
background cannot promise.

- **Commercially usable:**
  - **BackgroundMattingV2** (MIT), built for exactly this: a fixed camera with a clean plate;
  - BiRefNet including HR-matting (MIT);
  - BEN2 Base (MIT);
  - SAM 2 / 2.1 (Apache);
  - SAM 3 (the SAM License: commercial use allowed, military and ITAR uses barred);
  - Cutie (MIT).
- **Not commercially usable:** MatAnyone 1 and 2 (S-Lab), RMBG-2.0 (CC BY-NC), VideoMaMa. RVM is
  GPL-3.0, which covers the software, not the video.
- **The plate:** 10-20 s of the empty set, from him (below). Failing that, the median of frames in
  which he is out of a region, or an inpaint.

### The cost of 150 s on this machine

| Pipeline | Training | 480p (est.) | 720p (est.) |
|---|---|---|---|
| InfiniteTalk, 4-6 steps | none (a rented LoRA if identity is off) | 1.5-4 h | 4-11 h |
| Wan2.2-Animate, Move, 4 steps, plus a MuseTalk lip pass | none | 1.1-1.6 h | about 3.7 h |
| SCAIL-2, 8 steps | none | about 1.9 h | about 6.6 h |
| LTX-2.x A2V, distilled | rented, a few GPU-hours | 0.2-0.5 h | 0.6-1.5 h |
| LongCat-Video-Avatar 1.5 | Wan LoRAs do not load | 5-10 h | - |
| Wan2.2-S2V, 20 steps x 2 | Wan LoRAs show no effect | about 7.8 h | about 29 h |
| SoulX-FlashHead Lite | none | minutes ("teeth unclear"): a timing draft | - |

**At 720p, 3,750 decoded frames are about 41 GB in fp32.** So 720p is either segments of about 20 s
or less, or 480p upscaled. The upscaled route is not measured.

## The voice

**The honest gap.** On Artificial Analysis's blind tests (October 2026):
- ElevenLabs v4 leads, at 1328-1329.
- The open models above 1100 are all non-commercial (Fish, Breeze, Step Audio EditX, Voxtral).
- The usable ones sit near Chatterbox's 1026. On the cloned-voice board, Eleven v4 scores 1158 and
  Chatterbox 932.
- VoxCPM2, the open Qwen3-TTS and CosyVoice3 are not on either board.

**Our own blind A/B with him decides.** By objective scores (speaker similarity and word error rate
on Seed-TTS-eval English), VoxCPM2 leads: 75.3 / 1.84. Then MOSS 73.4, CosyVoice3 72.0, and
Qwen3-TTS 71.7, which has the lowest word error rate (1.23).

**Cadence takes a fine-tune.**
- Unsloth: zero-shot "captures general tone and timbre but misses pacing, phrasing"; fine-tuning
  reproduces delivery.
- The Qwen3-TTS paper: in-context cloning (a reference clip plus its transcript) "better preserves
  prosody" than a speaker embedding, and a single-speaker fine-tune "transfers the target speaker's
  timbre and prosody".

**The three, in order:**

1. **VoxCPM2** (2B, Apache, April 2026)
   - *Training:* the official LoRA at rank 64, alpha 64-128, on both the LM and the DiT, learning
     rate 1e-4. 50-500 clips is its "style adaptation" range, the one for cadence. 1-3 epochs, with
     every save checked: it can start to ignore the text within a few hundred steps.
   - *Memory:* the official figure is about 20 GB at batch 16. Batch 4-6 with gradient accumulation,
     and `max_batch_tokens` near 4096, should fit 16 GB (est.). VoxCPM1.5's LoRA fits at about
     12 GB as a fallback.
   - *Time:* about 2-5 h on 600-900 clips (est.).
   - *Reading:* "Ultimate cloning" continues straight on from a reference clip and its transcript,
     and output is 48 kHz.
2. **Qwen3-TTS 1.7B Base** (Apache). The best long-passage robustness found: English word error
   rate 2.81 on 200-2000-word texts.
   - *Training:* the official single-speaker script trains the whole model in bf16 with plain AdamW:
     batch 1-2 or an 8-bit optimizer (est.), learning rate 2e-5, 3-5 epochs.
   - *A known bug:* FlashAttention-2 gives NaN losses past 8192 frames, so the code predictor runs on
     eager attention.
   - *Time:* about 2-4 h (est.). Start on 0.6B if 1.7B does not fit.
3. **Fun-CosyVoice3-0.5B** (Apache). Small enough to fine-tune whole, and it has a `[breath]` tag. A
   2026 paper fine-tuned it on real whispers to a whisper MOS of 4.53, above real recordings' 4.33.
   - *Its cost:* lower speaker similarity than the two above, and it pins torch 2.3, which has to be
     re-pinned for sm_120.

**Not usable:**
- Non-commercial: F5-TTS, Fish S1/S2, Spark, Llasa, Dia and VibeVoice.
- Step-Audio-EditX: its weights carry no license.
- Maya1: no cloning.
- Orpheus: Llama 3.2 terms.
- MOSS-TTS 8B: too big for this card.

**Higgs TTS 3 zero-shot is an option:** its Creator Use Grant covers monetized videos and audiobooks
"published on channels the creator owns or controls", with credit. Fine-tuned derivatives are
non-commercial, though.

**Whispers.** No commercially usable open model has a working whisper control together with
cloning. The control is the data: a whispered prompt, and whispered training clips. Expect long
passages to drift toward a voiced voice, and test for it.

**Long passages:** one paragraph at a time, each passing the previous paragraph's audio as its
continuation prompt (VoxCPM2; untested). Sesame CSM-1B (Apache) conditions on earlier turns by
design, so it is the alternate if cadence breaks between paragraphs.

**Word timings for the subtitles:** the text is known, so it is aligned, not transcribed. The tool
is Qwen3-ForcedAligner-0.6B (Apache), which aligns words up to 5 minutes with 37.5 ms of English
error, against WhisperX's 92.1.

**His training audio** (Emilia-Pipe, adapted):
- Silero VAD into 3-30 s clips, and music removed only where there is music.
- **Hand-checked clips, not a DNSMOS cutoff:** DNSMOS and VAD reject whispers. Then a filter by
  speaker similarity to a centroid built from those clips.
- **Exact transcripts**, "uhm" included.
- **His breaths kept, the deliberate triggers (mouth sounds) cut,** or the model learns them.
- **One delivery throughout.**
- **45-90 minutes of narration-like speech.** Best of all is him reading other chapters of the book
  in his ASMR setup.

**The hosted bar: ElevenLabs Professional Voice Clone on Eleven v4.**
- *Training:* 30 min to 3 h of audio in one style; it trains in 3-24 h.
- *Reading:* 10,000 characters a request, so a passage is one call. `[whispers]` is reliable when
  whispers are in the training audio.
- *Who makes it:* **he must create and verify the clone on his own account**, then share it.

## Ask him for a capture session

He is cooperating, so the data can be shot for the purpose. The library comes first, for the
zero-shot tests, since it is free. The session is what turns the proof into him:

1. **A consent statement on camera, and the signed license** (see Consent).
2. **10-20 minutes in his setup, with variety:** head turns, expressions, slow hand movement,
   reading, and talking. These give the reference frames, the stills for an identity LoRA, and the
   clips for an LTX A2V LoRA.
3. **A clean plate:** 10-20 s of the empty set, with the same camera, exposure and light.
4. **45-90 minutes of him reading other chapters aloud** in the delivery the AI should have, on his
   usual microphone, with no music and no triggers. A known text means exact transcripts.
5. **One real passage, filmed: the ground truth.** The proof is judged next to it, in a blind A/B
   for the voice and side by side for the picture.

## How it sits in ghost (after the proof)

The proof needs none of this. Steps 0-6 run by hand in `dist/likeness_spike/` (with a
`.gdignore`). What follows is the shape the component takes if the proof convinces.

- **The component is Likeness.** Its row:
  - family `picture`, provides `picture`, requires `voice`;
  - fills the `presentation` slot (the likeness is what the show is carried on);
  - capabilities include a new `gpu:nvidia`, impossible on a phone and not ready without an NVIDIA
    card, with the reason.
- **The actor is a library thing,** kept in `user://actors/<id>/`:
  - `actor.json`: his name, the license file, the sources, and every trained model with what it was
    trained from;
  - the voice LoRA and its dataset;
  - the reference frames and the clean plate;
  - any picture LoRAs.
  - No training job starts without the license file in `actor.json`.
- **The voice is a new backend** in `hosts/voice/backends/` (the registry the Kokoro plan named),
  on the GPU, in an environment of its own. Piper's graph patches (`dur_scale`, `rest_floor`) do not
  carry over. Its word timings come from the forced aligner.
- **The picture is a render job,** run by a host that drives a headless ComfyUI (a saved workflow
  posted to its HTTP API) or Wan2GP's command line. That host is fetched and pinned by ghost, like
  every other dependency, along with its model files: about 25-30 GB for a route.
- **The jobs:**
  - **Segmented at pauses, and cached by fingerprint:** the audio segment, the reference, the
    settings and the model versions. Editing a sentence re-renders its segment.
  - **One GPU job at a time, resumable after a quit.**
- **The medium** shows the rendered frame for each moment of show time (Films' virtual clock), and
  the export bakes what is missing first.
- **This breaks the 2026-10-05 rule** against heavy local models. The containment proposed: it is
  opt-in, it renders at bake time only, and nothing else requires it. The other choice is a tool
  beside the app that writes the actor's folder, which ghost then reads.

## Consent and disclosure

- **Already done in code:** ghost marks every upload as synthetic media
  (`"containsSyntheticMedia": true`, `src/export/youtube.gd:991`), YouTube's "altered or synthetic
  content" flag.
- **The LTX license requires saying an LTX video is machine-generated,** and the EU AI Act's
  Article 50 has applied since 2026-08-02. It reaches a US creator's video watched in the EU. For a
  creative work, it is satisfied by a mention "that does not hamper the display or enjoyment of the
  work": a line on the title card and in the description. A C2PA manifest on the export is later.
- **YouTube likeness detection** has been open to every creator since 2026-05-17. If he enrolls,
  these uploads will match, so agree in advance that he will not file takedowns against them.
- **The written license should cover:**
  - the uses, named specifically;
  - his approval of each script and each render;
  - a fixed term, worldwide;
  - revocation going forward, with a takedown deadline;
  - **who owns the trained LoRAs and voice;**
  - deletion of the data and models at the end, certified;
  - the disclosure commitments;
  - what his estate controls;
  - his own counsel;
  - pay and credit.
- **Why each part:**
  - California AB 2602 and New York GOL 5-302 require the uses to be described with reasonable
    specificity, or counsel.
  - The Tennessee ELVIS Act covers voice.
  - California AB 1836 hands consent to his estate.
- **Renting a bare GPU keeps his footage private;** hosted trainers have rules of their own about
  real people.
- **ACX/Audible reject AI narration.** Google Play Books and Spotify accept a labeled digital voice.

## The plan for the proof, in order

0. **Set up.**
   - A 32-64 GB swapfile on a real disk.
   - ComfyUI with WanVideoWrapper, on torch 2.9.1+cu130, with SageAttention 2.2.0 from source, in
     `dist/likeness_spike/`.
   - Wan2GP beside it as the second runtime.
   - The model files for InfiniteTalk and Animate.
1. **The voice, zero-shot.** One 350-word passage from three whispered reference clips of 20-30 s,
   with exact transcripts, on:
   - VoxCPM2 "Ultimate cloning";
   - Qwen3-TTS in-context;
   - CosyVoice3 zero-shot;
   - Chatterbox;
   - Eleven v4 Instant Voice Clone as the control.

   **A blind A/B with him.** Score whether the whisper holds to the end, where his pauses fall, and
   the timing (with the aligner).
2. **The picture, zero-shot, InfiniteTalk.** 30 s, driven first by his REAL audio from another video,
   so that voice faults and picture faults are told apart; then by the best voice from step 1. Run
   both I2V from a sharp frame and video-to-video over a still take. Measure the time per window,
   VRAM and RAM. Look at it with him.
3. **The puppet, Animate.** The same 30 s, Move mode, the developer performing it, then the MuseTalk
   lip pass. Side by side with step 2.
4. **The voice, fine-tuned.** The step-1 winner, with a LoRA on 45-90 minutes of his audio; a blind
   A/B against its zero-shot self.
5. **Identity, only if it is off.** A rented Wan2.1-14B LoRA (musubi-tuner, on a host with 64 GB of
   RAM or more). Its training material is 30-60 varied stills plus 10-20 short clips at about
   480x272, rank 16-32, 1,500-3,000 steps: est. 2-6 h and $1-10. Then a 20 s A/B.
6. **The 2-3 minute proof.** The better of steps 2 and 3, at 480p:
   - in segments of 30-45 s cut at pauses;
   - composited over the clean plate if the room moves;
   - then 720p overnight, or 480p upscaled.
7. **Optional: novel shots.** LTX-2.x A2V with a rented A2V LoRA, for a few seconds of him somewhere
   new.

Each step replaces this note's estimates with measurements.

## For the user to decide

1. **The first picture:** from the voice alone (InfiniteTalk, no performer) or a puppet (Animate,
   with a performer). Both are cheap at 480p, so steps 2 and 3 run both.
2. **Who performs** for the puppet: the developer, or someone of his build.
3. **Renting** for the training this machine cannot do: an identity LoRA, an LTX A2V LoRA.
4. **ElevenLabs as the voice's bar** (he makes the clone himself), and whether a hosted voice is
   acceptable for the launch if it wins.
5. **The runtime ghost drives later:** ComfyUI or Wan2GP.
6. **The name** (Likeness?), and in ghost or beside it.
7. **About him:**
   - a beard or a mustache;
   - the microphone in the shot;
   - his hands near his face;
   - whispered or soft spoken for the book;
   - the resolution he posts at.

## Sources

The machine and the runtimes:
- InfiniteTalk timings and RAM: https://github.com/MeiGen-AI/InfiniteTalk/issues/210,
  https://github.com/MeiGen-AI/InfiniteTalk/issues/14, https://github.com/MeiGen-AI/InfiniteTalk/issues/71
- WanVideoWrapper runs on 16 GB and 32 GB:
  https://github.com/kijai/ComfyUI-WanVideoWrapper/issues/1185,
  https://github.com/kijai/ComfyUI-WanVideoWrapper/issues/1088,
  https://github.com/kijai/ComfyUI-WanVideoWrapper/issues/1805,
  https://github.com/kijai/ComfyUI-WanVideoWrapper/issues/371
- Wan2GP on 32 GB: https://github.com/deepbeepmeep/Wan2GP/issues/1183,
  https://raw.githubusercontent.com/deepbeepmeep/Wan2GP/main/docs/INSTALLATION.md
- SageAttention on sm_120: https://github.com/thu-ml/SageAttention,
  https://github.com/thu-ml/SageAttention/issues/357,
  https://github.com/kijai/ComfyUI-WanVideoWrapper/issues/1875,
  https://github.com/Comfy-Org/ComfyUI/discussions/11583
- flash-attn on sm_120: https://github.com/Dao-AILab/flash-attention/issues/2361
- The 4790K's memory limit:
  https://www.intel.com/content/www/us/en/products/sku/80807/intel-core-i74790k-processor-8m-cache-up-to-4-40-ghz/specifications.html

InfiniteTalk:
- https://github.com/MeiGen-AI/InfiniteTalk (long takes, LoRAs, FusionX); model files
  https://huggingface.co/Kijai/WanVideo_comfy_GGUF/tree/main/InfiniteTalk,
  https://huggingface.co/city96/Wan2.1-I2V-14B-480P-gguf/tree/main
- The still-to-video trick: https://github.com/MeiGen-AI/InfiniteTalk/issues/10; silence:
  https://github.com/MeiGen-AI/InfiniteTalk/issues/146, https://github.com/MeiGen-AI/InfiniteTalk/issues/6
- Video-to-video drift: https://github.com/kijai/ComfyUI-WanVideoWrapper/issues/2048; color over
  minutes: https://github.com/kijai/ComfyUI-WanVideoWrapper/issues/1941
- The example workflows: https://github.com/kijai/ComfyUI-WanVideoWrapper/tree/main/example_workflows

The puppet:
- Wan2.2-Animate: https://huggingface.co/Wan-AI/Wan2.2-Animate-14B, https://arxiv.org/html/2509.14055,
  https://docs.comfy.org/tutorials/video/wan/wan2-2-animate,
  https://github.com/Wan-Video/Wan2.2/blob/main/wan/modules/animate/preprocess/UserGuider.md
- Wan2.2-Animate-2: https://huggingface.co/Wan-AI/Wan2.2-Animate-2-14B; SCAIL-2:
  https://github.com/zai-org/SCAIL-2; NLF's license: https://github.com/isarandi/nlf
- MuseTalk: https://github.com/TMElyralab/MuseTalk; DWPose: https://github.com/IDEA-Research/DWPose;
  YOLOv10: https://github.com/THU-MIG/yolov10
- Hand ghosting: https://medium.com/@302.AI/wan2-2-animate-model-test-with-4-cases-e9e1c1ef492c

Novel shots:
- LTX-2: https://github.com/Lightricks/LTX-2/blob/main/packages/ltx-pipelines/docs/pipelines.md,
  the A2V trainer config
  https://raw.githubusercontent.com/Lightricks/LTX-2/main/packages/ltx-trainer/configs/a2v_lora.yaml,
  the trainer https://github.com/Lightricks/LTX-2/blob/main/packages/ltx-trainer/README.md, the license
  https://github.com/Lightricks/LTX-2/blob/main/LICENSE-2_x, 2.5 https://huggingface.co/Lightricks/LTX-2.5
- Image models for an identity LoRA: https://huggingface.co/Tongyi-MAI/Z-Image,
  https://huggingface.co/Qwen/Qwen-Image, https://huggingface.co/black-forest-labs/FLUX.2-klein-4B
- musubi-tuner: https://github.com/kohya-ss/musubi-tuner,
  https://github.com/kohya-ss/musubi-tuner/issues/489,
  https://civarchive.com/models/1971596/wan22-16gb-training
- LongCat-Video-Avatar: https://huggingface.co/meituan-longcat/LongCat-Video-Avatar-1.5; Wan LoRAs
  in it https://github.com/kijai/ComfyUI-WanVideoWrapper/issues/1570
- S2V: https://docs.comfy.org/tutorials/video/wan/wan2-2-s2v,
  https://github.com/kijai/ComfyUI-WanVideoWrapper/issues/1109
- SoulX-FlashHead: https://github.com/Soul-AILab/SoulX-FlashHead/issues/18

Keeping his room:
- BackgroundMattingV2: https://github.com/PeterL1n/BackgroundMattingV2; BiRefNet:
  https://github.com/ZhengPeng7/BiRefNet; BEN2: https://huggingface.co/PramaLLC/BEN2
- SAM 2: https://github.com/facebookresearch/sam2; SAM 3's license:
  https://github.com/facebookresearch/sam3/blob/main/LICENSE
- MatAnyone's license: https://raw.githubusercontent.com/pq-yang/MatAnyone/main/LICENSE; RMBG-2.0:
  https://huggingface.co/briaai/RMBG-2.0

The voice:
- The boards: https://artificialanalysis.ai/text-to-speech/leaderboard,
  https://artificialanalysis.ai/text-to-speech/leaderboard/controlled-voice
- Fine-tuning for cadence: https://unsloth.ai/docs/basics/text-to-speech-tts-fine-tuning; the
  Qwen3-TTS paper https://arxiv.org/html/2601.15621v1
- VoxCPM2: https://github.com/OpenBMB/VoxCPM, https://huggingface.co/openbmb/VoxCPM2, its fine-tune
  guide https://voxcpm.readthedocs.io/en/latest/finetuning/finetune.html and FAQ
  https://voxcpm.readthedocs.io/en/latest/finetuning/faq.html
- Qwen3-TTS: https://github.com/QwenLM/Qwen3-TTS/tree/main/finetuning; the NaN bug
  https://huggingface.co/Qwen/Qwen3-TTS-12Hz-1.7B-Base/discussions/18
- CosyVoice3: https://github.com/FunAudioLLM/CosyVoice; whispers: https://arxiv.org/html/2603.14853v1
- CSM-1B: https://huggingface.co/sesame/csm-1b; Higgs TTS 3's license:
  https://huggingface.co/bosonai/higgs-tts-3-4b/blob/main/LICENSE
- The aligner: https://github.com/QwenLM/Qwen3-ASR; Emilia-Pipe:
  https://github.com/open-mmlab/Amphion/tree/main/preprocessors/Emilia
- ElevenLabs: https://elevenlabs.io/blog/eleven-v4,
  https://elevenlabs.io/docs/product-guides/voices/voice-cloning/professional-voice-cloning,
  https://elevenlabs.io/docs/help-center/product/voices/voice-cloning/can-i-create-a-professional-voice-clone-of-someone-elses-voice.md

Renting: https://www.runpod.io/pricing

Consent and disclosure:
- YouTube: https://support.google.com/youtube/answer/14328491,
  https://developers.google.com/youtube/v3/revision_history, likeness detection
  https://www.androidauthority.com/youtube-likeness-detection-expansion-3667840/
- The EU AI Act: https://artificialintelligenceact.eu/article/50/, https://artificialintelligenceact.eu/article/2/
- California: https://perkinscoie.com/insights/update/single-day-california-enacts-five-bills-tackling-digital-replicas-and-deepfakes;
  New York: https://www.nysenate.gov/legislation/bills/2023/S7676
- ACX: https://help.acx.com/s/article/acx-audio-submission-requirements
