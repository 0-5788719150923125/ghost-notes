extends RefCounted
class_name TableActions

## TableActions - the verbs a card show performs at the table, as ONE REGISTRY (next/notes.md step
## 9, "Actions are a registry"). Each verb declares what it takes (which card), whether it is written
## in a reading's marks or performed between them, the rest the voice takes for it, whether it brings
## a card up to be shown or puts the shown one down first, and the moments it makes (what the air can
## burst on, [constant CardTable.MOMENTS]) - declared, not branched on, the way [constant Medium.USES]
## is. CardReading's marks and rests and the table's schedule read it; adding a verb is an entry here
## and its pose where the table draws it.
##
## THE DURATIONS ARE THE TABLE'S, in seconds - the phase constants inside each are [TableMedium]'s
## own; these are their sums - and the voice rests exactly as long, from the same numbers, so the
## voice waits as long as the cards move. The shuffle is the exception that proves it: readers talk
## while they shuffle, so its rest is only the moment it takes to begin.
##
## THE OPENING VERB SAYS WHERE THE CARDS COME FROM ([constant SOURCES]): `shuffle` - a deck shuffled
## in the middle of the table and pushed aside before the first card - or `open` - a box the cards are
## kept in, standing where the deck would, pulled from one at a time. A verb that takes a card from the
## source waits for the push (`first`) only when the source pushes.
##
## Tarot's verbs are draw, jumper and spread; a show of a collection adds `deal` (a card straight to
## its place, never held up), `fan` (a waterfall: several swept out at once, overlapping), `show` (a
## card lying on the table picked up and held up as a drawn one is), and the turns of a card where it
## lies - `tap` and `untap` (a quarter turn, sideways and back) and `flip` (over). Gather and discard
## are entries to come.

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
## THE BOX OPENS: the intro of a show whose cards are kept in a box - only the moment it takes to begin,
## as the shuffle's.
const OPEN_LEAD := 0.8
## A card dealt: off the deck (or up out of the box), turned over, and straight down into its place.
const DEAL := 2.0
## A waterfall: the cards leave the deck one after another, each a beat behind the last, and slide
## out into an overlapping line - its first card's travel, and the beat each further card adds.
const FAN := 1.6
const FAN_EACH := 0.32
## A card lying on the table picked up and held up to be shown.
const SHOW := 1.6
## A card turned where it lies: a quarter turn (tap, untap), or over (flip).
const TURN := 0.9
const FLIP := 1.2

## THE VERBS. `written`: a reading's mark names it (`<!-- table: draw 3 -->`); `args`: what the mark
## takes after the verb; `rest`: the seconds the voice holds for it; `first`: added when it brings up
## the reading's first card (the deck's push comes before it); `shows`: it brings a card up to be
## shown; `lays`: a card still shown is laid down first (+ the lay's duration); `ends`: nothing is
## shown after it; `moments`: what it makes for the air.
## `source`: an opening verb's, where the cards come from; `takes`: it takes cards from the source
## (waiting for the push when it is the first); `range`: its mark names a run of cards (`fan 3-5`);
## `turns`: it turns a card where it lies; `chapter`: a video chapter starts there.
const REGISTRY := {
	"shuffle": {"written": true, "args": [], "rest": SHUFFLE_LEAD, "shows": false, "lays": false,
		"ends": false, "moments": ["shuffle"], "source": "deck",
		"about": "the deck shuffles under the words that follow"},
	"open": {"written": true, "args": [], "rest": OPEN_LEAD, "shows": false, "lays": false,
		"ends": false, "moments": [], "source": "box",
		"about": "the box the cards are kept in stands open; the cards are pulled from it one at a time"},
	"draw": {"written": true, "args": ["card"], "rest": DRAW, "first": PUSH, "shows": true, "lays": true,
		"ends": false, "moments": ["reveal", "pirouette"], "takes": true, "chapter": true,
		"about": "the card on the table goes down into the spread (if one is up), then the named card is drawn, turned and held up beside its booklet entry"},
	"jumper": {"written": true, "args": ["card"], "rest": JUMP, "shows": true, "lays": true,
		"ends": false, "moments": ["jumper", "reveal", "pirouette"], "takes": true, "chapter": true,
		"about": "the named card is not drawn: it flies out of the shuffle on its own, lands, and is picked up and held up as a drawn card is"},
	"spread": {"written": true, "args": [], "rest": SETTLE, "shows": false, "lays": true,
		"ends": true, "moments": ["close"], "chapter": true,
		"about": "the last card goes down; the whole spread lies on the table"},
	"deal": {"written": true, "args": ["card"], "rest": DEAL, "first": PUSH, "shows": false, "lays": true,
		"ends": false, "moments": ["lay"], "takes": true, "chapter": true,
		"about": "the card on display goes down (if one is up), then the named card is taken and put straight down in its place, face up, never held up"},
	"fan": {"written": true, "args": ["card"], "rest": FAN, "first": PUSH, "shows": false, "lays": true,
		"ends": false, "moments": ["lay"], "takes": true, "range": true,
		"about": "the card on display goes down (if one is up), then the named run of cards (`fan 3-5`) is swept out at once, overlapping in a line or an arc, face up"},
	"show": {"written": true, "args": ["card"], "rest": SHOW, "shows": true, "lays": true,
		"ends": false, "moments": ["reveal", "pirouette"], "chapter": true,
		"about": "the card on display goes down (if one is up), then the named card, lying on the table, is picked up and held up as a drawn card is"},
	"tap": {"written": true, "args": ["card"], "rest": TURN, "shows": false, "lays": true, "turns": true,
		"ends": false, "moments": [],
		"about": "the card on display goes down (if one is up), then the named card, lying on the table, is turned a quarter turn, sideways"},
	"untap": {"written": true, "args": ["card"], "rest": TURN, "shows": false, "lays": true, "turns": true,
		"ends": false, "moments": [],
		"about": "the named card, lying sideways, is turned back upright"},
	"flip": {"written": true, "args": ["card"], "rest": FLIP, "shows": false, "lays": true, "turns": true,
		"ends": false, "moments": [],
		"about": "the named card is turned over where it lies"},
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


## Does [param kind]'s mark name a run of cards (`fan 3-5`)?
static func takes_range(kind: String) -> bool:
	return bool(REGISTRY.get(kind, {}).get("range", false))


## Does [param kind] take cards from the source (the deck, the box)?
static func takes_from_source(kind: String) -> bool:
	return bool(REGISTRY.get(kind, {}).get("takes", false))


## Does [param kind] turn a card where it lies?
static func turns(kind: String) -> bool:
	return bool(REGISTRY.get(kind, {}).get("turns", false))


## Where the cards come from after the opening verb [param kind]: `deck`, `box`, or "" (not an opening).
static func source_of(kind: String) -> String:
	return String(REGISTRY.get(kind, {}).get("source", ""))


## THE SOURCES: what each opening means for the table. `pushes`: the deck is shuffled in the middle
## and pushed to its side before the first card; `shuffles`: it is shuffled at all; `jumpers`: a card
## can fly out of it.
const SOURCES := {
	"deck": {"opens": "shuffle", "pushes": true, "shuffles": true, "jumpers": true,
		"about": "a deck, shuffled in the middle of the table while the host talks and pushed to one side before the first card"},
	"box": {"opens": "open", "pushes": false, "shuffles": false, "jumpers": false,
		"about": "a box the cards are kept in (a shoebox, a tin, a cigar box), standing open to one side; each card is pulled out of it"},
}


## Does a video chapter start at [param kind]?
static func chapter(kind: String) -> bool:
	return bool(REGISTRY.get(kind, {}).get("chapter", false))


## THE REST THE VOICE TAKES for [param kind]. [param showing] is whether a card is up on display when
## it begins, which a verb that `lays` puts down first; [param first] is whether no card has left the
## source yet, when a verb that takes one waits for the push - if the source [param pushes]. [param n]
## is how many cards it moves (a waterfall's run). Left to their defaults, [param first] is what it
## always was: nothing up means the reading's first card.
static func rest_of(kind: String, showing: bool, first: Variant = null, pushes := true, n := 1) -> float:
	var a: Dictionary = REGISTRY.get(kind, {})
	if a.is_empty():
		return 0.0
	var is_first: bool = (not showing and bool(a["shows"])) if first == null else bool(first)
	var rest := float(a["rest"]) + (FAN_EACH * float(maxi(n - 1, 0)) if takes_range(kind) else 0.0)
	if is_first and pushes:
		rest += float(a.get("first", 0.0))
	return (LAY if showing and bool(a["lays"]) else 0.0) + rest


## How long the table waits after a card's action begins before that card's own phases start: the
## lay of the card before it, or - for the reading's first card, drawn rather than thrown - the push.
## [param showing] (a card is up to be laid first) and [param pushes] (the source pushes) default to
## what they always were.
static func lead_of(kind: String, first: bool, showing: Variant = null, pushes := true) -> float:
	var up: bool = (not first) if showing == null else bool(showing)
	var out := LAY if up and bool(REGISTRY.get(kind, {}).get("lays", false)) else 0.0
	if first and pushes:
		out += float(REGISTRY.get(kind, {}).get("first", 0.0))
	return out


## Every moment the verbs make, once each.
static func moments() -> Array:
	var out: Array = []
	for k in REGISTRY:
		for m in REGISTRY[k]["moments"]:
			if not out.has(m):
				out.append(m)
	return out
