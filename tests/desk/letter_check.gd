extends SceneTree

## Does a letter hold together without a voice, an agent or a renderer: the hand, the format, the voice's rests and the
## desk's clock ([Handwriting], [LetterScript], [LetterMedium]; next/letter.md)? Each item names its control, which must
## fail the assertion.
##
## - Hand: strokes for every letter, digit and mark; an i's dot after its stem; no letter lost (control: a word with one
##   letter fewer); seeded strokes, but a word's width is the font's whatever the seed; another hand's width is its own.
## - Format ([method LetterScript.parse]): paragraphs written and said, none indented, a rule left empty between two
##   (control: two lines of one paragraph a rule apart); a thought is said and never written; a strike crosses out the
##   paragraph last written (control: not the one before) after the writer's pause ([constant LetterScript.DECIDE], or the
##   mark's number; control: a word there no number); a picture's span is exactly its passage; a sketch is drawn where its
##   mark is, the voice waiting it out, a rule left empty under it (control: the first rule clear of it); a thought right
##   after it is thought while it is drawn, one pointing at it waits for the drawing (control); a point goes to the part it
##   names, a point in a written paragraph is set aside and said so (control: the pen is writing then), a point at the
##   camera is a span; a tap is the desk's; a still runs from its mark to the next written line; the voice reads every
##   word once and waits for the unspoken line at the end.
## - A page turns mid-sentence and the voice reads on through it: no rest inside a paragraph a page turns in (control: a
##   turn between two paragraphs is rested for); the turned page's first line begins once the voice has read the page, its
##   first word said before it is written, the next paragraph's first word written before it is said. A sketch pointed at
##   two paragraphs later starts a page (control: pointed at by nothing, it stays at the foot).
## - The page lies blank first: the voice opens on a rest of [constant LetterScript.BLANK_PAGE], nothing written before it.
## - The pen writes two words ahead: ordinary sentences are not waited for, a sentence of far more ink than words is
##   (control); a paragraph after a thought is waited for when it has more ink (control: less); a hesitation, on its own
##   line or in a written line, pauses the pen, which takes up again just before the voice goes on (control: none there).
## - Camera arc ([method LetterMedium._arc]): framings under twice as far apart; wide as the intro ends, in over the blank
##   page, close mid-page, let go before the turn; a thought, a point at a sketch and a tap do not move it in or out, a
##   point at the camera stands it back (control).
## - Desk clock ([LetterMedium], no stage): a line begins as the voice begins the word two before its first, no quicker than
##   [constant LetterScript.QUICKEST] its ink's time; the pen is ahead of the voice, on a quicker voice too (control: one
##   far quicker than the pen can go leaves it behind); first line, after-thought line, turned-page line and
##   under-picture line begin when each says; through a thought the pen is up; a tap and a point at the camera pose the
##   pen (top clear of the pad); a picture is up over its passage and the voice goes on once it is gone; a strike follows
##   both the line's last word and its ink; a still stops the camera's wander and clears the pen; the letter is not over
##   while the unspoken line is written.
## - A point lingers ([constant LetterScript.POINT_LINGER]): the voice rests after a point's sentence in a thought, the pen
##   held on its target and the camera framed on it (control: a thought with no point goes straight on); a point at the
##   camera holds the pen up through its rest.
## - Pictures dissolve into one another ([method LetterMedium.pictures_at]): a picture whose mark comes before the last one's
##   close, or straight after it, comes up over it with no rest and no sight of the page (control: after a written line it
##   comes up from the desk); the passage under a dissolve is captioned; every fade is [constant LetterScript.IMAGE_FADE];
##   no picture moves as the one before it did.
## - A hesitation before a picture is the writer's first: the picture comes up as the pen is taken up again; a dissolve with
##   one before the next picture holds the one before whole through it; a live reading not yet past it keeps the desk
##   (control: with no hesitation mark, the picture comes up in the pause).
## - A dense sketch is dashed off ([method LetterScript.draw_pace]): done soon after its words, the voice resting only that
##   long (control: the desk's quickest pen rests several times as long); one with room is drawn no quicker. Drawn alone
##   ([method LetterScript.drawn_alone]) the voice waits [constant LetterScript.DRAW_ALONE] and the desk draws it in that
##   (control: its ink at the hand's pace), keeping that pace through a plan made again (control: the desk's quickest).
##   Told its time ([method LetterScript.drawn_in_of]) `<!-- sketch (10s): ... -->` is drawn in 10 (control: untimed).
## - The pen is set down ([method LetterMedium._set_down_pose]): in hand until [constant LetterMedium.SET_DOWN_AFTER] past
##   the last stroke (control: not lain down early), then put down a frame at a time, no further than a hand would move it,
##   never into the desk or the pad, and lies as before it was picked up.
## - The pen is picked up ([method LetterMedium._pick_up_pose]): it lies level beside the pad's right edge through the intro,
##   is picked up once the blur has lifted and is over the first stroke as the line begins, moving a frame at a time, no
##   further than a hand would (control: the desk's own pen hovering over the first stroke jumps), never into the desk or
##   the pad. As it writes it leans right and a little down on screen ([constant Pen.UP]), whatever the sway
##   (control: the Proof desk's lean points up). Nothing lies where it rests ([method DeskLook.pen_rest]; control: with its
##   place not taken, a thing lands on it).
## - A page turned inside a paragraph after a mark is rested for, at least the turn's own rest; one that breaks a sentence
##   is not, and the voice waits at the next sentence with its first word on the page before it is said ([method
##   LetterScript._voice_text]; control: the same voice without that rest says it with the pen behind).
## - A line runs on into the voice's pause after it ([method LetterMedium._runs_on_to]): no line leaves the pen standing at
##   its end (control: each line ended as the voice ends the word two before its last stands at several).
## - The camera catches on a drawing ([method LetterMedium._caught]): on a page that opens on one it is close on it
##   [constant LetterMedium.CATCH_IN] after the turn (control: the page's own arc) held at its middle high on the page
##   (control: the column's reach), keeps it while a line up to [constant LetterMedium.CATCH_LOW] below is written (control:
##   the line's own framing), then lets go to the line's own framing, no quicker than [constant LetterMedium.LET_GO]
##   (control: a step).
## - The camera lets go before a turn once ([method LetterMedium._letting_go]): with words arriving a sentence at a time
##   past a hesitation and a picture's passage it never comes back in (control: the arc's guess at the steady pace does).
## - What is on the desk and its light are chosen, the seed only placing them ([method DeskLook.of]'s picks): every seed has
##   the same things and light, each looking its own way (control: nothing chosen, a different set on nearly every seed);
##   ticking another leaves how the rest look; a candlelit desk with none chosen has a taper (control: a lamplit desk none);
##   what lies flat and was chosen lies where the widest framing sees it ([constant DeskLook.SEEN]; control: drawn by the
##   seed, almost never).
## - A chosen desk is packed in to the paper ([method DeskLook._pack]): with tea lights and a dog tag, the tag lies within
##   4 cm of the paper and its bone wholly in the wide frame, on every desk (control: a circle round it anywhere in the
##   frame, on few); a crowded desk keeps what lies flat in the frame and pushes the candles out first; candles take sides
##   by turns (one alone on either, two on both), none in the pen's stretch beside the pad's right; things lie on both
##   sides of the pad, never in the lane where the pen taps ([constant DeskLook.TAP_LANE]), never on a pen.
## - A dog tag is cut as a dog's bone ([method DeskLook._dog_tag]): one flat bone, its halves each other's mirror, no rim, a
##   V cast with it at the middle of its long edge, its point as far out as the knobs; the V's triangle open from its apex
##   down to the bar's edge, half again the round hole's size at least (control: the round hole); the chain of links
##   through it, whole to a necklace's length (control: the 360 links a thick chain stops at); dropped, off the bone on
##   every tag (control: a single drop lies on it now and then). A name now and then ([method DeskLook.tag_name]): the
##   named desk's tag is engraved with the name held here by its digest alone ([constant DESK_NAME]; control: the
##   generator's next salt); a quarter of desks named. A small outline is cut at its own size ([method
##   Props._extrude_face]): a notch in its edge stays open (control: cut in meters, it fills some).
## - Words on the index cards ([method DeskLook._write]): nothing on the desk moves for them (control: another desk lies
##   otherwise); the words on the top card of every desk turn the quarter turn nearest upright (control: square to the card,
##   some are over half a quarter turn off), inside its margin, as the pad is written; too many words come smaller and
##   still fit (control: as the pad is written, they overrun it).
## - Ticked while the letter plays, the desk is dressed again ([method LetterMedium._set_desk]): a mounted letter's desk has
##   the thing and the cards' words at once, and another desk's number another desk, the letter as it was (control:
##   another hand loads the letter again).
## - The frame is cheap, held as a share of its control by this thread's own processor time ([WorkClock], the least of
##   several runs): asking whether a line written long ago is written; a plan made again with the past kept, against the
##   same plan with nothing kept; a finished line's ink asked again, against making it.
##
##   godot --headless --path . --script tests/desk/letter_check.gd

const WorkClock := preload("res://tests/work_clock.gd")
## A desk number and the SHA-256 of the name its dog tag is to draw ([constant DeskLook.TAG_NAME_SALT]) - the name itself
## is never written in the code.
const NAMED_DESK := 4230
const DESK_NAME := "d37f78ec86d14bfbc56637bf37e355cd34a98613a6e520dec285a6644163c9dc"
## Text written on the index cards.
const CARD := "Send letters to:\nRyan Brooks\n1500 Southwest Chandler Avenue\nBend, OR 97702"

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

## A picture a hesitation stands before (Secular Haze's "Housing came into my room looking for you." and the
## `<!-- hesitation: 3 -->` under it), and a dissolve into one a hesitation stands before.
const HESITANT := """Dear Friend,

Housing came into my room looking for you.

<!-- hesitation: 3 -->

<!-- image (full): a narrow room at night, nobody in it -->

They brought a key and a form.

<!-- hesitation -->

<!-- image (full): a form on a clipboard -->

They wrote her down.

<!-- /image -->

Yours.
"""

const DOT_SVG :="<svg viewBox=\"0 0 360 40\"><line x1=\"30\" y1=\"20\" x2=\"50\" y2=\"20\"/><circle id=\"the-dot\" cx=\"300\" cy=\"20\" r=\"4\" fill=\"black\"/></svg>"

var _fails: Array = []


## A pen leaning up, to the right and away from the writer - the frame's top right: the lean's control.
const TOP_RIGHT := Vector3(0.42, 0.64, -0.40)


func _init() -> void:
	# run on the first frame, in the tree: the pens laid by the desk are placed in it ([method _pens])
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	_hand()
	_format()
	_turns()
	_blank()
	_lag()
	_clock()
	_caught_camera()
	_pictures()
	_hesitant_picture()
	_dense_sketch()
	_struck()
	_pens()
	_pick_up()
	_set_down()
	_turn_waits()
	_line_breaks()
	_let_go()
	_chosen_desk()
	_packed()
	_dog_tag()
	_card_writing()
	_redressed()
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
	for h in Handwriting.HANDS:
		if Handwriting.nib(h) <= 0.0 or Handwriting.ascent_px(h) <= 0.0:
			lacking.append("%s has no nib or no height" % h)
		for ch in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.,;:!?'\"-()&":
			var g := Handwriting._glyph(ch, h)
			if g.is_empty() or (g[2] as Array).is_empty():
				lacking.append("%s %s" % [h, ch])
	_check(lacking.is_empty(), "every hand has a nib and strokes for every letter, digit and mark %s" % ", ".join(lacking))
	var i_strokes: Array = Handwriting.line(PackedStringArray(["i"]), [], 3, "a")["strokes"]
	var stem := _box(i_strokes[0]["points"]) if i_strokes.size() == 2 else Rect2()
	var dot := _box(i_strokes[1]["points"]) if i_strokes.size() == 2 else Rect2()
	_check(i_strokes.size() == 2 and dot.end.y < stem.position.y and dot.size.length() < stem.size.length() * 0.5,
		"an i's dot is made after its stem, above it (%d strokes)" % i_strokes.size())
	var whole := _ink(Handwriting.line(PackedStringArray(["Dear"]), [], 3, "b")["strokes"])
	var alone := 0.0
	for ch in "Dear":
		alone += _ink(Handwriting.line(PackedStringArray([ch]), [], 3, "c")["strokes"])
	var mm := _ink(Handwriting.line(PackedStringArray(["minimum"]), [], 3, "b")["strokes"])
	var mm_alone := 0.0
	for ch in "minimum":
		mm_alone += _ink(Handwriting.line(PackedStringArray([ch]), [], 3, "c")["strokes"])
	var short := _ink(Handwriting.line(PackedStringArray(["minimu"]), [], 3, "b")["strokes"])
	_check(whole >= alone * 0.97 and mm >= mm_alone * 0.97 and short < mm_alone * 0.9,
		"no letter is lost: \"Dear\" has the ink of its letters (%.0f of %.0f pt), \"minimum\" (%.0f of %.0f) - \"minimu\" less (%.0f)"
		% [whole, alone, mm, mm_alone, short])
	var a := Handwriting.line(PackedStringArray(["the", "pen"]), [], 3, "d")
	var b := Handwriting.line(PackedStringArray(["the", "pen"]), [], 3, "d")
	var c := Handwriting.line(PackedStringArray(["the", "pen"]), [], 4, "d")
	var other := Handwriting.line(PackedStringArray(["the", "pen"]), [], 3, "d", "caveat")
	_check(a["strokes"][0]["points"] == b["strokes"][0]["points"] and a["strokes"][0]["points"] != c["strokes"][0]["points"]
		and is_equal_approx(float(a["width"]), float(c["width"])) and not is_equal_approx(float(a["width"]), float(other["width"])),
		"the same line is the same strokes, another seed's differ, its width the words' alone - and another hand's its own")
	_check(not Handwriting.line(PackedStringArray(["1974"]), [], 3, "e")["strokes"].is_empty(), "a year is written")


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
			and y + Handwriting.descent_px() <= DeskScript.PH - DeskScript.FOOT
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
	# a sketch is drawn where its mark is: the paragraph after it written and said after it, the voice waiting the drawing
	# out - a rule left empty under it
	var draws := _of(d, "draw")
	var acts: Array = d["actions"]
	# (each wait against the same letter with no drawing yet, where the picture before it rests the voice as well)
	var bare := LetterScript.parse(LETTER, 3)
	var no_wait: float = rest_before.call(bare, "A cross")
	var after := lines.filter(func(l: Dictionary) -> bool: return String(l["text"]).begins_with("A cross"))
	var dr: Dictionary = draws[0] if draws.size() == 1 else {}
	var clear := ((dr.get("at", Vector2.ZERO) as Vector2).y + float(dr.get("d", 0.0))) + DeskScript.RULE * 0.25
	var was_y := DeskScript._snap_rule(maxf(DeskScript._snap_rule(clear), clear + Handwriting.ascent_px() * 0.8))
	var after_y := ((after[0] as Dictionary)["at"] as Vector2).y if after.size() == 1 else 0.0
	_check(draws.size() == 1 and int(dr["span"]) == 0 and spoken[int(dr["after"])] == "a" and after.size() == 1
		and int(after[0]["span"]) == 5 and acts.find(after[0]) > acts.find(dr)
		and rest_before.call(d, "A cross") - no_wait >= LetterScript.drawn_alone(float(dr["write"])) - 0.01
		and is_equal_approx(after_y, was_y + DeskScript.RULE),
		"a sketch is drawn where its mark is: the paragraph after it written and said after it, the voice waiting %.1f s more for the drawing, a rule left empty under it (the first rule clear of it, the control, %.0f px up)"
		% [rest_before.call(d, "A cross") - no_wait, after_y - was_y])
	# a thought right after it is thought while it is drawn, never written; one pointing at it waits for the drawing (the
	# control), as the written paragraph does
	var plain := "Dear Friend,\n\nI am writing.\n\n<!-- sketch: a cross and a dot on one line -->\n\n%s\n\nClose one eye.\n"
	var mused := LetterScript.parse(plain % "*A cross, and a dot.*", 3, svgs)
	var pointing := LetterScript.parse(plain % "<!-- point: sketch, the dot --> *A cross, and a dot.*", 3, svgs)
	var as_written := LetterScript.parse(plain % "A cross, and a dot.", 3, svgs)
	var m_draw: Dictionary = _of(mused, "draw")[0]
	var m_written := ""
	for l in _of(mused, "pad-text"):
		m_written += String((l as Dictionary)["text"]) + " "
	var ink := float(m_draw["write"])
	var m_rest: float = rest_before.call(mused, "\\*A cross")
	var p_rest: float = rest_before.call(pointing, "\\*A cross")
	var w_rest: float = rest_before.call(as_written, "A cross")
	_check(int(m_draw["span"]) == 5 and (mused["spoken"] as PackedStringArray)[int(m_draw["after"])] == "a"
		and not m_written.contains("A cross") and m_rest < ink * 0.5
		and int(_of(pointing, "draw")[0]["span"]) == 0 and _of(pointing, "point").size() == 1
		and p_rest >= LetterScript.drawn_alone(ink) and w_rest >= LetterScript.drawn_alone(ink),
		"a thought right after a sketch is thought while its %.1f s are drawn, never written, the voice resting %.2f s first - one pointing at it waits for the drawing (%.2f s), and points, as the paragraph written after it does (%.2f s; the controls)"
		% [ink, m_rest, p_rest, w_rest])
	var as_said := _of(bare, "pad-text").filter(func(l: Dictionary) -> bool: return String(l["text"]).begins_with("A cross"))
	_check(_of(bare, "draw").is_empty() and as_said.size() == 1 and int(as_said[0]["span"]) > 0,
		"with no drawing yet nothing is drawn, the paragraph after its mark written as it is said")
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
	# A sketch stays with what is said about it: one near a page's foot, pointed at two paragraphs on - the
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


## The pen's lead on the voice in [param m], heard as [param words] (by spoken index): `{first, worst, behind,
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


## The camera catches on a drawing ([method LetterMedium._caught]): see the header.
func _caught_camera() -> void:
	print("-- the camera caught on a drawing")
	var feed := ShowFeed.new()
	feed.outro_hold = 4.0
	feed.intro_hold = 1.0
	var svgs := {Manuscript.image_key("a cross and a dot on one line"): DOT_SVG}
	var id := String(DeskScript.item("draw", DOT_SVG)["id"])
	var records := {id: _dot_record(id)}
	var text := "Dear Friend,\n\n" + _filler(1, 30) + "\n<!-- new page -->\n\n<!-- sketch: a cross and a dot on one line -->\n\n" + _filler(6, 30)
	var m := LetterMedium.new()
	m.feed = feed
	m._pad = LegalPad.new()
	m.load_letter(text, {"seed": 3, "svgs": svgs, "ink": {"items": [_dot_record(id)]}})
	var parsed := LetterScript.parse(text, 3, svgs, LetterScript.lengths_of(records, 3), records)
	m._now = 0.0
	m.take_words(DeskScript.rehearsal(parsed, 0.42, 0.35, 1.0))
	var di := -1
	for i in m._actions.size():
		if String((m._actions[i] as Dictionary)["kind"]) == "draw":
			di = i
	var d: Dictionary = m._actions[di]
	var foot := (d["at"] as Vector2).y + float(d["d"])
	var mid := ((d["at"] as Vector2).y - float(d["h"]) + foot) * 0.5
	var aim := func() -> float: return float((m._framing()["line"] as Vector2).y) + 60.0
	# As it is drawn, on a page that opens on it: close, held on it, high on the page - the control, the page's own arc, still
	# coming in, and the column's own reach, which would hold it lower
	var opened := float(m._plan[di]["turn_at"]) + DeskScript.TURN
	m._now = opened + LetterMedium.CATCH_IN
	var f := m._framing()
	var drawn_k := float(f["k"])
	var drawn_aim: float = aim.call()
	var arc_k := m._arc()
	_check(bool(d.get("turn", false)) and drawn_k == 1.0 and absf(drawn_aim - mid) < 0.5 and float(f.get("top", 0.3)) == LetterMedium.CATCH_TOP
		and arc_k < 0.5 and mid < DeskScript.PH * 0.3,
		"a drawing a page opens on: the camera close on it %.0f s after the turn (the page's own arc, the control, %.2f of the way in), held at its middle, %.0f px down the page (the column's reach, the control, %.0f)"
		% [LetterMedium.CATCH_IN, arc_k, mid, DeskScript.PH * 0.3])
	# The writing under it: held on it while the line is within CATCH_LOW of it, then let go to exactly where the camera
	# would be with no drawing - the line's own framing - and kept there
	var near := -1
	var past := -1
	for i in range(di + 1, m._actions.size()):
		var a: Dictionary = m._actions[i]
		if String(a["kind"]) != "pad-text" or int(a["page"]) != int(d["page"]):
			continue
		var below := (a["at"] as Vector2).y - mid
		if below > DeskScript.RULE * 3.0 and below <= LetterMedium.CATCH_LOW:
			near = i
		elif below > LetterMedium.CATCH_LOW and past < 0:
			past = i
	var line_y := func(i: int) -> float: return ((m._actions[i] as Dictionary)["at"] as Vector2).y
	var from := float(m._plan[past]["start"]) - LetterMedium.LET_GO_LEAD if past >= 0 else INF
	m._now = minf(float(m._plan[near]["start"]) + 0.2, from - 0.2)
	var near_aim: float = aim.call()
	var near_k := float(m._framing()["k"])
	# Letting go, no quicker than LET_GO: from LET_GO_LEAD
	# before the line past CATCH_LOW, its aim from the drawing to the writing at most that fast - the control, the line's
	# own framing, a step - and then the line's own framing, kept
	m._now = from - 0.2
	var still_held := absf(aim.call() - mid) < 0.5
	# (while it is letting go: the framing still the drawing's, short of the line's own, at both samples - once it has
	# reached the line it steps with the writing, a rule a line, as the line's own framing does)
	var fastest := 0.0
	var was: float = aim.call()
	var was_held := true
	var t := from
	while t < from + 40.0:
		m._now = t
		var now_aim: float = aim.call()
		var held := float(m._framing().get("top", 0.3)) == LetterMedium.CATCH_TOP
		if held and was_held:
			fastest = maxf(fastest, absf(now_aim - was) / 0.1)
		was = now_aim
		was_held = held
		t += 0.1
	var step: float = line_y.call(past) + 60.0 - mid
	# (the line's own framing: the line being written, or the next where it begins within the desk's look ahead)
	var natural := true
	var lines_after: Array = []
	for i in range(past, m._actions.size()):
		var a: Dictionary = m._actions[i]
		if String(a["kind"]) == "pad-text" and int(a["page"]) == int(d["page"]):
			lines_after.append(i)
	for k in lines_after.size():
		var i: int = lines_after[k]
		if float(m._plan[i]["start"]) <= from + 40.0:
			continue
		m._now = float(m._plan[i]["start"]) + 0.2
		var at_aim: float = aim.call()
		var own := absf(at_aim - (line_y.call(i) + 60.0)) < 0.5
		var next := k + 1 < lines_after.size() and absf(at_aim - (line_y.call(lines_after[k + 1]) + 60.0)) < 0.5 \
			and float(m._plan[lines_after[k + 1]]["start"]) <= m._now + DeskMedium.CAM_LEAD
		natural = natural and (own or next) and float(m._framing().get("top", 0.3)) == 0.3
	_check(near >= 0 and past >= 0 and absf(near_aim - mid) < 0.5 and near_aim < line_y.call(near) + 60.0 - DeskScript.RULE * 2.0
		and near_k == 1.0 and still_held and fastest <= LetterMedium.LET_GO + 0.5 and step > LetterMedium.LET_GO * 4.0 and natural,
		"under it, the line %.0f px below its middle is written with the camera still on it (%.0f px, where the line alone would take it - the control - to %.0f); past %.0f px it lets go from %.0f s before that line, at most %.1f px a second (the line's own framing, the control, a step of %.0f), then the line's own framing, kept"
		% [line_y.call(near) - mid, near_aim, line_y.call(near) + 60.0, LetterMedium.CATCH_LOW, LetterMedium.LET_GO_LEAD, fastest, step])
	m.free()
	feed.free()


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
		and float(m.pen_at()["lift"]) <= Pen.LIFT + 0.0001,
		"a line begins as the voice begins the word %d before its first, or as the pen is free, the pen on the paper" % LetterScript.AHEAD_WORDS)
	var paced := true
	for i in m._actions.size():
		var pa: Dictionary = m._actions[i]
		if String(pa["kind"]) == "pad-text" and int(pa.get("span", 0)) > 0 and not m._pictured(pa):
			var took := float(m._plan[i]["end"]) - float(m._plan[i]["start"])
			paced = paced and took >= float(pa["write"]) / LetterScript.QUICKEST - 0.01
	_check(paced, "no line is written quicker than %.1f times its ink's own time" % LetterScript.QUICKEST)
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
	var th: int = at.call("always")
	m._now = t0.call(th) + 0.2
	var writing := false
	for i in m._actions.size():
		if String((m._actions[i] as Dictionary)["kind"]) == "pad-text":
			var w := m._written(i)
			writing = writing or (w > 0.0 and w < 1.0)
	_check(not writing and float(m.pen_at()["lift"]) > Pen.LIFT,
		"through a thought nothing is written and the pen is up")
	_check(is_equal_approx(float(m._framing()["k"]), m._arc()), "and the camera neither stands back nor comes in")
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
	# the page is drawn through a tap and a point (every frame asked the tap for its ink by an `id`; this gate counts script
	# errors)
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
	# A point lingers: the voice rests after its sentence, the pen held on the dot and the camera framed on it through
	# the rest - where a thought with no point in it goes straight on (the control) - and a point at the camera holds
	# the pen up through its rest too
	var pi := -1
	for i in m._actions.size():
		if String((m._actions[i] as Dictionary)["kind"]) == "point":
			pi = i
	var pt: Dictionary = m._actions[pi]
	var pt_said := float((words[int(pt["after"]) + int(pt["span"]) - 1] as Dictionary)["t1"])
	var pt_gap: float = t0.call(int(pt["after"]) + int(pt["span"])) - pt_said
	var not_that: int = at.call("not")
	var plain_gap: float = t0.call(not_that + 2) - float((words[not_that + 1] as Dictionary)["t1"])
	m._now = pt_said + LetterScript.POINT_LINGER * 0.8
	var dot := m.target_box(pt).get_center()
	var framed: Vector2 = m._framing()["line"]
	_check(pt_gap >= LetterScript.POINT_LINGER and plain_gap < LetterScript.POINT_LINGER
		and float(m._plan[pi]["end"]) >= pt_said + LetterScript.POINT_LINGER - 0.7
		and framed.distance_to(dot - Vector2(0.0, 60.0)) < 1.0,
		"a point lingers: the voice rests %.1f s after its sentence, the pen held on the dot %.1f s past it and the camera on it - after a thought with none, %.1f s (the control)"
		% [pt_gap, float(m._plan[pi]["end"]) - pt_said, plain_gap])
	var cam_said := float((words[int(camspan["after"]) + int(camspan["span"]) - 1] as Dictionary)["t1"])
	m._now = cam_said + LetterScript.POINT_LINGER - LetterMedium.CAMERA_EASE - 0.1
	var lingering := m._camera_pose(Transform3D.IDENTITY)
	m._now = cam_said + LetterScript.POINT_LINGER + 0.1
	_check(not lingering.is_empty() and float(lingering["f"]) == 1.0 and m._camera_pose(Transform3D.IDENTITY).is_empty(),
		"and a point at the camera holds the pen up through its rest, put back as it ends")
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
	# nothing else moves it in or out: on the same letter with a long paragraph after its point at the camera, so its turn
	# is well past the points and the tap, which here all fall where the arc lets go - and one between the tap and the point
	# at the camera, which here comes up within the tap - and its picture's passage taken out, the rule left empty under the
	# sketch takes
	var long := LETTER.replace("*Not that.*", "*Not that.*\n\n" + _filler(1, 30)).replace("<!-- a note to myself -->",
		_filler(1, 120)).replace("<!-- image (full): a quiet street at night, nobody on it -->\n\nThe street was empty when I came home. Nobody came, and nobody left.\n\n<!-- /image -->\n\n", "")
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
			seen.append("%s at %.1f s: arc %.2f, k %.2f" % [kind, m2._now, m2._arc(), float(m2._framing()["k"])])
	var cam2: Dictionary = (parsed2["spans"] as Array).filter(func(x: Dictionary) -> bool: return String(x["kind"]) == "camera")[0]
	m2._now = (float((words2[int(cam2["after"])] as Dictionary)["t0"]) + float((words2[int(cam2["after"]) + int(cam2["span"]) - 1] as Dictionary)["t0"])) * 0.5
	_check(steady and seen.size() == 2 and m2._arc() == 1.0 and float(m2._framing()["k"]) < 1.0,
		"a point at a sketch and a tap leave the camera close (%s), where a point at the camera stands it back (the control: at %.1f s, arc %.2f, k %.2f)"
		% ["; ".join(seen), m2._now, m2._arc(), float(m2._framing()["k"])])
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
	# The subtitles caption only what cannot be read on the page
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
	_check(not on_page and thought_cap and not drawn_cap,
		"a line the pen writes is not captioned - the paragraph after a sketch among them - and a thought is (the control)")
	_check(under and not unpainted,
		"the passage under a picture is captioned while the picture covers the screen, and not with no picture painted (the control)")

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
	# A live reading: words arriving a few at a time, the plan made again over what has begun - points, taps
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
	m._now = t_end.call(int(pics[2]["to"]) - 1) + LetterScript.IMAGE_AFTER + 1.2
	var slow := float(m.picture_at()["alpha"])
	_check(LetterScript.IMAGE_FADE >= 2.0 and LetterScript.IMAGE_FADE <= 3.0 and slow > 0.2,
		"every fade takes %.1f s: 1.2 s after a picture begins to go it is still at %.2f" % [LetterScript.IMAGE_FADE, slow])
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


func _hesitant_picture() -> void:
	print("-- a picture after a hesitation")
	# the control: the same letter and the same voice, the marks gone
	var hasty := RegEx.create_from_string("<!-- hesitation[^>]*-->\\n\\n").sub(HESITANT, "", true)
	var got := {}
	for text in [HESITANT, hasty]:
		var d := LetterScript.parse(text, 3)
		var pics: Array = (d["spans"] as Array).filter(func(x: Dictionary) -> bool: return String(x["kind"]) == "image")
		var words := DeskScript.rehearsal(d, 0.42, 0.35, 1.0)
		# the hesitations, which a rehearsal does not time: three seconds before each picture's words - the control's
		# voice pausing alike
		for i in range(int(pics[0]["from"]), words.size()):
			words[i]["t0"] = float(words[i]["t0"]) + (3.0 if i < int(pics[1]["from"]) else 6.0)
			words[i]["t1"] = float(words[i]["t1"]) + (3.0 if i < int(pics[1]["from"]) else 6.0)
		var img := Image.create(4, 4, false, Image.FORMAT_RGB8)
		var made := func(heard: Array) -> LetterMedium:
			var feed := ShowFeed.new()
			feed.outro_hold = 4.0
			feed.intro_hold = 1.0
			var m := LetterMedium.new()
			m.feed = feed
			m._pad = LegalPad.new()
			m.load_letter(text, {"seed": 3})
			m._now = 0.0
			m.take_words(heard)
			for p in pics:
				m._pictures[String(p["key"])] = ImageTexture.create_from_image(img)
			return m
		var alpha_of := func(m: LetterMedium, key: String) -> float:
			for p in m.pictures_at():
				if String((p as Dictionary)["key"]) == key:
					return float(p["alpha"])
			return 0.0
		var m: LetterMedium = made.call(words)
		var you := float((words[int(pics[0]["from"]) - 1] as Dictionary)["t1"])
		var resumed := float((words[int(pics[0]["from"])] as Dictionary)["t0"]) - LetterMedium.RESUME_LEAD
		var most := 0.0
		var t := you
		while t < resumed:
			m._now = t
			most = maxf(most, LetterMedium.cover_of(m.pictures_at()))
			t += 0.05
		m._now = resumed + LetterMedium.IMAGE_FADE + 0.01
		var whole: float = alpha_of.call(m, String(pics[0]["key"]))
		# the dissolve: the first held whole through the second hesitation, the second not up in it
		var form := float((words[int(pics[1]["from"]) - 1] as Dictionary)["t1"])
		var resumed2 := float((words[int(pics[1]["from"])] as Dictionary)["t0"]) - LetterMedium.RESUME_LEAD
		var least := 1.0
		var second := 0.0
		t = form
		while t < resumed2:
			m._now = t
			least = minf(least, LetterMedium.cover_of(m.pictures_at()))
			second = maxf(second, alpha_of.call(m, String(pics[1]["key"])))
			t += 0.05
		m._now = resumed2 + LetterMedium.IMAGE_FADE + 0.01
		var second_in: float = alpha_of.call(m, String(pics[1]["key"]))
		var dissolved := m.pictures_at().size() == 2
		(m.feed as ShowFeed).free()
		m.free()
		# a live reading that has heard no word past the hesitation yet
		var live: LetterMedium = made.call(words.slice(0, int(pics[0]["from"])))
		live._now = you + 2.0
		var live_cover := LetterMedium.cover_of(live.pictures_at())
		(live.feed as ShowFeed).free()
		live.free()
		got[text] = {"marked": pics.map(func(x: Dictionary) -> bool: return bool(x.get("after_hesitation", false))),
			"blend": bool(pics[1].get("blend", false)), "most": most, "whole": whole, "least": least,
			"second": second, "second_in": second_in, "dissolved": dissolved, "live": live_cover}
	var h: Dictionary = got[HESITANT]
	var c: Dictionary = got[hasty]
	_check(h["marked"] == [true, true] and c["marked"] == [false, false] and bool(h["blend"]) and bool(c["blend"]),
		"a picture's mark after a hesitation is marked so, and a dissolve still dissolves; with no hesitation neither is (the control)")
	_check(float(h["most"]) == 0.0 and float(h["whole"]) == 1.0 and float(c["most"]) > 0.5,
		"the desk is seen through the hesitation before a picture (covered at most %.2f), the picture whole %.1f s after the pen is taken up; with no hesitation it comes up in the pause (the control: %.2f)"
		% [float(h["most"]), LetterMedium.IMAGE_FADE, float(c["most"])])
	_check(float(h["least"]) > 0.999 and float(h["second"]) == 0.0 and float(h["second_in"]) == 1.0 and not bool(h["dissolved"])
		and float(c["second"]) > 0.5,
		"through a hesitation before a dissolve the picture before is held whole (at least %.4f covered) and the next waits for the pen; with none it comes in during the pause (the control: %.2f)"
		% [float(h["least"]), float(c["second"])])
	_check(float(h["live"]) == 0.0 and float(c["live"]) > 0.5,
		"a live reading that has not heard the words after a hesitation keeps the desk; with no hesitation the picture is up from the word before (the control: %.2f)"
		% float(c["live"]))


## The pen is set down again once the letter is written, the pick-up's way back.
func _set_down() -> void:
	print("-- the pen set down")
	var feed := ShowFeed.new()
	feed.outro_hold = 4.0
	feed.intro_hold = 1.0
	var svgs := {Manuscript.image_key("a cross and a dot on one line"): DOT_SVG}
	var id := String(DeskScript.item("draw", DOT_SVG)["id"])
	var m := LetterMedium.new()
	m.feed = feed
	m._pad = LegalPad.new()
	m.load_letter(LETTER, {"seed": 3, "svgs": svgs, "ink": {"items": [_dot_record(id)]}})
	var records := {id: _dot_record(id)}
	var parsed := LetterScript.parse(LETTER, 3, svgs, LetterScript.lengths_of(records, 3), records)
	m._now = 0.0
	m.take_words(DeskScript.rehearsal(parsed, 0.42, 0.35, 1.0))
	var last := m._last_done()
	var end := float(m._plan[last]["end"])
	var w := m._set_down()
	var hand := m._pen_in_hand()
	_check(last >= 0 and w.x >= end + LetterMedium.SET_DOWN_AFTER - 0.001 and absf(w.y - w.x - LetterMedium.PICK_UP) < 0.001,
		"the pen is set down %.1f s after its last stroke ends, over %.1f s" % [w.x - end, w.y - w.x])
	# In hand until then (the control: it has not lain down early)
	var held := true
	for t in [end - 0.05, end + 0.5, w.x - 0.02]:
		m._now = t
		held = held and m._pen_xf().origin.distance_to(m._lying(hand).origin) > 0.03
	_check(held, "through the last stroke and the beat after it the pen is in hand, off the desk")
	# The way: on, a frame at a time, and never into the desk or the pad
	var dt := 1.0 / 60.0
	var worst := 0.0
	var lowest := INF
	var prev := Transform3D()
	var t := w.x - 0.2
	var k := 0
	while t <= w.y + 0.2:
		m._now = t
		var xf := m._pen_xf()
		if k > 0:
			worst = maxf(worst, maxf(xf.origin.distance_to(prev.origin),
				(xf.origin + xf.basis.y * LetterMedium.PEN_TOP).distance_to(prev.origin + prev.basis.y * LetterMedium.PEN_TOP)))
		for along in [0.0, 0.02, 0.06, 0.1, LetterMedium.PEN_TOP]:
			var q: Vector3 = xf.origin + xf.basis.y * float(along)
			var on_pad := absf(q.x) <= LegalPad.W * 0.5 + DeskMedium.PEN_R and absf(q.z) <= LegalPad.H * 0.5 + DeskMedium.PEN_R
			var over: float = q.y - (0.0003 if on_pad else LegalPad.DESK_Y) - (0.0 if float(along) == 0.0 else DeskMedium.PEN_R * 0.9)
			lowest = minf(lowest, over)
		prev = xf
		t += dt
		k += 1
	_check(worst < 0.005, "on the way down it moves at most %.1f mm a frame" % (worst * 1000.0))
	_check(lowest > -0.0002, "and it never goes into the desk or the pad (%.1f mm clear at the least)" % (lowest * 1000.0))
	var lies := true
	for u in [w.y + 0.01, w.y + 2.0, w.y + 60.0]:
		m._now = u
		lies = lies and m._pen_xf().is_equal_approx(m._lying(hand))
	m._now = 0.0
	_check(lies and m._pen_xf().is_equal_approx(m._lying(hand)),
		"and from then on it lies at its place, exactly as it lay before it was picked up")


## The pen is picked up from the desk, and nothing else lies where it does.
func _pick_up() -> void:
	print("-- the pen picked up")
	var feed := ShowFeed.new()
	feed.outro_hold = 4.0
	feed.intro_hold = 1.0
	var svgs := {Manuscript.image_key("a cross and a dot on one line"): DOT_SVG}
	var id := String(DeskScript.item("draw", DOT_SVG)["id"])
	var m := LetterMedium.new()
	m.feed = feed
	m._pad = LegalPad.new()
	m.load_letter(LETTER, {"seed": 3, "svgs": svgs, "ink": {"items": [_dot_record(id)]}})
	var records := {id: _dot_record(id)}
	var parsed := LetterScript.parse(LETTER, 3, svgs, LetterScript.lengths_of(records, 3), records)
	m._now = 0.0
	m.take_words(DeskScript.rehearsal(parsed, 0.42, 0.35, 1.0))
	var opening := m._opening()
	var w := m._pick_up()
	var first := m._first_done()
	var start := float(m._plan[first]["start"])
	var rest := DeskLook.pen_rest(m.look, LegalPad.DESK_Y)
	var lies: Vector3 = (rest["nib"] as Vector3) + Vector3.UP * DeskMedium.PEN_R * 1.04
	var lying := true
	for t in [0.0, opening - 1.0, opening + ShowOpening.FOCUS_PULL.y * 0.5, w.x - 0.02]:
		m._now = t
		var xf := m._pen_xf()
		var top := xf.origin + xf.basis.y * LetterMedium.PEN_TOP
		lying = lying and xf.origin.distance_to(lies) < 0.0005 and absf(xf.basis.y.y) < 0.01 \
			and minf(xf.origin.x, top.x) > LegalPad.W * 0.5 + 0.015 and absf(top.y - xf.origin.y) < 0.001
	_check(lying, "through the intro and its focus pull the pen lies level on the desk, beside the pad's right edge")
	_check(w.x < INF and ShowOpening.pull("title", w.x, opening, true) >= ShowOpening.INTRO_LIFT
		and ShowOpening.title_alpha("title", w.x, opening, true) == 0.0 and w.y < start and start - w.y < 0.5,
		"it is picked up once a titled intro's blur has lifted and the name is gone (%.1f s after the opening), and is over the first stroke as the line begins (%.2f s before)"
		% [w.x - opening, start - w.y])
	# The way: on, a frame at a time, and never into the desk or the pad
	var dt := 1.0 / 60.0
	var worst := 0.0
	var lowest := INF
	var prev := Transform3D()
	var t := w.x - 0.2
	var k := 0
	while t <= start + 0.2:
		m._now = t
		var xf := m._pen_xf()
		if k > 0 and t <= start:
			# up to the paper: the pick-up and the nib's way down, not the writing after it
			worst = maxf(worst, maxf(xf.origin.distance_to(prev.origin),
				(xf.origin + xf.basis.y * LetterMedium.PEN_TOP).distance_to(prev.origin + prev.basis.y * LetterMedium.PEN_TOP)))
		if t < start:
			for along in [0.0, 0.02, 0.06, 0.1, LetterMedium.PEN_TOP]:
				var q: Vector3 = xf.origin + xf.basis.y * float(along)
				var on_pad := absf(q.x) <= LegalPad.W * 0.5 + DeskMedium.PEN_R and absf(q.z) <= LegalPad.H * 0.5 + DeskMedium.PEN_R
				var over: float = q.y - (0.0003 if on_pad else LegalPad.DESK_Y) - (0.0 if float(along) == 0.0 else DeskMedium.PEN_R * 0.9)
				lowest = minf(lowest, over)
		prev = xf
		t += dt
		k += 1
	m._now = w.x
	var hover := m._world(m._before_first()["p"], Pen.REST_LIFT)
	_check(worst < 0.005 and hover.distance_to(lies) > 0.1,
		"on the way it moves at most %.1f mm a frame - the control, the desk's own pen hovering over the first stroke, is %.0f cm from where it lies"
		% [worst * 1000.0, hover.distance_to(lies) * 100.0])
	_check(lowest > -0.0002, "and it never goes into the desk or the pad (%.1f mm clear at the least)" % (lowest * 1000.0))
	m._now = start + 0.05
	_check(m._pick_up_pose(Transform3D.IDENTITY).is_empty() and float(m.pen_at()["lift"]) <= Pen.LIFT + 0.0001,
		"and once the line begins the pen is the desk's own, on the paper")
	# The pen leans to the right and a little down as the camera sees it, close and wide, all the while it writes
	var lo := INF
	var hi := -INF
	var sum := 0.0
	var count := 0
	var n := 0
	for i in m._actions.size():
		if String((m._actions[i] as Dictionary)["kind"]) != "pad-text" or n >= 6:
			continue
		n += 1
		var s0 := float(m._plan[i]["start"])
		var s1 := float(m._plan[i]["end"])
		for q in 12:
			m._now = lerpf(s0, s1, float(q) / 11.0)
			var body := m._pen_xf().basis.y
			for pitch in [float(LetterMedium.LETTER_LOCAL["pitch"]), float(LetterMedium.LETTER_WIDE["pitch"])]:
				var down := _screen_down(body, pitch)
				lo = minf(lo, down)
				hi = maxf(hi, down)
				sum += down
				count += 1
	var desk := _screen_down(Pen.lean(TOP_RIGHT, 0.0, 3, 0.5, Vector3.ZERO), float(LetterMedium.LETTER_LOCAL["pitch"]))
	var mean := sum / float(maxi(count, 1))
	_check(lo > 0.0 and hi < 35.0 and mean > 10.0 and mean < 24.0 and desk < -30.0,
		"as it writes, the pen's top points right and a little down on the screen (%.0f degrees under the level, %.0f to %.0f with the hand's sway) - the control, a pen leaning up and away to the frame's top right, %.0f degrees over it"
		% [mean, lo, hi, -desk])
	m.free()
	# Nothing else lies there
	var on := 0
	var ctl := 0
	var placed := 0
	for seed in 600:
		var look := DeskLook.of(seed)
		var pen := DeskLook.pen_rest(look, LegalPad.DESK_Y)
		var a := Vector2((pen["nib"] as Vector3).x, (pen["nib"] as Vector3).z)
		var b := Vector2((pen["top"] as Vector3).x, (pen["top"] as Vector3).z)
		var r := DeskLook._rng(seed, "pen probe")
		var rad := r.randf_range(0.04, 0.12)
		var r_ctl := DeskLook._rng(seed, "pen probe")
		r_ctl.randf_range(0.04, 0.12)
		var at := DeskLook._placed(r, rad, false, DeskLook._pen_taken(look, LegalPad.DESK_Y))
		var free := DeskLook._placed(r_ctl, rad, false, [])
		if at.x < INF:
			placed += 1
			on += int(at.distance_to(Geometry2D.get_closest_point_to_segment(at, a, b)) < rad + DeskMedium.PEN_R)
		if free.x < INF:
			ctl += int(free.distance_to(Geometry2D.get_closest_point_to_segment(free, a, b)) < rad + DeskMedium.PEN_R)
	_check(placed > 500 and on == 0 and ctl > 0,
		"nothing is set down where the pen lies (%d placed; the control, its place not taken, %d on it)" % [placed, ctl])


## A letter of many sentences: [param paras] paragraphs of sentences [param lengths] words long in turn, a comma in
## every third - where a page may turn after a mark or inside a sentence.
static func _prose(paras: int, lengths: Array) -> String:
	var vocab := ["the", "letter", "was", "written", "slowly", "by", "lamplight", "and", "nobody", "read", "it", "twice"]
	var out := PackedStringArray()
	var n := 0
	var s := 0
	for i in paras:
		var para := PackedStringArray()
		for _k in 4:
			var words := PackedStringArray()
			var len := int(lengths[s % lengths.size()])
			for w in len:
				words.append(String(vocab[(n * 7 + w * 5) % vocab.size()]))
				n += 1
			if s % 3 == 1:
				words[len / 2] += ","
			var sentence := " ".join(words)
			para.append(sentence.substr(0, 1).to_upper() + sentence.substr(1) + ".")
			s += 1
		out.append(" ".join(para))
	return "\n\n".join(out) + "\n"


## A voice that pauses as a real one does, for [param parsed]: [param word] a word, [param stop] more at a sentence's end
## and a third of it at a comma, the rests and hesitations the script writes, and each word's `sentence` - for words
## handed a sentence at a time, as a live reading's arrive.
static func _voiced(parsed: Dictionary, word := LetterScript.READ_WORD, stop := 0.7, lead := 1.0) -> Array:
	var spoken: PackedStringArray = parsed["spoken"]
	var token := RegEx.create_from_string("<!--\\s*action-hold\\s*:\\s*([0-9.]+)\\s*-->|<!--\\s*hesitation\\s*(?::\\s*([0-9.]+))?\\s*-->|<!--.*?-->|\\S+")
	var ends := RegEx.create_from_string(LetterScript.SENTENCE_END)
	var out: Array = []
	var t := lead
	var sentence := 0
	for chunk in String(parsed["speakable"]).split("\n\n"):
		var said := false
		for m in token.search_all(String(chunk)):
			var tok := m.get_string()
			if not m.get_string(1).is_empty():
				t += float(m.get_string(1))
			elif tok.begins_with("<!--") and tok.contains("hesitation"):
				t += float(m.get_string(2)) if not m.get_string(2).is_empty() else LetterMedium.HESITATE
			elif not tok.begins_with("<!--") and not TabletScript.norm(tok).is_empty() and out.size() < spoken.size():
				out.append({"text": spoken[out.size()], "t0": t, "t1": t + word * 0.9, "sentence": sentence})
				t += word
				said = true
				if ends.search(tok) != null:
					t += stop
					sentence += 1
				elif tok.ends_with(",") or tok.ends_with(";") or tok.ends_with(":"):
					t += stop / 3.0
		if said:
			t += 0.35
			sentence += 1
	return out


## A letter's medium, off the stage, read by [param words] (all of them known, as an export's are).
## What is on the desk and its light are chosen, the seed only placing them and drawing how they look.
func _chosen_desk() -> void:
	print("-- what is on the desk, chosen")
	var kinds := ["mug", "pencil", "dog_tag", "mat"]
	var picks := {"things": kinds, "mood": "daylight"}
	var first := DeskLook.of(11, picks)
	var same := true
	var moved := false
	var drawn := {}
	for seed in range(12, 40):
		var l := DeskLook.of(seed, picks)
		same = same and DeskLook.kinds(l) == kinds and String(l["mood"]) == "daylight"
		moved = moved or str(l["things"]) != str(first["things"]) or str(l["materials"]) != str(first["materials"])
		var own := DeskLook.of(seed)
		drawn[str(DeskLook.kinds(own)) + String(own["mood"])] = true
	_check(same and moved and drawn.size() > 10,
		"chosen, every seed has the same things and light, each looking its own way - the control, nothing chosen: %d sets of things and light over 28 seeds"
		% drawn.size())
	var more := DeskLook.of(11, {"things": kinds + ["eraser"], "mood": "daylight"})
	var kept := true
	for t in first["things"]:
		var twin: Array = (more["things"] as Array).filter(func(o: Dictionary) -> bool: return o["kind"] == t["kind"])
		kept = kept and twin.size() == 1 and str(twin[0]) == str(t)
	_check(kept and DeskLook.kinds(more) == ["mug", "pencil", "eraser", "dog_tag", "mat"],
		"ticking another thing leaves how the rest look as they were")
	var dark := DeskLook.kinds(DeskLook.of(11, {"things": ["mug"], "mood": "candlelight"}))
	var own_candle := DeskLook.kinds(DeskLook.of(11, {"things": ["mug", "pillar"], "mood": "candlelight"}))
	var lamp := DeskLook.kinds(DeskLook.of(11, {"things": ["mug"], "mood": "lamplight"}))
	_check(dark == ["mug", "taper"] and own_candle == ["mug", "pillar"] and lamp == ["mug"],
		"a desk lit by candles and given none has a taper set down - one given its own keeps it, and a lamplit desk has none (the control)")
	_check(DeskLook.picks_of({"things": ["mug"], "mood": "dusk", "seed": 3}) == {"things": ["mug"], "mood": "dusk"}
		and DeskLook.picks_of({"mood": "noon"}).is_empty(), "a document's letter hands its things and light, never a light there is not")
	# Where the frame sees them: what lies flat and was chosen, beside the pad in the widest framing
	var flat := ["pencil", "eraser", "clips", "dog_tag"]
	var seen := 0
	var all := 0
	var ctl_seen := 0
	var ctl_all := 0
	for seed in range(1, 13):
		for chosen in [true, false]:
			var l := DeskLook.of(seed, {"things": flat} if chosen else {})
			var dressed := DeskLook.dress(l, seed, LegalPad.DESK_Y)
			for c in (dressed["node"] as Node).get_children():
				if not (c as Node).has_meta("kind") or not (String(c.get_meta("kind")) in flat):
					continue
				var p := Vector2((c as Node3D).position.x, (c as Node3D).position.z)
				if chosen:
					all += 1
					seen += int(Geometry2D.is_point_in_polygon(p, PackedVector2Array(DeskLook.SEEN)))
				else:
					ctl_all += 1
					ctl_seen += int(Geometry2D.is_point_in_polygon(p, PackedVector2Array(DeskLook.SEEN)))
			(dressed["node"] as Node).free()
	_check(all >= 40 and float(seen) >= 0.75 * float(all) and float(ctl_seen) < 0.4 * float(ctl_all),
		"what lies flat and was chosen lies where the wide framing sees it (%d of %d) - the control, the same things drawn by the seed, %d of %d"
		% [seen, all, ctl_seen, ctl_all])


## A chosen desk packed in to the paper, the candles the first pushed out of the frame.
func _packed() -> void:
	print("-- a chosen desk packed in to the paper")
	var seen := PackedVector2Array(DeskLook.SEEN)
	var edge := -LegalPad.W * 0.5
	var snug := 0
	var whole := 0
	var ctl_snug := 0
	var n := 16
	for seed in range(1, n + 1):
		var l := DeskLook.of(seed, {"things": ["tealights", "dog_tag"], "mood": "lamplight"})
		var dressed := DeskLook.dress(l, seed, LegalPad.DESK_Y)
		for c in (dressed["node"] as Node).get_children():
			if (c as Node).has_meta("kind") and String(c.get_meta("kind")) == "dog_tag":
				var foot: PackedVector2Array = c.get_meta("foot")
				var near := DeskLook._gap(foot)
				snug += int(near >= 0.0 and near <= 0.04)
				var halves: Array = Props.sanitize(DeskLook._thing("dog_tag", DeskLook._rng(seed, "chosen dog_tag")), ["#888888"])["things"][0]["parts"].slice(0, 2)
				var bone_in := true
				for plate in halves:
					for q in plate["points"]:
						var w := (c as Node3D).transform * (((plate["at"] as Vector3) + Vector3((q as Vector2).x, 0.0, (q as Vector2).y)) * 0.01)
						bone_in = bone_in and Geometry2D.is_point_in_polygon(Vector2(w.x, w.z), seen)
				whole += int(bone_in)
		(dressed["node"] as Node).free()
		# The control: placed as it had been, a circle round it anywhere in the frame beside the pad, the tea lights in
		# their band first
		var r := DeskLook._rng(seed, "control")
		var taken := DeskLook._pen_taken(l, LegalPad.DESK_Y)
		var lights := DeskLook._placed(r, 0.06, false, taken, DeskLook.CANDLE_BAND)
		taken.append(Vector3(lights.x, lights.y, 0.06))
		var at := DeskLook._placed(r, 0.047, false, taken, Rect2(-0.26, -0.175, 0.52, 0.305))
		ctl_snug += int(at.x != INF and edge - (at.x + 0.025) <= 0.04)
	_check(snug == n and whole == n and ctl_snug * 2 < n,
		"tea lights and a dog tag: the tag lies within 4 cm of the paper and its bone wholly in the wide frame on all %d desks (%d, %d) - the control, a circle round it anywhere in the frame, on %d"
		% [n, snug, whole, ctl_snug])
	var crowd := ["pencil", "eraser", "clips", "cards", "dog_tag", "mug", "tealights", "taper", "pillar"]
	var flat_in := 0
	var flat_all := 0
	var lit_in := 0
	var lit_all := 0
	for seed in range(1, 13):
		var dressed := DeskLook.dress(DeskLook.of(seed, {"things": crowd, "mood": "lamplight"}), seed, LegalPad.DESK_Y)
		for c in (dressed["node"] as Node).get_children():
			if not (c as Node).has_meta("kind"):
				continue
			var kind := String(c.get_meta("kind"))
			var inside := Geometry2D.is_point_in_polygon(Vector2((c as Node3D).position.x, (c as Node3D).position.z), seen)
			if bool((DeskLook.THINGS[kind] as Dictionary).get("lit", false)):
				lit_all += 1
				lit_in += int(inside)
			elif not bool((DeskLook.THINGS[kind] as Dictionary)["tall"]):
				flat_all += 1
				flat_in += int(inside)
		(dressed["node"] as Node).free()
	_check(flat_all >= 55 and float(flat_in) >= 0.9 * float(flat_all) and float(lit_in) / float(lit_all) < float(flat_in) / float(flat_all) - 0.3,
		"a crowded desk keeps what lies flat in the frame (%d of %d) and pushes the candles out first (%d of %d in it) - their light falls on the page from anywhere"
		% [flat_in, flat_all, lit_in, lit_all])
	# Its things on both sides of the pad, each leaning to one: never in the lane where the pen taps the desk, never on a
	# pen - and where nothing had been let lie, the stretch beside the pad's right (the control: none there before)
	var things := ["pencil", "dog_tag", "eraser", "cards", "tealights"]
	var right := {}
	var stretch := 0
	var in_lane := 0
	var on_pen := 0
	for seed in range(1, 25):
		var l := DeskLook.of(seed, {"things": things, "mood": "lamplight"})
		var dressed := DeskLook.dress(l, seed, LegalPad.DESK_Y)
		var pens: Array = []
		for j in maxi(1, int(l.get("pens", 1))):
			var pen := DeskLook.pen_rest(l, LegalPad.DESK_Y, j)
			pens.append([Vector2((pen["nib"] as Vector3).x, (pen["nib"] as Vector3).z), Vector2((pen["top"] as Vector3).x, (pen["top"] as Vector3).z)])
		for c in (dressed["node"] as Node).get_children():
			if not (c as Node).has_meta("kind"):
				continue
			var kind := String(c.get_meta("kind"))
			var foot: PackedVector2Array = c.get_meta("foot")
			var mid := Vector2((c as Node3D).position.x, (c as Node3D).position.z)
			right[kind] = int(right.get(kind, 0)) + int(mid.x > 0.0)
			stretch += int(mid.x > LegalPad.W * 0.5 and mid.x < DeskLook.TALL_RIGHT and absf(mid.y) < LegalPad.H * 0.5)
			for q in foot:
				in_lane += int(q.x > LegalPad.W * 0.5 + 0.001 and q.x < LegalPad.W * 0.5 + DeskLook.TAP_LANE - 0.001 and absf(q.y) < LegalPad.H * 0.5)
			for pen in pens:
				for k in 11:
					on_pen += int(Geometry2D.is_point_in_polygon((pen[0] as Vector2).lerp(pen[1], float(k) / 10.0), foot))
		(dressed["node"] as Node).free()
	var sided := true
	for kind in things:
		sided = sided and int(right.get(kind, 0)) >= 4 and int(right.get(kind, 0)) <= 20
	_check(sided and stretch >= 10 and in_lane == 0 and on_pen == 0,
		"a chosen desk's things lie on both sides of the pad (on the right of 24: %s), %d in the stretch beside its right where none had lain (the control, the rule before: none) - none in the pen's tap lane, none on a pen"
		% [str(right), stretch])
	var alone := Vector2i.ZERO
	var lit_both := 0
	var lit_desks := 0
	var clear := true
	for seed in range(1, 25):
		for kinds in [["dog_tag", "taper"], ["dog_tag", "taper", "tealights"]]:
			var dressed := DeskLook.dress(DeskLook.of(seed, {"things": kinds, "mood": "lamplight"}), seed, LegalPad.DESK_Y)
			var sides := Vector2i.ZERO
			for t in dressed["lit"]:
				var at := ((t as Dictionary)["node"] as Node3D).position
				sides += Vector2i(int(at.x < 0.0), int(at.x > 0.0))
				# never in the pen's stretch beside the pad's right
				var foot: PackedVector2Array = ((t as Dictionary)["node"] as Node).get_meta("foot")
				for q in foot:
					clear = clear and not (q.x > 0.0 and q.x < DeskLook.TALL_RIGHT and q.y < LegalPad.H * 0.5 + DeskLook.PAD_ROOM)
			if kinds.size() == 2:
				alone += sides
			else:
				lit_desks += 1
				lit_both += int(sides.x > 0 and sides.y > 0)
			(dressed["node"] as Node).free()
	_check(alone.x >= 6 and alone.y >= 6 and lit_both == lit_desks and clear,
		"a chosen desk's candles take their sides by turns: one alone on the left %d times and the right %d, two on both sides on all %d - and none in the pen's stretch beside the pad's right"
		% [alone.x, alone.y, lit_desks])


## A dog tag cut as a dog's bone: flat, hung by the V at the middle of its edge on a long fine chain, whole.
func _dog_tag() -> void:
	print("-- a dog tag")
	var n := 24
	var shaped := 0
	var whole := 0
	var ctl_capped := 0
	var longest := 0.0
	var shortest := INF
	var off_bone := 0
	var ctl_over := 0
	var shapes := {}
	for seed in range(1, n + 1):
		var spec := DeskLook._thing("dog_tag", DeskLook._rng(seed, "chosen dog_tag"))
		var parts: Array = Props.sanitize(spec, ["#888888"])["things"][0]["parts"]
		var plate: Dictionary = parts[0]
		var other: Dictionary = parts[1]
		var chain: Dictionary = parts.filter(func(p: Dictionary) -> bool: return p["shape"] == "strand")[0]
		# The bone: one flat plate in two halves, each the other's mirror, and nothing laid round its edge (no rim)
		var pts: Array = plate["points"]
		var mirrored := (other["points"] as Array).size() == pts.size()
		for q in pts:
			var twin := false
			for o in other["points"]:
				twin = twin or (o as Vector2).distance_to(Vector2(-(q as Vector2).x, (q as Vector2).y)) < 1e-4
			mirrored = mirrored and twin
		var tubes := parts.filter(func(p: Dictionary) -> bool: return p["shape"] == "tube").size()
		var plate_at: Vector3 = plate["at"]
		# The V cast with it: out of the middle of the long edge, its point on the axis as far out as the knobs come - and A
		# V, not a hole: the triangle between its struts open, its apex on the axis, its foot on the bar's edge from the
		# axis to short of the V's own, larger than the round hole it had been, and the chain's two runs through it
		var point := Vector2(0.0, INF)           # the furthest out on the axis
		var knobs := INF                         # how far out the lobes come
		var waist := -INF                        # the bar's edge beside the V
		for q in pts:
			var v: Vector2 = q
			if absf(v.x) < 1e-4 and v.y < point.y:
				point = v
			if absf(v.x) > 0.9:
				knobs = minf(knobs, v.y)
			if v.x > 0.05 and v.x < 0.6 and v.y < 0.0:
				waist = maxf(waist, v.y)
		var apex := Vector2(0.0, INF)            # the opening's, on the axis between the point and the bar
		var on_bar: Array = []                   # what lies on the bar's edge by the V: the opening's corner, then its foot
		for q in pts:
			var v: Vector2 = q
			if absf(v.x) < 1e-4 and v.y > point.y + 1e-4 and v.y < waist - 1e-4:
				apex = v
			if absf(v.y - waist) < 1e-4 and v.x > 1e-4 and v.x < 0.6:
				on_bar.append(v.x)
		on_bar.sort()
		var opening := float(on_bar[0]) * (waist - apex.y) if on_bar.size() == 2 and apex.y < INF else 0.0
		var line := Props.strand_line(chain, RandomNumberGenerator.new())
		var ends := line[0].distance_to(line[line.size() - 1])
		var hole := ((chain["path"][0] as Vector2) + (chain["path"][-1] as Vector2)) * 0.5
		var right := PackedVector2Array()
		var left := PackedVector2Array()
		for q in pts:
			right.append(q as Vector2)
		for q in other["points"]:
			left.append(q as Vector2)
		var outline: PackedVector2Array = Geometry2D.merge_polygons(right, left)[0]
		var through := (Geometry2D.is_point_in_polygon(hole, outline) and not Geometry2D.is_point_in_polygon(hole, right)
			and not Geometry2D.is_point_in_polygon(hole, left))
		shaped += int(mirrored and tubes <= 1 and (other["at"] as Vector3).is_equal_approx(plate_at) and point.y < INF
			and absf(point.y - knobs) < 0.12 and point.y < waist - 0.15 and opening > PI * 0.075 * 0.075 * 1.5
			and absf(hole.x) < 1e-3 and hole.y > apex.y and hole.y < waist and through
			and String(chain["kind"]) == "chain" and ends < 0.003)
		var along := Props._lengths(Array(line))[-1]
		longest = maxf(longest, along)
		shortest = minf(shortest, along)
		# The chain whole: a link where its last run comes back to the ring, past where whole rings a link had stopped it
		var geo = Props._strand(chain, RandomNumberGenerator.new())[0]["geo"]
		var t := float(chain["thickness"]) * 0.01
		var late: Vector3 = line[int(line.size() * 0.97)]
		var found := false
		for v in geo.v:
			if (v as Vector3).distance_to(late) < t:
				found = true
				break
		whole += int(found and geo.v.size() < 400000)
		var pitch := (2.0 * t * 0.36 - t * 0.13) * 1.45
		ctl_capped += int(along / pitch > 360.0)
		# Dropped, not looped: off the bone - the control, the first drop alone, on it now and then - and each its own shape,
		# on both halves and the whole bone round them (for a drop of its own, the control)
		# (the chain and the plate are laid about the same middle: each in the bone's own frame) - but for where it goes
		# through the V and over its point, as it should
		var over := 0
		for q in line:
			var at := Vector2(q.x, q.z) * 100.0
			over += int((Geometry2D.is_point_in_polygon(at, right) or Geometry2D.is_point_in_polygon(at, left))
				and at.distance_to(hole) > DeskLook.TAG_THROUGH)
		off_bone += int(over == 0)
		var r0 := DeskLook._rng(seed, "first drop")
		ctl_over += int(DeskLook._over(DeskLook._dropped(r0, hole, 80.0, outline), outline, hole) > 0)
		var lo2 := Vector2(INF, INF)
		var hi2 := -lo2
		for q in line:
			lo2 = lo2.min(Vector2(q.x, q.z))
			hi2 = hi2.max(Vector2(q.x, q.z))
		shapes[str(((hi2 - lo2) * 1000.0).round())] = true
	_check(shaped == n,
		"one flat bone on every tag, its halves each other's mirror and no rim round it, a V cast with it at the middle of its long edge, its point as far out as the knobs, two struts open between them down to the bar - half again the round hole's size at least - the chain a chain of links through it (%d of %d)"
		% [shaped, n])
	_check(whole == n and ctl_capped == n and shortest > DeskLook.TAG_LONG.x * 0.0095 and longest < DeskLook.TAG_LONG.y * 0.0105,
		"its chain is whole, links to its end on all %d, %.0f to %.0f cm - a necklace's - where the 360 links a thick chain stops at would have stopped %d"
		% [n, shortest * 100.0, longest * 100.0, ctl_capped])
	_check(off_bone == n and ctl_over > 0 and shapes.size() == n,
		"its chain is dropped, never looped: off the bone on all %d (the control, a single drop, on it %d times), each heap its own size and shape (%d of %d)"
		% [n, ctl_over, shapes.size(), n])
	# a name now and then, made up ([method DeskLook.tag_name]): the named desk's, drawn as every desk's is - the control,
	# the next salt, names it otherwise - and engraved on its tag; a quarter of desks named, each its own name
	var named := 0
	var names := {}
	for seed in 4000:
		var nm := DeskLook.tag_name(seed)
		named += int(not nm.is_empty())
		if not nm.is_empty():
			names[nm] = true
	var r_next := DeskLook._rng(NAMED_DESK, "tag name %d" % (DeskLook.TAG_NAME_SALT + 1))
	var next_name := TabletMedium.made_up(r_next) if r_next.randf() < DeskLook.TAG_NAMED else ""
	var engraved := ""
	var unnamed_seed := 0
	while not DeskLook.tag_name(unnamed_seed).is_empty():
		unnamed_seed += 1
	var bare := true
	for desk in [NAMED_DESK, unnamed_seed]:
		var dressed := DeskLook.dress(DeskLook.of(desk, {"things": ["dog_tag"], "mood": "lamplight"}), desk, LegalPad.DESK_Y)
		for c in (dressed["node"] as Node).get_children():
			var label := (c as Node).get_node_or_null("engraving") as Label3D
			if desk == NAMED_DESK and label != null:
				engraved = label.text
			elif desk != NAMED_DESK and (c as Node).has_meta("kind"):
				bare = bare and label == null
		(dressed["node"] as Node).free()
	var chosen := DeskLook.tag_name(NAMED_DESK)
	_check(chosen.sha256_text() == DESK_NAME and not engraved.is_empty() and engraved == chosen.to_upper()
		and next_name.sha256_text() != DESK_NAME and bare and named > 800 and named < 1200 and names.size() > named / 3,
		"desk %d's tag is engraved with the name chosen for it, drawn as every desk's is (the control, the next salt: %s), %d of 4000 desks named, %d names among them, an unnamed desk's tag bare"
		% [NAMED_DESK, "\"%s\"" % next_name if not next_name.is_empty() else "no name", named, names.size()])
	# a small outline cut at its own size ([method Props._extrude_face]): a notch in its edge left open - the control, cut
	# in meters, fills now and then
	var notched := 0
	var ctl_filled := 0
	var tried := 0
	for i in 40:
		var sz := 0.8 + 0.01 * float(i)
		for flip in [false, true]:
			var pts := _notched(4.0 * sz, 1.0 * sz, -1.4 * sz, 0.16 * sz, flip)
			var cm: Array = []
			for q in pts:
				cm.append([q.x, q.y])
			var safe := Props.sanitize({"things": [{"name": "n", "parts": [{"shape": "extrude", "material": "m", "points": cm, "height": 0.1}]}],
				"materials": {"m": {"kind": "metal", "color": "#888888"}}}, ["#888888"])
			var g = Props._extrude(safe["things"][0]["parts"][0])
			var flat := PackedVector2Array()
			for v in g.v:
				flat.append(Vector2((v as Vector3).x, (v as Vector3).z))
			var meters := PackedVector2Array()
			for q in pts:
				meters.append(q * 0.01)
			var notch := Vector2(-1.4 * sz, 0.0) * 0.01
			tried += 1
			notched += int(not _fills(flat, range(flat.size()), notch, 0.0016 * sz, flip))
			ctl_filled += int(_fills(meters, Array(Geometry2D.triangulate_polygon(meters)), notch, 0.0016 * sz, flip))
	_check(notched == tried and ctl_filled > 0,
		"a small outline with a notch in its edge is cut round it at its own size, on all %d - the control, cut in meters as it had been, filled %d"
		% [tried, ctl_filled])


## A strip [param w] by [param h] (centimeters) with a half round notch of [param nr] at [param nx] in its edge on z = 0
## - its mirror, wound back, when [param flip].
func _notched(w: float, h: float, nx: float, nr: float, flip: bool) -> PackedVector2Array:
	var pts: Array = [Vector2(w * 0.5, 0.0), Vector2(w * 0.5, h), Vector2(-w * 0.5, h), Vector2(-w * 0.5, 0.0)]
	for k in 5:
		var a := PI - PI * float(k) / 4.0
		pts.append(Vector2(nx + cos(a) * nr, sin(a) * nr))
	var out := PackedVector2Array()
	for q in pts:
		out.append(Vector2(q.x, -q.y) if flip else q)
	if flip:
		out.reverse()
	return out


## Whether any triangle of [param poly] (corners [param tris], three a triangle) lies in the notch of [param nr] at
## [param notch].
func _fills(poly: PackedVector2Array, tris: Array, notch: Vector2, nr: float, flip: bool) -> bool:
	for t in range(0, tris.size() - 2, 3):
		var a := poly[int(tris[t])]
		var b := poly[int(tris[t + 1])]
		var c := poly[int(tris[t + 2])]
		for ring in [0.3, 0.6, 0.85]:
			for k in 12:
				var u := PI * (float(k) + 0.5) / 12.0
				var q := notch + Vector2(cos(u), (-1.0 if flip else 1.0) * sin(u)) * nr * float(ring)
				if Geometry2D.point_is_inside_triangle(q, a, b, c):
					return true
	return false


## Ticked while the letter plays: the desk dressed again, the letter as it was.
## Words on the index cards ([method DeskLook._write]): see the header.
func _card_writing() -> void:
	print("-- words on the index cards")
	var things := ["pencil", "cards", "taper", "pillar", "tealights", "dog_tag"]
	var pad_px := LegalPad.H / DeskScript.PH
	var off := PI * 0.25 + DeskLook.CARD_TILT + 1e-3
	var m := DeskLook.CARD_MARGIN * 0.01
	var n := 0
	var written := 0
	var kept := 0
	var upright := 0
	var ctl_off := 0
	var portrait := 0
	var sticky := 0
	var fits := 0
	var at_pad := 0
	var as_pad := 0
	for seed in [NAMED_DESK] + range(1, 24):
		var plain := DeskLook.dress(DeskLook.of(seed, {"things": things, "mood": "lamplight"}), seed, LegalPad.DESK_Y)
		var l := DeskLook.of(seed, {"things": things, "mood": "lamplight", "card_text": CARD, "hand": "kalam"})
		var size := Vector3.ZERO
		for t in l["things"]:
			if String((t as Dictionary)["kind"]) == "cards":
				size = ((t["thing"] as Dictionary)["parts"] as Array)[0]["size"]
		var dressed := DeskLook.dress(l, seed, LegalPad.DESK_Y)
		# Nothing moves for it: every thing where it lay unwritten, the same stack
		kept += int(_layout(dressed["node"]) == _layout(plain["node"]))
		for c in (dressed["node"] as Node).get_children():
			if not ((c as Node).has_meta("kind") and String(c.get_meta("kind")) == "cards"):
				continue
			n += 1
			sticky += int(size.x < 8.0)
			var card := c as Node3D
			var on := card.get_node_or_null("card writing") as Node3D
			var label := on.get_node_or_null("writing") as Label3D if on != null else null
			if label == null or label.text != CARD:
				continue
			written += 1
			var q := roundi(on.rotation.y / (PI * 0.5))
			var xf := card.transform * on.transform * label.transform
			var d := xf.basis.x
			upright += int(absf(atan2(d.z, d.x)) <= off and xf.basis.z.normalized().y > 0.99)
			# The control: the writing square to its card, its quarter turns undone
			var square := Transform3D(on.transform.basis.rotated(Vector3.UP, -float(q) * PI * 0.5), on.position)
			var ds := (card.transform * square * label.transform).basis.x
			ctl_off += int(absf(atan2(ds.z, ds.x)) > off)
			portrait += posmod(q, 2)
			var room := (Vector2(size.x, size.z) if posmod(q, 2) == 0 else Vector2(size.z, size.x)) * 0.01 - Vector2.ONE * 2.0 * m
			var wide := label.width * label.pixel_size
			var tall := DeskLook.card_lines(label.font, CARD, label.width, label.font_size) \
				* (label.font.get_height(label.font_size) + label.line_spacing) * label.pixel_size
			fits += int(wide <= room.x + 1e-6 and tall <= room.y + 1e-6 and label.position.x >= -room.x * 0.5 - 1e-6
				and label.position.z >= -room.y * 0.5 - 1e-6 and on.position.y > size.y * 0.01)
			var advance := label.font.get_height(label.font_size) + label.line_spacing
			as_pad += int(label.font_size == int(Handwriting.size_px("kalam")) and label.pixel_size <= pad_px + 1e-9
				and absf(advance - DeskScript.RULE) < 1e-3)
			at_pad += int(absf(label.pixel_size - pad_px) < 1e-9)
		var other := DeskLook.dress(DeskLook.of(seed + 100, {"things": things, "mood": "lamplight"}), seed + 100, LegalPad.DESK_Y)
		# (the control: another desk's layout is another - the comparison sees a difference)
		kept -= int(_layout(other["node"]) == _layout(plain["node"]))
		for d in [plain, dressed, other]:
			((d as Dictionary)["node"] as Node).free()
	_check(kept == 24, "nothing on the desk moves for the cards' words: every thing on all %d desks lies where it lay unwritten (the control: another desk's lies otherwise)" % kept)
	_check(n == 24 and written == n and upright == n and ctl_off > 0 and portrait > 0 and portrait < n and sticky > 0
		and fits == n and as_pad == n and at_pad > 0,
		"the words on the top card of every desk (%d of %d), however it lies - %d of them sticky notes - the nearest way up to the writer's seat (%d), down %d cards lying along the pad, across the rest - the control, the writing square to its card, more than half a quarter turn off on %d - inside the margin (%d), in the pad's hand and rules (%d), at its size where the card has room (%d)"
		% [written, n, sticky, upright, portrait, ctl_off, fits, as_pad, at_pad])
	# More words than the pad's size holds on a card come smaller, and still fit - the control, as the pad is written, overruns it
	var many := "\n".join([CARD, CARD, CARD])
	var l := DeskLook.of(NAMED_DESK, {"things": ["cards"], "mood": "lamplight", "card_text": many, "hand": "kalam"})
	var size: Vector3 = ((l["things"][0]["thing"] as Dictionary)["parts"] as Array)[0]["size"]
	var dressed := DeskLook.dress(l, NAMED_DESK, LegalPad.DESK_Y)
	var label: Label3D = null
	for c in (dressed["node"] as Node).get_children():
		if label == null:
			label = (c as Node).get_node_or_null("card writing/writing") as Label3D
	var closer := -1.0
	var tall := INF
	var ctl_tall := 0.0
	var room := Vector2.ZERO
	if label != null:
		var q := roundi((label.get_parent() as Node3D).rotation.y / (PI * 0.5))
		room = (Vector2(size.x, size.z) if posmod(q, 2) == 0 else Vector2(size.z, size.x)) * 0.01 - Vector2.ONE * 2.0 * m
		closer = label.pixel_size / pad_px
		tall = DeskLook.card_lines(label.font, many, label.width, label.font_size) * DeskScript.RULE * label.pixel_size
		ctl_tall = DeskLook.card_lines(label.font, many, room.x / pad_px, label.font_size) * DeskScript.RULE * pad_px
	(dressed["node"] as Node).free()
	_check(closer > 0.0 and closer < 1.0 and tall <= room.y + 1e-6 and ctl_tall > room.y,
		"twelve lines on a card come smaller (%.2f of the pad's size) and fit its %.1f cm (%.1f) - the control, as the pad is written, %.1f"
		% [closer, room.y * 100.0, tall * 100.0, ctl_tall * 100.0])


## Where each thing on a dressed desk lies: [its kind or name, its transform], in order.
func _layout(desk: Node) -> Array:
	var out: Array = []
	for c in desk.get_children():
		out.append([String(c.get_meta("kind")) if c.has_meta("kind") else String(c.name), (c as Node3D).transform])
	return out


func _redressed() -> void:
	print("-- the desk dressed again while it plays")
	var vp := SubViewport.new()
	vp.size = Vector2i(320, 180)
	root.add_child(vp)
	var m := LetterMedium.new()
	var feed := ShowFeed.new()
	m.feed = feed
	m.mount(vp)
	var subs_script := GDScript.new()
	subs_script.source_code = "extends Node\nvar document := {}\nvar words := []\nfunc now() -> float:\n\treturn 0.0\n"
	subs_script.reload()
	var subs = subs_script.new()
	subs.document = {"source": "Dear Pen,\n\nThe tag is on the desk.\n", "letter": {"seed": 5, "things": ["pencil"], "mood": "lamplight"}}
	m._subs = subs
	m._ensure_doc()
	var actions: Array = m._actions
	var desk_before: Node3D = m._desk
	(subs.document["letter"] as Dictionary)["things"] = ["pencil", "dog_tag"]
	m._ensure_doc()
	var has_tag := false
	for c in m._desk.get_children():
		has_tag = has_tag or ((c as Node).has_meta("kind") and String(c.get_meta("kind")) == "dog_tag")
	var redressed := m._desk != desk_before and has_tag and is_same(m._actions, actions)
	(subs.document["letter"] as Dictionary)["things"] = ["pencil", "cards", "dog_tag"]
	(subs.document["letter"] as Dictionary)["card_text"] = "Back soon."
	m._ensure_doc()
	var wrote := ""
	for c in m._desk.get_children():
		var w := (c as Node).get_node_or_null("card writing/writing") as Label3D
		if w != null:
			wrote = w.text
	redressed = redressed and wrote == "Back soon." and is_same(m._actions, actions)
	var paper: Color = m.look["paper"]
	var desk_mid: Node3D = m._desk
	(subs.document["letter"] as Dictionary)["desk"] = 9
	m._ensure_doc()
	var other_desk: bool = m._desk != desk_mid and m._seed == 9 and m._hand == 5 and m.look["paper"] != paper \
		and is_same(m._actions, actions)
	(subs.document["letter"] as Dictionary)["hand"] = "caveat"
	m._ensure_doc()
	_check(redressed and other_desk and not is_same(m._actions, actions),
		"a thing ticked, words on the cards or another desk's number while it plays are on the desk at once, the letter as it was - the control, another hand, loads the letter again")
	m._subs = null
	vp.remove_child(m)
	m.free()
	feed.free()
	(subs as Node).free()
	vp.queue_free()


func _medium(text: String, words: Array) -> LetterMedium:
	var feed := ShowFeed.new()
	feed.outro_hold = 4.0
	feed.intro_hold = 1.0
	var m := LetterMedium.new()
	m.feed = feed
	m._pad = LegalPad.new()
	m.load_letter(text, {"seed": 1})
	m._now = 0.0
	if not words.is_empty():
		m.take_words(words)
	return m


## A page is turned with the voice waiting where it ends on a mark, and a sentence it breaks is finished first.
func _turn_waits() -> void:
	print("-- a page turned on a mark, and one inside a sentence")
	var marked := 0
	var broken := 0
	var rested_marked := INF
	var rested_broken := 0.0
	var next_rest := INF
	var nexts: Array = []          # [the letter, the next sentence's first word after a turn that broke one]
	for lengths in [[7, 11, 9, 13, 8, 10], [6, 9, 12, 8], [10, 7, 13, 9], [5, 8, 11, 14, 7], [9, 9, 10, 12], [8, 13, 6, 11, 9]]:
		var text := _prose(24, lengths)
		var parsed := LetterScript.parse(text)
		var rests := LetterMedium.rests_of(parsed)
		var acts: Array = parsed["actions"]
		for i in acts.size():
			var a: Dictionary = acts[i]
			if String(a["kind"]) != "pad-text" or not bool(a.get("turn", false)) or bool(a.get("para", false)) or i == 0:
				continue
			var k0 := int(a["after"])
			var prev := String((acts[i - 1] as Dictionary).get("text", "")).strip_edges()
			if RegEx.create_from_string(LetterScript.PAUSE_END).search(prev) != null:
				marked += 1
				rested_marked = minf(rested_marked, rests[k0])
				continue
			broken += 1
			rested_broken = maxf(rested_broken, rests[k0])
			var j := i
			var ks := -1
			while ks < 0 and j < acts.size() and String((acts[j] as Dictionary)["kind"]) == "pad-text" \
					and (j == i or not bool((acts[j] as Dictionary).get("para", false))):
				var said := String((acts[j] as Dictionary)["text"]).split(" ", false)
				for w in said.size() - 1:
					if RegEx.create_from_string(LetterScript.SENTENCE_END).search(said[w]) != null:
						ks = int((acts[j] as Dictionary)["after"]) + w + 1
						break
				j += 1
			if ks > k0:
				next_rest = minf(next_rest, rests[ks])
				nexts.append([text, ks, rests[ks]])
	_check(marked > 0 and broken > 0 and rested_marked >= LetterScript.TURN_REST - 0.05 and rested_broken == 0.0,
		"a page turned inside a paragraph after a mark is rested for (%d, %.2f s at the least), one that breaks a sentence is read on through (%d)"
		% [marked, rested_marked, broken])
	_check(not nexts.is_empty() and next_rest > 0.3,
		"and after one that breaks a sentence, the voice waits at the next (%.2f s at the least)" % next_rest)
	# ...and the pen is caught up there: its first word on the page before it is said - without that rest, behind
	var text0 := String(nexts[0][0])
	var ks0 := int(nexts[0][1])
	var words := _voiced(LetterScript.parse(text0))
	var m := _medium(text0, words)
	var late := _late(m, words, ks0)
	m.free()
	var hurried: Array = []
	for w in words.size():
		var d: Dictionary = (words[w] as Dictionary).duplicate()
		if w >= ks0:
			d["t0"] = float(d["t0"]) - float(nexts[0][2])
			d["t1"] = float(d["t1"]) - float(nexts[0][2])
		hurried.append(d)
	var mh := _medium(text0, hurried)
	var late_h := _late(mh, hurried, ks0)
	mh.free()
	_check(late < 0.05 and late_h > 0.3,
		"the next sentence's first word is on the page %.2f s before it is said - the control, the voice without that rest, says it %.2f s before it is written"
		% [-late, late_h])


## How far under the level the screen shows a pen's body along [param body] (degrees; less than none over it), from a
## camera on the writer's side of the desk pitched [param pitch] degrees down.
static func _screen_down(body: Vector3, pitch: float) -> float:
	var p := deg_to_rad(pitch)
	var up := Vector3(0.0, cos(p), -sin(p))
	return rad_to_deg(atan2(-body.dot(up), body.x))


## How long after spoken word [param k] is said it is on [param m]'s page (seconds; less than 0 when it is there first).
static func _late(m: LetterMedium, words: Array, k: int) -> float:
	for i in m._actions.size():
		var a: Dictionary = m._actions[i]
		if String(a["kind"]) == "pad-text" and int(a["after"]) <= k and k < int(a["after"]) + int(a.get("span", 0)):
			return _written_at(m, i, k - int(a["after"])) - float((words[k] as Dictionary)["t0"])
	return INF


## A line runs on into the voice's pause after it.
func _line_breaks() -> void:
	print("-- a line runs on into the voice's pause")
	var text := _prose(12, [7, 11, 9, 13, 8, 10])
	var parsed := LetterScript.parse(text)
	var words := _voiced(parsed)
	var m := _medium(text, words)
	var stood := 0
	var was := 0
	var worst := 0.0
	for i in m._actions.size() - 1:
		var a: Dictionary = m._actions[i]
		var b: Dictionary = m._actions[i + 1]
		if String(a["kind"]) != "pad-text" or String(b["kind"]) != "pad-text" or bool(b.get("para", false)) or bool(b.get("turn", false)):
			continue
		var start := float(m._plan[i]["start"])
		var idle := float(m._plan[i + 1]["start"]) - float(m._plan[i]["end"]) - m._way(i, i + 1)
		var own: float = (m._ahead_times(a, start)[1] as PackedFloat32Array)[int(a["span"]) - 1]
		own = clampf(own, start + float(a["write"]) / LetterScript.QUICKEST, start + float(a["write"]) / DeskScript.MIN_PACE)
		worst = maxf(worst, idle)
		stood += int(idle > 0.15)
		was += int(float(m._plan[i + 1]["start"]) - own - m._way(i, i + 1) > 0.3)
	m.free()
	_check(stood == 0 and was >= 2,
		"read by a voice that pauses at each sentence's end, no line leaves the pen standing at its end (%.2f s at the most) - the control, each ended as the voice ends the word two before its last, stands at %d"
		% [worst, was])


## The camera lets go before a turn once, its words arriving a sentence at a time.
func _let_go() -> void:
	print("-- the camera lets go before a turn once")
	var text := "Dear Friend,\n\n" + _prose(2, [9, 7, 12]) + "\n<!-- hesitation: 1.5 -->\n\n<!-- image (full): an empty room at night -->\n\n" \
		+ _prose(2, [8, 12, 10]) + "\n<!-- /image -->\n\n" + _prose(8, [10, 7, 13, 9])
	var parsed := LetterScript.parse(text)
	var words := _voiced(parsed)
	var m := _medium(text, [])
	var ti := -1
	for i in m._actions.size():
		if bool((m._actions[i] as Dictionary).get("turn", false)):
			ti = i
			break
	var handed := 0
	var t := 0.0
	var rises := 0
	var old_rises := 0
	var k_was := INF
	var old_was := INF
	var letting := false
	var old_letting := false
	var turned := INF
	while t < turned:
		m._now = t
		var n := handed
		while n < words.size() and float((words[n] as Dictionary)["t0"]) <= t + 3.0:
			var sn := int((words[n] as Dictionary)["sentence"])
			while n < words.size() and int((words[n] as Dictionary)["sentence"]) == sn:
				n += 1
		if n != handed:
			handed = n
			m.take_words(words.slice(0, n))
		var ta := float(m._plan[ti]["turn_at"])
		if ta < INF and t >= ta:
			turned = t
			break
		var k := m._arc()
		# the control: the turn as the arc had guessed it, the desk's steady pace from the last word heard
		var opening := m._opening()
		var guess := ta if ta < INF else m._guess(int((m._actions[ti] as Dictionary)["after"]), false) - DeskScript.TURN
		var opened := opening if opening < INF else 1.0
		var old := minf(smoothstep(opened + LetterMedium.ARRIVE, opened + LetterMedium.ARRIVE + LetterMedium.ARC_IN, t),
			1.0 - smoothstep(guess - LetterMedium.OUT_BEFORE - LetterMedium.ARC_OUT, guess - LetterMedium.OUT_BEFORE, t))
		if letting and k > k_was + 0.01:
			rises += 1
		if old_letting and old > old_was + 0.01:
			old_rises += 1
		letting = letting or (k_was > 0.99 and k < k_was - 0.001)
		old_letting = old_letting or (old_was > 0.99 and old < old_was - 0.001)
		k_was = k
		old_was = old
		t += 1.0 / 30.0
	m.free()
	_check(turned < INF and letting and rises == 0 and old_rises > 0,
		"its words arriving a sentence at a time, the camera lets go before the turn once and never comes back in - the control, the turn guessed at the desk's steady pace, comes back in %d times"
		% old_rises)


func _struck() -> void:
	print("-- words struck inside a line")
	var marked := "It looks like <!-- struck: morning --> mourning, and it is.\n\nYours.\n"
	var plain := "It looks like morning mourning, and it is.\n\nYours.\n"
	var d := LetterScript.parse(marked, 3)
	var c := LetterScript.parse(plain, 3)
	var lines := _of(d, "pad-text")
	var strikes := _of(d, "strike")
	var said := String(d["speakable"])
	var rest := RegEx.create_from_string("morning\\s*<!-- action-hold: ([0-9.]+) -->\\s*mourning").search(said)
	var first: Dictionary = lines[0]
	var beside: Dictionary = lines[1] if lines.size() > 1 else {}
	_check(lines.size() == 3 and String(first["text"]).ends_with("morning") and bool(beside.get("cont", false))
		and is_equal_approx((beside["at"] as Vector2).y, (first["at"] as Vector2).y)
		and (d["spoken"] as PackedStringArray).has("morning"),
		"the struck words are written and said, and the words after the mark go on beside them on the same rule")
	_check(strikes.size() == 1 and int(strikes[0]["of"]) == int(first["i"])
		and float(strikes[0]["x1"]) < (beside["at"] as Vector2).x - DeskScript.TEXT_X
		and float(strikes[0]["x0"]) > float(first["w"]) * 0.5,
		"a strike crosses the struck words alone (%.0f to %.0f px of a %.0f px line)" % [float(strikes[0]["x0"]), float(strikes[0]["x1"]), float(first["w"])])
	var no_rest := RegEx.create_from_string("morning\\s*<!-- action-hold").search(String(c["speakable"]))
	_check(rest != null and float(rest.get_string(1)) >= LetterScript.DECIDE + LetterScript.STRIKE
		and _of(c, "strike").is_empty() and _of(c, "pad-text").size() == 2 and no_rest == null,
		"the voice rests %.2f s between them, the writer deciding; with no mark, one line and no strike nor rest (the control)"
		% (float(rest.get_string(1)) if rest != null else 0.0))
	var long := LetterScript.parse("I wanted to say <!-- struck: that I was sorry about all of it, every single part of it --> nothing at all.\n", 3)
	_check(_of(long, "strike").size() == 2 and int(_of(long, "strike")[0]["of"]) != int(_of(long, "strike")[1]["of"]),
		"a struck run over two lines is crossed out on each")
	# written and never said: the correction written beside the struck words and not said, the sentence's stop kept for the
	# voice, which rests while it is written
	var quiet := LetterScript.parse("It looks like <!-- struck: morning --> <!-- unspoken: mourning. -->\n\nYours.\n", 3)
	var ql := _of(quiet, "pad-text")
	var qsaid := String(quiet["speakable"])
	var qrest := RegEx.create_from_string("like morning\\.\\s*<!-- action-hold: ([0-9.]+) -->\\s*Yours").search(qsaid)
	_check(String(ql[1]["text"]) == "mourning." and int(ql[1]["span"]) == 0 and bool(ql[1].get("cont", false))
		and not (quiet["spoken"] as PackedStringArray).has("mourning") and (d["spoken"] as PackedStringArray).has("mourning")
		and qrest != null and float(qrest.get_string(1)) >= LetterScript.DECIDE + LetterScript.STRIKE + LetterScript.LEAD,
		"words written and never said: the correction written beside the struck words, \"morning.\" said, the voice resting %.2f s while it is written - plain, it is said (the control)"
		% (float(qrest.get_string(1)) if qrest != null else 0.0))
	var full := LetterScript.parse("From where you are, I think it looks like <!-- struck: morning --> mourning, and it is.\n", 3)
	var fl := _of(full, "pad-text")
	_check(fl.size() == 2 and String(fl[0]["text"]).ends_with("morning") and not bool(fl[1].get("cont", false))
		and (fl[1]["at"] as Vector2).x == DeskScript.TEXT_X,
		"words that will not fit beside the struck ones start the next line, at the margin")
	# on the desk's clock: the strike after the deciding, the words beside it after the strike, on the page before said
	var feed := ShowFeed.new()
	feed.outro_hold = 4.0
	feed.intro_hold = 1.0
	var m := LetterMedium.new()
	m.feed = feed
	m._pad = LegalPad.new()
	m.load_letter(marked, {"seed": 3})
	var words := DeskScript.rehearsal(d, 0.42, 0.35, 1.0)
	m._now = 0.0
	m.take_words(words)
	var si := -1
	var bi := -1
	for i in m._actions.size():
		if String((m._actions[i] as Dictionary)["kind"]) == "strike":
			si = i
		elif bool((m._actions[i] as Dictionary).get("cont", false)):
			bi = i
	var k := -1
	for i in words.size():
		if String((words[i] as Dictionary)["text"]) == "morning":
			k = i
	var said_end := float((words[k] as Dictionary)["t1"])
	var free := maxf(float(m._plan[int(m._actions[si]["of"])]["end"]), said_end)
	var waited := float(m._plan[si]["start"]) - free
	var replaced := float(m._plan[bi]["start"])
	var said_after := float((words[k + 1] as Dictionary)["t0"])
	_check(waited >= LetterScript.DECIDE - 0.01 and replaced >= float(m._plan[si]["end"]) - 0.01,
		"the strike begins %.2f s after the struck word is said and written, the words beside it once it is made" % waited)
	m._now = said_after
	_check(m._written(bi) > 0.0 and said_after > float(m._plan[si]["end"]),
		"and the voice goes on with them once they are being written (%.0f%% on the page)" % (m._written(bi) * 100.0))
	m.free()
	feed.free()


func _pens() -> void:
	print("-- a pen each ink")
	var body := "Dear Pen,\n\nI write in the desk's ink, then <!-- color: red --> in red.\n\n*A thought.*\n\nStill red.\n\n<!-- color: blue -->\n\n*Another.*\n\nBlue now. It looks like <!-- struck: morning --> <!-- color: default --> mourning.\n"
	var d := LetterScript.parse(body, 3)
	var none := LetterScript.parse("Dear Pen,\n\nAll in one ink.\n", 3)
	_check(Array(d["pens"]) == ["", "red", "blue"] and Array(none["pens"]) == [""] and _of(none, "swap").is_empty(),
		"the pens are scanned first, the desk's own and each ink in the order it is first asked for - one with no color marks (the control)")
	var lines := _of(d, "pad-text")
	var swaps := _of(d, "swap")
	var said := String(d["speakable"])
	var at_red := RegEx.create_from_string("then\\s*<!-- action-hold: ([0-9.]+) -->\\s*in red").search(said)
	_check(String(lines[1]["text"]).ends_with("then") and String(lines[1].get("ink", "")) == ""
		and bool(lines[2].get("cont", false)) and String(lines[2]["ink"]) == "red"
		and int(swaps[0]["from"]) == 0 and int(swaps[0]["pen"]) == 1 and int(swaps[0]["i"]) == int(lines[1]["i"]) + 1
		and at_red != null and float(at_red.get_string(1)) >= LetterScript.SWAP,
		"a change of ink inside a line stops it there: the pen changed, the voice resting %.2f s, the rest written beside it in the new ink"
		% (float(at_red.get_string(1)) if at_red != null else 0.0))
	var blue_line: Dictionary = lines.filter(func(l: Dictionary) -> bool: return String(l["text"]).begins_with("Blue"))[0]
	_check(int(swaps[1]["pen"]) == 2 and int(swaps[1]["i"]) == int(blue_line["i"]) - 1 and String(blue_line["ink"]) == "blue",
		"a change on a line of its own waits for the next thing written - not the thought between")
	var strike: Dictionary = _of(d, "strike")[0]
	_check(String(strike["ink"]) == "blue" and int(swaps[2]["i"]) == int(strike["i"]) + 1 and int(swaps[2]["pen"]) == 0
		and String(lines.back()["ink"]) == "",
		"words struck and then a change of ink: crossed out with the pen in hand, the correction in the other")
	# A change inside a word (the chapter's closing stop in red): the stop against the word, no space, said with it
	var glued := LetterScript.parse("Godspeed to you, Pen<!-- color: red -->.<!-- color: default -->\n\nInk\n", 3)
	var spaced := LetterScript.parse("Godspeed to you, Pen <!-- color: red --> . <!-- color: default -->\n\nInk\n", 3)
	var gl := _of(glued, "pad-text")
	var sl := _of(spaced, "pad-text")
	var gsaid := String(glued["speakable"])
	var one_rest := RegEx.create_from_string("Pen\\.\\s*<!-- action-hold: ([0-9.]+) -->\\s*Ink").search(gsaid)
	_check(gl.size() == 3 and String(gl[1]["text"]) == "." and String(gl[1]["ink"]) == "red" and bool(gl[1].get("cont", false))
		and float(gl[1]["cont_x"]) < float(sl[1]["cont_x"]) - 5.0 and one_rest != null
		and float(one_rest.get_string(1)) >= 2.0 * LetterScript.SWAP,
		"a change of ink inside a word: the stop written in red against it (%.0f px on, %.0f with a space - the control), \"Pen.\" said whole and one rest after it"
		% [float(gl[1]["cont_x"]), float(sl[1]["cont_x"])])
	var feed := ShowFeed.new()
	feed.outro_hold = 4.0
	feed.intro_hold = 1.0
	var m := LetterMedium.new()
	m.feed = feed
	m._pad = LegalPad.new()
	var desk3 := Node3D.new()
	root.add_child(desk3)
	m._pen = Node3D.new()
	desk3.add_child(m._pen)
	m._trim = StandardMaterial3D.new()
	m.load_letter(body, {"seed": 3})
	var words := DeskScript.rehearsal(d, 0.42, 0.35, 1.0)
	m._now = 0.0
	m.take_words(words)
	var rests: Array = []
	for k in 3:
		rests.append(DeskLook.pen_rest(m.look, LegalPad.DESK_Y, k))
	var bodies_ok: bool = m._more_pens.size() == 2
	for k in m._more_pens.size():
		var mesh: MeshInstance3D = (m._more_pens[k] as Node3D).get_child(1)
		var want := NotebookLayout.ink_color(String(d["pens"][k + 1])).darkened(0.1)
		bodies_ok = bodies_ok and (mesh.material_override as StandardMaterial3D).albedo_color.is_equal_approx(want)
	var apart: bool = (rests[1]["nib"] as Vector3).x > (rests[0]["nib"] as Vector3).x + 0.015 \
		and (rests[2]["nib"] as Vector3).x > (rests[1]["nib"] as Vector3).x + 0.015
	var one_pen: Dictionary = m.look.duplicate()
	one_pen["pens"] = 1
	_check(bodies_ok and apart and DeskLook._pen_taken(m.look, LegalPad.DESK_Y).size() == 3 * DeskLook._pen_taken(one_pen, LegalPad.DESK_Y).size(),
		"a pen for each ink past the desk's own, its body its ink, each lying further out from the pad - and the desk's things kept off them all")
	var si := int(swaps[0]["i"])
	var start := float(m._plan[si]["start"])
	m._now = start + LetterScript.SWAP_DOWN * 0.5
	var down_hand := m._pen_in_hand()
	m._place_pen()
	var old_moving := not (m._pen as Node3D).global_transform.is_equal_approx(m._lying(0))
	var new_lying := (m._more_pens[0] as Node3D).global_transform.is_equal_approx(m._lying(1))
	m._now = float(m._plan[si]["end"]) + 0.6
	m._place_pen()
	var after_hand := m._pen_in_hand()
	var old_down := (m._pen as Node3D).global_transform.is_equal_approx(m._lying(0))
	var new_up := not (m._more_pens[0] as Node3D).global_transform.is_equal_approx(m._lying(1))
	_check(down_hand == 0 and old_moving and new_lying and after_hand == 1 and old_down and new_up,
		"a change of pen: the one in hand is put down at its place, then the other picked up - it writes, the first lies where it was put")
	var red_i := int(lines[2]["i"])
	m._now = float(m._plan[red_i]["end"]) + 0.1
	var red_ink: Array = m._ink_of(red_i)
	var plain_ink: Array = m._ink_of(int(lines[0]["i"]))
	_check(not red_ink.is_empty() and (red_ink[0] as Dictionary).get("color", Color.BLACK) == NotebookLayout.ink_color("red")
		and not (plain_ink[0] as Dictionary).has("color"),
		"the red line's strokes are drawn red, a line in the desk's own ink as the desk draws it (the control)")
	desk3.queue_free()
	m.free()
	feed.free()


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
	var text := "Dear Friend,\n\n<!-- sketch: a row of strokes -->\n\n*One, two.*\n\nAnd that was all of them, in the end.\n"
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
	# Drawn alone, no words over it: the voice waits DRAW_ALONE, not its ink at the hand's pace (the control)
	var alone_text := text.replace("*One, two.*\n\n", "")
	var alone := LetterScript.parse(alone_text, 3, {key: svg}, lengths, records)
	var am := RegEx.create_from_string("action-hold: ([0-9.]+) -->\\s*And that").search(String(alone["speakable"]))
	var alone_rest := float(am.get_string(1)) if am != null else 0.0
	var alone_draw: Array = _of(alone, "draw")
	_check(alone_draw.size() == 1 and int(alone_draw[0]["span"]) == 0
		and is_equal_approx(LetterScript.drawn_alone(ink), LetterScript.DRAW_ALONE)
		and alone_rest >= LetterScript.DRAW_ALONE and alone_rest < LetterScript.DRAW_ALONE + LetterScript.LEAD + 1.5
		and ink > alone_rest + 10.0 and is_equal_approx(LetterScript.drawn_alone(2.0), 2.0),
		"a sketch of %.0f s of ink drawn alone: the voice waits %.1f s for it; at the hand's pace, %.0f (the control) - a small one at the hand's pace, as before"
		% [ink, alone_rest, ink])
	var heard_alone := DeskScript.rehearsal(alone, 0.42, 0.35, 1.0)
	var ma := LetterMedium.new()
	ma.feed = feed
	ma._pad = LegalPad.new()
	ma.load_letter(alone_text, {"seed": 3, "svgs": {key: svg}, "ink": {"items": [_dense_record(id, 80)]}})
	var ai := -1
	for i in ma._actions.size():
		if String((ma._actions[i] as Dictionary)["kind"]) == "draw":
			ai = i
	var before_it := int((ma._actions[ai] as Dictionary)["after"])
	ma.take_words(heard_alone.slice(0, before_it))
	var a_begun := float(ma._plan[ai]["start"])
	var a_done := float(ma._plan[ai]["end"])
	ma._now = a_begun + (a_done - a_begun) * 0.25
	var u_mid := ma._written(ai)
	ma.take_words(heard_alone)
	var a_again := float(ma._plan[ai]["end"])
	var floor_was := ma._now + (1.0 - u_mid) * ink / DeskScript.MAX_PACE
	_check(absf(a_done - a_begun - LetterScript.DRAW_ALONE) < 0.05 and absf(a_again - a_done) < 0.05
		and floor_was > a_done + 0.8,
		"at the desk it is drawn alone in %.1f s (its ink at the hand's pace, %.0f - the control); the plan made again a quarter of the way in, it ends %.2f s later (held to the desk's quickest, %.1f - the control)"
		% [a_done - a_begun, ink, a_again - a_done, floor_was - a_done])
	ma.free()
	# told its time: `<!-- sketch (10s): ... -->` is drawn in that, the voice waiting it out - drawn alone, or over a thought,
	# which then rests up to it
	var told := 10.0
	var timed_text := alone_text.replace("<!-- sketch:", "<!-- sketch (10s):")
	var timed := LetterScript.parse(timed_text, 3, {key: svg}, lengths, records)
	var tm := RegEx.create_from_string("action-hold: ([0-9.]+) -->\\s*And that").search(String(timed["speakable"]))
	var timed_rest := float(tm.get_string(1)) if tm != null else 0.0
	var over_text := text.replace("<!-- sketch:", "<!-- sketch (10s):")
	var over := LetterScript.parse(over_text, 3, {key: svg}, lengths, records)
	var om := RegEx.create_from_string("action-hold: ([0-9.]+) -->\\s*And that").search(String(over["speakable"]))
	var over_rest := float(om.get_string(1)) if om != null else 0.0
	_check(is_equal_approx(LetterScript.drawn_alone(ink, told), told) and is_equal_approx(LetterScript.drawn_alone(2.0, told), 2.0)
		and timed_rest >= told and timed_rest < told + LetterScript.LEAD + 1.5 and alone_rest < told - 3.0
		and over_rest >= told - words - 0.1 and over_rest > rest + 3.0,
		"told 10 s, a sketch of %.0f s of ink drawn alone: the voice waits %.1f s (untimed, %.1f - the control); over a thought, %.1f after it (untimed, %.1f - the control); a small one at the hand's pace"
		% [ink, timed_rest, alone_rest, over_rest, rest])
	for t in [timed_text, over_text]:
		var tp := LetterScript.parse(t, 3, {key: svg}, lengths, records)
		var mt := LetterMedium.new()
		mt.feed = feed
		mt._pad = LegalPad.new()
		mt.load_letter(t, {"seed": 3, "svgs": {key: svg}, "ink": {"items": [_dense_record(id, 80)]}})
		mt.take_words(DeskScript.rehearsal(tp, 0.42, 0.35, 1.0))
		var ti := -1
		for i in mt._actions.size():
			if String((mt._actions[i] as Dictionary)["kind"]) == "draw":
				ti = i
		var took := float(mt._plan[ti]["end"]) - float(mt._plan[ti]["start"])
		_check(absf(took - told) < 0.6,
			"at the desk a sketch told 10 s is drawn in %.1f s%s (untimed alone, %.1f - the control)"
			% [took, " over a thought" if t == over_text else "", a_done - a_begun])
		mt.free()

