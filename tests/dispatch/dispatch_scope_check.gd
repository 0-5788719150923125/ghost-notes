extends SceneTree

## Gate for the receiver's oscilloscope ([DispatchScope], [method DispatchSounds.receiver_wave], next/dispatch.md). It holds:
##
## - the receiver's own static: idle a faint hiss, opened up by a storm; a pop the receiver plays is a spike on the trace where
##   it is heard (the control: the moment before it, no spike); with the grid down, nothing;
## - a voice on the receiver is its real waveform (the heard audio's), through its words; the room's voice never (the control:
##   the same waveform through the receiver's word is on it);
## - triggered: a held tone stands still from frame to frame (the control: run free, it does not);
## - the receiver's AGC: the static alone brought up to fill the glass, a voice bringing the gain down; quick down, slow up;
## - the figure: a tone against itself a quarter period behind is a ring (the control: with no delay, a line); the morphed copy
##   is the output read at its rate and delay (the control: read at one, it is not); turned further, another view; the beam
##   brightest where it moves slowest; its drift the same at a moment and moving on; drawn unless the receiver's property says a
##   sweep;
## - the worker's drawing taken in, waited for as a render waits.
##
## Run: godot --headless --path . --script tests/dispatch/dispatch_scope_check.gd

const Scope := preload("res://src/dispatch/dispatch_scope.gd")

var _fails: Array = []


func _init() -> void:
	var rate := Scope.RATE
	var n := int(Scope.WINDOW * float(rate))
	var crackle := {"t": 10.0, "t1": 20.0, "kind": "static", "storm": "popcorn", "seed": 7, "under": [], "words": []}
	var station := {"t": 60.0, "t1": 70.0, "kind": "static", "storm": "popcorn", "seed": 5, "under": [[1.0, 4.0]],
		"words": [[1.25, 1.75], [2.5, 3.2]]}
	var open := [crackle, station]
	# the static: faint idle, opened by a storm, nothing with the grid down
	var idle := _rms(DispatchSounds.receiver_wave(open, 5.0, n, rate, 1.0, true))
	var storm := _rms(DispatchSounds.receiver_wave(open, 15.0, n, rate, 1.0, true))
	_ok(idle > 0.0 and idle < 0.003 and storm > idle * 3.0, "idle the receiver hisses faintly, a storm opens it up (%.5f, %.5f)" % [idle, storm])
	var dead := DispatchSounds.receiver_wave(open, 15.0, n, rate, 1.0, false)
	_ok(_peak(dead) == 0.0, "with the grid down the receiver is silent")
	# a pop the receiver plays, alone in the 40 ms before it and loud: a spike where it is heard
	var slot := -1
	var prob := func(s: int) -> bool: return DispatchSounds.hash01(7, s) < DispatchSounds.POP_RATE * DispatchSounds.POP_SLOT \
		* DispatchSounds.receiver_level(crackle, float(s) * DispatchSounds.POP_SLOT)
	for s in range(300, 2200):
		if prob.call(s) and DispatchSounds.hash01(14, s) > 0.7:
			var alone := true
			for e in range(s - 12, s):
				alone = alone and not prob.call(e)
			if alone:
				slot = s
				break
	var onset := 10.0 + float(slot) * DispatchSounds.POP_SLOT
	var at := DispatchSounds.receiver_wave(open, onset + 0.01, n, rate, 1.0, true)
	var before := DispatchSounds.receiver_wave(open, onset - 0.0005, n, rate, 1.0, true)
	var lead := at.slice(0, n - int(0.012 * float(rate)))
	var spike := _peak(at.slice(n - int(0.012 * float(rate))))
	_ok(slot > 0 and spike > _rms(lead) * 4.0, "a pop the receiver plays is a spike where it is heard (%.4f over %.5f)" % [spike, _rms(lead)])
	_ok(_peak(before) < _rms(before) * 4.0, "the control: the moment before the pop there is no spike")
	# the voice: its real waveform through the receiver's word; the room's never
	var tone := func(t: float) -> AudioFeatures: return _tone(t, 200.0, 0.5)
	var heard := Scope.output(61.5, open, tone.call(61.5), true, 1.0)
	var room := Scope.output(5.0, open, tone.call(5.0), true, 1.0)
	var c_heard := _match(heard, 61.5, 200.0)
	var c_room := _match(room, 5.0, 200.0)
	_ok(c_heard > 0.9, "through the receiver's word its voice is the heard waveform itself (matching %.3f)" % c_heard)
	_ok(c_room < 0.2, "the room's voice is never on it (matching %.3f; the control, through the receiver's word, %.3f)" % [c_room, c_heard])
	# triggered: a held tone stands still
	var a: Dictionary = Scope.worked(61.5, open, tone.call(61.5), true, 1.0, 1.0, -1.0)
	var b: Dictionary = Scope.worked(61.5 + 1.0 / 60.0, open, tone.call(61.5 + 1.0 / 60.0), true, 1.0, float(a["gain"]), 1.0 / 60.0)
	# (each as a share of its trace's own size: the tone's amplitude at its gain)
	var still := _apart(a["trace"], b["trace"]) / (0.5 * float(a["gain"]))
	var free := 0.2
	var free_a := Scope.swept(Scope.output(61.5, open, tone.call(61.5), true, 1.0), free)
	var free_b := Scope.swept(Scope.output(61.5 + 1.0 / 60.0, open, tone.call(61.5 + 1.0 / 60.0), true, 1.0), free)
	var runs := _apart(free_a, free_b) / (0.5 * free)
	_ok(still < 0.3, "a held tone stands still from frame to frame (%.2f of its size apart)" % still)
	_ok(runs > 0.6, "the control: run free, below the trigger, it does not stand still (%.2f of its size apart)" % runs)
	# the AGC: the static alone fills the glass; a voice brings the gain down; quick down, slow up
	var alone_trace: Dictionary = Scope.worked(15.0, open, null, true, 1.0, 1.0, -1.0)
	_ok(float(alone_trace["gain"]) > 10.0 and _peak(alone_trace["trace"]) > 0.3,
		"the static alone is brought up to fill the glass (gain %.1f, peak %.2f)" % [float(alone_trace["gain"]), _peak(alone_trace["trace"])])
	_ok(float(a["gain"]) < 2.0, "a voice brings the gain down (gain %.2f)" % float(a["gain"]))
	var down: Dictionary = Scope.worked(61.5, open, tone.call(61.5), true, 1.0, 50.0, 0.02)
	var up: Dictionary = Scope.worked(15.0, open, null, true, 1.0, 1.0, 0.02)
	_ok(float(down["gain"]) < 15.0 and float(up["gain"]) < 2.0,
		"the AGC comes down quickly and goes back up slowly (%.1f from 50, %.2f from 1)" % [float(down["gain"]), float(up["gain"])])
	# the figure: a tone against itself a quarter period behind is a ring; no delay, a line (the control)
	var hz := 250.0
	var ring := _tone_wave(hz, 0.5, int(Scope.HISTORY * float(rate)))
	var flat := {"delay": 0.25 / hz, "morph_delay": 0.0, "rate": 1.0, "turn": 0.0, "tilt": 0.0}
	var circle: Dictionary = Scope.figured(ring, 1.0, flat)
	var line: Dictionary = Scope.figured(ring, 1.0, {"delay": 0.0, "morph_delay": 0.0, "rate": 1.0, "turn": 0.0, "tilt": 0.0})
	var radii := _radii(circle["points"])
	_ok(radii.x > 0.5 and radii.y - radii.x < 0.08, "a tone against itself a quarter period behind is a ring (radius %.3f to %.3f)" % [radii.x, radii.y])
	_ok(_off_diagonal(line["points"]) < 0.01 and _off_diagonal(circle["points"]) > 0.3, "the control: with no delay it is a line")
	# the morphed copy is the output read at its rate: turned a quarter, it is what is on the X input
	var quarter := {"delay": 0.0, "morph_delay": 0.002, "rate": 1.5, "turn": PI * 0.5, "tilt": 0.0}
	var morphed: Dictionary = Scope.figured(ring, 1.0, quarter)
	var unmorphed: Dictionary = Scope.figured(ring, 1.0, {"delay": 0.0, "morph_delay": 0.002, "rate": 1.0, "turn": PI * 0.5, "tilt": 0.0})
	var off := _morph_error(morphed["points"], hz, 1.5, 0.002)
	_ok(off < 0.02 and _morph_error(unmorphed["points"], hz, 1.5, 0.002) > 0.2,
		"the morphed copy is the output read at its rate and delay (off by %.4f; the control, read at one, is not)" % off)
	# turning in depth: the same moment turned further is another view of it
	var turned: Dictionary = Scope.figured(ring, 1.0, {"delay": 0.25 / hz, "morph_delay": 0.003, "rate": 1.25, "turn": 0.8, "tilt": 0.4})
	var turned_on: Dictionary = Scope.figured(ring, 1.0, {"delay": 0.25 / hz, "morph_delay": 0.003, "rate": 1.25, "turn": 1.4, "tilt": 0.4})
	_ok(_apart2(turned["points"], turned_on["points"]) > 0.2, "turned further, the figure is another view of it")
	# the beam: brightest where it moves slowest
	var g: PackedFloat32Array = turned["glow"]
	var p: PackedVector2Array = turned["points"]
	var slow := 0
	var fast := 0
	for i in range(1, p.size() - 1):
		if p[i + 1].distance_to(p[i - 1]) < p[slow + 1].distance_to(p[maxi(slow - 1, 0)]):
			slow = i
		if p[i + 1].distance_to(p[i - 1]) > p[fast + 1].distance_to(p[maxi(fast - 1, 0)]):
			fast = i
	_ok(g[slow] > g[fast], "the beam glows brightest where it moves slowest (%.2f against %.2f)" % [g[slow], g[fast]])
	# its drift: the same every time, and on through the night
	_ok(Scope.params(57, 30.0) == Scope.params(57, 30.0) and Scope.params(57, 30.0) != Scope.params(57, 50.0),
		"the figure's drift is the same at the same moment, and moves on through the night")
	# how it draws is the receiver's property
	_ok(DispatchSet.scope_trace({}) == "figure" and DispatchSet.scope_trace({"trace": "sweep"}) == "sweep",
		"the scope draws a figure unless the receiver's property says a sweep")
	# the worker's drawing, waited for as a render waits
	var scope := Scope.new()
	var landed := scope.tick(15.0, open, null, 1.0, 1.0, true)
	_ok(landed and scope.figure.size() == Scope.FIGURE_POINTS and scope.shown().has("figure"), "the worker's figure is taken in, waited for as a render waits")
	scope.mode = "sweep"
	landed = scope.tick(15.1, open, null, 1.0, 1.0, true)
	_ok(landed and scope.trace.size() == Scope.POINTS and scope.figure.is_empty(), "...and a sweep, told so")
	if _fails.is_empty():
		print("dispatch_scope_check: ALL OK")
		quit(0)
	else:
		for e in _fails:
			print("dispatch_scope_check: FAIL  " + e)
		quit(1)


## A frame of heard audio whose waveform is a tone of [param hz] at [param amp], its window ending at [param t].
func _tone(t: float, hz: float, amp: float) -> AudioFeatures:
	var f := AudioFeatures.new()
	f.time = t
	f.hear_from(func() -> PackedFloat32Array:
		var w := PackedFloat32Array()
		w.resize(AudioFeatures.WAVE_SAMPLES)
		for i in w.size():
			w[i] = amp * sin(TAU * hz * (t - float(w.size() - 1 - i) / float(AudioFeatures.WAVE_RATE)))
		return w)
	return f


## A tone of [param hz] at [param amp], [param n] samples at the scope's rate, its last at time 0.
func _tone_wave(hz: float, amp: float, n: int) -> PackedFloat32Array:
	var w := PackedFloat32Array()
	w.resize(n)
	for i in n:
		w[i] = amp * sin(TAU * hz * (-float(n - 1 - i) / float(Scope.RATE)))
	return w


## The least and most distance of [param p]'s points from the glass's middle.
func _radii(p: PackedVector2Array) -> Vector2:
	var lo := INF
	var hi := 0.0
	for q in p:
		lo = minf(lo, q.length())
		hi = maxf(hi, q.length())
	return Vector2(lo, hi)


## How far [param p]'s points stray from the diagonal at most.
func _off_diagonal(p: PackedVector2Array) -> float:
	var most := 0.0
	for q in p:
		most = maxf(most, absf(q.x - q.y) / sqrt(2.0))
	return most


## How far a figure turned a quarter ([param p]: its X the morphed copy, of a tone of [param hz] at 0.5 whose last sample is time
## 0) strays from that tone read at [param rate] and [param delay] behind.
func _morph_error(p: PackedVector2Array, hz: float, rate: float, delay: float) -> float:
	var most := 0.0
	for i in p.size():
		var back := Scope.FIGURE * (1.0 - float(i) / float(p.size() - 1))
		var want := 0.5 * sin(TAU * hz * (-(back * rate + delay))) * Scope.FIGURE_SIZE
		most = maxf(most, absf(p[i].x - clampf(want, -1.3, 1.3)))
	return most


func _apart2(a: PackedVector2Array, b: PackedVector2Array) -> float:
	var most := 0.0
	for i in mini(a.size(), b.size()):
		most = maxf(most, a[i].distance_to(b[i]))
	return most


## How well [param s] (ending at [param t]) matches a tone of [param hz] there: its correlation with it.
func _match(s: PackedFloat32Array, t: float, hz: float) -> float:
	var sxy := 0.0
	var sxx := 0.0
	var syy := 0.0
	for i in s.size():
		var y := sin(TAU * hz * (t - float(s.size() - 1 - i) / float(Scope.RATE)))
		sxy += s[i] * y
		sxx += s[i] * s[i]
		syy += y * y
	return sxy / maxf(sqrt(sxx * syy), 1e-9)


func _apart(a: PackedFloat32Array, b: PackedFloat32Array) -> float:
	var most := 0.0
	for i in mini(a.size(), b.size()):
		most = maxf(most, absf(a[i] - b[i]))
	return most


func _rms(s: PackedFloat32Array) -> float:
	var sum := 0.0
	for v in s:
		sum += v * v
	return sqrt(sum / float(maxi(s.size(), 1)))


func _peak(s: PackedFloat32Array) -> float:
	var most := 0.0
	for v in s:
		most = maxf(most, absf(v))
	return most


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails.append(what)
