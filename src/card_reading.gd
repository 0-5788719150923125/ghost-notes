extends RefCounted
class_name CardReading

## CardReading - a card reading as the voice reads it and the table performs it.
##
## The reading is prose, and a handful of own-line marks for what happens at the table between
## the passages:
##
##     <!-- table: shuffle -->    the deck shuffles under the words that follow
##     <!-- table: draw 3 -->     the card on the table goes down into the spread (if one is up),
##                                then the third card is drawn, turned and held up beside its
##                                booklet entry while the words that follow are read
##     <!-- table: jumper 1 -->   the first card is not drawn: it flies out of the shuffle on its
##                                own, lands, and is picked up and held up as a drawn card is
##     <!-- table: spread -->     the last card goes down; the whole spread lies on the table
##
## and the rest of [TableActions]' written verbs - `open` (the cards come out of a box, not a deck),
## `deal 2`, `fan 3-5` (a run of cards in one waterfall), `show 4`, `tap 2`, `untap 2`, `flip 2`.
##
## THE READING IS WRITTEN FOR THE TABLE, by [CardProducer], one passage per mark - the intro
## after `shuffle`, one passage per card after its `draw`, the close after `spread` - and a
## hand-written one works the same way.
##
## MORE THAN ONE VOICE: a show may give the reader company (a familiar on its shoulder), and a
## passage hands it a line with an own-line `<!-- speaker: Familiar -->` and takes it back with
## `<!-- speaker: Narrator -->` - the Generative panel's own cues, kept for the voice. EVERY PASSAGE
## OPENS IN THE READER'S VOICE: each is written on its own, so one that ended on another voice's
## line is handed back before the next.
##
## ONE WALK, TWO READERS, as in [TabletScript]: [method parse] produces both the spoken words the
## table follows the voice by and the text the voice reads ([member speakable]), in which every
## mark is a rest long enough to perform it (`<!-- action-hold: S -->`, spliced by the voice like a
## hesitation). The rest and the table's schedule come from the same [method rest_of], so the
## voice waits exactly as long as the cards move. The shuffle is the exception that proves it:
## readers talk while they shuffle, so its rest is only the moment it takes to begin.

## THE TIMING OF THE TABLE, in seconds, is the action registry's ([TableActions], step 9): one table
## of verbs, each with its rest. These names are its, kept here for the code and gates that ask
## CardReading.
const SHUFFLE_LEAD := TableActions.SHUFFLE_LEAD
const LAY := TableActions.LAY
const DRAW := TableActions.DRAW
const PUSH := TableActions.PUSH
const JUMP := TableActions.JUMP
const SETTLE := TableActions.SETTLE


static func _rx(pattern: String) -> RegEx:
	var r := RegEx.new()
	r.compile(pattern)
	return r


## AN OWN-LINE MARK, for the verbs the registry says are written: group 1 is the verb, 2 the card's
## place in the reading (1-based), 3 the last card of a run (`fan 3-5`).
static func mark_pattern() -> String:
	return "^\\s*<!--\\s*table\\s*:\\s*(%s)\\s*(\\d+)?(?:\\s*-\\s*(\\d+))?\\s*-->\\s*$" % "|".join(PackedStringArray(TableActions.written()))


## What makes a document a card reading: a mark naming one of the written verbs.
static func is_reading(body: String) -> bool:
	return _rx("<!--\\s*table\\s*:\\s*(?:%s)" % "|".join(PackedStringArray(TableActions.written()))).search(body) != null


## The rest the voice takes for one action - the registry's ([method TableActions.rest_of]).
## [param showing] is whether a card is up on display when it begins.
static func rest_of(kind: String, showing: bool) -> float:
	return TableActions.rest_of(kind, showing)


## [param body] as the voice should read it - see the class note. Any other text is returned
## untouched.
static func speakable(body: String) -> String:
	if not is_reading(body):
		return body
	return String(parse(body)["speakable"])


## THE WALK. Returns:
##   passages  - [{kind, card, text}]: each mark and the words read after it, in order
##   actions   - [{kind, card, last, after, dur}]: `after` = how many spoken words precede the mark;
##               `last` the run's last card (`card` for one)
##   source    - where the cards come from: the opening verb's ([constant TableActions.SOURCES])
##   spoken    - PackedStringArray: every spoken word, normalized ([method TabletScript.norm])
##   speakable - the text the voice reads
##   cards     - how many cards the reading draws
static func parse(body: String) -> Dictionary:
	var src := Manuscript.strip_frontmatter(body)
	var mark := _rx(mark_pattern())
	var passages: Array = []
	# an Array, not a PackedStringArray: appending through `(d[k] as PackedStringArray)` appends
	# to a copy and every line is silently lost
	var cur := {"kind": "", "card": 0, "lines": []}
	for line in src.split("\n"):
		var m := mark.search(line)
		if m == null:
			(cur["lines"] as Array).append(line)
			continue
		passages.append(cur)
		var num := m.get_string(2)
		var to := m.get_string(3)
		cur = {"kind": m.get_string(1), "card": int(num) if not num.is_empty() else 0, "lines": [],
			"last": int(to) if not to.is_empty() else (int(num) if not num.is_empty() else 0)}
	passages.append(cur)
	var out_passages: Array = []
	var actions: Array = []
	var spoken := PackedStringArray()
	var speak := PackedStringArray()
	var showing := false
	var cards := 0
	var moved := false
	var source := "deck"
	var who := Manuscript.NARRATOR
	for p in passages:
		var kind := String((p as Dictionary)["kind"])
		var text := "\n".join(PackedStringArray((p as Dictionary)["lines"] as Array)).strip_edges()
		# THE READER'S MARKS go on to the voice - a delivery, a hesitation, a change of speaker - but
		# no comment is ever a word the table follows, and any other note is not read at all
		var voiced := _voice_marks(text)
		text = Manuscript._rx(Manuscript.COMMENT).sub(text, "", true).strip_edges()
		if not kind.is_empty():
			if not TableActions.source_of(kind).is_empty():
				source = TableActions.source_of(kind)
			var card := int((p as Dictionary)["card"])
			var last := maxi(int((p as Dictionary).get("last", card)), card)
			var takes := TableActions.takes_from_source(kind)
			var dur := TableActions.rest_of(kind, showing, takes and not moved,
				bool((TableActions.SOURCES[source] as Dictionary)["pushes"]), last - card + 1)
			actions.append({"kind": kind, "card": card, "last": last, "after": spoken.size(), "dur": dur})
			speak.append("<!-- action-hold: %s -->" % String.num(dur, 2))
			moved = moved or takes
			if TableActions.shows(kind):
				showing = true
			elif TableActions.ends(kind) or (showing and TableActions.REGISTRY[kind]["lays"]):
				showing = false
			if TableActions.takes_card(kind):
				cards = maxi(cards, last)
		if kind.is_empty() and text.is_empty():
			continue
		out_passages.append({"kind": kind, "card": int((p as Dictionary)["card"]),
			"last": int((p as Dictionary).get("last", (p as Dictionary)["card"])), "text": text})
		for w in text.split(" ", false):
			for piece in String(w).split("\n", false):
				var n := TabletScript.norm(piece)
				if not n.is_empty():
					spoken.append(n)
		if not text.is_empty():
			# after the rest, so the rest stays on a word of the voice that spoke last
			if who != Manuscript.NARRATOR and Manuscript.speaker_of_line(voiced.get_slice("\n", 0)).is_empty():
				speak.append("<!-- speaker: %s -->" % Manuscript.NARRATOR)
			speak.append(voiced)
			who = Manuscript.NARRATOR
			for line in voiced.split("\n"):
				var cued := Manuscript.speaker_of_line(String(line))
				if not cued.is_empty():
					who = cued
	return {"passages": out_passages, "actions": actions, "spoken": spoken,
		"speakable": "\n\n".join(speak), "cards": cards, "source": source}


## [param text] with every comment taken out but the ones the voice acts on: a delivery, a
## hesitation, a change of speaker - which is put on a line of its own, since a cue anywhere else
## is read past as a note and the line goes to whoever spoke before it.
static func _voice_marks(text: String) -> String:
	var lean := _rx(Manuscript.DELIVERY)
	var hes := _rx(Manuscript.HESITATION)
	var cue := _rx(Manuscript.SPEAKER)
	var out := ""
	var at := 0
	for m in _rx(Manuscript.COMMENT).search_all(text):
		out += text.substr(at, m.get_start() - at)
		at = m.get_end()
		if lean.search(m.get_string()) != null or hes.search(m.get_string()) != null:
			out += m.get_string()
		elif cue.search(m.get_string()) != null:
			out = out.rstrip(" \t") + "\n" + m.get_string().strip_edges() + "\n"
	return (out + text.substr(at)).strip_edges()


## THE VIDEO'S CHAPTERS, from a rendered take: when the intro, each card and the spread begin,
## found by following the take's own word timings ([param words], a sidecar's) through the reading
## exactly as the table does - so a chapter starts where the cards move. `[{t, kind, card}]`,
## the first at 0.
static func chapters(body: String, words: Array) -> Array:
	var p := parse(body)
	var f := ReadingFollower.new()
	f.reset(p["spoken"])
	f.extend(words)
	var out: Array = [{"t": 0.0, "kind": "intro", "card": 0}]
	for e in f.place(p["actions"], 0.0, 0.25, 0.2):
		var a: Dictionary = (e as Dictionary)["a"]
		if not TableActions.chapter(String(a["kind"])):
			continue
		out.append({"t": maxf(0.0, float((e as Dictionary)["t0"])), "kind": String(a["kind"]),
			"card": int(a["card"])})
	return out


## A reading, written out: [param passages] are `{kind, card, text}` in order (the shape
## [method parse] returns), each its mark and then its words.
static func compose(passages: Array) -> String:
	var parts := PackedStringArray()
	for p in passages:
		var kind := String((p as Dictionary).get("kind", ""))
		var card := int((p as Dictionary).get("card", 0))
		var last := int((p as Dictionary).get("last", card))
		if not kind.is_empty():
			if TableActions.takes_range(kind) and last > card:
				parts.append("<!-- table: %s %d-%d -->" % [kind, card, last])
			else:
				parts.append("<!-- table: %s %d -->" % [kind, card] if TableActions.takes_card(kind)
					else "<!-- table: %s -->" % kind)
		var text := String((p as Dictionary).get("text", "")).strip_edges()
		if not text.is_empty():
			parts.append(text)
	return "\n\n".join(parts) + "\n"
