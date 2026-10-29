extends SceneTree

## Gate for THE BED IN THE VOICE'S OWN KEY, AND THE BASS UNDER IT ([constant VoiceFX.KEY_HEARD],
## [constant VoiceFX.PAD_REGISTER], [constant VoiceFX.BASS_UNDER]; 2026-10-28, the user: "a very strange tone
## being 'plucked' a few times per minute, and it's a super distracting, dissonant sound ... always the same tone"
## - on Puck, the key taken from the reading's first, high, window was C where he speaks at A#, and the bass's
## partials sat in his own register, the second a whole step over him):
##
## - the key's root is two octaves under the MIDDLE of the voice's pitch as far as it is known when the key is set -
##   the voiced windows of [constant VoiceFX.PAD_PRIME] primed, the first KEY_HEARD live - where the first voiced
##   window, which the key had been taken from, is a few semitones over it (the control);
## - live, nothing of the bed sounds before KEY_HEARD voiced windows are heard;
## - the key holds through the reading, though a tenth of the tracked windows are an octave up (the tracker's
##   own slips) - which pull an average of the pitch in Hz well off the middle (the control);
## - a low voice's every swell has its second partial BASS_UNDER under the voice's middle - where a voice with
##   room under it keeps its bass in [BASS_ROOT_LO, 2 BASS_ROOT_LO), as before (the control) - and a voice too deep
##   for a bass over BASS_FLOOR under it has none;
## - THE BED IS HEARD UNDER A LOW VOICE AS UNDER A HIGH ONE ([constant VoiceFX.PAD_AUDIBLE]; the user, of the bed
##   in Puck's key: "far too quiet. I can barely hear it at all anymore" - every tone under 80 Hz): what a small
##   speaker plays of it, its power over 100 Hz, against the voice, within 6 dB of a high voice's - where with its
##   tones plain (the control: no octave partials, no lift) a low voice's is far under it.
##
## Run: godot --headless --path . --script tests/voice/pad_key_check.gd

const SR := 22050
const INTRO := 2.0
const SECS := 90.0
const LOW := 125.0              # a low man's middle: the old bass's second partial was on it
const DEEP := 98.0              # under A2: no room under it for a bass over BASS_FLOOR
const HIGH := 204.0             # Heart's

var _fails: Array = []


## The bed as it was before the ear staged it (the control): every tone plain, nothing lifted.
class Plain extends VoiceFX:
	func _start_tone() -> void:
		super._start_tone()
		for k in VoiceFX.PAD_VOICES:
			if _p_state[k] == 1 and _p_env[k] == 0.0:
				_p_h2[k] = 0.0
				_p_h4[k] = 0.0
				_p_n[k] = 1.0

	func _ear() -> void:
		_ear_k = 1.0


func _init() -> void:
	var low := _voice(LOW)
	var heard := _heard(low)
	var mid: float = heard["mid"]
	var primed := _run(low, true)
	var live := _run(low, false)
	var p_mid := float(heard["primed_mid"])
	var l_mid := float(heard["live_mid"])
	_ok(absf(float(primed["key"]) + 24.0 - p_mid) < 0.01 and absf(float(heard["first"]) - p_mid) >= 2.0,
		"primed, the key is two octaves under the middle of the voice's first %.0f s, not its first window (%.1f semitones off, the control)"
		% [VoiceFX.PAD_PRIME, float(heard["first"]) - p_mid])
	_ok(absf(float(live["key"]) + 24.0 - l_mid) < 0.01 and absf(float(heard["first"]) - l_mid) >= 1.5
		and float(live["key_at"]) >= float(heard["enough_at"]) - 0.01
		and float(live["tone_at"]) >= float(live["key_at"]) and float(live["swell_at"]) >= float(live["key_at"]),
		"live, the key is set once %d voiced windows are heard (%.2f s in), under their middle - not the first (%.1f off) - and nothing sounds before it"
		% [VoiceFX.KEY_HEARD, float(live["key_at"]), float(heard["first"]) - l_mid])
	_ok(int(primed["keys"]) == 1 and int(live["keys"]) == 1 and float(heard["mean"]) - mid > 1.5,
		"the key holds through %.0f s of the voice though a tenth of its windows are an octave up, which pull its mean %.1f semitones over the middle (the control)"
		% [SECS, float(heard["mean"]) - mid])
	var under := true
	for sw in primed["swells"]:
		under = under and VoiceFX._semis(float(sw) * 2.0) <= mid - VoiceFX.BASS_UNDER + 0.01
	_ok(not (primed["swells"] as Array).is_empty() and under,
		"a low voice's every swell (%d) has its second partial %.0f semitones or more under its middle"
		% [(primed["swells"] as Array).size(), VoiceFX.BASS_UNDER])
	var high := _run(_voice(HIGH), true)
	var kept := true
	for sw in high["swells"]:
		kept = kept and float(sw) >= VoiceFX.BASS_ROOT_LO and float(sw) < VoiceFX.BASS_ROOT_LO * 2.0
	_ok(not (high["swells"] as Array).is_empty() and kept,
		"the control: a voice with room under it keeps its bass where it was (%d swells, %s Hz)"
		% [(high["swells"] as Array).size(), str((high["swells"] as Array).map(func(x): return snappedf(x, 0.1)))])
	var low_v := _voice(LOW)
	var high_v := _voice(HIGH)
	var heard_low := _audible(low_v, _bed(low_v, VoiceFX.new()))
	var heard_high := _audible(high_v, _bed(high_v, VoiceFX.new()))
	var plain_low := _audible(low_v, _bed(low_v, Plain.new()))
	_ok(absf(heard_low - heard_high) < 6.0 and heard_high - plain_low > 10.0,
		"a low voice's bed is heard over 100 Hz %.1f dB against it, a high voice's %.1f - plain, the low one's is %.1f (the control)"
		% [heard_low, heard_high, plain_low])
	var deep := _run(_voice(DEEP), true)
	_ok(int(deep["cued"]) > 0 and (deep["swells"] as Array).is_empty(),
		"a voice at %.0f Hz plays no swell (%d cued), where its bass would be under %.1f Hz" % [DEEP, int(deep["cued"]),
		VoiceFX.BASS_FLOOR])
	if _fails.is_empty():
		print("pad_key_check: ALL OK")
		quit(0)
	else:
		for f in _fails:
			print("pad_key_check: FAIL  " + f)
		quit(1)


## The bed alone over [param dry] in [param fx] (Ambience 1.0, every other effect off), primed.
func _bed(dry: PackedFloat32Array, fx: VoiceFX) -> PackedFloat32Array:
	fx.pad_seed = 12345
	fx.setup(SR)
	fx.echo_wet = 0.0
	fx.resonance = 0.0
	fx.pad = 1.0
	fx.room.from_dial(0.0, 0.0)
	fx.prime_key(dry)
	var out := PackedFloat32Array()
	var pos := 0
	while pos < dry.size():
		var c := dry.slice(pos, mini(pos + 4096, dry.size()))
		var o := fx.process(c.duplicate())
		for i in o.size():
			o[i] -= c[i]
		out.append_array(o)
		pos += 4096
	return out


## What a small speaker plays of [param bed] - its power over 100 Hz (two Butterworth sections) - against
## [param dry]'s power while it speaks (dB), from INTRO on.
func _audible(dry: PackedFloat32Array, bed: PackedFloat32Array) -> float:
	var hp := _highpass(_highpass(bed, 100.0), 100.0)
	var eb := 0.0
	var ev := 0.0
	var nv := 0
	for i in range(int(INTRO * SR), dry.size()):
		eb += hp[i] * hp[i]
		if dry[i] != 0.0:
			ev += dry[i] * dry[i]
			nv += 1
	return 10.0 * log((eb / float(dry.size() - int(INTRO * SR))) / (ev / float(nv))) / log(10.0)


## A Butterworth high-pass biquad at [param fc].
static func _highpass(x: PackedFloat32Array, fc: float) -> PackedFloat32Array:
	var w := TAU * fc / float(SR)
	var al := sin(w) / (2.0 * 0.7071)
	var a0 := 1.0 + al
	var b0 := (1.0 + cos(w)) * 0.5 / a0
	var b1 := -(1.0 + cos(w)) / a0
	var a1 := -2.0 * cos(w) / a0
	var a2 := (1.0 - al) / a0
	var y := PackedFloat32Array()
	y.resize(x.size())
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	for i in x.size():
		var v := b0 * x[i] + b1 * x1 + b0 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = x[i]
		y2 = y1
		y1 = v
		y[i] = v
	return y


## What the tracker hears of [param dry], in semitones: the middle of its voiced windows' pitch, of the first
## KEY_HEARD of them (as a live chain's windows fall, from the first sample), and of those of the PAD_PRIME seconds
## [method VoiceFX.prime_key] reads (from the first sound); its first; the mean of them in Hz; and when the
## KEY_HEARD-th ends (seconds).
func _heard(dry: PackedFloat32Array) -> Dictionary:
	var fx := VoiceFX.new()
	fx.setup(SR)
	var win := int(SR / VoiceFX.TRACK_HZ)
	var s := PackedFloat32Array()
	var hz := 0.0
	var enough := 0.0
	var p := 0
	while p + win <= dry.size():
		var f := fx._estimate_pitch(dry.slice(p, p + win))
		if f > 0.0:
			s.append(VoiceFX._semis(f))
			hz += f
			if s.size() == VoiceFX.KEY_HEARD:
				enough = float(p + win) / SR
		p += win
	var sound := 0
	while absf(dry[sound]) <= 0.004:
		sound += 1
	var primed := PackedFloat32Array()
	p = sound
	while p <= mini(dry.size() - win, sound + int(VoiceFX.PAD_PRIME * SR)):
		var f := fx._estimate_pitch(dry.slice(p, p + win))
		if f > 0.0:
			primed.append(VoiceFX._semis(f))
		p += win
	return {"mid": _middle(s), "live_mid": _middle(s.slice(0, VoiceFX.KEY_HEARD)), "primed_mid": _middle(primed),
		"first": s[0], "mean": VoiceFX._semis(hz / s.size()), "enough_at": enough}


static func _middle(s: PackedFloat32Array) -> float:
	var sorted := s.duplicate()
	sorted.sort()
	return sorted[sorted.size() / 2]


## The bed alone over [param dry], primed or not ([param primed]): the key at the end, how many keys it was in,
## when it was set, when the first tone and the first swell began (seconds), and each swell's root (Hz).
func _run(dry: PackedFloat32Array, primed: bool) -> Dictionary:
	var fx := VoiceFX.new()
	fx.pad_seed = 12345
	fx.setup(SR)
	fx.echo_wet = 0.0
	fx.resonance = 0.0
	fx.pad = 1.0
	fx.room.from_dial(0.0, 0.0)
	if primed:
		fx.prime_key(dry)
	var keys := {}
	var key_at := INF
	var tone_at := INF
	var swell_at := INF
	var swells: Array = []
	var cued := 0
	var pos := 0
	while pos < dry.size():
		var waiting: int = fx._bass_at
		var cool: float = fx._bass_cool
		fx.process(dry.slice(pos, mini(pos + 64, dry.size())))
		if fx._bass_cool > cool + 1.0:
			cued += 1
		pos += 64
		var t := float(pos) / SR
		if fx._key_semi > -1000.0:
			keys[snappedf(fx._key_semi, 0.01)] = true
			key_at = minf(key_at, t)
		for k in VoiceFX.PAD_VOICES:
			if fx._p_state[k] != 0:
				tone_at = minf(tone_at, t)
		if waiting >= 0 and fx._bass_at < 0:
			swells.append(fx._bass_hz)
		if fx._bass_env > 0.0:
			swell_at = minf(swell_at, t)
	return {"key": fx._key_semi, "keys": keys.size(), "key_at": key_at, "tone_at": tone_at, "swell_at": swell_at,
		"swells": swells, "cued": cued}


## A silent intro, then phrases round [param center] Hz: 3 s of a buzzing "voice" with a syllable envelope, each
## phrase a little over or under the middle and gliding, then a 1.5 s pause. The first phrase opens 3 semitones
## high, as a reading does; the last 0.45 s of each is a plain tone an octave up, as the tracker sometimes hears.
func _voice(center: float) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(int((INTRO + SECS) * SR))
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var ph := 0.0
	var base := center
	var glide := 0.0
	var last := -1
	for i in range(int(INTRO * SR), buf.size()):
		var t := float(i) / SR - INTRO
		if int(t / 4.5) != last:
			last = int(t / 4.5)
			base = center * pow(2.0, rng.randf_range(-1.5, 1.5) / 12.0)
			glide = rng.randf_range(-0.2, 0.2)
		var into := fmod(t, 4.5)
		if into >= 3.0:
			continue
		var f := base * (1.0 + glide * into / 3.0)
		if t < 0.25:
			f = center * pow(2.0, 3.0 / 12.0)
		var slip := into >= 2.55
		ph += TAU * f * (2.0 if slip else 1.0) / SR
		var syl := 0.5 + 0.5 * sin(TAU * 4.0 * t)
		buf[i] = (sin(ph) if slip else sin(ph) + 0.5 * sin(2.0 * ph) + 0.3 * sin(3.0 * ph)) * 0.05 * syl
	return buf


func _ok(cond: bool, msg: String) -> void:
	print(("   ok   " if cond else "   FAIL ") + msg)
	if not cond:
		_fails.append(msg)
