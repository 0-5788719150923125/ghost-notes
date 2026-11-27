# The head

A speaker's head as a thing in the scene: where the mouth is round a microphone, how the head is turned, tipped and leaned, and what
that means for the sound. First use: the Studio (next/studio.md), where the viewer's camera IS the creator's head - leaning in at the
left of the microphone, the camera goes left, comes close and looks along the windscreen - and the voice is heard from where the mouth
is: its pan, its nearness, and muffled where the mouth turns away.

THE MOVEMENT MEANS SOMETHING ONLY BECAUSE IT IS HEARD: one performance of the head moves the camera and places the voice, so what is
seen and what is heard never disagree. NOTHING IS A FIXED MOVE: the head performs the show's own habits, each written in ranges and
drawn afresh every time, timed to the words.

## Status

Built, each piece with its gate:
- the performer (`HeadPlan` in `motion/`);
- the show's bank (`HeadBank`), designed by an agent who is shown its phrases measured (`HeadDesign`, rules/table/head_designer.yaml), its row on the Studio's Pipeline card;
- the phrases a script calls, timed on a take's words (`HeadMarks`, `ScriptMarks` `head`);
- the voice placed by the performance in the kept take's pass and the live stream (`VoiceFX` `place`: pan, nearness, muffle; Lean and Near standing aside);
- the Studio's eye moving with the head, rolling with its lean;
- what the reader is told (the show's phrases by name), and a passage handed back told why (`StudioMedium.reader_check`, `TableProducer` `sent_back`).

Looked at in the probe with the fixture bank (`tests/fixtures/studio/head_bank.json`): near the middle through the opening, then leaning in at either side, close on the fur, the picture rolling with the lean, sitting back at other angles.

Not yet:
- the hush where the head comes close (the near plan stands aside for the head, and its hush with it);
- the Voice card saying why its Lean and Near stand aside;
- a phrase refined on its own (the bank is designed whole; ⟳ designs it again, the one before kept a version back).

Open for the user: the bank an agent designs, by eye and by ear.

## Phrases (`HeadPlan.sanitize_phrase`, `HeadBank`)

A phrase is a short choreography: its moves in order, each a place round the microphone (`side` in degrees, `distance` and `rise` in
meters) with the head's `turn`, `tilt` and `roll` there, how long it `take`s against the phrase's other moves, the share it `hold`s
still, where its arrival `land`s (a stressed word, a sentence's end, anywhere), and optionally where the eyes `look` (the flip screen,
the lens). Every value is a range, drawn afresh on each performance; a phrase also has `repeat`, `length`, `weight` (how often it is
picked) and `calm` (one the opening and the close favor).

A show's bank is ITS OWN, kept in the library (`<library>/head/<show>.json`, the Table block's `show`), designed by an agent told the
show and what the head means to the picture and the voice. Its answer is performed and measured (`HeadPlan.measure`: how often the voice
crosses the ears, its pan's range, nearest and farthest, most muffled, length, how far two performances differ) and the numbers handed
back once: it puts right what does not do what its own line says. The bank before is kept a version back.

## The performance (`HeadPlan.make`)

A pure function of the phrases the script calls (each at its word), the take's words (their times, stresses and sentence ends), the
bank and a number.

- A phrase the reader calls (`<!-- head: NAME -->`) begins at its word and is stretched to its sentence's end where that is near.
- Between calls the performer picks a phrase by its weight after a short settle: the head is never parked.
- Each move comes to rest on a stressed word or a sentence's end where its phrase says, sliding up to `LAND_REACH` of its length to get there.
- Through the opening (the first half minute of words) and the close (the last thirty-five seconds), the head keeps near the middle: the calm phrases favored and every move pulled toward home (`calm`).
- A move is minimum-jerk along a bowed path. The turn leads it and the lean lags it, each on its own clock, with a swing of its own on the way.
- A held head drifts and breathes.
- The mouth stays where a seated head can be: never in the windscreen, never more than 30 cm over it, never out past it toward the camera, never more than 42 cm to a side.

## The sound

The voice is heard from where the mouth is: its pan from the mouth's angle round the microphone (level only, 70/30 at the most, as the
lean is), its nearness from the distance (the direct voice up against the room, the proximity bass), and muffled as the mouth turns
away (`VoiceFX` `MUFFLE_*`: the direct voice's highs dulled and some of its level gone - speech beams forward). A show with a bank is
heard so whether or not its script calls a phrase; its takes are signed by the bank (`take_sig`). The props' sounds already come from
where the props are, in the same frame.

The seam:
- `HeadMarks.plan` performs the head on the take's own words, matched to the script by the follower the Studio reads with;
- `HeadMarks.lane` hands `VoiceFX.place` the `(pan, near, muffle)` lane for the frames it is about to process, in the kept take's one pass and the live stream alike;
- the reading's document carries the bank (`head`), so the Studio performs the same.

## Gates

- `tests/motion/head_plan_check.gd` - a phrase made safe; a pure function of its inputs; never the same twice; the turn leads the lean; moves land on stressed words (control: free); with nothing called it performs (control: no bank, it rests); the opening and the close keep near home (control: between, it goes out); turned away it muffles; never in the windscreen; measured; a bank kept for its show, the one before a version back.
- `tests/reading/head_lane_check.gd` - a mark timed on its word, naming its phrase; an unknown name named; a show with a bank performed uncalled (control: none); the left ear louder leaning left (control: no lane); turned away duller (control: facing).
- `tests/studio/studio_script_check.gd` - a passage's unknown phrase named; the reader told the show's phrases (control: none); the designer told the fields and shown its phrases measured; nothing resting seen over minutes of performance.
