extends RefCounted
class_name Branch3D

## Branch3D - a bracketed L-system that emits segments in three dimensions, plus the tapered-tube loft that turns them into
## drawable faces. The 3D form of [Filament]'s recursion, with two rules a plant needs:
##
##   Multi-child whorls: a node throws 2-4 children at once from one point, deterministically, rather than forking by a coin
##   per step (the difference between a vine and a crown).
##
##   A divergence roll: successive whorls are rotated about the parent's own axis by a fixed angle, so a branch system reads as
##   a spiral staircase rather than a flat fan. [constant DIVERGENCE] holds the four angles botany uses, not a range.
##
## [method sample_species] rolls one dictionary that is the whole genome: fork angle and how it tightens with depth, the
## divergence roll, length and width ratios between parent and child, child count, clear trunk below the crown, a leader
## fraction (how nearly straight the continuing axis runs, which gives a tree a trunk), gravitropism, phototropism toward the
## sun, droop on the outer orders, buttress flare at the base, and trunk lean.
##
## The budget is part of the algorithm: axis count is children^depth. Growth proceeds level by level and a level is accepted
## only if it fits whole (a half-expanded level looks broken, a level short is a younger tree); [method sample_species] also
## trades depth against width.
##
## Coordinates: everything grows in local space with the base at the origin and +y up, and the finished model is rescaled so its
## real height is exactly the height asked for. A caller instances one model many times by scaling, yawing and bending it at
## draw time.
##
## The emitters append the same face dictionaries the terrain merge path uses ({d, poly, cols}, or {d, fan, fcols} for a soft
## billboard), so tree faces depth-sort against terrain quads in one list.

const UP := Vector3(0, 1, 0)

## The divergence angles between successive whorls that plants use: 137.5 degrees (golden angle, spiral phyllotaxis), 90
## (decussate), 180 (distichous), 120 (three-ranked whorl). Four discrete choices: the angle is a species trait, not a tolerance.
const DIVERGENCE := [137.5, 90.0, 180.0, 120.0]


## Roll one species: the per-depth rule table, and every tunable of it sampled. Depth and children are not independent draws:
## a wide species is capped shallow, because the level budget would discard the outer orders of a wide deep tree.
static func sample_species(rng: RandomNumberGenerator) -> Dictionary:
	var children := rng.randi_range(2, 4)
	var depth := rng.randi_range(3, 6)
	if children >= 4:
		depth = mini(depth, 4)
	elif children == 3:
		depth = mini(depth, 5)
	return {
		"depth": depth,
		"children": children,
		# The fork angle off the parent axis: narrow reads as a poplar, wide as an old oak.
		"angle": rng.randf_range(18.0, 55.0),
		# How the fork angle scales per order: below 1 the twigs close up toward the light, above 1 they splay out.
		"angle_falloff": rng.randf_range(0.78, 1.12),
		"roll": DIVERGENCE[rng.randi() % DIVERGENCE.size()],
		"ratio": rng.randf_range(0.55, 0.82),
		# The leader: child 0 of every whorl continues the parent's axis at this fraction of the fork angle and a little longer than its siblings.
		"leader": rng.randf_range(0.10, 0.45),
		"leader_ratio": rng.randf_range(1.0, 1.35),
		"taper": rng.randf_range(0.62, 0.78),
		"internodes": rng.randi_range(2, 4),
		"crown": rng.randf_range(0.25, 0.70),
		# Gravitropism: how hard each internode re-aims toward vertical. Slightly negative is a weeping form.
		"tropism": rng.randf_range(-0.05, 0.34),
		"photo": rng.randf_range(0.0, 0.22),
		"droop": rng.randf_range(0.0, 0.34),
		"lean": rng.randf_range(0.0, 0.16),
		"flare": rng.randf_range(1.15, 1.95),
		"jitter": rng.randf_range(0.05, 0.22),
		"leaf_size": rng.randf_range(0.030, 0.085),
		"leaf_ragged": rng.randf_range(0.12, 0.38),
		# How readily the trunk throws side branches between whorls.
		"lateral": rng.randf_range(0.35, 1.0),
	}


## Grow one model. Returns `{segs, leaves, puffs, level_end, height, radius, depth, crown, crown_r}` in local space (base at
## the origin, +y up, real height == [param height]).
##
## Each segment is `{a, b, w0, w1, depth, born0, born}`: `born0`/`born` are its start and end as a fraction of the longest path
## from the base, so one scalar reveals the structure with the growth front sweeping outward from the trunk.
static func grow(sp: Dictionary, rng: RandomNumberGenerator, height: float,
		radius: float, sun: Vector3, budget := 200) -> Dictionary:
	var depth_max: int = int(sp["depth"])
	var children: int = int(sp["children"])
	var ratio: float = float(sp["ratio"])
	var taper: float = float(sp["taper"])
	var base_angle: float = deg_to_rad(float(sp["angle"]))
	var falloff: float = float(sp["angle_falloff"])
	var roll_step: float = deg_to_rad(float(sp["roll"]))
	var tropism: float = float(sp["tropism"])
	var photo: float = float(sp["photo"])
	var droop: float = float(sp["droop"])
	var jitter: float = float(sp["jitter"])
	var lead_frac: float = float(sp["leader"])
	var lead_ratio: float = float(sp["leader_ratio"])
	var crown: float = float(sp["crown"])
	var flare: float = float(sp["flare"])
	var internodes: int = int(sp["internodes"])
	var lateral: float = float(sp["lateral"])
	var sun_dir := sun.normalized() if sun.length() > 1e-6 else UP
	# The heading every internode is pulled toward: vertical, biased toward the sun.
	var want := UP.lerp(sun_dir, clampf(photo, 0.0, 1.0)).normalized()

	var segs: Array = []
	# The trunk axis is only the clear part of the tree; the crown is built above it by the leader, so the axis is shortened by
	# the crown fraction and the final rescale restores the requested height.
	var level: Array = [{
		"p": Vector3.ZERO, "dir": _jog(UP, float(sp["lean"]), rng),
		"len": height * (1.0 - crown * 0.55), "w": radius,
		"roll": rng.randf() * TAU, "path": 0.0}]
	var d := 0
	var deepest := 0
	while d <= depth_max and not level.is_empty():
		var next: Array = []
		for entry in level:
			var ax: Dictionary = entry
			# Finer wood is drawn with fewer internodes: it curves less and costs less.
			var n := maxi(1, internodes - int(d / 2))
			var alen: float = float(ax["len"])
			var aw: float = float(ax["w"])
			var pos: Vector3 = ax["p"]
			var dir: Vector3 = ax["dir"]
			var path: float = float(ax["path"])
			var roll: float = float(ax["roll"])
			var seg_len := alen / float(n)
			# Tropism is spent over the whole axis, so a twig and a trunk bend by the same total amount.
			var pull := clampf(tropism - droop * float(d) / float(maxi(1, depth_max)),
				-0.5, 0.8) / float(n)
			for i in n:
				dir = _jog(dir.lerp(want, pull).normalized(), jitter / float(n), rng)
				var t0 := float(i) / float(n)
				var t1 := float(i + 1) / float(n)
				# The buttress: only the trunk flares, only near the ground (cubed, confining the swelling to the base).
				var fl0 := 1.0
				var fl1 := 1.0
				if d == 0:
					fl0 = 1.0 + (flare - 1.0) * pow(1.0 - t0, 3.0)
					fl1 = 1.0 + (flare - 1.0) * pow(1.0 - t1, 3.0)
				var a: Vector3 = pos
				var b: Vector3 = pos + dir * seg_len
				var p0 := path
				path += seg_len
				segs.append({"a": a, "b": b,
					"w0": aw * lerpf(1.0, taper, t0) * fl0,
					"w1": aw * lerpf(1.0, taper, t1) * fl1,
					"depth": d, "path0": p0, "path": path})
				pos = b
				# A side branch off the trunk between whorls (the rooted_growth lateral, in 3D).
				if d == 0 and i < n - 1 and t1 > crown * 0.6 and rng.randf() < lateral:
					next.append(_child_at(pos, dir,
						roll + roll_step * float(i + 1) + rng.randf_range(-jitter, jitter),
						base_angle * rng.randf_range(0.85, 1.30),
						alen * ratio * rng.randf_range(0.6, 0.9),
						aw * lerpf(1.0, taper, t1) * rng.randf_range(0.45, 0.68),
						roll + roll_step, path))
			deepest = maxi(deepest, d)
			if d >= depth_max:
				continue
			var tip_w := aw * taper
			var ang := base_angle * pow(falloff, float(d))
			for k in children:
				var phi := roll + TAU * float(k) / float(children) \
					+ rng.randf_range(-jitter, jitter)
				var theta := ang * rng.randf_range(0.8, 1.2)
				var clen := alen * ratio * rng.randf_range(0.85, 1.15)
				var cw := tip_w * rng.randf_range(0.5, 0.72)
				if k == 0:
					theta *= lead_frac                 # the leader continues the axis
					clen *= lead_ratio
					cw = tip_w * 0.92
				next.append(_child_at(pos, dir, phi, theta, clen, cw, roll + roll_step, path))
		# The level budget: accept the next order only if it fits whole.
		var est := next.size() * maxi(1, internodes - int((d + 1) / 2))
		if segs.size() + est > budget:
			next = []
		level = next
		d += 1

	# Normalize the growth front and put the silhouette back at the requested height. Widths are not rescaled: a radius passed as
	# a fraction of the final height is exactly that.
	var pmax := 0.001
	var ymax := 0.001
	for entry in segs:
		var sg: Dictionary = entry
		pmax = maxf(pmax, float(sg["path"]))
		var av: Vector3 = sg["a"]
		var bv: Vector3 = sg["b"]
		ymax = maxf(ymax, maxf(av.y, bv.y))
	var k := height / ymax
	for entry in segs:
		var sg: Dictionary = entry
		sg["a"] = (sg["a"] as Vector3) * k
		sg["b"] = (sg["b"] as Vector3) * k
		sg["born0"] = clampf(float(sg["path0"]) / pmax, 0.0, 1.0)
		sg["born"] = clampf(float(sg["path"]) / pmax, 0.0, 1.0)

	# Level index: segments are appended level by level, so `level_end[k]` is the index past the last segment of order k, and a
	# caller stops early by depth (silhouette LOD costs nothing).
	var level_end := PackedInt32Array()
	level_end.resize(deepest + 1)
	for si in segs.size():
		var sg: Dictionary = segs[si]
		level_end[int(sg["depth"])] = si + 1
	for lk in range(1, level_end.size()):
		level_end[lk] = maxi(level_end[lk], level_end[lk - 1])

	# Leaf sites: the outer two orders only, strided down to a cap (foliage is held in masses).
	var leaves: Array = []
	var outer: Array = []
	var leaf_order := maxi(0, deepest - 1)
	for entry in segs:
		var sg: Dictionary = entry
		if int(sg["depth"]) >= leaf_order:
			outer.append(sg)
	# The cap is the foliage's grain: at 46 sites the clusters are a third of the crown's radius across and read as colored
	# card; three times the sites makes each a third the size. The near LOD band is capped at a dozen trees to bound the
	# billboards.
	var cap := 112
	var stride := maxi(1, int(ceil(float(outer.size()) / float(cap))))
	var lsize: float = float(sp["leaf_size"]) * height
	# `along` is renormalized over the leaves' own range of born-fractions (raw, they all sit near 1.0, so a base-to-tip hue turn
	# keyed to it would be a constant offset).
	var blo := 1.0
	var bhi := 0.0
	for entry in outer:
		var sg: Dictionary = entry
		blo = minf(blo, float(sg["born"]))
		bhi = maxf(bhi, float(sg["born"]))
	var bspan := maxf(1e-3, bhi - blo)
	for oi in range(0, outer.size(), stride):
		var sg: Dictionary = outer[oi]
		var av: Vector3 = sg["a"]
		var bv: Vector3 = sg["b"]
		var tw := bv - av
		tw = tw.normalized() if tw.length() > 1e-6 else UP
		leaves.append({
			"p": bv, "dir": tw,
			"size": lsize * rng.randf_range(0.7, 1.35),
			"phase": rng.randf() * TAU,
			"hue": rng.randf_range(-0.035, 0.035),
			"ragged": rng.randf() * TAU,
			"along": clampf((float(sg["born"]) - blo) / bspan, 0.0, 1.0),
			"born": float(sg["born"])})

	# The silhouette form: a handful of crown puffs a distant tree collapses to, measured off the leaf mass so the far tree
	# occupies the same space as the near one.
	var cen := Vector3.ZERO
	var crad := height * 0.22
	if not leaves.is_empty():
		for entry in leaves:
			var lf: Dictionary = entry
			cen += lf["p"] as Vector3
		cen /= float(leaves.size())
		crad = 0.001
		for entry in leaves:
			var lf: Dictionary = entry
			crad = maxf(crad, ((lf["p"] as Vector3) - cen).length())
	else:
		cen = Vector3(0.0, height * 0.72, 0.0)
	# The puff cloud must fit inside the crown it stands for: offsets and radii sum to 1.0, so the far tree is not bigger than
	# the near one.
	var puffs: Array = []
	for _pi in rng.randi_range(4, 7):
		var off := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.8, 0.8),
			rng.randf_range(-1.0, 1.0))
		if off.length() > 1.0:
			off = off.normalized()
		var orad := rng.randf_range(0.40, 0.62)
		puffs.append({
			"p": cen + off * crad * (1.0 - orad),
			"r": crad * orad,
			"ragged": rng.randf() * TAU})
	return {"segs": segs, "leaves": leaves, "puffs": puffs, "height": height,
		"radius": radius, "depth": deepest, "crown": cen, "crown_r": crad,
		"level_end": level_end}


# One child axis: a heading built from the parent's own frame - `phi` around the parent axis (the divergence roll), `theta` away from it (the fork angle).
static func _child_at(pos: Vector3, dir: Vector3, phi: float, theta: float,
		clen: float, cw: float, roll: float, path: float) -> Dictionary:
	var fx := dir.cross(UP)
	if fx.length() < 1e-4:
		fx = dir.cross(Vector3(1, 0, 0))
	fx = fx.normalized()
	var fz := fx.cross(dir).normalized()
	var cd := (dir * cos(theta) + (fx * cos(phi) + fz * sin(phi)) * sin(theta)).normalized()
	return {"p": pos, "dir": cd, "len": clen, "w": cw, "roll": roll, "path": path}


# A small random deflection of a heading, so the structure does not read as machined.
static func _jog(v: Vector3, amount: float, rng: RandomNumberGenerator) -> Vector3:
	var n := v.normalized() if v.length() > 1e-6 else UP
	if amount <= 0.0:
		return n
	var r := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0),
		rng.randf_range(-1.0, 1.0))
	var out := n + r * amount
	return out.normalized() if out.length() > 1e-6 else n


## The camera's screen-aligned right / up axes in world space, for billboards. Returns `[right, up]`. [Lens3D] caches this
## internally but does not expose it.
static func cam_axes(lens: Lens3D) -> Array:
	var fwd := lens.look - lens.eye
	fwd = fwd.normalized() if fwd.length() > 1e-6 else Vector3(0, 0, -1)
	var right := fwd.cross(lens.up)
	right = right.normalized() if right.length() > 1e-6 else Vector3(1, 0, 0)
	return [right, right.cross(fwd).normalized()]


## The tapered-tube loft. One segment becomes a closed `sides`-gon tube from radius [param w0] to [param w1], back-face culled
## (safe because the tube is closed).
##
## Faces append as `{d, poly, cols}`, the shape [method Terrain.collect_surface] returns, so a caller merges wood and land into
## one depth-sorted list. Shading is the key light's n.l over an [param ambient] floor, plus [param rim], a term that peaks where
## the surface turns away from the eye, which is the only channel the audio glow drives on bark.
static func loft_tube(faces: Array, lens: Lens3D, u: float, a: Vector3, b: Vector3,
		w0: float, w1: float, sides: int, col: Color, ldir: Vector3,
		ambient := 0.42, rim := 0.0) -> void:
	var axis := b - a
	var alen := axis.length()
	if alen < 1e-6 or sides < 3:
		return
	var dir := axis / alen
	var fx := dir.cross(UP)
	if fx.length() < 1e-4:
		fx = dir.cross(Vector3(1, 0, 0))
	fx = fx.normalized()
	var fz := fx.cross(dir).normalized()
	var vdir := (a + b) * 0.5 - lens.eye
	if vdir.length_squared() < 1e-12:
		return
	vdir = vdir.normalized()
	var offs: Array = []
	for s in sides:
		var ang := TAU * float(s) / float(sides)
		offs.append(fx * cos(ang) + fz * sin(ang))
	for s in sides:
		var o0: Vector3 = offs[s]
		var o1: Vector3 = offs[(s + 1) % sides]
		var nrm := (o0 + o1).normalized()
		if nrm.dot(vdir) > 0.02:
			continue                                  # facing away - the tube is closed
		var r0 := lens.project(a + o0 * w0)
		var r1 := lens.project(a + o1 * w0)
		var r2 := lens.project(b + o1 * w1)
		var r3 := lens.project(b + o0 * w1)
		if r0.z <= lens.near or r1.z <= lens.near or r2.z <= lens.near or r3.z <= lens.near:
			continue
		var poly := PackedVector2Array([Vector2(r0.x, r0.y) * u, Vector2(r1.x, r1.y) * u,
			Vector2(r2.x, r2.y) * u, Vector2(r3.x, r3.y) * u])
		if Terrain._quad_area(poly) < 0.30:
			continue
		var sh := ambient + (1.0 - ambient) * clampf(nrm.dot(ldir), 0.0, 1.0)
		sh += rim * pow(clampf(1.0 - absf(nrm.dot(vdir)), 0.0, 1.0), 3.0)
		var lo := Color(col.r * sh, col.g * sh, col.b * sh, col.a)
		var k := sh * 1.07
		var hi := Color(col.r * k, col.g * k, col.b * k, col.a)
		faces.append({"d": (r0.z + r1.z + r2.z + r3.z) * 0.25, "poly": poly,
			"cols": PackedColorArray([lo, lo, hi, hi])})


## The LOD form of the same segment: one camera-facing tapered ribbon instead of a tube. Built in screen space: a sub-pixel
## twig is discarded or rasterized as nothing, so widening to a floor of [param min_px] after projection keeps every twig a
## visible hairline.
static func loft_ribbon(faces: Array, lens: Lens3D, u: float, a: Vector3, b: Vector3,
		w0: float, w1: float, ca: Color, cb: Color, min_px := 0.55) -> void:
	var axis := b - a
	if axis.length_squared() < 1e-12:
		return
	var view := (a + b) * 0.5 - lens.eye
	var side := axis.cross(view)
	if side.length_squared() < 1e-14:
		return
	side = side.normalized()
	var pa := lens.project(a)
	var pb := lens.project(b)
	if pa.z <= lens.near or pb.z <= lens.near:
		return
	var sa := lens.project(a + side)
	var sb := lens.project(b + side)
	var oa := Vector2(pa.x, pa.y) * u
	var ob := Vector2(pb.x, pb.y) * u
	var ea := (Vector2(sa.x, sa.y) * u - oa) * w0
	var eb := (Vector2(sb.x, sb.y) * u - ob) * w1
	var la := ea.length()
	var lb := eb.length()
	if la < min_px:
		ea = (ea / la) * min_px if la > 1e-6 else Vector2(min_px, 0.0)
	if lb < min_px:
		eb = (eb / lb) * min_px if lb > 1e-6 else Vector2(min_px, 0.0)
	# A point just past the near plane projects to coordinates in the millions: the near-plane test above catches most, this the rest.
	if not (is_finite(oa.x) and is_finite(oa.y) and is_finite(ob.x) and is_finite(ob.y)):
		return
	if maxf(absf(oa.x), absf(oa.y)) > 1.0e6 or maxf(absf(ob.x), absf(ob.y)) > 1.0e6:
		return
	var poly := PackedVector2Array([oa - ea, oa + ea, ob + eb, ob - eb])
	faces.append({"d": (pa.z + pb.z) * 0.5, "poly": poly,
		"cols": PackedColorArray([ca, ca, cb, cb])})


## A billboard cluster: one leaf mass, or one crown puff of a distant tree.
##
## A fan with an opaque core, a rim whose radius is modulated per vertex so the silhouette is broken, and a rim alpha that decides
## whether the thing has an edge at all. Not a textured quad: a second texture in the merged depth-sorted list cuts the batch at
## every crossing between land and foliage.
##
## [param hard]: at 0 the rim is fully transparent and the cluster is a soft radial gradient (a cloud puff); at 1 the rim carries
## the core's own alpha and the boundary is hard and jagged; between them is a leaf clump, mostly solid with the gradient
## compressed into a thin outer band.
##
## The silhouette takes two harmonics (a slow lobe for the mass's shape, a faster one for clumping) and a per-vertex hash for the
## leaf-scale break. The hash is keyed on `s % sides` so the closing vertex lands on the opening one.
##
## Faces append as `{d, fan, fcols}`; the caller draws them with [method TriBatch.tri_colored].
static func billboard_fan(faces: Array, lens: Lens3D, u: float, c: Vector3,
		right: Vector3, up: Vector3, r: float, core: Color, sides := 5,
		ragged := 0.25, phase := 0.0, hard := 0.0) -> void:
	if r <= 0.0 or core.a <= 0.004:
		return
	var pc := lens.project(c)
	if pc.z <= lens.near:
		return
	var pr := lens.project(c + right * r)
	var pu := lens.project(c + up * r)
	var o := Vector2(pc.x, pc.y) * u
	var ex := Vector2(pr.x, pr.y) * u - o
	var ey := Vector2(pu.x, pu.y) * u - o
	if ex.length() < 0.8 and ey.length() < 0.8:
		return                                        # sub-pixel: not worth the triangles
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	pts.append(o)
	cols.append(core)
	var k := clampf(hard, 0.0, 1.0)
	# The rim keeps a share of the core's alpha and darkens a little as it goes: lit on top, shaded at its edge.
	var dim := lerpf(1.0, 0.74, k)
	var edge := Color(core.r * dim, core.g * dim, core.b * dim, core.a * k)
	for s in sides + 1:
		var si := s % sides
		var ang := TAU * float(si) / float(sides) + phase
		var jag := _rim_hash(si, phase) - 0.5
		var rr := 1.0 + ragged * (0.55 * sin(3.0 * ang + phase * 2.0)
			+ 0.30 * sin(7.0 * ang - phase * 1.3) + 0.75 * jag)
		pts.append(o + ex * (cos(ang) * rr) + ey * (sin(ang) * rr))
		cols.append(edge)
	faces.append({"d": pc.z, "fan": pts, "fcols": cols})


# A deterministic 0..1 per rim vertex, keyed on the vertex index and the cluster's phase, so a cluster's outline is fixed for its
# lifetime and no two clusters share one.
static func _rim_hash(i: int, phase: float) -> float:
	return fposmod(sin(float(i) * 12.9898 + phase * 78.233) * 43758.5453, 1.0)
