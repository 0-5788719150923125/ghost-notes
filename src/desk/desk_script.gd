extends RefCounted
class_name DeskScript

## DeskScript - a lesson as the voice reads it and the desk performs it.
##
## The lesson is the teacher's words, and a few own-line marks for what the pen does between them:
##
##     <!-- pad: \sum_{k=1}^{n} (2k-1) = n^2 -->     write a formula on the pad (TeX math; `\\` or an
##                                                   environment such as `aligned` for several lines)
##     <!-- pad-text: Suppose $p$ is prime. -->     write a line of prose, math inside it in $...$
##     <!-- strike -->                              cross out the last thing written: a dead end
##     <!-- new page -->                            tear the page off; the next writing starts fresh
##
## Everything else is speech. The voice's own marks (a delivery, a hesitation, a speaker) pass to
## the voice; any other comment is a note and is not read.
##
## ONE WALK, TWO READERS, as [CardReading] and [TabletScript] have it: [method parse] produces the
## spoken words the desk follows the voice by, the pen's actions anchored after them, and the text
## the voice reads ([member speakable]) with a rest for each run of actions
## (`<!-- action-hold: S -->`). The rest and the desk's schedule come from the same numbers, so they
## cannot disagree.
##
## WRITING OVERLAPS SPEECH. A teacher writes while talking, so a formula's rest is not the time it
## takes to write but what the writing outlasts its sentence by: the pen starts in the rest and goes
## on under the words that follow ([method hold_for]). How long a formula takes to write is the
## ink's ([method Ink.schedule] over the typeset item) - handed in as [param lengths] - or, before
## it is typeset, an estimate from its length.
##
## THE VOICE IS NEVER HANDED NOTATION ([method audit]): math the pen writes is TeX in a mark; math the
## voice says is words. A lesson whose speech carries `$`, `\`, `^`, `_` or braces is refused at its
## step (next/proof.md, "The voice and the math").

## The marks: group 1 the verb, group 2 what follows the colon.
const MARK := "^\\s*<!--\\s*(pad-text|pad|strike|new page)\\s*(?::\\s*(.*?))?\\s*-->\\s*$"

## A formula's rest is what its writing outlasts this many seconds of the sentence after it by...
const OVERLAP := 3.5
## ...but never less than the moment the pen takes to start, nor more than a long pause.
const MIN_HOLD := 0.6
const MAX_HOLD := 6.0
## A cross-out: the pen draws a line through the last thing written, deliberately.
const STRIKE := 0.9
## A page torn off and laid aside.
const PAGE := 1.3
## A formula's writing time before it is typeset: a guess from its TeX's length, close to what the
## ink measures for short formulas (a^2 + b^2 = c^2: 4.3 s written, 4.2 guessed).
const EST_BASE := 1.2
const EST_PER_CHAR := 0.2

## The environments TeX sets only outside math mode: a pad formula that is one is set as a display.
static var DISPLAY := RegEx.create_from_string("^\\s*\\\\begin\\{(align|gather|multline|flalign|alignat)\\*?\\}")

## Characters that are notation, never words: the voice must not be handed them.
const NOTATION := ["$", "\\", "^", "_", "{", "}"]


static func _rx(pattern: String) -> RegEx:
	var r := RegEx.new()
	r.compile(pattern)
	return r


## Is [param body] a lesson for the desk (does it carry a pen's mark)?
static func is_lesson(body: String) -> bool:
	return _rx("<!--\\s*(?:pad-text|pad|strike|new page)\\b").search(body) != null


## The item a pad mark writes, as the ink step typesets it and the desk draws it: `{id, tex, mode}`.
## The id is a hash of what is written, so the same formula is the same item wherever it appears.
static func item(kind: String, tex: String) -> Dictionary:
	var mode := "text"
	if kind == "pad":
		# MATH, unless it is a display environment of its own (align*, gather*), which TeX sets only
		# outside math: `aligned` - what the teacher is told to use - lives inside math, and set as a
		# display it was refused ("\\begin{aligned} allowed only in math mode", the first real episode)
		mode = "display" if DISPLAY.search(tex) != null else "math"
	return {"id": "p" + (kind + "|" + tex).sha256_text().substr(0, 12), "tex": tex, "mode": mode}


## Every item the pen writes in [param body], once each, in order: what the ink step typesets.
static func items(body: String) -> Array:
	var seen := {}
	var out: Array = []
	for a in parse(body)["actions"]:
		var act: Dictionary = a
		if String(act["kind"]) in ["pad", "pad-text"] and not seen.has(String(act["id"])):
			seen[String(act["id"])] = true
			out.append({"id": act["id"], "tex": act["tex"], "mode": act["mode"]})
	return out


## How long a formula's writing is held for, given how long it takes to write.
static func hold_for(length: float) -> float:
	return clampf(length - OVERLAP, MIN_HOLD, MAX_HOLD)


## How long [param tex] takes to write before the ink has measured it.
static func estimate(tex: String) -> float:
	return EST_BASE + EST_PER_CHAR * float(tex.length())


## [param body] as the voice reads it (see the class note); any other text untouched.
static func speakable(body: String, lengths: Dictionary = {}) -> String:
	if not is_lesson(body):
		return body
	return String(parse(body, lengths)["speakable"])


## THE WALK. [param lengths]: item id -> seconds its writing takes (the ink's), else estimated.
## Returns:
##   actions   - [{kind, id, tex, mode, after, dur, write}]: `after` = how many spoken words come
##               before it; `dur` the voice's rest for it; `write` how long the pen takes
##   spoken    - PackedStringArray: every spoken word, normalized ([method TabletScript.norm])
##   speakable - the text the voice reads
##   said      - the speech alone, marks and notes out: what [method audit] reads
static func parse(body: String, lengths: Dictionary = {}) -> Dictionary:
	var src := Manuscript.strip_frontmatter(body)
	var mark := _rx(MARK)
	var actions: Array = []
	var spoken := PackedStringArray()
	var speak := PackedStringArray()
	var said := PackedStringArray()
	var lines: Array = []
	var hold := 0.0
	for line in (src + "\n").split("\n"):
		var m := mark.search(line)
		if m == null:
			lines.append(line)
			continue
		if _flush(lines, spoken, speak, said):
			hold = 0.0          # words were said since the last rest: this mark starts a new one
		lines = []
		var kind := m.get_string(1)
		var arg := m.get_string(2).strip_edges()
		var act := {"kind": kind, "after": spoken.size(), "id": "", "tex": "", "mode": "", "write": 0.0}
		match kind:
			"pad", "pad-text":
				if arg.is_empty():
					continue
				act.merge(item(kind, arg), true)
				var length := float(lengths.get(String(act["id"]), estimate(arg)))
				act["write"] = length
				act["dur"] = hold_for(length)
			"strike":
				act["write"] = STRIKE
				act["dur"] = STRIKE
			"new page":
				act["write"] = PAGE
				act["dur"] = PAGE
		actions.append(act)
		hold += float(act["dur"])
		# a run of actions is one rest, placed where the next words begin
		if not speak.is_empty() and speak[speak.size() - 1].begins_with("<!-- action-hold:"):
			speak[speak.size() - 1] = "<!-- action-hold: %s -->" % String.num(hold, 2)
		else:
			speak.append("<!-- action-hold: %s -->" % String.num(hold, 2))
	_flush(lines, spoken, speak, said)
	return {"actions": actions, "spoken": spoken, "speakable": "\n\n".join(speak),
		"said": "\n\n".join(said)}


## The words before the next mark: into the spoken list, the voice's text and the speech. A rest
## ends at the first words after it. True when anything was added.
static func _flush(lines: Array, spoken: PackedStringArray, speak: PackedStringArray,
		said: PackedStringArray) -> bool:
	var text := "\n".join(PackedStringArray(lines)).strip_edges()
	if text.is_empty():
		return false
	var voiced := CardReading._voice_marks(text)
	var plain := Manuscript._rx(Manuscript.COMMENT).sub(text, "", true).strip_edges()
	if plain.is_empty() and voiced.is_empty():
		return false
	for w in plain.split(" ", false):
		for piece in String(w).split("\n", false):
			var n := TabletScript.norm(piece)
			if not n.is_empty():
				spoken.append(n)
	if not voiced.is_empty():
		speak.append(voiced)
	if not plain.is_empty():
		said.append(plain)
	return true


## WHAT THE VOICE WOULD BE HANDED THAT IS NOTATION: each line of speech carrying a character of
## [constant NOTATION], "" when there is none. Math the voice says is words ("n squared"), never TeX.
static func audit(body: String) -> PackedStringArray:
	var out := PackedStringArray()
	for line in String(parse(body)["said"]).split("\n"):
		for c in NOTATION:
			if String(line).contains(c):
				out.append(String(line).strip_edges().substr(0, 120))
				break
	return out
