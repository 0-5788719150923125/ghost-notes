extends RefCounted
class_name PuppetBody

## PuppetBody - a rigged drawing alive on the stage (next/cartoon.md): the [PuppetRig]'s pictures on its skeleton, drawn by the
## engine's own 2D skinning (a [Skeleton2D] of [Bone2D]s and a [Polygon2D] per layer, weighted as the rig says), and the motion
## the verbs steer ([Actions]: move, pose, talk, face, strike, hit, hop, shake).
##
## Every bone springs toward where it is told to be (its held pose plus what its life adds), so a limb overshoots and settles as
## a drawn one would; a loose part (an ear, a tail, a tentacle) springs softest and trails. Its life: breath, a sway, blinks a few
## seconds apart, and while it moves a gait (walk, run, tiptoe, hop, float, slide) read off how fast its place is moving - legs
## swinging, arms against them, a bob and a waddle, a lean into the way it goes. Talking chatters the jaw in syllables and words
## and nods the head, heard by nobody (a show may be silent). A hit recoils, spins and squashes it on springs; a hop squashes,
## stretches and lands.
##
## A puppet with a model sheet ([PuppetSheet]) is a drawing per view, mouth and mood, and SWAPS between them as a hand-drawn cartoon
## does: its profile while it goes across (mirrored going left - a drawing facing us is never mirrored), the latched [member view]
## otherwise; the mouth drawing its syllables call for, each held at least two frames at twelve a second; its [member mood]'s drawing
## while it has one. A swap snaps a little squash. Every drawing shares the springs by bone name, so a pose carries across a swap.
##
## Drawn as a node under the stage, placed each frame where the stage's lens puts its feet: `node` (placed) -> its squash about
## its feet (lean, spin, bob) -> a rig per drawing (its anchor at the origin, only the one shown visible) -> its skeleton and layers. The stage draws what is under it
## (a backdrop, shadows); puppets go over in depth order ([method arrange]) and the stage's [CartoonFx] over them.

## Springs, by a bone's role: [stiffness (rad/s), damping ratio]. A loose part trails and swings.
const SPRING := {"": [15.0, 0.55], "head": [12.0, 0.5], "loose": [7.0, 0.28], "jaw": [30.0, 0.7], "eye": [16.0, 0.4],
	"body": [14.0, 0.6], "arm": [13.0, 0.5], "hand": [11.0, 0.45], "leg": [16.0, 0.6], "prop": [12.0, 0.5]}
## Gaits: steps a second at its usual speed (in heights a second, `pace`), a leg's and an arm's swing (degrees), the bob (a share
## of its height), the waddle and the lean (degrees).
const GAITS := {
	"walk": {"pace": 0.55, "steps": 1.9, "leg": 16.0, "arm": 14.0, "bob": 0.025, "roll": 4.0, "lean": 4.0},
	"run": {"pace": 1.6, "steps": 3.4, "leg": 30.0, "arm": 34.0, "bob": 0.05, "roll": 5.0, "lean": 13.0},
	"tiptoe": {"pace": 0.3, "steps": 1.3, "leg": 9.0, "arm": 6.0, "bob": 0.03, "roll": 2.5, "lean": -3.0},
	"hop": {"pace": 0.7, "steps": 2.2, "leg": 6.0, "arm": 10.0, "bob": 0.14, "roll": 1.0, "lean": 3.0},
	"float": {"pace": 0.4, "steps": 0.6, "leg": 7.0, "arm": 5.0, "bob": 0.04, "roll": 3.0, "lean": 6.0},
	"slide": {"pace": 0.8, "steps": 0.0, "leg": 0.0, "arm": 4.0, "bob": 0.0, "roll": 0.0, "lean": 8.0},
}
## Poses any rig has, by role: where each arm (and leg) points on the screen, in degrees (0 right, -90 up), for its left and its
## right; `head` tilts the head, `sq` squashes. A rig's own poses (`rig.json` `poses`) are bone angles and win by name.
const POSES := {
	"rest": {},
	"arms_up": {"arm": [-125.0, -55.0]},
	"arms_out": {"arm": [180.0, 0.0]},
	"arms_down": {"arm": [112.0, 68.0]},
	"cower": {"arm": [-50.0, -130.0], "head": 12.0, "sq": 0.9},
	"shrug": {"arm": [160.0, 20.0], "head": -8.0},
	"spooky": {"arm": [-160.0, -20.0], "hand": 30.0, "head": -6.0},
	"cheer": {"arm": [-105.0, -75.0], "head": -10.0, "sq": 1.06},
	"windup": {"arm": [-110.0, -70.0], "head": -6.0},
	"kick": {"leg": [150.0, 30.0]},
}
## How far a pose turns an arm toward where it points, at most (degrees): a drawing bends, it does not spin round.
const REACH := 115.0
## How much a puppet with a model sheet bends its limbs, of what one drawing alone would: its big moves are drawings of their own.
const SHEET_BEND := 0.3
## The drawing a pose shows on a puppet whose sheet has it ([constant PuppetSheet.REGISTRY]).
const POSE_DRAWINGS := {"cower": "scared", "arms_up": "scared", "cheer": "laughing", "windup": "windup"}
## How long a mouth drawing holds at least (s): two frames at twelve a second, as a hand-drawn mouth does.
const MOUTH_HOLD := 2.0 / 12.0
## The simulation's step (s): springs advance in steps no longer than this, the same live as in an export.
const STEP := 1.0 / 120.0
## Seconds a blink takes, and the seconds between blinks while nothing else blinks it.
const BLINK := 0.16
const BLINK_EVERY := [2.2, 5.5]

var rig: PuppetRig = null
var node: Node2D = null
var height := 1.0                    # world units, its feet to its top
var facing := 1.0                    # 1 as drawn, -1 mirrored
var pose := {}                       # bone -> degrees, held (what verbs latch)
var gait := ""                       # how it goes while its place moves ("" its own: a walk)
var talking := 0.0                   # how hard it is talking, 0-1
var tremble := 0.0                   # a shake, 0-1
var lift := 0.0                      # a hop's height now (shares of its height)
var spooky := 0.0                    # floating off the ground, 0-1 (a ghost's float)
var squash_hold := 1.0               # a squash a pose holds (height over width)
var snap := 1.0                      # how much stiffer the limbs spring for now (a strike's swing keeps up with it)
var shown := true

## The view it holds while it is not going across: front, side or back ([method Actions.Face] latches it).
var view := "front"
## Its mood: a key of [constant PuppetSheet.MOODS], drawn where it has that drawing ("" none).
var mood := ""
## What it is doing that has a drawing of its own ([constant PuppetSheet.ACTIONS]: a verb's wind-up, a blow's reeling), "" none.
var action := ""
## The drawing a held pose shows ([constant POSE_DRAWINGS]), "" none.
var posed := ""
var _action_left := 0.0              # seconds a reaction ([method react]) holds its drawing
var _bend := 1.0                     # how much its limbs bend ([constant SHEET_BEND] with a model sheet)

var _squash: Node2D = null
var _cels := {}                      # drawing key -> Cel
var _cel: Cel = null                 # the one shown
var _mouth := "closed"
var _mouth_t := 0.0
var _role := {}
var _side := {}
var _dir := {}                       # name -> the bone's rest direction on screen (degrees)
var _order: Array = []
var _angle := {}
var _vel := {}
var _t := 0.0
var _left := 0.0                     # time not yet stepped
var _rng := RandomNumberGenerator.new()
var _ph := []                        # seeded phases
var _flip := 1.0
var _phase := 0.0
var _speed := 0.0                    # how fast its place moves along the ground (heights a second), smoothed
var _heading := 0.0                  # -1..1 which way across the screen
var _last := Vector3.INF
var _talk := 0.0
var _jaw := 0.0
var _sq := 1.0
var _sq_v := 0.0
var _recoil := Vector2.ZERO          # rig px
var _recoil_v := Vector2.ZERO
var _spin := 0.0                     # degrees
var _spin_v := 0.0
var _lean := 0.0
var _eye := 1.0
var _eye_v := 0.0
var _eye_pop := 0.0                  # seconds the eyes stay popped
var _blink_t := -1.0
var _next_blink := 2.0
var _float := 0.0


func _init(r: PuppetRig, seed: int, h: float) -> void:
	rig = r
	height = maxf(0.05, h)
	_rng.seed = seed
	for i in 8:
		_ph.append(_rng.randf() * TAU)
	_next_blink = _rng.randf_range(BLINK_EVERY[0], BLINK_EVERY[1])
	var drawn: Dictionary = rig.drawings if not rig.drawings.is_empty() else {"front": rig}
	var keys := drawn.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return a == "front" or (b != "front" and a < b))
	for key in keys:
		var cel := Cel.new()
		cel.key = String(key)
		cel.rig = drawn[key]
		cel.view = PuppetSheet.view_of(cel.key)
		for b in cel.rig.data.get("bones", []):
			var d: Dictionary = b
			var n := String(d["name"])
			var head := _v2(d["head"])
			var tail := _v2(d["tail"])
			var parent := String(d.get("parent", ""))
			cel.rest[n] = head - (_v2(cel.rig.bone(parent)["head"]) if not parent.is_empty() else Vector2.ZERO)
			cel.order.append(n)
			if not _role.has(n):
				_order.append(n)
				_role[n] = String(d.get("role", ""))
				_side[n] = String(d.get("side", ""))
				_dir[n] = rad_to_deg((tail - head).angle()) if tail.distance_to(head) > 1.0 else 90.0
				_angle[n] = 0.0
				_vel[n] = 0.0
		_cels[cel.key] = cel
	_cel = _cels.get("front", _cels.values()[0])
	for c in _cels.values():
		(c as Cel).talks = _cels.has((c as Cel).view + "_open")
	_bend = SHEET_BEND if _cels.size() > 1 else 1.0


static func _v2(a: Variant) -> Vector2:
	return Vector2(float(a[0]), float(a[1])) if a is Array and (a as Array).size() >= 2 else Vector2.ZERO


# --- the node -----------------------------------------------------------------------------------------------------------

## Its node, made the first time it is asked for: a rig per drawing - its skeleton, its layers weighted to it, its lids - each
## built the first time it is shown ([method _built]), so a puppet comes up at the cost of one drawing.
func build() -> Node2D:
	if node != null and is_instance_valid(node):
		return node
	node = Node2D.new()
	node.name = "Puppet"
	node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_squash = Node2D.new()
	_squash.name = "Squash"
	node.add_child(_squash)
	for key in _cels:
		(_cels[key] as Cel).root = null
	_built(_cel).root.visible = true
	return node


## Drawing [param cel] with its node built under the puppet's (hidden), where it is not yet.
func _built(cel: Cel) -> Cel:
	if cel.root == null:
		cel.build()
		cel.root.visible = false
		_squash.add_child(cel.root)
	return cel


## Its node let go (its stage is going and nothing carries it on).
func free_node() -> void:
	if node != null and is_instance_valid(node):
		node.queue_free()
	node = null


## Its node under [param stage], moved there from wherever it was (a cut carried it on).
func adopt(stage: Node) -> void:
	build()
	if node.get_parent() == stage:
		return
	if node.get_parent() != null:
		node.reparent(stage, false)
	else:
		stage.add_child(node)


## Puppets under [param stage] put in depth order (the farthest first), and its marks over them all, a moment [param dt] on.
static func arrange(stage: Node, actors: Array, dt: float) -> void:
	var drawn: Array = []
	for a in actors:
		var b: Variant = a.get("body")
		if b is PuppetBody and (b as PuppetBody).node != null and is_instance_valid((b as PuppetBody).node) \
				and (b as PuppetBody).node.get_parent() == stage:
			drawn.append([float(a.state.get("depth", 0.0)), (b as PuppetBody).node])
	if drawn.size() > 1:
		drawn.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) > float(y[0]))
		for i in drawn.size():
			stage.move_child(drawn[i][1], i)
	var fx := stage.get_node_or_null(CartoonFx.NAME) as CartoonFx
	if fx != null:
		stage.move_child(fx, stage.get_child_count() - 1)
		fx.step(dt)


# --- what the verbs steer -----------------------------------------------------------------------------------------------

## The angles of pose [param name] for this rig: its own pose by that name, else one any rig has ([constant POSES]), each arm
## turned toward where the pose points it. [param toward] (screen degrees) points the arm of [param side] there instead (a
## strike, a point).
func pose_angles(name: String, toward := NAN, side := "") -> Dictionary:
	var own: Dictionary = rig.data.get("poses", {})
	if own.has(name) and own[name] is Dictionary:
		return (own[name] as Dictionary).duplicate()
	var p: Dictionary = POSES.get(name, {})
	var out := {}
	for n in _order:
		var role := String(_role[n])
		var sd := String(_side[n])
		if (role == "arm" or role == "leg") and p.has(role):
			var two: Array = p[role]
			var want := float(two[0] if sd == "left" else two[1])
			if sd.is_empty():
				continue
			out[n] = _turn_to(n, want)
		elif role == "hand" and p.has("hand"):
			out[n] = float(p["hand"]) * (-1.0 if sd == "left" else 1.0)
		elif role == "head" and p.has("head"):
			out[n] = float(p["head"])
	if not is_nan(toward) and not side.is_empty():
		for n in _order:
			if String(_role[n]) == "arm" and String(_side[n]) == side:
				out[n] = _turn_to(n, toward)
	if p.has("sq"):
		out["_sq"] = float(p["sq"])
	return out


## How far bone [param n] turns to point toward [param want] (screen degrees, as drawn facing its own way), at most REACH.
func _turn_to(n: String, want: float) -> float:
	var d := wrapf(want - float(_dir[n]), -180.0, 180.0)
	return clampf(d, -REACH, REACH)


## The arm (its first bone) on the side nearer screen x [param toward_x] from [param from_x], as it is drawn now.
func arm_toward(from_x: float, toward_x: float) -> String:
	var want := "right" if (toward_x - from_x) * facing >= 0.0 else "left"
	if not rig.bones_of("arm", want).is_empty():
		return want
	return "left" if want == "right" and not rig.bones_of("arm", "left").is_empty() else ("right" if not rig.bones_of("arm", "right").is_empty() else "")


## A hit from the screen direction [param dir] (x across, y up), as hard as [param force] (0-1): it recoils away, spins, squashes
## and its eyes pop.
func hit(dir: Vector2, force: float) -> void:
	var h := rig.height()
	var d := dir.normalized() if dir.length() > 0.001 else Vector2(1, 0)
	_recoil_v += Vector2(d.x, -d.y * 0.4) * h * (0.5 + 0.7 * force)
	_spin_v += d.x * (110.0 + 230.0 * force)
	_sq_v -= 5.0 + 7.0 * force
	pop_eyes(0.4 + 0.6 * force, 0.5 + force)


## Its drawing of [param what] (reeling, ...) shown for [param secs], whatever it was doing.
func react(what: String, secs: float) -> void:
	action = what
	_action_left = secs


## A squash kicked in: [param amount] below 0 flattens it, above stretches it, on a spring.
func kick(amount: float) -> void:
	_sq_v += amount * 14.0


## Its eyes swollen by [param amount] for [param secs].
func pop_eyes(amount: float, secs: float) -> void:
	_eye_v += amount * 22.0
	_eye_pop = maxf(_eye_pop, secs)


## Whether it has a drawing of its own for view [param v] (front, side, back).
func has_view(v: String) -> bool:
	return _has_view(v)


## A blink of [param secs] (the eye verb's, which an eye's body answers too).
func blink(_secs := BLINK) -> void:
	_blink_t = 0.0


## A point of bone [param bone] ([param at] along it from its head to its tail, 0-1) where the stage draws it, through
## [param placed] (its node's transform under the stage).
func point_of(bone: String, at := 1.0) -> Vector2:
	if node == null or not is_instance_valid(node) or not _cel.bones.has(bone):
		return node.position if node != null and is_instance_valid(node) else Vector2.ZERO
	var b := _cel.rig.bone(bone)
	var p := _v2(b["head"]).lerp(_v2(b["tail"]), at)
	var xf := _skel_xf(bone) * Transform2D(0.0, -_v2(b["head"]))
	return node.transform * _squash.transform * Transform2D(0.0, -_cel.rig.anchor()) * xf * p


## Its top (the head's tail, else its highest row) where the stage draws it.
func top_point() -> Vector2:
	if _cel.bones.has("head"):
		return point_of("head", 1.0)
	var a := _cel.rig.anchor()
	return node.transform * _squash.transform * Transform2D(0.0, -a) * Vector2(a.x, float(_cel.rig.data.get("top", 0.0)))


func _skel_xf(bone: String) -> Transform2D:
	var xf := Transform2D.IDENTITY
	var n := bone
	while not n.is_empty() and _cel.bones.has(n):
		xf = (_cel.bones[n] as Bone2D).transform * xf
		n = String(_cel.rig.bone(n).get("parent", ""))
	return xf


# --- each frame -----------------------------------------------------------------------------------------------------------

## Its life advanced [param dt], its place [param pos] (world) read for its gait.
func step(dt: float, pos: Vector3) -> void:
	if _last == Vector3.INF:
		_last = pos
	var move := Vector2(pos.x - _last.x, pos.z - _last.z)
	_last = pos
	var inst := move.length() / maxf(1e-4, dt) / height
	_speed = lerpf(_speed, inst, 1.0 - exp(-dt / 0.12))
	if absf(move.x) > 1e-5:
		_heading = lerpf(_heading, signf(move.x), 1.0 - exp(-dt / 0.1))
	_left += dt
	while _left >= STEP * 0.5:
		var h := minf(STEP, _left)
		_advance(h)
		_left -= h


func _advance(dt: float) -> void:
	_t += dt
	_mouth_t += dt
	if _action_left > 0.0:
		_action_left -= dt
		if _action_left <= 0.0:
			action = ""
	var g: Dictionary = GAITS.get(gait if not gait.is_empty() else "walk", GAITS["walk"])
	var going := clampf(_speed / maxf(0.05, float(g["pace"]) * 0.35), 0.0, 1.0) if not gait == "slide" else 0.0
	if gait == "float" or spooky > 0.0:
		going = maxf(going, 0.0)
	_phase += dt * float(g["steps"]) * clampf(0.6 + 0.4 * _speed / maxf(0.05, float(g["pace"])), 0.5, 1.8) * (1.0 if going > 0.02 else 0.0)
	var cyc := sin(_phase * TAU)
	var targets := {}
	for n in _order:
		var r := String(_role[n])
		targets[n] = float(pose.get(n, 0.0)) * (_bend if r in ["arm", "hand", "leg"] else 1.0)
	# breath and sway
	var breath := sin(_t * TAU * 0.33 + float(_ph[0]))
	var sway := sin(_t * TAU * 0.21 + float(_ph[1])) * (1.0 - going)
	# the gait: legs against each other, arms against the legs
	for n in _order:
		var role := String(_role[n])
		var sd := 1.0 if String(_side[n]) == "left" else -1.0
		match role:
			"leg":
				targets[n] = float(targets[n]) + going * float(g["leg"]) * cyc * sd * _bend
			"arm":
				targets[n] = float(targets[n]) - going * float(g["arm"]) * cyc * sd * _bend + 1.5 * breath * sd
			"hand":
				targets[n] = float(targets[n]) + going * float(g["arm"]) * 0.4 * cos(_phase * TAU) * sd * _bend
			"loose":
				targets[n] = float(targets[n]) + 7.0 * sin(_t * TAU * 0.8 + float(_ph[2]) + _order.find(n)) * (0.35 + going) \
					- _heading * facing * going * 10.0
			"head":
				targets[n] = float(targets[n]) + 2.0 * sin(_t * TAU * 0.27 + float(_ph[3])) + _talk * 3.5 * sin(_t * TAU * 1.9 + float(_ph[4]))
	# talking: syllables in words, a word's pause between
	_talk = lerpf(_talk, talking, 1.0 - exp(-dt / 0.08))
	var syl := maxf(0.0, sin(_t * TAU * 4.6 + float(_ph[5])))
	var shape := 0.55 + 0.45 * sin(_t * TAU * 1.13 + float(_ph[6]))
	var words := smoothstep(-0.75, -0.35, sin(_t * TAU * 0.41 + float(_ph[7])))
	_jaw = lerpf(_jaw, _talk * syl * shape * words, 1.0 - exp(-dt / 0.035))
	# the springs
	for n in _order:
		var role := String(_role[n])
		var s: Array = SPRING.get(role, SPRING[""])
		var w := float(s[0]) * (snap if role in ["arm", "hand", "prop"] else 1.0)
		var z := float(s[1])
		var a := float(_angle[n])
		var v := float(_vel[n])
		var tgt := float(targets[n])
		if role == "jaw":
			tgt = _jaw * float((_cel.rig.data.get("mouth", {}) as Dictionary).get("open", 16.0)) if _cel.rig.data.get("mouth") is Dictionary and not _cel.talks else 0.0
		v += (w * w * (tgt - a) - 2.0 * z * w * v) * dt
		a += v * dt
		_angle[n] = a
		_vel[n] = v
	# its whole: squash, recoil, spin, lean, eyes
	var sq_tgt := squash_hold * (1.0 + 0.012 * breath)
	_sq_v += (18.0 * 18.0 * (sq_tgt - _sq) - 2.0 * 0.32 * 18.0 * _sq_v) * dt
	_sq = clampf(_sq + _sq_v * dt, 0.45, 1.8)
	_recoil_v += (-7.0 * 7.0 * _recoil - 2.0 * 0.55 * 7.0 * _recoil_v) * dt
	_recoil += _recoil_v * dt
	_spin_v += (-6.5 * 6.5 * _spin - 2.0 * 0.3 * 6.5 * _spin_v) * dt
	_spin += _spin_v * dt
	_lean = lerpf(_lean, _heading * going * float(g["lean"]), 1.0 - exp(-dt / 0.2))
	_eye_pop = maxf(0.0, _eye_pop - dt)
	var eye_tgt := 1.0 + (0.35 if _eye_pop > 0.0 else 0.0)
	_eye_v += (16.0 * 16.0 * (eye_tgt - _eye) - 2.0 * 0.35 * 16.0 * _eye_v) * dt
	_eye = clampf(_eye + _eye_v * dt, 0.6, 2.2)
	_float = lerpf(_float, maxf(spooky, 1.0 if gait == "float" and going > 0.02 else 0.0), 1.0 - exp(-dt / 0.4))
	# blinks
	if _blink_t >= 0.0:
		_blink_t += dt
		if _blink_t > BLINK:
			_blink_t = -1.0
	else:
		_next_blink -= dt
		if _next_blink <= 0.0:
			_blink_t = 0.0
			_next_blink = _rng.randf_range(BLINK_EVERY[0], BLINK_EVERY[1])
	_flip = move_toward(_flip, facing, dt / 0.09)


## Its node put where the stage draws it: [param placed] (its feet's place and scale under the stage, the stage's view in it).
func show_at(placed: Transform2D) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.visible = shown
	var h := rig.height()
	var g: Dictionary = GAITS.get(gait if not gait.is_empty() else "walk", GAITS["walk"])
	var going := clampf(_speed / maxf(0.05, float(g["pace"]) * 0.35), 0.0, 1.0)
	var bob := absf(sin(_phase * TAU)) * float(g["bob"]) * h * going
	var hover := _float * (0.1 + 0.04 * sin(_t * TAU * 0.5 + float(_ph[0]))) * h
	var roll := sin(_phase * TAU) * float(g["roll"]) * going + sin(_t * TAU * 0.21 + float(_ph[1])) * 1.2 * (1.0 - going)
	var shake := Vector2.ZERO
	var shake_r := 0.0
	if tremble > 0.0:
		shake = Vector2(sin(_t * 97.0 + float(_ph[2])), sin(_t * 113.0 + float(_ph[3]))) * tremble * 0.012 * h
		shake_r = sin(_t * 89.0) * tremble * 2.0
	_choose(going)
	var flip := _flip if absf(_flip) > 0.08 else 0.08 * signf(_flip if _flip != 0.0 else 1.0)
	if _cel.view == "front" and _cels.size() > 1:
		flip = 1.0                       # a drawing facing us is never mirrored: turning is another drawing
	node.transform = placed * Transform2D(0.0, Vector2(flip, 1.0), 0.0, Vector2.ZERO)
	var sy := _sq
	var sx := 1.0 / sqrt(maxf(0.2, _sq))
	_squash.transform = Transform2D(deg_to_rad(roll + _lean * facing * flip + _spin + shake_r), Vector2(sx, sy), 0.0,
		Vector2(_recoil.x * facing * signf(flip), _recoil.y - bob - hover - lift * h) + shake)
	var mouth: Dictionary = _cel.rig.data.get("mouth", {}) if _cel.rig.data.get("mouth") is Dictionary else {}
	for n in _cel.order:
		var bone: Bone2D = _cel.bones[n]
		var role := String(_role[n])
		var off: Vector2 = _cel.rest[n]
		var sc := Vector2.ONE
		if role == "jaw":
			off += Vector2(0.0, float(mouth.get("drop", 0.0)) * clampf(_jaw, 0.0, 1.2))
		elif role == "eye":
			sc = Vector2(_eye, _eye)
		bone.transform = Transform2D(deg_to_rad(float(_angle[n])), sc, 0.0, off)
	var close := 0.0
	if _blink_t >= 0.0:
		close = sin(PI * clampf(_blink_t / BLINK, 0.0, 1.0))
	for lid in _cel.lids:
		(lid as Lid).set_close(close)


## The drawing shown now: the view (its profile while it goes across at [param going], else the one it holds), the mouth its
## syllables call for (held at least [constant MOUTH_HOLD]), its mood - a swap snapping a little squash.
func _choose(going: float) -> void:
	if _cels.size() < 2 or _cel == null:
		return
	var want_view := "side" if going > 0.35 and _has_view("side") else view
	var want_mouth := "closed" if _jaw < 0.18 else ("open" if _jaw < 0.55 else "wide")
	if want_mouth != _mouth and _mouth_t >= MOUTH_HOLD:
		_mouth = want_mouth
		_mouth_t = 0.0
	# a drawn walk: the profile and its stride swapped at every step
	var doing := action if not action.is_empty() else posed
	if doing.is_empty() and want_view == "side" and going > 0.35 and _cels.has("stride") and sin(_phase * TAU * 2.0) > 0.0:
		doing = "stride"
	var key := PuppetSheet.pick(_cels, want_view, _mouth, mood, doing)
	if key.is_empty() or key == _cel.key:
		return
	var was := _cel
	_cel = _built(_cels[key])
	if was.root != null:
		was.root.visible = false
	_cel.root.visible = true
	if was.view != _cel.view:
		kick(-0.25)


func _has_view(v: String) -> bool:
	for c in _cels.values():
		if (c as Cel).view == v:
			return true
	return false


## One drawing of the puppet: its rig, built as a node of its own - its skeleton, its layers weighted to it, its lids.
class Cel extends RefCounted:
	var key := ""
	var view := "front"
	var rig: PuppetRig = null
	var root: Node2D = null
	var skel: Skeleton2D = null
	var bones := {}                  # name -> Bone2D
	var rest := {}                   # name -> rest offset from its parent (rig px)
	var order: Array = []
	var lids: Array = []
	## Whether its talking is drawings of its own (the sheet has its mouths), so its jaw stays shut.
	var talks := false

	func build() -> void:
		bones = {}
		lids = []
		root = Node2D.new()
		root.name = "Rig_" + key
		root.position = -rig.anchor()
		skel = Skeleton2D.new()
		skel.name = "Skeleton"
		root.add_child(skel)
		var paths := {}
		for n in order:
			var bone := Bone2D.new()
			bone.name = String(n)
			bone.set_autocalculate_length_and_angle(false)
			bone.set_length(8.0)
			var xf := Transform2D(0.0, rest[n])
			bone.rest = xf
			bone.transform = xf
			var parent := String(rig.bone(String(n)).get("parent", ""))
			if parent.is_empty():
				skel.add_child(bone)
				paths[n] = NodePath(String(n))
			else:
				(bones[parent] as Bone2D).add_child(bone)
				paths[n] = NodePath(String(paths[parent]) + "/" + String(n))
			bones[n] = bone
		# each layer's mesh and weights as the rig's reading packed them ([member PuppetRig.meshes])
		for layer in rig.data.get("layers", []):
			var ln := String((layer as Dictionary)["name"])
			var mesh: Dictionary = rig.meshes[ln]
			var poly := Polygon2D.new()
			poly.name = ln
			poly.polygon = mesh["points"]
			poly.uv = mesh["points"]
			poly.polygons = mesh["polygons"]
			poly.texture = rig.texture(ln)
			root.add_child(poly)
			poly.skeleton = poly.get_path_to(skel)
			for bw in mesh["bones"]:
				poly.add_bone(paths[order[int(bw[0])]], bw[1])
		for e in rig.data.get("eyes", []):
			var ed: Dictionary = e
			var bone: Bone2D = bones.get(String(ed.get("bone", "")))
			if bone == null:
				continue
			var lid := Lid.new()
			lid.radius = PuppetBody._v2(ed["radius"])
			lid.color = Color(String(ed.get("lid", "#808080")))
			bone.add_child(lid)
			lids.append(lid)


## A lid over an eye: the skin round it drawn down over the eye as far as it is closed, its edge inked.
class Lid extends Node2D:
	var radius := Vector2(10, 10)
	var color := Color.GRAY
	var _close := 0.0

	func set_close(c: float) -> void:
		if not is_equal_approx(c, _close):
			_close = c
			queue_redraw()

	func _draw() -> void:
		if _close <= 0.02:
			return
		var rx := radius.x * 1.08
		var ry := radius.y * 1.08
		var edge := -ry + 2.0 * ry * _close
		# the eye's outline above the lid's edge (round from its left, over its top, to its right and back), then the edge inked
		var poly := PackedVector2Array()
		for i in 49:
			var a := -PI + TAU * float(i) / 48.0
			var p := Vector2(cos(a) * rx, sin(a) * ry)
			if p.y <= edge:
				poly.append(p)
		if poly.size() >= 3:
			draw_colored_polygon(poly, color)
			var w := sqrt(maxf(0.0, 1.0 - (edge / ry) * (edge / ry))) * rx
			var curve := PackedVector2Array()
			for i in 13:
				var x := -w + 2.0 * w * float(i) / 12.0
				curve.append(Vector2(x, edge + 0.06 * ry * (1.0 - pow(x / maxf(1.0, w), 2.0))))
			draw_polyline(curve, Color(0.08, 0.1, 0.06), maxf(2.0, rx * 0.09), true)
