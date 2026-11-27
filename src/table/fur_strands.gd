extends RefCounted
class_name FurStrands

## FurStrands - a part's fur as strands ([constant Props.FUR], next/studio.md "Fur (props)"). Roots are strewn over the part's
## triangles by area in a seeded draw (each triangle its share, placed in it on a low-discrepancy run) and kept in a float texture,
## two texels a strand: its root and a number of its own, the skin's normal there and another. Beside it is one mesh of placeholder
## vertices, a triangle strip with a ribbon for each strand, which [constant Props.FUR_SHADER] lays out from VERTEX_ID and that
## texture (bent, combed, turned to the camera). The vertices' only use is the mesh's box, which holds every strand however it lies.
##
## The same mesh and fur give the same strands every build, so an export plays what the live show did. What is made is kept by the
## mesh and the fur's fields ([constant KEPT] of them), and a thing built again reuses it. Built on a worker: nothing here needs the
## tree, and the cache takes a lock.

## The most strands one part's fur has: its density over its area asks more of a large part.
const MOST := 65536
## Strands a row of the roots texture (two texels each).
const ROW := 512
## A strand's segments, root to tip. Its ribbon is two vertices a joint, with one more at each end that joins it to the next strand
## unseen (a zero-area triangle).
const SEGMENTS := 10
## How wide a strand is at its root, as a share of the space between strands.
const WIDTH := 0.3
## How far past the part's own box a strand may reach, as a share of the fur's length (bent over, waved and gathered into a lock).
const REACH := 1.35
## How many furs are kept (a windscreen's strip is some 19 MB on the graphics card).
const KEPT := 4
## A low-discrepancy run in a triangle (the plastic number's R2 sequence): strands spread evenly, never in clumps or gaps.
const R2 := Vector2(0.7548776662, 0.5698402910)

static var _kept := {}
static var _lock := Mutex.new()


## How many strands [param area] (square meters, as built) wears at [param density] strands a centimeter across, never more than
## [constant MOST].
static func count_for(area: float, density: float) -> int:
	return clampi(int(round(maxf(area, 0.0) * 1e4 * density * density)), 0, MOST)


## Vertices a strand's ribbon takes in the strip.
static func per_strand() -> int:
	return 2 * SEGMENTS + 4


## The fur of a mesh of triangles [param v] (normals [param n], every three points a triangle) as fur [param f] ([method
## Props._sanitize_fur]): {texture, mesh, count, width (m, as built)}, or {} where the mesh has no area. Kept: the same mesh and fur
## hand back what was made.
static func made(v: PackedVector3Array, n: PackedVector3Array, f: Dictionary) -> Dictionary:
	var density := float(f.get("density", 9.0))
	var length := float(f.get("length", 1.8)) * 0.01
	var shape := hash([v.size(), hash(v), hash(n)])
	var key := hash([shape, density, length])
	_lock.lock()
	var got: Variant = _kept.get(key)
	_lock.unlock()
	if got is Dictionary:
		return got
	var area := area_of(v)
	var count := count_for(area, density)
	if count <= 0 or n.size() != v.size():
		return {}
	var data := roots(v, n, count, shape)
	var rows := ceili(float(count) / ROW)
	data.resize(ROW * 2 * rows * 4)
	var img := Image.create_from_data(ROW * 2, rows, false, Image.FORMAT_RGBAF, data.to_byte_array())
	var box := AABB(v[0], Vector3.ZERO)
	for p in v:
		box = box.expand(p)
	var out := {"texture": ImageTexture.create_from_image(img), "mesh": strip(count, box.grow(length * REACH)), "count": count,
		"width": WIDTH * sqrt(area / count)}
	_lock.lock()
	_kept[key] = out
	while _kept.size() > KEPT:
		_kept.erase(_kept.keys()[0])
	_lock.unlock()
	return out


## The area of triangles [param v] (every three points one).
static func area_of(v: PackedVector3Array) -> float:
	var total := 0.0
	for t in v.size() / 3:
		var a := v[t * 3]
		total += (v[t * 3 + 1] - a).cross(v[t * 3 + 2] - a).length() * 0.5
	return total


## [param count] roots strewn over triangles [param v] (normals [param n]) by area, drawn from [param seed]: eight floats a strand -
## its root (x, y, z) and a number of its own (0..1), the skin's normal there and another number. Each triangle takes its share of
## the count by the area before it and its own (so the count is exact and no triangle is skipped by chance), placed in it on an R2
## run from a drawn start.
static func roots(v: PackedVector3Array, n: PackedVector3Array, count: int, seed: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(maxi(count, 0) * 8)
	var tris := v.size() / 3
	if count <= 0 or tris == 0 or n.size() != v.size():
		return out
	var upto := PackedFloat64Array()
	upto.resize(tris)
	var total := 0.0
	for t in tris:
		var a := v[t * 3]
		total += (v[t * 3 + 1] - a).cross(v[t * 3 + 2] - a).length() * 0.5
		upto[t] = total
	if total <= 0.0:
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var done := 0
	var j := 0
	for t in tris:
		var due := count if t == tris - 1 else mini(int(round(upto[t] / total * count)), count)
		var k := due - done
		if k <= 0:
			continue
		done = due
		var a := v[t * 3]
		var ab := v[t * 3 + 1] - a
		var ac := v[t * 3 + 2] - a
		var na := n[t * 3]
		var nab := n[t * 3 + 1] - na
		var nac := n[t * 3 + 2] - na
		var o := Vector2(rng.randf(), rng.randf())
		for i in k:
			var x := fposmod(o.x + i * R2.x, 1.0)
			var y := fposmod(o.y + i * R2.y, 1.0)
			if x + y > 1.0:
				x = 1.0 - x
				y = 1.0 - y
			var p := a + ab * x + ac * y
			var q := (na + nab * x + nac * y).normalized()
			out[j] = p.x
			out[j + 1] = p.y
			out[j + 2] = p.z
			out[j + 3] = rng.randf()
			out[j + 4] = q.x
			out[j + 5] = q.y
			out[j + 6] = q.z
			out[j + 7] = rng.randf()
			j += 8
	return out


## A strip of [param count] strands' placeholder vertices, all at [param box]'s corners so the mesh's box is that box.
static func strip(count: int, box: AABB) -> ArrayMesh:
	var verts := PackedVector3Array()
	verts.resize(count * per_strand())
	verts.fill(box.position)
	verts[1] = box.end
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, arrays)
	return m
