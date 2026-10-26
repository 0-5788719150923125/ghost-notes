extends Node

## stream_depth_check - the live reading's window follows the host's pace ([ReadingStream]):
##
##   tests/run_boot_probe.sh tests/reading/stream_depth_check.gd 60
##
## A boot probe, not a `--script` gate: [ReadingStream] names the Spectrum autoload, which a `--script`
## run compiles without.
##
## WHAT IT HOLDS (2026-10-25, the user, reading a chapter in a Kokoro voice: "playback kept freezing").
## The window kept LOOKAHEAD_SECONDS of audio ahead, sized for Piper, which makes a take four to eleven
## times faster than it is heard; a host making one barely faster than it is heard ran dry on a long
## sentence. Now the host's cost is measured and the window keeps DEPTH_SAFETY times what the next
## chunks will take to make:
##
## - UNMEASURED, OR FAST, IT IS THE OLD WINDOW: no cost known, or Piper's (a quarter of a second per
##   second), the depth is LOOKAHEAD_SECONDS exactly - a fast host reads as it always did;
## - SLOW, IT IS DEEPER, AND BOUNDED: a host at 0.7 s a second over two long chunks keeps more, and no
##   cost keeps more than DEPTH_MOST;
## - THE COST RISES AT ONCE AND FALLS SLOWLY;
## - THE CONTROL: a replay of a host at 1.5x real time (Kokoro, measured on a busy machine) over uneven
##   sentences, through the window as it was (9 s, a 2.5 s lead) and as it is (the measured depth, the
##   lead the next chunk needs) - the old one runs dry, the new one does not; and at Piper's pace (4x)
##   both start at the same moment and neither runs dry. The replay is the stream's own policy (LOOKAHEAD
##   in flight, the host making one at a time, its [method ReadingStream.depth] and
##   [method ReadingStream.lead_for]), in simulated seconds: it times nothing.

var _fail := 0


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fail += 1
		print("  FAIL: ", what)
	else:
		print("  ok: ", what)


func _ready() -> void:
	var nine := ReadingStream.LOOKAHEAD_SECONDS
	_ok(is_equal_approx(ReadingStream.depth(0.0, PackedFloat32Array([12.0, 14.0])), nine),
		"unmeasured, the window is LOOKAHEAD_SECONDS")
	_ok(is_equal_approx(ReadingStream.depth(0.25, PackedFloat32Array([5.0, 6.0])), nine),
		"a host four times faster than heard keeps the old window")
	var slow := ReadingStream.depth(0.7, PackedFloat32Array([10.0, 12.0]))
	_ok(is_equal_approx(slow, ReadingStream.DEPTH_SAFETY * 0.7 * 22.0) and slow > nine,
		"a slow host over long chunks keeps more: %.1f s" % slow)
	_ok(is_equal_approx(ReadingStream.depth(3.0, PackedFloat32Array([20.0, 20.0])), ReadingStream.DEPTH_MOST),
		"and never more than DEPTH_MOST")
	_ok(is_equal_approx(ReadingStream.cost_after(0.0, 0.4), 0.4), "the first cost seen is the cost")
	_ok(is_equal_approx(ReadingStream.cost_after(0.3, 0.9), 0.6), "a cost that rises is believed at once (halfway)")
	_ok(is_equal_approx(ReadingStream.cost_after(0.9, 0.3), 0.78), "one that falls is let go of slowly (a fifth)")

	# THE CONTROL: uneven sentences, a host at 1.5x real time
	var lens := PackedFloat32Array([3.0, 12.0, 4.0, 14.0, 2.0, 11.0, 5.0, 13.0, 3.0, 9.0, 15.0, 4.0, 10.0, 12.0, 3.0])
	var cost := 1.0 / 1.5
	var was := _replay(lens, cost, false)
	var now := _replay(lens, cost, true)
	_ok(was["stalls"] > 0, "the old window runs dry on a host at 1.5x: %d stalls, %.1f s" % [was["stalls"], was["dry"]])
	_ok(now["stalls"] == 0, "the measured window does not: %d stalls (first sound after %.1f s, the old one's %.1f s)"
		% [now["stalls"], now["first"], was["first"]])
	var fast := _replay(lens, 0.25, true)
	var fast_was := _replay(lens, 0.25, false)
	_ok(fast["stalls"] == 0 and fast_was["stalls"] == 0 and is_equal_approx(fast["first"], fast_was["first"]),
		"a host at Piper's pace starts as soon as it always did (%.2f s) and never runs dry" % fast["first"])
	print("stream_depth_check: %s" % ("PASS" if _fail == 0 else "FAIL (%d)" % _fail))
	get_tree().quit(1 if _fail > 0 else 0)


## The stream's policy over chunks of [param lens] seconds made at [param cost] seconds a second, in
## steps of 10 ms: LOOKAHEAD in flight, the host making one at a time, a request only while what is
## buffered is under the depth, and the first sample held for the lead. [param measured]: the window and
## lead as they are now; else as they were (LOOKAHEAD_SECONDS and LIVE_PREROLL).
func _replay(lens: PackedFloat32Array, cost: float, measured: bool) -> Dictionary:
	var dt := 0.01
	var t := 0.0
	var queue: Array = []          # [chunk, seconds of making left]
	var next_req := 0
	var next_play := 0             # the next chunk not yet in the buffer
	var buffered := 0.0
	var seen := 0.0                # the cost as the stream has measured it
	var started := false
	var first := 0.0
	var stalls := 0
	var dry := 0.0
	var in_stall := false
	while t < 600.0:
		var up := PackedFloat32Array()
		for k in range(next_req, mini(next_req + ReadingStream.LOOKAHEAD, lens.size())):
			up.append(lens[k])
		var deep := ReadingStream.depth(seen, up) if measured else ReadingStream.LOOKAHEAD_SECONDS
		while queue.size() < ReadingStream.LOOKAHEAD and next_req < lens.size() and buffered < deep:
			queue.append([next_req, lens[next_req] * cost])
			next_req += 1
		if not queue.is_empty():
			queue[0][1] -= dt
			if float(queue[0][1]) <= 0.0:
				var k := int(queue[0][0])
				queue.pop_front()
				buffered += lens[k]
				next_play = k + 1
				seen = ReadingStream.cost_after(seen, cost)
		if not started:
			var lead := ReadingStream.LIVE_PREROLL
			if measured and next_play < lens.size():
				lead = maxf(lead, ReadingStream.lead_for(seen, lens[next_play]))
			if buffered >= lead or (next_req >= lens.size() and queue.is_empty()):
				started = true
				first = t
		elif buffered > 0.0:
			buffered = maxf(0.0, buffered - dt)
			in_stall = false
		elif next_req < lens.size() or not queue.is_empty():
			dry += dt
			if not in_stall:
				stalls += 1
				in_stall = true
		else:
			break
		t += dt
	return {"stalls": stalls, "dry": dry, "first": first}
