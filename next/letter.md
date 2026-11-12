# Letter: a letter written by hand at a desk

A letter-writing format akin to the Proof desk: an author writing a letter to someone, read aloud while it is written,
with inner-monologue pauses, inline doodles or full-screen slow-panning images (the voice playing on, the pen writing
on, like a flashback), and pen actions such as tapping the pen's top on the table while the author thinks. It was first
made for the chapter `rift/books/north-star/chapters/43-secular-haze.md`.

**Phase two, not built:** the set dresser's agents populating the desk (things on it, another texture for its top), as
they do the card table ([cards.md](cards.md), `Tables`, `Props`). The desk is already built from those parts
([DeskLook], from the seed), so the seam is `DeskLook.dress`: a letter's table spec, written by an agent, in place of
the seeded one. Its light is built and seeded in the table's own words, so an agent can write it later: below, "The desk
is lit as the card table is".

## What it is

**A format of the Medium card, `letter`**, picked on a reading's Medium card, the note's `medium:` block saying
`format: letter`. **The note's words are the letter, word for word**: no agent writes it. Its own rows on the Medium card
([LetterFormat], `src/letter/`) draw the sketches and hand the reading the letter with the pen's rests in it
([LetterWalk]) and the document a render draws from ([LetterFormat.Publish]); the format is the Director's medium, set
from the block and never pinned. Its pictures are painted on the note's Pictures card, which comes with the Medium
(next/pictures.md; [LetterMedium] `pictures_in` says which marks they are: never a sketch).

**A medium, `letter`** ([LetterMedium], `src/desk/letter.gd`): the Proof desk's ([DeskMedium]) pad, pen, lamp, camera, the
voice followed word by word and the elastic pen, with the letter's own hand and moments. Its parts are the desk's; the
hooks it needed are small and the desk's behavior is unchanged (`_end_fade`, `_ended`, `_travel`,
`_wide_frame`/`_local_frame`, `_wander_time`).

**The journal's hands, written by the pen, no TeX** ([LetterHand], `src/desk/letter_hand.gd`): Kalam (the default),
Caveat or Patrick Hand - the Notebook's ([NotebookLayout]) at its sizes - picked on the Medium card's Handwriting row,
which the Notebook shares, and kept in the block (`hand`; Random is drawn from the note's own number). An outline font is
a shape to fill, so each is traced once into the lines a pen draws it with (`scripts/hand_strokes.py`, numpy and Pillow, a
development tool): every printable ASCII character rendered at 400 px an em, thinned to its centerline (Zhang-Suen), cut
where it branches (two junctions closer than a stroke's width are one crossing, the stubs thinning leaves at a corner are
dropped) and walked into strokes as a hand writes: from the top left, on through a branch the way the line was going,
lifting at a turn sharper than 110 degrees, a line begun at its tail turned round (an a, an e, a g), a ring from its top
counterclockwise, a dot (an i's, a period) last as a small spiral. They are kept in Hershey's own format
(`fonts/hands/strokes/*.jhf`, which [Ink] reads and the export ships with the plotter fonts); what the format cannot hold
(units to the em, the baseline, the reach, the nib) is the tracer's printed row in `LetterHand.HANDS`. Drawn with a round
nib as wide as the font's own stroke (its ink over its centerline's length), the page is the font. It is a print hand: the
pen lifts between letters. (Not the Hershey simplex script font: its joined centerline cursive is thin and spindly at the
letter's close camera.)

## The marks ([LetterScript], `src/desk/letter_script.gd`; ScriptMarks group "letter")

| Mark | What happens |
|---|---|
| a paragraph | written while it is said, a line at a time, each line a dictation of its own words |
| `*a paragraph in italics, whole*` | a thought: said, never written; the pen up, the camera eased back |
| `<!-- strike -->`, `<!-- strike: 5 -->` | the writer stops to decide (3 s, or the mark's own seconds), the pen still, then crosses out the paragraph last written, every line |
| `like <!-- struck: morning --> mourning` | words struck inside a line: written and said, a rest, the pen crosses out those words alone and the rest of the paragraph goes on beside them |
| `<!-- unspoken: Dear Ink, -->` | written, never said; the voice waits (inside a line, the words are written and none of it said) |
| `<!-- sketch: words -->` | drawn by the pen at the mark's place: words before it are written and said, then the drawing, then what comes after; the voice waits for the pen before the next written words and is silent while it draws |
| `<!-- point: sketch -->`, `<!-- point: sketch, the dot -->` | in a thought (or any paragraph the pen is not busy with): at the next word the pen points at the last sketch, or its named part, to the sentence's end, then lingers |
| `<!-- point: camera -->` | the pen lifted, its nib turned to the lens for the sentence |
| `<!-- tap -->`, `<!-- tap: desk -->` | the pen turned over, its top tapped three times on the pad (or the desk), turned back |
| `<!-- image (full): words -->` ... `<!-- /image -->` | the picture over the whole screen for the passage between, faded in and out over 2.5 s, each moving its own way (closer, back, across); the pen writes on unseen. Another image mark before the close, or straight after it, dissolves into its picture - the page not seen between |
| `<!-- still -->` | to the next written line: the camera dead still on the last sketch, the pen off the pad |
| `<!-- new page -->` | the next writing starts a page of its own |
| `<!-- color: red -->`, `<!-- color: default -->` | a change of pen: each ink named is its own pen on the desk, put down and picked up |

Hesitations, deliveries and speakers pass to the voice; any other comment is a note. A chapter's `<!-- note: ... -->` is a
note and does nothing: the behavior it describes is written as `<!-- still -->`.

## Decisions, and what was measured

- **No indent; a rule left empty between paragraphs** (the book's rule, `BookLayout` `INDENT_EM` 0). A paragraph after a
  sketch keeps the sketch's own spacing; a sketch kept with the lines that point at it counts their empty rules
  (`_keep_with`). A rule is left empty under every drawing (`LetterScript.UNDER_SKETCH`).
- **The writer decides before striking**: the voice and the pen both done, the pen held still over the line
  `LetterScript.DECIDE` (3 s) or the mark's own number, then the strike; the voice rests through both (`decide` on the
  action, `DeskMedium._build_plan`).
- **A picture clears before the letter goes on**: it fades out from 0.1 s after its passage's last word over 1.2 s, and
  the voice rests until it is gone, so the next thing the pen does is seen from its start.
- **Pictures dissolve into one another; every fade is 2.5 s.** A picture whose passage begins where the last one's ends
  (its mark before that one's `/image`, or straight after it) is its span's `blend`: it comes up over the one before, held
  whole under it until it is in, the voice reading on with no rest for the page (`LetterMedium.pictures_at`, the plate
  drawing them bottom first, `cover_of`). Each picture takes a move of `LetterMedium.MOVES` (closer, back, across) by the
  seed, never the one before's, drifting at least a quarter turn from its way (`moves_of`). `LetterScript.IMAGE_FADE` is
  1.2 to 2.5 s for every fade, so the rest the voice takes for the page to come back is 2.6 s.
- **A page turned inside a paragraph is read on through** (`LetterScript._voice_text`'s `turned_in`: no wait at the turn
  nor after it in that paragraph); the page still turns once the voice has said its last word, and the pen comes back
  behind the voice, catching up at the next paragraph, where the voice waits for it if it must. A turn between two
  paragraphs is still rested for.
- **A page turns where it runs out, mid-sentence too.** The legal pad of the desk is 24 lines to a page, about 230 words.
  The voice rests for the turn (`TURN_REST` and the pen's first words) between two paragraphs, and inside one only where
  the page ends on a mark (`LetterScript.PAUSE_END`: a stop, a comma, a semicolon, a colon, a dash). A sentence the page
  breaks is read on to its end, and the voice waits for the pen at the next sentence. The words said before a line begins
  are written at the pen's quickest (`LetterMedium._ahead_times`). Over a 20-turn chapter: after a mark, about 4 s rested;
  a broken sentence, 3.5 to 4.3 s at the next sentence; the pen never past 2.5 times the hand's pace over the page seen.
- **The desk is lit as the card table is.** The Desk number is the seed of the desk's whole look. Each desk has a mood
  (`DeskLook.MOODS`): lamplight (the lamp, a dark room - a screen's glow, a street lamp, a fire or the moon in a window),
  candlelight (the lamp off, one to three candles on the desk, the one that lights the page most the key), daylight (the
  sun through a window across the desk, clouds now and then) and dusk (a low gold sun through it, the lamp part on). The
  room's light is a `Lights` spec written as the set dresser writes a table's and built by `Lights.build` on the desk's
  stage, fitted to the paper; the candles are `Props` things with wicks, their flames the table's (`TableLight`'s flame
  quad, flicker and filtered shadow, made static for any host), each held to what the page can take
  (`DeskLight.PAGE_HEAT`) and turned to face a camera that looks nearly straight down. A fine diagonal moire on the page
  came from the lamp's shadow map having only 512 texels of the stage's default atlas; the desk sets the card table's
  stage (`TableMedium.STAGE`: 8192, a quadrant of its own for the lamp, debanding, 4x MSAA) and gives it back as it
  leaves. The Proof desk takes all of it too.
- **The desk is drawn only as it changes.** Measured on a chapter, frame by frame at the viewer's rate (by the thread's own
  processor time, under a real renderer):
  - Both page viewports were `UPDATE_ALWAYS` (a page of handwriting is about 2,100 draw calls, 1.9 ms of the main thread a
    frame). Now a page's finished ink is a viewport of its own inside the page, rendered as a line is finished; the page
    under the line being written is rendered as the pen moves; the turning page once a turn (0.2 ms, about 130 draw calls).
    Read back across four lines' ends, no frame loses a line.
  - A line's end rebuilt the whole page's ink point by point (a 20 to 35 ms frame). Now a finished action's ink is made once
    (`DeskMedium._done_ink_of`) and moved onto the page in one native step (`Transform2D * PackedVector2Array`); the line
    being written costs 0.2 ms.
  - Every frame walked every action a dozen times. Now the actions are indexed by page, kind and turn once a letter is laid
    out (`_page_actions`, `_of_kind`, `_turn_actions`), the pages and each line's ink time are kept for the moment and the
    plan (`_plan_rev`), the pen's walk goes on from where it found all done, and the follower keeps its last known word:
    the script's frame went from about 3.3 ms (34 ms spikes) to about 1.3 ms.
  - A live reading made its plan again as each sentence's words arrived, overwriting finished actions with what was kept;
    now they are kept: 9.9 ms to 2.0 three quarters in.
  What is left: the desk's 3D (0.4 ms of the main thread, 2.4 ms of the card), its shadows (about 1 ms), and the voice
  host, which synthesizes ahead on every core but one while the reading plays. letter_check holds each fix as a share of its
  control.
- **A dense sketch is dashed off.** A sketch with more ink than its words leave time for is drawn quicker, up to
  `LetterScript.DRAW_QUICKEST` (7) times the hand's pace, to be done `DRAW_TAIL` (1.5 s) after them (`draw_pace`): the
  voice's rest is sized by it and the desk draws to it (`LetterMedium._paced_end`), filling to the next line as before. A
  sketch with room keeps its pace. Without this, a tree of dots with 47.5 s of ink ran 6.5 s past its 13 words and the voice
  waited on the pen.
- **A sketch is drawn where its mark is.** The letter goes in its order: words before the mark written and said, the
  drawing, then what comes after. A thought right after the mark with no point in it is thought while the drawing is made,
  the drawing paced across its words (`draw_pace`); one with a point waits for the drawing. **A drawing alone is dashed
  off:** with no words over it, it is drawn in `DRAW_ALONE` (5 s), or at the hand's pace if that is sooner, never quicker
  than `DRAW_QUICKEST` (`LetterScript.drawn_alone`: the voice's rest and the desk's end both read it). A live reading holds
  the letter's own quickest while a drawing is under way (`DeskMedium._quickest`), never the desk's.
- **The camera catches on a drawing.** `LetterMedium._caught`: from `AWAY_LEAD` before the pen begins a drawing the camera
  is close and holds it at the frame's middle (as high as `CATCH_TOP` of the page) while the line written under it is
  within `CATCH_LOW` (360 px; close, the frame sees about 425 either side), on springs `CATCH_SPRING` of its own; then it
  lets go to exactly where it would be with no drawing. A page that opens on a drawing brings the camera in from the turn's
  middle to `CATCH_IN` after it, and the pen waits `LetterScript.DRAW_SETTLE` (1.5 s, the action's `settle`, read by the
  desk's plan and the voice's rests). It lets go slowly: what it aims at goes from the drawing toward the writing at most
  `LET_GO` (30) a second, easing up over `LET_GO_EASE` (2 s), from `LET_GO_LEAD` (3 s) before the line that lets it go, a
  function of the plan and the time as every framing is. Simulated on a chapter: 30 px a second at most, the line written at
  most 325 px under the frame's middle. Not capped: the swing to a point's target and back (90-100 px a second there).
- **The pen writes two words ahead of the voice.** Each word is written while the voice says the one `AHEAD_WORDS` (2) before
  it: the desk's elastic dictation on the voice's own times, so at any voice's speed (`LetterMedium._due`, `_ahead_times`,
  `_paced_end`, `_share`), never quicker than `QUICKEST` (2.5) times the hand's pace. The voice waits only where the pen
  cannot be two words ahead: a paragraph after a thought, a still or the blank page, for its first two words (the line's
  `gate` "voice" and `gate_rest`, the pen beginning as the voice gets there); a page turn, once the voice has read the page
  ("turn"); and a run of words far longer in ink than in speech. Not X: a pen paced to a fixed hand speed makes the voice
  wait out the difference at every sentence, whatever lead is asked for, and keeping the pen with the voice word for word
  writes too fast to read. Measured on a chapter: 28.3 minutes on a voice of 0.45 s a word, 23.1 on 0.36, 1.8 minutes of
  rests in all (24 inside a paragraph, mostly turns); the pen 1.2 to 1.4 words ahead as each word is finished, 7% of words
  said a moment before they are finished at 0.45 s a word. Under a picture the desk's own dictation runs unseen.
- **The subtitles caption only what cannot be read on the page**: a line is drawn while a picture covers the screen, or when
  any word of it is not written - a thought, one said while a sketch is drawn (`LetterMedium._captioned`, handed the overlay
  as `Subtitles.captions`, a hook any medium may set; the line eases out and in as any does). A passage under a picture with
  no painting is read over the desk, and not captioned.
- **The writer hesitates too.** A hesitation, on a line of its own or inside a written line (`LetterScript.parse`'s
  `pauses`), stops the pen after the word before it, and the pen is taken up again `RESUME_LEAD` (0.9 s) before the voice
  goes on (`LetterMedium._resume_floor`). Only hesitations: an `action-hold` is often the voice waiting for the pen, and
  stopping the pen there would lengthen it.
- **A hesitation before a picture is the writer's first.** A picture whose mark a hesitation stands before
  (`after_hesitation` on its span) comes up as the pen is taken up again, `RESUME_LEAD` before its first word
  (`LetterMedium._comes_up`), the desk seen through the pause; one dissolved from is held whole through it, and a live
  reading not yet past the pause keeps the desk. Gate: letter_check.
- **A point lingers.** A point in a thought, at a sketch or at the camera carries `linger` (`LetterScript.POINT_LINGER`,
  3 s): the voice rests that long after its sentence (at the next sentence, or after the paragraph), the desk holds the pen
  on its target through it (desk.gd's point plan, `linger` on the action - Proof's points carry none), the camera stays on a
  point under way rather than setting off for what comes next (`_framing`), and a point at the camera holds the pen up
  through its rest (`_camera_until`). Gate: letter_check.
- **Words struck inside a line.** The struck words are the paragraph's, written and said (as a struck paragraph is said);
  the paragraph is cut after them into parts (`_marked`, a cut `{at, struck, ink}`): the voice reads the first part, rests
  `DECIDE` and the strike, the pen crosses out those words alone (a strike's `x0`, `x1` along its line -
  `DeskMedium._struck_line`), and the next part goes on beside them on the same rule (`cont`, `cont_x`; `lay_out`), or at the
  margin if its first word will not fit. A run over a line's end is crossed out on each line. Words written and never said
  inside a line use the unspoken mark there (`UNSAID`, kept between two characters no script holds): written, none of it
  said, the closing marks it ends on left to the voice (`_voiced`: `<!-- unspoken: mourning. -->` still ends the sentence),
  and a part with nothing in it to say rests the voice while it is written (`_voice_part`).
- **A pen each ink.** `LetterScript.pens_of` scans the letter first - the desk's own pen, then each ink named
  (`NotebookLayout.INKS`, a hex color; `default` the desk's) - and `LetterMedium._lay_pens` lays a pen for each past the
  first beside it, further out (`DeskLook.PEN_APART`, the desk's things kept off them all), its body lacquered in its ink. A
  change of ink is a `swap` action (`LetterScript.SWAP`: the pen in hand put down at its place over 1 s - the opening
  pick-up run back, `_lift` - and the other picked up over 1.6), the voice resting through it; a change on a line of its own
  waits for the next thing written, one inside a written line cuts it there as struck words do (a strike then a change:
  crossed out with the old pen, the correction in the new), and one inside a word splits it with no space (`GLUE`). Every
  line, strike and sketch carries its pen's ink, and the canvas draws each stroke in it. Gate: letter_check `_pens`,
  `_struck`; script_marks_check. Not yet seen rendered.
- **A line runs on into the voice's pause after it.** A line ends as the voice ends the word two before its last, and the
  next begins as the voice begins the word two before its first. So where a sentence ends two words before a line's end, the
  line is written on into the voice's pause, done as the nib must leave for the next (`LetterMedium._runs_on_to`), never
  across a hesitation, where the writer stops too.
- **The camera's arc over a page, gentle.** As the book's and the tablet's: a page opens on the whole pad (`LETTER_WIDE`,
  0.85 m), closes in on the writing over 9 s once it has come up (`LETTER_LOCAL`, 0.47 m: three fifths of the page's height
  and all its width) and lets go over 9 s, done 7 s before its turn, on the tablet's springs (4.2 s). A turn not planned yet
  is guessed from its first word, and once the camera has begun to let go for it, it lets go for the soonest guess yet:
  `LetterMedium._letting_go` keeps the soonest, and `_turn_guess` paces the guess on the voice's own last 40 words and the
  rests the script writes (`rests_of`), because a live reading's words arrive a sentence at a time and a guess at a steady
  0.33 s a word ran early and moved later with each sentence, bouncing the camera in twice as it let go. Nothing else moves
  it in or out: a thought, a point at a sketch and a tap move where it looks, never how close; only a point at the camera
  stands it back (`CAMERA_K` 0.7, a fifth further), and a still holds close on its drawing. Across, it holds the column's
  middle. For what the pen does away from the line it still sets off `AWAY_LEAD` (3.5 s) early. Not X: a deeper arc (1.45 m
  to 0.38 m, all the way out before each turn, a 70% step back for every thought) is nauseating.
- **The page lies blank a moment first**: the voice opens on a rest of `LetterScript.BLANK_PAGE` (4 s), nothing is written
  before it (`DeskMedium._blank`, a hook: none at the Proof desk), and the camera comes in over the empty pad.
- **The pen is picked up from the desk.** It lies beside the pad's right edge, its top toward the writer and turned out 4 to
  16 degrees (`DeskLook.pen_rest`, seeded; `dress` sets nothing down there), through the intro and its focus pull; 1.5 s
  after the opening it is lifted by its grip, turned up into the hand and carried over the pad's edge in an arc, over 2.2 s,
  to hover over the first stroke as the blank page ends (`LetterMedium._pick_up_pose`, laid over the desk's `_pen_xf`; at
  most 4 mm a frame, its nib never into the desk or the pad). The Proof desk's pen's first stroke comes with the first word.
- **The pen leans to the right and a little down as it writes**: back over the hand toward the writer's right shoulder, as a
  right hand holds one, seen from the camera on the writer's side (`LetterMedium.LEAN` through the desk's `_pen_up` hook: 48
  degrees up from the nib, 30 degrees toward the writer from straight right - on the screen 14 degrees under the level on
  average, 3 to 31 with the forearm's turn and the hand's sway). Its body lies over the paper not yet written. The Proof
  desk keeps its own lean, and the pen lies on the desk top toward the writer as it is picked up.
- **What is on the desk and its light are chosen; the number only places them.** The Letter's "On the desk" bank is a tick
  for each `DeskLook.THINGS` row (the mat and the candles among them), and a Light row holds the moods. Chosen (`DeskLook.of`'s
  picks: the block's `things` and `mood`), each thing is drawn from a generator of its own kind and placed by it, so another
  seed moves and recolors them and ticking another changes nothing about how the rest look; until chosen they are what the
  number drew, and the first change of anything on the desk keeps them (`LetterFormat._hold_desk`). A candlelit desk given
  no candle gets a taper, since its page would have no light. Ticked while the letter plays, the desk is dressed again at
  once, the letter untouched (`LetterMedium._set_desk`). **The number is the desk's alone**: the hand's seed is the note's
  own (the document's `seed`, `LetterFormat.hand_seed`) and the number the desk's (`desk`, [LetterMedium]'s `_seed`; `_hand`
  the hand's), so a number changed while it plays dresses the desk again at once and never changes where lines break or the
  rests the voice takes ([LetterWalk]). The Hand row still waits for a Play.
  **Measured: the camera sees little of the desk.** The lens is 20 degrees high: at 0.85 m the widest framing, its corners
  cast onto the desk, sees 56 cm across at the binding and 52 at its foot, 31 deep (`DeskLook.SEEN`), where `REACH`, the
  stretch the wide camera sees, is 90 by 62; close, as the pen writes (0.47 m, following the line down the page), it sees 4
  cm past the pad's sides.
  **A chosen desk is packed in to the paper.** `DeskLook._pack` tries each thing at 160 places, three in four snug against
  the pad's left, and sets it where it is closest to the paper and most in the wide frame (a share out of `SEEN` weighs 0.4
  m), its footprint its own turned rectangle, a long thing along the pad. Flat things first, smallest first; then what
  stands, kept back from the pad; the candles last, nearest their band. The pad's right edge is the pen's (it rests there,
  taps the desk 2 cm out and parks off the top right). What the pen needs on the right is less than the whole stretch: its
  rest (kept clear as a thing is), the lane by the paper where it taps (`TAP_LANE`, 3.5 cm), and room from anything tall
  where it leans out and parks (`TALL_RIGHT`). Each thing leans to a side by the seed (`PACK_RIGHT` 0.45; the other side
  costs it `PACK_SIDE`, 3 cm), its snug tries on both sides, the choice among good places is looser (`PACK_JITTER` 4.5 cm),
  long things now and then at an angle (`PACK_ASKEW`), others half the time square to the pad. A `THINGS` row's `face` (the
  dog tag's: its bone) is kept in the frame first, the rest weighed a quarter, and any overhang costs a step (`PACK_EDGE`).
  **Candles on both sides**: each candle takes a side by turns from a seeded first (`DeskLook._candle_right`), drawn desks
  and chosen alike; the right's band (`CANDLE_RIGHT`) stands past the stretch the pen keeps, at the frame's edge or past it,
  so light crosses the page from both directions. Two tea lights are kept apart (`TEA_TIN`; desk_light_check: 416 pairs over
  200 saucers). Measured: the tag within 4 cm of the paper and in the wide frame on 16 of 16 seeds; a crowded desk of nine,
  59 of 60 flat things in the frame and 0 of 36 candles; 48 of 95 candles on the right over 60 candlelit desks, every desk
  of two lit from both; over 24 desks things on the right of the pad in every kind, none in the tap lane or on a pen.
  Dressing a desk of nine takes about 0.4 s. Everything ticked at once leaves the ruler or the books off, said in the log
  ("no room for"). On a varnished top the tea lights' light makes a large glare on the desk beside them: their light, not
  the packing.
- **A dog tag cut as a dog's bone** (`DeskLook._dog_tag`, only ever chosen, weight 0). A flat polished plate (0.9-0.97),
  3.6-4.4 cm, round lobes and a bar 0.64-0.72 of an end's width, no rim. The bail is a V cast with the bone: out of the
  middle of the plate's long edge, two straight struts 0.8 mm wide meeting at a point rounded 0.8 mm at the knobs' reach, the
  triangle between them open from its apex down to the bar's edge (`TAG_STRUT`), the chain through it by the apex. The plate
  is two halves along its axis, each the other's mirror with half the opening a notch in it (an extrude has no holes), with no
  bevel, or the halves' faces would pull apart at the seam. The chain is a fine cable chain (1.5 mm links), 76-89 cm long,
  with its clasp, **dropped, not looped**: `DeskLook._dropped`, a walk of 37 places out of the ring and back, its heading
  turning smoothly or in kinks by drawn amounts, drawn toward a heap's middle (0.9 to 2.2 cm, dense to loose) the further it
  strays, now and then a run pulled out straight first, its last stretch home to the ring; it turns off the bone as it goes,
  and is dropped again (up to six times) while the curve `Props` smooths through its places still crosses the bone. Where the
  chain goes through the V and over its point it lies on the plate: the drop's check leaves it out within `TAG_THROUGH`
  (`_over`). **A name, now and then:** `DeskLook.tag_name` - one desk in four, its name the tablet's made-up syllables
  (`TabletMedium.made_up`, shared) on a generator of its own salted with `TAG_NAME_SALT` (88283). The name is an easter egg
  and is never written in the code: letter_check holds it by its SHA-256 (`DESK_NAME`); to move it to another desk, search
  again from 0 for that desk with the generator's own steps. It is engraved as plain capitals with Godot's `Label3D` in its
  fallback face, dark, flat on the bone, its top toward the bail, lifted 0.6 mm off the face (at 0.2 mm the plate drew over
  it). **What Props needed:** `Props._extrude_face` cuts the outline at its own unit size, because Godot's ear clipping weighs
  each turn against a fixed epsilon and a notched strip cut in meters lost its small corners; `_ball` and `_ring` take a `fine`
  that goes with their size (a small bead is no longer a whole 18x32 sphere), and a fine chain goes past the 360 links a thick
  one stops at; and prop.gdshader's metal grain fades past polish 0.7, since its few broad patches clouded a 4 cm polished
  face. A flat mirror facing up shows the desk's dark background, so it reads silver from the light on it, and a candle close
  by can glare on it.
- **Words on the index cards**: the `letter` block's `card_text`, a box under the desk's bank shown while Index cards is
  ticked (typing holds the desk, as any change does, and a playing letter's desk takes the words once they rest 0.6 s,
  `CARD_SETTLE`). `DeskLook._write` writes it on the top card or sticky note with Godot's `Label3D`, in the letter's hand (the
  Notebook's font) and the desk's ink, from the top left inside an 8 mm margin. Nothing on the desk moves for it: the stack
  is the one the number drew, where it drew it, and the writing takes the quarter turn on it nearest upright from the
  writer's seat - down a card lying along the pad (portrait), across the rest; letter_check holds every thing on 24 desks
  where it lay unwritten. As the pad is written: the hand's own size on a pixel of the pad's page, its lines a rule apart; a
  line too long for the card (portrait, a sticky note) makes it smaller, to 0.7 of that, before it is wrapped, and more lines
  than the card holds smaller again. Rastered at 96 px, the font's thin strokes would be averaged by mipmaps into a pale tint
  from across the desk.
- **A sketch stays on the page with what points at it** (`LetterScript._keep_with`): a sketch starts a page of its own when
  the lines up to its last point (or a still after it) would not fit under it.
- **A tap is by the line last written**, on the paper under it or on the desk beside it, where the camera is.
- **Pointing at the camera holds the pen high and turned off the lens's line**: a camera all but straight down has the pen's
  body running down from the nib. At 16 cm up, with a turn, its top is about 4.5 cm clear of the pad, and the camera stands
  back.
- **Pictures are painted wide**: a letter hands the painter every image mark pinned `(screen)` (a placement in `Manuscript`
  and `Illustrations`: landscape, composed to survive a 16:9 crop), where a book's `(full)` is a tall page that a widescreen
  frame would crop to a third. The key is the words', so a painting made for a book is found too.
- **A solid dot is a dot of its own size**: figure.py's `<dot r="">` is filled by the pen going round it; a filled circle that
  size is hatched with two strokes and reads as a circle struck through. A filled circle is still hatched (a Proof's region).
- **A still is still from its first moment**: the camera heads for the drawing 3.5 s early on quicker springs.
- **A sketch is SVG drawn by an agent** (`rules/letter/sketcher.yaml`) and laid out by the Proof pad's ink step
  (`hosts/math/typeset.py`, figure.py): the same language, reader and hand as a Proof drawing. Each part a point names is
  handed over as an id (`LetterScript.part_id`: "the figure on the bed" -> `the-figure-on-the-bed`), and a drawing missing
  one goes back once. Kept per note in `user://letters/<note>-<hash>/` ([LetterSketches]).

## Status

**Built.** Looked at (`tests/desk/letter_look_probe.gd` over the chapter - its note written as `<!-- still -->` in a copy -
with hand-written stand-ins for the three sketches and a stand-in picture, the voice a steady 0.42 s a word and its
hesitations timed): the cursive, the strike, the picture over the desk, each sketch drawn and pointed at on its own page,
the blind-spot test held dead still with the pen off the pad, both taps, the point at the camera, and the reply begun on a
new page after the last word. The point at the camera is the weakest: the pen raised and foreshortened over the page, its
shadow long, reads as lifted more than as aimed at the viewer. Gates: `tests/desk/letter_check.gd` (the hand, the format, the
turns, the lag, the medium's clock), `tests/letter/letter_format_check.gd` (the row, the drawer's prompt, what is kept, the
walk), `script_marks_check` (the marks).

**Not yet tried:** a real agent drawing the chapter's sketches; a painted picture; a real voice and an export (the end,
where "Dear Ink," is written after the last word, waits on the take's final rest being rendered as silence).

**Open:**

- the tap is seen and not heard: a knock under the voice needs the tap's time, which only the medium's plan knows - a
  `ReadingBed` handed the words' times, or the taps' times written beside the take;
- a thought is said in the voice's own delivery: a hushed or nearer one for the inner voice is one mark
  (`<!-- delivery: hushed -->`) away, or a rule;
- a point at a sketch on a page already turned does nothing (the desk's rule); the camera could turn back;
- the closing ("Godspeed," and the name) is set like any paragraph, not to the right;
- phase two, above.

**The pictures' look is the note's.** The Picture card's style guides live in the note's markdown, so external agents can
update them. The registry row says what the Letter's `illustrations:` block comes with (`comes_with`: Picture, Letter) and
brings nothing, as `requires` would have given a letter keeping the block a Picture; a note carrying it with neither still
has a Picture (`Components.attached_of`). It is written with the rest of the note's settings at the next change, an outside
edit read back at the next Play, as a Picture's. The painter is every card's row ([AgentPick]: agent, model, effort;
`painter_model`, `painter_effort` in the block), on a Picture's card too. Gates: doc_sync_check (a letter's look into its note
and back), components_check, letter_card_check, illustrations_check.
