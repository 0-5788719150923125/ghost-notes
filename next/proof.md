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
The `proof:` block holds the dials: `level`, `kind` (solve, explain, explore - inferred from the
brief when not set). NO LENGTH (2026-10-16, the user: "I would prefer to just make videos as long as
they need to be"): a lesson runs as long as its proof takes to teach - unless the note's words ask for
one (2026-10-20, "The length the note asks for" below).

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
  as an edit the note's Undo takes back), Refine (below), Make episode (Remake episode once anything
  is made), Stop, Delete…, Folder, New episode and a picker, the writer, and a row per step with what its agent is doing and a ⟳ (the lesson's minutes
  were a dial here until 2026-10-16 - see "No minutes" below).
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

**After the user's third look (2026-10-16)**, the second episode exported and on YouTube:
- **A letter is said as a letter** ("The voices are pronouncing 'a' wrong; because they're using it
  like a part of a sentence ... maybe a macro that could be used to override phonemes"): `[a]` in any
  script is the letter's name, shown as `a` in the subtitles (`TextNorm._expand_core`, the `letter`
  row of `ScriptMarks`). The teacher writes every letter that names something that way, and
  `DeskScript.bare_letters` sends back a lesson that reads a formula's `a` as a bare word, or puts a
  bare "a" before a comma or a stop, which no article is.
- **The pen draws** ("at the very least ... charts/graphs/drawings upon the paper itself ... today,
  the model just writes a title, then sits there explaining"): a `draw` mark holds an SVG over as many
  lines as it takes, dictated like a formula. `hosts/math/figure.py` reads it with svgelements (MIT,
  in `math_venv`) into pen paths - lines, curves and arcs flattened, a small filled shape a dot, a big
  one hatched (only a fill the SVG asks for: SVG's default fill is black), dashes, hand-drawn
  arrowheads - and its `<text>` labels are set by TeX in the same run as the formulas. `<axes>` draws
  numbered axes on a box of the figure, and inside it `<plot fn>` is COMPUTED from its expression (an
  arithmetic-only parser; broken where undefined or jumping, cut at the range's edge), so a curve is
  never an agent's guess. The hand draws paths a little uneven, pinned at their ends, at 2.6 times its
  writing speed; a figure is centered in the column. Held by `test_typeset.py`, `ink_check` and
  `proof_check`; looked at on a fixture lesson (a number line with root two, y = x squared, stones and
  a square's diagonal).
- **Plain words, and a student** ("some concepts are unexplained, or not going into enough depth ...
  the model was trying to be 'poetic' - which is absolutely not helpful here"): the teacher's rules
  were rewritten (define every term with numbers, history included; every step names its rule; the
  facts the proof stands on are taught; no metaphors, personification or flourishes), and two sample
  phrases the old prompt held were taken out - both came back in the second episode almost word for
  word. The lesson is three steps now: `draft` (the teacher), `review` (the STUDENT reads it as the
  episode's viewer and notes where it loses them, as `{quote, need}`, never its reasoning), `lesson`
  (the teacher again, from the draft and the notes). An episode whose lesson was written before there
  were drafts is not drafted again behind it (`ProofEpisode.moot`). Run for real on the
  irrational-power problem (`user://proofs/ghost-dev/3`, the second episode's solved work copied in):
  the student's twelve notes were the right ones (Gelfond-Schneider named but never stated, case B
  never checking that b is irrational, the power rule used on irrational exponents with no word on
  why it still holds, "real number" undefined), and the second lesson answered them in plain words -
  and ran 1,995 spoken words on a six-minute dial. THE DIAL WAS LOOSE BEFORE THAT: the budget assumed
  140 words a minute, the rate a voice reads at alone, and the second episode's take spoke 1,014 words
  in 9:01 - 112 a minute with the pen's rests. The budget is the measured rate now, the second draft
  is told to stay in it (room for the notes is cut from asides, repeats and detail), and a lesson
  over 1.35 times its words goes back once (`ProofPrompts.LONG`). All of it went the same day - see
  "No minutes".
- **The thumbnail** ("did not use the proper thumbnail ... the same thumbnail that cards-based modes
  use"): the Proof card's upload never named the title screen's moment, so the exporter took none and
  YouTube chose a frame. It names `ShowOpening.thumbnail_moment` at the take's intro now, as Cards does
  (`proof_check`, on the first frame: the card names the Director).
- **The category** ("every video is uploaded ... under the 'People & Blogs' category"): the YouTube
  card picks one of YouTube's assignable categories (`YouTube.CATEGORIES`); People & Blogs until it is
  changed.
- **Refine** ("I want the agents to look at what I've written in the script, and give in a more
  fully fleshed-out structure there ... rewrite the entire thing, to define the problem better", on a
  note reading "Explain the 6 trig functions"): a button beside Invent. The refiner
  (rules/proof/refiner.yaml) reads the note as it stands and writes it back whole - the title, the
  question, the claim in LaTeX, what the viewer learns, who it is for, what to show on the pad, where
  it comes from, and anything else asked. Everything the author asked
  for is kept; a topic that is not a claim is given the claim at its heart, proved while the topic is
  explained. One agent writes the note at a time (`ProofCard.NOTE_WRITERS`), and the edit is the
  note's own (its undo takes it back).
- **No minutes** ("I feel like the ability to set a video's runtime in minutes was a bad idea. I
  would prefer to just make videos as long as they need to be, because otherwise you're stretching
  them to fill the minutes requirement, or you are compressing them and teaching the content too
  quickly"): the card's Minutes dial, the word budget (`WORDS_PER_MINUTE`), the over-length retry
  (`LONG`) and the figure count by minutes are gone. The teacher is told the lesson has no set length
  and is told against both failures - never stretch it (no repeats, no second example of the same
  thing, no aside that does not serve the proof), never rush it (no step or definition the viewer
  needs skipped or squeezed); the second draft answers each note where it arises, in as few plain
  sentences as it needs, and cuts what does not serve the proof; a lesson draws at least two figures.
  `proof_check` holds that no agent is handed minutes or words, and that a lesson of 4,500 spoken
  words lands on its first try. If lessons come back bloated, the fix is in the teacher's words.
- **The length the note asks for** (2026-10-20: "a 5-10 minute request in the script turned into a
  36-minute export, in reality. Why didn't the agents prioritize a shorter script ... Do we give them
  any tools or ability to estimate the runtime?"): every agent read "about 5 to 10 minutes long" in
  the note (its "Also asked"), but the teacher's own prompt said "the lesson has no set length", and
  nothing could tell it how long it ran. The first draft came back at 3,030 spoken words (about 26
  minutes), the student's twelve notes asked for more, and the lesson answered them at 3,930 - 36
  minutes on the export. Still no dial and no budget of our own: the framer reads the length the note
  asks for into `minutes` (`[least, most]`; `ProofProducer.minutes_of` keeps only a sound pair), and
  only then the teacher is handed it as spoken words in place of "as long as it needs"
  (`ProofPrompts.length_of`: 5 to 10 minutes is 580 to 1,150 words), met by what is taught - never by
  talking faster, and a lesson done sooner is never stretched. The second draft and the student are
  told how long the first runs (the student asks only for what it cannot follow without, and marks
  what could go when the draft runs over), every take's length is in the log, and a take more than a
  fifth past the most asked goes back once with the others' faults (`too_long`, `LONG_BY`). THE
  ESTIMATE: `DeskScript.runtime` - spoken words at `SAID_WORD` (0.52 s, pauses included, measured on
  the three exports: 0.49 to 0.53 s at the Narrator's pace 0.9) plus the lesson's rests; before the
  ink it put episode 6 at 34.7 minutes, against 35.8 minutes of reading on the export. A voice set
  faster or slower is not yet read into it.
- **The pen points, and is never still for long** (on the six-trig-functions episode: "the model has
  gone for minutes just staring at a static page, while describing what is on the page, but never
  POINTING to any of it ... I was not able to follow what the model was talking about, and after 2
  minutes of no movement - it's very hard to get my attention back on track"): the lesson's longest
  stretch of speech with the pen idle was 496 words (about four and a half minutes; the earlier
  episodes' were 200 and 283). A thing on the pad can be NAMED - `<!-- pad #name: ... -->`, an SVG
  element's `id` (on a `<g>` for several, inside `<axes>` too), a formula's `\pin{name}{...}` - and
  `<!-- point: name -->` INSIDE SPEECH sends the pen there at the next word, held to the sentence's
  end (`DeskScript`). typeset.py reads the pins back from TeX's own specials, figure.py the ids, each
  as a box in the record's `anchors`. At the desk the nib comes down close (3.5 mm) beside a small
  thing's foot, to its right, or sweeps under a wide one left to right, so the pen's body leans away
  over clean paper; the camera goes there; a point at a page already turned leaves the pen be. A
  lesson that says more than 80 words with the pen idle (`DeskScript.still`) or points at a name
  nothing carries goes back once; the student marks both. Every take is checked and the log says how
  it stands - kept with its faults named, or passing after a send-back (2026-10-19: "Was the problem
  fixed or not?" - a second take was taken unchecked, in silence); what a take was sent back for is
  told to the take TeX sends back too, since that one is written from the draft again.
- **The hand is alive** ("the pen being at a completely static angle feels awkward ... A hand holding a
  pen would never keep it at a perfectly static angle"): `DeskMedium.lean` sways the lean a few
  degrees over seconds about its top-right direction, turns it toward the page's top as the nib goes
  left (a forearm pivoting at the elbow), and trails its top behind the nib's travel; `drift` moves the
  nib a few millimeters off the paper, in proportion to how high it is held - never while it writes.
- **Teach what this proof uses** (the same episode ran about 58 minutes - "possibly too long"): it
  retold every numerical check in the notebook (pi/3, pi/6, x = 2.5, x = -0.7, the computer's
  infinities), Lean's three axioms, and a similar-triangles detour on where the names come from, and
  put Lean's own code on the pad. The length stays the lesson's own; the teacher is told to teach
  only what the proof uses, to tell the steps that lead to it rather than every check, and to keep
  Lean's code and inner workings out; the student marks a stretch spent on what the proof does not use.
- **Delete and remake** ("There is currently no way to delete an episode. There is also no way to
  entirely remake one. ... Delete should be a button, while 'Make Episode' should probably just
  regenerate the entire thing"): once anything of an episode is made, Make episode reads Remake
  episode and, after asking, throws every step away and makes it all again from the note; Delete…
  asks, then sends the episode's folder to the system trash (`ProofEpisode.trash`) and opens the
  newest one left. A step's ⟳ also goes on from a step that failed or was never made - what Make
  episode did before. While a take of an episode renders it is pinned, and neither is done to it.
- **A phrase is never broken** ("A point is named by two numbers" had "like 5 seconds of silence
  between 'two' and 'numbers' ... flow completely broken by the interrupted sentence"): a dictation
  the pen lags rested at punctuation OR after any six words, and "two" was the sixth. It rested at
  punctuation only for a day; since 2026-10-17 it does not rest inside a dictation at all (below,
  "the pen is elastic"). The wait itself was the pen writing a whole sentence of prose (23 s of hand
  for 3 s of words), so the teacher is told a line of pad text is a few words, and the rest is said.
- **The pen keeps up with the voice** ("there is still a super long pause at the end of this ...
  rather than breaking the audio, should we increase the speed of writing ... to track with the audio
  better?"): `DeskScript.MAX_PACE` 1.8 -> 4.0. On the six-trig-functions episode the rest at "numbers:"
  went from 6.5 s to 1.7, and the whole episode's rests inside dictations to 7, 5 s in all.
- **The pen is elastic, and never stops mid-line** (2026-10-17: "the pen stopping at weird moments -
  like halfway between drawing a straight line, pausing for a second or two ... If the speech is
  gaining too far ahead, speed-up the pen. If the pen is too far ahead of the speech, slow down the
  motions. But NEVER should we just be stopping ... We shouldn't be forcing arbitrary breaks in the
  speech, to wait for the pen, nor should we be forcing arbitrary breaks in the pen movement, to
  wait for the speech"). The ink's clock was the share of the dictation's words said, which stands
  still in every gap between words, so the nib froze mid-stroke at each comma and breath - and where
  the voice rested FOR the pen, the pen, waiting on words, rested too. `DeskMedium.elastic`: the
  voice's progress smoothed over 1.5 s, stretched onto the pen's time (a pen that lags runs behind
  evenly the whole way), with 0.3 of the progress steady - so it slows over a pause to about a third
  of its average pace and makes it up over the words after, and is always moving. The voice no longer
  rests inside a dictation (`DeskScript.paced` is gone): what the pen owes at 4 x is one rest after
  the dictation's last word. On the trig episode, read by a steady voice, the longest the nib stands
  still while writing is 0.17 s (the ink's own ease at a stroke's ends); 50 dictations leave 16 s of
  rests after them. `proof_check` "the elastic pen", with the old clock as the control (1.6 s still).
- **What is on the page stays** (2026-10-19: "two graphs are drawn side-by-side. Then suddenly, the
  2nd one disappears and is re-drawn", and again at 3:50). A live reading's words arrive a sentence
  (a chunk) at a time, when it is decoded - at most 9 s ahead of being heard - so a drawing dictated
  over several sentences was planned on a guess at its last word's time, and the plan was made anew
  as each sentence came in: a voice slower than the guess moved the end later, the share written fell,
  and the newest strokes were taken back (up to 20% of a drawing; a faster one made it jump ahead at
  19x the pen's pace). Now `DeskMedium.take_words` holds the past before the new times are taken in
  (`_hold_past`): what began keeps its start and its page's turn, what is done stays done, and a line
  being written goes on from where it is over what the new plan leaves it (`_ink_time`). An export,
  whose times are all known at once, is planned once and stays a pure function of time. Replayed on
  the Universal Approximation episode (`dist/math_spike/desk_replay.gd`, voices at 0.85-1.3 x the
  rehearsal's pace, words 3-9 s ahead): seven drawings went back before, none after. `proof_check`
  "what is on the page stays", with the plan made again unheld as the control (16% taken back).
  Found measuring it: a reach was "never longer than the wait", and an action that began the moment
  the last ended (a point said while its drawing was still being written) had none - the nib crossed
  326 px in one frame at 338.8 s, 195 px at 767.8 s. `_build_plan` now starts no action before the
  nib's way from the last (`DeskMedium._way`); the control, the point begun as the formula ends, 555 px.
- **A word the voice says its own way never stops the desk** (2026-10-20, "What Can One Row of Neurons
  Imitate?": "got stuck and just hanged there, after a few minutes. All animation stop, and the pen just
  stood in one place swaying for the rest of the video"). At 1:50 the lesson said "the [c]'s": the page's
  word is `cs`, the voice said "c" and "'s", and the follower (`ReadingFollower`) took a one-letter word
  only as a whole word - it found the next `c` seven words on, those seven were never heard, and
  `_build_plan` stopped at the first action anchored on one: 9 of 51 actions placed, the pen parked for
  the last eleven minutes. Now a one-letter word starts the page's next word when it begins it, and a
  word the voice goes past unmatched has the time it was most likely said (`said0`/`said1`: the voice's
  loose words in its place, else an even share of the gap, and past the last match one loose word
  each) - the desk waits only for what the voice has not reached. On the exported take: 1278 of 1278
  words matched, 51 of 51 actions placed. `proof_check` "a word the voice says its own way".
- **A drawing takes its time** (the same day: "a lot of the chart and picture-drawing felt REALLY fast,
  relative to the voice describing the charts. It felt rushed, when it could have been a lot slower and
  there still would have been plenty of buffer room to prepare for the next thing"). A drawing's line
  is a few words ("Axes from zero to one, the neuron's graph, and its corner.") and its ink long - every
  tick's number and label handwritten, half of it the pen in the air between them: the episode's seven
  drawings had 26 to 59 s of ink at the hand's pace, were held to their lines at 3.6 to 4 x it (6 to 15
  s), and the pen then sat 2 to 11 s before its next action. Now a drawing runs on past its line through
  the talk about it (`about`, the paragraph after its dictation), never slower than the hand's own pace
  (`DRAW_PACE`), done `DRAW_SETTLE` and the nib's way before the pen's next action is due
  (`DeskMedium._drawn_by`) - no action later, the voice unchanged. On the exported take: 2.2 to 3.8 x
  (2.8 on the whole, from 3.9), 92 s of drawing for 66; frame by frame no action starts later, the
  biggest move in a frame 74 px (97 before), 14 frames over 60 px (148), the nib 13.6 px a frame while
  drawing (18.7), no ink taken back (`dist/math_spike/pen_frames.gd`). The rest is the teacher's: a
  drawing's line now gives each axis, curve, shape and label a phrase as it is drawn (teacher.yaml).
  `proof_check` "a drawing takes its time", a formula as long held to its words as the control.
  Found replaying it live (`dist/math_spike/desk_replay2.gd`, the same with drawings held as the
  control - both alike): a point the next one cuts to 0.3 s stopped its 0.9 s sweep a third of the way
  and the nib jumped 366 px in a frame to where the wait starts; a cut sweep now finishes in the time
  it has (widest frame 133-163 px at 30 fps, voices x0.85-1.3).
- **An idle pen gets out of the way** (2026-10-19: "as it told the story, doing nothing, for ~30 or
  60 seconds, the pen was just frozen, right in the middle of the page, covering a bunch of the text's
  visibility ... it would be better for the pen to drift to the right and top"). Over 40 words or more
  with nothing for the pen (`DeskMedium.PARK_WORDS`, read off the script so it never changes its mind
  as a streamed voice's words arrive), and before every page turn, the nib goes right off the written
  lines, then up the pad's edge to `PARK` (off the pad's top right), and comes back as the next action
  begins. Episode theorem-proving/5 has 23 such waits of 121, up to 75 words. Found on the way: the
  nib JUMPED to its rest the frame each action ended (136 px), and across the page as one was about
  to turn it (1025 px in a frame); every reach took 0.45 s however far (30 of 110 crossed most of the
  page in it); and the old wait at the page's right stood in the turning sheet's way in 26-28 of a
  turn's 96 frames. Now every move is continuous and a reach takes its way at 1000 px/s
  (`_reach`); a page turns only once the pen is off the pad (`PARK_CLEAR`), early enough for the pen
  to come back behind the sheet (`PARK_BACK`). `proof_check` "an idle pen gets out of the way" and
  the turn's sheet checks (the pen a rod along its lean against the sheet's plane).
- **A page is turned as a hand turns one** (2026-10-19: "When a page is turned, it sort of just
  disappears. Can we do a proper page turn, which gently lifts the head of the pad and folds the paper
  around the back? ... a turned page will COVER that top part of the paper. And multiple pages might
  fan-apart a bit, giving more depth"). `LegalPad` (desk/): the sheet is lifted at its foot, its
  bottom right corner ahead, and rolled up the page - flat to where it has lifted, round a bend that
  tightens as it nears the binding (the notebook's photo curl, page-long), its free end trailing; the
  pad's head is lifted on its foot (24 degrees at most, `tilt`), the free end curls down behind it and
  under, and the head comes down on it as the curl tightens round the binding. The page stays there:
  each later page goes round it a loop's width rounder (the newest outermost - its root lies under the
  older roots), the loops' bulge covers the page's top above the first rule (58 px of the 196 before
  it), and eight are drawn. A turn takes 2.2 s (`DeskScript.TURN`, was 1.6) and the pen comes back once
  the head is down (`PARK_BACK` 0.93). A first cut left the page lying flat on the desk behind the pad -
  what a page does on a desk, but it read as a sheet on the desk, not one turned on a pad. Measured:
  eight pages over and a ninth turned over them, no two sheets cross and none goes into the pad or the
  binding (the control, the turning sheet given the innermost loop, crosses); on theorem-proving/5 the
  pen meets a turning sheet in 0 of 924 frames and the loops in 0 of 34,862, and is never late for the
  line after a turn. The camera stands back 3 s before a turn (its springs are slow) and aims higher,
  at the head, where the page goes round (`TURN_BACK`, `TURN_AIM`); the pages' textures take the
  book's five-tap filter, so the thin margin line no longer breaks into dashes in a wide shot.
  `proof_check` "a page turned".
- **Every desk is its own** (2026-10-19: "a little bit of variety, of color, of the table, of objects
  on the table ... borrow from the cards mechanisms ... It would be very nice if the table could have
  a proper texture"). `DeskLook` (desk/), from the episode's seed: the pad's paper (canary, white or a
  pastel), rules, margin and binding, the ink (always 8.6:1 or better on its paper), the pen's lacquer
  and trim, the lamp's warmth and place, the desk's top built as the card table's is (`Tables`: wood in
  boards or a slab, stone, lacquer, leather or baize, with its relief), a felt or woven mat under the
  pad about half the time, and up to five things on the desk made as the card table's are (`Props`):
  a mug, pencils, a cup of pencils, an eraser, books, paper clips, index cards or sticky notes, a
  ruler, a small cactus - each sized and colored by the seed, never on the pad, behind it, or (tall)
  beside its right edge where the pen leans out. No agent and NO PAINTER (the user: "There is nowhere
  to set the 'Painter' on the Proof card; so how would the generative table and props even work
  there?"): every surface is a shader pattern from the drawn numbers, and the card table's one painted
  surface - a top or layer that is the episode's painting, or the old reading cloth `Tables.sanitize`
  lays when handed no layers - is never chosen (proof_check). An existing episode gets its desk on the
  next play. NOT BUILT: a desk an agent dresses for the problem (the card table's set dresser, its
  blueprint and its photographs) - things chosen for the topic.
- **More to draw with** (2026-10-19: "do the agents have the ability to draw charts, line graphs,
  etc.? ... the ability to draw arbitrary pictures would be useful: for example, if we wanted to draw
  a tree, and use trig functions to measure the height"). They could already draw graphs of a
  function of x on axes, dots, labels, dashed lines, arrows, hatched fills and any outline an SVG
  path makes. Added to `hosts/math/figure.py` and told to the teacher (rules/proof/teacher.yaml):
  curves of t (`<plot x="" y="" t=""/>`) and polar curves (`<plot r="" t=""/>`), cut at the box's
  edges; bars (`<rect>` in the axes' units, hatched when filled), circles and ellipses in them; a
  faint grid (`grid="true"`, a fine light line per tick - dashed, it was 434 strokes); ranges and
  ticks written with pi, numbered in pi; `<angle>` marks (an arc between two directions, or a right
  angle's corner); and the rule that a problem about a thing in the world draws that thing as a plain
  outline with its lengths and angles marked. test_typeset.py holds each, with a control.
- **Not only math** (2026-10-19: "I don't want to specialize that mode too much on just math: it
  should be a general theorem-prover and learning tool"; the first Universal Approximation note came
  back as its simplest case - one input, on-off switches - because the refiner was told "short and
  elementary"). Two halves:
  - THE WORDS: every agent is told of "a channel of lessons", not of math; the inventor draws from
    twenty fields (number theory to orbits, epidemics and machine learning); the refiner and the
    framer keep the depth the note asks for where the team can do the work, and say what a nearer
    claim leaves out; the teacher and the student take the viewer from the framer's `audience` alone
    (both had also been told "arithmetic, fractions and a little algebra").
  - A SECOND KIND OF CHECKED WORK, A COMPUTATION: the framer's `check` is "proof" (Lean, as before)
    or "computation" (what is computed, fixed as a statement is; `land_problem` refuses one that does
    not say). The solver gets `run` (`ProofTools`): Python in the compute environment (`compute_venv`:
    numpy, SciPy, SymPy) inside a bubblewrap sandbox (`hosts/compute/run.py` - the system read-only,
    one folder to write in kept between runs, a sized /tmp, no network, nothing of the author's; its
    memory, processor time, files and folder capped, killed at its wall time). `keep(name, x, y)` keeps
    a series, which the teacher's drawings plot by name (`<plot data>`, `<dots data>`, `<bars data>`,
    figure.py) - never numbers typed in. A computation is handed in as its result with the runs that
    show it (each one that ran to its end) and lands `computed`; the teacher is shown those runs first,
    says the numbers come from code that ran and what a computation does not show, and the upload says
    so. A proof's solver may run code too. Where there is no bubblewrap (not Linux, or not installed)
    nothing runs: `run` is not offered, the framer is never offered a computation, and a computation
    framed before fails at the solve saying to install it. Held by `proof_check`,
    `hosts/compute/test_run.py` (the sandbox, each limit beside a control run plainly) and
    `test_typeset.py` (the series drawn). NOT BUILT: a sandbox on macOS (`sandbox-exec`) or Windows.
- **A scrub no longer stops the pen** ("scrubbing the timeline seems to have broken the pen
  completely. For the remainder of the video, the pen doesn't move at all"): a scrub starts the voice
  again from a later chunk, and the desk matched the new words from the top of the lesson - a
  twelve-word window found none, so nothing after it was ever scheduled. The desk now reads the
  document's `start_words` (as the card table and the tablet do) and starts there; `proof_check`
  holds both sides.
- **The trig names "pronounced very strangely"** (BUILT - next/voice_engines.md, "a word eSpeak has
  to guess at"; the user, on the clips below: "B sounds quite a bit better"; the report: cosine "co-seen", cotangent
  "co-angent", cosecant "co-seh-cant"): eSpeak, which the neural voices use, gives kˈoʊsaɪn,
  kˈoʊtændʒənt and kˈoʊsɛkənt - the core syllable unstressed in each, and the voice slurs an
  unstressed full vowel ("sine" to "seen", the t of "tan" lost); cosecant's vowel is wrong too. A
  dictionary does not settle it alone: Wiktionary's US cosine is /ˈkoʊ.saɪn/, eSpeak's pattern;
  Merriam-Webster marks a secondary stress (\ˈkō-ˌsīn\). CMUdict has none of cosine, secant,
  cotangent, cosecant, hypotenuse or radian; Wiktionary has them all (kaikki.org: a JSON file per
  word, US IPA, topic tags). Two clips for the user's ear, speaker 13 of en_US-libritts-high:
  dist/math_spike/stress_ab/A_as_now.wav and B_core_stressed.wav (kˈoʊsˌaɪn, kˈoʊtˌændʒənt,
  kˈoʊsˌiːkənt). If B is right, the fix is general: a word CMUdict lacks (eSpeak guessing) gets a
  secondary stress on each unstressed full vowel, and Wiktionary's vowels where eSpeak's differ.
  NOT HEARD AT FIRST (2026-10-17: the export "sounded exactly like the original"): the reading
  marked a word `rare` only when its page spelling matched its spoken one, and the page spelling
  keeps its marks - "cosine," is not "cosine" - so in the list every one of the three, each with a
  comma or a stop after it, went to eSpeak's guess ("secant", with none, was fetched). Now
  `Phonemes.guessed`, its marks aside; `g2p_check` "guessed" holds the list.
- Still to come from the user's notes: the instruments (step 3) - "an actor that could browse the
  internet on a tablet, perhaps pull up a wikipedia page and read from it, perhaps compute on a
  calculator ... we would pivot from one tool to another".

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
