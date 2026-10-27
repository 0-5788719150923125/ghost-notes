extends SceneTree

## Does a letter hold together without a voice, an agent or a renderer: the hand, the format, the voice's
## rests and the desk's clock ([LetterHand], [LetterScript], [LetterMedium]; next/letter.md)?
##
## - THE HAND WRITES CURSIVE ([LetterHand]): a word is one stroke the pen never lifts from, its i's dotted
##   after it; NO LETTER IS LOST (the first look, 2026-10-26: "Dear Pen," came out "Dea Pe ," - a joined
##   stroke appended to a copy of a packed array) - a word's ink is at least its letters' written alone,
##   the control a word with one letter fewer; seeded, the same line is the same strokes and another hand's
##   differ, and a word's WIDTH is the font's whatever the hand, so the pages never move with the seed.
## - THE FORMAT ([method LetterScript.parse]): a paragraph is written and said, the first not indented and
##   the next indented, every line on a rule; a thought is said and never written; a strike crosses out
##   the paragraph last written and not the one before (the control); a picture's span is exactly its
##   passage; a sketch is drawn as the paragraph after it is said, and that paragraph is never written -
##   with no drawing yet (the control) there is no draw and still no writing; a point goes to the part of
##   the sketch it names, a point in a written paragraph is set aside and said so (the control: the pen
##   is writing then), and a point at the camera is a span; a tap is the desk's; a still runs from its
##   mark to the next written line; a new page turns one for an unspoken line; the voice reads every word
##   once, the voice's own marks kept and no other mark, and waits for the unspoken line at the end.
## - A PAGE TURNS MID-SENTENCE where the page runs out: the voice rests right before the first word of the
##   line the page turns for, inside its paragraph - the control, the same letter on a page it fits, rests
##   nowhere inside one. A SKETCH STAYS WITH WHAT IS SAID ABOUT IT (the first look: the cross and the dot
##   at a page's foot, the test and the point at it a page on): one pointed at two paragraphs later starts
##   a page, so the point finds it - the control, the same sketch pointed at by nothing, stays at the foot.
## - THE PEN TRAILS, AND THE VOICE WAITS ONLY PAST A LAG ([constant LetterScript.LAG_MOST]): a letter of
##   ordinary paragraphs asks for no rest but its page turns; one paragraph with far more ink than words
##   asks for what it owes past the lag (the control).
## - THE DESK'S CLOCK ([LetterMedium], no stage): a line is written while its words are said, the pen on
##   the paper; through a thought nothing is being written, the pen is up and the camera eased back; a tap
##   turns the pen over and brings its top down on its spot, by the line last written; a point at the
##   camera holds the pen up with its top clear of the pad (the first pose put it 2 cm into it), the camera
##   stood back; a picture is up over its passage and gone
##   before and after; a still frames the sketch with the camera's wander stopped, the pen off the pad;
##   and the letter is not over - no fade - while the unspoken line after the last word is being written.
##
##   godot --headless --path . --script tests/desk/letter_check.gd

const LETTER := """---
title: A Test Letter
author: Ink
---

Dear Friend,

I am writing this by hand, the way we used to, on the yellow pad you gave me.

I hope you are well.

<!-- strike -->

*She is always well.*

<!-- image (full): a quiet street at night, nobody on it -->

The street was empty when I came home. Nobody came, and nobody left.

<!-- /image -->

<!-- sketch: a cross and a dot on one line -->

A cross, and a dot.

Close one eye and look at the cross.

<!-- still -->

<!-- hesitation: 3 -->

It is still there.

<!-- point: sketch, the dot --> *That one is me.*

<!-- tap: desk -->

*Not that.*

<!-- point: camera --> *You are one of them.*

<!-- a note to myself -->

Yours,

<!-- new page -->

<!-- unspoken: Dear Friend, -->
"""

const DOT_SVG := "<svg viewBox=\"0 0 360 40\"><line x1=\"30\" y1=\"20\" x2=\"50\" y2=\"20\"/><circle id=\"the-dot\" cx=\"300\" cy=\"20\" r=\"4\" fill=\"black\"/></svg>"

var _fails: Array = []


func _init() -> void:
	_hand()
	_format()
	_turns()
	_lag()
	_clock()
	if _fails.is_empty():
		print("letter_check: ALL OK")
		quit(0)
	else:
		print("letter_check: %d FAILURE(S)" % _fails.size())
		for f in _fails:
			print("   ", f)
		quit(1)


func _check(ok: bool, msg: String) -> void:
	print(("   ok   " if ok else "   FAIL ") + msg)
	if not ok:
		_fails.append(msg)


static func _ink(strokes: Array) -> float:
	var t := 0.0
	for s in strokes:
		t += Ink._length((s as Dictionary)["points"])
	return t


func _hand() -> void:
	print("-- the hand")
	var word: Array = LetterHand.line(PackedStringArray(["minimum"]), [], 3, "a")["strokes"]
	var tiny := 0
	for s in word.slice(1):
		var lo := Vector2(INF, INF)
		var hi := -lo
		for p in (s as Dictionary)["points"]:
			lo = lo.min(p)
			hi = hi.max(p)
		if (hi - lo).length() < 3.0 * LetterHand.unit():
			tiny += 1
	_check(word.size() == 3 and tiny == 2, "\"minimum\" is one stroke, its two dots made after it (%d strokes)" % word.size())
	var whole := _ink(LetterHand.line(PackedStringArray(["Dear"]), [], 3, "b")["strokes"])
	var alone := 0.0
	for ch in "Dear":
		alone += _ink(LetterHand.line(PackedStringArray([ch]), [], 3, "c")["strokes"])
	var mm := _ink(LetterHand.line(PackedStringArray(["minimum"]), [], 3, "b")["strokes"])
	var mm_alone := 0.0
	for ch in "minimum":
		mm_alone += _ink(LetterHand.line(PackedStringArray([ch]), [], 3, "c")["strokes"])
	var short := _ink(LetterHand.line(PackedStringArray(["minimu"]), [], 3, "b")["strokes"])
	_check(whole >= alone * 0.97 and mm >= mm_alone * 0.97 and short < mm_alone * 0.9,
		"no letter is lost: \"Dear\" has the ink of its letters (%.0f of %.0f pt), \"minimum\" (%.0f of %.0f) - \"minimu\" less (%.0f)"
		% [whole, alone, mm, mm_alone, short])
	var a := LetterHand.line(PackedStringArray(["the", "pen"]), [], 3, "d")
	var b := LetterHand.line(PackedStringArray(["the", "pen"]), [], 3, "d")
	var c := LetterHand.line(PackedStringArray(["the", "pen"]), [], 4, "d")
	_check(a["strokes"][0]["points"] == b["strokes"][0]["points"] and a["strokes"][0]["points"] != c["strokes"][0]["points"]
		and is_equal_approx(float(a["width"]), float(c["width"])),
		"the same line is the same strokes, another hand's differ, and its width is the words' alone")
	_check(not LetterHand.line(PackedStringArray(["1974"]), [], 3, "e")["strokes"].is_empty(),
		"a year is written (its digits the roman's)")


## The actions of [param kind] in [param d].
static func _of(d: Dictionary, kind: String) -> Array:
	return (d["actions"] as Array).filter(func(x: Dictionary) -> bool: return String(x["kind"]) == kind)


static func _written(d: Dictionary) -> String:
	var out := PackedStringArray()
	for a in _of(d, "pad-text"):
		out.append(String(a["text"]))
	return " | ".join(out)


func _format() -> void:
	print("-- the format")
	var svgs := {Manuscript.image_key("a cross and a dot on one line"): DOT_SVG}
	var d := LetterScript.parse(LETTER, 3, svgs)
	var spoken: PackedStringArray = d["spoken"]
	var lines := _of(d, "pad-text")
	var written := _written(d)
	_check(String(lines[0]["text"]) == "Dear Friend," and is_equal_approx((lines[0]["at"] as Vector2).x, DeskScript.TEXT_X)
		and is_equal_approx((lines[1]["at"] as Vector2).x, DeskScript.TEXT_X + LetterScript.INDENT),
		"a paragraph is written: the first not indented, the next indented")
	var on_rules := true
	for l in lines:
		var y := (l["at"] as Vector2).y
		on_rules = on_rules and is_equal_approx(fposmod(y - DeskScript.FIRST_RULE, DeskScript.RULE), 0.0) \
			and y + LetterHand.descent_px() <= DeskScript.PH - DeskScript.FOOT
	_check(on_rules, "every line is on a rule, above the foot")
	_check(not written.contains("always well") and spoken.has("always"), "a thought is said and never written")
	var strikes := _of(d, "strike")
	_check(strikes.size() == 1 and String((d["actions"][int(strikes[0]["of"])] as Dictionary)["text"]) == "I hope you are well.",
		"a strike crosses out the paragraph last written, not the one before")
	var image: Dictionary = (d["spans"] as Array).filter(func(s: Dictionary) -> bool: return String(s["kind"]) == "image")[0]
	_check(spoken[int(image["from"])] == "the" and spoken[int(image["to"]) - 1] == "left",
		"a picture's span is exactly its passage")
	var draws := _of(d, "draw")
	_check(draws.size() == 1 and spoken[int(draws[0]["after"])] == "a" and int(draws[0]["span"]) == 5
		and not written.contains("A cross"), "a sketch is drawn as its paragraph is said, which is never written")
	var bare := LetterScript.parse(LETTER, 3)
	_check(_of(bare, "draw").is_empty() and not _written(bare).contains("A cross"),
		"with no drawing yet there is no draw, and its paragraph is still not written (the control)")
	var pts := _of(d, "point")
	_check(pts.size() == 1 and String(pts[0]["part"]) == "the-dot" and String((d["actions"][int(pts[0]["of"])] as Dictionary)["kind"]) == "draw"
		and spoken[int(pts[0]["after"])] == "that", "a point goes to the part of the sketch it names, at the word after it")
	var busy := LetterScript.parse("<!-- sketch: a cross and a dot on one line -->\n\nIt.\n\nWritten <!-- point: sketch --> here.\n", 3, svgs)
	_check(_of(busy, "point").is_empty() and (busy["ignored"] as PackedStringArray).size() == 1,
		"a point in a paragraph the pen writes is set aside, and said so (the control)")
	var cam := (d["spans"] as Array).filter(func(s: Dictionary) -> bool: return String(s["kind"]) == "camera")
	_check(cam.size() == 1 and spoken[int(cam[0]["after"])] == "you" and int(cam[0]["span"]) == 5,
		"a point at the camera is a span over its sentence")
	var taps := _of(d, "tap")
	_check(taps.size() == 1 and String(taps[0]["target"]) == "desk", "a tap is the desk's")
	var still: Dictionary = (d["spans"] as Array).filter(func(s: Dictionary) -> bool: return String(s["kind"]) == "still")[0]
	_check(spoken[int(still["from"]) - 1] == "cross" and spoken[int(still["to"])] == "it",
		"a still runs from its mark to the next written line")
	var last: Dictionary = lines.back()
	_check(String(last["text"]) == "Dear Friend," and bool(last["turn"]) and int(last["span"]) == 0
		and int(last["page"]) == int((lines[lines.size() - 2] as Dictionary)["page"]) + 1,
		"a new page turns one for the unspoken line")
	var said := String(d["speakable"])
	var clean := true
	for word in ["point", "sketch", "image", "a note to myself", "strike", "unspoken", "still", "tap"]:
		clean = clean and not said.contains("<!-- " + word)
	_check(said.count("Dear Friend,") == 1 and said.contains("<!-- hesitation: 3 -->") and clean,
		"the voice reads each word once, its own marks kept and no other")
	_check(said.strip_edges().ends_with("-->") and RegEx.create_from_string("action-hold: ([0-9.]+) -->$").search(said.strip_edges()) != null
		and float(RegEx.create_from_string("action-hold: ([0-9.]+) -->$").search(said.strip_edges()).get_string(1)) >= LetterScript.TURN_REST,
		"and waits at the end for the page to turn and the unspoken line to be written")


## A letter of [param n] paragraphs of plain words.
static func _filler(n: int, words := 60) -> String:
	var out := PackedStringArray()
	for i in n:
		var p := PackedStringArray()
		for w in words:
			p.append(["the", "letter", "was", "written", "slowly", "by", "lamplight"][(i + w) % 7])
		out.append(" ".join(p).capitalize().substr(0, 1) + " ".join(p).substr(1) + ".")
	return "\n\n".join(out) + "\n"


func _turns() -> void:
	print("-- a page turns mid-sentence")
	var long := LetterScript.parse(_filler(12))
	var turned: Array = _of(long, "pad-text").filter(func(a: Dictionary) -> bool: return bool(a["turn"]))
	var mid := turned.filter(func(a: Dictionary) -> bool: return int(a["after"]) % 60 != 0)
	var said := String(long["speakable"])
	var at := -1
	if not mid.is_empty():
		var first := String((mid[0] as Dictionary)["text"]).get_slice(" ", 0)
		var hold := "<!-- action-hold: %s --> " % String.num(LetterScript.TURN_REST, 2)
		at = said.find(hold + first)
	_check(not mid.is_empty() and at > 0 and not said.substr(at - 2, 2).contains("\n"),
		"the voice rests right before the first word of the line the page turns for, inside its paragraph")
	var short := LetterScript.parse(_filler(2))
	_check(not String(short["speakable"]).contains("action-hold"), "and on a page it fits, nowhere (the control)")
	# A SKETCH STAYS WITH WHAT IS SAID ABOUT IT: one near a page's foot, pointed at two paragraphs on
	var svgs := {Manuscript.image_key("a cross and a dot on one line"): DOT_SVG}
	var tail := "\n<!-- sketch: a cross and a dot on one line -->\n\nA cross, and a dot.\n\n" + _filler(2, 40)
	var pointed := LetterScript.parse(_filler(3) + tail + "\n<!-- point: sketch, the dot --> *That one.*\n", 3, svgs)
	var unpointed := LetterScript.parse(_filler(3) + tail, 3, svgs)
	var draw: Dictionary = _of(pointed, "draw")[0]
	var pt: Dictionary = _of(pointed, "point")[0]
	_check(bool(draw["turn"]) and int(pt["page"]) == int(draw["page"]),
		"a sketch pointed at later starts a page of its own, so the point finds it on the page")
	_check(not bool((_of(unpointed, "draw")[0] as Dictionary)["turn"]),
		"and with nothing pointing at it, it stays at the page's foot (the control)")


func _lag() -> void:
	print("-- the pen trails the voice")
	var calm := LetterScript.parse(_filler(3, 40))
	_check(not String(calm["speakable"]).contains("action-hold"), "ordinary paragraphs ask for no rest")
	var dense := LetterScript.parse("Incomprehensibilities, notwithstanding, counterrevolutionaries, institutionalization, "
		+ "uncharacteristically, disproportionately, overcompensating, interdisciplinary.\n\nNext.\n")
	var m := RegEx.create_from_string("action-hold: ([0-9.]+)").search(String(dense["speakable"]))
	_check(m != null and float(m.get_string(1)) > 1.0, "a paragraph of far more ink than words asks for what it owes past the lag (%s)"
		% (m.get_string(1) if m != null else "none"))


## A typeset record for [constant DOT_SVG], as the ink step hands one: a line, the dot, its anchor.
static func _dot_record(id: String) -> Dictionary:
	return {"id": id, "ok": true, "figure": true, "w": 208.0, "h": 15.0, "d": 0.0, "glyphs": [], "rules": [],
		"paths": [{"k": 0, "kind": "line", "pts": [[0.0, -7.5], [15.0, -7.5]]},
			{"k": 1, "kind": "dot", "pts": [[202.0, -7.5]]}],
		"anchors": {"the-dot": [199.0, -11.0, 205.0, -4.0]}}


func _clock() -> void:
	print("-- the desk's clock")
	var feed := ShowFeed.new()
	feed.outro_hold = 4.0
	var svgs := {Manuscript.image_key("a cross and a dot on one line"): DOT_SVG}
	var id := String(DeskScript.item("draw", DOT_SVG)["id"])
	var m := LetterMedium.new()
	m.feed = feed
	m._pad = LegalPad.new()
	m.load_letter(LETTER, {"seed": 3, "svgs": svgs, "ink": {"items": [_dot_record(id)]}})
	var records := {id: _dot_record(id)}
	var parsed := LetterScript.parse(LETTER, 3, svgs, LetterScript.lengths_of(records, 3), records)
	var words := DeskScript.rehearsal(parsed, 0.42, 0.35, 1.0)
	# the hesitation in the still, which a rehearsal does not time: five seconds before "It is still there."
	var still_to := -1
	for sp in parsed["spans"]:
		if String((sp as Dictionary)["kind"]) == "still":
			still_to = int(sp["to"])
	for i in range(still_to, words.size()):
		words[i]["t0"] = float(words[i]["t0"]) + 5.0
		words[i]["t1"] = float(words[i]["t1"]) + 5.0
	m._now = 0.0
	m.take_words(words)
	var spoken: PackedStringArray = parsed["spoken"]
	var at := func(word: String, from := 0) -> int:
		for i in range(from, spoken.size()):
			if spoken[i] == word:
				return i
		return -1
	var t0 := func(i: int) -> float: return float((words[i] as Dictionary)["t0"])
	# a line, written as it is said
	var li := -1
	for i in m._actions.size():
		if String((m._actions[i] as Dictionary).get("text", "")).begins_with("I am writing"):
			li = i
	var a: Dictionary = m._actions[li]
	m._now = (t0.call(int(a["after"])) + t0.call(int(a["after"]) + int(a["span"]) - 1)) * 0.5
	var u := m._written(li)
	_check(u > 0.1 and u < 0.95 and float(m.pen_at()["lift"]) <= DeskMedium.LIFT + 0.0001,
		"a line is written while its words are said (%.2f of it half way), the pen on the paper" % u)
	# a thought
	var th: int = at.call("always")
	m._now = t0.call(th) + 0.2
	var writing := false
	for i in m._actions.size():
		if String((m._actions[i] as Dictionary)["kind"]) == "pad-text":
			var w := m._written(i)
			writing = writing or (w > 0.0 and w < 1.0)
	_check(not writing and float(m.pen_at()["lift"]) > DeskMedium.LIFT and float(m._framing()["k"]) <= LetterMedium.THINK_K,
		"through a thought nothing is written, the pen is up and the camera eased back")
	# the tap: the top comes down on its spot
	var ti := -1
	for i in m._actions.size():
		if String((m._actions[i] as Dictionary)["kind"]) == "tap":
			ti = i
	var s := float(m._plan[ti]["start"])
	var e := float(m._plan[ti]["end"])
	var spot := m._world(m._actions[ti]["spot"], 0.0) + Vector3(0.0, LegalPad.DESK_Y, 0.0)
	var before_tap: Dictionary = {}
	for j in ti:
		if String((m._actions[j] as Dictionary)["kind"]) == "pad-text":
			before_tap = m._actions[j]
	_check(int(m._actions[ti]["page"]) == int(before_tap["page"]) and float((m._actions[ti]["spot"] as Vector2).y) > (before_tap["at"] as Vector2).y
		and float((m._actions[ti]["spot"] as Vector2).y) < (before_tap["at"] as Vector2).y + DeskScript.RULE * 2.0
		and float((m._actions[ti]["spot"] as Vector2).x) > DeskMedium.PW, "a tap on the desk is beside the pad, by the line last written")
	var closest := INF
	var full := true
	for k in 40:
		m._now = s + LetterMedium.TAP_FLIP + (e - s - 2.0 * LetterMedium.TAP_FLIP) * float(k) / 39.0
		var pose := m._tap_pose(Transform3D.IDENTITY)
		if pose.is_empty():
			full = false
			continue
		var xf: Transform3D = pose["xf"]
		full = full and float(pose["f"]) > 0.99
		closest = minf(closest, (xf.origin + xf.basis.y * LetterMedium.PEN_TOP).distance_to(spot))
	_check(e > s and full and closest < 0.002, "a tap turns the pen over and brings its top down on its spot (%.1f mm)" % (closest * 1000.0))
	m._now = s - 0.1
	_check(m._tap_pose(Transform3D.IDENTITY).is_empty(), "and before it the pen is the desk's own")
	# THE PAGE IS DRAWN THROUGH A TAP AND A POINT (the first look's render: every frame after the first tap
	# asked the tap for its ink by an `id` it did not have - a script error a frame, which this gate counts)
	var page_ok := true
	for when in [s + 0.5, float(m._plan[ti]["end"]) + 0.5]:
		m._now = when
		var st := m.page_state(int(m._actions[ti]["page"]))
		page_ok = page_ok and (st["all"] as Array).has(ti)
		m.page_ink(int(m._actions[ti]["page"]))
	_check(page_ok, "the page is drawn through a tap and after it, the tap on it and no ink of its own")
	# the point at the camera: the pen held up over the page, its body never into the pad
	var camspan: Dictionary = (parsed["spans"] as Array).filter(func(x: Dictionary) -> bool: return String(x["kind"]) == "camera")[0]
	m._now = (t0.call(int(camspan["after"])) + t0.call(int(camspan["after"]) + int(camspan["span"]) - 1)) * 0.5
	var held := m._camera_pose(Transform3D.IDENTITY)
	var hx: Transform3D = held.get("xf", Transform3D.IDENTITY)
	var top_y := (hx.origin + hx.basis.y * LetterMedium.PEN_TOP).y
	_check(not held.is_empty() and float(held["f"]) == 1.0 and hx.origin.y > 0.1 and top_y > 0.03
		and float(m._framing()["k"]) <= LetterMedium.CAMERA_K,
		"a point at the camera holds the pen up over the page, its top %.1f cm clear of the pad, the camera stood back" % (top_y * 100.0))
	# the picture
	var img := Image.create(4, 4, false, Image.FORMAT_RGB8)
	var key := Manuscript.image_key("a quiet street at night, nobody on it")
	m._pictures[key] = ImageTexture.create_from_image(img)
	var span: Dictionary = (parsed["spans"] as Array).filter(func(x: Dictionary) -> bool: return String(x["kind"]) == "image")[0]
	var pf := int(span["from"])
	var pl := int(span["to"]) - 1
	m._now = (t0.call(pf) + t0.call(pl)) * 0.5
	var mid := m.picture_at()
	m._now = t0.call(pf) - 2.0
	var before := m.picture_at()
	m._now = float((words[pl] as Dictionary)["t1"]) + 0.4 + LetterMedium.IMAGE_FADE + 0.1
	var after := m.picture_at()
	_check(String(mid["key"]) == key and float(mid["alpha"]) == 1.0 and float(before["alpha"]) == 0.0
		and float(after["alpha"]) == 0.0, "a picture is up over its passage, and gone before and after it")
	# the still
	var sf: int = at.call("cross", at.call("look"))
	m._now = float((words[sf] as Dictionary)["t1"]) + 2.6
	var f1: Dictionary = m._framing()
	var w1 := m._wander_time()
	m._now += 1.2
	m._framing()
	var w2 := m._wander_time()
	var box := m._last_drawn()
	_check(box.size.x > 0.0 and float(f1["k"]) == 1.0 and is_equal_approx(w1, w2)
		and (f1["line"] as Vector2).distance_to(box.get_center() - Vector2(0.0, 60.0)) < 1.0,
		"a still frames the sketch, the camera's wander stopped")
	_check(float((m.pen_at()["p"] as Vector2).x) > DeskMedium.PW, "and the pen is off the pad")
	# the end: not over while the unspoken line is written after the last word
	var last_t1 := float((words.back() as Dictionary)["t1"])
	m._now = last_t1 + 0.8
	_check(not m._ended() and m._end_fade() == 1.0, "the letter is not over while the line after the last word is being written")
	var done := 0.0
	for p in m._plan:
		done = maxf(done, float((p as Dictionary)["end"]))
	m._now = done + feed.outro_hold + 0.5
	_check(m._ended() and m._end_fade() == 0.0, "and is, once it is written and the outro has run")
	# A LIVE READING: words arriving a few at a time, the plan made again over what has begun - points, taps
	# and strikes among them (each asked what of it is written)
	var live := LetterMedium.new()
	live.feed = feed
	live._pad = LegalPad.new()
	live.load_letter(LETTER, {"seed": 3, "svgs": svgs, "ink": {"items": [_dot_record(id)]}})
	var n := 0
	while n < words.size():
		n = mini(n + 7, words.size())
		live._now = float((words[n - 1] as Dictionary)["t1"])
		live.take_words(words.slice(0, n))
		live.page_state(live._pages().x)
	_check(live._built_n == words.size(), "a live reading, its words a few at a time, is planned again over every kind of action")
	live._pad.free()
	live.free()
	m._pad.free()
	m.free()
	feed.free()
