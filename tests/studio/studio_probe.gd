extends Node

## Not a gate. Drives a real studio ([StudioMedium]) over a note with a steady voice ([method StudioScript.rehearsal]) and writes
## PNGs to look at, and what the studio sounds like over the run to a WAV.
##
##   GHOST_PROBE_GPU=1 tests/run_boot_probe.sh tests/studio/studio_probe.gd 900 \
##       --out <dir>/s --note <a note .md> --sounds <dir> [--times 3,8,20] [--every S] [--until S] [--wait 1] [--sound <wav>]
##       [--eye x,y,z --aim x,y,z]
##
## `--sounds` is where the act sounds are made and kept (a real disk: never the author's own folder). `--wait 1` holds the run
## until every act's sound is made, so the WAV and the meters hear them. `--sound` writes the studio's sound from 0 to the end.
## `--eye/--aim` photographs from there instead of the chair (the set's space, m). `--prop ROLE=FILE` plays ROLE by the prop in FILE
## (`{thing, materials}`, as the library keeps one) in place of its fixture. `--scene ROLE` writes the studio as an agent placing
## that thing sees it ([StudioScene]: its report printed, its pictures beside the probe's) and stops. The studio's things are the fixture props
## (tests/fixtures/studio/), held in a library beside the pictures, and the head performs the fixture bank. It prints where each act falls and asserts only
## that a frame is not uniform.

const W := 1280
const H := 720
const DT := 1.0 / 30.0

var _out := "user://studio"
var _props := {}                       # `--prop ROLE=FILE`: a prop file (`{thing, materials}`, as the library keeps one) playing ROLE
var _scene_role := ""                  # `--scene ROLE`: the studio as an agent placing it sees it, written and printed, then done
var _note := ""
var _sounds := ""
var _times: Array = [3.0, 10.0]
var _every := 0.0
var _until := INF
var _wait := false
var _sound := ""
var _eye: Variant = null
var _aim := Vector3.ZERO
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
			"--sounds": _sounds = args[i + 1]
			"--every": _every = float(args[i + 1])
			"--until": _until = float(args[i + 1])
			"--wait": _wait = args[i + 1] == "1"
			"--sound": _sound = args[i + 1]
			"--scene": _scene_role = args[i + 1]
			"--prop":
				var pair := String(args[i + 1]).split("=", true, 1)
				if pair.size() == 2:
					_props[pair[0]] = pair[1]
			"--eye", "--aim":
				var v := String(args[i + 1]).split_floats(",")
				if v.size() == 3:
					if args[i] == "--eye":
						_eye = Vector3(v[0], v[1], v[2])
					else:
						_aim = Vector3(v[0], v[1], v[2])
			"--times":
				_times = []
				for s in String(args[i + 1]).split(","):
					_times.append(float(s))
	if not _scene_role.is_empty():
		# the studio as an agent placing a thing sees it ([StudioScene]): its report printed, its pictures beside the probe's
		var seen: Dictionary = await StudioScene.look(_fixture_makes(), {}, _scene_role, ProjectSettings.globalize_path(_out.get_base_dir()))
		print("studio_probe: scene report\n" + String(seen["report"]))
		print("studio_probe: scene views %s" % str(seen["views"]))
		get_tree().quit(0)
		return
	var source := FileAccess.get_file_as_string(_note)
	if source.is_empty() or _sounds.is_empty():
		print("studio_probe: needs --note <a note .md> and --sounds <dir>")
		get_tree().quit(2)
		return
	StudioSounds.root = _sounds
	var parsed := StudioScript.parse(source)
	for u in parsed["unknown"]:
		print("studio_probe: act %d does not know '%s'" % [int(u[0]), String(u[1])])
	var words := StudioScript.rehearsal(parsed)
	var stage := SubViewport.new()
	stage.size = Vector2i(W, H)
	stage.own_world_3d = true
	stage.transparent_bg = false
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(stage)
	Director.detach()
	var medium: Medium = Medium.make("studio")
	medium.mount(stage)
	Director.attach(stage, medium)
	Director.hold(true)
	var studio := medium as StudioMedium
	var subs: Subtitles = preload("res://src/show/subtitles.gd").new()
	subs.words = words
	var head := FrontMatter.read_block(source)
	var title := String((head.data as Dictionary).get("title", "")) if head.ok and head.data is Dictionary else ""
	subs.document = {"source": source, "title": title, "author": ""}
	# the studio's things: the fixtures held in a library of the probe's own (a real disk beside its pictures), each playing its role
	subs.document["medium"] = {"makes": _fixture_makes()}
	# ...and the head's phrases, the fixture bank's
	subs.document["head"] = HeadBank.phrases_of(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/studio/head_bank.json")))
	add_child(subs)
	medium.bind_captions(subs)
	var end := minf(float((words.back() as Dictionary)["t1"]) + 6.0, _until)
	for a in parsed["acts"]:
		var at := float((words[mini(int(a["after"]), words.size() - 1)] as Dictionary)["t0"])
		print("studio_probe: %-8s %-7s %-12s %5.1fs  before word %4d (~%6.1fs)%s" % [String(a["verb"]), String(a["thing"]), String(a["side"]),
			float(a["secs"]), int(a["after"]), at, "  under" if bool(a["under"]) else ""])
	print("studio_probe: %d words, %d acts, %.0fs" % [words.size(), (parsed["acts"] as Array).size(), end])
	if _every > 0.0:
		_times = []
		var tt := _every
		while tt < end:
			_times.append(tt)
			tt += _every
	_times.sort()
	Spectrum.virtual_clock = DT
	Spectrum.current.time = DT
	# the set and the acts made, and (asked) every sound
	var began := Time.get_ticks_msec()
	while true:
		medium.advance(Spectrum.current, DT, 1.0)
		await get_tree().process_frame
		var made := not studio._made.is_empty() or (parsed["acts"] as Array).is_empty()
		if made and (not _wait or studio._sounds.ready()):
			break
		if Time.get_ticks_msec() - began > 600000:
			print("studio_probe: gave up waiting for the sounds")
			break
	print("studio_probe: set and acts ready in %.1fs%s" % [(Time.get_ticks_msec() - began) / 1000.0, ", every sound made" if studio._sounds.ready() else ""])
	var t := 0.0
	var audio := PackedVector2Array()
	for want in _times + ([end] if not _sound.is_empty() else []):
		while t < float(want):
			t += DT
			Spectrum.virtual_clock = t
			Spectrum.current.time = t
			medium.advance(Spectrum.current, DT, 1.0)
			if not _sound.is_empty():
				var n := int(round(t * StudioSounds.RATE)) - audio.size()
				if n > 0:
					audio.append_array(studio._sounds.render(float(audio.size()) / StudioSounds.RATE, n))
			if float(want) - t < 0.5:
				await get_tree().process_frame
		if not _times.has(want):
			continue
		var put := func() -> void: studio._cam.look_at_from_position(_eye, _aim, Vector3.UP)
		if _eye is Vector3:
			RenderingServer.frame_pre_draw.connect(put)
		await get_tree().process_frame
		await get_tree().process_frame
		if _eye is Vector3:
			RenderingServer.frame_pre_draw.disconnect(put)
		var img := stage.get_texture().get_image()
		var path := "%s_t%06.1f.png" % [_out, float(want)]
		img.save_png(path)
		var st := _spread(img)
		if st < 0.02:
			_flat += 1
		var lv := studio._sounds.level_at(t)
		print("studio_probe: t=%.1f (spread %.3f) %s  meters L %.0f R %.0f dB" % [want, st, path, lv.x, lv.y])
	if not _sound.is_empty():
		_write_wav(_sound, audio)
		print("studio_probe: wrote %.1fs of sound to %s" % [audio.size() / float(StudioSounds.RATE), _sound])
	print("studio_probe: done, %d flat" % _flat)
	Spectrum.virtual_clock = -1.0
	Director.hold(false)
	Director.detach()
	stage.queue_free()
	for _i in 3:
		await get_tree().process_frame
	get_tree().quit(1 if _flat > 0 else 0)


static func _spread(img: Image) -> float:
	var lo := 1.0
	var hi := 0.0
	for y in range(0, img.get_height(), 16):
		for x in range(0, img.get_width(), 16):
			var l := img.get_pixel(x, y).get_luminance()
			lo = minf(lo, l)
			hi = maxf(hi, l)
	return hi - lo


static func _write_wav(path: String, frames: PackedVector2Array) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	var n := frames.size()
	f.store_buffer("RIFF".to_ascii_buffer())
	f.store_32(36 + n * 4)
	f.store_buffer("WAVEfmt ".to_ascii_buffer())
	f.store_32(16)
	f.store_16(1)
	f.store_16(2)
	f.store_32(StudioSounds.RATE)
	f.store_32(StudioSounds.RATE * 4)
	f.store_16(4)
	f.store_16(16)
	f.store_buffer("data".to_ascii_buffer())
	f.store_32(n * 4)
	for v in frames:
		f.store_16(int(clampf(v.x, -1.0, 1.0) * 32767.0) & 0xffff)
		f.store_16(int(clampf(v.y, -1.0, 1.0) * 32767.0) & 0xffff)
	f.close()


## The studio's things for the probe: the fixture props (tests/fixtures/studio/) held as drafts in a library beside its pictures
## ([member Library.root]), each the make of its role.
func _fixture_makes() -> Dictionary:
	Library.root = ProjectSettings.globalize_path(_out.get_base_dir().path_join("library"))
	var by_role := {"camera": "vlog_camera", "tripod": "tripod", "ring_light": "ring_light", "microphone": "microphone",
		"block": "wood_block", "brush": "powder_brush"}
	var makes := {}
	for role in by_role:
		var path := String(_props[role]) if _props.has(role) else "res://tests/fixtures/studio/%s.prop.json" % by_role[role]
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not (d is Dictionary):
			continue
		var thing: Dictionary = (d as Dictionary)["thing"]
		if ThingLibrary.keep(thing, (d as Dictionary)["materials"], String((d as Dictionary).get("line", "")), true).is_empty():
			makes[role] = {"kept": String(thing["name"])}
	return makes
