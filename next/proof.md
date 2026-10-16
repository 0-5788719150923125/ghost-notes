# Proof: a mathematician at a desk, thinking out loud

Opened 2026-10-15, for the user's proposal: a new kind of show in which an actor sits at a desk with
a pad of paper, writes equations, looks things up on a tablet, works numbers on a calculator and
checks a proof in Lean - narrating all of it, to teach a hard idea to someone who knows little
math. LaTeX is the common language of the writing, Lean the industry's proof checker, and the voice
the point: "We are a teacher or a professor, not a research grad publishing the paper. But
actually, we're both. The technical research is the artifact; the teacher is the process." Exports
first, as always; live streams of an AI working a problem in real time later, so the design should
not close that door.

**Decided by the user, 2026-10-15:** the writer is unseen (the pen moves by itself); the first
episodes are classic theorems the agents can really solve and check; the component is called
Proof; and every dependency is a standalone install ghost fetches and keeps current itself, the way
FFmpeg and uv are - a system package is never installed by an agent, only handed to the user as a
command.

This note is the design, what was measured before it was written, and the plan in order. The
foundation it stands on was laid the same day for exactly this ([structure.md](structure.md), "The
second round: a foundation for a live mode"): a live mode is a component and a card, the reading
takes its parts from a component, and the show's clock is handed to what it mounts.

## The verdict

**Not a terrible idea, and a good fit.** Three reasons, each checked rather than assumed:

- **The machine is mostly built.** Cards already makes a show the way this one would be made:
  agents plan, write and act through ghost's own MCP tools, one file per step, a redo a delete, a
  medium that is a pure function of the episode and the show's time, and a voice that reads what
  the agents wrote. The tablet already turns marks in a script into actions and rests in the voice
  from one walk. What is missing is ink, a desk, and the two toolchains.
- **The hardest visual problem is solved on paper.** Ghost had no math rendering and nothing that
  draws strokes over time. A spike the same day (see [Ink](#ink)) laid twelve formulas out with TeX
  and wrote them in a seeded hand: fractions, radicals, limits, matrices, `align*`, prose with
  inline math, in 2.5 s for all twelve, every glyph covered.
- **The moment is real.** OpenAI's release on 2026-10-06 is in `github.com/openai/math`
  (Apache-2.0): 719 manuscripts in 372 families, LaTeX sources and PDFs, a Lean library pinned to
  Lean v4.34.1 covering about 42% of the top-line results, and abridged reasoning summaries for ten
  of them. Three manuscripts were withdrawn a day later over a sign error. That is a library of
  material, and a reminder of why the check on screen matters.

What I cannot verify is "first to market". Terence Tao has published recordings of himself
formalizing in Lean with AI help, and 3Blue1Brown's tooling set the standard for math exposition.
I know of no one combining the two: an AI working a problem at a desk, narrated as a lesson, with
the formal check on screen.

## What a viewer sees

A desk under a lamp: a legal pad, a pen, a tablet, a calculator, a small screen. Nobody is in the
chair. The pen lifts and writes by itself, the calculator's keys go down, the tablet's pages
scroll - **a ghost doing math**, which is the product's name made literal, and which spares the
show a hand (a visible hand is a feature of its own and easy to get uncanny). A voice talks the
whole time, as a teacher at a blackboard does: it says what it is about to try, writes while it
talks, stops to look something up, gets something wrong, crosses it out and says why.

An episode follows the arc of a good lecture, in sections the producer plans and a viewer can
skip to (they are the YouTube chapters):

1. **The hook** - why anyone should care: a puzzle, a picture, a number that refuses to behave.
2. **The question**, first in plain words, then precisely, written on the pad.
3. **Where it comes from** - who asked it, when, what they were trying to do, what it touches. The
   tablet: real searches, real pages.
4. **Playing with it** - small cases on the calculator, a plot, a table on the pad. The scientific
   method where math has one: observe, guess, test the guess, refine.
5. **The idea** - the one insight the proof turns on, in pictures and words before symbols.
6. **The proof**, line by line on the pad, with the dead ends that taught something.
7. **The check** - the screen: Lean, a program that trusts nothing, walked tactic by tactic, its
   list of goals read aloud as a to-do list, until it says there is nothing left to prove.
8. **What it means** - what we learned, where it leads, what is still open.

## The teacher's rules

The voice is the most important part, so its rules are written down (in `rules/proof/`, as YAML,
like the Cards rules) and held by a reviewer:

- **Every term is introduced before it is used**, with an everyday picture. "Prime" is "a number
  of stones you cannot lay out as a rectangle"; "irrational" is "a number no fraction hits
  exactly, however big its top and bottom get".
- **Why before how, numbers before symbols.** A pattern is seen in 1, 4, 9, 16 before it is
  written as $n^2$.
- **One new idea at a time**, and a recap at the end of each section.
- **Never "obviously", "trivially" or "it is easy to see".** If it is easy, say why in a sentence.
- **History is a story**: people, places, what they were after. Every claim of fact comes from a
  source the research step really read.
- **Questions to the viewer**, with a real pause: "Before I go on - can you see why that has to be
  even?"
- **Math is spoken as words, never as notation.** The pad says $\sum_{k=1}^n (2k-1) = n^2$; the voice
  says "add up the first n odd numbers, and you get n squared."
- **Lean is explained once per episode in plain words**: what a proof checker is, what it checked,
  and what it did not (it checks that the proof proves the statement; it does not check that the
  statement is the question we meant - which is why both are shown side by side).

A second reader, **the student**, reads each draft as a curious newcomer would and marks where they
got lost; the teacher revises those places. The audience is a dial on the note (`level`: curious,
student, specialist), and the same problem makes a different lesson at each.

## The work shown is the work done

Cards has NO CHEATING (a reader sees only the cards drawn so far). This show's version is stronger,
because a math video that fakes its work teaches something false:

- **Every number on the calculator was computed** (SymPy), every plot plotted from the expression
  on its screen.
- **Every search on the tablet was really made**, and its pages really read by the researcher.
- **Every Lean message on the screen is Lean's own**, and the check mark appears only when the exact
  file shown compiled with no errors, no `sorry`, and `#print axioms` listing nothing beyond Lean's
  three standard axioms (propext, Classical.choice, Quot.sound).
- **A struck-out line is a real dead end** from the solver's session. The lesson chooses which dead
  ends to show; it never invents one.
- **An episode without a finished formal proof says so**, out loud and in the description. It never
  shows the check.

## How an episode is made

The note's text is the brief: the problem, or a source (a classic theorem, an olympiad problem, a
manuscript from openai/math with its paper and Lean file), and anything the author wants stressed.
The `proof:` block holds the dials: `level`, `length` (minutes), `kind` (solve, explain, explore -
inferred from the brief when not set).

Steps, one file each under `user://proofs/<show>/<episode>/`, in the Cards pattern (a step is done
when its file exists; a redo deletes the step and what depends on it):

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

**The solver's tools are the desk.** Its MCP toolset (`ProofTools`, through `AgentTools` like the set
dresser's) is `pad` (write a line; TeX's errors come back, so a broken formula is fixed by the agent
that wrote it), `strike`, `calc`, `plot` (a picture the agent can look at), `lean` (check a snippet:
errors, remaining `sorry`s, the goals before and after every tactic), `note` (a line for the lab
notebook, written for a student - never asked for as "reasoning", which a safeguard reads as
extracting a chain of thought; see step 0c) and `submit`. Its web searches are its backend's own, read off the stream the
activity line already reads. So the trace of the work is the list of things the desk can show, and
the lesson is written from it.

## The voice and the math

The voice must never be handed notation. The teacher writes spoken math as words, and a gate holds
it: `MathSpeech` audits every segment for TeX, stray symbols and Greek letters spelled as symbols,
the way `pronounce_audit` holds a script before a long render. Names a voice gets wrong ("Erdős",
"Mathlib", "Noether") go in the note's `names:` block, which already exists.

## The desk

A medium, `desk`, registered by row like the table, beside it in the stack. It reads the episode
from the book the reading hands it and the time from its `feed`, and it is a pure function of the
two.

- **The set** is built from the table's parts, which do not depend on cards (measured: `Lights`,
  `Props`, `Soundscape`, `Effects` and `Winds` take a host and a description): a desk top, a lamp, a
  window's light, the room heard. Seeded per show; a set dresser can build it later.
- **The pad**: paper as a texture (a SubViewport on a plane, as the tablet's screen is), ruled or
  squared, pages turned or torn off when full. The ink is strokes, drawn as a function of time.
- **The pen**: a `Props` pen whose tip follows the stroke being drawn, lifting between strokes and
  resting on the pad while the voice talks without writing.
- **The tablet**: `TabletPage` pages, as the tablet medium sets them, real captures where a page was
  really read.
- **The calculator**: a prop with an LCD (a SubViewport), keys pressed as an expression is typed,
  the result SymPy's; a graph mode for plots.
- **The screen**: the Lean file in an editor, the cursor stepping through tactics, the goals panel
  beside it, errors underlined in red, and at the end Lean's "no goals" and the check.

**Marks** in the lesson say what the desk does, one `ScriptMarks` row each, documented in
docs/script.md like the tablet's: `<!-- pad: \int_0^1 x^2\,dx -->`, `<!-- pad-text: Suppose $p$ is
prime. -->`, `<!-- strike -->`, `<!-- box -->`, `<!-- calc: 2^61 - 1 -->`,
`<!-- plot: sin(x)/x, -10, 10 -->`, the tablet's own `<!-- search: -->` and `<!-- url: -->`, and
`<!-- lean: 3 -->` (the screen steps to tactic 3) or `<!-- lean: check -->`. A `DeskScript` walk
turns a segment into the voice's text and the desk's actions from one pass, as `TabletScript` does,
so they cannot disagree; `ReadingFollower.place` puts the actions between the spoken words.

**What is written is said as it is written** (2026-10-16; the first plan let the pen write under
whatever the voice was saying, and the user: "a person cannot pay attention to both"). The line right
after a pad mark, with no blank line between, is its DICTATION - the formula read aloud, word for
word - and the pen writes across exactly those words, its ink clock driven by how far through them
the voice is, within 0.55-1.8x its own pace. The voice rests only for the pen to come down (0.45 s),
for a page's turn (1.6 s), and for writing the words outrun (`DeskScript.tail_for`). A hand takes
three or four times as long to write a line of prose as to say it (the first real lesson: 19 s of ink
for an 11-word line), so a dictation the pen lags by a second or more goes PHRASE BY PHRASE
(`DeskScript.paced`): the wait is shared out over its words and rested at each phrase's end - a stop,
or six words without one, never one word left alone - so the voice says a phrase, the pen writes it,
and on, never all the words and then a long silence. One rest between two paragraphs. **No mark turns a page**: the pad is
filled rule by rule (`DeskScript.lay_out`) and turns when the next formula would run off its foot, so
the layout is part of the parse and the voice's rests come from the typeset sizes.

**The camera** has a station per instrument (over the shoulder on the pad, close on the calculator,
square on the screen) and moves between them on a context switch, the tablet's camera arc inside
each: wide on arrival, close while working, the current line held in a band of the view rather than
followed. The pad's, built: the book medium's kind (a 20° lens from high and a little in front,
mostly looking down, wide enough for the instruments to come beside the pad; one slow critically
damped spring; a per-page yaw and tilt and a wander).

## Ink

**Measured 2026-10-15** (`hosts/math/typeset.py`; the hand is a prototype in
`dist/math_spike/tools/hand.py`, to be written in GDScript).

**TeX lays out, a hand writes.** `typeset.py` sets every item in one TeX run (a page each, one box
shipped per page), reads the DVI back itself and answers, per item, every glyph's font, code, name,
baseline origin, size and TFM box, and every rule (fraction bars, radicals' bars), in TeX's own
order and on TeX's own baseline. DVI rather than SVG, because DVI keeps each glyph's font and code
and an SVG of outlines throws them away. The name is what a hand reads: `alpha`,
`summationdisplay`, `radicalbig`, `reflexsubset`. The hand draws each glyph as **pen strokes from
the Hershey fonts** (centerline fonts made for plotters, free for any use with credit to Dr. A. V.
Hershey and the NBS), fitted into the box TeX gave the glyph: Latin from the simplex Roman, Greek
from its Greek set (lowercase italic), `\mathcal` from its script capitals, operators, big
delimiters, radicals, integrals and sums from its two math sets. A few are recipes: an upside-down
A is "for all", a subset with a bar under it is "subset or equal", a doubled stroke is blackboard
bold.

What the spike showed, rendered and looked at:

- **TeX's structure survives the swap.** Fractions, radicals with their bars, limits above and below
  a sum, `\left( \right)` grown to fit, a matrix, a three-line `align*`, a paragraph wrapping with
  inline math, Cauchy-Schwarz with three sums.
- **TeX's order is a hand's order.** A fraction comes numerator, bar, denominator; a radical, sign,
  bar, radicand. One exception, fixed in the hand: a sum's upper limit comes before the sign, so
  the sign is moved first.
- **A glyph keeps its own proportions.** Stretching a stroke glyph to its TeX box crowded
  superscripts into their bases and swelled commas; scaling uniformly and centering in the box is
  right, with a little overflow allowed, as handwriting has.
- **One broken formula costs only itself.** A missing brace fails that item with TeX's own message
  ("Missing } inserted"), and the rest are set.
- **Writing takes as long as writing.** At the prototype's pen speed, $a^2 + b^2 = c^2$ takes 4.7 s,
  "$\sqrt 2 = p/q$, $\gcd(p,q) = 1$" 11 s, Cauchy-Schwarz 32 s - which is why the pen writes under
  the voice rather than between its sentences.

**The hand in GDScript** (`src/desk/ink.gd`, `Ink`; built 2026-10-15) is three pure steps:
`strokes_of` (a typeset item and a seed -> strokes in writing order), `schedule` (strokes and a pace
-> when each is drawn: the pen's speed, its lifts, a breath between glyphs and a longer one before a
relation) and `at` (a schedule and a time -> the ink then, the stroke under the pen cut on a
minimum-jerk profile, and where the nib is). The glyph table is the spike's, plus recipes for what
the Hershey sets lack or draw wrong for a hand (one bar under "less or equal", not two; "for all"
as an upside-down A; "and", "or", "approximately", the double arrows). A glyph with no strokes is
drawn as its outline traced and named in `missing`. `tests/desk/ink_check.gd` holds it on a fixture
TeX made (`tests/desk/ink_layout.json`, 125 glyphs in nine items): every glyph covered but the
contour integral, which must fall back; the same seed the same hand, another seed another; a
fraction's bar between numerator and denominator, and the sum's sign moved ahead of the limit TeX
set first (the control: TeX's own order has the limit first); every glyph in its box; and ink only
ever growing, the same at a moment whatever was asked before, the pen on the stroke it draws. The
gate found one thing the spike's pictures showed and nobody named: TeX's "not" slash is a glyph of
no width laid over the next one, so a not-equal came out "/=" - an overlay now strikes the box of
the glyph after it. And one the spike's pictures showed that was mine: the prototype measured a
stroke glyph's x by its own advance and its y by the cap height, so every glyph's shape followed its
width (a comma 2.8 times too wide, read as "›"; an m squeezed to two-thirds). One scale for both
axes now, and the gate holds narrow and wide glyphs to the font's own proportions - its first draft
took the reference through the hand's own code and passed on the bug, so the reference is the
font's raw points.

Left for the pad (step 2): the nib's width by speed (a triangle strip, as `TriBatch` draws), prose
in a cursive hand seeded per show, a wide glyph crowding its neighbor ("there exists" before a
delta), and the slant tuned so an italic's top clears its superscript.

**Ghost's own TeX** (`tex`, a fetched row): TinyTeX's smallest full build, `TinyTeX-1` - 54 MB as
a `.tar.xz` with GitHub's SHA-256, 187 MB unpacked, a real TeX Live 2026 with `latex`, `pdflatex`,
`kpsewhich`, `amsmath`, `amssymb` and the Computer Modern and AMS Type 1 fonts, and `tlmgr` to add
a package a paper asks for. Measured: `typeset.py` pointed at it (the spec's `bin`) set the same
twelve items to identical layouts, glyph for glyph, as the system's TeX Live, in 1.9 s, and the log
shows TinyTeX's own pdfTeX loading TinyTeX's own `article.cls`. One dependency serves the pad and
the paper.

## Lean

- **Installed by ghost, like everything else** - two rows, no elan. `lean` is a fetched tree: the
  toolchain zip from Lean's GitHub release (926 MB, SHA-256 checked, 3.4 GB unpacked; a zip keeps
  no permissions Godot can read, so `bin/` is made executable - all 17 of its programs are there).
  `mathlib` is a new kind of managed row, a WORKBENCH: a Lake project written from
  `hosts/math/lean/` into `user://lean/mathlib-<tag>/`, requiring Mathlib and the Lean REPL at one
  tag. Lake fetches them with git; Mathlib's cache tool downloads the compiled library with curl
  (both the machine's own, `Deps.TOOLS`) and honors `MATHLIB_CACHE_DIR`, so nothing lands in the
  user's own caches. Fetched only when a Proof needs it, with progress, like the voice environment.
- **One tag picks all three.** Mathlib's release names the Lean it is built for (`lean-toolchain`),
  and the REPL tags the same names, so the version ghost fetches is not Lean's newest: it is the
  newest Mathlib release the REPL also has (`Provision.pick_mathlib`). On 2026-10-15 that was
  v4.35.0 for all three (Lean released it on 10-12, Mathlib 10-13, the REPL the same day). The
  daily update pass moves the three together; an episode records the tag it was checked with.
- **Measured by hand, 2026-10-15** (the steps the provisioner runs): `lake update` 145 s, which
  includes Mathlib's own post-update hook downloading and unpacking all 9,031 compiled files; the
  REPL built in 27 s; the check file (`import Mathlib` and one theorem) 97 s. 7.5 GB, plus a
  0.45 GB download cache removed afterwards.
- **A warm host.** The REPL takes JSON commands on stdin: `import Mathlib` once, then each snippet in
  that environment. Asked for every tactic (`allTactics`), it answers each tactic's text, position,
  the goals before it, and the library facts it used - for `induction n` on the sum of odd numbers,
  the `rw` step used `Finset.sum_range_succ`, and the goal before `ring` was
  `k ^ 2 + (2 * k + 1) = (k + 1) ^ 2`, which is the screen's best moment and the teacher's line ("all
  that is left is to expand a square"). A failed tactic answers with its position and Lean's words
  (`omega` gives a counterexample), and `#print axioms` answers `[propext, Classical.choice,
  Quot.sound]`.
- **More than one checker.** The 4.35 toolchain ships three independent kernels beside Lean's own
  (`leanchecker`, `lean4lean`, `nanoda`). The final proof can be re-checked by each, and the screen
  can say so.
- **For an openai/math manuscript**, its own `lean/` project is the workbench (Lean v4.34.1, its own
  Mathlib), so its proof is checked as published.

## Live, later - and what this plan takes from it now

A live stream is the solver working while the audience watches, a few minutes behind it. What it
needs and does not have (structure.md): a reading that takes text while it streams (today
`ReadingPanel._plan` builds every chunk at Play), a clock with no song (`Spectrum` has none
without audio), the storyboard's third source (a live queue), frames sent to an RTMP address (today
the encoder follows a finished file), and a show that never waits in silence when the solver is
slow (the pen taps, the teacher recaps).

None of that is built in the first pass. What the first pass takes from it, at no cost:

- **The trace is append-only**: `work/NNNN.json` rounds, never rewritten.
- **The lesson is written in closed segments**: each one's narration, marks, ink, calculations and
  Lean states exist before it is read, and nothing in segment N depends on N+1.
- **The desk's schedule for a segment never moves once made**, and the desk is a pure function of
  (segments so far, show time).

So an export is the case where every segment exists before Play, and live is the same desk fed
segments as they close. The live phase is then plumbing, not a redesign.

## Where it goes

Two folders, as Cards has two (`table/` the set and its medium, `cards/` the show agents make):
`desk/` (the set, the ink, the instruments, the medium), placed after `table/` because it borrows
the table's light, props and sound; and `proof/` (the episode, its producer, prompts, tools and
card), above `desk/`. The hosts go in `hosts/math/` (TeX layout, SymPy, the Lean bridge), with one
environment, `math_venv`.

Names (decided): the component is **Proof** (block `ghost: proof:`, workspace `proof`), the medium
**Desk**.
Seed hash salts start neutral (`proof-`, `desk-`) so a later rename never re-rolls an episode.

## The plan, in order

### 0. Spikes

- **0a. Ink.** *Status, 2026-10-15: done.* See [Ink](#ink). `hosts/math/typeset.py` is kept; the
  hand prototype stays in `dist/math_spike/` until step 2 writes it in GDScript.
- **0b. Lean and TeX, installed by ghost.** *Status, 2026-10-15: built.* Rows `tex`, `lean`,
  `mathlib` (and `git`, `curl`, `tar` as the machine's own); `Provision.extract_zip_tree`,
  `adopt_tree`, `pick_mathlib`, `parse_toolchain`, `workbench_ready`; the provisioner's workbench
  job, its Lean release chained through Mathlib and the REPL, an update pass that keeps on-demand
  rows current, and `--provision <key>`. Held by `provision_check` (whole trees, permissions, a
  member climbing out, the shallowest `bin`, one tag for all three with a REPL that lags as the
  control, a workbench stale by template or by tag) and `deps_check`. Run for real on the author's machine
  (`--provision mathlib`): Lean 4.35.0 and Mathlib v4.35.0 in 394 s end to end, 3.2 GB and 7.5 GB,
  the download cache removed, nothing in the user's own caches, and a proof checked through the
  REPL against it. Found on the way, each by running it: `_ask` parsed only JSON objects, so a list
  endpoint (releases, tags) came back empty; Godot's `ZIPReader` finds each member by scanning the
  archive, which is quadratic on a toolchain's 18,571 files (600 MB in four minutes, slowing), so
  ghost's own Python unpacks a zip tree behind a GDScript guard on the member names; and the
  Environment report did not know a workbench, so it called a built Mathlib "on first use".
- **0c. A solver by hand.** *Status, 2026-10-15: done - three of three verified.* A Claude job
  (`opus`, no settings, `python3` and file tools only, the way Cards runs a writer) with a checker
  script in place of the `lean` tool (`dist/math_spike/solver/`: the REPL's answer as plain text -
  errors, the goals before each tactic, the facts each used, the axioms - and the theorem's own
  Mathlib copies forbidden, caught through the facts used), a lab notebook to keep, and the exact
  Lean statement. Measured:
  - **Euclid** (`∃ p, n ≤ p ∧ Nat.Prime p`): 10 turns, 103 s, 2 Lean checks, verified on the first
    (the second only cleared a deprecation warning). Its exploration tabulated n! + 1 and saw for
    itself that it is not always prime (25, 121, 721 = 7 · 103) while its smallest factor always
    passes n - the classic misconception about Euclid's proof, found and corrected by experiment.
  - **The square root of 2** (`Irrational (Real.sqrt 2)`, the irrationality lemmas forbidden): 9
    turns, 72 s, verified on the first check, from lowest terms (`q.num`, `q.den`, `q.reduced`). Its
    exploration found the near misses 3/2, 7/5, 17/12, 41/29, 99/70 (99² - 2 · 70² = 1) - the Pell
    numbers, a lesson's moment on their own.
  - **Nicomachus** (the sum of the first cubes is the square of their sum): 9 turns, 68 s, verified
    on its one check, by induction on how both sides grow from n to n + 1.
  - Every notebook ends in a "What a learner needs" a teacher could build a lesson on as written.
  - **A safeguard stopped one run's last message** (`reasoning_extraction`) after its work and
    notebook were written. The prompt asked it to log "what you changed, why"; a classifier read
    that as asking for its chain of thought. So: the solver is asked for WORK WRITTEN FOR A STUDENT -
    attempts, what each gave, explanations - never for its reasoning or thinking; the `note` tool is
    a lab notebook's line, not a thought. And because every step is a file, a flagged final message
    loses nothing: the producer reads the files, not the reply.
  - What these do not show: a real dead end. Textbook theorems with a compile loop are within reach
    on the first try (four Lean checks across the three), so a lesson's struck-out lines will come from the exploration (a guess the
    table refutes) more often than from Lean, and from harder problems.

### 1 + 2, as one slice: something to judge in the app

*Status, 2026-10-15: built.* Asked by the user the same day ("is there ANY combination of components
I could attach to a note, to create the proof mode? ... the standard text editor, which would allow
a user to define the problem. Then, a second button: to generate a random problem to solve"), steps
1 and 2 were built together, thin, so the whole path can be judged in the app:

- **Attach "Proof" with "+"** (a `producer` row that brings a Voice and takes the presentation slot,
  workspace `proof`, block `ghost: proof:`). The note's words are the problem.
- **The card** (`ProofCard`): Invent a problem (the inventor writes a classic problem into the note,
  as an edit the note's Undo takes back), Make episode, Stop, Folder, New episode and a picker, the
  lesson's minutes, the writer, and a row per step with what its agent is doing and a ⟳.
- **The episode** (`ProofEpisode`, `ProofProducer`): `problem` (the framer: words, TeX, the exact
  Lean statement of `theorem main`, the forbidden facts, history), `solve` (the solver with
  `ProofTools` - notebook, lean, submit - over `hosts/math/lean_check.py`; a proof is accepted only
  VERIFIED, and an episode the solver could not finish goes on honestly unverified), `lesson` (the
  teacher, refused once if its speech carries notation), `ink` (TeX lays out every formula; one TeX
  refuses sends the lesson back once with TeX's words) and `script`. It waits, saying so, while
  Lean, Mathlib or TeX install.
- **The desk** (`DeskMedium`): a legal pad under a lamp, ruled, formulas on the rules, a page filled
  and then turned over the binding, a stroke through a struck line; the pen's nib is the ink's own,
  lifting between strokes and resting after, writing what the voice says as it says it; the camera
  follows the line being written. The words are the subtitle overlay's.
- **Held by** `tests/proof/proof_check.gd` (every prompt whole and the verified/unverified claim
  two-sided, the lesson's format and its notation audit, the episode's redo, the framer's answer, the
  pad's layout) and `components_check` / `rules_check`; looked at with `tests/desk/desk_look_probe.gd`.

**The first real episode, made by agents end to end** (2026-10-15, `user://proofs/ghost-dev/1`, a
dev run of exactly what the card does): 411 s from Invent to script. The inventor proposed Erdős's
"choose n + 1 of 1..2n and one divides another"; the framer fixed a faithful Lean statement and
named no forbidden fact (Mathlib has no copy); the solver tabulated odd parts with `#eval`, searched
every subset for n ≤ 6 to see the bound is sharp, and was VERIFIED on its sixth check - three of
them refused by Lean, one a real dead end (`simp made no progress`, the line deleted) that the
lesson tells and strikes through; the teacher wrote 790 words that open on a bet, define "divides"
before using it, play with numbers before symbols, prove it a line at a time, and say what Lean
checked; TeX refused one formula, which went back to the teacher once with TeX's own words.

Found by making it, each fixed and held:
- **`AgentTools` threw on a tool's error in words** (`bool()` of a String has no constructor): the
  solver's notebook calls were never answered, though their files were written. An existing bug
  (`DealerTools` says its errors in words too); `agent_tools_check` now holds an error in words and
  an empty one, and fails on the old line.
- **The safeguard stopped the solver again** (after one Lean check), though its prompt no longer
  asked "why": its system prompt said its work was recorded and its real attempts became the lesson.
  Reworded to deliverables only (a lab notebook for students, a proof), and the solve is tried up to
  three times - a sound run is the episode's heart.
- **`aligned` was set as a display**, which TeX refuses (`aligned` lives inside math): only the
  display environments themselves (`align*`, `gather*`) are.
- **TeX's `\implies` is two glyphs** (an equals sign under a kerned double arrow): the pad said
  "=⇒" with a gap. A bar kerned under an arrow is one long arrow now (`ink_check`, both ways).
- **The first look** (`desk_look_probe`): the lamp burned the white page out (the tablet's value,
  set for a dark screen), the camera stood far and aimed at the middle of the page, and the pen
  leaned away as if held from across the desk. Lamp 1.5, the camera 0.2 m from the line and aimed
  at it, the pen down and right from the nib as a writer's own hand holds it; the rules no longer
  shimmer at that distance (the page is a render target, with no mipmaps).

**After the user's first look in the app (2026-10-15):**
- **One choice of agents** ("We need to unify agent selection under a single codebase ... re-use the
  thing we already built from cards mode"): `AgentPick` (`ui/`) is Cards' row - the agent by its
  CLI's name, its models, its reasoning levels, a stored choice kept and marked when not offered -
  lifted out of `EpisodeCard`, which builds its writer and painter from it as the Proof card builds
  its writer. `agent_effort_check` holds both cards to it, and that they list the same things.
- **The channel's name, its byline and the episode's name** ("it's unclear what the title or
  episode name would even be ... adopt the title/byline thing from cards mode ... structure the
  agents' logic to create a proper episode name"): a Proof note's Title and Byline are the
  channel's, as a card show's are - on the title screen over the desk while the intro holds
  (`TitleCard`, lifted out of the card table so both media draw it; in the pad's own ink), and the
  YouTube title's `%title%`. The framer names the episode (`episode_title`, the `%episode%`) under the
  one rule every show's namer is given, moved out of Cards' producer into `rules/agents/episode.yaml`,
  for the line it goes up in (`YouTube.title_shape`, `YouTube.EPISODE_MARK`) and unlike the note's
  earlier episodes; with a description and tags. The upload adds, from Lean's own verdict, whether
  the proof was checked and by which Lean and Mathlib. A real framer, run on the Erdős note:
  "Ghost Notes: Why Choosing n + 1 Numbers up to 2n Forces One to Divide Another".
- **The panel's width** (a warning in the user's log: the card asked for 448 px of 380):
  `panel_fit_check` now builds the Proof panel too, and fails on the layout that warned.

**After the user's second look (2026-10-16):**
- **The opening and the close are the card table's** ("the intro/outro doesn't inherit the behavior
  from cards mode. We need the blurring effect and fade and such"): `ShowOpening` (`table/`) is how a
  show at a table or a desk opens and closes - the name over the frame thrown far out of focus
  (`IntroBlur`, lifted out of the table with `TitleCard`), the focus pulled as the show opens (the
  pen's first word), black a beat after the last word as the outro runs out, and where the thumbnail
  is taken. The table delegates to it, unchanged (`table_place_check`); the desk calls it.
- **The camera stands back** ("zoom far too close and tilted ... something closer to the book
  medium, with a further zoom and mostly vertical orientation"): see The desk, above.
- **Pages are filled, never wiped** ("a page with text on it is just 'wiped' clean, for seemingly no
  reason"): the `new page` mark is gone; a full page lifts at its foot and swings over the binding,
  the clean one under it.
- **The voice says what the pen writes** ("we need to narrate the text being written, as it is being
  written ... speak exactly what is written"): the dictation format above, phrase by phrase where the
  pen lags; the teacher is told it as a template with no sample words in it, and a lesson that leaves
  pad lines unread goes back once (`DeskScript.undictated`). The real teacher, rerun on the Erdős
  note, read every pad line on the line after it the first time ("Six, seven, eight, nine, ten.").
- **The pen leans to the top right** from its nib ("a more natural writing position"), which also
  keeps the line just written, left of the nib, in view.
- Held by `proof_check` (dictation spans and rests, the turn's rest, pages filled to their foot, and
  the desk's clock with no stage: the pen down on the first word and done on the last, the ink as far
  through as the words, a lagging formula at the pen's fastest and done before the voice goes on, the
  turn after the writing before it, the camera wide, close and back, the title until the first
  word).
- Found rendering the rerun lesson (`desk_look_probe`): TeX sets "ff" and "fi" as one glyph each,
  which the hand had no strokes for, so their outlines were traced and "different" read as bold. A
  ligature is written as its letters now (`Ink._ligature`; `ink_check`, with a longer name as the
  control). And the wide shot cut the pad's binding off: it stands at 1.45 m, the whole pad in it.

### 1. The episode, heard

The `proof` row in `Components.REGISTRY`, a `WORKSPACES` row, `ProofCard` (built by `NoteCards`,
handing the reading its walk, bed and publish), `ProofEpisode` (steps, needs, invalidate),
`ProofProducer`, `ProofTools`, `rules/proof/*.yaml`, `MathSpeech`. The lesson is heard over a bare
desk. Gates: the episode's steps and redos on fixtures (no agent), every tool's real output, the
speech audit with a control that must fail.

### 2. The pad and the pen (the slice above built the first of it)

`DeskScript` (marks to actions and speech; the hand, `desk/ink.gd`, is built), the desk
medium with the pad and the pen, the pen writing under the voice. Gates: ink is a pure function of
time (the same frame from two paths), every glyph in a test set covered, the voice's words equal
the marks' spoken words (two-sided, as `tablet_check`).

### 3. The instruments

The screen (Lean file, goals, the check), the calculator (keys, LCD, plots), the tablet (its pages,
reused), the camera's stations. Gates per instrument; a look probe, rendered sparingly.

### 4. The paper and the publish

`paper.tex` compiled; chapters from the arc's sections; the description names the sources and says
what Lean checked; the paper and the Lean file published beside the video (where is the user's
call - a repository of the channel's own is the natural home).

### 5. Live

The reading that grows, the clock with no song, the RTMP output, the never-silent wait. Its own
note when it starts.

## Risks

- **Agents and Lean.** Textbook and olympiad results are within reach of today's agents with a
  compile loop; research results mostly are not - OpenAI's release formalized about 42% after hours
  of compute each. Nothing in the plan depends on Lean succeeding: an episode without a check says
  so.
- **Misformalization.** Lean proves what it is told. The fidelity step, and both statements shown
  side by side, are the guard.
- **A wrong teacher.** Lean checks the theorem, not the narration. Sources for every claim of fact,
  the student and editor passes, and the author's own pass before anything is published.
- **A wall of symbols.** The teacher writes key lines, not everything it says; pages turn; the
  camera frames the line being written.
- **Weight.** Lean and Mathlib are gigabytes; an episode is hours of agent time on the
  subscription.
- **YouTube's rules.** Its monetization policy excludes mass-produced, repetitive content; the
  author's editorial pass per episode is what keeps a channel of these on the right side of it.
