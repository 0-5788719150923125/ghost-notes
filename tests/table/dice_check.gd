extends SceneTree

## dice_check - A DIE IS A TRUE SOLID, AND IT CAN SHOW ANY NUMBER HONESTLY (next/tabletop.md): every shape has its right faces, its opposite numbers add up as real dice do, and for ANY two faces there is a rotation of the solid onto itself taking one to the other: checked here by the vertices, not trusted. So a die thrown by real physics can have its printing turned to show what was rolled, and no body changes. Controls: a turn that is not a symmetry is told apart, and a body turned at random reads back the face it shows.
##
##     godot --headless --path . --script tests/table/dice_check.gd

var fails := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		printerr("FAIL: ", what)


func _init() -> void:
	_faces()
	_printing()
	_rotations()
	_reading()
	_labels()
	_meshes()
	print("dice_check: ", "ok" if fails == 0 else "%d failed" % fails)
	quit(1 if fails > 0 else 0)


func _faces() -> void:
	var corners := {4: 3, 6: 4, 8: 3, 10: 4, 12: 5, 20: 3}
	for shape: int in Dice.SHAPES:
		var sd := Dice.solid(shape)
		var faces: Array = sd["faces"]
		_check(faces.size() == shape, "a %d has %d faces: %d" % [shape, shape, faces.size()])
		for f in faces:
			var d: Dictionary = f
			_check((d["ring"] as Array).size() == int(corners[shape]), "a %d's face has %d corners: %d" % [shape, corners[shape], (d["ring"] as Array).size()])
			_check(absf((d["normal"] as Vector3).length() - 1.0) < 1e-3, "a normal is a unit")
			_check((d["normal"] as Vector3).dot(d["center"]) > 0.0, "a normal looks out")


func _printing() -> void:
	for shape: int in Dice.SHAPES:
		var sd := Dice.solid(shape)
		var printed: Array = sd["printed"]
		var seen := {}
		for f in printed:
			seen[int(f)] = true
		_check(seen.size() == shape, "every number of a %d is on a face of its own" % shape)
		if shape == 4:
			continue
		for k in shape:
			var a: Vector3 = (sd["faces"] as Array)[int(printed[k])]["normal"]
			var b: Vector3 = (sd["faces"] as Array)[int(printed[shape - 1 - k])]["normal"]
			_check(a.dot(b) < -0.999, "on a %d, %d and %d are opposite" % [shape, k + 1, shape - k])


## FOR ANY TWO FACES, ON EVERY SHAPE: a real rotation, turning the die onto itself, and landing the one face on the other.
func _rotations() -> void:
	for shape: int in Dice.SHAPES:
		var sd := Dice.solid(shape)
		var faces: Array = sd["faces"]
		var verts: PackedVector3Array = sd["verts"]
		for a in faces.size():
			for b in faces.size():
				var r := Dice.rotation_between(shape, a, b)
				_check(Dice._is_symmetry(verts, r), "a %d turns onto itself, %d to %d" % [shape, a, b])
				_check(absf(r.determinant() - 1.0) < 1e-3, "it is a rotation, no mirror: %d, %d to %d" % [shape, a, b])
				var n: Vector3 = r * ((faces[a] as Dictionary)["normal"] as Vector3)
				_check(n.dot((faces[b] as Dictionary)["normal"]) > 0.999, "a %d's face %d lands on face %d" % [shape, a, b])
	# the control: a turn that is no symmetry is told apart
	_check(not Dice._is_symmetry(Dice.solid(20)["verts"], Basis(Vector3.UP, 0.3)), "a turn that is not one is not called one")


## THE NUMBER ROLLED IS WHAT SHOWS: a body lies with some face up, the printing is turned, and the face up now carries the number.
func _reading() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for shape: int in Dice.SHAPES:
		var sd := Dice.solid(shape)
		var faces: Array = sd["faces"]
		var printed: Array = sd["printed"]
		for trial in 40:
			var showing := rng.randi_range(0, shape - 1)
			var want := rng.randi_range(0, shape - 1)
			# a body lying with solid face `showing` up (or, on a four, down)
			var n: Vector3 = (faces[showing] as Dictionary)["normal"]
			var target := Vector3.DOWN if shape == 4 else Vector3.UP
			var q := Quaternion(n, target)
			var body := Basis(q)
			var read := Dice.landed(shape, body)
			_check(int(read["face"]) == showing and float(read["dot"]) > 0.999, "a %d lying on face %d reads it" % [shape, showing])
			var turn := Dice.turn_for(shape, want, showing)
			# the printed face `want` sits at solid face printed[want] of the die's own printing: where does it go, on the body turned?
			var printed_at: Vector3 = (faces[int(printed[want])] as Dictionary)["normal"]
			var world: Vector3 = body * (turn * printed_at)
			_check(world.dot(target) > 0.999, "a %d shows the number rolled: %d on face %d" % [shape, want, showing])
	# a cocked die is told apart: tipped a good way off flat
	var tipped := Basis(Vector3.RIGHT, deg_to_rad(20.0))
	_check(float(Dice.landed(6, tipped)["dot"]) < Dice.flat_enough(6), "a die leaning on something is no reading")


func _labels() -> void:
	_check(Array(Dice.labels_of(20, 20)) == range(1, 21).map(func(v: int) -> String: return str(v)), "a twenty is 1 to 20")
	_check(Dice.labels_of(10, 10)[0] == "0" and Dice.labels_of(10, 10)[9] == "9", "a ten is 0 to 9")
	_check(Dice.labels_of(10, 100)[0] == "00" and Dice.labels_of(10, 100)[9] == "90", "a percentile's tens")
	_check(Dice.labels_of(6, 3)[0] == "1" and Dice.labels_of(6, 3)[5] == "3", "a three on a six")
	_check(Dice.labels_of(6, 2)[0] == "1" and Dice.labels_of(6, 2)[5] == "2", "a two on a six")
	_check(Dice.labels_of(6, 6, PackedStringArray(["-1", "-1", "0", "0", "+1", "+1"]))[4] == "+1", "printed names")
	# a die's value always reads back as the label on the face thrown
	for seed in 60:
		for notation in ["1d20", "1d10", "1d8", "1d3", "1d2", "4dF"]:
			var r := DiceNotation.roll(notation, seed)
			for t in r["thrown"]:
				var d: Dictionary = t
				var labels := Dice.labels_of(int(d["shape"]), int(d["sides"]), d.get("labels", PackedStringArray()))
				_check(labels[int(d["face"])] == String(d["label"]) or (int(d["sides"]) == 10 and labels[int(d["face"])] == "0" and String(d["label"]) == "10"), "%s: its face reads what was rolled, %s and %s" % [notation, labels[int(d["face"])], d["label"]])


## A MESH: its body and, where the machine shapes text, its print. Every shape, built from its own faces.
func _meshes() -> void:
	for shape: int in Dice.SHAPES:
		var r := Dice.radius_of(shape)
		var size := float((Dice.SHAPES[shape] as Dictionary)["size"])
		_check(r > size * 0.3 and r < size * 1.2, "a %d's reach fits its size: %.4f of %.4f" % [shape, r, size])
		_check(Dice.hull(shape, 1.0).size() == (Dice.solid(shape)["verts"] as PackedVector3Array).size(), "its hull is its corners")
		var body := Dice._body_arrays(Dice.solid(shape), r)
		var pos: PackedVector3Array = body[Mesh.ARRAY_VERTEX]
		_check(pos.size() >= shape * 3 and pos.size() % 3 == 0, "a %d's body is triangles" % shape)
		for i in pos.size():
			_check(pos[i].length() <= r * 1.02, "a %d's body lies inside its corners" % shape)
