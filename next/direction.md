# Direction: where to take what is made next

## Status (2026-11-11)

**Built.** A component any note can have ("+" -> Direction), its card the Direction card (`src/ui/direction_card.gd`,
`DirectionCard`), its block `ghost: direction: {text, writer, writer_model, writer_effort}`, its words read through
`Direction.text_of` (`src/notes/direction.gd`) by whatever runs agents - never by naming the card.

- **At the table** (every table show): Generate on an episode with no plan writes the card's words into it as its first
  step, `direction.md`, the author's (`TableProducer._take_direction`); the plan is made from it. Every text job behind
  that episode carries it in its system prompt after the brief, with the words that put it first
  (`TableProducer.with_direction`, rules/table/show.yaml `direction`): it decides what the episode is about and does,
  the brief's voice and standing rules hold unless it changes them in so many words, and the producer's dice only flavor
  what it leaves open. A made episode keeps its own: the card is written for the next one freely. Its row on the Episode
  card (Direction, first) takes the card's words up again with its ⟳, and what was made from the old ones goes stale.
  Episodes made before there were directions have no such step and never go stale for one.
- **Refine** has the card's writer (its own AgentPick row) read the note - the show's brief, or a note's words - and the
  direction, and write the direction back whole in the note's terms: everything asked kept, made precise, nothing done in
  advance (rules/agents/direction.yaml). The note is never written. Refine stands in the window the direction is written
  in, not on the card (the user, the same day: "It's pointless to force the user to back-out of the Direction text, just to
  push the button and then re-enter it, to check results"), and the refined words land in its box (`TextField.add_action`,
  `TextField.replace` - any card's long words can carry actions of their own now). No undo of its own: "the user will just
  copy/paste their own prompt there, if they need to re-do it".
- **Gates**: `tests/ui/direction_card_check.gd` (the component, the card's block through the frontmatter, Refine's prompt
  and landing) and `tests/table_show/direction_step_check.gd` (taken up, told, kept; the controls an episode given none
  and one made before directions).

**Open:** the other agents a note can run do not read it yet - a Letter's sketcher, the Pictures painter, the YouTube
writers, an Actor's builder. Each is a line where its prompt is built (`Direction.text_of` of the note's block), when
the user wants it there. The user's eye on the first episode made from a direction.

## Why

The user, 2026-11-11, after Proof became a table show (next/proof.md): "The original version of the Proof component had
options that would allow me to guide agents to write about a certain topic ... Now, we have a single, static prompt -
and the models essentially choose their own topic, unless I edit that markdown guide. Which I don't necessarily want to
do." And the shape: "a high-priority instruction add-on to WHATEVER we're working on. Not restricted to theorem
proving. Just, a secondary card, which can allow us to pass additional instructions to models, beyond the initial
markdown prompt, and with higher priority. And on that card, we would have a similar text box, where we could do
similar AI-revising of that mini-prompt."

Three choices made with it:

- **Named Direction, not Guide**: the rift files are the user's "markdown guides"; a Guide card would be confused with
  them. The brief says what the show is; the direction says where to take it next.
- **An episode keeps the direction it was made from**, as every step keeps what it was made from (next/editing.md, "A
  step is kept"): a card read live by every agent would carry "explain a Turing machine" into the next episode when
  nobody cleared it, and change a made episode under a ⟳.
- **One place every agent hears it**: the producer's one funnel for text jobs (`TableProducer._submit_text`), so no role
  is left out and none is told it twice. A painter is not told it: what it paints is described to it by roles that were.
