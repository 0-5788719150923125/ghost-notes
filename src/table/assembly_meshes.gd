extends RefCounted
class_name AssemblyMeshes

## AssemblyMeshes - WHAT AN ASSEMBLY'S PARTS LOOK LIKE ([Assembly]'s kinds), as meshes: one for each kind and size, its origin the
## middle of its underside, across along x, deep along z. Studs carry no maker's mark. Built by hand, as [Props] builds a thing, so
## each costs what is seen: a heap of a thousand of them is drawn at every shadow it casts, and a tub's pieces lie studs up, studs
## down and on their sides, so the underside is real too - the walls, and the tubes the studs grip.
##
## SMALL EDGES THAT CATCH THE LIGHT: a molded brick's edges are broken a fraction of a millimeter, and its studs' tops are too, and
## that thin line of highlight is most of what makes one read as a brick and not a box. Each part stands a hair inside its cell, as
## a real one does, so a wall's joints are seen.

const STUD := Assembly.STUD
const PLATE := Assembly.PLATE
const STUD_H := Assembly.STUD_H
const STUD_R := 0.0024
## The sides of a stud's round, how far a part stands inside its cell on each side, how broken its edges are, how thick its walls
## are underneath, and the outer radii of the tube under two studs and the bar under one (meters).
const STUD_SIDES := 10
const INSET := 0.00018
const EDGE := 0.00028
const WALL := 0.0013
const TUBE_R := 0.00325
const BAR_R := 0.0015
const TUBE_SIDES := 10
## How much of a part's height a 45 degree slope leaves at its low edge, in plates.
const LOW_EDGE := 1.0
## The sides of a round part, by how many studs across.
const ROUND_SIDES := {1: 16, 2: 28}

static var _kept := {}
static var _lock := Mutex.new()


## THE MESH OF A PART: made once, under a lock, for a table is built on a worker ([TablePreview]).
static func mesh_of(kind: String, w: int, d: int) -> ArrayMesh:
	var key := "%s %dx%d" % [kind, w, d]
	_lock.lock()
	var m: Variant = _kept.get(key)
	_lock.unlock()
	if m != null:
		return m
	var b := Build.new()
	match kind:
		"plate":
			_block(b, w, d, PLATE, true)
		"tile":
			_block(b, w, d, PLATE, false)
		"slope":
			_slope(b, w, d)
		"round":
			_round(b, w)
		"arch":
			_arch(b, w, d)
		_:
			_block(b, w, d, PLATE * 3.0, true)
	var made := b.mesh()
	_lock.lock()
	if not _kept.has(key):
		_kept[key] = made
	made = _kept[key]
	_lock.unlock()
	return made


## THE PLATE a build stands on: thin, studded all over.
static func base_of(w: int, d: int) -> ArrayMesh:
	var key := "base %dx%d" % [w, d]
	_lock.lock()
	var m: Variant = _kept.get(key)
	_lock.unlock()
	if m != null:
		return m
	var b := Build.new()
	var hw := float(w) * STUD * 0.5
	var hd := float(d) * STUD * 0.5
	var t := Assembly.BASE_T
	b.box(Vector3(-hw, 0.0, -hd), Vector3(hw, t, hd), EDGE)
	for j in d:
		for i in w:
			b.stud(Vector3((float(i) + 0.5) * STUD - hw, t, (float(j) + 0.5) * STUD - hd))
	var made := b.mesh()
	_lock.lock()
	if not _kept.has(key):
		_kept[key] = made
	made = _kept[key]
	_lock.unlock()
	return made


static func _block(b: Build, w: int, d: int, tall: float, studs: bool) -> void:
	var hw := float(w) * STUD * 0.5 - INSET
	var hd := float(d) * STUD * 0.5 - INSET
	b.shell(hw, hd, tall)
	if studs:
		_studs(b, w, d, tall, func(_j: int) -> bool: return true)
	_under(b, w, d, tall)


static func _studs(b: Build, w: int, d: int, y: float, keep: Callable) -> void:
	for j in d:
		if not keep.call(j):
			continue
		for i in w:
			b.stud(Vector3((float(i) + 0.5 - float(w) * 0.5) * STUD, y, (float(j) + 0.5 - float(d) * 0.5) * STUD))


## Under a part: the round tubes between its studs, or under a part one stud wide the thin bars.
static func _under(b: Build, w: int, d: int, tall: float) -> void:
	var top := tall - WALL
	if w >= 2 and d >= 2:
		for j in d - 1:
			for i in w - 1:
				b.tube(Vector3((float(i) + 1.0 - float(w) * 0.5) * STUD, 0.0, (float(j) + 1.0 - float(d) * 0.5) * STUD), TUBE_R, top)
	elif d >= 2:
		for j in d - 1:
			b.tube(Vector3(0.0, 0.0, (float(j) + 1.0 - float(d) * 0.5) * STUD), BAR_R, top)
	elif w >= 2:
		for i in w - 1:
			b.tube(Vector3((float(i) + 1.0 - float(w) * 0.5) * STUD, 0.0, 0.0), BAR_R, top)


## A SLOPE, its back along far z at full height, its top flat for the back row, falling 45 degrees to its low front edge.
static func _slope(b: Build, w: int, d: int) -> void:
	var hw := float(w) * STUD * 0.5 - INSET
	var hd := float(d) * STUD * 0.5 - INSET
	var tall := PLATE * 3.0
	var low := PLATE * LOW_EDGE
	var back_z := -hd + STUD - INSET
	var outline := PackedVector2Array([Vector2(-hd, 0.0), Vector2(hd, 0.0), Vector2(hd, low), Vector2(back_z, tall), Vector2(-hd, tall)])
	b.extrude_x(outline, -hw, hw)
	_studs(b, w, d, tall, func(j: int) -> bool: return j == 0)


## A ROUND PART: its body turned, broken at its top edge, a stud on each of its studs.
static func _round(b: Build, w: int) -> void:
	var r := float(w) * STUD * 0.5 - INSET
	var tall := PLATE * 3.0
	b.turned(r, tall, int(ROUND_SIDES.get(w, 20)))
	_studs(b, w, w, tall, func(_j: int) -> bool: return true)


## AN ARCH: standing on its two end studs, its opening a curve under its top, studs along all of its top.
static func _arch(b: Build, w: int, d: int) -> void:
	var hw := float(w) * STUD * 0.5 - INSET
	var hd := float(d) * STUD * 0.5 - INSET
	var tall := PLATE * 6.0
	var inner := hd - STUD
	var spring := PLATE * 1.5
	var crown := tall - PLATE * 1.0
	var outline := PackedVector2Array([Vector2(-hd, 0.0), Vector2(-inner, 0.0), Vector2(-inner, spring)])
	var n := 10
	for k in range(1, n):
		var a := PI - PI * float(k) / float(n)
		outline.append(Vector2(cos(a) * inner, spring + sin(a) * (crown - spring)))
	outline.append(Vector2(inner, spring))
	outline.append(Vector2(inner, 0.0))
	outline.append(Vector2(hd, 0.0))
	outline.append(Vector2(hd, tall))
	outline.append(Vector2(-hd, tall))
	b.extrude_x(outline, -hw, hw)
	_studs(b, w, d, tall, func(_j: int) -> bool: return true)


## A mesh made a face at a time, each face's normals its own unless a round asks them smooth.
class Build:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var i := PackedInt32Array()

	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal := Vector3.ZERO) -> void:
		var nn := normal if normal != Vector3.ZERO else (b - a).cross(d - a).normalized()
		var at := v.size()
		v.append_array(PackedVector3Array([a, b, c, d]))
		n.append_array(PackedVector3Array([nn, nn, nn, nn]))
		i.append_array(PackedInt32Array([at, at + 2, at + 1, at, at + 3, at + 2]))

	## A plain block from [param lo] to [param hi], its top edges broken by [param e].
	func box(lo: Vector3, hi: Vector3, e: float) -> void:
		var t := hi.y
		quad(Vector3(lo.x + e, t, lo.z + e), Vector3(lo.x + e, t, hi.z - e), Vector3(hi.x - e, t, hi.z - e), Vector3(hi.x - e, t, lo.z + e), Vector3.UP)
		_side(Vector3(lo.x, lo.y, hi.z), Vector3(hi.x, lo.y, hi.z), t, e, Vector3.BACK)
		_side(Vector3(hi.x, lo.y, lo.z), Vector3(lo.x, lo.y, lo.z), t, e, Vector3.FORWARD)
		_side(Vector3(hi.x, lo.y, hi.z), Vector3(hi.x, lo.y, lo.z), t, e, Vector3.RIGHT)
		_side(Vector3(lo.x, lo.y, lo.z), Vector3(lo.x, lo.y, hi.z), t, e, Vector3.LEFT)
		quad(Vector3(lo.x, lo.y, hi.z), Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, lo.y, hi.z), Vector3.DOWN)

	## One side, from [param a] to [param b] along its foot, up to [param t], its top broken inward by [param e].
	func _side(a: Vector3, b: Vector3, t: float, e: float, normal: Vector3) -> void:
		var along := (b - a).normalized()
		var a2 := Vector3(a.x, t - e, a.z)
		var b2 := Vector3(b.x, t - e, b.z)
		quad(a, b, b2, a2, normal)
		var a3 := Vector3(a.x, t, a.z) - normal * e + along * e
		var b3 := Vector3(b.x, t, b.z) - normal * e - along * e
		quad(a2, b2, b3, a3, (normal + Vector3.UP).normalized())

	## A PART'S SHELL: top and four sides with its edges broken, hollow below - a rim round its underside and a ceiling above it.
	func shell(hw: float, hd: float, tall: float) -> void:
		box_open(hw, hd, tall)

	func box_open(hw: float, hd: float, tall: float) -> void:
		var e := EDGE
		quad(Vector3(-hw + e, tall, -hd + e), Vector3(-hw + e, tall, hd - e), Vector3(hw - e, tall, hd - e), Vector3(hw - e, tall, -hd + e), Vector3.UP)
		_side(Vector3(-hw, 0.0, hd), Vector3(hw, 0.0, hd), tall, e, Vector3.BACK)
		_side(Vector3(hw, 0.0, -hd), Vector3(-hw, 0.0, -hd), tall, e, Vector3.FORWARD)
		_side(Vector3(hw, 0.0, hd), Vector3(hw, 0.0, -hd), tall, e, Vector3.RIGHT)
		_side(Vector3(-hw, 0.0, -hd), Vector3(-hw, 0.0, hd), tall, e, Vector3.LEFT)
		# ...underneath: the rim its walls end in, the inside of its walls, and the ceiling the studs are under
		var iw := maxf(hw - WALL, hw * 0.5)
		var id := maxf(hd - WALL, hd * 0.5)
		var top := maxf(tall - WALL, tall * 0.4)
		quad(Vector3(-hw, 0.0, hd), Vector3(-hw, 0.0, -hd), Vector3(-iw, 0.0, -id), Vector3(-iw, 0.0, id), Vector3.DOWN)
		quad(Vector3(hw, 0.0, -hd), Vector3(hw, 0.0, hd), Vector3(iw, 0.0, id), Vector3(iw, 0.0, -id), Vector3.DOWN)
		quad(Vector3(-hw, 0.0, -hd), Vector3(hw, 0.0, -hd), Vector3(iw, 0.0, -id), Vector3(-iw, 0.0, -id), Vector3.DOWN)
		quad(Vector3(hw, 0.0, hd), Vector3(-hw, 0.0, hd), Vector3(-iw, 0.0, id), Vector3(iw, 0.0, id), Vector3.DOWN)
		quad(Vector3(-iw, 0.0, id), Vector3(-iw, 0.0, -id), Vector3(-iw, top, -id), Vector3(-iw, top, id), Vector3.RIGHT)
		quad(Vector3(iw, 0.0, -id), Vector3(iw, 0.0, id), Vector3(iw, top, id), Vector3(iw, top, -id), Vector3.LEFT)
		quad(Vector3(-iw, 0.0, -id), Vector3(iw, 0.0, -id), Vector3(iw, top, -id), Vector3(-iw, top, -id), Vector3.BACK)
		quad(Vector3(iw, 0.0, id), Vector3(-iw, 0.0, id), Vector3(-iw, top, id), Vector3(iw, top, id), Vector3.FORWARD)
		quad(Vector3(-iw, top, id), Vector3(-iw, top, -id), Vector3(iw, top, -id), Vector3(iw, top, id), Vector3.DOWN)

	## A STUD standing on [param at]: its side round and smooth, its top broken, its cap flat.
	func stud(at: Vector3) -> void:
		var r := STUD_R
		var h := STUD_H
		var e := minf(EDGE * 1.1, r * 0.2)
		var n_sides := STUD_SIDES
		var base := v.size()
		for k in n_sides + 1:
			var a := TAU * float(k) / float(n_sides)
			var out := Vector3(cos(a), 0.0, sin(a))
			v.append(at + out * r)
			n.append(out)
			v.append(at + out * r + Vector3(0.0, h - e, 0.0))
			n.append(out)
			v.append(at + out * r + Vector3(0.0, h - e, 0.0))
			n.append((out + Vector3.UP).normalized())
			v.append(at + out * (r - e) + Vector3(0.0, h, 0.0))
			n.append((out + Vector3.UP).normalized())
		for k in n_sides:
			var s := base + k * 4
			var t := s + 4
			i.append_array(PackedInt32Array([s, t, s + 1, t, t + 1, s + 1]))
			i.append_array(PackedInt32Array([s + 2, t + 2, s + 3, t + 2, t + 3, s + 3]))
		var cap := v.size()
		for k in n_sides:
			var a := TAU * float(k) / float(n_sides)
			v.append(at + Vector3(cos(a) * (r - e), h, sin(a) * (r - e)))
			n.append(Vector3.UP)
		for k in range(1, n_sides - 1):
			i.append_array(PackedInt32Array([cap, cap + k, cap + k + 1]))

	## A round tube under a part, standing from its underside up to [param top].
	func tube(at: Vector3, r: float, top: float) -> void:
		var base := v.size()
		var sides := TUBE_SIDES
		for k in sides + 1:
			var a := TAU * float(k) / float(sides)
			var out := Vector3(cos(a), 0.0, sin(a))
			v.append(at + out * r)
			n.append(out)
			v.append(at + out * r + Vector3(0.0, top, 0.0))
			n.append(out)
		for k in sides:
			var s := base + k * 2
			i.append_array(PackedInt32Array([s, s + 2, s + 1, s + 2, s + 3, s + 1]))
		var cap := v.size()
		for k in sides:
			var a := TAU * float(k) / float(sides)
			v.append(at + Vector3(cos(a) * r, 0.0, sin(a) * r))
			n.append(Vector3.DOWN)
		for k in range(1, sides - 1):
			i.append_array(PackedInt32Array([cap, cap + k + 1, cap + k]))

	## A SOLID OF THIS OUTLINE (z, y points, counterclockwise from outside at +x) across x from [param x0] to [param x1].
	func extrude_x(outline: PackedVector2Array, x0: float, x1: float) -> void:
		var tris := Geometry2D.triangulate_polygon(outline)
		for side in 2:
			var x := x1 if side == 0 else x0
			var nn := Vector3.RIGHT if side == 0 else Vector3.LEFT
			var at := v.size()
			for p in outline:
				v.append(Vector3(x, p.y, p.x))
				n.append(nn)
			for k in range(0, tris.size(), 3):
				# wound as the renderer takes a front face, whichever way the triangulation handed them back
				var pa := v[at + tris[k]]
				var pb := v[at + tris[k + 1]]
				var pc := v[at + tris[k + 2]]
				if (pb - pa).cross(pc - pa).dot(nn) < 0.0:
					i.append_array(PackedInt32Array([at + tris[k], at + tris[k + 1], at + tris[k + 2]]))
				else:
					i.append_array(PackedInt32Array([at + tris[k], at + tris[k + 2], at + tris[k + 1]]))
		var m := outline.size()
		for k in m:
			var a := outline[k]
			var b := outline[(k + 1) % m]
			var along := (b - a).normalized()
			# outward from the outline, which runs counterclockwise in (z, y): to its right
			var out := Vector3(0.0, -along.x, along.y)
			quad(Vector3(x1, a.y, a.x), Vector3(x1, b.y, b.x), Vector3(x0, b.y, b.x), Vector3(x0, a.y, a.x), out)

	## A TURNED BODY round the vertical, [param tall] high: its side smooth, its top edge broken, its top and underside flat.
	func turned(r: float, tall: float, sides: int) -> void:
		var e := EDGE
		var base := v.size()
		for k in sides + 1:
			var a := TAU * float(k) / float(sides)
			var out := Vector3(cos(a), 0.0, sin(a))
			v.append(out * r)
			n.append(out)
			v.append(out * r + Vector3(0.0, tall - e, 0.0))
			n.append(out)
			v.append(out * r + Vector3(0.0, tall - e, 0.0))
			n.append((out + Vector3.UP).normalized())
			v.append(out * (r - e) + Vector3(0.0, tall, 0.0))
			n.append((out + Vector3.UP).normalized())
		for k in sides:
			var s := base + k * 4
			var t := s + 4
			i.append_array(PackedInt32Array([s, t, s + 1, t, t + 1, s + 1]))
			i.append_array(PackedInt32Array([s + 2, t + 2, s + 3, t + 2, t + 3, s + 3]))
		for end in 2:
			var cap := v.size()
			for k in sides:
				var a := TAU * float(k) / float(sides)
				var rr := r - e if end == 0 else r
				v.append(Vector3(cos(a) * rr, tall if end == 0 else 0.0, sin(a) * rr))
				n.append(Vector3.UP if end == 0 else Vector3.DOWN)
			for k in range(1, sides - 1):
				if end == 0:
					i.append_array(PackedInt32Array([cap, cap + k, cap + k + 1]))
				else:
					i.append_array(PackedInt32Array([cap, cap + k + 1, cap + k]))

	func mesh() -> ArrayMesh:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = v
		arrays[Mesh.ARRAY_NORMAL] = n
		arrays[Mesh.ARRAY_INDEX] = i
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return m
