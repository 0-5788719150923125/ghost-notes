extends Node

## THE SUBTITLES' SEA ([SubtitleSea]): the eye's harmonics raise waves that run back through the words
## already said. Synthetic bands and a synthetic eye; it holds that
##   - A QUIET VOICE STIRS THE WORDS JUST SAID: speech at the level a real take's bands sit (0.1-0.3 of
##     Spectrum's window, where the old fixed threshold read nothing) moves the letters just behind the eye
##     off their rest and keeps them moving (reported 2026-10-20: "about 2 or 3 words in an entire sentence
##     will be highlighted ... There is little to no movement"). THE CONTROL: the same eye in silence
##     stirs nothing, so the measure can fail;
##   - AND THEY SETTLE: letters far behind the eye are back at the rest color however loud the voice, and
##     no said letter is ever vivid (the next report, the same day: "too distracting. The colors are very
##     intense, and they never decay back to the baseline color");
##   - a wave runs BACK at SPEED and STAYS IN THE TEXT: a burst raised at one place is found SPEED letters
##     a second behind it however far the eye has gone on since (measured from the eye, it would ride along);
##   - each harmonic crests in its own hue: the fundamental pulls one way round the wheel, sibilance the other;
##   - paused, nothing moves; a seek starts calm;
##   - the places are the reading's letters, a gap one, read on as the words grow and over again when
##     they are replaced in place.
## tests/run_boot_probe.sh tests/show/subtitle_spectral_check.gd 60

const FPS := 30.0

var _fails := 0


func _ready() -> void:
	_stirs_and_settles()
	_runs_back()
	_own_hues()
	_pause_and_seek()
	_letters()
	print("subtitle_spectral_check: %s" % ("ALL OK" if _fails == 0 else "%d failures" % _fails))
	get_tree().quit(0 if _fails == 0 else 1)


## Spectrum's 64 bands with each harmonic named in [param loud] at its level (the rest silent).
func _bands(sea: SubtitleSea, loud: Dictionary) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(Spectrum.BAND_COUNT)
	var k := 0
	for key in SubtitleSea.HARMONICS:
		if loud.has(key):
			for b in range(sea._lo[k], sea._hi[k]):
				out[b] = float(loud[key])
		k += 1
	return out


## A reading voice at [param level]: syllables at 4.3 a second, a breath every 2.2 s, each harmonic a
## little off the others; [param level] 0 is silence.
func _voice(sea: SubtitleSea, t: float, level: float) -> PackedFloat32Array:
	var loud := {}
	var k := 0
	for key in SubtitleSea.HARMONICS:
		var syl := 0.5 + 0.5 * sin(TAU * 4.3 * t + float(k) * 0.9)
		loud[key] = 0.0 if fmod(t, 2.2) > 1.85 else level * (0.35 + 0.65 * syl * syl)
		k += 1
	return _bands(sea, loud)


## Run [param sea] from [param from] to [param to] seconds with the eye at 14 letters a second.
func _speak(sea: SubtitleSea, from: float, to: float, level: float) -> void:
	var t := from
	while t < to - 1e-6:
		sea.hear(_voice(sea, t, level), t)
		sea.emit(t, 14.0 * t)
		t += 1.0 / FPS


## The said letters' colors behind the flare, the eye at [param eye], on [param sea] at [param t].
func _colors(sea: SubtitleSea, t: float, eye: float) -> Array:
	var line := sea.line(0.0, int(eye) + 1, t)
	var out: Array = []
	for ci in range(0, int(eye - Subtitles.Overlay.FLARE - 1.0)):
		out.append(Subtitles.Overlay._glyph_color(0.6, ci, eye, line, 0))
	return out


func _stirs_and_settles() -> void:
	var calm := Color.from_hsv(0.6, Subtitles.Overlay.SAT_CALM, Subtitles.Overlay.VAL_CALM)
	var flare := int(Subtitles.Overlay.FLARE) + 1
	for level in [0.18, 0.0]:
		var sea := SubtitleSea.new()
		_speak(sea, 0.0, 8.0, level)
		var eye := 14.0 * 8.0
		var a := _colors(sea, 8.0, eye)
		_speak(sea, 8.0, 8.2, level)
		var b := _colors(sea, 8.2, eye)
		var off := 0.0
		var moved := 0.0
		var far := 0.0
		var vivid := 0.0
		for ci in a.size():
			var c: Color = a[ci]
			var d: Color = b[ci]
			var behind := int(eye) - ci
			var from_rest := absf(c.s - calm.s) + absf(c.v - calm.v)
			if behind >= flare and behind <= 20:
				off += from_rest / float(20 - flare + 1)
				moved += (absf(c.s - d.s) + absf(c.v - d.v) + absf(c.h - d.h)) / float(20 - flare + 1)
			elif behind >= 70:
				far = maxf(far, from_rest)
			vivid = maxf(vivid, c.s)
		if level > 0.0:
			_check(off > 0.04, "a quiet voice stirred the letters just behind the eye %.3f off their rest" % off)
			_check(moved > 0.015, "a quiet voice moved the letters just behind the eye %.3f in 0.2 s" % moved)
			_check(far < 0.02, "letters 70 behind the eye stood %.3f off their rest - the sea never settles" % far)
			_check(vivid < 0.6, "a said letter behind the flare reached saturation %.2f - too intense" % vivid)
		else:
			_check(off < 0.002 and moved < 0.002, "silence stirred the letters just behind the eye %.3f and moved them %.3f - the measure cannot fail"
				% [off, moved])


## A burst of the fundamental at letter 100 at 0.5 s, then the eye runs on at 20 letters a second in silence.
func _runs_back() -> void:
	var sea := SubtitleSea.new()
	var t := 0.0
	while t < 2.0 - 1e-6:
		var on := t >= 0.5 and t < 0.6
		sea.hear(_bands(sea, {"fundamental": 0.6} if on else {}), t)
		sea.emit(t, 100.0 if t < 0.6 else 100.0 + 20.0 * (t - 0.6))
		t += 1.0 / FPS
	t -= 1.0 / FPS
	var line := sea.line(0.0, 130, t)
	var front := -1
	var top := 0.0
	for p in 130:
		var y := absf(line[p * SubtitleSea.STRIDE])
		if front < 0 and y > 0.01:
			front = p
		top = maxf(top, y)
	var want := 100.0 - SubtitleSea.SPEED * (t - 0.5)
	_check(front >= 0 and absf(float(front) - want) < 5.0, "the wave raised at letter 100 had come back to letter %d, not %.0f (the eye is at %.0f now)"
		% [front, want, 100.0 + 20.0 * (t - 0.6)])
	_check(top > 0.05, "the wave had all but gone after 1.4 s (%.3f)" % top)


func _own_hues() -> void:
	var pulls := {}
	for key in ["fundamental", "sibilance"]:
		var sea := SubtitleSea.new()
		var t := 0.0
		while t < 2.0:
			sea.hear(_bands(sea, {key: 0.4 if t < 1.0 else 0.6 + 0.2 * sin(TAU * 3.0 * t)}), t)
			sea.emit(t, 60.0)
			t += 1.0 / FPS
		var line := sea.line(0.0, 60, t - 1.0 / FPS)
		var sum := 0.0
		for p in range(40, 60):
			sum += line[p * SubtitleSea.STRIDE + 1]
		pulls[key] = sum / 20.0
	_check(float(pulls.fundamental) < -0.01 and float(pulls.sibilance) > 0.01,
		"the fundamental's crests pulled the hue %.3f and sibilance's %.3f - each harmonic should crest in its own" % [pulls.fundamental, pulls.sibilance])


func _pause_and_seek() -> void:
	var sea := SubtitleSea.new()
	_speak(sea, 0.0, 3.0, 0.3)
	var t := 3.0 - 1.0 / FPS
	var before := sea.line(0.0, 50, t)
	var levels := sea.levels.duplicate()
	for i in 5:                           # five frames paused: the clock stands
		sea.hear(_voice(sea, 1.3, 0.5), t)
		sea.emit(t, 14.0 * t)
	_check(sea.line(0.0, 50, t) == before and sea.levels == levels, "the sea moved while time stood still")
	sea.hear(_voice(sea, 0.5, 0.3), 0.5)
	sea.emit(0.5, 7.0)
	var calm := true
	for v in sea.line(0.0, 50, 0.5):
		calm = calm and v == 0.0
	_check(calm, "a seek back kept the waves of where the reading had been")


func _letters() -> void:
	var subs := Subtitles.new()
	var words: Array = [{"text": "ab", "t0": 0.0, "t1": 0.2, "sentence": 0}, {"text": "cde", "t0": 0.2, "t1": 0.5, "sentence": 0}]
	subs.words = words
	_check(subs.letter_of(0) == 0 and subs.letter_of(1) == 3 and subs.letter_of(2) == 7, "a word's first letter is not counted through the reading, a gap one")
	words.append({"text": "fghi", "t0": 0.5, "t1": 0.9, "sentence": 1})
	_check(subs.letter_of(3) == 12, "the letters were not read on as the words grew")
	words.clear()
	words.append({"text": "xyzzy", "t0": 0.0, "t1": 0.4, "sentence": 0})
	words.append({"text": "q", "t0": 0.4, "t1": 0.5, "sentence": 0})
	_check(subs.letter_of(1) == 6, "the letters of words replaced in place were the old words'")
	subs._cursor = 1.5
	_check(is_equal_approx(subs._eye_letter(), 6.5), "the eye halfway through the second word is not at its letter 6.5")
	subs.free()


func _check(ok: bool, reason: String) -> void:
	if not ok:
		_fails += 1
		printerr("subtitle_spectral_check: " + reason)
