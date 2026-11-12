extends Node

## reader_browser_check - the Speaker row's Browse… ([ReaderBrowser]): readers ticked, blended and shaped, and Test
## at its top:
##
##   tests/run_boot_probe.sh tests/reading/reader_browser_check.gd 120
##
## Holds, with a stand-in voice host that lists a voice whose readers blend (Kokoro's) and one whose do not (libritts):
##
## - on the blending voice every reader is a tick, what the tab reads in ticked; a second tick is a blend on the
##   tab ([VoiceBlend]) at even shares, its first reader the Speaker number, and every request carries it under a take
##   key of its own;
## - the shape ([VoiceShape]), dragged as a mouse does: a band's edge dragged whole moves every share, one point moves
##   one, a double-click flattens; the Breath line dragged up moves the whole lane, one Push point moves one; a Shape
##   fills them in; noise picked, its seed set, and none - and a wandering noise's request says its paragraph;
## - the method and the accent reach the line; Sound and delivery gives the first reader the sound and the rest the
##   delivery, and a part is the reader's own; Max keeps the shares;
## - one reader shaped is a line of its own, and the request carries it; shaped by nothing, that reader alone;
## - a blend that moves says where its sentence stands in its paragraph (`plan_span`, each sentence its share of the
##   paragraph's words), so every word is read where it stands; one that never moves says no span;
## - unticking back to one reader is that reader alone; the last tick comes off too: nothing ticked, the tab reads
##   on in what it had, Test waits for a tick, and the next tick is that reader alone;
## - the browser opened again shows the blend ticked, and the line under the Speaker row says it;
## - Test at the top asks the host for the passage in the blend, both Test buttons say so, a press while it plays
##   always stops it (a blend changed meanwhile too), and the next press reads the new blend;
## - stepping the Speaker number by hand, or picking another voice, ends the blend.
##
## Controls: nothing ticked never reaches the tab (its reader and blend stay as they were); on the voice whose
## readers do not blend there are no ticks, no shape and a row picks; a blend left on a slot whose voice does not
## blend is never sent; a request with no blend has no `blend` and keeps the key it had; noise that does not wander
## sends no paragraph.
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
	_ok(b != null and b._blends and b._tree.columns == 1 and b._shape_box.visible and b.shape().names.size() == 1,
		"a voice whose readers blend opens with ticks and its shape")
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

	# the shape, dragged
	var sh := b.shape()
	sh.size = Vector2(440, sh.custom_minimum_size.y)
	var rects := sh._rects()
	var mix: Rect2 = rects["mix"]
	var at := Vector2(sh._px(mix, 0.125), mix.position.y + 0.5 * mix.size.y)
	_drag(sh, at, at + Vector2(0, 0.17 * mix.size.y))
	_ok(cast.blend_now() == "mix: af_heart 67, bf_emma 33", "the edge dragged whole moves every share: %s" % cast.blend_now())
	var end := sh._handle("mix", 0, 4, mix)
	_drag(sh, end, Vector2(end.x, mix.position.y + 0.3 * mix.size.y))
	_ok(cast.blend_now() == "mix: af_heart 67/67/67/67/30, bf_emma 33/33/33/33/70",
		"one point moves one place across the paragraph: %s" % cast.blend_now())
	_ok(cast._speaker_about.text == "Mix: heart 67→30%, emma 33→70%", "...said from a paragraph's first word to its last: %s"
		% cast._speaker_about.text)
	var spanned := _chunk()
	spanned["plan_span"] = [0.25, 0.5]
	_ok(str(_ed._request_args(cast.slot_cfg(0), spanned).get("plan_span")) == str([0.25, 0.5]),
		"a blend that moves says where its sentence stands in its paragraph, so each word is read there")
	_drag(sh, at, at, true)
	_ok(cast.blend_now() == "mix: af_heart 60, bf_emma 40", "a double-click flattens it at its mean: %s" % cast.blend_now())
	_ok(not _ed._request_args(cast.slot_cfg(0), spanned).has("plan_span"), "CONTROL: a blend that never moves says no span")
	var text := "One two three. Four five.\n\nSix seven eight nine ten."
	var placed_chunks: Array = ReadingPlan.cut(text, 0)["chunks"]
	ReadingPlan.place(placed_chunks, text)
	var spans := placed_chunks.map(func(c: Dictionary) -> String: return str(c.get("plan_span")))
	_ok(str(spans) == str([str([0.0, 0.6]), str([0.6, 1.0]), str([0.0, 1.0])]),
		"each sentence's span in its paragraph is its share of the paragraph's words: %s" % str(spans))
	var breath: Rect2 = rects["breath"]
	var zero := Vector2(sh._px(breath, 0.125), sh._lane_y(breath, 0.0))
	_drag(sh, zero, zero - Vector2(0, 0.35 * (breath.size.y - 2.0 * VoiceShape.PAD)))
	_ok(cast.blend_now() == "mix: af_heart 60, bf_emma 40; breath 0.7", "the Breath line dragged up: %s" % cast.blend_now())
	var push: Rect2 = rects["push"]
	var top := sh._handle("push", -1, 0, push)
	_drag(sh, top, Vector2(top.x, push.position.y))
	_ok(cast.blend_now() == "mix: af_heart 60, bf_emma 40; breath 0.7; push 1/0/0/0/0", "one Push point: %s" % cast.blend_now())
	b.apply_shape("settle")
	_ok(cast.blend_now() == "mix: af_heart 72/68/60/50/45, bf_emma 28/32/40/50/55; breath 0/0/0.1/0.25/0.4; push 0.3/0.2/0/-0.2/-0.35",
		"Settle fills the shape in around the shares: %s" % cast.blend_now())
	var shown: Array = sh.lanes["breath"]
	var want: Array = VoiceBlend.SHAPES["settle"]["breath"]
	_ok(range(want.size()).all(func(k: int) -> bool: return is_equal_approx(float(shown[k]), float(want[k]))),
		"...and the lanes on screen are its: %s" % str(shown))
	b._noise_picked(2)
	_ok(cast.blend_now().ends_with("; noise wander 0.3") and b._noise_amount.visible, "noise picked: %s" % cast.blend_now())
	var placed := _chunk()
	placed["plan_p"] = 3
	_ok(int(_ed._request_args(cast.slot_cfg(0), placed).get("plan_p", -1)) == 3, "a wandering noise's request says its paragraph")
	# out of the tree a Range does not emit value_changed: the step a click makes, said as the spin box says it
	b._noise_seed.set_value_no_signal(7)
	b._noise_seed.value_changed.emit(7.0)
	_ok(cast.blend_now().ends_with("; noise wander 0.3 7") and b._seed_box.visible and b._noise_seed.prefix.is_empty(),
		"a seed set: %s" % cast.blend_now())
	b._noise_picked(1)
	_ok(not _ed._request_args(cast.slot_cfg(0), placed).has("plan_p"), "CONTROL: noise that does not wander sends no paragraph")
	b._noise_picked(0)
	b.apply_shape("steady")
	_ok(cast.blend_now() == "mix: af_heart 59, bf_emma 41" and not b._noise_amount.visible and not b._seed_box.visible,
		"no noise, and Steady holds the mix at its mean with no lanes: %s" % cast.blend_now())

	# the accent, the method
	b._accent.select(2)
	b._accent.item_selected.emit(2)
	_ok(cast.blend_now() == "mix british: af_heart 59, bf_emma 41", "the accent reaches the line: %s" % cast.blend_now())
	b._method.select(2)
	b._method_picked(2)
	_ok(cast.blend_now() == "split british: af_heart 59 sound, bf_emma 41 delivery" and b._tree.columns == 2,
		"Sound and delivery: the first reader's sound, the rest's delivery, a part column: %s" % cast.blend_now())
	b.row_of(2).set_range(1, 0)
	b.edit(b.row_of(2), 1)
	_ok(cast.blend_now() == "split british: af_heart 59 sound, bf_emma 41", "a part is the reader's own: %s" % cast.blend_now())
	b._method.select(3)
	b._method_picked(3)
	_ok(cast.blend_now() == "max british: af_heart 59, bf_emma 41" and b._tree.columns == 1,
		"Max keeps the shares, no part column: %s" % cast.blend_now())
	b._method.select(0)
	b._method_picked(0)
	_drag(sh, at, at, true)
	b._accent.select(0)
	b._accent.item_selected.emit(0)
	sh.weights = [[0.5, 0.5, 0.5, 0.5, 0.5], [0.5, 0.5, 0.5, 0.5, 0.5]]
	sh.edited.emit()
	_ok(cast.blend_now() == "mix: af_heart, bf_emma", "back to an even mix: %s" % cast.blend_now())

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
	b.apply_shape("hush")
	_ok(cast.blend_now() == "mix: af_heart; breath 0.9; push -0.2", "one reader shaped is a line of its own: %s"
		% cast.blend_now())
	_ok(String(_ed._request_args(cast.slot_cfg(0), _chunk()).get("blend", "")) == cast.blend_now()
		and cast._speaker_about.text == "heart · breath +0.9 · push -0.2", "...asked of the host, and said: %s"
		% cast._speaker_about.text)
	b.apply_shape("steady")
	_ok(cast.blend_now() == "", "CONTROL: shaped by nothing, that reader alone")
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
	_ok(not b._blends and b._tree.columns == 1 and b.row_of(0).get_cell_mode(0) != TreeItem.CELL_MODE_CHECK
		and not b._shape_box.visible, "CONTROL: a voice whose readers do not blend has no ticks and no shape")
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


## A drag on [param sh] from [param from] to [param to], as a mouse makes one - or, [param twice], a double-click.
func _drag(sh: VoiceShape, from: Vector2, to: Vector2, twice := false) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = from
	down.double_click = twice
	sh._gui_input(down)
	if not twice:
		var move := InputEventMouseMotion.new()
		move.position = to
		sh._gui_input(move)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.position = to
	sh._gui_input(up)


func _chunk() -> Dictionary:
	return {"tokens": [{"text": "word"}]}


func _ok(cond: bool, what: String) -> void:
	print("  ok: " if cond else "  FAIL: ", what)
	if not cond:
		_fails.append(what)
