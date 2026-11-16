extends Node

## Stage clicks select table objects only while the episode's timeline is already open.
## A click outside the voice lab during playback never opens or reopens it; the transport's timeline button does.
## A named pickable medium supplies the hit without a renderer, and every episode file belongs to this gate.
##
##   tests/run_boot_probe.sh tests/table_show/episode_click_check.gd 120

const ROOT := "user://episode_click_check"
var _fails := 0


class Pickable extends Medium:
	var hit := {"thing": "cup", "part": "bowl"}
	var picks := 0

	func pick(_at: Vector2) -> Dictionary:
		picks += 1
		return hit


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var was_root := TableEpisode.root
	var was_library := Library.root
	TableEpisode.root = ROOT
	Library.root = ROOT.path_join("library")
	_clean(ProjectSettings.globalize_path(ROOT))
	var ed := ReadingPanel.new()
	ed.workspace = "table"
	ed._build_panel()
	ed._doc._sync = false
	ed.remove_child(ed._panel)
	add_child(ed._panel)
	var show: EpisodeCard = ed._block_cards["table"]
	show.set_process(false)
	show._knobs["show"] = "click"
	show._knobs["seed"] = 1
	show._open_episode()
	var ep := show._episode
	ep.write_json("plan", {"episode_title": "Click", "staging": {"source": "none"}, "spread": {"positions": [{"name": "One"}]}})
	ep.write_json("table", {"things": [{"name": "cup", "parts": [{"name": "bowl", "shape": "lathe", "material": "clay"}]}],
		"materials": {"clay": {"kind": "clay"}}})
	for step in ["say:intro", "say:1", "say:close"]:
		ep.write_text(step, "A few words.")
	TableProducer.new(ep, {})._make_script()
	var medium := Pickable.new()
	add_child(medium)
	var was_medium := Director._medium
	var was_frame := Director.frame_rect
	Director._medium = medium
	Director.frame_rect = Rect2(0, 0, 640, 360)
	Spectrum.conduct(self, {"playing": func() -> bool: return true})
	var bar := Transport.new()
	add_child(bar)
	await get_tree().process_frame
	_ok(show.is_visible_in_tree() and Spectrum.transport_playing() and Director.pick(Vector2(100, 100)).get("thing") == "cup",
		"the playing episode has a visible card and a pickable object at the click")
	var lab: ReaderBrowser = ed._cast._lab
	_ok(lab != null, "the reading has its real voice lab")
	if lab != null:
		lab._popup.popup()
		await get_tree().process_frame
		_ok(lab.is_open(), "the voice lab is open")
		lab._popup.hide()
	show._unhandled_input(_click())
	_ok(show._dock == null, "an outside click escaping the voice lab during playback does not open the timeline")
	show.close_dock()
	var before := medium.picks
	show._unhandled_input(_click())
	_ok(show._dock == null and medium.picks == before, "with the timeline closed, stage clicks do not start object inspection")
	show.close_dock()
	_ok(not show.pick_thing("cup", "bowl").is_empty() and show._dock == null,
		"a direct object-selection request also leaves a closed timeline closed")
	show.close_dock()
	var offer := Transport.offered()
	_ok(not offer.is_empty() and (offer["who"] as WeakRef).get_ref() == show, "the timeline button is offered by the episode")
	bar._tl.pressed.emit()
	await get_tree().process_frame
	var dock := show._dock
	_ok(dock != null, "the control: pressing the timeline button opens the editor")
	show._unhandled_input(_click())
	_ok(show._dock == dock and dock.inspected.get("thing") == "cup" and dock.inspected.get("part") == "bowl",
		"with the editor open, a stage click selects the object in its existing inspector")
	bar._tl.pressed.emit()
	await get_tree().process_frame
	show._unhandled_input(_click())
	_ok(show._dock == null, "after the button closes the editor, a stage click cannot reopen it")
	show.close_dock()
	await get_tree().process_frame
	await get_tree().process_frame
	Spectrum.release_conductor(self)
	Director._medium = was_medium
	Director.frame_rect = was_frame
	bar.free()
	medium.free()
	ed._panel.free()
	ed.free()
	TableEpisode.root = was_root
	Library.root = was_library
	_clean(ProjectSettings.globalize_path(ROOT))
	print("episode_click_check: %s" % ("ALL OK" if _fails == 0 else "%d FAILED" % _fails))
	get_tree().quit(0 if _fails == 0 else 1)


func _click() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = Vector2(100, 100)
	return event


func _ok(condition: bool, what: String) -> void:
	print(("  ok    " if condition else "  FAIL  ") + what)
	if not condition:
		_fails += 1


func _clean(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for entry in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(entry))
	for entry in DirAccess.get_directories_at(path):
		_clean(path.path_join(entry))
	DirAccess.remove_absolute(path)
