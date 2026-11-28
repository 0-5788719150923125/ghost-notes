extends RefCounted
class_name StudioScript

## StudioScript - a note read at the studio (next/studio.md, "Acts"): its act marks read into acts, the words the voice says,
## and what the voice reads.
##
## An act is a mark, `<!-- VERB: words -->` ([constant StudioActs.VERBS]), on a line of its own or inside a paragraph (there
## it comes where it is written). Its words, split at commas, in any order: a thing ([constant StudioActs.THINGS]), a side
## ([constant StudioActs.SIDES]), a hand ([constant StudioActs.HANDS]), a number of seconds, paces ([constant StudioActs.PACES]),
## a pressure, a pattern, a tool (nails, fingertips) and `alone` - and how it is heard: a level (`-6 dB`) and a muffle ([constant
## MUFFLES], `muffled 0.3`), which change its sound as it plays and never what the hands do. A word it does not know is named
## ([method parse]'s `unknown`), never guessed at.
##
## AN ACT GOES ON UNDER THE WORDS until it ends: at its closing mark (`<!-- /VERB -->`, or `<!-- /VERB: left hand -->` where both
## hands do it), after its seconds where it names a number, when another act takes its hand, or at the end of the script. The
## voice talks over it; an act said `alone` (with its seconds) is heard on its own, the voice waiting it out. TWO HANDS: an act
## takes the hand it names, else the one on the side it works (left of the microphone, the left), else a free one; cupping,
## scraping and knocking take both, as does anything done to a thing held in both (the blocks, [constant StudioActs.THINGS] `both`).
## An act that names no side works its hand's side.
##
## Pure: a function of the note's words. Gate: tests/studio/studio_script_check.gd.

## An act's mark: group 1 its verb, group 2 its words.
const MARK := "<!--\\s*(rub|brush|scratch|tap|scrape|knock|cup)\\s*:\\s*([^>]*?)\\s*-->"
## The mark an act ends at: group 1 its verb, group 2 the hand it names (or nothing).
const CLOSE := "<!--\\s*/\\s*(rub|brush|scratch|tap|scrape|knock|cup)\\s*(?::\\s*([^>]*?))?\\s*-->"
## Either, in the order written: group 1 the slash of a closing mark, group 2 the verb, group 3 the words.
const EITHER := "<!--\\s*(/?)\\s*(rub|brush|scratch|tap|scrape|knock|cup)\\s*(?::\\s*([^>]*?))?\\s*-->"
## What an act left open runs on past the last word (s).
const PAST_LAST := 2.0
## The words that muffle an act's sound, and how much (0 as made, 1 through thick cloth): how it is heard, not what the hands do.
const MUFFLES := {"slightly muffled": 0.25, "a little muffled": 0.25, "muffled": 0.5, "very muffled": 0.85, "unmuffled": 0.0, "clear": 0.0}
## How long the studio is seen before the first word (s), and the rest left after an act before the words go on (s).
const OPENING := 2.5
const AFTER := 0.5


static func _rx(pattern: String) -> RegEx:
	return RegEx.create_from_string(pattern)


## The note [param body] read - each act's words as [param changed] has them where it has them (`{own number: words}`, a Refine's):
## `acts` (each `{verb, thing, side, hand, secs, timed, alone, under, paces, press, pattern, tool,
## words, seed, after, end, ends, i}`: `after` the number of spoken words before it, `end` the number before the word it ends at
## (-1 none: it runs its seconds, or to the end), `ends` what ends it - "mark", "hand", "secs" or "end"), `spoken` (every spoken
## word, normalized - what the voice is followed by), `speakable` (what the voice reads: a rest where an act said `alone` is),
## `unknown` (`[act index, word]` for each word an act's mark does not know) and `stray` (each closing mark that ends nothing).
static func parse(body: String, changed := {}) -> Dictionary:
	var src := Manuscript.strip_frontmatter(body)
	var mark := _rx(EITHER)
	var closes: Array = []           # {verb, hand, after}: each closing mark, in order
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
			var words := m.get_string(3)
			if m.get_string(1) == "/":
				closes.append({"verb": m.get_string(2), "hand": hand_in(words), "after": spoken.size(), "order": acts.size()})
				continue
			var key := m.get_string(2) + ":" + words.strip_edges().to_lower()
			seen[key] = int(seen.get(key, 0)) + 1
			# its words as a Refine changed them ([param changed]: its own number, as text -> its words), its number its own still
			var own_seed := 1 + absi(hash([key, int(seen[key])])) % 999983
			if changed.get(str(own_seed)) is String:
				words = String(changed[str(own_seed)])
			var act := act_of(m.get_string(2), words, unknown, acts.size())
			act["after"] = spoken.size()
			act["i"] = acts.size()
			# each act its own number: its words as written and how many times the same words came before it
			act["seed"] = own_seed
			acts.append(act)
			if not bool(act["under"]):
				out += " <!-- action-hold: %s --> " % String.num(float(act["secs"]) + AFTER, 2)
		var rest := line.substr(at)
		out += rest
		spoken.append_array(words_of(rest))
		speak.append(out)
	var stray := hands_and_ends(acts, closes)
	return {"acts": acts, "spoken": spoken, "speakable": "\n".join(speak), "unknown": unknown, "stray": stray}


## Each of [param acts] given its hand and where it ends ([param closes]: each closing mark, `{verb, hand, after, order}` - `order`
## how many acts were opened before it), in the order written; the closing marks that end nothing, as written (`/VERB`).
static func hands_and_ends(acts: Array, closes: Array) -> PackedStringArray:
	var holding := {"left": -1, "right": -1}
	var stray := PackedStringArray()
	var ci := 0
	for i in acts.size() + 1:
		# the closing marks written before this act
		while ci < closes.size() and int((closes[ci] as Dictionary)["order"]) <= i:
			var c: Dictionary = closes[ci]
			ci += 1
			var found := -1
			for h in ["right", "left"]:
				var k := int(holding[h])
				if k >= 0 and String((acts[k] as Dictionary)["verb"]) == String(c["verb"]) and (String(c["hand"]).is_empty() \
						or String(c["hand"]) == h or String((acts[k] as Dictionary)["hand"]) == "both") and (found < 0 or k > found):
					found = k
			if found < 0:
				stray.append("/" + String(c["verb"]))
				continue
			_end(acts[found], int(c["after"]), "mark")
			for h in holding:
				if int(holding[h]) == found:
					holding[h] = -1
		if i >= acts.size():
			break
		var a: Dictionary = acts[i]
		var hand := String(a["hand"])
		# (a thing held in both hands takes both, whichever hand the mark names)
		if bool((StudioActs.THINGS.get(String(a["thing"]), {}) as Dictionary).get("both", false)):
			hand = "both"
		elif hand.is_empty():
			if StudioActs.BOTH_HANDS.has(String(a["verb"])):
				hand = "both"
			else:
				var x := StudioActs.side_at(String(a["side"]), 0.0).x if bool(a.get("side_named", false)) else 0.0
				hand = "left" if x < -0.3 else "right" if x > 0.3 else ("right" if int(holding["right"]) < 0 else "left" if int(holding["left"]) < 0 else "right")
		a["hand"] = hand
		if not bool(a.get("side_named", false)) and hand != "both" and String(a["thing"]) == "fur":
			a["side"] = "back-left" if hand == "left" else "back-right"
		for h in (["left", "right"] if hand == "both" else [hand]):
			var k := int(holding[h])
			if k >= 0:
				_end(acts[k], int(a["after"]), "hand")
				for g in holding:
					if int(holding[g]) == k:
						holding[g] = -1
			holding[h] = i
	# what is still open runs on: its seconds, or to the end
	for a in acts:
		if String((a as Dictionary).get("ends", "")).is_empty():
			(a as Dictionary)["ends"] = "secs" if bool((a as Dictionary)["timed"]) else "end"
	return stray


## Act [param a] ending at the word after [param after] spoken words, by [param why] - unless it ends sooner by its seconds (which
## the moment it ends is worked out from).
static func _end(a: Dictionary, after: int, why: String) -> void:
	if not String(a.get("ends", "")).is_empty():
		return
	a["end"] = after
	a["ends"] = why


## The hand [param words] name ([constant StudioActs.HANDS]), "" for none.
static func hand_in(words: String) -> String:
	for piece in words.split(",", false):
		var p := String(piece).strip_edges().to_lower()
		if StudioActs.HANDS.has(p):
			return String(StudioActs.HANDS[p])
	return ""


## How long each act that goes on is likely to run, as a steady voice says [param parsed]'s words ([method word_starts]): `{i: s}`,
## from its first word to where it ends (or a little past the last word), with some to spare.
static func lengths(parsed: Dictionary) -> Dictionary:
	var out := {}
	var starts := word_starts(parsed)
	var n := starts.size()
	var last := (starts[n - 1] + PAST_LAST) if n > 0 else OPENING
	for a in parsed["acts"]:
		var d: Dictionary = a
		if bool(d["timed"]):
			continue
		var t0 := starts[int(d["after"])] if int(d["after"]) < n else last
		var e := int(d["end"])
		var t1 := starts[e] if e >= 0 and e < n else last
		out[int(d["i"])] = maxf(t1 - t0, 2.0) * 1.15 + 2.0
	return out


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
	var act := {"verb": verb, "thing": "", "side": "back", "side_named": false, "hand": "", "secs": float(row["secs"]), "timed": false,
		"alone": false, "under": true, "paces": [], "press": "", "pattern": "", "tool": "", "end": -1, "ends": "", "words": words.strip_edges(),
		"db": 0.0, "muffle": 0.0}
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
	# (every act goes on under the words: `under` is what it already does)
	if p == "under":
		return true
	if p == "alone":
		act["alone"] = true
		act["under"] = false
		act["timed"] = true
		return true
	if StudioActs.HANDS.has(p):
		act["hand"] = String(StudioActs.HANDS[p])
		return true
	# how it is heard, never what the hands do: a level (`-6 dB`) and a muffle (`muffled`, `very muffled`, `muffled 0.3`)
	if p.ends_with("db") and p.trim_suffix("db").strip_edges().is_valid_float():
		act["db"] = clampf(float(p.trim_suffix("db").strip_edges()), -30.0, 12.0)
		return true
	if MUFFLES.has(p):
		act["muffle"] = float(MUFFLES[p])
		return true
	if p.begins_with("muffled ") and p.trim_prefix("muffled ").strip_edges().is_valid_float():
		act["muffle"] = clampf(float(p.trim_prefix("muffled ").strip_edges()), 0.0, 1.0)
		return true
	var num := p.trim_suffix("seconds").trim_suffix("second").trim_suffix("secs").trim_suffix("s").strip_edges()
	if num.is_valid_float():
		act["secs"] = clampf(float(num), 1.0, StudioActs.LONGEST)
		act["timed"] = true
		return true
	var thing := StudioActs.key_in(StudioActs.THINGS, p)
	if not thing.is_empty():
		act["thing"] = thing
		return true
	if StudioActs.SIDES.has(p):
		act["side"] = p
		act["side_named"] = true
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
