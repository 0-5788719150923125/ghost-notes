extends Node

## What one still frame of an episode's table costs to draw (next/compute.md step 1, next/csharp.md): the stage's own time on the
## graphics card and on the renderer's side of the processor - never the wall's - at the four sizes the Graphics menu's Resolution
## offers, then at one of them (`--size`, by default the 1920 x 1080 the live stage is drawn at) with one thing taken out at a time,
## and each viewport under the table by itself. A probe, for looking.
##
##   GHOST_PROBE_GPU=1 tests/run_boot_probe.sh tests/table/table_render_probe.gd 300 --take=user://generative/take_N.json \
##       [--at=150] [--dir=<the episode's copy>] [--size=3840x2160] [--only-inner]
##
## The episode is a copy, never the author's: `--dir`, by default the one `episode_bake_probe` leaves in `dist/episode_bake_probe/`
## (run that first on the same take). The author's graphics rows are read as the app's stage reads them ([method Graphics.bind_stage]).
##
## Two things falsify its figures: a training run or export beside it (every figure is both of them; `nvidia-smi` first, and what
## uses the card is said here as it starts), and a large window (a virtual display copies each frame off the card, at 3840 x 2160
## five frames a second, and a card that idles between frames reads a pass at twice its cost). The window is made tiny here: the stage
## is a viewport of its own size whatever the window's is, as it is in the app.

var medium: TableMedium
var stage: SubViewport
var rid: RID


func _ready() -> void:
	_run.call_deferred()


func _arg(args: PackedStringArray, key: String, fallback: String) -> String:
	for a in args:
		if a.begins_with("--" + key + "="):
			return a.substr(key.length() + 3)
		if a == "--" + key:
			return "1"
	return fallback


## Mean GPU and processor milliseconds of the stage's own render over [param n] frames, and the wall's a frame.
func _measure(n := 40) -> Vector3:
	for _i in 12:
		await get_tree().process_frame
	var gpu := 0.0
	var cpu := 0.0
	var t0 := Time.get_ticks_usec()
	for _i in n:
		await get_tree().process_frame
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(rid)
	return Vector3(gpu / float(n), cpu / float(n), float(Time.get_ticks_usec() - t0) / 1000.0 / float(n))


func _say(label: String, v: Vector3) -> void:
	print("render %-46s GPU %7.2f ms   renderer's CPU %6.2f ms   wall %7.2f ms" % [label, v.x, v.y, v.z])


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var take: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_arg(args, "take", "")))
	var book: Dictionary = (take.get("book", {}) as Dictionary).duplicate(true)
	if book.get("start_words") is Array:
		book["start_words"] = PackedStringArray(book["start_words"] as Array)
	var pay: Dictionary = book.get("table", {})
	pay["dir"] = _arg(args, "dir", ProjectSettings.globalize_path("res://dist/episode_bake_probe"))
	book["table"] = pay
	var at := _arg(args, "at", "150").to_float()
	var split := Vector2i(1920, 1080)
	var asked := _arg(args, "size", "").split("x")
	if asked.size() == 2 and asked[0].to_int() > 0 and asked[1].to_int() > 0:
		split = Vector2i(asked[0].to_int(), asked[1].to_int())
	# a window the virtual display copies in no time (see the header), and who else has the card
	get_window().size = Vector2i(320, 180)
	var smi: Array = []
	if OS.execute("nvidia-smi", ["--query-gpu=utilization.gpu,memory.used", "--format=csv,noheader"], smi) == 0 and not smi.is_empty():
		print("render: the card as this starts (its use, its memory in use): %s" % String(smi[0]).strip_edges())

	stage = SubViewport.new()
	stage.size = Vector2i(1280, 720)
	stage.own_world_3d = true
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(stage)
	rid = stage.get_viewport_rid()
	Director.detach()
	medium = Medium.make("table") as TableMedium
	medium.mount(stage)
	Director.attach(stage, medium)
	Director.hold(true)
	# the author's own graphics rows, as the app's stage has them
	Graphics.bind_stage(stage)
	var subs: Subtitles = preload("res://src/show/subtitles.gd").new()
	add_child(subs)
	medium.bind_captions(subs)
	Director.intro_hold = float((take.get("bookend", {}) as Dictionary).get("in", Director.intro_hold)) if take.get("bookend") is Dictionary else Director.intro_hold
	subs.words = take.get("words", [])
	subs.document = book
	medium._key = ""
	medium._ensure_doc()
	var w = medium._work
	var ph = w.physics
	if ph != null:
		ph.bake_until(at + 2.0)
	Spectrum.virtual_clock = at
	Spectrum.current.time = at
	medium.advance(Spectrum.current, 1.0 / 60.0, 1.0)
	RenderingServer.viewport_set_measure_render_time(rid, true)
	print("render: stage msaa_3d %d, scaling %.2f, shadow atlas %d; rows: occlusion %s, bounce %s, subsurface %s, fog %s, shadows %s, supersample %s"
		% [stage.msaa_3d, stage.scaling_3d_scale, stage.positional_shadow_atlas_size, str(Graphics.value("occlusion")), str(Graphics.value("bounce")),
		str(Graphics.value("subsurface")), str(Graphics.value("fog")), str(Graphics.value("shadows")), str(Graphics.value("supersample"))])

	# What is drawn, counted
	for _i in 30:
		await get_tree().process_frame
	var RS := RenderingServer
	print("render: seen  - %d objects, %d draw calls, %d primitives" % [
		RS.viewport_get_render_info(rid, RS.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RS.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME),
		RS.viewport_get_render_info(rid, RS.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RS.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
		RS.viewport_get_render_info(rid, RS.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RS.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)])
	print("render: shadows - %d objects, %d draw calls, %d primitives" % [
		RS.viewport_get_render_info(rid, RS.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RS.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME),
		RS.viewport_get_render_info(rid, RS.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RS.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
		RS.viewport_get_render_info(rid, RS.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RS.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)])
	var lights: Array = medium.find_children("*", "Light3D", true, false)
	var casting := 0
	for l in lights:
		casting += 1 if (l as Light3D).shadow_enabled and (l as Light3D).visible else 0
	print("render: %d lights, %d casting shadows; %d mesh instances; %d viewports under the medium" % [lights.size(), casting,
		medium.find_children("*", "GeometryInstance3D", true, false).size(), medium.find_children("*", "SubViewport", true, false).size()])

	# The viewports under the table (a painted surface's canvases): each one's own cost a frame
	stage.size = split
	var inner: Array = medium.find_children("*", "SubViewport", true, false)
	for v in inner:
		RS.viewport_set_measure_render_time((v as SubViewport).get_viewport_rid(), true)
	for _i in 30:
		await get_tree().process_frame
	for v in inner:
		var sv: SubViewport = v
		var g := 0.0
		var c := 0.0
		for _i in 30:
			await get_tree().process_frame
			g += RS.viewport_get_measured_render_time_gpu(sv.get_viewport_rid())
			c += RS.viewport_get_measured_render_time_cpu(sv.get_viewport_rid())
		print("render: inner viewport '%s' %d x %d, update mode %d, %d children: GPU %.2f ms, CPU %.2f ms a frame" % [sv.name, sv.size.x, sv.size.y,
			sv.render_target_update_mode, sv.get_child_count(), g / 30.0, c / 30.0])
	# The frame the stage is shown in: the stage's picture through the note's Look, at the window's own size, multisampled as the
	# project's 2D is - what the app draws over and above the stage, every frame, whether the stage drew or not
	var screen := SubViewport.new()
	screen.size = Vector2i(3840, 2160)
	screen.disable_3d = true
	screen.msaa_2d = int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_2d", 0)) as Viewport.MSAA
	screen.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(screen)
	var view := TextureRect.new()
	view.texture = stage.get_texture()
	view.size = Vector2(screen.size)
	screen.add_child(view)
	RS.viewport_set_measure_render_time(screen.get_viewport_rid(), true)
	for look in [{}, {"bloom": 0.05, "vignette": 0.4}]:
		Filters.apply(view, look, view.size)
		for _i in 20:
			await get_tree().process_frame
		var g := 0.0
		for _i in 30:
			await get_tree().process_frame
			g += RS.viewport_get_measured_render_time_gpu(screen.get_viewport_rid())
		print("render: a 3840 x 2160 window's own frame (the stage's picture scaled to it), 2D multisampling %d, look %s: GPU %.2f ms a frame" % [screen.msaa_2d,
			"none" if (look as Dictionary).is_empty() else str(look), g / 30.0])
	screen.queue_free()
	if _arg(args, "only-inner", "") != "":
		print("render: done")
		get_tree().quit(0)
		return

	# By size: what grows with the pixels is the graphics card's
	for size in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)]:
		stage.size = size
		_say("%d x %d, as the app draws it" % [size.x, size.y], await _measure())

	# At one size (the live stage's, or `--size`): one thing out at a time
	stage.size = split
	_say("%d x %d, one thing out at a time:" % [split.x, split.y], await _measure())
	var env: Environment = medium._env
	var was_msaa := stage.msaa_3d
	stage.msaa_3d = Viewport.MSAA_DISABLED
	_say("  no multisampling (it is %s)" % ["off", "2x", "4x", "8x"][clampi(int(was_msaa), 0, 3)], await _measure())
	stage.msaa_3d = Viewport.MSAA_2X
	_say("  multisampling 2x", await _measure())
	stage.msaa_3d = was_msaa
	if env != null:
		var was := env.ssil_enabled
		env.ssil_enabled = false
		_say("  no bounce light (it is %s)" % ("on" if was else "off"), await _measure())
		env.ssil_enabled = was
		was = env.ssao_enabled
		env.ssao_enabled = false
		_say("  no ambient occlusion (it is %s)" % ("on" if was else "off"), await _measure())
		env.ssao_enabled = was
		was = env.volumetric_fog_enabled
		env.volumetric_fog_enabled = false
		_say("  no volumetric fog (it is %s)" % ("on" if was else "off"), await _measure())
		env.volumetric_fog_enabled = was
		was = env.glow_enabled
		env.glow_enabled = false
		_say("  no glow (it is %s)" % ("on" if was else "off"), await _measure())
		env.glow_enabled = was
		was = env.ssr_enabled
		env.ssr_enabled = false
		_say("  no screen-space reflections (it is %s)" % ("on" if was else "off"), await _measure())
		env.ssr_enabled = was
		var sd := env.sdfgi_enabled
		print("render:   (sdfgi %s, tonemap %d, fog %s)" % ["on" if sd else "off", env.tonemap_mode, "on" if env.fog_enabled else "off"])
	var had: Array = []
	for l in lights:
		had.append((l as Light3D).shadow_enabled)
		(l as Light3D).shadow_enabled = false
	_say("  no shadows at all", await _measure())
	for i in lights.size():
		(lights[i] as Light3D).shadow_enabled = bool(had[i])
	# everything out together: what is left is the bare picture
	stage.msaa_3d = Viewport.MSAA_DISABLED
	var keep := {}
	if env != null:
		for k in ["ssil_enabled", "ssao_enabled", "volumetric_fog_enabled", "glow_enabled", "ssr_enabled"]:
			keep[k] = env.get(k)
			env.set(k, false)
	for l in lights:
		(l as Light3D).shadow_enabled = false
	_say("  all of those out together", await _measure())
	for i in lights.size():
		(lights[i] as Light3D).shadow_enabled = bool(had[i])
	if env != null:
		for k in keep:
			env.set(k, keep[k])
	stage.msaa_3d = was_msaa
	# ...and playing, the work ticked each frame, at that size
	var gpu := 0.0
	var cpu := 0.0
	var script_us := 0
	for k in 60:
		var s := at + float(k) / 60.0
		Spectrum.virtual_clock = s
		Spectrum.current.time = s
		var b := Time.get_ticks_usec()
		medium.advance(Spectrum.current, 1.0 / 60.0, 1.0)
		script_us += Time.get_ticks_usec() - b
		await get_tree().process_frame
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(rid)
	print("render %d x %d, playing: GPU %.2f ms, renderer's CPU %.2f ms, our script %.2f ms a frame" % [split.x, split.y, gpu / 60.0, cpu / 60.0, script_us / 60000.0])
	Spectrum.virtual_clock = -1.0
	print("render: done")
	get_tree().quit(0)
