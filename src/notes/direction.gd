extends RefCounted
class_name Direction

## Direction - where to take what is made next, beside the note's own words (next/direction.md). The brief says what a
## show is, every episode; a direction says what the next one does ("explain a Turing machine") without the brief being
## edited.
##
## A component of its own, on any note: the Direction card ([DirectionCard]) keeps it in the note's `ghost: direction:`
## block, and whatever runs agents for the note reads it from there through this, never naming the card (a table's
## Episode card hands it to its producer, [method TableProducer.with_direction]).
##
## An episode keeps the direction it was made from: its producer writes it into the episode as the first step when the
## plan is first made ([method TableProducer._take_direction]), and every agent behind that episode reads the episode's
## copy. The card can be written for the next episode without a made one changing under it; taking the card's words up
## again into a made one (its row's ⟳) is a choice, after which what was made from it goes stale.

## The block it keeps under `ghost:`.
const KEY := "direction"
## The most characters a direction carries to an agent.
const MOST := 6000


## The direction [param block] (the note's `direction:` block, as the card captures it) carries: its words, trimmed, "" for none.
static func text_of(block: Variant) -> String:
	if not (block is Dictionary):
		return ""
	return String((block as Dictionary).get("text", "")).strip_edges().left(MOST)
