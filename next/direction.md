# Direction: where to take what is made next

## Status

**Built.** A component any note can have ("+" -> Direction), its card the Direction card (`src/ui/direction_card.gd`,
`DirectionCard`), its block `ghost: direction: {text, writer, writer_model, writer_effort}`, its words read through
`Direction.text_of` (`src/notes/direction.gd`) by whatever runs agents - never by naming the card.

- **At the table** (every table show): Generate on an episode with no plan writes the card's words into it as its first
  step, `direction.md`, the author's (`TableProducer._take_direction`); the plan is made from it. Every text job behind
  that episode carries it in its system prompt after the brief, with the words that put it first
  (`TableProducer.with_direction`, rules/table/show.yaml `direction`): it decides what the episode is about and does,
  the brief's voice and standing rules hold unless it changes them in so many words, and the producer's dice only flavor
  what it leaves open. A made episode keeps its own: the card can be rewritten for the next one. Its row on the Episode
  card (Direction, first) takes the card's words up again with its ⟳, and what was made from the old ones goes stale.
  Episodes made before there were directions have no such step and never go stale for one.
- **Refine** has the card's writer (its own AgentPick row) read the note - the show's brief, or a note's words - and the
  direction, and write the direction back whole in the note's terms: everything asked kept, made precise, nothing done in
  advance (rules/agents/direction.yaml). The note is never written. Refine stands in the window the direction is written
  in, not on the card, so the author never leaves the text to run it; the refined words land in its box
  (`TextField.add_action`, `TextField.replace` - any card's long words can carry actions of their own). It has no undo of
  its own.
- **Gates**: `tests/ui/direction_card_check.gd` (the component, the card's block through the frontmatter, Refine's prompt
  and landing) and `tests/table_show/direction_step_check.gd` (taken up, told, kept; the controls an episode given none
  and one made before directions).

**Open:**

- The other agents a note can run do not read it yet: a Letter's sketcher, the Pictures painter, the YouTube writers, an
  Actor's builder. Each is a line where its prompt is built (`Direction.text_of` of the note's block).
- The author's eye on the first episode made from a direction.

## Why

A table show's brief is one static markdown prompt, so the models choose their own topic unless the brief is edited. The
Direction card is a high-priority instruction add-on to whatever a note is: not tied to one kind of show, a secondary card
that passes additional instructions to the models beyond the brief, with a text box that an agent can revise.

Three choices:

- **Named Direction, not Guide**: the rift files are the author's "markdown guides", and a Guide card would be confused
  with them. The brief says what the show is; the direction says where to take it next.
- **An episode keeps the direction it was made from**, as every step keeps what it was made from (next/editing.md, "A
  step is kept"): a card read live by every agent would carry one episode's topic into the next when nobody cleared it,
  and change a made episode under a ⟳.
- **One place every agent hears it**: the producer's one funnel for text jobs (`TableProducer._submit_text`), so no role
  is left out and none is told it twice. A painter is not told it: what it paints is described to it by roles that were.
