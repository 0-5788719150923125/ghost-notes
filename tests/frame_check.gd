extends Node

## frame_check - two frames, landscape and portrait (next/notes.md step 10): the exporter, the stage
## and the subtitles, measured.
##
##   tests/run_boot_probe.sh tests/frame_check.gd 120
##
## THE EXPORTER: a landscape override written byte for byte as it always was; a portrait one shapes
## its window like the frame (270x480) and says `aspect="keep"` - the trap was a portrait render in a
## landscape window, widened by the project's `expand` aspect; every preset's render size even
## (yuv420p refuses odd); the portrait presets the landscape ones turned, with no 4K; the thumbnail
## cut at the frame's shape.
##
## THE FRAME: portrait only where the medium has one (full frame); a medium without one plays
## landscape whatever was asked.
##
## THE STAGE IS THE FRAME: through the real main scene, a song session's stage is the frame's shape
## (16:9, or 9:16 in portrait), as large as the window holds it, centered, black beside it; the filters
## are sized to the stage; the subtitles told the frame. Measured against the window as it is - a 16:9
## window holds a landscape stage whole, and headless Godot's window is 64x64, so its view is square
## and the landscape stage sits between bars above and below.
##
## THE SUBTITLES' SAFE AREA: a portrait frame's last line sits above its bottom 35% and its lines
## keep off the right 17.8% (Google's safe zones for 1080x1920), type sized off the short side; a
## landscape frame lays out exactly as before (92% of the width, 70 px up at 1080).

const SONG_DIR := "user://frame_check"
var _fails: Array = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_exporter()
	_frames()
	_subtitles()
	await _stage()
	if _fails.is_empty():
		print("frame_check: ALL OK")
		get_tree().quit(0)
		return
	print("frame_check: %d FAILURE(S)" % _fails.size())
	for f in _fails:
		print("   ", f)
	get_tree().quit(1)


func _ok(cond: bool, msg: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + msg)
	if not cond:
		_fails.append(msg)


func _exporter() -> void:
	print("-- the exporter")
	var old := "[display]\n\nwindow/size/viewport_width=%d\nwindow/size/viewport_height=%d\nwindow/size/window_width_override=480\nwindow/size/window_height_override=270\nwindow/stretch/mode=\"viewport\"\n" % [2880, 1620] \
		+ "\n[editor]\n\nmovie_writer/video_quality=1.0\n"
	_ok(Exporter.override_text(2880, 1620) == old, "a landscape override is written byte for byte as before")
	var p := Exporter.override_text(1620, 2880)
	_ok(p.contains("viewport_width=1620") and p.contains("viewport_height=2880"), "a portrait override records the portrait size")
	_ok(p.contains("window_width_override=270") and p.contains("window_height_override=480"),
		"...in a window shaped like the frame")
	_ok(p.contains("window/stretch/aspect=\"keep\""), "...and keeps its aspect")
	for list in [Exporter.QUALITIES, Exporter.PORTRAIT_QUALITIES]:
		for q in list:
			var w := int(int(q.w) * float(q.get("ss", 1.0)))
			var h := int(int(q.h) * float(q.get("ss", 1.0)))
			_ok(w % 2 == 0 and h % 2 == 0, "%s renders at even sizes (%dx%d)" % [q.tag, w, h])
	var turned := Exporter.qualities_for("portrait")
	_ok(turned.size() == 2 and not turned.any(func(q: Dictionary) -> bool: return int(q.h) > 1920),
		"the portrait presets stop at 1080x1920 - no 4K portrait")
	for i in turned.size():
		var land: Dictionary = Exporter.QUALITIES[i]
		_ok(int(turned[i].w) == int(land.h) and int(turned[i].h) == int(land.w) and int(turned[i].fps) == int(land.fps),
			"%s is %s turned" % [turned[i].tag, land.tag])
	_ok(Exporter.qualities_for("landscape") == Exporter.QUALITIES, "a landscape show keeps its presets")
	_ok(" ".join(Exporter.thumbnail_args("v.mp4", "t.jpg", 2.0, true)).contains("scale=720:1280"),
		"a portrait thumbnail is cut at the frame's shape")
	_ok(" ".join(Exporter.thumbnail_args("v.mp4", "t.jpg", 2.0)).contains("scale=1280:720"), "a landscape one as before")


func _frames() -> void:
	print("-- the frame")
	var keep_m := Director.medium
	var keep_f := Director.frame
	Director.set_medium("full")
	Director.set_frame("portrait")
	_ok(Director.resolved_frame() == "portrait", "full frame shows in portrait")
	Director.set_medium("comic")
	_ok(Director.resolved_frame() == "landscape", "the comic has no portrait frame: landscape whatever was asked")
	_ok(Director.frame == "portrait", "...and the asking is kept for a medium that has one")
	for key in Medium.REGISTRY:
		_ok(Medium.supports(String(key), "landscape"), "%s shows in landscape" % key)
	Director.set_medium(keep_m)
	Director.set_frame(keep_f)


func _subtitles() -> void:
	print("-- the subtitles' safe area")
	var land := Subtitles.text_area(Rect2(0, 0, 1920, 1080))
	_ok(is_equal_approx(float(land["base_y"]), 1010.0) and is_equal_approx(float(land["max_w"]), 1920.0 * 0.92)
		and is_equal_approx(float(land["cx"]), 960.0) and is_equal_approx(float(land["k"]), 1.0),
		"a landscape frame lays out as before")
	var f := Rect2(656, 0, 608, 1080)
	var port := Subtitles.text_area(f)
	_ok(float(port["base_y"]) <= f.position.y + f.size.y * 0.65 + 0.5, "the last line sits above the bottom 35%")
	var area: Rect2 = port["area"]
	_ok(area.end.x <= f.end.x - f.size.x * 0.178 + 0.5 and area.position.y >= f.position.y + f.size.y * 0.15 - 0.5,
		"lines keep off the right 17.8% and the top 15%")
	_ok(is_equal_approx(float(port["k"]), 608.0 / 1080.0), "type sized off the frame's short side")
	var full := Subtitles.text_area(Rect2(0, 0, 1080, 1920))
	_ok(is_equal_approx(float(full["k"]), 1.0), "a 1080x1920 frame sets type as a 1080-tall landscape one does")


func _stage() -> void:
	print("-- the stage is the frame")
	var keep_m := Director.medium
	var keep_f := Director.frame
	Director.set_medium("full")
	Director.set_frame("landscape")
	var song := _captioned_song()
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	for _i in 10:
		await get_tree().process_frame
	main.start_template("auto", song)
	for _i in 10:
		await get_tree().process_frame
	var vis := get_viewport().get_visible_rect().size
	var sv: Control = main._stage_view
	var land := _fit(vis, Vector2(16, 9))
	_ok(sv != null and _near(sv.get_rect(), land),
		"landscape: the stage is 16:9, as large as the window holds it, centered (%s in %s, want %s)"
			% [sv.get_rect() if sv != null else "none", vis, land])
	if sv == null:
		return
	var subs: Node = main._subtitles
	_ok(subs != null and is_instance_valid(subs) and subs.frame_rect == sv.get_rect(),
		"the subtitles come up told the frame (%s)" % (subs.frame_rect if subs != null else "no subtitles"))
	Director.set_frame("portrait")
	await get_tree().process_frame
	var port := _fit(vis, Vector2(9, 16))
	_ok(_near(sv.get_rect(), port), "portrait: the stage is 9:16, centered, black beside it (%s, want %s)" % [sv.get_rect(), port])
	_ok(Vector2(main._stage.size).is_equal_approx(sv.size), "the stage renders at the frame's size, not the window's")
	_ok(subs != null and is_instance_valid(subs) and subs.frame_rect == sv.get_rect(),
		"...and told again when it turns")
	Director.set_medium("tablet")
	await get_tree().process_frame
	_ok(_near(sv.get_rect(), land), "a medium without a portrait frame refits the stage to landscape (%s)" % sv.get_rect())
	main._end_session(false)
	Director.set_medium(keep_m)
	Director.set_frame(keep_f)
	main.queue_free()
	for _i in 5:
		await get_tree().process_frame
	var dir := ProjectSettings.globalize_path(SONG_DIR)
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)


## The fixture's silence, copied into a folder of the gate's own with a captions file beside it - the
## fixture is shared, and a sidecar next to it would caption every other gate's song.
func _captioned_song() -> String:
	var dir := ProjectSettings.globalize_path(SONG_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	var song := dir.path_join("song.wav")
	DirAccess.copy_absolute(preload("res://tests/fixture_audio.gd").silence(6.0), song)
	var side := FileAccess.open(dir.path_join("song.json"), FileAccess.WRITE)
	side.store_string(JSON.stringify({"words": [
		{"text": "Two", "t0": 0.2, "t1": 0.6, "sentence": 0, "emph": 0},
		{"text": "frames.", "t0": 0.6, "t1": 1.2, "sentence": 0, "emph": 0}]}))
	side.close()
	return song


## The largest rect of [param shape]'s proportions that [param vis] holds, centered - worked out here,
## not asked of main, so the gate does not grade main's sums with main's sums.
static func _fit(vis: Vector2, shape: Vector2) -> Rect2:
	var wide := vis.x / vis.y > shape.x / shape.y      # the window is wider than the frame: bars beside it
	var size := Vector2(vis.y * shape.x / shape.y, vis.y) if wide else Vector2(vis.x, vis.x * shape.y / shape.x)
	return Rect2((vis - size) * 0.5, size)


static func _near(a: Rect2, b: Rect2) -> bool:
	return a.position.distance_to(b.position) <= 1.0 and a.size.distance_to(b.size) <= 1.0
