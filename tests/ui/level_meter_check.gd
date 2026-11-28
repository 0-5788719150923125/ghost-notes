extends SceneTree

## LevelMeter's reading ([LevelMeter.Reading]): a peak shows at once and falls back at its rate, and each ear's highest is held a
## while then lets go. The control: silence rests on the floor, never under it.
##
##   godot --headless --path . --script tests/ui/level_meter_check.gd

var _checks := 0
var _failed := 0


func _init() -> void:
	var r := LevelMeter.Reading.new()
	r.feed(-6.0, -20.0, 0.016)
	_ok(is_equal_approx(r.left, -6.0) and is_equal_approx(r.right, -20.0), "a peak shows at once (%.1f, %.1f)" % [r.left, r.right])
	for i in 50:
		r.feed(-60.0, -60.0, 0.02)
	_ok(absf(r.left - (-6.0 - LevelMeter.FALL * 1.0)) < 0.6, "it falls back at its rate (%.1f after 1 s)" % r.left)
	_ok(is_equal_approx(float(r.held[0]), -6.0), "the ear's highest is held (%.1f)" % float(r.held[0]))
	for i in 50:
		r.feed(-60.0, -60.0, 0.02)
	_ok(float(r.held[0]) < -50.0, "...and let go after its while (%.1f)" % float(r.held[0]))
	r.feed(-1.0, -12.0, 0.02)
	r.feed(-40.0, -40.0, 0.5)
	_ok(is_equal_approx(float(r.held[0]), -1.0) and is_equal_approx(float(r.held[1]), -12.0), "each ear holds its own highest")
	r.feed(-200.0, -200.0, 0.02)
	_ok(r.left >= LevelMeter.FLOOR and r.right >= LevelMeter.FLOOR, "control: silence rests on the floor, never under it")
	print("level_meter_check: %d checks, %d failed" % [_checks, _failed])
	quit(1 if _failed > 0 else 0)


func _ok(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("ok    " + what)
	else:
		_failed += 1
		print("FAIL  " + what)
