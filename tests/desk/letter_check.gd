extends SceneTree

## Does a letter hold together without a voice, an agent or a renderer: the hand, the format, the voice's
## rests and the desk's clock ([LetterHand], [LetterScript], [LetterMedium]; next/letter.md)?
##
## - THE HAND IS THE JOURNAL'S, WRITTEN ([LetterHand], 2026-10-27): every hand has strokes for every letter,
##   digit and mark a letter uses, and a nib; an i's dot is made after its stem, above it; NO LETTER IS LOST
##   (the first look, 2026-10-26: "Dear Pen," came out "Dea Pe ," - a joined stroke appended to a copy of a
##   packed array) - a word's ink is at least its letters' written alone, the control a word with one
##   letter fewer; seeded, the same line is the same strokes and another seed's differ, and a word's WIDTH
##   is the font's whatever the seed, so the pages never move with it - but another hand's is its own.
## - THE FORMAT ([method LetterScript.parse]): a paragraph is written and said, NONE INDENTED and A RULE LEFT
##   EMPTY BETWEEN TWO (the user: "the hanging indents look wrong ... there should probably be a newline
##   between each paragraph") - the control, two lines of one paragraph a rule apart - every line on a
##   rule; a thought is said and never written; a strike crosses out the paragraph last written and not the
##   one before (the control), and THE WRITER DECIDES FIRST (the user: it "IMMEDIATELY scratches it out"):
##   the voice rests the pause and the strike, a bare mark's pause [constant LetterScript.DECIDE] and
##   `<!-- strike: 5 -->`'s five, a word there no number (the control); a picture's span is exactly its
##   passage; a sketch is drawn as the paragraph after it is said, and that paragraph is never written -
##   with no drawing yet (the control) there is no draw and still no writing; a point goes to the part of
##   the sketch it names, a point in a written paragraph is set aside and said so (the control: the pen
##   is writing then), and a point at the camera is a span; a tap is the desk's; a still runs from its
##   mark to the next written line; a new page turns one for an unspoken line; the voice reads every word
##   once, the voice's own marks kept and no other mark, and waits for the unspoken line at the end.
## - A PAGE TURNS MID-SENTENCE where the page runs out, AND THE VOICE READS ON THROUGH IT (the user, of "You do
##   not" and a rest for the turn before "remember agreeing to them": "just keep speaking there, and to force
##   the pen to catch up after the page turn"): no rest inside a paragraph a page turns in, where a turn between
##   two paragraphs is still rested for (the control); the line on the turned page begun once the voice has
##   read the page and the sheet is over, its first word said before it is written (the pen behind - the
##   measure's own control), and the next paragraph's first word on the page before it is said (caught up);
##   on a page it fits, no rest inside a paragraph of one sentence. A SKETCH STAYS WITH WHAT IS SAID ABOUT IT (the first look: the cross and the dot
##   at a page's foot, the test and the point at it a page on): one pointed at two paragraphs later starts
##   a page, so the point finds it - the control, the same sketch pointed at by nothing, stays at the foot.
## - THE PAGE LIES BLANK FIRST (the user: "the writing begins IMMEDIATELY after the intro disappears"): the
##   voice opens on a rest of [constant LetterScript.BLANK_PAGE], and nothing is written before it.
## - THE PEN WRITES TWO WORDS AHEAD ([LetterScript]; the user: "A person wants to read what is being said ...
##   maybe 2 words ahead of the speaking?"): ordinary sentences are not waited for, a sentence of far more ink
##   than its words is (the control); a paragraph after a thought is waited for its first words, one of more
##   ink longer (the control, one of less); its first line is marked to begin as the voice gets there; THE
##   WRITER HESITATES TOO (the user: "after "Dear Pen," - why was there no hesitation at all?") - a hesitation
##   on a line of its own or in a written line is a pause of the pen's, which takes up again just before the
##   voice goes on, where with none there it runs on two words ahead (the control).
## - THE CAMERA'S ARC ([method LetterMedium._arc]; the user: "The forward and backward zooming of the camera
##   is nauseating"): its two framings under twice as far apart; wide as the intro ends and coming in over
##   the blank page; close mid-page; let go before the page turns; and NOTHING ELSE MOVES IT IN OR OUT - a
##   thought, a point at a sketch and a tap leave it where the arc has it, where a point at the camera
##   stands it back (the control).
## - THE DESK'S CLOCK ([LetterMedium], no stage): a line begins as the voice begins the word two before its
##   first, no quicker than [constant LetterScript.QUICKEST] its ink's time, the pen on the paper; THE PEN IS AHEAD
##   OF THE VOICE - a paragraph's first word on the page before it is said, most words written before they are
##   said, none said long before - on a quicker voice too, where one far quicker than the pen can go leaves it
##   behind (the control); the first line begins as the blank page ends,
##   one after a thought once it is said, one a page turns for once the voice has read the page, one under a
##   picture as it is said (the desk's dictation); the intro clears [constant LetterScript.BLANK_PAGE] before
##   the first word; through a thought nothing is being written and the pen is up; a tap
##   turns the pen over and brings its top down on its spot, by the line last written; a point at the
##   camera holds the pen up with its top clear of the pad (the first pose put it 2 cm into it), the camera
##   stood back; a picture is up over its passage and gone before and after, and the voice goes on only
##   once it is gone; a strike begins the pause after both the line's last word and its ink, and is done
##   before the voice goes on; a still frames the sketch with the camera's wander stopped, the pen off the pad;
##   and the letter is not over - no fade - while the unspoken line after the last word is being written.
## - PICTURES DISSOLVE INTO ONE ANOTHER ([method LetterMedium.pictures_at]; the user: "blend from one picture into a
##   second one, or a third one, directly without ever seeing the page again ... each with different
##   panning/zooming behavior"): an image mark before the last one's close, or straight after it, comes up over
##   it - the voice reads on with no rest there, the one under held whole while the next comes in, so nothing of
##   the page shows from the run's first picture being up to its last going - where a picture after a written
##   line comes up from the desk, the voice resting for the page first (the control); the passage under a
##   dissolve is captioned; every fade is [constant LetterScript.IMAGE_FADE] ("A 2 or 3 second fade might look
##   better"); and no picture moves as the one before it did, nor drifts within a quarter turn of its way.
##
## - A DENSE SKETCH IS DASHED OFF ([method LetterScript.draw_pace]; the user, of the chapter's tree of dots: the text
##   "sort of gets frozen for a few seconds ... with the pen not moving" - the voice had waited 7.5 s for it): a
##   drawing of far more ink than its two words leave time for is done soon after them, the voice resting only that
##   long - the control, the desk's quickest pen, would have rested it several times as long - and the pen goes
##   from its last mark to the next line with no pause; one with room is drawn no quicker than before.
## - THE FRAME IS CHEAP (2026-10-27, the user: "performance can be really quite laggy in the realtime viewer"), each
##   held as a share of its control by this thread's own processor time ([WorkClock], the least of several runs - never
##   the machine's speed): a line written long ago is asked whether it is written for a small share of the line being
##   written (the elastic dictation word by word, every frame, for every line on the page); a plan made again as a live
##   reading's words arrive, the past kept, for a share of the same plan with nothing kept; a finished line's ink asked
##   again for a share of making it (a page's ink had been rebuilt point by point at every line's end).
##
##   godot --headless --path . --script tests/desk/letter_check.gd

const WorkClock := preload("res://tests/work_clock.gd")

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

## Four pictures: three in a run, the second closing the first by its own mark, the third after a close; the
## fourth after a line written on the page.
const PICTURES := """Dear Friend,

<!-- image (full): a harbor at dawn -->

The boats were going out, one by one, into the grey.

<!-- image (full): a field of wheat -->

The wheat stood still in the heat, and nobody walked in it.

<!-- /image -->

<!-- image (full): a road in the rain -->

The road ran on through the rain, and we ran with it.

<!-- /image -->

Yours, as ever.

<!-- image (full): a lamp in a window -->

A lamp was lit in the window.

<!-- /image -->
"""

const DOT_SVG := "<svg viewBox=\"0 0 360 40\"><line x1=\"30\" y1=\"20\" x2=\"50\" y2=\"20\"/><circle id=\"the-dot\" cx=\"300\" cy=\"20\" r=\"4\" fill=\"black\"/></svg>"

var _fails: Array = []


func _init() -> void:
	_hand()
	_format()
	_turns()
	_blank()
	_lag()
	_clock()
	_pictures()
	_dense_sketch()
	_frame_cost()
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


## The box [param pts] lie in.
static func _box(pts: PackedVector2Array) -> Rect2:
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	return r


func _hand() -> void:
	print("-- the hand")
	var lacking := PackedStringArray()
	for h in LetterHand.HANDS:
		if LetterHand.nib(h) <= 0.0 or LetterHand.ascent_px(h) <= 0.0:
			lacking.append("%s has no nib or no height" % h)
		for ch in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.,;:!?'\"-()&":
			var g := LetterHand._glyph(ch, h)
			if g.is_empty() or (g[2] as Array).is_empty():
				lacking.append("%s %s" % [h, ch])
	_check(lacking.is_empty(), "every hand has a nib and strokes for every letter, digit and mark %s" % ", ".join(lacking))
	var i_strokes: Array = LetterHand.line(PackedStringArray(["i"]), [], 3, "a")["strokes"]
	var stem := _box(i_strokes[0]["points"]) if i_strokes.size() == 2 else Rect2()
	var dot := _box(i_strokes[1]["points"]) if i_strokes.size() == 2 else Rect2()
	_check(i_strokes.size() == 2 and dot.end.y < stem.position.y and dot.size.length() < stem.size.length() * 0.5,
		"an i's dot is made after its stem, above it (%d strokes)" % i_strokes.size())
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
	var other := LetterHand.line(PackedStringArray(["the", "pen"]), [], 3, "d", "caveat")
	_check(a["strokes"][0]["points"] == b["strokes"][0]["points"] and a["strokes"][0]["points"] != c["strokes"][0]["points"]
		and is_equal_approx(float(a["width"]), float(c["width"])) and not is_equal_approx(float(a["width"]), float(other["width"])),
		"the same line is the same strokes, another seed's differ, its width the words' alone - and another hand's its own")
	_check(not LetterHand.line(PackedStringArray(["1974"]), [], 3, "e")["strokes"].is_empty(), "a year is written")


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
	var flush := true
	for l in lines:
		flush = flush and is_equal_approx((l["at"] as Vector2).x, DeskScript.TEXT_X)
	var y_of := func(i: int) -> float: return ((lines[i] as Dictionary)["at"] as Vector2).y
	_check(String(lines[0]["text"]) == "Dear Friend," and flush and bool(lines[1].get("para", false))
		and is_equal_approx(y_of.call(1) - y_of.call(0), DeskScript.RULE * 2.0),
		"a paragraph is written, none indented, a rule left empty above the next")
	_check(not bool(lines[2].get("para", false)) and is_equal_approx(y_of.call(2) - y_of.call(1), DeskScript.RULE),
		"and none between two lines of one paragraph (the control)")
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
	var rest_before := func(parsed: Dictionary, words: String) -> float:
		var said := String(parsed["speakable"])
		var m := RegEx.create_from_string("action-hold: ([0-9.]+) -->\\s*" + words).search(said)
		return float(m.get_string(1)) if m != null else 0.0
	var timed := LetterScript.parse(LETTER.replace("<!-- strike -->", "<!-- strike: 5 -->"), 3, svgs)
	var worded := LetterScript.parse(LETTER.replace("<!-- strike -->", "<!-- strike: soon -->"), 3, svgs)
	var thought := "\\*She is always"
	_check(float(strikes[0]["decide"]) == LetterScript.DECIDE
		and rest_before.call(d, thought) >= LetterScript.DECIDE + LetterScript.STRIKE - 0.01,
		"the writer decides first: the voice rests the pause and the strike (%.2f s)" % rest_before.call(d, thought))
	_check(float(_of(timed, "strike")[0]["decide"]) == 5.0 and rest_before.call(timed, thought) >= 5.0 + LetterScript.STRIKE - 0.01
		and float(_of(worded, "strike")[0]["decide"]) == LetterScript.DECIDE,
		"a strike's own number is its pause (%.2f s), a word there no number (the control)" % rest_before.call(timed, thought))
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
	# paragraphs a page does not hold a whole number of (at 60 words, three filled one exactly)
	var per := 50
	var long := LetterScript.parse(_filler(12, per))
	var turned: Array = _of(long, "pad-text").filter(func(a: Dictionary) -> bool: return bool(a["turn"]))
	var mid := turned.filter(func(a: Dictionary) -> bool: return int(a["after"]) % per != 0)
	var between := turned.filter(func(a: Dictionary) -> bool: return int(a["after"]) % per == 0)
	var said := _past_blank(String(long["speakable"]))
	var gated := not mid.is_empty()
	for a in mid:
		gated = gated and String((a as Dictionary).get("gate", "")) == "turn"
	var rest := 0.0
	if not between.is_empty():
		var m := RegEx.create_from_string("action-hold: ([0-9.]+) -->\\s*" + String((between[0] as Dictionary)["text"])).search(said)
		rest = float(m.get_string(1)) if m != null else 0.0
	_check(gated and RegEx.create_from_string("\\S <!-- action-hold").search(said) == null
		and rest >= LetterScript.TURN_REST - 0.01,
		"the voice reads on through a page turned inside a paragraph (%d), where it rests %.2f s for one turned between two (the control)"
		% [mid.size(), rest])
	# ...and the pen catches up after the turn
	var feed := ShowFeed.new()
	feed.outro_hold = 4.0
	feed.intro_hold = 1.0
	var md := LetterMedium.new()
	md.feed = feed
	md._pad = LegalPad.new()
	md.load_letter(_filler(12, per), {"seed": 1})
	var words := DeskScript.rehearsal(long, 0.42, 0.35, 1.0)
	md._now = 0.0
	md.take_words(words)
	var ti := -1
	var next_i := -1
	for i in md._actions.size():
		var a: Dictionary = md._actions[i]
		if String(a["kind"]) != "pad-text":
			continue
		if ti < 0 and bool(a.get("turn", false)) and int(a["after"]) % per != 0:
			ti = i
		elif ti >= 0 and next_i < 0 and int(a["after"]) % per == 0 and int(a.get("span", 0)) > 0:
			next_i = i
	var k0 := int(md._actions[ti]["after"])
	var kn := int(md._actions[next_i]["after"])
	var read := float((words[k0 - 1] as Dictionary)["t1"])
	var gap := float((words[k0] as Dictionary)["t0"]) - read
	var late := _written_at(md, ti, 0) - float((words[k0] as Dictionary)["t0"])
	var least := INF               # the next paragraph's first line: the least any word of it is on the page before it is said
	for j in int(md._actions[next_i]["span"]):
		least = minf(least, float((words[kn + j] as Dictionary)["t0"]) - _written_at(md, next_i, j))
	var waited := float((words[kn] as Dictionary)["t0"]) - float((words[kn - 1] as Dictionary)["t1"])
	_check(float(md._plan[ti]["start"]) >= read + LetterScript.TURN_REST - 0.05 and gap < 1.0 and late > 2.0
		and least > -0.15 and waited > 1.0,
		"the line on the turned page is begun once the page is read and turned, the voice going on (%.2f s), %.1f s behind it; caught up at the next paragraph, the voice waiting %.1f s there (its words at worst %.2f s late)"
		% [gap, late, waited, -least])
	md.free()
	var short := LetterScript.parse(_filler(2))
	_check(RegEx.create_from_string("\\S <!-- action-hold").search(_past_blank(String(short["speakable"]))) == null,
		"and on a page it fits, none inside a paragraph of one sentence (the control)")
	# A SKETCH STAYS WITH WHAT IS SAID ABOUT IT: one near a page's foot, pointed at two paragraphs on - the
	# words before it as many as leave it room at the foot, whatever the hand
	var svgs := {Manuscript.image_key("a cross and a dot on one line"): DOT_SVG}
	var tail := "\n<!-- sketch: a cross and a dot on one line -->\n\nA cross, and a dot.\n\n" + _filler(2, 40)
	var lead := ""
	var unpointed := {}
	for m in range(60, 0, -5):
		lead = _filler(2) + "\n" + _filler(1, m)
		unpointed = LetterScript.parse(lead + tail, 3, svgs)
		var at_foot: Dictionary = _of(unpointed, "draw")[0]
		if not bool(at_foot["turn"]):
			break
	var low: Dictionary = _of(unpointed, "draw")[0]
	var pointed := LetterScript.parse(lead + tail + "\n<!-- point: sketch, the dot --> *That one.*\n", 3, svgs)
	var draw: Dictionary = _of(pointed, "draw")[0]
	var pt: Dictionary = _of(pointed, "point")[0]
	_check(bool(draw["turn"]) and int(pt["page"]) == int(draw["page"]),
		"a sketch pointed at later starts a page of its own, so the point finds it on the page")
	_check(not bool(low["turn"]) and (low["at"] as Vector2).y > DeskScript.PH * 0.6,
		"and with nothing pointing at it, it stays at the page's foot (the control; %.0f px down)" % (low["at"] as Vector2).y)


## [param said] past the blank page's rest it opens on (none of a letter's own).
static func _past_blank(said: String) -> String:
	var m := RegEx.create_from_string("^<!-- action-hold: [0-9.]+ -->").search(said)
	return said.substr(m.get_end()) if m != null else said


func _blank() -> void:
	print("-- the blank page")
	var d := LetterScript.parse(LETTER, 3)
	var said := String(d["speakable"])
	var head := RegEx.create_from_string("^<!-- action-hold: ([0-9.]+) -->").search(said)
	_check(head != null and float(head.get_string(1)) >= LetterScript.BLANK_PAGE and said.count("<!-- action-hold") > 1,
		"the voice opens on the blank page's rest, and the pen's head start")
	var opening := LetterScript.parse("<!-- unspoken: Dear Friend, -->\n\nSaid.\n", 3)
	_check(String(opening["speakable"]).begins_with("<!-- action-hold: "), "and a letter opening on a line written, not said, too")


func _lag() -> void:
	print("-- the pen writes two words ahead")
	var inner_rest := RegEx.create_from_string("\\S <!-- action-hold")
	var plain := _past_blank(String(LetterScript.parse("One is here. Two is there. Three is last.\n")["speakable"]))
	var dense_mid := _past_blank(String(LetterScript.parse("It is here. Incomprehensibilities, notwithstanding, "
		+ "counterrevolutionaries, institutionalization, uncharacteristically.\n")["speakable"]))
	_check(inner_rest.search(plain) == null and inner_rest.search(dense_mid) != null,
		"ordinary sentences are not waited for, a sentence of far more ink than its words is (the control)")
	var hold_before := func(text: String, words: String) -> float:
		var m := RegEx.create_from_string("action-hold: ([0-9.]+) -->\\s*" + words).search(_past_blank(text))
		return float(m.get_string(1)) if m != null else 0.0
	var short: float = hold_before.call(String(LetterScript.parse("*Thought.*\n\nIt is a cat.\n")["speakable"]), "It")
	var dense: float = hold_before.call(String(LetterScript.parse("*Thought.*\n\nIncomprehensibilities, notwithstanding, "
		+ "counterrevolutionaries.\n")["speakable"]), "Incomprehensibilities")
	_check(short > 0.0 and dense > short + 0.5,
		"a paragraph after a thought is waited for its first words (%.2f s), one of more ink longer (%.2f s, the control)" % [short, dense])
	var gated := LetterScript.parse("*Thought.*\n\nIt is a cat.\n")
	var line: Dictionary = _of(gated, "pad-text")[0]
	_check(String(line.get("gate", "")) == "voice" and absf(float(line.get("gate_rest", -1.0)) - short) < 0.01,
		"and its first line is marked to begin as the voice gets there")
	# THE WRITER HESITATES TOO
	var own_line := LetterScript.parse("Dear Friend,\n\n<!-- hesitation -->\n\nIt is a fine day here, and I am well.\n")
	var inline := LetterScript.parse("In both worlds, <!-- hesitation --> I was expelled.\n")
	_check(Array(own_line["pauses"]) == [1] and Array(inline["pauses"]) == [2],
		"a hesitation on a line of its own, or in a written line, is a pause of the writer's (after %s and %s)" % [str(own_line["pauses"]), str(inline["pauses"])])
	var started := func(text: String) -> Array:
		var parsed_h := LetterScript.parse(text)
		var md := LetterMedium.new()
		md.feed = ShowFeed.new()
		md.feed.intro_hold = 1.0
		md._pad = LegalPad.new()
		md.load_letter(text, {"seed": 1})
		var heard := DeskScript.rehearsal(parsed_h, 0.42, 0.35, 1.0)
		# the voice's own pause after "Friend," (a rehearsal times no hesitation), in both
		for k in range(2, heard.size()):
			heard[k]["t0"] = float(heard[k]["t0"]) + 2.0
			heard[k]["t1"] = float(heard[k]["t1"]) + 2.0
		md._now = 0.0
		md.take_words(heard)
		var second := -1
		for i in md._actions.size():
			if String((md._actions[i] as Dictionary).get("text", "")).begins_with("It is"):
				second = i
		var got := [float(md._plan[second]["start"]), float((heard[int((md._actions[second] as Dictionary)["after"])] as Dictionary)["t0"])]
		md.free()
		return got
	var stopped: Array = started.call("Dear Friend,\n\n<!-- hesitation -->\n\nIt is a fine day here, and I am well.\n")
	var ran_on: Array = started.call("Dear Friend,\n\nIt is a fine day here, and I am well.\n")
	_check(float(stopped[0]) >= float(stopped[1]) - LetterMedium.RESUME_LEAD - 0.01 and float(ran_on[0]) < float(ran_on[1]) - LetterMedium.RESUME_LEAD - 1.0,
		"the pen stops through a hesitation and takes up again %.1f s before the voice goes on, where with none it runs on through the pause (%.1f s ahead, the control)"
		% [float(stopped[1]) - float(stopped[0]), float(ran_on[1]) - float(ran_on[0])])


## THE PEN'S LEAD ON THE VOICE in [param m], heard as [param words] (by spoken index): `{first, worst, behind,
## n}` - the least a paragraph's first word is on the page before it is said, the most any word is said before
## it is written, and how many of the n words written ahead are said first. A word is written when the line's
## ink reaches its end ([method LetterMedium._share]).
static func _read_along(m: LetterMedium, words: Array) -> Dictionary:
	var first := INF
	var worst := -INF
	var behind := 0
	var n := 0
	for i in m._actions.size():
		var a: Dictionary = m._actions[i]
		if String(a["kind"]) != "pad-text" or int(a.get("span", 0)) == 0 or m._pictured(a):
			continue
		for j in int(a["span"]):
			var lag := _written_at(m, i, j) - float((words[int(a["after"]) + j] as Dictionary)["t0"])
			worst = maxf(worst, lag)
			n += 1
			if lag > 0.0:
				behind += 1
			if j == 0 and bool(a.get("para", false)):
				first = minf(first, -lag)
	return {"first": first, "worst": worst, "behind": behind, "n": n}


## When the [param j]th spoken word of line [param i] of [param m] is on the page: when the line's ink reaches its end.
static func _written_at(m: LetterMedium, i: int, j: int) -> float:
	var ends: PackedFloat32Array = (m._actions[i] as Dictionary)["ends"]
	var write := float((m._actions[i] as Dictionary)["write"])
	var lo := float(m._plan[i]["start"])
	var hi := float(m._plan[i]["end"])
	for _it in 24:
		var mid := (lo + hi) * 0.5
		if m._share(i, mid) * write >= ends[j]:
			hi = mid
		else:
			lo = mid
	return hi


## A typeset record for [constant DOT_SVG], as the ink step hands one: a line, the dot, its anchor.
## A sketch's record of [param n] short strokes in a row, as the ink step hands one: a dense drawing.
static func _dense_record(id: String, n: int) -> Dictionary:
	var paths: Array = []
	for k in n:
		var x := 4.0 * float(k)
		paths.append({"k": k, "kind": "line", "pts": [[x, -14.0], [x + 2.0, 0.0]]})
	return {"id": id, "ok": true, "figure": true, "w": 4.0 * float(n), "h": 15.0, "d": 0.0, "glyphs": [], "rules": [],
		"paths": paths, "anchors": {}}


static func _dot_record(id: String) -> Dictionary:
	return {"id": id, "ok": true, "figure": true, "w": 208.0, "h": 15.0, "d": 0.0, "glyphs": [], "rules": [],
		"paths": [{"k": 0, "kind": "line", "pts": [[0.0, -7.5], [15.0, -7.5]]},
			{"k": 1, "kind": "dot", "pts": [[202.0, -7.5]]}],
		"anchors": {"the-dot": [199.0, -11.0, 205.0, -4.0]}}


func _clock() -> void:
	print("-- the desk's clock")
	var feed := ShowFeed.new()
	feed.outro_hold = 4.0
	feed.intro_hold = 1.0           # where the rehearsal's voice begins
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
	# a line, written ahead
	var li := -1
	for i in m._actions.size():
		if String((m._actions[i] as Dictionary).get("text", "")).begins_with("I am writing"):
			li = i
	var a: Dictionary = m._actions[li]
	var ls := float(m._plan[li]["start"])
	var two_back := float((words[int(a["after"]) - LetterScript.AHEAD_WORDS] as Dictionary)["t0"])
	m._now = (ls + float(m._plan[li]["end"])) * 0.5
	var pen_free := float(m._plan[li - 1]["end"]) + m._way(li - 1, li)
	_check(absf(ls - maxf(two_back, pen_free)) < 0.05 and m._written(li) > 0.1 and m._written(li) < 0.9
		and float(m.pen_at()["lift"]) <= DeskMedium.LIFT + 0.0001,
		"a line begins as the voice begins the word %d before its first, or as the pen is free, the pen on the paper" % LetterScript.AHEAD_WORDS)
	var paced := true
	for i in m._actions.size():
		var pa: Dictionary = m._actions[i]
		if String(pa["kind"]) == "pad-text" and int(pa.get("span", 0)) > 0 and not m._pictured(pa):
			var took := float(m._plan[i]["end"]) - float(m._plan[i]["start"])
			paced = paced and took >= float(pa["write"]) / LetterScript.QUICKEST - 0.01
	_check(paced, "no line is written quicker than %.1f times its ink's own time" % LetterScript.QUICKEST)
	# THE PEN IS AHEAD OF THE VOICE
	var along := _read_along(m, words)
	var read_by := func(per: float) -> Dictionary:
		var md := LetterMedium.new()
		md.feed = feed
		md._pad = LegalPad.new()
		md.load_letter(LETTER, {"seed": 3, "svgs": svgs, "ink": {"items": [_dot_record(id)]}})
		var heard := DeskScript.rehearsal(parsed, per, 0.2, 1.0)
		md._now = 0.0
		md.take_words(heard)
		var got := _read_along(md, heard)
		md.free()
		return got
	var quicker: Dictionary = read_by.call(0.34)
	var behind: Dictionary = read_by.call(0.12)
	_check(float(along["first"]) > 0.05 and int(along["behind"]) * 2 < int(along["n"])
		and float(along["worst"]) <= LetterScript.OVERTAKE + 1.0,
		"the pen is ahead of the voice: a paragraph's first word on the page %.1f s before it is said at the least, %d of %d words said first, none %.1f s after"
		% [float(along["first"]), int(along["behind"]), int(along["n"]), float(along["worst"])])
	_check(int(quicker["behind"]) * 2 < int(quicker["n"]) and float(quicker["worst"]) <= LetterScript.OVERTAKE + 1.0,
		"and on a quicker voice too (%d of %d said first, none %.1f s after)" % [int(quicker["behind"]), int(quicker["n"]), float(quicker["worst"])])
	_check(float(behind["worst"]) > LetterScript.OVERTAKE + 1.0,
		"where a voice far quicker than the pen can go leaves it %.1f s behind (the control)" % float(behind["worst"]))
	# where the pen waits for the voice
	var first_line: Dictionary = m._actions[0]
	var yours := -1
	for i in m._actions.size():
		if String((m._actions[i] as Dictionary).get("text", "")) == "Yours,":
			yours = i
	var them: int = at.call("them")
	var street := -1
	for i in m._actions.size():
		if String((m._actions[i] as Dictionary).get("text", "")).begins_with("The street"):
			street = i
	_check(absf(float(m._plan[0]["start"]) - (feed.intro_hold + LetterScript.BLANK_PAGE)) < 0.05 and String(first_line["text"]) == "Dear Friend,"
		and float(m._plan[yours]["start"]) >= float((words[them] as Dictionary)["t1"]) - 0.05
		and absf(float(m._plan[street]["start"]) - (t0.call(int((m._actions[street] as Dictionary)["after"])) - DeskMedium.PEN_LEAD)) < 0.05,
		"the first line begins as the blank page ends, one after a thought once it is said, one under a picture as it is said")
	_check(absf(m._opening() - (float(m._plan[0]["start"]) - LetterScript.BLANK_PAGE)) < 0.05,
		"the intro clears the blank page's rest before the pen first touches the page")
	# a thought
	var th: int = at.call("always")
	m._now = t0.call(th) + 0.2
	var writing := false
	for i in m._actions.size():
		if String((m._actions[i] as Dictionary)["kind"]) == "pad-text":
			var w := m._written(i)
			writing = writing or (w > 0.0 and w < 1.0)
	_check(not writing and float(m.pen_at()["lift"]) > DeskMedium.LIFT,
		"through a thought nothing is written and the pen is up")
	_check(is_equal_approx(float(m._framing()["k"]), m._arc()), "and the camera neither stands back nor comes in")
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
	# THE CAMERA'S ARC
	var ratio := float(LetterMedium.LETTER_WIDE["dist"]) / float(LetterMedium.LETTER_LOCAL["dist"])
	m._now = feed.intro_hold
	var k_open := m._arc()
	m._now = t0.call(0)
	var k_first := m._arc()
	m._now = feed.intro_hold + LetterMedium.ARRIVE + LetterMedium.ARC_IN + 1.0
	var k_mid := m._arc()
	_check(ratio < 2.0 and k_open == 0.0 and k_first > 0.0 and k_first < 0.6 and k_mid == 1.0,
		"the camera's framings are %.2f times apart; wide as the intro ends, coming in over the blank page (%.2f at the first word), close mid-page"
		% [ratio, k_first])
	var turn_i := -1
	for i in m._actions.size():
		if bool((m._actions[i] as Dictionary).get("turn", false)):
			turn_i = i
	var ta := float(m._plan[turn_i]["turn_at"])
	m._now = ta - LetterMedium.OUT_BEFORE - LetterMedium.ARC_OUT - 0.5
	var k_before := m._arc()
	m._now = ta - LetterMedium.OUT_BEFORE + 0.01
	var k_let_go := m._arc()
	_check(ta < INF and k_before == 1.0 and k_let_go == 0.0, "and lets go before the page turns, done %.0f s ahead of it" % LetterMedium.OUT_BEFORE)
	# nothing else moves it in or out: on the same letter with a long paragraph after its point at the
	# camera, so its turn is well past the points and the tap, which here all fall where the arc lets go -
	# and one between the tap and the point at the camera, which here comes up within the tap
	var long := LETTER.replace("*Not that.*", "*Not that.*\n\n" + _filler(1, 30)).replace("<!-- a note to myself -->",
		_filler(1, 120))
	var m2 := LetterMedium.new()
	m2.feed = feed
	m2._pad = LegalPad.new()
	m2.load_letter(long, {"seed": 3, "svgs": svgs, "ink": {"items": [_dot_record(id)]}})
	var parsed2 := LetterScript.parse(long, 3, svgs, LetterScript.lengths_of(records, 3), records)
	var words2 := DeskScript.rehearsal(parsed2, 0.42, 0.35, 1.0)
	m2._now = 0.0
	m2.take_words(words2)
	var steady := true
	var seen := PackedStringArray()
	for i in m2._actions.size():
		var kind := String((m2._actions[i] as Dictionary)["kind"])
		if kind in ["point", "tap"]:
			m2._now = float(m2._plan[i]["start"]) + 0.2
			steady = steady and m2._arc() == 1.0 and is_equal_approx(float(m2._framing()["k"]), 1.0)
			seen.append(kind)
	var cam2: Dictionary = (parsed2["spans"] as Array).filter(func(x: Dictionary) -> bool: return String(x["kind"]) == "camera")[0]
	m2._now = (float((words2[int(cam2["after"])] as Dictionary)["t0"]) + float((words2[int(cam2["after"]) + int(cam2["span"]) - 1] as Dictionary)["t0"])) * 0.5
	_check(steady and seen.size() == 2 and m2._arc() == 1.0 and float(m2._framing()["k"]) < 1.0,
		"a point at a sketch and a tap leave the camera close, where a point at the camera stands it back (the control)")
	var turned := 0
	var read_first := true
	for i in m2._actions.size():
		var tl: Dictionary = m2._actions[i]
		if String(tl["kind"]) == "pad-text" and bool(tl.get("turn", false)) and int(tl.get("span", 0)) > 0 and not m2._pictured(tl):
			turned += 1
			var read := float((words2[int(tl["after"]) - 1] as Dictionary)["t1"])
			read_first = read_first and float(m2._plan[i]["turn_at"]) >= read - 0.05
	_check(turned > 0 and read_first, "a page is turned for a line written ahead only once the voice has read it (%d turns)" % turned)
	m2.free()
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
	m._now = float((words[pl] as Dictionary)["t1"]) + LetterScript.IMAGE_AFTER + LetterMedium.IMAGE_FADE + 0.05
	var after := m.picture_at()
	_check(String(mid["key"]) == key and float(mid["alpha"]) == 1.0 and float(before["alpha"]) == 0.0
		and float(after["alpha"]) == 0.0, "a picture is up over its passage, and gone before and after it")
	m._now = t0.call(pl + 1)
	_check(float(m.picture_at()["alpha"]) == 0.0, "and the voice goes on only once it is gone")
	# THE SUBTITLES CAPTION ONLY WHAT CANNOT BE READ ON THE PAGE
	var line_of := func(text: String) -> Dictionary:
		for x in m._actions:
			if String((x as Dictionary).get("text", "")).begins_with(text):
				return x
		return {}
	var written: Dictionary = line_of.call("I am writing")
	var w_lo := int(written["after"])
	var w_hi := w_lo + int(written["span"]) - 1
	var thought_w: int = at.call("always")
	var drawn_w: int = at.call("cross")
	m._now = 0.5
	var on_page := m._captioned(w_lo, w_hi, m._now)
	var thought_cap := m._captioned(thought_w, thought_w, m._now)
	var drawn_cap := m._captioned(drawn_w, drawn_w, m._now)
	m._now = (t0.call(pf) + t0.call(pl)) * 0.5
	var under := m._captioned(pf, pl, m._now)
	m._pictures.erase(key)
	var unpainted := m._captioned(pf, pl, m._now)
	m._pictures[key] = ImageTexture.create_from_image(img)
	_check(not on_page and thought_cap and drawn_cap,
		"a line the pen writes is not captioned, a thought and a sketch's narration are (the control)")
	_check(under and not unpainted,
		"the passage under a picture is captioned while the picture covers the screen, and not with no picture painted (the control)")

	# the strike: decided on, then made, before the voice goes on
	var si := -1
	for i in m._actions.size():
		if String((m._actions[i] as Dictionary)["kind"]) == "strike":
			si = i
	var of := int(m._actions[si]["of"])
	var said_end := float((words[int(m._actions[si]["after"]) - 1] as Dictionary)["t1"])
	var free := maxf(float(m._plan[of]["end"]), said_end)
	var waited := float(m._plan[si]["start"]) - free
	_check(waited >= LetterScript.DECIDE - 0.01 and waited < LetterScript.DECIDE + 1.0
		and float(m._plan[si]["end"]) <= t0.call(int(m._actions[si]["after"])) + 0.05,
		"a strike begins %.2f s after the line's last word and ink, and is done before the voice goes on" % waited)
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


func _pictures() -> void:
	print("-- pictures dissolving")
	var d := LetterScript.parse(PICTURES, 3)
	var pics: Array = (d["spans"] as Array).filter(func(x: Dictionary) -> bool: return String(x["kind"]) == "image")
	var blends: Array = pics.map(func(x: Dictionary) -> bool: return bool(x.get("blend", false)))
	var spoken: PackedStringArray = d["spoken"]
	var adjacent := int(pics[0]["to"]) == int(pics[1]["from"]) and int(pics[1]["to"]) == int(pics[2]["from"])
	_check(blends == [false, true, true, false] and adjacent and spoken[int(pics[3]["from"])] == "a",
		"a picture's mark before the last one's close, or straight after it, comes up over it; one after a written line does not (the control)")
	var said := String(d["speakable"])
	var rest_before := func(words: String) -> float:
		var m := RegEx.create_from_string("action-hold: ([0-9.]+) -->\\s*" + words).search(said)
		return float(m.get_string(1)) if m != null else 0.0
	_check(rest_before.call("The wheat") == 0.0 and rest_before.call("The road") == 0.0
		and rest_before.call("Yours") >= LetterScript.IMAGE_AFTER + LetterScript.IMAGE_FADE - 0.01,
		"the voice reads on into a dissolve, and rests for the page to come back after a run (the control: %.2f s)"
		% rest_before.call("Yours"))
	var feed := ShowFeed.new()
	feed.outro_hold = 4.0
	feed.intro_hold = 1.0
	var m := LetterMedium.new()
	m.feed = feed
	m._pad = LegalPad.new()
	m.load_letter(PICTURES, {"seed": 3})
	var words := DeskScript.rehearsal(d, 0.42, 0.35, 1.0)
	m._now = 0.0
	m.take_words(words)
	var img := Image.create(4, 4, false, Image.FORMAT_RGB8)
	for p in pics:
		m._pictures[String(p["key"])] = ImageTexture.create_from_image(img)
	var t_end := func(i: int) -> float: return float((words[i] as Dictionary)["t1"])
	# the first dissolve, half way: the harbor whole under the wheat coming in
	var into: float = t_end.call(int(pics[0]["to"]) - 1) + LetterScript.IMAGE_AFTER
	m._now = into + LetterScript.IMAGE_FADE * 0.5
	var mid := m.pictures_at()
	_check(mid.size() == 2 and String(mid[0]["key"]) == String(pics[0]["key"]) and float(mid[0]["alpha"]) == 1.0
		and String(mid[1]["key"]) == String(pics[1]["key"]) and float(mid[1]["alpha"]) > 0.2 and float(mid[1]["alpha"]) < 0.8
		and m._captioned(int(pics[1]["from"]), int(pics[1]["from"]), m._now),
		"half way into a dissolve the picture before is whole under the next coming in, and what is said is captioned")
	m._now = into + LetterScript.IMAGE_FADE + 0.05
	var past := m.pictures_at()
	_check(past.size() == 1 and String(past[0]["key"]) == String(pics[1]["key"]), "and once it is in, it is alone")
	# nothing of the page from the run's first picture up to its last gone; the page back between the run and the lamp
	var first_up: float = t_end.call(int(pics[0]["from"]) - 1) + LetterScript.IMAGE_AFTER + LetterScript.IMAGE_FADE
	var last_out: float = t_end.call(int(pics[2]["to"]) - 1) + LetterScript.IMAGE_AFTER
	var least := 1.0
	var t := first_up
	while t <= last_out:
		m._now = t
		least = minf(least, LetterMedium.cover_of(m.pictures_at()))
		t += 0.05
	var gap := INF
	t = last_out
	while t < t_end.call(int(pics[3]["from"])):
		m._now = t
		gap = minf(gap, LetterMedium.cover_of(m.pictures_at()))
		t += 0.05
	_check(least > 0.999 and gap == 0.0,
		"nothing of the page shows through a run of three pictures (at least %.4f covered), where it comes back before one after a written line (the control)" % least)
	# a fade is the slow one asked for
	m._now = t_end.call(int(pics[2]["to"]) - 1) + LetterScript.IMAGE_AFTER + 1.2
	var slow := float(m.picture_at()["alpha"])
	_check(LetterScript.IMAGE_FADE >= 2.0 and LetterScript.IMAGE_FADE <= 3.0 and slow > 0.2,
		"every fade takes %.1f s: 1.2 s after a picture begins to go it is still at %.2f" % [LetterScript.IMAGE_FADE, slow])
	# each picture moves its own way
	var unlike := true
	var kinds := {}
	for sd in range(40):
		var mv := LetterMedium.moves_of(d["spans"], sd).filter(func(x: Dictionary) -> bool: return not x.is_empty())
		for i in mv.size():
			kinds[String(mv[i]["kind"])] = true
			if i > 0:
				unlike = unlike and String(mv[i]["kind"]) != String(mv[i - 1]["kind"]) \
					and absf((mv[i]["way"] as Vector2).angle_to(mv[i - 1]["way"])) >= PI * 0.5 - 0.001
	var same := LetterMedium.moves_of(d["spans"], 3) == LetterMedium.moves_of(d["spans"], 3)
	_check(unlike and kinds.size() == LetterMedium.MOVES.size() and same,
		"no picture moves as the one before it, nor drifts within a quarter turn of its way; every move is taken; a seed is the same moves")
	m._now = t_end.call(int(pics[1]["from"])) + 0.5
	var early: Dictionary = m.picture_at()
	m._now = t_end.call(int(pics[1]["to"]) - 1)
	var late: Dictionary = m.picture_at()
	var mv1: Dictionary = (m._spans.filter(func(x: Dictionary) -> bool: return String(x["kind"]) == "image")[1] as Dictionary)["move"]
	var sense := signf((mv1["grow"] as Vector2).y - (mv1["grow"] as Vector2).x)
	_check(String(early["key"]) == String(pics[1]["key"]) and String(late["key"]) == String(pics[1]["key"])
		and (signf(float(late["grow"]) - float(early["grow"])) == sense or (sense == 0.0 and is_equal_approx(float(late["grow"]), float(early["grow"]))))
		and (late["drift"] as Vector2) != (early["drift"] as Vector2),
		"a picture moves along its own move while it is up (%s)" % String(mv1["kind"]))
	m.free()


func _frame_cost() -> void:
	print("-- the frame is cheap")
	var feed := ShowFeed.new()
	feed.intro_hold = 1.0
	var m := LetterMedium.new()
	m.feed = feed
	m._pad = LegalPad.new()
	var text := _filler(24, 40)
	m.load_letter(text, {"seed": 3})
	var parsed := LetterScript.parse(text, 3)
	var words := DeskScript.rehearsal(parsed, 0.42, 0.35, 1.0)
	m.take_words(words)
	var lines: Array = []
	for i in m._actions.size():
		if String((m._actions[i] as Dictionary)["kind"]) == "pad-text" and int((m._actions[i] as Dictionary).get("span", 0)) > 4:
			lines.append(i)
	var old: int = lines[2]
	var now: int = lines[lines.size() / 2]
	var s0 := float(m._plan[now]["start"])
	var s1 := float(m._plan[now]["end"])
	# a different moment each ask, inside the line being written, so nothing kept for a moment answers it
	var ask := func(i: int) -> void:
		for k in 200:
			m._now = s0 + (s1 - s0) * (0.1 + 0.8 * float(k) / 200.0)
			m._written(i)
	var done_ms := WorkClock.cost_ms(func() -> void: ask.call(old))
	var writing_ms := WorkClock.cost_ms(func() -> void: ask.call(now))
	_check(writing_ms > 0.0 and done_ms < writing_ms * 0.25,
		"a line written long ago is asked whether it is written 200 times for %.2f ms; the line being written, %.2f (the control)"
		% [done_ms, writing_ms])
	# a plan made again, the voice past most of it, against the same plan with nothing kept
	m._now = float((words[words.size() * 3 / 4] as Dictionary)["t0"])
	var kept_ms := WorkClock.cost_ms(func() -> void:
		for k in 5:
			m._hold_past()
			m._build_plan())
	var whole_ms := WorkClock.cost_ms(func() -> void:
		for k in 5:
			m._held = {}
			m._build_plan())
	_check(whole_ms > 0.0 and kept_ms < whole_ms * 0.5,
		"a plan made again three quarters through, the past kept, takes %.1f ms five times; with nothing kept, %.1f (the control)" % [kept_ms, whole_ms])
	# a finished line's ink: made once
	m._now = float(m._plan[old]["end"]) + 1.0
	var made_ms := WorkClock.cost_ms(func() -> void:
		for k in 20:
			m._done_ink = {}
			m._done_ink_of(old))
	var again_ms := WorkClock.cost_ms(func() -> void:
		for k in 20:
			m._done_ink_of(old))
	_check(made_ms > 0.0 and again_ms < made_ms * 0.25,
		"a finished line's ink asked again 20 times takes %.2f ms; made each time, %.2f (the control)" % [again_ms, made_ms])
	m.free()


func _dense_sketch() -> void:
	print("-- a dense sketch is dashed off")
	var svg := "<svg viewBox=\"0 0 360 40\"><line x1=\"0\" y1=\"0\" x2=\"9\" y2=\"9\"/></svg>"
	var key := Manuscript.image_key("a row of strokes")
	var id := String(DeskScript.item("draw", svg)["id"])
	var text := "Dear Friend,\n\n<!-- sketch: a row of strokes -->\n\nOne, two.\n\nAnd that was all of them, in the end.\n"
	var records := {id: _dense_record(id, 80)}
	var lengths := LetterScript.lengths_of(records, 3)
	var ink := float(lengths[id])
	var parsed := LetterScript.parse(text, 3, {key: svg}, lengths, records)
	var said := String(parsed["speakable"])
	var m := RegEx.create_from_string("action-hold: ([0-9.]+) -->\\s*And that").search(said)
	var rest := float(m.get_string(1)) if m != null else 0.0
	var words := 2.0 * LetterScript.READ_WORD
	# the rest is the drawing's time past its words (and the next line's head start): what the quicker pace saves
	var quickest_rest := ink / DeskScript.MAX_PACE - words
	var saves := ink * (1.0 / DeskScript.MAX_PACE - 1.0 / LetterScript.DRAW_QUICKEST)
	_check(ink / DeskScript.MAX_PACE > words + 4.0 and quickest_rest - rest > saves * 0.5
		and rest > ink / LetterScript.DRAW_QUICKEST - words - 1.0,
		"a sketch of %.0f s of ink under two words: the voice rests %.1f s after them; at the desk's quickest, %.1f (the control)"
		% [ink, rest, quickest_rest])
	_check(is_equal_approx(LetterScript.draw_pace(2.0, 6.0), DeskScript.MAX_PACE)
		and is_equal_approx(LetterScript.draw_pace(ink, words), LetterScript.DRAW_QUICKEST),
		"a sketch with room is drawn at the desk's quickest at most, as before; the dense one at %.0f times the hand's pace (the control)"
		% LetterScript.DRAW_QUICKEST)
	# at the desk: done soon after its words, and the pen straight on to the next line
	var feed := ShowFeed.new()
	feed.intro_hold = 1.0
	var md := LetterMedium.new()
	md.feed = feed
	md._pad = LegalPad.new()
	md.load_letter(text, {"seed": 3, "svgs": {key: svg}, "ink": {"items": [_dense_record(id, 80)]}})
	var heard := DeskScript.rehearsal(parsed, 0.42, 0.35, 1.0)
	md.take_words(heard)
	var di := -1
	var ni := -1
	for i in md._actions.size():
		var a: Dictionary = md._actions[i]
		if String(a["kind"]) == "draw":
			di = i
		elif di >= 0 and ni < 0 and String(a["kind"]) == "pad-text":
			ni = i
	var narrated := float((heard[int(md._actions[di]["after"]) + int(md._actions[di]["span"]) - 1] as Dictionary)["t1"])
	var begun := float(md._plan[di]["start"])
	var done := float(md._plan[di]["end"])
	var gap := float(md._plan[ni]["start"]) - done
	_check(done < maxf(narrated + LetterScript.DRAW_TAIL, begun + ink / LetterScript.DRAW_QUICKEST) + 0.6
		and begun + ink / DeskScript.MAX_PACE > done + 1.5 and gap < 1.0,
		"at the desk it is drawn in %.1f s (at the desk's quickest, %.1f - the control), the pen on the next line %.2f s after its last mark"
		% [done - begun, ink / DeskScript.MAX_PACE, gap])
	md.free()

