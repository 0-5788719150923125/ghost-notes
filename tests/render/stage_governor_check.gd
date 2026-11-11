extends SceneTree

## stage_governor_check - how often the stage is drawn while a scene is heavy ([StageGovernor]).
##   godot --headless --path . --script res://tests/render/stage_governor_check.gd
##
## Frames are played to it as `main._process` plays them - what the frame before cost the app's thread, and how long it
## took in all - at a 160 Hz display's pace: a frame the stage ran in takes the scene's time, the others a refresh.
##
## A HEAVY SCRIPT IS SPACED OUT, AND STAYS SO: a scene costing the thread 111 ms a frame (a terrain) climbs to one frame
## in six and is held there, since its own frames read heavy at every level; a light scene is never touched; one long
## frame (a scene's build) costs one level for a couple of seconds, no more. It lets go a level at a time once the scene
## is light, and at once on a scene cut.
##
## A STAGE THE GRAPHICS CARD IS SLOW WITH IS LEFT ALONE, AND SAID (2026-11-11): frames 25 ms apart of which the thread
## spends 4 never change the level, and [member StageGovernor.slow_elsewhere] says so. THE CONTROL is the governor as it
## was, handed the whole frame's time: on the trace the app's log of 2026-11-10 holds (25 ms a frame drawn every frame;
## 9 ms once it is drawn every other, the card's work waited for in the frames between) it changes level again and
## again - the hunting that was seen as constant hitching. And a frame slow on the thread itself is not "elsewhere".

const REFRESH := 1.0 / 160.0

var _fails: Array = []


func _initialize() -> void:
	_heavy()
	_light()
	_one_long_frame()
	_card_bound()
	if _fails.is_empty():
		print("stage_governor_check: ALL OK")
		quit(0)
		return
	print("stage_governor_check: %d FAILURE(S)" % _fails.size())
	for f in _fails:
		print("   ", f)
	quit(1)


func _ok(cond: bool, msg: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + msg)
	if not cond:
		_fails.append(msg)


## Plays [param seconds] to [param g]: [param own] is what a frame the stage runs in costs the thread at the level it
## is at (ms; a Callable of the level), [param wait] what such a frame waits for besides (ms). A frame it does not run
## in costs the thread 1 ms and takes a refresh. [param whole] hands it the whole frame's time, as the governor was
## before. Returns {changes, most, least, active, frames}.
func _play(g: StageGovernor, seconds: float, own: Callable, wait: Callable, whole := false) -> Dictionary:
	var out := {"changes": 0, "most": g.level, "least": g.level, "active": 0, "frames": 0}
	var t := 0.0
	var own_ms := 0.0
	var delta := REFRESH
	while t < seconds:
		if g.step(delta * 1000.0 if whole else own_ms, delta):
			out["changes"] += 1
		out["most"] = maxi(out["most"], g.level)
		out["least"] = mini(out["least"], g.level)
		out["frames"] += 1
		# ...the frame that now runs: its cost is what the next step is handed
		if g.active:
			out["active"] += 1
			own_ms = float(own.call(g.level))
			delta = maxf(REFRESH, (own_ms + float(wait.call(g.level))) / 1000.0)
		else:
			own_ms = 1.0
			delta = REFRESH
		t += delta
	return out


func _flat(ms: float) -> Callable:
	return func(_level: int) -> float: return ms


func _heavy() -> void:
	print("-- a heavy script is spaced out")
	var g := StageGovernor.new()
	var r := _play(g, 20.0, _flat(111.0), _flat(1.0))
	var top := StageGovernor.PERIODS.size() - 1
	_ok(g.level == top and r["changes"] == top, "111 ms a frame climbs to one frame in %d and is held there (level %d, %d changes)"
		% [int(StageGovernor.PERIODS[top]), g.level, r["changes"]])
	_ok(not g.slow_elsewhere, "and is not called slow for anything but the thread")
	var held := _play(g, 10.0, _flat(111.0), _flat(1.0))
	_ok(held["changes"] == 0 and absf(float(held["frames"]) / float(held["active"]) - float(StageGovernor.PERIODS[top])) < 0.2,
		"there the stage runs one frame in six (%d of %d)" % [held["active"], held["frames"]])
	# it lets go a level at a time, once the scene is light
	var freed := _play(g, 12.0, _flat(5.0), _flat(1.0))
	_ok(g.level == 0 and freed["changes"] == top, "light again, it comes down a level at a time (%d changes, to level %d)" % [freed["changes"], g.level])
	# ...and at once on a cut
	_play(g, 10.0, _flat(111.0), _flat(1.0))
	_ok(g.level == top and g.cut() and g.level == 0 and g.active and g.cost == 0.0, "a scene cut lets go at once, and the next scene is measured afresh")
	_ok(not g.cut(), "a cut with nothing held changes nothing")


func _light() -> void:
	print("-- a light scene is never touched")
	var g := StageGovernor.new()
	var r := _play(g, 20.0, _flat(9.0), _flat(1.0))
	_ok(r["changes"] == 0 and r["active"] == r["frames"], "9 ms a frame runs every frame (%d changes)" % r["changes"])
	var mid := _play(StageGovernor.new(), 20.0, _flat(19.0), _flat(1.0))
	_ok(mid["changes"] == 0, "and so does 19 ms: neither heavy nor light")


func _one_long_frame() -> void:
	print("-- one long frame is not a heavy scene")
	# (a second into a light scene: a change of level waits [constant StageGovernor.CHANGE_EVERY] after the last)
	var g := StageGovernor.new()
	var n := [0]
	var r := _play(g, 8.0, func(_level: int) -> float:
		n[0] += 1
		return 300.0 if n[0] == 160 else 5.0, _flat(1.0))
	_ok(r["most"] == 1 and g.level == 0 and r["changes"] == 2, "a 300 ms frame costs one level, and it is given back (most %d, %d changes)" % [r["most"], r["changes"]])


func _card_bound() -> void:
	print("-- a stage the card is slow with is left alone")
	# 25 ms a frame of which the thread spends 4, as long as the stage is drawn every frame...
	var g := StageGovernor.new()
	var r := _play(g, 60.0, _flat(4.0), _flat(21.0))
	_ok(r["changes"] == 0 and r["most"] == 0, "frames 25 ms apart, 4 of them the thread's: the level never changes (%d changes in a minute)" % r["changes"])
	_ok(g.slow_elsewhere and g.whole > StageGovernor.HEAVY_MS and g.cost < StageGovernor.GOOD_MS,
		"and it is said: slow, and not for the thread's sake (%.0f ms a frame, %.0f of them its own)" % [g.whole, g.cost])
	# THE CONTROL: the same governor handed the whole frame, as it was - on the trace the log holds, where the card's work is
	# waited for in the frames between once the stage is drawn every other one, so the stage's own frames read 9 ms
	var was := StageGovernor.new()
	var hunted := _play(was, 60.0, _flat(4.0), func(level: int) -> float: return 21.0 if level == 0 else 5.0, true)
	_ok(hunted["changes"] >= 20 and hunted["most"] >= 1, "CONTROL: handed the whole frame's time it hunts (%d changes in a minute, to level %d)"
		% [hunted["changes"], hunted["most"]])
	# ...and a frame slow on the thread itself is the thread's
	var own := StageGovernor.new()
	_play(own, 10.0, _flat(40.0), _flat(1.0))
	_ok(own.level > 0 and not own.slow_elsewhere, "a frame slow on the thread itself is spaced out, never called the card's")
