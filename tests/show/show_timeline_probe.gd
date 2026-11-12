extends Node

## show_timeline_probe - what was on screen at a given time of a long render, in about a minute.
##
##   tests/run_boot_probe.sh tests/show/show_timeline_probe.gd 300 \
##       --audio <take.wav> --bake <cache.spec> --at 193.6,258.2
##
## Not a gate. It replays the schedule of a render that takes hours, so a freeze reported at two moments
## can be located without rendering again.
##
## The show is a pure function: the session seed is `hash(fingerprint(audio) : SEED_SALT)` with a constant
## salt (see Director._salt_seed), the running order falls out of that seed, and every cut is driven by the
## spectrum, which a render reads from a baked file. So the whole schedule replays with no audio device,
## window or encoder: feed the Director the same features in the same order and it makes the same decisions.
##
## It fills [Spectrum]'s `current` from the same function a render uses (`_fill_bands_baked`) against a
## stepped clock and calls the Director's own `_process`; nothing reimplements a scheduling decision.
##
## It replays what was scheduled, not what was rendered: the picture is never drawn, so a defect in a
## scene's drawing or frame cost is invisible here. It narrows hours to one scene; the look probes and
## perf_probe take it from there.

const Bake_ := preload("res://src/audio/bake.gd")

var _out: Array = []
var _cuts: Array = []
var _marks: Array = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var audio := _arg(args, "--audio", "")
	var bake := _arg(args, "--bake", "")
	var fps := float(_arg(args, "--fps", "30"))
	for m in _arg(args, "--at", "").split(",", false):
		_marks.append(float(m))

	if audio.is_empty() or not FileAccess.file_exists(audio):
		_say("need --audio <the take .wav the render was made from>")
		return _finish()
	var frames: Array = Bake_.load_cache(bake, Spectrum.BAND_COUNT) if not bake.is_empty() else []
	if frames.is_empty():
		_say("need --bake <the .spec the render read>; without it the cuts are not the "
			+ "render's cuts. Newest is usually the one.")
		return _finish()

	# The seed, derived as a render derives it (the file's fingerprint, salted by the constant), set on the
	# autoload so `Director._resolve_seed` finds it the normal way.
	Spectrum.song_hash = Spectrum._fingerprint(audio)
	Spectrum._baked_frames = frames
	Spectrum._baked = true
	var length := float(frames.size()) / float(Spectrum.BAKE_FPS)
	_say("take %s" % audio.get_file())
	_say("bake %d frames = %.1fs at %d fps" % [frames.size(), length, Spectrum.BAKE_FPS])

	# A stage for the Director to attach to. Scenes are built (which makes the running order real) but
	# nothing is drawn.
	var stage := SubViewport.new()
	stage.own_world_3d = true
	stage.size = Vector2i(320, 180)
	stage.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(stage)
	Director.attach(stage, null)
	_say("session seed %d" % Director.session_seed())
	Director.scene_cut.connect(_on_cut)

	# Driven by hand, both: the engine would otherwise step each autoload once per rendered frame as well,
	# and the replay steps them thousands of times between frames.
	Spectrum.set_process(false)
	Director.set_process(false)
	var dt := 1.0 / fps
	var t := 0.0
	var last_yield := Time.get_ticks_msec()
	while t < length:
	# The real per-frame derivation (energy, onset, tempo, flux, movement) against a clock this probe
	# supplies.
		Spectrum.virtual_clock = t
		Spectrum._process(dt)
		Director._process(dt)
		t += dt
		# The scene tree has to breathe or a freshly cut scene never reaches _ready.
		if Time.get_ticks_msec() - last_yield > 40:
			last_yield = Time.get_ticks_msec()
			await get_tree().process_frame
	_report(length)
	_finish()


func _on_cut() -> void:
	var name := "?"
	if Director._current != null and is_instance_valid(Director._current):
		name = String(Director._current.get_script().resource_path).get_file().get_basename()
	_cuts.append({"t": Spectrum.current.time, "scene": name})


func _report(length: float) -> void:
	_say("")
	_say("%d cut(s) over %.0fs - one scene every %.1fs on average"
		% [_cuts.size(), length, length / maxf(1.0, float(_cuts.size()))])
	for m in _marks:
		var at := float(m)
		var live := {"t": 0.0, "scene": "(nothing cut yet)"}
		var ends := length
		for i in _cuts.size():
			var c: Dictionary = _cuts[i]
			if float(c["t"]) <= at:
				live = c
				ends = float(_cuts[i + 1]["t"]) if i + 1 < _cuts.size() else length
		_say("")
		_say("AT %.1fs -> scene '%s'" % [at, live["scene"]])
		_say("   that scene took the stage at %.1fs and held until %.1fs (%.1fs long)"
			% [float(live["t"]), ends, ends - float(live["t"])])
	_say("")
	_say("the whole running order:")
	for c in _cuts:
		_say("   %8.1fs  %s" % [float(c["t"]), c["scene"]])
	# The neighborhood of each mark, so a scene that merely started near it is visible too.
	for m in _marks:
		_say("")
		_say("cuts within 40s of %.1fs:" % float(m))
		for c in _cuts:
			if absf(float(c["t"]) - float(m)) <= 40.0:
				_say("   %8.1fs  %s" % [float(c["t"]), c["scene"]])


func _say(s: String) -> void:
	_out.append(s)
	print("timeline: " + s)


func _finish() -> void:
	for _i in 3:
		await get_tree().process_frame
	get_tree().quit()


func _arg(args: PackedStringArray, name: String, dflt: String) -> String:
	var i := args.find(name)
	return String(args[i + 1]) if i >= 0 and i + 1 < args.size() else dflt
