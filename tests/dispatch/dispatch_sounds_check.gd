extends SceneTree

## Gate for THE DESK, HEARD ([DispatchSounds], next/dispatch.md):
##
## - THE JET'S PITCH FALLS as it passes: heard raised as it comes and lowered as it goes - the Doppler factor c / (c - v cos)
##   at the speed of sound, falling all the way through - and it is loudest as it passes overhead;
## - THE STORMS DIFFER: Io-B's pops are spiky (their peak far over their level), Io-A's surf is smooth swells - and both are
##   heard over the receiver's own hiss;
## - SUBDUED: a phone flipped and snapped, keys, the ping, the toggle, the mug set down, the gain knob's click, the lamp's
##   switch, the ring in the earpiece, the terminal's bell - none louder than the desk's most;
## - THE BELL is one short beep: heard over the hiss while it sounds, and gone when it ends;
## - A PURE FUNCTION OF THE SCHEDULE: the same plan made twice is the same sound, sample for sample;
## - THE CONTROL: with nothing planned there is only the hiss, and it is faint.
##
## Run: godot --headless --path . --script tests/dispatch/dispatch_sounds_check.gd

const RATE := DispatchSounds.RATE

var _fails: Array = []


## A desk with nothing but a sound plan.
class Plan extends RefCounted:
	var plan: Array = []

	func sound_plan() -> Array:
		return plan

	func sound_rev() -> int:
		return 1


func _init() -> void:
	# THE JET
	var span := float(DispatchSounds.SOUNDS["jet"]["secs"])
	var early := DispatchSounds.jet_pitch(0.5, span)
	var late := DispatchSounds.jet_pitch(span - 0.5, span)
	var falls := true
	var last := INF
	for k in 40:
		var f := DispatchSounds.jet_pitch(span * float(k) / 39.0, span)
		if f > last + 1e-6:
			falls = false
		last = f
	_ok(early > 1.08 and late < 0.93 and falls, "the jet's pitch falls all through its pass (%.3f to %.3f)" % [early, late])
	var jet := _render([{"t": 0.0, "t1": span, "kind": "jet"}], span)
	var ends := maxf(_rms(jet, 0.2, 1.2), _rms(jet, span - 1.2, span - 0.2))
	var over := _rms(jet, span * 0.5 - 0.6, span * 0.5 + 0.6)
	_ok(over > ends * 2.0 and _peak(jet) < DispatchSounds.LOUD_MOST * 2.0, "the jet is loudest overhead, and never too loud (%.4f against %.4f, peak %.3f)" % [over, ends, _peak(jet)])
	# THE STORMS
	var pop := _render([{"t": 0.0, "t1": 5.0, "kind": "static", "storm": "popcorn", "seed": 11}], 5.0)
	var surf := _render([{"t": 0.0, "t1": 5.0, "kind": "static", "storm": "surf", "seed": 11}], 5.0)
	var quiet := _render([], 5.0)
	var crest_pop := _peak(pop) / maxf(_rms(pop, 0.5, 4.5), 1e-6)
	var crest_surf := _peak(surf) / maxf(_rms(surf, 0.5, 4.5), 1e-6)
	_ok(crest_pop > crest_surf * 1.3, "Io-B's pops are spikier than Io-A's surf (crest %.1f against %.1f)" % [crest_pop, crest_surf])
	_ok(_rms(pop, 0.5, 4.5) > _rms(quiet, 0.5, 4.5) * 3.0 and _rms(surf, 0.5, 4.5) > _rms(quiet, 0.5, 4.5) * 3.0,
		"both storms are heard over the hiss")
	_ok(_peak(pop) < DispatchSounds.LOUD_MOST * 2.0 and _peak(surf) < DispatchSounds.LOUD_MOST * 2.0, "the storms are never too loud")
	# THE ONE-SHOTS AND THE PHONE
	var desk: Array = []
	var k := 0.2
	for what in ["flip", "snap", "lay", "key", "space", "ping", "echo", "toggle", "thud", "crt", "click", "detent", "lamp"]:
		desk.append({"t": k, "what": what, "at": Vector3(0.3, 0.76, 0.0)})
		k += 0.35
	desk.append({"t": k, "t1": k + 2.6, "kind": "ringback"})
	desk.append({"t": k + 3.0, "t1": k + 5.8, "kind": "buzz", "pattern": "ring", "ears": Vector2(0.8, 0.6)})
	desk.append({"t": k + 6.0, "t1": k + 8.5, "kind": "print", "lines": 4, "ears": Vector2(0.9, 0.4)})
	desk.append({"t": k + 8.6, "t1": k + 8.6 + DispatchSounds.BELL_LEN, "kind": "bell", "ears": Vector2(0.7071, 0.7071)})
	var heard := _render(desk, k + 9.0)
	# THE BELL, alone
	var bell := _render([{"t": 0.5, "t1": 0.5 + DispatchSounds.BELL_LEN, "kind": "bell", "ears": Vector2(0.7071, 0.7071)}], 1.5)
	var ringing := _rms(bell, 0.52, 0.5 + DispatchSounds.BELL_LEN - 0.02)
	var after_bell := _rms(bell, 0.5 + DispatchSounds.BELL_LEN + 0.02, 1.4)
	_ok(ringing > _rms(quiet, 0.5, 4.5) * 5.0 and after_bell < ringing * 0.2 and _peak(bell) < DispatchSounds.PEAK_MOST,
		"the bell is one short beep, heard over the hiss and gone when it ends (%.4f, then %.4f)" % [ringing, after_bell])
	_ok(_peak(heard) < DispatchSounds.PEAK_MOST * 1.6 and _rms(heard, 0.1, k + 9.0) > _rms(quiet, 0.5, 4.5) * 1.5,
		"the desk's sounds are heard, and subdued (peak %.3f)" % _peak(heard))
	# A PURE FUNCTION OF THE SCHEDULE
	var again := _render(desk, k + 9.0)
	var same := again.size() == heard.size()
	for i in mini(again.size(), heard.size()):
		if again[i] != heard[i]:
			same = false
			break
	_ok(same, "the same plan is the same sound, sample for sample")
	# THE CONTROL
	_ok(_peak(quiet) < 0.012, "the control: with nothing planned only the faint hiss is heard (peak %.4f)" % _peak(quiet))
	if _fails.is_empty():
		print("dispatch_sounds_check: ALL OK")
		quit(0)
	else:
		for f in _fails:
			print("dispatch_sounds_check: FAIL  " + f)
		quit(1)


func _render(plan: Array, secs: float) -> PackedVector2Array:
	var p := Plan.new()
	p.plan = plan
	var s := DispatchSounds.new(p)
	s._restart(0.0)
	var out := PackedVector2Array()
	var n := int(secs * RATE)
	while out.size() < n:
		out.append_array(s.render(mini(4096, n - out.size())))
	return out


static func _rms(buf: PackedVector2Array, a: float, b: float) -> float:
	var s := 0.0
	var n := 0
	for i in range(int(a * RATE), mini(int(b * RATE), buf.size())):
		s += buf[i].x * buf[i].x + buf[i].y * buf[i].y
		n += 2
	return sqrt(s / maxf(1.0, float(n)))


static func _peak(buf: PackedVector2Array) -> float:
	var m := 0.0
	for v in buf:
		m = maxf(m, maxf(absf(v.x), absf(v.y)))
	return m


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails.append(what)
