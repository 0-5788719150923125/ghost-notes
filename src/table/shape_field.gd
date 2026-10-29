extends RefCounted
class_name ShapeField

## ShapeField - A SOLID'S SIGNED DISTANCE, in its own space (meters): negative inside it, positive outside, and the
## way out (next/table_physics.md, "Grains and loose things"). What every grain and loose thing on the table
## ([Particles]) is kept out of, made from the part as [Props] built it - never from its triangles, which would be
## too slow to measure in GDScript:
##
##   - a LATHE exactly: a 2D field by radius and height of its profile as it was turned ([method Props.lathe_profile]),
##     its lobes and flat sides aside;
##   - an EXTRUDE exactly: its outline's 2D field raised to its height - and, with a `wall`, hollowed as [method
##     Props._extrude] hollows it, its inside the outline drawn smaller about its middle above its floor;
##   - a BOX, a BALL, a RING, a crystal POINT and a TUBE's segments in closed forms, inside the box the built
##     geometry measured;
##   - anything else as that box, its corners rounded.
##
## A warp's `scale` is undone before a point is measured (its distance scaled back by the least of it); its other
## bends are not. The 2D fields are kept only near the outline (a narrow band of [constant BAND] cells): what is
## further than that is far, which is all a particle asks.

## A 2D field's cells along its longest side (at most), and the least and most a cell may be (meters).
const CELLS := 72
const CELL := Vector2(0.0003, 0.0016)
## How many cells either side of an outline its distance is measured (beyond, it is this far and no further).
const BAND := 6

var kind := "box"             # lathe, extrude, box, ball, ring, capsules
## The part's box as built, in its own space (meters): what a broad test asks of it.
var box := AABB()
var scale := Vector3.ONE      # a warp's scale, undone before a point is measured
var pivot := Vector3.ZERO     # ...about this
var _least := 1.0             # the least of the scale: a distance scaled back by it
var spec: Dictionary = {}     # the part as written, made safe
var ready := false
# a 2D field (lathe: x radius, y height; extrude: x and z), over [g0, g0 + cell * (gw - 1, gh - 1)]
var grid := PackedFloat32Array()
var gw := 0
var gh := 0
var cell := 0.001
var g0 := Vector2.ZERO
var prof: Array = []          # a lathe's profile, or an extrude's outline (meters)
# an extrude: its height, its hollow's floor and how much smaller its hollow's outline is, about its middle
var height := 0.0
var floor_y := 0.0
var k_in := 0.0
var mid2 := Vector2.ZERO
# a box's half sizes and its corners' radius; a ball's radii; a ring's radius and thickness; capsules' ends and radii
var half := Vector3.ONE
var round_r := 0.0
var radii := Vector3.ONE
var ring_r := 0.0
var ring_t := 0.0
var caps_a := PackedVector3Array()
var caps_b := PackedVector3Array()
var caps_r := PackedFloat32Array()


## THE SOLID PART [param part] (made safe, [method Props.sanitize]) whose geometry as built lies in [param built] (its
## own space, meters): the field of its shape. Its 2D field is made when first asked ([method prepare]).
static func of(part: Dictionary, built: AABB) -> ShapeField:
	var f := ShapeField.new()
	f.spec = part
	f.box = built
	var w: Dictionary = part.get("warp", {}) if part.get("warp") is Dictionary else {}
	var sc: Vector3 = w.get("scale", Vector3.ONE)
	f.scale = Vector3(maxf(sc.x, 0.05), maxf(sc.y, 0.05), maxf(sc.z, 0.05))
	f._least = minf(f.scale.x, minf(f.scale.y, f.scale.z))
	f.pivot = Vector3(built.get_center().x, built.position.y, built.get_center().z)
	var shape := String(part.get("shape", ""))
	var c := built.get_center()
	match shape:
		"lathe":
			f.kind = "lathe"
			f.prof = Props.lathe_profile(part)
		"extrude":
			f.kind = "extrude"
			f.prof = Props._outline2(part)
			if f.prof.size() < 3:
				f.kind = "box"
			else:
				f.height = float(part.get("height", 2.0)) * 0.01
				var wall := float(part.get("wall", 0.0)) * 0.01
				var mid := Vector2.ZERO
				for q in f.prof:
					mid += q
				mid /= float(f.prof.size())
				var reach := 0.0
				for q in f.prof:
					reach += (q as Vector2).distance_to(mid)
				reach = maxf(reach / float(f.prof.size()), 0.001)
				f.mid2 = mid
				if wall > 0.0:
					f.k_in = clampf(1.0 - wall / reach, 0.15, 0.95)
					f.floor_y = minf(wall, f.height * 0.5)
		"ball":
			f.kind = "ball"
			f.radii = built.size * 0.5
		"ring":
			f.kind = "ring"
			f.ring_r = float(part.get("radius", 3.0)) * 0.01
			f.ring_t = float(part.get("thickness", 0.4)) * 0.01
		"point":
			f.kind = "capsules"
			var r := minf(built.size.x, built.size.z) * 0.5
			f.caps_a.append(Vector3(c.x, built.position.y + r, c.z))
			f.caps_b.append(Vector3(c.x, maxf(built.end.y - r, built.position.y + r), c.z))
			f.caps_r.append(r)
		"tube":
			f.kind = "capsules"
			var raw: Array = []
			for q in (part["path"] as Array):
				raw.append((q as Vector3) * 0.01)
			var cv := Props._curve(raw, Props._rounds_m(part, raw.size()), bool(part.get("smooth", true)), 4)
			var pts: Array = cv["pts"]
			var src: PackedFloat32Array = cv["src"]
			var rs: PackedFloat32Array = part.get("radii", PackedFloat32Array())
			var base_r := float(part.get("radius", 0.3)) * 0.01
			for i in pts.size() - 1:
				var k := floori(src[i])
				var r := lerpf(Props._radius_at(rs, k, base_r), Props._radius_at(rs, k + 1, base_r), src[i] - float(k))
				f.caps_a.append(pts[i])
				f.caps_b.append(pts[i + 1])
				f.caps_r.append(r)
			if f.caps_a.is_empty():
				f.kind = "box"
		_:
			f.kind = "box"
	if f.kind == "box":
		f.half = built.size * 0.5
		f.round_r = minf(float(part.get("round", 0.0)) * 0.01, minf(f.half.x, minf(f.half.y, f.half.z))) \
			if shape == "box" else minf(f.half.x, minf(f.half.y, f.half.z)) * 0.3
	f.ready = not (f.kind in ["lathe", "extrude"])
	return f


## Whether this solid has a hollow a thing can be put in: a lathe whose profile comes back down inside it, or a walled
## extrude.
func hollow() -> bool:
	if kind == "extrude":
		return k_in > 0.0
	if kind != "lathe" or prof.size() < 3:
		return false
	var top := -INF
	for q in prof:
		top = maxf(top, (q as Vector2).y)
	return top - (prof[prof.size() - 1] as Vector2).y > 0.003


## THE 2D FIELD, made once: a lathe's by radius and height, an extrude's across its plan - each cell its distance to the
## outline (within the band; further is the band's), less inside.
func prepare() -> void:
	if ready:
		return
	ready = true
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for q in prof:
		lo = Vector2(minf(lo.x, (q as Vector2).x), minf(lo.y, (q as Vector2).y))
		hi = Vector2(maxf(hi.x, (q as Vector2).x), maxf(hi.y, (q as Vector2).y))
	var ext := maxf(hi.x - lo.x, hi.y - lo.y)
	cell = clampf(ext / float(CELLS), CELL.x, CELL.y)
	var margin := cell * float(BAND + 2)
	if kind == "lathe":
		lo.x = 0.0
	g0 = lo - Vector2(0.0 if kind == "lathe" else margin, margin)
	gw = int(ceil((hi.x + margin - g0.x) / cell)) + 1
	gh = int(ceil((hi.y + margin - g0.y) / cell)) + 1
	var far := cell * float(BAND)
	grid = PackedFloat32Array()
	grid.resize(gw * gh)
	grid.fill(far)
	# the outline's own edges: a lathe's profile (its closing run up the axis is inside it, not a face of it), an
	# extrude's outline all round
	var n := prof.size()
	var edges := n - 1 if kind == "lathe" else n
	for e in edges:
		var a: Vector2 = prof[e]
		var b: Vector2 = prof[(e + 1) % n]
		var i0 := maxi(int(floor((minf(a.x, b.x) - g0.x) / cell)) - BAND, 0)
		var i1 := mini(int(ceil((maxf(a.x, b.x) - g0.x) / cell)) + BAND, gw - 1)
		var j0 := maxi(int(floor((minf(a.y, b.y) - g0.y) / cell)) - BAND, 0)
		var j1 := mini(int(ceil((maxf(a.y, b.y) - g0.y) / cell)) + BAND, gh - 1)
		var ab := b - a
		var l2 := maxf(ab.length_squared(), 1e-14)
		for j in range(j0, j1 + 1):
			var py := g0.y + float(j) * cell
			for i in range(i0, i1 + 1):
				var q := Vector2(g0.x + float(i) * cell, py)
				var t := clampf((q - a).dot(ab) / l2, 0.0, 1.0)
				var d := q.distance_to(a + ab * t)
				var k := j * gw + i
				if d < grid[k]:
					grid[k] = d
	# INSIDE IS LESS: each row's crossings of the closed outline (a lathe's closed up its axis)
	for j in gh:
		var py := g0.y + float(j) * cell
		var xs := PackedFloat32Array()
		for e in n:
			var a: Vector2 = prof[e]
			var b: Vector2 = prof[(e + 1) % n]
			if (a.y > py) != (b.y > py):
				xs.append(a.x + (py - a.y) / (b.y - a.y) * (b.x - a.x))
		if xs.is_empty():
			continue
		xs.sort()
		var row := j * gw
		var c := 0
		for i in gw:
			var px := g0.x + float(i) * cell
			# a crossing at the cell counts (a lathe's axis, where its closing run is, is inside it)
			while c < xs.size() and xs[c] <= px:
				c += 1
			if c % 2 == 1:
				grid[row + i] = -grid[row + i]


## A 2D field's distance at [param q] and its slope: `Vector3(d, dd/dx, dd/dy)`. Off the field, the edge's, and as far
## again as it is off.
func _at2(q: Vector2) -> Vector3:
	var fx := (q.x - g0.x) / cell
	var fy := (q.y - g0.y) / cell
	var cx := clampf(fx, 0.0, float(gw - 1) - 0.001)
	var cy := clampf(fy, 0.0, float(gh - 1) - 0.001)
	var i := int(cx)
	var j := int(cy)
	var tx := cx - float(i)
	var ty := cy - float(j)
	var k := j * gw + i
	var d00 := grid[k]
	var d10 := grid[k + 1]
	var d01 := grid[k + gw]
	var d11 := grid[k + gw + 1]
	var d := lerpf(lerpf(d00, d10, tx), lerpf(d01, d11, tx), ty)
	var gx := lerpf(d10 - d00, d11 - d01, ty) / cell
	var gy := lerpf(d01 - d00, d11 - d10, tx) / cell
	var off := Vector2((fx - cx) * cell, (fy - cy) * cell)
	return Vector3(d + off.length(), gx, gy)


## THE DISTANCE AT [param p] (its own space, meters) and which way is out: `Vector4(d, nx, ny, nz)`, the normal unit
## length (or up, where it cannot be told).
func sample(p: Vector3) -> Vector4:
	if not ready:
		prepare()
	var q := p
	if scale != Vector3.ONE:
		q = pivot + (p - pivot) / scale
	var out := _local(q)
	if scale != Vector3.ONE:
		var n := Vector3(out.y, out.z, out.w) / scale
		var l := n.length()
		n = n / l if l > 1e-9 else Vector3.UP
		out = Vector4(out.x * _least, n.x, n.y, n.z)
	return out


func _local(q: Vector3) -> Vector4:
	if kind == "lathe":
		var r := sqrt(q.x * q.x + q.z * q.z)
		var s := _at2(Vector2(r, q.y))
		var n := Vector3(s.y * q.x / r, s.z, s.y * q.z / r) if r > 1e-6 else Vector3(0.0, signf(s.z) if s.z != 0.0 else 1.0, 0.0)
		return _with(s.x, n)
	match kind:
		"lathe":
			var r := sqrt(q.x * q.x + q.z * q.z)
			var s := _at2(Vector2(r, q.y))
			var n := Vector3(s.y * q.x / r, s.z, s.y * q.z / r) if r > 1e-6 else Vector3(0.0, signf(s.z) if s.z != 0.0 else 1.0, 0.0)
			return _with(s.x, n)
		"extrude":
			var d := _extrude_d(q)
			var e := cell * 0.5
			var n := Vector3(_extrude_d(q + Vector3(e, 0, 0)) - _extrude_d(q - Vector3(e, 0, 0)),
				_extrude_d(q + Vector3(0, e, 0)) - _extrude_d(q - Vector3(0, e, 0)),
				_extrude_d(q + Vector3(0, 0, e)) - _extrude_d(q - Vector3(0, 0, e)))
			return _with(d, n)
		"ball":
			var c := box.get_center()
			var rr := Vector3(maxf(radii.x, 1e-4), maxf(radii.y, 1e-4), maxf(radii.z, 1e-4))
			var v := q - c
			var k0 := (v / rr).length()
			var k1 := (v / (rr * rr)).length()
			var d := k0 * (k0 - 1.0) / maxf(k1, 1e-9)
			return _with(d, v / (rr * rr))
		"ring":
			var c := box.get_center()
			var v := q - c
			var rr := sqrt(v.x * v.x + v.z * v.z)
			var t := Vector2(rr - ring_r, v.y)
			var d := t.length() - ring_t
			var radial := Vector3(v.x / rr, 0.0, v.z / rr) if rr > 1e-6 else Vector3.RIGHT
			return _with(d, radial * t.x + Vector3.UP * t.y)
		"capsules":
			var best := INF
			var bn := Vector3.UP
			for i in caps_a.size():
				var a := caps_a[i]
				var ab := caps_b[i] - a
				var t := clampf((q - a).dot(ab) / maxf(ab.length_squared(), 1e-12), 0.0, 1.0)
				var v := q - (a + ab * t)
				var d := v.length() - caps_r[i]
				if d < best:
					best = d
					bn = v
			return _with(best, bn)
	# a box, its corners rounded
	var c := box.get_center()
	var v := q - c
	var inner := half - Vector3(round_r, round_r, round_r)
	var w := Vector3(absf(v.x), absf(v.y), absf(v.z)) - inner
	var outside := Vector3(maxf(w.x, 0.0), maxf(w.y, 0.0), maxf(w.z, 0.0))
	var d := outside.length() + minf(maxf(w.x, maxf(w.y, w.z)), 0.0) - round_r
	var n := Vector3(signf(v.x) * outside.x, signf(v.y) * outside.y, signf(v.z) * outside.z)
	if n.length() < 1e-9:
		# inside: out through the nearest face
		if w.x >= w.y and w.x >= w.z:
			n = Vector3(signf(v.x), 0.0, 0.0)
		elif w.y >= w.z:
			n = Vector3(0.0, signf(v.y), 0.0)
		else:
			n = Vector3(0.0, 0.0, signf(v.z))
	return _with(d, n)


static func _with(d: float, n: Vector3) -> Vector4:
	var l := n.length()
	var u := n / l if l > 1e-9 else Vector3.UP
	return Vector4(d, u.x, u.y, u.z)


## An extrude's distance at [param q]: its outline raised to its height, less its hollow.
func _extrude_d(q: Vector3) -> float:
	var d2 := _at2(Vector2(q.x, q.z)).x
	var outer := _prism(d2, q.y, 0.0, height)
	if k_in <= 0.0:
		return outer
	var inner2 := _at2(mid2 + (Vector2(q.x, q.z) - mid2) / k_in).x * k_in
	return maxf(outer, -_prism(inner2, q.y, floor_y, height + cell * 4.0))


## A prism's distance: [param d2] across, between heights [param y0] and [param y1].
static func _prism(d2: float, y: float, y0: float, y1: float) -> float:
	var dy := maxf(y0 - y, y - y1)
	var ox := maxf(d2, 0.0)
	var oy := maxf(dy, 0.0)
	return sqrt(ox * ox + oy * oy) + minf(maxf(d2, dy), 0.0)
