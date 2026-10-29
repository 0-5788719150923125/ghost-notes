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
  Cards reader is told what an asterisk does now (`TablePrompts.SPOKEN_RULES`).
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
check and the patch check say what they hold now), `tests/reading/multi_voice_check.gd`
(`_check_stress_reaches_the_voice`, and `play_ratio` in `_check_settings_reach_the_request`).

## Built (2026-10-07): the word before a rest, and the next word's hiss

Reported: "the end of a statement (most commonly at a comma) can sound a bit strange, and truncated
... clipped", and then "Wait until the end, sweet souls" heard as "ends ... sweet". Status: built,
gated, and confirmed by ear - "the best they have ever sounded" (2026-10-07; files: `8_commas_before.wav` against `9_commas_after.wav` and
`10_commas_after_trail2.wav`, the opening 30 sentences; `11_sweet_souls_before.wav` against
`12_sweet_souls_after.wav`, three short s-initial cases).

**What was measured.** The model ends every word at full level and drops it: the steepest 20 ms of
a word's end is 15 dB before a comma, 17 before a full stop, 17 mid-sentence (37 commas). It is the
same everywhere; a comma is where a rest of up to a second and a level pitch leave it standing alone.
And the word-space the rest floor lengthens takes the NEXT word's sound with it: before an /s/ the
model's lead (40-75 ms unfloored, its own coarticulation) grew to 165-195 ms of a 210-290 ms rest, so
the splice cut through hiss and left a burst on the word before (medians of five draws; 0-25 ms before
vowels, stops and most other fricatives). A second or third word-space after the mark only halved it,
and made other cases worse.

- **The trail** (`TRAIL_*`, `_trail_weight`) - the word before `, ; :` is held and lets go: its final
  rime (`_final_rimes`) rendered 1.25x through `dur_scale`; the level eased down 16 dB over the last
  120 ms to the voice's own end (found in the waveform: the plan is 50 ms early to 80 ms late) and held
  there through the rest; the pitch sagged 1.5 semitones over the last 90 ms (`_glide`, a slower read
  with the length kept; measured -0.13 / -0.70 / -1.31 semitones over three 30 ms windows into the
  tip). Weighted by the rest (full from 0.5 s), none at Pause 0; `trail` in the request scales it
  (0 off, 2 double; not on the panel yet). Full stops are left to the model and `_discourse_plan`.
- **The lead** (`LEAD_*`, `_quiet_lead`) - in a floored rest, the next word's hiss is kept to its last
  80 ms, coming in over 30 ms; what is earlier is silenced, so the splice always cuts in silence. In
  the finished audio: the burst left on the word before went from 20-60 ms to none, the "sss" before
  "sweet" / "so" from 195-265 ms to about 120 (the 80 kept plus the /s/'s own).
- `_resample`'s kernel and read are `_sinc_table` / `_read_at` now, shared with the glide
  (byte-identical to the old resampler, 35 cases).

Gates: `hosts/voice/test_trail.py` (new: the rime, the weight, the hold, the fade, the sag, the lead,
each with its control); `test_pauses.py` runs its splice and floor checks with `trail` 0, so turning
the trail off is pinned byte-identical to the old audio.

**Splitting chunks at commas as well** was weighed for the leak: the model would never see the next
word. Set aside because it takes more than it fixes - each clause would open at an utterance's pitch
and close with an utterance's fall (the comma's continuation contour is why a sentence is rendered
whole), and every clause's first word would be clipped the way a sentence's is (`OPENING_VOWEL`). The
leak is local and the plan says exactly where it is, so it is fixed there. If the ear still hears the
next word in a rest, splitting is the experiment to run next.

## Built (2026-10-11): a word's own hiss, and the next word's early start

Reported: the trail "seems to truncate the 's' at the end of its final word too early, such that it
turns plural words into singular words". Status: built, gated, waiting on the user's ear
(`13_plurals_before.wav` against `14_plurals_after.wav`: twelve sentences of the Cards reading with
a hiss-final word before a comma, then ten made ones, the last a singular for contrast).

**What was measured** (`final_s.py`, `final_s_frames.py`, `final_plural.py`; seeded, the note's own
settings). The model renders a final /z/ small: planned for one or two frames, 30 to 60 ms long, 25
to 35 dB under the take's peak. The trail looked for the voice's end 12 dB under the rime's peak, so
it stopped before that hiss or part of the way into it, and its floor then held the rest of it 16 dB
down, at the room tone:

| | hiss-final words | own hiss down over 6 dB | over 12 dB | next word's start dipped over 3 dB |
|---|---|---|---|---|
| made sentences, before | 26 | 20 (median 11.7 dB) | 12 | 4 of 31 commas (worst 23.5) |
| made sentences, after | 26 | 0 | 0 | 1 (a -40 dB murmur) |
| the Cards reading (127 requests), before | 18 | 9 | 5 | 20 of 83 commas (worst 24.4) |
| the Cards reading, after | 18 | 0 (worst 0.1 dB) | 0 | 1 (a blip 50 ms out in the rest) |
| before a hiss-initial word, 50 draws, after | 50 | 0 (worst 0.9 dB) | 0 | 0 |

In the finished audio, 31 hiss-final words: 4 had under 20 ms of their hiss left before the pause
(median 70 ms at -33 dB), now none (median 100 ms at -27 dB); no splice lands inside a hiss, and
nothing clips. The lead was innocent: `_quiet_lead` touched none of 100 own hisses.

- **The plan says which words, the waveform says where** (`_HISSES`, `_hiss_codas`, `_hiss_tail`).
  A word whose sounds after its last vowel hold s z ʃ ʒ f θ is looked at for its hiss, for as many
  runs as it spells ("asks," has two, a 70 ms closure apart; "last," one, so its /t/ keeps the
  floor). The voice ends before the hiss, the hiss is left at the model's own level, and the floor
  comes back after it. Words the plan does not name are byte-identical to before.
- **Looked for above 2 kHz, not 4** - a /ʃ/ has 94-100% of its energy above 2 kHz and 5-40% above
  4 ("hush, you." in the reading had the middle of its /ʃ/ floored by the first version of this).
- **The voice falls no further than its hiss** - the fade's depth is the vowel's level over the
  hiss's, at most TRAIL_DB: the whole 16 dB before a quiet /z/, about 8 before "hush,".
- **The next word can start before the plan says** (10-30 ms): the far side of the rest is walked
  back to where its sound begins (`_sound_from`, at most TRAIL_EARLY), so the floor lets go first
  and the search for the voice's end cannot land on the next word ("a horse, a voice").

Gates: `hosts/voice/test_trail.py` (nine new checks, each with its control: a hiss the plan does
not name is still floored, one run where two are spelled, 4 kHz instead of 2, TRAIL_EARLY 0).

**A duration floor on the final hiss was weighed and set aside** (`hiss_floor.py`, like
OPENING_VOWEL): it lengthens a voiceless /s/ about 10 ms a frame, but a voiced /z/ - the short
case - only gets longer as voice (hiss 65 / 70 / 90 / 115 ms at 0 / 4 / 6 / 8 frames in the median,
"hands" 55 / 40 / 35 / 60), and every floored word grows by the floor.

**A delivery mark started a sentence late** where its passage opened on something stripped (a
comment and a blank line): `_resolve_marks` noted marks before the leading whitespace went
(`tests/reading/multi_voice_check.gd`, `[0, 0, 0.5]` before).

**Found on the way, not built** (the review of the whole voice path, 2026-10-11):

- *A delivery mark is under what can be heard.* One step is pace 4% (about 2% in the audio: most
  ids sit on the one-frame Ceil), pitch 0.33 st, effort 0.2 dB, eased half a sentence at a time;
  the model's own sentence medians wander about a semitone. The Cards reader writes one in most
  episodes (over 1000 marks; `dry`, `quicker, brighter`, `softer` lead). The pitch is on the
  formant-locked path, clamped at 1.5 st in the host, so there is room: `15_delivery_today.wav`,
  `16_delivery_x2.5.wav`, `17_delivery_x4.wav` (`listen_delivery.py`). The steps are pinned small
  by `multi_voice_check` on purpose; the ear decides.
- *Dead with one sentence per request*: the length-conditioned rate (`rel` is always 1) and the
  alternating `noise_w` (always the plus side) in `_discourse_plan`. Both under 2% at typical dials.
- *A hold's cut* (`rests`, `_splice_holds`) is searched only in the plan's gap, which after a
  hiss-final word with no mark can lie inside the hiss: part of it lands after the hesitation.
- *A failed request carries no id* (`VoiceHost.failed`): the live reading waits on that chunk for
  good, and an export awaits `synthesized`.
- *The outro mark's fade is in the export take and in the render's master ramp* (twice);
  *live and export hash different text for their seed* (unstripped against stripped);
  *a chain stage at 0 on one voice keeps its state frozen* across a handover.
- `_effort` and `_emphasize` end in a hard clip: none at the note's settings (0 samples at full
  scale in 23 takes), reachable at the top of the Effort dial.

## Built (2026-10-16): a word eSpeak has to guess at

The report, on a Proof lesson about the six trig functions: cosine said "co-seen", cotangent
"co-angent", cosecant "co-seh-cant". eSpeak, which the neural voices are phonemized by, gave
kˈoʊsaɪn, kˈoʊtændʒənt and kˈoʊsɛkənt: the core syllable unstressed in each - and
en_US-libritts-high slurs a full vowel given no stress - and cosecant's vowel wrong. A dictionary
alone does not settle it (Wiktionary's US cosine is /ˈkoʊ.saɪn/, eSpeak's own pattern; CMUdict has
none of cosine, secant, cotangent, cosecant). Two clips of the sentence in the user's voice, as
read and with the core syllable stressed: "B sounds quite a bit better".

So `hosts/voice/lexicon.py`, for a word the reading marks `rare` (not `Phonemes.is_known` - the
audit's UNKNOWN - and spelled as written): its reading is Wiktionary's American one where Wiktionary
has it (kaikki.org, one JSON file per word, fetched once into `<data>/ghost/voices/lexicon/`,
rewritten into eSpeak's spelling and checked against the voice's phoneme map), else eSpeak's; then
every full vowel left unstressed gets a secondary stress. A word eSpeak knows is never touched -
its transcriptions are what the voices were trained on. The request's `lexicon` is "fetch" in the
app and "off" in any read-only process (`ReadingPanel._request_args`), so a gate is the same on
every machine. `hosts/voice/test_lexicon.py` holds the three readings of the report.

Live, on a lesson's words: Pythagorean pˈaɪθɐɡˌɔːɹiən -> pɪθˌæɡəɹˈiːən, axiom ˈæksɪəm -> ˈæksiəm;
secant, tangent, trigonometry, radians and Euclid unchanged. A name Wiktionary lacks keeps eSpeak's
guess (Gelfond dʒˈɛlfɑːnd, the stress rule only). About a second a new word, once.

The first export after it "sounded exactly like the original" (2026-10-17): `rare` compared a
word's page spelling with its spoken one whole, and the page spelling keeps the word's marks, so
"cosine," "cotangent," and "cosecant." were never marked. `Phonemes.guessed` compares them with the
marks off (a word normalization wrote - a numeral, a letter's name - is still not one); g2p_check's
"guessed" holds the sentence, the old rule marking only "secant" in it.

## Still proposed

1. **Rests rendered, not spliced** - the comma rest whole from `rest_floor`, no digital silence
   (`2_native_rests.wav`). Needs the ear first.
2. **Final lengthening where it belongs** - done before a comma (the trail, above); a full stop
   still slows the whole sentence through `_discourse_plan`.
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
Chatterbox-Nano (110M, MIT, CPU, watermarked, no timings; its `exaggeration` dial is the original's - Nano
ignores it, read 2026-10-27). Pocket TTS
(100M) is CC-BY-4.0, gated, cloning only. Non-commercial and excluded: F5-TTS, Spark-TTS, Llasa,
MaskGCT, OpenAudio S1. The worry that these are hard to steer is borne out.

**Order:** the duration plan in Piper first - begun, see "Built" above; then a Kokoro prototype
behind the backend registry (`hosts/voice/backends/`), whose explicit F0 input is the one thing
Piper cannot have. The prototype is built: "Kokoro" below.

## Kokoro (2026-10-25): an inference trial

**The user:** "What would it take to wire up support for a more capable generative voice model, such
as Kokoro? I'd want to make it available everywhere we currently use voice models ... and the
likeness/actor modes. Especially with the latter, that means fine-tuning support. Is it possible,
and would we lose any features by using a model like that one, instead of Piper?" Then: wire it up
for inference only - "I just want to know what this would sound like reading prose with other
modes, before I decide if we'll go for the fine-tuning aspect later."

**What Kokoro is** (read in hexgrad's `kokoro/model.py`, `forward_with_tokens`): StyleTTS 2 without
the diffusion, 82M parameters. PL-BERT reads the phonemes; a duration predictor plans each token
(`round(sigmoid sum / speed)`, clipped at one frame); the F0 and energy curves are predicted from the
aligned features (`F0Ntrain`); an iSTFTNet decoder takes the aligned text, F0, energy and the voice's
timbre. So the durations AND the pitch are tensors between stages - split the graph and both are
inputs. A voice is a style vector, 128 numbers of timbre (decoder) and 128 of prosody (predictor),
taken by token count from a `[510, 1, 256]` pack. At most 510 tokens a call. 24 kHz. A duration frame
is 600 samples, 25 ms (Piper's is 256 at 22,050, 11.6 ms).

### Built

- **`hosts/voice/backends/kokoro.py`** - `KokoroBackend(PiperBackend)`: everything around the model is
  Piper's path, unchanged - ghost's tokens, eSpeak's reading (homographs, the lexicon), the rest
  floors and splices, the trail, the lead, stress through `dur_scale`, the arc's pitch, the Tone
  played back, words and phones handed back. What it replaces is the model: the ids (one per symbol,
  a pad at each end, no blanks, no `LEAD_IN_SPACES` - Kokoro's first pad already rests 14 frames), the
  graph, the frame, the voices. Piper gained three hooks for it, each a no-op on Piper: `hop`,
  `_nominal` (the arc's length estimate, for a plan rounded rather than ceiled) and `_delivered`.
- **The graph** is onnx-community's timestamped export (Apache-2.0, 325 MB, pinned by commit),
  patched once where it is first opened (`_patch`), as a Piper voice is: `dur_scale` before the
  Round, `rest_floor` after, and `durations` handing back the whole frames the decoder used (the
  export's own output was the plan before rounding). Measured: unfed, the patched graph's audio is
  the stock graph's sample for sample; frames x 600 is the take's length exactly; nothing in it
  samples, so one text and one voice make one take.
- **The symbols** (`kokoro_symbols`): Kokoro's English was taught misaki's notation - a letter per
  diphthong (A eɪ, I aɪ, W aʊ, Y ɔɪ, O oʊ, Q əʊ), ʤ ʧ, T for the American flap, no American length
  marks, ᵊ for a syllabic consonant - so eSpeak's reading is written in it by misaki's own table for
  its eSpeak fallback. ghost's reading carries no tie marks, so a pair is merged where it stands in
  one word. The phones go back in eSpeak's symbols (A's time shared by e and ɪ), so Visemes and the
  desk read them as they read Piper's.
- **One voice, its packs the speakers** (2026-10-25, the user: "I really dislike how all of the voices
  are pushed into the 'Voice' list ... voice should be used more like a family of voices, then a
  secondary option should be for selecting the various checkpoints within"): the host lists one
  voice, `kokoro`, with 28 speakers - the English packs, a speaker number each in the fixed order of
  `PACKS` (a note keeps the number, so a pack is only ever added at the end) - and says who each is
  (`readers`: the pack, its accent, hexgrad's own grade; only af_heart A, af_bella A-, the men C+ at
  best). The Speaker row and its Browse… read them as they read libritts' 904 readers
  (`VoiceReaders.offer`). A British pack is read in British eSpeak. The graph and tokenizer are
  fetched on first use, a pack (half a megabyte) when its number is first asked for, into
  `<data>/ghost/voices/kokoro/`. A note saved with an earlier id (`kokoro-bf_emma`) reads in the
  picked voice until kokoro is picked again.
- **One rate:** rendered at 24 kHz, handed back at 22,050 through the band-limited resampler
  (`_delivered`), so a cast mixing Kokoro and Piper joins at the one rate a reading has. It costs the
  band from 11 to 12 kHz.
- **A sentence over 510 tokens** is read in pieces cut after a mark (`_pieces`), each with its own
  pads and style.
- **A take's ends trimmed to the seam** (`_trim_ends`, SEAM_LEAD 0.044 s, SEAM_TAIL 0.14): the gap
  between two sentences is spliced on Piper's measured silence at a take's ends (`DWELL`'s full stop),
  and Kokoro's own ends hold more - its first pad rests 350 ms, a sentence's mark, word-space and pad
  another 225 or so. On the passage below its seams ran 2.57-2.79 s where Piper's ran 1.89-2.06 at the
  same Pause (its commas, which the splicer measures, already matched: 0.80-0.94 s against 0.90-0.95);
  trimmed, 2.05-2.23 s - the rest is its own lengthening of a sentence's last word. Cut only where the
  plan holds no sound and the waveform is quiet, the frames with the audio, so every time stays exact.
- Nothing in Godot changed but the Voice picker's tooltip: the host lists every backend's voices, a
  take says its rate, and a voice with no Piper config has no readers.

Gate: `hosts/voice/test_kokoro.py` (fake session, no download: the symbols American and British, the
ids, the comma's floor, stress, times, phones and rate, the pieces, the rounded estimate against brute
force and against Piper's ceiled one, the patch on a toy graph and a graph of another shape refused).
Piper's own tests pass unchanged; `test_cadence`'s "old rule spread over 2x" is a draw from the
libritts voice's noise (1.92x once, 2.1-2.4x on three reruns, the committed backend's too).

**Measured on this machine** (i7-4790K, four cores, nothing else running): the raw graph 2.2x real
time. Through the whole host path, on three paragraphs of the Ephemeral Rift note: the actor's own
Piper voice (medium) 11.3x, libritts-high 3.8x, the Kokoro voices 2.5-3.2x. A first call loads (and
once, patches) the graph: 5 s. A live reading over a busy show has less headroom than on Piper.
At the same Pace the Kokoro voices speak 10-20% slower (45-51 s of speech against 41).

**Listening** (`dist/voice_ab/kokoro/`; `passage.txt` is the first three paragraphs of the Ephemeral
Rift note, read at its own pace 0.9 and Pause 6.5 through the host alone - no Tone, room or presence):
`1_actor_own_piper.wav` (the actor's trained Piper voice), `2_piper_libritts_high_s8.wav`, then Kokoro
`3_am_michael`, `4_am_puck`, `5_am_fenrir`, `6_bm_george`, `7_af_heart`, `8_af_bella`.

### The second round (2026-10-25 evening): families, every dial checked, the stall, a second checkpoint

**The user:** "if any of the standard voice options would not work with Kokoro, we should disable them
... I really dislike how all of the voices are pushed into the 'Voice' list ... During real-time
playback with Kokoro, playback kept freezing ... Are we doing the sliding window approach here as well?"
and "Are there any open source Kokoro checkpoints that may have higher quality? Specifically ... a better
female GB voice. 'Emma' is decent, but it's a B-, and it does click/pop sometimes."

**Every dial, checked by rendering** (`controls.py`: a passage with a comma, a stressed word and a
hesitation, each request parameter moved off its default alone): on Kokoro only `noise_scale` and
`noise_w` change nothing - the same request twice is the same take, sample for sample. Pace, Pause,
Dynamics, Arc, Effort, the Tone's pitch, whisper and muffle, a delivery's pitch and effort, Near's hush,
the speaker, the trail, stress and a hesitation all change the take; the room's dials (Echo, Room,
Resonance, Presence, Lean, Near, Ambience) are Godot's and act on any voice. So NO CONTROL IS DEAD and
none is hidden: the Tone keeps its pace, pitch, whisper and muffle on Kokoro and loses its liveliness.

**Two checkpoints, one voice each, their packs the speakers:** `kokoro` (v1.0, 28 English packs) and
`kokoro 1.1` (hexgrad's v1.1-zh, Apache-2.0: its English voices Maple, Sol and Vale - "an older British
female" - an hour each of crowdsourced synthetic speech, ungraded; the card: "not a strict upgrade").
Its export hands back the clipped plan already (`duration`), so `_patch` leaves that output alone
(`_reaches`); its vocabulary keeps v1.0's ids and drops ɚ, which the table writes əɹ anyway. Each
checkpoint is fetched into its own folder (`FAMILIES` `dir`) on first use.

**The clicks are the v1.0 checkpoint's, not ours** (`dist/voice_ab/probes/quiet_clicks.py`: impulses
standing out of quiet; the first 40 sentences of "What is the 7th Realm?", the note's own settings,
counted after every stage of the host path):

| voice | in the model's own output | in the finished take |
|---|---|---|
| Emma (v1.0, B-) | 172 in 219 s | 169 in 236 s |
| Isabella (v1.0, C) | 203 in 223 s | 222 in 233 s |
| Heart (v1.0, A) | 180 in 224 s | 181 in 238 s |
| **Vale (v1.1)** | **16 in 237 s** | **30 in 247 s** |

No stage of ours adds them on v1.0 (the lead, the trail, effort, the arc, the trims, the splices); on
Vale's quieter floor the splices and the rate change show a few. Listening:
`dist/voice_ab/kokoro_gb/` (the chapter's first paragraphs: `1_emma_v1.0`, `2_vale_v1.1`,
`3_isabella_v1.0`, `4_heart_v1.0_reference`).

**The stall: the window was Piper's, and the machine was busy.** Yes, Kokoro reads through the same
sliding window - and there is no finer stream to be had from it: it plans a sentence and decodes every
frame of it at once, so a sentence is the smallest unit it can hand back, which is how its own pipeline
streams too. The window kept LOOKAHEAD_SECONDS (9 s) ahead, sized for Piper (4-11x real time); Kokoro
made its takes 2.2-2.7x real time idle and 1.55x while other work ran (a gate run, renders and another
session's avatar Fit, during the test), and replayed through the stream's policy over measured takes
the old window ran dry once in 120 sentences at 2.2x, twice at 1.5x, fifteen times at 1.1x. Now:

- **The window follows the host** (`ReadingStream.depth`, `cost_after`, `_measure`): each take's cost -
  the seconds the host spent on it, from when it could start, per estimated second of its chunk - is
  measured as it comes back (rising at once, falling slowly), and the window keeps DEPTH_SAFETY (1.5)
  times what the next LOOKAHEAD chunks will take to make, never under 9 s (a fast host reads exactly as
  before) nor over DEPTH_MOST (45 s, the latency of a pace change).
- **The first sample waits for the next chunk** (`lead_for`): as long as it will take to make - a pause
  before the first word in place of one inside a sentence. Replayed: at 1.5x no stall where there were
  two (first sound after 10 s, was 2); at Piper's pace the first sound is where it was (0.74 s).
- **The graph is opened before Play** (`VoiceHost.ensure`, `ReadingPanel.warm_voice`; Kokoro's `ensure`
  opens and patches it): the first take no longer waits seconds on a 325 MB load. A failed `ensure`
  is not a failed chunk (`VoiceHost.failed` says which request failed).
- **A core is left to the show** (`KokoroBackend._options`): a thread a core but one and no spinning -
  2.60x real time with 2.6 cores busy, where the default made 2.70x with 3.9 of the four busy.

Gate: `tests/reading/stream_depth_check.gd` (boot probe; the replay's control: the old window runs dry at
1.5x, the new one does not, and at 4x both start at once).

**Faster still, not done:** the int8 graph (`model_quantized.onnx`, smaller and quicker on a processor,
some quality lost - to be heard first), or the graphics card (onnxruntime's CUDA build: tens of times real
time, but gigabytes of CUDA libraries in the voice environment, which is kept small on purpose).

### One-word sentences (2026-10-25, late)

**The user:** "I still like Emma the best. However, when I use the 'Test' feature, after 'Let's shuffle' -
the two words spoken after that are completely imperceptible ... I think it might be a bug with
single-word outputs." The Cards Test reads "Let's shuffle. Oh. Oh, wow." - a sentence a request, so
Kokoro was asked for "Oh." alone, three tokens (its own notes: weak under 10 to 20).

**Measured** (Whisper base.en on each take; `dist/voice_ab/kokoro_short/`):

- **Not the host's plan:** the raw model, with no processing of ours, says it the same ("Loved it", "As
  well"); the plan the host feeds it is the plan the model makes.
- **Two faults of the takes, both fixed:** (1) Piper's path ends every utterance on a word-space, which
  Kokoro was never taught - a short take ended on a sound 32 to 40 dB under its peak (Isabella's one-word
  sentences heard "Ose. Wouse. Nouse.") - and `KokoroBackend._symbols` now drops it; (2) on a sentence
  ending voiced, the model often lets go with a burst of hiss (on "Oh." 18 to 23 dB under the peak, 86 to
  99% above 4 kHz, in Emma and Isabella alike), and `_quiet_tail` lets go of what follows the waveform's
  last voiced run (TAIL_RUN frames) - only where the plan's last sound is voiced, never a final s, z, sh,
  f, th or a stop's release. After both, Isabella reads "Let's shuffle. Oh, oh wow." where she read "Ose,
  wouse"; Heart was right throughout.
- **What is left is Emma's:** "Oh" alone still comes out "Low", and "Wow" "Well" - even opening a long
  sentence, with Heart's prosody under her timbre, and with up to half of Isabella blended in. Only her
  timbre half does it (Isabella's timbre with Emma's prosody says "Oh wow"). Spelled as two symbols
  (`əʊ` for Q, `aʊ` for W - off misaki's notation), Whisper hears her right ("let's shuffle oh oh wow okay
  I'm getting chills"): `emma_shuffle_as_shipped.wav` against `emma_shuffle_split_diphthongs.wav`. Not
  made a rule: it changes every "no", "road" and "now" she says - the ear decides.

The Test passages are a minute long now (the default 75 s, Cards 60 s, Proof 55 s; they had been 12 to
25 s).

### Rests and fades (2026-10-25, night)

**The user:** "For Piper models, I believe we implemented a fade-in/fade-out at the start and end of
every sentence. Here, with Kokoro models ... it might be too long, causing a kind of clipping sound."

There is no fade at every sentence: what fades is clause-level - the trail before a comma (120 ms, 16 dB)
and the splicer's ramps where a rest is cut in (2 to 30 ms, by how loud the voice still is there). The
clipping was the cut landing on sounding voice, and its ramps fading the word out and the next one in:

- **A floored rest is not a rest on Kokoro.** Piper given frames on a word-space renders silence there;
  Kokoro holds the word through them (20 frames after "dawn," were 500 ms of voice 16 to 20 dB under the
  peak; on the comma itself, a slow decay). Every comma and hesitation had 150 ms floored, and the rest
  was cut through that hum. Now nothing is floored on Kokoro (the opening vowel still is), the word falls
  away by itself, and the splicer measures that and rests the remainder.
- **Its word edges are not its waveform's.** Over 198 commas of two voices the real gap lay from 130 ms
  before to 140 after the plan's boundary, so Piper's window (the word's end to a frame into the next)
  reached no quieter than 23 to 25 dB under the peak at half of them. Kokoro's window (`_gap`) runs within
  the two words, at most GAP_REACH (150 ms) from the boundary; the splicer takes the middle of the
  longest silence in it. And the trail's fade and the lead's cut, placed by the plan, are not made on
  Kokoro (superseded the next day: the plan was found to run 50 ms late, corrected, and the trail made
  again - "The plan runs late" below).

Where the rest is cut (the 5 ms before the cut, re the peak; 198 commas each):

| | in silence (under -40 dB) | -40 to -30 | -30 to -20 | louder than -20 |
|---|---|---|---|---|
| Emma, before | 56 | 45 | 57 | 40 |
| **Emma, now** | **114** | 53 | 25 | **6** |
| Heart, before | 67 | 41 | 56 | 34 |
| **Heart, now** | **122** | 47 | 19 | **10** |

**Left:** the commas Kokoro reads straight through, with no silence within 150 or 200 ms of either side.
A pad token after the comma rests there but the model fills round it ("Gently air carefully or slowly");
an ellipsis in its place barely rests. Listening: `dist/voice_ab/kokoro_gb/1_emma_v1.0.wav` (before)
against `1_emma_v1.0_now.wav`, the chapter's opening at its own Pace and Pause.

**Read through, or left unrested?** (the user: "Is Kokoro leaving commas unrested, or is it choosing to
read through them quickly, as a natural speaker might do?") Each sentence rendered with the comma and
without it (`commas.py`; 28 commas, two voices): at the commas it RESTS, the comma lengthens the word
before it by 150 to 200 ms, deepens the dip at the boundary by 12 dB and holds the pitch up (a
continuation: Heart +3.0 semitones over the word's end where without the comma she falls 1.0; Emma -0.6
against -2.4); at the ones it READS THROUGH (5 to 7 of the 28), it still marks them, lightly - the word
25 to 75 ms longer, the dip 2.5 to 5 dB deeper - with no continuation in the pitch. A quick read-through,
as of a list ("Gently, carefully, slowly"), not a comma ignored; a full Pause spliced in there forces a
stop on a word the voice did not slow for.

**Kokoro's own pipeline does NOT read in pieces at commas** (`kokoro/pipeline.py`, `en_tokenize`,
`waterfall_last`): it splits text at blank lines only, then packs as much as fits in 510 phoneme tokens
into ONE call - most often a whole paragraph, several sentences - and cuts inside that only when it must,
at a full stop first, then a colon or semicolon, a comma last. Splitting at commas is not its practice;
its practice is the other way from ours - a sentence a call is shorter than its best range (100 to 200
tokens), and its weakest case is the short one (the "Oh." of the Cards Test).

Gates: `hosts/voice/test_kokoro.py` (no rest floored; the window, with Piper's as the control; the lead
not made on Kokoro, made on Piper; and, below, a stop's release kept before the cut, the trail run up to
the next word without a step, the short last vowel held).

### The plan runs late: corrected (2026-10-26)

**The user:** "the 'h' from 'happy' STARTS on the left side of the comma, then continues into the right
... ANY break is going to sound bad there. This is EXACTLY why we had the fade-out for Piper." And then:
"Instead of cutting, I wonder if it would be easier to just process each side of the comma separately?"

- **Where the cut was:** in "Sore arms, happy heart." Kokoro reads the comma straight through - the z of
  "arms" runs into the h of "happy" with no silence - and the wide window's longest silence was the
  closure INSIDE "happy": the rest went in as "ha ... ppy" (Whisper, as shipped: "arms happy, be hurt").
- **Why:** Kokoro's audio runs ahead of its plan by a nearly fixed amount - the voicing the plan puts in
  each frame is heard a median 55 ms (Emma) and 48 (Heart) earlier over 20 sentences, the middle half
  within 15 ms, the same in a sentence's first half as its second. Every time the plan reports is now
  told PLAN_LEAD (50 ms) earlier - the words, their edges, the rests, the phones (so the subtitles and a
  mouth too) - the cut is looked for GAP_REACH (50 ms) either side of that boundary, and the trail (the
  word before a rest let go of: Piper's fade, the user's ask) is made on Kokoro again; the lead stays
  off (no rest is floored here, and a floored rest is what made the lead long). The cut after "arms,"
  now lands where the z ends; Whisper: "arms. Happy heart."
- Counted by where a rest's cut lands against where the next word's voice begins (29 commas): Piper's
  window on the uncorrected plan split the next word at 7 (Emma) and 4 (Heart), the wide window at 5
  and 3, the corrected plan's at 3 and 2.
- **Each side rendered on its own** (the user's question; `clauses.py`, 29 commas, both voices): the
  first part ends as an utterance - the word before the comma 650 to 775 ms where the sentence whole
  gives it 475 - and the next starts as a new one, 5.0 to 5.3 semitones above where the last ended (whole:
  1.2 to 1.7). Whisper writes those commas as full stops ("at 3. Then spent ... panels. Because"), and the
  clause alone came out "Saw arms every". Not taken: a comma would be heard as a sentence end. (Whether
  a short call is worse than a long one in general is hexgrad's note, not measured here: Emma's "Oh"
  was her pack's at any length; this isolated clause is one case for it.)

Listening (`dist/voice_ab/kokoro_batch/`, the three sentences at the note's own settings):
`A_as_shipped.wav`, `H_plan_corrected.wav`, `I_split_at_commas.wav`; and `D_no_comma_rest.wav`,
`B_with_previous_raw.wav`, `C_with_next_raw.wav` (the model's own reading, nothing of ours).

### A cut inside the word, and the way back up (2026-10-26, later)

**The user,** on True Tarot 626717 as uploaded: "'You've always felt it, haven't you,' - both of these
commas felt abrupt, like they truncated the sound badly. The 'it,' was almost acceptable, but the 'you,'
was clearly cut in the wrong place." The export was rendered again by the host, cut for cut.

- **"you,":** Kokoro holds the vowel straight through the comma into "my", no dip. The trail walked the
  next word's start back over sound (TRAIL_EARLY, 60 ms, measured on Piper) - on Kokoro that sound was
  the same vowel - so it faded half the vowel and let go one sample from 16 dB down to full level; the
  cut went in that dip, and the vowel's second half played after the rest, before "my" (Whisper, under
  the episode's bed: "haven't you, in my love"). Now the trail walks back none on Kokoro (its plan is
  corrected) and fades the vowel right up to the next word.
- **"it,":** the window reached GAP_REACH (50 ms) back into the word and found the silence of the t's
  closure, so the release went after the rest, a tick before "haven't". Now it reaches GAP_BACK (15 ms).
- **The way back up is never a step** (the user: "the cut should probably be a logarithmic fade-out and
  fade-in, not a linear one"). The splicer's own ramps were measured first: at every cut in the test
  sentences they are 2 to 5 ms long at 32 to 98 dB under the peak, so their shape cannot be heard -
  reshaped to fall at a steady rate in dB, the take differed by 0 to 3 ms at each cut and nothing else.
  The abrupt edge was the trail's: where the voice runs right up to the next word, TRAIL_BACK had no room
  and came back in one sample, 16 dB on sounding voice (8 of 80 comma trails in two voices). Now it runs
  on into the next word (`_trail`'s `through`), a fade in dB as it always was; 0 of 80 step.
- **The short vowel held, not every rime** (the user, after M: "I would want to hear MORE of the
  'you'"). Piper's hold is a ratio (TRAIL_STRETCH, 1.25) and on 25 ms frames it is wrong both ways: the
  "oo" of "you," (two frames) rounded back to two, and held 1.6 or 2.0 times "stays," and "flame," (five
  and six frames) were drawn out ("someone stayyys", "same flaaaame" - and Whisper began to hear commas
  as full stops). Now the last vowel of the word before a rest is floored at HOLD_LEAST (90 ms at length
  scale 1, the trail's share of it; "uː" shares it between its two symbols): over the six test sentences
  only "you" (+2 frames), "it" and "inward" (+1) moved; the rest are sample for sample as before.
- **Measured** (`dist/voice_ab/kokoro_commas/eval/`, 53 sentences with 83 commas - this episode's and
  the earlier passages - in Emma and Heart, a dark bed at -28 dB, Whisper): Emma's words misheard 35 in
  22 sentences as shipped, 28 in 18 with the cut moved; every comma-related change a fix ("Someone stay,
  as you shine", "same flame, a new", "A fight to climb", "Am I love?" gone); Heart 18 either way; "Sore
  arms," unchanged sample for sample before its rest.

Listening (`dist/voice_ab/kokoro_commas/`, Emma at the Narrator's settings, six sentences):
`listen_H_as_shipped.wav`, `listen_J_cut_moved.wav`, `listen_M_no_step.wav`, `listen_N1_hold_1.6.wav` and
`listen_N2_hold_2.0.wav` (the ratio, rejected), `listen_O_short_vowel_held.wav` (as built: the code renders
it sample for sample); `listen_L1_db_ramps.wav` (the splicer's ramps in dB: no difference).

### Every sentence ends alike (2026-10-27): the model's, not ours

**The user,** of north-star ch43 "Secular Haze" in Puck (speaker 13): "EVERY sentence ends with a downward
inflection ... the very last word ALWAYS sounds the same, with a downward curve. Like a valley girl accent."
Chapter 42 had read in Piper's libritts-high 13 and varied.

**Measured** (pYIN on the last word's OWN voicing - from its start until 40 ms unvoiced - against its
sentence's median pitch; "falls": over 1.5 st across the word; "no pitch": pYIN found none - creak, or under
60 Hz; "alike": mean correlation of the last words' contours, 1 every one the same), 22 sentences of the chapter
alone, as the reading sends them:

| voice | last word ends | falls | no pitch | alike |
|---|---|---|---|---|
| Piper libritts-high 13 | -1.4 st | 7 of 18 | 4 of 22 | 0.31 |
| Kokoro Heart | -1.1 | 3 of 14 | 8 | 0.02 |
| Kokoro Emma | -3.3 | 15 of 18 | 3 | 0.85 |
| Kokoro Puck | -5.1 | 5 of 11 | 11 | 0.24 |
| Kokoro Michael / Onyx / Fenrir / Liam | -3.2 / -3.8 / -8.4 / -5.7 | 5/11, 9/18, 9/14, 11/16 | 11, 4, 8, 6 | 0.32-0.77 |
| Kokoro Eric / George / Daniel | -8.6 / -10.3 / -6.4 | 18/19, 18/19, 15/19 | 2 each | 0.61-0.87 |

Every male pack falls, most into creak (Puck's half of its endings: the "valley girl" fry). Heart alone varies
as Piper did. Not ours: LEAD_IN 0 falls the same (Puck -5.7), nothing after the render touches pitch.

**What does not change it** (the 18 sentences another follows in their paragraph):

- **The words after it heard.** Rendered with the next sentence's first 2 or 4 words, or the whole of it, or
  inside its whole paragraph as one utterance: Emma -3.2, -3.2, -3.3, -3.1 st (alone -3.3), Puck about the
  same. Built, then measured through the host and reverted (the patch: next sentence's 4 words after the
  sentence, cut in the 120 ms of quiet Kokoro leaves at a full stop). AN ERROR TO NOT REPEAT: measured over
  the word's span plus 80 ms, these looked like a fix (Puck -3.3, Emma 0.0) - a span ends where the next word
  begins, and the window took in the next sentence's reset pitch. Measure a word by its own voicing.
- **Another mark** in place of the full stop, in what Kokoro is sent alone: `…`, `;`, `,`, `—`, none at all,
  and the vocab's unused `→`: Emma -2.7 to -3.3 st, 11 to 14 of 15 falling, every one; Puck -5.1 to -6.3.
  The fall is the utterance's end, whatever ends it.
- **The last word's stress** (eSpeak read without a break at the sentence's end demotes it, `dˈWn` ->
  `dˌWn`): the same fall.
- **`…` inside an utterance** (the next 4 words after it): Puck 4 of 10 falling at -4.0 st against 8 of 12 at
  -5.0 with a `.` there, 7 creaking against 5; Emma no change (11 of 14). Too weak and too mixed to build
  unheard - and it would cost the words' render (about 30% more processor time).

**The lever: F0 as an input** ("Not in the trial" below). The predictor's pitch curve is one tensor
(`/encoder/Reshape_output_0`, from `F0_proj`, read by the decoder alone) and so is its energy
(`/encoder/Reshape_1_output_0`, from `N_proj`). A listening prototype, NOT the product (the user, 2026-10-27,
wary it "would end badly, and just make it sound like asking a question, or chipmunk voice"; a copy of the
graph at `dist/voice_ab/kokoro_f0/model_f0.onnx` handing both out and taking replacements, run twice a sentence):

- **The ending is planned unvoiced.** Puck's last vowel is predicted at 0 Hz ("left": 100 -> 69 Hz into the
  l, then the whole ɛ at 0; "down": the W and the n; "are": the ɑ and the ɹ) - the fry is the plan, not the
  decoder.
- **Pitch alone does not voice it:** 100 Hz written across the word voiced two or three frames more. Pitch with
  the energy held through the last vowel voices it at the pitch written - and held whole, the last consonant
  (planned ~400 ms, the model's own fade) drew out ("downnnn"), so the energy is let go over 100 ms after the
  vowel into the model's own.
- **The demo** (the note's dials; a sentence another follows falls a seeded 1.5-3.5 st "gentle" or 0-1.5
  "level", a paragraph's last 4-6; never above the word's start, never up past its peak): the last word voiced
  in 20 of 22 sentences against 10 as now; measured median end against start -1.5 / -0.7 st, -4.2 as now.
  Still a rise heard back in places the curve written has none: "...know what you are" +2.7 st in both, "...a
  letter from a stranger" +1.0 in level. Files `now.wav`, `gentle.wav`, `level.wav` there. Waiting on the
  user's ear.

### It comes out hot (2026-10-28)

The user: "Even at max volume, the 'ambience' level is almost inaudible with the newly-implemented Kokoro
models." Measured on four paragraphs of Secular Haze through the real host, speaking RMS: Puck (13) 0.141 with
the note's dials and 0.148 without them, its takes at full scale (most sentences peak at 1.000, 198 samples
clipped in 59 s); Heart (0) 0.086, peak 0.93; libritts-high 0.065, peak under 0.6. Neither backend levels its
output - Piper only puts the level back after its effort filter - so the model's own level is what VoiceFX gets,
and the bed, at a fixed level, sat 17.7 dB under Puck where it sits 9 under Piper.

- **Fixed: the bed follows the voice** (`VoiceFX.PAD_VOICE_REF`, `_level_pad`): its level and its duck scaled by
  the voice's speaking level (the RMS of the windows the pitch tracker finds voiced, over 8 s of voice, primed
  with the key from the take's first 12 s), against libritts-high's (0.06), so Piper's bed is where it was and
  every voice's sits 8-10 dB under it. Gate: tests/voice/pad_level_check.gd.
- **Built: every voice at one level** (the user: "Especially if we're going to continue adding voice model
  support, we're going to want a sane way to keep the volume even across them all"; hosts/voice/level.py). Each
  voice and speaker is measured once, as the vowel probe measures a checkpoint: two plain sentences through the
  backend's own `_run`, nothing delivered, the noise off (a VITS render moved 0.7 dB from one to the next) and
  what the noise adds back as the backend says (`level_noise`, measured: libritts-high 1.14 and 1.16 over twelve
  renders; Kokoro samples nothing), its speaking level the RMS of the frames within 30 dB of its loud ones. Its
  gain is TARGET - libritts-high speaker 0's own level, so the default voice and the bed's staging are where they
  were - over that, applied to every take as it leaves the model, before the host's shaping. One gain a voice,
  never a take. Kept in `levels.json` beside the weights, by the model files' sizes and times. 2 to 4 s a voice,
  once. Measured: Puck 0.1315 (played at 0.42), Emma 0.1105, Heart 0.0853, Maple 0.0499, libritts-high speaker
  4 0.0333 (1.6). Read in the chapter after, the four voices' speech came within 1.2 dB of each other (they
  had been 7.7 dB apart) and none reached full scale (Puck had clipped 198 samples in 59 s). Gate:
  hosts/voice/test_level.py.
- **And the bed's tones** (the user, after: "a very strange tone being 'plucked' a few times per minute ...
  super distracting, dissonant ... always the same tone"): the bass swell, which at the bed's new level was
  heard at last. Its key had been the first voiced window's pitch, rounded to A440's grid - a reading opens
  high, and Puck's came out C where he speaks at A#, inside the key's hysteresis so it never moved - and its
  root sat in [41, 82) Hz whatever the voice, so on a low voice its partials were in his own register, the
  second (131 Hz) a whole step over his middle (115). Now the key is the voice's own (`KEY_HEARD`: the median
  of its first 3 s of voiced windows, primed from 12 s; `PAD_REGISTER`: the register a median of the last 20
  s - a Hz average had drifted 3 semitones up on the tracker's octave slips), never snapped to a grid; the
  bass's second partial stays a fifth under the voice's middle (`BASS_UNDER`), none under A0
  (`BASS_FLOOR`); and it swells over 1.2 s, not 0.35. The scale was never the fault: the bed's minor
  pentatonic has no two notes a semitone apart. Gate: tests/voice/pad_key_check.gd.
- **Then staged by the ear** (the user: "The ambience is far too quiet. I can barely hear it at all anymore"). In
  Puck's own key, a fifth under him, every tone of the bed was under 80 Hz: at the same power against the voice as
  libritts-high's bed (-6.7 dB), it was -30.4 dB A-weighted where the bed the user had liked on Piper is -22.1, and
  no small speaker plays it. Now a tone under 120 Hz takes octave partials (2x and 4x, 0.6 and 0.35 an octave
  under it; octaves only, so no note the scale did not choose) at its own power, and the tones are lifted by how
  much less audible their register is than the one the bed was staged in (`PAD_EAR_KEY`, `_audibility`: the
  A-weighting over every tone the bed can play) - Puck 1.40 (plain tones would have needed 3.25, 10 dB of
  sub-bass), libritts-high 1.10, Heart 1.03, a child's register 0.70. Measured A-weighted against the voice: Puck
  -19.2, libritts-high -21.0, Heart -20.2. The swell is not lifted: it is felt more than heard. Gate:
  pad_key_check ("heard under a low voice as under a high one").

### The happy vowel (2026-10-28)

The user: "babysitter" "sort of sounds like 'bay-bah-sitter'". eSpeak reads a word's unstressed "ee" (CMUdict's
IY0) as lax ɪ in compounds and before vowels - "babysitter" bˈeɪbɪsˌɪɾɚ where "baby" alone is bˈeɪbi - and in 65
words of North Star: "everything" (184 times), "anything" (165), "anybody", "everyone", "video", "radio",
"earlier", "happiness". Kokoro was taught on misaki's dictionary, which writes that vowel i, so it says ɪ as the
short vowel it learned: in Puck, "babysitter"'s middle vowel measured F1 360, F2 1670 - between ɪ and ə, the "bah".

- **Built** (`kokoro.py` `happy_vowels`, the hook `PiperBackend._dictionary_reading`): where the word's dictionary
  reading (the token's `fallback`) has IY0 and eSpeak ɪ in the same place, vowel for vowel, Kokoro is sent i -
  after a stressed syllable or before a vowel. An unstressed prefix before a consonant keeps eSpeak's ɪ ("pretend",
  "prepare", "prediction": the dictionary's IY0 is careful speech there, and "prih-tend" is how it is said), as do
  a word whose vowels do not line up, a word no dictionary holds (`rare`) and every word Piper reads (taught on
  eSpeak's own readings). Measured after, in Puck: F1 300, F2 2200 in both sentences tried - an "ee". Gate:
  hosts/voice/test_kokoro.py `test_the_happy_vowel`.
- **Open:** a voice taught here is taught on `ids_of`, whose tokens carry no dictionary reading, so it learns
  eSpeak's ɪ where it is now sent i; utterances.py would need CMUdict to match.

### Not in the trial, and what would be lost

- **`noise_scale` and `noise_w`** have no meaning: Kokoro's prosody is fixed for a text and a voice.
  The Tone presets' `noise` and `noise_w` columns, the delivery leans that move them and
  `_discourse_plan`'s `noise_w` do nothing on these voices; best-of-N would have nothing to vary.
  `noise` (how lively the melody is) would map onto a scale of the F0 curve's range once F0 is an
  input; `noise_w` onto a seeded jitter of the plan.
- **904 readers become 28 packs** of uneven quality. Partly made up for: packs blend linearly, and
  the timbre half and the prosody half mix apart - a continuous space where libritts is a list.
- **A coarser plan:** 25 ms frames, every token at least one. Piper times P B M at 12-24 ms; stress,
  the opening floor and the trail's rime move in steps twice as large.
- **The pause figures are Piper's** (`DWELL`, `PAUSE_AFTER`, the floors): measured on Piper voices.
  Kokoro dwells on its own marks - in one sentence the comma's own token 1 frame and the final "d"
  of a sentence 12 (300 ms) before the full stop's 6. The seams come out nearly right (`_trim_ends`);
  the commas did NOT, at first - see "Rests and fades" below.
- **F0 is not an input yet:** the arc and the Tone still resample and restore formants. Splitting the
  graph at `F0Ntrain` -> decoder would make pitch a curve the host writes: the pitch accent on a
  stressed word ("Still proposed" 4), the trail's sag and the delivery steps without a resample.
- **The vowel probe** is not run (what it measures is a Piper checkpoint's).
- **Provenance:** Apache-2.0 weights, but hexgrad trained partly on synthetic audio from closed
  commercial voices.

### Fine-tuning (looked at, not built)

- **No official training code.** hexgrad's FAQ: continuing training is not feasible without the
  models that were not released (the style encoders, the discriminators).
- **A community recipe works:** [kikiri-tts](https://github.com/semidark/kikiri-tts) (Apache-2.0;
  "fully functional" April 2026, German) converts `kokoro-v1_0.pth` into a patched StyleTTS 2 trainer:
  stage 1 the decoder adversarially with a FRESH style encoder and fresh discriminators, stage 2 the
  durations, F0 and energy; a voicepack is the mean of the style encoders' outputs over the speaker's
  clips. It needs StyleTTS 2's ASR aligner, JDC pitch extractor and PL-BERT (training only). Their
  single-speaker fine-tunes used 455 and 627 clips; our Utterances make 1,087 (88 minutes) of his.
  "10GB+ VRAM", batch 4 on 12 GB - with Praxis on the card about 8 GB is free, and the Piper run died
  at 8.3.
- **A cheaper first step:** the model frozen, only the 256-number style fitted to his clips (a few
  minutes, little memory) - his timbre partway, nothing outside what the model can already say.
- **One clip to a voicepack, zero-shot** (looked at 2026-10-26):
  [kokoro-inno-clone-tuner](https://huggingface.co/remsky/kokoro-inno-clone-tuner) - Kokoro frozen, a speaker
  encoder (CC BY-SA 3.0) to the timbre half, a blend of stock packs for the prosody half; speaker similarity 0.288 on
  LibriSpeech test-clean by its own count, one 3-30 s clip. Shallow, as it says; the style fit above can use hours.
- **Built instead, the same day: our own loop** ("Training Kokoro", below) - the decoder and the prosody predictor
  taught, not only the style.
- What the Piper voice lacks is clarity (15.9% of words misheard), not tone; a far stronger base
  should help that, but 93 minutes of one register is the same limit.

### Other models (surveyed again 2026-10-25)

What ghost's reading leans on: phoneme input (the homographs, the lexicon), a duration plan per
phoneme (the rests rendered, stress, the trail, the hesitation), exact phones and words (subtitles,
the desk's pen, an actor's mouth), and a CPU faster than real time. Kokoro keeps all four; nothing
newer does.

- **Better tuning, and they give up most of the four** - codec language models: VoxCPM2 (2B,
  Apache-2.0, official LoRA from 5-10 minutes, about 20 GB to train), Qwen3-TTS (0.6B/1.7B,
  Apache-2.0, official fine-tuning, cloning, a GPU), Chatterbox Turbo (350M, MIT, community
  fine-tuning), NeuTTS Air (748M, Apache-2.0, a CPU via GGUF, a fine-tuning script), Pocket TTS
  (100M, CC-BY-4.0, cloning on a CPU). MOSS-TTS takes IPA and a token count for the length, but is
  1.7B and 8B. None hands back timings (a forced aligner would have to), none takes a plan per
  phoneme, and an autoregressive model can skip or repeat words in a long reading.
- **Phoneme models:** StyleTTS 2 has the official fine-tuning script Kokoro lacks, but older weights
  whose license asks listeners be told the speech is synthetic; Supertonic 3 (99M, faster than Kokoro
  on a CPU) is OpenRAIL-M, its repo archived, no training code; MeloTTS is MIT and trainable but about
  Piper's quality; Inflect-Nano (4.6M) is buzzy.
- One CPU benchmark (four Xeon cores): Kokoro 1.6x real time, UTMOS 4.44; Supertonic 3 4.2x, 4.32;
  Pocket TTS 1.4x, 4.10.

**Next, after listening:** Kokoro's own dwell measured and the pause figures made per backend; F0 as
an input (the Tone's `noise` as the F0 range); then, for an actor, the style fit before the recipe.

## Training Kokoro (2026-10-26)

**The user:** "Sadly, I likely won't use Piper models for anything other than testing now, given that Kokoro is so
much better-sounding. So, you think fine-tuning Kokoro might be possible... I would ask you to give that a try. To be
honest, I feel like our own custom training loop would probably be perfectly fine, and those other projects might
have legacy code that would be hard to work with." The test voice: Manzanita's ASMR channel (15 videos, 5.5 hours).

### The model, ours (`hosts/voice_train/kokoro_model.py`)

hexgrad's kokoro 0.9.4 modules (Apache-2.0) with PL-BERT's ALBERT written out under the checkpoint's own key names -
no `transformers`, no `huggingface_hub`. The checkpoint loads whole (only the AdaIN norms' affine weights absent, as
in Kokoro's own lenient loader). **Measured against the voice host's ONNX graph:** the same 42 frames for a sentence,
id for id, and the waveform correlated 0.99 - but 1.45 times louder: the export's inverse STFT (Kokoro's
`CustomSTFT`) leaves out the window normalization, 1.5 for its Hann 20 / hop 5. So the host's Kokoro has always
been ~3.5 dB over hexgrad's PyTorch; a voice taught here and written into that graph keeps the host's gain.

### What it is taught on (`kokoro_data.py`)

- **Their sentences, Kokoro's ids:** Utterances with `"engine": "kokoro"` cuts at 24 kHz and writes the host's own ids
  (`KokoroBackend.ids_of`, the ids `_render_symbols` sends: test_kokoro.py holds them equal).
- **Each id's frames, by warping Kokoro onto them:** Kokoro says the sentence (the base voice, its speed matched to
  theirs) and its exact plan is carried onto their recording by DTW. Calibrated where the truth is known - two of
  Kokoro's voices warped onto each other (four pairs: men, women, American, British; five sentences): log mel by
  cosine puts a boundary within a frame 94% of the time (median error 0), MFCCs 75-78%; through the whole
  preparation (silence padded, level moved, speed matched), af_heart's plan laid on af_bella's speech: 95% within a
  frame, 97% within two.
- **Pitch and energy as Kokoro's decoder reads them:** on its own speech, pYIN reads back the F0 it was given (median
  ratio 1.003, the middle half within 1-2.5%; unvoiced it is given ~0, as pYIN says); StyleTTS 2's energy (log of the
  norm of an 80-band power mel, n_fft 2048, window 1200) correlates 0.995 with what it was given, about 0.45 under it
  (0.15-0.70 by voice and sentence: `N_OFFSET`).
- **At Kokoro's level:** its own speech's loud frames sit at -27 dB (af_heart, af_bella; Sarah and Emma -24).

### The loop (`kokoro_train.py`)

PL-BERT and the text encoder held (Kokoro's reading of English); the decoder, the prosody predictor and one style
taught. The decoder teacher-forced on 1.5 s stretches: multi-resolution log mel (x45), then after 1,000 steps HiFi-GAN's
multi-period and UnivNet's multi-resolution discriminators (fresh: Kokoro's were never released), least squares and
feature matching. The predictor on whole sentences: frames (L1 on the sum of sigmoids, BCE per bin), F0 and energy
(smooth L1). The AdaIN norms' own scale and shift held at 1 and 0 (never taught by hexgrad, folded out of the graph).
Six stretches a step (eight were 8.6 GB until the discriminators joined, then 11.5 and out of memory on a card the app
shares), with the generator's residual blocks recomputed backward (kept, a Snake's tensors were 6 GB more): about a
second a step on the 5060 Ti. On clean speech the loop does what it should: af_heart taught 2.5 minutes of af_bella
for 300 steps came 0.90 to 0.52 of the way in log mel, its long-term spectrum 2.0 dB off to 0.2, and Whisper misheard
1.9% of its words before and after.

### Into the host's graph (`kokoro_export.py`)

The onnx-community graph's weights are not under PyTorch's names (weight norm folded, LSTM gates repacked i o f c,
some matrices transposed), so they are FOUND BY VALUE: of its 556, 477 are a form of a checkpoint parameter, the rest
constants; every taught tensor reaches one, none is ambiguous but two ones-and-zeros constants (left alone). The
taught values are written into a copy of the host's patched graph, and checked: a sentence plans PyTorch's frames
exactly and sounds 0.995 alike (gain 1.45). The host lists such a voice from `kokoro/trained/<id>/` (graph,
tokenizer, one pack, voice.json) beside the checkpoints, one speaker, never fetched (test_kokoro.py).

### What their recordings taught (measured 2026-10-26)

Every voice judged on TWENTY UNSEEN SENTENCES (188 words) by Whisper medium.en - base.en misheard a third of their own
real speech, so it could not judge a voice of them - and by its long-term spectrum and pitch against their own.

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
- **Their words were not what their sound said.** A sentence's words came from hearing a whole 20-minute video, its cut
  laid by those words' times: heard again alone, 83 of 192 said exactly their text - a word at an edge counted on the
  wrong side ("I've"), a word the long hearing left out. The warp put a boundary 14+ frames from where another
  reference voice put it for a tenth of them. On clean speech, alignments a median 2 frames off ALONE took the words
  misheard from 1.1% to 33% (af_bella with her own plan jittered: 1 frame, 9%; 2 frames, 33%). Now each sentence is
  HEARD AGAIN ALONE and cut to the words its sound says (hosts/speech/agree.py: 85 of 192 kept, 4.6 minutes).
- **Their room:** soft ASMR speech ~19 dB over a high-gain microphone's hiss; the decoder learned to make breathy noise.
  A stationary gate (`kokoro_data.quieted`) takes the room out of every sentence.
- **Their energy never fell to Kokoro's silence** (their quietest twentieth 8 log units over it, even gated): mapped
  quantile for quantile onto the energies Kokoro planned for the same sentences (`kokoro_range`).
- **Their delivery cost the words:** taught, the predictor's timing (warped from another voice onto soft speech) and
  its pitch and energy threw the taught decoder - each part alone stayed clear (the taught predictor through the stock
  decoder 1.6%, the taught decoder on stock curves 4.3%), together 33-56%. So KOKORO'S DELIVERY IS KEPT by default
  (`"predictor": "kept"`): the decoder and the timbre half of the style taught, the pack's prosody half the base's,
  row by row.
- **Tried and dropped:** a monotonic alignment search over a small model of their sound, started from the warp (it
  repaired a jittered alignment from 44% within a frame to 60% on clean speech, but on theirs it crammed 53% of
  phonemes into one frame, and a predictor taught that crammed too); teaching the decoder's AdaIN projections alone
  (4.8M of its 53M: no clearer than the whole, less of them); Whisper's encoder as the warp's features (as consistent
  as log mel on their recordings: 66% vs 51% within a frame between two references, the same long tail).

**The data:** 15 videos, 5.5 hours; 6,878 words heard by medium.en (base.en: 6,650, and sure of 16 minutes where
medium.en was of 26); two videos left out by content (a collab with another person, a character voice); the one-voice
rules kept their soft voice once CLEAN was made relative (`CLEAN_FROM_BEST`) and RATE's ceiling raised - 12.1 minutes,
4.6 once agreed.

### Built

The Voice training card is Kokoro's: Fetch (sound alone), Probe, Hear, Utterances (three phases - cut in Kokoro's
rate and ids, each sentence heard again by Whisper medium.en and cut to its words, written again) and Voice
(hosts/voice_train/kokoro_voice.py: prepare, teach, export into the host's graph, publish to
`<data>/ghost/voices/kokoro/trained/kokoro-<id>/`). The voice host lists such voices (test_kokoro.py). Whisper
medium.en and Kokoro's PyTorch checkpoint are files of the training environment (fetched by those who train);
agree.py runs medium.en on the graphics card where CTranslate2 reaches CUDA 12's libraries, else on the processor.
Gates: voice_training_check; hosts/voice/test_kokoro.py, test_utterances.py; hosts/voice_train/test_kokoro_train.py;
hosts/speech/test_agree.py.

**Listen** (`dist/voice_ab/kokoro_trained/`): `stock_heart/`, `manzanita_timbre/` (the card's recipe: their timbre,
Kokoro's delivery), `manzanita_intonation/` (their pitch and energy too, Kokoro's timing), `theirs/` (their own
sentences) - four unseen sentences each through the voice host's whole path. Both trained voices are also on every
Voice card: "Manzanita (their timbre)", "Manzanita (their intonation)".

**Open:** more of their speech (4.6 minutes is little); CTranslate2 on the graphics card in the app (its CUDA 12
libraries are not in the speech environment - medium.en on the processor is slow); a better aligner than a warp from
another voice; teaching their delivery once the data is clean enough to carry it.

### The user's ear (2026-10-27)

The card run end to end in the app ("Matana", all 13 ticked videos): **"that voice sounded horrible. It's totally
unusable. It sounds nothing like the original actress, and there's tons of static and electricity sound, very
robotic."** What was found afterwards:

- **The judges never taught a single voice.** The discriminators join at ADV_AFTER (1,000 steps), and every voice made -
  each research run, both published Manzanita voices and the card's default (`kokoro_steps` 1,000) - stopped at step
  1,000: the decoder was taught by log mel alone, which leaves its phase free (a vocoder's buzz).
- **The words-misheard and spectrum figures never heard static.** Measured after, on eight unseen sentences: between
  words the trained voices' floor is 46-47 dB under their speech, stock Kokoro's 70 (their own recordings: 26 - the
  room the gate was meant to take out). The research voices have it as much as the card's.
- **The card's run had a third of the research data:** 46 sentences cut, 28 agreed, 1.4 minutes (research: 4.6). The
  Hear step's small Whisper was unsure of most of her words (301 sentences left out "unsure words"); research had
  heard with medium.en.
- Her ordinary speaking voice is ~12 of 5.5 hours (the rest whispered), and Kokoro's delivery is kept: af_heart's
  rhythm and melody in her timbre.

**Then, of the research voices:** "The voices you trained actually DO sound like the actress, though they are muffled
and tinny/robotic/electric. There's no way to make the voice more clear?" Tried the same night, each on the 20 unseen
sentences (edges: the quieter of a take's first and last 100 ms, under its speech; floor: its quietest tenth of frames
under its loudest; words misheard by medium.en, of 188 - two or three either way is the swing between checkpoints):

| | edges | floor | over 6 kHz | misheard |
|---|---|---|---|---|
| stock af_heart | -68 dB | -71 dB | -15 dB | 1.1% |
| "(their timbre)": step 1,000, log mel alone | -40 | -47 | -24 | 4.8% |
| "(judged)": on to 2,000, the judges teaching | -42 | -49 | -23 | 5.9% |
| "(quiet edges)": the same, KOKORO'S PADS SILENT in what it is taught, 2,000 | -66.5 | -60 | -23 | 9.0% |
| ...3,000 | -66.7 | -57 | -25 | 7.4% |
| ..."(her pitch)": 3,000, Kokoro's pitch x1.15 | -67 | -56 | -26 | 9.0% |
| ...4,000 | -66.5 | -53 | -25 | 12.2% |

- **The hiss at a sentence's ends was taught:** the warp gives each sentence's first pad (median 6 frames) whatever
  starts their clip - a breath, a word's tail, the room, 14 dB under their speech (gated, 23.5) - where Kokoro's own
  pads are silence. Faded to nothing in what is taught (their energy there the sentence's quietest, unvoiced), the
  voice's ends are Kokoro's (-66.5 dB).
- **The gate does not thin them:** it takes 0.1-0.9 dB of their voice below 8 kHz and ~5 dB of hiss above.
- **Muffled, measured:** against their own recordings the voices lack 3-6 dB between 2.4 and 8 kHz (where stops and
  hisses are heard) - the misheard words are soft stops ("parked" heard "park", "card" "car", "slid" "lit"); stock is
  8 dB brighter than THEM above 6 kHz.
- **Their pitch is not Kokoro's:** her voiced frames 190-289 Hz (median 220), af_heart's plan 96-275 (median 192) - a
  quarter of its frames under anything the decoder was taught on; no Kokoro pack is pitched as high (af_bella 193,
  bf_isabella 199). A ratio is written into the predictor's F0 head (its weight and bias; published 227 Hz).
- **Longer overfits:** 4.3 minutes; past 3,000 steps the floor rises and the words go.
- Harmonic share, cepstral peak and flutter put every trained voice within their own recordings' range: no measure
  here hears "electric". The three voices are on every Voice card for the ear ("Manzanita (judged)", "(quiet
  edges)", "(her pitch)"); dist/kokoro_ft/evalset/ck/<run>/listen/said/ holds the 20 sentences of each.

### kikiri-tts read again (2026-10-27)

The user, of the research voices ("far too muffled ... a weird electric resonance ... almost like a coiled spring"):
would more of her data help, and does [kikiri-tts](https://github.com/semidark/kikiri-tts) show how to teach Kokoro
better? Its recipe (StyleTTS 2's two stages, patched; read in its fork `semidark/StyleTTS2`) against ours:

- **Every voice it published is synthetic speech** (Polly voices: the base "51 speakers synthetic", 30,800 clips; the
  two voices 455 and 627 clips, marked synthetic). Clean, alike from clip to clip, no room: it shows the method works,
  not that it works on soft real recordings. Its data step filters by Whisper's confidence alone.
- **The decoder is taught on the curves it will be given:** stage 2 decodes the recording from the PREDICTOR's pitch
  and energy (`F0Ntrain`), not the measured ones. Ours is taught on hers and played on af_heart's (a quarter of its
  frames under anything it was taught on) - the gap "taught decoder on stock curves" measured.
- **A speech model's ear on every step:** L1 between WavLM-base-plus's 13 layers for theirs and ours (`WavLMLoss`,
  weight 1, both stages), and in stage 2 a WavLM discriminator. Nothing of ours hears what sound is said; the misheard
  words are soft stops. The training environment has no WavLM (no torchaudio, no transformers).
- **Its own aligner:** StyleTTS 2's ASR aligner (pretrained on LibriTTS - English) taught on the speaker's audio with
  a monotonic loss, soft attention half the time; ours is a warp from another voice.
- **Seasoned judges:** the voices start from a base whose discriminators had learned on 30,800 clips, adversarial from
  the first step (a relativistic term besides least squares); ours start fresh on 4.6 minutes and overfit past 3,000.
- **A style per clip:** a style encoder reads each clip and the voice is their mean; ours is one style for every
  recording.

**More of her:** of the 13 videos read, four gave her ordinary voice (12.1 minutes before agreement: "Follow My
Instructions - Exam Edition" 5.7, "A Completely False Time Capsule Opening" 2.5, "A Very Generic ASMR Video" 2.1,
"Taking Your Picture" 1.8); whispered, no-talking and soft-spoken videos gave none. More data narrows the gap in clips
(ours 85), but misplaced cuts should not average away: a loss frame by frame learns a burst placed early in one clip
and late in another as a smear at both - muffled, a stop lost - and more data makes the smear surer, not sharper.
Untested at scale; af_bella's synthetic speech, jittered as before at 2.5 and 20+ minutes, would say.

### The kikiri revisions tried (2026-10-27, the night)

The user, with 58 new videos of hers fetched (12.8 hours): "If you'd like to go ahead and try those pipeline revisions we
discussed, let's do that now." Measured as before: twenty unseen sentences, words misheard by medium.en of 188; the floor
and what is over 6 kHz; and each band against her own held-out recordings, the level matched under 2.4 kHz (bands.py).
Scripts and runs in dist/kokoro_ft/ (scratch/night.sh, after.sh), every voice for the ear in dist/voice_ab/manzanita_night/.

**More of her, and what stood in the way:**
- **Whisper's voice-activity filter dropped her speech whole.** Hear runs Silero's VAD (`vad_filter`, hosts/speech/
  transcribe.py - the card's Hear too): 36 of 73 videos heard no word; without it, 69,439 words against 7,989 ("giving
  you a random pep talk", 9 minutes: none, then full sentences). What Whisper invents in silence the utterance and
  agreement steps leave out. NOT CHANGED IN THE PRODUCT: Hear serves an actor's mouth too, where words invented in
  silence would move it - proposed for a voice alone.
- **"Their usual pitch" was the search's edge** (fixed: utterances.py `signature`, test_utterances.py): 109 runs read
  exactly 300 Hz - a correlation that only falls peaks at the shortest lag searched - and the register came out 300 Hz
  against her voice's 205-235, keeping 6 minutes. A pitch is now the correlation coming back: register 207.6 Hz, 30
  minutes from 9 videos before agreement (the first data: 12.1 from 4), 209 sentences agreed, **12.2 minutes** (4.6).
  (Cut as the first data was: utt_dump.py's clean 17 dB, rate 6-60, recording 3 dB.)
- **More data alone is not clearer:** 9.6% misheard, and duller - 7 dB short from 2.4 to 8 kHz. Its nine recordings'
  4-8 kHz differ by 9.5 dB and are taught as one voice; the data itself is no darker than the first.

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

- **The decoder is best taught on the predictor's curves and played on Kokoro's own.** Taught on them (its pitch and
  energy taught alongside, at her level) it is brighter and its floor quieter - Kokoro's curves are smooth where hers
  move twice as sharply frame to frame. But with no style read from the recording (Kokoro has none; StyleTTS 2 reads one
  from the target), the taught pitch follows hers r = 0.01, and played with it every word smeared: crossed, its decoder
  with Kokoro's own predictor said 5.9%, the clear decoder with the taught predictor 31.9%. So the export leaves a pitch
  run's taught pitch and energy behind (kokoro_export.py).
- **Taught on Kokoro's own curves** - its level, 192 Hz - the decoder learned to raise the pitch it was given (it says
  230 Hz) and smeared the words: 20.2%. On the predictor's energy and her own pitch, 25.5%; its curves for half a batch,
  21.3% (both dropped).
- **The ear helps a little and costs little:** 8.5% against 9.0, 8.0 against 9.6, each a dB or so brighter, no slower a
  step. WavLM Base+ is CC BY-SA 3.0, used only to teach (StyleTTS 2's weight held: 18 against our mel, measured).
- **Single runs:** two or three words either way is the swing between checkpoints; 5.3% against 9.6% is 10 against 18.

On every Voice card: **"Manzanita (clearest)"** and "Manzanita (more of her)" (the new data with the ear). The card still
teaches as before (kept, no ear, Hear with the VAD) until the user has listened.

**Still open:** the floor between words (61 dB down, stock 71); 2.4-4 kHz 5.7 dB short; a style per recording.

## Chatterbox read (2026-10-27)

The user: Kokoro "is likely a heavily distilled model ... trained on AWS Polly synthetic examples. I feel like we might
be barking up the wrong tree" - is Chatterbox's 110M variant worth trying, inference first, tuning after? Read in
`resemble-ai/chatterbox` (5de7a54, 2026-07-21) and the safetensors headers on Hugging Face:

- **"110M" is the language model alone.** Nano is Turbo's pipeline with a GPT-2 small T3 (85M in its layers; Turbo's
  is GPT-2 medium, 302M). Behind it is the same S3Gen as Turbo's: a flow encoder (38M) and decoder (73M, two meanflow
  steps), the HiFT vocoder (21M) and an x-vector (7M) - and the speech tokenizer (124M), run only on a reference clip.
  About 330M to read a sentence. Files: 870 MB and 1.06 GB, fp32. MIT, not gated, uploaded 2026-07-21.
- **Text in as GPT-2's BPE of plain English, speech out as 25 tokens a second, sampled** (temperature 0.8, top-p 0.95,
  repetition penalty 1.2): no phonemes, no plan, no timings, a different take every time, and an autoregressive
  model can skip or repeat words. Nano and Turbo warn that CFG and exaggeration "will be ignored". Tags such as
  `[sigh]` and `[laugh]` are read. A built-in voice (`conds.pt`), so it reads with nothing cloned.
- **Every take is watermarked** (Perth, `apply_watermark` - one line in their code, MIT).
- **Dependencies:** torch, transformers, diffusers, conformer, s3tokenizer, librosa, perth, omegaconf (their pins
  ignored). "3x real time on 8 cores" is theirs; this machine's four cores are not measured.
- **What ghost loses** (the four the reading leans on, "Other models" above): the homographs, the lexicon, a word
  pinned; emphasis, the trail, the rests and the hesitation's rest; the words' times for the subtitles, the desk's pen
  and a cue at a word (a forced aligner would have to give them back - Whisper's word times are in speech_venv);
  and the same take from the same text.
- **Taught more easily, in one way:** neither half needs an alignment. T3 learns from text and her speech tokens (the
  agreed utterances are that), and S3Gen from her audio alone - her tokens to her mel, no text, so every hour of her
  ordinary voice, not only what Whisper agreed with. Only community scripts (`stlohrey/chatterbox-finetuning`, WIP,
  the original model; LoRA on T3 for languages); nothing official, nothing for Nano.
- **Voice conversion keeps everything Kokoro gives** (`vc.py`): S3Gen alone - speech to tokens to speech in the
  reference's voice, at a fixed 25 tokens and 50 mel frames a second, so a take comes back its own length and its
  word times hold to a token (40 ms). Kokoro would read as it does now and S3Gen re-voice the take; how much of
  Kokoro's intonation lives through tokens that keep mostly the words is for the ear.

**Proposed, nothing built:** inference only, a standalone script on a venv of its own - Nano with its built-in voice,
then with ten seconds of her; then a Kokoro take re-voiced by S3Gen into the same clip. Measured: the speed on this
CPU, words misheard (`hosts/speech/agree.py`), one sentence read five times, and the word times after conversion.
