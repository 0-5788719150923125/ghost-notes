# Music: a note that makes its own sound

## Status

**Not built, not decided.** This note looks at what music made in Ghost Notes could be: what the code already has, what
the research says, a design, and the order to build it in. No code exists for it yet.

**Looked at:** the Song component and its card (`src/notes/components.gd`, `src/show/song_card.gd`,
`src/app/note_panel.gd`); the Voice card's Ambience (the pad in `VoiceFX`, its row in `ReadingCast`); every synthesized
sound (`Soundscape`, `WorkSounds`, `DispatchSounds`, `VoiceFX`); the contract for a sound laid under a voice (`SoundBed`);
the formant voice's song mode (`Voice.Spec.song`); Kokoro taken apart for training (`hosts/voice_train/kokoro_model.py`);
the one Timeline (`Timeline`); how the show's seed comes from a song (`Director._resolve_seed`); harmonic_seeding.md. A
search found no prior work on making Kokoro sing by forcing its pitch and durations, so that part is untested.

**First experiment, heard:** a scratch script (not in the repo) sang Twinkle, Twinkle on `af_heart`, with each phoneme's
duration and the pitch curve taken from the score and decoded through `kokoro_model.py`. The pitch and timing controls
work. Held vowels buzz. A line's first word is lost when its opening pad gets fewer frames than Kokoro plans for it (the
trap `hosts/voice/backends/kokoro.py`'s header describes); the script gave it 3.

**For the user to judge:**

1. Whether to build it at all, and whether ambient comes first.
2. The name: **Sound** (proposed below) or Audio.
3. The first experiment, by ear: one Kokoro voice holding a sung vowel at a few pitches and lengths (step 5). It shows
   whether singing is close or far off.
4. The bet underneath all of it: that a song made by choosing among seeded parts feels like the author's own.

## The idea

A composed song is a few lines in a note's frontmatter: a tempo, a key, a form, and a handful of parts (pad, bass, drums,
lead, texture, voice). Each part is a pattern picked from a bank, an instrument picked from a bank, and a seed. Every
sound is synthesized from noise and oscillators, as the Soundscape's are. No samples. The same lines play the same song
on any machine. Making music means choosing: roll a part until it moves you, keep it, lock it, then roll the next.

THE SEEDED SONG IS A SCORE NOBODY WROTE DOWN, just as the seeded show is a storyboard nobody wrote down (storyboard.md).
It plays as soon as it is attached, every choice drawn from the seed, and the author overrides choice by choice. Later,
writing a part down note for note is how fine control arrives, without changing what the song is.

```yaml
ghost:
  sound:
    source: composed
    mood: drift            # a Moods row: tempo range, mode, which parts, which instruments, the form
    key: D
    tempo: 68
    form: arc              # a Forms row: the sections, and which parts play in each
    parts:
      harmony: {pattern: markov-slow, seed: 40}         # the spine every pitched part reads
      pad:     {pattern: held-chords, instrument: glass-pad, seed: 311}
      bass:    {pattern: drone, instrument: sub, seed: 88}
      lead:    {pattern: sparse-motif, instrument: bell, seed: 912, lock: 0.8}
      texture: {pattern: rain, tuned: true, seed: 7}
      voice:   {pattern: psalm-tone, singers: [Max, Emma], words: body, seed: 5}
```

## Why this, and for whom

Two barriers stand between most people and music they made themselves:

- **The DAW.** A blank timeline, a wall of plugins, theory you are assumed to know, and a sample library to manage.
  Most people who open one never finish a song.
- **AI platforms.** Suno and Udio make a song from a prompt, but the choices are the model's. Both now have licensing
  deals with major labels, and Udio's licensed platform keeps what it makes inside the platform. The US Copyright
  Office's 2025 report on copyrightability holds that prompts alone do not give enough human control for the output to
  be the author's; a person's selection and arrangement can be.

Some tools already sit between the two, and they show the middle ground works:

- **Drum machines and grooveboxes**: pattern banks and a randomize button. Hip hop, house and techno grew up on
  machines whose every sound was synthesized (the 808, the 909).
- **Logic's Drummer**: pick a player, then move one point on a pad from simple to complex and soft to loud. You choose
  the feel, never the notes.
- **Mutable Instruments Grids**: a map of drum patterns taken from real drumming. X and Y move across the map, and one
  density knob per drum adds or removes hits.
- **Music Thing's Turing Machine and Mutable's Marbles**: a random sequence that loops, with one knob that sets how
  likely each step is to change. At one end it is locked, in the middle it drifts. This is the key lesson: **the most
  musical randomness is randomness that repeats.**
- **Brian Eno's generative works**: Music for Airports' tape loops of different lengths rarely line up the same way
  twice; Bloom; Koan. The Soundscape already does this with its breaths of 7.3, 17.9 and 41 s.
- **FL Studio**: the step sequencer and the playlist. Ours is the same shape with the drawing taken out: a part is
  chosen, not drawn.
- **Euclidean rhythms** (Toussaint 2005): spreading k hits as evenly as possible over n steps produces most of the
  world's traditional timelines. E(3,8) is the tresillo, E(5,8) the cinquillo, E(7,12) a West African bell pattern and
  E(5,16) the bossa nova.

What Ghost Notes adds that neither side has:

- **A song is text.** About a kilobyte in a note, diffable, shareable, versioned with the note, and deterministic. A
  tracker module is smaller than a recording; this is smaller than a tracker module.
- **Ownership that holds up.** No samples, and no model trained on anyone's music. Every sound is math, and every
  choice is the author's. It is a drum machine's kind of authorship, not a prompt's.
- **Words.** Ghost Notes is about notes with words in them. A composed song can sing the note (see "Singing").
- **The show knows the score.** The scenes stop guessing at beats (see "What the show gets").
- **A way out to a real DAW.** A score is MIDI-shaped, so exporting a `.mid` file and per-part stems costs little. A
  person who outgrows the card takes their song with them.
- **No wrong notes.** Every part is in key and on chord. The Ambience pad already works this way: a pentatonic in which
  no two degrees are a semitone apart, "so any combination is consonant".

## The rename: Song becomes Sound

The component only attaches a file, and the file can be anything, so "Song" promises too much. **Sound** fits: it is
already the family's label (hue 212), and it reads well in a sentence ("this note's clock is its Sound").

- Key `sound`, block `sound:`, card "Sound". The card's first row is a **Source**: *A file* (what Song does today) or
  *Composed* (the parts). This mirrors the Medium card's Format with its own rows: a way of making the sound is a source
  on one card, never a second component.
- Old notes keep working: `song: {path}` is read as `sound: {source: file, path}`, the way `Components.adopted_medium`
  reads the old `picture:`, `letter:` and `dispatch:` blocks.
- No seed salt names a song (checked), so the rename re-rolls nothing. The `clock` slot's blurb, the Timeline's `song`
  clock label, and the internal names in Spectrum and main follow when those files are next touched.
- "Audio" also works, but it is already a typed need (`provides: ["audio"]`), and two meanings of one word in the
  registry would confuse things.

## The bank: music theory as rows

The person never needs to learn these terms. They are what the patterns are made of, and each is a registry row with a
label, a blurb and its fields (every registry is rows; docs.py makes a page of them). The banks:

- **Moods**: where a composed Sound starts. Each mood is a palette of other rows (a tempo range, a mode, the parts and
  their instrument families, a form): Drift, Hymn, Night drive, Pulse, Rain room. The seed picks a mood until the author
  does. A mood is not a note template: the note still starts empty, and a mood is one choice on one card.
- **Scales and modes**: major (Ionian), natural minor (Aeolian), Dorian, Mixolydian, Lydian, Phrygian, both
  pentatonics, harmonic minor, whole tone. Each blurb says how it feels: Lydian floats, Dorian is wistful, Phrygian is
  dark. Ambient leans on Lydian, Dorian and the pentatonics.
- **Progressions**: the four-chord song (I-V-vi-IV) and its rotation (vi-IV-I-V), the fifties (I-vi-IV-V), ii-V-I,
  i-VI-III-VII, the Andalusian cadence (i-VII-VI-V), the twelve-bar blues, Pachelbel's, the one-chord vamp, the pedal.
  Also a generated one: a Markov chain over chord functions (tonic, predominant, dominant, back to tonic), for harmony
  that wanders without repeating, which is right for ambient.
- **Voicing**: close, open and spread chords, with voice leading. Each chord tone moves to the nearest tone of the
  next chord, so pads glide through changes instead of jumping. More than anything else, this separates a good pad
  from a cheap one.
- **Rhythms**: four-on-the-floor, rock backbeat, half-time, boom bap, breakbeat, trap with hat rolls, bossa nova, son
  and rumba clave, tresillo, shuffle, reggae one-drop, dembow, motorik, 6/8 bell. Plus the Euclidean generator, whose
  seed picks k, n and a rotation for each drum within a family's rules (kick on one, snare on the backbeat for rock).
- **Groove**: swing (from straight eighths at 50% to a triplet feel at 66%), humanize (a little scatter in timing and
  loudness), accents by where a beat falls in the bar, and **ghost notes**: the soft snare strokes between the main
  hits that the app is named for. A drums part gets a Ghost notes dial.
- **Bass patterns**: root on one, root-fifth, octave pulse, walking (chord tones plus approach notes), following the
  kick, arpeggiated, drone.
- **Arpeggios**: up, down, up-down, random within the chord, Alberti; at eighths, sixteenths or triplets; over one or
  two octaves.
- **Melody**: a motif of one or two bars (a rhythm and a contour), developed the way composers develop one: repeated,
  sequenced (moved up or down), inverted, run backward, stretched. Phrases come in question-and-answer pairs (the same
  opening, a different ending). Chord tones fall on strong beats and passing tones between them, within a range, with a
  contour (arch, rise, fall, wave), ending on the tonic.
- **Forms**: verse-chorus, AABA, build-and-drop, the ambient arc (layers enter one by one, peak and dissolve), and the
  drone (one long section). Electronic music arranges by subtraction: write one loop with every part, then mute parts
  to make the sections. That suits seeds exactly: compose the loop once, and the form decides who plays when. A drum
  fill in the bar before a section change is a row too.
- **Chants**: see "Singing".

**Ambient first** (the likely first genre) needs: drones and pedal tones; slow harmony (a chord every two to eight bars,
or the Markov wander); loops of incommensurate lengths, Eno's way, so every note keeps its own period; pads with long
attacks and releases (today's pad swells over 3.5 s and lets go over 7); sparse bells and plucks with long tails; and
the place itself as an instrument (next section).

## The instruments: all synthesized

Instruments are rows too: a synthesis method and its ranges. The seed varies a row within its ranges, so two seeds of
"glass pad" are siblings, not strangers.

- **Drums**, the 808 and 909 recipes: a kick is a sine with a fast pitch drop and a click; a snare is two tones and a
  band of noise; a clap is three or four noise bursts a few milliseconds apart with a tail; a hat is six square waves at
  unrelated pitches through a high band-pass, or plain noise; toms are pitched drops; a rim or a clave is a short
  resonant ping.
- **Plucked strings**: Karplus-Strong (1983), a noise burst in a damped delay line. Guitar, harp, koto, pizzicato.
  Very cheap and surprisingly real.
- **Struck things**: modal synthesis, a bank of decaying resonators. Bells, marimba, vibraphone, glass, kalimba, gongs.
  It is the same method `WorkSounds` uses for a thing set down on the table (a material's modes for its size).
- **Keys**: FM (Chowning 1973; the DX7) for electric piano, bells and basses; additive drawbars for organ.
- **Pads and leads**: subtractive synthesis (detuned saws and pulses, a resonant low-pass, an envelope). Today's
  Ambience pad is one of these: two detuned oscillators per tone.
- **A wordless choir**: a buzz through vocal formants ("aah", "ooh"), the classic vox pad. The formant voice's
  resonators work as an instrument here.
- **The place, singing**: the Soundscape's layers (rain, wind, sea, stream, insects) offered as parts and **tuned to the
  chord**. Rain falls through resonators tuned to the chord's tones, the way `VoiceFX`'s resonance rings sympathetic
  strings. Wind through a comb filter at the root becomes an Aeolian harp. The work behind Ghost Notes' sound design
  becomes music directly.
- **Effects**: reverb (the Soundscape's feedback delay network already makes a space), a delay synced to the tempo,
  chorus, saturation, the sidechain duck that makes a pad pump, filter sweeps, and a limiter on the master.

Every sound family today writes its own filters inline. Music needs many voices built from the same few pieces, so a
small DSP kit goes in `audio/`: a biquad, a one-pole, envelopes, band-limited oscillators (PolyBLEP: a naive saw aliases
badly on high notes), noise colors, a delay line, the FDN, Karplus-Strong, a modal bank. The existing families can move
onto it over time, but they do not have to.

## Seeds, rolls and locks

- **One seed per note**, folded with each component's key (notes.md, "Seeds"). The song's seed is the note's folded
  with `sound`, and each part's draws are that folded with the part's key and its own seed. Rolling one part never
  changes another, so muting or re-rolling a part is a fair A/B.
- **The harmony is the spine.** Every pitched part reads one chord track, which is a part with its own seed. Rolling a
  melody leaves the harmony alone. Rolling the harmony re-harmonizes everything, but each part keeps its character: the
  bass still plays root pulses, on the new roots. Drums read no harmony.
- **A roll steps the seed, and every seed tried is kept.** ‹ and › walk back through them, as a kept step is never
  deleted (`KeptSteps`, editing.md). A good roll is never lost to the next one.
- **Lock**, the Turing Machine's knob: how much of a part's loop changes from one pass to the next. At 1 it repeats
  exactly; lower, a few steps mutate each time round. The Voice card's Lab already speaks this language (drift).
- **Roll all** rolls every part that is not kept.

## The card: not a DAW

On the Sound card (no workspace of its own; nothing on a card scrolls by itself):

- **Source**: File or Composed. Under Composed: Mood, Key, Tempo, Form.
- **One row per part**: its pattern (a list of rows), its instrument (a list of rows), its seed with roll and ‹ ›, Lock,
  mute and level. This is FL's channel rack reduced to choices.
- **Roll all**, and roll the harmony.
- **The form on the one Timeline** (`Timeline`; editing.md). Groups are the sections, lanes the parts, and a span is
  where a part plays. A flag is a one-shot (a fill, a drop). The clock is the Sound's and the engine is `time`, a pure
  function of show time. Each item's `source` is a path into the note's `sound:` block. Dragging a section's edge
  changes its length; clicking a cell mutes that part for that section. This is FL's playlist reduced to choices, in
  the `TimelineDock` every show already has.
- **The loop plays while you roll**: the selected section's four or eight bars render first and loop, so a roll is
  heard within a second or two. Play plays the whole song.
- **The Pipeline card** lists what is baked (each part's stem, the mix, every sung take), each with its ⟳ (one
  pipeline).
- **Not in v1**: a piano roll, a waveform, samples, per-note edits.

## Rendering

- The formant voice renders about 3x real time in GDScript on this machine, and a dense mix of many voices may not even
  keep up with real time. So a composed song is **baked, not streamed**: each part to a stem on a worker, cached by a
  hash of what made it (as a voice row's takes are kept), then mixed. Re-rolling one part re-renders one stem. The mix
  is cheap.
- The baked mix is a file in the note's folder, so **everything after it is the path a song already takes**: Spectrum,
  the transport, the scenes, the export. Nothing downstream changes.
- **Measure before choosing** (compute.md): eight bars of pad, bass and drums in GDScript on the thread's own clock. If
  it is too slow, the candidates are a C# kernel (csharp.md) or a Python host with numpy.
- **A trap**: the show's seed today comes from the song file's fingerprint (`Spectrum.song_hash`, `_resolve_seed`), so
  re-rolling the hi-hat would re-roll every scene. A composed Sound gives the show the note's seed instead, and the
  picture stays put while the music changes.

## What the show gets

A composed song knows its own beats, bars, sections and every note exactly, with nothing analyzed. So it offers the
note's **moments** (a downbeat, a section change, a drop, a hit on a named drum) and **feeds** (the chord, the energy of
the section) to whatever reads them. Scenes can cut on sections, and a storyboard's "leave on its beats" gets beats that
are never wrong. With one note seed behind both the song and the show, a single number makes the whole music video.

## A sound and a voice on one note

CLAUDE.md lists "a song and a voice on one note" as open: both take the `clock` slot. Music meets a voice in three ways,
and which one applies is **read off the parts, never picked**:

1. **Under a reading: a bed.** The reading conducts, by the fixed order (a voice, else a clip, else a song), and the
   composed Sound follows it. This is exactly `SoundBed`'s contract: the reading mixes a bed under the voice, live and in
   the export, and names no table. The Sound hands the reading a bed the way a table hands it the Soundscape. Its form
   is laid on the reading's own moments, not on bars: chord changes fall in the rests between sentences, a section turns
   at a paragraph, and the bed swells into the pauses and ducks under the words (the pad already ducks). Its key follows
   the reader's register, as the pad's does, so the music sits under the voice in a consonant key. These are the new
   kinds of background music the Ambience dial hinted at.
2. **Sung: the voice is in the music.** The Sound conducts, and the note's words are the lyrics. The Voice card stays
   the cast (who sings); a vocal part says what is sung and how. A note whose Sound sings its words reads no reading.
3. **Spoken over a beat** (later): the Sound conducts, and the reading is laid onto the bars, each sentence starting on
   a downbeat. Spoken word, or a podcast's open.

**The Ambience dial**: today's pad becomes the first bed of the music bank, moved out of `VoiceFX` into the kit. The
Voice card keeps its Ambience row for notes with no Sound card until the Sound card does everything it does, then the
row goes, so there is one implementation.

## Singing: chant and chorus

**What a chant is.** A text sung on a few notes, with the rhythm following the words. Gregorian plainchant is one line in
unison, in a mode, its rhythm the speech's. Its **psalm tones** are formulas that set any text: an opening figure, a
reciting note held for most of the syllables, a cadence at the half-line and another at the end, with the stressed
syllables deciding where the cadence notes fall. Byzantine chant adds the **ison**, a drone holding the base note under
the melody. A mantra is one phrase repeated over a drone. A crowd's chant is rhythmic speech in unison. Overtone chant
(Tuvan, Tibetan) is a low drone with whistled harmonics above it.

The psalm tone is the ideal first primitive for Ghost Notes: it sets **any** text, so the note's own words become a
chant. Rows: the eight psalm tones, one per mode, plus simpler formulas, with the seed choosing among their variants.
Put an ison under it and a room around it, and that is a chant. Setting text follows the textsetting rule (Halle and
Lerdahl 1993): stressed syllables land on strong beats and cadence notes. The phonemes a voice reads already carry
their stress.

### Kokoro sings: the main path

Kokoro is StyleTTS 2 inside, and **its decoder makes the waveform from a pitch curve.** `hosts/voice_train/kokoro_model.py`
already takes the model apart into `encode` (the text), `durations` (frames per phoneme), `prosody` (pitch and energy
curves along an alignment) and `decode` (the waveform from the text, its alignment, pitch and energy). So singing needs
no auto-tune after the fact:

- **Durations from the score**: each vowel stretched to its note, consonants kept at their spoken length, and the vowel
  landing on the beat (singers put the consonant before the beat). A duration frame is 25 ms, and a sub-frame trim of
  the samples puts each onset exactly on time.
- **Pitch from the score**: each note's pitch with a singer's ornaments. Saitou and colleagues' speech-to-singing recipe
  (2007) names them: a small dip before a change of note, an overshoot after it, vibrato ramping in on held notes, and a
  little slow drift. The pitch frames are 12.5 ms. The formant voice's song constants (5.5 Hz vibrato, 0.38 semitones
  deep, ramping in over 0.18 s) are a starting point.
- **Energy** held through a stretched vowel, so a long note does not sag.

The voice then sings in its own timbre, through its own vocoder. **Every Kokoro voice sings by the same path**: the
stock readers, every blend from the Lab (`VoiceBlend`), and every voice taught on the Voice training card, so someone's
own voice can sing. A chorus can be a family of blends, each a little different from the next. Piper voices (an actor's)
have no pitch input and need the fallback.

Risks: the decoder learned speech, so long held vowels and pitches far from a voice's speaking range may smear or buzz.
Each voice gets a comfortable range (the spread of its own planned pitch), and a melody moves by octaves to fit each
singer. "Auto-tune" in its hard-tuned sense (an instant snap between notes, the robotic sound) is a style the vocal part
can ask for: the glides taken out.

The first experiment needs no graph surgery: torch is already in `voice_train_venv`, and `kokoro_model.py` decodes there.
Sing a vowel and a psalm tone on one sentence, and listen. If it sings, it either becomes an ONNX graph that takes
durations and pitch as inputs (`kokoro_moving.py` shows this kind of surgery works here) or stays on torch as a feature
venv of its own. That choice waits for the ear.

**The fallback**, for any voice: speak the line, then move its pitch and stretch its vowels with the WORLD vocoder or
PSOLA. It is lower quality but works on anything, Piper included.

### The formant voice sings too

It already has a song mode: vowels stretched onto a beat grid, steps instead of glides, pitches pulled onto the scale,
vibrato. What it lacks is taking its notes from a score instead of from its genome, which is a small change. It is not
the voice for natural singing, but it is the right voice for:

- **A deliberately synthetic lead**: the vocoder sound, or "Daisy Bell" as the IBM 7094 sang it in 1961.
- **A wordless choir pad** as an instrument (above).
- **Overtone chant**: narrow resonances tuned onto the drone's harmonics, which a formant synthesizer can do and a
  neural voice cannot.
- **A crowd**: a thousand cheap voices chanting together.

### Chorus

Several singers on one line, each its own voice (a Kokoro reader, a blend, a formant voice), with what makes a choir
sound like a choir rather than one voice copied: each singer a little early or late (tens of milliseconds), a little
sharp or flat (choir studies such as Ternström's measure scatter of roughly ten to twenty cents), with their own vibrato
rate and phase and their own breath points, spread across the stereo field, all in one room (`RoomFX`). The order to
build it: unison first, which is the chant; then harmony, where the progression gives each singer a chord tone (the
ison, a fifth, an octave); then call and response, a cantor alone with the choir answering, which the psalm tone's
halves invite.

## Importing a song: patterns, not stems

The aim is to take what a song is made of as our own primitives: its tempo, key, chords, drum pattern, groove, and the
character of its sounds as synth settings. Never its audio. All of the following is classic signal processing, with no
neural networks:

- **Tempo and beats**: the autocorrelation of onset strength. Spectrum already tracks beats live.
- **Key**: chroma (HarmonicSignature already folds the bands into twelve pitch classes) matched against the
  Krumhansl-Schmuckler key profiles.
- **Chords**: chroma averaged per beat, matched against chord templates and smoothed with an HMM (Fujishima 1999; Sheh
  and Ellis 2003). Good on triads, weak on jazz.
- **Drums apart from the rest**: harmonic-percussive separation by median filtering (Fitzgerald 2010). Sustained
  sounds are horizontal lines in a spectrogram and hits are vertical lines, so a median along each axis pulls them
  apart.
- **The drums themselves**: this is where the PCA hunch is right, with one change. **NMF**, non-negative matrix
  factorization, splits the spectrogram V into W·H: each column of W is a spectral shape (the sound of the kick) and
  each row of H is when that shape plays. Because nothing can be negative, the parts add up the way sounds do, which
  PCA's signed components cannot (Lee and Seung 1999). Seeded with kick, snare and hat shapes and partly held fixed, NMF
  transcribes drums well (Dittmar and Gärtner 2014). Its convolutive form (Smaragdis 2004) learns a whole hit's shape
  over time. The peaks of H give the drum pattern, and their timing against the beat grid gives the **groove**: the
  swing and push of each step, the feel of the song as a template.
- **A sound as settings, never as a sample**: fit our synth's parameters to each extracted shape by optimization. The
  paint host already does this kind of fitting (an optimizer lays paint to match a picture); here the same idea fits a
  kick's pitch drop, decay and click to a kick's spectrum, or a pluck's damping and brightness to a guitar's harmonics.
  This is sound matching, by CMA-ES or by gradient through a differentiable synth (differentiable DSP with the
  synthesizer's own parameters as the variables, no network). The result is a row of numbers in the instrument bank.
- **Where it runs**: a Python host (`hosts/music/`, numpy and scipy, its venv stamped by its requirements as every
  feature's is), one offline pass per imported song. The output is a small JSON (tempo, key, progression, groove,
  patches) kept in the note's folder.

**How well each part works**, honestly: drums and groove, good. Tempo, key and chords, good on pop and ambient. The
bass line, fair (a pitch tracker on the lowest band). The lead melody, poor in a dense mix (salience-based extraction
such as MELODIA, Salamon and Gómez 2012, does better on vocals). A voice's timbre, no. If neural help ever becomes
necessary, Spotify's Basic Pitch is a small audio-to-MIDI model (Apache-2.0); Demucs-sized stem models are what this
avoids.

**What it takes**: grooves, the shapes of chord progressions, tempos and timbres are styles, and are generally not
protected. Melodies are what copyright protects most strongly. So an import takes the feel, the harmony's shape and the
sound patches, and leaves the melody behind.

## Where it lives in `src/`

- `audio/`: the DSP kit (bottom of the stack, readable by everything).
- A new folder `music/` (a `FOLDERS` row in docs.py), above `voice/` so a sung part can ask `VoiceHost` for a take: the
  banks (registries), the composer (a pure function from the `sound:` block and seeds to a score, like `TablePlan.make`),
  the renderer, the bed (a `SoundBed`), the MIDI writer.
- The Sound card in `show/`, where the Song card is now.
- The reading takes the bed through `SoundBed` and never names the music.

## The order to build it

0. **Measure.** The DSP kit, then eight bars of pad, bass and drums rendered in GDScript and timed on the work clock.
   Decide between GDScript and a kernel.
1. **The rename.** Song becomes Sound, with File as the only source and old blocks adopted. Nothing else changes.
2. **Ambient.** The Composed source: harmony spine, pad with voice leading, drone and bass, sparse bells and plucks,
   tuned textures from the Soundscape, the ambient arc; seeds, rolls, locks; baked to the note's folder and played
   through the song path; the show's seed kept off the file; beats and sections handed to the scenes as moments.
3. **Beats.** Synthesized drums, named and Euclidean rhythms, groove and ghost notes, arpeggios, motif leads, sections,
   fills, and the form on the Timeline.
4. **Under a reading.** The bed through `SoundBed`, its form laid on the reading's moments, a Voice and a Sound on one
   note. The Ambience pad moves into the bank.
5. **Singing.** The Kokoro experiment by ear (a held vowel, then a psalm tone on one sentence); then psalm tones on a
   note's words with an ison; the formant voice from a score; the chorus.
6. **Import.** `hosts/music/`: tempo, key, chords, drums and groove, patches by sound matching.

**Later**: MIDI and stem export; writing a part down (freezing it into notes) and editing those notes, on the same
Timeline as keyframed lanes; per-step edits; playing the parts live like a groovebox and recording the performance as the
arrangement; spoken word on the beat; a score cue for a table episode's bed; music on the phone (a composed Sound needs
audio, not the stage, so it may be the first component besides the text that a phone can run).

## Open questions

- Should a composed Sound under a reading take the `clock` slot at all, or should a bed be a role that needs no slot?
  (Recommended: a bed takes no slot; a Sound that sings, or that plays with no voice, conducts.)
- When the Voice card is only the cast for a sung Sound, does it still offer its reading rows, or only the voices?
- Moods as the entry point: does a mood read as a template the author did not ask for, or as Auto does for the Medium?
