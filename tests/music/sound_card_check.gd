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
## - What it makes is the Pipeline's: composed, its section lists the mix as missing and the sung lines; given a mix
##   and its record, the mix is made - the control, the block changed after, is stale. Its ⤓ (the song exported, from the
##   bottom-right row where the note exports no video) stands grayed until there is a mix, and lit once there is; a note
##   with a Medium has none of its own (its video's ⤓ carries the song).
## - Its timeline is offered beside Play while it is composed ([method Transport.offer_timeline]), and taken back for a
##   file.
## - Its export says itself on the row's progress line ([RowStatus]), as the video's does: a WAV copied and an MP3
##   encoded by FFmpeg (where ghost has it) each end "Saved" there, the file written; the subtitles beside a mix are its
##   words sung, each line a sentence (`SongBake.write_words`).
## - A section of the words pinned (`place`) is where the score lays it, with a reference made for the gate.
## - The score on the Timeline: a group a section, the voice's lane its words, and no problems (Timeline.check).

const ROOT := "user://sound_card_check"

var _fails := 0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT))
	var note := ProjectSettings.globalize_path(ROOT).path_join("song.md")
	var f := FileAccess.open(note, FileAccess.WRITE)
	f.store_string("---\ntitle: song\n---\nVerse\none two three\nfour five six\nChorus\nseven eight\nnine ten\n")
	f.close()
	var folder := ProjectSettings.globalize_path(ROOT).path_join("folder")
	_old_block(note, folder)
	_keeps(note, folder)
	await _pipeline(note, folder)
	await _export(note, folder)
	_placed(note, folder)
	_timeline(note, folder)
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
	var score := {"vocal": {"phrases": [{"at": 2.0, "words": [{"text": "one", "notes": [{"t": 0.0, "len": 0.5, "midi": 60}]},
		{"text": "two", "notes": [{"t": 0.5, "len": 0.25, "midi": 62}, {"t": 0.75, "len": 0.25, "midi": 64}]}]},
		{"at": 5.0, "words": [{"text": "three", "notes": [{"t": 0.0, "len": 1.0, "midi": 60}]}]}]}}
	SongBake.write_words(score, mix)
	var side: Variant = JSON.parse_string(FileAccess.get_file_as_string(Subtitles.sidecar_for(mix)))
	var words: Array = (side as Dictionary).get("words", []) if side is Dictionary else []
	_ok(words.size() == 3 and is_equal_approx(float(words[1]["t0"]), 2.5) and is_equal_approx(float(words[1]["t1"]), 3.0)
		and int(words[2]["sentence"]) == 1, "the subtitles beside a mix: its words when sung, each line a sentence")
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
	var c := _card({"sound": {"source": "composed", "reference": {"path": "/nowhere.mp3"}}}, note, folder)
	var at := _section_bars(c.score())
	_ok(int(at.get("Chorus", -1)) == 14, "the chorus lands where the reference sings (%s)" % str(at))
	c._block["place"] = {"1": 18}
	c._changed()
	at = _section_bars(c.score())
	_ok(int(at.get("Chorus", -1)) == 18, "pinned, it is where it was put (%s)" % str(at))
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


func _ok(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)
