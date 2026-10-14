extends Node

## storyboard_look_probe - pictures of the storyboard's editor, for looking at (not a gate): the
## notes list, a new note with its "+" open, and a note walking a storyboard with the editor
## docked under its show, a stage entry and one of its spans picked.
##
##   GHOST_PROBE_GPU=1 GHOST_PROBE_MUTE=1 tests/run_boot_probe.sh tests/timeline/storyboard_look_probe.gd 120 --out /some/dir
##
## It needs the real renderer (a readback under `--headless` is null), runs on a virtual display,
## and writes `list.png`, `plus.png`, `editor.png` and `source.png` into `--out`. Its notes are in a
## folder of its own (`NoteStore.root`), and its song is a fixture of silence.

const ROOT := "user://storyboard_look_probe"
const FixtureAudio := preload("res://tests/fixture_audio.gd")

var _out := ""
var _main: Node


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size() - 1:
		if args[i] == "--out":
			_out = args[i + 1]
	if _out.is_empty():
		print("storyboard_look_probe: give it --out <dir>")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	_clean()
	NoteStore.root = ROOT
	NoteStore.create("A chapter", "Words.\n", {"voice": {}, "picture": {"medium": "book"}})
	NoteStore.create("A show of cards", "A brief.\n", {"cards": {}})
	_main = preload("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await _frames(40)
	_main._chrome.set_environment_open(false, false)
	await _frames(10)
	_shot("list")
	# a new note, and what "+" offers it
	_main._list.new_note()
	await _frames(20)
	var panel: NotePanel = _main._note_panel
	panel._panel.plus.show_popup()
	await _frames(10)
	_shot("plus")
	panel._panel.plus.get_popup().hide()
	_main._chrome._home_button.pressed.emit()
	await _frames(12)
	# a note walking a storyboard, its editor open on a stage entry
	var song: String = FixtureAudio.silence(20.0)
	var note := NoteStore.create("The point", "Words.\n", {"song": {"path": song},
		"picture": {"medium": "full"}, "scenes": Storyboard.own_block(Storyboard.read_raw("default")["data"])})
	_main._list._open(note)
	await _frames(30)
	panel = _main._note_panel
	var card: StoryboardCard = panel._story
	card.open_editor()
	await _frames(6)
	var ed := card.editor()
	ed._pick(1)
	ed._sub = "span"
	ed._sub_i = 0
	ed._refresh()
	Spectrum.transport_play()
	await get_tree().create_timer(1.5).timeout
	Spectrum.transport_pause()
	await _frames(6)
	_shot("editor")
	ed.toggle_source()
	await _frames(6)
	_shot("source")
	_clean()
	get_tree().quit(0)


func _shot(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	if img == null:
		print("storyboard_look_probe: no picture (this needs GHOST_PROBE_GPU=1)")
		return
	var path := _out.path_join(name + ".png")
	img.save_png(path)
	print("storyboard_look_probe: %s  %dx%d" % [path, img.get_width(), img.get_height()])


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _clean() -> void:
	var abs := ProjectSettings.globalize_path(ROOT)
	if DirAccess.dir_exists_absolute(abs):
		for f in DirAccess.get_files_at(abs):
			DirAccess.remove_absolute(abs.path_join(f))
		DirAccess.remove_absolute(abs)
