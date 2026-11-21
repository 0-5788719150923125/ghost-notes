extends RefCounted
class_name DispatchScope

## DispatchScope - what the receiver's oscilloscope draws (next/dispatch.md): the receiver's own output, never a drawn pattern.
## The static it plays, from the receiver's own synthesis ([method DispatchSounds.receiver_wave]: its hiss, a storm's swells,
## each pop where it is heard); and a voice that comes in on it, its real waveform off the heard audio ([method
## AudioFeatures.wave]), taken only through that voice's words ([method DispatchSpectrum.heard_at]), so the room's voice is never
## on it. Levelled as the receiver's own AGC levels it - the hiss brought up to the glass when nothing is there, the gain coming
## down when a voice does, and back up over a moment after.
##
## Drawn one of two ways ([member mode], the receiver's `trace` property): a SWEEP, the output over time, triggered on a rising
## edge so a held vowel stands still and noise runs ([method swept]); or a FIGURE, the scope in XY ([method figured]): the output
## against two copies of itself - one delayed, one delayed and read at another rate, its pitch and tempo morphed - three channels
## tracing a shape in three dimensions (the signal's phase portrait), shown turning in depth as a slowly turning mix of two of them
## on the X input shows it, through a low tone so its loops are smooth. A held vowel draws a knot of loops, a rate near one sets it precessing, another rate ties it into a
## Lissajous knot; noise draws a fuzzy ball and a pop a ring that dies away. The delays, the rate and the turn drift with show time
## from the desk's number ([method params]). The beam glows brightest where it moves slowest, and nearest; the figures before it
## fade on the phosphor.
##
## Worked out on a worker ([method tick]), a frame behind what is heard; in a render waited for, so each frame draws its own.

## Its rate (Hz, the heard waveform's), how much of the output a sweep works out (s: the sweep and room before it to trigger in),
## how long the sweep across the glass takes (s), and the points its trace is drawn through.
const RATE := AudioFeatures.WAVE_RATE
const WINDOW := 0.04
const SWEEP := 0.02
const POINTS := 200
## The trigger's level, rising, on the glass's scale (its half height 1).
const TRIGGER := 0.12
## The receiver's AGC: the output's RMS it holds over the last [constant WINDOW] (on the glass's scale), its least and most gain,
## and how quickly it comes down and goes back up (s).
const AGC_TARGET := 0.25
const AGC_LEAST := 0.05
const AGC_MOST := 120.0
const AGC_ATTACK := 0.04
const AGC_RELEASE := 0.7
## The figure: how much of the output it draws (s), the points it is drawn through, how large for the AGC's level, and how much of
## the output is worked out for it (s: its span and as far back as its copies read).
const FIGURE := 0.022
const FIGURE_POINTS := 520
const FIGURE_SIZE := 1.35
const HISTORY := 0.05
## The tone the figure is drawn through (Hz, a low pass, as the receiver's tone control turned down): its loops are the output's
## lowest partials, smooth, rather than every harmonic's scribble.
const FIGURE_TONE := 800.0
## The most gain the AGC gives a figure: its tone takes most of an idle hiss away, and what is left is still drawn as a small ball.
const FIGURE_GAIN_MOST := 480.0
## Its copies: the first's delay and the morphed one's, each wandering between these (s) over [constant DRIFT] seconds; the rates
## the morphed one is read at, one drawn and held for [constant RATE_HOLD] seconds and eased into over [constant RATE_EASE] (near
## one it precesses; the others tie knots).
const DELAY := Vector2(0.0003, 0.0035)
const MORPH_DELAY := Vector2(0.0008, 0.006)
const DRIFT := 7.0
const RATES := [1.0, 1.004, 0.996, 1.5, 0.75, 1.25]
const RATE_HOLD := 6.0
const RATE_EASE := 1.5
## How it turns in depth: radians a second about the upright, and its tilt toward the eye, give or take.
const TURN := 0.3
const TILT := 0.45
const TILT_GIVE := 0.25
## The beam: a step this long (on the glass's scale) glows fully, a longer one dimmer down to the least; how much brighter the near
## side is than the far; and how brightly each figure before it still glows, newest first.
const BEAM := 0.03
const BEAM_LEAST := 0.1
const DEPTH := 0.45
const TRAILS := [0.3, 0.12]

var mode := "figure"                 # `figure` or `sweep` (the receiver's `trace` property)
var seed := 0                        # the desk's number its figure's drift is drawn from
var trace := PackedFloat32Array()    # a sweep: [constant POINTS] values, the glass's half height 1
var was := PackedFloat32Array()      # ...and the sweep before it, fading on the phosphor
var figure := PackedVector2Array()   # a figure: its points on the glass's scale
var glow := PackedFloat32Array()     # ...how brightly the beam draws each
var trails: Array = []               # ...and the figures before it, newest first: [points, glow]
var _gain := 1.0
var _t := NAN                        # the moment the drawing is of
var _asked := NAN                    # the moment last asked of the worker
var _task := -1
var _box := {}


## The drawing at show time [param t] asked of a worker, and the one it finished taken in: from the receiver's stretches [param
## open] (replaced whole when remade, never changed in place), this frame's heard audio [param features] (null: none), the grid's
## [param power] and the receiver's [param share] of its level; [param wait] (a render) waits for it. True when it changed.
func tick(t: float, open: Array, features: AudioFeatures, power: float, share: float, wait: bool) -> bool:
	var changed := _land(false)
	if _task < 0 and t != _asked:
		_asked = t
		var dt := t - _t if is_finite(_t) and absf(t - _t) < 1.0 else -1.0
		var box := {}
		_box = box
		var gain := _gain
		var powered := power > 0.5
		var how := mode
		var number := seed
		_task = WorkerThreadPool.add_task(func() -> void:
			box["out"] = worked(t, open, features, powered, share, gain, dt, how, number), false, "the receiver's scope")
		if wait:
			changed = _land(true) or changed
	return changed


## What the glass is handed ([method DispatchScreens.show_scope]): a figure `{figure, glow, trails}`, or a sweep `{trace, was}`.
func shown() -> Dictionary:
	if mode == "figure":
		return {"figure": figure, "glow": glow, "trails": trails}
	return {"trace": trace, "was": was}


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)


## The worker's drawing taken in, where it is done (or waited for, [param wait]).
func _land(wait: bool) -> bool:
	if _task < 0 or not (wait or WorkerThreadPool.is_task_completed(_task)):
		return false
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	var out: Dictionary = _box.get("out", {})
	if out.is_empty():
		return false
	if out.has("figure"):
		if not figure.is_empty():
			trails.push_front([figure, glow])
		trails.resize(mini(trails.size(), TRAILS.size()))
		figure = out["figure"]
		glow = out["glow"]
		trace = PackedFloat32Array()
		was = PackedFloat32Array()
	else:
		was = trace
		trace = out["trace"]
		figure = PackedVector2Array()
		trails = []
	_gain = float(out["gain"])
	_t = float(out["t"])
	return true


## The drawing at [param t] and the AGC's gain after it: the receiver's output up to [param t] ([method output]; for a figure
## through its tone, [method toned]), levelled from
## [param gain] toward its target over [param dt] seconds (below 0: at once, after a jump), then figured ([param how] `figure`:
## `{figure, glow, gain, t}`, its drift drawn from [param number]) or swept (`{trace, gain, t}`). A pure function of what it is
## handed: a worker's.
static func worked(t: float, open: Array, features: AudioFeatures, powered: bool, share: float, gain: float, dt: float,
		how := "sweep", number := 0) -> Dictionary:
	var s := output(t, open, features, powered, share, HISTORY if how == "figure" else WINDOW)
	if how == "figure":
		s = toned(s, FIGURE_TONE)
	var n := mini(s.size(), int(WINDOW * float(RATE)))
	var sum := 0.0
	for i in range(s.size() - n, s.size()):
		sum += s[i] * s[i]
	var rms := sqrt(sum / float(maxi(n, 1)))
	var want := clampf(AGC_TARGET / maxf(rms, 1e-7), AGC_LEAST, FIGURE_GAIN_MOST if how == "figure" else AGC_MOST)
	var g := want
	if dt >= 0.0:
		var k := 1.0 - exp(-dt / (AGC_ATTACK if want < gain else AGC_RELEASE))
		g = exp(lerpf(log(maxf(gain, 1e-6)), log(want), k))
	if how == "figure":
		var f := figured(s, g, params(number, t))
		return {"figure": f["points"], "glow": f["glow"], "gain": g, "t": t}
	return {"trace": swept(s, g), "gain": g, "t": t}


## The receiver's output over the [param span] seconds up to [param t] at [constant RATE]: its own static, and the heard voice
## where one comes in on it, eased in and out with its words.
static func output(t: float, open: Array, features: AudioFeatures, powered: bool, share: float, span := WINDOW) -> PackedFloat32Array:
	var n := int(span * float(RATE))
	var s := DispatchSounds.receiver_wave(open, t, n, RATE, share, powered)
	if not powered or features == null:
		return s
	var g := [DispatchSpectrum.heard_at(t - span, open), DispatchSpectrum.heard_at(t - span * 0.5, open), DispatchSpectrum.heard_at(t, open)]
	if float(g[0]) + float(g[1]) + float(g[2]) <= 0.0:
		return s
	var wave := features.wave()
	if wave.size() < n:
		return s
	var off := wave.size() - n
	for i in n:
		var u := float(i) / float(n - 1) * 2.0
		var k := mini(int(u), 1)
		s[i] += wave[off + i] * lerpf(float(g[k]), float(g[k + 1]), u - float(k))
	return s


## [param s] as the glass draws it at [param gain]: from the latest rising pass through the trigger's level that leaves a whole
## sweep after it (the newest sweep where nothing passes it, as a scope's auto mode runs free), [constant POINTS] points
## across [constant SWEEP], each on the glass's scale.
static func swept(s: PackedFloat32Array, gain: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(POINTS)
	var sweep := int(SWEEP * float(RATE))
	var n := s.size()
	if n < sweep + 2:
		return out
	var level := TRIGGER / maxf(gain, 1e-6)
	var start := n - sweep - 2
	var k := start
	while k > 0:
		if s[k - 1] < level and s[k] >= level:
			start = k
			break
		k -= 1
	for i in POINTS:
		var x := float(start) + float(i) / float(POINTS - 1) * float(sweep)
		var j := mini(int(x), n - 2)
		out[i] = clampf(lerpf(s[j], s[j + 1], x - float(j)) * gain, -1.2, 1.2)
	return out


## [param s] through a low pass at [param hz] (two poles, Butterworth), begun at its first sample.
static func toned(s: PackedFloat32Array, hz: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(s.size())
	if s.is_empty():
		return out
	var w := TAU * hz / float(RATE)
	var alpha := sin(w) / (2.0 * 0.7071)
	var a0 := 1.0 + alpha
	var b1 := (1.0 - cos(w)) / a0
	var b0 := b1 * 0.5
	var a1 := -2.0 * cos(w) / a0
	var a2 := (1.0 - alpha) / a0
	var x1 := s[0]
	var x2 := s[0]
	var y1 := s[0]
	var y2 := s[0]
	for i in s.size():
		var x := s[i]
		var y := b0 * x + b1 * x1 + b0 * x2 - a1 * y1 - a2 * y2
		out[i] = y
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
	return out


## The figure's drift at show time [param t] for desk number [param number]: `{delay, morph_delay, rate, turn, tilt}` - each
## wandering smoothly, the rate held and eased from one of [constant RATES] to the next. The same every time.
static func params(number: int, t: float) -> Dictionary:
	var k := floori(t / RATE_HOLD)
	var now := float(RATES[int(_h01(number, 5, k) * float(RATES.size())) % RATES.size()])
	var before := float(RATES[int(_h01(number, 5, k - 1) * float(RATES.size())) % RATES.size()])
	var u := smoothstep(0.0, 1.0, (t - float(k) * RATE_HOLD) / RATE_EASE)
	return {"delay": lerpf(DELAY.x, DELAY.y, _drift(number, 1, t, DRIFT)),
		"morph_delay": lerpf(MORPH_DELAY.x, MORPH_DELAY.y, _drift(number, 2, t, DRIFT * 1.3)),
		"rate": exp(lerpf(log(before), log(now), u)),
		"turn": TURN * t + TAU * _h01(number, 3, 0),
		"tilt": TILT + TILT_GIVE * (2.0 * _drift(number, 4, t, DRIFT * 1.7) - 1.0)}


## The figure of [param s] (its last sample the moment) at [param gain] with drift [param p] ([method params]): `{points, glow}` -
## the last [constant FIGURE] seconds of it against a copy [code]delay[/code] behind and a copy read at [code]rate[/code] and
## [code]morph_delay[/code] behind, turned [code]turn[/code] about the upright and tilted [code]tilt[/code] toward the eye, each
## point on the glass's scale; the beam brightest where it moves slowest, and nearest.
static func figured(s: PackedFloat32Array, gain: float, p: Dictionary) -> Dictionary:
	var pts := PackedVector2Array()
	pts.resize(FIGURE_POINTS)
	var depth := PackedFloat32Array()
	depth.resize(FIGURE_POINTS)
	var end := float(s.size() - 1)
	var d1 := float(p["delay"]) * float(RATE)
	var d2 := float(p["morph_delay"]) * float(RATE)
	var rate := float(p["rate"])
	var ct := cos(float(p["turn"]))
	var st := sin(float(p["turn"]))
	var cl := cos(float(p["tilt"]))
	var sl := sin(float(p["tilt"]))
	var size := gain * FIGURE_SIZE
	for i in FIGURE_POINTS:
		var back := FIGURE * float(RATE) * (1.0 - float(i) / float(FIGURE_POINTS - 1))
		var a := _at(s, end - back)
		var b := _at(s, end - back - d1)
		var c := _at(s, end - back * rate - d2)
		var x := a * ct + c * st
		var z := c * ct - a * st
		pts[i] = Vector2(clampf(x * size, -1.3, 1.3), clampf((b * cl - z * sl) * size, -1.3, 1.3))
		depth[i] = (b * sl + z * cl) * size
	var lit := PackedFloat32Array()
	lit.resize(FIGURE_POINTS)
	for i in FIGURE_POINTS:
		var step := pts[mini(i + 1, FIGURE_POINTS - 1)].distance_to(pts[maxi(i - 1, 0)]) * 0.5
		var near := 1.0 - DEPTH * 0.5 * clampf(depth[i], -1.0, 1.0)
		lit[i] = clampf(BEAM / maxf(step, 1e-6), BEAM_LEAST, 1.0) * near
	return {"points": pts, "glow": lit}


## [param s] at fractional sample [param x], through the four samples round it (Catmull-Rom): silence before its start.
static func _at(s: PackedFloat32Array, x: float) -> float:
	if x < 0.0:
		return 0.0
	var n := s.size()
	var i := int(x)
	var f := x - float(i)
	var p0 := s[clampi(i - 1, 0, n - 1)]
	var p1 := s[clampi(i, 0, n - 1)]
	var p2 := s[clampi(i + 1, 0, n - 1)]
	var p3 := s[clampi(i + 2, 0, n - 1)]
	return 0.5 * (2.0 * p1 + (p2 - p0) * f + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * f * f + (3.0 * p1 - p0 - 3.0 * p2 + p3) * f * f * f)


## A value wandering smoothly in [0, 1] with [param t], a new one every [param every] seconds, eased between: the same every time
## for [param number] and [param salt].
static func _drift(number: int, salt: int, t: float, every: float) -> float:
	var x := t / every
	var k := floori(x)
	return lerpf(_h01(number, salt, k), _h01(number, salt, k + 1), smoothstep(0.0, 1.0, x - float(k)))


## A number in [0, 1) from [param number], [param salt] and [param k], the same every time: an integer mix.
static func _h01(number: int, salt: int, k: int) -> float:
	var h := (number * 73856093) ^ (salt * 19349663) ^ (k * 83492791)
	h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
	h = h ^ (h >> 16)
	return float(h & 0xFFFFFF) / 16777216.0
