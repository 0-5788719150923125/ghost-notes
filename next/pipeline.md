# The Pipeline card

Asked 2026-11-02, built the same day. The user: "the pipeline is not a unified, generic card - it is multiple
branching paths, and we are forced to build logic that pushes steps into different lists, at different times, depending
upon the context ... I would always be able to find that one, stable card, to regenerate various things ... when we
click the regenerate button - we will KNOW that it's going to regenerate that one thing, without a maybe second list
appearing."

## What was wrong (measured in the code, before)

Six lists of steps, each its own widget code: Episode's rows (`EpisodeCard._add_row`), Proof's (`ProofCard._build`),
the Letter's (`LetterCard._build_rows`), `ActorStepRows` (Actor, Voice training), `EpisodeStepRows` (Proof, Letter,
Actor, `NoteUpload`), and the Pictures' (`IllustrationPanel`).

Other cards' steps reached four different places: `hand_publish(p, by)` set `steps_by`, the card that handed the
publish kept its own `_added` and `_added_rows`, and with none the YouTube card listed them itself
(`NoteUpload.hosting`). A docs.py rule existed only to keep that straight.

And ⟳ meant four things:

| Card | ⟳ did |
|---|---|
| Episode | always a menu, even of one item (`MenuButton`, `REDO`) |
| Proof | at once, with everything after it, thrown away unasked |
| Letter, Tags, Thumbnail | at once |
| Actor, Voice training | a dialog first |

Two more traps were found while reading it. The Episode menu was the only guard on a stray click: its Plan item deletes
every painting and reading. And ⟳ on a step whose inputs were not made did nothing and said nothing
(`TableProducer.tick` passes it by).

## The design

**One card, last in the deck.** `PipelineCard` (`src/ui/`) is the last card on the panel, in the one scroll, and its title bar
lies on the panel's bottom pile until it is scrolled to - so it is always in sight and one click away (`PanelDeck`,
next/panel_deck.md). (Built pinned under the scroll first, the same day. The user: "It's weird that there are now two panels on the
left ... They should all be scrollable".) Generate, Stop and the tally are on its title bar, and work wherever that bar lies. No component, no "+": it appears when something on the note has something to make, and is gone when nothing does.

**One way in.** A card answers `pipeline() -> PipelineSection` (`src/notes/`). `ReadingPanel._offer_pipeline` adds it. That
is the whole contract: no card names another, none is told where it stands, and which card "hosts" what no longer
exists as a question. `hand_publish`, `steps_by`, `hosting`, `_added`, `_added_rows`, `EpisodeStepRows`, `ActorStepRows`
and the docs.py rule are gone.

A section's rows are `PipelineRow`s: a key, a name, a state, what it says, and what its ⟳ does.

**One ⟳.** Every distinct regeneration is a row of its own, and its ⟳ does exactly that one thing. Never a menu. A card
of an Episode has four rows where it had one row and a menu: Design, Painting, Reading, Over its work.

**The guard, in the open.** A ⟳ that would throw away OTHER finished work says so on hover and asks once - a
yes or a no, never a list - naming what it throws away. Only when there is such work. So what a click will do is known
before it is made, and the ⟳ on Plan cannot lose an episode to a stray click. It wore amber until 2026-11-07, when the
user found it said nothing they could read ("it's not clear why some of the regenerate buttons are orange, while others
are white"): every ⟳ is one color now, and the hover and the question say it. (Worked out from the steps' own
dependencies, once per change of the episode's files - `TableEpisode.dependents` parses JSON per call, and at a row each
four times a second would cost a playing show.)

**One Generate.** Top to bottom, every section's missing work in turn, each waiting for the one before: an episode's words
first, then what is made from them. A section's own ▶ on its heading makes only that section, so "paint the missing
pictures, not the tags" is still one click. While Generate walks, every ⟳ waits, and Stop stops it all.

## What changed for the person

- Tags, Thumbnail: a "YouTube" section, always the same place, whatever else is on the note.
- Generate now also paints a note's missing pictures: it makes everything the list says is missing, and the ▶ on a
  section is there for making less.
- Proof's Make/Remake: Generate makes what is missing, and "Whole episode" is a row, asking first.
- A ⟳ makes what it says and nothing else. A Proof ⟳ no longer rewrites the tags and paints a thumbnail as a side effect:
  they say they are stale, and Generate (or their own ⟳) makes them.
- A Picture's "Regenerate" stays beside its thumbnail and in its full-size window: it is where the picture is judged, and
  it says what it does. "Generate missing" and "Regenerate all" moved here.
- Proof's Invent and Refine stay on the Proof card: they write the note's words, which come before the pipeline.

## Status

Built 2026-11-02: the contract, the card, all seven sections, the gates; docs.py's rule "one pipeline" holds that a new card
cannot grow a ⟳ of its own (`ActorSourceList`'s stays - it lists a link again and makes nothing). Gate:
`tests/ui/pipeline_check.gd`, with `tests/table_show/episode_rows_check.gd`, `tests/proof/proof_rows_check.gd` and `tests/media/pictures_rows_check.gd` on the real cards; `tests/ui/pipeline_look_probe.gd` to look at it.

Looked at under xvfb only (`pipeline_look_probe`), not yet by the user in the app: whether Stop and Generate on the title bar read well.

Open, not built:

- An undo for a thrown-away step (`invalidate` deletes). With one, the question could go.
- Which group to scroll to when a long Generate moves past the list's view: the tally says where it is, the list stays
  where it was left - or, left at its end, stays at its end as steps are added (`PanelDeck`, next/panel_deck.md).
