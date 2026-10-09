extends RefCounted
class_name CardDeck

## CardDeck - the cards a show reads with, and how an episode's deck is shuffled.
##
## THE DECK IS THE SHOW'S, and it is DATA: a `## Cards` section of the show's brief, one card per
## list item, each with an optional numeral and its meaning -
##
##     ## Cards
##
##     ### Major Arcana
##     - XVI. The Tower: sudden upheaval, a structure that was never sound. Reversed: ...
##     - 0. The Fool: ...
##
## - so a show reads the tarot by listing its 78, or a deck of its own: an oracle of forty-four
## cards, a deck of Mondays. A `###` heading inside the section names the group the cards under it
## belong to (a suit, an arcana). Prose in the section is kept as instructions (what a suit stands
## for, what a jumper means to the genre); only the list is the deck.
##
## A brief that lists no card leaves the deck to each episode's producer ([method chooses]): the
## brief says what kind of cards they are. No deck is built in (the user, 2026-10-08: "for anything
## else that tarot might need - declare it in the markdown files"): the tarot's 78 are the tarot
## show's own list.
##
## THE DRAW IS NEVER AN AGENT'S. The deck is defined before anyone writes a word, and an episode's
## cards are a seeded shuffle of it ([method shuffled]) - the seed drawn from the operating
## system's cryptographic randomness when the episode is made, and kept, so the episode can be
## made again exactly. No agent picks a card, and none is shown the deck's order.

## The heading that opens a show's deck: `## Cards` or `## The Cards`. Not "Deck": a brief
## describing its deck's LOOK under that heading, in bullets, would become a deck of its bullets.
const HEADING := "(?i)^(#{1,6})\\s*(?:the\\s+)?cards\\s*:?\\s*$"
const ITEM := "^\\s*(?:[-*+]|\\d+[.)])\\s+(.+)$"
## A card's own numeral, ahead of its name: `0.`, `XVI.`, `12)`.
const NUMERAL := "^(0|[IVXLCDM]+|\\d+)[.)]\\s+(.+)$"


static func _rx(p: String) -> RegEx:
	var r := RegEx.new()
	r.compile(p)
	return r


# --- a show's own deck ------------------------------------------------------------------------

## The cards [param body] defines in its Cards section, in order; empty when it defines none.
static func parse(body: String) -> Array:
	var span := _section(body)
	if span.is_empty():
		return []
	var lines: PackedStringArray = span["lines"]
	var item := _rx(ITEM)
	var numeral := _rx(NUMERAL)
	var sub := _rx("^(#{1,6})\\s+(.+?)\\s*$")
	var out: Array = []
	var keys := {}
	var group := ""
	for line in lines:
		var l := String(line)
		var h := sub.search(l)
		if h != null:
			group = h.get_string(2).strip_edges()
			continue
		var m := item.search(l)
		if m == null or _indented(l):
			# a continuation of the card above it, indented under its item - a nested bullet
			# (`  - Reversed: ...`) included: it says more about that card, it is not one
			if not out.is_empty() and _indented(l) and not l.strip_edges().is_empty():
				var last: Dictionary = out[-1]
				var more := m.get_string(1).strip_edges() if m != null else l.strip_edges()
				last["meaning"] = (String(last["meaning"]) + " " + more).strip_edges()
			continue
		var text := m.get_string(1).replace("**", "").replace("__", "").strip_edges()
		var num := ""
		var nm := numeral.search(text)
		if nm != null:
			num = nm.get_string(1)
			text = nm.get_string(2)
		# the name ends at the FIRST separator, whichever it is (a colon, or a spaced dash of any length)
		var name := text
		var meaning := ""
		var cut := -1
		var cut_len := 0
		for sep in [": ", " - ", " \u2014 ", " \u2013 "]:
			var at := text.find(sep)
			if at > 0 and (cut < 0 or at < cut):
				cut = at
				cut_len = String(sep).length()
		if cut > 0:
			name = text.substr(0, cut)
			meaning = text.substr(cut + cut_len)
		name = name.strip_edges().trim_suffix(":")
		if name.is_empty():
			continue
		var key := CardEpisode.slug(name)
		var k := key
		var n := 2
		while keys.has(k):
			k = "%s-%d" % [key, n]
			n += 1
		keys[k] = true
		out.append({"key": k, "name": name, "numeral": num, "group": group, "meaning": meaning.strip_edges()})
	return out


## The deck [param body]'s show reads with: the cards it lists - or none, when the producer chooses
## each episode's ([method chooses]).
static func of(body: String) -> Array:
	return parse(body)


## THE PRODUCER CHOOSES THE CARDS: [param body] lists none - its brief says what kind of cards the
## show shows (a collection shown off, a box of whatever the episode finds, a tarot deck it does not
## write out). Each episode's producer makes its deck ([method CardProducer._land_plan]) and the seed
## still decides which of them come out, so no agent picks a card here either.
static func chooses(body: String) -> bool:
	return parse(body).is_empty()


## [param body] as the agents are handed it: the Cards section's LIST taken out (each card's
## meaning reaches a writer only when that card is drawn), its prose kept, and a line saying how
## many cards the deck has.
static func strip(body: String) -> String:
	var span := _section(body)
	if span.is_empty() or chooses(body):
		return body
	var item := _rx(ITEM)
	var kept := PackedStringArray()
	var listed := false
	for line in span["lines"] as PackedStringArray:
		var l := String(line)
		if item.search(l) != null and not _indented(l):
			listed = true
			continue
		if _indented(l) and listed:
			continue
		kept.append(l)
	var n := parse(body).size()
	var head := String(span["head"])
	var note := "(This deck has %d cards. Each card's meaning is given when it is drawn.)" % n
	var mid := "\n".join(kept).strip_edges()
	var section := head + "\n\n" + ((mid + "\n\n") if not mid.is_empty() else "") + note + "\n"
	return String(span["before"]) + section + String(span["after"])


## A line indented under the item above it.
static func _indented(l: String) -> bool:
	return l.begins_with("  ") or l.begins_with("\t")


## The Cards section of [param body]: `{before, head, lines, after}`, or empty.
static func _section(body: String) -> Dictionary:
	var src := Manuscript.strip_frontmatter(body)
	var lines := src.split("\n")
	var head := _rx(HEADING)
	var start := -1
	var level := 0
	for i in lines.size():
		var m := head.search(String(lines[i]))
		if m != null:
			start = i
			level = m.get_string(1).length()
			break
	if start < 0:
		return {}
	var end := lines.size()
	var any := _rx("^(#{1,6})\\s+")
	for i in range(start + 1, lines.size()):
		var m := any.search(String(lines[i]))
		if m != null and m.get_string(1).length() <= level:
			end = i
			break
	return {"before": "\n".join(lines.slice(0, start)) + ("\n" if start > 0 else ""),
		"head": String(lines[start]), "lines": lines.slice(start + 1, end),
		"after": ("\n" + "\n".join(lines.slice(end))) if end < lines.size() else ""}


# --- the draw ---------------------------------------------------------------------------------

## THE SHUFFLE: [param deck] in the order this [param seed] cuts it, each card with whether it
## comes up reversed (only when [param reversals]; about a third do, as readers who use them
## find). Returns copies of the cards, each with `reversed` added.
static func shuffled(deck: Array, seed: int, reversals: bool) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed, "tarot-shuffle"])
	var order: Array = deck.duplicate()
	# Fisher-Yates, on the seeded stream - Array.shuffle() draws from the global one
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: Variant = order[i]
		order[i] = order[j]
		order[j] = t
	var out: Array = []
	for c in order:
		var card := (c as Dictionary).duplicate()
		card["reversed"] = reversals and rng.randf() < 0.32
		out.append(card)
	return out


## A fresh episode seed, from the operating system's cryptographic randomness - unpredictable,
## and kept, so the episode it makes can be made again.
static func true_seed() -> int:
	var b := Crypto.new().generate_random_bytes(4)
	return int(b.decode_u32(0) % 999999) + 1
