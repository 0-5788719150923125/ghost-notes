extends RefCounted
class_name TableAssembly

## TableAssembly - the parts of a thing built on the table, drawn: a part of [TableWork]. The table's `assembly` stands
## here over the things as they stood: its plate, each stock's place found on the table and what it holds. Instanced
## by kind and size (a tub of a thousand costs what one thing costs), and only what moved is written ([method tick]).
##
## What the bricks do is recorded, then played ([method behind]): real bodies in a second process ([AssemblyBake]),
## which starts when a show first wants them and whose stretches land here as they are written ([AssemblyTrack]). A
## show waits only for what it has reached. A record is named by everything it depends on and kept ([method
## _start_bake]), so a note opened again costs nothing and a new act costs what comes after it. A preview asks for no
## record: it sees where things rest ([method Assembly.pose_of]).
##
## A stock in a thing takes its inside from the thing itself, by rays straight down from over it: any open container
## the set dresser built (a tub, a crate, a dish, a tray) holds bricks without being told its shape. A deep one is
## filled over a false floor, deep enough to be dug in ([constant Assembly.IN_DEEP]), so the pieces never run to a
## body each for a dozen unseen layers.

## The most a stock's inside looks like, in cells a side, and what a surface must be under its thing's rim to be inside it (meters).
const INSIDE_MOST := 170
const UNDER_RIM := 0.008
## How many cells make an inside at all: fewer, and what was named has no hollow in it.
const INSIDE_LEAST := 12
## The bed under them, against a mean of what is in it.
const BED_DARK := 0.22
## `aside`: a place on the table beside the plate for what was put down for later (meters).
const ASIDE_R := 0.05
## A camera's distance, for the instances' bounds: they are never culled while anything stands on the table.
const BOUNDS := Vector3(4.0, 3.0, 4.0)
## A record's name changes when this does: what the world does is the same given the same of everything else ([method _world_key]).
const BAKE_VERSION := 1
## How many records are kept, the oldest gone first ([method _start_bake]).
const BAKES_KEPT := 24
## How far ahead of the show the record must be, for it not to wait (seconds), and for it to go on once it has waited; and how long between looks at
## what has landed (ms).
const WAIT_UNDER := 1.0
const WAIT_AHEAD := 6.0
const LOOK_EVERY := 250
## A window of sound never holds more hits than this, the hardest kept: past a few at once nobody hears another.
const HITS_AT_ONCE := 6
## Where records are kept in a process that may not write the user's things. A gate may set its own ([member bake_root]).
const PROBE_BAKES := "res://dist/assembly_bakes"
static var bake_root := ""
## A gate's way to a show that plays while its record is made: everything else that runs from tests/ waits for all of it.
static var live_in_tests := false
## A probe's way to where the plan has things, with no record made at all, as a preview sees them: for what is built as it stands, in moments.
static var plan_only := false

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
var _last_tau := NAN
var _built := false
var track: AssemblyTrack          # what has landed of the record ([method behind]; null until a show asks)
var _dir := ""
var _names := PackedInt64Array()
var _next := 0                    # the first step not yet on [member track]
var _pid := -1
var _bake_started := false
var _bake_whole := false
var _bake_failed := false
var _behind := false
var _looked := 0
var _landing := -1
var _landed: Variant = null
var _mutex := Mutex.new()
var _runs: Array = []
var _acts: Array = []
var _in_hand := -1                # the piece [Fingers] drew last frame, or -1


func _init(owner: TableWork, table_spec: Dictionary) -> void:
	work = owner
	spec = table_spec.duplicate(true)


## What stands where on the table by the table's own writing, before anything is built: where nothing else may stand ([method
## TableThings.off_limits]) - the plate and each pile on the table, on the table in meters.
static func keep_out(table_spec: Dictionary, at_base: Vector2) -> Array:
	var out: Array = []
	if table_spec.is_empty():
		return out
	var size: Array = (table_spec["base"] as Dictionary)["size"]
	# All the way round: a plate turned sweeps its diagonal, and what stands inside that gets a corner through it
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
	return base_center_under(table_spec, plan.cam_base)


## ...for a lens at [param cam].
static func base_center_under(table_spec: Dictionary, cam: Transform3D) -> Vector2:
	var b: Dictionary = table_spec.get("base", {})
	if b.has("at"):
		return Vector2(float((b["at"] as Array)[0]), float((b["at"] as Array)[1])) * 0.01 + Tables.ORIGIN
	var fwd := -cam.basis.z
	var aim := cam.origin + fwd * (-cam.origin.y / minf(fwd.y, -0.05))
	return Vector2(aim.x, aim.z + TablePlan.WORK_AHEAD)


## How far the top of the model rises past what the lens sees whole, where the plate stands (meters; 0 or less: all of it is seen), part by part: a tower at the far end of a plate is cut where the same tower at its near end is not.
static func model_cut_by(table_spec: Dictionary, cam: Transform3D, fov: float) -> float:
	var m: Dictionary = table_spec.get("model", {}) if table_spec.get("model") is Dictionary else {}
	if m.is_empty():
		return 0.0
	var at := base_center_under(table_spec, cam)
	var yaw := deg_to_rad(float((table_spec["base"] as Dictionary).get("turn", 0.0)))
	var size: Array = m["size"]
	var most := -INF
	for p in m["parts"]:
		var q: Dictionary = p
		var l := Vector3((float(q["x"]) - float(size[0]) * 0.5) * Assembly.STUD, 0.0, (float(q["z"]) - float(size[1]) * 0.5) * Assembly.STUD)
		var w := Basis(Vector3.UP, yaw) * l
		var top := float(int(q["l"]) + int((Assembly.KINDS[String(q["kind"])] as Dictionary)["h"])) * Assembly.PLATE
		most = maxf(most, top - CardTable.headroom_at(cam, fov, at + Vector2(w.x, w.z)))
	return most


## Stood over the things as they are: the plate, each stock's place. The pieces come with the acts ([method perform]).
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
	for ti in work.things.size():
		var th: Dictionary = work.things[ti]
		var box: AABB = work._world_rest_thing(ti) * (th["box"] as AABB)
		obstacles.append({"box": box, "name": String(th["name"])})
	heaps["aside"] = _aside_heap(at, size, yaw, obstacles, heaps)
	var w := {"base_at": Vector3(at.x, 0.0, at.y), "yaw": yaw, "heaps": heaps, "obstacles": obstacles, "lens": plan.cam_base, "fov": plan.fov}
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
	# The inside: flooded from its lowest place through what lies under the rim, never what is round it past its walls
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
	# A false floor under the pieces, as full as it was written: what is further down than anyone sees is not there
	var floor_mean := sum / float(seen.size())
	var fill := float(sd.get("fill", 0.85))
	var reach_to := lerpf(floor_mean, rim_y, fill)
	var area := float(seen.size()) * cell * cell
	var holds := int(sd.get("count", Assembly.count_for(area, true, reach_to - floor_mean)))
	var bed := reach_to - float(holds) / (area * Assembly.PER_M3)
	var heap := AssemblyHeap.inside(name, from, cols, rows, ground, rim_y)
	heap.thing = thing_name
	heap.deep = reach_to - floor_mean
	if bed > floor_mean + 0.004:
		heap.bed = bed
		for c in seen:
			heap.ground[int(c)] = maxf(heap.ground[int(c)], bed)
	return heap


## The surface of thing [param ti] straight under [param p] (the table's space): NAN where it is not over the thing.
func _down_on(ti: int, p: Vector3) -> float:
	var tm: TriangleMesh = work._mesh_of(ti)
	if tm == null:
		return NAN
	var hit: Dictionary = TableWork._ray(tm, p, Vector3.DOWN)
	return NAN if hit.is_empty() else float((hit["position"] as Vector3).y)


## `aside`: a small pile on the table beside the plate, where the table is clear of what stands on it: on the reader's
## right, else their left, else nearer them. What is put aside really falls and lies there.
func _aside_heap(at: Vector2, size: Array, yaw: float, obstacles: Array, heaps: Dictionary) -> AssemblyHeap:
	var half := Vector2(float(size[0]), float(size[1])) * Assembly.STUD * 0.5
	var across := absf(cos(yaw)) * half.x + absf(sin(yaw)) * half.y + ASIDE_R + 0.015
	var deep := absf(sin(yaw)) * half.x + absf(cos(yaw)) * half.y + ASIDE_R + 0.015
	var places: Array[Vector2] = [at + Vector2(across, 0.02), at + Vector2(-across, 0.02), at + Vector2(0.0, deep), at + Vector2(across, deep), at + Vector2(-across, deep)]
	for c in places:
		var clear := true
		for ob in obstacles:
			var box: AABB = (ob as Dictionary)["box"]
			var r := ASIDE_R + 0.012
			if c.x > box.position.x - r and c.x < box.end.x + r and c.y > box.position.z - r and c.y < box.end.z + r:
				clear = false
				break
		for k in heaps:
			var other: AssemblyHeap = heaps[k]
			if other.thing.is_empty() and c.distance_to(other.middle) < other.reach + ASIDE_R:
				clear = false
		if clear:
			return AssemblyHeap.pile("aside", c, ASIDE_R)
	return AssemblyHeap.pile("aside", places[0], ASIDE_R)


## The false floors, drawn: a dark surface under the pieces, in what the pieces leave showing.
func _beds(heaps: Dictionary) -> void:
	for k in heaps:
		var heap: AssemblyHeap = heaps[k]
		if is_nan(heap.bed):
			continue
		var verts := _bed_faces(heap)
		if verts.is_empty():
			continue
		var norms := PackedVector3Array()
		norms.resize(verts.size())
		norms.fill(Vector3.UP)
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


## A false floor as triangles, cell by cell over what is inside: what is drawn, and what the pieces land on.
static func _bed_faces(heap: AssemblyHeap) -> PackedVector3Array:
	var verts := PackedVector3Array()
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
	return verts


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


## The build: acts [param acts] walked ([method Assembly.perform]) and every piece they come to drawn where it begins. Each act gets
## what it was found to come to, so the schedule knows what it asks.
func perform(acts: Array) -> void:
	if log == null:
		return
	var order := _in_reading_order(acts)
	var script: Array = []
	for a in order:
		script.append({"name": String((a as Dictionary)["name"]), "ops": _ops_of(a as Dictionary)})
	_stop_bake()
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
	_last_tau = NAN
	track = null
	_next = 0
	_names = PackedInt64Array()
	_bake_whole = false
	_bake_failed = false
	# ...a show already playing goes on from whatever of it is the same
	if _bake_started:
		_bake_started = false
		_start_bake()


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


## The acts placed in time ([method Assembly.lay]), what is under way left alone.
func lay(runs: Array, acts: Array, now: float) -> void:
	if log == null:
		return
	_runs = runs
	_acts = acts
	log.lay(runs, acts, now)
	_last_k = -2


# --- the record -----------------------------------------------------------------------------------------------------

## Whether the show must wait for the bricks at [param t]: asking starts the record. In a render it is waited for here, whole: a render's frames
## must be the show's. Called only by a table on the stage, so a preview never starts one.
func behind(t: float) -> bool:
	if plan_only or log == null or not _built or log.pieces.is_empty():
		return false
	if not _bake_started:
		_start_bake()
	if _sync():
		_wait_whole()
		return false
	_pump()
	if _bake_failed or _bake_whole:
		return false
	if track == null or not track.stock_ready:
		_behind = true
		return true
	var ahead := log.step_at(t + (WAIT_AHEAD if _behind else WAIT_UNDER))
	_behind = ahead >= track.baked_to and track.baked_to < log.steps.size()
	return _behind


## How far ahead of [param t] the record reaches (seconds).
func ready_to(t: float) -> float:
	if log == null or track == null or not _bake_started:
		return t
	if track.baked_to >= log.steps.size():
		return INF
	return log._t0[track.baked_to] if track.baked_to >= 0 and track.baked_to < log._t0.size() else t


func _sync() -> bool:
	if live_in_tests:
		return false
	return work.medium == null or not work.medium.is_inside_tree() or TablePhysics.render_waits()


## What the record is called: everything it depends on, the table it stands on, the pieces it has, the seed - and what it does, the code.
func _world_key() -> int:
	var parts: Array = [BAKE_VERSION, log.seed_value, var_to_str(spec), var_to_str(log.world["base_at"]), var_to_str(log.world["yaw"]), var_to_str(log.world["lens"]), var_to_str(log.world["fov"])]
	for path in ["res://src/table/assembly_bake.gd", "res://src/table/assembly_world.gd"]:
		var sc := load(path) as Script
		parts.append(sc.source_code.hash() if sc != null else 0)
	for ti in work.things.size():
		var tm: TriangleMesh = work._mesh_of(ti)
		parts.append(hash(tm.get_faces().to_byte_array()) if tm != null else 0)
	for p in log.pieces:
		parts.append(Assembly.part_key(p as Dictionary))
		parts.append(String((p as Dictionary)["stock"]))
	return hash(parts) & 0x7FFFFFFFFFFFFFFF


static func _root_of_bakes() -> String:
	if not bake_root.is_empty():
		return bake_root
	# A test's own, as [method TablePhysics.render_waits] knows one, named without the autoload a gate's first compile has not got yet
	var probe := false
	for a in OS.get_cmdline_args():
		if a.trim_prefix("res://").begins_with("tests/"):
			probe = true
	return ProjectSettings.globalize_path(PROBE_BAKES if probe else "user://assembly_bakes")


## The record begun, or gone on from: a process of its own, handed the table's shapes and every step. What is already there is simply read.
func _start_bake() -> void:
	_bake_started = true
	_bake_failed = false
	track = AssemblyTrack.new(log.pieces.size())
	var key := _world_key()
	_names = log.step_names(key)
	var root_dir := _root_of_bakes()
	_dir = root_dir.path_join("%016x" % key)
	DirAccess.make_dir_recursive_absolute(_dir)
	_prune(root_dir)
	_next = 0
	while _land_next(true):
		pass
	if track.stock_ready and _next >= log.steps.size():
		_bake_whole = true
		_after_landing()
		return
	_after_landing()
	var req_path := _dir.path_join("request.bin")
	var f := FileAccess.open(req_path, FileAccess.WRITE)
	if f == null:
		push_warning("assembly: cannot write %s" % req_path)
		_bake_failed = true
		return
	f.store_buffer(var_to_bytes(_request()))
	f.close()
	var args: PackedStringArray = Subprocess.own_log("assembly_bake") + _project_args() + PackedStringArray(["--headless", "--fixed-fps", str(AssemblyWorld.TICKS),
		"--script", "res://src/table/assembly_bake.gd", "--", req_path])
	_pid = Subprocess.start(OS.get_executable_path(), args, "bricks")
	if _pid <= 0:
		push_warning("assembly: the record could not be started")
		_bake_failed = true


## Where a second ghost finds this project: as [method Boot.project_args] says, in a script a gate may compile before that autoload stands.
static func _project_args() -> PackedStringArray:
	return PackedStringArray(["--path", ProjectSettings.globalize_path("res://")]) if OS.has_feature("editor") else PackedStringArray()


## Only so many records stay: each a show's whole hour of motion.
static func _prune(root_dir: String) -> void:
	var dirs := DirAccess.get_directories_at(root_dir)
	if dirs.size() <= BAKES_KEPT:
		return
	var by_age: Array = []
	for d in dirs:
		by_age.append([FileAccess.get_modified_time(root_dir.path_join(d).path_join("request.bin")), d])
	by_age.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
	for i in by_age.size() - BAKES_KEPT:
		var old := root_dir.path_join(String((by_age[i] as Array)[1]))
		for f in DirAccess.get_files_at(old):
			DirAccess.remove_absolute(old.path_join(f))
		DirAccess.remove_absolute(old)


## What the record needs, all of it plain data: no node crosses to the other process. [param solids] each `{faces (meters), sound}`, what stands on the table.
static func request_of(log: Assembly, table_spec: Dictionary, solids: Array, dir: String, names: PackedInt64Array) -> Dictionary:
	var pieces: Array = []
	var stock_of := PackedStringArray()
	for p in log.pieces:
		var q: Dictionary = p
		pieces.append({"kind": String(q["kind"]), "w": int(q["w"]), "d": int(q["d"]), "color": String(q["color"])})
		stock_of.append(String(q["stock"]))
	var stocks := {}
	var heaps: Dictionary = log.world["heaps"]
	for k in heaps:
		var heap: AssemblyHeap = heaps[k]
		var inside := not heap.thing.is_empty()
		var area := float(heap.area_cells()) * AssemblyHeap.CELL * AssemblyHeap.CELL
		var low := INF
		for v in heap.ground:
			if not is_nan(v):
				low = minf(low, v)
		var sd := {"middle": heap.middle, "thing": heap.thing, "radius": sqrt(area / PI) if inside else heap.reach, "floor": low if low < INF else 0.0,
			"origin": heap.origin, "nx": heap.nx, "nz": heap.nz, "ground": heap.ground}
		if not is_nan(heap.bed):
			sd["bed_faces"] = _bed_faces(heap)
		stocks[String(k)] = sd
	var obstacles: Array = []
	for ob in log.world.get("obstacles", []):
		obstacles.append((ob as Dictionary)["box"])
	return {"dir": dir, "seed": log.seed_value, "base_at": log.world["base_at"], "yaw": log.world["yaw"], "base_size": (table_spec["base"] as Dictionary)["size"], "lens": log.world["lens"], "fov": log.world["fov"],
		"pieces": pieces, "stock_of": stock_of, "stocks": stocks, "solids": solids, "obstacles": obstacles, "steps": log.steps, "keys": names}


func _request() -> Dictionary:
	var solids: Array = []
	for ti in work.things.size():
		var tm: TriangleMesh = work._mesh_of(ti)
		if tm != null:
			var faces := tm.get_faces()
			for i in faces.size():
				faces[i] = faces[i] / TableWork.RAY_SCALE
			solids.append({"faces": faces, "sound": _sound_of(ti), "thing": String((work.things[ti] as Dictionary)["name"])})
	var out := request_of(log, spec, solids, _dir, _names)
	# The table as it is drawn: what goes past its edge falls off it
	if work.medium != null and work.medium._top is Dictionary and not (work.medium._top as Dictionary).is_empty():
		out["top"] = Tables.top_outline(work.medium._top)
	return out


## Where what is built here ever stands: the middle of the plate (x, z), how far round it the plate reaches however it is turned, and how high anything on it comes (meters). A thing an act moves is [TablePhysics]'s
## and the bricks are not, so this is all such a thing can know of them.
func built_reach() -> Dictionary:
	var size: Array = (spec["base"] as Dictionary)["size"]
	var at: Vector3 = log.world["base_at"]
	var most := 0.0
	for st in log.steps:
		var q: Dictionary = st
		if String(q["do"]) == "put":
			most = maxf(most, float(int(q["l"]) + int((Assembly.KINDS[String(q["key"]).get_slice(" ", 0)] as Dictionary)["h"])) * Assembly.PLATE)
	return {"at": Vector2(at.x, at.z), "reach": Vector2(float(size[0]), float(size[1])).length() * Assembly.STUD * 0.5, "top": Assembly.BASE_T + most + Assembly.STUD_H}


## What thing [param ti] sounds like when something hits it: what it is made of ([constant Props.MATERIALS]).
func _sound_of(ti: int) -> String:
	for m in (work.things[ti] as Dictionary)["meshes"]:
		var mat := (m as MeshInstance3D).material_override as ShaderMaterial if m is MeshInstance3D else null
		if mat != null and mat.get_shader_parameter("kind") != null:
			var code := int(mat.get_shader_parameter("kind"))
			for k in Props.MATERIALS:
				if int((Props.MATERIALS[k] as Dictionary)["code"]) == code:
					return String(k)
	return "painted"


## The next stretch there is, read and added: false when there is none. [param now]: on this thread, as a record is first opened and in a render;
## otherwise on a worker ([method _pump]), and a frame only pays for adding it.
func _land_next(now: bool) -> bool:
	if not track.stock_ready:
		var f := _dir.path_join("stock.seg")
		if not FileAccess.file_exists(f):
			return false
		var d: Variant = bytes_to_var(FileAccess.get_file_as_bytes(f))
		track.add_stock((d as Dictionary)["rest"])
		_last_tau = NAN
		return true
	if not now:
		return false
	var path := _next_file()
	if path.is_empty():
		return false
	_take_stretch(bytes_to_var(FileAccess.get_file_as_bytes(path)))
	return true


## Where the next stretch is, if it is there. A stretch is named by the step it reached, so the steps after the last are looked at in turn.
func _next_file() -> String:
	if _next >= _names.size():
		return ""
	var have := DirAccess.get_files_at(_dir)
	var names := {}
	for f in have:
		names[f] = true
	for k in range(_next, _names.size()):
		var name := "%016x.seg" % _names[k]
		if names.has(name):
			return _dir.path_join(name)
	return ""


func _take_stretch(seg: Variant) -> void:
	if not (seg is Dictionary):
		return
	var d: Dictionary = seg
	track.add_stretch(d)
	for st in d["steps"]:
		log.take_record(int((st as Dictionary)["k"]), st as Dictionary)
	_next = int(d["to"])
	if _next >= log.steps.size():
		_bake_whole = true


func _after_landing() -> void:
	if not _acts.is_empty():
		var now := _last_t if not is_nan(_last_t) else -INF
		log.lay(_runs, _acts, now)
	_last_tau = NAN


## What has landed since, read on a worker and added here. The app never waits on a disk.
func _pump() -> void:
	if not _bake_started or _bake_whole or _bake_failed or track == null:
		return
	_mutex.lock()
	var got: Variant = _landed
	_landed = null
	_mutex.unlock()
	if got != null:
		WorkerThreadPool.wait_for_task_completion(_landing)
		_landing = -1
		_take_stretch(got)
		_after_landing()
	var clock := Time.get_ticks_msec()
	if _landing >= 0 or clock - _looked < LOOK_EVERY:
		return
	_looked = clock
	if not track.stock_ready:
		if _land_next(false):
			_after_landing()
	else:
		var path := _next_file()
		if not path.is_empty():
			_landing = WorkerThreadPool.add_task(_read_stretch.bind(path), false, "a stretch of the bricks' record")
			return
	if _pid > 0 and not Subprocess.alive(_pid) and not _bake_whole and _next_file().is_empty() and _landing < 0:
		if track.stock_ready and _next >= log.steps.size():
			_bake_whole = true
		else:
			push_warning("assembly: the record stopped at step %d of %d (user://logs/assembly_bake.log)" % [_next, log.steps.size()])
			_bake_failed = true


func _read_stretch(path: String) -> void:
	var v: Variant = bytes_to_var(FileAccess.get_file_as_bytes(path))
	_mutex.lock()
	_landed = v
	_mutex.unlock()


## All of it, here and now: a render, and a gate.
func _wait_whole() -> void:
	if _bake_whole or _bake_failed:
		return
	while true:
		while _land_next(true):
			pass
		if track.stock_ready and _next >= log.steps.size():
			_bake_whole = true
			break
		if _pid <= 0 or not Subprocess.alive(_pid):
			while _land_next(true):
				pass
			_bake_whole = track.stock_ready and _next >= log.steps.size()
			_bake_failed = not _bake_whole
			if _bake_failed:
				push_warning("assembly: the record stopped at step %d of %d" % [_next, log.steps.size()])
			break
		OS.delay_msec(100)
	_after_landing()


func _stop_bake() -> void:
	if _landing >= 0:
		WorkerThreadPool.wait_for_task_completion(_landing)
		_landing = -1
		_landed = null
	if _pid > 0 and Subprocess.alive(_pid):
		Subprocess.stop(_pid)
	_pid = -1


## The table gone: so is what was working for it. What it wrote stays, for when it is opened again.
func clear() -> void:
	_stop_bake()


# --- a frame --------------------------------------------------------------------------------------------------------

## The frame at [param t]: what the record has moved since the last frame, every piece after a jump in time, and while the plate turns, what is on it. With
## no record (a preview), where the plan has things at rest.
func tick(t: float) -> void:
	if log == null or not _built or log.steps.is_empty():
		_pump_only()
		return
	_pump()
	if track != null and track.stock_ready:
		_tick_recorded(t)
	else:
		_tick_planned(t)
	_last_t = t


func _pump_only() -> void:
	if log != null and _built:
		_pump()


func _tick_planned(t: float) -> void:
	var k := log.step_at(t)
	if k == _last_k:
		return
	var yaw := log.yaw_at(t, k)
	for id in log.pieces.size():
		_write(id, log.pose_of(id, t, k, yaw))
	_base.transform = log.base_xf(yaw)
	_last_k = k


func _tick_recorded(t: float) -> void:
	var tau := log.tau_at(t)
	if is_nan(tau):
		# ...not on the record yet: what stands, stands, and the show is told to wait for it ([method behind])
		return
	tau = maxf(tau, 0.0)
	var yaw := track.yaw_at(tau, float(log.world.get("yaw", 0.0)))
	var plate := log.base_xf(yaw)
	var jumped := is_nan(_last_tau) or is_nan(_last_t) or absf(t - _last_t) > 0.5 or tau < _last_tau - 1e-4
	if jumped:
		for id in log.pieces.size():
			_write(id, track.pose_of(id, tau, plate))
	elif tau != _last_tau:
		for id in track.moved_between(_last_tau, tau):
			_write(int(id), track.pose_of(int(id), tau, plate))
		if track.turning(tau) or track.turning(_last_tau):
			for id in log.pieces.size():
				if not (track.seats[id] as Array).is_empty():
					_write(id, track.pose_of(id, tau, plate))
	_base.transform = plate
	_held_up(t, tau, plate)
	_last_tau = tau


## What is in hand is done something with ([Fingers]), the record going or stopped: it is only the record that stops.
func _held_up(t: float, tau: float, plate: Transform3D) -> void:
	var held := log.held_at(t)
	var id := int(held.get("id", -1))
	if _in_hand >= 0 and _in_hand != id:
		_write(_in_hand, track.pose_of(_in_hand, tau, plate))
	_in_hand = id
	if id >= 0:
		_write(id, Fingers.on(track.pose_of(id, tau, plate), held, log.pieces[id]))


func _write(id: int, xf: Transform3D) -> void:
	var s: Array = _slot[id]
	(s[0] as MultiMesh).set_instance_transform(int(s[1]), xf)


# --- the words -------------------------------------------------------------------------------------

## The table's assembly, as a puppeteer reads it: the plate, the stocks, and the model as it stands now.
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


## What is heard between [param t0] and [param t1]: what really happened then, on the record - `[{t, kind, against, at, size, strength, weight}]`. A stop has
## no record, so a stop has no sound. The hardest few of a crowded moment: past that nobody hears another.
func sounds_in(t0: float, t1: float) -> Array:
	if log == null or not _built or track == null or not track.stock_ready:
		return []
	var a := log.tau_at(t0)
	var b := log.tau_at(t1)
	if is_nan(a) or is_nan(b):
		return []
	a = maxf(a, 0.0)
	var picked := track.events_between(a, b)
	var out: Array = []
	for i in picked:
		var j := i * 6
		var words := track.ev_kind[i].split("/")
		out.append({"t": t0 + (track.ev_t[i] - a), "kind": words[0], "against": words[1], "at": Vector3(track.ev[j], track.ev[j + 1], track.ev[j + 2]),
			"strength": track.ev[j + 3], "size": track.ev[j + 4], "weight": track.ev[j + 5]})
	if out.size() > HITS_AT_ONCE:
		out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x["strength"]) > float(y["strength"]))
		out.resize(HITS_AT_ONCE)
	return out
