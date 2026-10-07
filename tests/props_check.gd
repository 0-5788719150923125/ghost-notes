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


func _told() -> void:
	var words := Props.describe()
	for k in ["- loft:", "- coil:", "WARP:", "\"bend\"", "\"wobble\"", "[x, y, z, r]", "[radius, height, 0]", "WHERE PARTS MEET:", "lens", "drop"]:
		_ok(words.contains(k), "the set dresser is not told %s" % k)
