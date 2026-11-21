extends SceneTree

## Gate for the heard waveform ([HeardWave], [method AudioFeatures.wave]). It holds:
##
## - a 16-bit WAV is read off the disk exactly: the window ends at the moment asked, each sample the file's own there (the
##   control: read a quarter period later, it is not);
## - silence before a file's start and past its end;
## - a float WAV's channels are averaged to one; an 8-bit WAV is not read (its header says so);
## - what a bus caught is read back the same way, its last frame the moment (the control: told the wrong rate, it is not);
## - a frame's waveform is read once, when first asked, and empty with nothing to read.
##
## Run: godot --headless --path . --script tests/audio/heard_wave_check.gd

const Heard := preload("res://src/audio/heard_wave.gd")
const Features := preload("res://src/audio/audio_features.gd")

var _fails: Array = []
var _scratch := ""


func _init() -> void:
	_scratch = OS.get_user_data_dir().path_join("heard_wave_check")
	DirAccess.make_dir_recursive_absolute(_scratch)
	var n := Features.WAVE_SAMPLES
	var rate := float(Features.WAVE_RATE)
	# a 16-bit WAV, read where it lies
	var mono := _scratch.path_join("mono.wav")
	_write_wav(mono, 44100, 1, 16, 1.0, func(t: float, _c: int) -> float: return 0.5 * sin(TAU * 441.0 * t))
	var info := Heard.wav_info(mono)
	_ok(int(info.get("channels", 0)) == 1 and int(info.get("rate", 0)) == 44100 and int(info.get("frames", 0)) == 44100,
		"a WAV's header is read (%s)" % str(info))
	var at := 0.5
	var got := Heard.of_wav(mono, info, at)
	var off := _error(got, func(tt: float) -> float: return 0.5 * sin(TAU * 441.0 * tt), at)
	var late := _error(Heard.of_wav(mono, info, at + 0.25 / 441.0), func(tt: float) -> float: return 0.5 * sin(TAU * 441.0 * tt), at)
	_ok(got.size() == n and off < 0.01, "a 16-bit WAV is read exactly, its window ending at the moment asked (off by %.4f)" % off)
	_ok(late > 0.3, "the control: read a quarter period later, it is not the moment asked (off by %.3f)" % late)
	var early := Heard.of_wav(mono, info, 0.01)
	var gone := Heard.of_wav(mono, info, 1.2)
	var quiet := 0.0
	for v in gone:
		quiet = maxf(quiet, absf(v))
	_ok(early[0] == 0.0 and absf(early[n - 1]) > 0.0 and quiet == 0.0, "silence before a file's start and past its end")
	# a float WAV, two channels averaged; an 8-bit one not read
	var wide := _scratch.path_join("stereo.wav")
	_write_wav(wide, 48000, 2, 32, 0.6, func(t: float, c: int) -> float: return (0.4 if c == 0 else 0.2) * sin(TAU * 300.0 * t))
	var winfo := Heard.wav_info(wide)
	var both := _error(Heard.of_wav(wide, winfo, 0.3), func(tt: float) -> float: return 0.3 * sin(TAU * 300.0 * tt), 0.3)
	_ok(bool(winfo.get("float", false)) and both < 0.01, "a float WAV's two channels are averaged to one (off by %.4f)" % both)
	var narrow := _scratch.path_join("eight.wav")
	_write_wav(narrow, 8000, 1, 8, 0.2, func(_t: float, _c: int) -> float: return 0.0)
	_ok(Heard.wav_info(narrow).is_empty(), "an 8-bit WAV is not read")
	# what a bus caught: chunks at the mixer's rate, the last frame the moment
	var mix := 48000.0
	var chunks: Array = []
	var frames := int(0.1 * mix)
	var k := 0
	for size in [1600, 2400, frames - 4000]:
		var c := PackedVector2Array()
		for i in size:
			var v := 0.6 * sin(TAU * 300.0 * float(k) / mix)
			c.append(Vector2(v, v))
			k += 1
		chunks.append(c)
	var last := float(k - 1) / mix
	var caught := Heard.of_caught(chunks, mix)
	var ok_caught := _error(caught, func(tt: float) -> float: return 0.6 * sin(TAU * 300.0 * tt), last)
	var wrong := _error(Heard.of_caught(chunks, 44100.0), func(tt: float) -> float: return 0.6 * sin(TAU * 300.0 * tt), last)
	_ok(caught.size() == n and ok_caught < 0.01, "what a bus caught is read back, its last frame the moment (off by %.4f)" % ok_caught)
	_ok(wrong > 0.2, "the control: told the wrong rate, it is not (off by %.3f)" % wrong)
	# read once, when first asked
	var f: AudioFeatures = Features.new()
	_ok(f.wave().is_empty(), "with nothing to read, a frame's waveform is empty")
	var calls := [0]
	var g: AudioFeatures = Features.new()
	g.hear_from(func() -> PackedFloat32Array:
		calls[0] += 1
		return PackedFloat32Array([0.25, -0.25]))
	var once := g.wave()
	var twice := g.wave()
	_ok(once == twice and once.size() == 2 and int(calls[0]) == 1, "a frame's waveform is read once, when first asked (%d reads)" % int(calls[0]))
	for p in [mono, wide, narrow]:
		DirAccess.remove_absolute(p)
	DirAccess.remove_absolute(_scratch)
	if _fails.is_empty():
		print("heard_wave_check: ALL OK")
		quit(0)
	else:
		for e in _fails:
			print("heard_wave_check: FAIL  " + e)
		quit(1)


## The most a window [param got] (ending at [param at]) is off what [param want] says at each of its samples' moments.
func _error(got: PackedFloat32Array, want: Callable, at: float) -> float:
	var most := 0.0
	var n := got.size()
	for i in n:
		var t := at - float(n - 1 - i) / float(Features.WAVE_RATE)
		most = maxf(most, absf(got[i] - float(want.call(t))))
	return most


## A WAV at [param path]: [param rate] Hz, [param channels], [param bits] (8 or 16 PCM, 32 float), [param secs] long, each
## sample [param of] (seconds, channel).
func _write_wav(path: String, rate: int, channels: int, bits: int, secs: float, of: Callable) -> void:
	var frames := int(secs * float(rate))
	var data := PackedByteArray()
	data.resize(frames * channels * bits / 8)
	for i in frames:
		for c in channels:
			var v := float(of.call(float(i) / float(rate), c))
			var at := (i * channels + c) * bits / 8
			if bits == 16:
				data.encode_s16(at, int(clampf(v, -1.0, 1.0) * 32767.0))
			elif bits == 32:
				data.encode_float(at, v)
			else:
				data[at] = int(clampf(v * 127.0 + 128.0, 0.0, 255.0))
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer("RIFF".to_ascii_buffer())
	f.store_32(36 + data.size())
	f.store_buffer("WAVEfmt ".to_ascii_buffer())
	f.store_32(16)
	f.store_16(3 if bits == 32 else 1)
	f.store_16(channels)
	f.store_32(rate)
	f.store_32(rate * channels * bits / 8)
	f.store_16(channels * bits / 8)
	f.store_16(bits)
	f.store_buffer("data".to_ascii_buffer())
	f.store_32(data.size())
	f.store_buffer(data)
	f.close()


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails.append(what)
