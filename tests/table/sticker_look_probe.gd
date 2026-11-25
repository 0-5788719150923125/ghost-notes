extends SceneTree

## sticker_look_probe - a sticker book's pages seen ([StickerBook], next/sticker_book.md): its pages laid one after another, every
## `--every` seconds, and frames written at the moments asked - a page held, the glide between two on one set, a wipe to another.
## A probe, for looking: it needs a real renderer.
##
##     tests/run_quiet.sh -- tests/table/sticker_look_probe.gd --dir <folder with game.json and its pictures> --out <dir>
##         [--every 3] [--times 0.5,3.2,6.1] [--portrait]
##
## The folder is an episode's (`set_K.png`, `model_K.png`, `pose_K.png`, `thing_K.png`, `game.json`) or one made by hand like it.

var _args := {}


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var argv := OS.get_cmdline_user_args() + OS.get_cmdline_args()
	for i in argv.size():
		if String(argv[i]).begins_with("--") and i + 1 < argv.size() and not String(argv[i + 1]).begins_with("--"):
			_args[String(argv[i]).trim_prefix("--")] = String(argv[i + 1])
		elif String(argv[i]) == "--portrait":
			_args["portrait"] = "1"
	var dir := String(_args.get("dir", ""))
	var out := String(_args.get("out", ""))
	var game: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("game.json")))
	if not (game is Dictionary) or out.is_empty():
		printerr("sticker_look_probe: --dir <folder with game.json> --out <dir>")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	var every := float(_args.get("every", "3"))
	var book := StickerBook.new(game, dir, 9.0 / 16.0 if _args.has("portrait") else 16.0 / 9.0)
	book.build()
	root.add_child(book.viewport)
	book.show(true)
	var pages: int = (game.get("pages", []) as Array).size()
	var times: Array = []
	if _args.has("times"):
		for v in String(_args["times"]).split(","):
			times.append(float(v))
	else:
		for i in pages:
			times.append_array([i * every + 0.05, i * every + 0.25, i * every + every - 0.1])
	for t in times:
		var i := clampi(int(floor(float(t) / every)), 0, pages - 1)
		book.pose_at(float(t), i, i * every, i - 1, (i - 1) * every)
		await process_frame
		await process_frame
		var img := book.viewport.get_texture().get_image()
		var path := out.path_join("t%06.2f_p%d.png" % [float(t), i + 1])
		if img != null:
			img.save_png(path)
			print("sticker_look_probe: %s" % path)
	book.viewport.queue_free()
	await process_frame
	quit(0)
