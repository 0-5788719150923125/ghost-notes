# One desk: one pen, one hand, one desk for a lesson and a letter

## Status

**Built; a lesson made at the desk awaits the user's eye.** A pen writing by itself was drawn by two codes: the Letter's
desk ([DeskMedium], [LetterMedium]: a desk dressed from its seed, a legal pad turned over its binding, a pen that waits and
gets out of the way between writes, a camera close on the line being written) and the table ([TableWork]'s `write` and
`point`, [SheetWriting], a pen the set dresser built, a camera on a tripod). What both draw is one code in `table/` - the
pen ([Pen]), the ink ([Ink]) and the hand ([Handwriting]) - and the desk is the one desk: a table show's episode plays at
it ([EpisodeDesk]). `theorem-grooving.md`'s Medium says `format: desk`, so its next episode is made for the desk.

- **One pen** ([Pen]). The desk, the Letter and the table pose their pens through it: the nib on a hand's strokes (eased as
  `Ink.share` has it; the table's ink picture is put down on the same easing, so the nib is at the ink's front), between
  them, pointing and resting; the hand's lean; a lifted pen drifting as `Hands.drift` has any held thing; its frame.
- **One hand** ([Handwriting], moved down from `desk/`). The table's words in a hand (`neat`, `quick`, `print`: Kalam,
  Caveat, Patrick Hand, `CardTable.HANDS` `strokes`) are written in the hand's traced strokes, as a letter's are, and a pen
  seen follows them ([method SheetWriting.words]); a typewriter's are set from the font. One stroke picture for a formula
  and words ([method TableInk.picture_of_schedule]).
- **The desk plays a table episode** ([EpisodeDesk], Medium row `desk`, Table's). Each act's writes and points are the
  desk's actions on its one pad, whatever sheet and pen they name: a write begins at its act's word and keeps with the words
  to the next act's word, as the old desk's dictation did; a point is held while it is talked about; a strike crosses out
  the line its act names. Words with no math are written in their hand on the pad's rules; what TeX lays out is the
  episode's `ink.json`. The desk is the Letter's ([DeskLook]: mood, things, candles - the `medium:` block's `mood` and
  `things` where written, else the seed's), its camera the old desk's a little closer ([constant EpisodeDesk.EPISODE_LOCAL]).
  The lesson, the letter and the episode lay out their actions and begin the desk one way ([method DeskMedium._begin]).
- **The episode keeps its medium.** A table show's note has the Medium card (Table brings it; [method Medium.offered] gives a
  note that `provides` an episode Table's formats alone - the table, the desk); a pick is its block, never the remembered
  medium, and a block naming another format is kept as it was until one of Table's is picked. Generate hands the producer
  the block's format and the plan keeps it ([method TableProducer._land_medium], [method TableEpisode.medium]); the Episode
  card pins the episode's medium, so an episode made before plays as it was made. A desk episode's steps are the plan, the
  solve, its table ([DeskTable]: a pad of sheets and a pen, landed as a set dresser's table is), the acts, the ink and the
  readers - no set dresser, no cloth, room or depth painted.

Held by `tests/desk/episode_desk_check.gd` (the lesson from an episode's acts, played at the words; the episode's medium
and steps; the producer keeping it), `tests/media/medium_pick_check.gd` (a table show's Medium card),
`tests/notes/components_check.gd` (Table brings its Medium; the control an Actor), `page_writing_check` (the table's words
the hand's strokes), `letter_check`, `ink_check`. Looked at with `tests/desk/episode_desk_look_probe.gd` (its own lesson
of a page and more: the opening, formulas, words, a drawing, a point, a strike, a page turned).

**What the user still has to judge:** a Theorem Grooving episode made at the desk and watched - how close the camera is,
whether each write keeps with its words, the desk's mood and things.

**Open:** the desk's own rows on the Medium card (its mood and things, as the Letter's are); the producer choosing an
episode's medium among the formats the note allows; telling the producer and the puppeteer what a desk shows (they see
its table, a pad and a pen; what an act does to anything else is not shown at the desk); the Letter's page ink
([DeskMedium]'s canvases) and a table sheet's picture skin are still two ways to draw ink.

## Why the desk is not rebuilt inside the table

The desk's pad, its pen's walk between writes and its camera are the old look itself, and the Letter overrides many of
those methods: moved under the table, the overrides would go quiet. So the table hands the desk an episode, and what both
sides draw (the pen, the ink, the hand) is the shared code. A table's loose sheets (a recipe's slip, a label, a page on a
prop) keep their own picture skin: a surface of any shape, bent and carried.

## What stays a medium's own

- **When each thing is done.** The desk's pen keeps pace with the voice word by word ([method DeskMedium.elastic]); a
  letter's writes two words ahead ([LetterScript]); a table's runs over its act's seconds.
- **The framing's numbers** (how close, how high, how slow).
- **The Letter's poses** over the pen: picked up, set down, an ink swapped, a tap, a point at the lens.
