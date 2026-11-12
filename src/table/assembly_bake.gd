extends SceneTree

## AssemblyBake - the hands at work on real bricks: a second Godot, no window, stepping [AssemblyWorld] as fast as the machine goes under
## `--fixed-fps`, handed what the steps come to ([Assembly]) and writing down everything that happens ([AssemblyTrack] reads it). Started by
## [TableAssembly], which goes on drawing as the pieces of the record land.
##
##   godot --headless --fixed-fps 240 --script res://src/table/assembly_bake.gd -- <request file>
##
## The record is a log, not a schedule: what comes to rest where does not depend on when in the reading it happens. Every step runs at a
## hand's own pace on the record's own clock and leaves stops in it (moments when nothing moves); the reading decides how long each stop
## lasts ([method Assembly.lay]). Before a stop the world is let come to rest ([method _settle]).
##
## The unseen hand is a body: a cupped palm or a set of fingers moved through the heap; everything it does to the pieces is what the
## pieces do. A dig is three things a hand does in a tub ([constant GESTURES]). What it holds it holds firmly and pushes aside what is in
## the way; what it lets go of falls. What is in hand is left to [Fingers]: the record says where the hand takes a piece and how much room
## it has at each point of the way ([method _room]); what the fingers do there is laid over this on the show's clock and touches nothing.
##
## What falls is still there to be used: a piece keeps its stock wherever it lands and [method _find] goes on finding it, on the table, on
## another's pile or on the floor. What falls past the table's edge ([method _begin]) drops to the floor, where a hand fetches it when
## nothing nearer is left ([method _off_the_floor]). What has fallen where a part goes is moved off first ([method _clear_spot]).
##
## Written in stretches ([constant STRETCH]), each ending at a step and holding where everything then is, under a name made from
## everything it depends on: a show can begin playing what has landed, and a new act or sentence never redoes what came before it.

## How much record makes a stretch (seconds), before it is written down.
const STRETCH := 6.0
## The ways a hand goes into a heap, and how often (`share`).
const GESTURES := {
	"stir": {"label": "Stir", "blurb": "fingers dragged through the top of it in a slow curve: everything shuffles, little of it hard", "share": 0.42},
	"flip": {"label": "Flip", "blurb": "a cupped hand under a handful, brought up quick and turned over: they fall back with a clatter", "share": 0.34},
	"sweep": {"label": "Sweep", "blurb": "the side of a hand pushing the top of it across, to see what is under", "share": 0.24},
}
## The hand's busy share of a dig's time: the rest it stops, looks, and goes back in.
const DIG_BUSY := 0.42
## How far from a container's wall the hand goes in (meters) - and how much closer a small one lets it; how far down it goes.
const WALL_CLEAR := 0.065
const IN_DEEP := 0.035
## How far above what it lands on a piece is let go (meters): put back, dropped from a stock's height, aside.
const BACK_FROM := Vector2(0.02, 0.055)
const DROP_FROM := 0.06
const ASIDE_FROM := 0.012
## How many lie over a piece before the hand clears it first; how fast one is drawn out of a heap (m/s).
const BURIED := 3
const DRAW_OUT := 0.2
## A pull ([method _pull]): the grip tips one end up (degrees) in this long (seconds); it turns on coming out (degrees); and it moves toward
## the middle of what it comes out of as a share of how far it rises, up to the most (meters), which keeps it off a wall.
const GRIP_TIP := Vector2(10.0, 24.0)
const GRIP_TAKES := Vector2(0.1, 0.2)
const DRAW_TURN := Vector2(18.0, 55.0)
const DRAW_ASIDE := 0.2
const DRAW_ASIDE_MOST := 0.008
const DRAW_LEAST := 0.2
const DRAW_MOST := 0.75
## How much of a draw is done before the move after it begins, the rest going on under it ([method _held_move]), so a hand does not come up, stop and set off.
const RUN_ON := 0.6
## A hand's pace across the table (m/s), and the least and most any carry takes.
const CARRY_SPEED := 0.34
const CARRY_LEAST := 0.75
const CARRY_MOST := 2.0
## A piece's way over what is on the table ([method _way]).
const CLEAR_OVER := 0.014
const LIFT_MOST := 0.34
const TALL := 0.22
const WAY_LOOKS := 7
const HOVER := 0.024
const PRESS_FROM := 0.0018
## Where a thing is held up to be looked at ([method _view_xf]): how far from the lens (meters), how far to the side it came from and how far
## up as shares of what the lens sees there, the same side three times in four, and how far over whatever is under it (meters).
const VIEW_FAR := Vector2(0.21, 0.33)
const VIEW_ACROSS := Vector2(0.2, 0.62)
const VIEW_UP := Vector2(-0.6, 0.1)
const VIEW_SAME_SIDE := 0.75
const VIEW_CLEAR := 0.05
const VIEW_ASPECT := 16.0 / 9.0
## How long what a piece disturbed coming out may go on landing before a stop with it held up (seconds): nothing hangs through one.
const HOLD_SETTLE := 0.7
## The share of a step's stops each kind of stop takes.
const STOP_HOVER := 2.0
const STOP_THINK := 1.0
const STOP_HELD := 2.0
## How often a pour is laid in, while a stock is filled.
const POUR_BATCH := 14
const POUR_WAIT := 0.8
## The floor, under the top (meters; [constant Tables.DROP_MOST] is what a cloth may hang to reach it); how far past a table's edge a hand comes up from it, and how far over the top it brings a piece.
const FLOOR_DROP := 0.72
const PAST_THE_EDGE := 0.04
const OVER_THE_TOP := 0.03
## How far over a part's own height something fallen is still in its way (meters).
const IN_THE_WAY_OVER := 0.008
## What a hand reaches, for thawing what is near it (meters).
const HAND_REACH := 0.085
## How far over a floor a hand goes at its lowest (meters): room for a plate under it.
const HAND_OVER_FLOOR := 0.008
const PIECE_REACH := 0.016

var req := {}
var world: AssemblyWorld
var log: Assembly
var stocks := {}
var stock_of := PackedStringArray()
var yaw := 0.0
var _hand: RID
var _hand_shapes := {}
var _hand_now := "scoop"
var _hand_floor := 0.0
var _body_of := {}                # the plan's piece on the model -> which piece it really is
var _seat_log: Array = []
var _turns: Array = []
var _plan_steps: Array = []       # the steps of this stretch: {k, t0, t1, stops}
var _cur: Dictionary = {}
var _run_on := {}                 # what is left of a draw: {id, to, j, n}, going on under the next move ([method _held_move])
var _keys: PackedInt64Array
var _out := ""
var _top_model := 0.0
var _tops := {}                   # a stud of the plate -> how high what is seated stands over it (meters)
var _at_of := {}                  # a seated piece -> [its stud x, z, turn]
var _base_body: RID
var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	Engine.physics_ticks_per_second = AssemblyWorld.TICKS
	Engine.max_physics_steps_per_frame = 1
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("assembly_bake: no request file")
		quit(2)
		return
	req = bytes_to_var(FileAccess.get_file_as_bytes(args[0]))
	_out = String(req["dir"])
	_run()


func _step() -> void:
	await physics_frame
	world.after_step()


func _run() -> void:
	var t0 := Time.get_ticks_msec()
	await _begin()
	var steps: Array = req["steps"]
	_keys = req["keys"]
	var k := _resume_from()
	print("assembly_bake: %d pieces, %d steps, from step %d (stock in %d ms)" % [world.pieces.size(), steps.size(), k, Time.get_ticks_msec() - t0])
	var stretch_tau := world.tau
	while k < steps.size():
		await _do_step(k, steps[k] as Dictionary)
		k += 1
		if world.tau - stretch_tau >= STRETCH or k == steps.size():
			_write_stretch(k)
			stretch_tau = world.tau
	print("assembly_bake: done, %.1f s of the record in %.1f s" % [world.tau, float(Time.get_ticks_msec() - t0) / 1000.0])
	PhysicsServer3D.free_rid(_hand)
	for shape_name in _hand_shapes:
		for sh in _hand_shapes[shape_name]:
			PhysicsServer3D.free_rid((sh as Array)[0])
	world.free_all()
	quit(0)


# --- the table stood, the stock laid in --------------------------------------------------------------------------

func _begin() -> void:
	var space := PhysicsServer3D.space_create()
	PhysicsServer3D.space_set_active(space, true)
	world = AssemblyWorld.new(space)
	_rng.seed = hash([int(req["seed"]), "assembly bake"])
	log = Assembly.new()
	log.spec = {"base": {"size": req["base_size"]}}
	log.world = {"base_at": req["base_at"], "yaw": float(req["yaw"])}
	yaw = float(req["yaw"])
	stocks = req["stocks"]
	# the table, what stands on it, and the plate
	# ...as far as the top goes: a table with no outline to hand is as wide as anything falls
	if req.has("top"):
		var edge := Tables.edge_points(req["top"] as Dictionary, 64)
		for i in edge.size():
			edge[i] += (req["top"] as Dictionary)["center"] as Vector2
		world.add_prism(edge, 0.0, 0.5, "wood")
		world.add_slab(Transform3D(Basis.IDENTITY, Vector3(0.0, -FLOOR_DROP - 0.25, 0.0)), Vector3(8.0, 0.25, 8.0), "wood")
	else:
		world.add_slab(Transform3D(Basis.IDENTITY, Vector3(0.0, -0.25, 0.0)), Vector3(8.0, 0.25, 8.0), "wood")
	for s in req["solids"]:
		world.add_surface((s as Dictionary)["faces"], String((s as Dictionary)["sound"]))
	for nm in stocks:
		var sd: Dictionary = stocks[nm]
		if sd.has("bed_faces"):
			world.add_surface(sd["bed_faces"], "plastic")
	# what a hollow thing holds stays in it ([method AssemblyWorld.add_vessel])
	for nm in stocks:
		var sd: Dictionary = stocks[nm]
		for s in req["solids"]:
			if not String(sd["thing"]).is_empty() and String((s as Dictionary).get("thing", "")) == String(sd["thing"]):
				world.add_vessel((s as Dictionary)["faces"], sd["middle"], float(sd["floor"]))
	var size: Array = req["base_size"]
	var half := Vector3(float(size[0]) * Assembly.STUD * 0.5, (Assembly.BASE_T + Assembly.STUD_H) * 0.5, float(size[1]) * Assembly.STUD * 0.5)
	var plate := log.base_xf(yaw)
	_base_body = world.add_slab(Transform3D(plate.basis, plate.origin + Vector3(0.0, half.y, 0.0)), half, "plastic")
	world.make_pieces(req["pieces"])
	stock_of = req["stock_of"]
	_hand = PhysicsServer3D.body_create()
	PhysicsServer3D.body_set_mode(_hand, PhysicsServer3D.BODY_MODE_KINEMATIC)
	PhysicsServer3D.body_set_param(_hand, PhysicsServer3D.BODY_PARAM_FRICTION, 0.5)
	world._surface[_hand.get_id()] = AssemblyWorld.HAND
	_make_hands()
	var stock_file := _out.path_join("stock.seg")
	if FileAccess.file_exists(stock_file):
		return
	await _pour()
	_write(stock_file, {"rest": _rest_of()})


func _make_hands() -> void:
	var cm := 0.01 * AssemblyWorld.SIM
	var scoop: Array = []
	for row in [[Vector3(0.0, 0.0, 0.0), Vector3(4.5, 0.55, 5.5)], [Vector3(-4.5, 1.2, 0.0), Vector3(0.55, 1.8, 5.5)], [Vector3(4.5, 1.2, 0.0), Vector3(0.55, 1.8, 5.5)], [Vector3(0.0, 1.2, -5.5), Vector3(4.5, 1.8, 0.55)]]:
		var s := PhysicsServer3D.box_shape_create()
		PhysicsServer3D.shape_set_data(s, (row[1] as Vector3) * cm)
		scoop.append([s, Transform3D(Basis.IDENTITY, (row[0] as Vector3) * cm)])
	_hand_shapes["scoop"] = scoop
	var fingers: Array = []
	for x in [-3.3, -1.1, 1.1, 3.3]:
		var s := PhysicsServer3D.capsule_shape_create()
		PhysicsServer3D.shape_set_data(s, {"radius": 0.75 * cm, "height": 6.5 * cm})
		fingers.append([s, Transform3D(Basis.IDENTITY, Vector3(float(x), -3.25, 0.0) * cm)])
	_hand_shapes["fingers"] = fingers


## The stock poured in, in the order it was handed ([method Assembly._lay_stock]: what is asked for soonest, last, and so on top), a batch at a
## time, each let lie before the next, as a tub comes to be full.
func _pour() -> void:
	world.recording = false
	var by: Dictionary = {}
	for id in world.pieces.size():
		var nm := stock_of[id]
		if not by.has(nm):
			by[nm] = []
		(by[nm] as Array).append(id)
	for nm in by:
		var sd: Dictionary = stocks.get(nm, {})
		if sd.is_empty():
			continue
		var ids: Array = by[nm]
		var i := 0
		while i < ids.size():
			var batch := ids.slice(i, i + POUR_BATCH)
			i += POUR_BATCH
			_lay_batch(batch, sd)
			var waited := 0.0
			while waited < POUR_WAIT:
				await _step()
				waited += AssemblyWorld.DT
				if waited > 0.25 and world.at_rest():
					break
	# ...and let lie, every piece of it: frozen where it got to
	for _i in AssemblyWorld.TICKS * 6:
		await _step()
		if world.loose.is_empty():
			break
	while not world.loose.is_empty():
		world._freeze(world.loose[0])
	world.recording = true
	world.tick = 0
	world.tau = 0.0
	world.events = []
	world.keys = {}


## The pieces of a batch, each dropped from clear of the others over the stock.
func _lay_batch(batch: Array, sd: Dictionary) -> void:
	var taken: Array = []
	var middle: Vector2 = sd["middle"]
	var radius := float(sd["radius"])
	var floor_y := float(sd["floor"])
	var pile: bool = String(sd["thing"]).is_empty()
	var top := world.top_near(middle, radius + 0.1)
	var y := (top if not is_nan(top) else floor_y) + (0.012 if pile else 0.03)
	for b in batch:
		var id := int(b)
		var r := world.size[id] + 0.002
		var at := middle
		var placed := false
		for _try in 26:
			var a := _rng.randf() * TAU
			var d := sqrt(_rng.randf()) * maxf(radius - r - 0.006, 0.005)
			at = middle + Vector2(cos(a), sin(a)) * d
			var clear := _inside(sd, at, r)
			if clear:
				for o in taken:
					if at.distance_to((o as Array)[0] as Vector2) < r + float((o as Array)[1]):
						clear = false
						break
			if clear:
				placed = true
				break
				# ...no room at this height: the next ones go a little over these, and this one in the middle, never where its last try had it across the wall
		if not placed:
			y += 0.012
			taken = []
			if not pile:
				at = middle
		taken.append([at, r])
		var basis := Basis.from_euler(Vector3(_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU))
		if pile:
			# ...a pile on the table is let down from low, and lies as it would, nearly flat
			basis = Basis(Vector3.UP, _rng.randf() * TAU) * Basis(Vector3.RIGHT, _rng.randf_range(-0.5, 0.5) + (PI if _rng.randf() < 0.2 else 0.0))
		world.drop_in(id, Transform3D(basis, Vector3(at.x, y + r, at.y)), Vector3(0.0, -0.12, 0.0), Vector3(_rng.randf() - 0.5, _rng.randf() - 0.5, _rng.randf() - 0.5) * (2.0 if pile else 8.0))


## Whether [param at], [param r] from anything outside it, is inside stock [param sd].
func _inside(sd: Dictionary, at: Vector2, r: float) -> bool:
	if String(sd["thing"]).is_empty():
		return true
	for k in 8:
		var a := TAU * float(k) / 8.0
		if not _cell_inside(sd, at + Vector2(cos(a), sin(a)) * (r + 0.003)):
			return false
	return _cell_inside(sd, at)


static func _cell_inside(sd: Dictionary, at: Vector2) -> bool:
	var origin: Vector2 = sd["origin"]
	var cols := int(sd["nx"])
	var rows := int(sd["nz"])
	var i := int(round((at.x - origin.x) / AssemblyHeap.CELL))
	var j := int(round((at.y - origin.y) / AssemblyHeap.CELL))
	if i < 0 or j < 0 or i >= cols or j >= rows:
		return false
	return not is_nan((sd["ground"] as PackedFloat32Array)[j * cols + i])


# --- the record ---------------------------------------------------------------------------------------------------

## Where to go on from: the last stretch already written, its world stood again, so a new act costs only what comes after what is already
## written. The stock first, or from where a checkpoint left it.
func _resume_from() -> int:
	var steps: Array = req["steps"]
	var rest: Dictionary = {}
	var from := 0
	var stock_file := _out.path_join("stock.seg")
	if FileAccess.file_exists(stock_file):
		rest = (bytes_to_var(FileAccess.get_file_as_bytes(stock_file)) as Dictionary)["rest"]
	for k in range(steps.size(), 0, -1):
		var f := _out.path_join("%016x.seg" % _keys[k - 1])
		if FileAccess.file_exists(f):
			rest = (bytes_to_var(FileAccess.get_file_as_bytes(f)) as Dictionary)["rest"]
			from = k
			break
	if not rest.is_empty():
		_stand_from(rest)
	return from


## The world as a record's stretch left it.
func _stand_from(rest: Dictionary) -> void:
	while not world.loose.is_empty():
		world._freeze(world.loose[0])
	var poses: PackedFloat32Array = rest["poses"]
	var states: PackedByteArray = rest["state"]
	var seated: Dictionary = rest["seated"]
	stock_of = rest["stock_of"]
	yaw = float(rest["yaw"])
	_body_of = rest["slots"]
	world.tick = int(rest["tick"])
	world.tau = float(world.tick) * AssemblyWorld.DT
	_top_model = float(rest["model_top"])
	_at_of = rest.get("at_of", {})
	var plate := log.base_xf(yaw)
	var size: Array = req["base_size"]
	PhysicsServer3D.body_set_state(_base_body, PhysicsServer3D.BODY_STATE_TRANSFORM, AssemblyWorld._big(Transform3D(plate.basis, plate.origin + Vector3(0.0, (Assembly.BASE_T + Assembly.STUD_H) * 0.5, 0.0))))
	for id in world.pieces.size():
		var i := id * 7
		var at := Transform3D(Basis(Quaternion(poses[i + 3], poses[i + 4], poses[i + 5], poses[i + 6])), Vector3(poses[i], poses[i + 1], poses[i + 2]))
		if states[id] == AssemblyWorld.OUT:
			continue
		world.place_frozen(id, at)
		if seated.has(id):
			world._unfile(id)
			world.state[id] = AssemblyWorld.SEATED
			world.seats[id] = seated[id]
	_recount_tops()


func _rest_of() -> Dictionary:
	var n := world.pieces.size()
	var poses := PackedFloat32Array()
	poses.resize(n * 7)
	for id in n:
		var at: Transform3D = world.xf[id]
		var q := at.basis.get_rotation_quaternion()
		var i := id * 7
		poses[i] = at.origin.x
		poses[i + 1] = at.origin.y
		poses[i + 2] = at.origin.z
		poses[i + 3] = q.x
		poses[i + 4] = q.y
		poses[i + 5] = q.z
		poses[i + 6] = q.w
	return {"poses": poses, "state": world.state, "seated": world.seats.duplicate(), "stock_of": stock_of, "yaw": yaw, "slots": _body_of.duplicate(), "tick": world.tick, "model_top": _top_model, "at_of": _at_of.duplicate()}


## What this stretch came to, under the name of the step it reached.
func _write_stretch(k: int) -> void:
	world.flush_all()
	var e_t := PackedFloat32Array()
	var e_v := PackedFloat32Array()
	var e_k := PackedStringArray()
	for ev in world.events:
		var a: Array = ev
		e_t.append(float(a[0]))
		e_v.append_array(PackedFloat32Array([float(a[1]), float(a[2]), float(a[3]), float(a[4]), float(a[5]), float(a[6])]))
		e_k.append("%s/%s" % [String(a[7]), String(a[8])])
	var seg := {"to": k, "steps": _plan_steps, "keys": world.keys, "seat_log": _seat_log, "turns": _turns, "ev_t": e_t, "ev": e_v, "ev_k": e_k, "tau": world.tau, "rest": _rest_of()}
	_write(_out.path_join("%016x.seg" % _keys[k - 1]), seg)
	world.keys = {}
	world.events = []
	_seat_log = []
	_turns = []
	_plan_steps = []


## Written whole or not at all: what reads it never sees half of one.
func _write(path: String, data: Dictionary) -> void:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("assembly_bake: cannot write %s" % tmp)
		quit(3)
		return
	f.store_buffer(var_to_bytes(data))
	f.close()
	DirAccess.rename_absolute(tmp, path)


# --- a step -------------------------------------------------------------------------------------------------------

func _do_step(k: int, st: Dictionary) -> void:
	_cur = {"k": k, "t0": world.tau, "stops": []}
	var seed := hash([int(req["seed"]), k])
	match String(st["do"]):
		"pause":
			_stop(1.0, float(st["natural"]), float(st["floor"]))
		"dig":
			await _dig(st, seed)
		"put":
			await _put(st, seed)
		"try":
			await _try(st, seed)
		"look":
			await _look(st, seed)
		"take", "wreck":
			await _bring_off(st, seed)
		"turn":
			await _turn(st, seed)
	await _settle()
	world.flush_all()
	_cur["t1"] = world.tau
	_run_on = {}
	_share_stops(st)
	_plan_steps.append(_cur)


## A stop: from here nothing moves in the record until the reading says ([method Assembly.lay]). [param weight] how much of what is spare it
## takes; [param natural] seconds it is always worth by itself (-1: its share of the step's natural time); [param least] the least it takes.
func _stop(weight: float, natural := -1.0, least := 0.0) -> void:
	(_cur["stops"] as Array).append([world.tau - float(_cur["t0"]), natural, least, weight])


## Piece [param id] is in hand from here, in this step ([method Assembly.held_at]).
func _in_hand(id: int) -> void:
	var o := world.tau - float(_cur["t0"])
	_cur["hand"] = {"id": id, "from": o, "to": o, "knots": [[o, 0.0]]}


## The room the hand has here, [param ahead] seconds on: how much of what it does with what it holds ([method Fingers.at]) it can do without touching anything, from here to the next said.
func _room(room: float, ahead := 0.0) -> void:
	((_cur["hand"] as Dictionary)["knots"] as Array).append([world.tau - float(_cur["t0"]) + ahead, room])


## It leaves the hand here, exactly where the record has it.
func _out_of_hand() -> void:
	if not _cur.has("hand"):
		return
	_room(0.0)
	(_cur["hand"] as Dictionary)["to"] = world.tau - float(_cur["t0"])


## What the step's natural time leaves over its moves goes to its stops, by weight. A step that stopped nowhere stops as it begins.
func _share_stops(st: Dictionary) -> void:
	var stops: Array = _cur["stops"]
	if stops.is_empty():
		stops.append([0.0, -1.0, 0.0, 1.0])
	var moving := float(_cur["t1"]) - float(_cur["t0"])
	var fixed := 0.0
	var weights := 0.0
	for s in stops:
		var a: Array = s
		if float(a[1]) >= 0.0:
			fixed += float(a[1])
		else:
			weights += float(a[3])
	var left := maxf(float(st["natural"]) - moving - fixed, 0.0)
	for s in stops:
		var a: Array = s
		if float(a[1]) < 0.0:
			a[1] = left * float(a[3]) / maxf(weights, 1e-6)


## Let what is falling land: up to [constant AssemblyWorld.SETTLE_MOST] of the record, nothing can be seen hanging through what comes next.
func _settle(most := AssemblyWorld.SETTLE_MOST) -> void:
	var waited := 0.0
	while waited < most:
		if waited >= 0.05 and world.at_rest():
			return
		await _step()
		waited += AssemblyWorld.DT


func _wait(seconds: float) -> void:
	for _i in int(ceil(seconds * float(AssemblyWorld.TICKS))):
		await _step()


# --- a dig --------------------------------------------------------------------------------------------------------

## A dig is what a hand does in a tub, some of it, with stops: into the heap, moving what is there, out, and a look at what that turned up. The
## last of them near what it is looking for, if it knows what that is.
func _dig(st: Dictionary, seed: int) -> void:
	var stock := String(st["stock"])
	var sd: Dictionary = stocks.get(stock, {})
	if sd.is_empty() or _ids_in(stock).is_empty():
		_stop(1.0)
		return
	var busy := float(st["seconds"]) * DIG_BUSY
	var t0 := world.tau
	var last := ""
	var n := 0
	var sought := _find(String(st.get("part_key", "")), stock)
	while n == 0 or world.tau - t0 < busy:
		_stop(STOP_THINK * lerpf(0.5, 1.6, Hands.share(seed, 70 + n)))
		var gesture := _pick_gesture(seed, n, last, sd)
		last = gesture
		var spot := _spot(sd, seed, n)
		if sought >= 0 and world.tau - t0 >= busy * 0.5:
			spot = Vector2(world.mid[sought].x, world.mid[sought].z)
		await _gesture(gesture, sd, spot, hash([seed, n]))
		await _settle(1.0)
		n += 1
		if n > 40:
			break
	_stop(STOP_THINK)


func _pick_gesture(seed: int, n: int, last: String, sd: Dictionary) -> String:
	var small := float(sd["radius"]) < 0.1
	if small:
		return "stir"
	var u := Hands.share(seed, 90 + n)
	for k in GESTURES:
		var share := float((GESTURES[k] as Dictionary)["share"])
		if u < share:
			return "stir" if String(k) == last and String(k) == "flip" else String(k)
		u -= share
	return "stir"


## Where it goes in: anywhere clear of the walls.
func _spot(sd: Dictionary, seed: int, n: int) -> Vector2:
	var middle := _middle_of(sd)
	var r := maxf(float(sd["radius"]) - WALL_CLEAR, float(sd["radius"]) * 0.3)
	var a := TAU * Hands.share(seed, 110 + n)
	return middle + Vector2(cos(a), sin(a)) * r * sqrt(Hands.share(seed, 130 + n))


## A pile's middle is where it has got to, a container's where it stands.
func _middle_of(sd: Dictionary) -> Vector2:
	return sd["middle"]


func _gesture(gesture: String, sd: Dictionary, spot: Vector2, seed: int) -> void:
	_hand_floor = float(sd["floor"])
	var middle := _middle_of(sd)
	var to_mid := (middle - spot)
	var dir := Vector3(to_mid.x, 0.0, to_mid.y)
	dir = dir.normalized() if dir.length() > 0.02 else Vector3(cos(float(seed)), 0.0, sin(float(seed)))
	dir = (Basis(Vector3.UP, lerpf(-0.7, 0.7, Hands.share(seed, 1))) * dir).normalized()
	var top := world.top_near(spot, 0.05)
	var floor_y := float(sd["floor"])
	var s: float = maxf(top if not is_nan(top) else floor_y, floor_y + 0.012)
	var deep := minf(IN_DEEP, maxf(s - floor_y - 0.012, 0.004))
	var at := Vector3(spot.x, 0.0, spot.y)
	match gesture:
		"flip":
			await _flip(at, dir, s, deep, seed)
		"sweep":
			await _sweep(at, dir, s, deep, seed)
		_:
			await _stir(at, s, deep, seed)


## The hand's frame: its fingers along [param dir], its palm up, tipped [param tilt] radians fingers down.
static func _palm(dir: Vector3, tilt: float) -> Basis:
	var z := dir.normalized()
	var y := Vector3.UP
	var x := y.cross(z).normalized()
	return Basis(x, tilt) * Basis(x, y, z)


## Flip: in under a handful at a slant, levelled, brought up and turned over as it stops: what was on it goes on rising a moment, then falls. The one a tub is
## loudest for, and a hand at an easy pace, not a throw.
func _flip(at: Vector3, dir: Vector3, s: float, deep: float, seed: int) -> void:
	var up := Vector3.UP
	var vary := lerpf(1.15, 1.6, Hands.share(seed, 2))
	var lift := lerpf(0.03, 0.06, Hands.share(seed, 3))
	var pts: Array = [
		[at - dir * 0.1 + up * (s + 0.04), 0.8],
		[at - dir * 0.05 + up * (s - deep * 0.6), 0.72],
		[at + up * (s - deep), 0.12],
		[at + dir * 0.03 + up * (s - deep * 0.6), -0.1],
		[at + dir * 0.045 + up * (s + lift), -0.28],
		[at + dir * 0.05 + up * (s + lift + 0.016), 0.95],
		[at + dir * 0.02 + up * (s + lift + 0.08), 1.2]]
	var times := PackedFloat32Array([0.26, 0.26, 0.24, 0.17, 0.2, 0.22])
	for i in times.size():
		times[i] *= vary
	await _hand_along("scoop", pts, times, dir)


## Sweep: the side of a hand on edge, pushing the top of it across.
func _sweep(at: Vector3, dir: Vector3, s: float, deep: float, seed: int) -> void:
	var side := (Basis(Vector3.UP, PI * 0.5) * dir) * (1.0 if Hands.share(seed, 4) < 0.5 else -1.0)
	var y := s - deep * 0.45
	var go := lerpf(0.08, 0.14, Hands.share(seed, 5))
	var pts: Array = [
		[at - dir * go * 0.6 + Vector3.UP * (s + 0.035), 1.25],
		[at - dir * go * 0.5 + Vector3.UP * y, 1.25],
		[at + side * 0.012 + Vector3.UP * y, 1.3],
		[at + dir * go * 0.5 + Vector3.UP * (y + 0.004), 1.35],
		[at + dir * go * 0.62 + Vector3.UP * (s + 0.05), 1.0]]
	var pace := lerpf(0.75, 1.15, Hands.share(seed, 6))
	await _hand_along("scoop", pts, PackedFloat32Array([0.26 * pace, 0.36 * pace, 0.36 * pace, 0.26 * pace]), dir)


## Stir: fingers through the top in a slow curve.
func _stir(at: Vector3, s: float, deep: float, seed: int) -> void:
	var r := lerpf(0.03, 0.065, Hands.share(seed, 7))
	var turns := lerpf(0.8, 1.5, Hands.share(seed, 8)) * (1.0 if Hands.share(seed, 9) < 0.5 else -1.0)
	var a0 := TAU * Hands.share(seed, 10)
	# ...the finger's tips reach this far under the top
	var y := s - deep + 0.065
	var n := 10
	var pts: Array = []
	var times := PackedFloat32Array()
	var first := at + Vector3(cos(a0), 0.0, sin(a0)) * r
	pts.append([first + Vector3.UP * (y + 0.05), 0.0])
	times.append(0.3)
	var step_len := absf(turns) * TAU * r / float(n)
	var speed := lerpf(0.14, 0.26, Hands.share(seed, 11))
	for i in n + 1:
		var a := a0 + TAU * turns * float(i) / float(n)
		var wander := 1.0 + 0.3 * sin(float(i) * 1.3 + float(seed % 7))
		var dip := 0.006 * sin(float(i) * 0.9 + float(seed % 5))
		pts.append([at + Vector3(cos(a), 0.0, sin(a)) * r * wander + Vector3.UP * (y + dip), 0.0])
		if i < n:
			times.append(maxf(step_len / speed, 0.05))
	var last: Vector3 = (pts[pts.size() - 1] as Array)[0]
	pts.append([last + Vector3.UP * 0.06, 0.0])
	times.append(0.3)
	await _hand_along("fingers", pts, times, Vector3.FORWARD)


## The hand's way through [param pts] (`[place, tilt]`) in [param times]: its speed runs through its places, from nothing and back to it. Gone
## once it has been: the hand is a body only while it is in there.
func _hand_along(shape: String, pts: Array, times: PackedFloat32Array, dir: Vector3) -> void:
	_hand_now = shape
	var clock := PackedFloat32Array([0.0])
	for t in times:
		clock.append(clock[clock.size() - 1] + float(t))
	PhysicsServer3D.body_clear_shapes(_hand)
	for s in _hand_shapes[shape]:
		PhysicsServer3D.body_add_shape(_hand, (s as Array)[0], (s as Array)[1])
	var first: Transform3D = _hand_xf(pts[0] as Array, dir)
	PhysicsServer3D.body_set_state(_hand, PhysicsServer3D.BODY_STATE_TRANSFORM, AssemblyWorld._big(first))
	PhysicsServer3D.body_set_space(_hand, world.space)
	for i in times.size():
		var a: Array = pts[i]
		var b: Array = pts[i + 1]
		var m0 := _slope_at(pts, clock, i)
		var m1 := _slope_at(pts, clock, i + 1)
		var d := float(times[i])
		var n := maxi(int(ceil(d * float(AssemblyWorld.TICKS))), 1)
		for j in n:
			var u := float(j + 1) / float(n)
			var p := Motions.hermite(a[0] as Vector3, b[0] as Vector3, m0 * d, m1 * d, u)
			var turned := _palm(dir, lerpf(float(a[1]), float(b[1]), u))
						# ...never through the floor: a hand on edge reaches far below its middle
			p.y = maxf(p.y, _hand_floor + HAND_OVER_FLOOR + _reach_down(shape, turned))
			var at := Transform3D(turned, p)
			PhysicsServer3D.body_set_state(_hand, PhysicsServer3D.BODY_STATE_TRANSFORM, AssemblyWorld._big(at))
			world.sources = [[p, HAND_REACH]]
			await _step()
	PhysicsServer3D.body_set_space(_hand, RID())
	world.sources = []


func _hand_xf(p: Array, dir: Vector3) -> Transform3D:
	var turned := _palm(dir, float(p[1]))
	var at: Vector3 = p[0]
	at.y = maxf(at.y, _hand_floor + HAND_OVER_FLOOR + _reach_down(_hand_now, turned))
	return Transform3D(turned, at)


## How far under its own middle a hand reaches, turned as it is (meters).
static func _reach_down(shape: String, turned: Basis) -> float:
	if shape == "fingers":
		return 0.0725
	return absf(turned.y.y) * 0.0055 + absf(turned.x.y) * 0.05 + absf(turned.z.y) * 0.06


static func _slope_at(pts: Array, clock: PackedFloat32Array, i: int) -> Vector3:
	if i <= 0 or i >= pts.size() - 1:
		return Vector3.ZERO
	return (((pts[i + 1] as Array)[0] as Vector3) - ((pts[i - 1] as Array)[0] as Vector3)) / maxf(clock[i + 1] - clock[i - 1], 1e-4)


# --- a piece --------------------------------------------------------------------------------------------------------

func _ids_in(stock: String) -> Array:
	var out: Array = []
	for id in world.pieces.size():
		if stock_of[id] == stock and (world.state[id] == AssemblyWorld.FROZEN or world.state[id] == AssemblyWorld.LOOSE):
			out.append(id)
	return out


## Of the pieces of a part, the one most to hand: the highest of what lies in that stock. -1 for none.
func _find(key: String, stock: String) -> int:
	if key.is_empty():
		return -1
	var best := -1
	var high := -INF
	for id in world.pieces.size():
		if stock_of[id] != stock or (world.state[id] != AssemblyWorld.FROZEN and world.state[id] != AssemblyWorld.LOOSE):
			continue
		if Assembly.part_key(world.pieces[id] as Dictionary) == key and world.mid[id].y > high:
			high = world.mid[id].y
			best = id
	return best


## A piece of that part out of its stock, in hand and clear of the rest: it goes in for it, clearing it first if much lies on it, and draws it up
## through what is there, which rides up on it and rolls off as a heap does.
func _fetch(key: String, stock: String, seed: int, brisk: bool) -> int:
	var id := _find(key, stock)
	if id < 0:
		for nm in stocks:
			id = _find(key, String(nm))
			if id >= 0:
				break
	if id < 0:
		return -1
	await _wait(lerpf(0.2, 0.4, Hands.share(seed, 50)) * (0.6 if brisk else 1.0))
	var sd: Dictionary = stocks.get(stock_of[id], {})
	if world.on_top_of(id) >= BURIED and not sd.is_empty() and world.xf[id].origin.y >= 0.0:
		var s := world.top_near(Vector2(world.mid[id].x, world.mid[id].z), 0.04)
		var at := Vector3(world.mid[id].x, 0.0, world.mid[id].z)
		_hand_floor = float(sd["floor"])
		await _stir(at, s, minf(s - world.mid[id].y + 0.005, IN_DEEP * 1.4), seed)
		await _settle(0.5)
	var was := world.xf[id]
	var fallen := was.origin.y < -0.02
	var top := world.top_near(Vector2(was.origin.x, was.origin.z), world.size[id] + 0.01)
	var out_y := maxf(top if not is_nan(top) else was.origin.y, was.origin.y) + world.size[id] + 0.006
	if not sd.is_empty() and not String(sd["thing"]).is_empty():
		out_y = maxf(out_y, was.origin.y + 0.02)
	world.say("tick", world.mid[id], 0.3, world.size[id])
	world.take_up(id)
	_in_hand(id)
	if fallen:
		await _off_the_floor(id, was, seed, brisk)
		was = world.xf[id]
		out_y = OVER_THE_TOP + world.size[id]
		sd = {}
	await _pull(id, was, out_y - was.origin.y, sd, seed, brisk)
	_room(Fingers.ROOM_DRAWN)
	return id


## What has gone off the table is fetched up from the floor: if it rolled in under, a hand brings it out past the edge first, so it comes up beside the table and never through it.
func _off_the_floor(id: int, was: Transform3D, seed: int, brisk: bool) -> void:
	if not req.has("top"):
		return
	var o: Dictionary = req["top"]
	var at := Vector2(was.origin.x, was.origin.z)
	var past := Tables.sdf(o, at) - (PAST_THE_EDGE + world.size[id])
	if past >= 0.0:
		return
	var out := at + Tables.normal(o, at) * -past
	var to := Transform3D(was.basis, Vector3(out.x, was.origin.y + 0.02, out.y))
	await _held_move([id], was, to, clampf(-past / CARRY_SPEED, CARRY_LEAST * 0.5, CARRY_MOST) * (0.7 if brisk else 1.0), seed)


## What has fallen where part [param seat] goes, moved off first: taken up and let lie beside the plate, where it can still be had. A part
## pressed on regardless would shove it about. What lies clear of the place is left.
func _clear_spot(st: Dictionary, seat: Transform3D, seed: int) -> void:
	var half := Vector3(float(st["w"]) * Assembly.STUD * 0.5, 0.0, float(st["d"]) * Assembly.STUD * 0.5)
	var row: Dictionary = Assembly.KINDS[String(st["key"]).get_slice(" ", 0)]
	var tall := float(row["h"]) * Assembly.PLATE + Assembly.STUD_H + IN_THE_WAY_OVER
	var inv := seat.affine_inverse()
	var reach := half.length()
	for id in world.pieces.size():
		if world.state[id] != AssemblyWorld.FROZEN and world.state[id] != AssemblyWorld.LOOSE:
			continue
		if world.mid[id].distance_to(seat.origin) > reach + world.size[id] + tall:
			continue
		if not _lies_in(id, inv, half, tall):
			continue
		var was := world.xf[id]
		var s := hash([seed, id])
		world.say("tick", world.mid[id], 0.25, world.size[id])
		world.take_up(id)
		await _pull(id, was, world.size[id] + 0.015, {}, s, true)
		await _let_go_over([id], "aside" if stocks.has("aside") else stock_of[id], Vector2(was.origin.x, was.origin.z), s, ASIDE_FROM)


## Whether what stands at piece [param id] reaches into the box of half [param half] and height [param tall] that [param inv] takes the world into.
func _lies_in(id: int, inv: Transform3D, half: Vector3, tall: float) -> bool:
	var q: Dictionary = world.pieces[id]
	var hw := float(q["w"]) * Assembly.STUD * 0.5
	var hd := float(q["d"]) * Assembly.STUD * 0.5
	var h := float((Assembly.KINDS[String(q["kind"])] as Dictionary)["h"]) * Assembly.PLATE
	var at := world.xf[id]
	for u in [-1.0, -0.5, 0.0, 0.5, 1.0]:
		for v in [-1.0, -0.5, 0.0, 0.5, 1.0]:
			var p: Vector3 = inv * (at * Vector3(hw * float(u), h * 0.5, hd * float(v)))
			if absf(p.x) < half.x and absf(p.z) < half.z and p.y > -0.002 and p.y < tall:
				return true
	return false


## Drawn out as fingers draw one, not lifted on a wire: the grip tips one end of it up, and it comes on up and turning, toward the middle of what it
## is in, what it meets riding up on it as a heap does. Near a wall it turns as much as the wall leaves it. The end of the draw is left to go on under the next move ([method _held_move]).
func _pull(id: int, was: Transform3D, up: float, sd: Dictionary, seed: int, brisk: bool) -> void:
	var reach := world.size[id]
	var room := 1.0
	var aside := Vector3.ZERO
	if not sd.is_empty():
		var off := _middle_of(sd) - Vector2(was.origin.x, was.origin.z)
		if not String(sd["thing"]).is_empty():
			room = clampf((float(sd["radius"]) - off.length()) / maxf(reach * 1.5, 0.01), 0.25, 1.0)
		if off.length() > 1e-3:
			aside = Vector3(off.x, 0.0, off.y).normalized() * minf(up * DRAW_ASIDE, DRAW_ASIDE_MOST)
	var tip := deg_to_rad(lerpf(GRIP_TIP.x, GRIP_TIP.y, Hands.share(seed, 80))) * room
	var tip_about := Basis(Vector3.UP, TAU * Hands.share(seed, 81)) * Vector3.RIGHT
	var gripped := Transform3D(Basis(tip_about, tip) * was.basis, was.origin + Vector3(0.0, reach * sin(tip), 0.0))
	await _held_move([id], was, gripped, lerpf(GRIP_TAKES.x, GRIP_TAKES.y, Hands.share(seed, 82)) * (0.7 if brisk else 1.0), seed)
	var turn := deg_to_rad(lerpf(DRAW_TURN.x, DRAW_TURN.y, Hands.share(seed, 83))) * room * (-1.0 if Hands.share(seed, 84) < 0.5 else 1.0)
	var turn_about := Basis(Vector3.UP, TAU * Hands.share(seed, 85)) * Vector3.RIGHT
	var out := Transform3D(Basis(turn_about, turn) * gripped.basis, gripped.origin + Vector3(0.0, up, 0.0) + aside)
	var q0 := gripped.basis.get_rotation_quaternion()
	var q1 := out.basis.get_rotation_quaternion()
	var n := maxi(int(ceil(clampf(up / DRAW_OUT, DRAW_LEAST, DRAW_MOST) * float(AssemblyWorld.TICKS))), 2)
	var runs := int(float(n) * RUN_ON)
	for j in runs:
		var v := Hands.smooth(float(j + 1) / float(n))
		world.carry_to(id, Transform3D(Basis(q0.slerp(q1, v)), gripped.origin.lerp(out.origin, v)))
		await _step()
	_run_on = {"id": id, "to": out, "j": runs, "n": n}


## What is in hand ([param ids]) moved from [param a] to [param b] by [param secs], as one, a hand's way ([param way] for a carry: else straight). What is left of a draw goes on under it,
## as one movement of a hand goes on under the next (Flash and Henis, 1991): the two added, so it never comes to rest between them.
func _held_move(ids: Array, a: Transform3D, b: Transform3D, secs: float, seed: int, way := {}) -> void:
	var n := maxi(int(ceil(secs * float(AssemblyWorld.TICKS))), 1)
	var q0 := a.basis.get_rotation_quaternion()
	var q1 := b.basis.get_rotation_quaternion()
	var starts: Array = []
	var inv := a.affine_inverse()
	for id in ids:
		starts.append(inv * world.xf[int(id)])
	var draw: Dictionary = _run_on if ids.size() == 1 and int(_run_on.get("id", -1)) == int(ids[0]) else {}
	_run_on = {}
	var p0 := a.origin
	var rest := Vector3.ZERO
	var q_rest := Quaternion.IDENTITY
	var done_at := 0.0
	if not draw.is_empty():
		var to: Transform3D = draw["to"]
		rest = to.origin - a.origin
		q_rest = (to.basis.get_rotation_quaternion() * q0.inverse()).normalized()
		p0 += rest
		q0 = (q_rest * q0).normalized()
		done_at = Hands.smooth(float(draw["j"]) / float(draw["n"]))
	for j in n:
		var u := float(j + 1) / float(n)
		var p: Vector3
		if way.is_empty():
			p = p0.lerp(b.origin, Hands.smooth(u))
		else:
			p = Hands.carried(p0, b.origin, Vector3.ZERO, Vector3.ZERO, float(way["lift"]), u, seed, way["rise"])
		var q := q0.slerp(q1, Hands.smooth(u))
		if not draw.is_empty():
			var v := (Hands.smooth(float(int(draw["j"]) + j + 1) / float(draw["n"])) - done_at) / maxf(1.0 - done_at, 1e-5)
			v = maxf(v, Hands.smooth(u))
			p -= rest * (1.0 - v)
			q = Quaternion.IDENTITY.slerp(q_rest.inverse(), 1.0 - v) * q
		var m := Transform3D(Basis(q), p)
		for i in ids.size():
			world.carry_to(int(ids[i]), m * (starts[i] as Transform3D))
		await _step()


## Carried, [param id] from [param a] to [param b]: there is more room on the way than at either end, and [param room] at the other.
func _carry(id: int, a: Transform3D, b: Transform3D, secs: float, seed: int, way: Dictionary, room: float) -> void:
	_room(Fingers.ROOM_CARRY, secs * 0.5)
	await _held_move([id], a, b, secs, seed, way)
	_room(room)


## How long the way from [param a] to [param b] takes a hand.
static func _carry_time(a: Vector3, b: Vector3, brisk: bool) -> float:
	return clampf(a.distance_to(b) / CARRY_SPEED, CARRY_LEAST, CARRY_MOST) * (0.72 if brisk else 1.0)


## How high what stands under [param x], [param z] stands: the model on its plate, a heap, what stands on the table and can be gone over.
func _top_at(x: float, z: float, half: float) -> float:
	var out: float = (req["base_at"] as Vector3).y
	out = maxf(out, _model_top_at(x, z, half))
	var heap := world.top_near(Vector2(x, z), half + 0.01)
	if not is_nan(heap):
		out = maxf(out, heap)
	for ob in req["obstacles"]:
		var box: AABB = ob
		if x >= box.position.x - half and x <= box.end.x + half and z >= box.position.z - half and z <= box.end.z + half and box.end.y < TALL:
			out = maxf(out, box.end.y)
	return out


## How high the model stands under [param x], [param z]: stud by stud, for a tower at one end of a plate is no reason to go over the air at the other.
func _model_top_at(x: float, z: float, half: float) -> float:
	if _tops.is_empty():
		return 0.0
	var b: Vector3 = req["base_at"]
	var size: Array = req["base_size"]
	var l := Basis(Vector3.UP, -yaw) * Vector3(x - b.x, 0.0, z - b.z)
	var cx := l.x / Assembly.STUD + float(size[0]) * 0.5
	var cz := l.z / Assembly.STUD + float(size[1]) * 0.5
	var reach := half / Assembly.STUD + 1.0
	var out := 0.0
	for j in range(floori(cz - reach), ceili(cz + reach) + 1):
		for i in range(floori(cx - reach), ceili(cx + reach) + 1):
			out = maxf(out, float(_tops.get(Vector2i(i, j), 0.0)))
	return out


## What stands over each stud, seen again from what is seated.
func _recount_tops() -> void:
	_tops = {}
	for k in world.seats:
		if world.state[int(k)] == AssemblyWorld.SEATED:
			_top_of_piece(int(k))


func _top_of_piece(id: int) -> void:
	if not _at_of.has(id):
		return
	var q: Dictionary = world.pieces[id]
	var at: Array = _at_of[id]
	var top := _top_of_seated(id)
	var size := Assembly.turned_size(int(q["w"]), int(q["d"]), int(at[2]))
	for j in size.y:
		for i in size.x:
			var c := Vector2i(int(at[0]) + i, int(at[1]) + j)
			_tops[c] = maxf(float(_tops.get(c, 0.0)), top)


## Its way: `{lift, rise}`, what [method Hands.carried] needs to bring it from [param a] to [param b] clear of what is under its way: up first clear
## of what it leaves, down last among what it goes to.
func _way(a: Vector3, b: Vector3, half: float) -> Dictionary:
	var rise := Vector2(maxf(_top_at(a.x, a.z, half) + CLEAR_OVER - a.y, 0.0), maxf(_top_at(b.x, b.z, half) + CLEAR_OVER - b.y, 0.0))
	var lift := maxf(0.02, maxf(rise.x, rise.y) * 1.15)
	for _pass in 2:
		var span := Hands.across(lift, rise)
		var raised := false
		for k in range(1, WAY_LOOKS):
			var lin := lerpf(span.x, span.y, float(k) / float(WAY_LOOKS))
			var p := a.lerp(b, Hands.timing((lin - span.x) / maxf(span.y - span.x, 1e-6)))
			var need := _top_at(p.x, p.z, half) + CLEAR_OVER - (p.y + lift * Hands.lift_at(lin))
			if need > 0.0:
				lift += need / maxf(Hands.lift_at(lin), 0.35)
				raised = true
		if not raised:
			break
	return {"lift": minf(lift, LIFT_MOST), "rise": rise}


## Where a hand holds a thing up to look at it: where the lens sees it, a little to the side it came from [param from], and low, at an angle of its own, clear of what is under it.
func _view_xf(seed: int, from: Vector3, reach: float) -> Transform3D:
	var lens: Transform3D = req["lens"]
	var far := lerpf(VIEW_FAR.x, VIEW_FAR.y, Hands.share(seed, 24))
	var high := far * tan(deg_to_rad(float(req["fov"]) * 0.5))
	var side := 1.0 if lens.basis.x.dot(from - lens.origin) >= 0.0 else -1.0
	if Hands.share(seed, 25) > VIEW_SAME_SIDE:
		side = -side
	var across := side * lerpf(VIEW_ACROSS.x, VIEW_ACROSS.y, Hands.share(seed, 26)) * high * VIEW_ASPECT
	var at := lens.origin - lens.basis.z * far + lens.basis.x * across + lens.basis.y * lerpf(VIEW_UP.x, VIEW_UP.y, Hands.share(seed, 27)) * high
	at.y = maxf(at.y, _top_at(at.x, at.z, reach) + VIEW_CLEAR)
	return Transform3D(Basis(Vector3.UP, TAU * Hands.share(seed, 22)) * Basis(Vector3.RIGHT, deg_to_rad(lerpf(35.0, 70.0, Hands.share(seed, 23)))), at)


## What is in hand back into a stock: over where it goes, and let go. It falls as far as it falls and lies where it lands; a piece
## asked for from that stock later is wherever that turned out to be.
func _let_go_over(ids: Array, stock: String, from: Vector2, seed: int, height: float) -> void:
	var sd: Dictionary = stocks.get(stock, {})
	var first := world.xf[int(ids[0])]
	var near := from
	if not sd.is_empty():
		var aim := _middle_of(sd)
		var r := maxf(float(sd["radius"]) - 0.04, 0.01)
		if from.distance_to(aim) > r:
			near = aim + (from - aim).normalized() * r * lerpf(0.4, 0.95, Hands.share(seed, 60))
		near += Vector2(cos(float(seed)), sin(float(seed))) * 0.012
	var top := world.top_near(near, 0.05)
	var floor_y := float(sd.get("floor", 0.0))
	var y: float = maxf(top if not is_nan(top) else floor_y, floor_y) + height
	var over := Transform3D(first.basis, Vector3(near.x, y, near.y))
	var way := _way(first.origin, over.origin, 0.03)
	if _cur.has("hand"):
		_room(Fingers.ROOM_CARRY, _carry_time(first.origin, over.origin, false) * 0.5)
	await _held_move(ids, first, over, _carry_time(first.origin, over.origin, false), seed, way)
	_out_of_hand()
	for id in ids:
		var hs := hash([seed, id])
		world.let_go(int(id), Vector3(Hands.share(hs, 1) - 0.5, -0.2, Hands.share(hs, 2) - 0.5) * 0.15,
			Vector3(Hands.share(hs, 3) - 0.5, Hands.share(hs, 4) - 0.5, Hands.share(hs, 5) - 0.5) * 7.0)
		stock_of[int(id)] = stock
	await _settle()


func _put(st: Dictionary, seed: int) -> void:
	var brisk: bool = st["brisk"]
	_stop(STOP_THINK * 0.6)
	var local := log.place_xf(int(st["x"]), int(st["z"]), int(st["l"]), int(st["w"]), int(st["d"]), int(st["turn"]))
	var plate := log.base_xf(yaw)
	var seat := plate * local
	await _clear_spot(st, seat, seed)
	var id := await _fetch(String(st["key"]), String(st["stock"]), seed, brisk)
	if id < 0:
		push_warning("assembly_bake: no %s for step" % String(st["key"]))
		return
	var over := Transform3D(seat.basis, seat.origin + Vector3(0.0, HOVER, 0.0))
	var near := Transform3D(seat.basis, seat.origin + Vector3(0.0, PRESS_FROM, 0.0))
	var here := world.xf[id]
	var half := world.size[id]
	if float(st["look"]) > 0.0:
		here = await _hold_up(id, here, seed, float(st["look"]))
	for p in st["first"]:
		var a: Array = p
		var other := plate * log.place_xf(int(a[0]), int(a[1]), int(a[2]), int(st["w"]), int(st["d"]), int(st["turn"]))
		var there := Transform3D(other.basis, other.origin + Vector3(0.0, HOVER, 0.0))
		await _carry(id, here, there, _carry_time(here.origin, there.origin, false), seed, _way(here.origin, there.origin, half), Fingers.ROOM_HOVER)
		await _settle(HOLD_SETTLE)
		_stop(STOP_HOVER)
		await _wait(0.1)
		_room(Fingers.ROOM_HOVER)
		here = there
	await _carry(id, here, over, _carry_time(here.origin, over.origin, brisk), seed, _way(here.origin, over.origin, half), Fingers.ROOM_HOVER)
	await _settle(HOLD_SETTLE)
	_stop(STOP_HOVER * (0.2 if brisk else 1.0), float(st["hover"]) if float(st["hover"]) > 0.0 else -1.0)
	_room(Fingers.ROOM_HOVER)
	await _held_move([id], over, near, 0.26 if brisk else 0.48, seed)
	_room(0.0)
	await _held_move([id], near, seat, 0.09 if brisk else 0.14, seed)
	_out_of_hand()
	world.say("click", seat.origin, 1.0, half, AssemblyWorld.weight_of(String((world.pieces[id] as Dictionary)["kind"]), int((world.pieces[id] as Dictionary)["w"]), int((world.pieces[id] as Dictionary)["d"])))
	_at_of[id] = [int(st["x"]), int(st["z"]), int(st["turn"])]
	_seat(id, int(st["slot"]), seat, local)
	await _wait(0.1)
	_stop(STOP_THINK * (0.3 if brisk else 1.0))


func _seat(id: int, slot: int, at: Transform3D, local: Transform3D) -> void:
	world.seat(id, at, local)
	_seat_log.append([id, world.tau, true, local])
	_body_of[slot] = id
	_top_model = maxf(_top_model, _top_of_seated(id))
	_top_of_piece(id)


func _top_of_seated(id: int) -> float:
	var q: Dictionary = world.pieces[id]
	return world.xf[id].origin.y + float((Assembly.KINDS[String(q["kind"])] as Dictionary)["h"]) * Assembly.PLATE + Assembly.STUD_H


## Held up where the lens sees it, and looked at: the record goes there and stops, for [param seconds] the record cannot say what fingers do in ([Fingers]), and in the air they are free.
func _hold_up(id: int, here: Transform3D, seed: int, seconds: float) -> Transform3D:
	var shown := _view_xf(seed, here.origin, world.size[id])
	await _carry(id, here, shown, _carry_time(here.origin, shown.origin, false) * 1.15, seed, _way(here.origin, shown.origin, world.size[id]), Fingers.ROOM_FREE)
	await _settle(HOLD_SETTLE)
	_stop(STOP_HELD, seconds)
	await _wait(0.05)
	_room(Fingers.ROOM_FREE)
	return shown


func _try(st: Dictionary, seed: int) -> void:
	_stop(STOP_THINK * 0.6)
	var id := await _fetch(String(st["key"]), String(st["stock"]), seed, false)
	if id < 0:
		return
	var plate := log.base_xf(yaw)
	var seat := plate * log.place_xf(int(st["x"]), int(st["z"]), int(st["l"]), int(st["w"]), int(st["d"]), int(st["turn"]))
	var over := Transform3D(seat.basis, seat.origin + Vector3(0.0, HOVER, 0.0))
	var near := Transform3D(seat.basis, seat.origin + Vector3(0.0, PRESS_FROM, 0.0))
	var here := world.xf[id]
	var half := world.size[id]
	var came_from := Vector2(here.origin.x, here.origin.z)
	await _carry(id, here, over, _carry_time(here.origin, over.origin, false), seed, _way(here.origin, over.origin, half), Fingers.ROOM_HOVER)
	await _settle(HOLD_SETTLE)
	_stop(STOP_HOVER)
	_room(Fingers.ROOM_HOVER)
	await _held_move([id], over, near, 0.42, seed)
	if bool(st["pressed"]):
		_room(0.0)
		await _held_move([id], near, seat, 0.14, seed)
		world.say("click", seat.origin, 0.85, half)
		_stop(STOP_HOVER)
		await _wait(0.05)
		_room(0.0)
		world.say("pop", seat.origin, 0.6, half)
		await _held_move([id], seat, near, 0.12, seed)
		_room(0.0)
	else:
				# ...on the studs and not going: it is rocked a little, to see
		_room(Fingers.ROOM_TRIED)
		world.say("tick", seat.origin, 0.3, half)
		_stop(STOP_HOVER * 0.5)
		await _wait(0.05)
		_room(Fingers.ROOM_TRIED)
	await _held_move([id], near, over, 0.3, seed)
	_room(Fingers.ROOM_HOVER)
	_stop(STOP_THINK)
	await _wait(0.05)
	_room(Fingers.ROOM_HOVER)
	await _back_where(id, st, came_from, seed)


func _look(st: Dictionary, seed: int) -> void:
	_stop(STOP_THINK * 0.6)
	var id := await _fetch(String(st["key"]), String(st["stock"]), seed, false)
	if id < 0:
		return
	var came_from := Vector2(world.xf[id].origin.x, world.xf[id].origin.z)
	await _hold_up(id, world.xf[id], seed, float(st["seconds"]))
	await _back_where(id, st, came_from, seed)


func _back_where(id: int, st: Dictionary, came_from: Vector2, seed: int) -> void:
	var to := String(st["to"])
	var height := ASIDE_FROM if to == "aside" else lerpf(BACK_FROM.x, BACK_FROM.y, Hands.share(seed, 61))
	await _let_go_over([id], to, came_from, seed, height)


## What comes off the model: up as one with a pop, carried over the stock, and let go - and it comes apart as what falls comes apart.
func _bring_off(st: Dictionary, seed: int) -> void:
	_stop(STOP_THINK * 0.5)
	var ids: Array = []
	for s in st["slots"]:
		if _body_of.has(int(s)):
			ids.append(int(_body_of[int(s)]))
	if ids.is_empty():
		return
	var mid := Vector3.ZERO
	for id in ids:
		mid += world.xf[int(id)].origin
	mid /= float(ids.size())
	world.say("pop", mid, 0.9, 0.02, 1.0 + float(ids.size()) * 0.4)
	for id in ids:
		world.unseat(int(id))
		_seat_log.append([int(id), world.tau, false, Transform3D.IDENTITY])
	_top_model = 0.0
	for k in world.seats:
		if world.state[int(k)] == AssemblyWorld.SEATED:
			_top_model = maxf(_top_model, _top_of_seated(int(k)))
	_recount_tops()
	var a := Transform3D(world.xf[int(ids[0])].basis, world.xf[int(ids[0])].origin)
	var up := Transform3D(a.basis, a.origin + Vector3(0.0, 0.012, 0.0))
	await _held_move(ids, a, up, 0.2, seed)
	var to := String(st["stock"])
	var sd: Dictionary = stocks.get(to, {})
	var target: Vector2 = sd.get("middle", Vector2(up.origin.x, up.origin.z))
	var from := target.lerp(Vector2(mid.x, mid.z), 0.15)
	await _let_go_over(ids, to, from, seed, DROP_FROM if to != "aside" else ASIDE_FROM * 2.0)


## The plate turned: with what lies loose on it, and everything built on it.
func _turn(st: Dictionary, seed: int) -> void:
	_stop(STOP_THINK)
	var y0 := float(st["y0"])
	var y1 := float(st["y1"])
	var b: Vector3 = req["base_at"]
	var riders: Array = []
	var size: Array = req["base_size"]
	var reach := Vector2(float(size[0]), float(size[1])) * Assembly.STUD * 0.5
	for id in world.pieces.size():
		if world.state[id] != AssemblyWorld.FROZEN and world.state[id] != AssemblyWorld.LOOSE:
			continue
		var l := Basis(Vector3.UP, -y0) * (world.mid[id] - b)
		if absf(l.x) < reach.x and absf(l.z) < reach.y and world.mid[id].y < _top_model + 0.03:
			riders.append(id)
	for id in riders:
		world.take_up(int(id))
	var secs := 3.0
	var t0 := world.tau
	var n := int(secs * float(AssemblyWorld.TICKS))
	var starts: Array = []
	for id in riders:
		starts.append((Transform3D(Basis(Vector3.UP, y0), b)).affine_inverse() * world.xf[int(id)])
	var next_scuff := 0.0
	for j in n:
		var u := float(j + 1) / float(n)
		var y := lerpf(y0, y1, Hands.smooth(u))
		var m := Transform3D(Basis(Vector3.UP, y), b)
		for i in riders.size():
			world.carry_to(int(riders[i]), m * (starts[i] as Transform3D))
		if float(j) / float(AssemblyWorld.TICKS) >= next_scuff:
			var fast := sin(u * PI)
			if fast > 0.15:
				world.say("scuff", b, 0.25 + 0.5 * fast, 0.09)
			next_scuff += lerpf(0.1, 0.24, Hands.share(seed, j))
		await _step()
	_turns.append([t0, world.tau, y0, y1])
	yaw = y1
	var plate := log.base_xf(yaw)
	PhysicsServer3D.body_set_state(_base_body, PhysicsServer3D.BODY_STATE_TRANSFORM, AssemblyWorld._big(Transform3D(plate.basis, plate.origin + Vector3(0.0, (Assembly.BASE_T + Assembly.STUD_H) * 0.5, 0.0))))
	for k in world.seats:
		var id := int(k)
		if world.state[id] == AssemblyWorld.SEATED:
			var list: Array = world.seats[k]
			world.moved_with_plate(id, plate * ((list[list.size() - 1] as Array)[2] as Transform3D))
	for id in riders:
		world.let_go(int(id))
	_stop(STOP_THINK)
