extends SceneTree

## NOT a gate. What a brick record came to, read from its files alone ([AssemblyBake] wrote them; nothing is baked or rendered):
## stretch by stretch, how many pieces lie loose, have left their stock, lie on the plate, lie past the drawn table's edge or
## stand in something solid, and where each built part was taken from. Read-only; a record still being written may be read.
##
##   godot --headless --path . --log-file dist/brick4/record.log --script tests/table/assembly_record_probe.gd -- <record's folder> [--top 1.5,0.92] [--deep 0.0015] [--upto K] [--list N]
##
## `--top` is the drawn table's width and depth (meters), `--deep` how far into a solid counts (a contact's slop is 1 mm), `--upto` stops at that step, `--list` how many of the worst to name.

const CELL := 0.02
const SHRINK := 0.0002

var _tris: Array = []          # a solid -> PackedVector3Array of threes
var _grids: Array = []         # a solid -> a cell -> [the triangle's first index...]
var _req: Dictionary = {}
var _boxes: Array = []         # a piece -> [half size, its middle over its origin]
var where_in := {}             # a piece -> where it last stood in a solid, and which
var solid_at := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("assembly_record_probe: which record?")
		quit(2)
		return
	var dir := String(args[0])
	var top := Vector2(1.5, 0.92)
	var deep := 0.0015
	var upto := 1 << 30
	var list_n := 12
	for i in range(1, args.size() - 1):
		match String(args[i]):
			"--top":
				var a := String(args[i + 1]).split(",")
				top = Vector2(float(a[0]), float(a[1]))
			"--deep":
				deep = float(args[i + 1])
			"--upto":
				upto = int(args[i + 1])
			"--list":
				list_n = int(args[i + 1])
	_req = bytes_to_var(FileAccess.get_file_as_bytes(dir.path_join("request.bin")))
	_report(dir, top, deep, upto, list_n)
	quit(0)


func _report(dir: String, top: Vector2, deep: float, upto: int, list_n: int) -> void:
	var pieces: Array = _req["pieces"]
	var steps: Array = _req["steps"]
	var keys: PackedInt64Array = _req["keys"]
	for s in _req["solids"]:
		_add_solid((s as Dictionary)["faces"])
	for q in pieces:
		var row: Dictionary = Assembly.KINDS[String((q as Dictionary)["kind"])]
		var tall := float(row["h"]) * Assembly.PLATE
		_boxes.append([Vector3(float((q as Dictionary)["w"]) * Assembly.STUD * 0.5, tall * 0.5, float((q as Dictionary)["d"]) * Assembly.STUD * 0.5), Vector3(0.0, tall * 0.5, 0.0)])
	var counts := {}
	for sn in _req["stock_of"]:
		counts[String(sn)] = int(counts.get(String(sn), 0)) + 1
	print("%d pieces, %d steps, %d solids; stocks %s" % [pieces.size(), steps.size(), _tris.size(), counts])
	for nm in _req["stocks"]:
		var sd: Dictionary = _req["stocks"][nm]
		print("  %s: middle %s radius %.3f floor %.3f thing \"%s\"" % [nm, sd["middle"], float(sd["radius"]), float(sd["floor"]), sd["thing"]])
	print("plate at %s, %s studs, yaw %.2f" % [_req["base_at"], _req["base_size"], float(_req["yaw"])])
	var stock_seg: Dictionary = bytes_to_var(FileAccess.get_file_as_bytes(dir.path_join("stock.seg")))
	var last: PackedFloat32Array = PackedFloat32Array()
	var depth := {}
	var first_in := {}
	var was_rest: Dictionary = stock_seg["rest"]
	_look("poured", was_rest, last, depth, first_in, deep, top, -1)
	last = was_rest["poses"]
	var from_where := {"in its stock": 0, "off its stock, on the table": 0, "on the plate": 0, "another stock's": 0}
	var far_fetch := 0
	for k in steps.size():
		if k >= upto:
			break
		var f := dir.path_join("%016x.seg" % keys[k])
		if not FileAccess.file_exists(f):
			continue
		var seg: Dictionary = bytes_to_var(FileAccess.get_file_as_bytes(f))
		var rest: Dictionary = seg["rest"]
		# Where each part put on the plate in this stretch had lain as it began
		for s in seg["seat_log"]:
			var a: Array = s
			if not bool(a[2]):
				continue
			var id := int(a[0])
			var p := _pose(was_rest["poses"], id)
			var at := _where(id, p.origin, String(was_rest["stock_of"][id]))
			from_where[at] = int(from_where.get(at, 0)) + 1
		_look("to step %d (%s), tau %.0f" % [k + 1, String((steps[k] as Dictionary)["do"]), float(seg["tau"])], rest, last, depth, first_in, deep, top, k)
		last = rest["poses"]
		was_rest = rest
	print("parts built, by where they lay as the stretch began: %s" % from_where)
	var worst: Array = depth.keys().filter(func(i): return String((pieces[int(i)] as Dictionary)["kind"]) in ["plate", "brick", "tile"])
	worst.sort_custom(func(a, b): return float(depth[a]) > float(depth[b]))
	print("%d pieces stood in a solid at some time, %d of them true boxes (a slope, a round, an arch overlap by corners they do not have); the deepest boxes:" % [depth.size(), worst.size()])
	for i in mini(list_n, worst.size()):
		var id := int(worst[i])
		var q: Dictionary = pieces[id]
		print("  piece %d, %s %s %dx%d: %.1f mm, first at %s, last at %s" % [id, q["color"], q["kind"], int(q["w"]), int(q["d"]), float(depth[id]) * 1000.0, first_in.get(id, "?"), where_in.get(id, "?")])


## One rest looked over: only what moved since the last is tested against the solids.
func _look(what: String, rest: Dictionary, last: PackedFloat32Array, depth: Dictionary, first_in: Dictionary, deep: float, top: Vector2, _k: int) -> void:
	var poses: PackedFloat32Array = rest["poses"]
	var states: PackedByteArray = rest["state"]
	var stock_of: PackedStringArray = rest["stock_of"]
	var free := 0
	var seated := 0
	var on := {}
	var past := 0
	var low := Vector3.INF
	var high := -Vector3.INF
	var into_now := 0
	for id in states.size():
		if states[id] == AssemblyWorld.SEATED:
			seated += 1
			continue
		if states[id] == AssemblyWorld.OUT:
			continue
		free += 1
		var x := _pose(poses, id)
		var at := _where(id, x.origin, stock_of[id])
		on[at] = int(on.get(at, 0)) + 1
		low = low.min(x.origin)
		high = high.max(x.origin)
		if absf(x.origin.x - (Tables.ORIGIN + Tables.TOP_AT).x) > top.x * 0.5 or absf(x.origin.z - (Tables.ORIGIN + Tables.TOP_AT).y) > top.y * 0.5:
			past += 1
		var moved := last.is_empty()
		if not moved:
			for j in 7:
				if absf(poses[id * 7 + j] - last[id * 7 + j]) > 1e-5:
					moved = true
					break
		if moved:
			var d := _depth_in_solids(id, x)
			if d > deep:
				if not first_in.has(id):
					first_in[id] = what
				depth[id] = maxf(float(depth.get(id, 0.0)), d)
				where_in[id] = "%s %s" % [_cm(x.origin), solid_at]
				into_now += 1
	print("%s: %d loose, %d seated; %s; past the table's edge %d; moved and in a solid %d; lying from %s to %s" % [what, free, seated, on, past, into_now, _cm(low), _cm(high)])


static func _cm(v: Vector3) -> String:
	return "(%.0f, %.0f, %.0f) cm" % [v.x * 100.0, v.y * 100.0, v.z * 100.0]


func _pose(poses: PackedFloat32Array, id: int) -> Transform3D:
	var i := id * 7
	return Transform3D(Basis(Quaternion(poses[i + 3], poses[i + 4], poses[i + 5], poses[i + 6])), Vector3(poses[i], poses[i + 1], poses[i + 2]))


func _where(_id: int, p: Vector3, stock: String) -> String:
	var size: Array = _req["base_size"]
	var base: Vector3 = _req["base_at"]
	var local := Basis(Vector3.UP, float(_req["yaw"])).inverse() * (p - base)
	if absf(local.x) < float(size[0]) * Assembly.STUD * 0.5 and absf(local.z) < float(size[1]) * Assembly.STUD * 0.5:
		return "on the plate"
	for nm in _req["stocks"]:
		var sd: Dictionary = _req["stocks"][nm]
		var inside := false
		if String(sd["thing"]).is_empty():
			inside = Vector2(p.x, p.z).distance_to(sd["middle"]) < float(sd["radius"]) + 0.04
		else:
			inside = _in_cell(sd, Vector2(p.x, p.z))
		if inside:
			return "in its stock" if String(nm) == stock else "another stock's"
	return "off its stock, on the table"


static func _in_cell(sd: Dictionary, at: Vector2) -> bool:
	var origin: Vector2 = sd["origin"]
	var cols := int(sd["nx"])
	var i := int(round((at.x - origin.x) / AssemblyHeap.CELL))
	var j := int(round((at.y - origin.y) / AssemblyHeap.CELL))
	if i < 0 or j < 0 or i >= cols or j >= int(sd["nz"]):
		return false
	return not is_nan((sd["ground"] as PackedFloat32Array)[j * cols + i])


func _add_solid(faces: PackedVector3Array) -> void:
	var grid := {}
	var i := 0
	while i + 2 < faces.size():
		var a := faces[i]
		var b := faces[i + 1]
		var c := faces[i + 2]
		var lo := a.min(b).min(c)
		var hi := a.max(b).max(c)
		var c0 := Vector3i((lo / CELL).floor())
		var c1 := Vector3i((hi / CELL).floor())
		for x in range(c0.x, c1.x + 1):
			for y in range(c0.y, c1.y + 1):
				for z in range(c0.z, c1.z + 1):
					var cell := Vector3i(x, y, z)
					if not grid.has(cell):
						grid[cell] = PackedInt32Array()
					var l: PackedInt32Array = grid[cell]
					l.append(i)
					grid[cell] = l
		i += 3
	_tris.append(faces)
	_grids.append(grid)


## How deep a piece stands in what is solid: of every triangle it overlaps, the most by which it would have to move off that
## triangle (separating axes); 0 for none. Studs are left out, since what a piece rests on is under them.
func _depth_in_solids(id: int, x: Transform3D) -> float:
	var box: Array = _boxes[id]
	var e: Vector3 = (box[0] as Vector3) - Vector3.ONE * SHRINK
	var c: Vector3 = x * (box[1] as Vector3)
	var u := [x.basis.x.normalized(), x.basis.y.normalized(), x.basis.z.normalized()]
	var reach: float = e.length()
	var c0 := Vector3i(((c - Vector3.ONE * reach) / CELL).floor())
	var c1 := Vector3i(((c + Vector3.ONE * reach) / CELL).floor())
	var out := 0.0
	for si in _tris.size():
		var grid: Dictionary = _grids[si]
		var faces: PackedVector3Array = _tris[si]
		var seen := {}
		for gx in range(c0.x, c1.x + 1):
			for gy in range(c0.y, c1.y + 1):
				for gz in range(c0.z, c1.z + 1):
					var cell := Vector3i(gx, gy, gz)
					if not grid.has(cell):
						continue
					for t in (grid[cell] as PackedInt32Array):
						if seen.has(t):
							continue
						seen[t] = true
						var o := _overlap(c, u, e, faces[t], faces[t + 1], faces[t + 2])
						if o > out:
							out = o
							solid_at = "solid %d" % si
	return out


## The least overlap over the separating axes of a box and a triangle: 0 where they do not touch.
static func _overlap(c: Vector3, u: Array, e: Vector3, a: Vector3, b: Vector3, d: Vector3) -> float:
	var p0 := a - c
	var p1 := b - c
	var p2 := d - c
	var f0 := p1 - p0
	var f1 := p2 - p1
	var f2 := p0 - p2
	var axes: Array = [u[0], u[1], u[2], f0.cross(f1)]
	for ui in u:
		for f in [f0, f1, f2]:
			axes.append((ui as Vector3).cross(f as Vector3))
	var least := INF
	for ax in axes:
		var n: Vector3 = ax
		var l := n.length()
		if l < 1e-9:
			continue
		n /= l
		var r := e.x * absf(n.dot(u[0])) + e.y * absf(n.dot(u[1])) + e.z * absf(n.dot(u[2]))
		var t0 := n.dot(p0)
		var t1 := n.dot(p1)
		var t2 := n.dot(p2)
		var lo := minf(t0, minf(t1, t2))
		var hi := maxf(t0, maxf(t1, t2))
		var over := minf(r - lo, hi + r)
		if over <= 0.0:
			return 0.0
		least = minf(least, over)
	return least if least < INF else 0.0
