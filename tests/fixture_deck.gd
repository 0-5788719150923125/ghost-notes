extends RefCounted

## A deck a gate can count on: a show's `## Cards` section, written here and read the way a brief's is
## ([method CardDeck.parse]). No deck is built into the app (a tarot show lists its 78 in its own brief),
## so the gates that shuffle, draw and print cards make one.
##
## It is the tarot's 78 in their Rider-Waite-Smith order - long names ("The High Priestess", "Queen of
## Pentacles") to fit on a card's band, two kinds of group, numerals of both kinds - each with a stub
## meaning. It is content for the gates, not a deck the app knows.
##
##   const FixtureDeck := preload("res://tests/fixture_deck.gd")
##   var deck: Array = FixtureDeck.cards()

const MAJORS := ["The Fool", "The Magician", "The High Priestess", "The Empress", "The Emperor",
	"The Hierophant", "The Lovers", "The Chariot", "Strength", "The Hermit", "Wheel of Fortune",
	"Justice", "The Hanged Man", "Death", "Temperance", "The Devil", "The Tower", "The Star",
	"The Moon", "The Sun", "Judgement", "The World"]
const SUITS := ["Wands", "Cups", "Swords", "Pentacles"]
const RANKS := ["Ace", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten",
	"Page", "Knight", "Queen", "King"]
const ROMAN := ["0", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII", "XIII",
	"XIV", "XV", "XVI", "XVII", "XVIII", "XIX", "XX", "XXI"]


## The deck as a brief writes it: a `## Cards` section, a `###` heading per group.
static func section() -> String:
	var out := PackedStringArray(["## Cards", "", "### Major Arcana", ""])
	for i in MAJORS.size():
		out.append("- %s. %s: the meaning of %s. Reversed: its shadow." % [ROMAN[i], MAJORS[i], MAJORS[i]])
	for s in SUITS:
		out.append_array(["", "### " + String(s), ""])
		for r in RANKS.size():
			var name := "%s of %s" % [RANKS[r], s]
			var num := "%s. " % ROMAN[r + 1] if r >= 1 and r <= 9 else ""
			out.append("- %s%s: the meaning of the %s." % [num, name, name])
	return "\n".join(out) + "\n"


## The 78, in deck order, as [method CardDeck.parse] reads them.
static func cards() -> Array:
	return CardDeck.parse(section())
