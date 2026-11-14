extends Node

## audition_check - Test: one voice on its own, the passage streamed in it ([ReadingAudition]):
##
##   tests/run_boot_probe.sh tests/reading/audition_check.gd 120
##
## Holds, with a stand-in voice host that answers with takes made here:
##
## - Test asks the host for the passage's first [constant ReadingAudition.AHEAD] sentences, not all of it, in the
##   selected voice, and says so on its button; the rest are asked as replies arrive, each with the voice's
##   settings as they are then (a pace changed mid-test reaches the sentences asked after it, and not those before);
## - a sentence that arrives before the one ahead of it waits: nothing is joined out of order;
## - the passage is joined as a reading joins it ([ReadingJoin]): every sentence, a seam of the voice's
##   between each two, a second of silence after the last, every joined frame through the room once;
## - a take is taken off the disk once it is joined;
## - Stop drops the replies still in flight and cancels them on the host (every sentence still asked, and no other).
##
## Controls: a reply held back leaves nothing joined until the one ahead arrives; a Stop after every
## sentence has arrived cancels nothing.
##
## The panel is built by hand and never added to the tree (its `_ready` starts the python voice host);
## the audition is handed a player that is in it, so the ring can be fed.

class Host extends VoiceHost:
	var asked: Array = []

	func request(text: String, voice: String, out_path: String,
			params: Dictionary = {}, phonemes: Variant = null) -> int:
		asked.append({"voice": voice, "out": out_path, "params": params})
		return 1000 + asked.size()

	var cancelled: Array = []

	func cancel(ids: Array) -> void:
		cancelled.append_array(ids)

	func is_up() -> bool:
		return true


const SR := 22050

var _fails: Array = []
var _ed: ReadingPanel
var _host: Host


func _ready() -> void:
	_ed = ReadingPanel.new()
	_ed._build_panel()
	# the words read are the plain reading's: a format's walk (a Letter's, a desk's) taken from the Director's last
	# medium in the author's settings must not choose them
	_ed.walk = TextWalk.new()
	if _ed._doc != null:
		_ed._doc._sync = false
	_ed.remove_child(_ed._panel)
	add_child(_ed._panel)
	_host = Host.new()
	_ed._host = _host
	_ed._cast._names = PackedStringArray([Manuscript.NARRATOR])
	_ed._cast._slots = [ReadingPanel.SLOT_DEFAULTS.duplicate()]
	_ed._cast._order = PackedStringArray([Manuscript.NARRATOR])
	_ed._cast.slot = 0
	# the voices the host lists, as they arrive: the picker filled and the tab's voice selected
	_ed._cast.fill_voices([{"id": "en_US-lessac-medium", "name": "lessac medium", "speakers": 1, "installed": true},
		{"id": "en_US-libritts-high", "name": "libritts high", "speakers": 904, "installed": true}])
	_ed._sr = SR
	var player := AudioStreamPlayer.new()
	add_child(player)
	_ed._audition._player = player
	_run.call_deferred()


func _run() -> void:
	var a := _ed._audition
	_ed._on_test()
	var n := a.chunks.size()
	_ok(n >= 10 and _host.asked.size() == ReadingAudition.AHEAD,
		"Test asked for %d of the passage's %d sentences at once, not %d" % [_host.asked.size(), n, ReadingAudition.AHEAD])
	_ok(_ed._cast._test.text == "Test ■" and a.busy(), "Test does not say it is testing")
	# nobody listens here, so nothing is heard: the lead is widened, or the asking would stop LEAD seconds in
	a.lead = 1.0e9
	var sizes: Array = []
	var files: Array = []
	for i in n:
		sizes.append(int(SR * (0.4 + 0.1 * (i % 3))))
		files.append(_wav(i, int(sizes[i])))
	# the second sentence first: it waits for the first
	a.take(1001 + 1, {"wav": files[1], "sample_rate": SR, "tokens": []})
	await _settle(a)
	_ok(a._next == 0 and a._join.frames == 0, "control: a sentence that came early was joined before the one ahead of it")
	a.take(1001, {"wav": files[0], "sample_rate": SR, "tokens": []})
	await _settle(a)
	# the pace changed mid-test: what is asked and not yet joined is asked again at it, and so is all that follows
	var pending: Array = a._req.keys()
	pending.sort()
	var changed_at := _host.asked.size()
	_ed._cast._slots[0]["pace"] = 1.5
	await _settle(a)
	var dropped := _host.cancelled.duplicate()
	dropped.sort()
	_ok(not pending.is_empty() and dropped == pending,
		"the pace changed: %d of the %d sentences still asked were asked again" % [dropped.size(), pending.size()])
	_host.cancelled = []
	for _r in 400:
		if a._next >= n:
			break
		for id in a._req.keys():
			a.take(int(id), {"wav": files[int(a._req[id])], "sample_rate": SR, "tokens": []})
		await _settle(a)
	_ok(a._next == n, "%d of %d sentences joined" % [a._next, n])
	_ok(_host.asked.all(func(q: Dictionary) -> bool: return String(q["voice"]) == "en_US-libritts-high"),
		"Test asked in another voice than the tab's")
	var scale := func(i: int) -> float: return float((_host.asked[i]["params"] as Dictionary).get("length_scale", 0.0))
	var after_ok := true
	for i in range(changed_at, _host.asked.size()):
		after_ok = after_ok and scale.call(i) < scale.call(0) * 0.8
	_ok(after_ok and _host.asked.size() > changed_at, "a sentence asked after the pace changed did not read at it")
	_ok(is_equal_approx(scale.call(changed_at - 1), scale.call(0)),
		"control: a sentence asked before the pace changed read at the new pace")
	_ed._cast._slots[0]["pace"] = 1.0
	var s: Dictionary = _ed._cast.cfg_of(Manuscript.NARRATOR)
	var seam := int(Delivery.seam_gap_of(s) * SR)
	var spoken := 0
	for v in sizes:
		spoken += int(v)
	var whole := spoken + (n - 1) * seam + SR
	_ok(a._join.frames == whole, "the audition joined %d frames, not %d of sentences, %d seams of %d and a second of tail"
		% [a._join.frames, spoken, n - 1, seam])
	var seams_ok := true
	for i in range(1, n):
		seams_ok = seams_ok and int(a._join.chunk_at[i]) == int(a._join.chunk_at[i - 1]) + int(sizes[i - 1]) + seam
	_ok(seams_ok, "a sentence does not start a seam after the one before it")
	var wet: int = a._pushed + (a._hold.size() - a._read)
	_ok(wet == whole and a._dry.is_empty(), "%d frames came out of the room for %d joined" % [wet, whole])
	_ok(files.all(func(f: String) -> bool: return not FileAccess.file_exists(f)), "a joined take was left on the disk")
	# Stop drops what is in flight, and cancels it on the host
	_ed._stop_test()
	_ok(_host.cancelled.is_empty(), "control: a Stop with every sentence arrived cancelled %d requests" % _host.cancelled.size())
	var before := _host.asked.size()
	_ed._on_test()
	var late := 1000 + _host.asked.size()
	_ed._stop_test()
	_ok(not a.busy() and not a.owns(late) and _ed._cast._test.text == "Test", "Stop kept a reply in flight as the audition's")
	var asked_now: Array = range(1001 + before, 1001 + _host.asked.size())
	var gone := _host.cancelled.duplicate()
	gone.sort()
	_ok(gone == asked_now, "Stop cancelled %d of the %d sentences still asked on the host" % [gone.size(), asked_now.size()])
	print("")
	if _fails.is_empty():
		print("audition_check: ALL OK")
	else:
		for f in _fails:
			print("audition_check: FAIL - ", f)
		print("audition_check: %d FAILED" % _fails.size())
	# what a failing audition left behind goes too: the takes stand in for the host's
	for f in files:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)
	_ed._panel.queue_free()
	for _i in 4:
		await get_tree().process_frame
	_ed.free()
	get_tree().quit(0 if _fails.is_empty() else 1)


## A take of [param frames] frames of a tone, written where the host would write sentence [param i].
func _wav(i: int, frames: int) -> String:
	var pcm := PackedVector2Array()
	pcm.resize(frames)
	for k in frames:
		var v := 0.2 * sin(TAU * 180.0 * float(k) / SR)
		pcm[k] = Vector2(v, v)
	return Splice.write_wav("user://_audition_probe_%d.wav" % i, pcm, 1, SR)


## Frames until the audition's workers are done with everything it has been handed.
func _settle(a: ReadingAudition) -> void:
	for _i in 600:
		a.tick()
		await get_tree().process_frame
		if a._tasks.is_empty() and a._fx_task.is_empty() and a._dry.is_empty():
			a.tick()
			return


func _ok(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)
