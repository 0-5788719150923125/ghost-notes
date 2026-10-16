extends SceneTree

## take_length_check - the exporter reads a take's length from the WAV itself, whatever its rate and
## channels ([method Exporter._wav_seconds]): the render runs as long as the take.
##
##   godot --headless --path . --script res://tests/export/take_length_check.gd
##
## Reported 2026-10-16 (an overnight export of a Proof lesson): the take was stereo - a voice leans
## ([VoiceFX]) - and the exporter, reading it as mono, said 1081.83 s of a 540.92 s take, so the render
## would have run nine minutes past the show. The fixtures are made here: mono and stereo at Piper's
## 22050, a stereo 44100 take with a chunk before its data, and a take still being written (its data
## size 0). The control is the old reading (the file's size past a 44-byte header, mono), which must
## read the stereo take at twice its length.

const SECONDS := 1.5

var _fails := 0


func _init() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + what)
	if not cond:
		_fails += 1


## A PCM16 WAV of [param seconds] of silence, at [param rate] with [param channels]; with a LIST chunk
## before its data when [param extra]; its data size written as 0 when [param open] (still being written).
func _wav(name: String, rate: int, channels: int, extra: bool, open := false) -> String:
	var dir := ProjectSettings.globalize_path("user://fixtures")
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join(name)
	var n := int(round(SECONDS * rate)) * channels * 2
	var b := StreamPeerBuffer.new()
	b.put_data("RIFF".to_ascii_buffer())
	b.put_u32(0)
	b.put_data("WAVE".to_ascii_buffer())
	b.put_data("fmt ".to_ascii_buffer())
	b.put_u32(16)
	b.put_u16(1)
	b.put_u16(channels)
	b.put_u32(rate)
	b.put_u32(rate * channels * 2)
	b.put_u16(channels * 2)
	b.put_u16(16)
	if extra:
		b.put_data("LIST".to_ascii_buffer())
		b.put_u32(11)                        # odd: the chunk is padded to even
		b.put_data("INFOISFT\u0001\u0002\u0003".to_ascii_buffer())
		b.put_u8(0)
	b.put_data("data".to_ascii_buffer())
	b.put_u32(0 if open else n)
	var silence := PackedByteArray()
	silence.resize(n)
	silence.fill(0)
	b.put_data(silence)
	b.seek(4)
	b.put_u32(b.get_size() - 8)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(b.data_array)
	f.close()
	return path


func _run() -> void:
	# loaded once the autoloads are up: the exporter names them, and a --script gate compiles before them
	var ex: GDScript = load("res://src/export/exporter.gd")
	var mono := _wav("take_mono_22050.wav", 22050, 1, false)
	var stereo := _wav("take_stereo_22050.wav", 22050, 2, false)
	var listed := _wav("take_stereo_44100_list.wav", 44100, 2, true)
	var writing := _wav("take_stereo_22050_open.wav", 22050, 2, false, true)
	for c in [[mono, "a mono take at 22050"], [stereo, "a stereo take at 22050"],
			[listed, "a stereo take at 44100 with a chunk before its data"],
			[writing, "a take still being written (its data size 0)"]]:
		var got: float = ex._wav_seconds(String(c[0]))
		_ok(absf(got - SECONDS) < 0.001, "%s plays %.3f s (%.3f s)" % [c[1], SECONDS, got])
	_ok(ex._wav_seconds(ProjectSettings.globalize_path("res://project.godot")) == 0.0,
		"a file that is no WAV reads as 0")
	# THE CONTROL: the old reading, mono past a 44-byte header
	var size := FileAccess.get_file_as_bytes(stereo).size()
	var old := float(size - 44) / (2.0 * 22050.0)
	_ok(absf(old - 2.0 * SECONDS) < 0.001, "the control: read as mono, the stereo take was twice as long (%.3f s)" % old)
	for p in [mono, stereo, listed, writing]:
		DirAccess.remove_absolute(String(p))
	print("take_length_check: %s" % ("ALL OK" if _fails == 0 else "%d FAILED" % _fails))
	quit(1 if _fails > 0 else 0)
