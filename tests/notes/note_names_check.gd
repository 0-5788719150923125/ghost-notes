extends Node

## note_names_check - a note's file is named after its title, and stays so ([method NoteStore.retitle];
## 2026-10-31), on a notes folder of the gate's own (`NoteStore.root`).
##
##   tests/run_boot_probe.sh tests/notes/note_names_check.gd 120
##
## A NAME FOLLOWS ITS TITLE while it is the title's, or that and a number another note made it take ("Plan 2"
## titled "Plan"), and not otherwise: "Plan 2" titled "Plan 2" follows, "Plan two" titled "Plan" does not.
## RETITLED, A FOLLOWING NOTE IS RENAMED, its words untouched; a title another file has takes a number, and the
## note is never numbered past itself (retitled back to what it is called, it stays). A title that has what a file
## system refuses is named without it; one that opens on a dot is no hidden file.
##
## THE CONTROLS, A NAME OF ITS OWN: a file saved or brought in under another name than its title keeps that name
## when its title changes - and a title emptied leaves the file as it is.
##
## A NEW NOTE LEFT EMPTY GOES ([method NoteStore.discard_if_empty]) - and one with words, or with something
## attached, never does.

const ROOT := "user://note_names_check"
var _fails: Array = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_clean()
	var keep := NoteStore.root
	NoteStore.root = ROOT
	var dir := NoteStore.folder()
	print("-- whether a name follows its title")
	_ok(NoteStore.follows(dir.path_join("Plan.md"), "Plan"), "\"Plan.md\" follows \"Plan\"")
	_ok(NoteStore.follows(dir.path_join("Plan 2.md"), "Plan"), "\"Plan 2.md\" follows \"Plan\" (a number another note made it take)")
	_ok(NoteStore.follows(dir.path_join("Plan 2.md"), "Plan 2"), "\"Plan 2.md\" follows \"Plan 2\"")
	_ok(not NoteStore.follows(dir.path_join("Plan two.md"), "Plan"), "THE CONTROL: \"Plan two.md\" does not follow \"Plan\"")
	_ok(not NoteStore.follows(dir.path_join("43-secular-hazing.md"), "Secular Hazing"), "...nor a chapter's own file name its title")
	_ok(NoteStore.follows(dir.path_join("What is it.md"), "What is it?"), "a title's \"?\" is left out of its name")
	_ok(NoteStore.name_of(".hidden") == "hidden", "a title opening on a dot names no hidden file")

	print("-- retitled")
	var a := NoteStore.create("Untitled", "Milk and eggs.\n")
	var b := NoteStore.create("Untitled", "Bread.\n")
	_ok(b.get_file() == "Untitled 2.md", "a second untitled note takes a number (%s)" % b.get_file())
	var a2 := NoteStore.retitle(a, "Groceries")
	_ok(a2.get_file() == "Groceries.md" and not FileAccess.file_exists(a) and FileAccess.get_file_as_string(a2).contains("Milk and eggs."),
		"retitled, it is renamed after its title, its words with it (%s)" % a2.get_file())
	var b2 := NoteStore.retitle(b, "Groceries")
	_ok(b2.get_file() == "Groceries 2.md", "a title another note has takes a number (%s)" % b2.get_file())
	_ok(NoteStore.retitle(b2, "Groceries") == b2, "retitled to what it is, it stays where it is")
	var b3 := NoteStore.retitle(b2, "Bread: a plan")
	_ok(b3.get_file() == "Bread  a plan.md" or b3.get_file() == "Bread a plan.md", "a title's \":\" is left out of its name (%s)" % b3.get_file())

	print("-- a name of its own")
	var own := dir.path_join("chapter-03.md")
	FrontMatter.create(own, null, "Words.\n", "", FrontMatter.KEY, {"title": "The Long Night"})
	_ok(NoteStore.retitle(own, "The Longest Night") == own and FileAccess.get_file_as_string(own).contains("title: The Longest Night"),
		"THE CONTROL: a file under a name of its own keeps it, its title changed")
	var emptied := NoteStore.retitle(a2, "")
	_ok(emptied == a2 and not FileAccess.get_file_as_string(a2).contains("title:"), "a title emptied is taken out, and the file stays")

	print("-- a new note left empty")
	var blank := NoteStore.create()
	var worded := NoteStore.create("", "Words.\n")
	var attached := NoteStore.create("", "", {"voice": {}})
	_ok(NoteStore.discard_if_empty(blank) and not FileAccess.file_exists(blank), "a new note left empty goes")
	_ok(not NoteStore.discard_if_empty(worded) and FileAccess.file_exists(worded), "THE CONTROL: one with words stays")
	_ok(not NoteStore.discard_if_empty(attached) and FileAccess.file_exists(attached), "...and one with something attached")

	NoteStore.root = keep
	_clean()
	if _fails.is_empty():
		print("note_names_check: ALL OK")
		get_tree().quit(0)
		return
	print("note_names_check: %d FAILURE(S)" % _fails.size())
	for f in _fails:
		print("   ", f)
	get_tree().quit(1)


func _clean() -> void:
	var abs := ProjectSettings.globalize_path(ROOT)
	if DirAccess.dir_exists_absolute(abs):
		for f in DirAccess.get_files_at(abs):
			DirAccess.remove_absolute(abs.path_join(f))
		DirAccess.remove_absolute(abs)


func _ok(cond: bool, msg: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + msg)
	if not cond:
		_fails.append(msg)
