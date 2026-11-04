extends SceneTree

## assembly_wall_check: WHAT IS IN A VESSEL STAYS IN IT, AND WHAT FALLS IS STILL THERE ([method AssemblyWorld.add_vessel], [AssemblyBake]; next/assembly.md "Walls, and what falls"). Feedback 0015, of the first real
## model's tub: "an orange brick currently clipping through the side of the bucket"; and the user, of the spill: "people do make messes - just so long as those fallen bricks still remain usable, if we need them".
## assembly_bake_check's own wall test looks at where a piece's origin goes, and an 8x8 plate standing 2.5 mm into a 3 mm wall has its origin well inside: this one looks at its corners.
##
## - A VESSEL'S INSIDE IS MEASURED: by rays, from its own surface, against what the profile says.
## - A SHOVE HOLDS: an 8x8 plate on edge against the short wall of a warped tub, shoved by a hand that cannot give, stays at the wall's face. The control: without the rule the same shove has it past the outer face.
## - THE RULE IS ONLY THAT: what is clear, what lies across the rim, what is outside and what has left over the rim are left alone; what went through comes back; a hand drawing one out takes it past the wall. The
##   control: a corner past the wall below the rim is moved, by what it is past.
## - THE TABLE HAS AN EDGE: what goes past it falls to the floor. The control: on the old slab, as wide as anything, it rested on air.
## - WHAT FELL IS USED, in a real record from a second process: a brick that rolled in under the table, a brick off its edge, and a plate lying on the plate exactly where the first part goes. The first two come up
##   beside the table and never through it, the third is moved off first, and all three end up pressed home. The controls: the first starts under the table, the third starts in the way.
##
## Run: timeout 300 godot --headless --path . --script tests/table/assembly_wall_check.gd

const DIR := "res://dist/assembly_bakes/wall_check"
const WARP := 0.63
const PROFILE := [[0.0, 0.0], [0.125, 0.0], [0.131, 0.006], [0.147, 0.082], [0.151, 0.087], [0.153, 0.092], [0.148, 0.094], [0.1425, 0.088], [0.127, 0.0095], [0.122, 0.007], [0.0, 0.007]]
const COLORS := {"red": "#b3261e", "tan": "#c9b185", "gray": "#8b8d8f"}
const FLOOR_Y := -0.72

var _fails := 0
var _spaces: Array[RID] = []


func _init() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + what)
	if not cond:
		_fails += 1


func _run() -> void:
	Engine.physics_ticks_per_second = AssemblyWorld.TICKS
	Engine.max_physics_steps_per_frame = 1
	_measured()
	await _shoved()
	_only_that()
	await _edge()
	_fallen_used()
	print("assembly_wall_check: %s (%d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _fails, "" if _fails == 1 else "s"])
	quit(1 if _fails > 0 else 0)


## A tub as a thing is one: a lathe's surface, warped on x, with both its faces.
static func _tub_faces() -> PackedVector3Array:
	var out := PackedVector3Array()
	var sides := 96
	for s in sides:
		var a0 := TAU * float(s) / float(sides)
		var a1 := TAU * float(s + 1) / float(sides)
		for i in PROFILE.size() - 1:
			var p: Array = PROFILE[i]
			var q: Array = PROFILE[i + 1]
			var v00 := Vector3(cos(a0) * float(p[0]) * WARP, float(p[1]), sin(a0) * float(p[0]))
			var v01 := Vector3(cos(a1) * float(p[0]) * WARP, float(p[1]), sin(a1) * float(p[0]))
			var v10 := Vector3(cos(a0) * float(q[0]) * WARP, float(q[1]), sin(a0) * float(q[0]))
			var v11 := Vector3(cos(a1) * float(q[0]) * WARP, float(q[1]), sin(a1) * float(q[0]))
			out.append_array(PackedVector3Array([v00, v01, v11, v00, v11, v10]))
	return out


## How far from the middle the inner face is, the way [param a] round, at height [param y]: the profile's own.
static func _inner(a: float, y: float) -> float:
	var r := lerpf(0.127, 0.1425, clampf((y - 0.0095) / (0.088 - 0.0095), 0.0, 1.0))
	return r / sqrt(pow(cos(a) / WARP, 2.0) + pow(sin(a), 2.0))


static func _outer(a: float, y: float) -> float:
	var r := lerpf(0.131, 0.147, clampf((y - 0.006) / (0.082 - 0.006), 0.0, 1.0))
	return r / sqrt(pow(cos(a) / WARP, 2.0) + pow(sin(a), 2.0))


func _world(keep: bool, list: Array) -> AssemblyWorld:
	var space := PhysicsServer3D.space_create()
	PhysicsServer3D.space_set_active(space, true)
	_spaces.append(space)
	var w := AssemblyWorld.new(space)
	w.keep_walls = keep
	w.recording = false
	w.add_slab(Transform3D(Basis.IDENTITY, Vector3(0.0, -0.25, 0.0)), Vector3(8.0, 0.25, 8.0), "wood")
	var faces := _tub_faces()
	w.add_surface(faces, "metal")
	w.add_vessel(faces, Vector2.ZERO, 0.007)
	w.make_pieces(list)
	return w


func _measured() -> void:
	var w := _world(true, [{"kind": "plate", "w": 2, "d": 2, "color": "tan"}])
	_ok(w._vessels.size() == 1, "the tub is measured")
	var v: Dictionary = w._vessels[0]
	var off := 0.0
	for a in [0.0, 0.7, 1.57, 2.6, 3.14, 4.4, 5.9]:
		for y in [0.02, 0.04, 0.06, 0.08]:
			off = maxf(off, absf(AssemblyWorld._wall_at(v, float(a), float(y)) - _inner(float(a), float(y))))
	_ok(off < 0.0015, "its inside is where its profile puts it, at worst %.2f mm off" % (off * 1000.0))
	_ok(float(v["open"]) > 0.08 and float(v["open"]) < 0.094, "its wall is held up to %.1f cm, under its rim of 9.4" % (float(v["open"]) * 100.0))
	w.free_all()


## The plate shoved; the deepest any corner of it stood past the inner face and past the outer, and past the inner where it came to rest.
func _shove(keep: bool) -> Array:
	var w := _world(keep, [{"kind": "plate", "w": 8, "d": 8, "color": "tan"}])
	var turned := Basis(Vector3.BACK, PI * 0.5)
	# ...clear of the wall where the wall comes in, at its foot
	var c := Vector3(-_inner(PI, 0.018) + 0.006, 0.05, 0.0)
	var top := float((Assembly.KINDS["plate"] as Dictionary)["h"]) * Assembly.PLATE + Assembly.STUD_H
	w.drop_in(0, Transform3D(turned, c - turned.y * top * 0.5))
	var hand := PhysicsServer3D.body_create()
	var shape := PhysicsServer3D.box_shape_create()
	PhysicsServer3D.shape_set_data(shape, Vector3(0.01, 0.025, 0.025) * AssemblyWorld.SIM)
	PhysicsServer3D.body_set_mode(hand, PhysicsServer3D.BODY_MODE_KINEMATIC)
	PhysicsServer3D.body_add_shape(hand, shape)
	PhysicsServer3D.body_set_space(hand, w.space)
	var deep := 0.0
	var out := 0.0
	var x := -0.04
	var go := func(to_x: float) -> void: PhysicsServer3D.body_set_state(hand, PhysicsServer3D.BODY_STATE_TRANSFORM, AssemblyWorld._big(Transform3D(Basis.IDENTITY, Vector3(to_x, 0.05, 0.0))))
	go.call(x)
	for tick in 240:
		x = maxf(x - 0.0014, -0.078)
		go.call(x)
		await physics_frame
		w.after_step()
		var d := _past(w, 0)
		deep = maxf(deep, d[0])
		out = maxf(out, d[1])
	go.call(0.0)
	for _i in 120:
		await physics_frame
		w.after_step()
	var rest := _past(w, 0)
	PhysicsServer3D.free_rid(hand)
	PhysicsServer3D.free_rid(shape)
	w.free_all()
	return [deep, out, rest[0]]


## How far past the inner face and the outer any corner of piece [param id] stands, under the rim.
func _past(w: AssemblyWorld, id: int) -> Array:
	var inner := 0.0
	var outer := 0.0
	for p in (w._corners[id] as PackedVector3Array):
		var at: Vector3 = w.xf[id] * p
		if at.y > 0.088:
			continue
		var a := atan2(at.z, at.x)
		var d := Vector2(at.x, at.z).length()
		inner = maxf(inner, d - _inner(a, at.y))
		outer = maxf(outer, d - _outer(a, at.y))
	return [inner, outer]


func _shoved() -> void:
	var loose_walls: Array = await _shove(false)
	var kept: Array = await _shove(true)
	_ok(float(loose_walls[0]) > 0.004, "the control: with no rule the shove has it %.1f mm past the inner face, %.1f mm past the outer" % [float(loose_walls[0]) * 1000.0, float(loose_walls[1]) * 1000.0])
	_ok(float(kept[0]) < 0.0025, "held, a shove that cannot give has it at most %.1f mm into a wall %.1f mm through" % [float(kept[0]) * 1000.0, (_outer(PI, 0.05) - _inner(PI, 0.05)) * 1000.0])
	_ok(float(kept[1]) <= 0.0, "nothing of it comes out of the far side")
	_ok(float(kept[2]) < AssemblyWorld.WALL_SLOP + 0.0002, "where it comes to rest it is %.1f mm into the wall" % (float(kept[2]) * 1000.0))


func _only_that() -> void:
	var w := _world(true, [{"kind": "plate", "w": 1, "d": 8, "color": "tan"}, {"kind": "plate", "w": 1, "d": 8, "color": "tan"}, {"kind": "brick", "w": 1, "d": 1, "color": "tan"}])
	var long_x := Basis(Vector3.UP, PI * 0.5)    # its length along x, toward the short wall
	var half := 8.0 * Assembly.STUD * 0.5
	var wall := _inner(PI, 0.05)
	var at_y := func(cx: float, y: float) -> Transform3D: return Transform3D(long_x, Vector3(cx, y, 0.0))
	var push_at := func(id: int, x: Transform3D) -> Vector3: return w._wall_push(id, x, w._middle(id, x))
	_ok((push_at.call(0, at_y.call(0.0, 0.05)) as Vector3) == Vector3.ZERO, "in the middle it is clear")
	var pressed: Vector3 = push_at.call(0, at_y.call(-wall + half - 0.003, 0.05))
	_ok(pressed.x > 0.0015 and pressed.x < 0.0034 and absf(pressed.z) < 1e-3, "the control: 3 mm past the wall below the rim it is moved back, %.1f mm" % (pressed.x * 1000.0))
	_ok((push_at.call(0, at_y.call(-wall + half - 0.0005, 0.05)) as Vector3) == Vector3.ZERO, "half a millimeter is a contact's own")
	var across := Transform3D(long_x, Vector3(-wall + half * 0.5, 0.095, 0.0))
	_ok((push_at.call(1, across) as Vector3) == Vector3.ZERO, "lying across the rim it is left alone")
	w._in[1] = -1
	var outside := Transform3D(long_x, Vector3(-_outer(PI, 0.03) - half - 0.002, 0.03, 0.0))
	_ok((push_at.call(1, outside) as Vector3) == Vector3.ZERO and w._in[1] == -1, "outside the tub it is nothing to do with it")
	# ...in it, and through the wall: still in it
	w._in[1] = -1
	push_at.call(1, at_y.call(0.0, 0.05))
	_ok(w._in[1] == 0, "its middle in the tub, it is in it")
	var ends_through: Vector3 = push_at.call(1, at_y.call(-wall - 0.004 + half, 0.05))
	_ok(ends_through.x > 0.0, "its end gone through the wall, it comes back: %.1f mm" % (ends_through.x * 1000.0))
	w._in[2] = 0
	var whole_through: Vector3 = push_at.call(2, Transform3D(Basis.IDENTITY, Vector3(-wall - 0.004, 0.05, 0.0)))
	_ok(whole_through.x > 0.004, "its middle gone through the wall, it comes back: %.1f mm" % (whole_through.x * 1000.0))
	push_at.call(1, Transform3D(long_x, Vector3(-wall - 0.03, 0.12, 0.0)))
	_ok(w._in[1] == -1, "its middle out over the rim, it has left")
	_ok((push_at.call(1, at_y.call(-wall - 0.2 + half, 0.05)) as Vector3) == Vector3.ZERO, "and after that it is free to be anywhere")
	# ...in hand
	w.place_frozen(0, at_y.call(-wall + half + 0.001, 0.02))
	w._in[0] = -1
	w._wall_push(0, w.xf[0], w.mid[0])
	w.take_up(0)
	var sent: Transform3D = at_y.call(-wall + half - 0.004, 0.05)
	w.carry_to(0, sent)
	_ok(w.xf[0].origin.x > sent.origin.x + 0.002, "a hand drawing one out takes it past the wall, not through it: %.1f mm" % ((w.xf[0].origin.x - sent.origin.x) * 1000.0))
	var over: Transform3D = Transform3D(long_x, Vector3(-wall, 0.14, 0.0))
	w.carry_to(0, over)
	_ok(w.xf[0].origin.distance_to(over.origin) < 1e-5, "over the rim it goes where it is sent")
	w.free_all()


func _edge() -> void:
	var top := Tables.top_outline({"shape": "rect", "size": [50.0, 40.0], "corner": 0.0})
	var res := {}
	for how in ["edge", "slab"]:
		var space := PhysicsServer3D.space_create()
		PhysicsServer3D.space_set_active(space, true)
		_spaces.append(space)
		var w := AssemblyWorld.new(space)
		w.recording = false
		if how == "edge":
			var ring := Tables.edge_points(top, 64)
			for i in ring.size():
				ring[i] += top["center"] as Vector2
			w.add_prism(ring, 0.0, 0.5, "wood")
			w.add_slab(Transform3D(Basis.IDENTITY, Vector3(0.0, FLOOR_Y - 0.25, 0.0)), Vector3(8.0, 0.25, 8.0), "wood")
		else:
			w.add_slab(Transform3D(Basis.IDENTITY, Vector3(0.0, -0.25, 0.0)), Vector3(8.0, 0.25, 8.0), "wood")
		w.make_pieces([{"kind": "brick", "w": 2, "d": 2, "color": "tan"}, {"kind": "brick", "w": 2, "d": 2, "color": "tan"}])
		w.drop_in(0, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.02, 0.0)))
		w.drop_in(1, Transform3D(Basis.IDENTITY, Vector3(0.40, 0.02, 0.0)))
		for _i in 240 * 2:
			await physics_frame
			w.after_step()
		res[how] = [w.xf[0].origin.y, w.xf[1].origin.y]
		w.free_all()
	_ok(absf(float(res["edge"][0])) < 0.003, "on the top it rests on the top: %.1f cm" % (float(res["edge"][0]) * 100.0))
	_ok(absf(float(res["edge"][1]) - FLOOR_Y) < 0.005, "past its edge it falls to the floor: %.1f cm" % (float(res["edge"][1]) * 100.0))
	_ok(absf(float(res["slab"][1])) < 0.003, "the control: on a slab as wide as anything it rests on air: %.1f cm" % (float(res["slab"][1]) * 100.0))


static func _key_at(a: PackedFloat32Array, t: float) -> Vector3:
	var out := Vector3(INF, INF, INF)
	var i := 0
	while i < a.size() and a[i] <= t:
		out = Vector3(a[i + 1], a[i + 2], a[i + 3])
		i += 8
	return out


func _fallen_used() -> void:
	var a := Assembly.new()
	a.spec = {"colors": COLORS, "base": {"size": [16, 16], "color": "gray", "turn": 0.0}, "stock": [
		{"name": "the pile", "at": [15.0, -14.0], "radius": 5.0, "count": 5, "colors": {"tan": 1.0}, "kinds": {"brick": 1.0}}]}
	a.seed_value = 11
	a.world = {"base_at": Vector3.ZERO, "yaw": 0.0, "lens": Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-40.0)), Vector3(0.0, 0.6, 0.6)), "fov": 40.0, "obstacles": [],
		"heaps": {"the pile": AssemblyHeap.pile("the pile", Vector2(0.15, -0.16), 0.05), "aside": AssemblyHeap.pile("aside", Vector2(0.15, 0.12), 0.04)}}
	var parts := ["brick 2x4 red", "brick 2x2 gray", "plate 2x2 gray"]
	a.perform([{"name": "building", "ops": [
		{"do": "put", "part": parts[0], "at": [6, 6], "from": "the pile"},
		{"do": "put", "part": parts[1], "at": [1, 1], "from": "the pile"},
		{"do": "put", "part": parts[2], "at": [11, 11], "from": "the pile"}]}])
	var dir := ProjectSettings.globalize_path(DIR)
	if DirAccess.dir_exists_absolute(dir):
		for f in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.make_dir_recursive_absolute(dir)
	var names := a.step_names(hash([11, "wall"]))
	var req := TableAssembly.request_of(a, a.spec, [], dir, names)
	var top := Tables.top_outline({"shape": "rect", "size": [50.0, 40.0], "corner": 0.0})
	req["top"] = top
	# THE WORLD AS IT IS WANTED, where a pour would only maybe leave it: a record goes on from whatever its first file says
	var ids := {}
	var poses := PackedFloat32Array()
	poses.resize(a.pieces.size() * 7)
	var states := PackedByteArray()
	states.resize(a.pieces.size())
	var spare := 0
	for id in a.pieces.size():
		var key := Assembly.part_key(a.pieces[id] as Dictionary)
		var at := Vector3(0.1 + 0.02 * float(spare % 4), 0.0005, -0.15 + 0.03 * float(spare / 4))
		if key == parts[0] and not ids.has("under"):
			ids["under"] = id
			at = Vector3(0.05, FLOOR_Y, 0.03)
		elif key == parts[1] and not ids.has("past"):
			ids["past"] = id
			at = Vector3(0.40, FLOOR_Y, 0.02)
		elif key == parts[2] and not ids.has("stray"):
			ids["stray"] = id
			# ...flat on the plate, in what the first part fills
			at = Vector3(-0.0, Assembly.BASE_T + Assembly.STUD_H + 0.0005, -0.004) + (a.place_xf(6, 6, 0, 2, 4, 0).origin * Vector3(1.0, 0.0, 1.0))
		else:
			spare += 1
		var i := id * 7
		poses[i] = at.x
		poses[i + 1] = at.y
		poses[i + 2] = at.z
		poses[i + 6] = 1.0
		states[id] = AssemblyWorld.FROZEN
	_ok(ids.size() == 3, "the three are among the pieces: %s" % str(ids))
	var rest := {"poses": poses, "state": states, "seated": {}, "stock_of": req["stock_of"], "yaw": 0.0, "slots": {}, "tick": 0, "model_top": 0.0, "at_of": {}}
	var sf := FileAccess.open(dir.path_join("stock.seg"), FileAccess.WRITE)
	sf.store_buffer(var_to_bytes({"rest": rest}))
	sf.close()
	var path := dir.path_join("request.bin")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(var_to_bytes(req))
	f.close()
	var out: Array = []
	var log_path := dir.path_join("log.txt")
	var code := OS.execute(OS.get_executable_path(), PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "--log-file", log_path,
		"--fixed-fps", str(AssemblyWorld.TICKS), "--script", "res://src/table/assembly_bake.gd", "--", path]), out, true)
	_ok(code == 0, "the record is made")
	var log_text := FileAccess.get_file_as_string(log_path)
	_ok(not log_text.contains("for step") and not log_text.contains("SCRIPT ERROR"), "every part was found, and nothing went wrong")
	var keys := {}
	var last: Dictionary = {}
	var seated_at := {}
	for k in names.size():
		var file := dir.path_join("%016x.seg" % names[k])
		if not FileAccess.file_exists(file):
			continue
		var seg: Dictionary = bytes_to_var(FileAccess.get_file_as_bytes(file))
		last = seg["rest"]
		for id in seg["keys"]:
			var mine: PackedFloat32Array = keys.get(int(id), PackedFloat32Array())
			mine.append_array(seg["keys"][id] as PackedFloat32Array)
			keys[int(id)] = mine
		for s in seg["seat_log"]:
			if bool((s as Array)[2]):
				seated_at[int((s as Array)[0])] = float((s as Array)[1])
	if last.is_empty():
		_ok(false, "no record to read")
		return
	for nm in ids:
		_ok(int((last["state"] as PackedByteArray)[int(ids[nm])]) == AssemblyWorld.SEATED, "the one %s is pressed home" % String(nm))
	# NEVER THROUGH THE TABLE
	_ok(Tables.sdf(top, Vector2(0.05, 0.03)) < 0.0, "the control: the first lay under the table")
	for nm in ["under", "past"]:
		var path_keys: PackedFloat32Array = keys.get(int(ids[nm]), PackedFloat32Array())
		var through := 0
		var i := 0
		var highest := -INF
		while i < path_keys.size():
			var p := Vector3(path_keys[i + 1], path_keys[i + 2], path_keys[i + 3])
			highest = maxf(highest, p.y)
			if Tables.sdf(top, Vector2(p.x, p.z)) < 0.0 and p.y > -0.45 and p.y < -0.002:
				through += 1
			i += 8
		_ok(path_keys.size() > 0 and through == 0 and highest > 0.0, "the one %s comes up beside the table and over it, never through it: %d keys in it, up to %.1f cm" % [String(nm), through, highest * 100.0])
	# MOVED OFF FIRST
	var stray := int(ids["stray"])
	var first_seat := float(seated_at.get(int(ids["under"]), -1.0))
	var seat := a.place_xf(6, 6, 0, 2, 4, 0)
	var in_way := func(p: Vector3) -> bool:
		var l: Vector3 = seat.affine_inverse() * p
		return absf(l.x) < 2.0 * Assembly.STUD * 0.5 + 2.0 * Assembly.STUD * 0.5 and absf(l.z) < 4.0 * Assembly.STUD * 0.5 + 2.0 * Assembly.STUD * 0.5
	_ok(in_way.call(Vector3(poses[stray * 7], poses[stray * 7 + 1], poses[stray * 7 + 2])), "the control: the stray lay in the first part's way")
	var when_seated := _key_at(keys.get(stray, PackedFloat32Array()), first_seat)
	_ok(first_seat > 0.0 and not in_way.call(when_seated), "as the first part went home the stray was out of its way, at %s" % str(when_seated))
	_ok(float(seated_at.get(stray, -1.0)) > first_seat, "and it was still there to be used, after that")
