extends Node

## glyph_frame_check - that the glyphs camera frames the writing in every layout, and that the written
## row holds still.
##
## `_track_pen` must aim at where the layout writes: a spiral advances `_s` along its coil and never
## touches the page cursor `_cx` / `_cy`, and a banner recenters its live line by `_shift_cur`. The
## tracker must also not glide back across the page at a carriage return (the `_chasing` band in
## _track_pen).
##
## The probe runs the shipped camera beside a shadow camera on the retired rule and reports the fraction
## of 900 frames with the nib in shot (retired -> shipped): page 68.3% -> 97.9%, column 87.6% -> 99.7%,
## banner 31.3% -> 100.0%, spiral 100.0% (no honest before: the fix changed what the camera aims at, the
## coil's center, and how far it is zoomed).
##
## The row: the banner's centering shift is integrated on the fixed clock off a target that moves with
## the reveal (`Glyphs._ease_shift`). The probe records the shift every frame and reports the worst
## single-frame step as a fraction of one advance, beside the same measure on the retired rule (0.5 of
## an advance in one frame before, under 0.05 after).
##
## It asserts the sustained case, not the instantaneous one: tracking is eased over about 1.4 s so a
## frame or two of overshoot is the feature, but the nib gone for a second at a time is the bug.
##
## The scene reaches Spectrum and Director, so it needs a real boot (see run_boot_probe's header).
##
## Run: tests/run_boot_probe.sh tests/scenes/glyph_frame_check.gd 120

const W := 1920.0
const H := 1080.0
const FPS := 60.0
const FRAMES := 900
## The row's stability, as a shape rather than a size. An absolute per-frame limit cannot tell a jump
## from a fast hand (the centering legitimately travels at half the pen's rate, about 0.08 of an
## advance per frame at the shortest character spans). Both rules move the row by the same total over a
## line, but one spreads it over every frame and the other delivers it in one step per character:
## peak/mean 5.6 against 36.8. So: a peak no more than this many times the mean step, with an absolute
## backstop for when everything jumps equally.
const MAX_PEAK_RATIO := 12.0
const MAX_STEP := 0.20
## The nib may leave the frame this long while the eased camera catches up (0.5 s, a third of the
## tracker's 1.4 s time constant).
const MAX_GONE := 30
## And it must be in frame for most of the hold, not merely return to it.
const MIN_INSIDE := 0.90
## The camera's own smoothness is measured as acceleration, not speed: a camera that pans quickly is
## fine, one that changes how fast it pans reads as a jerk. The retired rule (a position lerp whose
## velocity is its error, switched between two gains 13x apart) changed it on every commit: peak
## acceleration 139-594 against a flat 16 on the new one, the cap the tracker enforces.
##
## The bound is the cap plus room for one bound contact: the page edge can still stop the camera, a
## deceleration the cap cannot govern (48.5 on the worst seed), but at most once a line.
const MAX_CAM_ACCEL := 90.0
## ...and the retired rule must be worse than that, or this measures nothing.
const MIN_CAM_ACCEL_GAIN := 2.5

var _fails: Array = []
var _seen: Dictionary = {}
## The worst ratio of retired-rule to shipped-rule peak acceleration over every layout in the run.
var _accel_gain := 0.0


func _ready() -> void:
	var script := load("res://src/scenes/glyphs.gd")
	# The layout is a seeded roll, so sweep seeds until all four have been measured.
	for s in range(0, 400):
		if _seen.size() >= 4:
			break
		_run(script, s)
	for want in ["page", "column", "banner", "spiral"]:
		if not _seen.has(want):
			_fails.append("no seed in 0..399 produced the %s layout - the probe never tested it" % want)
	# The camera control, once for the run (see where `_accel_gain` is accumulated).
	if _accel_gain < MIN_CAM_ACCEL_GAIN:
		_fails.append("the retired camera peaked at only %.1fx the shipped one's worst frame "
			% _accel_gain + "(want %.1fx) - no layout here shows the jerk this measures"
			% MIN_CAM_ACCEL_GAIN)
	else:
		print("glyph_frame_check: the retired camera peaked at %.1fx the shipped one" % _accel_gain)
	if _fails.is_empty():
		print("glyph_frame_check: ALL OK")
		get_tree().quit()
		return
	print("glyph_frame_check: %d FAILURE(S)" % _fails.size())
	for f in _fails:
		print("   ", f)
	get_tree().quit(1)


func _run(script, seed_value: int) -> void:
	var sc = script.new()
	sc.init_with_seed(seed_value, "drift")
	if _seen.has(sc._layout):
		sc.free()
		return
	_seen[sc._layout] = true
	# _ready never fires outside a tree, so hand it the frame it would have measured.
	sc.size = Vector2(W, H)
	sc._metrics()
	sc._open = true
	sc._write_opening()
	sc._cam = sc._clamp_cam(sc._pen_at())
	# Drive the path that ships (_step eases `_scroll` toward `_scroll_to`; driving _commit() on a timer
	# lets `_cy` walk off a page that never scrolled). Audio the pen will write to: above
	# Director.silence_floor, with a plausible tempo.
	sc._f = AudioFeatures.new()
	sc._f.energy = 0.25
	sc._f.beat_period = 0.5
	sc._f.flux = 0.02

	var dt := 1.0 / FPS
	var old_cam: Vector2 = sc._cam          # the shadow camera, on the rule that was there
	var chasing := false                    # ...and its gain switch, which is half of the point
	var cam_sp: Array = []
	var old_sp: Array = []
	var cam_prev: Vector2 = sc._cam
	var old_prev: Vector2 = sc._cam
	var old_sw: Vector2 = sc._cam           # the retired rule COMPLETE, gain switch included
	var inside := 0
	var old_inside := 0
	var gone := 0
	var worst_gone := 0
	# The row's own stability: the worst single-frame step of the centering shift, and the same for the
	# retired rule, both as a fraction of one character advance.
	var shift_prev: float = sc._shift_cur
	var raw_prev: float = -(sc._cx + sc._adv + sc._left) * 0.5
	var worst_step := 0.0
	var worst_raw := 0.0
	var travel := 0.0
	var steps := 0
	var raw_travel := 0.0
	var raw_steps := 0
	var line_prev: int = sc._line
	for i in FRAMES:
		if i % 180 == 90:
			sc._pending_word = true         # a section change, as update() would raise it
		sc._step(dt)
		sc._track_pen(dt)
	# The old target: the raw page cursor, no centering shift, and nothing for the spiral.
		var old_target := Vector2(sc._cx + sc._adv * 0.5,
			sc._cy - sc._scroll - sc._line_step * 0.25)
	# The retired camera in full, aimed where it was aimed. Two controls for two bugs:
	#
	#   `old_cam` above is the loose lerp at the raw cursor, no centering shift: the control for the
	#   in-frame column, badly aimed on purpose (banner scores 26% on it).
	#
	#   `old_sw` is the camera as it shipped last: the committed-cursor target, centering shift
	#   included, with the 0.7/9.0 gain switch. The raw target is not a fair control for the
	#   acceleration (banner's shadow flew around chasing a half-measure swing).
		var sw_target := Vector2(sc._cx + sc._adv * 0.5 + sc._shift_cur,
			sc._cy - sc._scroll - sc._line_step * 0.25)
		var sw_off := sw_target - old_sw
		var sw_h: Vector2 = sc._half / maxf(0.001, sc._zoom_in)
		if absf(sw_off.x) > sw_h.x or absf(sw_off.y) > sw_h.y:
			chasing = true
		elif absf(sw_off.x) < sw_h.x * 0.7 and absf(sw_off.y) < sw_h.y * 0.7:
			chasing = false
		old_sw = sc._clamp_cam(old_sw.lerp(sw_target, 1.0 - exp((-9.0 if chasing else -0.7) * dt)))
		old_cam = old_cam.lerp(old_target, 1.0 - exp(-0.7 * dt))

		if sc._centered:
			var adv: float = maxf(0.0001, sc._adv)
			var now_shift: float = sc._shift_cur
	# Measured only while the live line has ink on it, never across a carriage return: a row of
	# glyphs must not move once written, but a new empty line may snap its centering (nothing is
	# drawn with it yet), and measuring that frame would hide the jumps that move ink.
			var mid_line: bool = sc._line == line_prev and sc._cx > sc._left + 0.0001
			if mid_line:
				worst_step = maxf(worst_step, absf(now_shift - shift_prev) / adv)
				travel += absf(now_shift - shift_prev) / adv
				steps += 1
			line_prev = sc._line
			shift_prev = now_shift
	# the control: the expression that used to be evaluated at draw time
			var raw_now: float = -(sc._cx + sc._adv + sc._left) * 0.5
			if mid_line:
				worst_raw = maxf(worst_raw, absf(raw_now - raw_prev) / adv)
				raw_travel += absf(raw_now - raw_prev) / adv
				raw_steps += 1
			raw_prev = raw_now
		var h: Vector2 = sc._half / maxf(0.001, sc._zoom_in)
		var pen: Vector2 = sc._pen_at()
		var off: Vector2 = pen - sc._cam
		var ok := absf(off.x) <= h.x and absf(off.y) <= h.y
		if ok:
			inside += 1
			gone = 0
		else:
			gone += 1
			worst_gone = maxi(worst_gone, gone)
		var oo: Vector2 = pen - old_cam
		if absf(oo.x) <= h.x and absf(oo.y) <= h.y:
			old_inside += 1
	# The frame's own motion: speed this frame, from which the check takes the acceleration.
		cam_sp.append((sc._cam - cam_prev).length() * FPS)
		old_sp.append((old_sw - old_prev).length() * FPS)
		cam_prev = sc._cam
		old_prev = old_sw

	var frac := float(inside) / float(FRAMES)
	var old_frac := float(old_inside) / float(FRAMES)
	print("glyph_frame_check: %-7s seed=%-4d nib in frame %5.1f%% (old rule %5.1f%%), longest gone %d frames"
		% [sc._layout, seed_value, frac * 100.0, old_frac * 100.0, worst_gone])
	if frac < MIN_INSIDE:
		_fails.append("%s: the nib is inside the frame only %.1f%% of the time (want %.0f%%) - the camera is not following the writing"
			% [sc._layout, frac * 100.0, MIN_INSIDE * 100.0])
	if worst_gone > MAX_GONE:
		_fails.append("%s: the nib left the frame for %d consecutive frames (%.2f s, want at most %.2f s)"
			% [sc._layout, worst_gone, float(worst_gone) / FPS, float(MAX_GONE) / FPS])
	if sc._centered:
		var mean_step := travel / float(maxi(1, steps))
		var raw_mean := raw_travel / float(maxi(1, raw_steps))
		print("                   row shift: worst step %.3f advances/frame, mean %.4f, "
			% [worst_step, mean_step] + "peak/mean %.1f  |  old rule: worst %.3f, mean %.4f, "
			% [worst_step / maxf(0.00001, mean_step), worst_raw, raw_mean]
			+ "peak/mean %.1f" % (worst_raw / maxf(0.00001, raw_mean)))
		var ratio := worst_step / maxf(0.00001, mean_step)
		var raw_ratio := worst_raw / maxf(0.00001, raw_mean)
		if ratio > MAX_PEAK_RATIO:
			_fails.append("%s: the row's worst frame is %.1fx its mean (want under %.0f) - the "
				% [sc._layout, ratio, MAX_PEAK_RATIO]
				+ "centering is arriving in steps, not as a glide")
		if worst_step > MAX_STEP:
			_fails.append("%s: the row moved %.2f of a character advance in ONE frame (want under "
				% [sc._layout, worst_step] + "%.2f)" % MAX_STEP)
		if travel < 1.0:
			_fails.append("%s: the centering shift moved %.2f advances over %d frames - it is not "
				% [sc._layout, travel, FRAMES] + "recentering at all, so this measures nothing")
	# Both controls: the old rule must fail both checks above, and its mean must match, or the
	# comparison is between two amounts of centering rather than two ways of delivering it.
		if raw_ratio < MAX_PEAK_RATIO * 1.5:
			_fails.append("%s: the OLD rule's peak/mean is only %.1f - this measure cannot see "
				% [sc._layout, raw_ratio] + "the jump it exists for")
		if absf(raw_mean - mean_step) > 0.35 * maxf(raw_mean, mean_step):
			_fails.append("%s: the two rules travel different distances (%.4f vs %.4f per frame), "
				% [sc._layout, raw_mean, mean_step] + "so the comparison is not about jumpiness")

	# --- the frame's own motion: how hard it changes speed, against the rule it replaced ---
	# The spiral is exempt: it is framed rather than tracked (see _pen_at), so its camera holds still and
	# a ratio on a mean of 0.0003 is noise.
	if sc._layout != "spiral":
		var now_acc := _peak_accel(cam_sp)
		var was_acc := _peak_accel(old_sp)
		var now_mean := _mean(cam_sp)
		var was_mean := _mean(old_sp)
		print("                   camera: peak accel %.1f (old rule %.1f), mean speed %.3f (old %.3f)"
			% [now_acc, was_acc, now_mean, was_mean])
		if now_acc > MAX_CAM_ACCEL:
			_fails.append("%s: the camera changed speed at %.0f per second squared (want under "
				% [sc._layout, now_acc] + "%.0f) - that is a lurch, not a pan" % MAX_CAM_ACCEL)
	# The control is kept for the run, not each layout: peak acceleration on the retired rule was 594
	# on `page`, 227 on `column` and 15 on `banner` (which recenters its live line and barely pans).
	# One layout must show the jerk or the measure is blind; that is asserted once, below.
		_accel_gain = maxf(_accel_gain, was_acc / maxf(1.0, now_acc))
	# ...and the two must be doing the same job, not a tracker against a parked frame.
		if now_mean < was_mean * 0.5:
			_fails.append("%s: the camera now travels %.3f against the old rule's %.3f - it is "
				% [sc._layout, now_mean, was_mean] + "smoother because it stopped following")
	sc.free()


func _mean(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var t := 0.0
	for v in a:
		t += float(v)
	return t / float(a.size())


## The largest change in speed between consecutive frames, per second squared.
func _peak_accel(sp: Array) -> float:
	var worst := 0.0
	for i in range(1, sp.size()):
		worst = maxf(worst, absf(float(sp[i]) - float(sp[i - 1])) * FPS)
	return worst
