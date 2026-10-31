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
## THE LIST IS THE DESKTOP'S (2026-10-31, the user: "the mobile view is important"): the same [NoteGrid]
## of square notes, at [constant SCALE] - two columns on a phone's width, the search above them, and
## icons for New and Import… (an [Icons] "+" and a folder, no words). A tap opens a note; a drag scrolls.
##
## A NOTE CAN BE DELETED from its editor (Delete…), asked first ([DeleteDialog]) - to the trash.
##
## THE NOTE IS WRITTEN IN ITS CARD (2026-10-31), the desktop's [NoteEditor] filling the screen: its title and
## its words in place, written as they are typed on a quiet period - the frontmatter kept byte for byte, the
## file renamed with its title while its name follows it ([method NoteStore.retitle]).

## Everything on the list is this much bigger than on a desktop: a phone's canvas is 1080 wide and held
## closer, and a finger is wider than a pointer.
const SCALE := 1.8

var _list_view: NoteGrid
var _editor: NoteEditor
var _title: LineEdit
var _body: TextEdit
## The note open in the card, "" on the list.
var _note: String:
	get:
		return _editor.path if _editor != null else ""
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


## ANDROID'S BACK goes from a note to the list; on the list it leaves the app, as back does.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and not _note.is_empty():
		show_list()
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save()           # a phone may stop the app at any moment: what was typed is kept


func _build_list(stack: VBoxContainer) -> void:
	_list_view = NoteGrid.new(SCALE, false)
	_list_view.opened.connect(open_note)
	stack.add_child(_list_view)
	var make := Icons.button("new", roundi(24 * SCALE), "New note")
	make.pressed.connect(new_note)
	_list_view.actions.add_child(make)
	var bring := Icons.button("existing", roundi(24 * SCALE), "Import a note from anywhere the phone can reach")
	bring.pressed.connect(func() -> void: _pick("import"))
	_list_view.actions.add_child(bring)


func _build_editor(stack: VBoxContainer) -> void:
	_editor = NoteEditor.new(SCALE, true)
	_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_editor.closed.connect(func(_p: String) -> void: show_list())
	stack.add_child(_editor)
	_title = _editor.title_edit
	_body = _editor.body
	var out := Icons.button("export", roundi(24 * SCALE), "Export this note to a file")
	out.pressed.connect(func() -> void: _pick("export"))
	_editor.actions.add_child(out)
	var bin := Icons.button("delete", roundi(24 * SCALE), "Delete this note")
	bin.pressed.connect(func() -> void:
		if not _note.is_empty():
			DeleteDialog.ask(self, _note, delete_note))
	_editor.actions.add_child(bin)


## The list, read again: every note in the folder, newest first ([NoteGrid]) - the note in the card closed first.
func show_list() -> void:
	if _editor.visible:
		_editor.close()          # closing it comes back here
		return
	_list_view.visible = true
	_list_view.refresh(true)


## A new, empty note, open in its card.
func new_note() -> void:
	var path := NoteStore.create()
	if not path.is_empty():
		_list_view.visible = false
		_editor.open(path, true)


func open_note(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	_list_view.visible = false
	_editor.open(path)


## Write what is waiting in the card.
func save() -> void:
	_editor.save()


## DELETE THE OPEN NOTE (once asked): the note is trashed and the list comes back without it. [param answer]
## is the dialog's ("trash"; "forget" cannot arise here - every note on a phone is in its own folder).
func delete_note(answer: String) -> void:
	if _note.is_empty() or answer != "trash":
		return
	var path := _note
	_editor.drop()
	var err := NoteStore.trash(path)
	if not err.is_empty():
		push_warning("ghost: " + err)
	show_list()


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
