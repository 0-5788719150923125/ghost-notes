extends SceneTree

## Does the desk's hand write what TeX laid out - every glyph, in a hand's order, in its box, and as
## a function of time?
##
## The fixture, tests/desk/ink_layout.json, is TeX's own answer (hosts/math/typeset.py, run on
## ghost's TinyTeX) for nine items: a superscript sum, a radical and a fraction, a sum with limits,
## a two-line align*, the logic symbols, calligraphic and blackboard letters with the drawn-by-recipe
## glyphs, big delimiters and a matrix, a paragraph with inline math, and a contour integral - the
## one glyph no stroke font has, kept with its outline, so the fallback is held too. Committed
## rather than made here because a gate cannot assume TeX; regenerate it with typeset.py when the
## host changes (the spec is in its header's form: id, tex, mode).
##
## Two-sided where a pass could come from a broken instrument: the contour integral must NOT be
## covered and must still be drawn (traced, and named in `missing`); a name nothing knows must be
## named and drawn as nothing; a ligature TeX sets as one glyph ("ff") is written as its letters, never
## traced; TeX's own order must have the sum's upper limit first, so the hand's
## moving the sign ahead of it is seen to happen; a different seed must give a different hand.
##
## A DRAWING (hosts/math/figure.py's record: `paths` beside its labels' glyphs) is drawn by the same
## hand, in one order over both: a line drawn a little uneven but ending exactly where it was laid out
## (lines that meet still meet), never ruler-straight (the control), and faster than writing - a
## line drawn at the writing pace is the control that must take longer.
##
##   godot --headless --path . --script tests/desk/ink_check.gd

var _fails: Array = []


func _init() -> void:
	var text := FileAccess.get_file_as_string("res://tests/desk/ink_layout.json")
	var parsed: Variant = JSON.parse_string(text)
	var layout: Dictionary = parsed if parsed is Dictionary else {}
	_check(not layout.is_empty(), "the fixture reads")
	var items := {}
	for it in layout.get("items", []):
		items[String(it["id"])] = it
	var outlines: Dictionary = layout.get("fonts", {})
	_coverage(items, outlines)
	_seeded(items, outlines)
	_order(items)
	_boxes(items, outlines)
	_proportions()
	_time(items, outlines)
	_figure(items)
	if _fails.is_empty():
		print("ink_check: ALL OK")
		quit(0)
	else:
		print("ink_check: %d FAILURE(S)" % _fails.size())
		for f in _fails:
			print("   ", f)
		quit(1)


func _check(ok: bool, msg: String) -> void:
	print(("   ok   " if ok else "   FAIL ") + msg)
	if not ok:
		_fails.append(msg)


func _names(strokes: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for s in strokes:
		var n := String(s["name"])
		if out.is_empty() or out[out.size() - 1] != n:
			out.append(n)
	return out


# --- every glyph -----------------------------------------------------------------

func _coverage(items: Dictionary, outlines: Dictionary) -> void:
	print("-- every glyph has a hand")
	var uncovered := PackedStringArray()
	var seen := 0
	for id in items:
		for g in items[id]["glyphs"]:
			seen += 1
			var name := String(g["n"])
			if name.begins_with("contintegral"):
				continue
			if not Ink.covered(name, String(g["f"])):
				uncovered.append("%s:%s" % [g["f"], name])
	_check(seen > 100, "the fixture has its glyphs (%d)" % seen)
	_check(uncovered.is_empty(), "every glyph but the contour integral has strokes (%s)" % ", ".join(uncovered))
	for id in items:
		var got := Ink.strokes_of(items[id], 7, outlines)
		var missing: PackedStringArray = got["missing"]
		if id == "oint":
			_check(not Ink.covered("contintegraldisplay", "cmex10"),
				"the control: the contour integral has no strokes of its own")
			_check(missing.size() == 1 and missing[0].ends_with("contintegraldisplay"),
				"so it is named in missing (%s)" % ", ".join(missing))
			_check(_names(got["strokes"]).has("contintegraldisplay"), "and drawn all the same, traced")
		else:
			_check(missing.is_empty(), "%s: nothing missing (%s)" % [id, ", ".join(missing)])
	var made_up := {"id": "x", "glyphs": [{"k": 1, "f": "cmsy10", "c": 250, "n": "nosuchglyph",
		"x": 0.0, "y": 0.0, "s": 12.0, "w": 6.0, "ht": 6.0, "dp": 0.0}], "rules": []}
	var got := Ink.strokes_of(made_up, 7)
	_check((got["missing"] as PackedStringArray).has("cmsy10:nosuchglyph") and
		(got["strokes"] as Array).is_empty(), "a glyph nothing can draw is named, and drawn as nothing")
	# A LIGATURE: cmr's "ff" (code 11) is one glyph to TeX and two letters to a hand
	var lig := {"id": "lig", "glyphs": [{"k": 1, "f": "cmr12", "c": 11, "n": "ff", "x": 0.0, "y": 0.0,
		"s": 12.0, "w": 7.0, "ht": 8.3, "dp": 0.0}], "rules": []}
	var one := {"id": "lig", "glyphs": [{"k": 1, "f": "cmr12", "c": 102, "n": "f", "x": 0.0, "y": 0.0,
		"s": 12.0, "w": 3.6, "ht": 8.3, "dp": 0.0}], "rules": []}
	var ff := Ink.strokes_of(lig, 7)
	var f := Ink.strokes_of(one, 7)
	_check((ff["missing"] as PackedStringArray).is_empty() and Ink.covered("ff", "cmr12")
		and (ff["strokes"] as Array).size() == 2 * (f["strokes"] as Array).size(),
		"a ligature is written as its letters, never traced (%d strokes, f has %d)"
		% [(ff["strokes"] as Array).size(), (f["strokes"] as Array).size()])
	_check(not Ink.covered("ffxyz", "cmr12"), "the control: a longer name is no ligature")


# --- a seeded hand -----------------------------------------------------------------

func _points(strokes: Array) -> Array:
	var out: Array = []
	for s in strokes:
		out.append(Array(s["points"]))
	return out


func _seeded(items: Dictionary, outlines: Dictionary) -> void:
	print("-- the hand is seeded")
	var a := Ink.strokes_of(items["big"], 7, outlines)
	var b := Ink.strokes_of(items["big"], 7, outlines)
	var c := Ink.strokes_of(items["big"], 8, outlines)
	_check(_points(a["strokes"]) == _points(b["strokes"]), "the same item and seed write the same strokes")
	_check(_points(a["strokes"]) != _points(c["strokes"]), "the control: another seed is another hand")
	var sa := Ink.schedule(a["strokes"], 7)
	var sb := Ink.schedule(b["strokes"], 7)
	_check(is_equal_approx(float(sa["length"]), float(sb["length"])), "and the same schedule")


# --- a hand's order ----------------------------------------------------------------

func _order(items: Dictionary) -> void:
	print("-- written in a hand's order")
	var frac := _names(Ink.strokes_of(items["frac"], 7)["strokes"])
	_check(frac == PackedStringArray(["radical", "rule", "two", "equal", "p", "rule", "q"]),
		"a radical, its bar, its radicand; a numerator, its bar, its denominator (%s)" % ", ".join(frac))
	# TeX sets a sum's upper limit before the sign - the control, so the fix is seen to happen.
	var raw: Array = (items["sum"]["glyphs"] as Array).duplicate()
	raw.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return int(x["k"]) < int(y["k"]))
	_check(String(raw[0]["n"]) == "n" and String(raw[1]["n"]) == "summationdisplay",
		"the control: TeX's own order has the upper limit first")
	var sum := _names(Ink.strokes_of(items["sum"], 7)["strokes"])
	_check(sum.size() > 2 and sum[0] == "summationdisplay" and sum[1] == "n",
		"the hand writes the sign first, then its limits (%s)" % ", ".join(sum.slice(0, 4)))
	# `\implies` is TeX's equals sign with a double arrow kerned back over its end: one long arrow
	var implies := {"id": "imp", "rules": [], "glyphs": [
		{"k": 1, "f": "cmr12", "c": 61, "n": "equal", "x": 0.0, "y": 0.0, "s": 12.0, "w": 9.1, "ht": 4.0, "dp": 0.0},
		{"k": 2, "f": "cmsy10", "c": 41, "n": "arrowdblright", "x": 5.2, "y": 0.0, "s": 12.0, "w": 12.0, "ht": 6.0, "dp": 0.6}]}
	var imp := _names(Ink.strokes_of(implies, 7)["strokes"])
	_check(imp == PackedStringArray(["arrowdbllong"]), "an implies is one long arrow, not \"=\" and \"⇒\" (%s)" % ", ".join(imp))
	(implies["glyphs"][1] as Dictionary)["x"] = 12.0
	_check(_names(Ink.strokes_of(implies, 7)["strokes"]) == PackedStringArray(["equal", "arrowdblright"]),
		"the control: an equals sign and an arrow that do not overlap stay two glyphs")
	var lines := _names(Ink.strokes_of(items["align"], 7)["strokes"])
	_check(lines.find("arrowdblright") > lines.find("q"), "an align is written line by line")


# --- in its box --------------------------------------------------------------------

func _boxes(items: Dictionary, outlines: Dictionary) -> void:
	print("-- each glyph stays in the box TeX gave it")
	var wide := PackedStringArray()
	var off := PackedStringArray()
	for id in items:
		var item: Dictionary = items[id]
		var by_k := {}
		var glyphs: Array = (item["glyphs"] as Array).duplicate()
		glyphs.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return int(x["k"]) < int(y["k"]))
		for n in glyphs.size():
			var g: Dictionary = glyphs[n]
			# An overlay of no width (the "not" slash) is held to the glyph it strikes.
			if float(g["w"]) <= 0.01 and n + 1 < glyphs.size():
				g = g.duplicate()
				g["x"] = glyphs[n + 1]["x"]
				g["w"] = glyphs[n + 1]["w"]
			by_k[int(g["k"])] = g
		var got := Ink.strokes_of(item, 7, outlines)
		var extents := {}
		for s in got["strokes"]:
			var k := int(s["k"])
			if not by_k.has(k):
				continue
			var r: Rect2 = extents.get(k, Rect2())
			for p in s["points"]:
				r = Rect2(p, Vector2.ZERO) if r == Rect2() else r.expand(p)
			extents[k] = r
		for k in extents:
			var g: Dictionary = by_k[k]
			var r: Rect2 = extents[k]
			var size := float(g["s"])
			var w := float(g["w"])
			var name := String(g["n"])
			# Overflow allowed is a hand's, not a stretch: a glyph is never wider than its box by
			# more than a third of its size (stretched to fit, the spike's superscripts ran into
			# their bases), and its middle is inside the box.
			if r.size.x > w + 0.34 * size and not String(g["f"]).begins_with("cmex"):
				wide.append("%s %s (%.1f in %.1f)" % [id, name, r.size.x, w])
			var cx := r.get_center().x
			if cx < float(g["x"]) - 0.2 * size or cx > float(g["x"]) + w + 0.2 * size:
				off.append("%s %s" % [id, name])
	_check(wide.is_empty(), "no glyph overruns its box by much (%s)" % ", ".join(wide))
	_check(off.is_empty(), "every glyph is centered on its box (%s)" % ", ".join(off))


# --- its own proportions --------------------------------------------------------------

## A glyph is drawn at the shape its font gives it. The hand once measured x by each glyph's own
## advance and y by the cap height: a comma (8 units wide) came out 2.6 times too wide and read as
## "›", and every glyph's shape followed its advance. Each of these, set alone in a box wide enough
## not to shrink it, must keep the font's width-to-height within a quarter (the hand's own jitter -
## a uniform scale and a few degrees' turn - stays well inside that).
func _proportions() -> void:
	print("-- a glyph keeps its own proportions")
	var bad := PackedStringArray()
	for pair in [["comma", ","], ["period", "."], ["colon", ":"], ["m", "m"], ["w", "w"], ["x", "x"]]:
		var name := String(pair[0])
		# The font's own points, in its own units - never through the hand's code, or a bug there
		# would bend the reference the same way (it did: this check passed on the bug at first).
		var glyph: Array = Ink._hershey("futural", String(pair[1]))
		var raw := _extent(glyph[2])
		var item := {"id": "p_" + name, "rules": [], "glyphs": [{"k": 1, "f": "cmr12", "c": 0,
			"n": name, "x": 0.0, "y": 0.0, "s": 12.0, "w": 20.0, "ht": 8.0, "dp": 3.0}]}
		var drawn := Rect2()
		for st in Ink.strokes_of(item, 3)["strokes"]:
			for q in st["points"]:
				drawn = Rect2(q, Vector2.ZERO) if drawn == Rect2() else drawn.expand(q)
		var want := raw.size.x / maxf(raw.size.y, 1e-6)
		var got := drawn.size.x / maxf(drawn.size.y, 1e-6)
		if absf(got - want) > 0.25 * want + 0.05:
			bad.append("%s %.2f for %.2f" % [name, got, want])
	_check(bad.is_empty(), "narrow and wide glyphs keep the font's width to height (%s)" % ", ".join(bad))


func _extent(strokes: Array) -> Rect2:
	var r := Rect2()
	for st in strokes:
		for q in st:
			r = Rect2(q, Vector2.ZERO) if r == Rect2() else r.expand(q)
	return r


# --- a function of time --------------------------------------------------------------

func _drawn(ink: Array) -> float:
	var total := 0.0
	for s in ink:
		var pts: PackedVector2Array = s["points"]
		for i in range(1, pts.size()):
			total += pts[i - 1].distance_to(pts[i])
	return total


func _time(items: Dictionary, outlines: Dictionary) -> void:
	print("-- ink is a function of time")
	var strokes: Array = Ink.strokes_of(items["pyth"], 7, outlines)["strokes"]
	var sched := Ink.schedule(strokes, 7)
	var length := float(sched["length"])
	_check(length > 3.0 and length < 8.0,
		"a^2 + b^2 = c^2 takes as long as writing it (%.1f s; the spike measured 4.7)" % length)
	var fast := Ink.schedule(strokes, 7, 2.0)
	_check(absf(float(fast["length"]) * 2.0 - length) < 0.01, "and twice the pace, half the time")
	_check((Ink.at(sched, 0.0)["ink"] as Array).is_empty(), "nothing is written at the start")
	var done := Ink.at(sched, length + 1.0)
	_check((done["ink"] as Array).size() == strokes.size() and done["pen"] == Vector2.INF,
		"everything is written at the end, and the pen is lifted")
	var last := -1.0
	var monotone := true
	var t := 0.0
	while t <= length:
		var d := _drawn(Ink.at(sched, t)["ink"])
		monotone = monotone and d >= last - 1e-4
		last = d
		t += 0.05
	_check(monotone, "ink only ever grows")
	var mid := length * 0.5
	var early := Ink.at(sched, mid)
	Ink.at(sched, length)
	Ink.at(sched, 0.1)
	var again := Ink.at(sched, mid)
	_check(_drawn(early["ink"]) == _drawn(again["ink"]) and early["pen"] == again["pen"],
		"a moment is the same whatever was asked before it")
	var writing := false
	for s in sched["strokes"]:
		var row: Dictionary = s
		var t_in := (float(row["t0"]) + float(row["t1"])) * 0.5
		var now := Ink.at(sched, t_in)
		if now["pen"] != Vector2.INF:
			var pts: PackedVector2Array = row["points"]
			var on := false
			for i in range(1, pts.size()):
				var q := Geometry2D.get_closest_point_to_segment(now["pen"], pts[i - 1], pts[i])
				on = on or q.distance_to(now["pen"]) < 1e-3
			writing = on
			break
	_check(writing, "mid-stroke, the pen is on the stroke it is drawing")


func _figure(items: Dictionary) -> void:
	print("-- a drawing, by the same hand")
	var label: Dictionary = {}
	for id in items:
		for g in (items[id] as Dictionary).get("glyphs", []):
			if String((g as Dictionary).get("n", "")) == "one":
				label = (g as Dictionary).duplicate()
	_check(not label.is_empty(), "the fixture has a glyph to label the drawing with")
	label["k"] = 1001
	label["x"] = 40.0
	label["y"] = -4.0
	var rec := {"id": "fig", "figure": true, "w": 200.0, "h": 60.0, "d": 0.0, "glyphs": [label], "rules": [],
		"paths": [{"k": 0, "kind": "line", "pts": [[0.0, -30.0], [200.0, -30.0]]},
			{"k": 2000, "kind": "arrow", "pts": [[194.0, -33.0], [200.0, -30.0], [194.0, -27.0]]},
			{"k": 3000, "kind": "dot", "pts": [[100.0, -30.0], [101.0, -30.0], [100.5, -29.0]]}]}
	var got := Ink.strokes_of(rec, 5)
	var strokes: Array = got["strokes"]
	var names := PackedStringArray()
	for st in strokes:
		names.append(String((st as Dictionary)["name"]))
	_check(names.size() >= 4 and names[0] == "line" and names[names.size() - 2] == "arrow" and names[names.size() - 1] == "dot"
		and names.slice(1, names.size() - 2).has("one"), "paths and labels in one order (%s)" % ", ".join(names))
	var line: PackedVector2Array = (strokes[0] as Dictionary)["points"]
	_check(line[0].distance_to(Vector2(0, -30)) < 0.001 and line[line.size() - 1].distance_to(Vector2(200, -30)) < 0.001,
		"a line ends exactly where it was laid out")
	var off := 0.0
	for q in line:
		off = maxf(off, absf(q.y + 30.0))
	_check(off <= Ink.WANDER_RANGE.y + 0.2 and off > 0.05,
		"and wanders a little between, never ruler-straight (%.2f points at most)" % off)
	var dot: PackedVector2Array = (strokes[strokes.size() - 1] as Dictionary)["points"]
	_check(dot.size() == 3 and dot[0] == Vector2(100, -30), "a dot is drawn as it was laid out")
	_check(Ink.strokes_of(rec, 5)["strokes"][0]["points"] == line and Ink.strokes_of(rec, 6)["strokes"][0]["points"] != line,
		"the same seed draws the same line; another seed, another")
	var sched := Ink.schedule(strokes, 5)
	var row: Dictionary = sched["strokes"][0]
	var took := float(row["t1"]) - float(row["t0"])
	var slow: Dictionary = (strokes[0] as Dictionary).duplicate()
	slow.erase("speed")
	var as_writing := Ink.schedule([slow], 5)["strokes"][0] as Dictionary
	var slow_took := float(as_writing["t1"]) - float(as_writing["t0"])
	_check(took < 2.0 and slow_took > took * 2.0,
		"a line is drawn faster than writing (%.2f s; the control, at the writing pace, %.2f s)" % [took, slow_took])
