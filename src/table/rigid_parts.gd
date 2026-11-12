extends RefCounted
class_name RigidParts

## RigidParts: what the work picks up, as rigid bodies (next/table_physics.md, "Tools"). Every free part that is not loose - a pestle, a
## ladle, a jar and its cork, a lid - and every thing that may be moved whole is a body with a mass, a middle and an inertia ([method
## TablePhysics._mass_of]), stepped by the bake ([TablePhysics]) on its own thread. It is a body whatever the acts are (next/framework_audit.md):
## being a body must not depend on whether some act moves it, or the world would change with every act and nothing baked before could be
## kept. And it is dormant as built: untouched, a body is the solid it was before it was one - reckoned no further, met as a solid, woken
## by nothing but a hand taking it up or what holds it moving ([method _stirred]); woken by whatever came near, a table of bodies set as
## the set dresser left them would wake one another and never settle.
##
##   - Held, it goes where the hand takes it and meets what it is moved into: kept out of every other solid and the table's top, pushed
##     back along what it meets and turned about it as a grip gives a little (Muller, Macklin, Chentanez, Jeschke and Kim, "Detailed Rigid
##     Body Simulation with Extended Position Based Dynamics", 2020: each contact a positional correction weighed by the body's
##     generalized inverse mass at it, friction a correction of its slide);
##   - Let go, it falls and comes to rest: gravity, the same contacts, friction against what it lies on; still, it sleeps on that and goes
##     where that goes - a pestle in its mortar carried to the middle - until it is taken up, its holder tips or jolts, or something moving
##     comes to it.
##
## A body is met as points on its surface ([method ShapeField.surface_points]) against every other solid's field, and every other solid's
## points against its own fields - so a jar's thin rim never slips between a cork's points. A move is taken in pieces no longer than
## [constant STEP_MOST] at any point of it: never over a glass wall in one step. Pure data: no node, nothing but numbers.

## Substeps a frame; the most points a body's surface is met by; how far into what it touches a body may stand
## (meters) - and how far a move goes at most between looks (meters), in at most this many pieces a substep.
const SUBSTEPS := 2
const POINTS := 120
const OTHER_POINTS := 200
const SLACK := 0.0003
## A point kept by the face it came into a still wall by ([method _contacts]) lets it go this far clear of the wall (meters).
const FACE_FAR := 0.004
## ...and, out of the wall, this far from where it came in (meters): past it, it went round the wall, never through it.
const FACE_REACH := 0.008
const STEP_MOST := 0.0012
const PIECES_MOST := 8
## Held, how much faster than the hand a body goes back into it (meters a second): one held back by what it met comes back as a grip
## settles - and is pressed into what holds it back no harder than the hand presses.
const CATCH_UP := 0.06
## ...and, clear of everything by CATCH_CLEAR (meters) or by more than it lags, this fast (meters a second).
const CATCH_UP_CLEAR := 0.5
const CATCH_CLEAR := 0.02
## Passes over its contacts a piece of a move: each finds them afresh.
const PASSES := 2
## How much of the speed it met something with a body keeps going back off it: a pushed-out body flies off only as fast as it came in
## times this (positional pushes alone spin a landing rod up).
const BOUNCE := 0.15
## Held firm: a held body turns about what it meets this share as freely as a loose one does - a hand holds it.
const GRIP := 0.2
## Gravity; the fastest a body goes (meters a second); a loose body's turning dies this share a second.
const GRAVITY := Vector3(0.0, -9.81, 0.0)
const V_MOST := 3.0
const SPIN_DAMP := 0.6
## At rest: touching something and slower than SETTLE at any point (meters a second), it loses SETTLE_LOSS of its speed a substep -
## positional contacts leave a resting body trembling, never still enough to sleep (as [constant Particles.SETTLE]). Sleep: slower than
## this at any point of it over a frame (meters a second) for this long (seconds), touching something - or, touching something, none of
## it further than SLEEP_DRIFT (meters) from where it was this long ago: trembling in place is at rest. Waking: its holder tipped this far
## since (radians) or jolted this hard (meters a second, squared), or a moving solid this near (meters).
const SETTLE := 0.05
const SETTLE_LOSS := 0.5
const SLEEP_SPEED := 0.01
const SLEEP_DRIFT := 0.0005
const SLEEP_AFTER := 0.3
const WAKE_TILT := 0.12
const WAKE_JOLT := 4.0
const WAKE_NEAR := 0.003
## The table's top's own friction, static and kinetic ([constant Particles.TABLE_FRICTION]).
const TABLE_MU := Vector2(0.5, 0.4)
## What a body rests on with no solid under it: the table's top.
const TABLE := -2
## ...and on loose things: a sphere of [Particles] under it, holding it up as a solid would - let go only, and only where
## the sphere's push on it points this much up (a jar is never pushed off its own contents). Any contact holds a body up, and
## is what it sleeps on and rides, only past [constant HELD_UP].
const LOOSE := -3
const HELD_UP := 0.3
## A part in its seat is welded to it ([method TablePhysics._weld]): eased onto it over WELD_EASE seconds, then it goes exactly where its
## seat goes and is woken by nothing but a hand (the solver's points are coarser than a neck's fit, so a cork would tremble in its jar).
const WELD_EASE := 0.25
## A hand lets go gently ([method guide]): for GUIDE seconds after a hand lets go, or until it rests, a body goes no faster than GUIDE_V
## at any point (meters a second) - it is lowered onto what takes it, as a hand sets a thing down, never dropped.
const GUIDE := 2.5
const GUIDE_V := 0.12
## SUPPORTED ([method supported]): a point of its surface this near (meters) what is under it, there facing up at least
## HELD_UP, holds it up - and only if its middle stands over the points that do, within SUPPORT_GROW (meters).
const SUPPORT_NEAR := 0.003
const SUPPORT_GROW := 0.006

## Each body: `{wi, solids (its own), rests (each one's pose as built), m, ii (its inverse inertia as built, the table's
## space), c0 (its middle as built), pts (its surface as built), rad (from its middle to its furthest point), mu, c, q,
## v, w, held (where the hand has it: a motion from as built, or null), held_from, asleep, still, host, hrel, hup, touch,
## moved}` - a pose is the rigid motion from where it was built ([method motion]).
var bodies: Array = []
var _solids: Array = []
var _top := 0.0
var _spheres := {}            # the loose things' spheres this frame: {x, r, alive, n} ([Particles]'s own arrays, read only)


## A BODY of work [param wi], its solids [param solids] (each one's pose as built in [param rests]), [param m] kilograms,
## its inertia about its middle [param inertia] (the table's space, as built), its middle [param c0], its surface [param pts]
## (the table's space, as built), its surface's friction [param mu] - asleep on [param host] ([param host_xf] its pose). Its
## number.
func add(wi: int, solids: PackedInt32Array, rests: Array, m: float, inertia: Basis, c0: Vector3, pts: PackedVector3Array,
		mu: Vector2, host: int, host_xf: Transform3D) -> int:
	var rad := 0.0
	for p in pts:
		rad = maxf(rad, p.distance_to(c0))
	# Its surface, spread evenly: [constant POINTS] of them, each the furthest from those taken before - its corners and edges first
	# (every k-th point of the surface's own grid leaves a box's edges out, and the body rests on one, sunk into the table)
	var det := inertia.determinant()
	var ii := inertia.inverse() if absf(det) > 1e-30 else Basis.from_scale(Vector3.ONE * (1.0 / maxf(m * rad * rad * 0.4, 1e-12)))
	# ...and how far apart the points it is met by lie: a rim as thin as that may pass between them unseen
	var lo := c0
	var hi := c0
	for p in pts:
		lo = Vector3(minf(lo.x, p.x), minf(lo.y, p.y), minf(lo.z, p.z))
		hi = Vector3(maxf(hi.x, p.x), maxf(hi.y, p.y), maxf(hi.z, p.z))
	var gap := 0.001
	if pts.size() > POINTS:
		var far := PackedFloat32Array()
		far.resize(pts.size())
		far.fill(INF)
		var even := PackedVector3Array()
		var at := 0
		for k in pts.size():
			if pts[k].distance_squared_to(c0) > pts[at].distance_squared_to(c0):
				at = k
		for n_taken in POINTS:
			even.append(pts[at])
			var next := 0
			var most := -1.0
			for k in pts.size():
				far[k] = minf(far[k], pts[k].distance_squared_to(pts[at]))
				if far[k] > most:
					most = far[k]
					next = k
			gap = sqrt(maxf(most, 0.0))
			at = next
		pts = even
	bodies.append({"bi": bodies.size(), "wi": wi, "solids": solids, "rests": rests, "m": maxf(m, 1e-6), "ii": ii, "c0": c0, "pts": pts, "rad": rad, "mu": mu,
		"gap": gap, "clear": 0.0, "clear_from": Transform3D.IDENTITY, "stir": 0.0, "was_moved": true, "faces": {}, "hits": [],
		"c": c0, "q": Quaternion.IDENTITY, "v": Vector3.ZERO, "w": Vector3.ZERO, "held": null, "held_from": null, "asleep": true,
		"still": 0.0, "anchor": Transform3D.IDENTITY, "host": host, "hrel": host_xf.affine_inverse() if host >= 0 else Transform3D.IDENTITY,
		"hup": host_xf.basis.y.normalized() if host >= 0 else Vector3.UP, "touch": host, "moved": false,
		"weld": -1, "weld_rel": Transform3D.IDENTITY, "weld_in": 1.0, "guide": 0.0, "dormant": true})
	return bodies.size() - 1


## Body [param bi] welded to solid [param si], at [param rel] from it (the body's motion in that solid's space): eased there over
## [constant WELD_EASE] from where it is, asleep on it, woken by nothing but a hand ([method TablePhysics._weld]).
func weld(bi: int, si: int, rel: Transform3D, xf: Transform3D) -> void:
	var b: Dictionary = bodies[bi]
	var now := xf.affine_inverse() * _motion(b)
	b["held"] = null
	b["held_from"] = null
	b["asleep"] = true
	b["v"] = Vector3.ZERO
	b["w"] = Vector3.ZERO
	b["still"] = 0.0
	b["guide"] = 0.0
	b["touch"] = si
	b["host"] = si
	b["hup"] = xf.basis.y.normalized()
	b["weld_rel"] = rel
	# ...eased in from where it is, unless it is there already (as built, or riding its seat)
	b["weld_in"] = 1.0 if int(b["weld"]) == si or _span(b, now, rel) < 0.0005 else 0.0
	b["hrel"] = now if float(b["weld_in"]) < 1.0 else rel
	b["weld"] = si


## Whether body [param bi] is welded to a seat.
func welded(bi: int) -> bool:
	return int((bodies[bi] as Dictionary)["weld"]) >= 0


## Body [param bi] taken from its seat by a hand.
func unweld(bi: int) -> void:
	(bodies[bi] as Dictionary)["weld"] = -1


## A hand lets go of body [param bi]: it is lowered onto what takes it at a hand's pace for [constant GUIDE] seconds.
func guide(bi: int) -> void:
	(bodies[bi] as Dictionary)["guide"] = GUIDE


## Whether body [param bi] is held up where it is: points of its surface within [constant SUPPORT_NEAR] of the table's top or of a solid
## (as the last frame left them) that faces up there at least [constant HELD_UP], and its middle over them - so let go, it stays.
## Touching is not enough: a ladle whose bowl grazes a vial's rim, or whose handle leans on a pot's rim with its weight past it, falls.
func supported(bi: int) -> bool:
	var b: Dictionary = bodies[bi]
	var d := _motion(b)
	var near := _near(b, d)
	var feet := PackedVector2Array()
	for q in (b["pts"] as PackedVector3Array):
		var p := d * q
		if p.y < _top + SUPPORT_NEAR:
			feet.append(Vector2(p.x, p.z))
			continue
		for si in (near["solids"] as PackedInt32Array):
			var sd: Dictionary = _solids[si]
			if not (sd["wbox"] as AABB).grow(SUPPORT_NEAR).has_point(p):
				continue
			var f: Vector4 = (sd["field"] as ShapeField).sample((sd["inv"] as Transform3D) * p)
			if f.x < SUPPORT_NEAR and ((sd["xf"] as Transform3D).basis * Vector3(f.y, f.z, f.w)).normalized().y >= HELD_UP:
				feet.append(Vector2(p.x, p.z))
				break
	if feet.is_empty():
		return false
	var c: Vector3 = b["c"]
	var mid := Vector2(c.x, c.z)
	var hull := Geometry2D.convex_hull(feet)
	if hull.size() >= 4:
		if Geometry2D.is_point_in_polygon(mid, hull):
			return true
	# ...or near enough the points or the line they make
	var least := INF
	for k in feet.size():
		least = minf(least, mid.distance_to(feet[k]))
	for k in range(hull.size() - 1):
		least = minf(least, mid.distance_to(Geometry2D.get_closest_point_to_segment(mid, hull[k], hull[k + 1])))
	return least <= SUPPORT_GROW


## Let go, where does it go? Body [param bi] let go where it is now - a hand lowering it ([method guide]) - stepped alone for at most
## [param seconds] of [param dt] among everything else as the last frame left it, which holds still: `{drop}`, how far its lowest point
## went down (meters), and `{falling}`, whether it was still going down at the end. A copy is stepped: the body itself is untouched. What
## a hand may let go of is what this says comes to rest about where it is ([method TablePhysics._would_fall]) - one test for every shape,
## never a rule for one: a ladle on its rest and its block, a ladle standing in its pot (it leans on the rim), a cork on its jar's lip; and
## never a feather held up in the air.
func trial(bi: int, seconds: float, dt: float) -> Dictionary:
	var b: Dictionary = (bodies[bi] as Dictionary).duplicate(true)
	b["held"] = null
	b["held_from"] = null
	b["asleep"] = false
	b["still"] = 0.0
	b["v"] = Vector3.ZERO
	b["w"] = Vector3.ZERO
	b["guide"] = GUIDE
	b["anchor"] = _motion(b)
	var low0 := _lowest(b)
	var low := low0
	var t := 0.0
	while t < seconds and not bool(b["asleep"]):
		low = _lowest(b)
		_loose_frame(b, dt)
		t += dt
	var low1 := _lowest(b)
	# ...and how it came to rest: its up turned from what it was, and where it is (a hand asks whether that is any way to leave it,
	# [method TablePhysics._lands_ill])
	var up0 := motion(bi).basis * Vector3.UP
	var end := _motion(b)
	return {"drop": low0 - low1, "falling": not bool(b["asleep"]) and low - low1 > FALLING * dt, "turned": up0.angle_to(end.basis * Vector3.UP), "pose": end}


## How fast a body tried let go may still be going down at the end of its trial and be at rest (meters a second).
const FALLING := 0.02


## The height of body [param b]'s lowest point now (meters).
static func _lowest(b: Dictionary) -> float:
	var d := _motion(b)
	var low := INF
	for q in (b["pts"] as PackedVector3Array):
		low = minf(low, (d * q).y)
	return low


## Body [param bi]'s pose now: the rigid motion that carries it from where it was built to where it is.
func motion(bi: int) -> Transform3D:
	return _motion(bodies[bi])


static func _motion(b: Dictionary) -> Transform3D:
	var r := Basis(b["q"] as Quaternion)
	return Transform3D(r, (b["c"] as Vector3) - r * (b["c0"] as Vector3))


static func _set_motion(b: Dictionary, d: Transform3D) -> void:
	b["q"] = d.basis.get_rotation_quaternion()
	b["c"] = d * (b["c0"] as Vector3)


## How far a body must go in a frame (meters, at any point) to stir what lies loose near it ([method TablePhysics._wake_near_loose]):
## settling, it does not.
const STIRS := 0.0002


## Whether body [param b] (its solids [param own]) never meets body [param ob] nor is woken by it: [param ob] rests in it or
## on it - asleep on one of its solids, or awake and last touching one - or is a lighter thing in a hand (held or not, [param b]:
## a jar carried with its cork goes where its hand has it, and the cork meets the jar).
static func _yields_to(ob: Dictionary, b: Dictionary, own: PackedInt32Array) -> bool:
	if ob["held"] != null and float(ob["m"]) < float(b["m"]):
		return true
	return own.has(int(ob["host"])) if bool(ob["asleep"]) else own.has(int(ob["touch"]))


## Whether any body is awake or held.
func busy() -> bool:
	for b in bodies:
		if not bool((b as Dictionary)["asleep"]) or (b as Dictionary)["held"] != null:
			return true
	return false


## Whether body [param bi] rests on or against anything where it is: a point of its surface within [param within] (meters)
## of the table's top, of another solid as the last frame left them, or of a loose thing's sphere.
func touching(bi: int, within: float) -> bool:
	var b: Dictionary = bodies[bi]
	var d := _motion(b)
	var near := _near(b, d)
	# ...the loose things' spheres in its reach, held or not
	var reach := _fill(b, d).grow(within)
	var spheres := PackedInt32Array()
	if not _spheres.is_empty():
		for i in int(_spheres["n"]):
			if (_spheres["alive"] as PackedByteArray)[i] == 1 and reach.grow((_spheres["r"] as PackedFloat32Array)[i]).has_point((_spheres["x"] as PackedVector3Array)[i]):
				spheres.append(i)
	for q in (b["pts"] as PackedVector3Array):
		var p := d * q
		if p.y < _top + within:
			return true
		for si in (near["solids"] as PackedInt32Array):
			var sd: Dictionary = _solids[si]
			if (sd["wbox"] as AABB).grow(within).has_point(p) \
					and (sd["field"] as ShapeField).sample((sd["inv"] as Transform3D) * p).x < within:
				return true
		for i in spheres:
			if p.distance_to((_spheres["x"] as PackedVector3Array)[i]) < (_spheres["r"] as PackedFloat32Array)[i] + within:
				return true
	return false


# --- the frame ------------------------------------------------------------------------------------------

## One frame of [param dt] seconds among [param world]'s `solids` (each with its `xf`, `xf0`, `inv`, `field`, `wbox`, `moving`, `mu`,
## `on`) over the table's `top`: each body held, falling or asleep on its holder - and its own solids put where it went.
func step(dt: float, world: Dictionary) -> void:
	_solids = world.get("solids", [])
	_top = float(world.get("top", 0.0))
	_spheres = world.get("spheres", {})
	# the held first, then the loose, then those asleep - each carried by its holder as it now stands
	var order: Array = []
	for pass_i in 3:
		for bi in bodies.size():
			var b: Dictionary = bodies[bi]
			var k := 0 if b["held"] != null else (2 if bool(b["asleep"]) else 1)
			if k == pass_i:
				order.append(bi)
	# ...what stirs, found once a frame: what a sleeper is woken by (most frames, nothing)
	var stirring: Array = []
	for si in _solids.size():
		var sd: Dictionary = _solids[si]
		if bool(sd.get("stirs", sd.get("moving", false))) and bool(sd.get("on", true)):
			stirring.append([si, sd["wbox"]])
	for bi in order:
		var b: Dictionary = bodies[bi]
		# Dormant: as built, untouched - a solid that does not move, reckoned no further than whether it is taken along now ([method
		# _stirred]). Every free part and every thing that may be moved is a body (next/framework_audit.md), and a frame finds the few a hand
		# has taken up awake.
		if bool(b.get("dormant", false)):
			if b["held"] == null and not _stirred(b, stirring):
				b["moved"] = false
				continue
			b["dormant"] = false
		var was := _motion(b)
		if b["held"] != null:
			b["asleep"] = false
			_held_frame(b, dt)
		elif bool(b["asleep"]):
			_asleep_frame(b, stirring)
		if not bool(b["asleep"]) and b["held"] == null:
			_loose_frame(b, dt)
		var now := _motion(b)
		b["moved"] = not now.is_equal_approx(was)
		b["stir"] = _way_from(b, was)
		_place_solids(b, was, now, dt)


## A held body: the frame's way to where the hand has it, in its pieces ([method _go]), meeting what it is moved into - its speed the
## hand's as it goes, so let go it goes on as the hand had it going.
func _held_frame(b: Dictionary, dt: float) -> void:
	var near := _near(b, (b["held"] as Transform3D))
	b["touch"] = -1
	b["by"] = -1
	var from := _motion(b)
	var hand: Transform3D = b["held_from"] if b["held_from"] != null else from
	# ...as fast as its hand, and back into it gently where it meets something - but where it was clear of everything by more than it
	# lags, at a hand's own pace
	var lag := _way_from(b, b["held"])
	var catch_up := CATCH_UP_CLEAR if float(b["clear"]) > minf(lag, CATCH_CLEAR) else CATCH_UP
	_go(b, from, b["held"], near, true, dt, _span(b, hand, b["held"]) + catch_up * dt)
	_speeds(b, from, dt)
	b["still"] = 0.0
	b["anchor"] = _motion(b)
	b["host"] = -1


## A loose body: gravity, then its contacts, a substep at a time; still long enough, it sleeps on what holds it up.
func _loose_frame(b: Dictionary, dt: float) -> void:
	var h := dt / float(SUBSTEPS)
	# What holds it up carries it: one settling on or in what is being moved goes with it, and only how it moves there is reckoned
	var hs := int(b["touch"])
	if _may_hold(hs, b) and bool((_solids[hs] as Dictionary).get("moving", false)):
		var sd: Dictionary = _solids[hs]
		_set_motion(b, ((sd["xf"] as Transform3D) * (sd["xf0"] as Transform3D).affine_inverse()) * _motion(b))
	var ahead := _motion(b)
	ahead.origin += (b["v"] as Vector3) * dt + GRAVITY * dt * dt
	var near := _near(b, ahead)
	var touched := false
	var begun := _motion(b)
	for s in SUBSTEPS:
		var from := _motion(b)
		var v: Vector3 = (b["v"] as Vector3) + GRAVITY * h
		var w: Vector3 = (b["w"] as Vector3) * exp(-SPIN_DAMP * h)
		var want := from
		want.origin += v.limit_length(V_MOST) * h
		var wl := w.length()
		if wl > 1e-9:
			var turn := Basis(w / wl, wl * h)
			var c: Vector3 = b["c"]
			want = Transform3D(turn, c - turn * c) * want
		b["touch"] = -1
		b["hits"] = []
		var v0: Vector3 = b["v"]
		var w0: Vector3 = b["w"]
		_go(b, from, want, near, false, h)
		touched = touched or int(b["touch"]) != -1
		_speeds(b, from, h)
		_bounce(b, v0, w0, h)
		# ...a body resting on something stops trembling
		if int(b["touch"]) != -1 and (b["v"] as Vector3).length() + (b["w"] as Vector3).length() * float(b["rad"]) < SETTLE:
			b["v"] = (b["v"] as Vector3) * (1.0 - SETTLE_LOSS)
			b["w"] = (b["w"] as Vector3) * (1.0 - SETTLE_LOSS)
		# ...and just let go, a hand lowers it: no point of it faster than GUIDE_V
		if float(b["guide"]) > 0.0:
			var lin := (b["v"] as Vector3).length()
			var spin := (b["w"] as Vector3).length() * float(b["rad"])
			if lin + spin > GUIDE_V:
				var k := GUIDE_V / (lin + spin)
				b["v"] = (b["v"] as Vector3) * k
				b["w"] = (b["w"] as Vector3) * k
	b["guide"] = maxf(float(b["guide"]) - dt, 0.0)
	var fastest := _way_from(b, begun) / dt
	if touched and (fastest < SLEEP_SPEED or _way_from(b, b["anchor"]) < SLEEP_DRIFT):
		b["still"] = float(b["still"]) + dt
		if float(b["still"]) >= SLEEP_AFTER:
			_sleep(b)
	else:
		b["still"] = 0.0
		b["anchor"] = _motion(b)


## An asleep body goes where its holder goes - and wakes as its holder tips past [constant WAKE_TILT] or jolts past [constant WAKE_JOLT],
## or as a moving solid comes to it.
func _asleep_frame(b: Dictionary, stirring: Array) -> void:
	var hs := int(b["host"])
	# Welded to its seat: exactly where its seat is, eased onto it as it was welded - and nothing wakes it but a hand
	if int(b["weld"]) >= 0 and hs >= 0 and hs < _solids.size():
		var dt := float((_solids[hs] as Dictionary).get("dt", 1.0 / 60.0))
		if float(b["weld_in"]) < 1.0:
			var was: Transform3D = b["hrel"]
			var s := minf(float(b["weld_in"]) + dt / WELD_EASE, 1.0)
			b["hrel"] = _between(b, was, b["weld_rel"], (s - float(b["weld_in"])) / maxf(1.0 - float(b["weld_in"]), 1e-6))
			b["weld_in"] = s
		_set_motion(b, ((_solids[hs] as Dictionary)["xf"] as Transform3D) * (b["hrel"] as Transform3D))
		return
	if hs >= 0 and hs < _solids.size():
		var sd: Dictionary = _solids[hs]
		if bool(sd.get("moving", false)):
			_set_motion(b, (sd["xf"] as Transform3D) * (b["hrel"] as Transform3D))
			var up := (sd["xf"] as Transform3D).basis.y.normalized()
			if up.angle_to(b["hup"] as Vector3) > WAKE_TILT or float(sd.get("jolt", 0.0)) > WAKE_JOLT:
				_wake(b, sd)
				return
	if stirring.is_empty():
		return
	var box := _box(b, _motion(b)).grow(WAKE_NEAR)
	var own: PackedInt32Array = b["solids"]
	# ...nor by what carries it: its holder's own body moving it, every solid of it
	var hb := int((_solids[hs] as Dictionary).get("body", -1)) if hs >= 0 and hs < _solids.size() else -1
	# ...stirring, not settling: two bodies trembling at rest side by side (a jar and its stopper) would wake each other forever
	for e in stirring:
		var si := int((e as Array)[0])
		if si == hs or own.has(si) or (hb >= 0 and int((_solids[si] as Dictionary).get("body", -1)) == hb):
			continue
		# ...nor by what rests in it or on it, which it never meets ([method _near])
		var ob := int((_solids[si] as Dictionary).get("body", -1))
		if ob >= 0 and _yields_to(bodies[ob], b, own):
			continue
		if ((e as Array)[1] as AABB).intersects(box):
			_wake(b, null)
			return


## Whether dormant body [param b] is taken along this frame ([method step]): what holds it up moves - a pestle in its mortar as the
## mortar is carried, a cork in its jar. Nothing else wakes it, nothing passing near it ([param _stirring] is not looked at): until a hand
## takes it up or what it stands on goes, it is exactly the solid it was before it was a body, met as one and moved by nothing
## (next/framework_audit.md).
func _stirred(b: Dictionary, _stirring: Array) -> bool:
	var hs := int(b["host"])
	return hs >= 0 and hs < _solids.size() and bool((_solids[hs] as Dictionary).get("moving", false))


## Body [param b] woken: moving as its holder [param sd] moved it, if any.
func _wake(b: Dictionary, sd: Variant) -> void:
	b["asleep"] = false
	b["still"] = 0.0
	b["anchor"] = _motion(b)
	b["v"] = Vector3.ZERO
	b["w"] = Vector3.ZERO
	if sd is Dictionary:
		var c: Vector3 = b["c"]
		var dt := float((sd as Dictionary).get("dt", 1.0 / 60.0))
		b["v"] = (((sd as Dictionary)["xf"] as Transform3D) * (((sd as Dictionary)["xf"] as Transform3D).affine_inverse() * c) \
			- ((sd as Dictionary)["xf0"] as Transform3D) * (((sd as Dictionary)["xf"] as Transform3D).affine_inverse() * c)) / maxf(dt, 1e-4)
	b["host"] = -1


## Whether solid [param si] may hold body [param b] up - be what it sleeps on and is carried by: never a lighter thing in a hand (a jar
## set down as its cork is taken up must not sleep on the cork).
func _may_hold(si: int, b: Dictionary) -> bool:
	if si < 0 or si >= _solids.size():
		return false
	var ob := int((_solids[si] as Dictionary).get("body", -1))
	return ob < 0 or (bodies[ob] as Dictionary)["held"] == null or float((bodies[ob] as Dictionary)["m"]) >= float(b["m"])


## Body [param b] asleep on what it touched last - a solid, or the table's top.
func _sleep(b: Dictionary) -> void:
	b["asleep"] = true
	b["v"] = Vector3.ZERO
	b["w"] = Vector3.ZERO
	var hs := int(b["touch"])
	if _may_hold(hs, b):
		var xf: Transform3D = (_solids[hs] as Dictionary)["xf"]
		b["host"] = hs
		b["hrel"] = xf.affine_inverse() * _motion(b)
		b["hup"] = xf.basis.y.normalized()
	else:
		b["host"] = -1


## The speed a push gave it, put right (Muller et al. 2020's velocity pass): at each point it met something this substep, one after
## another, its speed along the way out is set to [constant BOUNCE] of how fast it came in there ([param v0], [param w0], its speeds
## before) - none, coming in slower than a substep of gravity gives it, so what rests does not tremble - and its slide there slowed by
## kinetic friction as much as that changed.
func _bounce(b: Dictionary, v0: Vector3, w0: Vector3, h: float) -> void:
	var hits: Array = b.get("hits", [])
	if hits.is_empty():
		return
	var r := Basis(b["q"] as Quaternion)
	var ii: Basis = r * (b["ii"] as Basis) * r.transposed()
	var c: Vector3 = b["c"]
	var wm := 1.0 / float(b["m"])
	var calm := 2.0 * GRAVITY.length() * h
	for hit in hits:
		var nn: Vector3 = (hit as Array)[1]
		var arm: Vector3 = ((hit as Array)[0] as Vector3) - c
		var v: Vector3 = b["v"]
		var w: Vector3 = b["w"]
		var at := v + w.cross(arm)
		var vn := at.dot(nn)
		var came := (v0 + w0.cross(arm)).dot(nn)
		var want := BOUNCE * -came if came < -calm else 0.0
		var dn := want - vn
		var rn := arm.cross(nn)
		var j := dn / (wm + rn.dot(ii * rn))
		v += nn * (j * wm)
		w += ii * rn * j
		# ...and its slide there, slowed by kinetic friction for that much change
		var vt := (v + w.cross(arm)) - nn * (v + w.cross(arm)).dot(nn)
		var lt := vt.length()
		if lt > 1e-9:
			var by := minf(lt, ((hit as Array)[4] as Vector2).y * absf(dn))
			var tn := -vt / lt
			var rt := arm.cross(tn)
			var jt := by / (wm + rt.dot(ii * rt))
			v += tn * (jt * wm)
			w += ii * rt * jt
		b["v"] = v
		b["w"] = w


## Its speeds from where it went over [param h] seconds from [param from].
func _speeds(b: Dictionary, from: Transform3D, h: float) -> void:
	var c0: Vector3 = b["c0"]
	b["v"] = ((b["c"] as Vector3) - from * c0) / h
	var dq: Quaternion = (b["q"] as Quaternion) * from.basis.get_rotation_quaternion().inverse()
	if dq.w < 0.0:
		dq = -dq
	b["w"] = (Vector3(dq.x, dq.y, dq.z) * (2.0 / h)).limit_length(V_MOST / maxf(float(b["rad"]), 0.01))


## Body [param b] from [param from] toward [param want], in pieces short enough never to step over a thin wall, each kept out of every
## solid near it ([param near], [method _near]) - [param held]: firm in a hand.
func _go(b: Dictionary, from: Transform3D, want: Transform3D, near: Dictionary, held: bool, h: float, pace := INF) -> void:
	var way := _span(b, from, want)
	# ...no further a frame than its pieces at their longest: a hand that has gone on past what stopped it is followed a step at a time,
	# never in one stride deep into what is in the way - and, held, no further than [param pace]
	# ...but clear of everything by more than that, there is nothing to step past, so it goes as its hand does
	var most := minf(STEP_MOST * float(PIECES_MOST), pace)
	var free := float(b["clear"]) - _way_from(b, b["clear_from"]) if float(b["clear"]) > 0.0 else 0.0
	if free > most:
		most = minf(free, pace)
	if way > most:
		want = _between(b, from, want, most / way)
		way = most
	var pieces := clampi(int(ceil(way / STEP_MOST)), 1, PIECES_MOST)
	for k in pieces:
		# ...each piece on from where the last one was kept - never from the frame's start along a straight line, which throws away what
		# had stopped it
		var prev := _motion(b)
		_set_motion(b, _between(b, prev, want, 1.0 / float(pieces - k)))
		# Clear of everything by more than it has gone since it was last looked at: nothing to meet
		if float(b["clear"]) > 0.0 and _way_from(b, b["clear_from"]) < float(b["clear"]):
			continue
		_contacts(b, prev, near, held, h)


## How far any point of body [param b] has gone since it was posed [param from] (meters, at most).
static func _way_from(b: Dictionary, from: Transform3D) -> float:
	return _span(b, from, _motion(b))


## How far any point of body [param b] goes from pose [param a] to pose [param x2] (meters, at most).
static func _span(b: Dictionary, a: Transform3D, x2: Transform3D) -> float:
	var c0: Vector3 = b["c0"]
	return (x2 * c0).distance_to(a * c0) + a.basis.get_rotation_quaternion().angle_to(x2.basis.get_rotation_quaternion()) * float(b["rad"])


## Body [param b]'s pose [param s] of the way from [param a] to [param x2]: its middle straight from one to the other, turned
## about it.
static func _between(b: Dictionary, a: Transform3D, x2: Transform3D, s: float) -> Transform3D:
	var c0: Vector3 = b["c0"]
	var r := Basis(a.basis.get_rotation_quaternion().slerp(x2.basis.get_rotation_quaternion(), s))
	return Transform3D(r, (a * c0).lerp(x2 * c0, s) - r * c0)


## What body [param b] may meet this frame, posed [param ahead] at its end: every other solid whose box comes near its way
## (`solids`), and of each the points of its surface that do (`points`, the table's space) - found once a frame - and how
## near the nearest it is not looked at may come this frame (`far`, meters: the gap between their boxes, less the most any
## point of it goes in a frame).
func _near(b: Dictionary, ahead: Transform3D) -> Dictionary:
	# ...the box its own points fill, now and at the frame's end: a ball about its middle took in a ladle's whole hearth
	var here := _fill(b, _motion(b))
	var reach := here.merge(_fill(b, ahead)).grow(0.005)
	var own: PackedInt32Array = b["solids"]
	var out := PackedInt32Array()
	var held := b["held"] != null
	var gap_least := INF
	# ...nor its seat while a hand eases it in or out ([method TablePhysics._seat])
	var seated: PackedInt32Array = b.get("seat_skip", PackedInt32Array())
	for si in _solids.size():
		if seated.has(si):
			continue
		var sd: Dictionary = _solids[si]
		# ...never what hangs from it and goes where it goes: a balance's beam on its hinge, carried with its base
		if own.has(si) or (sd.get("bodies", []) as Array).has(int(b["bi"])):
			continue
		if not bool(sd.get("on", true)) or not (sd["wbox"] as AABB).intersects(reach):
			gap_least = minf(gap_least, _gap(here, sd["wbox"]))
			continue
		# ...never what rests in it or on it, held or not: what a thing holds goes with it and never shoves it (a mortar carried with its
		# pestle lying in it), nor a lighter thing in a hand: a pestle ground round its bowl never shoves the mortar. Anything else it
		# meets - and what another hand holds at once: two held bodies would pass through each other
		if sd.has("body"):
			var ob: Dictionary = bodies[int(sd["body"])]
			if _yields_to(ob, b, own):
				continue
		out.append(si)
		# ...one moving: how clear it was is no longer known
		if bool(sd.get("moving", false)):
			b["clear"] = 0.0
	# ...and, let go, the loose things' spheres in its reach, which may hold it up - never what lies in it or on it: what a vessel holds
	# cannot lift it
	var near_spheres := PackedInt32Array()
	if not held and not _spheres.is_empty():
		var sx: PackedVector3Array = _spheres["x"]
		var sr: PackedFloat32Array = _spheres["r"]
		var sa: PackedByteArray = _spheres["alive"]
		var on: PackedInt32Array = _spheres.get("touch", PackedInt32Array())
		var hosts: PackedInt32Array = _spheres.get("host", PackedInt32Array())
		var asleep: PackedByteArray = _spheres.get("asleep", PackedByteArray())
		for i in int(_spheres["n"]):
			if sa[i] != 1 or not reach.grow(sr[i]).has_point(sx[i]):
				continue
			var under := hosts[i] if i < asleep.size() and asleep[i] == 1 else (on[i] if i < on.size() else -1)
			if under >= 0 and own.has(under):
				continue
			near_spheres.append(i)
		if not near_spheres.is_empty():
			b["clear"] = 0.0
	return {"solids": out, "points": null, "reach": reach, "spheres": near_spheres,
		"far": maxf(gap_least - STEP_MOST * float(PIECES_MOST * SUBSTEPS), 0.0)}


## How far apart boxes [param a] and [param x2] are at their nearest (meters; 0 where they meet).
static func _gap(a: AABB, x2: AABB) -> float:
	var d := (x2.position - a.end).max(a.position - x2.end).max(Vector3.ZERO)
	return d.length()


## The points of each of [param near]'s solids within its reach (the table's space), found the first time a frame asks.
func _near_points(near: Dictionary) -> Array:
	if near["points"] != null:
		return near["points"]
	var reach: AABB = near["reach"]
	var pts: Array = []
	for si in (near["solids"] as PackedInt32Array):
		var sd: Dictionary = _solids[si]
		var xf: Transform3D = sd["xf"]
		# ...each solid's points where it stands, kept until it moves
		if sd.get("wpts") == null or not (sd["wpts_xf"] as Transform3D).is_equal_approx(xf):
			var spts := (sd["field"] as ShapeField).surface_points()
			var w := PackedVector3Array()
			for j in range(0, spts.size(), maxi(1, spts.size() / OTHER_POINTS)):
				w.append(xf * spts[j])
			sd["wpts"] = w
			sd["wpts_xf"] = xf
		var mine := PackedVector3Array()
		for p in (sd["wpts"] as PackedVector3Array):
			if reach.has_point(p):
				mine.append(p)
		pts.append(mine)
	near["points"] = pts
	return pts


## The box body [param b]'s points fill posed [param d].
static func _fill(b: Dictionary, d: Transform3D) -> AABB:
	var pts: PackedVector3Array = b["pts"]
	var box := AABB(d * pts[0], Vector3.ZERO)
	for q in pts:
		box = box.expand(d * q)
	return box


## The box body [param b] fills posed [param d] (a ball about its middle).
static func _box(b: Dictionary, d: Transform3D) -> AABB:
	var r := float(b["rad"])
	return AABB(d * (b["c0"] as Vector3) - Vector3.ONE * r, Vector3.ONE * r * 2.0)


## Kept out of the solids [param near] and the table's top, in [constant PASSES] passes: each of its points in a solid, and each of a
## solid's points in it, pushed out along the way out, its slide along it since [param prev] held by friction - every contact of a pass
## reckoned against the same pose and their corrections averaged (one after another, each would turn the body against the last).
func _contacts(b: Dictionary, prev: Transform3D, near_d: Dictionary, held: bool, _h: float) -> void:
	var near: PackedInt32Array = near_d["solids"]
	var pts: PackedVector3Array = b["pts"]
	var mu: Vector2 = b["mu"]
	var own: PackedInt32Array = b["solids"]
	var rests: Array = b["rests"]
	var near_pts := _near_points(near_d)
	var boxes: Array = []
	for k in own.size():
		boxes.append(((_solids[own[k]] as Dictionary)["box"] as AABB).grow(SLACK))
	var table_mu := Vector2(sqrt(mu.x * TABLE_MU.x), sqrt(mu.y * TABLE_MU.y))
	var nearest := INF
	var met := false
	var up_most := -INF
	var met_up := -INF
	for pass_i in PASSES:
		var d := _motion(b)
		var hits: Array = []
		# Its points in the solids, and in the table's top
		var faces: Dictionary = b["faces"]
		var closest := {}   # solid -> [its own point nearest it (as built), how near]: where [method _refined] starts from
		for j in pts.size():
			var q := pts[j]
			var p := d * q
			if pass_i == 0:
				nearest = minf(nearest, p.y - _top)
			if p.y < _top + SLACK:
				hits.append([p, Vector3.UP, _top + SLACK - p.y, Vector3.ZERO, table_mu, TABLE, q, -1])
			for si in near:
				var sd: Dictionary = _solids[si]
				var wb: AABB = sd["wbox"]
				if not wb.grow(maxf(SLACK, float(b["gap"]))).has_point(p):
					if pass_i == 0:
						nearest = minf(nearest, _outside(wb, p))
					continue
				var local := (sd["inv"] as Transform3D) * p
				var f: Vector4 = (sd["field"] as ShapeField).sample(local)
				if pass_i == 0:
					nearest = minf(nearest, f.x)
				if f.x < float(b["gap"]) + SLACK:
					if not closest.has(si):
						closest[si] = []
					(closest[si] as Array).append([q, f.x])
				var key := j * 4096 + si
				var xf: Transform3D = sd["xf"]
				var sv := (xf * local - (sd["xf0"] as Transform3D) * local) / float(SUBSTEPS)
				# ...still in by the face it came in by: kept until it is back in front of that face or clear of the wall - a let-go body's
				# contacts are put right only in their mean, and a point left a little in a thin wall, asked again from inside, would be put out
				# through the far side
				if faces.has(key):
					var face: Array = faces[key]
					var past := float(face[1]) - p.dot(face[0] as Vector3)
					# ...out of the wall, only near where it came in - out its far side; a face is a plane, and a cup's foot that grazed a
					# bowl's rim on its way in would be held up by the rim's plane
					if past < 0.0 or bool(sd.get("moving", false)) \
							or (f.x >= -SLACK and (f.x > FACE_FAR or p.distance_to(face[2] as Vector3) > FACE_REACH)):
						faces.erase(key)
					else:
						if past > SLACK:
							hits.append([p, face[0], past - SLACK, sv, _mu_with(mu, sd), si, q, -1, face])
						continue
				if f.x >= -SLACK:
					continue
				var way_out := (xf.basis * Vector3(f.y, f.z, f.w)).normalized()
				var deep := -SLACK - f.x
				# A still wall is met on the side it was come to from: a point outside it at the piece's start is pushed back out where it
				# came in - past a thin wall's middle, the wall's own way out is through its far side
				if not bool(sd.get("moving", false)):
					var field: ShapeField = sd["field"]
					var inv: Transform3D = sd["inv"]
					var pp := prev * q
					# (out of it as far as a contact goes - within the slack it stands in what it rests on, and a point resting there would
					# keep losing its face and never be given one again)
					if field.sample(inv * pp).x >= -SLACK:
						var lo := 0.0
						var hi := 1.0
						for _k in 10:
							var mid := (lo + hi) * 0.5
							if field.sample(inv * pp.lerp(p, mid)).x >= 0.0:
								lo = mid
							else:
								hi = mid
						var e := pp.lerp(p, lo)
						var fe := field.sample(inv * e)
						way_out = (xf.basis * Vector3(fe.y, fe.z, fe.w)).normalized()
						deep = (e - p).dot(way_out) - fe.x - SLACK
						if deep <= 0.0:
							continue
						# ...and measured again against that face, never the wall's own way out ([method _depth_now])
						faces[key] = [way_out, e.dot(way_out) - fe.x, e]
						hits.append([p, way_out, deep, sv, _mu_with(mu, sd), si, q, -1, faces[key]])
						continue
				hits.append([p, way_out, deep, sv, _mu_with(mu, sd), si, q, -1])
		# ...and where it is deepest in each, found, never only at its points ([method _refined]): a handle laid across a rim between two
		# of its points would stand in it
		for si in closest:
			# ...from each place it comes near the solid, a few, apart (a ladle leaning in its pot meets it at its bowl and again
			# where its handle crosses the rim)
			var cs: Array = closest[si]
			cs.sort_custom(func(x: Array, y: Array) -> bool: return float(x[1]) < float(y[1]))
			var starts: Array = []
			for c in cs:
				var far := true
				for st in starts:
					if (d * ((st as Array)[0] as Vector3)).distance_to(d * ((c as Array)[0] as Vector3)) < REFINE_APART:
						far = false
						break
				if far:
					starts.append(c)
					if starts.size() >= REFINE_MOST:
						break
			for c in starts:
				_refine_hit(b, d, prev, si, (c as Array)[0], hits, mu)
		# ...and the solids' points in it: a rim thinner than the gaps between its points - each first against its own solids' boxes,
		# where they stand now
		var invs: Array = []
		for k in own.size():
			invs.append((d * (rests[k] as Transform3D)).affine_inverse())
		for n_i in near.size():
			var si := near[n_i]
			for p in (near_pts[n_i] as PackedVector3Array):
				for k in own.size():
					var lp: Vector3 = (invs[k] as Transform3D) * p
					if not (boxes[k] as AABB).has_point(lp):
						if pass_i == 0:
							nearest = minf(nearest, _outside(boxes[k], lp))
						continue
					var f: Vector4 = ((_solids[own[k]] as Dictionary)["field"] as ShapeField).sample(lp)
					if pass_i == 0:
						nearest = minf(nearest, f.x)
					if f.x >= -SLACK:
						continue
					# its way out of the body, the other way: the body goes from the point
					var nn := -((d * (rests[k] as Transform3D)).basis * Vector3(f.y, f.z, f.w)).normalized()
					# ...a thin wall of its own came onto a still point from one side: out that side (a ladle's bowl over a floor)
					var own_field: ShapeField = (_solids[own[k]] as Dictionary)["field"]
					var lpp := (prev * (rests[k] as Transform3D)).affine_inverse() * p
					if not bool((_solids[si] as Dictionary).get("moving", false)) and own_field.sample(lpp).x >= -SLACK:
						var lo := 0.0
						var hi := 1.0
						for _k in 10:
							var mid := (lo + hi) * 0.5
							if own_field.sample(lpp.lerp(lp, mid)).x >= 0.0:
								lo = mid
							else:
								hi = mid
						var e := lpp.lerp(lp, lo)
						var fe := own_field.sample(e)
						var nl := Vector3(fe.y, fe.z, fe.w).normalized()
						var deep := (e - lp).dot(nl) - fe.x - SLACK
						if deep > 0.0:
							hits.append([p, -((d * (rests[k] as Transform3D)).basis * nl).normalized(), deep, Vector3.ZERO, _mu_with(mu, _solids[si]), si, p, k,
								[nl, e.dot(nl) - fe.x]])
						break
					hits.append([p, nn, -SLACK - f.x, Vector3.ZERO, _mu_with(mu, _solids[si]), si, p, k])
					break
		# ...and, let go, the loose things under it, as solids: each sphere it has sunk into holds it up
		var near_spheres: PackedInt32Array = near_d.get("spheres", PackedInt32Array())
		if not held and not near_spheres.is_empty():
			var sx: PackedVector3Array = _spheres["x"]
			var sr: PackedFloat32Array = _spheres["r"]
			for i in near_spheres:
				for k in own.size():
					var lp: Vector3 = (invs[k] as Transform3D) * sx[i]
					if not (boxes[k] as AABB).grow(sr[i]).has_point(lp):
						continue
					var f: Vector4 = ((_solids[own[k]] as Dictionary)["field"] as ShapeField).sample(lp)
					var deep := sr[i] - SLACK - f.x
					if deep <= 0.0:
						continue
					var nn := -((d * (rests[k] as Transform3D)).basis * Vector3(f.y, f.z, f.w)).normalized()
					if nn.y < HELD_UP:
						continue
					var at: Vector3 = sx[i] + nn * f.x
					hits.append([at, nn, deep, Vector3.ZERO, mu, LOOSE, at, k])
					break
		if hits.is_empty():
			break
		met = true
		_resolve(b, hits, prev, held)
		# ...what holds it up is what it meets from below, never what pushes it from the side or above
		for hit in hits:
			var ny := ((hit as Array)[1] as Vector3).y
			if ny > met_up:
				met_up = ny
				b["by"] = int((hit as Array)[5])
			if ny > up_most and ny > HELD_UP:
				up_most = ny
				b["touch"] = int((hit as Array)[5])
	# The table's top holds, whatever else pushes: the mean of a let-go body's contacts puts right only their mean depth, and a body
	# wedged in another would be pushed through the other's floor and into the table
	if not held:
		var d := _motion(b)
		var under := 0.0
		for q in pts:
			under = maxf(under, _top - (d * q).y)
		if under > 0.0:
			b["c"] = (b["c"] as Vector3) + Vector3.UP * under
		# ...and so does a still wall it came into: what the mean left past the face a point came in by is put out along it, the deepest
		# first
		var faces: Dictionary = b["faces"]
		for _k in 3:
			d = _motion(b)
			var most := SLACK
			var way := Vector3.ZERO
			for key in faces.keys():
				var face: Array = faces[key]
				var j := int(key) / 4096
				var si := int(key) % 4096
				if j >= pts.size() or si >= _solids.size():
					faces.erase(key)
					continue
				# ...only while it is in that wall still: a face is a plane, and one kept past its point's going out would push the body
				# anywhere
				var p := d * pts[j]
				var sd: Dictionary = _solids[si]
				var deep := float(face[1]) - p.dot(face[0] as Vector3)
				var fx := (sd["field"] as ShapeField).sample((sd["inv"] as Transform3D) * p).x if (sd["wbox"] as AABB).grow(FACE_FAR).has_point(p) else INF
				if deep < 0.0 or (fx >= -SLACK and (fx > FACE_FAR or p.distance_to(face[2] as Vector3) > FACE_REACH)):
					faces.erase(key)
					continue
				if deep > most:
					most = deep
					way = face[0]
			if way == Vector3.ZERO:
				break
			b["c"] = (b["c"] as Vector3) + way * (most - SLACK)
	# How clear it was of everything, less the gaps between its points - meeting nothing, it need not be looked at again until it has
	# gone that far ([method _go]). Everything: what it was not looked at against is as near as their boxes (`far`).
	nearest = minf(nearest, float(near_d.get("far", INF)))
	b["clear"] = 0.0 if met else maxf(nearest - float(b["gap"]) - SLACK, 0.0)
	b["clear_from"] = _motion(b)


## The deepest body [param b] (posed [param d]) is in solid [param si], found from its own point [param q0] (as built): down the solid's
## distance along its own surface, a step at a time, each step put back onto its surface by its nearest solid's field - the least of the
## solid's field over its surface near there (Macklin, Erleben, Muller, Chentanez, Jeschke and Corse, "Local Optimization for Robust
## Signed Distance Field Collision", 2020: a contact is the deepest point of one surface in the other, found by searching the surface,
## never one of a fixed set of samples). `[where on its surface (the table's space), how deep less the slack, the solid's way out there]`
## - or empty, past [constant REFINE_DEEP] (a deep contact is the points', which know which face of a thin wall it came in by).
func _refined(b: Dictionary, d: Transform3D, si: int, q0: Vector3) -> Array:
	var sd: Dictionary = _solids[si]
	var inv: Transform3D = sd["inv"]
	var xf: Transform3D = sd["xf"]
	var field: ShapeField = sd["field"]
	var p := d * q0
	var fb := field.sample(inv * p)
	var step := REFINE_STEP
	for _it in REFINE_STEPS:
		var nb := (xf.basis * Vector3(fb.y, fb.z, fb.w)).normalized()
		var na := _own_normal(b, d, p)
		# ...the way down the solid's distance that keeps to its own surface
		var g := -nb - na * (-nb).dot(na)
		if g.length() < 1e-3:
			break
		var q := _onto_own(b, d, p + g.normalized() * step)
		var fq := field.sample(inv * q)
		if fq.x < fb.x:
			p = q
			fb = fq
		else:
			step *= 0.5
			if step < 0.0002:
				break
	var deep := -SLACK - fb.x
	if deep > REFINE_DEEP:
		return []
	return [p, deep, (xf.basis * Vector3(fb.y, fb.z, fb.w)).normalized()]


## Body [param b]'s own way out at [param p] (posed [param d]): its nearest solid's.
func _own_normal(b: Dictionary, d: Transform3D, p: Vector3) -> Vector3:
	var own: PackedInt32Array = b["solids"]
	var rests: Array = b["rests"]
	var best := INF
	var n := Vector3.UP
	for k in own.size():
		var bx := d * (rests[k] as Transform3D)
		var fa: Vector4 = ((_solids[own[k]] as Dictionary)["field"] as ShapeField).sample(bx.affine_inverse() * p)
		if absf(fa.x) < best:
			best = absf(fa.x)
			n = (bx.basis * Vector3(fa.y, fa.z, fa.w)).normalized()
	return n


## [param p] put onto body [param b]'s own surface (posed [param d]), by its nearest solid's field.
func _onto_own(b: Dictionary, d: Transform3D, p: Vector3) -> Vector3:
	var own: PackedInt32Array = b["solids"]
	var rests: Array = b["rests"]
	var best := INF
	var out := p
	for k in own.size():
		var bx := d * (rests[k] as Transform3D)
		var fa: Vector4 = ((_solids[own[k]] as Dictionary)["field"] as ShapeField).sample(bx.affine_inverse() * p)
		if absf(fa.x) < best:
			best = absf(fa.x)
			out = p - (bx.basis * Vector3(fa.y, fa.z, fa.w)).normalized() * fa.x
	return out


## How many steps [method _refined] takes, how long its first is (meters), the deepest contact it says (meters) - and from how many
## of a body's points near a solid, at least how far apart (meters).
const REFINE_STEPS := 10
const REFINE_STEP := 0.003
const REFINE_DEEP := 0.004
const REFINE_MOST := 4
const REFINE_APART := 0.02


## Body [param b] (posed [param d], a piece before at [param prev]) refined into solid [param si] from its point [param q0] ([method
## _refined]): a contact added to [param hits] where it is in it - but never one whose way out has turned since a piece before, in a still
## wall: past a thin wall's middle its way out is through its far side, which the points' faces know and this does not.
func _refine_hit(b: Dictionary, d: Transform3D, prev: Transform3D, si: int, q0: Vector3, hits: Array, mu: Vector2) -> void:
	var got := _refined(b, d, si, q0)
	if got.is_empty() or float(got[1]) <= 0.0:
		return
	var sd: Dictionary = _solids[si]
	var p: Vector3 = got[0]
	if not bool(sd.get("moving", false)):
		var was: Vector4 = (sd["field"] as ShapeField).sample((sd["inv"] as Transform3D) * (prev * (d.affine_inverse() * p)))
		if was.x < -SLACK * 2.0 and ((sd["xf"] as Transform3D).basis * Vector3(was.y, was.z, was.w)).normalized().dot(got[2] as Vector3) < 0.0:
			return
	var local := (sd["inv"] as Transform3D) * p
	var sv := ((sd["xf"] as Transform3D) * local - (sd["xf0"] as Transform3D) * local) / float(SUBSTEPS)
	hits.append([p, got[2], float(got[1]), sv, _mu_with(mu, sd), si, d.affine_inverse() * p, -1])


## How far [param p] lies outside box [param box] (meters; 0 inside it).
static func _outside(box: AABB, p: Vector3) -> float:
	var q := Vector3(maxf(maxf(box.position.x - p.x, p.x - box.end.x), 0.0), maxf(maxf(box.position.y - p.y, p.y - box.end.y), 0.0),
		maxf(maxf(box.position.z - p.z, p.z - box.end.z), 0.0))
	return q.length()


## Body [param b] kept out by contacts [param hits] (`[point, way out, how deep, what met it moved, friction, solid, its own point as
## built or the solid's point, -1 or the body's solid it is in]`): each a positional correction by its generalized inverse mass there -
## firm in a hand when [param held] - its slide since [param prev] held by friction, static or kinetic. Let go, their mean is applied,
## each reckoned against the same pose (one after another, each would turn the body against the last, and a body at rest would tremble
## awake); held, each alone, deepest first, measured again where the body is now - a hand drives what it holds into what is in the way,
## and the mean puts right only the mean depth.
func _resolve(b: Dictionary, hits: Array, prev: Transform3D, held: bool) -> void:
	b["hits"] = hits
	if held:
		hits.sort_custom(func(x: Array, y: Array) -> bool: return float(x[2]) > float(y[2]))
		for hit in hits:
			var now := _depth_now(b, hit)
			if float(now[0]) > 0.0:
				_correct(b, now[2], now[1], float(now[0]), true)
		return
	var r := Basis(b["q"] as Quaternion)
	var ii: Basis = r * (b["ii"] as Basis) * r.transposed()
	if held:
		ii = ii * GRIP
	var c: Vector3 = b["c"]
	var wm := 1.0 / float(b["m"])
	var back := _motion(b).affine_inverse()
	var dc := Vector3.ZERO
	var dw := Vector3.ZERO
	for hit in hits:
		var h: Array = hit
		var p: Vector3 = h[0]
		var nn: Vector3 = h[1]
		var pen := float(h[2])
		var arm := p - c
		var rn := arm.cross(nn)
		var lam := pen / (wm + rn.dot(ii * rn))
		dc += nn * (lam * wm)
		dw += ii * rn * lam
		var slide := (p - prev * (back * p)) - (h[3] as Vector3)
		var t := slide - nn * slide.dot(nn)
		var lt := t.length()
		if lt < 1e-9:
			continue
		var fmu: Vector2 = h[4]
		var by := minf(lt, lt if lt < fmu.x * pen else fmu.y * pen)
		var tn := -t / lt
		var rt := arm.cross(tn)
		var lf := by / (wm + rt.dot(ii * rt))
		dc += tn * (lf * wm)
		dw += ii * rt * lf
	var k := float(hits.size())
	b["c"] = c + dc / k
	var spin := dw / k
	var q: Quaternion = b["q"]
	var dq := Quaternion(spin.x, spin.y, spin.z, 0.0) * q
	b["q"] = Quaternion(q.x + 0.5 * dq.x, q.y + 0.5 * dq.y, q.z + 0.5 * dq.z, q.w + 0.5 * dq.w).normalized()
	# ...and the deepest left in a solid, put out: the mean puts right only the mean depth, so the deepest contact is measured again where
	# the body is now and, still past twice the slack, the body is moved straight out along it, never turned (turned about one contact at a
	# time, a jar at rest would tremble); the table's top is held by its own pass ([method _contacts])
	if hits.size() > 1:
		var worst: Array = []
		var most := SLACK
		for hit in hits:
			if int((hit as Array)[5]) < 0:
				continue
			var now := _depth_now(b, hit)
			if float(now[0]) > most:
				most = float(now[0])
				worst = now
		if not worst.is_empty():
			b["c"] = (b["c"] as Vector3) + (worst[1] as Vector3) * (float(worst[0]) - SLACK)


## Contact [param h] measured again where body [param b] is now: `[how deep, way out, where]` - its own point against what
## it met (or the table's top), or the solid's point against the body's own solid it was in.
func _depth_now(b: Dictionary, h: Array) -> Array:
	var si := int(h[5])
	var k := int(h[7])
	var d := _motion(b)
	# ...against the face it came in by, where it kept one ([method _contacts]): a thin wall's own way out past its middle is through its
	# far side
	if h.size() > 8:
		var face: Array = h[8]
		var n: Vector3 = face[0]
		if k >= 0:
			var p: Vector3 = h[6]
			var bx := d * ((b["rests"] as Array)[k] as Transform3D)
			return [float(face[1]) - (bx.affine_inverse() * p).dot(n) - SLACK, -(bx.basis * n).normalized(), p]
		var q := d * (h[6] as Vector3)
		return [float(face[1]) - q.dot(n) - SLACK, n, q]
	if k >= 0:
		var p: Vector3 = h[6]
		var bx := d * ((b["rests"] as Array)[k] as Transform3D)
		var f: Vector4 = ((_solids[(b["solids"] as PackedInt32Array)[k]] as Dictionary)["field"] as ShapeField).sample(bx.affine_inverse() * p)
		return [-SLACK - f.x, -(bx.basis * Vector3(f.y, f.z, f.w)).normalized(), p]
	var p := d * (h[6] as Vector3)
	if si == TABLE:
		return [_top + SLACK - p.y, Vector3.UP, p]
	var sd: Dictionary = _solids[si]
	var local := (sd["inv"] as Transform3D) * p
	var f: Vector4 = (sd["field"] as ShapeField).sample(local)
	return [-SLACK - f.x, ((sd["xf"] as Transform3D).basis * Vector3(f.y, f.z, f.w)).normalized(), p]


## Body [param b] moved [param by] meters along [param nn] at [param p]: its generalized inverse mass there, its middle and
## its turn - firm in a hand when [param held].
func _correct(b: Dictionary, p: Vector3, nn: Vector3, by: float, held: bool) -> void:
	var r := Basis(b["q"] as Quaternion)
	var ii: Basis = r * (b["ii"] as Basis) * r.transposed()
	if held:
		ii = ii * GRIP
	var c: Vector3 = b["c"]
	var rn := (p - c).cross(nn)
	var wm := 1.0 / float(b["m"])
	var lam := by / (wm + rn.dot(ii * rn))
	b["c"] = c + nn * (lam * wm)
	var spin := ii * rn * lam
	var q: Quaternion = b["q"]
	var dq := Quaternion(spin.x, spin.y, spin.z, 0.0) * q
	b["q"] = Quaternion(q.x + 0.5 * dq.x, q.y + 0.5 * dq.y, q.z + 0.5 * dq.z, q.w + 0.5 * dq.w).normalized()


static func _mu_with(mu: Vector2, sd: Dictionary) -> Vector2:
	var smu: Vector2 = sd.get("mu", TABLE_MU)
	return Vector2(sqrt(mu.x * smu.x), sqrt(mu.y * smu.y))


## Body [param b]'s own solids where it went, from [param was] to [param now] over [param dt] seconds: their poses, what
## they meet by, whether they move and how hard they jolt.
func _place_solids(b: Dictionary, was: Transform3D, now: Transform3D, dt: float) -> void:
	var own: PackedInt32Array = b["solids"]
	var rests: Array = b["rests"]
	# Still, and still a frame ago: nothing of it to put anywhere
	if not bool(b["moved"]) and not bool(b.get("was_moved", true)):
		return
	b["was_moved"] = b["moved"]
	for k in own.size():
		var sd: Dictionary = _solids[own[k]]
		var xf := now * (rests[k] as Transform3D)
		sd["xf00"] = sd["xf0"]
		sd["xf0"] = sd["xf"]
		sd["xf"] = xf
		sd["moving"] = not xf.is_equal_approx(sd["xf0"])
		# ...and whether it moves enough to wake what sleeps by it: held, or going somewhere ([constant STIRS]) - and whether it presses
		# what it meets hard enough to break it: only as a hand drives it ([member Particles._np])
		sd["stirs"] = bool(sd["moving"]) and (b["held"] != null or float(b.get("stir", 0.0)) >= STIRS)
		sd["presses"] = b["held"] != null
		sd["dt"] = dt
		if bool(sd["moving"]) or not (sd["xf0"] as Transform3D).is_equal_approx(sd["xf00"]):
			sd["inv"] = xf.affine_inverse()
			sd["wbox"] = (xf * (sd["box"] as AABB)).grow(0.001)
			# ...held, it jolts nothing: a hand carries smoothly, and the pushes of what it met as it was taken up are no jolt to what is
			# in it
			sd["jolt"] = 0.0 if b["held"] != null else Particles.jolt_of((xf.origin - 2.0 * (sd["xf0"] as Transform3D).origin + (sd["xf00"] as Transform3D).origin) / (dt * dt))
		else:
			sd["jolt"] = 0.0


# --- kept -------------------------------------------------------------------------------------------------

## Every body as it stands, for a bake begun again from here ([method restore]) - all of what a frame reads: how far each went last frame
## (`stir`) wakes what lies loose round it, and a bake begun again with it gone would wake none.
func snapshot() -> Array:
	var out: Array = []
	for b in bodies:
		var d: Dictionary = {}
		for k in ["c", "q", "v", "w", "held", "held_from", "asleep", "still", "anchor", "host", "hrel", "hup", "touch", "moved", "clear", "clear_from",
				"stir", "was_moved", "weld", "weld_rel", "weld_in", "guide", "dormant"]:
			d[k] = (b as Dictionary)[k]
		d["faces"] = ((b as Dictionary)["faces"] as Dictionary).duplicate(true)
		out.append(d)
	return out


func restore(s: Array) -> void:
	for bi in mini(s.size(), bodies.size()):
		var b: Dictionary = bodies[bi]
		for k in (s[bi] as Dictionary):
			b[k] = (s[bi] as Dictionary)[k]
		b["faces"] = ((s[bi] as Dictionary).get("faces", {}) as Dictionary).duplicate(true)
