extends SceneTree

## assembly_model_check: what is built is designed, and it stands by the end ([AssemblyModel], next/assembly.md "The model").
## Pure: no table, no bodies.
##
##   godot --headless --path . --script res://tests/table/assembly_model_check.gd
##
## The laying: every part is a real one, nothing lies in anything, and the cells written are what is covered, exactly for what
## shows. An order exists in which every part goes on joined to what is there, and one hung from what is over it is laid after that.
## It is hollow where nobody can see, a wall's joints do not line up, and written twice it comes out the same.
## The language: each shape fills what it says, carve cuts, paint colors and adds nothing, repeat and mirror make their copies, a
## formula it cannot read is said in words.
## The build: `build` lays it in order; `wrong` puts on what is no part of it, and it is said; `undo` takes it off, and what came off
## is owed; `wreck` costs the same; `finish` stands the whole thing whatever came before.
##
## Controls: a span with nothing across it floats, and is said to; a thing in the air over nothing floats, and is said to; a model with nothing written has no parts; a build that stops short leaves parts owed.

const COLORS := {"red": "#b3261e", "tan": "#c9b185", "gray": "#8b8d8f"}

var _fails := 0


func _init() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + what)
	if not cond:
		_fails += 1


func _run() -> void:
	_laying()
	_holds()
	_language()
	_slopes_and_roof()
	_build_steps()
	_finish_always()
	_words()
	print("assembly_model_check: %s (%d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _fails, "" if _fails == 1 else "s"])
	quit(1 if _fails > 0 else 0)


static func _model(sections: Array, size := [16, 16]) -> Dictionary:
	return AssemblyModel.make({"name": "a test", "size": size, "colors": COLORS, "base_color": "gray", "sections": sections})


static func _cells_of(m: Dictionary) -> Dictionary:
	var out := {}
	for p in m["parts"]:
		var q: Dictionary = p
		for c in Assembly.cells_of(String(q["kind"]), int(q["w"]), int(q["d"]), int(q["turn"]), int(q["x"]), int(q["z"]), int(q["l"])):
			var at := Vector3i(int(c[0]), int(c[1]), int(c[2]))
			out[at] = int(out.get(at, 0)) + 1
	return out


func _laying() -> void:
	var m := _model([{"name": "a", "shapes": [{"shape": "box", "from": [0, 0, 0], "to": [15, 15, 5], "color": "tan"}, {"shape": "round", "at": [8, 8], "radius": 5, "y": [6, 41], "color": "red"}]}])
	var parts: Array = m["parts"]
	var all_real := true
	for p in parts:
		var q: Dictionary = p
		var sizes: Array = (Assembly.KINDS[String(q["kind"])] as Dictionary)["sizes"]
		all_real = all_real and sizes.has([int(q["w"]), int(q["d"])]) and int(q["turn"]) % 90 == 0
	_ok(not parts.is_empty() and all_real, "every part is one really made: %d of them" % parts.size())
	var cells := _cells_of(m)
	var twice := 0
	for at in cells:
		if int(cells[at]) > 1:
			twice += 1
	_ok(twice == 0, "nothing lies in anything: %d cells taken twice" % twice)
	# what shows is what was written: its outside, exactly
	var missing := 0
	for z in 16:
		for x in 16:
			if not cells.has(Vector3i(x, z, 0)) and (x == 0 or z == 0 or x == 15 or z == 15):
				missing += 1
	_ok(missing == 0, "its outside is all there: %d cells missing" % missing)
	var extra := 0
	for at in cells:
		# ...x, its stud deep, its level
		var a: Vector3i = at
		var in_box := a.x >= 0 and a.x <= 15 and a.y >= 0 and a.y <= 15 and a.z >= 0 and a.z <= 5
		var in_round := a.z >= 6 and a.z <= 41
		if not in_box and not in_round:
			extra += 1
	_ok(extra == 0, "and nothing was added: %d cells outside what was written" % extra)
	# hollow where nobody sees
	var solid := 16 * 16 * 6
	var kept := 0
	for at in cells:
		if (at as Vector3i).z <= 5:
			kept += 1
	var big := _model([{"name": "a", "shapes": [{"shape": "box", "from": [0, 0, 0], "to": [31, 31, 29], "color": "tan"}]}], [32, 32])
	var big_cells := _cells_of(big)
	_ok(big_cells.size() < 32 * 32 * 30 * 0.55, "a great block is hollow: %d of its %d cells" % [big_cells.size(), 32 * 32 * 30])
	_ok(not big_cells.has(Vector3i(15, 15, 15)), "control: nothing at its heart")
	_ok(kept <= solid, "a floor is what it was written")
	_ok((big["floating"] as Array).is_empty(), "and it still holds: what was hollowed out left nothing hanging")
	# a floor is big plates, not crumbs
	var floor_m := _model([{"name": "f", "shapes": [{"shape": "box", "from": [0, 0, 0], "to": [31, 31, 0], "color": "tan"}]}], [32, 32])
	_ok((floor_m["parts"] as Array).size() <= 20, "a floor of 1024 studs is a few big plates: %d" % (floor_m["parts"] as Array).size())
	var ring_m := _model([{"name": "r", "shapes": [{"shape": "round", "at": [16, 16], "radius": 12, "y": [0, 2], "color": "tan"}, {"shape": "round", "at": [16, 16], "radius": 11, "y": [0, 2], "carve": true}]}], [32, 32])
	var round_studs := 0
	for at in _cells_of(ring_m):
		if (at as Vector3i).z == 0:
			round_studs += 1
	_ok((ring_m["parts"] as Array).size() * 2 < round_studs, "a curved wall is not crumbs: %d parts for %d studs of it" % [(ring_m["parts"] as Array).size(), round_studs])
	# a wall's joints do not run up it
	var wall := _model([{"name": "w", "shapes": [{"shape": "box", "from": [0, 4, 0], "to": [31, 4, 23], "color": "tan"}]}], [32, 32])
	var joints := {}
	for p in wall["parts"]:
		var q: Dictionary = p
		if String(q["kind"]) == "brick":
			var course := int(q["l"]) / 3
			if not joints.has(course):
				joints[course] = {}
			(joints[course] as Dictionary)[int(q["x"])] = true
	var same := 0
	var checked := 0
	for c in joints:
		if joints.has(int(c) + 1):
			for x in joints[c]:
				if int(x) > 0:
					checked += 1
					if (joints[int(c) + 1] as Dictionary).has(x):
						same += 1
	_ok(checked > 0 and same * 2 <= checked, "a wall's joints are off the course below: %d of %d line up" % [same, checked])
	var again := _model([{"name": "a", "shapes": [{"shape": "box", "from": [0, 0, 0], "to": [15, 15, 5], "color": "tan"}, {"shape": "round", "at": [8, 8], "radius": 5, "y": [6, 41], "color": "red"}]}])
	_ok(str(again["parts"]) == str(parts), "written twice, it comes out the same")


## An order that works: walking them in it, each is on the plate or joined to what has gone before.
static func _holds_in_order(parts: Array) -> int:
	var at := {}
	var bad := 0
	for p in parts:
		var q: Dictionary = p
		var joined := int(q["l"]) == 0
		var kind := String(q["kind"])
		var cells := Assembly.cells_of(kind, int(q["w"]), int(q["d"]), int(q["turn"]), int(q["x"]), int(q["z"]), int(q["l"]))
		for c in cells:
			var k := Vector3i(int(c[0]), int(c[1]), int(c[2]))
			if at.has(k + Vector3i(0, 0, -1)) or at.has(k + Vector3i(0, 0, 1)):
				joined = true
		if not joined:
			bad += 1
		for c in cells:
			at[Vector3i(int(c[0]), int(c[1]), int(c[2]))] = true
	return bad


func _holds() -> void:
	var m := _model([
		{"name": "the rock", "shapes": [{"shape": "box", "from": [0, 0, 0], "to": [15, 15, 8], "color": "gray"}]},
		{"name": "the tower", "shapes": [{"shape": "box", "from": [4, 4, 9], "to": [9, 9, 40], "color": "red"}]}])
	var parts: Array = m["parts"]
	_ok((m["floating"] as Array).is_empty(), "what stands on what stands: nothing floats: %s" % str((m["floating"] as Array).slice(0, 4)))
	_ok(_holds_in_order(parts) == 0, "and there is an order it can all go on in")
	var first_tower := -1
	var rock_after := 0
	for i in parts.size():
		if int((parts[i] as Dictionary)["section"]) == 1 and first_tower < 0:
			first_tower = i
		if int((parts[i] as Dictionary)["section"]) == 0 and first_tower >= 0:
			rock_after += 1
	_ok(first_tower > 0 and rock_after * 20 <= parts.size(), "section by section, only what must hang from what comes later waiting for it: %d of %d" % [rock_after, parts.size()])
	var low_first := true
	for i in range(1, parts.size()):
		if int((parts[i] as Dictionary)["section"]) == int((parts[i - 1] as Dictionary)["section"]) and int((parts[i] as Dictionary)["l"]) + 3 < int((parts[i - 1] as Dictionary)["l"]):
			low_first = false
	_ok(low_first, "from the bottom up within each")
	# ...a span, thick enough to lay across: joined over its piers, hung from what is above where it must be
	var span := _model([{"name": "b", "shapes": [
		{"shape": "box", "from": [0, 0, 0], "to": [3, 3, 8], "color": "gray"}, {"shape": "box", "from": [28, 0, 0], "to": [31, 3, 8], "color": "gray"},
		{"shape": "box", "from": [0, 0, 9], "to": [31, 3, 14], "color": "tan"}]}], [32, 32])
	_ok((span["floating"] as Array).is_empty(), "a span two courses thick holds between its piers: %d float" % (span["floating"] as Array).size())
	_ok(_holds_in_order(span["parts"]) == 0, "and can be laid: what hangs goes on after what it hangs from")
	# controls
	var thin := _model([{"name": "b", "shapes": [
		{"shape": "box", "from": [0, 0, 0], "to": [3, 3, 8], "color": "gray"}, {"shape": "box", "from": [28, 0, 0], "to": [31, 3, 8], "color": "gray"},
		{"shape": "box", "from": [0, 0, 9], "to": [31, 0, 9], "color": "tan"}]}], [32, 32])
	_ok(not (thin["floating"] as Array).is_empty(), "control: a span one thin course long has parts with nothing across them, and it says so: %d" % (thin["floating"] as Array).size())
	var air := _model([{"name": "a", "shapes": [{"shape": "box", "from": [4, 4, 30], "to": [9, 9, 36], "color": "red"}]}])
	_ok(not (air["floating"] as Array).is_empty(), "control: a thing written in the air floats, and it says so")
	_ok(AssemblyModel.report(air).contains("HOLD ON TO NOTHING"), "...in words")
	_ok(not AssemblyModel.report(m).contains("HOLD ON TO NOTHING"), "control: and of what holds, it does not")


func _language() -> void:
	var cut := _model([{"name": "a", "shapes": [{"shape": "box", "from": [0, 0, 0], "to": [7, 7, 8], "color": "tan"}, {"shape": "box", "from": [3, 0, 0], "to": [4, 0, 5], "carve": true}]}])
	var cells := _cells_of(cut)
	_ok(not cells.has(Vector3i(3, 0, 2)) and cells.has(Vector3i(2, 0, 2)) and cells.has(Vector3i(3, 0, 7)), "carve cuts a door, and leaves what is over it")
	var painted := _model([{"name": "a", "shapes": [{"shape": "box", "from": [0, 0, 0], "to": [7, 7, 8], "color": "tan"}, {"shape": "box", "from": [0, 0, 6], "to": [7, 7, 20], "paint": true, "color": "red"}]}])
	var reds := 0
	var over := 0
	for p in painted["parts"]:
		var q: Dictionary = p
		if String(q["color"]) == "red":
			reds += 1
			if int(q["l"]) < 6:
				over += 1
	_ok(reds > 0 and over == 0, "paint colors what is there: %d parts" % reds)
	_ok(int(painted["top"]) == 9, "and adds nothing: it is still %d levels tall" % int(painted["top"]))
	var land := _model([{"name": "a", "shapes": [{"shape": "land", "height": "12 - abs(x - 8)", "color": "tan"}]}])
	var land_cells := _cells_of(land)
	_ok(land_cells.has(Vector3i(8, 3, 11)) and not land_cells.has(Vector3i(8, 3, 12)) and not land_cells.has(Vector3i(0, 3, 6)), "land stands as high as its formula says, a course at a time")
	var noisy := _model([{"name": "a", "shapes": [{"shape": "land", "height": "6 + 3*noise2(x*0.3, z*0.3)", "color": "tan"}]}])
	_ok(not (noisy["parts"] as Array).is_empty(), "noise of two numbers is in the language")
	var rep := _model([{"name": "a", "shapes": [{"shape": "box", "from": [1, 1, 0], "to": [2, 2, 2], "color": "red", "repeat": {"n": 3, "by": [4, 0, 0]}, "mirror": "z"}]}])
	var rep_cells := _cells_of(rep)
	_ok(rep_cells.has(Vector3i(9, 1, 0)) and rep_cells.has(Vector3i(9, 14, 0)) and not rep_cells.has(Vector3i(13, 1, 0)), "repeat and mirror make their copies, and no more")
	var line := _model([{"name": "a", "shapes": [{"shape": "line", "points": [[0, 8], [15, 8]], "width": 2, "tall": 6, "color": "gray"}]}])
	_ok(_cells_of(line).has(Vector3i(8, 8, 5)) and not _cells_of(line).has(Vector3i(8, 3, 0)), "a line is a wall along its points")
	var wheres := _model([{"name": "a", "shapes": [{"shape": "where", "if": "9 - ((x-8)^2 + (z-8)^2)", "from": [0, 0, 0], "to": [15, 15, 5], "color": "tan"}]}])
	_ok(_cells_of(wheres).has(Vector3i(8, 6, 2)) and not _cells_of(wheres).has(Vector3i(2, 2, 2)), "where fills where its formula says")
	var bad := _model([{"name": "a", "shapes": [{"shape": "land", "height": "instance_from_id(1)", "color": "tan"}, {"shape": "cloud", "color": "tan"}, {"shape": "box", "from": [0, 0, 0], "to": [1, 1, 2], "color": "mauve"}]}])
	_ok((bad["notes"] as PackedStringArray).size() >= 3, "what it cannot read it says, and nothing is run: %s" % str(bad["notes"]))
	_ok((bad["parts"] as Array).is_empty(), "control: with nothing written that it can use, there are no parts")
	var turned_part := _model([{"name": "a", "shapes": [{"shape": "part", "part": "arch 1x4 red", "at": [4, 4, 0], "turn": 0}, {"shape": "box", "from": [0, 0, 0], "to": [8, 8, 2], "color": "tan"}]}])
	var arches := 0
	for p in turned_part["parts"]:
		if String((p as Dictionary)["kind"]) == "arch":
			arches += 1
	_ok(arches == 1, "a part written is that part, whatever is painted round it")


func _slopes_and_roof() -> void:
	var house := _model([{"name": "h", "shapes": [{"shape": "box", "from": [4, 4, 0], "to": [12, 10, 8], "color": "tan"}, {"shape": "roof", "from": [3, 3], "to": [13, 11], "y": 9, "ridge": "x", "color": "red"}]}])
	var slopes := 0
	var turns := {}
	for p in house["parts"]:
		var q: Dictionary = p
		if String(q["kind"]) == "slope":
			slopes += 1
			turns[int(q["turn"])] = true
	_ok(slopes >= 8 and turns.has(0) and turns.has(180), "a roof is real sloped parts, falling both ways: %d" % slopes)
	_ok((house["floating"] as Array).is_empty(), "and it stands on its walls: %d float" % (house["floating"] as Array).size())
	var along_z := _model([{"name": "h", "shapes": [{"shape": "box", "from": [4, 4, 0], "to": [10, 12, 8], "color": "tan"}, {"shape": "roof", "from": [3, 3], "to": [11, 13], "y": 9, "color": "red"}]}])
	var ways := {}
	for p in along_z["parts"]:
		if String((p as Dictionary)["kind"]) == "slope":
			ways[int((p as Dictionary)["turn"])] = true
	_ok(ways.has(90) and ways.has(270), "and along its longer side, unless told")
	# a slope's low side faces out, as its cells and its mesh have it
	var hill := _model([{"name": "h", "shapes": [{"shape": "box", "from": [0, 0, 0], "to": [15, 15, 2], "color": "tan", "slopes": true}]}])
	var edge_right := false
	for p in hill["parts"]:
		var q: Dictionary = p
		if String(q["kind"]) == "slope" and int(q["turn"]) == 90 and int(q["x"]) == 14:
			edge_right = true
	_ok(edge_right, "`slopes` finishes an edge that drops, its low side outward")
	var flat := _model([{"name": "h", "shapes": [{"shape": "box", "from": [0, 0, 0], "to": [15, 15, 2], "color": "tan"}]}])
	var any := false
	for p in flat["parts"]:
		any = any or String((p as Dictionary)["kind"]) == "slope"
	_ok(not any, "control: and left out, nothing is sloped")


static func _assembly(m: Dictionary) -> Assembly:
	var a := Assembly.new()
	a.spec = {"colors": COLORS, "base": {"size": m["size"], "color": "gray", "turn": 0.0}, "stock": [{"name": "left", "colors": {"red": 1.0, "tan": 1.0, "gray": 1.0}, "kinds": {"brick": 1.0}, "count": 30}], "model": m}
	a.seed_value = 5
	a.world = {"base_at": Vector3.ZERO, "yaw": 0.0, "lens": Transform3D(Basis.IDENTITY, Vector3(0.0, 0.5, 0.5)), "fov": 40.0, "obstacles": [], "heaps": {"left": AssemblyHeap.pile("left", Vector2(-0.3, 0.0), 0.1), "aside": AssemblyHeap.pile("aside", Vector2(0.3, 0.0), 0.05)}}
	return a


func _build_steps() -> void:
	var m := _model([
		{"name": "the base", "shapes": [{"shape": "box", "from": [0, 0, 0], "to": [15, 15, 2], "color": "tan"}]},
		{"name": "the wall", "shapes": [{"shape": "box", "from": [2, 2, 3], "to": [13, 2, 11], "color": "red"}]}])
	var total := (m["parts"] as Array).size()
	var a := _assembly(m)
	a.perform([{"name": "n", "ops": [{"do": "build", "parts": 4}]}])
	_ok(a._stand_of.size() == 4, "`build` lays that many: %d" % a._stand_of.size())
	_ok(a.progress_text().contains("4 of %d" % total), "and it is said how far it stands: %s" % a.progress_text().get_slice("\n", 0))
	_ok((a.problems["n"] as Array).is_empty(), "with nothing it could not do: %s" % str(a.problems["n"]))
	a = _assembly(m)
	a.perform([{"name": "n", "ops": [{"do": "build", "section": "the base", "parts": "rest"}]}])
	var base_parts := 0
	for p in m["parts"]:
		if int((p as Dictionary)["section"]) == 0:
			base_parts += 1
	_ok(a._stand_of.size() == base_parts, "`build` of a section lays that section: %d of %d" % [a._stand_of.size(), base_parts])
	a = _assembly(m)
	a.perform([{"name": "n", "ops": [{"do": "build", "section": "the wall", "parts": "rest"}]}])
	_ok(a._stand_of.is_empty() and not (a.problems["n"] as Array).is_empty(), "control: a section whose ground is not there cannot go on, and it says so: %s" % str(a.problems["n"]))
	# wrong, then noticed
	a = _assembly(m)
	a.perform([{"name": "n", "ops": [{"do": "build", "parts": 3}, {"do": "wrong", "parts": 2}]}])
	_ok(a._off_model.size() == 2 and a._stand_of.size() == 3, "`wrong` puts on what is no part of it: %d, and %d that are" % [a._off_model.size(), a._stand_of.size()])
	_ok(a.progress_text().contains("wrongly"), "and it is said")
	a = _assembly(m)
	a.perform([{"name": "n", "ops": [{"do": "build", "parts": 3}, {"do": "wrong", "parts": 2}, {"do": "undo"}]}])
	_ok(a._off_model.is_empty() and a._stand_of.size() == 3, "`undo` takes them off: %d wrong, %d right" % [a._off_model.size(), a._stand_of.size()])
	a = _assembly(m)
	a.perform([{"name": "n", "ops": [{"do": "build", "parts": 6}, {"do": "undo", "parts": 2}]}])
	_ok(a._stand_of.size() == 4, "and the last that went on, what comes off is owed: %d stand" % a._stand_of.size())
	var owed := a._next_part()
	a = _assembly(m)
	a.perform([{"name": "n", "ops": [{"do": "build", "parts": 6}, {"do": "undo", "parts": 2}, {"do": "build", "parts": 2}]}])
	_ok(a._stand_of.size() == 6 and a._stand_of.has(owed), "and the next `build` lays what is owed first")
	# wrong, and in the way
	a = _assembly(m)
	a.perform([{"name": "n", "ops": [{"do": "wrong", "parts": 1}, {"do": "build", "parts": "rest"}]}])
	_ok(a._off_model.is_empty() and a._stand_of.size() == total, "what was wrong comes off when its place is wanted: %d of %d stand, %d wrong" % [a._stand_of.size(), total, a._off_model.size()])
	# try and look know what is next
	a = _assembly(m)
	a.perform([{"name": "n", "ops": [{"do": "try"}, {"do": "look"}, {"do": "build", "parts": 1}]}])
	_ok((a.problems["n"] as Array).is_empty(), "`try` and `look` need nothing said: they are of what comes next: %s" % str(a.problems["n"]))
	# a tower's cost
	_ok(absf(Assembly.timing([{"do": "build", "parts": 20}]).x - 20.0 * 5.0 * Assembly.BUILD_MORE) < 1e-3, "and how long it is known beforehand: 20 parts, %.0f s" % Assembly.timing([{"do": "build", "parts": 20}]).x)
	# stock: it is had, and it takes the place of what was filler
	a = _assembly(m)
	a.perform([{"name": "n", "ops": [{"do": "finish"}]}])
	var in_left := 0
	for id in a.pieces.size():
		if String((a.pieces[id] as Dictionary)["stock"]) == "left":
			in_left += 1
	_ok(in_left <= maxi(total, 30) + 8, "what is wanted takes the place of what fills a stock: %d in it, for %d wanted" % [in_left, total])


func _finish_always() -> void:
	var m := _model([
		{"name": "the base", "shapes": [{"shape": "box", "from": [0, 0, 0], "to": [15, 15, 2], "color": "tan"}]},
		{"name": "the wall", "shapes": [{"shape": "box", "from": [2, 2, 3], "to": [13, 2, 11], "color": "red"}]}])
	var total := (m["parts"] as Array).size()
	var a := _assembly(m)
	a.perform([{"name": "n", "ops": [{"do": "build", "parts": 3}, {"do": "wrong", "parts": 2}]}])
	_ok(a._stand_of.size() < total, "control: left to itself a build that stops short leaves parts owed: %d of %d" % [a._stand_of.size(), total])
	a = _assembly(m)
	a.perform([{"name": "n", "ops": [{"do": "build", "parts": 3}, {"do": "wrong", "parts": 2}, {"do": "finish"}]}])
	_ok(a._stand_of.size() == total and a._off_model.is_empty(), "`finish` stands the whole of it and nothing else: %d of %d, %d wrong" % [a._stand_of.size(), total, a._off_model.size()])
	a = _assembly(m)
	a.perform([{"name": "n", "ops": [{"do": "build", "parts": "rest"}, {"do": "wreck"}, {"do": "finish"}]}])
	_ok(a._stand_of.size() == total, "even from all of it come down: %d of %d" % [a._stand_of.size(), total])
	var steps_with := a.steps.size()
	a = _assembly(m)
	a.perform([{"name": "n", "ops": [{"do": "build", "parts": "rest"}, {"do": "finish"}]}])
	_ok(a.steps.size() == total and steps_with > total, "and it costs nothing where all of it stands: %d steps" % a.steps.size())
	# written into the work, in the last act that builds, whatever order they were written in
	var d := {"acts": [
		{"name": "last", "beat": "close", "tracks": [{"law": "assemble", "ops": [{"do": "pause"}]}]},
		{"name": "first", "beat": "intro", "tracks": [{"law": "assemble", "ops": [{"do": "build", "parts": 3}]}]},
		{"name": "mid", "beat": 2, "tracks": [{"law": "assemble", "ops": [{"do": "dig"}]}]},
		{"name": "no build", "beat": "close", "tracks": [{"law": "carry", "thing": "a mug"}]}]}
	Assembly.with_finish(d, m)
	var last_ops: Array = ((d["acts"][0] as Dictionary)["tracks"][0] as Dictionary)["ops"]
	# ...what it comes to is known, or the words end before it does and the video with them
	_ok(int((last_ops[0] as Dictionary)["owed"]) == total - 3, "and it says how much that is, from what the acts before it really left: %d of %d" % [int((last_ops[0] as Dictionary).get("owed", -1)), total])
	var said_long := Assembly.timing([last_ops[0]]).x
	_ok(said_long >= float(total - 3) * 5.0, "so whoever times the words knows how long it takes: %.0f s" % said_long)
	var all_built := {"acts": [{"name": "all", "beat": "intro", "tracks": [{"law": "assemble", "ops": [{"do": "build", "parts": "rest"}]}]}]}
	Assembly.with_finish(all_built, m)
	var none_owed: Dictionary = ((all_built["acts"][0] as Dictionary)["tracks"][0] as Dictionary)["ops"][0]
	_ok(int(none_owed["owed"]) == 0 and Assembly.timing([none_owed]).x == 0.0, "control: with all of it built nothing is owed, and it takes no time")
	_ok(String((last_ops[0] as Dictionary)["do"]) == "finish" and String((last_ops[1] as Dictionary)["do"]) == "pause", "the last act that builds begins by finishing it, and then is looked at")
	_ok(((d["acts"][1] as Dictionary)["tracks"][0] as Dictionary)["ops"].size() == 1, "control: and no other does")
	Assembly.with_finish(d)
	_ok((((d["acts"][0] as Dictionary)["tracks"][0] as Dictionary)["ops"] as Array).size() == 2, "and it is written once, however often it is asked")
	var none := {"acts": [{"name": "x", "beat": "close", "tracks": [{"law": "carry"}]}]}
	Assembly.with_finish(none)
	_ok(not str(none).contains("finish"), "control: nothing to finish in a show that does not build")
	# a model brings its plate and its colors
	var made := Assembly.sanitize({"colors": {"blue": "#1f4f9c"}, "stock": [{"name": "t", "at": [0, 0], "radius": 10}], "base": {"size": [16, 16], "color": "blue"}, "model": _model([{"name": "b", "shapes": [{"shape": "box", "from": [0, 0, 0], "to": [8, 8, 2], "color": "red"}]}], [40, 40])})
	_ok((made["base"] as Dictionary)["size"] == [40, 40] and String((made["base"] as Dictionary)["color"]) == "gray", "the table takes its plate from the model: %s" % str(made["base"]))
	_ok((made["colors"] as Dictionary).has("red") and (made["colors"] as Dictionary).has("blue"), "and its colors, with the table's own")


func _words() -> void:
	var text := AssemblyModel.describe()
	for k in AssemblyModel.SHAPES:
		_ok(text.contains("- %s:" % String(k)), "the language says %s" % String(k))
	_ok(not Assembly.describe(true).contains("- put (") and Assembly.describe(true).contains("- build (") and Assembly.describe(true).contains("- wrong ("), "a build to a model is told `build`, never `put`")
	_ok(Assembly.describe(false).contains("- put (") and not Assembly.describe(false).contains("- build ("), "control: one with none is told `put`")
	_ok(not Assembly.describe(true).contains("- finish ("), "`finish` is the code's, and nobody is told of it")
