# Letter: a letter written by hand at a desk

Opened 2026-10-26, for the user's chapter `rift/books/north-star/chapters/43-secular-haze.md`: "a
letter-writing mode ... akin to the theorem-proving mode we have, with an author writing a letter to
someone. It would need to support direct reading while writing, as well as 'inner monologue' style
pauses ... inline doodles or full-screen, slow-panning images (while voice plays in the background,
continuing to write, like a flashback). There may also be pen actions, like tapping the top of the pen
on the table, while the author thinks to himself."

**Phase two, named by the user and not built:** the set dresser's agents populating the desk - things
on it, another texture for its top - as they do the card table ([cards.md](cards.md), `Tables`,
`Props`). The desk is already built from those parts ([DeskLook], from the seed), so the seam is
`DeskLook.dress`: a letter's table spec, written by an agent, in place of the seeded one. **Its light
is built and seeded (2026-10-27)**, in the table's own words, so an agent can write it later: below,
"The desk is lit as the card table is".

## What it is

**A component, `letter`** ("+" Letter on a note; it brings a Voice; the reading's workspace runs it, as
the Actor's card stands there). **The note's words are the letter, word for word**: no agent writes it.
Its card ([LetterCard], `src/letter/`) pins the medium, draws the sketches, paints the pictures and hands
the reading the letter with the pen's rests in it ([LetterWalk]) and the document a render draws from
([LetterCard.Publish]).

**A medium, `letter`** ([LetterMedium], `src/desk/letter.gd`): the Proof desk's ([DeskMedium]) - pad,
pen, lamp, camera, the voice followed word by word, the elastic pen - with the letter's own hand and
moments. Its parts are the desk's; the hooks it needed are small and the desk's behavior is unchanged
(`_end_fade`, `_ended`, `_travel`, `_wide_frame`/`_local_frame`, `_wander_time`).

**The journal's hands, written by the pen, no TeX** ([LetterHand], `src/desk/letter_hand.gd`; 2026-10-27,
the user: "the font looks awful ... the journal medium had nicer fonts"): Kalam (the default), Caveat or
Patrick Hand - the Notebook's ([NotebookLayout]) at its sizes - picked on the Letter card's Hand row and kept
in the block (`hand`). An outline font is a shape to fill, so each is traced ONCE into the lines a pen draws
it with (`scripts/hand_strokes.py`, numpy and Pillow, a development tool): every printable ASCII character
rendered at 400 px an em, thinned to its centerline (Zhang-Suen), cut where it branches - two junctions
closer than a stroke's width one crossing, the stubs thinning leaves at a corner dropped - and walked into
strokes as a hand writes: from the top left, on through a branch the way the line was going, lifting at a
turn sharper than 110 degrees, a line begun at its tail turned round (an a, an e, a g), a ring from its top
counterclockwise, a dot (an i's, a period) last as a small spiral. Kept in Hershey's own format
(`fonts/hands/strokes/*.jhf`, which [Ink] reads and the export ships with the plotter fonts); what the
format cannot hold (units to the em, the baseline, the reach, the nib) is the tracer's printed row in
`LetterHand.HANDS`. Drawn with a round nib as wide as the font's own stroke (its ink over its centerline's
length), the page is the font. A print hand: the pen lifts between letters. The first pass was the Hershey
simplex SCRIPT font, a centerline cursive, its letters joined into one stroke a word - thin and spindly
at the letter's close camera.

## The marks ([LetterScript], `src/desk/letter_script.gd`; ScriptMarks group "letter")

| Mark | What happens |
|---|---|
| a paragraph | written while it is said, a line at a time, each line a dictation of its own words |
| `*a paragraph in italics, whole*` | a THOUGHT: said, never written; the pen up, the camera eased back |
| `<!-- strike -->`, `<!-- strike: 5 -->` | the writer stops to decide (3 s, or the mark's own seconds), the pen still, then crosses out the paragraph last written, every line |
| `<!-- unspoken: Dear Ink, -->` | written, never said; the voice waits |
| `<!-- sketch: words -->` | drawn by the pen while the paragraph after it is said - that paragraph is the drawing's, then written under it while the voice waits |
| `<!-- point: sketch -->`, `<!-- point: sketch, the dot -->` | in a thought (or any paragraph the pen is not busy with): at the next word the pen points at the last sketch, or its named part, to the sentence's end |
| `<!-- point: camera -->` | the pen lifted, its nib turned to the lens for the sentence |
| `<!-- tap -->`, `<!-- tap: desk -->` | the pen turned over, its top tapped three times on the pad (or the desk), turned back |
| `<!-- image (full): words -->` ... `<!-- /image -->` | the picture over the whole screen for the passage between, faded in and out over 2.5 s, each moving its own way (closer, back, across); the pen writes on unseen. Another image mark before the close, or straight after it, dissolves into its picture - the page not seen between |
| `<!-- still -->` | to the next written line: the camera dead still on the last sketch, the pen off the pad |
| `<!-- new page -->` | the next writing starts a page of its own |

Hesitations, deliveries and speakers pass to the voice; any other comment is a note.

**The chapter's `<!-- note: ... the camera holds still on the cross and the dot, with the pen well clear
of them, or the test cannot work -->` is a note and does nothing**: written as `<!-- still -->` it is
exactly that.

## Decisions, and what was measured

- **No indent; a rule left empty between paragraphs** (2026-10-27, the user: "the hanging indents look
  wrong, when the first several paragraphs are each just ~10 words long ... there should probably be a
  newline between each paragraph"): the book's rule ([BookLayout] `INDENT_EM` 0). A paragraph after a
  sketch keeps the sketch's own spacing; a sketch kept with the lines that point at it counts their empty
  rules (`_keep_with`).
- **The writer decides before striking** (2026-10-27: "The actor writes the line, then IMMEDIATELY scratches
  it out ... an actor would likely write the line, then pause, then scratch it out after a few seconds of
  silent decision-making"; then: "the user could specify their own delay time in the marker"): the voice
  and the pen both done, the pen held still over the line `LetterScript.DECIDE` (3 s) or the mark's own
  number, then the strike; the voice rests through both (`decide` on the action, `DeskMedium._build_plan`).
- **A picture clears before the letter goes on** (2026-10-27, the user: "the first full-screen picture
  seemed to linger for far too long"): it fades out from 0.1 s after its passage's last word over 1.2 s,
  and the voice rests until it is gone, so the next thing the pen does is seen from its start. It had faded
  from 0.4 s over 1.4 s with no rest, so the chapter's first sketch began under it. The passage itself is
  the author's: the chapter's first picture is up over 94 words, the next three over 170, 123 and 122.

- **Pictures dissolve into one another; every fade is 2.5 s** (2026-10-27, the user: "it would be nice if we
  could blend from one picture into a second one, or a third one, directly without ever seeing the page again
  ... each with different panning/zooming behavior"; then, of the fades: "seems to be too fast. A 2 or 3
  second fade might look better"). Back-to-back image marks had been parsed as a run already (a mark closes the
  one before), but the screen drew one picture: the first faded to the desk, then the next popped up whole. Now
  a picture whose passage begins where the last one's ends - its mark before that one's `/image`, or straight
  after it - is its span's `blend`: it comes up over the one before, held whole under it until it is in, the
  voice reading on with no rest for the page (`LetterMedium.pictures_at`, the plate drawing them bottom first,
  `cover_of`). Each picture takes a move of `LetterMedium.MOVES` (closer, back, across) by the seed, never the
  one before's, drifting at least a quarter turn from its way (`moves_of`). `LetterScript.IMAGE_FADE` 1.2 to
  2.5 s for every fade, so the rest the voice takes for the page to come back is 2.6 s.
- **A page turned inside a paragraph is read on through** (2026-10-27, the user: "the voice speaks "You do
  not" - then holds for X seconds until the page turns ... It would probably feel most natural to just keep
  speaking there, and to force the pen to catch up after the page turn"). The voice had waited at the turned
  line's first word for the page to be read, turned and the pen two words into it - 3.5 s and more,
  mid-sentence. Now the voice reads the paragraph on (`LetterScript._voice_text`'s `turned_in`: no wait at the
  turn nor after it in that paragraph); the page still turns once the voice has said its last word, and the
  pen comes back behind the voice. Even at its quickest the pen is hardly quicker than the voice (on the gate's
  letter it is 4 s behind and still 3.7 s behind a line on), so it catches up at the next paragraph, where the
  voice waits for it if it must - on the chapter 1.7 s before "Mine were:", where the writer would pause. A
  turn between two paragraphs is still rested for: the writer turning the page is the pause there.
- **The desk is lit as the card table is** (2026-10-27, the user: "It's not clear to me what the 'Desk' value
  under the 'Letter' card is doing. Is that just a random seed? ... I am wanting for some more detail in the
  scene, akin to what the agents produce in True Tarot episodes. Just, some nice ambient lighting, maybe some
  open-flame light sources, which cast nice shadows ... some weird stripey rings of light across the desk and
  paper ... leverage the Table primitives"). The Desk number is the seed of the desk's whole look; the card now
  says the MOOD it picked beside it. Each desk has one (`DeskLook.MOODS`): lamplight (the lamp, a dark room -
  a screen's glow, a street lamp, a fire or the moon in a window), candlelight (the lamp off, one to three
  candles on the desk, the one that lights the page most the key), daylight (the sun through a window across
  the desk, clouds now and then) and dusk (a low gold sun through it, the lamp part on). The room's light is a
  `Lights` spec written as the set dresser writes a table's and built by `Lights.build` on the desk's stage,
  fitted to the paper; the candles are `Props` things with wicks, their flames the table's (`TableLight`'s
  flame quad, flicker and filtered shadow, made static for any host), each held to what the page can take
  (`DeskLight.PAGE_HEAT`) and turned to face a camera that looks nearly straight down. THE STRIPES were the
  lamp's shadow map: on the stage's own atlas (2048, its first quadrant split four ways) the lamp had 512
  texels for the whole desk, and the page and desk wore a fine diagonal moire of it; the desk now sets the
  card table's stage (`TableMedium.STAGE`: 8192, a quadrant of its own for the lamp, debanding, 4x MSAA) and
  gives it back as it leaves. Proof's desk takes all of it too.
- **The desk is drawn only as it changes** (2026-10-27, the user: "performance can be really quite laggy in the
  realtime viewer ... the scene itself is pretty simple"). Measured on the chapter, frame by frame at the viewer's
  rate - by the thread's own processor time, and under a real renderer (xvfb on the card; xvfb's own empty frame
  costs 12.9 ms of the main thread, which a real display does not):
  - THE PAGE RENDERED EVERY FRAME: both page viewports were `UPDATE_ALWAYS`, a page of handwriting about 2,100 draw
    calls, 1.9 ms of the main thread a frame whatever changed. Now its finished ink is a viewport of its own inside
    the page (rendered first), rendered as a line is finished; the page under the line being written is rendered as
    the pen moves; the turning page once a turn - 0.2 ms, about 130 draw calls. Read back frame by frame across four
    lines' ends, no frame loses a line.
  - A LINE'S END REBUILT THE PAGE: the whole page's ink was made again point by point, a 20 to 35 ms frame every few
    seconds; now a finished action's ink is made once (`DeskMedium._done_ink_of`) and moved onto the page in one
    native step (`Transform2D * PackedVector2Array`), the line being written 0.35 ms to 0.2.
  - EVERY FRAME WALKED EVERY ACTION, a dozen times: whether each line on the page is written (the elastic dictation
    word by word, for lines done minutes ago - now 1 past its end, `_written`), the pages, the pen from the letter's
    first action, the camera's framing, the close, a tap. Now the actions are indexed by page, kind and turn once a
    letter is laid out (`_page_actions`, `_of_kind`, `_turn_actions`), the pages and each line's ink time are kept for
    the moment and the plan (`_plan_rev`), the pen's walk goes on from where it found all done, and the follower
    keeps its last known word. The script's frame, about 3.3 ms with 34 ms spikes, is about 1.3 ms.
  - A LIVE READING MADE ITS PLAN AGAIN as each sentence's words arrived, working out every action - for the finished
    ones only to overwrite them with what was kept; now they are kept as they are: 9.9 ms to 2.0 three quarters in.
  What is left: the desk's 3D (0.4 ms of the main thread, 2.4 ms of the card) and its shadows (about 1 ms), and the
  voice host, which synthesizes ahead on every core but one while the reading plays. letter_check holds each fix as a
  share of its control.
- **A dense sketch is dashed off** (2026-10-27, the user, of the chapter's tree of dots: "the final row with 32
  dots has zero lines connecting any of them. I think that was a bug, because the text below it sort of gets
  frozen for a few seconds as well, with the pen not moving"). The unjoined row is the sketch mark's own words ("a
  long row of dots too many to count trailing off"): the drawing agent drew what it was asked, 23 dots and no
  lines. The freeze was the VOICE: the tree's 47.5 s of ink at the desk's quickest (4 times the hand's pace) ran
  6.5 s past its 13 words, and the voice waited 7.5 s after "Then eight" while the pen dotted its last two rows, the
  caption held. Replayed with every word known and with each sentence's words arriving 3 s ahead, the pen never
  stops, and its wet ink costs 0.4 ms a frame. Now a sketch with more ink than its words leave time for is drawn
  quicker, up to `LetterScript.DRAW_QUICKEST` (7) the hand's pace, to be done `DRAW_TAIL` (1.5 s) after them
  (`draw_pace`): the voice's rest is sized by it and the desk draws to it (`LetterMedium._paced_end`), filling to
  the next line as before. The tree: 7.1 s, done 1.5 s after its words, the voice on 2.9 s after "Then eight". A
  sketch with room keeps its pace. To have the long row joined, the mark can say so and the sketch be drawn again.
- **The paragraph after a sketch is its narration, said as it is drawn - and then written under it.** The
  pen cannot write and draw at once, and the only words to draw under are the next ones. In the chapter every
  sketch is followed by words about it ("A cross, and a dot, on the same line, about a hand apart.") - the
  drawing is said as it is drawn, the desk's rule. Not written at first; on 2026-10-29 the user, of the tree
  of dots in Secular Hazing: "why is this line not written at all? ... it fails to write down the context Pen
  would need to have here" - the letter is Pen's to read later, and a drawing with no words reads as nothing.
  Chosen of four (written as said and drawn after; a mark per sketch; the `unspoken` mark by hand): drawn
  while said, then written as `unspoken` words are, the voice waiting (about 10 s for that paragraph at the
  hand's pace) - its caption stays while it is said, the words not on the page yet. A sketch not drawn yet has
  its paragraph written as it is said. And a rule is left empty under every drawing
  (`LetterScript.UNDER_SKETCH`; the user: "Both sketches are too squished today, with text that is too close
  to them") - the text had gone on the first rule clear of it.
- **The pen writes two words ahead of the voice** (2026-10-27, the fifth pass). How it got here:
  - the first two passes kept the pen with the voice word for word (the desk's elastic pen, `LAG_MOST` 2.5 s
    of trail): the user, "Something about this mode feels wrong and bad ... the pen writes very fast
    simultaneously";
  - the third let the voice lead, the pen at a hand's pace (48 words a minute), and TIME SKIPPED under 1.2 s
    dissolves (62 in the chapter): "A person wants to read what is being said, and while the pen is so far
    behind the voice... they can't do that ... write ahead, and pause at the start of each sentence";
  - the fourth wrote ahead at a hand's steady pace (86 words a minute), the voice waiting at each sentence's
    start: "on average, 5 or 6 words ahead of the speaking ... It makes the pauses between sentences far too
    long ... maybe 2 words ahead of the speaking?" A pen slower than the voice makes the voice wait out the
    difference at every sentence, whatever lead is asked for (the chapter 43 minutes, and longer the slower
    the hand); and its rests were sized against a guessed voice, quicker than the user's.

  Now each word is written while the voice says the one `AHEAD_WORDS` (2) before it: the desk's elastic
  dictation on the voice's OWN times, so at any voice's speed (`LetterMedium._due`, `_ahead_times`,
  `_paced_end`, `_share`), never quicker than `QUICKEST` (2.5) times the hand's pace (at 2.0 a voice of 0.36 s a
  word outran it by 18 words). The voice waits only where the pen cannot be two words ahead: a paragraph after a
  thought, a still or the blank page, for its first two words (the line's `gate` "voice" and `gate_rest`, the
  pen beginning as the voice gets there); a page turn, once the voice has read the page ("turn"); and a run of
  words far longer in ink than in speech. Measured on the chapter: 28.3 minutes on a voice of 0.45 s a word, 23.1
  on 0.36, 1.8 minutes of rests in all (24 inside a paragraph, mostly turns); the pen 1.2 to 1.4 words ahead as
  each word is finished (it writes the word two on from the one being said), 7% of words said a moment before
  they are finished at 0.45 s a word. Under a picture the desk's own dictation, unseen. The pen moves at about
  the voice's speed again - the price of short pauses - but two words ahead of it, never on it.
- **The subtitles caption only what cannot be read on the page** (2026-10-27, the user: "the subtitles can
  be a bit of a distraction ... hide the subtitles for any text that is already being written on the page ...
  anything we can't see or didn't write directly on the page will need subtitles"): a line is drawn while a
  picture covers the screen, or when any word of it is not written - a thought, a sketch's narration
  (`LetterMedium._captioned`, handed the overlay as `Subtitles.captions`, a hook any medium may set; the
  line eases out and in as any does). A passage under a picture with no painting is read over the desk, and
  not captioned.
- **The writer hesitates too** (2026-10-27, the user: "after "Dear Pen," - why was there no hesitation at
  all? Why wasn't the marker respected?"). The voice did rest there - in the chapter's own voice, joined as
  the reading joins it, 2.4 s of silence after "Pen," (the hesitation's 1.5 s and the voice's own) - but the
  pen, two words ahead, wrote straight on into "Isn't it suspicious". Now a hesitation, on a line of its own
  or inside a written line (`LetterScript.parse`'s `pauses`), stops the pen after the word before it, and
  the pen is taken up again `RESUME_LEAD` (0.9 s) before the voice goes on (`LetterMedium._resume_floor`).
  Only hesitations: an `action-hold` is often the voice waiting for the pen, and stopping the pen there
  would lengthen it.
- **A hesitation before a picture is the writer's first** (2026-10-28, the user, of Secular Haze's
  "Housing came into my room looking for you." and the `<!-- hesitation: 3 -->` under it: "the picture that
  follows is immediately displayed - not waiting for the hesitation at all"). A picture came up from the end
  of the word before its passage, and the hesitation sits after that word. Now a picture whose mark a
  hesitation stands before (`after_hesitation` on its span) comes up as the pen is taken up again, `RESUME_LEAD`
  before its first word (`LetterMedium._comes_up`), the desk seen through the pause; one dissolved from is held
  whole through it, and a live reading not yet past the pause keeps the desk. Gate: letter_check.
- **A point lingers** (2026-10-28, the user, of "That one's me." at the dot: "the camera moves there quickly, and
  the pen retreats immediately, and the camera moves again, and it feels jarring. We need the linger when we
  point"). A point was held only while its sentence was said - three words, about a second - while the camera
  had set off for it 3.5 s before (`AWAY_LEAD`), so it arrived as the pen left. Now a point in a thought, at a
  sketch or at the camera, carries `linger` (`LetterScript.POINT_LINGER`, 3 s): the voice rests that long after
  its sentence (at the next sentence, or after the paragraph), the desk holds the pen on its target through it
  (desk.gd's point plan, `linger` on the action - Proof's points carry none), the camera stays on a point under
  way rather than setting off for what comes next (`_framing`), and a point at the camera holds the pen up
  through its rest (`_camera_until`). In Secular Haze the voice rests 3.4 to 3.8 s after each of its three.
  Gate: letter_check.
- **The tree's loose row is gone** (2026-10-28, feedback 0008, "See the extra row of unconnected dots? They are a
  problem"; the user: "just removing it might work best - because the pen would have to draw extremely fast
  there"). The chapter's description no longer asks for "a long row of dots too many to count", and the drawing
  the agent had made was kept, its 23-dot row taken out and its height cut to match (`sketches/b737f232b21e1ddc.json`,
  fingerprinted as drawn from the new words; the ink laid out again). The point at "the dot on its own" is kept.
- **Words struck inside a line** (2026-10-28, the user: `like <!-- struck: morning --> mourning` - "Rather than a
  full-line replacement, this would replace a single word or a sequence of words ... write the original, pause for
  a bit, then strikethrough and write the replacement words beside it"). The struck words are the paragraph's,
  written and said (as a struck paragraph is said); the paragraph is cut after them into parts (`_marked`, a cut
  `{at, struck, ink}`): the voice reads the first part, rests `DECIDE` and the strike, the pen crosses out those
  words alone (a strike's `x0`, `x1` along its line - `DeskMedium._struck_line`), and the next part goes on beside
  them on the same rule (`cont`, `cont_x`; `lay_out`), or at the margin if its first word will not fit. A run
  over a line's end is crossed out on each line. In Secular Haze "morning ... mourning" with a 4.6 s rest - then
  (the user: "it feels like the second 'mourning' should not have been spoken") WORDS WRITTEN AND NEVER SAID inside
  a line: the unspoken mark there (`UNSAID`, kept between two characters no script holds) is written and none of it
  said, the closing marks it ends on left to the voice (`_voiced`: `<!-- unspoken: mourning. -->` still ends the
  sentence), and a part with nothing in it to say rests the voice while it is written (`_voice_part`). The chapter
  now says "...it looks like morning." and rests 6.35 s while "morning" is crossed out and "mourning." written.
- **A pen each ink** (2026-10-28, the user: `<!-- color: red -->` / `<!-- color: default -->`, then: "a single pen
  would not be able to create 2 different font colors. So, could we render multiple pens at the start, and pick them
  up/put them down as we use them? We would need to pre-scan the entire script"). `LetterScript.pens_of` scans the
  letter first - the desk's own pen, then each ink named (`NotebookLayout.INKS`, a hex color; `default` the desk's)
  - and `LetterMedium._lay_pens` lays a pen for each past the first beside it, further out (`DeskLook.PEN_APART`,
  the desk's things kept off them all), its body lacquered in its ink. A change of ink is a `swap` action
  (`LetterScript.SWAP`: the pen in hand put down at its place over 1 s - the opening pick-up run back, `_lift` - and
  the other picked up over 1.6), the voice resting through it; a change on a line of its own waits for the next
  thing written, one inside a written line cuts it there as struck words do (a strike then a change: crossed out
  with the old pen, the correction in the new), and one INSIDE A WORD splits it with no space (`GLUE`; the chapter's
  `Pen<!-- color: red -->.<!-- color: default -->`, its closing stop alone in red - "Pen." still said whole, one
  rest of 5.8 s for both changes). Every line, strike and sketch carries its pen's ink, and the canvas draws each
  stroke in it. Gate: letter_check `_pens`, `_struck`; script_marks_check. Not yet seen rendered.
- **A page turns where it runs out, mid-sentence too.** The legal pad of the desk, 24 lines to a page,
  about 230 words. The voice rests for the turn (`TURN_REST` and the pen's first words) between two
  paragraphs, and - 2026-10-28, the user: "if a page ended with punctuation, we can hold the voice until
  after the page turn. However if a sentence was broken by a page turn, we should just finish the
  thought/voice - and then we should wait for the pen to catch up, before proceeding with the next
  sentence" - inside one where the page ends on a mark (`LetterScript.PAUSE_END`: a stop, a comma, a
  semicolon, a colon, a dash). A sentence the page breaks is read on to its end, and the voice waits for
  the pen at the next sentence (it had waited only at the next paragraph, with the pen at its quickest all
  the way there: "the pen has to go at like 5x speed to catch up"). The words said before a line begins
  are written at the pen's quickest (`LetterMedium._ahead_times`): given the line's start all at once, the
  elastic pen had smoothed them over its window and written them at near half that, two seconds late.
  Over Secular Haze's 20 turns: after a mark, about 4 s rested; a broken sentence, 3.5 to 4.3 s at the
  next sentence; the pen never past its 2.5 times over the page seen.
- **A line runs on into the voice's pause after it** (2026-10-28, the user, of "my line of work. It is |
  called a zero-knowledge protocol": "the pen just stops moving at "it is", for a second, before it moves
  to the new line"). A line ends as the voice ends the word two before its last, and the next begins as
  the voice begins the word two before its first: where a sentence ends two words before a line's end, the
  voice's pause after it fell between the two, and the pen stood at the line's end through it - 22 times
  in Secular Haze, read by a voice that pauses 0.7 s at a stop. Inside a line the elastic pen slows through
  the same pause. Now the line is written on into it, done as the nib must leave for the next
  (`LetterMedium._runs_on_to`) - never across a hesitation, where the writer stops too.
- **The camera's arc over a page, gentle** (2026-10-27, the user: "The forward and backward zooming of the
  camera is nauseating. Like the journal and tablet mediums, we really need to dial that behavior back"):
  as the book's and the tablet's, a page opens on the whole pad (`LETTER_WIDE`, 0.85 m), closes in on the
  writing over 9 s once it has come up (`LETTER_LOCAL`, 0.47 m: three fifths of the page's height and all
  its width) and lets go over 9 s, done 7 s before its turn - its springs the tablet's (4.2 s), which run
  about twice their time behind (simulated: a fifth of the way in as the sheet lifts). A turn not planned
  yet is guessed from its first word, AND ONCE THE CAMERA HAS BEGUN TO LET GO FOR IT, IT LETS GO FOR THE
  SOONEST GUESS YET (2026-10-28, the user, of the end of Secular Haze's first page: "it bounces forward and
  back a couple times, right at the very last few sentences ... the camera tries to catch-up"): a live
  reading's words arrive a sentence at a time, and the guess - at the desk's steady 0.33 s a word, no rest
  counted - ran ten seconds early twenty words out and moved later with each sentence (past the hesitation
  in "In both worlds, I was expelled.", past the rest as the picture clears), so the camera came back in
  twice as it let go (replayed without a renderer: its aim's closeness 0.49 back to 0.77, then 0.00 back to
  0.22). `LetterMedium._letting_go` keeps the soonest, and `_turn_guess` paces the guess on the voice's own
  last 40 words and the rests the script writes (`rests_of`): let go once, 3.5 s before an export would.
  Nothing else moves it in or out: a thought, a point at a sketch and a
  tap move where it looks, never how close; only a point at the camera stands it back (`CAMERA_K` 0.7, a
  fifth further), and a still holds close on its drawing. Across, it holds the column's middle. The first
  pass ran from the desk's 1.45 m to 0.38 (near four times), all the way out 3 s before each of the
  chapter's 18 turns and back, a step back of 70% for every thought, 50% for every point and tap, on
  3.2 s springs; and it swung across between a short line and a long one. For what the pen does away
  from the line it still sets off `AWAY_LEAD` (3.5 s) early.
- **The page lies blank a moment first** (2026-10-27: "the writing begins IMMEDIATELY after the intro
  disappears ... We should linger on the blank page for a bit"): the voice opens on a rest of
  `LetterScript.BLANK_PAGE` (4 s), nothing is written before it (`DeskMedium._blank`, a hook: none at the
  Proof desk), and the camera comes in over the empty pad.
- **The pen is picked up from the desk** (2026-10-28, the user: "the pen starts floating in the air already.
  I think it would be better if the pen started from a resting place upon the table, to the right of the
  paper, and if we gently picked it up at the beginning, after the intro-blur"). It lies beside the pad's
  right edge, its top toward the writer and turned out 4 to 16 degrees (`DeskLook.pen_rest`, seeded;
  `dress` sets nothing down there), through the intro and its focus pull; 1.5 s after the opening it is
  lifted by its grip, turned up into the hand and carried over the pad's edge in an arc, over 2.2 s, to
  hover over the first stroke as the blank page ends (`LetterMedium._pick_up_pose`, laid over the desk's
  `_pen_xf`; at most 4 mm a frame, its nib never into the desk or the pad). The Proof desk is as it was:
  its pen's first stroke comes with the first word, inside the focus pull.
- **The pen leans to the right and a little down as it writes** (2026-10-28, the user: "it would be more
  common for the top of the pen to point to the bottom-right (though gently, trending closer to pure right
  than directly to the bottom right corner)"): back over the hand toward the writer's right shoulder, as a
  right hand holds one, seen from the camera on the writer's side (`LetterMedium.LEAN` through the desk's
  `_pen_up` hook: 48 degrees up from the nib as before, 30 degrees toward the writer from straight right -
  on the screen 14 degrees under the level on average, 3 to 31 with the forearm's turn and the hand's sway).
  Its body lies over the paper not yet written; the desk's lean to the top right lay over the lines already
  written above the nib. The Proof desk keeps its own (its user's call, 2026-10-16), and the pen lies on
  the desk top toward the writer, as it is picked up.
- **What is on the desk and its light are chosen; the number only places them** (2026-10-29, the user:
  "It's really hard to find a good seed, because generating the scenes is kind of slow (startup is like 20
  seconds). I think it would be better to provide a multi-select bank of the standard objects ... Then, when
  we change the seed - the only thing being changed would be the placement of objects, and textures"): the
  Letter card's "On the desk" bank, a tick a `DeskLook.THINGS` row (the mat and the candles among them),
  and a Light row of the moods in place of the mood shown beside the number. Chosen (`DeskLook.of`'s picks:
  the block's `things` and `mood`), each thing is drawn from a generator of its own kind and placed by it, so
  another seed moves and recolors them and ticking another changes nothing about how the rest look; until
  chosen they are what the number drew, and the first change of anything on the desk keeps them
  (`LetterCard._hold_desk`). A candlelit desk given no candle gets a taper - its page would have no light.
  Ticked while the letter plays, the desk is dressed again at once, the letter untouched
  (`LetterMedium._set_desk`). **The number is the desk's alone**: it had seeded the hand too - each word's
  wavers, so where the lines break and the rests the voice takes ([LetterWalk]) - so a new desk was a new take,
  the 20 seconds of a Play to see it. The hand's seed is now the note's own (the document's `seed`,
  `LetterCard.hand_seed`) and the number the desk's (`desk`, [LetterMedium]'s `_seed`; `_hand` the hand's), so a
  number changed while it plays, paused or not, dresses the desk again at once. The Hand row still waits for a Play.
  **Measured: the camera sees little of the desk.** The lens is 20 degrees high: at 0.85 m the widest framing,
  its corners cast onto the desk, sees 56 cm across at the binding and 52 at its foot, 31 deep (`DeskLook.SEEN`),
  where `REACH`, "the stretch the wide camera sees", is 90 by 62; close, as the pen writes (0.47 m, following
  the line down the page), it sees 4 cm past the pad's sides. The first chosen desks put the dog tag and the
  pencil out of the frame on both seeds rendered.
  **A chosen desk is packed in to the paper** (2026-10-29, the user, testing: "almost all of the objects placed on
  the table are outside of the camera's view. Could we add some pressure that would push items inward, closer to
  the paper, in a more dense fashion? ... with just tea lights and the dog tags now... I still can't even see the
  dog tags ... certain items are better candidates to push outside (like candles, which cast light regardless of
  where they exist)"): `DeskLook._pack` tries each thing at 160 places, three in four snug against the pad's left,
  and sets it where it is closest to the paper and most in the wide frame (a share out of `SEEN` weighs 0.4 m) -
  its footprint its own turned rectangle (a circle had given a 5 by 8 cm tag a disc 9.4 cm wide), a long thing
  along the pad. Flat things first, smallest first (a small thing is seen only in the frame, a big one half out of
  it); then what stands, kept back from the pad as always; the candles last, nearest their band. The pad's right
  edge is the pen's - it rests there, taps the desk 2 cm out and parks off the top right - so things go left.
  Measured: tea lights and a dog tag, the tag within 4 cm of the paper and in the wide frame on 16 of 16 seeds (a
  circle anywhere in the frame, 4); a crowded desk of nine, 59 of 60 flat things in the frame and 0 of 36 candles.
  Dressing a desk of nine takes about 0.4 s. **Candles on both sides** (2026-10-29, the user: "I don't think I've
  seen a candle placed on the right side even one time ... The scenes look best when lighting comes from both
  directions"): they had stood beside the pad's left alone - chosen so the right hand's shadow falls away from the
  line. Each candle now takes a side by turns from a seeded first (`DeskLook._candle_right`), drawn desks and chosen
  alike; the right's band (`CANDLE_RIGHT`) stands past the stretch the pen keeps (it leans out, rests, taps the desk
  and parks there), at the frame's edge or past it - its light across the page from the right, the pen's shadow
  then falling left. Measured: 48 of 95 candles on the right over 60 candlelit desks, every desk of two lit from both.
  **Things on both sides of the pad** (2026-10-29, the user: "the pencil and dog tags and probably other objects as
  well are NEVER placed on the right ... desk layouts are often pretty similar now ... the pencil could obviously be
  set alongside the pens on the right. Also on the right, at the bottom corner, there is NEVER anything placed
  there, even though there is space for it"): the packer had kept every chosen thing off the whole stretch beside
  the pad's right and tried snug places on the left alone. What the pen needs there is less: its rest (kept clear
  as a thing is), the lane by the paper where it taps the desk (`TAP_LANE`, 3.5 cm - its tap is 2 cm out), and room
  from anything tall where it leans out and parks (`TALL_RIGHT`, as before). Each thing now leans to a side by the
  seed (`PACK_RIGHT` 0.45; the other side costs it `PACK_SIDE`, 3 cm), its snug tries on both sides, the choice
  among good places looser (`PACK_JITTER` 4.5 cm), long things now and then at an angle (`PACK_ASKEW`), others half
  the time square to the pad. Measured over 24 desks: pencil 11 on the right, eraser 10, tea lights 15, the tag 9,
  23 things in the stretch beside the pad's right; none in the tap lane or on a pen. A dog tag with a run before its
  heap is wider than either strip beside the pad, and the overhang had fallen on its bone: a `THINGS` row's `face`
  (the tag's: its bone) is kept in the frame first, the rest weighed a quarter, and any overhang costs a step
  (`PACK_EDGE`) - the bone wholly in the frame on 16 of 16.
  **Two tea lights had stood in each other** (the user: "the tea lights are clipping through each other"): two tins
  1.6 cm either side of the saucer's middle, 3.2 apart, each 1.9 round; now as far out as keeps every two apart, the
  saucer for two 2 mm wider (`TEA_TIN`; desk_light_check: 416 pairs over 200 saucers). Everything ticked at once leaves the ruler or the books off - said
  in the log ("no room for"). Seen (dist/tag_look/p7, p8): the tag beside the page wide and as it writes. On a
  varnished top the tea lights' light makes a large glare on the desk beside them - their light, not the packing.
- **A dog tag cut as a dog's bone** (2026-10-29, the user: "Exactly like a military-issued tag might be,
  except that the tag needs to be literally dog-bone shaped"): `DeskLook._dog_tag`, only ever chosen (weight 0).
  **The first** was a stamped steel plate with a rolled rim on a ball chain through a hole at one end. **Reworked
  by their picture** (a bone pendant on a girl's necklace: "The chain is connected to the center of the bone, not
  to the side. It has sort of a V-shaped thing attached to the middle of the bone ... The chain itself is true
  chain ... Not tiny spheres ... the edges do not appear to be raised ... simple and flat ... more shiny/polished
  ... the chain needs to be much longer ... the bone hangs to roughly the middle of her chest"): a flat plate,
  3.6-4.4 cm, round lobes and a bar a little over half an end's width, no rim, polished (0.9-0.97); a V bail,
  blunt over the plate and round at its far end, clipped over the middle of the long edge and tipped down to the
  desk; a jump ring; a fine cable chain (1.5 mm links) 76-89 cm long, with its clasp. **Dropped, not looped**
  (the user: "in every seed, the chain has ~3 loops, which are more or less the same shape. But a normal person
  doesn't loop their chain into neat little circles ... They just drop it there, chaotically ... more of a dense
  pile"): `DeskLook._dropped`, a walk of 37 places out of the ring and back - its heading turning smoothly or in
  kinks by drawn amounts, drawn toward a heap's middle (0.9 to 2.2 cm, dense to loose) the further it strays, now
  and then a run pulled out straight first, its last stretch home to the ring, the gap left spread back along it;
  it turns off the bone as it goes, and is dropped again (up to six times) while the curve Props smooths through
  its places still crosses the bone (5 of 24 single drops had) - then drawn again until it is its length.
  **The bail a pointed loop** (the user: "it needs to be a V, a triangle, a pointed loop ... The one in the
  reference connects to the chain via an upside-down V shape"): first a wire triangle, its point 7.5 mm out (the
  blunt V sheet and jump ring before it read as a needle) - then, by the picture again, **a V cast with the bone**
  ("the inner part of the bone is not quite so narrow, and the V-shape is not a separate thing: it is a part of the
  bone itself, as if the entire bone and V were cut from the same cast. The point of the V protrudes roughly as far
  outward as the curve of the bone-knobs do - but the one you're rendering now is almost twice as far"): the bar
  now 0.64-0.72 of an end's width (it had been 0.52-0.6), and out of the middle of its long edge a V in the plate
  itself, its sides straight to a round point (1.7 mm) at the knobs' reach, a 1.5 mm hole in it for the chain -
  then **a V, not a hole** ("2 straight pieces of metal, which make a V ... replace the circular hole with a
  triangular one, which is also larger. The bottom of the triangle should be level with the center of the bone's
  inner side"): two straight struts 0.8 mm wide meeting at a point rounded 0.8 mm, the triangle between them open
  from its apex down to the bar's edge (`TAG_STRUT`; at 1 mm the shortest V's opening was only half again the hole's
  size, at 0.8 at least that on every tag), the chain through it by the apex. The plate is two halves along its axis,
  each the other's mirror with half the opening a notch in it (an extrude has no holes; the first tag's slit-bridged
  hole had been filled now and then); no bevel, or the halves' faces would pull apart at the seam. Where the chain
  goes through the V and over its point it lies on the plate, as it should: the drop's check against the bone leaves
  it out within `TAG_THROUGH` (`_over`). A changed V moves the chain's heap - it is dropped from the V - so a desk's
  layout moves with it. **A name, now and then** (the user: "generate random words to use
  as names, engraved into the dog tag ... must be a name that is generated by the hash function: not something we
  just naively hack into the code ... ~75% of the time - there should be no name on tags at all"; then "just simple
  lettering", like a collar's or an army tag): `DeskLook.tag_name` - one desk in four, its name the tablet's made-up
  syllables (`TabletMedium.made_up`, shared, the tablet's draws unchanged) on a generator of its own salted with
  `TAG_NAME_SALT`, 88283: the first salt from 0 under which desk 4230 - the user's desk for their first video - draws
  a name and draws the one they chose (a search over 88,283 salts, 0.18 s, with `DeskLook._rng` itself). THE NAME IS
  NEVER WRITTEN IN THE CODE (the user: "please do not mention [it] at all ... anywhere we will commit code. It's an
  easter egg"): letter_check holds it by its SHA-256 (`DESK_NAME`). To move it to another desk, search again from 0
  for that desk with the generator's own steps. Engraved as plain capitals with Godot's `Label3D` in its fallback face, dark, flat on the bone, its top
  toward the bail; lifted 0.6 mm off the face (at 0.2 mm the plate drew over it - measured by height). 991 of 4000
  desks named, 977 names.
  **What Props needed:** an extrude cut in meters lost its small corners - Godot's ear clipping weighs each turn
  against a fixed epsilon, and the first tag's hole was filled on 21 of 24 - so `Props._extrude_face` cuts the
  outline at its own unit size (a notched strip: 11 of 80 filled in meters, none now); a small bead and a small
  link were whole 18x32 spheres and 64x12 rings, so a 2.4 mm ball chain stopped half way at the strand's 400k
  corners and a necklace's thousand links would have been millions - `_ball` and `_ring` take a `fine` that goes
  with their size, and a fine chain goes past the 360 links a thick one stops at (default sizes unchanged); and
  **prop.gdshader's metal grain fades past polish 0.7** - its few broad patches of color and roughness clouded a
  4 cm polished face. Looked at (dist/tag_look/q7): polished silver, warm from the room as the bone in their
  picture is, the dark V and the fine chain. A flat mirror facing up shows what is above it - the desk's dark
  background - so it reads silver from the light on it, and a candle close by can glare on it (a seed's call).
- **A sketch stays on the page with what points at it** (`LetterScript._keep_with`): the first look put
  the cross and the dot at a page's foot, so the blind-spot test and "That's me" were a page on, with the
  pen pointing at nothing. A sketch now starts a page of its own when the lines up to its last point (or a
  still after it) would not fit under it.
- **A tap is by the line last written**, on the paper under it or on the desk beside it - where the
  camera is (the first, at the pad's foot, was out of frame).
- **Pointing at the camera holds the pen high and turned off the lens's line**: a camera all but straight
  down has the pen's body running down from the nib, and the first pose (11 cm up) put its top 2 cm into
  the pad. At 16 cm, with more of a turn, its top is about 4.5 cm clear, and the camera stands back.
- **Pictures are painted wide**: a letter hands the painter every image mark pinned `(screen)` (a new
  placement in `Manuscript` and `Illustrations`: landscape, composed to survive a 16:9 crop), where a
  book's `(full)` is a tall page that a widescreen frame would crop to a third. The key is the words', so
  a painting made for a book is found too.
- **A solid dot is a dot of its own size**: figure.py's `<dot r="">` (new) is filled by the pen going
  round it; a filled circle that big was hatched with two strokes and read as a circle struck through -
  for the blind-spot test, the wrong thing. A filled circle is still hatched (a Proof's region).
- **A still is still from its first moment**: the camera heads for the drawing 3.5 s early on quicker
  springs (on its own it was still drifting 15 px three seconds in).
- **A sketch is SVG drawn by an agent** (`rules/letter/sketcher.yaml`) and laid out by the Proof pad's ink
  step (`hosts/math/typeset.py`, figure.py): the same language, reader and hand as a Proof drawing. Each
  part a point names is handed over as an id (`LetterScript.part_id`: "the figure on the bed" ->
  `the-figure-on-the-bed`), and a drawing missing one goes back once. Kept per note in
  `user://letters/<note>-<hash>/` ([LetterSketches]).

## Status

**Built 2026-10-26, a first pass.** Looked at (dist/letter_probe, `tests/desk/letter_look_probe.gd` over
the chapter - its note written as `<!-- still -->` in a copy - with hand-written stand-ins for the three
sketches and a stand-in picture, the voice a steady 0.42 s a word and its hesitations timed): the
cursive, the strike, the picture over the desk, each sketch drawn and pointed at on its own page, the
blind-spot test held dead still with the pen off the pad, both taps, the point at the camera, and the
reply begun on a new page after the last word. The point at the camera is the weakest: the pen raised
and foreshortened over the page, its shadow long, reads as lifted more than as aimed at the viewer. Gates: `tests/desk/letter_check.gd` (the hand,
the format, the turns, the lag, the medium's clock), `tests/letter/letter_card_check.gd` (the row, the
drawer's prompt, what is kept, the walk), `script_marks_check` (the eight marks).

**Not yet tried:** a real agent drawing the chapter's sketches; a painted picture; a real voice and an
export (the end, where "Dear Ink," is written after the last word, waits on the take's final rest being
rendered as silence).

**Open:**

- the tap is seen and not heard: a knock under the voice needs the tap's time, which only the medium's
  plan knows - a `ReadingBed` handed the words' times, or the taps' times written beside the take;
- a thought is said in the voice's own delivery: a hushed or nearer one for the inner voice is one mark
  (`<!-- delivery: hushed -->`) away, or a rule;
- a point at a sketch on a page already turned does nothing (the desk's rule); the camera could turn back;
- the closing ("Godspeed," and the name) is set like any paragraph, not to the right;
- phase two, above.

**The pictures' look is the note's (2026-10-27; the user: "I see style guides for the pictures in the UI,
but not in the markdown ... so that external agents can actually update the style guide").** The card
had shown the Illustrations library's look and kept none of it: the registry tied `illustrations:` to
the Picture alone (its row's `requires`), so the Letter's blocks were `letter:` only. The row now says
what it COMES WITH (`comes_with`: Picture, Letter) and brings nothing - as `requires`, a letter keeping
the block would have been given a Picture - and a note carrying it with neither (chapter 40: a voice
and the look) still has a Picture (`Components.attached_of`). Written with the rest of the note's
settings at the next change, an outside edit read back at the next Play, as a Picture's. The painter
is every card's row now ([AgentPick]: agent, model, effort; `painter_model`, `painter_effort` in the
block), on a Picture's card too. Gates: doc_sync_check (a letter's look into its note and back),
components_check, letter_card_check, illustrations_check.
