extends Node

## note_editor_check - a note opened in its card ([NoteEditor]; 2026-10-31), on a notes folder of the gate's own
## (`NoteStore.root`).
##
##   tests/run_boot_probe.sh tests/ui/note_editor_check.gd 120
##
## ITS TITLE AND ITS WORDS IN PLACE: opened, the card holds the note's title and its words without the
## frontmatter; a new note's title box is empty.
##
## THE CARD GROWS WITH ITS WORDS (the user: "expand description to fit the content - breaking from the strictly
## square aspect ratio"): many lines make it taller than a few - THE CONTROL - and never taller than the screen,
## where the words scroll inside it. On a phone ([member NoteEditor.whole]) it fills its rect.
##
## WRITTEN AS IT IS TYPED: on the quiet period the words reach the file, the frontmatter kept byte for byte, and
## the title renames a file named after it ([signal NoteEditor.moved]). CLOSED, a new note left empty is gone and
## one with words stays; Escape and a click beside the card close it.

const ROOT := "user://note_editor_check"
var _fails: Array = []
var _closed: Array = []
var _moves: Array = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_clean()
	var keep := NoteStore.root
	NoteStore.root = ROOT
	var ed := NoteEditor.new()
	add_child(ed)
	ed.position = Vector2.ZERO
	ed.size = Vector2(1920, 1080)
	ed.closed.connect(func(p: String) -> void: _closed.append(p))
	ed.moved.connect(func(f: String, t: String) -> void: _moves.append([f, t]))

	print("-- its title and words in place")
	var path := NoteStore.create("Shopping", "Milk.\n", {"youtube": {}})
	var head := String(FrontMatter.split(FileAccess.get_file_as_string(path))["head"])
	ed.open(path)
	await _frames(3)
	_ok(ed.visible and ed.title_edit.text == "Shopping" and ed.body.text == "Milk.\n", "opened, the card holds the title and the words alone")

	print("-- the card grows with its words")
	var short := ed._card.size.y
	ed.body.text = "A line.\n".repeat(14)
	ed.body.text_changed.emit()
	await _frames(3)
	var tall := ed._card.size.y
	_ok(tall > short + 100.0, "THE CONTROL: fourteen lines make it taller than a few (%.0f to %.0f)" % [short, tall])
	_ok(absf(ed._card.size.x - NoteEditor.WIDE) < 1.0 and tall > ed._card.size.x * 0.5, "it is no longer a square's shape: %.0f by %.0f" % [ed._card.size.x, tall])
	ed.body.text = "A line.\n".repeat(200)
	ed.body.text_changed.emit()
	await _frames(3)
	_ok(ed._card.get_rect().end.y <= 1080.0 + 0.5, "never taller than the screen (%.0f)" % ed._card.get_rect().end.y)

	print("-- written as it is typed")
	ed.body.text = "Milk, eggs, bread.\n"
	ed.body.text_changed.emit()
	ed.title_edit.text = "Groceries"
	ed.title_edit.text_changed.emit("Groceries")
	await _wait(NoteEditor.SAVE_MS + 300)
	var raw := FileAccess.get_file_as_string(ed.path)
	_ok(raw.contains("Milk, eggs, bread.") and raw.contains("title: Groceries"), "the words and the title reach the file")
	_ok(String(FrontMatter.split(raw)["head"]).replace("title: Groceries", "title: Shopping") == head, "the frontmatter kept byte for byte, but its title")
	_ok(ed.path.get_file() == "Groceries.md" and _moves.size() == 1 and _moves[0][0] == path, "the file is renamed after its title, and says so")

	print("-- closed")
	var kept := ed.path
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	ed._input(esc)
	_ok(not ed.visible and _closed == [kept] and FileAccess.file_exists(kept), "Escape closes it, the note kept")
	var blank := NoteStore.create()
	ed.open(blank, true)
	await _frames(2)
	_ok(ed.title_edit.text.is_empty(), "a new note's title box is empty")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	ed._scrim.gui_input.emit(click)
	_ok(not ed.visible and not FileAccess.file_exists(blank), "a click beside the card closes it, and a new note left empty is gone")
	var worded := NoteStore.create()
	ed.open(worded, true)
	ed.body.text = "Call the plumber.\n"
	ed.body.text_changed.emit()
	ed.close()
	_ok(FileAccess.file_exists(worded) and FileAccess.get_file_as_string(worded).contains("Call the plumber."),
		"THE CONTROL: a new note with words stays, written as it closes")
	ed.queue_free()

	print("-- on a phone")
	var phone := NoteEditor.new(PhoneShell.SCALE, true)
	add_child(phone)
	phone.size = Vector2(1032, 1872)
	phone.open(worded)
	await _frames(3)
	_ok(phone._card.size.is_equal_approx(phone.size), "it fills the phone's screen (%s)" % str(phone._card.size))
	phone.queue_free()

	NoteStore.root = keep
	_clean()
	if _fails.is_empty():
		print("note_editor_check: ALL OK")
		get_tree().quit(0)
		return
	print("note_editor_check: %d FAILURE(S)" % _fails.size())
	for f in _fails:
		print("   ", f)
	get_tree().quit(1)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait(ms: int) -> void:
	var until := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < until:
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
