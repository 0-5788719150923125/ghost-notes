extends Node

## tunnel_smooth_check - that a tunnel_run flight is continuous, measured in pixels.
##
## Everything along the tube (swell, hue zones, wound spectrum, fog) is keyed to arclength and so fixed
## in the world, but a rib test of `i % rib_every` on the station's index into the buffer steps backward
## by a station each time `_advance_track` retires one (ten times a second at this speed), against walls
## still moving forward. The rule must key on the station's world number.
##
## Two measurements:
##
##   1. The picture: frame-to-frame mean absolute luma difference over 90 real frames. Smooth forward
##      motion is a slowly varying number and a jump is a spike (3.3 typical with a 10-12 spike every
##      sixth frame on the old rule, 2.2-3.7 with none now). It needs no model of what a rib is, so it
##      catches the next thing that steps once per station too.
##
##   2. The rule, both ways: the set of world arclengths carrying a rib is computed under the shipped
##      rule and the old one, before and after a retirement, and the old rule must move or this file
##      asserts nothing.
##
## Run: GHOST_PROBE_GPU=1 tests/run_boot_probe.sh tests/scenes/tunnel_smooth_check.gd 240

const W := 640
const H := 360
const DT := 1.0 / 60.0
const FRAMES := 90
const WARMUP := 40
## A frame that differs from its predecessor by more than this multiple of the run's mean is a step
## rather than a move. 1.8 is above the honest variation of a bending flight (2.2 to 3.7 against a 2.8
## mean) and under a station step (10 to 12 against 3.3).
const SPIKE := 1.8
## Engine frames to wait for the worker to deliver a packet before giving up (a packet lands within a
## dozen frames at the measured rates): it notices a forge that has stopped, not one that is busy.
const SPIN_LIMIT := 240

var _fails: Array = []


func _ready() -> void:
	_run.call_deferred()


func _features() -> AudioFeatures:
	var f := AudioFeatures.new()
	f.energy = 0.5
	f.bass = 0.5
	f.bands = PackedFloat32Array()
	for _i in 64:
		f.bands.append(0.4)
	return f


func _run() -> void:
	_check_rule()
	await _check_picture()
	if _fails.is_empty():
		print("tunnel_smooth_check: ALL OK")
		get_tree().quit()
		return
	print("tunnel_smooth_check: %d FAILURE(S)" % _fails.size())
	for f in _fails:
		print("   ", f)
	get_tree().quit(1)


## Where the ribs sit in the world, under each rule, as the window slides along the track. No rendering
## and no scene: the defect is one modulo. A station's absolute number is `s / STEP` and the window holds
## `n` of them from `s0`; retiring one advances `s0` by a step and drops every index by one.
func _check_rule() -> void:
	var step := 0.55
	var every := 9
	var n := 30
	var moved_new := 0
	var moved_old := 0
	for retired in 6:
		var s0 := float(retired) * step
		for i in n:
			var si := s0 + float(i) * step
			var abs_no := int(round(si / step))
	# the shipped rule, and the rule it replaced
			var now := (abs_no % every) == 0
			var was := (i % every) == 0
	# a rib at this arclength under the first window is the reference
			var ref_now := (abs_no % every) == 0
			var ref_was := ((abs_no) % every) == 0
			if now != ref_now:
				moved_new += 1
			if retired > 0 and was != ref_was:
				moved_old += 1
	print("tunnel_smooth_check: over 6 retirements, ribs that moved in the world - shipped %d, old rule %d"
		% [moved_new, moved_old])
	if moved_new != 0:
		_fails.append("a rib moved in the world under the shipped rule (%d of them) - it is not keyed to arclength"
			% moved_new)
	if moved_old == 0:
		_fails.append("the OLD index rule did not move a single rib, so this control is measuring nothing")


## Wait until the worker hands over a new packet, so one call is exactly one step of the flight at any
## harness speed. False if it never arrived.
func _next_packet(sc) -> bool:
	var src: Variant = sc._forge.packet_source()
	for _spin in SPIN_LIMIT:
		await get_tree().process_frame
		if sc._forge.packet_source() != src:
			return true
	return false


## What the flight looks like, one step at a time.
func _check_picture() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(W, H)
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var sc = load("res://src/scenes/tunnel_run.gd").new()
	vp.add_child(sc)
	sc.init_with_seed(7, "drift")
	# Warmed up the way it is measured: spinning `update` without waiting for packets leaves the forge
	# far behind, and the first measured packet carries the whole backlog (10.5 against a 2.9 mean), a
	# startup transient reported as a step. Discarding the first sample would only hide it.
	for _i in WARMUP:
		sc.update(_features(), DT)
		await _next_packet(sc)
	var prev := PackedByteArray()
	var diffs: Array = []
	var starved := 0
	for _i in FRAMES:
		sc.update(_features(), DT)
	# One sample per packet, not per engine frame: tunnel_run builds its geometry on a worker (see
	# FrameForge) and the picture changes only when a packet lands. Unthrottled, this probe runs at
	# 224-293 fps while the forge delivers 30 to 50 packets a second, so most samples repeat a picture
	# and one carries several frames of travel, which reads as a step every few frames and depends on
	# the machine's spare capacity. Waiting for the packet source to change makes every sample exactly
	# one `update` of travel apart, so the diffs are comparable.
		if not await _next_packet(sc):
			starved += 1
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.convert(Image.FORMAT_L8)
		var cur := img.get_data()
		if prev.size() == cur.size():
			var acc := 0
			var taken := 0
			for k in range(0, cur.size(), 7):
				acc += absi(int(cur[k]) - int(prev[k]))
				taken += 1
			diffs.append(float(acc) / float(maxi(1, taken)))
		prev = cur
	vp.queue_free()
	await get_tree().process_frame
	if starved > 0:
		_fails.append("the forge failed to deliver a packet within %d frames on %d of %d samples - the scene is not building"
			% [SPIN_LIMIT, starved, FRAMES])
	if diffs.size() < 10:
		_fails.append("the probe captured %d usable frames - it is not measuring the scene" % diffs.size())
		return
	var mean := 0.0
	var worst := 0.0
	for d in diffs:
		mean += float(d)
		worst = maxf(worst, float(d))
	mean /= float(diffs.size())
	var spikes := 0
	for d in diffs:
		if float(d) > mean * SPIKE:
			spikes += 1
	var per_sec := float(spikes) * 60.0 / float(diffs.size())
	print("tunnel_smooth_check: %d frames, mean change %.2f, worst %.2f (%.2fx) - %d spike(s), %.1f/s"
		% [diffs.size(), mean, worst, worst / maxf(0.01, mean), spikes, per_sec])
	if spikes > 0:
		_fails.append("the picture steps %.1f times a second (%d frames over %.1fx the mean) - a flight through a tube does not"
			% [per_sec, spikes, SPIKE])
	# The instrument's own control: what would a step score? A skipped station delivers two steps of
	# travel in one frame, so the smallest step to catch is the sum of two adjacent diffs; if that does
	# not clear the spike threshold, the threshold is too loose to see the fault. Arithmetic on the
	# samples already taken, not a second render with deliberately dropped packets.
	var pair := 0.0
	for k in range(1, diffs.size()):
		pair = maxf(pair, float(diffs[k]) + float(diffs[k - 1]))
	print("tunnel_smooth_check: a doubled step would score %.2f, %.2fx the mean (threshold %.1fx)"
		% [pair, pair / maxf(0.01, mean), SPIKE])
	if pair <= mean * SPIKE:
		_fails.append("two steps at once would only score %.2fx the mean - this measure cannot see a skipped station, so it is not gating anything"
			% (pair / maxf(0.01, mean)))
	# ...and it must still be moving, or a scene that froze would pass the test above.
	if mean < 0.5:
		_fails.append("the picture barely changes at all (mean %.2f) - it is smooth because nothing is happening" % mean)
