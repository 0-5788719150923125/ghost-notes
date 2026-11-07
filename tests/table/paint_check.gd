extends SceneTree

## The gate of THE PAINTED SURFACE ([FaceForm], [Bristles], [Skins], [TablePaint]; next/painted_surface.md), with no renderer.
##
##   godot --headless --path . --script res://tests/table/paint_check.gd
##
## - A MASK IS A FACE SEEN FROM THE FRONT: its nose stands out its depth, its closed eyes lie in their sockets, a point outside its
##   outline has no height, and its landmarks are where its features are. The control: the rim's height is nothing.
## - A DESIGN IS MADE SAFE: fills, lines, dots and stones kept in order with ids of their own; a fill that is no path, an element with
##   no paint and two of one id are said. The control: a path's letters and numbers alone pass.
## - PATHS ARE FOLLOWED: an SVG path's lines, curves and arcs end where they say, a `Z` closes, a second `M` starts another.
## - A LINE IS DRAWN IN SHORT PULLS ("Nobody strokes a line perfectly all in one fell swoop"), each begun back over the last, lifted
##   between; the control, its runs alone, are long. A FILL OF SHAPES APART IS FINISHED A SHAPE AT A TIME (feedback 0022); the control,
##   rows over both at once, go back and forth between them.
## - PAINT SHOWS WHERE ITS TOOL HAS BEEN: a line's reveal map rises along its path from its start to its end; a stipple's begins at its
##   middle and ends at its rim. The control: a map read backward along the line falls. A STIPPLE RUNS DRY (the user, 2026-11-06:
##   "fainter and fainter, until we are forced to pick-up more product"): what is on it taken off a share at a time, EACH PRESS ITS
##   OWN ("each application might use a different amount"), so never nothing, and back for more where this load happens to stop -
##   EACH LOAD ITS OWN LENGTH ("every 16 dabs is going to be strange ... because it's constant"), now and then pushed on nearly dry -
##   its reveal map saying how much, the same design painted the same way twice; a sweep never pale; the control, a line, lays as much
##   at its end as at its start.
## - A TOOL PAINTS ON THE SURFACE (the `paint` law, on a mask on its stand): fetched from its jar, the liner's tip is on the face, within
##   a millimeter, all the while it draws; lifted between strokes; back in its jar when the act is done - and the sponge stippling the
##   base is pressed onto the face too. Each element is laid while its act runs, the base before the line drawn over it. The control:
##   the liner's tip at rest is far from the face. NOTHING IS LIFTED ALONG A STROKE IT PRESSES (feedback 0019, 0021: a liner 11 mm and a
##   flat brush 17 mm over a mask's rim, painting in the air); the control, the lifts between strokes, are found.
##   ITS HAIRS ARE BENT ONTO THE FACE wherever it is pressed (a forehead's stars painted with nothing, a lower lip's outline drawn up on
##   the lip): the bent tip within a touch of it at nine places in ten over the whole face; the control, the bend counted along the
##   face's normal, at far fewer. IT GOES BACK OVER WHAT IT MISSED (feedback 0035): what the brow's strokes left bare dabbed until under
##   half is; the control, the first look, left some.
##   The sponge stipples BY ITS CORNER (the user: "dab with the corner of the sponge, not with the flat side"), stood off only where the
##   face round it leaves the corner no room, and never more than 4 mm.
## - A HELD TOOL STANDS IN NOTHING (feedback 0016: "This sponge is clipping right through the nose", and through a pot as it took its
##   paint): a sponge stippling by its corner and blending flat over a whole face, nose and all, stands no more than 3 mm in it as it is
##   drawn (pressed in, squashed back), at each place it keeps and on its way between them; dipped into a pot narrower than its face,
##   nothing of it as drawn past the pot's wall. THE CONTROLS: blended with nothing held clear, it stands 8 mm and more in the face;
##   held flat in the pot, past its wall.
## - A SPONGE IS PRESSED INTO ITS PAINT AND SQUASHED FLAT ON IT (the user, 2026-11-06: "It touches at the very tip of a corner, and
##   doesn't compress the sponge at all"): dipped by its end, pushed in over 7 mm, its lowest drawn on the paint's surface and over 12 mm
##   of it lying there. THE CONTROLS: never flattened it would stand over 6 mm under the paint; held as it had been, by its corner
##   through its middle and squashed back from there, it lay on the paint half as far across or less.
## - IT IS A FUNCTION OF TIME: the tool posed at a moment straight away and posed there after every moment before it are the same.
## - A PAINT ACT TAKES WHAT ITS STROKES TAKE: its natural length is set, and `act` says what it paints and what no act paints yet.
##   BEGUN, IT KEEPS ITS LENGTH when a later plan moves the word that cues the next act (each sentence had moved every stroke, and the
##   bake went back to the act's start - 75 of 120 s waited, live); the control, planned afresh, ends at the word heard. ONE HAND PAINTS
##   ONE THING AT A TIME: a paint act cued while another is still painting waits for it; the control, a change of the water cued at the
##   same word, begins on it.
##   A paint act on a surface with no design is refused, and why said; the same acts on the designed surface, kept, the control.
## - THE HAIRS FOLLOW THEIR PULL: dragged to the right they lean left; let go, they swing past straight and settle. The control: a
##   brush neither dragged nor pressed is straight.
## - ITS FIELD IS THE FACE: 3 mm out of the cheek reads 3 mm, 3 mm in reads -3 mm, behind its back and past its rim read out. The control:
##   the box it had been read the point over the cheek as inside (joker-motivation 856886: every brush on the face "passed through" it).
## - THE DETAILS (the user, 2026-11-05: "the smear and towel and such are important details"): a SMEAR takes an earlier element's paint
##   and thins along the way it is dragged, revealed from its start (the control: a smear of nothing is left out); a MIST lays no color
##   and is sprayed from a hand's length off, to the surface's side, never between it and the lens; a brush that RINSES is rinsed and
##   dried on the towel before each new color and before it is put down, going cup to towel to pot with no stop at the face between
##   (the control: one that does not rinse has none); the WATER CLOUDS toward each color rinsed out (the control: an act with no rinse
##   leaves it as it was); a powder's pats are PLACED as puffs. A trip comes to the cup OVER ITS RIM (the control: its water lies further
##   under it than a trip's lift) and the way between places goes OVER WHAT STANDS IN IT, a tall bottle between the cup and the towel
##   (the control: with nothing mapped it goes through); a painting tool is NEVER SAID TO PASS THROUGH what it is meant to go into -
##   what it paints, its water, its towel, the paints (the control: one that does not rinse is not excused the cup or the towel). These
##   three, and the design that never reached the puppeteer's table, were joker-motivation 856886's first real puppeteer.

var _fails := 0


func _ok(cond: bool, msg: String) -> void:
	if not cond:
		_fails += 1
		print("  FAIL: " + msg)


func _init() -> void:
	for check in [_mask, _design, _paths, _reveal, _hairs, _paints, _held, _scheduled, _details]:
		var done: Variant = (check as Callable).call()
		_ok(done == true, "%s stopped part way (a script error - see above)" % (check as Callable).get_method())
	print("paint_check: %s (%d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _fails, "" if _fails == 1 else "s"])
	quit(1 if _fails > 0 else 0)


func _mask() -> bool:
	var size := FaceForm.SIZE
	var nose := FaceForm.point(0.0, 0.415 * size.y, size)
	_ok(absf(nose.z - size.z) < size.z * 0.15, "the nose's tip stands %.2f cm out, not about the depth %.1f" % [nose.z, size.z])
	var lid := FaceForm.point(0.36 * size.x * 0.5, 0.553 * size.y, size)
	var cheek := FaceForm.point(0.36 * size.x * 0.5, 0.45 * size.y, size)
	_ok(lid.z < nose.z - 2.0, "the closed eye stands as far out as the nose")
	_ok(FaceForm.height(1.2, 0.5) == 0.0 and FaceForm.height(0.0, 1.05) == 0.0, "a point outside the outline has a height")
	_ok(FaceForm.height(0.0, 0.53) > 0.3, "the face's middle has no height")
	# THE CONTROL: the rim is where the face meets nothing
	var rim := FaceForm._rim_point(0.3)
	_ok(absf(FaceForm.height(rim.x, rim.y)) < 0.02, "the rim stands out %.3f of the depth" % FaceForm.height(rim.x, rim.y))
	var lm := FaceForm.landmarks(size)
	var nose_mm: Vector2 = (lm["the nose's tip"] as Dictionary)["at"]
	var mouth_mm: Vector2 = (lm["the mouth (closed: the line between the lips)"] as Dictionary)["at"]
	var eye_l: Vector2 = (lm["left eye (closed: its lash line)"] as Dictionary)["at"]
	var eye_r: Vector2 = (lm["right eye (closed: its lash line)"] as Dictionary)["at"]
	_ok(eye_l.y < nose_mm.y and nose_mm.y < mouth_mm.y, "the landmarks are not eyes over nose over mouth: %s %s %s" % [eye_l, nose_mm, mouth_mm])
	_ok(eye_l.x < 75.0 and eye_r.x > 75.0 and absf(eye_l.y - eye_r.y) < 0.01, "the eyes are not either side of the middle, level")
	var g := FaceForm.build({"size": size, "relief": 1.0, "thick": 0.6})
	_ok(g.v.size() > 10000 and g.v.size() == g.n.size() and g.v.size() == g.uv2.size(), "the mask's mesh is not whole")
	_ok(absf(g.height - size.y) < 0.2, "the mask stands %.2f cm tall, not %.0f" % [g.height, size.y])
	var outline := Skins.flatten(FaceForm.outline_path(size))
	_ok(outline.size() == 1 and bool((outline[0] as Dictionary)["closed"]), "the outline is not one closed path")
	# ITS FIELD IS THE FACE (what is met, and what a tool pressed onto it is measured against): a point 3 mm out of the cheek reads
	# 3 mm out, one 3 mm in reads 3 mm in, behind its back and past its rim are out - THE CONTROL: the box it had been read the
	# point over the cheek as inside
	var part := {"shape": "mask", "size": size, "relief": 1.0, "thick": 0.6}
	var built := AABB(Vector3(-size.x * 0.005, 0.0, -0.006), Vector3(size.x * 0.01, size.y * 0.01, size.z * 0.01 + 0.006))
	var field := ShapeField.of(part, built)
	var n := FaceForm.normal(cheek.x, cheek.y, size)
	var on := cheek * 0.01
	var out3 := field.sample(on + n * 0.003).x
	var in3 := field.sample(on - n * 0.003).x
	_ok(field.kind == "mask" and absf(out3 - 0.003) < 0.0006 and absf(in3 + 0.003) < 0.0006, "the mask's field does not read its face: %.1f mm 3 mm out, %.1f mm 3 mm in" % [out3 * 1000.0, in3 * 1000.0])
	_ok(field.sample(Vector3(0.0, size.y * 0.005, -0.01)).x > 0.003 and field.sample(Vector3(size.x * 0.007, size.y * 0.005, 0.0)).x > 0.005,
		"behind the mask's back and past its rim read as inside it")
	var as_box := ShapeField.of({"shape": "box", "size": [size.x, size.y, size.z]}, built)
	_ok(as_box.sample(on + n * 0.003).x < 0.0, "THE CONTROL: the mask's box reads the point over its cheek outside")
	return true


func _design() -> bool:
	var d := Skins.sanitize({"name": "a test", "elements": [
		{"id": "base", "stage": "base", "paint": "#f4f0e8", "fill": "all"},
		{"id": "brow", "stage": "lines", "paint": "#111111", "line": "M 30 70 C 40 55 60 52 68 60", "width": 1.6},
		{"id": "grin", "stage": "color", "paint": "#b0142c", "finish": "gloss", "fill": "M 40 160 Q 75 185 110 160 Q 75 172 40 160 Z"},
		{"id": "dots", "paint": "#ffffff", "dots": [[50, 100, 1.5]]},
		{"id": "stones", "stones": [[60, 110, 1.5]]},
		{"id": "not a path", "paint": "#123456", "fill": "<script>"},
		{"id": "no paint", "fill": "M 0 0 L 10 0 L 10 10 Z"},
		{"id": "brow", "paint": "#222222", "line": "M 80 70 L 120 60"},
		{"id": "lacquer", "paint": "#333333", "finish": "chrome", "line": "M 10 10 L 20 20"},
	]}, Vector2(150, 210))
	var ids: Array = (d["elements"] as Array).map(func(e: Dictionary) -> String: return String(e["id"]))
	_ok(ids.size() == 7, "%d elements kept, not 7: %s" % [ids.size(), ids])
	_ok(ids.slice(0, 5) == ["base", "brow", "grin", "dots", "stones"], "the elements are not kept in order: %s" % [ids])
	_ok(not ids.has("not a path") and not ids.has("no paint"), "a fill with no path or no paint was kept")
	_ok(ids.count("brow") == 1, "two elements share the id \"brow\"")
	var notes: PackedStringArray = d["notes"]
	_ok(notes.size() >= 4, "what was left out or changed is not said: %s" % notes)
	_ok(String(((d["elements"] as Array)[6] as Dictionary)["finish"]) == "matte", "a finish that is not one is not matte")
	_ok(Skins._path_text("M 1 2 L 3.5 -4e1 Z") != "", "THE CONTROL: a path's letters and numbers alone were refused")
	return true


func _paths() -> bool:
	var subs := Skins.flatten("M 10 10 L 40 10 C 50 10 60 20 60 30 Q 60 50 40 50 A 10 10 0 0 1 20 50 Z m 5 5 h 10 v 10 z")
	_ok(subs.size() == 2, "%d subpaths, not 2" % subs.size())
	if subs.size() < 2:
		return true
	var a: PackedVector2Array = (subs[0] as Dictionary)["pts"]
	_ok(a[0] == Vector2(10, 10) and a[a.size() - 1] == Vector2(10, 10) and bool((subs[0] as Dictionary)["closed"]), "the first subpath does not close where it began")
	var through := {"line": false, "curve": false, "arc": false}
	for q in a:
		through["line"] = through["line"] or q.distance_to(Vector2(40, 10)) < 0.01
		through["curve"] = through["curve"] or q.distance_to(Vector2(60, 30)) < 0.01
		through["arc"] = through["arc"] or q.distance_to(Vector2(20, 50)) < 0.01
	_ok(through.values().all(func(x: bool) -> bool: return x), "the path does not pass where its commands end: %s" % through)
	# the arc between (40, 50) and (20, 50), radius 10: a half circle, its middle 10 off the chord
	var off := 0.0
	for q in a:
		if q.x > 20.5 and q.x < 39.5 and absf(q.y - 50.0) > off:
			off = absf(q.y - 50.0)
	_ok(absf(off - 10.0) < 0.3, "the arc bows %.2f off its chord, not 10" % off)
	var b: PackedVector2Array = (subs[1] as Dictionary)["pts"]
	_ok(b[0] == Vector2(15, 15) and b[2] == Vector2(25, 25), "a relative subpath is not where it says: %s" % b)
	return true


func _reveal() -> bool:
	var frame := Vector2(150, 210)
	var line := {"id": "line", "kind": "line", "d": "M 20 50 L 120 50", "width": 2.0, "stage": "", "paint": "#000000", "finish": "matte", "opacity": 1.0, "soft": 0.0}
	var rect := Skins.rect_of(line, frame, 2.0)
	var cov := Skins.cover(line, rect, Skins.WHEN_PX, "", frame)
	_ok(cov != null and cov.get_size().x >= 100, "a line's cover was not drawn")
	var prog := Skins.program(line, "line", 4.0, cov, rect)
	# ...IN SHORT PULLS (the user: "Nobody strokes a line perfectly all in one fell swoop"): none longer than a pull, each after the first
	# begun back over the last one's end (or going over part of it again), lifted between. THE CONTROL: its runs alone are longer
	var pulls: Array = prog["strokes"]
	var longest := 0.0
	var joined := true
	for k in pulls.size():
		var pp: PackedVector2Array = (pulls[k] as Dictionary)["pts"]
		longest = maxf(longest, pp[pp.size() - 1].x - pp[0].x)
		if k > 0:
			var was: PackedVector2Array = (pulls[k - 1] as Dictionary)["pts"]
			joined = joined and pp[0].x < was[was.size() - 1].x
	_ok(pulls.size() >= int(ceil(100.0 / Skins.PULL.y)) and longest <= Skins.PULL.y + 0.5 * Skins.PULL.x + 0.01,
		"a 100 mm line is not drawn in short pulls: %d, the longest %.1f mm" % [pulls.size(), longest])
	_ok(joined, "a line's pulls do not each begin back over the one before")
	var lifts := 0
	for k in range(1, (prog["keys"] as Array).size()):
		var kk: Array = prog["keys"][k]
		lifts += 1 if float(kk[3]) > 0.5 and float((prog["keys"][k - 1] as Array)[4]) > 0.5 else 0
	_ok(lifts >= pulls.size() - 1, "a line is not lifted between its pulls: %d lifts for %d pulls" % [lifts, pulls.size()])
	var line_runs := Skins._strokes_of(String(line["d"]))
	var run_most := 0.0
	for rr in line_runs:
		run_most = maxf(run_most, (rr as PackedVector2Array)[(rr as PackedVector2Array).size() - 1].x - (rr as PackedVector2Array)[0].x)
	_ok(run_most > Skins.PULL.y * 2.0, "THE CONTROL: the line's runs alone are only %.1f mm" % run_most)
	# A SHAPE AT A TIME (feedback 0022: green laid "on one eye, and another stroke on the other eye, then back to the first eye"): a fill of
	# two squares apart is swept in one before the other is begun. THE CONTROL: rows taken over both at once go back and forth
	var two := {"id": "two", "kind": "fill", "d": "M 20 60 L 50 60 L 50 90 L 20 90 Z M 90 60 L 120 60 L 120 90 L 90 90 Z", "stage": "", "paint": "#2a8a4a",
		"finish": "matte", "opacity": 1.0, "soft": 0.0}
	var r_two := Skins.rect_of(two, frame, 2.0)
	var c_two := Skins.cover(two, r_two, Skins.WHEN_PX, "", frame)
	var sides := func(sts: Array) -> int:
		var turns := 0
		var last_side := -1
		for st in sts:
			var sp: PackedVector2Array = (st as Dictionary)["pts"] if st is Dictionary else st
			var side := 0 if sp[0].x < 70.0 else 1
			turns += 1 if last_side >= 0 and side != last_side else 0
			last_side = side
		return turns
	var swept: int = sides.call(Skins.program(two, "sweep", 6.0, c_two, r_two)["strokes"])
	_ok(swept == 1, "a fill of two shapes goes from one to the other %d times" % swept)
	var both: int = sides.call(Skins._rows(c_two, r_two, 6.0 * Skins.ROWS))
	_ok(both > 3, "THE CONTROL: rows over both shapes at once go between them only %d times" % both)
	_ok(float(prog["natural"]) > 100.0 / Skins.LINE_SPEED, "a line takes %.1f s, less than its length at a hand's pace" % float(prog["natural"]))
	var wm := Skins.when_map(prog, rect)
	var at := func(x: float) -> float: return wm.get_pixel(int((x - rect.position.x) * Skins.WHEN_PX), int((50.0 - rect.position.y) * Skins.WHEN_PX)).r
	var rising := true
	var falling := true
	var last := -1.0
	for x in range(22, 119, 4):
		var u: float = at.call(float(x))
		rising = rising and u >= last - 1e-4
		last = u
	last = -1.0
	for x in range(118, 21, -4):
		var u2: float = at.call(float(x))
		falling = falling and u2 >= last - 1e-4
		last = u2
	_ok(rising, "the line's reveal map does not rise from its start to its end")
	_ok(not falling, "THE CONTROL: read backward along the line its reveal map rises too")
	# (its end among the last of it: a load run out on the way, and a pull gone over again, come after)
	_ok(at.call(22.0) < 0.15 and at.call(118.0) > 0.6, "the line is not revealed from its start (%.2f) to its end (%.2f)" % [at.call(22.0), at.call(118.0)])
	# A STIPPLE begins at its middle and ends at its rim
	var disc := {"id": "disc", "kind": "fill", "d": "M 75 55 A 30 30 0 1 1 75 115 A 30 30 0 1 1 75 55 Z", "stage": "", "paint": "#ffffff", "finish": "matte", "opacity": 1.0, "soft": 0.0}
	var r2 := Skins.rect_of(disc, frame, 2.0)
	var c2 := Skins.cover(disc, r2, Skins.WHEN_PX, "", frame)
	var p2 := Skins.program(disc, "stipple", 12.0, c2, r2)
	var w2 := Skins.when_map(p2, r2)
	var mid: float = w2.get_pixel(int((75.0 - r2.position.x) * Skins.WHEN_PX), int((85.0 - r2.position.y) * Skins.WHEN_PX)).r
	var edge: float = w2.get_pixel(int((103.0 - r2.position.x) * Skins.WHEN_PX), int((85.0 - r2.position.y) * Skins.WHEN_PX)).r
	_ok(mid < edge, "a stipple does not go from its middle (%.2f) outward (%.2f)" % [mid, edge])
	# ...AN AREA FINISHED BEFORE THE NEXT (feedback 0034: "dabbing around the outside of the face now, when there are huge, visible gaps
	# still at and around the nose"): no press comes back far inside where the presses have already been - where two passes one after
	# the other, out to the rim and back from the middle, did
	var bd := {"id": "bd", "kind": "fill", "d": "M 75 35 A 70 70 0 1 1 75 175 A 70 70 0 1 1 75 35 Z", "stage": "", "paint": "#ffffff", "finish": "matte", "opacity": 1.0, "soft": 0.0}
	var rbd := Skins.rect_of(bd, frame, 2.0)
	var cbd := Skins.cover(bd, rbd, Skins.WHEN_PX, "", frame)
	var gap := 12.0 * Skins.DABS
	var pbd := Skins.program(bd, "stipple", 12.0, cbd, rbd)
	var order: Array = (pbd["strokes"] as Array).map(func(st: Dictionary) -> Vector2: return (st["pts"] as PackedVector2Array)[0])
	var passes: Array = Skins._dabs(cbd, rbd, gap, 0) + Skins._dabs(cbd, rbd, gap, 1)
	var back := func(o: Array) -> float:
		var far := 0.0
		var worst := 0.0
		for q in o:
			var d := (q as Vector2).distance_to(o[0] as Vector2)
			worst = maxf(worst, far - d)
			far = maxf(far, d)
		return worst / gap
	_ok(back.call(order) < 3.0, "a stipple comes back %.1f presses inside where it has been" % back.call(order))
	_ok(back.call(passes) > 5.0, "THE CONTROL: two passes one after the other come back only %.1f presses inside" % back.call(passes))
	# IT RUNS DRY: back to its paint after a load's presses - EACH LOAD ITS OWN LENGTH (the user: "every 16 dabs is going to be strange
	# ... because it's constant"), a load as much of the face as LOAD_AREA_DABS, give or take - each laying less than the first of its
	# load, and the same design drawn the same way again: a face's worth of it, several loads
	var big := {"id": "big", "kind": "fill", "d": "M 75 35 A 70 70 0 1 1 75 175 A 70 70 0 1 1 75 35 Z", "stage": "", "paint": "#ffffff", "finish": "matte", "opacity": 1.0, "soft": 0.0}
	var rb := Skins.rect_of(big, frame, 2.0)
	p2 = Skins.program(big, "stipple", 12.0, Skins.cover(big, rb, Skins.WHEN_PX, "", frame), rb)
	var trips: Array = []
	for k in range(1, (p2["keys"] as Array).size()):
		if int((p2["keys"][k] as Array)[5]) == 1 and int((p2["keys"][k - 1] as Array)[5]) != 1:
			trips.append(float((p2["keys"][k] as Array)[0]))
	var runs: Array = [[]]
	for st in p2["strokes"]:
		var at_t := float((st["t"] as PackedFloat32Array)[0])
		while runs.size() - 1 < trips.size() and at_t > float(trips[runs.size() - 1]):
			runs.append([])
		(runs.back() as Array).append(float((st["load"] as PackedFloat32Array)[0]))
	var sizes: Array = runs.slice(0, runs.size() - 1).map(func(r: Array) -> int: return r.size())
	_ok(sizes.size() >= 3 and sizes.max() - sizes.min() >= 3, "a stipple's loads are not each their own length: %s" % [sizes])
	var ends: Array = runs.slice(0, runs.size() - 1).map(func(r: Array) -> float: return float(r.back()))
	_ok(runs.slice(0, runs.size() - 1).all(func(r: Array) -> bool: return float(r[0]) > float(r.back()) + 0.2),
		"a stipple's presses do not lay less as its load runs out: %s" % [runs.slice(0, 2)])
	var all_laid: Array = []
	for r in runs:
		all_laid.append_array(r)
	_ok(all_laid.min() >= Skins.LAYS_LEAST - 1e-4, "a press laid nothing at all: %.3f" % float(all_laid.min()))
	# ...EACH PRESS ITS OWN ("each application might use a different amount"): not one load's presses laying less every time
	_ok(runs.any(func(r: Array) -> bool:
			for i in range(1, r.size()):
				if float(r[i]) > float(r[i - 1]) + 0.05:
					return true
			return false), "every press lays less than the one before it, as if each took the same share")
	var again := Skins.program(big, "stipple", 12.0, Skins.cover(big, rb, Skins.WHEN_PX, "", frame), rb)
	_ok(str(again["keys"]) == str(p2["keys"]), "the same design is not painted the same way twice")
	var lo := 1.0
	var hi := 0.0
	for y in w2.get_height():
		for x in w2.get_width():
			if c2.get_pixel(x, y).a > 0.5:
				lo = minf(lo, w2.get_pixel(x, y).g)
				hi = maxf(hi, w2.get_pixel(x, y).g)
	_ok(hi > 0.99 and lo < Skins.DRY_DABS + 0.1, "the stipple's reveal map does not say how much each press laid: %.2f to %.2f" % [lo, hi])
	# THE CONTROL: a line lays as much at its end as at its start (a liner never runs pale)
	var line_lo := 1.0
	for st in prog["strokes"]:
		for v in (st as Dictionary)["load"]:
			line_lo = minf(line_lo, float(v))
	_ok(line_lo > 0.999, "THE CONTROL: a line lays less as it goes: %.2f at the least" % line_lo)
	# ...NOW AND THEN PUSHED ON, nearly dry ("a person might choose to apply the dabbing even when they have very little product"): over a
	# whole face's base some load is run down far past where most go back; and a sweep, gone over once, never pale (a stripe to the end)
	var face := {"id": "base", "kind": "fill", "d": "all", "stage": "", "paint": "#ffffff", "finish": "matte", "opacity": 1.0, "soft": 0.0}
	var rf := Skins.rect_of(face, frame, 2.0)
	var cf := Skins.cover(face, rf, Skins.WHEN_PX, FaceForm.outline_path(FaceForm.SIZE), frame)
	var pf := Skins.program(face, "stipple", 16.0, cf, rf)
	var faintest := 1.0
	for st in pf["strokes"]:
		faintest = minf(faintest, float((st["load"] as PackedFloat32Array)[0]))
	_ok(faintest < Skins.DRY_DABS * 0.5, "no load of a face's base is ever pushed on past where most go back: the faintest press lays %.2f" % faintest)
	var sweep := Skins.program(face, "sweep", 10.0, cf, rf)
	var sweep_lo := 1.0
	for st in sweep["strokes"]:
		for v in (st as Dictionary)["load"]:
			sweep_lo = minf(sweep_lo, float(v))
	_ok(sweep_lo > Skins.DRY_SWEEP - 0.08, "a sweep lays a stroke as pale as %.2f: a stripe in its fill to the end" % sweep_lo)
	return true


func _hairs() -> bool:
	var drag := func(t: float) -> Array:
		var v := Vector3(0.05, 0.0, 0.0) if t < 1.0 else Vector3.ZERO
		return Bristles.target(v, 1.0 if t < 1.0 else 0.0, 0.02, Vector3.UP)
	var during: Array = Bristles.response(drag, 0.8)
	_ok((during[0] as Vector3).x < -0.002, "dragged right, the hairs do not lean left: %s" % during[0])
	var most := 0.0
	for k in 40:
		var b: Array = Bristles.response(drag, 1.0 + float(k) * 0.01)
		most = maxf(most, (b[0] as Vector3).x)
	_ok(most > 0.0002, "let go, the hairs do not swing past straight")
	var late: Array = Bristles.response(drag, 2.5)
	_ok((late[0] as Vector3).length() < 1e-4, "the hairs have not settled 1.5 s after they were let go: %s" % late[0])
	var none: Array = Bristles.response(func(_t: float) -> Array: return Bristles.target(Vector3.ZERO, 0.0, 0.02, Vector3.UP), 1.0)
	_ok((none[0] as Vector3).length() < 1e-9 and float(none[1]) < 1e-9, "THE CONTROL: a brush neither dragged nor pressed is bent")
	# HAIRS HAVE ONE LENGTH (feedback 0030): lifted straight off its surface, a brush's hairs are not pulled out after it - and pressed,
	# leaning, they fold across themselves the way its tip goes, never up into the handle (feedback 0029, 6 mm off the face)
	var lifted: Array = Bristles.target(Vector3(0.0, 0.08, 0.0), 1.0, 0.02, Vector3.UP)
	_ok((lifted[0] as Vector3).length() < 1e-9, "lifted straight off, the hairs are pulled along themselves: %s" % lifted[0])
	var axis := Vector3(0.0, 0.8, 0.6).normalized()
	var pressed: Array = Bristles.target(Vector3.ZERO, 1.0, 0.02, axis, Vector3(0.0, 0.0, -1.0))
	var pb: Vector3 = pressed[0]
	_ok(absf(pb.dot(axis)) < 1e-6 and pb.length() > 0.002 and pb.z < 0.0,
		"pressed, leaning, the hairs fold aside the way the tip goes: %s, %.6f m of it along them" % [pb, pb.dot(axis)])
	var old_fold := axis * Bristles.PRESS_BEND * 0.02
	_ok(absf(old_fold.dot(axis)) > 0.004, "THE CONTROL: the fold as it was, the handle's way, is along the hairs: %.4f m" % old_fold.dot(axis))
	# ...and bent aside, a hair is as long as it was (to a two-hundredth), where the bend as drawn before grew it
	var worst := 0.0
	var worst_was := 0.0
	for k in 7:
		var bend := 0.02 * 0.1 * float(k)
		var run := 0.0
		var run_was := 0.0
		var last := Vector2.ZERO
		var last_was := Vector2.ZERO
		for i in range(1, 201):
			var s := float(i) / 200.0
			var q := Bristles.bent_at(s, bend, 0.02)
			var q_was := Vector2(bend * s * s, 0.02 * s - 0.5 * bend * bend / 0.02 * s * s * s)
			run += q.distance_to(last)
			run_was += q_was.distance_to(last_was)
			last = q
			last_was = q_was
		worst = maxf(worst, absf(run / 0.02 - 1.0))
		worst_was = maxf(worst_was, absf(run_was / 0.02 - 1.0))
	_ok(worst < 0.005, "a hair bent aside keeps its length to %.2f%%" % (worst * 100.0))
	_ok(worst_was > 0.02, "THE CONTROL: bent as it was drawn before, a hair grew by %.1f%%" % (worst_was * 100.0))
	var tip := Bristles.bent_at(1.0, 0.008, 0.02)
	_ok(absf(tip.x - 0.008) < 1e-5, "a hair bent 8 mm aside has its tip 8 mm aside: %.5f m" % tip.x)
	return true


## A MASK ON ITS STAND, a jar of brushes, a sponge on its dish and two pots of paint - the station, in centimeters.
static func station() -> Dictionary:
	return {"things": [
		{"name": "mask", "at": [0, -6], "parts": [
			{"shape": "box", "size": [12, 2, 10], "material": "walnut"},
			{"shape": "tube", "path": [[0, 2, -5], [0, 15, -5]], "radius": 0.8, "material": "walnut"},
			{"name": "face", "shape": "mask", "size": [15, 21, 8], "at": [0, 13, -4], "skin": true, "material": "bisque"}]},
		{"name": "brush jar", "at": [18, 4], "parts": [
			{"shape": "lathe", "profile": [[0, 0], [3, 0], [3, 8], [2.7, 8], [2.7, 0.5], [0, 0.5]], "material": "glaze"},
			{"name": "liner", "joint": {"kind": "free"}, "at": [0, 0.5, 0], "turn": [0, 0, 8], "parts": [
				{"shape": "tube", "path": [[0, 0, 0], [0, 14, 0]], "radius": 0.3, "material": "walnut"},
				{"shape": "lathe", "profile": [[0, 0], [0.32, 0], [0.26, 1.5], [0, 1.5]], "at": [0, 14, 0], "material": "brass"},
				{"shape": "tuft", "kind": "liner", "length": 2.4, "width": 0.3, "at": [0, 15.5, 0], "material": "sable"}]}]},
		{"name": "sponge", "at": [-16, 8], "parts": [
			{"shape": "lathe", "profile": [[0, 0], [5, 0], [5.5, 1], [0, 1]], "material": "glaze"},
			{"name": "wedge", "shape": "box", "size": [4, 2.5, 3], "at": [0, 1, 0], "joint": {"kind": "free"}, "material": "foam"}]},
		{"name": "white pot", "at": [-9, 12], "parts": [
			{"shape": "lathe", "profile": [[0, 0], [2.5, 0], [2.5, 2], [2.2, 2], [2.2, 0.4], [0, 0.4]], "material": "glaze"},
			{"shape": "lathe", "profile": [[0, 0.4], [2.2, 0.4], [2.2, 1.6], [0, 1.6]], "material": "white paint"}]},
		{"name": "water cup", "at": [22, -6], "parts": [
			{"shape": "lathe", "profile": [[0, 0], [3, 0], [3.2, 7], [2.95, 7], [2.75, 0.4], [0, 0.4]], "material": "glaze"},
			{"name": "water", "shape": "lathe", "profile": [[0, 0.4], [2.75, 0.4], [2.95, 5.2], [0, 5.2]], "material": "water"}]},
		{"name": "towel", "at": [-24, -8], "parts": [{"shape": "box", "size": [10, 1.6, 7], "material": "sable"}]},
		{"name": "black pot", "at": [9, 12], "parts": [
			{"shape": "lathe", "profile": [[0, 0], [2.5, 0], [2.5, 2], [2.2, 2], [2.2, 0.4], [0, 0.4]], "material": "glaze"},
			{"shape": "lathe", "profile": [[0, 0.4], [2.2, 0.4], [2.2, 1.6], [0, 1.6]], "material": "black paint"}]}],
		"materials": {"walnut": {"kind": "wood", "color": "#3a2a1e"}, "bisque": {"kind": "ceramic", "color": "#ebe5da", "polish": 0.05},
			"glaze": {"kind": "ceramic", "color": "#202226", "polish": 0.8}, "brass": {"kind": "metal", "color": "#b08d3c"},
			"sable": {"kind": "fabric", "color": "#5a3a24"}, "foam": {"kind": "sponge", "color": "#f0d6c4"},
			"white paint": {"kind": "cream", "color": "#f6f2ea"}, "black paint": {"kind": "cream", "color": "#121214"},
			"water": {"kind": "liquid", "color": "#c9d8dc", "clarity": 0.8}}}


static func design() -> Dictionary:
	return {"designs": [{"thing": "mask", "part": "face", "name": "a test", "elements": [
		{"id": "base", "stage": "base", "paint": "#f6f2ea", "fill": "all"},
		{"id": "brow", "stage": "lines", "paint": "#121214", "line": "M 30 72 C 40 58 58 55 66 62", "width": 1.4}]}]}


func _paints() -> bool:
	var m := _medium()
	var spec := station()
	var at := {"mask": Vector3(0, 0, -0.06), "brush jar": Vector3(0.18, 0, 0.04), "sponge": Vector3(-0.16, 0, 0.08),
		"white pot": Vector3(-0.09, 0, 0.12), "black pot": Vector3(0.09, 0, 0.12)}
	for nm in at:
		_stand(m, spec, nm, Vector3(Tables.ORIGIN.x, 0.0, Tables.ORIGIN.y) + (at[nm] as Vector3))
	m._work.skin_doc = design()
	var acts := {"acts": [
		{"name": "base", "beat": 1, "length": "under", "about": "the base stippled on",
			"tracks": [{"thing": "sponge", "part": "wedge", "law": "paint", "on": "mask/face", "paint": ["base"], "from": "white pot"}]},
		{"name": "brow", "beat": 2, "length": "under", "about": "a brow drawn",
			"tracks": [{"thing": "brush jar", "part": "liner", "law": "paint", "on": "mask", "paint": ["brow", "no such"], "from": "black pot"}]}]}
	var bare_acts: Dictionary = acts.duplicate(true)
	m._work.build(acts, 2)
	_ok((m._work.acts as Array).size() == 2, "the paint acts were not kept: %s" % "; ".join(m._work.notes))
	_ok(m._work.paint != null and m._work.paint.skins.size() == 1, "the mask's face is not a skin on the table")
	if (m._work.acts as Array).size() < 2 or m._work.paint == null or m._work.paint.skins.is_empty():
		return true
	_ok(Array(m._work.notes).any(func(n: String) -> bool: return n.contains("no such")), "an element the design does not have is not said: %s" % "; ".join(m._work.notes))
	# A SURFACE WITH NO DESIGN: the same acts refused, and why said (joker-motivation 856886: a puppeteer's preview had no
	# `skin.json`, every act was taken, painted nothing and pressed its tool into the bare mask) - the acts above, kept, the control
	var bare := _medium()
	for nm in at:
		_stand(bare, spec, nm, Vector3(Tables.ORIGIN.x, 0.0, Tables.ORIGIN.y) + (at[nm] as Vector3))
	bare._work.skin_doc = {}
	bare._work.build(bare_acts, 2)
	_ok((bare._work.acts as Array).is_empty(), "a paint act on a surface with no design is taken: %d acts" % (bare._work.acts as Array).size())
	_ok(Array(bare._work.notes).any(func(n: String) -> bool: return n.contains("no design yet")), "a surface with no design is not said: %s" % "; ".join(bare._work.notes))
	for a in m._work.acts:
		_ok(float((a as Dictionary).get("_natural", 0.0)) > 5.0, "%s has no length at a hand's pace" % (a as Dictionary)["name"])
	var times: Dictionary = m._work.rehearse(10.0)
	var tp: TablePaint = m._work.paint
	var si := 0
	var face_mesh := TableWork._ray_mesh(_faces_of(tp.skins[si]))
	var lw: int = m._work._work_of(m._work._thing_named("brush jar"), "liner")
	var tool: Dictionary = tp.tools.get("w%d:pose" % lw, {})
	_ok(String(tool.get("kind", "")) == "brush", "the liner is not a brush: %s" % tool.get("kind", ""))
	var tip_l: Vector3 = tool.get("tip", Vector3.ZERO)
	var brow: Array = times["brow"]
	var base: Array = times["base"]
	_ok(float(base[1]) <= float(brow[0]) + 1e-3, "the brow is drawn before the base is laid")
	# THE CONTROL: at rest the liner's tip is far from the face
	m._work._planned = true
	m._work.tick(float(brow[0]) - 0.5)
	var rest_tip := m._work._world_of((m._work.works[lw] as Dictionary)["node"]) * tip_l
	_ok(_off_face(face_mesh, tp, si, rest_tip) > 0.03, "THE CONTROL: the liner at rest is on the face")
	# ...NEVER LIFTED ALONG A STROKE (feedback 0019, 0021: a liner 11 mm and a flat brush 17 mm over a mask's rim, painting in the air - the
	# lift that clears a tool on its way between two dabs had been found between two keys of one pressed stroke, divided by the lift's own
	# shape beside a key): wherever a program is pressed at a key and at the next, nothing lifts it between. THE CONTROL: between keys not
	# both pressed, a way is lifted somewhere - the lifts are found at all. (This station's mask never met it: a mask lying back on its
	# cradle by the board did - `episode_bake_probe --audit` says a painting tool off what it paints)
	var along_lift := 0.0
	var between_lift := 0.0
	for key in (tp.skins[si].get("held", {}) as Dictionary):
		var kept: Dictionary = tp.skins[si]["held"][key]
		var arcs: PackedFloat32Array = kept.get("arcs", PackedFloat32Array())
		var prog_keys: Array = []
		for made in tp._made.values():
			var pp: Dictionary = (made as Dictionary).get("program", {})
			if not pp.is_empty() and String(key).begins_with(String(pp.get("id", "")) + "|"):
				prog_keys = pp["keys"]
		for k in mini(arcs.size(), prog_keys.size() - 1):
			var pressed := float((prog_keys[k] as Array)[4]) > 0.5 and float((prog_keys[k + 1] as Array)[4]) > 0.5
			if pressed:
				along_lift = maxf(along_lift, arcs[k])
			else:
				between_lift = maxf(between_lift, arcs[k])
	_ok(along_lift == 0.0, "a tool is lifted %.1f mm along a stroke it presses on" % (along_lift * 1000.0))
	_ok(between_lift > 0.0, "THE CONTROL: no tool is ever lifted on its way between strokes")
	# ...WHILE IT DRAWS, its tip on the face; lifted between strokes
	var plan := tp.plan_of(_track_of(m, "brow"), float(brow[1]) - float(brow[0]))
	var drawing := 0
	var worst := 0.0
	var lifted := 0.0
	for p in plan["phases"]:
		var pd: Dictionary = p
		if String(pd["kind"]) != "el":
			continue
		var prog: Dictionary = pd["prog"]
		var k := (float(pd["b"]) - float(pd["a"])) / float(prog["natural"])
		for key in prog["keys"]:
			var kk: Array = key
			var t := float(brow[0]) + float(pd["a"]) + float(kk[0]) * k
			m._work.tick(t)
			var tip := m._work._world_of((m._work.works[lw] as Dictionary)["node"]) * tip_l
			var off := _off_face(face_mesh, tp, si, tip)
			if float(kk[4]) >= 0.99:
				drawing += 1
				worst = maxf(worst, absf(off))
			elif float(kk[3]) > 2.0:
				lifted = maxf(lifted, off)
	_ok(drawing >= 4, "the liner never draws: %d moments pressed" % drawing)
	_ok(worst < 0.001, "the liner's tip leaves the face by %.2f mm while it draws" % (worst * 1000.0))
	_ok(lifted > 0.002, "the liner is not lifted between strokes (%.2f mm at most)" % (lifted * 1000.0))
	# ...back in its jar when the act is done
	m._work.tick(float(brow[1]) + 0.5)
	var home := m._work._world_of((m._work.works[lw] as Dictionary)["node"]) * tip_l
	_ok(home.distance_to(rest_tip) < 0.002, "the liner is not back where it rests: %.1f mm off" % (home.distance_to(rest_tip) * 1000.0))
	# ...ITS HAIRS BENT ONTO THE FACE WHEREVER IT IS PRESSED (the forehead's stars and brows, painted with nothing; a lower lip's outline
	# drawn 2-8 mm up on the lip): held by its tip and pressed at places all over the face, the tip as its hairs are bent lies within a
	# touch of it at nearly every one - where the bend had been counted along the face's normal and stepped to by the slope alone (the
	# control), off it by more at many
	var tip_on := [0, 0, 0]
	var frame: Vector2 = tp.skins[si]["frame"]
	var g_face := tp._obstacles(tp.skins[si])
	var to_part: Transform3D = g_face["to_part"]
	for gy in range(1, 16):
		for gx in range(1, 12):
			var xy := Vector2(frame.x * float(gx) / 12.0, frame.y * float(gy) / 16.0)
			var cl := tp._cleared(si, xy, tool, "tip")
			var hh := tp._skin_hold(si, xy, 0.0, 1.0, 0.0, tool, "tip", cl, cl, 0.0)
			var node := tp._node_at(hh, tool, tool["x0"])
			if TablePaint._front_z(g_face, to_part * (node * tip_l)) == -INF:
				continue
			var axis: Vector3 = (hh[1] as Vector3).normalized()
			var n: Vector3 = hh[7]
			var fold: Vector3 = Bristles.target(Vector3.ZERO, 1.0, float(tool["len"]), axis, -(axis - n * axis.dot(n)))[0]
			var bent := tp._bend_to_surface(si, tool, hh, fold)
			var tip_now := to_part * (node * TablePaint._bent_tip(tool, node.basis.inverse() * bent))
			# (the control, as it was: how far over the face the straight tip is, read off the cell it is in, taken back along the normal)
			var mv := (n - axis * axis.dot(n)).normalized()
			var straight := to_part * (node * tip_l)
			var at_g: Vector2 = g_face["at"]
			var cells: Vector2i = g_face["n"]
			var zs: PackedFloat32Array = g_face["z"]
			var ci := clampi(int((straight.x - at_g.x) / TablePaint.CLEAR_CELL), 0, cells.x - 1)
			var cj := clampi(int((straight.y - at_g.y) / TablePaint.CLEAR_CELL), 0, cells.y - 1)
			var toward := clampf(-(straight.z - zs[cj * cells.x + ci]) / maxf(mv.dot(n), 0.2), -float(tool["len"]) * 0.6, float(tool["len"]) * 0.6)
			var tip_was := to_part * (node * TablePaint._bent_tip(tool, node.basis.inverse() * (fold - mv * fold.dot(mv) + mv * toward)))
			tip_on[0] += 1
			if absf(tip_now.z - TablePaint._front_z(g_face, tip_now)) <= TablePaint.TOUCH_BAND:
				tip_on[1] += 1
			if absf(tip_was.z - TablePaint._front_z(g_face, tip_was)) <= TablePaint.TOUCH_BAND:
				tip_on[2] += 1
	print("  the liner's bent tip within a touch of the face at %d of %d places (bent along the normal, %d)" % [tip_on[1], tip_on[0], tip_on[2]])
	_ok(tip_on[0] >= 60 and tip_on[1] >= tip_on[0] * 0.9,
		"the liner's bent tip lies within a touch of the face at %d of %d places it is pressed" % [tip_on[1], tip_on[0]])
	_ok(tip_on[2] < tip_on[1] - tip_on[0] * 0.1,
		"THE CONTROL: bent along the face's normal, the liner's tip lay within a touch of it at %d of %d places" % [tip_on[2], tip_on[0]])
	# ...AND IT GOES BACK OVER WHAT IT MISSED (feedback 0035, as a sponge does): what its hairs, bent as they are drawn, left bare of the
	# brow looked at and dabbed again until little is - the first look the control
	var brow_made: Dictionary = ((tp.skins[si]["items"] as Dictionary).get("brow", {}) as Dictionary).get("made", {})
	var brow_bare: PackedFloat32Array = brow_made.get("gaps", PackedFloat32Array())
	print("  the brow left bare at each look: %s mm2" % [brow_bare])
	_ok(brow_bare.size() >= 2 and brow_bare[brow_bare.size() - 1] < brow_bare[0] * 0.5,
		"what the liner left bare of the brow was not put right: %s mm2 at each look" % [brow_bare])
	_ok(brow_bare.size() >= 1 and brow_bare[0] > 0.0, "THE CONTROL: the brow's strokes as planned left nothing bare to put right")
	# THE SPONGE stippling the base is on the face as it presses
	var sw: int = m._work._work_of(m._work._thing_named("sponge"), "wedge")
	var stool: Dictionary = tp.tools.get("w%d:pose" % sw, {})
	_ok(String(stool.get("kind", "")) == "sponge", "the wedge is not a sponge: %s" % stool.get("kind", ""))
	var corner: Dictionary = (stool.get("contacts", {}) as Dictionary).get("corner", {})
	_ok(not corner.is_empty(), "a sponge has no corner to dab with: %s" % [(stool.get("contacts", {}) as Dictionary).keys()])
	var corner_tip: Vector3 = corner.get("tip", stool.get("tip", Vector3.ZERO))
	var corner_grip: Vector3 = corner.get("grip", stool.get("grip", Vector3.UP))
	var bplan := tp.plan_of(_track_of(m, "base"), float(base[1]) - float(base[0]))
	var pressed := 0
	var on_face := 0
	var sworst := 0.0
	var stood_off := 0.0
	for p in bplan["phases"]:
		var pd: Dictionary = p
		if String(pd["kind"]) != "el":
			continue
		var prog: Dictionary = pd["prog"]
		var k := (float(pd["b"]) - float(pd["a"])) / float(prog["natural"])
		var keys: Array = prog["keys"]
		var held: PackedVector4Array = ((tp.skins[si]["held"] as Dictionary).get(TablePaint._held_key(prog, "w%d:pose" % sw, "corner"), {}) as Dictionary).get("held", PackedVector4Array())
		# (forty of its pressed keys, spread through it - a stride over all its keys had fallen on its lifts alone)
		var pressed_at: Array = []
		for j in keys.size():
			if float((keys[j] as Array)[4]) >= 0.99 and int((keys[j] as Array)[5]) == 0:
				pressed_at.append(j)
		for pj in range(0, pressed_at.size(), maxi(pressed_at.size() / 40, 1)):
			var j: int = pressed_at[pj]
			var kk: Array = keys[j]
			m._work.tick(float(base[0]) + float(pd["a"]) + float(kk[0]) * k)
			# ...BY ITS CORNER, where the foam gives back to as it is pressed ([constant TablePaint.GIVE]) - stood off where the face round
			# it leaves its corner no room ([method TablePaint._cleared])
			var nx := m._work._world_of((m._work.works[sw] as Dictionary)["node"])
			# (as hard as it presses: a press put in where the first missed is harder, TablePaint.PRESS_HARD)
			var tip := nx * corner_tip + (nx.basis * (corner_grip - corner_tip)).normalized() * TablePaint.GIVE * float(kk[4])
			var off := _off_face(face_mesh, tp, si, tip)
			var owed := held[j].w if j < held.size() else 0.0
			stood_off = maxf(stood_off, owed)
			pressed += 1
			# (a press on the rim itself is past where a ray straight in finds the face)
			if off < INF:
				sworst = maxf(sworst, absf(off - owed))
				on_face += 1
	_ok(pressed >= 10 and on_face >= pressed * 0.8 and sworst < 0.0015, "the sponge's corner is not on the face as it stipples: %d presses, %d found on it, %.2f mm off at worst" % [pressed, on_face, sworst * 1000.0])
	_ok(stood_off < 0.004, "the sponge's corner is stood %.1f mm off the face to clear it" % (stood_off * 1000.0))
	# EACH ELEMENT LAID WHILE ITS ACT RUNS
	var items: Dictionary = tp.skins[si]["items"]
	_ok(items.has("base") and items.has("brow"), "the elements laid have no place in the skin's canvas: %s" % [items.keys()])
	if items.has("brow"):
		var span: Vector2 = (items["brow"] as Dictionary)["span"]
		_ok(span.x >= float(brow[0]) and span.y <= float(brow[1]) and span.y > span.x, "the brow is laid at %s, outside its act %s" % [span, brow])
	# A FUNCTION OF TIME: posed straight away at a moment, as after every moment before it
	m._work.tick(float(brow[0]) + 3.0)
	var walked := m._work._world_of((m._work.works[lw] as Dictionary)["node"])
	m._work.tick(0.0)
	m._work.tick(float(brow[0]) + 3.0)
	var jumped := m._work._world_of((m._work.works[lw] as Dictionary)["node"])
	_ok(walked.origin.distance_to(jumped.origin) < 1e-6, "posed straight away the liner is %.3f mm from where it was posed after the moments before" % (walked.origin.distance_to(jumped.origin) * 1000.0))
	m._work._planned = false
	# `act` SAYS WHAT IT PAINTS
	var said: Dictionary = m._work.check("brow")
	_ok(String(said["text"]).contains("it paints") and String(said["text"]).contains("\"brow\""), "`act` does not say what it paints:\n%s" % said["text"])
	_ok(m._work.parts_report().contains("surface to paint"), "the parts report does not say what can be painted")
	# THE FACE PAINTED FIRST CARRIED BY THE PAINT (feedback 0023): a design copied from a painting lays each element with the painting
	# beside its own paint, knowing where its picture lies on the surface - THE CONTROL: a design with none lays its paint alone
	var with_ref: Dictionary = design()
	var ref := Image.create(450, 630, false, Image.FORMAT_RGBA8)
	ref.fill(Color(0.8, 0.1, 0.1))
	with_ref["_reference"] = ref
	with_ref["_reference_on"] = "mask/face"
	tp.set_designs(with_ref)
	tp._canvas(si)
	var brow_mats: Array = ((tp.skins[si]["items"] as Dictionary).get("brow", {}) as Dictionary).get("mats", [])
	var ruv: Vector4 = (brow_mats[0] as ShaderMaterial).get_shader_parameter("rect_uv") if not brow_mats.is_empty() else Vector4.ZERO
	_ok(not brow_mats.is_empty() and (brow_mats[0] as ShaderMaterial).get_shader_parameter("referenced") == true
		and (brow_mats[0] as ShaderMaterial).get_shader_parameter("reference") is Texture2D and ruv.x > 0.0 and ruv.y > 0.0 and ruv.x + ruv.z <= 1.0 and ruv.y + ruv.w <= 1.0,
		"the brow is not laid with the painting it was copied from, where its picture lies (%s)" % ruv)
	tp.set_designs(design())
	tp._canvas(si)
	var plain_mats: Array = ((tp.skins[si]["items"] as Dictionary).get("brow", {}) as Dictionary).get("mats", [])
	_ok(not plain_mats.is_empty() and (plain_mats[0] as ShaderMaterial).get_shader_parameter("referenced") != true,
		"THE CONTROL: a design copied from no painting lays the brow with one")
	return true


## A HELD TOOL STANDS IN NOTHING (feedback 0016: "This sponge is clipping right through the nose", and through a pot as it took its
## paint): a sponge stippling by its corner and blending flat over a whole face, nose and all, never deeper in it than it gives; dipped
## by its end into a pot narrower than its face and pressed flat on its paint, nothing of it as drawn past the pot's wall. THE
## CONTROLS: blended with nothing held clear, it goes into the nose; held flat in the pot, through its wall; never flattened, under the
## paint; held by its corner through its middle, on the paint at a point.
func _held() -> bool:
	var m := _medium()
	var spec := station()
	var at := {"mask": Vector3(0, 0, -0.06), "sponge": Vector3(-0.16, 0, 0.08), "white pot": Vector3(-0.09, 0, 0.12)}
	for nm in at:
		_stand(m, spec, nm, Vector3(Tables.ORIGIN.x, 0.0, Tables.ORIGIN.y) + (at[nm] as Vector3))
	m._work.skin_doc = {"designs": [{"thing": "mask", "part": "face", "name": "a base", "elements": [{"id": "base", "stage": "base", "paint": "#f6f2ea", "fill": "all"}]}]}
	m._work.build({"acts": [
		{"name": "stipple", "beat": 1, "length": "under", "tracks": [{"thing": "sponge", "part": "wedge", "law": "paint", "on": "mask", "paint": ["base"], "from": "white pot"}]},
		{"name": "blend", "beat": 2, "length": "under", "tracks": [{"thing": "sponge", "part": "wedge", "law": "paint", "on": "mask", "paint": ["base"], "manner": "blend"}]}]}, 2)
	var tp: TablePaint = m._work.paint
	_ok(tp != null and (m._work.acts as Array).size() == 2, "the sponge's acts were not kept: %s" % "; ".join(m._work.notes))
	if tp == null or (m._work.acts as Array).size() < 2:
		return true
	var times: Dictionary = m._work.rehearse(10.0)
	var sw: int = m._work._work_of(m._work._thing_named("sponge"), "wedge")
	var node: Node3D = (m._work.works[sw] as Dictionary)["node"]
	var pts := _box_points(node, m._work)
	var face_mesh := TableWork._ray_mesh(_faces_of(tp.skins[0]))
	var sponge_mat: ShaderMaterial = ((tp.tools["w%d:pose" % sw] as Dictionary)["sponges"][0] as Dictionary)["mat"]
	m._work._planned = true
	# how deep the sponge stands in the face as it is drawn, at most, at every place it keeps through an act, and how many it kept
	var deepest := func(act: String) -> Vector2:
		var t: Array = times[act]
		var plan := tp.plan_of(_track_of(m, act), float(t[1]) - float(t[0]))
		var worst := 0.0
		var count := 0
		for p in plan["phases"]:
			var pd: Dictionary = p
			if String(pd["kind"]) != "el":
				continue
			var keys: Array = (pd["prog"] as Dictionary)["keys"]
			var k := (float(pd["b"]) - float(pd["a"])) / float((pd["prog"] as Dictionary)["natural"])
			# ...at a key, and on its way to the next, a third and two thirds along (between dabs either side of a nose, turned from one
			# way of holding it to the other, it had gone 18 mm into it)
			var moments := PackedFloat32Array()
			for j in range(0, keys.size() - 1, maxi(keys.size() / 120, 1)):
				var ta := float((keys[j] as Array)[0])
				var tb := float((keys[j + 1] as Array)[0])
				for f in [0.0, 0.33, 0.67]:
					moments.append(lerpf(ta, tb, float(f)))
			for tau in moments:
				m._work.tick(float(t[0]) + float(pd["a"]) + tau * k)
				var nx := m._work._world_of(node)
				# ...AS IT IS DRAWN: pressed in, the foam squashed back from its middle as its material has it (prop_common.gdshaderinc)
				var sq: Vector4 = sponge_mat.get_shader_parameter("squash")
				var sq_at: Vector3 = sponge_mat.get_shader_parameter("squash_at")
				var sq_d := Vector3(sq.x, sq.y, sq.z).normalized() if sq.w > 0.0 else Vector3.ZERO
				for q in pts:
					var v: Vector3 = q - sq_d * maxf((q - sq_at).dot(sq_d), 0.0) * sq.w
					var off := _off_face(face_mesh, tp, 0, nx * v)
					if off < INF:
						worst = maxf(worst, -off)
				count += 1
		return Vector2(worst, count)
	var stippled: Vector2 = deepest.call("stipple")
	var blended: Vector2 = deepest.call("blend")
	# (a sponge's face resting on a nose's ridge stands in it as far as the ridge's peak falls between the cells it is found in, and
	# its foam gives round it)
	var within := 0.003
	_ok(stippled.y > 50 and stippled.x < within, "the sponge stippling by its corner stands %.1f mm in the face, over %d places" % [stippled.x * 1000.0, stippled.y])
	_ok(blended.y > 50 and blended.x < within, "the sponge blending flat stands %.1f mm in the face, over %d places" % [blended.x * 1000.0, blended.y])
	# THE CONTROL: nothing held clear, as a hand holds it alone - the flat face over the nose goes into it
	var kept: Dictionary = tp.skins[0]["held"]
	tp.skins[0]["held"] = {}
	var unheld: Vector2 = deepest.call("blend")
	tp.skins[0]["held"] = kept
	_ok(unheld.x > 0.008, "THE CONTROL: blended flat with nothing held clear, the sponge stands only %.1f mm in the face" % (unheld.x * 1000.0))
	# WHAT A PRESS TOUCHES IS WHAT IT PAINTS (feedback 0032: "barely touching the mask with a corner - yet the entire area around it
	# splatters with paint"): the stipple's first press shows no more than about what its corner touches, pressed - where a reveal from
	# its program alone showed every point nearest it; and what no press touched never shows
	var item: Dictionary = (tp.skins[0]["items"] as Dictionary).get("base", {})
	_ok(not item.is_empty(), "the stippled base has no picture")
	if not item.is_empty():
		var made: Dictionary = item["made"]
		var wm: Image = made["when"]
		var prog: Dictionary = made["program"]
		var u0 := float(((prog["strokes"] as Array)[0] as Dictionary)["t"][0]) / float(prog["natural"])
		var wide := tp._touch_width(tp.tools["w%d:pose" % sw], "corner")
		var first_mm2 := func(img: Image) -> float:
			var n := 0
			for y in img.get_height():
				for x in img.get_width():
					if img.get_pixel(x, y).r <= u0 + 1e-4:
						n += 1
			return float(n) / (Skins.WHEN_PX * Skins.WHEN_PX)
		var touched: float = first_mm2.call(wm)
		var disc := PI * wide * wide * 0.25
		_ok(touched > disc * 0.2 and touched < disc * 2.0,
			"the first press shows %.0f mm2 where its corner touches %.0f (%.1f mm across)" % [touched, disc, wide])
		var never_of := func(img: Image) -> int:
			var n := 0
			for y in img.get_height():
				for x in img.get_width():
					if img.get_pixel(x, y).r >= Skins.NEVER:
						n += 1
			return n
		# A HAND GOES BACK OVER WHAT IT MISSED (feedback 0035): what its presses left bare looked at, and pressed again, until little is -
		# the first look, before any press was put in, the control
		var bare: PackedFloat32Array = made.get("gaps", PackedFloat32Array())
		_ok(bare.size() >= 2 and bare[bare.size() - 1] < bare[0] * 0.7,
			"what the stipple left bare was not put right: %s mm2 at each look" % [bare])
		_ok(bare.size() >= 1 and bare[0] > 0.0, "THE CONTROL: the presses as planned left nothing bare to put right")
		# ...AND PUT RIGHT AS SOON AS IT IS SEEN (the user: "They would fix the gaps soon after they first see them ... before moving on to
		# the rest of the face"): a hole the paint has closed round is pressed within seconds, most of them - where the old way, two passes
		# one after the other, held and touched as they would be, left its holes for the second pass to come round to (the control)
		var track := _track_of(m, "stipple")
		var tool_s: Dictionary = tp.tools["w%d:pose" % sw]
		var mm_s := float(tp._layers["0|base"]["mm"])
		var cov_s := Skins.cover(tp.element(0, "base"), made["rect"], Skins.WHEN_PX, String(tp.skins[0].get("outline", "")), tp.skins[0]["frame"])
		# ...ITS EDGE'S MOMENT CARRIED PAST ITS EDGE (520084: a ragged bare band along the rim, 3 mm wide - a press's ragged edge reads the
		# map up to 1.6 mm off each point, and past the face's edge it read points no tool touched): the points two out from what it covers,
		# as far from a point shown, hold a moment - THE CONTROL: the map of the same touches with nothing carried out holds few there (the
		# ring beside the edge is the edge's own, its pixels half covered)
		var shown_at := func(img: Image, x: int, y: int) -> bool:
			return x >= 0 and y >= 0 and x < mini(img.get_width(), cov_s.get_width()) and y < mini(img.get_height(), cov_s.get_height()) \
				and cov_s.get_pixel(x, y).a > 0.5 and img.get_pixel(x, y).r < Skins.NEVER
		var past_edge := func(img: Image) -> Vector2i:
			var n := Vector2i.ZERO
			for y in range(2, mini(img.get_height(), cov_s.get_height()) - 2):
				for x in range(2, mini(img.get_width(), cov_s.get_width()) - 2):
					if cov_s.get_pixel(x, y).a > 0.5:
						continue
					var near := 3
					for dy in range(-2, 3):
						for dx in range(-2, 3):
							if shown_at.call(img, x + dx, y + dy):
								near = mini(near, maxi(absi(dx), absi(dy)))
					if near == 2:
						n.x += 1
						if img.get_pixel(x, y).r < Skins.NEVER:
							n.y += 1
			return n
		var edge_now: Vector2i = past_edge.call(wm)
		var edge_was: Vector2i = past_edge.call(Skins.touch_map(made.get("touches", []), made["rect"]))
		print("  two points past the stipple's edge: %d of %d hold a moment (with nothing carried out, %d of %d)" % [edge_now.y, edge_now.x, edge_was.y, edge_was.x])
		_ok(edge_now.x > 50 and edge_now.y >= edge_now.x * 0.95, "two points past the stipple's edge, %d of %d hold a moment" % [edge_now.y, edge_now.x])
		_ok(edge_was.y < edge_was.x * 0.5, "THE CONTROL: with nothing carried out, %d of %d did" % [edge_was.y, edge_was.x])
		var two: Array = []
		for k in 2:
			for c in Skins._dabs(cov_s, made["rect"], mm_s * Skins.DABS, k):
				two.append(Vector3((c as Vector2).x, (c as Vector2).y, 1.0))
		var old_way := Skins.pressed(tp.element(0, "base"), "stipple", mm_s, two)
		old_way["id"] = "two passes"
		(tp.skins[0]["held"] as Dictionary)[TablePaint._held_key(old_way, "w%d:pose" % sw, "corner")] = tp._held_keys(0, old_way, tool_s, "corner")
		var touches0: Array = []
		for st in old_way["strokes"]:
			var t0s: PackedFloat32Array = (st as Dictionary)["t"]
			touches0.append({"u": t0s[0] / float(old_way["natural"]), "pts": tp._touched(0, tool_s, TablePaint._hold_of(tp._surface_hold(0, old_way, t0s[0], 0.0, track), tool_s))})
		var held_now := _holes(wm, cov_s, float(prog["natural"]))
		var held_was := _holes(Skins.touch_map(touches0, made["rect"]), cov_s, float(old_way["natural"]))
		_ok(held_now.x >= 0.8, "of the holes paint closed round, only %.0f%% were pressed within 5 s" % (held_now.x * 100.0))
		_ok(held_was.x < held_now.x - 0.1, "THE CONTROL: two passes one after the other pressed %.0f%% of their holes within 5 s" % (held_was.x * 100.0))
		var never: int = never_of.call(wm)
		_ok(never > 0, "every point of the picture shows at some time: what no press touched is shown all the same")
		_ok(never_of.call(Skins.when_map(prog, made["rect"])) == 0, "THE CONTROL: shown by its program alone, some point is never shown")
	# ...DIPPED INTO ITS PAINT BY ITS END'S CORNER, inside the pot's mouth AS IT IS DRAWN: nothing of it under the rim past the wall
	var mouth := m._work._mouth_of("white pot", 0.0)
	var rim: Vector3 = mouth["at"]
	var drawn := func(nx: Transform3D) -> PackedVector3Array:
		var out := PackedVector3Array()
		var by: Variant = sponge_mat.get_shader_parameter("flat_by")
		for q in pts:
			out.append(nx * (_flat_drawn(q, sponge_mat.get_shader_parameter("flat_on"), by, sponge_mat.get_shader_parameter("flat_at"))
				if by is Vector3 and (by as Vector3).x > 0.0 else q))
		return out
	var past_wall := func(ws: PackedVector3Array) -> float:
		var worst := -INF
		for w in ws:
			if w.y < rim.y:
				worst = maxf(worst, Vector2(w.x - rim.x, w.z - rim.z).length() - float(mouth["r"]))
		return worst
	var st: Array = times["stipple"]
	var splan := tp.plan_of(_track_of(m, "stipple"), float(st[1]) - float(st[0]))
	var load: Array = (splan["phases"] as Array).filter(func(p: Dictionary) -> bool: return String(p["kind"]) == "load")
	_ok(not load.is_empty(), "the stipple never loads its sponge")
	if load.is_empty():
		m._work._planned = false
		return true
	var stool: Dictionary = tp.tools["w%d:pose" % sw]
	var pot := tp._pot_hold("load", "white pot", "", float(st[0]), _track_of(m, "stipple"))
	var floor_y := float(pot[6]) if pot.size() > 6 else NAN
	_ok(String(pot[5]) == "end", "the sponge does not dip by its end: %s" % pot[5])
	_ok(not is_nan(floor_y), "the sponge's paint has no surface it is pressed onto")
	# ...PUSHED INTO IT AND PRESSED FLAT ON IT (the user: "It touches at the very tip of a corner, and doesn't compress the sponge at
	# all"): at its hardest, as deep as it is pushed, its lowest drawn on the paint's surface, and a patch of it there - never a point
	var dipped := -INF
	var hardest := 0.0
	var patch := 0.0
	var lowest := INF
	var rigid_low := INF
	var at_hardest := Transform3D.IDENTITY
	for k in 41:
		m._work.tick(float(st[0]) + lerpf(float((load[0] as Dictionary)["a"]), float((load[0] as Dictionary)["b"]), 0.4 + 0.6 * float(k) / 40.0))
		var nx := m._work._world_of(node)
		var ws: PackedVector3Array = drawn.call(nx)
		dipped = maxf(dipped, float(past_wall.call(ws)))
		var by: Vector3 = sponge_mat.get_shader_parameter("flat_by") if sponge_mat.get_shader_parameter("flat_by") is Vector3 else Vector3.ZERO
		if by.x > hardest:
			hardest = by.x
			at_hardest = nx
			lowest = INF
			rigid_low = INF
			var on := PackedVector3Array()
			for i in ws.size():
				lowest = minf(lowest, ws[i].y)
				if ws[i].y < floor_y + 0.0015:
					on.append(ws[i])
				rigid_low = minf(rigid_low, (nx * pts[i]).y)
			patch = _across(on)
	_ok(hardest > TablePaint.LOAD_PRESS * 0.6, "the sponge taking up its paint goes only %.1f mm past its surface" % (hardest * 1000.0))
	_ok(absf(lowest - floor_y) < 0.001, "pressed into its paint, the sponge is drawn %.1f mm off its surface" % ((lowest - floor_y) * 1000.0))
	_ok(patch > 0.012, "pressed into its paint, the sponge lies on it only %.1f mm across - a corner's tip, not foam squashed flat" % (patch * 1000.0))
	_ok(dipped > -INF and dipped < 0.0005, "the sponge dipped into its pot stands %.1f mm past the pot's wall" % (dipped * 1000.0))
	# THE CONTROLS: drawn as it is held, never flattened, it would stand far under its paint's surface; held as it had been, balanced on
	# its corner through its middle and squashed back from there, it touched the paint at a point
	_ok(floor_y - rigid_low > 0.006, "THE CONTROL: unflattened, the sponge goes only %.1f mm under its paint" % ((floor_y - rigid_low) * 1000.0))
	var corner := tp._contact(stool, "corner")
	var old := tp._node_at([pot[0] - Vector3.UP * 0.008, (Vector3.UP * 0.9 + Vector3.BACK * 0.35).normalized(), 1.0, false, pot[4], "corner"],
		stool, stool["x0"])
	var sq_d := -(Vector3.UP * 0.9 + Vector3.BACK * 0.35).normalized()
	var sq_m := (old.basis.inverse() * sq_d).normalized()
	var sq_w := 0.008 / float(corner["reach"])
	var old_low := INF
	var old_ws := PackedVector3Array()
	for q in pts:
		var v: Vector3 = q - sq_m * maxf((q - stool["center"]).dot(sq_m), 0.0) * sq_w
		old_ws.append(old * v)
		old_low = minf(old_low, (old * v).y)
	var old_on := PackedVector3Array()
	for w in old_ws:
		if w.y < old_low + 0.0015:
			old_on.append(w)
	var old_patch := _across(old_on)
	_ok(old_patch < patch * 0.5, "THE CONTROL: held by its corner through its middle, the sponge lay on its paint %.1f mm across (%.1f now)" % [
		old_patch * 1000.0, patch * 1000.0])
	print("  the sponge pressed %.1f mm into its paint, lying on it %.1f mm across (by its corner through its middle, %.1f), %.1f mm inside the pot's wall" % [
		hardest * 1000.0, patch * 1000.0, old_patch * 1000.0, -dipped * 1000.0])
	# ...and held flat by its face, a sponge wider than the mouth goes through the wall
	var flat := tp._node_at([tp._source_of("load", "white pot", "", float(st[0])), Vector3.UP, 1.0, false, pot[4], "face"], stool, stool["x0"])
	var flat_ws := PackedVector3Array()
	for q in pts:
		flat_ws.append(flat * q)
	_ok(float(past_wall.call(flat_ws)) > 0.002, "THE CONTROL: held flat in the pot the sponge stands only %.1f mm past its wall" % (float(past_wall.call(flat_ws)) * 1000.0))
	m._work._planned = false
	return true


## How far across points [param ps] lie (meters, the table's plan): the farthest two apart.
static func _across(ps: PackedVector3Array) -> float:
	var most := 0.0
	for i in ps.size():
		for j in range(i + 1, ps.size()):
			most = maxf(most, Vector2(ps[i].x - ps[j].x, ps[i].z - ps[j].z).length())
	return most


## Point [param q] of a tool (its node's space) as prop_common.gdshaderinc draws it pressed onto a surface ([method TablePaint._flat_on]).
static func _flat_drawn(q: Vector3, on: Vector4, by: Vector3, at: Vector3) -> Vector3:
	if by.x <= 0.0:
		return q
	var n := Vector3(on.x, on.y, on.z).normalized()
	var s := q.dot(n) - on.w
	if s >= by.y:
		return q
	var u := clampf((s + by.x) / (by.y + by.x), 0.0, 1.0)
	var lifted := by.y * pow(u, (by.y + by.x) / by.y) - s
	var rel := q - at
	var out := rel - n * rel.dot(n)
	return q + n * lifted + out * lifted * by.z / maxf(out.length(), 0.004)


## [param node]'s own surface (its node's space): every corner of its meshes, and where each of a grid across each face of its box meets
## them straight in - the middle of a sponge's faces too, which a mesh's corners alone are not.
static func _box_points(node: Node3D, w: TableWork) -> PackedVector3Array:
	var inv := w._world_of(node).affine_inverse()
	var box := AABB()
	var first := true
	var faces := PackedVector3Array()
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var to := inv * w._world_of(mi as MeshInstance3D)
		var b: AABB = to * (mi as MeshInstance3D).get_aabb()
		box = b if first else box.merge(b)
		first = false
		for v in (mi as MeshInstance3D).mesh.get_faces():
			faces.append(to * v)
	var out := PackedVector3Array()
	var seen := {}
	for v in faces:
		var key := Vector3i(roundi(v.x * 4000.0), roundi(v.y * 4000.0), roundi(v.z * 4000.0))
		if not seen.has(key):
			seen[key] = true
			out.append(v)
	var tm := TableWork._ray_mesh(faces)
	var grown := box.grow(0.003)
	for ax in 3:
		for side in 2:
			for i in 9:
				for j in 9:
					var q := grown.position
					q[ax] = grown.position[ax] if side == 0 else grown.end[ax]
					q[(ax + 1) % 3] = lerpf(box.position[(ax + 1) % 3], box.end[(ax + 1) % 3], float(i) / 8.0)
					q[(ax + 2) % 3] = lerpf(box.position[(ax + 2) % 3], box.end[(ax + 2) % 3], float(j) / 8.0)
					var into := Vector3.ZERO
					into[ax] = 1.0 if side == 0 else -1.0
					var hit := TableWork._ray(tm, q, into)
					if not hit.is_empty():
						out.append(hit["position"])
	return out


## THE HOLES IN WHAT A PRESSING TOOL LAID ([param wm], a touch map over [param cov], a program [param natural] seconds long): every point the
## paint had closed round (the points 4 mm about it all shown before it) - the share of those shown within 5 s of it, and how many are
## never shown.
static func _holes(wm: Image, cov: Image, natural: float) -> Vector2:
	var quick := 0
	var all := 0
	var never := 0
	for y in range(4, wm.get_height() - 4):
		for x in range(4, wm.get_width() - 4):
			if cov.get_pixel(x, y).a <= 0.5:
				continue
			var up := wm.get_pixel(x, y).r
			var closed := -1.0
			var round_it := true
			for k in 16:
				var a := TAU * float(k) / 16.0
				var qx := x + int(round(cos(a) * 4.0))
				var qy := y + int(round(sin(a) * 4.0))
				var uq := wm.get_pixel(qx, qy).r
				if cov.get_pixel(qx, qy).a <= 0.5 or uq >= Skins.NEVER:
					round_it = false
					break
				closed = maxf(closed, uq)
			if not round_it or up <= closed:
				continue
			if up >= Skins.NEVER:
				never += 1
				continue
			all += 1
			if (up - closed) * natural <= 5.0:
				quick += 1
	return Vector2(float(quick) / float(maxi(all, 1)), float(never))


static func _track_of(m: TableMedium, act: String) -> Dictionary:
	for a in m._work.acts:
		if String((a as Dictionary)["name"]) == act:
			return ((a as Dictionary)["tracks"] as Array)[0]
	return {}


static func _faces_of(sd: Dictionary) -> PackedVector3Array:
	var faces := PackedVector3Array()
	for mi in sd["meshes"]:
		faces.append_array((mi as MeshInstance3D).mesh.get_faces())
	return faces


## How far [param p] (the table's space) is off skin [param si]'s face, along the face's own normal where a ray along its front
## finds it (meters).
static func _off_face(tm: TriangleMesh, tp: TablePaint, si: int, p: Vector3) -> float:
	var hw := tp.holder_world(si, 0.0)
	var local := hw.affine_inverse() * p
	var front: Vector3 = (tp.skins[si]["surface"] as Dictionary)["front"]
	var hit := TableWork._ray(tm, local + front * 0.05, -front)
	if hit.is_empty():
		return INF
	var n: Vector3 = (hit["normal"] as Vector3).normalized()
	if n.dot(front) < 0.0:
		n = -n
	return (local - (hit["position"] as Vector3)).dot(n) * hw.basis.get_scale().x


static func _medium() -> TableMedium:
	var m := TableMedium.new()
	m._root3 = Node3D.new()
	m._props = Node3D.new()
	m._root3.add_child(m._props)
	m._wind = {}
	# ...and a lens, for the bursts a powder and a spray throw ([method TableMedium._air_stage])
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	m._plan.cam_base = CardTable.sample_layout(rng)["camera"]
	m._cam = Camera3D.new()
	return m


static func _stand(m: TableMedium, spec: Dictionary, name: String, at: Vector3, seed := 5) -> Dictionary:
	var safe := Props.sanitize(spec, [])
	var thing: Dictionary = {}
	for t in safe["things"]:
		if String((t as Dictionary)["name"]) == name:
			thing = t
	var b := Props.build(thing, safe["materials"], seed)
	var node: Node3D = b["node"]
	node.transform = Transform3D(Basis.IDENTITY, at)
	m._props.add_child(node)
	m._work.take(thing, b, node)
	m._work.materials = safe["materials"]
	return {"node": node, "built": b, "thing": thing}


## A paint act's place in the reading: begun, it keeps its length; and a hand paints one thing at a time.
func _scheduled() -> bool:
	var spec := station()
	var at := {"mask": Vector3(0, 0, -0.06), "brush jar": Vector3(0.18, 0, 0.04), "sponge": Vector3(-0.16, 0, 0.08),
		"white pot": Vector3(-0.09, 0, 0.12), "black pot": Vector3(0.09, 0, 0.12), "water cup": Vector3(0.22, 0, -0.06)}
	var made := func(two_beats: bool) -> TableMedium:
		var m := _medium()
		for nm in at:
			_stand(m, spec, nm, Vector3(Tables.ORIGIN.x, 0.0, Tables.ORIGIN.y) + (at[nm] as Vector3))
		m._work.skin_doc = design()
		var acts: Array = [
			{"name": "base", "beat": 1, "length": "under", "tracks": [{"thing": "sponge", "part": "wedge", "law": "paint", "on": "mask", "paint": ["base"], "from": "white pot"}]}]
		if two_beats:
			acts.append({"name": "splash", "beat": 2, "length": 2, "tracks": [{"thing": "water cup", "part": "water", "state": "tint", "law": "to", "value": "#8899aa"}]})
		acts.append({"name": "brow", "beat": 2 if two_beats else 1, "length": "under", "tracks": [{"thing": "brush jar", "part": "liner", "law": "paint", "on": "mask", "paint": ["brow"], "from": "black pot"}]})
		m._work.build({"acts": acts}, 2 if two_beats else 1)
		return m
	var action := {"kind": "work", "card": 1, "after": 0, "dur": 0.0}
	var cues: Array = [{"name": "base", "si": 0}, {"name": "brow", "si": 1}]
	var parse := {"actions": [action], "spoken": PackedStringArray(["one", "two", "three"]), "cues": cues}
	var sched := [{"a": action, "t0": 2.0, "s": 1.0}]
	var span_of := func(m: TableMedium, nm: String) -> Vector2:
		for r in m._work.runs:
			if String((m._work.acts[int((r as Dictionary)["i"])] as Dictionary)["name"]) == nm:
				return Vector2(float(r["t0"]), float(r["t1"]))
		return Vector2(INF, INF)
	# BEGUN, IT KEEPS ITS LENGTH: placed under a guess at the word that cues the next act, then that word moved by a later plan
	var m: TableMedium = made.call(false)
	_ok((m._work.acts as Array).size() == 2, "the scheduled paint acts were not kept: %s" % "; ".join(m._work.notes))
	if (m._work.acts as Array).size() < 2:
		return true
	var nat := float((m._work.acts[0] as Dictionary).get("_natural", 0.0))
	var guess := 2.0 + nat * 1.3
	var heard := 2.0 + nat * 1.1
	m._work.schedule(sched, parse, PackedFloat32Array([2.0, guess, guess + 60.0]), PackedFloat32Array([2.5, guess + 0.5, guess + 60.5]), PackedFloat32Array(), 2.0)
	var first: Vector2 = span_of.call(m, "base")
	m._work.schedule(sched, parse, PackedFloat32Array([2.0, heard, heard + 60.0]), PackedFloat32Array([2.5, heard + 0.5, heard + 60.5]), PackedFloat32Array(), 20.0)
	var later: Vector2 = span_of.call(m, "base")
	_ok(absf(first.y - guess) < 0.05 and absf(later.y - first.y) < 0.01, "a paint act begun moved its end with a later plan: %s, then %s (the next cue %.1f, then %.1f)" % [first, later, guess, heard])
	var fresh: TableMedium = made.call(false)
	fresh._work.schedule(sched, parse, PackedFloat32Array([2.0, heard, heard + 60.0]), PackedFloat32Array([2.5, heard + 0.5, heard + 60.5]), PackedFloat32Array(), 2.0)
	_ok(absf((span_of.call(fresh, "base") as Vector2).y - heard) < 0.05, "THE CONTROL: planned afresh it does not end at the word heard (%s, the word %.1f)" % [span_of.call(fresh, "base"), heard])
	# ONE HAND PAINTS ONE THING AT A TIME: the base, not hurried, runs on past its beat's words into the next beat, and the brow cued
	# at that beat's first word waits for it - THE CONTROL: what is not painted, cued at the same word, begins on it
	var h: TableMedium = made.call(true)
	var a2 := {"kind": "work", "card": 2, "after": 1, "dur": 0.0}
	var cues3: Array = [{"name": "base", "si": 0}, {"name": "splash", "si": 1}, {"name": "brow", "si": 1}]
	h._work.schedule([{"a": action, "t0": 2.0, "s": 1.0}, {"a": a2, "t0": 5.0, "s": 1.0}], {"actions": [action, a2], "spoken": parse["spoken"], "cues": cues3},
		PackedFloat32Array([2.0, 5.0, 400.0]), PackedFloat32Array([2.5, 5.5, 400.5]), PackedFloat32Array(), 0.0)
	var base: Vector2 = span_of.call(h, "base")
	var brow: Vector2 = span_of.call(h, "brow")
	var splash: Vector2 = span_of.call(h, "splash")
	_ok(base.y > 5.0 and brow.x >= base.y - 0.01, "the brow began beside the base: base %s, brow %s" % [base, brow])
	_ok(absf(splash.x - 5.0) < 0.01, "THE CONTROL: what is not painted, cued at the same word, does not begin on it: %s" % splash)
	for x in [m, fresh, h]:
		(x as TableMedium)._root3.free()
	return true


func _details() -> bool:
	var frame := Vector2(150, 210)
	# A SMEAR
	var d := Skins.sanitize({"elements": [
		{"id": "mouth", "stage": "color", "paint": "#b3122a", "finish": "gloss", "fill": "M 55 152 Q 75 140 95 152 Q 75 164 55 152 Z"},
		{"id": "drag", "stage": "depth", "smear": "mouth", "line": "M 95 152 Q 110 150 124 140", "width": 6},
		{"id": "nothing", "smear": "no such", "line": "M 10 10 L 40 10"},
		{"id": "spray", "stage": "finish", "mist": "all"}]}, frame)
	var els: Array = d["elements"]
	_ok(els.size() == 3 and String((els[1] as Dictionary)["kind"]) == "smear" and String((els[1] as Dictionary)["paint"]) == "#b3122a" and String((els[1] as Dictionary)["finish"]) == "gloss",
		"a smear takes the paint and finish of what it drags: %s" % [els.map(func(e: Dictionary) -> String: return "%s %s" % [e["id"], e["kind"]])])
	_ok(not els.any(func(e: Dictionary) -> bool: return String(e["id"]) == "nothing"), "THE CONTROL: a smear of nothing is left out")
	if els.size() < 3:
		return true
	var sm: Dictionary = els[1]
	var rect := Skins.rect_of(sm, frame, 2.0)
	var cov := Skins.cover(sm, rect, Skins.PX_MM, "", frame)
	var near_start := 0.0
	var near_end := 0.0
	for dy in range(-2, 3):
		near_start = maxf(near_start, cov.get_pixel(int((97.0 - rect.position.x) * Skins.PX_MM), int((152.0 + dy - rect.position.y) * Skins.PX_MM)).a)
		near_end = maxf(near_end, cov.get_pixel(int((122.0 - rect.position.x) * Skins.PX_MM), int((141.5 + dy - rect.position.y) * Skins.PX_MM)).a)
	_ok(near_start > near_end * 1.6 and near_end > 0.02, "a smear thins along the way it is dragged: %.2f at its start, %.2f at its end" % [near_start, near_end])
	var c1 := Skins.cover(sm, rect, Skins.WHEN_PX, "", frame)
	var prog := Skins.program(sm, Skins.manner_of(sm, "sponge"), 20.0, c1, rect)
	var wm := Skins.when_map(prog, rect)
	var u0: float = wm.get_pixel(int(96.0 - rect.position.x), int(152.0 - rect.position.y)).r
	var u1: float = wm.get_pixel(int(123.0 - rect.position.x), int(141.0 - rect.position.y)).r
	_ok(Skins.manner_of(sm, "sponge") == "smear" and u0 < u1, "and is revealed from where it starts (%.2f) to where it ends (%.2f)" % [u0, u1])
	# A MIST
	var mist: Dictionary = els[2]
	_ok(String(mist["kind"]) == "mist" and Skins.manner_of(mist, "tool") == "spray", "a mist is sprayed")
	# ...ON A TABLE: rinsed, dried, clouding the water, sprayed from aside, the powder's puffs placed
	var m := _medium()
	var spec := station()
	(spec["things"] as Array).append({"name": "atomizer", "at": [-30, 4], "parts": [{"name": "bottle", "joint": {"kind": "free"},
		"points": {"tip": [0, 9, 1], "grip": [0, 9, -1]}, "parts": [{"shape": "lathe", "profile": [[0, 0], [2, 0], [2, 9], [0, 9]], "material": "glaze"}]}]})
	(spec["things"] as Array).append({"name": "red pot", "at": [3, 14], "parts": [
		{"shape": "lathe", "profile": [[0, 0], [2.5, 0], [2.5, 2], [2.2, 2], [2.2, 0.4], [0, 0.4]], "material": "glaze"},
		{"shape": "lathe", "profile": [[0, 0.4], [2.2, 0.4], [2.2, 1.6], [0, 1.6]], "material": "red paint"}]})
	(spec["materials"] as Dictionary)["red paint"] = {"kind": "cream", "color": "#b3122a"}
	# ...and a tall bottle on the way from the cup to the towel
	(spec["things"] as Array).append({"name": "tall bottle", "at": [15, -6], "parts": [{"shape": "lathe", "profile": [[0, 0], [1.8, 0], [1.8, 12], [0, 12]], "material": "glaze"}]})
	var at := {"mask": Vector3(0, 0, -0.06), "brush jar": Vector3(0.18, 0, 0.04), "sponge": Vector3(-0.16, 0, 0.08), "white pot": Vector3(-0.09, 0, 0.12),
		"black pot": Vector3(0.09, 0, 0.12), "red pot": Vector3(0.03, 0, 0.14), "water cup": Vector3(0.22, 0, -0.06), "towel": Vector3(-0.24, 0, -0.08), "atomizer": Vector3(-0.3, 0, 0.04),
		"tall bottle": Vector3(0.15, 0, -0.063)}
	for nm in at:
		_stand(m, spec, nm, Vector3(Tables.ORIGIN.x, 0.0, Tables.ORIGIN.y) + (at[nm] as Vector3))
	m._work.skin_doc = {"designs": [{"thing": "mask", "part": "face", "name": "details", "elements": [
		{"id": "base", "stage": "base", "paint": "#f6f2ea", "fill": "all", "finish": "powder"},
		{"id": "brow", "stage": "lines", "paint": "#121214", "line": "M 30 72 C 40 58 58 55 66 62", "width": 1.4},
		{"id": "mouth", "stage": "color", "paint": "#b3122a", "fill": "M 55 152 Q 75 140 95 152 Q 75 164 55 152 Z"},
		{"id": "drag", "stage": "depth", "smear": "mouth", "line": "M 95 152 Q 110 150 124 140", "width": 6},
		{"id": "spray", "stage": "finish", "mist": "all"}]}]}
	var acts := {"acts": [
		{"name": "base", "beat": 1, "length": "under", "tracks": [{"thing": "sponge", "part": "wedge", "law": "paint", "on": "mask", "paint": ["base"], "manner": "pat", "from": "white pot"}]},
		{"name": "lines", "beat": 1, "length": "under", "tracks": [{"thing": "brush jar", "part": "liner", "law": "paint", "on": "mask", "paint": ["brow", "mouth"], "rinse": "water cup", "dry": "towel"}]},
		{"name": "plain", "beat": 2, "length": "under", "tracks": [{"thing": "brush jar", "part": "liner", "law": "paint", "on": "mask", "paint": ["brow"]}]},
		{"name": "drag", "beat": 2, "length": "under", "tracks": [{"thing": "sponge", "part": "wedge", "law": "paint", "on": "mask", "paint": ["drag"]}]},
		{"name": "spray", "beat": 2, "length": "under", "tracks": [{"thing": "atomizer", "part": "bottle", "law": "paint", "on": "mask", "paint": ["spray"]}]}]}
	m._work.build(acts, 2)
	var tp: TablePaint = m._work.paint
	_ok(tp != null and (m._work.acts as Array).size() == 5, "the detail acts were kept: %s" % "; ".join(m._work.notes))
	if tp == null or (m._work.acts as Array).size() < 5:
		return true
	var times: Dictionary = m._work.rehearse(10.0)
	var lines_tr: Dictionary = _track_of(m, "lines")
	var lines_t: Array = times["lines"]
	var plan := tp.plan_of(lines_tr, float(lines_t[1]) - float(lines_t[0]))
	var kinds: Array = (plan["phases"] as Array).map(func(p: Dictionary) -> String: return String(p["kind"]))
	var trips: Array = kinds.filter(func(k: String) -> bool: return k in ["load", "rinse", "dry"])
	_ok(trips == ["load", "rinse", "dry", "load", "rinse", "dry"], "a brush is rinsed and dried before its next color and before it is put down: %s" % [kinds])
	_ok(kinds.find("dry") + 1 == kinds.find("load", kinds.find("dry")), "and goes from the towel straight to its paint")
	var plain := tp.plan_of(_track_of(m, "plain"), 10.0)
	_ok(not (plain["phases"] as Array).any(func(p: Dictionary) -> bool: return String(p["kind"]) in ["rinse", "dry"]), "THE CONTROL: a brush that does not rinse is never rinsed")
	# ...over the towel while it is dried, in the cup while it is rinsed
	var lw: int = m._work._work_of(m._work._thing_named("brush jar"), "liner")
	var tool: Dictionary = tp.tools.get("w%d:pose" % lw, {})
	m._work._planned = true
	var towel_box: AABB = m._work._world_rest_thing(m._work._thing_named("towel")) * (m._work.things[m._work._thing_named("towel")]["box"] as AABB)
	var cup_box: AABB = m._work._world_rest_thing(m._work._thing_named("water cup")) * (m._work.things[m._work._thing_named("water cup")]["box"] as AABB)
	var on_towel := false
	var in_cup := false
	for p in plan["phases"]:
		var pd: Dictionary = p
		if not String(pd["kind"]) in ["rinse", "dry"]:
			continue
		m._work.tick(float(lines_t[0]) + lerpf(float(pd["a"]), float(pd["b"]), 0.7))
		var tip := m._work._world_of((m._work.works[lw] as Dictionary)["node"]) * (tool["tip"] as Vector3)
		if String(pd["kind"]) == "dry":
			on_towel = on_towel or towel_box.grow(0.006).has_point(tip)
		else:
			in_cup = in_cup or cup_box.has_point(tip)
	_ok(on_towel, "the brush is touched to the towel")
	_ok(in_cup, "and rinsed in the cup")
	# ...COMING IN OVER THE CUP'S RIM, its water lying further under it than a trip's lift - THE CONTROL
	var rinse_ph: Dictionary = (plan["phases"] as Array).filter(func(p: Dictionary) -> bool: return String(p["kind"]) == "rinse")[0]
	m._work.tick(float(lines_t[0]) + lerpf(float(rinse_ph["a"]), float(rinse_ph["b"]), 0.4))
	var over_tip := m._work._world_of((m._work.works[lw] as Dictionary)["node"]) * (tool["tip"] as Vector3)
	var water := tp._pot_hold("rinse", "", "", float(lines_t[0]), lines_tr)
	_ok(over_tip.y > cup_box.end.y, "the brush comes to the cup over its rim: its tip at %.1f cm, the rim at %.1f" % [over_tip.y * 100.0, cup_box.end.y * 100.0])
	_ok((water[0] as Vector3).y + TablePaint.TRIP_LIFT < cup_box.end.y, "THE CONTROL: the cup's water lies a trip's lift under its rim")
	# ...AND OVER WHAT STANDS ON ITS WAY: from the cup to the towel, over the tall bottle between them - THE CONTROL: with nothing
	# mapped (as it had been) the same way goes through it
	var dry_ph: Dictionary = (plan["phases"] as Array).filter(func(p: Dictionary) -> bool: return String(p["kind"]) == "dry")[0]
	var bottle_box: AABB = m._work._world_rest_thing(m._work._thing_named("tall bottle")) * (m._work.things[m._work._thing_named("tall bottle")]["box"] as AABB)
	var lowest_over := func() -> float:
		var low := INF
		for k in 60:
			m._work.tick(float(lines_t[0]) + lerpf(float(dry_ph["a"]), float(dry_ph["b"]), 0.4 * float(k) / 59.0))
			var tip := m._work._world_of((m._work.works[lw] as Dictionary)["node"]) * (tool["tip"] as Vector3)
			if tip.x > bottle_box.position.x and tip.x < bottle_box.end.x and tip.z > bottle_box.position.z - 0.01 and tip.z < bottle_box.end.z + 0.01:
				low = minf(low, tip.y)
		return low
	var cleared: float = lowest_over.call()
	_ok(cleared < INF and cleared > bottle_box.end.y, "the brush goes over the bottle on its way to the towel: its tip at %.1f cm over it, the bottle %.1f cm tall" % [cleared * 100.0, bottle_box.end.y * 100.0])
	var mapped := tp._tops
	tp._tops = PackedFloat32Array()
	var through: float = lowest_over.call()
	tp._tops = mapped
	_ok(through < bottle_box.end.y, "THE CONTROL: with nothing mapped the way goes through the bottle (its tip at %.1f cm)" % (through * 100.0))
	# WHAT A PAINTING TOOL IS MEANT TO GO INTO is never said to be passed through: what it paints, its water, its towel and the
	# paints - THE CONTROL: one that does not rinse is not excused the cup or the towel
	var mv := {"nodes": [(m._work.works[lw] as Dictionary)["node"]]}
	var free: Array = (m._work._pressed_by(m._work.acts.filter(func(a: Dictionary) -> bool: return String(a["name"]) == "lines")[0], mv) as Dictionary).get("free", [])
	var want := ["mask", "water cup", "towel", "white pot", "black pot", "red pot"].map(func(nm: String) -> int: return m._work._thing_named(nm))
	_ok(want.all(func(ti: int) -> bool: return free.has(ti)), "a rinsing brush is not excused what it paints, its water, its towel and the paints: %s" % [free])
	var plain_free: Array = (m._work._pressed_by(m._work.acts.filter(func(a: Dictionary) -> bool: return String(a["name"]) == "plain")[0], mv) as Dictionary).get("free", [])
	_ok(plain_free.has(m._work._thing_named("mask")) and not plain_free.has(m._work._thing_named("water cup")) and not plain_free.has(m._work._thing_named("towel")),
		"THE CONTROL: a brush that does not rinse is excused the cup or the towel: %s" % [plain_free])
	# THE WATER CLOUDS toward what is rinsed out
	var ww: int = m._work._work_of(m._work._thing_named("water cup"), "water")
	var before: Color = m._work.value("w%d:tint" % ww, float(lines_t[0]) - 1.0)
	var after: Color = m._work.value("w%d:tint" % ww, float(lines_t[1]) + 1.0)
	var red := Color.html("#b3122a")
	_ok(Vector3(after.r - red.r, after.g - red.g, after.b - red.b).length() < Vector3(before.r - red.r, before.g - red.g, before.b - red.b).length() - 0.01,
		"the water clouds toward the color rinsed out: %s to %s" % [before.to_html(false), after.to_html(false)])
	var plain_t: Array = times["plain"]
	var later: Color = m._work.value("w%d:tint" % ww, float(plain_t[1]) + 1.0)
	_ok(later.is_equal_approx(after), "THE CONTROL: an act with no rinse leaves the water as it was")
	# A SPRAY from aside
	var aw: int = m._work._work_of(m._work._thing_named("atomizer"), "bottle")
	var spray_t: Array = times["spray"]
	var splan := tp.plan_of(_track_of(m, "spray"), float(spray_t[1]) - float(spray_t[0]))
	var sprayed := false
	for p in splan["phases"]:
		var pd: Dictionary = p
		if String(pd["kind"]) != "el":
			continue
		m._work.tick(float(spray_t[0]) + lerpf(float(pd["a"]), float(pd["b"]), 0.5))
		var atool: Dictionary = tp.tools.get("w%d:pose" % aw, {})
		var nozzle := m._work._world_of((m._work.works[aw] as Dictionary)["node"]) * (atool["tip"] as Vector3)
		var face := tp.holder_world(0, 0.0) * (tp.at_mm(0, Vector2(75, 105))[0] as Vector3)
		var hw0 := tp.holder_world(0, 0.0)
		var front: Vector3 = (hw0.basis * ((tp.skins[0]["surface"] as Dictionary)["front"] as Vector3)).normalized()
		var right: Vector3 = (hw0.basis * ((tp.skins[0]["xform"] as Transform3D).basis * Vector3.RIGHT)).normalized()
		var off := nozzle - face
		sprayed = off.length() > 0.06 and off.length() < 0.3 and off.normalized().dot(right) > 0.3 and off.normalized().dot(front) > 0.2
	_ok(sprayed, "the mist is sprayed from a hand's length off, out from the surface and to its side")
	var items: Dictionary = tp.skins[0]["items"]
	_ok(items.has("spray") and float(((items["spray"] as Dictionary)["mats"][0] as ShaderMaterial).get_shader_parameter("color_alpha")) == 0.0, "and lays no color")
	_ok(items.has("drag") and ((items["drag"] as Dictionary)["span"] as Vector2).x < INF, "the smear is laid")
	_ok(not tp.dust("dust").is_empty() and not tp.dust("mist").is_empty() and m._work._paint_bursts.has("dust") and m._work._paint_bursts.has("mist"), "the powder's pats and the spray's pumps are placed as puffs")
	m._work._planned = false
	return true
