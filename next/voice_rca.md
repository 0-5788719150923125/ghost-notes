# Voice RCA - the robotic sound, the clicks, and what the audio keys off of

Root-cause analysis of the Klatt voice's artifacts, with what each fix ended as. Empirical numbers come from instrumented renders
(the curated default voice plus rolls 42 and 777, one paragraph) that tapped the signal inside the output chain. Re-render with
`python build/scratchpad.py run`.

---

## 1. What is the audio keying off of? (why it speaks with an empty belt)

Nothing about the belt, the cast or the water gates the audio. `SynthEditor._ready` marks the draft structural, and a debounced
`_apply()` (`synth_editor.gd:111`) speaks it with the working candidate (`_traits` + `_lineage` + `_working_genome` from
`ghost.cfg`; on a fresh install the zero vector, the curated default speaker). This is a design leftover from before the fishing
loop: sound with no source.

### Proposed gating (maps cleanly onto the existing state machine)

Audio presence is one scalar, `presence`:

- **Belt empty, nothing thrown:** `presence = 0`.
- **Belt has seeds:** the party is the background voice, an acceptance-weighted belt blend (`Spec.influences` and
  `_background_traits()` are the two APIs to rejoin).
- **Thrown, anchored, reeling:** the candidate ramps in with the reel (the scalar that drives `Director.set_aura`): far is quiet and
  dark (lowpass), closer is louder and brighter.
- **Caught and accepted:** full presence.

Bootstrap deadlock: bites are detected from the playing stream's clock (`_fresh_strike` reads `Spectrum.current.time` against
`stream.events`), so a throw that makes no sound has no clock and the first seed could never be caught. The stream therefore always
runs, through the presence gain; at `presence=0` it is inaudible while the clock and events tick. `Spectrum.begin_stream` also gives
the session its seed and the scenes their audio, so full silence would freeze the show.

---

## 2. The clicks, pops, and static - measured

The per-phoneme click class was already fixed (0-1 isolated click events per ~31 s take, none at phone boundaries). The remaining
crackle came from the broadcast chain (AGC, cosine dampener, static bed), which manufactured crackle and hiss from clean input:

| measurement | value |
|---|---|
| pre-broadcast signal | peak 0.84, RMS 0.064, crest 13x - clean, nothing to limit |
| AGC gain | pegged at the 2.5x maximum for 90-96% of all samples |
| voiced samples zeroed outright by the dampener | 10.2% |
| static bed | above -40 dB for 97% of the take, median -33 dB |
| 5-11 kHz band, vowel cores | pre-broadcast -25 dB -> final -9 dB |

1. The AGC steered mean |x| toward a target "as a sine" (assumes crest ~1.4); speech through formant resonators has crest ~13, so
   the gain railed and pushed peaks to ~2.1.
2. The cosine dampener is a non-monotonic waveshaper whose gain falls to zero at the ceiling, so each peak above 0.8 became a hole.
   Holes at f0 rate are wideband splatter, the crackle.
3. The static bed never decayed, a permanent -33 dB hiss.
4. The AGC pegged during every pause, so each post-pause onset arrived pre-boosted 2.5x.

The fix is to remove the arms race: `OUT_GAIN` lands peaks at 0.73-0.84, a lookahead peak limiter handles overshoot, and loudness
consistency across rolls belongs at plan time. A live-only pop on every throw or edit restart (`Spectrum.restart_stream()` stops and
plays mid-waveform) needs a fade-out before the cut. Smaller nits: `period_gain` (shimmer) resets to 1.0 at each segment boundary,
and the per-period jitter draw was overwritten at the next 64-sample frame boundary, so jitter shaped only ~40% of each cycle.

---

## 3. Why it still sounds robotic - the vocal physics we skipped

Ranked by expected audible payoff after the broadcast chain:

1. **Loudness dynamics erased after they are computed** (the AGC normalized the whole performance).
2. **Periodicity too perfect:** the jitter bug left cycle lengths barely varying, the oldest robot-voice cue.
3. **Only vowels carried the melody:** `semitones` was computed inside `if is_vowel`, so f0 dove toward neutral through every voiced
   consonant (within-word f0 span p90 of 4-5 st). The contour is a word property: non-vowel segments take the interpolated value.
4. **Nothing above 3 kHz but noise** (vowel cores -25 to -30 dB above 3 kHz): F4/F5 presence poles are cheap in the cascade.
5. **No voice onset time** after voiceless stops: a short aspirated release borrowed from the `asp` (HH) machinery.
6. **Coarticulation was one symmetric 18 ms EMA**; real transitions are 50-100 ms, asymmetric and consonant-specific (locus targets).
7. **Nasals had no anti-resonance:** one notch switched in for M/N/NG.
8. **The air trait's top of range replaced the voice with static** (roll 42: 5-11 kHz at -5.9 dB pre-broadcast, f0 tracker locked 59
   frames against 238 for the default): narrow `air_gain` or couple it to harmonic level.

The prosody walk itself is not at fault; the readings move. The robotic quality is downstream of it.

---

## 4. The chorus idea - considered

- **(a) Parameter averaging across population samples** exists already (the 1+N influence blend with the PRIOR). It regresses the
  reading toward the population mean, flatter, and spends the variance the seed economy farms.
- **(b) Trajectory-level ensemble with votes/modes:** render the plan N times from different genome rolls, take the majority on
  discrete events and the median on continuous values, synthesize once from the consensus. Decisions stay crisp and one genome's
  tics wash out. A candidate way to derive what the belt as a whole would say; it makes readings more typical, not more human.
- **(c) Unison doubling at the signal level:** synthesize the same plan 2-3 times with independent jitter/shimmer/tension noise and
  tiny offsets (a few cents of f0, ~2% formant scale, a few ms onset) and sum. It decorrelates periods as a real glottis does.
  Cost is linear (synthesis runs 16-27x real time). Pushed too far it becomes a phasey effect or a crowd, and it papers over the
  too-regular source rather than fixing it.

The cheapest big win is fixing why the lone voice is perfect (sections 2 and 3). (c) as a flavor layer and (b) as the belt's
consensus reading remain live options, neither built.

---

## 5. Suggested order of attack (for discussion)

1. Replace the broadcast chain: no AGC or fold, a lookahead limiter on the worker's 2.5 s lead, plan-time loudness per take.
2. Restart fade.
3. Jitter fix.
4. Audio presence gating (section 1).
5. Melody continuity through consonants.
6. Then ranks 4-8 and the chorus experiments, by ear.

---

## 6. Implemented (2026-07-20, same day) - first attempt at all of it

- **Broadcast v3** (`voice.gd`): AGC, cosine fold and always-on bed are gone. A one-block lookahead limiter (output one 64-sample
  block behind synthesis, each incoming block's peak sets a gain ramp) never engaged across the three test voices. The bed remains
  only as a mask tied to actual limiter work; silence floor -48 to -60 dBFS (was -38).
- **The clicks were the stop bursts.** The envelope was backwards (slow 8 ms attack, hard cut) and the noise was added after the
  cascade. Bursts now attack instantly, decay through the EMA and excite the tract, retargeted to the next phone first. Click
  events 21 -> 4-7 per take.
- **Robot voice ranks 2-8 landed:** jitter/shimmer draws persist until the next period; f0 continuity through consonants and
  silences (within-word span p90 4-5 st -> 1-2 st); F4/F5 presence poles; VOT aspiration after voiceless stops; per-articulator
  coarticulation speeds; nasal anti-resonance as a biquad notch (a bare zero pair amplified the top octave ~30x); shimmer default
  6% -> 4%; air trait ceiling roughly halved.
- **Sampling normalization** (`synth_editor.gd` `_temper_traits`): a trust region (RMS radius 0.85 over the trait axes) around the
  party's acceptance-weighted centre pulls a draw beyond it back onto the boundary. Drifting widens the radius, so foreign voices
  are earned.
- **Silence at launch and presence** (`synth_editor.gd`, `voice_stream.gd`): no auto-speak; the first throw breaks the silence
  (`--say` counts as a landed cast). Presence is distance from the caster, applied at push time (the WAV take stays canonical):
  gain plus a distance lowpass. Far cast 0.28, anchored up to 0.6, reel 0.4 -> 1.0 with progress, landed/kept/restored 1.
- **The reel is a fight:** progress is belt power against seeded runs (per-lineage; foreign catches run more and harder); a run pays
  line out, drops presence and whips the HUD line red. `_reel_power` (0.9x to 2.2x) replaces `_retrieval_factor`. Every 2 s the
  stream's timbre retunes toward the annealing traits, so the wait auditions what is being pulled in. The HUD shows percent.
- **Restart pop:** `fade_stream()` drops the player ~40 ms before the stop/play cycle; every new stream fades in over ~0.2 s.
- **Loudness:** presence gain is linear with an audible floor (distance is the filter's job; silence belongs only to the un-cast
  water). The broadcast stage has a bounded syllable leveler (2:1, fast attack, slow release, +-4 dB; its target is in near-peak
  units, since a mean-sized target cut every vowel) and a tanh soft ceiling at 0.8.

Not built: unison doubling (c) and the belt-consensus reading (b); locus targets beyond the burst retarget.

---

## 7. Round two - the clicks localized to the sample, and lineage aging

The adaptive masking bed idled at its floor; the clicks were synthesis-side. Fixed:

- **The noise route switch.** Aspiration and bursts send noise through the cascade, fricatives ride the post-cascade band. The
  envelope survived a handover, so a leftover re-emitted as a raw burst-tuned band snapping on in one sample ~1 ms into the vowel
  after every stop. The route is tracked in state and the envelope zeroes on a cascade-to-band switch.
- **Per-frame envelope staircases:** voiced amp and noise envelopes now ramp per sample across each frame.
- **The noise resonator froze through the asp branch;** it now steps every sample.
- Click events 14/11/11 -> 5/5/7 per take; max one-sample step 0.34 -> 0.16. Survivors are smooth plosive transients.
- The adaptive bed and its 60 s floor ratchet are deleted. `retune()` glides breath, `air_gain`, `air_cut` and the F4/F5 scale
  through a ~60 ms EMA (the reel retuned them instantly every 2 s). The location reception path's hard clip is a tanh soft ceiling
  (`LOC_CEIL` 0.95), live and offline.
- **Lineage aging:** ornaments age out while identity stays root-anchored. A spawned modulator's raw depth decays by `ORN_DECAY`
  (0.7) per later generation, and the suppress floor prunes the faded ones (AGE joins DAMPEN/NORMALIZE/SUPPRESS as the fourth
  regularizer). The elaboration anchor shelf is a window seeded by the newest generations, capped at 4. The genome's 0.6^gen
  root-anchored refinement is unchanged. `voice_check`: root gesture depth 0.916 -> 0.053 over 8 generations, pruned at finalize.

---

## 8. Round three (2026-07-26, same day) - the "random noise bursts" found and killed

- **`NOISE_FX`** (`voice.gd`, a hardcoded const): false disables every non-phonemic noise injection (aspiration hiss, the air band,
  the output grain). Consonant noise stays. The rng draws still happen when disabled, so the flag A/Bs the same take.
- **The random bursts were the echo bus ringing frication.** An echo activation had thrown the word "static" into the undamped delay
  line, and its S-noise rang through the following gap (a 200 ms, aperiodic, 3-11 kHz burst at ~-27 dB). The delay line is now
  damped by a one-pole lowpass (`ECHO_LP` 1400 Hz) inside the feedback loop, ~15 dB per pass at 8 kHz. Pause floors -62/-55/-60 dBFS
  (roll 42 was -40.6).

---

## 9. Round four - the foundational one: gain staging into the ceiling

Saturation events (37-52 per minute, ~3% of samples distorted), identical on a brand-new seed. Cause: `OUT_GAIN` staged peaks at
1.5-1.75 against an always-on tanh ceiling at 0.8, so every stressed syllable's pulse peaks were folded and the leveler then pulled
the RMS back down. **Broadcast v4:** the lookahead ramp is the peak authority (blocks under `LIMIT` 0.85, distortion-free); the clip
is a safety net only (identity below `KNEE` 0.7, rounding into `CLIP_CEIL` 0.98). If it reads too quiet, raise `COMP_TARGET`, never
`OUT_GAIN` past peak-safe staging. Loudness dynamics from the walk are performance; if scenes burst on those, the dial is `act_thr`
or ELABORATION, not the broadcast chain.

---

## 10. Round five - RAW bypass: the bisect experiment

`Voice.RAW_MODE` (hardcoded, beside `NOISE_FX`) plays the base synthesis only. Off while raw: the walk's audible realization (the
walk still advances and strike events still fire), ProsodyField wander, per-period jitter/shimmer/tension, the whole broadcast chain
(blocks emit under fixed `RAW_TRIM`), and VoiceStream's push-time presence and location (`bake_location` returns raw for exports).
On: phonemes, coarticulation EMAs, declination, accents, vowel reduction, punctuation pauses, terminal contours, VOT, the trait
vector. Restore order, one at a time: broadcast chain, jitter/shimmer/tension, ProsodyField wander, walk realization,
presence/location, `NOISE_FX`.

---

## 11. Round six - the noise survives RAW mode: tap the mixer

`Spectrum.LIVE_TAP` (hardcoded) puts an AudioEffectCapture on the Master bus, recording the last 120 s of what the mixer hears and
writing `user://synth/live_tap.wav` on quit at the real mix rate. Bursts in the capture are inside the mix; a clean capture while
the ear hears them means post-mix (driver or OS). Off when not hunting.

---

## 12. Round seven - FOUND: frication was the noise, all along

The tap caught 27 HF-noise events in 22.3 s, 40-200 ms, 70-90% of their energy above 5 kHz. Every /S/ rendered at RMS 0.27-0.29
(peaks 0.8+) while vowels sat at 0.011-0.06: fricatives +13 dB over the loudest vowel, when natural /s/ sits below vowel level. The
post-cascade noise band is a resonator at its resonant gain, and the radiation first-difference tilts it +6 dB/oct (an 8 kHz band
~12x relative to vowel bands). Every gain-staging number before this was contaminated by S peaks (the true voiced peak at `OUT_GAIN`
0.35 was ~0.2).

---

## 13. Round eight - correction, and the pure_say ladder

The second live tap matched current synthesis exactly, so the app plays what is shipped and the remaining question was perceptual:
equal RMS at 8 kHz reads louder than at voice frequencies, and the /s/ was raw resonator-filtered white noise.
`tests/voice/pure_say.gd` is the minimal repro: bare `Voice.render` to WAV with no autoloads and no stream, rendering one text at a
ladder of `FRIC_TRIM` levels (a static var so the ladder can sweep it), each peak-normalized. The `off` rung is decisive: noise still
there with every fricative silent means the base synthesis is the suspect.

---

## 14. Round nine - the verdict: frication doesn't FUSE

Level was irrelevant: `off` was decent and soft/natural/full were equally bad. The isolated frication signal measured clean (no
impulses, smooth envelope, proper 4-11 kHz spectrum). The offense is where it enters: post-cascade, sharing no formant shaping or
coarticulation with the voice, so the ear segregates it as a second source. The burst path had documented the same lesson (a bare
wideband tick after the cascade reads as a pop; through the formants it reads as a consonant). Frication therefore routes through
the cascade (`FRIC_THRU`), with `FRIC_TRIM` 0.0 keeping the post-cascade band silent.

---

## 15. Round ten - through-tract confirmed, drive calibrated

Through-tract frication moved the character from static to voice-like, but the guessed drive was too high: at unity the cascade
seats voiceless fricatives at 4.44x vowel RMS. The ladder self-calibrates: it renders at drive 1.0, measures the voiceless
fricative/vowel median RMS ratio from its own timing map and solves for `TARGET_RATIO` (0.25, ~-12 dB, where real /s/ lives).
Raw peak 0.961 on every rung: fricatives no longer set the take's peak.

---

## 16. Round eleven - back into Ghost: the instrument restored

All four calibrated rungs were acceptable. Shipped: `FRIC_THRU` 0.06, `FRIC_TRIM` 0.0, `RAW_MODE` false (the full instrument:
walk, ProsodyField wander, jitter/shimmer/tension, broadcast chain, presence/location, lineage aging), `OUT_GAIN` 0.35 -> 2.0
(the S-clean voice has a 16-23x crest, so static gain carries the level: RMS -21 to -23 dBFS, peaks steered to `LIMIT`, ramp active
on 0.2% of samples, zero saturation). The leveler is a gentle evener again. Remaining artifacts: plosive-transient clicks (4-15 per
take, legitimate stop acoustics at threshold).

---

## 17. Round twelve - restore complete + the fidelity pass

- `NOISE_FX` true (breath, air band and grain back: the air band is most of the voice's top-octave life); `LIVE_TAP` retired.
- **SR 22050 -> 44100:** doubles the bandwidth ceiling and removes Godot's playback resample. Everything derives from SR;
  per-block constants were rescaled to keep their time constants. Radiation tilt halves at speech frequencies, crest falls to
  8-10x, clicks 2-8 per take.
- Effort tilt floor raised (0.3 -> 0.45 base, 0.2 -> 0.35 clamp): settled speech had been lowpassed into dullness.
- `FRIC_THRU` 0.18 (`TARGET_RATIO` 0.35), `OUT_GAIN` 4.5 (RMS -17.3/-18.8/-19.0 dBFS, ramp work <= 0.03% of samples), presence
  distance filter floor 500 -> 900 Hz.

Same lineage still gives the same take, deterministically, though every seed sounds different after an SR change.

---

## 18. Round thirteen - the acoustic rebuild (Stage 1 of 3)

Stage 1 is the acoustics, Stage 2 the text front end, Stage 3 singing as a typed capability. A multi-agent investigation (7
dimensions, each adversarially verified, plus an independent measurement pass) found the cascade doing three jobs it should never
have had.

### What was actually wrong (measured, not inferred)

1. **Frication was routed through the vowel's formant cascade.** The `"fric"` branch never called `_retarget()`, so the 5-pole
   cascade (an all-pole chain topping out at 4.7 kHz) held the previous vowel's formants and attenuated each fricative at its own
   noise band by 42 dB (/f/), 69 dB (/th/) and 85 dB (/s/). The S/SH/F/TH log-spectra correlated at 0.99-1.00, and 6-10 kHz contrast
   against the neighboring vowel was -0.2 dB. Both earlier routes were wrong for opposite reasons: post-cascade shared no tract
   shaping, through-cascade was lowpassed into nothing.
2. **A DC pedestal held 43-52% of every take's power.** The Rosenberg pulse tables are unipolar (mean 0.404), every pole passes DC at
   unity, and the only rejection was the radiation zero at 0.04 (predicted and measured output DC 0.0727). It ate budget from the
   0.85 peak, modulated at the syllable rate and fed the leveler, making every RMS staging number ~2.4 dB optimistic.
3. **No top.** Five poles ending at 4.7 kHz put the -60 dB/oct cliff inside the speech band (27 dB drop between 3150 and 5000 Hz);
   above 5 kHz the output was the `FLOOR_MIN` dither. Breath/air hiss was 96-99% of a sustained vowel's 2-4 kHz energy.

Also: obstruents had no tract posture (so /aba/, /ada/, /aga/ had bit-identical formant trajectories); nasals shared one 1000 Hz zero
(collapsing sum/sun/sung); fricative bandwidths were tract-scaled (a higher-Q /s/ for short tracts); one `hiss` draw fed
aspiration, the air band and constriction noise, so three sources added coherently.

### Shipped

- **Parallel branch** (`phonemes.gd` `par`, `voice.gd` `FRIC_LEVEL`, `_tune_parallel`, `Reso.tune_peak`): frication and bursts drive
  their own peak-normalized front-cavity resonators, summed with the cascade after the nasal zero and before radiation (the half of
  Klatt 1980 the file lacked).
- **Mandatory tract posture on every TABLE row:** fricatives and stops carry loci (F2: labial 900, dental 1400, alveolar 1750,
  post-alveolar 2000, velar 1900 Hz).
- **Locus glide** (`LOCUS_TIME` 50 ms): a segment holds its own posture then bends toward the next before the boundary.
- **Zero-mean pulse tables**, and the radiation coefficient derived from a named corner (`RAD_CORNER` 140 Hz).
- **F6 at 6000 Hz** and Klatt 1980 per-formant bandwidths (60/90/150/250/300/500).
- **Per-phoneme nasal zeros** (M 950 / N 1800 / NG 3000), an independent turbulence draw, fricative bandwidths not tract-scaled.
- **Air band centre 0.07 -> 0.02** (it masked /sh/ in its own 2-4 kHz band) and `FRIC_LEVEL` 0.05.

### The calibrator was the reason this survived so long

`pure_say._ratio()` was broadband fricative/vowel RMS against a target, orthogonal to a timbre collapse: it converged on the old
synth and declared success on fricatives with 0.02-0.06% of their energy above 4 kHz. It is now three gates that each catch a
different failure: in-band contrast against the adjacent vowel (buried), broadband level (too loud), and pairwise spectral
distinctness (collapsed). The contrast band is read from each phoneme's own declared poles and gated only where diagnostic (/sh/
sits on F3/F4 by physical fact, so it is gated on level and distinctness instead).

### Measured, before -> after (same prose, curated default speaker)

| measurement | before | after | natural |
|---|---|---|---|
| /s/ in-band vs adjacent vowel | -14.4 dB | +19.9 dB | +15..+25 |
| /f/ in-band vs adjacent vowel | -18.6 dB | +11.7 dB | +8..+15 |
| /th/ in-band vs adjacent vowel | -17.8 dB | +14.1 dB | +8..+15 |
| /s/,/f/,/th/ broadband vs vowel | - | -10.3 / -11.2 / -12.1 dB | -8..-15 |
| worst gated fricative pair correlation | 0.99-1.00 | 0.838 | - |
| S/SH correlation | ~0.94 | -0.361 | - |
| 0-30 Hz share of take power | 39.0% | 0.0% | ~0 |
| 2-4 kHz vs 5-8 kHz | +35.7 dB | +5.0 dB | +6..+10 |
| octave LTAS at 6k / 8k / 12k | -40.9 / -47.7 / -44.6 | -21.7 / -20.7 / -25.8 | -22 / -26 / -33 |
| /aba/ vs /ada/ vs /aga/ F2 track | bit-identical | 152-182 Hz mean abs delta | - |

### Known residuals (deliberately not chased further)

- 8-12 kHz sits 5-7 dB above the natural reference (the broad /f/ and /th/ top poles); the rest is tuning, not physics.
- 2-4k vs 5-8k lands at +5.0 dB against +6..+10 natural, legitimate /s/ and /th/ energy in fricative-dense prose.
- 1 kHz is a few dB hot relative to the natural LTAS.

---

## 19. Round fourteen - "father" and "yours", and what they exposed

`tests/app/phone_dump.gd` prints every phoneme of an utterance with its position, duration, broadband RMS and three band energies, so
a word reported by ear becomes a measurement. Two words implicated four defects, three from section 18.

### The DSP half (three bugs, all mine from §18)

1. **The forward locus glide erased the cue it existed to create.** A voiceless fricative is silent through the tract, so gliding
   its posture spends the transition where nobody hears it. Voiceless obstruents now hold their locus and let the following vowel
   carry the movement ("father" /AE/ onset F2 1394 -> steady 1701). For /f/ and /th/ that transition is the primary place cue.
2. **The glide window ate short segments:** a 97 ms /r/ spent 48 ms travelling away from its low, close-spaced F2/F3. Capped at
   `LOCUS_SHARE` 0.35.
3. **Klatt's sign alternation was wrong for the diffuse fricatives.** Alternating signs stops a null between narrow, separated
   resonators (/s/, /sh/), but /f/'s poles at 1400 and 4800 Hz overlap, so opposite signs made them cancel. Sign is now data (a
   negative amplitude in the table). /f/ 0-1 kHz improved 6 dB; F/TH correlation 0.911 -> 0.615. The low shoulder was restored
   (0.15 -> 0.30).

### The front-end half (and the opening of Stage 2)

The words were also mispronounced independently of DSP (`father` -> F AE TH ER, `yours` -> Y AW R S, `comes` -> K AA M EH S). Four
rules in `phonemes.gd`:

- **`-s` morphology**, one level: strip a final plural or third-person `-s`, pronounce the stem, reattach with voicing assimilation
  (Z / S / syllabic IH Z). The strip test is orthographic and conservative, since a wrong strip invents a word.
- **`th` voicing:** function words, intervocalic (`father`), and the `-the$` spelling (`bathe`). It was unconditionally voiceless.
- **General silent final `e`**, with soft c/g tested against the original spelling.
- **Word-final `y` and `o`**, plus a `HARD_G` list for Germanic words the soft-g rule broke.

### Known residuals

- No vowel reduction or stress at that point (resolved in sections 21-22).
- `change`/`danger` read the `ng` digraph and lose the soft g; the same spelling is genuinely NG in `singer`, `longer`, `finger`.
- Live-only risk: `voice_stream.gd:359` applies a distance lowpass at `900 * 2^(4*presence)` Hz whenever presence < 0.995 (~3.6 kHz
  at half-landed presence), which removes /f/ and /s/ while leaving vowels. Any consonant report from inside the fishing loop should
  check it.

---

## 20. Round fifteen - the front end becomes data

Graded against a hand-written reference over a real chapter's vocabulary (1530 tokens, 482 types), the letter rules mispronounced
words that carry most of the listening load, mostly as data problems (`we`/`me`/`he` with EH, `head` as HH IY D, `watched` as
W AE T SH EH D, `couldn't`).

### Why this became the architecture work too

The front end loads its language from disk: **`data/english.yml`** (MiniYaml) with `lexicon` (the irregular high-frequency core,
grouped by the rule class each entry defeats), `clitics` (contractions split at the apostrophe; heads that change shape such as
`don't` are whole lexicon entries) and `suffixes` (`-ing`, `-ed`, `-ly`, `-ness`, `-ment`, `-ful`, with undoubling and
e-restoration). The order is lexicon, clitic, suffix, letter rules. The suffix stage needed typing: whether `-ed` is a syllable,
/t/ or /d/ depends on the stem's last phone, so the stem is pronounced before the suffix is chosen.

### The measurement, which is the real deliverable

`tests/voice/g2p_check.gd` grades against `data/reference.yml`, hand-written and independent of the front end's output, weighted by
token frequency (an error on `the` costs 130 times one on `syndicate`). Token-weighted WER ~35% before, 0.0% over the graded set (110
types, 69% of the text) after. `tests/voice/g2p_dump.gd` lists every distinct word of a text with its phonemes by frequency.

### Honest limits

- The other 31% of tokens (the tail) is unmeasured.
- No stress or vowel reduction yet (done in section 21).
- MiniYaml constraints for the data file: duplicate keys are rejected, and a bare key containing an apostrophe fails to scan, so
  contraction keys must be quoted.

---

## 21. Round sixteen - CMUdict, and the stress that came with it

Every syllable still arrived at roughly equal length and full vowel quality, so the reading chanted.

### CMUdict, vendored

`data/cmudict.dict`: 126,052 words, BSD-2-Clause, attribution in `data/cmudict.LICENSE`. It is a dictionary, not a model, so it does
not touch the no-generative-AI or no-recordings constraints (3.3 MB, 117 ms to read and index at first speech). What matters is
the stress digits (`father F AA1 DH ER0`, `photograph F OW1 T AH0 G R AE2 F` against `photography F AH0 T AA1 G R AH0 F IY0`: the
stress moves, and the rhythm follows). Lookup order: `data/english.yml` overrides, CMUdict, clitics, suffixes, letter rules.

### What the stress marks bought

- **Accent placement:** `stress_vowel()` returns the primary-stressed vowel (the old first-vowel rule was wrong on ~32% of
  multisyllabic content tokens).
- **Vowel reduction per syllable:** unstressed vowels 0.62x duration, 0.78x amplitude, 0.7 toward schwa; secondary stress 0.88x /
  0.92x / 0.25.
- **A real schwa:** `_SCHWA` was byte-identical to AH's own target, so reducing AH moved nothing. Now `[500, 1500, 2500]`.

Measured: stressed content vowels 195-393 ms at -12 to -16 dB, reduced function vowels 72-79 ms at -21 to -25 dB; vowel duration CV
0.55 (natural 0.50-0.60), p90/p10 3.4x (natural 3-4x). Total duration barely moved (89.2 -> 89.0 s), as expected.

### Honest limits

- Take-level envelope statistics do not capture a duration change; it is for the ear.
- `yours` reads Y UH R Z (CMUdict's rhotic form) against Y AO R Z in the reference; both are current English.
- Lexical stress only: sentence stress was still the walk's seeded guess (section 22).

---

## 22. Round seventeen - the walk stops inventing prosody

Lexical stress is the baseline and the walk modulates it. The pitch accent had been a coin flip in `ProsodyWalk.word()` that both
invented and placed the accent, so the same sentence stressed different words on different seeds and no seed stressed them where
English does.

### `src/voice/phrasing.gd` - sentence stress from the text

A typed stage between `Phonemes` and `plan()`. Nothing in it is seeded: the same text always gets the same phrasing, and the
voice's temperament decides how hard it leans, never where. Four parser-free rules:

1. **Content vs function:** function words carry no accent (the list moved to `data/english.yml`, ~100 entries; contractions resolve
   through their head). Standalone possessives (`mine`, `yours`) are not function words: they are predicates that carry focus.
2. **The nuclear accent:** the last content word before a boundary carries its phrase's main accent.
3. **De-accenting given information:** a content word said in the last ~14 words drops to 0.45x.
4. **Stress clash:** two full accents in adjacent words are not English rhythm; the earlier steps back.

Checked with `tests/voice/phrasing_dump.gd` (the second `couch` de-accents to 0.31; the nuclei land where a reader puts them).

### The inversion in the walk

`word()` takes `prominence` and returns `emph = prominence * appetite * (1 - 0.55 * spent)`. The spent-emphasis EMA spaces the big
leans but cannot delete an accent the sentence requires; the seeded push multiplies words that are already prominent. In `plan()`
the accent's size scales with prominence.

### Honest limits

- Take-level statistics barely move; the phrasing dump and the ear are the evidence.
- Contrastive focus is not attempted ("I said the RED one" needs syntax or an author's mark); the nucleus lands wrongly, confidently.
- No syntactic phrasing: boundaries come from punctuation only.
- Rule 3 keys on the exact surface word, so `couch`/`couches` and `is`/`was` do not count as repeats.

---

## 23. Round eighteen - the override layer was a silent regression

387 of 414 `english.yml` lexicon entries and 105 of 110 reference entries were byte-identical to CMUdict, and the redundancy hid a
bug.

### The bug the redundancy was hiding

`english.yml` is the override layer and wins over CMUdict. Its entries carried no stress digits, so `_with_default_stress` marked the
first vowel primary, mis-stressing 56 high-frequency words whose primary stress is elsewhere (`about`, `because`, `before`,
`between`, `again`, `another`, `believe`, ...). A redundant override is a regression with no symptom until something reads it.

### What `english.yml` keeps

Four lexicon entries: two homographs where the system picks a reading without part-of-speech tagging (`live`/`lives` as the verb),
and two words CMUdict lacks. The suffix, clitic and function-word tables stay. Overrides may carry stress digits, and must when
polysyllabic. Not reduced narrator forms: CMUdict lists function words in citation shape, and `function_words` forces stress 0 so
the per-syllable reduction centralizes the vowel at synthesis time; spelling `HH AH0 Z` would freeze one degree of reduction for
every speaker and tempo.

### A second bug that fell out of testing it

Stress flattening applied to all function words, so `about`, `between`, `under` and `after` had no stressed vowel. Only
monosyllabic function words reduce; polysyllabic prepositions keep internal stress and take no sentence accent (Phrasing's job).
Now gated on syllable count.

### `reference.yml` repurposed

It grades the paths CMUdict does not answer: `words` (a smoke set including overrides), `derived` (suffixes, clitics, plural
voicing), `fallback` (out-of-dictionary) and `stress` (the index of the primary-stressed vowel, `-1` for a reduced function word).
Nothing tested stress before, and stress is what the rhythm hangs off. `g2p_check`: words 9/9, derived 9/9, fallback 2/2, stress
17/17. The token-weighted WER is gone; it had become a measure of CMUdict's coverage.

---

## 24. Round nineteen - the staircase, recovered from git

### What the archaeology found

The first commit's melody was one line, `"semitones": decl + accent`: every phone took the sentence's declination, only the stressed
vowel the accent bump, silences reset to 0. The contour was a staircase (discrete pitch levels held flat per segment, instant
transitions, a hard reset at every pause), and that is what sounded like singing. The f0 continuity pass later lerped every
consonant onto the line between its neighbors, a correct fix for the picket fence that made singing unreachable.

### `song`: the ninth trait axis

It swaps four behaviors at once:

- **Notes:** a sung vowel takes a whole number of beats (`1 + round(prom * 2)`, so prominent syllables hold more). Integer beats
  give long-short patterns against a pulse; uniform stretching gives a drone. The beat follows the speaker's tempo and drawl.
- **Steps:** the continuity glide is gated by `1 - song`, so at the top of the axis a consonant holds the note it is inside.
- **Scale:** the anchor-shelf pull goes to 0.95, engaging fully by song 0.5.
- **Vibrato:** 5.5 Hz, 0.38 st, ramped in over 180 ms. The ProsodyField wander is scaled by `1 - song`.

Only the upper half of the axis sings, so the curated default and half of every roll stay speech. Separately, `rate` widened from
`2^(0.35*pace)` to `2^(0.55*pace)` (the slow end reached only 1.28x slower).

### Measured (`tests/voice/song_check.gd`)

    song   median note   p90     on-note   |df0/dt|
    0.0        71 ms    143 ms    35.2%    382 cents/s
    0.5       456 ms   1161 ms    54.1%    103 cents/s
    1.0       933 ms   1911 ms    61.2%     85 cents/s

Speech vowels have a median of 104 ms, with 0.17% reaching 400 ms, so no seed could sing before.

### Three bugs the measurement caught

- The tuning metric measured the vibrato (a +-38 cent waver is mostly outside a 25 cent window); it now smooths over one vibrato
  period first.
- The drone bank was tuned to the raw anchor while the melody realizes `anchor * inflect`; both it and the proximity test now use the
  realized pitch.
- The synth realizes `... * 1.06` (a fixed +1.01 st offset) that must come off a tracked f0 before comparing to the shelf.

### Honest limits

- Intelligibility is unchanged: `song` makes a voice sing, not a reading easier to follow.
- Median 933 ms at song 1.0 (max 2.16 s) is the extreme end.
- Vibrato has a fixed rate and depth.
- No metre: nothing aligns notes to a shared bar line.

---

## 25. Round twenty - singing gets a cadence, and stops being the default

### Why almost everything sang

`song` drew from the same `randfn(0, 0.55)` as the timbre axes, so half of wild rolls started above zero, and the belt compounds it
(acceptance-weighted `_pick_parent`, inherited jitter, `_temper_traits` pulling toward the party centre). `song` is a mode, not a
shade: it is drawn with an explicit incidence (`SONG_INCIDENCE` 0.28) and the negative draw is pushed to `[-1.0, -0.25]`. Over 4000
wild rolls, 29% sing at all and 17% strongly. The roll sits below the rate wanted in play, because the belt only amplifies.

### Why every sung word was slow

The beat grid stretched every vowel onto 1-3 beats, a drone. Music alternates held notes at the joints of a phrase with runs
between.

**The sustain gate.** A syllable is held when a slow seeded cycle over the syllable count, its prominence and whether it ends a
phrase add up past `SUSTAIN_BAR` (the thresholded-drive idiom of the activation channels, sparse and self-spacing). The cycle's
period and phase derive from `drawl`, `pace`, `lilt` and `grit`, so no new roll is needed. A syllable not held runs at `SONG_RUN`
0.72 of its spoken length, floored at `SONG_RUN_MIN` 75 ms. Two consequences were fixed:

- Runs had no pitch (the 35 ms f0 EMA never reached target), so the f0 time constant is `lerp(35 ms, 12 ms, song)`: a singer
  arrives on a pitch where a speaker glides onto it.
- The terminal contour (applied after the anchor pull, landing on the longest vowels, which the sustain gate also picks) knocked
  held notes 1 to 6.5 st off the scale. `_resnap` re-quantizes after the contour, so a fall becomes a fall to a note.

### Measured

    song  median  p90     on-note  held-note  |df0/dt|  total  spread  sustained
    0.0     71 ms  143 ms   35.2%    38.5%    382 c/s    5.8s  CV 0.49    0%
    0.5     74 ms  691 ms   57.8%    80.0%    227 c/s    7.1s  CV 1.35   10%
    1.0     72 ms 1175 ms   74.2%    91.6%     90 c/s    8.6s  CV 1.75   15%

"held-note" is tuning restricted to frames under 50 cents/s (it exposed the terminal-contour bug: 34.4% before the re-snap, 91.6%
after). Total length is 1.22x speech at song 0.5 and 1.48x at 1.0.

### Honest limits

- The sustained fraction (10-15%) is set by the drive threshold, not targeted.
- Still no metre.
- Intelligibility is untouched.

---

## 26. Round twenty-one - the fishing field: audit, and two fixes

Seeds stop changing as the player drifts out, and the belt's "interference" does not behave like interference. Audit findings:

1. **Distance is a clock, not a position.** `_drift_dist` is an odometer integrated from time and velocity; `_cast_vector` moves the
   candidate through the 25-D space but its only consumer is the moon-phase drawing.
2. **Every gameplay consumer of drift saturated at odometer 1.0**, which the warp crosses in ~16 s: a clamp rather than a physics.
3. **The anneal cannot express interference.** `_adreno_step` is a sum of linear springs, which reduces to `W * (tbar - x)`: one
   attractor however many seeds, collapsing as the belt fills (caught-trait spread 0.152 -> 0.012 per axis).
4. **Its force is distance-independent** (a far member pulls harder).
5. **An interference field existed** (`_field_reception`) but drove only the audio reception filter, with sources at lineage hashes,
   one shared falloff length, and phase from wall-clock times array indices.
6. **The trust region widens with drift but its centre never moves.**
7. **The metric was broken:** `_seed_vector` normalized each genome delta by `|prior|`, so `hesit_bias` (prior 0.25) counted 38x
   more per unit than `breath_span` (prior 9.5) and carried 31% of all variance (effective dimensionality ~7.6 of 25).

### Shipped now (the two cheapest, and #7 is a prerequisite for everything else)

- **`_seed_vector` normalizes by each gene's own `G_BOUNDS` spread**, the range the gene is sampled and clamped over.
- **`_drift_free()`:** `log1p(_drift_reach())`, unbounded but soft-compressed, feeding the wild-throw chance, the child jitter and
  how far a throw lands from the belt. Reward, the reception band and anything laid out on a finite on-screen line keep the clamped
  `_drift_norm`.

### The field itself - designed, NOT built

(Built in section 27.) The field runs in the 3-axis frame (brightness / damage / drive) extended with `song`, genome folded through
a baked hyperplane bank, justified by measurement: a random cast's projection onto a source's wave vector has sd 0.58 in 3-D and
0.20 in 25-D, where 90% of casts land inside |cos| < 0.33 and angle stops discriminating. Per seed, all derived: position from
`_seed_vector`, strength from acceptance, range from `ring * (1 - damp)` normalized against the belt's median pairwise distance
(~40x span), wave vector and phase from the strongest `_lineage_mods` entry:

    a_i  = A_i * exp(-d_i / L_i)
    th_i = dot(k_i, p - x_i) + phi_i
    M    = sum_i a_i * cos(th_i) * unit(x_i - p)

`k_i` is a vector, so phase depends on distance and angle; `cos` has zero spatial mean, so `M` perturbs without biasing toward the
centroid (the guard against collapse). Migration is seven steps, each leaving a working game, starting with `src/voice/voice_field.gd`
plus `tests/voice/field_check.gd` and no call sites. The later steps must not ship before the metric fix.

A separate mechanism: `Spec.influences` (the pooled-oscillator blend, the belt's audible alchemy) is assigned only in `export_take`
and never on a live path, and an accepted catch's `override` genome replaces the blend outright.

---

## 27. Round twenty-two - the interference field, built

### How influence combined before

Three unchosen rules: `_field_reception` summed amplitudes arithmetically but blended frequencies as an amplitude-weighted geometric
mean; `_adreno_step` summed signed forces with a hard +-1 threshold on acceptance versus the belt mean; `_party_vector` and
`_background_traits` took positive-weighted arithmetic means, which never subtract.

### `src/voice/voice_field.gd`

`COMBINE` has four modes, different instruments rather than spellings of a sum:

- **sum:** superposition, a chord.
- **product:** a source on a null silences the whole belt; the field goes quiet in specific places.
- **max:** the strongest source wins; the belt as territories.
- **ring:** only pairwise products survive, so a lone seed radiates nothing and the field is made of relationships between seeds.

The mode a voice's water obeys derives from its lineage root, so it is a property fished for and inherited.

### On negative values

Amplitudes are signed and continuous, `tanh((acceptance - 1) * gain)`, so a seed liked less than average subtracts. The stronger
half is phase: each source carries a wave vector, so `cos(k . (p - x))` spans [-1, +1] as a function of where the candidate stands.
Two seeds reinforce here, partly cancel a step away and null a step further, so distance and angle matter. A signed scalar gives
subtraction; a phase gives a pattern.

### Everything derived, nothing rolled

- position: the seed's `_seed_vector` projected into 3 axes
- strength: its acceptance
- range: `ring * (1 - damp)` normalized against the belt's median (3.0x span on a 9-seed belt; the gene ranges allow ~40x)
- wave vector / phase: the strongest lineage modulator's rate and phase

Three axes rather than 25, for the measured reason in section 26.

### Wired at three sites

- **`_temper_traits`:** the cage's centre moves with the field instead of only widening. Far out the field dies and the centre
  returns to the plain centroid.
- **`_adreno_step`:** the reel hauls the line home across the interference pattern, so the anneal sees a changing field shaped by
  the cast bearing, weighted by `cool` so it matters most early in the fight.
- **`_field_reception`:** re-based on the same field, so what is heard and what the catch feels are one geometry. Its wall-clock
  beat survives as live shimmer only; a clock never reaches the trait path.

### `tests/voice/field_check.gd` - the first test the fishing loop has ever had

    determinism   identical, and independent of belt array order
    falloff       monotonic beyond the belt's extent, decays to 0.0% of edge
    angle         spread 1.64 across bearings at equal radius (needs > 0.50)
    range         3.0x span; dropping the longest-range seed moves the field
                  0.0763 vs 0.0128 for the shortest
    polarity      8/10 probes point OPPOSITE an all-positive belt
    budget        prox 0.741 at 4 seeds vs 1.000 at 22 (needs under 2x)
    modes         sum 0.48  product 0.69  max 0.40  ring 0.08, all distinct

The polarity and angle checks catch "a fourth attractor"; the budget check catches the belt homogenizing as it fills. Falloff is
measured from outside the belt's extent, since energy rightly rises approaching a source.

### Not done

- `_drift_dist` is still a scalar radius (the fight math, HUD arc and caption are defined on it).
- The HUD draws belt moons at hash-derived positions, not the field's.
- `Spec.influences` is still assigned only in `export_take`, and a catch's frozen genome replaces the blend.
- No end-to-end assertion that caught voices vary with distance and bearing.

---

## 28. Round twenty-three - the belt composes instead of selecting

A second or third seed on the belt should be able to bring in a mode (singing) and modulate it, and change which words are held, not
just make the signal stronger.

### What the belt did before: it SELECTED

A throw called `_pick_parent`, an acceptance-weighted roulette, and the child was a jittered copy of that one seed. Adding a singer
added a lottery ticket. The rest of the belt reached the candidate only through the trust region (which binds ~1% of throws) and the
field bias on its centre. `_background_traits`, the acceptance-weighted blend, was never used to derive a throw.

### `_ensemble_traits`

    out = dominant + sum_i w_i * (member_i - dominant)

- One seed on the belt, or no contributors drawn: byte-identical to before.
- `w > 0` pulls the child toward that member; a further contributor pushes it further.
- `w < 0` pushes the child away: combination that can only add converges on one voice.
- Always an interpolation around the dominant, so nothing runs away; the dominant keeps its lineage, identity, genome and scene.

How many contribute is gated by the field energy of section 27: near the belt is modulated, far is stable.

### The sustain bank - variety along the spectrum, not a louder signal

`Spec.sustain_bank` is a list of `[period, phase, weight]`, one per contributing voice, summed by `Spec.sustain_wave`. Incommensurate
periods give a long non-repeating held pattern, and signed weights let a contributor suppress a position the dominant would hold.
An empty bank is the single-cycle behavior.

`tests/voice/ensemble_check.gd`, held syllables of the first 60 at identical mean drive:

    solo      [1, 7, 18, 24, 29, 35, 40, 46, 57]
    + w       [7, 29, 51]
    - w       [18, 40]

    overlap: solo vs +w 0.20,  solo vs -w 0.22,  +w vs -w 0.00

Adding a seed rearranges the cadence rather than turning it up. A non-singer at -0.60 with one singer on the belt reaches song 0.08,
a second contributor takes it to 0.40; a negative weight takes a singer from 0.50 to 0.32; child spread over 4000 random belts is
0.580 against parent spread 0.578, so composing is not averaging.

### Not done, and one warning

- `Spec.influences` is dead on live paths, deliberately: `ProsodyWalk._init` blends genes as a uniform mean of PRIOR plus every
  lineage, so each influence pulls the genome toward the population centre (the halving that confined the melody genes). Its good
  half (pooling each lineage's modulators and anchors) is worth reviving separately, as a change inside ProsodyWalk.
- An accepted catch carries a frozen `adrenochrome` genome, and `ProsodyWalk._init` skips the blend and sets `_mods = []`, so the
  belt never contributes to a caught voice's genome. Changing it alters every caught voice's sound and wants an ear first.
- The sustain bank is built at throw time and carried on the live spec; it is not persisted, so a reload rebuilds it from the belt.
