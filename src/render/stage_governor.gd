extends RefCounted
class_name StageGovernor

## StageGovernor - how often the stage is drawn while a scene is heavy on the app's own thread: the scene's rate is
## given up, never the UI's.
##
## The engine runs one loop (input, every node's `_process` and `_draw`, then the frame handed to the renderer) and the
## UI composites in it, so a scene that spends 300 ms of script in a frame holds every click for 300 ms. The lever is
## spacing those frames out: at level L the stage is processed and drawn one frame in [constant PERIODS][L], and the UI
## runs between them. Whoever owns the stage sets its modes from [member level] and [member active] (`main._process`);
## an export never asks, since a slow frame costs a render only time.
##
## It reads this thread's own time on a frame the stage ran in: from the frame's first `_process` to the moment it is
## handed to the renderer (script and `_draw`, nothing waited for). Only such frames are read: the blended rate is
## misleading while throttling (the skipped frames are cheap, so the average looks healthy and it releases straight
## back into the wall). The whole frame (`delta`) is not read either: it includes the graphics card's and the display's
## time, which are waited for, not this thread's. Throttling such frames buys the UI nothing and makes the level flap,
## so they are left alone and reported once ([member slow_elsewhere]). A light frame reads light at any display rate.
##
## It does not see the renderer's own processor time for the stage: a scene of very many canvas commands that costs
## little in script and much in the renderer goes unthrottled.
##
## There is no deeper level than one frame in 6 (a freeze-frame reads as a broken scene), and the stage is never drawn
## smaller by level (each change reallocates its target while the backdrop samples it). How many pixels the stage has
## is chosen, never governed ([code]Graphics[/code]'s Resolution row).

## The stage is processed and drawn one frame in this many, by level.
const PERIODS := [1, 2, 3, 6]
## A stage frame costing this thread more than this (ms) is heavy, and the level goes up...
const HEAVY_MS := 24.0
## ...and one under this, for [constant GOOD_FOR] seconds on end, light, and it comes down.
const GOOD_MS := 14.0
const GOOD_FOR := 2.0
## The least time between two changes of level (seconds).
const CHANGE_EVERY := 0.4

var level := 0
## Whether the stage runs in the frame [method step] was last called in.
var active := true
## What a frame the stage ran in costs this thread (ms), eased: quick to forgive, steady to accuse.
var cost := 0.0
## What such a frame took in all (ms), eased the same way: this thread's time and everything waited for.
var whole := 0.0
## Frames are slow and this thread is not why: the whole frame heavy and this thread's share of it light, for
## [constant GOOD_FOR] seconds. Nothing is throttled for it.
var slow_elsewhere := false
var _good_t := 0.0
var _change_t := 0.0
var _slow_t := 0.0
var _frame := 0


## A frame begins. [param own_ms] is what the frame before cost this thread, [param delta] the seconds it took in all.
## Returns whether the level changed; [member active] is then whether the stage runs in this frame.
func step(own_ms: float, delta: float) -> bool:
	if active:
		var frame_ms := delta * 1000.0
		# a scene's first frame is taken whole, so every scene is measured afresh (see [method cut])
		cost = own_ms if cost <= 0.0 else lerpf(cost, own_ms, 0.35 if own_ms < cost else 0.12)
		whole = frame_ms if whole <= 0.0 else lerpf(whole, frame_ms, 0.35 if frame_ms < whole else 0.12)
	_change_t += delta
	var want := level
	if cost > HEAVY_MS:
		_good_t = 0.0
		if level < PERIODS.size() - 1:
			want = level + 1
	elif cost < GOOD_MS:
		_good_t += delta
		if _good_t > GOOD_FOR and level > 0:
			want = level - 1
			_good_t = 0.0
	else:
		_good_t = 0.0
	var changed := want != level and _change_t > CHANGE_EVERY
	if changed:
		level = want
		_change_t = 0.0
	_slow_t = _slow_t + delta if level == 0 and whole > HEAVY_MS and cost < GOOD_MS else 0.0
	slow_elsewhere = _slow_t > GOOD_FOR
	_frame += 1
	active = level == 0 or _frame % int(PERIODS[level]) == 0
	return changed


## A scene cut: what the last scene cost is forgotten, and the stage runs every frame until the new one is measured
## (a light scene after a heavy one would stay held while its sparse samples forgive). Returns whether that changed the level.
func cut() -> bool:
	cost = 0.0
	whole = 0.0
	_good_t = 0.0
	_slow_t = 0.0
	slow_elsewhere = false
	if level == 0:
		return false
	level = 0
	_change_t = 0.0
	active = true
	return true
