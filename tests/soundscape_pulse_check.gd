extends SceneTree

## NOTHING IN A PLACE PULSES - a gate of [Soundscape] beside tests/soundscape_check.gd (which runs
## close to its five minutes on a busy machine, so this is its own).
##
##   godot --headless --path . --script tests/soundscape_pulse_check.gd
##
## The user, 2026-10-12, of a boat at sea under an awning (True Tarot 647530: the sea against the
## hull, the wind through canvas): "weird bursts of oscillation sound happening, over and over. It
## almost sounds like a fan spinning." Noise chopped by a sine is a machine, and two parts of that
## place were that. The flap was fixed first ("the wind sounds fine"); a slosh with its pulse made
## uneven was not ("the water still has the oscillation sounds, and it's still pretty bad"), and
## measured part by part it was also the loudest thing in the water - 5 dB over the slap it trails.
##
## - THE WASH after a hull's slaps, heard alone, does not pulse: its loudness, moved along by one
##   pulse's length, does not come back on itself - against the slosh as it was, pulsed at one rate.
## - ...AND IT IS UNDER ITS SLAP, and there: its loudest moment is below the slaps' own and no
##   more than 12 dB below (it was 5 dB above).
## - AN AWNING'S FLAPS, heard alone, come at no one rate - against a flap as it was: one band
##   pulsed deep at one rate.
## - ...AND THEY ARE THERE: cloth that makes no sound in a gusty wind would pass the rest.

var _fails := 0
const SR := 22050


func _init() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("  FAIL: " + what)


func _run() -> void:
	var done: Variant = _one_rate()
	_ok(done == true, "the check stopped part way (a script error - see above)")
	print("soundscape_pulse_check: %s (%d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _fails, "" if _fails == 1 else "s"])
	quit(1 if _fails > 0 else 0)


static func _rms(pcm: PackedVector2Array, a := 0, b := -1) -> Vector2:
	if b < 0:
		b = pcm.size()
	var s := Vector2.ZERO
	for i in range(a, b):
		s += pcm[i] * pcm[i]
	var n := float(maxi(1, b - a))
	return Vector2(sqrt(s.x / n), sqrt(s.y / n))


func _make(sound: Dictionary, wind: Dictionary, seed := 3, dial := 0.5) -> Soundscape:
	var table := {"sound": sound}
	if not wind.is_empty():
		table["light"] = {"wind": wind}
	var made := Soundscape.of_table(table, seed)
	var sc := Soundscape.new(made["sound"], made["wind"], seed, SR, 0.0)
	sc.set_level(dial)
	return sc


## HOW MUCH A SOUND PULSES AT ONE RATE: its loudness every [param step] seconds, in windows of
## [param win] seconds, against itself moved along by a pulse's length (every length from 1 /
## [param fmax] to 1 / [param fmin] seconds, the best of them) - the median over its loud quarter. A
## steady pulse returns on itself (toward 1); uneven events and a ragged pulse do not, and neither
## does a slow swell, which returns as well at half that length.
static func _returns(pcm: PackedVector2Array, step: float, win: float, fmin: float, fmax: float) -> float:
	var d := int(step * SR)
	var env := PackedFloat32Array()
	for k in pcm.size() / d:
		env.append(_rms(pcm, k * d, (k + 1) * d).length())
	var er := 1.0 / step
	var w := int(win * er)
	var rows: Array = []
	var s := 0
	while s + w <= env.size():
		var mean := 0.0
		for i in w:
			mean += env[s + i]
		mean /= float(w)
		var den := 1e-18
		var level := 0.0
		for i in w:
			den += pow(env[s + i] - mean, 2.0)
			level += env[s + i] * env[s + i]
		# a swell returns on itself too, at every length: only a return that stands over the one
		# at HALF its length is a pulse (between two beats of a steady pulse there is none)
		var first := int(er / fmax)
		var last := int(er / fmin)
		var r := PackedFloat32Array()
		r.resize(last + 1)
		for lag in range(first / 2, last + 1):
			var sum := 0.0
			for i in w - lag:
				sum += (env[s + i] - mean) * (env[s + i + lag] - mean)
			r[lag] = sum / den
		var best := 0.0
		for lag in range(first, last + 1):
			best = maxf(best, r[lag] - maxf(r[lag / 2], 0.0))
		rows.append([level, best])
		s += w / 2
	rows.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	var loud: Array = []
	for i in maxi(1, rows.size() / 4):
		loud.append(float(rows[i][1]))
	loud.sort()
	return float(loud[loud.size() / 2])


## [param sc] with only [param keep] of its noise bands sounding (and none of the wind's body).
static func _only(sc: Soundscape, keep: Array) -> Soundscape:
	var bands: Array[Soundscape.Band] = []
	for b in keep:
		bands.append(b)
	sc._bands = bands
	if sc._w.has("eddies"):
		sc._w["eddies"] = []
	return sc


## The loudest moment of [param pcm], in dB.
static func _peak(pcm: PackedVector2Array) -> float:
	var most := 0.0
	for v in pcm:
		most = maxf(most, maxf(absf(v.x), absf(v.y)))
	return linear_to_db(most + 1e-9)


func _one_rate() -> bool:
	# THE WASH after a hull's slaps: plain, and under them
	var sea := {"water": {"kind": "hull", "size": 0.6}}
	var now := _make(sea, {}, 647530)
	var wash_pcm := _only(now, now._wa["sloshes"]).render(SR * 30)
	var plain := _returns(wash_pcm, 0.0025, 0.8, 6.0, 20.0)
	var old := _make(sea, {}, 647530)
	for b in old._wa["sloshes"]:
		(b as Soundscape.Band).am_depth = 0.55
		(b as Soundscape.Band).am_rate = 12.0
	var motor := _returns(_only(old, old._wa["sloshes"]).render(SR * 30), 0.0025, 0.8, 6.0, 20.0)
	_ok(plain < 0.3, "the wash after a slap pulses: its loudness returns on itself by %.2f (under 0.3)" % plain)
	_ok(motor > plain + 0.25 and motor > 0.4, "the control: the slosh pulsed at one rate is not found steady (%.2f against %.2f)" % [motor, plain])
	var slaps := _make(sea, {}, 647530)
	var under := _peak(wash_pcm) - _peak(_only(slaps, slaps._wa["slaps"]).render(SR * 30))
	_ok(under < -1.0 and under > -12.0, "the wash is not under its slap, or not there: %.1f dB beside it (between -12 and -1)" % under)
	# AN AWNING'S FLAPS: one at a time, uneven
	var wind := {"every": 10.0, "from": "front left", "gusts": 0.9, "strength": 0.6}
	var awning := {"wind": {"through": "canvas"}}
	var cloth := _make(awning, wind, 647530)
	var flaps := _returns(_only(cloth, cloth._w["flaps"]).render(SR * 45), 0.01, 5.0, 1.5, 10.0)
	var fan := _make(awning, wind, 647530)
	var blade: Soundscape.Band = fan._band(0, 1, 230.0, 1.2, false)
	blade.am_depth = 1.0
	blade.am_rate = 3.1
	blade.gl = 0.05
	blade.gr = 0.05
	var spun := _returns(_only(fan, [blade]).render(SR * 45), 0.01, 5.0, 1.5, 10.0)
	_ok(flaps < 0.3, "an awning's flaps come at one rate: their loudness returns on itself by %.2f (under 0.3)" % flaps)
	_ok(spun > flaps + 0.3 and spun > 0.7, "the control: one band pulsed deep at one rate is not found steady (%.2f against %.2f)" % [spun, flaps])
	# ...and they are there: cloth that makes no sound in a gusty wind proves nothing
	_ok(_rms(cloth.render(SR * 10)).length() > 1e-4, "the awning's flaps are not heard at all")
	print("  wash %.2f (pulsed at one rate %.2f), %.1f dB beside its slap; flaps %.2f (one band at one rate %.2f)" % [plain, motor, under, flaps, spun])
	return true
