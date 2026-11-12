extends SceneTree
class_name DiceBake

## DiceBake - every throw of a session, as real bodies (next/tabletop.md "Dice"): a second Godot, no window, stepping Jolt as fast as the
## machine goes, as [AssemblyBake] does the bricks. Handed where everything stands at each throw ([method GameBoard.bake_request]), it
## throws, watches each die come to rest, and writes down what each body did and every time it hit something. [TableGame] plays it back by lookup.
##
##     godot --headless --fixed-fps 240 --script res://src/table/dice_bake.gd -- <request file>
##
## A throw never depends on the last: the last roll's dice have gone home before the next is thrown, so each throw stands alone, in a world
## holding only what stands on the table and on the map then.
##
## What does not count is thrown again: a die that leans on something, leaves the table, leaves the picture, or takes too long to stop.
## Which number it shows is not this file's: it comes to rest on a face, and the die's printing is turned onto that face
## ([method Dice.turn_for]), so whatever a throw lands on, it reads what was rolled.
##
## At ten times its size, as [AssemblyWorld] and for its reason: Jolt's margins are made for things a meter across, so everything is
## scaled going in and coming out, gravity with it.

const SIM := 10.0
const TICKS := 240
const G := 9.81
## How long a throw is watched at most (seconds), how long it takes to reach the place it was aimed at (seconds, the least and the most), and how many times one is tried.
const WATCH_MOST := 5.0
const FLIGHT := Vector2(0.3, 0.42)
const TRIES := 14
## A die spins this fast on leaving a hand (radians a second, at its real size: the world's own settings cap it at 30).
const SPIN := Vector2(14.0, 26.0)
## At rest: as slow as this (m/s and radians a second) for this long.
const REST_SPEED := 0.012
const REST_SPIN := 0.25
const REST_HOLD := 0.18
## Heard: the least sudden change in a die's speed that is a hit at all (m/s), and how soon the same die can be heard again (ticks).
const HIT_LEAST := 0.09
const HIT_AGAIN := 5
## Keys are looked at this many ticks apart (60 a second), and what lies still after is its last.
const KEY_EVERY := 4
## How far to leave between dice leaving one hand (a share of their reach).
const HAND_GAP := 1.15

var _space: RID
var _shapes := {}             # a shape + size -> RID
var _bodies: Array = []
var _statics: Array = []      # the things on the table, for every throw
var _static_shapes: Array = []
var _extra: Array = []        # this throw's own: what stands on the map
var _req := {}


func _initialize() -> void:
	Engine.physics_ticks_per_second = TICKS
	Engine.max_physics_steps_per_frame = 1
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("dice_bake: no request")
		quit(2)
		return
	var f := FileAccess.open(args[0], FileAccess.READ)
	if f == null:
		push_error("dice_bake: cannot read %s" % args[0])
		quit(2)
		return
	_req = bytes_to_var(f.get_buffer(f.get_length()))
	f.close()
	_run.call_deferred()


func _run() -> void:
	await physics_frame
	_space = PhysicsServer3D.space_create()
	PhysicsServer3D.space_set_active(_space, true)
	PhysicsServer3D.area_set_param(_space, PhysicsServer3D.AREA_PARAM_GRAVITY, G * SIM)
	PhysicsServer3D.area_set_param(_space, PhysicsServer3D.AREA_PARAM_GRAVITY_VECTOR, Vector3.DOWN)
	PhysicsServer3D.area_set_param(_space, PhysicsServer3D.AREA_PARAM_LINEAR_DAMP, 0.0)
	PhysicsServer3D.area_set_param(_space, PhysicsServer3D.AREA_PARAM_ANGULAR_DAMP, 0.0)
	_slab()
	for s in _req.get("solids", []):
		_surface((s as Dictionary)["faces"])
	for h in _req.get("homes", []):
		_home_pile(h)
	var rolls: Dictionary = {}
	for r in _req.get("rolls", []):
		rolls[int((r as Dictionary)["id"])] = await _throw(r as Dictionary)
	var out := String(_req.get("out", ""))
	var f := FileAccess.open(out + ".part", FileAccess.WRITE)
	if f == null:
		push_error("dice_bake: cannot write %s" % out)
		quit(2)
		return
	f.store_buffer(var_to_bytes({"rolls": rolls}))
	f.close()
	DirAccess.rename_absolute(out + ".part", out)
	print("dice_bake: %d throws" % rolls.size())
	_free_world()
	quit(0)


func _free_world() -> void:
	_clear_figures()
	for b in _statics:
		PhysicsServer3D.free_rid(b)
	_statics.clear()
	for s in _shapes.values():
		PhysicsServer3D.free_rid(s)
	_shapes.clear()
	for s in _static_shapes:
		PhysicsServer3D.free_rid(s)
	_static_shapes.clear()
	PhysicsServer3D.free_rid(_space)


## The table itself: flat to a good way past anything thrown at it, which is what leaving the table means here: a body that gets past it is off it, and not looked at again.
func _slab() -> void:
	var s := PhysicsServer3D.box_shape_create()
	PhysicsServer3D.shape_set_data(s, Vector3(1.0, 0.2, 0.7) * SIM)
	var b := PhysicsServer3D.body_create()
	PhysicsServer3D.body_set_mode(b, PhysicsServer3D.BODY_MODE_STATIC)
	PhysicsServer3D.body_add_shape(b, s)
	PhysicsServer3D.body_set_param(b, PhysicsServer3D.BODY_PARAM_FRICTION, 0.5)
	PhysicsServer3D.body_set_param(b, PhysicsServer3D.BODY_PARAM_BOUNCE, 0.3)
	PhysicsServer3D.body_set_state(b, PhysicsServer3D.BODY_STATE_TRANSFORM, Transform3D(Basis.IDENTITY, Vector3(0.0, -0.2, 0.0) * SIM))
	PhysicsServer3D.body_set_space(b, _space)
	_statics.append(b)
	_static_shapes.append(s)


func _surface(faces: PackedVector3Array) -> void:
	var big := PackedVector3Array()
	big.resize(faces.size())
	for i in faces.size():
		big[i] = faces[i] * SIM
	var s := PhysicsServer3D.concave_polygon_shape_create()
	PhysicsServer3D.shape_set_data(s, {"faces": big, "backface_collision": true})
	var b := PhysicsServer3D.body_create()
	PhysicsServer3D.body_set_mode(b, PhysicsServer3D.BODY_MODE_STATIC)
	PhysicsServer3D.body_add_shape(b, s)
	PhysicsServer3D.body_set_param(b, PhysicsServer3D.BODY_PARAM_FRICTION, 0.42)
	PhysicsServer3D.body_set_param(b, PhysicsServer3D.BODY_PARAM_BOUNCE, 0.25)
	PhysicsServer3D.body_set_space(b, _space)
	_statics.append(b)
	_static_shapes.append(s)


## Where someone keeps their dice: a low heap of them on the table, as a throw meets it.
func _home_pile(at: Vector2) -> void:
	var s := PhysicsServer3D.box_shape_create()
	PhysicsServer3D.shape_set_data(s, Vector3(0.05, 0.012, 0.03) * SIM)
	var b := PhysicsServer3D.body_create()
	PhysicsServer3D.body_set_mode(b, PhysicsServer3D.BODY_MODE_STATIC)
	PhysicsServer3D.body_add_shape(b, s)
	PhysicsServer3D.body_set_param(b, PhysicsServer3D.BODY_PARAM_FRICTION, 0.4)
	PhysicsServer3D.body_set_param(b, PhysicsServer3D.BODY_PARAM_BOUNCE, 0.3)
	PhysicsServer3D.body_set_state(b, PhysicsServer3D.BODY_STATE_TRANSFORM, Transform3D(Basis.IDENTITY, Vector3(at.x, 0.012, at.y) * SIM))
	PhysicsServer3D.body_set_space(b, _space)
	_statics.append(b)
	_static_shapes.append(s)


## What stands on the map for this throw: a figure's base, a little taller than a coin, and the card it holds; a fallen one, only flat card. Nothing here is knocked over: it is a post in the way.
func _figures(list: Array) -> void:
	for f in list:
		var d: Dictionary = f
		var at: Vector2 = d["at"]
		var w := float(d["w"])
		var s := PhysicsServer3D.box_shape_create()
		var tall := w * GameBoard.FIGURE_TALL
		var half := Vector3(w * 0.5, 0.002, tall * 0.5) if bool(d["down"]) else Vector3(w * 0.5, tall * 0.5, w * 0.4)
		PhysicsServer3D.shape_set_data(s, half * SIM)
		var b := PhysicsServer3D.body_create()
		PhysicsServer3D.body_set_mode(b, PhysicsServer3D.BODY_MODE_STATIC)
		PhysicsServer3D.body_add_shape(b, s)
		PhysicsServer3D.body_set_param(b, PhysicsServer3D.BODY_PARAM_FRICTION, 0.4)
		PhysicsServer3D.body_set_param(b, PhysicsServer3D.BODY_PARAM_BOUNCE, 0.2)
		PhysicsServer3D.body_set_state(b, PhysicsServer3D.BODY_STATE_TRANSFORM, Transform3D(Basis.IDENTITY, Vector3(at.x, half.y, at.y) * SIM))
		PhysicsServer3D.body_set_space(b, _space)
		_extra.append([b, s])


func _clear_figures() -> void:
	for pair in _extra:
		PhysicsServer3D.free_rid((pair as Array)[0])
		PhysicsServer3D.free_rid((pair as Array)[1])
	_extra.clear()


func _shape_of(shape: int, scale: float) -> RID:
	var key := "%d:%.3f" % [shape, scale]
	if not _shapes.has(key):
		var s := PhysicsServer3D.convex_polygon_shape_create()
		var pts := Dice.hull(shape, scale)
		for i in pts.size():
			pts[i] = pts[i] * SIM
		PhysicsServer3D.shape_set_data(s, pts)
		_shapes[key] = s
	return _shapes[key]


## One throw, as many times as it takes to come out readable: `{dur, dice: [{keys, face, rest}], hits: PackedFloat32Array + kinds}`.
func _throw(r: Dictionary) -> Dictionary:
	_figures(r.get("figures", []))
	var best := {}
	for attempt in TRIES:
		var got := await _try(r, hash([int(_req.get("seed", 0)), int(r["id"]), attempt]), attempt)
		best = got
		if bool(got["good"]):
			break
	_clear_figures()
	best.erase("good")
	return best


func _try(r: Dictionary, salt: int, attempt: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = salt
	var list: Array = r.get("dice", [])
	var seat := float(r.get("seat", 0.0))
	var hand2 := GameBoard.at_seat(seat, GameBoard.HAND)
	var hand := Vector3(hand2.x, rng.randf_range(GameBoard.THROW_UP.x, GameBoard.THROW_UP.y), hand2.y)
	# ...aimed at open table, nearer the middle as a throw goes on being unreadable, and only ever across from where they sit
	var aim := Vector2(rng.randf_range(GameBoard.AIM.position.x, GameBoard.AIM.end.x), rng.randf_range(GameBoard.AIM.position.y, GameBoard.AIM.end.y))
	aim = aim.lerp(GameBoard.MIDDLE, clampf(float(attempt) * 0.08, 0.0, 0.7))
	var toward := Vector3(aim.x, 0.02, aim.y)
	var flight := rng.randf_range(FLIGHT.x, FLIGHT.y)
	var bodies: Array = []
	var reach := 0.0
	for d in list:
		reach = maxf(reach, Dice.radius_of(int((d as Dictionary)["shape"])) * float((d as Dictionary)["size"]))
	var cols := ceili(sqrt(float(list.size())))
	var side := (Vector3(toward.x - hand.x, 0.0, toward.z - hand.z).normalized()).cross(Vector3.UP)
	var ahead := Vector3(toward.x - hand.x, 0.0, toward.z - hand.z).normalized()
	for k in list.size():
		var d: Dictionary = list[k]
		var shape := int(d["shape"])
		var scale := float(d["size"])
		var material: Dictionary = Dice.MATERIALS.get(String(d.get("material", "plastic")), Dice.MATERIALS["plastic"])
		var b := PhysicsServer3D.body_create()
		PhysicsServer3D.body_set_mode(b, PhysicsServer3D.BODY_MODE_RIGID)
		PhysicsServer3D.body_add_shape(b, _shape_of(shape, scale))
		PhysicsServer3D.body_set_param(b, PhysicsServer3D.BODY_PARAM_MASS, float(material["mass"]))
		PhysicsServer3D.body_set_param(b, PhysicsServer3D.BODY_PARAM_FRICTION, float(material["friction"]))
		PhysicsServer3D.body_set_param(b, PhysicsServer3D.BODY_PARAM_BOUNCE, float(material["bounce"]))
		PhysicsServer3D.body_set_enable_continuous_collision_detection(b, true)
		var gap := reach * 2.0 * HAND_GAP
		var row := k / cols
		var col := k % cols
		var start := hand + side * (float(col) - float(cols - 1) * 0.5) * gap - ahead * float(row) * gap + Vector3.UP * float(row % 2) * gap * 0.5
		var turn := Basis(Vector3(rng.randf(), rng.randf(), rng.randf()).normalized(), rng.randf() * TAU)
		PhysicsServer3D.body_set_state(b, PhysicsServer3D.BODY_STATE_TRANSFORM, Transform3D(turn, start * SIM))
		# ...in the world, then going: a velocity set on a body not yet in a space is lost, and it lay where it was put
		PhysicsServer3D.body_set_space(b, _space)
		PhysicsServer3D.body_set_state(b, PhysicsServer3D.BODY_STATE_SLEEPING, false)
		var v := (toward - start) / flight + Vector3.UP * G * flight * 0.5
		v += Vector3(rng.randf_range(-0.1, 0.1), rng.randf_range(-0.05, 0.05), rng.randf_range(-0.1, 0.1))
		PhysicsServer3D.body_set_state(b, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, v * SIM)
		PhysicsServer3D.body_set_state(b, PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized() * rng.randf_range(SPIN.x, SPIN.y))
		bodies.append({"rid": b, "shape": shape, "keys": PackedFloat32Array(), "last_v": v, "still": 0.0, "again": 0, "rest": -1.0, "size": reach})
	var hits := PackedFloat32Array()
	var against := PackedStringArray()
	var tick := 0
	# ...its first key, where it leaves the hand: a hand's move ends exactly there ([method TableGame._in_hand])
	for bd: Dictionary in bodies:
		var at: Transform3D = PhysicsServer3D.body_get_state(bd["rid"], PhysicsServer3D.BODY_STATE_TRANSFORM)
		_keep(bd, 0.0, at.origin / SIM, at.basis)
	var settled := false
	while float(tick) / float(TICKS) < WATCH_MOST and not settled:
		await physics_frame
		tick += 1
		var t := float(tick) / float(TICKS)
		settled = true
		for k in bodies.size():
			var bd: Dictionary = bodies[k]
			if float(bd["rest"]) >= 0.0:
				continue
			var rid: RID = bd["rid"]
			var xf: Transform3D = PhysicsServer3D.body_get_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM)
			var v: Vector3 = PhysicsServer3D.body_get_state(rid, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY)
			var w: Vector3 = PhysicsServer3D.body_get_state(rid, PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY)
			v /= SIM
			# ...heard: a sudden change past what gravity takes in a tick, and the hit is what it was thrown against
			var change := (v - (bd["last_v"] as Vector3) + Vector3.UP * G / float(TICKS)).length()
			bd["last_v"] = v
			bd["again"] = int(bd["again"]) - 1
			var p := xf.origin / SIM
			if change > HIT_LEAST and int(bd["again"]) <= 0:
				bd["again"] = HIT_AGAIN
				hits.append_array(PackedFloat32Array([t, p.x, p.y, p.z, change, float(bd["size"])]))
				against.append(_what_was_hit(p, bodies, k))
			if tick % KEY_EVERY == 0:
				_keep(bd, t, p, xf.basis)
			if v.length() < REST_SPEED and w.length() < REST_SPIN:
				bd["still"] = float(bd["still"]) + 1.0 / float(TICKS)
			else:
				bd["still"] = 0.0
			if float(bd["still"]) >= REST_HOLD or p.y < -0.05:
				bd["rest"] = t
				_keep(bd, t, p, xf.basis)
				continue
			settled = false
	# What it came to
	var good := settled
	var out_dice: Array = []
	var dur := 0.0
	for k in bodies.size():
		var bd: Dictionary = bodies[k]
		var rid: RID = bd["rid"]
		var xf: Transform3D = PhysicsServer3D.body_get_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM)
		var p := xf.origin / SIM
		var shape := int(bd["shape"])
		var read := Dice.landed(shape, xf.basis.orthonormalized())
		good = good and float(read["dot"]) >= Dice.flat_enough(shape) and GameBoard.LANDS.has_point(Vector2(p.x, p.z)) and p.y > 0.0
		dur = maxf(dur, float(bd["rest"]) if float(bd["rest"]) >= 0.0 else WATCH_MOST)
		out_dice.append({"keys": bd["keys"], "face": int(read["face"])})
		PhysicsServer3D.free_rid(rid)
	return {"good": good, "dur": dur, "dice": out_dice, "hits": hits, "against": against, "hand": hand}


## A key of this die. Taken out and put back: appending through a cast appends to a copy of a packed array.
static func _keep(bd: Dictionary, t: float, p: Vector3, b: Basis) -> void:
	var q := b.get_rotation_quaternion()
	var keys: PackedFloat32Array = bd["keys"]
	keys.append_array(PackedFloat32Array([t, p.x, p.y, p.z, q.x, q.y, q.z, q.w]))
	bd["keys"] = keys


## What a die at [param p] has hit: another die near enough, else what it lies on: a thing or the table. Only for what it rings as.
func _what_was_hit(p: Vector3, bodies: Array, k: int) -> String:
	for j in bodies.size():
		if j == k:
			continue
		var other: Transform3D = PhysicsServer3D.body_get_state((bodies[j] as Dictionary)["rid"], PhysicsServer3D.BODY_STATE_TRANSFORM)
		if (other.origin / SIM).distance_to(p) < float((bodies[k] as Dictionary)["size"]) * 2.2:
			return "die"
	return "table"
