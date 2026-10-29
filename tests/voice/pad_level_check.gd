extends SceneTree

## Gate for THE BED UNDER ANY VOICE ([constant VoiceFX.PAD_VOICE_REF]; 2026-10-28, the user: "Even at max
## volume, the 'ambience' level is almost inaudible with the newly-implemented Kokoro models" - Kokoro's Puck
## came out more than twice libritts-high's level, and the bed, at a fixed level, sat 17 dB under it where it
## sits 9 under Piper):
##
## - a voice LOUD times as loud gets the bed LOUD times as loud, second by second - the intro's bed (primed
##   with the key) and the duck under the words with it - so the balance is the same whatever the voice;
## - THE CONTROL: a whisper, a tenth of the voice, is under [constant VoiceFX.PAD_SCALE_MIN], and its bed is
##   held there instead of following it down - the same measure finds that bed NOT scaled with its voice.
##
## Run: godot --headless --path . --script tests/voice/pad_level_check.gd

const SR := 22050
const INTRO := 4.0
const SECS := 60.0
## Puck against this voice, about: the voice here speaks at 0.42 of the reference, Puck at 2.
const LOUD := 4.7
const WHISPER := 0.1

var _fails: Array = []


func _init() -> void:
	var dry := _voice()
	var one := _bed(dry, 1.0)
	var loud := _bed(dry, LOUD)
	var soft := _bed(dry, WHISPER)
	var k_one := float(one["k"])
	var k_loud := float(loud["k"])
	_ok(k_one > VoiceFX.PAD_SCALE_MIN and k_loud < VoiceFX.PAD_SCALE_MAX,
		"the voice and the loud one are inside the scale's range (%.2f, %.2f)" % [k_one, k_loud])
	var worst_loud := _worst(one["bed"], loud["bed"], LOUD)
	var worst_soft := _worst(one["bed"], soft["bed"], WHISPER)
	_ok(worst_loud < 0.5,
		"a voice %.1f times as loud gets its bed %.1f times as loud in every second, the intro and the duck with it (at worst %.2f dB off)"
		% [LOUD, LOUD, worst_loud])
	_ok(worst_soft > 6.0 and float(soft["k"]) == VoiceFX.PAD_SCALE_MIN,
		"the control: a whisper's bed is held at the scale's floor, not taken down with it (%.1f dB over a tenth)" % worst_soft)
	print("pad_level_check: scale %.2f for the voice, %.2f %.1f times as loud, %.2f for a whisper"
		% [k_one, k_loud, LOUD, float(soft["k"])])
	if _fails.is_empty():
		print("pad_level_check: ALL OK")
		quit(0)
	else:
		for f in _fails:
			print("pad_level_check: FAIL  " + f)
		quit(1)


## The bed alone over [param dry] times [param k] (Ambience 1.0, every other effect off: what the chain adds), and
## the scale the chain ended on.
func _bed(dry: PackedFloat32Array, k: float) -> Dictionary:
	var v := PackedFloat32Array()
	v.resize(dry.size())
	for i in dry.size():
		v[i] = dry[i] * k
	var fx := VoiceFX.new()
	fx.pad_seed = 12345
	fx.setup(SR)
	fx.echo_wet = 0.0
	fx.resonance = 0.0
	fx.presence = 1.0
	fx.pad = 1.0
	fx.room.from_dial(0.0, 0.0)
	fx.prime_key(v)
	var bed := PackedFloat32Array()
	var pos := 0
	while pos < v.size():
		var c := v.slice(pos, mini(pos + 4096, v.size()))
		var o := fx.process(c.duplicate())
		for i in o.size():
			o[i] -= c[i]
		bed.append_array(o)
		pos += 4096
	return {"bed": bed, "k": fx._pad_k}


## How far [param b]'s level is from [param k] times [param a]'s, at worst over the seconds either sounds in (dB).
func _worst(a: PackedFloat32Array, b: PackedFloat32Array, k: float) -> float:
	var worst := 0.0
	var s := 0
	while s + SR <= a.size():
		var ea := 0.0
		var eb := 0.0
		for i in range(s, s + SR):
			ea += a[i] * a[i]
			eb += b[i] * b[i]
		if ea > 1e-9:
			worst = maxf(worst, absf(10.0 * log(eb / ea) / log(10.0) - 20.0 * log(k) / log(10.0)))
		s += SR
	return worst


## A silent intro, then phrases: 3 s of a buzzing "voice" with a syllable envelope and a pitch glide, a 1.5 s
## pause ([code]ambience_severity_check[/code]'s).
func _voice() -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(int((INTRO + SECS) * SR))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var ph := 0.0
	var base := 120.0
	var glide := 0.0
	var last := -1
	for i in range(int(INTRO * SR), buf.size()):
		var t := float(i) / SR - INTRO
		if int(t / 4.5) != last:
			last = int(t / 4.5)
			base = rng.randf_range(105.0, 135.0)
			glide = rng.randf_range(-0.2, 0.2)
		var into := fmod(t, 4.5)
		ph += TAU * base * (1.0 + glide * into / 3.0) / SR
		var syl := 0.5 + 0.5 * sin(TAU * 4.0 * t)
		buf[i] = (sin(ph) + 0.5 * sin(2.0 * ph) + 0.3 * sin(3.0 * ph)) * 0.05 * syl \
			if into < 3.0 else 0.0
	return buf


func _ok(cond: bool, msg: String) -> void:
	print(("   ok   " if cond else "   FAIL ") + msg)
	if not cond:
		_fails.append(msg)
