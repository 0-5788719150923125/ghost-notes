extends Node

## stream_pause_check - a reading sought to while paused stays paused ([method Spectrum.begin_stream], [method
## ReadingStream.seek_now]; next/editing.md).
##
##   tests/run_boot_probe.sh tests/audio/stream_pause_check.gd 60
##
## A seek restarts the stream from the sentence sought: begun while the session is paused, the new stream is
## held; control: begun while playing, it plays.

var _fails := 0


func _ready() -> void:
	Spectrum.set_paused(true)
	Spectrum.begin_stream(7, 22050)
	_ok(Spectrum._player.stream_paused, "a stream begun while the session is paused is held")
	Spectrum.set_paused(false)
	Spectrum.begin_stream(8, 22050)
	_ok(not Spectrum._player.stream_paused, "the control: begun while playing, it plays")
	Spectrum.stop()
	if _fails == 0:
		print("stream_pause_check: ALL OK")
		get_tree().quit(0)
		return
	print("stream_pause_check: %d FAILED" % _fails)
	get_tree().quit(1)


func _ok(cond: bool, msg: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + msg)
	if not cond:
		_fails += 1
