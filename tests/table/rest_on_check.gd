extends SceneTree

## One thing resting on or in another ([method TableThings.rest_on]): what it rests on, and how a table's `on` is made safe
## ([method CardTable.rests]). Geometry and dictionaries alone - no renderer, no table built.
##
##   godot --headless --path . --script res://tests/table/rest_on_check.gd
##
## - [method TableThings.rest_height] over [method TableThings.faces_of]: a foot over a slab rests on its top; off it, on nothing;
##   over an open tray, on its floor and never its rim; over a shut box, on its lid; a liquid's surface in the tray is no floor; a
##   mesh under a child node and a support turned and moved are read in the table's space; a face steeper than
##   [constant TableThings.REST_FLAT] is never rested on.
## - [method TableThings.rest_points] draws a foot's corners in, so a foot as wide as the tray's floor rests on the floor (control:
##   the corners themselves reach the rim, and rest on it).
## - [method CardTable.rests]: `on` kept where it names another thing (in any case: written as that thing is named), dropped where
##   it names the thing itself, nothing on the table, a strand laid along its path or the cards' box; a circle loses one link; in a
##   stack higher than [constant CardTable.STACK_MOST] the first thing past the most stands on the table, and what was on it stays on
##   it. Control: the gate's own count of bad `on`s finds every one of them in the fixture before it is made safe, and none after.
##   Through [method CardTable.sanitize_table] too.
## - [method TableThings.resting_order]: what rests is stood after what it rests on, bottom first.

var _fails := 0


func _init() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("  FAIL: " + what)


func _run() -> void:
	for check in [_heights, _points, _rests, _order]:
		var done: Variant = (check as Callable).call()
		_ok(done == true, "%s stopped part way (a script error - see above)" % (check as Callable).get_method())
	print("rest_on_check: %s (%d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _fails, "" if _fails == 1 else "s"])
	quit(1 if _fails > 0 else 0)


# --- fixtures ----------------------------------------------------------------------------------

## A closed box from [param lo] to [param hi] (meters), its triangles wound either way.
static func _slab(st: SurfaceTool, lo: Vector3, hi: Vector3) -> void:
	var c := [Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, lo.y, hi.z), Vector3(lo.x, lo.y, hi.z),
		Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z)]
	for q in [[0, 1, 2, 3], [4, 7, 6, 5], [0, 4, 5, 1], [1, 5, 6, 2], [2, 6, 7, 3], [3, 7, 4, 0]]:
		st.add_vertex(c[q[0]])
		st.add_vertex(c[q[1]])
		st.add_vertex(c[q[2]])
		st.add_vertex(c[q[0]])
		st.add_vertex(c[q[2]])
		st.add_vertex(c[q[3]])


static func _mesh(boxes: Array) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for b in boxes:
		_slab(st, b[0], b[1])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	return mi


## An open tray 20 x 20 cm: a floor 1 cm thick and walls 6 cm tall, 0.5 cm thick.
static func _tray() -> MeshInstance3D:
	return _mesh([[Vector3(-0.1, 0.0, -0.1), Vector3(0.1, 0.01, 0.1)],
		[Vector3(-0.1, 0.0, -0.1), Vector3(-0.095, 0.06, 0.1)], [Vector3(0.095, 0.0, -0.1), Vector3(0.1, 0.06, 0.1)],
		[Vector3(-0.1, 0.0, -0.1), Vector3(0.1, 0.06, -0.095)], [Vector3(-0.1, 0.0, 0.095), Vector3(0.1, 0.06, 0.1)]])


static func _square(half: float, at := Vector2.ZERO) -> PackedVector2Array:
	return PackedVector2Array([at + Vector2(-half, -half), at + Vector2(half, -half), at + Vector2(half, half), at + Vector2(-half, half)])


# --- what a foot rests on ----------------------------------------------------------------------

func _heights() -> bool:
	var root := Node3D.new()
	var book := _mesh([[Vector3(-0.1, 0.0, -0.15), Vector3(0.1, 0.05, 0.15)]])
	root.add_child(book)
	var faces := TableThings.faces_of(root, Transform3D.IDENTITY, [book])
	_ok(is_equal_approx(TableThings.rest_height(faces, TableThings.rest_points(_square(0.02))), 0.05),
		"a foot over a slab 5 cm tall rests at %s, not on its top" % TableThings.rest_height(faces, TableThings.rest_points(_square(0.02))))
	_ok(is_inf(TableThings.rest_height(faces, TableThings.rest_points(_square(0.02, Vector2(0.4, 0.0))))),
		"a foot beside the slab rests on something")
	# the open tray: its floor, never its rim; a shut one, its lid
	var tray_root := Node3D.new()
	var tray := _tray()
	tray_root.add_child(tray)
	var tray_faces := TableThings.faces_of(tray_root, Transform3D.IDENTITY, [tray])
	var in_tray := TableThings.rest_height(tray_faces, TableThings.rest_points(_square(0.03)))
	_ok(is_equal_approx(in_tray, 0.01), "a foot inside an open tray rests at %s, not on its floor (1 cm)" % in_tray)
	var on_wall := TableThings.rest_height(tray_faces, PackedVector2Array([Vector2(0.0975, 0.0)]))
	_ok(is_equal_approx(on_wall, 0.06), "a point over the tray's wall rests at %s, not on its rim (6 cm)" % on_wall)
	var lid := _mesh([[Vector3(-0.1, 0.06, -0.1), Vector3(0.1, 0.065, 0.1)]])
	tray_root.add_child(lid)
	var shut := TableThings.rest_height(TableThings.faces_of(tray_root, Transform3D.IDENTITY, [tray, lid]), TableThings.rest_points(_square(0.03)))
	_ok(is_equal_approx(shut, 0.065), "a foot over a shut box rests at %s, not on its lid" % shut)
	# a liquid's surface (its material the liquid's kind) is no floor
	var liquid := _mesh([[Vector3(-0.09, 0.01, -0.09), Vector3(0.09, 0.04, 0.09)]])
	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = "shader_type spatial;\nuniform int kind = 0;\n"
	mat.set_shader_parameter("kind", 13)
	liquid.material_override = mat
	var wet := TableThings.rest_height(TableThings.faces_of(tray_root, Transform3D.IDENTITY, [tray, liquid]), TableThings.rest_points(_square(0.03)))
	_ok(is_equal_approx(wet, 0.01), "a foot in a tray of liquid rests at %s - on the liquid, not the floor" % wet)
	mat.set_shader_parameter("kind", 0)
	var solid := TableThings.rest_height(TableThings.faces_of(tray_root, Transform3D.IDENTITY, [tray, liquid]), TableThings.rest_points(_square(0.03)))
	_ok(is_equal_approx(solid, 0.04), "the control: the same mesh of another kind is rested on (%s)" % solid)
	# a mesh under a child node, its support turned 90 degrees and moved: read in the table's space
	var turned := Node3D.new()
	var holder := Node3D.new()
	holder.position = Vector3(0.0, 0.02, 0.0)
	turned.add_child(holder)
	var plank := _mesh([[Vector3(-0.2, 0.0, -0.02), Vector3(0.2, 0.01, 0.02)]])
	holder.add_child(plank)
	var xf := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0.3, 0.0, -0.1))
	var pf := TableThings.faces_of(turned, xf, [plank])
	var along := TableThings.rest_height(pf, PackedVector2Array([Vector2(0.3, -0.25)]))
	var across := TableThings.rest_height(pf, PackedVector2Array([Vector2(0.45, -0.1)]))
	_ok(is_equal_approx(along, 0.03) and is_inf(across),
		"a plank turned and moved is read in the table's space (along it %s, across it %s)" % [along, across])
	# a steep face is never rested on
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in [Vector3(-0.1, 0.0, 0.0), Vector3(0.1, 0.0, 0.0), Vector3(0.0, 0.5, 0.05)]:
		st.add_vertex(v)
	var steep := MeshInstance3D.new()
	steep.mesh = st.commit()
	_ok(TableThings.faces_of(Node3D.new(), Transform3D.IDENTITY, [steep]).is_empty(), "a face at 84 degrees is taken to rest on")
	var st2 := SurfaceTool.new()
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in [Vector3(-0.1, 0.0, 0.0), Vector3(0.1, 0.0, 0.0), Vector3(0.0, 0.05, 0.2)]:
		st2.add_vertex(v)
	var gentle := MeshInstance3D.new()
	gentle.mesh = st2.commit()
	_ok(TableThings.faces_of(Node3D.new(), Transform3D.IDENTITY, [gentle]).size() == 3, "the control: a face at 14 degrees is not taken to rest on")
	for n in [root, tray_root, turned, steep, gentle, liquid]:
		(n as Node).free()
	return true


## A foot as wide as the tray's floor: its corners drawn in rest on the floor; the corners themselves reach the rim.
func _points() -> bool:
	var root := Node3D.new()
	var tray := _tray()
	root.add_child(tray)
	var faces := TableThings.faces_of(root, Transform3D.IDENTITY, [tray])
	var foot := _square(0.0975)
	var drawn := TableThings.rest_height(faces, TableThings.rest_points(foot))
	var raw := TableThings.rest_height(faces, foot)
	_ok(is_equal_approx(drawn, 0.01), "a foot as wide as the tray's floor rests at %s with its corners drawn in" % drawn)
	_ok(is_equal_approx(raw, 0.06), "the control: its corners themselves rest at %s, not on the rim" % raw)
	_ok(TableThings.rest_points(foot).size() == foot.size() + 1, "the points under a foot are not its corners and its middle")
	root.free()
	return true


# --- `on` made safe ----------------------------------------------------------------------------

## How many things of [param things] carry an `on` that is no rest: naming itself, nothing there, a strand or the cards' box, a link
## of a circle, or a stack past the most.
static func _bad_on(things: Array) -> int:
	var by := {}
	for t in things:
		by[String((t as Dictionary)["name"])] = t
	var bad := 0
	for t in things:
		var d: Dictionary = t
		if not d.has("on"):
			continue
		var on := String(d["on"])
		if on == String(d["name"]) or not by.has(on) or Props.draped(by[on]) or (by[on] as Dictionary).get("holds_cards") == true:
			bad += 1
			continue
		var high := 1
		var cur: Dictionary = d
		var seen := {}
		while cur.has("on") and by.has(String(cur["on"])):
			if seen.has(String(cur["name"])):
				high = 99
				break
			seen[String(cur["name"])] = true
			high += 1
			cur = by[String(cur["on"])]
		if high > CardTable.STACK_MOST:
			bad += 1
	return bad


static func _thing(name: String, on: Variant = null) -> Dictionary:
	var d := {"name": name, "parts": [{"shape": "box", "size": [4, 2, 4], "material": "wood"}]}
	if on != null:
		d["on"] = on
	return d


func _rests() -> bool:
	var strand := _thing("a red thread")
	strand["parts"] = [{"shape": "strand", "lay": "drape", "path": [[0, 0], [10, 0]]}]
	var box := _thing("the cards' box")
	box["holds_cards"] = true
	var things: Array = [_thing("a tall book"), _thing("a pebble", "A TALL BOOK"), _thing("a mirror", "a mirror"),
		_thing("a coin", "a teacup nowhere"), _thing("a bead", "a red thread"), strand, box, _thing("a ring", "the cards' box"),
		_thing("a", "b"), _thing("b", "a")]
	# a stack six high: the fifth stands on the table, the sixth on it
	things.append(_thing("s1"))
	for i in range(2, 7):
		things.append(_thing("s%d" % i, "s%d" % (i - 1)))
	var raw := things.duplicate(true)
	_ok(_bad_on(raw) >= 7, "the control: the fixture's bad `on`s are not found before it is made safe (%d)" % _bad_on(raw))
	CardTable.rests(things)
	_ok(_bad_on(things) == 0, "%d bad `on`s are left after the table is made safe" % _bad_on(things))
	var by := {}
	for t in things:
		by[String((t as Dictionary)["name"])] = t
	_ok(String((by["a pebble"] as Dictionary).get("on", "")) == "a tall book", "a pebble written on \"A TALL BOOK\" does not rest on \"a tall book\"")
	for nm in ["a mirror", "a coin", "a bead", "a ring"]:
		_ok(not (by[nm] as Dictionary).has("on"), "%s keeps an `on` that is no rest" % nm)
	_ok(int((by["a"] as Dictionary).has("on")) + int((by["b"] as Dictionary).has("on")) == 1, "a circle of two keeps %s of its links, not one" %
		(int((by["a"] as Dictionary).has("on")) + int((by["b"] as Dictionary).has("on"))))
	for i in range(2, 7):
		var want := i != CardTable.STACK_MOST + 1
		_ok((by["s%d" % i] as Dictionary).has("on") == want, "s%d %s in a stack %d high at most" % [i, "stands on the table" if want else "still rests",
			CardTable.STACK_MOST])
	# ...and through the table's own sanitizing
	var safe := CardTable.sanitize_table({"things": [_thing("a slate"), _thing("a shell", "a slate"), _thing("a key", "a key")],
		"materials": {"wood": {"kind": "wood", "color": "#8a6a3a"}}}, {})
	var got := {}
	for t in safe["things"]:
		got[String((t as Dictionary)["name"])] = t
	_ok(got.has("a shell") and String((got["a shell"] as Dictionary).get("on", "")) == "a slate", "sanitize_table drops a good `on`")
	_ok(got.has("a key") and not (got["a key"] as Dictionary).has("on"), "sanitize_table keeps a thing resting on itself")
	return true


func _order() -> bool:
	var things: Array = [_thing("c", "b"), _thing("b", "a"), _thing("a"), _thing("d", "a")]
	CardTable.rests(things)
	var order := TableThings.resting_order(things)
	_ok(order == [1, 3, 0], "what rests is stood in the order %s, not bottom first ([1, 3, 0])" % str(order))
	return true
