extends Node

## Not a gate. Drives a real dispatch desk ([DispatchMedium]) over a note with a synthetic voice ([method
## DispatchScript.rehearsal]: every word at a steady pace, plus the rests the script asks for) and writes PNGs to look at.
##
##   GHOST_PROBE_GPU=1 tests/run_boot_probe.sh tests/dispatch/dispatch_look_probe.gd 600 \
##       --out <dir>/d --note <a note .md> [--picture <png>] [--seed N] --times 3,8,20 [--every S] [--words W] [--live 1]
##
## `--picture` stands in for every picture the note shows. `--every S` photographs every S seconds to the end. `--live 1`
## hands the words a sentence at a time, a few seconds ahead, as a live reading does. `--sound <wav>` writes what the desk
## sounds like over the whole run to a file. It prints where each action falls, and asserts only that a frame is not uniform.

const W := 1280
const H := 720
const DT := 1.0 / 30.0

var _out := "user://dispatch"
var _note := ""
var _picture := ""
var _seed := 7
var _times: Array = [3.0, 10.0]
var _every := 0.0
var _word := 0.32
var _live := false
var _sound := ""
var _flat := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if i + 1 >= args.size():
			break
		match args[i]:
			"--out": _out = args[i + 1]
			"--note": _note = args[i + 1]
			"--picture": _picture = args[i + 1]
			"--seed": _seed = int(args[i + 1])
			"--every": _every = float(args[i + 1])
			"--words": _word = float(args[i + 1])
			"--live": _live = args[i + 1] == "1"
			"--sound": _sound = args[i + 1]
			"--times":
				_times = []
				for s in String(args[i + 1]).split(","):
					_times.append(float(s))
	var source := FileAccess.get_file_as_string(_note)
	if source.is_empty():
		print("dispatch_look_probe: no note at '%s'" % _note)
		get_tree().quit(2)
		return
	var parsed := DispatchScript.parse(source)
	var pictures := {}
	if not _picture.is_empty():
		for s in parsed["spans"]:
			pictures[String((s as Dictionary)["key"])] = _picture
		for a in parsed["actions"]:
			if String((a as Dictionary)["kind"]) == "picture":
				pictures[String(a["key"])] = _picture
	var words := DispatchScript.rehearsal(parsed, _word)
	var stage := SubViewport.new()
	stage.size = Vector2i(W, H)
	stage.own_world_3d = true
	stage.transparent_bg = false
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(stage)
	Director.detach()
	var medium: Medium = Medium.make("dispatch")
	medium.mount(stage)
	Director.attach(stage, medium)
	Director.hold(true)
	var subs: Subtitles = preload("res://src/show/subtitles.gd").new()
	subs.words = [] if _live else words
	subs.document = {"source": source, "dispatch": {"seed": _seed, "pictures": pictures}, "title": "Targeted Individuality",
		"author": "Pen & Ink"}
	add_child(subs)
	medium.bind_captions(subs)
	var end := float((words.back() as Dictionary)["t1"]) + 8.0
	var actions: Array = parsed["actions"]
	for a in actions:
		var k := String((a as Dictionary)["kind"])
		print("dispatch_look_probe: %-8s at word %5d (~%7.1fs) rest %.1f  %s" % [k, int(a["after"]), _at(words, int(a["after"])),
			float(a["rest"]), String(a.get("label", a.get("place", a.get("screen", a.get("at", "")))))])
	print("dispatch_look_probe: %d words, %d actions, %.0fs" % [words.size(), actions.size(), end])
	if _every > 0.0:
		_times = []
		var tt := _every
		while tt < end:
			_times.append(tt)
			tt += _every
	_times.sort()
	var t := 0.0
	var fed := 0
	var audio := PackedVector2Array()
	var desk := medium as DispatchMedium
	var heard := DispatchSounds.new(desk)
	Spectrum.virtual_clock = 0.0
	for want in _times:
		while t < float(want):
			t += DT
			Spectrum.virtual_clock = t
			Spectrum.current.time = t
			if _live:
				# a sentence at a time, three seconds before it is heard
				while fed < words.size() and float((words[fed] as Dictionary)["t0"]) < t + 3.0:
					fed += 1
				if fed > subs.words.size():
					subs.words = words.slice(0, fed)
			medium.advance(Spectrum.current, DT, 1.0)
			if not _sound.is_empty():
				audio.append_array(heard.render(int(round(t * DispatchSounds.RATE)) - audio.size()))
			if float(want) - t < 1.6 or int(round(t / DT)) % 300 == 0:
				await get_tree().process_frame
		await get_tree().process_frame
		var img := stage.get_texture().get_image()
		var path := "%s_t%06.1f.png" % [_out, float(want)]
		img.save_png(path)
		var st := _spread(img)
		if st < 0.02:
			_flat += 1
		var saying := ""
		for w in words:
			if float((w as Dictionary)["t0"]) <= desk._now and float(w["t1"]) >= desk._now - 0.3:
				saying = String(w["text"])
		print("dispatch_look_probe: t=%.1f (spread %.3f) %s - looking at %s, saying \"%s\"" % [want, st, path, desk.looking_at(desk._now), saying])
	if not _sound.is_empty():
		_write_wav(_sound, audio)
	print("dispatch_look_probe: done, %d flat" % _flat)
	Spectrum.virtual_clock = -1.0
	Director.hold(false)
	Director.detach()
	stage.queue_free()
	for _i in 3:
		await get_tree().process_frame
	get_tree().quit(1 if _flat > 0 else 0)


static func _at(words: Array, si: int) -> float:
	if words.is_empty():
		return 0.0
	return float((words[clampi(si, 0, words.size() - 1)] as Dictionary)["t0"])


static func _spread(img: Image) -> float:
	var lo := 1.0
	var hi := 0.0
	for y in range(0, img.get_height(), 37):
		for x in range(0, img.get_width(), 41):
			var v := img.get_pixel(x, y).get_luminance()
			lo = minf(lo, v)
			hi = maxf(hi, v)
	return hi - lo


static func _write_wav(path: String, frames: PackedVector2Array) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	var n := frames.size()
	var rate := DispatchSounds.RATE
	f.store_buffer("RIFF".to_ascii_buffer())
	f.store_32(36 + n * 4)
	f.store_buffer("WAVEfmt ".to_ascii_buffer())
	f.store_32(16)
	f.store_16(1)
	f.store_16(2)
	f.store_32(rate)
	f.store_32(rate * 4)
	f.store_16(4)
	f.store_16(16)
	f.store_buffer("data".to_ascii_buffer())
	f.store_32(n * 4)
	for v in frames:
		f.store_16(int(clampf(v.x * 8.0, -1.0, 1.0) * 32767.0) & 0xFFFF)
		f.store_16(int(clampf(v.y * 8.0, -1.0, 1.0) * 32767.0) & 0xFFFF)
	f.close()
