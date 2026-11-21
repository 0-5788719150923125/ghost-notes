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
##     part's notes and no other's (the control: the rolled part does change), and draws its own pattern and sound (the
##     voice its singer); rolling the song's moves every part.
##   - THE WORDS ON THE BARS THE REFERENCE SINGS: with a made reference whose voice sings bars 8-15 and 24-31, a verse
##     of eight lines and a chorus of eight land there, a line a bar - the control a reference singing elsewhere moves
##     them; the bars between are an intro, a break and an outro.
##   - A composed line puts its stressed syllables on strong beats more than its unstressed ones; every sung note sits
##     inside its line's bars; the melody is moved by octaves into the singer's range.
##   - The music host's spec carries every part and the sung takes, and survives JSON; with a vocoder, the line's notes
##     in the mix's seconds for it to play.
##   - A Key chosen over a reference moves its chords by the nearest interval (C to D, up two; C to B, down one), the
##     control the reference's own key leaving them; the song's seed draws each part's instrument and pattern where none
##     is set - another seed, another band - and a part the author set stays; a reference's heard parts are the song's.
##   - A ROLL DRAWS EVERYTHING LEFT OPEN: at likeness 0 twelve rolls over a reference draw many tempos, keys, drum
##     patterns and forms, chords of their own, some swung and some straight, both singers; the control, likeness 1,
##     keeps the reference's tempo, key, chords and form in every roll; at one half, some rolls keep the form and some
##     do not; a part pinned to the reference keeps its form, and a tempo set stays. Swing moves an offbeat eighth to
##     its swing and leaves the beats: a swung score's offbeat hats land there, a straight one's on the half beat.
##   - A ROLL ON THE CARD DRAWS EVERY SETTING: `rolled` keeps the note's own, the words' pins, the parts and what is
##     muted, nothing else; rolls draw Likeness, each part's level and the vocoder on some voices - the control, each
##     set, stays set.
##   - THE BANK: every pattern of every part plays notes; every sound is made by a method the music host has; every
##     mode a key is drawn in has progressions written for it.
##   - THE GROOVE LEADS: the drums' pattern set is the song's groove - drum and bass drawn at its fast tempo, a shuffle
##     swinging, the control a song left to roll ranging far wider; the band follows it (under trap drums far more of
##     the basses are hip hop's than under a shuffle); a twelve-bar blues, its chords dominant sevenths, comes up
##     under a shuffle.

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
	_band()
	_roll()
	_rolled()
	_bank()
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
	var sounds := {}
	var bass_kept := true
	for n in range(2, 26):
		var r := _block()
		r["parts"]["drums"]["seed"] = n
		var sc := Composer.score(r, {"lyrics": lyrics})
		sounds["%s/%s" % [_part(sc, "drums")["pattern"], _part(sc, "drums")["instrument_key"]]] = true
		bass_kept = bass_kept and _part(sc, "bass")["instrument_key"] == _part(a, "bass")["instrument_key"] \
			and _part(sc, "bass")["pattern"] == _part(a, "bass")["pattern"]
	_ok(sounds.size() >= 4 and bass_kept, "a part's roll draws its own pattern and sound (%d of them in 24 rolls), the bass's kept" % sounds.size())
	var singers := {}
	for n in range(2, 26):
		var r := _block()
		r["parts"]["vocal"]["seed"] = n
		singers[String(Composer.score(r, {"lyrics": lyrics})["vocal"]["singer"]["name"])] = true
	_ok(singers.size() == Composer.SINGERS.size(), "...the voice's its singer (%d of %d)" % [singers.size(), Composer.SINGERS.size()])
	var song_rolled := _block()
	song_rolled["seed"] = 8
	var d := Composer.score(song_rolled, {"lyrics": lyrics})
	var moved := 0
	for k in ["drums", "bass", "keys", "pad"]:
		moved += 1 if JSON.stringify(_part(a, k)["notes"]) != JSON.stringify(_part(d, k)["notes"]) \
			or JSON.stringify(_part(a, k)["instrument"]) != JSON.stringify(_part(d, k)["instrument"]) else 0
	_ok(moved == 4, "rolling the song moves every part (%d of 4)" % moved)
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
	var s := Composer.score({"seed": 1, "likeness": 1.0}, {"lyrics": words, "reference": _reference([[8, 16], [24, 32]])})
	var kinds: Array = []
	var at := {}
	for sec in s["sections"]:
		kinds.append(String(sec["kind"]))
		at[String(sec["kind"])] = int(sec["bar"])
	_ok(kinds == ["intro", "verse", "break", "chorus", "outro"], "an intro, the verse, a break, the chorus, an outro: %s" % str(kinds))
	_ok(int(at.get("verse", -1)) == 8 and int(at.get("chorus", -1)) == 24, "the verse lands on bar 8, the chorus on 24: %s" % str(at))
	var moved := Composer.score({"seed": 1, "likeness": 1.0}, {"lyrics": words, "reference": _reference([[4, 12], [20, 28]])})
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
				if in_beats < -0.6 or in_beats > Composer.METER * 4 + 0.01:
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
	var center := int(Composer.SINGER_CENTER[Composer._voice_of(v["singer"])])
	_ok(absi(median - center) <= 6, "the melody sits in the singer's range: median %d, %s's center %d" % [median, String(v["singer"]["name"]), center])
	var spec := Composer.render_spec(s, [{"wav": "/x/take.wav", "at": 1.0}], "/x", "mix.wav")
	var back: Variant = JSON.parse_string(JSON.stringify(spec))
	_ok(back is Dictionary and ((back as Dictionary)["parts"] as Array).size() == (s["parts"] as Array).size()
		and ((back as Dictionary)["vocals"] as Array).size() == 1, "the music host's spec carries every part and the sung takes, through JSON")


func _band() -> void:
	var words := Lyrics.parse(SONG)
	var ref := _reference([[8, 16], [24, 32]])
	var roots := func(block: Dictionary) -> Array:
		var out: Array = []
		for c in Composer.score(block.merged({"likeness": 1.0}), {"lyrics": words, "reference": ref})["chords"]:
			out.append(int(c["root"]))
		return out
	_ok(roots.call({}) == [0, 5], "the reference's chords as read, in its own key: %s" % str(roots.call({})))
	_ok(roots.call({"key": "D major"}) == [2, 7] and roots.call({"key": "B major"}) == [11, 4],
		"a Key over a reference moves its chords: D up two %s, B down one %s" % [str(roots.call({"key": "D major"})), str(roots.call({"key": "B major"}))])
	var drawn := func(seed: int) -> String:
		var out := PackedStringArray()
		for k in ["keys", "pad", "guitar", "lead", "bells", "bass"]:
			var c := Composer.choice_of(k, {}, seed, {})
			out.append("%s/%s" % [c["pattern"], c["instrument"]])
		return ",".join(out)
	var bands := {}
	for seed in range(1, 9):
		bands[drawn.call(seed)] = true
	_ok(bands.size() >= 4, "the song's seed draws the band: %d bands from eight seeds" % bands.size())
	var set := Composer.choice_of("keys", {"instrument": "organ", "pattern": "block"}, 5, {})
	_ok(String(set["instrument"]) == "organ" and String(set["pattern"]) == "block", "a part the author set stays as set")
	var heard := {"parts": ["drums", "pad"], "drums": {"A": {}}, "voice": {"0": {}}}
	_ok(Composer.default_parts(heard, true) == ["drums", "pad", "vocal"] and Composer.default_parts(heard, false) == ["drums", "pad"],
		"a reference's heard parts are the song's, the voice where there are words")
	_ok(String(Composer.choice_of("drums", {}, 1, heard)["pattern"]) == "reference", "...its drums play its own pattern")
	var s := Composer.score({"seed": 2, "parts": {"vocal": {"pattern": "composed", "vocoder": 1.0}}}, {"lyrics": words})
	var spec := Composer.render_spec(s, [{"wav": "/x/a.wav", "at": 0.0}], "/x", "mix.wav")
	var voc: Dictionary = (spec["vocals"] as Array)[0]
	var first: Dictionary = s["vocal"]["phrases"][0]
	_ok(float(voc.get("vocoder", 0.0)) == 1.0 and not (voc.get("notes", []) as Array).is_empty()
		and is_equal_approx(float(voc["notes"][0]["t"]), float(first["at"]) + float(first["words"][0]["notes"][0]["t"])),
		"with a vocoder the spec carries the line's notes in the mix's seconds")


func _roll() -> void:
	var words := Lyrics.parse(SONG)
	var ref := _reference([[8, 16], [24, 32]])
	var band := {"drums": {}, "bass": {}, "keys": {}, "vocal": {}}
	var of := func(seed: int, like: float, more := {}) -> Dictionary:
		return Composer.score({"seed": seed, "likeness": like, "parts": band.duplicate(true)}.merged(more, true),
			{"lyrics": words, "reference": ref})
	var ref_roots := [0, 5]
	var roots_of := func(sc: Dictionary) -> Array:
		var out: Array = []
		for c in sc["chords"]:
			out.append(int(c["root"]))
		return out
	var tempos := {}
	var keys := {}
	var drums := {}
	var forms := {}
	var singers := {}
	var swung := 0
	var own := 0
	var free := 0
	for seed in range(1, 13):
		var sc: Dictionary = of.call(seed, 0.0)
		tempos[int(sc["tempo"])] = true
		keys["%d %s" % [int(sc["key"]["tonic"]), String(sc["key"]["scale"])]] = true
		drums[String(_part(sc, "drums")["pattern"])] = true
		forms[JSON.stringify((sc["sections"] as Array).map(func(x: Dictionary) -> int: return int(x["bars"])))] = true
		singers[String(sc["vocal"]["singer"]["name"])] = true
		swung += 1 if float(sc["roll"]["swing"]) > 0.5 else 0
		own += 1 if roots_of.call(sc) != ref_roots else 0
		free += 1 if not bool(sc["roll"]["form"]) else 0
	_ok(tempos.size() >= 8 and keys.size() >= 6 and drums.size() >= 3,
		"at likeness 0, twelve rolls draw %d tempos, %d keys, %d drum patterns" % [tempos.size(), keys.size(), drums.size()])
	_ok(free == 12 and own == 12 and forms.size() >= 3,
		"...every form and every set of chords its own (%d, %d of 12), %d forms" % [free, own, forms.size()])
	_ok(swung > 0 and swung < 12 and singers.size() == Composer.SINGERS.size(),
		"...%d of 12 swung, %d singers" % [swung, singers.size()])
	var kept := 0
	for seed in range(1, 9):
		var sc: Dictionary = of.call(seed, 1.0)
		kept += 1 if int(sc["tempo"]) == 100 and int(sc["key"]["tonic"]) == 0 and String(sc["key"]["scale"]) == "major" \
			and roots_of.call(sc) == ref_roots and bool(sc["roll"]["form"]) else 0
	_ok(kept == 8, "the control, likeness 1: every roll keeps the reference's tempo, key, chords and form (%d of 8)" % kept)
	var with_form := 0
	for seed in range(1, 17):
		with_form += 1 if bool(of.call(seed, 0.5)["roll"]["form"]) else 0
	_ok(with_form > 0 and with_form < 16, "at one half, some rolls keep the reference's form and some do not (%d of 16)" % with_form)
	var pinned := 0
	for seed in range(1, 7):
		var sc: Dictionary = of.call(seed, 0.0, {"parts": {"drums": {"pattern": "reference"}, "vocal": {}}})
		pinned += 1 if bool(sc["roll"]["form"]) else 0
	_ok(pinned == 6, "a part pinned to the reference keeps its form at likeness 0 (%d of 6)" % pinned)
	_ok(int(of.call(3, 0.0, {"tempo": 133.0})["tempo"]) == 133, "a tempo set stays set")
	_ok(is_equal_approx(Composer.warp(1.5, 0.62), 1.62) and is_equal_approx(Composer.warp(2.0, 0.62), 2.0)
		and is_equal_approx(Composer.warp(1.25, 0.62), 1.31) and is_equal_approx(Composer.warp(1.5, 0.5), 1.5),
		"swing moves an offbeat eighth to its swing, a sixteenth with it, and leaves the beats")
	var swung_at := -1.0
	var straight_at := -1.0
	for seed in range(1, 40):
		var sc: Dictionary = Composer.score({"seed": seed, "tempo": 100.0, "parts": {"drums": {"pattern": "backbeat"}}}, {"lyrics": []})
		var sw := float(sc["roll"]["swing"])
		var off := _offbeat_hat(sc)
		if sw > 0.5 and swung_at < 0.0:
			swung_at = absf(off - sw)
		elif sw <= 0.5 and straight_at < 0.0:
			straight_at = absf(off - 0.5)
	_ok(swung_at >= 0.0 and swung_at < 0.02 and straight_at >= 0.0 and straight_at < 0.02,
		"a swung score's offbeat hats land at its swing (off by %.3f), a straight one's on the half beat (%.3f)" % [swung_at, straight_at])


func _rolled() -> void:
	var words := Lyrics.parse(SONG)
	var tuned := {"source": "composed", "reference": {"path": "/x.mp3"}, "place": {"1": 8}, "seed": 9, "tempo": 120.0,
		"key": "C major", "likeness": 0.8, "harmony": "reference",
		"parts": {"drums": {"pattern": "trap", "instrument": "kit_808", "seed": 4, "level": -3.0},
			"vocal": {"singer": {"name": "af_heart"}, "tune": 0.5, "vocoder": 1.0, "mute": true}}}
	var r := Composer.rolled(tuned, 77)
	var want := {"source": "composed", "reference": {"path": "/x.mp3"}, "place": {"1": 8}, "seed": 77,
		"parts": {"drums": {}, "vocal": {"mute": true}}}
	_ok(JSON.stringify(r) == JSON.stringify(want),
		"a roll keeps the note's own, its words' pins, its parts and what is muted, and nothing else: %s" % JSON.stringify(r))
	_ok(JSON.stringify(Composer.part_rolled(tuned["parts"]["vocal"], 5)) == JSON.stringify({"mute": true, "seed": 5}),
		"...a part rolled alone keeps only whether it is muted, with a number of its own")
	var ref := _reference([[8, 16], [24, 32]])
	var likes := {}
	var levels := {}
	var vocoded := 0
	for seed in range(1, 25):
		var sc := Composer.score({"seed": seed, "parts": {"drums": {}, "bass": {}, "vocal": {}}}, {"lyrics": words, "reference": ref})
		likes[float(sc["roll"]["likeness"])] = true
		levels[float(_part(sc, "bass")["level"])] = true
		vocoded += 1 if float(sc["vocal"]["vocoder"]) > 0.0 else 0
	_ok(likes.size() >= 8 and levels.size() >= 6 and vocoded > 0 and vocoded < 24,
		"rolls draw Likeness (%d values in 24), each part's level (%d), the vocoder on some voices (%d of 24)" % [likes.size(), levels.size(), vocoded])
	var set := Composer.score({"seed": 3, "likeness": 0.8, "parts": {"bass": {"level": -7.0}, "vocal": {"vocoder": 0.0}}},
		{"lyrics": words, "reference": ref})
	_ok(float(set["roll"]["likeness"]) == 0.8 and float(_part(set, "bass")["level"]) == -7.0 and float(set["vocal"]["vocoder"]) == 0.0,
		"...the control: each set, stays set")


func _bank() -> void:
	var words := Lyrics.parse(SONG)
	var silent: Array = []
	for k in SongParts.PARTS:
		if k == "vocal":
			continue
		for p in SongParts.patterns_for(k):
			var parts := {"drums": {"pattern": "backbeat"}}
			parts[k] = {"pattern": p}
			var plays := false
			for seed in range(3, 9):  # a roll's line-up may leave the part out of a short song
				var sc := Composer.score({"seed": seed, "tempo": 120.0, "parts": parts}, {"lyrics": words})
				plays = plays or not (_part(sc, k).get("notes", []) as Array).is_empty()
			if not plays:
				silent.append("%s/%s" % [k, p])
	_ok(silent.is_empty(), "every pattern of every part plays notes (silent: %s)" % str(silent))
	var py := FileAccess.get_file_as_string("res://hosts/music/instruments.py")
	var at := py.find("METHODS = {")
	var methods := py.substr(at, py.find("}", at) - at) if at >= 0 else ""
	var unmade: Array = []
	for key in Instruments.ROWS:
		if not methods.contains("\"%s\"" % String(Instruments.ROWS[key]["method"])) or (Instruments.ROWS[key]["parts"] as Array).is_empty():
			unmade.append(key)
	_ok(not methods.is_empty() and unmade.is_empty(), "every sound is made by a method the music host has (not: %s)" % str(unmade))
	var bare: Array = Composer.MODES.filter(func(m: String) -> bool: return SongParts.progressions_for(m).is_empty())
	_ok(bare.is_empty(), "every mode a key is drawn in has progressions (none for %s)" % str(bare))
	var fast := true
	var shuffled := true
	var lo := 999.0
	var hi := 0.0
	for seed in range(1, 25):
		var a := Composer.score({"seed": seed, "parts": {"drums": {"pattern": "two_step"}, "bass": {}}}, {"lyrics": words})
		fast = fast and float(a["tempo"]) >= 164.0 and float(a["tempo"]) <= 178.0
		var b := Composer.score({"seed": seed, "parts": {"drums": {"pattern": "shuffle"}, "bass": {}}}, {"lyrics": words})
		shuffled = shuffled and is_equal_approx(float(b["roll"]["swing"]), 0.67)
		var c := Composer.score({"seed": seed, "parts": {"drums": {}, "bass": {}}}, {"lyrics": words})
		lo = minf(lo, float(c["tempo"]))
		hi = maxf(hi, float(c["tempo"]))
	_ok(fast and shuffled, "the drums' pattern set is the song's groove: drum and bass drawn at 164-178 BPM, a shuffle swinging")
	_ok(hi - lo > 60.0, "...the control: a song left to roll ranges %d-%d BPM" % [int(lo), int(hi)])
	var share := func(beat: String) -> float:
		var hits := 0
		for seed in range(1, 61):
			var song := Composer.drawn({"seed": seed}, {}, {"drums": {"pattern": beat}, "bass": {}})
			var c := Composer.choice_of("bass", {}, seed, {}, false, song)
			hits += 1 if (Registry.field(SongParts.PATTERNS, String(c["pattern"]), "styles", []) as Array).has("hiphop") else 0
		return hits / 60.0
	var trap: float = share.call("trap")
	var shuffle: float = share.call("shuffle")
	_ok(trap > 0.3 and trap > shuffle * 3.0,
		"the band follows the groove: under trap drums %d%% of the basses are hip hop's, under a shuffle %d%%" % [int(trap * 100), int(shuffle * 100)])
	var blues := 0
	for seed in range(1, 41):
		var sc := Composer.score({"seed": seed, "key": "E major", "tempo": 100.0, "parts": {"drums": {"pattern": "shuffle"}, "bass": {}}},
			{"lyrics": words})
		for ch in sc["chords"]:
			if int(ch["root"]) == 4 and String(ch["quality"]) == "7":
				blues += 1
				break
	_ok(blues > 0, "a twelve-bar blues, its home chord a dominant seventh, comes up under a shuffle (%d of 40 songs)" % blues)


## Where in the beat a score's offbeat hats fall (the most common fraction past the half beat's neighborhood).
func _offbeat_hat(sc: Dictionary) -> float:
	var beat := float(sc["beat"])
	var start := float(sc["start"])
	for n in _part(sc, "drums")["notes"]:
		if String(n.get("hit", "")) != "hat":
			continue
		var b := (float(n["t"]) - start) / beat
		var f := b - floorf(b)
		if f > 0.4 and f < 0.75:
			return f
	return -1.0


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
