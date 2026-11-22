# Sound effects

A sound a note needs, made from its description: a `<!-- sound: words -->` mark's words go to a sound designer agent, who
writes a PATCH - a small program of the music host's own building blocks - and the host renders it. Every sound stays
synthesized from first principles, as the songs, the desk and the table are; no audio model, hosted or local.

## Status

Built (the user's choices: agents write a synth patch, never a text-to-audio model; each sound an entry on the Sound card and
kept in the Library):

- **The renderer** (`hosts/music/sound.py`, `test_sound.py` on the music venv): a patch made into a 22050 Hz stereo WAV and its
  HEARD NUMBERS (loudness, brightness and pitch every 0.1 s, onsets, the fade). A pure function of the patch and seed.
- **The store** (`SoundEffects`, `src/music/`): a sound kept by its words' key in `user://sound_effects/<key>/` - its versions
  (`sound.json`, kept, never deleted; `used` plays), each version's `v<N>.wav` and heard numbers, and the designer's conversation.
  The same words are the same sound on every note. The patch's language is rows (`SOURCES`, `FIELDS`), held to sound.py's.
- **The designer** (`SoundDesign`, `SoundTools`, rules/sound/designer.yaml): a `WriterChat` (its `rules` and `toolset`) whose
  text is the patch as JSON, with read, edit, write and RENDER (the patch heard as numbers, `SoundEffects.heard_text`). Generate
  is the conversation's first turn; Refine… (`TextRefine`) every turn after. A turn that leaves a new valid patch is a new
  version, made into sound at once.
- **The Sound card** (`SoundEffectsPart`): Source "None - sound effects only"; the component takes no slot, and beside what else
  times a note (a Voice) the card plays no song (`SoundCard.clock_elsewhere`), so a reading note can have it. A NOTE WHOSE WORDS
  CARRY A SOUND MARK HAS IT (the row's `brought_by`, `Components.brought_by`): its card shows with no ×, Source None, and writes no
  block until a setting changes. An entry a sound
  mark: Test, versions, Refine…, Make again, Keep, From the Dex…; a Pipeline row each, Generate making those not made. The
  designer is picked on the card (block `designer`).
- **The Library and the Dex** (`SoundLibrary`, shelf `sounds`; `SoundShelf`, also in the Dex opened on its own).
- **The desk** plays a made sound for its mark (`DispatchScript.parse`'s `sounds`, `SoundEffects.made_in`; a plan's `clip`,
  `DispatchSounds.clips`, its peak at what the voice waits for), the voice waiting its `secs`; a mark not made yet plays the jet
  if its words name it.

Open for the user: the first sounds made and judged by ear (Targeting Individuals' cans and jet: attach Sound, Generate);
whether a sound's Refine… should also hear the draft played as the designer works.

## A patch

JSON, `{secs, tail, layers}`: `secs` what the voice waits, `tail` how long it is heard after. Each layer is a source, shaped
and placed:

- **sources** - noise (white, pink, brown), an oscillator (sine, saw, pulse, triangle) on a pitch curve, modal resonances
  (`dsp.modal`: a struck thing), a plucked string (`dsp.karplus`);
- **shaping** - envelopes as breakpoint curves over the sound's time (level, a filter's cutoff, pitch), filters (low-pass with
  a moving cutoff, band, high), drive;
- **placing** - a MOVING SOURCE (a path past the listener, its speed and nearest distance: Doppler, loudness and the far air's
  darkening follow, as the jet's do), pan, the room (`dsp.reverb_ir`).

Every field is a registry row (`label`, `blurb`, bounds), so `docs.py` lists them, a gate checks them and the designer is told
them from the rows. The host renders a patch to a WAV named by its hash and seed (`hosts/music/sound.py` on `dsp.py`), kept as
the song's stems are; a pure function of the two.

## Made from its words

- A `sound:` mark's words are its description; a sound is keyed by them as a picture is by its prompt.
- Each sound not yet made is a Pipeline row; Generate asks the sound designer (an `AgentPick` row, `rules/sound/`).
- The designer works through tools, as the painter and the rigger do: write the patch, RENDER it and HEAR it as numbers
  (`listen.py`'s pieces: loudness over time, brightness and pitch over time, onsets), change it, and say it is done. A patch
  is checked against its words, never guessed once.

## On the Sound card

- Each sound an `EntryCard`: its words, the rendered sound's outline, Test (`SoundTest`), Refine…, Keep, and its ×.
- **Refine…** is a chat with the designer kept in the note's folder (`WriterChat`, the CLI's session resumed), told the
  words, the patch and what it measured, changing the patch through its tools. Each refinement is a version
  (`LibraryVersions`); the one used is chosen.
- **The Library**: `SoundLibrary`, shelf `sounds` (`{name, patch, versions}`), browsed in the Dex beside props and voices;
  "+ Add" on the card. A sound used from the Library is copied into the note.

## Where it plays

- The Dispatch desk plays a `sound:` mark's made sound through `DispatchSounds`, from its WAV, the voice waiting its `secs`.
- Other formats take the mark once one has a place for it (`ScriptMarks` row `desk_sound` is Dispatch's today).

## Next

- The jet written as a patch and judged by ear against the hand-written one (`DispatchSounds._jet`); the hand-written one goes if
  the patch is as good.
- Other formats taking the `sound:` mark.
