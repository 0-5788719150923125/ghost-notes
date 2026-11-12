# Voice: the intelligibility program

A six-audit investigation of the Klatt formant engine (Synthesis' voice and the reading voice). Every number below was measured
against the code, not estimated; `file:line` references are from the repository root as of the audit and drift. The problem: the
voices are hard to understand without subtitles, and the goal is to narrate 35 chapters into video with the reading voice bred in
the fishing game.

---

## 1. Diagnosis

The engine's phonetic knowledge is sound. `phonemes.gd`'s TABLE carries textbook Klatt values (sibilants peaked high, /f/ and /th/
flat and diffuse in 4-10 kHz, per-place burst spectra, per-place nasal zeros), and the comment at `phonemes.gd:80-82` states the
principle: for the weak fricatives the cue is spectral contrast against the neighbor, not level. Almost nothing downstream honors
that. The damage is in the realization, the effects and the front end, ranked here by share of the intelligibility loss.

### Cause 1 - non-phonemic hiss masks the entire consonant band (~40% of the problem)

`spec.breath` (aspiration, default 0.05) and the `air` band (default 0.02, highpassed at `air_cut` 3000 Hz) are injected into the
source before the cascade, so the formants shape them like the voice and they land on top of it.

| band | share of vowel power supplied by hiss |
|---|---|
| 1.5-2.5 kHz | 70.8% |
| 2.5-4 kHz | 90.1% |
| 4-6 kHz | 84.9% |

| contrast, 2.5-5 kHz | with hiss | without | delta |
|---|---|---|---|
| fricative vs vowel | -4.05 dB | +5.96 dB | +10.02 |
| stop burst vs vowel | -21.18 dB | | ~+10 |

A fricative was quieter than the vowel beside it, in its own cue band. Category: wrong constants plus a routing choice. Cheap.

### Cause 2 - the consonant level column does not control level (~25%)

`namp` in the TABLE scales resonators that are peak-normalised, while delivered power goes as `sum(a_k^2 * BW_k)`.

- 4.4 dB of `namp` span across the six stops produces 16.5 dB of delivered burst span.
- The four voiceless fricatives land within 3.2 dB of each other (natural spread is 10-18 dB).
- /sh/ (`namp` 1.8, deliberately the highest) delivers 3.2 dB quieter than /s/ (natural /sh/ is 3-6 dB louder).
- Stop bursts sit 24-37 dB under the adjacent vowel (natural is 8-15 dB).

The whole parallel branch also passed through one global `FRIC_LEVEL := 0.05` (`voice.gd:188`, applied once at `voice.gd:1924`),
-26 dB on every fricative and burst. Category: wrong scaling law; needs a small derivation at table-load time.

### Cause 3 - place of articulation is not transmitted (~20%)

- **All six stops shared one formant onset.** `voice.gd:1328` retargets the cascade to the following vowel before the release run,
  so the locus excursion is spent before the burst. Onset-F2 spread across the three voiceless places: 35 Hz in /AA/, 22 Hz in
  /UW/ (natural 600-800 Hz). /b/=/d/=/g/ and /p/=/t/=/k/ acoustically.
- **/b d g/ had no release event.** `voice.gd:1331` gates the VOT run on voiceless only, so a voiced stop was 45-48 ms of closure, a
  9 ms burst at -42 dB, then the vowel (9.3% of all phones).
- **VOT was 24-28 ms for /p t k/**, on the 25-35 ms English category boundary; aspirated stops should run 50-90 ms.
- **Voiced fricatives were inverted**: voice bar exceeds frication by 9.4 to 13.7 dB, where the voiceless twins run -30.9 to
  -37.7, a 40-50 dB swing between /s/ and /z/.

Category: missing acoustic mechanism. Bounded and local.

### Cause 4 - vowel space collapse (~10%)

`reduce = 0.7` (`voice.gd:1101`) lerps all three formants 70% toward a fixed schwa `[500, 1500, 2500]` for every CMUdict stress-0
vowel.

| | Bark^2 |
|---|---|
| TABLE targets | 18.74 |
| after reduce=0.7 | 1.59 (8.5%) |
| LPC-measured, unstressed | 1.69 vs 11.49 stressed (85% collapse) |

It also drags F3, raising /ER/'s F3 from 1690 to 2257 Hz; a low F3 is American /r/, so unstressed "-er" was destroyed (7 of 7
tokens). The formant trajectory is a first-order EMA and `LOCUS_SHARE = 0.35` starts pulling toward the next target before the
current one is reached, so no segment arrives and holds: median attainment 0.77, falling to 0.61 at fast pace. Glides and nasals
got the slowest time constant (32 ms, `voice.gd:1677-1678`) on the shortest segments (60-75 ms), backwards for a ballistic gesture.

### Cause 5 - effects erase what survives (~5%, but free to fix)

- **The drone bank held a -16 dB floor under every pause.** `DRONE` defaulted true (`voice.gd:140`) and summed into every sample
  (`voice.gd:1955`). Boundary trough depth at a 40 ms gap: -15.5 dB with drone, -31.8 dB without. Silence never arrived, so word
  boundaries never appeared.
- **The leveler never compressed.** Its detector is block-mean |x| (median 0.023, p95 0.128) but `COMP_TARGET` is 0.42, a near-peak
  figure; 99.4% of blocks sit below the clamp point, so gain is pinned at `COMP_MAX` 1.5. It was a constant gain.
- **The location bandpass was baked into exports** (Q=2.5 state-variable bandpass, 55% wet, 1.8x makeup, plus a carrier tone),
  through `bake_location`. At prox 1.0 / 400 Hz: +5.6 dB at 300-800 Hz and -6.2 to -6.4 dB above 2.5 kHz. It must never touch a
  chapter render.
- **No switch produced a clean, dry, full-bandwidth voice.** Five effect families had five unrelated gating mechanisms, and the
  echo had no override (a per-segment planner value).

### Cause 6 - the front end, which is the worst of it for a book

On typographic manuscript text, 10.4% of tokens were damaged before synthesis began:

| defect | file | measured |
|---|---|---|
| numerals silently deleted (no digit in any char table) | `phonemes.gd:119-137, 549-571` | 2.2% of tokens dropped; 0 of 11 numeric forms survived |
| curly quotes, apostrophes, em dash, ellipsis in no char set | `phonemes.gd:216, 223` | coverage 88.3% typographic vs 92.7% ASCII |
| punctuation stripped before quotes, so dialogue-final words miss the dictionary | `phonemes.gd:216-223` | fixing order alone: 88.3% -> 95.7% |
| hyphenated compounds fused, parts never looked up | `phonemes.gd:549-571` | 7/7 wrong |
| newline treated as a sentence stop | `phonemes.gd:270-273` | 18 spurious full stops per chapter sample |
| abbreviation periods treated as stops | | 7 of 42 stops false |
| suffix/stem machinery unreachable (letter rules always return non-empty, so the raw base wins) | `phonemes.gd:631-642` | 12/12 restore_e and 12/12 undouble cases dead |
| letter-to-sound quality | `phonemes.gd:119-137` | 19 of 27 ordinary out-of-dictionary words plainly wrong (70%) |

### Cause 7 - the game is selecting for unintelligibility

A structural trap, not a bug. The toll (`synth_editor.gd:1314-1317`) frays exactly `[grit, air, breath]` toward the rail as a
foreign seed is reeled in: `x += TOLL_FRAY * toll^2 * (1 - x)`, saturating, with no opposing term. At difficulty 1.0 the medians
land at grit 0.89 / air 0.90 / breath 0.92 (shimmer 0.081, `air_cut` 1938 Hz, `air_gain` 0.047, breath 0.116). Those are the three
parameters of Cause 1 at about 2.4x the default, so the seeds worked hardest to catch are the least intelligible ones.

Related: the annealed genome bypasses `G_BOUNDS` (`voice.gd:585-589` takes the override branch; bounds apply only inside
`_lineage_genome` at `voice.gd:730-732`). At d=1.0 that yields `act_thr` p05 = -0.898 and `breath_span` p05 = -3.771, both negative
and below a floor meant to keep an elaborate lineage a voice. And breeding cannot remove the problems: the genome is an unweighted
mean of the PRIOR plus each lineage (`voice.gd:591-599`), so with one lineage every gene moves at most halfway to its bound (best
achievable hesitation rate ~4.8% against a 1.6% default). The only escape from the prior is the toll.

### Cause 8 - inflection

Seven melodic terms sum with no budget: declination, motif tilt, ring (to +-3.15 st), accent (`spec.f0_accent` hardcoded 4.0 at
`voice.gd:336`, reaching +7.5 st), microprosody, terminal contour and the pitch attractors. Per-sentence f0 span: p50 8.95 st, p95
13.89, max 16.04 at `lilt = 0`, and 17.91 st median at `lilt = +1`; adjacent-vowel jumps reach 7.13 st at p95.

Unasked-for: breath pauses fire on 7.5% of words with 41% landing mid-phrase (`voice.gd:881-882`, a syllable counter with no
reference to syntax), and disfluencies run 16 per 1000 words, 40% of them a spoken "uh" (roughly 900 audible "uh"s over a 140k-word
book).

---

## 2. Fastest path to an audible difference

Constants or a flag, no new mechanisms, all reversible, ordered by impact over effort.

1. **`NOISE_FX := false`** (`voice.gd:111`): recovers ~10 dB of consonant-to-vowel contrast. The principled end state is noise tied
   to glottal open quotient and pushed 10-12 dB down.
2. **`DRONE := false`** (`voice.gd:140`): restores 16 dB of boundary trough depth. The drone stays an opt-in atmosphere for the game.
3. **Zero the echo send and the location bake for renders.** The echo needs a small override; `bake_location` leaves the export path.
4. **Cap `reduce` at 0.25-0.35 and exempt F3** (`voice.gd:1101`, `voice.gd:1570`): undershoot already supplies the centralization a
   short vowel should have, and the explicit lerp doubled it.
5. **Raise `FRIC_LEVEL` and give bursts their own scaler**: a burst is a transient and a fricative a steady state. Do this after 1.
6. **Fix the front-end normalization order** (strip wrappers, then terminal punctuation, then wrappers again) and add the Unicode
   punctuation block: coverage 88.3% -> 95.7%.
7. **Apply `G_BOUNDS` in `ProsodyWalk._init` to both branches.**

Items 1, 2 and 4 together are the difference between unusable and usable but rough.

---

## 3. The measurement gate

Judging by ear alone produced this state: several rounds traded intelligibility for pleasantness, reducing the frication level
because it offended when the offence was masking. A gate lands alongside the cheap fixes. Three tiers:

- **Cheap always-on proxy, numpy only.** (a) Per-phoneme-class delivered level relative to mean vowel, against a target table; (b)
  vowel space hull area in Bark^2, stressed and unstressed separately; (c) word-boundary trough depth distribution. Wired into
  `tests/voice/voice_check.gd`.
- **Primary metric: ASR word error rate.** Synthesize known text, transcribe, compare; alignment is known by construction. An ASR
  model used as a test oracle ships nothing and never touches the render path, but it is a dependency and a download (whisper-small
  is ~500 MB), so it is the author's call. Target: WER under 10% on clean narration.
- **Human protocol.** A modified rhyme test over minimal pairs (bat/pat/mat/cat, sit/sip/sick, thin/fin/sin) isolates which
  contrast is failing. Given Cause 3, stop place and /f/-/th/ were expected at chance.

---

## 4. The acoustic work

Only after the gate exists. Each item is bounded and local.

1. **Make the amplitude column mean what it says.** `namp` becomes a target delivered level in dB relative to a reference vowel,
   with per-pole gains derived at load time from `sum(a_k^2 * BW_k * pi/2)`.
2. **Hold the stop's own locus through the release**, and let the following vowel carry the glide. Voiceless fricatives already get
   this at `voice.gd:1355` (`nxt if voiced else []`). This makes /b/, /d/ and /g/ different sounds.
3. **Per-phoneme VOT as a table field**, not `dur * 0.3`: 55-75 ms for aspirated /p t k/, 5-15 ms for /b d g/, near zero in
   /s/-clusters, with a short voiced-VOT run so /b d g/ have a release event.
4. **Rebalance voiced obstruents**: decouple the voicing amplitude from the frication level and honor `seg.amp` so stress reaches them.
5. **Replace the fixed-tau EMA with a time-normalized trajectory**: a fixed 40-60 ms transition at segment onset, an explicit hold
   at target, then the locus glide. This fixes undershoot and the glide/nasal inversion.
6. **Give the melody a budget**, as `MOD_BUDGET` (`voice.gd:542`) does for the modulator set. Structural terms (declination, accent
   scaled by prominence, terminal contour) are split from decorative ones (motif tilt, ring, attractors), which compete for a fixed
   share. Target a p95 sentence span near 6-8 st rather than 13.9.
7. **Move the toll off `[grit, air, breath]`** onto axes a listener tolerates: pitch register, tract length, tempo, drawl, drone
   character. A foreign catch should cost something audible, but not intelligibility.
8. **Breath placement as a search over legal sites**: `Phrasing` knows content vs function words and phrase ends; the counter
   proposes and phrasing chooses.
9. **Hesitation behind a register switch**, not on the genome: a property of spontaneous speech, kept for the fishing instrument
   and absent from a chapter.

---

## 5. Architecture

`voice.gd` is 1198 lines of code under 798 lines of comment, so the problem is concentration and typing, not volume.

- **No stage boundary carries a typed record.** Text to words, words to phrasing, words to prosody, prosody to segments, segments
  to acoustics, acoustics to delivery all pass bare `Dictionary`/`Array`, read through `.get(key, default)`, so a field a producer
  forgets or misspells resolves to a default forever instead of failing at parse time (a bug class named at
  `mask_session.gd:110-118`).
- **312 segments from a 72-word paragraph arrive in two key shapes** (75 with 11 keys, 237 with 12) from three constructors.
- **`plan()` writes `amp` on every segment; `synth()` reads it only for vowels, glides and nasals.** Fricatives, stops and aspiration
  (33.4% of the take by time, 101 of 312 segments) discard their planned dynamics (mean |amp - 1| of 0.134): emphasis, the nuclear
  accent and function-word reduction never reach a third of the audio. This is the clearest argument for typed records, and a
  direct intelligibility bug.
- `synth_state()` is a flat 61-key untyped Dictionary tangling filter state, source state, EMA smoothers, prosody realization,
  effect state, mastering state and the output timing map.
- `_run_frames` is 407 lines with 12 positional parameters, nesting depth 8, spanning eight concerns.

A per-sample DSP kernel being long and imperative is not itself a flaw: one virtual call per stage per sample is ~220k dynamic
dispatches per second of audio on a thread that must hold a 2.5 s lead, which GDScript cannot afford. The inner loop stays flat;
everything that is not the inner loop comes out of it (~86 lines of preamble, ~85 of per-frame scheduling, ~62 of drone, ~48 of
master bus, ~16 of write-back), leaving roughly 110 lines of per-sample kernel.

### The target shape

Eight stages, each with one typed record crossing its boundary. GDScript 4 inner classes (`class X extends RefCounted` with typed
`var`s) give parse-time member checking, which `.get()` throws away:

```
SourceText  -> normalize   -> NormalizedText   (numerals, unicode, abbreviations expanded)
            -> tokenize    -> Token[]          (surface, wrappers, terminal punct, pause class)
            -> g2p         -> LexicalWord[]    (phones, stress, syllables, provenance: dict|rules|inline)
            -> phrase      -> PhrasedWord[]    (prominence, phrase position, given/new)
            -> plan        -> Segment[]        (phone, dur, f0, amp, reduce, echo, locus)
            -> realize     -> AudioBlock[]     (the kernel; state as typed sub-objects)
            -> master      -> Take             (pcm + word/phone timing map)
            -> deliver     -> stream or file
```

Three things become data rather than code:

- **A phoneme is a definition record**: type, formant targets, bandwidths, parallel poles, target delivered level in dB, VOT,
  closure fraction, locus behavior. Section 4 item 1 then becomes a load-time derivation over that record.
- **A voice configuration is one object** whether it came from a preset, a bred seed or a diagnostic A/B. `RAW_MODE`, `NOISE_FX`,
  `DRONE` and `FRIC_LEVEL` were static vars and module constants reachable only by editing the file, so every investigation had to
  patch source (`tests/voice/pure_say.gd` saves and restores a static var).
- **The effect chain is a declared ordered list**, inspectable and per-context, so clean narration and fishing atmosphere are two
  configurations rather than two code paths (the move `mask_session.gd`'s `MASK_EFFECTS`/`EFFECT_CONTROLS` makes for the mask editor).

### Ordering, which is the real question

Restructuring first would delay every audible improvement behind a refactor with no gate; restructuring last leaves items 1-5 in
section 4 each touching a boundary that wants a type. So: cheap constants (section 2) land with no structural change, then the
gate, then the typed record for the one stage each acoustic fix touches, as part of that fix. `Segment` comes first (item 1 and the
`amp` bug live there), `PhonemeDef` with the amplitude-column work, and `SynthState`'s split into six typed sub-objects with the
trajectory rewrite.

Determinism: seeds reproduce forever, so every restructure step needs a byte-identical check on a fixed lineage before and after
(`tests/voice/voice_check.gd` asserts it). The acoustic fixes change output by design, so a version marker on the voice config
treats pre-fix seeds as a different generation.

---

## 6. The book pipeline

Feeding 35 chapters needs:

- **A real text normalization stage**: cardinals, ordinals, decimals, times, currency, percentages, years, roman numerals,
  abbreviations, acronyms. Without it numbers are deleted silently.
- **Pronunciation overrides for invented proper nouns.** The inline `[K AE T]` mechanism is the right primitive; a per-project
  lexicon file spells a name phonetically once. Given 70% letter-to-sound failure on out-of-dictionary words, this is required for
  fiction.
- **A pronunciation audit pass**: run a chapter, report every token that fell through to letter rules with its phone string, as a
  worklist before rendering.
- **Chapter-scale batching** with a stable seed: same bred lineage, same voice config version, across all 35 renders.
- **A clean-narration effect configuration** (section 2, item 3) that the export path selects.

---

## 7. Sequencing

```
A. Cheap constants (hours)          NOISE_FX, DRONE, reduce cap + F3 exempt, G_BOUNDS fix
                                    -> listen. Independent of everything else.
B. Front-end normalization order    coverage 88.3 -> 95.7%. Independent of A.
   + unicode punctuation (hours)
C. Measurement gate (small)         numpy proxies into voice_check.gd. Needs A to have a baseline.
   + ASR WER (decision needed)
D. Amplitude column as dB target    needs C to verify. Unblocks all consonant balancing.
   (small-medium)
E. Stop locus + VOT + voiced        needs D. The largest single intelligibility gain after A.
   release (medium)
F. Trajectory rewrite (medium)      needs C. Independent of D/E.
G. Melody budget + breath placement needs C. Independent of D/E/F.
   + hesitation register (medium)
H. Toll channel change (small)      independent, but pointless before A.
I. Text normalization stage +       needs B. Required before any real chapter render.
   project lexicon (medium)
J. Clean-narration config (small)   needs A. Required before any real chapter render.
```

---

## 8. Open questions

1. **ASR oracle: yes or no?** ~500 MB one-time download, test-only. Without it the gate is acoustic proxies only, which catch
   regressions but do not measure intelligibility directly.
2. **What should the default voice be optimized for?** The fishing loop wants a voice that is alive and strange, the chapter one
   that is clear. Section 4 item 9 assumes two registers over one engine.
3. **Is `reduce` doing anything wanted?** The recommendation caps it hard. If the heavily reduced quality is liked on some seeds, it
   becomes a genome axis rather than a constant.
4. **Seed generation break.** The acoustic fixes change output for every existing lineage. This is acceptable (no belt to
   preserve), with a version marker so old takes are explicable.
5. Unmeasured: cross-platform float determinism of the synthesizer. Not urgent while everything runs on one machine, but the game's
   guarantees depend on it.

---

## 9. Status, 2026-08-08

**Landed.** Phase A in full (`NOISE_FX` off, `DRONE` off, `reduce` 0.7 -> 0.3, F3 exempted, `G_BOUNDS` applied at point of use).
Phase C, the measurement gate: `tests/render_fixtures.gd` renders three fixed fixtures with ground-truth alignment, and
`measure_voice.py` measures them with numpy (per-class delivered level against literature bands, vowel-space hull area in Bark^2,
word-boundary trough depth, octave-band energy) plus optional ASR word error rate. Artifacts land in `build/voice/`, gitignored.
Phase D in full: the parallel branch is power-normalized in `_tune_parallel`, so `namp` controls delivered level, and the column
was re-seated from measurement. Phase E items 2 and 3: stops hold their own locus through the release and hand the glide forward,
and /b d g/ have a voiced release event.

**Measured effect.**

| metric | before | after |
|---|---|---|
| sibilant level re vowel | -8.1 dB | -3.8 dB (target -8 to +2) |
| weak fricative re vowel | -6.4 dB (at parity with sibilants) | -12.4 to -17.1 dB (target -25 to -10) |
| voiceless fricative spread | 3.2 dB | 8.5 dB (natural 10-18) |
| voiced stop level re vowel | -23.0 dB | -18.2 dB (target -20 to -6) |
| word-boundary trough, >=40 ms gaps | -15.5 dB | digital silence |
| ASR WER, narration fixture | not measured | 4.5% |
| ASR WER, consonant-dense fixture | not measured | 36.7% |

`tests/voice/voice_check.gd` reports ALL OK: trait determinism, lineage reproducibility and ornament aging held.

The WER numbers need care. 4.5% on connected prose flatters context-rich text, since whisper's language model repairs phonetic
damage from context. The consonant-dense fixture at 36.7% is the more honest signal, and its errors are all stop place or voicing
confusions (`Take the cake, bake the dough, and go` came back as `Tape the cape, tape the toe, a bone`).

**Not yet done**, in the plan's order: Phase E item 1 (per-phoneme VOT as a table field; the remaining stop confusions point at it),
Phase F (the trajectory rewrite; the consonant-dense fixture shows a 0.216 vowel-space ratio against a 0.40 gate), Phase G (melody
budget, breath placement, hesitation register), Phases B and I (the text front end, untouched and the largest single risk to the
35-chapter run), Phase H (toll channel), Phase J (clean-narration configuration).

---

## 10. Second round, 2026-08-08: the Klatt reference comparison

A past `RAW_MODE` bypass sounded equally bad, which rules out the modulation stack and points at the base source-filter path.

**Platform verdict: not the constraint.** A kernel carrying Klatt's entire Fig. 6 inventory (17 second-order sections, retuned
every 1.45 ms, pitch-synchronous noise) benchmarks at 9.0x real time, 11.1% of one core, 1.9x faster than ghost's six-pole kernel,
because 67% of ghost's per-sample cost is `Reso.step()` dispatch rather than arithmetic. Klatt 1980 ran 6x real time on a
PDP-11/45; DECtalk scored 97% on the Modified Rhyme Test against 97-99% for natural speech. GDScript floats are IEEE doubles,
`Reso.tune` hits its bandwidth within 1 Hz, and the audio path is bit-transparent.

**Measure tilt per class.** Whole-take spectral tilt averages voice with consonant noise, and ghost's two errors were opposite, so
they cancelled: vowels-only tilt was -11.5 dB/oct (too dark) while /S/ was +10.7 dB/oct (too bright). `measure_voice.py` measures
tilt per class and never gates on the mixed number.

**Four causes, each with a primary source, fixed this round.**

1. *The hiss.* Klatt 1980 p.977 low-passes the noise source so lip radiation "exactly cancels out the effects of LPF", giving flat
   frication. Ghost had no such filter, so the parallel branch got the full +6 dB/oct differentiator. Frication now sums after
   radiation. Obstruent tilt +5.2 to +10.7 -> -1.2 to -2.6 dB/oct. The level was never the problem.
2. *The muffle.* Klatt Table I clusters F4/F5 at 3300/3750 for "an energy concentration around 3 to 3.5 kHz and a rapid falloff
   above about 4 kHz". Ghost had 3400/4700. F5 -> 3800, B5 -> 200. 2500-4000 Hz band energy -20.79 -> -7.54 dB; 1500-2500 -16.47 ->
   -11.33. Measured vowel spectra matched the analytic prediction of ghost's own equations within 1.5 dB.
3. *The clicks.* KLSYN88 ch. 3 (after Fujisaki and Azemi 1971) rescales `y1`/`y2` by `sqrt(A'/A)` every time F1-F3 are set. Ghost
   retuned six poles 690 times per second per pole with the history untouched. Zeroing the parallel bank does nothing, since that
   bank is already silent between consonants; the cascade is the one that matters. (Round 2b: the rescale made the click metric
   worse.)
4. *Target attainment.* Only 25.5% of vowels reached within 5% of their F1 target. The locus glide is not implicated (removing it
   moves attainment by 0.00); the EMA time constant is: 24 ms gives 3 tau = 72 ms against a median 95 ms vowel. Time constants halved.

**Result: the spectra improved and the ASR proxy got worse.**

| | before round 2 | after |
|---|---|---|
| obstruent tilt | +5.2 to +10.7 dB/oct | -1.2 to -2.6 (flat target) |
| 2500-4000 Hz energy | -20.79 dB | -7.54 dB |
| 6000-14000 Hz energy | -20.6 dB | -24.7 dB |
| WER, narration | 4.5% | 10.4% |
| WER, consonant-dense | 36.7% | 40.8% |

Individual errors moved both ways. At 67 words a 3-to-7 error change is near the fixture's resolution, so the result is
unresolved, neither a clean regression nor a win. The fixture set needs to be several times larger before WER can adjudicate changes
this size.

**Open, in priority order.** Restage `BURST_GAIN` (voiceless stops measure -16.5 to -18.0 dB re vowel against a -15 to -5 target).
Vowel-space ratio is 0.24-0.37 against a 0.40 gate. Peak is pinned at -1.54 dBFS on every fixture even after `OUT_GAIN` 4.5 -> 3.2,
so the lookahead limiter still works on transients and the crest factor wants investigating. Then: a bounded noise envelope
replacing the unbounded `nampsm` EMA (74 ms decay against Klatt's bounded 5 ms), pitch-synchronous noise modulation,
period-latched voicing amplitude, and the parallel branch derived from the cascade's own formants (Klatt p.981: this prevents
frication "dissociating from the rest of the speech signal", and is the answer to the second-source finding in voice_rca.md).

### THE FINDING THAT REFRAMES ALL OF THIS

DECtalk "Perfect Paul", the commercial descendant of Klatt's synthesizer, has the same clicks, pops and static as ghost, quieter
and less frequent, and is itself hard to understand. There was never a single bug to find: these artifacts are inherent to the
method, since gating noise sources on and off and retuning resonators while they ring produces transients. The refuted hypotheses
in the table below are a map of where not to look again.

1. **The goal is minimize-and-mask, not eliminate.** DECtalk masked its own artifacts under an 8-bit-era noise floor. `NOISE_FX =
   false` bought +10 dB of consonant contrast and threw that masking away, so it is back at `NOISE_TRIM = 0.25` (~12 dB under the
   old level): enough floor to bury the transients, far short of the 90% of vowel power at 2.5-4 kHz that breath and air used to
   supply.
2. **The ceiling is two numbers.** Intelligibility in this class is essentially solved (DECtalk scored 97% on the Modified Rhyme
   Test), so nothing physical stands between ghost and a voice that needs no subtitles. Naturalness has a hard ceiling well below
   human, because a simplified source through a handful of poles discards what the ear reads as a person. If the requirement is
   natural, it needs a different method; if it is "stylized and alive" (next/voice.md), this method can reach it.

### Round 2b: the clicks are still unsolved, and here is everything they are not

Seven interventions, each with a plausible mechanism, each measured. None moved the click rate, which sits at 4-5/s (coarse
detector) or 13-14/s (6-sigma block-local detector).

| intervention | rationale | result |
|---|---|---|
| lower `FRIC_LEVEL` | peaks hitting saturation | 0.006% above the knee; not saturation |
| drop the burst forward-glide | tract traversing its excursion in 8 ms | unchanged |
| `NOISE_FX` on | noise floor was masking them | 4.87 vs 5.15/s |
| zero parallel-bank state on retune | filter transient at coefficient change | identical to 4 decimals |
| `sqrt(A'/A)` cascade history rescale | Klatt KLSYN88 "clicks and burps" | worse: 689 Hz AM, heard as "electrical" |
| `FRAME` 64 -> 16 | zipper noise from parameter stepping | 12.87 -> 11.81/s |
| `RAW_MODE` on (all modulation bypassed) | modulation stepping | 14.03/s, higher than with modulation on |
| unipolar pulse table + DC blocker + 512 points | per-period gain stepping a -0.30 pedestal | 12.87 -> 14.15/s |

This rules out saturation, the noise route, the masking floor, filter state carry-over, the parameter update rate, the modulation
stack and the glottal pedestal. The events sit on voiced phones (AE, AH, T, D, K, M) and at stop bursts.

The likely remaining explanation is that the detector partly flags glottal closures, the sharpest legitimate event in voiced
speech: raising the wavetable to 512 points made closures sharper, and the count went up. The reference read's own detector
reported 3.19 events/s confined to stop phones, where this reimplementation reports 13-14/s including vowels. Neither has been
validated against a human reference recording passed through the same code, so no tuning should chase this metric until it is
calibrated on real speech.

Nothing has measured what is actually heard. `render_fixtures.gd` calls `Voice.render`; the live path is
`VoiceStream._push_available`, which applies a presence gain and a one-pole low-pass at `900 * 2^(4*presence)` Hz (4135 Hz at
presence 0.55). A capture path through `VoiceStream` at presence 1.0 is the highest-value missing measurement.
