# The neural voice: what the clicks are, what Piper gives us, and what could replace it

The question: is our chunking breaking the phonetics, and are we using Piper's own controls at all?
Measured on a Cards reading at the note's own voice settings (en_US-libritts-high speaker 13, pace 1.15,
Pause 6.5). The probes and the listening files are in `dist/voice_ab/` (gitignored); `probes/` holds every
script named below.

## How a reading was made (before the changes below)

- **There is no sliding window.** `ReadingPanel` sends one sentence per request (`CHUNK_SENTENCES = 1`); the
  host renders it in one ONNX call, commas and all, so the phonetics inside a sentence are whole. VITS has no
  memory between calls, and Piper's own CLI also splits on sentences. What a sentence cannot know is where it
  sits in its paragraph; `_discourse_plan` (paratone, final lengthening, effort) is the answer to that.
- **Piper's three scales are used on every request:** `scales = [noise_scale, length_scale, noise_w]` is the
  whole of Piper's inference interface (plus `sid` for a multi-speaker voice). The Tone presets set all three,
  delivery leans move `noise_scale` and `length_scale`, and the discourse plan moves `length_scale` and
  `noise_w` per sentence.
- **One more native control exists, because we patched it in:** `rest_floor`, a per-id frame floor after the
  duration predictor's Ceil (`_ensure_patched`). It is how a comma gets a rest the model renders itself.
- **Post-generation, because no Piper input reaches it:** pitch (render slower, resample faster,
  `_restore_formants`), effort tilt, whisper, muffle, the pause top-up (`_splice_pauses`, digital silence),
  rest trimming (`_trim_rests`), the editor's Tone resample, hesitations and the room.

## What was measured

| Question | Probe | Result |
|---|---|---|
| Does the host's post-processing add transients? | `stage_spy.py` (audio kept after every stage) | No. 36 click-like events in the model's own output, 33 after the last stage (40 sentences, 94 s). |
| Does the formant restore pre-echo onsets? | `restore_probe.py` | No. +0.3 dB median in the 30 ms before an onset (90th percentile +1.1). |
| Does `noise_scale` drive the events? | `event_words.py`, 3 renders each | No. 16.9 / 19.4 / 20.0 / 17.5 per minute at 0.78 / 0.667 / 0.5 / 0.33. |
| Where do the events fall? | `edge_offsets.py`, `rest_clicks.py` (duration plan) | Inside words at stops (/p/ /k/ /t/), plus word-final releases before a rest. 1 in 111 s inside a pause. Not mouth clicks. |
| Are chunk joins a step? | `voice_ab.py` | No. Every chunk starts and ends about 55 dB under its peak, with a 1.67 s seam between them at Pause 6.5, so a crossfade has nothing to cross. |
| Native rests vs splicing | `native_ab.py` (seeded, see below) | Native: the model renders the whole comma rest (`rest_floor` = the target), unplanned rests capped in the plan (`dur_cap`), nothing cut. Same total length (85.7 s vs 84.9 s); 13.2 s of digital silence becomes 0 s of it, the room tone runs on. |
| Are onsets after a rest abrupt? | `onsets.py` | No. Median 10-90% attack 27-29 ms after a comma, at a sentence start and mid-sentence alike. |
| Are sentence-initial words clipped? | `onsets.py`, `first_word.py` | **Yes.** The first word of a sentence is short: "A" 12 ms, "If" / "It" / "The" 46 ms. A vowel floor of 5 frames on the first word (`rest_floor` again) gives 58 / 93 / 93 / 81 ms. Known for this checkpoint ([piper #296](https://github.com/rhasspy/piper/issues/296)). |

**Seeded renders.** Piper's two `RandomNormalLike` nodes take a `seed` attribute; with it set (a copy of the
voice in `dist/voice_ab/xdg_det/`) a fresh session renders the same performance every time, so an A/B differs
only in what is being compared. One session renders differently on each call: a fresh session per render is
the price.

**Not known: which sound a listener objects to.** No detector separates a click a listener objects to from a
/k/. The clipped first word is the strongest candidate for "the start of a sentence"; for "around commas" the
candidates are a word-final release left standing in a long rest, and the switch from the model's room tone
(about -45 to -50 dB) to digital silence and back.

Listening files (`dist/voice_ab/listen/`, the opening 30 sentences, the Tone resample and seams applied, no
room or presence): `1_current.wav` (the shipped pipeline), `2_native_rests.wav` (the same seeded performance,
every rest rendered by the model), `3_first_word_model.wav` / `4_first_word_floored.wav` (14 sentences, the
model's first word against a 5-frame vowel floor on it).

## Built: the duration plan steered, and the resample fixed

Pitch has no input in a VITS graph, but duration does, per phoneme id, between the predictor and the decoder.
Status: built, gated, waiting on the ear (`5_before.wav` against `6_after.wav`, and
`7_stress_plain_then_marked.wav`).

- **`dur_scale`:** a second patched input beside `rest_floor`, a per-id multiplier on the planned frames after
  the Ceil and before the floor (before the Ceil it did almost nothing: most of a syllable's ids are predicted
  under one frame, and `ceil(d * 1.3)` lands back on the same frame). `_ensure_patched` adds each input on
  its own, so a voice patched before gains it on its next load and keeps its floor.
- **Stress:** `*word*` and `**word**` are spoken, not only drawn: the token carries `emph`, the host holds
  the word's stressed syllable 1.3x / 1.5x through `dur_scale` (the stress mark, the vowel and the blanks
  inside and after it, because Piper spreads a syllable's time over all of them) and lifts the word 1.5 / 3 dB
  (`EMPHASIS`, `_emphasize`). Measured on six words: +17-31 ms italic, +28-55 ms bold. Pitch, the strongest
  cue of stress, is not in it yet. A run of more than `STRESS_RUN_MAX` (3) emphasized words is typography (an
  italic paragraph is a change of time or place) and is sent plain. The Cards reader is told what an asterisk
  does (`TablePrompts.SPOKEN_RULES`).
- **The opening vowel:** the first word's vowel may not fall below `OPENING_VOWEL` (50 ms at the request's
  length scale), through `rest_floor`. A floor, so a first word the model already gave its length is
  untouched.
- **Band-limited resampling:** `_resample` is a Kaiser-windowed sinc (polyphase, 32 taps, 4096 phases) where
  both pitch moves used linear interpolation (which left images at -27 dB by 4 kHz and -14 dB by 8 kHz at
  +1.5 semitones); every spur is under -80 dB. 0.14 s per 10 s of audio.
- **The Tone is played back in the host** (`play_ratio` in the request), through that resampler, with every
  returned time already in the played audio's seconds. `_drain_ready`, the audition and the export apply no
  ratio.

Gates: `hosts/voice/test_expression.py` (stress, the opening floor, the gain, the playback, the resampler
against the linear control, an old patch upgraded), `test_pauses.py`, `tests/reading/multi_voice_check.gd`
(`_check_stress_reaches_the_voice`, and `play_ratio` in `_check_settings_reach_the_request`).

## Built: the word before a rest, and the next word's hiss

The end of a statement (most commonly at a comma) sounded truncated, and "Wait until the end, sweet souls"
was heard as "ends ... sweet". Status: built, gated, confirmed by ear (`8_commas_before.wav` against
`9_commas_after.wav` and `10_commas_after_trail2.wav`; `11_sweet_souls_before.wav` against
`12_sweet_souls_after.wav`).

**What was measured.** The model ends every word at full level and drops it: the steepest 20 ms of a word's
end is 15 dB before a comma, 17 before a full stop, 17 mid-sentence. A comma is where a rest of up to a second
and a level pitch leave it standing alone. And the word-space the rest floor lengthens takes the next word's
sound with it: before an /s/ the model's lead (40-75 ms unfloored, its own coarticulation) grew to 165-195 ms
of a 210-290 ms rest, so the splice cut through hiss and left a burst on the word before. A second or third
word-space after the mark only halved it, and made other cases worse.

- **The trail** (`TRAIL_*`, `_trail_weight`): the word before `, ; :` is held and lets go: its final rime
  (`_final_rimes`) rendered 1.25x through `dur_scale`; the level eased down 16 dB over the last 120 ms to the
  voice's own end (found in the waveform: the plan is 50 ms early to 80 ms late) and held there through the
  rest; the pitch sagged 1.5 semitones over the last 90 ms (`_glide`, a slower read with the length kept).
  Weighted by the rest (full from 0.5 s), none at Pause 0; `trail` in the request scales it (0 off, 2 double;
  not on the panel). Full stops are left to the model and `_discourse_plan`.
- **The lead** (`LEAD_*`, `_quiet_lead`): in a floored rest, the next word's hiss is kept to its last 80 ms,
  coming in over 30 ms; what is earlier is silenced, so the splice always cuts in silence. The burst left on
  the word before went from 20-60 ms to none, the "sss" before "sweet" / "so" from 195-265 ms to about 120.
- `_resample`'s kernel and read are `_sinc_table` / `_read_at`, shared with the glide (byte-identical to the
  old resampler, 35 cases).

Gates: `hosts/voice/test_trail.py` (the rime, the weight, the hold, the fade, the sag, the lead, each with its
control); `test_pauses.py` runs its splice and floor checks with `trail` 0, so turning the trail off is pinned
byte-identical to the old audio.

**Not splitting chunks at commas:** each clause would open at an utterance's pitch and close with an
utterance's fall (the comma's continuation contour is why a sentence is rendered whole), and every clause's
first word would be clipped the way a sentence's is (`OPENING_VOWEL`). The leak is local and the plan says
exactly where it is, so it is fixed there. If the ear still hears the next word in a rest, splitting is the
experiment to run next.

## Built: a word's own hiss, and the next word's early start

The trail truncated the 's' at the end of its final word too early, turning plural words into singular ones.
Status: built, gated, waiting on the ear (`13_plurals_before.wav` against `14_plurals_after.wav`).

**What was measured** (`final_s.py`, `final_s_frames.py`, `final_plural.py`; seeded). The model renders a
final /z/ small: planned for one or two frames, 30 to 60 ms long, 25 to 35 dB under the take's peak. The trail
looked for the voice's end 12 dB under the rime's peak, so it stopped before that hiss or part of the way into
it, and its floor then held the rest of it 16 dB down, at the room tone:

| | hiss-final words | own hiss down over 6 dB | over 12 dB | next word's start dipped over 3 dB |
|---|---|---|---|---|
| made sentences, before | 26 | 20 (median 11.7 dB) | 12 | 4 of 31 commas (worst 23.5) |
| made sentences, after | 26 | 0 | 0 | 1 (a -40 dB murmur) |
| the Cards reading (127 requests), before | 18 | 9 | 5 | 20 of 83 commas (worst 24.4) |
| the Cards reading, after | 18 | 0 (worst 0.1 dB) | 0 | 1 (a blip 50 ms out in the rest) |
| before a hiss-initial word, 50 draws, after | 50 | 0 (worst 0.9 dB) | 0 | 0 |

No splice lands inside a hiss, and nothing clips. The lead was innocent: `_quiet_lead` touched none of 100 own
hisses.

- **The plan says which words, the waveform says where** (`_HISSES`, `_hiss_codas`, `_hiss_tail`): a word
  whose sounds after its last vowel hold s z ʃ ʒ f θ is looked at for its hiss, for as many runs as it spells
  ("asks," has two, a 70 ms closure apart; "last," one, so its /t/ keeps the floor). The voice ends before the
  hiss, the hiss is left at the model's own level, and the floor comes back after it. Words the plan does not
  name are byte-identical to before.
- **Looked for above 2 kHz, not 4:** a /ʃ/ has 94-100% of its energy above 2 kHz and 5-40% above 4.
- **The voice falls no further than its hiss:** the fade's depth is the vowel's level over the hiss's, at most
  TRAIL_DB: the whole 16 dB before a quiet /z/, about 8 before "hush,".
- **The next word can start before the plan says** (10-30 ms): the far side of the rest is walked back to
  where its sound begins (`_sound_from`, at most TRAIL_EARLY), so the floor lets go first and the search for
  the voice's end cannot land on the next word.

Gates: `hosts/voice/test_trail.py` (nine checks, each with its control: a hiss the plan does not name is
still floored, one run where two are spelled, 4 kHz instead of 2, TRAIL_EARLY 0).

**A duration floor on the final hiss was weighed and set aside** (`hiss_floor.py`): it lengthens a voiceless
/s/ about 10 ms a frame, but a voiced /z/ (the short case) only gets longer as voice, and every floored word
grows by the floor.

**A delivery mark resolves its marks after the leading whitespace** (a passage opening on a comment and a
blank line started a mark late; `tests/reading/multi_voice_check.gd`).

**Found, not built:**

- A delivery mark is under what can be heard: one step is pace 4% (about 2% in the audio), pitch 0.33 st,
  effort 0.2 dB, eased half a sentence at a time; the model's own sentence medians wander about a semitone.
  The pitch is on the formant-locked path, clamped at 1.5 st in the host, so there is room
  (`15_delivery_today.wav`, `16_delivery_x2.5.wav`, `17_delivery_x4.wav`, `listen_delivery.py`). The steps
  are pinned small by `multi_voice_check` on purpose; the ear decides.
- Dead with one sentence per request: the length-conditioned rate (`rel` is always 1) and the alternating
  `noise_w` (always the plus side) in `_discourse_plan`; both under 2% at typical dials.
- A hold's cut (`rests`, `_splice_holds`) is searched only in the plan's gap, which after a hiss-final word
  with no mark can lie inside the hiss: part of it lands after the hesitation.
- A failed request carries no id (`VoiceHost.failed`): the live reading waits on that chunk for good, and an
  export awaits `synthesized`.
- The outro mark's fade is in the export take and in the render's master ramp (twice); live and export hash
  different text for their seed (unstripped against stripped); a chain stage at 0 on one voice keeps its state
  frozen across a handover.
- `_effort` and `_emphasize` end in a hard clip: none at the note's settings, reachable at the top of the
  Effort dial.

## Built: a word eSpeak has to guess at

Cosine said "co-seen", cotangent "co-angent", cosecant "co-seh-cant". eSpeak, which the neural voices are
phonemized by, gave kˈoʊsaɪn, kˈoʊtændʒənt and kˈoʊsɛkənt: the core syllable unstressed in each (and
en_US-libritts-high slurs a full vowel given no stress), and cosecant's vowel wrong. A dictionary alone does
not settle it (Wiktionary's US cosine is /ˈkoʊ.saɪn/, eSpeak's own pattern; CMUdict has none of cosine,
secant, cotangent, cosecant).

So `hosts/voice/lexicon.py`, for a word the reading marks `rare` (not `Phonemes.is_known`, the audit's
UNKNOWN, and spelled as written): its reading is Wiktionary's American one where Wiktionary has it
(kaikki.org, one JSON file per word, fetched once into `<data>/ghost/voices/lexicon/`, rewritten into
eSpeak's spelling and checked against the voice's phoneme map), else eSpeak's; then every full vowel left
unstressed gets a secondary stress. A word eSpeak knows is never touched (its transcriptions are what the
voices were trained on). The request's `lexicon` is "fetch" in the app and "off" in any read-only process
(`ReadingPanel._request_args`), so a gate is the same on every machine. `hosts/voice/test_lexicon.py` holds
the three readings. Live on a lesson's words: Pythagorean pˈaɪθɐɡˌɔːɹiən -> pɪθˌæɡəɹˈiːən, axiom ˈæksɪəm ->
ˈæksiəm; secant, tangent, trigonometry, radians and Euclid unchanged. A name Wiktionary lacks keeps eSpeak's
guess (the stress rule only). About a second a new word, once.

`rare` compares a word's spoken spelling with its page spelling with the marks off (`Phonemes.guessed`; a
word normalization wrote, a numeral or a letter's name, is still not one): the page spelling keeps the word's
marks, so "cosine," never matched whole. g2p_check's "guessed" holds the sentence.

## Still proposed

1. **Rests rendered, not spliced:** the comma rest whole from `rest_floor`, no digital silence
   (`2_native_rests.wav`). Needs the ear first.
2. **Final lengthening where it belongs:** done before a comma (the trail, above); a full stop still slows
   the whole sentence through `_discourse_plan`.
3. **`dur_cap`:** a per-id ceiling after the floor, so the bimodal blank `_trim_rests` cuts out is capped
   before the audio exists.
4. **A pitch accent on a stressed word:** the one cue of stress this graph cannot render. A local resample
   around the word, formant-locked, would be the way.

## Agents: more granular control

An agent has `<!-- delivery: ... -->` (four axes, two steps, per paragraph, eased over sentences),
`<!-- hesitation -->`, and a word's stress by asterisks. Next, all on the duration plan: a drawn-out word
(`Sooo`, "Ooh") as a duration on that word, and `quicker` / `slower` scoped to a clause rather than a
paragraph. Not a per-sentence Tone or raw `noise_scale`: the presets are a person, and the rules say the
show's voice is fixed.

## Ideas weighed and set aside

- **A crossfade between chunks:** the joins are already at the noise floor with seconds of silence between
  them (see the table).
- **Blending several takes:** waveforms whose phases do not agree average into a chorus. The version that
  works is best-of-N: render a sentence two or three times (`noise_w` and the seed vary) and keep the one with
  the fewest artifacts by a score. That costs 2-3x synthesis, which suits an export better than live reading.

## Other engines (surveyed 2026-10-07; licenses checked on the model cards)

**Piper.** Nothing beats en_US-libritts-high and is commercially clean. Clean single-speaker "high" voices
that would drop into this pipeline: `en_US-ljspeech-high` (public domain) and `en_GB-cori-high` (public
domain). `rhasspy/piper-checkpoints` publishes `ljspeech-2000.ckpt`, the only clean high-quality base to
fine-tune from (onto Hi-Fi TTS or LibriTTS-R speakers, CC BY 4.0). Lessac-derived (never usable): libritts_r,
joe, mike, amy, alba, vctk, aru, sam, jenny_dioco. Every `*-low` voice is ryan-derived (CC BY-NC-SA).

**Phoneme-driven alternatives.**

- **Kokoro-82M** (Apache-2.0 code and weights, 24 kHz, ONNX, about real time on a weak CPU): takes phonemes
  (misaki's set; our IPA maps onto it), returns per-token durations, takes a duration override and a style
  vector (voices blend by averaging). Its decoder is fed an explicit frame-level F0 curve and an energy
  curve: split the graph and pitch becomes an input, which retires the resample-and-restore DSP. Caveat: its
  training data includes synthetic audio from commercial providers, a provenance question for Steam.
- **NeMo FastPitch + HiFi-GAN** (CC-BY-4.0): a per-token pitch input and duration and pitch outputs, out of
  the box. One LJSpeech voice, older and plainer than Kokoro.
- Matcha-TTS, MeloTTS and Kitten TTS take phonemes but add no pitch control; StyleTTS2's weights require
  telling listeners the speech is synthetic.

**Generative models.** None takes a duration plan or a pitch contour; their "emotion" is a global vector or a
tag, and most need a GPU. The only small one that is commercially usable is Chatterbox-Nano (110M, MIT, CPU,
watermarked, no timings; its `exaggeration` dial is the original's, Nano ignores it). Pocket TTS (100M) is
CC-BY-4.0, gated, cloning only. Non-commercial and excluded: F5-TTS, Spark-TTS, Llasa, MaskGCT, OpenAudio S1.
They are hard to steer.

**Order:** the duration plan in Piper first (built, above); then a Kokoro prototype behind the backend
registry (`hosts/voice/backends/`), whose explicit F0 input is the one thing Piper cannot have. The
prototype is built: "Kokoro" below.

## Kokoro: an inference trial

Goal: wire Kokoro up for inference only, everywhere voice models are used (including the likeness/actor
modes), to hear it read prose before deciding on fine-tuning, and to know whether any feature is lost
against Piper.

**What Kokoro is** (read in hexgrad's `kokoro/model.py`, `forward_with_tokens`): StyleTTS 2 without the
diffusion, 82M parameters. PL-BERT reads the phonemes; a duration predictor plans each token
(`round(sigmoid sum / speed)`, clipped at one frame); the F0 and energy curves are predicted from the aligned
features (`F0Ntrain`); an iSTFTNet decoder takes the aligned text, F0, energy and the voice's timbre. So the
durations and the pitch are tensors between stages: split the graph and both are inputs. A voice is a style
vector, 128 numbers of timbre (decoder) and 128 of prosody (predictor), taken by token count from a
`[510, 1, 256]` pack. At most 510 tokens a call. 24 kHz. A duration frame is 600 samples, 25 ms (Piper's is
256 at 22,050, 11.6 ms).

### Built

- **`hosts/voice/backends/kokoro.py`:** `KokoroBackend(PiperBackend)`: everything around the model is Piper's
  path, unchanged (ghost's tokens, eSpeak's reading with homographs and the lexicon, the rest floors and
  splices, the trail, the lead, stress through `dur_scale`, the arc's pitch, the Tone played back, words and
  phones handed back). What it replaces is the model: the ids (one per symbol, a pad at each end, no blanks,
  no lead-in spaces), the graph, the frame, the voices. Piper has three hooks for it, each a no-op on Piper:
  `hop`, `_nominal` (the arc's length estimate, for a plan rounded rather than ceiled) and `_delivered`.
- **The graph** is onnx-community's timestamped export (Apache-2.0, 325 MB, pinned by commit), patched once
  where it is first opened (`_patch`), as a Piper voice is: `dur_scale` before the Round, `rest_floor` after,
  and `durations` handing back the whole frames the decoder used. Unfed, the patched graph's audio is the
  stock graph's sample for sample; frames x 600 is the take's length exactly; nothing in it samples, so one
  text and one voice make one take.
- **The symbols** (`kokoro_symbols`): Kokoro's English was taught misaki's notation (a letter per diphthong:
  A eɪ, I aɪ, W aʊ, Y ɔɪ, O oʊ, Q əʊ; ʤ ʧ; T for the American flap; no American length marks; ᵊ for a
  syllabic consonant), so eSpeak's reading is written in it by misaki's own table for its eSpeak fallback.
  ghost's reading carries no tie marks, so a pair is merged where it stands in one word. The phones go back in
  eSpeak's symbols (A's time shared by e and ɪ), so Visemes and the desk read them as they read Piper's.
- **One voice, its packs the speakers:** the host lists one voice, `kokoro`, with 28 speakers (the English
  packs, a speaker number each in the fixed order of `PACKS`; a note keeps the number, so a pack is only ever
  added at the end) and says who each is (`readers`: the pack, its accent, hexgrad's own grade). The Speaker
  row and its Browse… read them as they read libritts' 904 readers (`VoiceReaders.offer`). A British pack is
  read in British eSpeak. The graph and tokenizer are fetched on first use, a pack (half a megabyte) when its
  number is first asked for, into `<data>/ghost/voices/kokoro/`.
- **One rate:** rendered at 24 kHz, handed back at 22,050 through the band-limited resampler (`_delivered`),
  so a cast mixing Kokoro and Piper joins at the one rate a reading has. It costs the band from 11 to 12 kHz.
- **A sentence over 510 tokens** is read in pieces cut after a mark (`_pieces`), each with its own pads and
  style.
- **A take's ends trimmed to the seam** (`_trim_ends`, SEAM_LEAD 0.044 s, SEAM_TAIL 0.14): the gap between two
  sentences is spliced on Piper's measured silence at a take's ends, and Kokoro's own ends hold more (its
  first pad rests 350 ms, a sentence's mark, word-space and pad another 225 or so). Seams ran 2.57-2.79 s
  where Piper's ran 1.89-2.06 at the same Pause; trimmed, 2.05-2.23 s, the rest being its own lengthening of
  a sentence's last word. Cut only where the plan holds no sound and the waveform is quiet, the frames with
  the audio, so every time stays exact.
- Nothing in Godot changed but the Voice picker's tooltip: the host lists every backend's voices, a take says
  its rate, and a voice with no Piper config has no readers.

Gate: `hosts/voice/test_kokoro.py` (fake session, no download: the symbols American and British, the ids, the
comma's floor, stress, times, phones and rate, the pieces, the rounded estimate against brute force and
against Piper's ceiled one, the patch on a toy graph and a graph of another shape refused).

**Measured** (i7-4790K, four cores, nothing else running): the raw graph 2.2x real time. Through the whole
host path: the actor's own Piper voice (medium) 11.3x, libritts-high 3.8x, the Kokoro voices 2.5-3.2x. A first
call loads (and once, patches) the graph: 5 s. A live reading over a busy show has less headroom than on
Piper. At the same Pace the Kokoro voices speak 10-20% slower.

**Listening** (`dist/voice_ab/kokoro/`; `passage.txt` read at its own pace and Pause 6.5 through the host
alone): `1_actor_own_piper.wav`, `2_piper_libritts_high_s8.wav`, then Kokoro `3_am_michael` through
`8_af_bella`.

### The second round (2026-10-25 evening): families, every dial checked, the stall, a second checkpoint

**Every dial, checked by rendering** (`controls.py`: a passage with a comma, a stressed word and a
hesitation, each request parameter moved off its default alone): on Kokoro only `noise_scale` and `noise_w`
change nothing (the same request twice is the same take, sample for sample). Pace, Pause, Dynamics, Arc,
Effort, the Tone's pitch, whisper and muffle, a delivery's pitch and effort, Near's hush, the speaker, the
trail, stress and a hesitation all change the take; the room's dials are Godot's and act on any voice. So no
control is dead and none is hidden: the Tone keeps its pace, pitch, whisper and muffle on Kokoro and loses its
liveliness.

**Two checkpoints, one voice each, their packs the speakers:** `kokoro` (v1.0, 28 English packs) and
`kokoro 1.1` (hexgrad's v1.1-zh, Apache-2.0: its English voices Maple, Sol and Vale, an hour each of
crowdsourced synthetic speech, ungraded; the card: "not a strict upgrade"). Its export hands back the clipped
plan already (`duration`), so `_patch` leaves that output alone (`_reaches`); its vocabulary keeps v1.0's ids
and drops ɚ, which the table writes əɹ anyway. Each checkpoint is fetched into its own folder (`FAMILIES`
`dir`) on first use.

**The clicks are the v1.0 checkpoint's, not ours** (`dist/voice_ab/probes/quiet_clicks.py`: impulses standing
out of quiet; the first 40 sentences of a chapter, counted after every stage of the host path):

| voice | in the model's own output | in the finished take |
|---|---|---|
| Emma (v1.0, B-) | 172 in 219 s | 169 in 236 s |
| Isabella (v1.0, C) | 203 in 223 s | 222 in 233 s |
| Heart (v1.0, A) | 180 in 224 s | 181 in 238 s |
| **Vale (v1.1)** | **16 in 237 s** | **30 in 247 s** |

No stage of ours adds them on v1.0; on Vale's quieter floor the splices and the rate change show a few.
Listening: `dist/voice_ab/kokoro_gb/`.

**The stall: the window was Piper's, and the machine was busy.** Kokoro reads through the same sliding
window, and there is no finer stream to be had from it: it plans a sentence and decodes every frame of it at
once, so a sentence is the smallest unit it can hand back (as its own pipeline streams too). The window kept
LOOKAHEAD_SECONDS (9 s) ahead, sized for Piper (4-11x real time); Kokoro made its takes 2.2-2.7x real time
idle and 1.55x while other work ran, and replayed through the stream's policy over measured takes the old
window ran dry once in 120 sentences at 2.2x, twice at 1.5x, fifteen times at 1.1x. Now:

- **The window follows the host** (`ReadingStream.depth`, `cost_after`, `_measure`): each take's cost (the
  seconds the host spent on it, from when it could start, per estimated second of its chunk) is measured as
  it comes back (rising at once, falling slowly), and the window keeps DEPTH_SAFETY (1.5) times what the next
  LOOKAHEAD chunks will take to make, never under 9 s (a fast host reads exactly as before) nor over
  DEPTH_MOST (45 s, the latency of a pace change).
- **The first sample waits for the next chunk** (`lead_for`): as long as it will take to make, a pause before
  the first word in place of one inside a sentence.
- **The graph is opened before Play** (`VoiceHost.ensure`, `ReadingPanel.warm_voice`; Kokoro's `ensure` opens
  and patches it). A failed `ensure` is not a failed chunk (`VoiceHost.failed` says which request failed).
- **A core is left to the show** (`KokoroBackend._options`): a thread a core but one and no spinning: 2.60x
  real time with 2.6 cores busy, where the default made 2.70x with 3.9 of the four busy.

Gate: `tests/reading/stream_depth_check.gd` (boot probe; the replay's control: the old window runs dry at 1.5x,
the new one does not, and at 4x both start at once).

**Faster still, not done:** the int8 graph (`model_quantized.onnx`, smaller and quicker on a processor, some
quality lost: to be heard first), or the graphics card (onnxruntime's CUDA build: tens of times real time, but
gigabytes of CUDA libraries in the voice environment, which is kept small on purpose).

### One-word sentences (2026-10-25, late)

The Cards Test reads "Let's shuffle. Oh. Oh, wow." (a sentence a request), so Kokoro is asked for "Oh."
alone, three tokens (its own notes: weak under 10 to 20). Measured (Whisper base.en on each take;
`dist/voice_ab/kokoro_short/`):

- Not the host's plan: the raw model, with no processing of ours, says it the same.
- Two faults of the takes, both fixed: (1) Piper's path ends every utterance on a word-space, which Kokoro
  was never taught (a short take ended on a sound 32 to 40 dB under its peak), and `KokoroBackend._symbols`
  drops it; (2) on a sentence ending voiced, the model often lets go with a burst of hiss (18 to 23 dB under
  the peak, 86 to 99% above 4 kHz), and `_quiet_tail` lets go of what follows the waveform's last voiced run
  (TAIL_RUN frames), only where the plan's last sound is voiced, never a final s, z, sh, f, th or a stop's
  release.
- What is left is Emma's: "Oh" alone still comes out "Low", and "Wow" "Well", even opening a long sentence,
  with Heart's prosody under her timbre, and with up to half of Isabella blended in. Only her timbre half does
  it. Spelled as two symbols (`əʊ` for Q, `aʊ` for W, off misaki's notation), Whisper hears her right
  (`emma_shuffle_as_shipped.wav` against `emma_shuffle_split_diphthongs.wav`). Not made a rule: it changes
  every "no", "road" and "now" she says; the ear decides.

The Test passages are a minute long (the default 75 s, Cards 60 s, Proof 55 s).

### Rests and fades (2026-10-25, night)

There is no fade at every sentence: what fades is clause-level (the trail before a comma, 120 ms and 16 dB,
and the splicer's ramps where a rest is cut in, 2 to 30 ms by how loud the voice still is there). Clipping on
Kokoro was the cut landing on sounding voice:

- **A floored rest is not a rest on Kokoro.** Piper given frames on a word-space renders silence there; Kokoro
  holds the word through them (20 frames after "dawn," were 500 ms of voice 16 to 20 dB under the peak). So
  nothing is floored on Kokoro (the opening vowel still is), the word falls away by itself, and the splicer
  measures that and rests the remainder.
- **Its word edges are not its waveform's.** Over 198 commas of two voices the real gap lay from 130 ms before
  to 140 after the plan's boundary, so Piper's window reached no quieter than 23 to 25 dB under the peak at
  half of them. Kokoro's window (`_gap`) runs within the two words, at most GAP_REACH from the boundary; the
  splicer takes the middle of the longest silence in it. The trail's fade and the lead's cut are placed by the
  plan, which runs late here ("The plan runs late").

Where the rest is cut (the 5 ms before the cut, re the peak; 198 commas each):

| | in silence (under -40 dB) | -40 to -30 | -30 to -20 | louder than -20 |
|---|---|---|---|---|
| Emma, before | 56 | 45 | 57 | 40 |
| **Emma, now** | **114** | 53 | 25 | **6** |
| Heart, before | 67 | 41 | 56 | 34 |
| **Heart, now** | **122** | 47 | 19 | **10** |

**Left:** the commas Kokoro reads straight through, with no silence within 150 or 200 ms of either side. A
pad token after the comma rests there but the model fills round it; an ellipsis in its place barely rests.

**Read through, or left unrested?** Each sentence rendered with the comma and without it (`commas.py`; 28
commas, two voices): at the commas it rests, the comma lengthens the word before it by 150 to 200 ms, deepens
the dip at the boundary by 12 dB and holds the pitch up (a continuation); at the ones it reads through (5 to 7
of the 28), it still marks them, lightly (the word 25 to 75 ms longer, the dip 2.5 to 5 dB deeper) with no
continuation in the pitch. A quick read-through, as of a list, not a comma ignored; a full Pause spliced in
there forces a stop on a word the voice did not slow for.

**Kokoro's own pipeline does not read in pieces at commas** (`kokoro/pipeline.py`, `en_tokenize`,
`waterfall_last`): it splits text at blank lines only, then packs as much as fits in 510 phoneme tokens into
one call (most often a whole paragraph) and cuts inside that only when it must, at a full stop first, then a
colon or semicolon, a comma last. A sentence a call is shorter than its best range (100 to 200 tokens), and
its weakest case is the short one.

Gates: `hosts/voice/test_kokoro.py` (no rest floored; the window, with Piper's as the control; the lead not
made on Kokoro, made on Piper; a stop's release kept before the cut, the trail run up to the next word
without a step, the short last vowel held).

### The plan runs late: corrected

- **Where the cut was:** in "Sore arms, happy heart." Kokoro reads the comma straight through (the z of
  "arms" runs into the h of "happy" with no silence) and the wide window's longest silence was the closure
  inside "happy", so the rest went in as "ha ... ppy".
- **Why:** Kokoro's audio runs ahead of its plan by a nearly fixed amount: the voicing the plan puts in each
  frame is heard a median 55 ms (Emma) and 48 (Heart) earlier over 20 sentences, the middle half within 15
  ms, the same in a sentence's first half as its second. Every time the plan reports is told PLAN_LEAD (50
  ms) earlier (the words, their edges, the rests, the phones, so the subtitles and a mouth too), the cut is
  looked for GAP_REACH (50 ms) either side of that boundary, and the trail is made on Kokoro; the lead stays
  off (no rest is floored here, and a floored rest is what made the lead long). Counted by where a rest's cut
  lands against where the next word's voice begins (29 commas): Piper's window on the uncorrected plan split
  the next word at 7 (Emma) and 4 (Heart), the wide window at 5 and 3, the corrected plan's at 3 and 2.
- **Each side of a comma rendered on its own** (`clauses.py`, 29 commas, both voices): the first part ends as
  an utterance (the word before the comma 650 to 775 ms where the sentence whole gives it 475) and the next
  starts as a new one, 5.0 to 5.3 semitones above where the last ended (whole: 1.2 to 1.7). Whisper writes
  those commas as full stops. Not taken: a comma would be heard as a sentence end.

Listening (`dist/voice_ab/kokoro_batch/`): `A_as_shipped.wav`, `H_plan_corrected.wav`,
`I_split_at_commas.wav`; and `D_no_comma_rest.wav`, `B_with_previous_raw.wav`, `C_with_next_raw.wav` (the
model's own reading, nothing of ours).

### A cut inside the word, and the way back up (2026-10-26, later)

- **A vowel held straight through a comma into the next word** ("you, my"): the trail walked the next word's
  start back over sound (TRAIL_EARLY, 60 ms, measured on Piper), and on Kokoro that sound was the same vowel,
  so it faded half the vowel and let go one sample from 16 dB down to full level; the cut went in that dip,
  and the vowel's second half played after the rest. The trail walks back none on Kokoro (its plan is
  corrected) and fades the vowel right up to the next word.
- **A window reaching into a word finds the silence of a stop's closure** ("it,"): so the release went after
  the rest. The window reaches GAP_BACK (15 ms) back.
- **The way back up is never a step.** The splicer's own ramps are 2 to 5 ms long at 32 to 98 dB under the
  peak, so their shape cannot be heard (reshaped to fall at a steady rate in dB, the take differed by 0 to 3
  ms at each cut and nothing else). The abrupt edge was the trail's: where the voice runs right up to the next
  word, TRAIL_BACK had no room and came back in one sample, 16 dB on sounding voice (8 of 80 comma trails in
  two voices). It runs on into the next word (`_trail`'s `through`), a fade in dB; 0 of 80 step.
- **The short vowel is held, not every rime.** Piper's hold is a ratio (TRAIL_STRETCH, 1.25), which on 25 ms
  frames is wrong both ways: the "oo" of "you," (two frames) rounded back to two, and "stays," and "flame,"
  (five and six frames) were drawn out ("someone stayyys"; commas began to be heard as full stops). The last
  vowel of the word before a rest is floored at HOLD_LEAST (90 ms at length scale 1, the trail's share of
  it; "uː" shares it between its two symbols).
- **Measured** (`dist/voice_ab/kokoro_commas/eval/`, 53 sentences with 83 commas in Emma and Heart, a dark
  bed at -28 dB, Whisper): Emma's words misheard 35 in 22 sentences as shipped, 28 in 18 with the cut moved,
  every comma-related change a fix; Heart 18 either way.

Listening (`dist/voice_ab/kokoro_commas/`): `listen_H_as_shipped.wav`, `listen_J_cut_moved.wav`,
`listen_M_no_step.wav`, `listen_N1_hold_1.6.wav` and `listen_N2_hold_2.0.wav` (the ratio, rejected),
`listen_O_short_vowel_held.wav` (as built), `listen_L1_db_ramps.wav` (the splicer's ramps in dB: no
difference).

### Every sentence ends alike: the model's, not ours

Symptom: a chapter in Puck (speaker 13) had every sentence end with a downward inflection, the last word
always the same curve, in creak ("valley girl"); the same chapter in Piper varied.

**Measured** (pYIN on the last word's own voicing, from its start until 40 ms unvoiced, against its
sentence's median pitch; "falls": over 1.5 st across the word; "no pitch": pYIN found none (creak, or under 60
Hz); "alike": mean correlation of the last words' contours, 1 every one the same), 22 sentences of the chapter
alone, as the reading sends them:

| voice | last word ends | falls | no pitch | alike |
|---|---|---|---|---|
| Piper libritts-high 13 | -1.4 st | 7 of 18 | 4 of 22 | 0.31 |
| Kokoro Heart | -1.1 | 3 of 14 | 8 | 0.02 |
| Kokoro Emma | -3.3 | 15 of 18 | 3 | 0.85 |
| Kokoro Puck | -5.1 | 5 of 11 | 11 | 0.24 |
| Kokoro Michael / Onyx / Fenrir / Liam | -3.2 / -3.8 / -8.4 / -5.7 | 5/11, 9/18, 9/14, 11/16 | 11, 4, 8, 6 | 0.32-0.77 |
| Kokoro Eric / George / Daniel | -8.6 / -10.3 / -6.4 | 18/19, 18/19, 15/19 | 2 each | 0.61-0.87 |

Every male pack falls, most into creak. Heart alone varies as Piper did. Not ours: LEAD_IN 0 falls the same,
nothing after the render touches pitch.

**What does not change it:**

- The words after it heard: rendered with the next sentence's first 2 or 4 words, or the whole of it, or
  inside its whole paragraph as one utterance, the fall is the same (Emma -3.2, -3.2, -3.3, -3.1 st, alone
  -3.3). Measure a word by its own voicing: measured over the word's span plus 80 ms these looked like a fix
  because the window took in the next sentence's reset pitch.
- Another mark in place of the full stop (`…`, `;`, `,`, `—`, none at all, the vocab's unused `→`): the fall
  is the utterance's end, whatever ends it.
- The last word's stress (eSpeak read without a break at the sentence's end demotes it): the same fall.
- `…` inside an utterance: too weak and too mixed to build unheard, and it would cost about 30% more
  processor time.

**The lever: F0 as an input** ("Not in the trial" below). The predictor's pitch curve is one tensor
(`/encoder/Reshape_output_0`, from `F0_proj`, read by the decoder alone) and so is its energy
(`/encoder/Reshape_1_output_0`, from `N_proj`). A listening prototype, not the product: the ending is planned
unvoiced (Puck's last vowel is predicted at 0 Hz: the fry is the plan, not the decoder); pitch alone does not
voice it (100 Hz written across the word voiced two or three frames more); pitch with the energy held through
the last vowel voices it at the pitch written, the energy let go over 100 ms after the vowel into the model's
own (held whole, the last consonant draws out). In the demo (a sentence another follows falls a seeded 1.5-3.5
st "gentle" or 0-1.5 "level", a paragraph's last 4-6; never above the word's start) the last word is voiced in
20 of 22 sentences against 10 as now; median end against start -1.5 / -0.7 st, -4.2 as now (`now.wav`,
`gentle.wav`, `level.wav`). Open: the ear.

### It comes out hot

Kokoro voices come out loud: speaking RMS Puck (13) 0.141 with the note's dials, its takes at full scale (most
sentences peak at 1.000, 198 samples clipped in 59 s); Heart (0) 0.086, peak 0.93; libritts-high 0.065, peak
under 0.6. Neither backend levels its output, so the model's own level is what VoiceFX gets, and the bed, at a
fixed level, sat 17.7 dB under Puck where it sits 9 under Piper ("ambience" almost inaudible).

- **The bed follows the voice** (`VoiceFX.PAD_VOICE_REF`, `_level_pad`): its level and its duck scaled by the
  voice's speaking level (the RMS of the windows the pitch tracker finds voiced, over 8 s of voice, primed with
  the key from the take's first 12 s) against libritts-high's (0.06), so Piper's bed is where it was and every
  voice's sits 8-10 dB under it. Gate: tests/voice/pad_level_check.gd.
- **Every voice at one level:** each voice and speaker is measured once, as the vowel probe measures a
  checkpoint: two plain sentences through the backend's own `_run`, nothing delivered, the noise off (a VITS
  render moved 0.7 dB from one to the next) and what the noise adds back as the backend says (`level_noise`:
  libritts-high 1.14 and 1.16 over twelve renders; Kokoro samples nothing), its speaking level the RMS of the
  frames within 30 dB of its loud ones. Its gain is TARGET - libritts-high speaker 0's own level, so the default
  voice and the bed's staging are where they were - over that, applied to every take as it leaves the model,
  before the host's shaping. One gain a voice, never a take. Kept in `levels.json` beside the weights, by the
  model files' sizes and times. 2 to 4 s a voice, once. Read in a chapter, four voices' speech came within 1.2
  dB of each other (they had been 7.7 apart) and none reached full scale. Gate: hosts/voice/test_level.py.
- **The bed's tones follow the voice's register:** the key is the voice's own (`KEY_HEARD`: the median of its
  first 3 s of voiced windows, primed from 12 s; `PAD_REGISTER`: the register a median of the last 20 s, since
  a Hz average drifted 3 semitones up on the tracker's octave slips), never snapped to a grid; the bass's
  second partial stays a fifth under the voice's middle (`BASS_UNDER`), none under A0 (`BASS_FLOOR`); and it
  swells over 1.2 s, not 0.35. The scale was never the fault: the bed's minor pentatonic has no two notes a
  semitone apart. Gate: tests/voice/pad_key_check.gd.
- **And staged by the ear:** in a low voice's key, a fifth under him, every tone of the bed was under 80 Hz
  (-30.4 dB A-weighted where the Piper bed is -22.1, and no small speaker plays it). A tone under 120 Hz takes
  octave partials (2x and 4x, 0.6 and 0.35 an octave under it; octaves only, so no note the scale did not
  choose) at its own power, and the tones are lifted by how much less audible their register is than the one
  the bed was staged in (`PAD_EAR_KEY`, `_audibility`: the A-weighting over every tone the bed can play): Puck
  1.40, libritts-high 1.10, Heart 1.03, a child's register 0.70. A-weighted against the voice: Puck -19.2,
  libritts-high -21.0, Heart -20.2. The swell is not lifted: it is felt more than heard. Gate: pad_key_check
  ("heard under a low voice as under a high one").

### The happy vowel

eSpeak reads a word's unstressed "ee" (CMUdict's IY0) as lax ɪ in compounds and before vowels ("babysitter"
bˈeɪbɪsˌɪɾɚ where "baby" alone is bˈeɪbi; 65 words of one corpus, "everything" 184 times). Kokoro was taught on
misaki's dictionary, which writes that vowel i, so it says ɪ as the short vowel it learned ("bay-bah-sitter":
F1 360, F2 1670, between ɪ and ə).

- **Built** (`kokoro.py` `happy_vowels`, the hook `PiperBackend._dictionary_reading`): where the word's
  dictionary reading (the token's `fallback`) has IY0 and eSpeak ɪ in the same place, vowel for vowel, Kokoro is
  sent i, after a stressed syllable or before a vowel. An unstressed prefix before a consonant keeps eSpeak's
  ɪ ("pretend", "prepare", "prediction"), as do a word whose vowels do not line up, a word no dictionary holds
  (`rare`) and every word Piper reads. Measured after: F1 300, F2 2200, an "ee". Gate:
  hosts/voice/test_kokoro.py `test_the_happy_vowel`.
- **Open:** a voice taught here is taught on `ids_of`, whose tokens carry no dictionary reading, so it learns
  eSpeak's ɪ where it is now sent i; utterances.py would need CMUdict to match.

### A colon is not faded

The word before a colon (the short word one so often follows: "were:", "said:") lost its end to the fade.
Whisper medium.en, hearing the reading's own requests (ten colons and six commas, the note's dials, the trail
as made and with each of its three parts off):

| | word before a colon heard | its confidence | before a comma |
|---|---|---|---|
| as made | 8 of 10 | 0.79 | 6 of 6, 0.99 |
| no trail | 10 of 10 | 0.94 | 6 of 6 |
| no fade | 10 of 10 | 0.98 | 6 of 6 |
| no sag | 8 of 10 | 0.79 | 6 of 6 |
| no hold | 7 of 10 | 0.67 | 6 of 6 |

libritts-high, default dials: 7 of 10 (0.63) as made, 10 of 10 (0.98) with no fade. So the word before a
colon is held and sags but is not faded (`TRAIL_FADE`), in both models; a comma's and a semicolon's trail are
as they were. A colon announces what follows: the voice holds up into it. Gate: hosts/voice/test_trail.py
`test_a_colon_is_not_faded`.

### The head of a take: ours, not the model's

A lead-in of four word-spaces (added for a swallowed "A") rendered as clicks or a voiced syllable ("h-h-h-ello",
"Uh-hello"). Cause under all the reports: Kokoro is silent for a fixed stretch from the start of the sequence,
8 to 14 frames by the voice, and voices whatever follows, word or not, pad included. Its first pad's plan at
speed 1.0 lands the first word just there. `speed` divides the pad with the words, so a fast pace puts the word
in the silence and a slow one voices a phantom before it. The table is in the backend's header.

**Built:** no lead-in, the model's own ids, `dur_scale` = speed on the first pad, so it is planned at speed 1.0
at any pace. It needs no constant per voice: the plan is the voice's own, in trained voices too. Not taken:
other lead-ins (pads, `.`, `,`, `…`, `“`, `—`: all voice a head by the same dose), a pad 1.15 or 1.3 times its
plan (the phantom back). Kokoro reads about 5% quicker than it did with the lead-in (the lead-in stretched the
words after it 5 to 10% against the stock plan). Heard better ("after" against "before",
`dist/voice_ab/kokoro_head/listen/`); checked through `host.py`'s own protocol: the first word 42 ms in and the
head 39 to 166 dB under the peak, but for one "Guilty." at 0.85, about 40 ms ahead of the word at -16 dB,
heard right by Whisper.

**Open:** "Ha." alone at Pace 0.85 is still misheard (one word now and no phantom; a one-word sentence reads on
a pack's weakest row). Where in the model the silent stretch comes from is not traced.

### Not in the trial, and what would be lost

- **`noise_scale` and `noise_w`** have no meaning: Kokoro's prosody is fixed for a text and a voice. The Tone
  presets' `noise` and `noise_w` columns, the delivery leans that move them and `_discourse_plan`'s `noise_w`
  do nothing on these voices; best-of-N would have nothing to vary. `noise` (how lively the melody is) would
  map onto a scale of the F0 curve's range once F0 is an input; `noise_w` onto a seeded jitter of the plan.
- **904 readers become 28 packs** of uneven quality. Partly made up for: packs blend linearly, and the timbre
  half and the prosody half mix apart: a continuous space where libritts is a list.
- **A coarser plan:** 25 ms frames, every token at least one. Piper times P B M at 12-24 ms; stress, the
  opening floor and the trail's rime move in steps twice as large.
- **The pause figures are Piper's** (`DWELL`, `PAUSE_AFTER`, the floors): measured on Piper voices. Kokoro
  dwells on its own marks (in one sentence the comma's own token 1 frame and the final "d" of a sentence 12,
  300 ms, before the full stop's 6). The seams come out nearly right (`_trim_ends`); the commas needed their
  own window ("Rests and fades").
- **F0 is not an input yet:** the arc and the Tone still resample and restore formants. Splitting the graph at
  `F0Ntrain` -> decoder would make pitch a curve the host writes: the pitch accent on a stressed word ("Still
  proposed" 4), the trail's sag and the delivery steps without a resample.
- **The vowel probe** is not run (what it measures is a Piper checkpoint's).
- **Provenance:** Apache-2.0 weights, but hexgrad trained partly on synthetic audio from closed commercial
  voices.

### Fine-tuning (looked at, not built)

- **No official training code.** hexgrad's FAQ: continuing training is not feasible without the models that
  were not released (the style encoders, the discriminators).
- **A community recipe works:** [kikiri-tts](https://github.com/semidark/kikiri-tts) (Apache-2.0; German)
  converts `kokoro-v1_0.pth` into a patched StyleTTS 2 trainer: stage 1 the decoder adversarially with a fresh
  style encoder and fresh discriminators, stage 2 the durations, F0 and energy; a voicepack is the mean of the
  style encoders' outputs over the speaker's clips. It needs StyleTTS 2's ASR aligner, JDC pitch extractor and
  PL-BERT (training only). Their single-speaker fine-tunes used 455 and 627 clips; our Utterances make 1,087
  (88 minutes) of one actor. "10GB+ VRAM", batch 4 on 12 GB: with another trainer on the card about 8 GB is
  free, and the Piper run died at 8.3.
- **A cheaper first step:** the model frozen, only the 256-number style fitted to the clips (a few minutes,
  little memory): the timbre partway, nothing outside what the model can already say.
- **One clip to a voicepack, zero-shot:**
  [kokoro-inno-clone-tuner](https://huggingface.co/remsky/kokoro-inno-clone-tuner): Kokoro frozen, a speaker
  encoder (CC BY-SA 3.0) to the timbre half, a blend of stock packs for the prosody half; speaker similarity
  0.288 on LibriSpeech test-clean by its own count, one 3-30 s clip. Shallow, as it says; the style fit above
  can use hours.
- **Built instead: our own loop** ("Training Kokoro", below): the decoder and the prosody predictor taught,
  not only the style.
- What the Piper voice lacks is clarity (15.9% of words misheard), not tone; a far stronger base should help
  that, but 93 minutes of one register is the same limit.

### Other models (surveyed again 2026-10-25)

What ghost's reading leans on: phoneme input (the homographs, the lexicon), a duration plan per phoneme (the
rests rendered, stress, the trail, the hesitation), exact phones and words (subtitles, the desk's pen, an
actor's mouth), and a CPU faster than real time. Kokoro keeps all four; nothing newer does.

- **Better tuning, and they give up most of the four** (codec language models): VoxCPM2 (2B, Apache-2.0,
  official LoRA from 5-10 minutes, about 20 GB to train), Qwen3-TTS (0.6B/1.7B, Apache-2.0, official
  fine-tuning, cloning, a GPU), Chatterbox Turbo (350M, MIT, community fine-tuning), NeuTTS Air (748M,
  Apache-2.0, a CPU via GGUF, a fine-tuning script), Pocket TTS (100M, CC-BY-4.0, cloning on a CPU).
  MOSS-TTS takes IPA and a token count for the length, but is 1.7B and 8B. None hands back timings (a forced
  aligner would have to), none takes a plan per phoneme, and an autoregressive model can skip or repeat words
  in a long reading.
- **Phoneme models:** StyleTTS 2 has the official fine-tuning script Kokoro lacks, but older weights whose
  license asks listeners be told the speech is synthetic; Supertonic 3 (99M, faster than Kokoro on a CPU) is
  OpenRAIL-M, its repo archived, no training code; MeloTTS is MIT and trainable but about Piper's quality;
  Inflect-Nano (4.6M) is buzzy.
- One CPU benchmark (four Xeon cores): Kokoro 1.6x real time, UTMOS 4.44; Supertonic 3 4.2x, 4.32; Pocket
  TTS 1.4x, 4.10.

**Next, after listening:** Kokoro's own dwell measured and the pause figures made per backend; F0 as an input
(the Tone's `noise` as the F0 range); then, for an actor, the style fit before the recipe.

## Blending Kokoro voices

Goal: new voices synthesized by merging tensors (averaging, interpolation, weighted merges): a toggle per
reader in Browse…, a pick-list of merging options, and a Test at the top of Browse… (so voices can be tried
without closing it).

**What is merged is the pack, not the weights.** A Kokoro voice is a style pack, [510, 1, 256] (a row per
sentence length): the first 128 numbers of a row are what the decoder is given (timbre), the last 128 what the
duration, F0 and energy predictors are (prosody; Kokoro's `ref_s[:, :128]` / `ref_s[:, 128:]`, StyleTTS 2's
acoustic and prosodic styles). Every pack of a checkpoint runs on the same graph, so a blend costs nothing to
run. What the community does: Kokoro's own `voice="af_bella,af_sky"` is the packs' mean; Kokoro-FastAPI,
PyKokoro and kokoro-tts take weights (`af_bella(2)+af_sky(1)`, normalized); a ComfyUI node adds slerp, said to
keep more of each voice than the mean, which shrinks the vector; kvoicewalk random-walks a pack toward a
target recording, scored by Resemblyzer.

### Built

- `hosts/voice/blend.py`: the line (`mix: af_heart 2, bf_emma 1`, `split british: af_heart sound, bf_emma
  delivery`) and five methods: **Mix** (weighted mean), **Mix, kept full** (spherical: each half's length put
  back to the readers' own), **Sound and delivery** (one side's timbre, the other's prosody; a part per
  reader), **Max** and **Min** (number by number, weights unused).
- The Kokoro backend reads a request's `blend` into a pack made of the checkpoint's own (`_blended`, eight
  kept made), read in the heaviest reader's accent (a split's delivery's) unless the line says one. The
  backend says it blends (`describe`), never a voice's row: every field of a row keys the takes kept in that
  voice, and one added would make every kept Kokoro sentence again. A voice taught here (one pack, its own
  decoder) never blends.
- `VoiceBlend` (`src/voice/`) writes and says the line; `ReaderBrowser` (`src/reading/`) is Browse…: on a
  voice that blends, every reader is a tick with a weight (and a part in Sound and delivery), the method and
  accent along the top, Test first. The tab keeps `blend:` beside `speaker:` (the note's voice block,
  `SLOT_DEFAULTS`); stepping the Speaker number or picking another voice ends it. A blend is asked only when
  there is one, so no kept take's key moved.
- Test at the top of Browse… is the Voice card's own (`ReadingCast.press_test`): a press while it plays always
  stops it, and the next press reads what is ticked then. Nothing ticked is allowed on the way to another
  reader; the tab reads on in what it had. The browser is at most 80% of the stage's height, its summary one
  line.
- Gates: `hosts/voice/test_kokoro.py` (11), `tests/voice/voice_blend_check.gd` (the same lines read alike in
  both languages), `tests/reading/reader_browser_check.gd`.

### What was measured

Four sentences in four pairs (Heart+Emma, Heart+Puck, Emma+George, Bella+Michael) through the real v1.0 graph,
ten ways each; `dist/kokoro_blends/` holds every take (gitignored).

- **Every word heard in every take** (Whisper medium.en on all 46): being understood does not tell the methods
  apart; only the ear can.
- **The level, from the readers' own** (a blend is never measured: a weight moved is a new blend, and each
  would wait seconds and leave a row in levels.json). Spoken level against the weighted geometric mean of the
  readers' levels: mix 1:1 and 3:1 within 0.5 dB; kept full (spherical) up to -2.4 dB; sound of A with delivery
  of B within 2.3 dB (a split's level is its sound's: the decoder makes the level, so a split is estimated
  from its sound side alone); max up to -1.6; min up to +0.7. A mean shrinks the style (Heart and Emma, 1.59
  and 1.67 in a row's timbre, mix to 1.46); kept full puts it back, and came out quieter than estimated.
- Left out of the list, the files kept for the ear: strongest-of-each, mosaic and extrapolation (their levels
  miss by up to 4.4 dB).

### Status

Built, gated and heard: most blends sound good, some with mild artifacts, and Max is the favorite (the closest
to the voice wanted from a male and a female reader). Open by ear: whether kept full sounds fuller than the
mix or only louder, and whether Min earns its row. Not built: blending libritts's readers (Piper's speaker
embedding is a Gather inside the graph, patchable the way `rest_floor` was), blending across checkpoints
(v1.1's decoder was retrained), a blend saved under a name of its own, voice arithmetic (A + B - C, an accent
moved), and a kvoicewalk-style search from a blend toward a recording.

## A Kokoro blend that moves

In the app, word by word: Browse… beside its list draws the voice across each paragraph ([VoiceShape]): each
reader's share as a band whose edges are dragged, the Breath and Push lanes, noise (Fixed or Wander, how far, and its
Seed - a number, so the draw heard is the draw shown) and Shapes to start from (`VoiceBlend.SHAPES`). While Test
plays, a playhead sweeps the lanes where the words heard stand, with each lane's value there, never stopping
(`ReadingAudition.place_now`: the second heard, its sentence's span gone through from its start to the next's, the rest
after its last word included). The line carries it (`max: am_santa 60/55/45/35/30, af_nicole
40/45/55/65/70; breath 0/0/0.1/0.25/0.4; noise wander 0.3 7`), one reader shaped is a voice (`mix: bf_emma;
breath 0.9`), and Max and Min take shares (the weighted mix plus the edge's reach past the plain mean; equal
shares are the old Max). The axes ship as data, `hosts/voice/kokoro_axes.json`, made by
`hosts/voice_train/kokoro_axes.py` (cosine 0.9999 with the prototype's).

A blend that moves is read token by token: the app says where each sentence starts and ends in its paragraph
by its words (`plan_span`, `ReadingPlan.place`; sent only for a line that moves), the host lays that over the
sentence's ids (`blend.rows_along`) and reads them through the graph that moves
(`hosts/voice/kokoro_moving.py`): the stock graph copied with its 73 style sites (each AdaIN's and
AdaLayerNorm's `fc`) and the duration encoder's Expand rewired to a style a token, carried onto the frames by
the graph's own alignment and smoothed over 125 ms, as the prototype does. The host makes it once beside the
stock graph (`model_moving.onnx`, 325 MB) and keeps it only if, fed one row for every token, it plans the stock
graph's frames exactly and sounds the same (level within 0.06%, spectrogram correlation 0.996 for a reader's
row). No graph, no span or a line that never moves: a sentence at a time. It costs about 1.5x the stock graph
(a 7.2 s sentence in 6.2 s against 4.2 s, three threads, the machine loaded), still faster than speech.

Measured through the host (`dist/kokoro_curves/app_moving/`): a reader's breath rising across each paragraph
lowers CPP 1.0-1.4 dB in a late sentence's first half and 3.0-3.2 dB in its second, against the plain reader;
a Max between two readers grows breathier from first half to second in nearly every sentence. Whisper heard
every word but a sentence-opening "I" that Max drops anyway.

The prototype beside it moves within a sentence: its scripts and a listening set of 22 files are in
`dist/kokoro_curves/` (gitignored; its README says what each file is).

### Built (the prototype)

- The voice_train PyTorch Kokoro (`kokoro_model.py`) with its style taken per token and per frame: `AdaIN1d`,
  `AdaLayerNorm` and the duration encoder accept a style [B, S, T], each AdaIN interpolating it to its own
  block's length. In float64 a constant curve renders the stock model's samples to 1.5e-8, and a curve held at
  0.5 renders the 50/50 Mix to the same.
- A curve is a path of anchor styles (any blend can be an anchor, Max included) and each id's place on it: the
  delivery half per token (the duration encoder), both halves per frame through the model's own alignment,
  smoothed over 125 ms. The level follows the sound's place on the path.
- Also driven inside the model: the predictor's F0, scaled per frame (a pitch move with no resample), and an
  offset along a measured axis.
- Programs: every sentence from one reader to another; a paratone arc that resets at each paragraph; that arc
  on the sound alone; breath on the last two words of each phrase; the sound following the model's own energy
  plan; on a three-reader path, asides toward one and emphasis toward another; a blend held per paragraph; a
  voice drifting through the voices' spread; six voices sampled from it.

### What was measured

- Breathiness (cepstral peak prominence) and effort (alpha ratio), 28 English voices reading four sentences
  each: Nicole's CPP is 14.4 dB, every other voice's 17.1-21.2. A ridge direction over both halves moves CPP
  2-3 dB across +-2 sigma in all four voices tried, monotonic, the level 1-2 dB lower. A difference-of-means
  direction in the sound half moves the alpha ratio about 15 dB across +-2 sigma, the level within 1.5 dB and
  CPP rising with effort. Leave-one-voice-out r 0.63-0.65.
- The voices' sound halves take 16 components for 90% of their variance, and no one of them is breathiness
  (the nearest, PC4, r 0.72).
- The model's own pitch scaled for Arc at full gives +1.4-1.7 semitones at a paragraph's top, the size of the
  app's Arc on Kokoro (+1.4-2.3), which is a resample and formant restore after the model, as its Effort is a
  filter.
- Whisper medium.en on all 22 files: no curve loses a word its held reference keeps.

### Status

Heard from the prototype: most of it sounds good, and the breath axis on Emma is the favorite, wanted over her
whole voice, not only toward a paragraph's end (the Hush shape, breath 0.9). Built in the app, word by word;
awaits the author's hands and ear on the lab. Not built: shapes keyed to the words rather than the paragraph
(the prototype's breath on a phrase's last words, asides, emphasis: the graph takes them already, the line has
no way to say them), and F0 and energy as inputs (the Arc made in the model).

## Training Kokoro

Our own custom training loop (other projects have legacy code that would be hard to work with). The test
voice: a 15-video ASMR channel (5.5 hours).

### The model, ours (`hosts/voice_train/kokoro_model.py`)

hexgrad's kokoro 0.9.4 modules (Apache-2.0) with PL-BERT's ALBERT written out under the checkpoint's own key
names: no `transformers`, no `huggingface_hub`. The checkpoint loads whole (only the AdaIN norms' affine
weights absent, as in Kokoro's own lenient loader). Measured against the voice host's ONNX graph: the same 42
frames for a sentence, id for id, and the waveform correlated 0.99, but 1.45 times louder: the export's
inverse STFT (Kokoro's `CustomSTFT`) leaves out the window normalization, 1.5 for its Hann 20 / hop 5. So the
host's Kokoro is about 3.5 dB over hexgrad's PyTorch; a voice taught here and written into that graph keeps
the host's gain.

### What it is taught on (`kokoro_data.py`)

- **Their sentences, Kokoro's ids:** Utterances with `"engine": "kokoro"` cuts at 24 kHz and writes the host's
  own ids (`KokoroBackend.ids_of`, the ids `_render_symbols` sends: test_kokoro.py holds them equal).
- **Each id's frames, by warping Kokoro onto them:** Kokoro says the sentence (the base voice, its speed
  matched to theirs) and its exact plan is carried onto their recording by DTW. Calibrated where the truth is
  known (two of Kokoro's voices warped onto each other; four pairs: men, women, American, British): log mel by
  cosine puts a boundary within a frame 94% of the time (median error 0), MFCCs 75-78%; through the whole
  preparation, one voice's plan laid on another's speech: 95% within a frame, 97% within two.
- **Pitch and energy as Kokoro's decoder reads them:** on its own speech, pYIN reads back the F0 it was given
  (median ratio 1.003, the middle half within 1-2.5%; unvoiced it is given about 0); StyleTTS 2's energy (log of
  the norm of an 80-band power mel, n_fft 2048, window 1200) correlates 0.995 with what it was given, about
  0.45 under it (0.15-0.70 by voice and sentence: `N_OFFSET`).
- **At Kokoro's level:** its own speech's loud frames sit at -27 dB (Sarah and Emma -24).

### The loop (`kokoro_train.py`)

PL-BERT and the text encoder held (Kokoro's reading of English); the decoder, the prosody predictor and one
style taught. The decoder teacher-forced on 1.5 s stretches: multi-resolution log mel (x45), then after 1,000
steps HiFi-GAN's multi-period and UnivNet's multi-resolution discriminators (fresh: Kokoro's were never
released), least squares and feature matching. The predictor on whole sentences: frames (L1 on the sum of
sigmoids, BCE per bin), F0 and energy (smooth L1). The AdaIN norms' own scale and shift held at 1 and 0 (never
taught by hexgrad, folded out of the graph). Six stretches a step (eight were 11.5 GB with the discriminators
and out of memory on a card the app shares), with the generator's residual blocks recomputed backward: about a
second a step on the 5060 Ti. On clean speech the loop does what it should: af_heart taught 2.5 minutes of
af_bella for 300 steps came 0.90 to 0.52 of the way in log mel, its long-term spectrum 2.0 dB off to 0.2, and
Whisper misheard 1.9% of its words before and after.

### Into the host's graph (`kokoro_export.py`)

The onnx-community graph's weights are not under PyTorch's names (weight norm folded, LSTM gates repacked i o f
c, some matrices transposed), so they are found by value: of its 556, 477 are a form of a checkpoint
parameter, the rest constants; every taught tensor reaches one, none is ambiguous but two ones-and-zeros
constants (left alone). The taught values are written into a copy of the host's patched graph, and checked: a
sentence plans PyTorch's frames exactly and sounds 0.995 alike (gain 1.45). The host lists such a voice from
`kokoro/trained/<id>/` (graph, tokenizer, one pack, voice.json) beside the checkpoints, one speaker, never
fetched (test_kokoro.py).

### What their recordings taught (measured 2026-10-26)

Every voice is judged on twenty unseen sentences (188 words) by Whisper medium.en (base.en misheard a third of
their own real speech, so it could not judge a voice of them) and by its long-term spectrum and pitch against
their own.

| | words misheard | spectrum off theirs |
|---|---|---|
| stock af_heart | 1.1% | 4.0 dB |
| first run, their 12 minutes as cut, step 1,000 | 43.6% | - |
| the room gated out | 33.5% | - |
| ...the decoder's AdaIN projections alone taught | 20.7% | - |
| strict sentences, the whole decoder, its own delivery | 33.0% | 1.7 dB |
| **strict sentences, the whole decoder, Kokoro's delivery** | **4.8%** | **1.6 dB** |
| ...with their own pitch and energy, Kokoro's timing | 10.1% | 1.4 dB |

**Why, each found and measured:**
- **Their words were not what their sound said.** A sentence's words came from hearing a whole 20-minute video,
  its cut laid by those words' times: heard again alone, 83 of 192 said exactly their text. On clean speech,
  alignments a median 2 frames off alone took the words misheard from 1.1% to 33%. Now each sentence is heard
  again alone and cut to the words its sound says (hosts/speech/agree.py: 85 of 192 kept, 4.6 minutes).
- **Their room:** soft ASMR speech about 19 dB over a high-gain microphone's hiss; the decoder learned to make
  breathy noise. A stationary gate (`kokoro_data.quieted`) takes the room out of every sentence.
- **Their energy never fell to Kokoro's silence** (their quietest twentieth 8 log units over it, even gated):
  mapped quantile for quantile onto the energies Kokoro planned for the same sentences (`kokoro_range`).
- **Their delivery costs the words:** taught, the predictor's timing (warped from another voice onto soft
  speech) and its pitch and energy threw the taught decoder; each part alone stayed clear (the taught
  predictor through the stock decoder 1.6%, the taught decoder on stock curves 4.3%), together 33-56%. So
  Kokoro's delivery is kept by default (`"predictor": "kept"`): the decoder and the timbre half of the style
  taught, the pack's prosody half the base's, row by row.
- **Tried and dropped:** a monotonic alignment search over a small model of their sound, started from the warp
  (on theirs it crammed 53% of phonemes into one frame); teaching the decoder's AdaIN projections alone (4.8M
  of its 53M: no clearer than the whole); Whisper's encoder as the warp's features (as consistent as log mel).

**The data:** 15 videos, 5.5 hours; 6,878 words heard by medium.en; two videos left out by content (a collab
with another person, a character voice); the one-voice rules kept their soft voice once CLEAN was made relative
(`CLEAN_FROM_BEST`) and RATE's ceiling raised: 12.1 minutes, 4.6 once agreed.

### Built

The Voice training card is Kokoro's: Fetch (sound alone), Probe, Hear, Utterances (three phases: cut in
Kokoro's rate and ids, each sentence heard again by Whisper medium.en and cut to its words, written again) and
Voice (hosts/voice_train/kokoro_voice.py: prepare, teach, export into the host's graph, publish to
`<data>/ghost/voices/kokoro/trained/kokoro-<id>/`). The voice host lists such voices (test_kokoro.py). Whisper
medium.en and Kokoro's PyTorch checkpoint are files of the training environment (fetched by those who train);
agree.py runs medium.en on the graphics card where CTranslate2 reaches CUDA 12's libraries, else on the
processor. Gates: voice_training_check; hosts/voice/test_kokoro.py, test_utterances.py;
hosts/voice_train/test_kokoro_train.py; hosts/speech/test_agree.py.

**Listen** (`dist/voice_ab/kokoro_trained/`): `stock_heart/`, `manzanita_timbre/` (the card's recipe: their
timbre, Kokoro's delivery), `manzanita_intonation/` (their pitch and energy too, Kokoro's timing), `theirs/`
(their own sentences): four unseen sentences each through the voice host's whole path. Both trained voices are
also on every Voice card.

**Open:** more of their speech (4.6 minutes is little); CTranslate2 on the graphics card in the app (its CUDA 12
libraries are not in the speech environment; medium.en on the processor is slow); a better aligner than a warp
from another voice; teaching their delivery once the data is clean enough to carry it.

### The user's ear

The card run end to end in the app (13 ticked videos) sounded unusable: static and electricity, very robotic.
What was found afterwards:

- **The judges never taught a single voice.** The discriminators join at ADV_AFTER (1,000 steps), and every
  voice made (each research run, both published voices and the card's default `kokoro_steps` 1,000) stopped at
  step 1,000: the decoder was taught by log mel alone, which leaves its phase free (a vocoder's buzz).
- **The words-misheard and spectrum figures never heard static.** Measured on eight unseen sentences: between
  words the trained voices' floor is 46-47 dB under their speech, stock Kokoro's 70 (their own recordings: 26,
  the room the gate was meant to take out).
- **The card's run had a third of the research data:** 46 sentences cut, 28 agreed, 1.4 minutes (research:
  4.6), because the Hear step's small Whisper was unsure of most of her words.
- Her ordinary speaking voice is about 12 of 5.5 hours (the rest whispered), and Kokoro's delivery is kept:
  af_heart's rhythm and melody in her timbre.

**Then, of the research voices:** like the actress, but muffled and tinny. Tried, each on the 20 unseen
sentences (edges: the quieter of a take's first and last 100 ms, under its speech; floor: its quietest tenth of
frames under its loudest; words misheard by medium.en, of 188; two or three either way is the swing between
checkpoints):

| | edges | floor | over 6 kHz | misheard |
|---|---|---|---|---|
| stock af_heart | -68 dB | -71 dB | -15 dB | 1.1% |
| "(their timbre)": step 1,000, log mel alone | -40 | -47 | -24 | 4.8% |
| "(judged)": on to 2,000, the judges teaching | -42 | -49 | -23 | 5.9% |
| "(quiet edges)": the same, Kokoro's pads silent in what it is taught, 2,000 | -66.5 | -60 | -23 | 9.0% |
| ...3,000 | -66.7 | -57 | -25 | 7.4% |
| ..."(her pitch)": 3,000, Kokoro's pitch x1.15 | -67 | -56 | -26 | 9.0% |
| ...4,000 | -66.5 | -53 | -25 | 12.2% |

- **The hiss at a sentence's ends was taught:** the warp gives each sentence's first pad (median 6 frames)
  whatever starts their clip (a breath, a word's tail, the room, 14 dB under their speech) where Kokoro's own
  pads are silence. Faded to nothing in what is taught (their energy there the sentence's quietest,
  unvoiced), the voice's ends are Kokoro's (-66.5 dB).
- **The gate does not thin them:** it takes 0.1-0.9 dB of their voice below 8 kHz and about 5 dB of hiss
  above.
- **Muffled, measured:** against their own recordings the voices lack 3-6 dB between 2.4 and 8 kHz (where
  stops and hisses are heard); the misheard words are soft stops ("parked" heard "park", "card" "car"); stock
  is 8 dB brighter than they are above 6 kHz.
- **Their pitch is not Kokoro's:** her voiced frames 190-289 Hz (median 220), af_heart's plan 96-275 (median
  192), a quarter of its frames under anything the decoder was taught on; no Kokoro pack is pitched as high. A
  ratio is written into the predictor's F0 head (its weight and bias; published 227 Hz).
- **Longer overfits:** 4.3 minutes; past 3,000 steps the floor rises and the words go.
- Harmonic share, cepstral peak and flutter put every trained voice within their own recordings' range: no
  measure here hears "electric". The three voices are on every Voice card for the ear ("(judged)", "(quiet
  edges)", "(her pitch)"); dist/kokoro_ft/evalset/ck/<run>/listen/said/ holds the 20 sentences of each.

### kikiri-tts read again

Would more of her data help, and does [kikiri-tts](https://github.com/semidark/kikiri-tts) show how to teach
Kokoro better? Its recipe (StyleTTS 2's two stages, patched; read in its fork `semidark/StyleTTS2`) against
ours:

- **Every voice it published is synthetic speech** (Polly voices: the base "51 speakers synthetic", 30,800
  clips; the two voices 455 and 627 clips). Clean, alike from clip to clip, no room: it shows the method works,
  not that it works on soft real recordings. Its data step filters by Whisper's confidence alone.
- **The decoder is taught on the curves it will be given:** stage 2 decodes the recording from the
  predictor's pitch and energy (`F0Ntrain`), not the measured ones. Ours is taught on hers and played on
  af_heart's (a quarter of its frames under anything it was taught on): the gap "taught decoder on stock
  curves" measured.
- **A speech model's ear on every step:** L1 between WavLM-base-plus's 13 layers for theirs and ours
  (`WavLMLoss`, weight 1, both stages), and in stage 2 a WavLM discriminator. Nothing of ours hears what
  sound is said; the misheard words are soft stops.
- **Its own aligner:** StyleTTS 2's ASR aligner (pretrained on LibriTTS, English) taught on the speaker's
  audio with a monotonic loss, soft attention half the time; ours is a warp from another voice.
- **Seasoned judges:** the voices start from a base whose discriminators had learned on 30,800 clips,
  adversarial from the first step (a relativistic term besides least squares); ours start fresh on 4.6
  minutes and overfit past 3,000.
- **A style per clip:** a style encoder reads each clip and the voice is their mean; ours is one style for
  every recording.

**More of her:** four of the 13 videos read gave her ordinary voice (12.1 minutes before agreement);
whispered, no-talking and soft-spoken videos gave none. More data narrows the gap in clips, but misplaced cuts
should not average away: a loss frame by frame learns a burst placed early in one clip and late in another as a
smear at both (muffled, a stop lost), and more data makes the smear surer, not sharper. Untested at scale; a
Kokoro voice's own speech, jittered as before at 2.5 and 20+ minutes, would say.

### The kikiri revisions tried (2026-10-27, the night)

With 58 more videos (12.8 hours). Measured as before: twenty unseen sentences, words misheard by medium.en of
188; the floor and what is over 6 kHz; and each band against her own held-out recordings, the level matched
under 2.4 kHz (bands.py). Scripts and runs in dist/kokoro_ft/ (scratch/night.sh, after.sh), every voice for the
ear in dist/voice_ab/manzanita_night/.

**More of her, and what stood in the way:**
- **Whisper's voice-activity filter dropped her speech whole.** Hear runs Silero's VAD (`vad_filter`,
  hosts/speech/transcribe.py; the card's Hear too): 36 of 73 videos heard no word; without it, 69,439 words
  against 7,989. What Whisper invents in silence the utterance and agreement steps leave out. Not changed in
  the product: Hear serves an actor's mouth too, where words invented in silence would move it; proposed for a
  voice alone.
- **"Their usual pitch" was the search's edge** (fixed: utterances.py `signature`, test_utterances.py): 109
  runs read exactly 300 Hz (a correlation that only falls peaks at the shortest lag searched), and the register
  came out 300 Hz against her voice's 205-235, keeping 6 minutes. A pitch is now the correlation coming back:
  register 207.6 Hz, 30 minutes from 9 videos before agreement (the first data: 12.1 from 4), 209 sentences
  agreed, 12.2 minutes (4.6).
- **More data alone is not clearer:** 9.6% misheard, and duller (7 dB short from 2.4 to 8 kHz). Its nine
  recordings' 4-8 kHz differ by 9.5 dB and are taught as one voice.

**The loop** (kokoro_train.py `"predictor": "pitch"` and `"ear"`, wavlm.py):

| | misheard | floor | over 6 kHz | 2.4-4 kHz | 4-8 kHz |
|---|---|---|---|---|---|
| stock af_heart | 1.1% | -71 dB | -15 dB | -3.1 | -2.8 |
| "(judged)", the first data | 5.9% | -49 | -23 | -3.2 | -2.3 |
| "(quiet edges)", the first data | 9.0% | -60 | -23 | -4.5 | -3.3 |
| the first data, the ear | 8.5% | -56 | -24 | -3.8 | -2.9 |
| the first data, pitch, played with its own | 15.4% | -70 | -22 | -4.5 | -1.4 |
| the new data, as before | 9.6% | -55 | -31 | -6.9 | -7.0 |
| the new data, the ear | 8.0% | -49 | -28 | -6.6 | -5.5 |
| the new data, pitch and ear, played with its own | 22.9% | -70 | -22 | -4.5 | +1.1 |
| **the same, played with Kokoro's delivery: "(clearest)"** | **5.3%** | -61 | -25 | -5.7 | -1.3 |
| ...3,000 steps | 5.9% | -57 | -25 | -3.9 | -1.9 |
| the new data, taught on Kokoro's own curves | 20.2% | -68 | -27 | -1.5 | -0.3 |

- **The decoder is best taught on the predictor's curves and played on Kokoro's own.** Taught on them (its
  pitch and energy taught alongside, at her level) it is brighter and its floor quieter (Kokoro's curves are
  smooth where hers move twice as sharply frame to frame). But with no style read from the recording (Kokoro has
  none; StyleTTS 2 reads one from the target), the taught pitch follows hers r = 0.01, and played with it
  every word smeared: crossed, its decoder with Kokoro's own predictor said 5.9%, the clear decoder with the
  taught predictor 31.9%. So the export leaves a pitch run's taught pitch and energy behind
  (kokoro_export.py).
- **Taught on Kokoro's own curves** (its level, 192 Hz) the decoder learned to raise the pitch it was given
  (it says 230 Hz) and smeared the words: 20.2%. On the predictor's energy and her own pitch, 25.5%; its curves
  for half a batch, 21.3% (both dropped).
- **The ear helps a little and costs little:** 8.5% against 9.0, 8.0 against 9.6, each a dB or so brighter, no
  slower a step. WavLM Base+ is CC BY-SA 3.0, used only to teach.
- **Single runs:** two or three words either way is the swing between checkpoints; 5.3% against 9.6% is 10
  against 18.

On every Voice card: "Manzanita (clearest)" and "Manzanita (more of her)" (the new data with the ear). The
card teaches as before (kept, no ear, Hear with the VAD) until the ear has judged.

**Still open:** the floor between words (61 dB down, stock 71); 2.4-4 kHz 5.7 dB short; a style per recording.

## Chatterbox read

Is Chatterbox's 110M variant worth trying (inference first, tuning after), given Kokoro is likely a heavily
distilled model trained on synthetic examples? Read in `resemble-ai/chatterbox` and the safetensors headers on
Hugging Face:

- **"110M" is the language model alone.** Nano is Turbo's pipeline with a GPT-2 small T3 (85M in its layers;
  Turbo's is GPT-2 medium, 302M). Behind it is the same S3Gen as Turbo's: a flow encoder (38M) and decoder
  (73M, two meanflow steps), the HiFT vocoder (21M) and an x-vector (7M), and the speech tokenizer (124M), run
  only on a reference clip. About 330M to read a sentence. Files: 870 MB and 1.06 GB, fp32. MIT, not gated.
- **Text in as GPT-2's BPE of plain English, speech out as 25 tokens a second, sampled** (temperature 0.8,
  top-p 0.95, repetition penalty 1.2): no phonemes, no plan, no timings, a different take every time, and an
  autoregressive model can skip or repeat words. Nano and Turbo warn that CFG and exaggeration "will be
  ignored". Tags such as `[sigh]` and `[laugh]` are read. A built-in voice (`conds.pt`), so it reads with
  nothing cloned.
- **Every take is watermarked** (Perth, `apply_watermark`: one line in their code, MIT).
- **Dependencies:** torch, transformers, diffusers, conformer, s3tokenizer, librosa, perth, omegaconf (their
  pins ignored). "3x real time on 8 cores" is theirs; this machine's four cores are not measured.
- **What ghost loses** (the four the reading leans on, "Other models" above): the homographs, the lexicon, a
  word pinned; emphasis, the trail, the rests and the hesitation's rest; the words' times for the subtitles,
  the desk's pen and a cue at a word (a forced aligner would have to give them back; Whisper's word times are
  in speech_venv); and the same take from the same text.
- **Taught more easily, in one way:** neither half needs an alignment. T3 learns from text and her speech
  tokens (the agreed utterances are that), and S3Gen from her audio alone (her tokens to her mel, no text, so
  every hour of her ordinary voice, not only what Whisper agreed with). Only community scripts
  (`stlohrey/chatterbox-finetuning`, WIP, the original model; LoRA on T3 for languages); nothing official,
  nothing for Nano.
- **Voice conversion keeps everything Kokoro gives** (`vc.py`): S3Gen alone (speech to tokens to speech in
  the reference's voice, at a fixed 25 tokens and 50 mel frames a second), so a take comes back its own length
  and its word times hold to a token (40 ms). Kokoro would read as it does now and S3Gen re-voice the take; how
  much of Kokoro's intonation lives through tokens that keep mostly the words is for the ear.

**Proposed, nothing built:** inference only, a standalone script on a venv of its own: Nano with its built-in
voice, then with ten seconds of her; then a Kokoro take re-voiced by S3Gen into the same clip. Measured: the
speed on this CPU, words misheard (`hosts/speech/agree.py`), one sentence read five times, and the word times
after conversion.
