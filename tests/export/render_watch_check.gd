extends SceneTree

## render_watch_check - an export never saves stills as the show (RenderWatch, Exporter.is_short, Exporter.read_display_check).
##
##   godot --headless --path . --script res://tests/export/render_watch_check.gd
##
## The True Tarot export of 2026-11-23 is replayed from its own numbers: Movie Maker wrote 53,811 frames at 60 fps, Godot drew
## 3,468 of them, everything after 0:56 a copy of the last frame drawn - and the exporter's whole test of it was "the MP4 is
## over 4 KB". The control is that test, which passes it.

const FPS := 60
const DT := 1.0 / FPS

var _fails := 0


func _init() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + what)
	if not cond:
		_fails += 1


func _run() -> void:
	_drawing()
	_incident()
	_sparse()
	_fault_file()
	_short()
	_display()
	print("render_watch_check: %s" % ("ALL OK" if _fails == 0 else "%d FAILED" % _fails))
	quit(1 if _fails > 0 else 0)


## Feed [param w] a run of iterations: [param drawn_each] true draws every one, false draws none. Returns the frame (0-based,
## from [param from]) the watch fired on, -1 if it did not.
func _feed(w: RenderWatch, count: int, drawn_each: bool, state: Dictionary) -> int:
	var fired := -1
	for i in count:
		if drawn_each:
			state["drawn"] = int(state["drawn"]) + 1
		state["t"] = float(state["t"]) + DT
		if w.step(int(state["drawn"]), DT, float(state["t"])) and fired < 0:
			fired = int(state["frame"])
		state["frame"] = int(state["frame"]) + 1
	return fired


func _drawing() -> void:
	print("render_watch_check: [a render that draws every frame]")
	var w := RenderWatch.new()
	var s := {"drawn": 0, "t": 0.0, "frame": 0}
	_ok(_feed(w, FPS * 600, true, s) < 0, "ten minutes drawn: never stopped")
	_ok(w.missed == 0.0 and w.first_at < 0.0, "nothing counted as missed")
	# the first call has nothing to compare with, so a count that has not started moving yet is not a miss
	var fresh := RenderWatch.new()
	_ok(not fresh.step(0, DT, 0.0) and fresh.missed == 0.0, "the first frame is never a miss")


func _incident() -> void:
	print("render_watch_check: [the 2026-11-23 export, replayed]")
	var w := RenderWatch.new()
	var s := {"drawn": 0, "t": 0.0, "frame": 0}
	var drawn_part := 56 * FPS               # 0:00 - 0:56 drawn
	_ok(_feed(w, drawn_part, true, s) < 0, "the first 56 s, drawn: not stopped")
	var fired := _feed(w, 53811 - drawn_part, false, s)
	var limit_frames := int(ceil(RenderWatch.LIMIT * FPS))
	_ok(fired == drawn_part + limit_frames - 1,
		"stopped %d frames into the stills (%.2f s), not 13:20 later (fired at frame %d)" % [limit_frames, RenderWatch.LIMIT, fired])
	_ok(absf(w.first_at - 56.0) < 2.0 * DT, "the stills are said to start at 0:56 (%.3f s)" % w.first_at)
	# fires once: the render quits on it
	var again := 0
	for i in 600:
		s["t"] = float(s["t"]) + DT
		if w.step(int(s["drawn"]), DT, float(s["t"])):
			again += 1
	_ok(again == 0, "and says so once")
	# the control: the exporter's old acceptance, a file over 4 KB, passed this 703 MB video
	_ok(703071572 > 4096, "control: the old test (an MP4 over 4 KB) passes the frozen video")


func _sparse() -> void:
	print("render_watch_check: [frames missed here and there]")
	# a window drawn once a second while hidden (a compositor's trickle of frame callbacks) is a slideshow, not the show
	var w := RenderWatch.new()
	var s := {"drawn": 0, "t": 0.0, "frame": 0}
	_feed(w, FPS, true, s)
	var fired := -1
	for sec in 10:
		var f := _feed(w, FPS - 1, false, s)
		if fired < 0 and f >= 0:
			fired = f
		_feed(w, 1, true, s)
	_ok(fired >= 0 and fired < 2 * FPS, "a drawn frame a second does not keep a render alive (stopped at frame %d)" % fired)
	# a handful scattered through a long render is below the limit
	var odd := RenderWatch.new()
	var o := {"drawn": 0, "t": 0.0, "frame": 0}
	var fired_odd := -1
	for k in int(RenderWatch.LIMIT * FPS) - 1:
		_feed(odd, FPS * 30, true, o)
		var f := _feed(odd, 1, false, o)
		if fired_odd < 0 and f >= 0:
			fired_odd = f
	_ok(fired_odd < 0, "%d single frames missed across a long render: not stopped" % (int(RenderWatch.LIMIT * FPS) - 1))


func _fault_file() -> void:
	print("render_watch_check: [the render's reason, handed to the exporter]")
	var path := ProjectSettings.globalize_path("user://render_watch_check_fault.txt")
	RenderWatch.clear_fault(path)
	_ok(RenderWatch.read_fault(path) == "", "nothing there before")
	RenderWatch.write_fault(path, "its window stopped drawing at 0:56 (on Wayland)\n")
	_ok(RenderWatch.read_fault(path) == "its window stopped drawing at 0:56 (on Wayland)", "read back whole")
	_ok(not FileAccess.file_exists(path + ".tmp"), "no half-written file left beside it")
	RenderWatch.clear_fault(path)
	_ok(RenderWatch.read_fault(path) == "" and not FileAccess.file_exists(path), "cleared before the next render")
	RenderWatch.write_fault("", "nowhere")
	_ok(RenderWatch.read_fault("") == "", "a render with no --fault-file writes nothing")


func _short() -> void:
	print("render_watch_check: [a video shorter than asked for]")
	var Ex: GDScript = load("res://src/export/exporter.gd")
	_ok(Ex.is_short(57.48, 896.81), "0:57 of 14:56 is short")
	_ok(not Ex.is_short(896.85, 896.81), "the incident's own length (896.85 of 896.81) is whole")
	_ok(not Ex.is_short(890.0, 896.81), "an encode a few seconds shy of a long take is whole (within 1%)")
	_ok(Ex.is_short(880.0, 896.81), "17 s shy of it is not")
	_ok(not Ex.is_short(28.5, 30.0) and Ex.is_short(27.5, 30.0), "a short take: 2 s of slack")
	_ok(not Ex.is_short(0.0, 30.0) and not Ex.is_short(10.0, 0.0) and not Ex.is_short(-1.0, 30.0), "a length not known is never short")


func _display() -> void:
	print("render_watch_check: [does a render draw on its display of its own]")
	var Ex: GDScript = load("res://src/export/exporter.gd")
	var ok: Dictionary = Ex.read_display_check(
		"Godot Engine v4.7.2\nghost: settings are READ-ONLY in this process (a render)\n"
		+ "ghost display: X11 | Intel(R) Iris(R) Xe Graphics (ADL GT2)\n", 0)
	_ok(bool(ok["ok"]) and ok["adapter"] == "Intel(R) Iris(R) Xe Graphics (ADL GT2)", "X11, and the card that draws it")
	# the laptop before the fix: X11 failed, Godot fell back to the desktop
	var fell: Dictionary = Ex.read_display_check("WARNING: Display driver x11 failed, falling back to wayland.\n"
		+ "ghost display: Wayland | Intel(R) Iris(R) Xe Graphics (ADL GT2)\n", 0)
	_ok(not bool(fell["ok"]) and str(fell["why"]).contains("Wayland"), "came up on Wayland: not working (%s)" % fell["why"])
	var died: Dictionary = Ex.read_display_check("MESA: info: vulkan: No DRI3 support detected - required for presentation\n"
		+ "ERROR: None of the devices supports both graphics and present queues.\n"
		+ "   at: initialize (servers/rendering/rendering_device.cpp:8364)\n", 1)
	_ok(not bool(died["ok"]) and str(died["why"]) == "None of the devices supports both graphics and present queues.",
		"no display at all: the first error is the reason (%s)" % died["why"])
	var hung: Dictionary = Ex.read_display_check("", 124)
	_ok(not bool(hung["ok"]) and str(hung["why"]).contains("did not answer"), "hung: timed out (%s)" % hung["why"])
	var mute: Dictionary = Ex.read_display_check("", 1)
	_ok(not bool(mute["ok"]) and str(mute["why"]).contains("exit 1"), "silent: how it ended (%s)" % mute["why"])
	# Setup's row, marked from an answer already had (no check run here)
	Ex.forget_display()
	var rows := [{"key": "xvfb", "name": "xvfb-run", "found": true, "version": "installed"}]
	Ex.mark_display(rows, false)
	_ok(rows[0]["version"] == "installed", "no answer yet, not asked to run: the row is left as it is")
