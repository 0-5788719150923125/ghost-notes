extends SceneTree

## timeline_lanes_check - A STAGE ENTRY'S SPANS ON MASKING'S CONTROLS ([TimelineLanes], [TrackLane], [FlagStrip]; Ctrl+wheel zooms
## from any lane, a plain wheel left to the list of lanes;
## next/editing.md, "The Timeline").
##
##   godot --headless --path . --script res://tests/timeline/timeline_lanes_check.gd
##
## What it holds, on a made track (the showcase's own shape: a window for one actor, a moment for another):
##   - a window is a lane of its own and a moment a flag on the strip, all on one view;
##   - ITS LEFT EDGE TRIMMED, its start moves and its end stays; ITS BODY MOVED, both move by as much - each one `retimed` as the
##     gesture ends. THE CONTROL: a press with no drag (a pick) retimes nothing, and says `picked`;
##   - a flag dragged is retimed to where it was let go, start and end the same;
##   - the strip scrubbed says the moment, and a double click on it asks for a new moment there;
##   - a span's window as written: a window's two ends, a moment's one twice.

var _fails := 0
var _retimed: Array = []
var _picked: Array = []


func _initialize() -> void:
	var lanes := TimelineLanes.new()
	lanes.size = Vector2(800, 200)
	root.add_child(lanes)
	lanes.retimed.connect(func(i: int, a: float, b: float) -> void: _retimed.append([i, snappedf(a, 0.001), snappedf(b, 0.001)]))
	lanes.picked.connect(func(i: int) -> void: _picked.append(i))
	var asked: Array = []
	lanes.wanted.connect(func(actor: String, at: float) -> void: asked.append([actor, at]))
	var scrubbed: Array = []
	lanes.scrubbed.connect(func(t: float) -> void: scrubbed.append(t))
	lanes.set_track(["blue", "red"], [{"from": 0.2, "to": 2.4, "action": "arrive", "target": "blue"},
		{"at": 1.0, "action": "blink", "target": "red"}], 3.0)
	var rows: Array = lanes._rows
	_ok(rows.size() == 1 and lanes._flags.size() == 1 and (rows[0]["lane"] as TrackLane).tview == lanes._strip.tview,
		"a window is a lane, a moment a flag on the strip, all on one view (%d lanes, %d flags)" % [rows.size(), lanes._flags.size()])
	var lane: TrackLane = rows[0]["lane"]
	var m: Dictionary = rows[0]["m"]

	# THE CONTROL: a pick, no drag
	lane.gui_input.emit(_press(true))
	_ok(_retimed.is_empty() and _picked == [0], "a press with no drag retimes nothing, and picks the span")

	# the left edge trimmed by 0.3: what TrackLane's "in" drag writes on a movable lane
	lane.drag_started.emit()
	lane.set_in.call(float(m["in"]) + 0.3)
	lane.set_offset.call(float(m["off"]) + 0.3)
	lane.drag_ended.emit()
	_ok(_retimed.back() == [0, 0.5, 2.4], "its left edge trimmed, its start moves and its end stays: %s" % str(_retimed.back()))
	# its body moved by 0.5
	lanes.set_track(lanes.actors, [{"from": 0.5, "to": 2.4, "action": "arrive", "target": "blue"}, lanes.spans[1]], 3.0)
	lane = lanes._rows[0]["lane"]
	m = lanes._rows[0]["m"]
	lane.drag_started.emit()
	lane.set_offset.call(float(m["off"]) + 0.5)
	lane.drag_ended.emit()
	_ok(_retimed.back() == [0, 1.0, 2.9], "its body moved, both ends move by as much: %s" % str(_retimed.back()))

	# a flag dragged to 1.8 and let go
	var flag: Dictionary = lanes._flags[0]
	lanes._strip.marker_picked.emit(flag)
	lanes._strip.marker_drag_started.emit(flag)
	flag["time"] = 1.8
	lanes._strip.gui_input.emit(_press(false))
	_ok(_retimed.back() == [1, 1.8, 1.8] and _picked.back() == 1, "a flag dragged is retimed where it was let go: %s" % str(_retimed.back()))

	lanes._strip.scrubbed.emit(1.25)
	_ok(scrubbed == [1.25], "the strip scrubbed says the moment: %s" % str(scrubbed))
	var dbl := _press(true)
	dbl.double_click = true
	dbl.position = Vector2(400, 40)
	lanes._strip.gui_input.emit(dbl)
	_ok(asked.size() == 1 and String(asked[0][0]) == "" and float(asked[0][1]) >= 0.0 and float(asked[0][1]) <= 3.0,
		"a double click on the strip asks for a new moment there: %s" % str(asked))
	_ok(TimelineLanes.window_of({"from": 1, "to": 2}) == [1.0, 2.0] and TimelineLanes.window_of({"at": 0.5}) == [0.5, 0.5],
		"a span's window as written")
	# THE TRACK'S KEYS ([StageKeys]): Masking's markers on the strip - a ramp's span before it, a damp's after - dragged to retime
	var keyed: Array = []
	lanes.key_retimed.connect(func(k: int, at: float) -> void: keyed.append([k, snappedf(at, 0.001)]))
	lanes.set_keys([{"field": "camera.fov", "at": 2.0, "to": 30, "over": 0.5, "ease": "ramp"},
		{"field": "camera.eye", "at": 1.0, "to": [0, 1, 2], "over": 0.5, "ease": "damp"}])
	var ks: Array = lanes._keys
	var fov: Dictionary = ks.filter(func(k: Dictionary) -> bool: return String(k["label"]) == "camera.fov")[0]
	var eye: Dictionary = ks.filter(func(k: Dictionary) -> bool: return String(k["label"]) == "camera.eye")[0]
	_ok(ks.size() == 2 and int(fov["kind"]) == 0 and (fov["tint"] as Vector2).is_equal_approx(Vector2(1.5, 2.0))
		and int(eye["kind"]) == 1 and (eye["tint"] as Vector2).is_equal_approx(Vector2(1.0, 1.5)),
		"keys are markers on the strip: a ramp's seconds before it, a damp's after")
	var n_picked := _picked.size()
	lanes._strip.marker_picked.emit(fov)
	lanes._strip.marker_drag_started.emit(fov)
	fov["time"] = 2.6
	lanes._strip.gui_input.emit(_press(false))
	_ok(keyed == [[0, 2.6]] and _picked.size() == n_picked, "a key dragged is retimed by its own index, and picks no span: %s" % str(keyed))
	# CTRL+WHEEL ZOOMS FROM ANY LANE (the user, 2026-11-11: only the bottom one did) - THE CONTROL a plain wheel over a lane leaves
	# the zoom as it was, for the list of lanes to scroll
	var a_lane: TrackLane = lanes._rows[0]["lane"]
	var notch := InputEventMouseButton.new()
	notch.button_index = MOUSE_BUTTON_WHEEL_UP
	notch.pressed = true
	notch.position = Vector2(40.0, 8.0)
	var before := lanes._view.zoom
	a_lane._gui_input(notch)
	var plain := lanes._view.zoom
	notch.ctrl_pressed = true
	a_lane._gui_input(notch)
	_ok(is_equal_approx(plain, before) and lanes._view.zoom > before, "Ctrl+wheel over a lane zooms (%.2fx); the control: a plain wheel leaves it (%.2fx)" % [lanes._view.zoom, plain])
	lanes.queue_free()
	if _fails == 0:
		print("timeline_lanes_check: ALL OK")
		quit(0)
		return
	print("timeline_lanes_check: %d FAILED" % _fails)
	quit(1)


func _press(down: bool) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	return e


func _ok(cond: bool, msg: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + msg)
	if not cond:
		_fails += 1
