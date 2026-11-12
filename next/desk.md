# One desk: one pen, one hand, one desk for a lesson and a letter

## Status

**Built; a lesson made at the desk awaits the user's eye.** A pen writing by itself was drawn by two codes: the Letter's
desk ([DeskMedium], [LetterMedium]: a desk dressed from its seed, a legal pad turned over its binding, a pen that waits and
gets out of the way between writes, a camera close on the line being written) and the table ([TableWork]'s `write` and
`point`, [SheetWriting], a pen the set dresser built, a camera on a tripod). What both draw is one code in `table/` - the
pen ([Pen]), the ink ([Ink]) and the hand ([Handwriting]) - and the desk is the one desk: a table show's episode plays at
it ([EpisodeDesk]). `theorem-grooving.md`'s Medium says `format: desk`, so its next episode is made for the desk.

- **The pen rests until it is needed** ([method DeskMedium._pick_up_pose], [method DeskMedium._set_down_pose]): at the desk,
  for a lesson, a letter and an episode alike, it lies beside the pad's right edge, is picked up as its first stroke comes,
  and is set down a beat after its last action. A letter adds its own: a guess at its first stroke before the words arrive,
  a point at the camera holding the pen, a change of pens. The camera stays wide until the pen is picked up.
- **An episode's pen leads the voice** ([method EpisodeDesk._ahead], [method DeskMedium._lead_of]): a line is begun ahead of
  its word by the time its own first two words take to say, and kept that far ahead, as a letter's pen is; a lead never
  reaches back across a pause before its line.
- **One pen** ([Pen]). The desk, the Letter and the table pose their pens through it: the nib on a hand's strokes (eased as
  `Ink.share` has it; the table's ink picture is put down on the same easing, so the nib is at the ink's front), between
  them, pointing and resting; the hand's lean, one for all three (`Pen.UP`: to the right and a little down on the screen, back
  over a right hand toward the writer); a lifted pen drifting as `Hands.drift` has any held thing; its frame.
- **One hand** ([Handwriting], moved down from `desk/`). The table's words in a hand (`neat`, `quick`, `print`: Kalam,
  Caveat, Patrick Hand, `CardTable.HANDS` `strokes`) are written in the hand's traced strokes, as a letter's are, and a pen
  seen follows them ([method SheetWriting.words]); a typewriter's are set from the font. One stroke picture for a formula
  and words ([method TableInk.picture_of_schedule]).
- **The desk plays a table episode** ([EpisodeDesk], Medium row `desk`, Table's). Each act's writes and points are the
  desk's actions on its one pad, whatever sheet and pen they name: a write begins at its act's word and keeps with the words
  to the next act's word, as the old desk's dictation did; a point is held while it is talked about; a strike crosses out
  the line its act names. Words with no math are written in their hand on the pad's rules; what TeX lays out is the
  episode's `ink.json`. The desk is the Letter's ([DeskLook]), its camera the old desk's a little closer ([constant
  EpisodeDesk.EPISODE_LOCAL]). The lesson, the letter and the episode lay out their actions and begin the desk one way
  ([method DeskMedium._begin]).
- **The desk's rows are the Letter's** ([DeskRows], on the Medium card under Desk: [DeskFormat]): which desk by number, its
  light, what is on it, the index cards' words, kept in the `medium:` block and seen at once while an episode plays (the
  desk dressed again, the episode not loaded again). A number of 0 is each episode's own desk: the things and light chosen,
  placed from the episode's number. A pick between Table and Desk opens the note again around its rows.
- **The episode keeps its medium.** A table show's note has the Medium card (Table brings it; [method Medium.offered] gives a
  note that `provides` an episode Table's formats alone - the table, the desk); a pick is its block, never the remembered
  medium, and a block naming another format is kept as it was until one of Table's is picked. Generate hands the producer
  the block's format and the plan keeps it ([method TableProducer._land_medium], [method TableEpisode.medium]); the Episode
  card pins the episode's medium, so an episode made before plays as it was made. A desk episode's steps are the plan, the
  solve, its table ([DeskTable]: a pad of sheets and a pen, landed as a set dresser's table is), the acts, the ink and the
  readers - no set dresser, no cloth, room or depth painted.

Held by `tests/desk/episode_desk_check.gd` (the lesson from an episode's acts, played at the words; the desk dressed by its
rows; the episode's medium and steps; the producer keeping it), `tests/media/medium_pick_check.gd` (a table show's Medium
card, the Desk's rows), `letter_format_check` (the desk rows on a letter),
`tests/notes/components_check.gd` (Table brings its Medium; the control an Actor), `page_writing_check` (the table's words
the hand's strokes), `letter_check`, `ink_check`. Looked at with `tests/desk/episode_desk_look_probe.gd` (its own lesson
of a page and more: the opening, formulas, words, a drawing, a point, a strike, a page turned).

**What the user still has to judge:** a Theorem Grooving episode made at the desk and watched - how close the camera is,
whether each write keeps with its words, the desk's mood and things.

**Open:**

- **The producer choosing the medium.** An episode is made for the format the Medium card names; the producer does not yet
  choose among the formats the note allows (a lesson at the desk, a demonstration at the table).
- **Telling the agents what a desk shows.** The producer and the puppeteer see its table (a pad and a pen) but are not told
  that the desk shows only writes, points and strikes: an act that moves or uses anything else is not shown there.
- **Two ways to draw ink.** The Letter's page ink ([DeskMedium]'s canvases) and a table sheet's picture skin
  ([TableInk]) still draw the same strokes two ways.
- **The GPU gates over this work.** The pixel and shader gates (`scripts/check.sh --gpu`) have not run since the desk was
  joined; the desk was looked at with `episode_desk_look_probe.gd`.
- **Outside this repo.** The status table in `~/repos/rift`'s ENTRYPOINT still calls Theorem Grooving a table show.

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
