extends Node

## Not a gate (asserts nothing): plays a cartoon's storyboard silent through [NestedShow] - as a desk's screen plays a note - and
## writes its frames at the times asked, and a contact sheet of them, so the puppets, their verbs and the set can be judged by
## looking (next/cartoon.md).
##
##   GHOST_PROBE_GPU=1 tests/run_boot_probe.sh tests/stage/cartoon_look_probe.gd 300 \
##       --storyboard /path/board.yaml --out /scratch/look --times 0.5,1,2,3 [--title NAME] [--sheet 4]
##
## `--storyboard` is a file as `--storyboard` plays one (YAML or JSON); `--title` seeds it as a note of that title would be; `--sheet 0`
## writes no contact sheet (a whole run's frames, for a film).
## A probe is read-only: rigs named by path are read where they lie, and nothing is written but the frames.

const DT := 1.0 / 30.0

var _board := ""
var _out := "user://cartoon_look"
var _title := "cartoon"
var _times: Array = [1.0]
var _cols := 4


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size() - 1:
		match args[i]:
			"--storyboard": _board = args[i + 1]
			"--out": _out = args[i + 1]
			"--title": _title = args[i + 1]
			"--sheet": _cols = maxi(0, int(args[i + 1]))
			"--times":
				_times = []
				for s in String(args[i + 1]).split(","):
					_times.append(float(s))
	var sb := Storyboard.load_file(_board)
	if not bool(sb.get("ok", false)):
		print("cartoon_look_probe: %s" % sb.get("error", "no storyboard"))
		get_tree().quit(1)
		return
	var note := {"title": _title, "song": "", "storyboard": sb, "medium": "full", "secs": Storyboard.silent_length(sb)}
	var t0 := Time.get_ticks_msec()
	note = NestedShow.prepared(note)
	print("cartoon_look_probe: %d entries, %.1f s, prepared in %d ms" % [(sb["sequence"] as Array).size(), float(note["secs"]),
		Time.get_ticks_msec() - t0])
	var show := NestedShow.new(note)
	add_child(show)
	var t := 0.0
	var shots: Array = []
	var frame_ms := 0.0
	var frames := 0
	for target: float in _times:
		while t < target - 1e-4:
			var a := Time.get_ticks_usec()
			show.play_at(t, DT, true, false, false)
			frame_ms += float(Time.get_ticks_usec() - a) / 1000.0
			frames += 1
			t += DT
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var tex := show.texture()
		if tex == null:
			continue
		var img := tex.get_image()
		var p := "%s_t%05.2f.png" % [_out, target]
		img.save_png(p)
		shots.append(img)
		print("    %s" % p)
	print("cartoon_look_probe: %.2f ms a step on the app's thread" % (frame_ms / maxf(1.0, float(frames))))
	if shots.size() > 1 and _cols > 0:
		_sheet(shots)
	show.stop()
	show.queue_free()
	for _i in 6:
		await get_tree().process_frame
	get_tree().quit(0)


## The frames in a grid, a quarter size each, labelled by time.
func _sheet(shots: Array) -> void:
	var w := (shots[0] as Image).get_width() / 2
	var h := (shots[0] as Image).get_height() / 2
	var rows := ceili(float(shots.size()) / float(_cols))
	var sheet := Image.create(w * _cols, h * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.BLACK)
	for i in shots.size():
		var im: Image = (shots[i] as Image).duplicate()
		im.convert(Image.FORMAT_RGBA8)
		im.resize(w, h, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(im, Rect2i(0, 0, w, h), Vector2i((i % _cols) * w, (i / _cols) * h))
	sheet.save_png("%s_sheet.png" % _out)
	print("    %s_sheet.png" % _out)
