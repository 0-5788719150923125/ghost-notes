extends RefCounted
class_name RigidParts

## RigidParts - WHAT THE WORK PICKS UP, AS RIGID BODIES (next/table_physics.md, "Tools"): every part an act moves that
## is not loose - a pestle, a ladle, a jar and its cork, a lid - is a body with a mass, a middle and an inertia
## ([method TablePhysics._mass_of]), stepped by the bake ([TablePhysics]) on its own thread. The user, 2026-10-29: "We
## really want that behavior everywhere there is interaction between components, because faking it looks bad" - a
## pestle put back had stood through its mortar's wall, a lid laid on its crock jittered on it to the end of the show,
## and "the physics everywhere is just going to provide us with a better long-term foundation". So:
##
##   - HELD, it goes where the hand takes it and MEETS WHAT IT IS MOVED INTO: kept out of every other solid and the
##     table's top, pushed back along what it meets and turned about it as a grip gives a little (Muller, Macklin,
##     Chentanez, Jeschke and Kim, "Detailed Rigid Body Simulation with Extended Position Based Dynamics", 2020: each
##     contact a positional correction weighed by the body's generalized inverse mass at it, friction a correction of
##     its slide);
##   - LET GO, IT FALLS AND COMES TO REST: gravity, the same contacts, friction against what it lies on; still, it
##     sleeps on that and goes where that goes - a pestle in its mortar carried to the middle - until it is taken up,
##     its holder tips or jolts, or something moving comes to it.
##
## A body is met as POINTS ON ITS SURFACE ([method ShapeField.surface_points]) against every other solid's field, and
## every other solid's points against its own fields - so a jar's thin rim never slips between a cork's points. A move
## is taken in pieces no longer than [constant STEP_MOST] at any point of it: never over a glass wall in one step.
## Pure data: no node, nothing but numbers.

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
## HELD, how much faster than the hand a body goes back into it (meters a second): one held back by what it met comes back
## as a grip settles - and is pressed into what holds it back no harder than the hand presses. (841899: a pestle the act stood
## up through its mortar's wall was driven into the wall at the most a frame allows, 9.6 mm, and squeezed out sideways 3.4 mm
## a frame - 34 mm off the hand in a tenth of a second, a jolt.)
const CATCH_UP := 0.06
## Passes over its contacts a piece of a move: each finds them afresh.
const PASSES := 2
## How much of the speed it met something with a body keeps going back off it: a pushed-out body flies off only as fast as
## it came in times this (positional pushes alone had spun a rod landing on the table up to 47 radians a second).
const BOUNCE := 0.15
## HELD FIRM: a held body turns about what it meets this share as freely as a loose one does - a hand holds it.
const GRIP := 0.2
## Gravity; the fastest a body goes (meters a second); a loose body's turning dies this share a second.
const GRAVITY := Vector3(0.0, -9.81, 0.0)
const V_MOST := 3.0
const SPIN_DAMP := 0.6
## AT REST: touching something and slower than SETTLE at any point (meters a second), it loses SETTLE_LOSS of its speed a
## substep - positional contacts leave a resting body trembling, never still enough to sleep (as [constant
## Particles.SETTLE]). SLEEP: slower than this at any point of it over a frame (meters a second) for this long (seconds),
## touching something - OR, touching something, none of it further than SLEEP_DRIFT (meters) from where it was this long
## ago: TREMBLING IN PLACE IS AT REST (841899: the ladle laid on its rest, held up at its bowl and its handle's end, rocked
## a hair's width each way, its far end faster than SLEEP_SPEED, and kept the bake reckoning every frame in full for
## fifty-five seconds); WAKING: its holder tipped this far since (radians) or jolted this hard (meters a second, squared),
## or a moving solid this near (meters).
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
	# ITS SURFACE, SPREAD EVENLY: [constant POINTS] of them, each the furthest from those taken before - its corners and edges
	# first (every k-th point of the surface's own grid had left a box's edges out, and it rested on one, 4 mm into the table;
	# one a cell had kept a side's point for the bottom's)
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
		"hup": host_xf.basis.y.normalized() if host >= 0 else Vector3.UP, "touch": host, "moved": false})
	return bodies.size() - 1


## Body [param bi]'s pose now: the rigid motion that carries it from where it was built to where it is.
func motion(bi: int) -> Transform3D:
	return _motion(bodies[bi])


static func _motion(b: Dictionary) -> Transform3D:
	var r := Basis(b["q"] as Quaternion)
	return Transform3D(r, (b["c"] as Vector3) - r * (b["c0"] as Vector3))


static func _set_motion(b: Dictionary, d: Transform3D) -> void:
	b["q"] = d.basis.get_rotation_quaternion()
	b["c"] = d * (b["c0"] as Vector3)


## How far a body must go in a frame (meters, at any point) to stir what lies loose near it ([method
## TablePhysics._wake_near_loose]): settling, it does not - an awake pestle trembling on the bench had woken every loose
## thing round it, until the solver held no more and a jar's lumps could not be bodies.
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

## ONE FRAME of [param dt] seconds among [param world]'s `solids` (each with its `xf`, `xf0`, `inv`, `field`, `wbox`,
## `moving`, `mu`, `on`) over the table's `top`: each body held, falling or asleep on its holder - and its own solids put
## where it went.
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


## A HELD BODY: the frame's way to where the hand has it, in its pieces ([method _go]), meeting what it is moved into -
## its speed the hand's as it goes, so let go it goes on as the hand had it going.
func _held_frame(b: Dictionary, dt: float) -> void:
	var near := _near(b, (b["held"] as Transform3D))
	b["touch"] = -1
	b["by"] = -1
	var from := _motion(b)
	var hand: Transform3D = b["held_from"] if b["held_from"] != null else from
	_go(b, from, b["held"], near, true, dt, _span(b, hand, b["held"]) + CATCH_UP * dt)
	_speeds(b, from, dt)
	b["still"] = 0.0
	b["anchor"] = _motion(b)
	b["host"] = -1


## A LOOSE BODY: gravity, then its contacts, a substep at a time; still long enough, it sleeps on what holds it up.
func _loose_frame(b: Dictionary, dt: float) -> void:
	var h := dt / float(SUBSTEPS)
	# WHAT HOLDS IT UP CARRIES IT: one settling on or in what is being moved goes with it, and only how it moves there is
	# reckoned (a pestle let go in its mortar as the mortar was picked up had been left in the air, and fell to the table)
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
	var fastest := _way_from(b, begun) / dt
	if touched and (fastest < SLEEP_SPEED or _way_from(b, b["anchor"]) < SLEEP_DRIFT):
		b["still"] = float(b["still"]) + dt
		if float(b["still"]) >= SLEEP_AFTER:
			_sleep(b)
	else:
		b["still"] = 0.0
		b["anchor"] = _motion(b)


## AN ASLEEP BODY goes where its holder goes - and wakes as its holder tips past [constant WAKE_TILT] or jolts past
## [constant WAKE_JOLT], or as a moving solid comes to it.
func _asleep_frame(b: Dictionary, stirring: Array) -> void:
	var hs := int(b["host"])
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
	# ...stirring, not settling: two bodies trembling at rest side by side (a jar and its stopper) woke each other forever
	for e in stirring:
		var si := int((e as Array)[0])
		if si == hs or own.has(si) or (hb >= 0 and int((_solids[si] as Dictionary).get("body", -1)) == hb):
			continue
		# ...nor by what rests in it or on it, which it never meets ([method _near]): a pestle grinding in its mortar kept the
		# mortar awake the whole grind
		var ob := int((_solids[si] as Dictionary).get("body", -1))
		if ob >= 0 and _yields_to(bodies[ob], b, own):
			continue
		if ((e as Array)[1] as AABB).intersects(box):
			_wake(b, null)
			return


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


## Whether solid [param si] may hold body [param b] up - be what it sleeps on and is carried by: never a lighter thing in a
## hand (841899's frankincense jar, set down as its cork was taken up, slept on the cork and went up with it).
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


## THE SPEED A PUSH GAVE IT, put right (Muller et al. 2020's velocity pass): at each point it met something this substep, one
## after another, its speed along the way out is set to [constant BOUNCE] of how fast it came in there ([param v0], [param w0],
## its speeds before) - none, coming in slower than a substep of gravity gives it, so what rests does not tremble - and its
## slide there slowed by kinetic friction as much as that changed. (Pushed out alone, a rod landing on the table spun up to
## 47 radians a second, and one resting on it trembled awake for ever.)
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


## BODY [param b] FROM [param from] TOWARD [param want], in pieces short enough never to step over a thin wall, each
## kept out of every solid near it ([param near], [method _near]) - [param held]: firm in a hand.
func _go(b: Dictionary, from: Transform3D, want: Transform3D, near: Dictionary, held: bool, h: float, pace := INF) -> void:
	var way := _span(b, from, want)
	# ...no further a frame than its pieces at their longest: a hand that has gone on past what stopped it is followed a step at
	# a time, never in one stride deep into what is in the way - and, held, no further than [param pace]
	var most := minf(STEP_MOST * float(PIECES_MOST), pace)
	if way > most:
		want = _between(b, from, want, most / way)
		way = most
	var pieces := clampi(int(ceil(way / STEP_MOST)), 1, PIECES_MOST)
	for k in pieces:
		# ...each piece on from where the last one was kept - never from the frame's start along a straight line, which threw
		# away what had stopped it (a rod held against a block's face was put back 5 cm into it on the last piece)
		var prev := _motion(b)
		_set_motion(b, _between(b, prev, want, 1.0 / float(pieces - k)))
		# CLEAR OF EVERYTHING by more than it has gone since it was last looked at: nothing to meet
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
		# ...never what hangs from it and goes where it goes: a balance's beam on its hinge, carried with its base, had held the
		# base back (841899's balance, 47 cm short of where its act took it)
		if own.has(si) or (sd.get("bodies", []) as Array).has(int(b["bi"])):
			continue
		if not bool(sd.get("on", true)) or not (sd["wbox"] as AABB).intersects(reach):
			gap_least = minf(gap_least, _gap(here, sd["wbox"]))
			continue
		# ...NEVER WHAT RESTS IN IT OR ON IT, held or not: what a thing holds goes with it and
		# never shoves it (841899: a mortar carried with its pestle lying in it was held back by the pestle, left on the table
		# and tipped over; let go, the pestle leaning in it crept it across the table), NOR A LIGHTER THING IN A HAND: a pestle
		# ground round its bowl never shoves the mortar. Anything else it meets, a vial a ladle falls on among them (a ladle
		# dropped through one when all that weighed less was passed through) - and what another hand holds at once: two held
		# bodies had passed through each other, and 841899's cork, carried with its jar, ended inside the jar's wall and fell in
		if sd.has("body"):
			var ob: Dictionary = bodies[int(sd["body"])]
			if _yields_to(ob, b, own):
				continue
		out.append(si)
		# ...one moving: how clear it was is no longer known
		if bool(sd.get("moving", false)):
			b["clear"] = 0.0
	# ...and, let go, the loose things' spheres in its reach, which may hold it up - never what lies in it or on it: what a
	# vessel holds cannot lift it (841899: the frankincense ground in the mortar, pressed into its floor by the pestle, pushed
	# the mortar up and about, and it slid across the table)
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
		if not sd.has("wpts") or not (sd["wpts_xf"] as Transform3D).is_equal_approx(xf):
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


## KEPT OUT of the solids [param near] and the table's top, in [constant PASSES] passes: each of its points in a solid, and
## each of a solid's points in it, pushed out along the way out, its slide along it since [param prev] held by friction -
## every contact of a pass reckoned against the same pose and their corrections AVERAGED (one after another, each turned
## the body against the last: a rod landing flat on the table spun up to 20 radians a second and came to rest on an edge).
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
		# ITS POINTS IN THE SOLIDS, and in the table's top
		var faces: Dictionary = b["faces"]
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
				if not wb.grow(SLACK).has_point(p):
					if pass_i == 0:
						nearest = minf(nearest, _outside(wb, p))
					continue
				var local := (sd["inv"] as Transform3D) * p
				var f: Vector4 = (sd["field"] as ShapeField).sample(local)
				if pass_i == 0:
					nearest = minf(nearest, f.x)
				var key := j * 4096 + si
				var xf: Transform3D = sd["xf"]
				var sv := (xf * local - (sd["xf0"] as Transform3D) * local) / float(SUBSTEPS)
				# ...STILL IN BY THE FACE IT CAME IN BY: kept until it is back in front of that face or clear of the wall - a let-go
				# body's contacts are put right only in their mean, and a point left a millimeter in a 3 mm wall, asked again from
				# inside, was put out through the far side; and kept even there, the wall's far side no way out
				if faces.has(key):
					var face: Array = faces[key]
					var past := float(face[1]) - p.dot(face[0] as Vector3)
					# ...out of the wall, only near where it came in - out its far side; a face is a plane, and a cup's foot that
					# grazed a bowl's rim on its way in was held up by the rim's plane over the water (841899's ladle, a dip)
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
				# A STILL WALL IS MET ON THE SIDE IT WAS COME TO FROM: a point outside it at the piece's start is pushed back
				# out where it came in - past a thin wall's middle, the wall's own way out is through its far side (841899:
				# the ladle let go in its pot stood 2 mm in its copper floor and sank through it, 2 cm in half a second)
				if not bool(sd.get("moving", false)):
					var field: ShapeField = sd["field"]
					var inv: Transform3D = sd["inv"]
					var pp := prev * q
					# (out of it as far as a contact goes - within the slack it stands in what it rests on, and a point resting
					# there had kept losing its face and never been given one again)
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
		# ...AND THE SOLIDS' POINTS IN IT: a rim thinner than the gaps between its points - each first against its own
		# solids' boxes, where they stand now
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
					# ...A THIN WALL OF ITS OWN came onto a still point from one side: out that side (a ladle's bowl over a floor)
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
		# ...AND, LET GO, THE LOOSE THINGS UNDER IT, as solids: each sphere it has sunk into holds it up (a stopper fallen into a
		# jar of tears had sunk through them, squeezing them against the glass, awake to the end of the show)
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
		# ...WHAT HOLDS IT UP is what it meets from below, never what pushes it from the side or above: the ladle lifted past
		# 841899's cork had been what the cork touched last, so it slept on the ladle and went round with every stir
		for hit in hits:
			var ny := ((hit as Array)[1] as Vector3).y
			if ny > met_up:
				met_up = ny
				b["by"] = int((hit as Array)[5])
			if ny > up_most and ny > HELD_UP:
				up_most = ny
				b["touch"] = int((hit as Array)[5])
	# THE TABLE'S TOP HOLDS, WHATEVER ELSE PUSHES: the mean of a let-go body's contacts puts right only their mean depth, and
	# one wedged in another (841899's stopper, fallen sideways into its jar) had been pushed through the jar's floor and 1.3 mm
	# into the table, and the jar 2.2 mm into it after
	if not held:
		var d := _motion(b)
		var under := 0.0
		for q in pts:
			under = maxf(under, _top - (d * q).y)
		if under > 0.0:
			b["c"] = (b["c"] as Vector3) + Vector3.UP * under
		# ...AND SO DOES A STILL WALL IT CAME INTO: what the mean left past the face a point came in by is put out along it,
		# the deepest first (841899: the ladle let go leaning in its pot, its weight on its bowl's edge, worked a point a little
		# deeper each step into the 3 mm copper floor until it came out under it)
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
				# ...only while it is in that wall still: a face is a plane, and one kept past its point's going out would push
				# the body anywhere
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
	# HOW CLEAR IT WAS of everything, less the gaps between its points - meeting nothing, it need not be looked at again
	# until it has gone that far ([method _go]). EVERYTHING: what it was not looked at against is as near as their boxes
	# (`far`). (841899 played live: the ladle, carried high over the bench, was clear of the table's top by 18.5 cm and of
	# nothing else it had been looked at against - so it was not looked at again until it had gone 18.5 cm, and let go
	# standing in its pot it fell through the pot's floor and the brazier to the table.)
	nearest = minf(nearest, float(near_d.get("far", INF)))
	b["clear"] = 0.0 if met else maxf(nearest - float(b["gap"]) - SLACK, 0.0)
	b["clear_from"] = _motion(b)


## How far [param p] lies outside box [param box] (meters; 0 inside it).
static func _outside(box: AABB, p: Vector3) -> float:
	var q := Vector3(maxf(maxf(box.position.x - p.x, p.x - box.end.x), 0.0), maxf(maxf(box.position.y - p.y, p.y - box.end.y), 0.0),
		maxf(maxf(box.position.z - p.z, p.z - box.end.z), 0.0))
	return q.length()


## Body [param b] kept out by contacts [param hits] (`[point, way out, how deep, what met it moved, friction, solid, its own
## point as built or the solid's point, -1 or the body's solid it is in]`): each a positional correction by its generalized
## inverse mass there - firm in a hand when [param held] - its slide since [param prev] held by friction, static or kinetic;
## LET GO, THEIR MEAN applied, each reckoned against the same pose (one after another, each turned the body against the last,
## and a body at rest trembled awake); HELD, each ALONE, deepest first, measured again where the body is now - a hand drives
## what it holds into what is in the way, and the mean puts right only the mean depth: a rod tilted against a block, its
## corners 1 and 5 mm in, had stood 2.5 mm in it.
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


## Contact [param h] measured again where body [param b] is now: `[how deep, way out, where]` - its own point against what
## it met (or the table's top), or the solid's point against the body's own solid it was in.
func _depth_now(b: Dictionary, h: Array) -> Array:
	var si := int(h[5])
	var k := int(h[7])
	var d := _motion(b)
	# ...AGAINST THE FACE IT CAME IN BY, where it kept one ([method _contacts]): a thin wall's own way out past its middle is
	# through its far side, and a held ladle's bowl, its contacts measured again one by one, was driven through a 3 mm floor
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
	# STILL, AND STILL A FRAME AGO: nothing of it to put anywhere
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
		# ...and whether it moves enough to wake what sleeps by it: held, or going somewhere ([constant STIRS]) - and whether it
		# presses what it meets hard enough to break it: only as a hand drives it ([member Particles._np])
		sd["stirs"] = bool(sd["moving"]) and (b["held"] != null or float(b.get("stir", 0.0)) >= STIRS)
		sd["presses"] = b["held"] != null
		sd["dt"] = dt
		if bool(sd["moving"]) or not (sd["xf0"] as Transform3D).is_equal_approx(sd["xf00"]):
			sd["inv"] = xf.affine_inverse()
			sd["wbox"] = (xf * (sd["box"] as AABB)).grow(0.001)
			# ...HELD, IT JOLTS NOTHING: a hand carries smoothly, and the pushes of what it met as it was taken up are no jolt to
			# what is in it (a jar's lumps had been woken as it was lifted, and left behind in the air)
			sd["jolt"] = 0.0 if b["held"] != null else Particles.jolt_of((xf.origin - 2.0 * (sd["xf0"] as Transform3D).origin + (sd["xf00"] as Transform3D).origin) / (dt * dt))
		else:
			sd["jolt"] = 0.0


# --- kept -------------------------------------------------------------------------------------------------

## Every body as it stands, for a bake begun again from here ([method restore]) - ALL OF IT a frame reads: how far each went
## last frame (`stir`) wakes what lies loose round it, and a bake begun again with it gone woke none (841899's jar of snow,
## taken up in the middle of its carry, spilled its grains 30 cm from where a bake from the start put them).
func snapshot() -> Array:
	var out: Array = []
	for b in bodies:
		var d: Dictionary = {}
		for k in ["c", "q", "v", "w", "held", "held_from", "asleep", "still", "anchor", "host", "hrel", "hup", "touch", "moved", "clear", "clear_from",
				"stir", "was_moved"]:
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
