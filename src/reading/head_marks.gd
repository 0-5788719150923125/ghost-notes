extends RefCounted
class_name HeadMarks

## HeadMarks - the speaker's head as a script and a take have it (next/head.md): the phrases the script calls (`<!-- head: NAME -->`,
## a phrase of the show's bank, [HeadBank]), each timed at the word after it as the take says it - the script's spoken words matched
## to the take's own by the follower the Studio reads with ([ReadingFollower]) - and the head performed on the take's words from them
## and the bank ([method plan], [HeadPlan]). The take's voice is placed by it ([method lane], [VoiceFX] `place`) and the Studio's camera
## moves by it ([StudioMedium]), from the same words, bank and number ([constant SEED]), so they are one performance. A show with no
## bank places nothing.
##
## A heading or a rule is never said, and a mark's own words are never spoken. Pure. Gate: tests/reading/head_lane_check.gd.

## A head mark: group 1 its words.
const MARK := "<!--\\s*head\\s*:\\s*([^>]*?)\\s*-->"
## Every head plan's own number: the same script moves the same in the voice and in the picture.
const SEED := 1


static func _rx(pattern: String) -> RegEx:
	return RegEx.create_from_string(pattern)


## [param body]'s head marks and its spoken words: `{marks: [{after, words}], spoken}` - `after` how many spoken words come before it.
static func read(body: String) -> Dictionary:
	var src := Manuscript.strip_frontmatter(body)
	var mark := _rx(MARK)
	var marks: Array = []
	var spoken := PackedStringArray()
	for raw_line in src.split("\n"):
		var line := String(raw_line)
		var stripped := line.strip_edges()
		if stripped.begins_with("#") or stripped == "---" or stripped == "***":
			continue
		var at := 0
		for m in mark.search_all(line):
			spoken.append_array(words_of(line.substr(at, m.get_start() - at)))
			at = m.get_end()
			marks.append({"after": spoken.size(), "words": m.get_string(1)})
		spoken.append_array(words_of(line.substr(at)))
	return {"marks": marks, "spoken": spoken}


## Whether [param body] places the head at all.
static func has_marks(body: String) -> bool:
	return _rx(MARK).search(body) != null


## The spoken words of [param text], normalized as the follower matches them: its marks, a delivery's terms and brackets left out.
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


## [param body]'s head marks timed on [param words] (a take's: each `{text, t0, t1}`), each at the start of the word after it - or
## a mark whose word is not heard yet, left out: `[{at, name}]`.
static func timed(body: String, words: Array) -> Array:
	var d := read(body)
	var marks: Array = d["marks"]
	if marks.is_empty():
		return []
	var f := ReadingFollower.new()
	f.reset(d["spoken"])
	f.extend(words)
	var out: Array = []
	var n := f.said0.size()
	for m in marks:
		var k := int((m as Dictionary)["after"])
		var at := ReadingFollower.NO_TIME
		# the word after it, or (a mark at the very end) the end of the last
		if k < n and f.said0[k] != ReadingFollower.NO_TIME:
			at = f.said0[k]
		elif k >= n and n > 0 and f.st1[n - 1] != ReadingFollower.NO_TIME:
			at = f.st1[n - 1]
		if at != ReadingFollower.NO_TIME:
			out.append({"at": at, "name": String((m as Dictionary)["words"]).strip_edges().to_lower()})
	return out


## The head performed for [param body] as [param words] say it, from the show's [param bank] ([HeadPlan]), as gently as [param feel]
## says ([method HeadPlan.feel_of]); {} where the show has no bank. [param targets]: where a move's `look` looks.
static func plan(body: String, words: Array, bank: Array, targets := {}, feel := {}) -> Dictionary:
	if bank.is_empty() or words.is_empty():
		return {}
	return HeadPlan.make(timed(body, words), words, bank, SEED, targets, -1.0, feel)


## The names [param body] calls that [param bank] has no phrase for.
static func unknown(body: String, bank: Array) -> PackedStringArray:
	var names := {}
	for p in bank:
		names[String((p as Dictionary).get("name", ""))] = true
	var out := PackedStringArray()
	for m in read(body)["marks"]:
		var n := String((m as Dictionary)["words"]).strip_edges().to_lower()
		if not names.has(n) and not out.has(n):
			out.append(n)
	return out


## The voice's place for frames [param a] to [param b] at [param sr] a second (take frames: the take's seconds are the show's) from
## [param head_plan]: `(pan, near, muffle)` every [constant VoiceFX.PLACE_STEP] frames from [param a], reaching [param b] or past it,
## as [member VoiceFX.place] takes it.
static func lane(head_plan: Dictionary, a: int, b: int, sr: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	if head_plan.is_empty() or b <= a:
		return out
	var k := 0
	while true:
		var f := a + k * VoiceFX.PLACE_STEP
		out.append(HeadPlan.lane_at(head_plan, float(f) / float(sr)))
		if f >= b:
			break
		k += 1
	return out
