extends SceneTree

## The library's voices ([VoiceLibrary], on [Library]'s own root - never the author's), with no autoloads.
##
##   godot --headless --path . --script res://tests/voice/voice_library_check.gd
##
## - A voice kept is who speaks and how ([constant VoiceLibrary.OWN]): every room dial of the row it came from is left out
##   ([constant VoiceLibrary.ROOM]). A voice with no name or no model is refused.
## - Its hash is what it is: the same voice under another name, with another room, or with its numbers written as YAML gives
##   them back, hashes the same; the control, one dial moved, does not. Its sound ([method VoiceLibrary.sound_of]) leaves the
##   ink out; the control, the tone changed, does not.
## - Kept, it is read back, listed and found by its hash; kept again under its name it is replaced; renamed (never over
##   another voice's name) it answers to its old name too; removed it goes to the trash seam ([member Library.discard]) and its
##   sample with it, the author's trash never touched. Every write moves [member VoiceLibrary.version].
## - A file from anywhere comes in bounded ([method VoiceLibrary.sanitized]): huge numbers within their dials, a NaN its
##   default, a path where a model, a reader, an ink or a name goes no path, a formant voice of thousands of seeds and genes cut
##   short, the room and unknown keys dropped; a file with no voice, or too large to be one, is refused. One coming in under a
##   kept voice's name takes a free name - the control, the same voice again, is the one kept. Export and import round-trip.
## - Its sample is named by its sound: none yet asks the maker; a rename or an ink keeps it, a dial moved asks again, and one
##   no voice sounds like is swept.
## - On the Dex ([LibraryVoices]): a kept voice is a tile on Kept voices, with nothing to hear and Say it until its sample is made
##   (with no Voice card to say it, Say it says so); made, the shelf's version moves and the tile is heard from its sample, Say it
##   gone; Remove takes it off the shelf.

const ROOT := "user://voice_library_check"

var _fails := 0


func _init() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("  FAIL: " + what)


func _run() -> void:
	Library.root = ROOT
	var trashed: Array = []
	Library.discard = func(path: String) -> int:
		trashed.append(path)
		return DirAccess.remove_absolute(path)
	_rmrf(ProjectSettings.globalize_path(ROOT))
	_kept()
	_hashes()
	_shelf(trashed)
	_bounded()
	_samples()
	_dex_shelf()
	_rmrf(ProjectSettings.globalize_path(ROOT))
	Library.root = Library.ROOT
	Library.discard = Callable()
	VoiceLibrary.maker = Callable()
	print("voice_library_check: %s (%d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _fails, "" if _fails == 1 else "s"])
	quit(1 if _fails > 0 else 0)


## A cast row as the Voice card writes one: the voice and its room.
func _row(pace := 1.2) -> Dictionary:
	return {"voice": "kokoro", "speaker": 3, "blend": "", "formant": {}, "tone": 2, "pace": pace, "pause": 2.5,
		"dynamics": 0.3, "arc": 0.2, "effort": 0.6, "ink": "blue",
		"echo": 0.4, "room": 0.3, "resonance": 0.2, "presence": 0.8, "ambience": 0.5, "lean": 0.1, "near": 0.2, "seat": 45.0,
		"kept": "Someone"}


func _kept() -> void:
	var e := VoiceLibrary.entry_of(_row(), "Ada", "a low, even narrator")
	var v: Dictionary = e["voice"]
	var keys := v.keys()
	keys.sort()
	var own := VoiceLibrary.OWN.duplicate()
	own.sort()
	_ok(keys == own, "a voice kept holds exactly who speaks and how (%s)" % str(keys))
	for k in VoiceLibrary.ROOM:
		_ok(not v.has(k), "the room's %s is kept" % k)
	_ok(not v.has("kept"), "the name a row reads by is kept as part of the voice")
	_ok(String(v["voice"]) == "kokoro" and int(v["speaker"]) == 3 and int(v["tone"]) == 2 and is_equal_approx(float(v["pace"]), 1.2)
		and is_equal_approx(float(v["pause"]), 2.5) and String(v["ink"]) == "blue", "the voice's own fields changed as kept (%s)" % str(v))
	_ok(String(e["name"]) == "Ada" and String(e["line"]) == "a low, even narrator", "its name and line are kept")
	_ok(VoiceLibrary.entry_of(_row(), "  ").is_empty(), "a voice with no name was kept")
	var none := _row()
	none["voice"] = ""
	_ok(VoiceLibrary.entry_of(none, "Nobody").is_empty(), "a voice with no model was kept")
	var nan := VoiceLibrary.own_of({"voice": "kokoro", "pace": NAN, "pause": INF, "tone": -INF, "dynamics": NAN})
	_ok(is_equal_approx(float(nan["pace"]), 1.0) and is_equal_approx(float(nan["pause"]), Delivery.MAX_PAUSE_SCALE)
		and int(nan["tone"]) == 0 and is_equal_approx(float(nan["dynamics"]), 0.5),
		"a NaN is its dial's default and an infinity its dial's end (%s)" % str(nan))


func _hashes() -> void:
	var h := VoiceLibrary.hash_of(_row())
	var other := _row()
	for k in VoiceLibrary.ROOM:
		other[k] = 0.0
	other["kept"] = "Another"
	_ok(VoiceLibrary.hash_of(other) == h, "the same voice with another room hashes otherwise")
	var yaml := _row()
	yaml["pace"] = "1.2"
	yaml["speaker"] = 3.0
	yaml["pause"] = 2.5000000001
	_ok(VoiceLibrary.hash_of(yaml) == h, "the same voice with its numbers as YAML gives them hashes otherwise")
	_ok(VoiceLibrary.hash_of(_row(1.25)) != h, "control: one dial moved hashes the same")
	var inked := _row()
	inked["ink"] = "red"
	_ok(VoiceLibrary.hash_of(inked) != h and VoiceLibrary.sound_of(inked) == VoiceLibrary.sound_of(_row()),
		"the ink is the voice's, but not its sound")
	var toned := _row()
	toned["tone"] = 5
	_ok(VoiceLibrary.sound_of(toned) != VoiceLibrary.sound_of(_row()), "control: the tone changed sounds the same")


func _shelf(trashed: Array) -> void:
	var v0 := VoiceLibrary.version
	_ok(VoiceLibrary.keep(_row(), "Ada", "a narrator").is_empty(), "a voice could not be kept")
	_ok(VoiceLibrary.version > v0, "a voice kept did not move the version")
	var got := VoiceLibrary.read("ada")
	_ok(not got.is_empty() and String(got["name"]) == "Ada" and String(got["hash"]) == VoiceLibrary.hash_of(_row()),
		"a voice kept is not read back by its name (%s)" % str(got))
	_ok(_same(got.get("voice", {}), VoiceLibrary.own_of(_row())), "a voice read back is not the voice kept")
	_ok(VoiceLibrary.names() == ["Ada"] and (VoiceLibrary.entries()[0] as Dictionary).has("voice"), "the shelf lists %s" % str(VoiceLibrary.names()))
	_ok(VoiceLibrary.kept_as(VoiceLibrary.hash_of(_row())) == "Ada" and VoiceLibrary.kept_as("0000") == "", "a voice is not found as kept by its hash")
	_ok(VoiceLibrary.keep(_row(1.3), "Ada", "a narrator").is_empty() and is_equal_approx(float(VoiceLibrary.read("Ada")["voice"]["pace"]), 1.3)
		and VoiceLibrary.names().size() == 1, "a voice kept again under its name did not replace it")
	_ok(VoiceLibrary.keep(_row(), "Bea", "").is_empty(), "a second voice could not be kept")
	_ok(not VoiceLibrary.rename("Ada", "Bea", "").is_empty(), "a voice was renamed over another's name")
	_ok(VoiceLibrary.rename("Ada", "Ada Prime", "the narrator, renamed").is_empty(), "a voice could not be renamed")
	var renamed := VoiceLibrary.read("Ada Prime")
	_ok(String(renamed.get("line", "")) == "the narrator, renamed" and is_equal_approx(float(renamed["voice"]["pace"]), 1.3), "a voice renamed lost itself")
	_ok(String(VoiceLibrary.read("Ada").get("name", "")) == "Ada Prime", "a voice renamed does not answer to its old name")
	_ok(not FileAccess.file_exists(VoiceLibrary.dir().path_join("ada.json")), "the old name's file stayed")
	_ok(VoiceLibrary.keep(_row(1.4), "Ada Prime", "").is_empty() and String(VoiceLibrary.read("Ada").get("name", "")) == "Ada Prime",
		"a voice kept again forgot the old name it answers to")
	_ok(VoiceLibrary.remove("Bea").is_empty() and VoiceLibrary.read("Bea").is_empty(), "a voice could not be removed")
	_ok(trashed.size() == 1 and String(trashed[0]).ends_with("bea.json"), "a voice removed did not go to the trash seam (%s)" % str(trashed))
	_ok(not VoiceLibrary.remove("Bea").is_empty(), "a voice not kept was removed")


func _bounded() -> void:
	var dir := ProjectSettings.globalize_path(ROOT).path_join("files")
	DirAccess.make_dir_recursive_absolute(dir)
	var lineage: Array = []
	for i in 10000:
		lineage.append(i * 7919)
	var genome := {}
	for i in 5000:
		genome["g%d" % i] = float(i)
	var bank: Array = []
	for i in 1001:
		bank.append(1.0e30)
	var wild := {"name": "../../../etc/" + "x".repeat(10000), "line": "two\nlines " + "y".repeat(5000),
		"voice": {"voice": "/home/someone/.local/share/models/../../evil.onnx", "speaker": 1.0e30, "tone": -5,
			"pace": "1e400", "pause": -1.0e308, "dynamics": "nan", "arc": 7, "effort": null,
			"blend": "mix: ../../etc/passwd 1, af_heart 1", "ink": "../../etc/passwd", "echo": 5.0, "exec": "rm -rf /",
			"formant": {"lineage": lineage, "genome": genome, "traits": {"pitch": "nan"}, "bank": bank}}}
	var path := dir.path_join("wild" + VoiceLibrary.EXPORT)
	_write(path, JSON.stringify(wild))
	var why: Array = []
	var name := VoiceLibrary.import_from(path, why)
	_ok(not name.is_empty(), "a wild file was refused: %s" % str(why))
	var e := VoiceLibrary.read(name)
	var v: Dictionary = e.get("voice", {})
	_ok(String(e.get("file", "")).get_base_dir() == VoiceLibrary.dir() and not name.contains("\n") and name.length() <= VoiceLibrary.NAME_MOST,
		"a name with a path in it was kept outside the shelf or long (%s)" % String(e.get("file", "")))
	_ok(String(e.get("line", "")).length() <= VoiceLibrary.LINE_MOST and not String(e.get("line", "")).contains("\n"), "the line came in unbounded")
	_ok(String(v.get("voice", "")) == "evil.onnx", "a path where the model goes came in as %s" % String(v.get("voice", "")))
	_ok(int(v.get("speaker", -1)) == VoiceLibrary.SPEAKER_MOST and int(v.get("tone", -1)) == 0, "a huge reader or a low tone came in unbounded")
	_ok(float(v.get("pace", 0.0)) <= VoiceLibrary.PACE_MOST and float(v.get("pace", 0.0)) >= VoiceLibrary.PACE_LEAST
		and is_equal_approx(float(v.get("pause", -1.0)), 0.0) and is_equal_approx(float(v.get("dynamics", 0.0)), 0.5)
		and is_equal_approx(float(v.get("arc", 0.0)), 1.0) and is_equal_approx(float(v.get("effort", 0.0)), 0.35),
		"a dial came in out of its range (%s)" % str(v))
	_ok(String(v.get("blend", "x")) == "" and String(v.get("ink", "x")) == "", "a path where a reader or an ink goes came in")
	_ok(not v.has("echo") and not v.has("exec"), "the room or an unknown key came in")
	var f: Dictionary = v.get("formant", {})
	_ok((f.get("lineage", []) as Array).size() == VoiceLibrary.LINEAGE_MOST and (f.get("genome", {}) as Dictionary).size() == VoiceLibrary.MAP_MOST
		and (f.get("bank", []) as Array).size() <= VoiceLibrary.BANK_MOST and (f.get("bank", []) as Array).size() % 3 == 0
		and float((f.get("bank", [0.0]) as Array)[0]) <= VoiceLibrary.NUMBER_MOST and is_equal_approx(float((f.get("traits", {}) as Dictionary).get("pitch", 1.0)), 0.0),
		"the formant voice came in unbounded")
	_write(dir.path_join("empty.voice.json"), JSON.stringify({"name": "nothing", "line": "no voice here"}))
	why.clear()
	_ok(VoiceLibrary.import_from(dir.path_join("empty.voice.json"), why).is_empty() and not why.is_empty(), "a file with no voice was kept")
	_write(dir.path_join("huge.voice.json"), JSON.stringify({"name": "huge", "voice": {"voice": "kokoro"}, "line": "z".repeat(VoiceLibrary.FILE_MOST)}))
	why.clear()
	_ok(VoiceLibrary.import_from(dir.path_join("huge.voice.json"), why).is_empty(), "a file too large to be a voice was kept")
	# export and import: one coming in under a kept voice's name takes a free name; the same voice again is the one kept
	_ok(VoiceLibrary.export_to("Ada Prime", dir.path_join("ada" + VoiceLibrary.EXPORT)).is_empty(), "a voice could not be exported")
	var handed: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("ada" + VoiceLibrary.EXPORT)))
	_ok(handed is Dictionary and not (handed as Dictionary).has("was") and not (handed as Dictionary).has("file"), "an export carries the shelf's own fields")
	_ok(VoiceLibrary.import_from(dir.path_join("ada" + VoiceLibrary.EXPORT)) == "Ada Prime" and VoiceLibrary.names().size() == 2,
		"control: the same voice imported again was kept twice (%s)" % str(VoiceLibrary.names()))
	var changed: Dictionary = (handed as Dictionary).duplicate(true)
	changed["voice"]["pace"] = 0.6
	_write(dir.path_join("ada2" + VoiceLibrary.EXPORT), JSON.stringify(changed))
	var other := VoiceLibrary.import_from(dir.path_join("ada2" + VoiceLibrary.EXPORT))
	_ok(other == "Ada Prime 2" and is_equal_approx(float(VoiceLibrary.read("Ada Prime")["voice"]["pace"]), 1.4)
		and is_equal_approx(float(VoiceLibrary.read("Ada Prime 2")["voice"]["pace"]), 0.6),
		"another voice imported under a kept voice's name replaced it (kept as %s)" % other)
	VoiceLibrary.remove(other)
	VoiceLibrary.remove(name)


func _samples() -> void:
	var asked: Array = []
	VoiceLibrary.maker = func(n: String) -> void: asked.append(n)
	var e := VoiceLibrary.read("Ada Prime")
	_ok(VoiceLibrary.sample("Ada Prime") == "" and asked == ["Ada Prime"], "a voice with no sample did not ask for one (%s)" % str(asked))
	var at := VoiceLibrary.sample_path(e["voice"])
	_ok(at.get_base_dir() == VoiceLibrary.dir() and at.get_file() == VoiceLibrary.sound_of(e["voice"]) + ".wav", "a sample is not kept beside its voice")
	_write(at, "RIFF")
	_ok(VoiceLibrary.sample("Ada Prime") == at and asked.size() == 1, "a sample made is not found")
	var inked: Dictionary = (e["voice"] as Dictionary).duplicate(true)
	inked["ink"] = "red"
	VoiceLibrary.keep(inked, "Ada Prime", "")
	VoiceLibrary.rename("Ada Prime", "Ada", "")
	_ok(VoiceLibrary.sample("Ada") == at, "a rename or an ink lost the sample")
	var slower: Dictionary = inked.duplicate(true)
	slower["pace"] = 0.9
	VoiceLibrary.keep(slower, "Ada", "")
	_ok(VoiceLibrary.sample("Ada") == "" and asked.size() == 2, "control: a dial moved kept the old sample")
	VoiceLibrary.sampled()
	_ok(not FileAccess.file_exists(at), "a sample no voice sounds like was not swept")
	var now := VoiceLibrary.sample_path(slower)
	_write(now, "RIFF")
	VoiceLibrary.sampled()
	_ok(FileAccess.file_exists(now), "control: the sample a voice sounds like was swept")
	_ok(VoiceLibrary.remove("Ada").is_empty() and not FileAccess.file_exists(now), "a voice removed left its sample")


func _dex_shelf() -> void:
	VoiceLibrary.maker = Callable()
	var row := _row()
	row.erase("kept")
	VoiceLibrary.keep(VoiceLibrary.own_of(row), "Bea", "a bright reader")
	var sec := LibraryVoices.new()
	var tile := func() -> Dictionary:
		var got: Array = sec.offers().filter(func(o: Dictionary) -> bool: return String(o["key"]) == "kept:Bea")
		return got[0] if not got.is_empty() else {}
	var t: Dictionary = tile.call()
	var verbs := func(o: Dictionary) -> Array: return (o.get("verbs", []) as Array).map(func(v: Dictionary) -> String: return String(v["key"]))
	_ok(String(t.get("shelf", "")) == "kept" and String(t.get("line", "")) == "a bright reader" and String(t.get("sound", "x")) == ""
		and (verbs.call(t) as Array).has("say"), "a kept voice with no sample is not a tile with nothing to hear and Say it (%s)" % str(t))
	_ok(sec.act("kept:Bea", "say").contains("Voice card"), "Say it with no Voice card to say it does not say so")
	var was := sec.version()
	var at := VoiceLibrary.sample_path(VoiceLibrary.read("Bea")["voice"])
	_write(at, "RIFF")
	VoiceLibrary.sampled()
	t = tile.call()
	_ok(sec.version() != was and String(t.get("sound", "")) == at and not (verbs.call(t) as Array).has("say"),
		"a sample made does not move the shelf's version, or the tile is not heard from it (%s)" % str(t))
	_ok(sec.act("kept:Bea", "forget").is_empty() and (tile.call() as Dictionary).is_empty(), "Remove does not take it off the shelf")


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


## Equal as JSON written with its keys sorted.
func _same(a: Variant, b: Variant) -> bool:
	return JSON.stringify(a, "", true) == JSON.stringify(b, "", true)


func _rmrf(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for d in DirAccess.get_directories_at(path):
		_rmrf(path.path_join(d))
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	DirAccess.remove_absolute(path)
