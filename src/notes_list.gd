extends CanvasLayer
class_name NotesList

## NotesList - where Ghost Notes opens (next/notes.md step 8, "No home screen"): a notes app opens on
## its notes. The left panel lists them - the default folder and every folder or file the user added
## ([NoteStore]), newest first - under the name and the tagline, with New, and "Existing note…" for a
## markdown file brought into the list. Each note has an × that deletes it, asked first
## ([DeleteDialog]).
##
## NEW MAKES A NOTE, AND THERE IS ONE KIND (2026-10-12, the user: "'New' has no options at all.
## Every note would open in exactly the same way"): its words and nothing else. What it becomes is
## what "+" attaches to it inside ([Components]) - a song, a Picture, a Voice, a show of cards - so
## the list never asks what a note is going to be. It offered a menu of the old modes until then,
## which was a mode switch with the word "template" on it.
##
## IT MAKES NOTES AND NOTHING ELSE (2026-10-06, the user: "the launch screen should be clean, and a
## URL input panel causes immediate confusion"): a song or a video is a component of a note - the
## Song card's Choose…, the Clip card's file or link - never a button here. The main area is empty.
##
## THE ⤓ EXPORT BUTTON HAS NO BUSINESS HERE: nothing is playing, so there is nothing to render.
## Suppressed on the way in and released on the way out - KEYED, because main opens the note FIRST
## and frees this list SECOND, so the note's own claims are already made when this lets go.

## Set by main: open_note.call(path).
var open_note: Callable

const COL_DATE := Color(0.5, 0.56, 0.66)

var _panel: SidePanel
var _new: Button
var _existing: Button
var _rows: VBoxContainer
var _dialog: FileDialog
var _seen := ""            # the list as last drawn, so it is rebuilt only when it changed
var _poll_t := 0.0


func _ready() -> void:
	layer = 200
	_build()
	var ch := Chrome.of(self)
	if ch != null:
		ch.suppress_export(&"notes")
	refresh()


func _exit_tree() -> void:
	var ch := Chrome.of(self)
	if ch != null:
		ch.release_export(&"notes")


func _process(delta: float) -> void:
	# a note saved, made or deleted elsewhere shows up within a second or two
	_poll_t -= delta
	if _poll_t <= 0.0:
		_poll_t = 1.5
		refresh()


func _build() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.03, 0.05, 1.0)
	add_child(bg)
	_panel = preload("res://src/side_panel.gd").new(380.0)
	_panel.title = "Notes"
	add_child(_panel)
	var box: VBoxContainer = _panel.body
	box.add_theme_constant_override("separation", 10)
	var name := Label.new()
	name.text = Boot.NAME
	name.add_theme_font_size_override("font_size", 20)
	box.add_child(name)
	var sub := Label.new()
	sub.text = Boot.TAGLINE
	sub.add_theme_font_size_override("font_size", 12)
	sub.modulate = Color(1, 1, 1, 0.6)
	box.add_child(sub)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	_new = Button.new()
	_new.text = "New"
	_new.focus_mode = Control.FOCUS_NONE
	_new.tooltip_text = ("A new note: its words, and nothing else yet. Inside it, + attaches what it "
		+ "should become - a song, a picture, a voice, a show of cards.")
	_new.pressed.connect(new_note)
	row.add_child(_new)
	_existing = Button.new()
	_existing.text = "Existing note…"
	_existing.flat = true
	_existing.focus_mode = Control.FOCUS_NONE
	_existing.tooltip_text = ("Keep a markdown note from anywhere in this list - a chapter in another "
		+ "project, a git repository. The file stays where it is.")
	_existing.pressed.connect(_open_dialog)
	row.add_child(_existing)

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 2)
	box.add_child(_rows)


## NEW: a note with nothing attached, made in the default folder and opened.
func new_note() -> void:
	var path := NoteStore.create()
	if not path.is_empty():
		_open(path)


## Rebuild the rows when the notes changed: each a note's title and when it last changed.
func refresh() -> void:
	var notes := NoteStore.list()
	var sig := JSON.stringify(notes)
	if sig == _seen:
		return
	_seen = sig
	for c in _rows.get_children():
		c.queue_free()
	if notes.is_empty():
		var none := Label.new()
		none.text = "No notes yet - New makes one."
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.add_theme_font_size_override("font_size", 12)
		none.modulate = Color(1, 1, 1, 0.55)
		_rows.add_child(none)
		return
	for n in notes:
		_rows.add_child(_row(n))


func _row(n: Dictionary) -> Control:
	var path := String(n["path"])
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var b := Button.new()
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.clip_text = true
	b.text = String(n["title"])
	b.tooltip_text = path
	b.custom_minimum_size = Vector2(0, 30)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(_open.bind(path))
	row.add_child(b)
	var date := Label.new()
	date.text = when(int(n["mtime"]))
	date.add_theme_font_size_override("font_size", 11)
	date.add_theme_color_override("font_color", COL_DATE)
	date.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(date)
	var x := Button.new()
	x.text = "×"
	x.flat = true
	x.focus_mode = Control.FOCUS_NONE
	x.tooltip_text = "Delete this note"
	x.add_theme_color_override("font_color", COL_DATE)
	x.pressed.connect(_ask_delete.bind(path))
	row.add_child(x)
	return row


## The ×: asked first, then gone ([DeleteDialog]) - to the trash, or out of the list with its file kept.
func _ask_delete(path: String) -> void:
	DeleteDialog.ask(self, path, func(answer: String) -> void:
		var err := ""
		if answer == "trash":
			err = NoteStore.trash(path)
		elif answer == "forget":
			NoteStore.remove(path)
		if not err.is_empty():
			push_warning("ghost: " + err)
		refresh())


## When a note last changed, as a list says it: "today", "yesterday", "Oct 3", "2025-12-01".
static func when(mtime: int) -> String:
	if mtime <= 0:
		return ""
	var now := int(Time.get_unix_time_from_system())
	var today := Time.get_datetime_dict_from_unix_time(now)
	var then := Time.get_datetime_dict_from_unix_time(mtime)
	var day := func(d: Dictionary) -> int:
		return int(Time.get_unix_time_from_datetime_dict({"year": d["year"], "month": d["month"], "day": d["day"]}) / 86400)
	var ago: int = int(day.call(today)) - int(day.call(then))
	if ago <= 0:
		return "today"
	if ago == 1:
		return "yesterday"
	var months := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	if int(then["year"]) == int(today["year"]):
		return "%s %d" % [months[int(then["month"]) - 1], int(then["day"])]
	return "%04d-%02d-%02d" % [int(then["year"]), int(then["month"]), int(then["day"])]


func _open(path: String) -> void:
	if open_note.is_valid():
		open_note.call(path)
	queue_free()


## EXISTING NOTE…: a markdown file from anywhere, kept in the list where it is ([method
## NoteStore.add]) and opened.
func _open_dialog() -> void:
	if _dialog != null and is_instance_valid(_dialog):
		return
	_dialog = FileDialog.new()
	_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_dialog.access = FileDialog.ACCESS_FILESYSTEM
	# In-window, never native: the portal dialog shows nothing at all on a Linux box without
	# xdg-desktop-portal ("I pressed it and nothing happened").
	_dialog.use_native_dialog = false
	_dialog.title = "Bring a markdown note into the list"
	_dialog.filters = PackedStringArray(["*.md, *.markdown ; Notes"])
	_dialog.size = Vector2i(820, 560)
	_dialog.file_selected.connect(func(p: String) -> void:
		_close_dialog()
		if NoteStore.add(p):
			_open(p))
	_dialog.canceled.connect(_close_dialog)
	add_child(_dialog)
	_dialog.popup_centered()


func _close_dialog() -> void:
	if _dialog != null and is_instance_valid(_dialog):
		_dialog.queue_free()
	_dialog = null
