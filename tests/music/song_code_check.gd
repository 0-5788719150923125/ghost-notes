extends SceneTree

## song_code_check - a composed Sound's settings as one code and back ([SongCode], [BlockCode]; next/music.md). No
## renderer.
##
##   godot --headless --path . --script res://tests/music/song_code_check.gd
##
## - THE WORDS ONLY GROW: the first 167 are pinned by their hash (reordering or removing one fails here; appending does
##   not), none twice, and every built-in part, pattern, instrument and key the card offers is one (a row added is
##   appended).
## - A tuned song's code entered on a note brings back every setting, the note's own source and reference kept; the
##   song it scores is the same song. Bad codes are refused and change nothing.
## - A value at its default is left out (control: one off its default is in) - but a setting a roll draws where it is
##   unset, Likeness, is in at any value; every setting moves the code (control: the same block is the same code); a
##   fresh roll is a short code, a tuned song a longer one.
## - A name no word covers (a pattern of the author's own) is written out and still comes back; the voices - what each
##   sings, its sections, a kept voice's name - come back from the code.
## - A ROW ADDED MOVES ONLY THE ROLLS IT WINS: over 2000 rolls a seventh name takes about a seventh of the picks, every
##   pick that changed going to it (control: a pick by place in the list moves most of them); weighted, a heavier name
##   wins about as many times more often and a name added still takes only what it wins; the composer's own picks of a
##   part's pattern and sound are these.
## - A roll is never the number it replaces.

## The first words' count and the hash of them joined by newlines: grows only when a word is appended and this pinned.
const PINNED := 167
const PINNED_HASH := "03debb323f63cbef9d2638cd57b872a41bb0104f058ff0ca273f0c1efa896d97"

const SONG := """<!-- verse -->

Welcome random user
To my soliloquy

<!-- chorus -->
Error me found
"""

var _fails := 0


func _ok(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	print("song_code_check")
	_words()
	_round_trip()
	_defaults()
	_names()
	_voices()
	_stable()
	_fresh()
	print("song_code_check: %s" % ("FAILED (%d)" % _fails if _fails > 0 else "ok"))
	quit(1 if _fails > 0 else 0)


func _tuned() -> Dictionary:
	return {"source": "composed", "reference": {"path": "/music/a song.mp3"}, "place": {"1": 32, "3": 60},
		"seed": 9858, "likeness": 0.8, "tempo": 0.0,
		"parts": {"drums": {"seed": 1, "pattern": "four_floor", "instrument": "kit_band"},
			"bass": {"seed": 2, "mute": false, "instrument": "sub_bass"}, "keys": {"seed": 2, "mute": false, "instrument": "marimba"},
			"lead": {"seed": 1, "mute": true}, "vocal": {"seed": 13633, "vocoder": 1.0, "mute": false, "tune": 0.35},
			"guitar": {"seed": 2, "level": -4.5}}}


func _words() -> void:
	var w: Array = SongCode.WORDS
	_ok(w.size() >= PINNED and "\n".join(PackedStringArray(w.slice(0, PINNED))).sha256_text() == PINNED_HASH,
		"the first %d words are as pinned: appended to, never reordered or removed" % PINNED)
	var seen := {}
	for x in w:
		seen[x] = true
	_ok(seen.size() == w.size(), "no word twice")
	var missing: Array = []
	for k in SongParts.PARTS.keys() + SongParts.PATTERNS.keys() + Instruments.ROWS.keys():
		if not seen.has(k):
			missing.append(k)
	for scale in ["major", "minor", "dorian", "mixolydian", "lydian"]:
		for t in 12:
			if not seen.has(MusicTheory.key_name(t, scale)):
				missing.append(MusicTheory.key_name(t, scale))
	_ok(missing.is_empty(), "every built-in part, pattern, instrument and key is a word: missing %s" % str(missing))


func _round_trip() -> void:
	var tuned := _tuned()
	var code := SongCode.of(tuned)
	var note := {"source": "composed", "reference": {"path": "/music/another.mp3"}, "seed": 3, "parts": {"pad": {}}}
	var got := SongCode.applied(note, code)
	var back: Dictionary = got["block"]
	_ok(String(got["why"]).is_empty(), "a tuned song's code reads: %s (%d letters)" % [code, code.length()])
	_ok(JSON.stringify(SongCode.settings(back)) == JSON.stringify(SongCode.settings(tuned)), "...every setting back")
	_ok(String((back["reference"] as Dictionary)["path"]) == "/music/another.mp3" and String(back["source"]) == "composed",
		"...the note's own reference and source kept")
	_ok(code.length() <= 100, "a tuned song's code is under 100 letters (%d)" % code.length())
	var lyrics := Lyrics.parse(SONG)
	var a := Composer.score(tuned, {"lyrics": lyrics})
	var b := Composer.score(SongCode.applied(tuned, code)["block"], {"lyrics": lyrics})
	_ok(JSON.stringify(a) == JSON.stringify(b), "the song a code brings back is the same song")
	for bad in ["", "1zzzz", code.substr(0, code.length() - 2), "hello"]:
		var r := SongCode.applied(note, bad)
		_ok(not String(r["why"]).is_empty() and r["block"] == note, "refused, nothing changed: '%s' (%s)" % [bad, r["why"]])
	_ok(not String(SongCode.applied(note, BlockCode.encode([1, 2], SongCode.WORDS))["why"]).is_empty(), "a code of no song's settings is refused")


func _defaults() -> void:
	var bare := SongCode.of({})
	_ok(SongCode.of({"seed": 1, "tempo": 0.0, "key": "", "parts": {}, "source": "composed"}) == bare,
		"a value at its default is left out: %s" % bare)
	var like := SongCode.of({"likeness": 0.5})
	_ok(like != bare and SongCode.applied({}, like)["block"].has("likeness"), "...but Likeness, which a roll draws where it is unset, is in at one half")
	_ok(SongCode.of({"parts": {"drums": {"seed": 1, "mute": false}}}) == SongCode.of({"parts": {"drums": {}}}),
		"...a part's too, the part kept")
	_ok(SongCode.of({"seed": 2}) != bare and SongCode.of({"parts": {"drums": {}}}) != bare, "the control: one off its default is in")
	var roll := SongCode.of({"seed": SongCode.fresh()})
	_ok(roll.length() <= 12, "a fresh roll is a short code: %s" % roll)
	var tuned := _tuned()
	var code := SongCode.of(tuned)
	_ok(SongCode.of(_tuned()) == code, "the control: the same block is the same code")
	var moved: Array = []
	for change in [["likeness", 0.85], ["tempo", 120.0], ["key", "F# dorian"], ["place", {"1": 33, "3": 60}]]:
		var t := _tuned()
		t[change[0]] = change[1]
		if SongCode.of(t) != code:
			moved.append(change[0])
	for change in [["drums", "level", -2.0], ["bass", "pattern", "walking"], ["vocal", "singer", {"voice": "kokoro", "speaker": 0, "name": "af_heart"}],
			["keys", "seed", 77], ["lead", "mute", false]]:
		var t := _tuned()
		t["parts"][change[0]][change[1]] = change[2]
		if SongCode.of(t) != code:
			moved.append("%s.%s" % [change[0], change[1]])
	var t2 := _tuned()
	(t2["parts"] as Dictionary).erase("guitar")
	if SongCode.of(t2) != code:
		moved.append("a part taken out")
	_ok(moved.size() == 10, "every setting moves the code: %s" % str(moved))


func _voices() -> void:
	var block := {"seed": 77, "parts": {"vocal": {"singer": {"kept": "Deep Ana", "name": "Deep Ana"}, "sections": [0, 1, 3]},
		"vocal_2": {"sings": "harmony", "sections": [3, 4]}, "vocal_3": {"sings": "tune", "sections": [2], "singer": {"kept": "Ana"}}}}
	var code := SongCode.of(block)
	var back := SongCode.applied({}, code)
	_ok(String(back["why"]).is_empty() and JSON.stringify(SongCode.settings(back["block"])) == JSON.stringify(SongCode.settings(block)),
		"a song's voices come back from its code - what each sings, where, and its kept singer (%d letters)" % code.length())


func _names() -> void:
	var own := {"parts": {"drums": {"pattern": "my_shuffle_from_the_dex"}}}
	var code := SongCode.of(own)
	var back := SongCode.applied({}, code)
	_ok(String(back["why"]).is_empty() and String(back["block"]["parts"]["drums"]["pattern"]) == "my_shuffle_from_the_dex",
		"a name no word covers is written out and comes back")
	_ok(code.length() > SongCode.of({"parts": {"drums": {"pattern": "motorik"}}}).length(), "...longer than a word (the control)")


func _stable() -> void:
	var names := ["a", "b", "c", "d", "e", "f"]
	var grown := names + ["g"]
	var moved := 0
	var to_new := 0
	var by_place := 0
	for seed in 2000:
		var was: Variant = Roll.pick(names, seed, "pattern")
		var now: Variant = Roll.pick(grown, seed, "pattern")
		if was != now:
			moved += 1
			to_new += 1 if now == "g" else 0
		if Roll.rng(seed, "x").randi_range(0, names.size() - 1) != Roll.rng(seed, "x").randi_range(0, grown.size() - 1):
			by_place += 1
	_ok(moved == to_new and moved > 160 and moved < 440,
		"a row added takes only the rolls it wins: %d of 2000 moved, all to it" % moved)
	_ok(by_place > 1000, "the control: a pick by place in the list moves %d of 2000" % by_place)
	var heavy := {"a": 4.0}
	var won := 0
	var w_moved := 0
	var w_to_new := 0
	for seed in 4000:
		var was: Variant = Roll.pick_weighted(names, heavy, seed, "w")
		won += 1 if was == "a" else 0
		var now: Variant = Roll.pick_weighted(grown, heavy, seed, "w")
		if was != now:
			w_moved += 1
			w_to_new += 1 if now == "g" else 0
	# "a" weighs 4 among five of 1: it should win 4/9 of the draws
	_ok(won > 1600 and won < 1950 and w_moved == w_to_new and w_moved > 0,
		"weighted, a name four times as heavy wins %d of 4000 (about 1778), and a name added takes only what it wins (%d)" % [won, w_moved])
	_ok(Roll.pick_weighted(names, {}, 7, "pattern") == Roll.pick(names, 7, "pattern"), "...and with no weights it is the plain pick")
	var same := 0
	for seed in range(1, 51):
		var c := Composer.choice_of("keys", {}, seed, {})
		var pseed := Composer.part_seed(seed, "keys", {})
		var pattern := String(Roll.pick(SongParts.patterns_for("keys"), pseed, "pattern"))
		var rows := Instruments.for_part("keys")
		var weights := Composer.style_weights(rows, Instruments.ROWS, Registry.field(SongParts.PATTERNS, pattern, "styles", []))
		if String(c["pattern"]) == pattern and String(c["instrument"]) == String(Roll.pick_weighted(rows, weights, pseed, "instrument")):
			same += 1
	_ok(same == 50, "the composer picks a part's pattern and sound so: %d of 50" % same)


func _fresh() -> void:
	var ok := true
	var was := 5
	for i in 300:
		var n := SongCode.fresh(was)
		ok = ok and n != was and n >= 2 and n < SongCode.ROLL_MOST
		was = n
	_ok(ok, "a roll is never the number it replaces, and is under ROLL_MOST")
