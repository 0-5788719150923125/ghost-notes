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
## `deal 2`, `fan 3-5` (a run of cards in one waterfall), `show 4`, `tap 2`, `untap 2`, `flip 2`, and
## `work 2` (the card goes down and the work of its beat begins - [TableWork]).
##
## A READING WITH NO CARDS opens with `begin` and each of its beats with `work K` - K a beat, never a card -
## and closes with `spread`: nothing is drawn, and each beat is a chapter of the video.
##
## AN ACT AT A WORD (next/table_work.md): inside speech, `<!-- act: grind -->` starts the episode's act
## `grind` as the word after it is said - what is done is said as it is done. [method parse] lists each
## (`cues`, `{name, si}`: the spoken word it starts at); the voice never hears the mark.
##
## A CHAPTER AT A WORD (2026-10-31, the user of the-quiet-crucible 841899's description: "0:00 Intro, 1:58
## The Card from the Tin - Lighting a New Furnace, 9:14 The spread" - a seven-minute brew in one chapter, and
## a card-reading word for a show that brews): `<!-- chapter: its name -->`, written by the reader where the
## video turns to a part a viewer would look for, starts one at the word after it; before a passage's first
## word it names the chapter the passage's own mark begins ([method chapters]). No agent writes a time: the
## take's word timings place every chapter. The voice never hears the mark.
##
## THE READING IS WRITTEN FOR THE TABLE, by [TableProducer], one passage per mark - the intro
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


## An act cued at a word, inside speech: group 1 the act's name.
const ACT_MARK := "<!--\\s*act\\s*:\\s*([\\w-]+)\\s*-->"
## A CHAPTER OF THE VIDEO, named by the reader where its words begin one: group 1 its name.
const CHAPTER_MARK := "<!--\\s*chapter\\s*:\\s*([\\s\\S]*?)\\s*-->"
## A SILENCE, written where the reader stops talking and the work goes on (the user, 2026-11-02: "There might be stretches where we do
## not talk at all"): group 1 its seconds. It is a rest as a table's move is, never a hesitation, so it stays with the Hesitate box
## off and is as long as it says up to QUIET_MOST; a passage's words may end on one, and it is still its beat's ([method
## TableWork.schedule], an action's `tail`). An act cued inside one begins as much into it as is written before its mark.
const QUIET_MARK := "<!--\\s*quiet\\s*:\\s*([0-9]*\\.?[0-9]+)\\s*-->"
const QUIET_MOST := 240.0
## AN EPISODE OPENS TALKING ([method opens_talking]): how many words come before any silence, what is only a breath (seconds), and the most that is kept of
## what was written before them.
const OPEN_WORDS := 60
const OPEN_BREATH := 3.0
const OPEN_HELD := 30.0


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
##   cues      - [{name, si}]: each act cued at a word, `si` the spoken word it starts at
##   chapters  - [{name, si, opens, action}]: each chapter mark; `opens` when no word of its passage is
##               before it, `action` the index of its passage's own action (-1: none)
##   quiets    - [{si, s}]: each silence ([constant QUIET_MARK]), `si` the spoken word it comes before, `s` its seconds
static func parse(body: String) -> Dictionary:
	var src := opens_talking(Manuscript.strip_frontmatter(body))
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
	var cues: Array = []
	var chapters: Array = []
	var quiets: Array = []
	var quiet_rx := _rx(QUIET_MARK)
	var act_rx := _rx(ACT_MARK)
	var chapter_rx := _rx(CHAPTER_MARK)
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
		# AN ACT AT A WORD: the spoken words before its mark, counted as the table counts them
		for m in act_rx.search_all(text):
			var cue := {"name": m.get_string(1).strip_edges().to_lower(), "si": spoken.size() + _words_before(text, m.get_start())}
			# ...IN A SILENCE, no word comes at it: it is timed from the word before, and how far into the silence it stands
			var into := quiet_around(text, m.get_start(), m.get_end())
			if into >= 0.0:
				cue["quiet"] = into
			cues.append(cue)
		# A SILENCE: the word it comes before, for what estimates a reading's time ([method TablePlan.estimated_times])
		for m in quiet_rx.search_all(text):
			quiets.append({"si": spoken.size() + _words_before(text, m.get_start()), "s": minf(float(m.get_string(1)), QUIET_MOST)})
		# A CHAPTER AT A WORD, and whether it opens its passage - then it names the chapter of the passage's
		# own mark (`action`, the index that mark's action is about to take; -1 for words before any mark)
		for m in chapter_rx.search_all(text):
			var named := " ".join(m.get_string(1).split("\n", false)).strip_edges()
			if named.is_empty():
				continue
			var n_before := _words_before(text, m.get_start())
			chapters.append({"name": named, "si": spoken.size() + n_before, "opens": n_before == 0,
				"action": actions.size() if not kind.is_empty() else -1})
		var tail_quiet := quiet_at_end(text)
		var lead_quiet := quiet_at_start(text)
		text = Manuscript._rx(Manuscript.COMMENT).sub(text, "", true).strip_edges()
		if not kind.is_empty():
			if not TableActions.source_of(kind).is_empty():
				source = TableActions.source_of(kind)
			var card := int((p as Dictionary)["card"])
			var last := maxi(int((p as Dictionary).get("last", card)), card)
			var takes := TableActions.takes_from_source(kind)
			var dur := TableActions.rest_of(kind, showing, takes and not moved,
				bool((TableActions.SOURCES[source] as Dictionary)["pushes"]), last - card + 1)
			actions.append({"kind": kind, "card": card, "last": last, "after": spoken.size(), "dur": dur, "tail": tail_quiet, "lead": lead_quiet})
			speak.append("<!-- action-hold: %s -->" % String.num(dur, 2))
			moved = moved or takes
			if TableActions.shows(kind):
				showing = true
			elif TableActions.ends(kind) or (showing and TableActions.REGISTRY[kind]["lays"]):
				showing = false
			if TableActions.takes_card(kind) and not TableActions.names_beat(kind):
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
		"speakable": "\n\n".join(speak), "cards": cards, "source": source, "cues": cues, "chapters": chapters, "quiets": quiets}


## HOW FAR INTO A SILENCE a mark from [param from] to [param to] in [param text] stands: the seconds of the quiet marks between the word
## before it and it, if there is any quiet between the word before it and the word after it; -1 when it is at a word.
## AN EPISODE OPENS TALKING (the user, 2026-11-03, of the first real one, whose reader was told it might open in silence and did: "a solid 45 seconds of silence at
## the beginning ... which feels wrong. We definitely need an intro, even if we're going to go silent at parts throughout"). Whatever was written and whenever: a
## silence before the first [constant OPEN_WORDS] words comes out, and as much as [constant OPEN_HELD] of what came out falls at the next paragraph's end instead.
## A breath stays. The work goes on under the talk, and its stops take what the silence would have given it.
static func opens_talking(src: String) -> String:
	var words := 0
	var cuts: Array = []
	var total := 0.0
	var quiet := _rx(QUIET_MARK)
	var at_end := -1
	var tokens := _rx("<!--.*?-->|\\S+")
	for m in tokens.search_all(src):
		var tok := m.get_string()
		if tok.begins_with("<!--"):
			var q := quiet.search(tok)
			if q != null and float(q.get_string(1)) > OPEN_BREATH:
				cuts.append([m.get_start(), m.get_end()])
				total += float(q.get_string(1))
			elif tok.contains("table:") and words > 0:
				at_end = m.get_start()
				break
			continue
		words += 1
		if words >= OPEN_WORDS:
			at_end = m.get_end()
			break
	if cuts.is_empty():
		return src
	if at_end < 0:
		at_end = src.length()
	elif words >= OPEN_WORDS:
		# ...at the paragraph's end, or before the next beat if that comes first: never in the middle of a thought
		var para := src.find("\n\n", at_end)
		var beat := src.find("<!-- table:", at_end)
		at_end = src.length() if para < 0 and beat < 0 else (mini(para, beat) if para >= 0 and beat >= 0 else maxi(para, beat))
	var held := "\n\n<!-- quiet: %d -->\n\n" % roundi(minf(total, OPEN_HELD))
	var out := src.substr(0, at_end) + held + src.substr(at_end)
	cuts.reverse()
	for c in cuts:
		out = out.substr(0, int(c[0])) + out.substr(int(c[1]))
	return out


static func quiet_around(text: String, from: int, to: int) -> float:
	var q := _rx(QUIET_MARK)
	var before := 0.0
	var some := false
	var head := text.substr(0, from)
	var last_word := -1
	var stripped := Manuscript._rx(Manuscript.COMMENT)
	# the end of the last word before it: the last place outside a comment that holds other than space
	var at := 0
	for m in stripped.search_all(head):
		if not head.substr(at, m.get_start() - at).strip_edges().is_empty():
			last_word = m.get_start()
		at = m.get_end()
	if not head.substr(at).strip_edges().is_empty():
		last_word = head.length()
	for m in q.search_all(head):
		if m.get_start() >= last_word:
			before += minf(float(m.get_string(1)), QUIET_MOST)
			some = true
	var tail := text.substr(to)
	var next_word := tail.length()
	at = 0
	for m in stripped.search_all(tail):
		if not tail.substr(at, m.get_start() - at).strip_edges().is_empty():
			next_word = at
			break
		at = m.get_end()
	if next_word == tail.length() and not tail.substr(at).strip_edges().is_empty():
		next_word = at
	for m in q.search_all(tail):
		if m.get_start() < next_word:
			some = true
	return before if some else -1.0


## The silence [param text] opens on: the seconds of the quiet marks before its first word. The move of a mark is made before it, not
## after ([method ReadingFollower.place], `lead`): a beat that opens in silence opens as the silence does.
static func quiet_at_start(text: String) -> float:
	var q := _rx(QUIET_MARK)
	var at := 0
	var out := 0.0
	for m in Manuscript._rx(Manuscript.COMMENT).search_all(text):
		if not text.substr(at, m.get_start() - at).strip_edges().is_empty():
			return out
		var hit := q.search(m.get_string())
		if hit != null:
			out += minf(float(hit.get_string(1)), QUIET_MOST)
		at = m.get_end()
	return out


## The silence [param text] ends on: the seconds of the quiet marks after its last word.
static func quiet_at_end(text: String) -> float:
	var q := _rx(QUIET_MARK)
	var stripped := Manuscript._rx(Manuscript.COMMENT)
	var last_word := 0
	var at := 0
	for m in stripped.search_all(text):
		if not text.substr(at, m.get_start() - at).strip_edges().is_empty():
			last_word = m.get_start()
		at = m.get_end()
	if not text.substr(at).strip_edges().is_empty():
		return 0.0
	var out := 0.0
	for m in q.search_all(text):
		if m.get_start() >= last_word:
			out += minf(float(m.get_string(1)), QUIET_MOST)
	return out


## How many spoken words of [param text] come before [param at], counted as the table counts them.
static func _words_before(text: String, at: int) -> int:
	var n := 0
	for w in Manuscript._rx(Manuscript.COMMENT).sub(text.substr(0, at), "", true).split(" ", false):
		for piece in String(w).split("\n", false):
			if not TabletScript.norm(piece).is_empty():
				n += 1
	return n


## [param text] with every comment taken out but the ones the voice acts on: a delivery, a
## hesitation, a change of speaker - which is put on a line of its own, since a cue anywhere else
## is read past as a note and the line goes to whoever spoke before it.
static func _voice_marks(text: String) -> String:
	var lean := _rx(Manuscript.DELIVERY)
	var hes := _rx(Manuscript.HESITATION)
	var cue := _rx(Manuscript.SPEAKER)
	var quiet := _rx(QUIET_MARK)
	var out := ""
	var at := 0
	for m in _rx(Manuscript.COMMENT).search_all(text):
		out += text.substr(at, m.get_start() - at)
		at = m.get_end()
		var q := quiet.search(m.get_string())
		if q != null:
			# a table's rest, as a move's is ([constant QUIET_MARK])
			out += "<!-- action-hold: %s -->" % String.num(minf(float(q.get_string(1)), QUIET_MOST), 2)
		elif lean.search(m.get_string()) != null or hes.search(m.get_string()) != null:
			out += m.get_string()
		elif cue.search(m.get_string()) != null:
			out = out.rstrip(" \t") + "\n" + m.get_string().strip_edges() + "\n"
	return (out + text.substr(at)).strip_edges()


## THE VIDEO'S CHAPTERS, from a rendered take: when the intro, each card and the close begin, and each
## chapter the reader named, found by following the take's own word timings ([param words], a sidecar's)
## through the reading exactly as the table does - so a chapter starts where the cards move, or at the
## word its mark is before. `[{t, kind, card, name}]` in time order, the first the intro at 0; `name` is
## the reader's (a passage's opening mark names its own action's chapter, the opening verb's the intro's,
## and makes a chapter of an action that is none of itself - a card's work), "" where it named none, for
## the caller to label. A reading with no cards ([constant TableActions.SOURCES] `none`) has a chapter at
## each beat: its `work` marks. A mark inside a passage is `kind` "named".
static func chapters(body: String, words: Array) -> Array:
	var p := parse(body)
	var f := ReadingFollower.new()
	f.reset(p["spoken"])
	f.extend(words)
	var actions: Array = p["actions"]
	var names := {}           # an action's index (-1, the intro) -> the name its passage opens with
	var inside: Array = []
	for c in p["chapters"]:
		var d: Dictionary = c
		var i := int(d["action"])
		if not bool(d["opens"]):
			inside.append(d)
			continue
		if i < 0 or i >= actions.size() or not TableActions.source_of(String((actions[i] as Dictionary)["kind"])).is_empty():
			i = -1
		if not names.has(i):
			names[i] = String(d["name"])
	var out: Array = [{"t": 0.0, "kind": "intro", "card": 0, "name": String(names.get(-1, ""))}]
	var beats := String(p["source"]) == "none"
	var placed := f.place(actions, 0.0, 0.25, 0.2)
	for k in placed.size():
		var a: Dictionary = (placed[k] as Dictionary)["a"]
		var kind := String(a["kind"])
		if not names.has(k) and not TableActions.chapter(kind) and not (beats and kind == "work"):
			continue
		out.append({"t": maxf(0.0, float((placed[k] as Dictionary)["t0"])), "kind": kind,
			"card": int(a["card"]), "name": String(names.get(k, ""))})
	for d in inside:
		var si := int(d["si"])
		if si < f.said0.size() and f.said0[si] != ReadingFollower.NO_TIME:
			out.append({"t": maxf(0.0, f.said0[si]), "kind": "named", "card": 0, "name": String(d["name"])})
	# (the intro stays first: a sort is not stable, and an action may start at 0 too)
	var rest := out.slice(1)
	rest.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x["t"]) < float(y["t"]))
	return [out[0]] + rest


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
