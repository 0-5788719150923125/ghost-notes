extends RefCounted
class_name Actions

## Actions - the verb registry for data-driven scenes (see scenes/stage.gd).
##
## The registry sibling of [Primitives] / [Layer] / [Shots], for choreography: each verb is a small class
## applied to named actors over a time window by a [Track] span, called with data.
##
## Lifecycle: `begin(stage, actors)` once when the window is entered, `apply(stage, actors, k, f, dt)` every
## frame with the eased window fraction k (a point span gets a single k=1 apply), `finish(stage, actors)`
## once when it closes. Most verbs latch on finish (a specialized prism stays specialized); undoing is
## another span.
##
## Verbs receive their args raw (ranges intact) plus a seeded rng: values meant to be fixed per instance are
## sampled in begin() ("cattle, not pets"); per-event values (a gaze fixation's distance) are re-drawn as
## they happen. Same seed, same show.

const REGISTRY := {
	"look": Look, "blink": Blink, "arrive": Arrive, "sprout": Sprout, "split": Split,
	"crystallize": Crystallize, "tremble": Tremble, "burst": Burst, "lock": Lock,
	"desync": Desync, "hold_still": HoldStill, "sway": Sway, "counterflow": Counterflow,
	"specialize": Specialize, "form": Form, "leave": Leave,
	"gather": Gather, "fly": Fly, "helix_split": HelixSplit, "lane_jump": LaneJump,
	"set": SetParam, "ramp": Ramp, "pulse": Pulse, "flash": Flash,
}

## What `set` and `ramp` can move on an actor: the ones every kind has, then the eye's own.
const PARAM_NAMES := ["scale", "fade", "hue", "time_scale", "drive", "tremble", "dilate", "lid", "iris"]
## The shapes `form` makes ([method Form.slots]).
const FORM_SHAPES := ["tetra", "ring", "line"]
## From the world (y up) to a prism's own frame (y down), and back: the same matrix.
const FLIP := Basis(Vector3(1, 0, 0), Vector3(0, -1, 0), Vector3(0, 0, 1))

## What each verb can be told, as data: its `args` in a storyboard's span, the rows an editor builds for it
## ([SchemaForm]), beside the ones every span has ([constant Storyboard.SPAN]). A `num` takes a number or a
## sampled `[lo, hi]` range; a default of null is the verb's own draw. A verb with no row takes no args.
const ARGS := {
	"look": {
		"tiers": {"label": "Depths", "type": "data", "default": null,
			"blurb": "Where the gaze rests, as a list of tiers: each a chance `p`, a distance `dist` and how long it dwells there, `dwell`."},
		"lateral": {"label": "Sideways", "type": "num", "default": null,
			"blurb": "How far a fixation strays to the side."},
		"stray": {"label": "Stray", "type": "num", "default": 0.0,
			"blurb": "The chance that one eye wanders off the shared focus for a fixation."},
	},
	"blink": {
		"duration": {"label": "Seconds", "type": "num", "default": 0.32, "blurb": "How long the lids take to close and open again."},
	},
	"arrive": {
		"from": {"label": "From", "type": "vec3", "default": null,
			"blurb": "Where it flies in from. Unset, from off the frame."},
		"wobble": {"label": "Swing", "type": "num", "default": null,
			"blurb": "How far past its place it swings as it lands. Unset, as far as the speed it came in with carries it."},
		"upright": {"label": "Rights in", "type": "num", "default": 3.0,
			"blurb": "Seconds it takes, once landed, to turn gently from the way it flew in to upright, while whatever comes next goes on. 0 keeps it pointing the way it came."},
	},
	"sprout": {
		"side": {"label": "Side", "type": "num", "default": null,
			"blurb": "Which side of its place the stem grows on: -1 left, 1 right. Unset, by the seed."},
	},
	"split": {
		"into": {"label": "Into", "type": "actor", "default": null,
			"blurb": "The hidden actor that becomes the newborn."},
		"hue": {"label": "Its hue", "type": "num", "default": null,
			"blurb": "The color the newborn warms to as it pulls away. Unset, its parent's."},
		"slots": {"label": "Places", "type": "data", "default": null,
			"blurb": "Where the two come to rest, as two places: `[[x, y, z], [x, y, z]]`."},
	},
	"crystallize": {
		"into": {"label": "Into", "type": "actor", "default": null,
			"blurb": "The hidden prism the eye freezes over into."},
	},
	"burst": {
		"replaces": {"label": "Replaces", "type": "actor", "default": null,
			"blurb": "An actor that goes as this one bursts into being."},
	},
	"lock": {
		"to": {"label": "To", "type": "actor", "default": null, "blurb": "The prism whose turning it locks onto."},
		"snap": {"label": "Snap", "type": "num", "default": 0.05,
			"blurb": "How quickly it snaps into step, as a share of the window."},
	},
	"sway": {
		"amp": {"label": "Reach", "type": "num", "default": null,
			"blurb": "How far it drifts from its place. Unset, a little, by the seed."},
	},
	"counterflow": {
		"lane": {"label": "Lane", "type": "num", "default": null, "blurb": "How far apart the two highways run."},
		"speed": {"label": "Speed", "type": "num", "default": null, "blurb": "How fast they cruise."},
		"loop_k": {"label": "Loop at", "type": "num", "default": null,
			"blurb": "How far through the window each pulls its closing loop, from 0 to 1."},
	},
	"specialize": {
		"size": {"label": "Size", "type": "num", "default": 1.0, "blurb": "How many times its size it grows or shrinks to."},
		"tempo": {"label": "Tempo", "type": "num", "default": 1.0, "blurb": "How many times its own speed it runs at."},
		"pulse": {"label": "Pulse", "type": "data", "default": null,
			"blurb": "A breathing of its size it keeps afterward: `{\"amp\": 0.06, \"rate\": 6.5}`."},
	},
	"form": {
		"shape": {"label": "Shape", "type": "enum", "options": FORM_SHAPES, "default": "tetra",
			"blurb": "What they make: a tetrahedron (its corners, then its edge midpoints, finer as more join, never a member where it has no node), a ring, or a line abreast. The first actor named takes the first place."},
		"size": {"label": "Size", "type": "num", "default": 1.2, "blurb": "How far apart its outermost places are, corner to corner."},
		"fit": {"label": "Fit", "type": "bool", "default": true,
			"blurb": "Size the members to their spacing, so their corners meet and together they read as one large shape."},
		"center": {"label": "Center", "type": "vec3", "default": null,
			"blurb": "Where the shape stands. Unset, where its members are now, on average."},
		"tilt": {"label": "Lean", "type": "num", "default": 18.0,
			"blurb": "How far it leans back from the camera, in degrees, so its depth shows."},
		"turn": {"label": "Turns", "type": "num", "default": 5.0,
			"blurb": "How fast the whole turns about its upright once formed, in turns a minute."},
		"stagger": {"label": "Stagger", "type": "num", "default": 0.1,
			"blurb": "How much later each member sets off than the one before, as a share of the window."},
	},
	"leave": {
		"to": {"label": "Toward", "type": "vec3", "default": null,
			"blurb": "Which way it goes, right, up and toward the camera. Toward the camera it grows and leaves the frame's edge, never coming near the lens; away it shrinks and fades out. Unset, away from the others on the stage, by the seed."},
		"force": {"label": "Force", "type": "num", "default": 0.5,
			"blurb": "How hard it goes, from 0 to 1: low winds up slowly and eases away, high snaps back and throws, rolling fast and shedding shards."},
	},
	"fly": {
		"speed": {"label": "Speed", "type": "num", "default": 1.0, "blurb": "How fast the swarm flies its track."},
		"follow": {"label": "Camera", "type": "num", "default": 0.72,
			"blurb": "How closely the camera keeps up: 1 holds the swarm still in frame, less lets it pull away."},
	},
	"set": {
		"param": {"label": "What", "type": "enum", "options": PARAM_NAMES, "default": "scale", "blurb": "What is set."},
		"value": {"label": "To", "type": "num", "default": 0.0, "blurb": "Its new value, at once."},
	},
	"ramp": {
		"param": {"label": "What", "type": "enum", "options": PARAM_NAMES, "default": "scale", "blurb": "What is eased."},
		"from": {"label": "From", "type": "num", "default": null, "blurb": "Where it starts. Unset, from where it is."},
		"to": {"label": "To", "type": "num", "default": 0.0, "blurb": "Where it ends up, across the window."},
	},
	"pulse": {
		"amp": {"label": "Depth", "type": "num", "default": 0.1, "blurb": "How much its size breathes."},
		"rate": {"label": "Rate", "type": "num", "default": 1.2, "blurb": "How many breaths a second."},
		"latch": {"label": "Keeps on", "type": "bool", "default": true,
			"blurb": "The breathing carries on after the window closes."},
	},
	"flash": {
		"hue": {"label": "Hue", "type": "num", "default": null, "blurb": "The flash's color. Unset, the actor's own."},
	},
}


## A prism's orientation, as its body's frame ([member PrismBody.rot] is its euler), with its apex pointing along
## [param dir] in the world, turned [param roll] about that way.
static func pointing(dir: Vector3, roll := 0.0) -> Quaternion:
	var d := dir.normalized() if dir.length() > 1e-5 else Vector3.UP
	var align := Quaternion(Vector3.RIGHT, PI) if d.dot(Vector3.UP) < -0.9999 else Quaternion(Vector3.UP, d)
	return Quaternion(FLIP * (Basis(align) * Basis(Vector3.UP, roll)) * FLIP)


## A prism's heading for travelling along [param dir] in the world: its apex where it is drawn along the way. A prism
## is drawn at 0.8 of its height ([constant Form.SQUASH]), so the heading leans that much further up or down.
static func travelling(dir: Vector3, roll := 0.0) -> Quaternion:
	return pointing(dir / Form.SQUASH, roll)


## The world direction [param pb]'s apex points along.
static func apex_of(pb: PrismBody) -> Vector3:
	return FLIP * (Basis.from_euler(pb.rot) * (FLIP * Vector3.UP))


## What the stage holds every actor to each frame, after the bodies have advanced: its place in a formation
## ([method Form.hold]) and a righting under way ([method right]).
static func hold(a, dt: float) -> void:
	Form.hold(a, dt)
	_hold_upright(a, dt)


## A slow righting latched on [param a], a prism: from where it points now to upright over [param secs] seconds,
## eased in and out, by the least turn, then a second more in which its own slow turning eases back in before the
## stage lets it go. It lives in `state.upright`, so it carries across a cut and a clone takes a copy; a verb that
## sets the prism's pose itself takes over ([method let_go]).
static func right(a, secs: float) -> void:
	if not (a.body is PrismBody) or secs <= 0.0:
		return
	var from := Quaternion(Basis.from_euler((a.body as PrismBody).rot))
	var apex := apex_of(a.body as PrismBody)
	var arc := Quaternion(Vector3.RIGHT, PI) if apex.dot(Vector3.UP) < -0.9999 else Quaternion(apex, Vector3.UP)
	a.state["upright"] = {"from": from, "to": Quaternion(FLIP * Basis(arc) * FLIP) * from, "secs": secs, "t": 0.0,
		"own": Quaternion()}


## A righting given up: what a verb that sets the prism's pose itself calls first.
static func let_go(a) -> void:
	a.state.erase("upright")


## The seconds after upright in which a righted prism's own turning eases back in.
const OWN_TURN_S := 1.0


static func _hold_upright(a, dt: float) -> void:
	var up: Variant = a.state.get("upright")
	if not (up is Dictionary) or not (a.body is PrismBody):
		return
	var d: Dictionary = up
	var pb := a.body as PrismBody
	var secs := maxf(0.01, float(d["secs"]))
	d["t"] = float(d["t"]) + dt
	var t := float(d["t"])
	# its own turning, at the body's own rate, eased in once it is upright
	var own := smoothstep(secs, secs + OWN_TURN_S, t)
	d["own"] = (d["own"] as Quaternion) * Quaternion.from_euler(pb._vel * dt * (0.4 + 0.7 * pb._energy) * own)
	var q: Quaternion = (d["from"] as Quaternion).slerp(d["to"], smoothstep(0.0, 1.0, minf(t / secs, 1.0))) * (d["own"] as Quaternion)
	pb.rot = Basis(q).get_euler()
	if t >= secs + OWN_TURN_S:
		a.state.erase("upright")


## [param to] made a clone of [param from]: the same shell, core, pose and clock, so the two move as one until
## something sets them apart.
static func clone_body(from: PrismBody, to: PrismBody) -> void:
	to.rot = from.rot
	to._vel = from._vel
	to._disp = from._disp
	to._dvel = from._dvel
	to._max_len = from._max_len
	to._dens_lo = from._dens_lo
	to._dens_hi = from._dens_hi
	to.hue_shift = from.hue_shift
	to._energy = from._energy
	to._breath = from._breath
	to._t = from._t
	to._tendrils = from._tendrils.duplicate(true)
	to._rng.seed = from._rng.seed
	to._rng.state = from._rng.state


static func make(key: String, args: Dictionary, rng: RandomNumberGenerator) -> Action:
	if not REGISTRY.has(key):
		push_warning("ghost: unknown action '%s' (have: %s)" % [key, ", ".join(REGISTRY.keys())])
		return null
	var a: Action = REGISTRY[key].new()
	a.args = args
	a.rng = rng
	return a


class Action extends RefCounted:
	var args := {}
	var rng: RandomNumberGenerator

	func begin(_stage, _actors: Array) -> void:
		pass

	func apply(_stage, _actors: Array, _k: float, _f: AudioFeatures, _dt: float) -> void:
		pass

	func finish(_stage, _actors: Array) -> void:
		pass

	# Sample an arg once (a [lo, hi] range collapses to one draw). Call from begin() and store: repeated
	# calls re-roll.
	func num(key: String, fallback: float) -> float:
		if not args.has(key):
			return fallback
		return float(Storyboard.sample(args[key], rng))


## look - aim eyes at a wandering 3D focus point. All targets share one focus, so two eyes verge (toe in
## near, run parallel far); a rare stray sends one eye wandering. The depth-tier table comes from the args
## (see [Cast.FocusSampler]).
class Look extends Action:
	var _sampler: Cast.FocusSampler

	func begin(_stage, _actors: Array) -> void:
		_sampler = Cast.FocusSampler.new(args, rng)

	func apply(_stage, actors: Array, _k: float, _f: AudioFeatures, dt: float) -> void:
		_sampler.advance(dt, actors.size())
		for i in actors.size():
			var a = actors[i]
			a.state["focus"] = _sampler.focus
			a.state["focus_age"] = 0.0
			if _sampler.stray_of == i:
				a.state["div"] = _sampler.stray_off
			else:
				a.state.erase("div")


## blink - close and reopen the eyelids once. args: duration (s).
class Blink extends Action:
	func apply(_stage, actors: Array, _k: float, _f: AudioFeatures, _dt: float) -> void:
		var dur := num("duration", 0.32)
		for a in actors:
			if a.body is EyeBody:
				(a.body as EyeBody).blink(dur)


## arrive - the actor flies in from off the frame, fast, and lands on its place like a rubber band coming home: past
## it, back, settling in a few quick swings. A prism flies apex first along its way and still points that way as it
## lands; at the end it latches a slow righting ([method Actions.right]) that turns it upright over the next seconds
## while whatever follows goes on - in its last moments too, since a window that ends on its entry's cut never
## finishes. Give the span `ease: linear`: the verb shapes its own motion. args: from ([x,y,z]
## origin, default a sampled point off the frame), wobble (how far past its place it swings; default as far as its
## speed carries it), upright (the righting's seconds; 0 keeps it pointing the way it came).
class Arrive extends Action:
	## The share of the window spent flying in; the rest is the landing's swings.
	const APPROACH := 0.5
	var _origin := Vector3.ZERO
	var _slot := Vector3.ZERO
	var _flight := Vector3.RIGHT
	var _side := Vector3.UP
	var _arc := 0.2
	var _swing := 0.1
	var _freq := 12.0
	var _roll := 0.0
	var _roll_rate := 2.0
	var _righted := false             # the righting latched

	func begin(_stage, actors: Array) -> void:
		var a = actors[0]
		_slot = a.pos
		if args.has("from"):
			_origin = Cast._vec3(args["from"], a.home)
		else:
			# a sampled origin past the frame's edge, biased upward so the entrance swoops down
			var ang := rng.randf_range(0.25, 0.85) * (1.0 if rng.randf() < 0.5 else -1.0)
			var dir2 := Vector2(sin(ang), absf(cos(ang)) * 0.6 + 0.2).normalized()
			_origin = _slot + Vector3(dir2.x, dir2.y, 0.0) * rng.randf_range(2.6, 3.4)
		_arc = rng.randf_range(0.10, 0.22) * (1.0 if rng.randf() < 0.5 else -1.0)
		_flight = (_slot - _origin).normalized()
		_side = Vector3(-_flight.y, _flight.x, 0.0)
		_freq = TAU * rng.randf_range(1.8, 2.3)
		# the swing continues the approach: it hits its place still moving at 0.7 of the speed it set out with
		var hit := 0.7 * _origin.distance_to(_slot) * (1.0 - APPROACH) / APPROACH
		_swing = num("wobble", hit / _freq)
		_roll_rate = rng.randf_range(1.5, 3.0) * (1.0 if rng.randf() < 0.5 else -1.0)
		Actions.let_go(a)
		a.fade = 1.0

	func apply(_stage, actors: Array, k: float, _f: AudioFeatures, dt: float) -> void:
		var a = actors[0]
		var landed := 0.0                 # the drill roll slows to a stop as it lands
		if k < APPROACH:
			var p := k / APPROACH
			a.pos = _origin.lerp(_slot, p * (1.3 - 0.3 * p)) + _side * (_arc * sin(PI * p))
		else:
			var tau := (k - APPROACH) / (1.0 - APPROACH)
			a.pos = _slot + _flight * (_swing * exp(-4.5 * tau) * sin(_freq * tau))
			landed = smoothstep(0.0, 0.6, tau)
		a.home = _slot
		if a.body is PrismBody and not _righted:
			_roll += _roll_rate * dt * (1.0 - landed)
			(a.body as PrismBody).rot = Basis(Actions.travelling(_flight, _roll)).get_euler()
		if k >= 0.98:
			_right(a)

	func finish(_stage, actors: Array) -> void:
		var a = actors[0]
		a.pos = _slot
		a.home = _slot
		_right(a)

	func _right(a) -> void:
		if _righted:
			return
		_righted = true
		if a.body is PrismBody:
			(a.body as PrismBody).rot = Basis(Actions.travelling(_flight, _roll)).get_euler()
		Actions.right(a, num("upright", 3.0))


## sprout - a standing rose beside the anchor: the stem grows up from below the frame (rooted in the void's
## floor, never from the camera), rises almost vertical beside the eye's anchor, crests above it and droops
## its head so the tip hangs downward; the eye swells at the tip like fruit, facing the ground. The bloom
## sheds a petal or two; then the eye detaches, which whips the freed stem back as it retreats down along
## itself while the dropped eye settles onto its anchor and rights itself to face forward. The vine and
## petals are drawn by [Cast.EyeActor] from `state.vine`. Give the span `ease: linear`. args: side (-1/1
## stem side, default sampled).
class Sprout extends Action:
	var _slot := Vector3.ZERO
	var _R := 0.34
	var _base := Vector3.ZERO         # the stem's root, beyond the frame's lower side corner
	var _grow_k := 0.42               # phase boundaries + character, sampled per instance
	var _fruit_k := 0.62
	var _drop_k := 0.74
	var _hang := Vector3.ZERO         # where the eye's center hangs (a touch above the slot)
	var _sag := 0.05                  # how far the fruit's weight bends the tip down
	var _sway_f := 1.6
	var _whip_f := 15.0
	var _whip_a := 0.16
	var _seed := 0
	var _hue := 0.3
	var _petals: Array = []           # {spawn: k, at: Vector3, ph, size} - shed as it wilts
	var _detached := false
	var _t := 0.0

	func begin(_stage, actors: Array) -> void:
		var a = actors[0]
		_slot = a.pos
		_R = a.scale
		var side := signf(num("side", -1.0 if rng.randf() < 0.5 else 1.0))
		_base = _slot + Vector3(side * rng.randf_range(0.34, 0.52), rng.randf_range(-1.25, -1.05), 0.0)
		_grow_k = rng.randf_range(0.38, 0.46)
		_fruit_k = _grow_k + rng.randf_range(0.16, 0.22)
		_drop_k = _fruit_k + rng.randf_range(0.09, 0.14)
		_hang = _slot + Vector3(0, rng.randf_range(0.08, 0.14), 0)
		_sag = rng.randf_range(0.04, 0.07)
		_sway_f = rng.randf_range(1.2, 2.0)
		_whip_f = rng.randf_range(12.0, 18.0)
		_whip_a = rng.randf_range(0.12, 0.20)
		_seed = rng.randi()
		_hue = rng.randf_range(0.24, 0.36)          # deep plant green, sampled
	# The shed petals: one or two, let go while the bloom hangs (before the drop).
		for i in rng.randi_range(1, 2):
			_petals.append({"spawn": rng.randf_range(_fruit_k + 0.02, _drop_k + 0.03),
				"ph": rng.randf() * TAU, "size": rng.randf_range(0.030, 0.045), "at": Vector3.ZERO})
		a.fade = 0.0
		if a.body is EyeBody:
			(a.body as EyeBody).droop = 1.1

	func apply(stage, actors: Array, k: float, _f: AudioFeatures, dt: float) -> void:
		var a = actors[0]
		_t += dt
		var kg := clampf(k / _grow_k, 0.0, 1.0)                                 # growth
		var kf := clampf((k - _grow_k) / (_fruit_k - _grow_k), 0.0, 1.0)        # fruiting
		var kd := clampf((k - _drop_k) / maxf(0.05, 1.0 - _drop_k), 0.0, 1.0)   # drop + retreat
		# The fruit's weight bends the hanging tip lower; a light pendulum sway.
		var sag := _sag * smoothstep(0.0, 1.0, kf)
		var sway := 0.022 * sin(_t * TAU * _sway_f) * kf * (1.0 - kd)
		var tip := _hang + Vector3(sway, _R * 1.02 - sag, 0.0)
	# The standing rose: a near-vertical rise beside the anchor, cresting above it, the head drooping
	# onto the hanging tip.
		var c1 := Vector3(_base.x * 1.08, lerpf(_base.y, tip.y, 0.72), 0.0)
		var c2 := Vector3(tip.x, tip.y + 0.5, 0.0)
		var grown := 1.0 - pow(1.0 - kg, 2.6)               # quick, decelerating growth
		if not _detached and k >= _drop_k:
			_detached = true
			stage.spatter(tip, 3, rng, Color.from_hsv(_hue, 0.4, 0.55))
		if _detached:
			# Freed of the weight, the vine WHIPS back and retreats along itself.
			var wob := exp(-4.0 * kd * 3.0) * sin(_whip_f * kd * 3.0)
			c2 += Vector3(-signf(_base.x - _slot.x) * _whip_a * wob, _whip_a * 0.7 * absf(wob), 0.0)
			c1.x += _whip_a * 0.4 * wob * signf(_base.x - _slot.x)
			grown = 1.0 - smoothstep(0.0, 1.0, minf(kd * 1.6, 1.0))
		# The shed petals flutter down from wherever the tip was when they let go.
		var pets: Array = []
		for p in _petals:
			var sp := float(p.spawn)
			if k < sp:
				continue
			if (p.at as Vector3) == Vector3.ZERO:
				p.at = tip
			var fall := clampf((k - sp) / 0.34, 0.0, 1.0)
			if fall >= 1.0:
				continue
			var ph := float(p.ph)
			pets.append({
				"p": (p.at as Vector3) + Vector3(sin(fall * 7.0 + ph) * 0.07 * (1.0 - 0.4 * fall),
					-pow(fall, 1.6) * 0.55, 0.0),
				"ang": ph + fall * 5.0, "size": float(p.size),
				"a": 1.0 - smoothstep(0.55, 1.0, fall)})
		a.state["vine"] = {"base": _base, "c1": c1, "c2": c2, "tip": tip,
			"g": grown, "seed": _seed, "hue": _hue, "r": _R, "petals": pets}
		# The eye: swells at the hanging tip, drops free, settles, rights itself.
		if k < _drop_k:
			a.fade = smoothstep(0.0, 1.0, minf(kf * 1.6, 1.0))
			a.scale = _R * pow(maxf(kf, 0.0001), 0.45)      # fruit swell
			a.pos = tip - Vector3(0, a.scale * 1.02, 0.0)   # hanging from the tip
			if a.body is EyeBody:
				(a.body as EyeBody).droop = 1.1
		else:
			a.scale = _R
			var fall := 1.0 - exp(-5.0 * kd) * cos(13.0 * kd)   # small drop, damped bounce
			a.pos = Vector3(_slot.x, lerpf(_hang.y - sag, _slot.y, fall), _slot.z)
			if a.body is EyeBody:
				(a.body as EyeBody).droop = 1.1 * (1.0 - smoothstep(0.0, 1.0, kd))
		a.home = _slot
		# The verb owns the gaze: neutral under the droop while it hangs and wakes.
		a.state["focus"] = a.pos + Vector3(0, 0, 9.0)
		a.state["focus_age"] = 0.0

	func finish(_stage, actors: Array) -> void:
		var a = actors[0]
		a.state.erase("vine")
		a.pos = _slot
		a.home = _slot
		a.scale = _R
		a.fade = 1.0
		if a.body is EyeBody:
			(a.body as EyeBody).droop = 0.0


## split - mitosis: one eye divides into two. The twin buds off the source as a blank wet ball (no iris
## yet), connected by a stretching tissue membrane (drawn by [Cast.EyeActor] from `state.mit`); volume is
## conserved, so the parent deflates as the bud swells (one R eye -> two ~0.79R twins). The pull is
## stick-slip up to the SNAP, where the membrane tears: both eyes recoil on a damped spring to their slots,
## droplets spatter, and then the newborn's iris surfaces, followed by its first blink.
##
## A prism divides by CLONING: the twin is the same size, shape and pose, in its own hue from the first frame,
## sharing the parent's every move until the bond between them tears; then it turns away on its own. Timed in
## seconds, so any window reads alike: a moment in place as the twin condenses over its parent, a quick pull to the
## bond's limit, a tug-of-war there that takes up the rest
## of the window (back and forth, the strands taut and quivering), the tear (shards, a flash), and a spring settle
## into each place. args: into (actor id), slots ([[x,y,z],[x,y,z]]), hue (the newborn's; default the parent's).
class Split extends Action:
	var _from_pos := Vector3.ZERO
	var _R := 0.3                     # the parent's whole volume, as a radius
	var _slots: Array = []
	var _tense_k := 0.30              # phase boundaries + dynamics, sampled per instance
	var _snap_k := 0.75
	var _pre_frac := 0.55             # separation reached at the snap (the membrane holds the rest)
	var _rec_freq := 22.0
	var _rec_damp := 6.0
	var _drops := 4
	var _seed := 0
	var _snapped := false
	var _hue0 := 0.6                  # the newborn's hue at the bud, and at the snap
	var _hue1 := 0.6
	var _tr0 := 0.0                   # a tremble already on the parent, which the strain carries on from
	# a prism's division (the clone): its pull timed in seconds
	const LEAD_S := 0.3               # in place, the twin condensing over its parent
	const RAMP_S := 0.45              # the pull to the bond's limit
	const SETTLE_S := 0.6             # the spring into place after the tear
	var _clone := false
	var _clock := 0.0                 # seconds since it began
	var _span := -1.0                 # the window's seconds, read off its progress
	var _limit := 0.72                # the share of the way apart the bond holds them at
	var _tug_f := Vector2(1.6, 2.8)   # the tug-of-war's two rates, Hz
	var _tug_ph := Vector2.ZERO
	var _last_sep := 0.0
	var _snap_at := 0.0               # seconds in when it tore
	var _at_snap := 0.72

	func begin(stage, actors: Array) -> void:
		var src = actors[0]
		var into = stage.actor(String(args.get("into", "")))
		_clone = src.body is PrismBody and into != null and into.body is PrismBody
		if _clone:
			_begin_clone(src, into)
			return
		_from_pos = src.pos
		_tr0 = float(src.state.get("tremble", 0.0))
		_hue0 = src.hue
		_hue1 = num("hue", src.hue)
		_R = src.scale
		_slots = args.get("slots", [])
		_tense_k = rng.randf_range(0.26, 0.36)
		_snap_k = rng.randf_range(0.70, 0.80)
	# The membrane must stretch on screen: separation at the snap must well exceed the sum of the two
	# radii (~0.48 of the slot distance), or the bridge stays hidden inside the spheres and tears unseen.
		_pre_frac = rng.randf_range(0.78, 0.88)
		_rec_freq = rng.randf_range(17.0, 26.0)
		_rec_damp = rng.randf_range(5.0, 7.5)
		_drops = rng.randi_range(3, 6)
		_seed = rng.randi()
		if into != null:
			into.hue = src.hue
			if into.body is EyeBody and src.body is EyeBody:
				(into.body as EyeBody).hue = (src.body as EyeBody).hue
				(into.body as EyeBody).gaze = (src.body as EyeBody).gaze
				(into.body as EyeBody).target = (src.body as EyeBody).target
				(into.body as EyeBody).iris_fade = 0.0    # born featureless
			into.pos = src.pos
			into.scale = 0.0
			into.fade = 0.0

	func apply(stage, actors: Array, k: float, _f: AudioFeatures, _dt: float) -> void:
		if _clone:
			_apply_clone(stage, actors, k, _dt)
			return
		var src = actors[0]
		var into = stage.actor(String(args.get("into", "")))
		if into == null or _slots.size() < 2:
			return
		var s0: Vector3 = Cast._vec3(_slots[0], src.home)
		var s1: Vector3 = Cast._vec3(_slots[1], into.home)
		var kt := clampf(k / _tense_k, 0.0, 1.0)                              # tension builds
		var kp := clampf((k - _tense_k) / (_snap_k - _tense_k), 0.0, 1.0)     # the pull
		var ks := clampf((k - _snap_k) / maxf(0.05, 1.0 - _snap_k), 0.0, 1.0) # snap + settle
		# Volume conservation: the bud inflates to half the parent's volume by the snap.
		var v := 0.5 * pow(clampf(k / _snap_k, 0.0, 1.0), 1.3)
		src.scale = _R * pow(1.0 - v, 1.0 / 3.0)
		into.scale = _R * pow(maxf(v, 0.0001), 1.0 / 3.0)
	# Separation: a stick-slip creep to _pre_frac, then the snap's damped spring carries the rest with
	# an overshoot recoil.
		var sep: float
		if k < _snap_k:
			var jerk := pow(absf(sin(kp * 37.0 + float(_seed % 7)) * sin(kp * 53.0 + 1.7)), 3.0)
			sep = _pre_frac * (pow(kp, 1.15) + 0.06 * jerk * kp)
		else:
			var spring := 1.0 - exp(-_rec_damp * ks) * cos(_rec_freq * ks)
			sep = _pre_frac + (1.0 - _pre_frac) * spring
		# The parent LEANS toward the bud while the tissue drags on it, then recoils.
		var lean := 0.05 * kp * (1.0 - kp) * 4.0 * (1.0 if k < _snap_k else 0.0)
		var toward := (s1 - s0).normalized()
		src.pos = _from_pos.lerp(s0, sep) + toward * (lean * _R)
		into.pos = _from_pos.lerp(s1, sep)
		into.pos.z += 0.02 * (1.0 - ks)          # a hair closer, so the bud draws over its parent
		src.home = src.pos
		into.home = into.pos
		into.fade = smoothstep(0.0, 1.0, clampf(k / (_tense_k * 0.8), 0.0, 1.0))
		# A newborn of another hue takes it on through the pull, the short way round the wheel.
		var dh := wrapf(_hue1 - _hue0, -0.5, 0.5)
		into.hue = fposmod(_hue0 + dh * smoothstep(0.0, 1.0, clampf(k / _snap_k, 0.0, 1.0)), 1.0)
		# Strain: the tremble channel gives the jiggle AND gathers light around the eye.
		if k < _snap_k:
			src.state["tremble"] = clampf(maxf(_tr0, 0.30 * kt) + 0.35 * kp, 0.0, 0.6)
		else:
			src.state["tremble"] = maxf(0.0, 0.45 * (1.0 - ks * 3.0))
	# The division owns the gaze: the parent stares dead ahead under the strain (one thing happening),
	# and the newborn holds the same stare once it tears free. The next entry's look verb takes over
	# when this stops feeding (focus_age expiry).
		src.state["focus"] = src.pos + Vector3(0, 0, 9.0)
		src.state["focus_age"] = 0.0
		if _snapped:
			into.state["focus"] = into.pos + Vector3(0, 0, 9.0)
			into.state["focus_age"] = 0.0
		# The membrane, for the actor's draw pass. `waist` starves through the pull.
		src.state["mit"] = {"to": String(args.get("into", "")), "seed": _seed,
			"waist": 1.0 - kp, "snap": -1.0 if not _snapped else float(src.state["mit"].get("snap", -1.0)) + _dt}
		if k >= _snap_k and not _snapped:
			_snapped = true
			src.state["mit"]["snap"] = 0.0
			var at := _from_pos.lerp(s0.lerp(s1, 0.5), sep)
			if into.body is PrismBody:
				# a crystal tears clean: shards in both colors and a flash on the newborn
				stage.spatter(at, _drops, rng, Color.from_hsv(_hue0, 0.35, 1.0))
				stage.spatter(at, _drops, rng, Color.from_hsv(_hue1, 0.35, 1.0))
				stage.flash(into, Color.from_hsv(_hue1, 0.45, 1.0))
			else:
				stage.spatter(at, _drops, rng)
		# The aftermath: the newborn's iris surfaces once it has torn free.
		if _snapped and into.body is EyeBody:
			(into.body as EyeBody).iris_fade = smoothstep(0.0, 1.0, clampf((ks - 0.25) / 0.6, 0.0, 1.0))

	func finish(stage, actors: Array) -> void:
		var src = actors[0]
		var into = stage.actor(String(args.get("into", "")))
		src.state.erase("mit")
		src.state.erase("tremble")
		if _clone:
			if into != null:
				into.state.erase("tremble")
				into.fade = 1.0
				into.hue = _hue1
			if _slots.size() >= 2:
				src.pos = Cast._vec3(_slots[0], src.home)
				src.home = src.pos
				if into != null:
					into.pos = Cast._vec3(_slots[1], into.home)
					into.home = into.pos
			return
		if _slots.size() >= 2:
			src.pos = Cast._vec3(_slots[0], src.home)
			src.home = src.pos
		var half := _R * pow(0.5, 1.0 / 3.0)
		src.scale = half
		if into != null:
			if _slots.size() >= 2:
				into.pos = Cast._vec3(_slots[1], into.home)
				into.home = into.pos
			into.scale = half
			into.fade = 1.0
			into.hue = _hue1
			if into.body is EyeBody:
				(into.body as EyeBody).iris_fade = 1.0


	func _begin_clone(src, into) -> void:
		_slots = args.get("slots", [])
		_hue0 = src.hue
		_hue1 = num("hue", src.hue)
		_limit = rng.randf_range(0.68, 0.76)
		_tug_f = Vector2(rng.randf_range(1.4, 1.9), rng.randf_range(2.5, 3.2))
		_tug_ph = Vector2(rng.randf() * TAU, rng.randf() * TAU)
		_drops = rng.randi_range(3, 6)
		_seed = rng.randi()
		_tr0 = float(src.state.get("tremble", 0.0))
		_from_pos = src.pos
		into.pos = src.pos
		into.home = src.home
		into.scale = src.scale
		into.hue = _hue1
		into.fade = 0.0
		into.time_scale = src.time_scale
		into.drive_gain = src.drive_gain
		into._t = src._t
		Actions.clone_body(src.body as PrismBody, into.body as PrismBody)
		Actions.let_go(into)
		if src.state.get("upright") is Dictionary:
			into.state["upright"] = (src.state["upright"] as Dictionary).duplicate(true)   # the pair right as one

	func _apply_clone(stage, actors: Array, k: float, dt: float) -> void:
		var src = actors[0]
		var into = stage.actor(String(args.get("into", "")))
		if into == null or _slots.size() < 2:
			return
		_clock += dt
		if k > 0.02:
			_span = _clock / k
		var span := maxf(_span, 0.6) if _span > 0.0 else 4.0
		var lead := minf(LEAD_S, span * 0.12)
		var ramp := minf(RAMP_S, span * 0.25)
		var snap_t := span - minf(SETTLE_S, span * 0.35)
		var t := _clock
		var s0: Vector3 = Cast._vec3(_slots[0], src.home)
		var s1: Vector3 = Cast._vec3(_slots[1], into.home)
		if not _snapped and t >= snap_t:
			_snapped = true
			_snap_at = t
			_at_snap = _last_sep
			var at := _from_pos.lerp(s0.lerp(s1, 0.5), _last_sep)
			stage.spatter(at, _drops, rng, Color.from_hsv(_hue0, 0.35, 1.0))
			stage.spatter(at, _drops, rng, Color.from_hsv(_hue1, 0.35, 1.0))
			stage.flash(into, Color.from_hsv(_hue1, 0.45, 1.0))
			# free of the bond, the twin turns away on its own
			Actions.let_go(into)
			var pb := into.body as PrismBody
			pb._vel = Vector3(rng.randf_range(0.18, 0.42), rng.randf_range(0.28, 0.55), rng.randf_range(0.08, 0.22)) \
				* (-1.0 if rng.randf() < 0.5 else 1.0)
			pb._rng.seed = rng.randi()
		var sep: float
		var waist := 1.0
		var tug := 0.0
		var tr: float
		if not _snapped:
			if t < lead:
				sep = 0.0
				tr = _tr0
			elif t < lead + ramp:
				# the quick pull: fast apart, slowing into the bond's limit
				var p := (t - lead) / maxf(0.01, ramp)
				sep = _limit * (1.0 - pow(1.0 - p, 3.0))
				waist = 1.0 - 0.7 * p
				tr = maxf(_tr0, 0.3 * p)
			else:
				# the tug-of-war at the limit: back and forth, harder toward the tear, a last pull before it
				var tt := t - lead - ramp
				var q := clampf(tt / maxf(0.05, snap_t - lead - ramp), 0.0, 1.0)
				var osc := 0.6 * sin(TAU * _tug_f.x * tt + _tug_ph.x) + 0.4 * sin(TAU * _tug_f.y * tt + _tug_ph.y)
				var amp := lerpf(0.05, 0.11, q) * smoothstep(0.0, 0.3, tt)
				var pull := amp * osc + 0.05 * smoothstep(0.75, 1.0, q)
				sep = _limit + pull
				tug = q
				waist = clampf(0.3 - 0.12 * q - 0.8 * pull, 0.05, 1.0)
				tr = maxf(_tr0, 0.3 + 0.35 * q)
			_last_sep = sep
			(into.body as PrismBody).lock_pose_to(src.body as PrismBody)
		else:
			# the tear: the bond's pull let go flings each toward its place, past it and back
			var ts := t - _snap_at
			sep = 1.0 - (1.0 - _at_snap) * exp(-6.5 * ts) * (cos(15.0 * ts) - 0.5 * sin(15.0 * ts))
			tr = maxf(0.0, 0.45 * (1.0 - ts * 3.0))
		src.pos = _from_pos.lerp(s0, sep)
		into.pos = _from_pos.lerp(s1, sep)
		into.pos.z += 0.004 * (1.0 - smoothstep(0.0, 0.2, sep))     # a hair nearer while they overlap: the twin draws on top
		src.home = src.pos
		into.home = into.pos
		into.fade = smoothstep(0.0, maxf(0.05, lead), t)
		src.state["tremble"] = tr
		into.state["tremble"] = tr
		src.state["mit"] = {"to": String(args.get("into", "")), "seed": _seed, "waist": waist, "tug": tug,
			"snap": -1.0 if not _snapped else t - _snap_at}


## crystallize - the eye freezes over into the prism (a staged physical transition, not a crossfade). Phase
## 1, stilling: the gaze locks to one point and crystal edges creep across the ball ([Cast.EyeActor] draws
## the cage from `state.crys`) while the pupil constricts and the iris hue chills toward the crystal's.
## Phase 2, faceting: the cage tightens and glints, the iris features die away, and the prism's wireframe
## materializes aligned over it. Phase 3, collapse: the ball is sucked into the crystal's core (cold shards,
## an icy flash) and the prism solidifies alive. Give the span `ease: linear`. args: into (actor id).
class Crystallize extends Action:
	var _facet_k := 0.4               # phase boundaries + character, sampled per instance
	var _fall_k := 0.8
	var _seed := 0
	var _stare := Vector3.ZERO
	var _base_scale := 0.27
	var _base_hue := 0.3
	var _flashed := false

	func begin(stage, actors: Array) -> void:
		var src = actors[0]
		_facet_k = rng.randf_range(0.34, 0.44)
		_fall_k = rng.randf_range(0.76, 0.84)
		_seed = rng.randi()
		_base_scale = src.scale
	# The stare it dies with: one fixed world point, sampled once (the first sign of the freeze is that
	# the eye stops moving).
		_stare = src.pos + Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(-0.25, 0.25), 7.0)
		if src.body is EyeBody:
			_base_hue = (src.body as EyeBody).hue
		var into = stage.actor(String(args.get("into", "")))
		if into != null:
			into.fade = 0.0

	func apply(stage, actors: Array, k: float, _f: AudioFeatures, _dt: float) -> void:
		var src = actors[0]
		var into = stage.actor(String(args.get("into", "")))
		if into == null:
			return
		var kf := clampf((k - _facet_k) / maxf(0.05, _fall_k - _facet_k), 0.0, 1.0)  # faceting
		var kc := clampf((k - _fall_k) / maxf(0.05, 1.0 - _fall_k), 0.0, 1.0)        # collapse
		var chill := clampf(into.hue, 0.0, 1.0)
		# Stilling: the locked stare, the dying pupil, the chilling iris.
		src.state["focus"] = _stare
		src.state["focus_age"] = 0.0
		if src.body is EyeBody:
			var eye := src.body as EyeBody
			eye.dilate_bias = -0.30 * smoothstep(0.0, 1.0, minf(k / _facet_k, 1.0))
			eye.hue = lerpf(_base_hue, chill, smoothstep(0.0, 1.0, k))
			eye.iris_fade = 1.0 - smoothstep(0.0, 1.0, kf)         # features die in phase 2
		# The cage, drawn by the actor: growth through phases 1-2, gone with the ball.
		src.state["crys"] = {"k": k, "facet": kf, "seed": _seed, "hue": chill}
		# Collapse: the ball is sucked into the crystal's core; the prism solidifies.
		src.scale = _base_scale * (1.0 - smoothstep(0.0, 1.0, kc))
		src.fade = 1.0 if kc < 1.0 else 0.0
		into.fade = smoothstep(0.0, 1.0, kf * 0.55 + kc * 0.45)
		into.drive_gain = 0.25 + 0.75 * (kf * 0.4 + kc * 0.6)
		if not _flashed and kc > 0.0:
			_flashed = true
			var icy := Color.from_hsv(chill, 0.35, 1.0)
			stage.flash(into, icy)
			stage.spatter(src.pos, rng.randi_range(4, 7), rng, icy)

	func finish(stage, actors: Array) -> void:
		var src = actors[0]
		src.fade = 0.0
		src.scale = _base_scale
		src.state.erase("crys")
		if src.body is EyeBody:
			(src.body as EyeBody).iris_fade = 1.0
			(src.body as EyeBody).dilate_bias = 0.0
		var into = stage.actor(String(args.get("into", "")))
		if into != null:
			into.fade = 1.0
			into.drive_gain = 1.0


## tremble - the riser: the eye vibrates harder as k rises, light building around it (drawn in
## [Cast.EyeActor]). Latches at its final level; the burst that replaces the eye ends it.
class Tremble extends Action:
	func apply(_stage, actors: Array, k: float, f: AudioFeatures, _dt: float) -> void:
		var drive := clampf(f.energy * 0.85 + f.beat * 0.6, 0.0, 1.0)
		for a in actors:
			a.state["tremble"] = clampf(k * (0.55 + 0.6 * drive), 0.0, 1.0)


## burst - the target bursts into being in a flash (the drop): revealed at full fade, optionally replacing
## another actor (the eye it erupts from). Usually a point span gated on a beat:
## `{at: 0, on: beat, by: 0.8, action: burst, ...}`.
class Burst extends Action:
	func apply(stage, actors: Array, _k: float, _f: AudioFeatures, _dt: float) -> void:
		for a in actors:
			a.fade = 1.0
			stage.flash(a, Color(1.0, 0.5, 0.4))
		var rep = stage.actor(String(args.get("replaces", "")))
		if rep != null:
			rep.fade = 0.0
			rep.state.erase("tremble")


## lock - phase-lock the target's pose to another prism (they turn as one), with a brief bright tie between
## them at the snap. Latches until a desync. args: to (actor id), snap (window fraction where the snap
## lands, default 0.05).
class Lock extends Action:
	var _snapped := false
	var _snap_k := 0.05

	func begin(_stage, _actors: Array) -> void:
		_snap_k = num("snap", 0.05)

	func apply(stage, actors: Array, k: float, _f: AudioFeatures, _dt: float) -> void:
		if k < _snap_k and not _snapped:
			return
		for a in actors:
			if not _snapped:
				var to = stage.actor(String(args.get("to", "")))
				if to != null:
					stage.tie(a, to)
			a.state["lock_to"] = String(args.get("to", ""))
			Actions.let_go(a)
		_snapped = true


## desync - break a phase-lock: the target resumes its own rotation.
class Desync extends Action:
	func apply(_stage, actors: Array, _k: float, _f: AudioFeatures, _dt: float) -> void:
		for a in actors:
			a.state.erase("lock_to")


## hold_still - damp the target's own spin toward rest (it keeps breathing). Latches.
class HoldStill extends Action:
	func apply(_stage, actors: Array, k: float, _f: AudioFeatures, _dt: float) -> void:
		for a in actors:
			a.state["still"] = k


## sway - slip the anchor and drift weightlessly around it, pushing and pulling. Each target wanders on its
## own seeded phases; the audio leans into it. args: amp (world units, default [0.07, 0.10], sampled per
## target).
class Sway extends Action:
	var _t := 0.0
	var _ph: Array = []               # per-target {px, py, fx, fy, amp}

	func begin(_stage, actors: Array) -> void:
		for i in actors.size():
			_ph.append({"px": rng.randf() * TAU, "py": rng.randf() * TAU,
				"fx": rng.randf_range(0.55, 0.95), "fy": rng.randf_range(0.6, 1.0),
				"amp": num("amp", rng.randf_range(0.07, 0.10))})

	func apply(_stage, actors: Array, k: float, f: AudioFeatures, dt: float) -> void:
		_t += dt
		var drive := clampf(f.energy * 0.85 + f.beat * 0.6, 0.0, 1.0)
		var follow := 1.0 - exp(-3.0 * dt)
		for i in actors.size():
			var a = actors[i]
			var p: Dictionary = _ph[i]
			var w := Vector2(sin(_t * float(p.fx) + float(p.px)), cos(_t * float(p.fy) + float(p.py))) \
				* (float(p.amp) * k * (0.5 + drive))
			a.pos = a.pos.lerp(a.home + Vector3(w.x, w.y, 0.0), follow)


## counterflow - the pair take opposite highways: each merges onto its own lane and cruises against the
## other (they pass mid-scene), rolling about its travel axis like a drill; in the final stretch each pulls
## a loop off its lane, the arc that carries them into the ouroboros. Cruise speed rides the actor's live
## time_scale, so a specialized small/fast prism zips while the large/slow one glides. Give the span
## `ease: linear`. args: lane (half-gap between the highways), speed (world/s), loop_k (where the exit loop
## begins, 0..1).
class Counterflow extends Action:
	var _lane := 0.18
	var _speed := 0.35
	var _loop_k := 0.7
	var _loop_r := 0.3
	var _roll := 2.8
	var _from: Array = []
	var _dir: Array = []              # +1 / -1 travel direction per target
	var _trav: Array = []             # accumulated cruise distance per target
	var _loop_at: Array = []          # position where each target left its lane

	func begin(_stage, actors: Array) -> void:
		_lane = num("lane", rng.randf_range(0.14, 0.22))
		_speed = num("speed", rng.randf_range(0.28, 0.40))
		_loop_k = num("loop_k", rng.randf_range(0.66, 0.74))
		_loop_r = rng.randf_range(0.19, 0.26)
		_roll = rng.randf_range(2.2, 3.4)
		for i in actors.size():
			var a = actors[i]
			_from.append(a.pos)
			_trav.append(0.0)
			_loop_at.append(Vector3.ZERO)
			# Travel TOWARD the other side of the frame, so the two pass each other.
			_dir.append(-signf(a.pos.x) if absf(a.pos.x) > 0.01 else (1.0 if i == 0 else -1.0))

	func apply(_stage, actors: Array, k: float, _f: AudioFeatures, dt: float) -> void:
	# The current: the pair start adrift and the flow builds slowly, easing them onto their lanes and
	# up to cruise.
		var current := smoothstep(0.0, 0.38, k)
		for i in actors.size():
			var a = actors[i]
			var d := float(_dir[i])
			var up := 1.0 if i == 0 else -1.0          # which side its lane and loop live on
			var lane_y := _lane * up
			var merge := smoothstep(0.0, 0.42, k)
			if k < _loop_k:
				_trav[i] = float(_trav[i]) + dt * _speed * current * (0.4 + 0.6 * a.time_scale)
				var p := Vector3(float((_from[i] as Vector3).x) + d * float(_trav[i]),
					lerpf(float((_from[i] as Vector3).y), lane_y, merge), 0.0)
				a.pos = p
				_loop_at[i] = p
			else:
	# The exit loop: a circular arc off the lane, curling up (blue) or down (red), drawn by the
	# same current into a spiral that sinks toward the center-depth, so the cut into the
	# ouroboros catches both converging on the point the swarm then blossoms out of.
				var kl := smoothstep(0.0, 1.0, (k - _loop_k) / maxf(0.05, 1.0 - _loop_k))
				var c := (_loop_at[i] as Vector3) + Vector3(0, up * _loop_r, 0)
				var ph := kl * 3.7                     # ~210 degrees of the circle
				var sink := smoothstep(0.45, 1.0, kl)
				var on_loop := c + Vector3(sin(ph) * d, -cos(ph) * up, 0.0) * _loop_r
				a.pos = on_loop.lerp(Vector3(0.0, 0.0, -0.85), sink * 0.8)
			a.home = a.pos
	# Roll about the travel axis, opposite for the two directions. Builds with the current, eases
	# off in the loop.
			if a.body is PrismBody:
				var want := Vector3(d * _roll * current * (0.4 + 0.6 * a.time_scale), 0.12 * d, 0.0)
				if k >= _loop_k:
					want *= 0.4
				var pb := a.body as PrismBody
				pb._vel = pb._vel.lerp(want, 1.0 - exp(-3.0 * dt))


## specialize - diverge in character: scale eases to size x, the body's whole tempo to `tempo` x, and a
## scale pulse latches ({amp, rate}). args: size (default 1.0), tempo (default 1.0), pulse {amp, rate}.
class Specialize extends Action:
	var _base: Array = []
	var _size := 1.0
	var _tempo := 1.0

	func begin(_stage, actors: Array) -> void:
		_size = num("size", 1.0)
		_tempo = num("tempo", 1.0)
		for a in actors:
			_base.append(a.scale)

	func apply(_stage, actors: Array, k: float, _f: AudioFeatures, _dt: float) -> void:
		var pulse: Dictionary = args.get("pulse", {}) if typeof(args.get("pulse")) == TYPE_DICTIONARY else {}
		for i in actors.size():
			var a = actors[i]
			a.scale = lerpf(float(_base[i]), float(_base[i]) * _size, k)
			a.time_scale = lerpf(1.0, _tempo, k)
			if not pulse.is_empty():
				a.state["pulse"] = {"amp": float(pulse.get("amp", 0.1)) * k,
					"rate": float(pulse.get("rate", 1.2))}


## form - the targets fly to the places of a shape and turn to one heading as they go, like a squadron: each member
## points the way the whole shape points. A tetrahedron's places are the centers of the upward small tetrahedra of
## one subdivided as finely as its members need ([method lattice]: four, its corners; ten, its corners and edge
## midpoints; twenty, its edge thirds and face centers), so members sized to their spacing (`fit`) meet corner to
## corner and read as one large tetrahedron, with no member where the shape has no node. A ring's places are round
## its rim, a line's abreast. Once formed the shape turns about its upright as one rigid body. It latches: the
## formation lives in each member's `state.form` and the stage holds it there every frame ([method hold]), across a
## cut too, until a `leave` takes a member out. A `form` over members already in one carries it on from where it
## stands, so the same shape and size continue without a jump while the turning eases to the new rate. args: shape,
## size, fit, center, tilt (degrees), turn (turns a minute), stagger.
class Form extends Action:
	## A prism is drawn with its height squashed to 0.8 ([method PrismBody._project]); the shape's places are too, so
	## members meet where they are drawn.
	const SQUASH := Vector3(1.0, 0.8, 1.0)
	## A prism's base edge, in its own size: what `fit` sizes a member by.
	const EDGE := 1.15
	## The share of the window spent gathering; the rest is the formed shape turning up to speed.
	const GATHER := 0.75

	var _turn := 0.0                  # rad/s, reached across the window
	var _rate0 := 0.0                 # the rate it starts from (a formation carried on keeps its own)
	var _starts: Array = []           # each member's start, as a share of the window
	var _docked: Array = []           # each member home yet (one carried on is from the start)

	## The places of [param n] members on a tetrahedron whose corners are a prism's own, its base edge 1, about its
	## center: the centers of the upward small tetrahedra of it subdivided L to an edge, L the least whose count
	## (L(L+1)(L+2)/6) holds [param n] - corners first, then the points along its edges, its faces, its inside.
	## `{points, spacing}`, spacing the distance between neighbors.
	static func lattice(n: int) -> Dictionary:
		var level := 1
		while level * (level + 1) * (level + 2) / 6 < n:
			level += 1
		var corners: Array = []
		for v in PrismBody.VERTS:
			corners.append(Actions.FLIP * (v as Vector3) - Vector3(0.0, -0.25, 0.0))
		var steps := level - 1
		var found: Array = []
		for i in range(steps, -1, -1):
			for j in range(steps - i, -1, -1):
				for k in range(steps - i - j, -1, -1):
					var l := steps - i - j - k
					var w := [i, j, k, l]
					var p := Vector3.ZERO
					if steps > 0:
						for c in 4:
							p += (corners[c] as Vector3) * (float(w[c]) / float(steps))
					found.append({"p": p, "rank": maxi(1, w.filter(func(x: int) -> bool: return x > 0).size())})   # one alone is a corner
		var points: Array = []
		for rank in range(1, 5):
			for f in found:
				if int(f["rank"]) == rank and points.size() < n:
					points.append(f["p"])
		return {"points": points, "spacing": 1.0 / float(maxi(1, steps))}

	## The places of [param shape] for [param n] members, [param size] apart at their outermost, about the shape's
	## center in its own frame (y up).
	static func slots(shape: String, n: int, size: float) -> Array:
		var out: Array = []
		match shape:
			"ring":
				for i in n:
					var a := TAU * float(i) / float(maxi(1, n))
					out.append(Vector3(sin(a), 0.0, cos(a)) * (size * 0.5))
			"line":
				for i in n:
					var x := 0.0 if n < 2 else (float(i) / float(n - 1) - 0.5)
					out.append(Vector3(x * size, 0.0, 0.0))
			_:
				for p in lattice(n)["points"]:
					out.append((p as Vector3) * size)
		return out

	## The distance between neighboring places: what a member fitted to the shape measures along its edge.
	static func spacing(shape: String, n: int, size: float) -> float:
		match shape:
			"ring":
				return size * sin(PI / float(n)) if n > 1 else size
			"line":
				return size / float(n - 1) if n > 1 else size
		return size * float(lattice(n)["spacing"])

	## The shape's own frame in the world: turned [param angle] about its upright, then leaned back [param tilt].
	static func frame(tilt: float, angle: float) -> Basis:
		return Basis(Vector3.RIGHT, -tilt) * Basis(Vector3.UP, angle)

	## Where the formation in [param fm] places its member at [param angle]: its offset turned with the shape and
	## squashed as a prism is drawn.
	static func place(fm: Dictionary, angle: float) -> Vector3:
		return (fm["center"] as Vector3) + SQUASH * (frame(float(fm["tilt"]), angle) * (fm["offset"] as Vector3))

	## Where the formation in [param fm] holds its member now: on the way from where it set off, or at its place.
	static func held_pos(fm: Dictionary) -> Vector3:
		var e := float(fm["e"])
		return (fm["from"] as Vector3).lerp(place(fm, float(fm["angle"])), e) + (fm["side"] as Vector3) * sin(PI * e)

	## A member of a formation put where it holds it, turned to its heading and, while it gathers, grown or shrunk
	## to its fitted size; the shape's turning advanced by [param dt]. What the stage calls for every actor each
	## frame, after the bodies have advanced.
	static func hold(a, dt: float) -> void:
		var fm: Variant = a.state.get("form")
		if not (fm is Dictionary):
			return
		var d: Dictionary = fm
		d["angle"] = float(d["angle"]) + float(d["rate"]) * dt
		var e := float(d["e"])
		a.pos = held_pos(d)
		a.home = a.pos
		if e < 1.0:
			a.scale = lerpf(float(d["scale_from"]), float(d["scale_to"]), e)
		elif not bool(d.get("sized", false)):
			a.scale = float(d["scale_to"])     # once: a later verb may change its size
			d["sized"] = true
		if a.body is PrismBody:
			var heading := Quaternion(Actions.FLIP * frame(float(d["tilt"]), float(d["angle"])) * Actions.FLIP)
			var q: Quaternion = heading if e >= 1.0 else (d["from_q"] as Quaternion).slerp(heading, e)
			(a.body as PrismBody).rot = Basis(q).get_euler()

	func begin(_stage, actors: Array) -> void:
		var n := actors.size()
		if n == 0:
			return
		var shape := String(args.get("shape", "tetra"))
		var size := num("size", 1.2)
		var places := slots(shape, n, size)
		var fitted := spacing(shape, n, size) / EDGE
		var fit := bool(args.get("fit", true))
		var tilt := deg_to_rad(num("tilt", 18.0))
		_turn = num("turn", 5.0) * TAU / 60.0
		var stagger := num("stagger", 0.1)
		var center := Vector3.ZERO
		for a in actors:
			center += a.pos
		center /= float(n)
		if args.get("center") != null:
			center = Storyboard.sample_vec3(args["center"], rng, center)
		# a formation carried on keeps its angle and rate, so the turning never jumps
		var angle := 0.0
		for a in actors:
			if a.state.get("form") is Dictionary:
				angle = float(a.state["form"]["angle"])
				_rate0 = float(a.state["form"]["rate"])
				break
		for i in n:
			var a = actors[i]
			var from: Vector3 = held_pos(a.state["form"]) if a.state.get("form") is Dictionary else a.pos
			var from_q := Quaternion(Basis.from_euler((a.body as PrismBody).rot)) if a.body is PrismBody else Quaternion()
			var fm := {"center": center, "offset": places[i], "tilt": tilt, "angle": angle, "rate": _rate0,
				"e": 0.0, "from": from, "from_q": from_q, "side": Vector3.ZERO,
				"scale_from": a.scale, "scale_to": fitted if fit else a.scale}
			var d := place(fm, angle) - from
			var settled: bool = a.state.get("form") is Dictionary and d.length() < 0.01
			fm["e"] = 1.0 if settled else 0.0
			fm["side"] = Vector3(-d.y, d.x, 0.0) * rng.randf_range(-0.22, 0.22)
			a.state.erase("lock_to")
			Actions.let_go(a)
			a.state["form"] = fm
			_docked.append(settled)
			_starts.append(minf(float(i) * stagger, GATHER - 0.3))

	func apply(stage, actors: Array, k: float, _f: AudioFeatures, _dt: float) -> void:
		var rate := lerpf(_rate0, _turn, smoothstep(0.15, 0.85, k))
		var travel := maxf(0.3, GATHER - float(_starts.max() if not _starts.is_empty() else 0.0))   # each the same, so they lock in one by one
		for i in actors.size():
			var a = actors[i]
			var fm: Variant = a.state.get("form")
			if not (fm is Dictionary):
				continue                # it left
			var s := float(_starts[i]) if i < _starts.size() else 0.0
			var e := smoothstep(0.0, 1.0, clampf((k - s) / travel, 0.0, 1.0))
			if i < _docked.size() and bool(_docked[i]):
				e = 1.0
			elif e >= 1.0 and i < _docked.size():
				_docked[i] = true
				stage.flash(a, Color.from_hsv(fposmod(a.hue, 1.0), 0.45, 1.0))    # home: a glint as it locks in
			fm["e"] = e
			fm["rate"] = rate

	func finish(_stage, actors: Array) -> void:
		for a in actors:
			if a.state.get("form") is Dictionary:
				a.state["form"]["e"] = 1.0
				a.state["form"]["rate"] = _turn


## leave - the reverse of arrive: a brief wind-up (it draws back a little, turning its apex the way it will go),
## then a launch that gathers speed until it is gone, out of any formation it was in; a prism flies apex first,
## rolling about its way, its apex along the exact way it goes, in depth too (a way straight into the distance is
## seen end-on). The way may run in depth. Toward the camera it grows as it comes, on a path that leaves the
## frame while still farther than [constant NEAREST] from the lens (one that would come nearer first is turned
## sideways until it does not), and ends at the frame's edge. Away from the camera it shrinks into the distance and
## fades out over the end of its window, gone by then whether or not it reached an edge. Hidden once its whole body is
## past the frame's edge. Give the span `ease: linear`: the verb shapes its own motion. args: to (the way it goes,
## right, up and toward the camera; unset, away from the others on the stage), force (0 winds up slowly and eases
## away, 1 snaps back and throws, rolling fast and shedding shards as it goes).
class Leave extends Action:
	## The nearest a leaving actor may be to the lens while it can be seen, in world units.
	const NEAREST := 1.5
	## How far into the distance a way that never reaches an edge runs, at the least and at full force.
	const DEPTH_RUN := Vector2(8.0, 12.0)
	## The share of the window over which a way into the distance fades out.
	const FADE_TAIL := 0.3
	var _from: Array = []
	var _to: Array = []
	var _dir: Array = []
	var _from_q: Array = []
	var _back: Array = []             # how far each draws back, as a share of its way
	var _tail: Array = []             # each fades over the window's end (a way into the distance)
	var _fade0: Array = []
	var _out: Array = []              # each gone past the frame's edge
	var _force := 0.5
	var _wind := 0.2                  # the share of the window the wind-up takes
	var _power := 2.0                 # how the launch gathers speed
	var _roll := 0.0
	var _roll_rate := 3.0
	var _launched := false
	var _lens: Lens3D = null
	var _half := Vector2(0.9, 0.5)

	## How [param a] would leave along [param dir]: `out`, the first distance at which its whole body is past the
	## frame's edge (-1 for none within reach), and `near`, whether it would come nearer the lens than
	## [constant NEAREST] before then.
	func _exit(a, dir: Vector3) -> Dictionary:
		var d := 0.25
		while d < 12.0:
			var pj := _lens.project(a.pos + dir * d)
			if pj.z < NEAREST:
				return {"out": -1.0, "near": true}
			var r: float = a.scale * _lens._focal / maxf(0.1, pj.z) * 1.2
			if absf(pj.x) - r > _half.x or absf(pj.y) - r > _half.y:
				return {"out": d, "near": false}
			d += 0.1
		return {"out": -1.0, "near": false}

	## [param dir], a way in the world, in the camera's axes (right, up, toward it), which a prism is drawn in.
	func _in_view(dir: Vector3) -> Vector3:
		return Vector3(dir.dot(_lens._r), dir.dot(_lens._u), -dir.dot(_lens._f))

	## Whether [param a]'s whole body is past the frame's edge, or too near the lens to be seen.
	func _gone(a) -> bool:
		var pj := _lens.project(a.pos)
		if pj.z < NEAREST:
			return true
		var r: float = a.scale * _lens._focal / maxf(0.1, pj.z) * 1.2
		return absf(pj.x) - r > _half.x or absf(pj.y) - r > _half.y

	func begin(stage, actors: Array) -> void:
		_force = clampf(num("force", 0.5), 0.0, 1.0)
		_wind = lerpf(0.24, 0.12, _force)
		_power = lerpf(2.4, 1.5, _force)
		_roll_rate = lerpf(1.5, 10.0, _force) * (1.0 if rng.randf() < 0.5 else -1.0)
		_lens = stage.lens
		_lens.prepare()
		_half = stage.view_half() if stage.has_method("view_half") else Vector2(0.9, 0.5)
		for a in actors:
			a.state.erase("form")
			Actions.let_go(a)
			var dir := Vector3.ZERO
			if args.get("to") != null:
				dir = Storyboard.sample_vec3(args["to"], rng, Vector3.RIGHT)
			else:
				# away from the others still shown, the way a burst throws its pieces
				var mid := Vector3.ZERO
				var others := 0
				for o in stage.actors():
					if o != a and o.fade > 0.05 and not actors.has(o):
						mid += o.pos
						others += 1
				if others > 0 and a.pos.distance_to(mid / float(others)) > 0.05:
					dir = a.pos - mid / float(others)
				else:
					var ang := rng.randf() * TAU
					dir = Vector3(cos(ang), sin(ang) * 0.6, 0.0)
				dir = dir.normalized().rotated(Vector3.BACK, rng.randf_range(-0.3, 0.3))
				dir.z += rng.randf_range(-0.25, 0.05)
			dir = dir.normalized() if dir.length() > 1e-4 else Vector3.RIGHT
			# toward the camera, turned sideways until it leaves the frame before it comes too near
			var exit := _exit(a, dir)
			var tries := 0
			while bool(exit["near"]) and tries < 12:
				var side := Vector2(dir.x, dir.y)
				side = side.normalized() if side.length() > 1e-3 else Vector2.RIGHT
				dir = Vector3(side.x, side.y, 0.0).lerp(dir, 0.75).normalized()
				exit = _exit(a, dir)
				tries += 1
			var out := float(exit["out"])
			var way: float
			var tail := false
			if out < 0.0 or dir.z < -0.3:
				# into the distance: a run of its own, fading out over the window's end
				way = lerpf(DEPTH_RUN.x, DEPTH_RUN.y, _force) if out < 0.0 else minf(out * (1.08 + 0.6 * _force), lerpf(DEPTH_RUN.x, DEPTH_RUN.y, _force))
				tail = true
			elif dir.z > 0.05:
				way = out * 1.08            # toward the camera it ends at the frame's edge
			else:
				way = out * (1.08 + 0.6 * _force)
			_from.append(a.pos)
			_to.append(a.pos + dir * way)
			_dir.append(dir)
			_back.append((0.08 + 0.3 * a.scale) / way)
			_tail.append(tail)
			_fade0.append(a.fade)
			_out.append(false)
			_from_q.append(Quaternion(Basis.from_euler((a.body as PrismBody).rot)) if a.body is PrismBody else Quaternion())

	func apply(stage, actors: Array, k: float, _f: AudioFeatures, dt: float) -> void:
		var turned := smoothstep(0.0, 1.0, k / (_wind * 1.3))
		_roll += _roll_rate * dt * turned
		var launch := k >= _wind
		for i in actors.size():
			var a = actors[i]
			var b := float(_back[i])
			var s: float
			if not launch:
				s = -b * sin(0.5 * PI * k / _wind)                                  # draws back, slowing
			else:
				var q := (k - _wind) / (1.0 - _wind)
				s = -b + (1.0 + b) * pow(q, _power)                                 # and goes, gathering speed
			a.pos = (_from[i] as Vector3).lerp(_to[i], s)
			a.home = a.pos
			if a.body is PrismBody:
				var way := Actions.travelling(_in_view(_dir[i]), _roll)
				var q: Quaternion = (_from_q[i] as Quaternion).slerp(way, turned)
				(a.body as PrismBody).rot = Basis(q).get_euler()
			if launch and not _launched and _force >= 0.5:
				stage.spatter(a.pos, rng.randi_range(3, 5), rng, Color.from_hsv(fposmod(a.hue, 1.0), 0.35, 1.0))
			# hidden once out; a way into the distance fades over the window's end
			if launch and not bool(_out[i]) and _gone(a):
				_out[i] = true
			if bool(_out[i]):
				a.fade = 0.0
			elif bool(_tail[i]):
				a.fade = float(_fade0[i]) * (1.0 - smoothstep(1.0 - FADE_TAIL, 1.0, k))
		_launched = _launched or launch

	func finish(_stage, actors: Array) -> void:
		for i in actors.size():
			var a = actors[i]
			a.pos = _to[i]
			a.home = a.pos
			a.fade = 0.0
			a.state.erase("tremble")


## gather - the swarm's members ease in one at a time and form up (k plays the
## staggered joins through; see [Cast.SwarmActor]).
class Gather extends Action:
	func apply(_stage, actors: Array, k: float, _f: AudioFeatures, _dt: float) -> void:
		for a in actors:
			a.state["gather"] = k


## fly - the formation flies forward along its track, the stage camera following a touch slower so it pulls
## ahead and recedes. args: speed (x, default 1.0), follow (camera fraction of the travel, default 0.72).
class Fly extends Action:
	var _base_z := 0.0
	var _speed := 1.0
	var _follow := 0.72

	func begin(stage, _actors: Array) -> void:
		_base_z = stage.lens.eye.z
		_speed = num("speed", 1.0)
		_follow = num("follow", 0.72)

	func apply(stage, actors: Array, k: float, f: AudioFeatures, dt: float) -> void:
		var drive := clampf(f.energy * 0.8 + f.beat * 0.6, 0.0, 1.0)
		for a in actors:
			var travel := float(a.state.get("travel", 0.0)) + dt * k * (1.2 + 0.8 * drive) * _speed
			a.state["travel"] = travel
			stage.lens.eye.z = _base_z + travel * _follow
			stage.lens.look.z = stage.lens.eye.z + 6.0


## helix_split - the single track opens into a double helix: the spread widens and
## the counter-winding red strand fades in (see [Cast.SwarmActor]).
class HelixSplit extends Action:
	func apply(_stage, actors: Array, k: float, _f: AudioFeatures, _dt: float) -> void:
		for a in actors:
			a.state["split_k"] = k


## lane_jump - the swarm banks to its side and leaps across to the other strand,
## then holds there (k rides the bank's arc through the crossing).
class LaneJump extends Action:
	func apply(_stage, actors: Array, k: float, _f: AudioFeatures, _dt: float) -> void:
		for a in actors:
			a.state["lane"] = k


## set - set one actor parameter instantly. args: param, value.
class SetParam extends Action:
	func apply(_stage, actors: Array, _k: float, _f: AudioFeatures, _dt: float) -> void:
		var v := num("value", 0.0)
		for a in actors:
			a.set_param(String(args.get("param", "")), v)


## ramp - ease one actor parameter from its current value (or `from`) to `to`.
class Ramp extends Action:
	var _from: Array = []
	var _to := 0.0

	func begin(_stage, actors: Array) -> void:
		_to = num("to", 0.0)
		for a in actors:
			_from.append(num("from", a.get_param(String(args.get("param", "")))))

	func apply(_stage, actors: Array, k: float, _f: AudioFeatures, _dt: float) -> void:
		for i in actors.size():
			actors[i].set_param(String(args.get("param", "")), lerpf(float(_from[i]), _to, k))


## pulse - a scale breathing on the target while the span runs ({amp, rate});
## latches unless args.latch is false.
class Pulse extends Action:
	var _amp := 0.1
	var _rate := 1.2

	func begin(_stage, _actors: Array) -> void:
		_amp = num("amp", 0.1)
		_rate = num("rate", 1.2)

	func apply(_stage, actors: Array, k: float, _f: AudioFeatures, _dt: float) -> void:
		for a in actors:
			a.state["pulse"] = {"amp": _amp * k, "rate": _rate}

	func finish(_stage, actors: Array) -> void:
		if not bool(args.get("latch", true)):
			for a in actors:
				a.state.erase("pulse")


## flash - a bright burst overlay on the target (a stinger accent).
class Flash extends Action:
	func apply(stage, actors: Array, _k: float, _f: AudioFeatures, _dt: float) -> void:
		var h := num("hue", -1.0)
		var col := Color(1, 1, 1) if h < 0.0 else Color.from_hsv(h, 0.45, 1.0)
		for a in actors:
			stage.flash(a, col)
