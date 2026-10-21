extends SceneTree

## timeline_kit_check - ONE TIMELINE KIT ([TimelineView], [Clock]; next/structure.md, step 26). Masking's
## marker strip and track lanes, the storyboard's strip and a stage entry's lanes each kept their own
## ruler ladder, wheel, playhead and clock text, and the copies had parted (two pan steps, a clock with
## no hours, two ladders). Now:
##
##   godot --headless --path . --script tests/timeline/timeline_kit_check.gd
##
##   - THE RULER: the step is the first of the ladder that fits the ticks asked for - finer as a view
##     zooms in - and the ticks are that far apart, across exactly what is in view;
##   - THE WHEEL: Ctrl zooms about the pointer, keeping the time under it where it was; a plain notch pans
##     a tenth of the window; anything else moves nothing;
##   - THE CLOCK: m:ss, h:mm:ss past an hour, a negative time at 0:00;
##   - NO COPIES: no timeline handles the wheel itself, and nothing in src/ writes a clock's format but
##     [Clock] - against a made-up source that does, which the same scan must catch (the control).

## What may write the clock's digits all the same: a time of day is not a length.
const NOT_CLOCKS := {"media/tablet.gd": "the tablet's status bar shows the time of day, not how long something runs"}
const TIMELINES := ["res://src/masking/mask_timeline.gd", "res://src/masking/track_lane.gd",
	"res://src/timeline/storyboard_strip.gd", "res://src/timeline/storyboard_lanes.gd"]

var _fails := 0


func _initialize() -> void:
	print("the ruler")
	_ok(TimelineView.step_for(600.0, 14.0) == 60.0 and TimelineView.step_for(6.0, 14.0) == 0.5,
		"ten minutes in view ticks each minute, six seconds each half second")
	var fits := 0
	var first := 0
	for span in [3.0, 17.0, 95.0, 400.0, 2400.0]:
		for most in [6.0, 14.0, 30.0]:
			var st := TimelineView.step_for(span, most)
			fits += 1 if span / st <= most or st == float(TimelineView.STEPS[-1]) else 0
			var i := TimelineView.STEPS.find(st)
			first += 1 if i == 0 or span / float(TimelineView.STEPS[i - 1]) > most else 0
	_ok(fits == 15 and first == 15, "the step is the first rung that fits (%d of 15 fit, %d of 15 the first)" % [fits, first])
	var v := TimelineView.new()
	v.width = 800.0
	v.refresh(120.0)
	v.zoom_at(400.0, 4.0)
	var ticks := v.ticks(5.0)
	var spaced := ticks.size() > 1
	for j in range(1, ticks.size()):
		spaced = spaced and is_equal_approx(ticks[j] - ticks[j - 1], 5.0)
	_ok(spaced and ticks[0] >= v.view_start and ticks[0] - v.view_start < 5.0 and ticks[-1] < v.view_start + v.visible_span(),
		"the ticks are a step apart across exactly what is in view (%d, from %.1f in %.1f..%.1f)"
		% [ticks.size(), ticks[0], v.view_start, v.view_start + v.visible_span()])
	_ok(TimelineView.tick_label(65.0, 5.0) == "1:05" and TimelineView.tick_label(2.5, 0.5) == "2.5",
		"a tick is labeled by the clock, in tenths under a second")

	print("the wheel")
	var w := TimelineView.new()
	w.width = 800.0
	w.refresh(120.0)
	var under := w.t_of(600.0)
	_ok(w.wheel(_notch(MOUSE_BUTTON_WHEEL_UP, true, 600.0)) and is_equal_approx(w.zoom, TimelineView.WHEEL_ZOOM)
		and absf(w.t_of(600.0) - under) < 0.001, "Ctrl zooms in about the pointer, the time under it kept (%.2f)" % w.t_of(600.0))
	var at := w.view_start
	var span := w.visible_span()
	_ok(w.wheel(_notch(MOUSE_BUTTON_WHEEL_UP, false, 600.0)) and is_equal_approx(at - w.view_start, span * TimelineView.WHEEL_PAN),
		"a plain notch pans a tenth of the window")
	at = w.view_start
	_ok(not w.wheel(_notch(MOUSE_BUTTON_LEFT, false, 600.0)) and w.view_start == at, "a click is not the wheel's")

	print("the clock")
	_ok(Clock.text(0.0) == "0:00" and Clock.text(65.4) == "1:05" and Clock.text(3725.0) == "1:02:05" and Clock.text(-3.0) == "0:00",
		"m:ss, h:mm:ss past an hour, nothing below zero")

	print("no copies")
	var wheels: PackedStringArray = []
	for p in TIMELINES:
		if _handles_wheel(FileAccess.get_file_as_string(p)):
			wheels.append(String(p).get_file())
	_ok(wheels.is_empty(), "no timeline handles the wheel itself (%s)" % ", ".join(wheels))
	var clocks: PackedStringArray = []
	for p in _scripts("res://src"):
		if p != "res://src/data/clock.gd" and not NOT_CLOCKS.has(p.trim_prefix("res://src/")) \
				and _writes_clock(FileAccess.get_file_as_string(p)):
			clocks.append(p.trim_prefix("res://src/"))
	_ok(clocks.is_empty(), "nothing writes a clock's format but Clock (%s)" % ", ".join(clocks))
	_ok(_handles_wheel("if mb.button_index == MOUSE_BUTTON_WHEEL_UP:\n\tview.pan(-0.1)")
		and _writes_clock('return "%d:%02d" % [s / 60, s % 60]'), "the control: the scans catch a copy")

	print("timeline_kit_check: %s" % ("ALL OK" if _fails == 0 else "%d FAILED" % _fails))
	quit(0 if _fails == 0 else 1)


func _ok(cond: bool, what: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + what)
	if not cond:
		_fails += 1


func _notch(button: MouseButton, ctrl: bool, x: float) -> InputEventMouseButton:
	var mb := InputEventMouseButton.new()
	mb.button_index = button
	mb.pressed = true
	mb.ctrl_pressed = ctrl
	mb.position = Vector2(x, 10.0)
	return mb


## Code (comments aside) that reads the wheel's buttons itself.
func _handles_wheel(text: String) -> bool:
	return _code(text).contains("MOUSE_BUTTON_WHEEL_")


## Code that writes the clock's minutes-and-seconds format itself.
func _writes_clock(text: String) -> bool:
	return _code(text).contains("%d:%02d")


func _code(text: String) -> String:
	var out: PackedStringArray = []
	for line in text.split("\n"):
		var i := line.find("#")
		out.append(line if i < 0 else line.substr(0, i))
	return "\n".join(out)


func _scripts(dir: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_scripts(dir.path_join(d)))
	return out
