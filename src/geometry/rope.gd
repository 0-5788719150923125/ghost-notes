extends RefCounted
class_name Rope

## Rope - a cord settled where it would lie: a chain of points, each held to its neighbours' spacing and bent no sharper than a cord
## of its stiffness can - over a few lengths at once, so no stretch of it curves tighter than its least radius and it never kinks -
## falling under gravity onto what is under it - solids (a box, or an outline standing between two heights),
## capsules (a root, a pipe) and a floor - its pinned points held where they are. Position based (Verlet steps, the constraints worked over each step), run to rest once from where it
## is laid; pure and deterministic, so a scene settles it on a worker and gets the same cord every time.
##
## A point that goes into a solid is put back where it went in (never out through the far side of a thin thing), so a cord resting
## on something holds its place rather than being drawn along by its own stiffness; off a root or another cord, it is pushed out
## round it and may slide. A point
## inside a solid leaves it by its nearest side that is free - never down into what the solid stands on. A link
## is kept out of a capsule as well as its points, so a cord never slips through a root thinner than its links; laid where a capsule
## lies across its way, start it over the capsule ([method lifted_over]) so it falls onto it rather than being pushed under.

## A settle's steps (each 1/60 s), the passes over its lengths and bends each step (what it touches pushed out of halfway and at the
## step's end), the passes that only push it out at the end, how much of its motion each step keeps, and how much of it a touch takes away along the
## surface.
const STEPS := 60
const ITERATIONS := 4
const SETTLE_PASSES := 8
## The least radius the stiffest cord bends round (m), and over how many links at once its bending is held to it.
const BEND_MOST := 0.035
const SPANS := [2, 4, 6]
## How much of the way a chord bent too short is pushed back each pass: soft, under the lengths.
const BEND_SHARE := 0.3
## How little of its bending reaches a point resting on something (1: none), and how much of its slide along a face it meets a point
## keeps (the rest its friction takes).
const RESTING_BEND := 0.9
const SLIDE := 0.5
## The cell of the grid what it lies on is sorted into (m), so a point asks only what is near it.
const CELL := 0.06
const DAMPING := 0.97
const FRICTION := 0.6
const GRAVITY := Vector3(0.0, -9.8, 0.0)
const DT := 1.0 / 60.0


## The cord along [param path] (its points as laid, ends included) settled: [param pinned] the indices of the points held where they
## are (its ends, say), [param radius] how thick it is (m), [param stiff] 0 limp to 1 stiff (how sharply it may bend between three
## points), and what it lies on: [param solids] (each an AABB, or `{outline: PackedVector2Array (x, z), lo, hi}` - an outline standing
## from one height to another), [param capsules] (each `[from, to, radius]`) and [param floor] (the height it never goes under). [param slack]: how much longer it is than the way it was laid
## (0.04: four percent), so it lies in easy curves rather than pulled taut; [param margin], how far further it keeps from a solid
## (m: a curve drawn through its points may cut a hair inside). Returns its points at rest.
static func settle(path: PackedVector3Array, pinned: Array, radius: float, stiff: float, solids: Array, capsules: Array,
		floor := -INF, slack := 0.0, margin := 0.0) -> PackedVector3Array:
	var n := path.size()
	if n < 3:
		return path
	var p := path.duplicate()
	var prev := path.duplicate()
	var rest := PackedFloat32Array()
	rest.resize(n - 1)
	for i in n - 1:
		rest[i] = p[i].distance_to(p[i + 1]) * (1.0 + slack)
	var held := {}
	for i in pinned:
		if int(i) >= 0 and int(i) < n:
			held[int(i)] = path[int(i)]
	# what is near it at all, so a step asks only that
	var reach := AABB(p[0], Vector3.ZERO)
	for q in p:
		reach = reach.expand(q)
	reach = reach.grow(0.25)
	var near_solids: Array = []
	for one in solids:
		var sd := _solid(one, radius + margin)
		if not sd.is_empty() and (sd["box"] as AABB).intersects(reach):
			near_solids.append(sd)
	var near_caps: Array = capsules.filter(func(c: Array) -> bool:
		return AABB((c[0] as Vector3), Vector3.ZERO).expand(c[1] as Vector3).grow(float(c[2]) + radius).intersects(reach))
	var grid := _grid(near_solids, near_caps, radius)
	# how far apart a point and the one after next may come: a cord this stiff bends no sharper
	# the least radius it bends round: a limp cord's as tight as it is thick, the stiffest's BEND_MOST
	var bend_radius := lerpf(radius * 2.0, BEND_MOST, clampf(stiff, 0.0, 1.0))
	var least_chords: Array = []          # per span, the shortest chord from each point an arc of that radius allows
	for span in SPANS:
		var chords := PackedFloat32Array()
		chords.resize(maxi(n - int(span), 0))
		for i in n - int(span):
			var arc := 0.0
			for j in range(i, i + int(span)):
				arc += rest[j]
			chords[i] = 2.0 * bend_radius * sin(minf(arc / (2.0 * bend_radius), PI * 0.5))
		least_chords.append(chords)
	var touched := PackedByteArray()
	touched.resize(n)
	var resting := PackedByteArray()
	resting.resize(n)
	for step in STEPS:
		var before := p.duplicate()
		for i in n:
			if held.has(i):
				continue
			var v := (p[i] - prev[i]) * DAMPING
			if touched[i] != 0:
				v *= 1.0 - FRICTION
			prev[i] = p[i]
			p[i] += v + GRAVITY * DT * DT
		touched.fill(0)
		for k in ITERATIONS:
			# no stretch of it bent tighter than its least radius: the chord across a few links never shorter than an arc that round
			for si in SPANS.size():
				var span: int = SPANS[si]
				var chords: PackedFloat32Array = least_chords[si]
				for i in n - span:
					# (a stretch from a point held - a plug - bends as tight as it must: the plug takes the strain)
					if held.has(i) or held.has(i + span):
						continue
					var d := p[i + span] - p[i]
					var now := d.length()
					if now >= chords[i] or now < 1e-6:
						continue
					# pushed apart along the chord - a point resting on something hardly at all: what lies on the desk keeps the
					# curves it was laid in, what hangs or drapes is shaped by its stiffness, and nothing is pulled taut by it
					var fix := d * ((chords[i] - now) / now) * BEND_SHARE * 0.5
					p[i] -= fix * (1.0 - RESTING_BEND if resting[i] != 0 else 1.0)
					p[i + span] += fix * (1.0 - RESTING_BEND if resting[i + span] != 0 else 1.0)
			# its lengths last, twice, so bending reshapes it and never stretches it
			for _again in 2:
				for i in n - 1:
					_hold_apart(p, i, i + 1, rest[i], held, 1.0)
			_push_out(p, held, touched, grid, radius, floor, k == ITERATIONS - 1, before)
		for i in n:
			resting[i] = touched[i]
	# what it rests on pushed out of a last few times, nothing pulling it back in
	for _k in SETTLE_PASSES:
		_push_out(p, held, touched, grid, radius, floor, true)
	return p


## A solid of [param settle] grown by [param radius]: `{box}` for an AABB, `{box, outline}` for an outline standing between two
## heights (its box the outline's bounds); {} where it has no room in it.
static func _solid(one: Variant, radius: float) -> Dictionary:
	if one is AABB:
		return {"box": (one as AABB).grow(radius)}
	if not one is Dictionary or not (one as Dictionary).get("outline") is PackedVector2Array:
		return {}
	var d: Dictionary = one
	var poly: PackedVector2Array = d["outline"]
	if poly.size() < 3:
		return {}
	var grown: Array = Geometry2D.offset_polygon(poly, radius)
	var best := poly
	var area := -1.0
	for g in grown:
		var a := absf(_area(g as PackedVector2Array))
		if a > area:
			area = a
			best = g
	var bb := Rect2(best[0], Vector2.ZERO)
	for q in best:
		bb = bb.expand(q)
	var lo := float(d.get("lo", 0.0)) - radius
	var hi := float(d.get("hi", 0.0)) + radius
	if hi <= lo:
		return {}
	return {"box": AABB(Vector3(bb.position.x, lo, bb.position.y), Vector3(bb.size.x, hi - lo, bb.size.y)), "outline": best}


static func _area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		a += poly[i].cross(poly[(i + 1) % poly.size()])
	return 0.5 * a


## [param solids] ([method _solid]) and [param caps] sorted into the cells of a grid ([constant CELL]) by what each covers, capsules
## grown by [param radius]: `{cell: {solids: [solid], caps: [[from, to, radius]]}}`.
static func _grid(solids: Array, caps: Array, radius: float) -> Dictionary:
	var g := {}
	for sd in solids:
		_into(g, (sd as Dictionary)["box"], "solids", sd)
	for c in caps:
		var r := float(c[2]) + radius
		_into(g, AABB(c[0] as Vector3, Vector3.ZERO).expand(c[1] as Vector3).grow(r), "caps", [c[0], c[1], r])
	return g


static func _into(g: Dictionary, box: AABB, kind: String, what: Variant) -> void:
	var c0 := _cell(box.position)
	var c1 := _cell(box.end)
	for x in range(c0.x, c1.x + 1):
		for y in range(c0.y, c1.y + 1):
			for z in range(c0.z, c1.z + 1):
				var k := Vector3i(x, y, z)
				if not g.has(k):
					g[k] = {"solids": [], "caps": []}
				(g[k][kind] as Array).append(what)


static func _cell(q: Vector3) -> Vector3i:
	return Vector3i(floori(q.x / CELL), floori(q.y / CELL), floori(q.z / CELL))


## Every point of [param p] not [param held] put out of what it lies on near it ([param grid], [method _grid]: each grown already),
## each moved marked [param touched]; with [param links], each link out of each capsule near it too.
static func _push_out(p: PackedVector3Array, held: Dictionary, touched: PackedByteArray, grid: Dictionary, radius: float,
		floor: float, links: bool, before := PackedVector3Array()) -> void:
	for i in p.size():
		if held.has(i):
			continue
		var q := p[i]
		var here: Dictionary = grid.get(_cell(q), {})
		# out of the capsules first, then the solids, which always win: a cord pressed between a root or another cord and a thing
		# stays outside the thing
		for c in here.get("caps", []):
			q = _out_of_capsule(q, c[0], c[1], float(c[2]))
		var near: Array = (grid.get(_cell(q), {}) as Dictionary).get("solids", [])
		for sd in near:
			if not _inside(q, sd):
				continue
			# put back where it went in, on its way this step: never out through the far side of a thing, and a point at rest
			# comes back to where it lay (it holds its place) - else, where it began inside, by the nearest side that is free
			if not before.is_empty() and not _inside(before[i], sd):
				var entry := _entered(before[i], q, sd)
				# with some of its slide along the face it met kept, so its slack spreads rather than gathering into a loop
				var face := _out_of(q, sd, near) - q
				var slid := q - entry
				if face.length() > 1e-7:
					var nrm := face.normalized()
					var along := entry + (slid - nrm * slid.dot(nrm)) * SLIDE
					q = along if not _inside(along, sd) else entry
				else:
					q = entry
			else:
				q = _out_of(q, sd, near)
		q.y = maxf(q.y, floor + radius)
		if not q.is_equal_approx(p[i]):
			touched[i] = 1
			p[i] = q
	if not links:
		return
	# each link out of each capsule near it, so none slips through a thin one between its points
	for i in p.size() - 1:
		var near: Array = (grid.get(_cell(p[i]), {}) as Dictionary).get("caps", [])
		var other: Array = (grid.get(_cell(p[i + 1]), {}) as Dictionary).get("caps", [])
		if not other.is_empty() and other != near:
			near = near + other
		for c in near:
			var a: Vector3 = c[0]
			var b: Vector3 = c[1]
			var r := float(c[2])
			var st := _closest(p[i], p[i + 1], a, b)
			var on_link := p[i].lerp(p[i + 1], st.x)
			var on_cap := a.lerp(b, st.y)
			var d := on_link - on_cap
			var l := d.length()
			if l >= r:
				continue
			var push := (d / l if l > 1e-6 else Vector3.UP) * (r - l)
			# its ends moved so the link's nearest point moves out by the overlap (a held end never moves; capped, so a link near
			# one does not leap)
			var wi := 0.0 if held.has(i) else 1.0 - st.x
			var wj := 0.0 if held.has(i + 1) else st.x
			if wi + wj <= 0.0:
				continue
			var norm := maxf(wi * wi + wj * wj, 0.25)
			p[i] += push * (wi / norm)
			p[i + 1] += push * (wj / norm)
			touched[i] = 1
			touched[i + 1] = 1


## Where the segments [param p1]-[param q1] and [param p2]-[param q2] come nearest: (s, t), each a share of its segment.
static func _closest(p1: Vector3, q1: Vector3, p2: Vector3, q2: Vector3) -> Vector2:
	var d1 := q1 - p1
	var d2 := q2 - p2
	var r := p1 - p2
	var a := d1.dot(d1)
	var e := d2.dot(d2)
	var f := d2.dot(r)
	if a <= 1e-9 and e <= 1e-9:
		return Vector2.ZERO
	if a <= 1e-9:
		return Vector2(0.0, clampf(f / e, 0.0, 1.0))
	var c := d1.dot(r)
	if e <= 1e-9:
		return Vector2(clampf(-c / a, 0.0, 1.0), 0.0)
	var b := d1.dot(d2)
	var den := a * e - b * b
	var s := clampf((b * f - c * e) / den, 0.0, 1.0) if den > 1e-9 else 0.0
	var t := (b * s + f) / e
	if t < 0.0:
		t = 0.0
		s = clampf(-c / a, 0.0, 1.0)
	elif t > 1.0:
		t = 1.0
		s = clampf((b - c) / a, 0.0, 1.0)
	return Vector2(s, t)


## [param path] (a cord as laid, [param radius] thick) started over every capsule of [param capsules] lying across its way, at about
## its height: each point that would be inside one, or under it, raised to lie a little over its top - so let fall it drapes over it.
## A capsule standing up out of its way, or one well over it, it is left to go round.
static func lifted_over(path: PackedVector3Array, capsules: Array, radius: float) -> PackedVector3Array:
	var out := path.duplicate()
	for i in out.size():
		var q := out[i]
		for c in capsules:
			var a: Vector3 = c[0]
			var b: Vector3 = c[1]
			var r := float(c[2]) + radius
			var ab := Vector2(b.x - a.x, b.z - a.z)
			# only what lies across its way: never a capsule standing up out of it (gone round), nor one well over it
			if absf(b.y - a.y) > ab.length():
				continue
			var t := clampf(Vector2(q.x - a.x, q.z - a.z).dot(ab) / maxf(ab.length_squared(), 1e-9), 0.0, 1.0)
			var axis := a.lerp(b, t)
			var flat := Vector2(q.x - axis.x, q.z - axis.z).length()
			if flat < r and q.y < axis.y + r and axis.y - q.y < r + 0.01:
				q.y = maxf(q.y, axis.y + sqrt(maxf(r * r - flat * flat, 0.0)) + 0.004)
		out[i] = q
	return out


## Points [param i] and [param j] of [param p] moved toward or apart to [param length] apart, a held point never moving, each by its
## share ([param k] of the way).
static func _hold_apart(p: PackedVector3Array, i: int, j: int, length: float, held: Dictionary, k: float) -> void:
	var d := p[j] - p[i]
	var now := d.length()
	if now < 1e-6:
		return
	var fix := d * ((now - length) / now) * k
	var hi := held.has(i)
	var hj := held.has(j)
	if hi and hj:
		return
	if hi:
		p[j] -= fix
	elif hj:
		p[i] += fix
	else:
		p[i] += fix * 0.5
		p[j] -= fix * 0.5


## Where the way from [param a] (outside solid [param sd]) to [param b] (inside it) went in: the last point of it still outside.
static func _entered(a: Vector3, b: Vector3, sd: Dictionary) -> Vector3:
	var out := a
	var into := b
	for _i in 14:
		var m := out.lerp(into, 0.5)
		if _inside(m, sd):
			into = m
		else:
			out = m
	return out


## Whether [param q] is inside solid [param sd] ([method _solid]).
static func _inside(q: Vector3, sd: Dictionary) -> bool:
	if not (sd["box"] as AABB).has_point(q):
		return false
	return not sd.has("outline") or Geometry2D.is_point_in_polygon(Vector2(q.x, q.z), sd["outline"])


## [param q] put out of solid [param sd] where it is inside: by its nearest side that leaves it in none of [param near] (a box's
## faces; an outline's top, bottom or nearest edge), so it is never pushed down into what the solid stands on.
static func _out_of(q: Vector3, sd: Dictionary, near: Array) -> Vector3:
	if not _inside(q, sd):
		return q
	var b: AABB = sd["box"]
	var e := b.end
	var o := b.position
	var ways: Array = [[e.y - q.y, Vector3(q.x, e.y, q.z)], [q.y - o.y, Vector3(q.x, o.y, q.z)]]
	if sd.has("outline"):
		var poly: PackedVector2Array = sd["outline"]
		var at := Vector2(q.x, q.z)
		var best := at
		var least := INF
		for i in poly.size():
			var c := Geometry2D.get_closest_point_to_segment(at, poly[i], poly[(i + 1) % poly.size()])
			if at.distance_to(c) < least:
				least = at.distance_to(c)
				best = c
		var out := best + (best - at).normalized() * 1e-4 if least > 1e-6 else best
		ways.append([least, Vector3(out.x, q.y, out.y)])
	else:
		ways.append_array([[e.x - q.x, Vector3(e.x, q.y, q.z)], [q.x - o.x, Vector3(o.x, q.y, q.z)],
			[e.z - q.z, Vector3(q.x, q.y, e.z)], [q.z - o.z, Vector3(q.x, q.y, o.z)]])
	var down: Vector3 = ways[1][1]
	ways.sort_custom(func(a: Array, c: Array) -> bool: return float(a[0]) < float(c[0]))
	for w in ways:
		var to: Vector3 = w[1]
		var free := true
		for other in near:
			if other != sd and _inside(to, other):
				free = false
				break
		if free:
			return to
	# none clear: the nearest that is not down through its foot, so it is never caught between a solid and what that stands on
	for w in ways:
		if not (w[1] as Vector3).is_equal_approx(down):
			return w[1]
	return ways[0][1]


## [param q] put out of the capsule from [param a] to [param b] of radius [param r] where it is inside.
static func _out_of_capsule(q: Vector3, a: Vector3, b: Vector3, r: float) -> Vector3:
	var ab := b - a
	var t := clampf((q - a).dot(ab) / maxf(ab.length_squared(), 1e-9), 0.0, 1.0)
	var c := a + ab * t
	var d := q - c
	var l := d.length()
	if l >= r:
		return q
	if l < 1e-6:
		return c + Vector3.UP * r
	return c + d / l * r


## [param path] with its corners cut, [param times] over (Chaikin's way, never past the path it was): each corner replaced by two
## points [param cut] along its sides (at most; a quarter of a side where that is less), the first and last [param keep] points as
## they are.
static func rounded(path: PackedVector3Array, cut: float, times: int, keep: int) -> PackedVector3Array:
	var out := path
	for _t in times:
		if out.size() < 3:
			return out
		var next := PackedVector3Array()
		for i in mini(keep, out.size()):
			next.append(out[i])
		for i in range(keep, out.size() - keep):
			var a := out[i - 1]
			var b := out[i]
			var c := out[i + 1]
			next.append(b + (a - b).limit_length(minf(cut, a.distance_to(b) * 0.25)))
			next.append(b + (c - b).limit_length(minf(cut, b.distance_to(c) * 0.25)))
		for i in range(maxi(out.size() - keep, keep), out.size()):
			next.append(out[i])
		out = next
	return out


## [param path] laid in a gentle meander: each point moved sideways (across its way, along the ground) by up to [param amplitude],
## a slow wave [param wavelength] long beginning at [param phase] (radians) and a second, slower one under it, none of it within
## [param keep] of either end - so a cord laid along straight runs lies as one does, in curves.
static func meandered(path: PackedVector3Array, amplitude: float, wavelength: float, phase: float, keep: float) -> PackedVector3Array:
	var out := path.duplicate()
	var n := path.size()
	if n < 3:
		return out
	var along := PackedFloat32Array([0.0])
	for i in range(1, n):
		along.append(along[i - 1] + path[i].distance_to(path[i - 1]))
	var whole := along[n - 1]
	for i in range(1, n - 1):
		var dir := path[i + 1] - path[i - 1]
		var side := Vector3(-dir.z, 0.0, dir.x)
		if side.length() < 1e-6:
			continue
		side = side.normalized()
		var taper := clampf(minf(along[i], whole - along[i]) / maxf(keep, 1e-4) - 1.0, 0.0, 1.0)
		var u := along[i] / wavelength * TAU
		out[i] += side * amplitude * taper * (0.7 * sin(u + phase) + 0.3 * sin(u * 0.43 + phase * 1.7))
	return out


## [param path] resampled to points [param spacing] apart along it (its ends kept).
static func resampled(path: PackedVector3Array, spacing: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	if path.size() < 2:
		return path.duplicate()
	var whole := 0.0
	for i in path.size() - 1:
		whole += path[i].distance_to(path[i + 1])
	var n := maxi(2, ceili(whole / maxf(spacing, 1e-4)) + 1)
	var step := whole / float(n - 1)
	out.append(path[0])
	var seg := 0
	var into := 0.0
	for k in range(1, n - 1):
		var want := step * float(k)
		while seg < path.size() - 2 and into + path[seg].distance_to(path[seg + 1]) < want:
			into += path[seg].distance_to(path[seg + 1])
			seg += 1
		var len_seg := maxf(path[seg].distance_to(path[seg + 1]), 1e-6)
		out.append(path[seg].lerp(path[seg + 1], clampf((want - into) / len_seg, 0.0, 1.0)))
	out.append(path[path.size() - 1])
	return out
