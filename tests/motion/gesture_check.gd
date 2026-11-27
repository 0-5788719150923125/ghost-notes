extends SceneTree

## gesture_check - a hand's motion ([Gesture]). It holds:
##
## - no stroke is a straight line: out and back part (control: a path along one line measures no parting);
## - no stroke goes at a constant speed: speed varies most of its size and is still at every turn (control: a steady
##   circle measures no variation);
## - a rub's cycles spread a few percent, near the pace asked (control: a clock's cycles measure no spread);
## - the stroke out takes longer than the stroke back;
## - `pace_to` is heard: a rub asked to go faster ends quicker than it began (control: one at a steady pace does not);
## - it lands and lifts: pressed nothing at its ends, pressed hardest where it goes fastest on the stroke out;
## - a pure function of its seed (control: another seed, another rub);
## - taps come in rolls with rests between, land exactly at their hits (off the surface between them), at the speed the hit
##   says - the fall's own speed;
## - a reach ends where it was sent, still at both ends, its path bowed; a quick one is corrected by a second, smaller move
##   (control: a slow one has one bell of speed);
## - a held thing at rest drifts a few millimeters and never stands still.
##
##   godot --headless --path . --script tests/motion/gesture_check.gd

var _fails := 0
var _checks := 0


func _init() -> void:
	var secs := 12.0
	var rub := Gesture.strokes(7, secs, {"pace": 1.6, "reach": 0.022, "arc": 0.004, "press": 1.0, "breaks": 0.0})
	var u: PackedFloat32Array = rub["u"]
	var w: PackedFloat32Array = rub["w"]
	var on: PackedFloat32Array = rub["on"]
	var pr: PackedFloat32Array = rub["press"]
	var v := Gesture.speeds(u, w)
	var a := int(1.5 * Gesture.RATE)
	var b := int((secs - 1.5) * Gesture.RATE)

	# no straight line: across the stroke, out and back part
	_ok(_spread(w, a, b) > 0.003, "a stroke's out and back part across it (%.1f mm)" % (_spread(w, a, b) * 1000.0))
	var line := PackedFloat32Array()
	line.resize(u.size())
	_ok(_spread(line, a, b) < 0.0005, "control: a path along one line measures no parting")

	# no constant speed, and still at every turn
	var cv := _cv(v, a, b)
	_ok(cv > 0.35, "speed varies along the strokes (spread %.2f of its mean)" % cv)
	var circle := PackedFloat32Array()
	circle.resize(u.size())
	circle.fill(0.1)
	_ok(_cv(circle, a, b) < 0.01, "control: a steady circle measures no variation")
	var turns := _turns(u, a, b)
	var still_at_turns := true
	var peak := 0.0
	for i in range(a, b):
		peak = maxf(peak, v[i])
	for i in turns:
		if v[i] > peak * 0.2:
			still_at_turns = false
	_ok(turns.size() > 20 and still_at_turns, "it is all but still at each of its %d turns" % turns.size())

	# cycles spread a few percent, near the pace
	var periods := PackedFloat32Array()
	for k in range(2, turns.size(), 2):
		periods.append(float(turns[k] - turns[k - 2]) / Gesture.RATE)
	var mean := _mean(periods)
	var spread := _cv(periods, 0, periods.size())
	_ok(absf(mean - 1.0 / 1.6) < 0.1 and spread > 0.015 and spread < 0.2,
		"cycles average %.3f s (1/1.6 asked) and spread %.1f%%" % [mean, spread * 100.0])
	var clock := PackedFloat32Array([0.625, 0.625, 0.625, 0.625])
	_ok(_cv(clock, 0, clock.size()) < 0.001, "control: a clock's cycles measure no spread")

	# the stroke out is longer than the stroke back
	var out_t := 0.0
	var back_t := 0.0
	for k in range(1, turns.size()):
		var d := float(turns[k] - turns[k - 1])
		if u[turns[k]] > u[turns[k - 1]]:
			out_t += d
		else:
			back_t += d
	_ok(out_t > back_t * 1.04, "the stroke out takes longer than the stroke back (%.2f against %.2f s)" % [out_t / Gesture.RATE, back_t / Gesture.RATE])

	# faster
	var fast := Gesture.strokes(7, secs, {"pace": 1.2, "pace_to": 2.6, "breaks": 0.0})
	var fv := Gesture.speeds(fast["u"], fast["w"])
	var q := int(secs * 0.25 * Gesture.RATE)
	var first := _mean_of(fv, int(1.0 * Gesture.RATE), int(1.0 * Gesture.RATE) + q)
	var last := _mean_of(fv, fv.size() - q - int(0.5 * Gesture.RATE), fv.size() - int(0.5 * Gesture.RATE))
	_ok(last > first * 1.5, "a rub asked to go faster ends quicker (%.3f against %.3f m/s)" % [last, first])
	var steady_first := _mean_of(v, int(1.0 * Gesture.RATE), int(1.0 * Gesture.RATE) + q)
	var steady_last := _mean_of(v, v.size() - q - int(0.5 * Gesture.RATE), v.size() - int(0.5 * Gesture.RATE))
	_ok(steady_last < steady_first * 1.3, "control: one at a steady pace ends about as it began")

	# lands and lifts; pressed hardest where it goes fastest on the stroke out
	_ok(on[0] < 0.01 and on[on.size() - 1] < 0.01 and pr[0] < 0.01 and pr[pr.size() - 1] < 0.01 and on[on.size() / 2] > 0.99,
		"it lands and lifts: pressed nothing at its ends, wholly on in its middle")
	var fast_press := 0.0
	var slow_press := 0.0
	var nf := 0
	var ns := 0
	for i in range(a, b):
		if v[i] > peak * 0.7 and i + 1 < u.size() and u[i + 1] > u[i]:
			fast_press += pr[i]
			nf += 1
		elif v[i] < peak * 0.15:
			slow_press += pr[i]
			ns += 1
	_ok(nf > 0 and ns > 0 and fast_press / nf > slow_press / ns * 1.08, "it presses hardest where it goes fastest on the stroke out")

	# a pure function of its seed
	var again := Gesture.strokes(7, secs, {"pace": 1.6, "reach": 0.022, "arc": 0.004, "press": 1.0, "breaks": 0.0})
	var other := Gesture.strokes(8, secs, {"pace": 1.6, "reach": 0.022, "arc": 0.004, "press": 1.0, "breaks": 0.0})
	_ok(again["u"] == u and again["press"] == pr, "the same seed is the same rub")
	_ok(other["u"] != u, "control: another seed is another rub")

	# breaks: a rub with them hesitates or lifts mid-act (a re-grip) somewhere; one without does neither
	var broken := Gesture.strokes(3, 60.0, {"breaks": 0.06})
	var calm := Gesture.strokes(3, 60.0, {"breaks": 0.0})
	_ok(_broke(broken), "a rub with breaks hesitates or lifts somewhere mid-act")
	_ok(not _broke(calm), "control: one without breaks never does")

	# taps
	var tp := Gesture.taps(5, 10.0, {"rate": 7.0, "group": 4, "gap": 0.5, "speed": 0.35})
	var hits: Array = tp["hits"]
	var lift: PackedFloat32Array = tp["lift"]
	var quick_gaps := 0
	var rests := 0
	for k in range(1, hits.size()):
		var d := float(hits[k]["t"]) - float(hits[k - 1]["t"])
		if d < 0.22:
			quick_gaps += 1
		elif d > 0.3:
			rests += 1
	_ok(hits.size() > 12 and quick_gaps > 6 and rests > 2, "taps come in rolls (%d quick, %d rests, %d taps)" % [quick_gaps, rests, hits.size()])
	var lands := true
	var speeds_ok := true
	for h in hits:
		var i := int(round(float(h["t"]) * Gesture.RATE))
		if i < 2 or i >= lift.size():
			continue
		if lift[i] > 0.0015:
			lands = false
		var fall := (lift[i - 2] - lift[i]) / (2.0 / Gesture.RATE)
		if absf(fall - float(h["speed"])) > float(h["speed"]) * 0.35 + 0.02:
			speeds_ok = false
	_ok(lands, "every tap lands at its hit")
	_ok(speeds_ok, "each lands at the speed its hit says")
	var between := 0.0
	for k in range(1, hits.size()):
		between = maxf(between, Gesture.at(lift, (float(hits[k]["t"]) + float(hits[k - 1]["t"])) * 0.5))
	_ok(between > 0.004, "between taps it is off the surface (%.1f mm at most)" % (between * 1000.0))

	# a reach
	var from := Vector3(0.1, 0.0, 0.0)
	var to := Vector3(-0.1, 0.05, -0.1)
	var path := Gesture.reach(4, from, to, 0.9, Vector3(0.0, 0.04, 0.0), true)
	var pv := Gesture.speeds3(path)
	_ok(path[0].distance_to(from) < 0.001 and path[path.size() - 1].distance_to(to) < 0.001, "a reach ends where it was sent")
	var top := 0.0
	for x in pv:
		top = maxf(top, x)
	_ok(pv[1] < top * 0.1 and pv[pv.size() - 2] < top * 0.1, "...still at both ends")
	var mid := path[path.size() / 2]
	var off_line := (mid - from).cross((to - from).normalized()).length()
	_ok(off_line > 0.02, "...its path bowed (%.1f cm off the line at its middle)" % (off_line * 100.0))
	_ok(_bells(pv) >= 2, "a quick reach is corrected by a second, smaller move")
	_ok(_bells(Gesture.speeds3(Gesture.reach(4, from, to, 0.9, Vector3.ZERO, false))) == 1, "control: a slow reach has one bell of speed")

	# idle
	var far := 0.0
	var moved := false
	var p0 := Gesture.idle(9, 0.0)
	for i in 600:
		var p := Gesture.idle(9, float(i) * 0.05)
		far = maxf(far, p.length())
		if p.distance_to(p0) > 0.0005:
			moved = true
	_ok(far < 0.008 and moved, "a held thing drifts a few millimeters (%.1f at most) and never stands still" % (far * 1000.0))

	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _ok(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("ok    " + what)
	else:
		_fails += 1
		print("FAIL  " + what)


## How far [param x] spreads between samples [param a] and [param b] once its slow drift is taken out (max - min of
## what is left over each second).
func _spread(x: PackedFloat32Array, a: int, b: int) -> float:
	var best := 0.0
	var step := int(Gesture.RATE)
	for s in range(a, b - step, step):
		var lo := INF
		var hi := -INF
		for i in range(s, s + step):
			lo = minf(lo, x[i])
			hi = maxf(hi, x[i])
		best = maxf(best, hi - lo)
	return best


func _mean(x: PackedFloat32Array) -> float:
	return _mean_of(x, 0, x.size())


func _mean_of(x: PackedFloat32Array, a: int, b: int) -> float:
	var s := 0.0
	for i in range(a, b):
		s += x[i]
	return s / maxf(float(b - a), 1.0)


func _cv(x: PackedFloat32Array, a: int, b: int) -> float:
	var m := _mean_of(x, a, b)
	var s := 0.0
	for i in range(a, b):
		s += (x[i] - m) * (x[i] - m)
	return sqrt(s / maxf(float(b - a), 1.0)) / maxf(absf(m), 1e-9)


## Where [param u] turns (its local extremes) between [param a] and [param b].
func _turns(u: PackedFloat32Array, a: int, b: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in range(a + 1, b - 1):
		if (u[i] > u[i - 1] and u[i] >= u[i + 1]) or (u[i] < u[i - 1] and u[i] <= u[i + 1]):
			if out.is_empty() or i - out[out.size() - 1] > 20:
				out.append(i)
	return out


## The longest stretch (s) where [param v] stays under [param below].
func _longest_still(v: PackedFloat32Array, below: float) -> float:
	var best := 0
	var run := 0
	for i in range(int(Gesture.RATE), v.size() - int(Gesture.RATE)):
		run = run + 1 if v[i] < below else 0
		best = maxi(best, run)
	return float(best) / Gesture.RATE


## How many bells a speed profile has: peaks of its smoothed speed (a 50 ms window: a tremor's wiggles are not bells) over
## a tenth of its top, each parted from the last by a dip under 0.6 of the smaller.
func _bells(v: PackedFloat32Array) -> int:
	var sm := PackedFloat32Array()
	sm.resize(v.size())
	var half := 7
	for i in v.size():
		var s := 0.0
		var k := 0
		for j in range(maxi(i - half, 0), mini(i + half + 1, v.size())):
			s += v[j]
			k += 1
		sm[i] = s / float(k)
	var top := 0.0
	for x in sm:
		top = maxf(top, x)
	var peaks: Array = []
	var low_since := INF
	for i in range(1, sm.size() - 1):
		low_since = minf(low_since, sm[i])
		if sm[i] > top * 0.1 and sm[i] >= sm[i - 1] and sm[i] > sm[i + 1]:
			if peaks.is_empty() or low_since < 0.6 * minf(sm[i], float(peaks[peaks.size() - 1])):
				peaks.append(sm[i])
				low_since = INF
			elif sm[i] > float(peaks[peaks.size() - 1]):
				peaks[peaks.size() - 1] = sm[i]
	return peaks.size()


## Whether a rub hesitated (near still for a third of a second somewhere a cycle never is) or lifted off mid-act.
func _broke(rub: Dictionary) -> bool:
	var on: PackedFloat32Array = rub["on"]
	var v := Gesture.speeds(rub["u"], rub["w"])
	var a := int(1.5 * Gesture.RATE)
	for i in range(a, on.size() - a):
		if on[i] < 0.5:
			return true
	return _longest_still(v, 0.02) > 0.3
