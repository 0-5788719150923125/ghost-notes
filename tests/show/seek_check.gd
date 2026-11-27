extends Node

## Gate for seeking, the scrub bar's one operation.
##
## The clock handed to [method Spectrum.seek] is the session clock, bookend and all. Inside, that position
## is resolved against three regimes (held silence, playing file, run-out tail) and two ways a bookend can
## exist (held here, or baked into the audio); a wrong offset is invisible until a seek lands a few
## seconds off.
##
## Paused, a seek moves the clock at once and it stays paused there - in the music, and from the held intro into
## the music (a paused player is not `playing`, so the clock would hold where it was until Play); the control:
## played, it runs on from where it was sought.
##
## Run: tests/run_boot_probe.sh tests/show/seek_check.gd 120

const LEAD := 5.0
const TAIL := 6.0
const LEN := 10.0                   # the fixture is exactly ten seconds
const FixtureAudio := preload("res://tests/fixture_audio.gd")

var _fails: Array = []


func _ready() -> void:
	var wav: String = FixtureAudio.silence(LEN)
	if wav.is_empty() or not FileAccess.file_exists(wav):
		print("seek_check: could not write the fixture under %s" % FixtureAudio.DIR)
		get_tree().quit(1)
		return
	await _held_bookend(wav)
	await _no_bookend(wav)
	await _paused_seek(wav)
	_unseekable()
	Spectrum.stop()
	Spectrum.lead_in = 0.0
	Spectrum.tail = 0.0
	if _fails.is_empty():
		print("seek_check: ALL OK")
		get_tree().quit()
		return
	print("seek_check: %d FAILURE(S)" % _fails.size())
	for f in _fails:
		print("   ", f)
	get_tree().quit(1)


func _ok(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)


## The clock must read back what was asked for, across all three regimes.
func _held_bookend(wav: String) -> void:
	Spectrum.stop()
	Spectrum.lead_in = LEAD
	Spectrum.tail = TAIL
	Spectrum.begin(wav)
	_ok(Spectrum.seekable(), "a loaded file must be seekable")
	_ok(absf(Spectrum.song_length() - (LEAD + LEN + TAIL)) < 0.05,
		"length should span the bookend, got %.2f" % Spectrum.song_length())

	# into the held silence
	Spectrum.seek(2.0)
	await _settle()
	_ok(absf(Spectrum.current.time - 2.0) < 0.35,
		"seek into the intro should read 2.0s, got %.2f" % Spectrum.current.time)

	# into the content: the offset is where this goes wrong
	Spectrum.seek(LEAD + 4.0)
	await _settle()
	_ok(absf(Spectrum.current.time - (LEAD + 4.0)) < 0.35,
		"seek into the content should read %.1fs, got %.2f"
		% [LEAD + 4.0, Spectrum.current.time])

	# clamped past the end rather than running off
	Spectrum.seek(999.0)
	await _settle()
	_ok(Spectrum.current.time <= LEAD + LEN + TAIL + 0.5,
		"seek past the end must clamp, got %.2f" % Spectrum.current.time)
	_ok(Spectrum.current.time > LEAD,
		"seek past the end must not fall back to the start, got %.2f" % Spectrum.current.time)

	# and back to zero
	Spectrum.seek(0.0)
	await _settle()
	_ok(Spectrum.current.time < 0.6,
		"seek home should read ~0, got %.2f" % Spectrum.current.time)


## Without a bookend the session clock and the player position are the same, so a seek that applied the
## offset anyway would land LEAD seconds early.
func _no_bookend(wav: String) -> void:
	Spectrum.stop()
	Spectrum.lead_in = 0.0
	Spectrum.tail = 0.0
	Spectrum.begin(wav)
	Spectrum.seek(6.0)
	await _settle()
	_ok(absf(Spectrum.current.time - 6.0) < 0.35,
		"unbookended seek should read 6.0s, got %.2f" % Spectrum.current.time)


## Paused, the scrub shows where it lands: the clock (and so the picture, the playhead and the words) goes there with
## no Play, and stays paused.
func _paused_seek(wav: String) -> void:
	Spectrum.stop()
	Spectrum.lead_in = LEAD
	Spectrum.tail = TAIL
	Spectrum.begin(wav)
	Spectrum.seek(LEAD + 3.0)
	await _settle()
	Spectrum.set_paused(true)
	await _settle()
	Spectrum.seek(LEAD + 7.0)
	await _settle()
	_ok(absf(Spectrum.current.time - (LEAD + 7.0)) < 0.05,
		"paused, a seek in the music should read %.1fs at once, got %.2f" % [LEAD + 7.0, Spectrum.current.time])
	_ok(absf(Spectrum.scrub_position() - (LEAD + 7.0)) < 0.05,
		"paused, the playhead should follow the seek to %.1fs, got %.2f" % [LEAD + 7.0, Spectrum.scrub_position()])
	_ok(Spectrum.paused and Spectrum._player.stream_paused and not Spectrum.transport_playing(),
		"a seek while paused should stay paused")
	var at := Spectrum.current.time
	await _settle()
	_ok(absf(Spectrum.current.time - at) < 0.001, "paused, the clock should stand where it was sought (moved %.3fs)"
		% (Spectrum.current.time - at))
	# from the held intro into the music, paused
	Spectrum.seek(2.0)
	await _settle()
	Spectrum.seek(LEAD + 2.0)
	await _settle()
	_ok(absf(Spectrum.current.time - (LEAD + 2.0)) < 0.05 and Spectrum._player.stream_paused,
		"paused, a seek from the intro into the music should read %.1fs and stay paused, got %.2f"
		% [LEAD + 2.0, Spectrum.current.time])
	# the control: played, it runs on from there
	Spectrum.set_paused(false)
	var t0 := Time.get_ticks_msec()
	await get_tree().create_timer(0.5).timeout
	await _settle()
	var waited := float(Time.get_ticks_msec() - t0) / 1000.0
	var ran := Spectrum.current.time - (LEAD + 2.0)
	_ok(ran > 0.2 and ran < waited + 0.5,
		"played, the clock should run on from %.1fs (ran %.2fs in %.2fs)" % [LEAD + 2.0, ran, waited])


## A generator has nothing behind the playhead, so the control must refuse (the scrub bar keys off this).
func _unseekable() -> void:
	Spectrum.stop()
	_ok(not Spectrum.seekable(), "a stopped session must not report itself seekable")


func _settle() -> void:
	# Spectrum publishes `current` from _process, so the clock is a frame behind the seek.
	for _i in 3:
		await get_tree().process_frame
