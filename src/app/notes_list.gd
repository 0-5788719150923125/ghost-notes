extends CanvasLayer
class_name NotesList

## NotesList - where Ghost Notes opens (next/notes.md step 8, "No home screen"): a notes app opens on
## its notes - the default folder and every folder or file the user added ([NoteStore]), newest first.
##
## THEY ARE NOTES ON THE SCREEN, NOT A LIST IN A PANEL (2026-10-31, the user: "the home screen certainly
## doesn't give us the feeling of a notes app. It gives us a list of unlabeled projects"): a [NoteGrid]
## fills the window - the name, a search, and each note a square [NoteTile] bearing its title, its first
## words and its components, in a color its components make. Beside the search, two [Icons] and no words
## ("just replace them plain icons, no text"): "+" is New, the folder "Existing note…" for a markdown file
## brought into the list. Each tile has an × that deletes its note, asked first ([DeleteDialog]). The
## phone's [PhoneShell] shows the same grid.
##
## A NOTE OF WORDS ALONE IS WRITTEN IN ITS CARD (2026-10-31): New, or a click on a note with nothing attached,
## opens it in a [NoteEditor] over the grid - title and words, in place - and its "open" icon takes it to its
## own panel, where "+" attaches what it becomes. A note with something attached opens on its panel at once.
##
## NEW MAKES A NOTE, AND THERE IS ONE KIND (2026-10-12, the user: "'New' has no options at all.
## Every note would open in exactly the same way"): its words and nothing else. What it becomes is
## what "+" attaches to it inside ([Components]) - a song, a Picture, a Voice, a show of cards - so
## the list never asks what a note is going to be. It offered a menu of the old modes until then,
## which was a mode switch with the word "template" on it.
##
## IT MAKES NOTES AND NOTHING ELSE (2026-10-06, the user: "the launch screen should be clean, and a
## URL input panel causes immediate confusion"): a song or a video is a component of a note - the
## Song card's Choose…, the Clip card's file or link - never a button here. Its one field is the
## search, which finds notes and nothing else.
##
## THE ⤓ EXPORT BUTTON HAS NO BUSINESS HERE: nothing is playing, so there is nothing to render.
## Suppressed on the way in and released on the way out - KEYED, because main opens the note FIRST
## and frees this list SECOND, so the note's own claims are already made when this lets go.

## Set by main: open_note.call(path).
var open_note: Callable

var _grid: NoteGrid
var _editor: NoteEditor
var _new: Button
var _existing: Button
var _dialog: FileDialog


func _ready() -> void:
	layer = 200
	_build()
	var ch := Chrome.of(self)
	if ch != null:
		ch.suppress_export(&"notes")


func _exit_tree() -> void:
	var ch := Chrome.of(self)
	if ch != null:
		ch.release_export(&"notes")


func _build() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.03, 0.05, 1.0)
	add_child(bg)
	var top := MarginContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	top.add_theme_constant_override("margin_top", 36)
	add_child(top)
	_grid = NoteGrid.new()
	_grid.opened.connect(_pick)
	_grid.delete_asked.connect(_ask_delete)
	top.add_child(_grid)
	_new = Icons.button("new", 22, ("New note: its words, and nothing else yet. Inside it, + attaches what "
		+ "it should become - a song, a picture, a voice, a show of cards."))
	_new.pressed.connect(new_note)
	_grid.actions.add_child(_new)
	_existing = Icons.button("existing", 22, ("Existing note: keep a markdown note from anywhere in this "
		+ "list - a chapter in another project, a git repository. The file stays where it is."))
	_existing.pressed.connect(_open_dialog)
	_grid.actions.add_child(_existing)
	_editor = NoteEditor.new()
	_editor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_editor.closed.connect(func(_p: String) -> void: _grid.refresh(true))
	add_child(_editor)
	var whole := Icons.button("open", 20, ("Open the whole note: its own panel, where + attaches what it "
		+ "should become - a voice, a picture, a show - and Edit lists every mark it understands."))
	whole.pressed.connect(open_whole)
	_editor.actions.add_child(whole)
	var bin := Icons.button("delete", 20, "Delete this note")
	bin.pressed.connect(func() -> void: _ask_delete(_editor.path))
	_editor.actions.add_child(bin)


## NEW: a note with nothing attached, made in the default folder and opened in its card, its title and words
## written there ([NoteEditor]).
func new_note() -> void:
	var path := NoteStore.create()
	if not path.is_empty():
		_editor.open(path, true)


## A NOTE CLICKED: one of words alone opens in its card; one with something attached, on its own panel.
func _pick(path: String) -> void:
	if Components.attached_of(NoteStore.blocks_of(path)).size() > 1:
		_open(path)
	else:
		_editor.open(path)


## THE CARD'S "OPEN": the note in it, what waits written, on its own panel.
func open_whole() -> void:
	var path := _editor.path
	if path.is_empty():
		return
	_editor.save()
	_editor.drop()
	_open(path)


## Read the notes again now, rather than at the grid's next look ([NoteGrid]).
func refresh() -> void:
	_grid.refresh()


## The ×: asked first, then gone ([DeleteDialog]) - to the trash, or out of the list with its file kept.
func _ask_delete(path: String) -> void:
	DeleteDialog.ask(self, path, func(answer: String) -> void:
		var err := ""
		if answer in ["trash", "forget"] and _editor.path == path:
			_editor.drop()
		if answer == "trash":
			err = NoteStore.trash(path)
		elif answer == "forget":
			NoteStore.remove(path)
		if not err.is_empty():
			push_warning("ghost: " + err)
		refresh())


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
