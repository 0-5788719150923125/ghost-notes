extends RefCounted
class_name SubtitleSea

## SubtitleSea - the water the subtitles' color moves on.
##
## THE TAIL RAISES THE WAVES (the user, 2026-10-20: "the tail of the text (the new text) is causing
## 'ripples' in the color, through the harmonics, which propagates backwards through that older text").
## The line is a one-dimensional sea - a place is a letter, the gap between two words one more - and the
## voice is a source on it, where the reading's eye is ([method emit]). Each HARMONIC of the voice, a band
## of its spectrum ([constant HARMONICS]), rings there at a swell of its own, as high as the band is loud
## lately; the wave runs back through the words already said at [constant SPEED] letters a second and dies
## out over the harmonic's `reach`, so the water is only ever rough near the tail. What a letter shows is
## the sum ([method line]): how high the water stands there and the hue the harmonics cresting there pull
## it toward - the overlay lights it by both and lets it settle with distance from the eye.
##
## QUIET, AND IT DIES OUT (the user, of the first sea: "too distracting. The colors are very intense, and
## they never decay back to the baseline color ... something more natural, more subtle, and something that
## probably decays with distance from the tail"). That sea's longest wave ran 160 letters, a reflection off
## the line's first letter kept the start of every long line rough, and each syllable threw a flash back
## through the whole line; the reaches are a third of that now, the loudness follows the phrase rather than
## the syllable ([constant ATTACK], each harmonic's `release`), and there is no reflection and no flash.
##
## It replaced eight lights, each a fixed run of three letters tied to one FFT band with a fixed threshold
## ("about 2 or 3 words in an entire sentence will be highlighted ... There is little to no movement"). The
## threshold was the dull part: on a real take the speech bands sit at 0.1-0.3 of Spectrum's 60 dB window
## (take_7308f0: the 90th percentile of every band from 90 Hz to 10 kHz under 0.2), so `(raw - 0.10) * 2.5`
## read zero for nearly every frame. EACH HARMONIC IS HEARD AGAINST ITSELF ([method hear]): between its own
## running floor - the room, a soundscape under the voice - and its own recent peak.
##
## A WAVE BELONGS TO THE TEXT, NOT TO THE TAIL: what the source sent out is kept with where it stood
## ([member _g]), and the letter at p is reached at t by what left at the t0 where
## s(t0) - SPEED * (t - t0) = p. So the waves behind a speaking voice are stretched as a moving source's
## are, and through a pause they roll on out of the words where they were raised while the source calms.
## Measured from the tail instead, the pattern would ride along with the voice: at a reading pace, nearly
## standing still in the text.
##
## A function of show time and the bands it is handed: paused, nothing moves; a seek, a loop or a new take
## starts calm; a render at a fixed rate sees the same sea every time.

## THE HARMONICS: `band`, the voice's frequencies it hears (Hz); `swell`, how fast its wave rises and falls
## where it is raised (Hz - a letter behind a speaking voice sees about half that); `reach`, the letters it
## runs before it has fallen to a third; `hue`, how far round the wheel its crests pull a letter (a turn is
## 1); `release`, how long its loudness takes to fall when the band goes quiet (s).
const HARMONICS := {
	"fundamental": {"label": "Fundamental", "blurb": "The voice's own pitch and its first overtones: the long, slow swell, the last to die out.",
		"band": [90.0, 250.0], "swell": 0.55, "reach": 50.0, "hue": -0.045, "release": 0.9},
	"first_formant": {"label": "First formant", "blurb": "The open vowels' body: a broad wave a little quicker than the swell.",
		"band": [250.0, 700.0], "swell": 0.8, "reach": 42.0, "hue": -0.018, "release": 0.75},
	"second_formant": {"label": "Second formant", "blurb": "What tells one vowel from another: its waves turn the hue near the tail as the vowels change.",
		"band": [700.0, 1800.0], "swell": 1.1, "reach": 34.0, "hue": 0.022, "release": 0.6},
	"third_formant": {"label": "Third formant", "blurb": "The brightness of the voice: quicker ripples that die out a word or two back.",
		"band": [1800.0, 4000.0], "swell": 1.5, "reach": 26.0, "hue": 0.05, "release": 0.45},
	"sibilance": {"label": "Sibilance", "blurb": "The hiss of s, sh, f and t: a fine stir just behind the tail.",
		"band": [4000.0, 10000.0], "swell": 2.0, "reach": 18.0, "hue": 0.08, "release": 0.35},
}
## Letters a second every wave runs back (a word of five letters and its gap in about 0.4 s - a reading
## voice says some 15 letters a second, so the waves are left behind it, as a boat leaves its wake).
const SPEED := 15.0
## How quickly a harmonic's loudness rises (s) - slow enough to follow the phrase, not each syllable - and
## THE LEVEL A HARMONIC IS HEARD AGAINST: its floor falls to a quiet band in FLOOR_FALL and creeps up in
## FLOOR_RISE (so the bed under a voice is the floor, and a voice that never pauses is not); its peak jumps
## to a loud one and sinks back in PEAK_FALL; and the two are never closer than RANGE of the window
## (3.6 dB), so a quiet room's breath is no wave.
const ATTACK := 0.12
const FLOOR_FALL := 0.25
const FLOOR_RISE := 8.0
const PEAK_FALL := 5.0
const RANGE := 0.06
## The seconds of what the source sent out that are kept: far longer than any wave lasts.
const MEMORY := 12.0
## How much cresting it takes to pull a letter halfway to the hue of the harmonics cresting there.
const HUE_HOLD := 0.35
## What [method line] hands back per letter.
const STRIDE := 2

var _k := 0                               # harmonics
var _lo := PackedInt32Array()             # each harmonic's bands in Spectrum's 64: [lo, hi)
var _hi := PackedInt32Array()
var _swell := PackedFloat32Array()
var _reach := PackedFloat32Array()
var _hue := PackedFloat32Array()
var _release := PackedFloat32Array()
var _phase := PackedFloat32Array()        # so the swells do not all crest at t = 0

## What is heard at the source right now: each harmonic's loudness 0..1.
var levels := PackedFloat32Array()
var _floor := PackedFloat32Array()
var _peak := PackedFloat32Array()
var _heard := -1.0

## WHAT THE SOURCE SENT OUT, oldest first, from [member _at] on: when, where it stood, the two together
## as `s + SPEED * t` (never falling, so a letter's moment is found by a walk), and its [member levels].
var _t := PackedFloat64Array()
var _s := PackedFloat64Array()
var _g := PackedFloat64Array()
var _a := PackedFloat32Array()
var _at := 0


func _init() -> void:
	_k = HARMONICS.size()
	var ratio := Spectrum.FREQ_MAX / Spectrum.FREQ_MIN
	var n := Spectrum.BAND_COUNT
	var i := 0
	for key in HARMONICS:
		var row: Dictionary = HARMONICS[key]
		var band: Array = row["band"]
		var lo := floori(float(n) * log(float(band[0]) / Spectrum.FREQ_MIN) / log(ratio))
		var hi := ceili(float(n) * log(float(band[1]) / Spectrum.FREQ_MIN) / log(ratio))
		_lo.append(clampi(lo, 0, n - 1))
		_hi.append(clampi(hi, lo + 1, n))
		_swell.append(float(row["swell"]))
		_reach.append(float(row["reach"]))
		_hue.append(float(row["hue"]))
		_release.append(float(row["release"]))
		_phase.append(fposmod(float(i) * 0.618034, 1.0) * TAU)
		i += 1
	levels.resize(_k)
	_floor.resize(_k)
	_peak.resize(_k)
	for k in _k:
		_peak[k] = RANGE


## HEAR [param bands] (Spectrum's, this frame - none is silence) at reading time [param t]: each
## harmonic's loudness, eased by show time - paused, nothing changes - against its own floor and peak. A
## step back or a jump of more than two seconds (a seek, a loop, a new take) is silence.
func hear(bands: PackedFloat32Array, t: float) -> void:
	var dt := t - _heard if _heard >= 0.0 else 0.0
	_heard = t
	if dt < 0.0 or dt > 2.0:
		levels.fill(0.0)
		return
	if dt == 0.0:
		return
	var heard := bands.size() >= Spectrum.BAND_COUNT
	for k in _k:
		var raw := 0.0
		if heard:
			for b in range(_lo[k], _hi[k]):
				raw += bands[b]
			raw /= float(_hi[k] - _lo[k])
		var fl := _floor[k]
		_floor[k] = lerpf(fl, raw, 1.0 - exp(-dt / (FLOOR_FALL if raw < fl else FLOOR_RISE)))
		var pk := _peak[k]
		_peak[k] = maxf(raw if raw > pk else lerpf(pk, _floor[k] + RANGE, 1.0 - exp(-dt / PEAK_FALL)), _floor[k] + RANGE)
		var x := clampf((raw - _floor[k]) / (_peak[k] - _floor[k]), 0.0, 1.0)
		var old := levels[k]
		levels[k] = lerpf(old, x, 1.0 - exp(-dt / (ATTACK if x > old else _release[k])))


## SEND OUT what is heard now, from where the source stands at reading time [param t] ([param source], in
## letters through the whole reading). Nothing is sent while time stands still; a step back in time or in
## place, or a jump of more than two seconds, drops every wave - a sea starts calm.
func emit(t: float, source: float) -> void:
	var n := _t.size()
	if n > _at:
		var last := _t[n - 1]
		if t < last - 0.05 or t - last > 2.0 or source < _s[n - 1] - 4.0:
			clear()
		elif t <= last:
			return
	n = _t.size()
	_t.append(t)
	_s.append(source)
	_g.append(maxf(source + SPEED * t, _g[n - 1] + 1e-6 if n > _at else -INF))
	_a.append_array(levels)
	while _at < _t.size() - 2 and _t[_at + 1] < t - MEMORY:
		_at += 1
	if _at > 512:
		_t = _t.slice(_at)
		_s = _s.slice(_at)
		_g = _g.slice(_at)
		_a = _a.slice(_at * _k)
		_at = 0


func clear() -> void:
	_t.clear()
	_s.clear()
	_g.clear()
	_a.clear()
	_at = 0


## THE SEA ALONG A LINE at [param t]: [constant STRIDE] values for each of [param n] letters from
## [param p0] (the line's first letter, in the letters [method emit] was handed) - how high the water
## stands there (about -1..1 at the tail) and the hue the cresting harmonics pull it toward (a share of a
## turn). A letter no wave has reached, or every wave has passed, is calm: both zero.
func line(p0: float, n: int, t: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n * STRIDE)
	if _t.size() - _at < 2:
		return out
	var hint := _at
	for i in n:                           # what reaches p left later the further on p is: one walk
		var p := p0 + float(i)
		var target := p + SPEED * t
		hint = _find(target, hint)
		if hint < 0:
			hint = _at
			continue
		var j := hint
		var f := clampf((target - _g[j]) / maxf(_g[j + 1] - _g[j], 1e-9), 0.0, 1.0)
		var t0 := lerpf(_t[j], _t[j + 1], f)
		var dist := maxf(lerpf(_s[j], _s[j + 1], f) - p, 0.0)
		var y := 0.0
		var hue := 0.0
		var crest := 0.0
		for k in _k:
			var a := lerpf(_a[j * _k + k], _a[(j + 1) * _k + k], f) * exp(-dist / _reach[k])
			if a < 0.002:
				continue
			var h := sin(TAU * _swell[k] * t0 + _phase[k])
			y += a * h
			var c := a * (0.5 + 0.5 * h)
			hue += c * _hue[k]
			crest += c
		out[i * STRIDE] = y
		out[i * STRIDE + 1] = hue / (HUE_HOLD + crest)
	return out


## The step of what was sent out in which `s + SPEED * t` crosses [param target] - the j with
## g[j] <= target < g[j + 1] - walked from [param hint]; -1 when it lies outside what is kept (a wave
## not yet sent, or sent before the sea began).
func _find(target: float, hint: int) -> int:
	var last := _g.size() - 1
	if last - _at < 1 or target < _g[_at] or target > _g[last]:
		return -1
	var j := clampi(hint, _at, last - 1)
	while j < last - 1 and _g[j + 1] <= target:
		j += 1
	while j > _at and _g[j] > target:
		j -= 1
	return j
