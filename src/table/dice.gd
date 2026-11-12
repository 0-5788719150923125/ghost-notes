extends RefCounted
class_name Dice

## Dice - a die as a solid (next/tabletop.md "Dice"): each shape's faces from its vertices, the numbers printed on them as real dice print
## them, how to read one at rest, and the one trick that makes a die thrown by real physics come up as the seed says.
##
## The trick: a body is thrown ([DiceBake]) and lands on whatever face it lands on, and the die's printing is then turned by one of the
## solid's own rotations ([method rotation_between]) so the number rolled is printed on that face. The solid does not change, so every
## bounce and every rest is what physics did, and the printing it comes to rest in is a real die's, opposite faces summing as they do.
## Which number came up was decided by [DiceNotation]. Every shape here is face-transitive, so for any two faces the rotation exists,
## which tests/table/dice_check.gd holds by the vertices.
##
## A D4 is read at its top point: it rests on a face, and the number is the one printed at the point that face is opposite. So its face
## counts as the one it lies on ([method landed]), and each of its faces shows the three numbers of the three points it has.
##
## Nothing here needs a server or a scene, but [method mesh_of]: the bake and a gate ask for the shapes alone.

## The solids, by how many faces. `flat`: how far from the solid's middle its face is, as a share of its size, so a table can stand it at rest; `size` a real die's across, in meters, flats or points as a player would measure it; `read` how big its print is on a face, as a share of the face's own radius.
const SHAPES := {
	4: {"label": "Four", "blurb": "a tetrahedron: read at its top point", "size": 0.024, "read": 0.34},
	6: {"label": "Six", "blurb": "a cube", "size": 0.019, "read": 0.82},
	8: {"label": "Eight", "blurb": "an octahedron", "size": 0.023, "read": 0.62},
	10: {"label": "Ten", "blurb": "a pentagonal trapezohedron", "size": 0.024, "read": 0.5},
	12: {"label": "Twelve", "blurb": "a dodecahedron", "size": 0.025, "read": 0.72},
	20: {"label": "Twenty", "blurb": "an icosahedron", "size": 0.026, "read": 0.56},
}
## What a set of dice is made of: how it looks, how it bounces (real dice are near enough one mass; a metal die is what you hear coming), and what [WorkSounds] rings as.
const MATERIALS := {
	"plastic": {"label": "Plastic", "blurb": "the usual kind: light, bright and rattling", "friction": 0.42, "bounce": 0.42, "mass": 1.0, "sound": "plastic", "metal": 0.0, "rough": 0.28},
	"metal": {"label": "Metal", "blurb": "heavy, bites the table, and is heard across the room", "friction": 0.32, "bounce": 0.28, "mass": 3.2, "sound": "metal", "metal": 0.9, "rough": 0.34},
	"wood": {"label": "Wood", "blurb": "soft-edged and quiet, soon at rest", "friction": 0.55, "bounce": 0.3, "mass": 0.6, "sound": "wood", "metal": 0.0, "rough": 0.72},
	"stone": {"label": "Stone", "blurb": "polished, cold and clacking", "friction": 0.36, "bounce": 0.36, "mass": 2.2, "sound": "stone", "metal": 0.0, "rough": 0.18},
	"glass": {"label": "Glass", "blurb": "clear, ringing and a little alarming", "friction": 0.3, "bounce": 0.4, "mass": 1.3, "sound": "glass", "metal": 0.0, "rough": 0.06},
}
const FONT := "res://fonts/cards/EBGaramond-Variable.ttf"
## How much of a face is taken back to round its edges, and how far apart a printed number stands off it (shares of the die's size).
const BEVEL := 0.12
const PRINT_LIFT := 0.004

static var _solids := {}          # a shape -> {verts, faces, printed}
static var _meshes := {}          # a shape + print -> ArrayMesh
static var _lock := Mutex.new()


## The solid: `{verts, faces}` at a radius of 1 from its middle, a face `{normal, center, ring}`, `ring` its corners in order, counterclockwise from outside; `printed`, a printed face's index -> the solid's face that has it.
static func solid(shape: int) -> Dictionary:
	_lock.lock()
	if not _solids.has(shape):
		var verts := _vertices(shape)
		var d := {"verts": verts, "faces": _faces_of(verts)}
		d["printed"] = _printing(d["faces"], shape)
		_solids[shape] = d
	var out: Dictionary = _solids[shape]
	_lock.unlock()
	return out


static func _vertices(shape: int) -> PackedVector3Array:
	var v := PackedVector3Array()
	var phi := (1.0 + sqrt(5.0)) * 0.5
	match shape:
		4:
			v = PackedVector3Array([Vector3(1, 1, 1), Vector3(1, -1, -1), Vector3(-1, 1, -1), Vector3(-1, -1, 1)])
		6:
			for x in [-1.0, 1.0]:
				for y in [-1.0, 1.0]:
					for z in [-1.0, 1.0]:
						v.append(Vector3(x, y, z))
		8:
			v = PackedVector3Array([Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, -1, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)])
		10:
						# a pentagonal trapezohedron: two points and a zigzag ring, as high as lays each kite flat. In the kite's plane the point, the ring's near corner and its far corner must lie on one line,
						# so point / ring = (1 + cos 36) / (1 - cos 36) (9.47)
			var c := cos(deg_to_rad(36.0))
			var ring := (1.0 - c) / (1.0 + c)
			v.append(Vector3(0, 1, 0))
			v.append(Vector3(0, -1, 0))
			for k in 10:
				var a := deg_to_rad(36.0 * float(k))
				v.append(Vector3(cos(a), ring if k % 2 == 0 else -ring, sin(a)))
		12:
			for x in [-1.0, 1.0]:
				for y in [-1.0, 1.0]:
					for z in [-1.0, 1.0]:
						v.append(Vector3(x, y, z))
			for a in [-1.0, 1.0]:
				for b in [-1.0, 1.0]:
					v.append(Vector3(0, a / phi, b * phi))
					v.append(Vector3(a / phi, b * phi, 0))
					v.append(Vector3(a * phi, 0, b / phi))
		20:
			for a in [-1.0, 1.0]:
				for b in [-1.0, 1.0]:
					v.append(Vector3(0, a, b * phi))
					v.append(Vector3(a, b * phi, 0))
					v.append(Vector3(a * phi, 0, b))
	var most := 0.0
	for p in v:
		most = maxf(most, p.length())
	for i in v.size():
		v[i] = v[i] / most
	return v


## Its faces, from its vertices: every plane through three of them with all the rest on one side, the corners of each found once, in order round its middle.
static func _faces_of(v: PackedVector3Array) -> Array:
	var seen := {}
	var faces: Array = []
	for i in v.size():
		for j in range(i + 1, v.size()):
			for k in range(j + 1, v.size()):
				var n := (v[j] - v[i]).cross(v[k] - v[i])
				if n.length() < 1e-6:
					continue
				n = n.normalized()
				var d := n.dot(v[i])
				if d < 0.0:
					n = -n
					d = -d
				var outside := false
				var on: Array = []
				for m in v.size():
					var off := n.dot(v[m]) - d
					if off > 1e-4:
						outside = true
						break
					if off > -1e-4:
						on.append(m)
				if outside:
					continue
				on.sort()
				var key := str(on)
				if seen.has(key):
					continue
				seen[key] = true
				faces.append(_face(v, on, n))
	return faces


static func _face(v: PackedVector3Array, on: Array, n: Vector3) -> Dictionary:
	var center := Vector3.ZERO
	for m in on:
		center += v[int(m)]
	center /= float(on.size())
	var x := (v[int(on[0])] - center).normalized()
	var y := n.cross(x)
	var ring: Array = on.duplicate()
	ring.sort_custom(func(a: int, b: int) -> bool:
		var pa: Vector3 = v[a] - center
		var pb: Vector3 = v[b] - center
		return atan2(pa.dot(y), pa.dot(x)) < atan2(pb.dot(y), pb.dot(x)))
	return {"normal": n, "center": center, "ring": ring}


## Where each number is printed, as real dice have them: a number and its opposite add up alike, taken up the die in turn. (Which face a real maker gives which pair varies from maker to maker.) A four has no opposites.
static func _printing(faces: Array, shape: int) -> Array:
	var n := faces.size()
	var printed: Array = []
	printed.resize(n)
	printed.fill(-1)
	var used := {}
	var low := 0
	for i in n:
		if used.has(i):
			continue
		var opposite := -1
		for j in n:
			if j != i and not used.has(j) and ((faces[i] as Dictionary)["normal"] as Vector3).dot((faces[j] as Dictionary)["normal"]) < -0.999:
				opposite = j
				break
		printed[low] = i
		used[i] = true
		if opposite >= 0 and shape != 4:
			printed[n - 1 - low] = opposite
			used[opposite] = true
		low += 1
	# (a shape without opposites takes up what is left in turn)
	if printed.has(-1):
		for f in n:
			if printed[f] == -1:
				for i in n:
					if not used.has(i):
						printed[f] = i
						used[i] = true
						break
	return printed


## What landed: the solid's face showing, for a body turned by [param basis]: the one looking up (`dot` how squarely, 1 flat), or, on a four, the one it lies on.
static func landed(shape: int, basis: Basis) -> Dictionary:
	var sd := solid(shape)
	var up := Vector3.UP
	var best := -1
	var most := -2.0
	var faces: Array = sd["faces"]
	for i in faces.size():
		var n: Vector3 = basis * ((faces[i] as Dictionary)["normal"] as Vector3)
		var d := n.dot(-up if shape == 4 else up)
		if d > most:
			most = d
			best = i
	return {"face": best, "dot": most}


## How squarely a body lies at rest when it is really lying flat, face to the table: a cocked die fails this and is thrown again ([DiceBake]). The cone a face must be within, as a dot.
static func flat_enough(shape: int) -> float:
	# (a twenty's next face is only 42 degrees off, and it lies truly flat or not at all)
	return 0.997 if shape == 20 or shape == 12 else 0.995


## The turn that prints face [param printed_face] on solid face [param solid_face]: a rotation of the solid onto itself, in the body's own coordinates. The body is drawn as `body_transform * turn`.
static func turn_for(shape: int, printed_face: int, solid_face: int) -> Basis:
	var printed: Array = solid(shape)["printed"]
	return rotation_between(shape, int(printed[clampi(printed_face, 0, printed.size() - 1)]), solid_face)


## A rotation of the solid taking its face [param from] onto its face [param to]: found by trying each corner of the far face for one near corner, and kept when every vertex lands on a vertex.
static func rotation_between(shape: int, from: int, to: int) -> Basis:
	if from == to:
		return Basis.IDENTITY
	var sd := solid(shape)
	var verts: PackedVector3Array = sd["verts"]
	var a: Dictionary = (sd["faces"] as Array)[from]
	var b: Dictionary = (sd["faces"] as Array)[to]
	var ca: Vector3 = a["center"]
	var cb: Vector3 = b["center"]
	var ax: Vector3 = (verts[int((a["ring"] as Array)[0])] - ca).normalized()
	var fa := _frame(a["normal"], ax)
	for corner in b["ring"]:
		var bx: Vector3 = (verts[int(corner)] - cb).normalized()
		var r := _frame(b["normal"], bx) * fa.inverse()
		if _is_symmetry(verts, r):
			return r
	push_error("Dice: no rotation of the %d takes face %d to face %d" % [shape, from, to])
	return Basis.IDENTITY


static func _frame(n: Vector3, x: Vector3) -> Basis:
	var y := n.cross(x).normalized()
	return Basis(x, y, n)


static func _is_symmetry(verts: PackedVector3Array, r: Basis) -> bool:
	for p in verts:
		var q: Vector3 = r * p
		var found := false
		for s in verts:
			if q.distance_to(s) < 1e-3:
				found = true
				break
		if not found:
			return false
	return true


## What is printed on each face: a thrown die's `sides` and any names of its own ([DiceNotation] `labels`), one text per printed face: 00 to 90 on a percentile's tens, 0 to 9 on a ten, a two and a three on a six numbered over.
static func labels_of(shape: int, sides: int, names: PackedStringArray = PackedStringArray()) -> PackedStringArray:
	var out := PackedStringArray()
	if not names.is_empty():
		for k in shape:
			out.append(names[k % names.size()])
		return out
	if sides == 100:
		for k in 10:
			out.append("%d0" % k if k > 0 else "00")
		return out
	if sides == 10:
		for k in 10:
			out.append(str(k))
		return out
	if sides < shape:
		var each := shape / sides
		for k in shape:
			out.append(str(k / each + 1))
		return out
	for k in shape:
		out.append(str(k + 1))
	return out


## Its convex shape's corners, at [param scale] across: what [DiceBake] gives the physics.
static func hull(shape: int, scale: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	for p in solid(shape)["verts"]:
		out.append(p * radius_of(shape) * scale)
	return out


## How far a corner of this shape stands from its middle, in meters, at size 1.
static func radius_of(shape: int) -> float:
	var sd := solid(shape)
	# ...measured as a player measures: across its flats or its points, as [constant SHAPES] says
	return float((SHAPES[shape] as Dictionary)["size"]) * 0.5 / ((sd["faces"] as Array)[0]["center"] as Vector3).length() if shape != 4 else float((SHAPES[shape] as Dictionary)["size"]) * 0.75


# --- drawn --------------------------------------------------------------------------------------------------------------------------------------------

## The die's mesh: two surfaces, its body (edges rounded back: each face drawn in from its corners, a strip across each edge and a little fan over each corner, normals running between) and its print. One per shape and printing, kept.
static func mesh_of(shape: int, labels: PackedStringArray) -> ArrayMesh:
	var key := "%d:%s" % [shape, ",".join(labels)]
	_lock.lock()
	var had: ArrayMesh = _meshes.get(key)
	_lock.unlock()
	if had != null:
		return had
	var sd := solid(shape)
	var r := radius_of(shape)
	var mesh := ArrayMesh.new()
	var body := _body_arrays(sd, r)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, body)
	var ink := _print_arrays(sd, shape, labels, r)
	if not (ink[Mesh.ARRAY_VERTEX] as PackedVector3Array).is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, ink)
	_lock.lock()
	_meshes[key] = mesh
	_lock.unlock()
	return mesh


static func _body_arrays(sd: Dictionary, r: float) -> Array:
	var verts: PackedVector3Array = sd["verts"]
	var faces: Array = sd["faces"]
	var pos := PackedVector3Array()
	var nor := PackedVector3Array()
	# each face's corners drawn in toward its middle: where it is flat
	var inset: Array = []
	for f in faces:
		var d: Dictionary = f
		var pts := {}
		for corner in d["ring"]:
			pts[int(corner)] = (verts[int(corner)].lerp(d["center"], BEVEL)) * r
		inset.append(pts)
	for i in faces.size():
		var d: Dictionary = faces[i]
		var ring: Array = d["ring"]
		var n: Vector3 = d["normal"]
		for k in range(1, ring.size() - 1):
			_tri(pos, nor, inset[i][int(ring[0])], inset[i][int(ring[k])], inset[i][int(ring[k + 1])], n, n, n)
	# a strip across every edge two faces share
	for i in faces.size():
		var a: Dictionary = faces[i]
		var ring: Array = a["ring"]
		for k in ring.size():
			var p := int(ring[k])
			var q := int(ring[(k + 1) % ring.size()])
			for j in range(i + 1, faces.size()):
				var b: Dictionary = faces[j]
				if (b["ring"] as Array).has(p) and (b["ring"] as Array).has(q):
					var na: Vector3 = a["normal"]
					var nb: Vector3 = b["normal"]
					_tri(pos, nor, inset[i][p], inset[j][p], inset[j][q], na, nb, nb)
					_tri(pos, nor, inset[i][p], inset[j][q], inset[i][q], na, nb, na)
	# a little fan over every corner
	for v in verts.size():
		var round: Array = []
		var mid := Vector3.ZERO
		for i in faces.size():
			if (faces[i]["ring"] as Array).has(v):
				round.append({"at": inset[i][v], "n": faces[i]["normal"]})
				mid += inset[i][v]
		if round.size() < 3:
			continue
		mid /= float(round.size())
		var out := verts[v].normalized()
		var x := (((round[0] as Dictionary)["at"] as Vector3) - mid).normalized()
		var y := out.cross(x)
		round.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var pa: Vector3 = (a["at"] as Vector3) - mid
			var pb: Vector3 = (b["at"] as Vector3) - mid
			return atan2(pa.dot(y), pa.dot(x)) < atan2(pb.dot(y), pb.dot(x)))
		var tip := mid + out * r * BEVEL * 0.12
		for k in round.size():
			var u: Dictionary = round[k]
			var w: Dictionary = round[(k + 1) % round.size()]
			_tri(pos, nor, tip, u["at"], w["at"], out, u["n"], w["n"])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pos
	arrays[Mesh.ARRAY_NORMAL] = nor
	return arrays


## One triangle, wound so its first normal looks out of the side it was made for.
static func _tri(pos: PackedVector3Array, nor: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3) -> void:
	if (b - a).cross(c - a).dot(na + nb + nc) > 0.0:
		# (Godot's front face winds clockwise, seen from outside)
		pos.append_array([a, c, b])
		nor.append_array([na, nc, nb])
	else:
		pos.append_array([a, b, c])
		nor.append_array([na, nb, nc])


## Its print: each number laid on its face, from [TextMesh], as a surface of its own (a face has its number in its middle; a four's has three, one at each corner, for the point it stands by).
static func _print_arrays(sd: Dictionary, shape: int, labels: PackedStringArray, r: float) -> Array:
	var pos := PackedVector3Array()
	var nor := PackedVector3Array()
	var idx := PackedInt32Array()
	var font: Font = load(FONT) as Font
	var faces: Array = sd["faces"]
	var printed: Array = sd["printed"]
	var verts: PackedVector3Array = sd["verts"]
	var read := float((SHAPES[shape] as Dictionary)["read"])
	if font == null:
		return _as_arrays(pos, nor, idx)
	var corner_of := {}
	if shape == 4:
		# a face's number is the number of the point it does not touch
		for f in printed.size():
			var face: Dictionary = faces[int(printed[f])]
			for v in verts.size():
				if not (face["ring"] as Array).has(v):
					corner_of[v] = f
	for f in printed.size():
		var face: Dictionary = faces[int(printed[f])]
		var n: Vector3 = face["normal"]
		var center: Vector3 = face["center"]
		var ring: Array = face["ring"]
		var far := 0.0
		for corner in ring:
			far = maxf(far, (verts[int(corner)] - center).length())
		if shape == 4:
			for corner in ring:
				var toward: Vector3 = (verts[int(corner)] - center).normalized()
				var at: Vector3 = center + toward * far * 0.52
				_lay(pos, nor, idx, font, labels[int(corner_of[int(corner)])], at, n, toward, far * read * r, r)
			continue
		var along: Vector3 = (verts[int(ring[0])] - center).normalized()
		var text := labels[f] if f < labels.size() else ""
		_lay(pos, nor, idx, font, _marked(text), center, n, along, far * read * r, r)
	return _as_arrays(pos, nor, idx)


## A six and a nine are told apart, as dice do.
static func _marked(text: String) -> String:
	return text + "." if text == "6" or text == "9" else text


static func _as_arrays(pos: PackedVector3Array, nor: PackedVector3Array, idx: PackedInt32Array) -> Array:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pos
	arrays[Mesh.ARRAY_NORMAL] = nor
	arrays[Mesh.ARRAY_INDEX] = idx
	return arrays


static func _lay(pos: PackedVector3Array, nor: PackedVector3Array, idx: PackedInt32Array, font: Font, text: String, at: Vector3, n: Vector3, up: Vector3, height: float, r: float) -> void:
	if text.is_empty():
		return
	var tm := TextMesh.new()
	tm.font = font
	tm.text = text
	tm.font_size = 64
	tm.depth = 0.0
	tm.curve_step = 0.25
	var got: Array = tm.get_mesh_arrays()
	if got.is_empty() or got[Mesh.ARRAY_VERTEX] == null:
		return
	var src: PackedVector3Array = got[Mesh.ARRAY_VERTEX]
	if src.is_empty():
		return
	# ...the text's own box, centered and scaled to the height asked for
	var lo := src[0]
	var hi := src[0]
	for p in src:
		lo = Vector3(minf(lo.x, p.x), minf(lo.y, p.y), minf(lo.z, p.z))
		hi = Vector3(maxf(hi.x, p.x), maxf(hi.y, p.y), maxf(hi.z, p.z))
	var box := hi - lo
	var mid := (lo + hi) * 0.5
	var s := height / maxf(maxf(box.y, box.x * 0.7), 1e-6)
	var right := up.cross(n).normalized()
	var base := pos.size()
	var flip := false
	var src_i: PackedInt32Array = got[Mesh.ARRAY_INDEX] if got[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	for p in src:
		var q := (p - mid) * s
		pos.append(at * r + right * q.x + up * q.y + n * r * PRINT_LIFT)
		nor.append(n)
	if src_i.is_empty():
		for i in src.size():
			src_i.append(i)
	# (the text's triangles keep the winding they had, seen from +z: which is the outside, here too)
	for i in src_i:
		idx.append(base + int(i))
	flip = flip
