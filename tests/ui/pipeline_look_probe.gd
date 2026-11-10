extends Node

## pipeline_look_probe - the deck and the Pipeline card as the app shows them, as a picture: a note OPENED THE WAY A CLICK OPENS IT,
## on main (a panel built by hand is out of the tree and has no ×, and looked right while the app's did not; next/panel_deck.md), a
## table show's episode part made, with a card's painting running, a failed reading and the YouTube section under it
## (next/pipeline.md). In roots of its own; the author's notes are only listed behind it. For looking; nothing is held.
##
##   GHOST_PROBE_GPU=1 tests/run_boot_probe.sh tests/ui/pipeline_look_probe.gd 60 [--out=<dir>]
##
## Writes `top.png` (scrolled to the top, its piles), `middle.png` (a pile at each end), `fanned.png` (the pointer on a bar in a
## pile) and `small.png` (a 720-tall window) under the out folder, and the panel's numbers to the log.

const ROOT := "user://pipeline_look_probe"

var _ed: ReadingPanel
var _pipe: PipelineCard
var _ep: TableEpisode
var _out := "dist/pipeline_look"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--out="):
			_out = String(a).trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(_out)
	var was := TableEpisode.root
	var was_notes := NoteStore.root
	TableEpisode.root = ROOT
	NoteStore.root = ROOT + "_notes"
	get_tree().root.size = Vector2i(1280, 1000)
	var note := NoteStore.create("The Quiet Crucible", "Someone brews a thing, slowly.\n", {"table": {"show": "look", "seed": 7},
		"voice": {"engine": "piper"}, "look": {"look": ""}, "bookends": {"intro": 8.0}, "youtube": {"write_tags": true}})
	var main_node: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main_node)
	for i in 30:
		await get_tree().process_frame
	main_node._list._open(note)
	for i in 30:
		await get_tree().process_frame
	_ed = main_node._generative
	var show: EpisodeCard = _ed._block_cards["table"]
	_pipe = _ed.pipeline()
	show._knobs["show"] = "look"
	show._knobs["seed"] = 7
	show._open_episode()
	_ep = show._episode
	_ep.write_json("plan", {"episode_title": "Lighting a New Furnace", "spread": {"positions": [{"name": "What Was Lit"}, {"name": "What Burns Now"},
		{"name": "What Is Left"}, {"name": "What Comes After"}]}})
	_ep.write_json("draw", {"cards": [{"name": "The Tower", "key": "tower"}, {"name": "The Moon", "key": "moon", "reversed": true},
		{"name": "The Star", "key": "star"}, {"name": "Death", "key": "death"}], "deck_n": 78})
	for st in ["design:1", "design:2", "design:3", "design:4", "image:back", "image:surface", "image:backdrop", "table", "image:card:1", "check:1", "say:intro", "say:1"]:
		_touch(st)
	# a painting under way and a reading that failed, as the card shows them
	show._producer._jobs["image:card:2"] = "text-look-probe"
	show._producer._errors["say:2"] = "the writer stopped: its quota is spent"
	for i in 12:
		await get_tree().process_frame
	_pipe.refresh()
	await _shot("top")
	var bar: ScrollBar = _ed._panel._scroll.get_v_scroll_bar()
	bar.value = _pipe.card.position.y * 0.45
	await _shot("middle")
	bar.value = 0.0
	await _shot("fanned", _ed._panel.cards()[_ed._panel.cards().size() - 3])
	get_tree().root.size = Vector2i(1280, 720)
	await _shot("small")
	print("pipeline_look_probe: rows %s" % str(_pipe.names()))
	print("pipeline_look_probe: panel %d wide, %d tall; list %d; peek %d; Generate on its bar %s" % [int(_ed._panel.size.x), int(_ed._panel.size.y),
		int(_pipe._list.get_combined_minimum_size().y), int(_ed._panel._deck.peek()), _pipe.card.head.is_ancestor_of(_pipe._generate)])
	show._producer._jobs.clear()
	TableEpisode.root = was
	NoteStore.root = was_notes
	_rmrf(ProjectSettings.globalize_path(ROOT))
	_rmrf(ProjectSettings.globalize_path(ROOT + "_notes"))
	print("pipeline_look_probe: PASS")
	get_tree().quit(0)


func _touch(step: String) -> void:
	var path := _ep.file_of(step)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{}" if path.ends_with(".json") else "Some words said over this card.")
	f.close()


func _shot(name: String, point_at: Card = null) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = point_at.head.global_position + Vector2(20.0, 3.0) if point_at != null else Vector2(1000.0, 600.0)
	ev.global_position = ev.position
	get_viewport().push_input(ev, true)
	for i in 24:
		await get_tree().process_frame
	_pipe.refresh()
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img != null:
		img.save_png(_out.path_join(name + ".png"))
		print("pipeline_look_probe: wrote %s" % _out.path_join(name + ".png"))


func _rmrf(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	for d in DirAccess.get_directories_at(path):
		_rmrf(path.path_join(d))
	DirAccess.remove_absolute(path)
