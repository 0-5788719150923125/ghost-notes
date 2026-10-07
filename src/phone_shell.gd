extends CanvasLayer
class_name PhoneShell

## PhoneShell - Ghost Notes on a phone (next/notes.md step 11, "Platforms: desktop and Android"): a
## notes app and nothing more. A list of the notes in `user://notes/` ([NoteStore]), and the editor -
## full screen, in portrait - with no stage, no transport, no Chrome furniture and no agent: on a phone
## a note has one component, its text. Nothing is downloaded; the Provisioner stays off.
##
## A FILE COMES IN OR GOES OUT THROUGH THE SYSTEM'S PICKER: Import… copies a note from anywhere the
## phone can reach into `user://notes/`, and Export… writes one back out (on Android the picker hands
## back a `content://` address, which [FileAccess] reads and writes since Godot 4.6). No permission is
## asked for. On the desktop (`--handheld`) the picker is the in-window dialog.
##
## THE NOTE IS WRITTEN AS YOU TYPE, on a quiet period ([constant SAVE_MS]), body and title apart:
## the body through [method FrontMatter.write_body], which keeps every byte of the frontmatter, and the
## title as the note's own `title:` line - the same file a desktop opens, components and all.

## How long the typing must stop before the note is written, in ms.
const SAVE_MS := 800

var _list_view: VBoxContainer
var _rows: VBoxContainer
var _editor_view: VBoxContainer
var _title: LineEdit
var _body: TextEdit
var _note := ""                 # the note open in the editor, "" on the list
var _saved_body := ""           # the body as last read or written: what write_body expects
var _dirty_ms := -1             # when the typing stopped, -1 when nothing waits
var _title_dirty := false
var _picker_mode := ""          # "import" or "export" while a picker is up


func _ready() -> void:
	layer = 100
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.07)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var stack := VBoxContainer.new()
	margin.add_child(stack)
	_build_list(stack)
	_build_editor(stack)
	show_list()


func _process(_delta: float) -> void:
	if _dirty_ms >= 0 and Time.get_ticks_msec() - _dirty_ms >= SAVE_MS:
		save()


## ANDROID'S BACK goes from a note to the list; on the list it leaves the app, as back does.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and not _note.is_empty():
		show_list()
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save()           # a phone may stop the app at any moment: what was typed is kept


func _build_list(stack: VBoxContainer) -> void:
	_list_view = VBoxContainer.new()
	_list_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list_view.add_theme_constant_override("separation", 14)
	stack.add_child(_list_view)
	var name := Label.new()
	name.text = Boot.NAME
	name.add_theme_font_size_override("font_size", 40)
	_list_view.add_child(name)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_list_view.add_child(row)
	row.add_child(_button("New", new_note))
	row.add_child(_button("Import…", func() -> void: _pick("import")))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list_view.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 6)
	scroll.add_child(_rows)


func _build_editor(stack: VBoxContainer) -> void:
	_editor_view = VBoxContainer.new()
	_editor_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_editor_view.add_theme_constant_override("separation", 10)
	stack.add_child(_editor_view)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_editor_view.add_child(row)
	row.add_child(_button("‹ Notes", show_list))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	row.add_child(_button("Export…", func() -> void: _pick("export")))
	_title = LineEdit.new()
	_title.placeholder_text = "Title"
	_title.add_theme_font_size_override("font_size", 30)
	_title.text_changed.connect(func(_t: String) -> void:
		_title_dirty = true
		_dirty_ms = Time.get_ticks_msec())
	_editor_view.add_child(_title)
	# the system keyboard comes up by itself for a TextEdit; no code of ours asks for it
	_body = TextEdit.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_body.add_theme_font_size_override("font_size", 24)
	_body.text_changed.connect(func() -> void: _dirty_ms = Time.get_ticks_msec())
	_editor_view.add_child(_body)


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 64)
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(action)
	return b


## The list, rebuilt: every note in the folder, newest first.
func show_list() -> void:
	save()
	_note = ""
	_editor_view.visible = false
	_list_view.visible = true
	for c in _rows.get_children():
		c.queue_free()
	var notes := NoteStore.list()
	if notes.is_empty():
		var none := Label.new()
		none.text = "No notes yet. New makes one."
		none.add_theme_font_size_override("font_size", 22)
		none.modulate = Color(1, 1, 1, 0.6)
		_rows.add_child(none)
	for n in notes:
		var b := _button(String(n["title"]), open_note.bind(String(n["path"])))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.flat = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.clip_text = true
		_rows.add_child(b)


## A new, empty note, open in the editor.
func new_note() -> void:
	var path := NoteStore.create("note", "Untitled")
	if not path.is_empty():
		open_note(path)


func open_note(path: String) -> void:
	save()
	if not FileAccess.file_exists(path):
		return
	_note = path
	var raw := FileAccess.get_file_as_string(path)
	_saved_body = FrontMatter.lf(String(FrontMatter.split(raw).body))
	_title.text = NoteStore.title_of(path)
	_body.text = _saved_body
	_dirty_ms = -1
	_title_dirty = false
	_list_view.visible = false
	_editor_view.visible = true


## Write what is waiting: the body, keeping the frontmatter byte for byte, and the title as its line.
func save() -> void:
	if _note.is_empty() or _dirty_ms < 0:
		return
	_dirty_ms = -1
	if _body.text != _saved_body:
		var err := FrontMatter.write_body(_note, _body.text, _saved_body)
		if err.is_empty():
			_saved_body = _body.text
		else:
			push_warning("ghost: %s was not saved - %s" % [_note.get_file(), err])
	if _title_dirty:
		_title_dirty = false
		var t := _title.text.strip_edges()
		FrontMatter.write_block(_note, t if not t.is_empty() else null, "title")


# --- the system's picker ------------------------------------------------------------------------

func _pick(mode: String) -> void:
	save()
	_picker_mode = mode
	var save_mode := mode == "export"
	var filters := PackedStringArray(["*.md, *.markdown, *.txt ; Notes"])
	if DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		DisplayServer.file_dialog_show("Export the note" if save_mode else "Import a note", "",
			_note.get_file() if save_mode else "", false,
			DisplayServer.FILE_DIALOG_MODE_SAVE_FILE if save_mode else DisplayServer.FILE_DIALOG_MODE_OPEN_FILE,
			filters, _on_picked)
		return
	var d := FileDialog.new()
	d.access = FileDialog.ACCESS_FILESYSTEM
	d.use_native_dialog = false
	d.file_mode = FileDialog.FILE_MODE_SAVE_FILE if save_mode else FileDialog.FILE_MODE_OPEN_FILE
	d.filters = filters
	d.size = Vector2i(560, 760)
	if save_mode:
		d.current_file = _note.get_file()
	d.file_selected.connect(func(p: String) -> void:
		_on_picked(true, PackedStringArray([p]), 0)
		d.queue_free())
	d.canceled.connect(d.queue_free)
	add_child(d)
	d.popup_centered()


func _on_picked(ok: bool, paths: PackedStringArray, _filter: int) -> void:
	if not ok or paths.is_empty():
		return
	var where := String(paths[0])
	if _picker_mode == "export":
		export_to(where)
	else:
		import_from(where)


## A note from [param where] (a path or a `content://` address) copied into the notes folder, and
## opened.
func import_from(where: String) -> String:
	var text := FileAccess.get_file_as_string(where)
	if text.is_empty() and not FileAccess.file_exists(where):
		return ""
	var name := where.get_file().get_basename() if not where.begins_with("content://") else "Imported note"
	var path := NoteStore.unique(NoteStore.folder().path_join(name + ".md"))
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(text)
	f.close()
	open_note(path)
	return path


## The open note written out to [param where], as it is.
func export_to(where: String) -> bool:
	if _note.is_empty():
		return false
	var f := FileAccess.open(where, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(FileAccess.get_file_as_string(_note))
	f.close()
	return true
