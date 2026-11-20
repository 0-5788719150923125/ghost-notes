extends Node

## Not a gate. Bakes a printer's paper ([Fanfold]) as the dispatch desk does ([method DispatchSet.paper_scene], the printer's own
## make, its slot 0.885 m up and `--end` (0.18) m short of the desk's end) and draws its shape at several lengths fed, side on, to look
## at: what it lies on gray, the heap tan, the paper black, each crease a red dot, the slot green. `--hand 1` bakes a scene drawn
## here instead (`--rest 1` with a paper rest), `--gate 1` the one tests/geometry/fanfold_check.gd bakes; `--lean` the way it leaves the slot (degrees from straight up).
##
##   tests/run_boot_probe.sh tests/dispatch/dispatch_paper_probe.gd 300 --out <png> [--shots N] [--lean degrees] [--end m] [--hand 1 [--rest 1]] [--gate 1]

const Fold := preload("res://src/geometry/fanfold.gd")
const SCALE := 520.0
const CELL := Vector2i(430, 420)
const ORIGIN := Vector2(90.0, 110.0)


func _ready() -> void:
	var out := "fanfold.png"
	var links := 10
	var shots := 12
	var rest := false
	var hand := false
	var gate := false
	var args := OS.get_cmdline_user_args()
	for i in args.size() - 1:
		match args[i]:
			"--out": out = args[i + 1]
			"--links": links = int(args[i + 1])
			"--shots": shots = int(args[i + 1])
			"--rest": rest = args[i + 1] == "1"
			"--hand": hand = args[i + 1] == "1"
			"--end": _end = float(args[i + 1])
			"--gate": gate = args[i + 1] == "1"
			"--lean":
				_exit = Vector2(sin(deg_to_rad(float(args[i + 1]))), cos(deg_to_rad(float(args[i + 1]))))
				_lean_set = true
	var scene := scene_of(links, rest) if hand else _desk()
	if gate:
		scene = preload("res://tests/geometry/fanfold_check.gd")._scene({})
	if _lean_set:
		scene["exit"] = _exit
	var t0 := Time.get_ticks_msec()
	var baked := Fold.bake(scene)
	print("dispatch_paper_probe: baked in %d ms - %d frames, gap %.4f m, laid %s, start %s" % [Time.get_ticks_msec() - t0,
		(baked["frames"] as Array).size(), float(baked["gap"]), str(baked["laid"]), str(baked["start"])])
	var cols := 4
	var rows := int(ceil(float(shots) / float(cols)))
	var img := Image.create(CELL.x * cols, CELL.y * rows, false, Image.FORMAT_RGB8)
	img.fill(Color(0.96, 0.96, 0.94))
	var cycle := 2.0 * float(scene["panel"])
	for k in shots:
		var at := Vector2(float(k % cols) * CELL.x, float(k / cols) * CELL.y) + ORIGIN
		_cell = Rect2(at - ORIGIN, Vector2(CELL))
		for poly in scene["solids"]:
			_poly(img, at, poly, Color(0.72, 0.72, 0.72))
		var heap: Vector2 = scene["heap"]
		_poly(img, at, PackedVector2Array([heap, heap + Vector2(float(scene["panel"]), 0), heap + Vector2(float(scene["panel"]), -0.1),
			heap + Vector2(0, -0.1)]), Color(0.8, 0.75, 0.6))
		var shape := Fold.profile(baked, cycle * float(k) / float(shots))
		var pts: PackedVector2Array = shape["points"]
		var arr := Fold.arrays(shape, 0.38, 1.0)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		for i in range(0, verts.size() - 2, 2):
			_line(img, at + _px(Vector2(-verts[i].z, verts[i].y)), at + _px(Vector2(-verts[i + 2].z, verts[i + 2].y)), Color(0.05, 0.05, 0.05))
		for i in pts.size():
			if (shape["crease"] as PackedByteArray)[i] == 1:
				_dot(img, at + _px(pts[i]), Color(0.9, 0.1, 0.1))
		_dot(img, at + _px(Vector2.ZERO), Color(0.1, 0.7, 0.2))
	img.save_png(out)
	print("dispatch_paper_probe: %s" % out)
	get_tree().quit(0)


## The desk's own scene: the printer's make as the desk builds it, its slot as high and as far from the desk's end as on the desk.
static func _desk() -> Dictionary:
	var b := PropMakes.made("printer", {}, 1)
	var node: Node3D = b["node"]
	var rig := PropRig.new(b)
	var named: Variant = rig.point("slot")
	var slot: Vector3 = named if named is Vector3 else Vector3(0, 0.125, -0.06)
	var scene := DispatchSet.paper_scene(node, slot, DispatchSet.DESK_Y + slot.y, _end, float(DispatchSet.PAPER_LEANS[0]))
	node.free()
	return scene


## The printer's desk, side on: the printer's body and cover, the desk's end, the heap beside it; with [param rest], a paper
## rest leaning back off the printer's top.
static func scene_of(links: int, rest: bool) -> Dictionary:
	var solids: Array = [
		PackedVector2Array([Vector2(-0.23, -0.125), Vector2(0.07, -0.125), Vector2(0.07, -0.005), Vector2(-0.23, -0.005)]),
		PackedVector2Array([Vector2(-0.09, -0.025), Vector2(0.03, -0.025), Vector2(0.03, 0.005), Vector2(-0.09, 0.005)]),
		PackedVector2Array([Vector2(-1.0, -1.0), Vector2(0.17, -1.0), Vector2(0.17, -0.125), Vector2(-1.0, -0.125)]),
	]
	if rest:
		solids.append(PackedVector2Array([Vector2(0.028, -0.009), Vector2(0.030, -0.013), Vector2(0.247, 0.100), Vector2(0.245, 0.104)]))
	return {"exit": _exit, "solids": solids, "heap": Vector2(0.19, -0.433), "floor": -0.885, "panel": 0.28, "links": links}


static var _cell := Rect2()
static var _exit := Vector2(0.26, 0.97)
static var _lean_set := false
static var _end := 0.18


static func _px(q: Vector2) -> Vector2:
	return Vector2(q.x, -q.y) * SCALE


static func _poly(img: Image, at: Vector2, poly: PackedVector2Array, c: Color) -> void:
	for i in poly.size():
		_line(img, at + _px(poly[i]), at + _px(poly[(i + 1) % poly.size()]), c)


static func _line(img: Image, a: Vector2, b: Vector2, c: Color) -> void:
	var n := int(maxf(absf(b.x - a.x), absf(b.y - a.y))) + 1
	for i in n + 1:
		var q := a.lerp(b, float(i) / float(n))
		if _cell.has_point(q) and q.x < img.get_width() and q.y < img.get_height():
			img.set_pixelv(Vector2i(q), c)


static func _dot(img: Image, at: Vector2, c: Color) -> void:
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var q := Vector2i(at) + Vector2i(dx, dy)
			if q.x >= 0 and q.y >= 0 and q.x < img.get_width() and q.y < img.get_height():
				img.set_pixelv(q, c)
