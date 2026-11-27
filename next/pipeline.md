# The Pipeline card

One stable card lists everything agents and tools make for a note, and its regenerate button always regenerates exactly
the one thing its row names, with no second list appearing.

## What was wrong (measured in the code, before)

Six lists of steps each had their own widget code: Episode's rows (`EpisodeCard._add_row`), Proof's (`ProofCard._build`),
the Letter's (`LetterCard._build_rows`), `ActorStepRows` (Actor, Voice training), `EpisodeStepRows` (Proof, Letter,
Actor, `NoteUpload`), and the Pictures' (`IllustrationPanel`).

Other cards' steps reached four different places (`hand_publish` and `steps_by`, a card's own `_added` and `_added_rows`,
or the YouTube card listing them itself through `NoteUpload.hosting`), and a docs.py rule existed only to keep that
straight.

⟳ meant four things:

| Card | ⟳ did |
|---|---|
| Episode | always a menu, even of one item (`MenuButton`, `REDO`) |
| Proof | at once, with everything after it, thrown away unasked |
| Letter, Tags, Thumbnail | at once |
| Actor, Voice training | a dialog first |

Two more traps: the Episode menu was the only guard on a stray click (its Plan item deletes every painting and reading),
and ⟳ on a step whose inputs were not made did nothing and said nothing (`TableProducer.tick` passes it by).

## The design

**One card, last in the deck.** `PipelineCard` (`src/ui/`) is the last card on the panel, in the one scroll, and its title
bar lies on the panel's bottom pile until it is scrolled to, so it is always in sight and one click away (`PanelDeck`,
next/panel_deck.md). Generate, Stop and the tally are on its title bar and work wherever that bar lies. It has no
component and no "+": it appears when something on the note has something to make, and is gone when nothing does.

**One way in.** A card answers `pipeline() -> PipelineSection` (`src/notes/`). `ReadingPanel._offer_pipeline` adds it. That
is the whole contract: no card names another, none is told where it stands, and which card "hosts" what is not a
question. `hand_publish`, `steps_by`, `hosting`, `_added`, `_added_rows`, `EpisodeStepRows`, `ActorStepRows` and the
old docs.py rule are gone.

A section's rows are `PipelineRow`s: a key, a name, a state, what it says, and what its ⟳ does.

**One ⟳.** Every distinct regeneration is a row of its own, and its ⟳ does exactly that one thing. Never a menu. An
Episode card has four rows: Design, Painting, Reading, Over its work.

**The guard, in the open.** A ⟳ that would throw away other finished work says so on hover and asks once - a yes or a no,
never a list - naming what it throws away. It asks only when there is such work, so the ⟳ on Plan cannot lose an episode
to a stray click. Every ⟳ is one color; the hover text and the question carry the warning. The dependents are worked out
from the steps' own dependencies once per change of the episode's files (`TableEpisode.dependents` parses JSON per call,
and at a row each four times a second it would cost a playing show).

**One Generate.** Top to bottom, every section's missing work in turn, each waiting for the one before: an episode's words
first, then what is made from them. A section's own ▶ on its heading makes only that section, so "paint the missing
pictures, not the tags" is one click. GENERATE RUNS THE WHOLE OF IT: a section done but still missing what its last ask
opened is asked again (the studio's things designed, then the sounds made on them), and at the end the walk goes round again
for every section still missing while the last round started anything (the studio's sounds, from the script the episode writes
below it) - bounded (`AGAIN_MOST`, `ROUNDS_MOST`), so a section whose asks start nothing is asked no more. While Generate walks, rows whose owners accept queued requests stay available;
other ⟳ buttons wait. Stop stops it all. What Generate was asked
goes on with the settings it was pressed with: a note opened again while it walks (a format picked, a card attached or
taken off) builds its panel anew, whose cards take up what is being made (`TableProducer.of`) and whose Generate walks on
(`PipelineCard.carry_on`).

An episode's regeneration requests join its producer's current run. Other rows stay available while one runs;
requested rows show as queued and take no duplicate request. Each waits for its inputs, including remakes farther
upstream through an unchanged intermediate step. Queuing preserves the active jobs, their settings, notes and retry
counts. Generate can widen the run to the whole episode; Stop clears the requests and stops the active jobs.
If an input fails, dependent requests wait for it to be retried rather than using the previous output.

Generate includes stale unlocked episode steps even when every file exists. The set of files alone does not decide
whether there is work: changing a passage or releasing its lock takes effect on the next refresh. Every made output
has a lock, including Script and other derived outputs with no regeneration button. An unlocked stale Script is rebuilt
locally from the passages by Generate, or after a passage is regenerated; a kept Script waits until it is unlocked.

The episode's Voice row is an optional saved narration. Until it is requested or a recording is saved it is excluded
from the tally, so an unused recording leaves a completed episode complete. Its action waits for a ready voice;
once requested or saved, its running, made or stale state counts normally.

**Rows cost nothing to ask for.** The card asks every section for its rows four times a second while something is
being made, so a step's progress is seen as it moves, and once a second while nothing is (`PipelineCard.EVERY`,
`EVERY_IDLE`); what the card itself changes is shown at once. So A SECTION'S ROWS NEVER ASK THE DISK: what a row says
is read from what its owner holds in memory, which the owner looks at again when it writes or is told to. The
Pictures' rows asked the library about each picture's versions a score of times, each a look at every file: seven
hundred looks a refresh for thirty pictures, most of a frame. The library holds what it found
(`Illustrations._held`: the versions and references on disk, the look's signature) until it writes, or the window is
come back to (`look_again`). Gate: `tests/media/pictures_held_check.gd`. The same holds for a card's own refresh:
the YouTube card asks for the note's title, episode, author and book twice a second, and each ask read the whole
note file; `DocSource.field` holds the file's fields until the file changes (`tests/notes/doc_sync_check.gd`).

## What changed for the person

- Tags, Thumbnail: a "YouTube" section, always in the same place, whatever else is on the note.
- Generate also paints a note's missing pictures: it makes everything the list says is missing, and the ▶ on a section
  makes less.
- Proof's Make/Remake: Generate makes what is missing, and "Whole episode" is a row, asking first.
- A ⟳ makes what it says and nothing else. A Proof ⟳ does not rewrite the tags or paint a thumbnail as a side effect;
  they show as stale, and Generate (or their own ⟳) makes them.
- A Picture's "Regenerate" stays beside its thumbnail and in its full-size window, where the picture is judged.
  "Generate missing" and "Regenerate all" are there too.
- Proof's Invent and Refine stay on the Proof card: they write the note's words, which come before the pipeline.

## Interrupted authoring

An interrupted authoring step offers **Resume** beside its regenerate button when its tools have saved progress.
Work, table setup, model design, decoration and solving checkpoint their draft and bookkeeping after every completed
tool call. The remaining looks, call budget and submit guards survive Stop, a crash, or an app restart. Generate
leaves this progress alone; regenerate asks before starting it over. Nothing resumes automatically on open.

Resume restores against the same input files and original settings. It starts a writer with the original task,
the restored draft, recent completed tool answers, visible writer notes and saved pictures. Writer sessions remain
stateless: hidden reasoning and an in-flight call are not checkpointed. The old writer's files are kept under
`jobs/<step>/attempts/` before the new attempt writes its own stream. A draft already submitted before the crash
lands locally without another writer. Changed inputs, a replaced output or an incompatible checkpoint prevent Resume.

Work runs made before checkpointing can also recover their draft edits, replacements, removals, looks and watched
acts from `tools.jsonl`, without replaying simulations or pictures, where the inputs have not changed since the run.
Other old runs, one-shot writers, generated images, live game sessions and the canvas painter have no supported
draft restoration and offer no Resume button. New toolsets opt in by naming only their durable data in `RESUME_FIELDS`.

Gates: `producer_resume_check`, `agent_tools_check`, and `pipeline_check`, with no paid agent calls.

## Status

Built: the contract, the card, all seven sections, the gates. A table show's row ⟳ makes its step again and then everything
made from it, in order, as Generate makes what goes stale (a 🔒 stops it there; `TableProducer.start`'s `follow`), and every
group's own line has a ⟳ that makes every step in it again but the locked (`PipelineSection.group_again`). A table show's
take (the Voice row) is said on its own whenever the script or a voice changes, while nothing is being made and nothing plays
(`EpisodeCard._keep_take`; never in a read-only session, a gate or a probe); its ⟳ says it at once. docs.py's rule "one pipeline" holds that a new card cannot
grow a ⟳ of its own (`ActorSourceList`'s stays - it lists a link again and makes nothing). Gate:
`tests/ui/pipeline_check.gd`, with `tests/table_show/episode_rows_check.gd` and
`tests/media/pictures_rows_check.gd` on the real cards; `tests/ui/pipeline_look_probe.gd` to look at it.

Looked at under xvfb only (`pipeline_look_probe`); the author has still to judge whether Stop and Generate on the title
bar read well in the app.

Open, not built:

- A table step made again throws nothing away (next/editing.md step 1: versions, stale, kept); stepping back to a
  version from the card, and the same for Proof's steps, are not built.
- Which group to scroll to when a long Generate moves past the list's view: the tally says where it is, the list stays
  where it was left, or, left at its end, stays at its end as steps are added (`PanelDeck`, next/panel_deck.md).
