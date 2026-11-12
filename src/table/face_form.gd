extends RefCounted
class_name FaceForm

## FaceForm - a mask: a face with no one in it (next/painted_surface.md; next/table_work.md section 11, "a mask form"). A life-size face
## form, its eyes and lips closed, no hair and no ears - what a makeup artist practises on, a milliner's block, a theater's mask before
## it is painted. A shape of [Props] (`mask`).
##
## It is a relief over its own front: every point of the face is one point seen from the front, z = [method height] of (x, y) inside an
## egg-shaped outline, over a flat back. So a design drawn on the face from the front ([Skins], in millimeters across and down) lands on
## exactly one place, and the face's landmarks - the closed eyes, the brows, the nose's tip, the mouth - are numbers the designer can be
## told ([method landmarks]).
##
## Units: centimeters in, meters out (as [Props] builds); the part stands on its chin (y = 0) facing +z.

## Its size when none is given (centimeters: width, height, depth from the rim to the nose's tip), and the least and most.
const SIZE := Vector3(15.0, 21.0, 8.0)
const SIZE_LEAST := Vector3(4.0, 5.0, 1.5)
const SIZE_MOST := Vector3(40.0, 50.0, 25.0)
## How far apart the face's points are (centimeters, at its size when none is given - a larger face is cut as finely in
## points, so a crease is as sharp at any size).
const STEP := 0.1
## How many ways round the rim's distance from the middle is found, between which it is drawn ([method _rim_reach]).
const RIM_REACH := 2048
## How far out of the middle the grid over the front is left as it is (a share of the way to the rim): past it, it is pulled in
## so its edge lies on the rim ([method _pulled_in]). Every feature is inside it.
const PULL_FROM := 0.72
## The back's depth behind the rim (centimeters), when none is given.
const THICK := 0.6
## Where the middle of the face is, up from the chin (a share of its height), and how the outline narrows to the chin.
const MIDDLE := 0.53
const JAW := 0.3
const JAW_CURVE := 1.8
## The dome's share of the depth (the rest is the nose), and its flatness across the front.
const DOME := 0.55
const DOME_FLAT := Vector2(2.6, 0.6)
## The features fade out toward the rim from this share of the way there, so the rim stays where the outline is.
const FEATURES_FADE := Vector2(0.82, 1.0)

## The features, as bumps (a positive height) and hollows (negative) - each [across, up, its width across, its height up,
## how high, mirrored], in shares: across of half the face's width (s, -1 at the left as seen to 1 at the right), up of its
## height (t, 0 at the chin), how high of its depth. Drawn by eye against a face's proportions.
const BUMPS := [
	[0.36, 0.555, 0.25, 0.085, -0.10, true],    # the eye's socket
	[0.36, 0.553, 0.17, 0.06, 0.075, true],     # the eye under its closed lid
	[0.36, 0.64, 0.30, 0.045, 0.05, true],      # the brow's ridge
	[0.0, 0.63, 0.12, 0.05, 0.03, false],       # between the brows
	[0.0, 0.415, 0.10, 0.045, 0.10, false],     # the nose's tip
	[0.115, 0.395, 0.07, 0.035, 0.11, true],    # the nose's wing
	[0.07, 0.378, 0.04, 0.012, -0.03, true],    # under it
	[0.0, 0.33, 0.035, 0.03, -0.012, false],    # the groove over the lip
	[0.05, 0.33, 0.02, 0.03, 0.008, true],      # ...its ridges
	[0.0, 0.297, 0.27, 0.022, 0.055, false],    # the upper lip
	[0.0, 0.255, 0.23, 0.025, 0.065, false],    # the lower lip
	[0.29, 0.275, 0.04, 0.03, -0.02, true],     # the mouth's corners
	[0.0, 0.12, 0.22, 0.075, 0.085, false],     # the chin
	[0.0, 0.205, 0.18, 0.02, -0.025, false],    # under the lower lip
	[0.6, 0.48, 0.25, 0.10, 0.06, true],        # the cheekbones
	[0.55, 0.32, 0.18, 0.08, -0.03, true],      # under them
	[0.0, 0.82, 0.55, 0.12, 0.035, false],      # the forehead
	[0.85, 0.66, 0.15, 0.12, -0.03, true],      # the temples
]
## The nose's ridge from between the eyes down to its tip: [up at its top, up at its bottom, how high at the top, at the bottom,
## how wide at the top, at the bottom] - and where it ends under the tip.
const RIDGE := [0.62, 0.43, 0.10, 0.30, 0.07, 0.10]
const RIDGE_ENDS := Vector2(0.375, 0.405)
## The creases - a closed eye's lash line and the closed mouth's line: [across, up at its lowest, how far it rises at its ends
## (a share of the height), its half-length across, its width, how deep].
const LASH := [0.36, 0.540, 0.015, 0.17, 0.0085, 0.022]
const LIPS := [0.0, 0.277, -0.004, 0.29, 0.0065, 0.03]


## The face's size, made safe: [param v] as written ([width, height, depth] centimeters), else [constant SIZE].
static func size_of(v: Variant) -> Vector3:
	var s := Props._vec3(v, SIZE, SIZE_MOST.y, 0.1)
	return Vector3(clampf(s.x, SIZE_LEAST.x, SIZE_MOST.x), clampf(s.y, SIZE_LEAST.y, SIZE_MOST.y), clampf(s.z, SIZE_LEAST.z, SIZE_MOST.z))


## How far out of the outline (s, t) is: 0 at the middle, 1 on the rim, more outside - an egg, narrowing to the chin.
static func outside(s: float, t: float) -> float:
	var dy := t - MIDDLE
	var by := (1.0 - MIDDLE) if dy > 0.0 else MIDDLE
	var ax := 1.0 - JAW * pow(maxf(0.0, -dy / MIDDLE), JAW_CURVE)
	return sqrt(pow(s / ax, 2.0) + pow(dy / by, 2.0))


## The face's height over its rim at (s, t) - in shares of its depth, scaled by [param relief] (its features, 0-1.5) - and how
## shut in it is there ([method cavity]).
static func height(s: float, t: float, relief := 1.0) -> float:
	var r := outside(s, t)
	if r >= 1.0:
		return 0.0
	var dome := DOME * pow(1.0 - pow(r, DOME_FLAT.x), DOME_FLAT.y)
	var f := 0.0
	for b in BUMPS:
		var bb: Array = b
		f += float(bb[4]) * _bump(s, t, float(bb[0]), float(bb[1]), float(bb[2]), float(bb[3]))
		if bool(bb[5]):
			f += float(bb[4]) * _bump(s, t, -float(bb[0]), float(bb[1]), float(bb[2]), float(bb[3]))
	# the nose's ridge
	var k := clampf((t - float(RIDGE[1])) / (float(RIDGE[0]) - float(RIDGE[1])), 0.0, 1.0)
	var hb := lerpf(float(RIDGE[3]), float(RIDGE[2]), k)
	var wb := lerpf(float(RIDGE[5]), float(RIDGE[4]), k)
	f += hb * exp(-pow(s / wb, 2.0)) * smoothstep(RIDGE_ENDS.x, RIDGE_ENDS.y, t) * (1.0 - smoothstep(0.6, 0.66, t))
	f -= _crease(s, t, LASH, true) + _crease(s, t, LIPS, false)
	return dome + f * relief * (1.0 - smoothstep(FEATURES_FADE.x, FEATURES_FADE.y, r))


## How shut in the face is at (s, t), 0-1: the creases' depths and the sockets', which the surface darkens as the room's light
## reaches less of them (prop.gdshader's cavity).
static func cavity(s: float, t: float) -> float:
	var c := (_crease(s, t, LASH, true) / float(LASH[5])) * 0.45 + (_crease(s, t, LIPS, false) / float(LIPS[5])) * 0.5
	c += _bump(absf(s), t, 0.36, 0.585, 0.2, 0.04) * 0.12
	return clampf(c, 0.0, 1.0)


static func _bump(s: float, t: float, s0: float, t0: float, rs: float, rt: float) -> float:
	if absf(s - s0) > rs * 3.0 or absf(t - t0) > rt * 3.0:
		return 0.0
	return exp(-pow((s - s0) / rs, 2.0) - pow((t - t0) / rt, 2.0))


## A crease's depth at (s, t) ([constant LASH], [constant LIPS]) - mirrored for a pair.
static func _crease(s: float, t: float, c: Array, pair: bool) -> float:
	var out := 0.0
	for side in ([-1.0, 1.0] if pair else [1.0]):
		var ds := s - float(c[0]) * float(side)
		var half := float(c[3])
		if absf(ds) > half:
			continue
		var tc := float(c[1]) + float(c[2]) * pow(ds / half, 2.0)
		out += float(c[5]) * exp(-pow((t - tc) / float(c[4]), 2.0)) * (1.0 - smoothstep(half * 0.7, half, absf(ds)))
	return out


## The face's point at (x, y) centimeters (x across from its middle, y up from its chin): [x, y, z] centimeters, z its height
## out of its rim - for a face [param size] (centimeters) of [param relief].
static func point(x: float, y: float, size: Vector3, relief := 1.0) -> Vector3:
	return Vector3(x, y, height(x / (size.x * 0.5), y / size.y, relief) * size.z)


## Its normal there, from the height's own slope.
static func normal(x: float, y: float, size: Vector3, relief := 1.0) -> Vector3:
	var e := 0.02
	var dx := (point(x + e, y, size, relief).z - point(x - e, y, size, relief).z) / (2.0 * e)
	var dy := (point(x, y + e, size, relief).z - point(x, y - e, size, relief).z) / (2.0 * e)
	return Vector3(-dx, -dy, 1.0).normalized()


## The mask as [Props] builds it, from its made-safe part [param p] (`size`, `relief`, `thick`): the face, its flat back, and
## the rim between. UV is (s, t); UV2's y how shut in it is (prop.gdshader). Built once a size and kept: every episode's mask
## is the same one, and a face is some hundred thousand evaluations of [method height].
static func build(p: Dictionary) -> Props.Tris:
	var size: Vector3 = p.get("size", SIZE)
	var relief := float(p.get("relief", 1.0))
	var thick := float(p.get("thick", THICK))
	var key := "%s|%.3f|%.3f" % [size, relief, thick]
	_lock.lock()
	var kept: Props.Tris = _kept.get(key)
	_lock.unlock()
	if kept == null:
		kept = _built(size, relief, thick)
		_lock.lock()
		if _kept.size() > 8:
			_kept.clear()
		_kept[key] = kept
		_lock.unlock()
	var g := Props.Tris.new()
	g.v = kept.v.duplicate()
	g.n = kept.n.duplicate()
	g.uv = kept.uv.duplicate()
	g.uv2 = kept.uv2.duplicate()
	g.girth = kept.girth
	g.height = kept.height
	g.top = kept.top
	return g


static var _kept := {}
static var _lock := Mutex.new()


## The face is cut to its own outline: every point of the grid over the front is kept and its outer band is pulled in along its way from
## the middle ([method _pulled_in]), so the grid's edge lands on the rim and every row near it runs smoothly into it, and inside
## [constant PULL_FROM] (every feature) the grid is unchanged, its rows along the creases. (Cutting the grid where the outline crosses it
## leaves the last point inside anywhere from 1 to 5 mm high, a sawtooth round the rim; pushing the grid out in copies of the outline
## draws the mouth's line in stairs.) Its normals are the surface's own, across the two ways the grid runs; the rim's, the height's slope there.
static func _built(size: Vector3, relief: float, thick: float) -> Props.Tris:
	var g := Props.Tris.new()
	var step := STEP * maxf(size.x / SIZE.x, 1.0)
	var nx := int(ceil(size.x / step))
	var ny := int(ceil(size.y / step))
	var reach := _rim_reach()
	var w := nx + 1
	var pts := PackedVector3Array()
	var sts := PackedVector2Array()
	pts.resize(w * (ny + 1))
	sts.resize(w * (ny + 1))
	for j in ny + 1:
		for i in nx + 1:
			var q := _pulled_in(-1.0 + 2.0 * float(i) / float(nx), float(j) / float(ny), reach)
			var p := point(q.x * size.x * 0.5, q.y * size.y, size, relief)
			if i == 0 or j == 0 or i == nx or j == ny:
				p.z = 0.0
			sts[j * w + i] = q
			pts[j * w + i] = p * 0.01
	var nrm := PackedVector3Array()
	nrm.resize(pts.size())
	for j in ny + 1:
		for i in nx + 1:
			var k := j * w + i
			if i == 0 or j == 0 or i == nx or j == ny:
				nrm[k] = normal(sts[k].x * size.x * 0.5, sts[k].y * size.y, size, relief)
				continue
			nrm[k] = (pts[k + 1] - pts[k - 1]).cross(pts[k + w] - pts[k - w]).normalized()
	var cav := PackedVector2Array()
	cav.resize(pts.size())
	for k in pts.size():
		cav[k] = Vector2(0.0, cavity(sts[k].x, sts[k].y))
	for j in ny:
		for i in nx:
			var a := j * w + i
			var b := a + 1
			var c := a + w + 1
			var d := a + w
			g.tri(pts[a], pts[b], pts[c], nrm[a], nrm[b], nrm[c], sts[a], sts[b], sts[c], cav[a], cav[b], cav[c])
			g.tri(pts[a], pts[c], pts[d], nrm[a], nrm[c], nrm[d], sts[a], sts[c], sts[d], cav[a], cav[c], cav[d])
	# The rim, the grid's own edge round from the face back to the back's, and the back, flat: a fan from its middle
	var ring := PackedInt32Array()
	for i in nx:
		ring.append(i)
	for j in ny:
		ring.append(j * w + nx)
	for i in range(nx, 0, -1):
		ring.append(ny * w + i)
	for j in range(ny, 0, -1):
		ring.append(j * w)
	var back := Vector3(0.0, 0.0, -thick * 0.01)
	var mid := Vector3(0.0, MIDDLE * size.y * 0.01, 0.0) + back
	var z0 := Vector2.ZERO
	for k in ring.size():
		var ka := ring[k]
		var kb := ring[(k + 1) % ring.size()]
		var pa := pts[ka]
		var pb := pts[kb]
		var na := Vector3(pa.x, pa.y - MIDDLE * size.y * 0.01, 0.0).normalized()
		var nb := Vector3(pb.x, pb.y - MIDDLE * size.y * 0.01, 0.0).normalized()
		g.quad(pa, pb, pb + back, pa + back, na, nb, nb, na, sts[ka], sts[kb], sts[kb], sts[ka], 0.0, 0.0, 0.0, 0.0)
		g.tri(mid, pb + back, pa + back, Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD, Vector2(0.0, MIDDLE), sts[kb], sts[ka], z0, z0, z0)
	g.measure()
	return g


## The grid's point (s, t) of the front's box (s -1 to 1, t 0 to 1) pulled in onto the face: along its way from the middle, as it
## was out to [constant PULL_FROM] of the way to the rim, and from there to the box's edge laid evenly over what is left of the
## way to the rim - the box's edge on the rim. [param reach] is [method _rim_reach].
static func _pulled_in(s: float, t: float, reach: PackedFloat32Array) -> Vector2:
	var d := Vector2(s, t - MIDDLE)
	var far := d.length()
	if far <= 0.0:
		return Vector2(0.0, MIDDLE)
	var dir := d / far
	var f := (atan2(dir.y, dir.x) + PI) / TAU * float(RIM_REACH)
	var k := int(floor(f))
	var rim := lerpf(reach[k % RIM_REACH], reach[(k + 1) % RIM_REACH], f - float(k))
	var box := INF
	if absf(dir.x) > 1e-9:
		box = 1.0 / absf(dir.x)
	if dir.y > 1e-9:
		box = minf(box, (1.0 - MIDDLE) / dir.y)
	elif dir.y < -1e-9:
		box = minf(box, MIDDLE / -dir.y)
	var out := far / rim
	var edge := box / rim
	if out > PULL_FROM and edge > PULL_FROM:
		out = PULL_FROM + (out - PULL_FROM) * (1.0 - PULL_FROM) / (edge - PULL_FROM)
	return Vector2(0.0, MIDDLE) + dir * minf(out, 1.0) * rim


## How far the rim is from the middle (in (s, t)) at RIM_REACH ways round from -PI ([method _rim_point]).
static func _rim_reach() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(RIM_REACH)
	for k in RIM_REACH:
		out[k] = (_rim_point(-PI + TAU * float(k) / float(RIM_REACH)) - Vector2(0.0, MIDDLE)).length()
	return out


## The rim's point at angle [param a] round the middle, as (s, t).
static func _rim_point(a: float) -> Vector2:
	var d := Vector2(cos(a), sin(a))
	# walk out until the outline (it is star-shaped about the middle)
	var lo := 0.0
	var hi := 2.0
	for _k in 30:
		var m := (lo + hi) * 0.5
		if outside(d.x * m, MIDDLE + d.y * m) < 1.0:
			lo = m
		else:
			hi = m
	return Vector2(d.x * lo, MIDDLE + d.y * lo)


## The face's landmarks, as a designer reads them: each a place in millimeters from the top left corner of the face seen from
## the front (x to the right as you look at it, y down), and how wide it is - for a face [param size] centimeters. Left and right
## are as you look at the face, never the face's own.
static func landmarks(size: Vector3) -> Dictionary:
	var mm := func(s: float, t: float) -> Vector2:
		return Vector2((s + 1.0) * 0.5 * size.x * 10.0, (1.0 - t) * size.y * 10.0)
	var half := size.x * 5.0
	var out := {}
	for side in [["left", -1.0], ["right", 1.0]]:
		var sg := float(side[1])
		var lash: Vector2 = mm.call(float(LASH[0]) * sg, float(LASH[1]))
		out["%s eye (closed: its lash line)" % side[0]] = {"at": lash,
			"from": mm.call((float(LASH[0]) - float(LASH[3])) * sg, float(LASH[1]) + float(LASH[2])),
			"to": mm.call((float(LASH[0]) + float(LASH[3])) * sg, float(LASH[1]) + float(LASH[2])), "wide": float(LASH[3]) * 2.0 * half}
		out["%s eyelid" % side[0]] = {"at": mm.call(0.36 * sg, 0.565), "wide": 0.32 * half}
		out["%s brow ridge" % side[0]] = {"at": mm.call(0.36 * sg, 0.64), "wide": 0.5 * half}
		out["%s cheekbone" % side[0]] = {"at": mm.call(0.6 * sg, 0.47), "wide": 0.4 * half}
		out["%s temple" % side[0]] = {"at": mm.call(0.85 * sg, 0.66), "wide": 0.2 * half}
		out["%s corner of the mouth" % side[0]] = {"at": mm.call(float(LIPS[3]) * sg, float(LIPS[1]) + float(LIPS[2])), "wide": 0.0}
	out["between the brows"] = {"at": mm.call(0.0, 0.63), "wide": 0.2 * half}
	out["the nose's bridge"] = {"at": mm.call(0.0, 0.57), "wide": 0.16 * half}
	out["the nose's tip"] = {"at": mm.call(0.0, 0.415), "wide": 0.22 * half}
	out["the mouth (closed: the line between the lips)"] = {"at": mm.call(0.0, float(LIPS[1])), "wide": float(LIPS[3]) * 2.0 * half}
	out["the upper lip"] = {"at": mm.call(0.0, 0.297), "wide": 0.5 * half}
	out["the lower lip"] = {"at": mm.call(0.0, 0.255), "wide": 0.44 * half}
	out["the chin"] = {"at": mm.call(0.0, 0.12), "wide": 0.4 * half}
	out["the forehead's middle"] = {"at": mm.call(0.0, 0.82), "wide": 1.0 * half}
	out["the top of the face"] = {"at": mm.call(0.0, 1.0), "wide": 0.0}
	out["the bottom of the chin"] = {"at": mm.call(0.0, 0.0), "wide": 0.0}
	return out


## The outline as a closed SVG path in the designer's millimeters ([method landmarks]) - the edge of the face, for a design to
## stay inside, or to fill all of it.
static func outline_path(size: Vector3) -> String:
	var bits := PackedStringArray()
	var n := 72
	for k in n:
		var st := _rim_point(TAU * float(k) / float(n))
		var x := (st.x + 1.0) * 0.5 * size.x * 10.0
		var y := (1.0 - st.y) * size.y * 10.0
		bits.append("%s %.1f %.1f" % ["M" if k == 0 else "L", x, y])
	return " ".join(bits) + " Z"
