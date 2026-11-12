extends SceneTree

## note_history_check - A NOTE'S EVERY SAVED STATE, TO GO BACK TO ([NoteHistory]; the Body card's Restore).
##
##   godot --headless --path . --script res://tests/notes/note_history_check.gd
##
## In a folder of its own: a note's text kept with its moment; a setting changed said by its place and its two values, the words by
## how many more; newest first, each read back as it was; the newest kept, the oldest gone past the bound. THE CONTROL: the same
## text written again is kept once.

const ROOT := "user://note_history_check"

var _fails := 0


func _initialize() -> void:
	var dir := ProjectSettings.globalize_path(ROOT)
	_rmrf(dir)
	var t1 := FrontMatter.put_block("One two three.\n", {"look": {"vignette": 0.4}})
	var t2 := FrontMatter.put_block("One two three.\n", {"look": {"vignette": 0.35}})
	var t3 := FrontMatter.put_block("One two three four five.\n", {"look": {"vignette": 0.35}})
	_ok(NoteHistory.record(dir, t1).is_empty() and NoteHistory.entries(dir).size() == 1, "a note's text is kept")
	NoteHistory.record(dir, t1)
	_ok(NoteHistory.entries(dir).size() == 1, "the control: the same text written again is kept once")
	NoteHistory.record(dir, t2)
	NoteHistory.record(dir, t3)
	var all := NoteHistory.entries(dir)
	_ok(all.size() == 3 and String(all[1]["said"]).contains("look.vignette 0.4 → 0.35"),
		"a setting changed is said by its place and its two values: %s" % String(all[1]["said"]) if all.size() > 1 else "?")
	_ok(String(all[0]["said"]).contains("the words, 2 more"), "the words changed are said by how many more: %s" % String(all[0]["said"]))
	_ok(float(all[0]["at"]) >= float(all[2]["at"]) and NoteHistory.text_of(dir, all[2]) == t1, "newest first, each read back as it was")
	NoteHistory.record(dir, t1, 3)
	var after := NoteHistory.entries(dir)
	_ok(after.size() == 3 and NoteHistory.text_of(dir, after[0]) == t1 and not FileAccess.file_exists(dir.path_join(String(all[2]["file"]))),
		"the newest kept, the oldest gone past the bound (%d)" % after.size())
	_rmrf(dir)
	if _fails == 0:
		print("note_history_check: ALL OK")
		quit(0)
		return
	print("note_history_check: %d FAILED" % _fails)
	quit(1)


func _rmrf(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	DirAccess.remove_absolute(path)


func _ok(cond: bool, msg: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + msg)
	if not cond:
		_fails += 1
