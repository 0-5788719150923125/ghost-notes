extends Node

## transport_check - ONE transport for every mode (next/notes.md step 3), driven through the bar.
##
##   tests/run_boot_probe.sh tests/transport_check.gd 120
##
## A SONG: play, pause, seek and stop through the bar's own buttons and rail - and THE CLOCK STANDS
## STILL WHILE PAUSED, inside the held intro and inside the tail as well as in the music. The
## bookend counters ran on through a pause before, so a pause inside a bookend still moved the
## picture (the control: the same pause with the counters left running moves the clock).
##
## A READING: the Generative panel conducts (Spectrum.conduct), and the bar's play, pause, seek and
## stop reach it; after Stop nothing is left on the rail, and once the panel is gone NO HOOK IS
## LEFT - the three Callables this replaced were never cleared by anything.
##
## SPACE plays and pauses through the transport, even with a button focused.

const FixtureAudio := preload("res://tests/fixture_audio.gd")
const LEAD := 3.0
const TAIL := 2.0
const LEN := 10.0

var _fails: Array = []
var _bar: Transport


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_bar = preload("res://src/transport.gd").new()
	add_child(_bar)
	await _frames(2)
	_ok(not _bar._root.visible, "with nothing loaded the show is untimed and there is no transport")
	await _song()
	await _reading()
	Spectrum.stop()
	Spectrum.lead_in = 0.0
	Spectrum.tail = 0.0
	if _fails.is_empty():
		print("transport_check: ALL OK")
		get_tree().quit(0)
		return
	print("transport_check: %d FAILURE(S)" % _fails.size())
	for f in _fails:
		print("   ", f)
	get_tree().quit(1)


func _ok(cond: bool, msg: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + msg)
	if not cond:
		_fails.append(msg)


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _seconds(s: float) -> void:
	await get_tree().create_timer(s).timeout


## Over [param s] seconds, how far the show clock moved.
func _moved(s: float) -> float:
	var t0 := Spectrum.current.time
	await _seconds(s)
	return Spectrum.current.time - t0


func _song() -> void:
	print("-- a song")
	var wav: String = FixtureAudio.silence(LEN)
	_ok(not wav.is_empty(), "the fixture is written")
	Spectrum.lead_in = LEAD
	Spectrum.tail = TAIL
	Spectrum.begin(wav)
	await _frames(20)
	_ok(_bar._root.visible, "a loaded song is timed: the transport shows (Auto and Manual have one now)")
	_ok(Spectrum.transport_playing(), "and the song is playing")
	_ok(Spectrum._held, "inside the held intro to begin with")
	# PAUSE INSIDE THE INTRO, through the bar
	_bar._play.pressed.emit()
	await _frames(2)
	_ok(Spectrum.paused and not Spectrum.transport_playing(), "the bar's ❚❚ pauses it")
	var still := await _moved(0.6)
	_ok(absf(still) < 0.001, "and the clock stands still inside the intro while paused (moved %.3fs)" % still)
	# the control: the intro counter does run when it is not paused
	_bar._play.pressed.emit()
	await _frames(2)
	_ok(Spectrum.transport_playing(), "▶ plays it again")
	var ran := await _moved(0.5)
	_ok(ran > 0.3, "control: unpaused, the intro clock runs (%.2fs in 0.5s)" % ran)
	# SEEK through the rail: a click at three quarters
	var r := _bar._rail()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(r.position.x + r.size.x * 0.75, r.position.y + r.size.y * 0.5)
	click.global_position = click.position
	# IN LOCAL COORDINATES: a pointer event pushed as window coordinates is moved through the
	# window's stretch and lands elsewhere (measured: it never reached the rail)
	get_viewport().push_input(click, true)
	var up := click.duplicate() as InputEventMouseButton
	up.pressed = false
	get_viewport().push_input(up, true)
	await _frames(3)
	var want := 0.75 * Spectrum.scrub_length()
	_ok(absf(Spectrum.scrub_position() - want) < 0.5,
		"a click on the rail seeks there (%.2fs, want %.2fs)" % [Spectrum.scrub_position(), want])
	# PAUSE IN THE MUSIC
	_bar._play.pressed.emit()
	await _frames(2)
	still = await _moved(0.5)
	_ok(Spectrum.paused and absf(still) < 0.001, "paused in the music, the clock stands still (moved %.3fs)" % still)
	_bar._play.pressed.emit()
	# INTO THE TAIL, then pause there
	Spectrum.seek(LEAD + LEN - 0.15)
	var waited := 0.0
	while not Spectrum._tailing and waited < 3.0:
		await _seconds(0.05)
		waited += 0.05
	_ok(Spectrum._tailing, "the song runs into its tail")
	if Spectrum._tailing:
		Spectrum.transport_pause()
		await _frames(2)
		still = await _moved(0.5)
		_ok(absf(still) < 0.001, "and the clock stands still in the tail while paused (moved %.3fs)" % still)
		Spectrum.transport_play()
	# STOP through the bar: back to the start, waiting there
	_bar._stop.pressed.emit()
	await _frames(3)
	_ok(Spectrum.paused and Spectrum.scrub_position() < 0.05,
		"■ goes back to the start and waits there (at %.2fs)" % Spectrum.scrub_position())
	# SPACE plays it, with a button holding the focus
	var b := Button.new()
	add_child(b)
	b.grab_focus()
	var space := InputEventKey.new()
	space.keycode = KEY_SPACE
	space.pressed = true
	get_viewport().push_input(space)
	await _frames(2)
	_ok(Spectrum.transport_playing(), "Space plays it, with a button focused")
	b.queue_free()
	Spectrum.stop()
	await _frames(3)
	_ok(not _bar._root.visible or not Spectrum.timed(), "a stopped session is untimed again")


func _reading() -> void:
	print("-- a reading")
	Spectrum.lead_in = 0.0
	Spectrum.tail = 0.0
	var ed: GenerativeEditor = GenerativeEditor.new()
	ed._build_panel()
	ed._doc._sync = false
	ed._doc._fields = {}
	# the panel goes IN the tree, as speak_stop_check puts it: a Range outside it emits nothing
	ed.remove_child(ed._panel)
	add_child(ed._panel)
	var ended := [0]
	ed.end_stream = func() -> void: ended[0] += 1
	# what _ready does (it would start the voice host, which nothing here needs)
	Spectrum.conduct(ed, ed.transport_hooks())
	await _frames(2)
	_ok(_bar._root.visible, "a panel with a voice is timed before anything plays: the transport shows")
	_ok(_bar._play.disabled, "and its Play waits for a voice to load")
	ed._can_play = true
	ed._text.text = "The first sentence is here. The second one follows it. A third ends the reading."
	ed._plan(ed._text.text)
	ed._sync_speak_buttons()
	await _frames(2)
	_ok(Spectrum.seekable() and Spectrum.scrub_length() > 0.0, "a planned reading is on the rail")
	_ok(Spectrum.transport_playing(), "and reads as playing")
	_bar._play.pressed.emit()
	await _frames(1)
	_ok(Spectrum.paused and not Spectrum.transport_playing(), "the bar's ❚❚ pauses the reading")
	_bar._play.pressed.emit()
	await _frames(1)
	_ok(not Spectrum.paused and Spectrum.transport_playing(), "▶ carries it on")
	var t := Spectrum.scrub_length() * 0.6
	Spectrum.seek(t)
	_ok(ed._seek_k >= 0, "a seek on the rail goes to the reading, by sentence (to %d)" % ed._seek_k)
	ed._seek_k = -1
	_bar._stop.pressed.emit()
	await _frames(1)
	_ok(ended[0] == 1, "■ ends the reading and hands the stage back (end_stream %d)" % ended[0])
	_ok(not Spectrum.seekable() and Spectrum.scrub_length() == 0.0,
		"after a stop nothing is left on the rail")
	_ok(not Spectrum.conductor().is_empty(), "the panel still conducts: ▶ reads again from the top")
	# LEAVING: the panel goes, and its hooks with it
	ed._panel.free()
	ed.free()
	await _frames(2)
	_ok(Spectrum.conductor().is_empty(), "the panel gone, no hook is left")
	_ok(not Spectrum.timed(), "and the show is untimed")
	await _seconds(1.0)
	_ok(not _bar._root.visible, "so the transport has gone too")
