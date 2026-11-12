extends Node

## Gate for Stop in the Generative panel:
##
##   tests/run_boot_probe.sh tests/reading/speak_stop_check.gd 90
##
## Stop must reset the whole of a reading, not most of it: every field a reading owns is back where it started
## and the owner's `end_stream` was called exactly once (otherwise the audio stream stays open and the Director
## stays attached to a stage nothing drives).
##
## The editor is built by hand and never added to the tree, because its `_ready` starts the python voice host.
## The panel itself does go in: Range emits `value_changed` only for an owner inside the tree (see multi_voice_check.gd).

var _fails: Array = []
var _ed: ReadingPanel
var _ended := 0


func _ready() -> void:
	_ed = ReadingPanel.new()
	_ed._build_panel()
	_ed.remove_child(_ed._panel)
	add_child(_ed._panel)
	_ed.remove_child(_ed._cast._repace_timer)
	add_child(_ed._cast._repace_timer)
	_ed.end_stream = func() -> void: _ended += 1
	_run.call_deferred()


func _run() -> void:
	_check_stop_ends_a_reading()
	_check_stop_is_idempotent()
	_check_the_transport_follows_the_state()
	_check_space_plays_wherever_the_focus_is()
	print("")
	if _fails.is_empty():
		print("speak_stop_check: ALL OK - Stop ends a reading and hands the stage back.")
	else:
		print("speak_stop_check: %d FAILURE(S)" % _fails.size())
		for f in _fails:
			print("   ", f)
	# Freed by hand: the editor was never in the tree, and its two reparented children are not freed by it.
	_ed._panel.queue_free()
	_ed._cast._repace_timer.queue_free()
	for _i in 4:
		await get_tree().process_frame
	_ed.free()
	get_tree().quit(1 if not _fails.is_empty() else 0)


## The whole of a reading, put back. Listed field by field on purpose: a Stop that clears the chunk list but
## leaves the request map still splices stale replies into the next reading.
func _check_stop_ends_a_reading() -> void:
	print("")
	print("stop_ends_a_reading")
	_ed._text.text = "The machines are running. They have been here for years. Nobody minds."
	_ed._stream.plan(_ed._text.text)
	_ok(not _ed._stream.chunks.is_empty(), "a reading was planned (%d chunks)" % _ed._stream.chunks.size())
	# Pretend the stream opened and a couple of chunks went out: the state Stop has to unwind, not the tidy one after planning.
	_ed._stream._stream_open = true
	_ed._stream._next_to_request = 2
	_ed._stream._in_flight = 1
	_ed._stream._req_chunk = {7: 0, 8: 1}
	_ed._stream._pushed = 12345
	_ed._stream._join.frames = 77175
	_ed._stream._join.marks.append({"at": 0, "speaker": "Narrator"})
	_ed._stream._join.fade_at = 500
	_ed._stream._ready_takes = [{"stub": true}]
	_ed._stream._sub_words.append({"w": "the"})
	_ended = 0
	_ed._stream.stop()
	_ok(_ended == 1, "the owner's end_stream was called exactly once (%d)" % _ended)
	# by name, so a name the stream does not hold is a failure, never a null that reads as empty
	for name in ["chunks", "_ready_takes", "_sub_words"]:
		_ok(name in _ed._stream and (_ed._stream.get(name) as Array).is_empty(), "%s is empty" % name)
	_ok(_ed._stream._req_chunk.is_empty(),
		"the pending request map is cleared, so replies in flight are discarded on arrival")
	_ok(not _ed._stream._stream_open, "_stream_open is false")
	_ok(_ed._stream.playback == null, "_playback is released")
	for name in ["_next_to_request", "_next_to_play", "_in_flight", "_pushed", "_read",
			"_ring_capacity"]:
		_ok(name in _ed._stream and int(_ed._stream.get(name)) == 0, "%s is zero (%s)" % [name, str(_ed._stream.get(name))])
	_ok(_ed._stream._join.frames == 0 and _ed._stream._join.marks.is_empty() and _ed._stream._join.fade_at == -1, "the reading clock is back to zero, with no marks and no fade")
	_ok(is_equal_approx(_ed._stream._lead_in, 0.0), "the intro silence is cleared")
	_ok(_ed._stream._pending.is_empty(), "the resampler's pending buffer is empty")


## Pressing it twice, or with nothing playing, does nothing, including not calling the owner's end_stream again
## (which would detach a stage the editor no longer owns).
func _check_stop_is_idempotent() -> void:
	print("")
	print("stop_is_idempotent")
	_ended = 0
	_ed._stream.stop()
	_ed._stream.stop()
	_ok(_ended == 0, "stopping an already-stopped reading calls end_stream %d times" % _ended)


## Play and Stop are the transport's (next/notes.md step 3): the panel conducts, and the bar along the stage
## draws its buttons from these hooks every frame.
func _check_the_transport_follows_the_state() -> void:
	print("")
	print("the_transport_follows_the_state")
	var h: Dictionary = _ed.transport_hooks()
	for k in ["play", "pause", "stop", "playing", "can_play", "can_stop", "position", "length", "seek"]:
		_ok((h.get(k) as Callable).is_valid(), "the panel hands the transport its '%s'" % k)
	_ok(not bool(h["can_play"].call()), "Play cannot start before a voice has loaded")
	_ok(not bool(h["can_stop"].call()), "Stop is grayed with nothing playing")
	_ok(float(h["length"].call()) == 0.0, "and the rail is empty")
	_ed._text.text = "One sentence is enough. And a second one, to have two."
	_ed._stream.plan(_ed._text.text)
	_ed._stream._sync_speak_buttons()
	_ok(bool(h["can_stop"].call()), "Stop is live once a reading is planned")
	_ok(float(h["length"].call()) > 0.0, "and the rail has the reading on it (%.1fs)" % float(h["length"].call()))
	_ed._stream.stale = true
	_ok(_ed._stream.play_label().ends_with("●"), "an edit since the reading began shows its dot (%s)" % _ed._stream.play_label())
	_ed._stream.stop()
	_ok(not bool(h["can_stop"].call()), "Stop is grayed again after Stop")
	_ok(float(h["length"].call()) == 0.0, "the rail is empty again - a seek there would start a reading")
	_ok(_ed._stream.play_label() == "Play", "Play has dropped its unsaved-edit dot after a stop (%s)" % _ed._stream.play_label())


## Space plays and pauses wherever the focus is: the Transport takes Space first (Transport.space_toggles), with a
## button focused or the panel hidden, unless someone types, in every mode; the collapse button
## (SidePanel.pin_title_row) takes no focus. The control: a button on the panel that does take it.
func _check_space_plays_wherever_the_focus_is() -> void:
	print("")
	print("space_plays_wherever_the_focus_is")
	var collapse: Button = null
	var focused: Button = null
	for b in _ed._panel.find_children("*", "Button", true, false):
		if (b as Button).text == "–":
			collapse = b
		elif focused == null and (b as Button).focus_mode != Control.FOCUS_NONE:
			focused = b
	_ok(collapse != null, "the panel has its collapse button")
	if collapse == null or focused == null:
		_ok(focused != null, "the panel has a button that takes the focus")
		return
	_ok(collapse.focus_mode == Control.FOCUS_NONE, "clicking the collapse button leaves the keyboard focus where it was")
	_ok(focused.focus_mode != Control.FOCUS_NONE,
		"control: clicking \"%s\" takes the keyboard focus (which is why Space went to the collapse button once)" % focused.text)
	var space := InputEventKey.new()
	space.keycode = KEY_SPACE
	space.pressed = true
	_ok(Transport.space_toggles(space, focused), "Space plays with a button focused")
	_ok(Transport.space_toggles(space, null), "and with nothing focused")
	_ed._panel.visible = false
	_ok(Transport.space_toggles(space, null), "and with the panel collapsed")
	_ed._panel.visible = true
	_ok(not Transport.space_toggles(space, _ed._text), "but not while typing in the script")
	var field := LineEdit.new()
	_ok(not Transport.space_toggles(space, field), "or in a text field")
	field.free()
	var ctrl := space.duplicate() as InputEventKey
	ctrl.ctrl_pressed = true
	_ok(not Transport.space_toggles(ctrl, null), "Ctrl+Space is not Space")
	var held := space.duplicate() as InputEventKey
	held.echo = true
	_ok(not Transport.space_toggles(held, null), "a held key does not toggle again and again")


func _ok(cond: bool, what: String) -> void:
	if cond:
		print("    ok  %s" % what)
	else:
		_fails.append(what)
		print("    FAIL %s" % what)
