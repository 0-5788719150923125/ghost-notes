extends RefCounted
class_name CameraFollow

## CameraFollow - how a flown camera follows what it is turned to: the one follow of every medium that flies one (the
## Dispatch desk, the desk and the Letter, the novel and the notebook, the tablet). Each channel of the view (where it
## looks, where it stands, its lens, its angles) is led in over [constant FIELDS] `ease_in`, so no move starts with a jolt,
## and settled on a critically damped spring (`settle`), so none overshoots.
##
## A long look runs on a quicker clock, its end included: a turn of `long_full` degrees or more `long` times quicker, one
## of `long_from` or less at its own pace, partly between. A linear spring takes as long over a short look as a long one,
## and on a long one the eye sees the slow end crawl for seconds; quickening the whole move is what shortens it. A move's
## size is the farthest the view has been from where it goes since it last came to rest, so a look turned elsewhere
## mid-way keeps its pace. It never turns faster than `top_speed`, eased under it rather than clipped.
##
## The settings are the Camera card's over the format's own (a Medium row's `follow`, [method settings]). What a medium
## changes for a moment (springs quickened on a new page, through a still) is a pace on one step ([method step]), never a
## setting. A medium makes one with each channel's slowness (1 its own pace; 3 for angles that settle three times slower)
## and which channel is the point it looks at, and steps it each frame with where every channel is going and where the
## eye is now. A channel is a float or a Vector3; the point looked at is a Vector3.

## What can be set (the Camera card's rows, [CameraCard]); a format's row in [constant Medium.REGISTRY] (`follow`) says its
## own, and where it says none these defaults stand.
const FIELDS := {
	"ease_in": {"label": "Ease in (s)", "type": "float", "min": 0.0, "max": 20.0, "step": 0.05, "default": 0.0,
		"blurb": "How long a move takes to get going: every turn starts slowly over about this many seconds. 0 starts at once, on the spring alone."},
	"settle": {"label": "Settle (s)", "type": "float", "min": 0.1, "max": 30.0, "step": 0.05, "default": 1.6,
		"blurb": "How slowly it settles on what it turns to: the spring's time in seconds. A short look is mostly there in about four of these."},
	"long": {"label": "Long looks (x)", "type": "float", "min": 0.25, "max": 8.0, "step": 0.05, "default": 2.0,
		"blurb": "How many times quicker a long look runs, its end included: 2 crosses the desk in about half the time. 1 takes a long look at a short one's pace; under 1, slower."},
	"long_from": {"label": "Long from (°)", "type": "float", "min": 0.0, "max": 180.0, "step": 1.0, "default": 20.0,
		"blurb": "A look of this many degrees or less runs at its own pace; past it, quicker and quicker."},
	"long_full": {"label": "Fully long (°)", "type": "float", "min": 1.0, "max": 180.0, "step": 1.0, "default": 80.0,
		"blurb": "A look of this many degrees or more is quickened by the whole of Long looks."},
	"top_speed": {"label": "Top speed (°/s)", "type": "float", "min": 1.0, "max": 720.0, "step": 1.0, "default": 45.0,
		"blurb": "The fastest it ever turns, in degrees a second: a move that would go faster is eased under it."},
}
## Steps a second the springs are worked at, at the least; more where a quick spring would need them.
const RATE := 60.0
## The view this close to where it goes (degrees), turning no faster than REST_SPEED (degrees a second), is at rest: the
## next move's size is counted from here.
const REST := 1.5
const REST_SPEED := 2.0
## How quickly the clock takes a new quickening (seconds): a look turned elsewhere mid-way changes its pace smoothly.
const SCALE_EASE := 0.3
## A look has arrived ([method arrival]) within this share of its way, or within [constant REST].
const ARRIVED := 0.1
## The longest a look is followed to work out its arrival (seconds): past it, it is said to arrive then.
const LONGEST := 300.0

var _slow := PackedFloat32Array([1.0])
var _look := 0
var _stall := INF
var _set := settings({}, {})
var _f: Array = []                       # where each channel is led toward, eased in
var _c: Array = []                       # where it is
var _v: Array = []                       # how fast it goes there, at the follow's own pace
var _span := 0.0                         # the move's size (degrees)
var _scale := 1.0                        # how much quicker a move of its size runs, eased to
var _run := 1.0                          # ...and how much quicker its clock runs now, under the top speed
var _arrivals := {}                      # a look's degrees and the settings -> its seconds ([method arrival])


## A follow for channels as slow as [param slow] (each a multiple of the settle), [param look] the one that is the point
## looked at (a Vector3), a step never moving more than [param stall_most] seconds (a stall of the app's thread eased out
## of, rather than leapt).
func _init(slow: Array = [1.0], look := 0, stall_most := INF) -> void:
	_slow = PackedFloat32Array(slow)
	_look = look
	_stall = stall_most


## The settings in force: the Camera card's [param chosen] over the format's [param own], each within its row's bounds and
## a row neither names at its default.
static func settings(own: Dictionary, chosen: Dictionary) -> Dictionary:
	var out := {}
	for k in FIELDS:
		var row: Dictionary = FIELDS[k]
		var v: Variant = chosen.get(k)
		if not (v is float or v is int):
			v = own.get(k)
		if not (v is float or v is int):
			v = row["default"]
		out[k] = clampf(float(v), float(row["min"]), float(row["max"]))
	return out


## What a card keeps of [param block]: only the settings it names that are numbers, within their bounds.
static func sanitize(block: Variant) -> Dictionary:
	var out := {}
	if not (block is Dictionary):
		return out
	for k in FIELDS:
		var v: Variant = (block as Dictionary).get(k)
		if v is float or v is int:
			var row: Dictionary = FIELDS[k]
			out[k] = clampf(float(v), float(row["min"]), float(row["max"]))
	return out


## How far apart (degrees), seen from [param eye], looking at [param now] and at [param to] are.
static func apart(eye: Vector3, now: Vector3, to: Vector3) -> float:
	var a := now - eye
	var b := to - eye
	if a.length_squared() < 1e-10 or b.length_squared() < 1e-10:
		return 0.0
	return rad_to_deg(a.angle_to(b))


## How many times quicker a move of [param span] degrees runs under [param s], before the top speed.
static func quicken(s: Dictionary, span: float) -> float:
	var from := float(s["long_from"])
	var full := maxf(float(s["long_full"]), from + 0.01)
	return 1.0 + (float(s["long"]) - 1.0) * smoothstep(from, full, span)


## Take [param s] ([method settings]) from the next step on.
func configure(s: Dictionary) -> void:
	_set = s


## The settings in force.
func current() -> Dictionary:
	return _set


## Every channel put at [param values] at once, at rest: a cut, a seek, the first frame.
func snap(values: Array) -> void:
	_f = values.duplicate()
	_c = values.duplicate()
	_v = []
	for x in values:
		_v.append(x * 0.0)
	_span = 0.0
	_scale = 1.0
	_run = 1.0


## One frame, [param delta] seconds: each channel on toward [param targets] (as many as were snapped, else they are snapped
## to them), [param eye] where the camera stands now; [param pace] what a medium makes of this moment (under 1 quicker, over
## 1 slower: its own springs' times multiplied). Returns where each channel is.
func step(targets: Array, delta: float, eye: Vector3, pace := 1.0) -> Array:
	if _c.size() != targets.size():
		snap(targets)
		return _c
	_advance(targets, minf(maxf(delta, 0.0), _stall), pace, func() -> Vector2:
		var now: Vector3 = _c[_look]
		var from := now - eye
		if from.length_squared() < 1e-10:
			return Vector2.ZERO
		var v: Vector3 = _v[_look]
		var n := from.normalized()
		return Vector2(apart(eye, now, targets[_look]), rad_to_deg((v - n * v.dot(n)).length() / from.length())))
	return _c


## Where channel [param i] is.
func value(i: int) -> Variant:
	return _c[i] if i < _c.size() else null


## How much quicker the clock runs now (1 at its own pace).
func quickened() -> float:
	return _run


## Seconds a look of [param deg] degrees from rest takes to arrive under the settings in force ([constant ARRIVED]): what a
## medium times a thing by that waits for the camera to be on it. Worked out once for each look and setting.
func arrival(deg: float) -> float:
	var key := "%.1f|%s" % [deg, JSON.stringify(_set)]
	if _arrivals.has(key):
		return float(_arrivals[key])
	var probe := CameraFollow.new([1.0])
	probe.configure(_set)
	probe.snap([0.0])
	var h := 1.0 / RATE
	var t := 0.0
	var near := maxf(deg * ARRIVED, REST)
	var measure := func() -> Vector2: return Vector2(absf(deg - float(probe._c[0])), absf(float(probe._v[0])))
	while t < LONGEST and absf(deg - float(probe._c[0])) > near:
		probe._advance([deg], h, 1.0, measure)
		t += h
	if _arrivals.size() > 64:
		_arrivals.clear()
	_arrivals[key] = t
	return t


## The springs worked over [param dt] seconds, each channel's time [param pace] times its own, in steps short enough for the
## quickest spring on the quickest clock; before each, the clock's pace from [param measure] (`() -> Vector2`: how far, in
## degrees, the view is from where it goes, and how fast it turns at its own pace, in degrees a second).
func _advance(targets: Array, dt: float, pace: float, measure: Callable) -> void:
	if dt <= 0.0:
		return
	var slowest := 1.0
	for i in mini(_slow.size(), _c.size()):
		slowest = minf(slowest, _slow[i]) if i > 0 else _slow[i]
	var quickest := maxf(float(_set["settle"]) * pace * slowest, 0.02)
	var steps := maxi(maxi(1, ceili(dt * RATE)), ceili(dt * maxf(float(_set["long"]), 1.0) / quickest / 0.5))
	var h := dt / float(steps)
	var lead_tau := float(_set["ease_in"]) * pace
	for _s in steps:
		var m: Vector2 = measure.call()
		_pace_by(m.x, m.y, h)
		var run := h * _run
		var lead := 1.0 - exp(-run / lead_tau) if lead_tau > 1e-4 else 1.0
		for i in _c.size():
			_f[i] = _f[i] + (targets[i] - _f[i]) * lead
			var w := 1.0 / maxf(float(_set["settle"]) * pace * (_slow[i] if i < _slow.size() else 1.0), 0.02)
			_v[i] = _v[i] + ((_f[i] - _c[i]) * (w * w) - _v[i] * (2.0 * w)) * run
			_c[i] = _c[i] + _v[i] * run


## The clock's quickening for this step: the move's size from [param far] (degrees from where it goes), eased to; then
## held under the top speed at once by how fast it turns at its own pace ([param speed], degrees a second) - a soft limit,
## so the speed seen never jumps.
func _pace_by(far: float, speed: float, dt: float) -> void:
	if far >= _span or (far < REST and speed * _run < REST_SPEED):
		_span = far
	_scale += (quicken(_set, _span) - _scale) * (1.0 - exp(-dt / SCALE_EASE))
	_run = _scale / pow(1.0 + pow(_scale * speed / float(_set["top_speed"]), 4.0), 0.25)
