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
##     and goes where its host goes ([method follow]) - a heap at rest whole, its trembling grains with it; it wakes when its host tips or jolts, when another moving solid
##     comes near it, or when something awake strikes it ([method wake_near], [method wake_host]).
##   - EVERY SOLID IS A FIELD ([ShapeField]): a particle in one is pushed out along its way out, and its slide along it
##     held by friction against the solid's own motion - a tipped dish's stones slide, a carried one's ride.
##   - IN A LIQUID a particle is slowed, lifted by what it displaces (lighter than the liquid, it floats), carried round
##     by its swirl, and - if its matter dissolves - shrinks away; it rings the surface as it enters ([member events]).
##   - SQUEEZED BETWEEN A MOVING SOLID AND WHAT HOLDS IT, a particle is damaged; past its matter's strength a loose
##     thing splits along its middle, its halves still rigid, and a lone piece into two of half its volume, down to
##     [constant POWDER] - a bonded-particle model's bonds breaking under load (Potyondy and Cundall, 2004).
##   - A SHEET THAT BENDS ([method make_soft]; 841899, feedback 0012: the feather "clipping through the ladle ... should probably be more deformable, so that it's able to wrap
##     and contort around the ladle ... gently enough that it doesn't create a whiplash effect"): not matched to its shape but held by LINKS between its points - the
##     stretch and bending of position based dynamics (Muller et al., 2007) - with a weak pull back to its own shape; a thin tool can never slip between its points
##     ([member _nr]), and pushes it no faster than the tool goes ([constant SOFT_PUSH]). What it does is drawn by [SheetBend].
##   - A LIQUID IS NEVER QUITE STILL ([method current], [method swell]; the same report: "a floating object shouldn't be stable, it should be gently moving ... sometimes bob ...
##     maybe spin a bit"): a slow current and a swell, as hard as it boils and stirs, carry what floats. A body afloat never sleeps; how it rides them is its own weight's.

## The most particles at once, the substeps a frame, gravity, the fastest a particle may go (meters a second). A loose
## thing is made a body only as something comes to it ([method TablePhysics._wake_loose]), so these are what is laid in
## things and what the work has touched.
const MOST := 1600
const SUBSTEPS := 4
const GRAVITY := Vector3(0.0, -9.81, 0.0)
const V_MOST := 2.5
## SLEEP: slower than this (meters a second) for this long (seconds), touching something, and it sleeps on its host - or, a
## body, none of it further than SLEEP_DRIFT (meters) from where it was that long ago: TREMBLING IN PLACE IS AT REST (841899:
## a jar's seven lumps, woken as it was set down, trembled a tenth of a millimeter each way in it for seconds, never slower
## than SLEEP_SPEED, and kept the bake reckoning every frame).
const SLEEP_SPEED := 0.008
const SLEEP_DRIFT := 0.0005
const SLEEP_AFTER := 0.25
## WAKING: a host tipped this far since its sleepers slept (radians), or jolted this hard (meters a second, squared);
## a moving solid this near (meters); struck this hard (a share of its radius pushed in a substep).
const WAKE_TILT := 0.12
const WAKE_JOLT := 4.0
const WAKE_NEAR := 0.003
const WAKE_PUSH := 0.15
## FRICTION (static, kinetic) of a particle's own, unless its matter says - between particles as it is, and against a
## solid met with the solid's surface's own (a solid's `mu`, [constant TablePhysics.SURFACES]) as their geometric mean,
## the table's top's TABLE_FRICTION.
const FRICTION := Vector2(0.65, 0.45)
const TABLE_FRICTION := Vector2(0.5, 0.4)
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
## A HELD THING GOES NO DEEPER into a solid than this, or than it already is (meters): it may touch, never pass ([method
## _held_way]).
const HELD_SLACK := 0.0003
## A HEAP COMES TO REST: a sphere held up by something and slower than this (meters a second) loses this share of its
## speed a substep - one pass of the constraints leaves a heap trembling, never still enough to sleep.
const SETTLE := Vector2(0.04, 0.3)
## A HEAP TREMBLING, not moving: the fastest one of its grains goes while the heap is at rest ([method _settle]) - meters
## a second (a grain rolling off a heap's shoulder goes faster).
const TREMBLE := 0.15
## A LIQUID IS CALM, and what floats on it may sleep ([method _afloat]): turning slower than this (radians a second), its
## surface this level (the cosine of its tilt).
const CALM_SWIRL := 0.05
const CALM_LEVEL := 0.9995
## A BLADE CUTS ([method _cut_through]): once its lowest point is this share of a thing's height below the thing's top,
## and the two sides are pushed apart this fast (meters a second), as the wedge of a blade parts them.
const CUT_INTO := 0.1
## A moving solid under a thing, its surface facing up more than this, carries it - never presses it.
const CARRIED := 0.5
const WEDGE := 0.025
## ...and how far past the blade's own half-width each side is parted as it is cut (meters).
const PARTED := 0.0012
const THIN := 0.0016
## A body's spheres: none smaller than this nor larger (meters), and no more than this many.
const SPHERE := Vector2(0.0012, 0.007)
const BODY_MOST := 36
## A SHEET THAT BENDS ([method make_soft]): the points it may have (its links are costly in fewer than its spheres are in more: a thin tool must not fit between them); how
## many of each point's nearest it is linked to; how firmly a link holds its length, and a link across a point its straightness, a pass; the pull back to its own shape a
## pass; how many substeps to a pass; and how much of the difference in speed a link evens out, a pass - what a whip would be (all shares).
const SOFT_MOST := 64
const SOFT_NEAR := 4
const SOFT_STRETCH := 0.9
const SOFT_BEND := 0.08
const SOFT_SHAPE := 0.012
const SOFT_EVERY := 2
const SOFT_CALM := 0.08
## ...how much faster than the tool that pushes it a sheet is moved off it (meters a second) - never a whip - and the middle dimension under which a solid is a thin tool,
## met at a point's whole radius (meters): a rod or a handle goes between points that would stop a bowl.
const SOFT_PUSH := 0.04
const THIN_TOOL := 0.02
## How far past its box a solid is looked at for a sphere, a frame ([method step]), over how far both can go in it (meters).
const NEAR_SLACK := 0.01
## ...and how much of its bend a sheet keeps, a substep in a hand.
const HELD_STRAIGHTENS := 0.985
## A LIQUID IS NEVER QUITE STILL: its current at a rolling boil (meters a second) and its swell's height (meters) - each two waves added, so half that each.
const CURRENT := 0.024
const SWELL := 0.0035
## How many ways round a sheet its outline is reached ([method _sheet_outline]), and how fine a grid of it (a side) that is looked for on.
const SHEET_REACHES := 16
const SHEET_GRID := 96
## ...spaced up to this many times their touching apart in a thing no blade cuts (a cut parts the spheres either side of
## it, so a soft thing keeps them touching): a pumpkin seed 1.5 cm long, filled to its thinness with twenty, ten of them
## tumbling into a mortar were 200 awake and the bake fell behind the show.
const BODY_SPREAD := 2.0
## What a sphere resting on the table's own top has met ([member touch]): no solid.
const TABLE := -2
## The spatial hash's size (a power of two), and the cells what is awake is told by ([member awake_cells], meters).
const HASH := 8192
const AWAKE_CELL := 0.03

var n := 0
var x := PackedVector3Array()          # where each is (the table's space, meters) - a sleeper's kept where its host has it
var v := PackedVector3Array()
var r := PackedFloat32Array()
var r0 := PackedFloat32Array()         # its radius as it was made
## HOW NEAR THE TABLE AND THE SOLIDS IT RESTS (meters): its radius - or, a sphere of a thin thing, half that thing's own
## thickness ([method add_body]'s `contact`). A sheet's spheres are spaced as its length asks, a few millimeters, and met the
## table at that: a feather 0.8 mm thick lay 3 mm over the table and threw a shadow apart from itself (the-quiet-crucible
## 841899, 2026-10-31). Among themselves and other loose things they keep their radius.
var rc := PackedFloat32Array()
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
var touch := PackedInt32Array()        # the solid it rests on this frame ([constant TABLE] the table's top), or -1
var mus := PackedFloat32Array()        # its matter's friction, static and kinetic, its density and how fast it dissolves
var muk := PackedFloat32Array()
var rho := PackedFloat32Array()
var dis := PackedFloat32Array()
var _hold := PackedByteArray()         # this substep: held by the work (kinematic)
var _pressed := PackedFloat32Array()   # this substep: how hard a moving solid pressed it
var _held_by := PackedByteArray()      # this substep: whether something else held it from the other side
var _p := PackedVector3Array()         # predicted places this substep
var _still_only := false               # a body's way asked of the still solids alone ([method _way])

## [{density, strength, dissolves, friction (Vector2)}]: what each kind of matter is ([constant Props.MATERIALS]).
var matter: Array = []
## THE LOOSE THINGS: [{ids, rest (offsets from `c0`), c0 (the middle as made), q (its turn now), c (its middle now),
## intact, held (a Transform3D the work holds it at this substep, or null), hrel (its pose in its host's space while it
## sleeps), roll}]
var bodies: Array = []
## WHAT HAPPENED this frame, for the bake to keep: [{kind ("enter", "break" - with where and how big a piece, "gone",
## "cut"), ...}]
var events: Array = []
## Whether anything moved this frame - awake, carried by a moving host, made or gone: a frame where nothing did shares the
## last one's places ([method TablePhysics._record]).
var moved := true
## Where what is awake was this frame, as far as it could reach in it (the table's space): empty when nothing is.
var reach := AABB()
## ...and each cell of AWAKE_CELL meters something awake was in ([Vector3i] -> the ones in it): two things awake at
## either end of the table leave what lies between them alone, which their one box takes in.
var awake_cells := {}

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
var _ne := PackedByteArray()          # this substep: which of the near solids is a blade ([method _cut_through])
var _nmu := PackedVector2Array()      # ...and each one's surface friction, static and kinetic
var _mv := PackedByteArray()          # this frame: which solids move ...
var _on_moving := PackedInt32Array()  # ...and which spheres sleep on one
var _woke_now := false                # a sphere has woken, or been made, since this was last looked at
var _near_all := PackedInt32Array()   # every near solid's place in [member _nid] ...
var _near_of: Array = []              # ...and those each awake sphere may meet this frame
var _way_near := PackedInt32Array()   # what the sphere or body being moved now may meet
var _nr := PackedByteArray()          # ...and which is a thin tool, which a sheet's points meet at their whole radius ([constant THIN_TOOL])
var _np := PackedByteArray()          # ...and whether each one, moving, presses what it meets (driven, never settling)
var _pi := PackedInt32Array()         # the pairs that may meet this frame ([method _find_pairs])
var _ride := PackedInt32Array()       # this frame: the moving solid whose inside each awake one is in, which carries it, or -1
var _any_moving := false              # this frame: whether any solid moves
var _vessels: Array = []              # [{solid, vessel}]: every inside on the table, as the world hands them
var _pj := PackedInt32Array()


## MATTER as a row: [param density] (grams a cubic centimeter), [param strength] (0 never breaks), [param dissolves]
## (seconds to dissolve in a liquid, 0 never), and whether a blade [param cuts] it ([method _cut_through]).
func add_matter(density: float, strength: float, dissolves: float, friction := FRICTION, cuts := false) -> int:
	matter.append({"density": maxf(density, 0.05), "strength": maxf(strength, 0.0), "dissolves": maxf(dissolves, 0.0), "friction": friction,
		"cuts": cuts})
	return matter.size() - 1


## Whether anything awake this frame has come within [constant WAKE_NEAR] of [param box] (the table's space), where it
## is now.
func awake_in(box: AABB) -> bool:
	if awake_cells.is_empty():
		return false
	var lo := _cell(box.position, AWAKE_CELL) - Vector3i.ONE
	var hi := _cell(box.end, AWAKE_CELL) + Vector3i.ONE
	for cx in range(lo.x, hi.x + 1):
		for cy in range(lo.y, hi.y + 1):
			for cz in range(lo.z, hi.z + 1):
				for i in awake_cells.get(Vector3i(cx, cy, cz), []):
					if alive[int(i)] == 1 and box.grow(r[int(i)] + WAKE_NEAR).has_point(x[int(i)]):
						return true
	return false


## A PARTICLE at [param at] (meters), [param radius] across, of matter [param m]: its number, or -1 past [constant MOST].
## It sleeps on [param on] ([param on_xf], that solid's pose) unless [param on] is -2: awake.
func add(at: Vector3, radius: float, m: int, made_by: int, on: int, on_xf := Transform3D.IDENTITY) -> int:
	_woke_now = true
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
		rc.append(0.0)
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
	rc[i] = radius
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


## A LOOSE THING made of the spheres [param at] (meters, the table's space), each [param radius] across - resting on the table and
## the solids at [param contact] (meters; 0: its radius) ([member rc]): its body's number.
func add_body(at: PackedVector3Array, radius: float, m: int, made_by: int, on: int, on_xf := Transform3D.IDENTITY, contact := 0.0) -> int:
	var ids := PackedInt32Array()
	for p in at:
		var i := add(p, radius, m, made_by, on, on_xf)
		if i >= 0:
			ids.append(i)
			if contact > 0.0:
				rc[i] = minf(contact, radius)
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


## How many more particles there is room for: the most, less those alive (a dead one's place is taken first, [method add]).
func room() -> int:
	var live := 0
	for i in n:
		live += alive[i]
	return MOST - live


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
	# NOTHING MOVING: no sleeper is carried, jolted or tipped by its host - the loops over every sleeper are skipped. AND WHAT MOVES CARRIES ONLY WHAT SLEEPS ON IT (841899, a stir: 52 of 1,437
	# spheres awake, the ladle the only thing moving, and most of a frame in here spent walking all 1,437 a dozen times to find that out): those are found once, here
	_any_moving = false
	_mv.resize(_solids.size())
	_mv.fill(0)
	for si in _solids.size():
		if bool((_solids[si] as Dictionary).get("moving", false)):
			_mv[si] = 1
			_any_moving = true
	_on_moving = PackedInt32Array()
	if _any_moving:
		for i in n:
			var hs := host[i]
			if hs >= 0 and hs < _mv.size() and _mv[hs] == 1 and alive[i] == 1 and asleep[i] == 1:
				_on_moving.append(i)
		moved = not _on_moving.is_empty()
		follow()
		wake_host(dt)
	wake_near()
	var act := PackedInt32Array()
	for i in n:
		if alive[i] == 1 and asleep[i] == 0:
			act.append(i)
	_wet_now(act)
	for b in bodies:
		if (b as Dictionary)["held"] != null:
			for i in (b as Dictionary)["ids"]:
				if alive[i] == 1 and asleep[i] == 1:
					_wake(i)
					act.append(i)
	for i in act:
		touch[i] = -1
	awake_cells = {}
	if act.is_empty():
		moved = moved or n != n_was
		reach = AABB()
		return
	for i in act:
		var cell := _cell(x[i], AWAKE_CELL)
		if not awake_cells.has(cell):
			awake_cells[cell] = []
		(awake_cells[cell] as Array).append(i)
	moved = true
	# THE SOLIDS NEAR WHAT IS AWAKE, found once a frame: only they are met
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for i in act:
		lo = Vector3(minf(lo.x, x[i].x), minf(lo.y, x[i].y), minf(lo.z, x[i].z))
		hi = Vector3(maxf(hi.x, x[i].x), maxf(hi.y, x[i].y), maxf(hi.z, x[i].z))
	reach = AABB(lo, hi - lo).grow(0.03 + V_MOST * dt)
	_near = PackedInt32Array()
	for si in _solids.size():
		var sd: Dictionary = _solids[si]
		if bool(sd.get("on", true)) and reach.intersects(sd["wbox"]):
			_near.append(si)
	# WHAT A MOVING INSIDE HOLDS RIDES IT: a jar's grains go where the jar goes, and only how they move in it is reckoned
	# - its wall never sweeps into them (a carried jar's thin glass had passed through its own snow)
	_ride.resize(n)
	_ride.fill(-1)
	# ...the smallest inside first: a vial carried in a pot holds its own
	var moving_in: Array = []
	for vd in _vessels:
		if bool((_solids[int((vd as Dictionary)["solid"])] as Dictionary).get("moving", false)):
			moving_in.append(vd)
	moving_in.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a["vessel"] as Vessel).volume < (b["vessel"] as Vessel).volume)
	for vd in moving_in:
		var si := int((vd as Dictionary)["solid"])
		var sd: Dictionary = _solids[si]
		var inv0: Transform3D = (sd["xf0"] as Transform3D).affine_inverse()
		var vs: Vessel = (vd as Dictionary)["vessel"]
		var near: AABB = ((sd["xf0"] as Transform3D) * (sd["box"] as AABB)).grow(SPHERE.y)
		# every one in it, asleep or not: a sleeper woken part way through the frame rides from the moment it wakes
		for i in n:
			if alive[i] == 1 and _ride[i] < 0 and near.has_point(x[i]) and vs.contains(inv0 * x[i]):
				# ...NEVER A SHEET'S POINT: what is in a jar goes with the jar, but part of a feather in a ladle's bowl went off with the ladle, the rest left in the pot, stretched 23 cm across the
				# table (841899). The bowl meets it, carries it as far as it lies on it, and it slides off
				if body[i] >= 0 and (bodies[body[i]] as Dictionary).has("links"):
					continue
				_ride[i] = si
				# ...its speed its own in it: one woken as its inside moved is at rest there, not thrown at its wall
				if still[i] < 0.0:
					v[i] = Vector3.ZERO
				# ...and A SLEEPER IN IT SLEEPS ON IT: one asleep on what it lay on in there goes with it, never left in the
				# air where the jar stood
				if asleep[i] == 1 and host[i] != si and _inside_at(x[i], true) == si:
					_rehost(i, si)
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
	# ...each substep sets its own where it goes; what sleeps is where it is
	_p = x.duplicate()
	_find_pairs(act, clampf(fastest * dt * 1.2, least * 0.3, SPHERE.y))
	# ...AND WHICH OF THE NEAR SOLIDS EACH MAY MEET THIS FRAME, by their boxes and how far both can go in it: of the twenty a stirred cauldron has near it, a sphere is by one or two, and
	# each sphere had asked all twenty three times a substep - most of what a stir's bake spent in here (841899: a stir had baked slower than it plays, next/framework_audit.md)
	_near_all = PackedInt32Array()
	var boxes: Array = []
	for c in _near.size():
		_near_all.append(c)
		boxes.append((_solids[_near[c]] as Dictionary)["wbox"])
	_near_of.resize(n)
	_near_of.fill(null)
	for i in act:
		var by := PackedInt32Array()
		var far := SPHERE.y + NEAR_SLACK + (fastest + v[i].length()) * dt * 1.5
		for c in boxes.size():
			if (boxes[c] as AABB).grow(far).has_point(x[i]):
				by.append(c)
		_near_of[i] = by
	var h := dt / float(steps)
	var inact := PackedByteArray()
	inact.resize(n)
	for i in act:
		inact[i] = 1
	_woke_now = false
	for s in steps:
		var a := float(s + 1) / float(steps)
		_substep(h, a, act, world)
		# a woken sleeper (or one made this step) joins at once
		if _woke_now or inact.size() < n:
			_woke_now = false
			if inact.size() < n:
				inact.resize(n)
			for i in n:
				if alive[i] == 1 and asleep[i] == 0 and inact[i] == 0:
					act.append(i)
					inact[i] = 1
	_cut_through()
	# ...how each sheet is bent, as this frame leaves it ([method bent]): what is drawn, and what a hand takes up
	for bi in bodies.size():
		var bd: Dictionary = bodies[bi]
		if bd.has("links") and bd["held"] == null and not body_asleep(bi):
			bd["off"] = bent(bi)
	_settle(dt, act)
	_break()
	if _any_moving:
		follow(true)


## THE SLEEPERS GO WHERE THEIR HOSTS GO: each one's place, and each sleeping body's pose, from its host as it was as the
## frame began ([param end] false: the substeps carry them on with it, as they carry what is awake in it) or as it ends.
func follow(end := false) -> void:
	var key := "xf" if end else "xf0"
	for i in _on_moving:
		if alive[i] == 1 and asleep[i] == 1:
			x[i] = ((_solids[host[i]] as Dictionary)[key] as Transform3D) * hloc[i]
	for bi in bodies.size():
		var b: Dictionary = bodies[bi]
		var ids: PackedInt32Array = b["ids"]
		var hs := host[ids[0]] if not ids.is_empty() else -1
		if hs < 0 or hs >= _mv.size() or _mv[hs] == 0 or not body_asleep(bi):
			continue
		if hs >= 0 and hs < _solids.size():
			var t: Transform3D = ((_solids[hs] as Dictionary)[key] as Transform3D) * (b["hrel"] as Transform3D)
			b["c"] = t.origin
			b["q"] = t.basis.get_rotation_quaternion()


## HOW HARD A HOST JOLTS what lies on or in it, from its acceleration [param a] (meters a second, squared): along the
## table, and downward past falling. Set down or lifted, what lies in it is only pressed into it - a frame's stop as a jar
## lands a millimeter reads twice [constant WAKE_JOLT], and woke what lay in it.
static func jolt_of(a: Vector3) -> float:
	return Vector2(a.x, a.z).length() + maxf(-a.y + GRAVITY.y, 0.0)


## A SLEEPER WAKES as its host tips or jolts: tipped past [constant WAKE_TILT] since it fell asleep, or moved harder than
## [constant WAKE_JOLT] (its `jolt`, the bake's).
func wake_host(_dt: float) -> void:
	for i in _on_moving:
		if alive[i] == 0 or asleep[i] == 0:
			continue
		var s: Dictionary = _solids[host[i]]
		var up := (s["xf"] as Transform3D).basis.y.normalized()
		if up.angle_to(hup[i]) > WAKE_TILT or float(s.get("jolt", 0.0)) > WAKE_JOLT:
			_wake_body_of(i)


## A SLEEPER WAKES as another moving solid comes near it.
func wake_near() -> void:
	# ...one moving enough to: a part the work let go, settling, wakes nothing ([constant RigidParts.STIRS])
	var stirring := PackedInt32Array()
	var all_box := AABB()
	for si in _solids.size():
		var s: Dictionary = _solids[si]
		if bool(s.get("stirs", s.get("moving", false))):
			var grown: AABB = (s["wbox"] as AABB).grow(SPHERE.y + WAKE_NEAR)
			all_box = grown if stirring.is_empty() else all_box.merge(grown)
			stirring.append(si)
	if stirring.is_empty():
		return
	var under := PackedInt32Array()
	for i in n:
		if alive[i] == 1 and asleep[i] == 1 and all_box.has_point(x[i]):
			under.append(i)
	for si in stirring:
		var s: Dictionary = _solids[si]
		var box: AABB = (s["wbox"] as AABB).grow(SPHERE.y + WAKE_NEAR)
		var inv: Transform3D = s["inv"]
		var f: ShapeField = s["field"]
		for i in under:
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
	_woke_now = true
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
func _wet_now(act: PackedInt32Array) -> void:
	for i in act:
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
		if (p - (l["c"] as Vector3)).dot(l["n"] as Vector3) > rad + _lift(l, p):
			continue
		if ((l["vessel"] as Vessel).contains((l["inv"] as Transform3D) * p)):
			return li
	return -1


## LIQUID [param l]'s CURRENT at [param p] (the table's space, meters a second): level, and going nowhere on the whole - two slow waves of a stream function - so what
## floats drifts, and turns where its two ends are carried differently. A pure function of the moment: a render and a scrub agree. [method TablePhysics._flow_of] makes `flow`.
static func current(l: Dictionary, p: Vector3) -> Vector3:
	var a := float(l.get("agit", 0.0))
	if a <= 0.0:
		return Vector3.ZERO
	var fl: PackedFloat32Array = l["flow"]
	var t := float(l["t"])
	var out := Vector3.ZERO
	for m in 2:
		var kx := fl[m * 4]
		var kz := fl[m * 4 + 1]
		var along := cos(kx * p.x + kz * p.z + fl[m * 4 + 2] + fl[m * 4 + 3] * t) / maxf(sqrt(kx * kx + kz * kz), 1e-6)
		out += Vector3(kz * along, 0.0, -kx * along)
	return out * (CURRENT * 0.5 * a)


## LIQUID [param l]'s SWELL over [param p] (meters above its level): two waves, quicker than its current. What it is drawn with is the shader's own never-still ripple.
static func swell(l: Dictionary, p: Vector3) -> float:
	var a := float(l.get("agit", 0.0))
	if a <= 0.0:
		return 0.0
	var fl: PackedFloat32Array = l["flow"]
	var t := float(l["t"])
	var up := 0.0
	for m in range(2, 4):
		up += sin(fl[m * 4] * p.x + fl[m * 4 + 1] * p.z + fl[m * 4 + 2] + fl[m * 4 + 3] * t)
	return up * SWELL * 0.5 * a


## How far above its level liquid [param l]'s surface stands over [param p] (the table's space): its ripples there
## ([SurfaceWaves]), its swell and, turning, its curve - what floats rides them, and what is under them is in it.
func _lift(l: Dictionary, p: Vector3) -> float:
	var up := swell(l, p)
	var st: Variant = l.get("w")
	if st is Dictionary and bool((st as Dictionary)["on"]):
		up += (l["waves"] as SurfaceWaves).height_at(st, (l["inv"] as Transform3D) * p)
	var dip := float(l.get("dip", 0.0))
	if dip > 0.0:
		var d := p - (l["c"] as Vector3)
		var along := d.dot(l["n"] as Vector3)
		up += dip * (d.length_squared() - along * along - float(l.get("r2", 0.0)))
	return up


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
	_ne = PackedByteArray()
	_nmu = PackedVector2Array()
	_np = PackedByteArray()
	_nr = PackedByteArray()
	for si in _near:
		var sd: Dictionary = _solids[si]
		_nid.append(si)
		_nr.append(1 if bool(sd.get("thin", false)) else 0)
		_ne.append(1 if bool(sd.get("edge", false)) else 0)
		_nmu.append(sd.get("mu", TABLE_FRICTION))
		_np.append(1 if bool(sd.get("presses", true)) else 0)
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
	for i in _on_moving:
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
			var below := _lift(l, x[i]) - (x[i] - (l["c"] as Vector3)).dot(nn)
			var f := clampf((below + r[i]) / (2.0 * r[i]), 0.0, 1.0)
			vi -= GRAVITY * h * (f * LIQUID_DENSITY / rho[i])
			var rel := x[i] - (l["axis"] as Vector3)
			# ...about where the tool goes, as one, and past that falling away as a vortex does
			var core2 := float(l.get("core", 0.0))
			core2 *= core2
			var flat2 := rel.x * rel.x + rel.z * rel.z
			var vl := Vector3(-rel.z, 0.0, rel.x) * (float(l["swirl"]) * (core2 / flat2 if flat2 > core2 and core2 > 0.0 else 1.0))
			# ...and what floats, by its current (what lies on the floor stays there)
			if body[i] >= 0 and rho[i] < LIQUID_DENSITY:
				vl += current(l, x[i])
			var k := DRAG * f / maxf(rho[i] * r[i], 1e-5)
			vi = vl + (vi - vl) * exp(-k * h)
			if dis[i] > 0.0 and f > 0.0:
				r[i] = maxf(r[i] - r0[i] * h * f / dis[i], 0.0)
				if r[i] < GONE:
					_kill(i)
					continue
		_p[i] = x[i] + vi * h
	# A HELD THING is taken where the work holds it, and pushes what is in its way - but NO HAND PUSHES IT THROUGH A SOLID:
	# it goes whole toward the hand as far as nothing it meets stops it, and slides along what does ([method _held_way]) -
	# a scale lowered onto a vial narrower than it rests on the mouth (the user, 2026-10-29: "We really ought to be able to
	# drop ingredients INTO the vial, and have proper collision handle how it falls, where it settles")
	for b in bodies:
		var bd: Dictionary = b
		if bd["held"] == null:
			continue
		var t := _held_way(bd, _between(bd, bd["held_from"], bd["held"], a))
		bd["c"] = t * (bd["c0"] as Vector3)
		bd["q"] = t.basis.get_rotation_quaternion()
		var ids: PackedInt32Array = bd["ids"]
		var rest: PackedVector3Array = bd["rest"]
		var c0: Vector3 = bd["c0"]
		# ...a sheet taken up straightens as it is held, never at a stroke ([method _ease_held])
		if bd.has("links"):
			_ease_held(bd, t)
			continue
		for k in ids.size():
			_p[ids[k]] = t * (c0 + rest[k])
	# KEPT OUT OF ONE ANOTHER - and then, last, OUT OF EVERY SOLID, with friction against its motion: what a substep ends
	# with is never inside a solid (the other way round, a heap's weight had pressed its bottom grains through a jar's floor)
	_contacts()
	# ...A SHEET'S LINKS, then the solids, so what it comes to stands in nothing: its points are kept out one by one, and go where its links take them
	var pass_now := int(round(a * float(_steps))) % SOFT_EVERY == 0
	if pass_now:
		for bi in bodies.size():
			var bd: Dictionary = bodies[bi]
			if bd.has("links") and bd["held"] == null and not body_asleep(bi):
				_soft_pass(bi)
	for i in act:
		if alive[i] == 0 or _hold[i] == 1:
			continue
		_solid_pass(i)
	# THE LOOSE THINGS HOLD THEIR SHAPES - those awake - AND GO WHOLE as far as nothing they meet stops them: matched to
	# their shape after each sphere was kept out of the solids, a scale resting across a vial's narrow mouth had been
	# pulled down by its spheres inside it, those on the glass with them, and fell through ([method _way])
	for bi in bodies.size():
		var bd: Dictionary = bodies[bi]
		if bd["held"] != null or body_asleep(bi):
			continue
		if bd.has("links"):
			continue
		var was := body_pose_of(bd)
		_match(bi)
		if (bd["ids"] as PackedInt32Array).size() < 2:
			continue
		# ...AND A WALL AT REST IS NEVER CROSSED BY IT, afloat or pushed: what floats, or what a moving solid pushes, goes
		# sphere by sphere where it is moved - but never whole through a still wall, which matching it to its shape after its
		# spheres were kept out would put it (841899: the phoenix feather, afloat and turned by the stir, stood on edge
		# against the cauldron's wall and went through it, and lay outside in the coals to the end of the show)
		var still_only := wet[(bd["ids"] as PackedInt32Array)[0]] >= 0 or _near_moving(bd)
		var want := body_pose_of(bd)
		# ...a body settling a fraction of a millimeter a substep is kept out sphere by sphere; one falling could step through
		if _moved_most(bd, was, want) < THIN * 0.25:
			continue
		var got := _way(bd, was, want, still_only)
		if got != want:
			bd["c"] = got * (bd["c0"] as Vector3)
			bd["q"] = got.basis.get_rotation_quaternion()
			var ids: PackedInt32Array = bd["ids"]
			var rest: PackedVector3Array = bd["rest"]
			for k in ids.size():
				if alive[ids[k]] == 1:
					_p[ids[k]] = got * ((bd["c0"] as Vector3) + rest[k])
	# ...AND WHAT IT CAME TO STANDS IN NOTHING: matched to its shape after its spheres were kept out one by one, a body lying on
	# something is drawn back into it by a fraction of a millimeter a substep - hidden under a sphere's radius, and seen under a
	# sheet's own thickness ([member rc]): a feather lay 0.7 mm into its board. Lifted out whole by its deepest - but never what
	# floats or what a moving solid pushes, which goes sphere by sphere and never whole through a still wall (a leaf a paddle swept
	# into its pot's wall, lifted out of the paddle whole, went through the wall)
	for bi in bodies.size():
		var bd: Dictionary = bodies[bi]
		if bd["held"] != null or body_asleep(bi) or (bd["ids"] as PackedInt32Array).size() < 2 \
				or wet[(bd["ids"] as PackedInt32Array)[0]] >= 0 or bd.has("links") or _near_moving(bd):
			continue
		_out_whole(bd)
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
	# ...AND A SHEET'S POINTS GO TOGETHER: what one was given is shared along its links, so a push is a bend and never a whip
	if pass_now:
		for bd in bodies:
			if (bd as Dictionary).has("links") and (bd as Dictionary)["held"] == null:
				_soft_calm(bd)


## Body [param bd] as this substep leaves it, out of the table's top and of every solid near it: moved whole by the deepest
## push any of its spheres needs ([member rc]), when it is deeper than [constant OUT_LEAST].
func _out_whole(bd: Dictionary) -> void:
	var push := Vector3.ZERO
	for i in (bd["ids"] as PackedInt32Array):
		if alive[i] == 0:
			continue
		var p := _p[i]
		var rad := minf(rc[i], r[i])
		if p.y < _top + rad and _top + rad - p.y > push.length():
			push = Vector3(0.0, _top + rad - p.y, 0.0)
		for c in _near_for(i):
			if not (_nb[c] as AABB).has_point(p):
				continue
			var f: Vector4 = (_nf[c] as ShapeField).sample((_ni[c] as Transform3D) * p)
			if f.x < rad and rad - f.x > push.length():
				push = ((_nx[c] as Transform3D).basis * Vector3(f.y, f.z, f.w)).normalized() * (rad - f.x)
	if push.length() < OUT_LEAST:
		return
	bd["c"] = (bd["c"] as Vector3) + push
	for i in (bd["ids"] as PackedInt32Array):
		_p[i] += push


## A body this little into what it lies on is left there, a substep (meters).
const OUT_LEAST := 0.00005


## WHERE A HELD BODY [param bd] GOES this substep, the hand at [param want]: there, if nothing it would meet on the way
## is deeper in a solid than it is now; else as far toward it as nothing is - and then on along whatever stopped it, as
## far as it may go, level or straight up and down. A rigid thing's own conservative advance: its spheres moved one by
## one and matched to their shape after, the glass of a mouth thinner than the gaps between them had slipped between them.
func _held_way(bd: Dictionary, want: Transform3D) -> Transform3D:
	return _way(bd, body_pose_of(bd), want)


## Body [param bd] from [param now] toward [param want], whole: there if nothing it would meet is deeper in a solid than
## it is now, else as far as nothing is, and on along what stopped it ([method _held_way]).
func _way(bd: Dictionary, now: Transform3D, want: Transform3D, still_only := false) -> Transform3D:
	var ids: PackedInt32Array = bd["ids"]
	var rest: PackedVector3Array = bd["rest"]
	var c0: Vector3 = bd["c0"]
	var soft := not ids.is_empty() and bool((matter[mat[ids[0]]] as Dictionary).get("cuts", false))
	_still_only = still_only
	_way_near = _near_for_body(ids)
	# how deep each sphere may go: a touch past where it is clear, and no deeper than it is where it is already in (it
	# rests in its dish as it is taken up) - never a little more each substep, which walked it through a glass wall
	var deep := PackedFloat32Array()
	deep.resize(ids.size())
	var nearest := INF
	var step := 0.0
	for k in ids.size():
		var q := c0 + rest[k]
		var d := _depth_of(now * q, minf(rc[ids[k]], r[ids[k]]), soft)
		deep[k] = d if d < -HELD_SLACK else -HELD_SLACK
		nearest = minf(nearest, d)
		step = maxf(step, (want * q).distance_to(now * q))
	# NOTHING IN REACH this substep: there, unasked
	if nearest > step + HELD_SLACK or _clear(bd, want, deep, soft):
		_still_only = false
		return want
	var got := _furthest(bd, now, want, deep, soft)
	# ...ON ALONG WHAT STOPPED IT: the rest of the way level, or straight down or up - the way its middle has left to go,
	# never the way a pose's origin has: that lies where the body was made, a meter off, and the least turn between two
	# poses swung it centimeters - a tear wedged between a pestle and its mortar had been slid 8 cm up and out in a frame
	var left := want * c0 - got * c0
	for way in [Vector3(left.x, 0.0, left.z), Vector3(0.0, left.y, 0.0)]:
		var w3: Vector3 = way
		if w3.length() < 1e-5:
			continue
		var slid := Transform3D(got.basis, got.origin + w3)
		got = slid if _clear(bd, slid, deep, soft) else _furthest(bd, got, slid, deep, soft)
	_still_only = false
	return got


## Body [param bd]'s pose [param s] of the way from [param a] to [param b]: its middle straight from one to the other,
## turned about it - never about a pose's origin, which lies where the body was made.
static func _between(bd: Dictionary, a: Transform3D, b: Transform3D, s: float) -> Transform3D:
	var c0: Vector3 = bd["c0"]
	var r := Basis(a.basis.get_rotation_quaternion().slerp(b.basis.get_rotation_quaternion(), s))
	return Transform3D(r, (a * c0).lerp(b * c0, s) - r * c0)


## The furthest any sphere of body [param bd] goes from pose [param a] to pose [param b] (meters).
func _moved_most(bd: Dictionary, a: Transform3D, b: Transform3D) -> float:
	var most := 0.0
	var rest: PackedVector3Array = bd["rest"]
	var c0: Vector3 = bd["c0"]
	for q in rest:
		most = maxf(most, (b * (c0 + q)).distance_to(a * (c0 + q)))
	return most


## Whether a solid near body [param bd] is moving this substep: what it rides or what pushes it moves it, sphere by sphere.
func _near_moving(bd: Dictionary) -> bool:
	var box := AABB(bd["c"] as Vector3, Vector3.ZERO)
	for i in bd["ids"]:
		box = box.expand(_p[i])
	box = box.grow(SPHERE.y)
	for c in _nid.size():
		if not (_nx[c] as Transform3D).is_equal_approx(_n0[c]) and (_nb[c] as AABB).intersects(box):
			return true
	return false


## Body [param bd]'s pose now: what carries a point of it as it was made to where it is.
func body_pose_of(bd: Dictionary) -> Transform3D:
	return Transform3D(Basis(bd["q"] as Quaternion), bd["c"] as Vector3) * Transform3D(Basis.IDENTITY, -(bd["c0"] as Vector3))


## The furthest of the way from [param from] to [param to] body [param bd] can go whole, nothing deeper than [param deep]
## (each sphere's own) - halved down to a sixteenth of it.
func _furthest(bd: Dictionary, from: Transform3D, to: Transform3D, deep: PackedFloat32Array, soft: bool) -> Transform3D:
	var lo := 0.0
	var hi := 1.0
	for it in 4:
		var mid := (lo + hi) * 0.5
		if _clear(bd, _between(bd, from, to, mid), deep, soft):
			lo = mid
		else:
			hi = mid
	return _between(bd, from, to, lo)


## Whether body [param bd] posed [param x] is nowhere deeper in a solid (or the table's top) than [param deep] allows.
func _clear(bd: Dictionary, x: Transform3D, deep: PackedFloat32Array, soft: bool) -> bool:
	var ids: PackedInt32Array = bd["ids"]
	var rest: PackedVector3Array = bd["rest"]
	var c0: Vector3 = bd["c0"]
	for k in ids.size():
		if alive[ids[k]] == 1 and _depth_of(x * (c0 + rest[k]), minf(rc[ids[k]], r[ids[k]]), soft) < float(deep[k]):
			return false
	return true


## Which of the near solids (their places in [member _nid]) sphere [param i] may meet this frame: all, for one woken part way through it.
func _near_for(i: int) -> PackedInt32Array:
	var by: Variant = _near_of[i] if i < _near_of.size() else null
	return by if by != null else _near_all


## Which of the near solids a body made of [param ids] may meet this frame: any its spheres may.
func _near_for_body(ids: PackedInt32Array) -> PackedInt32Array:
	var seen := PackedByteArray()
	seen.resize(_nid.size())
	for i in ids:
		for c in _near_for(i):
			if c < seen.size():
				seen[c] = 1
	var out := PackedInt32Array()
	for c in seen.size():
		if seen[c] == 1:
			out.append(c)
	return out


## How far a sphere at [param p] of radius [param rad] is into the nearest solid this substep, or the table's top (meters,
## less than 0 in it): its surface's distance from theirs.
func _depth_of(p: Vector3, rad: float, soft: bool) -> float:
	var d := p.y - rad - _top
	for c in _way_near:
		if not (_nb[c] as AABB).has_point(p) or (soft and _ne[c] == 1):
			continue
		# ...only the still ones, where a body goes sphere by sphere as a moving one pushes it ([method _way])
		if _still_only and not (_nx[c] as Transform3D).is_equal_approx(_n0[c]):
			continue
		d = minf(d, (_nf[c] as ShapeField).sample((_ni[c] as Transform3D) * p).x - rad)
	return d


func _is_held(i: int) -> bool:
	return body[i] >= 0 and (bodies[body[i]] as Dictionary)["held"] != null


## Particle [param i] kept out of the solids near it (and the table's top), its slide along each held by friction against
## that solid's own motion over the substep - and a fast one stopped where it first meets one, not passed through it.
func _solid_pass(i: int) -> void:
	var rad := minf(rc[i], r[i])
	var bends := body[i] >= 0 and (bodies[body[i]] as Dictionary).has("links")
	var near := _near_for(i)
	_way_near = near
	var from := x[i]
	var p := _p[i]
	# A FAST ONE IS TAKEN IN PIECES: the first piece that meets a solid is where it stops
	var way := p - from
	var pieces := mini(int(ceil(way.length() / minf(rad, THIN * 0.5))), 12)
	if pieces > 1:
		for k in range(1, pieces):
			var q := from + way * (float(k) / float(pieces))
			if _deepest(q, bool((matter[mat[i]] as Dictionary).get("cuts", false))) < 0.0:
				p = from + way * (float(k - 1) / float(pieces))
				break
	var ms := mus[i]
	var mk := muk[i]
	var up_most := -INF
	# A BLADE GOES THROUGH WHAT IT CUTS, never shoving it: pushed out of a blade's thin edge, a sphere it had just come
	# down past was flung across the table, and crushed against the board in going ([method _cut_through])
	var soft := bool((matter[mat[i]] as Dictionary).get("cuts", false))
	for c in near:
		if not (_nb[c] as AABB).has_point(p) or (soft and _ne[c] == 1):
			continue
		var inv: Transform3D = _ni[c]
		var local := inv * p
		var f: Vector4 = (_nf[c] as ShapeField).sample(local)
		# ...A SHEET'S POINT MEETS A THIN TOOL AT ITS WHOLE RADIUS: a 7 mm handle went between its points, a centimeter apart, and on through it (feedback 0012)
		var meets := float(r[i]) if bends and _nr[c] == 1 else rad
		if f.x >= meets:
			continue
		var xf: Transform3D = _nx[c]
		var nn := (xf.basis * Vector3(f.y, f.z, f.w)).normalized()
		var pen := meets - f.x
		# ...AND NO FASTER THAN THAT TOOL GOES: out of the solid itself at once, off it gently - never a whip
		if bends:
			pen = minf(pen, maxf(rad - f.x, (xf * local - (_n0[c] as Transform3D) * local).length() + SOFT_PUSH * _h))
		p += nn * pen
		# WHAT HOLDS IT UP is what it rests on, the contact facing up the most - never a pestle pressing it from above
		if nn.y > up_most:
			up_most = nn.y
			touch[i] = _nid[c]
		# the solid's own motion at that point over the substep - none, to what rides in it
		var sv := Vector3.ZERO if (i < _ride.size() and _ride[i] == _nid[c]) else xf * local - (_n0[c] as Transform3D) * local
		# PRESSED by a moving solid on its side or over it (a pestle); one under it carries it (a board carried and tipped:
		# taken as squeezing, a carrot's cut pieces were crushed to lumps on the way to the pot) - and one let go, settling
		# by its own weight, only rests on it (841899: a stopper let go in its jar's mouth as the jar was set down crushed the
		# tears under it, and their pieces flew out onto the table and the saucer beside it)
		if sv.length_squared() > 1e-10 and nn.dot(Vector3.UP) < CARRIED:
			if _np[c] == 1:
				_pressed[i] += pen
		else:
			_held_by[i] = 1
		var d := (p - from) - sv
		var t := d - nn * d.dot(nn)
		var lt := t.length()
		var smu: Vector2 = _nmu[c]
		var cs := sqrt(ms * smu.x)
		var ck := sqrt(mk * smu.y)
		# ...A SHEET SLIDES OFF WHAT MOVES IT: pushed, never gripped - a feather's points in a ladle's bowl were dragged up with it as it left, and over the pot's rim (841899)
		if bends and sv.length_squared() > 1e-12:
			continue
		if lt > 1e-9:
			p -= t if lt < cs * pen else t * minf(ck * pen / lt, 1.0)
	# A WALL AT REST IS NEVER CROSSED: a center outside a still solid as the substep began is never left inside it - pushed
	# out of a moving one into a thin wall, past the wall's middle, the wall's own way out is through its far side (841899:
	# the ladle stirring the brew pressed crushed frankincense through the cauldron's floor into the brazier). It goes back
	# to where its way first came into the wall, and out of it on the side it came from.
	for c in near:
		if not (_nb[c] as AABB).has_point(p) or (soft and _ne[c] == 1) or not (_nx[c] as Transform3D).is_equal_approx(_n0[c]):
			continue
		var inv: Transform3D = _ni[c]
		var field: ShapeField = _nf[c]
		if field.sample(inv * p).x >= 0.0 or field.sample(inv * from).x < 0.0:
			continue
		var lo := 0.0
		var hi := 1.0
		for _k in 10:
			var mid := (lo + hi) * 0.5
			if field.sample(inv * from.lerp(p, mid)).x >= 0.0:
				lo = mid
			else:
				hi = mid
		var q := from.lerp(p, lo)
		var fq := field.sample(inv * q)
		p = q + ((_nx[c] as Transform3D).basis * Vector3(fq.y, fq.z, fq.w)).normalized() * maxf(rad - fq.x, 0.0)
	if p.y < _top + rad:
		var pen := _top + rad - p.y
		p.y = _top + rad
		_held_by[i] = 1
		if up_most < 1.0:
			touch[i] = TABLE
		var t := Vector3(p.x - from.x, 0.0, p.z - from.z)
		var lt := t.length()
		var cs := sqrt(ms * TABLE_FRICTION.x)
		var ck := sqrt(mk * TABLE_FRICTION.y)
		if lt > 1e-9:
			p -= t if lt < cs * pen else t * minf(ck * pen / lt, 1.0)
	_p[i] = p


## How far [param q] is inside the nearest solid: less than 0 where it is in one.
func _deepest(q: Vector3, soft := false) -> float:
	var best := INF
	for c in _way_near:
		if not (_nb[c] as AABB).has_point(q) or (soft and _ne[c] == 1):
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
func _match(bi: int, apply := true) -> void:
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
	if not apply:
		return
	var R2 := Basis(q)
	for k in live:
		var i := ids[int(k)]
		_p[i] = c + R2 * rest[int(k)]


## BODY [param bi] BENDS FROM NOW ON ([constant SOFT_MOST]): linked to its [constant SOFT_NEAR] nearest points as it was made, for its stretch, and across each point it is linked
## through, for its bend: a link's length is all a flat sheet and a bent one differ by. What a grid of rows and columns would be, from any outline's points.
func make_soft(bi: int) -> void:
	var b: Dictionary = bodies[bi]
	var rest: PackedVector3Array = b["rest"]
	var n_pts := rest.size()
	if n_pts < 3:
		return
	var near: Array = []          # each point's linked points
	for a in n_pts:
		near.append({})
	var links := PackedInt32Array()
	var lens := PackedFloat32Array()
	for a in n_pts:
		var ds: Array = []
		for c in n_pts:
			if c != a:
				ds.append([rest[a].distance_squared_to(rest[c]), c])
		ds.sort_custom(func(u: Array, w2: Array) -> bool: return float(u[0]) < float(w2[0]))
		for k in mini(SOFT_NEAR, ds.size()):
			var c := int((ds[k] as Array)[1])
			if not (near[a] as Dictionary).has(c):
				(near[a] as Dictionary)[c] = true
				(near[c] as Dictionary)[a] = true
				links.append_array([a, c])
				lens.append(rest[a].distance_to(rest[c]))
	var across := PackedInt32Array()
	var across_lens := PackedFloat32Array()
	var seen := {}
	for m in n_pts:
		var round_m: Array = (near[m] as Dictionary).keys()
		for u in round_m:
			for w2 in round_m:
				var ua := int(u)
				var wa := int(w2)
				if ua >= wa or (near[ua] as Dictionary).has(wa) or seen.has(Vector2i(ua, wa)):
					continue
				# ...only one that runs on through the point: a corner of its links would hold nothing straight
				if (rest[ua] - rest[m]).normalized().dot((rest[wa] - rest[m]).normalized()) > -0.7:
					continue
				seen[Vector2i(ua, wa)] = true
				across.append_array([ua, wa])
				across_lens.append(rest[ua].distance_to(rest[wa]))
	b["links"] = links
	b["lens"] = lens
	b["across"] = across
	b["across_lens"] = across_lens
	var off := PackedVector3Array()
	off.resize(n_pts)
	b["off"] = off


## ONE PASS OF SHEET [param bi]: its links' lengths, its bend's, and a little way back to its own shape - and, whatever comes of them, where it is on the whole.
func _soft_pass(bi: int) -> void:
	var b: Dictionary = bodies[bi]
	var ids: PackedInt32Array = b["ids"]
	_links(ids, b["links"], b["lens"], SOFT_STRETCH)
	_links(ids, b["across"], b["across_lens"], SOFT_BEND)
	_match(bi, false)
	var rest: PackedVector3Array = b["rest"]
	var R := Basis(b["q"] as Quaternion)
	var c: Vector3 = b["c"]
	for k in ids.size():
		var i := ids[k]
		if alive[i] == 1:
			_p[i] += (c + R * rest[k] - _p[i]) * SOFT_SHAPE


func _links(ids: PackedInt32Array, links: PackedInt32Array, lens: PackedFloat32Array, firm: float) -> void:
	for e in lens.size():
		var i := ids[links[e * 2]]
		var j := ids[links[e * 2 + 1]]
		var d := _p[j] - _p[i]
		var l := d.length()
		if l < 1e-7 or alive[i] == 0 or alive[j] == 0:
			continue
		var move := d * ((l - lens[e]) / l * 0.5 * firm)
		_p[i] += move
		_p[j] -= move


## What one of sheet [param bd]'s points goes, over and above its links' neighbors, evened out a little along them.
func _soft_calm(bd: Dictionary) -> void:
	var ids: PackedInt32Array = bd["ids"]
	var links: PackedInt32Array = bd["links"]
	for e in range(0, links.size(), 2):
		var i := ids[links[e]]
		var j := ids[links[e + 1]]
		if alive[i] == 0 or alive[j] == 0 or asleep[i] == 1 or asleep[j] == 1:
			continue
		var dv := (v[j] - v[i]) * SOFT_CALM
		v[i] += dv
		v[j] -= dv


## Sheet [param bd] where a hand has it, posed [param t]: each point where the hand's rigid hold has it, plus what is left of how it was bent as it was taken up.
func _ease_held(bd: Dictionary, t: Transform3D) -> void:
	var ids: PackedInt32Array = bd["ids"]
	var rest: PackedVector3Array = bd["rest"]
	var off: PackedVector3Array = bd["off"]
	var c0: Vector3 = bd["c0"]
	for k in ids.size():
		off[k] *= HELD_STRAIGHTENS
		_p[ids[k]] = t * (c0 + rest[k] + off[k])
	bd["off"] = off


## HOW BENT SHEET [param bi] IS NOW: each point from where it would be in its own shape, as it was made ([method body_pose]) - what is drawn ([SheetBend]).
func bent(bi: int) -> PackedVector3Array:
	var b: Dictionary = bodies[bi]
	var ids: PackedInt32Array = b["ids"]
	var rest: PackedVector3Array = b["rest"]
	var c0: Vector3 = b["c0"]
	var inv := body_pose_of(b).affine_inverse()
	var out := PackedVector3Array()
	out.resize(ids.size())
	for k in ids.size():
		if alive[ids[k]] == 1:
			out[k] = inv * x[ids[k]] - (c0 + rest[k])
	return out


## WHAT IS STILL SLEEPS, on its host: the solid it is in or last met - or, resting on others, theirs.
func _settle(dt: float, act: PackedInt32Array) -> void:
	# A HEAP AT REST SLEEPS WHOLE: one pass of the constraints leaves a few of a heap's grains trembling however they
	# are damped ([constant SETTLE]) - in the-quiet-crucible 707668's jar of iron filings, set back on the bench, a dozen
	# of 165 at 1 to 7 cm a second while the rest lay still - and each pushed its sleeping neighbors awake, so the heap
	# never slept and the bake ran at half the show's pace from then on. Grains of one part slower than SLEEP_SPEED on
	# the whole, none of them faster than TREMBLE, are at rest: the trembling ones are still with them. And they sleep
	# TOGETHER, once most of them have been still SLEEP_AFTER - a few asleep under the rest give them nothing to rest on
	# but what no longer gives, they are jolted, and wake the sleepers again: measured, a quarter-second cycle of it.
	var heaps := {}
	for i in act:
		if alive[i] == 0 or body[i] >= 0:
			continue
		var hp: Vector3 = heaps.get(owner[i], Vector3.ZERO)
		var sp := v[i].length()
		heaps[owner[i]] = Vector3(hp.x + sp, hp.y + 1.0, maxf(hp.z, sp))
	var resting := {}
	for o in heaps:
		var hp: Vector3 = heaps[o]
		if hp.x / hp.y < SLEEP_SPEED and hp.z < TREMBLE:
			resting[o] = true
	# A BODY IS HELD UP AS A WHOLE: its upper spheres touch nothing but itself, and a thing in layers (a carrot two spheres
	# thick) had never slept once woken
	var borne := {}
	for i in act:
		if body[i] >= 0 and (_held_by[i] == 1 or _afloat(i)):
			borne[body[i]] = true
	# ...AND ONE TREMBLING IN PLACE: none of it further than SLEEP_DRIFT from where it was when it last went further
	var in_place := {}
	for i in act:
		var bi := body[i]
		if bi < 0 or in_place.has(bi):
			continue
		var b: Dictionary = bodies[bi]
		var c: Vector3 = b["c"]
		var q: Quaternion = b["q"]
		if not b.has("span"):
			var span := 0.0
			for p in (b["rest"] as PackedVector3Array):
				span = maxf(span, p.length())
			b["span"] = span + r[i]
		if b.has("anchor_c") and c.distance_to(b["anchor_c"]) + q.angle_to(b["anchor_q"]) * float(b["span"]) < SLEEP_DRIFT:
			in_place[bi] = true
		else:
			b["anchor_c"] = c
			b["anchor_q"] = q
			in_place[bi] = false
	var calm := PackedInt32Array()
	var ripe := {}
	for i in act:
		if alive[i] == 0 or _is_held(i):
			continue
		var heap := body[i] < 0 and resting.has(owner[i])
		# ...A BODY AFLOAT NEVER SLEEPS: what it floats on is never still ([method current])
		if body[i] >= 0 and wet[i] >= 0 and rho[i] < LIQUID_DENSITY:
			still[i] = 0.0
			continue
		if ((v[i].length() < SLEEP_SPEED or bool(in_place.get(body[i], false))) and (_held_by[i] == 1 or borne.has(body[i]) or _afloat(i))) or heap:
			still[i] = maxf(still[i], 0.0) + dt
		else:
			still[i] = 0.0
		if heap:
			ripe[owner[i]] = (ripe.get(owner[i], Vector2i.ZERO) as Vector2i) + Vector2i(1 if still[i] >= SLEEP_AFTER else 0, 1)
		elif still[i] >= SLEEP_AFTER:
			calm.append(i)
	for i in act:
		if alive[i] == 1 and body[i] < 0 and ripe.has(owner[i]) and not _is_held(i):
			var c: Vector2i = ripe[owner[i]]
			if c.x * 2 >= c.y:
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
	var fell := {}
	for i in keep:
		if body[i] >= 0:
			fell[body[i]] = true
		# ...what floats, on what holds its liquid
		var hs := int((_liquids[wet[i]] as Dictionary).get("solid", -1)) if touch[i] < 0 and _afloat(i) else _host_of(i)
		asleep[i] = 1
		v[i] = Vector3.ZERO
		host[i] = hs
		var hx: Transform3D = (_solids[hs] as Dictionary)["xf"] if hs >= 0 else Transform3D.IDENTITY
		hloc[i] = hx.affine_inverse() * x[i]
		hup[i] = hx.basis.y.normalized()
	# ...and EACH BODY THAT FELL ASLEEP NOW, never one asleep already: hosted again where it lies each frame, a sleeping body's
	# pose stayed where it had been as its host was carried off, its spheres riding with the host unseen - the-quiet-crucible
	# 841899's jar of sulfur went home and its lumps "remain on the table", whenever anything else on the table was awake
	for bi in bodies.size():
		var b: Dictionary = bodies[bi]
		if b["held"] != null or not fell.has(bi) or not body_asleep(bi):
			continue
		var ids: PackedInt32Array = b["ids"]
		# its spheres share one host: the inside its middle is in, else what holds up its lowest sphere - never one over the
		# rest of it (an upper sphere of a carrot cut through took the knife beside it, and the piece rode off on the knife)
		var hs := _inside_at(b["c"])
		if hs < 0:
			var low := -1
			for i in ids:
				if alive[i] == 1 and (low < 0 or x[i].y - r[i] < x[low].y - r[low]):
					low = i
			hs = host[low] if low >= 0 else host[ids[0]]
		for i in ids:
			if alive[i] == 1:
				host[i] = hs
				var hx: Transform3D = (_solids[hs] as Dictionary)["xf"] if hs >= 0 else Transform3D.IDENTITY
				hloc[i] = hx.affine_inverse() * x[i]
				hup[i] = hx.basis.y.normalized()
		var hx2: Transform3D = (_solids[hs] as Dictionary)["xf"] if hs >= 0 else Transform3D.IDENTITY
		b["hrel"] = hx2.affine_inverse() * Transform3D(Basis(b["q"] as Quaternion), b["c"] as Vector3)


## Whether particle [param i] floats on a calm liquid: held up by it, as by what is under it - so it sleeps there, and
## wakes as the liquid is stirred, tipped or struck (pumpkin seeds left afloat in a pot had kept the bake busy to the end
## of the show).
func _afloat(i: int) -> bool:
	if wet[i] < 0 or wet[i] >= _liquids.size():
		return false
	var l: Dictionary = _liquids[wet[i]]
	return absf(float(l.get("swirl", 0.0))) < CALM_SWIRL and (l["n"] as Vector3).dot(Vector3.UP) > CALM_LEVEL


## The host particle [param i] sleeps on: THE INSIDE IT IS IN first - what is in a jar goes where the jar goes, whatever
## in it it last met (the-quiet-crucible 841899: crushed frankincense asleep on the pestle that pressed it, and sulfur
## asleep on the lumps under it, stayed behind as their mortar and jar were carried off) - else the solid it rests on,
## or what the spheres it rests on sleep on, or -1 (the table).
func _host_of(i: int) -> int:
	var inside := _inside_at(x[i])
	if inside >= 0:
		return inside
	if touch[i] >= 0:
		return touch[i]
	if touch[i] == TABLE:
		return -1
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
	# in a hollow, by its field: the nearest solid within a few centimeters - never a blade, to what a blade cuts
	var near := -1
	var nd := 0.03
	var soft := bool((matter[mat[i]] as Dictionary).get("cuts", false))
	for si in _solids.size():
		var s: Dictionary = _solids[si]
		if not (s["wbox"] as AABB).grow(0.03).has_point(x[i]) or (soft and bool(s.get("edge", false))):
			continue
		var d := (s["field"] as ShapeField).sample((s["inv"] as Transform3D) * x[i]).x
		if d < nd:
			nd = d
			near = si
	return near


## The solid whose inside holds [param p] (the table's space), the smallest of them (a vial stood in a pot), or -1 -
## where each is as the frame ends, or as it began ([param start]).
func _inside_at(p: Vector3, start := false) -> int:
	var best := -1
	var least := INF
	for vd in _vessels:
		var si := int((vd as Dictionary)["solid"])
		if si < 0 or si >= _solids.size():
			continue
		var sd: Dictionary = _solids[si]
		var xf: Transform3D = sd["xf0"] if start and sd.has("xf0") else sd["xf"]
		if not bool(sd.get("on", true)) or not (xf * (sd["box"] as AABB)).grow(SPHERE.y).has_point(p):
			continue
		var vs: Vessel = (vd as Dictionary)["vessel"]
		if vs.volume < least and vs.contains(xf.affine_inverse() * p):
			least = vs.volume
			best = si
	return best


## Sleeper [param i] - and the body it is a sphere of - asleep on solid [param si] from now, where that solid was as the
## frame began.
func _rehost(i: int, si: int) -> void:
	var hx: Transform3D = (_solids[si] as Dictionary)["xf0"]
	var inv := hx.affine_inverse()
	var ids := PackedInt32Array([i]) if body[i] < 0 else ((bodies[body[i]] as Dictionary)["ids"] as PackedInt32Array)
	for k in ids:
		if alive[k] == 1:
			host[k] = si
			hloc[k] = inv * x[k]
			hup[k] = hx.basis.y.normalized()
	if body[i] >= 0:
		var b: Dictionary = bodies[body[i]]
		b["hrel"] = inv * Transform3D(Basis(b["q"] as Quaternion), b["c"] as Vector3)


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
	# a piece ground apart is drawn as its pieces, cut or not
	b["cut"] = false
	_reform(bi, a)
	var nb := bodies.size()
	bodies.append({"ids": PackedInt32Array(), "rest": PackedVector3Array(), "c0": c, "c": c, "q": Quaternion.IDENTITY, "intact": false,
		"held": null, "hrel": Transform3D.IDENTITY, "made_by": int(b.get("made_by", -1)), "piece_of": int(b.get("piece_of", bi))})
	_reform(nb, bb)
	events.append({"kind": "break", "body": int(b.get("piece_of", bi)), "at": c, "size": r[live[0]]})


## A BLADE CUTS ([constant TablePhysics] gives a solid with an `edge` its `edge`): a loose thing of matter a blade cuts (a
## root, a candle, a sheet - [method add_matter]) that a moving blade has come down into - the blade's lowest point
## [constant CUT_INTO] of the thing's height below its top - is parted along the blade's own plane (its thinnest way),
## each side a body of its own and rigid, and the wedge of the blade pushes them [constant WEDGE] apart. A side with
## none of its spheres is no cut: the blade went past it. The user, 2026-10-29: "cut it into pieces (Fruit Ninja style,
## which is to say - with real cutting dynamics)".
func _cut_through() -> void:
	for si in _near:
		var sd: Dictionary = _solids[si]
		if not bool(sd.get("edge", false)) or not bool(sd.get("moving", false)) or not bool(sd.get("on", true)):
			continue
		var box: AABB = sd["box"]
		var xf: Transform3D = sd["xf"]
		var thin := Vector3.RIGHT
		var width := box.size.x
		if box.size.y < box.size.x and box.size.y <= box.size.z:
			thin = Vector3.UP
			width = box.size.y
		elif box.size.z < box.size.x:
			thin = Vector3.BACK
			width = box.size.z
		var nn := (xf.basis * thin).normalized()
		width *= (xf.basis * thin).length()
		var p0 := xf * box.get_center()
		var wb: AABB = sd["wbox"]
		for bi in bodies.size():
			var b: Dictionary = bodies[bi]
			if b["held"] != null:
				continue
			var live := PackedInt32Array()
			var lo := Vector3(INF, INF, INF)
			var hi := Vector3(-INF, -INF, -INF)
			for i in (b["ids"] as PackedInt32Array):
				if alive[i] == 1:
					live.append(i)
					lo = lo.min(x[i] - Vector3.ONE * r[i])
					hi = hi.max(x[i] + Vector3.ONE * r[i])
			if live.size() < 2 or not bool((matter[mat[live[0]]] as Dictionary).get("cuts", false)):
				continue
			if not wb.intersects(AABB(lo, hi - lo)) or wb.position.y > hi.y - CUT_INTO * (hi.y - lo.y):
				continue
			var a := PackedInt32Array()
			var bb := PackedInt32Array()
			for i in live:
				if nn.dot(x[i] - p0) < 0.0:
					a.append(i)
				else:
					bb.append(i)
			if a.is_empty() or bb.is_empty():
				continue
			_cut_body(bi, a, bb, nn, p0, width)


## Body [param bi] cut along the plane through [param p0] square to [param nn] by a blade [param width] across: [param a]
## (behind it) stays body [param bi], [param bb] is a body of its own - both drawn as pieces of what was cut
## ([TablePhysics]) - and each side moved off the blade by half its width and [constant PARTED] more: where the blade
## went, the two are apart (left touching, the pieces of a carrot cut through lay flush and read as a carrot uncut).
func _cut_body(bi: int, a: PackedInt32Array, bb: PackedInt32Array, nn: Vector3, p0: Vector3, width: float) -> void:
	var b: Dictionary = bodies[bi]
	var was := body_pose(bi)
	b["intact"] = false
	b["cut"] = true
	_reform(bi, a)
	var c := Vector3.ZERO
	for i in bb:
		c += x[i]
	c /= float(bb.size())
	var nb := bodies.size()
	bodies.append({"ids": PackedInt32Array(), "rest": PackedVector3Array(), "c0": c, "c": c, "q": Quaternion.IDENTITY, "intact": false,
		"cut": true, "held": null, "hrel": Transform3D.IDENTITY, "made_by": int(b.get("made_by", -1)), "piece_of": int(b.get("piece_of", bi))})
	_reform(nb, bb)
	var off := width * 0.5 + PARTED
	for i in a:
		v[i] -= nn * WEDGE
		x[i] -= nn * off
	for i in bb:
		v[i] += nn * WEDGE
		x[i] += nn * off
	events.append({"kind": "cut", "body": bi, "new": nb, "was": was, "plane": Plane(nn, nn.dot(p0))})


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
	# ...a piece is rigid: its links named the points it had
	b.erase("links")


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
	rc[j] = minf(rc[i], nr)
	var nb := bodies.size()
	bodies.append({"ids": PackedInt32Array(), "rest": PackedVector3Array(), "c0": at, "c": at, "q": Quaternion.IDENTITY, "intact": false,
		"held": null, "hrel": Transform3D.IDENTITY, "made_by": int((bodies[bi] as Dictionary).get("made_by", -1)),
		"piece_of": int((bodies[bi] as Dictionary).get("piece_of", bi))})
	_reform(nb, PackedInt32Array([j]))
	events.append({"kind": "break", "body": int((bodies[bi] as Dictionary).get("piece_of", bi)), "at": x[i], "size": r[i]})


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
	return {"n": n, "x": x.duplicate(), "v": v.duplicate(), "r": r.duplicate(), "r0": r0.duplicate(), "rc": rc.duplicate(), "w": w.duplicate(),
		"mat": mat.duplicate(), "body": body.duplicate(), "alive": alive.duplicate(), "asleep": asleep.duplicate(),
		"still": still.duplicate(), "host": host.duplicate(), "hloc": hloc.duplicate(), "hup": hup.duplicate(),
		"damage": damage.duplicate(), "wet": wet.duplicate(), "owner": owner.duplicate(), "bodies": bs, "reach": reach,
		"awake_cells": awake_cells.duplicate()}


func restore(s: Dictionary) -> void:
	n = int(s["n"])
	x = (s["x"] as PackedVector3Array).duplicate()
	v = (s["v"] as PackedVector3Array).duplicate()
	r = (s["r"] as PackedFloat32Array).duplicate()
	r0 = (s["r0"] as PackedFloat32Array).duplicate()
	rc = (s["rc"] as PackedFloat32Array).duplicate() if s.has("rc") else r.duplicate()
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
	reach = s.get("reach", AABB())
	awake_cells = (s.get("awake_cells", {}) as Dictionary).duplicate()
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
static func fill_shape(f: ShapeField, box: AABB, rad: float, xf: Transform3D, most: int, spread := 1.0) -> PackedVector3Array:
	# SPHERES TO ITS EDGES: each way as many as reach from one face of its box to the other, the outermost touching them -
	# a long round thing lying on its side rests on its own surface (a 2.6 cm carrot, one row of 7 mm spheres along its
	# middle, had lain 6 mm into the board under it) - and no more than [param most], the way with the most given fewer
	var n := Vector3i(_across(box.size.x, rad, spread), _across(box.size.y, rad, spread), _across(box.size.z, rad, spread))
	# A SHEET IS ONE LAYER ON ITS OWN BENT MIDDLE ([method ShapeField.sheet_mid]): its box, a bent feather's five millimeters,
	# is not its thickness
	var sheet := f != null and f.kind == "sheet"
	# ...AND TO ITS OUTLINE: what meets the world is a point at the sheet's own thickness, so past its last point it meets nothing. A 12 cm
	# feather's rows lay 1.9 cm apart, its narrow tip between two of them, and the tip stood through the cauldron's wall (841899, feedback
	# 0010: "a little red triangle poking out") - where its middle's seven spheres had once been widened for the same report.
	var rim := _sheet_outline(f, box) if sheet else PackedVector3Array()
	var grid_most := maxi(most - rim.size(), 1)
	if sheet:
		n.y = 1
	while n.x * n.y * n.z > grid_most:
		if n.x >= n.y and n.x >= n.z and n.x > 1:
			n.x -= 1
		elif n.y >= n.z and n.y > 1:
			n.y -= 1
		elif n.z > 1:
			n.z -= 1
		else:
			break
	# ...section by section along its longest way, and where a thing narrows past the spheres across it (a carrot's tip),
	# one down its middle - every slice of it has something to be cut from
	var long := 0 if box.size.x >= box.size.y and box.size.x >= box.size.z else (1 if box.size.y >= box.size.z else 2)
	var out := PackedVector3Array()
	var c := box.get_center()
	# ...A THIN THING ACROSS ITS WHOLE FACE: a sheet thinner than its spheres has no point a quarter of one inside it, and had been
	# a single line of spheres down its middle - a 12 cm feather seven spheres 18 mm apart, its width met by nothing, its edges
	# through the cauldron's wall and a ladle through its gaps (841899). A point on it is in it.
	var thin := f.thick if sheet else minf(box.size.x, minf(box.size.y, box.size.z))
	var deep := -minf(rad * 0.25, thin * 0.25)
	for s in n[long]:
		var here := 0
		for a in n[(long + 1) % 3]:
			for b in n[(long + 2) % 3]:
				var idx := Vector3i.ZERO
				idx[long] = s
				idx[(long + 1) % 3] = a
				idx[(long + 2) % 3] = b
				var p := Vector3(_at_across(box.position.x, box.size.x, rad, idx.x, n.x), _at_across(box.position.y, box.size.y, rad, idx.y, n.y),
					_at_across(box.position.z, box.size.z, rad, idx.z, n.z))
				if sheet:
					p.y = f.sheet_mid(p.x, p.z)
				if (f == null or f.sample(p).x < deep) and out.size() < grid_most:
					out.append(xf * p)
					here += 1
		if here == 0 and out.size() < grid_most:
			var p := c
			p[long] = _at_across(box.position[long], box.size[long], rad, s, n[long])
			if sheet:
				p.y = f.sheet_mid(p.x, p.z)
			if f == null or f.sample(p).x < 0.0:
				out.append(xf * p)
	for p in rim:
		out.append(xf * p)
	if out.is_empty():
		out.append(xf * c)
	return out


## THE FARTHEST A SHEET REACHES, each of [constant SHEET_REACHES] ways round it across its box ([method fill_shape]): points on its own bent
## middle at the edge of its outline, however that narrows or runs off to one side. Found on a fine grid of the outline's own inside.
static func _sheet_outline(f: ShapeField, box: AABB) -> PackedVector3Array:
	f.prepare()
	var mid := box.get_center()
	var best: Array = []
	for k in SHEET_REACHES:
		best.append([-INF, Vector2.ZERO])
	# ...as fine each way, however long and narrow it is
	var cell := maxf(box.size.x, box.size.z) / float(SHEET_GRID)
	var nx := maxi(int(ceil(box.size.x / cell)), 1)
	var nz := maxi(int(ceil(box.size.z / cell)), 1)
	for ix in nx:
		for iz in nz:
			var q := Vector2(box.position.x + box.size.x * (float(ix) + 0.5) / float(nx), box.position.z + box.size.z * (float(iz) + 0.5) / float(nz))
			if f._at2(q).x > 0.0:
				continue
			# ...each way measured as a share of the box, so a long sheet's ends are not all its reaches
			var u := Vector2((q.x - mid.x) / maxf(box.size.x, 1e-6), (q.y - mid.z) / maxf(box.size.z, 1e-6))
			for k in SHEET_REACHES:
				var a := TAU * float(k) / float(SHEET_REACHES)
				var d := u.dot(Vector2(cos(a), sin(a)))
				if d > float((best[k] as Array)[0]):
					best[k] = [d, q]
	var out := PackedVector3Array()
	for b in best:
		if float((b as Array)[0]) == -INF:
			continue
		var q: Vector2 = (b as Array)[1]
		var p := Vector3(q.x, f.sheet_mid(q.x, q.y), q.y)
		if not out.has(p):
			out.append(p)
	return out


## How many spheres of [param rad] go across [param size] (meters), the outermost touching its ends - [param spread] times
## their touching apart at most.
static func _across(size: float, rad: float, spread := 1.0) -> int:
	return 1 if size <= rad * 2.5 else int(ceil((size - rad * 2.0) / (rad * 2.0 * spread))) + 1


## Where the [param i]-th of [param n] spheres of [param rad] across [param size] from [param lo] stands.
static func _at_across(lo: float, size: float, rad: float, i: int, n: int) -> float:
	return lo + size * 0.5 if n <= 1 else lo + rad + (size - rad * 2.0) * float(i) / float(n - 1)


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
