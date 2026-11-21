extends Node

## sound_card_check - the Sound card ([SoundCard]; next/music.md), built by hand out of the app's panel, with a note and
## a folder of the gate's own (never the author's).
##
##   tests/run_boot_probe.sh tests/music/sound_card_check.gd 120
##
## - A Song's old block is a Sound's file: `for_note` reads `song: {path}` as the file source, and what it plays is that
##   file; the control - a composed Sound with nothing made plays nothing.
## - What it keeps is what it shows: `capture` hands back the block it was given, a part's pattern set is written into
##   `parts`, and `apply` of another block shows it (Source, Key).
## - Its parts are entries: one a part, the voice's among them; a part taken off is gone from the block.
## - ITS CODE IS EVERY SETTING ([SongCode]): the Code row shows it and it changes as a dial moves; ROLL DRAWS EVERY
##   SETTING (the key and tempo set drawn again, the parts and what is muted kept) and the dials it drew show dimmed,
##   their value the score's - the control, a dial set, lit; a part's Roll draws that part alone (its pattern gone, its
##   mute kept), and a code entered brings its settings back, the source kept - the control, a bad code, is refused
##   and changes nothing; Back walks to the song before each. THE FIELD NEVER HOLDS A STALE CODE: focused, a roll still
##   writes it there and letting it go changes nothing; typed into, it is entered when let go (a bad one refused); a
##   press outside lets it go - the control, a press on it, keeps it. A part shows a Roll and no number.
## - EVERY PART IS USED IN THE SECTIONS IT IS GIVEN: an instrument's entry has a toggle a section of the song, its intro
##   and outro too; letting one go sets the sections it plays in.
## - A SONG HAS UP TO FOUR VOICES, each an entry: the first has its Melody, Tune and Vocoder but no Vibrato of its own
##   (a voice's, set in its Lab), and its singer picker lists the kept voices first; a second has what it sings and a
##   toggle a section of the words, the ones it sings in pressed, and no Melody; pressing a toggle sets them; + Add a
##   part offers Voice while a song has fewer than four; every voice's lines are counted in the Pipeline.
## - What it makes is the Pipeline's: composed, its section lists the mix as missing and the sung lines; given a mix
##   and its record, the mix is made - the control, the block changed after, is stale. Its ⤓ (the song exported, from the
##   bottom-right row where the note exports no video) stands grayed until there is a mix, and lit once there is; a note
##   with a Medium has none of its own (its video's ⤓ carries the song).
## - Its song is what a video's export renders ([method SoundCard.export_song]): a mix made from the score as it stands is
##   handed over as it is, its sidecar written with the song's grid; a file source hands its file, and a file missing
##   none.
## - Its timeline is offered beside Play while it is composed ([method Transport.offer_timeline]), and taken back for a
##   file.
## - Its export says itself on the row's progress line ([RowStatus]), as the video's does: a WAV copied and an MP3
##   encoded by FFmpeg (where ghost has it) each end "Saved" there, the file written; the subtitles beside a mix are its
##   words sung, each line a sentence (`SongBake.write_sidecar`).
## - A section of the words pinned (`place`) is where the score lays it, with a reference made for the gate.
## - With a reference its Likeness shows (the control, none, hides it), and the card says what the roll drew and kept of
##   it - at likeness 1 its tempo, key, form and chords, at 0 nothing; a part's pattern picked stays, and Auto lets
##   the roll draw it again.
## - The score on the Timeline: a group a section, the voice's lane its words, and no problems (Timeline.check).
## - A composed song is heard as it is made ([SongStream]) in a session a person plays; the controls, an export's render
##   and a file, are not. Its mix's sidecar names its grid (a beat a beat, a section a section) and its seed, which a
##   file loaded takes ([method Spectrum.begin]) - the control, a file with no sidecar, has no grid and its own
##   fingerprint. The show's beat rises on the grid's beats through Spectrum's own frames - the control, no grid and
##   nothing heard, never rises - and Stop lets the grid go.
## - IT BUFFERS FOR ITS VOICES (the stream's choices driven by hand, nothing heard): its windows end at the bar line
##   before a line not yet sung could begin and ask nothing more however often asked, a harmony voice's line holding them as the lead's does;
##   playing with nothing made left to hear, the player pauses itself, the line's words kept, the transport still
##   showing it playing; its takes come, the windows go on past it and, enough made, it plays on, the rail showing what
##   is made ahead - the control, paused by the author, shows paused. A line no voice is left to sing goes without, its words off the
##   subtitles - the control, every take there, is never waited for, and the song is made on to its end, nothing capping
##   how far ahead. A roll reaches the stream once the dials settle, and while the song streams its unmade mix is
##   on demand, left out of the Pipeline's tally (an export makes it).
## - Where the music environment is installed, the music host streams a short song: the first sound is heard once its
##   preroll is made, a roll is taken while it plays, a seek starts it again there, Stop ends it.

const ROOT := "user://sound_card_check"

var _fails := 0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT))
	var note := ProjectSettings.globalize_path(ROOT).path_join("song.md")
	var f := FileAccess.open(note, FileAccess.WRITE)
	f.store_string("---\ntitle: song\n---\n<!-- verse -->\none two three\nfour five six\n<!-- chorus -->\nseven eight\nnine ten\n")
	f.close()
	var folder := ProjectSettings.globalize_path(ROOT).path_join("folder")
	_old_block(note, folder)
	_keeps(note, folder)
	_code(note, folder)
	_voices(note, folder)
	await _pipeline(note, folder)
	await _export(note, folder)
	_placed(note, folder)
	_timeline(note, folder)
	await _stream(note, folder)
	DirAccess.remove_absolute(note)
	if _fails == 0:
		print("sound_card_check: ALL OK")
		get_tree().quit(0)
		return
	print("sound_card_check: %d FAILED" % _fails)
	get_tree().quit(1)


func _card(block: Dictionary, note: String, folder: String) -> SoundCard:
	var c := SoundCard.for_note({"blocks": block, "path": note, "folder": folder})
	add_child(c)
	return c


func _old_block(note: String, folder: String) -> void:
	var song := ProjectSettings.globalize_path(ROOT).path_join("a.wav")
	var w := FileAccess.open(song, FileAccess.WRITE)
	w.store_buffer(PackedByteArray([0, 0, 0, 0]))
	w.close()
	var c := _card({"song": {"path": song}}, note, folder)
	_ok(String(c.capture()["source"]) == "file" and c.playable() == song and c.ready_to_play(),
		"a Song's old block is the file source, and it plays that file")
	c.queue_free()
	var d := _card({"sound": {"source": "composed"}}, note, folder)
	_ok(d.playable().is_empty() and not d.ready_to_play(), "the control: a composed Sound with nothing made plays nothing")
	d.queue_free()
	DirAccess.remove_absolute(song)


func _keeps(note: String, folder: String) -> void:
	var block := {"source": "composed", "seed": 4, "key": "D dorian", "parts": {"drums": {"seed": 2}, "bass": {}, "vocal": {}}}
	var c := _card({"sound": block}, note, folder)
	_ok(JSON.stringify(c.capture()) == JSON.stringify(block), "capture hands back the block it was given")
	c._set_part("drums", "pattern", "four_floor")
	_ok(String(c.capture()["parts"]["drums"]["pattern"]) == "four_floor", "a part's pattern set is written into its block")
	var entries := c._parts_box.get_children().filter(func(n: Node) -> bool: return n is EntryCard and not n.is_queued_for_deletion())
	_ok(entries.size() == 3, "an entry a part, the voice's among them (%d)" % entries.size())
	c.apply({"source": "file", "path": ""})
	_ok(not c._composed_box.visible and c._file_box.visible, "apply of a file block shows the file source")
	c.apply(block)
	_ok(c._composed_box.visible and String(c._key.get_item_metadata(c._key.selected)) == "D dorian", "...and of the composed one, its key")
	var parts: Dictionary = c.capture()["parts"]
	parts.erase("bass")
	c._block["parts"] = parts
	c._changed()
	_ok(not (c.capture()["parts"] as Dictionary).has("bass"), "a part taken off is gone from the block")
	c.queue_free()


func _code(note: String, folder: String) -> void:
	var block := {"source": "composed", "seed": 4, "key": "D dorian", "parts": {"drums": {"seed": 2}, "bass": {}, "vocal": {}}}
	var c := _card({"sound": block}, note, folder)
	_ok(c._code.text == SongCode.of(block), "its Code row shows the song's code: %s" % c._code.text)
	c._tempo.value = 120.0
	_ok(c._code.text == SongCode.of(c.capture()) and c._code.text != SongCode.of(block), "...which changes as a dial moves")
	_ok(c._tempo.get_parent().modulate.a == 1.0, "...the tempo set shows lit")
	c._set_part("bass", "mute", true)
	c._set_part("bass", "pattern", "walking")
	var kept := c._code.text
	var kept_settings := JSON.stringify(SongCode.settings(c.capture()))
	c.roll_song()
	var after: Dictionary = c.capture()
	_ok(c._code.text != kept and int(after["seed"]) != 4, "Roll is a new song, a new code")
	_ok(not after.has("key") and not after.has("tempo") and not (after["parts"]["drums"] as Dictionary).has("seed")
		and JSON.stringify(after["parts"]["bass"]) == JSON.stringify({"mute": true}) and (after["parts"] as Dictionary).size() == 3,
		"...every setting drawn again (the key and tempo set gone, the bass's pattern), the parts and the bass's mute kept")
	_ok(c._tempo.get_parent().modulate.a < 1.0 and int(c._tempo.value) == int(roundf(float(c.score()["tempo"]))),
		"...the tempo it drew shows dimmed: %d BPM" % int(c._tempo.value))
	var song_code := c._code.text
	c.roll_part("bass")
	var rolled: Dictionary = c.capture()["parts"]
	_ok(rolled["bass"].has("seed") and bool(rolled["bass"]["mute"]) and not rolled["drums"].has("seed") and not rolled["vocal"].has("seed")
		and c._code.text != song_code, "a part's Roll draws it alone, its mute kept, and moves the code")
	var part_code := c._code.text
	var why := c.enter_code(kept)
	_ok(why.is_empty() and JSON.stringify(SongCode.settings(c.capture())) == kept_settings and c._code.text == kept,
		"a code entered brings its settings back: %s" % (why if not why.is_empty() else c._code.text))
	_ok(String(c.capture()["source"]) == "composed", "...the source kept")
	var before := JSON.stringify(c.capture())
	why = c.enter_code("1zzzzz")
	_ok(not why.is_empty() and JSON.stringify(c.capture()) == before and c._code.text == kept,
		"a bad code is refused, nothing changed (%s)" % why)
	c.back()
	var stepped := c._code.text
	c.back()
	_ok(stepped == part_code and c._code.text == song_code and not c._back.disabled,
		"Back walks to the song before the code entered, then before the part's roll")
	c._code.grab_focus()
	var held := JSON.stringify(c.capture())
	c.roll_song()
	var rolled_code := SongCode.of(c.capture())
	_ok(c._code.has_focus() and c._code.text == rolled_code and JSON.stringify(c.capture()) != held,
		"focused, the field still shows the code a roll made")
	c._code.release_focus()
	_ok(SongCode.of(c.capture()) == rolled_code, "...and letting it go changes nothing")
	c._code.grab_focus()
	c._code.text = "1zzzzz"
	c._code.text_changed.emit("1zzzzz")
	c._code.release_focus()
	_ok(SongCode.of(c.capture()) == rolled_code and c._code.text == rolled_code, "typed into and let go, a bad code is refused and the code shown again")
	c._code.grab_focus()
	var on := InputEventMouseButton.new()
	on.button_index = MOUSE_BUTTON_LEFT
	on.pressed = true
	on.position = c._code.get_global_rect().get_center()
	c._input(on)
	var stays := c._code.has_focus()
	var off := on.duplicate() as InputEventMouseButton
	off.position = c._code.get_global_rect().position + Vector2(-40.0, -40.0)
	c._input(off)
	_ok(stays and not c._code.has_focus(), "a press outside the field lets it go; the control, a press on it, keeps it")
	var drums: EntryCard = null
	for e in c._parts_box.get_children():
		if e is EntryCard and not e.is_queued_for_deletion() and (e as EntryCard).name_label.text == "Drums":
			drums = e
	var labels: Array = []
	var rolls := 0
	if drums != null:
		for n in drums.options.find_children("*", "Label", true, false):
			labels.append((n as Label).text)
		for n in drums.options.find_children("*", "Button", true, false):
			rolls += 1 if (n as Button).text == "Roll" else 0
	_ok(drums != null and rolls == 1 and not labels.has("Number"), "a part has a Roll and no number of its own shown")
	c.queue_free()


func _voices(note: String, folder: String) -> void:
	var block := {"source": "composed", "seed": 4, "parts": {"vocal": {"pattern": "composed"}, "vocal_2": {"sings": "harmony"}}}
	var c := _card({"sound": block}, note, folder)
	c._voices = {"Deep Ana": {"voice": "kokoro", "speaker": 0, "blend": "", "tone": 13, "semis": -4.0, "center": 50,
		"vibrato": 0.4, "vibrato_rate": 6.0, "drift": 0.05}}
	c._voices_at = VoiceLibrary.version
	c._score_of = ""
	c._refresh()
	var voice := _entry(c, "Voice")
	var second := _entry(c, "Voice 2")
	var labels := func(e: EntryCard) -> Array:
		return e.options.find_children("*", "Label", true, false).map(func(l: Node) -> String: return (l as Label).text)
	var pickers: Array = voice.options.find_children("*", "OptionButton", true, false) if voice != null else []
	var singer: OptionButton = null
	for p in pickers:
		for i in (p as OptionButton).item_count:
			if (p as OptionButton).get_item_text(i) == "♥ Deep Ana":
				singer = p
	_ok(voice != null and not labels.call(voice).has("Vibrato") and labels.call(voice).has("Tune") and labels.call(voice).has("Vocoder")
		and labels.call(voice).has("Melody") and singer != null and singer.get_item_text(1) == "♥ Deep Ana",
		"the Voice entry has its Melody, Tune and Vocoder but no Vibrato of its own, and lists the kept voices first")
	_ok(second != null and labels.call(second).has("Sings") and labels.call(second).has("Used in") and not labels.call(second).has("Melody"),
		"a second voice is an entry of its own - what it sings and where - singing the first's melody")
	var toggles: Array = []
	if second != null:
		for f in second.options.find_children("*", "HFlowContainer", true, false):
			for b in (f as Node).get_children():
				if b is Button and (b as Button).toggle_mode:
					toggles.append(b)
	_ok(toggles.size() == 2 and String(toggles[1].text) == "Chorus 1" and bool(toggles[1].button_pressed),
		"...a toggle a section of the words, the last chorus pressed (%d)" % toggles.size())
	if toggles.size() == 2:
		(toggles[0] as Button).button_pressed = not (toggles[0] as Button).button_pressed
	var sections: Variant = (c.capture()["parts"]["vocal_2"] as Dictionary).get("sections")
	_ok(sections is Array and (sections as Array).has(1), "...pressing one sets the sections it sings in: %s" % str(sections))
	var popup := c._add.get_popup()
	var another := -1
	for i in popup.item_count:
		if popup.get_item_text(i) == "Voice":
			another = popup.get_item_id(i)
	if another >= 0:
		popup.id_pressed.emit(another)
	_ok(another >= 0 and (c.capture()["parts"] as Dictionary).has("vocal_3") and _entry(c, "Voice 3") != null,
		"+ Add a part offers Voice while there is room for one, and it is Voice 3")
	var block2 := {"source": "composed", "seed": 4, "parts": {"drums": {}, "vocal": {"pattern": "composed"}}}
	var d := _card({"sound": block2}, note, folder)
	var drums := _entry(d, "Drums")
	var used: Array = []
	if drums != null:
		for f in drums.options.find_children("*", "HFlowContainer", true, false):
			for b in (f as Node).get_children():
				if b is Button and (b as Button).toggle_mode:
					used.append(b)
	var names: Array = used.map(func(b: Button) -> String: return b.text)
	_ok(names.size() == (d.score()["sections"] as Array).size() and names.has("Intro") and names.has("Verse 1") and names.has("Outro"),
		"an instrument is used in the sections of the song, a toggle each - its intro and outro too: %s" % str(names))
	var off: Button = null
	for b in used:
		if (b as Button).button_pressed:
			off = b
	if off != null:
		off.button_pressed = false
	var set_used: Variant = (d.capture()["parts"]["drums"] as Dictionary).get("sections")
	_ok(set_used is Array and not (set_used as Array).is_empty() and (set_used as Array).size() < names.size(),
		"...letting one go sets the sections it plays in: %s" % str(set_used))
	d.queue_free()
	var rows: Array = c.pipeline_rows()
	var lines := SongBake.lines_of(c.score()).size()
	var said := ""
	for r in rows:
		if (r as PipelineRow).key == "takes":
			said = (r as PipelineRow).said
	_ok(said.begins_with("%d lines" % lines) and lines > (Composer.voice_of(c.score())["phrases"] as Array).size(),
		"every voice's lines are counted in the Pipeline: %s" % said)
	c.queue_free()


func _entry(c: SoundCard, name: String) -> EntryCard:
	for e in c._parts_box.get_children():
		if e is EntryCard and not e.is_queued_for_deletion() and (e as EntryCard).name_label.text == name:
			return e
	return null


func _pipeline(note: String, folder: String) -> void:
	var c := _card({"sound": {"source": "composed", "parts": {"bass": {}, "vocal": {"pattern": "composed"}}}}, note, folder)
	await get_tree().process_frame
	var rows := _rows(c)
	_ok(rows.has("mix") and String(rows["mix"]) == "missing" and rows.has("takes"), "composed and unmade: the mix is missing, the sung lines listed")
	_ok(c._save.visible and c._save.disabled and c._save.text == "⤓", "its ⤓ stands grayed while there is no song to export")
	var with_video := SoundCard.for_note({"blocks": {"sound": {"source": "composed"}}, "path": note, "folder": folder, "video": true})
	_ok(not with_video._save.visible, "a note with a Medium has no ⤓ of the song's own: its video's carries it")
	with_video.free()
	var offer := Transport.offered()
	_ok(not offer.is_empty() and (offer["who"] as WeakRef).get_ref() == c, "its timeline is offered beside Play")
	_ok(c.pipeline().shown() and c.pipeline().missing(), "...and its section is shown, with something to make")
	# a mix and its record, as a bake leaves them
	DirAccess.make_dir_recursive_absolute(folder.path_join("sound"))
	var w := FileAccess.open(folder.path_join("sound").path_join(SongBake.MIX), FileAccess.WRITE)
	w.store_buffer(PackedByteArray([0, 0]))
	w.close()
	c.score()
	var r := FileAccess.open(folder.path_join("sound").path_join(SongBake.MADE), FileAccess.WRITE)
	r.store_string(JSON.stringify({"hash": c._score_hash}))
	r.close()
	c._read_made()
	_ok(String(_rows(c)["mix"]) == "made" and c.ready_to_play(), "given a mix and its record, the mix is made and plays")
	c._show_save()
	_ok(c._save.visible and not c._save.disabled, "...and its ⤓ is lit")
	var mix := folder.path_join("sound").path_join(SongBake.MIX)
	DirAccess.remove_absolute(mix.get_basename() + ".json")
	var handed := String(await c.export_song())
	var side: Variant = JSON.parse_string(FileAccess.get_file_as_string(mix.get_basename() + ".json"))
	_ok(handed == mix and side is Dictionary and (side as Dictionary).get("grid") is Dictionary,
		"a video's export is handed the mix made from this score, its sidecar written with the grid (%s)" % handed.get_file())
	var file := SoundCard.for_note({"blocks": {"sound": {"source": "file", "path": mix}}, "path": note, "folder": folder})
	var missing := SoundCard.for_note({"blocks": {"sound": {"source": "file", "path": "/nowhere.wav"}}, "path": note, "folder": folder})
	_ok(String(await file.export_song()) == mix and String(await missing.export_song()).is_empty() and not missing.can_export_song(),
		"a file source hands its file; the control, a file missing, none")
	file.free()
	missing.free()
	c._set_part("bass", "seed", 9)
	_ok(String(_rows(c)["mix"]) == "stale", "the control: a part rolled after, the mix is stale")
	c.apply({"source": "file", "path": ""})
	var gone := Transport.offered()
	_ok(gone.is_empty() or (gone["who"] as WeakRef).get_ref() != c, "a file has no timeline of its own: the offer is taken back")
	_ok(not c._save.visible, "...nor a ⤓ of its own")
	c.queue_free()
	for name in [SongBake.MIX, SongBake.MADE]:
		DirAccess.remove_absolute(folder.path_join("sound").path_join(name))


func _export(note: String, folder: String) -> void:
	var c := _card({"sound": {"source": "composed", "parts": {"vocal": {"pattern": "composed"}}}}, note, folder)
	await get_tree().process_frame
	var dir := folder.path_join("sound")
	DirAccess.make_dir_recursive_absolute(dir)
	var mix := dir.path_join(SongBake.MIX)
	_wav(mix, 1.5)
	for ext in ["wav", "mp3"]:
		var dest := dir.path_join("out." + ext)
		if ext == "mp3" and Provision.tool_path("ffmpeg", "ffmpeg").is_empty():
			print("  skip the MP3: ghost has no FFmpeg here")
			continue
		c._saving_as = dest
		var why := c._bake.save_as(mix, dest)
		var waited := 0
		while not c._line.said().begins_with("✓") and not c._line.said().begins_with("⚠") and waited < 600:
			await get_tree().process_frame
			waited += 1
		_ok(why.is_empty() and c._line.said().begins_with("✓  Saved") and FileAccess.file_exists(dest),
			"its %s export ends \"Saved\" on the row's line, the file written (%s)" % [ext.to_upper(), c._line.said()])
		c._line.clear()
		DirAccess.remove_absolute(dest)
	var score := {"voices": [{"key": "vocal", "phrases": [{"at": 2.0, "lead": true, "words": [{"text": "one", "notes": [{"t": 0.0, "len": 0.5, "midi": 60}]},
		{"text": "two", "notes": [{"t": 0.5, "len": 0.25, "midi": 62}, {"t": 0.75, "len": 0.25, "midi": 64}]}]},
		{"at": 5.0, "lead": true, "words": [{"text": "three", "notes": [{"t": 0.0, "len": 1.0, "midi": 60}]}]}]},
		{"key": "vocal_2", "phrases": [{"at": 2.0, "lead": false, "words": [{"text": "one", "notes": [{"t": 0.0, "len": 0.5, "midi": 64}]}]}]}]}
	SongBake.write_sidecar(score, mix)
	var side: Variant = JSON.parse_string(FileAccess.get_file_as_string(Subtitles.sidecar_for(mix)))
	var words: Array = (side as Dictionary).get("words", []) if side is Dictionary else []
	_ok(words.size() == 3 and is_equal_approx(float(words[1]["t0"]), 2.5) and is_equal_approx(float(words[1]["t1"]), 3.0)
		and int(words[2]["sentence"]) == 1, "the subtitles beside a mix: its words when sung, each line a sentence, a voice that does not lead left out")
	for f in [mix, mix.get_basename() + ".json"]:
		DirAccess.remove_absolute(f)
	c.queue_free()


## A WAV of silence [param seconds] long, as render.py writes a mix (16-bit stereo at 44.1 kHz).
func _wav(path: String, seconds: float) -> void:
	var frames := int(seconds * 44100.0)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer("RIFF".to_ascii_buffer())
	f.store_32(36 + frames * 4)
	f.store_buffer("WAVEfmt ".to_ascii_buffer())
	f.store_32(16)
	f.store_16(1)
	f.store_16(2)
	f.store_32(44100)
	f.store_32(44100 * 4)
	f.store_16(4)
	f.store_16(16)
	f.store_buffer("data".to_ascii_buffer())
	f.store_32(frames * 4)
	var zero := PackedByteArray()
	zero.resize(frames * 4)
	f.store_buffer(zero)
	f.close()


func _rows(c: SoundCard) -> Dictionary:
	var out := {}
	for r in c.pipeline_rows():
		out[String((r as PipelineRow).key)] = String((r as PipelineRow).state)
	return out


func _placed(note: String, folder: String) -> void:
	var sung: Array = []
	for b in 24:
		sung.append(0.9 if (b >= 4 and b < 6) or (b >= 14 and b < 16) else 0.0)
	var ref := {"tempo": 100.0, "beat": 0.6, "offset": 0.0, "bars": 24, "key": {"tonic": 0, "mode": "major"},
		"chords": [{"bar": 0, "beat": 0, "root": 0, "quality": ""}], "sections": [], "drums": {}, "voice": {}, "sung": sung}
	var dir := folder.path_join("sound")
	DirAccess.make_dir_recursive_absolute(dir)
	var w := FileAccess.open(dir.path_join(SongBake.REFERENCE), FileAccess.WRITE)
	w.store_string(JSON.stringify(ref))
	w.close()
	var c := _card({"sound": {"source": "composed", "likeness": 1.0, "reference": {"path": "/nowhere.mp3"}}}, note, folder)
	var at := _section_bars(c.score())
	_ok(int(at.get("Chorus", -1)) == 14, "the chorus lands where the reference sings (%s)" % str(at))
	c._block["place"] = {"1": 18}
	c._changed()
	at = _section_bars(c.score())
	_ok(int(at.get("Chorus", -1)) == 18, "pinned, it is where it was put (%s)" % str(at))
	_ok(c._likeness.get_parent().visible and c._roll_info.text.contains("From the reference: tempo, key, form, chords"),
		"with a reference its Likeness shows, and the card says what the roll kept: %s" % c._roll_info.text.replace("\n", " / "))
	c._block["likeness"] = 0.0
	c._changed()
	_ok(c._roll_info.text.contains("From the reference: nothing"), "at likeness 0 it keeps nothing: %s" % c._roll_info.text.replace("\n", " / "))
	c._set_part("drums", "pattern", "half_time")
	var set := String((c._parts()["drums"] as Dictionary).get("pattern", ""))
	c._set_part("drums", "pattern", "")
	_ok(set == "half_time" and not (c._parts()["drums"] as Dictionary).has("pattern"),
		"a part's pattern picked stays (%s), and Auto lets the roll draw it again" % set)
	c.queue_free()
	DirAccess.remove_absolute(dir.path_join(SongBake.REFERENCE))


func _section_bars(score: Dictionary) -> Dictionary:
	var out := {}
	for s in score["sections"]:
		out[String(s["label"])] = int(s["bar"])
	return out


func _timeline(note: String, folder: String) -> void:
	var c := _card({"sound": {"source": "composed", "tempo": 100.0, "key": "C major",
		"parts": {"drums": {}, "bass": {}, "vocal": {"pattern": "composed"}}}}, note, folder)
	var score := c.score()
	_ok(not c._likeness.get_parent().visible, "the control: with no reference, no Likeness")
	var tl := SoundTimeline.of(score)
	_ok(Timeline.check(tl).is_empty(), "the score on the Timeline has no problems: %s" % ", ".join(Timeline.check(tl)))
	_ok((tl["groups"] as Array).size() == (score["sections"] as Array).size(), "a group a section")
	var words := 0
	for g in tl["groups"]:
		for l in g["lanes"]:
			if String(l["id"]) == "vocal":
				words += (l["items"] as Array).size()
	_ok(words == 10, "the voice's lane holds its words (%d of 10)" % words)
	c.queue_free()


const STREAM_BLOCK := {"sound": {"source": "composed", "tempo": 120.0, "key": "C major", "seed": 5,
	"parts": {"drums": {}, "bass": {}, "keys": {}}}}


func _stream(note: String, folder: String) -> void:
	var opener := func(fp: int, sr: int, _words: Array) -> Dictionary:
		return {"playback": Spectrum.begin_stream(fp, sr), "subtitles": null}
	var closer := func() -> void: Spectrum.stop()
	var live := SoundCard.for_note({"blocks": STREAM_BLOCK, "path": note, "folder": folder, "live": true,
		"begin_stream": opener, "end_stream": closer})
	var render := SoundCard.for_note({"blocks": STREAM_BLOCK, "path": note, "folder": folder, "live": false,
		"begin_stream": opener, "end_stream": closer})
	var file := SoundCard.for_note({"blocks": {"sound": {"source": "file", "path": "x.wav"}}, "path": note, "folder": folder,
		"live": true, "begin_stream": opener, "end_stream": closer})
	_ok(live.streams() and not render.streams() and not file.streams(),
		"a composed song streams in a session a person plays; an export's render and a file do not")
	var score := live.score()
	var mix := ProjectSettings.globalize_path(ROOT).path_join("grid.wav")
	_wav(mix, 2.0)
	SongBake.write_sidecar(score, mix)
	Spectrum.begin(mix)
	var beats: PackedFloat32Array = Spectrum.known.get("beats", PackedFloat32Array())
	var secs: PackedFloat32Array = Spectrum.known.get("sections", PackedFloat32Array())
	_ok(beats.size() == int(score["bars"]) * int(score.get("meter", 4)) and secs.size() == (score["sections"] as Array).size()
		and Spectrum.song_hash == SongBake.seed_of(score),
		"a mix's sidecar hands the show its grid (%d beats, %d sections) and its seed" % [beats.size(), secs.size()])
	var bare := ProjectSettings.globalize_path(ROOT).path_join("bare.wav")
	_wav(bare, 2.0)
	Spectrum.begin(bare)
	_ok(Spectrum.known.is_empty() and Spectrum.song_hash != SongBake.seed_of(score),
		"the control, a file with no sidecar: no grid, its own fingerprint")
	Spectrum.stop()
	Spectrum.known = SongBake.grid_of(score)
	# the show's beat through Spectrum's own frames, the song's second 0 put a moment from now
	Spectrum.known_origin = Spectrum.current.time + 0.2
	var risen := await _rises(1.6)
	Spectrum.stop()
	_ok(Spectrum.known.is_empty(), "Stop lets the grid go")
	var still := await _rises(1.6)
	_ok(risen >= 2 and still == 0, "the show's beat rises on the grid's beats: %d times in 1.6 s; the control, no grid, %d" % [
		risen, still])
	render.free()
	file.free()
	for p in [mix, mix.get_basename() + ".json", bare]:
		DirAccess.remove_absolute(p)
	_buffers(note, folder)
	add_child(live)
	var stream: SongStream = null
	for c in live.get_children():
		if c is SongStream:
			stream = c
	_ok(stream != null, "the card holds its stream")
	if stream == null:
		live.queue_free()
		return
	_ok(String(_rows(live).get("mix", "")) == "on_demand" and not PipelineRow.counted("on_demand"),
		"heard as it is made, its unmade mix is on demand, left out of the tally (an export makes it)")
	var was := int(stream._score.get("seed", 0))
	live._block["seed"] = was + 4
	live._changed()
	await get_tree().create_timer(SoundCard.STREAM_SETTLE + 0.4).timeout
	_ok(int(stream._score.get("seed", 0)) == was + 4, "a roll reaches its stream once the dials settle (%d, was %d)" % [
		int(stream._score.get("seed", 0)), was])
	if not FileAccess.file_exists(Deps.venv_bin(SongStream.VENV, "python")):
		print("  --   the music environment is not installed: the music host's stream is not tried")
		live.queue_free()
		return
	stream.play()
	var heard := await _until(func() -> bool: return stream._pushed >= int(SongStream.PREROLL * SongStream.RATE), 90.0)
	_ok(heard and Spectrum.is_streaming() and not Spectrum.paused,
		"the stream is heard once its preroll is made (%d frames pushed)" % stream._pushed)
	var epoch := stream._epoch
	stream.update(SoundCard.for_note({"blocks": {"sound": STREAM_BLOCK["sound"].merged({"seed": 6}, true)}, "path": note,
		"folder": folder}).score())
	var rolled := await _until(func() -> bool: return stream._ready_load == stream._epoch and stream.landed >= 1, 60.0)
	_ok(rolled and stream._epoch > epoch, "a roll is taken while it plays: the host loaded it and the stream goes on")
	stream.seek(4.0)
	_ok(absf(stream.position() - 4.0) < 0.05, "a seek starts the stream again there: %.2f s" % stream.position())
	var again := await _until(func() -> bool: return stream._pushed >= int(SongStream.PREROLL * SongStream.RATE), 60.0)
	_ok(again, "and it is heard from there")
	stream.stop_song()
	_ok(not Spectrum.is_streaming() and Spectrum.known.is_empty(), "Stop ends the stream")
	live.queue_free()
	await get_tree().process_frame


class FakeSubtitles extends Node:
	var words: Array = []
	var time_base := 0.0


## The stream's choices while a voice's lines are not sung yet, driven by hand: what it asks of a host that never answers.
func _buffers(note: String, folder: String) -> void:
	var block := {"sound": {"source": "composed", "tempo": 120.0, "key": "C major", "seed": 3,
		"parts": {"drums": {}, "bass": {}, "vocal": {"pattern": "composed"}, "vocal_2": {"sings": "harmony", "sections": [0, 1]}}}}
	var score := SoundCard.for_note({"blocks": block, "path": note, "folder": folder}).score()
	var lines := SongBake.lines_of(score)
	var first: Dictionary = Composer.voice_of(score)["phrases"][0]
	var made := func(taken: Array, dead := false) -> SongStream:
		var st := SongStream.new()
		var bake := SongBake.new()
		bake._host_dead = dead
		st.add_child(bake)
		st.setup(score, folder, bake)
		Spectrum.release_conductor(st)
		st._host = "up"
		st._ready_load = st._epoch
		st._takes.clear()
		for l in lines:
			if taken.has("all") or taken.has(String(l["id"])):
				st._takes[l["id"]] = {"wav": "/nowhere.wav", "at": float(l["phrase"]["at"]), "voice": l["key"]}
		st._subtitles = FakeSubtitles.new()
		st.add_child(st._subtitles)
		st._show_words()
		return st
	var asked := func(st: SongStream) -> Array:
		st._ask()
		var out: Array = st._pending.values()
		st._pending.clear()
		st._asking = 0
		st._inflight = 0.0
		return out
	var reach := func(windows: Array) -> float:
		var most := 0.0
		for w in windows:
			most = maxf(most, float(w["t1"]))
		return most
	var bar := 0.0
	var st: SongStream = made.call([])
	bar = st._bar_at(float(first["at"]) - SongStream.TAKE_LEAD, false)
	var windows: Array = asked.call(st)
	var again: Array = []
	for _k in 10:
		again.append_array(asked.call(st))
	_ok(not windows.is_empty() and absf(float(reach.call(windows)) - bar) < 1e-3 and again.is_empty() and st._missed.is_empty(),
		"a line not yet sung: the windows end at the bar line before its take could begin (%.2f s, the line at %.2f s) and ask nothing more" % [reach.call(windows), float(first["at"])])
	st.free()
	var lead_only: Array = lines.filter(func(l: Dictionary) -> bool: return String(l["key"]) == "vocal").map(func(l: Dictionary) -> String: return String(l["id"]))
	st = made.call(lead_only)
	_ok(absf(float(reach.call(asked.call(st))) - bar) < 1e-3, "...a harmony voice's line holding them as the lead's does")
	var was := Spectrum.paused
	st._open = true
	st._want_play = true
	Spectrum.set_stream_paused(false)
	st._buffer()
	var held := st.buffering() and Spectrum.paused
	_ok(held and st._subtitles.words.any(func(w: Dictionary) -> bool: return String(w["line"]) == "vocal:0"),
		"playing with nothing made left to hear, the player pauses itself, the line's words kept")
	_ok(st.playing() and is_equal_approx(st.made_ahead(), 0.0),
		"...still playing as the transport shows it, nothing made ahead on the rail")
	for l in lines:
		st._takes[l["id"]] = {"wav": "/nowhere.wav", "at": float(l["phrase"]["at"]), "voice": l["key"]}
	var on: Array = asked.call(st)
	var frames := PackedVector2Array()
	frames.resize(int(SongStream.BUFFER_FULL * SongStream.RATE) + 10)
	st._queue.append({"seq": 1, "t0": 0.0, "t1": 4.0, "frames": frames, "started": false})
	st._buffer()
	_ok(float(reach.call(on)) > bar + 0.01 and not st.buffering() and not Spectrum.paused,
		"...its takes come, the windows go on past it, and with enough made it plays on")
	_ok(absf(st.made_ahead() - float(frames.size()) / SongStream.RATE) < 0.01,
		"...the rail showing what is made ahead: %.2f s" % st.made_ahead())
	st.pause()
	_ok(not st.playing() and not st.buffering(), "the control: paused by the author, it shows paused")
	st._open = false
	st.free()
	st = made.call([], true)
	var past := float(reach.call(asked.call(st)))
	_ok(past > bar + 0.01 and st._missed.has("vocal:0") and not st._subtitles.words.any(func(w: Dictionary) -> bool: return String(w["line"]) == "vocal:0"),
		"a line no voice is left to sing goes without, its words off the subtitles")
	st.free()
	var ready: SongStream = made.call(["all"])
	_ok(float(reach.call(asked.call(ready))) > bar + 0.01, "the control: with every take there, nothing waits at its bar")
	var far := 0.0
	for _k in 200:
		far = maxf(far, float(reach.call(asked.call(ready))))
	_ok(absf(far - float(score["length"])) < 0.01, "...and it makes the song on to its end, however far ahead: %.1f of %.1f s" % [far, float(score["length"])])
	ready.free()
	Spectrum.set_stream_paused(was)


## How many times the show's beat rises past the Director's edge (0.5) in [param seconds] of frames.
func _rises(seconds: float) -> int:
	var n := 0
	var prev := Spectrum.current.beat
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
		var b := Spectrum.current.beat
		if b > 0.5 and prev <= 0.5:
			n += 1
		prev = b
	return n


## Frames until [param cond] holds or [param seconds] pass; whether it held.
func _until(cond: Callable, seconds: float) -> bool:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		if cond.call():
			return true
		await get_tree().process_frame
	return bool(cond.call())


func _ok(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)
