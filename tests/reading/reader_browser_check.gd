extends Node

## reader_browser_check - the Speaker row's Browse… ([ReaderBrowser]): readers ticked and blended, and Test at its top:
##
##   tests/run_boot_probe.sh tests/reading/reader_browser_check.gd 120
##
## WHAT IT HOLDS (2026-11-11, the user: "instead of selecting just a single model, we have boolean toggles for each
## one. If we select 2 or more of the available models, then they will be blended"; "I hate having to close that
## screen, to test voices"). A stand-in voice host lists a voice whose readers blend (Kokoro's) and one whose do not
## (libritts), and the gate holds that:
##
## - on the blending voice every reader is a tick, what the tab reads in ticked; a second tick is a blend on the tab
##   ([VoiceBlend]), its first reader the Speaker number, and every request the host is asked carries it - under a
##   take key of its own;
## - a weight, the method and the accent reach the line; Sound and delivery gives the first reader the sound and the
##   rest the delivery, and a part is the reader's own;
## - unticking back to one reader is that reader alone; the last tick comes off too (2026-11-11, the user: "it should
##   be possible to select 0 options ... the current version requires backtracking"): nothing ticked, the tab reads on
##   in what it had, Test waits for a tick, and the next tick is that reader alone;
## - the browser opened again shows the blend ticked, and the line under the Speaker row says it;
## - Test at the top asks the host for the passage in the blend, both Test buttons say so, a press while it plays
##   ALWAYS stops it - a blend changed meanwhile too (2026-11-11, the user: "ensure that we always stop before we
##   allow the Test button to be started for playback again") - and the next press reads the new blend;
## - stepping the Speaker number by hand, or picking another voice, ends the blend.
##
## THE CONTROLS: nothing ticked never reaches the tab (its reader and blend stay as they were); on the voice whose
## readers do not blend there are no ticks and a row picks; a blend left on a slot
## whose voice does not blend is never sent; a request with no blend has no `blend` and keeps the key it had.
##
## The panel is built by hand and never added to the tree (its `_ready` starts the python voice host); the popup is
## the panel's child, so it is out of the tree too - its controls are driven, never clicked.

class Host extends VoiceHost:
	var asked: Array = []
	var cancelled: Array = []

	func request(text: String, voice: String, out_path: String,
			params: Dictionary = {}, phonemes: Variant = null) -> int:
		asked.append({"voice": voice, "out": out_path, "params": params})
		return 5000 + asked.size()

	func cancel(ids: Array) -> void:
		cancelled.append_array(ids)

	func is_up() -> bool:
		return true


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
	var first := ReadingPanel.SLOT_DEFAULTS.duplicate()
	first["voice"] = "kokoro"
	_ed._cast._slots = [first]
	_ed._cast._order = PackedStringArray([Manuscript.NARRATOR])
	_ed._cast.slot = 0
	var readers := [{"reader": "af_heart", "g": "F", "d": "heart, American, grade A"},
		{"reader": "am_puck", "g": "M", "d": "puck, American, grade C+"},
		{"reader": "bf_emma", "g": "F", "d": "emma, British, grade B-"}]
	# the host says which backends blend first (its capabilities are asked before its voices), never on a row
	_ed._on_synthesized(0, {"backends": {"kokoro": {"blend": true}, "piper": {}}})
	_ed._cast.fill_voices([
		{"id": "kokoro", "name": "kokoro", "backend": "kokoro", "speakers": 3, "installed": true,
			"readers": readers, "readers_about": "Grades: the host's."},
		{"id": "en_US-libritts-high", "name": "libritts high", "backend": "piper", "speakers": 3, "installed": true,
			"readers": readers, "readers_about": "Readers: the host's."},
		{"id": "kokoro-someone", "name": "Someone", "backend": "kokoro", "speakers": 1, "installed": true}])
	_ed._cast._apply_slot(0)
	_ed._sr = 22050
	var player := AudioStreamPlayer.new()
	add_child(player)
	_ed._audition._player = player
	_run.call_deferred()


func _run() -> void:
	var cast := _ed._cast
	var plain_key := _ed.take_key(cast.slot_cfg(0), _ed._request_args(cast.slot_cfg(0), _chunk()))
	_ok(cast.blends("kokoro") and not cast.blends("en_US-libritts-high") and not cast.blends("kokoro-someone"),
		"the readers of a voice blend where its backend says so and it has more than one (CONTROLS: libritts, a voice of one)")
	cast._open_speaker_browser()
	var b := cast._browser
	_ok(b != null and b._blends and b._tree.columns == 2, "a voice whose readers blend opens with ticks and a weight")
	_ok(b._test != null and b._test.get_parent().get_index() == 0 and b._test.get_index() == 0,
		"Test is first along the browser's top")
	_ok(b.row_of(0).is_checked(0) and not b.row_of(2).is_checked(0), "what the tab reads in (reader 0) is ticked")

	# a second tick: a blend
	_tick(b, 2, true)
	_ok(cast.blend_now() == "mix: af_heart, bf_emma", "a second tick is a mix of the two: %s" % cast.blend_now())
	_ok(String(cast.slot_cfg(0)["blend"]) == cast.blend_now() and int(cast.slot_cfg(0)["speaker"]) == 0,
		"the tab keeps the blend, its first reader the Speaker number")
	var args := _ed._request_args(cast.slot_cfg(0), _chunk())
	_ok(String(args.get("blend", "")) == "mix: af_heart, bf_emma", "the host is asked in the blend: %s" % str(args.get("blend")))
	_ok(_ed.take_key(cast.slot_cfg(0), args) != plain_key, "a blend's takes are kept under a key of their own")
	_ok(cast._speaker_about.text == "Mix: heart 50%, emma 50%", "the Speaker row says the blend: %s" % cast._speaker_about.text)

	# a weight, the accent, the method
	b.row_of(0).set_range(1, 2.0)
	b.edit(b.row_of(0), 1)
	_ok(cast.blend_now() == "mix: af_heart 2, bf_emma", "a weight reaches the line: %s" % cast.blend_now())
	b._accent.select(2)
	b._accent.item_selected.emit(2)
	_ok(cast.blend_now() == "mix british: af_heart 2, bf_emma", "the accent reaches the line: %s" % cast.blend_now())
	b._method.select(2)
	b._method_picked(2)
	_ok(cast.blend_now() == "split british: af_heart 2 sound, bf_emma delivery" and b._tree.columns == 3,
		"Sound and delivery: the first reader's sound, the rest's delivery, a part column: %s" % cast.blend_now())
	b.row_of(2).set_range(2, 0)
	b.edit(b.row_of(2), 2)
	_ok(cast.blend_now() == "split british: af_heart 2 sound, bf_emma", "a part is the reader's own: %s" % cast.blend_now())
	b._method.select(3)
	b._method_picked(3)
	_ok(cast.blend_now() == "max british: af_heart, bf_emma" and b._tree.columns == 1,
		"Max weighs nothing: no Weight column, no weight in the line: %s" % cast.blend_now())
	b._method.select(2)
	b._method_picked(2)
	_ok(cast.blend_now() == "split british: af_heart 2 sound, bf_emma", "back to Sound and delivery, the weights and parts kept")

	# Test at the top: in the blend; again with nothing changed stops it; after a change starts it again
	b._test.pressed.emit()
	var n := _host.asked.size()
	_ok(n > 5 and _host.asked.all(func(q: Dictionary) -> bool:
			return String((q["params"] as Dictionary).get("blend", "")) == cast.blend_now()),
		"Test asked the host for the passage in the blend (%d sentences)" % n)
	_ok(b._test.text == "Test ■" and cast._test.text == "Test ■", "both Test buttons say a test is playing")
	b._test.pressed.emit()
	_ok(not _ed._test_busy() and _host.asked.size() == n and b._test.text == "Test",
		"CONTROL: Test pressed again with nothing changed stops it")
	b._test.pressed.emit()
	_tick(b, 1, true)
	var during := _host.asked.size()
	b._test.pressed.emit()
	_ok(not _ed._test_busy() and _host.asked.size() == during and b._test.text == "Test" and cast._test.text == "Test",
		"Test pressed after a change still stops it - it never starts over")
	b._test.pressed.emit()
	_ok(_ed._test_busy() and _host.asked.size() == during + n
		and String((_host.asked[-1]["params"] as Dictionary).get("blend", "")).contains("am_puck"),
		"...and the next press reads the new blend")
	_ed._stop_test()

	# back to one reader, then to none: a way through to another reader, never a pick
	_tick(b, 1, false)
	_tick(b, 2, false)
	_ok(cast.blend_now() == "" and int(cast.slot_cfg(0)["speaker"]) == 0, "unticked back to one: that reader alone")
	_ok(not _ed._request_args(cast.slot_cfg(0), _chunk()).has("blend")
		and _ed.take_key(cast.slot_cfg(0), _ed._request_args(cast.slot_cfg(0), _chunk())) == plain_key,
		"CONTROL: no blend asks no blend, under the key it had")
	_tick(b, 0, false)
	await get_tree().process_frame
	_ok(b._on.is_empty() and not b.row_of(0).is_checked(0), "the last tick comes off: nothing ticked")
	_ok(int(cast.slot_cfg(0)["speaker"]) == 0 and cast.blend_now() == "" and cast.speaker_now() == 0,
		"CONTROL: nothing ticked never reaches the tab - it reads on in its reader")
	_ok(b._test.disabled and b._method.disabled and b._summary.text.begins_with("Nothing ticked")
		and b._summary.text.ends_with("reads in heart.") and b._summary.tooltip_text == b._summary.text,
		"Test waits for a tick, and the browser says why: %s" % b._summary.text)
	_tick(b, 2, true)
	_ok(int(cast.slot_cfg(0)["speaker"]) == 2 and cast.blend_now() == "" and not b._test.disabled,
		"the next tick is that reader alone - no backtracking")
	_tick(b, 2, false)
	_tick(b, 0, true)
	_ok(int(cast.slot_cfg(0)["speaker"]) == 0 and b._on.size() == 1, "...and back to the first")

	# opened again on a blend: ticked as it was
	_tick(b, 1, true)
	var kept := cast.blend_now()
	cast._open_speaker_browser()
	b = cast._browser
	_ok(b.row_of(0).is_checked(0) and b.row_of(1).is_checked(0) and not b.row_of(2).is_checked(0)
		and cast.blend_now() == kept, "opened again, the blend is ticked as it was: %s" % kept)

	# the Speaker number stepped by hand ends it
	cast._speaker.value = 2
	_ok(cast.blend_now() == "" and String(cast.slot_cfg(0)["blend"]) == "", "a Speaker number stepped by hand ends the blend")

	# a voice whose readers do not blend
	_tick(b, 2, true)
	_ok(not cast.blend_now().is_empty(), "blended again")
	cast.voice_pick.select(1)
	cast._voice_picked()
	_ok(cast.blend_now() == "", "another voice ends the blend")
	var stale := cast.slot_cfg(0)
	stale["blend"] = "mix: af_heart, bf_emma"
	_ok(cast.blend_of(stale) == "" and not _ed._request_args(stale, _chunk()).has("blend"),
		"CONTROL: a blend left on a voice whose readers do not blend is never sent")
	cast._open_speaker_browser()
	b = cast._browser
	_ok(not b._blends and b._tree.columns == 1 and b.row_of(0).get_cell_mode(0) != TreeItem.CELL_MODE_CHECK,
		"CONTROL: a voice whose readers do not blend has no ticks")
	b.row_of(1).select(0)
	_ok(int(cast.slot_cfg(0)["speaker"]) == 1 and cast.blend_now() == "", "...and a row picks its reader")

	for f in _fails:
		print("  FAIL: ", f)
	print("reader_browser_check: ", "ALL OK" if _fails.is_empty() else "%d FAILED" % _fails.size())
	get_tree().quit(1 if not _fails.is_empty() else 0)


## Reader [param i] ticked ([param on]) or not, as a click on its tick does.
func _tick(b: ReaderBrowser, i: int, on: bool) -> void:
	var it := b.row_of(i)
	it.set_checked(0, on)
	b.edit(it, 0)


func _chunk() -> Dictionary:
	return {"tokens": [{"text": "word"}]}


func _ok(cond: bool, what: String) -> void:
	print("  ok: " if cond else "  FAIL: ", what)
	if not cond:
		_fails.append(what)
