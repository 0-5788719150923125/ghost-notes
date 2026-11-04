extends SceneTree

## dice_bake_check - EVERY THROW LANDS AND CAN BE READ, IN REAL BODIES (next/tabletop.md): [DiceBake] run for real, in a process of its own, from a request a table would write: each person's dice from where they sit, a figure in the way. It holds that every die came to rest flat on the table in the picture, that a throw took a throw's time, came from the side it was thrown from, was heard only where a die was really moving, and is the same twice. A control: gravity is measured, and low gravity would read as low.
##
##     timeout 300 godot --headless --path . --script tests/table/dice_bake_check.gd

const OUT := "res://dist/check_dice_bake"
var fails := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		printerr("FAIL: ", what)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var dir := ProjectSettings.globalize_path(OUT)
	DirAccess.make_dir_recursive_absolute(dir)
	var left := await _bake(dir.path_join("a.bin"))
	var again := await _bake(dir.path_join("b.bin"))
	if left.is_empty() or again.is_empty():
		_check(false, "the bake wrote nothing")
	else:
		_read(left)
		_check(_same(left, again), "two runs of the same throws are the same")
	print("dice_bake_check: ", "ok" if fails == 0 else "%d failed" % fails)
	quit(1 if fails > 0 else 0)


static func _request(out: String) -> Dictionary:
	var dice := func(shapes: Array, mat: String, size := 1.0) -> Array:
		return shapes.map(func(s: int) -> Dictionary: return {"shape": s, "size": size, "material": mat})
	return {"out": out, "seed": 9, "solids": [], "rolls": [
		{"id": 1, "seat": 105.0, "dice": dice.call([20], "plastic"), "figures": []},
		{"id": 2, "seat": -105.0, "dice": dice.call([20, 20], "metal"), "figures": []},
		{"id": 3, "seat": 50.0, "dice": dice.call([6, 6, 6, 6, 6, 6, 6, 6], "plastic"), "figures": [{"at": Vector2(0.0, -0.03), "w": 0.03, "down": false}]},
		{"id": 4, "seat": -50.0, "dice": dice.call([4, 8, 10, 12], "stone"), "figures": []},
		{"id": 5, "seat": 0.0, "dice": dice.call([20], "wood", 1.6), "figures": []},
		{"id": 6, "seat": 180.0, "dice": dice.call([10, 10], "glass"), "figures": []},
	]}


func _bake(out: String) -> Dictionary:
	var req := out + ".request"
	var f := FileAccess.open(req, FileAccess.WRITE)
	f.store_buffer(var_to_bytes(_request(out)))
	f.close()
	DirAccess.remove_absolute(out)
	var output: Array = []
	var pid := OS.create_process(OS.get_executable_path(), PackedStringArray(["--path", ProjectSettings.globalize_path("res://"), "--log-file", out + ".log", "--headless", "--fixed-fps", str(DiceBake.TICKS), "--script", "res://src/table/dice_bake.gd", "--", req]))
	if pid <= 0:
		return {}
	while OS.is_process_running(pid):
		await process_frame
	output = output
	if not FileAccess.file_exists(out):
		return {}
	var g := FileAccess.open(out, FileAccess.READ)
	var got: Variant = bytes_to_var(g.get_buffer(g.get_length()))
	g.close()
	return got if got is Dictionary else {}


func _read(rec: Dictionary) -> void:
	var rolls: Dictionary = rec["rolls"]
	var req := _request("")
	_check(rolls.size() == (req["rolls"] as Array).size(), "every throw is in the record")
	for r in req["rolls"]:
		var rd: Dictionary = r
		var id := int(rd["id"])
		var got: Dictionary = rolls[id]
		var dice: Array = got["dice"]
		_check(dice.size() == (rd["dice"] as Array).size(), "throw %d has its dice" % id)
		_check(float(got["dur"]) > 0.2 and float(got["dur"]) < DiceBake.WATCH_MOST, "throw %d took a throw's time: %.2f" % [id, float(got["dur"])])
		for k in dice.size():
			var d: Dictionary = dice[k]
			var keys: PackedFloat32Array = d["keys"]
			_check(keys.size() >= 16, "throw %d die %d moved" % [id, k])
			var n := keys.size() / 8
			var last := Vector3(keys[(n - 1) * 8 + 1], keys[(n - 1) * 8 + 2], keys[(n - 1) * 8 + 3])
			var q := Quaternion(keys[(n - 1) * 8 + 4], keys[(n - 1) * 8 + 5], keys[(n - 1) * 8 + 6], keys[(n - 1) * 8 + 7])
			var shape := int((rd["dice"] as Array)[k]["shape"])
			var read := Dice.landed(shape, Basis(q.normalized()))
			_check(float(read["dot"]) >= Dice.flat_enough(shape), "throw %d die %d lies flat: %.3f" % [id, k, float(read["dot"])])
			_check(int(read["face"]) == int(d["face"]), "throw %d die %d says what it shows" % [id, k])
			_check(GameBoard.LANDS.has_point(Vector2(last.x, last.z)), "throw %d die %d is in the picture: %s" % [id, k, str(last)])
			_check(last.y > 0.0 and last.y < 0.05 * float((rd["dice"] as Array)[k]["size"]), "throw %d die %d lies on the table: %.3f" % [id, k, last.y])
			# FROM WHERE THEY SIT: the first key is on their side of the table
			var first := Vector3(keys[1], keys[2], keys[3])
			var from := GameBoard.at_seat(float(rd["seat"]), GameBoard.HAND)
			_check(Vector2(first.x, first.z).distance_to(from) < 0.25, "throw %d die %d comes from its person's side: %s, %s" % [id, k, str(first), str(from)])
			_check(Vector2(last.x, last.z).distance_to(from) > Vector2(first.x, first.z).distance_to(from), "...and goes across the table")
		# HEARD: only ever a die really moving there
		var hits: PackedFloat32Array = got["hits"]
		_check(hits.size() >= 6, "throw %d is heard" % id)
		for j in range(0, hits.size(), 6):
			_check(hits[j] >= 0.0 and hits[j] <= float(got["dur"]) + 0.01, "a hit is during the throw")
			_check(hits[j + 2] >= -0.02, "a hit is on the table")
		_check(float((got["hand"] as Vector3).y) > 0.02, "it leaves a hand above the table")
	# GRAVITY, MEASURED from nothing but where a die was, before it first lands: a fall is a fall
	var d0: Dictionary = (rolls[1] as Dictionary)["dice"][0]
	var keys: PackedFloat32Array = d0["keys"]
	var y := func(i: int) -> float: return keys[i * 8 + 2]
	var t := func(i: int) -> float: return keys[i * 8]
	var g := -(float(y.call(4)) - 2.0 * float(y.call(2)) + float(y.call(0))) / pow((float(t.call(4)) - float(t.call(0))) * 0.5, 2.0)
	_check(g > 8.0 and g < 11.5, "gravity reads as gravity: %.2f (0.5 would be a die on the moon)" % g)


static func _same(a: Dictionary, b: Dictionary) -> bool:
	for id in a["rolls"]:
		var x: Dictionary = a["rolls"][id]
		var y: Dictionary = b["rolls"][id]
		if float(x["dur"]) != float(y["dur"]):
			return false
		for k in (x["dice"] as Array).size():
			if (x["dice"][k]["keys"] as PackedFloat32Array) != (y["dice"][k]["keys"] as PackedFloat32Array):
				return false
	return true
