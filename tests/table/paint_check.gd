extends SceneTree

## The gate of THE PAINTED SURFACE ([FaceForm], [Bristles], [Skins], [TablePaint]; next/painted_surface.md), with no renderer.
##
##   timeout 1800 godot --headless --path . --script res://tests/table/paint_check.gd   (over 300 s - about 20 minutes since the nose's clearance checks (feedback 0003): a puff, a sponge and a fill each held and looked at through a whole act, the sponge's every drawn point)
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
##   the liner's tip at rest is far from the face. AN ELEMENT IS TAKEN FROM THE POT ITS DESIGN NAMES (feedback 0001: a base went back
##   for more to the amber pot, the cream nearest its color, from the white it named); the control, naming none, the nearest.
##   NOTHING IS LIFTED ALONG A STROKE IT PRESSES (feedback 0019, 0021: a liner 11 mm and a
##   flat brush 17 mm over a mask's rim, painting in the air); the control, the lifts between strokes, are found.
##   ITS HAIRS ARE BENT ONTO THE FACE wherever it is pressed (a forehead's stars painted with nothing, a lower lip's outline drawn up on
##   the lip): the bent tip within a touch of it at nine places in ten over the whole face; the control, the bend counted along the
##   face's normal, at far fewer. IT GOES BACK OVER WHAT IT MISSED (feedback 0035): what its strokes left bare of a band wider than it
##   dabbed until under half is; the control, the first look, left some. IT IS PULLED THROUGH ITS STROKE (the user, 2026-11-07): drawn
##   each of eight ways, its handle leans the way it goes, and so at every key of the brow; the control, held as before, leaned against
##   the way it went at three ways or more.
##   A PRESS PUT IN WHERE THE FIRST MISSED IS HELD THE WAY THAT REACHES IT (a chin's underside: the corner stood off it, the face reached
##   it): every one held other than by its corner is one its corner missed and the other way touches nearer; the control, no press of the
##   plan is held but by its corner. WHAT NO PRESS REACHED IS PAINTED ALL THE SAME ("just dab in that area, and paint it anyway"), each
##   point with the touch aimed nearest it; the control, with nothing bare, nothing is added. A PRESS'S EDGE IS CARRIED PAST ITS EDGE:
##   two points out, every point beside a shown one holds a moment; the control, the same touches carried nowhere, few do.
##   The sponge stipples BY ITS CORNER (the user: "dab with the corner of the sponge, not with the flat side"), stood off only where the
##   face round it leaves the corner no room, and never more than 4.5 mm.
## - A HELD TOOL STANDS IN NOTHING (feedback 0016: "This sponge is clipping right through the nose", and through a pot as it took its
##   paint): a sponge stippling by its corner and blending flat over a whole face, nose and all, stands no more than 1.5 mm in it as it is
##   drawn - pressed onto it, taking its shape (feedback 0041, a puff "clipping through the nose ... always perfectly flat") - at each
##   place it keeps and on its way between them; dipped into a pot narrower than its face, nothing of it as drawn past the pot's wall.
##   THE CONTROLS: as it is held, never drawn taking the face's shape, it stands in the face as far as it gives; blended with nothing
##   held clear, 8 mm and more; held flat in the pot, past its wall.
## - A SPONGE IS PRESSED INTO ITS PAINT AND SQUASHED FLAT ON IT (the user, 2026-11-06: "It touches at the very tip of a corner, and
##   doesn't compress the sponge at all"): dipped by its end, pushed in over 7 mm, its lowest drawn on the paint's surface and over 12 mm
##   of it lying there. THE CONTROLS: never flattened it would stand over 6 mm under the paint; held as it had been, by its corner
##   through its middle and squashed back from there, it lay on the paint half as far across or less.
## - A PAD PRESSED ONTO THE FACE TAKES ITS SHAPE (feedback 0041, of a powder puff: "the pad is clipping through the nose ... always
##   perfectly flat: it never seems to bend or compress ... pads like this are very soft and should be easy to bend"): a puff patting a
##   base over the whole face stands no more than 1.5 mm in it as drawn, at each place it keeps and on its way between them, and pressed
##   its hardest twice as much of its face lies on the face (within a millimeter) as when it is held flat. THE CONTROL: as it is held,
##   never drawn taking the face's shape, it stands 4 mm and more in it. And a bit of it standing higher is never drawn lower (nothing
##   of it passes through the rest); a pad's face 2 mm over a hollow sags onto it (the control: with no sag, a sponge's, it stays);
##   pushed 12 mm in, its back stays its share of its depth over the face.
## - A BRUSH'S PAINT IS WHERE ITS HAIRS TOUCHED, AND A FILL KEEPS INSIDE ITS SHAPE (feedback 0042: rows that "pull through the black line
##   and onto the outside of the diamond", its paint inside alone; 0043, "rough edges"): a flat brush filling a diamond lays its paint
##   where its hairs touched - no more than 8 mm2 of it over half a millimeter past the diamond, no more than 3% of the diamond bare -
##   having eased off where it ran past at the first look and nowhere at the last. THE CONTROL: its rows as they were, over the whole
##   shape and past it, lay over 30 mm2 past it. Its paint is smoothed as paint spreads: a lone hair's touch fades out, a millimeter's
##   line stays whole (the control: unsmoothed, the lone touch is whole). A way eased off is pressed half as hard where it ran past and
##   cut there once at its lightest (the control: run past nowhere, it is as it was). A fill is softened by a blend no further than a
##   third of the way to its middle: a lip's upper half 1.5 mm, where a wide one is softened the whole 4 mm.
## - BUILT AGAIN, A HAND GOES BACK OVER WHAT IT MISSED FROM ITS PLAN (2026-11-07, a stipple reworked: "The calculated index 36 is out of
##   bounds (the array has 16 elements)"): the stipple's program built a second time is the one it had. THE CONTROL: what the first build
##   put in is more than its plan, so starting from that is not the same.
## - IT IS A FUNCTION OF TIME: the tool posed at a moment straight away and posed there after every moment before it are the same.
## - A PAINT ACT TAKES WHAT ITS STROKES TAKE: its natural length is set, and `act` says what it paints and what no act paints yet.
##   BEGUN, IT KEEPS ITS LENGTH when a later plan moves the word that cues the next act (each sentence had moved every stroke, and the
##   bake went back to the act's start - 75 of 120 s waited, live); the control, planned afresh, ends at the word heard. ONE HAND PAINTS
##   ONE THING AT A TIME: a paint act cued while another is still painting waits for it; the control, a change of the water cued at the
##   same word, begins on it. A TOOL KEPT IN HAND from one act into the next is put back where it was taken from (feedback 0004: a brush
##   left "floating near the eye" while another worked): back in its jar while the sponge works, and so by the copy of its entry the
##   physics holds it by; the control, put back where its second act found it, it is left in the air.
##   A paint act on a surface with no design is refused, and why said; the same acts on the designed surface, kept, the control.
## - THE HAIRS FOLLOW THEIR PULL: dragged to the right they lean left; let go, they come back straight, past it by a twentieth of
##   their bend at most, within a tenth of a second (the user: "Bristles aren't floppy"); the control, the spring they had, a sixth and
##   more. Moved quickly through the air they stay straight; the control, pressed and dragged as fast, they trail. The control: a
##   brush neither dragged nor pressed is straight. LEANED, THEY BEND MORE THAN THEY SPLAY (the user, 2026-11-07: a fat brush
##   "balloons into a mushroom shape"): held 40 degrees off the face, a quarter of the splay; the control, pressed straight down, all of
##   it. THE CORE STAYS UNDER THE HAIRS (a fat brush's "weird ring" of paint "ABOVE the moving bristles"): a dome's core stands under
##   its outer hairs' ends, at rest and pressed, and pressed is drawn in; the control, the core as it was, stood over them.
##   A BRUSH IS DRAWN THE WAY ITS STROKE GOES: pressed along it, at a corner between the two ways, lifted as it went or will go, a dab
##   no way at all.
## - ITS FIELD IS THE FACE: 3 mm out of the cheek reads 3 mm, 3 mm in reads -3 mm, behind its back and past its rim read out. The control:
##   the box it had been read the point over the cheek as inside (joker-motivation 856886: every brush on the face "passed through" it).
## - THE DETAILS (the user, 2026-11-05: "the smear and towel and such are important details"): a SMEAR takes an earlier element's paint
##   and thins along the way it is dragged, revealed from its start (the control: a smear of nothing is left out); a MIST lays no color
##   and is sprayed from a hand's length off, to the surface's side, never between it and the lens; a brush that RINSES is rinsed and
##   dried on the towel before each new color and before it is put down, going cup to towel to pot with no stop at the face between
##   (the control: one that does not rinse has none); A BRUSH IS LAID ON ITS PAINT, THE CUP'S FLOOR AND THE TOWEL (feedback 0002: "we need
##   the bottom 30% to 50% of bristles touching, laying on their side"): mid-load, mid-rinse and mid-dry 30% to 50% of each hair lies
##   along it (the control: held as feedback 0017 left it, a tenth or less), and it comes to the towel no faster than the solver carries it
##   (the control: its way there in the trip's fixed share, faster); the WATER CLOUDS toward each color rinsed out (the control: an act with no rinse
##   leaves it as it was), by how much paint goes into how much water - a sponge's many times a liner's, one sponge's rinse a little,
##   ten a lot - and is drawn seen through, clouding as it goes (the controls: the old tenth a rinse whatever was rinsed; a brew kept
##   opaque); A SPONGE IS RINSED AS A HAND RINSES ONE, squeezed under the water, wrung out over the cup and blotted on the towel in
##   firm presses on fresh places (the control: a brush is never wrung and is dried in one press); a powder's pats are PLACED as puffs. A trip comes to the cup OVER ITS RIM (the control: its water lies further
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
	for check in [_mask, _design, _paths, _reveal, _hairs, _paints, _held, _brush_clear, _kept_clear, _pad, _inside, _scheduled, _details, _coats, _put_back, _paced_ways, _paced_keys, _laid_as_drawn, _trailed, _picture]:
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
	# A BASE COVERS ALL OF WHAT IT IS THE BASE OF (feedback 0050, 0051: "We missed that white spot in the exact same spots on the chin,
	# again ... Our coverage is incomplete"): a second base drawn short of the chin is laid to the face's edges, its soft edge off the
	# rim - and what comes after it is its own - THE CONTROLS: a design that opens on a smaller fill keeps it; with nothing laid over
	# all of it, the face's chin had been bare of it
	var mask_outline := FaceForm.outline_path(Vector3(15, 21, 8))
	var short_base := {"name": "short", "outline": mask_outline, "elements": [
		{"id": "base 1", "stage": "base", "paint": "#d5b9a1", "fill": "all"},
		{"id": "base 2", "stage": "base", "paint": "#efe3d6", "soft": 8, "fill": "M 75 8 C 100 8 115 18 120 35 C 126 55 132 80 140 100 C 144 120 136 145 120 160 C 108 175 95 195 75 201 C 55 199 30 175 18 155 C 6 135 4 110 6 95 C 8 60 30 10 75 8 Z"},
		{"id": "cheek", "stage": "color", "paint": "#a95c2e", "fill": "M 100 120 A 12 9 0 1 0 124 120 A 12 9 0 1 0 100 120 Z"}]}
	var based := Skins.sanitize(short_base, Vector2(150, 210))
	var b2: Dictionary = (based["elements"] as Array)[1]
	var cheek: Dictionary = (based["elements"] as Array)[2]
	_ok(String(b2["d"]) == "all" and float(b2["soft"]) == 0.0 and String(cheek["d"]) != "all",
		"a base drawn short of the chin is laid to the face's edges, what comes after it its own: %s, %s" % [b2["d"], String(cheek["d"]).left(12)])
	_ok((based["notes"] as PackedStringArray).size() >= 1, "and the decorator is told: %s" % based["notes"])
	var small := Skins.sanitize({"name": "small", "outline": mask_outline, "elements": [
		{"id": "patch", "stage": "base", "paint": "#efe3d6", "fill": "M 40 60 L 110 60 L 110 120 L 40 120 Z"}]}, Vector2(150, 210))
	_ok(String(((small["elements"] as Array)[0] as Dictionary)["d"]) != "all", "THE CONTROL: a design that opens on a smaller fill keeps its shape")
	var as_written := {"kind": "fill", "d": String(((short_base["elements"] as Array)[1] as Dictionary)["fill"]), "soft": 8.0}
	var chin_cov := Skins.cover(as_written, Rect2(Vector2.ZERO, Vector2(150, 210)), 1.0, mask_outline, Vector2(150, 210))
	_ok(chin_cov != null and chin_cov.get_pixel(112, 175).a < 0.5, "THE CONTROL: drawn as written, the base left the right of the chin bare")
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
		lifts += 1 if float(kk[3]) > 0.5 and float((prog["keys"][k - 1] as Array)[4]) > TablePaint.PRESSED else 0
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
	# ...AND LET GO, THEY COME BACK STRAIGHT AND HARDLY PAST IT (the user, 2026-11-07, of the liner: "Bristles aren't floppy, and quick
	# movement shouldn't cause them to wiggle at all really"): swung past by no more than a twentieth of the bend they had, and back
	# within a tenth of a second. THE CONTROL: the spring they had (3.6 Hz, damped 0.38) swings past by a sixth and more
	var swing := func(hz: float, damping: float) -> Vector2:
		var most := 0.0
		var back_at := INF
		for k in 60:
			var b: Array = Bristles.response(drag, 1.0 + float(k) * 0.005, hz, damping)
			most = maxf(most, (b[0] as Vector3).x)
			if is_inf(back_at) and absf((b[0] as Vector3).x) < absf((during[0] as Vector3).x) * 0.1:
				back_at = float(k) * 0.005
		return Vector2(most / absf((during[0] as Vector3).x), back_at)
	var now_swing: Vector2 = swing.call(Bristles.SPRING_HZ, Bristles.SPRING_DAMPING)
	_ok(now_swing.x < 0.05 and now_swing.y <= 0.1, "let go, the hairs swing past straight by %.2f of their bend, and are back in %.3f s" % [now_swing.x, now_swing.y])
	var old_swing: Vector2 = swing.call(3.6, 0.38)
	_ok(old_swing.x > 0.16, "THE CONTROL: the spring the hairs had swings past by only %.2f of their bend" % old_swing.x)
	# ...AND MOVED THROUGH THE AIR, quickly, THEY STAY STRAIGHT (a liner carried between strokes had curled over); the control, pressed
	# onto a surface and dragged as fast, they trail
	var flown: Array = Bristles.target(Vector3(0.4, 0.0, 0.0), 0.0, 0.02, Vector3.UP)
	var dragged: Array = Bristles.target(Vector3(0.4, 0.0, 0.0), 1.0, 0.02, Vector3.UP)
	_ok((flown[0] as Vector3).length() < 1e-9, "moved quickly through the air, the hairs bend %.1f mm" % ((flown[0] as Vector3).length() * 1000.0))
	_ok((dragged[0] as Vector3).x < -0.002 and (dragged[0] as Vector3).length() <= Bristles.DRAG_BEND * 0.02 + 1e-9,
		"THE CONTROL: pressed and dragged as fast, the hairs bend %s" % dragged[0])
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
	# ...LEANED, THEY BEND MORE THAN THEY SPLAY (the user, 2026-11-07: a fat brush "balloons into a mushroom shape" where an artist would
	# "lean the brush slightly, such that the bristles bend"): held 40 degrees off the face, pressed as hard, a quarter of the splay. THE
	# CONTROL: pressed straight down, it mushrooms as it always did
	var leaned_ax := Vector3(0.0, cos(deg_to_rad(40.0)), sin(deg_to_rad(40.0)))
	var leaned: Array = Bristles.target(Vector3.ZERO, 1.0, 0.02, leaned_ax, -(leaned_ax - Vector3.UP * leaned_ax.y))
	var upright: Array = Bristles.target(Vector3.ZERO, 1.0, 0.02, Vector3.UP, Vector3.ZERO)
	_ok(float(leaned[1]) <= Bristles.PRESS_SPLAY * 0.3 and (leaned[0] as Vector3).length() > 0.002,
		"leaned 40 degrees and pressed, a brush splays %.2f (upright, %.2f) and bends %.1f mm" % [float(leaned[1]), Bristles.PRESS_SPLAY, (leaned[0] as Vector3).length() * 1000.0])
	_ok(absf(float(upright[1]) - Bristles.PRESS_SPLAY) < 1e-6, "THE CONTROL: pressed straight down, a brush splays %.2f, not %.2f" % [float(upright[1]), Bristles.PRESS_SPLAY])
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
	# THE CORE STAYS UNDER THE HAIRS (the user, 2026-11-07: a fat brush pressed in kept "a weird ring" of its paint "ABOVE the moving
	# bristles"): a dome's core, which takes their paint, stands no higher up the tuft than the ends of its outer hairs, at rest or pressed
	# as hard as it is - and pressed, it is drawn in under them. THE CONTROL: the core as it was, as tall as the middle hairs and splayed
	# as a hair is, stood millimeters over them
	var dome := {}
	Bristles.sanitize({"kind": "dome", "length": 2.0, "width": 1.6}, dome)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var tuft: Props.Tris = Bristles.build(dome, rng)
	var rest := _core_over(tuft, dome, 0.0, false)
	var full := _core_over(tuft, dome, Bristles.PRESS_SPLAY, false)
	var was := _core_over(tuft, dome, Bristles.PRESS_SPLAY, true)
	print("  a dome's core over its outer hairs' ends: %.1f mm at rest, %.1f mm pressed (as it was, %.1f mm); its painted band %.2f of its room across pressed (as it was, %.2f)" % [rest.x * 1000.0, full.x * 1000.0, was.x * 1000.0, full.y, was.y])
	_ok(rest.x < 0.0 and full.x < 0.0, "a dome's core stands over the ends of its outer hairs: %.1f mm at rest, %.1f mm pressed" % [rest.x * 1000.0, full.x * 1000.0])
	_ok(full.y < rest.y, "pressed, a dome's core is not drawn in under its hairs: %.2f of its room across, %.2f at rest" % [full.y, rest.y])
	_ok(was.x > 0.002 and was.y > rest.y, "THE CONTROL: the core as it was stood %.1f mm over the outer hairs, %.2f across pressed" % [was.x * 1000.0, was.y])
	# A BRUSH IS DRAWN THE WAY ITS STROKE GOES (the user: "pull THROUGH the stroke"): pressed along a stroke, each key the way it goes there
	# (at a corner between the two ways); lifted at its end, as it went; on its way to the next, as it will go; a dab, no way at all
	var ks := [[0.0, 0, 0, 2, 0, 0], [0.1, 0, 0, 0, 1, 0], [0.2, 10, 0, 0, 1, 0], [0.3, 10, 10, 0, 1, 0], [0.4, 10, 10, 2, 0, 0],
		[0.6, 30, 0, 2, 0, 0], [0.7, 30, 0, 0, 1, 0], [0.8, 30, -10, 0, 1, 0], [0.9, 30, -10, 2, 0, 0], [1.1, 50, 0, 2, 0, 0],
		[1.2, 50, 0, 0, 1, 0], [1.3, 50, 0, 2, 0, 0]]
	var pl := TablePaint._pulls_of(ks)
	var want := [Vector2.RIGHT, Vector2.RIGHT, Vector2(1, 1).normalized(), Vector2.DOWN, Vector2.DOWN, Vector2.UP, Vector2.UP, Vector2.UP,
		Vector2.UP, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
	var wrong := PackedStringArray()
	for k in ks.size():
		if pl[k].distance_to(want[k]) > 1e-4:
			wrong.append("key %d %s, not %s" % [k, pl[k], want[k]])
	_ok(wrong.is_empty(), "a brush is not drawn the way its strokes go: %s" % "; ".join(wrong))
	# ...THE WAY OF A STRETCH, NEVER OF A STEP (feedback 0014: "This brush is jittering/jerking back and forth, at the top side, while the
	# point remains perfectly still drawing lines"): a traced line, keys a quarter millimeter apart, wobbling 12 degrees either way every
	# 2.5 mm, as 732687's was - its lean turns back no more than twice and stays within 6 degrees of the line; a stroke 15 degrees from
	# the last is leaned as that one was, one 40 degrees from it turned to whole. THE CONTROL: each key's own two steps, as it was
	var wav := [[0.0, 10.0, 50.0, 2.0, 0.0, 0]]
	for i in 161:
		var x := 10.0 + float(i) * 0.25
		wav.append([0.1 + float(i) * 0.03, x, 50.0 + 0.084 * sin(TAU * (x - 10.0) / 2.5), 0.0, 1.0, 0])
	wav.append([5.0, 50.0, 50.0, 2.0, 0.0, 0])
	var wp := TablePaint._pulls_of(wav)
	var turns_back := func(angs: PackedFloat32Array) -> int:
		var n_back := 0
		var last_sign := 0.0
		for j in range(1, angs.size()):
			var dd := angs[j] - angs[j - 1]
			if absf(dd) > 0.2:
				if last_sign != 0.0 and signf(dd) != last_sign:
					n_back += 1
				last_sign = signf(dd)
		return n_back
	var now_angs := PackedFloat32Array()
	var was_angs := PackedFloat32Array()
	var off_most := 0.0
	for k in range(1, wav.size() - 1):
		now_angs.append(rad_to_deg(wp[k].angle()))
		off_most = maxf(off_most, absf(rad_to_deg(wp[k].angle())))
		var came := (Vector2(wav[k][1], wav[k][2]) - Vector2(wav[k - 1][1], wav[k - 1][2])).normalized() if k > 1 else Vector2.ZERO
		var goes := (Vector2(wav[k + 1][1], wav[k + 1][2]) - Vector2(wav[k][1], wav[k][2])).normalized() if k < wav.size() - 2 else Vector2.ZERO
		was_angs.append(rad_to_deg((came + goes).angle()))
	print("  along a wobbling line the brush's lean turns back %d times, %.1f degrees off it at most (each key's own steps: %d times)" % [
		turns_back.call(now_angs), off_most, turns_back.call(was_angs)])
	_ok(turns_back.call(now_angs) <= 2 and off_most <= 6.0, "along a wobbling line the lean turns back %d times, %.1f degrees off it" % [turns_back.call(now_angs), off_most])
	_ok(turns_back.call(was_angs) >= 20, "THE CONTROL: by each key's own steps it turned back only %d times" % turns_back.call(was_angs))
	var three := []
	for st in [[0.0, Vector2(10, 100)], [15.0, Vector2(10, 110)], [55.0, Vector2(10, 120)]]:
		var d := Vector2.from_angle(deg_to_rad(float(st[0])))
		var at: Vector2 = st[1]
		var t0 := float(three.size()) * 2.0
		three.append([t0, at.x, at.y, 2.0, 0.0, 0])
		for j in 21:
			var q := at + d * float(j)
			three.append([t0 + 0.1 + float(j) * 0.05, q.x, q.y, 0.0, 1.0, 0])
		var e := at + d * 20.0
		three.append([t0 + 1.5, e.x, e.y, 2.0, 0.0, 0])
	var tp3 := TablePaint._pulls_of(three)
	var kept := rad_to_deg(tp3[23 + 10].angle())
	var turned := rad_to_deg(tp3[46 + 10].angle())
	_ok(absf(kept) < 1.0 and absf(turned - 55.0) < 1.0, "a stroke 15 degrees from the last leans at %.1f (as that one, 0), one 40 degrees from it at %.1f (55)" % [kept, turned])
	return true


## HOW FAR [param g]'s CORE STANDS OVER THE ENDS OF ITS OUTER HAIRS (meters up the tuft; the shortest tenth of its hairs' tips) and how wide
## its painted band is (the most of it across, a share of the hairs' room) - tuft [param p] splayed [param splay] as prop_common.gdshaderinc
## draws it ([method Bristles.core_at]), or [param as_was]: as tall as its middle hairs and splayed as a hair.
static func _core_over(g: Props.Tris, p: Dictionary, splay: float, as_was: bool) -> Vector2:
	var hw := float(p["width"]) * 0.005
	var hd := float(p["thick"]) * 0.005
	var dome := float((Bristles.KINDS[String(p["kind"])] as Dictionary)["dome"])
	var tips: Array = []
	var top := -INF
	var wide := 0.0
	for i in g.v.size():
		var q: Vector3 = g.v[i]
		var s := clampf(g.uv2[i].x, 0.0, 1.0)
		if g.uv[i].x < Bristles.CORE_MARK - 0.5:
			if s > 0.99:
				tips.append(q.y)
			continue
		var y := q.y
		var out_by := splay * s * 1.2
		if as_was:
			y /= 1.0 - dome
		else:
			var c := Bristles.core_at(s, splay)
			y -= q.y * c.y
			out_by = c.z
		top = maxf(top, y)
		if s >= 0.55:
			wide = maxf(wide, Vector2(q.x / hw, q.z / hd).length() * (1.0 + out_by))
	tips.sort()
	return Vector2(top - float(tips[tips.size() / 10]), wide)


## A MASK ON ITS STAND, a jar of brushes, a flat brush in a jar of its own, a sponge on its dish, a powder puff on its pot and two pots
## of paint - the station, in centimeters.
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
		{"name": "flat jar", "at": [28, 6], "parts": [
			{"shape": "lathe", "profile": [[0, 0], [3, 0], [3, 8], [2.7, 8], [2.7, 0.5], [0, 0.5]], "material": "glaze"},
			{"name": "flat", "joint": {"kind": "free"}, "at": [0, 0.5, 0], "turn": [0, 0, 8], "parts": [
				{"shape": "tube", "path": [[0, 0, 0], [0, 11, 0]], "radius": 0.35, "material": "walnut"},
				{"shape": "lathe", "profile": [[0, 0], [0.5, 0], [0.45, 1.8], [0, 1.8]], "at": [0, 11, 0], "material": "brass"},
				{"shape": "tuft", "kind": "flat", "length": 1.6, "width": 1.0, "at": [0, 12.8, 0], "material": "sable"}]}]},
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
		{"name": "powder pot", "at": [-30, 14], "parts": [
			{"shape": "lathe", "profile": [[0, 0], [3.6, 0], [3.8, 3.2], [3.5, 3.2], [3.3, 0.3], [0, 0.3]], "material": "glaze"},
			{"name": "puff", "shape": "ball", "size": [6.5, 1.8, 6.5], "at": [0, 3.2, 0], "joint": {"kind": "free"}, "material": "velvet"}]},
		{"name": "black pot", "at": [9, 12], "parts": [
			{"shape": "lathe", "profile": [[0, 0], [2.5, 0], [2.5, 2], [2.2, 2], [2.2, 0.4], [0, 0.4]], "material": "glaze"},
			{"shape": "lathe", "profile": [[0, 0.4], [2.2, 0.4], [2.2, 1.6], [0, 1.6]], "material": "black paint"}]}],
		"materials": {"walnut": {"kind": "wood", "color": "#3a2a1e"}, "bisque": {"kind": "ceramic", "color": "#ebe5da", "polish": 0.05},
			"glaze": {"kind": "ceramic", "color": "#202226", "polish": 0.8}, "brass": {"kind": "metal", "color": "#b08d3c"},
			"sable": {"kind": "fabric", "color": "#5a3a24"}, "foam": {"kind": "sponge", "color": "#f0d6c4"},
			"velvet": {"kind": "fabric", "color": "#e8c9c9", "polish": 0.7},
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
	# (and a band wider than the liner is, which its strokes leave bare along its edges for it to go back over)
	var doc := design()
	(((doc["designs"] as Array)[0] as Dictionary)["elements"] as Array).append({"id": "band", "stage": "lines", "paint": "#121214",
		"line": "M 22 138 C 32 131 42 131 52 138", "width": 4.0})
	m._work.skin_doc = doc
	var acts := {"acts": [
		{"name": "base", "beat": 1, "length": "under", "about": "the base stippled on",
			"tracks": [{"thing": "sponge", "part": "wedge", "law": "paint", "on": "mask/face", "paint": ["base"], "from": "white pot"}]},
		{"name": "brow", "beat": 2, "length": "under", "about": "a brow drawn",
			"tracks": [{"thing": "brush jar", "part": "liner", "law": "paint", "on": "mask", "paint": ["brow", "band", "no such"], "from": "black pot"}]}]}
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
	# AN ELEMENT IS TAKEN FROM THE POT ITS DESIGN NAMES (feedback 0001: a base mixed grey-green, its plan naming the white pot, went back
	# for more to the amber - the cream nearest its color): a dark grey whose plan names the white pot is laid in the white's paint. THE
	# CONTROL: with no pot named, the cream nearest it - the black's.
	var from_white := tp._pot_of({"from": "white pot"}, {"paint": "#303030", "kind": "fill"})
	var from_black := tp._pot_of({"from": "black pot"}, {"paint": "#303030", "kind": "fill"})
	var named := tp._pot_of({}, {"paint": "#303030", "kind": "fill", "plan": {"pot": "white pot"}})
	_ok(named == from_white and named != from_black, "a dark grey whose design names the white pot is laid in %s, not the white's %s" % [named, from_white])
	var unnamed := tp._pot_of({}, {"paint": "#303030", "kind": "fill"})
	_ok(unnamed == from_black, "THE CONTROL: a dark grey naming no pot is laid in %s, not the black's %s" % [unnamed, from_black])
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
			var pressed := float((prog_keys[k] as Array)[4]) > TablePaint.PRESSED and float((prog_keys[k + 1] as Array)[4]) > TablePaint.PRESSED
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
			# (its tip as its hairs are bent, pressed past its point - feedback 0052, TablePaint.TIP_PUSH)
			var bend_now: Variant = ((tool["tufts"] as Array)[0]["mat"] as ShaderMaterial).get_shader_parameter("bristle_bend")
			var tip := m._work._world_of((m._work.works[lw] as Dictionary)["node"]) * (TablePaint._bent_tip(tool, bend_now) if bend_now is Vector3 else tip_l)
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
	# A BRUSH IS PULLED THROUGH ITS STROKE (the user, 2026-11-07: "a real artist would turn the brush, to pull THROUGH the stroke at the same
	# angle"): drawn each of eight ways across the cheek, the liner's handle leans the way it goes, and along the brow, at every key it is
	# drawn. THE CONTROL, held as before - up and out to its side whichever way it went - it leaned against some of the eight
	var xf_s: Transform3D = tp.skins[si]["xform"]
	var cheek := Vector2(frame.x * 0.3, frame.y * 0.55)
	var n_c: Vector3 = (tp.at_mm(si, cheek)[1] as Vector3).normalized()
	var lean_of := func(ax: Vector3, nn: Vector3, d: Vector2) -> float:
		var v := xf_s.basis.inverse() * (ax - nn * ax.dot(nn))
		return Vector2(v.x, -v.y).normalized().dot(d)
	var along_n := 0
	var against_was := 0
	for k in 8:
		var d := Vector2.from_angle(TAU * float(k) / 8.0)
		if float(lean_of.call(tp._held_axis(si, cheek, n_c, tool, "tip", d), n_c, d)) > 0.95:
			along_n += 1
		if float(lean_of.call(tp._held_axis(si, cheek, n_c, tool, "tip"), n_c, d)) < 0.0:
			against_was += 1
	_ok(along_n == 8, "drawn each of eight ways, the liner leans the way it goes only %d ways" % along_n)
	_ok(against_was >= 3, "THE CONTROL: held as before, the liner leaned against the way it went only %d ways of eight" % against_was)
	var brow_prog: Dictionary = (((tp.skins[si]["items"] as Dictionary).get("brow", {}) as Dictionary).get("made", {}) as Dictionary).get("program", {})
	var brow_held: Dictionary = (tp.skins[si].get("held", {}) as Dictionary).get(TablePaint._held_key(brow_prog, String(tool.get("ch", "")), "tip"), {})
	var bh: PackedVector4Array = brow_held.get("held", PackedVector4Array())
	var bk: Array = brow_prog.get("keys", [])
	var bp := TablePaint._pulls_of(bk)
	var drawn := 0
	var leans := 0
	for k in mini(bh.size(), bk.size()):
		if float((bk[k] as Array)[4]) <= TablePaint.PRESSED or bp[k] == Vector2.ZERO:
			continue
		drawn += 1
		var nk: Vector3 = (tp.at_mm(si, Vector2(float((bk[k] as Array)[1]), float((bk[k] as Array)[2])))[1] as Vector3).normalized()
		if float(lean_of.call(Vector3(bh[k].x, bh[k].y, bh[k].z), nk, bp[k])) > 0.5:
			leans += 1
	print("  along the brow the liner leans the way it is drawn at %d of %d keys" % [leans, drawn])
	_ok(drawn >= 10 and leans == drawn, "along the brow the liner leans the way it is drawn at %d of %d keys" % [leans, drawn])
	# ...A LINE WIDER THAN THE LINER LAID IN PULLS SIDE BY SIDE, as the band its hairs sweep, nothing of it left bare to go back for (2026-11-07:
	# "a proper brush stroke is more often than not very smooth, with clean edges"; feedback 0060, of the touch-ups: "tapping at each jagged
	# place") - THE CONTROL: one pull down its middle, a liner wide, leaves its edges bare
	var band_made: Dictionary = ((tp.skins[si]["items"] as Dictionary).get("band", {}) as Dictionary).get("made", {})
	var band_foot: Image = band_made.get("foot", null)
	var band_el := tp.element(si, "band")
	var band_rect: Rect2 = band_made.get("rect", Rect2())
	var bare_of := func(foot: Image) -> Vector2i:
		if foot == null:
			return Vector2i(-1, 0)
		var fpx := float(foot.get_width()) / maxf(band_rect.size.x, 1.0)
		var cv := Skins.cover(band_el, band_rect, fpx, String(tp.skins[si].get("outline", "")), tp.skins[si]["frame"])
		var n_bare := 0
		var n_all := 0
		for y in mini(cv.get_height(), foot.get_height()):
			for x in mini(cv.get_width(), foot.get_width()):
				n_all += int(cv.get_pixel(x, y).a > 0.5)
				n_bare += int(cv.get_pixel(x, y).a > 0.5 and foot.get_pixel(x, y).r < 0.5)
		return Vector2i(n_bare, n_all)
	var band_counts: Vector2i = bare_of.call(band_foot)
	var band_bare := band_counts.x
	var band_all := band_counts.y
	# (...but where its last pull's tail thins, at its end - "which might fade near the tail of the stroke")
	_ok(band_bare >= 0 and band_bare < band_all * 0.06 and not band_made.has("gaps"),
		"a band wider than the liner is laid whole in pulls side by side: %d of its %d points bare" % [band_bare, band_all])
	var one_pull := {"natural": 5.0, "strokes": []}
	for run in Skins._strokes_of(String(band_el["d"])):
		var ts := PackedFloat32Array()
		ts.resize((run as PackedVector2Array).size())
		for k in ts.size():
			ts[k] = 5.0 * float(k) / float(maxi(ts.size() - 1, 1))
		(one_pull["strokes"] as Array).append({"pts": run, "t": ts, "r": float(tool["mm"]) * 0.5, "load": 1.0})
	var one_foot: Array = []
	Skins.band_map(one_pull, band_rect, float(band_foot.get_width()) / maxf(band_rect.size.x, 1.0) if band_foot != null else TablePaint.BRUSH_PX, one_foot)
	var one_bare: int = (bare_of.call(one_foot[0]) as Vector2i).x
	_ok(one_bare > band_bare + 20, "THE CONTROL: one pull down its middle leaves %d points of it bare" % one_bare)
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
		var kept_s: Dictionary = (tp.skins[si]["held"] as Dictionary).get(TablePaint._held_key(prog, "w%d:pose" % sw, "corner"), {})
		var held: PackedVector4Array = kept_s.get("held", PackedVector4Array())
		var ways_s: PackedByteArray = kept_s.get("ways", PackedByteArray())
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
			# (as hard as it presses: a press put in where the first missed is harder, TablePaint.PRESS_HARD - and held the way that reaches
			# it, by what of it touches that way: its long end, or its face under a chin)
			var way: String = TablePaint.WAYS[ways_s[j]] if j < ways_s.size() and ways_s[j] > 0 else "corner"
			var wc: Dictionary = (stool.get("contacts", {}) as Dictionary).get(way, corner)
			var w_tip: Vector3 = wc.get("tip", corner_tip)
			var w_grip: Vector3 = wc.get("grip", corner_grip)
			var tip := nx * w_tip + (nx.basis * (w_grip - w_tip)).normalized() * float(wc.get("give", TablePaint.GIVE)) * float(kk[4])
			var off := _off_face(face_mesh, tp, si, tip)
			var owed := held[j].w if j < held.size() else 0.0
			stood_off = maxf(stood_off, owed)
			pressed += 1
			# (a press on the rim itself is past where a ray straight in finds the face)
			if off < INF:
				sworst = maxf(sworst, absf(off - owed))
				on_face += 1
	_ok(pressed >= 10 and on_face >= pressed * 0.8 and sworst < 0.0015, "the sponge's corner is not on the face as it stipples: %d presses, %d found on it, %.2f mm off at worst" % [pressed, on_face, sworst * 1000.0])
	# (4.5 mm: what is thin is filled while the hand is there too - TablePaint._gaps_left - and some of it lies in the tight places
	# beside the nose, where the corner is stood off a little further to clear the face round it)
	_ok(stood_off < 0.0045, "the sponge's corner is stood %.1f mm off the face to clear it" % (stood_off * 1000.0))
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
	# ITS OWN PAINT, NEVER THE PAINTING'S PIXELS (feedback 0049: "we are just revealing the underlying PNG through transparency
	# manipulation"): an element draws from its own maps alone - its marks' own build-up among them (`laid_map`, `laid_when`) - whatever its
	# design was copied from - THE CONTROL: the shader as it was, which read the painting too
	var own := ["cover", "foot", "blend_map", "when_map", "laid_map", "laid_when", "laid_map2", "laid_when2", "tint_map"]
	var pictures_of := func(code: String) -> Array:
		var names := []
		for line in code.split("\n"):
			if line.strip_edges().begins_with("uniform sampler2D "):
				names.append(line.strip_edges().trim_prefix("uniform sampler2D ").get_slice(" ", 0).trim_suffix(";"))
		return names
	var code := (TablePaint._CANVAS as Shader).code
	var read: Array = pictures_of.call(code)
	_ok(read.size() == own.size() and read.all(func(n): return own.has(n)), "an element draws from more than its own maps: %s" % [read])
	var was: Array = pictures_of.call(code + "\nuniform sampler2D reference : source_color, filter_linear, repeat_disable;\n")
	_ok(not was.all(func(n): return own.has(n)), "THE CONTROL: the shader that read the painting draws from its own maps alone")
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
	# (its mesh's own vertices and the way each faces, as its shader is handed them)
	var sponge_mesh: MeshInstance3D = ((tp.tools["w%d:pose" % sw] as Dictionary)["sponges"][0] as Dictionary)["mesh"]
	var sponge_arrays := sponge_mesh.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = sponge_arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = sponge_arrays[Mesh.ARRAY_NORMAL]
	m._work._planned = true
	# how deep the sponge stands in the face as it is drawn, at most, at every place it keeps through an act, how many it kept, and how
	# deep as it is held, never taking the face's shape
	var deepest := func(act: String) -> Vector3:
		var t: Array = times[act]
		var plan := tp.plan_of(_track_of(m, act), float(t[1]) - float(t[0]))
		var worst := 0.0
		var worst_held := 0.0
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
				# ...AS IT IS DRAWN: pressed onto the face, taking its shape (feedback 0041), or squashed back from its middle, as its material
				# has it (prop_common.gdshaderinc - [method TablePaint.pressed_drawn])
				var sq: Vector4 = sponge_mat.get_shader_parameter("squash")
				var sq_at: Vector3 = sponge_mat.get_shader_parameter("squash_at")
				var sq_d := Vector3(sq.x, sq.y, sq.z).normalized() if sq.w > 0.0 else Vector3.ZERO
				var mx := m._work._world_of(sponge_mesh)
				for vi in verts.size():
					var q: Vector3 = verts[vi]
					var v: Vector3 = q - sq_d * maxf((q - sq_at).dot(sq_d), 0.0) * sq.w
					var held_off := _off_face(face_mesh, tp, 0, mx * v)
					if held_off < INF:
						worst_held = maxf(worst_held, -held_off)
					var off := _off_face(face_mesh, tp, 0, mx * tp.pressed_drawn(sponge_mat, 0, v, norms[vi]))
					if off < INF:
						worst = maxf(worst, -off)
				count += 1
		return Vector3(worst, count, worst_held)
	var stippled: Vector3 = deepest.call("stipple")
	var blended: Vector3 = deepest.call("blend")
	# (drawn on the face's heights found every 2 mm, a nose's ridge peaking between them stands over what it is laid on)
	var within := 0.0015
	_ok(stippled.y > 50 and stippled.x < within, "the sponge stippling by its corner stands %.1f mm in the face, over %d places" % [stippled.x * 1000.0, stippled.y])
	_ok(blended.y > 50 and blended.x < within, "the sponge blending flat stands %.1f mm in the face, over %d places" % [blended.x * 1000.0, blended.y])
	# THE CONTROLS: as it is held, never drawn taking the face's shape, it stands in the face as far as it gives (feedback 0041); and with
	# nothing held clear, as a hand holds it alone, the flat face over the nose goes into it
	_ok(blended.z > 0.0015, "THE CONTROL: as it is held, never taking the face's shape, the sponge stands only %.1f mm in the face" % (blended.z * 1000.0))
	var kept: Dictionary = tp.skins[0]["held"]
	tp.skins[0]["held"] = {}
	# (...and nothing keeping the drawn pose out of the face either, which would hold it clear on its own - [method TablePaint._kept_out])
	tp.keep_out = false
	var unheld: Vector3 = deepest.call("blend")
	tp.keep_out = true
	tp.skins[0]["held"] = kept
	_ok(unheld.z > 0.008, "THE CONTROL: blended flat with nothing held clear, the sponge stands only %.1f mm in the face" % (unheld.z * 1000.0))
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
		# ...A PRESS PUT IN WHERE THE FIRST MISSED, HELD THE WAY THAT REACHES IT (520084: the corner, come from above, stood off a chin's
		# underside; flat, it reached): every put-in press held otherwise than by its corner misses where it is aimed, held by its corner, by
		# more than a millimeter, and touches nearer the way it is held - THE CONTROL: no press of the plan is held but by its corner
		var kept_b: Dictionary = (tp.skins[0]["held"] as Dictionary).get(TablePaint._held_key(prog, "w%d:pose" % sw, "corner"), {})
		var ways_b: PackedByteArray = kept_b.get("ways", PackedByteArray())
		var tool_b: Dictionary = tp.tools["w%d:pose" % sw]
		var turned := 0
		var turned_right := 0
		var planned := 0
		var planned_turned := 0
		var bkeys: Array = prog["keys"]
		var seen_b := {}
		# (the plan's presses are its own places - a press put in at the first look is pressed no harder than they are)
		var planned_at := {}
		for st in (made["planned"] as Dictionary)["strokes"]:
			planned_at[((st as Dictionary)["pts"] as PackedVector2Array)[0]] = true
		var nb := mini(bkeys.size(), ways_b.size())
		var j := 0
		while j < nb:
			var kb: Array = bkeys[j]
			var xy := Vector2(float(kb[1]), float(kb[2]))
			# ...THE KEYS AT ONE PLACE ONE PRESS, as hard as the hardest of them, as TablePaint._held_keys holds it: a thin patch is pressed
			# again where the press put in for it was, straight after it
			var hard := 0.0
			var way := 0
			var kj := j
			while kj < nb and Vector2(float((bkeys[kj] as Array)[1]), float((bkeys[kj] as Array)[2])) == xy:
				hard = maxf(hard, float((bkeys[kj] as Array)[4]))
				way = maxi(way, ways_b[kj])
				kj += 1
			j = maxi(kj, j + 1)
			if hard < 0.99 or seen_b.has(xy):
				continue
			seen_b[xy] = true
			if planned_at.has(xy):
				planned += 1
				if way > 0:
					planned_turned += 1
				continue
			if way > 0:
				var wn: String = TablePaint.WAYS[way]
				turned += 1
				var own_miss := tp._press_miss(0, xy, tool_b, "corner", tp._cleared(0, xy, tool_b, "corner"), hard)
				if own_miss > TablePaint.AIM_MET and tp._press_miss(0, xy, tool_b, wn, tp._cleared(0, xy, tool_b, wn), hard) < own_miss - TablePaint.REACH_BETTER:
					turned_right += 1
		print("  presses put in held another way: %d, %d where the corner missed and it reached nearer; of %d planned, %d" % [turned, turned_right, planned, planned_turned])
		_ok(turned > 0 and turned_right == turned, "a press put in was held another way where its corner reached as near: %d of %d" % [turned - turned_right, turned])
		_ok(planned > 50 and planned_turned == 0, "THE CONTROL: %d of %d presses of the plan were held other than by the corner" % [planned_turned, planned])
		# ...AND WHAT NO PRESS REACHED, PAINTED ALL THE SAME (the user: "just dab in that area, and paint it anyway"): each point of what the
		# last look found bare laid when the touch aimed nearest it comes down - THE CONTROL: with nothing bare, nothing is added
		var two_touches := [{"u": 0.1, "load": 1.0, "pts": PackedVector2Array(), "st": 0, "aim": Vector2(10, 10)},
			{"u": 0.9, "load": 0.5, "pts": PackedVector2Array(), "st": 1, "aim": Vector2(30, 10)}]
		var anyway := TablePaint._painted_anyway(two_touches, [PackedVector2Array([Vector2(12, 10), Vector2(28, 10), Vector2(27, 11)])])
		var by_u := {}
		for tc in anyway:
			if (tc as Dictionary).get("anyway", false):
				by_u[float((tc as Dictionary)["u"])] = ((tc as Dictionary)["pts"] as PackedVector2Array).size()
		_ok(anyway.size() == 4 and by_u.get(0.1, 0) == 1 and by_u.get(0.9, 0) == 2, "what was left bare is not laid with the touch nearest each point: %s" % [anyway])
		_ok(TablePaint._painted_anyway(two_touches, []).size() == 2, "THE CONTROL: with nothing bare, something is added")
		# ...AND WHAT ONE PRESS ALONE REACHED, LAID AGAIN BY ONE AFTER IT (feedback 0001: "a tiny spot just under the nose that is slightly
		# more transparent than the rest of the white"): a point the first touch reached, nearest its aim, is laid by the second - THE
		# CONTROL: not told what reached it, it is laid by the nearest, its own press again, and stays a single press's film
		var thin_by := func(firsts: Array) -> float:
			for tc in TablePaint._painted_anyway(two_touches, [PackedVector2Array([Vector2(12, 10)])], firsts):
				if (tc as Dictionary).get("anyway", false):
					return float((tc as Dictionary)["u"])
			return -1.0
		_ok(is_equal_approx(thin_by.call([PackedInt32Array([0])]), 0.9), "a point the first press reached is laid again by %.1f, not the press after it" % thin_by.call([PackedInt32Array([0])]))
		_ok(is_equal_approx(thin_by.call([]), 0.1), "THE CONTROL: not told what reached it, a point was laid by %.1f, not its nearest" % thin_by.call([]))
		# ...AND WHAT ONE PRESS ALONE REACHED, GONE OVER AGAIN (feedback 0001: "missing specks of makeup all over this face ... it's completely
		# ignoring the ugly missing specks right at the center of the face"): one dab leaves a thin, uneven film that only a second press
		# fills (skin_paint.gdshader's `again`, the map's third channel), so next to nothing of what the stipple covers is left to one press
		# alone - THE CONTROL: its presses as planned, before any was put in, left much of it so
		var inside_s := TablePaint.covered_in(cov_s)
		var alone_of := func(img: Image) -> float:
			var n := 0
			for y in mini(img.get_height(), cov_s.get_height()):
				for x in mini(img.get_width(), cov_s.get_width()):
					var pv := img.get_pixel(x, y)
					if inside_s[y * cov_s.get_width() + x] == 1 and pv.r < Skins.NEVER and pv.b >= Skins.NEVER:
						n += 1
			return float(n) / (Skins.WHEN_PX * Skins.WHEN_PX)
		var covered_mm2 := float(inside_s.count(1)) / (Skins.WHEN_PX * Skins.WHEN_PX)
		var alone_now: float = alone_of.call(wm)
		var alone_planned: float = alone_of.call(Skins.touch_map(tp._stroke_touches(0, made["planned"], track, tool_s, "stipple"), made["rect"],
			Skins.WHEN_PX, TablePaint.PRESS_SPOT / Skins.WHEN_PX, inside_s, Skins.PRESS_RAGGED))
		print("  of the stipple's %.0f mm2, reached by one press alone: %.0f (its presses as planned, %.0f)" % [covered_mm2, alone_now, alone_planned])
		_ok(alone_now < 1.0, "of the stipple's %.0f mm2, %.0f were reached by one press alone" % [covered_mm2, alone_now])
		_ok(alone_planned >= covered_mm2 * 0.01, "THE CONTROL: its presses as planned left only %.0f of %.0f mm2 to one press alone" % [alone_planned, covered_mm2])
		var edge_now: Vector2i = past_edge.call(wm)
		var edge_was: Vector2i = past_edge.call(Skins.touch_map(made.get("touches", []), made["rect"]))
		print("  two points past the stipple's edge: %d of %d hold a moment (with nothing carried out, %d of %d)" % [edge_now.y, edge_now.x, edge_was.y, edge_was.x])
		_ok(edge_now.x > 50 and edge_now.y >= edge_now.x * 0.95, "two points past the stipple's edge, %d of %d hold a moment" % [edge_now.y, edge_now.x])
		# (...short of all of them: a thin patch at the rim is pressed again, and its presses reach past the edge of their own - 60% of the
		# ring two out)
		_ok(edge_was.y < edge_was.x * 0.8, "THE CONTROL: with nothing carried out, %d of %d did" % [edge_was.y, edge_was.x])
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
		# ...AND BUILT AGAIN (its acts reworked) IT GOES BACK OVER WHAT IT MISSED FROM ITS PLAN: the same presses in the same places, never
		# more put in over the last build's (2026-11-07: "The calculated index 36 is out of bounds (the array has 16 elements)") - THE
		# CONTROL: what the last build put in is more than the plan, so starting from it is not the same
		var first: Array = (made["program"] as Dictionary)["keys"]
		var planned_n := ((made.get("planned", {}) as Dictionary).get("strokes", []) as Array).size()
		tp.prepare()
		var again: Dictionary = ((tp.skins[0]["items"] as Dictionary).get("base", {}) as Dictionary).get("made", {})
		var second: Array = (again.get("program", {}) as Dictionary).get("keys", [])
		_ok(second == first, "built again, the stipple's program is not the one it had: %d keys, then %d" % [first.size(), second.size()])
		_ok(planned_n > 0 and planned_n < ((made["program"] as Dictionary)["strokes"] as Array).size(),
			"THE CONTROL: the stipple's plan has %d presses, no fewer than it was given (%d)" % [planned_n, ((made["program"] as Dictionary)["strokes"] as Array).size()])
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
	# (...a share, not a half: the patch is its drawn points within 1.5 mm of its lowest, and a sponge cut finely across its faces, so it
	# can bend over a pot, has more of them along its corner's edges)
	_ok(old_patch < patch * 0.65, "THE CONTROL: held by its corner through its middle, the sponge lay on its paint %.1f mm across (%.1f now)" % [
		old_patch * 1000.0, patch * 1000.0])
	print("  the sponge pressed %.1f mm into its paint, lying on it %.1f mm across (by its corner through its middle, %.1f), %.1f mm inside the pot's wall" % [
		hardest * 1000.0, patch * 1000.0, old_patch * 1000.0, -dipped * 1000.0])
	# ...and held flat by its face, a sponge wider than the mouth goes through the wall
	var flat := tp._node_at([tp._source_of("load", "white pot", "", float(st[0])), Vector3.UP, 1.0, false, pot[4], "face"], stool, stool["x0"])
	var flat_ws := PackedVector3Array()
	for q in pts:
		flat_ws.append(flat * q)
	_ok(float(past_wall.call(flat_ws)) > 0.002, "THE CONTROL: held flat in the pot the sponge stands only %.1f mm past its wall" % (float(past_wall.call(flat_ws)) * 1000.0))
	# ...SO A FACE TOO BROAD FOR THE MOUTH IS LAID OVER IT FLAT (feedback 0005, 2026-11-08: "You would expected it dabbed flat: resting on
	# both sides of the container, and compressed/pushed from the middle, into the container. It would bend in the middle"): upright, resting
	# on the rim, and pressed, bent down in its middle onto its paint - nothing of it past the wall, what is outside the mouth over the rim
	var fpot := tp._pot_hold("load", "white pot", "", float(st[0]), _track_of(m, "stipple"), "face")
	var draped := fpot.size() > 9 and fpot[9] is Vector4 and (fpot[9] as Vector4).w > 0.0
	_ok(draped, "a face wider than the pot's mouth is not laid over it: %s" % [fpot])
	if draped:
		var fx := tp._node_at(fpot, stool, stool["x0"])
		var dr := TablePaint._drape_on(fx, fpot[9], float(fpot[6]), 1.0, stool)
		var dws := PackedVector3Array()
		var d_low := INF
		var outside_low := INF
		var rest_low := INF
		for q in pts:
			var wq: Vector3 = fx * _drape_drawn(q, dr)
			dws.append(wq)
			d_low = minf(d_low, wq.y)
			rest_low = minf(rest_low, (fx * q).y)
			if Vector2(wq.x - rim.x, wq.z - rim.z).length() > float(mouth["r"]):
				outside_low = minf(outside_low, wq.y)
		var turned := (fpot[1] as Vector3).angle_to(Vector3.UP)
		_ok(turned < 0.01, "laid over the mouth, the sponge is turned %.0f degrees from flat" % rad_to_deg(turned))
		_ok(float(past_wall.call(dws)) < 0.0005, "laid over the mouth and pressed, the sponge stands %.1f mm past the pot's wall" % (float(past_wall.call(dws)) * 1000.0))
		_ok(outside_low >= rim.y - 0.0002, "what of it rests on the rim goes %.1f mm under it" % ((rim.y - outside_low) * 1000.0))
		_ok(absf(d_low - float(fpot[6])) < 0.001, "laid over the mouth and pressed, its middle is drawn %.1f mm off its paint" % ((d_low - float(fpot[6])) * 1000.0))
		# THE CONTROLS: unbent, resting on the rim, it never reaches its paint; and fitted inside the mouth, as it had been, it stood tilted far over
		_ok(rest_low - float(fpot[6]) > 0.002, "THE CONTROL: unbent, resting on the rim, the sponge is only %.1f mm over its paint" % ((rest_low - float(fpot[6])) * 1000.0))
		var tilted: Dictionary = tp._pot_clear("white pot", stool, "face", tp._source_of("load", "white pot", "", float(st[0])), Vector3.UP, mouth, float(fpot[6]))
		var tilt := (tilted["axis"] as Vector3).angle_to(Vector3.UP)
		_ok(tilt > deg_to_rad(20.0), "THE CONTROL: fitted inside the mouth, the face is turned only %.0f degrees" % rad_to_deg(tilt))
		print("  a face too broad for the mouth laid over it: pressed, its middle %.1f mm into the pot and on its paint (unbent, %.1f mm over it); fitted inside, it had been turned %.0f degrees" % [
			(rim.y - d_low) * 1000.0, (rest_low - float(fpot[6])) * 1000.0, rad_to_deg(tilt)])
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


## Point [param q] of a tool (its node's space) as prop_common.gdshaderinc draws it laid over a pot's mouth and bent down into it, then
## pressed flat on its paint ([method TablePaint._drape_on]).
static func _drape_drawn(q: Vector3, dr: Dictionary) -> Vector3:
	var on: Vector4 = dr["on"]
	var at: Vector4 = dr["at"]
	var by: Vector4 = dr["by"]
	var n := Vector3(on.x, on.y, on.z).normalized()
	var rel := q - Vector3(at.x, at.y, at.z)
	var lat := rel - n * rel.dot(n)
	var d := lat.length() / at.w
	var v := q
	if d < 1.0:
		var up := clampf((q.dot(n) - on.w) / maxf(by.z, 1e-5), 0.0, 1.0)
		var fw := maxf(by.w, 0.05)
		v -= n * (by.x * pow(1.0 - d * d, 2.0) + by.y * exp(-d * d / (2.0 * fw * fw)) * up)
	var fb: Vector3 = dr["flat_by"]
	return _flat_drawn(v, dr["flat_on"], fb, dr["flat_at"]) if fb.x > 0.0 else v


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


## A PAD PRESSED ONTO THE FACE TAKES ITS SHAPE (feedback 0041): the arithmetic ([method TablePaint.press_lands]), and a puff patting a base
## over a whole face as it is drawn ([method TablePaint.pressed_drawn]) - in nothing, and lying on more of the face than held flat.
func _pad() -> bool:
	var mono := true
	for zf in [0.0, 0.004, 0.009]:
		for back in [0.0, 0.5, 1.0]:
			var last := -INF
			for k in 200:
				var hh := TablePaint.press_lands(-0.02 + float(k) * 0.0002, float(zf), float(back), 0.0032)
				mono = mono and hh >= last - 1e-9
				last = hh
	_ok(mono, "a bit of a pressed pad standing higher is drawn lower: it would pass through the rest")
	var sagged := TablePaint.press_lands(0.002, 0.0, 0.0, 0.0032)
	var stiff := TablePaint.press_lands(0.002, 0.0, 0.0, 0.0)
	_ok(sagged <= TablePaint._press_touches(), "a pad's face 2 mm over a hollow is drawn %.2f mm over it: it does not sag onto it" % (sagged * 1000.0))
	_ok(stiff > 0.0018, "THE CONTROL: with no sag, a face 2 mm over a hollow is drawn %.2f mm over it" % (stiff * 1000.0))
	var crushed := TablePaint.press_lands(-0.012, 0.018, 1.0, 0.0)
	_ok(crushed >= 0.018 * TablePaint.PRESS_THIN - 1e-6, "pushed 12 mm into the face, a pad's back 18 mm up its depth is drawn %.1f mm over it" % (crushed * 1000.0))
	var m := _medium()
	var spec := station()
	_stand(m, spec, "mask", Vector3(Tables.ORIGIN.x, 0.0, Tables.ORIGIN.y) + Vector3(0, 0, -0.06))
	_stand(m, spec, "powder pot", Vector3(Tables.ORIGIN.x, 0.0, Tables.ORIGIN.y) + Vector3(-0.17, 0, 0.1))
	m._work.skin_doc = {"designs": [{"thing": "mask", "part": "face", "name": "a base", "elements": [{"id": "base", "stage": "base", "paint": "#f6f2ea", "fill": "all"}]}]}
	m._work.build({"acts": [{"name": "pat", "beat": 1, "length": "under", "tracks": [{"thing": "powder pot", "part": "puff", "law": "paint", "on": "mask", "paint": ["base"], "manner": "pat"}]}]}, 1)
	var tp: TablePaint = m._work.paint
	_ok(tp != null and (m._work.acts as Array).size() == 1, "the puff's act was not kept: %s" % "; ".join(m._work.notes))
	if tp == null or (m._work.acts as Array).size() < 1:
		return true
	var times: Dictionary = m._work.rehearse(10.0)
	var pw: int = m._work._work_of(m._work._thing_named("powder pot"), "puff")
	var tool: Dictionary = tp.tools.get("w%d:pose" % pw, {})
	_ok(bool(tool.get("flat", false)) and not (tool.get("sponges", []) as Array).is_empty(), "the puff is not taken for a pad that gives: %s" % tool.get("kind", ""))
	if tool.is_empty() or (tool["sponges"] as Array).is_empty():
		return true
	var mat: ShaderMaterial = ((tool["sponges"] as Array)[0] as Dictionary)["mat"]
	var mesh: MeshInstance3D = ((tool["sponges"] as Array)[0] as Dictionary)["mesh"]
	var arrays := mesh.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var face_mesh := TableWork._ray_mesh(_faces_of(tp.skins[0]))
	m._work._planned = true
	var t: Array = times["pat"]
	var plan := tp.plan_of(_track_of(m, "pat"), float(t[1]) - float(t[0]))
	var worst := 0.0
	var worst_held := 0.0
	var count := 0
	var lying := 0
	var lying_held := 0
	var hard := TablePaint.PAD_GIVE * TablePaint.PRESS_SAG * 0.95
	for p in plan["phases"]:
		var pd: Dictionary = p
		if String(pd["kind"]) != "el":
			continue
		var keys: Array = (pd["prog"] as Dictionary)["keys"]
		var k := (float(pd["b"]) - float(pd["a"])) / float((pd["prog"] as Dictionary)["natural"])
		var moments := PackedFloat32Array()
		for j in range(0, keys.size() - 1, maxi(keys.size() / 40, 1)):
			for f in [0.0, 0.33, 0.67]:
				moments.append(lerpf(float((keys[j] as Array)[0]), float((keys[j + 1] as Array)[0]), float(f)))
		for tau in moments:
			m._work.tick(float(t[0]) + float(pd["a"]) + tau * k)
			var cells: Variant = mat.get_shader_parameter("press_cells")
			var pressed_hard: bool = cells is Vector4 and (cells as Vector4).w >= hard
			var up_own: Vector3 = mat.get_shader_parameter("press_up_own") if mat.get_shader_parameter("press_up_own") is Vector3 else Vector3.UP
			var mx := m._work._world_of(mesh)
			for vi in verts.size():
				var held_off := _off_face(face_mesh, tp, 0, mx * verts[vi])
				var off := _off_face(face_mesh, tp, 0, mx * tp.pressed_drawn(mat, 0, verts[vi], norms[vi]))
				if held_off < INF:
					worst_held = maxf(worst_held, -held_off)
				if off < INF:
					worst = maxf(worst, -off)
				# (...and pressed its hardest, how much of its face lies on the face)
				if pressed_hard and norms[vi].dot(up_own) < -0.2:
					lying += int(off < INF and absf(off) <= 0.001)
					lying_held += int(held_off < INF and absf(held_off) <= 0.001)
			count += 1
	print("  a puff patting a face: drawn %.1f mm in it at most (held %.1f), over %d places; pressed hardest, %d bits of its face on the face (held flat, %d)" % [worst * 1000.0, worst_held * 1000.0, count, lying, lying_held])
	_ok(count > 30 and worst < 0.0015, "the puff patting a face is drawn %.1f mm in it, over %d places" % [worst * 1000.0, count])
	_ok(lying > 0 and lying >= lying_held * 2, "pressed its hardest, %d bits of the puff's face lie on the face, %d held flat: it does not take the face's shape" % [lying, lying_held])
	_ok(worst_held > 0.004, "THE CONTROL: as it is held, never taking the face's shape, the puff stands only %.1f mm in the face" % (worst_held * 1000.0))
	m._root3.free()
	return true


## A BRUSH'S PAINT IS WHERE ITS HAIRS TOUCHED, AND A FILL KEEPS INSIDE ITS SHAPE (feedback 0042, 0043): the arithmetic, then a flat brush
## filling a diamond on a mask as it is drawn ([method TablePaint._keep_inside]) against its rows as they were.
func _inside() -> bool:
	# ...SMOOTHED AS PAINT SPREADS: a lone touch, and a line a millimeter wide, 20 mm long, touched every quarter millimeter
	var rect := Rect2(0, 0, 30, 20)
	var line := PackedVector2Array()
	for i in 80:
		for j in 3:
			line.append(Vector2(14.0 + float(i) * 0.25, 9.6 + float(j) * 0.4))
	var touches := [{"u": 0.1, "load": 1.0, "pts": PackedVector2Array([Vector2(5, 10)])}, {"u": 0.5, "load": 1.0, "pts": line}]
	var foot: Array = []
	var px := TablePaint.BRUSH_PX
	Skins.touch_map(touches, rect, px, TablePaint.BRUSH_SPOT, PackedByteArray(), 0.0, foot)
	var fi: Image = foot[0]
	var lone := fi.get_pixel(int(5.0 * px), int(10.0 * px)).r
	var mid := fi.get_pixel(int(24.0 * px), int(10.0 * px)).r
	_ok(lone < 0.3 and mid > 0.9, "smoothed, a lone hair's touch lays %.2f and a millimeter's line %.2f" % [lone, mid])
	var raw := Skins.touch_map(touches, rect, px, TablePaint.BRUSH_SPOT)
	_ok(raw.get_pixel(int(5.0 * px), int(10.0 * px)).r < Skins.NEVER, "THE CONTROL: unsmoothed, the lone touch is not laid at all")
	# ...EASED OFF where it ran past, then cut
	var way := {"pts": PackedVector2Array([Vector2(0, 0), Vector2(4, 0), Vector2(8, 0), Vector2(12, 0), Vector2(16, 0)]), "press": PackedFloat32Array([1, 1, 1, 1, 1])}
	var bad := PackedVector2Array([Vector2(16, 0)])
	var once: Array = TablePaint._ease_off([way], bad, 2.0)
	var twice: Array = TablePaint._ease_off(TablePaint._ease_off(once, bad, 2.0), bad, 2.0)
	var p1: PackedFloat32Array = (once[0] as Dictionary)["press"] if once.size() == 1 else PackedFloat32Array()
	_ok(p1.size() == 5 and is_equal_approx(p1[4], 0.5) and is_equal_approx(p1[0], 1.0), "a way run past at its end is not pressed half as hard there alone: %s" % [p1])
	_ok(twice.size() == 1 and ((twice[0] as Dictionary)["pts"] as PackedVector2Array).size() == 4, "a way still run past at its lightest is not cut there: %s" % [twice])
	var none: Array = TablePaint._ease_off([way], PackedVector2Array(), 2.0)
	_ok(none.size() == 1 and (none[0] as Dictionary)["press"] == way["press"], "THE CONTROL: run past nowhere, a way is changed")
	# ...A BLEND'S SOFTNESS by how far a fill's middle is from its edge
	var thin := Skins.cover({"kind": "fill", "d": "M 10 20 Q 30 10 50 20 Q 30 28 10 20 Z", "rule": "nonzero"}, Rect2(0, 0, 60, 40), Skins.WHEN_PX, "", Vector2(150, 210))
	var wide := Skins.cover({"kind": "fill", "d": "M 10 10 L 50 10 L 50 40 L 10 40 Z", "rule": "nonzero"}, Rect2(0, 0, 60, 50), Skins.WHEN_PX, "", Vector2(150, 210))
	var soft_thin := minf(Skins.BLEND_SOFT, Skins.inner_reach(thin) * Skins.BLEND_SHARE)
	var soft_wide := minf(Skins.BLEND_SOFT, Skins.inner_reach(wide) * Skins.BLEND_SHARE)
	_ok(soft_thin <= 1.5 and is_equal_approx(soft_wide, Skins.BLEND_SOFT), "a lip-thin fill is blended %.1f mm soft, a wide one %.1f" % [soft_thin, soft_wide])
	# ...AND A FLAT BRUSH FILLING A DIAMOND ON A MASK
	var m := _medium()
	var spec := station()
	_stand(m, spec, "mask", Vector3(Tables.ORIGIN.x, 0.0, Tables.ORIGIN.y) + Vector3(0, 0, -0.06))
	_stand(m, spec, "flat jar", Vector3(Tables.ORIGIN.x, 0.0, Tables.ORIGIN.y) + Vector3(0.18, 0, 0.06))
	_stand(m, spec, "black pot", Vector3(Tables.ORIGIN.x, 0.0, Tables.ORIGIN.y) + Vector3(0.09, 0, 0.12))
	m._work.skin_doc = {"designs": [{"thing": "mask", "part": "face", "name": "a gem", "elements": [
		{"id": "gem", "stage": "fill", "paint": "#3a5164", "fill": "M 48 66 L 64 95 L 48 130 L 32 95 Z"}]}]}
	m._work.build({"acts": [{"name": "fill", "beat": 1, "length": "under", "tracks": [{"thing": "flat jar", "part": "flat", "law": "paint", "on": "mask", "paint": ["gem"], "from": "black pot"}]}]}, 1)
	var tp: TablePaint = m._work.paint
	_ok(tp != null and (m._work.acts as Array).size() == 1, "the flat brush's act was not kept: %s" % "; ".join(m._work.notes))
	if tp == null or (m._work.acts as Array).size() < 1:
		return true
	var item: Dictionary = (tp.skins[0]["items"] as Dictionary).get("gem", {})
	_ok(not item.is_empty() and (item["made"] as Dictionary).has("foot"), "the flat brush's fill is not laid where its hairs touched")
	if item.is_empty() or not (item["made"] as Dictionary).has("foot"):
		return true
	var made: Dictionary = item["made"]
	var past := _past_shape(tp, "gem", made["foot"], made["rect"])
	var spilt: PackedInt32Array = made.get("spill", PackedInt32Array())
	print("  a flat brush filling a diamond: %.1f mm2 past it, %.1f of %.0f bare; ran past at each look %s" % [past.x, past.y, past.z, spilt])
	_ok(past.x <= 8.0 and past.y <= past.z * 0.03, "the flat brush's fill lays %.1f mm2 past the diamond and leaves %.1f of %.0f bare" % [past.x, past.y, past.z])
	_ok(spilt.size() >= 2 and spilt[0] > 0 and spilt[spilt.size() - 1] == 0, "the flat brush did not ease off where it ran past at the first look and nowhere at the last: %s" % [spilt])
	# THE CONTROL: its rows as they were, over the whole shape and past it
	var ch := ""
	for a in m._work.acts:
		for tr in (a as Dictionary)["tracks"]:
			ch = String((tr as Dictionary).get("_ch", ""))
	var track := _track_of(m, "fill")
	var tool: Dictionary = tp.tool_of(ch, track)
	var ed := tp.element(0, "gem")
	var gem_rect: Rect2 = made["rect"]
	var cov1 := Skins.cover(ed, gem_rect, Skins.WHEN_PX, String(tp.skins[0].get("outline", "")), tp.skins[0]["frame"])
	var mm := float(((tp._layers as Dictionary).get("0|gem", {}) as Dictionary).get("mm", 10.0))
	var rows: Array = []
	for st in Skins._rows(cov1, gem_rect, mm * Skins.ROWS):
		var pts := Skins._resampled(st, Skins.ROW_KEYS)
		var pr := PackedFloat32Array()
		pr.resize(pts.size())
		pr.fill(1.0)
		rows.append({"pts": pts, "press": pr})
	var was := Skins.program(ed, "sweep", mm, cov1, gem_rect, {}, rows)
	was["id"] = "the rows as they were"
	var contact := TablePaint._contact_for(tool, "sweep")
	(tp.skins[0]["held"] as Dictionary)[TablePaint._held_key(was, ch, contact)] = tp._held_keys(0, was, tool, contact)
	var foot_was: Array = []
	Skins.touch_map(tp._stroke_touches(0, was, track, tool, "sweep"), gem_rect, TablePaint.BRUSH_PX, TablePaint.BRUSH_SPOT, PackedByteArray(), 0.0, foot_was)
	var past_was := _past_shape(tp, "gem", foot_was[0], gem_rect)
	_ok(past_was.x > 30.0, "THE CONTROL: its rows as they were lay only %.1f mm2 past the diamond" % past_was.x)
	# ...AND BACK AND FORTH ALONG ITS ROWS IT NEVER ROLLS OVER (feedback 0016: "This brush is flipping and twirling and twisting and
	# repositioning ... They wouldn't just flip-flop back and forth"): rows drawn at 0, 170, 5 and 175 degrees, its broadside turned no more
	# than a quarter from one row to the next. THE CONTROL: each row's own way, as it comes, rolls it over half a turn
	var rows_keys := []
	for ri in 4:
		var ang := deg_to_rad([0.0, 170.0, 5.0, 175.0][ri])
		var row_mid := Vector2(48.0, 88.0 + float(ri) * 4.0)
		var a0 := row_mid - Vector2.from_angle(ang) * 8.0
		var t0 := float(ri) * 3.0
		rows_keys.append([t0, a0.x, a0.y, 2.0, 0.0, 0])
		for j in 17:
			var q := a0 + Vector2.from_angle(ang) * float(j)
			rows_keys.append([t0 + 0.2 + float(j) * 0.08, q.x, q.y, 0.0, 1.0, 0])
		var a1 := a0 + Vector2.from_angle(ang) * 16.0
		rows_keys.append([t0 + 1.8, a1.x, a1.y, 2.0, 0.0, 0])
	var rdirs := TablePaint._dirs_of(rows_keys)
	var flat_contact := TablePaint._contact_for(tool, "sweep")
	var across_at := func(ki: int, d: Vector2) -> Vector3:
		var kk: Array = rows_keys[ki]
		var hh: Array = tp._skin_hold(0, Vector2(float(kk[1]), float(kk[2])), 0.0, 1.0, 0.0, tool, flat_contact, Vector4.ZERO, Vector4.ZERO, 0.0, d)
		return (tp._node_at(hh, tool, tool["x0"]).basis * (tool["across"] as Vector3)).normalized()
	var rolled_most := 0.0
	var rolled_was := 0.0
	for ri in range(1, 4):
		var k_prev := (ri - 1) * 19 + 9
		var k_now := ri * 19 + 9
		rolled_most = maxf(rolled_most, rad_to_deg(across_at.call(k_prev, rdirs[k_prev]).angle_to(across_at.call(k_now, rdirs[k_now]))))
		var own := func(kx: int) -> Vector2:
			return (Vector2(float(rows_keys[kx + 1][1]), float(rows_keys[kx + 1][2])) - Vector2(float(rows_keys[kx][1]), float(rows_keys[kx][2]))).normalized()
		rolled_was = maxf(rolled_was, rad_to_deg(across_at.call(k_prev, own.call(k_prev)).angle_to(across_at.call(k_now, own.call(k_now)))))
	print("  back and forth along its rows the flat brush rolls %.0f degrees at most from one to the next (each row's own way: %.0f)" % [rolled_most, rolled_was])
	_ok(tool.has("across") and rolled_most <= 90.0, "back and forth along its rows the flat brush rolls %.0f degrees from one to the next" % rolled_most)
	_ok(rolled_was >= 150.0, "THE CONTROL: by each row's own way it rolled only %.0f degrees" % rolled_was)
	# ...AND TO ITS PAINT AND BACK IT STAYS ROLLED AS IT WAS ([method TablePaint._way_from]): from a stroke drawn each of eight ways, at the
	# middle of its load its broadside is turned about its handle no more than 30 degrees from where it lay on the stroke, carried with the
	# handle as the hand tilts it there (a half turn counts whole) - THE CONTROL: the stroke's way dropped at the pot, its untouched roll
	# there, it turns further
	# (...the pot's hold found from where it comes, as it is played: a brush laid on its paint is leaned across its broadside as it comes
	# rolled - [method TablePaint._laid_hold])
	var kept_most := 0.0
	var dropped_most := 0.0
	var node_of := func(h: Variant) -> Transform3D:
		return h if h is Transform3D else tp._node_at(h as Array, tool, tool["x0"])
	var twist := func(xa: Transform3D, xb: Transform3D) -> float:
		var hand := (tool["grip"] as Vector3) - (tool["tip"] as Vector3)
		var carried := Basis(Quaternion((xa.basis * hand).normalized(), (xb.basis * hand).normalized())) * (xa.basis * (tool["across"] as Vector3)).normalized()
		return rad_to_deg(carried.angle_to((xb.basis * (tool["across"] as Vector3)).normalized()))
	for wk in 8:
		var near_h: Array = tp._skin_hold(0, Vector2(48.0, 95.0), 0.0, 1.0, 0.0, tool, flat_contact, Vector4.ZERO, Vector4.ZERO, 0.0, Vector2.from_angle(TAU * float(wk) / 8.0))
		var on_stroke: Transform3D = node_of.call(near_h)
		var dropped_h := near_h.slice(0, 8)
		kept_most = maxf(kept_most, twist.call(on_stroke, node_of.call(tp._trip(near_h, tp._pot_hold("load", "black pot", "", 0.0, track, "", near_h), 0.6, 0, "load", tool))))
		dropped_most = maxf(dropped_most, twist.call(on_stroke, node_of.call(tp._trip(dropped_h, tp._pot_hold("load", "black pot", "", 0.0, track, "", dropped_h), 0.6, 0, "load", tool))))
	print("  at the middle of its load the flat brush's broadside is turned %.0f degrees at most from its stroke's (the way dropped: %.0f)" % [kept_most, dropped_most])
	_ok(tool.has("across") and kept_most <= 30.0, "at the middle of its load the flat brush's broadside is turned %.0f degrees from its stroke's" % kept_most)
	_ok(dropped_most > kept_most + 20.0, "THE CONTROL: the way dropped at the pot, it turned only %.0f degrees" % dropped_most)
	m._root3.free()
	# A FILL TOO FINE FOR ITS BRUSH IS DRAWN ALONG ITS MIDDLE (feedback 0055: "it touched the area once, and the entire brow just appeared"):
	# a brow's crescent under a 6 mm brush followed along its length in pulls at a line's pace, pressed hardest where it is thickest -
	# THE CONTROL: the rows it had, one or two across it
	var frame := Vector2(150, 210)
	var brow := Skins.sanitize({"elements": [{"id": "brow", "paint": "#2b1313", "fill": "M 17 77 C 25 66 35 59 44 60 C 53 61 60 66 67 72 C 59 67 52 63.5 44 63 C 35 62.5 26 68 17 77 Z"}]}, frame)
	var be: Dictionary = (brow["elements"] as Array)[0]
	var brect := Skins.rect_of(be, frame, 2.0)
	var bcov := Skins.cover(be, brect, Skins.WHEN_PX, "", frame)
	var bprog := Skins.program(be, "sweep", 6.0, bcov, brect, {}, null, frame)
	var bstrokes: Array = bprog["strokes"]
	var lightest := 1.0
	var heaviest := 0.0
	for st in bstrokes:
		for pr in (st as Dictionary).get("press", PackedFloat32Array()):
			lightest = minf(lightest, pr)
			heaviest = maxf(heaviest, pr)
	_ok(bstrokes.size() >= 3 and float(bprog["natural"]) > 50.0 / Skins.LINE_SPEED * 0.8 and heaviest > lightest * 1.5,
		"a brow too fine for its brush is drawn along it in %d pulls over %.1f s, pressed %.2f to %.2f" % [bstrokes.size(), float(bprog["natural"]), lightest, heaviest])
	_ok(Skins._eroded(bcov, 6.0 * 0.5 * Skins.CUT_IN) == null, "THE CONTROL: nothing of it is half the brush inside its edge, where a row keeps")
	# A BRUSH IS PULLED THROUGH EVERY STROKE (feedback 0054, 0056: "the brush is PUSHING against the natural direction of the stroke"): a fill
	# on the face's right half, every row and every piece of its edge drawn the way the hand leans the brush there - THE CONTROL: with no
	# frame to lean by, its rows go back and forth
	var rim := Skins.sanitize({"elements": [{"id": "rim", "paint": "#a95c2e", "fill": "M 84 90 A 21 14 0 1 0 126 90 A 21 14 0 1 0 84 90 Z"}]}, frame)
	var re: Dictionary = (rim["elements"] as Array)[0]
	var rrect := Skins.rect_of(re, frame, 2.0)
	var rcov := Skins.cover(re, rrect, Skins.WHEN_PX, "", frame)
	var against := func(prog: Dictionary, by_frame: bool) -> Vector2i:
		var pushed_n := 0
		var all := 0
		for st in prog["strokes"]:
			var pts: PackedVector2Array = (st as Dictionary)["pts"]
			if pts.size() < 2 or pts[0].distance_to(pts[pts.size() - 1]) < Skins.PULL_PIECE_LEAST:
				continue
			all += 1
			pushed_n += int((pts[pts.size() - 1] - pts[0]).dot(Skins.pull_toward(pts[pts.size() / 2], frame)) < -0.5 * pts[0].distance_to(pts[pts.size() - 1]))
		return Vector2i(pushed_n, all)
	var pulled: Vector2i = against.call(Skins.program(re, "sweep", 6.0, rcov, rrect, {}, null, frame), true)
	var pushed: Vector2i = against.call(Skins.program(re, "sweep", 6.0, rcov, rrect), false)
	_ok(pulled.y >= 4 and pulled.x == 0, "every stroke of a fill is pulled the way the brush leans: %d of %d pushed" % [pulled.x, pulled.y])
	_ok(pushed.x >= 2, "THE CONTROL: with no frame to lean by, %d of its %d strokes are pushed" % [pushed.x, pushed.y])
	# A LINE IS THE BAND ITS HAIRS SWEEP (2026-11-07: "nearly all straight lines are 'splotchy' ... But a proper brush stroke is more often
	# than not very smooth, with clean edges... which might fade near the tail"): a stroke's band whole along it and clean at its edge,
	# thinner and narrower over its tail - THE CONTROL: its body, which does not fade
	var band_prog := {"natural": 5.0, "strokes": [{"pts": PackedVector2Array([Vector2(10, 10), Vector2(50, 10)]), "t": PackedFloat32Array([0.0, 5.0]), "r": 1.0,
		"load": PackedFloat32Array([1.0, 1.0])}]}
	var band_foot: Array = []
	var band_when := Skins.band_map(band_prog, Rect2(0, 0, 60, 20), 4.0, band_foot)
	var bf: Image = band_foot[0]
	var body_least := 1.0
	for x in range(int(12 * 4), int(38 * 4)):
		body_least = minf(body_least, bf.get_pixel(x, 40).r)
	var edge_soft := 0
	for y in range(0, 80):
		var v := bf.get_pixel(int(25 * 4), y).r
		edge_soft += int(v > 0.05 and v < 0.95)
	var tail_v := bf.get_pixel(int(49.5 * 4), 40).r
	var tail_w := 0
	var body_w := 0
	for y in range(0, 80):
		tail_w += int(bf.get_pixel(int(49 * 4), y).r > 0.05)
		body_w += int(bf.get_pixel(int(25 * 4), y).r > 0.05)
	_ok(body_least > 0.97 and edge_soft <= 2 and band_when.get_pixel(int(25 * 4), 40).r < 0.6,
		"a line's band is whole along its body (%.2f at the least) and clean at its edge (%d pixels between)" % [body_least, edge_soft])
	_ok(tail_v < 0.75 and tail_w < body_w, "and thins over its tail (%.2f, %d pixels wide of %d)" % [tail_v, tail_w, body_w])
	_ok(bf.get_pixel(int(30 * 4), 40).r > 0.97, "THE CONTROL: its body does not thin")
	# A DESIGN'S COLORS ARE THE TABLE'S PAINTS (the user's choice of 0057, 0059: "Pot paint, thinned"): a lighter plum from the plum pot is
	# laid thinner, one as dark as its pot whole - THE CONTROL: the same color as its pot, whole
	var plum := Color.html("#4b2a3c")
	var lighter := TablePaint._thickness(Color.html("#8b3f63"), plum)
	var darker := TablePaint._thickness(Color.html("#2b1313"), plum)
	_ok(lighter > TablePaint.THIN_LEAST and lighter < 0.9 and darker == 1.0, "a lighter plum from the plum pot is laid %.2f thick, a darker one whole" % lighter)
	_ok(TablePaint._thickness(plum, plum) == 1.0, "THE CONTROL: its own color, whole")
	return true


## How much of [param foot] (a brush's paint over [param rect], [method Skins.touch_map]'s `foot_out`) lies over half a millimeter past
## element [param id]'s shape, how much of its shape it leaves bare, and how large that shape is - square millimeters.
static func _past_shape(tp: TablePaint, id: String, foot: Image, rect: Rect2) -> Vector3:
	var fpx := float(foot.get_width()) / maxf(rect.size.x, 1.0)
	var cov := Skins.cover(tp.element(0, id), rect, fpx, String(tp.skins[0].get("outline", "")), tp.skins[0]["frame"])
	var inside := TablePaint.covered_in(cov)
	var w := cov.get_width()
	var h := cov.get_height()
	var r := ceili(0.5 * fpx)
	var past := 0
	var bare := 0
	var shape := 0
	for y in mini(h, foot.get_height()):
		for x in mini(w, foot.get_width()):
			var on := foot.get_pixel(x, y).r >= 0.5
			if inside[y * w + x] == 1:
				shape += 1
				bare += int(not on)
				continue
			if not on:
				continue
			var near := false
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					var qx := x + dx
					var qy := y + dy
					if qx >= 0 and qy >= 0 and qx < w and qy < h and inside[qy * w + qx] == 1:
						near = true
			past += int(not near)
	return Vector3(float(past), float(bare), float(shape)) / (fpx * fpx)

## ONE COAT OF A PAINT (the user, 2026-11-07: "why are we making two passes of white at all? ... There ought to be one application of white,
## no more"): two coats of one paint over the whole face are one, as thick as both, and the act whose coat it was takes nothing up; the one
## coat's sponge cleaned and put down - THE CONTROLS: a line in a paint of its own kept, and the liner's act after them worked and cleaned.
## A POWDER IS A PAINT OF ITS OWN (257002's setting powder, given the nearest cream's color, was folded into the white base and patted
## nothing): patted on from its pot over the whole face, it keeps its layer, in its pot's powder, and its act pats - THE CONTROL: taken as
## a cream, the nearest cream to its color is the white the base is laid in.
## AN ACT LEFT NOTHING TO DO IS NO ACT (feedback 0002, the clean sponge dunked again): the sponge's next act after the folded coat, in a
## thinned paint, begins damp from the white's rinse and takes it straight up - THE CONTROL: told nothing of being damp, it is wetted first.
func _coats() -> bool:
	var m := _medium()
	var spec := station()
	# (...the powder pot with its powder in it - the station's has none, and the puff checks above dip into it bare)
	for th in spec["things"]:
		if String((th as Dictionary)["name"]) == "powder pot":
			((th as Dictionary)["parts"] as Array).insert(1, {"shape": "lathe", "profile": [[0, 0.3], [3.3, 0.3], [3.3, 2.6], [0, 2.7]], "material": "setting powder"})
	(spec["materials"] as Dictionary)["setting powder"] = {"kind": "powder", "color": "#f4efe8"}
	var at := {"mask": Vector3(0, 0, -0.06), "brush jar": Vector3(0.18, 0, 0.04), "sponge": Vector3(-0.16, 0, 0.08), "white pot": Vector3(-0.09, 0, 0.12),
		"black pot": Vector3(0.09, 0, 0.12), "water cup": Vector3(0.22, 0, -0.06), "towel": Vector3(-0.24, 0, -0.08), "powder pot": Vector3(-0.3, 0, 0.14)}
	for nm in at:
		_stand(m, spec, nm, Vector3(Tables.ORIGIN.x, 0.0, Tables.ORIGIN.y) + (at[nm] as Vector3))
	m._work.skin_doc = {"designs": [{"thing": "mask", "part": "face", "name": "coats", "elements": [
		{"id": "coat one", "stage": "base", "paint": "#d5b9a1", "fill": "all", "opacity": 0.85},
		{"id": "coat two", "stage": "base", "paint": "#efe3d6", "fill": "all", "opacity": 0.9},
		{"id": "strip", "stage": "base", "paint": "#9a9a9a", "fill": "M 20 60 H 130 V 70 H 20 Z"},
		{"id": "set", "stage": "base", "paint": "#f0dece", "fill": "all", "finish": "powder", "opacity": 0.22},
		{"id": "brow", "stage": "lines", "paint": "#121214", "line": "M 30 72 C 40 58 58 55 66 62", "width": 1.4}]}]}
	var sponge_track := func(id: String) -> Dictionary:
		return {"thing": "sponge", "part": "wedge", "law": "paint", "on": "mask", "paint": [id], "manner": "stipple", "from": "white pot",
			"rinse": "water cup", "dry": "towel"}
	m._work.build({"acts": [
		{"name": "one", "beat": 1, "length": "under", "tracks": [sponge_track.call("coat one")]},
		{"name": "two", "beat": 2, "length": "under", "tracks": [sponge_track.call("coat two")]},
		{"name": "shade", "beat": 3, "length": "under", "tracks": [{"thing": "sponge", "part": "wedge", "law": "paint", "on": "mask", "paint": ["strip"],
			"manner": "stipple", "from": "black pot", "rinse": "water cup", "dry": "towel"}]},
		{"name": "powder", "beat": 4, "length": "under", "tracks": [{"thing": "powder pot", "part": "puff", "law": "paint", "on": "mask", "paint": ["set"],
			"manner": "pat", "from": "powder pot"}]},
		{"name": "lines", "beat": 5, "length": "under", "tracks": [{"thing": "brush jar", "part": "liner", "law": "paint", "on": "mask", "paint": ["brow"],
			"from": "black pot", "rinse": "water cup", "dry": "towel"}]}]}, 5)
	var tp: TablePaint = m._work.paint
	_ok(tp != null and (m._work.acts as Array).size() == 5, "the coats' acts were kept: %s" % "; ".join(m._work.notes))
	if tp == null or (m._work.acts as Array).size() < 5:
		m._root3.free()
		return true
	# (...one coat, as thick as the two designed come to together - 0.85 and 0.9 - the second taken out of the design)
	var one := tp.element(0, "coat one")
	_ok(not one.is_empty() and tp.element(0, "coat two").is_empty() and not tp._layers.has("0|coat two")
		and absf(float(one.get("opacity", 0.0)) * float((tp._layers.get("0|coat one", {}) as Dictionary).get("thick", 1.0)) - (1.0 - 0.15 * 0.1)) < 0.01,
		"two coats of one paint over the whole face are one, as thick as both: %.3f" % float(one.get("opacity", 0.0)))
	_ok(not tp.element(0, "brow").is_empty() and tp._layers.has("0|brow"), "THE CONTROL: a line in a paint of its own is kept")
	var kinds_of := func(act: String) -> Array:
		return (tp.plan_of(_track_of(m, act), 120.0)["phases"] as Array).map(func(p: Dictionary) -> String: return String(p["kind"]))
	var k1: Array = kinds_of.call("one")
	var k2: Array = kinds_of.call("two")
	var k3: Array = kinds_of.call("lines")
	var before_el := func(kinds: Array) -> Array: return kinds.slice(0, maxi(kinds.find("el"), 0))
	var after_el := func(kinds: Array) -> Array: return kinds.slice(kinds.rfind("el") + 1)
	_ok(k2.is_empty() and (after_el.call(k1) as Array).has("rinse") and (after_el.call(k1) as Array).back() == "back",
		"the act whose coat is the one before's takes nothing up, and the one coat's sponge is cleaned and put down: %s / %s" % [k1, k2])
	_ok((after_el.call(k3) as Array).has("rinse") and (after_el.call(k3) as Array).has("dry") and not k3.is_empty(),
		"THE CONTROL: the liner's act after them is worked and cleaned: %s" % [k3])
	var set_lay: Dictionary = tp._layers.get("0|set", {})
	var kp: Array = kinds_of.call("powder")
	_ok(not tp.element(0, "set").is_empty() and String(set_lay.get("pot", "")) == "#f4efe8" and kp.has("el"),
		"a powder patted on from its pot keeps its layer in its powder (%s) and its act pats: %s" % [set_lay.get("pot", "none"), kp])
	var as_cream := tp._cream_near("#f0dece", 0)
	_ok(not as_cream.is_empty() and "#" + Color(as_cream["color"]).to_html(false) == String((tp._layers.get("0|coat one", {}) as Dictionary).get("pot", "")),
		"THE CONTROL: taken as a cream, the powder's nearest is not the white the base is laid in: %s" % [as_cream.get("color", "none")])
	# ...AN ACT LEFT NOTHING TO DO IS NO ACT: the sponge's next after the folded coat begins damp, its thinned paint taken straight up
	var shade_t := _track_of(m, "shade")
	var ks: Array = kinds_of.call("shade")
	_ok(bool(shade_t.get("_damp", false)) and ks.has("el") and not (before_el.call(ks) as Array).has("rinse"),
		"the sponge's act after the folded coat begins damp from the white's rinse and takes its thinned paint straight up: %s" % [ks])
	var dry_t := shade_t.duplicate()
	dry_t.erase("_damp")
	var kd: Array = (tp.plan_of(dry_t, 120.0)["phases"] as Array).map(func(p: Dictionary) -> String: return String(p["kind"]))
	_ok((before_el.call(kd) as Array).has("rinse"), "THE CONTROL: told nothing of being damp, its thinned paint was taken up on a sponge not wetted first: %s" % [kd])
	m._root3.free()
	return true


## A TOOL KEPT IN HAND IS PUT BACK WHERE IT WAS TAKEN FROM (feedback 0004, 2026-11-09: "Why is there a brush floating near the eye, while we
## are simultaneously using a second brush ...?"; TablePaint._home_of): a liner drawing a brow and, straight after in the same black, a lid
## is kept in hand between them, and the second act puts it back in its jar - where it is while the sponge lays the base. THE CONTROL: put
## back where that second act found it, it is left in the air off its jar.
## EACH WAY AS LONG AS ITS LENGTH NEEDS ([method TablePaint._paced]; 2026-11-10, the user: "the brush is leaving paint streaks in places
## that are far away from where it's actually touching now"): a liner laying a brow, then a chin across the nose, then rinsed and dried -
## its body, as its plan carries it frame by frame, never moved faster in a move between elements or a trip than RigidParts carries a held
## thing (about 0.58 m/s; WAY_FRAME_MOST a frame at 30 frames a second). THE CONTROL: each move and trip its hand's fixed time, as it was -
## the move over the nose and the rinse faster than that.
const WAY_FRAME_MOST := 0.022


func _paced_ways_once(paced: bool) -> float:
	var m := _medium()
	var spec := station()
	var at := {"mask": Vector3(0, 0, -0.06), "brush jar": Vector3(0.18, 0, 0.04), "sponge": Vector3(-0.16, 0, 0.08), "white pot": Vector3(-0.09, 0, 0.12),
		"black pot": Vector3(0.09, 0, 0.12), "water cup": Vector3(0.22, 0, -0.06), "towel": Vector3(-0.24, 0, -0.08)}
	for nm in at:
		_stand(m, spec, nm, Vector3(Tables.ORIGIN.x, 0.0, Tables.ORIGIN.y) + (at[nm] as Vector3))
	# (...paced or not before anything is planned: an act's plan is made as it is prepared)
	if m._work.paint != null:
		m._work.paint.paced = paced
	var doc := design()
	(((doc["designs"] as Array)[0] as Dictionary)["elements"] as Array).append({"id": "chin", "stage": "lines", "paint": "#121214",
		"line": "M 60 190 C 70 196 84 196 92 190", "width": 1.4})
	m._work.skin_doc = doc
	m._work.build({"acts": [{"name": "both", "beat": 1, "length": "under", "tracks": [{"thing": "brush jar", "part": "liner", "law": "paint",
		"on": "mask", "paint": ["brow", "chin"], "from": "black pot", "rinse": "water cup", "dry": "towel"}]}]}, 1)
	var action := {"kind": "work", "card": 1, "after": 0, "dur": 0.0}
	m._work.schedule([{"a": action, "t0": 2.0, "s": 1.0}], {"actions": [action], "spoken": PackedStringArray(["one", "two"]), "cues": [{"name": "both", "si": 0}]},
		PackedFloat32Array([2.0, 60.0]), PackedFloat32Array([2.5, 60.5]), PackedFloat32Array(), 0.0)
	var node: Node3D = null
	for wk in m._work.works:
		if String((wk as Dictionary)["name"]) == "liner":
			node = (wk as Dictionary)["node"]
	var run: Dictionary = (m._work.runs as Array)[0]
	var tp: TablePaint = m._work.paint
	var trk := _track_of(m, "both")
	var pl: Dictionary = tp.plan_of(trk, float(run["t1"]) - float(run["t0"]))
	var windows: Array = []
	for ph in pl["phases"]:
		var pd: Dictionary = ph
		windows.append([String(pd["kind"]), String(pd.get("el", "")), float(run["t0"]) + float(pd["a"]), float(run["t0"]) + float(pd["b"]), 0.0])
	m._work._planned = true
	var last := Vector3.INF
	var worst := 0.0
	var at_t := 0.0
	var jumps := 0
	var t := float(run["t0"])
	while t < float(run["t1"]):
		m._work.tick(t)
		var p := m._work._world_of(node).origin
		if last != Vector3.INF:
			var j := p.distance_to(last)
			if j > 0.02:
				jumps += 1
			for wnd in windows:
				if t >= float(wnd[2]) and t < float(wnd[3]):
					wnd[4] = maxf(float(wnd[4]), j)
			if j > worst:
				worst = j
				at_t = t
		last = p
		t += 1.0 / 30.0
	var ways := 0.0
	var said := PackedStringArray()
	for wnd in windows:
		if String(wnd[0]) in ["move", "rinse", "dry", "load"]:
			ways = maxf(ways, float(wnd[4]))
			said.append("%s %.1f" % [wnd[0], float(wnd[4]) * 100.0])
	m._root3.free()
	return ways


## EACH WAY INSIDE AN ELEMENT AS LONG AS ITS BODY NEEDS ([method TablePaint._pace_keys]; feedback 0010, 2026-11-10: "black mark on the chin
## ... brush not even touching"): the same liner's chin, drawn out from its middle, ends one stroke leaning left and begins the next leaning
## right; baked by the solver, through every element its body keeps within KEY_OFF_MOST of where its hand has it. THE CONTROL: each way at
## its program's own time, its handle swung 100 degrees in 0.41 s - its body falls centimeters behind, and its paint is laid where it is not.
const KEY_OFF_MOST := 0.003


func _paced_keys_once(paced: bool) -> float:
	var m := _medium()
	var spec := station()
	var at := {"mask": Vector3(0, 0, -0.06), "brush jar": Vector3(0.18, 0, 0.04), "sponge": Vector3(-0.16, 0, 0.08), "white pot": Vector3(-0.09, 0, 0.12),
		"black pot": Vector3(0.09, 0, 0.12), "water cup": Vector3(0.22, 0, -0.06), "towel": Vector3(-0.24, 0, -0.08)}
	for nm in at:
		_stand(m, spec, nm, Vector3(Tables.ORIGIN.x, 0.0, Tables.ORIGIN.y) + (at[nm] as Vector3))
	if m._work.paint != null:
		m._work.paint.paced = paced
	var doc := design()
	(((doc["designs"] as Array)[0] as Dictionary)["elements"] as Array).append({"id": "chin", "stage": "lines", "paint": "#121214",
		"line": "M 60 190 C 70 196 84 196 92 190", "width": 1.4})
	m._work.skin_doc = doc
	m._work.build({"acts": [{"name": "both", "beat": 1, "length": "under", "tracks": [{"thing": "brush jar", "part": "liner", "law": "paint",
		"on": "mask", "paint": ["brow", "chin"], "from": "black pot", "rinse": "water cup", "dry": "towel"}]}]}, 1)
	# (...in as long as the act takes at a hand's pace, never slowed to fill more: slowed, the control's swing had time enough)
	var nat := 0.0
	for a in m._work.acts:
		if String((a as Dictionary)["name"]) == "both":
			nat = float((a as Dictionary).get("_natural", 0.0))
	var action := {"kind": "work", "card": 1, "after": 0, "dur": 0.0}
	m._work.schedule([{"a": action, "t0": 2.0, "s": 1.0}], {"actions": [action], "spoken": PackedStringArray(["one", "two"]), "cues": [{"name": "both", "si": 0}]},
		PackedFloat32Array([2.0, 1.5 + nat]), PackedFloat32Array([2.5, 2.0 + nat]), PackedFloat32Array(), 0.0)
	var wi := -1
	for k in (m._work.works as Array).size():
		if String((m._work.works[k] as Dictionary)["name"]) == "liner":
			wi = k
	var run: Dictionary = (m._work.runs as Array)[0]
	var tp: TablePaint = m._work.paint
	var pl: Dictionary = tp.plan_of(_track_of(m, "both"), float(run["t1"]) - float(run["t0"]))
	var phys: TablePhysics = m._work.physics
	_ok(phys != null and phys._rigid_of.has(wi), "the liner is no body the solver carries")
	if phys == null or not phys._rigid_of.has(wi):
		m._root3.free()
		return INF
	var bi := int(phys._rigid_of[wi])
	var worst := 0.0
	var els := 0
	for ph in pl["phases"]:
		var pd: Dictionary = ph
		if String(pd["kind"]) != "el":
			continue
		els += 1
		var a := float(run["t0"]) + float(pd["a"])
		var b := float(run["t0"]) + float(pd["b"])
		phys.bake_until(b)
		var t := a
		while t < b:
			var fr: Variant = phys.frame_at(t)
			if fr != null:
				worst = maxf(worst, phys.held_off(fr, bi))
			t += 1.0 / 30.0
	_ok(els == 2, "the liner's act laid %d elements, not the brow and the chin" % els)
	_ok(absf(float(run["t1"]) - float(run["t0"]) - nat) < 0.6, "the liner's act ran %.1f s, not its own %.1f" % [float(run["t1"]) - float(run["t0"]), nat])
	m._root3.free()
	return worst


func _paced_keys() -> bool:
	var paced: float = _paced_keys_once(true)
	var fixed: float = _paced_keys_once(false)
	_ok(paced <= KEY_OFF_MOST, "a liner's ways inside its elements, each as long as its body needs, leave it %.1f mm off its hand (%.1f the most)" % [paced * 1000.0, KEY_OFF_MOST * 1000.0])
	_ok(fixed > KEY_OFF_MOST * 5.0, "THE CONTROL: each way at its program's own time, its body is only %.1f mm off its hand" % (fixed * 1000.0))
	return true


## PICK A LANE (2026-11-10, the user: "when the brushes go into the water, the bristles bend - even though the brush isn't touching the
## bottom of the glass ... either touch the actual bottom, so that the curves make sense, or don't touch it, and don't curve the bristles
## in the water"; TablePaint._lay_on_plane): a liner squeezed on the water cup's floor is stopped by the table under the cup's floor short
## of its hand; through the squeeze, as the solver carries it, its hairs as drawn either reach the floor or stand straight - never bent
## more than HAIR_CURL_MOST with their tip HAIR_OFF_MOST over it. THE CONTROL: laid as its hand has it, their tip stands well up in the water.
const HAIR_CURL_MOST := 0.001
const HAIR_OFF_MOST := 0.0015


func _laid_as_drawn() -> bool:
	var m := _medium()
	var spec := station()
	var at := {"mask": Vector3(0, 0, -0.06), "brush jar": Vector3(0.18, 0, 0.04), "sponge": Vector3(-0.16, 0, 0.08), "white pot": Vector3(-0.09, 0, 0.12),
		"black pot": Vector3(0.09, 0, 0.12), "water cup": Vector3(0.22, 0, -0.06), "towel": Vector3(-0.24, 0, -0.08)}
	for nm in at:
		_stand(m, spec, nm, Vector3(Tables.ORIGIN.x, 0.0, Tables.ORIGIN.y) + (at[nm] as Vector3))
	m._work.skin_doc = design()
	m._work.build({"acts": [{"name": "brow", "beat": 1, "length": "under", "tracks": [{"thing": "brush jar", "part": "liner", "law": "paint",
		"on": "mask", "paint": ["brow"], "from": "black pot", "rinse": "water cup", "dry": "towel"}]}]}, 1)
	var nat := 0.0
	for a in m._work.acts:
		nat = float((a as Dictionary).get("_natural", 0.0))
	var action := {"kind": "work", "card": 1, "after": 0, "dur": 0.0}
	m._work.schedule([{"a": action, "t0": 2.0, "s": 1.0}], {"actions": [action], "spoken": PackedStringArray(["one", "two"]), "cues": [{"name": "brow", "si": 0}]},
		PackedFloat32Array([2.0, 1.5 + nat]), PackedFloat32Array([2.5, 2.0 + nat]), PackedFloat32Array(), 0.0)
	var wi := -1
	for k in (m._work.works as Array).size():
		if String((m._work.works[k] as Dictionary)["name"]) == "liner":
			wi = k
	var node: Node3D = (m._work.works[wi] as Dictionary)["node"]
	var run: Dictionary = (m._work.runs as Array)[0]
	var t0 := float(run["t0"])
	var tp: TablePaint = m._work.paint
	var trk := _track_of(m, "brow")
	var plan: Dictionary = tp.plan_of(trk, float(run["t1"]) - t0)
	var tool := tp._tool_or_none(trk)
	var mat: ShaderMaterial = ((tool["tufts"] as Array)[0] as Dictionary)["mat"]
	var rinse: Array = (plan["phases"] as Array).filter(func(p: Dictionary) -> bool: return String(p["kind"]) == "rinse")
	_ok(rinse.size() == 1 and m._work.physics != null, "the liner was not rinsed with a solver to carry it")
	if rinse.size() != 1 or m._work.physics == null:
		m._root3.free()
		return true
	var a := t0 + float((rinse[0] as Dictionary)["a"])
	var b := t0 + float((rinse[0] as Dictionary)["b"])
	m._work.physics.bake_until(b)
	var pressed := 0
	var curled := 0
	var worst := 0.0
	var control := 0.0
	var t := a
	while t < b:
		m._work.tick(t)
		var h: Array = tp._hold_of(tp._held_at(plan, trk, t - t0, t, Transform3D.IDENTITY, m._work._rest.get("w%d:pose" % wi, Transform3D.IDENTITY),
			Transform3D.IDENTITY), tool)
		if not bool(h[3]) and float(h[2]) > 0.0 and h.size() > 7 and not is_nan(float(h[6])):
			pressed += 1
			var xn := m._work._world_of(node)
			var bend: Vector3 = mat.get_shader_parameter("bristle_bend")
			var off := (xn * tp._bent_tip(tool, bend, mat.get_shader_parameter("bristle_lay") as Vector2)).y - float(h[6])
			if bend.length() > HAIR_CURL_MOST and off > HAIR_OFF_MOST:
				curled += 1
				worst = maxf(worst, off)
			var by_hand: Array = tp._lay_on_plane(tool, h, Vector3.ZERO)
			control = maxf(control, (xn * tp._bent_tip(tool, xn.basis.inverse() * (by_hand[0] as Vector3), by_hand[1] as Vector2)).y - float(h[6]))
		t += 1.0 / 30.0
	_ok(pressed > 10, "the liner was pressed on the cup's floor in %d frames of its rinse" % pressed)
	_ok(curled == 0, "the liner's hairs curl in the water in %d of %d frames pressed, their tip up to %.1f mm over the cup's floor" % [curled, pressed, worst * 1000.0])
	_ok(control > HAIR_OFF_MOST * 4.0, "THE CONTROL: laid as its hand has it, the hairs' tip stands only %.1f mm over the floor" % (control * 1000.0))
	m._root3.free()
	return true


## A BRUSH'S HAIRS TRAIL BEHIND THE WAY IT GOES (TablePaint._lay_on_plane's `goes`; 2026-11-10, the user: "the brush moves in small circles
## in those containers... yet the bristles only bend in a single direction ... On the grey pad, the bending looks great: because we only
## ever pull in one direction"): a liner swirled round the water cup's floor has its hairs, laid on it, pointing behind it (TRAIL_BEHIND_LEAST
## on average) and turning all the way round with it (TRAIL_BINS_LEAST of twelve ways); dried on the towel, they lie as they did. THE
## CONTROL: laid by the handle's lean alone, as they were, they point one way the whole swirl.
const TRAIL_BEHIND_LEAST := 0.7
const TRAIL_BINS_LEAST := 10


func _trailed() -> bool:
	var m := _medium()
	var spec := station()
	var at := {"mask": Vector3(0, 0, -0.06), "brush jar": Vector3(0.18, 0, 0.04), "sponge": Vector3(-0.16, 0, 0.08), "white pot": Vector3(-0.09, 0, 0.12),
		"black pot": Vector3(0.09, 0, 0.12), "water cup": Vector3(0.22, 0, -0.06), "towel": Vector3(-0.24, 0, -0.08)}
	for nm in at:
		_stand(m, spec, nm, Vector3(Tables.ORIGIN.x, 0.0, Tables.ORIGIN.y) + (at[nm] as Vector3))
	m._work.skin_doc = design()
	m._work.build({"acts": [{"name": "brow", "beat": 1, "length": "under", "tracks": [{"thing": "brush jar", "part": "liner", "law": "paint",
		"on": "mask", "paint": ["brow"], "from": "black pot", "rinse": "water cup", "dry": "towel"}]}]}, 1)
	var nat := 0.0
	for a in m._work.acts:
		nat = float((a as Dictionary).get("_natural", 0.0))
	var action := {"kind": "work", "card": 1, "after": 0, "dur": 0.0}
	m._work.schedule([{"a": action, "t0": 2.0, "s": 1.0}], {"actions": [action], "spoken": PackedStringArray(["one", "two"]), "cues": [{"name": "brow", "si": 0}]},
		PackedFloat32Array([2.0, 1.5 + nat]), PackedFloat32Array([2.5, 2.0 + nat]), PackedFloat32Array(), 0.0)
	var wi := -1
	for k in (m._work.works as Array).size():
		if String((m._work.works[k] as Dictionary)["name"]) == "liner":
			wi = k
	var node: Node3D = (m._work.works[wi] as Dictionary)["node"]
	var run: Dictionary = (m._work.runs as Array)[0]
	var t0 := float(run["t0"])
	var tp: TablePaint = m._work.paint
	var trk := _track_of(m, "brow")
	var plan: Dictionary = tp.plan_of(trk, float(run["t1"]) - t0)
	var tool := tp._tool_or_none(trk)
	var mat: ShaderMaterial = ((tool["tufts"] as Array)[0] as Dictionary)["mat"]
	m._work._planned = true
	var hold := func(tt: float) -> Array:
		return tp._hold_of(tp._held_at(plan, trk, tt - t0, tt, Transform3D.IDENTITY, m._work._rest.get("w%d:pose" % wi, Transform3D.IDENTITY),
			Transform3D.IDENTITY), tool)
	var flat := func(v: Vector3) -> Vector2: return Vector2(v.x, v.z).normalized() if Vector2(v.x, v.z).length() > 1e-9 else Vector2.ZERO
	var judged := {}
	for kind in ["rinse", "dry"]:
		var ph: Array = (plan["phases"] as Array).filter(func(p: Dictionary) -> bool: return String(p["kind"]) == kind)
		if ph.size() != 1:
			_ok(false, "the liner has no %s" % kind)
			continue
		var behind := 0.0
		var kept := 0.0
		var n := 0
		var bins := {}
		var bins_was := {}
		var t := t0 + float((ph[0] as Dictionary)["a"])
		while t < t0 + float((ph[0] as Dictionary)["b"]):
			var h: Array = hold.call(t)
			if not bool(h[3]) and float(h[2]) > 0.0 and h.size() > 7 and not is_nan(float(h[6])):
				var v := ((h[0] as Vector3) - ((hold.call(t - TablePaint.TRAIL_LAG) as Array)[0] as Vector3)) / TablePaint.TRAIL_LAG
				m._work.tick(t)
				var xn := m._work._world_of(node)
				var lay: Vector2 = mat.get_shader_parameter("bristle_lay")
				if lay.y > 0.0 and Vector2(v.x, v.z).length() > TablePaint.TRAIL_SPEED:
					var dir: Vector2 = flat.call(xn.basis * (mat.get_shader_parameter("bristle_bend") as Vector3))
					var was: Vector2 = flat.call(tp._lay_on_plane(tool, h, Vector3.ZERO, xn)[0] as Vector3)
					behind += dir.dot(-(flat.call(v) as Vector2))
					kept += dir.dot(was)
					n += 1
					bins[int(floor((dir.angle() + PI) / (TAU / 12.0))) % 12] = true
					bins_was[int(floor((was.angle() + PI) / (TAU / 12.0))) % 12] = true
			t += 1.0 / 30.0
		judged[kind] = [behind / maxf(n, 1), kept / maxf(n, 1), bins.size(), bins_was.size(), n]
	if judged.has("rinse") and judged.has("dry"):
		var r: Array = judged["rinse"]
		var d: Array = judged["dry"]
		_ok(int(r[4]) > 20 and float(r[0]) >= TRAIL_BEHIND_LEAST and int(r[2]) >= TRAIL_BINS_LEAST,
			"swirled round the cup's floor, the hairs point behind the brush %.2f on average and turn through %d of 12 ways (%d frames)" % [float(r[0]), int(r[2]), int(r[4])])
		_ok(int(d[4]) > 10 and float(d[1]) > 0.98, "dried on the towel, they lie as they did (%.3f the same way, %d frames)" % [float(d[1]), int(d[4])])
		_ok(int(r[3]) <= 2, "THE CONTROL: laid by the handle's lean alone, the swirl's hairs point %d of 12 ways" % int(r[3]))
	m._root3.free()
	return true


func _paced_ways() -> bool:
	var paced: float = _paced_ways_once(true)
	var fixed: float = _paced_ways_once(false)
	_ok(paced <= WAY_FRAME_MOST, "a liner's moves and trips, each as long as its way needs, move it at most %.1f cm a frame (%.1f the most)" % [paced * 100.0, WAY_FRAME_MOST * 100.0])
	_ok(fixed > WAY_FRAME_MOST * 1.3, "THE CONTROL: each its hand's fixed time, as it was, they move it %.1f cm a frame" % (fixed * 100.0))
	return true


func _put_back() -> bool:
	var m := _medium()
	var spec := station()
	var at := {"mask": Vector3(0, 0, -0.06), "brush jar": Vector3(0.18, 0, 0.04), "sponge": Vector3(-0.16, 0, 0.08), "white pot": Vector3(-0.09, 0, 0.12),
		"black pot": Vector3(0.09, 0, 0.12), "water cup": Vector3(0.22, 0, -0.06), "towel": Vector3(-0.24, 0, -0.08)}
	for nm in at:
		_stand(m, spec, nm, Vector3(Tables.ORIGIN.x, 0.0, Tables.ORIGIN.y) + (at[nm] as Vector3))
	var doc := design()
	(((doc["designs"] as Array)[0] as Dictionary)["elements"] as Array).append({"id": "lid", "stage": "lines", "paint": "#121214",
		"line": "M 84 72 C 94 64 108 64 116 70", "width": 1.4})
	m._work.skin_doc = doc
	var liner := func(nm: String) -> Dictionary:
		return {"name": nm, "beat": 1, "length": "under", "tracks": [{"thing": "brush jar", "part": "liner", "law": "paint", "on": "mask", "paint": [nm],
			"from": "black pot", "rinse": "water cup", "dry": "towel"}]}
	m._work.build({"acts": [liner.call("brow"), liner.call("lid"), {"name": "base", "beat": 1, "length": "under", "tracks": [{"thing": "sponge",
		"part": "wedge", "law": "paint", "on": "mask", "paint": ["base"], "from": "white pot"}]}]}, 1)
	var tp: TablePaint = m._work.paint
	_ok(tp != null and (m._work.acts as Array).size() == 3, "the put-back acts were not kept: %s" % "; ".join(m._work.notes))
	if tp == null or (m._work.acts as Array).size() < 3:
		m._root3.free()
		return true
	var brow_t := _track_of(m, "brow")
	var lid_t := _track_of(m, "lid")
	_ok(bool(brow_t.get("_keep", false)) and lid_t.has("_loaded"), "the liner's brow is not kept in hand for its lid in the same black: %s, %s" % [
		brow_t.get("_keep", false), lid_t.get("_loaded", "")])
	var action := {"kind": "work", "card": 1, "after": 0, "dur": 0.0}
	var cues: Array = [{"name": "brow", "si": 0}, {"name": "lid", "si": 1}, {"name": "base", "si": 2}]
	m._work.schedule([{"a": action, "t0": 2.0, "s": 1.0}], {"actions": [action], "spoken": PackedStringArray(["one", "two", "three"]), "cues": cues},
		PackedFloat32Array([2.0, 3.0, 4.0]), PackedFloat32Array([2.5, 3.5, 4.5]), PackedFloat32Array(), 0.0)
	var ch := String(brow_t.get("_ch", ""))
	var x0: Transform3D = m._work._rest.get(ch, Transform3D.IDENTITY)
	var ents := {}
	for e in m._work._chan.get(ch, []):
		ents[String((e as Dictionary)["act"])] = e
	var base_e := {}
	for e in m._work._chan.get(String(_track_of(m, "base").get("_ch", "")), []):
		base_e = e
	_ok(ents.has("brow") and ents.has("lid") and not base_e.is_empty(), "the liner's acts and the sponge's were not placed: %s" % [ents.keys()])
	if not ents.has("brow") or not ents.has("lid") or base_e.is_empty():
		m._root3.free()
		return true
	var brow_e: Dictionary = ents["brow"]
	var lid_e: Dictionary = ents["lid"]
	var off := func(x: Variant) -> float: return (x as Transform3D).origin.distance_to(x0.origin) if x is Transform3D else INF
	_ok(float(off.call(brow_e["end"])) > 0.02 and float(off.call(lid_e["from"])) > 0.02,
		"the liner was not kept in hand between its brow and its lid: the brow ends %.1f cm off its jar, the lid begins %.1f cm off" % [
		float(off.call(brow_e["end"])) * 100.0, float(off.call(lid_e["from"])) * 100.0])
	var mid := (float(base_e["t0"]) + float(base_e["t1"])) * 0.5
	_ok(float(base_e["t0"]) >= float(lid_e["t1"]) - 0.01, "the base began before the lid was done: %.1f, %.1f" % [float(base_e["t0"]), float(lid_e["t1"])])
	_ok(float(off.call(lid_e["end"])) < 0.002 and float(off.call(m._work.value(ch, mid))) < 0.002,
		"the liner kept in hand was not put back in its jar: the lid ends %.1f cm off it, and it stands %.1f cm off it while the sponge lays the base" % [
		float(off.call(lid_e["end"])) * 100.0, float(off.call(m._work.value(ch, mid))) * 100.0])
	var d := float(lid_e["t1"]) - float(lid_e["t0"])
	var found_at: Variant = tp._held_at(tp._plan_entry(lid_e, lid_t, d), lid_t, d, float(lid_e["t1"]), lid_e["from"], x0, lid_e["from"])
	_ok(float(off.call(found_at)) > 0.02, "THE CONTROL: put back where the lid's act found it, the liner is not left off its jar: %.1f cm" % [
		float(off.call(found_at)) * 100.0])
	# ...AND BY THE COPY OF ITS ENTRY THE PHYSICS HOLDS IT BY (TablePhysics._held_pose: its `from` where the body was): matched by which copy it
	# was, none was the entry before, and the body went back to where the lid's act found it - 732687's round brush set down over the eye, its
	# plan's hand in the tray. THE CONTROL: that copy's own `from`, which a copy was given back, is off the jar.
	var copy: Dictionary = lid_e.duplicate()
	var home_of_copy: Transform3D = tp._home_of(copy, copy["from"])
	_ok(float(off.call(home_of_copy)) < 0.002 and float(off.call(copy["from"])) > 0.02,
		"a copy of the lid's entry, as the physics holds it, is not put back in the jar: %.1f cm off (its own `from` %.1f cm off)" % [
		float(off.call(home_of_copy)) * 100.0, float(off.call(copy["from"])) * 100.0])
	m._root3.free()
	return true


## THE PAINTING IS THE DESIGN (next/painted_surface.md; [PaintLayers], TablePaint._from_picture): where the surface was painted first as a
## picture, an element a brush fills is laid from it - its program the strokes the picture still wanted, its paint their coverage, nothing
## looked for after - and lays its black where the picture is black, not on the white beside it inside its own shape; the foundation too,
## whole, by the corner's own dabs. THE CONTROL: with no picture, the same design is laid as its shapes say.
func _picture() -> bool:
	var made_of := func(with_picture: bool) -> TableMedium:
		var m := _medium()
		var spec := station()
		# (...a face of a skin's tone, as the show's: the station's bisque is all but the white, and a foundation of it has nothing to do)
		(spec["materials"] as Dictionary)["bisque"] = {"kind": "ceramic", "color": "#c89e80", "polish": 0.05}
		var at := {"mask": Vector3(0, 0, -0.06), "flat jar": Vector3(0.2, 0, 0.06), "sponge": Vector3(-0.16, 0, 0.08), "white pot": Vector3(-0.09, 0, 0.12),
			"black pot": Vector3(0.09, 0, 0.12), "water cup": Vector3(0.22, 0, -0.06), "towel": Vector3(-0.24, 0, -0.08)}
		for nm in at:
			_stand(m, spec, nm, Vector3(Tables.ORIGIN.x, 0.0, Tables.ORIGIN.y) + (at[nm] as Vector3))
		m._work.skin_doc = {"designs": [{"thing": "mask", "part": "face", "name": "picture", "elements": [
			{"id": "base", "stage": "base", "paint": "#f6f2ea", "fill": "all"},
			{"id": "eye", "stage": "eyes", "paint": "#121214", "fill": "M 40 80 L 75 80 L 75 105 L 40 105 Z"}]}]}
		if with_picture:
			# (...the picture: a white face, a black bar inside the eye's shape, white round it - 3 points a millimeter over the face's frame; the
			# bar half again as tall as the flat brush is wide, so the brush's picture, judged over its own width, is black along it: 9 mm tall,
			# whether it found a stroke there at all turned on the foundation's film under it)
			var img := Image.create(450, 630, false, Image.FORMAT_RGBA8)
			for y in 630:
				for x in 450:
					var q := Vector2(float(x) + 0.5, float(y) + 0.5) / 3.0
					var inside := Vector2((q.x - 75.0) / 74.0, (q.y - 105.0) / 104.0).length() <= 1.0
					var black := q.x > 47.0 and q.x < 68.0 and q.y > 85.0 and q.y < 100.0
					img.set_pixel(x, y, Color("#121214") if black else Color("#f6f2ea") if inside else Color(0, 0, 0, 0))
			m._work.skin_ref = img
			m._work.skin_ref_on = "mask/face"
		m._work.build({"acts": [
			{"name": "base", "beat": 1, "length": "under", "tracks": [{"thing": "sponge", "part": "wedge", "law": "paint", "on": "mask", "paint": ["base"],
				"manner": "stipple", "from": "white pot", "rinse": "water cup", "dry": "towel"}]},
			{"name": "eye", "beat": 2, "length": "under", "tracks": [{"thing": "flat jar", "part": "flat", "law": "paint", "on": "mask", "paint": ["eye"],
				"from": "black pot", "rinse": "water cup", "dry": "towel"}]}]}, 2)
		return m
	var m: TableMedium = made_of.call(true)
	var tp: TablePaint = m._work.paint
	var items: Dictionary = tp.skins[0]["items"] if tp != null else {}
	var base_made: Dictionary = (items.get("base", {}) as Dictionary).get("made", {})
	var eye_made: Dictionary = (items.get("eye", {}) as Dictionary).get("made", {})
	var strokes_of := func(md: Dictionary) -> int: return ((md.get("program", {}) as Dictionary).get("strokes", []) as Array).size()
	print("  laid from the picture: the foundation %d dabs, the eye %d strokes" % [strokes_of.call(base_made), strokes_of.call(eye_made)])
	_ok(bool(base_made.get("laid", false)) and strokes_of.call(base_made) > 20 and base_made.get("foot") is Image,
		"the foundation is not laid from the picture: %s" % [base_made.keys()])
	_ok(bool(eye_made.get("laid", false)) and strokes_of.call(eye_made) > 0 and eye_made.get("foot") is Image,
		"the brushed element is not laid from the picture: %s" % [eye_made.keys()])
	_ok(tp != null and (tp.plan_of(_track_of(m, "eye"), 60.0)["phases"] as Array).map(func(p: Dictionary) -> String: return String(p["kind"])).has("el"),
		"the brushed element's act lays nothing")
	if eye_made.get("foot") is Image:
		var foot: Image = eye_made["foot"]
		var er: Rect2 = eye_made["rect"]
		var at_mm := func(q: Vector2) -> float:
			var px := Vector2i(((q - er.position) * PaintLayers.FOOT_PX).floor())
			return foot.get_pixel(px.x, px.y).r if px.x >= 0 and px.y >= 0 and px.x < foot.get_width() and px.y < foot.get_height() else -1.0
		# (...the most it laid anywhere on the bar: where along it the brush's stroke goes is the canvas's to say - the foundation's own film
		# moved it 2.5 mm off the one point this had read)
		var on_bar := 0.0
		for yy in range(86, 100):
			for xx in range(48, 68):
				on_bar = maxf(on_bar, float(at_mm.call(Vector2(float(xx) + 0.5, float(yy) + 0.5))))
		var beside: float = at_mm.call(Vector2(43.0, 102.0))
		print("  the eye's paint on the picture's black %.2f, on its white inside the eye's shape %.2f" % [on_bar, beside])
		_ok(on_bar > 0.5 and beside >= 0.0 and beside < 0.15, "the brush laid %.2f on the black and %.2f on the white beside it" % [on_bar, beside])
	m._root3.free()
	var mc: TableMedium = made_of.call(false)
	var eye_c: Dictionary = (((mc._work.paint.skins[0] as Dictionary)["items"] as Dictionary).get("eye", {}) as Dictionary).get("made", {}) if mc._work.paint != null else {}
	_ok(not bool(eye_c.get("laid", false)) and not eye_c.is_empty(), "THE CONTROL: with no picture the element was laid from one, or not at all")
	mc._root3.free()
	return true


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
	# (the hairs' tip as the frame draws them, bent or laid - [method TablePaint._tick_tool])
	var hair_mat: ShaderMaterial = ((tool["tufts"] as Array)[0] as Dictionary)["mat"]
	var drawn_tip := func() -> Vector3:
		var xn := m._work._world_of((m._work.works[lw] as Dictionary)["node"])
		return xn * TablePaint._bent_tip(tool, hair_mat.get_shader_parameter("bristle_bend") as Vector3, hair_mat.get_shader_parameter("bristle_lay") as Vector2)
	var on_towel := false
	var in_cup := false
	for p in plan["phases"]:
		var pd: Dictionary = p
		if not String(pd["kind"]) in ["rinse", "dry"]:
			continue
		m._work.tick(float(lines_t[0]) + lerpf(float(pd["a"]), float(pd["b"]), 0.7))
		var tip: Vector3 = drawn_tip.call()
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
	# A BRUSH IS LAID ON WHAT IT DIPS INTO AND IS DRIED ON, ITS HAIRS ON THEIR SIDE (feedback 0002, 2026-11-09: "It is not enough for the
	# very tip to touch: we need the bottom 30% to 50% of bristles touching, laying on their side"; 0017: "That brush is not even touching
	# the foundation it's dipping into ... at the grey block, where we dry the brush, it never touches either"), AND ITS HAIRS BEND ONLY
	# AWAY FROM WHAT THEY MEET (0019: "why are the bristles curved, when the brush is lifted?"): as the frame draws them ([method
	# TablePaint._tick_tool]), mid-load, mid-rinse and mid-dry, a third to two thirds of each hair's length lies along its paint, the cup's
	# floor and the towel, its tip on it and its straight tip well past it - THE CONTROL, held as feedback 0017 left it (21 degrees off
	# upright, pushed its give past its paint and the towel, bent until its tip met it; a rinse 1 mm over the floor): a tenth or less;
	# lifted over the face, the hairs are
	# straight - THE CONTROL: pressed, they bend, and away from it
	var hair_len := float(tool["len"])
	var hair_give := float(tp._contact(tool, "")["give"])
	var node_now := func() -> Transform3D:
		return m._work._world_of((m._work.works[lw] as Dictionary)["node"])
	var hold_now := func(tt: float) -> Array:
		return tp._hold_of(tp._held_at(plan, lines_tr, tt - float(lines_t[0]), tt, Transform3D.IDENTITY, m._work._rest.get("w%d:pose" % lw, Transform3D.IDENTITY),
			Transform3D.IDENTITY), tool)
	# (how much of a hair's length lies within a touch of the surface at [param level], the tuft posed [param xn], bent [param bend] (its
	# node's space) and laid [param lay] - as prop_common.gdshaderinc draws it)
	var lying := func(xn: Transform3D, bend: Vector3, lay: Vector2, level: float) -> float:
		var root: Vector3 = tool["hair_root"]
		var ax: Vector3 = tool["hair_axis"]
		var aside := bend - ax * bend.dot(ax)
		var dir := aside.normalized() if aside.length() > 1e-9 else Vector3.ZERO
		var on := 0
		for k in 41:
			var sv := float(k) / 40.0
			var v := Bristles.laid_at(sv, lay, hair_len) if lay.y > 1e-4 else Bristles.bent_at(sv, aside.length(), hair_len)
			if absf((xn * (root + ax * v.y + dir * v.x)).y - level) <= TablePaint.TOUCH_BAND:
				on += 1
		return float(on) / 41.0
	var lying_now := func(level: float) -> float:
		return lying.call(node_now.call(), hair_mat.get_shader_parameter("bristle_bend") as Vector3, hair_mat.get_shader_parameter("bristle_lay") as Vector2, level)
	# (...and held as feedback 0017 left it, at the same place over the same surface: dipped straight down its give into its paint,
	# pressed its give along itself onto the towel, a rinse a millimeter over the cup's floor)
	var old_axis := (Vector3.UP * 0.9 + Vector3.BACK * 0.35).normalized()
	var lying_was := func(h: Array, kind: String) -> float:
		var level := float(h[6])
		var src := Vector3((h[0] as Vector3).x, level, (h[0] as Vector3).z)
		var low := src - old_axis * hair_give
		if kind == "load":
			low = Vector3(src.x, level - maxf(hair_give, TablePaint.BRUSH_DIP) * maxf(old_axis.y, 0.5), src.z)
		elif kind == "rinse":
			low = src + Vector3.UP * 0.001
		var was := [low, old_axis, 1.0, false, TablePaint.TRIP_LIFT, String(h[5]), level, Vector3.UP]
		var got: Array = tp._lay_on_plane(tool, was, Vector3.ZERO)
		var xw: Transform3D = tp._node_at(was, tool, tool["x0"])
		return lying.call(xw, xw.basis.inverse() * (got[0] as Vector3), got[1] as Vector2, level)
	var judged := {}
	for kind in ["load", "rinse", "dry"]:
		var ph: Dictionary = (plan["phases"] as Array).filter(func(p: Dictionary) -> bool: return String(p["kind"]) == kind)[0]
		var tt := float(lines_t[0]) + lerpf(float(ph["a"]), float(ph["b"]), 0.65)
		var hk: Array = hold_now.call(tt)
		m._work.tick(tt)
		var level := float(hk[6]) if hk.size() > 7 else NAN
		var tip: Vector3 = drawn_tip.call()
		var straight := (node_now.call() as Transform3D) * (tool["tip"] as Vector3)
		judged[kind] = [lying_now.call(level) if not is_nan(level) else 0.0, (tip.y - level) * 1000.0, (level - straight.y) * 1000.0,
			lying_was.call(hk, kind) if not is_nan(level) else 1.0]
	for kind in judged:
		var j: Array = judged[kind]
		_ok(float(j[0]) >= 0.3 and float(j[0]) <= 0.5 and absf(float(j[1])) <= TablePaint.TOUCH_BAND * 1000.0 and float(j[2]) >= hair_give * 1000.0,
			"mid-%s the brush lies %.0f%% of its hairs along what it is pressed onto, its tip %.2f mm off it, its straight tip %.1f mm past it" % [kind,
				float(j[0]) * 100.0, float(j[1]), float(j[2])])
		_ok(float(j[3]) <= 0.1, "THE CONTROL: held as feedback 0017 left it, mid-%s it lay %.0f%% of its hairs along it" % [kind, float(j[3]) * 100.0])
	print("  laid mid-load, mid-rinse, mid-dry: %s of its hairs (held as it was: %s)" % [["load", "rinse", "dry"].map(func(k: String) -> String:
		return "%.0f%%" % (float((judged[k] as Array)[0]) * 100.0)), ["load", "rinse", "dry"].map(func(k: String) -> String:
		return "%.0f%%" % (float((judged[k] as Array)[3]) * 100.0))])
	# ...AND COME TO WHAT IT IS LAID ON NO FASTER THAN THE BRUSH KEEPS UP WITH (feedback 0002: "It also applies to the grey pad"): a dry 40 cm
	# from where the brush was, in a trip 2.6 s long, its hand never faster than the solver carries a held thing near others - THE CONTROL:
	# its way there in the trip's fixed share, as it was, faster (732687's flat brush had been drawn 15 cm behind its hand on the way)
	var pace_ph: Dictionary = (plan["phases"] as Array).filter(func(p: Dictionary) -> bool: return String(p["kind"]) == "dry")[0]
	var pace_t := float(lines_t[0]) + float(pace_ph["a"])
	var pace_from: Array = hold_now.call(pace_t - 0.02)
	var pace_pot: Array = tp._trip_hold(pace_ph, pace_t, lines_tr, pace_from)
	var pace_far := pace_from.duplicate()
	pace_far[0] = (pace_pot[0] as Vector3) + Vector3(0.3, 0.12, 0.25)
	var body_most := RigidParts.STEP_MOST * float(RigidParts.PIECES_MOST) * 60.0
	var pace_fastest := func(secs_told: float) -> float:
		var most := 0.0
		var last := Vector3.INF
		for k in 301:
			var sk := float(k) / 300.0
			var hv: Variant = tp._brush_laid(pace_far, pace_pot, sk, 7, "dry", tool, secs_told)
			var xk: Transform3D = hv if hv is Transform3D else tp._node_at(TablePaint._hold_of(hv, tool), tool, tool["x0"])
			var ck := xk * (tool["center"] as Vector3)
			if last != Vector3.INF:
				most = maxf(most, ck.distance_to(last) / (2.6 / 300.0))
			last = ck
		return most
	var pace_most: float = pace_fastest.call(2.6)
	var fixed_share: float = pace_fastest.call(0.0)
	_ok(TablePaint._says_way(pace_pot) and pace_most <= body_most, "a brush comes to the towel 40 cm off at %.2f m/s at most, the solver carrying it %.2f" % [pace_most, body_most])
	_ok(fixed_share > body_most, "THE CONTROL: its way there in the trip's fixed share, it went %.2f m/s" % fixed_share)
	var lifted_most := 0.0
	var toward_most := 0.0
	var pressed_away := 0.0
	var lifted_n := 0
	var unpressed_for := 0.0
	var lines_d := float(lines_t[1]) - float(lines_t[0])
	for k in 600:
		var tt := float(lines_t[0]) + lines_d * float(k) / 599.0
		var hk: Array = tp._hold_of(tp._held_at(plan, lines_tr, tt - float(lines_t[0]), tt, Transform3D.IDENTITY, m._work._rest.get("w%d:pose" % lw, Transform3D.IDENTITY),
			Transform3D.IDENTITY), tool)
		if hk.size() < 8 or not bool(hk[3]) or (hk[7] as Vector3).length_squared() < 0.5:
			unpressed_for = 0.0
			continue
		var n_k: Vector3 = (hk[7] as Vector3).normalized()
		unpressed_for = unpressed_for + lines_d / 599.0 if float(hk[2]) <= 0.0 else 0.0
		m._work.tick(tt)
		var bw := m._work._world_of((m._work.works[lw] as Dictionary)["node"]).basis * (hair_mat.get_shader_parameter("bristle_bend") as Vector3)
		# (...once the spring has let go of its last press: its weights are all but spent in 0.15 s - [method Bristles.weights])
		if float(hk[2]) <= 0.0 and unpressed_for > 0.15:
			lifted_n += 1
			lifted_most = maxf(lifted_most, bw.length())
			toward_most = maxf(toward_most, -bw.dot(n_k))
		elif float(hk[2]) > 0.5:
			pressed_away = maxf(pressed_away, bw.dot(n_k))
	_ok(lifted_n >= 5 and lifted_most <= 0.0002 and toward_most <= 0.0001,
		"lifted over the face, the brush's hairs are straight: bent %.2f mm at most, %.2f mm toward the face, over %d moments" % [lifted_most * 1000.0, toward_most * 1000.0, lifted_n])
	_ok(pressed_away > 0.0005, "THE CONTROL: pressed, its hairs bend away from the face, %.1f mm at most" % (pressed_away * 1000.0))
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
	_ok(Vector3(after.r - red.r, after.g - red.g, after.b - red.b).length() < Vector3(before.r - red.r, before.g - red.g, before.b - red.b).length() - 1e-5
		and after.a < before.a, "the water clouds toward the color rinsed out, a liner's a little: %s to %s, clear %.4f to %.4f" % [before.to_html(false), after.to_html(false), before.a, after.a])
	var plain_t: Array = times["plain"]
	var later: Color = m._work.value("w%d:tint" % ww, float(plain_t[1]) + 1.0)
	_ok(later.is_equal_approx(after), "THE CONTROL: an act with no rinse leaves the water as it was")
	# ...BY HOW MUCH PAINT IS RINSED INTO HOW MUCH WATER, NEVER AT ONCE (2026-11-07: "start clear, and inherit colors based upon the
	# volume coming off of brushes and sponges ... accumulate color over time, not immediately"): a sponge carries out many times a
	# liner's paint; a glass of water one sponge's rinse clouds a little, ten a lot, a liner's hardly - THE CONTROL: the rule it had,
	# a tenth of the way to the color whatever was rinsed, clouds it as much for a liner as for a sponge
	var sw: int = m._work._work_of(m._work._thing_named("sponge"), "wedge")
	var sponge_tool: Dictionary = tp.tools.get("w%d:pose" % sw, {})
	var ml_sponge := TablePaint.rinsed_ml(sponge_tool)
	var ml_liner := TablePaint.rinsed_ml(tool)
	var cloud_tr: Dictionary = {}
	for a in m._work.acts:
		for tr in (a as Dictionary)["tracks"]:
			if String((tr as Dictionary)["law"]) == "cloud":
				cloud_tr = tr
	var water_ml: float = m._work._water_ml(cloud_tr)
	_ok(ml_sponge > ml_liner * 20.0, "a sponge's rinse carries out %.3f ml of paint, a liner's %.4f" % [ml_sponge, ml_liner])
	var clean := Color(0.79, 0.85, 0.86, 1.0)
	var once := TablePaint.clouded(clean, red, ml_sponge / water_ml)
	var tenth := clean
	for k in 10:
		tenth = TablePaint.clouded(tenth, red, ml_sponge / water_ml)
	var by_liner := TablePaint.clouded(clean, red, ml_liner / water_ml)
	_ok(water_ml > 50.0 and water_ml < 400.0, "the cup holds %.0f ml of water" % water_ml)
	_ok(once.a > 0.8 and once.a < 0.97 and tenth.a < 0.5 and by_liner.a > 0.99,
		"one sponge's rinse leaves the water %.2f clear, ten %.2f, a liner's %.4f" % [once.a, tenth.a, by_liner.a])
	var moved := func(c: Color) -> float: return Vector3(c.r - clean.r, c.g - clean.g, c.b - clean.b).length()
	_ok(float(moved.call(once)) > float(moved.call(by_liner)) * 20.0, "a sponge's rinse turns the water's color %.3f of the way, a liner's %.5f" % [moved.call(once), moved.call(by_liner)])
	var old_sponge := clean.lerp(red, 0.1)
	var old_liner := clean.lerp(red, 0.1)
	_ok(not (float(moved.call(old_sponge)) > float(moved.call(old_liner)) * 20.0) and old_sponge.a == 1.0,
		"THE CONTROL: the rule it had turns it as far for a liner's rinse as for a sponge's, and never clouds it")
	# ...SEEN THROUGH, a clear liquid, under the glass round it - and the murk rinsed into it reaches what draws it - THE CONTROL: a
	# brew (clarity 0.25) keeps the opaque body; the water before the rinse, none
	var water_mat: ShaderMaterial = null
	for L in m._work.physics.liquids:
		if int((L as Dictionary)["wi"]) == ww and not ((L as Dictionary)["mats"] as Array).is_empty():
			water_mat = ((L as Dictionary)["mats"] as Array)[0]
	_ok(water_mat != null and water_mat.shader.resource_path.ends_with("prop_liquid_clear.gdshader") and water_mat.render_priority < 0,
		"the water is drawn seen through, under its glass: %s" % [water_mat.shader.resource_path if water_mat != null else "no material"])
	var brew := ShaderMaterial.new()
	brew.shader = load("res://shaders/prop.gdshader")
	brew.set_shader_parameter("clarity", 0.25)
	TablePhysics._liquid_shader(brew)
	_ok(brew.shader.resource_path.ends_with("prop_liquid.gdshader") and brew.render_priority == 0, "THE CONTROL: a brew is seen through: %s" % brew.shader.resource_path)
	if water_mat != null:
		m._work.tick(float(lines_t[0]) - 1.0)
		var murk0 := float(water_mat.get_shader_parameter("murk"))
		m._work.tick(float(lines_t[1]) + 1.0)
		var murk1 := float(water_mat.get_shader_parameter("murk"))
		_ok(murk1 > 1e-4 and absf(murk1 - (1.0 - after.a)) < 1e-4, "the water drawn is clouded as much as what was rinsed in it: %.4f" % murk1)
		_ok(murk0 < 1e-6, "THE CONTROL: before the rinse it is drawn clean: %.4f" % murk0)
	# A SPONGE RINSED AS A HAND RINSES ONE (feedback 0050: "holding it in the water for longer ... for us to ring out? Then, when we press
	# it against the board ... more than just one quick press"): squeezed under the water as it soaks, wrung out over the cup, blotted
	# on the towel in firm presses on fresh places - THE CONTROL: a brush is swished and wiped, never wrung, and dried in one press
	var str_tr: Dictionary = _track_of(m, "base").duplicate()
	str_tr["rinse"] = "water cup"
	str_tr["dry"] = "towel"
	var rinse_pot := tp._pot_hold("rinse", "", "", 10.0, str_tr)
	var dry_pot := tp._pot_hold("dry", "", "", 10.0, str_tr)
	# (a rinse goes to the cup's floor, under all its water - [method TablePaint._source_of])
	var floor_y := (rinse_pot[0] as Vector3).y
	# (each squeeze a rise of the press through [param least] where [param where] has the tool, and where it was)
	var count := func(t_tool: Dictionary, pot: Array, kind: String, where: Callable, least: float) -> Array:
		var peaks := 0
		var xs: Array = []
		var prev := 0.0
		var near := [(pot[0] as Vector3) + Vector3(0.05, 0.06, 0.0), pot[1], 0.0, false, float(pot[4]), String(pot[5])]
		for k in 800:
			var sv := TablePaint.SPONGE_GO + (1.0 - TablePaint.SPONGE_GO) * float(k) / 799.0
			var h: Variant = tp._trip(near, pot, sv, 7, kind, t_tool)
			if not (h is Array):
				continue
			var pr := float((h as Array)[2])
			if pr >= least and prev < least and where.call((h as Array)[0] as Vector3):
				peaks += 1
				xs.append(snappedf(((h as Array)[0] as Vector3).x, 0.002))
			prev = pr
		return [peaks, xs]
	var under: Array = count.call(sponge_tool, rinse_pot, "rinse", func(p: Vector3) -> bool: return p.y < floor_y + 0.005, 0.5)
	var wrung: Array = count.call(sponge_tool, rinse_pot, "rinse", func(p: Vector3) -> bool: return p.y > cup_box.end.y, 0.9)
	var blots: Array = count.call(sponge_tool, dry_pot, "dry", func(p: Vector3) -> bool: return p.y < (dry_pot[0] as Vector3).y + 0.004, 0.95)
	var spots := {}
	for x in blots[1]:
		spots[x] = true
	_ok(int(under[0]) >= TablePaint.SOAKS and int(wrung[0]) == TablePaint.WRINGS,
		"a sponge is squeezed %d times under the water and wrung %d times over the cup" % [int(under[0]), int(wrung[0])])
	_ok(int(blots[0]) == TablePaint.BLOTS and spots.size() == TablePaint.BLOTS, "and blotted %d times on the towel, on %d places" % [int(blots[0]), spots.size()])
	var brush_wrung: Array = count.call(tool, tp._pot_hold("rinse", "", "", 10.0, lines_tr), "rinse", func(p: Vector3) -> bool: return p.y > cup_box.end.y, 0.9)
	var brush_blots: Array = count.call(tool, tp._pot_hold("dry", "", "", 10.0, lines_tr), "dry", func(p: Vector3) -> bool: return true, 0.95)
	_ok(int(brush_wrung[0]) == 0 and int(brush_blots[0]) <= 1, "THE CONTROL: a brush is wrung %d times and dried in %d presses" % [int(brush_wrung[0]), int(brush_blots[0])])
	# ...SQUEEZED IN THE HAND ACROSS ITS BROAD FACES, never along its length, and let back out to its own shape between squeezes (the user:
	# "The sponge should compress first, then expand back to where it started ... most people would squish on the wider edge, the fatter
	# edge - not lengthwise") - THE CONTROL: its length is another way
	var sq: Vector4 = TablePaint._squeeze_of(sponge_tool, 1.0)
	var sbox: AABB = sponge_tool["box"]
	var squeezed := absf(Vector3(sq.x, sq.y, sq.z).dot(sbox.size))
	var longest := maxf(sbox.size.x, maxf(sbox.size.y, sbox.size.z))
	_ok(is_equal_approx(squeezed, minf(sbox.size.x, minf(sbox.size.y, sbox.size.z))) and sq.w > 0.3 and TablePaint._squeeze_of(sponge_tool, 0.0).w == 0.0,
		"a sponge is squeezed through its %.1f mm, %.0f%% thinner at its hardest, its own shape let go" % [squeezed * 1000.0, sq.w * 100.0])
	_ok(not is_equal_approx(squeezed, longest), "THE CONTROL: its %.1f mm length is not what is squeezed" % (longest * 1000.0))
	var least_between := 1.0
	var near_s := [(rinse_pot[0] as Vector3) + Vector3(0.05, 0.06, 0.0), rinse_pot[1], 0.0, false, float(rinse_pot[4]), String(rinse_pot[5])]
	for k in 200:
		var wv := 0.2 + 0.25 * float(k) / 199.0
		var h: Variant = tp._trip(near_s, rinse_pot, TablePaint.SPONGE_GO + (1.0 - TablePaint.SPONGE_GO) * wv, 7, "rinse", sponge_tool)
		least_between = minf(least_between, float((h as Array)[2]))
	_ok(least_between < 0.02, "and let back out to its own shape between its squeezes under the water (%.2f at the least)" % least_between)
	var sponge_plan := tp.plan_of(str_tr, 60.0)
	var rinse_at := -1.0
	for p in sponge_plan["phases"]:
		if String((p as Dictionary)["kind"]) == "rinse" and rinse_at < 0.0:
			rinse_at = lerpf(float((p as Dictionary)["a"]), float((p as Dictionary)["b"]), 0.5)
	_ok(rinse_at >= 0.0 and TablePaint._phase_kind(sponge_plan, rinse_at) == "rinse" and TablePaint._phase_kind(sponge_plan, -1.0) == "",
		"its rinse is found in its plan, where it is squeezed")
	# A BRUSH WORKED INTO ITS PAINT (2026-11-07: "the brush doesn't really move at all when it's dipped into the container"): swirled round
	# twice, its hairs pressed in and dragged through it - THE CONTROL: as it had been, turned once in 2.5 mm
	var load_pot := tp._pot_hold("load", "black pot", "", 10.0, lines_tr)
	var centre: Vector3 = load_pot[0]
	var load_near := [centre + Vector3(0.05, 0.06, 0.0), load_pot[1], 0.0, false, float(load_pot[4]), String(load_pot[5])]
	var turned_by := func(trip: Callable) -> Vector2:
		var ang := 0.0
		var prev_a := NAN
		var widest := 0.0
		for k in 400:
			var h: Variant = trip.call(0.36 + 0.64 * float(k) / 399.0)
			if not (h is Array) or float((h as Array)[2]) < 0.5:
				prev_a = NAN
				continue
			var off := ((h as Array)[0] as Vector3) - centre
			var flat := Vector2(off.x, off.z)
			widest = maxf(widest, flat.length())
			if flat.length() > 0.0005:
				var a := flat.angle()
				if not is_nan(prev_a):
					ang += wrapf(a - prev_a, -PI, PI)
				prev_a = a
		return Vector2(absf(ang) / TAU, widest)
	var worked: Vector2 = turned_by.call(func(sv: float) -> Variant: return tp._trip(load_near, load_pot, sv, 5, "load", tool))
	_ok(worked.x >= 1.6 and worked.y > 0.003, "a brush is worked round its paint %.1f times, out to %.1f mm, pressed in" % [worked.x, worked.y * 1000.0])
	var old_dip := func(sv: float) -> Variant:
		var w := (sv - 0.4) / 0.6
		if w < 0.0:
			return null
		var dip := clampf(sin(w * PI) * TablePaint.LOAD_HELD, 0.0, 1.0)
		return [centre + Vector3(cos(w * TAU), 0.0, sin(w * TAU)) * 0.0025 * dip, load_pot[1], dip]
	var was_dip: Vector2 = turned_by.call(old_dip)
	_ok(was_dip.x < 1.2 and was_dip.y < 0.003, "THE CONTROL: as it had been, it turned %.1f times in %.1f mm" % [was_dip.x, was_dip.y * 1000.0])
	# A BRUSH'S TIP PRESSED PAST ITS POINT, AS FAR AS ITS LINE IS WIDE (feedback 0052: "Why are we painting with the very tip of it? ... We need
	# to push a little BEYOND that tip, such that it is FORCED to bend"): a line half the brush's width presses it half as far as it gives
	# at its hardest, a hairline at the least, never its point alone - THE CONTROL: the 0.6 mm it was pressed whatever the line
	var tip_give := float(TablePaint._contact(tool, "tip")["give"])
	_ok(absf(tip_give - float(tool["len"]) * TablePaint.TIP_PUSH) < 1e-6 and tip_give > 0.0006 * 2.0,
		"a brush's tip gives %.2f mm at its hardest (%.0f mm hairs)" % [tip_give * 1000.0, float(tool["len"]) * 1000.0])
	var line_of := func(width: float) -> float:
		var e := {"id": "l", "kind": "line", "d": "M 20 20 L 60 20", "width": width}
		var pr := Skins.program(e, "line", 6.0, null, Rect2(0, 0, 80, 40))
		var most := 0.0
		for kk in pr["keys"]:
			most = maxf(most, float((kk as Array)[4]))
		return most
	var half_line: float = line_of.call(3.0)
	var hairline: float = line_of.call(0.3)
	_ok(absf(half_line - 0.5) < 0.01 and absf(hairline - Skins.LINE_PRESS_LEAST) < 0.01,
		"a line half a 6 mm brush wide is pressed %.2f of the way, a hairline %.2f" % [half_line, hairline])
	_ok(half_line * tip_give > 0.0006 and half_line < 1.0, "THE CONTROL: pressed whatever the line, it had been 1.0 of 0.6 mm")
	_ok(is_equal_approx(TablePaint._trip_len("rinse", sponge_tool), TablePaint.SPONGE_RINSE) and is_equal_approx(TablePaint._trip_len("rinse", tool), TablePaint.RINSE),
		"a sponge's rinse takes %.1f s, a brush's %.1f" % [TablePaint._trip_len("rinse", sponge_tool), TablePaint._trip_len("rinse", tool)])
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


## A BRUSH'S HANDLE AND FERRULE STAND IN NOTHING (feedback 0003, 2026-11-09: "This brush is clipping straight through the nose here ...
## Why don't we have proper collision on the props and on the mask"): a flat brush laid low on its belly at places all round a mask's
## nose, drawn each of eight ways and pressed its hardest, held clear as the show holds it ([method TablePaint._cleared]) and posed as it
## is drawn, its handle and ferrule - never its hairs, which bend - found every 2 mm over them no deeper in the face than BRUSH_IN_MOST.
## THE CONTROLS: held as a hand holds it, nothing held clear, they stand 3 mm and more in it somewhere; held clear as the clearance
## measured before - the ferrule forgiven the hairs' bend and give, the tool looked at no more than twelve times along it, as 732687's
## round brush was - 1.5 mm and more.
const BRUSH_IN_MOST := 0.0008


func _brush_clear() -> bool:
	var m := _medium()
	var spec := station()
	_stand(m, spec, "mask", Vector3(Tables.ORIGIN.x, 0.0, Tables.ORIGIN.y) + Vector3(0, 0, -0.06))
	_stand(m, spec, "flat jar", Vector3(Tables.ORIGIN.x, 0.0, Tables.ORIGIN.y) + Vector3(0.18, 0, 0.06))
	_stand(m, spec, "black pot", Vector3(Tables.ORIGIN.x, 0.0, Tables.ORIGIN.y) + Vector3(0.09, 0, 0.12))
	m._work.skin_doc = {"designs": [{"thing": "mask", "part": "face", "name": "a dot", "elements": [
		{"id": "dot", "stage": "fill", "paint": "#3a5164", "fill": "M 20 180 L 26 180 L 26 186 L 20 186 Z"}]}]}
	m._work.build({"acts": [{"name": "fill", "beat": 1, "length": "under", "tracks": [{"thing": "flat jar", "part": "flat", "law": "paint", "on": "mask", "paint": ["dot"], "from": "black pot"}]}]}, 1)
	var tp: TablePaint = m._work.paint
	_ok(tp != null and (m._work.acts as Array).size() == 1, "the flat brush's act was not kept: %s" % "; ".join(m._work.notes))
	if tp == null or (m._work.acts as Array).size() < 1:
		return true
	var track := _track_of(m, "fill")
	var tool: Dictionary = tp.tool_of(String(track.get("_ch", "")), track)
	var node: Node3D = tool["node"]
	var x0: Transform3D = tool["x0"]
	var hw := tp.holder_world(0, 0.0)
	var face_mesh := TableWork._ray_mesh(_faces_of(tp.skins[0]))
	var face_box := AABB()
	for mi in (tp.skins[0] as Dictionary)["meshes"]:
		face_box = face_box.merge(hw * (mi as MeshInstance3D).get_aabb()) if face_box.size != Vector3.ZERO else hw * (mi as MeshInstance3D).get_aabb()
	face_box = face_box.grow(0.002)
	# ...its handle and ferrule's own surface, every 2 mm over each of their faces (the node's space)
	var inv := m._work._world_of(node).affine_inverse()
	var stiff := PackedVector3Array()
	var whole := PackedVector3Array()
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var mm := mi as MeshInstance3D
		var own := (inv * m._work._world_of(mm)) * mm.mesh.get_faces()
		whole.append_array(own)
		var mat := mm.material_override as ShaderMaterial
		if mat != null and mat.has_meta("tuft"):
			continue
		for k in range(0, own.size(), 3):
			var a := own[k]
			var e1 := own[k + 1] - a
			var e2 := own[k + 2] - a
			var n := maxi(ceili(maxf(e1.length(), e2.length()) / 0.002), 1)
			for i in n + 1:
				for j in n + 1 - i:
					stiff.append(a + e1 * (float(i) / float(n)) + e2 * (float(j) / float(n)))
	# ...the places: rings round the nose's bridge and its tip, as far out as a ferrule reaches over it from the hairs
	var marks := FaceForm.landmarks(Vector3(15, 21, 8))
	var places := PackedVector2Array()
	for nm in ["the nose's bridge", "the nose's tip"]:
		var c: Vector2 = (marks[nm] as Dictionary)["at"]
		for r in [7.0, 13.0, 19.0]:
			for k in 12:
				places.append(c + Vector2.from_angle(TAU * float(k) / 12.0) * float(r))
	# how deep its handle and ferrule stand in the face as drawn, the deepest over every place and way, held by [param held_of]
	var deepest := func(t: Dictionary, held_of: Callable) -> Array:
		var worst := 0.0
		var where := ""
		for xy in places:
			for k in 8:
				var pull := Vector2.from_angle(TAU * float(k) / 8.0)
				var held: Vector4 = held_of.call(t, xy, pull)
				var h := tp._skin_hold(0, xy, 0.0, 1.0, 0.0, tool, "belly", held, held, 0.0)
				var x := tp._node_at(h, tool, x0)
				for q in stiff:
					var p := x * q
					if not face_box.has_point(p):
						continue
					var off := _off_face(face_mesh, tp, 0, p)
					if off < INF and -off > worst:
						worst = -off
						where = "at %s mm drawn %s" % [xy.snappedf(0.1), pull.snappedf(0.01)]
		return [worst, where]
	var clear := func(t: Dictionary, xy: Vector2, pull: Vector2) -> Vector4:
		return tp._cleared(0, xy, t, "belly", pull)
	var by_hand := func(t: Dictionary, xy: Vector2, pull: Vector2) -> Vector4:
		var ax := tp._held_axis(0, xy, (tp.at_mm(0, xy)[1] as Vector3).normalized(), t, "belly", pull)
		return Vector4(ax.x, ax.y, ax.z, 0.0)
	var now: Array = deepest.call(tool, clear)
	print("  a flat brush laid on its belly round a nose, %d places, eight ways: its handle and ferrule %.2f mm in the face at most (%s), %d of its %d clearance points stiff" % [
		places.size(), float(now[0]) * 1000.0, now[1], int(tool.get("stiff", 0)), (tool["points"] as PackedVector3Array).size()])
	_ok(float(now[0]) <= BRUSH_IN_MOST, "a brush laid on its belly by a nose stands %.2f mm in the face (%s)" % [float(now[0]) * 1000.0, now[1]])
	var hand: Array = deepest.call(tool, by_hand)
	_ok(float(hand[0]) > 0.003, "THE CONTROL: held as a hand holds it, nothing held clear, the brush stands only %.2f mm in the face" % (float(hand[0]) * 1000.0))
	var was := tool.duplicate()
	was.erase("stiff")
	was["points"] = TablePaint._surface_points(TableWork._ray_mesh(whole), tool["box"], TablePaint.POINTS_EVERY, 12)
	var before: Array = deepest.call(was, clear)
	_ok(float(before[0]) > 0.0015, "THE CONTROL: held clear as it was, its ferrule forgiven and looked at twelve times along it, the brush stands only %.2f mm in the face" % (float(before[0]) * 1000.0))
	return true


## A TOOL IS NEVER DRAWN IN WHAT IT PAINTS, WHATEVER ITS PLAN ([method TablePaint._kept_out]; feedback 0003, 2026-11-09: "This brush is
## clipping straight through the nose here ... Why don't we have proper collision on the props and on the mask, so that it would not even
## be possible to clip through the nose like this?"): a flat brush by a mask's nose, every pose held as a hand holds it - nothing held clear
## - round the bridge and the tip each of eight ways, and the middle of a straight way across the nose between two of them, drawn as
## [method TablePaint.pose] draws it: its handle and ferrule, found every 2 mm over them, no deeper in the face than BRUSH_IN_MOST. THE
## CONTROL: the same poses as planned stand 3 mm and more in it. A pose already clear is drawn as it is.
func _kept_clear() -> bool:
	var m := _medium()
	var spec := station()
	_stand(m, spec, "mask", Vector3(Tables.ORIGIN.x, 0.0, Tables.ORIGIN.y) + Vector3(0, 0, -0.06))
	_stand(m, spec, "flat jar", Vector3(Tables.ORIGIN.x, 0.0, Tables.ORIGIN.y) + Vector3(0.18, 0, 0.06))
	_stand(m, spec, "black pot", Vector3(Tables.ORIGIN.x, 0.0, Tables.ORIGIN.y) + Vector3(0.09, 0, 0.12))
	m._work.skin_doc = {"designs": [{"thing": "mask", "part": "face", "name": "a dot", "elements": [
		{"id": "dot", "stage": "fill", "paint": "#3a5164", "fill": "M 20 180 L 26 180 L 26 186 L 20 186 Z"}]}]}
	m._work.build({"acts": [{"name": "fill", "beat": 1, "length": "under", "tracks": [{"thing": "flat jar", "part": "flat", "law": "paint", "on": "mask", "paint": ["dot"], "from": "black pot"}]}]}, 1)
	var tp: TablePaint = m._work.paint
	_ok(tp != null and (m._work.acts as Array).size() == 1, "the flat brush's act was not kept: %s" % "; ".join(m._work.notes))
	if tp == null or (m._work.acts as Array).size() < 1:
		return true
	var track := _track_of(m, "fill")
	var tool: Dictionary = tp.tool_of(String(track.get("_ch", "")), track)
	var node: Node3D = tool["node"]
	var x0: Transform3D = tool["x0"]
	var hw := tp.holder_world(0, 0.0)
	var face_mesh := TableWork._ray_mesh(_faces_of(tp.skins[0]))
	var face_box := AABB()
	for mi in (tp.skins[0] as Dictionary)["meshes"]:
		face_box = face_box.merge(hw * (mi as MeshInstance3D).get_aabb()) if face_box.size != Vector3.ZERO else hw * (mi as MeshInstance3D).get_aabb()
	face_box = face_box.grow(0.002)
	# ...its handle and ferrule's own surface, every 2 mm over each of their faces (the node's space) - never its hairs, which bend
	var inv := m._work._world_of(node).affine_inverse()
	var stiff := PackedVector3Array()
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var mm := mi as MeshInstance3D
		var mat := mm.material_override as ShaderMaterial
		if mat != null and mat.has_meta("tuft"):
			continue
		var own := (inv * m._work._world_of(mm)) * mm.mesh.get_faces()
		for k in range(0, own.size(), 3):
			var a := own[k]
			var e1 := own[k + 1] - a
			var e2 := own[k + 2] - a
			var n := maxi(ceili(maxf(e1.length(), e2.length()) / 0.002), 1)
			for i in n + 1:
				for j in n + 1 - i:
					stiff.append(a + e1 * (float(i) / float(n)) + e2 * (float(j) / float(n)))
	var stiff_in := func(x: Transform3D) -> float:
		var worst := 0.0
		for q in stiff:
			var p := x * q
			if face_box.has_point(p):
				var off := _off_face(face_mesh, tp, 0, p)
				if off < INF:
					worst = maxf(worst, -off)
		return worst
	# ...the places: rings round the nose's bridge and its tip, each pose held as a hand holds it, nothing held clear
	var marks := FaceForm.landmarks(Vector3(15, 21, 8))
	var places := PackedVector2Array()
	for nm in ["the nose's bridge", "the nose's tip"]:
		var c: Vector2 = (marks[nm] as Dictionary)["at"]
		for r in [7.0, 13.0, 19.0]:
			for k in 12:
				places.append(c + Vector2.from_angle(TAU * float(k) / 12.0) * float(r))
	var poses: Array = []
	for xy in places:
		for k in 8:
			var pull := Vector2.from_angle(TAU * float(k) / 8.0)
			var ax := tp._held_axis(0, xy, (tp.at_mm(0, xy)[1] as Vector3).normalized(), tool, "belly", pull)
			var hv := Vector4(ax.x, ax.y, ax.z, 0.0)
			var h := tp._skin_hold(0, xy, 0.0, 1.0, 0.0, tool, "belly", hv, hv, 0.0)
			poses.append([tp._node_at(h, tool, x0), h])
	# ...and the middle of a straight way across the nose, from one side of a ring to the other
	var ring := 12
	for i in range(0, places.size(), 3):
		var j := (i / ring) * ring + ((i % ring) + ring / 2) % ring
		var a: Transform3D = (poses[i * 8] as Array)[0]
		var b: Transform3D = (poses[j * 8 + 4] as Array)[0]
		var mid := Transform3D(Basis(Quaternion(a.basis.orthonormalized()).slerp(Quaternion(b.basis.orthonormalized()), 0.5)), a.origin.lerp(b.origin, 0.5))
		poses.append([mid, mid])
	var planned := 0.0
	var drawn := 0.0
	var kept := 0
	var clear_poses := 0
	for pz in poses:
		var x: Transform3D = (pz as Array)[0]
		var was_in: float = stiff_in.call(x)
		var got := tp._kept_out(0, tool, x, (pz as Array)[1], 0.0)
		planned = maxf(planned, was_in)
		drawn = maxf(drawn, float(stiff_in.call(got)))
		if was_in <= 0.0:
			clear_poses += 1
			if got.is_equal_approx(x):
				kept += 1
	print("  %d poses held as a hand holds them, and ways across the nose: as planned %.2f mm in the face at most, as drawn %.2f mm; %d of %d clear ones drawn as they are" % [
		poses.size(), planned * 1000.0, drawn * 1000.0, kept, clear_poses])
	_ok(drawn <= BRUSH_IN_MOST, "a brush drawn wherever its plan puts it stands %.2f mm in the face" % (drawn * 1000.0))
	_ok(planned > 0.003, "THE CONTROL: as planned, those poses stand only %.2f mm in the face" % (planned * 1000.0))
	_ok(clear_poses > 0 and kept == clear_poses, "a pose already clear was moved (%d of %d kept)" % [kept, clear_poses])
	return true
