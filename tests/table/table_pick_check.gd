extends SceneTree

## table_pick_check - a click on the table names a thing and its part ([method TableMedium.ray_pick], [method SourceWindow.find_text];
## next/editing.md step 7: "a click on the stage names a thing and its part - a ray against what is built").
##
##   godot --headless --path . --script tests/table/table_pick_check.gd
##
## Two things standing one behind the other on a ray, as [member TableThings.on_table] holds them: the ray names the nearer and the
## part its mesh is; the controls a ray that meets neither names nothing, and the nearer hidden, the one behind is named. A mesh Godot
## named for itself names no part. In ✎'s window the thing named is found and picked in its data; the control a name not written
## there is not found. A free look turns the eye about the middle of the table and draws it in or out (the control: turned past
## the table it stays above it).

var _fails := 0


func _initialize() -> void:
	_run.call_deferred()


# deferred: in _initialize the root is not in the tree yet, and a mesh out of it has no place
func _run() -> void:
	var near := _box("jaw", Vector3(0, 0, -1.0))
	var far := _box("lid", Vector3(0.02, 0, -2.0))
	var unnamed := MeshInstance3D.new()
	unnamed.mesh = BoxMesh.new()
	unnamed.position = Vector3(0, 0, -3.0)
	root.add_child(unnamed)
	var things := [{"name": "mask", "meshes": [near]}, {"name": "jar", "meshes": [far]}, {"name": "towel", "meshes": [unnamed]}]
	var hit := TableMedium.ray_pick(Vector3.ZERO, Vector3(0, 0, -1), things)
	_ok(String(hit.get("thing", "")) == "mask" and String(hit.get("part", "")) == "jaw", "the ray names the nearer thing and its part: %s" % str(hit))
	_ok(TableMedium.ray_pick(Vector3.ZERO, Vector3(1, 0, 0), things).is_empty(), "the control: a ray that meets nothing names nothing")
	near.visible = false
	hit = TableMedium.ray_pick(Vector3.ZERO, Vector3(0, 0, -1), things)
	_ok(String(hit.get("thing", "")) == "jar", "the control: the nearer hidden, the one behind it is named: %s" % str(hit))
	far.visible = false
	hit = TableMedium.ray_pick(Vector3.ZERO, Vector3(0, 0, -1), things)
	_ok(String(hit.get("thing", "")) == "towel" and String(hit.get("part", "x")).is_empty(), "a mesh Godot named for itself names no part: %s" % str(hit))

	# A free look ([method TableMedium.free_eye]): untold, the eye as it was, looking at the middle; turned half round, it looks from
	# the far side; drawn twice as far, twice as far - the control: a pitch past the table keeps it above the table
	var base := Transform3D(Basis(), Vector3(0.0, 0.3, 0.5)).looking_at(Vector3.ZERO, Vector3.UP)
	var same := TableMedium.free_eye(base, Vector3.ZERO, 0.0, 0.0, 1.0)
	var round := TableMedium.free_eye(base, Vector3.ZERO, PI, 0.0, 1.0)
	var farther := TableMedium.free_eye(base, Vector3.ZERO, 0.0, 0.0, 2.0)
	var low := TableMedium.free_eye(base, Vector3.ZERO, 0.0, -1.2, 1.0)
	_ok(same.origin.distance_to(base.origin) < 1e-4 and (-same.basis.z).dot(-same.origin.normalized()) > 0.999
		and round.origin.distance_to(Vector3(0.0, 0.3, -0.5)) < 1e-3 and absf(farther.origin.length() - 2.0 * base.origin.length()) < 1e-3,
		"a free look turns the eye about the middle, looking at it, and draws it in or out")
	_ok(low.origin.y >= 0.02 - 1e-5, "the control: turned under the table, the eye stays above it (y %.3f)" % low.origin.y)

	var w := SourceWindow.new()
	root.add_child(w)
	w.text_edit.text = JSON.stringify({"things": [{"name": "mask", "at": [0, 0]}, {"name": "jar", "at": [1, 0]}]}, "\t")
	_ok(w.find_text("\"jar\"") and w.text_edit.get_selected_text() == "\"jar\"" and w.text_edit.get_caret_line() > 0,
		"in ✎'s window the thing named is found and picked (line %d)" % w.text_edit.get_caret_line())
	_ok(not w.find_text("\"candle\""), "the control: a name not written there is not found")
	w.free()
	for n in [near, far, unnamed]:
		n.free()
	if _fails == 0:
		print("table_pick_check: ALL OK")
		quit(0)
		return
	print("table_pick_check: %d FAILED" % _fails)
	quit(1)


func _box(named: String, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.2, 0.2, 0.2)
	mi.mesh = b
	mi.name = named
	mi.position = at
	root.add_child(mi)
	return mi


func _ok(cond: bool, msg: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + msg)
	if not cond:
		_fails += 1
