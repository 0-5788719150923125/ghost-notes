extends Node

## assistant_delete_check - deleting from the feedback list never holds the app up, and Delete all.
##
##   tests/run_boot_probe.sh tests/app/assistant_delete_check.gd 60
##
## On a folder of its own (`Assistant.root`), never the author's feedback. What it holds:
##   - Rows only while the panel is open: closed, the list builds none (control: open, one per note).
##   - One note deleted leaves the list at once and takes its row alone (every other row is the same node;
##     control: a full refresh makes new ones); its files go on a worker, so a task is under way when the
##     call returns, and once done every file of the note is gone and no other note's is.
##   - Delete all is pressed twice (the first press only arms it), takes every note not at work and every
##     numbered file no remaining note owns, and leaves a run under way, one waiting its turn, their files
##     and a file that is not a note's. With nothing left to take it is grayed (control: it was not before).
##   - The folder is given no .gdignore from a test.
## No run is ever started: the Assistant is held at its concurrency limit throughout.

const DIR := "user://assistant_delete_check"

var _fails: Array = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var dir := ProjectSettings.globalize_path(DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	_clear(dir)
	for i in range(1, 6):
		_put(dir, "%04d.json" % i, JSON.stringify({"query": "note %d" % i}))
		_put(dir, "%04d.png" % i, "png")
		_put(dir, "%04d.assistant.json" % i, JSON.stringify({"index": i, "query": "note %d" % i, "status": "done",
			"session_id": "s%d" % i, "response": "done %d" % i, "backend": "claude_cli"}))
	_put(dir, "0099.png.import", "left behind")
	_put(dir, "listen.wav", "not a note's")
	Assistant.root = DIR
	var a: Assistant = preload("res://src/app/assistant.gd").new()
	a.hold = true     # nothing can start, whatever is queued
	add_child(a)
	await _frames(2)
	_ok(a._entries.size() == 5, "the five notes are listed (%d)" % a._entries.size())
	_ok(_rows(a) == 0, "closed, the panel builds no rows")
	a._set_expanded(true)
	await _frames(2)
	_ok(_rows(a) == 5, "the control: open, a row per note (%d)" % _rows(a))

	print("-- one note")
	var gone: Dictionary = a._entries[1]
	var others: Array = a._entries.filter(func(e: Dictionary) -> bool: return e != gone).map(
		func(e: Dictionary) -> int: return (e["_row"] as Node).get_instance_id())
	a._delete_entry(gone)
	_ok(not a._entries.has(gone), "it leaves the list at once")
	_ok(not a._deleting.is_empty(), "its files are deleted on a worker, still under way as the call returns")
	await _frames(2)
	var same: Array = a._entries.map(func(e: Dictionary) -> int: return (e["_row"] as Node).get_instance_id())
	_ok(same == others and _rows(a) == 4, "its row alone goes: every other row is the node it was")
	a._refresh_list()
	var rebuilt: Array = a._entries.map(func(e: Dictionary) -> int: return (e["_row"] as Node).get_instance_id())
	_ok(rebuilt != others, "the control: a full refresh makes new rows")
	a._reap_deleting(true)
	var n := int(gone.index)
	_ok(not _any(dir, "%04d." % n), "once done, none of its files is left")
	_ok(_any(dir, "0001.") and _any(dir, "0003.") and _any(dir, "0099."), "and no other note's file went")

	print("-- delete all")
	var running: Dictionary = a._entries[0]
	running.status = "running"
	running.pid = -1
	var queued: Dictionary = a._entries[1]
	queued.status = "queued"
	a._refresh_list()
	_ok(not a._delete_all_btn.disabled, "with notes to take, Delete all is live")
	a._delete_all_btn.pressed.emit()
	_ok(a._entries.size() == 4, "the first press only arms it (%d notes)" % a._entries.size())
	a._delete_all_btn.pressed.emit()
	a._reap_deleting(true)
	_ok(a._entries == [running, queued], "the second takes every note not at work, and leaves the two that are")
	_ok(_any(dir, "%04d." % int(running.index)) and _any(dir, "%04d." % int(queued.index)), "their files stay")
	var taken := a._entries.size() == 2
	for i in range(1, 6):
		if i != int(running.index) and i != int(queued.index) and _any(dir, "%04d." % i):
			taken = false
	_ok(taken and not _any(dir, "0099."), "every other note's files went, and the import file no note owns")
	_ok(FileAccess.file_exists(dir.path_join("listen.wav")), "a file that is not a note's stays")
	_ok(a._delete_all_btn.disabled, "with nothing left to take, Delete all is grayed")
	_ok(not FileAccess.file_exists(dir.path_join(".gdignore")), "the folder is given no .gdignore from a test")

	a.queue_free()
	Assistant.root = ""
	await _frames(2)
	_clear(dir)
	DirAccess.remove_absolute(dir)
	if _fails.is_empty():
		print("assistant_delete_check: ALL OK")
		get_tree().quit(0)
		return
	print("assistant_delete_check: %d FAILURE(S)" % _fails.size())
	for f in _fails:
		print("   ", f)
	get_tree().quit(1)


func _rows(a: Assistant) -> int:
	return a._list_col.get_children().filter(func(c: Node) -> bool: return not c.is_queued_for_deletion()).size()


func _any(dir: String, prefix: String) -> bool:
	return Array(DirAccess.get_files_at(dir)).any(func(f: String) -> bool: return f.begins_with(prefix))


func _put(dir: String, name: String, text: String) -> void:
	var f := FileAccess.open(dir.path_join(name), FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _clear(dir: String) -> void:
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))


func _frames(k: int) -> void:
	for _i in k:
		await get_tree().process_frame


func _ok(cond: bool, msg: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + msg)
	if not cond:
		_fails.append(msg)
