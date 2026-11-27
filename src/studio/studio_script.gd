extends RefCounted
class_name StudioScript

## StudioScript - a note read at the studio (next/studio.md, "Acts"): its act marks read into acts, the words the voice says,
## and what the voice reads - each act a rest as long as it, unless it says `under`.
##
## An act is a mark, `<!-- VERB: words -->` ([constant StudioActs.VERBS]), on a line of its own or inside a paragraph (there
## it comes where it is written). Its words, split at commas, in any order: a thing ([constant StudioActs.THINGS]), a side
## ([constant StudioActs.SIDES]), a number of seconds, paces ([constant StudioActs.PACES]), a pressure, a pattern, a tool
## (nails, fingertips) and `under` (the words after it said over it). A word it does not know is named ([method parse]'s
## `unknown`), never guessed at.
##
## Pure: a function of the note's words. Gate: tests/studio/studio_script_check.gd.

## An act's mark: group 1 its verb, group 2 its words.
const MARK := "<!--\\s*(rub|brush|scratch|tap|scrape|knock|cup)\\s*:\\s*([^>]*?)\\s*-->"
## How long the studio is seen before the first word (s), and the rest left after an act before the words go on (s).
const OPENING := 2.5
const AFTER := 0.5


static func _rx(pattern: String) -> RegEx:
	return RegEx.create_from_string(pattern)


## The note [param body] read: `acts` (each `{verb, thing, side, secs, paces, press, pattern, tool, under, words, seed, after,
## i}`, `after` the number of spoken words before it), `spoken` (every spoken word, normalized - what the voice is followed
## by), `speakable` (what the voice reads: the words with a rest where each act is) and `unknown` (`[act index, word]` for
## each word an act's mark does not know).
static func parse(body: String) -> Dictionary:
	var src := Manuscript.strip_frontmatter(body)
	var mark := _rx(MARK)
	var acts: Array = []
	var unknown: Array = []
	var spoken := PackedStringArray()
	var speak := PackedStringArray()
	var seen := {}
	speak.append("<!-- action-hold: %s -->" % String.num(OPENING, 2))
	for raw_line in src.split("\n"):
		var line := String(raw_line)
		var stripped := line.strip_edges()
		# a heading is the title screen's, a rule a break: neither is said
		if stripped.begins_with("#") or stripped == "---" or stripped == "***":
			speak.append("")
			continue
		var out := ""
		var at := 0
		for m in mark.search_all(line):
			var before := line.substr(at, m.get_start() - at)
			out += before
			spoken.append_array(words_of(before))
			at = m.get_end()
			var words := m.get_string(2)
			var key := m.get_string(1) + ":" + words.strip_edges().to_lower()
			seen[key] = int(seen.get(key, 0)) + 1
			var act := act_of(m.get_string(1), words, unknown, acts.size())
			act["after"] = spoken.size()
			act["i"] = acts.size()
			# each act its own number: its words and how many times the same words came before it
			act["seed"] = 1 + absi(hash([key, int(seen[key])])) % 999983
			acts.append(act)
			if not bool(act["under"]):
				out += " <!-- action-hold: %s --> " % String.num(float(act["secs"]) + AFTER, 2)
		var rest := line.substr(at)
		out += rest
		spoken.append_array(words_of(rest))
		speak.append(out)
	return {"acts": acts, "spoken": spoken, "speakable": "\n".join(speak), "unknown": unknown}


## [param acts] as their takes have them ([param takes]: an act's own number, as text -> how many times it was made again): an act
## made again is a new performance, its number drawn from its own and the take's - the hands move otherwise, and so it sounds.
## Copies; the first take is the act as written.
static func with_takes(acts: Array, takes: Dictionary) -> Array:
	var out: Array = []
	for a in acts:
		var c := (a as Dictionary).duplicate()
		var n := int(takes.get(str(int(c["seed"])), 0))
		c["own"] = int(c["seed"])
		c["take"] = n
		if n > 0:
			c["seed"] = 1 + absi(hash([int(c["seed"]), n])) % 999983
		out.append(c)
	return out


## What the voice reads of [param body] ([method parse]'s `speakable`).
static func speakable(body: String) -> String:
	return String(parse(body)["speakable"])


## An act from its mark's verb [param verb] and [param words]; a word it does not know goes on [param unknown] as
## `[index, word]` ([param index] the act's).
static func act_of(verb: String, words: String, unknown: Array, index := 0) -> Dictionary:
	var row: Dictionary = StudioActs.VERBS[verb]
	var act := {"verb": verb, "thing": "", "side": "back", "secs": float(row["secs"]), "paces": [], "press": "", "pattern": "",
		"tool": "", "under": false, "words": words.strip_edges()}
	for piece in words.split(",", false):
		var p := String(piece).strip_edges().to_lower()
		if p.is_empty():
			continue
		if not _take(act, p, verb):
			# a piece not known whole is read a word at a time ("slow firm")
			for word in p.split(" ", false):
				if not _take(act, String(word), verb):
					unknown.append([index, String(word)])
	if String(act["thing"]).is_empty():
		act["thing"] = String((row["things"] as Array)[0])
	elif not (row["things"] as Array).has(act["thing"]):
		unknown.append([index, "%s (a %s cannot be done to it)" % [act["thing"], verb]])
		act["thing"] = String((row["things"] as Array)[0])
	return act


## Word or words [param p] taken into [param act], if they name something it can be told.
static func _take(act: Dictionary, p: String, _verb: String) -> bool:
	if p == "under":
		act["under"] = true
		return true
	var num := p.trim_suffix("seconds").trim_suffix("second").trim_suffix("secs").trim_suffix("s").strip_edges()
	if num.is_valid_float():
		act["secs"] = clampf(float(num), 1.0, 180.0)
		return true
	var thing := StudioActs.key_in(StudioActs.THINGS, p)
	if not thing.is_empty():
		act["thing"] = thing
		return true
	if StudioActs.SIDES.has(p):
		act["side"] = p
		return true
	if StudioActs.PACES.has(p):
		(act["paces"] as Array).append(p)
		return true
	if StudioActs.PRESSES.has(p):
		act["press"] = p
		return true
	if StudioActs.PATTERNS.has(p):
		act["pattern"] = p
		return true
	if StudioActs.TOOLS.has(p):
		act["tool"] = String(StudioActs.TOOLS[p])
		return true
	return false


## A stretch of words as the voice says them, normalized: comments out, a delivery's braces out, a word said a way said as itself.
static func words_of(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	var plain := Manuscript._rx(Manuscript.COMMENT).sub(text, " ", true)
	plain = _rx("\\{[^}]*\\}").sub(plain, "", true)
	plain = plain.replace("[", "").replace("]", "")
	for w in plain.split(" ", false):
		for piece in String(w).split("\n", false):
			var n := TabletScript.norm(piece)
			if not n.is_empty():
				out.append(n)
	return out


## Each spoken word's moment as a steady voice would say it (s from the top): what a reading started part way is placed by
## before the voice has said those words. [param pace] words a second.
static func word_starts(parsed: Dictionary, pace := 2.3) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var acts: Array = parsed["acts"]
	var t := OPENING
	var k := 0
	for i in (parsed["spoken"] as PackedStringArray).size():
		while k < acts.size() and int((acts[k] as Dictionary)["after"]) <= i:
			if not bool((acts[k] as Dictionary)["under"]):
				t += float((acts[k] as Dictionary)["secs"]) + AFTER
			k += 1
		out.append(t)
		t += 1.0 / pace
	return out


## A steady voice's words for [param parsed] (each `{text, t0, t1}`): a word every [param word] seconds, [param pause] between
## lines, each act's rest and each timed hesitation as written, the first word [param lead] seconds in - what a gate and a probe
## hand the studio in place of a voice.
static func rehearsal(parsed: Dictionary, word := 0.38, pause := 0.4, lead := 1.0) -> Array:
	var spoken: PackedStringArray = parsed["spoken"]
	var token := _rx("<!--\\s*action-hold\\s*:\\s*([0-9.]+)\\s*-->|<!--\\s*hesitation\\s*(?::\\s*([0-9.]+))?\\s*-->|<!--.*?-->|\\S+")
	var out: Array = []
	var t := lead
	for line in String(parsed["speakable"]).split("\n"):
		var any := false
		for m in token.search_all(String(line)):
			if not m.get_string(1).is_empty():
				t += float(m.get_string(1))
			elif m.get_string().contains("hesitation"):
				t += float(m.get_string(2)) if not m.get_string(2).is_empty() else 1.0
			elif not m.get_string().begins_with("<!--") and not words_of(m.get_string()).is_empty():
				for _w in words_of(m.get_string()):
					if out.size() < spoken.size():
						out.append({"text": spoken[out.size()], "t0": t, "t1": t + word * 0.9, "sentence": 0})
					t += word
				any = true
		if any:
			t += pause
	return out
