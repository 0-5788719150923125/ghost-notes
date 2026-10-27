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

**A hand of its own, no TeX** ([LetterHand], `src/desk/letter_hand.gd`): the Hershey simplex SCRIPT
font (`fonts/hands/hershey/scripts.jhf`, already in the repo for `\mathcal`), a centerline cursive.
Measured on the font: every lowercase letter leaves at its right margin about half way up its body and
most come in at their left margin there, so letters set at their advance join, and a word is one stroke
the pen never lifts from. Where a letter starts elsewhere (a, c, d, g, o, q start their bowl at the top)
a connecting stroke rises to it; dots and crosses (i, j, t, x) are made after the word; digits and the
marks the script font draws doubled come from the simplex roman. Strokes come back in [Ink]'s shape, so
`Ink.schedule` and `Ink.at` time and draw them.

## The marks ([LetterScript], `src/desk/letter_script.gd`; ScriptMarks group "letter")

| Mark | What happens |
|---|---|
| a paragraph | written while it is said, a line at a time, each line a dictation of its own words |
| `*a paragraph in italics, whole*` | a THOUGHT: said, never written; the pen up, the camera eased back |
| `<!-- strike -->` | the paragraph last written crossed out, every line |
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

- **The paragraph after a sketch is its narration, not written.** The pen cannot write and draw at once,
  and the only words to draw under are the next ones. In the chapter every sketch is followed by words
  about it ("A cross, and a dot, on the same line, about a hand apart.") - the drawing is said as it is
  drawn, the desk's rule.
- **The hand writes at a fluent pace** (`LetterHand.PACE` 1.5 of the desk's pen, which is a careful hand
  setting formulas at about 3.3 cm of the page a second; fluent cursive runs 4 to 5). At the desk's pace
  the chapter's ink was 1.9 s a word against a voice at about 0.45 - the voice would have waited nine
  minutes in all.
- **The pen trails the voice, as a hand trails dictation**, by up to `LetterScript.LAG_MOST` (2.5 s) at a
  paragraph's end before the voice waits; a thought, a hesitation or a picture takes the lag back. The
  walk follows the voice and the pen line by line, as the medium's plan does (a paragraph-level guess
  missed every line's return and its words' floor). The chapter: 3,467 spoken words, 15 pages, about 2.8
  times the hand's fluent pace on average, about a minute of rests in all - most of them the 14 page
  turns. Measured on the plan: lines a median 0.28 s behind their words.
- **But the pen is on time for what it does at a moment**: before a strike, a tap, a drawing, an
  unspoken line or a thought it points in, the voice waits until the pen is free (`sync`) - on the plan,
  every point and tap of the chapter starts on its word.
- **A page turns where it runs out, mid-sentence too** (`TURN_REST`, the voice resting at that line's
  first word). The legal pad of the desk, 24 lines to a page, about 230 words.
- **The camera is closer than the desk's** (0.38 m to 0.82): a line of cursive is small. Close on a line
  it sees under half the page, so for what the pen does away from the line - a point at a sketch, a tap -
  it sets off `AWAY_LEAD` (3.5 s) early and frames a little wider; the first look had the pen pointing
  above the frame.
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
- the pictures' look (painter, style, references) is the Illustrations library's, kept on this machine:
  `Components.blocks_of("letter")` does not take the `illustrations:` block into the note as a Picture's
  does;
- phase two, above.
