extends Node

## Not a gate. Drives a real dispatch desk ([DispatchMedium]) over a note with a synthetic voice ([method
## DispatchScript.rehearsal]: every word at a steady pace, plus the rests the script asks for) and writes PNGs to look at.
##
##   GHOST_PROBE_GPU=1 tests/run_boot_probe.sh tests/dispatch/dispatch_look_probe.gd 600 \
##       --out <dir>/d --note <a note .md> [--picture <png>] [--seed N] --times 3,8,20 [--every S] [--words W] [--live 1]
##
## `--picture` stands in for every picture the note shows. `--every S` photographs every S seconds to the end. `--live 1`
## hands the words a sentence at a time, a few seconds ahead, as a live reading does. `--sound <wav>` writes what the desk
## sounds like over the whole run to a file. `--opening title` opens on the channel's name over the blur, and `--lead S`
## gives the voice's first word S seconds in, as the intro's hold does. `--light K`, `--bright X`, `--shafts k=v,...`, `--fog k=v,...`, `--air a,b`
## and `--heard a,b` are the Environment card's (tests/table/environment_flags.gd); `--terminal`, `--radar`, `--scope` and `--dial`
## (each `#rrggbb`) the Props card's colors for the terminal's text, the radar's glow, the receiver's oscilloscope and its dial lamp;
## `--trace figure|sweep` how the scope draws.
## `--eye x,y,z --aim x,y,z` photographs from there instead of where the desk's camera is (the set's space, m), to see what no
## shot holds - the printer's paper falling past the desk's end, say. With no Environment flag the note's own `environment:` block is
## used. Each `play` mark plays what [method ScreenPlays.record_of] finds (a note played live, a video file), or `--film WHAT=PATH=SECS`
## (a video by hand, each `=`-parted). `--voice <wav>` stands in for the heard audio (the SDR screen reads a voice's bands off it, the
## scope its waveform): the recording's bands, through the receiver's band, and its waveform, whenever any word is said - the
## screens show only the receiver's.
## `--sdr 1` also writes that screen's own picture beside each photograph (`_sdr.png`). `--looks FROM,TO` draws nothing: it prints
## where the camera looks every half second over that stretch, and the word then said, as the whole plan has it.
## It prints where each action falls, and each step of the desk that holds the app's thread over [constant LONG_STEP] ms (a live
## desk snaps its camera past a stall of a second), and asserts only that a frame is not uniform.

const W := 1280
const H := 720
const DT := 1.0 / 30.0
const LONG_STEP := 150

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
var _opening := Openings.DEFAULT
var _lead := 1.0
var _environment := {}             # the Environment card's block ([Surroundings]): --light, --bright, --shafts, --air, --heard
var _glass := {}                   # the screens' colors, as the Props card keeps them: --terminal, --radar, --scope, --dial
var _eye: Variant = null           # --eye and --aim: where every photograph is taken from instead
var _aim := Vector3.ZERO
var _films := {}                   # what each `play` plays -> what it is ([ScreenPlays]), or --film WHAT=PATH=SECS
var _voice := ""                   # --voice: a recording whose bands stand in for the heard audio's
var _sdr := false                  # --sdr 1: the SDR screen's own picture written too
var _looks := Vector2(-1, -1)      # --looks FROM,TO: where the camera looks over that stretch, nothing drawn

const EnvFlags := preload("res://tests/table/environment_flags.gd")


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
			"--voice": _voice = args[i + 1]
			"--sdr": _sdr = args[i + 1] == "1"
			"--looks":
				var lv := String(args[i + 1]).split_floats(",")
				if lv.size() == 2:
					_looks = Vector2(lv[0], lv[1])
			"--opening": _opening = args[i + 1]
			"--lead": _lead = float(args[i + 1])
			"--light", "--bright", "--shafts", "--fog", "--air", "--heard": EnvFlags.take(_environment, args[i], args[i + 1])
			"--terminal": _glass["terminal_screen"] = {"text": args[i + 1]}
			"--radar": _glass["radar_screen"] = {"glow": args[i + 1]}
			"--scope", "--dial", "--trace":
				if not _glass.has("receiver_glow"):
					_glass["receiver_glow"] = {}
				_glass["receiver_glow"][args[i].substr(2)] = args[i + 1]
			"--eye", "--aim":
				var v := String(args[i + 1]).split_floats(",")
				if v.size() == 3:
					if args[i] == "--eye":
						_eye = Vector3(v[0], v[1], v[2])
					else:
						_aim = Vector3(v[0], v[1], v[2])
			"--film":
				var f := String(args[i + 1]).split("=")
				if f.size() == 3:
					_films[f[0]] = {"kind": "file", "ready": true, "video": f[1], "secs": float(f[2]), "size": Vector2i(960, 720), "fps": 30.0, "sound": ""}
			"--times":
				_times = []
				for s in String(args[i + 1]).split(","):
					_times.append(float(s))
	var source := FileAccess.get_file_as_string(_note)
	if source.is_empty():
		print("dispatch_look_probe: no note at '%s'" % _note)
		get_tree().quit(2)
		return
	for what in DispatchScript.films_in(source):
		if not _films.has(what):
			var made := ScreenPlays.record_of(what)
			_films[what] = made
			print("dispatch_look_probe: play %s - %s" % [what, "ready, %.1fs" % float(made.get("secs", 0.0)) if bool(made["ready"]) else String(made["why"])])
	if _environment.is_empty():
		var head := FrontMatter.read_block(source)
		if head.ok and head.data is Dictionary and (head.data as Dictionary).get("environment") is Dictionary:
			_environment = (head.data as Dictionary)["environment"]
	var parsed := DispatchScript.parse(source, _films)
	var pictures := {}
	if not _picture.is_empty():
		for s in parsed["spans"]:
			pictures[String((s as Dictionary)["key"])] = _picture
		for a in parsed["actions"]:
			if String((a as Dictionary)["kind"]) == "picture":
				pictures[String(a["key"])] = _picture
	var words := DispatchScript.rehearsal(parsed, _word, 0.35, _lead)
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
	medium.feed.opening = _opening
	var subs: Subtitles = preload("res://src/show/subtitles.gd").new()
	subs.words = [] if _live else words
	var dispatch := {"seed": _seed, "pictures": pictures, "films": _films}
	dispatch.merge(_glass)
	subs.document = {"source": source, "dispatch": dispatch, "environment": _environment,
		"title": "Targeted Individuality", "author": "Pen & Ink"}
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
	if _looks.y > _looks.x:
		Spectrum.virtual_clock = DT
		Spectrum.current.time = DT
		medium.advance(Spectrum.current, DT, 1.0)
		var was := ""
		var tt := _looks.x
		while tt <= _looks.y:
			var on := desk.looking_at(tt)
			var said := ""
			for w in words:
				if float((w as Dictionary)["t0"]) <= tt and float(w["t1"]) >= tt - 0.3:
					said = String(w["text"])
			print("dispatch_look_probe: looks t=%.1f %-9s %s%s" % [tt, on, "<- turns  " if on != was else "", said])
			was = on
			tt += 0.5
		Spectrum.virtual_clock = -1.0
		Director.hold(false)
		Director.detach()
		stage.queue_free()
		await get_tree().process_frame
		get_tree().quit(0)
		return
	var heard := DispatchSounds.new(desk)
	var voiced: Array = SpectrumBake.bake(_voice, 30, AudioFeatures.BAND_COUNT, AudioFeatures.FREQ_MIN, AudioFeatures.FREQ_MAX,
		AudioFeatures.DB_FLOOR) if not _voice.is_empty() else []
	var voice_info := HeardWave.wav_info(_voice) if not _voice.is_empty() else {}
	if not _voice.is_empty():
		print("dispatch_look_probe: voice %s, %d frames" % [_voice, voiced.size()])
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
			var heard_now: AudioFeatures = Spectrum.current
			if not voiced.is_empty():
				heard_now = AudioFeatures.new()
				heard_now.time = t
				heard_now.bands = _voice_bands(words, desk._now, voiced)
				if _saying(words, desk._now):
					heard_now.hear_from(HeardWave.of_wav.bind(_voice, voice_info, fmod(desk._now, float(voiced.size()) / 30.0)))
			var began := Time.get_ticks_msec()
			medium.advance(heard_now, DT, 1.0)
			if Time.get_ticks_msec() - began > LONG_STEP:
				print("dispatch_look_probe: a step at t=%.2f held the thread %d ms" % [t, Time.get_ticks_msec() - began])
			if not _sound.is_empty():
				audio.append_array(heard.render(int(round(t * DispatchSounds.RATE)) - audio.size()))
			if float(want) - t < 1.6 or int(round(t / DT)) % 300 == 0:
				began = Time.get_ticks_msec()
				await get_tree().process_frame
				if Time.get_ticks_msec() - began > LONG_STEP:
					print("dispatch_look_probe: a frame at t=%.2f took %d ms" % [t, Time.get_ticks_msec() - began])
		# (set as each frame is drawn: the Director advances the desk every frame, which turns its camera back to its spot)
		var put := func() -> void: desk._cam.look_at_from_position(_eye, _aim, Vector3.UP)
		if _eye is Vector3:
			RenderingServer.frame_pre_draw.connect(put)
			await get_tree().process_frame
		await get_tree().process_frame
		if _eye is Vector3:
			RenderingServer.frame_pre_draw.disconnect(put)
		var img := stage.get_texture().get_image()
		var path := "%s_t%06.1f.png" % [_out, float(want)]
		img.save_png(path)
		if _sdr and desk._screens.spectrum != null:
			desk._screens.spectrum.get_texture().get_image().save_png(path.trim_suffix(".png") + "_sdr.png")
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


## The heard audio's bands at [param t] with [param voiced] (a recording's, 30 a second) standing in for the voice: its
## frames in turn, through the receiver's band (300-2600 Hz, rolled off 12 dB an octave), while any of [param words] is said;
## silence between.
static func _saying(words: Array, t: float) -> bool:
	for w in words:
		if float((w as Dictionary)["t0"]) <= t and t <= float(w["t1"]) + 0.1:
			return true
	return false


static func _voice_bands(words: Array, t: float, voiced: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(AudioFeatures.BAND_COUNT)
	for w in words:
		if float((w as Dictionary)["t0"]) <= t and t <= float(w["t1"]) + 0.1:
			var raw: PackedFloat32Array = voiced[int(t * 30.0) % voiced.size()]
			var ratio := AudioFeatures.FREQ_MAX / AudioFeatures.FREQ_MIN
			for b in out.size():
				var hz := AudioFeatures.FREQ_MIN * pow(ratio, (float(b) + 0.5) / float(out.size()))
				var off := maxf(log(300.0 / hz), log(hz / 2600.0)) / log(2.0)
				out[b] = clampf(raw[b] - maxf(off, 0.0) * 12.0 / AudioFeatures.DB_FLOOR, 0.0, 1.0)
			break
	return out


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
