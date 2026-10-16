extends Node

## NOT a gate. Drives a real desk-medium session over a Proof episode's lesson with a SYNTHETIC voice
## - every spoken word at a steady pace, and the rests [method DeskScript.parse] asks the voice for,
## sized from the episode's own ink - and writes PNGs to look at.
##
##   GHOST_PROBE_GPU=1 tests/run_boot_probe.sh tests/desk/desk_look_probe.gd 400 \
##       --out <dir>/d --episode <episode folder> --times 3,8,20 [--every S] [--page 1]
##
## `--every S` photographs every S seconds to the end of the lesson instead of `--times`. `--page 1`
## also writes the flat pad texture beside each frame. `--title` and `--byline` are the note's, for the
## title screen over the intro (`--lead S` holds the first word back that long, as an intro does).
## It asserts only that a frame is not uniform.

const W := 1280
const H := 720
const DT := 1.0 / 30.0
## The synthetic voice: a word every this many seconds, and a breath at each sentence's end.
const WORD := 0.32
const SENTENCE := 0.35

var _out := "user://desk"
var _episode := ""
var _times: Array = [3.0, 10.0]
var _every := 0.0
var _page := false
var _flat := 0
var _title := ""
var _byline := ""
var _lead := 1.0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if i + 1 >= args.size():
			break
		match args[i]:
			"--out": _out = args[i + 1]
			"--episode": _episode = args[i + 1]
			"--every": _every = float(args[i + 1])
			"--page": _page = args[i + 1] == "1"
			"--title": _title = args[i + 1]
			"--byline": _byline = args[i + 1]
			"--lead": _lead = float(args[i + 1])
			"--times":
				_times = []
				for s in String(args[i + 1]).split(","):
					_times.append(float(s))
	var source := FileAccess.get_file_as_string(_episode.path_join("script.md"))
	var ink: Variant = JSON.parse_string(FileAccess.get_file_as_string(_episode.path_join("ink.json")))
	if source.is_empty() or not (ink is Dictionary):
		print("desk_look_probe: no script.md and ink.json in '%s'" % _episode)
		get_tree().quit(2)
		return
	# the episode's seed is its folder's: show and number
	var ep := ProofEpisode.open(_episode.get_base_dir().get_file(), int(_episode.get_file()))
	ep.dir = _episode
	var desk := {"dir": _episode, "seed": ep.seed, "ink": ink}
	var lengths := ep.lengths()
	var parsed: Dictionary = DeskScript.parse(source, lengths)
	var words := _timeline(source, parsed)
	var stage := SubViewport.new()
	stage.size = Vector2i(W, H)
	stage.own_world_3d = true
	stage.transparent_bg = false
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(stage)
	Director.detach()
	var medium: Medium = Medium.make("desk")
	medium.mount(stage)
	Director.attach(stage, medium)
	Director.hold(true)
	var subs: Subtitles = preload("res://src/show/subtitles.gd").new()
	subs.words = words
	subs.document = {"source": source, "desk": desk, "title": _title, "byline": _byline}
	add_child(subs)
	if medium.bind_captions(subs):
		subs.overlay_hidden = true
	var end := float((words.back() as Dictionary)["t1"]) + 6.0
	print("desk_look_probe: %d synthetic words, %d pen actions, %.0fs" % [words.size(),
		(parsed["actions"] as Array).size(), end])
	if _every > 0.0:
		_times = []
		var tt := _every
		while tt < end:
			_times.append(tt)
			tt += _every
	_times.sort()
	var t := 0.0
	Spectrum.virtual_clock = 0.0
	for want in _times:
		while t < float(want):
			t += DT
			Spectrum.virtual_clock = t
			Spectrum.current.time = t
			medium.advance(Spectrum.current, DT, 1.0)
			await get_tree().process_frame
		await get_tree().process_frame
		var img := stage.get_texture().get_image()
		var path := "%s_t%05.1f.png" % [_out, float(want)]
		img.save_png(path)
		if _page:
			(medium as DeskMedium)._vp.get_texture().get_image().save_png("%s_t%05.1f_page.png" % [_out, float(want)])
		var st := _spread(img)
		if st < 0.02:
			_flat += 1
		print("desk_look_probe: t=%.1f (spread %.3f) %s" % [want, st, path])
	print("desk_look_probe: done, %d flat" % _flat)
	Spectrum.virtual_clock = -1.0
	Director.hold(false)
	Director.detach()
	stage.queue_free()
	for _i in 3:
		await get_tree().process_frame
	get_tree().quit(1 if _flat > 0 else 0)


## The voice's words as a steady reader would say them: one every [constant WORD] seconds, a breath
## at each sentence's end, and before each run of pen actions the rest the lesson asks for.
func _timeline(_source: String, parsed: Dictionary) -> Array:
	var spoken: PackedStringArray = parsed["spoken"]
	var rests := {}
	for a in parsed["actions"]:
		var k := int((a as Dictionary)["after"])
		rests[k] = float(rests.get(k, 0.0)) + float((a as Dictionary)["dur"])
	var out: Array = []
	var t := _lead
	for i in spoken.size():
		if rests.has(i):
			t += float(rests[i]) + 0.4
		out.append({"text": spoken[i], "t0": t, "t1": t + WORD * 0.9, "sentence": 0})
		t += WORD
	return out


func _spread(img: Image) -> float:
	var lo := 1.0
	var hi := 0.0
	for y in range(0, img.get_height(), 24):
		for x in range(0, img.get_width(), 24):
			var v := img.get_pixel(x, y).get_luminance()
			lo = minf(lo, v)
			hi = maxf(hi, v)
	return hi - lo
