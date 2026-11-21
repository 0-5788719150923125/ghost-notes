extends Node

## sound_bake_probe - a composed Sound made start to end in a real boot, for looking and listening (not a gate): the
## reference read, the score composed from the words, every line sung by the voice host, the parts rendered and mixed
## by the music host ([SongBake], [Composer]; next/music.md). Writes only into `--out`.
##
##   tests/run_boot_probe.sh tests/music/sound_bake_probe.gd 1800 --words <lyrics.md> --out <folder>
##       [--reference <song>] [--block <sound block as JSON>] [--read]
##   tests/run_boot_probe.sh tests/music/sound_bake_probe.gd 1800 --note <note.md> --out <its folder>/sound [--read]
##
## `--note` takes a note's own `sound:` block and words, and leaves what the Sound card checks (the reference's stamp,
## the mix's record) so the note opens with its song made. `--read` reads the reference again even where
## `<out>/reference.json` is there. Prints what the bake says, the form it laid and every line's notes, and the mix.

var _bake: SongBake
var _args := {}
var _block := {}
var _words := ""
var _out := ""
var _made_hash := ""


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var i := 0
	while i < a.size():
		var k := String(a[i])
		if k.begins_with("--") and i + 1 < a.size() and not String(a[i + 1]).begins_with("--"):
			_args[k.trim_prefix("--")] = String(a[i + 1])
			i += 2
		else:
			_args[k.trim_prefix("--")] = "1"
			i += 1
	_out = String(_args.get("out", ""))
	_words = FileAccess.get_file_as_string(String(_args.get("words", "")))
	if _args.has("note"):
		var raw := FileAccess.get_file_as_string(String(_args["note"]))
		_words = String(FrontMatter.split(raw).get("body", ""))
		var blocks := NoteStore.blocks_of(String(_args["note"]))
		_args["block"] = JSON.stringify(blocks.get("sound", {}))
	if _out.is_empty() or _words.is_empty():
		print("sound_bake_probe: give --words <lyrics> and --out <folder>")
		get_tree().quit(2)
		return
	var parsed: Variant = JSON.parse_string(String(_args.get("block", "{}")))
	_block = parsed if parsed is Dictionary else {}
	if _args.has("reference"):
		_block["reference"] = {"path": String(_args["reference"])}
	_bake = SongBake.new()
	add_child(_bake)
	_bake.said.connect(func(t: String) -> void: print("  bake: ", t))
	_bake.done.connect(_on_done)
	var ref_file := _out.path_join(SongBake.REFERENCE)
	if _block.has("reference") and (_args.has("read") or not FileAccess.file_exists(ref_file)):
		var lines: Array = []
		for l in Lyrics.lines_of(Lyrics.parse(_words)):
			lines.append({"text": l["text"]})
		_bake.analyze(String(_block["reference"]["path"]), lines, _out)
	else:
		_compose_and_bake()


func _compose_and_bake() -> void:
	var ref := SongBake.reference_of(_out) if _block.has("reference") else {}
	var score := Composer.score(_block, {"lyrics": Lyrics.parse(_words), "reference": ref})
	print("sound_bake_probe: %.1f BPM, %s, %d bars, %.1f s" % [float(score["tempo"]),
		MusicTheory.key_name(int(score["key"]["tonic"]), String(score["key"]["scale"])), int(score["bars"]), float(score["length"])])
	for s in score["sections"]:
		print("  %-8s bars %3d-%3d" % [String(s["label"]), int(s["bar"]), int(s["bar"]) + int(s["bars"]) - 1])
	var phrases: Array = Composer.voice_of(score).get("phrases", [])
	for p in phrases:
		var notes := PackedStringArray()
		for w in p["words"]:
			var ms := PackedStringArray()
			for n in w["notes"]:
				ms.append(MusicTheory.NAMES[posmod(int(n["midi"]), 12)] + str(floori(int(n["midi"]) / 12.0) - 1))
			notes.append("%s(%s)" % [String(w["text"]), "-".join(ms)])
		print("  bar %3d  %s" % [int(p["bar"]), " ".join(notes)])
	_made_hash = JSON.stringify(score).sha1_text()
	_bake.bake(score, _out)


func _on_done(job: String, ok: bool, path: String, why: String) -> void:
	if not ok:
		print("sound_bake_probe: %s FAILED - %s" % [job, why])
		get_tree().quit(1)
		return
	if job == "analyze":
		print("sound_bake_probe: read the reference: ", path)
		# what the Sound card keeps with a reading: the file it was read from, as it stood
		var ref := SongBake.reference_of(_out)
		var song := String(_block["reference"]["path"])
		ref["stamp"] = "%s@%d" % [song, FileAccess.get_modified_time(song)]
		ref["song"] = song
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(ref, " "))
			f.close()
		_compose_and_bake()
		return
	print("sound_bake_probe: MIX ", path)
	if _args.has("note"):
		var m := FileAccess.open(_out.path_join(SongBake.MADE), FileAccess.WRITE)
		if m != null:
			m.store_string(JSON.stringify({"hash": _made_hash, "at": Time.get_unix_time_from_system()}))
			m.close()
	get_tree().quit(0)
