extends Node

## sound_effects_check - sound effects made from their words (next/sound_effects.md): the store ([SoundEffects]), a sound's
## design ([SoundDesign]), the Sound card's part ([SoundEffectsPart]) and the library's shelf ([SoundLibrary]), every one in a
## folder of the gate's own (never the author's sounds or library). Nothing is made into sound and no agent runs: hosts/music/
## test_sound.py holds the renderer.
##
##   tests/run_boot_probe.sh tests/music/sound_effects_check.gd 120
##
## (A part's name after the timeout - `_versions`, `_card` - runs it alone.)
##
## - A note's sound marks are found once each, the same words however wrapped one sound (the control: other words, another);
##   the Dispatch desk's own `sound:` mark is what is found.
## - A sound's level is kept beside it in dB within its range, its versions untouched, and handed to the desk with it.
## - A version is kept, never replaced: a second is added and used, the first still there and usable again; a sound with a
##   version but no file made plays nothing (`made`, `made_in`) - the control, its WAV there, plays it with its secs and tail.
## - A design keeps the draft its designer left as a new version only when it changed and can be made: valid and new, kept;
##   the same patch again, not (control); not JSON, or a source nobody knows, not, saying why.
## - The patch's rows are the renderer's: every source sound.py makes is a row the designer is told, and no row is a source
##   it does not make (both ways); the system prompt names every source and field.
## - A WAV is read into frames as written (16-bit stereo): left and right apart, at their levels; the control, not a WAV, none.
## - The heard numbers are told in words: an abrupt end says so, a fade says how long.
## - The Sound card: beside a Voice it plays no song (its Source none, the song's sources grayed saying why) and holds the sound
##   effects; alone, composed (the control). Its part lists one entry a sound mark, and the Pipeline a row a sound - missing,
##   then made once its file is there. Generate's tip names the sound effects where there is no song.
## - Kept: a sound kept is on the library's shelf with its patch and its sound, offered on the Dex's Sounds shelf, and "Use it"
##   hands its name to the sound it was opened from; removed, it is gone.

const ROOT := "user://sound_effects_check"
const WORDS := "a can falls on a hard floor and rolls away"

var _fails := 0


func _ready() -> void:
	SoundEffects.root = ROOT.path_join("sounds")
	Library.root = ROOT.path_join("library")
	Library.discard = func(p: String) -> int: return DirAccess.remove_absolute(p)
	_clear(ProjectSettings.globalize_path(ROOT))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT))
	var only := OS.get_cmdline_user_args()
	for part in [_marks, _versions, _design, _rows, _frames, _card, _kept]:
		if only.is_empty() or only.has((part as Callable).get_method()):
			(part as Callable).call()
	_clear(ProjectSettings.globalize_path(ROOT))
	# what the gate set aside put back, and the conversations held live let go, before the engine's teardown
	Library.discard = Callable()
	Library.root = Library.ROOT
	SoundEffects.root = SoundEffects.ROOT
	SoundEffects._held.clear()
	WriterChat._live.clear()
	if _fails == 0:
		print("sound_effects_check: ALL OK")
		get_tree().quit(0)
		return
	print("sound_effects_check: %d FAILED" % _fails)
	get_tree().quit(1)


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("  FAIL: " + what)


func _clear(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for d in DirAccess.get_directories_at(dir):
		_clear(dir.path_join(d))
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)


func _patch(secs := 2.0) -> Dictionary:
	return {"secs": secs, "tail": 1.0, "layers": [{"source": "modal", "modes": [[2400.0, 0.3, 1.0]], "hits": [0.0, 0.4]}]}


func _marks() -> void:
	var text := "One.\n\n<!-- sound: %s -->\n\nTwo.\n\n<!-- sound: a can falls on a hard\n  floor and rolls away -->\n\n<!-- sound: rain on the roof -->\n" % WORDS
	var m := SoundEffects.marks_in(text)
	_ok(m.size() == 2 and String(m[0]["words"]) == WORDS and String(m[0]["key"]) == SoundEffects.key_of(WORDS)
		and String(m[1]["key"]) != String(m[0]["key"]),
		"a note's sound marks are found once each, the same words however wrapped one sound, other words another (%s)" % str(m))
	_ok(RegEx.create_from_string(String(ScriptMarks.REGISTRY["desk_sound"]["pattern"])).search("<!-- sound: %s -->" % WORDS) != null,
		"what is found is the desk's own sound mark")


func _versions() -> void:
	var key := SoundEffects.key_of(WORDS)
	var v0 := SoundEffects.add_version(key, WORDS, _patch(2.0))
	var v1 := SoundEffects.add_version(key, WORDS, _patch(3.0))
	_ok(v0 == 0 and v1 == 1 and SoundEffects.versions(key).size() == 2 and SoundEffects.used(key) == 1
		and float(SoundEffects.patch_of(key)["secs"]) == 3.0 and float(SoundEffects.patch_of(key, 0)["secs"]) == 2.0,
		"a version is kept, never replaced: the second is used, the first still there")
	SoundEffects.use(key, 0)
	_ok(SoundEffects.used(key) == 0 and float(SoundEffects.patch_of(key)["secs"]) == 2.0, "an earlier version can be used again")
	var was := JSON.stringify(SoundEffects.versions(key))
	SoundEffects.set_level(key, -6.5)
	var down := SoundEffects.level_of(key)
	SoundEffects.set_level(key, 40.0)
	_ok(is_equal_approx(down, -6.5) and is_equal_approx(SoundEffects.level_of(key), SoundEffects.LEVEL_RANGE.y)
		and JSON.stringify(SoundEffects.versions(key)) == was and is_equal_approx(SoundEffects.level_of("never made"), 0.0),
		"a sound's level is kept beside it in dB, within its range, its versions untouched (the control: one never made is at 0)")
	SoundEffects.set_level(key, -6.5)
	_ok(SoundEffects.made(key).is_empty() and SoundEffects.made_in("<!-- sound: %s -->" % WORDS).is_empty(),
		"a version with no file made plays nothing")
	_wav(SoundEffects.wav_path(key), 100)
	var made := SoundEffects.made_in("<!-- sound: %s -->" % WORDS)
	_ok(made.has(key) and float(made[key]["secs"]) == 2.0 and float(made[key]["tail"]) == 1.0 and is_equal_approx(float(made[key]["level"]), -6.5),
		"the control: its WAV there, it plays, with its secs and tail (%s)" % str(made))


func _design() -> void:
	var key := SoundEffects.key_of("a door slams")
	var d := SoundDesign.new(key, "a door slams")
	d.draft = JSON.stringify(_patch(1.5))
	var kept := d.keep_draft()
	var again := d.keep_draft()
	d.draft = "{ not json"
	var bad := d.keep_draft()
	var bad_why := d.error
	d.draft = JSON.stringify({"secs": 1.0, "layers": [{"source": "violin"}]})
	var odd := d.keep_draft()
	_ok(kept == 0 and again == -1 and SoundEffects.versions(key).size() == 1,
		"a design keeps a new valid draft as a version, and the same patch again not (%d, %d)" % [kept, again])
	_ok(bad == -1 and bad_why.contains("JSON") and odd == -1 and d.error.contains("source") and SoundEffects.versions(key).size() == 1,
		"a draft that is not JSON or names an unknown source keeps nothing, saying why (%s / %s)" % [bad_why, d.error])
	d.chat.clear()


func _rows() -> void:
	var py := FileAccess.get_file_as_string("res://hosts/music/sound.py")
	var m := RegEx.create_from_string("SOURCES = \\(([^)]*)\\)").search(py)
	var theirs: Array = []
	if m != null:
		for part in m.get_string(1).split(","):
			var s := part.strip_edges().trim_prefix("\"").trim_suffix("\"")
			if not s.is_empty():
				theirs.append(s)
	var mine: Array = SoundEffects.SOURCES.keys()
	theirs.sort()
	mine.sort()
	_ok(not theirs.is_empty() and theirs == mine, "every source sound.py makes is a row, and no row is a source it does not make (%s against %s)" % [str(theirs), str(mine)])
	var d := SoundDesign.new(SoundEffects.key_of(WORDS), WORDS, "A Night")
	var sys := WriterChat.system_of(d.about(), true, "sound/designer")
	var named := true
	for k in SoundEffects.SOURCES:
		named = named and sys.contains("- %s (" % k)
	for k in SoundEffects.FIELDS:
		named = named and sys.contains("- %s (" % k)
	_ok(named and sys.contains("A Night") and not sys.contains("{{") and Rules.missing.is_empty(),
		"the designer's system prompt names every source and field, whole")
	_ok(SoundEffects.heard_text({"seconds": 2.0, "peak_db": -1.0, "loudest_at": 0.1, "onsets": [0.0], "fade": null, "end_db": -3.0, "frames": []}).contains("abruptly")
		and SoundEffects.heard_text({"seconds": 9.0, "peak_db": -1.0, "loudest_at": 0.1, "onsets": [0.0], "fade": 4.2, "end_db": -70.0, "frames": []}).contains("4.20 s"),
		"the heard numbers are told in words: an abrupt end says so, a fade says how long")


func _frames() -> void:
	var p := ProjectSettings.globalize_path(ROOT).path_join("f.wav")
	_wav(p, 50)
	var fr := SoundEffects.frames_of(p)
	_ok(fr.size() == 50 and absf(fr[10].x - 0.5) < 0.001 and absf(fr[10].y + 0.25) < 0.001,
		"a WAV is read into frames as written, left and right apart (%d frames, %s)" % [fr.size(), str(fr[10]) if fr.size() > 10 else "-"])
	var not_wav := ProjectSettings.globalize_path(ROOT).path_join("x.wav")
	var f := FileAccess.open(not_wav, FileAccess.WRITE)
	f.store_string("not a wav at all, just words")
	f.close()
	_ok(SoundEffects.frames_of(not_wav).is_empty(), "the control: what is not a WAV has no frames")


## A 16-bit stereo WAV at the store's rate, [param n] frames, the left at 0.5 and the right at -0.25.
func _wav(path: String, n: int) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var data := PackedByteArray()
	data.resize(n * 4)
	for i in n:
		data.encode_s16(i * 4, 16384)
		data.encode_s16(i * 4 + 2, -8192)
	var h := PackedByteArray()
	h.resize(44)
	h.encode_u32(0, 0x46464952)        # RIFF
	h.encode_u32(4, 36 + data.size())
	h.encode_u32(8, 0x45564157)        # WAVE
	h.encode_u32(12, 0x20746d66)       # fmt
	h.encode_u32(16, 16)
	h.encode_u16(20, 1)
	h.encode_u16(22, 2)
	h.encode_u32(24, SoundEffects.RATE)
	h.encode_u32(28, SoundEffects.RATE * 4)
	h.encode_u16(32, 4)
	h.encode_u16(34, 16)
	h.encode_u32(36, 0x61746164)       # data
	h.encode_u32(40, data.size())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(h + data)
	f.close()


func _card() -> void:
	var note := ProjectSettings.globalize_path(ROOT).path_join("night.md")
	var f := FileAccess.open(note, FileAccess.WRITE)
	f.store_string("---\ntitle: A Night\n---\nHello.\n\n<!-- sound: %s -->\n\n<!-- sound: a kettle starts to whistle -->\n\nGoodbye.\n" % WORDS)
	f.close()
	var folder := ProjectSettings.globalize_path(ROOT).path_join("folder")
	var beside := SoundCard.for_note({"blocks": {"sound": {"source": "composed"}, "voice": {}}, "path": note, "folder": folder})
	add_child(beside)
	var grayed := true
	for i in beside._source.item_count:
		var k := String(beside._source.get_item_metadata(i))
		grayed = grayed and (beside._source.is_item_disabled(i) == (k != "none"))
	_ok(beside.source() == "none" and beside.playable().is_empty() and not beside._composed() and grayed
		and beside._source.get_item_tooltip(0).contains("Voice"),
		"beside a Voice the card plays no song: its Source none, the song's sources grayed saying why")
	var alone := SoundCard.for_note({"blocks": {"sound": {"source": "composed"}}, "path": note, "folder": folder})
	add_child(alone)
	_ok(alone.source() == "composed", "the control: alone, it is composed")
	_ok(SoundCard.clock_elsewhere({"voice": {}}) == "Voice" and SoundCard.clock_elsewhere({"medium": {}}).is_empty()
		and Components.cannot_attach("sound", ["text", "voice"]).is_empty(),
		"a Voice times the note and a Medium does not, and a Sound can be attached beside a Voice")
	var part := beside._effects
	part.refresh(beside._words())
	var rows: Array = beside.pipeline().rows()
	var key := SoundEffects.key_of(WORDS)
	_ok(part._list.get_child_count() == 2 and rows.size() == 2 and beside.pipeline().shown(),
		"its part lists one entry a sound mark, and the Pipeline a row a sound (%d, %d)" % [part._list.get_child_count(), rows.size()])
	var first: PipelineRow = rows[0]
	var second: PipelineRow = rows[1]
	_ok(String(first.state) == "made" and String(second.state) == "missing" and beside.pipeline().missing(),
		"a sound with its file is made and one never made is missing (%s, %s)" % [first.state, second.state])
	_ok(beside.pipeline().make_tip().contains("sound effect"), "Generate's tip names the sound effects where there is no song")
	beside.queue_free()
	alone.queue_free()
	DirAccess.remove_absolute(note)
	var _unused := key


func _kept() -> void:
	var key := SoundEffects.key_of(WORDS)
	var why := SoundLibrary.keep("Can falls", WORDS, SoundEffects.patch_of(key), SoundEffects.wav_path(key))
	var kept := SoundLibrary.find("Can falls")
	_ok(why.is_empty() and not kept.is_empty() and (kept["patch"] as Dictionary).has("layers") and FileAccess.file_exists(String(kept["wav"])),
		"a sound kept is on the shelf with its patch and its sound (%s)" % why)
	var picked := [""]
	var shelf := SoundShelf.new(func(name: String) -> void: picked[0] = name)
	var offers := shelf.offers()
	_ok(offers.size() == 1 and String(offers[0]["key"]) == "kept:Can falls" and not String(offers[0]["sound"]).is_empty()
		and shelf.add("kept:Can falls").is_empty() and picked[0] == "Can falls" and not shelf.adds().is_empty(),
		"it is offered on the Dex's Sounds shelf, heard there, and Use it hands its name to the sound it was opened from")
	_ok(SoundShelf.new().adds().is_empty(), "the control: the Dex opened on its own offers no Use it")
	_ok(shelf.act("kept:Can falls", "forget").is_empty() and SoundLibrary.find("Can falls").is_empty(), "removed, it is gone")
