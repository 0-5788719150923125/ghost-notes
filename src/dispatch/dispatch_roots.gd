extends RefCounted
class_name DispatchRoots

## DispatchRoots - the roots of the hollow (next/dispatch.md): large roots crawling down from the ceiling like neurons,
## some past the desk, some onto it and across it toward the chair.
##
## Grown from the seed: each root is a walk from the ceiling, drawn down and wandering, splitting now and then into
## thinner roots (a swelling at each split), thinning to its tip; at the floor it crawls a little way and ends. The
## hanging ones stand behind the desk and at its ends, never over it or in front of the terminal; some come down past its
## edge to the floor. Systems of their own stand beside the desk on both sides, coming down to the floor and crawling a
## long way along it; at each end one clings under the desk's edge, runs down its front corner and out across the floor
## toward the chair. The ones on the desk come down behind it, over its far edge or its ends where there is a gap, and
## crawl across its top toward the chair between the things standing on it ([member DispatchSet.footprints]); how much of
## each is grown is a pure function of show time ([method grow]), its tip a taper moving on along it.

## How many: hanging systems, and roots on the desk; systems beside the desk on each side, and how far out from the middle
## they keep (m: never in front of what the chair sees at the desk's ends); roots along under each end.
const HANGING := 24
const ON_DESK := 4
const BESIDE := 8
const BESIDE_OUT := 1.45
const UNDER := 1
## A walk's step (m), how much it wanders a step, how hard it is drawn down, and how likely it is to split a step.
const STEP := 0.055
const WANDER := 0.42
const DOWN := 0.32
const SPLIT := 0.05
## Radii (m): a hanging root's at the ceiling, least and most; its tip; a root on the desk's at the edge.
const THICK := Vector2(0.035, 0.11)
const TIP := 0.004
const DESK_THICK := Vector2(0.018, 0.03)
## The desk's grid for the roots' way across it (m a cell).
const CELL := 0.02
## Sides round a root (more for a thick one).
const SIDES := 9
## The desk's roots are grown this share at the start of the night, all of it after [constant GROWN_BY] seconds.
const GROWN_AT_START := 0.62
const GROWN_BY := 1500.0
## Where no hanging root goes: over the desk and in front of it (the chair's), and the column before the terminal.
const KEEP_OUT_DESK := Rect2(-1.32, -0.62, 2.64, 2.6)
const KEEP_OUT_TERMINAL := Rect2(-0.55, -1.25, 1.1, 0.7)

var _seed := 1
var _desk_mat: ShaderMaterial
var _feet: Array = []
var _held := Rect2()
## The roots on the desk as made: each `{from, to}` (x, z, m) - where it came onto the desk and where its tip is grown to.
var on_desk: Array = []
## What lies on the desk's top, every root and tendril there: `{points, radii, from}` - its points from `from` on are on
## the top (a gate holds that nothing goes through what stands there).
var lying: Array = []


## Build them for [param seed], keeping clear of [param footprints] on the desk (Rect2s in x, z) and of [param held], where a
## phone laid open lies ([method DispatchSet.held_rect]): its way, its tendrils and its wander all avoid them.
func build(seed: int, footprints: Array, held := Rect2()) -> Node3D:
	_seed = seed
	_feet = footprints + ([held] if held.has_area() else [])
	_held = held
	var root := Node3D.new()
	root.name = "Roots"
	var hang_mat := _material(1.0)
	_desk_mat = _material(GROWN_AT_START)
	var r := RandomNumberGenerator.new()
	r.seed = hash([seed, "roots"])
	var paths: Array = []
	var tries := 0
	while paths.size() < HANGING * 3 and tries < HANGING * 6:
		tries += 1
		var near := r.randf() < 0.6
		var at := Vector3(r.randf_range(-2.4, 2.4), DispatchSet.CEILING, r.randf_range(-1.5, -0.62) if near else r.randf_range(-2.4, 0.6))
		if _kept_out(at):
			continue
		var made: Array = []
		_walk(r, at, Vector3(r.randf_range(-0.4, 0.4), -1.0, r.randf_range(-0.3, 0.3)).normalized(), r.randf_range(THICK.x, THICK.y),
			r.randf_range(2.6, 5.0), 0, made)
		paths.append_array(made)
		if paths.size() >= HANGING * 3:
			break
	for side in [-1.0, 1.0]:
		var n := 0
		var tries_side := 0
		while n < BESIDE and tries_side < BESIDE * 4:
			tries_side += 1
			var at := Vector3(side * r.randf_range(BESIDE_OUT, DispatchSet.ROOM.x - 0.3), DispatchSet.CEILING, r.randf_range(-1.8, 0.7))
			var made: Array = []
			_walk(r, at, Vector3(r.randf_range(-0.3, 0.3), -1.0, r.randf_range(-0.3, 0.3)).normalized(), r.randf_range(THICK.x, THICK.y * 0.85),
				r.randf_range(3.2, 5.6), 1, made, 0.55, BESIDE_OUT * side)
			paths.append_array(made)
			n += 1
		for k in UNDER:
			_under_root(r, side, paths)
	var hang := MeshInstance3D.new()
	hang.name = "Hanging"
	hang.mesh = _mesh(paths)
	hang.material_override = hang_mat
	root.add_child(hang)
	var desk: Array = []
	var grid := _desk_grid()
	var used: Array = []
	for k in ON_DESK:
		_desk_root(r, k, grid, desk, used)
	var on := MeshInstance3D.new()
	on.name = "OnTheDesk"
	on.mesh = _mesh(desk)
	on.material_override = _desk_mat
	root.add_child(on)
	return root


## How much of the desk's roots is grown at show time [param t]: from [constant GROWN_AT_START] at the start to all of it
## at [constant GROWN_BY] seconds, easing out.
static func grown(t: float) -> float:
	var u := clampf(t / GROWN_BY, 0.0, 1.0)
	return lerpf(GROWN_AT_START, 1.0, 1.0 - pow(1.0 - u, 1.6))


## The desk's roots as grown at [param t].
func grow(t: float) -> void:
	if _desk_mat != null:
		_desk_mat.set_shader_parameter("growth", grown(t))


func _material(growth: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/dispatch_root.gdshader")
	m.set_shader_parameter("growth", growth)
	return m


## Is [param p] where no hanging root may be?
static func _kept_out(p: Vector3) -> bool:
	var xz := Vector2(p.x, p.z)
	return KEEP_OUT_DESK.has_point(xz) or (KEEP_OUT_TERMINAL.has_point(xz) and p.y > 0.3)


## One root's walk from [param at] going [param dir], [param r0] thick, [param budget] meters long at most: a path
## `{points, radii}` into [param out], and the roots it splits into after it (at most [param depth] 3 deep). At the floor it
## crawls [param crawl] of its length at most; with [param outer] it keeps at least that far out to its side (x, signed).
func _walk(r: RandomNumberGenerator, at: Vector3, dir: Vector3, r0: float, budget: float, depth: int, out: Array, crawl := 0.25,
		outer := 0.0) -> void:
	var pts := PackedVector3Array([at])
	var rad := PackedFloat32Array([r0])
	var p := at
	var d := dir
	var gone := 0.0
	var on_floor := 0.0
	while gone < budget:
		d = (d + Vector3(r.randf_range(-1, 1), r.randf_range(-0.6, 0.6), r.randf_range(-1, 1)) * WANDER + Vector3.DOWN * DOWN).normalized()
		var next := p + d * STEP
		if _kept_out(next):
			var away := _away(next)
			d = (d + away * 1.4).normalized()
			next = p + d * STEP
			if _kept_out(next):
				next = p + away * STEP
		if outer != 0.0:
			next.x = signf(outer) * maxf(absf(next.x), absf(outer))
		next.x = clampf(next.x, -DispatchSet.ROOM.x + 0.1, DispatchSet.ROOM.x - 0.1)
		next.z = clampf(next.z, -0.6 - DispatchSet.ROOM.z + 0.1, 0.9)
		var thick := _radius(r0, gone / budget)
		if next.y < thick:
			next.y = thick
			d.y = 0.0
			on_floor += STEP
			if on_floor > budget * crawl:
				break
		p = next
		gone += STEP
		pts.append(p)
		rad.append(_radius(r0, gone / budget))
		if depth < 3 and r.randf() < SPLIT and rad[rad.size() - 1] > 0.012 and gone > 0.4:
			rad[rad.size() - 1] *= 1.35
			var axis := d.cross(Vector3(r.randf(), r.randf(), r.randf()).normalized()).normalized()
			var cd := d.rotated(axis, deg_to_rad(r.randf_range(35.0, 70.0)))
			_walk(r, p, cd, rad[rad.size() - 1] * 0.62, (budget - gone) * r.randf_range(0.4, 0.85), depth + 1, out, crawl, outer)
	if pts.size() >= 3:
		out.append({"points": pts, "radii": rad})


static func _radius(r0: float, u: float) -> float:
	return TIP + (r0 - TIP) * pow(clampf(1.0 - u, 0.0, 1.0), 0.75)


## The way out of the kept-out region nearest [param p] (in x and z).
static func _away(p: Vector3) -> Vector3:
	var box: Rect2 = KEEP_OUT_DESK if KEEP_OUT_DESK.has_point(Vector2(p.x, p.z)) else KEEP_OUT_TERMINAL
	var dl := p.x - box.position.x
	var dr := box.end.x - p.x
	var db := p.z - box.position.y
	var m := minf(dl, minf(dr, db))
	if m == dl:
		return Vector3.LEFT
	if m == dr:
		return Vector3.RIGHT
	return Vector3.FORWARD


## A root under the desk's end at [param side] (-1 left, 1 right): down from the ceiling beside the end, along under its
## edge toward the chair, down its front corner to the floor and out across it a way. Just outside the top's own edge, so
## it clings to the desk and never goes into it.
func _under_root(r: RandomNumberGenerator, side: float, out: Array) -> void:
	var y := DispatchSet.DESK_Y
	var x := side * (DispatchSet.DESK_W * 0.5 + 0.035)
	var r0 := r.randf_range(0.022, 0.034)
	var pts := PackedVector3Array()
	var top := Vector3(side * r.randf_range(1.4, 1.9), DispatchSet.CEILING, r.randf_range(-0.9, -0.35))
	var a := Vector3(x, y - 0.055, r.randf_range(-0.5, -0.25))
	for i in 26:
		var u := float(i) / 25.0
		var p := top.lerp(a, u)
		p.x += side * sin(u * PI) * 0.12
		p.z += sin(u * PI * 2.0) * 0.05
		pts.append(p)
	var b := Vector3(x, y - 0.06, DispatchSet.NEAR - 0.05)
	for i in range(1, 18):
		var u := float(i) / 17.0
		var p := a.lerp(b, u)
		p.y -= absf(sin(u * PI * 3.0)) * 0.012
		p.x += side * sin(u * PI * 2.0 + 0.7) * 0.008
		pts.append(p)
	var c := Vector3(x + side * 0.01, r0, DispatchSet.NEAR - 0.03)
	for i in range(1, 16):
		var u := float(i) / 15.0
		var p := b.lerp(c, u)
		p.x += side * sin(u * PI) * 0.03
		pts.append(p)
	var d := c + Vector3(-side * r.randf_range(0.0, 0.25), 0.0, r.randf_range(0.2, 0.45))
	for i in range(1, 12):
		var u := float(i) / 11.0
		var p := c.lerp(d, u)
		p.x += sin(u * PI * 2.0) * 0.03
		p.y = r0 * (1.0 - u * 0.6)
		pts.append(p)
	var rad := PackedFloat32Array()
	for i in pts.size():
		rad.append(lerpf(r0, TIP, pow(float(i) / float(pts.size() - 1), 0.85)))
	out.append({"points": pts, "radii": rad})


## The [param k]th root on the desk: down from the ceiling behind the desk to its far edge (or an end) at a gap between
## the things standing there, over the edge, and across the top toward the chair by the free way round what stands there
## (Godot's [AStarGrid2D] over the desk's top, a cell [constant CELL] across, what stands there and a margin solid),
## wandering a little off it, with now and then a fine tendril off its side. Into [param out]: the root, then its tendrils.
func _desk_root(r: RandomNumberGenerator, k: int, grid: AStarGrid2D, out: Array, used: Array) -> void:
	var gaps := _gaps()
	if gaps.is_empty():
		return
	# its own way in, and a way from it to the chair's side: each gap in turn from its own, the first that has one
	var entry := Vector2.INF
	var target := Vector2.ZERO
	var way := PackedVector2Array()
	for g in gaps.size():
		var e: Vector2 = gaps[(k * 2 + g) % gaps.size()]
		if used.has(e) or grid.is_point_solid(_cell(e)):
			continue
		target = _target(r, e, grid)
		way = grid.get_point_path(_cell(e), _cell(target), true)
		if way.size() >= 6:
			entry = e
			break
	if entry == Vector2.INF:
		return
	used.append(entry)
	var y := DispatchSet.DESK_Y
	var r0 := r.randf_range(DESK_THICK.x, DESK_THICK.y)
	var pts := PackedVector3Array()
	var behind := entry + (Vector2(0, -0.08) if absf(entry.y - DispatchSet.FAR) < 0.03 else Vector2(signf(entry.x) * 0.08, 0))
	var top := Vector3(behind.x + r.randf_range(-0.5, 0.5), DispatchSet.CEILING, behind.y - r.randf_range(0.2, 0.6))
	var drop := Vector3(behind.x, y + 0.03, behind.y)
	for i in 30:
		var u := float(i) / 29.0
		var p := top.lerp(drop, u)
		p.x += sin(u * PI * 2.0 + float(k)) * 0.06 * (1.0 - u)
		p.z += sin(u * PI) * -0.12
		pts.append(p)
	var edge := pts.size()
	var flat := _wander(r, way, 0.012)
	for q in flat:
		pts.append(Vector3(q.x, y + r0 * 0.85, q.y))
	var rad := PackedFloat32Array()
	var n := pts.size()
	for i in n:
		var u := float(i) / float(n - 1)
		rad.append(lerpf(r0 * 1.8, TIP, pow(u, 0.9)))
	out.append({"points": pts, "radii": rad, "grow_at": edge})
	lying.append({"points": pts, "radii": rad, "from": edge})
	on_desk.append({"from": entry, "to": flat[flat.size() - 1]})
	# Tendrils: fine roots off its side on the desk, each short and wandering until something stands in its way
	for t in r.randi_range(1, 3):
		var at := r.randi_range(int(flat.size() * 0.25), maxi(int(flat.size() * 0.8), int(flat.size() * 0.25) + 1))
		at = clampi(at, 1, flat.size() - 2)
		var dir := (flat[at + 1] - flat[at - 1]).normalized().rotated(r.randf_range(0.7, 1.3) * (1.0 if r.randf() < 0.5 else -1.0))
		var tp := PackedVector3Array()
		var p := flat[at]
		var tr := lerpf(r0 * 1.8, TIP, pow(float(edge + at) / float(n - 1), 0.9)) * 0.45
		for _i in r.randi_range(10, 22):
			tp.append(Vector3(p.x, y + tr * 0.8, p.y))
			dir = dir.rotated(r.randf_range(-0.45, 0.45))
			var next := p + dir * 0.012
			if _blocked(next, tr + 0.008) or absf(next.x) > DispatchSet.DESK_W * 0.5 - 0.02 or next.y > DispatchSet.NEAR - 0.02 or next.y < DispatchSet.FAR + 0.01:
				break
			p = next
		if tp.size() >= 5:
			var trad := PackedFloat32Array()
			for i in tp.size():
				trad.append(lerpf(tr, TIP * 0.6, float(i) / float(tp.size() - 1)))
			out.append({"points": tp, "radii": trad, "grow_at": 0, "tendril": true})
			lying.append({"points": tp, "radii": trad, "from": 0})


## The desk's top as a grid for the roots' way across it: a cell [constant CELL] across, solid where something stands (and
## a margin round it), and where a phone laid open will lie.
func _desk_grid() -> AStarGrid2D:
	var g := AStarGrid2D.new()
	var w := int(ceil(DispatchSet.DESK_W / CELL))
	var d := int(ceil(DispatchSet.DESK_D / CELL))
	g.region = Rect2i(0, 0, w, d)
	g.cell_size = Vector2(1, 1)
	g.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	g.default_compute_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	g.update()
	var held := _held
	for i in w:
		for j in d:
			var p := _point(Vector2i(i, j))
			if _blocked(p, 0.026) or held.has_point(p):
				g.set_point_solid(Vector2i(i, j), true)
	return g


## Where a root from [param entry] heads: of every free cell it can reach (a flood over the grid), the one nearest the
## chair's middle, a little at random, and apart from where the roots before it went ([member on_desk]).
func _target(r: RandomNumberGenerator, entry: Vector2, grid: AStarGrid2D) -> Vector2:
	var start := _cell(entry)
	if not grid.is_in_boundsv(start) or grid.is_point_solid(start):
		return entry
	var seen := {start: true}
	var front: Array = [start]
	var best := entry
	var best_score := -INF
	var chair := Vector2(0.0, DispatchSet.NEAR)
	while not front.is_empty():
		var c: Vector2i = front.pop_back()
		var p := _point(c)
		var score := -p.distance_to(chair) + r.randf_range(0.0, 0.12)
		for o in on_desk:
			score -= maxf(0.0, 0.18 - p.distance_to((o as Dictionary)["to"])) * 4.0
		if p.y > 0.1 and score > best_score:
			best_score = score
			best = p
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if grid.is_in_boundsv(n) and not seen.has(n) and not grid.is_point_solid(n):
				seen[n] = true
				front.append(n)
	return best


func _cell(p: Vector2) -> Vector2i:
	return Vector2i(clampi(int((p.x + DispatchSet.DESK_W * 0.5) / CELL), 0, int(ceil(DispatchSet.DESK_W / CELL)) - 1),
		clampi(int((p.y - DispatchSet.FAR) / CELL), 0, int(ceil(DispatchSet.DESK_D / CELL)) - 1))


func _point(c: Vector2i) -> Vector2:
	return Vector2((float(c.x) + 0.5) * CELL - DispatchSet.DESK_W * 0.5, (float(c.y) + 0.5) * CELL + DispatchSet.FAR)


## A grid's path in meters, smoothed and wandering [param amount] off it - kept off what stands there.
func _wander(r: RandomNumberGenerator, way: PackedVector2Array, amount: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for c in way:
		pts.append(_point(Vector2i(int(c.x), int(c.y))))
	for _k in 2:
		var sm := PackedVector2Array([pts[0]])
		for i in pts.size() - 1:
			sm.append(pts[i].lerp(pts[i + 1], 0.25))
			sm.append(pts[i].lerp(pts[i + 1], 0.75))
		sm.append(pts[pts.size() - 1])
		pts = sm
	var ph := r.randf() * TAU
	var out := PackedVector2Array()
	for i in pts.size():
		var t := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var off := t.orthogonal() * amount * sin(float(i) * 0.21 + ph) * sin(float(i) * 0.07 + ph * 0.5)
		var q := pts[i] + off
		out.append(q if not _blocked(q, 0.012) else pts[i])
	return out


## Where a root can come onto the desk: points along its far edge, and down its ends, with nothing standing there.
func _gaps() -> Array:
	var out: Array = []
	var x := -DispatchSet.DESK_W * 0.5 + 0.06
	while x < DispatchSet.DESK_W * 0.5 - 0.06:
		var p := Vector2(x, DispatchSet.FAR + 0.015)
		if not _blocked(p, 0.035) and not _blocked(p + Vector2(0, 0.06), 0.035):
			out.append(p)
			x += 0.16
		x += 0.02
	for side in [-1.0, 1.0]:
		var z := DispatchSet.FAR + 0.1
		while z < 0.1:
			var p := Vector2(side * (DispatchSet.DESK_W * 0.5 - 0.015), z)
			if not _blocked(p, 0.035):
				out.append(p)
				z += 0.2
			z += 0.03
	return out


func _blocked(p: Vector2, margin: float) -> bool:
	for f in _feet:
		if (f as Rect2).grow(margin).has_point(p):
			return true
	return false


## The push away from what stands near [param p] (within [param margin]).
func _push(p: Vector2, margin: float) -> Vector2:
	var out := Vector2.ZERO
	for f in _feet:
		var rect: Rect2 = (f as Rect2).grow(margin + 0.04)
		if not rect.has_point(p):
			continue
		var c := rect.get_center()
		var d := p - c
		var e := Vector2(d.x / maxf(rect.size.x, 0.01), d.y / maxf(rect.size.y, 0.01))
		out += Vector2(signf(d.x), 0.0) if absf(e.x) > absf(e.y) else Vector2(0.0, signf(d.y))
	return out


## The roots' mesh: a tube along each path, its radius as the path says; UV.x is how far along its root (0-1), UV2 meters
## along and round it, CUSTOM0 the point of its line it is drawn in onto past the growth.
func _mesh(paths: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
	for pa in paths:
		var pts: PackedVector3Array = pa["points"]
		var rad: PackedFloat32Array = pa["radii"]
		var n := pts.size()
		if n < 2:
			continue
		# smoothed once, so the walk's steps are curves
		var sm := PackedVector3Array()
		for i in n:
			var a := pts[maxi(i - 1, 0)]
			var b := pts[i]
			var c := pts[mini(i + 1, n - 1)]
			sm.append(b if i == 0 or i == n - 1 else (a + b * 2.0 + c) * 0.25)
		var lens := PackedFloat32Array([0.0])
		for i in range(1, n):
			lens.append(lens[i - 1] + sm[i].distance_to(sm[i - 1]))
		# How far along it has grown is measured from where it begins to grow (a root on the desk: its edge)
		var g0 := lens[clampi(int(pa.get("grow_at", 0)), 0, n - 1)]
		var total := maxf(lens[n - 1] - g0, 1e-4)
		var sides := SIDES if rad[0] > 0.03 else 6
		var up := Vector3.RIGHT
		var rings: Array = []
		for i in n:
			var t := (sm[mini(i + 1, n - 1)] - sm[maxi(i - 1, 0)]).normalized()
			if absf(t.dot(up)) > 0.9:
				up = Vector3.FORWARD if absf(t.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
			var bx := t.cross(up).normalized()
			var by := bx.cross(t).normalized()
			up = by
			var ring: Array = []
			for k in sides + 1:
				var a := TAU * float(k) / float(sides)
				var dd := bx * cos(a) + by * sin(a)
				var lump := 1.0 + 0.12 * sin(lens[i] * 23.0 + float(k) * 1.7) * sin(lens[i] * 7.0)
				ring.append([sm[i] + dd * rad[i] * lump, dd, float(k) / float(sides)])
			rings.append(ring)
		for i in n - 1:
			for k in sides:
				var q: Array = [[i, k], [i + 1, k + 1], [i + 1, k], [i, k], [i, k + 1], [i + 1, k + 1]]
				for qq in q:
					var ii := int(qq[0])
					var e: Array = rings[ii][int(qq[1])]
					st.set_normal(e[1])
					st.set_uv(Vector2(maxf(lens[ii] - g0, 0.0) / total, float(e[2])))
					st.set_uv2(Vector2(lens[ii], float(e[2]) * TAU * rad[ii]))
					var c: Vector3 = sm[ii]
					st.set_custom(0, Color(c.x, c.y, c.z, 0.0))
					st.add_vertex(e[0])
	st.generate_tangents()
	return st.commit()
