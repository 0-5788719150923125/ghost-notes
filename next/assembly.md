# What is built on the table: many small parts, slowly

The user, 2026-11-02, of the brick show (`rift/cards/brick-by-brick.md`, renamed from The Spare Bin, its challenge cards gone):

> I just want to free-form build something from the LEGOs, in a meandering style, while talking about whatever people talk about when
> they are mindlessly building toy models ... a big box of bricks that we would sometimes dig through (bearing in mind we might want
> sound there), or piles of bricks on the table ... we might pull a brick, try to fit it, put it back, try a different one. We might
> build some structure, then destroy it and start over ... building a model from LEGO is probably not fast ... The video might be long.
> There might be stretches where we do not talk at all.

This replaces the plan in `next/table_work.md` section 8, which was written for a build that follows its steps. What stayed: an instanced
assembly on a lattice, one law that makes its acts, exact checks. What changed: **the puppeteer writes the meander itself** in the one
law, with no separate builder or booklet, and **a piece has a life before and after it is used** - it lies in a heap, it is dug for,
it comes off again.

**Status, 2026-11-02: built and gated; nothing has run with real agents, and nobody has heard it.** Open at the end.

## Trying it

1. In the notes list, "Existing note..." and pick `rift/cards/brick-by-brick.md`.
2. On the Pipeline card, Generate. The producer should plan `assembly: true`, a `quiet` near 0.5 and six to ten beats, the set dresser
   should build a hollow tub and write an `assembly` block, and the puppeteer's `act`s should come back with level maps.
3. Play. `Folder` opens the episode: `table.json` has the assembly, `acts.json` the steps, `jobs/acts/` the puppeteer's calls.

To look without any agent: `GHOST_PROBE_GPU=1 tests/run_boot_probe.sh tests/table/assembly_look_probe.gd 400 [--sheet] [--times 12,30]`.

## Why not the physics

`TablePhysics` is what the alchemy show stands on, and bricks stay outside it. Measured against the framework audit's rules:

- **Cost.** A body is surface points and a field. A tub is a thousand pieces. `MAX_WORKS` is 192.
- **Fit.** Interlocking studs fit to a tenth of a millimeter, and a positional solver held apart by that fit trembles
  (next/framework_audit.md has every chapter of this with corks and necks).
- **It would answer a question the lattice answers better.** A cell is taken or it is not; a stud holds or it does not. Exact, and in
  words an agent can act on, where a solver says "HELD BACK 4 cm".

What makes it possible is that **where things rest after a step does not depend on when the step happens.** So:

## A log, then time over it

`Assembly.perform` walks the steps once, in order, with no clock, and keeps for every piece each place it comes to rest and each move
that took it there. `Assembly.lay` then places those steps in time, and can do it again every sentence of a live reading:

- what has begun stays where it is (a piece in the air never jumps);
- what has not, takes the new time;
- a scrub is a lookup, and lands exactly where the same step left it;
- nothing is baked, so **an hour costs the same frame as a minute**, and live and export can only differ in when, never in what.

Measured on the probe's table: 0.4-0.8 ms of the app's thread a frame, with 479 pieces. Walking a 51-minute build of 404 steps takes about 2.5 s with the machine loaded, once for each puppeteer `act` and once as a note opens.

## Slow, by stretching the stops

A step has a **natural** time and a **floor** (`Assembly.OPS`). `lay` fits a stretch of steps to the time its words leave:

| time given | what happens |
|---|---|
| less than the floor | hurried to the floor, and it overruns; the next act waits behind it |
| between floor and natural | each move quicker in proportion |
| more than natural | **moves stay at a hand's pace, and the rest falls between them**, four times as much into a `pause` as elsewhere |

So a reader who talks long gets a builder who stops more, never one in slow motion. `tests/table/assembly_check.gd` `_time` holds it.

## What a table says, what an act says

**The set dresser** writes `assembly` beside `things`: colors by name, a `base` (its plate), and `stock` - each a pile `at` a place, or
`thing` naming a hollow thing it built. A container's inside is found by rays straight down (`TableAssembly._heap_of`), so any open tub,
crate, tray or dish holds pieces without being told how it is shaped, and a solid thing is refused in words. A deep one is filled
over a false floor: only its top layers are real, and nobody can tell.

**The puppeteer** writes `{"law": "assemble", "ops": [...]}`, its `length` left out:

| step | what the hands do |
|---|---|
| `dig` | stir a heap, moving what is on top aside, optionally looking `for` a part |
| `put` | find a piece, bring it over, line it up, press it on; `hover`, `first` and `look` are its indecision |
| `try` | bring one over and take it away again (`press`: on and off) |
| `look` | hold one up near the lens and turn it over |
| `pause` | nothing moves |
| `take` | one piece off, and whatever only it held comes away with it |
| `wreck` | a stretch or all of it pulled apart top down, chunk by chunk, dropped in with a clatter |
| `turn` | the plate turned, to see another side |
| `wall`, `fill` | a run of the same part, seams staggered, the hands in a rhythm (about 5 s a piece) |

**The agent says what, the hand finds where**, as `pour` and `dip` do:

- *Which piece:* the one of that part with least on it. A piece asked for is always there: a dry pass of the same walk learns what the
  steps need, and it is added to the stock before anything lands, soonest-used on top.
- *What has to move:* what lies on it goes aside first, in the step's own time, heard. A heap knows what lies on what (a cell keeps
  its pieces in the order they landed), so nothing is ever left on air.
- *How high:* `at` is `[x, z]`, and it comes down on what is there; `[x, z, level]` only to hang under something.
- *The way:* over what stands under it, by `Hands`, up first and down last.

`act` answers with what each act came to, what it COULD NOT do, and the whole model level by level as letters. `model` is the model from
four sides, close to. The rules name none of this: `rules_check` now bans "brick" and "lego" from `rules/`, and the words come from
`Assembly.describe()`, inserted only `when: assembly`.

## Silence

`<!-- quiet: 40 -->`, written by the reader where it stops talking (`CardReading.QUIET_MARK`). It is a rest as a table's move is
(`action-hold`), so it stays with the Hesitate box off, and it runs to `QUIET_MOST`, four minutes. Four things had to change, each found
by a failure:

- **A word budget.** `TablePrompts.reader` asked for words to cover all the work. The plan's `quiet` (the producer's, from the brief)
  now scales it down, and the reader is told how many seconds pass with no words.
- **A cue in a silence.** `<!-- act: x --> <!-- quiet: 30 -->` cued at the next word would wait out the whole silence. A cue with a quiet
  beside it is timed from the word before, plus how far into the silence it stands (`CardReading.quiet_around`, `TableWork.schedule`).
- **A beat that opens in silence.** A mark's move is placed just before the next word (`ReadingFollower.place`), so the beat began as
  its opening silence ended. The action now carries `lead`, and is placed before it.
- **A beat that ends in silence.** A beat's span ended at its last word, so the work stopped for the silence. The action carries `tail`.

If a reader writes too little anyway, `TableProducer.fit_silence` adds the difference as a silence before the last sentence, so the work
never runs on past the talk.

## Heard

`WorkSounds._plastic`, each step's own moments (`Assembly.sounds_in`): a molded piece is small and stiff, so it rings high and is gone in
a few milliseconds, pitched by its size. A press is a click with a knock of the body under it, a dig is many small knocks in bursts as a
hand goes in and comes back, never a steady rattle, and a wreck's pieces each clack as they land. Peak 0.052 in `assembly_table_check`,
under `PEAK_MOST`. **Nobody has listened to this yet.** The levels are measured and the character is a guess.

## Found while building it

Kept here because the code says what it does now, and not what it did:

- `(problems[_act] as PackedStringArray).append(...)` appends to a copy, so no step ever reported a problem (CLAUDE.md warns of exactly
  this). `problems` holds plain Arrays.
- A piece's clearance sampled the moment it was still rising out of its own heap, which drove every carry to the lift's limit and out
  of the top of the frame. It samples only where the piece is going across now, and a gate holds the height.
- A `wreck` grown by joined pieces took a whole running-bond wall in one chunk, since each joint holds up the next. A chunk grows only
  as far as it brings away no more than a hand takes.

- A plate turned sweeps its diagonal, and its corner went through a tub written beside it. Its room on the table is now the whole circle
  it sweeps (40 cm square for a 32-stud plate, so a big tub sits partly out of the frame; a smaller plate lets it closer), and a turn
  that would still hit something is refused in words (`Assembly._swept_into`).
- A fresh read of the code found four more, each now a test that failed first: a piece moved twice in a step had its second move laid
  past the step's end and snapped there (`_no_snaps`); a `wreck` drew its chunk sizes from the walk's own dice, which differ between the
  dry pass and the real one, so a part the dry pass found was sometimes not there (`_always_there`, 1 seed in 16); a `fill` closed an odd
  stud by running past its rectangle (`_fill_stays_in`); and a cue's silence was not capped as every other reader of it is.

## Open

- **By ear.** The plastic above; whether the room tone carries a four-minute silence; whether a rummage reads as a rummage.
- **By eye, in motion.** Contact sheets only so far. A held piece's drift, the plate's turn, a chunk coming apart as it falls.
- **Real agents.** Whether a puppeteer can design something recognizable from level maps and `model` is the biggest unknown here;
  `next/table_work.md` called it the risk. If it cannot, the sandbox's `run` (a shape filled in cell by cell, as Proof's solver runs
  Python) is the next thing to give it. Whether its meander reads as a person's, or as a checklist of the step names, is the second.
- **Limits a real episode may hit.** 40 acts (`Motions.MAX_ACTS`) at a few minutes each is about two hours; 120 steps an act; 1,800 pieces.
- **Tall things on the way.** A carry goes over what is under `Assembly.TALL` and through what is taller, unsaid; the set dresser is told
  to keep the way clear. It should be said in `act`.
- **Clear parts.** The old brief's see-through pieces: a second instanced material, not built. No figures, by the brief.
- **Bodies near the build.** A thing an act moves meets the things, never the bricks: `TablePhysics` does not know they are there. A
  mug carried over the plate would go through a tower. The puppeteer has no reason to yet, since the rest of the table sits still.
- **The jigsaw** (`corner-by-corner.md`) was to share this. A flat lattice of different pieces, `Assembly.KINDS` is bricks' own, and
  `AssemblyHeap` would hold its pieces unchanged.
