extends Node

## handheld_check - the phone shell, run on the desktop (next/notes.md step 11), through the real main
## scene with `Boot.handheld_for_test` (what `--handheld` and a phone set) and a notes folder of the
## gate's own (`NoteStore.root`).
##
##   tests/run_boot_probe.sh tests/handheld_check.gd 120
##
## A NOTES APP AND NOTHING MORE: the shell is up, and no Chrome furniture, no stage, no transport, no
## notes list of the desktop's; the Provisioner did not start and no program is running - a phone
## downloads nothing.
##
## MAKES, EDITS AND KEEPS A NOTE ACROSS RESTARTS: New makes a note in the folder; its title and body,
## typed, are written on the quiet period (the frontmatter kept byte for byte); the shell torn down and
## built again lists it under its new title and opens it with its words. Import… and Export… copy a
## note in and out.
##
## THE SETTINGS A PHONE DEPENDS ON ARE THERE - Godot drops a value equal to its default when it
## rewrites project.godot, which is how monotone's first APK came up sideways: portrait orientation, a
## portrait canvas for mobile; and the Android preset leaves out the hosts, masks, feedback, build,
## tests, next and docs.

const ROOT := "user://handheld_check"
var _fails: Array = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_clean()
	NoteStore.root = ROOT
	Boot.handheld_for_test = true
	var main := await _boot()
	var shell: PhoneShell = _shell(main)
	_ok(shell != null, "the phone shell is up")
	if shell == null:
		return _report()
	_ok(get_tree().get_first_node_in_group("ghost_chrome") == null, "no Chrome furniture")
	_ok(main._stage == null and main._list == null, "no stage and no desktop notes list")
	_ok(not Provisioner._enabled and Provisioner._jobs.is_empty(), "the Provisioner did not start")
	_ok(Subprocess.tracked() == 0, "no program is running")
	# make, edit
	shell.new_note()
	var path: String = shell._note
	_ok(not path.is_empty() and FileAccess.file_exists(path), "New makes a note in the folder")
	shell._title.text = "Groceries"
	shell._title.text_changed.emit("Groceries")
	shell._body.text = "Milk, eggs, and the good bread.\n"
	shell._body.text_changed.emit()
	await _wait(PhoneShell.SAVE_MS + 400)
	var raw := FileAccess.get_file_as_string(path)
	_ok(raw.contains("Milk, eggs, and the good bread.") and raw.contains("title: Groceries"),
		"the title and the words are written as they are typed:\n%s" % raw)
	_ok(raw.begins_with("---\n"), "the frontmatter stays at the top")
	# export and import
	var out := ProjectSettings.globalize_path(ROOT).path_join("exported.md")
	_ok(shell.export_to(out) and FileAccess.get_file_as_string(out) == raw, "Export… writes the note out as it is")
	# restart
	main.queue_free()
	await _frames(4)
	main = await _boot()
	shell = _shell(main)
	_ok(shell != null and not shell._list_view.get_children().is_empty(), "after a restart the shell is up again")
	var listed := NoteStore.list().map(func(n: Dictionary) -> String: return String(n["title"]))
	_ok(listed.has("Groceries"), "the note is listed under its new title (%s)" % str(listed))
	shell.open_note(path)
	_ok(shell._body.text == "Milk, eggs, and the good bread.\n" and shell._title.text == "Groceries",
		"and opens with its words")
	var copy := shell.import_from(out)
	_ok(not copy.is_empty() and copy != path and FileAccess.get_file_as_string(copy) == raw,
		"Import… copies a note into the folder and opens it")
	main.queue_free()
	await _frames(4)
	Boot.handheld_for_test = false
	_settings()
	_clean()
	_report()


func _settings() -> void:
	_ok(int(ProjectSettings.get_setting("display/window/handheld/orientation", 0)) == 1, "the phone holds portrait")
	var proj := FileAccess.get_file_as_string("res://project.godot")
	_ok(proj.contains("window/size/viewport_width.mobile=1080") and proj.contains("window/size/viewport_height.mobile=1920"),
		"a phone's canvas is portrait")
	var cfg := ConfigFile.new()
	_ok(cfg.load("res://export_presets.cfg") == OK, "the export presets read")
	var trimmed := false
	for sec in cfg.get_sections():
		if String(cfg.get_value(sec, "platform", "")) == "Android":
			var ex := String(cfg.get_value(sec, "exclude_filter", ""))
			trimmed = ["hosts/*", "masks/*", "feedback/*", "build/*", "tests/*", "next/*", "docs/*"].all(
				func(f: String) -> bool: return ex.contains(f))
	_ok(trimmed, "the Android preset leaves out the hosts, masks, feedback, build, tests, next and docs")


func _boot() -> Node:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames(8)
	return main


func _shell(main: Node) -> PhoneShell:
	for c in main.get_children():
		if c is PhoneShell:
			return c
	return null


func _wait(ms: int) -> void:
	var until := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


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


func _report() -> void:
	if _fails.is_empty():
		print("handheld_check: ALL OK")
		get_tree().quit(0)
		return
	print("handheld_check: %d FAILURE(S)" % _fails.size())
	for f in _fails:
		print("   ", f)
	get_tree().quit(1)
