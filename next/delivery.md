# Delivery: how every word is said, at every scope

## Status

**Planned. Nothing here is built.** What exists today, and what this plan grows from:

- `<!-- delivery: quicker, brighter -->` leans the rest of a paragraph a step at a time on four axes (pace, brightness,
  pauses, volume), one value per sentence, eased half the way each sentence (`Delivery.lean_of`, `LEAN_EASE`).
- `<!-- inflect: none|rise -->...<!-- /inflect -->` takes away or adds a question's rise on the words it wraps; `*italic*`
  and `**bold**` hit a word (a pitch accent, a longer stressed vowel, louder). A question rises by rule
  (`hosts/voice/inflection.py`).
- `<!-- hesitation -->` is a silence spliced in; `Hmm.` is a hum held by overlap-add.

What the author still has to judge: the schema, the bank's breadth and sizes, and the open questions at the end.

## The idea

One vocabulary of ways to say words, written in three forms that differ only in how much text they cover:

| Form | Covers | Example |
|---|---|---|
| `[words]{terms}` | the words in the brackets | `a bird, a mouse, a frog, [and]{drawn, held} five arrows` |
| `<!-- delivery: terms -->` | a stretch: on its own line, the paragraph under it; inline, from there to the paragraph's end; with `<!-- /delivery -->`, to that close, across paragraphs | `<!-- delivery: excited, building -->` |
| `{term}` | a point: a sound the voice makes between words | `{sigh}`, `{breath}`, `{um}` |

A term is one of four kinds, each with an optional degree:

- **an expression** from the bank: `sarcastic`, `shouting`, `deadpan`, `sports commentator`;
- **an axis** moved: `faster`, `higher`, `flatter`, `breathier`, `pressed`, `pauses 0.5`;
- **an act** on a word: `rise`, `fall-rise`, `contrast`, `drawn`, `cut off`, `thrown away`;
- **a shape** over the stretch: `building`, `fading`, `swelling`, `sudden`, or a ramp on one axis (`speeding up`,
  `rising`, `getting softer`, `dying away`).

The bank's own rows are written in the same terms (an expression is a list of axis values), so an author can say a
delivery the bank has no name for, and a note can name its own (`<!-- delivery: giddy = excited, speeding up, breathier -->`).

Four deliveries this plan exists to make:

- An excited teller gaining speed through a paragraph, her pauses shortening and her pitch climbing:
  `<!-- delivery: excited, building -->`, or spelled out, `<!-- delivery: speeding up, tightening, rising -->`.
- A man keeping a straight face, nearly no inflection: `<!-- delivery: deadpan -->`.
- A shout: `[Get down!]{shouting}` - in the model, the pressed lane, the pitch up eight semitones, the vowels long.
- The beat before a list's last item: `[and]{drawn, held} five arrows` (the vowel drawn out at a level pitch),
  never a silence.

## What the voice can already do

Kokoro, as this host patches it, takes far more than any mark asks of it
(`hosts/voice/backends/kokoro.py`, `kokoro_moving.py`, `kokoro_sung.py`; next/voice_engines.md):

| Control | Granularity | Range | Reached from the script today |
|---|---|---|---|
| `dur_scale` (a multiplier on each sound's frames, before the round) | per phoneme | any, 25 ms frames | italic/bold stretch, the trail's hold, inflection's `slow` |
| `rest_floor` (frames at least) | per phoneme | any | off on Kokoro: the model holds the word through floored frames instead of resting |
| `speed` | per call (a sentence) | 0.4-1.6 Pace, the discourse plan's rate, the delivery lean | Pace, delivery `quicker`/`slower` |
| `f0_keep`/`f0_set` (the pitch curve into the decoder) | every 12.5 ms | multiplier / absolute | inflection's rules (a question's rise, an italic's accent), `inflect` |
| `n_keep`/`n_set` (the energy curve into the decoder) | every 12.5 ms | multiplier / absolute | only to voice a whispered vowel; singing |
| style per token (`[T, 256]`: 128 timbre, 128 prosody) | per token, smoothed over 125 ms | the 28 readers' space; `breath` (CPP) and `push` (alpha ratio, about 15 dB over 2 sigma) lanes | a voice's blend curves only |
| `_effort` (a shelf near 1.2 kHz and a gain) | per sentence | dial, contour, lean | Effort dial, delivery `louder`/`softer` |
| `_emphasize` (a gain with 30 ms ramps) | per word | +2.5 / +5 dB | italic / bold |
| `_whisper`, `_muffle` | per voice | 0-1 | the Tone |
| resample pitch | per sentence | +-1.5 st (Arc, lean), formants restored | Arc, delivery `brighter`/`graver` |
| splice (a silence) | per word boundary | 0-30 s | hesitation, the Pauses, the marks' rests |
| overlap-add hold | per word | to 0.95 s | `Hmm.` only |

The graph that takes a style per token and the graph that takes the curves are one graph when both are wanted
(`model_moving_sung.onnx`), and a cut of it returns the planned curves without the decoder (`model_moving_sung_curves.onnx`).
So everything below can be asked of one render.

**The gap.** Nothing a script says changes inside a sentence except a word's accent: every lean, every effort, every
pitch offset is one value per sentence, stepping at sentence ends. The style per token and the energy curve are never
reached from the words. And the delivery lean's `brighter` half-works on Kokoro: its `noise_scale` share is a no-op there.

## Prior art, and what is taken from each

| Family | What it has | Taken |
|---|---|---|
| W3C SSML 1.1 | `prosody` rate, pitch, range, volume, contour (pitch targets at % of the span), duration; `emphasis` strong/moderate/none/reduced; `break` strength or time | the axes and their units (multiplier, st, dB, %); relative values nested from the value outside; `reduced` as an act (thrown away) |
| W3C EmotionML | category sets (Ekman 6, everyday 17, OCC 22, FSRE 24), PAD and FSRE dimensions, a 0-1 `value`, `trace` (a sampled curve) | the research category sets as the bank's spine; a degree on a category |
| Azure `express-as` | 33 neural styles, 62 HD styles (sarcastic, hesitant, panting, pleading...), `styledegree` 0.01-2, roles by age | a style's degree on 0-2 with 1 its default; the style list as a coverage check; one style that is not loudness (Azure's `shouting` is effort) |
| Polly, Alexa, Google, IBM | whispered, soft phonation, vocal-tract length, auto breaths; emotion with low/medium/high; IBM's breathiness, glottal tension, pitch range as signed % | breath as a point; voice quality as axes; size left to the voice |
| ElevenLabs v3, Gemini TTS, Fish, OpenAI, Hume | open bracket tags placed before the words they shape, carrying forward; free-text arcs ("starting calm, then losing patience"); Fish's 49 emotions, tones, effects | a term goes where the change starts; arcs as shapes; the lesson that a direction fighting the words lands weakly, and that a tag is sometimes spoken |
| Parler-TTS / Data-Speech | 7 labeled bins per measure: very slowly ... very fast, very monotone ... very expressive | degree words mapped to measured bins |
| StyleTTS 2, Kokoro | a 256-number style, half timbre and half prosody; StyleTTS 2 blends each sentence's style with the last (t = 0.7) | what our style per token already is; carry across sentences |
| Apple embedded commands, SABLE, SAPI | `[[emph +]]`, `pbas`, `pmod`, `rate`; phoneme-level `/` `\` `>` `<` stacked for degree; TUNE (pitch targets inside each phoneme); a setting that persists until changed leaked state | degree by repetition; never a setting with no end: every stretch ends at its paragraph or its close |
| Jefferson (conversation analysis) | `so:::` (each colon about 0.1 s), `>fast<`, `<slow>`, `°quiet°`, CAPS loud, up and down arrows, `word-` cut off, `£smile£`, `~wobbly~`, `#creaky#` | elongation where the colons are (an optional shorthand); the cut-off; smile, tremor and creak as qualities |
| GAT 2 (German conversation analysis) | spans `<<f> words>` loud, `<<all>>` fast, and CHANGE OVER A SPAN: `cresc`, `dim`, `acc`, `rall`; accents rise, fall, level, rise-fall, fall-rise; lengths `:` 0.2-0.5 s, `::` 0.5-0.8, `:::` 0.8-1.0; form marks kept apart from interpretive comments (`<<surprised>>`) | the shapes over a stretch; the accent set; the length steps; form and interpretation as two kinds of term that combine |
| ToBI, Halliday | H*, L*, L+H* (contrast), L*+H (doubt, incredulity), H+!H* (reminding), phrase accents and boundary tones; Halliday's five tones | the word acts and what each means |
| Musical expression | accelerando, ritardando, crescendo, diminuendo, morendo, subito, poco a poco, fermata, staccato, legato, marcato, tenuto, sotto voce | the shapes' names and meanings; Friberg and Sundberg's measured ritardando curve |

Sources are listed at the end.

## The schema

### Forms and where each ends

- **`[words]{terms}`** covers exactly the bracketed words (one or many, inside one paragraph). It is Pandoc's bracketed
  span, the lightest wrap Markdown has; brackets with braces after them are never a pronunciation (`[K AE T]`) or a
  letter (`[a]`).
- **`<!-- delivery: terms -->`** on its own line covers the paragraph under it. Inline, it covers from the next word to
  the paragraph's end. With a later `<!-- /delivery -->` (inline or on its own line) it covers up to that close,
  across paragraphs. `<!-- delivery: steady -->` returns to the voice's own from there. Nothing persists past its
  paragraph without a close.
- **`{term}`** is a point between words: a vocal event (`{sigh}`, `{breath}`, `{gasp}`, `{um}`).
- **Shorthand, optional:** two or more colons after letters inside a word draw out the sound before them, about 0.1 s a
  colon (`a::nd`, `so:::`), as Jefferson writes it. A single colon is always punctuation.

### Terms

Comma-separated, any number, read left to right. Each is an expression, an axis, an act or a shape, with an optional
degree. Words are plain English; a term's synonyms (`aka`) resolve to it (`quicker` and `faster`, `hushed` and
`murmuring`). An unknown word is reported where the panel says what it did (`StatusLog`), never ignored silently:
agents already write words outside today's vocabulary (`brisker`).

### Degree

- **Words:** `barely` 0.25, `slightly` / `a little` 0.5, (none) 1, `quite` 1.5, `very` 1.75, `extremely` 2 - before or
  after the term (`very sad`, `drawn a little`).
- **Numbers:** a bare number after a term is its degree, 0-2 (`excited 0.6`), as Azure's `styledegree` and EmotionML's
  `value` are.
- **Repetition:** `faster faster` is `faster` twice, as Apple's stacked symbols and Jefferson's colons count.
- **What degree 1 is:** clearly that, as a good reader would give it - about half of what an actor gives it in the
  acted corpora, so `extremely` (2) is the acted value. Every number in the bank below is degree 1.

Degree scales an expression's distance from the voice's own: semitones and dB times the degree, multipliers to the
power of the degree (`rate 1.2` at 0.5 is `rate 1.095`).

### Shapes

A shape says how the stretch's terms move between its start and its end, as a share of the full degree at each word:

| Shape | Share across the stretch | Musical name |
|---|---|---|
| (none) | eased in over the first few words, held, eased out over the last | - |
| `building` | 0 to 1 | crescendo of the whole delivery, poco a poco |
| `fading` | 1 to 0 | diminuendo |
| `swelling` | 0 to 1 at three fifths, back to 0 | - |
| `sudden` | 1 from the first word, no ease | subito |

Position along the stretch is counted in syllables, which the phonemes give before anything is rendered (a stand-in for
time that a 0-1 ramp needs). A shape on a word covers that word's syllables.

### Numbers: the precise form

Every axis takes a value in its own unit, and a ramp takes two: `rate 1.3`, `rate 1.0..1.4`, `pitch +3st`,
`pitch 0..+5st`, `range 0.4`, `volume -6dB`, `pauses 0.5`, `breath 0.4`, `push 0.7`, `tremor 0.3`, `drawn 0.6s`.
These are SSML's units. The bank's rows are written this way, and so are tests.

### Combining

- Terms in one mark add: semitones and dB add, multipliers multiply. `angry, very loud` is angry with more volume.
- A stretch inside a stretch adds to it (SSML's relative values); a word's terms add to the stretch it is in.
- A later term for the same axis in the same mark replaces an earlier one only when both are numbers.
- Every axis is clamped to its limits after adding (below).
- All of it rides on the voice's own: its Tone, Pace, Pauses, Dynamics, Arc and Effort are the baseline, and the discourse
  plan (the paragraph's arc, the sentence's final lengthening) goes on underneath unless a term narrows it - `range`
  scales the arc and the inflection rules too, so a deadpan question barely rises.

### Who it belongs to

A delivery belongs to the voice speaking when it is reached (as today, per speaker). A speaker cue ends it unless it is
closed across the cue on purpose.

### Note-local expressions

`<!-- delivery: giddy = excited, speeding up, breathier -->` on a line of its own names a delivery for the rest of the
note, as `<!-- say: name = ... -->` names a pronunciation. Kept ones could go to the Library beside voices (open question).

### What is shown

The brackets, braces, colons and marks are never spoken or captioned. A word hit (`hit`, `hit hard`) still shows in
italics or bold, as `*word*` and `**word**` do now. The script editor's highlighter colors the three forms.

## The bank

### Axes

| Axis | Neutral | Limits | Words (degree 1) | Unit | Made by | Anchors |
|---|---|---|---|---|---|---|
| rate | x1 | x0.5-x2 | `slower` x0.87, `faster` x1.15 | multiplier | `dur_scale` per token (remainders carried across 25 ms frames) | conversational 4.75-5 syll/s, read 3.2; emotions -33% to +30% |
| pauses | x1 | x0-x3 | `tighter` x0.7, `looser` x1.4 | multiplier on every rest in the stretch | rest top-ups and splices per boundary | read pauses peak at 100-150 and 500-600 ms |
| pitch | 0 | -8..+14 st | `lower` -2, `higher` +2 | semitones | `f0_keep` = 2^(st/12) | fear +9.6 st, anger +5.7, surprise +14 (acted, Pell 2009); loud speech +8.2 |
| range | x1 | x0-x3 | `flatter` x0.6, `livelier` x1.5, `monotone` x0.15 | multiplier on the pitch's swing about its running mean | `f0_keep` from the planned curve (two passes) | anger x2.4, surprise x4.9, sadness x1.2; Parler's very monotone ... very expressive |
| volume | 0 | -20..+8 dB | `softer` -4, `louder` +4 | dB of level in the mix | gain per token with ramps, capped by the limiter | ISO 9921 relaxed 54 to max shout 90 dB(A) |
| effort | 0 | -1..1 | `lax`, `tense` | share of the tilt shelf | `_effort` per token, not per sentence | tense/harsh = stressed, angry, formal, confident (Gobl 2003) |
| push | 0 | -1..1 | `pressed` +0.6, `slack` -0.6 | lane (1 = 2 sigma of the readers) | style rows per token | alpha ratio about 15 dB over +-2 sigma |
| breath | 0 | -1..1 | `breathier` +0.5, `clearer` -0.5 | lane (1 = 3 sigma) | style rows per token | breathy/whispery = relaxed, intimate, sad, timid (Gobl 2003) |
| whisper | 0 | 0-1 | `whispered` 1 | share of noise excitation | `_whisper` per token (today per voice) | - |
| tremor | 0 | 0-1 | `trembling` 0.5 | 1 = +-0.8 st and +-3 dB at 5-8 Hz, its rate wandering | `f0_keep` and `n_keep` modulated (singing's ornament, made irregular) | crying despair F0 flutter (Burkhardt 2000) |
| energy | x1 | x0.5-x2 | - | multiplier on the decoder's energy curve | `n_keep` | to measure: the decoder levels a phrase as a whole |
| precision | 0 | -1..1 | `crisp`, `slurred` | consonant frames x(1 + 0.3 p) | `dur_scale` on consonants | precise for anger, imprecise for sadness (J&L 2003) |
| creak | 0 | 0-1 | `creaky` | to measure | a style axis found as breath and push were (H1-H2, jitter) | creak = relaxed, bored, sad (Gobl 2003) |
| smile | 0 | 0-1 | `smiling` | to measure | a timbre axis (F1/F2 up, lips spread) | Jefferson `£`; Burkhardt's joy: lips spread 10% |

### Word acts

On a word (or the last word of a stretch), placed on its stressed vowel by inflection's keyframes (`stress<`, `stress`,
`stress>`). The pitch numbers are degree 1, relative to the stretch's register and scaled by its range.

| Act | After | Contour and timing | Says |
|---|---|---|---|
| `hit` | H*, `*word*` | +3 st at the stressed vowel, -1 by the word's end; vowel x1.5; +2.5 dB | new, important |
| `hit hard` | `**word**` | +4.5 st; vowel x1.9; +5 dB | the word that matters most |
| `contrast` | L+H* | a dip, then a steep rise onto the stressed vowel, then a fall | this one, not that one; a correction |
| `scoop` | L*+H | low on the stressed vowel, rising late in the word | doubt, incredulity |
| `reminder` | H+!H* | a step down onto the stressed vowel | as we know |
| `rise` | H-H% | +6 st by the end (today's question rule) | a question, an open end |
| `low rise` | L* H-H% | low, then +4 st at the very end | a polite or tentative question |
| `fall` | H* L-L% | a full fall to the floor | final, certain (a question said as a statement) |
| `rise-fall` | Halliday 5, GAT ˆ | +4 st then -5 st across the stressed vowel | impressed, insisting |
| `fall-rise` | Halliday 4, GAT ˇ | -3 st then +3 st | reservation, an implied "but" |
| `held` | GAT ¯, a level tone | level from the stressed vowel on, no fall | not finished: a list, suspense |
| `chant` | the vocative call | two levels, high then a step lower, both held | calling a name across a room |
| `drawn` | Jefferson `:`, GAT `:` | the word's rime continuants held 0.35 s more (0.2 a little, 0.7 very), pitch level, energy sustained | searching, suspense, savoring |
| `clipped` | - | the last sound cut short, no trail | curt |
| `cut off` | Jefferson `word-` | the word stops at its stressed vowel's end with a glottal close | interrupted, broken off |
| `spaced` | marcato, staccato | each syllable hit, 60 ms between them | ab-so-lute-ly |
| `thrown away` | SSML `reduced` | x1.2 rate, range x0.4, -3 dB, no accent | an aside, not worth a stress |
| `none` | `inflect: none` | no accent and no rise the text would give | as plain as the voice says it |

### Shapes and ramps

Shapes move a whole delivery (above). A ramp moves one axis from the voice's own (or the stretch's start) to an end:

| Ramp | Axis, start to end at degree 1 | Curve | Musical name |
|---|---|---|---|
| `speeding up` | rate x1 to x1.3 | Friberg-Sundberg, q = 2 | accelerando |
| `slowing down` | rate x1 to x0.75 | v(x) = [1 + (w^q - 1) x]^(1/q), w the end over the start, q = 2 (constant braking force) | ritardando |
| `running down` | rate x1 to x0.7 | the same, q = 3 (constant braking power) | rallentando |
| `rising` | pitch 0 to +4 st | linear in syllables | - |
| `sinking` | pitch 0 to -3 st | linear | - |
| `getting louder` | volume 0 to +6 dB | linear in dB | crescendo |
| `getting softer` | volume 0 to -6 dB | linear in dB | diminuendo |
| `tightening` | pauses x1 to x0.5 | linear | picking up the cues |
| `loosening` | pauses x1 to x1.8 | linear | - |
| `opening up` | range x1 to x1.6 | linear | - |
| `flattening` | range x1 to x0.5 | linear | - |
| `dying away` | rate to x0.8, volume to -8 dB, pitch to -2 st, breath to +0.4 | together | morendo, smorzando |
| `heating up` | rate to x1.2, pitch to +3 st, volume to +5 dB, push to +0.5 | together | - |
| `cooling down` | the reverse of heating up | together | - |
| `holding the last` | the stretch's last word drawn 0.6 s | - | fermata |

### Expressions

Every value is degree 1, as a change from the voice's own: rate and pauses are multipliers, pitch in semitones, range a
multiplier, volume in dB, push and breath lanes. The anchors are acted-corpus figures (degree 2 would match them).
A blank is no change.

**Lively, positive**

| Expression | rate | pauses | pitch | range | volume | push | breath | Also | Anchors |
|---|---|---|---|---|---|---|---|---|---|
| excited | 1.15 | 0.75 | +3 | 1.6 | +3 | 0.3 | | accents rise | elation: F0, range, loudness up (Banse & Scherer 1996) |
| joyful | 1.05 | 0.9 | +2.5 | 1.5 | +2 | 0.1 | | smiling | happiness +3.2 st, range x1.7 (Pell 2009) |
| amused | 1.05 | 0.9 | +2 | 1.4 | +1 | | 0.3 | laughter in it past degree 1 | epistemic positives highest in pitch (Kamiloglu 2020) |
| playful | 1.1 | 0.9 | +2 | 1.5 | +1 | | | fall-rise, sing-song | - |
| triumphant | 0.95 | 1 | +1 | 1.3 | +4 | 0.4 | | full falls | pride: faster, louder (Kamiloglu 2020) |
| amazed | 0.85 | 1.3 | +2 | 1.6 | | | 0.4 | rise-fall, drawn | awe (Cowen 2019) |
| surprised | 0.95 | | +6 | 2.5 | +3 | 0.2 | | rise-fall on the key word | +14 st, range x4.9 (Pell 2009) |
| curious | 1.05 | | +1.5 | 1.3 | +1 | | | rises | interest: F0 and variability up (Kamiloglu 2020) |
| eager | 1.12 | 0.8 | +1.5 | 1.3 | +2 | 0.2 | | - | - |

**Heated, negative**

| Expression | rate | pauses | pitch | range | volume | push | breath | Also | Anchors |
|---|---|---|---|---|---|---|---|---|---|
| angry | 1.1 | 0.8 | +4 | 1.8 | +5 | 0.7 | | steep falls, crisp | +5.7 st, x2.4 (Pell); +9 dB on stresses, rate +30% (Burkhardt) |
| furious | angry 2 | | | | | | | | hot anger |
| seething | 0.9 | 1.3 | -1.5 | 1.4 | +1 | 0.5 | | clipped, crisp | cold anger: F0 -20%, range x2 (Burkhardt) |
| irritated | 1.05 | 0.9 | +1 | 1.2 | +2 | 0.4 | | clipped | GEMEP irritation |
| frustrated | 1 | 0.9 | +2 | 1.5 | +3 | 0.2 | 0.3 | sighed falls | - |
| disgusted | 0.8 | 1.1 | +1 | 1.4 | | 0.2 | | drawn key words, low falls | rate -33% (Pell) |
| contemptuous | 0.85 | 1.2 | -3 | 1.2 | -1 | 0.2 | | creaky, drawn, falls | lowest F0 of 14 (Banse & Scherer) |
| impatient | 1.15 | 0.7 | +1 | 1.2 | +3 | 0.3 | | clipped | - |
| urgent | 1.15 | 0.7 | +1 | 1.1 | +3 | 0.3 | | - | today's `urgent` |

**Afraid**

| Expression | rate | pauses | pitch | range | volume | push | breath | Also | Anchors |
|---|---|---|---|---|---|---|---|---|---|
| nervous | 1.08 | 1.1 | +0.5 | 0.8 | -1 | | 0.3 | uneven timing, `{um}` | anxiety: F0 and range below the mean (Banse & Scherer) |
| scared | 1.15 | 0.8 | +5 | 1.2 | +1 | | 0.4 | tremor 0.3 | fear +9.6 st (Pell); variability low (J&L 2003) |
| panicked | 1.3 | 0.6 | +8 | 1.5 | +4 | 0.2 | 0.3 | tremor 0.5, rising ends | panic: F0 +150%, falsetto (Burkhardt) |
| desperate | 0.9 | 1.1 | +4 | 0.8 | +4 | | 0.3 | tremor 0.3 | despair: F0 up, variability down (Banse & Scherer) |
| pleading | 0.92 | 1.1 | +3 | 1.4 | +1 | | 0.4 | tremor 0.2, rises, drawn | - |

**Low, negative**

| Expression | rate | pauses | pitch | range | volume | push | breath | Also | Anchors |
|---|---|---|---|---|---|---|---|---|---|
| sad | 0.85 | 1.4 | -1.5 | 0.6 | -4 | | 0.4 | falls, slurred a little | rate -18% (Pell); low, flat, slow, long pauses (J&L) |
| grieving | 0.7 | 1.6 | -2.5 | 0.5 | -6 | | 0.6 | - | quiet sorrow: rate -40%, F0 -20% (Burkhardt) |
| tearful | 0.85 | 1.3 | +3 | 0.8 | -2 | | 0.6 | tremor 0.6 | crying despair (Burkhardt) |
| disappointed | 0.9 | 1.2 | -1 | 0.8 | -2 | | 0.3 | falls, drawn key word | - |
| resigned | 0.88 | 1.3 | -2 | 0.6 | -3 | | 0.4 | sighed falls | - |
| weary | 0.85 | 1.3 | -2 | 0.6 | -3 | -0.3 | 0.4 | creaky ends, slurred | - |
| bored | 0.85 | 1.2 | -3 | 0.5 | -2 | | 0.2 | stresses held 1.4x, creaky | Burkhardt's boredom |
| ashamed | 0.9 | 1.2 | -1 | 1.1 | -5 | | 0.4 | hesitant | shame: energy far down (Banse & Scherer) |
| hurt | 0.9 | 1.2 | +1 | 0.9 | -2 | | 0.4 | tremor 0.2 | - |
| wistful | 0.88 | 1.3 | -1 | 0.8 | -3 | | 0.4 | drawn, gentle falls | - |

**Calm, warm**

| Expression | rate | pauses | pitch | range | volume | push | breath | Also | Anchors |
|---|---|---|---|---|---|---|---|---|---|
| tender | 0.9 | 1.2 | -1 | 0.8 | -3 | -0.2 | 0.4 | even timing | low F0, slow, soft, regular (J&L) |
| calm | 0.92 | 1.15 | -1 | 0.75 | -1 | -0.2 | 0.2 | legato | - |
| content | 0.95 | 1.1 | -0.5 | 0.9 | -1 | -0.2 | 0.2 | - | lax voice (Gobl) |
| relieved | 0.92 | 1.2 | +1 | 1.2 | -1 | | 0.4 | a breath out before it | relief higher in pitch (Kamiloglu) |
| warm | 1 | | +1 | 1.2 | | | 0.1 | smiling | - |
| reassuring | 0.88 | 1.2 | -1.5 | 0.8 | -2 | | 0.3 | full falls, legato | low-arousal positive profiles |
| intimate | 0.9 | 1.1 | -1 | 0.8 | -6 | -0.3 | 0.6 | - | breathy = intimate (Gobl) |
| dreamy | 0.85 | 1.3 | +1 | 1.2 | -2 | | 0.5 | drawn vowels | - |

**Stance**

| Expression | rate | pauses | pitch | range | volume | push | breath | Also | Anchors |
|---|---|---|---|---|---|---|---|---|---|
| serious | 0.95 | 1.15 | -1 | 0.7 | | 0.1 | | falls | today's `serious` |
| deadpan | 0.95 | 1 | -1 | 0.3 | | | | accents x0.4 | - |
| grave | 0.85 | 1.3 | -2 | 0.6 | -1 | 0.1 | | legato | - |
| dry | 1 | | -0.5 | 0.7 | | | | - | today's `dry` |
| confident | 1.05 | 0.9 | -1 | 1.1 | +2 | 0.3 | | full falls | lower, louder, faster (Jiang & Pell 2017) |
| commanding | 0.95 | 1 | -2 | 1 | +4 | 0.5 | | falls, spaced on the order | - |
| doubtful | 0.92 | 1.2 | +1.5 | 1.1 | -1 | | 0.2 | scoops, hesitant | higher, slower (Jiang & Pell 2017) |
| confused | 0.92 | 1.2 | +1.5 | 1.3 | | | | rises, scoops | Cowen 2019 prosody |
| sarcastic | 0.75 | 1.1 | -1 | 0.75 | +1 | | 0.2 | drawn key word, rise-fall on it | key phrase 2.8 vs 3.9 syll/s, lower F0, rougher (Cheang & Pell 2008) |
| mocking | 1 | | +2 | 1.8 | | | | sing-song, drawn | - |
| suspicious | 0.9 | 1.2 | -1 | 1.1 | -1 | | | scoops, drawn | - |
| conspiratorial | 1.05 | 0.9 | -1 | 0.8 | -8 | | 0.6 | whisper 0.3 | - |
| polite | 0.95 | 1.05 | +0.5 | 0.9 | -1 | | | crisp | - |
| casual | 1.1 | 0.9 | -0.5 | 0.8 | -1 | -0.2 | | thrown away endings | - |
| defiant | 1 | | | 1.2 | +3 | 0.5 | | spaced, falls | - |
| impressed | 0.9 | 1.1 | +1 | 1.6 | +1 | | | rise-fall | Halliday tone 5 |
| mysterious | 0.85 | 1.3 | -1 | 1.1 | -3 | | 0.4 | drawn, held ends | - |
| apologetic | 0.92 | 1.1 | +1 | 0.9 | -2 | | 0.3 | soft falls | - |

**Effort** (ISO 9921's ladder). Loudness is carried by quality more than by level: the mix level is capped, and the rest
follows the measured rule of about +0.5 st of pitch per dB of effort, a flatter tilt, and longer vowels.

| Expression | rate | pauses | pitch | range | volume | push | breath | Also | Anchors |
|---|---|---|---|---|---|---|---|---|---|
| whispering | 0.9 | | | 0.7 | -10 | | | whisper 1 | Polly: slow whispers up to 10% |
| hushed | 0.92 | 1.1 | -1 | 0.7 | -8 | | 0.6 | whisper 0.4 | today's `hushed` |
| soft | 0.95 | | -0.5 | 0.9 | -4 | -0.3 | 0.3 | effort -0.4 | relaxed, 54 dB(A) |
| raised | | | +3 | | +3 | 0.3 | | effort +0.3 | 66 dB(A) |
| loud | 0.97 | | +5 | 0.9 | +5 | 0.6 | | effort +0.6, vowels x1.1 | 72-78 dB(A) |
| calling | 0.9 | | +6 | | +6 | 0.6 | | chant or drawn on the last word | - |
| shouting | 0.95 | | +8 | 0.8 | +7 | 1 | | effort 1, vowels x1.2 | +16 dB with +8.2 st (Garnier 2022); 84 dB(A) |
| screaming | | | +12 | 0.7 | +8 | 1 | 0.3 | vowels x1.3 | max shout 90 dB(A) |

**Performance styles.** A style is a person's way of telling, and may carry its own shape.

| Expression | rate | pauses | pitch | range | volume | push | breath | Also |
|---|---|---|---|---|---|---|---|---|
| storyteller | 0.95 | 1.3 | | 1.5 | | | | held ends before a reveal, swelling |
| bedtime | 0.85 | 1.3 | -1 | 1.1 | -4 | -0.3 | 0.4 | legato |
| sports commentator | 1.25 | 0.6 | +3 | 1.4 | +4 | 0.4 | | building on a play, hit hard on its end |
| game show host | 1.1 | 0.8 | +3 | 1.7 | +4 | 0.3 | | rise-fall, drawn names |
| ring announcer | 0.8 | 1.2 | +4 | 2 | +6 | 0.6 | | drawn vowels, chant |
| newsreader | 1 | 1 | | 0.9 | | 0.1 | | crisp, steady falls |
| narrator | | | | | | | | the voice's own |
| auctioneer | 1.8 | 0.3 | +2 | 0.4 | +3 | 0.3 | | even rhythm |
| orator | 0.9 | 1.4 | | 1.4 | +4 | 0.4 | | building, spaced on the key words |
| drill sergeant | 1.1 | 0.8 | -1 | 1.1 | +7 | 0.8 | | clipped, falls |
| radio host | 1.12 | 0.8 | +2 | 1.4 | +2 | 0.2 | | bright, hit on names |
| campfire | 0.85 | 1.5 | -2 | 1.2 | -5 | | 0.4 | sudden loud at the turn |
| game master | 0.95 | 1.3 | | 1.6 | +1 | | | held ends, contrast |
| mechanical | 1 | 0.8 | | 0 | | | | every syllable the same length |

**Physical states**

| Expression | rate | pauses | pitch | range | volume | push | breath | Also |
|---|---|---|---|---|---|---|---|---|
| out of breath | 1.1 | | +1 | | | | 0.7 | `{breath}` at odd boundaries |
| laughing | 1.05 | | +2 | 1.4 | +1 | | 0.4 | energy pulsing at 4-6 Hz, breath bursts |
| crying | 0.85 | 1.3 | +3 | 0.8 | -2 | | 0.6 | tremor 0.6, voice breaks |
| trembling | | | | | | | 0.2 | tremor 0.5 |
| sleepy | 0.8 | 1.3 | -2 | 0.6 | -3 | -0.4 | 0.4 | drawn, creaky |
| straining | 0.9 | | +2 | | +2 | 0.8 | | uneven timing |
| shivering | | | | | | | 0.2 | tremor on energy |
| muffled | | | | | | | | `_muffle` 0.7 |

### Points: sounds between words

| Point | Made by | Feasibility |
|---|---|---|
| `{breath}` | a synthesized inhalation (filtered noise, an envelope) placed as a rest | good: the sound designer's synth patches already make such sounds (next/sound_effects.md) |
| `{sigh}` | an exhalation with a voiced onset falling | good, the same way |
| `{gasp}` | a short ingressive noise | good |
| `{um}`, `{uh}` | the word said low and level, drawn (0.49 s on average), then a delay (longer after um) | good: words Kokoro says, with acts this plan builds (Clark & Fox Tree 2002) |
| `{hum}` | today's `Hmm.` hold | built |
| `{tsk}`, `{sniff}` | short synthesized clicks and noise | fair |
| `{laugh}`, `{chuckle}` | - | poor: Kokoro does not laugh; a speech-laugh (`laughing` above) is the reachable part |

### Coverage and growth

The bank is about 80 expressions, 14 axes, 18 acts, 5 shapes and 15 ramps. Checked against the research sets: all 12
prosody dimensions Cowen found preserved across cultures (adoration, amusement, anger, awe, confusion, contempt,
desire, disappointment, distress, fear, interest, sadness), all 12 of GEMEP's core, Ekman's 6, and Azure's neural styles
apart from service registers. A row is added like any registry row; the probe below says whether it does what it says.

## How it is made

**In Godot** (`ReadingPlan`, `Delivery`): the three forms are parsed with the other marks; each token gets its resolved
axis values (`x`: rate, pauses, pitch, range, volume, effort, push, breath, whisper, tremor, energy, precision) and its
act with a degree (`act`), every shape, ease, nesting and clamp already applied. The bank lives here, as rows.
Continuity across sentences is free: values come from each token's place in its stretch, so the last word of one call
and the first of the next agree.

**In the host**, each value goes to its control:

| Value | Control |
|---|---|
| rate, precision, an act's timing | `dur_scale` per id, remainders carried over the 25 ms frames; `VOWEL_LEAST` keeps a fast vowel |
| pauses | each boundary's rest top-up and Godot's splices, scaled |
| pitch, tremor, an act's contour | `f0_keep` keyframes per token (inflection's machinery, with the ToBI set as rule rows) |
| range | `f0_keep` from the planned curve: the curves cut of the graph first, then mean + (planned - mean) x range. inflection's `flatten` is a special case of it |
| volume | a per-token gain with ramps, under the limiter |
| energy | `n_keep` |
| effort | `_effort` made a curve: the shelved and the plain audio crossfaded by the effort at each sample |
| push, breath, creak, smile | style rows per token, lanes added to the voice's own blend |
| whisper | `_whisper`'s mix made a curve |
| `drawn` | `dur_scale` on the rime's continuants, `n_set` held at the vowel's peak (singing's sustain), pitch level; overlap-add (the hum's hold) where the model's held vowel thins |
| `cut off`, `clipped` | the take cut at the phone's end with a short close; no trail |

Cost: the moving and sung graph is about 1.5x the stock graph; the curves pass has no decoder. A sentence with no
delivery feeds nothing new and renders as now.

**What may not work, and the way round it:**

- Kokoro's held vowels lose energy past a few hundred ms (singing found it): `n_set` sustain, else overlap-add.
- `n_keep` may change the voice's quality more than its loudness: measured first; volume never depends on it.
- A style lane changes durations as well as timbre (the prosody half feeds the duration predictor): the probe measures
  rate under each lane, and rate is corrected for it.
- Large pitch moves inside the model (a shout's +8 st, a scream's +12) are within what the sung graph sings, but speech
  may crack or creak there: measured.

## Measuring it

- **A probe** (`hosts/voice/delivery_probe.py`): one passage rendered neutral and under each axis, act and expression.
  Measured: rate in syllables per second, F0 mean and range in semitones, level and tilt, alpha ratio, CPP, pause
  lengths. It prints a row per term against the row's intended directions and sizes, and writes the takes for listening.
- **A gate** (`tests/voice/delivery_check.gd`): the grammar parses every bank row and every form; resolution per token
  holds scope, nesting, shapes, easing, degree and clamps; an unknown word is reported. Controls: a script with no
  delivery resolves to nothing; a word outside every row fails.
- **A host gate** (`hosts/voice/test_delivery.py`): each axis moves its acoustic measure the right way on Kokoro (the
  neutral render the control), and a token with no `x` feeds nothing.
- **The author's ear** on the listening set, a family at a time: the numbers above are a start, not a verdict.

## Agents

- The reader's rule (rules/table/reader.yaml, "HOW YOU SAY IT") and the game master's describe the three forms and the
  kinds of term in plain words; the bank's names, grouped by family, are filled in by the code from the rows, never
  typed into a rule, so a row added is a word every agent may use. No sample sentence goes in a rule.
- What the research says about directions: one that fights the words lands weakly, so the words carry the feeling
  and the delivery shapes it; a change goes where a reader would really change; a word's act is for one word, a
  delivery for a stretch.
- Generate reports words outside the bank (the same lint as the editor) and the reader may be asked again.

## Migration

- Every word `delivery:` takes today becomes a bank row of the same name: quicker/faster, slower, brighter, graver,
  tighter, looser, louder, softer, excited, urgent, playful, serious, hushed, tender, dry, steady. Their sizes are an
  open question below.
- `<!-- inflect: none -->words<!-- /inflect -->` becomes `[words]{none}`, and `rise` likewise (one note uses it today);
  the old mark goes.
- `*italic*` and `**bold**` stay, as `hit` and `hit hard`.
- `<!-- hesitation -->` stays the silence. A drawn word or `{um}` is the hesitation that is heard.
- The delivery lean's per-sentence `Vector4` and `ease_leans` give way to per-token values; `noise_scale` leaves
  `brighter`.

## Build order

1. **The engine on today's words.** Per-token values from the existing delivery words, eased per word, made through
   `dur_scale`, `f0_keep`, per-token gain and effort, and the lanes. The probe measuring each axis on Kokoro.
2. **The grammar.** The three forms, degree, shapes, ramps, numbers, nesting; ScriptMarks rows; highlighter; captions
   stripped; the lint; `inflect` migrated.
3. **Acts.** The ToBI and GAT set as inflection rule rows; `drawn` (the model's hold against overlap-add, measured);
   `cut off`, `clipped`, `thrown away`, `spaced`, `chant`.
4. **The bank.** The expression rows with their anchors; the probe's table; the listening set; tuning by ear.
5. **Agents.** The rules, the list filled from the rows, the lint at Generate.
6. **Points.** `{breath}`, `{sigh}`, `{gasp}` synthesized; `{um}` and `{uh}`.
7. **The editor.** The palette by family; words selected and a term chosen; a stretch heard alone (Test).

## Open questions for the author

1. **The mark's name.** `delivery` for stretches keeps what agents already write thousands of times; a new name (`how`,
   `tone`, `voice`) would read better on a word but `tone` and `voice` already name other things.
2. **The word form.** `[words]{terms}`, and the Jefferson colons (`a::nd`) as a shorthand for drawing a sound out?
3. **Points.** `{sigh}` for sounds between words, and whether the hesitation folds into it (`{pause}`, `{pause 2s}`).
4. **Degree 1.** About half the acted corpora's size (a good reader), with `extremely` the acted size - or larger?
5. **Today's delivery words.** Keep their small steps (a pace step is 4%, a pitch step 0.33 st) so episodes already
   written sound the same, or take the bank's sizes?
6. **Breadth.** Any family to drop (performance styles, physical states) or add (ages, characters - though a character
   is a voice, not a delivery)?
7. **Kept deliveries.** A note's own named deliveries in the Library beside voices, offered to every note?
8. **Laughter.** Worth chasing past the speech-laugh?

## Sources

- W3C SSML 1.1: https://www.w3.org/TR/speech-synthesis11/ ; EmotionML 1.0: https://www.w3.org/TR/emotionml/ and its
  vocabularies https://www.w3.org/TR/emotion-voc/
- Azure SSML: https://learn.microsoft.com/en-us/azure/ai-services/speech-service/speech-synthesis-markup-voice ;
  Polly: https://docs.aws.amazon.com/polly/latest/dg/supportedtags.html ; Google: https://docs.cloud.google.com/text-to-speech/docs/ssml
  and https://docs.cloud.google.com/text-to-speech/docs/gemini-tts ; IBM: https://cloud.ibm.com/docs/text-to-speech?topic=text-to-speech-elements
- ElevenLabs v3: https://elevenlabs.io/docs/best-practices/prompting/eleven-v3 ; Fish Audio: https://docs.fish.audio/developer-guide/core-features/emotions ;
  Parler-TTS / Data-Speech: https://github.com/huggingface/dataspeech ; CosyVoice 2: https://arxiv.org/abs/2412.10117 ;
  Zonos: https://github.com/Zyphra/Zonos ; StyleTTS 2: https://github.com/yl4579/StyleTTS2 ; Kokoro: https://github.com/hexgrad/kokoro
- Apple embedded speech commands: https://developer.apple.com/library/archive/documentation/UserExperience/Conceptual/SpeechSynthesisProgrammingGuide/FineTuning/FineTuning.html ;
  SABLE: https://www.cstr.ed.ac.uk/research/projects/sable/sable_spec2.html ; JSML: https://www.w3.org/TR/2000/NOTE-jsml-20000605/
- Jefferson notation: Clift et al., Cambridge Handbook of Methods in Conversation Analysis (2024), https://eprints.whiterose.ac.uk/id/eprint/237652/ ;
  GAT 2 in English: https://www.uni-potsdam.de/fileadmin/projects/ilup/ILUP_SoSe16/GAT_2__English_.pdf ;
  ToBI: https://www.ling.ohio-state.edu/research/phonetics/E_ToBI/ ; Hirschberg on prosody and pragmatics:
  https://www.cs.columbia.edu/~julia/papers/Chapter_28.pdf
- Juslin & Laukka (2003), Psychological Bulletin 129:770 (cue counts as reproduced in Laukka's thesis,
  https://uu.diva-portal.org/smash/get/diva2:165425/FULLTEXT01.pdf) ; Banse & Scherer (1996), JPSP 70:614 ;
  Scherer (2003), Speech Communication 40:227 ; Pell et al. (2009), J. Phonetics 37:417 ; Burkhardt & Sendlmeier (2000),
  https://www.cs.columbia.edu/~julia/papers/burkhardt00.pdf ; Kamiloglu, Fischer & Sauter (2020), Psychonomic Bulletin & Review 27:237 ;
  Cowen et al. (2019), American Psychologist 74:698 and Nature Human Behaviour 3:369 ; Gobl & Ni Chasaide (2003),
  Speech Communication 40:189 ; Garnier, Smith & Wolfe (2022), JASA 152:3695 ; ISO 9921-1 ; Cheang & Pell (2008),
  Speech Communication 50:366 ; Jiang & Pell (2017), Speech Communication 88:106 ; Campione & Veronis (2002) on pauses ;
  Clark & Fox Tree (2002), Cognition 84:73 ; Friberg & Sundberg (1999), JASA 105:1469 ; Laukka, Juslin & Bresin (2005)
  on dimensions ; HUMAINE EARL, Plutchik, Geneva Emotion Wheel, OCC for the category sets.
