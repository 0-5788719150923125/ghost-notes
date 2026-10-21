extends RefCounted
class_name Geo

## Geo - small reusable polygon helpers (area, centroid, convex split, fracture, footprints).
## Shared geometry, not a scene's private code - the fracture that shatters glass
## can shatter anything.


static func area(poly: PackedVector2Array) -> float:
	var a := 0.0
	var n := poly.size()
	for i in n:
		var p := poly[i]
		var q := poly[(i + 1) % n]
		a += p.x * q.y - q.x * p.y
	return absf(a) * 0.5


static func centroid(poly: PackedVector2Array) -> Vector2:
	if poly.is_empty():
		return Vector2.ZERO
	var s := Vector2.ZERO
	for p in poly:
		s += p
	return s / float(poly.size())


## Split a convex polygon by the line through `pt` with normal `nrm`.
## Returns [front, back]; either side may have fewer than 3 points.
static func split(poly: PackedVector2Array, pt: Vector2, nrm: Vector2) -> Array:
	var front := PackedVector2Array()
	var back := PackedVector2Array()
	var n := poly.size()
	for i in n:
		var a := poly[i]
		var b := poly[(i + 1) % n]
		var da := nrm.dot(a - pt)
		var db := nrm.dot(b - pt)
		if da >= 0.0:
			front.append(a)
		else:
			back.append(a)
		if (da > 0.0) != (db > 0.0):
			var denom := da - db
			if absf(denom) > 0.00001:
				var ip := a.lerp(b, da / denom)
				front.append(ip)
				back.append(ip)
	return [front, back]


## Fracture a convex polygon into ~count convex shards by repeatedly splitting
## the largest shard along a random line biased toward `impact`, so the cracks
## read as radiating from a strike rather than a uniform grid.
static func fracture(base: PackedVector2Array, count: int, impact: Vector2, jitter: float, rng: RandomNumberGenerator) -> Array:
	var shards: Array = [base]
	var guard := 0
	while shards.size() < count and guard < count * 8:
		guard += 1
		var idx := 0
		var best := -1.0
		for i in shards.size():
			var ar: float = area(shards[i])
			if ar > best:
				best = ar
				idx = i
		var poly: PackedVector2Array = shards[idx]
		var c := centroid(poly)
		var pt := c.lerp(impact, rng.randf() * 0.4) + Vector2(
			rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * jitter
		var ang := rng.randf() * PI
		var res := split(poly, pt, Vector2(cos(ang), sin(ang)))
		var fr: PackedVector2Array = res[0]
		var bk: PackedVector2Array = res[1]
		if fr.size() >= 3 and bk.size() >= 3:
			shards.remove_at(idx)
			shards.append(fr)
			shards.append(bk)
	return shards


# FOOTPRINTS: convex outlines on a plane (a thing's foot on a table, x by z), as the card table
# stands its things and moves its cards round them.


## [param poly]'s bounding rectangle.
static func bounds(poly: PackedVector2Array) -> Rect2:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for q in poly:
		lo = lo.min(q)
		hi = hi.max(q)
	return Rect2(lo, hi - lo)


## [param poly] moved by [param by].
static func moved(poly: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in poly:
		out.append(q + by)
	return out


## A footprint [param poly] (x by z) under [param basis], seen from above.
static func turned(poly: PackedVector2Array, basis: Basis) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in poly:
		var w := basis * Vector3(q.x, 0.0, q.y)
		out.append(Vector2(w.x, w.z))
	return out


## [param poly] (convex) pushed out by [param by] all round.
static func grown(poly: PackedVector2Array, by: float) -> PackedVector2Array:
	var c := Vector2.ZERO
	for q in poly:
		c += q
	c /= float(maxi(poly.size(), 1))
	var out := PackedVector2Array()
	for q in poly:
		out.append(q + (q - c).normalized() * by)
	return out


## Rectangle [param r] as a convex outline.
static func of_rect(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


## Whether convex [param a] and [param b] come within [param gap] of each other: no separating
## axis among their edges' normals with that much room on it.
static func within(a: PackedVector2Array, b: PackedVector2Array, gap: float) -> bool:
	if a.size() < 2 or b.size() < 2:
		return false
	for poly in [a, b]:
		var p: PackedVector2Array = poly
		for i in p.size():
			var e := p[(i + 1) % p.size()] - p[i]
			if e.length_squared() < 1e-12:
				continue
			var ax := Vector2(-e.y, e.x).normalized()
			var ra := span(a, ax)
			var rb := span(b, ax)
			if ra.x > rb.y + gap or rb.x > ra.y + gap:
				return false
	return true


## [param poly]'s extent along [param ax]: (least, most).
static func span(poly: PackedVector2Array, ax: Vector2) -> Vector2:
	var lo := INF
	var hi := -INF
	for q in poly:
		var d := q.dot(ax)
		lo = minf(lo, d)
		hi = maxf(hi, d)
	return Vector2(lo, hi)
