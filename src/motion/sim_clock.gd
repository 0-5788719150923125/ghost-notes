extends RefCounted
class_name SimClock

## SimClock - a fixed-rate tick accumulator for scenes that run a SIMULATION.
##
## A scene that advances a state (sand settling, cloth relaxing, a flock steering) cannot work per [code]update()[/code]
## call, which runs at very different rates:
##
##   Per frame, variably: [Director] sub-steps the sim in fixed chunks and may run up to [code]MAX_SIM_STEPS[/code]
##   (15) of them in one drawn frame while catching up (director.gd's SIM_STEP / MAX_SIM_STEPS).
##
##   Many times before the first frame: every new scene is pre-warmed so its opening frame is already settled.
##
##   Up to 240 times at once: an [Echo] re-localization can fast-forward seconds of update() calls in one frame.
##
## So a simulation advances on wall-clock time at its own fixed rate, with a hard ceiling on how much of it one call
## may run. Surplus time is dropped, not banked: a sim that has fallen behind carries on from where it is.
##
## Usage:
## [codeblock]
## var _sim := SimClock.new(60.0)          # 60 sim ticks per second
##
## func update(f: AudioFeatures, delta: float) -> void:
##     for _i in _sim.ticks(delta):
##         _step(_sim.dt)                  # one generation, always the same dt
## [/codeblock]
##
## [member dt] is constant: a solver tuned at one timestep is not tuned at another, so everything downstream
## integrates at exactly one rate.

## Ticks per second. 60 suits contact/relaxation solvers; 20-30 suffices for a cellular automaton.
var rate := 60.0

## The fixed timestep every tick represents. Read this inside the step, never `delta`.
var dt := 1.0 / 60.0

## Hard ceiling on ticks emitted from one [method ticks] call, the guard against the pre-warm and the Echo
## fast-forward.
var max_per_call := 3

## Total ticks this clock has ever emitted: a stable integer clock (an automaton's generation count).
var generation := 0

var _acc := 0.0


func _init(rate_ := 60.0, max_per_call_ := 3) -> void:
	rate = maxf(1.0, rate_)
	dt = 1.0 / rate
	max_per_call = maxi(1, max_per_call_)


## How many fixed steps to run for this much elapsed time. Call once per update and loop over the result; the surplus
## past [member max_per_call] is discarded, not carried.
func ticks(delta: float) -> int:
	# A negative or absurd delta is not a real elapsed time (a paused tab, a debugger, a clock correction): no time.
	if delta <= 0.0 or delta > 1.0:
		delta = clampf(delta, 0.0, dt)
	_acc += delta
	var n := int(_acc / dt)
	if n <= 0:
		return 0
	if n > max_per_call:
		n = max_per_call
		_acc = 0.0                      # drop the surplus; do NOT bank it
	else:
		_acc -= float(n) * dt
	generation += n
	return n


## Discard any accumulated time without emitting ticks, for a scene handed a discontinuity it should not simulate
## through (a morph hand-off, a storyboard seek).
func skip() -> void:
	_acc = 0.0


## Seconds of simulated time this clock has produced: independent of frame rate and identical between a live session
## and an export.
func elapsed() -> float:
	return float(generation) * dt
