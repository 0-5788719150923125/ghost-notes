extends SceneTree

## composer_check - a composed Sound's score ([Composer], [Lyrics], [MusicTheory]; next/music.md).
##
##   godot --headless --path . --script res://tests/music/composer_check.gd
##
## What it holds:
##   - Lyrics: a section's name alone on a line starts it (`Verse`, `[Chorus]`), `x2` sings the section so far again, a
##     blank line ends a stanza, a heading naming no section is not sung, and each word carries its syllables and stress.
##   - Theory: a scale's degrees, the diatonic triads of C major, voice leading that moves each voice by a step or less
##     between C and F, and E(3,8) the tresillo.
##   - The score is a pure function: the same block and words make the same score; rolling one part's seed moves that
##     part's notes and no other's (the control: the rolled part does change).
##   - THE WORDS ON THE BARS THE REFERENCE SINGS: with a made reference whose voice sings bars 8-15 and 24-31, a verse
##     of eight lines and a chorus of eight land there, a line a bar - the control a reference singing elsewhere moves
##     them; the bars between are an intro, a break and an outro.
##   - A composed line puts its stressed syllables on strong beats more than its unstressed ones; every sung note sits
##     inside its line's bars; the melody is moved by octaves into the singer's range.
##   - The music host's spec carries every part and the sung takes, and survives JSON.

var _fails := 0

const SONG := """# A test song

Verse

Welcome random user
To my soliloquy
Sit and listen closely
You will learn of me

[Chorus]
Error me found
Trying to shutdown now
x2
"""


func _init() -> void:
	_lyrics()
	_theory()
	_pure()
	_placement()
	_voice()
	if _fails == 0:
		print("composer_check: ALL OK")
		quit(0)
		return
	print("composer_check: %d FAILED" % _fails)
	quit(1)


func _lyrics() -> void:
	var secs := Lyrics.parse(SONG)
	_ok(secs.size() == 2 and String(secs[0]["kind"]) == "verse" and String(secs[1]["kind"]) == "chorus",
		"two sections, a verse and a chorus; the title is not sung (%d)" % secs.size())
	_ok((secs[0]["lines"] as Array).size() == 4 and (secs[1]["lines"] as Array).size() == 4,
		"x2 sings the chorus's two lines again: %d lines" % (secs[1]["lines"] as Array).size())
	var welcome: Dictionary = secs[0]["lines"][0]["words"][0]
	_ok(int(welcome["syllables"]) == 2 and int(welcome["stress"][0]) == 1,
		"\"Welcome\" is two syllables, stressed first: %s" % str(welcome))
	_ok(int(secs[1]["lines"][2]["stanza"]) > int(secs[1]["lines"][1]["stanza"]), "a repeat is a stanza of its own")


func _theory() -> void:
	_ok(MusicTheory.scale_of(0, "major") == [0, 2, 4, 5, 7, 9, 11], "C major's pitch classes")
	var ii := MusicTheory.diatonic(0, "major", 1)
	var vii := MusicTheory.diatonic(0, "major", 6)
	_ok(int(ii["root"]) == 2 and String(ii["quality"]) == "m" and String(vii["quality"]) == "dim", "ii is D minor, vii B diminished")
	var c := MusicTheory.voice_lead([], [0, 4, 7], 3, 55, 76)
	var f := MusicTheory.voice_lead(c, [5, 9, 0], 3, 55, 76)
	var most := 0
	for i in 3:
		most = maxi(most, absi(int(f[i]) - int(c[i])))
	_ok(most <= 2, "C to F voice-led: no voice moves more than a step (%s -> %s)" % [str(c), str(f)])
	_ok(MusicTheory.euclid(3, 8) == [true, false, false, true, false, false, true, false], "E(3,8) is the tresillo")


func _block() -> Dictionary:
	return {"seed": 7, "tempo": 100.0, "key": "C major",
		"parts": {"drums": {"seed": 1}, "bass": {"seed": 1}, "pad": {"seed": 1}, "keys": {"seed": 1}, "vocal": {"pattern": "composed"}}}


func _pure() -> void:
	var lyrics := Lyrics.parse(SONG)
	var a := Composer.score(_block(), {"lyrics": lyrics})
	var b := Composer.score(_block(), {"lyrics": lyrics})
	_ok(JSON.stringify(a) == JSON.stringify(b), "the same block and words make the same score")
	var rolled := _block()
	rolled["parts"]["drums"]["seed"] = 2
	var c := Composer.score(rolled, {"lyrics": lyrics})
	var drums_moved := JSON.stringify(_part(a, "drums")["notes"]) != JSON.stringify(_part(c, "drums")["notes"])
	var bass_same := JSON.stringify(_part(a, "bass")["notes"]) == JSON.stringify(_part(c, "bass")["notes"])
	var voice_same := JSON.stringify(a["vocal"]) == JSON.stringify(c["vocal"])
	_ok(drums_moved, "the control: rolling the drums' seed moves the drums")
	_ok(bass_same and voice_same, "...and nothing else: the bass and the voice stay")
	_ok(not (_part(a, "bass")["notes"] as Array).is_empty() and String((_part(a, "drums")["instrument"] as Dictionary)["method"]) == "kit",
		"the bass plays, and the drums are a kit")


func _reference(sung_at: Array) -> Dictionary:
	var sung: Array = []
	for b in 40:
		var on := false
		for r in sung_at:
			if b >= int(r[0]) and b < int(r[1]):
				on = true
		sung.append(0.9 if on else 0.0)
	return {"tempo": 100.0, "beat": 0.6, "offset": 0.2, "bars": 40, "key": {"tonic": 0, "mode": "major"},
		"chords": [{"bar": 0, "beat": 0, "root": 0, "quality": ""}, {"bar": 2, "beat": 0, "root": 5, "quality": ""}],
		"sections": [], "drums": {}, "melody": [], "sung": sung}


func _placement() -> void:
	var words := Lyrics.parse("Verse\none\ntwo\nthree\nfour\nfive\nsix\nseven\neight\nChorus\na\nb\nc\nd\ne\nf\ng\nh\n")
	var s := Composer.score({"seed": 1}, {"lyrics": words, "reference": _reference([[8, 16], [24, 32]])})
	var kinds: Array = []
	var at := {}
	for sec in s["sections"]:
		kinds.append(String(sec["kind"]))
		at[String(sec["kind"])] = int(sec["bar"])
	_ok(kinds == ["intro", "verse", "break", "chorus", "outro"], "an intro, the verse, a break, the chorus, an outro: %s" % str(kinds))
	_ok(int(at.get("verse", -1)) == 8 and int(at.get("chorus", -1)) == 24, "the verse lands on bar 8, the chorus on 24: %s" % str(at))
	var moved := Composer.score({"seed": 1}, {"lyrics": words, "reference": _reference([[4, 12], [20, 28]])})
	var v := -1
	for sec in moved["sections"]:
		if String(sec["kind"]) == "verse":
			v = int(sec["bar"])
	_ok(v == 4, "the control: a reference singing from bar 4 moves the verse there (%d)" % v)
	_ok(absf(float(s["start"]) - 0.2) < 1e-6 and absf(float(s["tempo"]) - 100.0) < 1e-6, "the reference's grid: its tempo and first downbeat")


func _voice() -> void:
	var lyrics := Lyrics.parse(SONG)
	var s := Composer.score(_block(), {"lyrics": lyrics})
	var v: Dictionary = s["vocal"]
	_ok((v["phrases"] as Array).size() == 8, "a phrase a sung line: %d" % (v["phrases"] as Array).size())
	var strong_stressed := 0.0
	var n_stressed := 0
	var strong_weak := 0.0
	var n_weak := 0
	var beat := float(s["beat"])
	var all: Array = []
	var inside := true
	for p in v["phrases"]:
		var bar_t := float(s["start"]) + int(p["bar"]) * Composer.METER * beat
		var line := _line_of(lyrics, String(p["text"]))
		var stresses: Array = []
		for w in line.get("words", []):
			stresses.append_array(w["stress"])
		var k := 0
		for w in p["words"]:
			for nt in w["notes"]:
				var t := float(p["at"]) + float(nt["t"])
				all.append(int(nt["midi"]))
				var in_beats := (t - bar_t) / beat
				if in_beats < -0.6 or in_beats > Composer.METER * 2 + 0.01:
					inside = false
				var strong := absf(in_beats - round(in_beats)) < 0.02 and int(round(in_beats)) % 2 == 0
				if k < stresses.size():
					if int(stresses[k]) == 1:
						strong_stressed += 1.0 if strong else 0.0
						n_stressed += 1
					else:
						strong_weak += 1.0 if strong else 0.0
						n_weak += 1
				k += 1
	_ok(inside, "every sung note sits in its line's bars")
	var rs := strong_stressed / maxf(n_stressed, 1)
	var rw := strong_weak / maxf(n_weak, 1)
	_ok(rs > rw, "stressed syllables land on strong beats more than unstressed ones (%.2f against %.2f)" % [rs, rw])
	all.sort()
	var median := int(all[all.size() / 2]) if not all.is_empty() else 0
	_ok(absi(median - int(Composer.SINGER_CENTER["m"])) <= 6, "the melody sits in the singer's range: median %d" % median)
	var spec := Composer.render_spec(s, [{"wav": "/x/take.wav", "at": 1.0}], "/x", "mix.wav")
	var back: Variant = JSON.parse_string(JSON.stringify(spec))
	_ok(back is Dictionary and ((back as Dictionary)["parts"] as Array).size() == (s["parts"] as Array).size()
		and ((back as Dictionary)["vocals"] as Array).size() == 1, "the music host's spec carries every part and the sung takes, through JSON")


func _line_of(lyrics: Array, text: String) -> Dictionary:
	for sec in lyrics:
		for l in sec["lines"]:
			if String(l["text"]) == text:
				return l
	return {}


func _part(score: Dictionary, key: String) -> Dictionary:
	for p in score["parts"]:
		if String(p["key"]) == key:
			return p
	return {}


func _ok(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)
