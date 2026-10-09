extends SceneTree

## props_check - THE SHAPES A THING IS BUILT FROM ([Props]): how a profile or a path is drawn, the
## loft, the coil and the warp, held to what they say they make. Built headless (meshes only).
##
##   godot --headless --path . --script tests/props_check.gd
##
## - A FLAT BASE AND A FLAT TOP STAY FLAT in a smooth profile: a set dresser's teapot, as written,
##   neither sags below the cloth nor domes above its top - the control, the same points curved
##   through with no corners kept, does both (the bulbous pot it was).
## - A CORNER IS WHERE IT IS WRITTEN: [r, h, 0] is a crisp corner in a smooth profile, and the same
##   point without its 0 is not.
## - A ROUNDED ELBOW: a path point written with a rounding passes beside its corner, an arc away -
##   the same point unrounded passes through it.
## - A KINK KEEPS ITS WIDTH: every point of a rod bent square lies a radius from its path - the
##   control, a ring laid square to the bend and not stretched, pinches to 0.71 of one inside it.
## - A LOFT IS CLOSED, solid or hollow: every edge has a face on both sides - and the same mesh less
##   one triangle does not (the measure can fail).
## - A LOFT'S SECTIONS ARE WHERE THEY ARE SAID: round at its foot, the turned rectangle at its top -
##   and unturned, the top is not the turned one.
## - A BEND BENDS: a warped block's top comes round to where a bend that far puts it, and halfway up
##   it lies on the curve, not on the straight line - the control, the same block built coarse and
##   warped, has nothing halfway up to bend.
## - NORMALS FOLLOW A WARP: a ball scaled into an ellipsoid shades as the ellipsoid - its unwarped
##   normals do not.
## - A WOBBLE OPENS NO SEAM: a wobbled vessel is as closed as it was, and the same seed wobbles it the
##   same - the control, pushed out along its normals instead, splits at its crisp corners.
## - WHATEVER IS WRITTEN IS BUILDABLE: junk sections, warps and roundings come out in range.
## - A STRAND RESTS ON ITSELF (2026-10-07, ropes, vines and wires asked for): wherever a coil or a tangle
##   crosses itself the crossing rides over, never through - no two points of it further apart along it
##   than its width come closer than nine tenths of a width - and it never lies below the cloth or jumps
##   up a step. Two-sided: the same tangle laid flat, every point on the cloth, passes through itself.
## - A STRAND DRAPED over the table's edge hangs down past it as far as it ran past, to the floor at most,
##   and never into the table: every point over the top lies on it. Two-sided: with no ground it lies flat.
## - BONES AND SKULLS rest on the cloth, are the length asked, and a draped thing keeps only its strand.
## - A SCULPT (2026-10-07: "grant the agents the ability to draw their own geometry") is one closed surface;
##   a carve goes right through - a line through a ball carved by a rod meets no face, and through the same
##   ball uncarved it does; mirrored, a stroke drawn on the right is on the left too, and unmirrored it is
##   not; its hollows are shut in - a well carved into a ball is darker inside than its outside, and a ball's is open
##   all round; a stroke finer than the sculpt is cut is found before it is built, and a thick one is not.
##   And THE SKULLS ARE SCULPTS: a bird's orbits are open right through it, where a line through its
##   braincase is not.
## - A HEAP OF COINS NEVER SHARES SPACE (feedback 0008, coins in a dish cut through each other): fourteen
##   coins heaped on seven seeds lie flat, and no two discs overlap in plan and in height. Two-sided: two
##   coins laid on the same spot are found overlapping.
## - THE SET DRESSER IS TOLD all of it.

var _fails: Array = []
const PAL := ["#8a6a3a", "#c9b38a", "#3a3030"]


func _initialize() -> void:
	_flat_ends()
	_corners()
	_elbow()
	_kink()
	_loft_closed()
	_loft_sections()
	_bend()
	_warp_normals()
	_wobble()
	_junk()
	_strands()
	_draped()
	_bones()
	_sculpts()
	_coins()
	_told()
	if _fails.is_empty():
		print("props_check: ALL OK")
		quit(0)
		return
	print("props_check: %d FAILURE(S)" % _fails.size())
	for f in _fails:
		print("  FAIL: " + String(f))
	quit(1)


func _ok(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)


## One part, made safe as a thing's only part.
func _part(p: Dictionary) -> Dictionary:
	var safe := Props.sanitize({"things": [{"name": "t", "parts": [p]}]}, PAL)
	var things: Array = safe["things"]
	return (things[0] as Dictionary)["parts"][0] if not things.is_empty() else {}


func _geo(p: Dictionary, seed := 1) -> Props.Tris:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var geos := Props._geometry(_part(p), rng)
	return (geos[0] as Dictionary)["geo"]


## How many edges of [param g] have a face on one side only (an odd count of faces): 0 is closed.
func _open_edges(g: Props.Tris, skip := -1) -> int:
	var count := {}
	var key := func(v: Vector3) -> String:
		return "%d,%d,%d" % [roundi(v.x * 1e6), roundi(v.y * 1e6), roundi(v.z * 1e6)]
	for t in range(0, g.v.size(), 3):
		if t / 3 == skip:
			continue
		for e in 3:
			var a: String = key.call(g.v[t + e])
			var b: String = key.call(g.v[t + (e + 1) % 3])
			if a == b:
				continue
			var k := a + "|" + b if a < b else b + "|" + a
			count[k] = int(count.get(k, 0)) + 1
	var odd := 0
	for k in count:
		odd += int(count[k]) % 2
	return odd


func _flat_ends() -> void:
	# a set dresser's purple clay teapot, its body as written (episode 882)
	var prof := [[0.0, 0.0], [4.0, 0.0], [5.6, 2.0], [6.0, 4.0], [5.2, 6.4], [3.0, 7.3], [0.0, 7.3]]
	var g := _geo({"shape": "lathe", "smooth": true, "profile": prof})
	var lo := INF
	var hi := -INF
	for v in g.v:
		lo = minf(lo, v.y)
		hi = maxf(hi, v.y)
	_ok(lo > -0.00001 and hi < 0.073 + 0.00001, "a smooth teapot's flat base or top is not flat: from %.5f to %.5f m (0 to 0.073)" % [lo, hi])
	# the control: curved through with no corners kept, it sags and domes
	var pts: Array = []
	for q in prof:
		pts.append(Vector2(q[0], q[1]) * 0.01)
	var c: Array = Props._curve(pts, PackedFloat32Array(), true, 6)["pts"]
	var clo := INF
	var chi := -INF
	for q in c:
		clo = minf(clo, (q as Vector2).y)
		chi = maxf(chi, (q as Vector2).y)
	_ok(clo < -0.0003 and chi > 0.0733, "the control did not sag or dome (%.5f to %.5f): the flat-end check proves nothing" % [clo, chi])


func _corners() -> void:
	var pts: Array = [Vector2(0, 0), Vector2(0.03, 0), Vector2(0.04, 0.03), Vector2(0.02, 0.05), Vector2(0, 0.06)]
	var with := Props._curve(pts, PackedFloat32Array([-1, -1, 0, -1, -1]), true, 6)
	var without := Props._curve(pts, PackedFloat32Array([-1, -1, -1, -1, -1]), true, 6)
	var at := func(c: Dictionary) -> int:
		var ps: Array = c["pts"]
		for i in ps.size():
			if (ps[i] as Vector2).distance_to(Vector2(0.04, 0.03)) < 1e-7:
				return int((c["corner"] as PackedByteArray)[i])
		return -1
	_ok(at.call(with) == 1, "a point written [r, h, 0] is not a corner of the smooth curve")
	_ok(at.call(without) == 0, "the same point written without its 0 is a corner (or missing): the corner check proves nothing")
	# and read from what an agent writes
	var p := _part({"shape": "lathe", "smooth": true, "profile": [[0, 0], [3, 0], [4, 3, 0], [2, 5, 1.5], [0, 6]]})
	_ok(Array(p["rounds"]) == [-1.0, -1.0, 0.0, 1.5, -1.0], "a profile's roundings were not read as written: %s" % str(p["rounds"]))


func _elbow() -> void:
	var near := func(p: Dictionary) -> float:
		var c := Props._curve([Vector3(0, 0, 0), Vector3(0.05, 0, 0), Vector3(0.05, 0.05, 0)], Props._rounds_m(p, 3), false)
		var d := INF
		for q in c["pts"]:
			d = minf(d, (q as Vector3).distance_to(Vector3(0.05, 0, 0)))
		return d
	var rounded: float = near.call(_part({"shape": "tube", "path": [[0, 0, 0], [5, 0, 0, 2], [5, 5, 0]], "smooth": false}))
	var square: float = near.call(_part({"shape": "tube", "path": [[0, 0, 0], [5, 0, 0], [5, 5, 0]], "smooth": false}))
	# a quarter turn rounded 2 cm passes about 0.7-0.8 cm inside its corner
	_ok(rounded > 0.005 and rounded < 0.01, "a 2 cm elbow passes %.4f m from its corner (about 0.007)" % rounded)
	_ok(square < 1e-6, "an unrounded corner is not passed through (%.4f m): the elbow check proves nothing" % square)


## The distance from [param q] to the nearest of the path's segments, each carried 2 cm on past its
## ends: a mitered joint's outer corner lies on both rods' surfaces, past where either segment ends.
func _to_path(q: Vector3, path: Array) -> float:
	var d := INF
	for i in path.size() - 1:
		var a: Vector3 = path[i]
		var b: Vector3 = path[i + 1]
		var along := (b - a).normalized() * 0.02
		d = minf(d, q.distance_to(Geometry3D.get_closest_point_to_segment(q, a - along, b + along)))
	return d


func _kink() -> void:
	var path := [Vector3(0, 0.01, 0), Vector3(0.06, 0.01, 0), Vector3(0.06, 0.07, 0)]
	var g := _geo({"shape": "tube", "radius": 1, "smooth": false, "path": [[0, 1, 0], [6, 1, 0], [6, 7, 0]]})
	var worst := 0.0
	for v in g.v:
		# the rod's ends are closed by caps across it: only its wall is a radius out
		if v.x < 0.0005 or v.y > 0.0695:
			continue
		worst = maxf(worst, absf(_to_path(v, path) - 0.01))
	_ok(worst < 0.0003, "a rod bent square is pinched or swollen at its bend: a point lies %.4f m off its radius" % worst)
	# the control: a ring square to the bend's middle, not stretched - the old rod's corner, whose
	# inside pinched to 0.71 of its radius
	var inside := Vector3(0.06, 0.01, 0) + Vector3(-1, 1, 0).normalized() * 0.01
	_ok(absf(_to_path(inside, path) - 0.01) > 0.002, "an unstretched ring at the bend lies a radius from the path: the kink check proves nothing")


func _loft_closed() -> void:
	var solid := _geo({"shape": "loft", "path": [[0, 0, 0], [2, 5, 0], [6, 8, 1]], "sections": [
		{"at": 0, "size": 3}, {"at": 0.5, "outline": "star", "sides": 5, "size": [3, 2], "turn": 40}, {"at": 1, "outline": "rect", "size": [1, 2]}]})
	var hollow := _geo({"shape": "loft", "wall": 0.3, "path": [[0, 0, 0], [3, 3, 0], [5, 7, 0]], "sections": [{"size": 3}, {"size": 1.4}]})
	_ok(not solid.v.is_empty() and _open_edges(solid) == 0, "a solid loft is not closed: %d open edges" % _open_edges(solid))
	_ok(not hollow.v.is_empty() and _open_edges(hollow) == 0, "a hollow loft is not closed: %d open edges" % _open_edges(hollow))
	_ok(_open_edges(solid, 7) > 0, "the same loft less one triangle reads as closed: the closed check proves nothing")
	var coil := _geo({"shape": "coil", "turns": 3, "radius": 1, "radius2": 4, "thickness": 0.3})
	_ok(_open_edges(coil) == 0, "a coil is not closed: %d open edges" % _open_edges(coil))
	var lo := INF
	for v in coil.v:
		lo = minf(lo, v.y)
	_ok(absf(lo) < 0.0001, "a flat coil does not lie on the cloth (its lowest point at %.5f)" % lo)


func _loft_sections() -> void:
	var make := func(turn: float) -> Props.Tris:
		return _geo({"shape": "loft", "height": 10, "sections": [{"at": 0, "size": 4}, {"at": 1, "outline": "rect", "size": [2, 1], "turn": turn}]})
	var g: Props.Tris = make.call(90.0)
	var foot := 0.0
	var top := Vector2.ZERO
	for v in g.v:
		if v.y < 0.00001:
			foot = maxf(foot, absf(Vector2(v.x, v.z).length() - 0.02) if Vector2(v.x, v.z).length() > 0.001 else 0.0)
		if v.y > 0.1 - 0.00001:
			top = top.max(Vector2(absf(v.x), absf(v.z)))
	_ok(foot < 0.0003, "a loft's round foot is not round: a point %.5f m off its radius" % foot)
	_ok(absf(top.x - 0.005) < 0.0003 and absf(top.y - 0.01) < 0.0003, "a loft's top is not its rectangle turned 90: reaches %s m" % str(top))
	var g0: Props.Tris = make.call(0.0)
	var top0 := Vector2.ZERO
	for v in g0.v:
		if v.y > 0.1 - 0.00001:
			top0 = top0.max(Vector2(absf(v.x), absf(v.z)))
	_ok(absf(top0.x - 0.005) > 0.002, "the unturned top reads as turned: the section check proves nothing")


## The middle, across, of what a part's geometry has at height [param y] (within [param tol]).
func _slice_mid(g: Props.Tris, y: float, tol: float) -> Variant:
	var sum := Vector3.ZERO
	var n := 0
	for v in g.v:
		if absf(v.y - y) < tol:
			sum += v
			n += 1
	return sum / float(n) if n > 0 else null


func _bend() -> void:
	var g := _geo({"shape": "box", "size": [2, 20, 2], "round": 0.2, "warp": {"bend": 90}})
	var R := 0.2 / (PI * 0.5)
	_ok(g.top.distance_to(Vector3(R, R, 0)) < 0.003, "a block bent 90 does not come round to its side: its top at %s (about %s)" % [str(g.top), str(Vector3(R, R, 0))])
	# halfway round the curve the middle is at 30 degrees: x = R (1 - cos 30)
	var want := R * (1.0 - cos(PI / 6.0))
	var mid: Variant = _slice_mid(g, R * 0.5, 0.002)
	_ok(mid != null and absf((mid as Vector3).x - want) < 0.004, "a bent block is not on its curve halfway up: %s (x about %.4f)" % [str(mid), want])
	var front := _geo({"shape": "box", "size": [2, 20, 2], "warp": {"bend": 90, "bend_to": 90}})
	_ok(front.top.distance_to(Vector3(0, R, R)) < 0.003, "a block bent toward its front went to %s" % str(front.top))
	# the control: built coarse and then warped, it has nothing halfway up to bend
	var coarse := _part({"shape": "box", "size": [2, 20, 2], "round": 0.2})
	var rng := RandomNumberGenerator.new()
	var geos := Props._geometry(coarse, rng)
	Props._warp(geos, {"bend": 90.0}, 1)
	var cmid: Variant = _slice_mid((geos[0] as Dictionary)["geo"], R * 0.5, 0.002)
	_ok(cmid == null or absf((cmid as Vector3).x - want) > 0.004, "a coarse block bends as well as a fine one: the bend check proves nothing")


func _warp_normals() -> void:
	var g := _geo({"shape": "ball", "size": [4, 4, 4], "warp": {"scale": [2, 1, 1]}})
	var plain := _geo({"shape": "ball", "size": [4, 4, 4]})
	var axes := Vector3(0.04, 0.02, 0.02)
	var worst := 0.0
	var worst_plain := 0.0
	for i in g.v.size():
		var q := g.v[i] - Vector3(0, 0.02, 0)
		var want := Vector3(q.x / (axes.x * axes.x), q.y / (axes.y * axes.y), q.z / (axes.z * axes.z)).normalized()
		worst = maxf(worst, rad_to_deg(g.n[i].angle_to(want)))
		worst_plain = maxf(worst_plain, rad_to_deg(plain.n[i].angle_to(want)))
	_ok(worst < 6.0, "a ball stretched to an ellipsoid shades %.1f degrees off the ellipsoid" % worst)
	_ok(worst_plain > 15.0, "the unwarped normals agree with the ellipsoid (%.1f degrees): the normal check proves nothing" % worst_plain)


func _wobble() -> void:
	var pot := {"shape": "lathe", "profile": [[0, 0], [3, 0], [4, 5], [3.5, 9], [3.2, 9], [3.6, 5], [2.6, 0.5], [0, 0.5]], "warp": {"wobble": 0.6}}
	var a := _geo(pot, 5)
	var b := _geo(pot, 5)
	_ok(a.v == b.v, "the same seed wobbled a pot two ways")
	var flat := _geo({"shape": "lathe", "profile": pot["profile"]}, 5)
	_ok(_unround(a) > 0.001 and _unround(flat) < 0.0001, "a wobble of 0.6 left the pot as round as a turned one (%.4f m against %.4f)"
		% [_unround(a), _unround(flat)])
	_ok(_open_edges(flat) == 0, "the pot is not closed before it is wobbled: %d open edges" % _open_edges(flat))
	_ok(_open_edges(a) == 0, "a wobble opened %d edges of the pot" % _open_edges(a))
	# the control: pushed out along its normals, its crisp rim and foot split
	var split := Props.Tris.new()
	for i in flat.v.size():
		split.v.append(flat.v[i] + flat.n[i] * 0.001)
	_ok(_open_edges(split) > 0, "pushing a pot out along its normals keeps it closed: the seam check proves nothing")


## How far from a turned thing [param g] is: the most its outer wall's distance from the axis varies
## at one height (2 mm bands).
func _unround(g: Props.Tris) -> float:
	var bands := {}
	for v in g.v:
		var r := Vector2(v.x, v.z).length()
		if r < 0.037:
			continue
		var k := roundi(v.y / 0.002)
		var span: Vector2 = bands.get(k, Vector2(INF, -INF))
		bands[k] = Vector2(minf(span.x, r), maxf(span.y, r))
	var most := 0.0
	for k in bands:
		most = maxf(most, (bands[k] as Vector2).y - (bands[k] as Vector2).x)
	return most


func _junk() -> void:
	var p := _part({"shape": "loft", "path": [[0, 0]], "sections": ["wide", 3, {"outline": "spiral", "size": [-4, 900], "at": 7, "turn": "x"}, {}],
		"warp": {"bend": 9000, "scale": [0, 99, "x"], "wobble": -1, "frobnicate": 3, "lean": [1, "z"]}})
	_ok(not p.is_empty(), "a loft of junk was dropped")
	var secs: Array = p["sections"]
	_ok(secs.size() == 3, "a loft kept %d sections of 4 written (one was not a section)" % secs.size())
	var ok_secs := true
	var last := -1.0
	for sd in secs:
		var d: Dictionary = sd
		ok_secs = ok_secs and Props.EXTRUDE_OUTLINES.has(String(d["outline"])) and float(d["at"]) >= last and float(d["at"]) <= 1.0 \
			and (d["size"] as Vector2).x >= 0.0 and (d["size"] as Vector2).y <= Props.MAX_SIZE
		last = float(d["at"])
	_ok(ok_secs, "a loft's junk sections were kept as written: %s" % str(secs))
	var w: Dictionary = p["warp"]
	_ok(float(w.get("bend", 0)) == 270.0 and not w.has("wobble") and not w.has("frobnicate") and not w.has("lean")
		and (w["scale"] as Vector3) == Vector3(0.1, 4.0, 1.0), "a junk warp was kept as written: %s" % str(w))
	var g := _geo({"shape": "loft", "path": [[0, 0]], "sections": ["wide", {"size": 0}], "warp": {"wobble": 2, "twist": 90}})
	var bad := 0
	for i in g.v.size():
		bad += 0 if g.v[i].is_finite() and g.n[i].is_finite() and absf(g.n[i].length() - 1.0) < 0.01 else 1
	_ok(not g.v.is_empty() and bad == 0, "a junk loft built %d bad points or normals" % bad)


## The closest two points of [param line] come that lie further than [param apart] from each other along it.
func _closest_apart(line: PackedVector3Array, apart: float) -> float:
	var along := PackedFloat32Array([0.0])
	for i in range(1, line.size()):
		along.append(along[i - 1] + line[i].distance_to(line[i - 1]))
	var best := INF
	for i in line.size():
		for j in range(i + 1, line.size()):
			if along[j] - along[i] > apart:
				best = minf(best, line[i].distance_to(line[j]))
	return best


func _strands() -> void:
	for lay in ["coil", "heap", "flemish"]:
		for kind in ["rope", "cord", "wire"]:
			var p := _part({"shape": "strand", "kind": kind, "lay": lay, "length": 160, "thickness": 1.0, "loose": 0.6})
			var rng := RandomNumberGenerator.new()
			rng.seed = 11
			var line := Props.strand_line(p, rng)
			var t := float(p["thickness"]) * 0.01
			var low := INF
			var step := 0.0
			for i in line.size():
				low = minf(low, line[i].y)
				if i > 0:
					step = maxf(step, absf(line[i].y - line[i - 1].y))
			_ok(_closest_apart(line, t * 2.0) >= t * 0.9, "a %s %s passes through itself (%.2f of its width)" % [lay, kind, _closest_apart(line, t * 2.0) / t])
			_ok(low >= t * 0.5 - 1e-5, "a %s %s lies below the cloth" % [lay, kind])
			_ok(step <= t * 0.5, "a %s %s jumps up a step of %.1f mm" % [lay, kind, step * 1000.0])
	# TWO-SIDED: the same tangle on the cloth throughout passes through itself
	var p := _part({"shape": "strand", "kind": "cord", "lay": "heap", "length": 160, "thickness": 1.0, "loose": 0.6})
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var flat := Props._strand_flat(p, rng)
	var flat3 := PackedVector3Array()
	for q in flat:
		flat3.append(Vector3(q.x, 0.005, q.y))
	_ok(_closest_apart(flat3, 0.02) < 0.009, "control: a tangle laid flat does not cross itself, so the measure sees nothing")
	# every kind builds, and what it builds stands on the cloth
	for kind in Props.STRANDS:
		var b := Props.build(Props.sanitize({"things": [{"name": "s", "parts": [{"shape": "strand", "kind": kind, "lay": "coil", "length": 80}]}]}, PAL)["things"][0], {}, 3)
		_ok(not (b["meshes"] as Array).is_empty() and absf((b["size"] as AABB).position.y) < 1e-4, "a %s strand did not build on the cloth" % kind)
		(b["node"] as Node).free()


func _draped() -> void:
	# a round top 1 m across: the path runs 30 cm past its right edge
	var o := Tables.top_outline({"shape": "round", "size": [100.0, 100.0]})
	var ground := {"sdf": func(q: Vector2) -> float: return Tables.sdf(o, q), "normal": func(q: Vector2) -> Vector2: return Tables.normal(o, q),
		"origin": Tables.ORIGIN, "drop": Tables.DROP_MOST}
	var c: Vector2 = o["center"]
	var from := (c - Tables.ORIGIN) * 100.0
	var p := _part({"shape": "strand", "kind": "rope", "lay": "drape", "path": [[from.x - 20.0, from.y], [from.x + 80.0, from.y]], "thickness": 1.0, "loose": 0.0})
	p["ground"] = ground
	var line := Props.strand_line(p, RandomNumberGenerator.new())
	var lowest := INF
	var inside_low := INF
	for q in line:
		lowest = minf(lowest, q.y)
		if Tables.sdf(o, Vector2(q.x, q.z)) < -0.001:
			inside_low = minf(inside_low, q.y)
	_ok(lowest < -0.2 and lowest > -0.32, "a strand run 30 cm past the edge hangs %.0f cm down, not about 30 - the bend round the edge taken" % (-lowest * 100.0))
	_ok(inside_low > 0.0, "a draped strand goes into the table (%.1f mm under its top)" % (-inside_low * 1000.0))
	var long := _part({"shape": "strand", "kind": "rope", "lay": "drape", "path": [[from.x, from.y], [from.x + 200.0, from.y]], "thickness": 1.0, "loose": 0.0})
	long["ground"] = ground
	var floor_low := INF
	for q in Props.strand_line(long, RandomNumberGenerator.new()):
		floor_low = minf(floor_low, q.y)
	_ok(floor_low >= -Tables.DROP_MOST, "a long draped strand hangs through the floor")
	# control: with no ground it lies on the cloth
	p.erase("ground")
	var flat_low := INF
	for q in Props.strand_line(p, RandomNumberGenerator.new()):
		flat_low = minf(flat_low, q.y)
	_ok(flat_low > 0.0, "control: a drape with no table under it does not lie flat")
	var thing: Dictionary = Props.sanitize({"things": [{"name": "d", "parts": [{"shape": "box"}, {"shape": "strand", "lay": "drape", "path": [[0, 0], [10, 0]]}]}]}, PAL)["things"][0]
	_ok(Props.draped(thing) and (thing["parts"] as Array).size() == 1, "a draped thing kept parts beside its strand")


func _bones() -> void:
	for kind in Props.BONES:
		var g := _geo({"shape": "bone", "kind": kind, "length": 20})
		var box := AABB(g.v[0], Vector3.ZERO)
		for q in g.v:
			box = box.expand(q)
		_ok(absf(box.position.y) < 1e-4, "a %s bone does not rest on the cloth" % kind)
		_ok(maxf(box.size.x, box.size.z) > 0.15 and maxf(box.size.x, box.size.z) < 0.3, "a %s bone of 20 cm is %.0f cm long" % [kind, maxf(box.size.x, box.size.z) * 100.0])
	for kind in Props.SKULLS:
		var rng := RandomNumberGenerator.new()
		var geos := Props._geometry(_part({"shape": "skull", "kind": kind, "length": 18}), rng)
		var g: Props.Tris = (geos[0] as Dictionary)["geo"]
		var box := AABB(g.v[0], Vector3.ZERO)
		for q in g.v:
			box = box.expand(q)
		_ok(absf(box.position.y) < 1e-4, "a %s skull does not rest on the cloth" % kind)
		_ok(box.size.z > 0.12 and box.size.z < 0.26, "a %s skull of 18 cm is %.0f cm front to back" % [kind, box.size.z * 100.0])
		_ok(_open_edges(g) == 0 or kind == "horned", "a %s skull is not closed: %d open edges" % [kind, _open_edges(g)])
	# a bird's orbits, open through the thin wall between them; its braincase is not
	var f := Props._field_of(Props._strokes(Props.SKULL_FORMS["bird"]), true)
	var near := Props._near(f, AABB(Vector3(-4, -1, -5), Vector3(8, 6, 13)))
	var orbit := PackedVector3Array()
	var brain := PackedVector3Array()
	for i in 61:
		var x := -3.0 + 0.1 * float(i)
		orbit.append(Vector3(x, 1.9, 0.3))
		brain.append(Vector3(x, 2.0, -1.9))
	var through := true
	for d in Props._sample(f, near, orbit):
		through = through and d > 0.0
	var solid := false
	for d in Props._sample(f, near, brain):
		solid = solid or d < 0.0
	_ok(through, "a bird skull's orbits are not open through it")
	_ok(solid, "control: a line through a bird's braincase meets no bone")


func _sculpts() -> void:
	var ball := {"points": [[0, 3, 0]], "size": [6, 6, 6]}
	var bore := {"points": [[0, 3, -5, 1.0], [0, 3, 5, 1.0]], "carve": true}
	var carved := _geo({"shape": "sculpt", "strokes": [ball, bore]})
	var whole := _geo({"shape": "sculpt", "strokes": [ball]})
	_ok(not carved.v.is_empty() and _open_edges(carved) == 0, "a carved sculpt is not closed: %d open edges" % _open_edges(carved))
	_ok(not whole.v.is_empty() and _open_edges(whole) == 0, "a sculpted ball is not closed: %d open edges" % _open_edges(whole))
	_ok(_hits(carved, Vector3(0.0013, 0.0307, -0.1), Vector3(0, 0, 1)) == 0, "a carve does not go through: a line down the bore meets %d faces" % _hits(carved, Vector3(0.0013, 0.0307, -0.1), Vector3(0, 0, 1)))
	_ok(_hits(whole, Vector3(0.0013, 0.0307, -0.1), Vector3(0, 0, 1)) > 0, "control: the uncarved ball is open through its middle")
	# mirrored
	var arm := {"points": [[0, 2, 0, 1.0], [4, 2, 0, 0.6]]}
	var both := _geo({"shape": "sculpt", "mirror": true, "strokes": [arm]})
	var one := _geo({"shape": "sculpt", "strokes": [arm]})
	var bb := Props._bounds_of(both)
	var ob := Props._bounds_of(one)
	_ok(absf(bb.position.x + bb.end.x) < 0.002 and bb.size.x > 0.08, "a mirrored stroke is not on both sides: x %.3f..%.3f" % [bb.position.x, bb.end.x])
	_ok(ob.position.x > -0.015, "control: an unmirrored stroke on the right reaches the left")
	# a well carved into a ball is darker inside than out; a ball is open all round
	var cup := _geo({"shape": "sculpt", "strokes": [{"points": [[0, 3, 0]], "size": [6, 6, 6]}, {"points": [[0, 7, 0, 1.2], [0, 1.5, 0, 1.2]], "carve": true}]})
	var inside := []
	var outside := []
	for i in cup.v.size():
		var p := cup.v[i] * 100.0
		if Vector2(p.x, p.z).length() < 1.3 and p.y > 1.0 and p.y < 4.5:
			inside.append(cup.uv2[i].y)
		elif p.y < 2.0:
			outside.append(cup.uv2[i].y)
	_ok(not inside.is_empty() and _mean(inside) > _mean(outside) + 0.3, "a cup's inside is not shut in: %.2f inside, %.2f out" % [_mean(inside), _mean(outside)])
	var open := []
	for s in whole.uv2:
		open.append(s.y)
	_ok(_mean(open) < 0.05, "a ball's outside reads as a hollow: %.2f" % _mean(open))
	# a stroke too fine for its sculpt is found
	var fine := Props.sculpt_cut({"strokes": Props._strokes([{"points": [[0, 0, 0]], "size": [40, 10, 10]}, {"points": [[0, 6, 0, 0.04], [5, 6, 0, 0.04]]}])})
	_ok(float(fine["thin"][1]) < float(fine["cell"]) * 0.6, "a hair-thin rod on a 40 cm sculpt is not found too fine (cell %.2f cm)" % float(fine["cell"]))
	_ok(float(fine["thin"][0]) > float(fine["cell"]) * 0.6, "control: the 10 cm body itself is found too fine")
	_ok(Props._sanitize_part({"shape": "sculpt", "strokes": [{"points": "x"}]}, {}, PAL).is_empty(), "a sculpt with no stroke is kept")


## How many faces of [param g] a line from [param from] along [param dir] meets - in centimeters: Godot's test
## takes a triangle under a millimeter for one lying along the line.
## Whether any two of the coins [param laid] (transforms: a unit-thickness-scaled disc of half-width
## [param a], half-thickness [param b]) share space: overlapping in plan, and in height.
func _coins_touch(laid: Array, a: float, b: float) -> bool:
	for i in laid.size():
		for j in range(i + 1, laid.size()):
			var ti: Transform3D = laid[i]
			var tj: Transform3D = laid[j]
			var ri := a * ti.basis.get_scale().x
			var rj := a * tj.basis.get_scale().x
			var hi := b * ti.basis.get_scale().y
			var hj := b * tj.basis.get_scale().y
			var d := ti.origin - tj.origin
			if Vector2(d.x, d.z).length() < (ri + rj) * 0.97 and absf(d.y) < (hi + hj) * 0.97:
				return true
	return false


func _coins() -> void:
	var a := 0.012
	var b := 0.001
	var bounds := {"reach": a, "girth": a, "low": -b, "high": b}
	for seed in 7:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed + 1
		var laid := Props._strewn(true, 14, 1.0, 0.03, Transform3D.IDENTITY, Vector3.ZERO, bounds, rng)
		_ok(laid.size() == 14, "seed %d: all fourteen coins are laid" % seed)
		_ok(not _coins_touch(laid, a, b), "seed %d: two coins in a heap share space" % seed)
		for t in laid:
			_ok((t as Transform3D).basis.y.normalized().dot(Vector3.UP) > 0.9999, "seed %d: a coin lies flat" % seed)
	var same := [Transform3D(Basis(), Vector3(0, b, 0)), Transform3D(Basis(), Vector3(0.005, b, 0))]
	_ok(_coins_touch(same, a, b), "the control: two coins on one spot are found overlapping")


func _hits(g: Props.Tris, from: Vector3, dir: Vector3) -> int:
	var n := 0
	for t in range(0, g.v.size(), 3):
		if Geometry3D.ray_intersects_triangle(from * 100.0, dir, g.v[t] * 100.0, g.v[t + 1] * 100.0, g.v[t + 2] * 100.0) != null:
			n += 1
	return n


func _mean(a: Array) -> float:
	var s := 0.0
	for x in a:
		s += float(x)
	return s / maxf(float(a.size()), 1.0)


func _told() -> void:
	var words := Props.describe()
	for k in ["- strand:", "- bone:", "- skull:", "- sculpt:", "`carve`", "`mirror`", "DRAPED:", "- loft:", "- coil:", "WARP:", "\"bend\"", "\"wobble\"", "[x, y, z, r]", "[radius, height, 0]", "WHERE PARTS MEET:", "lens", "drop"]:
		_ok(words.contains(k), "the set dresser is not told %s" % k)
