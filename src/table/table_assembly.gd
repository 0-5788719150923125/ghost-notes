extends RefCounted
class_name TableAssembly

## TableAssembly - THE PARTS OF A THING BUILT ON THE TABLE, drawn ([Assembly] is what they do, this is where it is seen): a part of
## [TableWork]. The table's `assembly` stands here over the things as they stood - its plate, each stock's place found on the table
## and what it holds - and every frame the piece in hand is moved. Instanced by kind and size: a tub of a thousand costs what one
## thing costs, and only what moved this frame is written ([method tick]).
##
## A STOCK IN A THING takes its inside from the thing itself, by rays straight down from over it: any open container the set dresser
## built (a tub, a crate, a dish, a tray) holds bricks without being told how it is shaped, and they lie on what is really there. A
## deep one is filled over a false floor, its top few layers all anyone can see ([constant SHOWN_DEEP]) - a tub a dozen layers deep
## would be most of its pieces unseen and every one of them drawn.

## The most a stock's inside looks like, in cells a side, and what a surface must be under its thing's rim to be inside it (meters).
const INSIDE_MOST := 170
const UNDER_RIM := 0.008
## How many cells make an inside at all: fewer, and what was named has no hollow in it.
const INSIDE_LEAST := 12
## How deep a full container's pieces are drawn, under where they reach (meters).
const SHOWN_DEEP := 0.03
## The bed under them, against a mean of what is in it.
const BED_DARK := 0.22
## How far in front of the lens a piece is held up (meters), and how far below the lens's middle.
const VIEW_AHEAD := 0.2
const VIEW_LOW := 0.02
## `aside`: a place on the table beside the plate for what was put down for later (meters).
const ASIDE_R := 0.05
## A camera's distance, for the instances' bounds: they are never culled while anything stands on the table.
const BOUNDS := Vector3(4.0, 3.0, 4.0)

var work: TableWork
var spec := {}
var log: Assembly
var root: Node3D
var _base: MeshInstance3D
var _groups := {}                 # "kind WxD" -> {mm, node, ids}
var _slot: Array = []             # a piece -> [group's key, instance]
var _material: ShaderMaterial
var _last_k := -2
var _last_t := NAN
var _in_step := {}                # pieces the step going last frame was moving
var _built := false


func _init(owner: TableWork, table_spec: Dictionary) -> void:
	work = owner
	spec = table_spec.duplicate(true)


## WHAT STANDS WHERE ON THE TABLE BY THE TABLE'S OWN WRITING, before anything is built: where nothing else may stand ([method
## TableThings.off_limits]) - the plate and each pile on the table, on the table in meters.
static func keep_out(table_spec: Dictionary, at_base: Vector2) -> Array:
	var out: Array = []
	if table_spec.is_empty():
		return out
	var size: Array = (table_spec["base"] as Dictionary)["size"]
	# ...ALL THE WAY ROUND: a plate turned sweeps its diagonal, and what stands inside that gets a corner through it
	var reach := Vector2(float(size[0]), float(size[1])).length() * Assembly.STUD * 0.5 + 0.02
	var half := Vector2(reach, reach)
	out.append(Rect2(at_base - half, half * 2.0))
	for s in table_spec.get("stock", []):
		var sd: Dictionary = s
		if sd.has("at"):
			var c := Vector2(float((sd["at"] as Array)[0]), float((sd["at"] as Array)[1])) * 0.01 + Tables.ORIGIN
			var r := float(sd.get("radius", 12.0)) * 0.01
			out.append(Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0))
	return out


## Where the plate's middle stands, written or in the middle of the picture a little toward the reader (on the table, meters).
static func base_center(table_spec: Dictionary, plan: TablePlan) -> Vector2:
	var b: Dictionary = table_spec.get("base", {})
	if b.has("at"):
		return Vector2(float((b["at"] as Array)[0]), float((b["at"] as Array)[1])) * 0.01 + Tables.ORIGIN
	var fwd := -plan.cam_base.basis.z
	var aim := plan.cam_base.origin + fwd * (-plan.cam_base.origin.y / minf(fwd.y, -0.05))
	return Vector2(aim.x, aim.z + TablePlan.WORK_AHEAD)


## STOOD OVER THE THINGS AS THEY ARE: the plate, each stock's place. The pieces come with the acts ([method perform]).
func stand() -> void:
	root = Node3D.new()
	root.name = "Assembly"
	work._root.add_child(root)
	var plan: TablePlan = work.medium._plan
	var at := base_center(spec, plan)
	var size: Array = (spec["base"] as Dictionary)["size"]
	var colors: Dictionary = spec["colors"]
	var yaw := deg_to_rad(float((spec["base"] as Dictionary).get("turn", 0.0)))
	_material = ShaderMaterial.new()
	_material.shader = preload("res://shaders/plastic.gdshader")
	_base = MeshInstance3D.new()
	_base.mesh = AssemblyMeshes.base_of(int(size[0]), int(size[1]))
	_base.material_override = _plate_material(Color.html(String(colors[String((spec["base"] as Dictionary)["color"])])))
	root.add_child(_base)
	var heaps := {}
	var obstacles: Array = []
	var holders := {}
	var kept: Array = []
	for s in spec.get("stock", []):
		var sd: Dictionary = s
		var heap: AssemblyHeap = _heap_of(sd)
		if heap == null:
			work.notes.append("the stock \"%s\": %s has no open inside to hold pieces" % [String(sd["name"]), String(sd.get("thing", "its place"))])
			continue
		heaps[String(sd["name"])] = heap
		kept.append(sd)
		if not heap.thing.is_empty():
			holders[heap.thing] = true
	spec["stock"] = kept
	heaps["aside"] = _aside_heap(at, size, yaw)
	for ti in work.things.size():
		var th: Dictionary = work.things[ti]
		var box: AABB = work._world_rest_thing(ti) * (th["box"] as AABB)
		obstacles.append({"box": box, "name": String(th["name"])})
	var fwd := -plan.cam_base.basis.z
	var view := plan.cam_base.origin + fwd * VIEW_AHEAD + plan.cam_base.basis.y * -VIEW_LOW
	var w := {"base_at": Vector3(at.x, 0.0, at.y), "yaw": yaw, "heaps": heaps, "obstacles": obstacles, "view": view}
	log = Assembly.new()
	log.spec = spec
	log.seed_value = hash([plan.seed_value, "assembly"])
	log.world = w
	_base.transform = log.base_xf(yaw)
	_beds(heaps)


## Whether thing [param name] holds a stock: it stands where it was built, what is in it does not go with it.
func holds_stock(name: String) -> bool:
	if log == null:
		return false
	for k in (log.world["heaps"] as Dictionary):
		if ((log.world["heaps"] as Dictionary)[k] as AssemblyHeap).thing == name:
			return true
	return false


static func _plate_material(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.34
	m.metallic_specular = 0.5
	return m


## The stock [param sd]'s place: a pile as written, or what is inside its thing as rays straight down find it - null when it has none.
func _heap_of(sd: Dictionary) -> AssemblyHeap:
	var name := String(sd["name"])
	if sd.has("at"):
		var c := Vector2(float((sd["at"] as Array)[0]), float((sd["at"] as Array)[1])) * 0.01 + Tables.ORIGIN
		var h := AssemblyHeap.pile(name, c, float(sd.get("radius", 12.0)) * 0.01)
		return h
	var ti: int = work._thing_named(String(sd.get("thing", "")))
	if ti < 0:
		work.notes.append("the stock \"%s\" names no thing on the table" % name)
		return null
	var th: Dictionary = work.things[ti]
	var box: AABB = work._world_rest_thing(ti) * (th["box"] as AABB)
	var rim_y := box.end.y
	var cell := AssemblyHeap.CELL
	var cols := mini(int(ceil(box.size.x / cell)) + 1, INSIDE_MOST)
	var rows := mini(int(ceil(box.size.z / cell)) + 1, INSIDE_MOST)
	var from := Vector2(box.position.x, box.position.z)
	var heights := PackedFloat32Array()
	heights.resize(cols * rows)
	var thing_name := String(th["name"])
	var low := INF
	var low_at := -1
	for j in rows:
		for i in cols:
			var p := Vector3(from.x + float(i) * cell, rim_y + 0.01, from.y + float(j) * cell)
			var y := _down_on(ti, p)
			heights[j * cols + i] = y
			if not is_nan(y) and y < low - 1e-4:
				low = y
				low_at = j * cols + i
	if low_at < 0 or rim_y - low < UNDER_RIM:
		return null
	# THE INSIDE: flooded from its lowest place through what lies under the rim - never what is round it, past its walls
	var seen := {}
	var open: Array = [low_at]
	seen[low_at] = true
	while not open.is_empty():
		var c: int = open.pop_back()
		var i := c % cols
		var j := c / cols
		for next in [[i + 1, j], [i - 1, j], [i, j + 1], [i, j - 1]]:
			var ni := int(next[0])
			var nj := int(next[1])
			if ni < 0 or nj < 0 or ni >= cols or nj >= rows:
				continue
			var nc := nj * cols + ni
			if seen.has(nc):
				continue
			var y := heights[nc]
			if is_nan(y) or y > rim_y - UNDER_RIM:
				continue
			seen[nc] = true
			open.append(nc)
	if seen.size() < INSIDE_LEAST:
		return null
	var ground := PackedFloat32Array()
	ground.resize(cols * rows)
	ground.fill(NAN)
	var sum := 0.0
	for c in seen:
		ground[int(c)] = heights[int(c)]
		sum += heights[int(c)]
	# A FALSE FLOOR, under the pieces as full as it was written: what is further down than anyone sees is not there
	var floor_mean := sum / float(seen.size())
	var fill := float(sd.get("fill", 0.85))
	var reach_to := lerpf(floor_mean, rim_y, fill)
	var bed := reach_to - SHOWN_DEEP
	var heap := AssemblyHeap.inside(name, from, cols, rows, ground, rim_y)
	if bed > floor_mean + 0.004:
		heap.bed = bed
		for c in seen:
			heap.ground[int(c)] = maxf(heap.ground[int(c)], bed)
	heap.thing = thing_name
	return heap


## The surface of thing [param ti] straight under [param p] (the table's space): NAN where it is not over the thing.
func _down_on(ti: int, p: Vector3) -> float:
	var tm: TriangleMesh = work._mesh_of(ti)
	if tm == null:
		return NAN
	var hit: Dictionary = TableWork._ray(tm, p, Vector3.DOWN)
	return NAN if hit.is_empty() else float((hit["position"] as Vector3).y)


## `aside`: a small pile on the table beside the plate, on the reader's right unless the plate is hard against that side.
func _aside_heap(at: Vector2, size: Array, yaw: float) -> AssemblyHeap:
	var half := Vector2(float(size[0]), float(size[1])) * Assembly.STUD * 0.5
	var out := (absf(cos(yaw)) * half.x + absf(sin(yaw)) * half.y) + ASIDE_R + 0.015
	var c := at + Vector2(out, 0.02)
	return AssemblyHeap.pile("aside", c, ASIDE_R)


## THE FALSE FLOORS, drawn: a dark surface under the pieces, in what the pieces leave showing. Cell by cell over what is inside.
func _beds(heaps: Dictionary) -> void:
	for k in heaps:
		var heap: AssemblyHeap = heaps[k]
		if is_nan(heap.bed):
			continue
		var verts := PackedVector3Array()
		var norms := PackedVector3Array()
		var cell := AssemblyHeap.CELL
		for j in heap.nz:
			for i in heap.nx:
				if is_nan(heap.ground[j * heap.nx + i]):
					continue
				var c := heap.origin + Vector2(i, j) * cell
				var h := cell * 0.5
				var y := heap.bed - 0.0005
				for q in [Vector3(c.x - h, y, c.y - h), Vector3(c.x + h, y, c.y - h), Vector3(c.x - h, y, c.y + h),
						Vector3(c.x + h, y, c.y - h), Vector3(c.x + h, y, c.y + h), Vector3(c.x - h, y, c.y + h)]:
					verts.append(q)
					norms.append(Vector3.UP)
		if verts.is_empty():
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = norms
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var mi := MeshInstance3D.new()
		mi.mesh = m
		var mat := StandardMaterial3D.new()
		mat.albedo_color = _mean_color() * BED_DARK
		mat.roughness = 0.8
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)


func _mean_color() -> Color:
	var sum := Color(0.0, 0.0, 0.0, 1.0)
	var n := 0
	for k in (spec["colors"] as Dictionary):
		var c := Color.html(String((spec["colors"] as Dictionary)[k]))
		sum.r += c.r
		sum.g += c.g
		sum.b += c.b
		n += 1
	return Color(sum.r / float(maxi(n, 1)), sum.g / float(maxi(n, 1)), sum.b / float(maxi(n, 1)))


## THE BUILD: acts [param acts] walked ([method Assembly.perform]) and every piece they come to drawn where it begins. Each act gets
## what it was found to come to, so the schedule knows what it asks.
func perform(acts: Array) -> void:
	if log == null:
		return
	var order := _in_reading_order(acts)
	var script: Array = []
	for a in order:
		script.append({"name": String((a as Dictionary)["name"]), "ops": _ops_of(a as Dictionary)})
	log.perform(script)
	for a in acts:
		var ad: Dictionary = a
		if not _has_ops(ad):
			continue
		var nm := String(ad["name"])
		ad["_natural"] = maxf(log.natural_of(nm), 0.5)
		ad["_min_length"] = maxf(log.floor_of(nm), 0.5)
		ad["length"] = ad["_natural"]
	_draw_pieces()
	_last_k = -2
	_last_t = NAN


static func _has_ops(a: Dictionary) -> bool:
	for t in a["tracks"]:
		if String((t as Dictionary).get("law", "")) == "assemble":
			return true
	return false


static func _ops_of(a: Dictionary) -> Array:
	var out: Array = []
	for t in a["tracks"]:
		if String((t as Dictionary).get("law", "")) == "assemble":
			out.append_array((t as Dictionary).get("ops", []))
	return out


## The acts that build, as the reading comes to them: the intro's, each beat's, the close's - in the order written within each.
static func _in_reading_order(acts: Array) -> Array:
	var out: Array = []
	var most := 0
	for a in acts:
		var b := String((a as Dictionary)["beat"])
		if b.is_valid_int():
			most = maxi(most, int(b))
	for beat in ["intro"] + range(1, most + 1).map(func(k: int) -> String: return str(k)) + ["close"]:
		for a in acts:
			if String((a as Dictionary)["beat"]) == String(beat) and _has_ops(a as Dictionary):
				out.append(a)
	return out


func _draw_pieces() -> void:
	for k in _groups:
		((_groups[k] as Dictionary)["node"] as Node).queue_free()
	_groups = {}
	_slot = []
	_slot.resize(log.pieces.size())
	var by: Dictionary = {}
	for id in log.pieces.size():
		var q: Dictionary = log.pieces[id]
		var key := "%s %dx%d" % [String(q["kind"]), int(q["w"]), int(q["d"])]
		if not by.has(key):
			by[key] = []
		(by[key] as Array).append(id)
	var colors: Dictionary = spec["colors"]
	var linear := {}
	for k in colors:
		linear[k] = Color.html(String(colors[k])).srgb_to_linear()
	for key in by:
		var ids: Array = by[key]
		var first: Dictionary = log.pieces[int(ids[0])]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = AssemblyMeshes.mesh_of(String(first["kind"]), int(first["w"]), int(first["d"]))
		mm.instance_count = ids.size()
		var node := MultiMeshInstance3D.new()
		node.multimesh = mm
		node.material_override = _material
		node.custom_aabb = AABB(-BOUNDS * 0.5, BOUNDS)
		root.add_child(node)
		_groups[key] = {"mm": mm, "node": node}
		for i in ids.size():
			var id := int(ids[i])
			_slot[id] = [mm, i]
			var q: Dictionary = log.pieces[id]
			# ...each a shade its own: parts of different ages in one lot
			var hs := hash([log.seed_value, id])
			var worn := Hands.share(hs, 1)
			var c: Color = linear.get(String(q["color"]), Color.GRAY)
			var shade := lerpf(0.94, 1.05, Hands.share(hs, 2))
			mm.set_instance_color(i, Color(c.r * shade, c.g * shade, c.b * shade, 1.0))
			mm.set_instance_custom_data(i, Color(worn, 0.0, 0.0, 0.0))
			mm.set_instance_transform(i, ((q["rests"] as Array)[0] as Array)[2] if not (q["rests"] as Array).is_empty() else Transform3D.IDENTITY)
	_built = true


## THE ACTS PLACED IN TIME ([method Assembly.lay]), what is under way left alone.
func lay(runs: Array, acts: Array, now: float) -> void:
	if log == null:
		return
	log.lay(runs, acts, now)
	_last_k = -2


## THE FRAME AT [param t]: only what the going step moves, and when the step changes what the last one left - every piece after a
## jump in time, and while the plate turns, every piece on it.
func tick(t: float) -> void:
	if log == null or not _built or log.steps.is_empty():
		return
	var k := log.step_at(t)
	var yaw := log.yaw_at(t, k)
	var jumped := _last_k == -2 or is_nan(_last_t) or absf(t - _last_t) > 0.5 or k < _last_k or k > _last_k + 12
	if jumped:
		_pose_all(t, k, yaw)
	else:
		# what the steps since the last frame moved, where they left it
		for done in range(maxi(_last_k, 0), k):
			_pose_moved(done, t, k, yaw)
		if k >= 0:
			_pose_moved(k, t, k, yaw)
			if (log.steps[k] as Dictionary).has("yaw") and t <= log._t1[k] + 0.1:
				_pose_on_plate(t, k, yaw)
	_base.transform = log.base_xf(yaw)
	_last_k = k
	_last_t = t


func _pose_moved(step: int, t: float, k: int, yaw: float) -> void:
	for mv in (log.steps[step] as Dictionary)["moves"]:
		var id := int((mv as Dictionary)["id"])
		_write(id, log.pose_of(id, t, k, yaw))


func _pose_on_plate(t: float, k: int, yaw: float) -> void:
	for id in log.pieces.size():
		var rests: Array = (log.pieces[id] as Dictionary)["rests"]
		if rests.is_empty():
			continue
		_write(id, log.pose_of(id, t, k, yaw))


func _pose_all(t: float, k: int, yaw: float) -> void:
	for id in log.pieces.size():
		_write(id, log.pose_of(id, t, k, yaw))


func _write(id: int, xf: Transform3D) -> void:
	var s: Array = _slot[id]
	(s[0] as MultiMesh).set_instance_transform(int(s[1]), xf)


# --- the words -------------------------------------------------------------------------------------

## THE TABLE'S ASSEMBLY, as a puppeteer reads it: the plate, the stocks, and the model as it stands now.
func report() -> String:
	if log == null:
		return ""
	var lines := PackedStringArray()
	var size: Array = (spec["base"] as Dictionary)["size"]
	var at: Vector3 = log.world["base_at"]
	lines.append("THE ASSEMBLY: a plate of %d x %d studs at [%.0f, %.0f] cm, its studs numbered x 0-%d left to right, z 0-%d far to near." % [int(size[0]), int(size[1]),
		(at.x - Tables.ORIGIN.x) * 100.0, (at.z - Tables.ORIGIN.y) * 100.0, int(size[0]) - 1, int(size[1]) - 1])
	lines.append("Its colors: %s." % ", ".join(PackedStringArray((spec["colors"] as Dictionary).keys())))
	lines.append("What the pieces come out of and go back into, with \"aside\", a small pile beside the plate:")
	var heaps: Dictionary = log.world["heaps"]
	for k in heaps:
		var heap: AssemblyHeap = heaps[k]
		var n := (log._fillers.get(String(k), []) as Array).size()
		if String(k) == "aside":
			continue
		lines.append("- \"%s\": %s, %d pieces to begin with" % [String(k), ("in " + heap.thing) if not heap.thing.is_empty() else ("a pile at [%.0f, %.0f] cm" % [(heap.middle.x - Tables.ORIGIN.x) * 100.0, (heap.middle.y - Tables.ORIGIN.y) * 100.0]), n])
	lines.append("Any part you ask for will be there: a stock is never short of one.")
	return "\n".join(lines)


## What is heard between [param t0] and [param t1] ([method Assembly.sounds_in]).
func sounds_in(t0: float, t1: float) -> Array:
	return [] if log == null or not _built else log.sounds_in(t0, t1)
