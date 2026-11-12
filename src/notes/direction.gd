extends RefCounted
class_name Direction

## Direction - WHERE TO TAKE WHAT IS MADE NEXT, beside the note's own words (2026-11-11, the user: "a high-priority instruction
## add-on to WHATEVER we're working on ... Just, a secondary card, which can allow us to pass additional instructions to models,
## beyond the initial markdown prompt, and with higher priority"; next/direction.md). The brief says what a show is, every episode;
## a direction says what the next one does - "explain a Turing machine" - without the brief being edited.
##
## A COMPONENT OF ITS OWN, ON ANY NOTE: the Direction card ([DirectionCard]) keeps it in the note's `ghost: direction:` block, and
## whatever runs agents for the note reads it from there through this, never naming the card (a table's Episode card hands it to its
## producer, [method TableProducer.with_direction]).
##
## AN EPISODE KEEPS THE DIRECTION IT WAS MADE FROM: its producer writes it into the episode as the episode's first step when the
## plan is first made ([method TableProducer._take_direction]), and every agent behind that episode reads the episode's copy - so
## the card can be written for the next episode without a made one changing under it, and taking the card's words up again into a
## made one (its row's ⟳) is a choice, after which what was made from it goes stale.

## The block it keeps under `ghost:`.
const KEY := "direction"
## The most characters a direction carries to an agent.
const MOST := 6000


## The direction [param block] (the note's `direction:` block, as the card captures it) carries: its words, trimmed - "" for none.
static func text_of(block: Variant) -> String:
	if not (block is Dictionary):
		return ""
	return String((block as Dictionary).get("text", "")).strip_edges().left(MOST)
