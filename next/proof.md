# Proof: a mathematician at a desk, thinking out loud

## Status: Proof became a table show

The Proof component is gone. A lesson is a brief the Table component plays, as bricks, puzzles, a painted mask
and a tabletop game are: the show is `~/repos/rift/animations/theorem-grooving.md`, which carries the channel's
voice and YouTube settings; the teacher's, the student's and the framer's rules became its prose. The tools that
Proof needed moved down into the table for any show to use.

**What moved down into the table:**

- **Work a computer checks.** A `problem` in the producer's plan (`SolverTools.land_problem`,
  rules/table/producer.yaml `problem`) makes a `solve` step before the table is set. The solver (`SolverTools`,
  rules/table/solver.yaml) keeps a lab notebook, checks Lean files, runs sandboxed Python and hands in a
  verified proof or a computed result, retried and landed honestly unchecked after that. The puppeteer and
  every reader are handed what it found (`TableProducer._plan`'s `worked`, `table/solver.worked`), and the
  upload says what checked it (`SolverTools.check_line`). Held by `tests/table_show/solve_step_check.gd`.
- **Math on a page.** The `write` law takes `tex` (a formula) and `draw` (an SVG in figure.py's words: axes,
  curves computed from their expressions, series a run kept) beside `text`, and words with `$...$` in them.
  Several writes on one sheet are a page, one under another at one size (`SheetWriting.page`), each written
  stroke by stroke in the Hershey hand from TeX's own layout (`TableInk`), in the reading's order
  (`TableWork._order_writing`); a page that runs off its sheet is written smaller and says so. A write's
  `strike` crosses an earlier line out (`SheetWriting._strike`), for a dead end the notebook records. The `ink`
  step lays it out with TeX once the acts are blocked. The puppeteer is told the drawing language where the
  table has a sheet (rules/table/puppeteer.yaml `drawings`). Held by `tests/table/page_writing_check.gd` and
  `tests/table/ink_check.gd`.
- **The solver writes a worked solution, never a record of its tries** (2026-11-12): theorem-grooving's solver was refused
  by the safeguard on every run. Bisected on the job's own prompts with capped CLI runs, the brief, the direction and the
  request each passed alone; it was refused only with the solver framed as a video's team member and asked for "the
  attempts that did not work", "what you try, what each attempt gives", "what you notice and guess" - Proof's own wording,
  which passed in October. Reframed, the user's idea ("closer to 'show your work'"), as a worked solution about the
  mathematics (rules/table/solver.yaml, "A WORKED SOLUTION"): the same prompt otherwise, run once, went straight to work.
  An age line ("Younger students are among them") had also reached the direction and the plan; audiences are now said by
  what people know, never by age.
- **No notation in what is said.** A reader's passage with TeX in its words is sent back once
  (`TableProducer.notation_in`), and `[a]` is kept as the letter's name (`clean_spoken`).
- **A pen seen, and pointing.** A `write` may name a pen on the table (`with`): its nib follows the page layout
  and hand schedule the ink is drawn from (`TableWork._pen_nib`), coming down in the write's lead, on each stroke,
  4 mm up between strokes and 2.2 cm clear in its tail, held by its tip and grip as any tool is
  (`TablePaint.tool_of`, found once at build so the bake's twin never reads its nodes), leaning to the frame's
  top right (`PEN_UP`). The `point` law sends a pen to something written - a formula's `\pin{name}{...}`, a
  drawing element's `id`, or the act that wrote the line (`_find_pointed`) - sweeping under a wide thing and
  settling beside its end, 3.5 mm over the paper (`_point_nib`). The puppeteer blocks point acts and the reader
  starts each at its word (`<!-- act: name -->`); the brief asks for the pen to point whenever something written
  is talked about. Pointing directs the viewer's attention. Held by `tests/table/page_writing_check.gd`.

**What did not come over:** from the desk, the elastic pen's tie to the voice word by word (a write here runs over
its act's seconds, started at its word), parking far off the pad in a long stretch of talk, the legal pad's curled
page turn and the camera's stations; and the student's review pass, whose place is now Ink's questions in the
brief. A full sheet is put aside by an act rather than turned over a binding. `DeskMedium` stays as the base Letter
is written at.

**The author still has to judge:** a first lesson made at the table and watched - whether the camera at the host's
chair reads the page (on the made desk a line of writing is about 9 mm tall), whether the pen points often enough,
and whether the brief (Pen teaching, Ink asking) holds the teaching as the old rules did. Ink's voice (speaker 3 of
the LibriTTS voice) is a placeholder.

The rest of this note is the design of Proof as it was built, kept because its reasons still stand behind the
primitives above.

The idea: a show in which an actor sits at a desk with a pad of paper, writes equations, looks things up on a
tablet, works numbers on a calculator and checks a proof in Lean, narrating all of it to teach a hard idea to
someone who knows little math. LaTeX is the common language of the writing, Lean the industry's proof checker, and
the voice is a teacher and a researcher at once: the technical research is the artifact, the teacher is the
process. Exports first; live streams of an AI working a problem later, so the design does not close that door.
The writer is unseen (the pen moves by itself), the first episodes are classic theorems the agents can really solve
and check, and every dependency is a standalone install ghost fetches and keeps current itself, the way FFmpeg and
uv are - a system package is never installed by an agent, only handed to the author as a command.

## The verdict

A good fit, for three checked reasons:

- **The machine is mostly built.** Cards (now Table) already makes a show the way this one is made: agents plan,
  write and act through ghost's own MCP tools, one file per step, a redo a delete, a medium that is a pure function
  of the episode and the show's time, and a voice that reads what the agents wrote. The tablet already turns marks
  in a script into actions and rests in the voice from one walk. What was missing is ink, a desk and the two
  toolchains.
- **The hardest visual problem is solved on paper.** A spike laid twelve formulas out with TeX and wrote them in a
  seeded hand: fractions, radicals, limits, matrices, `align*`, prose with inline math, in 2.5 s for all twelve,
  every glyph covered ([Ink](#ink)).
- **The material exists.** `github.com/openai/math` (Apache-2.0) holds 719 manuscripts in 372 families, LaTeX
  sources and PDFs, and a Lean library pinned to Lean v4.34.1 covering about 42% of the top-line results. Some
  manuscripts were withdrawn over a sign error, a reminder of why the check on screen matters.

Not verified: that nobody combines an AI working a problem at a desk, narrated as a lesson, with the formal check
on screen.

## What a viewer sees

A desk under a lamp: a legal pad, a pen, a tablet, a calculator, a small screen. Nobody is in the chair. The pen
lifts and writes by itself, the calculator's keys go down, the tablet's pages scroll - a ghost doing math, which
spares the show a hand. A voice talks the whole time, as a teacher at a blackboard does: it says what it is about
to try, writes while it talks, stops to look something up, gets something wrong, crosses it out and says why.

An episode follows the arc of a good lecture, in sections the producer plans (they are the YouTube chapters):

1. **The hook** - why anyone should care: a puzzle, a picture, a number that refuses to behave.
2. **The question**, first in plain words, then precisely, written on the pad.
3. **Where it comes from** - who asked it, when, what they were trying to do, what it touches. The tablet: real
   searches, real pages.
4. **Playing with it** - small cases on the calculator, a plot, a table on the pad: observe, guess, test, refine.
5. **The idea** - the one insight the proof turns on, in pictures and words before symbols.
6. **The proof**, line by line on the pad, with the dead ends that taught something.
7. **The check** - the screen: Lean walked tactic by tactic, its list of goals read aloud as a to-do list, until
   it says there is nothing left to prove.
8. **What it means** - what we learned, where it leads, what is still open.

## The teacher's rules

The rules live as YAML (`rules/`, now in the table's) and are held by a reviewer:

- **Every term is introduced before it is used,** with numbers and an everyday picture.
- **Why before how, numbers before symbols.** A pattern is seen in 1, 4, 9, 16 before it is written as $n^2$.
- **One new idea at a time,** and a recap at the end of each section.
- **Never "obviously", "trivially" or "it is easy to see".** If it is easy, say why in a sentence.
- **History is a story:** people, places, what they were after. Every claim of fact comes from a source the
  research step really read.
- **Questions to the viewer,** with a real pause.
- **Math is spoken as words, never as notation.** The pad says $\sum_{k=1}^n (2k-1) = n^2$; the voice says "add up
  the first n odd numbers, and you get n squared."
- **Lean is explained once per episode in plain words:** what a proof checker is, what it checked, and what it did
  not (it checks that the proof proves the statement, not that the statement is the question we meant - which is
  why both are shown side by side).
- **Plain words:** every step names its rule; the facts the proof stands on are taught; no metaphors,
  personification or flourishes. No sample phrase appears in a prompt, because agents copy it.
- **Teach what this proof uses:** tell the steps that lead to it rather than every numerical check, and keep
  Lean's code and inner workings out.

A second reader, the student, reads each draft as a curious newcomer and marks where they got lost as
`{quote, need}`; the teacher revises those places. The audience is the framer's `audience`.

## The work shown is the work done

A math video that fakes its work teaches something false:

- **Every number on the calculator was computed** (SymPy), every plot plotted from the expression on its screen.
- **Every search on the tablet was really made,** and its pages really read by the researcher.
- **Every Lean message on the screen is Lean's own,** and the check mark appears only when the exact file shown
  compiled with no errors, no `sorry`, and `#print axioms` listing nothing beyond Lean's three standard axioms
  (propext, Classical.choice, Quot.sound).
- **A struck-out line is a real dead end** from the solver's session. The lesson chooses which dead ends to show;
  it never invents one.
- **An episode without a finished formal proof says so,** out loud and in the description. It never shows the
  check.

## How an episode is made

The note's text is the brief: the problem, or a source (a classic theorem, an olympiad problem, a manuscript from
openai/math), and anything the author wants stressed. A lesson has no set length: it runs as long as its proof
takes to teach, unless the note's words ask for one. When they do, the framer reads the length into `minutes`
(`[least, most]`), the teacher is handed it as spoken words (5 to 10 minutes is 580 to 1,150 words), met by what
is taught and never by talking faster, and a take more than a fifth past the most asked goes back once. The
estimate is spoken words at 0.52 s each (pauses included, measured on exports at the Narrator's pace 0.9) plus the
lesson's rests. Otherwise the teacher is told against both failures: never stretch it, never rush it.

Steps, one file each under the episode's folder, in the Cards pattern (a step is done when its file exists; a redo
deletes the step and what depends on it):

| step | made by | what it is |
| --- | --- | --- |
| `problem.json` | producer | the statement in words and in LaTeX, the kind, the audience, the arc's sections with what each must teach |
| `research.json` | researcher (web search on) | history, people, related ideas, intuition; every claim with its source; the searches made, which become tablet beats |
| `formal.lean` | formalizer | the statement in Lean, proof `sorry`; checked to elaborate |
| `fidelity.json` | reviewer | does `formal.lean` say what `problem.json` says? A mismatch stops the episode |
| `work/NNNN.json` | solver, with tools | the session: every tool call and its real result, in order, append-only |
| `proof.lean` | solver | the finished proof, checked, its axioms printed - or a note of what is left |
| `lesson/NN.md` | teacher | the narration, one segment per section, with the desk's marks in it |
| `review.json` | student, editor | where a newcomer gets lost, unexplained jargon, notation in the speech, unsourced claims |
| `ink/`, `calc/`, `lean_states.json` | ghost, no agent | every pad line laid out by TeX, every calculation computed, every tactic's goals |
| `paper.tex`, `paper.pdf` | typesetter, then TeX | the research artifact: statement, background, proof, the Lean file as an appendix, references |
| `script.md` | ghost, no agent | the segments composed into what the voice reads |

As built, the lesson is three steps: `draft` (the teacher), `review` (the student), `lesson` (the teacher again
from the draft and the notes).

**The solver's tools are the desk.** Its MCP toolset is `pad` (write a line; TeX's errors come back, so a broken
formula is fixed by the agent that wrote it), `strike`, `calc`, `plot`, `lean` (check a snippet: errors, remaining
`sorry`s, the goals before and after every tactic), `note` (a line for the lab notebook, written for a student) and
`submit`. Its web searches are its backend's own. The trace of the work is the list of things the desk can show,
and the lesson is written from it. A solver is never asked for its reasoning or thinking, only for work written for
a student (attempts, what each gave, explanations): a safeguard reads a request for reasoning as extracting a chain
of thought and stops the run. Every step is a file, so a flagged final message loses nothing.

**A second kind of checked work, a computation.** The framer's `check` is "proof" (Lean) or "computation" (what is
computed, fixed as a statement is). The solver gets `run`: Python in the compute environment (`compute_venv`:
numpy, SciPy, SymPy) inside a bubblewrap sandbox (`hosts/compute/run.py`: the system read-only, one folder to
write in, a sized /tmp, no network, nothing of the author's; memory, processor time, files and folder capped,
killed at its wall time). `keep(name, x, y)` keeps a series, which drawings plot by name (`<plot data>`,
`<dots data>`, `<bars data>`) - never numbers typed in. A computation lands `computed`, the teacher is shown the
runs first and says the numbers come from code that ran, and the upload says so. Without bubblewrap nothing runs:
`run` is not offered and a computation framed earlier fails at the solve saying to install it. Not built: a
sandbox on macOS or Windows.

**Not only math.** Every agent is told of "a channel of lessons". The inventor draws from many fields, the framer
and refiner keep the depth the note asks for, and the teacher and student take the viewer from the framer's
`audience` alone.

## The voice and the math

The voice is never handed notation. `MathSpeech` audits every segment for TeX, stray symbols and Greek letters
spelled as symbols, the way `pronounce_audit` holds a script before a long render. Names a voice gets wrong go in
the note's `names:` block. A letter that names something is written `[a]` and said as the letter's name (shown as
`a` in the subtitles; `TextNorm._expand_core`, the `letter` row of `ScriptMarks`).

**Pronouncing technical words.** eSpeak, which the neural voices use, guesses words CMUdict lacks and leaves the
core syllable of cosine, cotangent and cosecant unstressed, so the voice slurs it. A word eSpeak has to guess at
gets a secondary stress on each unstressed full vowel, with Wiktionary's vowels where eSpeak's differ (next/voice_engines.md,
"a word eSpeak has to guess at"). The reading marks a word as guessed through its page spelling with marks aside
(`Phonemes.guessed`; `g2p_check` "guessed").

## The desk

A medium, `desk`, registered by row like the table, reading the episode from the book the reading hands it and the
time from its `feed`: a pure function of the two.

- **The set** is built from the table's parts (`Lights`, `Props`, `Soundscape`, `Effects`, `Winds` take a host and a
  description): a desk top, a lamp, a window's light, the room heard.
- **The pad:** paper as a texture (a SubViewport on a plane), ruled or squared. The ink is strokes, drawn as a
  function of time. A full page lifts at its foot and swings over the binding, the clean one under it; later pages
  go round it a loop's width rounder, and the pen comes back once the head is down. A page is filled rule by rule
  and turns when the next formula would run off its foot, so no mark turns a page and the voice's rests come from
  the typeset sizes.
- **The pen:** a `Props` pen whose tip follows the stroke being drawn, lifting between strokes and resting on the
  pad while the voice talks without writing. It leans to the top right and sways a few degrees over seconds, turns
  toward the page's top as the nib goes left, and drifts a few millimeters off the paper in proportion to how high
  it is held, never while it writes.
- **The tablet:** `TabletPage` pages, real captures where a page was really read.
- **The calculator:** a prop with an LCD (a SubViewport), keys pressed as an expression is typed, the result SymPy's.
- **The screen:** the Lean file in an editor, the cursor stepping through tactics, the goals panel beside it,
  errors underlined in red, and at the end Lean's "no goals" and the check.

**Marks** in the lesson say what the desk does, one `ScriptMarks` row each: `<!-- pad: ... -->`,
`<!-- pad-text: ... -->`, `<!-- draw -->`, `<!-- strike -->`, `<!-- box -->`, `<!-- calc: ... -->`,
`<!-- plot: ... -->`, the tablet's own `<!-- search: -->` and `<!-- url: -->`, `<!-- lean: 3 -->` or
`<!-- lean: check -->`, and `<!-- point: name -->`. `DeskScript` turns a segment into the voice's text and the
desk's actions from one pass, as `TabletScript` does, so they cannot disagree; `ReadingFollower.place` puts the
actions between the spoken words.

**What is written is said as it is written.** The line right after a pad mark, with no blank line between, is its
dictation - the formula read aloud, word for word - and the pen writes across exactly those words. The teacher is
told this as a template with no sample words, and a lesson that leaves pad lines unread goes back once
(`DeskScript.undictated`). A line of pad text is a few words, and the rest is said. A hand takes three or four times
as long to write prose as to say it, so the pen is elastic: its clock is the voice's progress smoothed over 1.5 s
and stretched onto the pen's time (`DeskMedium.elastic`), so it slows over a pause and makes it up over the words
after, and is never still mid-stroke. The voice does not rest inside a dictation; what the pen owes at its fastest
(`MAX_PACE`) is one rest after the dictation's last word.

**A drawing takes its time.** A drawing's line is a few words and its ink long, so a drawing runs on past its line
through the talk about it (`about`), never slower than the hand's own pace (`DRAW_PACE`), done before the pen's
next action is due (`DeskMedium._drawn_by`). Its line gives each axis, curve, shape and label a phrase as it is
drawn.

**What is on the page stays.** A streamed reading's words arrive a sentence at a time, so a drawing's plan is
remade as each sentence comes in; `DeskMedium.take_words` holds the past before new times are taken in
(`_hold_past`): what began keeps its start, what is done stays done, and a line being written goes on from where it
is. An export, whose times are all known at once, is planned once and stays a pure function of time. No action
starts before the nib's way from the last (`DeskMedium._way`).

**A word the voice says its own way never stops the desk.** `ReadingFollower` takes a one-letter word as the start
of the page's next word when it begins it, and a word the voice goes past unmatched has the time it was most likely
said; the desk waits only for what the voice has not reached. After a scrub the desk reads the document's
`start_words` (as the card table and the tablet do) and starts there.

**An idle pen gets out of the way.** Over 40 words with nothing for the pen (`DeskMedium.PARK_WORDS`, read off the
script so it never changes its mind as streamed words arrive), and before every page turn, the nib goes right off
the written lines, up the pad's edge to `PARK`, and comes back as the next action begins. Every move is continuous
and a reach takes its way at 1000 px/s (`_reach`); a page turns only once the pen is off the pad (`PARK_CLEAR`).

**The pen points.** A thing on the pad can be named - `<!-- pad #name: ... -->`, an SVG element's `id`, a formula's
`\pin{name}{...}` - and `<!-- point: name -->` inside speech sends the pen there at the next word, held to the
sentence's end (`DeskScript`). typeset.py reads the pins back from TeX's own specials, figure.py the ids, each as
a box in the record's `anchors`. The nib comes down 3.5 mm beside a small thing's foot or sweeps under a wide one;
the camera goes there; a point at a page already turned leaves the pen be. A lesson that says more than 80 words
with the pen idle (`DeskScript.still`) or points at a name nothing carries goes back once; the student marks both.

**The camera** has a station per instrument (over the shoulder on the pad, close on the calculator, square on the
screen) and moves between them on a context switch. The pad's camera is the book medium's kind: a 20 degree lens
from high and a little in front, mostly looking down, one slow critically damped spring, the wide shot standing at
1.45 m with the whole pad in it; it stands back 3 s before a page turn and aims at the head.

**Every desk is its own.** `DeskLook`, from the episode's seed: the pad's paper, rules, margin and binding, the ink
(always 8.6:1 or better on its paper), the pen's lacquer and trim, the lamp's warmth and place, the desk's top
(`Tables`: wood, stone, lacquer, leather or baize), a mat under the pad about half the time, and up to five things
(`Props`: a mug, pencils, an eraser, books, paper clips, index cards, a ruler, a small cactus), never on the pad,
behind it, or (tall) beside its right edge where the pen leans out. No agent and no painter: every surface is a
shader pattern from the drawn numbers. Not built: a desk an agent dresses for the problem.

**The opening and the close are the card table's.** `ShowOpening` (`table/`) is how a show at a table or a desk
opens and closes: the name over the frame thrown far out of focus (`IntroBlur`, `TitleCard`), the focus pulled as
the show opens, black a beat after the last word, and where the thumbnail is taken
(`ShowOpening.thumbnail_moment`).

**The channel and the episode.** A note's Title and Byline are the channel's, as a card show's are; the framer names
the episode (`episode_title`, the `%episode%`) under the rule every show's namer is given
(`rules/agents/episode.yaml`). The upload adds, from Lean's own verdict, whether the proof was checked and by which
Lean and Mathlib. The YouTube card picks a category (`YouTube.CATEGORIES`).

## Ink

**TeX lays out, a hand writes.** `hosts/math/typeset.py` sets every item in one TeX run (a page each), reads the DVI
back itself and answers, per item, every glyph's font, code, name, baseline origin, size and TFM box, and every
rule (fraction bars, radicals' bars), in TeX's own order. DVI rather than SVG, because DVI keeps each glyph's font
and code and an SVG of outlines throws them away. The name is what a hand reads (`alpha`, `summationdisplay`,
`radicalbig`). The hand draws each glyph as pen strokes from the Hershey fonts (centerline fonts made for
plotters, free for any use with credit to Dr. A. V. Hershey and the NBS), fitted into the box TeX gave the glyph:
Latin from the simplex Roman, Greek from its Greek set, `\mathcal` from its script capitals, operators, big
delimiters, radicals, integrals and sums from its two math sets. A few are recipes (an upside-down A is "for all",
a subset with a bar under it is "subset or equal", a doubled stroke is blackboard bold; one bar under "less or
equal"; "and", "or", "approximately", the double arrows). A glyph with no strokes is drawn as its outline traced.

What the spike showed:

- **TeX's structure survives the swap:** fractions, radicals with their bars, limits above and below a sum,
  `\left( \right)` grown to fit, a matrix, a three-line `align*`, a paragraph with inline math.
- **TeX's order is a hand's order:** a fraction comes numerator, bar, denominator; a radical, sign, bar, radicand.
  One exception: a sum's upper limit comes before the sign, so the sign is moved first.
- **A glyph keeps its own proportions.** Scale uniformly and center in the box, with a little overflow allowed.
  One scale serves both axes; a comma's width and an m's must follow the font's own proportions.
- **One broken formula costs only itself:** a missing brace fails that item with TeX's own message, and the rest
  are set.
- **Writing takes as long as writing:** $a^2 + b^2 = c^2$ takes 4.7 s at the prototype's pen speed, Cauchy-Schwarz
  32 s - which is why the pen writes under the voice rather than between its sentences.
- TeX's "not" slash is a glyph of no width laid over the next one, so an overlay strikes the box of the glyph after
  it; "ff" and "fi" are single glyphs written as their letters (`Ink._ligature`); `\implies` is a bar kerned under
  an arrow, written as one long arrow; `aligned` lives inside math, so only the display environments (`align*`,
  `gather*`) are set as displays.

**The hand** (`Ink`, in the table's `TableInk`) is three pure steps: `strokes_of` (a typeset item and a seed ->
strokes in writing order), `schedule` (strokes and a pace -> when each is drawn: the pen's speed, its lifts, a
breath between glyphs and a longer one before a relation) and `at` (a schedule and a time -> the ink then, the
stroke under the pen cut on a minimum-jerk profile, and where the nib is). The same seed gives the same hand,
another seed another; ink only ever grows and is the same at a moment whatever was asked before.

**Figures.** A `draw` mark holds an SVG over as many lines as it takes, dictated like a formula.
`hosts/math/figure.py` reads it with svgelements (MIT, in `math_venv`) into pen paths - lines, curves and arcs
flattened, a small filled shape a dot, a big one hatched (only a fill the SVG asks for), dashes, hand-drawn
arrowheads - and its `<text>` labels are set by TeX in the same run as the formulas. `<axes>` draws numbered axes
on a box, and inside it `<plot fn>` is computed from its expression (an arithmetic-only parser; broken where
undefined or jumping, cut at the range's edge), so a curve is never an agent's guess. Also curves of t
(`<plot x="" y="" t=""/>`), polar curves (`<plot r="" t=""/>`), bars, circles and ellipses in the axes' units, a
faint grid (`grid="true"`), ranges and ticks written with pi, `<angle>` marks, and the rule that a problem about a
thing in the world draws that thing as a plain outline with its lengths and angles marked. The hand draws paths a
little uneven, pinned at their ends, at 2.6 times its writing speed; a figure is centered in the column. A lesson
draws at least two figures. Held by `test_typeset.py`.

**Ghost's own TeX** (`tex`, a fetched row): TinyTeX's smallest full build, `TinyTeX-1` - 54 MB as a `.tar.xz` with
GitHub's SHA-256, 187 MB unpacked, a real TeX Live with `latex`, `pdflatex`, `kpsewhich`, `amsmath`, `amssymb` and
the Computer Modern and AMS Type 1 fonts, and `tlmgr` to add a package a paper asks for. `typeset.py` pointed at it
sets the same twelve items to identical layouts as the system's TeX Live, in 1.9 s. One dependency serves the pad
and the paper.

## Lean

- **Installed by ghost,** two rows, no elan. `lean` is a fetched tree: the toolchain zip from Lean's GitHub release
  (926 MB, SHA-256 checked, 3.4 GB unpacked; `bin/` is made executable because a zip keeps no permissions Godot can
  read). `mathlib` is a managed row of a new kind, a workbench: a Lake project written from `hosts/math/lean/` into
  `user://lean/mathlib-<tag>/`, requiring Mathlib and the Lean REPL at one tag. Lake fetches them with git;
  Mathlib's cache tool downloads the compiled library with curl and honors `MATHLIB_CACHE_DIR`, so nothing lands in
  the author's own caches. Fetched only when a lesson needs it, with progress, like the voice environment.
  Godot's `ZIPReader` is quadratic on a toolchain's 18,571 files, so ghost's own Python unpacks a zip tree behind a
  GDScript guard on the member names.
- **One tag picks all three.** Mathlib's release names the Lean it is built for (`lean-toolchain`), and the REPL
  tags the same names, so the version ghost fetches is the newest Mathlib release the REPL also has
  (`Provision.pick_mathlib`). The daily update pass moves the three together; an episode records the tag it was
  checked with.
- **Measured:** end to end 394 s on the author's machine (`lake update` 145 s including the 9,031 compiled files,
  the REPL built in 27 s, the check file with `import Mathlib` 97 s); 7.5 GB, plus a 0.45 GB download cache removed
  afterwards.
- **A warm host.** The REPL takes JSON commands on stdin: `import Mathlib` once, then each snippet in that
  environment. Asked for every tactic (`allTactics`), it answers each tactic's text, position, the goals before it
  and the library facts it used; a failed tactic answers with its position and Lean's words, and `#print axioms`
  answers `[propext, Classical.choice, Quot.sound]`. The goal before the last tactic ("all that is left is to
  expand a square") is the screen's best moment.
- **More than one checker.** The toolchain ships three independent kernels beside Lean's own (`leanchecker`,
  `lean4lean`, `nanoda`). The final proof can be re-checked by each, and the screen can say so.
- **For an openai/math manuscript,** its own `lean/` project is the workbench, so its proof is checked as published.
- Held by `provision_check` (whole trees, permissions, a member climbing out, one tag for all three with a REPL that
  lags as the control, a workbench stale by template or by tag) and `deps_check`.

## Live, later - and what this plan takes from it now

A live stream is the solver working while the audience watches, a few minutes behind it. It needs a reading that
takes text while it streams, a clock with no song, the storyboard's third source (a live queue), frames sent to an
RTMP address, and a show that never waits in silence when the solver is slow (the pen taps, the teacher recaps).
None of that is built. What the design takes from it at no cost:

- **The trace is append-only:** `work/NNNN.json` rounds, never rewritten.
- **The lesson is written in closed segments:** each one's narration, marks, ink, calculations and Lean states
  exist before it is read, and nothing in segment N depends on N+1.
- **The desk's schedule for a segment never moves once made,** and the desk is a pure function of (segments so far,
  show time).

An export is the case where every segment exists before Play, and live is the same desk fed segments as they
close. The live phase is then plumbing, not a redesign.

## Where it goes

Two folders, as Cards has two (`table/` the set and its medium, `cards/` the show agents make): `desk/` (the set,
the ink, the instruments, the medium), placed after `table/` because it borrows the table's light, props and sound;
and `proof/` (the episode, its producer, prompts, tools and card), above `desk/`. The hosts go in `hosts/math/` (TeX
layout, SymPy, the Lean bridge), with one environment, `math_venv`. Seed hash salts start neutral (`proof-`,
`desk-`) so a later rename never re-rolls an episode.

## The plan, in order

### 0. Spikes

- **0a. Ink.** Done. See [Ink](#ink). `hosts/math/typeset.py` is kept.
- **0b. Lean and TeX, installed by ghost.** Built: rows `tex`, `lean`, `mathlib` (and `git`, `curl`, `tar` as the
  machine's own); `Provision.extract_zip_tree`, `adopt_tree`, `pick_mathlib`, `parse_toolchain`,
  `workbench_ready`; the provisioner's workbench job, an update pass that keeps on-demand rows current, and
  `--provision <key>`. `_ask` parses JSON lists as well as objects (a list endpoint had come back empty), and the
  Environment report knows a workbench.
- **0c. A solver by hand.** Done, three of three verified: a Claude job with a checker script in place of the `lean`
  tool and a lab notebook solved Euclid's infinitude of primes, the irrationality of the square root of 2 and
  Nicomachus's sum of cubes in 68 to 103 s each, verified on the first or second Lean check. Their explorations
  found real lesson moments (n! + 1 is not always prime; the near misses 3/2, 7/5, 17/12, 41/29, 99/70 are the Pell
  numbers), and each notebook ended in a "What a learner needs" a teacher could build on. These show no real dead
  end: a lesson's struck-out lines will come more often from exploration (a guess the table refutes) than from
  Lean, and from harder problems.

### 1 + 2, as one slice: something to judge in the app

Built thin, so the whole path could be judged in the app. A `producer` row brought a Voice and took the
presentation slot (workspace `proof`, block `ghost: proof:`), the note's words were the problem, and `ProofCard` had
Invent a problem, Refine, Make episode (Remake once anything is made), Stop, Delete…, Folder, New episode, an
episode picker, the writer, and a row per step with a refresh. Delete… sent the episode's folder to the system
trash. The episode steps were `problem` (the framer: words, TeX, the exact Lean statement of `theorem main`, the
forbidden facts, history), `solve` (the solver, accepted only verified, otherwise honestly unverified), `lesson`
(refused once if its speech carries notation), `ink` (a TeX refusal sends the lesson back once with TeX's words)
and `script`. It waited, saying so, while Lean, Mathlib or TeX installed. The desk was a legal pad under a lamp with
the pen writing what the voice says as it says it. The first real episode, made by agents end to end, took 411 s
from Invent to script; the solver was verified on its sixth Lean check, one a real dead end that the lesson tells and
strikes through.

What those runs fixed, now held:

- `AgentTools` threw on a tool's error given in words, so the solver's notebook calls were never answered
  (`agent_tools_check` holds an error in words and an empty one).
- A solver prompt that mentions recording its work can trip the reasoning safeguard; it is asked for deliverables
  only, and the solve is tried up to three times.
- The lamp burned the white page out (the tablet's value, set for a dark screen), so the lamp is 1.5; the camera
  stands 0.2 m from the line and aims at it; the page is a render target with no mipmaps, so rules do not shimmer.
- One choice of agents: `AgentPick` (`ui/`) is the row every card builds its writer and painter from
  (`agent_effort_check`).
- The panel's width is gated (`panel_fit_check` builds every card's panel).
- Refine reads the note as it stands and writes it back whole (title, question, claim in LaTeX, what the viewer
  learns, who it is for, what to show on the pad, where it comes from), keeping everything the author asked for;
  one agent writes the note at a time and the edit is the note's own (its undo takes it back).
- The lesson length is the framer's reading of the note (see How an episode is made); no Minutes dial exists.
- The pen's motion, the page turn, the idle pen, the dictation and the drawings' pace in The desk above were each
  tuned and gated against real exports (frame-by-frame checks of jumps, rests and overlaps).

### 1. The episode, heard

The `proof` row in `Components.REGISTRY`, a `WORKSPACES` row, `ProofCard`, `ProofEpisode` (steps, needs,
invalidate), `ProofProducer`, `ProofTools`, the rules, `MathSpeech`. The lesson is heard over a bare desk. Gates: the
episode's steps and redos on fixtures (no agent), every tool's real output, the speech audit with a control that
must fail.

### 2. The pad and the pen (the slice above built the first of it)

`DeskScript` (marks to actions and speech), the desk medium with the pad and the pen, the pen writing under the
voice. Gates: ink is a pure function of time (the same frame from two paths), every glyph in a test set covered, the
voice's words equal the marks' spoken words (two-sided, as `tablet_check`).

### 3. The instruments

The screen (Lean file, goals, the check), the calculator (keys, LCD, plots), the tablet (its pages, reused), the
camera's stations. Gates per instrument; a look probe, rendered sparingly. Not built.

### 4. The paper and the publish

`paper.tex` compiled; chapters from the arc's sections; the description names the sources and says what Lean
checked; the paper and the Lean file published beside the video (where is the author's call). Not built.

### 5. Live

The reading that grows, the clock with no song, the RTMP output, the never-silent wait. Its own note when it
starts.

## Risks

- **Agents and Lean.** Textbook and olympiad results are within reach of today's agents with a compile loop;
  research results mostly are not (OpenAI's release formalized about 42% after hours of compute each). Nothing
  depends on Lean succeeding: an episode without a check says so.
- **Misformalization.** Lean proves what it is told. The fidelity step, and both statements shown side by side, are
  the guard.
- **A wrong teacher.** Lean checks the theorem, not the narration. Sources for every claim of fact, the student and
  editor passes, and the author's own pass before anything is published.
- **A wall of symbols.** The teacher writes key lines, not everything it says; pages turn; the camera frames the
  line being written.
- **Weight.** Lean and Mathlib are gigabytes; an episode is hours of agent time on the subscription.
- **YouTube's rules.** Its monetization policy excludes mass-produced, repetitive content; the author's editorial
  pass per episode is what keeps a channel of these on the right side of it.
