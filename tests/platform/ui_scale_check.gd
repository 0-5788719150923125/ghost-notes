extends Node

## ui_scale_check - the interface as large as the screen's pixels ask for (UiScale), and the window opened maximized
## where three quarters of the screen is smaller than the interface (Boot.maximizes).
##
##   tests/run_boot_probe.sh tests/platform/ui_scale_check.gd 60
##
## Holds, in numbers (nothing is drawn):
##   - a 14-inch 1920x1200 laptop (161 DPI), maximized (1920x1126): a unit drawn at its DPI over REF_DPI, the canvas
##     no smaller than LEAST;
##   - a 4K screen's window of three quarters, and its whole screen, are drawn as they always were (the control: the
##     stretch alone already draws a unit that large);
##   - a desktop monitor's DPI asks for no more than a pixel a unit; a DPI that says nothing true (0, a TV's
##     placeholder) leaves the laptop a unit a unit;
##   - a small window at the laptop's DPI is held to LEAST; the person's zoom multiplies, within LEAST and never
##     under half;
##   - a read-only process (this one) watches nothing, and a step there changes nothing and says nothing;
##   - the window opens maximized on the laptop (X11's free area and Wayland's whole screen), a 1080p and a 1440p
##     screen, and at three quarters on a 4K and a 5K one.

var _fails: Array = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var laptop := Vector2(1920, 1126)
	var f := UiScale.factor_for(laptop, 161, 1.0)
	_ok(absf(f - 161.0 / UiScale.REF_DPI) < 0.01, "the laptop: a unit at its DPI over %d (%.3f)" % [UiScale.REF_DPI, f])
	_ok(laptop.x / f >= UiScale.LEAST.x - 0.5 and laptop.y / f >= UiScale.LEAST.y - 0.5,
		"...its canvas %s no smaller than %s" % [laptop / f, UiScale.LEAST])
	var three_quarters := UiScale.factor_for(Vector2(2880, 1587), 163, 1.0)
	_ok(absf(three_quarters - 1.0) < 0.02, "a 4K screen's window of three quarters is drawn as it was (%.3f)" % three_quarters)
	_ok(is_equal_approx(UiScale.factor_for(Vector2(3840, 2160), 163, 1.0), 1.0), "...and its whole screen")
	var monitor := Vector2(1920, 1050)
	var fm := UiScale.factor_for(monitor, 92, 1.0)
	_ok(is_equal_approx(UiScale.stretch(monitor) * fm, 1.0),
		"a 24-inch 1080p monitor, maximized: a unit a pixel, its DPI asking no more (factor %.3f over a stretch of %.3f)"
		% [fm, UiScale.stretch(monitor)])
	_ok(is_equal_approx(UiScale.factor_for(laptop, 0, 1.0), 1.0) and is_equal_approx(UiScale.factor_for(laptop, 900, 1.0), 1.0),
		"a DPI that says nothing true: a unit a unit")
	var small := Vector2(960, 600)
	var fs := UiScale.factor_for(small, 161, 1.0)
	var canvas := small / (UiScale.stretch(small) * fs)
	_ok(canvas.x >= UiScale.LEAST.x - 0.5 and canvas.y >= UiScale.LEAST.y - 0.5 and fs > 1.0,
		"a small window at the laptop's DPI is held to %s (canvas %s, factor %.3f)" % [UiScale.LEAST, canvas, fs])
	_ok(absf(UiScale.factor_for(laptop, 161, 0.8) - 0.8 * 161.0 / UiScale.REF_DPI) < 0.01, "the zoom multiplies (0.8)")
	_ok(is_equal_approx(UiScale.factor_for(laptop, 161, 2.0), UiScale.most(laptop)), "...within LEAST (2.0 is held to %.3f)" % UiScale.most(laptop))
	_ok(is_equal_approx(UiScale.factor_for(Vector2(3840, 2160), 163, 0.1), 0.5), "...and never under half")
	_ok(not UiScale.watch(get_window()) and UiScale.window() == null, "a read-only process watches nothing")
	var was := get_window().content_scale_factor
	_ok(UiScale.step(1).is_empty() and is_equal_approx(get_window().content_scale_factor, was),
		"...and a step there changes nothing and says nothing")
	_ok(Boot.maximizes(Vector2i(1920, 1154)) and Boot.maximizes(Vector2i(1920, 1200)),
		"the laptop opens maximized (X11's free area, Wayland's whole screen)")
	_ok(Boot.maximizes(Vector2i(1920, 1040)) and Boot.maximizes(Vector2i(2560, 1396)), "...a 1080p and a 1440p screen too")
	_ok(not Boot.maximizes(Vector2i(3840, 2116)) and not Boot.maximizes(Vector2i(5120, 2836)),
		"a 4K and a 5K screen open at three quarters")
	if _fails.is_empty():
		print("ui_scale_check: ALL OK")
		get_tree().quit(0)
		return
	print("ui_scale_check: %d FAILURE(S)" % _fails.size())
	for m in _fails:
		print("   ", m)
	get_tree().quit(1)


func _ok(cond: bool, msg: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + msg)
	if not cond:
		_fails.append(msg)
