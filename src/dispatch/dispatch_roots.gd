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
## each is grown is a pure function of show time ([method grow]), its tip a taper moving on along it. No root goes through
## what fills the air beside the desk ([member DispatchSet.clear]: the printer's paper and its heap): it goes round ([method
## _cleared]).
##
## A prop on the Dispatch desk's Props card ([DispatchProps]): how many hang, cross the desk and stand beside it, how thick they are,
## how much they wander and how often they split are its properties ([constant FIELDS]), each set by a person or drawn by its own
## number ([Roll]); kept unrolled, they are the hollow's own, grown from the desk's number.

## What the roots can be told: how many hang from the ceiling, cross the desk and stand beside it on each side, how thick they are
## (over their own), how much they wander and how often they split. Their defaults are the hollow's own.
const FIELDS := {
	"hanging": {"label": "Hanging", "blurb": "How many systems of roots hang from the ceiling.", "type": "int", "min": 0, "max": 48, "step": 1,
		"default": 24, "roll": [12, 36]},
	"on_desk": {"label": "On the desk", "blurb": "How many crawl across the desk toward the chair.", "type": "int", "min": 0, "max": 8,
		"step": 1, "default": 4, "roll": [2, 6]},
	"beside": {"label": "Beside", "blurb": "How many stand beside the desk on each side.", "type": "int", "min": 0, "max": 16, "step": 1,
		"default": 8, "roll": [4, 12]},
	"thick": {"label": "Thickness", "blurb": "How thick they are, over the hollow's own.", "type": "float", "min": 0.4, "max": 2.0,
		"step": 0.05, "default": 1.0, "roll": [0.7, 1.35]},
	"wander": {"label": "Wander", "blurb": "How much they wander as they come down.", "type": "float", "min": 0.05, "max": 0.9, "step": 0.01,
		"default": 0.42, "roll": [0.26, 0.6]},
	"split": {"label": "Splits", "blurb": "How often they split into thinner roots.", "type": "float", "min": 0.0, "max": 0.15, "step": 0.005,
		"default": 0.05, "roll": [0.025, 0.085]},
}
## How far out from the middle the systems beside the desk keep (m: never in front of what the chair sees at the desk's ends), and
## how many roots run along under each end.
const BESIDE_OUT := 1.45
const UNDER := 1
## A walk's step (m) and how hard it is drawn down (how much it wanders a step and how likely it is to split, [constant FIELDS]).
const STEP := 0.055
const DOWN := 0.32
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
## How far a root keeps from what it goes round, past its own thickness (m).
const CLEAR_GAP := 0.04
## The longest step along a hanging root's line before it is filled in (m, [method _dense]).
const DENSE_STEP := 0.05
## How many times a root's line is smoothed and cleared again before it is drawn ([method _kept_clear]).
const CLEAR_PASSES := 4

var _seed := 1
var _v := {}                     # what the roots are told ([constant FIELDS]), as this build has it
var _desk_mat: ShaderMaterial
var _feet: Array = []
var _held := Rect2()
var _clear: Array = []           # what no root goes through (AABBs, the set's space)
## Every root off the desk's top as made, `{points, radii}`: the hanging ones, those beside the desk and under its ends.
var hanging: Array = []
## The roots on the desk as made: each `{from, to}` (x, z, m) - where it came onto the desk and where its tip is grown to.
var on_desk: Array = []
## What lies on the desk's top, every root and tendril there: `{points, radii, from}` - its points from `from` on are on
## the top (a gate holds that nothing goes through what stands there).
var lying: Array = []


## What roots kept as [param spec] (`{seed, <its fields set>}`, [method Roll.own_or_drawn]) are told, every field.
static func values_of(spec: Dictionary) -> Dictionary:
	return Roll.own_or_drawn(FIELDS, spec)


## What roots told [param v] ([method values_of]) are, in a line.
static func line_of(v: Dictionary) -> String:
	return "%d hanging, %d across the desk, %d beside it each side" % [int(v["hanging"]), int(v["on_desk"]), int(v["beside"])]


## Build them for [param seed], keeping clear of [param footprints] on the desk (Rect2s in x, z) and of [param held], where a
## phone laid open lies ([method DispatchSet.held_rect]): its way, its tendrils and its wander all avoid them - and going round
## [param clear] (AABBs: [member DispatchSet.clear]) - as [param spec] keeps them (`{seed, <its fields set>}`, [method
## Roll.own_or_drawn]: rolled, grown from its own number instead).
func build(seed: int, footprints: Array, held := Rect2(), clear: Array = [], spec := {}) -> Node3D:
	_v = Roll.own_or_drawn(FIELDS, spec)
	_seed = int(spec["seed"]) if typeof(spec.get("seed")) in [TYPE_INT, TYPE_FLOAT] else seed
	seed = _seed
	var hanging_n := int(_v["hanging"])
	var beside_n := int(_v["beside"])
	var thick: Vector2 = THICK * float(_v["thick"])
	_feet = footprints + ([held] if held.has_area() else [])
	_held = held
	_clear = _merged(clear)
	var root := Node3D.new()
	root.name = "Roots"
	var hang_mat := _material(1.0)
	_desk_mat = _material(GROWN_AT_START)
	var r := RandomNumberGenerator.new()
	r.seed = hash([seed, "roots"])
	var paths: Array = []
	var tries := 0
	while paths.size() < hanging_n * 3 and tries < hanging_n * 6:
		tries += 1
		var near := r.randf() < 0.6
		var at := Vector3(r.randf_range(-2.4, 2.4), DispatchSet.CEILING, r.randf_range(-1.5, -0.62) if near else r.randf_range(-2.4, 0.6))
		if _kept_out(at):
			continue
		var made: Array = []
		_walk(r, at, Vector3(r.randf_range(-0.4, 0.4), -1.0, r.randf_range(-0.3, 0.3)).normalized(), r.randf_range(thick.x, thick.y),
			r.randf_range(2.6, 5.0), 0, made)
		paths.append_array(made)
		if paths.size() >= hanging_n * 3:
			break
	for side in [-1.0, 1.0]:
		var n := 0
		var tries_side := 0
		while n < beside_n and tries_side < beside_n * 4:
			tries_side += 1
			var at := Vector3(side * r.randf_range(BESIDE_OUT, DispatchSet.ROOM.x - 0.3), DispatchSet.CEILING, r.randf_range(-1.8, 0.7))
			var made: Array = []
			_walk(r, at, Vector3(r.randf_range(-0.3, 0.3), -1.0, r.randf_range(-0.3, 0.3)).normalized(), r.randf_range(thick.x, thick.y * 0.85),
				r.randf_range(3.2, 5.6), 1, made, 0.55, BESIDE_OUT * side)
			paths.append_array(made)
			n += 1
		for k in UNDER:
			_under_root(r, side, paths)
	for i in paths.size():
		paths[i] = _drawn_clear(paths[i])
	hanging = paths
	var hang := MeshInstance3D.new()
	hang.name = "Hanging"
	hang.mesh = _mesh(paths)
	hang.material_override = hang_mat
	root.add_child(hang)
	var desk: Array = []
	var grid := _desk_grid()
	var used: Array = []
	for k in int(_v["on_desk"]):
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
		d = (d + Vector3(r.randf_range(-1, 1), r.randf_range(-0.6, 0.6), r.randf_range(-1, 1)) * float(_v["wander"]) + Vector3.DOWN * DOWN).normalized()
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
		if depth < 3 and r.randf() < float(_v["split"]) and rad[rad.size() - 1] > 0.012 and gone > 0.4:
			rad[rad.size() - 1] *= 1.35
			var axis := d.cross(Vector3(r.randf(), r.randf(), r.randf()).normalized()).normalized()
			var cd := d.rotated(axis, deg_to_rad(r.randf_range(35.0, 70.0)))
			_walk(r, p, cd, rad[rad.size() - 1] * 0.62, (budget - gone) * r.randf_range(0.4, 0.85), depth + 1, out, crawl, outer)
	if pts.size() >= 3:
		out.append({"points": pts, "radii": rad})


## [param boxes] with any two nearer than a root is thick made one, the box round both: a root pushed out of one never lands in
## another, nor squeezes between them.
static func _merged(boxes: Array) -> Array:
	var out: Array = boxes.duplicate()
	var joined := true
	while joined:
		joined = false
		for i in out.size():
			for j in range(i + 1, out.size()):
				if (out[i] as AABB).grow(THICK.y + CLEAR_GAP).intersects(out[j] as AABB):
					out[i] = (out[i] as AABB).merge(out[j] as AABB)
					out.remove_at(j)
					joined = true
					break
			if joined:
				break
	return out


## [param pts] (each [param rad] thick) kept out of what no root goes through ([member _clear]) - the first [param upto] of them,
## all for -1: each run of points inside one box pushed out together through the side (x or z, never up or down) that moves the run
## least in all - so a root passing through goes round the box's side, one only grazing it out by the face it touched -
## [constant CLEAR_GAP] off.
func _cleared(pts: PackedVector3Array, rad: PackedFloat32Array, upto := -1) -> PackedVector3Array:
	if _clear.is_empty():
		return pts
	var out := pts.duplicate()
	var n := pts.size() if upto < 0 else mini(upto, pts.size())
	var i := 0
	while i < n:
		var box := -1
		for b in _clear.size():
			if (_clear[b] as AABB).grow(rad[i] + CLEAR_GAP).has_point(out[i]):
				box = b
				break
		if box < 0:
			i += 1
			continue
		var j := i
		while j < n and (_clear[box] as AABB).grow(rad[j] + CLEAR_GAP).has_point(out[j]):
			j += 1
		var best := 0
		var least := INF
		for face in 4:
			var cost := 0.0
			for k in range(i, j):
				cost += out[k].distance_to(_to_face(out[k], (_clear[box] as AABB).grow(rad[k] + CLEAR_GAP), face))
			if cost < least:
				least = cost
				best = face
		for k in range(i, j):
			out[k] = _to_face(out[k], (_clear[box] as AABB).grow(rad[k] + CLEAR_GAP), best)
		i = j
	return out


## [param p] moved out to side [param face] of [param g] (0 its low x, 1 high x, 2 low z, 3 high z).
static func _to_face(p: Vector3, g: AABB, face: int) -> Vector3:
	match face:
		0:
			p.x = g.position.x
		1:
			p.x = g.end.x
		2:
			p.z = g.position.z
		_:
			p.z = g.end.z
	return p


## [param path] (`{points, radii}`) with each step longer than [constant DENSE_STEP] filled in along a smooth curve through its own
## points (Catmull-Rom; its radii between): the line its tube is drawn along ([method _mesh]), so what is kept clear ([method
## _cleared]) is what is drawn - a long step's chord never cuts through what its ends go round.
static func _dense(path: Dictionary) -> Dictionary:
	var pts: PackedVector3Array = path["points"]
	var rad: PackedFloat32Array = path["radii"]
	var n := pts.size()
	if n < 2:
		return path
	var out_p := PackedVector3Array()
	var out_r := PackedFloat32Array()
	for i in n - 1:
		out_p.append(pts[i])
		out_r.append(rad[i])
		var steps := ceili(pts[i].distance_to(pts[i + 1]) / DENSE_STEP)
		var a := pts[maxi(i - 1, 0)]
		var b := pts[i]
		var c := pts[i + 1]
		var d := pts[mini(i + 2, n - 1)]
		for k in range(1, steps):
			var u := float(k) / float(steps)
			var u2 := u * u
			out_p.append(0.5 * (2.0 * b + (c - a) * u + (2.0 * a - 5.0 * b + 4.0 * c - d) * u2 + (3.0 * b - a - 3.0 * c + d) * u2 * u))
			out_r.append(lerpf(rad[i], rad[i + 1], u))
	out_p.append(pts[n - 1])
	out_r.append(rad[n - 1])
	var out := path.duplicate()
	out["points"] = out_p
	out["radii"] = out_r
	return out


## [param pts] kept out of what no root goes through ([method _cleared]) as it will be drawn: cleared, smoothed as its tube is
## ([method _smoothed]) and cleared again, [constant CLEAR_PASSES] times - so where a run of it was moved out to a face, the stretch
## between that and the rest is drawn outside too. The first [param upto] of them, all for -1.
func _kept_clear(pts: PackedVector3Array, rad: PackedFloat32Array, upto := -1) -> PackedVector3Array:
	var out := _cleared(pts, rad, upto)
	if _clear.is_empty():
		return out
	for _k in CLEAR_PASSES:
		out = _cleared(_smoothed(out, upto), rad, upto)
	return out


## Hanging root [param path] (`{points, radii}`) as it is drawn, kept out of what no root goes through ([member _clear]): filled in
## ([method _dense]), cleared, then [constant CLEAR_PASSES] times filled in where clearing left a jump, smoothed and cleared again,
## and filled in and cleared a last time - kept `drawn`, so its tube is drawn on just these points ([method _mesh]).
func _drawn_clear(path: Dictionary) -> Dictionary:
	var out := _dense(path)
	if _clear.is_empty():
		return out
	out["points"] = _cleared(out["points"], out["radii"])
	for _k in CLEAR_PASSES:
		out = _dense(out)
		out["points"] = _cleared(_smoothed(out["points"]), out["radii"])
	out = _dense(out)
	out["points"] = _cleared(out["points"], out["radii"])
	out["drawn"] = true
	return out


## [param pts] smoothed once as a root's tube is drawn ([method _mesh]): each point a quarter of the way to its neighbours' middle, its
## ends kept; the first [param upto] of them, all for -1.
static func _smoothed(pts: PackedVector3Array, upto := -1) -> PackedVector3Array:
	var n := pts.size()
	var m := n if upto < 0 else mini(upto, n)
	var out := pts.duplicate()
	for i in range(1, mini(m, n - 1)):
		out[i] = (pts[i - 1] + pts[i] * 2.0 + pts[i + 1]) * 0.25
	return out


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
	var r0 := r.randf_range(DESK_THICK.x, DESK_THICK.y) * float(_v["thick"])
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
	# its way down filled in to the line it is drawn on, then round what fills the air by the desk; its way across the top keeps
	# clear of what stands there already
	var head := _dense({"points": pts.slice(0, edge + 1), "radii": rad.slice(0, edge + 1)})
	var head_p: PackedVector3Array = head["points"]
	var head_r: PackedFloat32Array = head["radii"]
	pts = head_p.slice(0, head_p.size() - 1) + pts.slice(edge)
	rad = head_r.slice(0, head_r.size() - 1) + rad.slice(edge)
	edge = head_p.size() - 1
	pts = _kept_clear(pts, rad, edge)
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


## Where a root can come onto the desk: points along its far edge, and down its ends, with nothing standing there and nothing it
## must not go through ([member _clear]: the printer's paper falling past the end, its heap) where it comes down to it.
func _gaps() -> Array:
	var out: Array = []
	var x := -DispatchSet.DESK_W * 0.5 + 0.06
	while x < DispatchSet.DESK_W * 0.5 - 0.06:
		var p := Vector2(x, DispatchSet.FAR + 0.015)
		if not _blocked(p, 0.035) and not _blocked(p + Vector2(0, 0.06), 0.035) and not _drops_through(p + Vector2(0, -0.08)):
			out.append(p)
			x += 0.16
		x += 0.02
	for side in [-1.0, 1.0]:
		var z := DispatchSet.FAR + 0.1
		while z < 0.1:
			var p := Vector2(side * (DispatchSet.DESK_W * 0.5 - 0.015), z)
			if not _blocked(p, 0.035) and not _drops_through(p + Vector2(side * 0.08, 0)):
				out.append(p)
				z += 0.2
			z += 0.03
	return out


## Whether a root coming down at [param p] (x, z) would come down through what it must not go through ([member _clear]), as thick as
## a root on the desk at its thickest, and far enough round for its drop's wander.
func _drops_through(p: Vector2) -> bool:
	for b in _clear:
		var box: AABB = b
		if Rect2(box.position.x, box.position.z, box.size.x, box.size.z).grow(DESK_THICK.y * 1.8 + CLEAR_GAP + 0.06).has_point(p):
			return true
	return false


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
		# smoothed once, so the walk's steps are curves (a path kept as drawn already is: [method _drawn_clear])
		var sm := PackedVector3Array()
		for i in n:
			var a := pts[maxi(i - 1, 0)]
			var b := pts[i]
			var c := pts[mini(i + 1, n - 1)]
			sm.append(b if i == 0 or i == n - 1 or pa.get("drawn", false) else (a + b * 2.0 + c) * 0.25)
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
