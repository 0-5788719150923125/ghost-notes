extends RefCounted
class_name Vessel

## Vessel - THE INSIDE OF A HOLLOW PART, what a liquid fills (next/table_physics.md, "Liquids"): a lathe's inside
## up from its inner floor to its rim, as a radius at each height ([member radius]); or a walled extrude's, its
## outline drawn smaller about its middle ([member ShapeField.k_in]) above its floor. Measured in the part's own space
## (meters), its warp's scale laid over it.
##
## What it answers is a LEVEL: the user, 2026-10-28, of a vial tipped to pour - "The liquids are not liquids". A
## liquid's surface is level in the table's space however its vessel is turned, and keeps the volume under it: the
## level for any tilt and any share of the inside is a QUANTILE of a few thousand equal-volume points filling it
## ([member points]), taken along the up the vessel sees ([method level]) - made once, as a table by tilt (a lathe
## is the same all round) or by tilt and bearing (an outline). And it answers an OVERFLOW: how much leaves over the
## rim where the liquid stands above it, as a weir's flow ([method overflow]).

## The heights a lathe's inside is measured at, the points it is filled with (about), its rim's points round, and the
## level table's tilts, bearings (an outline's) and shares.
const LEVELS := 48
const POINTS := 1800
const RIM := 48
const TILTS := 37
const BEARINGS := 16
const SHARES := 41
## A WEIR's coefficient of discharge (a sharp crest, Q = 2/3 Cd sqrt(2g) b H^3/2) and gravity.
const CD := 0.62
const GRAVITY := 9.81
## How far inside its walls the liquid drawn in it stands (meters): never in the vessel's own surface.
const INSET := 0.0004

var field: ShapeField
var floor_y := 0.0            # where the inside begins (its own space, meters, unwarped)
var top_y := 0.0              # ...and its rim
var heights := PackedFloat32Array()
var radius := PackedFloat32Array()   # a lathe's inside radius at each height
var points := PackedVector3Array()   # equal volumes filling it (warped)
var volume := 0.0             # cubic meters
var rim := PackedVector3Array()      # its crest, the inside's top edge, round (warped)
var lip := PackedVector3Array()      # ...and where what flows over it leaves, the rim's outer edge there
var _arc := 0.0               # the crest's length a rim point stands for
var _levels: Array = []       # [tilt][bearing] -> PackedFloat32Array of heights along up, a share apiece


## THE INSIDE OF [param f], or null when it has none (a solid part, a shallow one).
static func of(f: ShapeField) -> Vessel:
	if f == null or not f.hollow():
		return null
	f.prepare()
	var v := Vessel.new()
	v.field = f
	if f.kind == "lathe":
		if not v._measure_lathe():
			return null
	else:
		v.floor_y = f.floor_y
		v.top_y = f.height
	v._fill()
	if v.points.size() < 20:
		return null
	v._rim()
	v._table()
	return v


## A lathe's inside: from its inner floor (where its profile meets the axis at its end) to the top of its rim, the
## inside radius at each height - the first crossing of its profile out from the axis.
func _measure_lathe() -> bool:
	var prof := field.prof
	top_y = -INF
	for q in prof:
		top_y = maxf(top_y, (q as Vector2).y)
	floor_y = (prof[prof.size() - 1] as Vector2).y
	if top_y - floor_y < 0.003:
		return false
	var n := prof.size()
	for k in LEVELS:
		var y := lerpf(floor_y, top_y, (float(k) + 0.5) / float(LEVELS))
		var first := INF
		for e in n - 1:
			var a: Vector2 = prof[e]
			var b: Vector2 = prof[e + 1]
			if (a.y > y) != (b.y > y):
				var x := a.x + (y - a.y) / (b.y - a.y) * (b.x - a.x)
				if x > 1e-5:
					first = minf(first, x)
		heights.append(y)
		radius.append(maxf(first - INSET, 0.0) if first < INF else 0.0)
	return true


## The inside's radius at height [param y] (unwarped), or -1 outside its heights.
func radius_at(y: float) -> float:
	if y < floor_y or y > top_y or heights.is_empty():
		return -1.0
	var f := clampf((y - floor_y) / maxf(top_y - floor_y, 1e-6) * float(LEVELS) - 0.5, 0.0, float(LEVELS - 1))
	var i := mini(int(f), LEVELS - 2)
	return lerpf(radius[i], radius[i + 1], f - float(i))


## Whether [param p] (the part's own space, warped, meters) is in the inside.
func contains(p: Vector3) -> bool:
	var q := p
	if field.scale != Vector3.ONE:
		q = field.pivot + (p - field.pivot) / field.scale
	return _inside(q)


## Whether [param q] (unwarped) is in the inside.
func _inside(q: Vector3) -> bool:
	if q.y < floor_y or q.y > top_y:
		return false
	if field.kind == "lathe":
		var r := radius_at(q.y)
		return r > 0.0 and q.x * q.x + q.z * q.z < r * r
	var inner := field._at2(field.mid2 + (Vector2(q.x, q.z) - field.mid2) / field.k_in).x * field.k_in
	return inner < -INSET


## EQUAL VOLUMES FILLING IT: the middles of the cells of an even grid that fall inside - each the same volume, so a
## level is a quantile of their heights.
func _fill() -> void:
	var lo: Vector3
	var hi: Vector3
	if field.kind == "lathe":
		var rmax := 0.0
		for r in radius:
			rmax = maxf(rmax, r)
		lo = Vector3(-rmax, floor_y, -rmax)
		hi = Vector3(rmax, top_y, rmax)
	else:
		var b := field.box
		var b0 := field.pivot + (b.position - field.pivot) / field.scale
		var b1 := field.pivot + (b.end - field.pivot) / field.scale
		lo = Vector3(b0.x, floor_y, b0.z)
		hi = Vector3(b1.x, top_y, b1.z)
	var size := hi - lo
	# a lathe fills about pi/4 of its box
	var guess := maxf(size.x * size.y * size.z * (0.785 if field.kind == "lathe" else 0.8), 1e-12)
	var c := pow(guess / float(POINTS), 1.0 / 3.0)
	var nx := maxi(int(ceil(size.x / c)), 1)
	var ny := maxi(int(ceil(size.y / c)), 1)
	var nz := maxi(int(ceil(size.z / c)), 1)
	var cx := size.x / float(nx)
	var cy := size.y / float(ny)
	var cz := size.z / float(nz)
	points = PackedVector3Array()
	for j in ny:
		var y := lo.y + (float(j) + 0.5) * cy
		var r := radius_at(y) if field.kind == "lathe" else 0.0
		for i in nx:
			var x := lo.x + (float(i) + 0.5) * cx
			for k in nz:
				var z := lo.z + (float(k) + 0.5) * cz
				var inside := (x * x + z * z < r * r) if field.kind == "lathe" else _inside(Vector3(x, y, z))
				if inside:
					points.append(_warped(Vector3(x, y, z)))
	var sc := field.scale
	volume = float(points.size()) * cx * cy * cz * sc.x * sc.y * sc.z


## [param q] (unwarped, the part's own space) as the warp lays it.
func warp_point(q: Vector3) -> Vector3:
	return _warped(q)


func _warped(q: Vector3) -> Vector3:
	return field.pivot + (q - field.pivot) * field.scale if field.scale != Vector3.ONE else q


## ITS CREST, round the inside's top edge, and where what goes over it leaves: the rim's outer edge at the same bearing.
func _rim() -> void:
	rim = PackedVector3Array()
	lip = PackedVector3Array()
	if field.kind == "lathe":
		var r_in := radius_at(top_y - 0.0005)
		var r_out := 0.0
		for q in field.prof:
			if (q as Vector2).y > top_y - 0.002:
				r_out = maxf(r_out, (q as Vector2).x)
		r_out = maxf(r_out, r_in)
		for k in RIM:
			var a := TAU * float(k) / float(RIM)
			var d := Vector3(cos(a), 0.0, sin(a))
			rim.append(_warped(d * r_in + Vector3(0.0, top_y, 0.0)))
			lip.append(_warped(d * (r_out + 0.0005) + Vector3(0.0, top_y, 0.0)))
	else:
		var n := field.prof.size()
		var perim := 0.0
		for i in n:
			perim += (field.prof[i] as Vector2).distance_to(field.prof[(i + 1) % n])
		for k in RIM:
			var s := perim * float(k) / float(RIM)
			var q := Vector2.ZERO
			for i in n:
				var a: Vector2 = field.prof[i]
				var b: Vector2 = field.prof[(i + 1) % n]
				var l := a.distance_to(b)
				if s <= l:
					q = a.lerp(b, s / maxf(l, 1e-9))
					break
				s -= l
			var inner := field.mid2 + (q - field.mid2) * field.k_in
			rim.append(_warped(Vector3(inner.x, top_y, inner.y)))
			lip.append(_warped(Vector3(q.x, top_y, q.y) + Vector3(q.x - field.mid2.x, 0.0, q.y - field.mid2.y).normalized() * 0.0005))
	_arc = 0.0
	for k in rim.size():
		_arc += rim[k].distance_to(rim[(k + 1) % rim.size()])
	_arc /= float(maxi(rim.size(), 1))


## THE LEVEL TABLE: for each tilt (and, for an outline, each bearing), the heights along up that leave each share of
## the inside under them.
func _table() -> void:
	_levels = []
	var bearings := 1 if field.kind == "lathe" else BEARINGS
	var n := points.size()
	var proj := PackedFloat32Array()
	proj.resize(n)
	for ti in TILTS:
		var row: Array = []
		var th := PI * float(ti) / float(TILTS - 1)
		for bi in bearings:
			var ph := TAU * float(bi) / float(bearings)
			var up := Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph))
			for i in n:
				proj[i] = points[i].dot(up)
			proj.sort()
			var s := PackedFloat32Array()
			s.resize(SHARES)
			for k in SHARES:
				var f := float(k) / float(SHARES - 1)
				var at := f * float(n - 1)
				var i0 := int(at)
				var i1 := mini(i0 + 1, n - 1)
				s[k] = lerpf(proj[i0], proj[i1], at - float(i0))
			# the empty and the full: the lowest and the highest of it, a half cell past
			row.append(s)
		_levels.append(row)


## THE LEVEL: how far along [param up] (the table's up, in the part's own space, unit) the surface stands that leaves
## [param share] (0-1) of the inside under it.
func level(up: Vector3, share: float) -> float:
	var u := up.normalized()
	var th := acos(clampf(u.y, -1.0, 1.0))
	var f := clampf(share, 0.0, 1.0) * float(SHARES - 1)
	var k0 := mini(int(f), SHARES - 2)
	var kt := f - float(k0)
	var tf := th / PI * float(TILTS - 1)
	var t0 := mini(int(tf), TILTS - 2)
	var tt := tf - float(t0)
	var bearings := (_levels[0] as Array).size()
	var at := func(ti: int, bi: int) -> float:
		var s: PackedFloat32Array = (_levels[ti] as Array)[bi]
		return lerpf(s[k0], s[k0 + 1], kt)
	if bearings == 1:
		return lerpf(at.call(t0, 0), at.call(t0 + 1, 0), tt)
	var bf := fposmod(atan2(u.z, u.x), TAU) / TAU * float(bearings)
	var b0 := int(bf) % bearings
	var b1 := (b0 + 1) % bearings
	var bt := bf - floorf(bf)
	return lerpf(lerpf(at.call(t0, b0), at.call(t0, b1), bt), lerpf(at.call(t0 + 1, b0), at.call(t0 + 1, b1), bt), tt)


## The share of the inside under a surface [param s] along [param up]: the inverse of [method level], found by halving.
func share_under(up: Vector3, s: float) -> float:
	var lo := 0.0
	var hi := 1.0
	for i in 22:
		var m := (lo + hi) * 0.5
		if level(up, m) < s:
			lo = m
		else:
			hi = m
	return (lo + hi) * 0.5


## WHAT FLOWS OVER THE RIM with the surface at [param s] along [param up]: `{q (cubic meters a second), at (the rim point
## it leaves over most), head (meters, there)}` - a weir along the part of the crest the liquid stands above.
func overflow(up: Vector3, s: float) -> Dictionary:
	var q := 0.0
	var best := -INF
	var at := -1
	for k in rim.size():
		var h := s - rim[k].dot(up)
		if h > best:
			best = h
			at = k
		if h > 0.0:
			q += (2.0 / 3.0) * CD * sqrt(2.0 * GRAVITY) * pow(h, 1.5) * _arc
	return {"q": q, "at": at, "head": best}


## How far below the surface [param s] along [param up] the deepest of the inside lies (meters): the liquid's depth.
func depth(up: Vector3, s: float) -> float:
	return maxf(s - level(up, 0.0), 0.0)


## The middle of the surface [param s] along [param up]: the inside's axis where it crosses it, or the middle of the
## points lying at it.
func surface_middle(up: Vector3, s: float) -> Vector3:
	if field.kind == "lathe" and up.y > 0.35:
		var axis_lo := _warped(Vector3(0.0, floor_y, 0.0))
		var axis_dir := _warped(Vector3(0.0, top_y, 0.0)) - axis_lo
		var t := (s - axis_lo.dot(up)) / maxf(axis_dir.dot(up), 1e-6)
		return axis_lo + axis_dir * clampf(t, 0.0, 1.0)
	var sum := Vector3.ZERO
	var n := 0
	var band := pow(volume / float(maxi(points.size(), 1)), 1.0 / 3.0) * 1.5
	for p in points:
		if absf(p.dot(up) - s) <= band:
			sum += p
			n += 1
	return sum / float(n) if n > 0 else points[0]


## The radius of the surface [param s] along [param up] (meters), as a round surface of its area would have.
func surface_radius(up: Vector3, s: float) -> float:
	if field.kind == "lathe" and up.y > 0.7:
		var y := (s / maxf(up.y, 0.05) - field.pivot.y) / maxf(field.scale.y, 0.05) + field.pivot.y
		var r := radius_at(clampf(y, floor_y, top_y))
		if r > 0.0:
			return maxf(r * sqrt(field.scale.x * field.scale.z), 0.002)
	# tipped far, or an outline: as round as the inside is on the whole
	var sc := field.scale
	return maxf(sqrt(volume / (PI * maxf((top_y - floor_y) * sc.y, 1e-4))), 0.002)


## THE INSIDE AS A SHADER READS IT ([code]prop_liquid.gdshader[/code], whose cut surface is drawn only within it): its
## radius at [constant SHADER_N] heights from its floor to its rim (a lathe's), or at as many bearings round its middle
## (an outline's) - the other all ones - its heights, its middle, its warp's scale and pivot.
const SHADER_N := 32


func shader_tables() -> Dictionary:
	var rs := PackedFloat32Array()
	var as_ := PackedFloat32Array()
	for k in SHADER_N:
		var f := float(k) / float(SHADER_N - 1)
		if field.kind == "lathe":
			rs.append(radius_at(lerpf(floor_y, top_y, f)) + INSET)
			as_.append(1.0)
		else:
			rs.append(1.0)
			as_.append(_outline_reach(-PI + TAU * f))
	return {"r": rs, "a": as_, "y": Vector2(floor_y, top_y), "mid": field.mid2 if field.kind != "lathe" else Vector2.ZERO,
		"scale": field.scale, "pivot": field.pivot}


## How far from the middle an outline's inside reaches at bearing [param a] (radians, from +x toward +z).
func _outline_reach(a: float) -> float:
	var d := Vector2(cos(a), sin(a))
	var n := field.prof.size()
	var best := 0.0
	for i in n:
		var p0: Vector2 = field.mid2 + ((field.prof[i] as Vector2) - field.mid2) * field.k_in
		var p1: Vector2 = field.mid2 + ((field.prof[(i + 1) % n] as Vector2) - field.mid2) * field.k_in
		var e := p1 - p0
		var den := d.x * e.y - d.y * e.x
		if absf(den) < 1e-12:
			continue
		var w := p0 - field.mid2
		var t := (w.x * e.y - w.y * e.x) / den
		var u := (w.x * d.y - w.y * d.x) / den
		if t > 0.0 and u >= 0.0 and u <= 1.0:
			best = maxf(best, t)
	return best


## THE INSIDE AS A PART [Props] can build (centimeters, unwarped - [method warp_point] lays the warp over what it
## makes; an outline's from its floor up, [member floor_y] below it): what a liquid in it is drawn as, cut at its
## surface.
func part_spec() -> Dictionary:
	if field.kind == "lathe":
		var prof: Array = [Vector2(0.0, floor_y * 100.0)]
		for k in LEVELS:
			prof.append(Vector2(radius[k] * 100.0, heights[k] * 100.0))
		prof.append(Vector2(radius[LEVELS - 1] * 100.0, top_y * 100.0))
		prof.append(Vector2(0.0, top_y * 100.0))
		return {"shape": "lathe", "profile": prof, "rounds": PackedFloat32Array(), "smooth": false, "sides": 0, "lobes": 0,
			"lobe_depth": 0.0, "twist": 0.0, "drips": 0.0}
	var pts: Array = []
	for q in field.prof:
		var inner := field.mid2 + ((q as Vector2) - field.mid2) * field.k_in
		pts.append(inner * 100.0)
	return {"shape": "extrude", "outline": "polygon", "points": pts, "size": Vector2.ONE, "height": (top_y - floor_y) * 100.0,
		"sides": 6, "taper": 0.0, "bevel": 0.0, "wall": 0.0}
