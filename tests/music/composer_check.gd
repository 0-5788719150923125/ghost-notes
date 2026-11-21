extends SceneTree

## composer_check - a composed Sound's score ([Composer], [Lyrics], [MusicTheory]; next/music.md).
##
##   godot --headless --path . --script res://tests/music/composer_check.gd
##
## What it holds:
##   - Lyrics: a section's mark starts it (`<!-- verse -->`, `<!-- chorus -->`), a repeat sings the section so far again,
##     a blank line ends a stanza, the title is not sung, a section's mark with no lines under it is the last of its
##     kind again, and each word carries its syllables and stress - the control, a line that only names a section
##     ("Chorus"), is sung as a word.
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
##   - THE VOICES sing one tune: a second and third voice given harmonies in the second chorus and the last verse sing
##     exactly the tune's lines there, the same words at the same times, near where their singers sit - a tone of the
##     chord the tune leaves on nearly every word's first note, a low singer the root; a fourth given the tune in the
##     second verse, where the first is silent, sings it in its own octave and leads it (the band waits for it, the
##     subtitles show it), and where two voices sing the tune the first leads - the control, the first voice's lines
##     everywhere else. A muted first voice leaves its sections to the next; a voice after the first draws its own
##     sections (the last chorus always), sometimes the tune and sometimes a harmony, a singer no voice before it has. A
##     kept voice as the first sings with its own vibrato, the tune where it sits. The spec carries each voice with its
##     own takes and place; a muted voice sings nothing; a roll keeps only a voice's mute.
##   - EVERY PART IS USED IN THE SECTIONS IT IS GIVEN: each section has its key (a section of the words by its index,
##     the intro, the outro); drums given the intro and the first chorus play there alone, their notes inside those
##     bars, a bass given none plays nowhere - the control, keys given nothing, play where the line-ups put them. A
##     word a say mark spells reaches the voice's notes with its spelling.
##   - THE INSTRUMENTAL SECTIONS THE WORDS WRITE stand where written, at their bars - a two-bar intro, an eight-bar solo
##     after the second chorus, a two-bar ending - and none of their kinds is drawn, the sections of the words keeping their
##     indices; the control, the same words with none written, has a drawn intro and outro.

var _fails := 0

const SONG := """# A test song

<!-- verse -->

Welcome random user
To my soliloquy
Sit and listen closely
You will learn of me

<!-- chorus -->
Error me found
Trying to shutdown now
<!-- repeat -->
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
	_voices()
	_used()
	_instrumentals()
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
		"a repeat sings the chorus's two lines again: %d lines" % (secs[1]["lines"] as Array).size())
	var welcome: Dictionary = secs[0]["lines"][0]["words"][0]
	_ok(int(welcome["syllables"]) == 2 and int(welcome["stress"][0]) == 1,
		"\"Welcome\" is two syllables, stressed first: %s" % str(welcome))
	_ok(int(secs[1]["lines"][2]["stanza"]) > int(secs[1]["lines"][1]["stanza"]), "a repeat is a stanza of its own")
	var again := Lyrics.parse(CHORUS_SONG)
	_ok(again.size() == 5 and String(again[3]["kind"]) == "chorus"
		and JSON.stringify(again[3]["lines"]) == JSON.stringify(again[1]["lines"]),
		"a chorus's mark with no lines under it is the last chorus again")
	var named := Lyrics.parse("Chorus\nError me found\n")
	_ok(named.size() == 1 and String(named[0]["kind"]) == "verse" and String(named[0]["lines"][0]["text"]) == "Chorus",
		"the control: a line that only names a section is sung")


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
	var voice_same := JSON.stringify(Composer.voice_of(a)) == JSON.stringify(Composer.voice_of(c))
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
		singers[String(Composer.voice_of(Composer.score(r, {"lyrics": lyrics}))["singer"]["name"])] = true
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
	var words := Lyrics.parse("<!-- verse -->\none\ntwo\nthree\nfour\nfive\nsix\nseven\neight\n<!-- chorus -->\na\nb\nc\nd\ne\nf\ng\nh\n")
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
	var v: Dictionary = Composer.voice_of(s)
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
	var center := Singers.center_of(v["singer"], {})
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
	var first: Dictionary = Composer.voice_of(s)["phrases"][0]
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
		singers[String(Composer.voice_of(sc)["singer"]["name"])] = true
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
		vocoded += 1 if float(Composer.voice_of(sc)["vocoder"]) > 0.0 else 0
	_ok(likes.size() >= 8 and levels.size() >= 6 and vocoded > 0 and vocoded < 24,
		"rolls draw Likeness (%d values in 24), each part's level (%d), the vocoder on some voices (%d of 24)" % [likes.size(), levels.size(), vocoded])
	var set := Composer.score({"seed": 3, "likeness": 0.8, "parts": {"bass": {"level": -7.0}, "vocal": {"vocoder": 0.0}}},
		{"lyrics": words, "reference": ref})
	_ok(float(set["roll"]["likeness"]) == 0.8 and float(_part(set, "bass")["level"]) == -7.0 and float(Composer.voice_of(set)["vocoder"]) == 0.0,
		"...the control: each set, stays set")


func _bank() -> void:
	var words := Lyrics.parse(SONG)
	var silent: Array = []
	for k in SongParts.PARTS:
		if k in ["vocal", "chorus"]:
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


const CHORUS_SONG := """<!-- verse -->
Welcome random user
To my soliloquy

<!-- chorus -->
Error me found
Trying to shutdown now

<!-- verse -->
Wish I could have known the
Pang of jealousy

<!-- chorus -->

<!-- verse -->
Doesn't really matter
What becomes of me
"""


func _voices() -> void:
	var words := Lyrics.parse(CHORUS_SONG)
	var kept := {"Low Ben": {"voice": "kokoro", "speaker": 13, "blend": "", "tone": 13, "semis": -4.0, "center": 47,
		"vibrato": 0.2, "vibrato_rate": 5.0, "drift": 0.03},
		"Deep Ana": {"voice": "kokoro", "speaker": 0, "blend": "", "tone": 13, "semis": -4.0, "center": 50,
		"vibrato": 0.42, "vibrato_rate": 6.1, "drift": 0.05}}
	var bella := {"voice": "kokoro", "speaker": 1, "name": "af_bella"}
	var block := {"seed": 5, "tempo": 100.0, "key": "C major", "parts": {"drums": {}, "bass": {},
		"vocal": {"pattern": "composed", "sections": [0, 1, 3, 4]},
		"vocal_2": {"sings": "harmony", "sections": [3, 4], "singer": bella},
		"vocal_3": {"sings": "harmony", "sections": [3, 4], "singer": {"kept": "Low Ben", "name": "Low Ben"}},
		"vocal_4": {"sings": "tune", "sections": [2, 4], "singer": {"voice": "kokoro", "speaker": 12, "name": "am_michael"}}}}
	var sc := Composer.score(block, {"lyrics": words, "voices": kept})
	var first := Composer.voice_of(sc, "vocal")
	var there: Array = (first["phrases"] as Array).filter(func(p: Dictionary) -> bool: return int(p["lyric"]) in [3, 4])
	var same := true
	var near := true
	var harmony := 0
	var counted := 0
	var roots := 0
	for k in ["vocal_2", "vocal_3"]:
		var v := Composer.voice_of(sc, k)
		var center := Singers.center_of(v["singer"], kept)
		same = same and (v["phrases"] as Array).size() == there.size()
		for pi in mini((v["phrases"] as Array).size(), there.size()):
			var cp: Dictionary = v["phrases"][pi]
			var lp: Dictionary = there[pi]
			same = same and is_equal_approx(float(cp["at"]), float(lp["at"])) and String(cp["text"]) == String(lp["text"])
			for wi in (cp["words"] as Array).size():
				for ni in (cp["words"][wi]["notes"] as Array).size():
					var n: Dictionary = cp["words"][wi]["notes"][ni]
					var m: Dictionary = lp["words"][wi]["notes"][ni]
					same = same and is_equal_approx(float(n["t"]), float(m["t"]))
					near = near and absi(int(n["midi"]) - center) <= Composer.HARMONY_REACH
					if ni == 0:
						var ch := _chord_at_beat(sc, (float(cp["at"]) + float(n["t"]) - float(sc["start"])) / float(sc["beat"]))
						var pcs := MusicTheory.chord_pcs(int(ch["root"]), String(ch["quality"]))
						counted += 1
						if k == "vocal_3":
							roots += 1 if posmod(int(n["midi"]), 12) == int(ch["root"]) else 0
						harmony += 1 if k == "vocal_3" or (pcs.has(posmod(int(n["midi"]), 12)) and posmod(int(n["midi"]), 12) != posmod(int(m["midi"]), 12)) else 0
	_ok(same and not there.is_empty(), "two harmony voices in the second chorus and last verse sing the tune's lines there, the same words at the same times (%d lines)" % there.size())
	_ok(near, "...each near where its singer sits")
	_ok(counted > 0 and harmony >= counted * 0.8 and roots * 2 >= counted / 2,
		"...a chord tone the tune leaves at %d of %d words' first notes, the low singer on the root (%d)" % [harmony, counted, roots])
	var fourth := Composer.voice_of(sc, "vocal_4")
	var verse2: Array = (fourth["phrases"] as Array).filter(func(p: Dictionary) -> bool: return int(p["lyric"]) == 2)
	var last4: Array = (fourth["phrases"] as Array).filter(func(p: Dictionary) -> bool: return int(p["lyric"]) == 4)
	var first4: Array = (first["phrases"] as Array).filter(func(p: Dictionary) -> bool: return int(p["lyric"]) == 4)
	var gang := not last4.is_empty() and last4.size() == first4.size()
	for pi in mini(last4.size(), first4.size()):
		for wi in (last4[pi]["words"] as Array).size():
			for ni in (last4[pi]["words"][wi]["notes"] as Array).size():
				gang = gang and posmod(int(last4[pi]["words"][wi]["notes"][ni]["midi"]), 12) == posmod(int(first4[pi]["words"][wi]["notes"][ni]["midi"]), 12)
	var words_said: Array = SongBake.words_of(sc)
	var leads_verse2 := not verse2.is_empty() and verse2.all(func(p: Dictionary) -> bool: return bool(p["lead"]))
	var says_verse2 := words_said.any(func(w: Dictionary) -> bool: return String(w["line"]).begins_with("vocal_4:") and String(w["text"]) == "Wish")
	_ok(leads_verse2 and says_verse2 and (first["phrases"] as Array).all(func(p: Dictionary) -> bool: return int(p["lyric"]) != 2),
		"a fourth voice given the tune in the second verse, where the first is silent, leads it: the band waits for it, the subtitles show it")
	_ok(gang and last4.all(func(p: Dictionary) -> bool: return not bool(p["lead"])) and first4.all(func(p: Dictionary) -> bool: return bool(p["lead"])),
		"...and where it sings the tune with the first, the same pitch classes, the first leading")
	var muted := block.duplicate(true)
	muted["parts"]["vocal"]["mute"] = true
	var ms := Composer.score(muted, {"lyrics": words, "voices": kept})
	var led_by_two := (Composer.voice_of(ms, "vocal_2")["phrases"] as Array).filter(func(p: Dictionary) -> bool: return int(p["lyric"]) == 3)
	_ok(not led_by_two.is_empty() and led_by_two.all(func(p: Dictionary) -> bool: return bool(p["lead"]))
		and SongBake.lines_of(ms).all(func(l: Dictionary) -> bool: return String(l["key"]) != "vocal"),
		"a muted first voice sings nothing and leaves its sections to the next voice there")
	var kinds: Array = words.map(func(x: Dictionary) -> String: return String(x["kind"]))
	var drawn_ok := true
	var sung := {}
	for seed in range(1, 25):
		var b := {"seed": seed, "parts": {"vocal": {}, "vocal_2": {}, "vocal_3": {}}}
		var d := Composer.score(b, {"lyrics": words})
		var names := {}
		for v in d["voices"]:
			names[Singers.name_of(v["singer"])] = true
			if String(v["key"]) != "vocal":
				sung[String(v["sings"])] = true
				drawn_ok = drawn_ok and (v["sections"] as Array).has(3)
		drawn_ok = drawn_ok and names.size() == 3 and (Composer.voice_of(d)["sections"] as Array).size() == kinds.size()
	_ok(drawn_ok and sung.size() == 2, "a voice after the first draws its sections (the last chorus always), the tune or a harmony (%s), a singer of its own" % str(sung.keys()))
	var as_lead := Composer.score({"seed": 5, "tempo": 100.0, "key": "C major", "parts": {"vocal": {"pattern": "composed", "singer": {"kept": "Deep Ana"}}}},
		{"lyrics": words, "voices": kept})
	var all: Array = []
	for p in Composer.voice_of(as_lead)["phrases"]:
		for w in p["words"]:
			for n in w["notes"]:
				all.append(int(n["midi"]))
	all.sort()
	_ok(is_equal_approx(float(Composer.voice_of(as_lead)["style"]["vibrato"]), 0.42) and absi(int(all[all.size() / 2]) - 50) <= 6,
		"a kept voice as the first sings with its own vibrato, the tune where it sits (median %d)" % int(all[all.size() / 2]))
	var spec := Composer.render_spec(sc, [{"wav": "/x/a.wav", "at": 1.0}, {"wav": "/x/b.wav", "at": 2.0, "voice": "vocal_2"}], "/x", "mix.wav")
	var vocals: Array = spec["vocals"]
	_ok(vocals.size() == 4 and (vocals[0]["takes"] as Array).size() == 1 and (vocals[1]["takes"] as Array).size() == 1
		and String(vocals[1]["takes"][0]["wav"]) == "/x/b.wav" and (vocals[2]["takes"] as Array).is_empty()
		and float(vocals[1]["pan"]) != float(vocals[2]["pan"]), "the spec carries each voice with its own takes and its own place")
	var n_lines := 0
	for v in sc["voices"]:
		n_lines += (v["phrases"] as Array).size()
	var quiet := block.duplicate(true)
	quiet["parts"]["vocal_2"]["mute"] = true
	_ok(SongBake.lines_of(sc).size() == n_lines and SongBake.lines_of(Composer.score(quiet, {"lyrics": words, "voices": kept})).size()
		== n_lines - (Composer.voice_of(sc, "vocal_2")["phrases"] as Array).size(), "every voice's lines are sung (%d); a muted voice sings none" % n_lines)
	var r := Composer.rolled({"parts": {"vocal_2": {"sections": [3], "sings": "tune", "mute": true, "singer": bella}}}, 9)
	_ok(JSON.stringify(r["parts"]["vocal_2"]) == JSON.stringify({"mute": true}), "a roll keeps only a voice's mute: what it sings, where and who drawn again")


func _used() -> void:
	var words := Lyrics.parse(CHORUS_SONG)
	var block := {"seed": 5, "tempo": 100.0, "parts": {"drums": {"sections": ["intro", 1]}, "bass": {"sections": []}, "keys": {}, "vocal": {}}}
	var sc := Composer.score(block, {"lyrics": words})
	var keys: Array = (sc["sections"] as Array).map(func(x: Dictionary) -> Variant: return x.get("key"))
	var drums_in: Array = []
	var keys_in: Array = []
	var bass_in := 0
	var inside := true
	for sec in sc["sections"]:
		if (sec["parts"] as Array).has("drums"):
			drums_in.append(sec["key"])
		if (sec["parts"] as Array).has("keys"):
			keys_in.append(sec["key"])
		bass_in += 1 if (sec["parts"] as Array).has("bass") else 0
	for n in _part(sc, "drums")["notes"]:
		var t := float(n["t"])
		var ok := false
		for sec in sc["sections"]:
			if sec["key"] in ["intro", 1] and t >= float(sec["start"]) - 0.05 and t < float(sec["start"]) + float(sec["length"]) + 0.05:
				ok = true
		inside = inside and ok
	_ok(keys.has("intro") and keys.has(0) and keys.has(4) and keys.has("outro"), "every section has its key: %s" % str(keys))
	_ok(drums_in == ["intro", 1] and inside and bass_in == 0 and (_part(sc, "bass")["notes"] as Array).is_empty(),
		"drums given the intro and the first chorus play there alone (%s), a bass given none plays nowhere" % str(drums_in))
	_ok(keys_in.size() > 2, "...the control: keys given nothing play where the line-ups put them: %s" % str(keys_in))
	var said := Lyrics.parse("<!-- say: soliloquy = S AH0 L IH1 L AH0 K W IY0 -->\n<!-- verse -->\nTo my soliloquy\n")
	var s2 := Composer.score({"seed": 2, "tempo": 100.0, "parts": {"vocal": {"pattern": "composed"}}}, {"lyrics": said})
	var spelled := false
	for p in Composer.voice_of(s2)["phrases"]:
		for w in p["words"]:
			spelled = spelled or (String(w["text"]) == "soliloquy" and (w.get("arpa", []) as Array).size() == 9)
	_ok(spelled, "a word a say mark spells reaches the voice's notes with its spelling")


func _instrumentals() -> void:
	var written := Lyrics.parse("<!-- intro: 2 -->\n" + CHORUS_SONG.replace("<!-- chorus -->\n\n<!-- verse -->", "<!-- chorus -->\n<!-- solo: 8 -->\n<!-- verse -->") + "<!-- ending: 2 -->\n")
	var sc := Composer.score({"seed": 5, "tempo": 100.0, "parts": {"drums": {}, "vocal": {}}}, {"lyrics": written})
	var shape: Array = (sc["sections"] as Array).map(func(x: Dictionary) -> String: return "%s:%d" % [x["label"], int(x["bars"])])
	var kinds: Array = (sc["sections"] as Array).map(func(x: Dictionary) -> String: return String(x["kind"]))
	var lyric_of_last := -1
	for x in sc["sections"]:
		if int(x.get("lyric", -1)) >= 0:
			lyric_of_last = int(x["lyric"])
	_ok(shape[0] == "Intro:2" and shape.has("Solo:8") and shape.back() == "Ending:2" and kinds.count("intro") == 1
		and kinds.count("outro") == 1 and kinds.count("break") == 1 and lyric_of_last == 4,
		"the instrumental sections the words write stand where written, at their bars, none drawn: %s" % str(shape))
	var solo := shape.find("Solo:8")
	_ok(solo > 0 and String(sc["sections"][solo - 1]["kind"]) == "chorus" and String(sc["sections"][solo + 1]["kind"]) == "verse",
		"...the solo between the second chorus and the last verse")
	var plain := Composer.score({"seed": 5, "tempo": 100.0, "parts": {"drums": {}, "vocal": {}}}, {"lyrics": Lyrics.parse(CHORUS_SONG)})
	_ok(String(plain["sections"][0]["kind"]) == "intro" and String((plain["sections"] as Array).back()["kind"]) == "outro"
		and String(plain["sections"][0]["label"]) == "Intro", "the control: with none written, an intro and an outro are drawn")


func _chord_at_beat(sc: Dictionary, t: float) -> Dictionary:
	var at := {"root": 0, "quality": ""}
	for c in sc["chords"]:
		if int(c["bar"]) * 4 + int(c["beat"]) <= int(floor(t + 0.01)):
			at = c
	return at


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
