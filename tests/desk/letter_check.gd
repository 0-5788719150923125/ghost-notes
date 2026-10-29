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
## - A POINT LINGERS ([constant LetterScript.POINT_LINGER]; the user, of "That one's me." at the dot: "the camera moves
##   there quickly, and the pen retreats immediately, and the camera moves again, and it feels jarring"): the voice
##   rests after a point's sentence in a thought, the pen held on what it points at and the camera framed on it
##   through the rest, not taken off to what comes next before it is done - where after a thought with no point the
##   voice goes straight on (the control); a point at the camera holds the pen up through its rest, put back as it ends.
## - PICTURES DISSOLVE INTO ONE ANOTHER ([method LetterMedium.pictures_at]; the user: "blend from one picture into a
##   second one, or a third one, directly without ever seeing the page again ... each with different
##   panning/zooming behavior"): an image mark before the last one's close, or straight after it, comes up over
##   it - the voice reads on with no rest there, the one under held whole while the next comes in, so nothing of
##   the page shows from the run's first picture being up to its last going - where a picture after a written
##   line comes up from the desk, the voice resting for the page first (the control); the passage under a
##   dissolve is captioned; every fade is [constant LetterScript.IMAGE_FADE] ("A 2 or 3 second fade might look
##   better"); and no picture moves as the one before it did, nor drifts within a quarter turn of its way.
## - A HESITATION BEFORE A PICTURE IS THE WRITER'S FIRST (2026-10-28, the user, of Secular Haze's `<!-- hesitation: 3 -->`
##   before its first picture: "the picture that follows is immediately displayed - not waiting for the hesitation at
##   all"): the desk is seen through it and the picture comes up as the pen is taken up again; a dissolve with one before
##   the next picture holds the one before whole through it; a live reading not yet past it keeps the desk - with no
##   hesitation mark and the same voice, the picture comes up in the pause each time (the control).
##
## - A DENSE SKETCH IS DASHED OFF ([method LetterScript.draw_pace]; the user, of the chapter's tree of dots: the text
##   "sort of gets frozen for a few seconds ... with the pen not moving" - the voice had waited 7.5 s for it): a
##   drawing of far more ink than its two words leave time for is done soon after them, the voice resting only that
##   long - the control, the desk's quickest pen, would have rested it several times as long - and the pen goes
##   from its last mark to the next line with no pause; one with room is drawn no quicker than before.
## - THE PEN IS PICKED UP FROM THE DESK ([method LetterMedium._pick_up_pose]; 2026-10-28, the user: "the pen starts
##   floating in the air already ... started from a resting place upon the table, to the right of the paper, and ...
##   gently picked it up at the beginning, after the intro-blur"): through the intro and its focus pull it lies level on
##   the desk beside the pad's right edge, where it rests on its widest, its top toward the writer; it is picked up only once the intro's blur has
##   lifted and the name is gone, and is over the first stroke as the line begins; on the way it moves on, a frame at a
##   time, no further than a hand would - the control, the desk's own pen hovering over the first stroke, is a jump of
##   many centimeters from where it lies - and never goes into the desk or the pad. AS IT WRITES IT LEANS TO THE RIGHT AND
##   A LITTLE DOWN on the screen ([constant LetterMedium.LEAN]; the user: "it would be more common for the top of the pen
##   to point to the bottom-right (though gently, trending closer to pure right ...)"), close and wide, whatever the
##   hand's sway - the control, the Proof desk's lean, points to the top right. NOTHING ELSE LIES THERE ([method
##   DeskLook.pen_rest]): a thing is never set down on the pen - the control, the same draws with its place not taken,
##   lands on it.
## - A PAGE IS TURNED WITH THE VOICE WAITING WHERE IT ENDS ON A MARK, AND A SENTENCE IT BREAKS IS FINISHED FIRST ([method
##   LetterScript._voice_text]; 2026-10-28, the user: "if a page ended with punctuation, we can hold the voice until after
##   the page turn. However if a sentence was broken by a page turn, we should just finish the thought/voice - and then we
##   should wait for the pen to catch up, before proceeding with the next sentence"): over a letter of many sentences, a
##   page turned inside a paragraph after a mark is rested for, at least the turn's own rest, and one that breaks a
##   sentence is not (the two sides of one rule); the voice then waits at the next sentence, and its first word is on the
##   page before it is said - the control, the same voice without that rest, says it with the pen behind.
## - A LINE RUNS ON INTO THE VOICE'S PAUSE AFTER IT ([method LetterMedium._runs_on_to]; the user, of "my line of work. It
##   is | called": "the pen just stops moving at "it is", for a second, before it moves to the new line"): read by a voice
##   that pauses at each sentence's end, no line of a paragraph leaves the pen standing at its end - the control, each
##   line ended as the voice ends the word two before its last, stands at several.
## - THE CAMERA LETS GO BEFORE A TURN ONCE ([method LetterMedium._letting_go]; the user, of the end of Secular Haze's first
##   page: "it bounces forward and back a couple times, right at the very last few sentences"): its words arriving a
##   sentence at a time, past a hesitation and a picture's passage, the camera never comes back in once it has begun to
##   let go before the turn - the control, the turn the arc had guessed at the desk's steady pace, comes back in.
## - WHAT IS ON THE DESK AND ITS LIGHT ARE CHOSEN, THE SEED ONLY PLACING THEM ([method DeskLook.of]'s picks; 2026-10-29,
##   the user: "when we change the seed - the only thing being changed would be the placement of objects, and
##   textures"): chosen, every seed has the same things and light, each looking its own way - the control, nothing
##   chosen, a different set on nearly every seed; ticking another leaves how the rest look as they were; a desk lit by
##   candles and given none has a taper set down (one given its own keeps it, a lamplit desk none - the control); what
##   lies flat and was chosen lies where the widest framing sees it ([constant DeskLook.SEEN]) - the control, the same
##   things drawn by the seed, almost never.
## - A CHOSEN DESK IS PACKED IN TO THE PAPER, THE CANDLES THE FIRST PUSHED OUT ([method DeskLook._pack]; 2026-10-29, the
##   user: "almost all of the objects placed on the table are outside of the camera's view ... with just tea lights and
##   the dog tags now... I still can't even see the dog tags"): with tea lights and a dog tag, the tag lies within 4 cm
##   of the paper - where the camera sees it as the pen writes - and its bone wholly in the wide frame, on every desk - the
##   control, a circle round it anywhere in the frame beside the pad, on few; a crowded desk keeps what lies flat in the
##   frame and pushes the candles out first ("candles, which cast light regardless of where they exist"); its candles
##   take their sides by turns ("The scenes look best when lighting comes from both directions"): one alone on either,
##   two on both - and none in the pen's stretch beside the pad's right; ITS THINGS ON BOTH SIDES OF THE PAD (the user:
##   "the pencil and dog tags and probably other objects as well are NEVER placed on the right ... the pencil could
##   obviously be set alongside the pens on the right ... at the bottom corner, there is NEVER anything placed there"),
##   each leaning to a side by the seed - the stretch beside the pad's right, where nothing had been let lie, in use -
##   never in the lane where the pen taps the desk ([constant DeskLook.TAP_LANE]), never on a pen.
## - A DOG TAG CUT AS A DOG'S BONE ([method DeskLook._dog_tag]; the user: "literally dog-bone shaped", then of the first
##   one, by their picture: "The chain is connected to the center of the bone ... It has sort of a V-shaped thing
##   attached to the middle of the bone ... true chain: like the necklace a girl would wear ... simple and flat ...
##   much longer"): on every tag one flat bone, mirrored both ways and no rim round it, its V bail at the middle of its
##   long edge, the chain a chain of links from the bail's ring; whole to its end, a necklace's length - the control,
##   the 360 links a thick chain stops at, would have stopped every one part way; DROPPED, NOT LOOPED (the user: "a
##   normal person doesn't loop their chain into neat little circles ... They just drop it there, chaotically"): off
##   the bone on every tag - the control, a single drop, lies on it now and then - each heap its own size and shape. A SMALL OUTLINE IS CUT AT ITS OWN SIZE
##   ([method Props._extrude_face]): a notch in its edge left open - the control, cut in meters as it had been (the
##   first tag's hole filled on 21 of 24), fills some.
## - TICKED WHILE THE LETTER PLAYS, THE DESK IS DRESSED AGAIN ([method LetterMedium._set_desk]): a mounted letter's
##   desk has the thing at once, and another desk's number another desk (its own seed, the hand's kept), the letter
##   as it was - the control, another hand, loads the letter again.
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
	_pictures()
	_hesitant_picture()
	_dense_sketch()
	_struck()
	_pens()
	_pick_up()
	_turn_waits()
	_line_breaks()
	_let_go()
	_chosen_desk()
	_packed()
	_dog_tag()
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
	# A POINT LINGERS: the voice rests after its sentence, the pen held on the dot and the camera framed on it through
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
		# through the hesitation, the desk
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


## THE PEN IS PICKED UP FROM THE DESK, and nothing else lies where it does.
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
	# LYING THERE through the intro and its focus pull
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
	# THE WAY: on, a frame at a time, and never into the desk or the pad
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
			# its axis over what is under it: the nib clear of it, the body (2 cm up) by about its radius
			for along in [0.0, 0.02, 0.06, 0.1, LetterMedium.PEN_TOP]:
				var q: Vector3 = xf.origin + xf.basis.y * float(along)
				var on_pad := absf(q.x) <= LegalPad.W * 0.5 + DeskMedium.PEN_R and absf(q.z) <= LegalPad.H * 0.5 + DeskMedium.PEN_R
				var over: float = q.y - (0.0003 if on_pad else LegalPad.DESK_Y) - (0.0 if float(along) == 0.0 else DeskMedium.PEN_R * 0.9)
				lowest = minf(lowest, over)
		prev = xf
		t += dt
		k += 1
	m._now = w.x
	var hover := m._world(m._before_first()["p"], DeskMedium.REST_LIFT)
	_check(worst < 0.005 and hover.distance_to(lies) > 0.1,
		"on the way it moves at most %.1f mm a frame - the control, the desk's own pen hovering over the first stroke, is %.0f cm from where it lies"
		% [worst * 1000.0, hover.distance_to(lies) * 100.0])
	_check(lowest > -0.0002, "and it never goes into the desk or the pad (%.1f mm clear at the least)" % (lowest * 1000.0))
	m._now = start + 0.05
	_check(m._pick_up_pose(Transform3D.IDENTITY).is_empty() and float(m.pen_at()["lift"]) <= DeskMedium.LIFT + 0.0001,
		"and once the line begins the pen is the desk's own, on the paper")
	# THE PEN LEANS TO THE RIGHT AND A LITTLE DOWN as the camera sees it, close and wide, all the while it writes
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
	var desk := _screen_down(DeskMedium.lean(DeskMedium.PEN_UP, 0.0, 3, 0.5, Vector3.ZERO), float(LetterMedium.LETTER_LOCAL["pitch"]))
	var mean := sum / float(maxi(count, 1))
	_check(lo > 0.0 and hi < 35.0 and mean > 10.0 and mean < 24.0 and desk < -30.0,
		"as it writes, the pen's top points right and a little down on the screen (%.0f degrees under the level, %.0f to %.0f with the hand's sway) - the control, the Proof desk's lean, %.0f degrees over it"
		% [mean, lo, hi, -desk])
	m.free()
	# NOTHING ELSE LIES THERE
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


## A LETTER OF MANY SENTENCES: [param paras] paragraphs of sentences [param lengths] words long in turn, a comma in
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


## A VOICE THAT PAUSES AS A REAL ONE DOES, for [param parsed]: [param word] a word, [param stop] more at a sentence's end
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
## WHAT IS ON THE DESK AND ITS LIGHT ARE CHOSEN, the seed only placing them and drawing how they look.
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
	# WHERE THE FRAME SEES THEM: what lies flat and was chosen, beside the pad in the widest framing
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


## A CHOSEN DESK PACKED IN TO THE PAPER, the candles the first pushed out of the frame.
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
				# THE BONE ITSELF, as it lies: its outline through the thing's place on the desk
				var plate: Dictionary = Props.sanitize(DeskLook._thing("dog_tag", DeskLook._rng(seed, "chosen dog_tag")), ["#888888"])["things"][0]["parts"][0]
				var bone_in := true
				for q in plate["points"]:
					var w := (c as Node3D).transform * (((plate["at"] as Vector3) + Vector3((q as Vector2).x, 0.0, (q as Vector2).y)) * 0.01)
					bone_in = bone_in and Geometry2D.is_point_in_polygon(Vector2(w.x, w.z), seen)
				whole += int(bone_in)
		(dressed["node"] as Node).free()
		# THE CONTROL: placed as it had been, a circle round it anywhere in the frame beside the pad, the tea lights in
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
	# ITS THINGS ON BOTH SIDES OF THE PAD, each leaning to one: never in the lane where the pen taps the desk, never on a
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
	# ITS CANDLES ON BOTH SIDES, by turns: one alone on either; two or more on each
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


## A DOG TAG CUT AS A DOG'S BONE: flat, hung by its bail from the middle of its edge on a long fine chain, whole.
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
		var bail: Dictionary = parts[1]
		var chain: Dictionary = parts.filter(func(p: Dictionary) -> bool: return p["shape"] == "strand")[0]
		# THE BONE: one flat plate, the same mirrored both ways, and nothing laid round its edge (no rim)
		var pts: Array = plate["points"]
		var mirrored := true
		for q in pts:
			var twins := 0
			for o in pts:
				twins += int((o as Vector2).distance_to(Vector2(-(q as Vector2).x, (q as Vector2).y)) < 1e-4) \
					+ int((o as Vector2).distance_to(Vector2((q as Vector2).x, -(q as Vector2).y)) < 1e-4)
			mirrored = mirrored and twins == 2
		var tubes := parts.filter(func(p: Dictionary) -> bool: return p["shape"] == "tube").size()
		# THE BAIL at the middle of the long edge, over it; the chain's two runs from the ring at its end
		var plate_at: Vector3 = plate["at"]
		var bail_at: Vector3 = bail["at"]
		# the long edge's middle: where the outline crosses x = 0 on the bail's side
		var waist := INF
		for i in pts.size():
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[(i + 1) % pts.size()]
			if a.x * b.x <= 0.0 and a.x != b.x and a.y < 0.0:
				waist = lerpf(a.y, b.y, a.x / (a.x - b.x))
		var line := Props.strand_line(chain, RandomNumberGenerator.new())
		var ends := line[0].distance_to(line[line.size() - 1])
		shaped += int(mirrored and tubes <= 1 and absf(bail_at.x - plate_at.x) < 1e-4 and bail["shape"] == "extrude"
			and absf(bail_at.z - plate_at.z - waist) < 1e-3 and String(chain["kind"]) == "chain" and ends < 0.003)
		var along := Props._lengths(Array(line))[-1]
		longest = maxf(longest, along)
		shortest = minf(shortest, along)
		# THE CHAIN WHOLE: a link where its last run comes back to the ring, past where whole rings a link had stopped it
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
		# DROPPED, NOT LOOPED: off the bone - the control, the first drop alone, on it now and then - and each its own shape
		var outline := PackedVector2Array()
		for q in pts:
			outline.append(q as Vector2)
		# (the chain and the plate are laid about the same middle: each in the bone's own frame)
		var over := 0
		for q in line:
			over += int(Geometry2D.is_point_in_polygon(Vector2(q.x, q.z) * 100.0, outline))
		off_bone += int(over == 0)
		var r0 := DeskLook._rng(seed, "first drop")
		var tip := ((chain["path"][0] as Vector2) + (chain["path"][-1] as Vector2)) * 0.5
		ctl_over += int(DeskLook._over(DeskLook._dropped(r0, tip, 80.0, outline), outline) > 0)
		var lo2 := Vector2(INF, INF)
		var hi2 := -lo2
		for q in line:
			lo2 = lo2.min(Vector2(q.x, q.z))
			hi2 = hi2.max(Vector2(q.x, q.z))
		shapes[str(((hi2 - lo2) * 1000.0).round())] = true
	_check(shaped == n,
		"one flat bone on every tag, the same mirrored both ways and no rim round it, its V bail at the middle of its long edge, the chain a chain of links from the bail's ring (%d of %d)"
		% [shaped, n])
	_check(whole == n and ctl_capped == n and shortest > DeskLook.TAG_LONG.x * 0.0095 and longest < DeskLook.TAG_LONG.y * 0.0105,
		"its chain is whole, links to its end on all %d, %.0f to %.0f cm - a necklace's - where the 360 links a thick chain stops at would have stopped %d"
		% [n, shortest * 100.0, longest * 100.0, ctl_capped])
	_check(off_bone == n and ctl_over > 0 and shapes.size() == n,
		"its chain is dropped, never looped: off the bone on all %d (the control, a single drop, on it %d times), each heap its own size and shape (%d of %d)"
		% [n, ctl_over, shapes.size(), n])
	# A SMALL OUTLINE CUT AT ITS OWN SIZE ([method Props._extrude_face]): a notch in its edge left open - the control, cut in
	# meters as it had been, filled now and then (the first tag's hole had been)
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


## TICKED WHILE THE LETTER PLAYS: the desk dressed again, the letter as it was.
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
	# ANOTHER DESK: drawn again, every word as it was
	var paper: Color = m.look["paper"]
	var desk_mid: Node3D = m._desk
	(subs.document["letter"] as Dictionary)["desk"] = 9
	m._ensure_doc()
	var other_desk: bool = m._desk != desk_mid and m._seed == 9 and m._hand == 5 and m.look["paper"] != paper \
		and is_same(m._actions, actions)
	(subs.document["letter"] as Dictionary)["hand"] = "caveat"
	m._ensure_doc()
	_check(redressed and other_desk and not is_same(m._actions, actions),
		"a thing ticked or another desk's number while it plays is on the desk at once, the letter as it was - the control, another hand, loads the letter again")
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


## A PAGE IS TURNED WITH THE VOICE WAITING WHERE IT ENDS ON A MARK, and a sentence it breaks is finished first.
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
			# the next sentence in the paragraph: the first word after a stop
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


## A LINE RUNS ON INTO THE VOICE'S PAUSE AFTER IT.
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


## THE CAMERA LETS GO BEFORE A TURN ONCE, its words arriving a sentence at a time.
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
	# WRITTEN AND NEVER SAID (the user: "the second 'mourning' should not have been spoken"): the correction written
	# beside the struck words and not said, the sentence's stop kept for the voice, which rests while it is written
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
	# A CHANGE INSIDE A WORD (the chapter's closing stop in red): the stop against the word, no space, said with it
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
	# on the desk
	var feed := ShowFeed.new()
	feed.outro_hold = 4.0
	feed.intro_hold = 1.0
	var m := LetterMedium.new()
	m.feed = feed
	m._pad = LegalPad.new()
	# the desk's own pen, as mounting builds it, in the tree beside where the others are laid
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

