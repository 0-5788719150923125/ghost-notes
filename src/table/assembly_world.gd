extends RefCounted
class_name AssemblyWorld

## AssemblyWorld - THE BRICKS AS REAL BODIES: Godot's own Jolt, each piece a rigid body with its own shape and weight, falling, bouncing,
## pushing and being pushed (next/assembly.md "Real bodies"). The user of what stood here before, 2026-11-03: "bricks gently floating
## around in the air ... It's not actually digging, there's no proper physics, and the blocks clip through each other."
##
## RUN ONLY BY [AssemblyBake], in a process of its own: the engine's physics server cannot be stepped by hand, so a child Godot steps it
## under `--fixed-fps` as fast as the machine goes, and what happened is written down. Nothing in the app's frame ever waits on it.
##
## AT TEN TIMES ITS SIZE ([constant SIM]): a stud is 8 mm, and Jolt's margins are made for things a meter across. Everything in here is
## scaled going in and coming out, gravity too, so a fall still takes the time a fall takes.
##
## IT MUST COME TO REST, or every stop is a lie and every moment of silence crackles. It did not, at first (next/assembly.md "Real bodies"): 350 "hits" a second all the way
## through, on pieces rocking at 3 rad/s, where the only thing happening was a piece being carried across the table. Four things, each measured: what bounces, bounces only
## past 25 cm/s (project.godot's `bounce_velocity_threshold`: at 10x gravity a resting piece gains 0.8 m/s in a read, which at the default bounced for ever); every piece
## weighs the same to the solver ([constant MASS]); contacts have a millimeter's slop (`penetration_slop`); and a piece rocking this little IS at rest ([constant REST_SPIN]).
## The record went from under real time to eight times it, because a heap that comes to rest costs nothing.
##
## A HEAP AT REST COSTS NOTHING ([method _thaw_and_freeze]): a piece that has stopped goes static, and is only made a body again when
## something that moves comes near it. Jolt wakes everything touching what is awake, and in a tub everything touches everything: 468 of
## 600 bricks stayed awake through a small dig. So the cost of a dig is what it disturbs, however full the tub is, and since whatever moves
## thaws what is around it, nothing is left hanging when what held it goes.
##
## WHAT HAPPENED IS WRITTEN AS IT HAPPENS: each moving piece's pose, kept only where a straight line between keys would miss it
## ([method _record]), and each hit ([method _hits]) - how hard, what it hit, where - which is the only place a brick's sound comes from.

## How much bigger than the table the world is, and how often it steps.
const SIM := 10.0
const TICKS := 240
const DT := 1.0 / float(TICKS)
const G := 9.81
## What is loose is read this many ticks apart: reading it every tick was a third of a record's time, and no sound or sight needs 240 a second.
const READ_EVERY := 2
## Keys are looked at this many ticks apart (60 a second), and kept only if leaving them out would misplace a piece by this much
## (meters, and as a quaternion's dot short of 1).
const RECORD_EVERY := 4
const KEY_NEAR := 0.0002
const KEY_TURN := 0.00004
## WHAT A PIECE IS LIKE: its grip, its bounce, and how heavy a cubic centimeter of a molded (hollow) piece is against a solid one.
const FRICTION := 0.34
const BOUNCE := 0.28
const HOLLOW := 0.45
## THEY ALL WEIGH THE SAME TO THE SOLVER, whatever they weigh to the ear ([method weight_of]): a plate sixty times a 1x1 lying on it kept whatever was under it trembling for
## as long as it lay there, and a heap never came to rest. A little turning is lost to the air, where a real piece's is lost to its grip.
const MASS := 1.0
const ANGULAR_DAMP := 3.0
## HEARD ([method _hits]): the least sudden change in a piece's speed that is a hit at all (m/s - a piece at rest is held up against
## 0.08 of it every read), and how soon the same piece can be heard again (ticks).
const HIT_LEAST := 0.1
const HIT_AGAIN := 4
## ...and that it was going at least this fast, one side of it or the other: a piece resting trembles by the gravity of a read, up and down, which is twice HIT_LEAST's jitter and no hit.
const HIT_GOING := 0.1
## ...how far round a piece that has hit something is looked at, for what it hit (the world's meters), and how many things.
const ASK_MARGIN := 0.012
const ASK_MOST := 8
## A piece at rest: as slow as this (m/s, radians/s) for this long (seconds) goes static, unless something moving is this near (meters past
## its own size); and what moves faster than this thaws what is round it, this far past its size. Looked at this many ticks apart.
const REST_SPEED := 0.04
const REST_SPIN := 1.5
const REST_FOR := 0.15
const THAW_EVERY := 6
const STIR_SPEED := 0.09
const THAW_NEAR := 0.016
## The grid frozen pieces are found in (meters).
const CELL := 0.04
## How long the world may take to come to rest before a stop, at most (seconds): a piece still creeping then is under anything seen.
const SETTLE_MOST := 1.6
## What can be hit, for what it sounds like: anything else is a [constant Props.MATERIALS] kind.
const PLASTIC := "plastic"
const HAND := "hand"

enum { OUT, FROZEN, LOOSE, HELD, SEATED }

var space: RID
var pieces: Array = []            # {kind, w, d, color} each
var bodies: Array[RID] = []
var state := PackedByteArray()
var size := PackedFloat32Array()  # how far a piece reaches from its middle (meters)
var xf: Array[Transform3D] = []   # where each is (meters; for a frozen one, exact)
var mid: Array[Vector3] = []      # ...and its middle
var vel: Array[Vector3] = []
var spin: Array[Vector3] = []
var still := PackedFloat32Array()
var quiet := PackedInt32Array()
var loose: Array[int] = []
var held: Array[int] = []
var tick := 0
var tau := 0.0
var recording := true
var sources: Array = []           # what else thaws what is round it: [Vector3 (meters), reach]
var keys := {}                    # a piece -> PackedFloat32Array [tau, x, y, z, qx, qy, qz, qw]...
var seats := {}                   # a piece -> [[tau on, tau off (INF), local Transform3D]]
var events: Array = []            # [tau, x, y, z, strength, size, weight, kind, against]
var _shapes := {}
var _made: Array[RID] = []        # what else was made, for [method free_all]
var _ask := PhysicsShapeQueryParameters3D.new()
var _surface := {}                # a body's id -> what it sounds like
var _grid := {}                   # a cell -> [frozen pieces]
var _key_last: Array = []         # a piece -> [tau, pos, quat] of its last key
var _prev: Array = []             # a piece -> [tau, pos, quat] of its last sample


func _init(world_space: RID) -> void:
	space = world_space
	PhysicsServer3D.area_set_param(space, PhysicsServer3D.AREA_PARAM_GRAVITY, G * SIM)
	PhysicsServer3D.area_set_param(space, PhysicsServer3D.AREA_PARAM_LINEAR_DAMP, 0.0)
	PhysicsServer3D.area_set_param(space, PhysicsServer3D.AREA_PARAM_ANGULAR_DAMP, 0.0)


# --- what the shapes are -----------------------------------------------------------------------------------------

## THE SHAPES OF A PART: `[[shape, local transform]...]`, scaled to the world's size, its origin the middle of its underside as the mesh's is
## ([AssemblyMeshes]). As tall as its studs: a piece lies ON another's studs, and that is what stops them going through each other. Its
## hollow underside is left closed, and a stud that would have gone up into it stays out: nothing shows of that but a hair's air.
func shapes_of(kind: String, w: int, d: int) -> Array:
	var key := "%s %dx%d" % [kind, w, d]
	if _shapes.has(key):
		return _shapes[key]
	var hw := float(w) * Assembly.STUD * 0.5
	var hd := float(d) * Assembly.STUD * 0.5
	var row: Dictionary = Assembly.KINDS[kind]
	var tall := float(row["h"]) * Assembly.PLATE
	var top := tall + (Assembly.STUD_H if String(row["studs"]) != "none" else 0.0)
	var out: Array = []
	match kind:
		"slope":
			var low := Assembly.PLATE * AssemblyMeshes.LOW_EDGE
			var back := -hd + Assembly.STUD
			var pts := PackedVector3Array()
			for x in [-hw, hw]:
				for p in [Vector3(x, 0.0, -hd), Vector3(x, 0.0, hd), Vector3(x, low, hd), Vector3(x, tall, back), Vector3(x, top, back), Vector3(x, top, -hd)]:
					pts.append((p as Vector3) * SIM)
			var s := PhysicsServer3D.convex_polygon_shape_create()
			PhysicsServer3D.shape_set_data(s, pts)
			out.append([s, Transform3D.IDENTITY])
		"round":
			var sides := 10
			var r := hw
			var pts := PackedVector3Array()
			for i in sides:
				var a := TAU * float(i) / float(sides)
				for y in [0.0, top]:
					pts.append(Vector3(cos(a) * r, y, sin(a) * r) * SIM)
			var s := PhysicsServer3D.convex_polygon_shape_create()
			PhysicsServer3D.shape_set_data(s, pts)
			out.append([s, Transform3D.IDENTITY])
		"arch":
			# ...two legs and a span, which is what lets one hook over another in a heap
			var leg_tall := Assembly.PLATE * 3.0
			out.append(_box(Vector3(-hw, 0.0, -hd), Vector3(hw, leg_tall, -hd + Assembly.STUD)))
			out.append(_box(Vector3(-hw, 0.0, hd - Assembly.STUD), Vector3(hw, leg_tall, hd)))
			out.append(_box(Vector3(-hw, leg_tall, -hd), Vector3(hw, top, hd)))
		_:
			out.append(_box(Vector3(-hw, 0.0, -hd), Vector3(hw, top, hd)))
	_shapes[key] = out
	return out


func _box(lo: Vector3, hi: Vector3) -> Array:
	var s := PhysicsServer3D.box_shape_create()
	PhysicsServer3D.shape_set_data(s, (hi - lo) * SIM * 0.5)
	return [s, Transform3D(Basis.IDENTITY, (lo + hi) * SIM * 0.5)]


## All of it let go: a process that leaves it to the engine says so in the app's log.
func free_all() -> void:
	for b in bodies:
		PhysicsServer3D.free_rid(b)
	for r in _made:
		PhysicsServer3D.free_rid(r)
	for k in _shapes:
		for s in _shapes[k]:
			PhysicsServer3D.free_rid((s as Array)[0])
	PhysicsServer3D.free_rid(space)


## How heavy a part is, for the world: only against other parts.
static func weight_of(kind: String, w: int, d: int) -> float:
	var row: Dictionary = Assembly.KINDS[kind]
	var cm3 := float(w) * 0.8 * float(d) * 0.8 * float(row["h"]) * 0.32
	return maxf(cm3 * HOLLOW * (0.6 if kind == "arch" else 1.0), 0.05)


# --- what stands in it -------------------------------------------------------------------------------------------

## What cannot move: [param faces] (meters, in threes) as a surface that sounds like [param sound], the outsides and insides of a thing.
func add_surface(faces: PackedVector3Array, sound: String) -> RID:
	if faces.is_empty():
		return RID()
	var big := PackedVector3Array()
	big.resize(faces.size())
	for i in faces.size():
		big[i] = faces[i] * SIM
	var s := PhysicsServer3D.concave_polygon_shape_create()
	PhysicsServer3D.shape_set_data(s, {"faces": big, "backface_collision": true})
	var b := PhysicsServer3D.body_create()
	_made.append_array([b, s])
	PhysicsServer3D.body_set_mode(b, PhysicsServer3D.BODY_MODE_STATIC)
	PhysicsServer3D.body_add_shape(b, s)
	PhysicsServer3D.body_set_param(b, PhysicsServer3D.BODY_PARAM_FRICTION, 0.42)
	PhysicsServer3D.body_set_param(b, PhysicsServer3D.BODY_PARAM_BOUNCE, 0.2)
	PhysicsServer3D.body_set_space(b, space)
	_surface[b.get_id()] = sound
	return b


## A flat box that cannot move (meters): the table, the plate.
func add_slab(at: Transform3D, half: Vector3, sound: String) -> RID:
	var s := PhysicsServer3D.box_shape_create()
	PhysicsServer3D.shape_set_data(s, half * SIM)
	var b := PhysicsServer3D.body_create()
	_made.append_array([b, s])
	PhysicsServer3D.body_set_mode(b, PhysicsServer3D.BODY_MODE_STATIC)
	PhysicsServer3D.body_add_shape(b, s)
	PhysicsServer3D.body_set_param(b, PhysicsServer3D.BODY_PARAM_FRICTION, 0.42)
	PhysicsServer3D.body_set_param(b, PhysicsServer3D.BODY_PARAM_BOUNCE, 0.22)
	PhysicsServer3D.body_set_state(b, PhysicsServer3D.BODY_STATE_TRANSFORM, _big(at))
	PhysicsServer3D.body_set_space(b, space)
	_surface[b.get_id()] = sound
	return b


static func _big(x: Transform3D) -> Transform3D:
	return Transform3D(x.basis, x.origin * SIM)


## The pieces there are, none of them in the world yet.
func make_pieces(list: Array) -> void:
	pieces = list
	var n := list.size()
	bodies.resize(n)
	state.resize(n)
	state.fill(OUT)
	size.resize(n)
	xf.resize(n)
	mid.resize(n)
	vel.resize(n)
	spin.resize(n)
	still.resize(n)
	quiet.resize(n)
	_key_last.resize(n)
	_prev.resize(n)
	for id in n:
		var q: Dictionary = list[id]
		var kind := String(q["kind"])
		var w := int(q["w"])
		var d := int(q["d"])
		var b := PhysicsServer3D.body_create()
		PhysicsServer3D.body_set_mode(b, PhysicsServer3D.BODY_MODE_STATIC)
		for s in shapes_of(kind, w, d):
			PhysicsServer3D.body_add_shape(b, (s as Array)[0], (s as Array)[1])
		PhysicsServer3D.body_set_param(b, PhysicsServer3D.BODY_PARAM_MASS, MASS)
		PhysicsServer3D.body_set_param(b, PhysicsServer3D.BODY_PARAM_FRICTION, FRICTION)
		PhysicsServer3D.body_set_param(b, PhysicsServer3D.BODY_PARAM_BOUNCE, BOUNCE)
		PhysicsServer3D.body_set_param(b, PhysicsServer3D.BODY_PARAM_ANGULAR_DAMP, ANGULAR_DAMP)
		PhysicsServer3D.body_set_param(b, PhysicsServer3D.BODY_PARAM_ANGULAR_DAMP_MODE, PhysicsServer3D.BODY_DAMP_MODE_REPLACE)
		# ...A PLATE IS THIN AND SO IS A TIN WALL: at a meter a second a plate goes nearly its own thickness in a step, and through a wall in two
		PhysicsServer3D.body_set_enable_continuous_collision_detection(b, true)
		bodies[id] = b
		size[id] = Vector3(float(w) * Assembly.STUD, float((Assembly.KINDS[kind] as Dictionary)["h"]) * Assembly.PLATE, float(d) * Assembly.STUD).length() * 0.5
		xf[id] = Transform3D.IDENTITY
		mid[id] = Vector3.ZERO


## PIECE [param id]'s middle, where it is at [param at] (its origin is under it).
func _middle(id: int, at: Transform3D) -> Vector3:
	var q: Dictionary = pieces[id]
	return at * Vector3(0.0, float((Assembly.KINDS[String(q["kind"])] as Dictionary)["h"]) * Assembly.PLATE * 0.5, 0.0)


## PIECE [param id] put in the world at [param at], as a body falling from there.
func drop_in(id: int, at: Transform3D, v := Vector3.ZERO, w := Vector3.ZERO) -> void:
	var b := bodies[id]
	PhysicsServer3D.body_set_state(b, PhysicsServer3D.BODY_STATE_TRANSFORM, _big(at))
	if state[id] == OUT:
		PhysicsServer3D.body_set_space(b, space)
	_unfile(id)
	_go_loose(id)
	xf[id] = at
	mid[id] = _middle(id, at)
	PhysicsServer3D.body_set_state(b, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, v * SIM)
	PhysicsServer3D.body_set_state(b, PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, w)
	vel[id] = v
	spin[id] = w
	_note_key(id)


## PIECE [param id] where it was left at [param at], as still as a piece can be: how a world is stood again from a checkpoint.
func place_frozen(id: int, at: Transform3D) -> void:
	var b := bodies[id]
	PhysicsServer3D.body_set_state(b, PhysicsServer3D.BODY_STATE_TRANSFORM, _big(at))
	if state[id] == OUT:
		PhysicsServer3D.body_set_space(b, space)
	_unfile(id)
	xf[id] = at
	mid[id] = _middle(id, at)
	state[id] = FROZEN
	_file(id)


func _go_loose(id: int) -> void:
	var b := bodies[id]
	PhysicsServer3D.body_set_mode(b, PhysicsServer3D.BODY_MODE_RIGID)
	PhysicsServer3D.body_set_state(b, PhysicsServer3D.BODY_STATE_SLEEPING, false)
	state[id] = LOOSE
	still[id] = 0.0
	quiet[id] = 0
	vel[id] = Vector3.ZERO
	spin[id] = Vector3.ZERO
	loose.append(id)


func _file(id: int) -> void:
	var c := _cell_of(mid[id])
	if not _grid.has(c):
		_grid[c] = []
	(_grid[c] as Array).append(id)


func _unfile(id: int) -> void:
	if state[id] != FROZEN:
		return
	var c := _cell_of(mid[id])
	if _grid.has(c):
		(_grid[c] as Array).erase(id)


static func _cell_of(p: Vector3) -> Vector3i:
	return Vector3i(floori(p.x / CELL), floori(p.y / CELL), floori(p.z / CELL))


## PIECE [param id] IN HAND: nothing moves it now but [method carry_to], and it pushes what it meets.
func take_up(id: int) -> void:
	var b := bodies[id]
	if state[id] == LOOSE:
		loose.erase(id)
	_unfile(id)
	if state[id] == OUT:
		PhysicsServer3D.body_set_state(b, PhysicsServer3D.BODY_STATE_TRANSFORM, _big(xf[id]))
		PhysicsServer3D.body_set_space(b, space)
	PhysicsServer3D.body_set_mode(b, PhysicsServer3D.BODY_MODE_KINEMATIC)
	state[id] = HELD
	held.append(id)
	_note_key(id)


func carry_to(id: int, at: Transform3D) -> void:
	PhysicsServer3D.body_set_state(bodies[id], PhysicsServer3D.BODY_STATE_TRANSFORM, _big(at))
	xf[id] = at
	mid[id] = _middle(id, at)


## PIECE [param id] LET GO, with the hand's speed.
func let_go(id: int, v := Vector3.ZERO, w := Vector3.ZERO) -> void:
	held.erase(id)
	var b := bodies[id]
	_go_loose(id)
	PhysicsServer3D.body_set_state(b, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, v * SIM)
	PhysicsServer3D.body_set_state(b, PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, w)
	vel[id] = v
	spin[id] = w


## PIECE [param id] PRESSED HOME at [param at] (the world's), [param local] of the plate: it is part of what stands there now, and goes
## with the plate from here on.
func seat(id: int, at: Transform3D, local: Transform3D) -> void:
	held.erase(id)
	var b := bodies[id]
	PhysicsServer3D.body_set_mode(b, PhysicsServer3D.BODY_MODE_STATIC)
	PhysicsServer3D.body_set_state(b, PhysicsServer3D.BODY_STATE_TRANSFORM, _big(at))
	xf[id] = at
	mid[id] = _middle(id, at)
	state[id] = SEATED
	_flush_key(id, at)
	if not seats.has(id):
		seats[id] = []
	(seats[id] as Array).append([tau, INF, local])


## PIECE [param id] OFF THE PLATE and in hand again.
func unseat(id: int) -> void:
	if seats.has(id):
		var list: Array = seats[id]
		(list[list.size() - 1] as Array)[1] = tau
	take_up(id)


## Where a seated piece went when the plate was turned.
func moved_with_plate(id: int, at: Transform3D) -> void:
	PhysicsServer3D.body_set_state(bodies[id], PhysicsServer3D.BODY_STATE_TRANSFORM, _big(at))
	xf[id] = at
	mid[id] = _middle(id, at)


# --- a tick ------------------------------------------------------------------------------------------------------

## AFTER THE WORLD HAS STEPPED: where everything got to, what hit what, what to thaw and what has stopped.
func after_step() -> void:
	tick += 1
	tau = float(tick) * DT
	if tick % READ_EVERY == 0:
		for id in loose:
			var b := bodies[id]
			var at: Transform3D = PhysicsServer3D.body_get_state(b, PhysicsServer3D.BODY_STATE_TRANSFORM)
			at.origin /= SIM
			var v: Vector3 = PhysicsServer3D.body_get_state(b, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY)
			v /= SIM
			var w: Vector3 = PhysicsServer3D.body_get_state(b, PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY)
			xf[id] = at
			mid[id] = _middle(id, at)
			if recording:
				_hits(id, b, at, v, w)
			vel[id] = v
			spin[id] = w
	if tick % RECORD_EVERY == 0 and recording:
		for id in loose:
			_record(id)
		for id in held:
			_record(id)
	if tick % THAW_EVERY == 0:
		_thaw_and_freeze()


## WHAT WAS HIT ([member events]): the one place a brick's sound comes from. A sudden change in a piece's speed past what gravity gives it,
## and how far it was turned: a hand's slow push changes it a little a tick, and is heard as nothing; a fall stopped dead, as all of it at once.
func _hits(id: int, b: RID, at: Transform3D, v: Vector3, w: Vector3) -> void:
	if quiet[id] > tick:
		return
	if vel[id].length_squared() < HIT_GOING * HIT_GOING and v.length_squared() < HIT_GOING * HIT_GOING:
		return
	var free_fall := vel[id] + Vector3(0.0, -G * DT * float(READ_EVERY), 0.0)
	var dv := (v - free_fall).length() + (w - spin[id]).length() * size[id] * 0.35
	if dv < HIT_LEAST:
		return
	quiet[id] = tick + HIT_AGAIN
	var q: Dictionary = pieces[id]
	events.append([tau, at.origin.x, at.origin.y, at.origin.z, dv, size[id], weight_of(String(q["kind"]), int(q["w"]), int(q["d"])), "hit", _against(id, b)])


## WHAT PIECE [param id] IS AGAINST, FOR ITS SOUND: asked only when it has hit something. Having every body report its contacts as they happen is what
## this would otherwise take, and that was more than half of the whole record's time (measured, 55.7 s to 23.3 s). A hand before what is made of something,
## and that before another piece: a piece among others against a tin wall rings the wall.
func _against(id: int, b: RID) -> String:
	_ask.shape_rid = PhysicsServer3D.body_get_shape(b, 0)
	_ask.transform = PhysicsServer3D.body_get_state(b, PhysicsServer3D.BODY_STATE_TRANSFORM)
	_ask.margin = ASK_MARGIN
	_ask.exclude = [b]
	var out := PLASTIC
	for r in PhysicsServer3D.space_get_direct_state(space).intersect_shape(_ask, ASK_MOST):
		var kind: Variant = _surface.get(((r as Dictionary)["rid"] as RID).get_id())
		if kind == HAND:
			return HAND
		if kind != null:
			out = String(kind)
	return out


## A SOUND THAT IS NOT A HIT: a press home, a piece pulled off, a plate dragged.
func say(kind: String, at: Vector3, strength: float, reach: float, weight := 1.0) -> void:
	if recording:
		events.append([tau, at.x, at.y, at.z, strength, reach, weight, kind, PLASTIC])


## KEPT ONLY WHERE A LINE BETWEEN KEYS WOULD MISS IT: the last sample is written when going straight from the last key to here would pass
## it by more than a hair, so a piece at rest has no keys and a falling one only as many as it takes. A piece's first move starts from its
## still pose, which is then written, and it holds there through whatever came before.
func _record(id: int) -> void:
	var at := xf[id]
	var p := at.origin
	var q := at.basis.get_rotation_quaternion()
	var prev: Array = _prev[id] if _prev[id] != null else []
	var last: Array = _key_last[id] if _key_last[id] != null else []
	if last.is_empty():
		_write_key(id, tau, p, q)
		_prev[id] = [tau, p, q]
		return
	if not prev.is_empty() and float(prev[0]) > float(last[0]):
		var u := (float(prev[0]) - float(last[0])) / maxf(tau - float(last[0]), 1e-6)
		var line := (last[1] as Vector3).lerp(p, u)
		var turn := (last[2] as Quaternion).slerp(q, u)
		if line.distance_squared_to(prev[1] as Vector3) > KEY_NEAR * KEY_NEAR or 1.0 - absf(turn.dot(prev[2] as Quaternion)) > KEY_TURN:
			_write_key(id, float(prev[0]), prev[1] as Vector3, prev[2] as Quaternion)
	_prev[id] = [tau, p, q]


func _write_key(id: int, t: float, p: Vector3, q: Quaternion) -> void:
	if not keys.has(id):
		keys[id] = PackedFloat32Array()
	var k: PackedFloat32Array = keys[id]
	k.append(t)
	k.append(p.x)
	k.append(p.y)
	k.append(p.z)
	k.append(q.x)
	k.append(q.y)
	k.append(q.z)
	k.append(q.w)
	keys[id] = k
	_key_last[id] = [t, p, q]


## A piece about to move: where it holds until then is a key, or it would drift from its last one across a rest.
func _note_key(id: int) -> void:
	if not recording:
		_key_last[id] = null
		_prev[id] = null
		return
	var at := xf[id]
	var t := tau - 1.0 / 60.0
	var last: Array = _key_last[id] if _key_last[id] != null else []
	if last.is_empty() or float(last[0]) < t:
		_write_key(id, t if not last.is_empty() else tau, at.origin, at.basis.get_rotation_quaternion())
	_prev[id] = null


## Where it ended, whatever a line would say.
func _flush_key(id: int, at: Transform3D) -> void:
	if recording:
		var last: Array = _key_last[id] if _key_last[id] != null else []
		var prev: Array = _prev[id] if _prev[id] != null else []
		if not prev.is_empty() and not last.is_empty() and float(prev[0]) > float(last[0]) and float(prev[0]) < tau:
			_write_key(id, float(prev[0]), prev[1] as Vector3, prev[2] as Quaternion)
		_write_key(id, tau, at.origin, at.basis.get_rotation_quaternion())
	_prev[id] = null


## EVERY PIECE'S LAST PLACE WRITTEN: nothing is left owed a key past here.
func flush_all() -> void:
	for id in loose:
		_flush_key(id, xf[id])
	for id in held:
		_flush_key(id, xf[id])


## WHAT MOVES THAWS WHAT IS ROUND IT, AND WHAT HAS STOPPED GOES STATIC ([constant REST_FOR]). Thawed only near something moving, a heap
## costs what is disturbed; and because anything that moves thaws what lies on it, nothing hangs when what held it goes.
func _thaw_and_freeze() -> void:
	var dt := DT * float(THAW_EVERY)
	var stirring: Array = sources.duplicate()
	for id in held:
		stirring.append([mid[id], size[id] + THAW_NEAR])
	var i := loose.size() - 1
	while i >= 0:
		var id := loose[i]
		if vel[id].length() > STIR_SPEED or spin[id].length() * size[id] > STIR_SPEED:
			stirring.append([mid[id], size[id] + THAW_NEAR])
			still[id] = 0.0
		elif vel[id].length() < REST_SPEED and spin[id].length() < REST_SPIN:
			still[id] += dt
		else:
			still[id] = 0.0
		i -= 1
	for s in stirring:
		_thaw_near(s[0] as Vector3, float(s[1]))
	i = loose.size() - 1
	while i >= 0:
		var id := loose[i]
		if still[id] >= REST_FOR and not _near_any(id, stirring):
			_freeze(id)
		i -= 1


func _near_any(id: int, stirring: Array) -> bool:
	for s in stirring:
		var r := float(s[1]) + size[id]
		if mid[id].distance_squared_to(s[0] as Vector3) < r * r:
			return true
	return false


func _freeze(id: int) -> void:
	var b := bodies[id]
	_flush_key(id, xf[id])
	PhysicsServer3D.body_set_mode(b, PhysicsServer3D.BODY_MODE_STATIC)
	state[id] = FROZEN
	loose.erase(id)
	_file(id)


func _thaw_near(at: Vector3, reach: float) -> void:
	var c0 := _cell_of(at - Vector3.ONE * (reach + CELL))
	var c1 := _cell_of(at + Vector3.ONE * (reach + CELL))
	for x in range(c0.x, c1.x + 1):
		for y in range(c0.y, c1.y + 1):
			for z in range(c0.z, c1.z + 1):
				var c := Vector3i(x, y, z)
				if not _grid.has(c):
					continue
				var list: Array = _grid[c]
				var j := list.size() - 1
				while j >= 0:
					var id := int(list[j])
					var r := reach + size[id]
					if state[id] == FROZEN and mid[id].distance_squared_to(at) < r * r:
						list.remove_at(j)
						_go_loose(id)
						_note_key(id)
					j -= 1


## Whether anything is still moving.
func at_rest() -> bool:
	for id in loose:
		if vel[id].length() > REST_SPEED * 1.5 or spin[id].length() > REST_SPIN * 1.5:
			return false
	return true


## THE HIGHEST OF WHAT LIES NEAR [param at] (meters), a piece's top - of what lies loose, not in hand, not on the plate - or NAN.
func top_near(at: Vector2, reach: float) -> float:
	var out := NAN
	for id in pieces.size():
		if state[id] != FROZEN and state[id] != LOOSE:
			continue
		var m := mid[id]
		if Vector2(m.x - at.x, m.z - at.y).length_squared() < reach * reach:
			var top := m.y + size[id] * 0.5
			if is_nan(out) or top > out:
				out = top
	return out


## HOW MANY PIECES LIE OVER PIECE [param id].
func on_top_of(id: int) -> int:
	var n := 0
	var m := mid[id]
	var r := size[id] + 0.008
	for o in pieces.size():
		if o == id or (state[o] != FROZEN and state[o] != LOOSE):
			continue
		var p := mid[o]
		if p.y > m.y + 0.003 and Vector2(p.x - m.x, p.z - m.z).length_squared() < r * r:
			n += 1
	return n
