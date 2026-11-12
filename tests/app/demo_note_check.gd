extends Node

## demo_note_check - THE DEMO NOTE IS THE README'S PRISM, AND ITS STORYBOARD IS ITS OWN TO EDIT ([method Showcase.make_demo_note]).
##
##   tests/run_boot_probe.sh tests/app/demo_note_check.gd 60
##
## On a notes folder and a song of its own under user:// (never the author's): the note is made with the recording's title,
## its song written and its medium full frame, and its `scenes:` block is the note's OWN storyboard (what the Timeline edits),
## loading whole with every entry of storyboards/showcase.yaml. The control is the recording's own block, which names the
## file: it must not read as the note's own - else "editable" would prove nothing.

const ROOT := "user://demo_note_check"

var _fails: Array = []


func _ready() -> void:
	var root := ProjectSettings.globalize_path(ROOT)
	_clear(root)
	NoteStore.root = root.path_join("notes")
	DirAccess.make_dir_recursive_absolute(NoteStore.root)
	var song := ROOT.path_join("song.wav")
	var path := Showcase.make_demo_note(song)
	_ok(not path.is_empty() and FileAccess.file_exists(path), "the demo note was made (%s)" % path)
	_ok(NoteStore.title_of(path) == Showcase.TITLE, "it is titled \"%s\"" % Showcase.TITLE)
	_ok(FileAccess.get_size(ProjectSettings.globalize_path(song)) > 1000, "its song was written")
	var blocks := NoteStore.blocks_of(path) if not path.is_empty() else {}
	_ok(String((blocks.get("medium", {}) as Dictionary).get("format", "")) == "full", "its medium is full frame")
	var own := Storyboard.of_block(blocks.get("scenes"))
	_ok(String(own["kind"]) == "own", "its storyboard is the note's own (kind %s)" % String(own["kind"]))
	var shipped: Dictionary = Storyboard.read_raw(Showcase.STORYBOARD)["data"]
	var loaded := Storyboard.from_data(own["data"], Storyboard.IN_NOTE, "storyboard")
	_ok(bool(loaded.ok), "it loads whole")
	_ok(((own["data"] as Dictionary).get("sequence", []) as Array).size() == (shipped.get("sequence", []) as Array).size()
		and not (shipped.get("sequence", []) as Array).is_empty(), "it has every entry of the shipped storyboard")
	# THE CONTROL: the recording's block names the file, and is not the note's own
	_ok(String(Storyboard.of_block({"storyboard": Showcase.STORYBOARD})["kind"]) != "own", "control: a block naming the file is not the note's own")
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
