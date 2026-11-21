extends Node

## cartoon_app_probe - a cartoon note as the app opens it (next/cartoon.md): opened on main the way a click opens it, its Cartoon card
## and Pipeline rows built in the panel, its show timed by its silent track (as long as its storyboard), and the window photographed a
## few seconds after Play. In roots of its own (notes, their folders); the puppets and sets are read from the library, never written.
## For looking; nothing is held.
##
##   GHOST_PROBE_GPU=1 tests/run_boot_probe.sh tests/cartoon/cartoon_app_probe.gd 120 --board=<storyboard.json> [--out=<dir>] [--at=S]
##       [--seek=S] [--after=S]
##
## `--board` is a cartoon's storyboard (a note's `storyboard.json`), copied into the probe's note; its cast and sets must be on the
## library's shelves. Writes `app.png` under the out folder, and what came up to the log; `--seek` then moves the playhead there, as a
## scrub does, and writes `seek.png`; `--after` lets it play that many seconds more (past its end, a loop's seam), printing each
## entry the show comes to, and writes `after.png`.

const ROOT := "user://cartoon_app_probe"

var _out := "user://cartoon_app_probe/look"
var _board := ""
var _at := 5.0
var _seek := -1.0
var _after := 0.0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--out="):
			_out = s.trim_prefix("--out=")
		elif s.begins_with("--board="):
			_board = s.trim_prefix("--board=")
		elif s.begins_with("--at="):
			_at = float(s.trim_prefix("--at="))
		elif s.begins_with("--seek="):
			_seek = float(s.trim_prefix("--seek="))
		elif s.begins_with("--after="):
			_after = float(s.trim_prefix("--after="))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	NoteStore.root = ROOT + "/notes"
	NoteUpload.root = ROOT + "/folders"
	get_tree().root.size = Vector2i(1600, 900)
	var board: Variant = JSON.parse_string(FileAccess.get_file_as_string(_board))
	var cast: Array = []
	var sets := {}
	for e in (board as Dictionary).get("sequence", []) if board is Dictionary else []:
		for c in (e as Dictionary).get("cast", []):
			if String((c as Dictionary).get("kind", "")) == "puppet" and not cast.any(func(x: Dictionary) -> bool: return x["name"] == String(c["rig"])):
				cast.append({"name": String(c["rig"]), "picture": ""})
			elif String((c as Dictionary).get("kind", "")) == "backdrop":
				sets[String(c["picture"])] = true
	var set_rows: Array = []
	for s in sets:
		set_rows.append({"name": s, "place": s})
	var note := NoteStore.create("Cartoon probe", "A cartoon, opened as the app opens it.\n",
		{"cartoon": {"cast": cast, "sets": set_rows, "seconds": 30, "silent": true}, "medium": {"format": "full", "frame": "standard"}})
	var folder := NoteUpload.folder_of(note)
	DirAccess.make_dir_recursive_absolute(folder)
	print("cartoon_app_probe: storyboard copied: %s" % ("ok" if NoteStoryboard.write(folder, board).is_empty() else "failed"))
	var main_node: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main_node)
	for i in 30:
		await get_tree().process_frame
	main_node._list._open(note)
	for i in 60:
		await get_tree().process_frame
	var panel: Node = main_node.get("_note_panel")
	var cards: Dictionary = panel.get("_cards") if panel != null else {}
	print("cartoon_app_probe: cards %s" % str(cards.keys()))
	print("cartoon_app_probe: audio %s, %.1f s; Director attached %s" % [Spectrum.has_audio(), Spectrum.song_length(), Director.is_attached()])
	var pipe: Object = panel.get("_pipeline") if panel != null else null
	if pipe != null and pipe.has_method("names"):
		print("cartoon_app_probe: pipeline rows %s" % str(pipe.call("names")))
	Spectrum.transport_play()
	var t0 := Time.get_ticks_msec()
	while Spectrum.current.time < _at and Time.get_ticks_msec() - t0 < 40000:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(_out).path_join("app.png"))
	print("cartoon_app_probe: show time %.1f s, wrote %s" % [Spectrum.current.time, ProjectSettings.globalize_path(_out).path_join("app.png")])
	# a scrub: the playhead moved, and the written show goes where it is told to be
	if _seek >= 0.0:
		var before := int(Director.get("_manual_i"))
		Spectrum.seek(_seek)
		for i in 20:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(_out).path_join("seek.png"))
		print("cartoon_app_probe: sought to %.1f s: show time %.1f s, entry %d -> %d" % [_seek, Spectrum.current.time, before, int(Director.get("_manual_i"))])
	# played on: each entry it comes to, at the show time it comes
	if _after > 0.0:
		var was := int(Director.get("_manual_i"))
		var t1 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t1 < int(_after * 1000.0):
			await get_tree().process_frame
			var now := int(Director.get("_manual_i"))
			if now != was:
				print("cartoon_app_probe: entry %d -> %d at show time %.2f s" % [was, now, Spectrum.current.time])
				was = now
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(_out).path_join("after.png"))
		print("cartoon_app_probe: %.1f s on: show time %.1f s, entry %d" % [_after, Spectrum.current.time, int(Director.get("_manual_i"))])
	Spectrum.transport_stop()
	for i in 10:
		await get_tree().process_frame
	get_tree().quit(0)
