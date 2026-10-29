extends SceneTree

## The gate of THE HAND ([Hands]; next/table_physics.md, "The hand"), pure. The user, 2026-10-28: "the motions are somewhat
## jerky, and they follow straight lines. A real human might move in curves, or in nonlinear patterns, or it might gently
## jitter".
##
##   godot --headless --path . --script res://tests/table/hands_check.gd
##
## - A CARRY ENDS WHERE IT WAS SENT AND BEGINS WHERE IT WAS: its first and last places are its ends exactly.
## - ITS SPEED NEVER STEPS: frame to frame, at 60 a second, no change of speed past what a hand's own acceleration gives
##   - and none at its middle, where the cubic ease before it stepped from speeding up to slowing down. The control: that
##   cubic ease steps there.
## - IT SLOWS LONGER INTO ITS PLACING than it took to leave: its fastest moment is before its middle.
## - IT BOWS: half way along a long move it is off the straight line, to one side, never more than a hand's bow - and a
##   short move hardly bows. The control: the straight line is on it.
## - ITS LIFT RISES EARLY AND NEVER DIPS: it is highest before the middle, and never below either end.
## - A HELD THING LAGS ITS HAND: tilted toward the way it is pulled as it sets off, the other way as it stops, upright at
##   rest.
## - A HELD THING IS NEVER STILL, and still at its ends: off the table it drifts; at either end of a move, not at all.
## - A ROUND IS NEVER THE SAME TWICE: a stir's round wanders in pace, reach and middle, and the same seed wanders alike.
## - THE SAME MOVE TWICE: one seed, one move.

var _fails := 0


func _init() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("  FAIL: " + what)


func _run() -> void:
	await process_frame
	var a := Vector3(0.0, 0.0, 0.0)
	var b := Vector3(0.3, 0.0, 0.1)
	var lift := 0.06
	var seed := 12345
	var at := func(x: float) -> Vector3: return Hands.carried(a, b, Vector3.ZERO, Vector3.ZERO, lift, x, seed)
	_ok((at.call(0.0) as Vector3).is_equal_approx(a) and (at.call(1.0) as Vector3).is_equal_approx(b), "a carry does not begin and end at its ends")
	# ITS SPEED NEVER STEPS (3 seconds, 60 frames a second)
	var secs := 3.0
	var frames := int(secs * 60.0)
	var worst := 0.0
	var fastest := 0.0
	var fastest_at := 0.0
	var last_v := Vector3.ZERO
	for i in range(1, frames + 1):
		var v := ((at.call(float(i) / float(frames)) as Vector3) - (at.call(float(i - 1) / float(frames)) as Vector3)) * 60.0
		if i > 1:
			worst = maxf(worst, (v - last_v).length() * 60.0)
		if v.length() > fastest:
			fastest = v.length()
			fastest_at = float(i) / float(frames)
		last_v = v
	_ok(worst < 1.5, "a 3 second carry's speed steps by %.2f m/s^2 from one frame to the next" % worst)
	var cubic_jump := absf(_cubic_acc(0.5 - 1e-4) - _cubic_acc(0.5 + 1e-4))
	var mj_jump := absf(_mj_acc(0.5 - 1e-4) - _mj_acc(0.5 + 1e-4))
	_ok(cubic_jump > 20.0 and mj_jump < 0.1, "the control: the cubic ease's acceleration does not step at the middle (%.1f), or minimum jerk's does (%.2f)" % [cubic_jump, mj_jump])
	_ok(fastest_at < 0.48 and fastest_at > 0.3, "a carry is fastest %.0f%% of the way, not before its middle" % (fastest_at * 100.0))
	# IT BOWS
	var mid: Vector3 = at.call(0.5)
	var flat := Vector3(mid.x, 0.0, mid.z)
	var line := Vector3(b.x, 0.0, b.z).normalized()
	var off := (flat - line * flat.dot(line)).length()
	_ok(off > 0.003 and off <= Hands.BOW_MOST + 1e-6, "half way along a 32 cm carry it is %.1f mm off the straight line" % (off * 1000.0))
	var straight := Vector3(b.x, 0.0, b.z) * 0.5
	_ok((straight - line * straight.dot(line)).length() < 1e-6, "the control: the straight line is off itself")
	var short := Hands.bow(a, Vector3(0.015, 0.0, 0.0), 0.5, seed)
	_ok(short.length() < 1e-6, "a 1.5 cm move bows %.2f mm" % (short.length() * 1000.0))
	# ITS LIFT RISES EARLY AND NEVER DIPS
	var highest := 0.0
	var highest_at := 0.0
	var dips := false
	for i in 101:
		var y := (at.call(float(i) / 100.0) as Vector3).y
		dips = dips or y < -1e-6
		if y > highest:
			highest = y
			highest_at = float(i) / 100.0
	_ok(not dips and absf(highest - lift) < 0.002 and highest_at < 0.5, "a carry's lift dips below its ends or is not highest early: %.1f cm at %.0f%%" % [highest * 100.0, highest_at * 100.0])
	# A HELD THING LAGS ITS HAND
	var early := Hands.lean(at, 0.15, secs)
	var late := Hands.lean(at, 0.85, secs)
	var rest := Hands.lean(at, 0.0, secs)
	var way := Vector3(b.x, 0.0, b.z).normalized()
	var top_early := (early * Vector3.UP)
	var top_late := (late * Vector3.UP)
	_ok(top_early.dot(way) > 0.002 and top_late.dot(way) < -0.002, "a carried thing does not lean toward its pull as it sets off (%.4f) and back as it stops (%.4f)" % [top_early.dot(way), top_late.dot(way)])
	_ok((rest * Vector3.UP).is_equal_approx(Vector3.UP), "a carried thing leans at rest")
	# NEVER STILL, AND STILL AT ITS ENDS
	var moved := 0.0
	for i in 30:
		var d: Array = Hands.drift(10.0 + float(i) * 0.1, seed, 1.0)
		moved = maxf(moved, (d[0] as Vector3).length())
	var at_end: Array = Hands.drift(10.0, seed, Hands.held(0.0))
	_ok(moved > 0.0003, "a held thing drifts %.2f mm at most" % (moved * 1000.0))
	_ok((at_end[0] as Vector3) == Vector3.ZERO and (at_end[1] as Basis).is_equal_approx(Basis.IDENTITY), "a thing at the end of its move drifts")
	# A ROUND IS NEVER THE SAME TWICE
	var r1 := Hands.round_of(1.0, 1.5, seed)
	var r2 := Hands.round_of(1.0 + 1.5 * 2.0, 1.5, seed)
	_ok(absf(float(r1["phase"]) - float(r2["phase"])) > 0.01 or absf(float(r1["radius"]) - float(r2["radius"])) > 0.005, "two rounds of a stir are the same")
	_ok(Hands.round_of(1.0, 1.5, seed) == r1, "one seed's round wanders two ways")
	# THE SAME MOVE TWICE
	_ok(Hands.carried(a, b, Vector3.ZERO, Vector3.ZERO, lift, 0.37, seed) == Hands.carried(a, b, Vector3.ZERO, Vector3.ZERO, lift, 0.37, seed),
		"one seed, two moves")
	print("hands_check: %s (%d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _fails, "" if _fails == 1 else "s"])
	quit(1 if _fails > 0 else 0)


## The cubic in and out the work eased with before minimum jerk: its acceleration at [param u].
static func _cubic_acc(u: float) -> float:
	return 24.0 * u if u < 0.5 else -12.0 * (2.0 - 2.0 * u)


## Minimum jerk's acceleration at [param u].
static func _mj_acc(u: float) -> float:
	return 60.0 * u - 180.0 * u * u + 120.0 * u * u * u
