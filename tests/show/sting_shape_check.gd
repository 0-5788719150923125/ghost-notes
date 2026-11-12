extends Node

## sting_shape_check - that a stinger punch is a move and not a discontinuity.
##
## Director._drive_stinger rides the SceneView pulse, so it reaches every scene. Its envelope must not be a
## step: `_sting = 1.0` on the beat edge read by the same frame's draw moves `pulse_zoom` from 1.00 to 1.20
## between two consecutive frames while a roll, a skew and a 1.5x brightness flash land in that frame.
## SceneView.commit exists so framing eases.
##
## The statistic: the largest change in the drawn zoom between two consecutive frames, in per-frame
## percent, at the largest kick the sampler can produce. A move the eye can follow is a few percent a
## frame; a step is the whole kick in one frame, and no decay afterwards makes the onset readable.
##
## Both rules are measured side by side (the old one as a shadow), so the threshold is proved: the check
## fails if the old rule does not trip it.
##
## The envelope is sampled through Director's own `_sting_env`, at the field values `_drive_stinger`
## writes, at a range of pulse periods (the span is sampled from the beat period, so a slow track is
## checked as well as a fast one).
##
## Run: tests/run_boot_probe.sh tests/show/sting_shape_check.gd 60

const FRAME := 1.0 / 60.0
## The largest zoom kick `_drive_stinger` can sample: the worst case. Read from the sampler's own range,
## so the gate cannot drift away from what ships.
const MAX_KICK := Director.STING_PUSH.y
## How much larger than the camera's ordinary travel a punch is allowed to be. Smoothness is necessary and
## not sufficient (a smooth punch of a fifth of the frame still reads as an explosion), so the amplitude is
## gated against the one number that says how far the camera moves when nothing special is happening. An
## accent may be larger than the ordinary travel, not a different order of thing.
const MAX_KICK_OVER_DRIFT := 2.0
## Per-frame zoom change, in percent of frame, that separates a move from a jump. A 60 Hz pan across the
## frame in a second is ~1.7%/frame; the eased camera (SceneView.smoothing = 5) covers 8% of its remaining
## error per frame. 5% is above both and far below a step.
const MAX_STEP_PCT := 5.0
## Pulse periods to sample: a fast track, the default until onsets are seen, and a slow one.
const PERIODS := [0.35, 0.5, 1.0, 2.0]

var _fails: Array = []


func _ready() -> void:
	var t_saved = Director._sting_t
	var span_saved = Director._sting_span

	for period in PERIODS:
		var span: float = clampf(float(period) * 0.55, 0.28, 0.7)
		var now := _walk_new(span)
		var was := _walk_old()
		print("sting_shape_check: period %.2fs  span %.2fs   new peak %.3f, max step %.2f%%/frame"
			% [period, span, now.peak, now.step])
		print("                                       old peak %.3f, max step %.2f%%/frame"
			% [was.peak, was.step])
		if now.step > MAX_STEP_PCT:
			_fails.append("period %.2fs: the punch still moves %.2f%% of frame in ONE frame (limit %.1f%%) - that is a jump, not a move"
				% [period, now.step, MAX_STEP_PCT])
		if was.step <= MAX_STEP_PCT:
			_fails.append("period %.2fs: the OLD step envelope measured %.2f%%/frame, under the limit - the threshold is not measuring what it claims to"
				% [period, was.step])
	# An envelope that overshoots would zoom past the sampled kick, and one that does not reach it is a
	# punch that never lands. The bar is 0.95 rather than 1.0 because this walks real 60 Hz frames: the
	# analytic peak sits at the attack/release join and only lands on a frame boundary by luck.
		if now.peak < 0.95 or now.peak > 1.0:
			_fails.append("period %.2fs: the drawn frames peak at %.3f of the kick" % [period, now.peak])
		if now.tail > 1e-6:
			_fails.append("period %.2fs: the envelope leaves %.6f behind - the frame never returns to the scene's own framing"
				% [period, now.tail])

	Director._sting_t = t_saved
	Director._sting_span = span_saved
	_check_pullback()
	_check_amplitude()

	if _fails.is_empty():
		print("sting_shape_check: ALL OK")
		get_tree().quit()
		return
	print("sting_shape_check: %d FAILURE(S)" % _fails.size())
	for f in _fails:
		print("   ", f)
	get_tree().quit(1)


## The other half of "explodes": a punch that pulls the camera back further than the picture is painted
## for. Layer-composed scenes hand their layers a half-extent of 1.15x the frame (GhostScene.update_layers),
## so the widest the camera may go is 1/1.15 of nominal, and the drift already spends part of that budget.
## The two multiply, the case the 1.15 was never sized for.
func _check_pullback() -> void:
	var widest: float = (1.0 - Director.DRIFT_PULL) * (1.0 - Director.STING_PULL.y)
	var painted: float = 1.0 / Director.LAYER_OVERDRAW
	print("sting_shape_check: widest camera %.4f of nominal, painted to %.4f (drift %.2f x pull %.2f)"
		% [widest, painted, Director.DRIFT_PULL, Director.STING_PULL.y])
	if widest < painted:
		_fails.append("a full pull-back punch on top of full drift opens the camera to %.4f of nominal, past the %.4f the layers are painted to - the frame's own edge comes into shot"
			% [widest, painted])
	# ...and the inward half is deliberately not bounded by it, so a regression that made them symmetric
	# again is caught here.
	if Director.STING_PULL.y >= Director.STING_PUSH.y:
		_fails.append("the outward kick (%.2f) is no smaller than the inward one (%.2f) - they are not symmetric and must not be made so"
			% [Director.STING_PULL.y, Director.STING_PUSH.y])


## The punch is an accent over the camera's own travel, not a different order of thing.
func _check_amplitude() -> void:
	var drift: float = Director.DRIFT_PULL
	var ratio: float = Director.STING_PUSH.y / drift
	print("sting_shape_check: largest kick %.3f against a %.3f ordinary drift - %.2fx"
		% [Director.STING_PUSH.y, drift, ratio])
	if ratio > MAX_KICK_OVER_DRIFT:
		_fails.append("the largest punch is %.2fx the camera's ordinary travel (limit %.1fx) - that is an explosion, however smoothly it arrives"
			% [ratio, MAX_KICK_OVER_DRIFT])
	# ...and a reading gets a fraction of even that: a scene under a chapter is a background.
	var reading: float = Director.STING_PUSH.y * Director.STING_READING
	print("sting_shape_check: over a reading, %.3f - %.2fx the drift" % [reading, reading / drift])
	if reading >= drift:
		_fails.append("a punch over a READING (%.3f) is no smaller than the camera's own drift (%.3f) - it is not a background at that size"
			% [reading, drift])
	# The floor of the range must stay a punch at all, or the softening has deleted it.
	if Director.STING_PUSH.x * Director.STING_READING < 0.005:
		_fails.append("the smallest punch over a reading is %.4f - that is not an accent, it is nothing"
			% (Director.STING_PUSH.x * Director.STING_READING))


## Walk the shipped envelope one 60 Hz frame at a time, through Director's own function.
func _walk_new(span: float) -> Dictionary:
	Director._sting_span = span
	Director._sting_t = 0.0
	var prev := 0.0
	var step := 0.0
	var peak := 0.0
	var t := 0.0
	# One extra frame past the span, so the return to neutral is part of the measurement.
	while t <= span + FRAME * 2.0:
		Director._sting_t = t if t < span else -1.0
		var p: float = Director._sting_env()
		peak = maxf(peak, p)
		step = maxf(step, absf(p - prev) * MAX_KICK * 100.0)
		prev = p
		t += FRAME
	return {"peak": peak, "step": step, "tail": prev}


## The rule this replaced, so the comparison is against the code that shipped: `_sting` snapped to 1.0 on
## the beat, decayed at 6/s, and the drawn envelope was its square.
func _walk_old() -> Dictionary:
	var s := 0.0
	var prev := 0.0
	var step := 0.0
	var peak := 0.0
	for i in 60:
		if i == 1:
			s = 1.0                      # the beat edge: one frame, no attack
		else:
			s = maxf(0.0, s - FRAME * 6.0)
		var p := s * s
		peak = maxf(peak, p)
		step = maxf(step, absf(p - prev) * MAX_KICK * 100.0)
		prev = p
	return {"peak": peak, "step": step, "tail": prev}
