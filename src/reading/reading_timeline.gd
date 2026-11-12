extends RefCounted
class_name ReadingTimeline

## ReadingTimeline - A NOTE'S WORDS AS A TIMELINE (next/editing.md step 12: "the Letter and the Dispatch desk hand a score from the
## marks they have"): every mark in the words (`<!-- name: what -->`, the [ScriptMarks] a script may carry - a Letter's strike and
## sketch, the Dispatch desk's `heard`, `redact`, `bell` and `lamp`, a reading's `pause`) a flag where it stands in them, on the
## voice's clock - each word as long as the reader says one ([method ReadingCast.said_word]), a rest a mark asks for counted in -
## and each heading of the words a group of its own. One reader for every show that is a reading, whatever presents it: what the
## marks do is the medium's; where they fall is the words'. Read-only: a mark is moved in the words.

const MARK := "<!--\\s*([A-Za-z][\\w-]*)\\s*(?::\\s*(.*?))?\\s*-->"
## A mark's rest, seconds, where it asks for one (`<!-- pause: 2 -->`).
const RESTS := ["pause", "rest", "hold"]


## [param body] (the words as the voice reads them, marks in) on the voice's clock, each word [param said_word] seconds. Every
## item's `source` is `["body", "mark", <the mark's place in the text>]`, its `text` the mark as written. {} for words with no marks.
static func of(body: String, said_word: float) -> Dictionary:
	var rx := RegEx.create_from_string(MARK)
	var words := RegEx.create_from_string("[\\p{L}\\p{N}][\\p{L}\\p{N}'’-]*")
	var groups: Array = []
	var g := Timeline.group("words", "The words", 0.0, 0.0, "time")
	var t := 0.0
	var at := 0
	var marks := 0
	var lines := body.split("\n")
	var pos := 0
	for line in lines:
		var ln := String(line)
		var head := ln.strip_edges().begins_with("#")
		if head:
			if not (g["lanes"] as Array).is_empty() or t > float(g["start"]):
				g["length"] = maxf(t - float(g["start"]), 0.05)
				groups.append(g)
			g = Timeline.group("h%d" % groups.size(), ln.strip_edges().trim_prefix("#").strip_edges().lstrip("#").strip_edges(), t, 0.0, "time")
		var from := 0
		for m in rx.search_all(ln):
			t += float(words.search_all(ln.substr(from, m.get_start() - from)).size()) * said_word
			from = m.get_end()
			var key := m.get_string(1).to_lower()
			var what := m.get_string(2).strip_edges()
			var label := (String(ScriptMarks.REGISTRY[key].get("label", key)) if ScriptMarks.REGISTRY.has(key) else key)
			var it := Timeline.item("m%d" % marks, (label + (": " + what.left(24) if not what.is_empty() else "")).strip_edges(),
				t - float(g["start"]), 0.0, ["body", "mark", pos + m.get_start()])
			it["text"] = m.get_string()
			Timeline.add(g, key, label, it)
			marks += 1
			if RESTS.has(key) and what.is_valid_float():
				t += float(what)
		if not head:
			t += float(words.search_all(ln.substr(from)).size()) * said_word
		pos += ln.length() + 1
		at += 1
	g["length"] = maxf(t - float(g["start"]), 0.05)
	groups.append(g)
	if marks == 0:
		return {}
	return Timeline.make("voice", groups)
