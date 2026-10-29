extends RefCounted
class_name Particles

## Particles - GRAINS AND LOOSE THINGS, stepped (next/table_physics.md, "Grains and loose things"): POSITION BASED
## DYNAMICS as the unified particle solver does it (Macklin, Muller, Chentanez and Kim, SIGGRAPH 2014) - everything
## is spheres; a grain is one, with friction; a loose thing is a few held to their shape by SHAPE MATCHING (Muller et
## al., SIGGRAPH 2005); one pass of the constraints a substep, more substeps rather than more passes (Macklin et al.,
## "Small Steps in Physics Simulation", 2019). Pure data: no node, no tree, nothing but numbers - the bake runs it on a
## thread of its own ([TablePhysics]) and a preview on the thread it is built on.
##
## The user, 2026-10-28: the snow should be "particles, or voxels, or sand-like ... With physics and collision"; the
## shell's crystals should "move and tumble ... fall into the cauldron"; and in the mortar "I would have expected the
## grinding to destroy those things". So:
##
##   - WHAT RESTS COSTS NOTHING: a particle still for [constant SLEEP_AFTER] sleeps on its HOST, the solid it lies in,
##     and goes where its host goes ([method follow]); it wakes when its host tips or jolts, when another moving solid
##     comes near it, or when something awake strikes it ([method wake_near], [method wake_host]).
##   - EVERY SOLID IS A FIELD ([ShapeField]): a particle in one is pushed out along its way out, and its slide along it
##     held by friction against the solid's own motion - a tipped dish's stones slide, a carried one's ride.
##   - IN A LIQUID a particle is slowed, lifted by what it displaces (lighter than the liquid, it floats), carried round
##     by its swirl, and - if its matter dissolves - shrinks away; it rings the surface as it enters ([member events]).
##   - SQUEEZED BETWEEN A MOVING SOLID AND WHAT HOLDS IT, a particle is damaged; past its matter's strength a loose
##     thing splits along its middle, its halves still rigid, and a lone piece into two of half its volume, down to
##     [constant POWDER] - a bonded-particle model's bonds breaking under load (Potyondy and Cundall, 2004).

## The most particles at once, the substeps a frame, gravity, the fastest a particle may go (meters a second).
const MOST := 900
const SUBSTEPS := 4
const GRAVITY := Vector3(0.0, -9.81, 0.0)
const V_MOST := 2.5
## SLEEP: slower than this (meters a second) for this long (seconds), touching something, and it sleeps on its host.
const SLEEP_SPEED := 0.008
const SLEEP_AFTER := 0.25
## WAKING: a host tipped this far since its sleepers slept (radians), or jolted this hard (meters a second, squared);
## a moving solid this near (meters); struck this hard (a share of its radius pushed in a substep).
const WAKE_TILT := 0.12
const WAKE_JOLT := 4.0
const WAKE_NEAR := 0.003
const WAKE_PUSH := 0.15
## FRICTION (static, kinetic) against a solid and between particles, unless the matter says.
const FRICTION := Vector2(0.65, 0.45)
## IN A LIQUID: how hard it drags (a particle of density rho and radius r relaxes to the liquid's motion at
## DRAG / (rho r) a second), and how dense a liquid is (grams a cubic centimeter).
const DRAG := 0.45
const LIQUID_DENSITY := 1.0
## BREAKING: the finest a piece is ground (meters), how small a dissolving grain is gone at (meters), and how much damage a
## strength of 1 withstands (seconds of being squeezed by its own radius).
const POWDER := 0.0011
const GONE := 0.0003
const DAMAGE := 0.05
## PUSHED APART NO FASTER THAN THIS (meters a second): two spheres found overlapping part a little each substep, never all
## at once - all at once, a heap's grains shot one another out through a jar's wall. And a move is looked along in
## steps no longer than half of THIN (meters): a glass wall a couple of millimeters thick is never stepped over.
const PART_MOST := 0.25
## A HEAP COMES TO REST: a sphere held up by something and slower than this (meters a second) loses this share of its
## speed a substep - one pass of the constraints leaves a heap trembling, never still enough to sleep.
const SETTLE := Vector2(0.04, 0.3)
const THIN := 0.0016
## A body's spheres: none smaller than this nor larger (meters), and no more than this many.
const SPHERE := Vector2(0.0012, 0.007)
const BODY_MOST := 18
## The spatial hash's size (a power of two).
const HASH := 8192

var n := 0
var x := PackedVector3Array()          # where each is (the table's space, meters) - a sleeper's kept where its host has it
var v := PackedVector3Array()
var r := PackedFloat32Array()
var r0 := PackedFloat32Array()         # its radius as it was made
var w := PackedFloat32Array()          # inverse mass
var mat := PackedInt32Array()          # its matter (a row of [member matter])
var body := PackedInt32Array()         # the body it is a sphere of, or -1
var alive := PackedByteArray()
var asleep := PackedByteArray()
var still := PackedFloat32Array()
var host := PackedInt32Array()         # the solid a sleeper rides, or -1 (the table, which never moves)
var hloc := PackedVector3Array()       # ...its place in the host's space
var hup := PackedVector3Array()        # ...and the host's up as it fell asleep
var damage := PackedFloat32Array()
var wet := PackedInt32Array()          # the liquid it is in, or -1
var owner := PackedInt32Array()        # what made it ([TablePhysics]: a grains part's number, or -1 for a body's)
var touch := PackedInt32Array()        # the solid it last met this frame, or -1
var mus := PackedFloat32Array()        # its matter's friction, static and kinetic, its density and how fast it dissolves
var muk := PackedFloat32Array()
var rho := PackedFloat32Array()
var dis := PackedFloat32Array()
var _hold := PackedByteArray()         # this substep: held by the work (kinematic)
var _pressed := PackedFloat32Array()   # this substep: how hard a moving solid pressed it
var _held_by := PackedByteArray()      # this substep: whether something else held it from the other side
var _p := PackedVector3Array()         # predicted places this substep

## [{density, strength, dissolves, friction (Vector2)}]: what each kind of matter is ([constant Props.MATERIALS]).
var matter: Array = []
## THE LOOSE THINGS: [{ids, rest (offsets from `c0`), c0 (the middle as made), q (its turn now), c (its middle now),
## intact, held (a Transform3D the work holds it at this substep, or null), hrel (its pose in its host's space while it
## sleeps), roll}]
var bodies: Array = []
## WHAT HAPPENED this frame, for the bake to keep: [{kind ("enter", "break", "gone"), ...}]
var events: Array = []
## Whether anything moved this frame - awake, carried by a moving host, made or gone: a frame where nothing did shares the
## last one's places ([method TablePhysics._record]).
var moved := true

# the world this frame ([method step]): its solids - [{field, xf, inv, xf0 (a frame ago), box (the table's, grown), moving}]
# - and its liquids - [{vessel, xf, inv, n (the surface's up), c (its middle), axis, swirl (radians a second)}]
var _solids: Array = []
var _liquids: Array = []
var _top := 0.0
var _near := PackedInt32Array()      # the solids near what is awake this frame
var _steps := SUBSTEPS                # the substeps this frame
var _h := 0.004                       # ...and how long this one is
# the near solids this substep, unpacked: field, pose, its inverse, its pose a substep before, its box grown
var _nf: Array = []
var _nx: Array = []
var _ni: Array = []
var _n0: Array = []
var _nb: Array = []
var _nid := PackedInt32Array()
var _pi := PackedInt32Array()         # the pairs that may meet this frame ([method _find_pairs])
var _ride := PackedInt32Array()       # this frame: the moving solid whose inside each awake one is in, which carries it, or -1
var _vessels: Array = []              # [{solid, vessel}]: every inside on the table, as the world hands them
var _pj := PackedInt32Array()


## MATTER as a row: [param density] (grams a cubic centimeter), [param strength] (0 never breaks), [param dissolves]
## (seconds to dissolve in a liquid, 0 never).
func add_matter(density: float, strength: float, dissolves: float, friction := FRICTION) -> int:
	matter.append({"density": maxf(density, 0.05), "strength": maxf(strength, 0.0), "dissolves": maxf(dissolves, 0.0), "friction": friction})
	return matter.size() - 1


## A PARTICLE at [param at] (meters), [param radius] across, of matter [param m]: its number, or -1 past [constant MOST].
## It sleeps on [param on] ([param on_xf], that solid's pose) unless [param on] is -2: awake.
func add(at: Vector3, radius: float, m: int, made_by: int, on: int, on_xf := Transform3D.IDENTITY) -> int:
	var i := -1
	for k in n:
		if alive[k] == 0:
			i = k
			break
	if i < 0:
		if n >= MOST:
			return -1
		i = n
		n += 1
		# each grown by its own name: a packed array in a list is a copy of it
		x.append(Vector3.ZERO)
		v.append(Vector3.ZERO)
		hloc.append(Vector3.ZERO)
		hup.append(Vector3.UP)
		_p.append(Vector3.ZERO)
		r.append(0.0)
		r0.append(0.0)
		w.append(0.0)
		mus.append(0.0)
		muk.append(0.0)
		rho.append(1.0)
		dis.append(0.0)
		_hold.append(0)
		still.append(0.0)
		damage.append(0.0)
		_pressed.append(0.0)
		mat.append(-1)
		body.append(-1)
		host.append(-1)
		wet.append(-1)
		owner.append(-1)
		touch.append(-1)
		alive.append(0)
		asleep.append(0)
		_held_by.append(0)
	x[i] = at
	v[i] = Vector3.ZERO
	r[i] = radius
	r0[i] = radius
	var kg := float((matter[m] as Dictionary)["density"]) * 1000.0
	w[i] = 1.0 / maxf(kg * 4.0 / 3.0 * PI * radius * radius * radius, 1e-9)
	mat[i] = m
	var md: Dictionary = matter[m]
	mus[i] = (md["friction"] as Vector2).x
	muk[i] = (md["friction"] as Vector2).y
	rho[i] = float(md["density"])
	dis[i] = float(md["dissolves"])
	body[i] = -1
	alive[i] = 1
	still[i] = 0.0
	damage[i] = 0.0
	wet[i] = -1
	owner[i] = made_by
	touch[i] = -1
	if on >= -1:
		asleep[i] = 1
		host[i] = on
		hloc[i] = on_xf.affine_inverse() * at if on >= 0 else at
		hup[i] = on_xf.basis.y.normalized() if on >= 0 else Vector3.UP
	else:
		asleep[i] = 0
		host[i] = -1
	return i


## A LOOSE THING made of the spheres [param at] (meters, the table's space), each [param radius] across: its body's number.
func add_body(at: PackedVector3Array, radius: float, m: int, made_by: int, on: int, on_xf := Transform3D.IDENTITY) -> int:
	var ids := PackedInt32Array()
	for p in at:
		var i := add(p, radius, m, made_by, on, on_xf)
		if i >= 0:
			ids.append(i)
	if ids.is_empty():
		return -1
	var bi := bodies.size()
	var c := Vector3.ZERO
	for i in ids:
		c += x[i]
	c /= float(ids.size())
	var rest := PackedVector3Array()
	for i in ids:
		rest.append(x[i] - c)
		body[i] = bi
	bodies.append({"ids": ids, "rest": rest, "c0": c, "c": c, "q": Quaternion.IDENTITY, "intact": true, "held": null,
		"hrel": (on_xf.affine_inverse() * Transform3D(Basis.IDENTITY, c)) if on >= 0 else Transform3D(Basis.IDENTITY, c),
		"made_by": made_by})
	return bi


## THE POSE of body [param bi] now: what carries a point of it as it was made to where it is.
func body_pose(bi: int) -> Transform3D:
	var b: Dictionary = bodies[bi]
	return Transform3D(Basis(b["q"] as Quaternion), b["c"] as Vector3) * Transform3D(Basis.IDENTITY, -(b["c0"] as Vector3))


## Whether body [param bi] sleeps (all its spheres do).
func body_asleep(bi: int) -> bool:
	for i in (bodies[bi] as Dictionary)["ids"]:
		if alive[i] == 1 and asleep[i] == 0:
			return false
	return true


# --- the frame ------------------------------------------------------------------------------------------

## ONE FRAME of [param dt] seconds in the world [param world] (`solids`, `liquids`, `top` - see above; each solid's
## `xf0` is where it was a frame ago): the sleepers carried by their hosts, woken where something moves them, then
## [constant SUBSTEPS] steps, then what sleeps, breaks and is gone.
func step(dt: float, world: Dictionary) -> void:
	_solids = world.get("solids", [])
	_liquids = world.get("liquids", [])
	_vessels = world.get("vessels", [])
	_top = float(world.get("top", 0.0))
	events = []
	var n_was := n
	moved = false
	for i in n:
		if alive[i] == 1 and asleep[i] == 1 and host[i] >= 0 and host[i] < _solids.size() and bool((_solids[host[i]] as Dictionary).get("moving", false)):
			moved = true
			break
	follow()
	wake_host(dt)
	wake_near()
	_wet_now()
	var act := PackedInt32Array()
	for i in n:
		if alive[i] == 1 and asleep[i] == 0:
			act.append(i)
	for b in bodies:
		if (b as Dictionary)["held"] != null:
			for i in (b as Dictionary)["ids"]:
				if alive[i] == 1 and asleep[i] == 1:
					_wake(i)
					act.append(i)
	for i in act:
		touch[i] = -1
	if act.is_empty():
		moved = moved or n != n_was
		return
	moved = true
	# THE SOLIDS NEAR WHAT IS AWAKE, found once a frame: only they are met
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for i in act:
		lo = Vector3(minf(lo.x, x[i].x), minf(lo.y, x[i].y), minf(lo.z, x[i].z))
		hi = Vector3(maxf(hi.x, x[i].x), maxf(hi.y, x[i].y), maxf(hi.z, x[i].z))
	var reach := AABB(lo, hi - lo).grow(0.03 + V_MOST * dt)
	_near = PackedInt32Array()
	for si in _solids.size():
		var sd: Dictionary = _solids[si]
		if bool(sd.get("on", true)) and reach.intersects(sd["wbox"]):
			_near.append(si)
	# WHAT A MOVING INSIDE HOLDS RIDES IT: a jar's grains go where the jar goes, and only how they move in it is reckoned
	# - its wall never sweeps into them (a carried jar's thin glass had passed through its own snow)
	_ride.resize(n)
	_ride.fill(-1)
	for vd in _vessels:
		var si := int((vd as Dictionary)["solid"])
		var sd: Dictionary = _solids[si]
		if not bool(sd.get("moving", false)):
			continue
		var inv0: Transform3D = (sd["xf0"] as Transform3D).affine_inverse()
		var vs: Vessel = (vd as Dictionary)["vessel"]
		# every one in it, asleep or not: a sleeper woken part way through the frame rides from the moment it wakes
		for i in n:
			if alive[i] == 1 and _ride[i] < 0 and vs.contains(inv0 * x[i]):
				_ride[i] = si
				# ...its speed its own in it: one woken as its inside moved is at rest there, not thrown at its wall
				if still[i] < 0.0:
					v[i] = Vector3.ZERO
	# AS MANY SUBSTEPS AS THE FASTEST NEEDS: what falls fast takes all of them, what settles two - and so does a solid
	# moving through what does not ride it
	var fastest := 0.0
	var least := SPHERE.y
	for i in act:
		fastest = maxf(fastest, v[i].length())
		least = minf(least, r[i])
	for si in _near:
		var sd: Dictionary = _solids[si]
		if bool(sd.get("moving", false)):
			var c := (sd["box"] as AABB).get_center()
			fastest = maxf(fastest, ((sd["xf"] as Transform3D) * c - (sd["xf0"] as Transform3D) * c).length() / dt + (sd["box"] as AABB).size.length() * 0.5 \
				* (sd["xf"] as Transform3D).basis.get_rotation_quaternion().angle_to((sd["xf0"] as Transform3D).basis.get_rotation_quaternion()) / dt)
	var steps := clampi(int(ceil(fastest * dt / (0.7 * least))), 2, SUBSTEPS)
	_steps = steps
	# who may meet whom, once for the frame: as far apart as the fastest can close in it, at most a sphere's width
	for i in n:
		if alive[i] == 1 and asleep[i] == 1:
			_p[i] = x[i]
	_find_pairs(act, clampf(fastest * dt * 1.2, least * 0.3, SPHERE.y))
	var h := dt / float(steps)
	var inact := PackedByteArray()
	inact.resize(n)
	for i in act:
		inact[i] = 1
	for s in steps:
		var a := float(s + 1) / float(steps)
		_substep(h, a, act, world)
		# a woken sleeper (or one made this step) joins at once
		if inact.size() < n:
			inact.resize(n)
		for i in n:
			if alive[i] == 1 and asleep[i] == 0 and inact[i] == 0:
				act.append(i)
				inact[i] = 1
	_settle(dt, act)
	_break()
	follow(true)


## THE SLEEPERS GO WHERE THEIR HOSTS GO: each one's place, and each sleeping body's pose, from its host as it was as the
## frame began ([param end] false: the substeps carry them on with it, as they carry what is awake in it) or as it ends.
func follow(end := false) -> void:
	var key := "xf" if end else "xf0"
	for i in n:
		if alive[i] == 1 and asleep[i] == 1 and host[i] >= 0 and host[i] < _solids.size():
			x[i] = ((_solids[host[i]] as Dictionary)[key] as Transform3D) * hloc[i]
	for bi in bodies.size():
		var b: Dictionary = bodies[bi]
		if not body_asleep(bi):
			continue
		var ids: PackedInt32Array = b["ids"]
		var hs := host[ids[0]] if not ids.is_empty() else -1
		if hs >= 0 and hs < _solids.size():
			var t: Transform3D = ((_solids[hs] as Dictionary)[key] as Transform3D) * (b["hrel"] as Transform3D)
			b["c"] = t.origin
			b["q"] = t.basis.get_rotation_quaternion()


## A SLEEPER WAKES as its host tips or jolts: tipped past [constant WAKE_TILT] since it fell asleep, or moved harder than
## [constant WAKE_JOLT] (its `jolt`, the bake's).
func wake_host(_dt: float) -> void:
	for i in n:
		if alive[i] == 0 or asleep[i] == 0 or host[i] < 0 or host[i] >= _solids.size():
			continue
		var s: Dictionary = _solids[host[i]]
		if not bool(s.get("moving", false)):
			continue
		var up := (s["xf"] as Transform3D).basis.y.normalized()
		if up.angle_to(hup[i]) > WAKE_TILT or float(s.get("jolt", 0.0)) > WAKE_JOLT:
			_wake_body_of(i)


## A SLEEPER WAKES as another moving solid comes near it.
func wake_near() -> void:
	for si in _solids.size():
		var s: Dictionary = _solids[si]
		if not bool(s.get("moving", false)):
			continue
		var box: AABB = (s["wbox"] as AABB).grow(SPHERE.y + WAKE_NEAR)
		var inv: Transform3D = s["inv"]
		var f: ShapeField = s["field"]
		for i in n:
			if alive[i] == 0 or asleep[i] == 0 or host[i] == si:
				continue
			if not box.has_point(x[i]):
				continue
			if f.sample(inv * x[i]).x < r[i] + WAKE_NEAR:
				_wake_body_of(i)


func _wake_body_of(i: int) -> void:
	if body[i] >= 0:
		for k in (bodies[body[i]] as Dictionary)["ids"]:
			_wake(k)
	else:
		_wake(i)


## Particle [param i] woken: moving as its host's point under it moves.
func _wake(i: int) -> void:
	if asleep[i] == 0:
		return
	asleep[i] = 0
	# just woken: -1 until it is known whether it rides what it is in ([method step]) - one already known to is at rest in it
	still[i] = -1.0
	v[i] = Vector3.ZERO
	if i < _ride.size() and _ride[i] >= 0:
		host[i] = -1
		return
	if host[i] >= 0 and host[i] < _solids.size():
		var s: Dictionary = _solids[host[i]]
		var dt := float(s.get("dt", 1.0 / 60.0))
		var then: Transform3D = s["xf0"]
		v[i] = ((s["xf"] as Transform3D) * hloc[i] - then * hloc[i]) / maxf(dt, 1e-4)
	host[i] = -1


## Which liquid each awake particle is in, now: entering one is said ([member events]).
func _wet_now() -> void:
	for i in n:
		if alive[i] == 0 or asleep[i] == 1:
			continue
		var was := wet[i]
		wet[i] = _liquid_at(x[i], r[i])
		if wet[i] >= 0 and was != wet[i]:
			var l: Dictionary = _liquids[wet[i]]
			var at := x[i] - (l["n"] as Vector3) * (x[i] - (l["c"] as Vector3)).dot(l["n"] as Vector3)
			events.append({"kind": "enter", "liquid": wet[i], "at": at, "strength": v[i].length() / maxf(w[i], 1e-12), "i": i})


## The liquid [param p] (a sphere of radius [param rad]) is in, or -1: inside a vessel's inside, below its surface.
func _liquid_at(p: Vector3, rad: float) -> int:
	for li in _liquids.size():
		var l: Dictionary = _liquids[li]
		if float(l.get("volume", 0.0)) <= 1e-9:
			continue
		if (p - (l["c"] as Vector3)).dot(l["n"] as Vector3) > rad:
			continue
		if ((l["vessel"] as Vessel).contains((l["inv"] as Transform3D) * p)):
			return li
	return -1


## ONE SUBSTEP of [param h] seconds, [param a] of the way through the frame.
func _substep(h: float, a: float, act: PackedInt32Array, _world: Dictionary) -> void:
	_h = h
	# each near solid where it is this far through the frame, and where it was a substep before
	_nf = []
	_nx = []
	_ni = []
	_n0 = []
	_nb = []
	_nid = PackedInt32Array()
	for si in _near:
		var sd: Dictionary = _solids[si]
		_nid.append(si)
		_nf.append(sd["field"])
		_nb.append((sd["wbox"] as AABB).grow(SPHERE.y))
		if bool(sd.get("moving", false)):
			var x1: Transform3D = (sd["xf0"] as Transform3D).interpolate_with(sd["xf"], a)
			_nx.append(x1)
			_ni.append(x1.affine_inverse())
			_n0.append((sd["xf0"] as Transform3D).interpolate_with(sd["xf"], a - 1.0 / float(_steps)))
		else:
			_nx.append(sd["xf"])
			_ni.append(sd["inv"])
			_n0.append(sd["xf"])
	# WHAT THE WORK HOLDS this substep
	_hold.fill(0)
	for b in bodies:
		if (b as Dictionary)["held"] != null:
			for i in (b as Dictionary)["ids"]:
				_hold[i] = 1
	# CARRIED BY WHAT HOLDS THEM: a sleeper with its host, where its host is now - and a rider moved with its inside over
	# the substep, its speed its own in it
	var hosts := {}
	for i in n:
		if alive[i] == 0 or asleep[i] == 0 or host[i] < 0:
			continue
		var hs := host[i]
		if not hosts.has(hs):
			var hd: Dictionary = _solids[hs]
			hosts[hs] = (hd["xf0"] as Transform3D).interpolate_with(hd["xf"], a) if bool(hd.get("moving", false)) else null
		if hosts[hs] != null:
			x[i] = (hosts[hs] as Transform3D) * hloc[i]
	for i in act:
		if asleep[i] == 1:
			continue
		var ci := _ride[i] if i < _ride.size() else -1
		if ci < 0:
			continue
		var c := _nid.find(ci)
		if c < 0:
			continue
		var x0c: Transform3D = _n0[c]
		var x1c: Transform3D = _nx[c]
		x[i] = x1c * (x0c.affine_inverse() * x[i])
	# GRAVITY, and in a liquid what it displaces, its drag and its swirl
	for i in act:
		_pressed[i] = 0.0
		_held_by[i] = 0
		var vi := v[i] + GRAVITY * h
		if wet[i] >= 0:
			var l: Dictionary = _liquids[wet[i]]
			var nn: Vector3 = l["n"]
			var below := -(x[i] - (l["c"] as Vector3)).dot(nn)
			var f := clampf((below + r[i]) / (2.0 * r[i]), 0.0, 1.0)
			vi -= GRAVITY * h * (f * LIQUID_DENSITY / rho[i])
			var rel := x[i] - (l["axis"] as Vector3)
			var vl := Vector3(-rel.z, 0.0, rel.x) * float(l["swirl"])
			var k := DRAG * f / maxf(rho[i] * r[i], 1e-5)
			vi = vl + (vi - vl) * exp(-k * h)
			if dis[i] > 0.0 and f > 0.0:
				r[i] = maxf(r[i] - r0[i] * h * f / dis[i], 0.0)
				if r[i] < GONE:
					_kill(i)
					continue
		_p[i] = x[i] + vi * h
	# A HELD THING goes where the work holds it, and pushes what is in its way
	for b in bodies:
		var bd: Dictionary = b
		if bd["held"] == null:
			continue
		var t: Transform3D = (bd["held_from"] as Transform3D).interpolate_with(bd["held"], a)
		var ids: PackedInt32Array = bd["ids"]
		var rest: PackedVector3Array = bd["rest"]
		var c0: Vector3 = bd["c0"]
		for k in ids.size():
			_p[ids[k]] = t * (c0 + rest[k])
	# KEPT OUT OF ONE ANOTHER - and then, last, OUT OF EVERY SOLID, with friction against its motion: what a substep ends
	# with is never inside a solid (the other way round, a heap's weight had pressed its bottom grains through a jar's floor)
	_contacts()
	for i in act:
		if alive[i] == 0 or _hold[i] == 1:
			continue
		_solid_pass(i)
	# THE LOOSE THINGS HOLD THEIR SHAPES - those awake
	for bi in bodies.size():
		var bd: Dictionary = bodies[bi]
		if bd["held"] == null and not body_asleep(bi):
			_match(bi)
	# THEIR SPEEDS, from where they went
	for i in act:
		if alive[i] == 0:
			continue
		var vi := (_p[i] - x[i]) / h
		var sp := vi.length()
		if sp > V_MOST:
			vi *= V_MOST / sp
		elif sp < SETTLE.x and _held_by[i] == 1:
			vi *= 1.0 - SETTLE.y
		v[i] = vi
		x[i] = _p[i]
		if _pressed[i] > 0.0 and _held_by[i] == 1:
			damage[i] += _pressed[i] / maxf(r[i], 1e-5) * h
	# a held body's pose is the work's
	for b in bodies:
		var bd: Dictionary = b
		if bd["held"] != null:
			var t: Transform3D = (bd["held_from"] as Transform3D).interpolate_with(bd["held"], a)
			bd["c"] = t * (bd["c0"] as Vector3)
			bd["q"] = t.basis.get_rotation_quaternion()


func _is_held(i: int) -> bool:
	return body[i] >= 0 and (bodies[body[i]] as Dictionary)["held"] != null


## Particle [param i] kept out of the solids near it (and the table's top), its slide along each held by friction against
## that solid's own motion over the substep - and a fast one stopped where it first meets one, not passed through it.
func _solid_pass(i: int) -> void:
	var rad := r[i]
	var from := x[i]
	var p := _p[i]
	# A FAST ONE IS TAKEN IN PIECES: the first piece that meets a solid is where it stops
	var way := p - from
	var pieces := mini(int(ceil(way.length() / minf(rad, THIN * 0.5))), 12)
	if pieces > 1:
		for k in range(1, pieces):
			var q := from + way * (float(k) / float(pieces))
			if _deepest(q) < 0.0:
				p = from + way * (float(k - 1) / float(pieces))
				break
	var ms := mus[i]
	var mk := muk[i]
	for c in _nid.size():
		if not (_nb[c] as AABB).has_point(p):
			continue
		var inv: Transform3D = _ni[c]
		var local := inv * p
		var f: Vector4 = (_nf[c] as ShapeField).sample(local)
		if f.x >= rad:
			continue
		var xf: Transform3D = _nx[c]
		var nn := (xf.basis * Vector3(f.y, f.z, f.w)).normalized()
		var pen := rad - f.x
		p += nn * pen
		touch[i] = _nid[c]
		# the solid's own motion at that point over the substep - none, to what rides in it
		var sv := Vector3.ZERO if (i < _ride.size() and _ride[i] == _nid[c]) else xf * local - (_n0[c] as Transform3D) * local
		if sv.length_squared() > 1e-10:
			_pressed[i] += pen
		else:
			_held_by[i] = 1
		var d := (p - from) - sv
		var t := d - nn * d.dot(nn)
		var lt := t.length()
		if lt > 1e-9:
			p -= t if lt < ms * pen else t * minf(mk * pen / lt, 1.0)
	if p.y < _top + rad:
		var pen := _top + rad - p.y
		p.y = _top + rad
		_held_by[i] = 1
		var t := Vector3(p.x - from.x, 0.0, p.z - from.z)
		var lt := t.length()
		if lt > 1e-9:
			p -= t if lt < ms * pen else t * minf(mk * pen / lt, 1.0)
	_p[i] = p


## How far [param q] is inside the nearest solid: less than 0 where it is in one.
func _deepest(q: Vector3) -> float:
	var best := INF
	for c in _nid.size():
		if not (_nb[c] as AABB).has_point(q):
			continue
		best = minf(best, (_nf[c] as ShapeField).sample((_ni[c] as Transform3D) * q).x)
	return best


## WHO MAY MEET WHOM THIS FRAME: every pair of spheres of different things within their two radii and [param margin] -
## the awake among themselves and with the sleepers near them - found once a frame through a spatial hash whose cells
## are twice the widest reach, so a sphere's neighbors are all in the 8 cells nearest it (a substep then only looks at
## these pairs: Verlet's list).
func _find_pairs(act: PackedInt32Array, margin: float) -> void:
	_pi = PackedInt32Array()
	_pj = PackedInt32Array()
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	var rmax := 0.0
	for i in act:
		if alive[i] == 0:
			continue
		var q := x[i]
		lo = Vector3(minf(lo.x, q.x), minf(lo.y, q.y), minf(lo.z, q.z))
		hi = Vector3(maxf(hi.x, q.x), maxf(hi.y, q.y), maxf(hi.z, q.z))
		rmax = maxf(rmax, r[i])
	if rmax <= 0.0:
		return
	var reach := AABB(lo, hi - lo).grow(rmax * 2.0 + SPHERE.y + margin)
	var who := PackedInt32Array()
	for i in act:
		if alive[i] == 1:
			who.append(i)
	for i in n:
		if alive[i] == 1 and asleep[i] == 1 and reach.has_point(x[i]):
			who.append(i)
			rmax = maxf(rmax, r[i])
	var cell := (rmax * 2.0 + margin) * 2.0
	var inv_cell := 1.0 / cell
	var count := PackedInt32Array()
	count.resize(HASH + 1)
	var key := PackedInt32Array()
	key.resize(who.size())
	for k in who.size():
		var q := x[who[k]]
		var hk := ((floori(q.x * inv_cell) * 73856093) ^ (floori(q.y * inv_cell) * 19349663) ^ (floori(q.z * inv_cell) * 83492791)) & (HASH - 1)
		key[k] = hk
		count[hk + 1] += 1
	for k in HASH:
		count[k + 1] += count[k]
	var order := PackedInt32Array()
	order.resize(who.size())
	var fill := count.duplicate()
	for k in who.size():
		order[fill[key[k]]] = who[k]
		fill[key[k]] += 1
	var seen := PackedInt32Array()
	for k in who.size():
		var i := who[k]
		if asleep[i] == 1 or alive[i] == 0:
			continue
		var pi := x[i]
		var fx := pi.x * inv_cell
		var fy := pi.y * inv_cell
		var fz := pi.z * inv_cell
		var cx := floori(fx)
		var cy := floori(fy)
		var cz := floori(fz)
		# the 8 cells nearest it: its own, and the next one each way it lies toward
		var ox := 1 if fx - float(cx) >= 0.5 else -1
		var oy := 1 if fy - float(cy) >= 0.5 else -1
		var oz := 1 if fz - float(cz) >= 0.5 else -1
		seen.clear()
		var bi := body[i]
		var ri := r[i] + margin
		for c in 8:
			var hk := (((cx + (ox if c & 1 else 0)) * 73856093) ^ ((cy + (oy if c & 2 else 0)) * 19349663) ^ ((cz + (oz if c & 4 else 0)) * 83492791)) & (HASH - 1)
			if seen.has(hk):
				continue
			seen.append(hk)
			for o in range(count[hk], count[hk + 1]):
				var j := order[o]
				if j == i or (j < i and asleep[j] == 0) or (bi >= 0 and bi == body[j]):
					continue
				var rr := ri + r[j]
				if (x[j] - pi).length_squared() < rr * rr:
					_pi.append(i)
					_pj.append(j)


## KEPT OUT OF ONE ANOTHER: each pair that may meet ([method _find_pairs]) and overlaps, pushed apart by their masses (a
## sleeper or a held one does not give), its slide held by friction.
func _contacts() -> void:
	for k in _pi.size():
		var i := _pi[k]
		var j := _pj[k]
		if alive[i] == 0 or alive[j] == 0:
			continue
		var d := _p[j] - _p[i]
		var rr := r[i] + r[j]
		var l2 := d.length_squared()
		if l2 >= rr * rr or l2 < 1e-18:
			continue
		var l := sqrt(l2)
		var nn := d / l
		var pen := minf(rr - l, PART_MOST * _h)
		var wi := 0.0 if _hold[i] == 1 else w[i]
		var wj := 0.0 if (asleep[j] == 1 or _hold[j] == 1) else w[j]
		if asleep[j] == 1 and pen > WAKE_PUSH * r[j] and _hold[i] == 0:
			_wake_body_of(j)
			wj = w[j]
		var sum := wi + wj
		if sum <= 0.0:
			continue
		_p[i] -= nn * (pen * wi / sum)
		_p[j] += nn * (pen * wj / sum)
		_held_by[i] = 1
		_held_by[j] = 1
		# friction between them: their slide over the substep, against one another
		var dd := (_p[i] - x[i]) - (_p[j] - x[j])
		var t := dd - nn * dd.dot(nn)
		var lt := t.length()
		if lt < 1e-9:
			continue
		var take := t if lt < mus[i] * pen else t * minf(muk[i] * pen / lt, 1.0)
		_p[i] -= take * (wi / sum)
		_p[j] += take * (wj / sum)


static func _cell(p: Vector3, c: float) -> Vector3i:
	return Vector3i(floori(p.x / c), floori(p.y / c), floori(p.z / c))


static func _hash(a: int, b: int, c: int) -> int:
	return ((a * 73856093) ^ (b * 19349663) ^ (c * 83492791)) & (HASH - 1)


## SHAPE MATCHING: body [param bi]'s spheres moved onto its shape, turned and placed as their positions best say -
## the turn by Muller et al.'s robust rotation extraction (2016), from the last turn; a lone sphere rolls.
func _match(bi: int) -> void:
	var b: Dictionary = bodies[bi]
	var ids: PackedInt32Array = b["ids"]
	var rest: PackedVector3Array = b["rest"]
	var live: Array = []
	for k in ids.size():
		if alive[ids[k]] == 1:
			live.append(k)
	if live.is_empty():
		return
	if live.size() == 1:
		var i := ids[int(live[0])]
		# A LONE SPHERE ROLLS over what it moves on
		var dp := _p[i] - x[i]
		var flat := Vector3(dp.x, 0.0, dp.z)
		if flat.length() > 1e-6 and _held_by[i] == 1:
			var axis := Vector3.UP.cross(flat).normalized()
			b["q"] = (Quaternion(axis, flat.length() / maxf(r[i], 1e-4)) * (b["q"] as Quaternion)).normalized()
		b["c"] = _p[i] - Basis(b["q"] as Quaternion) * rest[int(live[0])]
		return
	var c := Vector3.ZERO
	var m := 0.0
	for k in live:
		var i := ids[int(k)]
		var mi := 1.0 / maxf(w[i], 1e-12)
		c += _p[i] * mi
		m += mi
	c /= m
	var a0 := Vector3.ZERO
	var a1 := Vector3.ZERO
	var a2 := Vector3.ZERO
	for k in live:
		var i := ids[int(k)]
		var mi := 1.0 / maxf(w[i], 1e-12) / m
		var d := _p[i] - c
		var q0: Vector3 = rest[int(k)]
		a0 += d * (q0.x * mi)
		a1 += d * (q0.y * mi)
		a2 += d * (q0.z * mi)
	var q: Quaternion = b["q"]
	for it in 4:
		var R := Basis(q)
		var om := R.x.cross(a0) + R.y.cross(a1) + R.z.cross(a2)
		var den := absf(R.x.dot(a0) + R.y.dot(a1) + R.z.dot(a2)) + 1e-12
		om /= den
		var wl := om.length()
		if wl < 1e-9:
			break
		q = (Quaternion(om / wl, wl) * q).normalized()
	b["q"] = q
	b["c"] = c
	var R2 := Basis(q)
	for k in live:
		var i := ids[int(k)]
		_p[i] = c + R2 * rest[int(k)]


## WHAT IS STILL SLEEPS, on its host: the solid it is in or last met - or, resting on others, theirs.
func _settle(dt: float, act: PackedInt32Array) -> void:
	var calm := PackedInt32Array()
	for i in act:
		if alive[i] == 0 or _is_held(i):
			continue
		if v[i].length() < SLEEP_SPEED and _held_by[i] == 1:
			still[i] = maxf(still[i], 0.0) + dt
		else:
			still[i] = 0.0
		if still[i] >= SLEEP_AFTER:
			calm.append(i)
	if calm.is_empty():
		return
	# a body sleeps whole, or not at all
	var ok := {}
	for i in calm:
		ok[i] = true
	var keep := PackedInt32Array()
	for i in calm:
		if body[i] >= 0:
			var all := true
			for k in (bodies[body[i]] as Dictionary)["ids"]:
				if alive[k] == 1 and not ok.has(k):
					all = false
			if not all:
				continue
		keep.append(i)
	for i in keep:
		var hs := _host_of(i)
		asleep[i] = 1
		v[i] = Vector3.ZERO
		host[i] = hs
		var hx: Transform3D = (_solids[hs] as Dictionary)["xf"] if hs >= 0 else Transform3D.IDENTITY
		hloc[i] = hx.affine_inverse() * x[i]
		hup[i] = hx.basis.y.normalized()
	for bi in bodies.size():
		var b: Dictionary = bodies[bi]
		if b["held"] != null or not body_asleep(bi):
			continue
		var ids: PackedInt32Array = b["ids"]
		var hs := host[ids[0]]
		# its spheres share one host
		for i in ids:
			if alive[i] == 1:
				host[i] = hs
				var hx: Transform3D = (_solids[hs] as Dictionary)["xf"] if hs >= 0 else Transform3D.IDENTITY
				hloc[i] = hx.affine_inverse() * x[i]
				hup[i] = hx.basis.y.normalized()
		var hx2: Transform3D = (_solids[hs] as Dictionary)["xf"] if hs >= 0 else Transform3D.IDENTITY
		b["hrel"] = hx2.affine_inverse() * Transform3D(Basis(b["q"] as Quaternion), b["c"] as Vector3)


## The host particle [param i] sleeps on: the solid whose inside or surface it rests in, or what the spheres it rests on
## sleep on, or -1 (the table).
func _host_of(i: int) -> int:
	if touch[i] >= 0:
		return touch[i]
	for li in _liquids.size():
		var l: Dictionary = _liquids[li]
		if (l["vessel"] as Vessel).contains((l["inv"] as Transform3D) * x[i]):
			return int(l.get("solid", -1))
	# resting on others: theirs
	var best := -1
	var bd := INF
	for j in n:
		if j == i or alive[j] == 0 or asleep[j] == 0:
			continue
		var d := x[j].distance_to(x[i])
		if d < (r[i] + r[j]) * 1.3 and d < bd:
			bd = d
			best = host[j]
	if best >= 0:
		return best
	# in a hollow, by its field: the nearest solid within a few centimeters
	var near := -1
	var nd := 0.03
	for si in _solids.size():
		var s: Dictionary = _solids[si]
		if not (s["wbox"] as AABB).grow(0.03).has_point(x[i]):
			continue
		var d := (s["field"] as ShapeField).sample((s["inv"] as Transform3D) * x[i]).x
		if d < nd:
			nd = d
			near = si
	return near


## WHAT BREAKS: a body damaged past its matter's strength splits along its middle (its mesh no longer whole); a lone
## piece into two of half its volume, until it is powder.
func _break() -> void:
	for bi in range(bodies.size() - 1, -1, -1):
		var b: Dictionary = bodies[bi]
		var ids: PackedInt32Array = b["ids"]
		var worst := 0.0
		var live := PackedInt32Array()
		for i in ids:
			if alive[i] == 1:
				live.append(i)
				worst = maxf(worst, damage[i])
		if live.is_empty():
			continue
		var strength := float((matter[mat[live[0]]] as Dictionary)["strength"])
		if strength <= 0.0 or worst < strength * DAMAGE:
			continue
		for i in live:
			damage[i] = 0.0
		if live.size() >= 2:
			_split_body(bi, live)
		elif r[live[0]] * 0.7937 >= POWDER and n < MOST:
			_split_sphere(bi, live[0])


## Body [param bi] split in two across its longest way, each half a body of its own - its mesh no longer drawn whole.
func _split_body(bi: int, live: PackedInt32Array) -> void:
	var b: Dictionary = bodies[bi]
	var c := Vector3.ZERO
	for i in live:
		c += x[i]
	c /= float(live.size())
	var far := Vector3.ZERO
	for i in live:
		if (x[i] - c).length() > far.length():
			far = x[i] - c
	var axis := far.normalized() if far.length() > 1e-6 else Vector3.RIGHT
	var a := PackedInt32Array()
	var bb := PackedInt32Array()
	for i in live:
		if (x[i] - c).dot(axis) >= 0.0:
			a.append(i)
		else:
			bb.append(i)
	if a.is_empty() or bb.is_empty():
		a = live.slice(0, live.size() / 2)
		bb = live.slice(live.size() / 2)
	b["intact"] = false
	_reform(bi, a)
	var nb := bodies.size()
	bodies.append({"ids": PackedInt32Array(), "rest": PackedVector3Array(), "c0": c, "c": c, "q": Quaternion.IDENTITY, "intact": false,
		"held": null, "hrel": Transform3D.IDENTITY, "made_by": int(b.get("made_by", -1)), "piece_of": int(b.get("piece_of", bi))})
	_reform(nb, bb)
	events.append({"kind": "break", "body": int(b.get("piece_of", bi))})


## Body [param bi] made again of the spheres [param ids], as they are now.
func _reform(bi: int, ids: PackedInt32Array) -> void:
	var b: Dictionary = bodies[bi]
	var c := Vector3.ZERO
	for i in ids:
		c += x[i]
	c /= float(maxi(ids.size(), 1))
	var rest := PackedVector3Array()
	for i in ids:
		rest.append(x[i] - c)
		body[i] = bi
	b["ids"] = ids
	b["rest"] = rest
	b["c0"] = c
	b["c"] = c
	b["q"] = Quaternion.IDENTITY


## The lone sphere [param i] of body [param bi] split into two of half its volume, a little apart.
func _split_sphere(bi: int, i: int) -> void:
	var nr := r[i] * 0.7937
	var dir := Vector3(sin(float(i) * 12.9898 + x[i].x * 311.0), 0.35, cos(float(i) * 78.233 + x[i].z * 197.0)).normalized()
	var at := x[i]
	r[i] = nr
	r0[i] = maxf(r0[i] * 0.7937, nr)
	w[i] *= 2.0
	x[i] = at + dir * nr * 0.6
	(bodies[bi] as Dictionary)["intact"] = false
	_reform(bi, PackedInt32Array([i]))
	var j := add(at - dir * nr * 0.6, nr, mat[i], owner[i], -2)
	if j < 0:
		return
	v[j] = v[i]
	r0[j] = r0[i]
	var nb := bodies.size()
	bodies.append({"ids": PackedInt32Array(), "rest": PackedVector3Array(), "c0": at, "c": at, "q": Quaternion.IDENTITY, "intact": false,
		"held": null, "hrel": Transform3D.IDENTITY, "made_by": int((bodies[bi] as Dictionary).get("made_by", -1)),
		"piece_of": int((bodies[bi] as Dictionary).get("piece_of", bi))})
	_reform(nb, PackedInt32Array([j]))
	events.append({"kind": "break", "body": int((bodies[bi] as Dictionary).get("piece_of", bi))})


func _kill(i: int) -> void:
	alive[i] = 0
	asleep[i] = 0
	events.append({"kind": "gone", "i": i, "liquid": wet[i]})


# --- kept and restored ----------------------------------------------------------------------------------

## Everything, as it is now: what a bake goes back to when its plan changes after this moment.
func snapshot() -> Dictionary:
	var bs: Array = []
	for b in bodies:
		bs.append((b as Dictionary).duplicate(true))
	return {"n": n, "x": x.duplicate(), "v": v.duplicate(), "r": r.duplicate(), "r0": r0.duplicate(), "w": w.duplicate(),
		"mat": mat.duplicate(), "body": body.duplicate(), "alive": alive.duplicate(), "asleep": asleep.duplicate(),
		"still": still.duplicate(), "host": host.duplicate(), "hloc": hloc.duplicate(), "hup": hup.duplicate(),
		"damage": damage.duplicate(), "wet": wet.duplicate(), "owner": owner.duplicate(), "bodies": bs}


func restore(s: Dictionary) -> void:
	n = int(s["n"])
	x = (s["x"] as PackedVector3Array).duplicate()
	v = (s["v"] as PackedVector3Array).duplicate()
	r = (s["r"] as PackedFloat32Array).duplicate()
	r0 = (s["r0"] as PackedFloat32Array).duplicate()
	w = (s["w"] as PackedFloat32Array).duplicate()
	mat = (s["mat"] as PackedInt32Array).duplicate()
	body = (s["body"] as PackedInt32Array).duplicate()
	alive = (s["alive"] as PackedByteArray).duplicate()
	asleep = (s["asleep"] as PackedByteArray).duplicate()
	still = (s["still"] as PackedFloat32Array).duplicate()
	host = (s["host"] as PackedInt32Array).duplicate()
	hloc = (s["hloc"] as PackedVector3Array).duplicate()
	hup = (s["hup"] as PackedVector3Array).duplicate()
	damage = (s["damage"] as PackedFloat32Array).duplicate()
	wet = (s["wet"] as PackedInt32Array).duplicate()
	owner = (s["owner"] as PackedInt32Array).duplicate()
	bodies = []
	for b in s["bodies"]:
		bodies.append((b as Dictionary).duplicate(true))
	touch = PackedInt32Array()
	touch.resize(n)
	touch.fill(-1)
	mus = PackedFloat32Array()
	muk = PackedFloat32Array()
	rho = PackedFloat32Array()
	dis = PackedFloat32Array()
	for i in n:
		var md: Dictionary = matter[mat[i]] if mat[i] >= 0 else matter[0]
		mus.append((md["friction"] as Vector2).x)
		muk.append((md["friction"] as Vector2).y)
		rho.append(float(md["density"]))
		dis.append(float(md["dissolves"]))
	_hold = PackedByteArray()
	_hold.resize(n)
	_pressed = PackedFloat32Array()
	_pressed.resize(n)
	_held_by = PackedByteArray()
	_held_by.resize(n)
	_p = x.duplicate()


## SPHERES FILLING A SHAPE: the middles of an even packing of spheres of radius [param rad] inside [param f] (a field in
## its own space) within [param box], carried by [param xf] - at most [param most], and at least the box's middle.
static func fill_shape(f: ShapeField, box: AABB, rad: float, xf: Transform3D, most: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	var step := rad * 2.0
	var nx := maxi(int(floor(box.size.x / step)), 1)
	var ny := maxi(int(floor(box.size.y / step)), 1)
	var nz := maxi(int(floor(box.size.z / step)), 1)
	var c := box.get_center()
	for j in ny:
		for i in nx:
			for k in nz:
				var p := c + Vector3((float(i) - float(nx - 1) * 0.5) * step, (float(j) - float(ny - 1) * 0.5) * step, (float(k) - float(nz - 1) * 0.5) * step)
				if f == null or f.sample(p).x < -rad * 0.25:
					out.append(xf * p)
				if out.size() >= most:
					return out
	if out.is_empty():
		out.append(xf * c)
	return out


## THE RADIUS of the spheres a body of size [param size] (meters) is made of.
static func sphere_for(size: Vector3) -> float:
	var least := minf(size.x, minf(size.y, size.z))
	var most := maxf(size.x, maxf(size.y, size.z))
	var rad := clampf(least * 0.42, SPHERE.x, SPHERE.y)
	# never more than BODY_MOST along its longest way and across
	var along := most / (rad * 2.0)
	if along > float(BODY_MOST) * 0.5:
		rad = clampf(most / float(BODY_MOST), SPHERE.x, SPHERE.y)
	return rad
