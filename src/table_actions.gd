extends RefCounted
class_name TableActions

## TableActions - the verbs a card show performs at the table, as ONE REGISTRY (next/notes.md step
## 9, "Actions are a registry"). Each verb declares what it takes (which card), whether it is written
## in a reading's marks or performed between them, the rest the voice takes for it, whether it brings
## a card up to be shown or puts the shown one down first, and the moments it makes (what the air can
## burst on, [constant TarotTable.MOMENTS]) - declared, not branched on, the way [constant Medium.USES]
## is. TarotScript's marks and rests and the table's schedule read it; adding a verb is an entry here
## and its pose where the table draws it.
##
## THE DURATIONS ARE THE TABLE'S, in seconds - the phase constants inside each are [TarotMedium]'s
## own; these are their sums - and the voice rests exactly as long, from the same numbers, so the
## voice waits as long as the cards move. The shuffle is the exception that proves it: readers talk
## while they shuffle, so its rest is only the moment it takes to begin.
##
## Today's entries are tarot's four written verbs and the three nobody writes (the deck's push, its
## squaring, the lay). More - deal, place, flip, a quarter turn, show, gather, discard - are entries
## to come, with the positions they take (step 9's next primitives).

## The shuffle starts a beat before the first word, so the hands are already busy when the voice
## comes in.
const SHUFFLE_LEAD := 1.2
## The card on display goes down into the spread: the booklet closes and the card travels to its
## place and settles.
const LAY := 1.7
## A card is drawn: the deck squares, the top card slides off, lifts, turns over and comes up to be
## shown, and its booklet entry opens beside it.
const DRAW := 3.4
## Before the FIRST card: the deck, shuffled in the middle of the table, is squared and pushed to the
## side it is drawn from, clearing the middle for the spread.
const PUSH := 1.3
## A jumper: one more riffle, and the card flies out of it and lands; the reader looks at it a
## moment, then it is picked up and shown as a drawn card is.
const JUMP := 5.0
## The spread, once the last card is down: a moment to take it in before the close.
const SETTLE := 1.8

## THE VERBS. `written`: a reading's mark names it (`<!-- tarot: draw 3 -->`); `args`: what the mark
## takes after the verb; `rest`: the seconds the voice holds for it; `first`: added when it brings up
## the reading's first card (the deck's push comes before it); `shows`: it brings a card up to be
## shown; `lays`: a card still shown is laid down first (+ the lay's duration); `ends`: nothing is
## shown after it; `moments`: what it makes for the air.
const REGISTRY := {
	"shuffle": {"written": true, "args": [], "rest": SHUFFLE_LEAD, "shows": false, "lays": false,
		"ends": false, "moments": ["shuffle"],
		"about": "the deck shuffles under the words that follow"},
	"draw": {"written": true, "args": ["card"], "rest": DRAW, "first": PUSH, "shows": true, "lays": true,
		"ends": false, "moments": ["reveal", "pirouette"],
		"about": "the card on the table goes down into the spread (if one is up), then the named card is drawn, turned and held up beside its booklet entry"},
	"jumper": {"written": true, "args": ["card"], "rest": JUMP, "shows": true, "lays": true,
		"ends": false, "moments": ["jumper", "reveal", "pirouette"],
		"about": "the named card is not drawn: it flies out of the shuffle on its own, lands, and is picked up and held up as a drawn card is"},
	"spread": {"written": true, "args": [], "rest": SETTLE, "shows": false, "lays": true,
		"ends": true, "moments": ["close"],
		"about": "the last card goes down; the whole spread lies on the table"},
	# performed between the written ones, never written
	"push": {"written": false, "args": [], "rest": PUSH, "shows": false, "lays": false, "ends": false,
		"moments": [], "about": "the shuffled deck is squared and pushed to its side before the first card"},
	"square": {"written": false, "args": [], "rest": 0.0, "shows": false, "lays": false, "ends": false,
		"moments": [], "about": "the deck squares after the shuffle"},
	"lay": {"written": false, "args": [], "rest": LAY, "shows": false, "lays": false, "ends": false,
		"moments": ["lay"], "about": "the card on display goes down into its place in the spread"},
}


## The verbs a reading's marks may name, in registry order.
static func written() -> Array:
	return REGISTRY.keys().filter(func(k: String) -> bool: return bool(REGISTRY[k]["written"]))


## Does [param kind] bring a card up to be shown?
static func shows(kind: String) -> bool:
	return bool(REGISTRY.get(kind, {}).get("shows", false))


## Is nothing shown after [param kind]?
static func ends(kind: String) -> bool:
	return bool(REGISTRY.get(kind, {}).get("ends", false))


## Does [param kind] take a card?
static func takes_card(kind: String) -> bool:
	return (REGISTRY.get(kind, {}).get("args", []) as Array).has("card")


## THE REST THE VOICE TAKES for [param kind]. [param showing] is whether a card is up on display when
## it begins (every draw but the first, and the spread), which a verb that `lays` puts down first; a
## verb that `shows` with nothing up brings the reading's first card, and the deck moves first.
static func rest_of(kind: String, showing: bool) -> float:
	var a: Dictionary = REGISTRY.get(kind, {})
	if a.is_empty():
		return 0.0
	var rest := float(a["rest"])
	if bool(a["shows"]) and not showing:
		return float(a.get("first", 0.0)) + rest
	return (LAY if showing and bool(a["lays"]) else 0.0) + rest


## How long the table waits after a card's action begins before that card's own phases start: the
## lay of the card before it, or - for the reading's first card, drawn rather than thrown - the push.
static func lead_of(kind: String, first: bool) -> float:
	if not first:
		return LAY
	return float(REGISTRY.get(kind, {}).get("first", 0.0))


## Every moment the verbs make, once each.
static func moments() -> Array:
	var out: Array = []
	for k in REGISTRY:
		for m in REGISTRY[k]["moments"]:
			if not out.has(m):
				out.append(m)
	return out
