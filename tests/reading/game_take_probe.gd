extends Node

## NOT a gate. A SCRIPT OF SEVERAL VOICES, MADE AND MIXED AS AN EXPORT MIXES IT (next/tabletop.md "Voices over each other"): real voices from the real host, one [ReadingJoin], one [VoiceFX], each voice where it sits. To hear overlaps, and to measure them: for what no fake tone can answer.
##
##   tests/run_boot_probe.sh tests/reading/game_take_probe.gd 1200 --script <say file or files, comma separated> --note <the note's file> --out <file.wav> [--turn 0.2]

const TAKES := "user://game_take"
var host: VoiceHost


func _ready() -> void:
	_run.call_deferred()



func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var scripts := PackedStringArray()
	var note := ""
	var out := ""
	var turn := 0.2
	for i in args.size() - 1:
		match args[i]:
			"--script":
				scripts = String(args[i + 1]).split(",", false)
			"--note":
				note = args[i + 1]
			"--out":
				out = args[i + 1]
			"--turn":
				turn = float(args[i + 1])
	var body := PackedStringArray()
	for s in scripts:
		body.append(FileAccess.get_file_as_string(s))
	var cast := _cast_of(FileAccess.get_file_as_string(note))
	print("game_take_probe: voices %s" % str(cast.keys()))
	var reader := String(cast.keys()[0])
	var speak := String(CardReading.parse("<!-- table: begin -->\n\n" + "\n\n".join(body))["speakable"])
	var plan := ReadingPlan.make(speak, "", {"reader": reader, "hesitate": true, "bare": 1.2, "outro": 0.0})
	var chunks: Array = plan["chunks"]
	print("game_take_probe: %d chunks" % chunks.size())
	host = VoiceHost.new()
	add_child(host)
	host.start()
	while not host.is_up():
		await get_tree().process_frame
	var dir := ProjectSettings.globalize_path(TAKES)
	DirAccess.make_dir_recursive_absolute(dir)
	var began := Time.get_ticks_msec()
	var join := ReadingJoin.new(22050, [])
	var line := PackedFloat32Array()
	var words: Array = join.words
	for i in chunks.size():
		var ch: Dictionary = chunks[i]
		var s: Dictionary = cast.get(String(ch["speaker"]), cast[reader])
		var a := Delivery.request_args(s, ch, int(s.get("speaker", 0)))
		a["lexicon"] = "off"
		var id := host.request("", String(s["voice"]), dir.path_join("t_%d.wav" % i), a, null)
		var res: Array = []
		while true:
			res = await host.synthesized
			if int(res[0]) == id:
				break
		var got: Dictionary = res[1]
		var wav := String(got.get("wav", ""))
		if wav.is_empty():
			printerr("game_take_probe: chunk %d: no audio: %s" % [i, str(got)])
			continue
		join.sr = int(got.get("sample_rate", join.sr))
		var part := Splice.read_wav(wav)
		DirAccess.remove_absolute(wav)
		line.append_array(join.add(chunks, i, part, got.get("tokens", []), s, turn, got.get("phones", [])))
	print("game_take_probe: %d chunks made in %d s, %.1f s of take, %d over the line" % [chunks.size(), (Time.get_ticks_msec() - began) / 1000, float(line.size()) / float(join.sr), join.side.size()])
	var fx := VoiceFX.new()
	fx.setup(join.sr)
	var pan := func(who: String) -> float: return Delivery.pan_of_seat(float((cast.get(who, {}) as Dictionary).get("seat", 0.0)))
	var marks: Array = join.marks
	var wet := PackedVector2Array()
	for k in marks.size():
		var m: Dictionary = marks[k]
		if m.has("speaker"):
			Delivery.apply_fx(fx, cast.get(String(m["speaker"]), cast[reader]))
		var a := int(m["at"])
		var b := line.size() if k == marks.size() - 1 else int((marks[k + 1] as Dictionary)["at"])
		if b > a:
			fx.side = join.side_between(a, b, pan)
			wet.append_array(fx.process_stereo(line.slice(a, b)))
	_measure(join, wet, pan)
	Splice.write_wav(out, wet, 2, join.sr)
	print("game_take_probe: -> %s" % out)
	host.stop()
	get_tree().quit(0)


## WHAT THE EAR HAS TO GO ON, IN NUMBERS: how much of the voices over the line is there, and whether each is in its own ear.
func _measure(join: ReadingJoin, wet: PackedVector2Array, pan: Callable) -> void:
	var peak := 0.0
	for f in wet:
		peak = maxf(peak, maxf(absf(f.x), absf(f.y)))
	var clipped := 0
	for f in wet:
		if absf(f.x) >= 0.999 or absf(f.y) >= 0.999:
			clipped += 1
	print("game_take_probe: peak %.3f, %d frames clipped of %d" % [peak, clipped, wet.size()])
	var over := 0
	for v in join.side:
		over += ((v as Dictionary)["pcm"] as PackedFloat32Array).size()
	print("game_take_probe: %.1f s of voice over the line" % (float(over) / float(join.sr)))
	for v in join.side.slice(0, 12):
		var d: Dictionary = v
		print("  %7.2f s  %-6s %.2f s  pan %+.2f" % [float(d["at"]) / float(join.sr), String(d["speaker"]), float((d["pcm"] as PackedFloat32Array).size()) / float(join.sr), float(pan.call(String(d["speaker"])))])


## The voices a note names, by hand: name -> settings, as its block has them. [MiniYaml] reads a block, and the slots' defaults fill what it does not say.
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
