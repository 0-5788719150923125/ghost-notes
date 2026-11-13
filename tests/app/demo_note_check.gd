extends Node

## demo_note_check - the demo note is the README's prism, and its storyboard is its own to edit ([method
## Showcase.make_demo_note]).
##
##   tests/run_boot_probe.sh tests/app/demo_note_check.gd 60
##
## On a notes folder, note folders and a song of its own under user://: the note is made with the
## recording's title, its song written as long as the storyboard and its medium full frame, and its own
## storyboard is kept in its folder ([NoteStoryboard]), loading whole with every entry of
## data/showcase.json; nothing of it is written into the note's file. Control: another note's folder keeps
## no storyboard.

const ROOT := "user://demo_note_check"

var _fails: Array = []


func _ready() -> void:
	var root := ProjectSettings.globalize_path(ROOT)
	_clear(root)
	NoteStore.root = root.path_join("notes")
	NoteUpload.root = root.path_join("readings")
	DirAccess.make_dir_recursive_absolute(NoteStore.root)
	var song := ROOT.path_join("song.wav")
	var path := Showcase.make_demo_note(song)
	_ok(not path.is_empty() and FileAccess.file_exists(path), "the demo note was made (%s)" % path)
	_ok(NoteStore.title_of(path) == Showcase.TITLE, "it is titled \"%s\"" % Showcase.TITLE)
	var bytes := FileAccess.get_size(ProjectSettings.globalize_path(song))
	_ok(bytes == 44 + int(Showcase.song() * ShowcaseRecorder.RATE) * 2 and Showcase.song() > 0.0,
		"its song was written, as long as the storyboard (%.1f s, %d bytes)" % [Showcase.song(), bytes])
	var blocks := NoteStore.blocks_of(path) if not path.is_empty() else {}
	_ok(String((blocks.get("medium", {}) as Dictionary).get("format", "")) == "full", "its medium is full frame")
	_ok(not blocks.has("scenes"), "nothing of its storyboard is written into the note's file")
	var own := NoteStoryboard.read(NoteUpload.folder_of(path))
	var shipped: Dictionary = Storyboard.read_raw(Showcase.STORYBOARD)["data"]
	var loaded := Storyboard.from_data(own["data"], Storyboard.IN_NOTE, "storyboard")
	_ok(bool(own["ok"]) and bool(loaded.ok), "its storyboard is kept in its folder, and loads whole")
	_ok(DataPath.same(own["data"], Storyboard.own_block(shipped)) and not (shipped.get("sequence", []) as Array).is_empty(),
		"it is the shipped storyboard, every entry (%d)" % (shipped.get("sequence", []) as Array).size())
	# The control: another note's folder keeps none
	var other := NoteStore.create("another", "", {})
	_ok(((NoteStoryboard.read(NoteUpload.folder_of(other))["data"] as Dictionary)["sequence"] as Array).is_empty(),
		"control: another note's folder keeps no storyboard")
	NoteUpload.root = NoteUpload.ROOT
	_clear(root)
	if _fails.is_empty():
		print("demo_note_check: ALL OK")
		get_tree().quit(0)
		return
	print("demo_note_check: %d FAILURE(S)" % _fails.size())
	get_tree().quit(1)


func _clear(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for d in DirAccess.get_directories_at(dir):
		_clear(dir.path_join(d))
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)


func _ok(cond: bool, msg: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + msg)
	if not cond:
		_fails.append(msg)
