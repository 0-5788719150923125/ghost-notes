extends Node

## props_card_probe - looks at the Props card ([PropsCard], [EpisodeProps]), the Dex opened from it ([DexWindow]) and a prop in 3D ([PropViewer])
## on a copy of an episode, its props pictured ([PropStudio]): a picture of the card, of the shelf's Kept and Seen tiles, and of the
## first prop opened whole, then turned. For looking, never a gate.
##
##   GHOST_PROBE_GPU=1 tests/run_boot_probe.sh tests/table_show/props_card_probe.gd 300 <episode dir> <scratch dir>
##
## The episode's table and plan are copied into the scratch folder, which holds the library and the pictures too: nothing of the
## author's is written. Without the GPU (no renderer) the card is drawn with no pictures.

var _fails := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		print("props_card_probe: give an episode folder and a scratch folder")
		get_tree().quit(1)
		return
	var src := String(args[0]).trim_suffix("/")
	var out := String(args[1]).trim_suffix("/")
	var show := src.get_base_dir().get_file()
	var seed := int(src.get_file())
	var copy := out.path_join("table").path_join(show).path_join(str(seed))
	DirAccess.make_dir_recursive_absolute(copy)
	for f in ["table.json", "plan.json", "draw.json"]:
		if FileAccess.file_exists(src.path_join(f)):
			DirAccess.copy_absolute(src.path_join(f), copy.path_join(f))
	TableEpisode.root = out.path_join("table")
	Library.root = out.path_join("library")
	Library.discard = func(path: String) -> int: return DirAccess.remove_absolute(path)
	get_window().size = Vector2i(1280, 900)
	var ed := ReadingPanel.new()
	ed.workspace = "table"
	ed._build_panel()
	ed._doc._sync = false
	var card: EpisodeCard = ed._block_cards["table"]
	card.set_process(false)
	card._knobs["show"] = show
	card._knobs["seed"] = seed
	card._open_episode()
	var sec: EpisodeProps = null
	for s in ed.prop_sections:
		if s is EpisodeProps:
			sec = s
	var bg := ColorRect.new()
	bg.color = Color(0.11, 0.11, 0.13)
	bg.size = Vector2(1280, 900)
	add_child(bg)
	var scroll := VBoxContainer.new()
	scroll.position = Vector2(12, 12)
	scroll.custom_minimum_size = Vector2(440, 0)
	add_child(scroll)
	var props := PropsCard.new(func() -> Array: return ed.prop_sections)
	scroll.add_child(props)
	# a few kept, so the shelf has some
	var t: Dictionary = card._episode.read_json("table")
	var names: Array = (t.get("things", []) as Array).map(func(x: Dictionary) -> String: return String(x.get("name", "")))
	for n in names.slice(0, 3):
		sec.keep_prop("thing:" + n)
	sec.set_on("thing:" + String(names.back()), false)
	var t0 := Time.get_ticks_msec()
	var rows := sec.rows()
	while Time.get_ticks_msec() - t0 < 120000 and PropStudio.can_see():
		props.refresh()
		rows = sec.rows()
		if rows.all(func(r: Dictionary) -> bool: return r.get("picture") != null):
			break
		await get_tree().process_frame
	props.refresh(true)
	for i in 6:
		await get_tree().process_frame
	var pictured := rows.filter(func(r: Dictionary) -> bool: return r.get("picture") != null).size()
	print("props_card_probe: %d rows, %d pictured in %.1f s" % [rows.size(), pictured, (Time.get_ticks_msec() - t0) / 1000.0])
	_shot(out.path_join("props_card.png"))
	props.open_shelf(sec)
	var shelf: DexWindow = props._shelf
	for tab in ["kept", "seen"]:
		shelf._tab = "0:" + tab
		shelf._fill()
		var t1 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t1 < 60000 and PropStudio.can_see():
			shelf._show_pictures()
			var missing := 0
			for k in shelf._tiles:
				if not bool((shelf._tiles[k] as Dictionary)["has"]):
					missing += 1
			if missing == 0 or (tab == "seen" and Time.get_ticks_msec() - t1 > 40000):
				break
			await get_tree().process_frame
		for i in 6:
			await get_tree().process_frame
		_shot_window(shelf, out.path_join("props_shelf_%s.png" % tab))
		print("props_card_probe: shelf %s - %d tiles" % [tab, shelf._tiles.size()])
	shelf.hide()
	# the first prop whole, as it opens and turned
	var first := String(names[0])
	props.look_at(sec, "thing:" + first, first)
	var viewer: PropViewer = props._viewer
	var t2 := Time.get_ticks_msec()
	while viewer.held() == null and Time.get_ticks_msec() - t2 < 30000:
		await get_tree().process_frame
	for i in 6:
		await get_tree().process_frame
	_shot_window(viewer, out.path_join("props_viewer.png"))
	viewer.turn_by(Vector2(260, 140))
	for i in 4:
		await get_tree().process_frame
	_shot_window(viewer, out.path_join("props_viewer_turned.png"))
	viewer._close()
	ed.free()
	print("props_card_probe: done (%d failures)" % _fails)
	get_tree().quit(0)


func _shot(path: String) -> void:
	var img := get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png(path)
		print("props_card_probe: wrote ", path)


func _shot_window(w: Window, path: String) -> void:
	var img := w.get_texture().get_image() if w.get_texture() != null else null
	if img != null and not img.is_empty():
		img.save_png(path)
		print("props_card_probe: wrote ", path)
