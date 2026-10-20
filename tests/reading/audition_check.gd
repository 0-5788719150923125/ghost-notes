extends Node

## audition_check - Test: one voice on its own, the passage streamed in it ([ReadingAudition]):
##
##   tests/run_boot_probe.sh tests/reading/audition_check.gd 120
##
## WHAT IT HOLDS (next/structure.md, step 19). Test had no gate at all; its state was twenty members
## of the reading panel, and it joined its sentences with a copy of the reading's seams of its own.
## Here a stand-in voice host answers with takes made here, and the gate holds that:
##
## - Test asks the host for every sentence of the passage at once, in the selected voice, and says
##   so on its button;
## - a sentence that arrives before the one ahead of it waits: nothing is joined out of order;
## - the passage is joined as a reading joins it ([ReadingJoin]): every sentence, a seam of the
##   voice's between each two, a second of silence after the last so the room rings out - and every
##   joined frame goes through the room, none lost and none twice;
## - a take is taken off the disk once it is joined;
## - Stop drops the replies still in flight: a late one is no longer the audition's.
##
## THE CONTROL: a reply held back (out of order) leaves nothing joined until the one ahead arrives,
## so "joined" above is something that can be withheld.
##
## The panel is built by hand and never added to the tree (its `_ready` starts the python voice
## host); the audition is handed a player that IS in it, so the ring can be fed.

class Host extends VoiceHost:
	var asked: Array = []

	func request(text: String, voice: String, out_path: String,
			params: Dictionary = {}, phonemes: Variant = null) -> int:
		asked.append({"voice": voice, "out": out_path, "params": params})
		return 1000 + asked.size()

	func is_up() -> bool:
		return true


const SR := 22050

var _fails: Array = []
var _ed: ReadingPanel
var _host: Host


func _ready() -> void:
	_ed = ReadingPanel.new()
	_ed._build_panel()
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
	_ok(n >= 10 and _host.asked.size() == n, "Test asked for %d of the passage's %d sentences" % [_host.asked.size(), n])
	_ok(_host.asked.all(func(q: Dictionary) -> bool: return String(q["voice"]) == "en_US-libritts-high"),
		"Test asked in another voice than the tab's")
	_ok(_ed._cast._test.text == "Test ■" and a.busy(), "Test does not say it is testing")
	# the second sentence first: it waits for the first
	var sizes: Array = []
	var files: Array = []
	for i in n:
		sizes.append(int(SR * (0.4 + 0.1 * (i % 3))))
		files.append(_wav(i, int(sizes[i])))
	a.take(1001 + 1, {"wav": files[1], "sample_rate": SR, "tokens": []})
	await _settle(a)
	_ok(a._next == 0 and a._join.frames == 0, "control: a sentence that came early was joined before the one ahead of it")
	a.take(1001, {"wav": files[0], "sample_rate": SR, "tokens": []})
	for i in range(2, n):
		a.take(1001 + i, {"wav": files[i], "sample_rate": SR, "tokens": []})
	await _settle(a)
	_ok(a._next == n, "%d of %d sentences joined" % [a._next, n])
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
	# Stop drops what is in flight
	_ed._stop_test()
	_ed._on_test()
	var late := 1000 + _host.asked.size()
	_ed._stop_test()
	_ok(not a.busy() and not a.owns(late) and _ed._cast._test.text == "Test", "Stop kept a reply in flight as the audition's")
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
