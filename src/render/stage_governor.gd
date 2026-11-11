extends RefCounted
class_name StageGovernor

## StageGovernor - how often the stage is drawn while a scene is heavy ON THE APP'S OWN THREAD: the scene's rate is
## given up, never the UI's.
##
## WHY (2026-07-27): the engine runs one loop - input, every node's `_process` and `_draw`, then the frame handed to the
## renderer - and the UI composites in that loop, so a scene that spends 300 ms of script in a frame holds every click
## for 300 ms. Short of rewriting the scene the only lever is SPACING those frames out: at level L the stage is
## processed and drawn one frame in [constant PERIODS][L], and the UI runs between them. The scenes get slower; the
## instrument stays playable. Whoever owns the stage sets its modes from [member level] and [member active]
## (`main._process`); an export never asks, since a slow frame costs a render only time.
##
## WHAT IT READS IS THIS THREAD'S OWN TIME ON A FRAME THE STAGE RAN IN: from the frame's first `_process` to the moment
## it is handed to the renderer - script and `_draw`, nothing waited for. Only such frames are read: the blended rate is
## a lie while throttling (the skipped frames are cheap, the average looks healthy, and it released straight back into
## the wall - 7 fps, level 2, "86 fps", level 0, 7 fps, forever), where a heavy scene's own frame reads heavy at any level.
##
## IT READ THE WHOLE FRAME BEFORE (`delta`), AND THAT IS ALSO THE GRAPHICS CARD'S TIME AND THE DISPLAY'S, which do not
## behave as a script does (2026-11-11). A table's frames were 25 ms apart with its thread busy for 5 of them: the rest
## was waited for (the card or the processor shared with other work - which is not established). It read heavy and was
## throttled; drawn every other frame, what is waited for falls in a frame the stage did not run in, so the stage's own
## frames read 6 to 14 ms; it was released, met the same 25 ms and was throttled again. The app's log of 2026-11-10 has
## 185 changes of level in one session with a table up, and the picture's rate changed with each: "near-constant
## hitching". Spacing out frames the thread is not busy in buys the UI nothing, so such frames are left alone and said
## once ([member slow_elsewhere]). A light frame also reads light now at any display's rate: at 60 Hz the whole frame
## is never under [constant GOOD_MS], and only a scene cut released.
##
## WHAT IT DOES NOT SEE: the renderer's own processor time for the stage (0.7 ms for a table). A scene of very many
## canvas commands that costs little in script and much in the renderer would go unthrottled: measure before assuming.
##
## TRIED AND LEFT OUT: a deeper level than one frame in 6 (a freeze-frame read as a broken scene - the picture repainted
## and nothing moved); and drawing the stage smaller by level (every change REALLOCATED its target while the backdrop
## sampled it: black triangles, banding, uninitialized color on every heavy scene's entry). How many pixels the stage
## has is chosen, never governed ([code]Graphics[/code]'s Resolution row).

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
## FRAMES ARE SLOW AND THIS THREAD IS NOT WHY: the whole frame heavy and this thread's share of it light, for
## [constant GOOD_FOR] seconds. Nothing is throttled for it.
var slow_elsewhere := false
var _good_t := 0.0
var _change_t := 0.0
var _slow_t := 0.0
var _frame := 0


## A FRAME BEGINS. [param own_ms] is what the frame before cost this thread, [param delta] the seconds it took in all.
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


## A SCENE CUT: what the last scene cost is forgotten, and the stage runs every frame until the new one is measured -
## a light scene after a heavy one stayed held for the 15 s its sparse samples needed to forgive. Returns whether that
## changed the level.
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
