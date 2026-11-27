extends Node

## Not a gate. Scripts read in one of a note's voices, each made and joined as a reading makes it (the real host asked as the
## reading asks - the voice's blend, its inflection - one [ReadingJoin], the voice's [VoiceFX]), for hearing what a script's
## delivery says (next/delivery.md). Each script's words and what its delivery made of each (`x`, `acts`) are printed.
##
##   tests/run_boot_probe.sh tests/reading/delivery_take_probe.gd 3600 --scripts <dir of .md> --note <the note's file> --out <dir> [--voice Name]
##
## One WAV a script, named as it is, in --out. A script of the reading's own (the take cache) is never read or written.

const TAKES := "user://delivery_take"
var host: VoiceHost


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var scripts := ""
	var note := ""
	var out := ""
	var voice := ""
	for i in args.size() - 1:
		match args[i]:
			"--scripts":
				scripts = args[i + 1]
			"--note":
				note = args[i + 1]
			"--out":
				out = args[i + 1]
			"--voice":
				voice = args[i + 1]
	var cast := _cast_of(FileAccess.get_file_as_string(note))
	if voice.is_empty():
		voice = String(cast.keys()[0])
	print("delivery_take_probe: voices %s, reading in %s" % [str(cast.keys()), voice])
	host = VoiceHost.new()
	add_child(host)
	host.start()
	while not host.is_up():
		await get_tree().process_frame
	var dir := ProjectSettings.globalize_path(TAKES)
	DirAccess.make_dir_recursive_absolute(dir)
	DirAccess.make_dir_recursive_absolute(out)
	var files := Array(DirAccess.get_files_at(scripts))
	files.sort()
	for f in files:
		if not String(f).ends_with(".md"):
			continue
		var text := FileAccess.get_file_as_string(scripts.path_join(f))
		await _take(text, cast, voice, dir, out.path_join(String(f).get_basename() + ".wav"))
	host.stop()
	get_tree().quit(0)


## One script made and written to [param path].
func _take(text: String, cast: Dictionary, voice: String, dir: String, path: String) -> void:
	var plan := ReadingPlan.make(text, "", {"reader": voice, "hesitate": true, "bare": 1.2, "outro": 0.0})
	var chunks: Array = plan["chunks"]
	print("\n== %s: %d chunks%s" % [path.get_file(), chunks.size(), ("  (" + String(plan["note"]) + ")") if not String(plan["note"]).is_empty() else ""])
	var began := Time.get_ticks_msec()
	var join := ReadingJoin.new(22050, [])
	var line := PackedFloat32Array()
	for i in chunks.size():
		var ch: Dictionary = chunks[i]
		var s: Dictionary = cast.get(String(ch["speaker"]), cast[voice])
		for t in ch["tokens"]:
			var d: Dictionary = t
			if d.has("x") or d.has("acts"):
				print("   %-12s %s %s" % [String(d["text"]), str(d.get("x", {})), str(d.get("acts", []))])
		var a := Delivery.request_args(s, ch, int(s.get("speaker", 0)), String(s.get("blend", "")))
		a["lexicon"] = "off"
		a["inflect"] = true
		var id := host.request("", String(s["voice"]), dir.path_join("t_%d.wav" % i), a, null)
		var res: Array = []
		while true:
			res = await host.synthesized
			if int(res[0]) == id:
				break
		var got: Dictionary = res[1]
		var wav := String(got.get("wav", ""))
		if wav.is_empty():
			printerr("delivery_take_probe: chunk %d: no audio: %s" % [i, str(got)])
			continue
		join.sr = int(got.get("sample_rate", join.sr))
		var part := Splice.read_wav(wav)
		DirAccess.remove_absolute(wav)
		line.append_array(join.add(chunks, i, part, got.get("tokens", []), s, 1.0, got.get("phones", [])))
	var fx := VoiceFX.new()
	fx.setup(join.sr)
	Delivery.apply_fx(fx, cast[voice])
	var wet := fx.process_stereo(line)
	Splice.write_wav(path, wet, 2, join.sr)
	print("   -> %s, %.1f s of take, made in %d s" % [path, float(line.size()) / float(join.sr), (Time.get_ticks_msec() - began) / 1000])


## The voices a note names, by hand: name -> settings, as its block has them. [MiniYaml] reads a block, and the slots'
## defaults fill what it does not say.
func _cast_of(src: String) -> Dictionary:
	var yaml := src.get_slice("---", 1)
	var parsed := MiniYaml.parse(yaml)
	var data: Dictionary = parsed["data"] if bool(parsed["ok"]) else {}
	var voices: Dictionary = ((data.get("ghost", {}) as Dictionary).get("voice", {}) as Dictionary).get("voices", {})
	var out := {}
	for name in voices:
		var s: Dictionary = ReadingPanel.SLOT_DEFAULTS.duplicate()
		s.merge(voices[name], true)
		out[String(name)] = s
	return out
