extends RefCounted
class_name HeardWave

## HeardWave - the heard audio's waveform ([method AudioFeatures.wave]), for what draws a sound as it is (a scope): a WAV file
## playing, read exactly at its moment off the disk ([method of_wav]); or a stream (a reading said live, a song made as it
## plays), caught off the bus the show's own audio plays on ([method tap], [method drain], [method caught]). Each answer a
## window of [constant AudioFeatures.WAVE_SAMPLES] samples, mono, at [constant AudioFeatures.WAVE_RATE], its last sample the
## moment asked for; each a Callable bound to its own copies, so a worker may read it.
##
## A file is read where it lies, never held in memory whole (a long take is hundreds of megabytes); a 16-bit or float WAV.

## The bus the show's player plays on, sent on to the Master bus, and how much of a stream is kept (s).
const BUS := "Heard"
const KEPT := 0.15

var _cap: AudioEffectCapture
var _chunks: Array = []          # what was caught, oldest first: a PackedVector2Array each, at the mixer's rate
var _held := 0                   # frames in them


## [param player] moved onto the show's own bus ([constant BUS], made where there is none, sent to the Master bus) with a
## capture on it, so what it plays is caught and nothing else is.
func tap(player: AudioStreamPlayer) -> void:
	var idx := AudioServer.get_bus_index(BUS)
	if idx < 0:
		idx = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, BUS)
		AudioServer.set_bus_send(idx, "Master")
	for k in AudioServer.get_bus_effect_count(idx):
		if AudioServer.get_bus_effect(idx, k) is AudioEffectCapture:
			_cap = AudioServer.get_bus_effect(idx, k)
	if _cap == null:
		_cap = AudioEffectCapture.new()
		_cap.buffer_length = KEPT * 2.0
		AudioServer.add_bus_effect(idx, _cap)
	player.bus = BUS


## What the bus played since the last frame taken in, and what is older than [constant KEPT] let go: whole chunks, never a
## loop over their samples.
func drain() -> void:
	if _cap == null:
		return
	var n := _cap.get_frames_available()
	if n > 0:
		var got := _cap.get_buffer(n)
		_chunks.append(got)
		_held += got.size()
	var keep := int(KEPT * AudioServer.get_mix_rate())
	while _chunks.size() > 1 and _held - (_chunks[0] as PackedVector2Array).size() >= keep:
		_held -= (_chunks[0] as PackedVector2Array).size()
		_chunks.pop_front()


## This moment's window of what the bus played, as a Callable ([method of_caught]) bound to its own copy.
func caught() -> Callable:
	return HeardWave.of_caught.bind(_chunks.duplicate(), AudioServer.get_mix_rate())


## The window of [param chunks] (stereo, at [param rate], oldest first) ending at their last frame; empty with too little.
static func of_caught(chunks: Array, rate: float) -> PackedFloat32Array:
	var need := int(ceil(float(AudioFeatures.WAVE_SAMPLES) / float(AudioFeatures.WAVE_RATE) * rate)) + 2
	var tail := PackedVector2Array()
	var k := chunks.size() - 1
	while k >= 0 and tail.size() < need:
		var c: PackedVector2Array = chunks[k]
		c.append_array(tail)
		tail = c
		k -= 1
	if tail.size() < 2:
		return PackedFloat32Array()
	var out := PackedFloat32Array()
	out.resize(AudioFeatures.WAVE_SAMPLES)
	var last := float(tail.size() - 1)
	for i in out.size():
		var x := last - float(out.size() - 1 - i) / float(AudioFeatures.WAVE_RATE) * rate
		if x < 0.0:
			continue
		var j := int(x)
		var a := tail[j]
		var b := tail[mini(j + 1, tail.size() - 1)]
		var v := a.lerp(b, x - float(j))
		out[i] = (v.x + v.y) * 0.5
	return out


## A WAV file's shape, read once from its header: `{offset, frames, channels, rate, bits, float}` (where its samples begin,
## how many frames, ...); {} where it is not a 16-bit or float WAV.
static func wav_info(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null or f.get_length() < 44 or f.get_buffer(4).get_string_from_ascii() != "RIFF":
		return {}
	f.get_32()
	if f.get_buffer(4).get_string_from_ascii() != "WAVE":
		return {}
	var fmt := {}
	while f.get_position() + 8 <= f.get_length():
		var id := f.get_buffer(4).get_string_from_ascii()
		var size := f.get_32()
		var at := f.get_position()
		if id == "fmt ":
			var kind := f.get_16()
			var channels := f.get_16()
			var rate := f.get_32()
			f.get_32()
			f.get_16()
			var bits := f.get_16()
			if kind == 0xFFFE and size >= 26:
				f.get_16()
				f.get_16()
				f.get_32()
				kind = f.get_16()
			fmt = {"channels": channels, "rate": rate, "bits": bits, "float": kind == 3}
		elif id == "data" and not fmt.is_empty():
			var ok := (not bool(fmt["float"]) and int(fmt["bits"]) == 16) or (bool(fmt["float"]) and int(fmt["bits"]) == 32)
			if not ok or int(fmt["channels"]) < 1:
				return {}
			var frame := int(fmt["channels"]) * int(fmt["bits"]) / 8
			var out := fmt.duplicate()
			out["offset"] = at
			out["frames"] = mini(size, f.get_length() - at) / frame
			return out
		f.seek(at + size + (size & 1))
	return {}


## The window of the WAV at [param path] (its [param info], [method wav_info]) ending [param at] seconds into it, read off the
## disk; silence before its start and past its end.
static func of_wav(path: String, info: Dictionary, at: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(AudioFeatures.WAVE_SAMPLES)
	var rate := float(info["rate"])
	var ch := int(info["channels"])
	var wide := int(info["bits"]) / 8
	var frame := ch * wide
	var t0 := at - float(out.size() - 1) / float(AudioFeatures.WAVE_RATE)
	var s0 := clampi(int(floor(t0 * rate)) - 1, 0, int(info["frames"]))
	var s1 := clampi(int(ceil(at * rate)) + 2, 0, int(info["frames"]))
	if s1 <= s0:
		return out
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	f.seek(int(info["offset"]) + s0 * frame)
	var buf := f.get_buffer((s1 - s0) * frame)
	var n := buf.size() / frame
	var is_float := bool(info["float"])
	for i in out.size():
		var x := (t0 + float(i) / float(AudioFeatures.WAVE_RATE)) * rate - float(s0)
		var j := int(floor(x))
		if j < 0 or j >= n:
			continue
		var a := 0.0
		var b := 0.0
		var j1 := mini(j + 1, n - 1)
		for c in ch:
			if is_float:
				a += buf.decode_float(j * frame + c * 4)
				b += buf.decode_float(j1 * frame + c * 4)
			else:
				a += float(buf.decode_s16(j * frame + c * 2)) / 32768.0
				b += float(buf.decode_s16(j1 * frame + c * 2)) / 32768.0
		out[i] = lerpf(a, b, x - float(j)) / float(ch)
	return out
