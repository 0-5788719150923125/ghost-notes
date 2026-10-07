# The neural voice: what the clicks are, what Piper gives us, and what could replace it

Started 2026-10-07, from the question "is our chunking breaking the phonetics, and are we using
Piper's own controls at all?" Measured on the Cards reading `truthful-tarot`, episode 81051, at the
note's own voice settings (Narrator: en_US-libritts-high speaker 13, Dreamy, pace 1.15, Pause 6.5).
The probes and the listening files are in `dist/voice_ab/` (gitignored); `probes/` holds every
script named below.

## How a reading was made (before the changes below)

- **There is no sliding window.** `ReadingPanel` sends one sentence per request
  (`CHUNK_SENTENCES = 1`); the host renders it in ONE ONNX call, commas and all, so the phonetics
  inside a sentence are whole. VITS has no memory between calls, and Piper's own CLI also splits on
  sentences. What a sentence cannot know is where it sits in its paragraph - `_discourse_plan`
  (paratone, final lengthening, effort) is the answer to that.
- **Piper's three scales are used on every request.** `scales = [noise_scale, length_scale,
  noise_w]` is the whole of Piper's inference interface (plus `sid` for a multi-speaker voice). The
  Tone presets set all three, delivery leans move `noise_scale` and `length_scale`, and the
  discourse plan moves `length_scale` and `noise_w` per sentence.
- **One more native control exists, because we patched it in:** `rest_floor`, a per-id frame
  floor after the duration predictor's Ceil (`_ensure_patched`). It is how a comma gets a rest the
  model renders itself.
- **Post-generation, because no Piper input reaches it:** pitch (render slower, resample faster,
  `_restore_formants`), effort tilt, whisper, muffle, the pause top-up (`_splice_pauses`, digital
  silence), rest trimming (`_trim_rests`), the editor's Tone resample, hesitations and the room.

## What was measured

| Question | Probe | Result |
|---|---|---|
| Does the host's post-processing add transients? | `stage_spy.py` (audio kept after every stage) | No. 36 click-like events in the model's own output, 33 after the last stage (40 sentences, 94 s). |
| Does the formant restore pre-echo onsets? | `restore_probe.py` | No. +0.3 dB median in the 30 ms before an onset (90th percentile +1.1). |
| Does `noise_scale` drive the events? | `event_words.py`, 3 renders each | No. 16.9 / 19.4 / 20.0 / 17.5 per minute at 0.78 / 0.667 / 0.5 / 0.33. |
| Where do the events fall? | `edge_offsets.py`, `rest_clicks.py` (duration plan) | Inside words at stops (/p/ /k/ /t/), plus word-final releases before a rest ("out", "that,", "not."). 1 in 111 s inside a pause. Not mouth clicks. |
| Are chunk joins a step? | `voice_ab.py` | No. Every chunk starts and ends about 55 dB under its peak, with a 1.67 s seam between them at Pause 6.5, so a crossfade has nothing to cross. |
| Native rests vs splicing | `native_ab.py` (seeded, see below) | Native: the model renders the whole comma rest (`rest_floor` = the target), unplanned rests capped in the plan (`dur_cap`), nothing cut. Same total length (85.7 s vs 84.9 s); 13.2 s of digital silence becomes 0 s of it, the room tone runs on. |
| Are onsets after a rest abrupt? | `onsets.py` | No. Median 10-90% attack 27-29 ms after a comma, at a sentence start and mid-sentence alike. |
| Are sentence-initial words clipped? | `onsets.py`, `first_word.py` | **Yes.** The first word of a sentence is short: "A" 12 ms, "If" / "It" / "The" 46 ms. A vowel floor of 5 frames on the first word (`rest_floor` again) gives 58 / 93 / 93 / 81 ms. Known for this checkpoint ([piper #296](https://github.com/rhasspy/piper/issues/296)). |

**Seeded renders.** Piper's two `RandomNormalLike` nodes take a `seed` attribute; with it set
(a copy of the voice in `dist/voice_ab/xdg_det/`) a FRESH session renders the same performance
every time, so an A/B differs only in what is being compared. One session renders differently on
each call - a fresh session per render is the price.

**Not yet known: which sound the user hears.** No detector separates a click a listener objects to
from a /k/. The clipped first word is the strongest candidate for "the start of a sentence"; for
"around commas" the candidates are a word-final release left standing in a long rest, and the
switch from the model's room tone (about -45 to -50 dB) to digital silence and back.

Listening files (`dist/voice_ab/listen/`, the opening 30 sentences, the Tone resample and seams
applied, no room or presence):

1. `1_current.wav` - the shipped pipeline.
2. `2_native_rests.wav` - the same seeded performance, every rest rendered by the model.
3. `3_first_word_model.wav` / `4_first_word_floored.wav` - 14 sentences, the model's first word
   against a 5-frame vowel floor on it.

## Built (2026-10-07): the duration plan steered, and the resample fixed

Pitch has no input in a VITS graph, but DURATION does, per phoneme id, between the predictor and
the decoder. Status: built, gated, waiting on the user's ear (`5_before.wav` against
`6_after.wav`, and `7_stress_plain_then_marked.wav`).

- **`dur_scale`** - a second patched input beside `rest_floor`, a per-id multiplier on the
  planned frames AFTER the Ceil and before the floor. Before the Ceil it did almost nothing:
  most of a syllable's ids are predicted under one frame, and `ceil(d * 1.3)` lands back on the
  same frame (a stressed word moved 0-30 ms). `_ensure_patched` adds each input on its own, so a
  voice patched before this gains it on its next load and keeps its floor.
- **Stress** - `*word*` and `**word**` are SPOKEN now, not only drawn: the token carries `emph`,
  the host holds the word's stressed SYLLABLE 1.3x / 1.5x through `dur_scale` - the stress mark,
  the vowel and the blanks inside and after it, because Piper spreads a syllable's time over
  all of them ("officially": ˈ:4 ·:2 ɪ:1 ·:2) - and lifts the word 1.5 / 3 dB (`EMPHASIS`,
  `_emphasize`). Measured on six words of the Cards reading: +17-31 ms italic, +28-55 ms bold.
  Pitch, the strongest cue of stress, is not in it yet (see below). A run of more than `STRESS_RUN_MAX` (3) emphasized
  words is typography (an italic paragraph is a change of time or place) and is sent plain. The
  Cards reader is told what an asterisk does now (`CardPrompts.SPOKEN_RULES`).
- **The opening vowel** - the first word's vowel may not fall below `OPENING_VOWEL` (50 ms at
  the request's length scale), through `rest_floor`. A floor, so a first word the model already
  gave its length is untouched.
- **Band-limited resampling** - `_resample` is a Kaiser-windowed sinc (polyphase, 32 taps,
  4096 phases) where both pitch moves used linear interpolation. Linear left images at -27 dB by
  4 kHz and -14 dB by 8 kHz at Dreamy's +1.5 semitones; this holds every spur under -80 dB.
  0.14 s per 10 s of audio.
- **The Tone is played back in the host** (`play_ratio` in the request), through that
  resampler, with every returned time already in the played audio's seconds. The editor's
  linear `_resample` is gone; `_drain_ready`, the audition and the export apply no ratio.

Gates: `hosts/voice/test_expression.py` (new: stress, the opening floor, the gain, the playback,
the resampler against the linear control, an old patch upgraded), `test_pauses.py` (the floor
check and the patch check say what they hold now), `tests/multi_voice_check.gd`
(`_check_stress_reaches_the_voice`, and `play_ratio` in `_check_settings_reach_the_request`).

## Still proposed

1. **Rests rendered, not spliced** - the comma rest whole from `rest_floor`, no digital silence
   (`2_native_rests.wav`). Needs the ear first.
2. **Final lengthening where it belongs** - on the last word or two before a boundary
   (`dur_scale`), instead of slowing the whole sentence as `_discourse_plan` does now.
3. **`dur_cap`** - a per-id ceiling after the floor, so the bimodal blank `_trim_rests` cuts out
   is capped before the audio exists.
4. **A pitch accent on a stressed word** - the one cue of stress this graph cannot render. A
   local resample around the word, formant-locked, would be the way.

## Agents: more granular control

Today an agent has `<!-- delivery: ... -->` (four axes, two steps, per paragraph, eased over
sentences), `<!-- hesitation -->`, and now a word's stress by asterisks. Next, all on the
duration plan:

- a drawn-out word (`Sooo`, "Ooh") as a duration on that word,
- `quicker` / `slower` scoped to a clause rather than a paragraph.

Not a per-sentence Tone or raw `noise_scale`: the presets are a person, and the rules say the
show's voice is fixed.

## Ideas weighed and set aside

- **A crossfade between chunks** - the joins are already at the noise floor with seconds of
  silence between them (see the table).
- **Blending several takes** - waveforms whose phases do not agree average into a chorus. The
  version that works is best-of-N: render a sentence two or three times (`noise_w` and the seed
  vary) and keep the one with the fewest artifacts by a score. That costs 2-3x synthesis, which
  suits an export better than live reading.

## Other engines (surveyed 2026-10-07; licenses checked on the model cards)

**Piper.** Nothing beats en_US-libritts-high and is commercially clean. Clean single-speaker
"high" voices that would drop into this pipeline: `en_US-ljspeech-high` (public domain) and
`en_GB-cori-high` (public domain). `rhasspy/piper-checkpoints` publishes `ljspeech-2000.ckpt`,
the only clean high-quality base to fine-tune from (onto Hi-Fi TTS or LibriTTS-R speakers,
CC BY 4.0). Lessac-derived (never usable): libritts_r, joe, mike, amy, alba, vctk, aru, sam,
jenny_dioco. Every `*-low` voice is ryan-derived (CC BY-NC-SA).

**Phoneme-driven alternatives.**

- **Kokoro-82M** (Apache-2.0 code and weights, 24 kHz, ONNX, about real time on a weak CPU) - takes
  phonemes (misaki's set; our IPA maps onto it), returns per-token durations, takes a duration
  override and a style vector (voices blend by averaging). Its decoder is fed an explicit
  frame-level F0 curve and an energy curve: split the graph and pitch becomes an INPUT, which
  would retire the resample-and-restore DSP. Caveat: its training data includes synthetic audio
  from commercial providers - a provenance question for Steam.
- **NeMo FastPitch + HiFi-GAN** (CC-BY-4.0) - a per-token pitch input and duration and pitch
  outputs, out of the box. One LJSpeech voice, older and plainer than Kokoro.
- Matcha-TTS, MeloTTS and Kitten TTS take phonemes but add no pitch control; StyleTTS2's weights
  require telling listeners the speech is synthetic.

**Generative models.** None takes a duration plan or a pitch contour; their "emotion" is a global
vector or a tag, and most need a GPU. The only small one that is commercially usable is
Chatterbox-Nano (110M, MIT, CPU, an `exaggeration` dial, watermarked, no timings). Pocket TTS
(100M) is CC-BY-4.0, gated, cloning only. Non-commercial and excluded: F5-TTS, Spark-TTS, Llasa,
MaskGCT, OpenAudio S1. The worry that these are hard to steer is borne out.

**Order:** the duration plan in Piper first - begun, see "Built" above; then a Kokoro prototype
behind the backend registry (`hosts/voice/backends/`), whose explicit F0 input is the one thing
Piper cannot have.
