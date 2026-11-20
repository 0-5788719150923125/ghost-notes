extends RefCounted
class_name Fanfold

## Fanfold - continuous paper as it leaves a printer and folds itself onto its heap: a chain of points in the plane the paper
## travels in (x out from the slot, y up, meters), stiff along each panel and soft at the perforation between two panels, where
## it was folded and still leans to fold - one way, then the other. It falls under gravity onto what is under it (convex
## outlines: the printer's own parts, the desk) and onto the heap, where each panel is laid back over the last, its crease
## landing at the heap's near edge and the next at its far one.
##
## The paper is fed slowly through two panels - one whole fold out and back - and what it does is kept ([method bake]): its
## shape at any length fed is then read from that ([method profile]), the same every time, the creases travelling along it
## as it feeds. Pure and deterministic: a scene bakes it on a worker. [method arrays] makes the strip's mesh from a shape,
## curved through each panel and creased where it is creased.

## A sheet's weight (kg/m^2) and how stiff it is to bend (N m, a meter of width): it droops over about 7 cm.
const WEIGHT := 0.08
const STIFF := 3.0e-4
## A crease: how stiff beside a panel's own bending, and the turn it rests at (radians; folded flat is PI); and how far out of the
## slot it is held flat (the printer's bail and cover hold the paper as it leaves), taking its fold back over as far again (m).
const CREASE_STIFF := 0.01
const CREASE_REST := 2.5
const CREASE_HELD := 0.05
## No point of it turns sharper than this (radians): a fold never passes through itself.
const TURN_MOST := 3.0
const GRAVITY := 9.8
## How much of its motion a step takes away, how fast it is fed while baked (m/s) and the most a point moves in a step (m).
const DAMP := 0.12
const FEED := 0.1
const STEP_MOST := 0.0012
## How far it rides over what it lies on (m); how much of its slide over a part a touch takes (it slides over the printer, even
## where its weight pulls it hard round an edge); and how the heap grips it (the slide a touch stops, for how hard it presses),
## so a panel laid stays where it is laid.
const TOUCH := 0.002
const FRICTION := 0.25
const HEAP_FRICTION := 0.5
## How far the panel last laid lies over the heap's top (m), under the one being laid on it.
const LAID := 0.0006
## The shapes kept for each link fed, and the pieces a link is drawn in ([method arrays]).
const FRAMES_PER_LINK := 2
const PIECES := 4
## A crease has landed within this of the heap's top and of the edge it lands at (m); and a fold laid ends within this of where
## it began (m), so it goes round again as it went.
const LANDED := Vector2(0.03, 0.004)
const CLOSES := 0.02


static var _baked := {}
static var _lock := Mutex.new()


## [method bake] of [param scene], made once for each scene and kept: scenes alike to the last digit share it.
static func baked(scene: Dictionary) -> Dictionary:
	var key := var_to_str(scene)
	_lock.lock()
	if not _baked.has(key):
		_baked[key] = bake(scene)
	var out: Dictionary = _baked[key]
	_lock.unlock()
	return out


## What fed paper does over one fold out and back, in the scene [param scene]: `exit` the way it leaves the slot (Vector2, the
## slot at the origin), `solids` what it lies on (each a convex PackedVector2Array), `heap` where it folds down (Vector2: its
## near edge's x, its top's y), `floor` (y), `panel` a panel's length (m) and `links` the links a panel is cut in; and, where a
## sheet is not fanfold, `crease_stiff` and `crease_rest` ([constant CREASE_STIFF], [constant CREASE_REST]). Returns
## `{link, per, frames: [{top, points}], start, gap, laid}`: [method profile] reads it. `gap` is how far the fold's end is from
## its beginning before the two are joined (m), `laid` whether each crease landed at its edge and the fold closed ([constant
## CLOSES]).
static func bake(scene: Dictionary) -> Dictionary:
	var s := Sheet.new()
	s.set_up(scene)
	var cycle := 2.0 * s.panel
	# laid over everything as a hand would lay it, let fall, then fed through a fold and more until a fold begins
	for _i in 320:
		s.step(0.0)
	var from := ceilf((s.fed + cycle * 0.75) / cycle) * cycle
	var per_frame := maxi(1, int(ceil(s.h / float(FRAMES_PER_LINK) / (FEED * s.dt))))
	var df := s.h / float(FRAMES_PER_LINK) / float(per_frame)
	var warm := int(round((from - s.fed) / df))
	var d0 := (from - s.fed) / float(maxi(warm, 1))
	for _i in warm:
		s.step(d0)
	s.fed = from
	var shift := int(round(from / s.h))
	var count := 2 * s.per * FRAMES_PER_LINK
	var frames: Array = []
	var landed := 0
	for f in count + 1:
		frames.append(s.frame(shift))
		if f == count:
			break
		var before := s.lands
		for _i in per_frame:
			s.step(df)
		landed += s.lands - before
	# the fold's end joined to its beginning: the last quarter eased onto where the first shape lies, two panels on
	var first: Dictionary = frames[0]
	var last: Dictionary = frames[count]
	var gap := 0.0
	var off := {}
	var pts0: PackedVector2Array = first["points"]
	var ptsn: PackedVector2Array = last["points"]
	for i in pts0.size():
		var j := int(first["top"]) - i + 2 * s.per
		var k := int(last["top"]) - j
		if k >= 0 and k < ptsn.size():
			off[j] = pts0[i] - ptsn[k]
			gap = maxf(gap, (off[j] as Vector2).length())
	var ease_over := count / 4
	for f in range(count - ease_over, count):
		var w := float(f - (count - ease_over)) / float(ease_over)
		w = w * w * (3.0 - 2.0 * w)
		var fr: Dictionary = frames[f]
		var pts: PackedVector2Array = fr["points"]
		for i in pts.size():
			var j := int(fr["top"]) - i
			if off.has(j):
				pts[i] += (off[j] as Vector2) * w
		fr["points"] = pts
	frames.resize(count)
	return {"link": s.h, "per": s.per, "frames": frames, "start": s.start, "exit": s.exit, "gap": gap,
		"laid": landed == 2 and s.strays == 0 and gap < CLOSES}


## The paper's shape with [param fed] meters of it fed ([param baked], [method bake]), from the slot: `{points:
## PackedVector2Array, along: PackedFloat32Array (how far along the paper each is from the slot, m), crease: PackedByteArray
## (1 where it is creased)}`, the panel last laid on the heap its last.
static func profile(baked: Dictionary, fed: float) -> Dictionary:
	var h := float(baked["link"])
	var per := int(baked["per"])
	var frames: Array = baked["frames"]
	var count := frames.size()
	var cycle := float(2 * per) * h
	var phase := fposmod(fed, cycle)
	var at := phase / cycle * float(count)
	var k := mini(int(floor(at)), count - 1)
	var t := at - float(k)
	var a: Dictionary = frames[k]
	var b: Dictionary = frames[(k + 1) % count]
	var b_shift := 2 * per if k + 1 == count else 0
	var fed_a := float(k) / float(count) * cycle
	var fed_b := float(k + 1) / float(count) * cycle
	var exit: Vector2 = baked["exit"]
	var start: Vector2 = baked["start"]
	var pa: PackedVector2Array = a["points"]
	var pb: PackedVector2Array = b["points"]
	var top_a := int(a["top"])
	var top_b := int(b["top"]) + b_shift
	var points := PackedVector2Array([start])
	var along := PackedFloat32Array([0.0])
	var crease := PackedByteArray([0])
	var j := maxi(top_a, top_b)
	var low := mini(top_a - pa.size(), top_b - pb.size())
	while j > low:
		var out := phase - float(j) * h
		if out > 1.0e-5:
			var ia := top_a - j
			var ib := top_b - j
			var has_a := ia < pa.size()
			var has_b := ib < pb.size()
			var qa := (pa[ia] if ia >= 0 else exit * (fed_a - float(j) * h)) if has_a else Vector2.ZERO
			var qb := (pb[ib] if ib >= 0 else exit * (fed_b - float(j) * h)) if has_b else Vector2.ZERO
			if has_a or has_b:
				points.append(start + (qa.lerp(qb, t) if has_a and has_b else (qa if has_a else qb)))
				along.append(out)
				crease.append(1 if posmod(j, per) == 0 else 0)
		j -= 1
	return {"points": points, "along": along, "crease": crease}


## Everywhere the paper of [param baked] goes as it feeds: its points at every frame of the fold, and along each link no more than
## [param step] apart (m).
static func swept(baked: Dictionary, step := 0.015) -> PackedVector2Array:
	var out := PackedVector2Array()
	var frames: Array = baked["frames"]
	var cycle := float(2 * int(baked["per"])) * float(baked["link"])
	for f in frames.size():
		var pts: PackedVector2Array = profile(baked, float(f) / float(frames.size()) * cycle)["points"]
		for i in pts.size():
			var n := 1 if i == 0 else maxi(1, int(ceil(pts[i].distance_to(pts[i - 1]) / step)))
			for q in n:
				out.append(pts[i] if i == 0 else pts[i - 1].lerp(pts[i], float(q + 1) / float(n)))
	return out


## The strip's mesh arrays (Mesh.ARRAY_*) for shape [param shape] ([method profile]), [param width] across: x across it, y up, the
## paper going out along -z; each panel a curve through its points, each crease an edge. UV.x runs across it and UV.y from 1 at
## the slot back along the paper, [param per_meter] a meter, so a picture of it has the slot at its foot. Its front is the
## printed side, which faces the printer's front as it rises.
static func arrays(shape: Dictionary, width: float, per_meter: float) -> Array:
	var pts: PackedVector2Array = shape["points"]
	var along: PackedFloat32Array = shape["along"]
	var crease: PackedByteArray = shape["crease"]
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var hw := width * 0.5
	var n := pts.size()
	var from := 0
	while from < n - 1:
		# one run of it, crease to crease: a curve through its points, leaving each end the way its last link goes
		var to := from + 1
		while to < n - 1 and crease[to] == 0:
			to += 1
		var slopes := PackedVector2Array()
		for i in range(from, to + 1):
			slopes.append((pts[mini(i + 1, to)] - pts[maxi(i - 1, from)]) * (0.5 if i > from and i < to else 1.0))
		var row0 := verts.size() / 2
		for i in range(from, to + 1):
			for q in (PIECES if i < to else 1):
				var u := float(q) / float(PIECES)
				var p := pts[i]
				var way := slopes[i - from]
				var far := along[i]
				if q > 0:
					var p1 := pts[i + 1]
					var m0 := slopes[i - from]
					var m1 := slopes[i + 1 - from]
					var u2 := u * u
					var u3 := u2 * u
					p = (2.0 * u3 - 3.0 * u2 + 1.0) * p + (u3 - 2.0 * u2 + u) * m0 + (-2.0 * u3 + 3.0 * u2) * p1 + (u3 - u2) * m1
					way = (6.0 * u2 - 6.0 * u) * pts[i] + (3.0 * u2 - 4.0 * u + 1.0) * m0 + (-6.0 * u2 + 6.0 * u) * p1 + (3.0 * u2 - 2.0 * u) * m1
					far = lerpf(along[i], along[i + 1], u)
				way = way.normalized() if way.length_squared() > 1.0e-12 else Vector2(0, 1)
				for side in [-1.0, 1.0]:
					verts.append(Vector3(hw * float(side), p.y, -p.x))
					normals.append(Vector3(0.0, way.x, way.y))
					uvs.append(Vector2(0.5 + 0.5 * float(side), 1.0 - far * per_meter))
		for r in verts.size() / 2 - row0 - 1:
			var a := (row0 + r) * 2
			indices.append_array(PackedInt32Array([a, a + 2, a + 3, a, a + 3, a + 1]))
		from = to
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = verts
	out[Mesh.ARRAY_NORMAL] = normals
	out[Mesh.ARRAY_TEX_UV] = uvs
	out[Mesh.ARRAY_INDEX] = indices
	return out


## [param front] ([method arrays]) seen from behind: the same strip, its other side out.
static func turned(front: Array) -> Array:
	var out := front.duplicate()
	var normals := PackedVector3Array()
	for q in (front[Mesh.ARRAY_NORMAL] as PackedVector3Array):
		normals.append(-q)
	var from: PackedInt32Array = front[Mesh.ARRAY_INDEX]
	var indices := PackedInt32Array()
	for i in range(0, from.size(), 3):
		indices.append_array(PackedInt32Array([from[i], from[i + 2], from[i + 1]]))
	out[Mesh.ARRAY_NORMAL] = normals
	out[Mesh.ARRAY_INDEX] = indices
	return out


## The paper being fed: its points from the newest, still in the printer, to the crease last landed on the heap.
class Sheet extends RefCounted:
	var p := PackedVector2Array()
	var prev := PackedVector2Array()
	var top := 0                  # the first point's place along the paper, in links: a point j is fed - j * h out of the slot
	var fed := 0.0
	var h := 0.028
	var per := 10
	var panel := 0.28
	var dt := 0.004
	var exit := Vector2(0, 1)
	var start := Vector2.ZERO     # where it comes out of everything round the slot, which the scene's origin is moved to
	var solids: Array = []        # each {points, normals, box, heap}
	var near := 0.0
	var top_y := 0.0
	var crease_stiff := CREASE_STIFF
	var crease_rest := CREASE_REST
	var side := 1                 # the edge the crease last landed lies at: 1 the near one, -1 the far
	var lands := 0
	var strays := 0               # creases that came down off their edge
	var _lam := PackedFloat32Array()
	var _cp := PackedFloat32Array()
	var _dp := PackedFloat32Array()


	func set_up(scene: Dictionary) -> void:
		panel = float(scene.get("panel", 0.28))
		per = int(scene.get("links", 10))
		h = panel / float(per)
		exit = (scene.get("exit", Vector2(0.26, 0.97)) as Vector2).normalized()
		crease_stiff = float(scene.get("crease_stiff", CREASE_STIFF))
		crease_rest = float(scene.get("crease_rest", CREASE_REST))
		# no faster than its own bending can be stepped at
		dt = 0.9 * h * h * sqrt(WEIGHT / (6.0 * STIFF))
		var raw: Array = scene.get("solids", [])
		# it starts where it is out of everything round the slot
		var out := 0.0
		for k in 60:
			var q := exit * (float(k) * 0.001)
			for poly in raw:
				if _depth(_solid(poly, false), q) > 0.0:
					out = float(k + 1) * 0.001
		start = exit * out
		var heap: Vector2 = scene["heap"]
		near = heap.x - start.x
		top_y = heap.y - start.y
		for poly in raw:
			var moved := PackedVector2Array()
			for q in (poly as PackedVector2Array):
				moved.append(q - start)
			solids.append(_solid(moved, false))
		solids.append(_solid(PackedVector2Array([Vector2(near, top_y - 1.0), Vector2(near + panel, top_y - 1.0),
			Vector2(near + panel, top_y), Vector2(near, top_y)]), true))
		var floor_y := float(scene.get("floor", top_y - 0.5)) - start.y
		solids.append(_solid(PackedVector2Array([Vector2(-5.0, floor_y - 1.0), Vector2(5.0, floor_y - 1.0), Vector2(5.0, floor_y),
			Vector2(-5.0, floor_y)]), false))
		# laid as a hand would lay it: up out of the slot above everything, out past everything, down, and in to the heap's near edge
		var high := 0.06
		var out_to := near
		for sd in solids:
			if not bool(sd["heap"]):
				for q in (sd["points"] as PackedVector2Array):
					if q.x > -0.02 and q.y > top_y + 0.05:
						high = maxf(high, q.y + 0.05)
						out_to = maxf(out_to, q.x + 0.03)
		var pin := Vector2(near, top_y + LAID)
		var way := PackedVector2Array([Vector2.ZERO, exit * (high / exit.y), Vector2(out_to, high), Vector2(out_to, top_y + 0.12), pin])
		var lens := PackedFloat32Array([0.0])
		for i in range(1, way.size()):
			lens.append(lens[i - 1] + way[i].distance_to(way[i - 1]))
		var length := lens[lens.size() - 1]
		var links := int(ceil(length / h))
		fed = float(links) * h
		top = links + 2
		for i in links + 3:
			var along := fed - float(top - i) * h
			var q := exit * along
			if along > 0.0:
				var s := along * length / fed
				var leg := 1
				while leg < way.size() - 1 and lens[leg] < s:
					leg += 1
				q = way[leg - 1].lerp(way[leg], (s - lens[leg - 1]) / maxf(lens[leg] - lens[leg - 1], 1.0e-6))
			p.append(q)
		p[p.size() - 1] = pin
		prev = p.duplicate()


	## One step: [param df] more of it fed, and everything on it worked once.
	func step(df: float) -> void:
		fed += df
		while fed - float(top - 1) * h > 0.0:
			top += 1
			p.insert(0, exit * (fed - float(top) * h))
			prev.insert(0, p[0])
		var n := p.size()
		for i in 2:
			p[i] = exit * (fed - float(top - i) * h)
			prev[i] = p[i]
		var keep := 1.0 - DAMP
		var fall := Vector2(0.0, -GRAVITY * dt * dt)
		for i in range(2, n - 1):
			var v := (p[i] - prev[i]) * keep + fall
			var l := v.length()
			if l > STEP_MOST:
				v *= STEP_MOST / l
			prev[i] = p[i]
			p[i] += v
		_bend()
		_touch()
		_lengths()
		_lengths()
		_touch()
		_land()


	## Each point turned toward the turn it rests at: a panel's toward straight, a crease's toward its fold.
	func _bend() -> void:
		var n := p.size()
		var mass := WEIGHT * h
		var panel_k := STIFF / h * dt * dt / mass
		var crease_k := panel_k * crease_stiff
		var tail := Vector2(float(side), 0.0)
		for i in range(1, n):
			var a := p[i - 1]
			var b := p[i]
			var c := p[i + 1] if i + 1 < n else b + tail * h
			var e1 := b - a
			var e2 := c - b
			var l1 := e1.length_squared()
			var l2 := e2.length_squared()
			if l1 < 1.0e-12 or l2 < 1.0e-12:
				continue
			var turn := atan2(e1.x * e2.y - e1.y * e2.x, e1.dot(e2))
			var j := top - i
			var is_crease := posmod(j, per) == 0
			var rest := 0.0
			var k := panel_k
			if is_crease:
				var free := smoothstep(CREASE_HELD, 2.0 * CREASE_HELD, fed - float(j) * h)
				rest = (crease_rest if posmod(j / per, 2) == 0 else -crease_rest) * free
				k = lerpf(panel_k, crease_k, free)
			var off := turn - rest
			if is_crease:
				off = wrapf(off, -PI, PI)
			var ga := Vector2(-e1.y, e1.x) / l1
			var gc := Vector2(-e2.y, e2.x) / l2
			var gb := -ga - gc
			var wa := 1.0 if i - 1 >= 2 else 0.0
			var wb := 1.0 if i >= 2 and i < n - 1 else 0.0
			var wc := 1.0 if i + 1 >= 2 and i + 1 < n - 1 else 0.0
			var sum := wa * ga.length_squared() + wb * gb.length_squared() + wc * gc.length_squared()
			if sum < 1.0e-9:
				continue
			var lam := -off * minf(k, 0.9 / sum)
			# (never folded through itself)
			if absf(turn) > TURN_MOST:
				lam = -(turn - signf(turn) * TURN_MOST) / sum
			if wa > 0.0:
				p[i - 1] += ga * lam
			if wb > 0.0:
				p[i] += gb * lam
			if wc > 0.0:
				p[i + 1] += gc * lam


	## Every link put back to its length at once: the chain's own equations, solved down it and back.
	func _lengths() -> void:
		var n := p.size()
		var m := n - 1
		_lam.resize(m)
		_cp.resize(m)
		_dp.resize(m)
		var dirs := PackedVector2Array()
		dirs.resize(m)
		var errs := PackedFloat32Array()
		errs.resize(m)
		for i in m:
			var d := p[i + 1] - p[i]
			var l := d.length()
			dirs[i] = d / l if l > 1.0e-9 else Vector2(0, -1)
			errs[i] = l - h
		var last := n - 1
		for i in m:
			var w0 := 1.0 if i >= 2 else 0.0
			var w1 := 1.0 if i + 1 >= 2 and i + 1 < last else 0.0
			var diag := w0 + w1
			var rhs := -errs[i]
			if diag <= 0.0:
				diag = 1.0
				rhs = 0.0
			var lower := -w0 * dirs[i - 1].dot(dirs[i]) if i > 0 else 0.0
			var upper := -w1 * dirs[i].dot(dirs[i + 1]) if i + 1 < m else 0.0
			var denom := diag - (lower * _cp[i - 1] if i > 0 else 0.0)
			if absf(denom) < 1.0e-9:
				denom = 1.0e-9
			_cp[i] = upper / denom
			_dp[i] = (rhs - (lower * _dp[i - 1] if i > 0 else 0.0)) / denom
		_lam[m - 1] = _dp[m - 1]
		for i in range(m - 2, -1, -1):
			_lam[i] = _dp[i] - _cp[i] * _lam[i + 1]
		for i in m:
			if i >= 2:
				p[i] -= dirs[i] * _lam[i]
			if i + 1 >= 2 and i + 1 < last:
				p[i + 1] += dirs[i] * _lam[i]


	## Every free point put out of what it lies in, slipping or gripping, and every link kept out of each part.
	func _touch() -> void:
		var n := p.size()
		for i in range(2, n - 1):
			var q := p[i]
			for sd in solids:
				var box: Rect2 = sd["box"]
				if not box.has_point(q):
					continue
				var push := _out(sd, q, prev[i])
				if push == Vector2.ZERO:
					continue
				q += push
				var normal := push.normalized()
				var slid := q - prev[i]
				slid -= normal * slid.dot(normal)
				var far := slid.length()
				if not bool(sd["heap"]):
					q -= slid * FRICTION
				elif far > 1.0e-9:
					# the heap grips what presses on it: a slide shorter than its grip is stopped, a longer one shortened by it
					q -= slid * minf(1.0, push.length() * HEAP_FRICTION / far)
			p[i] = q
		# and every link kept out of each part on the side it was on a step ago: nothing thin is passed through, at a corner or
		# across a face (the heap, a block a panel is pressed into as it is laid, keeps only its points out)
		for i in range(1, n - 1):
			var wa := 1.0 if i >= 2 else 0.0
			var wb := 1.0 if i + 1 < n - 1 else 0.0
			if wa + wb == 0.0:
				continue
			var lo := p[i].min(p[i + 1])
			var hi := p[i].max(p[i + 1])
			var span := Rect2(lo, hi - lo)
			for sd in solids:
				if bool(sd["heap"]) or not (sd["box"] as Rect2).intersects(span, true):
					continue
				var moves := _link_out(sd, p[i], p[i + 1], prev[i], prev[i + 1])
				if moves.is_empty():
					continue
				p[i] += (moves[0] as Vector2) * wa + (moves[1] as Vector2) * (1.0 - wb)
				p[i + 1] += (moves[1] as Vector2) * wb + (moves[0] as Vector2) * (1.0 - wa)


	## The crease over the one landed, once it lies on the heap, is the one landed: what is under it is the heap's.
	func _land() -> void:
		var n := p.size()
		var c := n - 1 - per
		if c < 3:
			return
		var q := p[c]
		if q.y > top_y + TOUCH + LANDED.y:
			return
		var want := near + panel if side == 1 else near
		if absf(q.x - want) > LANDED.x:
			if q.x < near - LANDED.x or q.x > near + panel + LANDED.x:
				strays += 1
			return
		for i in range(c, n - 1):
			if p[i].y > top_y + TOUCH + LANDED.y * 2.0:
				return
		p.resize(c + 1)
		prev.resize(c + 1)
		p[c] = Vector2(want, top_y + LAID)
		prev[c] = p[c]
		side = -side
		lands += 1


	## Its shape now, as [method Fanfold.bake] keeps it: `{top, points}`, every point of it and then the panel last laid, flat
	## on the heap; [param shift] taken from each point's place along the paper.
	func frame(shift: int) -> Dictionary:
		var pts := p.duplicate()
		var pin := p[p.size() - 1]
		for k in range(1, per + 1):
			pts.append(pin + Vector2(float(side) * h * float(k), 0.0))
		return {"top": top - shift, "points": pts}


	## How far each end of the link [param a]-[param b] (at [param pa]-[param pb] a step ago) moves to leave solid [param sd]
	## grown by [constant TOUCH], by the side it was on a step ago (where it was in it already, by its shallowest): `[move_a,
	## move_b]`, or [] where it is out of it. Tried on each side of the solid and across the link (whichever parts them).
	static func _link_out(sd: Dictionary, a: Vector2, b: Vector2, pa: Vector2, pb: Vector2) -> Array:
		var pts: PackedVector2Array = sd["points"]
		var normals: PackedVector2Array = sd["normals"]
		var axes := normals.duplicate()
		var d := b - a
		if d.length_squared() > 1.0e-14:
			axes.append(Vector2(-d.y, d.x).normalized())
		var least := INF
		var least_axis := -1
		var least_sign := 1.0
		var came := -1
		var came_sign := 1.0
		var came_by := -INF
		for k in axes.size():
			var nk := axes[k]
			var pmin := INF
			var pmax := -INF
			for q in pts:
				pmin = minf(pmin, q.dot(nk))
				pmax = maxf(pmax, q.dot(nk))
			pmin -= TOUCH
			pmax += TOUCH
			var smin := minf(a.dot(nk), b.dot(nk))
			var smax := maxf(a.dot(nk), b.dot(nk))
			if smax <= pmin or smin >= pmax:
				return []
			var up := pmax - smin
			var down := smax - pmin
			# (a side of the solid pushes only outward; across the link, either way)
			var sides := [1.0] if k < normals.size() else [1.0, -1.0]
			for sg in sides:
				var over := up if sg > 0.0 else down
				if over < least:
					least = over
					least_axis = k
					least_sign = sg
				var was := minf(pa.dot(nk), pb.dot(nk)) - pmax if sg > 0.0 else pmin - maxf(pa.dot(nk), pb.dot(nk))
				if was > came_by:
					came_by = was
					came = k
					came_sign = sg
		var k := came if came_by > -0.0005 else least_axis
		var sg := came_sign if came_by > -0.0005 else least_sign
		var nk := axes[k] * sg
		var edge := -INF
		for q in pts:
			edge = maxf(edge, q.dot(nk))
		edge += TOUCH
		if k < normals.size():
			# out past a side: each end as far as it is under it, which takes the whole link out
			return [nk * maxf(0.0, edge - a.dot(nk)), nk * maxf(0.0, edge - b.dot(nk))]
		var by := edge - minf(a.dot(nk), b.dot(nk))
		return [nk * by, nk * by]


	## [param poly] as a solid: its points counterclockwise, each edge's outward normal, its box grown by [constant TOUCH].
	static func _solid(poly: PackedVector2Array, is_heap: bool) -> Dictionary:
		var pts := poly.duplicate()
		var area := 0.0
		for i in pts.size():
			var a := pts[i]
			var b := pts[(i + 1) % pts.size()]
			area += a.x * b.y - b.x * a.y
		if area < 0.0:
			pts.reverse()
		var normals := PackedVector2Array()
		var box := Rect2(pts[0], Vector2.ZERO)
		for i in pts.size():
			var e := pts[(i + 1) % pts.size()] - pts[i]
			normals.append(Vector2(e.y, -e.x).normalized())
			box = box.expand(pts[i])
		return {"points": pts, "normals": normals, "box": box.grow(TOUCH), "heap": is_heap}


	## How deep [param q] is in solid [param sd] grown by [constant TOUCH] (m; 0 or less: out of it).
	static func _depth(sd: Dictionary, q: Vector2) -> float:
		var pts: PackedVector2Array = sd["points"]
		var normals: PackedVector2Array = sd["normals"]
		var least := INF
		for i in pts.size():
			least = minf(least, TOUCH - (q - pts[i]).dot(normals[i]))
		return least


	## The way out of solid [param sd] for [param q], which was at [param was] a step ago: by the side it came in through (never
	## out through the far side of a thin thing), or by its nearest where it was in it already; zero where it is out of it.
	static func _out(sd: Dictionary, q: Vector2, was: Vector2) -> Vector2:
		var pts: PackedVector2Array = sd["points"]
		var normals: PackedVector2Array = sd["normals"]
		var least := INF
		var by := 0
		var clear := -INF
		var came := 0
		for i in pts.size():
			var d := TOUCH - (q - pts[i]).dot(normals[i])
			if d <= 0.0:
				return Vector2.ZERO
			if d < least:
				least = d
				by = i
			var off := (was - pts[i]).dot(normals[i]) - TOUCH
			if off > clear:
				clear = off
				came = i
		if clear > -0.0005:
			return normals[came] * (TOUCH - (q - pts[came]).dot(normals[came]))
		return normals[by] * least
