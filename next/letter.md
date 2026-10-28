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
`DeskLook.dress`: a letter's table spec, written by an agent, in place of the seeded one.

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
| `<!-- sketch: words -->` | drawn by the pen while the paragraph after it is said - that paragraph is the drawing's, never written |
| `<!-- point: sketch -->`, `<!-- point: sketch, the dot -->` | in a thought (or any paragraph the pen is not busy with): at the next word the pen points at the last sketch, or its named part, to the sentence's end |
| `<!-- point: camera -->` | the pen lifted, its nib turned to the lens for the sentence |
| `<!-- tap -->`, `<!-- tap: desk -->` | the pen turned over, its top tapped three times on the pad (or the desk), turned back |
| `<!-- image (full): words -->` ... `<!-- /image -->` | the picture over the whole screen for the passage between, faded in and out, drifting slowly closer and across; the pen writes on unseen |
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

- **The paragraph after a sketch is its narration, not written.** The pen cannot write and draw at once,
  and the only words to draw under are the next ones. In the chapter every sketch is followed by words
  about it ("A cross, and a dot, on the same line, about a hand apart.") - the drawing is said as it is
  drawn, the desk's rule.
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
- **A page turns where it runs out, mid-sentence too** (`TURN_REST`, the voice resting at that line's
  first word). The legal pad of the desk, 24 lines to a page, about 230 words.
- **The camera's arc over a page, gentle** (2026-10-27, the user: "The forward and backward zooming of the
  camera is nauseating. Like the journal and tablet mediums, we really need to dial that behavior back"):
  as the book's and the tablet's, a page opens on the whole pad (`LETTER_WIDE`, 0.85 m), closes in on the
  writing over 9 s once it has come up (`LETTER_LOCAL`, 0.47 m: three fifths of the page's height and all
  its width) and lets go over 9 s, done 7 s before its turn - its springs the tablet's (4.2 s), which run
  about twice their time behind (simulated: a fifth of the way in as the sheet lifts). A turn not planned
  yet is guessed from its first word. Nothing else moves it in or out: a thought, a point at a sketch and a
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
